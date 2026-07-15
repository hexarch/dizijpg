import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../tema.dart';
import 'kisi.dart';
import 'ortak.dart';

class AramaEkrani extends StatefulWidget {
  const AramaEkrani({super.key});

  @override
  State<AramaEkrani> createState() => _AramaEkraniState();
}

class _AramaEkraniState extends State<AramaEkrani>
    with AutomaticKeepAliveClientMixin {
  final _kutu = TextEditingController();
  Timer? _geciktirici;
  List<dynamic> _sonuclar = [];
  bool _yukleniyor = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _kutu.dispose();
    _geciktirici?.cancel();
    super.dispose();
  }

  void _degisti(String sorgu) {
    _geciktirici?.cancel();
    _geciktirici = Timer(const Duration(milliseconds: 450), () => _ara(sorgu));
  }

  Future<void> _ara(String sorgu) async {
    if (sorgu.trim().length < 2) {
      setState(() => _sonuclar = []);
      return;
    }
    setState(() => _yukleniyor = true);
    try {
      final d = await Api.get(
          '/tmdb/search/multi?query=${Uri.encodeComponent(sorgu.trim())}');
      if (!mounted) return;
      setState(() {
        _sonuclar = (d['results'] as List<dynamic>)
            .where((r) => r['media_type'] != 'person'
                ? r['poster_path'] != null
                : r['profile_path'] != null)
            .toList();
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Arama')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _kutu,
              onChanged: _degisti,
              decoration: InputDecoration(
                hintText: 'Dizi, film veya kişi ara...',
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: _yukleniyor
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: DiziRenkler.kirmizi)),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _sonuclar.isEmpty
                ? const Center(
                    child: Text('Aramaya başla 🎬',
                        style: TextStyle(color: Colors.white38)))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.53,
                    ),
                    itemCount: _sonuclar.length,
                    itemBuilder: (context, i) {
                      final r = _sonuclar[i] as Map<String, dynamic>;
                      if (r['media_type'] == 'person') {
                        return _KisiKarti(kisi: r);
                      }
                      return PosterKarti(icerik: r);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _KisiKarti extends StatelessWidget {
  final Map<String, dynamic> kisi;
  const _KisiKarti({required this.kisi});

  @override
  Widget build(BuildContext context) {
    final foto = posterUrl(kisi['profile_path'] as String?, boyut: 'w185');
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => KisiEkrani(kisiId: kisi['id'] as int)),
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: foto == null
                  ? Container(
                      color: DiziRenkler.kart,
                      child: const Icon(Icons.person, color: Colors.white24))
                  : Image.network(foto,
                      fit: BoxFit.cover, width: double.infinity),
            ),
          ),
          const SizedBox(height: 6),
          Text('🎭 ${kisi['name']}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
