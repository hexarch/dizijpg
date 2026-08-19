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
///
/// 19 AĞU 2026 — EKRAN ARTIK YALNIZ TMDB'YE BAĞLI DEĞİL. "Sana Özel" rafı
/// kişiye özel `/onerilen` ucundan geliyor; o ucun sayfa parametresi `sayfa`
/// ve liste alanı `oneriler`. Sayfalama/iskelet/hata/ızgara mantığı birebir
/// aynı olduğu için EKRANI KOPYALAMAK yerine bu iki ad parametreleştirildi —
/// ikinci bir kopya, "dibe 600 px kala çek" gibi ince ayarların ikisinden
/// birinde sessizce eskimesi demekti.
class KatalogListeEkrani extends StatefulWidget {
  final String baslik;

  /// Veri yolu, sayfa parametresi OLMADAN. Örn:
  /// `/tmdb/discover/movie?sort_by=revenue.desc` ya da `/onerilen`.
  final String yol;

  /// 'tv' | 'movie' — TÜM liste tek türdeyse. Öneri listesi karışık
  /// (`media_type` her yapımda ayrı geliyor), orada null geçilir ve
  /// [PosterKarti] kendi `media_type` alanına düşer.
  final String? tur;

  /// Sayfa numarasının sorgu parametresi adı. TMDB proxy'si `page` bekler,
  /// kişiye özel `/onerilen` ucu `sayfa`.
  final String sayfaParam;

  /// Yanıttaki liste alanının adı (`results` / `oneriler`).
  final String sonucAnahtari;

  const KatalogListeEkrani({
    super.key,
    required this.baslik,
    required this.yol,
    this.tur,
    this.sayfaParam = 'page',
    this.sonucAnahtari = 'results',
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
      final d = await Api.get(
        '${widget.yol}$ayirac${widget.sayfaParam}=${_sayfa + 1}',
      );
      final gelen = (d[widget.sonucAnahtari] as List<dynamic>? ?? []);
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
    } else if (_icerikler.isEmpty && !_yukluyor) {
      // BOŞ IZGARA YERİNE BOŞ DURUM. TMDB rafları pratikte hiç boş dönmüyordu
      // ama `/onerilen` dönebilir: izleme geçmişi olmayan (ya da havuzu
      // tamamen kitaplığında olan) kullanıcı. Eskiden bu hâlde ekran KAPKARA
      // kalırdı — kullanıcı için "sayfa bozuk" demek.
      govde = BosDurum(
        ikon: Icons.local_movies_outlined,
        baslik: 'Yapım bulunamadı'.c,
      );
    } else if (_icerikler.isEmpty && _yukluyor) {
      govde = GridView.builder(
        padding: const EdgeInsets.all(12),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const PosterIzgarasi(satirBoslugu: 12, bosluk: 10),
        itemCount: 9,
        itemBuilder: (_, _) => const IskeletKutu(
          genislik: double.infinity,
          yukseklik: double.infinity,
        ),
      );
    } else {
      govde = GridView.builder(
        controller: _kaydirma,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        // Sütun sayısı ARTIK sabit değil (eskiden geniş ekranda 6): ızgaranın
        // ölçülen genişliğinden türetilir, kart hedef bantta kalır.
        gridDelegate: const PosterIzgarasi(satirBoslugu: 12, bosluk: 10),
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
      // PC'de ızgara ortalanmış ve [masaustuIcerikGenisligi] (1080) ile sınırlı
      // (madde 26); mobilde kısıt bağlamaz.
      body: OrtaKolon(azami: masaustuIcerikGenisligi, cocuk: govde),
    );
  }
}
