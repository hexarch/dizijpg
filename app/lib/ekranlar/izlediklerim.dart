import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import 'ortak.dart';

/// Otomatik "İzlediklerim": izlenen tüm film ve dizilerin ızgarası.
/// Kendi verisini çeker (reload'da doğrudan açılabilir).
/// [tur] verilirse yalnız o tür listelenir ('tv' | 'movie').
class IzlenenlerEkrani extends StatefulWidget {
  final String? tur;
  const IzlenenlerEkrani({super.key, this.tur});

  @override
  State<IzlenenlerEkrani> createState() => _IzlenenlerEkraniState();
}

class _IzlenenlerEkraniState extends State<IzlenenlerEkrani> {
  List<dynamic>? _ogeler;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      // Tür filtresini SUNUCUYA gönder: yerelde kırpılmış listeyi filtrelemek
      // yanlış sayı verirdi (215 dizi → 3 görünüyordu).
      final yol = widget.tur == null
          ? '/izlediklerim'
          : '/izlediklerim?tur=${widget.tur}';
      final d = await Api.get(yol);
      if (mounted) setState(() => _ogeler = d['ogeler'] as List<dynamic>);
    } catch (e) {
      if (mounted) setState(() => _hata = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final ogeler = _ogeler;

    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (ogeler == null) {
      // İskelet ızgara: bekleme yerine içerik şekli belirir (premium his)
      govde = GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
          childAspectRatio: 0.5,
        ),
        itemCount: 9,
        itemBuilder: (_, __) => const IskeletKutu(
          genislik: double.infinity,
          yukseklik: double.infinity,
        ),
      );
    } else if (ogeler.isEmpty) {
      govde = BosDurum(
        ikon: Icons.movie_outlined,
        baslik: 'Henüz izleme kaydın yok'.c,
        ipucu: 'İzlediğin dizi ve filmleri işaretledikçe burada toplanır.'.c,
      );
    } else {
      govde = GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
          childAspectRatio: 0.5,
        ),
        itemCount: ogeler.length,
        itemBuilder: (context, i) {
          final o = ogeler[i] as Map<String, dynamic>;
          return MiniIcerik(
            tmdbId: o['tmdb_id'] as int,
            tur: o['tur'] as String,
            genislik: double.infinity,
            izlenenSayi: (o['sayi'] as num?)?.toInt(),
          );
        },
      );
    }

    final baslik = widget.tur == 'movie'
        ? 'İzlediğim Filmler ({})'
        : widget.tur == 'tv'
        ? 'İzlediğim Diziler ({})'
        : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          baslik != null
              ? baslik.cf([ogeler?.length ?? 0])
              : 'İzlediklerim'.c +
                    (ogeler != null ? ' (${ogeler.length})' : ''),
        ),
      ),
      body: govde,
    );
  }
}
