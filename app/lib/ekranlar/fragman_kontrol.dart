import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ceviri.dart';
import '../gorsel_basliklari.dart';
import '../tema.dart';

/// Fragman karesinin üstündeki bizim krom (YouTube'un hiçbir parçası görünmez).
///
/// Üç bölge:
/// - **Üst şerit:** sarı "FRAGMAN" rozeti + fragman adı (YouTube başlığının
///   yerini alır; o kırpılarak gizlenir).
/// - **Orta küme:** −10 · büyük oynat/duraklat · +10 (YouTube mobil kalıbı).
///   Duraklatınca ve bitince sarı, oynarken yarı saydam siyah.
/// - **Alt şerit:** tam genişlik ilerleme çubuğu (koyu zemin · açık tampon ·
///   sarı oynanan; fareyle/sürüklerken kalınlaşır ve zaman balonu çıkar) +
///   oynat, süre, altyazı, 1×/2×, ses, tam ekran.
///
/// Dokunuşlar: tek dokunuş oynat/duraklat (krom gizliyse yalnız açar), çift
/// dokunuş sol −10 / sağ +10, basılı tutma 2×. Klavye (odaklıyken): boşluk/K
/// oynat-duraklat, ←/J −10, →/L +10, M ses, C altyazı, F tam ekran.
///
/// Krom OYNARKEN 3 sn dokunulmayınca gizlenir; duraklatınca, yüklenirken ve
/// bitince hep görünür. Fare kıpırdayınca geri gelir.
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

  /// Oynarken ara tamponlama (YouTube state 3 / `<video>` bekliyor): ortada
  /// küçük sarı halka, krom davranışı değişmez.
  final bool tamponluyor;

  /// Video sona erdi: büyük düğme "Tekrar oynat" olur, krom açık kalır.
  final bool bitti;

  /// Tam ekran rotasının içindeyiz: düğme "Tam ekrandan çık" olur.
  final bool tamEkran;

  /// Üst şeritteki fragman adı (TMDB `name`). Null ise yalnız rozet.
  final String? baslik;

  /// Yüklenirken spinner'ın altında gösterilen kapak (YouTube'un kendi
  /// spinner'ı ve siyah karesi böylece hiç görünmez). [kapakYedekUrl]
  /// ilki 404 verirse (maxres yoksa) denenir.
  final String? kapakUrl;
  final String? kapakYedekUrl;

  final VoidCallback onOynatDuraklat;
  final VoidCallback onSessiz;
  final VoidCallback onAltyazi;
  final VoidCallback onHiz;
  final VoidCallback onGeri10;
  final VoidCallback onIleri10;
  final ValueChanged<bool> onBasili2x;
  final ValueChanged<Duration>? onSarma;

  /// Null ise tam ekran düğmesi çizilmez.
  final VoidCallback? onTamEkran;

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
    this.tamponluyor = false,
    this.bitti = false,
    this.tamEkran = false,
    this.baslik,
    this.kapakUrl,
    this.kapakYedekUrl,
    required this.onOynatDuraklat,
    required this.onSessiz,
    required this.onAltyazi,
    required this.onHiz,
    required this.onGeri10,
    required this.onIleri10,
    required this.onBasili2x,
    this.onSarma,
    this.onTamEkran,
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
  late final FocusNode _odak;

  static const _ciftSure = Duration(milliseconds: 240);
  static const _sarmaGoster = Duration(milliseconds: 300);
  static const _gizleSure = Duration(seconds: 3);
  static const _gecis = Duration(milliseconds: 200);

  /// Krom kilitli (hiç gizlenmez): duraklatılmış, yükleniyor veya bitti.
  bool get _kilitli => !widget.oynuyor || widget.yukleniyor || widget.bitti;

  @override
  void initState() {
    super.initState();
    _odak = FocusNode(debugLabel: 'fragman-kontrol');
    _gizlemeyiKur();
  }

  @override
  void dispose() {
    _tekTik?.cancel();
    _sarmaTik?.cancel();
    _gizleTik?.cancel();
    _odak.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FragmanKontrol eski) {
    super.didUpdateWidget(eski);
    if (eski.oynuyor != widget.oynuyor ||
        eski.yukleniyor != widget.yukleniyor ||
        eski.bitti != widget.bitti) {
      _gizlemeyiKur();
    }
  }

  /// Kilitliyken krom hep açık; oynamaya dönünce sayaç kurulur.
  void _gizlemeyiKur() {
    if (_kilitli) {
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
      if (!mounted || _kilitli) return;
      setState(() => _krom = false);
    });
  }

  /// Krom açıkken her el/fare teması sayacı baştan kurar (çubukta sürükleme
  /// dahil — kullanıcı dokunurken krom kaybolmaz). Klavye için odak alınır.
  void _temas(PointerDownEvent _) {
    if (_krom) _sayacKur();
    if (!_odak.hasFocus) _odak.requestFocus();
  }

  /// Fare kıpırdayınca krom geri gelir (masaüstü/web); dokunmatik ekranlar
  /// hover üretmez, onlar dokunuşla açar.
  void _fare(PointerHoverEvent _) {
    if (!_krom) {
      setState(() => _krom = true);
    }
    if (!_kilitli) _sayacKur();
  }

  void _kromAc() {
    if (!_krom) setState(() => _krom = true);
    if (!_kilitli) _sayacKur();
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
      _sar(yan);
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

  /// ±10 sarma + kısa rozet (çift dokunuş, orta küme ve klavye ortak).
  void _sar(int yan) {
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
    if (!_kilitli && _krom) _sayacKur();
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

  /// Klavye kısayolları (yalnız oynatıcı odaklıyken).
  KeyEventResult _tus(FocusNode _, KeyEvent olay) {
    if (olay is! KeyDownEvent && olay is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final t = olay.logicalKey;
    if (t == LogicalKeyboardKey.space || t == LogicalKeyboardKey.keyK) {
      if (olay is KeyRepeatEvent) return KeyEventResult.handled;
      _kromAc();
      widget.onOynatDuraklat();
      return KeyEventResult.handled;
    }
    if (t == LogicalKeyboardKey.arrowLeft || t == LogicalKeyboardKey.keyJ) {
      _kromAc();
      _sar(-1);
      return KeyEventResult.handled;
    }
    if (t == LogicalKeyboardKey.arrowRight || t == LogicalKeyboardKey.keyL) {
      _kromAc();
      _sar(1);
      return KeyEventResult.handled;
    }
    if (olay is KeyRepeatEvent) return KeyEventResult.ignored;
    if (t == LogicalKeyboardKey.keyM) {
      _kromAc();
      widget.onSessiz();
      return KeyEventResult.handled;
    }
    if (t == LogicalKeyboardKey.keyC) {
      _kromAc();
      widget.onAltyazi();
      return KeyEventResult.handled;
    }
    if (t == LogicalKeyboardKey.keyF && widget.onTamEkran != null) {
      widget.onTamEkran!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// mm:ss
  static String sureMetni(Duration s) {
    if (s <= Duration.zero) return '0:00';
    final dk = s.inMinutes, sn = s.inSeconds % 60;
    return '$dk:${sn.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.yukleniyor) return _yuklemeEkrani();
    final sureSn = widget.sure.inMilliseconds <= 0
        ? 0.0
        : widget.sure.inMilliseconds / 1000;
    final konumOran = sureSn <= 0
        ? 0.0
        : (widget.konum.inMilliseconds / 1000).clamp(0, sureSn) / sureSn;
    final tamponOran = sureSn <= 0
        ? 0.0
        : (widget.tampon.inMilliseconds / 1000).clamp(0, sureSn) / sureSn;
    final kumeGorunur = _krom || _kilitli;
    return Focus(
      focusNode: _odak,
      onKeyEvent: _tus,
      child: Listener(
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
            if (_sarmaYan != 0)
              IgnorePointer(child: _sarmaRozeti(_sarmaYan < 0)),
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
            // Ara tamponlama: küme gizliyken bile görünür ki "dondu mu?"
            // sorusu kalmasın.
            if (widget.tamponluyor && !widget.bitti && !kumeGorunur)
              const IgnorePointer(
                child: Center(
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      color: DiziRenkler.sari,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ),
            // Orta küme: −10 · oynat/duraklat · +10. Krom ile birlikte
            // kaybolur; basılı tutarken (2×) çekilir ki kare açık kalsın.
            IgnorePointer(
              ignoring: !kumeGorunur || _basili,
              child: ExcludeSemantics(
                child: AnimatedOpacity(
                  key: const ValueKey('fragman-kume'),
                  opacity: kumeGorunur && !_basili ? 1 : 0,
                  duration: _gecis,
                  child: AnimatedScale(
                    scale: kumeGorunur && !_basili ? 1 : 0.9,
                    duration: _gecis,
                    curve: Curves.easeOutBack,
                    child: Center(child: _ortaKume()),
                  ),
                ),
              ),
            ),
            // Üst şerit: rozet + ad.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  excluding: !_krom,
                  child: AnimatedOpacity(
                    key: const ValueKey('fragman-ust'),
                    opacity: _krom ? 1 : 0,
                    duration: _gecis,
                    child: FragmanBaslikSeridi(baslik: widget.baslik),
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
                          colors: [Color(0x00000000), Color(0xCC000000)],
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          8,
                          28,
                          8,
                          widget.altBosluk,
                        ),
                        child: AnimatedSlide(
                          offset: _krom ? Offset.zero : const Offset(0, 0.3),
                          duration: _gecis,
                          curve: Curves.easeOut,
                          child: _altSerit(konumOran, tamponOran, sureSn),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Yüklenirken: kapak karesi + karartma + sarı halka + üst şerit.
  /// Kapak opak olduğu için YouTube'un kendi spinner'ı görünmez.
  Widget _yuklemeEkrani() {
    final kapak = widget.kapakUrl;
    final yedek = widget.kapakYedekUrl;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (kapak != null)
            // Kapak YouTube'dan gelir (i.ytimg.com); `gorselBasliklari`
            // TMDB dışı adreste null döner, başlık eklenmez.
            CachedNetworkImage(
              imageUrl: kapak,
              httpHeaders: gorselBasliklari(kapak),
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              errorWidget: (_, _, _) => yedek == null
                  ? const ColoredBox(color: Colors.black)
                  : CachedNetworkImage(
                      imageUrl: yedek,
                      httpHeaders: gorselBasliklari(yedek),
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      errorWidget: (_, _, _) =>
                          const ColoredBox(color: Colors.black),
                    ),
            )
          else
            const ColoredBox(color: Colors.black),
          const ColoredBox(color: Color(0x80000000)),
          const Center(
            child: SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                color: DiziRenkler.sari,
                strokeWidth: 3,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: FragmanBaslikSeridi(baslik: widget.baslik),
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

  /// −10 · büyük oynat/duraklat/tekrar · +10.
  Widget _ortaKume() {
    final buyukSari = !widget.oynuyor || widget.bitti;
    final IconData buyukIkon;
    if (widget.bitti) {
      buyukIkon = Icons.replay;
    } else if (widget.oynuyor) {
      buyukIkon = Icons.pause;
    } else {
      buyukIkon = Icons.play_arrow;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _yuvarlak(Icons.replay_10, 44, () => _sar(-1), sari: false),
        const SizedBox(width: 28),
        AnimatedContainer(
          duration: _gecis,
          curve: Curves.easeOut,
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: buyukSari ? DiziRenkler.sari : const Color(0x8A000000),
            shape: BoxShape.circle,
            boxShadow: const [BoxShadow(blurRadius: 16, color: Colors.black45)],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const ValueKey('fragman-buyuk'),
              customBorder: const CircleBorder(),
              onTap: widget.onOynatDuraklat,
              child: AnimatedSwitcher(
                duration: _gecis,
                transitionBuilder: (cocuk, animasyon) =>
                    ScaleTransition(scale: animasyon, child: cocuk),
                child: Icon(
                  buyukIkon,
                  key: ValueKey(buyukIkon),
                  size: 40,
                  color: buyukSari ? Colors.black : Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 28),
        _yuvarlak(Icons.forward_10, 44, () => _sar(1), sari: false),
      ],
    );
  }

  Widget _yuvarlak(
    IconData ikon,
    double boyut,
    VoidCallback onTap, {
    required bool sari,
  }) {
    return Material(
      color: sari ? DiziRenkler.sari : const Color(0x8A000000),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: boyut,
          height: boyut,
          child: Icon(
            ikon,
            size: 26,
            color: sari ? Colors.black : Colors.white,
          ),
        ),
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
                color: DiziRenkler.sari,
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

  /// Alt şerit: tam genişlik ilerleme çubuğu, altında düğme satırı.
  Widget _altSerit(double konumOran, double tamponOran, double sureSn) {
    final ikiKat = widget.hiz >= 1.5;
    final tamEkran = widget.onTamEkran;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _IlerlemeCubugu(
            oynanan: konumOran,
            tampon: tamponOran,
            sureSn: sureSn,
            onSarma: sureSn <= 0 || widget.onSarma == null
                ? null
                : (oran) => widget.onSarma!(
                    Duration(milliseconds: (oran * sureSn * 1000).round()),
                  ),
          ),
        ),
        Row(
          children: [
            AnimatedSwitcher(
              duration: _gecis,
              transitionBuilder: (cocuk, animasyon) =>
                  ScaleTransition(scale: animasyon, child: cocuk),
              child: KeyedSubtree(
                key: ValueKey('${widget.oynuyor}-${widget.bitti}'),
                child: _ikon(
                  widget.bitti
                      ? Icons.replay
                      : widget.oynuyor
                      ? Icons.pause
                      : Icons.play_arrow,
                  widget.bitti
                      ? 'Tekrar oynat'.c
                      : widget.oynuyor
                      ? 'Duraklat'.c
                      : 'Oynat'.c,
                  widget.onOynatDuraklat,
                ),
              ),
            ),
            Text(
              '${sureMetni(widget.konum)} / ${sureMetni(widget.sure)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
                shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
              ),
            ),
            const Spacer(),
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
            if (tamEkran != null)
              _ikon(
                widget.tamEkran ? Icons.fullscreen_exit : Icons.fullscreen,
                widget.tamEkran ? 'Tam ekrandan çık'.c : 'Tam ekran'.c,
                tamEkran,
                anahtar: const ValueKey('fragman-tam-ekran'),
              ),
          ],
        ),
      ],
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
          shadows: const [Shadow(blurRadius: 4, color: Colors.black87)],
        ),
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

/// Üst şerit: sarı "FRAGMAN" rozeti + fragman adı. Kapakta ve oynatıcıda
/// aynı parça — YouTube'un kırpılan başlığının yerini tutar.
class FragmanBaslikSeridi extends StatelessWidget {
  final String? baslik;

  const FragmanBaslikSeridi({super.key, this.baslik});

  @override
  Widget build(BuildContext context) {
    final ad = baslik?.trim() ?? '';
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xB3000000), Color(0x00000000)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 26),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: DiziRenkler.sari,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Fragman'.c.toUpperCase(),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            if (ad.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ad,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
                  ),
                ),
              ),
            ],
          ],
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
/// Fare üstündeyken/sürüklerken kalınlaşır, tutamak büyür, zaman balonu çıkar.
class _IlerlemeCubugu extends StatefulWidget {
  final double oynanan;
  final double tampon;
  final double sureSn;
  final ValueChanged<double>? onSarma;

  const _IlerlemeCubugu({
    required this.oynanan,
    required this.tampon,
    required this.sureSn,
    this.onSarma,
  });

  @override
  State<_IlerlemeCubugu> createState() => _IlerlemeCubuguState();
}

class _IlerlemeCubuguState extends State<_IlerlemeCubugu> {
  bool _uzerinde = false;
  double? _surukleOran;

  void _oran(Offset yerel, double genislik, {required bool bitti}) {
    if (genislik <= 0) return;
    final oran = (yerel.dx / genislik).clamp(0.0, 1.0);
    setState(() => _surukleOran = bitti ? null : oran);
    widget.onSarma?.call(oran);
  }

  @override
  Widget build(BuildContext context) {
    final aktif = widget.onSarma != null;
    final vurgu = aktif && (_uzerinde || _surukleOran != null);
    return LayoutBuilder(
      builder: (context, kisit) {
        final w = kisit.maxWidth;
        final balonOran = _surukleOran;
        return SizedBox(
          height: 28,
          child: MouseRegion(
            cursor: aktif ? SystemMouseCursors.click : MouseCursor.defer,
            onEnter: aktif ? (_) => setState(() => _uzerinde = true) : null,
            onExit: aktif ? (_) => setState(() => _uzerinde = false) : null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: aktif
                  ? (d) => _oran(d.localPosition, w, bitti: true)
                  : null,
              onHorizontalDragStart: aktif
                  ? (d) => _oran(d.localPosition, w, bitti: false)
                  : null,
              onHorizontalDragUpdate: aktif
                  ? (d) => _oran(d.localPosition, w, bitti: false)
                  : null,
              onHorizontalDragEnd: aktif
                  ? (_) => setState(() => _surukleOran = null)
                  : null,
              onHorizontalDragCancel: aktif
                  ? () => setState(() => _surukleOran = null)
                  : null,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CustomPaint(
                    key: const ValueKey('fragman-ilerleme'),
                    painter: FragmanIlerlemeBoyaci(
                      oynanan: widget.oynanan.clamp(0.0, 1.0),
                      tampon: widget.tampon.clamp(0.0, 1.0),
                      vurgu: vurgu,
                    ),
                    child: const SizedBox.expand(),
                  ),
                  if (balonOran != null && widget.sureSn > 0)
                    Positioned(
                      left: (w * balonOran - 24).clamp(0.0, w - 48),
                      top: -26,
                      child: IgnorePointer(
                        child: Container(
                          width: 48,
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          decoration: BoxDecoration(
                            color: DiziRenkler.sari,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _FragmanKontrolState.sureMetni(
                              Duration(
                                milliseconds: (balonOran * widget.sureSn * 1000)
                                    .round(),
                              ),
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
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
  final bool vurgu;

  FragmanIlerlemeBoyaci({
    required this.oynanan,
    required this.tampon,
    this.vurgu = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final h = vurgu ? 6.0 : 4.0;
    final r = Radius.circular(h / 2);
    canvas.drawRRect(
      RRect.fromLTRBR(0, y - h / 2, size.width, y + h / 2, r),
      Paint()..color = const Color(0x40FFFFFF),
    );
    if (tampon > 0) {
      canvas.drawRRect(
        RRect.fromLTRBR(0, y - h / 2, size.width * tampon, y + h / 2, r),
        Paint()..color = const Color(0x80FFFFFF),
      );
    }
    if (oynanan > 0) {
      canvas.drawRRect(
        RRect.fromLTRBR(0, y - h / 2, size.width * oynanan, y + h / 2, r),
        Paint()..color = DiziRenkler.sari,
      );
    }
    canvas.drawCircle(
      Offset(size.width * oynanan, y),
      vurgu ? 8 : 6,
      Paint()..color = DiziRenkler.sari,
    );
  }

  @override
  bool shouldRepaint(FragmanIlerlemeBoyaci eski) =>
      eski.oynanan != oynanan || eski.tampon != tampon || eski.vurgu != vurgu;
}
