import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'ceviri.dart';
import 'icerik_deposu.dart';
import 'kitaplik_durumu.dart';
import 'onbellek.dart';

/// dizi.jpg API istemcisi (nginx + Cloudflare arkasında, TLS'li).
const String apiTaban = 'https://dizijpg.com/api';

/// TMDB görsel adresleri
String? posterUrl(String? yol, {String boyut = 'w342'}) =>
    yol == null ? null : 'https://image.tmdb.org/t/p/$boyut$yol';

/// Sunucudaki dosya yolları (avatar, yorum medyası) → tam URL
String? dosyaUrl(String? yol) =>
    yol == null ? null : (yol.startsWith('http') ? yol : '$apiTaban$yol');

class ApiHata implements Exception {
  final String mesaj;
  ApiHata(this.mesaj);
  @override
  String toString() => mesaj;
}

class Api {
  static String? _token;

  /// TEK, kalıcı istemci: bağlantı (TCP+TLS) yeniden kullanılır. Her çağrıda
  /// yeni http.get kullanılsaydı her istekte TLS el sıkışması tekrarlanır ve
  /// istek başına ~130ms boşa giderdi.
  static final http.Client _istemci = http.Client();

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
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  /// Katalog (TMDB) isteklerine dili ADRESE ekler: Cloudflare önbelleği
  /// yalnız URL'e bakar, başlığa değil — dil adreste olmasaydı kenar
  /// önbelleği bir dilin yanıtını başka dildeki kullanıcıya verirdi.
  static String _dilliYol(String yol) {
    if (!yol.startsWith('/tmdb/')) return yol;
    final ayirac = yol.contains('?') ? '&' : '?';
    return '$yol${ayirac}dil=${Ceviri.dil.value}';
  }

  static Future<dynamic> get(String yol) async {
    final cevap = await _istemci
        .get(Uri.parse('$apiTaban${_dilliYol(yol)}'), headers: _basliklar)
        .timeout(const Duration(seconds: 20));
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
      throw ApiHata(
        govde is Map && govde['hata'] != null
            ? govde['hata'] as String
            : 'Sunucu hatası ({})'.cf([cevap.statusCode]),
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

  static Future<Map<String, dynamic>> giris(String email, String sifre) async {
    final d = await post('/auth/giris', {'email': email, 'sifre': sifre});
    await _tokenKaydet(d['token'] as String);
    return d['kullanici'] as Map<String, dynamic>;
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
  static Future<void> cihazTokenKaydet(
    String token,
    String platform,
    String dil,
  ) => post('/cihaz-token', {'token': token, 'platform': platform, 'dil': dil});

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
  static const surum = '1.12.6+49';

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
  static Future<Map<String, dynamic>> profilim() async =>
      await get('/profilim') as Map<String, dynamic>;

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

  static Future<Map<String, dynamic>> takipToggle(String kullaniciAdi) async =>
      await post('/takip/$kullaniciAdi', {}) as Map<String, dynamic>;

  static Future<List<dynamic>> takipciler(String kullaniciAdi) async =>
      (await get('/takipciler/$kullaniciAdi'))['kullanicilar'] as List<dynamic>;

  static Future<List<dynamic>> takipEdilenler(String kullaniciAdi) async =>
      (await get('/takipedilenler/$kullaniciAdi'))['kullanicilar']
          as List<dynamic>;

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
  }

  Future<void> cikis() async {
    await Api.cikis();
    KitaplikDurumu.temizle(); // başka hesap önceki kitaplığı görmesin
    IcerikDeposu.temizle();
    kullanici = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('kullanici');
    notifyListeners();
  }
}
