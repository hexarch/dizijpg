import 'dart:async';

import 'package:flutter/material.dart';

import '../ceviri.dart';
import '../tema.dart';

/// Fragman karesinin üstündeki bizim krom.
///
/// Çift dokunuş: sol −10 sn, sağ +10 sn. Basılı tutma (sol veya sağ): 2×.
/// Altyazı ve kalıcı 1×/2× alt çubukta. İlerleme: koyu zemin, açık tampon,
/// sarı oynanan — üçü de ayrı görünür. Yatay kaydırma video alanında
/// PageView'e gider; yalnız çubukta sarma tanınır.
class FragmanKontrol extends StatefulWidget {
  final bool yukleniyor;
  final bool oynuyor;
  final bool sessiz;
  final bool altyazi;
  final double hiz;
  final Duration konum;
  final Duration sure;
  final Duration tampon;
  final double altBosluk;
  final VoidCallback onOynatDuraklat;
  final VoidCallback onSessiz;
  final VoidCallback onAltyazi;
  final VoidCallback onHiz;
  final VoidCallback onGeri10;
  final VoidCallback onIleri10;
  final ValueChanged<bool> onBasili2x;
  final ValueChanged<Duration>? onSarma;

  const FragmanKontrol({
    super.key,
    required this.yukleniyor,
    required this.oynuyor,
    required this.sessiz,
    this.altyazi = false,
    this.hiz = 1,
    required this.konum,
    required this.sure,
    this.tampon = Duration.zero,
    this.altBosluk = 8,
    required this.onOynatDuraklat,
    required this.onSessiz,
    required this.onAltyazi,
    required this.onHiz,
    required this.onGeri10,
    required this.onIleri10,
    required this.onBasili2x,
    this.onSarma,
  });

  @override
  State<FragmanKontrol> createState() => _FragmanKontrolState();
}

class _FragmanKontrolState extends State<FragmanKontrol> {
  Timer? _tekTik;
  Timer? _sarmaTik;
  DateTime? _sonDokunus;
  int _sonYan = 0;
  bool _basili = false;
  int _sarmaYan = 0;

  static const _ciftSure = Duration(milliseconds: 240);
  static const _sarmaGoster = Duration(milliseconds: 300);

  @override
  void dispose() {
    _tekTik?.cancel();
    _sarmaTik?.cancel();
    super.dispose();
  }

  /// Sol (−1) / sağ (+1) yarım: tek dokunuş oynat-duraklat, çift sarma.
  void _dokun(int yan) {
    final simdi = DateTime.now();
    if (_sonYan == yan &&
        _sonDokunus != null &&
        simdi.difference(_sonDokunus!) < _ciftSure) {
      _tekTik?.cancel();
      _tekTik = null;
      _sonDokunus = null;
      if (yan < 0) {
        widget.onGeri10();
      } else {
        widget.onIleri10();
      }
      _sarmaTik?.cancel();
      setState(() => _sarmaYan = yan);
      _sarmaTik = Timer(_sarmaGoster, () {
        if (mounted) setState(() => _sarmaYan = 0);
      });
      return;
    }
    _sonYan = yan;
    _sonDokunus = simdi;
    _tekTik?.cancel();
    _tekTik = Timer(_ciftSure, () {
      if (mounted) widget.onOynatDuraklat();
    });
  }

  void _basiliBasla() {
    if (_basili) return;
    _tekTik?.cancel();
    setState(() => _basili = true);
    widget.onBasili2x(true);
  }

  void _basiliBitir() {
    if (!_basili) return;
    setState(() => _basili = false);
    widget.onBasili2x(false);
  }

