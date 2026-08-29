import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../ceviri.dart';
import '../sohbet_olay.dart';
import '../tema.dart';
import 'dogum_gunu.dart';
import 'ortak.dart' show DaireGorsel;
import 'profil.dart' show profilYenileTetik;
import 'oturum_dustu.dart';
import 'yasakli.dart';

/// Masaüstünde alt çubuğun genişliği. Ada 280 dp'de SABİT tutuldu: 21 Ağu
/// 2026'da Keşfet hedefi çubuktan çıkıp yerine Mesajlar geçince masaüstü de
/// mobil gibi BEŞ hedefe indi, yani hedef başına 278/5 ≈ 55.6 dp düşüyor —
/// [dokunmaAsgari]'nin rahat üstünde (önceki altı hedefli düzende 46.3 dp
/// ile sınıra dayanıyordu). Adayı büyütmek yerine sabit tutmanın sebebi ada
/// sayfanın sol alt köşesinde durması; genişledikçe içeriğin üstüne binen bir
/// şerit hâline gelirdi.
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

/// Alt çubuktaki **Mesajlar** hedefinin indeksi (kullanıcı isteği, 21 Ağu
/// 2026: *"Keşfet'i kaldır, oraya mesajlar ikonu koy"*).
///
/// Bu hedef bir kabuk DALI DEĞİL: `/sohbetler` akış dalının içinde yaşıyor ve
/// üst bardaki DM kısayollarıyla AYNI şekilde `push` ile açılıyor (geri tuşu
/// bulunulan sayfaya döner; `go` olsaydı dönemezdi). Çubuğa bağlanan
/// `onSec` bu indeksi görünce `goBranch` yerine o kısayolu çalıştırır.
///
/// DİKKAT — HEDEF İNDEKSİ ≠ DAL İNDEKSİ. 3 numaralı DAL hâlâ Keşfet'tir
/// ([kesfetDali]); çubukta karşılığı kalmadı, Akış başlığındaki görünüm
/// seçicisinden açılıyor. Dal → hedef çevirisi [hedefIndeksi]'dedir.
const int mesajIndeksi = 3;

/// Akış hedefinin/dalının indeksi.
const int akisHedefi = 2;

/// Keşfet'in (Reels ızgarası, `/arama`) kabuk DAL indeksi. Çubukta hedefi
/// YOK: Akış'ın bir görünümü sayıldığı için [akisHedefi] vurgulanır.
const int kesfetDali = 3;

/// Profil hedefinin/dalının indeksi.
const int profilHedefi = 4;

/// Kabuk dalını alt çubuk hedefine çevirir.
///
/// Keşfet dalı ([kesfetDali]) çubukta artık Mesajlar'ın oturduğu indekstir;
/// çeviri yapılmasaydı kullanıcı Keşfet'e bakarken çubukta MESAJLAR seçili
/// görünürdü. Keşfet, Akış başlığından seçilen bir görünüm olduğu için
/// [akisHedefi] vurgulanır.
@visibleForTesting
int hedefIndeksi(int dal) => dal == kesfetDali ? akisHedefi : dal;

bool mesajYuzeyiMi(String yol) =>
    yol.startsWith('/sohbet') || yol.startsWith('/mesaj-istekleri');

/// Çubukta HANGİ hedefin sarı yanacağı — DAL ÜYELİĞİNDEN AYRI bir sorudur.
///
/// NEDEN AYRI (29 Ağu 2026, kullanıcı: "aşağıdaki 5'li navigasyonda mesajlar
/// hariç hepsine tıklayınca sarı oluyor, mesajlara tıklayınca olmuyor"):
/// Mesajlar bir dal DEĞİL, akış dalının içinde `push` edilir (geri tuşu
/// çalışsın diye, bkz. `onSec`). Bu yüzden `shell.currentIndex` hiçbir zaman
/// [mesajIndeksi] olmuyor ve [kabukSekmeIndeksi] de mesaj yollarını bilerek
/// [akisHedefi]e eşliyordu — ikisi de NAVİGASYON için doğru, ama GÖRSEL
/// geri bildirim için yanlıştı: kullanıcı bastığı sekmenin yandığını görmeli.
///
/// Dal üyeliği DEĞİŞMEDİ: `push`/`goBranch` davranışı, geri tuşu ve
/// [kabukSekmeIndeksi]nin döndürdüğü değer aynen duruyor. Değişen tek şey
/// çubuğun boyadığı hedef.
@visibleForTesting
int kabukSecili(String yol, int dalHedefi) =>
    mesajYuzeyiMi(yol) ? mesajIndeksi : dalHedefi;

