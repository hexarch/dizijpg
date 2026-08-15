import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'ceviri.dart';
import 'cihaz_kimlik.dart';
import 'google_kapisi.dart';
import 'icerik_deposu.dart';
import 'kitaplik_durumu.dart';
import 'onbellek.dart';

/// dizi.jpg API istemcisi (nginx + Cloudflare arkasında, TLS'li).
const String apiTaban = 'https://dizijpg.com/api';

/// TMDB görsel adresleri
String? posterUrl(String? yol, {String boyut = 'w342'}) =>
    yol == null ? null : 'https://image.tmdb.org/t/p/$boyut$yol';

/// Poster kartları için TMDB boyutunu KART GENİŞLİĞİ ve PİKSEL YOĞUNLUĞUNA
/// göre seçer.
///
/// NEDEN: her yerde sabit `w342` isteniyordu. Telefonda (105-118 dp kart) bu
/// doğru; masaüstünde ızgara kartı 240-490 dp'ye çıkıyor ve `devicePixelRatio`
/// 2 olan ekranda 480-980 FİZİKSEL piksel gerekiyor — 342 px'lik görsel 1,4x
/// ile 2,9x arası büyütülüp gözle görülür bulanıklaşıyordu.
///
/// KURALLAR:
///  * Taban `w342`. Bunun ALTINA İNİLMEZ — bugünkü mobil kalite ve mobil veri
///    kullanımı birebir korunsun (küçük kartta w185'e düşürmek 6 Ağu'da
///    denenmiş ve geri alınmıştı, bkz. `PosterKarti`).
///  * Gerekli piksel taban boyutu [_azamiBuyutme] kadarını da aşıyorsa bir üst
///    basamağa çıkılır: w500 → w780.
///  * Tavan `w780`. `original` ÇEKİLMEZ: poster başına birkaç MB eder,
///    ızgarada 30 poster = onlarca MB — bant genişliği israfı.
///
/// [_azamiBuyutme] 1.15: %15'e kadar büyütme gözle ayırt edilmiyor, ama bir
/// üst basamak ~2 kat bayt demek. Örn. 3x yoğunluklu telefonda 118 dp kart
/// 354 px ister; w342 (1.035x büyütme) yeterlidir, w500 israf olurdu.
const double _azamiBuyutme = 1.15;

/// Poster kartı için TMDB boyut adı ('w342' | 'w500' | 'w780').
///
/// [genislikDp] kartın MANTIKSAL genişliği, [pikselOrani] ekranın
/// `devicePixelRatio` değeri.
String posterBoyutu(double genislikDp, double pikselOrani) {
  // Bozuk/ölçülemeyen genişlikte (sonsuz, NaN, sıfır) tabana düş.
  if (!genislikDp.isFinite || genislikDp <= 0) return 'w342';
  final oran = (pikselOrani.isFinite && pikselOrani > 0) ? pikselOrani : 1.0;
  final gerekli = genislikDp * oran;
  if (gerekli <= 342 * _azamiBuyutme) return 'w342';
  if (gerekli <= 500 * _azamiBuyutme) return 'w500';
  return 'w780';
}

/// Sunucudaki dosya yolları (avatar, yorum medyası) → tam URL
String? dosyaUrl(String? yol) =>
    yol == null ? null : (yol.startsWith('http') ? yol : '$apiTaban$yol');

class ApiHata implements Exception {
  final String mesaj;

  /// HTTP durum kodu — yalnız sunucudan gelen hatalarda dolu.
  ///
  /// NEDEN: "bulunamadı/gizli" (404) ile "ağ/sunucu arızası" farklı EKRAN
  /// ister: birincisinde tekrar denemek anlamsızdır, ikincisinde şart. Mesaj
  /// metnine bakarak ayırmak çeviri değişince kırılırdı.
  final int? kod;

  /// Hesap askıya alındıysa cezanın ayrıntısı: `{kalici, bitis, kalan_sn,
  /// sebep}`. Yalnız 403 + yasak yanıtlarında dolu olur.
  final Map<String, dynamic>? yasak;

