import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'medya_goster.dart';

/// Yorum/akış postlarındaki fotoğraf-video galerisi.
/// Tek medya: TAM GENİŞLİK, yükseklik medyanın KENDİ oranından — her post
/// kendi boyutunda (aşırı uzunlar üst sınırda ortadan kırpılır). Çoklu (2-4):
/// 2 sütun kare ızgara. Videoda büyük kapak + dokununca TAM EKRAN oynatıcı.
/// otomatikOynat=true (akış) ile kapak yerine yerinde oynatıcı: ekran ortasına
/// gelen video sessiz başlar, uzaklaşınca durur — AkisVideo aynı anda tek
/// video oynatır, bu yüzden birden çok oynatıcı çakışıp çift ses vermez.
class MedyaGaleri extends StatelessWidget {
  final List<String> yollar; // /medya/... yolları
  /// Verilirse medyaya dokununca bu çağrılır (indeks); yoksa tam ekran
  /// görüntüleyici (medyaGoster) açılır. Akış bunu Reels açmak için kullanır.
  final void Function(int index)? onAc;

  /// Akışta: videolar kapak yerine yerinde (sessiz) oynar.
  final bool otomatikOynat;
  const MedyaGaleri({
    super.key,
    required this.yollar,
    this.onAc,
    this.otomatikOynat = false,
  });

  static bool _video(String m) => m.endsWith('.mp4') || m.endsWith('.webm');

  @override
  Widget build(BuildContext context) {
    if (yollar.isEmpty) return const SizedBox.shrink();
    final urller = [for (final m in yollar) dosyaUrl(m)!];
    // Akış: TAM GENİŞLİK kaydırmalı görüntüleyici (ilk medya önce, yana
    // kaydırınca sonraki) — ızgara/kırpma yok, yükseklik postun kendi oranı.
    if (otomatikOynat) {
      return AkisMedya(urller: urller, onAc: onAc);
    }
    Widget hucre(int i) {
      final video = _video(yollar[i]);
      return InkWell(
        onTap: () => onAc != null
            ? onAc!(i)
            : medyaGoster(context, urller, baslangic: i),
        child: video
            ? (otomatikOynat
                  ? AkisVideo(url: urller[i])
                  // Video kapağı: koyu zemin + beyaz oynat (tema-bağımsız,
                  // videolar koyu görünür — açık temada da görünür kalır)
                  : Container(
                      color: Colors.black87,
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          size: 52,
                          color: Colors.white,
                        ),
                      ),
                    ))
            : CachedNetworkImage(
                imageUrl: urller[i],
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: DiziRenkler.kart),
                errorWidget: (_, _, _) => Container(
                  color: DiziRenkler.kart,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: DiziRenkler.metin38,
                  ),
                ),
              ),
      );
    }

    if (yollar.length == 1) {
      // Tek medya: genişlik tam dolar, yükseklik medyanın KENDİ oranından
      // gelir — her post kendi boyutunda.
      final video = _video(yollar[0]);
      Widget icerik;
      if (video) {
        // AkisVideo oranını oynatıcıdan verir; kapak modunda oran bilinmez → 16:9
        icerik = otomatikOynat
            ? AkisVideo(url: urller[0])
            : AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.black87,
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      size: 52,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
      } else {
        // Görsel doğal oranında tam genişlik; aşırı uzun görseller akışı
        // yutmasın diye yükseklik genişliğin 1.5 katıyla sınırlı (taşan
        // kısım ortalanıp kırpılır).
        icerik = LayoutBuilder(
          builder: (context, kisit) => ConstrainedBox(
            constraints: BoxConstraints(maxHeight: kisit.maxWidth * 1.5),
            child: CachedNetworkImage(
              imageUrl: urller[0],
              width: double.infinity,
              fit: BoxFit.fitWidth,
              placeholder: (_, _) =>
                  Container(height: 220, color: DiziRenkler.kart),
              errorWidget: (_, _, _) => Container(
                height: 220,
                color: DiziRenkler.kart,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: DiziRenkler.metin38,
                ),
              ),
            ),
          ),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => onAc != null
              ? onAc!(0)
              : medyaGoster(context, urller, baslangic: 0),
          child: icerik,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1,
        children: [for (var i = 0; i < yollar.length; i++) hucre(i)],
      ),
    );
  }
}

