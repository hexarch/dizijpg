import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../ceviri.dart';
import '../sohbet_olay.dart';
import '../tema.dart';
import 'arama_cubugu.dart';
import 'ortak.dart';

/// Ana Sayfa rafları: (başlık, TMDB yolu, tür).
///
/// Yol sayfa parametresi İÇERMEZ — raf ilk sayfayı gösterir, "Tümünü gör"
/// ekranı aynı yolu sayfalayarak devam ettirir.
const anaSayfaRaflari = <(String, String, String)>[
  ('Haftanın Dizileri', '/tmdb/trending/tv/week', 'tv'),
  ('Haftanın Filmleri', '/tmdb/trending/movie/week', 'movie'),
  (
    'Türk Dizileri',
    '/tmdb/discover/tv?sort_by=popularity.desc&with_original_language=tr',
    'tv',
  ),
  (
    'Türk Filmleri',
    '/tmdb/discover/movie?sort_by=popularity.desc&with_original_language=tr',
    'movie',
  ),
  (
    'En Yüksek Puanlı Filmler',
    '/tmdb/discover/movie?sort_by=vote_average.desc&vote_count.gte=3000',
    'movie',
  ),
  (
    'En Yüksek Puanlı Diziler',
    '/tmdb/discover/tv?sort_by=vote_average.desc&vote_count.gte=1000',
    'tv',
  ),
  (
    'En Çok İzlenen Filmler',
    '/tmdb/discover/movie?sort_by=popularity.desc&vote_count.gte=500',
    'movie',
  ),
  (
    'Popüler Diziler',
    '/tmdb/discover/tv?sort_by=popularity.desc&vote_count.gte=200',
    'tv',
  ),
  (
    'En Çok Kazanan Filmler',
    '/tmdb/discover/movie?sort_by=revenue.desc&vote_count.gte=500',
    'movie',
  ),
  (
    'Kült Filmler',
    '/tmdb/discover/movie?sort_by=vote_count.desc&vote_average.gte=7.5'
        '&primary_release_date.lte=2005-12-31',
    'movie',
  ),
  (
    'Tüm Zamanların En İyileri',
    '/tmdb/discover/movie?sort_by=vote_count.desc&vote_average.gte=8',
    'movie',
  ),
  (
    'Yeni Diziler',
    '/tmdb/discover/tv?sort_by=first_air_date.desc&vote_count.gte=20',
    'tv',
  ),
  (
    'Yeni Filmler',
    '/tmdb/discover/movie?sort_by=primary_release_date.desc'
        '&vote_count.gte=100',
    'movie',
  ),
];

/// "Sana Özel" rafının başlığı (çeviri anahtarı) ve tam sayfa adresi.
///
/// NEDEN `anaSayfaRaflari`NDA DEĞİL: o tablo üçlüsü (ad, TMDB yolu, tür)
/// Keşfet'in raf ÇEKME döngüsünü de besliyor (`for (final r in anaSayfaRaflari)
/// Api.get(r.$2)`). Buraya bir kayıt eklemek üç şeyi birden bozardı:
///  1. Raf İKİ KEZ çekilirdi (döngüde bir, aşağıdaki `if (Api.girisli)`
///     dalında bir),
///  2. Döngü oturumu SORMUYOR — oturumsuz ziyaretçi `/onerilen`den 401 yerdi,
///  3. Yanıtın liste alanı `results` değil `oneriler`.
///
/// NEDEN ADRES `/raf/sana-ozel` DEĞİL, KÖK YOL: bu raf kişiye özel, yani rota
/// OTURUM ZORUNLU ve robots.txt ile kapatılmalı. Projede robots.txt kuralları
/// JOKER İÇERMİYOR (`backend/test/seo_gizlilik.test.js` kilitliyor); tek bir
/// `/raf/...` alt yolunu kapatmanın yolu ya joker ya da `/raf/` ön ekinin
/// tamamını kapatmaktı — ikincisi herkese açık katalog sayfalarını da taramaya
/// kapatırdı. Kök yol ikisini de gerektirmez.
const sanaOzelBaslik = 'Sana Özel';
const sanaOzelYolu = '/sana-ozel';

/// Türkçe raf başlığından üretilen KALICI adres parçası (`/raf/:slug`).
///
/// NEDEN BAŞLIKTAN, NEDEN İNDEKSTEN DEĞİL: indeks kullansaydık
/// [anaSayfaRaflari]'na araya bir raf eklemek paylaşılmış/yer imlenmiş tüm
/// adresleri BAŞKA bir rafa çevirirdi. Slug listedeki sırayla değil, rafın
/// kendi kimliğiyle bağlı.
///
/// ÇEVİRİDEN DEĞİL, TÜRKÇE ANAHTARDAN: başlık 45 dile çevriliyor; çeviriden
/// üretilen adres kullanıcının diline göre değişir ve İngilizce açılan bir
/// bağlantı Türkçe oturumda kırılırdı.
///
/// Türkçe harfler ÖNCE katlanır, SONRA küçük harfe inilir: Dart'ın
/// `toLowerCase()`i 'İ'yi iki kod birimine ('i' + birleşen nokta) çevirir ve
/// adreste görünmez bir karakter bırakırdı.
String rafSlug(String baslik) {
  const katla = {
    'Ç': 'C',
    'Ğ': 'G',
    'İ': 'I',
    'Ö': 'O',
    'Ş': 'S',
    'Ü': 'U',
    'ç': 'c',
    'ğ': 'g',
    'ı': 'i',
    'ö': 'o',
    'ş': 's',
    'ü': 'u',
  };
  final duz = baslik.split('').map((h) => katla[h] ?? h).join();
  return duz
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp('^-+|-+\$'), '');
}

