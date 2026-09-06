/// İZLEME ODASI — GÖMME YÜZEYİ (WEB).
///
/// Çapraz kökenli bir iframe'in içine CSS de JS de işlemez; tek yol
/// `postMessage`. İki sağlayıcının protokolü FARKLI olduğu için burada iki
/// ayrı çevirmen var:
///
///   · YouTube IFrame API — `{event:'command', func:'seekTo', args:[…]}`.
///     `listening` el sıkışması şart; karşılığında `infoDelivery` mesajları
///     `currentTime`/`duration`/`playerState` akıtır.
///   · Vimeo Player API — `{method:'setCurrentTime', value: 42}`. Olaylar
///     `addEventListener` ile açılır; `timeupdate` `{seconds, duration}` verir.
///
/// Protokoller 7 Eyl 2026'da tarayıcıda ÖLÇÜLDÜ (Vimeo: `getDuration` → 62,
/// `setCurrentTime` onaylandı). Dailymotion/OK.ru/VK aynı ölçümde hiçbir
/// komuta yanıt vermediği için desteklenmiyor — gerekçe `oda_baglanti.dart`ta.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../ceviri.dart';
import 'oda_baglanti.dart';
import 'oda_oynatici.dart';

/// Odanın gömme video yüzeyi.
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
  late final String _gorunumTipi;
  web.HTMLIFrameElement? _iframe;
  web.EventListener? _dinleyici;
  Timer? _elSikisma;
  Timer? _yoklama;

  /// Bu oynatıcının IFrame API kimliği.
  ///
  /// `event.source == iframe.contentWindow` KARŞILAŞTIRILMAZ: dart2js eşitlik
  /// için nesnenin özelliklerine dokunuyor ve çapraz kökenli WindowProxy'de bu
  /// SecurityError fırlatıp işleyiciyi sessizce öldürüyor (4 Eyl 2026'da
  /// fragman oynatıcısında ölçüldü). Kimlik JSON'un içinde taşınıyor.
  static int _sonKimlik = 0;
  late final int _kimlik;

  /// Platform görünümü tipi için ARTAN SAYAÇ — `identityHashCode` DEĞİL.
  ///
  /// ===========================================================================
  /// 7 EYL 2026'DA CANLIDA YAKALANAN SESSİZ HATA
  /// ===========================================================================
  /// Tip adı önce `identityHashCode(this)` ile üretiliyordu. Dart'ta bu sayı
  /// nesnenin kimliğinden türer ve ESKİ NESNE TOPLANDIKTAN SONRA YENİSİNE AYNI
  /// DEĞER DÜŞEBİLİR. Çakışma olduğunda motorun davranışı şu (engine
  /// `content_manager.dart#registerFactory`): aynı tip zaten kayıtlıysa
  /// **`false` döner ve ESKİ fabrikayı korur** — istisna atmaz, uyarı vermez.
  ///
  /// Sonuç: yeni State'in fabrikası hiç çağrılmıyor, dolayısıyla `_iframe`
  /// SONSUZA KADAR null kalıyor; el sıkışması hiç gönderilmiyor, YouTube hiç
  /// cevap vermiyor ve odada sonsuza kadar dönen bir yükleniyor halkası
  /// kalıyordu. Tarayıcıdan ölçüldü: 20 saniyede 0 postMessage, 0 yanıt,
  /// `contentWindow`a hiç dokunulmamış.
  ///
  /// Artan sayaç bir sayfa oturumu içinde çakışamaz.
  static int _sonGorunum = 0;

  /// iframe'in üstten ve alttan KIRPILAN payı (px).
  ///
  /// Çapraz kökenli iframe'e CSS işlemez: `controls=0` verilse bile YouTube'un
  /// başlık şeridi (üst), duraklama kutusu, logo ve paylaş düğmesi (alt) bizim
  /// kromumuzun üstünden sızıyor — 7 Eyl 2026'da canlıda görüldü. Kırpma,
  /// fragman oynatıcısında ölçülmüş çözümün aynısı: iframe kabından
  /// [_tasma] px daha yüksek kurulur ve kap `overflow:hidden` ile keser.
  /// Video kısalmaz; 16:9 genişliğe göre çizilip dikeyde ortalandığı için
  /// YouTube'un şeritleri siyah bantlara düşer ve kesilir.
  static const _tasma = 140;

  bool get _youtube => widget.baglanti.saglayici == OdaSaglayici.youtube;

  @override
  void initState() {
    super.initState();
    _kimlik = ++_sonKimlik;
    _gorunumTipi = 'oda-${widget.baglanti.saglayici.name}-${++_sonGorunum}';
    ui_web.platformViewRegistry.registerViewFactory(_gorunumTipi, (int id) {
      final kap = web.HTMLDivElement()
        ..style.position = 'relative'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.overflow = 'hidden'
        ..style.background = '#000';
      final iframe = web.HTMLIFrameElement()
        ..src = odaGommeUrl(
          widget.baglanti,
          dil: Ceviri.dil.value,
          // SESSİZ + otomatik: sesli otomatik oynatma tarayıcıda engellenir ve
          // izleyicinin videosu HİÇ açılmazdı. Ses "Sesi aç" düğmesiyle
          // gelir; gerekçe `OdaGommeDenetci` başlığında.
          otomatik: true,
        )
        ..style.border = 'none'
        ..style.position = 'absolute'
        ..style.left = '0'
        ..style.top = '-${_tasma}px'
        ..style.width = '100%'
        ..style.height = 'calc(100% + ${_tasma * 2}px)'
        ..allow = 'autoplay; encrypted-media; picture-in-picture; fullscreen'
        ..allowFullscreen = true;
      iframe.setAttribute('referrerpolicy', 'strict-origin-when-cross-origin');
      kap.appendChild(iframe);
      _iframe = iframe;
      return kap;
    });
    _dinleyici = _mesaj.toJS;
    web.window.addEventListener('message', _dinleyici!);
    widget.denetci.gonder = _komutIslet;
    WidgetsBinding.instance.addPostFrameCallback((_) => _elSikismayiBaslat());
  }

  @override
  void dispose() {
    _elSikisma?.cancel();
    _yoklama?.cancel();
    final d = _dinleyici;
    if (d != null) web.window.removeEventListener('message', d);
    // Denetçi ekranda YAŞAMAYA devam ediyor (yüzey yeniden kurulabilir);
    // yalnız bu yüzeyin kancası çözülür.
    if (identical(widget.denetci.gonder, _komutIslet)) {
      widget.denetci.gonder = null;
    }
    super.dispose();
  }

  /// El sıkışma + olay aboneliği.
  ///
  /// ===========================================================================
  /// NEDEN "HAZIR OLANA KADAR" ve NEDEN SABİT PENCERE DEĞİL
  /// ===========================================================================
  /// İlk yazımda bu döngü `initState`ten itibaren 400 ms × 20 = 8 saniye
  /// koşuyordu. 7 Eyl 2026'da canlıda ölçülen sonuç: **odaya ilk girişte
  /// oynatıcı hiç açılmıyordu.** Sebep, platform görünümünün (iframe)
  /// uygulama açılış yükü altında 8 saniyeden GEÇ kurulmasıydı — sayaç
  /// bitene kadar `_iframe` hâlâ null olduğu için `listening` mesajı hiç
  /// gönderilmiyor, YouTube da hiç cevap vermiyordu. Tam ekrana girip çıkmak
  /// yüzeyi yeniden kurduğu için orada çalışıyor görünüyordu; asıl akış
  /// bozuktu.
  ///
  /// İki değişiklik: (1) yüzey KURULMADAN sayaç harcanmıyor, (2) döngü
  /// oynatıcı "hazırım" diyene kadar sürüyor (tavan 60 sn). Bedeli 400 ms'de
  /// bir postMessage — hazır olunca ilk turda duruyor.
  void _elSikismayiBaslat() {
    _elSikisma?.cancel();
    var kalan = 150;
    _elSikisma = Timer.periodic(const Duration(milliseconds: 400), (t) {
      if (!mounted || widget.denetci.value.isInitialized) {
        t.cancel();
        return;
      }
      // Yüzey henüz kurulmadıysa TUR HARCANMAZ.
      if (_iframe == null) return;
      if (_youtube) {
        _posta({'event': 'listening', 'id': _kimlik, 'channel': 'widget'});
        _ytKomut('addEventListener', ['onStateChange']);
      } else {
        for (final olay in ['timeupdate', 'play', 'pause', 'loaded']) {
          _posta({'method': 'addEventListener', 'value': olay});
        }
        _posta({'method': 'getDuration'});
      }
      kalan--;
      if (kalan <= 0) t.cancel();
    });
    // VIMEO KONUM YOKLAMASI: `timeupdate` yalnız OYNARKEN akar. Duraklatılmış
    // bir videoda sahip çubuğu sürüklerse izleyicinin konumu güncellenmez ve
    // düzeltici eski konuma bakıp yanlış karar verirdi.
    if (!_youtube) {
      _yoklama = Timer.periodic(const Duration(milliseconds: 500), (_) {
        _posta({'method': 'getCurrentTime'});
      });
    }
  }

  void _posta(Map<String, Object?> govde) {
    _iframe?.contentWindow?.postMessage(jsonEncode(govde).toJS, '*'.toJS);
  }

  void _ytKomut(String fn, [List<Object> args = const []]) => _posta({
    'event': 'command',
    'func': fn,
    'args': args,
    'id': _kimlik,
    'channel': 'widget',
  });

  /// Denetçiden gelen soyut komutu sağlayıcının diline çevirir.
  void _komutIslet(String komut, Object? arg) {
    if (_youtube) {
      switch (komut) {
        case 'oynat':
          _ytKomut('playVideo');
        case 'duraklat':
          _ytKomut('pauseVideo');
        case 'sar':
          // `allowSeekAhead: true` — false olsaydı YouTube yalnız yüklenmiş
          // aralığa sarar, sahip ileri sardığında izleyici yerinde kalırdı.
          _ytKomut('seekTo', [(arg as num).toDouble(), true]);
        case 'hiz':
          _ytKomut('setPlaybackRate', [(arg as num).toDouble()]);
        case 'ses':
          _ytKomut(arg == true ? 'mute' : 'unMute');
          if (arg != true) _ytKomut('setVolume', [100]);
      }
      return;
    }
    switch (komut) {
      case 'oynat':
        _posta({'method': 'play'});
      case 'duraklat':
        _posta({'method': 'pause'});
      case 'sar':
        _posta({'method': 'setCurrentTime', 'value': (arg as num).toDouble()});
      case 'hiz':
        _posta({'method': 'setPlaybackRate', 'value': (arg as num).toDouble()});
      case 'ses':
        _posta({'method': 'setVolume', 'value': arg == true ? 0 : 1});
        _posta({'method': 'setMuted', 'value': arg == true});
    }
  }

  void _mesaj(web.Event e) {
    final m = e as web.MessageEvent;
    final koken = m.origin;
    final bizim = _youtube
        ? (koken.contains('youtube.com') ||
              koken.contains('youtube-nocookie.com'))
        : koken.contains('vimeo.com');
    if (!bizim) return;
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
    if (_youtube) {
      _youtubeMesaji(govde);
    } else {
      _vimeoMesaji(govde);
    }
  }

  void _youtubeMesaji(Map<String, dynamic> g) {
    // Tam ekranda iki yüzey yan yana yaşayabilir; kimliği bizim olmayanı at.
    final kimlik = g['id'];
    if (kimlik is num && kimlik.toInt() != _kimlik) return;
    final olay = g['event'] as String?;
    final bilgi = g['info'];
    if (olay == 'onReady') {
      widget.denetci.bildir(hazir: true);
      return;
    }
    if (bilgi is! Map) return;
    final durum = (bilgi['playerState'] as num?)?.toInt();
    widget.denetci.bildir(
      hazir: true,
      konumMs: bilgi['currentTime'] == null
          ? null
          : ((bilgi['currentTime'] as num) * 1000).round(),
      sureMs: bilgi['duration'] == null
          ? null
          : ((bilgi['duration'] as num) * 1000).round(),
      // 1 = oynuyor, 3 = tamponluyor (ikisi de "oynamak istiyor").
      oynuyor: durum == null ? null : (durum == 1 || durum == 3),
      tamponluyor: durum == null ? null : durum == 3,
      sessiz: bilgi['muted'] as bool?,
    );
  }

  void _vimeoMesaji(Map<String, dynamic> g) {
    final olay = g['event'] as String?;
    final yontem = g['method'] as String?;
    final veri = g['data'];
    if (olay == 'ready' || yontem == 'addEventListener') {
      widget.denetci.bildir(hazir: true);
      return;
    }
    if (yontem == 'getDuration' && g['value'] is num) {
      widget.denetci.bildir(sureMs: ((g['value'] as num) * 1000).round());
      return;
    }
    if (yontem == 'getCurrentTime' && g['value'] is num) {
      widget.denetci.bildir(konumMs: ((g['value'] as num) * 1000).round());
      return;
    }
    if (olay == 'play') widget.denetci.bildir(oynuyor: true, hazir: true);
    if (olay == 'pause') widget.denetci.bildir(oynuyor: false);
    if (olay == 'timeupdate' && veri is Map) {
      widget.denetci.bildir(
        hazir: true,
        oynuyor: true,
        konumMs: veri['seconds'] == null
            ? null
            : ((veri['seconds'] as num) * 1000).round(),
        sureMs: veri['duration'] == null
            ? null
            : ((veri['duration'] as num) * 1000).round(),
      );
    }
  }

  /// DOKUNUŞLAR FLUTTER'DA KALIR.
  ///
  /// iframe dokunuşu yutuyor ve altındaki YouTube kontrolleri tıklanabiliyor:
  /// izleyici oradan duraklatırsa oda senkronu bozulur (düzeltici bir saniye
  /// sonra geri alır, yani kullanıcı "video zıplıyor" görür). [IgnorePointer]
  /// iframe'i dokunmaya kapatır; oynatmayı yalnız bizim kontrollerimiz
  /// (ve sunucudaki oda durumu) sürer. Kalıp `ekranlar/fragman_gom_web.dart`
  /// ile aynı.
  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: HtmlElementView(viewType: _gorunumTipi));
}
