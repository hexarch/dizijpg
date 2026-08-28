import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import '../gorsel_basliklari.dart';
import '../tema.dart';

/// Dizi/film seçme sayfası — ARAMA + LİSTE, seçince `Navigator.pop` ile
/// TMDB kaydını döndürür (`{id, media_type, name|title, poster_path, ...}`).
///
/// NEDEN ORTAK BİLEŞEN (28 Ağu 2026): bu sayfa 2 Ağu'dan beri
/// `sohbet.dart` içinde `_IcerikSecSheet` adıyla ÖZELDİ. Akıştaki paylaşım
/// kutusu da aynı seçiciye ihtiyaç duyunca kopyalamak yerine buraya taşındı —
/// bu depoda kopyalanan iki ekran (kendi profilim / açık profil) tam da bu
/// yüzden ayrışmıştı ve 21 Ağu'da tek kaynağa çekilmek zorunda kalındı.
///
/// KİŞİ SONUÇLARI ELENİR: `search/multi` kişi de döndürür ama iki çağıran da
/// (sohbette paylaşım, akışta yorum) yalnız dizi/film bağlayabiliyor.
/// Afişsiz kayıt da elenir: listede boş kutu görünürdü.
class IcerikSecSheet extends StatefulWidget {
  const IcerikSecSheet({super.key});

  @override
  State<IcerikSecSheet> createState() => _IcerikSecSheetState();
}

class _IcerikSecSheetState extends State<IcerikSecSheet> {
  final _arama = TextEditingController();
  Timer? _geciktirici;
  List<dynamic> _sonuclar = [];
  bool _araniyor = false;

  @override
  void dispose() {
    _arama.dispose();
    _geciktirici?.cancel();
    super.dispose();
  }

  void _degisti(String q) {
    _geciktirici?.cancel();
    _geciktirici = Timer(const Duration(milliseconds: 400), () => _ara(q));
  }

  Future<void> _ara(String q) async {
    if (q.trim().length < 2) return;
    if (mounted) setState(() => _araniyor = true);
    try {
      final d = await Api.get(
        '/tmdb/search/multi?query=${Uri.encodeComponent(q.trim())}',
      );
      if (!mounted) return;
      setState(() {
        _sonuclar = (d['results'] as List<dynamic>)
            .where(
              (r) =>
                  (r['media_type'] == 'tv' || r['media_type'] == 'movie') &&
                  r['poster_path'] != null,
            )
            .toList();
        _araniyor = false;
      });
    } catch (_) {
      if (mounted) setState(() => _araniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: _arama,
              autofocus: true,
              onChanged: _degisti,
              decoration: InputDecoration(
                hintText: 'Dizi veya film ara...'.c,
                prefixIcon: Icon(Icons.search, color: DiziRenkler.metin),
              ),
            ),
          ),
          if (_araniyor)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _sonuclar.length,
              itemBuilder: (context, i) {
                final r = _sonuclar[i] as Map<String, dynamic>;
                final poster = posterUrl(
                  r['poster_path'] as String?,
                  boyut: 'w92',
                );
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 34,
                      height: 50,
                      child: poster != null
                          ? CachedNetworkImage(
                              imageUrl: poster,
                              httpHeaders: gorselBasliklari(poster),
                              fit: BoxFit.cover,
                            )
                          : Container(color: DiziRenkler.kart),
                    ),
                  ),
                  title: Text(
                    (r['name'] ?? r['title'] ?? '?') as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    r['media_type'] == 'tv' ? 'Dizi'.c : 'Film'.c,
                    style: TextStyle(fontSize: 11, color: DiziRenkler.metin38),
                  ),
                  onTap: () => Navigator.pop(context, r),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// İçerik seçiciyi alt sayfada açar; seçilen TMDB kaydını döndürür.
Future<Map<String, dynamic>?> icerikSecAc(BuildContext context) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DiziRenkler.koyuGri,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => const IcerikSecSheet(),
  );
}
