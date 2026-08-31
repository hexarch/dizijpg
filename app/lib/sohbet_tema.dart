import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tema.dart';

/// SOHBETE ÖZEL TEMA (31 Ağu 2026 isteği: sohbet detayında "tema özelleştir").
///
/// Tercih SOHBETE ÖZEL ve YERELDİR: `sohbet_tema_<partner>` anahtarıyla
/// cihazda durur; karşı taraf görmez (WhatsApp'ta da tema tek taraflıdır) ve
/// sunucuya hiçbir şey yazılmaz. Tema iki şeyi değiştirir: KENDİ balonunun
/// rengi ve sohbet zemininin hafif tonu. Karşı tarafın balonu tema kartı
/// ([DiziRenkler.kart]) kalır — açık/koyu uygulama temasında okunurluğu o
/// garanti ediyor; zemin tonu da alfa harmanı olduğu için iki uygulama
/// temasında da çalışır.
class SohbetTema {
  /// Saklanan kimlik (çeviriden bağımsız — ad değişse tercih bozulmaz).
  final String anahtar;

  /// Görünen ad (çeviri ANAHTARI; ekran `.c` ile çevirir).
  final String ad;

  /// Kendi balonumun rengi.
  final Color balon;

  /// Balon üstündeki yazı/ikon rengi (renk parlaklığına göre seçildi).
  final Color yazi;

  const SohbetTema(this.anahtar, this.ad, this.balon, this.yazi);

  /// Sohbet zemini: uygulama zemininin üstüne balon renginin çok hafif tonu.
  /// Varsayılan temada null → Scaffold kendi zeminini kullanır.
  Color? zemin(BuildContext context) => anahtar == 'varsayilan'
      ? null
      : Color.alphaBlend(
          balon.withValues(alpha: 0.07),
          Theme.of(context).scaffoldBackgroundColor,
        );
}

class SohbetTemalari {
  static const _onek = 'sohbet_tema_';

  /// Seçenekler. İLKİ varsayılandır (bugünkü sarı balon — davranış değişmez).
  static const listesi = [
    SohbetTema('varsayilan', 'Varsayılan', DiziRenkler.sari, Colors.black),
    SohbetTema('yesil', 'Yeşil', Color(0xFF4CAF50), Colors.black),
    SohbetTema('mavi', 'Mavi', Color(0xFF42A5F5), Colors.black),
    SohbetTema('mor', 'Mor', Color(0xFFAB47BC), Colors.white),
    SohbetTema('pembe', 'Pembe', Color(0xFFEC407A), Colors.white),
    SohbetTema('turuncu', 'Turuncu', Color(0xFFFF9800), Colors.black),
  ];

  /// Tema değişince artar — açık sohbet ekranı dinleyip tercihi yeniden okur
  /// (detay ekranı ayrı rotada; sonuç taşımak yerine yayın, `SohbetOlaylari`
  /// kalıbının küçüğü).
  static final ValueNotifier<int> nesil = ValueNotifier(0);

  static SohbetTema bul(String? anahtar) => listesi.firstWhere(
    (t) => t.anahtar == anahtar,
    orElse: () => listesi.first,
  );

  static Future<SohbetTema> getir(String partner) async {
    final p = await SharedPreferences.getInstance();
    return bul(p.getString('$_onek$partner'));
  }

  static Future<void> sec(String partner, SohbetTema t) async {
    final p = await SharedPreferences.getInstance();
    if (t.anahtar == 'varsayilan') {
      await p.remove('$_onek$partner');
    } else {
      await p.setString('$_onek$partner', t.anahtar);
    }
    nesil.value++;
  }
}
