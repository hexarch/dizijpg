import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'ortak.dart';

/// Katalog "Gözat": dizi/film seç, türe göre süz, popülerlik sırasına göre
/// poster ızgarası (sonsuz kaydırma). İçerik EKLEMENİN keşif yolu — kullanıcı
/// ne aradığını bilmese de gezip bulabilir.
/// Gözat adresi. Tür çipini ÖN SEÇİLİ açar.
///
/// NEDEN ADRESE YAZILIYOR (19 Ağu 2026): içerik sayfasındaki tür etiketlerine
/// dokununca burası açılıyor. Seçimi yalnız yapıcıya verseydik F5 kullanıcıyı
/// "Tümü"ne düşürürdü ve bağlantı paylaşılamazdı.
String gozatYolu({String? tur, int? genre}) {
  final q = <String>[
    if (tur == 'tv' || tur == 'movie') 'tur=$tur',
    if (genre != null) 'genre=$genre',
  ];
  return q.isEmpty ? '/gozat' : '/gozat?${q.join('&')}';
}

class GozatEkrani extends StatefulWidget {
  /// Açılışta seçili dizi/film ('tv' | 'movie'); null → 'tv'.
  final String? baslangicTuru;

  /// Açılışta seçili TMDB tür kimliği; null → "Tümü".
  final int? baslangicGenre;

  const GozatEkrani({super.key, this.baslangicTuru, this.baslangicGenre});

  @override
  State<GozatEkrani> createState() => _GozatEkraniState();
}

class _GozatEkraniState extends State<GozatEkrani> {
  late String _tur; // 'tv' | 'movie'
  List<dynamic> _turler = []; // TMDB genre listesi
  int? _seciliGenre; // null = tümü (popüler)
  final List<dynamic> _sonuc = [];
  int _sayfa = 1;
  bool _yukleniyor = false;
  bool _dahaVar = true;
  String? _hata;
  final _kaydirma = ScrollController();
  final _cipKaydirma = ScrollController();

  @override
  void initState() {
    super.initState();
    _tur = widget.baslangicTuru == 'movie' ? 'movie' : 'tv';
    _seciliGenre = widget.baslangicGenre;
    _turleriYukle();
    _yukle(ilk: true);
    _kaydirma.addListener(() {
      if (_kaydirma.position.pixels >
          _kaydirma.position.maxScrollExtent - 600) {
        _yukle();
      }
    });
  }

  @override
  void dispose() {
    _kaydirma.dispose();
    _cipKaydirma.dispose();
    super.dispose();
  }

  Future<void> _turleriYukle() async {
    try {
      final d = await Api.get('/tmdb/genre/$_tur/list');
      if (mounted) {
        setState(() => _turler = d['genres'] as List<dynamic>? ?? []);
        _seciliCipeKaydir();
      }
    } catch (_) {
      /* tür çipleri gelmezse ızgara yine çalışır */
    }
  }