/// Alt gezinme sekmeleri. İlk dört hedefin seçili / seçili olmayan ikonu
/// AYNI ikon ailesinden olmalı (yalnız içi dolu/boş farkı) — yoksa sekme
/// değiştikçe ikon başka bir şeye dönüşüyormuş gibi görünür. Test bunu kilitler.
///
/// Sağdaki beşinci hedef kişi ikonu DEĞİL: oturumdaki yuvarlak avatar
/// ([KabukProfilIkonu]). Fotoğraf yoksa yedek olarak kişi ikonu ailesi durur.
///
/// KEŞFET BURADA YOK ama KAYBOLMADI: Akış ekranının başlığı artık bir görünüm
/// seçicisi (Akış ⇄ Keşfet, bkz. `akis.dart` → [AkisGorunumSecici]) ve
/// `/arama` rotası olduğu gibi duruyor. Yerine gelen Mesajlar hedefi mobilde
/// de masaüstünde de AYNI: 17 Ağu'da masaüstüne 6. hedef olarak eklenmişti,
/// mobilde yer yok diye kapalıydı; Keşfet çıkınca beşinci yer boşaldı ve iki
/// düzen tek listede birleşti.
///
/// [okunmamis] > 0 ise Mesajlar hedefinin üstünde sayaç çizilir — üst bardaki
/// [RozetliIkon] ile AYNI kaynaktan (`SohbetOlaylari.okunmamis`) beslenir.
List<NavigationDestination> kabukHedefleri({
  int okunmamis = 0,
  String? avatarUrl,
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
    // Ana Sayfa ve Akış üst barlarındaki DM kısayoluyla aynı ikon ailesi:
    // aynı yere giden üç düğme farklı çizilirse ayrı özellik sanılır.
    icon: _rozetli(const Icon(Icons.near_me_outlined), okunmamis),
    selectedIcon: _rozetli(const Icon(Icons.near_me), okunmamis),
    label: 'Mesajlar'.c,
  ),
  NavigationDestination(
    icon: KabukProfilIkonu(url: avatarUrl),
    selectedIcon: KabukProfilIkonu(url: avatarUrl, secili: true),
    label: 'Profil'.c,
  ),
];

/// Oturumdaki avatarın tam HTTPS adresi.
///
/// Ağaçta [Oturum] yoksa (birim testleri çubuğu tek başına çizer), girişsizse
/// veya yol boşsa null — çubuk kişi ikonuna düşer. [listen] true: Ayarlar'dan
/// fotoğraf değişince beşli çubuk kendiliğinden yenilenir.
@visibleForTesting
String? kabukAvatarUrl(BuildContext context) {
  Oturum? oturum;
  try {
    oturum = Provider.of<Oturum>(context, listen: true);
  } on ProviderNotFoundException {
    oturum = null;
  }
  final ham = oturum?.kullanici?['avatar'];
  if (ham is! String || ham.trim().isEmpty) return null;
  return dosyaUrl(ham);
}

/// Rozet + oturum avatarını birleştiren canlı hedef listesi.
List<NavigationDestination> _canliHedefler(
  BuildContext context,
  int okunmamis,
) => kabukHedefleri(okunmamis: okunmamis, avatarUrl: kabukAvatarUrl(context));

/// Alt çubuğun sağındaki profil hedefi: yuvarlak fotoğraf, GIF oynar.
///
/// `CircleAvatar(backgroundImage:)` KULLANILMAZ — o görseli DecorationImage
/// olarak boyar ve animasyonlu GIF'in yalnız ilk karesini çizer (8/9 Ağu
/// 2026). Fotoğraf [DaireGorsel] → [AgGorsel] ile gelir; web'de de kareler
/// akar. Fotoğraf yoksa (misafir / henüz yüklenmemiş) kişi ikonu yedeği.
class KabukProfilIkonu extends StatelessWidget {
  /// Diğer çubuk ikonlarıyla aynı görsel ölçü; dokunma alanı çubuk hedefinin
  /// 44 dp kutusudur, dairenin kendisi değil.
  static const double cap = 24;

  final String? url;
  final bool secili;

  const KabukProfilIkonu({super.key, this.url, this.secili = false});

