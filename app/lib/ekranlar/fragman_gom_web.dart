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
import 'fragman_tam_ekran.dart';

/// Web: YouTube iframe (youtube-nocookie) + bizim krom.
///
/// **YouTube kromu KIRPILARAK gizlenir.** Çapraz kökenli iframe'e CSS
/// işlemez; `controls=0` olsa da YouTube başlığı (üst), "Diğer videolar"
/// duraklama kutusu ve logo (alt) bizim kromun üstünden sızıyordu. iframe,
/// kabından [_tasma] px daha yüksek kurulur ve kap `overflow:hidden` kırpar:
/// video 16:9 genişliğe göre ortalanır (tam görünür), YouTube'un üst/alt
/// şeritleri siyah bantlara düşer ve kesilir.
///
/// iframe dokunuşu yutar; [IgnorePointer] + [PointerInterceptor] ile
/// kaydırma ve oynat/duraklat Flutter'da kalır. Kaydırınca postMessage
/// ile duraklar — sökülmez, başa sarımaz.
class FragmanGomucu extends StatefulWidget {
  final String youtubeId;
  final bool aktif;
  final double altBosluk;

  /// Tam ekrandan dönüşte/geçişte kaldığı yerden sürmek için.
  final Duration baslangic;

  /// Tam ekran rotasının içindeyiz (düğme "çık" olur, geri tuşu konumu
  /// döndürür, tarayıcı tam ekranı istenir).
  final bool tamEkran;
  final String? baslik;
  final String? kapakUrl;
  final String? kapakYedekUrl;

  const FragmanGomucu({
    super.key,
    required this.youtubeId,
    this.aktif = true,
    this.altBosluk = 8,
    this.baslangic = Duration.zero,
    this.tamEkran = false,
    this.baslik,
    this.kapakUrl,
    this.kapakYedekUrl,
  });

  @override
  State<FragmanGomucu> createState() => _FragmanGomucuState();
}

class _FragmanGomucuState extends State<FragmanGomucu> {
  late final String _gorunumTipi;
  web.HTMLIFrameElement? _iframe;
  web.EventListener? _mesajDinleyici;
  Timer? _dinleme;
  Timer? _acTik;
  Timer? _hataTik;
  Timer? _otomatikTik;
  bool _yukleniyor = true;
  bool _hata = false;
  bool _oynuyor = true;
  bool _tamponluyor = false;
  bool _bitti = false;
  bool _sessiz = false;
  bool _oynatmakIstiyor = true;
  bool _altyazi = false;
  bool _basili2x = false;
  bool _tamEkranda = false;
  bool _haberGeldi = false;
  double _kaliciHiz = 1;

  /// Bu oynatıcının IFrame API kimliği. `listening` el sıkışmasında verilir,
  /// YouTube her `infoDelivery`/`onStateChange` mesajında aynen yankılar;
  /// tam ekranda iki oynatıcı yan yana yaşarken mesajlar buna göre ayrılır.
  ///
  /// NEDEN `event.source == iframe.contentWindow` DEĞİL (4 Eyl 2026): dart2js
  /// eşitlik için nesnenin özelliklerine dokunur (interceptor); çapraz kökenli
  /// WindowProxy'de bu SecurityError fırlatır, işleyici sessizce ölür ve
  /// oynatıcı 20 sn sonra "Bir şeyler ters gitti" der. Kimlik JSON içinde
  /// gelir, pencereye hiç dokunulmaz.
  static int _sonKimlik = 0;
  late final int _kimlik;
  Duration _konum = Duration.zero;
  Duration _sure = Duration.zero;
  Duration _tampon = Duration.zero;

  /// iframe'in üstten ve alttan kırpılan payı (px). YouTube başlık şeridi
  /// ~60 px (büyük kipte ~90), duraklama kutusu + logo ~80 px; 140 ikisini
  /// de her boyutta bantta bırakır. Video kısalmaz: iframe genişliğe göre
  /// 16:9 çizer ve dikeyde ortalar.
  static const _tasma = 140;

  double get _hiz => _basili2x ? 2 : _kaliciHiz;