  /// Sunucunun MAKİNE hata kodu (`{"hata": "...", "kod": "TAKIP_YOK"}`).
  ///
  /// NEDEN AYRI ALAN: arama uçları 13 ayrı hata durumunu tek tek ayırt
  /// etmemizi istiyor (backend/ARAMA-API-SOZLESMESI.md §8) ve bunların
  /// çoğu AYNI HTTP kodunu paylaşıyor — `ENGELLI`, `TAKIP_YOK` ve
  /// `ALICI_YASAKLI` üçü de 403. Türkçe [mesaj] metnine göre dallanmak ise
  /// sunucu metnini değiştirdiği gün sessizce kırılır. `kod` sabittir ve
  /// ÇEVRİLMEZ; istemci ona karşılık gelen kendi 45 dilli metnini basar.
  ///
  /// Hız limiti yanıtlarında (`hizLimiti()`, server.js:907) `kod` alanı
  /// YOKTUR — o durumda null kalır ve çağıran [kod] (HTTP) değerine düşer.
  final String? makineKodu;

  /// Hata gövdesinin tamamı. Bazı kodlar metne girecek EK ALAN taşır —
  /// `COK_FAZLA_CEVAPSIZ` gövdesindeki `kalan_sn` gibi. Alan başına yeni bir
  /// özellik açmak yerine ham harita saklanır; okuyan kendi kodunu bilir.
  final Map<String, dynamic>? govde;

  ApiHata(this.mesaj, {this.kod, this.yasak, this.makineKodu, this.govde});

  /// Sunucu Türkçe anahtar basar; ekranda seçili dilin karşılığı durur.
  /// Haritada yoksa Türkçe kalır (yeni uç, henüz çevrilmemiş metin).
  @override
  String toString() => mesaj.c;
}

class Api {
  static String? _token;

  /// TEK, kalıcı istemci: bağlantı (TCP+TLS) yeniden kullanılır. Her çağrıda
  /// yeni http.get kullanılsaydı her istekte TLS el sıkışması tekrarlanır ve
  /// istek başına ~130ms boşa giderdi.
  static http.Client _istemci = http.Client();

  /// YALNIZ TEST: gerçek ağ yerine sahte istemci tak (http/testing MockClient).
  @visibleForTesting
  static set istemci(http.Client c) => _istemci = c;

