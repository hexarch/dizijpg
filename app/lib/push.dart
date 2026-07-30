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

  // Konuşma geçmişini yükle-ekle-kırp; başlık/avatar meta'sını sakla ki
  // bildirimden yanıt verilince aynı bildirim yeniden çizilebilsin.
  // reload: başka izolat yazmış olabilir, bayat önbelleği tazele.
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  await _gecmiseEkle(prefs, ad, metin, benim: false);
  await prefs.setString(
    'bildirim_meta_$ad',
    jsonEncode({'baslik': baslik, 'avatar': veri['avatar'] ?? ''}),
  );
  await bildirimCiz(ad);

  // Gönderen çift tik görsün: mesajlar bu cihaza İLETİLDİ
  try {
    if (!Api.girisli) await Api.tokenYukle();
    await Api.post('/mesajlar/iletildi', {'kullanici_adi': ad});
  } catch (_) {}
}

/// Konuşma geçmişine bir satır ekler (kişi başına son 10 tutulur).
Future<void> _gecmiseEkle(
  SharedPreferences prefs,
  String ad,
  String metin, {
  required bool benim,
}) async {
  final anahtar = 'bildirim_mesajlari_$ad';
  final liste = prefs.getStringList(anahtar) ?? <String>[];
  liste.add(
    jsonEncode({
      'm': metin,
      't': DateTime.now().millisecondsSinceEpoch,
      if (benim) 'b': 1,
    }),
  );
  while (liste.length > 10) {
    liste.removeAt(0);
  }
  await prefs.setStringList(anahtar, liste);
}

/// Kayıtlı meta + geçmişten kişinin bildirimini (yeniden) çizer.
/// Hem yeni mesaj gelince hem bildirimden yanıt verilince kullanılır.
Future<void> bildirimCiz(String ad) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final metaHam = prefs.getString('bildirim_meta_$ad');
  final gecmis = <Map<String, dynamic>>[
    for (final e in prefs.getStringList('bildirim_mesajlari_$ad') ?? <String>[])
      jsonDecode(e) as Map<String, dynamic>,
  ];
  if (metaHam == null || gecmis.isEmpty) return;
  final meta = jsonDecode(metaHam) as Map<String, dynamic>;
  final baslik = meta['baslik'] as String? ?? 'dizi.jpg';

  // Gönderenin avatarı: sohbet balonundaki kişi ikonu + büyük ikon
  // (indirilemezse ikonsuz devam)
  ByteArrayAndroidIcon? kisiIkon;
  AndroidBitmap<Object>? buyukIkon;
  final avatarYol = meta['avatar'] as String? ?? '';
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

  const ben = Person(name: 'Sen', key: 'ben');
  final gonderen = Person(name: baslik, key: ad, icon: kisiIkon);
  await _yerel.show(
    // Kişi başına tek bildirim; içeriği MessagingStyle ile birikir
    ad.hashCode,
    baslik,
    gecmis.last['m'] as String,
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
        // WhatsApp tarzı satır içi yanıt: klavye bildirimde açılır
        actions: [
          AndroidNotificationAction(
            'yanitla',
            'Yanıtla'.c,
            inputs: [
              AndroidNotificationActionInput(label: 'Mesajını yaz...'.c),
            ],
            cancelNotification: false,
          ),
        ],
        styleInformation: MessagingStyleInformation(
          ben,
          messages: [
            for (final e in gecmis)
              Message(
                e['m'] as String,
                DateTime.fromMillisecondsSinceEpoch(e['t'] as int),
                e['b'] == 1 ? ben : gonderen,
              ),
          ],
        ),
      ),
    ),
    payload: jsonEncode({'tur': 'mesaj', 'ad': ad}),
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

/// Bildirimdeki "Yanıtla" girişini işler: mesajı gönderir, kendi yanıtını
/// bildirimdeki konuşmaya ekler. İşlendiyse true döner.
/// Hem ön plandaki hem arka plandaki (ayrı izolat) dokunuşlarda kullanılır.
Future<bool> _yanitIsle(NotificationResponse yanit) async {
  if (yanit.actionId != 'yanitla') return false;
  final metin = yanit.input?.trim() ?? '';
  try {
    final veri = jsonDecode(yanit.payload ?? '{}') as Map<String, dynamic>;
    final ad = veri['ad'] as String? ?? '';
    if (ad.isEmpty || metin.isEmpty) return true;
    if (!Api.girisli) await Api.tokenYukle();
    await Api.post('/mesajlar', {'kullanici_adi': ad, 'metin': metin});
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await _gecmiseEkle(prefs, ad, metin, benim: true);
    await bildirimCiz(ad);
  } catch (_) {}
  return true;
}

/// Bildirimden yanıt, uygulama KAPALIYKEN ayrı izolatta gelir (top-level).
@pragma('vm:entry-point')
Future<void> bildirimYanitArkaplan(NotificationResponse yanit) async {
  try {
    DartPluginRegistrant.ensureInitialized();
    await _yerel.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _yanitIsle(yanit);
  } catch (_) {}
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
        // Yanıtla aksiyonuysa mesajı gönder; değilse ilgili sayfaya git
        onDidReceiveNotificationResponse: (yanit) async {
          if (await _yanitIsle(yanit)) return;
          _payloadIleGit(yanit.payload);
        },
        // Uygulama kapalıyken bildirimden yanıt (ayrı izolat)
        onDidReceiveBackgroundNotificationResponse: bildirimYanitArkaplan,
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
