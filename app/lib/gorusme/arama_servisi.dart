import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api.dart';
import 'gorusme_api.dart';

/// Uygulama ömrü boyunca yaşayan arama durumu: özellik bayrakları, ICE
/// ayarı ve ön plandaki gelen arama yoklaması.
///
/// ### WEB KARARI: arama web'de TAMAMEN KAPALI
///
/// Gerekçe (tercih değil, ölçülebilir bir zarar):
///
/// 1. **Web'de push YOK.** `push.dart` `kIsWeb`te hemen `return` ediyor —
///    yani web kullanıcısına gelen aramanın tek yolu 4 sn'lik ön plan
///    yoklamasıdır. Sekme kapalıysa, arka plandaysa ya da uygulama açık
///    değilse telefon HİÇ çalmaz.
/// 2. Arayan bunu **bilemez**. Web kullanıcısına yapılan aramaların büyük
///    kısmı `cevapsiz` biter ve sözleşme §9.1'deki çift bazlı sessizleştirme
///    (15 dk içinde 3 cevapsız → o kişiye 1 saat arama yasağı) **arayanı**
///    cezalandırır. Yani bizim web sınırlamamız, kullanıcının hiç ilgisi
///    olmayan bir davranışı yüzünden onu susturur.
/// 3. Web kullanıcısı **ulaşılmaz kalmıyor**: sunucu FCM'i onun telefonuna da
///    gönderiyor. Arama telefonda çalar. Web'de gizlemek erişimi kapatmıyor,
///    yalnız yanlış cihazda cevaplanmayı önlüyor.
/// 4. "Yalnız giden arama" seçeneği elendi: gelen yoklaması açık kalırdı (2.
///    madde aynen geçerli), kapatılsaydı da "arayabiliyorum ama beni kimse
///    arayamıyor" tutarsız bir yarım özellik olurdu.
///
/// Karar `flutter_webrtc`nin web desteğiyle ilgili DEĞİL — o çalışıyor ve
/// `flutter build web` bu paketle geçiyor. Sınır bildirim katmanında.
///
/// [webMi] bilerek `kIsWeb`in kendisi değil, ondan BAŞLATILAN bir alandır:
/// `flutter test` daima VM'de koşar (`kIsWeb == false`), yani web dalı
/// koda gömülü olsaydı hiçbir testte çalışmazdı. Bugün tam bu yüzden bir
/// hata canlıya çıktı (GIF animasyonu) — `test/arama_web_test.dart` bu alanı
/// çevirerek her iki dalı da sınıyor.
class AramaServisi {
  AramaServisi._();

  @visibleForTesting
  static bool webMi = kIsWeb;

  /// Yalnız bellekte (sözleşme §3.3: `SharedPreferences`'a YAZILMAZ —
  /// TURN kimlik bilgisi cihaz yedeğine sızmasın).
  static BuzAyari? _buz;

  /// Bayrak/ayarı değişince arama düğmelerinin yeniden çizilmesi için.
  static final ValueNotifier<int> surum = ValueNotifier(0);

  /// Şu an süren aramanın kimliği (null = arama yok). `ZATEN_ARAMADA`
  /// hatasında kullanıcıyı mevcut arama ekranına döndürmek için tutulur.
  static String? aktifAramaId;

  /// Arama özelliği bu cihazda kullanılabilir mi (platform + sunucu bayrağı +
  /// hesap türü).
  ///
  /// Bu alan tek bir soruya cevap verir: **gerçekten arayabilir/aranabilir
  /// miyim?** Düğmenin ÇİZİLİP çizilmeyeceği ayrı bir sorudur ([yakindaModu]).
  ///
  /// **Misafir hesapta false** (sözleşme sürüm 4, kullanıcı kararı 10 Ağu):
  /// misafir ne arayabilir (`MISAFIR_ARAMA_YOK`) ne aranabilir
  /// (`ALICI_MISAFIR`). Buradan false dönmesi hem sohbet başlığındaki
  /// düğmeleri hiç çizdirmez hem de 4 sn'lik `GET /arama/gelen` yoklamasını
  /// hiç başlatmaz — gelmesi imkânsız bir arama için tur harcanmaz.
  ///
  /// Sebep kullanıcıdan SAKLANMIYOR: Ayarlar > Gizlilik'te iki anahtar
  /// KİLİTLİ görünüyor ve altında neden kilitli olduğu yazıyor.
  static bool get kullanilabilir =>
      !webMi && _buz != null && _buz!.aramaAcik && !_buz!.misafir;

