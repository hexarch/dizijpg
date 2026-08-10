/// Sesli/görüntülü arama uçlarının ince sarmalayıcısı.
///
/// Sözleşme: `backend/ARAMA-API-SOZLESMESI.md`. Alan adları BAĞLAYICIDIR;
/// değiştirmek gerekirse önce o belge güncellenir, sonra burası.
///
/// DOSYA ADI NEDEN "gorusme": `lib/ekranlar/arama.dart` ZATEN VAR ve o
/// **dizi/film araması**. Backend de aynı çarpışmayı yaşayıp hız limitine
/// `gorusmeLimiti` adını verdi (`aramaLimiti` search'e ait, server.js:955).
/// Aynı ayrımı istemcide de koruyoruz: dosya/sınıf adları `gorusme*`,
/// KULLANICIYA GÖRÜNEN metinler ve uç yolları `arama`.
library;

import '../api.dart';
import '../ceviri.dart';

/// Sunucunun makine hata kodları (sözleşme §8). **Çevrilmez, sabittir.**
class AramaKod {
  static const aramaKapali = 'ARAMA_KAPALI';
  static const goruntuluKapali = 'GORUNTULU_KAPALI';
  static const gecersizIstek = 'GECERSIZ_ISTEK';
  static const kullaniciYok = 'KULLANICI_YOK';
  static const kendineArama = 'KENDINE_ARAMA';
  static const engelli = 'ENGELLI';
  static const takipYok = 'TAKIP_YOK';
  static const aliciYasakli = 'ALICI_YASAKLI';

  /// Aranan kişi KENDİ ayarından sesli/görüntülü aramayı kapatmış (md. 38).
  ///
  /// [aramaKapali]/[goruntuluKapali] ile KARIŞTIRILMAMALI: onlar sunucu geneli
  /// kill switch'tir ("özellik şu an kapalı"), bunlar tek bir kullanıcının
  /// kararıdır ("aradığın kişide kapalı"). Yanlış sebep göstermek kullanıcıya
  /// uygulamayı bozuk gösterir — sözleşme §5.0.
  static const aliciSesliKapali = 'ALICI_SESLI_KAPALI';
  static const aliciGoruntuluKapali = 'ALICI_GORUNTULU_KAPALI';
  static const cokFazlaCevapsiz = 'COK_FAZLA_CEVAPSIZ';
  static const zatenAramada = 'ZATEN_ARAMADA';
  static const durumUygunDegil = 'DURUM_UYGUN_DEGIL';
  static const tarafDegil = 'TARAF_DEGIL';
  static const aramaYok = 'ARAMA_YOK';
}

/// Bir arama hatasında ekranın ne yapması gerektiği.
enum AramaTepkisi {
  /// SnackBar göster, kullanıcı bulunduğu ekranda kalsın.
  uyar,

  /// Arama ekranını kapat (ya da hiç açma).
  kapat,

  /// Zaten süren bir arama var; onun ekranına dön.
  mevcutAramayaDon,
}

/// Bir arama hatasının kullanıcıya dönük karşılığı.
class AramaHatasi {
  /// Sunucunun makine kodu; hız limitinde null olur (sözleşme §8 uyum notu).
  final String? kod;

  /// 45 dile çevrilmiş kullanıcı metni.
  final String metin;
  final AramaTepkisi tepki;

  const AramaHatasi(this.kod, this.metin, this.tepki);
}

/// Kalan saniyeyi kullanıcıya okunur bir süreye çevirir (en az 1 dakika).
String _kalanSure(num? saniye) {
  final sn = (saniye ?? 0).round();
  if (sn <= 0) return '{} dk'.cf([1]);
  if (sn < 3600) return '{} dk'.cf([(sn / 60).ceil()]);
  return '{} sa'.cf([(sn / 3600).ceil()]);
}

