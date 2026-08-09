// GELEN ARAMA BİLDİRİMİ — mağaza riski kilidi.
//
// EN KRİTİK MADDE: `USE_FULL_SCREEN_INTENT` İSTENMEYECEK.
// AAB 69 "temel işlevi bu olmayan uygulamalar" gerekçesiyle reddedildi ve
// ardından bir sürüm daha izin yüzünden reddedildi. Bu testler hem manifesti
// hem de `fullScreenIntent` bayrağını kilitliyor: birisi "kilit ekranında
// çıkmıyor" diye ekleyecek olursa test kırmızıya döner ve NEDENİNİ okur.
//
// Kalan maddeler sözleşme §7.3/§14.4'ten: Importance.MAX, CATEGORY_CALL,
// setOngoing, tekrarlayan titreşim, METİN ETİKETLİ Cevapla/Reddet.
import 'dart:io';

import 'package:dizijpg/gorusme/arama_bildirim.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

const _manifest = 'android/app/src/main/AndroidManifest.xml';

void main() {
  group('Play mağaza riski', () {
    test('manifestte USE_FULL_SCREEN_INTENT İZNİ YOK', () {
      final metin = File(_manifest).readAsStringSync();
      // Yorum bloğunda izin ADI geçiyor (neden eklenmediğini anlatıyor);
      // asıl aranan şey bir <uses-permission> SATIRI olması.
      final izinler = RegExp(
        r'<uses-permission[^>]*android:name="([^"]+)"',
      ).allMatches(metin).map((m) => m.group(1)!).toList();
      expect(
        izinler,
        isNot(contains('android.permission.USE_FULL_SCREEN_INTENT')),
        reason: 'Play bu izin yüzünden iki sürümü reddetti; geri eklenmeyecek',
      );
    });

    test('bildirim ayrıntısında fullScreenIntent KAPALI', () {
      expect(ayrintiFullScreen(), isFalse);
    });

    test('görüntülü arama için CAMERA izni VAR', () {
      final metin = File(_manifest).readAsStringSync();
      expect(metin.contains('android.permission.CAMERA'), isTrue);
      // Kamerası olmayan cihaz uygulamayı kuramaz olmasın.
      expect(
        metin.contains('android:name="android.hardware.camera"') &&
            metin.contains('android:required="false"'),
        isTrue,
        reason: 'kamera ZORUNLU donanım olarak işaretlenmemeli',
      );
    });

    test('mikrofon izni zaten var, yenisi eklenmedi', () {
      final metin = File(_manifest).readAsStringSync();
      expect(metin.contains('android.permission.RECORD_AUDIO'), isTrue);
    });

    test('istemediğimiz izinler manifeste sızmadı', () {
      final metin = File(_manifest).readAsStringSync();
      final izinler = RegExp(
        r'<uses-permission[^>]*android:name="([^"]+)"',
      ).allMatches(metin).map((m) => m.group(1)!).toSet();
      // Bluetooth SCO yönlendirmesi bu turda YOK; izin taşımak mağaza
      // incelemesinde açıklanacak boş bir yüzeydir.
      expect(izinler, isNot(contains('android.permission.BLUETOOTH_CONNECT')));
      // Ön plan servisi ayrı bir Play beyanı (gösterim videosu) istiyor.
      expect(
        izinler.where((i) => i.contains('FOREGROUND_SERVICE')),
        isEmpty,
        reason: 'ön plan servisi F2; beyanla birlikte gelecek',
      );
    });
  });

  group('kanal ve bildirim biçimi', () {
    test('kanal: dizijpg_arama, Importance.max, titreşimli, zil sesi', () {
      final k = AramaBildirim.kanal();
      expect(k.id, 'dizijpg_arama');
      expect(k.importance, Importance.max);
      expect(k.enableVibration, isTrue);
      expect(k.vibrationPattern, isNotNull);
      expect(k.audioAttributesUsage, AudioAttributesUsage.notificationRingtone);
    });

    test('bildirim: CATEGORY_CALL + ongoing + kaydırılamaz', () {
      final a = AramaBildirim.ayrinti();
      expect(a.category, AndroidNotificationCategory.call);
      expect(a.importance, Importance.max);
      expect(a.priority, Priority.max);
      expect(a.ongoing, isTrue, reason: 'çalan telefon süpürülmemeli');
      expect(a.autoCancel, isFalse);
    });

    test('İKİ EYLEM VAR ve İKİSİ DE METİN ETİKETLİ (ikon-tek yasak)', () {
      final a = AramaBildirim.ayrinti();
      expect(a.actions, isNotNull);
      expect(a.actions!.length, 2);
      final idler = a.actions!.map((e) => e.id).toList();
      expect(
        idler,
        containsAll([AramaBildirim.cevaplaEylemi, AramaBildirim.reddetEylemi]),
      );
      for (final e in a.actions!) {
        expect(e.title, isNotEmpty, reason: '${e.id} etiketsiz');
      }
    });

    test('titreşim TEKRARLAYAN (tek darbe değil)', () {
      // Tek darbe "bildirim" hissi verir; çalan telefon tekrar etmeli.
      expect(AramaBildirim.titresim.length, greaterThanOrEqualTo(4));
    });
  });
}

/// `AndroidNotificationDetails.fullScreenIntent` değerini okur.
bool ayrintiFullScreen() => AramaBildirim.ayrinti().fullScreenIntent;
