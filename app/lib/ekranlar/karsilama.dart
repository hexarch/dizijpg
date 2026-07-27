import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';

/// Yeni kayıt olan kullanıcıya gösterilen karşılama akışı: popüler dizi ve
/// filmlerden seçtiklerini "İzleyeceğim" listesine ekleyerek profili tohumlar.
class KarsilamaEkrani extends StatefulWidget {
  const KarsilamaEkrani({super.key});

  @override
  State<KarsilamaEkrani> createState() => _KarsilamaEkraniState();
}

class _KarsilamaEkraniState extends State<KarsilamaEkrani> {
  List<Map<String, dynamic>> _icerikler = [];
  final _secili = <String>{}; // 'tur:id'
  bool _yukleniyor = true;
  bool _kaydediyor = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final s = await Future.wait([
        Api.get('/tmdb/trending/tv/week'),
        Api.get('/tmdb/trending/movie/week'),
      ]);
      final tv = ((s[0]['results'] as List<dynamic>?) ?? const []).map(
        (e) => {...e as Map<String, dynamic>, 'tur': 'tv'},
      );
      final film = ((s[1]['results'] as List<dynamic>?) ?? const []).map(
        (e) => {...e as Map<String, dynamic>, 'tur': 'movie'},
      );
      // İki listeyi harmanla; yalnızca posteri olanları göster.
      final hepsi = <Map<String, dynamic>>[];
      final tvL = tv.toList(), filmL = film.toList();
      for (var i = 0; i < 20; i++) {
        if (i < tvL.length) hepsi.add(tvL[i]);
        if (i < filmL.length) hepsi.add(filmL[i]);
      }
      final gosterilecek = hepsi
          .where((e) => e['poster_path'] != null)
          .toList();
      if (mounted) {
        setState(() {
          _icerikler = gosterilecek;
          _yukleniyor = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _bitir() async {
    if (_secili.isEmpty) {
      _kapat();
      return;
    }
    setState(() => _kaydediyor = true);
    await Future.wait(
      _secili.map((anahtar) {
        final p = anahtar.split(':');
        return Api.post('/durum', {
          'tmdb_id': int.parse(p[1]),
          'tur': p[0],
          'durum': 'izleyecegim',
        }).catchError((_) => <String, dynamic>{});
      }),
    );
    _kapat();
  }

  void _kapat() {
    Oturum.karsilamaGerekli = false;
    if (mounted) context.go('/kesfet');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Başlık
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hoş geldin!'.c,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'İzlemek istediğin dizi ve filmleri seç'.c,
                    style: TextStyle(fontSize: 15, color: DiziRenkler.metin70),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Seçtiklerin "İzleyeceğim" listene eklenir'.c,
                    style: TextStyle(fontSize: 12, color: DiziRenkler.metin38),
                  ),
                ],
              ),
            ),
            // Poster ızgarası
            Expanded(
              child: _yukleniyor
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.62,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: _icerikler.length,
                      itemBuilder: (context, i) {
                        final ic = _icerikler[i];
                        final anahtar = '${ic['tur']}:${ic['id']}';
                        final secildi = _secili.contains(anahtar);
                        final poster = posterUrl(
                          ic['poster_path'] as String?,
                          boyut: 'w342',
                        );
                        return GestureDetector(
                          onTap: () => setState(() {
                            if (secildi) {
                              _secili.remove(anahtar);
                            } else {
                              _secili.add(anahtar);
                            }
                          }),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: poster == null
                                    ? Container(color: DiziRenkler.kart)
                                    : CachedNetworkImage(
                                        imageUrl: poster,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              if (secildi)
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: DiziRenkler.sari,
                                      width: 3,
                                    ),
                                    color: Colors.black38,
                                  ),
                                  alignment: Alignment.topRight,
                                  padding: const EdgeInsets.all(6),
                                  child: const CircleAvatar(
                                    radius: 13,
                                    backgroundColor: DiziRenkler.sari,
                                    child: Icon(
                                      Icons.check,
                                      size: 18,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            // Alt eylem çubuğu
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _kaydediyor ? null : _kapat,
                    child: Text(
                      'Şimdilik atla'.c,
                      style: TextStyle(color: DiziRenkler.metin54),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _kaydediyor ? null : _bitir,
                    child: _kaydediyor
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            _secili.isEmpty
                                ? 'Devam et'.c
                                : '{} ekle'.cf([_secili.length]),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
