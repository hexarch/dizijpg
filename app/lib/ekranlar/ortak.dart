import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';

/// Poster kartı: dokununca detaya gider.
class PosterKarti extends StatelessWidget {
  final Map<String, dynamic> icerik;
  final String? turZorla; // multi aramada media_type gelir; trendlerde belli
  final double genislik;

  const PosterKarti({
    super.key,
    required this.icerik,
    this.turZorla,
    this.genislik = 118,
  });

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
        onTap: () => context.push('/icerik/$tur/${icerik['id']}'),
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
                            child: const Icon(
                              Icons.movie,
                              color: Colors.white24,
                              size: 40,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: posterYolu,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: DiziRenkler.kart),
                            errorWidget: (_, __, ___) => Container(
                              color: DiziRenkler.kart,
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.white24,
                              ),
                            ),
                          ),
                  ),
                ),
                if (puan > 0)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            color: DiziRenkler.sari,
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            puan.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
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
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
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

  const PosterSeridi({
    super.key,
    required this.baslik,
    required this.icerikler,
    this.turZorla,
  });

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
                  color: DiziRenkler.sari,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                baslik,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
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
              turZorla: turZorla,
            ),
          ),
        ),
      ],
    );
  }
}

/// Kitaplık/ızgara içeriği: detayını sunucu önbelleğinden çekip poster gösterir.
class MiniIcerik extends StatefulWidget {
  final int tmdbId;
  final String tur;
  final double genislik;

  /// Dizi ilerleme rozeti için izlenen bölüm sayısı (isteğe bağlı).
  final int? izlenenSayi;

  const MiniIcerik({
    super.key,
    required this.tmdbId,
    required this.tur,
    this.genislik = 105,
    this.izlenenSayi,
  });

  @override
  State<MiniIcerik> createState() => _MiniIcerikState();
}

class _MiniIcerikState extends State<MiniIcerik> {
  Map<String, dynamic>? _icerik;

  @override
  void initState() {
    super.initState();
    Api.get('/tmdb/${widget.tur}/${widget.tmdbId}')
        .then((d) {
          if (mounted) setState(() => _icerik = d as Map<String, dynamic>);
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    if (_icerik == null) {
      return IskeletKutu(genislik: widget.genislik);
    }
    final kart = PosterKarti(
      icerik: _icerik!,
      turZorla: widget.tur,
      genislik: widget.genislik,
    );
    // Dizi ilerlemesi: izlenen / toplam bölüm rozeti
    final toplam = (_icerik!['number_of_episodes'] as num?)?.toInt() ?? 0;
    final izlenen = widget.izlenenSayi ?? 0;
    if (widget.tur != 'tv' || toplam <= 0 || izlenen <= 0) return kart;
    final yuzde = (izlenen / toplam * 100).clamp(1, 100).round();
    return Stack(
      children: [
        kart,
        Positioned(
          top: 6,
          left: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '%$yuzde',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: yuzde >= 100 ? DiziRenkler.sari : Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Yüklenirken nabız gibi atan iskelet kutu.
class IskeletKutu extends StatefulWidget {
  final double genislik;
  final double? yukseklik;

  const IskeletKutu({super.key, this.genislik = 105, this.yukseklik});

  @override
  State<IskeletKutu> createState() => _IskeletKutuState();
}

class _IskeletKutuState extends State<IskeletKutu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kontrol = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _kontrol.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_kontrol),
      child: Container(
        width: widget.genislik,
        height: widget.yukseklik,
        decoration: BoxDecoration(
          color: DiziRenkler.kart,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
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
            FilledButton(onPressed: tekrar, child: Text('Tekrar Dene'.c)),
          ],
        ),
      ),
    );
  }
}

/// Okunmamış sayacı rozetli appbar ikonu (zil, zarf, DM).
class RozetliIkon extends StatelessWidget {
  final IconData ikon;
  final int sayi;
  final VoidCallback onTap;

  const RozetliIkon({
    super.key,
    required this.ikon,
    required this.sayi,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(ikon),
          if (sayi > 0)
            Positioned(
              right: -5,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: DiziRenkler.sari,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  sayi > 99 ? '99+' : '$sayi',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
