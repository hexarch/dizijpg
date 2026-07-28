import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../ceviri.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          // Üst şerit: sayaç + kapat
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  if (widget.urller.length > 1)
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
              color: Colors.white70,
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
                            color: Colors.white70,
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
