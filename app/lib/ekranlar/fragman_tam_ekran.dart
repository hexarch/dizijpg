import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'fragman_gom.dart';

/// Fragmanı tam ekran rotasında açar; kapanınca kalınan konumu döndürür
/// (geri tuşu/kaydırmayla kapanırsa da gömücü konumu `pop` ile verir).
///
/// Gömme (iframe/WebView) rota değişiminde yeniden kurulduğu için video
/// SÖKÜLÜP yeniden açılır; kaldığı saniye `start=` ile aktarılır. Kahraman
/// altta duraklamış bekler, dönüşte aynı saniyeye sarıp sürer.
Future<Duration?> fragmanTamEkranAc(
  BuildContext context, {
  required String youtubeId,
  required Duration baslangic,
  String? baslik,
  String? kapakUrl,
  String? kapakYedekUrl,
}) {
  return Navigator.of(context, rootNavigator: true).push<Duration>(
    PageRouteBuilder<Duration>(
      opaque: true,
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => FragmanTamEkran(
        youtubeId: youtubeId,
        baslangic: baslangic,
        baslik: baslik,
        kapakUrl: kapakUrl,
        kapakYedekUrl: kapakYedekUrl,
      ),
      transitionsBuilder: (_, animasyon, _, cocuk) =>
          FadeTransition(opacity: animasyon, child: cocuk),
    ),
  );
}

/// Siyah zemin üzerinde 16:9 oynatıcı. Mobilde yatay kilit + sistem
/// çubukları gizli; webde gömücü tarayıcı tam ekranını ister.
class FragmanTamEkran extends StatefulWidget {
  final String youtubeId;
  final Duration baslangic;
  final String? baslik;
  final String? kapakUrl;
  final String? kapakYedekUrl;

  const FragmanTamEkran({
    super.key,
    required this.youtubeId,
    this.baslangic = Duration.zero,
    this.baslik,
    this.kapakUrl,
    this.kapakYedekUrl,
  });

  @override
  State<FragmanTamEkran> createState() => _FragmanTamEkranState();
}

class _FragmanTamEkranState extends State<FragmanTamEkran> {
  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations(const []);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: FragmanGomucu(
              youtubeId: widget.youtubeId,
              baslangic: widget.baslangic,
              tamEkran: true,
              baslik: widget.baslik,
              kapakUrl: widget.kapakUrl,
              kapakYedekUrl: widget.kapakYedekUrl,
            ),
          ),
        ),
      ),
    );
  }
}
