import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'api.dart';
import 'ceviri.dart';
import 'tema.dart';
import 'gorusme/gelen_arama_ekrani.dart';
import 'gorusme/gorusme_ekrani.dart';
import 'ekranlar/akis.dart';
import 'ekranlar/altyazi_bicem.dart';
import 'ekranlar/arama_cubugu.dart';
import 'ekranlar/arama_tam_liste.dart';
import 'ekranlar/kesfet_akis.dart';
import 'ekranlar/bildirimler.dart';
import 'ekranlar/ozet.dart';
import 'ekranlar/sohbet.dart';
import 'oda/oda_ekrani.dart';
import 'ekranlar/sohbet_detay.dart';
import 'ekranlar/ayarlar.dart';
import 'ekranlar/bolum.dart';
import 'ekranlar/detay.dart';
import 'ekranlar/giris.dart';
import 'ekranlar/giris_istem.dart';
import 'ekranlar/engellenen_kullanicilar.dart';
import 'ekranlar/gizlenen_yorumlar.dart';
import 'ekranlar/gizlilik.dart';
import 'ekranlar/gonderi_istatistik.dart';
import 'ekranlar/gozat.dart';
import 'ekranlar/hareketlerim.dart';
import 'ekranlar/favori_oyuncular.dart';
import 'ekranlar/istatistiklerim.dart';
import 'ekranlar/izleme_istatistik.dart';
import 'ekranlar/izlediklerim.dart';
import 'ekranlar/kabuk.dart';
import 'ekranlar/karsilama.dart';
import 'ekranlar/katalog_liste.dart';
import 'ekranlar/kesfet.dart';
import 'ekranlar/kisi.dart';
import 'ekranlar/kisi_yapimlar.dart';
import 'ekranlar/sirket.dart';
import 'ekranlar/liste.dart';
import 'ekranlar/kitaplik_liste.dart';
import 'ekranlar/kullanici_kitaplik.dart';
import 'ekranlar/kullanici_profil.dart';
import 'ekranlar/ortak.dart' show kabugaDon, kabukIcindeMi;
import 'ekranlar/profil.dart';
import 'ekranlar/takvim.dart';
import 'ekranlar/yenilikler.dart';

/// Son kurulan yönlendirici — push bildirimi dokunuşları buradan gezinir
/// (bildirim işleyicilerinin BuildContext'i yoktur).
GoRouter? sonYonlendirici;

/// Gelen arama ekranının yolu.
///
/// DİKKAT — bu `/arama` DEĞİL: `/arama` bu projede **dizi/film keşfi**
/// (Reels sekmesi) ve `tamAramaYolu` da tam ekran ARAMA KUTUSU. Sesli/görüntülü
/// arama başka bir şey; dosya adları `gorusme*`, yollar `arama-gelen` /
/// `gorusme`. Backend de aynı çarpışmayı yaşayıp hız limitine `gorusmeLimiti`
/// demişti (server.js:955 `aramaLimiti` = search).
const String gelenAramaYolu = '/arama-gelen';

/// Kabuk-güvenli gezinme: kabuk-içi rotaya kabuk DIŞINDAN push yapılırsa
/// kabuk ikinci kez kurulur (sayfa anahtarı/GlobalKey çakışması → boş, siyah
/// ekran); o durumda go. "Kabuk dışı" kararı elle tutulan yol listesiyle
/// DEĞİL, yönlendiricinin kendi eşleşme ağacıyla verilir — bkz.
/// [kabukIcindeMi]; eski kopyalanmış liste yeni kök rotalarda güncellenmeyip
/// siyah ekran üretiyordu.
void rotayaGit(String hedef) {
  final y = sonYonlendirici;
  if (y == null) return;
  if (kabukIcindeMi(y) || kabugaDon(y)) {
    y.push(hedef);
  } else {
    y.go(hedef);
  }
}

