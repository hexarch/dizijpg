import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../tmdb_fragman.dart';

/// Web: YouTube iframe (youtube-nocookie). Görünüm tipi örneğe özgüdür —
/// aynı factory iki kez kaydedilirse Flutter atar.
class FragmanGomucu extends StatefulWidget {
  final String youtubeId;

  const FragmanGomucu({super.key, required this.youtubeId});

  @override
  State<FragmanGomucu> createState() => _FragmanGomucuState();
}

class _FragmanGomucuState extends State<FragmanGomucu> {
  late final String _gorunumTipi;

  @override
  void initState() {
    super.initState();
    _gorunumTipi = 'yt-${widget.youtubeId}-${identityHashCode(this)}';
    ui_web.platformViewRegistry.registerViewFactory(_gorunumTipi, (int id) {
      final iframe = web.HTMLIFrameElement()
        ..src = youtubeGommeUrl(widget.youtubeId, otomatik: true)
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow =
            'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; fullscreen'
        ..allowFullscreen = true;
      iframe.setAttribute('referrerpolicy', 'strict-origin-when-cross-origin');
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _gorunumTipi);
  }
}