  /// Seçili çipi görünür yap. Çip genişlikleri değişken olduğu için ölçmek
  /// yerine YAKLAŞIK bir konum kullanılıyor (ortalama çip ~96 px): amaç
  /// piksel hassasiyeti değil, "seçili çip ekranda olsun".
  void _seciliCipeKaydir() {
    if (_seciliGenre == null || _turler.isEmpty) return;
    final i = _turler.indexWhere((t) => t['id'] == _seciliGenre);
    if (i < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_cipKaydirma.hasClients) return;
      final hedef = (i * 96.0).clamp(
        0.0,
        _cipKaydirma.position.maxScrollExtent,
      );
      _cipKaydirma.jumpTo(hedef);
    });
  }

  Future<void> _yukle({bool ilk = false}) async {
    if (_yukleniyor || (!ilk && !_dahaVar)) return;
    setState(() {
      _yukleniyor = true;
      if (ilk) _hata = null;
    });
    try {
      final genreQ = _seciliGenre != null ? '&with_genres=$_seciliGenre' : '';
      final d = await Api.get(
        '/tmdb/discover/$_tur?sort_by=popularity.desc'
        '&vote_count.gte=80&page=$_sayfa$genreQ',
      );
      if (!mounted) return;
      final yeni = (d['results'] as List<dynamic>? ?? [])
          .where((r) => r['poster_path'] != null)
          .toList();
      setState(() {
        _sonuc.addAll(yeni);
        _sayfa++;
        _dahaVar = yeni.isNotEmpty && _sayfa <= 500; // TMDB sayfa tavanı
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        if (ilk) _hata = e.toString();
      });
    }
  }

  /// Tür/dizi-film değişince listeyi sıfırla ve baştan yükle.
  void _sifirlaYukle() {
    setState(() {
      _sonuc.clear();
      _sayfa = 1;
      _dahaVar = true;
    });
    _yukle(ilk: true);
  }

  void _turDegis(String tur) {
    if (tur == _tur) return;
    setState(() {
      _tur = tur;
      _seciliGenre = null;
      _turler = [];
    });
    _turleriYukle();
    _sifirlaYukle();
  }

  @override
  Widget build(BuildContext context) {
    // Sütun sayısı artık burada hesaplanmıyor: [PosterIzgarasi] ızgaranın
    // ÖLÇÜLEN genişliğinden türetiyor (dolgu/boşluk dahil), MediaQuery tahmini
    // ve sabit basamaklar (3/4/6) gerekmiyor.
    return Scaffold(
      appBar: AppBar(
        title: Text('Gözat'.c),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              // Dizi / Film seçimi
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SegmentedButton<String>(
                  // FittedBox: uzun çeviri dar hücrede satır kırmaz,
                  // sığmazsa yazı küçülür (ayarlar tema seçicisiyle aynı
                  // "Syste/m" ailesi).
                  segments: [
                    ButtonSegment(
                      value: 'tv',
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Diziler'.c, maxLines: 1, softWrap: false),
                      ),
                    ),
                    ButtonSegment(
                      value: 'movie',
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Filmler'.c, maxLines: 1, softWrap: false),
                      ),
                    ),
                  ],
                  selected: {_tur},
                  onSelectionChanged: (s) => _turDegis(s.first),
                ),
              ),
              // Tür çipleri
              SizedBox(
                height: 40,
                child: ListView(
                  // Dışarıdan seçili gelen çip listenin ORTALARINDA olabilir
                  // (Dram 18, Bilim Kurgu 878...). Denetleyici, çip listesi
                  // dolduğunda o çipi görünür kılmak için kullanılır — yoksa
                  // kullanıcı "Gözat" açılınca hangi türde olduğunu göremezdi.
                  controller: _cipKaydirma,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text('Tümü'.c),
                        selected: _seciliGenre == null,
                        onSelected: (_) {
                          setState(() => _seciliGenre = null);
                          _sifirlaYukle();
                        },
                      ),
                    ),
                    for (final t in _turler)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text('${t['name']}'),
                          selected: _seciliGenre == t['id'],
                          onSelected: (_) {
                            setState(() => _seciliGenre = t['id'] as int);
                            _sifirlaYukle();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // PC'de ızgara ortalanmış ve [masaustuIcerikGenisligi] (1080) ile sınırlı
      // (madde 26); mobilde kısıt bağlamaz.
      body: OrtaKolon(
        azami: masaustuIcerikGenisligi,
        cocuk: _hata != null
            ? HataGorunumu(mesaj: _hata!, tekrar: () => _yukle(ilk: true))
            : (_sonuc.isEmpty && _yukleniyor)
            ? GridView.builder(
                padding: const EdgeInsets.all(8),
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const PosterIzgarasi(
                  satirBoslugu: 10,
                  bosluk: 10,
                ),
                itemCount: 12,
                itemBuilder: (_, _) =>
                    const IskeletKutu(genislik: double.infinity),
              )
            : _sonuc.isEmpty
            ? BosDurum(
                ikon: Icons.movie_filter_outlined,
                baslik: 'Sonuç bulunamadı'.c,
                ipucu: 'Farklı bir tür seç.'.c,
              )
            : GridView.builder(
                controller: _kaydirma,
                padding: EdgeInsets.fromLTRB(8, 8, 8, altGuvenli(context)),
                gridDelegate: const PosterIzgarasi(
                  satirBoslugu: 10,
                  bosluk: 10,
                ),
                itemCount: _sonuc.length,
                itemBuilder: (context, i) => PosterKarti(
                  icerik: _sonuc[i] as Map<String, dynamic>,
                  turZorla: _tur,
                ),
              ),
      ),
    );
  }
}
