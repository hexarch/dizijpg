import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ceviri.dart';
import 'puan_favori_deposu.dart';
import 'tema.dart';

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

/// AppBar'a konan GÖRÜNÜM ANAHTARI — afiş ızgarası ⇄ satır listesi.
///
/// NEDEN AYAR ÇARKININ İÇİNDE DEĞİL (kullanıcı isteği, 1 Eyl 2026 — birebir):
/// *"görünüm değiştirmeyi ayarlar butonunun içine aldık ya, onu kaldır,
/// ayarların yanına ikon olarak koy; afişteyken liste ikonu, listedeyken afiş
/// ikonu olsun."*
///
/// İlk sürümde anahtar süzgeç şeridinin içindeydi (aramanın yanında), yani
/// görünümü değiştirmek için önce SIRALAMA kipini açmak gerekiyordu. Görünüm
/// sıralamanın alt başlığı değil; iki ayrı iş iki ayrı düğme.
///
/// İKON GİDİLECEK YERİ ANLATIR, BULUNULAN YERİ DEĞİL (kullanıcının kuralı):
/// ızgaradayken liste ikonu ("listeye geç"), listedeyken ızgara ikonu.
/// Aynı gelenek [SiraSecici]'nin tersidir ve bilinçli: orada tek düğme bir
/// MENÜ açar (seçili modu göstermesi gerekir), burada düğme doğrudan
/// KARŞI moda geçirir.
class ListeGorunumuDugmesi extends StatelessWidget {
  const ListeGorunumuDugmesi({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: ListeGorunumu.satir,
    builder: (context, satirKipi, _) => IconButton(
      key: const Key('satir-kipi'),
      tooltip: satirKipi ? 'Afiş görünümü'.c : 'Satır görünümü'.c,
      onPressed: () {
        ListeGorunumu.ayarla(!satirKipi);
        // Satıra geçerken puan/kalp/tarih/emoji verisi gerekir. Liste widget'ı
        // da mount olurken çekiyor; burada da çağırmak, listenin HİÇ
        // çizilmediği durumlarda (hata/boş ekran) düğmenin sessiz kalmasını
        // önler. `yukle` kendini yeniden girişe karşı koruyor.
        if (!satirKipi) PuanFavoriDeposu.yukle();
      },
      icon: Icon(
        satirKipi ? Icons.grid_view : Icons.view_list,
        color: DiziRenkler.sariMetin,
      ),
    ),
  );
}
