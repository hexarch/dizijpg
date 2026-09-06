/// İZLEME ODASI — GÖMME YÜZEYİ (Android / iOS).
///
/// ===========================================================================
/// MOBİLDE PROTOKOL YOK: DOĞRUDAN `<video>`
/// ===========================================================================
/// Web'de gömme çapraz kökenli bir iframe olduğu için her sağlayıcının kendi
/// `postMessage` protokolü konuşulmak zorunda. Mobilde WebView gömme
/// sayfasının KENDİSİNİ yüklüyor: sayfa artık üst belge, yani
/// `document.querySelector('video')` doğrudan elimizde.
///
/// Bu yüzden burada sağlayıcıya göre DALLANMA YOK — YouTube da Vimeo da aynı
/// beş satırla sürülüyor. Kalıp yeni değil: `ekranlar/fragman_gom_io.dart`
/// fragman oynatıcısını 4 Eyl 2026'dan beri böyle sürüyor.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../ceviri.dart';
import 'oda_baglanti.dart';
import 'oda_oynatici.dart';

class OdaGommeYuzeyi extends StatefulWidget {
  final OdaBaglanti baglanti;
  final OdaGommeDenetci denetci;

  const OdaGommeYuzeyi({
    super.key,
    required this.baglanti,
    required this.denetci,
  });

  @override
  State<OdaGommeYuzeyi> createState() => _OdaGommeYuzeyiState();
}

class _OdaGommeYuzeyiState extends State<OdaGommeYuzeyi> {
  WebViewController? _web;
  Timer? _kur;

  /// `flutter test` VM'de platform WebView YOK: `WebViewController` kurmak
  /// orada assert atıyor ve odanın bağlantı kipini sınayan her widget testi
  /// çöküyordu (7 Eyl 2026'da tam bu testte yakalandı). Siyah kutu yeter —
  /// entegrasyon testleri gerçek WebView kullanır.
  ///
  /// Kalıp `ekranlar/fragman_gom_io.dart`taki `_otomatikTest` ile aynı.
  bool get _otomatikTest =>
      WidgetsBinding.instance.runtimeType.toString() ==
      'AutomatedTestWidgetsFlutterBinding';

  @override
  void initState() {
    super.initState();
    widget.denetci.gonder = _komutIslet;
    if (_otomatikTest) return;
    _denetciKur();
  }

  @override
  void dispose() {
    _kur?.cancel();
    if (identical(widget.denetci.gonder, _komutIslet)) {
      widget.denetci.gonder = null;
    }
    super.dispose();
  }

  Future<void> _denetciKur() async {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        // Satır içi oynatma olmadan iOS videoyu KENDİ tam ekranında açar;
        // orada bizim kontrollerimiz de senkron da yoktur.
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }
    final w = WebViewController.fromPlatformCreationParams(params);
    await w.setJavaScriptMode(JavaScriptMode.unrestricted);
    await w.setBackgroundColor(Colors.black);
    await w.addJavaScriptChannel('Oda', onMessageReceived: _kanal);
    await w.setNavigationDelegate(
      NavigationDelegate(
        // GÖMME DIŞINA ÇIKIŞ YOK: "YouTube'da izle" bağlantısı ya da bir
        // reklam, WebView'i odadan çıkarıp keyfi bir sayfaya götürebilirdi.
        onNavigationRequest: (istek) => odaGommeIstegiGuvenli(istek.url)
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
        onPageFinished: (_) => _enjekteyiBaslat(),
        onWebResourceError: (h) {
          if (h.isForMainFrame == true) widget.denetci.bildir(hazir: false);
        },
      ),
    );
    final p = w.platform;
    if (p is AndroidWebViewController) {
      await p.setMediaPlaybackRequiresUserGesture(false);
      // WebView kullanıcı aracısındaki "; wv" YouTube'da Error 153 üretir.
      await w.setUserAgent(
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
      );
    }
    if (!mounted) return;
    setState(() => _web = w);
    await w.loadRequest(
      Uri.parse(
        odaGommeUrl(widget.baglanti, dil: Ceviri.dil.value, otomatik: true),
      ),
      headers: const {'Referer': 'https://dizijpg.com/'},
    );
  }

  /// Sayfa bitince JS'i enjekte eder ve BİR SÜRE TEKRARLAR.
  ///
  /// Tek sefer yetmiyor: YouTube gömmesi kendi oynatıcısını `onPageFinished`
  /// sonrasında kuruyor, o ana kadar `<video>` DOM'da yok. 400 ms'de bir 20
  /// tur (8 sn) deneniyor; ilk başarılı turda `hazir` bildirimi geliyor.
  void _enjekteyiBaslat() {
    _kur?.cancel();
    var kalan = 20;
    _kur = Timer.periodic(const Duration(milliseconds: 400), (t) {
      _js(_enjekte);
      kalan--;
      if (kalan <= 0) t.cancel();
    });
    _js(_enjekte);
  }

  void _js(String kod) {
    _web?.runJavaScript(kod).catchError((_) {});
  }

  void _komutIslet(String komut, Object? arg) {
    switch (komut) {
      case 'oynat':
        _js('odaOynat()');
      case 'duraklat':
        _js('odaDuraklat()');
      case 'sar':
        _js('odaSar(${(arg as num).toDouble()})');
      case 'hiz':
        _js('odaHiz(${(arg as num).toDouble()})');
      case 'ses':
        _js('odaSessiz(${arg == true})');
    }
  }

  void _kanal(JavaScriptMessage msg) {
    Map<String, dynamic>? m;
    try {
      final ham = jsonDecode(msg.message);
      if (ham is Map<String, dynamic>) m = ham;
    } catch (_) {
      return;
    }
    if (m == null || !mounted) return;
    widget.denetci.bildir(
      hazir: true,
      konumMs: m['t'] == null ? null : ((m['t'] as num) * 1000).round(),
      sureMs: m['d'] == null ? null : ((m['d'] as num) * 1000).round(),
      oynuyor: m['p'] as bool?,
      tamponluyor: m['w'] as bool?,
      sessiz: m['m'] as bool?,
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = _web;
    if (w == null) return const ColoredBox(color: Colors.black);
    return WebViewWidget(controller: w);
  }
}