  /// "YAKINDA GELECEK" modu: platform ve hesap uygun ama SUNUCU bayrağı
  /// kapalı (`arama_acik:false`, `.env`teki `ARAMA_KAPALI`).
  ///
  /// Kullanıcı kararı (13 Ağu): "sesli ve görüntülü aramayı şu an herkeste
  /// devre dışı bırakalım, üstüne tıkladıklarında 'yakında gelecek' yazsın."
  /// Yani bayrak kapalıyken düğmeler artık YOK OLMUYOR: çiziliyor, pasif
  /// görünüyor ve dokununca ne olduğunu söylüyor.
  ///
  /// **Neden [kullanilabilir] değiştirilmedi:** o alan "arayabilir miyim"in
  /// cevabıdır ve 4 sn'lik `GET /arama/gelen` yoklamasının turunu da o
  /// tetikliyor (`_gelenTur`). Bu modda arama GELEMEZ — bayrak kapalıyken
  /// sunucu kimseye arama kurdurmuyor — dolayısıyla yoklama tur harcamamalı.
  /// Düğmeyi görünür yapmak için `kullanilabilir`i gevşetmek, gelmesi imkânsız
  /// bir arama için sonsuza kadar 4 sn'de bir istek atmak demekti.
  ///
  /// **Web ve misafirde bu mod da YOK:** orada özellik "yakında" değil, hiç
  /// gelmeyecek (web kararı bu dosyanın başında, misafir kararı sözleşme
  /// sürüm 4). Tutulamayacak bir söz verilmiyor.
  static bool get yakindaModu =>
      !webMi && _buz != null && !_buz!.aramaAcik && !_buz!.misafir;

  /// Bu hesap misafir mi (sunucudan; `GET /arama/buz-sunuculari`).
  static bool get kendiMisafir => _buz?.misafir == true;

  /// Görüntülü arama açık mı (sunucu bayrağı; kill switch).
  static bool get goruntuluAcik => kullanilabilir && _buz!.goruntuluAcik;

  // ---------------- Kendi tercihim (md. 38) ----------------
  //
  // DÖRT KATMAN VAR, KARIŞTIRILMAMALI (sözleşme §5.0):
  //   1) [kullanilabilir] / [goruntuluAcik] — SUNUCU GENELİ kill switch.
  //      AÇIKSA özellik gerçekten çalışır: düğme aktif çizilir, arama kurulur,
  //      gelen arama yoklaması döner.
  //   2) [yakindaModu] — kill switch KAPALI ama platform ve hesap uygun.
  //      Özellik HENÜZ yok: düğme yine çizilir, PASİF görünür ve dokununca
  //      "Yakında gelecek" der. Hiçbir ağ isteği atılmaz (ne arama, ne
  //      karşılıklı takip sorgusu, ne de gelen arama yoklaması).
  //      Web'de ve misafir hesapta bu katman da çalışmaz: orada özellik
  //      "yakında" değil, HİÇ gelmeyecek.
  //   3) BURASI — kullanıcının KENDİ kararı, varsayılan KAPALI.
  //      Kapalıysa özellik VAR ama kapalı: düğme çizilir, PASİF görünür ve
  //      tıklanınca nereden açılacağını söyler.
  //   4) Karşılıklı takip — düğme çizilmez (mevcut davranış).
  //
  // 2 ve 3 aynı GÖRÜNÜR (pasif düğme) ama farklı METİN verir: 2'de yapılacak
  // bir şey yok (beklenecek), 3'te kullanıcının kendi açacağı bir anahtar var.
  //
  // Gizlemek yerine pasif çizmenin sebebi: varsayılan KAPALI olduğu için,
  // gizlenirse özelliğin VARLIĞINDAN kimse haberdar olmaz ve hiç kimse açmaz.
  // Pasif düğme + açıklaması, tanıtımın kendisidir.

  /// Kendi ayarımdan sesli aramaya izin verdim mi.
  static bool get kendiSesliAcik => _buz?.kendiSesliAcik == true;

  /// Kendi ayarımdan görüntülü aramaya izin verdim mi.
  static bool get kendiGoruntuluAcik => _buz?.kendiGoruntuluAcik == true;

