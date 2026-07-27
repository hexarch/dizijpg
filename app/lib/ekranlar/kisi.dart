import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'ortak.dart';
import 'puan_sheet.dart';
import 'yorumlar.dart';

class KisiEkrani extends StatefulWidget {
  final int kisiId;
  const KisiEkrani({super.key, required this.kisiId});

  @override
  State<KisiEkrani> createState() => _KisiEkraniState();
}

class _KisiEkraniState extends State<KisiEkrani> {
  Map<String, dynamic>? _kisi;
  List<dynamic> _isler = [];
  Map<String, dynamic>? _benimPuan;
  Map<String, dynamic>? _toplum;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _puanYenile() async {
    try {
      final sonuclar = await Future.wait([
        Api.get('/benim/person/${widget.kisiId}'),
        Api.get('/incelemeler/person/${widget.kisiId}'),
      ]);
      if (mounted) {
        setState(() {
          _benimPuan = sonuclar[0]['puan'] as Map<String, dynamic>?;
          _toplum = sonuclar[1] as Map<String, dynamic>;
        });
      }
    } catch (_) {}
  }

  Future<void> _puanla() async {
    final kaydedildi = await puanlaVeKaydet(
      context,
      tur: 'person',
      tmdbId: widget.kisiId,
      mevcutPuan: _benimPuan?['puan'] as int?,
      mevcutYorum: _benimPuan?['yorum'] as String?,
    );
    if (kaydedildi) _puanYenile();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    _puanYenile();
    try {
      final sonuclar = await Future.wait([
        Api.get('/tmdb/person/${widget.kisiId}'),
        Api.get('/tmdb/person/${widget.kisiId}/combined_credits'),
      ]);
      if (!mounted) return;
      final isler =
          (sonuclar[1]['cast'] as List<dynamic>)
              .where((c) => c['poster_path'] != null)
              .toList()
            ..sort(
              (a, b) => ((b['vote_count'] as num?) ?? 0).compareTo(
                (a['vote_count'] as num?) ?? 0,
              ),
            );
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
        body: HataGorunumu(mesaj: _hata!, tekrar: _yukle),
      );
    }
    if (_kisi == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: DiziRenkler.sari)),
      );
    }
    final k = _kisi!;
    final foto = posterUrl(k['profile_path'] as String?, boyut: 'w342');

    return Scaffold(
      appBar: AppBar(title: Text(k['name'] as String? ?? '')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(0, 16, 0, altGuvenli(context)),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                                child: Icon(
                                  Icons.person,
                                  color: DiziRenkler.metin24,
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: foto,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            k['name'] as String? ?? '',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (k['birthday'] != null)
                            _BilgiSatiri(
                              ikon: Icons.cake_outlined,
                              metin: '${k['birthday']}',
                            ),
                          if ((k['place_of_birth'] as String?)?.isNotEmpty ==
                              true)
                            _BilgiSatiri(
                              ikon: Icons.location_on_outlined,
                              metin: k['place_of_birth'] as String,
                            ),
                          _BilgiSatiri(
                            ikon: Icons.movie_outlined,
                            metin: '{}+ yapım'.cf([_isler.length]),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: _puanla,
                                icon: Icon(
                                  _benimPuan != null
                                      ? Icons.star
                                      : Icons.star_border,
                                  size: 18,
                                  color: DiziRenkler.sari,
                                ),
                                label: Text(
                                  _benimPuan != null
                                      ? '${(((_benimPuan!['puan'] as num?) ?? 0) / 2).round()}/5'
                                      : 'Puanla'.c,
                                  style: const TextStyle(
                                    color: DiziRenkler.sari,
                                  ),
                                ),
                              ),
                              if (_toplum?['ortalama'] != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  'ort. {}'.cf([
                                    ((num.tryParse('${_toplum!['ortalama']}') ??
                                                0) /
                                            2)
                                        .toStringAsFixed(1),
                                  ]),
                                  style: TextStyle(
                                    color: DiziRenkler.metin54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if ((k['biography'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 14),
                  Text(
                    k['biography'] as String,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(height: 1.5, color: DiziRenkler.metin70),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  'Yapımları'.c,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
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
          ),
          YorumBolumu(tur: 'person', tmdbId: widget.kisiId),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Küçük ikonlu bilgi satırı (doğum günü, yer, yapım sayısı).
class _BilgiSatiri extends StatelessWidget {
  final IconData ikon;
  final String metin;

  const _BilgiSatiri({required this.ikon, required this.metin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 14, color: DiziRenkler.metin54),
          const SizedBox(width: 5),
          Text(metin, style: TextStyle(color: DiziRenkler.metin54)),
        ],
      ),
    );
  }
}