/// [ApiHata]'yı ekranın anlayacağı [AramaHatasi]'na çevirir.
///
/// **Türkçe metne göre DALLANMAZ** (sözleşme §14.2): sunucunun `hata` alanı
/// insan içindir ve değişebilir; `kod` alanı sabittir. `kod` hiç yoksa HTTP
/// durumuna düşülür — hız limiti yanıtı tam olarak öyle gelir.
AramaHatasi aramaHatasiCozumle(Object hata) {
  if (hata is! ApiHata) {
    // Ağ/zaman aşımı: sunucudan yanıt bile gelmedi.
    return AramaHatasi(null, 'Arama başlatılamadı'.c, AramaTepkisi.uyar);
  }
  switch (hata.makineKodu) {
    case AramaKod.aramaKapali:
      return AramaHatasi(
        AramaKod.aramaKapali,
        'Arama şu anda kullanılamıyor'.c,
        AramaTepkisi.kapat,
      );
    case AramaKod.goruntuluKapali:
      return AramaHatasi(
        AramaKod.goruntuluKapali,
        'Görüntülü arama şu anda kapalı, sesli arayabilirsin'.c,
        AramaTepkisi.kapat,
      );
    case AramaKod.gecersizIstek:
      return AramaHatasi(
        AramaKod.gecersizIstek,
        'Arama başlatılamadı'.c,
        AramaTepkisi.kapat,
      );
    case AramaKod.kullaniciYok:
      return AramaHatasi(
        AramaKod.kullaniciYok,
        'Kullanıcı bulunamadı'.c,
        AramaTepkisi.kapat,
      );
    case AramaKod.kendineArama:
      return AramaHatasi(
        AramaKod.kendineArama,
        'Kendini arayamazsın'.c,
        AramaTepkisi.kapat,
      );
    case AramaKod.engelli:
      return AramaHatasi(
        AramaKod.engelli,
        'Bu kullanıcıyı arayamazsın'.c,
        AramaTepkisi.uyar,
      );
    case AramaKod.takipYok:
      return AramaHatasi(
        AramaKod.takipYok,
        'Aramak için karşılıklı takipleşmelisiniz'.c,
        AramaTepkisi.uyar,
      );
    case AramaKod.aliciYasakli:
      return AramaHatasi(
        AramaKod.aliciYasakli,
        'Bu kullanıcı şu anda aranamıyor'.c,
        AramaTepkisi.uyar,
      );
    // md. 38 — TÜR BAZLI metin ZORUNLU. Tek bir genel metin ("bu kişi aranamıyor")
    // kullanıcıya "peki ötekini denesem olur mu" sorusunu sordurur; sunucu türü
    // zaten söylüyor, saklamanın anlamı yok.
    //
    // `uyar` (kapat DEĞİL): kullanıcı sohbet ekranında kalır. Arama ekranı
    // hiç açılmadı; kapatılacak bir şey yok ve sohbetten atılmak cezalandırıcı.
    case AramaKod.aliciSesliKapali:
      return AramaHatasi(
        AramaKod.aliciSesliKapali,
        'Aradığınız kişide sesli arama devre dışı'.c,
        AramaTepkisi.uyar,
      );
    case AramaKod.aliciGoruntuluKapali:
      return AramaHatasi(
        AramaKod.aliciGoruntuluKapali,
        'Aradığınız kişide görüntülü arama devre dışı'.c,
        AramaTepkisi.uyar,
      );
    case AramaKod.cokFazlaCevapsiz:
      return AramaHatasi(
        AramaKod.cokFazlaCevapsiz,
        'Çok fazla cevapsız arama. {} sonra tekrar dene'.cf([
          _kalanSure(hata.govde?['kalan_sn'] as num?),
        ]),
        AramaTepkisi.uyar,
      );
    case AramaKod.zatenAramada:
      return AramaHatasi(
        AramaKod.zatenAramada,
        'Zaten bir aramadasın'.c,
        AramaTepkisi.mevcutAramayaDon,
      );
    case AramaKod.durumUygunDegil:
      return AramaHatasi(
        AramaKod.durumUygunDegil,
        'Arama artık geçerli değil'.c,
        AramaTepkisi.kapat,
      );
    case AramaKod.tarafDegil:
      return AramaHatasi(
        AramaKod.tarafDegil,
        'Bu aramanın tarafı değilsin'.c,
        AramaTepkisi.kapat,
      );
    case AramaKod.aramaYok:
      return AramaHatasi(
        AramaKod.aramaYok,
        'Arama bulunamadı'.c,
        AramaTepkisi.kapat,
      );
  }
  // `kod` YOK: hız limiti (429) ya da beklenmeyen bir sunucu hatası.
  if (hata.kod == 429) {
    return AramaHatasi(
      null,
      'Çok fazla istek, biraz bekle'.c,
      AramaTepkisi.uyar,
    );
  }
  if (hata.kod == 403 && hata.yasak != null) {
    // Hesap askıda: mevcut ban akışı zaten `Api.yasak` üzerinden uyarıyor.
    return AramaHatasi(null, hata.mesaj, AramaTepkisi.kapat);
  }
  return AramaHatasi(null, 'Arama başlatılamadı'.c, AramaTepkisi.uyar);
}

