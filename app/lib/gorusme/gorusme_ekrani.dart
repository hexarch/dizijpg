import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import '../ekranlar/ortak.dart' show KullaniciAvatari;
import 'arama_servisi.dart';
import 'gorusme_api.dart';
import 'gorusme_denetci.dart';
import 'gorusme_surucu.dart';

/// Arama ekranı DAİMA KOYU zeminlidir (tema-duyarlı değil) — Reels ve poster
/// rozetiyle aynı "daima-koyu yüzey" kalıbı. Sebep: görüntülü aramada video
/// karesi zeminin kendisidir; açık temada beyaz bir çerçeve videonun etrafında
/// parlar ve gece yapılan aramada gözü yorar. Bu yüzden buradaki renkler
/// `DiziRenkler` tema geçitlerinden GEÇMEZ, sabittir.
const Color aramaZemin = DiziRenkler.markaKoyu;

/// Kabul (yeşil) ve kapat/reddet (kırmızı) — ÖLÇÜLMÜŞ kontrastlar.
///
/// Etiket rengi beyaz. WCAG 2.1 hesabı (`aramaZemin` = #0B0B0D, L=0.0034):
///   * `aramaYesil` #0F7A38: L=0.1431 → beyaz yazı **5,44:1** (≥4,5 ✓),
///     zemine karşı **3,62:1** (grafik nesne eşiği 3:1 ✓)
///   * `aramaKirmizi` #C62828: L=0.1368 → beyaz yazı **5,62:1** (✓),
///     zemine karşı **3,50:1** (✓)
///
/// Material'ın `Colors.red`/`greenAccent` tonları bu testi GEÇMİYORDU
/// (#E53935 üstünde beyaz yalnız 4,23:1). Sözleşme §14.5 bu ölçümü açıkça
/// istiyor: "koyu zeminde Reddet kontrastı ≥4.5:1 ÖLÇÜLMELİ".
const Color aramaYesil = Color(0xFF0F7A38);
const Color aramaKirmizi = Color(0xFFC62828);

/// Yuvarlak eylem düğmesinin çapı. 44 dp asgari dokunma hedefinin üstünde;
/// arama ekranı yanlış basmanın en pahalı olduğu ekrandır.
const double aramaDugmeCapi = 64;

/// İkincil kontroller (sessize al, hoparlör, kamera) — yine ≥44 dp.
const double aramaKucukDugmeCapi = 56;

/// Süreyi `s:dd` / `sa:dd:ss` biçimine çevirir.
String aramaSuresiMetni(Duration d) {
  final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  final dd = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  if (d.inHours > 0) return '${d.inHours}:$dd:$ss';
  return '${d.inMinutes}:$ss';
}

/// Metin etiketli yuvarlak eylem düğmesi.
///
/// **İkon-tek düğme YASAK** (`ui-ux-pro-max` öncelik 1, Accessibility →
/// "Icon-only buttons without labels"): "Cevapla" ile "Reddet"i yalnız renkten
/// ayırt etmek renk körü kullanıcı için kumardır ve ekran okuyucuya hiçbir şey
/// söylemez. Etiket hem görünür hem `Semantics` etiketi olarak verilir.
class AramaEylemDugmesi extends StatelessWidget {
  const AramaEylemDugmesi({
    super.key,
    required this.ikon,
    required this.etiket,
    required this.onTap,
    this.zemin,
    this.cap = aramaKucukDugmeCapi,
    this.secili = false,
  });

  final IconData ikon;
  final String etiket;
  final VoidCallback onTap;
  final Color? zemin;
  final double cap;

  /// Aç/kapa kontrollerinde açık hâl (sessize alındı, hoparlör açık...).
  final bool secili;