/// Oturum GEREKTİRMEYEN yol ön ekleri.
///
/// NEDEN: sunucu (nginx bot kuralı + `/og/...` uçları) arama motorlarına bu
/// yollar için GERÇEK içerikli HTML döndürüyor. Oturumsuz ziyaretçi aynı
/// adreste giriş formu görseydi bot ile kullanıcının gördüğü sayfa farklı
/// olurdu — Google bunu "cloaking" sayar ve elle ceza verir. SEO-PLANI.md
/// madde 0.1'in tek gerekçesi budur; liste bot kapsamıyla eşleşmelidir.
///
/// Kasıtlı olarak DIŞARIDA bırakılanlar:
/// - `/kullanici/...`: profil sayfası kabuk İÇİNDE ve gizlilik tercihleri
///   (izlenenler_gizli / yorumlar_gizli) varsayılan olarak KAPALI. Herkese
///   açmak, kimsenin onaylamadığı bir kararla tüm profilleri dünyaya (ve iç
///   bağlantılar üzerinden Google'a) açardı. Bot kapsamında da değil.
/// - `/kesfet`, `/takvim`, `/akis`, `/arama`, `/profil`: kişiye özel, botun
///   göremediği ekranlar; oturum gerektirmeleri cloaking yaratmaz.
///
/// `/listeler/` 7 Ağu 2026'da eklendi: nginx'in bot kuralı zaten
/// `^/(icerik|gonderi|kisi|dizi|listeler)/` idi ve `/og/listeler/:id`
/// indekslenebilir HTML basıyordu — yani bot içeriği, insan giriş formunu
/// görüyordu (tam tanımıyla cloaking). GİZLİLİK: sunucu `herkese_acik=false`
/// listeyi sahibi olmayana 404 verir, yani liste rotasının açık olması gizli
/// listeleri açmaz (bkz. server.js `GET /listeler/:id`).
const acikYolOnEkleri = <String>[
  '/icerik/',
  '/kisi/',
  '/gonderi/',
  '/dizi/',
  '/listeler/',
  // Keşfet raflarının "Tümünü gör" sayfası (`/raf/:slug`).
  //
  // NEDEN AÇIK: raflar `/kesfet`te oturumsuz ziyaretçiye de çiziliyor
  // (yalnız "Sana Özel" giriş ister), yani "Tümünü gör" bağlantısı oturumsuz
  // ziyaretçinin GÖRDÜĞÜ bir bağlantı. Kapalı olsaydı zincir tam ortasından
  // kopardı — `/sirket/` ile birebir aynı gerekçe.
  // GİZLİLİK: sayfa yalnız TMDB katalog verisi gösterir, kişiye özel hiçbir
  // alan okumaz. CLOAKING RİSKİ YOK: `/raf/` nginx'in bot kuralında
  // (`^/(icerik|gonderi|kisi|dizi|listeler)/`) yok — bot da insan da AYNI
  // uygulamayı görür.
  '/raf/',
  // Md. 49 — yapım firması sayfası. İçeriğin firma şeridinden açılıyor ve
  // içerik sayfaları zaten oturumsuz açık; burada giriş duvarı zincirin
  // ortasında kopukluk yaratırdı. GİZLİLİK: sayfa yalnız TMDB katalog
  // verisi gösterir, kişiye özel hiçbir alan okumaz. CLOAKING RİSKİ YOK:
  // `/sirket/` nginx'in bot kuralında (`^/(icerik|gonderi|kisi|dizi|listeler)/`)
  // yok, yani bot da insan da AYNI uygulamayı görür.
  '/sirket/',
];

/// Oturum gerektirmeyen tam yollar (ön ek DEĞİL: `/gizlilik-tercihleri` gibi
/// ileride eklenebilecek kişisel bir ekran yanlışlıkla açılmasın).
const acikTamYollar = <String>[
  '/gizlilik',
  // SEO 1.4 — keşif sayfalarının SSR'ı 6 Ağu'dan beri vardı ama Flutter
  // giriş duvarının arkasındaydı; bot içerik, insan /giris görüyordu
  // (cloaking). 14 Ağu'da ikisi de oturumsuz açıldı, `SEO_KESIF_INDEKS`
  // aynı turda `true` yapıldı. Tam yol (ön ek değil): `/kesfet-akis` bir
  // API ucu, Flutter rotası değil; yine de `/kesfet/` diye bir alt yol
  // ileride eklenirse yanlışlıkla açılmasın.
  '/gozat',
  '/kesfet',
];

/// Tek gönderi adresi. [yanit] TRUE ise `?yanit=1` eklenir.
///
/// NEDEN BAYRAK VAR (10 Ağu 2026, md.15): "yanıt" bildirimindeki `yorum_id`
/// yanıtın KENDİ id'sidir, üst gönderinin değil. `/gonderi/:id` ise gelen
/// yorumu tam ekran Reels sayfası olarak çizer; yanıtın medyası olmadığı için
/// ekranda dev puntolu tek bir yazı kalıyordu ("koca ekran"). Bayrak, ekrana
/// "bu id bir YANIT, üstünü çöz ve normal yorum ekranını aç" der.
/// Paylaşım bağlantıları (`/gonderi/123`) bu bayrağı taşımaz, davranışları
/// birebir aynıdır — ek istek de atılmaz.
String gonderiYolu(String yorumId, {bool yanit = false}) =>
    yanit ? '/gonderi/$yorumId?yanit=1' : '/gonderi/$yorumId';

/// Kabuk-dışı sayfayı masaüstünde beşli çubukla sarar; mobilde dokunmaz.
Widget _masa(Widget sayfa) => MasaustuKaliciCubuk(cocuk: sayfa);

/// [yol] oturumsuz ziyaretçiye açık mı?
bool herkeseAcikMi(String yol) =>
    acikTamYollar.contains(yol) || acikYolOnEkleri.any(yol.startsWith);