/// `GET /arama/buz-sunuculari` yanıtı: ICE sunucuları + özellik bayrakları.
///
/// **DİSKE YAZILMAZ** (sözleşme §3.3): TURN kimlik bilgisi kısa ömürlü bir
/// sırdır, `SharedPreferences`'a konursa cihaz yedeğine sızar. Yalnız bellekte
/// yaşar ve uygulama kapanınca gider.
class BuzAyari {
  final List<Map<String, dynamic>> sunucular;
  final int gecerlilikSn;
  final bool aramaAcik;
  final bool goruntuluAcik;

  /// **KENDİ** tercihim (md. 38) — yukarıdaki iki bayrakla AYNI ŞEY DEĞİL.
  ///
  /// `aramaAcik`/`goruntuluAcik` sunucu geneli kill switch'tir; kapalıysa düğme
  /// **hiç çizilmez**. Bunlar ise kullanıcının kendi kararıdır (varsayılan
  /// **kapalı**) ve kapalıyken düğme **çizilir ama PASİF görünür** — tıklanınca
  /// nereden açılacağını söyler. Sözleşme §14.2b.
  final bool kendiSesliAcik;
  final bool kendiGoruntuluAcik;

  final int calmaSaniye;

  /// Alındığı an — [tazelenmeli] bunun üstünden karar verir.
  final DateTime alindi;

  BuzAyari({
    required this.sunucular,
    required this.gecerlilikSn,
    required this.aramaAcik,
    required this.goruntuluAcik,
    required this.calmaSaniye,
    required this.alindi,
    this.kendiSesliAcik = false,
    this.kendiGoruntuluAcik = false,
  });

  /// Ayarlardan tercih değişince yeni bir istek atmadan güncellemek için.
  /// TURN kimliği ve `alindi` KORUNUR — yoksa her anahtar dokunuşu kimliği
  /// "taze" sanıp bayat kimlikle arama başlatma riskini geri getirirdi.
  BuzAyari kendiTercihle({bool? sesli, bool? goruntulu}) => BuzAyari(
    sunucular: sunucular,
    gecerlilikSn: gecerlilikSn,
    aramaAcik: aramaAcik,
    goruntuluAcik: goruntuluAcik,
    calmaSaniye: calmaSaniye,
    alindi: alindi,
    kendiSesliAcik: sesli ?? kendiSesliAcik,
    kendiGoruntuluAcik: goruntulu ?? kendiGoruntuluAcik,
  );

  factory BuzAyari.json(Map<String, dynamic> d, {DateTime? simdi}) => BuzAyari(
    sunucular: [
      for (final s in (d['buz_sunuculari'] as List<dynamic>? ?? const []))
        Map<String, dynamic>.from(s as Map),
    ],
    gecerlilikSn: (d['gecerlilik_sn'] as num?)?.toInt() ?? 0,
    aramaAcik: d['arama_acik'] == true,
    goruntuluAcik: d['goruntulu_acik'] == true,
    // Eksik alan = KAPALI. Sunucuyla aynı varsayılan-ret yönü: eski bir
    // sunucudan yanıt gelirse düğmeler pasif görünür (kullanıcı sebebini
    // okur), tersi olsaydı düğme aktif görünüp sunucu 403 verirdi.
    kendiSesliAcik: d['kendi_sesli_acik'] == true,
    kendiGoruntuluAcik: d['kendi_goruntulu_acik'] == true,
    calmaSaniye: (d['calma_saniye'] as num?)?.toInt() ?? 45,
    alindi: simdi ?? DateTime.now(),
  );

