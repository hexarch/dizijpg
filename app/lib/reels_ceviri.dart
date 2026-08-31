import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reels'teki OTOMATİK ÇEVİRİ anahtarının kipi (31 Ağu 2026 isteği, aynı gün
/// netleşti: "3 modu olsun; gri kapalı, beyaz orijinal, sarı kullanıcının
/// dili").
///
///  * [ceviri]   — SARI ikon: gönderi metni ve video altyazısı okuyanın
///                 dilinde (sunucunun bugünkü varsayılan davranışı).
///  * [orijinal] — BEYAZ ikon: metinler kaynak dilinde; altyazı da kaynak
///                 dildeki cümleyi basar (`o` alanı, yoksa eldeki metin).
///  * [kapali]   — GRİ ikon: video altyazısı HİÇ çizilmez ("çeviri kapat
///                 demek alttaki yazıyı kapat demek"); gönderi metni
///                 orijinal dilinde kalır (gönderinin kendisi gizlenmez —
///                 yazılı gönderide bomboş ekran olurdu).
enum ReelsCeviriKip { ceviri, orijinal, kapali }

/// Tercihin saklandığı/dinlendiği tek yer ([VeriTasarrufu] kalıbı; cihazda
/// kalıcı, main.dart'ta yüklenir).
class ReelsCeviri {
  static const _anahtar = 'reels_ceviri_kip';

  /// Eski (iki durumlu) sürümün anahtarı — bir kez okunup taşınır.
  static const _eskiAnahtar = 'reels_otomatik_ceviri';

  static final ValueNotifier<ReelsCeviriKip> kip = ValueNotifier(
    ReelsCeviriKip.ceviri,
  );

  /// Dokunma sırası: sarı → beyaz → gri → SARI... Kapalıdan sonra bilerek
  /// çeviriye dönülür ("sarı kapalıdan sonra gelsin ki kullanıcı şaşırmasın").
  static ReelsCeviriKip sonraki(ReelsCeviriKip k) => switch (k) {
    ReelsCeviriKip.ceviri => ReelsCeviriKip.orijinal,
    ReelsCeviriKip.orijinal => ReelsCeviriKip.kapali,
    ReelsCeviriKip.kapali => ReelsCeviriKip.ceviri,
  };

  static ReelsCeviriKip _coz(String? ad) => switch (ad) {
    'orijinal' => ReelsCeviriKip.orijinal,
    'kapali' => ReelsCeviriKip.kapali,
    _ => ReelsCeviriKip.ceviri,
  };

  static Future<void> yukle() async {
    final p = await SharedPreferences.getInstance();
    final ham = p.getString(_anahtar);
    if (ham != null) {
      kip.value = _coz(ham);
      return;
    }
    // Eski iki durumlu tercihten taşı: kapalıydıysa kapalı kalsın.
    if (p.getBool(_eskiAnahtar) == false) kip.value = ReelsCeviriKip.kapali;
  }

  static Future<void> sec(ReelsCeviriKip v) async {
    kip.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setString(_anahtar, v.name);
  }
}
