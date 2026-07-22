import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'ortak.dart';
import 'tepki.dart';
import 'yorumlar.dart';

/// Bölüm sayfası: görsel, özet, konuk oyuncular, izleme işareti ve
/// bölüme özel yorumlar.
class BolumEkrani extends StatefulWidget {
  final int tmdbId;
  final int sezonNo;
  final int bolumNo;
  final bool izlendi;

  const BolumEkrani({
    super.key,
    required this.tmdbId,
    required this.sezonNo,
    required this.bolumNo,
    required this.izlendi,
  });

  @override
  State<BolumEkrani> createState() => _BolumEkraniState();
}

class _BolumEkraniState extends State<BolumEkrani> {
  Map<String, dynamic>? _bolum;
  String? _hata;
  late bool _izlendi = widget.izlendi;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      final d = await Api.get(
        '/tmdb/tv/${widget.tmdbId}/season/${widget.sezonNo}/episode/${widget.bolumNo}',
      );
      if (mounted) setState(() => _bolum = d as Map<String, dynamic>);
    } catch (e) {
      if (mounted) setState(() => _hata = e.toString());
    }
  }

  Future<void> _izlendiToggle() async {
    setState(() => _izlendi = !_izlendi);
    try {
      await Api.post('/izleme/toggle', {
        'tmdb_id': widget.tmdbId,
        'tur': 'tv',
        'sezon': widget.sezonNo,
        'bolum': widget.bolumNo,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _izlendi = !_izlendi);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_bolum == null) {
      govde = const Center(
        child: CircularProgressIndicator(color: DiziRenkler.sari),
      );
    } else {
      final b = _bolum!;
      final gorsel = posterUrl(b['still_path'] as String?, boyut: 'w780');
      final tarih = b['air_date'] as String? ?? '';
      final sure = (b['runtime'] as num?)?.toInt();
      final konuklar = (b['guest_stars'] as List<dynamic>? ?? []);

      govde = ListView(
        padding: EdgeInsets.zero,
        children: [
          if (gorsel != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(imageUrl: gorsel, fit: BoxFit.cover),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b['name'] as String? ?? '{}. Bölüm'.cf([widget.bolumNo]),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    'S${widget.sezonNo}B${widget.bolumNo}',
                    if (tarih.isNotEmpty) tarih,
                    if (sure != null) '{} dk'.cf([sure]),
                    if (b['vote_average'] != null)
                      '{} TMDB'.cf([
                        (b['vote_average'] as num).toStringAsFixed(1),
                      ]),
                  ].join(' · '),
                  style: TextStyle(color: DiziRenkler.metin54),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _izlendiToggle,
                  style: _izlendi
                      ? FilledButton.styleFrom(
                          backgroundColor: DiziRenkler.kart,
                          foregroundColor: DiziRenkler.sari,
                        )
                      : null,
                  icon: Icon(_izlendi ? Icons.check_circle : Icons.visibility),
                  label: Text(_izlendi ? 'İzledin'.c : 'İzledim'.c),
                ),
                if ((b['overview'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 14),
                  Text(
                    b['overview'] as String,
                    style: const TextStyle(height: 1.5),
                  ),
                ],
              ],
            ),
          ),
          if (konuklar.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                'Konuk Oyuncular'.c,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: konuklar.length.clamp(0, 15),
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final o = konuklar[i] as Map<String, dynamic>;
                  final foto = posterUrl(
                    o['profile_path'] as String?,
                    boyut: 'w185',
                  );
                  return SizedBox(
                    width: 76,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.push('/kisi/${o['id']}'),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundColor: DiziRenkler.kart,
                            backgroundImage: foto == null
                                ? null
                                : CachedNetworkImageProvider(foto),
                            child: foto == null
                                ? Icon(Icons.person, color: DiziRenkler.metin24)
                                : null,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            o['name'] as String? ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TepkiSatiri(
              tur: 'tv',
              tmdbId: widget.tmdbId,
              sezon: widget.sezonNo,
              bolum: widget.bolumNo,
            ),
          ),
          YorumBolumu(
            tur: 'tv',
            tmdbId: widget.tmdbId,
            sezon: widget.sezonNo,
            bolum: widget.bolumNo,
          ),
          const SizedBox(height: 32),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('S{} · {}. Bölüm'.cf([widget.sezonNo, widget.bolumNo])),
      ),
      body: govde,
    );
  }
}
