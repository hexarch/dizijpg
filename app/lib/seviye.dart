import 'ceviri.dart';

/// Kullanıcı kararı (16 Ağu 2026): seviye şimdilik KAPALI.
/// Profilde satır çizilmez. Hesap ve çeviriler duruyor; `true` yapmak yeter.
const bool seviyeSistemiAcik = false;

/// MİNİ SEVİYE (istek md. 29, 14 Ağu revizyonu) — SAF hesap + etiket.
/// Widget YOK.
///
/// "Seviye sistemi kalsın ama 7/8 gibi yazma; bir seviye sistemimiz olsun,
///  ona göre artsın seviyesi."
///
/// 14 AĞU'DA KALKANLAR:
///  · UNVANLAR ("Meraklı izleyici" … "Ultra mega izleyici"). Ekranda hiçbir
///    yerde yok; sunucu artık `kod` göndermiyor.
///  · KESİRLİ GÖSTERİM ("Seviye 7/8"). Payda YOK — seviyenin TAVANI YOK,
///    yazılabilecek bir toplam da yok.
///  · "Sonraki: {unvan}" ve "En üst unvan" satırları.
///
/// SÖZLEŞME — HESAP SUNUCUDA, CÜMLE BURADA:
///  · Kademe, puan ve eşikler SUNUCUDAN gelir (`server.js` → `seviyeHesapla`,
///    eşik eğrisi `14 × (n−1)³`). İstemci eğriyi KENDİ BİLMEZ; buraya
///    kopyalasaydık iki taraf ilk düzenlemede ayrışır ve kullanıcı kendi
///    profilinde başkasının gördüğünden farklı bir sayı okurdu.
///  · Sunucu SALT SAYI yollar; "Seviye 7" cümlesi ve 45 dile çevirisi
///    BURADA (`'Seviye {}'` anahtarı + `.cf`).
///  · İlerleme (çubuk, "kaç puan kaldı") YALNIZ kendi profilinde çizilir.
///    Sunucu ziyaretçiye `puan`/`esik`/`sonraki_esik` GÖNDERMEZ; bu yüzden
///    [ilerlemeVar] başkasının profilinde doğal olarak false olur —
///    istemcinin ayrıca "ben miyim?" diye sorması gerekmez.
///
/// UTANDIRMAMA (maddenin şartı): sunucu 1. kademeyi açık profile HİÇ
/// göndermez (`seviyeAcikGorunum`), yani yeni bir hesap ziyaretçiye
/// "en alttayım" ilan etmez. Unvanlar kalktığı için ikinci katman (aşağılayıcı
/// olmayan adlar) artık gereksiz: ortada ad yok, yalnız sayı var.
class Seviye {
  /// 1'den başlar. ÜST SINIRI YOKTUR — 7 de olabilir 41 de.
  final int kademe;

  /// Seviye puanı — YALNIZ kendi profilinde gelir, ziyaretçide null.
  final int? puan;

  /// Bulunulan kademenin alt sınırı — yalnız kendi profilinde.
  final int? esik;

  /// Bir sonraki kademenin eşiği — yalnız kendi profilinde. Tavan olmadığı
  /// için sunucu bunu DAİMA doldurur; null yalnızca ziyaretçi görünümünde
  /// (ya da bozuk yanıtta) olur.
  final int? sonrakiEsik;

  const Seviye({required this.kademe, this.puan, this.esik, this.sonrakiEsik});

  /// Ekrana basılacak kayıt. Sistem kapalıysa daima null — sunucu hâlâ
  /// tam kayıt gönderse bile satır çizilmez.
  static Seviye? ekranda(Object? ham) =>
      seviyeSistemiAcik ? cozumle(ham) : null;

  /// Sunucu yanıtındaki `seviye` alanını çözer. Alan yoksa, null'sa ya da
  /// biçimi bozuksa **null** döner — ekranda satır hiç çizilmez.
  static Seviye? cozumle(Object? ham) {
    if (ham is! Map) return null;
    final kademe = (ham['kademe'] as num?)?.toInt();
    if (kademe == null || kademe < 1) return null;
    return Seviye(
      kademe: kademe,
      puan: (ham['puan'] as num?)?.toInt(),
      esik: (ham['esik'] as num?)?.toInt(),
      sonrakiEsik: (ham['sonraki_esik'] as num?)?.toInt(),
    );
  }

  /// "Seviye 7". Tek satırlık kimlik — payda ("/8") YOK: tavan kalktı, yani
  /// bir toplam yazmak hem yanlış hem de "7'de kaldın" hissi verirdi.
  String get etiket => 'Seviye {}'.cf([kademe]);

  /// İlerleme çizilebilir mi? Yalnız kendi profilinde true; ziyaretçiye
  /// puan/eşik gitmediği için orada daima false.
  bool get ilerlemeVar =>
      puan != null &&
      esik != null &&
      sonrakiEsik != null &&
      sonrakiEsik! > esik!;

  /// Çubuk dolgusu 0..1. İlerleme yoksa null. Sunucu ile istemci arasındaki
  /// bir tur gecikmesinde puan eşiği aşmış olabilir — 0..1 arasına KIRPILIR,
  /// aksi hâlde `LinearProgressIndicator` taşar.
  double? get ilerleme {
    if (!ilerlemeVar) return null;
    final aralik = sonrakiEsik! - esik!;
    final gidilen = puan! - esik!;
    final oran = gidilen / aralik;
    return oran < 0 ? 0 : (oran > 1 ? 1 : oran);
  }

  /// Bir sonraki seviyeye kalan puan. İlerleme yoksa null. Gecikmiş veride
  /// negatife düşebilir — 0'a kırpılır (eksi bir "kalan" saçmalık olurdu).
  int? get kalanPuan {
    if (!ilerlemeVar) return null;
    final kalan = sonrakiEsik! - puan!;
    return kalan < 0 ? 0 : kalan;
  }

  /// İlerleme çubuğunun ALTINDAKİ satır — YALNIZ kendi profilinde çizilir.
  ///
  /// İLERİ BAKAN İFADE (bilerek, eski gerekçe korunuyor): "%18 tamamlandı"
  /// az izleyene ne kadar AZ yaptığını söyler; HEDEF ise ne kazanacağını
  /// söyler. Unvan kalktığı için hedef artık bir ad değil, somut bir mesafe:
  /// "Sonraki seviyeye 320 puan kaldı". Konum ("Seviye 3/8") YOK — o payda
  /// hem kalktı hem de "8'de 3" bir sıralama gibi okunuyordu.
  String? get altSatir {
    final kalan = kalanPuan;
    if (kalan == null) return null;
    return 'Sonraki seviyeye {} puan kaldı'.cf([kalan]);
  }
}
