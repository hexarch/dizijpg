import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../tema.dart';
import 'ortak.dart';

/// Sezon ekranı: bölüm listesi, tek tek veya toplu izleme işaretleme.
class SezonEkrani extends StatefulWidget {
  final int tmdbId;
  final int sezonNo;
  final int bolumSayisi;

  const SezonEkrani({
    super.key,
    required this.tmdbId,
    required this.sezonNo,
    required this.bolumSayisi,
  });

  @override
  State<SezonEkrani> createState() => _SezonEkraniState();
}

class _SezonEkraniState extends State<SezonEkrani> {
  List<dynamic>? _bolumler;
  Set<int> _izlenen = {};
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
        Api.get('/tmdb/tv/${widget.tmdbId}/season/${widget.sezonNo}'),
        Api.get('/izleme/tv/${widget.tmdbId}'),
      ]);
      if (!mounted) return;
      setState(() {
        _bolumler = (sonuclar[0]['episodes'] as List<dynamic>);
        _izlenen = {
          for (final r in sonuclar[1]['izlenenler'] as List<dynamic>)
            if (r['sezon'] == widget.sezonNo) r['bolum'] as int
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
    }
  }

  Future<void> _bolumToggle(int bolum) async {
    // İyimser güncelleme: önce arayüz, sonra sunucu.
    setState(() {
      _izlenen.contains(bolum) ? _izlenen.remove(bolum) : _izlenen.add(bolum);
    });
    try {
      await Api.post('/izleme/toggle', {
        'tmdb_id': widget.tmdbId,
        'tur': 'tv',
        'sezon': widget.sezonNo,
        'bolum': bolum,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _izlenen.contains(bolum) ? _izlenen.remove(bolum) : _izlenen.add(bolum);
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _tumu(bool isaretle) async {
    try {
      await Api.post('/izleme/sezon', {
        'tmdb_id': widget.tmdbId,
        'sezon': widget.sezonNo,
        'bolum_sayisi': widget.bolumSayisi,
        'isaretle': isaretle,
      });
      if (!mounted) return;
      setState(() {
        _izlenen = isaretle
            ? {for (var b = 1; b <= widget.bolumSayisi; b++) b}
            : {};
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hepsiIzlendi =
        _bolumler != null && _izlenen.length >= (_bolumler!.length);

    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_bolumler == null) {
      govde = const Center(
          child: CircularProgressIndicator(color: DiziRenkler.kirmizi));
    } else {
      govde = ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: _bolumler!.length,
        itemBuilder: (context, i) {
          final b = _bolumler![i] as Map<String, dynamic>;
          final no = b['episode_number'] as int;
          final izlendi = _izlenen.contains(no);
          final gorsel = posterUrl(b['still_path'] as String?, boyut: 'w300');
          final tarih = b['air_date'] as String? ?? '';

          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _bolumToggle(no),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 100,
                        height: 58,
                        child: gorsel == null
                            ? Container(
                                color: DiziRenkler.koyuGri,
                                child: const Icon(Icons.tv,
                                    color: Colors.white24))
                            : CachedNetworkImage(
                                imageUrl: gorsel, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$no. ${b['name'] ?? 'Bölüm'}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          if (tarih.isNotEmpty)
                            Text(tarih,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white38)),
                        ],
                      ),
                    ),
                    Icon(
                      izlendi
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: izlendi ? DiziRenkler.kirmizi : Colors.white24,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.sezonNo}. Sezon'),
        actions: [
          TextButton.icon(
            onPressed: () => _tumu(!hepsiIzlendi),
            icon: Icon(hepsiIzlendi ? Icons.remove_done : Icons.done_all,
                color: DiziRenkler.kirmizi),
            label: Text(hepsiIzlendi ? 'Tümünü Kaldır' : 'Tümünü İzledim',
                style: const TextStyle(color: DiziRenkler.kirmizi)),
          ),
        ],
      ),
      body: govde,
    );
  }
}
