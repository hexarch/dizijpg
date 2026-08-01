import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'ortak.dart';

/// Ana Sayfa raflarının "Tümünü gör" ekranı.
///
/// Raf yalnız ilk sayfayı (20 içerik) gösterir; buradan TMDB sayfa sayfa
/// çekilir, kullanıcı dibe yaklaşınca sıradaki sayfa eklenir. Poster kartı
/// ortak olduğu için "izledin" rozeti burada da otomatik görünür.
class KatalogListeEkrani extends StatefulWidget {
  final String baslik;

  /// TMDB yolu, sayfa parametresi OLMADAN. Örn:
  /// `/tmdb/discover/movie?sort_by=revenue.desc`
  final String yol;
  final String tur; // 'tv' | 'movie'

  const KatalogListeEkrani({
    super.key,
    required this.baslik,
    required this.yol,
    required this.tur,
  });

  @override
  State<KatalogListeEkrani> createState() => _KatalogListeEkraniState();
}

class _KatalogListeEkraniState extends State<KatalogListeEkrani> {
  final List<dynamic> _icerikler = [];
  final _kaydirma = ScrollController();
  int _sayfa = 0;
  bool _yukluyor = false;
  bool _bitti = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _sonrakiSayfa();
    _kaydirma.addListener(() {
      // Dibe 600px kala sıradaki sayfayı çek: kullanıcı beklemesin.
      if (_kaydirma.position.pixels >=
          _kaydirma.position.maxScrollExtent - 600) {
        _sonrakiSayfa();
      }
    });
  }

  @override
  void dispose() {
    _kaydirma.dispose();
    super.dispose();
  }

  Future<void> _sonrakiSayfa() async {
    if (_yukluyor || _bitti) return;
    setState(() {
      _yukluyor = true;
      _hata = null;
    });
    try {
      final ayirac = widget.yol.contains('?') ? '&' : '?';
      final d = await Api.get('${widget.yol}${ayirac}page=${_sayfa + 1}');
      final gelen = (d['results'] as List<dynamic>? ?? []);
      if (!mounted) return;
      setState(() {
        _sayfa++;
        _icerikler.addAll(gelen);
        // TMDB 500 sayfayı aşmaz; boş sayfa da sonu gösterir.
        if (gelen.isEmpty || _sayfa >= 25) _bitti = true;
        _yukluyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yukluyor = false;
        // İlk sayfa patladıysa hata göster; sonrakilerde sessizce dur.
        if (_icerikler.isEmpty)
          _hata = e.toString();
        else
          _bitti = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(
        mesaj: _hata!,
        tekrar: () {
          _bitti = false;
          _sonrakiSayfa();
        },
      );
    } else if (_icerikler.isEmpty && _yukluyor) {
      govde = GridView.builder(
        padding: const EdgeInsets.all(12),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 10,
          childAspectRatio: 0.5,
        ),
        itemCount: 9,
        itemBuilder: (_, _) => const IskeletKutu(genislik: 110, yukseklik: 210),
      );
    } else {
      final genis = MediaQuery.of(context).size.width > 900;
      govde = GridView.builder(
        controller: _kaydirma,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: genis ? 6 : 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 10,
          childAspectRatio: 0.5,
        ),
        // Son karo: sayfa yüklenirken dönen gösterge
        itemCount: _icerikler.length + (_yukluyor ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _icerikler.length) {
            return const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: DiziRenkler.sari,
                ),
              ),
            );
          }
          return PosterKarti(
            icerik: _icerikler[i] as Map<String, dynamic>,
            turZorla: widget.tur,
            genislik: double.infinity,
          );
        },
      );
    }
    return Scaffold(
      // Raf adları uzun ("Ταινίες με τις περισσότερες προβολές"): tek satırlık
      // AppBar başlığı kesiliyordu. 2 satıra izin ver + puntoyu bir tık düşür;
      // 2x17 pt = ~40 dp, 56 dp'lik araç çubuğuna sığar.
      appBar: AppBar(
        title: Text(
          widget.baslik.c,
          maxLines: 2,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: govde,
    );
  }
}
