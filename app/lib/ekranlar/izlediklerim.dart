import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'ortak.dart';

/// Otomatik "İzlediklerim": izlenen tüm film ve dizilerin ızgarası.
/// Kendi verisini çeker (reload'da doğrudan açılabilir).
class IzlenenlerEkrani extends StatefulWidget {
  const IzlenenlerEkrani({super.key});

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
      final d = await Api.get('/izlediklerim');
      if (mounted) setState(() => _ogeler = d['ogeler'] as List<dynamic>);
    } catch (e) {
      if (mounted) setState(() => _hata = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_ogeler == null) {
      govde = const Center(
        child: CircularProgressIndicator(color: DiziRenkler.sari),
      );
    } else if (_ogeler!.isEmpty) {
      govde = Center(
        child: Text(
          'Henüz izleme kaydın yok'.c,
          style: TextStyle(color: DiziRenkler.metin38),
        ),
      );
    } else {
      govde = GridView.builder(
        padding: const EdgeInsets.all(16),
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
            tmdbId: o['tmdb_id'] as int,
            tur: o['tur'] as String,
            genislik: double.infinity,
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'İzlediklerim'.c + (_ogeler != null ? ' (${_ogeler!.length})' : ''),
        ),
      ),
      body: govde,
    );
  }
}
