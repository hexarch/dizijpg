import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../ceviri.dart';
import '../tema.dart';
import '../tmdb_fragman.dart';
import 'fragman_kontrol.dart';

/// Android/iOS: YouTube gömme yüzeyi + bizim kontrol çubuğu.
///
/// YouTube ham MP4 vermez (imza/WASM); `video_player` googlevideo'da 403
/// yer. Gömme sayfasındaki `<video>` dolar, YouTube kromu CSS ile silinir,
/// dokunuşlar Flutter'dadır — kaydırıcı WebView'i yutmaz, oynatıcı
/// sökülmeden duraklar.
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
  WebViewController? _denetci;
  bool _yukleniyor = true;
  bool _hata = false;
  bool _oynuyor = true;
  bool _sessiz = false;
  bool _oynatmakIstiyor = true;
  bool _altyazi = false;
  bool _basili2x = false;
  double _kaliciHiz = 1;
  Duration _konum = Duration.zero;
  Duration _sure = Duration.zero;
  Duration _tampon = Duration.zero;
  Timer? _boya;

  /// `flutter test` VM'de platform WebView yok; kapağı söktükten sonra
  /// siyah kutu yeter. Entegrasyon testleri gerçek WebView kullanır.
  bool get _otomatikTest =>
      WidgetsBinding.instance.runtimeType.toString() ==
      'AutomatedTestWidgetsFlutterBinding';

  double get _hiz => _basili2x ? 2 : _kaliciHiz;

  @override
  void initState() {
    super.initState();
    if (_otomatikTest) return;
    _denetciKur();
  }

  @override
  void dispose() {
    _boya?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(FragmanGomucu eski) {
    super.didUpdateWidget(eski);
    if (_otomatikTest) return;
    if (eski.youtubeId != widget.youtubeId) {
      _oynatmakIstiyor = true;
      _yukle();
      return;
    }
    if (eski.aktif != widget.aktif) _oynatmayiUygula();
  }

  /// Aktif karede ve kullanıcı duraklatmadıysa oynat; değilse duraklat.
  void _oynatmayiUygula() {
    if (widget.aktif && _oynatmakIstiyor) {
      _js('fragmanOynat()');
    } else {
      _js('fragmanDuraklat()');
      if (mounted) setState(() => _oynuyor = false);
    }
  }

  /// WebView'i kurar: satır içi oynatma, Referer (Error 153), uygulama
  /// kaçışını kesme. Kullanıcı aracısı yüklemeden ÖNCE set edilir.
  Future<void> _denetciKur() async {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final denetci = WebViewController.fromPlatformCreationParams(params);
    await denetci.setJavaScriptMode(JavaScriptMode.unrestricted);
    await denetci.setBackgroundColor(Colors.black);
    await denetci.addJavaScriptChannel('Fragman', onMessageReceived: _kanal);
    await denetci.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (istek) {
          return fragmanGommeIstek(istek.url)
              ? NavigationDecision.navigate
              : NavigationDecision.prevent;
        },
        onPageFinished: (_) {
          _boya?.cancel();
          _boya = Timer.periodic(const Duration(milliseconds: 400), (_) {
            _js(_gizleJs);
          });
          Future<void>.delayed(const Duration(seconds: 8), () {
            _boya?.cancel();
            _boya = null;
          });
          _js(_gizleJs);
          if (!mounted) return;
          setState(() => _yukleniyor = false);
          _oynatmayiUygula();
        },
        onWebResourceError: (hata) {
          if (hata.isForMainFrame != true || !mounted) return;
          setState(() {
            _hata = true;
            _yukleniyor = false;
          });
        },
      ),
    );

    final android = denetci.platform;
    if (android is AndroidWebViewController) {
      await android.setMediaPlaybackRequiresUserGesture(false);
      // WebView UA'sındaki "; wv" YouTube Error 153 üretir.
      await denetci.setUserAgent(
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
      );
    }

    if (!mounted) return;
    setState(() => _denetci = denetci);
    _yukle();
  }

  /// Gömme adresini Referer ile yükler (YouTube Error 153).
  void _yukle() {
    final denetci = _denetci;
    if (denetci == null) return;
    setState(() {
      _yukleniyor = true;
      _hata = false;
      _konum = Duration.zero;
      _sure = Duration.zero;
      _tampon = Duration.zero;
      _oynuyor = true;
      _altyazi = false;
      _basili2x = false;
      _kaliciHiz = 1;
    });
    denetci.loadRequest(
      Uri.parse(
        youtubeGommeUrl(
          widget.youtubeId,
          otomatik: true,
          gizlilikDostu: false,
          dil: Ceviri.dil.value,
        ),
      ),
      headers: const {'Referer': 'https://dizijpg.com/'},
    );
  }

  /// Hata sonrası aynı gömmeyi yeniden dener.
  void _tekrar() {
    _yukle();
  }

  /// `<video>` zaman damgası (JS kanalı).
  void _kanal(JavaScriptMessage msg) {
    Map<String, dynamic>? m;
    try {
      final ham = jsonDecode(msg.message);
      if (ham is Map<String, dynamic>) m = ham;
    } catch (_) {
      return;
    }
    if (m == null || !mounted) return;
    final t = ((m['t'] as num?)?.toDouble() ?? 0) * 1000;
    final d = ((m['d'] as num?)?.toDouble() ?? 0) * 1000;
    final b = ((m['b'] as num?)?.toDouble() ?? 0) * 1000;
    final p = m['p'] == true;
    final sessiz = m['m'] == true;
    final konum = Duration(milliseconds: t.round());
    final sure = Duration(milliseconds: d.round());
    final tampon = Duration(milliseconds: b.round());
    if (konum == _konum &&
        sure == _sure &&
        tampon == _tampon &&
        p == _oynuyor &&
        sessiz == _sessiz) {
      return;
    }
    setState(() {
      _konum = konum;
      if (sure > Duration.zero) _sure = sure;
      _tampon = tampon;
      _oynuyor = p;
      _sessiz = sessiz;
    });
  }

  Future<void> _js(String kod) async {
    final denetci = _denetci;
    if (denetci == null) return;
    try {
      await denetci.runJavaScript(kod);
    } catch (_) {}
  }

  /// Android'de video SurfaceTexture'te siyah kalır; Hybrid Composition şart.
  Widget _webGorunum(WebViewController denetci) {
    if (denetci.platform is AndroidWebViewController) {
      return WebViewWidget.fromPlatformCreationParams(
        params: AndroidWebViewWidgetCreationParams(
          controller: denetci.platform,
          displayWithHybridComposition: true,
        ),
      );
    }
    return WebViewWidget(controller: denetci);
  }

  void _oynatDuraklat() {
    _oynatmakIstiyor = !_oynuyor;
    if (_oynatmakIstiyor) {
      _js('fragmanOynat()');
    } else {
      _js('fragmanDuraklat()');
    }
  }

  void _sessizDegistir() {
    final hedef = !_sessiz;
    _js('fragmanSessiz(${hedef ? 'true' : 'false'})');
    setState(() => _sessiz = hedef);
  }

  void _sar(Duration s) {
    var hedef = s;
    if (hedef < Duration.zero) hedef = Duration.zero;
    if (_sure > Duration.zero && hedef > _sure) hedef = _sure;
    _js('fragmanSar(${hedef.inMilliseconds / 1000})');
    setState(() => _konum = hedef);
  }

  void _ileri10() => _sar(_konum + const Duration(seconds: 10));

  void _geri10() => _sar(_konum - const Duration(seconds: 10));

  void _hizDegistir() {
    setState(() => _kaliciHiz = _kaliciHiz >= 1.5 ? 1 : 2);
    if (!_basili2x) _js('fragmanHiz($_kaliciHiz)');
  }

  void _basiliTut(bool acik) {
    setState(() => _basili2x = acik);
    _js('fragmanHiz(${acik ? 2 : _kaliciHiz})');
  }

  void _altyaziDegistir() {
    final hedef = !_altyazi;
    final dil = Ceviri.dil.value.replaceAll(RegExp(r'[^a-z]'), '');
    _js("fragmanAltyazi(${hedef ? 'true' : 'false'}, '$dil')");
    setState(() => _altyazi = hedef);
  }

  @override
  Widget build(BuildContext context) {
    if (_otomatikTest) {
      return const ColoredBox(color: Colors.black);
    }
    final denetci = _denetci;
    if (denetci == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: DiziRenkler.sari),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        // Dokunuş Flutter'da kalsın: kaydırıcı WebView pan'ini yutmasın.
        IgnorePointer(child: _webGorunum(denetci)),
        if (_hata)
          ColoredBox(
            color: Colors.black,
            child: Center(
              child: TextButton(
                onPressed: _tekrar,
                child: Text('Tekrar dene'.c),
              ),
            ),
          )
        else
          FragmanKontrol(
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
      ],
    );
  }
}

