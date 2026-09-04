import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tema.dart';

/// SOHBETE ÖZEL TEMA.
///
/// 31 Ağu 2026: yalnız kendi balonunun rengi + zeminde hafif ton (6 renk).
/// 5 Eyl 2026 ("özel temalar: aşk, friends vb, Telegram gibi"): tema artık
/// TAM bir görünüm — gradyan zemin (açık/koyu uygulama temasına ayrı), zemine
/// silik DESEN (Material ikonu), kendi balonu, karşı tarafın balonu ve tema
/// için özel efekt emojisi. Eski 6 düz renk "Renkler" grubu olarak KALDI;
/// kayıtlı anahtarlar (`sohbet_tema_<partner>`) değişmedi.
///
/// Tercih SOHBETE ÖZEL ve YERELDİR: cihazda durur; karşı taraf görmez
/// (WhatsApp'ta da tema tek taraflıdır), sunucuya hiçbir şey yazılmaz.
class SohbetTema {
  /// Saklanan kimlik (çeviriden bağımsız — ad değişse tercih bozulmaz).
  final String anahtar;

  /// Görünen ad (çeviri ANAHTARI; ekran `.c` ile çevirir).
  final String ad;

  /// Kendi balonumun rengi ve üstündeki yazı (kontrast ≥ 4,5:1; test kilitli).
  final Color balon;
  final Color yazi;

  /// Zemin gradyanı — KOYU uygulama temasında. Boşsa tema zemine dokunmaz
  /// (düz renk temalarında balonun %7 tonu binen eski davranış sürer).
  final List<Color> koyuZemin;

  /// Zemin gradyanı — AÇIK uygulama temasında.
  final List<Color> acikZemin;

  /// Karşı tarafın balonu (koyu / açık). Null → tema kartı [DiziRenkler.kart].
  final Color? karsiKoyu;
  final Color? karsiAcik;

  /// Zemine silik döşenen ikon (kalp, kahve, yıldız…). Null → desen yok.
  final IconData? desen;

  /// Bu temada "yazıyor…", tarih rozeti gibi vurguların rengi (koyu temada).
  /// Null → marka sarısı.
  final Color? vurgu;

  const SohbetTema(
    this.anahtar,
    this.ad,
    this.balon,
    this.yazi, {
    this.koyuZemin = const [],
    this.acikZemin = const [],
    this.karsiKoyu,
    this.karsiAcik,
    this.desen,
    this.vurgu,
  });

  /// Gradyanlı ("tam") tema mı, yoksa yalnız balon rengi mi?
  bool get gradyanli => koyuZemin.isNotEmpty;

  /// Zemin gradyanının renkleri (uygulama temasına göre); düz renk
  /// temalarında null.
  List<Color>? zeminRenkleri(bool acikTema) {
    if (!gradyanli) return null;
    final l = acikTema ? acikZemin : koyuZemin;
    return l.length >= 2 ? l : [l.first, l.first];
  }

  /// Sohbet zemini: düz renk temalarında uygulama zemininin üstüne balon
  /// renginin çok hafif tonu; varsayılanda ve gradyanlı temalarda null
  /// (gradyanlı temada zemini [SohbetZemini] çizer).
  Color? zemin(BuildContext context) {
    if (anahtar == 'varsayilan' || gradyanli) return null;
    return Color.alphaBlend(
      balon.withValues(alpha: 0.07),
      Theme.of(context).scaffoldBackgroundColor,
    );
  }

  /// Karşı tarafın balon rengi.
  Color karsiBalon(bool acikTema) =>
      (acikTema ? karsiAcik : karsiKoyu) ?? DiziRenkler.kart;

  /// Vurgu rengi (yazıyor satırı vb.); açık temada okunurluk için tema
  /// metnine düşer — açık zeminde sarı/cyan kaybolur.
  Color vurguRengi(bool acikTema) =>
      acikTema ? DiziRenkler.sariMetin : (vurgu ?? DiziRenkler.sari);
}

