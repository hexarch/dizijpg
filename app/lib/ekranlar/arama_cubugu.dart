import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'ortak.dart';

/// Masaüstü üst barının yüksekliği.
const double masaustuUstBarYuksekligi = 64;

/// Masaüstü üst barında arama kutusunun İKİ YANINDA bırakılan pay: solda marka
/// bloğu, sağda eylem ikonları bu payın içinde durur. Kutu genişliği buna göre
/// hesaplandığı için kutu TAM ORTADA kalırken marka/eylemlerle ÇAKIŞMAZ.
const double masaustuUstBarKenarPayi = 230;

/// Masaüstünde arama kutusunun azami genişliği (720 masaüstünde şişkin duruyor).
const double masaustuAramaGenisligi = 560;

/// Sayfanın üstüne satır-içi arama çubuğu ekleyen sarmalayıcı.
///
/// Akış ve Ana Sayfa AYNI bileşeni kullanır; kopyalansaydı birinde
/// düzeltilen hata ötekinde kalırdı. Sorgu 2 karakterden kısayken [cocuk]
/// gösterilir, uzunsa sonuçlar listelenir.
///
/// MASAÜSTÜNDE (genişlik >= [masaustuEsigi]) bileşen sayfanın üst barını da
/// üstlenir: arama kutusu EKRANIN EN ÜSTÜNDE ve TAM ORTASINDA durur, [logo]
/// solda, [eylemler] sağda kalır. Bu yüzden çağıran ekran masaüstünde kendi
/// AppBar'ını kurmaz, marka bloğunu ve eylem ikonlarını buraya verir.
/// Dar ekranda [logo]/[eylemler] YOK SAYILIR ve düzen birebir eskisi gibidir.
class AramaCubugu extends StatefulWidget {
  final Widget cocuk;
  final Widget? logo;
  final List<Widget> eylemler;
  const AramaCubugu({
    super.key,
    required this.cocuk,
    this.logo,
    this.eylemler = const [],
  });

  @override
  State<AramaCubugu> createState() => _AramaCubuguState();
}

class _AramaCubuguState extends State<AramaCubugu> {
  // Satır-içi arama: sonuçlar modal/ayrı sayfa yerine çubuğun altında listelenir
  final _aramaKutu = TextEditingController();
  Timer? _aramaGecikme;
  String _sorgu = '';
  bool _araniyor = false;
  List<dynamic> _aramaIcerik = []; // dizi + film
  List<dynamic> _aramaKisiler = []; // oyuncu/yönetmen (TMDB)
  List<dynamic> _aramaKullanicilar = []; // uygulama kullanıcıları
  String? _duzeltme; // "şunu mu demek istedin" — sunucu yazım düzeltmesi

  @override
  void dispose() {
    _aramaGecikme?.cancel();
    _aramaKutu.dispose();
    super.dispose();
  }

  void _aramaDegisti(String s) {
    setState(() => _sorgu = s);
    _aramaGecikme?.cancel();
    if (s.trim().length < 2) return;
    _aramaGecikme = Timer(const Duration(milliseconds: 450), () => _ara(s));
  }

