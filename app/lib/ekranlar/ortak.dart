import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../tema.dart';
import 'detay.dart';

/// Poster kartı: dokununca detaya gider.
class PosterKarti extends StatelessWidget {
  final Map<String, dynamic> icerik;
  final String? turZorla; // multi aramada media_type gelir; trendlerde belli
  final double genislik;

  const PosterKarti(
      {super.key, required this.icerik, this.turZorla, this.genislik = 118});

  @override
  Widget build(BuildContext context) {
    final tur = turZorla ?? icerik['media_type'] as String? ?? 'tv';
    final ad = icerik['name'] ?? icerik['title'] ?? '?';
    final posterYolu = posterUrl(icerik['poster_path'] as String?);
    final puan = (icerik['vote_average'] as num?)?.toDouble() ?? 0;

    return SizedBox(
      width: genislik,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                DetayEkrani(tmdbId: icerik['id'] as int, tur: tur),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: posterYolu == null
                        ? Container(
                            color: DiziRenkler.kart,
                            child: const Icon(Icons.movie,
                                color: Colors.white24, size: 40))
                        : CachedNetworkImage(
                            imageUrl: posterYolu,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: DiziRenkler.kart),
                            errorWidget: (_, __, ___) => Container(
                                color: DiziRenkler.kart,
                                child: const Icon(Icons.broken_image,
                                    color: Colors.white24)),
                          ),
                  ),
                ),
                if (puan > 0)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star,
                              color: DiziRenkler.kirmizi, size: 12),
                          const SizedBox(width: 2),
                          Text(puan.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              ad as String,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yatay poster şeridi (başlık + liste).
class PosterSeridi extends StatelessWidget {
  final String baslik;
  final List<dynamic> icerikler;
  final String? turZorla;

  const PosterSeridi(
      {super.key,
      required this.baslik,
      required this.icerikler,
      this.turZorla});

  @override
  Widget build(BuildContext context) {
    if (icerikler.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: DiziRenkler.kirmizi,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(baslik,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        SizedBox(
          height: 236,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: icerikler.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => PosterKarti(
                icerik: icerikler[i] as Map<String, dynamic>,
                turZorla: turZorla),
          ),
        ),
      ],
    );
  }
}

/// Hata + tekrar dene görünümü
class HataGorunumu extends StatelessWidget {
  final String mesaj;
  final VoidCallback tekrar;
  const HataGorunumu({super.key, required this.mesaj, required this.tekrar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.white38),
            const SizedBox(height: 12),
            Text(mesaj, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: tekrar, child: const Text('Tekrar Dene')),
          ],
        ),
      ),
    );
  }
}
