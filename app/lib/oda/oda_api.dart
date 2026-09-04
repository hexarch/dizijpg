/// İZLEME ODASI — API sarmalayıcısı ve modelleri.
///
/// `gorusme/gorusme_api.dart` ile aynı disiplin: sunucunun MAKİNE hata
/// kodlarına (`kod` alanı) göre dallanılır, Türkçe hata METİNLERİNE göre ASLA.
/// Metinler çeviri turunda değişir; kodlar sabittir.
///
/// Sunucu tarafı: `backend/server.js` (İZLEME ODASI bölümü) + `backend/oda.js`.
/// Kararlar: `IZLEME-ODASI-PLANI.md`.
library;

import '../api.dart';
import '../ceviri.dart';
import 'oda_senkron.dart';

/// Sunucunun makine hata kodları. **Çevrilmez, sabittir.**
class OdaKod {
  static const odaYok = 'ODA_YOK';
  static const odaKapandi = 'ODA_KAPANDI';
  static const davetYok = 'DAVET_YOK';
  static const odaDolu = 'ODA_DOLU';
  static const engelli = 'ENGELLI';
  static const uyeDegil = 'UYE_DEGIL';
  static const sahipDegil = 'SAHIP_DEGIL';
  static const sahipAyrilamaz = 'SAHIP_AYRILAMAZ';
  static const odaZatenVar = 'ODA_ZATEN_VAR';
  static const kodGecersiz = 'KOD_GECERSIZ';
  static const misafirOdaYok = 'MISAFIR_ODA_YOK';
  static const takipYok = 'TAKIP_YOK';
  static const kullaniciYok = 'KULLANICI_YOK';
  static const videoCokBuyuk = 'VIDEO_COK_BUYUK';
  static const turGecersiz = 'TUR_GECERSIZ';
  static const ofsetUyusmaz = 'OFSET_UYUSMAZ';
}

/// Bir hata kodunun kullanıcıya gösterilecek çevrili karşılığı.
///
/// TEK YER: aynı kod üç ekranda (modal, oda ekranı, yükleyici) aynı cümleyi
/// basmalı. Ayrı ayrı yazılsalardı biri güncellenip öteki kalırdı ve kullanıcı
/// aynı kısıt için iki farklı cümle okurdu.
String odaHataMetni(ApiHata e) {
  switch (e.makineKodu) {
    case OdaKod.odaYok:
      return 'Böyle bir oda yok'.c;
    case OdaKod.odaKapandi:
      return 'Bu oda kapandı'.c;
    case OdaKod.davetYok:
      return 'Bu odaya girmek için davet ya da oda kodu gerekli'.c;
    case OdaKod.odaDolu:
      return 'Oda dolu'.c;
    case OdaKod.engelli:
      return 'Bu odaya giremezsin'.c;
    case OdaKod.uyeDegil:
      return 'Bu odanın üyesi değilsin'.c;
    case OdaKod.sahipDegil:
      return 'Bunu yalnız oda sahibi yapabilir'.c;
    case OdaKod.sahipAyrilamaz:
      return 'Oda sahibi odayı kapatmalı'.c;
    case OdaKod.odaZatenVar:
      return 'Zaten açık bir odan var'.c;
    case OdaKod.kodGecersiz:
      return 'Oda kodu 6 karakter olmalı'.c;
    case OdaKod.misafirOdaYok:
      // İki cümle: ne olduğu + ÇIKIŞ YOLU (misafir arama sebebiyle aynı
      // disiplin — "yapamazsın" tek başına kurtarma yolu olmayan bir hatadır).
      return 'Misafir hesaplar izleme odası açamaz. Hesap oluşturursan açabilirsin.'
          .c;
    case OdaKod.takipYok:
      return 'Yalnız karşılıklı takipleştiğin kişileri davet edebilirsin'.c;
    case OdaKod.kullaniciYok:
      return 'Kullanıcı bulunamadı'.c;
    case OdaKod.videoCokBuyuk:
      return 'Video en fazla {} GB olabilir'.cf([odaVideoAzamiGb]);
    case OdaKod.turGecersiz:
      return 'Yalnızca MP4 veya WebM izlenebilir'.c;
    default:
      return e.mesaj.c;
  }
}