  @override
  void initState() {
    super.initState();
    _konum = widget.baslangic;
    _kimlik = ++_sonKimlik;
    _gorunumTipi = 'yt-${widget.youtubeId}-${identityHashCode(this)}';
    ui_web.platformViewRegistry.registerViewFactory(_gorunumTipi, (int id) {
      final kap = web.HTMLDivElement()
        ..style.position = 'relative'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.overflow = 'hidden'
        ..style.background = '#000';
      final iframe = web.HTMLIFrameElement()
        ..src = youtubeGommeUrl(
          widget.youtubeId,
          otomatik: true,
          dil: Ceviri.dil.value,
          baslangicSn: widget.baslangic.inSeconds,
        )
        ..style.border = 'none'
        ..style.position = 'absolute'
        ..style.left = '0'
        ..style.top = '-${_tasma}px'
        ..style.width = '100%'
        ..style.height = 'calc(100% + ${_tasma * 2}px)'
        ..allow =
            'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; fullscreen'
        ..allowFullscreen = true;
      iframe.setAttribute('referrerpolicy', 'strict-origin-when-cross-origin');
      kap.appendChild(iframe);
      _iframe = iframe;
      return kap;
    });
    _mesajDinleyici = _mesaj.toJS;
    web.window.addEventListener('message', _mesajDinleyici!);
    WidgetsBinding.instance.addPostFrameCallback((_) => _dinlemeyiBaslat());
    _sayaclariKur();
    if (widget.tamEkran) _tarayiciTamEkran(true);
  }

  /// Yükleme kapağı en geç 12 sn'de kalkar (YouTube olay göndermese bile);
  /// 20 sn'de hiç haber yoksa hata ekranı.
  void _sayaclariKur() {
    _acTik?.cancel();
    _hataTik?.cancel();
    _acTik = Timer(const Duration(seconds: 12), () {
      if (mounted && _yukleniyor) setState(() => _yukleniyor = false);
    });
    _hataTik = Timer(const Duration(seconds: 20), () {
      if (!mounted || _haberGeldi) return;
      setState(() {
        _hata = true;
        _yukleniyor = false;
      });
    });
  }

  @override
  void dispose() {
    _dinleme?.cancel();
    _acTik?.cancel();
    _hataTik?.cancel();
    _otomatikTik?.cancel();
    final dinleyici = _mesajDinleyici;
    if (dinleyici != null) {
      web.window.removeEventListener('message', dinleyici);
    }
    if (widget.tamEkran) _tarayiciTamEkran(false);
    super.dispose();
  }

  @override
  void didUpdateWidget(FragmanGomucu eski) {
    super.didUpdateWidget(eski);
    if (eski.aktif != widget.aktif && !_tamEkranda) _oynatmayiUygula();
  }

  /// Tarayıcı tam ekranı (belge). Safari iOS'ta yok — sessizce geçilir;
  /// rota zaten tüm görünümü kaplar.
  void _tarayiciTamEkran(bool ac) {
    try {
      if (ac) {
        web.document.documentElement?.requestFullscreen();
      } else if (web.document.fullscreenElement != null) {
        web.document.exitFullscreen();
      }
    } catch (_) {}
  }

  /// IFrame API dinleyicisi: süre, tampon, konum YouTube'dan gelir.
  void _dinlemeyiBaslat() {
    _dinleme?.cancel();
    var kalan = 20;
    _dinleme = Timer.periodic(const Duration(milliseconds: 400), (t) {
      _posta({'event': 'listening', 'id': _kimlik, 'channel': 'widget'});
      _komut('addEventListener', ['onStateChange']);
      kalan--;
      if (kalan <= 0) t.cancel();
    });
  }

  /// YouTube kökenli postMessage (süre / tampon / durum). Yalnız BİZİM
  /// kimliğimizi taşıyanlar dinlenir (bkz. [_kimlik]).
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
    final kimlik = govde['id'];
    if (kimlik is num && kimlik.toInt() != _kimlik) return;
    _haberGeldi = true;
    _hataTik?.cancel();
    final olay = govde['event'] as String?;
    if (olay == 'onReady') {
      _oynatmayiUygula();
      _otomatikKontrol();
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
    if (degisti) setState(() {});
  }

  /// Tarayıcı sesli autoplay'i engellediyse YouTube "cued" kalır; 2 sn
  /// içinde oynama haberi gelmezse kapağı kaldırıp sarı oynat gösterilir —
  /// dokunuş jestiyle `playVideo` çalışır.
  void _otomatikKontrol() {
    _otomatikTik?.cancel();
    _otomatikTik = Timer(const Duration(seconds: 2), () {
      if (!mounted || !_yukleniyor) return;
      setState(() {
        _yukleniyor = false;
        _oynuyor = false;
        _oynatmakIstiyor = false;
      });
    });
  }