  static Future<void> tokenYukle() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
  }

  static bool get girisli => _token != null;

  static Future<void> _tokenKaydet(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove('token');
    } else {
      await prefs.setString('token', token);
    }
  }

  static Map<String, String> get _basliklar => {
    'Content-Type': 'application/json',
    // İçerik dili: TMDB başlık/özet/tür bu dilde gelsin
    'X-Dil': Ceviri.dil.value,
    // KURULUM kimliği (moderasyon). DONANIMDAN OKUNMAZ — uygulamanın kendi
    // ürettiği rastgele bir etiket; silinip kurulunca değişir. Ayrıntı ve
    // sınırları `cihaz_kimlik.dart` başlığında.
    if (CihazKimlik.kimlik != null) 'X-Cihaz': CihazKimlik.kimlik!,
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  /// Hesap askıya alındıysa sunucudan gelen ceza bilgisi
  /// (`{kalici, bitis, kalan_sn, sebep}`), yoksa null.
  ///
  /// NEDEN GLOBAL BİR NOTIFIER: ceza her yanıtta gelebilir — 403 gövdesinde,
  /// giriş yanıtında ya da `/profilim` içinde. Her çağrı yerinde ayrı ayrı
  /// yakalamak yerine tek yerde toplanıp ekranlar bunu DİNLİYOR; böylece
  /// kullanıcı hangi ekranda olursa olsun uyarıyı görüyor. Sessizce çalışmayan
  /// bir uygulama en kötü deneyimdir.
  static final ValueNotifier<Map<String, dynamic>?> yasak = ValueNotifier(null);

  /// Yanıt gövdesindeki `yasak` alanını yakalar (varsa) ve bildiriyi günceller.
  /// Ceza kalkmışsa (sunucu artık yasak göndermiyorsa) uyarı da kalkar.
  static void _yasakOku(dynamic govde, {bool temizle = false}) {
    if (govde is Map && govde['yasak'] is Map) {
      yasak.value = Map<String, dynamic>.from(govde['yasak'] as Map);
    } else if (temizle) {
      yasak.value = null;
    }
  }

  /// Katalog (TMDB) isteklerine dili ADRESE ekler: Cloudflare önbelleği
  /// yalnız URL'e bakar, başlığa değil — dil adreste olmasaydı kenar
  /// önbelleği bir dilin yanıtını başka dildeki kullanıcıya verirdi.
  static String _dilliYol(String yol) {
    if (!yol.startsWith('/tmdb/')) return yol;
    final ayirac = yol.contains('?') ? '&' : '?';
    return '$yol${ayirac}dil=${Ceviri.dil.value}';
  }

  /// Varsayılan istek zaman aşımı.
  static const Duration zamanAsimiVarsayilan = Duration(seconds: 20);

  /// Toplu TMDB çekimi yapan AĞIR uçlar için (takvim gibi) zaman aşımı.
  /// ÖLÇÜM (3 Ağu, 69 dizilik kitaplık): soğuk önbellekte /takvim tek istekte
  /// 312 TMDB çağrısı yapıyor ve 16,6 sn sürüyor — 20 sn sınırının hemen
  /// altında. Mobil bağlantıda ya da TMDB 429 verip yeniden denemeye
  /// girdiğinde 20 sn rahatlıkla aşılıyordu; aşınca istemci sessizce ESKİ
  /// kopyayı koruyordu (bugünkü "takvimden dizi kayboldu" hatası). nginx
  /// proxy_read_timeout 300 sn olduğu için 60 sn güvenli üst sınır.
  static const Duration zamanAsimiAgir = Duration(seconds: 60);

  static Future<dynamic> get(String yol, {Duration? zamanAsimi}) async {
    final cevap = await _istemci
        .get(Uri.parse('$apiTaban${_dilliYol(yol)}'), headers: _basliklar)
        .timeout(zamanAsimi ?? zamanAsimiVarsayilan);
    return _isle(cevap);
  }

  static Future<dynamic> post(String yol, Map<String, dynamic> govde) async {
    final cevap = await _istemci
        .post(
          Uri.parse('$apiTaban$yol'),
          headers: _basliklar,
          body: jsonEncode(govde),
        )
        .timeout(const Duration(seconds: 20));
    return _isle(cevap);
  }

  static Future<dynamic> delete(String yol) async {
    final cevap = await _istemci
        .delete(Uri.parse('$apiTaban$yol'), headers: _basliklar)
        .timeout(const Duration(seconds: 20));
    return _isle(cevap);
  }

  static Future<dynamic> patch(String yol, Map<String, dynamic> govde) async {
    final cevap = await _istemci
        .patch(
          Uri.parse('$apiTaban$yol'),
          headers: _basliklar,
          body: jsonEncode(govde),
        )
        .timeout(const Duration(seconds: 20));
    return _isle(cevap);
  }

  static dynamic _isle(http.Response cevap) {
    final govde = cevap.body.isEmpty ? {} : jsonDecode(cevap.body);
    if (cevap.statusCode >= 400) {
      // 403 + `yasak` = hesap askıda. Bilgiyi yakala ki ekranlar sebebi ve
      // kalan süreyi gösterebilsin; hata yine de fırlatılır (çağıran akış
      // "başarılı" sanmasın).
      _yasakOku(govde);
      throw ApiHata(
        govde is Map && govde['hata'] != null
            ? govde['hata'] as String
            : 'Sunucu hatası ({})'.cf([cevap.statusCode]),
        kod: cevap.statusCode,
        yasak: govde is Map && govde['yasak'] is Map
            ? Map<String, dynamic>.from(govde['yasak'] as Map)
            : null,
        makineKodu: govde is Map && govde['kod'] is String
            ? govde['kod'] as String
            : null,
        govde: govde is Map ? Map<String, dynamic>.from(govde) : null,
      );
    }
    return govde;
  }

  // ---- oturum ----
  static Future<Map<String, dynamic>> kayit(
    String email,
    String kullaniciAdi,
    String sifre,
  ) async {
    final d = await post('/auth/kayit', {
      'email': email,
      'kullanici_adi': kullaniciAdi,
      'sifre': sifre,
    });
    await _tokenKaydet(d['token'] as String);
    return d['kullanici'] as Map<String, dynamic>;
  }

  /// Şifreyle giriş. İKİ SONUÇ döner:
  ///  * 2FA KAPALI → `{kullanici: {...}}`; oturum token'ı kaydedilmiştir.
  ///  * 2FA AÇIK   → `{iki_adim: true, bilet, eposta_ipucu}`; TOKEN YOKTUR.
  ///
  /// Çağıran `iki_adim`a bakmak ZORUNDA: `d['kullanici']`ye körlemesine
  /// uzanan kod 2FA'lı hesapta null patlar (md. 52).
  static Future<Map<String, dynamic>> giris(String email, String sifre) async {
    final d = await post('/auth/giris', {'email': email, 'sifre': sifre});
    if (d['iki_adim'] == true) return Map<String, dynamic>.from(d as Map);
    await _tokenKaydet(d['token'] as String);
    // Yasaklı kullanıcı GİREBİLİR (cezasını uygulama içinde görsün diye);
    // yanıtta ceza varsa hemen yakalanır. `temizle: true`: ceza kalkmışsa
    // önceki oturumdan kalan uyarı da düşer.
    _yasakOku(d, temizle: true);
    return Map<String, dynamic>.from(d as Map);
  }

  /// Girişin İKİNCİ ADIMI: e-postaya gelen kodu doğrular, oturumu açar.
  ///
  /// [bilet] ilk adımdan gelen kısa ömürlü belirteçtir. ŞİFRE BURADA YOK —
  /// şifreyi ikinci adım için istemcide bekletmek yasak; sunucu kimliği
  /// bilete bağlıyor (backend `iki_adim.js`).
  static Future<Map<String, dynamic>> girisKodu(
    String bilet,
    String kod,
  ) async {
    final d = await post('/auth/giris-kod', {'bilet': bilet, 'kod': kod});
    await _tokenKaydet(d['token'] as String);
    _yasakOku(d, temizle: true);
    return d['kullanici'] as Map<String, dynamic>;
  }

  /// Giriş kodunu yeniden gönderir; BİLET aynı kalır (şifre tekrar sorulmaz).
  static Future<void> girisKoduYenile(String bilet) =>
      post('/auth/giris-kod-yenile', {'bilet': bilet});

  // ---- iki adımlı doğrulama ayarları (md. 52) ----

  /// `{acik, kullanilabilir, eposta_ipucu}`.
  /// `kullanilabilir` false ise hesabın e-postası yok (misafir) — kod
  /// gönderilecek bir yer olmadığı için anahtar kapalı çizilir.
  static Future<Map<String, dynamic>> ikiAdimDurumu() async =>
      await get('/auth/iki-adim') as Map<String, dynamic>;

  /// Aç/kapat kodunu e-postaya gönderir. [amac]: 'ac' | 'kapat'.
  static Future<Map<String, dynamic>> ikiAdimKodIste(String amac) async =>
      await post('/auth/iki-adim/kod', {'amac': amac}) as Map<String, dynamic>;

  /// Kodu doğrular ve ayarı uygular; dönen `acik` yeni durumdur.
  /// KAPATMA DA KOD İSTER: çalınmış bir oturum kilidi sessizce açamasın.
  static Future<bool> ikiAdimDogrula(String amac, String kod) async {
    final d = await post('/auth/iki-adim/dogrula', {'amac': amac, 'kod': kod});
    return d['acik'] == true;
  }

  static Future<Map<String, dynamic>> misafirGiris() async {
    final d = await post('/auth/misafir', {});
    await _tokenKaydet(d['token'] as String);
    return d['kullanici'] as Map<String, dynamic>;
  }

  /// Google ile giriş/kayıt: Android kimlik (id) token'ı, web erişim token'ı
  /// yollar; sunucu Google'a doğrulatır. Dönen harita: {kullanici, yeni}.
  static Future<Map<String, dynamic>> googleGiris({
    String? kimlik,
    String? erisim,
  }) async {
    final d = await post('/auth/google', {
      if (kimlik != null) 'kimlik': kimlik,
      if (erisim != null) 'erisim': erisim,
    });
    await _tokenKaydet(d['token'] as String);
    _yasakOku(d, temizle: true);
    return d;
  }

  /// Misafir hesabını e-postaya bağlar; sunucu yeni token döndürür.
  static Future<Map<String, dynamic>> hesabiBagla(
    String email,
    String? kullaniciAdi,
    String sifre,
  ) async {
    final d = await post('/auth/bagla', {
      'email': email,
      if (kullaniciAdi != null && kullaniciAdi.isNotEmpty)
        'kullanici_adi': kullaniciAdi,
      'sifre': sifre,
    });
    await _tokenKaydet(d['token'] as String);
    return d['kullanici'] as Map<String, dynamic>;
  }

  static Future<void> cikis() async {
    await Onbellek.temizle(); // başka hesap eski verileri görmesin
    await _tokenKaydet(null);
  }

  /// FCM cihaz token'ını sunucuya kaydeder (push bildirimleri için).
  /// `surum` de gider: admin panelindeki sürüm dağılımı buradan beslenir
  /// (hata günlüğü yalnızca HATA ALAN kullanıcıyı sayıyordu).
  static Future<void> cihazTokenKaydet(
    String token,
    String platform,
    String dil,
  ) => post('/cihaz-token', {
    'token': token,
    'platform': platform,
    'dil': dil,
    'surum': surum,
  });

  /// Sürüm kapısı: sunucudaki eşiklerle kendi derleme numaramızı karşılaştırır.
  /// Ateşle-unut mantığı — ağ yoksa/ayar yoksa uygulama normal açılır.
  static Future<Map<String, dynamic>?> surumKontrol() async {
    final derleme = int.tryParse(surum.split('+').last);
    if (derleme == null) return null;
    try {
      final y = await _istemci
          .get(Uri.parse('$apiTaban/surum-kontrol?derleme=$derleme'))
          .timeout(const Duration(seconds: 8));
      if (y.statusCode != 200) return null;
      return jsonDecode(y.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// FCM cihaz token'ını sunucudan siler.
  static Future<void> cihazTokenSil(String token) async {
    await _istemci
        .delete(
          Uri.parse('$apiTaban/cihaz-token'),
          headers: _basliklar,
          body: jsonEncode({'token': token}),
        )
        .timeout(const Duration(seconds: 15));
  }

  /// Hesabı ve tüm veriyi kalıcı siler (şifreli hesapta şifre doğrulanır).
  static Future<void> hesabiSil(String sifre) async {
    final cevap = await _istemci
        .delete(
          Uri.parse('$apiTaban/hesabim'),
          headers: _basliklar,
          body: jsonEncode({'sifre': sifre}),
        )
        .timeout(const Duration(seconds: 20));
    _isle(cevap);
    await _tokenKaydet(null);
  }

  /// Bir içeriği/kullanıcıyı şikayet eder.
  static Future<void> sikayetEt(String tur, int hedefId, String sebep) =>
      post('/sikayet', {'tur': tur, 'hedef_id': hedefId, 'sebep': sebep});

  /// Kullanıcıyı engelle/engeli kaldır; sonuç engellendi mi?
  static Future<bool> engelleToggle(String kullaniciAdi) async {
    final d = await post('/engelle/$kullaniciAdi', {});
    return d['engellendi'] as bool;
  }

  /// Engellediğim kullanıcılar.
  static Future<List<dynamic>> engellenenler() async =>
      (await get('/engellenenler'))['kullanicilar'] as List<dynamic>;

  /// Uygulama sürümü (hata bildirimlerinde etiketlenir; pubspec ile eşle).
  /// DİKKAT: pubspec version'ı artınca BURAYI da güncelle — 1.7.1'de
  /// unutulduğu için hata günlüğü üç sürüm boyunca yanlış etiketlendi.
  /// pubspec ile AYNI olmalı — `test/surum_tutarlilik_test.dart` bunu doğrular
  /// (3 Ağu: 1.12.9+52'de kalmıştı, hata günlüğü iki sürüm yanlış etiketlendi
  /// ve sürüm kapısı yanlış derleme numarasını karşılaştıracaktı).
  static const surum = '1.56.0+104';

  /// İstemci hatası/çökmesini sunucuya bildirir (self-hosted günlük).
  /// Ateşle-unut: kendi hatasında sessiz kalır ki döngü oluşmasın.
  static Future<void> hataBildir(
    Object hata,
    StackTrace? yigin, {
    String? yol,
  }) async {
    try {
      await post('/hata-bildir', {
        'mesaj': hata.toString(),
        'yigin': yigin?.toString(),
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'surum': surum,
        if (yol != null) 'yol': yol,
      });
    } catch (_) {
      // sessiz
    }
  }

  /// Şifre sıfırlama gibi dış akışların aldığı token'ı kaydeder.
  static Future<void> tokenKaydet(String token) => _tokenKaydet(token);

  // ---- profil ----
  // ---- ceza itirazı (uygulama içi; e-posta kutusuna bağımlılık YOK) ----

  /// `{itiraz, yazabilir}` — ban ekranı formu mu, durumu mu çizeceğini
  /// buradan öğrenir. Kural SUNUCUDA (tek açık itiraz, aynı ceza için bir
  /// kez); istemci onu yalnız yansıtır, kendi kopyasını tutmaz.
  static Future<Map<String, dynamic>> itirazDurumu() async =>
      await get('/itirazim') as Map<String, dynamic>;

  /// Cezaya itiraz gönderir. `POST /itiraz` yazma yasağından MUAFTIR
  /// (backend `yasak.js/YASAK_MUAF`) — olmasaydı yasaklı kullanıcı itiraz
  /// edemez, sistem kendi kendini kilitlerdi.
  static Future<Map<String, dynamic>> itirazGonder(String metin) async =>
      await post('/itiraz', {'metin': metin}) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> profilim() async {
    final d = await get('/profilim') as Map<String, dynamic>;
    // Hiç YAZMAYAN yasaklı kullanıcı 403 görmez; cezasını burada öğrenir.
    // `temizle: true`: ceza kalkmışsa (süre doldu / yönetici kaldırdı) uyarı da
    // kalksın — aksi halde serbest kalan kullanıcıda banner asılı kalırdı.
    _yasakOku(d, temizle: true);
    return d;
  }

  static Future<Map<String, dynamic>> profilGuncelle({
    required String bio,
    required String ulke,
    List<Map<String, dynamic>>? sosyal,
  }) async =>
      await post('/profilim', {
            'bio': bio,
            'ulke': ulke,
            if (sosyal != null) 'sosyal': sosyal,
          })
          as Map<String, dynamic>;

  /// Profil resmi yükler (avatar). Sunucu türü baytlardan doğrular.
  static Future<String> avatarYukle(Uint8List veri) async =>
      _profilResmiYukle('avatar', veri);

  /// Kapak (arka plan) resmi yükler.
  static Future<String> kapakYukle(Uint8List veri) async =>
      _profilResmiYukle('kapak', veri);

  static Future<String> _profilResmiYukle(String alan, Uint8List veri) async {
    final cevap = await _istemci
        .post(
          Uri.parse('$apiTaban/profilim/$alan'),
          headers: {
            'Content-Type': 'application/octet-stream',
            if (_token != null) 'Authorization': 'Bearer $_token',
          },
          body: veri,
        )
        .timeout(const Duration(minutes: 2));
    return (_isle(cevap) as Map<String, dynamic>)[alan] as String;
  }

  /// Yorum eki (fotoğraf/video) yükler; sunucu yolunu döndürür.
  static Future<Map<String, dynamic>> medyaYukle(Uint8List veri) async {
    final cevap = await _istemci
        .post(
          Uri.parse('$apiTaban/medya'),
          headers: {
            'Content-Type': 'application/octet-stream',
            if (_token != null) 'Authorization': 'Bearer $_token',
          },
          body: veri,
        )
        .timeout(const Duration(minutes: 5));
    return _isle(cevap) as Map<String, dynamic>;
  }

  // ---- sosyal ----
  static Future<Map<String, dynamic>> acikProfil(String kullaniciAdi) async =>
      await get('/profil/$kullaniciAdi') as Map<String, dynamic>;

  /// Takip et / takipten çık.
  ///
  /// [kaynakGonderi] — md. 23: "bu gönderiden kaç kişi takip etti". Bir
  /// GÖNDERİ KARTINDAKİ takip düğmesinden çağrılıyorsa gönderinin id'si
  /// verilir. Sunucu bunu YALNIZ gerçekten yeni takip satırı açıldığında
  /// sayar; takip-bırak-takip döngüsü sayacı şişiremez. Sayaç AGREGATTIR:
  /// kimin takip ettiği yazılmaz.
  static Future<Map<String, dynamic>> takipToggle(
    String kullaniciAdi, {
    int? kaynakGonderi,
  }) async {
    // Gövde koşullu ELEMANLA değil, iki satırla kuruluyor: koleksiyon-if
    // burada `use_null_aware_elements` uyarısı doğuruyor ve bu dosyada YENİ
    // uyarı bırakmamak proje kuralı.
    final govde = <String, dynamic>{};
    if (kaynakGonderi != null) govde['kaynak_gonderi'] = kaynakGonderi;
    return await post('/takip/$kullaniciAdi', govde) as Map<String, dynamic>;
  }

  /// Takipçi/takip listesi. YANITIN TAMAMI döner: md. 21'den beri sunucu
  /// `{kullanicilar, gizli}` gönderiyor ve `gizli:true` "liste boş" DEĞİL
  /// "kullanıcı gizlemeyi seçti" demek — yalnız `kullanicilar` okunursa ekran
  /// gizli listeyi "Takipçi yok" diye yanlış anlatır.
  static Future<Map<String, dynamic>> takipciler(String kullaniciAdi) async =>
      await get('/takipciler/$kullaniciAdi') as Map<String, dynamic>;

  static Future<Map<String, dynamic>> takipEdilenler(
    String kullaniciAdi,
  ) async => await get('/takipedilenler/$kullaniciAdi') as Map<String, dynamic>;

  static Future<List<dynamic>> kullaniciAra(String q) async =>
      (await get(
            '/kullanici-ara?q=${Uri.encodeQueryComponent(q)}',
          ))['kullanicilar']
          as List<dynamic>;

  static Future<Map<String, dynamic>> yorumBegen(int yorumId) async =>
      await post('/yorumlar/$yorumId/begen', {}) as Map<String, dynamic>;

  // ---- veri aktarma (GDPR) ----
  /// Verileri ZIP'leyip kullanıcının e-postasına gönderir.
  static Future<String> veriDisaAktar() async {
    final d = await post('/veri/disa-aktar', {}) as Map<String, dynamic>;
    return d['mesaj'] as String? ?? 'Gönderildi'.c;
  }

  /// ZIP verisini içe aktarır; içe aktarım özetini döndürür.
  static Future<Map<String, dynamic>> veriIceAktar(Uint8List zip) async {
    final cevap = await _istemci
        .post(
          Uri.parse('$apiTaban/veri/ice-aktar'),
          headers: {
            'Content-Type': 'application/zip',
            if (_token != null) 'Authorization': 'Bearer $_token',
          },
          body: zip,
        )
        .timeout(const Duration(minutes: 5));
    return (_isle(cevap) as Map<String, dynamic>)['ozet']
        as Map<String, dynamic>;
  }
}

/// Oturum durumu (giriş yapan kullanıcı bilgisi).
class Oturum extends ChangeNotifier {
  Map<String, dynamic>? kullanici;

  /// Yeni kayıt sonrası karşılama ekranına yönlendirmeyi tetikler
  /// (yalnız bu oturum için; uygulama yeniden başlayınca sıfırlanır).
  static bool karsilamaGerekli = false;

  bool get girisli => Api.girisli;

  Future<void> yukle() async {
    await Api.tokenYukle();
    final prefs = await SharedPreferences.getInstance();
    final ham = prefs.getString('kullanici');
    if (ham != null) kullanici = jsonDecode(ham) as Map<String, dynamic>;
    notifyListeners();
  }

  Future<void> girisYapildi(Map<String, dynamic> k) async {
    kullanici = k;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kullanici', jsonEncode(k));
    KitaplikDurumu.yukle(); // poster kartlarındaki "izledin" rozeti için
    notifyListeners();
    // GİRİŞ YANITINDA AVATAR YOK — bu yüzden hemen `/profilim` ile tazelenir.
    // Ayrıntı `tazele()` başlığında; buradaki koşul "gelen harita bir GİRİŞ
    // yanıtı mı yoksa yerel bir birleştirme mi" ayrımıdır: `avatar` anahtarı
    // hiç yoksa sunucudan taze bilgi gerekiyor demektir. (Ayarlar'daki
    // `{...?oturum.kullanici, 'avatar': yol}` birleştirmelerinde anahtar
    // DAİMA var — orada gereksiz istek atılmaz.)
    if (!k.containsKey('avatar')) unawaited(tazele());
  }

  /// Oturum nesnesini `/profilim` ile tazeler (avatar, kapak, bio, ülke,
  /// testçi bayrağı...).
  ///
  /// --- HANGİ HATAYI ÇÖZÜYOR (7 Ağu 2026) ---
  /// Kullanıcı bildirdi: "yorum yazmadaki sol taraftaki avatarda profil resmim
  /// gözükmüyor". Kök neden `dosyaUrl()` ya da widget DEĞİL, oturum nesnesi:
  ///
  ///   backend/server.js:1888-1891 → POST /auth/giris yanıtı
  ///     const { id, kullanici_adi, email: eposta, misafir } = rows[0];
  ///     res.json({ token: ..., kullanici: { id, kullanici_adi, email, misafir } });
  ///
  /// `avatar` o dört alanın arasında YOK. `Oturum.kullanici` yalnız bu yanıtla
  /// (ve prefs'teki kopyasıyla) doluyordu, `yukle()` da sunucuya hiç sormuyor.
  /// Sonuç: giriş yapan herkesin `kullanici['avatar']` alanı **null**;
  /// `kesfet_akis.dart` yorum satırındaki avatar da `KullaniciAvatari(url: null)`
  /// alıp kişi ikonuna düşüyordu. Avatar oturuma yalnız kullanıcı O CİHAZDA
  /// Ayarlar'dan yeni bir fotoğraf yüklerse giriyordu (`ayarlar.dart:212`) —
  /// yani "fotoğrafım vardı, yeni cihazda kayboldu" tam olarak bu.
  ///
  /// `GET /profilim` avatarı DÖNÜYOR (server.js:3053-3058), yani sunucuya
  /// dokunmadan çözülür — düzeltme tamamen istemcide.
  ///
  /// Sessizce yutulan hata bilinçli: çevrimdışı açılışta eldeki oturumla devam
  /// edilir, kullanıcıya gösterilecek bir eylem yok.
  Future<void> tazele() async {
    if (!Api.girisli) return;
    try {
      final p = await Api.profilim();
      // Birleştirme (atama değil): giriş yanıtındaki `email`/`misafir` gibi
      // `/profilim`de olmayan alanlar korunur.
      kullanici = {...?kullanici, ...p};
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('kullanici', jsonEncode(kullanici));
      notifyListeners();
    } catch (_) {
      // ağ/oturum hatası: eldeki bilgiyle devam
    }
  }

  Future<void> cikis() async {
    await Api.cikis();
    // GOOGLE OTURUMU DA KAPANIR (13 Ağu 2026). Yalnız kendi token'ımızı
    // silmek yetmiyordu: Google tarafındaki oturum açık kalınca `signIn()`
    // önbellekteki hesabı sessizce geri veriyor, hesap seçici HİÇ açılmıyordu
    // ("çıkış yapsam da eski hesabı seçiyor otomatik olarak"). Gerekçe ve
    // `signOut()`/`disconnect()` kararı: google_kapisi.dart.
    await googleOturumunuKapat(web: kIsWeb);
    KitaplikDurumu.temizle(); // başka hesap önceki kitaplığı görmesin
    IcerikDeposu.temizle();
    kullanici = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('kullanici');
    notifyListeners();
  }
}
