import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:video_player/video_player.dart';

import '../altyazi.dart';
import '../ceviri.dart';
import '../gorsel_basliklari.dart';
import '../tema.dart';

/// Tam ekran medya görüntüleyici: fotoğrafta çimdik/sürükle yakınlaştırma,
/// videoda oynatma + sarma çubuğu; birden çok medyada sayfa kaydırma.
/// Akış, yorumlar ve sohbet ortak kullanır.
Future<void> medyaGoster(
  BuildContext context,
  List<String> urller, {
  int baslangic = 0,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      pageBuilder: (_, __, ___) =>
          _MedyaGorunumu(urller: urller, baslangic: baslangic),
      transitionsBuilder: (_, animasyon, __, cocuk) =>
          FadeTransition(opacity: animasyon, child: cocuk),
    ),
  );
}

bool _videoMu(String url) => url.endsWith('.mp4') || url.endsWith('.webm');

/// Tam ekran geçiş süresi: anlık zıplama yok (150–300 ms aralığı).
const Duration tamEkranGecisSuresi = Duration(milliseconds: 250);

/// Tam ekran fotoğraf/gönderi geçiş oku.
///
/// Siyah overlay üzerinde beyaz chevron; dokunma hedefi ≥44 dp. Web'de HTML
/// video katmanı tıklamayı yutmasın diye [PointerInterceptor] ile sarılır.
class TamEkranYonOku extends StatelessWidget {
  static const solAnahtar = ValueKey<String>('tam-ekran-sol-ok');
  static const sagAnahtar = ValueKey<String>('tam-ekran-sag-ok');

  final bool sola;
  final VoidCallback onPressed;

