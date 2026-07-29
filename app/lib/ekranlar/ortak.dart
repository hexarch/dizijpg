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
/// Tek medya: tam genişlik büyük (16:10). Çoklu (2-4): 2 sütun kare ızgara.
/// Videoda büyük kapak + dokununca TAM EKRAN oynatıcı. otomatikOynat=true
/// (akış) ile kapak yerine yerinde oynatıcı: ekran ortasına gelen video sessiz
/// başlar, uzaklaşınca durur — AkisVideo aynı anda tek video oynatır, bu
/// yüzden birden çok oynatıcı çakışıp çift ses vermez.
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
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(aspectRatio: 16 / 10, child: hucre(0)),
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

/// Akışta yerinde oynayan video. Kaydırırken siyah kapakla duraklamış durur;
/// ekran ortasına EN YAKIN görünür video sessiz oynamaya başlar, merkezden
/// uzaklaşınca (veya başka kart merkeze gelince) durur. Statik aday kaydıyla
/// aynı anda yalnız BİR video oynar. Ses kapalı başlar (web otomatik oynatma
/// kuralı); sağ alttaki hoparlör rozeti oturum boyu ortak ses tercihini açar.
/// Karta dokunuş üstteki InkWell'e düşer (akışta Reels açar).
class AkisVideo extends StatefulWidget {
  final String url;
  const AkisVideo({super.key, required this.url});

  @override
  State<AkisVideo> createState() => _AkisVideoState();
}

class _AkisVideoState extends State<AkisVideo> {
  /// Görünür adaylar → ekran merkezine dikey uzaklık (px). En yakını oynar.
  static final Map<_AkisVideoState, double> _adaylar = {};
  static _AkisVideoState? _aktif;
  static bool _sesli = false; // oturum boyu ortak ses tercihi

  VideoPlayerController? _d;
  Future<void>? _kurulum; // ilk oynatma isteğinde tembel kurulur
  bool _hata = false;

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
    try {
      final d = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await d.initialize();
      if (!mounted) {
        d.dispose();
        return;
      }
      d.setLooping(true);
      setState(() => _d = d);
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
    return VisibilityDetector(
      key: ValueKey('akis-video-${widget.url}'),
      onVisibilityChanged: _gorunurluk,
      child: Container(color: Colors.black87, child: govde),
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