class SohbetTemalari {
  static const _onek = 'sohbet_tema_';

  /// Seçenekler. İLKİ varsayılandır (bugünkü sarı balon — davranış değişmez).
  /// Sıra: varsayılan → tam temalar → düz renkler. Ekran gruplara böler.
  static const listesi = [
    SohbetTema('varsayilan', 'Varsayılan', DiziRenkler.sari, Colors.black),
    // ---- TAM TEMALAR (gradyan zemin + desen + iki balon) ----
    SohbetTema(
      'ask',
      'Aşk',
      Color(0xFFC2185B),
      Colors.white,
      koyuZemin: [Color(0xFF2B0A1E), Color(0xFF5A1236), Color(0xFF7A1A3C)],
      acikZemin: [Color(0xFFFFE3EC), Color(0xFFFFC7D9)],
      karsiKoyu: Color(0xFF3F1A30),
      karsiAcik: Colors.white,
      desen: Icons.favorite,
      vurgu: Color(0xFFFF80AB),
    ),
    SohbetTema(
      'arkadaslar',
      'Arkadaşlar',
      DiziRenkler.sari,
      Colors.black,
      // Friends'in mor kapısı + sarı çerçevesi.
      koyuZemin: [Color(0xFF241543), Color(0xFF3E2470), Color(0xFF4F2D8C)],
      acikZemin: [Color(0xFFEDE3FF), Color(0xFFD9C8FF)],
      karsiKoyu: Color(0xFF3B2A63),
      karsiAcik: Colors.white,
      desen: Icons.local_cafe,
    ),
    SohbetTema(
      'gece',
      'Gece',
      Color(0xFF5C6BC0),
      Colors.white,
      koyuZemin: [Color(0xFF070B1F), Color(0xFF101A3F), Color(0xFF1B2A5E)],
      acikZemin: [Color(0xFFDDE3F7), Color(0xFFC5CFF0)],
      karsiKoyu: Color(0xFF1E2A55),
      karsiAcik: Colors.white,
      desen: Icons.star,
      vurgu: Color(0xFF9FA8DA),
    ),
    SohbetTema(
      'okyanus',
      'Okyanus',
      Color(0xFF4DD0E1),
      Colors.black,
      koyuZemin: [Color(0xFF04263A), Color(0xFF0B4F6C), Color(0xFF0E6A86)],
      acikZemin: [Color(0xFFD6F3FA), Color(0xFFB3E5F5)],
      karsiKoyu: Color(0xFF123C52),
      karsiAcik: Colors.white,
      desen: Icons.waves,
      vurgu: Color(0xFF80DEEA),
    ),
    SohbetTema(
      'gunbatimi',
      'Gün batımı',
      Color(0xFFFF7043),
      Colors.black,
      koyuZemin: [Color(0xFF3A0F2E), Color(0xFF7A2E1E), Color(0xFFB35A1A)],
      acikZemin: [Color(0xFFFFE0B2), Color(0xFFFFC1A6)],
      karsiKoyu: Color(0xFF4A2038),
      karsiAcik: Colors.white,
      desen: Icons.wb_twilight,
      vurgu: Color(0xFFFFAB91),
    ),
    SohbetTema(
      'orman',
      'Orman',
      Color(0xFF66BB6A),
      Colors.black,
      koyuZemin: [Color(0xFF0B2414), Color(0xFF1B4D2B), Color(0xFF256B3A)],
      acikZemin: [Color(0xFFDCEFD9), Color(0xFFBFE3BE)],
      karsiKoyu: Color(0xFF1F3F2A),
      karsiAcik: Colors.white,
      desen: Icons.park,
      vurgu: Color(0xFFA5D6A7),
    ),
    SohbetTema(
      'sinema',
      'Sinema',
      Color(0xFFC62828),
      Colors.white,
      koyuZemin: [Color(0xFF0B0B0D), Color(0xFF1C1114), Color(0xFF3A0F14)],
      acikZemin: [Color(0xFFF2EEEE), Color(0xFFE6D8D8)],
      karsiKoyu: Color(0xFF26262B),
      karsiAcik: Colors.white,
      desen: Icons.movie,
    ),
    SohbetTema(
      'neon',
      'Neon',
      Color(0xFF00E5FF),
      Colors.black,
      koyuZemin: [Color(0xFF12002B), Color(0xFF2A0050), Color(0xFF3D006B)],
      acikZemin: [Color(0xFFEDE0FF), Color(0xFFD0F7FF)],
      karsiKoyu: Color(0xFF2C1252),
      karsiAcik: Colors.white,
      desen: Icons.bolt,
      vurgu: Color(0xFFEA80FC),
    ),
    // ---- DÜZ RENKLER (31 Ağu seti) ----
    SohbetTema('yesil', 'Yeşil', Color(0xFF4CAF50), Colors.black),
    SohbetTema('mavi', 'Mavi', Color(0xFF42A5F5), Colors.black),
    SohbetTema('mor', 'Mor', Color(0xFFAB47BC), Colors.white),
    // 0xFFEC407A üstünde beyaz 4,3:1 kalıyordu; bir ton koyusu 4,9:1.
    SohbetTema('pembe', 'Pembe', Color(0xFFD81B60), Colors.white),
    SohbetTema('turuncu', 'Turuncu', Color(0xFFFF9800), Colors.black),
  ];

