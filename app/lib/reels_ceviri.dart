import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reels'te OTOMATİK ÇEVİRİ tercihi (31 Ağu 2026 isteği: "sağ yukarıda
/// çeviri butonu olmalı, otomatik çeviriler açıp kapatılabilsin").
///
/// Sunucu yabancı dildeki gönderinin metnini okuyanın dilinde HAZIR gönderir
/// (`cevrildi` + `orijinal_metin`, bkz. server.js `ceviriUygula`). Bu tercih
/// KAPALIYKEN Reels o gönderileri orijinal dilinde çizer — ağ isteği yok,
/// yalnız hangi alanın gösterildiği değişir. Tercih cihazda saklanır
/// ([VeriTasarrufu] ile aynı kalıp) ve main.dart'ta yüklenir.
class ReelsCeviri {
  static const _anahtar = 'reels_otomatik_ceviri';

  /// Otomatik çeviri açık mı (varsayılan: açık — sunucunun bugünkü davranışı).
  static final ValueNotifier<bool> acik = ValueNotifier(true);

  static Future<void> yukle() async {
    final p = await SharedPreferences.getInstance();
    acik.value = p.getBool(_anahtar) ?? true;
  }

  static Future<void> sec(bool v) async {
    acik.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_anahtar, v);
  }
}