/// Akıştaki postun medya görüntüleyicisi: TAM GENİŞLİK, yükseklik postun
/// ilk medyasının kendi oranından. Birden çok medya varsa yana kaydırılır
/// (ilk medya her zaman başta), altta nokta göstergesi + sayaç görünür.
class AkisMedya extends StatefulWidget {
  final List<String> urller;
  final void Function(int index)? onAc;
  const AkisMedya({super.key, required this.urller, this.onAc});

  @override
  State<AkisMedya> createState() => _AkisMedyaState();
}

class _AkisMedyaState extends State<AkisMedya> {
  static bool _video(String u) => u.endsWith('.mp4') || u.endsWith('.webm');

  double? _oran; // ilk medyanın oranı (bilinene dek 4:5)
  int _sayfa = 0;
  ImageStream? _akis;
  ImageStreamListener? _dinleyici;

  @override
  void initState() {
    super.initState();
    // İlk medya görselse doğal oranını ölç (video kendi oranını bildirir)
    if (!_video(widget.urller.first)) {
      final saglayici = CachedNetworkImageProvider(widget.urller.first);
      _akis = saglayici.resolve(const ImageConfiguration());
      _dinleyici = ImageStreamListener((bilgi, _) {
        if (!mounted || _oran != null) return;
        final o = bilgi.image.width / bilgi.image.height;
        setState(() => _oran = o.clamp(0.5, 16 / 9).toDouble());
      }, onError: (_, _) {});
      _akis!.addListener(_dinleyici!);
    }
  }

  @override
  void dispose() {
    if (_akis != null && _dinleyici != null) {
      _akis!.removeListener(_dinleyici!);
    }
    super.dispose();
  }

