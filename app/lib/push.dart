import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'ceviri.dart';
import 'yonlendirme.dart';

final FlutterLocalNotificationsPlugin _yerel =
    FlutterLocalNotificationsPlugin();
const AndroidNotificationChannel _kanal = AndroidNotificationChannel(
  'dizijpg_bildirim',
  'Bildirimler',
  description: 'Takip, beğeni, yanıt, mesaj ve etiket bildirimleri',
  importance: Importance.high,
);
bool _kuruldu = false;

// Sohbet bildirimleri tek grupta toplansın (WhatsApp tarzı demet)
const String _mesajGrubu = 'dizijpg_mesajlar';

/// Mesaj bildirimi (veri-mesajı): gönderenin avatarı + mesaj içeriğiyle
/// yerel bildirim basar. Aynı gönderenin okunmamış mesajları tek bildirimde
/// BİRİKİR (MessagingStyle, genişletilebilir — WhatsApp tarzı); geçmiş
/// SharedPreferences'ta tutulur ki arka plan izolatı da ekleyebilsin.
/// Ön planda ve arka plan izolatında ortak kullanılır.
Future<void> mesajBildirimiGoster(Map<String, dynamic> veri) async {
  final baslik = veri['baslik'] as String? ?? 'dizi.jpg';
  final metin = veri['metin'] as String? ?? '';
  final ad = veri['ad'] as String? ?? '';
  if (metin.isEmpty) return;

  // Konuşma geçmişini yükle-ekle-kırp (kişi başına son 10 mesaj).
  // reload: arka plan izolatı yazmış olabilir, bayat önbelleği tazele.
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final anahtar = 'bildirim_mesajlari_$ad';
  final gecmis = <Map<String, dynamic>>[
    for (final e in prefs.getStringList(anahtar) ?? <String>[])
      jsonDecode(e) as Map<String, dynamic>,
  ];
  gecmis.add({'m': metin, 't': DateTime.now().millisecondsSinceEpoch});
  while (gecmis.length > 10) {
    gecmis.removeAt(0);
  }
  await prefs.setStringList(anahtar, [for (final e in gecmis) jsonEncode(e)]);

  // Gönderenin avatarı: sohbet balonundaki kişi ikonu + büyük ikon
  // (indirilemezse ikonsuz devam)
  ByteArrayAndroidIcon? kisiIkon;
  AndroidBitmap<Object>? buyukIkon;
  final avatarYol = veri['avatar'] as String? ?? '';
  if (avatarYol.isNotEmpty && !avatarYol.endsWith('.gif')) {
    try {
      final y = await http
          .get(Uri.parse(dosyaUrl(avatarYol)!))
          .timeout(const Duration(seconds: 5));
      if (y.statusCode == 200) {
        kisiIkon = ByteArrayAndroidIcon(y.bodyBytes);
        buyukIkon = ByteArrayAndroidBitmap(y.bodyBytes);
      }
    } catch (_) {}
  }

  final gonderen = Person(name: baslik, key: ad, icon: kisiIkon);
  await _yerel.show(
    // Kişi başına tek bildirim; içeriği MessagingStyle ile birikir
    ad.hashCode,
    baslik,
    metin,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _kanal.id,
        _kanal.name,
        channelDescription: _kanal.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        largeIcon: buyukIkon,
        groupKey: _mesajGrubu,
        styleInformation: MessagingStyleInformation(
          const Person(name: 'Sen', key: 'ben'),
          messages: [
            for (final e in gecmis)
              Message(
                e['m'] as String,
                DateTime.fromMillisecondsSinceEpoch(e['t'] as int),
                gonderen,
              ),
          ],
        ),
      ),
    ),
    payload: jsonEncode({'tur': veri['tur'], 'ad': ad}),
  );
  // Özet bildirim: birden çok sohbet varsa Android tek demette toplar
  await _yerel.show(
    0,
    'dizi.jpg',
    null,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _kanal.id,
        _kanal.name,
        channelDescription: _kanal.description,
        icon: '@mipmap/ic_launcher',
        groupKey: _mesajGrubu,
        setAsGroupSummary: true,
        styleInformation: const InboxStyleInformation([]),
      ),
    ),
  );
}