/// Video tavanı — sunucudaki `ODA_VIDEO_AZAMI` ile BİREBİR (5 GB).
/// Kayarsa kullanıcı yüklemeye başlar ve sunucu ortada reddeder.
const int odaVideoAzamiGb = 5;
const int odaVideoAzamiBayt = odaVideoAzamiGb * 1024 * 1024 * 1024;

/// Parça boyutu — sunucudaki `ODA_PARCA_AZAMI` ile BİREBİR (8 MB).
const int odaParcaBayt = 8 * 1024 * 1024;

/// Odadaki azami kişi — sunucudaki `ODA_AZAMI_UYE` ile BİREBİR.
const int odaAzamiUye = 12;

/// Bir üye satırı.
class OdaUye {
  final int id;
  final String ad;
  final String? avatar;
  final String rol;
  final bool cevrimici;
  final bool hazir;

  /// null = davet edildi ama HENÜZ GİRMEDİ.
  final int? katildi;

  const OdaUye({
    required this.id,
    required this.ad,
    required this.rol,
    required this.cevrimici,
    required this.hazir,
    this.avatar,
    this.katildi,
  });

  bool get sahip => rol == 'sahip';
  bool get bekliyor => katildi == null;

  factory OdaUye.json(Map<String, dynamic> d) => OdaUye(
    id: (d['id'] as num?)?.toInt() ?? 0,
    ad: (d['ad'] as String?) ?? '',
    avatar: d['avatar'] as String?,
    rol: (d['rol'] as String?) ?? 'izleyici',
    cevrimici: d['cevrimici'] == true,
    hazir: d['hazir'] == true,
    katildi: (d['katildi'] as num?)?.toInt(),
  );
}

/// Oda sohbetindeki bir satır: mesaj, tepki ya da sistem olayı.
class OdaMesaj {
  final int id;
  final int? kullaniciId;
  final String? ad;
  final String? avatar;
  final String? metin;
  final String? tepki;
  final int? konumMs;
  final bool sistem;
  final int tarih;

  /// İYİMSER SATIRIN yerel anahtarı; sunucudan gelen satırlarda null.
  ///
  /// Mesaj dokunur dokunmaz listede belirsin diye var (`sohbet.dart`taki
  /// `_yerelEkle` kalıbının tipli karşılığı). Sunucu onaylayınca aynı satırın
  /// [id]'si gerçek id ile değiştirilir — YENİ SATIR EKLENMEZ, yoksa yoklama
  /// aynı mesajı ikinci kez çizerdi.
  final String? yerel;

  /// Sunucu onayı bekleniyor (saat ikonu + soluk balon).
  final bool bekliyor;

  /// Gönderilemedi — satır KALIR ve "tekrar dene" der. Sessiz kayıp yasak.
  final bool hataliMi;

  const OdaMesaj({
    required this.id,
    required this.tarih,
    required this.sistem,
    this.kullaniciId,
    this.ad,
    this.avatar,
    this.metin,
    this.tepki,
    this.konumMs,
    this.yerel,
    this.bekliyor = false,
    this.hataliMi = false,
  });

  OdaMesaj kopya({int? id, bool? bekliyor, bool? hataliMi}) => OdaMesaj(
    id: id ?? this.id,
    tarih: tarih,
    sistem: sistem,
    kullaniciId: kullaniciId,
    ad: ad,
    avatar: avatar,
    metin: metin,
    tepki: tepki,
    konumMs: konumMs,
    yerel: yerel,
    bekliyor: bekliyor ?? this.bekliyor,
    hataliMi: hataliMi ?? this.hataliMi,
  );

  factory OdaMesaj.json(Map<String, dynamic> d) => OdaMesaj(
    id: (d['id'] as num?)?.toInt() ?? 0,
    kullaniciId: (d['kullanici_id'] as num?)?.toInt(),
    ad: d['ad'] as String?,
    avatar: d['avatar'] as String?,
    metin: d['metin'] as String?,
    tepki: d['tepki'] as String?,
    konumMs: (d['konum_ms'] as num?)?.toInt(),
    sistem: d['sistem'] == true,
    tarih: (d['tarih'] as num?)?.toInt() ?? 0,
  );