  const TamEkranYonOku({
    super.key,
    required this.sola,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: IconButton(
        key: sola ? solAnahtar : sagAnahtar,
        tooltip: sola ? 'Önceki'.c : 'Sonraki'.c,
        onPressed: onPressed,
        icon: Icon(
          sola ? Icons.chevron_left : Icons.chevron_right,
          color: Colors.white,
          size: 28,
        ),
        style: IconButton.styleFrom(
          backgroundColor: Colors.black.withValues(alpha: 0.45),
          minimumSize: const Size(44, 44),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
    );
  }
}

/// Tam ekran görünümde yön tuşlarını önceki/sonraki eyleme bağlar.
///
/// Odak metin kutusundaysa yutulmaz: [CallbackShortcuts] o zaman yazma
/// alanının atası olmadığı için (yorum sheet'i ayrı rota) tuşlar kutuya gider.
class TamEkranKlavye extends StatelessWidget {
  final VoidCallback? sola;
  final VoidCallback? saga;
  final VoidCallback? yukari;
  final VoidCallback? asagi;
  final Widget child;

  const TamEkranKlavye({
    super.key,
    this.sola,
    this.saga,
    this.yukari,
    this.asagi,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        if (sola != null)
          const SingleActivator(LogicalKeyboardKey.arrowLeft): sola!,
        if (saga != null)
          const SingleActivator(LogicalKeyboardKey.arrowRight): saga!,
        if (yukari != null)
          const SingleActivator(LogicalKeyboardKey.arrowUp): yukari!,
        if (asagi != null)
          const SingleActivator(LogicalKeyboardKey.arrowDown): asagi!,
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}

class _MedyaGorunumu extends StatefulWidget {
  final List<String> urller;
  final int baslangic;
  const _MedyaGorunumu({required this.urller, required this.baslangic});

  @override
  State<_MedyaGorunumu> createState() => _MedyaGorunumuState();
}

class _MedyaGorunumuState extends State<_MedyaGorunumu> {
  late final PageController _sayfa = PageController(
    initialPage: widget.baslangic,
  );
  late int _aktif = widget.baslangic;

  @override
  void dispose() {
    _sayfa.dispose();
    super.dispose();
  }

  int get _sayfaNo =>
      _sayfa.hasClients ? (_sayfa.page?.round() ?? _aktif) : _aktif;

  /// Önceki medya; ilk karede no-op.
  void _geri() => _git(_sayfaNo - 1);

  /// Sonraki medya; son karede no-op.
  void _ileri() => _git(_sayfaNo + 1);

  void _git(int i) {
    if (!_sayfa.hasClients) return;
    if (i < 0 || i >= widget.urller.length) return;
    if (i == _sayfaNo) return;
    _sayfa.animateToPage(
      i,
      duration: tamEkranGecisSuresi,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final coklu = widget.urller.length > 1;
    final dolgu = MediaQuery.paddingOf(context);
    return TamEkranKlavye(
      sola: coklu ? _geri : null,
      saga: coklu ? _ileri : null,
      yukari: coklu ? _geri : null,
      asagi: coklu ? _ileri : null,
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.93),
        body: Stack(
          children: [
            PageView.builder(
              controller: _sayfa,
              itemCount: widget.urller.length,
              onPageChanged: (i) => setState(() => _aktif = i),
              itemBuilder: (context, i) {
                final url = widget.urller[i];
                if (_videoMu(url)) return _TamVideo(url: url);
                // Fotoğraf/GIF: çimdikle 5x'e kadar yakınlaştır
                return GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: InteractiveViewer(
                    maxScale: 5,
                    child: Center(
                      child: CachedNetworkImage(
                        imageUrl: url,
                        // Bu görüntüleyici İKİ KAYNAĞI da açıyor: TMDB arka
                        // planı/bölüm karesi (detay.dart, bolum.dart) ve kendi
                        // sunucumuzdaki yorum/mesaj medyası. Hangisi olduğu
                        // ancak ÇALIŞMA ANINDA bilinir; kararı adres veriyor.
                        httpHeaders: gorselBasliklari(url),
                        filterQuality: kullaniciGorselKalitesi,
                        fit: BoxFit.contain,
                        progressIndicatorBuilder: (_, __, ___) =>
                            const CircularProgressIndicator(
                              color: DiziRenkler.sari,
                            ),
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          size: 48,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            // Yan oklar Stack İÇİNDE (sınır dışı Positioned tıklanamaz).
            if (coklu && _aktif > 0)
              Positioned(
                left: 8 + dolgu.left,
                top: 0,
                bottom: 0,
                child: Center(
                  child: TamEkranYonOku(sola: true, onPressed: _geri),
                ),
              ),
            if (coklu && _aktif < widget.urller.length - 1)
              Positioned(
                right: 8 + dolgu.right,
                top: 0,
                bottom: 0,
                child: Center(
                  child: TamEkranYonOku(sola: false, onPressed: _ileri),
                ),
              ),
            // Üst şerit: sayaç + kapat
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    if (coklu)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${_aktif + 1}/${widget.urller.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Kapat'.c,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tam ekran video: otomatik başlar, dokununca durur/oynar, altta sarma
/// çubuğu + süre.
class _TamVideo extends StatefulWidget {
  final String url;
  const _TamVideo({required this.url});

  @override
  State<_TamVideo> createState() => _TamVideoState();
}

class _TamVideoState extends State<_TamVideo> {
  VideoPlayerController? _d;
  String? _hata;
  double _ses = 1; // 0..1 ses seviyesi
  bool _sessiz = false;

  @override
  void initState() {
    super.initState();
    _baslat();
  }

  Future<void> _baslat() async {
    try {
      final d = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await d.initialize();
      if (!mounted) {
        d.dispose();
        return;
      }
      setState(() => _d = d);
      d.setLooping(true);
      d.play();
      d.addListener(_dinle);
    } catch (_) {
      if (mounted) setState(() => _hata = '');
    }
  }

  void _dinle() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _d?.removeListener(_dinle);
    _d?.dispose();
    super.dispose();
  }

  String _sure(Duration s) {
    final dk = s.inMinutes, sn = s.inSeconds % 60;
    return '$dk:${sn.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (_hata != null) {
      return const Center(
        child: Icon(
          Icons.videocam_off_outlined,
          size: 48,
          color: Colors.white38,
        ),
      );
    }
    if (d == null) {
      return const Center(
        child: CircularProgressIndicator(color: DiziRenkler.sari),
      );
    }
    return GestureDetector(
      onTap: () => d.value.isPlaying ? d.pause() : d.play(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: d.value.aspectRatio == 0
                  ? 16 / 9
                  : d.value.aspectRatio,
              child: VideoPlayer(d),
            ),
          ),
          if (!d.value.isPlaying)
            const Icon(
              Icons.play_circle_outline,
              size: 72,
              color: Colors.white,
            ),
          // Altyazı: alt kontrol çubuğunun ÜSTÜNDE, sol altta. Çubukla
          // çakışmasın diye bottom=86 (çubuk ~70px + boşluk).
          Positioned(
            left: 0,
            right: 0,
            bottom: 86,
            child: AltyaziKatmani(
              denetleyici: d,
              url: widget.url,
              genislikOrani: 0.92,
              yaziBoyutu: 15,
              kenarBosluk: const EdgeInsets.only(left: 12),
            ),
          ),
          // Alt kontrol çubuğu: oynat/duraklat + sarma + süre + ses
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            // Çubuğun boş alanına dokunuş videoyu durdurmasın
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VideoProgressIndicator(
                      d,
                      allowScrubbing: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      colors: const VideoProgressColors(
                        playedColor: DiziRenkler.sari,
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () =>
                              d.value.isPlaying ? d.pause() : d.play(),
                          icon: Icon(
                            d.value.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        Text(
                          '${_sure(d.value.position)} / ${_sure(d.value.duration)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            setState(() => _sessiz = !_sessiz);
                            d.setVolume(_sessiz ? 0 : _ses);
                          },
                          icon: Icon(
                            _sessiz || _ses == 0
                                ? Icons.volume_off
                                : (_ses < 0.5
                                      ? Icons.volume_down
                                      : Icons.volume_up),
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        // Ses seviyesi (dar ekranda gizlenir; sessize alma kalır)
                        if (MediaQuery.of(context).size.width > 480)
                          SizedBox(
                            width: 110,
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 12,
                                ),
                              ),
                              child: Slider(
                                value: _sessiz ? 0 : _ses,
                                activeColor: DiziRenkler.sari,
                                inactiveColor: Colors.white24,
                                onChanged: (v) {
                                  setState(() {
                                    _ses = v;
                                    _sessiz = v == 0;
                                  });
                                  d.setVolume(v);
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
