import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ceviri.dart';
import '../sohbet_olay.dart';
import '../tema.dart';
import 'dogum_gunu.dart';
import 'profil.dart' show profilYenileTetik;
import 'yasakli.dart';

/// Masaüstünde alt çubuğun genişliği. Ada 280 dp'de SABİT tutuldu: masaüstüne
/// 6. hedef (Mesajlar) eklenince hedef başına 278/6 ≈ 46.3 dp düşüyor ve bu
/// hâlâ [dokunmaAsgari]'nin üstünde. Adayı büyütmek yerine hedefleri
/// daraltmak seçildi çünkü ada sayfanın sol alt köşesinde duruyor; genişledikçe
/// içeriğin üstüne binen bir şerit hâline gelirdi. 6 hedefin ötesine
/// çıkılacaksa buranın da büyütülmesi gerekir (46.3 → 44 sınırına çok yakın).
const double masaustuCubukGenisligi = 280;

/// Masaüstünde adanın SAĞINDA duran katla/aç düğmesinin genişliği ve iki
/// parçanın arasındaki boşluk. Düğme adanın İÇİNE değil yanına konuldu:
/// içeri alsaydık gezinme hedeflerinden çalıp hepsini 44 dp altına düşürürdü.
const double masaustuKatlaGenisligi = dokunmaAsgari;
const double masaustuKatlaAraligi = 8;

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

/// Masaüstünde Mesajlar hedefinin indeksi. Kabuğun (StatefulShellRoute) beş
/// dalı var; bu 6. öğe bir DAL DEĞİL, `/sohbetler`e giden bir kısayol —
/// `onDestinationSelected` onu dal değiştirmeden ayırt edebilsin diye sabit.
const int masaustuMesajIndeksi = 5;

/// Alt gezinme sekmeleri. Kural: bir sekmenin seçili ve seçili olmayan ikonu
/// AYNI ikon ailesinden olmalı (yalnız içi dolu/boş farkı) — yoksa sekme
/// değiştikçe ikon başka bir şeye dönüşüyormuş gibi görünür. Test bunu kilitler.
///
/// [mesajlar] YALNIZ masaüstünde açılır (kullanıcı isteği, 17 Ağu 2026).
/// Mobilde çubuk ekran genişliğini beşe bölüyor; altıncı hedef telefonu
/// 44 dp dokunma sınırına dayardı, o yüzden varsayılan kapalı.
/// [okunmamis] > 0 ise hedefin üstünde sayaç çizilir — üst bardaki
/// [RozetliIkon] ile AYNI kaynaktan (`SohbetOlaylari.okunmamis`) beslenir.
List<NavigationDestination> kabukHedefleri({
  bool mesajlar = false,
  int okunmamis = 0,
}) => [
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
  if (mesajlar)
    NavigationDestination(
      // Ana Sayfa ve Akış üst barlarındaki DM kısayoluyla aynı ikon ailesi:
      // aynı yere giden üç düğme farklı çizilirse ayrı özellik sanılır.
      icon: _rozetli(const Icon(Icons.near_me_outlined), okunmamis),
      selectedIcon: _rozetli(const Icon(Icons.near_me), okunmamis),
      label: 'Mesajlar'.c,
    ),
];

/// Hedefin üstüne okunmamış sayacı. Sayı 0'ken [Badge] hiç çizilmez —
/// `isLabelVisible` yerine widget'ı komple atlamak, boş rozetin ikonu
/// kaydırmasını da engeller.
Widget _rozetli(Widget ikon, int sayi) => sayi > 0
    ? Badge.count(
        count: sayi,
        backgroundColor: DiziRenkler.sari,
        textColor: Colors.black,
        child: ikon,
      )
    : ikon;

/// Katla/aç okunun yönü. Açıkken ok adayı KAPATACAĞI yöne (adaya doğru),
/// katlıyken adanın açılacağı yöne bakar.
@visibleForTesting
IconData katlaOku(bool katli, bool rtl) =>
    katli == rtl ? Icons.chevron_left : Icons.chevron_right;

/// Masaüstü gezinme adasının katlanma tercihi.
///
/// KALICI: kullanıcı adayı kapattıysa her F5'te geri gelmesi, kapatma
/// eyleminin hiç işe yaramaması demektir. Tercih [SiraTercihi] ile aynı
/// kalıpta tutulur — açılışta bir kez okunur, sonrası bellekten.
class KabukKatlama {
  KabukKatlama._();

  static const anahtar = 'masaustu_cubuk_katli';

  /// Varsayılan AÇIK (katlı değil): gezinme çubuğunu ilk kez gören kullanıcı
  /// onu bulabilmeli; katlama bilinçli bir tercih olmalı.
  static final ValueNotifier<bool> katli = ValueNotifier(false);

  /// `main.dart` açılışında bir kez çağrılır.
  static Future<void> yukle() async {
    try {
      final p = await SharedPreferences.getInstance();
      katli.value = p.getBool(anahtar) ?? false;
    } catch (_) {
      // Tercih okunamazsa açık hâlde kal: gezinmesiz bir ekran, geniş bir
      // çubuktan çok daha kötü.
    }
  }

