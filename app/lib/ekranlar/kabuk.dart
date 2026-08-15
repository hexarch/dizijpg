import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../ceviri.dart';
import '../tema.dart';
import 'dogum_gunu.dart';
import 'profil.dart' show profilYenileTetik;
import 'yasakli.dart';

/// Masaüstünde alt çubuğun genişliği: 5 hedef × 56 dp. 56 dp dokunma alanı
/// 44 dp asgarisinin üstünde kalır — küçültürken buranın altına inilmemeli.
const double masaustuCubukGenisligi = 280;

/// Dokunma hedefi asgarisi (ui-ux-pro-max "Touch Target Size", severity High).
/// Alt çubuk yüksekliği = hedeflerin dokunma yüksekliği, bunun altına İNMEZ.
const double dokunmaAsgari = 44;

/// Mobilde alt çubuğun yüksekliği. Material 3 varsayılanı 80 dp idi; 3 Ağu
/// isteğiyle %35 kısaltıldı → 80 × 0.65 = 52 dp. 52 hâlâ [dokunmaAsgari]'nin
/// üstünde olduğu için mobilde istenen oran BİREBİR uygulanabildi.
const double mobilCubukYuksekligi = 52;

/// Masaüstünde alt çubuğun yüksekliği. Eskiden 56 dp idi; aynı %35 kuralı
/// 36.4 dp verirdi ve bu [dokunmaAsgari]'nin ALTINA düşerdi — erişilebilirliği
/// bozmamak için 44 dp'de durduruldu (%21.4 kısalma).
const double masaustuCubukYuksekligi = dokunmaAsgari;

/// Masaüstünde çubuğun sol/alt kenar boşluğu.
const double masaustuCubukKenar = 12;

/// Alt gezinme sekmeleri. Kural: bir sekmenin seçili ve seçili olmayan ikonu
/// AYNI ikon ailesinden olmalı (yalnız içi dolu/boş farkı) — yoksa sekme
/// değiştikçe ikon başka bir şeye dönüşüyormuş gibi görünür. Test bunu kilitler.
List<NavigationDestination> kabukHedefleri() => [
  NavigationDestination(
    icon: const Icon(Icons.home_outlined),
    selectedIcon: const Icon(Icons.home),
    label: 'Ana Sayfa'.c,
  ),
  NavigationDestination(
    icon: const Icon(Icons.calendar_month_outlined),
    selectedIcon: const Icon(Icons.calendar_month),
    label: 'Takvim'.c,
  ),
  NavigationDestination(
    icon: const Icon(Icons.add_circle_outline, size: 30),
    selectedIcon: const Icon(Icons.add_circle, size: 30),
    label: 'Akış'.c,
  ),
  NavigationDestination(
    icon: const Icon(Icons.explore_outlined),
    selectedIcon: const Icon(Icons.explore),
    label: 'Keşfet'.c,
  ),
  NavigationDestination(
    icon: const Icon(Icons.person_outline),
    selectedIcon: const Icon(Icons.person),
    label: 'Profil'.c,
  ),
];

/// Alt çubuğun ZEMİN rengi. Temadan okunur (`diziTema` →
/// `navigationBarTheme.backgroundColor` = [DiziRenkler.koyuGri]) ki sistem
/// gezinme çubuğuna verilen renkle ASLA ayrışmasın: tek kaynak, tek renk.
Color altCubukZemini(BuildContext context) =>
    Theme.of(context).navigationBarTheme.backgroundColor ?? DiziRenkler.koyuGri;

/// Scaffold'un `bottomNavigationBar` yuvasına konan çubuk.
///
/// SİSTEM ÇUBUĞU: çubuk, ekranın en altındaki [AnnotatedRegion] olduğu için
/// Android'in gezinme çubuğu stilini O belirler (bkz. `sistemCubukStili`).
/// Bildirim DEKLARATİFTİR — imperatif `SystemChrome` çağrısı yok; tema/düzen
/// değişince kendiliğinden güncellenir ve web'de (SystemChrome etkisiz olduğu
/// yerde) fazladan hiçbir şey çalışmaz.
///
/// DAR EKRAN: bugünkü tam genişlikte NavigationBar (mobil düzen aynen kalır).
/// MASAÜSTÜ: [masaustuCubukGenisligi] dp genişliğinde, sol alt köşeye oturan
/// dar bir ada. Bindirme DEĞİL yine bottomNavigationBar yuvası — Scaffold
/// yüksekliği kadar yer ayırdığı için sayfa içeriği çubuğun ALTINDA KALMAZ.
/// KabukEkrani ile testler AYNI bu işlevi kullanır; ölçüm gerçek düzeni ölçer.
Widget kabukCubugu(
  BuildContext context, {
  required int secili,
  required ValueChanged<int> onSec,
}) {
  final genis = masaustuMu(context);
  final cubuk = NavigationBar(
    // Etiketler gizli: beş ikon (ev, takvim, akış, pusula, kişi) zaten
    // tanıdık; yazılar çubuğu yükseltip içerik alanını daraltıyordu.
    // label'lar SİLİNMEDİ — erişilebilirlik (TalkBack) onları okuyor.
    labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
    height: genis ? masaustuCubukYuksekligi : mobilCubukYuksekligi,
    selectedIndex: secili,
    onDestinationSelected: onSec,
    destinations: kabukHedefleri(),
  );
  if (!genis) {
    // Mobil: ekranın en altındaki renk ÇUBUĞUN zeminidir; sistem çubuğu da
    // o renge boyanır (Android ≤14) / o rengin üstündeki perde kaldırılır (15+).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: sistemCubukStili(altCubukZemini(context)),
      child: cubuk,
    );
  }
  return AnnotatedRegion<SystemUiOverlayStyle>(
    // Masaüstü/büyük tablet düzeninde ekranın en altında ada DEĞİL sayfa zemini
    // var — sistem çubuğu bu yüzden scaffold zeminine uyar.
    value: sistemCubukStili(Theme.of(context).scaffoldBackgroundColor),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        masaustuCubukKenar,
        0,
        masaustuCubukKenar,
        masaustuCubukKenar,
      ),
      // heightFactor: 1 ŞART — Align gevşek kısıtta ekran boyunca uzamaya
      // çalışır; 1 ile yüksekliğini çocuğuna eşitler.
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        heightFactor: 1,
        child: Container(
          key: const Key('masaustu-alt-cubuk'),
          width: masaustuCubukGenisligi,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: DiziRenkler.metin12),
          ),
          child: cubuk,
        ),
      ),
    ),
  );
}