  /// Sistem satırının çevrili metni.
  ///
  /// Sunucu ANAHTAR yazar ('katildi'), cümle DEĞİL: cümle yazsaydı odaya
  /// giren herkes odayı AÇANIN diliyle okurdu. Anahtar → çeviri, herkes kendi
  /// dilinde görür.
  String sistemMetni() {
    final kim = ad ?? '';
    switch (metin) {
      case 'katildi':
        return '{} odaya katıldı'.cf([kim]);
      case 'ayrildi':
        return '{} odadan ayrıldı'.cf([kim]);
      case 'video_yuklendi':
        return '{} bir video yükledi'.cf([kim]);
      default:
        return metin ?? '';
    }
  }
}

/// Sunucudaki video hazırlığının durumu (MKV desteği, 4 Eyl 2026).
///
/// Yüklenen dosya ffprobe ile inceleniyor; MKV ise kabı MP4'e çevriliyor ve/veya
/// sesi AAC'ye iniyor. İş ARKA PLANDA koşuyor, bu yüzden istemci bir "hazırlanıyor"
/// hâli çizmek zorunda: sessiz beklemek bozuk görünürdü.
class OdaHazirlik {
  /// 'yok' | 'kuyrukta' | 'isleniyor' | 'hata'
  final String durum;
  final int yuzde;

  /// Sunucunun MAKİNE hata anahtarı (çeviri istemcide).
  final String? hata;
  final String? videoKodek;
  final String? sesKodek;

  /// Bu videonun oynamayacağı platformlar: 'web' (H.265) · 'ios' (VP8/VP9/AV1).
  final List<String> uyumsuz;

  const OdaHazirlik({
    this.durum = 'yok',
    this.yuzde = 0,
    this.hata,
    this.videoKodek,
    this.sesKodek,
    this.uyumsuz = const [],
  });

  bool get suruyor => durum == 'kuyrukta' || durum == 'isleniyor';
  bool get hataliMi => durum == 'hata';
  bool get kuyrukta => durum == 'kuyrukta';

  factory OdaHazirlik.json(Map<String, dynamic> d) => OdaHazirlik(
    durum: (d['hazirlik_durum'] as String?) ?? 'yok',
    yuzde: (d['hazirlik_yuzde'] as num?)?.toInt() ?? 0,
    hata: d['hazirlik_hata'] as String?,
    videoKodek: d['video_kodek'] as String?,
    sesKodek: d['ses_kodek'] as String?,
    uyumsuz: ((d['uyumsuz'] as List<dynamic>?) ?? const [])
        .map((e) => e.toString())
        .toList(),
  );
}

/// Hazırlık hatasının çevrili karşılığı — sunucu ANAHTAR yollar, cümle burada.
String odaHazirlikHatasi(String? anahtar) {
  switch (anahtar) {
    case 'VIDEO_KODEK_DESTEKSIZ':
      // ÇIKIŞ YOLU ver: yalnız "desteklenmiyor" demek kullanıcıyı çıkmazda
      // bırakır (misafir arama sebebiyle aynı disiplin).
      return 'Bu videonun görüntü biçimi oynatılamıyor. MP4 (H.264) olarak çevirip yeniden dene.'
          .c;
    case 'VIDEO_GORUNTU_YOK':
      return 'Bu dosyada görüntü yok'.c;
    case 'VIDEO_OKUNAMADI':
      return 'Video okunamadı, dosya bozuk olabilir'.c;
    case 'DISK_YETERSIZ':
      return 'Sunucuda yer kalmadı, biraz sonra tekrar dene'.c;
    case 'VIDEO_YOK':
      return 'Video bulunamadı'.c;
    default:
      return 'Video hazırlanamadı'.c;
  }
}

/// Odanın tam anlık görüntüsü.
class Oda {
  final int id;
  final String kod;
  final String? baslik;
  final int sahipId;
  final String sahip;
  final String? sahipAvatar;
  final String? video;
  final String? videoAd;
  final int? videoSureMs;
  final String? videoKapak;
  final int biter;
  final bool sahibiMiyim;
  final OdaDurum durum;
  final OdaHazirlik hazirlik;
  final List<OdaUye> uyeler;

