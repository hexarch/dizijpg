import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'arama_cubugu.dart';
import 'katalog_liste.dart';
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

class KesfetEkrani extends StatefulWidget {
  const KesfetEkrani({super.key});

  @override
  State<KesfetEkrani> createState() => _KesfetEkraniState();
}

class _KesfetEkraniState extends State<KesfetEkrani> {
  Map<String, List<dynamic>>? _bolumler;
  int _mesajSayi = 0;

  Future<void> _mesajSayisiYukle() async {
    // Oturumsuz ziyaretçi (SEO 1.4, 14 Ağu): /sohbetler girisZorunlu, 401
    // yememek için hiç isteme. Rozet zaten 0 kalır.
    if (!Api.girisli) return;
    try {
      final d = await Api.get('/sohbetler');
      if (mounted) {
        setState(() => _mesajSayi = (d['okunmamis'] as int?) ?? 0);
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
        if (onerilen.isNotEmpty) 'Sana Özel': onerilen,
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
                // "Sana Özel" kişiye özel üretiliyor, sayfalanamaz.
                onBaslikTap: rafMap[e.key] == null
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => KatalogListeEkrani(
                            baslik: rafMap[e.key]!.$1,
                            yol: rafMap[e.key]!.$2,
                            tur: rafMap[e.key]!.$3,
                          ),
                        ),
                      ),
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
