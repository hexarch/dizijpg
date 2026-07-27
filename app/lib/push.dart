import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api.dart';
import 'ceviri.dart';

/// Arka planda/kapalıyken gelen mesaj (top-level, ayrı izolatta çalışır).
/// Bildirim payload'ı olduğu için Android otomatik gösterir; ek iş gerekmez.
@pragma('vm:entry-point')
Future<void> pushArkaplan(RemoteMessage mesaj) async {}

final FlutterLocalNotificationsPlugin _yerel =
    FlutterLocalNotificationsPlugin();
const AndroidNotificationChannel _kanal = AndroidNotificationChannel(
  'dizijpg_bildirim',
  'Bildirimler',
  description: 'Takip, beğeni, yanıt, mesaj ve etiket bildirimleri',
  importance: Importance.high,
);
bool _kuruldu = false;

/// Firebase çekirdeğini başlatır + arka plan mesaj işleyicisini kaydeder.
/// main() içinde runApp'ten önce çağrılır. Web'de hiçbir şey yapmaz.
Future<void> pushCekirdek() async {
  if (kIsWeb) return;
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(pushArkaplan);
  } catch (_) {
    // Firebase yoksa/başarısızsa uygulama normal çalışır
  }
}

/// İzin ister, kanalı kurar, FCM token'ını sunucuya kaydeder, dinleyicileri bağlar.
/// Giriş yapıldıktan sonra çağrılır.
Future<void> pushBaslat() async {
  if (kIsWeb) return;
  try {
    final mesajlasma = FirebaseMessaging.instance;
    await mesajlasma.requestPermission(); // Android 13+ bildirim izni

    if (!_kuruldu) {
      await _yerel.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await _yerel
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_kanal);

      // Uygulama açıkken gelen bildirimi yerel bildirim olarak göster
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n == null) return;
        _yerel.show(
          n.hashCode,
          n.title,
          n.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _kanal.id,
              _kanal.name,
              channelDescription: _kanal.description,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      });

      mesajlasma.onTokenRefresh.listen(_tokenGonder);
      _kuruldu = true;
    }

    final token = await mesajlasma.getToken();
    if (token != null) await _tokenGonder(token);
  } catch (_) {
    // izin reddi/hata → sessiz geç
  }
}

Future<void> _tokenGonder(String token) async {
  try {
    await Api.cihazTokenKaydet(
      token,
      Platform.isIOS ? 'ios' : 'android',
      Ceviri.dil.value,
    );
  } catch (_) {}
}

/// Çıkışta token'ı sunucudan siler (bu cihaza artık bildirim gitmesin).
Future<void> pushTokenSil() async {
  if (kIsWeb) return;
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await Api.cihazTokenSil(token);
    await FirebaseMessaging.instance.deleteToken();
  } catch (_) {}
}
