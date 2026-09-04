import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

/// EMOJİ EKRAN EFEKTİ (5 Eyl 2026 isteği: "emojilere tıklayınca ekranda
/// animasyonlar").
///
/// Telegram'ın tam ekran emoji efektinin küçüğü: dokunulan emojinin
/// kopyaları dokunma noktasından yukarı doğru saçılır, süzülür, döner ve
/// söner. Tepki verince, büyük emoji balonuna dokununca ve karşı taraf
/// efekt gönderince oynar.
///
/// ÇİZİM: parçacıklar SİSTEM emoji fontuyla (Text glifi) boyanır, Lottie
/// DEĞİL — 18 Lottie kopyasını aynı anda çözmek düşük donanımda kareyi
/// düşürür; glif tek TextPainter'dır. Balondaki ASIL emoji Lottie olarak
/// zaten yeniden oynar (`vurus`), efekt onun etrafındaki süstür.
///
/// Erişilebilirlik: "hareketi azalt" açıksa HİÇ oynamaz (yalnız titreşim).
/// Overlay kök katmana biner; dokunmayı yutmaz (IgnorePointer).
class EmojiEfekti {
  EmojiEfekti._();

  /// Aynı anda en çok bu kadar patlama; fazlası atılır (spam koruması —
  /// biri 20 kez art arda dokunursa ekran parçacığa boğulmasın).
  static const int azamiEsZamanli = 4;
  static int _aktif = 0;

  /// [kaynak] ekran koordinatı (global); null ise ekranın alt-ortası.
  static void oynat(BuildContext context, String emoji, {Offset? kaynak}) {
    HapticFeedback.lightImpact();
    if (MediaQuery.disableAnimationsOf(context)) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null || _aktif >= azamiEsZamanli) return;
    _aktif++;
    late final OverlayEntry giris;
    giris = OverlayEntry(
      builder: (_) => EmojiPatlamasi(
        emoji: emoji,
        kaynak: kaynak,
        bitti: () {
          giris.remove();
          _aktif--;
        },
      ),
    );
    overlay.insert(giris);
  }
}

/// Bir patlama: [EmojiEfekti.oynat] kurar, süresi dolunca kendini söker.
/// Testler `find.byType(EmojiPatlamasi)` ile yakalar.
class EmojiPatlamasi extends StatefulWidget {
  final String emoji;
  final Offset? kaynak;
  final VoidCallback bitti;

  /// Toplam süre; en geç parçacık bundan önce söner.
  static const sure = Duration(milliseconds: 1900);

  const EmojiPatlamasi({
    super.key,
    required this.emoji,
    required this.bitti,
    this.kaynak,
  });

  @override
  State<EmojiPatlamasi> createState() => _EmojiPatlamasiState();
}

class _Parcacik {
  final double aci; // radyan, -π/2 = düz yukarı
  final double hiz; // px/sn
  final double boyut;
  final double donus; // toplam dönüş (radyan)
  final double gecikme; // 0..0.3 (oran)
  final double salinim; // yatay salınım genliği
  const _Parcacik(
    this.aci,
    this.hiz,
    this.boyut,
    this.donus,
    this.gecikme,
    this.salinim,
  );
}

class _EmojiPatlamasiState extends State<EmojiPatlamasi>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Parcacik> _parcaciklar;
  late final TextPainter _boyaci;

  @override
  void initState() {
    super.initState();
    final r = math.Random();
    _parcaciklar = [
      for (var i = 0; i < 18; i++)
        _Parcacik(
          // Yukarı yelpaze: -π/2 ± 1.15 rad (yaklaşık ±66°).
          -math.pi / 2 + (r.nextDouble() * 2 - 1) * 1.15,
          260 + r.nextDouble() * 320,
          20 + r.nextDouble() * 22,
          (r.nextDouble() * 2 - 1) * math.pi * 1.5,
          r.nextDouble() * 0.3,
          (r.nextDouble() * 2 - 1) * 26,
        ),
    ];
    _boyaci = TextPainter(textDirection: TextDirection.ltr);
    _c = AnimationController(vsync: this, duration: EmojiPatlamasi.sure)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.bitti();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    _boyaci.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ekran = MediaQuery.sizeOf(context);
    final kaynak =
        widget.kaynak ?? Offset(ekran.width / 2, ekran.height * 0.72);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: ekran,
          painter: _PatlamaBoyayici(
            emoji: widget.emoji,
            parcaciklar: _parcaciklar,
            kaynak: kaynak,
            t: _c.value,
            boyaci: _boyaci,
          ),
        ),
      ),
    );
  }
}

class _PatlamaBoyayici extends CustomPainter {
  final String emoji;
  final List<_Parcacik> parcaciklar;
  final Offset kaynak;
  final double t;
  final TextPainter boyaci;

  const _PatlamaBoyayici({
    required this.emoji,
    required this.parcaciklar,
    required this.kaynak,
    required this.t,
    required this.boyaci,
  });

  static const _yercekimi = 420.0; // px/sn²
  static const _sureSn = 1.9;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in parcaciklar) {
      // Gecikmeli başlangıç: her parçacığın kendi 0..1 zamanı.
      final yerel = ((t - p.gecikme) / (1 - p.gecikme)).clamp(0.0, 1.0);
      if (yerel <= 0) continue;
      final sn = yerel * _sureSn;
      final vx = math.cos(p.aci) * p.hiz;
      final vy = math.sin(p.aci) * p.hiz;
      final x = kaynak.dx + vx * sn + math.sin(yerel * math.pi * 2) * p.salinim;
      final y = kaynak.dy + vy * sn + 0.5 * _yercekimi * sn * sn;
      // Belirme (ilk %12 büyür), sonra sönme (son %45).
      final buyume = (yerel / 0.12).clamp(0.0, 1.0);
      final olcek = 0.4 + 0.6 * Curves.easeOutBack.transform(buyume);
      final opaklik = yerel < 0.55 ? 1.0 : 1 - (yerel - 0.55) / 0.45;
      if (opaklik <= 0) continue;
      boyaci.text = TextSpan(
        text: emoji,
        style: TextStyle(
          fontSize: p.boyut,
          color: Colors.white.withValues(alpha: opaklik.clamp(0.0, 1.0)),
        ),
      );
      boyaci.layout();
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.donus * yerel);
      canvas.scale(olcek);
      boyaci.paint(canvas, Offset(-boyaci.width / 2, -boyaci.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PatlamaBoyayici eski) =>
      eski.t != t || eski.emoji != emoji || eski.kaynak != kaynak;
}