/// [rafSlug] ile eşleşen rafı bulur; yoksa null (bozuk/eski bağlantı).
(String, String, String)? rafBul(String? slug) {
  if (slug == null || slug.isEmpty) return null;
  for (final raf in anaSayfaRaflari) {
    if (rafSlug(raf.$1) == slug) return raf;
  }
  return null;
}

class KesfetEkrani extends StatefulWidget {
  const KesfetEkrani({super.key});

  @override
  State<KesfetEkrani> createState() => _KesfetEkraniState();
}

class _KesfetEkraniState extends State<KesfetEkrani> {
  Map<String, List<dynamic>>? _bolumler;
  int _mesajSayi = 0;

  Future<void> _mesajSayisiYukle() async {
    // Oturumsuz ziyaretçi (SEO 1.4, 14 Ağu): rozet ucu girisZorunlu, 401
    // yememek için hiç isteme. Rozet zaten 0 kalır.
    if (!Api.girisli) return;
    try {
      final d = await Api.get('/sohbetler/okunmamis');
      // Masaüstü gezinme adasının rozeti de bu sayıdan besleniyor: ortak
      // kaynağa yazmazsak ada bayat kalır (kendi isteğini atmıyor).
      SohbetOlaylari.okunmamis.value = (d['okunmamis'] as int?) ?? 0;
      if (mounted) {
        setState(() => _mesajSayi = SohbetOlaylari.okunmamis.value);
      }
    } catch (_) {}
  }

  String? _hata;

  @override
  void initState() {
    super.initState();
    _onbellektenYukle();
    _yukle();
    _mesajSayisiYukle();
  }