  /// Kalan geçerlilik 1 saatin altına indiyse arama başlatmadan önce tazelenir
  /// (sözleşme §3.3). Bayat kimlikle arama başlatmak SESSİZ arızadır: TURN
  /// reddeder, arama "bağlanılamadı" olur ve sebebi hiçbir yerde yazmaz.
  bool tazelenmeli([DateTime? simdi]) {
    final gecen = (simdi ?? DateTime.now()).difference(alindi).inSeconds;
    return gecerlilikSn - gecen < 3600;
  }
}

/// Arama uçları. Hepsi `Api` üzerinden gider (token + `X-Dil` + `X-Cihaz`).
class GorusmeApi {
  static Future<BuzAyari> buzSunuculari() async =>
      BuzAyari.json(await Api.get('/arama/buz-sunuculari'));

  /// `tur`: `'ses'` | `'goruntu'`. `sdp` **tüm ICE adaylarını içeren** tek
  /// pakettir (trickle YOK, sözleşme §1).
  static Future<Map<String, dynamic>> baslat({
    required String kullaniciAdi,
    required String tur,
    required String sdp,
  }) async =>
      await Api.post('/arama/baslat', {
            'kullanici_adi': kullaniciAdi,
            'tur': tur,
            'sdp': sdp,
          })
          as Map<String, dynamic>;

  static Future<Map<String, dynamic>> durum(String aramaId) async =>
      await Api.get('/arama/durum/$aramaId') as Map<String, dynamic>;

  /// Ön plandaki 4 sn'lik yoklama. Arama yoksa `{'arama': null}`.
  static Future<Map<String, dynamic>?> gelen() async {
    final d = await Api.get('/arama/gelen') as Map<String, dynamic>;
    final a = d['arama'];
    return a is Map ? Map<String, dynamic>.from(a) : null;
  }

  static Future<Map<String, dynamic>> yanit({
    required String aramaId,
    required bool kabul,
    String? sdp,
  }) async =>
      await Api.post('/arama/yanit', {
            'arama_id': aramaId,
            'kabul': kabul,
            if (kabul && sdp != null) 'sdp': sdp,
          })
          as Map<String, dynamic>;

  /// ICE yeniden başlatmada (Wi-Fi ↔ hücresel) yeni adaylar. En çok 20 aday.
  static Future<void> aday({
    required String aramaId,
    required List<Map<String, dynamic>> adaylar,
  }) => Api.post('/arama/aday', {
    'arama_id': aramaId,
    'adaylar': adaylar.take(20).toList(),
  });

  /// Aramayı kapatır.
  ///
  /// **`sebep` BAĞLAYICIDIR** (sözleşme §13.1): sunucu "arama bağlandı" anını
  /// GÖREMEZ, çünkü bağlantı kurulunca yoklama tamamen durur. Bu yüzden
  /// `baglaniyor` durumundaki bir aramanın veritabanına `basarisiz` mı yoksa
  /// `cevaplandi` mı yazılacağına YALNIZCA bu alan karar verir. ICE
  /// kurulamadıysa `'ice_basarisiz'` göndermemek, bağlanamamış aramayı
  /// `cevaplandi` olarak kaydeder ve röle oranı ölçümünü (§6.1) sessizce
  /// bozar — görüntülü aramanın maliyet kararı o veriye dayanıyor.
  static Future<Map<String, dynamic>> bitir({
    required String aramaId,
    required String sebep,
    Map<String, dynamic>? olcum,
  }) async =>
      await Api.post('/arama/bitir', {
            'arama_id': aramaId,
            'sebep': sebep,
            'olcum': ?olcum,
          })
          as Map<String, dynamic>;

  static Future<List<dynamic>> gecmis({int? once, int adet = 30}) async {
    final s = StringBuffer('/arama/gecmis?adet=$adet');
    if (once != null) s.write('&once=$once');
    return (await Api.get(s.toString()))['aramalar'] as List<dynamic>;
  }
}

/// `POST /arama/bitir` sebep değerleri (sözleşme §4.7 enum).
class AramaSebep {
  static const kullanici = 'kullanici';
  static const agKoptu = 'ag_koptu';
  static const iceBasarisiz = 'ice_basarisiz';
  static const zamanAsimi = 'zaman_asimi';
}