  /// Ayarlar ekranı anahtarı çevirince çağırır: bellekteki kopyayı günceller ve
  /// açık sohbet ekranlarındaki düğmeleri yeniden çizdirir.
  ///
  /// **Sunucuya YAZMAZ** — yazma `/gizlilik-tercihleri` ucundan, ayarlar
  /// ekranındaki mevcut iyimser-güncelleme kalıbıyla yapılır. Burada yalnız
  /// yerel yansıma var; sunucu yazması başarısız olursa ayarlar ekranı bunu da
  /// geri alır.
  static void kendiTercihiKur({bool? sesli, bool? goruntulu}) {
    final b = _buz;
    // Web ya da bayrak hiç alınmamış: gösterilecek düğme yok.
    if (b == null) return;
    _buz = b.kendiTercihle(sesli: sesli, goruntulu: goruntulu);
    surum.value++;
  }

  static int get calmaSaniye => _buz?.calmaSaniye ?? 45;

  @visibleForTesting
  static void ayariKur(BuzAyari? buz) {
    _buz = buz;
    surum.value++;
  }

  /// Açılışta (ve girişten sonra) BİR KEZ çağrılır.
  static Future<void> baslat() async {
    if (webMi || !Api.girisli) return;
    await _buzTazele();
  }

  static Future<bool> _buzTazele() async {
    try {
      _buz = await GorusmeApi.buzSunuculari();
      surum.value++;
      return true;
    } catch (_) {
      // Ağ yoksa arama düğmeleri gizli kalır; uygulamanın geri kalanı
      // etkilenmez.
      return false;
    }
  }

  /// Arama başlatmadan hemen önce çağrılır: kimlik bilgisi bayatladıysa
  /// (kalan geçerlilik < 1 saat) tazeler. Bayat TURN kimliğiyle arama
  /// başlatmak SESSİZ arızadır — röle reddeder, arama "bağlanılamadı" olur.
  static Future<BuzAyari?> buzHazirla() async {
    final b = _buz;
    if (b == null || b.tazelenmeli()) {
      await _buzTazele();
    }
    return _buz;
  }

  // ---------------- Karşılıklı takip ----------------

  /// Kullanıcı adı → düğme gösterilsin mi (oturum boyu önbellek).
  static final Map<String, bool> _karsilikli = {};

  @visibleForTesting
  static void karsilikliOnbellegiTemizle() => _karsilikli.clear();

  /// Arama düğmesi gösterilmeli mi.
  ///
  /// Sunucu zaten `TAKIP_YOK` / `ALICI_MISAFIR` ile reddediyor (sözleşme §5.1
  /// ve §5 adım 8), ama tıklanabilir görünüp KESİN reddedilen bir düğme kötü
  /// deneyimdir — 10 Ağu'daki hatanın özü tam buydu: iki taraf da doğru
  /// ayarlanmıştı, kod izin vermiyordu, arayüz düğmeyi yine de GÖSTERDİ.
  ///
  /// **Neden iki istek:** karşılıklı takibi TEK çağrıda veren bir uç YOK.
  /// `GET /profil/:ad` yalnız `takip_ediyorum` döndürür (ben → o); ters yön
  /// için `GET /takipedilenler/:ad` listesinde kendimi ararım.
  ///
  /// **Misafir hedef:** aynı `GET /profil/:ad` yanıtındaki `misafir` alanından
  /// okunuyor — **EK İSTEK YOK**. Misafirle arama HİÇBİR koşulda mümkün
  /// olmadığı için ikinci istek de atılmıyor: karşılıklı takip sorusunun
  /// cevabı ne olursa olsun sonuç değişmez.
  ///
  /// Eski sunucu `misafir` alanını göndermezse (`!= true`) düğme çizilir ve
  /// karar sunucuya kalır — kullanıcı bu kez ÇEVRİLMİŞ "Misafir hesaplar
  /// aranamaz" metnini görür, eskisi gibi "Kullanıcı bulunamadı"yı değil.
  static Future<bool> karsilikliTakipMi(
    String kullaniciAdi,
    String? benimAd,
  ) async {
    if (benimAd == null || benimAd.isEmpty) return false;
    final onbellek = _karsilikli[kullaniciAdi];
    if (onbellek != null) return onbellek;
    try {
      final profil = await Api.acikProfil(kullaniciAdi);
      if (profil['ben_mi'] == true) return _karsilikli[kullaniciAdi] = false;
      if (profil['engelledim'] == true) {
        return _karsilikli[kullaniciAdi] = false;
      }
      // MİSAFİR HEDEF: arama hiçbir koşulda kurulamaz (403 ALICI_MISAFIR).
      // Takip sorgusundan ÖNCE bakılıyor — ikinci istek boşuna atılmasın.
      if (profil['misafir'] == true) return _karsilikli[kullaniciAdi] = false;
      // Ben onu takip etmiyorsam karşılıklı OLAMAZ — ikinci istek gereksiz.
      if (profil['takip_ediyorum'] != true) {
        return _karsilikli[kullaniciAdi] = false;
      }
      // Md. 21: uç {kullanicilar, gizli} döner. Karşı taraf takip listesini
      // GİZLEMİŞ olsa bile KENDİ satırımız listede kalır (sunucu kuralı) —
      // yoksa listesini gizleyen kullanıcı arama düğmesini kaybederdi.
      final yanit = await Api.takipEdilenler(kullaniciAdi);
      final liste = yanit['kullanicilar'] as List<dynamic>? ?? const [];
      return _karsilikli[kullaniciAdi] = geriTakipEdiyorMu(liste, benimAd);
    } catch (_) {
      // Ağ hatasında düğmeyi GİZLEME: sunucu son sözü söylüyor ve reddederse
      // kullanıcı çevrilmiş "karşılıklı takipleşmelisiniz" metnini görüyor.
      // Sessizce kaybolan bir düğme, hata veren bir düğmeden kötüdür.
      // (Sonuç ÖNBELLEĞE ALINMIYOR: geçici bir ağ hatası oturum boyunca
      // yanlış bir karara dönüşmemeli.)
      return true;
    }
  }

