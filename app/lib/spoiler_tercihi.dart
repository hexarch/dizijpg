import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SPOILER UYARISI TERCİHİ (1 Eyl 2026 isteği: "bazılarının umrunda olmayan
/// bir durum bu").
///
/// AÇIK (varsayılan): spoiler işaretli gönderiler bugüne kadarki gibi perde
/// arkasında başlar; kullanıcı dokununca açılır.
///
/// KAPALI: perde HİÇ çizilmez — akış kartı, Reels, keşfet karosu, yorum
/// satırları ve profil alıntıları içeriği doğrudan gösterir. Paylaşan kişinin
/// vurduğu "spoiler" işareti VERİDE durur (sunucuya dokunulmaz); yalnız bu
/// cihazdaki GÖSTERİM değişir, tercih geri açılınca perdeler geri gelir.
///
/// Tercih değişince o an ekranda KURULU kartlar perdesini korur (kart durumu
/// `late` alanlarda); ayarlardan dönüp listeye gelinince yeni kurulan kartlar
/// tercihe uyar — VeriTasarrufu ile aynı yaklaşım, ayar ekranından akışa canlı
/// yayın yapmaya değmez.
class SpoilerTercihi {
  static const _anahtar = 'spoiler_uyari';

  /// Spoiler uyarısı (perde) gösterilsin mi. Varsayılan: AÇIK — paylaşanın
  /// işaretine saygı esas, kapatmak bilinçli bir seçim olmalı.
  static final ValueNotifier<bool> uyari = ValueNotifier(true);

  /// main.dart açılışında bir kez çağrılır (VeriTasarrufu.yukle gibi).
  static Future<void> yukle() async {
    final p = await SharedPreferences.getInstance();
    uyari.value = p.getBool(_anahtar) ?? true;
  }

  static Future<void> sec(bool acik) async {
    uyari.value = acik;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_anahtar, acik);
  }

  /// Perde çizilecek mi (gösterim yerlerinin okuduğu tek soru).
  static bool get acik => uyari.value;
}
