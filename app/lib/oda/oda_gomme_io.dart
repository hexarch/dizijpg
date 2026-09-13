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

import 'package:flutter/foundation.dart';
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

  /// ODA ŞU AN NEREDE — gömme AÇILIRKEN oradan başlasın diye.
  ///
  /// ===========================================================================
  /// NEDEN GEREKLİ (14 Eyl 2026)
  /// ===========================================================================
  /// Gömme daima 0'dan açılıyordu: yarısına gelinmiş bir filme giren kişinin
  /// oynatıcısı önce baştan açılıyor, sonra senkron düzelticisi onu 40 dakika
  /// ileri SARIYORDU. Sarma YouTube'un tamponunu komple attırıyor ve
  /// "kare donmuş" gibi görünen uzun bir tamponlama üretiyordu. `start=`
  /// parametresiyle oynatıcı DOĞRU yerden açılıyor, sarmaya hiç gerek kalmıyor.
  ///
  /// Geri çağırma (değer değil): yüzey kurtarma nöbetçisiyle yeniden
  /// kurulabiliyor ve o an okunan sabit bir sayı 12+ saniye BAYAT olurdu.
  final int Function()? baslangicSn;

  const OdaGommeYuzeyi({
    super.key,
    required this.baglanti,
    required this.denetci,
    this.baslangicSn,
  });

  @override
  State<OdaGommeYuzeyi> createState() => _OdaGommeYuzeyiState();
}

class _OdaGommeYuzeyiState extends State<OdaGommeYuzeyi> {
  WebViewController? _web;
  Timer? _kur;

  /// BU SAYFADAN en az bir durum raporu geldi mi.
  ///
  /// Enjekte döngüsünün duracağı an buna bakar, denetçinin
  /// `isInitialized`ına DEĞİL: yüzey yeniden kurulduğunda (kurtarma
  /// nöbetçisi) denetçi ZATEN "hazır" durumdadır ve döngü daha ilk turda
  /// kendini iptal ederdi — yeni WebView'e JS hiç enjekte edilmez, oynatıcı
  /// komut almayan ölü bir kutu olarak kalırdı.
  bool _rapor = false;

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

  /// Yüzey AYNI KALIP denetçi değişebilir (`GlobalKey` ile taşınan State).
  ///
  /// `initState` o durumda YENİDEN KOŞMAZ; kanca olmasaydı yeni denetçinin
  /// [OdaGommeDenetci.gonder]'i hiç dolmaz ve oynat/duraklat/sar komutları
  /// SESSİZCE düşerdi — ekranda "video donmuş" olarak görünür, hiçbir hata
  /// basılmaz.
  @override
  void didUpdateWidget(OdaGommeYuzeyi eski) {
    super.didUpdateWidget(eski);
    if (identical(eski.denetci, widget.denetci)) return;
    if (identical(eski.denetci.gonder, _komutIslet)) eski.denetci.gonder = null;
    widget.denetci.gonder = _komutIslet;
  }

  @override
  void dispose() {
    _kur?.cancel();
    if (identical(widget.denetci.gonder, _komutIslet)) {
      widget.denetci.gonder = null;
    }
    // ===========================================================================
    // WEBVIEW'İ ÖLDÜR — KENDİLİĞİNDEN ÖLMÜYOR (14 Eyl 2026)
    // ===========================================================================
    // `webview_flutter`ın `WebViewController`ında `dispose()` YOK: yerel WebView
    // ancak Dart nesnesi çöp toplanınca serbest kalıyor ve GC'nin ne zaman
    // koşacağı BELLİ DEĞİL. Yani odadan çıkan kullanıcının YouTube oynatıcısı
    // arkada CANLI kalıyor: ağı ve pili yiyor, sesi açıksa sesi de sürüyor ve
    // cihazın video kod çözücüsünü tutuyor. Kullanıcının bildirdiği belirti
    // tam buydu — *"odadan çıkıp ana sayfada gezip tekrar odaya girince yayın
    // devam etmiyor, uygulamayı kapatıp açınca düzeliyor"*: ikinci giriş yeni
    // bir oynatıcı kuruyor ama eskisi hâlâ ayakta.
    //
    // `about:blank` gezinme süzgecinden GEÇER (`odaGommeIstegiGuvenli`, `about`
    // şeması açıkça izinli). Önce videoyu elle durdurup kaynağını boşaltıyoruz:
    // sayfa değişimi kod çözücüyü her cihazda aynı hızda bırakmıyor.
    _web?.runJavaScript(_sondur).catchError((_) {});
    _web?.loadRequest(Uri.parse('about:blank')).catchError((_) {});
    _web = null;
    super.dispose();
  }

