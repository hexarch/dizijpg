import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../ceviri.dart';
import '../tema.dart';
import '../tmdb_fragman.dart';

/// Android/iOS: YouTube gömme WebView. `intent://` ve izleme sayfası
/// YouTube uygulamasını açmasın diye [fragmanGommeIstek] ile süzülür.
class FragmanGomucu extends StatefulWidget {
  final String youtubeId;

  const FragmanGomucu({super.key, required this.youtubeId});

  @override
  State<FragmanGomucu> createState() => _FragmanGomucuState();
}

class _FragmanGomucuState extends State<FragmanGomucu> {
  WebViewController? _denetci;
  bool _yukleniyor = true;
  bool _hata = false;

  /// `flutter test` VM'de platform WebView yok; kapağı söktükten sonra
  /// siyah kutu yeter. Entegrasyon testleri gerçek WebView kullanır.
  bool get _otomatikTest =>
      WidgetsBinding.instance.runtimeType.toString() ==
      'AutomatedTestWidgetsFlutterBinding';

  @override
  void initState() {
    super.initState();
    if (_otomatikTest) return;
    _denetciKur();
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
    await denetci.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (istek) {
          return fragmanGommeIstek(istek.url)
              ? NavigationDecision.navigate
              : NavigationDecision.prevent;
        },
        onPageFinished: (_) {
          if (!mounted) return;
          setState(() => _yukleniyor = false);
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
    denetci.loadRequest(
      Uri.parse(
        youtubeGommeUrl(widget.youtubeId, otomatik: true, gizlilikDostu: false),
      ),
      headers: const {'Referer': 'https://dizijpg.com/'},
    );
  }

  /// Hata sonrası aynı gömmeyi yeniden dener.
  void _tekrar() {
    setState(() {
      _hata = false;
      _yukleniyor = true;
    });
    _yukle();
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
        _webGorunum(denetci),
        if (_yukleniyor && !_hata)
          const ColoredBox(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(color: DiziRenkler.sari),
            ),
          ),
        if (_hata)
          ColoredBox(
            color: Colors.black,
            child: Center(
              child: TextButton(
                onPressed: _tekrar,
                child: Text('Tekrar dene'.c),
              ),
            ),
          ),
      ],
    );
  }
}
