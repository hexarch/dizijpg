import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import '../gorsel_basliklari.dart';
import '../tema.dart';
import 'bolum_sec.dart';
import 'giris_istem.dart';
import 'icerik_sec.dart';
import 'medya_inceleme.dart';
import '../medya_yukle.dart';

/// AKIŞTAN PAYLAŞIM — "izlediğin dizi/film hakkında yorum paylaş".
///
/// KULLANICI İSTEĞİ (28 Ağu 2026, birebir): "akışta üst barın altında sol
/// tarafta profil resmi ortada input alanı … tıklayınca alttan modal aç ve
/// paylaşım ekranını aç ama şunu unutma dizi ve film eklemek zorunda paylaşım
/// yapmak için ve dizinin bölümünü de seçebilir … paylaştığı şey ilgili dizi
/// filmin profilinde gözükmeli … varolan yorum yapma alanımızı akışta da
/// yazıyoruz gibi bir şey olmalı".
///
/// ---------------------------------------------------------------------------
/// SUNUCU DEĞİŞİKLİĞİ GEREKMEDİ — ve bu tesadüf değil
/// ---------------------------------------------------------------------------
/// Buradan giden şey YENİ bir "gönderi" türü DEĞİL, sıradan bir YORUM:
/// `POST /yorumlar` zaten `tur` + `tmdb_id` (+ isteğe bağlı `sezon`/`bolum`)
/// alıyor. Yani paylaşım otomatik olarak:
///   · dizi/film sayfasının yorumlarında (`/icerik/<tur>/<id>`),
///   · bölüm seçildiyse O BÖLÜMÜN yorumlarında,
///   · ve akışta
/// aynı anda görünür. Ayrı bir "paylaşım" tablosu açsaydık aynı metni iki
/// yerde tutmak ve senkron kalmasını ummak gerekirdi.
///
/// İÇERİK ZORUNLU: `_gonderilebilir` hem içeriği hem metni arar. Sunucu da
/// `tmdb_id`siz yorum kabul etmiyor; buradaki kapı kullanıcıya HATA yerine
/// kapalı bir düğme göstermek için — sebebi de düğmenin altında yazıyor.
class PaylasYorumSheet extends StatefulWidget {
  const PaylasYorumSheet({super.key});

  @override
  State<PaylasYorumSheet> createState() => _PaylasYorumSheetState();
}

class _PaylasYorumSheetState extends State<PaylasYorumSheet> {
  final _metin = TextEditingController();
  final _odak = FocusNode();

  /// Seçilen TMDB kaydı (`icerikSecAc` döndürüyor).
  Map<String, dynamic>? _icerik;

  /// Dizi seçildiyse isteğe bağlı bölüm: `{sezon, bolum, ad}`.
  Map<String, dynamic>? _bolum;

  final List<Map<String, dynamic>> _ekler = []; // {yol, video}
  bool _ekYukleniyor = false;
  int _ekToplam = 0;
  int _ekBiten = 0;
  bool _spoiler = false;
  bool _gonderiliyor = false;

  bool get _dizi => _icerik?['media_type'] == 'tv';
  String get _icerikAdi =>
      (_icerik?['name'] ?? _icerik?['title'] ?? '') as String;

  @override
  void initState() {
    super.initState();
    _metin.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _metin.dispose();
    _odak.dispose();
    super.dispose();
  }

  bool get _gonderilebilir =>
      _icerik != null &&
      _metin.text.trim().isNotEmpty &&
      !_gonderiliyor &&
      !_ekYukleniyor;

  Future<void> _icerikSec() async {
    final secim = await icerikSecAc(context);
    if (secim == null || !mounted) return;
    setState(() {
      _icerik = secim;
      // İçerik değişince eski bölüm seçimi ANLAMINI YİTİRİR: Silo 2x2 seçip
      // sonra filme geçen kullanıcının yorumu yanlış bölüme bağlanırdı.
      _bolum = null;
    });
  }

  Future<void> _bolumSec() async {
    final id = _icerik?['id'];
    if (id is! int) return;
    final secim = await bolumSecAc(context, diziId: id, diziAd: _icerikAdi);
    if (secim == null || !mounted) return;
    // `{}` = "bölüm seçme" (temizle) anlamına gelir.
    setState(() => _bolum = secim.isEmpty ? null : secim);
  }

  Future<void> _ekSec() async {
    if (!girisGerekli(context)) return;
    final kalan = 10 - _ekler.length;
    if (kalan <= 0 || _ekYukleniyor) return;
    final secim = await medyaSec(context, azami: kalan);
    if (secim.isEmpty || !mounted) return;
    setState(() {
      _ekYukleniyor = true;
      _ekToplam = secim.length;
      _ekBiten = 0;
    });
    final sonuc = await medyalariYukle(
      secim,
      adim: (biten) {
        if (mounted) setState(() => _ekBiten = biten);
      },
    );
    if (!mounted) return;
    setState(() {
      _ekler.addAll(sonuc.yuklenen);
      _ekYukleniyor = false;
    });
    if (sonuc.hata != null) _uyar(sonuc.hata!);
  }

