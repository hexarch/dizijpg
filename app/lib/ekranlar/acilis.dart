import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import '../uygulama_daveti_hedef.dart' show DavetMagaza;

/// AÇILIŞ (VİTRİN) SAYFASI — oturumsuz ziyaretçinin `dizijpg.com` kökünde
/// gördüğü ilk ekran (15 Eyl 2026, kullanıcı isteği: "dizi.jpg için güzel bir
/// giriş sayfası yazılmalı").
///
/// NEDEN AYRI BİR EKRAN: kök adres eskiden oturumsuzda doğrudan `/kesfet`e
/// düşüyordu. Keşfet bir RAF sayfasıdır; uygulamanın ne olduğunu, neden hesap
/// açılacağını anlatmaz — ilk ziyaretçi afiş duvarına bakıp çıkıyordu.
/// Oturumlu kullanıcı bu ekranı HİÇ görmez: yönlendirici `/`yi `/kesfet`e
/// çevirir (`yonlendirme.dart`). Mobil uygulama da görmez: platform adresi
/// olmadığında başlangıç rotası `/kesfet` kalır ([baslangicRotasi]).
///
/// TASARIM (ui-ux-pro-max "App Store Style Landing" kalıbı): gerçek afişler
/// (haftanın trendleri, canlı veri), özellik kartları, mağaza düğmeleri.
/// Rakam VERİLMEZ (kullanıcı sayısı vb.) — doğrulanamayan sayı yazılmaz.
/// Sarı yalnız EYLEM rengidir (birincil düğme, ikon rozeti, vurgu çizgisi);
/// metin rengi değil ([DiziRenkler.sariMetin] açık temada koyulaşır).
class AcilisEkrani extends StatefulWidget {
  const AcilisEkrani({super.key});

  @override
  State<AcilisEkrani> createState() => _AcilisEkraniState();
}

class _AcilisEkraniState extends State<AcilisEkrani> {
  /// Afiş duvarı: haftanın dizileri + filmleri, afişi olanlar. Boş liste
  /// = yükleniyor ya da ağ yok; ikisinde de iskelet çizilir, sayfa çökmez.
  List<String> _afisler = const [];

  @override
  void initState() {
    super.initState();
    _afisleriGetir();
  }

