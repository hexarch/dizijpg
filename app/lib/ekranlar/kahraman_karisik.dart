import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../gorsel_basliklari.dart';
import '../tema.dart';
import '../tmdb_fragman.dart';
import '../veri_tasarrufu.dart';
import 'fragman.dart';

/// Dizi/film/bölüm kahramanı: tek 16:9 karede video ve fotoğraf karışık
/// kaydırılır (video, foto, video…). Çalan fragman kaydırınca duraklar;
/// geri gelince kaldığı yerden devam eder.
class KahramanKarisik extends StatefulWidget {
  final List<KahramanOge> ogeler;
  final void Function(String url)? onFotoAc;
  final double sayacUstBosluk;

  const KahramanKarisik({
    super.key,
    required this.ogeler,
    this.onFotoAc,
    this.sayacUstBosluk = 8,
  });

  @override
  State<KahramanKarisik> createState() => _KahramanKarisikState();
}

class _KahramanKarisikState extends State<KahramanKarisik> {
  late final PageController _sayfaKontrol;
  int _sayfa = 0;
  int _sayacTetik = 0;
  bool _hicGoruldu = false;

  static const _sayacSuresi = Duration(seconds: 3);
  static const _sonmeSuresi = Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    _sayfaKontrol = PageController();
  }

  @override
  void dispose() {
    _sayfaKontrol.dispose();
    super.dispose();
  }

  /// Sayaç her kaydırmada yeniden belirir, 3 sn sonra söner.
  void _sayaciGoster() {
    if (widget.ogeler.length < 2 || !mounted) return;
    setState(() => _sayacTetik++);
  }

  /// Geri sayım kart gerçekten görününce başlar.
  void _gorunurluk(VisibilityInfo bilgi) {
    if (_hicGoruldu || bilgi.visibleFraction < 0.5 || !mounted) return;
    _hicGoruldu = true;
    _sayaciGoster();
  }

  /// Noktaya dokununca o kareye gider (WebView kaydırmayı yutsa bile).
  void _kareyeGit(int i) {
    if (i == _sayfa || i < 0 || i >= widget.ogeler.length) return;
    _sayfaKontrol.animateToPage(
      i,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Widget _sayacRozeti() {
    final rozet = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${_sayfa + 1}/${widget.ogeler.length}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    if (_sayacTetik == 0) return rozet;
    return TweenAnimationBuilder<double>(
      key: ValueKey(_sayacTetik),
      tween: Tween(begin: 1, end: 0),
      duration: _sayacSuresi + _sonmeSuresi,
      curve: Interval(
        _sayacSuresi.inMilliseconds /
            (_sayacSuresi + _sonmeSuresi).inMilliseconds,
        1,
      ),
      builder: (_, deger, cocuk) => Opacity(opacity: deger, child: cocuk),
      child: rozet,
    );
  }

  /// Foto karesi; karartma noktaların altında kalsın diye burada.
  Widget _foto(KahramanOge oge) {
    final url = oge.url!;
    return GestureDetector(
      onTap: () => widget.onFotoAc?.call(url),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: url,
            httpHeaders: gorselBasliklari(url),
            fit: BoxFit.cover,
            placeholder: (_, _) => ColoredBox(color: DiziRenkler.kart),
            errorWidget: (_, _, _) => const ColoredBox(color: Colors.black),
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xFF000000)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ogeler = widget.ogeler;
    if (ogeler.isEmpty) return const SizedBox.shrink();
    final coklu = ogeler.length > 1;
    return VisibilityDetector(
      key: const Key('kahraman-karisik'),
      onVisibilityChanged: _gorunurluk,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _sayfaKontrol,
              itemCount: ogeler.length,
              allowImplicitScrolling: VeriTasarrufu.onYuklemeSerbest,
              onPageChanged: (i) {
                setState(() => _sayfa = i);
                _sayaciGoster();
              },
              itemBuilder: (context, i) {
                final oge = ogeler[i];
                if (oge.videoMi) {
                  return FragmanOynatici(
                    youtubeId: oge.youtubeId!,
                    baslik: oge.ad,
                    aktif: i == _sayfa,
                    altBosluk: coklu ? 44 : 8,
                  );
                }
                return _foto(oge);
              },
            ),
            if (coklu) ...[
              Positioned(
                top: 10 + widget.sayacUstBosluk,
                right: 10,
                child: IgnorePointer(child: _sayacRozeti()),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 44,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < ogeler.length; i++)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _kareyeGit(i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 16,
                            ),
                            child: Container(
                              width: i == _sayfa ? 8 : 5,
                              height: i == _sayfa ? 8 : 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _sayfa
                                    ? Colors.white
                                    : Colors.white38,
                              ),
                            ),
                          ),
                        ),
                    ],
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
