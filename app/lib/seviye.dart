import 'ceviri.dart';

/// MİNİ SEVİYE / UNVAN (istek md. 29) — SAF hesap + etiket. Widget YOK.
///
/// "Amatör izleyici → profesör izleyici → ultra mega izleyici gibi unvanlar.
///  Unvanları BİZ koyacağız (kullanıcı seçmeyecek)."
///
/// SÖZLEŞME — HESAP SUNUCUDA, ETİKET BURADA:
///  · Kademe, puan ve eşikler SUNUCUDAN gelir (`server.js` → `seviyeHesapla`).
///    İstemci hiçbir eşiği KENDİ BİLMEZ; tabloyu buraya kopyalasaydık iki
///    tarafın eşikleri ilk düzenlemede ayrışır ve kullanıcı kendi profilinde
///    başkasının gördüğünden farklı bir unvan okurdu.
///  · Sunucu dilden bağımsız bir KOD yollar (`profesor`); Türkçe metin ve
///    45 dile çeviri BURADA (`_adlar` + `.c`).
///  · İlerleme (çubuk, "kaç puan kaldı") YALNIZ kendi profilinde çizilir.
///    Sunucu ziyaretçiye `puan`/`esik`/`sonraki_esik` GÖNDERMEZ; bu yüzden
///    [ilerlemeVar] başkasının profilinde doğal olarak false olur —
///    istemcinin ayrıca "ben miyim?" diye sorması gerekmez.
///
/// UTANDIRMAMA (maddenin şartı) — İKİ KATMAN:
///  1) Sunucu 1. kademeyi açık profile HİÇ göndermez (`seviyeAcikGorunum`),
///     yani yeni bir hesap ziyaretçiye "en alttayım" ilan etmez.
///  2) Adların hiçbiri aşağılayıcı değil: en alt kademe "acemi/çaylak" değil,
///     nötr-olumlu "Meraklı izleyici". Ton hafif esprili (kullanıcının
///     istediği gibi) ama kimseye beceriksiz demez.
class Seviye {
  /// 1'den başlar. 1 = en alt kademe.
  final int kademe;

  /// Dilden bağımsız kademe kodu (`merakli`, `profesor`, `ultra_mega` …).
  final String kod;

  /// Toplam kademe sayısı ("Seviye 5/8" satırı için).
  final int toplam;

  /// Seviye puanı — YALNIZ kendi profilinde gelir, ziyaretçide null.
  final int? puan;

  /// Bulunulan kademenin alt sınırı — yalnız kendi profilinde.
  final int? esik;

  /// Bir sonraki kademenin eşiği; en üst kademede (ya da ziyaretçide) null.
  final int? sonrakiEsik;

  /// Bir sonraki kademenin kodu; en üst kademede (ya da ziyaretçide) null.
  /// Sunucudan gelir — istemci kademe SIRASINI bilmez (eşik tablosunun tek
  /// kopyası sunucudadır).
  final String? sonrakiKod;

  const Seviye({
    required this.kademe,
    required this.kod,
    required this.toplam,
    this.puan,
    this.esik,
    this.sonrakiEsik,
    this.sonrakiKod,
  });

  /// Sunucu yanıtındaki `seviye` alanını çözer. Alan yoksa, null'sa, biçimi
  /// bozuksa ya da kod tanınmıyorsa **null** döner — ekranda satır hiç
  /// çizilmez. (Tanınmayan kodda ham `kod`u basmak, kullanıcıya
  /// "ultra_mega" gibi bir anahtar göstermek olurdu.)
  static Seviye? cozumle(Object? ham) {
    if (ham is! Map) return null;
    final kademe = (ham['kademe'] as num?)?.toInt();
    final kod = ham['kod'] as String?;
    final toplam = (ham['toplam'] as num?)?.toInt();
    if (kademe == null || kademe < 1) return null;
    if (kod == null || !_adlar.containsKey(kod)) return null;
    if (toplam == null || toplam < kademe) return null;
    return Seviye(
      kademe: kademe,
      kod: kod,
      toplam: toplam,
      puan: (ham['puan'] as num?)?.toInt(),
      esik: (ham['esik'] as num?)?.toInt(),
      sonrakiEsik: (ham['sonraki_esik'] as num?)?.toInt(),
      // Tanınmayan kod yok sayılır: "Sonraki: ultra_mega" yazmaktansa satırı
      // hiç yazmamak yeğdir (eski istemci + yeni sunucu durumu).
      sonrakiKod: _adlar.containsKey(ham['sonraki_kod'])
          ? ham['sonraki_kod'] as String
          : null,
    );
  }

  /// Kademe kodu → Türkçe unvan. Anahtarlar `lib/diller` içinde 45 dile
  /// çevrilir; buradaki Türkçe metin ÇEVİRİ ANAHTARININ KENDİSİDİR.
  static const Map<String, String> _adlar = {
    'merakli': 'Meraklı izleyici',
    'hevesli': 'Hevesli izleyici',
    'amator': 'Amatör izleyici',
    'kidemli': 'Kıdemli izleyici',
    'uzman': 'Uzman izleyici',
    'profesor': 'Profesör izleyici',
    'efsane': 'Efsane izleyici',
    'ultra_mega': 'Ultra mega izleyici',
  };

  /// Çeviri anahtarı olarak kullanılan Türkçe unvanların tamamı (testler ve
  /// çeviri betiği bu listeyi okur).
  static List<String> get tumAdlar => _adlar.values.toList(growable: false);

  /// Bilinen kademe kodları, en alttan en üste doğru DEĞİL — sırayı sunucu
  /// bilir; bu yalnız tanıma listesidir.
  static Iterable<String> get tumKodlar => _adlar.keys;

  /// Seçili dildeki unvan.
  String get etiket => _adlar[kod]!.c;

  /// Seçili dildeki BİR SONRAKİ unvan; yoksa null.
  String? get sonrakiEtiket =>
      sonrakiKod == null ? null : _adlar[sonrakiKod]!.c;

  /// "Seviye 5/8".
  String get konumEtiketi => 'Seviye {}/{}'.cf([kademe, toplam]);

  /// İlerleme çubuğunun ALTINDAKİ satır — YALNIZ kendi profilinde çizilir.
  ///
  /// İLERİ BAKAN İFADE (bilerek): "%18 tamamlandı" değil, "Sonraki: Kıdemli
  /// izleyici". Yüzde, az izleyene ne kadar AZ yaptığını söyler; hedef adı
  /// ne kazanacağını söyler. Konum ("Seviye 3/8") yalnız BURADA, yani kendi
  /// profilinde var — açık profilde 8 kademenin 7'si "en üstte değil" diye
  /// etiketlenmiş olurdu.
  String get altSatir {
    final sonraki = sonrakiEtiket;
    if (sonraki == null) return '${'En üst unvan'.c} · $konumEtiketi';
    return '${'Sonraki: {}'.cf([sonraki])} · $konumEtiketi';
  }

  /// İlerleme çizilebilir mi? Kendi profilinde ve en üst kademede DEĞİLKEN
  /// true. Ziyaretçiye puan/eşik gitmediği için orada daima false.
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

  /// En üst kademede miyim? (Kendi profilinde ilerleme yerine bu yazılır.)
  bool get enUst => kademe >= toplam;
}
