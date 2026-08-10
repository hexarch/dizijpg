import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import '../ekranlar/ortak.dart' show KullaniciAvatari;
import 'arama_efekti.dart';
import 'arama_servisi.dart';
import 'gorusme_api.dart';
import 'gorusme_denetci.dart';
import 'gorusme_ekrani.dart';
import 'gorusme_surucu.dart';

/// Gelen arama ekranı (`/arama-gelen`).
///
/// **Teklif SDP'sini bildirimden DEĞİL sunucudan alır.** FCM veri paketinde
/// yalnız `arama_id`, `arama_turu` ve `sona_erme` var (sözleşme §7.1) —
/// SDP oraya konmuyor. Bu bilinçli: FCM veri sınırı 4 KB, aday dolu bir SDP
/// 64 KB'a kadar çıkabiliyor. Ekran açılınca `GET /arama/gelen` ile
/// çekiliyor; böylece uygulama KAPALIYKEN bildirime dokunularak açılan yol
/// ile ön plandaki yoklamayla açılan yol AYNI koddan geçiyor.
class GelenAramaSayfasi extends StatefulWidget {
  const GelenAramaSayfasi({
    super.key,
    this.surucuUret,
    this.gelenGetir,
    this.efektUret,
  });

  /// YALNIZ TEST: sahte sürücü.
  final GorusmeSurucu Function()? surucuUret;

  /// YALNIZ TEST: `GET /arama/gelen` yerine sahte veri.
  final Future<Map<String, dynamic>?> Function()? gelenGetir;

  /// YALNIZ TEST: sahte efekt (zil/haptik) tak.
  final AramaEfekti Function()? efektUret;

  @override
  State<GelenAramaSayfasi> createState() => _GelenAramaSayfasiState();
}

class _GelenAramaSayfasiState extends State<GelenAramaSayfasi> {
  Map<String, dynamic>? _arama;
  bool _yuklendi = false;
  bool _kabulEdildi = false;
  bool _islemde = false;
  Timer? _sonaErmeSayaci;
  GorusmeDenetci? _denetci;

  /// Gelen aramanın ZİLİ. Ön planda gelen arama ekranı FCM bildirimi YERİNE
  /// açılır (push.dart §7.4 ön plan bastırma: bildirim çizilmez, doğrudan bu
  /// ekran) — yani foreground'da telefonu çaldıran TEK yer burasıdır. Aranan
  /// cevaplayınca/reddedince/ekran kapanınca SUSAR. Denetçiye de veriliyor:
  /// bağlanınca "bağlandı" haptiği ve oynatıcı temizliği tek yerden.
  late final AramaEfekti _efekt = (widget.efektUret ?? CihazEfekti.new)();

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final a = await (widget.gelenGetir ?? GorusmeApi.gelen)();
      if (!mounted) return;
      setState(() {
        _arama = a;
        _yuklendi = true;
      });
      if (a == null) {
        // Arayan kapatmış ya da 45 sn dolmuş: ekranı sessizce kapat.
        _kapat('Arama sona erdi'.c);
        return;
      }
      // TELEFON ÇALSIN: ön planda çaldıran tek yer burası (bildirim
      // bastırıldı). Haptik + döngülü zil.
      unawaited(_efekt.haptik(AramaHaptik.caliyor));
      unawaited(_efekt.zilCal());
      AramaServisi.aktifAramaId = a['arama_id'] as String?;
      final erme = (a['sona_erme'] as num?)?.toInt() ?? 0;
      final kalan = DateTime.fromMillisecondsSinceEpoch(
        erme * 1000,
      ).difference(DateTime.now());
      _sonaErmeSayaci = Timer(
        kalan.isNegative ? Duration.zero : kalan + const Duration(seconds: 1),
        () => _kapat('Cevapsız arama'.c),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _yuklendi = true);
      _kapat('Arama sona erdi'.c);
    }
  }

  void _kapat([String? metin]) {
    unawaited(_efekt.zilDurdur());
    AramaServisi.aktifAramaId = null;
    if (!mounted) return;
    if (metin != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(metin)));
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/sohbetler');
    }
  }

  Future<void> _reddet() async {
    if (_islemde) return;
    setState(() => _islemde = true);
    final d = _denetciKur();
    await d.reddet();
    _kapat();
  }

  GorusmeDenetci _denetciKur() {
    final a = _arama!;
    final arayan = (a['arayan'] as Map?) ?? const {};
    return _denetci ??= GorusmeDenetci(
      surucu: (widget.surucuUret ?? WebrtcSurucu.new)(),
      efekt: _efekt,
      karsiTaraf: arayan['kullanici_adi'] as String? ?? '',
      karsiAvatar: arayan['avatar'] as String?,
      tur: a['tur'] as String? ?? 'ses',
      gelen: true,
      aramaId: a['arama_id'] as String?,
      gelenTeklifSdp: a['sdp'] as String?,
      calmaSaniye: AramaServisi.calmaSaniye,
    );
  }

  Future<void> _cevapla() async {
    if (_islemde) return;
    _sonaErmeSayaci?.cancel();
    // Cevaplandı: zil hemen sussun (denetçi kabul akışını sürdürecek).
    unawaited(_efekt.zilDurdur());
    setState(() {
      _islemde = true;
      _kabulEdildi = true;
    });
  }

  @override
  void dispose() {
    _sonaErmeSayaci?.cancel();
    // Zil sussun ve oynatıcı bırakılsın. Kabul edildiyse denetçi de aynı
    // efekti bırakıyor (idempotent, çift bosalt zararsız); kabul edilmeden
    // ekran kapandıysa (geri tuşu) tek temizlik yeri burasıdır.
    _efekt.bosalt();
    AramaServisi.aktifAramaId = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_kabulEdildi) {
      final d = _denetciKur();
      return GorusmeEkrani(denetci: d, baslat: d.kabulEt);
    }
    final a = _arama;
    final arayan = (a?['arayan'] as Map?) ?? const {};
    final goruntulu = a?['tur'] == 'goruntu';

    return Scaffold(
      backgroundColor: aramaZemin,
      body: SafeArea(
        child: !_yuklendi
            ? const Center(
                child: CircularProgressIndicator(color: DiziRenkler.sari),
              )
            : Column(
                children: [
                  const Spacer(),
                  AramaNabzi(
                    // Gelen arama çalıyor: avatar nabız atsın (zil + haptikle
                    // birlikte). Hareket azaltıldıysa kendiliğinden statik olur.
                    aktif: _yuklendi && _arama != null,
                    cap: 112,
                    child: KullaniciAvatari(
                      url: dosyaUrl(arayan['avatar'] as String?),
                      kullaniciAdi: arayan['kullanici_adi'] as String?,
                      yaricap: 56,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '@${arayan['kullanici_adi'] ?? ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        goruntulu ? Icons.videocam : Icons.call,
                        size: 18,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        goruntulu ? 'Görüntülü arama'.c : 'Sesli arama'.c,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        AramaEylemDugmesi(
                          key: const Key('arama-reddet'),
                          ikon: Icons.call_end,
                          etiket: 'Reddet'.c,
                          zemin: aramaKirmizi,
                          cap: aramaDugmeCapi,
                          onTap: _reddet,
                        ),
                        AramaEylemDugmesi(
                          key: const Key('arama-cevapla'),
                          ikon: goruntulu ? Icons.videocam : Icons.call,
                          etiket: 'Cevapla'.c,
                          zemin: aramaYesil,
                          cap: aramaDugmeCapi,
                          onTap: _cevapla,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
      ),
    );
  }
}
