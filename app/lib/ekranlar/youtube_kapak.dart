import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../gorsel_basliklari.dart';

/// i.ytimg.com'un "kapak yok" yanıtındaki gri karenin eni (120×90).
const int _yerTutucuEn = 120;

/// YouTube kapak karesi: önce [url] (maxresdefault), olmazsa [yedekUrl]
/// (hqdefault), o da olmazsa [hataWidget].
///
/// NEDEN DURUM KODUNA DEĞİL BOYUTA BAKIYOR: i.ytimg.com olmayan bir
/// `maxresdefault` için 404 döner AMA gövdesi GEÇERLİ bir JPEG'dir —
/// 120×90 gri "video yok" ikonu. Tarayıcıda resim durum kodundan bağımsız
/// çözüldüğü için `errorWidget` HİÇ ateşlenmez; o gri kare 1280 piksele
/// gerilip kapak diye çizilir. (6 Eyl 2026, The Wire 2. sezon fragmanı
/// `Hv3jf9DHFzk`: kullanıcı "video var ama kapak fotoğrafı kırık" dedi;
/// ağ kaydında yalnız maxresdefault 404'ü vardı, hqdefault hiç istenmemişti.)
/// Bu yüzden yedeğe düşme kararı ÇÖZÜLEN GENİŞLİKLE verilir: en 120 piksel
/// veya daha darsa gerçek kapak yoktur.
class YoutubeKapak extends StatefulWidget {
  final String url;
  final String? yedekUrl;
  final BoxFit fit;

  /// İkisi de çözülemezse çizilecek yüzey (varsayılan: siyah).
  final Widget? hataWidget;

  /// Adresten sağlayıcı üretir. Yalnız TEST için verilir; üretimde ağa
  /// çıkan `CachedNetworkImageProvider` kullanılır.
  final ImageProvider Function(String url)? saglayiciUret;

  const YoutubeKapak({
    super.key,
    required this.url,
    this.yedekUrl,
    this.fit = BoxFit.cover,
    this.hataWidget,
    this.saglayiciUret,
  });

  @override
  State<YoutubeKapak> createState() => _YoutubeKapakState();
}

class _YoutubeKapakState extends State<YoutubeKapak> {
  /// false = [YoutubeKapak.url], true = [YoutubeKapak.yedekUrl] deneniyor.
  bool _yedek = false;
  bool _hata = false;

  ImageProvider? _saglayici;
  ImageStream? _akis;
  ImageStreamListener? _dinleyici;

  String get _url => _yedek ? widget.yedekUrl! : widget.url;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_saglayici == null) _coz();
  }

  @override
  void didUpdateWidget(YoutubeKapak eski) {
    super.didUpdateWidget(eski);
    if (eski.url == widget.url && eski.yedekUrl == widget.yedekUrl) return;
    _yedek = false;
    _hata = false;
    _coz();
  }

  @override
  void dispose() {
    _birak();
    super.dispose();
  }

  void _birak() {
    final dinleyici = _dinleyici;
    if (dinleyici != null) _akis?.removeListener(dinleyici);
    _dinleyici = null;
    _akis = null;
  }

  void _coz() {
    _birak();
    final uret = widget.saglayiciUret;
    final saglayici = uret != null
        ? uret(_url)
        : CachedNetworkImageProvider(_url, headers: gorselBasliklari(_url));
    _saglayici = saglayici;
    final dinleyici = ImageStreamListener(
      _geldi,
      onError: (_, _) => _yedegeDus(),
    );
    _dinleyici = dinleyici;
    _akis = saglayici.resolve(createLocalImageConfiguration(context))
      ..addListener(dinleyici);
  }

  /// Gelen kare gri yer tutucuysa (en ≤ 120) yedeğe geç; değilse dokunma.
  void _geldi(ImageInfo bilgi, bool _) {
    if (bilgi.image.width > _yerTutucuEn) return;
    _yedegeDus();
  }

  /// Kare çözülemedi ya da yer tutucu çıktı. Yedek varsa ona düşer, yoksa
  /// [YoutubeKapak.hataWidget] çizilir.
  ///
  /// Kare ÖNBELLEKTEN geliyorsa geri çağrı `resolve` içinde SENKRON
  /// ateşlenir — o an `setState` build sırasına düşerdi; mikro göreve
  /// ertelemek iki yolu da güvene alır.
  void _yedegeDus() {
    if (_yedek || _hata) return;
    if (widget.yedekUrl == null) {
      _hata = true;
      scheduleMicrotask(() {
        if (mounted) setState(() {});
      });
      return;
    }
    _yedek = true;
    scheduleMicrotask(() {
      if (mounted) setState(_coz);
    });
  }

  @override
  Widget build(BuildContext context) {
    final saglayici = _saglayici;
    final hata = widget.hataWidget ?? const ColoredBox(color: Colors.black);
    if (_hata || saglayici == null) return hata;
    return Image(
      image: saglayici,
      fit: widget.fit,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => hata,
    );
  }
}