  void _uyar(String mesaj) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(mesaj)));

  Future<void> _gonder() async {
    if (!_gonderilebilir) return;
    if (!girisGerekli(context)) return;
    setState(() => _gonderiliyor = true);
    try {
      await Api.post('/yorumlar', {
        'tur': _icerik!['media_type'],
        'tmdb_id': _icerik!['id'],
        if (_bolum != null) 'sezon': _bolum!['sezon'],
        if (_bolum != null) 'bolum': _bolum!['bolum'],
        'metin': _metin.text.trim(),
        'medya': _ekler.map((e) => e['yol']).toList(),
        'spoiler': _spoiler,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _gonderiliyor = false);
        _uyar(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Görsel alanı TÜRE GÖRE değişiyor (afiş / profil / logo).
    final poster = _icerik == null
        ? null
        : posterUrl(tmdbGorselYolu(_icerik!), boyut: 'w92');
    return Padding(
      // Klavye açıkken kutu klavyenin ÜSTÜNDE kalsın.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Paylaş'.c,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: DiziRenkler.metin,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Kapat'.c,
                    icon: Icon(Icons.close, color: DiziRenkler.metin),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              // ---- İÇERİK (ZORUNLU) ----
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _icerikSec,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 38,
                          height: 56,
                          child: poster != null
                              ? CachedNetworkImage(
                                  imageUrl: poster,
                                  httpHeaders: gorselBasliklari(poster),
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: DiziRenkler.kart,
                                  child: Icon(
                                    Icons.movie_outlined,
                                    color: DiziRenkler.metin38,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _icerik == null
                                  ? 'Yapım seç (zorunlu)'.c
                                  : _icerikAdi,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _icerik == null
                                    ? DiziRenkler.metin54
                                    : DiziRenkler.metin,
                              ),
                            ),
                            // Tür etiketi: aynı ad hem dizi hem film olabilir
                            // ("Superman"), kullanıcı NEYİ bağladığını görsün.
                            if (_icerik != null)
                              Text(
                                tmdbTurEtiketi(
                                  _icerik!['media_type'] as String?,
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: DiziRenkler.metin38,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: DiziRenkler.metin38),
                    ],
                  ),
                ),
              ),
              // ---- BÖLÜM (İSTEĞE BAĞLI, YALNIZ DİZİDE) ----
              if (_dizi)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _bolumSec,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.playlist_add_check,
                          size: 20,
                          color: DiziRenkler.sariMetin,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _bolum == null
                                ? 'Bölüm seç (isteğe bağlı)'.c
                                : '{}. sezon {}. bölüm'.cf([
                                    '${_bolum!['sezon']}',
                                    '${_bolum!['bolum']}',
                                  ]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: _bolum == null
                                  ? DiziRenkler.metin54
                                  : DiziRenkler.metin,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: DiziRenkler.metin38),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              // ---- METİN ----
              TextField(
                controller: _metin,
                focusNode: _odak,
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
                style: TextStyle(color: DiziRenkler.metin),
                decoration: InputDecoration(
                  hintText: 'Ne düşünüyorsun?'.c,
                  border: const OutlineInputBorder(),
                ),
              ),
              // ---- EKLER ----
              if (_ekYukleniyor)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '{}/{} yükleniyor'.cf(['$_ekBiten', '$_ekToplam']),
                    style: TextStyle(fontSize: 12, color: DiziRenkler.metin54),
                  ),
                ),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Fotoğraf/video ekle'.c,
                    onPressed: _ekYukleniyor ? null : _ekSec,
                    icon: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: DiziRenkler.sariMetin,
                    ),
                  ),
                  if (_ekler.isNotEmpty)
                    Text(
                      '${_ekler.length}',
                      style: TextStyle(color: DiziRenkler.metin54),
                    ),
                  const SizedBox(width: 6),
                  // Spoiler işareti: içerik sayfasındaki yorum kutusuyla aynı.
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _spoiler = !_spoiler),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _spoiler
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            size: 18,
                            color: _spoiler
                                ? DiziRenkler.sariMetin
                                : DiziRenkler.metin38,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Spoiler'.c,
                            style: TextStyle(
                              fontSize: 12,
                              color: DiziRenkler.metin54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _gonderilebilir ? _gonder : null,
                    child: _gonderiliyor
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('Paylaş'.c),
                  ),
                ],
              ),
              // Düğme neden kapalı: kullanıcı tahmin etmesin.
              if (_icerik == null)
                Text(
                  'Paylaşmak için önce bir yapım seç.'.c,
                  style: TextStyle(fontSize: 12, color: DiziRenkler.metin54),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paylaşım sayfasını açar. Paylaşım yapıldıysa `true` döner (çağıran akışı
/// tazelesin diye).
Future<bool> paylasYorumAc(BuildContext context) async {
  final sonuc = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DiziRenkler.koyuGri,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => const PaylasYorumSheet(),
  );
  return sonuc == true;
}