/// YouTube kromunu siler, `<video>`yu doldurur, zamanı kanala basar.
/// Altyazı penceresi gizlenmez; çubuğun üstüne kaydırılır.
const _gizleJs = r'''
(function(){
  var st = document.getElementById('fragman-css');
  if (!st) {
    st = document.createElement('style');
    st.id = 'fragman-css';
    st.textContent = [
      '.ytp-chrome-top,.ytp-gradient-top,.ytp-show-cards-title,',
      '.ytp-watermark,.ytp-pause-overlay,.ytp-paid-content-overlay,',
      '.ytp-ce-element,.ytp-endscreen-content,.ytp-scroll-min,',
      '.branding-img-container,.ytp-title,.ytp-title-channel,',
      '.ytp-chrome-top-buttons,.ytp-cards-teaser,.ytp-impression-link,',
      '.ytp-youtube-button,.ytp-share-button,.ytp-watch-later-button,',
      '.ytp-chrome-bottom,.ytp-gradient-bottom,.ytp-show-tiles,',
      '.ytp-large-play-button,.ytp-cued-thumbnail-overlay,',
      '.ytp-overflow-panel,.ytp-menuitem,.annotation',
      '{display:none!important;visibility:hidden!important;}',
      'html,body,#player,#player-api,.html5-video-player,.html5-video-container',
      '{width:100%!important;height:100%!important;margin:0!important;',
      'padding:0!important;overflow:hidden!important;background:#000!important;}',
      'video{width:100%!important;height:100%!important;object-fit:contain!important;}',
      '.ytp-caption-window-container,.caption-window{bottom:72px!important;}',
      '.ytp-caption-window-bottom{margin-bottom:56px!important;}'
    ].join('');
    (document.head || document.documentElement).appendChild(st);
  }
  function video(){ return document.querySelector('video'); }
  function player(){
    return document.getElementById('movie_player') ||
      document.querySelector('.html5-video-player');
  }
  if (typeof window.__fragmanHiz !== 'number') window.__fragmanHiz = 1;
  window.fragmanOynat = function(){ var v=video(); if(v){ v.play(); } };
  window.fragmanDuraklat = function(){ var v=video(); if(v){ v.pause(); } };
  window.fragmanSar = function(s){ var v=video(); if(v){ v.currentTime=s; } };
  window.fragmanSessiz = function(m){ var v=video(); if(v){ v.muted=!!m; } };
  window.fragmanHiz = function(r){
    window.__fragmanHiz = r;
    var v=video();
    if(v){ v.playbackRate = r; }
  };
  window.fragmanAltyazi = function(acik, dil){
    var p = player();
    if (p) {
      try {
        if (acik) {
          if (typeof p.loadModule === 'function') p.loadModule('captions');
          if (typeof p.setOption === 'function') {
            p.setOption('captions', 'track', {languageCode: dil || 'tr'});
          }
        } else if (typeof p.unloadModule === 'function') {
          p.unloadModule('captions');
        }
      } catch (e) {}
    }
    var v = video();
    if (!v || !v.textTracks) return;
    var dilK = (dil || '').toLowerCase();
    var aday = -1;
    for (var i = 0; i < v.textTracks.length; i++) {
      var lang = (v.textTracks[i].language || '').toLowerCase();
      if (dilK && lang.indexOf(dilK) === 0) { aday = i; break; }
    }
    if (aday < 0 && v.textTracks.length) aday = 0;
    for (var j = 0; j < v.textTracks.length; j++) {
      v.textTracks[j].mode = acik ? (j === aday ? 'showing' : 'hidden') : 'disabled';
    }
  };
  function nabiz(){
    var v = video();
    if (v && v.playbackRate !== window.__fragmanHiz) {
      v.playbackRate = window.__fragmanHiz;
    }
    if (v && window.Fragman) {
      var b = 0;
      if (v.buffered && v.buffered.length) {
        b = v.buffered.end(v.buffered.length - 1);
      }
      window.Fragman.postMessage(JSON.stringify({
        t: v.currentTime || 0,
        d: isFinite(v.duration) ? v.duration : 0,
        b: b,
        p: !v.paused && !v.ended,
        m: !!v.muted
      }));
    }
  }
  nabiz();
  if (!window.__fragmanNabiz) {
    window.__fragmanNabiz = setInterval(nabiz, 250);
  }
})();
''';
