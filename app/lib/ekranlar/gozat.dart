import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import 'ortak.dart';

/// Katalog "Gözat": dizi/film seç, türe göre süz, popülerlik sırasına göre
/// poster ızgarası (sonsuz kaydırma). İçerik EKLEMENİN keşif yolu — kullanıcı
/// ne aradığını bilmese de gezip bulabilir.
class GozatEkrani extends StatefulWidget {
  const GozatEkrani({super.key});

  @override
  State<GozatEkrani> createState() => _GozatEkraniState();
}

class _GozatEkraniState extends State<GozatEkrani> {
  String _tur = 'tv'; // 'tv' | 'movie'
  List<dynamic> _turler = []; // TMDB genre listesi
  int? _seciliGenre; // null = tümü (popüler)
  final List<dynamic> _sonuc = [];
  int _sayfa = 1;
  bool _yukleniyor = false;
  bool _dahaVar = true;
  String? _hata;
  final _kaydirma = ScrollController();

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  Future<void> _turleriYukle() async {
    try {
      final d = await Api.get('/tmdb/genre/$_tur/list');
      if (mounted) {
        setState(() => _turler = d['genres'] as List<dynamic>? ?? []);
      }
    } catch (_) {
      /* tür çipleri gelmezse ızgara yine çalışır */
    }
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
                  segments: [
                    ButtonSegment(value: 'tv', label: Text('Diziler'.c)),
                    ButtonSegment(value: 'movie', label: Text('Filmler'.c)),
                  ],
                  selected: {_tur},
                  onSelectionChanged: (s) => _turDegis(s.first),
                ),
              ),
              // Tür çipleri
              SizedBox(
                height: 40,
                child: ListView(
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
      body: _hata != null
          ? HataGorunumu(mesaj: _hata!, tekrar: () => _yukle(ilk: true))
          : (_sonuc.isEmpty && _yukleniyor)
          ? GridView.builder(
              padding: const EdgeInsets.all(8),
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const PosterIzgarasi(satirBoslugu: 10, bosluk: 10),
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
              gridDelegate: const PosterIzgarasi(satirBoslugu: 10, bosluk: 10),
              itemCount: _sonuc.length,
              itemBuilder: (context, i) => PosterKarti(
                icerik: _sonuc[i] as Map<String, dynamic>,
                turZorla: _tur,
              ),
            ),
    );
  }
}