  void _oranBildir(double o) {
    if (!mounted || _oran != null) return;
    setState(() => _oran = o.clamp(0.5, 16 / 9).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final coklu = widget.urller.length > 1;
    return AspectRatio(
      aspectRatio: _oran ?? 4 / 5,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: widget.urller.length,
            // Komşu sayfa önden kurulur: yana kaydırınca hazır gelir
            allowImplicitScrolling: true,
            onPageChanged: (i) => setState(() => _sayfa = i),
            itemBuilder: (context, i) {
              final url = widget.urller[i];
              return GestureDetector(
                onTap: () => widget.onAc != null
                    ? widget.onAc!(i)
                    : medyaGoster(context, widget.urller, baslangic: i),
                child: _video(url)
                    ? AkisVideo(
                        url: url,
                        kendiOrani: false,
                        onOran: i == 0 ? _oranBildir : null,
                      )
                    : Container(
                        color: Colors.black,
                        child: CachedNetworkImage(
                          imageUrl: url,
                          // İlk medya oranı kutuyu belirlediği için o tam
                          // oturur; diğerleri kırpılmadan sığdırılır.
                          fit: i == 0 ? BoxFit.cover : BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (_, _) =>
                              Container(color: DiziRenkler.kart),
                          errorWidget: (_, _, _) => Container(
                            color: DiziRenkler.kart,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: DiziRenkler.metin38,
                            ),
                          ),
                        ),
                      ),
              );
            },
          ),
          if (coklu) ...[
            // Sayaç (1/3) + nokta göstergesi
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_sayfa + 1}/${widget.urller.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.urller.length; i++)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _sayfa ? Colors.white : Colors.white38,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Akışta yerinde oynayan video. Kart ekranda belirir belirmez (daha merkeze
/// gelmeden) yüklenmeye başlar — eşzamanlı hazırlanan video sayısı sınırlıdır.
/// Ekran ortasına EN YAKIN görünür video sessiz oynar, merkezden uzaklaşınca
/// (veya başka kart merkeze gelince) durur; statik aday kaydıyla aynı anda
/// yalnız BİR video oynar. Ses kapalı başlar (web otomatik oynatma kuralı);
/// sağ alttaki hoparlör rozeti oturum boyu ortak ses tercihini açar.
class AkisVideo extends StatefulWidget {
  final String url;

  /// Kendi en-boy oranına göre yer kaplasın mı (AkisMedya kutuyu kendisi
  /// belirlediği için false verir).
  final bool kendiOrani;

  /// Oran öğrenilince bildirilir (post yüksekliğini belirlemek için).
  final ValueChanged<double>? onOran;

  const AkisVideo({
    super.key,
    required this.url,
    this.kendiOrani = true,
    this.onOran,
  });

  @override
  State<AkisVideo> createState() => _AkisVideoState();
}

class _AkisVideoState extends State<AkisVideo> {
  /// Görünür adaylar → ekran merkezine dikey uzaklık (px). En yakını oynar.
  static final Map<_AkisVideoState, double> _adaylar = {};
  static _AkisVideoState? _aktif;
  static bool _sesli = false; // oturum boyu ortak ses tercihi

  /// Aynı anda hazırlanan (buffer'lanan) video sayısı. Liste ilerideki
  /// kartları önden kurar; sınır olmasa onlarca çözücü/indirme açılır ve
  /// hem bellek şişer hem oynayan video için bant genişliği kalmazdı.
  static int _hazirSayi = 0;
  static const int _hazirUst = 6;

  VideoPlayerController? _d;
  Future<void>? _kurulum;
  bool _hata = false;
  bool _sayildi = false; // bu kart hazır sayacına dahil edildi mi

  @override
  void initState() {
    super.initState();
    // ÖNDEN YÜKLEME: kart listede kurulur kurulmaz (henüz ekranda bile
    // olmayabilir) video hazırlanmaya başlar; kaydırınca beklenmez.
    if (_hazirSayi < _hazirUst) _kurulum ??= _kur();
  }

  void _gorunurluk(VisibilityInfo info) {
    if (!mounted) return;
    if (info.visibleFraction < 0.55) {
      _adaylar.remove(this);
    } else {
      final kutu = context.findRenderObject();
      var uzaklik = 0.0;
      if (kutu is RenderBox && kutu.attached) {
        final merkez = kutu.localToGlobal(kutu.size.center(Offset.zero)).dy;
        uzaklik = (merkez - MediaQuery.of(context).size.height / 2).abs();
      }
      _adaylar[this] = uzaklik;
    }
    _secimiUygula();
  }

  /// Merkeze en yakın adayı oynat; öncekini (aday kalmadıysa aktifi) durdur.
  static void _secimiUygula() {
    _AkisVideoState? enYakin;
    var enKucuk = double.infinity;
    _adaylar.forEach((aday, uzaklik) {
      if (uzaklik < enKucuk) {
        enKucuk = uzaklik;
        enYakin = aday;
      }
    });
    if (enYakin == _aktif) return;
    _aktif?._d?.pause();
    _aktif = enYakin;
    _aktif?._oynat();
  }

  Future<void> _oynat() async {
    _kurulum ??= _kur();
    await _kurulum;
    final d = _d;
    // Kurulum sürerken kart merkezden çıktıysa başlatma
    if (!mounted || d == null || _aktif != this) return;
    await d.setVolume(_sesli ? 1 : 0);
    await d.play();
  }

  Future<void> _kur() async {
    _hazirSayi++;
    _sayildi = true;
    try {
      final d = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await d.initialize();
      if (!mounted) {
        d.dispose();
        return;
      }
      d.setLooping(true);
      setState(() => _d = d);
      // Postun yüksekliği videonun kendi oranından belirlensin
      if (d.value.aspectRatio > 0) widget.onOran?.call(d.value.aspectRatio);
    } catch (_) {
      if (mounted) setState(() => _hata = true);
    }
  }

  void _sesDegistir() {
    _sesli = !_sesli;
    _d?.setVolume(_sesli ? 1 : 0);
  }

  @override
  void dispose() {
    _adaylar.remove(this);
    if (_aktif == this) _aktif = null;
    if (_sayildi) _hazirSayi--; // yer aç: sıradaki kart önden kurulabilsin
    _d?.dispose();
    // Liste karttan kurtulduysa sıradaki görünür video devralsın
    _secimiUygula();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    Widget govde;
    if (_hata) {
      govde = const Center(
        child: Icon(
          Icons.videocam_off_outlined,
          size: 44,
          color: Colors.white38,
        ),
      );
    } else if (d == null) {
      // Henüz kurulmadı: siyah duraklatılmış kapak
      govde = const Center(
        child: Icon(Icons.play_circle_outline, size: 52, color: Colors.white),
      );
    } else {
      govde = ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: d,
        builder: (_, v, _) => Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: v.aspectRatio == 0 ? 16 / 9 : v.aspectRatio,
                child: VideoPlayer(d),
              ),
            ),
            if (!v.isPlaying)
              const Center(
                child: Icon(
                  Icons.play_circle_outline,
                  size: 52,
                  color: Colors.white70,
                ),
              ),
            if (v.isPlaying)
              Positioned(
                right: 2,
                bottom: 2,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _sesDegistir,
                  // 44px dokunma hedefi: saydam kenar + küçük görünür rozet
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        v.volume > 0 ? Icons.volume_up : Icons.volume_off,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    final kutu = VisibilityDetector(
      key: ValueKey('akis-video-${widget.url}'),
      onVisibilityChanged: _gorunurluk,
      child: Container(color: Colors.black, child: govde),
    );
    if (!widget.kendiOrani) return kutu; // kutuyu AkisMedya belirledi
    // Kutunun oranı videonun KENDİ oranı: genişlik tam dolar, yükseklik
    // posta göre değişir. Oran bilinene dek 16:9.
    final oran = (d != null && d.value.isInitialized && d.value.aspectRatio > 0)
        ? d.value.aspectRatio.clamp(0.5, 21 / 9).toDouble()
        : 16 / 9;
    return AspectRatio(aspectRatio: oran, child: kutu);
  }
}

/// Gönderi metni + "Çevir" düğmesi. Çeviri sunucuda HAZIRSA (ceviri_var)
/// ve gönderinin dili kullanıcının dilinden farklıysa düğme görünür; basınca
/// tek istekle çeviri gelir ve oturum boyunca yeniden istenmez.
/// Metni her ekran kendi biçiminde çizsin diye gövde `yapici` ile verilir.
class CeviriliMetin extends StatefulWidget {
  final int yorumId;
  final String metin;
  final String? kaynakDil;
  final bool ceviriVar;
  final Widget Function(String metin) yapici;
  final Color? dugmeRengi;

  const CeviriliMetin({
    super.key,
    required this.yorumId,
    required this.metin,
    required this.kaynakDil,
    required this.ceviriVar,
    required this.yapici,
    this.dugmeRengi,
  });

  @override
  State<CeviriliMetin> createState() => _CeviriliMetinState();
}

class _CeviriliMetinState extends State<CeviriliMetin> {
  String? _ceviri;
  bool _cevrili = false;
  bool _yukleniyor = false;

  Future<void> _degistir() async {
    if (_ceviri != null) {
      setState(() => _cevrili = !_cevrili);
      return;
    }
    setState(() => _yukleniyor = true);
    try {
      final d = await Api.get(
        '/ceviri/${widget.yorumId}?dil=${Ceviri.dil.value}',
      );
      if (!mounted) return;
      final m = d['metin'] as String?;
      setState(() {
        _yukleniyor = false;
        if (m != null && m.isNotEmpty) {
          _ceviri = m;
          _cevrili = true;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dil bilinmiyorsa ya da zaten kullanıcının dilindeyse düğme yok
    final farkliDil =
        widget.kaynakDil != null && widget.kaynakDil != Ceviri.dil.value;
    final gosterilsin = farkliDil && (widget.ceviriVar || _ceviri != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        widget.yapici(_cevrili ? (_ceviri ?? widget.metin) : widget.metin),
        if (gosterilsin)
          InkWell(
            onTap: _yukleniyor ? null : _degistir,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_yukleniyor)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: DiziRenkler.sari,
                      ),
                    )
                  else
                    Icon(
                      Icons.translate,
                      size: 14,
                      color: widget.dugmeRengi ?? DiziRenkler.sariMetin,
                    ),
                  const SizedBox(width: 5),
                  Text(
                    _cevrili ? 'Orijinali göster'.c : 'Çevir'.c,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: widget.dugmeRengi ?? DiziRenkler.sariMetin,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Poster kartı: dokununca detaya gider.
class PosterKarti extends StatelessWidget {
  final Map<String, dynamic> icerik;
  final String? turZorla; // multi aramada media_type gelir; trendlerde belli
  final double genislik;

  const PosterKarti({
    super.key,
    required this.icerik,
    this.turZorla,
    this.genislik = 118,
  });

  @override
  Widget build(BuildContext context) {
    final tur = turZorla ?? icerik['media_type'] as String? ?? 'tv';
    final ad = icerik['name'] ?? icerik['title'] ?? '?';
    // DİKKAT: burada w185 denendi ve GERİ ALINDI — 3x ekranda 118dp kart 354
    // fiziksel piksel demek; w185 büyütülüp gözle görülür bulanıklaşıyor.
    // Bant genişliği kazancı kaliteye değmez.
    final posterYolu = posterUrl(icerik['poster_path'] as String?);
    final puan = (icerik['vote_average'] as num?)?.toDouble() ?? 0;

    return SizedBox(
      width: genislik,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/icerik/$tur/${icerik['id']}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: posterYolu == null
                        ? Container(
                            color: DiziRenkler.kart,
                            child: Icon(
                              Icons.movie,
                              color: DiziRenkler.metin24,
                              size: 40,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: posterYolu,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: DiziRenkler.kart),
                            errorWidget: (_, __, ___) => Container(
                              color: DiziRenkler.kart,
                              child: Icon(
                                Icons.broken_image,
                                color: DiziRenkler.metin24,
                              ),
                            ),
                          ),
                  ),
                ),
                if (puan > 0)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            color: DiziRenkler.sari,
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            puan.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              ad as String,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yatay poster şeridi (başlık + liste).
class PosterSeridi extends StatelessWidget {
  final String baslik;
  final List<dynamic> icerikler;
  final String? turZorla;

  const PosterSeridi({
    super.key,
    required this.baslik,
    required this.icerikler,
    this.turZorla,
  });

  @override
  Widget build(BuildContext context) {
    if (icerikler.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: DiziRenkler.sari,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                baslik,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 236,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: icerikler.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => PosterKarti(
              icerik: icerikler[i] as Map<String, dynamic>,
              turZorla: turZorla,
            ),
          ),
        ),
      ],
    );
  }
}

/// Kitaplık/ızgara içeriği: detayını sunucu önbelleğinden çekip poster gösterir.
class MiniIcerik extends StatefulWidget {
  final int tmdbId;
  final String tur;
  final double genislik;

  /// Dizi ilerleme rozeti için izlenen bölüm sayısı (isteğe bağlı).
  final int? izlenenSayi;

  const MiniIcerik({
    super.key,
    required this.tmdbId,
    required this.tur,
    this.genislik = 105,
    this.izlenenSayi,
  });

  @override
  State<MiniIcerik> createState() => _MiniIcerikState();
}

class _MiniIcerikState extends State<MiniIcerik> {
  Map<String, dynamic>? _icerik;
  bool _hata = false;

  @override
  void initState() {
    super.initState();
    Api.get('/tmdb/${widget.tur}/${widget.tmdbId}')
        .then((d) {
          if (mounted) setState(() => _icerik = d as Map<String, dynamic>);
        })
        .catchError((_) {
          // Hata: sonsuz iskelet yerine kırık görsel göster
          if (mounted) setState(() => _hata = true);
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_hata) {
      // genislik double.infinity olabilir → sabit yükseklik yerine oran kullan
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 2 / 3,
          child: Container(
            color: DiziRenkler.kart,
            child: Icon(
              Icons.broken_image_outlined,
              color: DiziRenkler.metin38,
            ),
          ),
        ),
      );
    }
    if (_icerik == null) {
      return IskeletKutu(genislik: widget.genislik);
    }
    final kart = PosterKarti(
      icerik: _icerik!,
      turZorla: widget.tur,
      genislik: widget.genislik,
    );
    // Dizi ilerlemesi: posterin üstünde dolum barı.
    // Sarı = izlenen oran; tamamı izlendiyse turuncu.
    final toplam = (_icerik!['number_of_episodes'] as num?)?.toInt() ?? 0;
    final izlenen = widget.izlenenSayi ?? 0;
    if (widget.tur != 'tv' || toplam <= 0 || izlenen <= 0) return kart;
    final oranDolu = (izlenen / toplam).clamp(0.03, 1.0).toDouble();
    final tamamlandi = izlenen >= toplam;
    return Stack(
      children: [
        kart,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              height: 5,
              color: Colors.black45,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: oranDolu,
                heightFactor: 1,
                child: Container(
                  color: tamamlandi ? Colors.deepOrange : DiziRenkler.sari,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Yüklenirken nabız gibi atan iskelet kutu.
class IskeletKutu extends StatefulWidget {
  final double genislik;
  final double? yukseklik;

  const IskeletKutu({super.key, this.genislik = 105, this.yukseklik});

  @override
  State<IskeletKutu> createState() => _IskeletKutuState();
}

class _IskeletKutuState extends State<IskeletKutu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kontrol = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _kontrol.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_kontrol),
      child: Container(
        width: widget.genislik,
        height: widget.yukseklik,
        decoration: BoxDecoration(
          color: DiziRenkler.kart,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Kart-listesi iskeleti: yuvarlak avatar + iki metin çubuğu.
/// Bildirimler/sohbetler gibi liste ekranlarında bekleme yerine kullanılır.
class IskeletSatir extends StatelessWidget {
  const IskeletSatir({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const IskeletKutu(genislik: 44, yukseklik: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  IskeletKutu(genislik: 160, yukseklik: 12),
                  SizedBox(height: 8),
                  IskeletKutu(genislik: 90, yukseklik: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Verilen sayıda iskelet satırından oluşan liste (padding'li).
class IskeletListe extends StatelessWidget {
  final int adet;
  const IskeletListe({super.key, this.adet = 7});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: adet,
      itemBuilder: (_, __) => const IskeletSatir(),
    );
  }
}

/// Hata + tekrar dene görünümü
class HataGorunumu extends StatelessWidget {
  final String mesaj;
  final VoidCallback tekrar;
  const HataGorunumu({super.key, required this.mesaj, required this.tekrar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 48, color: DiziRenkler.metin38),
            const SizedBox(height: 12),
            Text(mesaj, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: tekrar, child: Text('Tekrar Dene'.c)),
          ],
        ),
      ),
    );
  }
}

/// Boş durum görünümü: ikon + başlık + ipucu (+ isteğe bağlı aksiyon).
/// Sade "X yok" metinleri yerine kullanılır — daha profesyonel his.
class BosDurum extends StatelessWidget {
  final IconData ikon;
  final String baslik;
  final String? ipucu;
  final Widget? aksiyon;
  const BosDurum({
    super.key,
    required this.ikon,
    required this.baslik,
    this.ipucu,
    this.aksiyon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 48, color: DiziRenkler.metin38),
            const SizedBox(height: 12),
            Text(
              baslik,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (ipucu != null) ...[
              const SizedBox(height: 6),
              Text(
                ipucu!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: DiziRenkler.metin54,
                  height: 1.4,
                ),
              ),
            ],
            if (aksiyon != null) ...[const SizedBox(height: 16), aksiyon!],
          ],
        ),
      ),
    );
  }
}

/// Tutarlı bölüm başlığı: sarı ikon + kalın başlık. Tüm ekranlarda aynı.
class BolumBasligi extends StatelessWidget {
  final IconData ikon;
  final String baslik;
  final Widget? sonEk; // sağdaki buton (ör. "Tümünü gör", +)
  const BolumBasligi({
    super.key,
    required this.ikon,
    required this.baslik,
    this.sonEk,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(ikon, size: 20, color: DiziRenkler.sari),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            baslik,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        if (sonEk != null) sonEk!,
      ],
    );
  }
}

/// Kullanıcı profiline güvenli gidiş. /kullanici/:ad kabuk İÇİNDE yaşar;
/// kabuğun üstündeki sayfalardan (detay/bölüm/kişi/özet...) push'lanırsa
/// kabuk ikinci kez kurulur, branch GlobalKey'leri çakışır → beyaz ekran.
/// O yüzden kabuk dışındaysak go (kabuğa dön), içindeysek push (yığın korunur).
void kullaniciyaGit(BuildContext context, String ad) {
  final yol = GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
  const kabukDisi = [
    '/icerik/',
    '/kisi/',
    '/dizi/',
    '/ozet/',
    '/izlediklerim',
    '/ayarlar',
    '/gizlilik',
    '/gonderi/',
  ];
  final disarida = kabukDisi.any(yol.startsWith);
  final hedef = '/kullanici/$ad';
  if (disarida) {
    context.go(hedef);
  } else {
    context.push(hedef);
  }
}

/// dizi.jpg AI hesabının kullanıcı adı. Bu adı taşıyan avatarlar her yerde
/// sarı çerçeve + çerçevenin altına oturan "AI" rozetiyle çizilir.
const String aiKullaniciAdi = 'dizi.jpg.ai';

/// Kullanıcı avatarı. [kullaniciAdi] AI hesabıysa sarı çerçeve ve altına
/// bindirilmiş "AI" rozeti ekler; diğer herkes için düz CircleAvatar'dır.
/// Rozetli halde bileşen çerçeve + rozet payı kadar büyür; rozet Stack
/// SINIRLARI İÇİNDE kalır (dışarı taşan Positioned tıklama almaz).
class KullaniciAvatari extends StatelessWidget {
  final String? url; // dosyaUrl'den geçmiş TAM adres; null = kişi ikonu
  final String? kullaniciAdi;
  final double yaricap;
  final Color? arkaplan;
  final Color? ikonRenk;
  const KullaniciAvatari({
    super.key,
    required this.url,
    required this.kullaniciAdi,
    this.yaricap = 20,
    this.arkaplan,
    this.ikonRenk,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: yaricap,
      backgroundColor: arkaplan ?? DiziRenkler.koyuGri,
      backgroundImage: url != null ? CachedNetworkImageProvider(url!) : null,
      child: url == null
          ? Icon(
              Icons.person,
              size: yaricap,
              color: ikonRenk ?? DiziRenkler.metin38,
            )
          : null,
    );
    if (kullaniciAdi != aiKullaniciAdi) return avatar;
    final kenar = (yaricap * 0.09).clamp(1.2, 2.0);
    final halka = yaricap * 2 + 2 * (kenar + 1.5);
    final yazi = (yaricap * 0.42).clamp(7.0, 11.0);
    final rozetYukseklik = yazi * 1.1 + 3;
    return SizedBox(
      width: halka,
      height: halka + rozetYukseklik / 2,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: halka,
            height: halka,
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: DiziRenkler.sari, width: kenar),
            ),
            child: avatar,
          ),
          Positioned(
            bottom: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: yazi * 0.55),
              decoration: BoxDecoration(
                color: DiziRenkler.sari,
                borderRadius: BorderRadius.circular(rozetYukseklik),
              ),
              // "AI" evrensel kısaltma/marka etiketi — çevrilmez.
              child: Text(
                'AI',
                style: TextStyle(
                  fontSize: yazi,
                  height: 1.4,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Okunmamış sayacı rozetli appbar ikonu (zil, zarf, DM).
class RozetliIkon extends StatelessWidget {
  final IconData ikon;
  final int sayi;
  final VoidCallback onTap;
  final String? etiket; // erişilebilirlik + tooltip

  const RozetliIkon({
    super.key,
    required this.ikon,
    required this.sayi,
    required this.onTap,
    this.etiket,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: etiket,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(ikon),
          if (sayi > 0)
            Positioned(
              right: -5,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: DiziRenkler.sari,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  sayi > 99 ? '99+' : '$sayi',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Liste içeriği modalı: 3'lü poster ızgarası, dokununca detaya gider.
/// Hem kendi profilinden hem başkasının profilinden açılır.
class ListeSheet extends StatefulWidget {
  final int listeId;
  final String ad;

  const ListeSheet({super.key, required this.listeId, required this.ad});

  static void ac(
    BuildContext context, {
    required int listeId,
    required String ad,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DiziRenkler.koyuGri,
      builder: (_) => ListeSheet(listeId: listeId, ad: ad),
    );
  }

  @override
  State<ListeSheet> createState() => _ListeSheetState();
}

class _ListeSheetState extends State<ListeSheet> {
  List<dynamic>? _ogeler;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final d = await Api.get('/listeler/${widget.listeId}');
      if (!mounted) return;
      setState(() => _ogeler = d['ogeler'] as List<dynamic>);
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_hata != null) {
      govde = Center(
        child: Text(_hata!, style: TextStyle(color: DiziRenkler.metin54)),
      );
    } else if (_ogeler == null) {
      govde = const Center(
        child: CircularProgressIndicator(color: DiziRenkler.sari),
      );
    } else if (_ogeler!.isEmpty) {
      govde = Center(
        child: Text(
          'Liste boş.'.c,
          style: TextStyle(color: DiziRenkler.metin38),
        ),
      );
    } else {
      govde = GridView.builder(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 2 / 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _ogeler!.length,
        itemBuilder: (context, i) {
          final o = _ogeler![i] as Map<String, dynamic>;
          return _ListeOgeKart(
            tur: o['tur'] as String,
            tmdbId: (o['tmdb_id'] as num).toInt(),
          );
        },
      );
    }

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.playlist_play, color: DiziRenkler.sari),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.ad,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: govde),
        ],
      ),
    );
  }
}

/// Liste öğesi: posteri önbellekli TMDB'den çeker, tıklayınca detaya gider.
class _ListeOgeKart extends StatefulWidget {
  final String tur;
  final int tmdbId;

  const _ListeOgeKart({required this.tur, required this.tmdbId});

  @override
  State<_ListeOgeKart> createState() => _ListeOgeKartState();
}

class _ListeOgeKartState extends State<_ListeOgeKart> {
  Map<String, dynamic>? _icerik;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final d = await Api.get('/tmdb/${widget.tur}/${widget.tmdbId}');
      if (mounted) setState(() => _icerik = d as Map<String, dynamic>);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final poster = posterUrl(_icerik?['poster_path'] as String?, boyut: 'w185');
    final ad = (_icerik?['name'] ?? _icerik?['title'] ?? '') as String;
    return InkWell(
      onTap: () {
        // Yönlendiriciyi modal kapanmadan ÖNCE al (ölü context tuzağı)
        final yonlendirici = GoRouter.of(context);
        Navigator.pop(context);
        yonlendirici.push('/icerik/${widget.tur}/${widget.tmdbId}');
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          color: DiziRenkler.kart,
          child: poster != null
              ? CachedNetworkImage(
                  imageUrl: poster,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Icon(
                    Icons.broken_image_outlined,
                    color: DiziRenkler.metin38,
                  ),
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      ad,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: DiziRenkler.metin54,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Şikayet sebebi seçtiren alt sayfa; seçilince sunucuya bildirir.
/// tur: 'yorum' | 'mesaj' | 'kullanici' | 'liste'
Future<void> sikayetEtSheet(
  BuildContext context,
  String tur,
  int hedefId,
) async {
  const sebepler = [
    'Spam veya yanıltıcı',
    'Taciz veya nefret söylemi',
    'Uygunsuz / cinsel içerik',
    'Şiddet veya tehlikeli içerik',
    'Telif hakkı ihlali',
    'Diğer',
  ];
  final messenger = ScaffoldMessenger.of(context);
  final secilen = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: DiziRenkler.koyuGri,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.flag_outlined, color: DiziRenkler.sari),
                const SizedBox(width: 10),
                Text(
                  'Şikayet sebebi'.c,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          for (final s in sebepler)
            ListTile(title: Text(s.c), onTap: () => Navigator.pop(context, s)),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (secilen == null) return;
  try {
    await Api.sikayetEt(tur, hedefId, secilen);
    messenger.showSnackBar(
      SnackBar(content: Text('Şikayetin alındı, teşekkürler'.c)),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.toString())));
  }
}

/// Push edilen (alt menüsüz) ekranlarda kaydırma sonunun telefonun sistem
/// gezinme çubuğu (3 buton / gesture) altında kalmaması için alt boşluk.
double altGuvenli(BuildContext context, {double ekstra = 16}) =>
    MediaQuery.of(context).padding.bottom + ekstra;
