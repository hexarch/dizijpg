import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../ceviri.dart';
import '../tema.dart';
import '../tmdb_fragman.dart';
import 'fragman_gom.dart';

/// Dizi/film/bölüm kahramanındaki resmi fragman.
///
/// Başta yalnız YouTube kapağı + oynat düğmesi vardır (yer ayrılır, CLS yok,
/// sessiz autoplay yok). Dokununca uygulama içi oynatıcı açılır — YouTube
/// uygulamasına gidilmez. Kaydırılıp görünmez olunca DURAKLAR; sökülmez ki
/// geri gelince başa sarılmasın.
class FragmanOynatici extends StatefulWidget {
  final String youtubeId;

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
                )
              : _kapak(),
        ),
      ),
    );
  }

  /// Kapak karesi + sarı oynat düğmesi (en az 44 dp).
  Widget _kapak() {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          // Adres SATIR İÇİNDE çağrılıyor, ara değişkenle değil: WebP başlık
          // denetimi (test/gorsel_webp_test.dart) çağrı noktasından sonraki
          // 500 karakteri tarıyor ve ara değişken kaynağı o pencerenin DIŞINA
          // itiyordu — kapak i.ytimg.com'dan gelir, TMDB başlıkları burada
          // anlamsızdır ama tarayıcının bunu görebilmesi gerekiyor.
          imageUrl: youtubeKapakUrl(widget.youtubeId),
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => const ColoredBox(color: Colors.black),
        ),
        const ColoredBox(color: Color(0x66000000)),
        Center(
          child: Semantics(
            button: true,
            label: 'Fragmanı oynat'.c,
            child: Material(
              color: DiziRenkler.sari,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _oynat,
                child: const SizedBox(
                  width: 56,
                  height: 56,
                  child: Icon(Icons.play_arrow, color: Colors.black, size: 36),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