/// Tarayıcı adresinden uygulama içi başlangıç rotasını çıkarır.
///
/// F5'in tek kaynağı burasıdır: kullanıcı hangi adresteyse uygulama ORADA
/// açılmalı. [adres] null ise (mobil) `/kesfet`.
///
/// Üç ayrı tuzağı birlikte kapatır:
///  1. **Yolu yeniden KODLA.** `Uri.path` yüzde-çözülmüş yol verir; bunu
///     doğrudan konum dizesi olarak vermek `/kullanici/a%20b` gibi adreslerde
///     ayrıştırılamayan bir dize üretir. Segmentler tek tek yeniden kodlanır.
///  2. **Sondaki eğik çizgiyi kırp.** `/akis/` hiçbir rotayla EŞLEŞMEZ ve
///     `errorBuilder`a, yani "Bağlantı geçersiz" ekranına düşerdi — kullanıcı
///     için "beni başka sayfaya attı" demek. Adresi elle yazarken, kopyala
///     yapıştırırken ve eski bağlantılarda sık görülür.
///  3. **Sorgu dizesini KORU.** `?tur=`, `?gun=`, `?yanit=1` gibi süzgeçler
///     sayfanın parçasıdır; kaybolurlarsa kullanıcı aynı yolda ama başka
///     içerikle karşılaşır. Ham (kodlanmış) hâliyle taşınır.
String baslangicRotasi(Uri? adres) {
  if (adres == null) return '/kesfet';
  var parcalar = adres.pathSegments.where((s) => s.isNotEmpty).toList();
  // DİL ÖNEKİ DÜŞER (29 Ağu 2026). Sunucu arama motorlarına dil önekli URL
  // veriyor (`/de/icerik/movie/559`); uygulamada o önekle EŞLEŞEN rota YOK ve
  // `errorBuilder`a, yani "Bağlantı geçersiz" ekranına düşerdi. Yani Almanca
  // arama sonucundan gelen HER ziyaretçi kırık sayfa görürdü.
  //
  // Dilin kendisi kaybolmaz: `Ceviri.yukle(adres: ...)` aynı önekten uygulama
  // dilini seçiyor (sıra: kullanıcı seçimi > adres > cihaz). Burada yalnız
  // ROTA eşleşmesi için önek atılır.
  if (Ceviri.adresDiliKodu(adres) != null) parcalar = parcalar.sublist(1);
  var yol = parcalar.map(Uri.encodeComponent).join('/');
  yol = yol.isEmpty ? '' : '/$yol';
  // Kök adres (`/`, `` ya da yalnız sorgu): uygulamanın ana sayfası.
  if (yol.isEmpty) return '/kesfet';
  if (yenilemeyleAcilmaz(yol)) return '/sohbetler';
  return yol + (adres.hasQuery ? '?${adres.query}' : '');
}

/// Dil önekli adresi öneksiz uygulama rotasına çevirir; öneksizse null.
///
/// `/de/icerik/movie/559` → `/icerik/movie/559`, `/en` → `/kesfet`,
/// `/es/icerik/tv/1396?tur=tv` → `/icerik/tv/1396?tur=tv`.
///
/// NEDEN [baslangicRotasi] YETMEDİ (5 Eyl 2026, CANLIDA ÖLÇÜLDÜ): go_router
/// web'de `initialLocation`ı yalnız platform başlangıç rotası `/` ise kullanır;
/// tarayıcı gerçek adresi (`/de`) verdiğinde `initialLocation` YOK SAYILIR ve
/// eşleşme doğrudan `/de` ile yapılır. Sonuç: oturumlu ziyaretçi "Bağlantı
/// geçersiz" ekranı, oturumsuz ziyaretçi `/giris?donus=/de` gördü — 29 Ağu'dan
/// beri yabancı dilli HER arama ziyaretçisi kırık sayfaya düşüyordu (SEO
/// yöneticisi `/de` ile yakaladı). `redirect` her konum için koşar; önek
/// orada düşürülünce platformun verdiği adres de, `go()` ile gelen de aynı
/// kapıdan geçer. Dil seçimi kaybolmaz: `Ceviri.yukle(adres:)` öneki
/// yönlendirmeden ÖNCE okur.
String? dilOnekiDusur(Uri adres) {
  if (Ceviri.adresDiliKodu(adres) == null) return null;
  final govde = adres.pathSegments
      .where((s) => s.isNotEmpty)
      .skip(1)
      .map(Uri.encodeComponent)
      .join('/');
  final yol = govde.isEmpty ? '/kesfet' : '/$govde';
  return yol + (adres.hasQuery ? '?${adres.query}' : '');
}

/// Yenilemeyle YENİDEN AÇILMAMASI gereken yollar (sesli/görüntülü arama).
///
/// Kural "kullanıcı neredeyse orada aç" ise de bu iki adres bir SAYFA değil,
/// canlı bir OTURUM: `/gorusme/:ad` açılınca karşı tarafa arama BAŞLATIR,
/// `/arama-gelen` ise sunucudaki teklifi bekler. Sayfayı yenilemek WebRTC
/// bağlantısını zaten koparır; adresi olduğu gibi geri yüklemek "F5'e bastım,
/// telefon yeniden çaldı" demek olurdu. Mesajlara düşülür — aramanın geldiği
/// yer orası.
bool yenilemeyleAcilmaz(String yol) =>
    yol == gelenAramaYolu || yol.startsWith('/gorusme/');