  /// `takipListesi` sorgusunun sunucudaki üst sınırı (server.js:5786).
  static const takipListesiSiniri = 500;

  /// [liste] karşı tarafın TAKİP ETTİKLERİ; içinde [benimAd] varsa o kişi
  /// beni takip ediyor demektir.
  ///
  /// **Kesilme koruması:** sunucu bu listeyi `LIMIT 500` ile döndürüyor
  /// (`server.js` `takipListesi`). Sınıra dayanmış bir listede beni
  /// bulamamak "beni takip etmiyor" ANLAMINA GELMEZ, "bilmiyorum" anlamına
  /// gelir. O durumda `true` dönüp kararı sunucuya bırakıyoruz: 500'den fazla
  /// kişiyi takip eden bir arkadaşımızı arayamamak, yanlışlıkla görünen bir
  /// düğmeden çok daha kötü bir hatadır ve **sessizdir**.
  static bool geriTakipEdiyorMu(List<dynamic> liste, String benimAd) {
    for (final k in liste) {
      if (k is Map && k['kullanici_adi'] == benimAd) return true;
    }
    return liste.length >= takipListesiSiniri;
  }

  // ---------------- Ön plan gelen arama yoklaması ----------------

  static Timer? _gelenYoklama;

  /// Ön plandaki 4 sn'lik `GET /arama/gelen` yoklaması (sözleşme §1).
  /// FCM'in YEDEĞİ, alternatifi değil.
  static const Duration gelenYoklamaAraligi = Duration(seconds: 4);

  /// Gelen arama yakalandığında çağrılır (yönlendirmeyi çağıran kurar).
  static void Function(Map<String, dynamic> arama)? gelenAramaGeldi;

  static void gelenYoklamaBaslat() {
    if (webMi || _gelenYoklama != null) return;
    _gelenYoklama = Timer.periodic(gelenYoklamaAraligi, (_) => _gelenTur());
  }

  static void gelenYoklamaDur() {
    _gelenYoklama?.cancel();
    _gelenYoklama = null;
  }

  static Future<void> _gelenTur() async {
    // Zaten bir aramadaysak ya da özellik kapalıysa tur harcanmaz. Bilerek
    // [kullanilabilir]'e bakılıyor, [yakindaModu]'na DEĞİL: "yakında gelecek"
    // düğmesi görünürken bile arama GELEMEZ, dolayısıyla tek bir istek bile
    // atılmamalı.
    if (!kullanilabilir || aktifAramaId != null || !Api.girisli) return;
    try {
      final arama = await GorusmeApi.gelen();
      if (arama != null) gelenAramaGeldi?.call(arama);
    } catch (_) {
      // Ağ dalgalanması: bir sonraki tur dener.
    }
  }
}
