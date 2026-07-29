import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import 'ortak.dart';

/// Bir kitaplık durumunun (izliyorum/bitirdim/...) TAM listesi, dikey ızgara.
class KitaplikListesiEkrani extends StatefulWidget {
  final String durum;

  const KitaplikListesiEkrani({super.key, required this.durum});

  @override
  State<KitaplikListesiEkrani> createState() => _KitaplikListesiEkraniState();
}

class _KitaplikListesiEkraniState extends State<KitaplikListesiEkrani> {
  List<dynamic>? _ogeler;
  Map<String, int> _sayilar = {}; // 'tur:id' → izlenen bölüm
  String? _hata;

  static const _adlar = {
    'izliyorum': 'İzliyorum',
    'izleyecegim': 'İzleyeceğim',
    'bitirdim': 'Bitirdim',
    'biraktim': 'Bıraktım',
  };

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      final sonuclar = await Future.wait([
        Api.get('/kitapligim'),
        Api.get('/izlediklerim'),
      ]);
      if (!mounted) return;
      setState(() {
        _ogeler = (sonuclar[0]['durumlar'] as List<dynamic>)
            .where((d) => d['durum'] == widget.durum)
            .toList();
        _sayilar = {
          for (final o in (sonuclar[1]['ogeler'] as List<dynamic>))
            '${o['tur']}:${o['tmdb_id']}': (o['sayi'] as num?)?.toInt() ?? 0,
        };
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
    } else if (_ogeler == null) {
      govde = GridView.builder(
        padding: EdgeInsets.fromLTRB(16, 16, 16, altGuvenli(context)),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 14,
          crossAxisSpacing: 10,
          childAspectRatio: 0.5,
        ),
        itemCount: 9,
        itemBuilder: (_, __) => const IskeletKutu(genislik: double.infinity),
      );
    } else if (_ogeler!.isEmpty) {
      govde = BosDurum(
        ikon: Icons.video_library_outlined,
        baslik: 'Henüz izleme kaydın yok'.c,
        ipucu: 'İzlediğin dizi ve filmleri işaretledikçe burada toplanır.'.c,
      );
    } else {
      govde = GridView.builder(
        padding: EdgeInsets.fromLTRB(16, 16, 16, altGuvenli(context)),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 14,
          crossAxisSpacing: 10,
          childAspectRatio: 0.5,
        ),
        itemCount: _ogeler!.length,
        itemBuilder: (context, i) {
          final o = _ogeler![i] as Map<String, dynamic>;
          return MiniIcerik(
            tmdbId: (o['tmdb_id'] as num).toInt(),
            tur: o['tur'] as String,
            genislik: double.infinity,
            izlenenSayi: _sayilar['${o['tur']}:${o['tmdb_id']}'],
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          (_adlar[widget.durum] ?? widget.durum).c +
              (_ogeler != null ? ' (${_ogeler!.length})' : ''),
        ),
      ),
      body: govde,
    );
  }
}