  /// Gradyanlı tam temalar (seçicideki "Temalar" grubu).
  static List<SohbetTema> get tamTemalar =>
      listesi.where((t) => t.gradyanli).toList();

  /// Düz renkler (seçicideki "Renkler" grubu; varsayılan dahil).
  static List<SohbetTema> get duzRenkler =>
      listesi.where((t) => !t.gradyanli).toList();

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

/// Sohbet zemini: gradyan + silik desen. Düz renk temalarında yalnız
/// [child]'ı döner (Scaffold zemini eskisi gibi çalışır).
class SohbetZemini extends StatelessWidget {
  final SohbetTema tema;
  final Widget child;

  const SohbetZemini({super.key, required this.tema, required this.child});

  @override
  Widget build(BuildContext context) {
    final renkler = tema.zeminRenkleri(DiziRenkler.acik);
    if (renkler == null) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: renkler,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (tema.desen != null)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: SohbetDeseni(
                      ikon: tema.desen!,
                      renk: DiziRenkler.acik
                          ? Colors.black.withValues(alpha: 0.07)
                          : Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// Zemin deseni: ikon glifi şaşırtmalı ızgarayla döşenir (Telegram desenli
/// duvar kâğıdının sade hâli). Boyama bir kez (RepaintBoundary); kaydırma
/// zemini yeniden çizdirmez.
class SohbetDeseni extends CustomPainter {
  final IconData ikon;
  final Color renk;

  /// Ikon aralığı ve boyu (dp).
  static const aralik = 76.0;
  static const boy = 24.0;

  const SohbetDeseni({required this.ikon, required this.renk});

  @override
  void paint(Canvas canvas, Size size) {
    final boyaci = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(ikon.codePoint),
        style: TextStyle(
          fontSize: boy,
          fontFamily: ikon.fontFamily,
          package: ikon.fontPackage,
          color: renk,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var satir = 0;
    for (var y = -boy; y < size.height + aralik; y += aralik, satir++) {
      final kaydir = satir.isOdd ? aralik / 2 : 0.0;
      for (var x = -boy + kaydir; x < size.width + aralik; x += aralik) {
        canvas.save();
        canvas.translate(x, y);
        // Hafif eğim: dümdüz ızgara "kağıt" gibi durmuyordu.
        canvas.rotate(satir.isOdd ? -0.25 : 0.25);
        boyaci.paint(canvas, Offset(-boyaci.width / 2, -boyaci.height / 2));
        canvas.restore();
      }
    }
    boyaci.dispose();
  }

  @override
  bool shouldRepaint(SohbetDeseni eski) =>
      eski.ikon != ikon || eski.renk != renk;
}