  @override
  Widget build(BuildContext context) {
    if (url != null) {
      return DaireGorsel(
        url: url!,
        cap: cap,
        arkaplan: DiziRenkler.koyuGri,
        ikonRenk: DiziRenkler.metin38,
      );
    }
    return Icon(secili ? Icons.person : Icons.person_outline, size: cap);
  }
}

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
    // Beş hedef — dördüncüsü artık Mesajlar (Keşfet, Akış başlığındaki
    // görünüm seçicisine taşındı).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: sistemCubukStili(altCubukZemini(context)),
      // Rozet ortak kaynaktan okunur ki üst bardaki DM rozetiyle AYNI anda
      // değişsin (masaüstü adasıyla birebir aynı kalıp).
      child: ValueListenableBuilder<int>(
        valueListenable: SohbetOlaylari.okunmamis,
        builder: (context, okunmamis, _) => NavigationBar(
          // Etiketler gizli: dört ikon + yuvarlak avatar zaten tanıdık;
          // yazılar çubuğu yükseltip içerik alanını daraltıyordu.
          // label'lar SİLİNMEDİ — erişilebilirlik (TalkBack) onları okuyor.
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          height: mobilCubukYuksekligi,
          selectedIndex: secili,
          onDestinationSelected: onSec,
          destinations: _canliHedefler(context, okunmamis),
        ),
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

  /// Beş hedefli gezinme adası (mobil çubukla AYNI liste). Rozet sayısı ortak
  /// kaynaktan okunur ki üst bardaki DM rozetiyle aynı anda değişsin.
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
        // Mesajlar dâhil TÜM hedefler çağırana devredilir: `push` mi `go` mu
        // olacağına kabuk-içi/kabuk-dışı bağlamı bilen taraf karar verir
        // (bkz. [KabukEkrani] ve [kabukSekmeyeGit]). Ada kabuk DIŞINDA da
        // çiziliyor; buradan `push` etmek orada ikinci bir kabuk kurup
        // siyah ekran üretirdi.
        onDestinationSelected: onSec,
        destinations: _canliHedefler(context, okunmamis),
      ),
    ),
  );

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

/// Beş HEDEFİN kök yolları (soldan sağa). Kabuk-dışı sayfadan hedefe
/// basınca [kabukSekmeyeGit] buraya gider.
///
/// 3. sıra artık `/arama` (Keşfet) değil `/sohbetler`: Keşfet çubuktan çıkıp
/// Akış başlığındaki görünüm seçicisine taşındı (21 Ağu 2026). Rotası
/// duruyor — yalnız çubuktaki hedefi yok.
const List<String> kabukSekmeKokleri = [
  '/kesfet',
  '/takvim',
  '/akis',
  '/sohbetler',
  '/profil',
];

/// Yola göre hangi hedef seçili görünür.
///
/// Kabuk-dışı tarama sayfaları (/icerik, /gonderi, /kisi…) Ana Sayfa (0)
/// sayılır. Profil ailesi (ayarlar, istatistik, kitaplık) 4. hedeftir.
///
/// `/arama` (Keşfet) AKIŞ (2) sayılır — kabuktaki [hedefIndeksi] çevirisiyle
/// birebir aynı kural: Keşfet artık Akış'ın bir görünümü. Mesaj yüzeyleri de
/// (sohbetler, mesaj istekleri) bugünkü gibi Akış'ta kalır: onlar kabuğun
/// akış dalının İÇİNDE `push` edilen sayfalar, ayrı bir dal değil.
@visibleForTesting
int kabukSekmeIndeksi(String yol) {
  if (yol.startsWith('/takvim')) return 1;
  if (yol.startsWith('/akis') ||
      yol == '/arama' ||
      yol.startsWith('/kullanici') ||
      yol.startsWith('/bildirim') ||
      yol.startsWith('/sohbet') ||
      yol.startsWith('/kisi-ara') ||
      yol.startsWith('/mesaj-istekleri')) {
    return akisHedefi;
  }
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

/// Masaüstünde kabuk-dışı sayfadan beşli çubuğa basınca ilgili hedefe git.
///
/// MESAJLAR BURADA `go`, KABUK İÇİNDE `push`: bu işlev yalnız kabuğun
/// DIŞINDAKİ sayfalardan (detay, ayarlar, gönderi…) çağrılıyor ve `/sohbetler`
/// kabuğun içinde bir rota. Oradan `push` etmek kabuğu ikinci kez kurar
/// (GlobalKey çakışması → siyah ekran); bilinen tuzak `rotayaGit`in
/// başlığında anlatılıyor.
void kabukSekmeyeGit(BuildContext context, int i) {
  if (i < 0 || i >= kabukSekmeKokleri.length) return;
  if (i == profilHedefi) profilYenileTetik.value++;
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
        secili: kabukSecili(yol, kabukSekmeIndeksi(yol)),
        onSec: (i) => kabukSekmeyeGit(context, i),
      ),
    );
  }
}

