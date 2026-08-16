import 'package:flutter/material.dart';

import '../ceviri.dart';
import '../tema.dart';

/// Fragman karesinin üstündeki bizim krom: oynat/duraklat, sarı ilerleme,
/// sessiz. YouTube'un kendi başlığı / ilgili videoları / logosu yok.
///
/// Yatay kaydırmayı PageView'e bırakmak için video alanına yalnız [onTap]
/// bağlanır (sürükleme tanımaz). Sarma çubuğu alttadır.
class FragmanKontrol extends StatelessWidget {
  final bool yukleniyor;
  final bool oynuyor;
  final bool sessiz;
  final Duration konum;
  final Duration sure;
  final double altBosluk;
  final VoidCallback onOynatDuraklat;
  final VoidCallback onSessiz;
  final ValueChanged<Duration>? onSarma;

  const FragmanKontrol({
    super.key,
    required this.yukleniyor,
    required this.oynuyor,
    required this.sessiz,
    required this.konum,
    required this.sure,
    this.altBosluk = 8,
    required this.onOynatDuraklat,
    required this.onSessiz,
    this.onSarma,
  });

  /// mm:ss — süre henüz yoksa boş.
  String _sure(Duration s) {
    if (s <= Duration.zero) return '0:00';
    final dk = s.inMinutes, sn = s.inSeconds % 60;
    return '$dk:${sn.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (yukleniyor) {
      return const IgnorePointer(
        child: ColoredBox(
          color: Colors.black26,
          child: Center(
            child: CircularProgressIndicator(color: DiziRenkler.sari),
          ),
        ),
      );
    }
    final sureSn = sure.inMilliseconds <= 0 ? 0.0 : sure.inMilliseconds / 1000;
    final konumSn = konum.inMilliseconds / 1000;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Yalnız tap: yatay sürükleme kahraman kaydırıcısına gider.
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: onOynatDuraklat,
          child: const SizedBox.expand(),
        ),
        if (!oynuyor)
          const IgnorePointer(
            child: Center(
              child: Icon(
                Icons.play_circle_outline,
                size: 64,
                color: Colors.white,
              ),
            ),
          ),
        Positioned(
          left: 8,
          right: 8,
          bottom: altBosluk,
          child: _cubuk(sureSn, konumSn),
        ),
      ],
    );
  }

  /// Alt kontrol: sarma + süre + sessiz (dokunma hedefi ≥44).
  Widget _cubuk(double sureSn, double konumSn) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 2, 0),
        child: Row(
          children: [
            Semantics(
              button: true,
              label: (oynuyor ? 'Duraklat' : 'Oynat').c,
              child: IconButton(
                onPressed: onOynatDuraklat,
                tooltip: (oynuyor ? 'Duraklat' : 'Oynat').c,
                icon: Icon(
                  oynuyor ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 26,
                ),
                style: IconButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            Text(
              '${_sure(konum)} / ${_sure(sure)}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            if (sureSn > 0)
              Expanded(
                child: SliderTheme(
                  data: const SliderThemeData(
                    trackHeight: 3,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
                    activeTrackColor: DiziRenkler.sari,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: DiziRenkler.sari,
                    overlayColor: Color(0x33F5C518),
                  ),
                  child: Slider(
                    min: 0,
                    max: sureSn,
                    value: konumSn.clamp(0, sureSn),
                    onChanged: onSarma == null
                        ? null
                        : (v) => onSarma!(
                            Duration(milliseconds: (v * 1000).round()),
                          ),
                  ),
                ),
              )
            else
              const Spacer(),
            Semantics(
              button: true,
              label: (sessiz ? 'Sesi aç' : 'Sesi kapat').c,
              child: IconButton(
                onPressed: onSessiz,
                tooltip: (sessiz ? 'Sesi aç' : 'Sesi kapat').c,
                icon: Icon(
                  sessiz ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 22,
                ),
                style: IconButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