  Future<void> _afisleriGetir() async {
    try {
      final yanitlar = await Future.wait([
        Api.get('/tmdb/trending/tv/week'),
        Api.get('/tmdb/trending/movie/week'),
      ]);
      final yollar = <String>[];
      // Dizi ve film sırayla karışsın: duvar tek türe kaymasın.
      final listeler = yanitlar
          .map((y) => ((y as Map)['results'] as List? ?? const []))
          .toList();
      final azami = listeler.fold<int>(
        0,
        (m, l) => l.length > m ? l.length : m,
      );
      for (var i = 0; i < azami; i++) {
        for (final liste in listeler) {
          if (i >= liste.length) continue;
          final yol = (liste[i] as Map)['poster_path'] as String?;
          if (yol != null && !yollar.contains(yol)) yollar.add(yol);
        }
      }
      if (!mounted) return;
      setState(() => _afisler = yollar.take(_afisSayisi).toList());
    } catch (_) {
      // Vitrin canlı veriye BAĞIMLI DEĞİL: ağ yoksa iskelet kalır.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, kisit) {
            final genis = kisit.maxWidth >= 900;
            final orta = kisit.maxWidth >= 600;
            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _sayfaGenisligi),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: orta ? 32 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _UstCubuk(orta: orta),
                        SizedBox(height: genis ? 56 : 32),
                        _Kahraman(genis: genis, orta: orta, afisler: _afisler),
                        SizedBox(height: genis ? 96 : 64),
                        _Ozellikler(sutun: genis ? 3 : (orta ? 2 : 1)),
                        SizedBox(height: genis ? 96 : 64),
                        _UygulamaBandi(orta: orta),
                        const SizedBox(height: 48),
                        const _AltBilgi(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

const double _sayfaGenisligi = 1120;

/// Afiş duvarındaki kart sayısı (4×3). Daha azı gelirse boş hücreler iskelet
/// olarak kalır; daha fazlası kırpılır.
const int _afisSayisi = 12;

// ---------------------------------------------------------------------------
// Üst çubuk: logo + giriş / başla
// ---------------------------------------------------------------------------

class _UstCubuk extends StatelessWidget {
  const _UstCubuk({required this.orta});

  final bool orta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Image.asset('assets/logo.png', height: 30, semanticLabel: 'dizi.jpg'),
          const Spacer(),
          TextButton(
            key: const Key('acilis-giris'),
            onPressed: () => context.go('/giris'),
            child: Text(
              'Giriş yap'.c,
              style: TextStyle(color: DiziRenkler.metin, fontSize: 15),
            ),
          ),
          if (orta) ...[
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('acilis-basla-ust'),
              onPressed: () => context.go('/giris'),
              child: Text('Ücretsiz başla'.c),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kahraman alanı: başlık + eylemler + afiş duvarı
// ---------------------------------------------------------------------------

class _Kahraman extends StatelessWidget {
  const _Kahraman({
    required this.genis,
    required this.orta,
    required this.afisler,
  });

  final bool genis;
  final bool orta;
  final List<String> afisler;

  @override
  Widget build(BuildContext context) {
    final metin = _KahramanMetni(genis: genis, orta: orta);
    final duvar = _AfisDuvari(afisler: afisler, sutun: orta ? 4 : 3);
    if (genis) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 5, child: metin),
          const SizedBox(width: 48),
          Expanded(flex: 6, child: duvar),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [metin, const SizedBox(height: 40), duvar],
    );
  }
}

class _KahramanMetni extends StatelessWidget {
  const _KahramanMetni({required this.genis, required this.orta});

  final bool genis;
  final bool orta;

  @override
  Widget build(BuildContext context) {
    final hizalama = genis
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.center;
    final metinHizasi = genis ? TextAlign.start : TextAlign.center;
    return Column(
      crossAxisAlignment: hizalama,
      children: [
        // Vurgu çizgisi: markanın raf başlıklarındaki sarı şerit dili.
        Container(
          width: 56,
          height: 5,
          decoration: BoxDecoration(
            color: DiziRenkler.sari,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'İzlediğin her şeyi tek yerde takip et'.c,
          textAlign: metinHizasi,
          style: TextStyle(
            fontSize: genis ? 48 : (orta ? 40 : 32),
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: DiziRenkler.metin,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Dizilerini bölüm bölüm işaretle, film listeni tut, puanla ve yorumla; arkadaşlarının ne izlediğini gör. Ücretsiz, web ve mobilde.'
              .c,
          textAlign: metinHizasi,
          style: TextStyle(
            fontSize: orta ? 18 : 16,
            height: 1.5,
            color: DiziRenkler.metin70,
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          alignment: genis ? WrapAlignment.start : WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              height: 52,
              child: FilledButton(
                key: const Key('acilis-basla'),
                onPressed: () => context.go('/giris'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text('Ücretsiz başla'.c),
              ),
            ),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                key: const Key('acilis-kesfet'),
                onPressed: () => context.go('/kesfet'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  side: BorderSide(color: DiziRenkler.metin24),
                  foregroundColor: DiziRenkler.metin,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                icon: const Icon(Icons.explore_outlined, size: 20),
                label: Text("Keşfet'e göz at".c),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Ücretsiz. 45 dilde. Web, Android ve iOS.'.c,
          textAlign: metinHizasi,
          style: TextStyle(fontSize: 13, color: DiziRenkler.metin54),
        ),
      ],
    );
  }
}

/// Haftanın afişlerinden hafif eğik bir duvar. Eğim ClipRRect İÇİNDE: taşan
/// köşeler kırpılır, dokunma hedefi yoktur (salt görsel — afişe basınca bir
/// şey olmaz, bu bir vitrin).
class _AfisDuvari extends StatelessWidget {
  const _AfisDuvari({required this.afisler, required this.sutun});

  final List<String> afisler;
  final int sutun;

  @override
  Widget build(BuildContext context) {
    final satir = (_afisSayisi / sutun).ceil();
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        color: DiziRenkler.koyuGri,
        padding: const EdgeInsets.all(16),
        child: Transform.rotate(
          angle: -0.05,
          child: Transform.scale(
            scale: 1.08,
            child: GridView.builder(
              key: const Key('acilis-afis-duvari'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: sutun,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2 / 3,
              ),
              itemCount: satir * sutun,
              itemBuilder: (context, i) {
                final yol = i < afisler.length ? afisler[i] : null;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: yol == null
                      ? ColoredBox(color: DiziRenkler.kart)
                      : CachedNetworkImage(
                          imageUrl: posterUrl(yol)!,
                          fit: BoxFit.cover,
                          fadeInDuration: const Duration(milliseconds: 250),
                          placeholder: (_, __) =>
                              ColoredBox(color: DiziRenkler.kart),
                          errorWidget: (_, __, ___) =>
                              ColoredBox(color: DiziRenkler.kart),
                        ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Özellik kartları
// ---------------------------------------------------------------------------

class _Ozellik {
  const _Ozellik(this.ikon, this.baslik, this.aciklama);

  final IconData ikon;
  final String baslik;
  final String aciklama;
}

/// Yalnız ÜRÜNDE OLAN özellikler; her cümle canlı bir ekrana karşılık gelir.
const _ozellikler = <_Ozellik>[
  _Ozellik(
    Icons.playlist_add_check_rounded,
    'Bölüm bölüm takip',
    'Kaldığın yeri asla kaybetme: sezonları ve bölümleri tek dokunuşla işaretle, ilerlemeni gör.',
  ),
  _Ozellik(
    Icons.calendar_month_rounded,
    'Takvim',
    'Yeni bölümler ve vizyon tarihleri takviminde; hiçbir bölümü kaçırma.',
  ),
  _Ozellik(
    Icons.star_rounded,
    'Puanla ve yorumla',
    'Ondalıklı puan ver, yorum yaz; IMDb, Rotten Tomatoes ve Metacritic puanlarını yan yana gör.',
  ),
  _Ozellik(
    Icons.list_alt_rounded,
    'Kendi listelerin',
    'Listeler oluştur, sırala ve paylaş; izleme listen her cihazında seninle.',
  ),
  _Ozellik(
    Icons.people_alt_rounded,
    'Arkadaşlarınla',
    'Akışta arkadaşlarının ne izlediğini gör, yorumlarına tepki ver, mesajlaş.',
  ),
  _Ozellik(
    Icons.live_tv_rounded,
    'Birlikte izle',
    'İzleme odasında aynı anda izleyin ve sohbet edin.',
  ),
];

class _Ozellikler extends StatelessWidget {
  const _Ozellikler({required this.sutun});

  final int sutun;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Neler yapabilirsin?'.c,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: DiziRenkler.metin,
          ),
        ),
        const SizedBox(height: 32),
        LayoutBuilder(
          builder: (context, kisit) {
            const bosluk = 16.0;
            final kartGenisligi =
                (kisit.maxWidth - bosluk * (sutun - 1)) / sutun;
            return Wrap(
              spacing: bosluk,
              runSpacing: bosluk,
              children: [
                for (final o in _ozellikler)
                  SizedBox(
                    width: kartGenisligi,
                    child: _OzellikKarti(ozellik: o),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _OzellikKarti extends StatelessWidget {
  const _OzellikKarti({required this.ozellik});

  final _Ozellik ozellik;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: DiziRenkler.kart,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DiziRenkler.metin12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: DiziRenkler.sari,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(ozellik.ikon, color: Colors.black, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            ozellik.baslik.c,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: DiziRenkler.metin,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ozellik.aciklama.c,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: DiziRenkler.metin70,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Uygulama bandı: mağaza düğmeleri
// ---------------------------------------------------------------------------

class _UygulamaBandi extends StatelessWidget {
  const _UygulamaBandi({required this.orta});

  final bool orta;

  Future<void> _ac(DavetMagaza magaza) =>
      launchUrl(Uri.parse(magaza.adres), webOnlyWindowName: '_blank');

  @override
  Widget build(BuildContext context) {
    final dugmeler = Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        _MagazaDugmesi(
          key: const Key('acilis-play'),
          ikon: Icons.android,
          etiket: 'Google Play',
          onPressed: () => _ac(DavetMagaza.play),
        ),
        _MagazaDugmesi(
          key: const Key('acilis-appstore'),
          ikon: Icons.apple,
          etiket: 'App Store',
          onPressed: () => _ac(DavetMagaza.appStore),
        ),
      ],
    );
    return Container(
      padding: EdgeInsets.all(orta ? 36 : 24),
      decoration: BoxDecoration(
        color: DiziRenkler.koyuGri,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Image.asset('assets/logo.png', height: 44, semanticLabel: 'dizi.jpg'),
          const SizedBox(height: 16),
          Text(
            'Uygulamayı indir'.c,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: DiziRenkler.metin,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Daha hızlı gezinme, bildirimler ve tam ekran deneyim uygulamada.'
                .c,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: DiziRenkler.metin70),
          ),
          const SizedBox(height: 24),
          dugmeler,
        ],
      ),
    );
  }
}

class _MagazaDugmesi extends StatelessWidget {
  const _MagazaDugmesi({
    super.key,
    required this.ikon,
    required this.etiket,
    required this.onPressed,
  });

  final IconData ikon;
  final String etiket;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: BorderSide(color: DiziRenkler.metin24),
          foregroundColor: DiziRenkler.metin,
        ),
        icon: Icon(ikon, size: 22),
        // Mağaza adları markadır, çevrilmez.
        label: Text(
          etiket,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Alt bilgi
// ---------------------------------------------------------------------------

class _AltBilgi extends StatelessWidget {
  const _AltBilgi();

  @override
  Widget build(BuildContext context) {
    final stil = TextStyle(fontSize: 13, color: DiziRenkler.metin54);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 20,
      runSpacing: 8,
      children: [
        Text('© dizi.jpg', style: stil),
        TextButton(
          onPressed: () => context.push('/gizlilik'),
          child: Text('Gizlilik Politikası'.c, style: stil),
        ),
        // TMDB kullanım koşulu: veri kaynağı görünür biçimde anılır.
        Text('Yapım verileri: TMDB'.c, style: stil),
      ],
    );
  }
}
