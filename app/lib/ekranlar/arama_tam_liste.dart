import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'arama_cubugu.dart';
import 'ortak.dart';

/// Aramanın "Daha fazlasını gör" tam listesi: TEK kategori, sonsuz kaydırma.
///
/// Önizleme (`/ara`) TMDB'nin ilk sayfasıyla sınırlıdır; burası kategoriye
/// göre sayfa sayfa yükler:
///  * `icerik`  → `/ara-tur?tur=tv` + `/ara-tur?tur=movie` aynı sayfa
///    numarasıyla birlikte çekilir, popülerliğe göre harmanlanır (bölüm
///    başlığı "Dizi ve Filmler" olduğu için tek listede ikisi de var).
///  * `kisi`    → `/ara-tur?tur=person`.
///  * `kullanici` → `/kullanici-ara?tam=1` — kullanıcı adı YANINDA görünen
///    ad ve bio da aranır ("süleyman" bio'sunda geçen herkes listelenir).
///
/// Önizlemeden farklı olarak POSTERSİZ/FOTOĞRAFSIZ sonuçlar da listelenir:
/// bu ekranın işi "hepsini göster"; görselsiz satır yer tutucu ikonla çıkar.
class AramaTamListeEkrani extends StatefulWidget {
  final String sorgu;

  /// 'icerik' | 'kisi' | 'kullanici'
  final String tur;
  const AramaTamListeEkrani({
    super.key,
    required this.sorgu,
    required this.tur,
  });

  @override
  State<AramaTamListeEkrani> createState() => _AramaTamListeEkraniState();
}

class _AramaTamListeEkraniState extends State<AramaTamListeEkrani> {
  final _kaydirici = ScrollController();
  final List<Map<String, dynamic>> _satirlar = [];

