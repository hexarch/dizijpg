import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../puan.dart';
import '../tema.dart';
import 'ortak.dart';
import 'profil.dart' show sureBicimle;

/// Yıl özeti: izleme istatistikleri + en çok izlenen diziler.
class OzetEkrani extends StatefulWidget {
  final int yil;

  const OzetEkrani({super.key, required this.yil});

  @override
  State<OzetEkrani> createState() => _OzetEkraniState();
}

class _OzetEkraniState extends State<OzetEkrani> {
  Map<String, dynamic>? _ozet;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      final d = await Api.get('/ozet/${widget.yil}');
      if (mounted) setState(() => _ozet = d as Map<String, dynamic>);
    } catch (e) {
      if (mounted) setState(() => _hata = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_ozet == null) {
      govde = const Center(
        child: CircularProgressIndicator(color: DiziRenkler.sari),
      );
    } else {
      final o = _ozet!;
      final enCok = (o['en_cok'] as List<dynamic>? ?? []);
      final kartlar = [
        (Icons.tv_outlined, '${o['bolum']}', 'Bölüm'.c),
        (Icons.movie_outlined, '${o['film']}', 'Film'.c),
        (
          Icons.schedule,
          sureBicimle((o['dakika'] as num?)?.toInt() ?? 0),
          'Toplam İzleme Süresi'.c,
        ),
        (Icons.star_outline_rounded, '${o['puan_sayisi']}', 'Verdiğin puan'.c),
        (
          Icons.star_half_rounded,
          yildizOrtalamaMetni(o['puan_ortalama']),
          'Ortalama puanın'.c,
        ),
        (Icons.chat_bubble_outline, '${o['yorum']}', 'Yorum'.c),
      ];
      govde = ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, altGuvenli(context)),
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.7,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              for (final (ikon, deger, etiket) in kartlar)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(ikon, size: 20, color: DiziRenkler.sariMetin),
                        const SizedBox(height: 6),
                        FittedBox(
                          child: Text(
                            deger,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          etiket,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: DiziRenkler.metin54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (enCok.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'En çok izlediğin diziler'.c,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            for (final d in enCok)
              Card(
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 40,
                      height: 58,
                      child: d['poster'] != null
                          ? CachedNetworkImage(
                              imageUrl: posterUrl(d['poster'] as String?)!,
                              fit: BoxFit.cover,
                            )
                          : Container(color: DiziRenkler.koyuGri),
                    ),
                  ),
                  title: Text(d['ad'] as String? ?? ''),
                  subtitle: Text(
                    '{} bölüm izlendi'.cf([d['bolum']]),
                    style: TextStyle(color: DiziRenkler.metin54, fontSize: 12),
                  ),
                  onTap: () => context.push('/icerik/tv/${d['tmdb_id']}'),
                ),
              ),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('{} özetin'.cf([widget.yil]))),
      // PC'de akış ile AYNI ortalanmış okuma kolonu (madde 26); mobilde kısıt
      // bağlamaz.
      body: OrtaKolon(azami: masaustuKolonGenisligi, cocuk: govde),
    );
  }
}
