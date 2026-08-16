import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:web/web.dart' as web;

import '../tmdb_fragman.dart';
import 'fragman_kontrol.dart';

/// Web: YouTube iframe (youtube-nocookie) + bizim krom.
///
/// iframe dokunuşu yutar; [IgnorePointer] + [PointerInterceptor] ile
/// kaydırma ve oynat/duraklat Flutter'da kalır. Kaydırınca postMessage
/// ile duraklar — sökülmez, başa sarımaz.
class FragmanGomucu extends StatefulWidget {
  final String youtubeId;
  final bool aktif;
  final double altBosluk;

  const FragmanGomucu({
    super.key,
    required this.youtubeId,
    this.aktif = true,
    this.altBosluk = 8,
  });

  @override
  State<FragmanGomucu> createState() => _FragmanGomucuState();
}

class _FragmanGomucuState extends State<FragmanGomucu> {
  late final String _gorunumTipi;
  web.HTMLIFrameElement? _iframe;
  bool _oynuyor = true;
  bool _sessiz = false;
  bool _oynatmakIstiyor = true;
  Duration _konum = Duration.zero;

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
      _iframe = iframe;
      return iframe;
    });
  }

  @override
  void didUpdateWidget(FragmanGomucu eski) {
    super.didUpdateWidget(eski);
    if (eski.aktif != widget.aktif) _oynatmayiUygula();
  }

  /// IFrame API komutu (enablejsapi=1 şart).
  void _komut(String fn, [List<Object> args = const []]) {
    final iframe = _iframe;
    if (iframe == null) return;
    iframe.contentWindow?.postMessage(
      jsonEncode({'event': 'command', 'func': fn, 'args': args}).toJS,
      '*'.toJS,
    );
  }

  void _oynatmayiUygula() {
    if (widget.aktif && _oynatmakIstiyor) {
      _komut('playVideo');
      if (mounted) setState(() => _oynuyor = true);
    } else {
      _komut('pauseVideo');
      if (mounted) setState(() => _oynuyor = false);
    }
  }

  void _oynatDuraklat() {
    _oynatmakIstiyor = !_oynuyor;
    if (_oynatmakIstiyor) {
      _komut('playVideo');
      setState(() => _oynuyor = true);
    } else {
      _komut('pauseVideo');
      setState(() => _oynuyor = false);
    }
  }

  void _sessizDegistir() {
    final hedef = !_sessiz;
    _komut(hedef ? 'mute' : 'unMute');
    setState(() => _sessiz = hedef);
  }

  void _sar(Duration s) {
    _komut('seekTo', [s.inMilliseconds / 1000, true]);
    setState(() => _konum = s);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(child: HtmlElementView(viewType: _gorunumTipi)),
        PointerInterceptor(
          child: FragmanKontrol(
            yukleniyor: false,
            oynuyor: _oynuyor,
            sessiz: _sessiz,
            konum: _konum,
            sure: Duration.zero,
            altBosluk: widget.altBosluk,
            onOynatDuraklat: _oynatDuraklat,
            onSessiz: _sessizDegistir,
            onSarma: _sar,
          ),
        ),
      ],
    );
  }
}
