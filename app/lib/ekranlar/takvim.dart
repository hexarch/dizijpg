import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../tema.dart';
import 'detay.dart';
import 'ortak.dart';

/// Takip edilen dizilerin yaklaşan bölümleri.
class TakvimEkrani extends StatefulWidget {
  const TakvimEkrani({super.key});

  @override
  State<TakvimEkrani> createState() => _TakvimEkraniState();
}

class _TakvimEkraniState extends State<TakvimEkrani>
    with AutomaticKeepAliveClientMixin {
  List<dynamic>? _yaklasan;
  String? _hata;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      final d = await Api.get('/takvim');
      if (!mounted) return;
      setState(() => _yaklasan = d['yaklasan'] as List<dynamic>);
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_yaklasan == null) {
      govde = const Center(
          child: CircularProgressIndicator(color: DiziRenkler.kirmizi));
    } else if (_yaklasan!.isEmpty) {
      govde = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Yaklaşan bölüm yok.\nDizi detayından "İzliyorum" durumuna al, '
            'yeni bölümleri burada takip et. 📅',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, height: 1.6),
          ),
        ),
      );
    } else {
      govde = RefreshIndicator(
        color: DiziRenkler.kirmizi,
        onRefresh: _yukle,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _yaklasan!.length,
          itemBuilder: (context, i) {
            final b = _yaklasan![i] as Map<String, dynamic>;
            final poster = posterUrl(b['poster'] as String?, boyut: 'w185');
            return Card(
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 42,
                    height: 62,
                    child: poster == null
                        ? Container(color: DiziRenkler.koyuGri)
                        : CachedNetworkImage(
                            imageUrl: poster, fit: BoxFit.cover),
                  ),
                ),
                title: Text(b['dizi_adi'] as String? ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                    'S${b['sezon']}B${b['bolum']}'
                    '${b['bolum_adi'] != null ? ' · ${b['bolum_adi']}' : ''}'),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: DiziRenkler.kirmizi,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    b['tarih'] as String? ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12),
                  ),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DetayEkrani(
                        tmdbId: b['tmdb_id'] as int, tur: 'tv'),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Takvim')),
      body: govde,
    );
  }
}