  Future<void> _ara(String sorgu) async {
    setState(() => _araniyor = true);
    try {
      final q = Uri.encodeComponent(sorgu.trim());
      final y = await Future.wait([
        Api.get('/ara?q=$q'),
        Api.get('/kullanici-ara?q=$q').catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted || _sorgu.trim() != sorgu.trim()) return;
      final sonuclar = (y[0]['results'] as List<dynamic>? ?? []);
      // Sunucu yazım hatasını düzeltip "duzeltme" döndürdüyse başlıkta göster
      final d = y[0]['duzeltme'] as String?;
      setState(() {
        _duzeltme = (d != null && d.toLowerCase() != sorgu.trim().toLowerCase())
            ? d
            : null;
        _aramaIcerik = sonuclar
            .where(
              (r) => r['media_type'] != 'person' && r['poster_path'] != null,
            )
            .toList();
        _aramaKisiler = sonuclar
            .where(
              (r) => r['media_type'] == 'person' && r['profile_path'] != null,
            )
            .toList();
        _aramaKullanicilar = y[1]['kullanicilar'] as List<dynamic>? ?? [];
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _araniyor = false);
    }
  }

  /// Arama kutusunun kendisi (mobil ve masaüstü aynı kutuyu kullanır).
  Widget _aramaKutusu() => TextField(
    controller: _aramaKutu,
    onChanged: _aramaDegisti,
    decoration: InputDecoration(
      hintText: 'Dizi, film veya kişi ara...'.c,
      prefixIcon: Icon(Icons.search, color: DiziRenkler.metin54),
      suffixIcon: _araniyor
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: DiziRenkler.sari,
                ),
              ),
            )
          : (_sorgu.isNotEmpty
                ? IconButton(
                    tooltip: 'Kapat'.c,
                    icon: Icon(Icons.close, color: DiziRenkler.metin54),
                    onPressed: () {
                      _aramaKutu.clear();
                      setState(() => _sorgu = '');
                    },
                  )
                : null),
    ),
  );

  /// Masaüstü üst barı: arama kutusu ekran genişliğinin TAM ORTASINDA
  /// (Stack + Center → sol boşluk = sağ boşluk), marka solda, eylemler sağda.
  /// Positioned'lar Stack SINIRI İÇİNDE — dışarı taşan Positioned tıklanamaz.
  Widget _masaustuUstBar(double ekranGenisligi) {
    final kutuGenisligi = (ekranGenisligi - masaustuUstBarKenarPayi * 2).clamp(
      320.0,
      masaustuAramaGenisligi,
    );
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: masaustuUstBarYuksekligi,
        child: Stack(
          children: [
            Center(
              child: SizedBox(width: kutuGenisligi, child: _aramaKutusu()),
            ),
            if (widget.logo != null)
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(child: widget.logo!),
              ),
            if (widget.eylemler.isNotEmpty)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.eylemler,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ekranGenisligi = MediaQuery.sizeOf(context).width;
    return Column(
      children: [
        // Satır-içi arama: dizi/film/kişi + kullanıcılar; sonuçlar
        // modal yerine çubuğun hemen altında listelenir
        if (ekranGenisligi >= masaustuEsigi)
          _masaustuUstBar(ekranGenisligi)
        else
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: _aramaKutusu(),
              ),
            ),
          ),
        Expanded(
          child: _sorgu.trim().length >= 2 ? _aramaSonuclari() : widget.cocuk,
        ),
      ],
    );
  }

  /// Arama sonuçları: çubuğun altında bölümlü, satır tabanlı liste.
  Widget _aramaSonuclari() {
    final bos =
        _aramaKullanicilar.isEmpty &&
        _aramaIcerik.isEmpty &&
        _aramaKisiler.isEmpty;
    if (bos && !_araniyor) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 44, color: DiziRenkler.metin24),
            const SizedBox(height: 10),
            Text(
              'Sonuç bulunamadı'.c,
              style: TextStyle(color: DiziRenkler.metin54),
            ),
          ],
        ),
      );
    }
    Widget baslik(IconData ikon, String metin) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          Icon(ikon, size: 17, color: DiziRenkler.sariMetin),
          const SizedBox(width: 6),
          Text(
            metin,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (_duzeltme != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 13, color: DiziRenkler.metin54),
                    children: [
                      TextSpan(text: '${'Şunu mu demek istedin'.c}: '),
                      TextSpan(
                        text: _duzeltme,
                        style: TextStyle(
                          color: DiziRenkler.sariMetin,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_aramaKullanicilar.isNotEmpty) ...[
              baslik(Icons.people_outline, 'Kullanıcılar'.c),
              for (final k in _aramaKullanicilar.take(6))
                _AramaSatiri(
                  gorselUrl: dosyaUrl(
                    (k as Map<String, dynamic>)['avatar'] as String?,
                  ),
                  yuvarlak: true,
                  kullaniciAdi: k['kullanici_adi'] as String?,
                  ad: '@${k['kullanici_adi']}',
                  altYazi: (k['bio'] as String?) ?? '',
                  onTap: () =>
                      kullaniciyaGit(context, k['kullanici_adi'] as String),
                ),
            ],
            if (_aramaIcerik.isNotEmpty) ...[
              baslik(Icons.local_movies_outlined, 'Dizi ve Filmler'.c),
              for (final r in _aramaIcerik.take(12))
                _AramaSatiri(
                  gorselUrl: posterUrl(
                    (r as Map<String, dynamic>)['poster_path'] as String?,
                    boyut: 'w185',
                  ),
                  ad: (r['name'] ?? r['title'] ?? '?') as String,
                  altYazi: [
                    ((r['first_air_date'] ?? r['release_date']) as String? ??
                            '')
                        .split('-')
                        .first,
                    r['media_type'] == 'tv' ? 'Dizi'.c : 'Film'.c,
                  ].where((p) => p.isNotEmpty).join(' · '),
                  onTap: () =>
                      context.push('/icerik/${r['media_type']}/${r['id']}'),
                ),
            ],
            if (_aramaKisiler.isNotEmpty) ...[
              baslik(Icons.person_outline, 'Kişiler'.c),
              for (final r in _aramaKisiler.take(8))
                _AramaSatiri(
                  gorselUrl: posterUrl(
                    (r as Map<String, dynamic>)['profile_path'] as String?,
                    boyut: 'w185',
                  ),
                  yuvarlak: true,
                  ad: (r['name'] ?? '?') as String,
                  altYazi: '',
                  onTap: () => context.push('/kisi/${r['id']}'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Arama sonucu satırı: küçük görsel (poster ya da yuvarlak avatar) +
/// ad + alt bilgi. Tüm ekran boylarında aynı düzen.
class _AramaSatiri extends StatelessWidget {
  final String? gorselUrl;
  final bool yuvarlak;
  final String ad;
  final String altYazi;
  final VoidCallback onTap;
  final String? kullaniciAdi; // kullanıcı satırlarında AI rozeti için
  const _AramaSatiri({
    required this.gorselUrl,
    this.yuvarlak = false,
    required this.ad,
    required this.altYazi,
    required this.onTap,
    this.kullaniciAdi,
  });

  @override
  Widget build(BuildContext context) {
    final gorsel = gorselUrl == null
        ? Container(
            color: DiziRenkler.kart,
            child: Icon(
              yuvarlak ? Icons.person : Icons.movie_outlined,
              color: DiziRenkler.metin38,
              size: 20,
            ),
          )
        : CachedNetworkImage(imageUrl: gorselUrl!, fit: BoxFit.cover);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            yuvarlak
                ? KullaniciAvatari(
                    url: gorselUrl,
                    kullaniciAdi: kullaniciAdi,
                    yaricap: 22,
                    arkaplan: DiziRenkler.kart,
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(width: 40, height: 56, child: gorsel),
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ad,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (altYazi.isNotEmpty)
                    Text(
                      altYazi,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: DiziRenkler.metin54,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: DiziRenkler.metin38),
          ],
        ),
      ),
    );
  }
}