/// Beş sekmenin kök yolları (soldan sağa). Kabuk-dışı sayfadan sekmeye
/// basınca [context.go] buraya gider.
const List<String> kabukSekmeKokleri = [
  '/kesfet',
  '/takvim',
  '/akis',
  '/arama',
  '/profil',
];

/// Yola göre hangi sekme seçili görünür.
///
/// Kabuk-dışı tarama sayfaları (/icerik, /gonderi, /kisi…) Ana Sayfa (0)
/// sayılır. Profil ailesi (ayarlar, istatistik, kitaplık) 4. sekmedir.
@visibleForTesting
int kabukSekmeIndeksi(String yol) {
  if (yol.startsWith('/takvim')) return 1;
  if (yol.startsWith('/akis') ||
      yol.startsWith('/kullanici') ||
      yol.startsWith('/bildirim') ||
      yol.startsWith('/sohbet') ||
      yol.startsWith('/kisi-ara') ||
      yol.startsWith('/mesaj-istekleri')) {
    return 2;
  }
  if (yol == '/arama') return 3;
  if (yol.startsWith('/profil') ||
      yol.startsWith('/kitaplik') ||
      yol.startsWith('/favori-oyuncular') ||
      yol.startsWith('/ayarlar') ||
      yol.startsWith('/gizlenen-yorumlar') ||
      yol.startsWith('/engellenenler') ||
      yol.startsWith('/istatistiklerim') ||
      yol.startsWith('/hareketlerim') ||
      yol.startsWith('/izlediklerim') ||
      yol.startsWith('/ozet')) {
    return 4;
  }
  return 0;
}

/// Masaüstünde kabuk-dışı sayfadan beşli çubuğa basınca ilgili sekmeye git.
void kabukSekmeyeGit(BuildContext context, int i) {
  if (i < 0 || i >= kabukSekmeKokleri.length) return;
  if (i == 4) profilYenileTetik.value++;
  context.go(kabukSekmeKokleri[i]);
}

/// Masaüstünde alt gezinme adasını sayfaya bağlar; mobilde çocuğu olduğu
/// gibi bırakır (detay tam ekran kalır).
///
/// Kabuğun (StatefulShellRoute) İÇİNDE kullanılmaz — orada [KabukEkrani]
/// zaten çubuğu taşır; iki kez bağlamak çift ada üretir.
class MasaustuKaliciCubuk extends StatelessWidget {
  final Widget cocuk;
  const MasaustuKaliciCubuk({super.key, required this.cocuk});

  @override
  Widget build(BuildContext context) {
    if (!masaustuMu(context)) return cocuk;
    final yol =
        GoRouter.maybeOf(
          context,
        )?.routerDelegate.currentConfiguration.uri.path ??
        '/';
    return Scaffold(
      body: cocuk,
      bottomNavigationBar: kabukCubugu(
        context,
        secili: kabukSekmeIndeksi(yol),
        onSec: (i) => kabukSekmeyeGit(context, i),
      ),
    );
  }
}

/// Ana kabuk: Keşfet · Takvim · Arama · Profil.
/// StatefulShellRoute ile sekme durumu korunur ve URL sekmeyi yansıtır.
class KabukEkrani extends StatelessWidget {
  final StatefulNavigationShell shell;
  const KabukEkrani({super.key, required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Hesap askıya alındıysa üstte ince bir şerit çıkar (dokununca sebep +
      // kalan süre). Yasak yokken hiçbir yer kaplamaz — kabuk aynen eskisi
      // gibi çizilir. Buraya konmasının sebebi: kullanıcı hangi sekmede olursa
      // olsun cezasından haberdar olmalı; tek bir ekrana koysaydık oraya hiç
      // uğramayan kullanıcı sessizce kısıtlanmış olurdu.
      // DOĞUM GÜNÜ (md. 36): kutlama kabuğun GÖVDESİNİ sarar, tek bir sekmeye
      // konmaz — kullanıcı hangi sekmede açarsa açsın görsün. Doğum günü
      // değilse ya da tarih girilmemişse katman hiçbir şey çizmez, ölçüye de
      // dokunmaz (`build` doğrudan `child`ı döndürür).
      body: DogumGunuKatmani(child: YasakSeridi(child: shell)),
      bottomNavigationBar: kabukCubugu(
        context,
        secili: shell.currentIndex,
        onSec: (i) {
          if (i == 4) profilYenileTetik.value++;
          shell.goBranch(
            i,
            // Aynı sekmeye tekrar basınca köke dön
            initialLocation: i == shell.currentIndex,
          );
        },
      ),
    );
  }
}
