import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../ceviri.dart';

/// Gelen arama bildirimi (Android).
///
/// ## `USE_FULL_SCREEN_INTENT` **İSTENMİYOR** — bu bir eksiklik değil, karar
///
/// Android 14+ hedefleyen uygulamalarda bu izin 22 Ocak 2025'ten beri yalnız
/// arama/alarm uygulamalarına varsayılan veriliyor; diğerleri Play Console
/// beyanı doldurmak zorunda ve ölçütü karşılamayanların **yayını
/// engelleniyor**. dizi.jpg'nin çekirdek işlevi arama değil, dizi takibi:
/// AAB 69 tam bu mantıkla reddedildi ve ardından bir sürüm daha izin yüzünden
/// reddedildi. İkinci kez risk alınmıyor (sözleşme §7.3 + §14.4).
///
/// **Yerine gelen (varsayılan) plan:** `Importance.max` kanal +
/// `AndroidNotificationCategory.call` + `ongoing: true` + tekrarlayan titreşim
/// + zil sesi ses niteliği. Telefon **çalar ve titrer**, bildirim kaydırılarak
/// atılamaz; yalnız kilit ekranını KAPLAMAZ.
///
/// `fullScreenIntent` bayrağı bu dosyada HİÇ verilmiyor (varsayılanı `false`).
/// `test/arama_bildirim_test.dart` bunu kilitliyor: bayrak açılırsa ya da
/// manifeste izin sızarsa test kırmızıya döner.
class AramaBildirim {
  AramaBildirim._();

  static const String kanalId = 'dizijpg_arama';
  static const String cevaplaEylemi = 'arama_cevapla';
  static const String reddetEylemi = 'arama_reddet';

  /// Gelen aramaların bildirim kimliği — tek arama olabileceği için sabit.
  static const int bildirimId = 90210;

  /// Tekrarlayan titreşim: bekle-titre-bekle-titre… Telefonu çalıyormuş gibi
  /// hissettirir; tek darbe bildirim gibi hissettirirdi.
  static final Int64List titresim = Int64List.fromList([
    0,
    800,
    600,
    800,
    600,
    800,
  ]);

  static AndroidNotificationChannel kanal() => AndroidNotificationChannel(
    kanalId,
    'Gelen aramalar'.c,
    description: 'Sesli ve görüntülü arama bildirimleri'.c,
    importance: Importance.max,
    enableVibration: true,
    vibrationPattern: titresim,
    // Zil sesi ses niteliği: sistem bunu bildirim değil ÇAĞRI sesi olarak
    // yönlendirir (sessiz moddaki davranış ve ses düzeyi kanalı farklıdır).
    audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
  );

  /// Bildirim ayrıntıları.
  ///
  /// `fullScreenIntent` BİLEREK verilmiyor — varsayılanı `false` ve öyle
  /// kalmalı (yukarıdaki karar).
  static AndroidNotificationDetails ayrinti() => AndroidNotificationDetails(
    kanalId,
    'Gelen aramalar'.c,
    channelDescription: 'Sesli ve görüntülü arama bildirimleri'.c,
    importance: Importance.max,
    priority: Priority.max,
    category: AndroidNotificationCategory.call,
    // Kaydırılarak atılamaz: çalan telefon yanlışlıkla süpürülmemeli.
    ongoing: true,
    autoCancel: false,
    icon: '@mipmap/ic_launcher',
    enableVibration: true,
    vibrationPattern: titresim,
    audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
    // METİN ETİKETLİ eylemler: ikon-tek düğme yasak (`ui-ux-pro-max`
    // öncelik 1). Android bildirim eylemi dokunma hedefini kendisi
    // ≥48 dp yapar.
    actions: <AndroidNotificationAction>[
      AndroidNotificationAction(
        reddetEylemi,
        'Reddet'.c,
        cancelNotification: true,
      ),
      AndroidNotificationAction(
        cevaplaEylemi,
        'Cevapla'.c,
        cancelNotification: true,
      ),
    ],
  );

  /// FCM veri paketinden ('tur' == 'arama') bildirimi çizer.
  static Future<void> goster(
    FlutterLocalNotificationsPlugin yerel,
    Map<String, dynamic> veri,
  ) async {
    if (kIsWeb) return;
    await yerel
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(kanal());
    final ad = veri['ad'] as String? ?? '';
    final goruntulu = veri['arama_turu'] == 'goruntu';
    await yerel.show(
      bildirimId,
      veri['baslik'] as String? ?? ad,
      // Sunucunun `PUSH_SABLON`dan gelen 16 dilli gövdesi; yoksa kendi
      // metnimize düşülür (boş bildirim gösterilmez).
      (veri['metin'] as String?)?.isNotEmpty == true
          ? veri['metin'] as String
          : (goruntulu ? 'Görüntülü arama'.c : 'Sesli arama'.c),
      NotificationDetails(android: ayrinti()),
      // `arama_id` payload'a KONUR: bildirimden "Reddet"e basıldığında
      // `POST /arama/yanit` bunsuz atılamaz ve arayan 45 sn boşuna çalar.
      payload: jsonEncode({
        'tur': 'arama',
        'arama_id': veri['arama_id'] ?? '',
        'ad': ad,
      }),
    );
  }

  static Future<void> kapat(FlutterLocalNotificationsPlugin yerel) async {
    if (kIsWeb) return;
    try {
      await yerel.cancel(bildirimId);
    } catch (_) {}
  }
}