  @override
  Widget build(BuildContext context) {
    final dolgu = zemin ?? (secili ? Colors.white : Colors.white24);
    final onRenk = zemin != null
        ? Colors.white
        : (secili ? aramaZemin : Colors.white);
    return Semantics(
      button: true,
      label: etiket,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: dolgu,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: cap,
                height: cap,
                child: Icon(ikon, color: onRenk, size: cap * 0.42),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Genişlik sınırı: uzun çevirilerde ("Kamerayı çevir" → Almanca)
          // etiket komşu düğmenin altına taşmasın.
          SizedBox(
            width: cap + 24,
            child: Text(
              etiket,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Giden/kurulmuş arama ekranı. Gelen arama kabul edilince de buraya geçilir.
class GorusmeEkrani extends StatefulWidget {
  const GorusmeEkrani({super.key, required this.denetci, required this.baslat});

  final GorusmeDenetci denetci;

  /// Ekran kurulunca çalışacak akış: giden aramada `aramaBaslat`, gelen
  /// aramada `kabulEt`. Ekran ikisini de aynı biçimde çizer.
  final Future<AramaHatasi?> Function(BuzAyari buz) baslat;

  @override
  State<GorusmeEkrani> createState() => _GorusmeEkraniState();
}

class _GorusmeEkraniState extends State<GorusmeEkrani> {
  bool _kapandi = false;

  @override
  void initState() {
    super.initState();
    widget.denetci.addListener(_degisti);
    WidgetsBinding.instance.addPostFrameCallback((_) => _basla());
  }

  Future<void> _basla() async {
    final buz = await AramaServisi.buzHazirla();
    if (!mounted) return;
    if (buz == null || !buz.aramaAcik) {
      _kapat('Arama şu anda kullanılamıyor'.c, hata: true);
      return;
    }
    AramaServisi.aktifAramaId = widget.denetci.aramaId ?? 'baslatiliyor';
    final hata = await widget.baslat(buz);
    if (!mounted) return;
    AramaServisi.aktifAramaId = widget.denetci.aramaId;
    if (hata != null) _kapat(hata.metin, hata: true);
  }

  void _degisti() {
    if (!mounted) return;
    if (widget.denetci.durum == GorusmeDurum.bitti && !_kapandi) {
      _kapat(widget.denetci.sonucMetni, hata: widget.denetci.sonucHata);
      return;
    }
    setState(() {});
  }

  void _kapat(String? metin, {bool hata = false}) {
    if (_kapandi) return;
    _kapandi = true;
    AramaServisi.aktifAramaId = null;
    if (metin != null && metin.isNotEmpty) {
      // ÜÇ HALİN ÜÇÜNCÜSÜ: her kapanış nedeni kullanıcıya söylenir.
      // Sessiz başarısızlık arama ekranında kabul edilemez (sözleşme §14.5).
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(metin),
          backgroundColor: hata ? aramaKirmizi : null,
        ),
      );
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/sohbet/${widget.denetci.karsiTaraf}');
    }
  }

  @override
  void dispose() {
    widget.denetci.removeListener(_degisti);
    // Ekran her yolla kapanabilir (geri tuşu, tarayıcı geri, rota değişimi);
    // aramayı kapatmayı YALNIZ "Kapat" düğmesine bağlamak hayalet arama
    // bırakırdı — karşı taraf 4 saat boyunca "aramada" görünürdü.
    widget.denetci.kapat();
    widget.denetci.dispose();
    AramaServisi.aktifAramaId = null;
    super.dispose();
  }

  String get _durumMetni {
    switch (widget.denetci.durum) {
      case GorusmeDurum.hazirlaniyor:
      case GorusmeDurum.baglaniyor:
        return 'Bağlanıyor...'.c;
      case GorusmeDurum.caliyor:
        return 'Çalıyor...'.c;
      case GorusmeDurum.konusuyor:
        return aramaSuresiMetni(widget.denetci.sure);
      case GorusmeDurum.bitti:
        return widget.denetci.sonucMetni ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.denetci;
    final goruntulu = d.tur == 'goruntu';
    final uzak = goruntulu ? d.surucu.gorunum(yerel: false) : null;
    final yerel = goruntulu ? d.surucu.gorunum(yerel: true) : null;

    return PopScope(
      // Geri tuşu aramayı kapatır; onay sormaz (arama ekranında modal onay
      // kullanıcıyı konuşurken kilitlerdi). `dispose` zaten `kapat()` çağırıyor.
      canPop: true,
      child: Scaffold(
        backgroundColor: aramaZemin,
        body: Stack(
          fit: StackFit.expand,
          children: [
            ?uzak,
            // Video varken üstündeki yazılar okunsun diye koyu perde.
            if (uzak != null)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black54,
                      Colors.transparent,
                      Colors.black87,
                    ],
                    stops: [0, 0.4, 1],
                  ),
                ),
              ),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  if (uzak == null) ...[
                    KullaniciAvatari(
                      url: dosyaUrl(d.karsiAvatar),
                      kullaniciAdi: d.karsiTaraf,
                      yaricap: 52,
                    ),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    '@${d.karsiTaraf}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (d.durum == GorusmeDurum.hazirlaniyor ||
                          d.durum == GorusmeDurum.baglaniyor) ...[
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: DiziRenkler.sari,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        _durumMetni,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  if (d.sureUyarisi) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        // Sözleşme §13.2: kurulmuş aramaya 4 saatlik SERT üst
                        // sınır var. Kullanıcı bunu ÖNCEDEN bilmeli, arama
                        // aniden kesilmiş gibi görünmesin.
                        'Arama en fazla 4 saat sürebilir'.c,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: DiziRenkler.sari,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (goruntulu && yerel != null)
                    // Yerel önizleme (PiP). `Stack` SINIRLARININ İÇİNDE:
                    // dışarı taşan `Positioned` görünür ama TIKLANAMAZ olurdu
                    // (proje skill'i madde 2, sözleşme §14.5).
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16, bottom: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 100,
                            height: 140,
                            child: d.kameraAcik
                                ? yerel
                                : const ColoredBox(
                                    color: Colors.black45,
                                    child: Icon(
                                      Icons.videocam_off,
                                      color: Colors.white54,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  _Kontroller(denetci: d, goruntulu: goruntulu),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Kontroller extends StatelessWidget {
  const _Kontroller({required this.denetci, required this.goruntulu});

  final GorusmeDenetci denetci;
  final bool goruntulu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        // 8 dp asgarinin üstünde: yanlışlıkla "Kapat"a basmak pahalıdır.
        spacing: 18,
        runSpacing: 16,
        children: [
          AramaEylemDugmesi(
            key: const Key('arama-sessize'),
            ikon: denetci.sessiz ? Icons.mic_off : Icons.mic,
            etiket: 'Sessize al'.c,
            secili: denetci.sessiz,
            onTap: denetci.sessizDegistir,
          ),
          AramaEylemDugmesi(
            key: const Key('arama-hoparlor'),
            ikon: denetci.hoparlor ? Icons.volume_up : Icons.hearing,
            etiket: 'Hoparlör'.c,
            secili: denetci.hoparlor,
            onTap: denetci.hoparlorDegistir,
          ),
          if (goruntulu) ...[
            AramaEylemDugmesi(
              key: const Key('arama-kamera'),
              ikon: denetci.kameraAcik ? Icons.videocam : Icons.videocam_off,
              etiket: 'Kamerayı kapat'.c,
              secili: !denetci.kameraAcik,
              onTap: denetci.kameraDegistir,
            ),
            AramaEylemDugmesi(
              key: const Key('arama-kamera-cevir'),
              ikon: Icons.cameraswitch,
              etiket: 'Kamerayı çevir'.c,
              onTap: denetci.kamerayiCevir,
            ),
          ],
          AramaEylemDugmesi(
            key: const Key('arama-kapat'),
            ikon: Icons.call_end,
            etiket: 'Kapat'.c,
            zemin: aramaKirmizi,
            cap: aramaDugmeCapi,
            onTap: () => denetci.kapat(),
          ),
        ],
      ),
    );
  }
}

/// Giden aramayı başlatan rota ekranı (`/gorusme/:ad`).
class GidenAramaSayfasi extends StatefulWidget {
  const GidenAramaSayfasi({
    super.key,
    required this.kullaniciAdi,
    required this.tur,
    this.avatar,
    this.surucuUret,
  });

  final String kullaniciAdi;
  final String tur;
  final String? avatar;

  /// YALNIZ TEST: sahte sürücü tak.
  final GorusmeSurucu Function()? surucuUret;

  @override
  State<GidenAramaSayfasi> createState() => _GidenAramaSayfasiState();
}

class _GidenAramaSayfasiState extends State<GidenAramaSayfasi> {
  late final GorusmeDenetci _denetci = GorusmeDenetci(
    surucu: (widget.surucuUret ?? WebrtcSurucu.new)(),
    karsiTaraf: widget.kullaniciAdi,
    karsiAvatar: widget.avatar,
    tur: widget.tur,
    gelen: false,
    calmaSaniye: AramaServisi.calmaSaniye,
  );

  @override
  Widget build(BuildContext context) =>
      GorusmeEkrani(denetci: _denetci, baslat: _denetci.aramaBaslat);
}
