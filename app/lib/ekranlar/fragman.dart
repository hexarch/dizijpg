import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../ceviri.dart';
import '../tema.dart';
import '../tmdb_fragman.dart';
import 'fragman_gom.dart';
import 'fragman_kontrol.dart';

/// Dizi/film/bölüm kahramanındaki resmi fragman.
///
/// Başta yalnız YouTube kapağı (1280×720 maxres; yoksa hqdefault) + sarı
/// oynat düğmesi + üst şeritte "FRAGMAN" rozeti ve fragman adı vardır (yer
/// ayrılır, CLS yok, sessiz autoplay yok). Dokununca uygulama içi oynatıcı
/// açılır — YouTube uygulamasına gidilmez. Kaydırılıp görünmez olunca
/// DURAKLAR; sökülmez ki geri gelince başa sarılmasın.
class FragmanOynatici extends StatefulWidget {
  final String youtubeId;

  /// Fragman adı (TMDB `name`) — kapakta ve oynatıcının üst şeridinde.
  final String? baslik;

  /// Null = gömme (web iframe / native yüzey). Testte `false` verilirse
  /// [disariAc] çağrılır; üretimde varsayılan gömmedir.
  final bool? gomulu;

  /// Kaydırıcıda görünür kare değilse oynatma duraklar (ses arkada kalmaz).
  final bool aktif;

  /// Alt kontrol çubuğunun noktaların üstünde kalması için (karışık kahraman).
  final double altBosluk;

  /// Yalnız [gomulu] açıkça false iken. Testler boş fonksiyon verir ki
  /// `url_launcher` bağlama istemesin.
  final Future<void> Function(Uri uri)? disariAc;

  const FragmanOynatici({
    super.key,
    required this.youtubeId,
    this.baslik,
    this.gomulu,
    this.aktif = true,
    this.altBosluk = 8,
    this.disariAc,
  });

  @override
  State<FragmanOynatici> createState() => _FragmanOynaticiState();
}

class _FragmanOynaticiState extends State<FragmanOynatici>
    with AutomaticKeepAliveClientMixin {
  bool _oynuyor = false;
  bool _gorunur = true;

  bool get _gomulu => widget.gomulu ?? true;

  /// Oynatma başlamışsa kaydırıcı kardeşi yok etmesin — konum kalsın.
  @override
  bool get wantKeepAlive => _oynuyor;

  @override
  void didUpdateWidget(FragmanOynatici eski) {
    super.didUpdateWidget(eski);
    if (eski.youtubeId != widget.youtubeId) {
      _oynuyor = false;
      updateKeepAlive();
    }
  }

  /// Fragmanı başlatır: gömme (uygulama içi). [gomulu] false ise yedek
  /// dışarı açma — üretim bunu kullanmaz.
  Future<void> _oynat() async {
    if (!widget.aktif) return;
    if (_gomulu) {
      setState(() => _oynuyor = true);
      updateKeepAlive();
      return;
    }
    final ac = widget.disariAc ?? _youtubeAc;
    await ac(youtubeIzleUri(widget.youtubeId));
  }

  /// YouTube izleme adresini tarayıcı/uygulamada açar.
  Future<void> _youtubeAc(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Dikey kaydırınca (yorumlar) duraklatır; oynatıcıyı SÖKMEZ.
  void _gorunurluk(VisibilityInfo bilgi) {
    if (!mounted || !_oynuyor) return;
    final g = bilgi.visibleFraction >= 0.35;
    if (g == _gorunur) return;
    setState(() => _gorunur = g);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return VisibilityDetector(
      key: Key('fragman-${widget.youtubeId}'),
      onVisibilityChanged: _gorunurluk,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: DiziRenkler.kart,
          child: _oynuyor && _gomulu
              ? FragmanGomucu(
                  youtubeId: widget.youtubeId,
                  aktif: widget.aktif && _gorunur,
                  altBosluk: widget.altBosluk,
                  baslik: widget.baslik,
                  kapakUrl: youtubeKapakUrl(widget.youtubeId, yuksek: true),
                  kapakYedekUrl: youtubeKapakUrl(widget.youtubeId),
                )
              : _kapak(),
        ),
      ),
    );
  }

  /// Kapak karesi + üst şerit + sarı oynat düğmesi (en az 44 dp).
  Widget _kapak() {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          // Adres SATIR İÇİNDE (WebP denetimi 500 karakter tarar; kapak
          // i.ytimg.com'dan gelir). Önce maxres; 404 → hqdefault.
          imageUrl: youtubeKapakUrl(widget.youtubeId, yuksek: true),
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => CachedNetworkImage(
            imageUrl: youtubeKapakUrl(widget.youtubeId),
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => const ColoredBox(color: Colors.black),
          ),
        ),
        const ColoredBox(color: Color(0x4D000000)),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: IgnorePointer(
            child: FragmanBaslikSeridi(baslik: widget.baslik),
          ),
        ),
        Center(
          child: Semantics(
            button: true,
            label: 'Fragmanı oynat'.c,
            child: Material(
              color: DiziRenkler.sari,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              elevation: 6,
              shadowColor: Colors.black54,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _oynat,
                child: const SizedBox(
                  width: 64,
                  height: 64,
                  child: Icon(Icons.play_arrow, color: Colors.black, size: 40),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
