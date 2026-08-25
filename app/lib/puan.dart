/// Puan ölçeği — TEK KAYNAK.
///
/// TARİHÇE / NEDEN: veritabanındaki `puanlar.puan` sütunu 1-10 tutuyordu.
/// Uygulama 5 yıldızlı arayüze geçtiğinde şema DEĞİŞMEDİ; her ekran ölçeği
/// kendi içinde `/ 2` ve `* 2` yaparak çevirdi. Aynı hesap altı ayrı dosyada
/// kopyalanınca sunucunun SSR/JSON-LD çıktısı "10/10" derken uygulama aynı
/// puanı "5.0" gösteriyordu (7 Ağu 2026 SEO denetimi). Doğru olan uygulama
/// tarafıdır; çeviri ARTIK YALNIZ BURADA yapılır.
///
/// ---------------------------------------------------------------------------
/// SEÇİLEBİLİR ÖLÇEK (kullanıcı isteği, 26 Ağu 2026)
/// ---------------------------------------------------------------------------
/// Kullanıcı Ayarlar'dan 5 / 10 / 50 / 100 (ya da arada herhangi bir değer)
/// yıldızlık ölçek seçebiliyor. İKİ ÖLÇEK VAR, karıştırma:
///
///   * KANONİK (db) 1-100 — `puanlar.puan`. Sunucu YALNIZ bunu bilir.
///     migrasyon-2026-08-26b.sql ile 1-10'dan taşındı (×10).
///   * GÖRÜNÜM (N) 5-100 — `PuanOlcegi.deger`. Yalnız ekranda yaşar.
///
/// ÖLÇEK DEĞİŞTİRMEK VERİ GÖÇÜ DEĞİLDİR: 5'lik ölçekte verilen 4 yıldız 80
/// olarak durur; 100'lük ölçeğe geçen kullanıcı 80 görür, geri dönünce yine 4.
/// Bu yüzden aşağıdaki çeviriler KAYIPLIDIR ve olması gereken budur — küçük
/// ölçeğe inince yuvarlanır, çıkınca yuvarlanmış hâlin karşılığı gösterilir.
///
/// DİKKAT — TMDB ile karıştırma: TMDB'nin `vote_average` alanı 0-10'dur ve
/// KENDİ ölçeğinde gösterilir ("8.4 TMDB" / poster rozeti). Bu dosyadaki
/// dönüşümler yalnız dizi.jpg'nin KENDİ puanları (`puanlar` tablosu) içindir.
library;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// Veritabanı (kanonik) ölçeğinin üst sınırı — `puanlar.puan`.
const int dbPuanAzami = 100;

/// Kullanıcının seçebileceği ölçek sınırları (sunucudaki CHECK ile aynı).
const int puanOlcekAlt = 5;
const int puanOlcekUst = 100;

/// Ayarlar'daki hazır seçenekler. Aradaki her değer de geçerli (kaydırıcı).
const List<int> puanOlcekSecenekleri = [5, 10, 50, 100];

/// Bu ölçekte yıldızlar TEK TEK dokunulabilir mi?
///
/// EŞİK 10: 360 dp'lik dar telefonda 10 yıldız × 32 dp = 320 dp ile son
/// hedefe kadar sığar; 11'incisi ya taşar ya da dokunma hedefini 44 dp'nin
/// (erişilebilirlik asgarisi) altına iter. Üstündeki ölçekler bu yüzden
/// SATIR YERİNE ROZET çizip dokununca [puanSecSheet] açar — kullanıcının
/// istediği "10 üzeri tıklayınca açılan div" kuralı tek yerde burada tanımlı.
bool yildizSatiriOlur(int olcek) => olcek <= 10;

/// Ölçeğe göre yıldız ikon boyutu (satır kipinde).
///
/// 5 yıldızda bugünkü 30 dp korunur; 10 yıldızda 22 dp'ye iner ki satır dar
/// ekranda taşmasın. Aradaki değerler doğrusal.
double yildizIkonBoyu(int olcek, {double taban = 30}) {
  if (olcek <= 5) return taban;
  final oran = (olcek - 5) / 5; // 5→0, 10→1
  return (taban - (taban - 22) * oran.clamp(0, 1)).toDouble();
}

/// Kullanıcının seçtiği görünüm ölçeği (5-100).
///
/// SUNUCU DOĞRUNUN KAYNAĞIDIR (`kullanicilar.puan_olcegi`); buradaki
/// SharedPreferences kaydı yalnız AÇILIŞ ÖNBELLEĞİDİR — uygulama ilk kareyi
/// çizerken ağı beklemesin, 5 yıldız gösterip saniye sonra 100'e atlamasın.
class PuanOlcegi {
  PuanOlcegi._();