/// URL tabanlı yönlendirme: web'de reload bulunulan sayfada kalır.
///
/// [tarayiciAdresi] YALNIZ TEST İÇİNDİR: `flutter test` daima
/// `kIsWeb == false` koşar, yani gömülü bayrakla yazılan web dalı testten
/// GİZLENİR (aynı tuzak `GirisEkrani(web: ...)`de de enjeksiyonla çözülmüştü).
/// Verilirse "tarayıcı şu adreste yenilendi" demektir; verilmezse web'de
/// `Uri.base`, mobilde null.
GoRouter yonlendiriciOlustur(Oturum oturum, {Uri? tarayiciAdresi}) {
  // ===========================================================================
  // ADRES ÇUBUĞU `push` EDİLEN SAYFAYI DA GÖSTERSİN  (14 Ağu 2026)
  // ===========================================================================
  // Kullanıcı bildirimi: "webde gezerken sayfayı yenilediğimde beni hep farklı
  // sayfalara atıyor."
  //
  // KÖK NEDEN: go_router'ın bu bayrağı VARSAYILAN OLARAK FALSE. Kapalıyken
  // `push` ile açılan sayfalar adres çubuğuna hiç yazılmaz; adres en son `go`
  // edilen konumda (yani kabuk sekmesinde) donar. Bu uygulamada derin
  // gezinmenin TAMAMI `push` ile yapılıyor — içerik, kişi, bölüm, kullanıcı
  // profili, sohbet, kitaplık, özet, liste, gönderi, tam ekran arama... Yani
  // hata tek bir sayfada değil, gezilen HER derin sayfadaydı.
  //
  // CANLIDA ÖLÇÜLDÜ (Chrome, oturumlu): Keşfet'ten "House of the Dragon"
  // posterine dokunduktan sonra dizi sayfası tam ekran açıkken
  // `location.pathname` hâlâ `/kesfet` idi. F5 → Keşfet.
  //
  // go_router bu bayrağa "önerilmez" diyor, GEREKÇESİ ŞU: en üstteki rotanın
  // adresi her uygulamada derin bağlantılanabilir olmayabilir. Bu projede
  // olabiliyor ve bu artık TESTLE KİLİTLİ — `yenileme_ayni_sayfa_test.dart`
  // rota tablosundaki HER yolu soğuk açılışla deneyip aynı sayfada açıldığını
  // doğruluyor; yeni bir rota deep-link'lenemez hâlde eklenirse test kırılır.
  //
  // YAN FAYDA: kullanıcı artık adres çubuğundaki bağlantıyı kopyalayıp
  // paylaşabiliyor (eskiden hep ana sayfa adresi kopyalanıyordu).
  GoRouter.optionURLReflectsImperativeAPIs = true;

  final adres = tarayiciAdresi ?? (kIsWeb ? Uri.base : null);
  // F5 güvencesi: motor başlangıç rotasını URL stratejisi kurulmadan '/'
  // olarak yakalayabiliyor; o durumda derin bağlantı kaybolup keşfete
  // düşülüyordu. Başlangıcı doğrudan tarayıcı adresinden alıyoruz.
  final baslangic = baslangicRotasi(adres);
  return sonYonlendirici = GoRouter(
    initialLocation: baslangic,
    refreshListenable: oturum,
    redirect: (context, state) {
      // DİL ÖNEKİ İLK KAPIDA DÜŞER — giriş duvarından ve rota eşleşmesinden
      // ÖNCE (gerekçe `dilOnekiDusur` üstünde). Aksi hâlde `/de` oturumsuzda
      // `/giris?donus=/de`, oturumluda "Bağlantı geçersiz" olur.
      final dilsiz = dilOnekiDusur(state.uri);
      if (dilsiz != null) return dilsiz;
      final girisli = oturum.girisli;
      final konum = state.matchedLocation;
      final giriste = konum == '/giris';
      if (!girisli) {
        if (giriste) return null;
        // İçerik sayfaları (ve gizlilik politikası) oturumsuz açılır.
        if (herkeseAcikMi(konum)) return null;
        // Korumalı yol: nereye gitmek istediğini SAKLA, giriş sonrası oraya
        // dönsün. Yoksa Google'dan gelip giriş yapan kullanıcı keşfette kalır
        // ve tıkladığı içeriği kaybeder.
        return girisYolu(state.uri.toString());
      }
      // Yeni kayıt sonrası bir kez karşılama ekranı.
      if (Oturum.karsilamaGerekli && konum != '/karsilama') {
        return '/karsilama';
      }
      if (giriste) {
        return donusHedefi(state.uri.queryParameters['donus']) ?? '/kesfet';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/giris', builder: (_, __) => const GirisEkrani()),
      GoRoute(path: '/gizlilik', builder: (_, __) => const GizlilikEkrani()),
      GoRoute(path: '/karsilama', builder: (_, __) => const KarsilamaEkrani()),
      // Alt sekmeler — durum korunur, URL sekmeyi yansıtır
      StatefulShellRoute.indexedStack(
        builder: (_, __, navigationShell) =>
            KabukEkrani(shell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/kesfet',
                builder: (_, __) => const KesfetEkrani(),
              ),
              // Raf başlığındaki "Tümünü gör".
              //
              // 14 Ağu 2026 — kullanıcının bildirdiği hata: bu ekran
              // `Navigator.push(MaterialPageRoute(...))` ile, yani
              // yönlendiricinin DIŞINDAN açılıyordu. Canlıda ölçüldü: sayfa
              // tam ekran açılırken `location.pathname` `/kesfet`te kalıyor,
              // F5 kullanıcıyı Keşfet'e geri atıyordu.
              //
              // KEŞFET ŞUBESİNİN İÇİNDE (kabuk dışı kök rota DEĞİL): sayfa
              // bugün de alt gezinme çubuğuyla birlikte açılıyor; kök rotaya
              // taşımak çubuğu kaldırır ve görünümü değiştirirdi. Şube içinde
              // durunca yenilemede Keşfet sekmesi de doğru seçilir —
              // `/kitaplik/:durum` ile aynı kalıp.
              GoRoute(
                path: '/raf/:slug',
                builder: (_, s) {
                  final raf = rafBul(s.pathParameters['slug']);
                  return raf == null
                      ? const _GecersizBaglanti()
                      : KatalogListeEkrani(
                          baslik: raf.$1,
                          yol: raf.$2,
                          tur: raf.$3,
                        );
                },
              ),
              // "Sana Özel" rafının "Tümünü gör" sayfası (19 Ağu 2026).
              //
              // NEDEN AYRI ROTA, `/raf/:slug` DEĞİL: `/raf/:slug` slug'ı
              // `anaSayfaRaflari` tablosunda arar (`rafBul`) ve oradan sabit
              // bir TMDB YOLU alır. "Sana Özel"in böyle bir yolu yok — içeriği
              // kişiye özel `/onerilen` ucundan geliyor. Tabloya sahte bir
              // kayıt eklemek Keşfet'in raf çekme döngüsünü bozardı (gerekçe
              // uzun uzun `kesfet.dart` → [sanaOzelYolu] başlığında).
              //
              // KÖK YOL, `/raf/` ALTINDA DEĞİL: rota OTURUM ZORUNLU olmalı ve
              // robots.txt ile kapatılmalı; bu dosyadaki `acikYolOnEkleri`
              // listesinde `/raf/` ön eki HERKESE AÇIK duruyor. Alt yol
              // olsaydı ya açık kalırdı ya da `/raf/` ön ekinin tamamı
              // kapanırdı (herkese açık katalog sayfaları dâhil).
              //
              // KEŞFET ŞUBESİNİN İÇİNDE: `/raf/:slug` ile aynı gerekçe — alt
              // gezinme çubuğu yerinde kalsın, F5'te Keşfet sekmesi seçili
              // gelsin. Yol dizesi SABİTten değil ELLE yazılı: SEO testlerinin
              // rota ayrıştırıcısı (`backend/test/yardimci/seo_kaynak.js`)
              // yalnız bu dosyadaki ve `arama_cubugu.dart`taki `const String`
              // sabitlerini çözüyor; `kesfet.dart`taki sabiti çözemez ve
              // "path sabiti çözülemedi" diye KIRILIRDI.
              GoRoute(
                path: '/sana-ozel',
                builder: (_, __) => const KatalogListeEkrani(
                  baslik: sanaOzelBaslik,
                  yol: '/onerilen',
                  // Sayfa parametresi ve liste alanı TMDB'ninkinden farklı.
                  sayfaParam: 'sayfa',
                  sonucAnahtari: 'oneriler',
                  // tur VERİLMİYOR: öneri listesi karışık (dizi + film), tür
                  // her yapımın kendi `media_type` alanından okunur.
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/takvim',
                builder: (_, __) => const TakvimEkrani(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/akis', builder: (_, __) => const AkisEkrani()),
              // Kullanıcı sayfaları kabuk içinde: alt menü kaybolmaz
              GoRoute(
                path: '/kullanici/:ad',
                builder: (_, s) => KullaniciProfilEkrani(
                  kullaniciAdi: s.pathParameters['ad']!,
                ),
                routes: [
                  GoRoute(
                    path: 'takipciler',
                    builder: (_, s) => KullaniciListesiEkrani(
                      kullaniciAdi: s.pathParameters['ad']!,
                      takipciler: true,
                    ),
                  ),
                  GoRoute(
                    path: 'takip',
                    builder: (_, s) => KullaniciListesiEkrani(
                      kullaniciAdi: s.pathParameters['ad']!,
                      takipciler: false,
                    ),
                  ),
                  // Kitaplık listesi paylaşım sayfası (salt okunur) —
                  // kitaplık ekranındaki paylaş düğmesi buraya bağlantı verir.
                  GoRoute(
                    path: 'kitaplik/:durum',
                    builder: (_, s) => KullaniciKitaplikEkrani(
                      kullaniciAdi: s.pathParameters['ad']!,
                      durum: s.pathParameters['durum']!,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/kisi-ara',
                builder: (_, __) => const KullaniciAramaEkrani(),
              ),
              GoRoute(
                path: '/bildirimler',
                builder: (_, __) => const BildirimlerEkrani(),
              ),
              // Sürüm tanıtım sayfası (2 Eyl 2026): "dizi.jpg X yayında"
              // bildirimi buraya götürür. İçerik uygulamada gömülü
              // (yenilikler.dart); bilinmeyen sürümde ekran "güncelle" der,
              // rota ayrıca doğrulamaz. Akış şubesinin İÇİNDE: alt gezinme
              // çubuğu yerinde kalır, F5'te sekme doğru seçilir
              // (/bildirimler ile aynı kalıp).
              GoRoute(
                path: '/yenilikler/:surum',
                builder: (_, s) =>
                    YeniliklerEkrani(surum: s.pathParameters['surum'] ?? ''),
              ),
              GoRoute(
                path: '/sohbetler',
                builder: (_, __) => const SohbetlerEkrani(),
              ),
              GoRoute(
                path: '/mesaj-istekleri',
                builder: (_, __) => const MesajIstekleriEkrani(),
              ),
              // İZLEME ODASI (3 Eyl 2026). KABUĞUN İÇİNDE: oda Mesajlar
              // sekmesinden açılıyor ve kullanıcı odadan çıkınca alt menüyle
              // birlikte sohbet listesine dönmeli (`ux-kontrol` md. 4:
              // "kullanıcı sayfaları kabuk İÇİNDE kalmalı").
              GoRoute(
                path: '/oda/:id',
                builder: (_, s) => OdaEkrani(
                  odaId: int.tryParse(s.pathParameters['id'] ?? '') ?? 0,
                ),
              ),
              GoRoute(
                path: '/sohbet/:ad',
                builder: (_, s) =>
                    SohbetEkrani(kullaniciAdi: s.pathParameters['ad']!),
                routes: [
                  // WhatsApp tarzı sohbet detayı: tema / arama / sessize al /
                  // medya (31 Ağu 2026) — başlıktaki ada dokununca açılır.
                  GoRoute(
                    path: 'detay',
                    builder: (_, s) => SohbetDetayEkrani(
                      kullaniciAdi: s.pathParameters['ad']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              // Reels tarzı Keşfet (eski Arama sekmesi; arama artık Akış'ta)
              GoRoute(
                path: '/arama',
                builder: (_, __) => const KesfetAkisEkrani(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profil',
                builder: (_, __) => const ProfilEkrani(),
              ),
              GoRoute(
                path: '/kitaplik/:durum',
                builder: (_, s) =>
                    KitaplikListesiEkrani(durum: s.pathParameters['durum']!),
              ),
              // Favori oyuncular: profil sekmesinin İÇİNDE (alt gezinme
              // çubuğu kaybolmasın, geri tuşu profile dönsün) —
              // `/kitaplik/:durum` ile aynı kalıp.
              GoRoute(
                path: '/favori-oyuncular',
                builder: (_, _) => const FavoriOyuncularEkrani(),
              ),
            ],
          ),
        ],
      ),
      // Detay sayfaları (sekmelerin üstünde).
      // Sayısal parametreler güvenli parse edilir: bozuk/eski URL'de (web'de
      // elle yazılmış /icerik/tv/abc gibi) hata ekranı yerine "bulunamadı".
      GoRoute(
        path: '/icerik/:tur/:id',
        builder: (_, s) {
          final id = int.tryParse(s.pathParameters['id'] ?? '');
          final tur = s.pathParameters['tur'];
          if (id == null || (tur != 'tv' && tur != 'movie')) {
            return _masa(const _GecersizBaglanti());
          }
          return _masa(DetayEkrani(tmdbId: id, tur: tur!));
        },
      ),
      GoRoute(
        path: '/kisi/:id',
        builder: (_, s) {
          final id = int.tryParse(s.pathParameters['id'] ?? '');
          return id == null
              ? _masa(const _GecersizBaglanti())
              : _masa(KisiEkrani(kisiId: id));
        },
      ),
      // Yapım firması (md. 49) — detaydaki firma şeridinden açılır. `/kisi/:id`
      // ile aynı hizada: kabuğun DIŞINDA ve oturumsuz ziyaretçiye AÇIK
      // (bkz. [acikYolOnEkleri]) — içerik sayfasından buraya tıklayan
      // ziyaretçinin giriş duvarına çarpması kopukluk olurdu.
      GoRoute(
        path: '/sirket/:id',
        builder: (_, s) {
          final id = int.tryParse(s.pathParameters['id'] ?? '');
          return id == null
              ? _masa(const _GecersizBaglanti())
              : _masa(
                  SirketEkrani(
                    sirketId: id,
                    sirketAdi: s.uri.queryParameters['ad'],
                    baslangicTuru: s.uri.queryParameters['tur'],
                  ),
                );
        },
      ),
      // Paylaşılan liste — SSR sayfası (`/og/listeler/:id`) bu adrese
      // götürüyor. Kabuğun DIŞINDA: oturumsuz ziyaretçinin kabuğu yoktur.
      GoRoute(
        path: '/listeler/:id',
        builder: (_, s) {
          final id = int.tryParse(s.pathParameters['id'] ?? '');
          return id == null
              ? _masa(const _GecersizBaglanti())
              : _masa(ListeEkrani(listeId: id));
        },
      ),
      // Paylaşılan gönderi (reel/yorum) — tam ekran tek gönderi
      GoRoute(
        path: '/gonderi/:id',
        builder: (_, s) {
          final id = int.tryParse(s.pathParameters['id'] ?? '');
          return id == null
              ? _masa(const _GecersizBaglanti())
              : _masa(
                  GonderiEkrani(
                    yorumId: id,
                    // Bildirimden gelen yanıt yolu — bkz. [gonderiYolu].
                    yanitBildirimi: s.uri.queryParameters['yanit'] == '1',
                  ),
                );
        },
      ),
      // Kendi gönderinin istatistikleri (md. 23) — TAM EKRAN hâli.
      //
      // GÖNDERİ KARTINDAKİ "İstatistikleri gör" ARTIK BURAYA GELMİYOR: o giriş
      // `gonderiIstatistikAc` ile MODAL açıyor (liste arkada kalsın, bağlam
      // korunsun). Bu rota YİNE DE DURUYOR ve durmalı — paylaşılmış bağlantı,
      // tarayıcı geçmişi ve oturumsuz erişim testi (`seo_gizlilik.test.js`)
      // bu adresi kullanıyor. İki kabuk da AYNI gövdeyi
      // (`GonderiIstatistikGovdesi`) çiziyor, yani içerik ayrışamaz.
      //
      // Kabuğun DIŞINDA tam ekran, geri tuşu gönderiye döner. Uç yalnız
      // SAHİBİNE cevap verir; başkası derin bağlantıyla girerse ekran
      // "gönderi bulunamadı" der (404 — 403 varlığı ele verirdi).
      //
      // NEDEN `/gonderi/:id/istatistik` DEĞİL: robots.txt ön ek kuralları
      // JOKER İÇERMİYOR (seo_gizlilik.test.js bunu kilitliyor) ve id ORTADA
      // olan bir yol ön ekle kapatılamaz — `Disallow: /gonderi/` yazsaydık
      // SSR ile indekslenen `/gonderi/123` sayfası da kapanırdı. Kök yol,
      // `/favori-oyuncular` ve `/yapimlar/` ile aynı gerekçe.
      GoRoute(
        path: '/gonderi-istatistik/:id',
        builder: (_, s) {
          final id = int.tryParse(s.pathParameters['id'] ?? '');
          return id == null
              ? _masa(const _GecersizBaglanti())
              : _masa(GonderiIstatistikEkrani(gonderiId: id));
        },
      ),
      GoRoute(
        path: '/dizi/:id/sezon/:sezon/bolum/:bolum',
        builder: (_, s) {
          final id = int.tryParse(s.pathParameters['id'] ?? '');
          final sezon = int.tryParse(s.pathParameters['sezon'] ?? '');
          final bolum = int.tryParse(s.pathParameters['bolum'] ?? '');
          if (id == null || sezon == null || bolum == null) {
            return _masa(const _GecersizBaglanti());
          }
          return _masa(
            BolumEkrani(
              tmdbId: id,
              sezonNo: sezon,
              bolumNo: bolum,
              izlendi: (s.extra as bool?) ?? false,
            ),
          );
        },
      ),
      // --- Sesli/görüntülü arama (KABUĞUN DIŞINDA: tam ekran, alt menü yok) ---
      // Giden arama. `tur` sorgu parametresi ('ses' | 'goruntu'), `extra`
      // karşı tarafın avatar yolu (varsa; yoksa harf baş harfi çizilir).
      GoRoute(
        path: '/gorusme/:ad',
        builder: (_, s) => GidenAramaSayfasi(
          kullaniciAdi: s.pathParameters['ad']!,
          tur: s.uri.queryParameters['tur'] == 'goruntu' ? 'goruntu' : 'ses',
          avatar: s.extra as String?,
        ),
      ),
      // Gelen arama. Parametre YOK: teklif SDP'si bildirime sığmaz (FCM veri
      // sınırı 4 KB), ekran açılınca `GET /arama/gelen` ile çekilir. Böylece
      // bildirimden açılan yol ile ön plan yoklamasının açtığı yol AYNI.
      GoRoute(
        path: gelenAramaYolu,
        builder: (_, _) => const GelenAramaSayfasi(),
      ),
      GoRoute(
        path: '/ayarlar',
        builder: (_, __) => _masa(const AyarlarEkrani()),
      ),
      // Ayarlar > Video altyazıları > Altyazı görünümü. Gizlenen yorumlar ile
      // AYNI kural: kabuğun DIŞINDA tam ekran, geri tuşu ayarlara döner.
      // Adrese yazılan gezinme (`Navigator.push` DEĞİL) ki F5 kullanıcıyı
      // ayarlara geri atmasın.
      GoRoute(
        path: '/altyazi-bicem',
        builder: (_, _) => _masa(const AltyaziBicemEkrani()),
      ),
      // Ayarlar > Gizlilik > Gizlenen yorumlar. Kabuğun DIŞINDA: ayarların
      // kendisi gibi tam ekran açılır, geri tuşu ayarlara döner.
      GoRoute(
        path: '/gizlenen-yorumlar',
        builder: (_, __) => _masa(const GizlenenYorumlarEkrani()),
      ),
      // Ayarlar > Gizlilik > Engellenen kullanıcılar. Gizlenen yorumlarla
      // AYNI kural: kabuğun DIŞINDA tam ekran, geri tuşu ayarlara döner.
      GoRoute(
        path: '/engellenenler',
        builder: (_, _) => _masa(const EngellenenKullanicilarEkrani()),
      ),
      // Ayarlar > İstatistiklerim (md. 24). Gizlenen yorumlar/engellenenler ile
      // AYNI kural: kabuğun DIŞINDA tam ekran, geri tuşu ayarlara döner.
      GoRoute(
        path: '/istatistiklerim',
        builder: (_, _) => _masa(const IstatistiklerimEkrani()),
      ),
      // Ayarlar > İzleme İstatistiklerim (19 Ağu 2026). AYRI yol, çünkü
      // /istatistiklerim GÖNDERİ erişimini ölçüyor; bu ekran kullanıcının
      // KENDİ izlemesini. İkisini tek sayfada birleştirmek "kaç kişi gördü"
      // ile "kaç bölüm izledim"i aynı manşete koymak olurdu.
      GoRoute(
        path: '/izleme-istatistik',
        builder: (_, _) => _masa(const IzlemeIstatistikEkrani()),
      ),
      // Ayarlar > Hareketlerim (md. 20). Gizlenen yorumlar/engellenenler ile
      // AYNI kural: kabuğun DIŞINDA tam ekran, geri tuşu ayarlara döner.
      // `?tur=` süzgeci derin bağlantıyla açılabilir (/hareketlerim?tur=begeni).
      GoRoute(
        path: '/hareketlerim',
        builder: (_, s) =>
            _masa(HareketlerimEkrani(tur: s.uri.queryParameters['tur'])),
      ),
      // `?tur=` ve `?genre=`: içerik sayfasındaki tür etiketinden gelinir
      // (19 Ağu 2026). Adreste durduğu için F5'te seçim korunur ve bağlantı
      // paylaşılabilir.
      GoRoute(
        path: '/gozat',
        builder: (_, s) => _masa(
          GozatEkrani(
            baslangicTuru: s.uri.queryParameters['tur'],
            baslangicGenre: int.tryParse(s.uri.queryParameters['genre'] ?? ''),
          ),
        ),
      ),
      // Aramanın "Daha fazlasını gör" tam listesi. Sorgu ve kategori adreste
      // durur: F5 ve geri tuşu doğal çalışır, arama sayfası yığında kaldığı
      // için geri dönünce sorgu/sonuçlar korunur.
      GoRoute(
        path: '/arama-liste',
        builder: (_, s) => _masa(
          AramaTamListeEkrani(
            sorgu: s.uri.queryParameters['q'] ?? '',
            tur: s.uri.queryParameters['tur'] ?? 'icerik',
          ),
        ),
      ),
      // Mobilde üst bardaki kapalı kutunun açtığı TAM EKRAN arama.
      // KABUĞUN DIŞINDA: alt gezinme çubuğu görünmez, geri tuşu (Android ve
      // tarayıcı) aramayı kapatıp geldiği sekmeye döner.
      GoRoute(
        path: tamAramaYolu,
        pageBuilder: (_, s) => CustomTransitionPage(
          key: s.pageKey,
          // Açılış 220 ms, kapanış 160 ms: çıkış girişten hızlı olur, "kutu
          // büyüyüp ekranı kaplıyor" hissi verir ama abartılı değildir.
          transitionDuration: const Duration(milliseconds: 220),
          reverseTransitionDuration: const Duration(milliseconds: 160),
          transitionsBuilder: (_, animasyon, __, cocuk) => FadeTransition(
            opacity: animasyon,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(
                CurvedAnimation(parent: animasyon, curve: Curves.easeOutCubic),
              ),
              child: cocuk,
            ),
          ),
          child: const MasaustuKaliciCubuk(cocuk: TamEkranAramaSayfasi()),
        ),
      ),
      GoRoute(
        path: '/ozet/:yil',
        builder: (_, s) {
          final yil = int.tryParse(s.pathParameters['yil'] ?? '');
          return yil == null
              ? _masa(const _GecersizBaglanti())
              : _masa(OzetEkrani(yil: yil));
        },
      ),
      GoRoute(
        path: '/izlediklerim',
        builder: (_, s) =>
            _masa(IzlenenlerEkrani(tur: s.uri.queryParameters['tur'])),
      ),
      // Oyuncunun yapımları + izlendi/izlenmedi listesi.
      //
      // NEDEN `/kisi/:id/yapimlar` DEĞİL: liste KİŞİYE ÖZEL (kimin neyi
      // izlediği) ve oturum ister; robots.txt ile kapatılması gerekiyor.
      // `Disallow` kuralları bu projede joker İÇERMEZ (bkz.
      // backend/test/seo_gizlilik.test.js `kapali`), yani `/kisi/*/yapimlar`
      // yazılamaz; `/kisi/` ön ekini kapatmak ise SSR ile indekslenen oyuncu
      // sayfalarını kapatırdı. Kök yol olunca `Disallow: /yapimlar/` yetiyor
      // ve `/izlediklerim` ile aynı kalıba oturuyor.
      // Yan fayda: `acikYolOnEkleri` dışında kaldığı için oturumsuz ziyaretçi
      // `/giris?donus=/yapimlar/500`e gider, hedefini kaybetmez.
      // `extra`: oyuncunun adı (başlık için); yoksa "Yapımları" yazar.
      GoRoute(
        path: '/yapimlar/:id',
        builder: (_, s) {
          final id = int.tryParse(s.pathParameters['id'] ?? '');
          return id == null
              ? _masa(const _GecersizBaglanti())
              : _masa(
                  KisiYapimlariEkrani(kisiId: id, kisiAdi: s.extra as String?),
                );
        },
      ),
    ],
    // Eşleşmeyen rota (bozuk/eski bağlantı): hata ekranı yerine nazik sayfa
    errorBuilder: (_, __) => _masa(const _GecersizBaglanti()),
  );
}

/// Bozuk/eski bağlantıda gösterilir (hata ekranı yerine nazik yönlendirme).
class _GecersizBaglanti extends StatelessWidget {
  const _GecersizBaglanti();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_off, size: 48, color: DiziRenkler.metin38),
            const SizedBox(height: 12),
            Text(
              'Bağlantı geçersiz veya sayfa bulunamadı'.c,
              textAlign: TextAlign.center,
              style: TextStyle(color: DiziRenkler.metin54),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/kesfet'),
              child: Text('Keşfet\'e dön'.c),
            ),
          ],
        ),
      ),
    );
  }
}