/// Ana kabuk: Ana Sayfa · Takvim · Akış · Mesajlar · Profil.
/// StatefulShellRoute ile sekme durumu korunur ve URL sekmeyi yansıtır.
class KabukEkrani extends StatefulWidget {
  final StatefulNavigationShell shell;
  const KabukEkrani({super.key, required this.shell});

  @override
  State<KabukEkrani> createState() => _KabukEkraniState();
}

class _KabukEkraniState extends State<KabukEkrani> {
  /// Mesajlar yüzeyi şu an açık mı — çubuğun boyayacağı hedefi belirler.
  ///
  /// NEDEN DURUM, ROTA OKUMASI DEĞİL (29 Ağu 2026): Mesajlar bir dal değil,
  /// `push` ile açılıyor; `shell.currentIndex` değişmiyor. İlk denemede
  /// `routerDelegate.currentConfiguration.uri.path` okundu — EMÜLATÖRDE
  /// ÇALIŞMADI, çubuk dalın hedefinde kaldı.
  ///
  /// NEDEN GLOBAL DEĞİL: ikinci denemede üst düzey bir `ValueNotifier`
  /// kullanıldı ve TESTLER ARASINDA SIZDI — `akis_gorunum_secici_test`
  /// bayrak açık kaldığı için Mesajlar'ı seçili gördü. Durum artık kabuğun
  /// kendi `State`inde; sızıntı imkânsız.
  bool _mesajda = false;

  StatefulNavigationShell get shell => widget.shell;

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
      body: OturumDustuKatmani(
        child: DogumGunuKatmani(child: YasakSeridi(child: shell)),
      ),
      // ROUTER DİNLENİR, tek seferlik OKUNMAZ. `GoRouter.maybeOf(context)` ile
      // yolu okumak değişikliğe ABONE OLMAZ: mesajlar dalın İÇİNE `push`
      // edildiği için `shell.currentIndex` değişmiyor, kabuk da yeniden
      // çizilmiyordu — çubuk eski hedefte kalıyordu. (29 Ağu 2026: ilk
      // denemede tam bu yüzden sarı yanmadı, emülatörde görüldü.)
      // `routerDelegate` bir `ChangeNotifier`; push/pop'ta haber verir.
      bottomNavigationBar: kabukCubugu(
        context,
        // Dal → hedef çevirisi ŞART: Keşfet dalındayken (3) çeviri olmadan
        // çubukta Mesajlar seçili görünürdü (bkz. [hedefIndeksi]).
        // Üstüne mesaj yüzeyi kontrolü (bkz. [kabukSecili]).
        secili: _mesajda ? mesajIndeksi : hedefIndeksi(shell.currentIndex),
        onSec: (i) async {
          // Mesajlar bir dal DEĞİL: `push` ile üste açılır (üst bardaki DM
          // düğmeleriyle aynı davranış), dönünce rozet tazelenir. `go`
          // kullansaydık kullanıcı geri tuşuyla bulunduğu sayfaya dönemezdi.
          if (i == mesajIndeksi) {
            setState(() => _mesajda = true);
            try {
              await context.push('/sohbetler');
            } finally {
              // `finally`: geri tuşuyla çıkılsa da hata atsa da bayrak
              // MUTLAKA iner; yoksa çubuk Mesajlar'da takılı kalırdı.
              if (mounted) setState(() => _mesajda = false);
            }
            await SohbetOlaylari.okunmamisYenile();
            return;
          }
          if (i == profilHedefi) profilYenileTetik.value++;
          shell.goBranch(
            i,
            // Aynı hedefe tekrar basınca köke dön. Karşılaştırma ÇEVRİLMİŞ
            // hedefle yapılır: Keşfet dalındayken (3) çubukta Akış (2) seçili
            // görünüyor, yani kullanıcı için bu "seçili sekmeye tekrar
            // basmak"tır ve karşılığı Akış'ın kökü olmalıdır. Dal indeksiyle
            // karşılaştırsaydık akış dalında en son ne açıksa (ör. bildirimler)
            // o gelirdi — kullanıcı Akış istemişken.
            initialLocation: i == hedefIndeksi(shell.currentIndex),
          );
        },
      ),
    );
  }
}