  /// Son başarılı raflar anında gösterilir (SWR): ekran boş iskelette
  /// beklemez, taze veri arkadan gelip üzerine yazar.
  Future<void> _onbellektenYukle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ham = prefs.getString('kesfet_onbellek');
      if (ham == null || !mounted || _bolumler != null) return;
      final d = jsonDecode(ham) as Map<String, dynamic>;
      if (_bolumler == null) {
        setState(() {
          _bolumler = {for (final e in d.entries) e.key: e.value as List};
        });
      }
    } catch (_) {}
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      // Tüm raflar + öneriler paralel çekilir (öneri hatası rafları düşürmez).
      final istekler = <Future<dynamic>>[
        for (final r in anaSayfaRaflari) Api.get(r.$2),
        // /onerilen girisZorunlu — oturumsuz ziyaretçiye "Sana Özel" rafı yok.
        if (Api.girisli)
          Api.get(
            '/onerilen',
          ).catchError((_) => <String, dynamic>{'oneriler': <dynamic>[]})
        else
          Future<Map<String, dynamic>>.value({'oneriler': <dynamic>[]}),
      ];
      final sonuclar = await Future.wait(istekler);
      if (!mounted) return;
      final onerilen =
          (sonuclar.last['oneriler'] as List<dynamic>? ?? <dynamic>[]);
      final bolumler = <String, List<dynamic>>{
        if (onerilen.isNotEmpty) sanaOzelBaslik: onerilen,
        for (var i = 0; i < anaSayfaRaflari.length; i++)
          anaSayfaRaflari[i].$1:
              (sonuclar[i]['results'] as List<dynamic>? ?? <dynamic>[]),
      };
      setState(() => _bolumler = bolumler);
      SharedPreferences.getInstance().then(
        (p) => p.setString('kesfet_onbellek', jsonEncode(bolumler)),
      );
    } catch (e) {
      if (!mounted) return;
      if (_bolumler == null) setState(() => _hata = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_bolumler == null) {
      // İskelet raflar: içerik gelene dek nabız atan kutular
      govde = ListView(
        padding: const EdgeInsets.only(top: 8),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var s = 0; s < 3; s++) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IskeletKutu(genislik: 150, yukseklik: 18),
              ),
            ),
            // İskelet ölçüsü GERÇEK şeritle aynı olmalı: masaüstünde şerit
            // kartı 168 dp'ye büyüdü, iskelet 118'de kalsaydı içerik gelince
            // düzen zıplardı (CLS).
            SizedBox(
              height: seritKartiGenisligi(context) * 1.5 + seritBaslikPayi,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, __) =>
                    IskeletKutu(genislik: seritKartiGenisligi(context)),
              ),
            ),
          ],
        ],
      );
    } else {
      final rafMap = {for (final r in anaSayfaRaflari) r.$1: r};
      govde = RefreshIndicator(
        color: DiziRenkler.sari,
        onRefresh: _yukle,
        child: ListView(
          children: [
            for (final e in _bolumler!.entries)
              PosterSeridi(
                baslik: e.key.c,
                icerikler: e.value,
                turZorla: rafMap[e.key]?.$3,
                // "Sana Özel" 19 Ağu 2026'ya kadar "Tümünü gör"süz TEK raftı:
                // içeriği `/onerilen` ucundan geliyor, `anaSayfaRaflari`ndaki
                // gibi sabit bir TMDB yolu YOK, yani `/raf/:slug` onu
                // sayfalayamıyordu. Artık uç `?sayfa=` alıyor ve rafın kendi
                // tam sayfa adresi var ([sanaOzelYolu]).
                //
                // ADRESE YAZILAN gezinme (14 Ağu 2026). Eskiden burada
                // `Navigator.push(MaterialPageRoute(...))` vardı: sayfa
                // açılıyor ama URL `/kesfet`te kalıyordu, yani F5 kullanıcıyı
                // Keşfet'e geri atıyordu (canlıda ölçüldü). `context.push`
                // aynı görünümü verir — rota Keşfet şubesinin içinde, alt
                // gezinme çubuğu yerinde kalır — ama adres sayfayı yansıtır.
                onBaslikTap: e.key == sanaOzelBaslik
                    ? () => context.push(sanaOzelYolu)
                    : rafMap[e.key] == null
                    ? null
                    : () => context.push('/raf/${rafSlug(rafMap[e.key]!.$1)}'),
              ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    final genis = masaustuMu(context);

    // Marka bloğu ve eylem ikonları iki düzende de AYNI yerden gelir: dar
    // ekranda AppBar'a, masaüstünde AramaCubugu'nun üst barına verilir.
    //
    // DAR EKRAN ÖLÇÜSÜ (360 dp): logo 40 + BETA 57 + sürüm 77 + boşluklar =
    // 204 dp, iki eylem ikonu 100 dp → arama kutusuna 56 dp kalıyordu; büyüteç
    // + tek kelimelik ipucu bile sığmaz. Bu yüzden dar ekranda logo 30'a
    // küçültüldü ve BETA rozeti gizlendi (sürüm metni DURUYOR — kullanıcı onu
    // referans alıyor; beta bilgisi sürümün ipucunda/erişilebilirlik
    // etiketinde kaldı). Böylece kutuya ~127 dp açıldı.
    final marka = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/logo.png', height: genis ? 40 : 30),
        SizedBox(width: genis ? 8 : 6),
        // BETA rozeti (marka sarısı pill) — yalnız masaüstünde yer var
        if (genis) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: DiziRenkler.sari,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'BETA',
              style: TextStyle(
                color: Colors.black,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        // Sürüm numarası (yapı numarası olmadan). Dar ekranda rozet
        // gizlendiği için beta bilgisi buranın ipucuna/etiketine taşınır.
        Tooltip(
          message: genis ? '' : 'BETA v${Api.surum.split('+').first}',
          child: Text(
            'v${Api.surum.split('+').first}',
            semanticsLabel: genis
                ? null
                : 'BETA v${Api.surum.split('+').first}',
            style: TextStyle(
              color: DiziRenkler.metin38,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
    final eylemler = <Widget>[
      // Katalog gözat (türe göre keşif)
      IconButton(
        tooltip: 'Gözat'.c,
        icon: const Icon(Icons.grid_view_outlined),
        onPressed: () => context.push('/gozat'),
      ),
      // Instagram tarzı DM kısayolu
      RozetliIkon(
        ikon: Icons.near_me_outlined,
        sayi: _mesajSayi,
        etiket: 'Mesajlar'.c,
        onTap: () async {
          await context.push('/sohbetler');
          _mesajSayisiYukle();
        },
      ),
      const SizedBox(width: 4),
    ];

    return Scaffold(
      // Masaüstünde AppBar YOK: arama kutusu pencerenin en üst satırında,
      // yatayda tam ortada dursun diye üst bar AramaCubugu'na devredildi.
      //
      // DAR EKRANDA arama kutusu artık üst barın İÇİNDE: marka bloğu (logo +
      // sürüm) ile eylem ikonlarının (Gözat, Mesajlar) TAM ARASINDA. Expanded
      // aradaki boşluğun tamamını kutuya verir; kutu ne taşar ne kırpılır.
      appBar: genis
          ? null
          : AppBar(
              titleSpacing: 12,
              title: Row(
                children: [
                  marka,
                  const SizedBox(width: 8),
                  const Expanded(child: AramaAcmaKutusu()),
                ],
              ),
              actions: eylemler,
            ),
      // Akışla AYNI arama bileşeni (ortak widget)
      body: AramaCubugu(
        cocuk: govde,
        logo: genis ? marka : null,
        eylemler: genis ? eylemler : const [],
      ),
    );
  }
}