  static const _anahtar = 'puan_olcegi';

  /// Geçerli ölçek. Dinleyen her ekran ölçek değişince kendini yeniden çizer.
  static final ValueNotifier<int> deger = ValueNotifier(puanOlcekAlt);

  static int _kis(Object? ham) {
    final n = puanSayisi(ham)?.round() ?? puanOlcekAlt;
    return n.clamp(puanOlcekAlt, puanOlcekUst);
  }

  /// Önbellekten oku (main.dart açılışında, ağ beklemeden).
  static Future<void> yukle() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getInt(_anahtar);
    if (v != null) deger.value = _kis(v);
  }

  /// Giriş yanıtındaki `kullanici.puan_olcegi` ile eşitle (ağ turu yok).
  static Future<void> oturumdan(Object? ham) async {
    if (ham == null) return;
    await _yaz(_kis(ham));
  }

  /// Sunucudan tazele. Hata YUTULUR: ölçek okunamadı diye açılışı bloklamak,
  /// kullanıcıyı yanlış ölçekle bırakmaktan daha kötü bir sonuç doğurmaz —
  /// elde son bilinen değer zaten var.
  static Future<void> tazele() async {
    try {
      final d = await Api.get('/puan-olcegi');
      if (d is Map && d['olcek'] != null) await _yaz(_kis(d['olcek']));
    } catch (_) {
      // sessiz: önbellekteki değerle devam
    }
  }

  /// Kullanıcı Ayarlar'dan seçti: önce yerel (anında görünsün), sonra sunucu.
  /// Sunucu reddederse ESKİ DEĞERE DÖNÜLÜR — sessiz ayrışma olmasın.
  static Future<void> sec(int olcek) async {
    final eski = deger.value;
    final yeni = _kis(olcek);
    await _yaz(yeni);
    try {
      await Api.post('/puan-olcegi', {'olcek': yeni});
    } catch (e) {
      await _yaz(eski);
      rethrow;
    }
  }

  static Future<void> _yaz(int olcek) async {
    deger.value = olcek;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_anahtar, olcek);
  }
}

/// Herhangi bir kaynaktan gelen puanı sayıya çevirir.
///
/// Sunucu `avg(puan)` sonucunu kimi uçta sayı, kimi uçta metin (`numeric`)
/// olarak döndürüyor; çağıran taraflar bu yüzden `num.tryParse('$x')`
/// kopyalıyordu.
num? puanSayisi(Object? ham) {
  if (ham == null) return null;
  if (ham is num) return ham;
  return num.tryParse('$ham');
}

/// Geçerli görünüm ölçeği (kısayol — çağrı yerleri `PuanOlcegi.deger.value`
/// yazmasın diye).
int get yildizAzami => PuanOlcegi.deger.value;

/// DB puanı (1-100) → görünüm yıldızı (0..N), tam sayı.
///
/// `null`/bozuk değer 0 döner: puanlanmamış demektir.
/// [olcek] verilmezse kullanıcının geçerli ölçeği kullanılır; testler ve
/// ölçek önizlemesi açıkça geçirir.
int yildiza(Object? dbPuan, {int? olcek}) {
  final n = olcek ?? yildizAzami;
  final p = puanSayisi(dbPuan) ?? 0;
  if (p <= 0) return 0;
  // round: 5'lik ölçekte 80 → 4, 90 → 4.5 → 5 (yukarı). Kanonik değerler
  // zaten N'in katları olduğu için kendi ölçeğinde kayıpsız geri döner.
  //
  // TABAN 1, 0 DEĞİL: 100'lük ölçekte 3 puan veren birinin puanı 5'lik
  // ölçekte 0,15 → 0 olurdu; 0 bu dosyada "PUAN YOK" anlamına geldiği için
  // o kişinin oyu dağılım grafiğinden ve rozetlerden SESSİZCE DÜŞERDİ
  // (26 Ağu 2026 testinde yakalandı). Puan varsa en az bir yıldızdır —
  // `dbPuani` de yazma yönünde aynı tabanı uyguluyor.
  return (p * n / dbPuanAzami).round().clamp(1, n);
}

/// DB ortalaması (1-100) → görünüm ölçeğinde ortalama, ondalıklı.
double yildizOrtalamasi(Object? dbOrtalama, {int? olcek}) {
  final n = olcek ?? yildizAzami;
  final p = puanSayisi(dbOrtalama) ?? 0;
  return (p * n / dbPuanAzami).clamp(0, n).toDouble();
}