  const Oda({
    required this.id,
    required this.kod,
    required this.sahipId,
    required this.sahip,
    required this.biter,
    required this.sahibiMiyim,
    required this.durum,
    required this.uyeler,
    this.hazirlik = const OdaHazirlik(),
    this.baslik,
    this.sahipAvatar,
    this.video,
    this.videoAd,
    this.videoSureMs,
    this.videoKapak,
  });

  /// GÖVDE BEKLENMEDİK OLABİLİR ve bu ekranı ÇÖKERTMEMELİ: `as num` sert
  /// dönüşümü, eski bir sunucu ya da araya giren bir portal sayfası yüzünden
  /// alan eksik geldiğinde yakalanmayan bir `TypeError` fırlatıyordu (3 Eyl
  /// 2026, gezinme testi yakaladı). Eksik id 0 olur; ekran onu "oda yok"
  /// olarak gösterir — ham hata metni değil.
  factory Oda.json(Map<String, dynamic> d) => Oda(
    id: (d['id'] as num?)?.toInt() ?? 0,
    kod: (d['kod'] as String?) ?? '',
    baslik: d['baslik'] as String?,
    sahipId: (d['sahip_id'] as num?)?.toInt() ?? 0,
    sahip: (d['sahip'] as String?) ?? '',
    sahipAvatar: d['sahip_avatar'] as String?,
    video: d['video'] as String?,
    videoAd: d['video_ad'] as String?,
    videoSureMs: (d['video_sure_ms'] as num?)?.toInt(),
    videoKapak: d['video_kapak'] as String?,
    biter: (d['biter'] as num?)?.toInt() ?? 0,
    sahibiMiyim: d['sahibi_miyim'] == true,
    durum: OdaDurum.json(d, surum: (d['surum'] as num?)?.toInt() ?? 0),
    hazirlik: OdaHazirlik.json(d),
    uyeler: ((d['uyeler'] as List<dynamic>?) ?? const [])
        .map((e) => OdaUye.json(e as Map<String, dynamic>))
        .toList(),
  );

  Oda kopya({
    String? video,
    String? videoAd,
    int? videoSureMs,
    OdaDurum? durum,
    OdaHazirlik? hazirlik,
    List<OdaUye>? uyeler,
  }) => Oda(
    id: id,
    kod: kod,
    baslik: baslik,
    sahipId: sahipId,
    sahip: sahip,
    sahipAvatar: sahipAvatar,
    video: video ?? this.video,
    videoAd: videoAd ?? this.videoAd,
    videoSureMs: videoSureMs ?? this.videoSureMs,
    videoKapak: videoKapak,
    biter: biter,
    sahibiMiyim: sahibiMiyim,
    durum: durum ?? this.durum,
    hazirlik: hazirlik ?? this.hazirlik,
    uyeler: uyeler ?? this.uyeler,
  );
}

/// "+" modalindeki liste satırı (odalarım + davetlerim).
class OdaOzet {
  final int id;
  final String kod;
  final String? baslik;
  final String sahip;
  final String? sahipAvatar;
  final bool videoVar;
  final String? videoAd;
  final int biter;
  final int uyeSayisi;
  final bool davet;
  final bool sahibiMiyim;

  const OdaOzet({
    required this.id,
    required this.kod,
    required this.sahip,
    required this.videoVar,
    required this.biter,
    required this.uyeSayisi,
    required this.davet,
    required this.sahibiMiyim,
    this.baslik,
    this.sahipAvatar,
    this.videoAd,
  });

  factory OdaOzet.json(Map<String, dynamic> d) => OdaOzet(
    id: (d['id'] as num?)?.toInt() ?? 0,
    kod: (d['kod'] as String?) ?? '',
    baslik: d['baslik'] as String?,
    sahip: (d['sahip'] as String?) ?? '',
    sahipAvatar: d['sahip_avatar'] as String?,
    videoVar: d['video_var'] == true,
    videoAd: d['video_ad'] as String?,
    biter: (d['biter'] as num?)?.toInt() ?? 0,
    uyeSayisi: (d['uye_sayisi'] as num?)?.toInt() ?? 0,
    davet: d['davet'] == true,
    sahibiMiyim: d['sahibi_miyim'] == true,
  );
}