  /// mm:ss
  String _sure(Duration s) {
    if (s <= Duration.zero) return '0:00';
    final dk = s.inMinutes, sn = s.inSeconds % 60;
    return '$dk:${sn.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.yukleniyor) {
      return const IgnorePointer(
        child: ColoredBox(
          color: Colors.black26,
          child: Center(
            child: CircularProgressIndicator(color: DiziRenkler.sari),
          ),
        ),
      );
    }
    final sureSn = widget.sure.inMilliseconds <= 0
        ? 0.0
        : widget.sure.inMilliseconds / 1000;
    final konumOran = sureSn <= 0
        ? 0.0
        : (widget.konum.inMilliseconds / 1000).clamp(0, sureSn) / sureSn;
    final tamponOran = sureSn <= 0
        ? 0.0
        : (widget.tampon.inMilliseconds / 1000).clamp(0, sureSn) / sureSn;
    return Stack(
      fit: StackFit.expand,
      children: [
        Row(
          children: [
            Expanded(child: _yan(-1, '10 saniye geri'.c)),
            Expanded(child: _yan(1, '10 saniye ileri'.c)),
          ],
        ),
        if (_sarmaYan != 0) IgnorePointer(child: _sarmaRozeti(_sarmaYan < 0)),
        if (_basili)
          const IgnorePointer(
            child: Center(
              child: Text(
                '2×',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(blurRadius: 12, color: Colors.black87)],
                ),
              ),
            ),
          ),
        if (!widget.oynuyor && !_basili)
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
          bottom: widget.altBosluk,
          child: _cubuk(konumOran, tamponOran, sureSn),
        ),
      ],
    );
  }

  /// Video yarımı: tap/çift tap/basılı tut. Yatay sürükleme tanımaz.
  Widget _yan(int yan, String etiket) {
    return Semantics(
      button: true,
      label: etiket,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _dokun(yan),
        onLongPressStart: (_) => _basiliBasla(),
        onLongPressEnd: (_) => _basiliBitir(),
        onLongPressCancel: _basiliBitir,
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _sarmaRozeti(bool geri) {
    return Align(
      alignment: geri ? Alignment.centerLeft : Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              geri ? Icons.fast_rewind : Icons.fast_forward,
              color: Colors.white,
              size: 36,
            ),
            Text(
              geri ? '−10' : '+10',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Alt kontrol: oynat, süre, tampon+sarı bar, altyazı, 2×, sessiz.
  Widget _cubuk(double konumOran, double tamponOran, double sureSn) {
    final ikiKat = widget.hiz >= 1.5;
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
        child: Row(
          children: [
            _ikon(
              widget.oynuyor ? Icons.pause : Icons.play_arrow,
              widget.oynuyor ? 'Duraklat'.c : 'Oynat'.c,
              widget.onOynatDuraklat,
            ),
            Text(
              '${_sure(widget.konum)} / ${_sure(widget.sure)}',
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _IlerlemeCubugu(
                  oynanan: konumOran,
                  tampon: tamponOran,
                  onSarma: sureSn <= 0 || widget.onSarma == null
                      ? null
                      : (oran) => widget.onSarma!(
                          Duration(
                            milliseconds: (oran * sureSn * 1000).round(),
                          ),
                        ),
                ),
              ),
            ),
            _ikon(
              widget.altyazi ? Icons.closed_caption : Icons.closed_caption_off,
              widget.altyazi ? 'Altyazıyı kapat'.c : 'Altyazıyı aç'.c,
              widget.onAltyazi,
              anahtar: const ValueKey('fragman-altyazi'),
              vurgu: widget.altyazi,
            ),
            Semantics(
              button: true,
              label: ikiKat ? '2×' : '1×',
              child: IconButton(
                key: const ValueKey('fragman-hiz'),
                onPressed: widget.onHiz,
                tooltip: ikiKat ? '2×' : '1×',
                icon: Text(
                  ikiKat ? '2×' : '1×',
                  style: TextStyle(
                    color: ikiKat ? DiziRenkler.sari : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: IconButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            _ikon(
              widget.sessiz ? Icons.volume_off : Icons.volume_up,
              widget.sessiz ? 'Sesi aç'.c : 'Sesi kapat'.c,
              widget.onSessiz,
            ),
          ],
        ),
      ),
    );
  }

  Widget _ikon(
    IconData ikon,
    String etiket,
    VoidCallback onTap, {
    Key? anahtar,
    bool vurgu = false,
  }) {
    return Semantics(
      button: true,
      label: etiket,
      child: IconButton(
        key: anahtar,
        onPressed: onTap,
        tooltip: etiket,
        icon: Icon(
          ikon,
          color: vurgu ? DiziRenkler.sari : Colors.white,
          size: 22,
        ),
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

/// Üç katmanlı bar: kalan (koyu) · tampon (açık gri) · oynanan (sarı).
class _IlerlemeCubugu extends StatelessWidget {
  final double oynanan;
  final double tampon;
  final ValueChanged<double>? onSarma;

  const _IlerlemeCubugu({
    required this.oynanan,
    required this.tampon,
    this.onSarma,
  });

  void _oran(Offset yerel, double genislik, ValueChanged<double> onSarma) {
    if (genislik <= 0) return;
    onSarma((yerel.dx / genislik).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, kisit) {
        final w = kisit.maxWidth;
        return SizedBox(
          height: 44,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: onSarma == null
                ? null
                : (d) => _oran(d.localPosition, w, onSarma!),
            onHorizontalDragUpdate: onSarma == null
                ? null
                : (d) => _oran(d.localPosition, w, onSarma!),
            child: CustomPaint(
              key: const ValueKey('fragman-ilerleme'),
              painter: FragmanIlerlemeBoyaci(
                oynanan: oynanan.clamp(0.0, 1.0),
                tampon: tampon.clamp(0.0, 1.0),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }
}

/// Testlerin tampon/oynanan oranını okuması için public boyacı.
class FragmanIlerlemeBoyaci extends CustomPainter {
  final double oynanan;
  final double tampon;

  FragmanIlerlemeBoyaci({required this.oynanan, required this.tampon});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    const h = 4.0;
    final r = RRect.fromLTRBR(
      0,
      y - h / 2,
      size.width,
      y + h / 2,
      const Radius.circular(2),
    );
    canvas.drawRRect(r, Paint()..color = const Color(0x33FFFFFF));
    if (tampon > 0) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          0,
          y - h / 2,
          size.width * tampon,
          y + h / 2,
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0x99FFFFFF),
      );
    }
    if (oynanan > 0) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          0,
          y - h / 2,
          size.width * oynanan,
          y + h / 2,
          const Radius.circular(2),
        ),
        Paint()..color = DiziRenkler.sari,
      );
    }
    canvas.drawCircle(
      Offset(size.width * oynanan, y),
      6,
      Paint()..color = DiziRenkler.sari,
    );
  }

  @override
  bool shouldRepaint(FragmanIlerlemeBoyaci eski) =>
      eski.oynanan != oynanan || eski.tampon != tampon;
}
