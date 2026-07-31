import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bağlantı türüne göre veri tasarrufu.
///
/// İki ayrı anahtar var: Wi-Fi ve mobil veri. Tasarruf AÇIKKEN uygulama
/// fotoğrafları önden indirmez; yalnız bakılan kare yüklenir. Varsayılan:
/// **Wi-Fi kapalı (önden indir), mobil açık (indirme)** — kullanıcının mobil
/// verisi sebepsiz harcanmasın.
///
/// Web'de bağlantı türü güvenilir ayırt edilemez (tarayıcı mobil veriyi de
/// wifi/ethernet diye bildirir) → web daima Wi-Fi sayılır.
class VeriTasarrufu {
  static const _anahtarWifi = 'veri_tasarrufu_wifi';
  static const _anahtarMobil = 'veri_tasarrufu_mobil';

  /// Wi-Fi'dayken tasarruf açık mı (varsayılan: kapalı).
  static final ValueNotifier<bool> wifi = ValueNotifier(false);

  /// Mobil verideyken tasarruf açık mı (varsayılan: açık).
  static final ValueNotifier<bool> mobil = ValueNotifier(true);

  /// Şu anki bağlantı mobil veri mi? (web'de daima false)
  static final ValueNotifier<bool> mobilBaglanti = ValueNotifier(false);

  static StreamSubscription<List<ConnectivityResult>>? _abone;

  /// Ayarları okur ve bağlantı türünü izlemeye başlar. main.dart'ta, uygulama
  /// açılırken bir kez çağrılır.
  static Future<void> yukle() async {
    final p = await SharedPreferences.getInstance();
    wifi.value = p.getBool(_anahtarWifi) ?? false;
    mobil.value = p.getBool(_anahtarMobil) ?? true;
    if (kIsWeb) return; // tarayıcıda tür ayırt edilemez, Wi-Fi varsayılır
    try {
      _baglantiyiIsle(await Connectivity().checkConnectivity());
      _abone ??= Connectivity().onConnectivityChanged.listen(_baglantiyiIsle);
    } catch (_) {
      // Bağlantı türü okunamadıysa Wi-Fi varsayılır: kullanıcıyı özellikten
      // mahrum bırakmaktansa önden indirmek yeğdir.
    }
  }

  static void _baglantiyiIsle(List<ConnectivityResult> sonuc) {
    mobilBaglanti.value = sonuc.contains(ConnectivityResult.mobile);
  }

  static Future<void> wifiSec(bool acik) async {
    wifi.value = acik;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_anahtarWifi, acik);
  }

  static Future<void> mobilSec(bool acik) async {
    mobil.value = acik;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_anahtarMobil, acik);
  }

  /// Şu anki bağlantıda tasarruf açık mı.
  static bool get acik => mobilBaglanti.value ? mobil.value : wifi.value;

  /// Fotoğraflar önden indirilsin mi (tasarruf kapalıysa evet).
  static bool get onYuklemeSerbest => !acik;
}