  /// YouTube playerState: 1 oynuyor, 2 duraklat, 3 tampon, 0 bitti,
  /// -1 başlamadı, 5 sıraya alındı.
  void _durumUygula(int durum, {bool setStateYok = false}) {
    final oynuyor = durum == 1 || durum == 3;
    final tamponluyor = durum == 3;
    final bitti = durum == 0;
    final yukleniyor = _yukleniyor && durum != 1;
    if (oynuyor == _oynuyor &&
        tamponluyor == _tamponluyor &&
        bitti == _bitti &&
        yukleniyor == _yukleniyor) {
      return;
    }
    _oynuyor = oynuyor;
    _tamponluyor = tamponluyor;
    _bitti = bitti;
    _yukleniyor = yukleniyor;
    if (durum == 1) _otomatikTik?.cancel();
    if (!setStateYok && mounted) setState(() {});
  }

  void _posta(Map<String, Object?> govde) {
    final iframe = _iframe;
    if (iframe == null) return;
    iframe.contentWindow?.postMessage(jsonEncode(govde).toJS, '*'.toJS);
  }

  /// IFrame API komutu (enablejsapi=1 şart).
  void _komut(String fn, [List<Object> args = const []]) {
    _posta({
      'event': 'command',
      'func': fn,
      'args': args,
      'id': _kimlik,
      'channel': 'widget',
    });
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
    if (_bitti) {
      _komut('seekTo', [0, true]);
      _komut('playVideo');
      _oynatmakIstiyor = true;
      setState(() {
        _bitti = false;
        _oynuyor = true;
        _konum = Duration.zero;
      });
      return;
    }
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
    setState(() {
      _konum = hedef;
      if (_bitti && hedef < _sure) _bitti = false;
    });
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

  /// Hata sonrası iframe'i aynı adresle yeniden yükler.
  void _tekrar() {
    _haberGeldi = false;
    setState(() {
      _hata = false;
      _yukleniyor = true;
      _oynuyor = true;
      _oynatmakIstiyor = true;
      _bitti = false;
      _sure = Duration.zero;
      _tampon = Duration.zero;
      _konum = widget.baslangic;
    });
    final iframe = _iframe;
    if (iframe != null) iframe.src = iframe.src;
    _sayaclariKur();
    WidgetsBinding.instance.addPostFrameCallback((_) => _dinlemeyiBaslat());
  }

  /// Tam ekrana geç / tam ekrandan çık. Kahraman altta duraklar, dönüşte
  /// tam ekranın bıraktığı saniyeye sarıp sürer.
  Future<void> _tamEkran() async {
    if (widget.tamEkran) {
      Navigator.of(context).pop(_konum);
      return;
    }
    _oynatmakIstiyor = false;
    _komut('pauseVideo');
    setState(() {
      _oynuyor = false;
      _tamEkranda = true;
    });
    final k = await fragmanTamEkranAc(
      context,
      youtubeId: widget.youtubeId,
      baslangic: _konum,
      baslik: widget.baslik,
      kapakUrl: widget.kapakUrl,
      kapakYedekUrl: widget.kapakYedekUrl,
    );
    if (!mounted) return;
    _tamEkranda = false;
    if (k != null) _sar(k);
    _oynatmakIstiyor = true;
    _oynatmayiUygula();
  }

  @override
  Widget build(BuildContext context) {
    final govde = Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(child: HtmlElementView(viewType: _gorunumTipi)),
        PointerInterceptor(
          child: _hata
              ? FragmanHata(onTekrar: _tekrar)
              : FragmanKontrol(
                  yukleniyor: _yukleniyor,
                  oynuyor: _oynuyor,
                  tamponluyor: _tamponluyor,
                  bitti: _bitti,
                  sessiz: _sessiz,
                  altyazi: _altyazi,
                  hiz: _hiz,
                  konum: _konum,
                  sure: _sure,
                  tampon: _tampon,
                  altBosluk: widget.altBosluk,
                  tamEkran: widget.tamEkran,
                  baslik: widget.baslik,
                  kapakUrl: widget.kapakUrl,
                  kapakYedekUrl: widget.kapakYedekUrl,
                  onOynatDuraklat: _oynatDuraklat,
                  onSessiz: _sessizDegistir,
                  onAltyazi: _altyaziDegistir,
                  onHiz: _hizDegistir,
                  onGeri10: _geri10,
                  onIleri10: _ileri10,
                  onBasili2x: _basiliTut,
                  onSarma: _sar,
                  onTamEkran: _tamEkran,
                ),
        ),
      ],
    );
    if (!widget.tamEkran) return govde;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_konum);
      },
      child: govde,
    );
  }
}