  Future<void> _denetciKur() async {
    // HATA AYIKLAMA DERLEMESİNDE WebView UZAKTAN İNCELENEBİLİR.
    //
    // 13 Eyl 2026'da siyah ekranın sebebi ancak `chrome://inspect` üzerinden
    // ölçülerek bulundu (`video` yüksekliği 0 px). Bayrak olmadan gömme
    // sayfası kapalı bir kutu; yalnız hata ayıklama derlemesinde açık, yayın
    // derlemesine hiç girmiyor.
    if (kDebugMode) {
      await AndroidWebViewController.enableDebugging(true);
    }
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
        onPageFinished: (_) {
          _rapor = false;
          _enjekteyiBaslat();
        },
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
        odaGommeUrl(
          widget.baglanti,
          dil: Ceviri.dil.value,
          otomatik: true,
          baslangicSn: widget.baslangicSn?.call() ?? 0,
        ),
      ),
      headers: const {'Referer': 'https://dizijpg.com/'},
    );
  }

  /// Sayfa bitince JS'i enjekte eder ve OYNATICI HAZIR DİYENE KADAR tekrarlar.
  ///
  /// Tek sefer yetmiyor: gömme sayfası kendi oynatıcısını `onPageFinished`
  /// sonrasında kuruyor, o ana kadar `<video>` DOM'da yok.
  ///
  /// SABİT PENCERE DEĞİL (7 Eyl 2026): web tarafında 8 saniyelik sabit pencere,
  /// yavaş açılışta el sıkışmasını tamamen kaçırıp oynatıcıyı hiç açmamıştı.
  /// Aynı hatayı burada da yapmamak için döngü "hazır" bildirimine kadar
  /// sürüyor (tavan 60 sn); hazır olunca ilk turda duruyor.
  void _enjekteyiBaslat() {
    _kur?.cancel();
    var kalan = 150;
    _kur = Timer.periodic(const Duration(milliseconds: 400), (t) {
      if (!mounted || _rapor) {
        t.cancel();
        return;
      }
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
    _rapor = true;
    widget.denetci.bildir(
      hazir: true,
      konumMs: m['t'] == null ? null : ((m['t'] as num) * 1000).round(),
      sureMs: m['d'] == null ? null : ((m['d'] as num) * 1000).round(),
      oynuyor: m['p'] as bool?,
      tamponluyor: m['w'] as bool?,
      sessiz: m['m'] as bool?,
    );
  }

  /// DOKUNUŞLAR FLUTTER'DA KALIR (web yüzeyiyle aynı gerekçe).
  ///
  /// WebView dokunuşu yutuyor ve altındaki YouTube kontrolleri tıklanabiliyor:
  /// izleyici oradan duraklatırsa oda senkronu bozulur ve düzeltici bir saniye
  /// sonra geri alır — kullanıcı "video zıplıyor" görür. Oynatmayı yalnız
  /// bizim kontrollerimiz ve sunucudaki oda durumu sürer.
  @override
  Widget build(BuildContext context) {
    final w = _web;
    if (w == null) return const ColoredBox(color: Colors.black);
    return IgnorePointer(child: _webGorunum(w));
  }

  /// ANDROID'DE HYBRID COMPOSITION ŞART (8 Eyl 2026, telefonda canlı görüldü).
  ///
  /// Varsayılan kip WebView'i bir SurfaceTexture'a KOPYALAR; donanım
  /// hızlandırmalı video ise ayrı yüzeyde çözülüyor ve o kopyaya girmiyor.
  /// Belirti: YouTube bağlantısı odada SES VERİYOR, GÖRÜNTÜ SİMSİYAH. Web'de
  /// (iframe) ve iOS'ta bu kip yok, emülatörde de çıkmadı — yalnız gerçek
  /// cihazda. Fragman oynatıcısı aynı tuzağı 1.65.0+113'te yaşamıştı
  /// (`ekranlar/fragman_gom_io.dart#_webGorunum`); bu kalıp oradan.
  Widget _webGorunum(WebViewController w) {
    if (w.platform is AndroidWebViewController) {
      return WebViewWidget.fromPlatformCreationParams(
        params: AndroidWebViewWidgetCreationParams(
          controller: w.platform,
          displayWithHybridComposition: true,
        ),
      );
    }
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
      '.ytp-chrome-top,.ytp-chrome-top-buttons,.ytp-gradient-top,',
      '.ytp-chrome-bottom,.ytp-gradient-bottom,.ytp-large-play-button,',
      '.ytp-pause-overlay,.ytp-pause-overlay-container,.ytp-ce-element,',
      '.ytp-watermark,.ytp-show-cards-title,.ytp-cards-teaser,',
      // BİTİŞ EKRANI (7 Eyl 2026, iOS'ta canlı görüldü): video bitince
      // YouTube başlık + kanal + "tekrar oynat" + logo + paylaş kartını
      // ortaya basıyor. Oynarken görünmediği için ilk turda kaçmıştı.
      '.ytp-endscreen-content,.html5-endscreen,.ytp-player-content,',
      '.ytp-title,.ytp-title-text,.ytp-title-channel,.ytp-title-link,',
      '.ytp-youtube-button,.ytp-share-button,.ytp-copylink-button,',
      '.ytp-watch-later-button,.ytp-cued-thumbnail-overlay,',
      '.ytp-suggestion-set,.ytp-scroll-min,.branding-img-container,',
      '.annotation,.ytp-spinner,',
      '.vp-title,.vp-controls,.vp-sidedock,.vp-overlay-cell,.vp-outro',
      '{display:none!important;}',
      // KESİN KURAL — sınıf adı kovalamayı bırakan satır (7 Eyl 2026).
      //
      // NOT (iOS, ölçüldü): bu kural DOM kromunu gerçekten temizliyor —
      // enjekte edilen teşhis, oynatıcının görünür tek çocuğunun altyazı
      // penceresi olduğunu bildirdi. Buna rağmen video DURAKLATILDIĞINDA
      // iOS ekrana kendi yerel katmanını basıyor (başlık, kanal kapağı,
      // YouTube logosu, duraklat simgesi). O katman DOM'da DEĞİL, dolayısıyla
      // CSS ile kaldırılamıyor; yalnız duraklama anında görünüyor.
      // Yukarıdaki liste YouTube'un duraklama/bitiş kartını iOS'ta
      // yakalayamadı (başlık, kanal, tekrar oynat, HD rozeti, logo, paylaş
      // hâlâ görünüyordu) ve her sürümde sınıf adı değişebiliyor. Bu kural
      // oynatıcının BÜTÜN çocuklarını gizliyor; yalnız videonun kabı ve
      // altyazı penceresi kalıyor. Yeni bir krom parçası eklenirse
      // kendiliğinden gizlenmiş oluyor.
      '.html5-video-player > *:not(.html5-video-container)',
      ':not(.ytp-caption-window-container){display:none!important;}',
      'html,body{width:100%!important;height:100%!important;',
      'margin:0!important;padding:0!important;overflow:hidden!important;',
      'background:#000!important;}',
      // ***KAPLARA YÜKSEKLİK VERMEK ŞART — YOKSA VİDEO 0 PİKSEL OLUR.***
      //
      // 13 Eyl 2026, emülatörde CDP ile ÖLÇÜLDÜ: `video` 406×**0**,
      // `.html5-video-container` 406×**0**. Belirti tam olarak kullanıcının
      // bildirdiği şeydi — ses akıyor, `currentTime` ilerliyor, `readyState`
      // 4, ama ekran SİMSİYAH.
      //
      // Sebep aşağıdaki `video{position:absolute;height:100%}` kuralının
      // kendisi: mutlak konumlu bir öğenin yüzdesi, konumlanmış en yakın
      // atasına (`.html5-video-container`, `position:relative`) göre çözülür.
      // O kabın yüksekliği `auto` ve İÇİNDEKİ TEK ÖĞE akıştan çıkmış video
      // olduğu için kap 0 oluyor; video da 0'ın %100'ü, yani 0. Döngü kendini
      // besliyor ve hiçbir hata vermiyor.
      //
      // Fragman oynatıcısı bu iki satırı 4 Eyl 2026'dan beri taşıyor
      // (`ekranlar/fragman_gom_io.dart#_gizleJs`); oda kopyalanırken YALNIZ
      // bunlar atlanmıştı. 8 Eyl'de siyahlık Hybrid Composition'a yorulup
      // öyle "düzeltilmişti" — o değişiklik yanlış değil ama siyahlığın
      // sebebi O DEĞİLDİ, bu yüzden telefonda siyah ekran sürdü.
      '#player,.html5-video-player,.html5-video-container',
      '{width:100%!important;height:100%!important;margin:0!important;',
      'padding:0!important;overflow:hidden!important;background:#000!important;}',
      '.html5-video-container{position:absolute!important;top:0!important;',
      'left:0!important;}',
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
  // GÖVDE DÜZEYİNDEKİ KROM — CSS'in ULAŞAMADIĞI YER (13 Eyl 2026).
  //
  // YouTube'un mobil gömmesi kendi arayüzünü oynatıcının İÇİNDE değil,
  // doğrudan `<body>` altında kuruyor: `#player-controls` → kapak resmi,
  // dev "oynat" düğmesi, başlık, kanal adı + logosu, paylaş ve "İzlemek
  // için YouTube" şeridi. Sınıf adları da artık `ytp-*` değil `ytm*`
  // (13 Eyl 2026'da emülatörde DOM'dan okundu). Yukarıdaki
  // `.html5-video-player > *` kuralı oynatıcının İÇİNİ temizliyor ama bu
  // katmana hiç değmiyordu — kullanıcının "tasarımlar iç içe geçmiş"
  // dediği görüntü tam olarak buydu.
  //
  // SINIF ADI KOVALAMIYORUZ: kural yapısal — VİDEOYU TAŞIMAYAN her gövde
  // çocuğu gizlenir. YouTube yarın arayüzü yeniden adlandırsa da geçerli.
  var odaSupur = function(){
    var e = document.querySelector('video');
    if (!e || !document.body) return;
    var c = document.body.children;
    for (var i = 0; i < c.length; i++) {
      var el = c[i];
      var t = el.tagName;
      if (t === 'SCRIPT' || t === 'STYLE' || t === 'NOSCRIPT' || t === 'LINK') continue;
      if (el.contains(e)) continue;
      el.style.setProperty('display', 'none', 'important');
    }
  };
  odaSupur();
  if (window.__odaKur) return;
  window.__odaKur = true;
  // Enjekte döngüsü "hazır" haberiyle duruyor; YouTube ise kromu SONRADAN da
  // ekliyor (duraklatma kartı, bitiş ekranı). Gözlemci o yüzden kalıcı.
  try {
    new MutationObserver(odaSupur).observe(document.body, {childList: true});
  } catch (_) {}
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
  window.__odaRapor = setInterval(yolla, 250);
  v.addEventListener('timeupdate', yolla);
  v.addEventListener('play', yolla);
  v.addEventListener('pause', yolla);
  yolla();
})();
''';

/// Yüzey sökülürken çalıştırılan kapatma betiği.
///
/// Yalnız `about:blank`e gitmek YETMİYOR: bazı cihazlarda gezinme tamamlanana
/// kadar eski oynatıcı kod çözücüyü bırakmıyor. Videoyu önce durdurup
/// kaynağını boşaltmak bırakmayı ANINDA tetikliyor. Her adım ayrı `try`:
/// sayfa çoktan boşalmışsa ilk satırın atacağı hata ötekileri de yutardı.
const _sondur = r'''
(function(){
  try { if (window.__odaRapor) { clearInterval(window.__odaRapor); window.__odaRapor = 0; } } catch (e) {}
  try {
    var v = document.querySelector('video');
    if (v) { v.pause(); v.removeAttribute('src'); v.load(); }
  } catch (e) {}
})();
''';
