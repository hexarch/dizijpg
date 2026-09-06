import 'package:flutter/foundation.dart';

import 'belge_basligi.dart';
import 'ceviri.dart';
import 'diller/seo_basliklari.dart';

/// Tarayıcı sekmesinde/geçmişinde görünen sayfa başlığı (`document.title`).
///
/// NEDEN VAR (6 Eylül 2026, SEO danışmanının bulgusu): SSR'nin bota bastığı
/// başlık dile ve hedef kelimeye göre yazılmıştı; insanın gördüğü Flutter
/// kabuğunda ise 46 dilde de "dizi.jpg" yazıyordu. Kabuk HTML'i artık dil
/// başına doğru başlıkla servis ediliyor (`araclar/web_dil_kabugu.mjs`); bu
/// sınıf, uygulama içinde gezinirken başlığın SAYFAYA ÖZEL kalmasını sağlar.
///
/// NEDEN `MaterialApp.title` DEĞİL: o kanal bu uygulamada `document.title`a
/// hiç ulaşmıyor — canlıda ölçüldü (bkz. `belge_basligi_web.dart`). Başlık
/// doğrudan DOM'a yazılır.
///
/// NEDEN ADRESE GÖRE HARİTA, EKRAN DURUMU DEĞİL: başlığı `initState`te yazıp
/// `dispose`ta geri almak A → B → geri akışında bozulur (B kapanınca A yeniden
/// build edilmediği için başlık ana sayfaya düşerdi). Burada ad ROTA
/// ADRESİNE yazılır; geri dönüşte doğru ad ZATEN haritadadır.
class SayfaBasligi {
  SayfaBasligi._();

  /// Rota yolu -> sayfanın adı (marka soneki hariç).
  static final Map<String, String> _adlar = {};

  /// Şu an görünen rota yolu — dil öneki AYRILMIŞ hâli (`/icerik/tv/2098`).
  /// `main.dart` yönlendiriciyi dinleyip günceller.
  static String _yol = '/';

  /// Haritanın üst sınırı: uzun bir gezinti oturumunda sınırsız büyümesin.
  /// Değerler kısa dizgeler; 128 kayıt birkaç KB.
  static const _sinir = 128;

  /// Görünen rota değişti: başlığı o adrese göre yeniden yaz.
  static void rota(String yol) {
    _yol = yol;
    _uygula();
  }

  /// [yol] adresindeki sayfanın adını kaydeder; o adres GÖRÜNÜR durumdaysa
  /// başlığı hemen tazeler. Ekranlar veriyi ağdan geç aldığı için yazma anı
  /// rota değişiminden sonradır.
  static void yaz(String yol, String? ad) {
    final temiz = ad?.trim();
    if (temiz == null || temiz.isEmpty) return;
    if (_adlar[yol] == temiz) return;
    if (_adlar.length >= _sinir) _adlar.remove(_adlar.keys.first);
    _adlar[yol] = temiz;
    if (yol == _yol) _uygula();
  }

  /// [yol] için bilinen ad; yoksa null.
  static String? oku(String yol) => _adlar[yol];

  static void _uygula() => belgeBasligiYaz(web(Ceviri.dil.value, _yol));

  /// Web'de basılacak `document.title`. Saf işlev — testler `kIsWeb`e bağlı
  /// kalmasın diye DOM'a dokunmaz.
  static String web(String dil, String yol) {
    final ad = _adlar[yol];
    if (ad == null) return seoAnaBaslik(dil);
    return '$ad | dizi.jpg';
  }

  /// Testler için.
  @visibleForTesting
  static void temizle() {
    _adlar.clear();
    _yol = '/';
  }
}
