import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'ortak.dart';

class KesfetEkrani extends StatefulWidget {
  const KesfetEkrani({super.key});

  @override
  State<KesfetEkrani> createState() => _KesfetEkraniState();
}

class _KesfetEkraniState extends State<KesfetEkrani> {
  Map<String, List<dynamic>>? _bolumler;
  int _mesajSayi = 0;

  Future<void> _mesajSayisiYukle() async {
    try {
      final d = await Api.get('/sohbetler');
      if (mounted) {
        setState(() => _mesajSayi = (d['okunmamis'] as int?) ?? 0);
      }
    } catch (_) {}
  }

  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
    _mesajSayisiYukle();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      final sonuclar = await Future.wait([
        Api.get('/tmdb/trending/tv/week'),
        Api.get('/tmdb/trending/movie/week'),
        Api.get(
          '/tmdb/discover/tv?sort_by=popularity.desc&with_original_language=tr',
        ),
        Api.get(
          '/tmdb/discover/movie?sort_by=vote_count.desc&vote_average.gte=8',
        ),
        Api.get(
          '/tmdb/discover/tv?sort_by=first_air_date.desc&vote_count.gte=20',
        ),
        Api.get(
          '/onerilen',
        ).catchError((_) => <String, dynamic>{'oneriler': <dynamic>[]}),
      ]);
      if (!mounted) return;
      final onerilen = (sonuclar[5]['oneriler'] as List<dynamic>? ?? []);
      setState(
        () => _bolumler = {
          if (onerilen.isNotEmpty) 'Sana Özel': onerilen,
          'Haftanın Dizileri': sonuclar[0]['results'] as List<dynamic>,
          'Haftanın Filmleri': sonuclar[1]['results'] as List<dynamic>,
          'Türk Dizileri': sonuclar[2]['results'] as List<dynamic>,
          'Tüm Zamanların En İyileri': sonuclar[3]['results'] as List<dynamic>,
          'Yeni Diziler': sonuclar[4]['results'] as List<dynamic>,
        },
      );
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
      // İskelet raflar: içerik gelene dek nabız atan kutular
      govde = ListView(
        padding: const EdgeInsets.only(top: 8),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var s = 0; s < 3; s++) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IskeletKutu(genislik: 150, yukseklik: 18),
              ),
            ),
            SizedBox(
              height: 236,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, __) => const IskeletKutu(genislik: 118),
              ),
            ),
          ],
        ],
      );
    } else {
      final turMap = {
        'Haftanın Dizileri': 'tv',
        'Haftanın Filmleri': 'movie',
        'Türk Dizileri': 'tv',
        'Tüm Zamanların En İyileri': 'movie',
        'Yeni Diziler': 'tv',
      };
      govde = RefreshIndicator(
        color: DiziRenkler.sari,
        onRefresh: _yukle,
        child: ListView(
          children: [
            for (final e in _bolumler!.entries)
              PosterSeridi(
                baslik: e.key.c,
                icerikler: e.value,
                turZorla: turMap[e.key],
              ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logo.png', height: 40),
            const SizedBox(width: 8),
            // BETA rozeti (marka sarısı pill)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: DiziRenkler.sari,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'BETA',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Sürüm numarası (yapı numarası olmadan)
            Text(
              'v${Api.surum.split('+').first}',
              style: TextStyle(
                color: DiziRenkler.metin38,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          // Katalog gözat (türe göre keşif)
          IconButton(
            tooltip: 'Gözat'.c,
            icon: const Icon(Icons.grid_view_outlined),
            onPressed: () => context.push('/gozat'),
          ),
          // Instagram tarzı DM kısayolu
          RozetliIkon(
            ikon: Icons.near_me_outlined,
            sayi: _mesajSayi,
            etiket: 'Mesajlar'.c,
            onTap: () async {
              await context.push('/sohbetler');
              _mesajSayisiYukle();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: govde,
    );
  }
}