/// Bir yoklama turunun sonucu.
class OdaAkis {
  /// Sunucunun yanıt anındaki saati (epoch ms) — saat sapması bununla ölçülür.
  final int sunucuZaman;
  final int surum;
  final int biter;

  /// Durum DEĞİŞMEDİYSE null (yoklamanın büyük çoğunluğu).
  final OdaDurum? durum;
  final String? video;
  final String? videoAd;
  final int? videoSureMs;
  final List<OdaUye>? uyeler;
  final List<OdaMesaj> mesajlar;

  /// Hazırlık durumu HER yanıtta gelir (`durum` gibi koşullu DEĞİL): ilerleme
  /// yüzdesi sürüm artmadan da akmalı, yoksa çubuk %0da donmuş görünürdü.
  final OdaHazirlik hazirlik;

  const OdaAkis({
    required this.sunucuZaman,
    required this.surum,
    required this.biter,
    required this.mesajlar,
    this.durum,
    this.video,
    this.videoAd,
    this.videoSureMs,
    this.uyeler,
    this.hazirlik = const OdaHazirlik(),
  });

  factory OdaAkis.json(Map<String, dynamic> d) {
    final ham = d['durum'] as Map<String, dynamic>?;
    final surum = (d['surum'] as num?)?.toInt() ?? 0;
    return OdaAkis(
      sunucuZaman: (d['sunucu_zaman'] as num?)?.toInt() ?? 0,
      surum: surum,
      biter: (d['biter'] as num?)?.toInt() ?? 0,
      durum: ham == null ? null : OdaDurum.json(ham, surum: surum),
      video: ham?['video'] as String?,
      videoAd: ham?['video_ad'] as String?,
      videoSureMs: (ham?['video_sure_ms'] as num?)?.toInt(),
      hazirlik: OdaHazirlik.json(d),
      uyeler: (d['uyeler'] as List<dynamic>?)
          ?.map((e) => OdaUye.json(e as Map<String, dynamic>))
          .toList(),
      mesajlar: ((d['mesajlar'] as List<dynamic>?) ?? const [])
          .map((e) => OdaMesaj.json(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Kalan süreyi kısa biçimde yazar: "11 sa", "42 dk", "30 sn".
///
/// TEK BİRİM: "11 sa 42 dk" yazmak bir GERİ SAYIM gibi okunur ve kullanıcıyı
/// saniyeleri izlemeye davet eder. Oda 12 saat yaşıyor; burada gereken bilgi
/// "acele etmeli miyim" — tek birim onu veriyor.
String odaSureKisa(int ms) {
  if (ms <= 0) return 'bitti'.c;
  final sn = ms ~/ 1000;
  if (sn >= 3600) return '{} sa'.cf([sn ~/ 3600]);
  if (sn >= 60) return '{} dk'.cf([sn ~/ 60]);
  return '{} sn'.cf([sn]);
}

/// Video konumunu `s:ss` / `s:ss:ss` biçiminde yazar (oynatıcı ve sohbet damgası).
///
/// Saat hanesi YALNIZ gerekliyse çizilir: 3 dakikalık bir videoda "0:03:12"
/// yazmak, ilerleme çubuğunun yanında sürekli göze çarpan ölü bir hane bırakır.
String odaKonumBicim(int ms) {
  final t = ms ~/ 1000;
  final sa = t ~/ 3600;
  final dk = (t % 3600) ~/ 60;
  final sn = t % 60;
  String iki(int n) => n.toString().padLeft(2, '0');
  return sa > 0 ? '$sa:${iki(dk)}:${iki(sn)}' : '$dk:${iki(sn)}';
}

/// Uçların ince sarmalayıcısı.
class OdaApi {
  static Future<Oda> olustur({String? baslik}) async {
    // Gövde koşullu ELEMANLA değil satırla kuruluyor: koleksiyon-if burada
    // `use_null_aware_elements` uyarısı doğuruyor ve bu projede YENİ uyarı
    // bırakmamak kural (aynı gerekçe `Api.takipToggle`de yazılı).
    final govde = <String, dynamic>{};
    if (baslik != null) govde['baslik'] = baslik;
    return Oda.json(await Api.post('/odalar', govde) as Map<String, dynamic>);
  }

  static Future<List<OdaOzet>> listem() async {
    final d = await Api.get('/odalar') as Map<String, dynamic>;
    return ((d['odalar'] as List<dynamic>?) ?? const [])
        .map((e) => OdaOzet.json(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Oda> katil(String kod) async => Oda.json(
    await Api.post('/odalar/katil', {'kod': kod}) as Map<String, dynamic>,
  );

  static Future<Oda> getir(int id) async =>
      Oda.json(await Api.get('/odalar/$id') as Map<String, dynamic>);

  /// Yoklama. [surum] ve [mesajdan] gönderilir ki sunucu değişmeyeni
  /// göndermesin — 1 sn'lik turun bedeli bir indeks okumasına insin.
  ///
  /// [uyeler] yalnız arada bir true verilir (birkaç saniyede bir): üye listesi
  /// her turda çekilseydi yoklama her seferinde fazladan bir JOIN koşardı ve
  /// neredeyse hiç değişmeyen bir veriyi taşırdı.
  static Future<OdaAkis> akis(
    int id, {
    required int surum,
    required int mesajdan,
    bool uyeler = false,
  }) async => OdaAkis.json(
    await Api.get(
          '/odalar/$id/akis?surum=$surum&mesajdan=$mesajdan'
          '${uyeler ? '&uyeler=1' : ''}',
        )
        as Map<String, dynamic>,
  );

  /// Oynatma durumunu yazar — YALNIZ oda sahibi çağırabilir.
  ///
  /// [kalp] true ise sunucu `surum`u ARTIRMAZ: bu bir kullanıcı eylemi değil,
  /// sahibin 10 saniyede bir konumunu tazelemesidir. Artırsaydı izleyiciler
  /// her 10 saniyede bir "kasıtlı eylem" sanıp seek eder, düzgün akan video
  /// zıplardı.
  static Future<Map<String, dynamic>> durumYaz(
    int id, {
    required bool oynuyor,
    required int konumMs,
    bool kalp = false,
  }) async =>
      await Api.post('/odalar/$id/durum', {
            'oynuyor': oynuyor,
            'konum_ms': konumMs,
            'kalp': kalp,
          })
          as Map<String, dynamic>;

  /// Mesaj/tepki gönderir ve sunucunun yanıtını (`{id, tarih}`) döndürür.
  ///
  /// `id` GEREKLİ: iyimser satır onaylanınca gerçek id'sini alır ve yoklama
  /// aynı satırı ikinci kez çizmesin diye elenir (bkz. `_metniGonder`).
  static Future<Map<String, dynamic>> mesaj(
    int id, {
    String? metin,
    String? tepki,
    int? konumMs,
  }) async {
    final govde = <String, dynamic>{};
    if (metin != null) govde['metin'] = metin;
    if (tepki != null) govde['tepki'] = tepki;
    if (konumMs != null) govde['konum_ms'] = konumMs;
    final d = await Api.post('/odalar/$id/mesaj', govde);
    return d is Map<String, dynamic> ? d : const {};
  }

  static Future<void> davet(int id, String kullanici) =>
      Api.post('/odalar/$id/davet', {'kullanici': kullanici});

  static Future<void> hazir(int id, bool hazirMi) =>
      Api.post('/odalar/$id/hazir', {'hazir': hazirMi});

  static Future<void> ayril(int id) => Api.post('/odalar/$id/ayril', const {});

  static Future<void> kapat(int id) => Api.delete('/odalar/$id');

  /// Sahip tetikler: H.265 videoyu tarayıcıda oynayacak H.264'e çevirir.
  /// PAHALIDIR (2 saatlik filmde 20-40 dk) — bu yüzden otomatik değil.
  static Future<void> videoCevir(int id) =>
      Api.post('/odalar/$id/video-cevir', const {});
}
