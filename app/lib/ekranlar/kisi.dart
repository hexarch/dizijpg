import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../tema.dart';
import 'ortak.dart';

class KisiEkrani extends StatefulWidget {
  final int kisiId;
  const KisiEkrani({super.key, required this.kisiId});

  @override
  State<KisiEkrani> createState() => _KisiEkraniState();
}

class _KisiEkraniState extends State<KisiEkrani> {
  Map<String, dynamic>? _kisi;
  List<dynamic> _isler = [];
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
        Api.get('/tmdb/person/${widget.kisiId}'),
        Api.get('/tmdb/person/${widget.kisiId}/combined_credits'),
      ]);
      if (!mounted) return;
      final isler = (sonuclar[1]['cast'] as List<dynamic>)
          .where((c) => c['poster_path'] != null)
          .toList()
        ..sort((a, b) => ((b['vote_count'] as num?) ?? 0)
            .compareTo((a['vote_count'] as num?) ?? 0));
      setState(() {
        _kisi = sonuclar[0] as Map<String, dynamic>;
        _isler = isler.take(60).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hata != null) {
      return Scaffold(
          appBar: AppBar(),
          body: HataGorunumu(mesaj: _hata!, tekrar: _yukle));
    }
    if (_kisi == null) {
      return const Scaffold(
          body: Center(
              child: CircularProgressIndicator(color: DiziRenkler.kirmizi)));
    }
    final k = _kisi!;
    final foto = posterUrl(k['profile_path'] as String?, boyut: 'w342');

    return Scaffold(
      appBar: AppBar(title: Text(k['name'] as String? ?? '')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 110,
                  height: 165,
                  child: foto == null
                      ? Container(
                          color: DiziRenkler.kart,
                          child:
                              const Icon(Icons.person, color: Colors.white24))
                      : CachedNetworkImage(imageUrl: foto, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(k['name'] as String? ?? '',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    if (k['birthday'] != null)
                      Text('🎂 ${k['birthday']}',
                          style: const TextStyle(color: Colors.white54)),
                    if ((k['place_of_birth'] as String?)?.isNotEmpty == true)
                      Text('📍 ${k['place_of_birth']}',
                          style: const TextStyle(color: Colors.white54)),
                    Text('🎬 ${_isler.length}+ yapım',
                        style: const TextStyle(color: Colors.white54)),
                  ],
                ),
              ),
            ],
          ),
          if ((k['biography'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 14),
            Text(k['biography'] as String,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(height: 1.5, color: Colors.white70)),
          ],
          const SizedBox(height: 18),
          const Text('Yapımları',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 10,
              childAspectRatio: 0.53,
            ),
            itemCount: _isler.length,
            itemBuilder: (context, i) =>
                PosterKarti(icerik: _isler[i] as Map<String, dynamic>),
          ),
        ],
      ),
    );
  }
}