/// Ekranda gösterilecek ortalama metni.
///
/// ONDALIK ÖLÇEĞE GÖRE: 5'lik ölçekte "4.2" bilgi taşır, 100'lük ölçekte
/// "83.4" sahte kesinliktir (kaynak değer zaten tam sayı puanların ortalaması)
/// ve dar rozetlerde satır taşırır. 10'un üstünde ondalık atılır.
String yildizOrtalamaMetni(Object? dbOrtalama, {int? olcek}) {
  final n = olcek ?? yildizAzami;
  final v = yildizOrtalamasi(dbOrtalama, olcek: n);
  return n > 10 ? v.round().toString() : v.toStringAsFixed(1);
}

/// Görünüm yıldızı (0..N) → DB puanı (0-100). Sunucuya YAZARKEN kullanılır.
int dbPuani(int yildiz, {int? olcek}) {
  final n = olcek ?? yildizAzami;
  final y = yildiz.clamp(0, n);
  if (y <= 0) return 0;
  // round + en az 1: N=100'de zaten birebir; N=5'te 1→20, 5→100.
  return (y * dbPuanAzami / n).round().clamp(1, dbPuanAzami);
}

/// Puan dağılımı grafiğinde kaç çubuk çizilir.
///
/// 100 çubuk okunmaz bir tarak olurdu; ölçek 10'u aşınca dağılım 10 kovaya
/// GRUPLANIR ("91-100" gibi aralıklar). 10 ve altında her yıldız kendi kovası.
int dagilimKovaSayisi(int olcek) => olcek <= 10 ? olcek : 10;

/// Sunucunun ham puan dağılımını (`[{puan: 1-100, adet: n}, ...]`) görünüm
/// kovalarına toplar. Anahtarlar HER ZAMAN 1..[dagilimKovaSayisi], boş kovalar
/// 0 ile doludur.
///
/// Kovalama [yildiza] ile yapılır — yani ekranda görünen yıldızla kovanın
/// yıldızı aynı işlevden çıkar. Sunucu bilerek ham ölçek gönderir: yuvarlamayı
/// orada da yapsaydık çeviri ikinci bir yerde yaşar ve iki taraf ayrışabilirdi
/// (bu dosyanın başlığındaki hatanın aynısı).
Map<int, int> yildizDagilimi(Object? ham, {int? olcek}) {
  final n = olcek ?? yildizAzami;
  final kova = dagilimKovaSayisi(n);
  final kovalar = <int, int>{for (var y = 1; y <= kova; y++) y: 0};
  if (ham is! List) return kovalar;
  for (final satir in ham) {
    if (satir is! Map) continue;
    // Kovaya çevirirken GÖRÜNÜM ölçeği değil KOVA sayısı kullanılır: 100'lük
    // ölçekte 100 ayrı kova değil, 10 aralık istiyoruz.
    final yildiz = yildiza(satir['puan'], olcek: kova);
    // 0 = puansız/bozuk satır; kovası yok, sayılmaz.
    if (yildiz < 1) continue;
    final adet = (puanSayisi(satir['adet']) ?? 0).toInt();
    if (adet > 0) kovalar[yildiz] = kovalar[yildiz]! + adet;
  }
  return kovalar;
}

/// Dağılım çubuğunun etiketi: 10 ve altında "4", üstünde "31-40" aralığı.
String dagilimKovaEtiketi(int kova, int olcek) {
  if (olcek <= 10) return '$kova';
  final adim = olcek / dagilimKovaSayisi(olcek);
  final ust = (kova * adim).round();
  final alt = ((kova - 1) * adim).round() + 1;
  return '$alt-$ust';
}

/// Ölçek değişince kendini yeniden çizen State'ler için karışım.
///
/// NEDEN GEREKLİ: Ayarlar'dan ölçek değiştirildiğinde geri dönülen sayfa
/// Navigator yığınında CANLI durur — `dispose` edilmediği için yeniden
/// build edilmez ve eski ölçekte ("4.2") kalır. Kullanıcı bunu bir hata
/// olarak görür. Puan gösteren her ekran bu karışımı kullanır; maliyeti
/// ölçek değiştiğinde bir `setState`, o da kullanıcı ömründe birkaç kez.
///
/// Doğrudan `ValueListenableBuilder` yerine karışım: ilgili sayılar bu
/// ekranlarda derin iç içe `Text`lerin içinde dağınık; her birini ayrı ayrı
/// sarmak yerine sayfayı bir kez tazelemek hem kısa hem kaçak bırakmıyor.
mixin OlcekDinler<T extends StatefulWidget> on State<T> {
  void _olcekDegisti() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    PuanOlcegi.deger.addListener(_olcekDegisti);
  }

  @override
  void dispose() {
    PuanOlcegi.deger.removeListener(_olcekDegisti);
    super.dispose();
  }
}