  /// Aynı içerik TMDB'nin ardışık sayfalarında tekrar edebilir; anahtar
  /// `media_type:id` (kullanıcıda `@ad`).
  final _gorulen = <String>{};
  int _sayfa = 0;
  bool _yukleniyor = false;
  bool _devamVar = true;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _kaydirici.addListener(_kaydirildi);
    _sonrakiSayfa();
  }

  @override
  void dispose() {
    _kaydirici.dispose();
    super.dispose();
  }

  void _kaydirildi() {
    if (_kaydirici.position.pixels >
        _kaydirici.position.maxScrollExtent - 400) {
      _sonrakiSayfa();
    }
  }

  Future<void> _sonrakiSayfa() async {
    if (_yukleniyor || !_devamVar) return;
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    final sayfa = _sayfa + 1;
    final q = Uri.encodeComponent(widget.sorgu.trim());
    try {
      List<Map<String, dynamic>> gelen;
      var devam = false;
      if (widget.tur == 'kullanici') {
        final y = await Api.get('/kullanici-ara?q=$q&tam=1&sayfa=$sayfa');
        gelen = ((y['kullanicilar'] as List<dynamic>? ?? []))
            .whereType<Map<String, dynamic>>()
            .toList();
        devam = y['devam_var'] == true;
      } else if (widget.tur == 'kisi') {
        final y = await Api.get('/ara-tur?tur=person&q=$q&sayfa=$sayfa');
        gelen = ((y['results'] as List<dynamic>? ?? []))
            .whereType<Map<String, dynamic>>()
            .toList();
        devam = sayfa < ((y['toplam_sayfa'] as num?)?.toInt() ?? 1);
      } else {
        // Dizi + film aynı sayfa numarasıyla birlikte; popülerliğe göre
        // harmanlanır ki liste "önce tüm diziler sonra tüm filmler" gibi
        // yapay bir sırayla akmasın.
        final y = await Future.wait([
          Api.get('/ara-tur?tur=tv&q=$q&sayfa=$sayfa'),
          Api.get('/ara-tur?tur=movie&q=$q&sayfa=$sayfa'),
        ]);
        gelen =
            [
              ...((y[0]['results'] as List<dynamic>? ?? [])),
              ...((y[1]['results'] as List<dynamic>? ?? [])),
            ].whereType<Map<String, dynamic>>().toList()..sort(
              (a, b) => ((b['popularity'] as num?) ?? 0).compareTo(
                (a['popularity'] as num?) ?? 0,
              ),
            );
        devam =
            sayfa < ((y[0]['toplam_sayfa'] as num?)?.toInt() ?? 1) ||
            sayfa < ((y[1]['toplam_sayfa'] as num?)?.toInt() ?? 1);
      }
      if (!mounted) return;
      setState(() {
        _sayfa = sayfa;
        _devamVar = devam;
        for (final r in gelen) {
          final anahtar = widget.tur == 'kullanici'
              ? '@${r['kullanici_adi']}'
              : '${r['media_type']}:${r['id']}';
          if (_gorulen.add(anahtar)) _satirlar.add(r);
        }
      });
    } catch (_) {
      // Sessiz başarısızlık yok: hata satırı + tekrar dene gösterilir.
      if (mounted) setState(() => _hata = 'Arama başarısız'.c);
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  String get _baslik => switch (widget.tur) {
    'kullanici' => 'Kullanıcılar'.c,
    'kisi' => 'Kişiler'.c,
    _ => 'Dizi ve Filmler'.c,
  };

  Widget _satir(Map<String, dynamic> r) {
    if (widget.tur == 'kullanici') {
      final ad = r['kullanici_adi'] as String;
      final gorunen = (r['ad'] as String?)?.trim() ?? '';
      final bio = (r['bio'] as String?)?.trim() ?? '';
      return AramaSatiri(
        key: Key('tam-kullanici-$ad'),
        gorselUrl: dosyaUrl(r['avatar'] as String?),
        yuvarlak: true,
        kullaniciAdi: ad,
        ad: '@$ad',
        altYazi: [
          if (gorunen.isNotEmpty) gorunen,
          if (bio.isNotEmpty) bio,
        ].join(' · '),
        onTap: () => kullaniciyaGit(context, ad),
      );
    }
    if (widget.tur == 'kisi') {
      return AramaSatiri(
        key: Key('tam-kisi-${r['id']}'),
        gorselUrl: posterUrl(r['profile_path'] as String?, boyut: 'w185'),
        yuvarlak: true,
        ad: (r['name'] ?? '?') as String,
        altYazi: kisiAramaAltYazi(r),
        onTap: () => context.push('/kisi/${r['id']}'),
      );
    }
    return AramaSatiri(
      key: Key('tam-icerik-${r['media_type']}-${r['id']}'),
      gorselUrl: posterUrl(r['poster_path'] as String?, boyut: 'w185'),
      ad: (r['name'] ?? r['title'] ?? '?') as String,
      altYazi: [
        ((r['first_air_date'] ?? r['release_date']) as String? ?? '')
            .split('-')
            .first,
        r['media_type'] == 'tv' ? 'Dizi'.c : 'Film'.c,
      ].where((p) => p.isNotEmpty).join(' · '),
      onTap: () => context.push('/icerik/${r['media_type']}/${r['id']}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget govde;
    if (_satirlar.isEmpty && _yukleniyor) {
      govde = const Center(
        child: CircularProgressIndicator(color: DiziRenkler.sari),
      );
    } else if (_satirlar.isEmpty && _hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _sonrakiSayfa);
    } else if (_satirlar.isEmpty) {
      govde = BosDurum(ikon: Icons.search_off, baslik: 'Sonuç bulunamadı'.c);
    } else {
      govde = OrtaKolon(
        azami: masaustuKolonGenisligi,
        cocuk: ListView.builder(
          controller: _kaydirici,
          padding: EdgeInsets.only(
            top: 8,
            bottom: altGuvenli(context, ekstra: 24),
          ),
          // +1: liste kuyruğu — spinner, hata + tekrar dene veya hiçbir şey.
          itemCount: _satirlar.length + 1,
          itemBuilder: (context, i) {
            if (i < _satirlar.length) return _satir(_satirlar[i]);
            if (_hata != null) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: TextButton(
                    onPressed: _sonrakiSayfa,
                    child: Text(
                      'Tekrar dene'.c,
                      style: TextStyle(color: DiziRenkler.sariMetin),
                    ),
                  ),
                ),
              );
            }
            if (_yukleniyor || _devamVar) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: DiziRenkler.sari,
                    ),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        // Başlık: kategori + tırnak içinde sorgu — kullanıcı hangi aramanın
        // devamına baktığını görür.
        title: Text('$_baslik · "${widget.sorgu.trim()}"'),
      ),
      body: govde,
    );
  }
}
