import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// dizi.jpg API istemcisi. SSL Faz 8'de eklenecek; şimdilik IP üzerinden.
const String apiTaban = 'http://154.53.161.139:8500';

/// TMDB görsel adresleri
String? posterUrl(String? yol, {String boyut = 'w342'}) =>
    yol == null ? null : 'https://image.tmdb.org/t/p/$boyut$yol';

class ApiHata implements Exception {
  final String mesaj;
  ApiHata(this.mesaj);
  @override
  String toString() => mesaj;
}

class Api {
  static String? _token;

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
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static Future<dynamic> get(String yol) async {
    final cevap = await http
        .get(Uri.parse('$apiTaban$yol'), headers: _basliklar)
        .timeout(const Duration(seconds: 20));
    return _isle(cevap);
  }

  static Future<dynamic> post(String yol, Map<String, dynamic> govde) async {
    final cevap = await http
        .post(Uri.parse('$apiTaban$yol'),
            headers: _basliklar, body: jsonEncode(govde))
        .timeout(const Duration(seconds: 20));
    return _isle(cevap);
  }

  static Future<dynamic> delete(String yol) async {
    final cevap = await http
        .delete(Uri.parse('$apiTaban$yol'), headers: _basliklar)
        .timeout(const Duration(seconds: 20));
    return _isle(cevap);
  }

  static dynamic _isle(http.Response cevap) {
    final govde = cevap.body.isEmpty ? {} : jsonDecode(cevap.body);
    if (cevap.statusCode >= 400) {
      throw ApiHata(govde is Map && govde['hata'] != null
          ? govde['hata'] as String
          : 'Sunucu hatası (${cevap.statusCode})');
    }
    return govde;
  }

  // ---- oturum ----
  static Future<Map<String, dynamic>> kayit(
      String email, String kullaniciAdi, String sifre) async {
    final d = await post('/auth/kayit',
        {'email': email, 'kullanici_adi': kullaniciAdi, 'sifre': sifre});
    await _tokenKaydet(d['token'] as String);
    return d['kullanici'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> giris(String email, String sifre) async {
    final d = await post('/auth/giris', {'email': email, 'sifre': sifre});
    await _tokenKaydet(d['token'] as String);
    return d['kullanici'] as Map<String, dynamic>;
  }

  static Future<void> cikis() => _tokenKaydet(null);
}

/// Oturum durumu (giriş yapan kullanıcı bilgisi).
class Oturum extends ChangeNotifier {
  Map<String, dynamic>? kullanici;

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
    notifyListeners();
  }

  Future<void> cikis() async {
    await Api.cikis();
    kullanici = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('kullanici');
    notifyListeners();
  }
}
