import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../ceviri.dart';
import '../tema.dart';

/// Fragman karesinin üstündeki bizim krom.
///
/// Çift dokunuş: sol −10 sn, sağ +10 sn. Basılı tutma (sol veya sağ): 2×.
/// Altyazı ve kalıcı 1×/2× alt çubukta. İlerleme: koyu zemin, açık tampon,
/// sarı oynanan — üçü de ayrı görünür. Yatay kaydırma video alanında
/// PageView'e gider; yalnız çubukta sarma tanınır.
///
/// Krom OYNARKEN 3 sn dokunulmayınca gizlenir; gizliyken tek dokunuş yalnız
/// geri getirir (oynatmayı değiştirmez), çift dokunuş sarmayı gizli de yapar.
/// Duraklatınca ve yüklenirken hep görünür. Fare oynayınca da geri gelir —
/// böylece masaüstü/web hover'la, telefon dokunuşla aynı davranışı alır.
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
  Timer? _gizleTik;
  DateTime? _sonDokunus;
  int _sonYan = 0;
  bool _basili = false;
  int _sarmaYan = 0;
  bool _krom = true;

  static const _ciftSure = Duration(milliseconds: 240);
  static const _sarmaGoster = Duration(milliseconds: 300);
  static const _gizleSure = Duration(seconds: 3);
  static const _gecis = Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    _gizlemeyiKur();
  }

  @override
  void dispose() {
    _tekTik?.cancel();
    _sarmaTik?.cancel();
    _gizleTik?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(FragmanKontrol eski) {
    super.didUpdateWidget(eski);
    if (eski.oynuyor != widget.oynuyor ||
        eski.yukleniyor != widget.yukleniyor) {
      _gizlemeyiKur();
    }
  }

  /// Duraklatınca/yüklenirken krom hep açık; oynamaya dönünce sayaç kurulur.
  void _gizlemeyiKur() {
    if (!widget.oynuyor || widget.yukleniyor) {
      _gizleTik?.cancel();
      _gizleTik = null;
      if (!_krom) setState(() => _krom = true);
      return;
    }
    _sayacKur();
  }

  void _sayacKur() {
    _gizleTik?.cancel();
    _gizleTik = Timer(_gizleSure, () {
      if (!mounted || !widget.oynuyor || widget.yukleniyor) return;
      setState(() => _krom = false);
    });
  }

  /// Krom açıkken her el/fare teması sayacı baştan kurar (çubukta sürükleme
  /// dahil — kullanıcı dokunurken krom kaybolmaz).
  void _temas(PointerDownEvent _) {
    if (_krom) _sayacKur();
  }

  /// Fare kıpırdayınca krom geri gelir (masaüstü/web); dokunmatik ekranlar
  /// hover üretmez, onlar dokunuşla açar.
  void _fare(PointerHoverEvent _) {
    if (!_krom) {
      setState(() => _krom = true);
    }
    if (widget.oynuyor && !widget.yukleniyor) _sayacKur();
  }

  void _kromAc() {
    if (!_krom) setState(() => _krom = true);
    if (widget.oynuyor && !widget.yukleniyor) _sayacKur();
  }

  /// Sol (−1) / sağ (+1) yarım: tek dokunuş oynat-duraklat (krom gizliyse
  /// yalnız açar), çift sarma.
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
    final gizliydi = !_krom;
    _tekTik?.cancel();
    _tekTik = Timer(_ciftSure, () {
      if (!mounted) return;
      if (gizliydi) {
        _kromAc();
      } else {
        widget.onOynatDuraklat();
      }
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
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _temas,
      onPointerHover: _fare,
      child: Stack(
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
          IgnorePointer(
            child: AnimatedScale(
              scale: !widget.oynuyor && !_basili ? 1 : 0.85,
              duration: _gecis,
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                opacity: !widget.oynuyor && !_basili ? 1 : 0,
                duration: _gecis,
                child: Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: DiziRenkler.sari,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(blurRadius: 16, color: Colors.black45),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      size: 40,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Alt gradyan + kontrol çubuğu birlikte kaybolur; gizliyken
          // dokunuşlar alta (oynat/sarma yüzeyine) geçer, okuyucular görmez.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: !_krom,
              child: ExcludeSemantics(
                excluding: !_krom,
                child: AnimatedOpacity(
                  key: const ValueKey('fragman-krom'),
                  opacity: _krom ? 1 : 0,
                  duration: _gecis,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0xB3000000)],
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(8, 24, 8, widget.altBosluk),
                      child: AnimatedSlide(
                        offset: _krom ? Offset.zero : const Offset(0, 0.3),
                        duration: _gecis,
                        curve: Curves.easeOut,
                        child: _cubuk(konumOran, tamponOran, sureSn),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                geri ? Icons.fast_rewind : Icons.fast_forward,
                color: Colors.white,
                size: 32,
              ),
              Text(
                geri ? '−10' : '+10',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Alt kontrol: oynat, süre, tampon+sarı bar, altyazı, 2×, sessiz.
  Widget _cubuk(double konumOran, double tamponOran, double sureSn) {
    final ikiKat = widget.hiz >= 1.5;
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: _gecis,
              transitionBuilder: (cocuk, animasyon) =>
                  ScaleTransition(scale: animasyon, child: cocuk),
              child: KeyedSubtree(
                key: ValueKey(widget.oynuyor),
                child: _ikon(
                  widget.oynuyor ? Icons.pause : Icons.play_arrow,
                  widget.oynuyor ? 'Duraklat'.c : 'Oynat'.c,
                  widget.onOynatDuraklat,
                ),
              ),
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

/// Fragman yüklenemeyince gösterilen ortak ekran: kısa mesaj + sarı
/// "Tekrar dene". Gömücüler (io/web) hata dalında bunu kullanır.
class FragmanHata extends StatelessWidget {
  final VoidCallback onTekrar;

  const FragmanHata({super.key, required this.onTekrar});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white70, size: 32),
            const SizedBox(height: 8),
            Text(
              'Bir şeyler ters gitti'.c,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onTekrar,
              style: FilledButton.styleFrom(
                backgroundColor: DiziRenkler.sari,
                foregroundColor: Colors.black,
                minimumSize: const Size(120, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text('Tekrar dene'.c),
            ),
          ],
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
          child: MouseRegion(
            cursor: onSarma == null
                ? MouseCursor.defer
                : SystemMouseCursors.click,
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
