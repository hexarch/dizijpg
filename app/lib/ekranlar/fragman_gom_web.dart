import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:web/web.dart' as web;

import '../ceviri.dart';
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
  web.EventListener? _mesajDinleyici;
  Timer? _dinleme;
  bool _yukleniyor = true;
  bool _oynuyor = true;
  bool _sessiz = false;
  bool _oynatmakIstiyor = true;
  bool _altyazi = false;
  bool _basili2x = false;
  double _kaliciHiz = 1;
  Duration _konum = Duration.zero;
  Duration _sure = Duration.zero;
  Duration _tampon = Duration.zero;

  double get _hiz => _basili2x ? 2 : _kaliciHiz;

  @override
  void initState() {
    super.initState();
    _gorunumTipi = 'yt-${widget.youtubeId}-${identityHashCode(this)}';
    ui_web.platformViewRegistry.registerViewFactory(_gorunumTipi, (int id) {
      final iframe = web.HTMLIFrameElement()
        ..src = youtubeGommeUrl(
          widget.youtubeId,
          otomatik: true,
          dil: Ceviri.dil.value,
        )
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
    _mesajDinleyici = _mesaj.toJS;
    web.window.addEventListener('message', _mesajDinleyici!);
    WidgetsBinding.instance.addPostFrameCallback((_) => _dinlemeyiBaslat());
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted && _yukleniyor) setState(() => _yukleniyor = false);
    });
  }

  @override
  void dispose() {
    _dinleme?.cancel();
    final dinleyici = _mesajDinleyici;
    if (dinleyici != null) {
      web.window.removeEventListener('message', dinleyici);
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(FragmanGomucu eski) {
    super.didUpdateWidget(eski);
    if (eski.aktif != widget.aktif) _oynatmayiUygula();
  }

  /// IFrame API dinleyicisi: süre, tampon, konum YouTube'dan gelir.
  void _dinlemeyiBaslat() {
    _dinleme?.cancel();
    var kalan = 20;
    _dinleme = Timer.periodic(const Duration(milliseconds: 400), (t) {
      _posta({'event': 'listening', 'id': 1, 'channel': 'widget'});
      _komut('addEventListener', ['onStateChange']);
      kalan--;
      if (kalan <= 0) t.cancel();
    });
  }

  /// YouTube kökenli postMessage (süre / tampon / durum).
  void _mesaj(web.Event e) {
    final m = e as web.MessageEvent;
    final origin = m.origin;
    if (!origin.contains('youtube.com') &&
        !origin.contains('youtube-nocookie.com')) {
      return;
    }
    final data = m.data;
    if (data == null || !data.isA<JSString>()) return;
    Map<String, dynamic>? govde;
    try {
      final ham = jsonDecode((data as JSString).toDart);
      if (ham is Map<String, dynamic>) govde = ham;
    } catch (_) {
      return;
    }
    if (govde == null || !mounted) return;
    final olay = govde['event'] as String?;
    if (olay == 'onReady') {
      if (_yukleniyor) setState(() => _yukleniyor = false);
      _oynatmayiUygula();
      return;
    }
    if (olay == 'onStateChange') {
      final durum = govde['info'];
      if (durum is num) _durumUygula(durum.toInt());
      return;
    }
    if (olay != 'infoDelivery' && olay != 'initialDelivery') return;
    final info = govde['info'];
    if (info is! Map) return;
    var degisti = false;
    if (info['currentTime'] is num) {
      final konum = Duration(
        milliseconds: ((info['currentTime'] as num) * 1000).round(),
      );
      if (konum != _konum) {
        _konum = konum;
        degisti = true;
      }
    }
    if (info['duration'] is num) {
      final sure = Duration(
        milliseconds: ((info['duration'] as num) * 1000).round(),
      );
      if (sure > Duration.zero && sure != _sure) {
        _sure = sure;
        degisti = true;
      }
    }
    if (info['videoLoadedFraction'] is num && _sure > Duration.zero) {
      final tampon = Duration(
        milliseconds:
            ((info['videoLoadedFraction'] as num) * _sure.inMilliseconds)
                .round(),
      );
      if (tampon != _tampon) {
        _tampon = tampon;
        degisti = true;
      }
    }
    if (info['muted'] is bool && info['muted'] != _sessiz) {
      _sessiz = info['muted'] as bool;
      degisti = true;
    }
    if (info['playerState'] is num) {
      _durumUygula((info['playerState'] as num).toInt(), setStateYok: true);
      degisti = true;
    }
    if (_yukleniyor) {
      _yukleniyor = false;
      degisti = true;
    }
    if (degisti) setState(() {});
  }

  /// YouTube playerState: 1 oynuyor, 2 duraklat, 3 tampon, 0 bitti.
  void _durumUygula(int durum, {bool setStateYok = false}) {
    final oynuyor = durum == 1 || durum == 3;
    if (oynuyor == _oynuyor) return;
    _oynuyor = oynuyor;
    if (!setStateYok && mounted) setState(() {});
  }

  void _posta(Map<String, Object?> govde) {
    final iframe = _iframe;
    if (iframe == null) return;
    iframe.contentWindow?.postMessage(jsonEncode(govde).toJS, '*'.toJS);
  }

  /// IFrame API komutu (enablejsapi=1 şart).
  void _komut(String fn, [List<Object> args = const []]) {
    _posta({'event': 'command', 'func': fn, 'args': args});
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
    var hedef = s;
    if (hedef < Duration.zero) hedef = Duration.zero;
    if (_sure > Duration.zero && hedef > _sure) hedef = _sure;
    _komut('seekTo', [hedef.inMilliseconds / 1000, true]);
    setState(() => _konum = hedef);
  }

  void _ileri10() => _sar(_konum + const Duration(seconds: 10));

  void _geri10() => _sar(_konum - const Duration(seconds: 10));

  void _hizDegistir() {
    setState(() => _kaliciHiz = _kaliciHiz >= 1.5 ? 1 : 2);
    if (!_basili2x) _komut('setPlaybackRate', [_kaliciHiz]);
  }

  void _basiliTut(bool acik) {
    setState(() => _basili2x = acik);
    _komut('setPlaybackRate', [acik ? 2 : _kaliciHiz]);
  }

  void _altyaziDegistir() {
    final hedef = !_altyazi;
    final dil = Ceviri.dil.value;
    if (hedef) {
      _komut('loadModule', ['captions']);
      _komut('setOption', [
        'captions',
        'track',
        {'languageCode': dil},
      ]);
    } else {
      _komut('unloadModule', ['captions']);
    }
    setState(() => _altyazi = hedef);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(child: HtmlElementView(viewType: _gorunumTipi)),
        PointerInterceptor(
          child: FragmanKontrol(
            yukleniyor: _yukleniyor,
            oynuyor: _oynuyor,
            sessiz: _sessiz,
            altyazi: _altyazi,
            hiz: _hiz,
            konum: _konum,
            sure: _sure,
            tampon: _tampon,
            altBosluk: widget.altBosluk,
            onOynatDuraklat: _oynatDuraklat,
            onSessiz: _sessizDegistir,
            onAltyazi: _altyaziDegistir,
            onHiz: _hizDegistir,
            onGeri10: _geri10,
            onIleri10: _ileri10,
            onBasili2x: _basiliTut,
            onSarma: _sar,
          ),
        ),
      ],
    );
  }
}