/// WebView'in gitmesine izin verilen adresler.
///
/// `intent:`/`market:` şemaları WebView'i UYGULAMADAN ATAR (YouTube uygulaması
/// açılır) — kullanıcı odadan düşer. İzin YALNIZ oynatıcının kendi alan
/// adlarına ve doğrudan video adreslerine verilir.
bool odaGommeIstegiGuvenli(String url) {
  final kucuk = url.trim().toLowerCase();
  if (kucuk.isEmpty) return false;
  for (final kotu in ['intent:', 'market:', 'youtube:', 'vnd.', 'itms']) {
    if (kucuk.startsWith(kotu)) return false;
  }
  final u = Uri.tryParse(url);
  if (u == null) return false;
  final sema = u.scheme.toLowerCase();
  if (sema == 'about' || sema == 'data' || sema == 'blob') return true;
  if (sema != 'https' && sema != 'http') return false;
  final host = u.host.toLowerCase();
  const kokler = [
    'youtube.com',
    'youtube-nocookie.com',
    'youtu.be',
    'ytimg.com',
    'googlevideo.com',
    'ggpht.com',
    'google.com',
    'googleapis.com',
    'gstatic.com',
    'googleusercontent.com',
    'doubleclick.net',
    'vimeo.com',
    'vimeocdn.com',
    'akamaized.net',
  ];
  var izinli = false;
  for (final k in kokler) {
    if (host == k || host.endsWith('.$k')) {
      izinli = true;
      break;
    }
  }
  if (!izinli) return false;
  // `/watch` ve `/shorts` gömme DEĞİL izleme sayfasıdır: oraya gitmek
  // oynatıcıyı kaybettirir.
  if (host.endsWith('youtube.com')) {
    final yol = u.path.toLowerCase();
    if (yol.contains('/watch') ||
        yol.contains('/shorts') ||
        yol.contains('/redirect')) {
      return false;
    }
  }
  return true;
}

/// Sayfaya enjekte edilen kumanda.
///
/// Sağlayıcı kromu CSS ile gizlenir (aynı belge olduğu için bu MÜMKÜN — web'de
/// değil). Durum 250 ms'de bir kanaldan akar: `timeupdate` yalnız oynarken
/// ateşlendiği için tek başına yetmiyor, duraklatılmışken sahibin sarması
/// izleyicide görünmezdi.
const _enjekte = r'''
(function(){
  var v = document.querySelector('video');
  if (!v) return;
  if (!document.getElementById('oda-css')) {
    var st = document.createElement('style');
    st.id = 'oda-css';
    st.textContent = [
      '.ytp-chrome-top,.ytp-gradient-top,.ytp-chrome-bottom,',
      '.ytp-gradient-bottom,.ytp-large-play-button,.ytp-pause-overlay,',
      '.ytp-ce-element,.ytp-watermark,.ytp-show-cards-title,',
      '.vp-title,.vp-controls,.vp-sidedock,.vp-overlay-cell',
      '{display:none!important;}',
      'html,body{margin:0!important;padding:0!important;overflow:hidden!important;background:#000!important;}',
      'video{position:absolute!important;top:0!important;left:0!important;',
      'width:100%!important;height:100%!important;object-fit:contain!important;}'
    ].join('');
    (document.head || document.documentElement).appendChild(st);
  }
  window.odaOynat = function(){ var e=document.querySelector('video'); if(e) e.play(); };
  window.odaDuraklat = function(){ var e=document.querySelector('video'); if(e) e.pause(); };
  window.odaSar = function(s){ var e=document.querySelector('video'); if(e) e.currentTime = s; };
  window.odaHiz = function(r){ var e=document.querySelector('video'); if(e) e.playbackRate = r; };
  window.odaSessiz = function(m){ var e=document.querySelector('video'); if(e){ e.muted = !!m; if(!m) e.volume = 1; } };
  if (window.__odaKur) return;
  window.__odaKur = true;
  var yolla = function(){
    var e = document.querySelector('video');
    if (!e || !window.Oda) return;
    var tampon = 0;
    try { if (e.buffered && e.buffered.length) tampon = e.buffered.end(e.buffered.length-1); } catch(_) {}
    window.Oda.postMessage(JSON.stringify({
      t: e.currentTime || 0,
      d: isFinite(e.duration) ? e.duration : 0,
      p: !e.paused,
      w: e.readyState < 3 && !e.paused,
      m: !!e.muted,
      b: tampon
    }));
  };
  setInterval(yolla, 250);
  v.addEventListener('timeupdate', yolla);
  v.addEventListener('play', yolla);
  v.addEventListener('pause', yolla);
  yolla();
})();
''';