  static Future<void> degistir() async {
    katli.value = !katli.value;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(anahtar, katli.value);
    } catch (_) {
      // Yazılamazsa tercih bu oturumda geçerli olur; kullanıcıya hata
      // göstermeye değmez (çubuk zaten katlandı).
    }
  }
}

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
  if (!masaustuMu(context)) {
    // Mobil: ekranın en altındaki renk ÇUBUĞUN zeminidir; sistem çubuğu da
    // o renge boyanır (Android ≤14) / o rengin üstündeki perde kaldırılır (15+).
    // Beş hedef — masaüstüne eklenen Mesajlar burada AÇILMAZ (yer yok).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: sistemCubukStili(altCubukZemini(context)),
      child: NavigationBar(
        // Etiketler gizli: beş ikon (ev, takvim, akış, pusula, kişi) zaten
        // tanıdık; yazılar çubuğu yükseltip içerik alanını daraltıyordu.
        // label'lar SİLİNMEDİ — erişilebilirlik (TalkBack) onları okuyor.
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        height: mobilCubukYuksekligi,
        selectedIndex: secili,
        onDestinationSelected: onSec,
        destinations: kabukHedefleri(),
      ),
    );
  }
  return AnnotatedRegion<SystemUiOverlayStyle>(
    // Masaüstü/büyük tablet düzeninde ekranın en altında ada DEĞİL sayfa zemini
    // var — sistem çubuğu bu yüzden scaffold zeminine uyar.
    value: sistemCubukStili(Theme.of(context).scaffoldBackgroundColor),
    child: _MasaustuAda(secili: secili, onSec: onSec),
  );
}

/// Masaüstünde sol alt köşeye oturan gezinme adası + yanındaki katla/aç
/// düğmesi.
///
/// Bindirme DEĞİL yine `bottomNavigationBar` yuvası — Scaffold yüksekliği
/// kadar yer ayırdığı için sayfa içeriği adanın ALTINDA KALMAZ. KabukEkrani
/// ile testler AYNI bu widget'ı kullanır; ölçüm gerçek düzeni ölçer.
///
/// KATLI HÂLDE ADA ÇİZİLMEZ, düğme kalır: çubuk tamamen kaybolsaydı geri
/// açmanın görünür bir yolu olmazdı.
class _MasaustuAda extends StatelessWidget {
  final int secili;
  final ValueChanged<int> onSec;
  const _MasaustuAda({required this.secili, required this.onSec});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: KabukKatlama.katli,
      builder: (context, katli, _) => Padding(
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
          // AnimatedSize satırın kendi boyunu yumuşatır; içindeki ada sabit
          // genişlikte kaldığı için katlanırken ikonlar ezilmez, kayarak
          // kırpılır. Süre kısa (180 ms): gezinme çubuğu her tıkta beklenen
          // bir şey değil, gösteri değil geri bildirim olmalı.
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: AlignmentDirectional.centerStart,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!katli) ...[
                  _ada(context),
                  const SizedBox(width: masaustuKatlaAraligi),
                ],
                _katlaDugmesi(context, katli),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Altı hedefli gezinme adası. Rozet sayısı ortak kaynaktan okunur ki üst
  /// bardaki DM rozetiyle aynı anda değişsin.
  Widget _ada(BuildContext context) => Container(
    key: const Key('masaustu-alt-cubuk'),
    width: masaustuCubukGenisligi,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: DiziRenkler.metin12),
    ),
    child: ValueListenableBuilder<int>(
      valueListenable: SohbetOlaylari.okunmamis,
      builder: (context, okunmamis, _) => NavigationBar(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        height: masaustuCubukYuksekligi,
        selectedIndex: secili,
        onDestinationSelected: (i) => _hedefSecildi(context, i),
        destinations: kabukHedefleri(mesajlar: true, okunmamis: okunmamis),
      ),
    ),
  );

  /// Mesajlar bir kabuk dalı DEĞİL: `push` ile üste açılır (üst bardaki DM
  /// düğmeleriyle aynı davranış), dönünce rozet tazelenir. `go` kullansaydık
  /// kullanıcı geri tuşuyla bulunduğu sayfaya dönemezdi.
  Future<void> _hedefSecildi(BuildContext context, int i) async {
    if (i != masaustuMesajIndeksi) {
      onSec(i);
      return;
    }
    await context.push('/sohbetler');
    await SohbetOlaylari.okunmamisYenile();
  }

  /// Katla/aç düğmesi. Durum ÜÇ kanaldan okunur: okun YÖNÜ (görsel),
  /// `Tooltip` (fare) ve `Semantics.expanded` (ekran okuyucu). Kullanıcı
  /// `<>` diye tarif etti ama iki oku birden göstermek "şu an hangisi?"
  /// sorusunu cevapsız bırakır — tek ok, duruma göre yön değiştirir.
  Widget _katlaDugmesi(BuildContext context, bool katli) {
    return Semantics(
      expanded: !katli,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: altCubukZemini(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: DiziRenkler.metin12),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const Key('masaustu-cubuk-katla'),
            onTap: KabukKatlama.degistir,
            child: Tooltip(
              // 'Tekrar göster' ödünç alındı: 45 dilde karşılığı olan bir
              // "genişlet" anahtarı yok ve tek bir metin için 45 dosyaya
              // dokunmak bu turun işi değil (bkz. rapor).
              message: katli ? 'Tekrar göster'.c : 'Daralt'.c,
              child: SizedBox(
                width: masaustuKatlaGenisligi,
                height: masaustuCubukYuksekligi,
                child: Icon(
                  // Ok, adanın DURDUĞU yöne bakmalı. Arapça/İbranice/Urduca
                  // düzende ada sağda olduğu için yönler ters çevrilir; sabit
                  // `chevron_left` yazsaydık o dillerde ok adayı değil boşluğu
                  // gösterirdi.
                  katlaOku(
                    katli,
                    Directionality.of(context) == TextDirection.rtl,
                  ),
                  color: DiziRenkler.metin70,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
