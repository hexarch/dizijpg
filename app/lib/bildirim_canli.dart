// WEBDE ANLIK BİLDİRİM KAYNAĞI — `/bildirimler/canli` yoklaması.
//
// ===========================================================================
// KİMLER YOKLAR: WEB + (PUSH'U ÇALIŞMAYAN) iOS
// ===========================================================================
// Android'de kaynak FCM'dir: uygulama ön plandayken `onMessage` tetiklenir ve
// pencereyi o çizer (push.dart). Tarayıcıda FCM YOK — yoklama olmadan
// "uygulamada gezerken mesaj gelince yukarıda pencere" web'de HİÇ çalışmazdı.
//
// iOS DA YOKLAR (13 Eyl 2026): kullanıcı "apple'da bildirimler gitmiyor" diye
// bildirdi, ölçüm `cihaz_tokenlari`nde **714 android / 0 ios** satır gösterdi —
// iOS cihazlar FCM jetonu kaydedemiyordu (bkz. push.dart `_tokenAl`). Jeton
// GERÇEKTEN kaydolduğunda [pushCalisiyorBildir] çağrılır ve yoklama SUSAR:
// push varken ikinci kanal pil ve veri harcamaktan başka bir şey yapmaz.
//
// ===========================================================================
// İLK TUR "DAMGA" TURUDUR
// ===========================================================================
// Uygulama açılır açılmaz dünkü 20 bildirimin üst üste pencere açması
// kabus olurdu: ilk tur `son` damgası olmadan gider, sunucu SATIR DÖNMEZ,
// yalnız en büyük id'yi verir. Bundan sonrası gerçekten YENİ olandır.
//
// Sekme arkaya atılınca sayaç DURUR ve damga SIFIRLANIR (katman yönetir):
// yarım saat sonra dönen kullanıcıya eski bildirimler pencere olarak
// patlamaz — onlar zaten zil listesinde ve rozette duruyor.
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'anlik_bildirim.dart';
import 'api.dart';
import 'sohbet_olay.dart';

class BildirimCanli {
  BildirimCanli._();

  /// Yoklama aralığı. 20 sn = saatte 180 istek; sunucudaki `canliBildirimLimiti`
  /// (400/saat) iki sekmeye yer bırakır.
  static const Duration tur = Duration(seconds: 20);

  /// Bu platform yoklamalı mı? Bilerek `kIsWeb`in kendisi değil, ondan
  /// BAŞLATILAN bir alandır: `flutter test` daima `kIsWeb == false` koşar,
  /// gömülü bayrakla yazılan dal testten gizlenirdi (arama_servisi.dart'taki
  /// aynı kalıp).
  ///
  /// `defaultTargetPlatform` kullanılır, `Platform.isIOS` DEĞİL: `dart:io`
  /// web derlemesinde yok.
  static bool yoklamali = kIsWeb || defaultTargetPlatform == TargetPlatform.iOS;

  /// Push jetonu sunucuya KAYDEDİLDİ mi (mobil). True olunca yoklama susar.
  static bool pushHazir = false;

  /// push.dart jetonu kaydettiğinde çağırır: ikinci kanal kapanır.
  static void pushCalisiyorBildir() {
    pushHazir = true;
    dur();
  }

  static Timer? _sayac;
  static int? _son;
  static bool _ucusta = false;

  static bool get acik => _sayac != null;

  /// Yoklamayı başlatır (zaten açıksa hiçbir şey yapmaz).
  static void baslat() {
    if (!yoklamali || pushHazir || !Api.girisli || _sayac != null) return;
    _sayac = Timer.periodic(tur, (_) => _tur());
    // İlk tur HEMEN: damga alınsın ki ilk gerçek bildirim 20 sn beklemesin.
    _tur();
  }

  /// Yoklamayı durdurur ve damgayı DÜŞÜRÜR — bkz. dosya başlığı.
  static void dur() {
    _sayac?.cancel();
    _sayac = null;
    _son = null;
  }

  /// Oturum durumu değişti (giriş/çıkış) ya da sekme öne/arkaya geçti.
  static void esitle({required bool calissin}) {
    if (calissin) {
      baslat();
    } else {
      dur();
    }
  }

  static Future<void> _tur() async {
    // Önceki tur hâlâ uçuştaysa (yavaş ağ) üstüne yenisini bindirme.
    if (_ucusta || !Api.girisli) return;
    _ucusta = true;
    try {
      final d =
          await Api.get(
                _son == null
                    ? '/bildirimler/canli'
                    : '/bildirimler/canli?son=$_son',
              )
              as Map<String, dynamic>;
      final ilkTur = _son == null;
      final yeniSon = (d['son'] as num?)?.toInt();
      if (yeniSon != null) _son = yeniSon;
      if (ilkTur) return; // damga turu: satır beklenmez
      final liste = (d['bildirimler'] as List?) ?? const [];
      String? sonGonderen;
      for (final ham in liste) {
        final satir = Map<String, dynamic>.from(ham as Map);
        if (satir['tur'] == 'mesaj') sonGonderen = satir['aktor'] as String?;
        AnlikBildirim.satirGoster(satir);
      }
      if (sonGonderen != null) {
        // Pencere tek başına yetmez: sohbet listesi ve zarf rozeti de
        // tazelensin (web'de bunu yapan başka bir kanal yok). Sayacı
        // `mesajGeldi`nin kendisi hem yerel artırır hem sunucudan
        // doğrular — buradan ayrıca istemek aynı turu ikiye katlardı.
        SohbetOlaylari.mesajGeldi(sonGonderen);
      }
    } catch (_) {
      // Ağ yoksa / 429 geldiyse sessiz geç: bir sonraki tur dener.
    } finally {
      _ucusta = false;
    }
  }

  /// YALNIZ TEST: sayaç ve damga sıfırlanır.
  @visibleForTesting
  static void sifirla() {
    dur();
    _ucusta = false;
    pushHazir = false;
  }
}