/// Sohbet açılınca o kişinin biriken bildirim geçmişini sıfırlar ve
/// bildirimini kapatır (bir sonraki mesaj yeni listeyle başlar).
Future<void> mesajBildirimleriniTemizle(String ad) async {
  if (kIsWeb) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bildirim_mesajlari_$ad');
    await _yerel.cancel(ad.hashCode);
  } catch (_) {}
}

/// Arka planda/kapalıyken gelen mesaj (top-level, ayrı izolatta çalışır).
/// Bildirim payload'lı türleri Android kendisi gösterir; veri-mesajı olan
/// 'mesaj' türünü burada avatarlı yerel bildirime çeviririz.
@pragma('vm:entry-point')
Future<void> pushArkaplan(RemoteMessage mesaj) async {
  if (mesaj.data['tur'] != 'mesaj') return;
  try {
    DartPluginRegistrant.ensureInitialized();
    await _yerel.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await mesajBildirimiGoster(mesaj.data);
  } catch (_) {}
}

/// Bildirim verisinden hedefe gider (dokunma / açılış).
void _bildirimVerisiyleGit(Map<String, dynamic> veri) {
  final tur = veri['tur'] as String? ?? '';
  final ad = veri['ad'] as String? ?? '';
  switch (tur) {
    case 'mesaj':
      if (ad.isNotEmpty) rotayaGit('/sohbet/$ad');
    case 'takip':
      if (ad.isNotEmpty) rotayaGit('/kullanici/$ad');
    case 'begeni' || 'yanit' || 'etiket':
      // yorum_id varsa doğrudan o gönderiye; yoksa bildirim listesine
      final yorumId = veri['yorum_id'] as String?;
      rotayaGit(
        (yorumId != null && yorumId.isNotEmpty)
            ? '/gonderi/$yorumId'
            : '/bildirimler',
      );
  }
}

void _payloadIleGit(String? payload) {
  if (payload == null || payload.isEmpty) return;
  try {
    _bildirimVerisiyleGit(jsonDecode(payload) as Map<String, dynamic>);
  } catch (_) {}
}

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
        // Yerel bildirime dokununca ilgili sayfaya git
        onDidReceiveNotificationResponse: (yanit) =>
            _payloadIleGit(yanit.payload),
      );
      await _yerel
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_kanal);

      // Uygulama açıkken gelen bildirim
      FirebaseMessaging.onMessage.listen((m) {
        if (m.data['tur'] == 'mesaj') {
          // Zaten o sohbetteyse bildirim basma (5 sn'lik poll gösterir)
          final ad = m.data['ad'] as String? ?? '';
          final yol =
              sonYonlendirici?.routerDelegate.currentConfiguration.uri.path;
          if (yol == '/sohbet/$ad') return;
          mesajBildirimiGoster(m.data);
          return;
        }
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
          payload: jsonEncode({'tur': m.data['tur'], 'ad': m.data['ad']}),
        );
      });

      // Arka plandayken sistem bildirimine dokunuldu (FCM notification türleri)
      FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => _bildirimVerisiyleGit(m.data),
      );
      // Uygulama bildirimle açıldıysa hedefe git (yönlendirici kurulduktan sonra)
      final ilkMesaj = await mesajlasma.getInitialMessage();
      final ilkYerel = await _yerel.getNotificationAppLaunchDetails();
      if (ilkMesaj != null || ilkYerel?.didNotificationLaunchApp == true) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (ilkMesaj != null) {
            _bildirimVerisiyleGit(ilkMesaj.data);
          } else {
            _payloadIleGit(ilkYerel?.notificationResponse?.payload);
          }
        });
      }

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
