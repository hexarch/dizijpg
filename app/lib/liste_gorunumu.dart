import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kitaplık listelerinin GÖRÜNÜM tercihi: afiş ızgarası mı, satır listesi mi.
///
/// ---------------------------------------------------------------------------
/// NEDEN KALICI (kullanıcı bildirimi, 1 Eyl 2026 — birebir)
/// ---------------------------------------------------------------------------
/// *"liste görünüşüne geçiyorum, uygulamayı yeniden başlatıp listelere
/// girdiğimde yine eski görünüşte oluyor; kullanıcı tercihleri her zaman
/// kaydedilmeli."*
///
/// İlk sürümde bayrak [SiralanabilirPosterIzgarasi]'nın State'indeydi: ekran
/// kapanınca ölüyordu. Bir görünüm SEÇİMİ geçici bir kip değildir — kullanıcı
/// bir kez seçer, hep öyle görmeyi bekler.
///
/// ---------------------------------------------------------------------------
/// NEDEN TEK ANAHTAR, LİSTE BAŞINA DEĞİL
/// ---------------------------------------------------------------------------
/// "Liste görünüşüne geçiyorum" cümlesinin öznesi bir liste değil UYGULAMA:
/// İzliyorum'da satır seçip İzlediğim Filmler'de yine ızgara bulmak aynı
/// şikâyetin devamı olurdu. Altı kitaplık listesi tek tercihi paylaşır.
/// (Karşılaştır: [SiraTercihi] iki AYRI anahtar tutuyor — orada yüzeyler
/// gerçekten farklı: "ne oldu" ile "ne varmış".)
///
/// Depo yalnız CİHAZDA (SharedPreferences): görünüm tercihi sunucuda tutulan
/// bir veri değil, ekran ayarı. Yazma başarısız olursa tercih o oturumda
/// geçerli kalır ve kullanıcıya hata gösterilmez — görünüm zaten değişti.
class ListeGorunumu {
  static const anahtar = 'liste_satir_kipi';

  /// true = satır listesi · false = afiş ızgarası (varsayılan).
  ///
  /// VARSAYILAN IZGARA: 21 Ağu'dan beri var olan görünüm bu ve sürükle-bırak
  /// sıralama yalnız orada çalışıyor; güncelleyen kullanıcıyı habersiz yeni
  /// bir düzene atmak doğru olmazdı.
  static final ValueNotifier<bool> satir = ValueNotifier(false);

  /// Kayıtlı tercihi okur. `main.dart` açılışta bir kez çağırır — ilk kare
  /// DOĞRU görünümle çizilsin, ızgara açılıp bir kare sonra satıra
  /// dönmesin.
  static Future<void> yukle() async {
    try {
      final p = await SharedPreferences.getInstance();
      satir.value = p.getBool(anahtar) ?? false;
    } catch (_) {
      // Okunamazsa varsayılan (ızgara) kalır.
    }
  }

  static Future<void> ayarla(bool satirKipi) async {
    if (satir.value == satirKipi) return;
    satir.value = satirKipi;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(anahtar, satirKipi);
    } catch (_) {
      // Yazılamazsa tercih bu oturumda geçerli olur.
    }
  }
}
