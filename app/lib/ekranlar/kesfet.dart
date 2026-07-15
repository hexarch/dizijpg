import 'package:flutter/material.dart';

import '../api.dart';
import '../tema.dart';
import 'ortak.dart';

class KesfetEkrani extends StatefulWidget {
  const KesfetEkrani({super.key});

  @override
  State<KesfetEkrani> createState() => _KesfetEkraniState();
}

class _KesfetEkraniState extends State<KesfetEkrani> {
  Map<String, List<dynamic>>? _bolumler;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      final sonuclar = await Future.wait([
        Api.get('/tmdb/trending/tv/week'),
        Api.get('/tmdb/trending/movie/week'),
        Api.get('/tmdb/discover/tv?sort_by=popularity.desc&with_original_language=tr'),
        Api.get('/tmdb/discover/movie?sort_by=vote_count.desc&vote_average.gte=8'),
        Api.get('/tmdb/discover/tv?sort_by=first_air_date.desc&vote_count.gte=20'),
      ]);
      if (!mounted) return;
      setState(() => _bolumler = {
            'Haftanın Dizileri': sonuclar[0]['results'] as List<dynamic>,
            'Haftanın Filmleri': sonuclar[1]['results'] as List<dynamic>,
            'Türk Dizileri': sonuclar[2]['results'] as List<dynamic>,
            'Tüm Zamanların En İyileri': sonuclar[3]['results'] as List<dynamic>,
            'Yeni Diziler': sonuclar[4]['results'] as List<dynamic>,
          });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_bolumler == null) {
      govde = const Center(
          child: CircularProgressIndicator(color: DiziRenkler.kirmizi));
    } else {
      final turMap = {
        'Haftanın Dizileri': 'tv',
        'Haftanın Filmleri': 'movie',
        'Türk Dizileri': 'tv',
        'Tüm Zamanların En İyileri': 'movie',
        'Yeni Diziler': 'tv',
      };
      govde = RefreshIndicator(
        color: DiziRenkler.kirmizi,
        onRefresh: _yukle,
        child: ListView(
          children: [
            for (final e in _bolumler!.entries)
              PosterSeridi(
                  baslik: e.key, icerikler: e.value, turZorla: turMap[e.key]),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/logo.png', height: 40),
),
      body: govde,
    );
  }
}
