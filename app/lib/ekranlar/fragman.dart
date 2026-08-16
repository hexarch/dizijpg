import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../ceviri.dart';
import '../tema.dart';
import '../tmdb_fragman.dart';
import 'fragman_gom.dart';

/// Dizi/film/bölüm kahramanındaki resmi fragman.
///
/// Başta yalnız YouTube kapağı + oynat düğmesi vardır (yer ayrılır, CLS yok,
/// sessiz autoplay yok). Dokununca webde iframe, Android/iOS'ta WebView
/// gömülür — YouTube uygulamasına gidilmez. Kaydırılıp ekrandan düşünce
/// gömme sökülür; ses arkada kalmaz.
class FragmanOynatici extends StatefulWidget {
  final String youtubeId;

  /// Null = gömme (web iframe / native WebView). Testte `false` verilirse
  /// [disariAc] çağrılır; üretimde varsayılan gömmedir.
  final bool? gomulu;

  /// Yalnız [gomulu] açıkça false iken. Testler boş fonksiyon verir ki
  /// `url_launcher` bağlama istemesin.
  final Future<void> Function(Uri uri)? disariAc;

  const FragmanOynatici({
    super.key,
    required this.youtubeId,
    this.gomulu,
    this.disariAc,
  });

  @override
  State<FragmanOynatici> createState() => _FragmanOynaticiState();
}

class _FragmanOynaticiState extends State<FragmanOynatici> {
  bool _oynuyor = false;

  bool get _gomulu => widget.gomulu ?? true;

  /// Fragmanı başlatır: gömme (uygulama içi). [gomulu] false ise yedek
  /// dışarı açma — üretim bunu kullanmaz.
  Future<void> _oynat() async {
    if (_gomulu) {
      setState(() => _oynuyor = true);
      return;
    }
    final ac = widget.disariAc ?? _youtubeAc;
    await ac(youtubeIzleUri(widget.youtubeId));
  }

  /// YouTube izleme adresini tarayıcı/uygulamada açar.
  Future<void> _youtubeAc(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Ekrandan kayınca iframe'i söker; aksi hâlde yorumlarda ses çalardı.
  void _gorunurluk(VisibilityInfo bilgi) {
    if (!mounted || !_oynuyor || bilgi.visibleFraction >= 0.35) return;
    setState(() => _oynuyor = false);
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('fragman-${widget.youtubeId}'),
      onVisibilityChanged: _gorunurluk,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: DiziRenkler.kart,
          child: _oynuyor && _gomulu
              ? FragmanGomucu(youtubeId: widget.youtubeId)
              : _kapak(),
        ),
      ),
    );
  }

  /// Kapak karesi + sarı oynat düğmesi (en az 44 dp).
  Widget _kapak() {
    final kapak = youtubeKapakUrl(widget.youtubeId);
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: kapak,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => const ColoredBox(color: Colors.black),
        ),
        const ColoredBox(color: Color(0x66000000)),
        Center(
          child: Semantics(
            button: true,
            label: 'Fragmanı oynat'.c,
            child: Material(
              color: DiziRenkler.sari,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _oynat,
                child: const SizedBox(
                  width: 56,
                  height: 56,
                  child: Icon(Icons.play_arrow, color: Colors.black, size: 36),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
