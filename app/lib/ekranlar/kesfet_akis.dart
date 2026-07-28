import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'etiket.dart';
import 'ortak.dart';

/// Keşfet (Reels tarzı): akış öncelikleriyle gelen postlar — önce videolar,
/// sonra fotoğraflılar, sonra yazılı yorumlar. Izgaradan birine dokununca
/// tam ekran dikey kaydırmalı görünüm açılır.
class KesfetAkisEkrani extends StatefulWidget {
  const KesfetAkisEkrani({super.key});

  @override
  State<KesfetAkisEkrani> createState() => _KesfetAkisEkraniState();
}

class _KesfetAkisEkraniState extends State<KesfetAkisEkrani>
    with AutomaticKeepAliveClientMixin {
  List<dynamic>? _liste;
  Map<String, dynamic> _icerikler = {};
  String? _hata;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      final d = await Api.get('/kesfet-akis');
      if (!mounted) return;
      setState(() {
        _liste = d['akis'] as List<dynamic>;
        _icerikler = d['icerikler'] as Map<String, dynamic>? ?? {};
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
    }
  }

  void _ac(int i) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) =>
            ReelsGorunumu(liste: _liste!, icerikler: _icerikler, baslangic: i),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_liste == null) {
      govde = GridView.builder(
        padding: const EdgeInsets.all(2),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          childAspectRatio: 0.66,
        ),
        itemCount: 12,
        itemBuilder: (context, i) =>
            const IskeletKutu(genislik: 120, yukseklik: 180),
      );
    } else if (_liste!.isEmpty) {
      govde = BosDurum(
        ikon: Icons.explore_outlined,
        baslik: 'Sonuç bulunamadı'.c,
        ipucu:
            'Akışın boş.\nİzlediğin dizi ve filmlere yorum yapılınca burada görünecek.'
                .c,
      );
    } else {
      final genis = MediaQuery.of(context).size.width > 900;
      govde = RefreshIndicator(
        color: DiziRenkler.sari,
        onRefresh: _yukle,
        child: GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: genis ? 5 : 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 0.66,
          ),
          itemCount: _liste!.length,
          itemBuilder: (context, i) => _KesfetKutusu(
            yorum: _liste![i] as Map<String, dynamic>,
            icerikler: _icerikler,
            onTap: () => _ac(i),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('Keşfet'.c)),
      body: govde,
    );
  }
}

/// Izgara karosu: medya varsa görsel (videoda oynatma rozeti), yoksa
/// içerik posteri + yorum metni.
class _KesfetKutusu extends StatelessWidget {
  final Map<String, dynamic> yorum;
  final Map<String, dynamic> icerikler;
  final VoidCallback onTap;
  const _KesfetKutusu({
    required this.yorum,
    required this.icerikler,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final medya = (yorum['medya'] as List<dynamic>? ?? []).cast<String>();
    final videolu = yorum['videolu'] == true;
    final spoiler = yorum['spoiler'] == true;
    final icerik =
        icerikler['${yorum['tur']}:${yorum['tmdb_id']}']
            as Map<String, dynamic>? ??
        const {'ad': '?', 'poster': null};
    // Görsel: ilk fotoğraf; yoksa (video/yazı) içerik posteri
    final ilkFoto = medya
        .where((m) => !m.endsWith('.mp4') && !m.endsWith('.webm'))
        .toList();
    final arka = ilkFoto.isNotEmpty
        ? dosyaUrl(ilkFoto.first)
        : posterUrl(icerik['poster'] as String?, boyut: 'w342');
    return InkWell(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          arka != null
              ? CachedNetworkImage(imageUrl: arka, fit: BoxFit.cover)
              : Container(color: DiziRenkler.kart),
          // Yazılı yorum: alt yarıda metin bandı
          if (medya.isEmpty)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(6),
                color: Colors.black54,
                child: Text(
                  spoiler ? '•••' : (yorum['metin'] as String? ?? ''),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          if (videolu)
            const Positioned(
              top: 6,
              right: 6,
              child: Icon(Icons.play_arrow, size: 20, color: Colors.white),
            ),
          if (spoiler)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Icon(
                  Icons.visibility_off_outlined,
                  color: Colors.white70,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tam ekran dikey kaydırmalı Reels görünümü.
class ReelsGorunumu extends StatefulWidget {
  final List<dynamic> liste;
  final Map<String, dynamic> icerikler;
  final int baslangic;
  const ReelsGorunumu({
    super.key,
    required this.liste,
    required this.icerikler,
    required this.baslangic,
  });

  @override
  State<ReelsGorunumu> createState() => _ReelsGorunumuState();
}

class _ReelsGorunumuState extends State<ReelsGorunumu> {
  late final PageController _sayfa = PageController(
    initialPage: widget.baslangic,
  );

  @override
  void dispose() {
    _sayfa.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _sayfa,
            scrollDirection: Axis.vertical,
            itemCount: widget.liste.length,
            itemBuilder: (context, i) => _ReelSayfa(
              key: ValueKey((widget.liste[i] as Map<String, dynamic>)['id']),
              yorum: widget.liste[i] as Map<String, dynamic>,
              icerikler: widget.icerikler,
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                tooltip: 'Kapat'.c,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.black38),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelSayfa extends StatefulWidget {
  final Map<String, dynamic> yorum;
  final Map<String, dynamic> icerikler;
  const _ReelSayfa({super.key, required this.yorum, required this.icerikler});

  @override
  State<_ReelSayfa> createState() => _ReelSayfaState();
}

class _ReelSayfaState extends State<_ReelSayfa> {
  VideoPlayerController? _d;
  late bool _begendim = widget.yorum['begendim'] == true;
  late int _begeni = (widget.yorum['begeni'] as num?)?.toInt() ?? 0;
  late bool _takipte = widget.yorum['takip_ediyorum'] == true;
  late bool _spoilerAcik = widget.yorum['spoiler'] != true;
  bool _kalpGoster = false; // çift dokunuş animasyonu

  String? get _videoUrl {
    for (final m in (widget.yorum['medya'] as List<dynamic>? ?? [])) {
      final s = m as String;
      if (s.endsWith('.mp4') || s.endsWith('.webm')) return dosyaUrl(s);
    }
    return null;
  }

  String? get _fotoUrl {
    for (final m in (widget.yorum['medya'] as List<dynamic>? ?? [])) {
      final s = m as String;
      if (!s.endsWith('.mp4') && !s.endsWith('.webm')) return dosyaUrl(s);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final v = _videoUrl;
    if (v != null) {
      final d = VideoPlayerController.networkUrl(Uri.parse(v));
      d
          .initialize()
          .then((_) {
            if (!mounted) return;
            setState(() => _d = d);
            d.setLooping(true);
            if (_spoilerAcik) d.play();
            d.addListener(() {
              if (mounted) setState(() {});
            });
          })
          .catchError((_) {});
    }
  }

  @override
  void dispose() {
    _d?.dispose();
    super.dispose();
  }

  Future<void> _begenToggle({bool sadeceBegen = false}) async {
    if (sadeceBegen && _begendim) return;
    setState(() {
      _begendim = sadeceBegen ? true : !_begendim;
      _begeni += _begendim ? 1 : -1;
    });
    try {
      await Api.post('/yorumlar/${widget.yorum['id']}/begen', {});
    } catch (_) {
      // geri al
      if (mounted) {
        setState(() {
          _begendim = !_begendim;
          _begeni += _begendim ? 1 : -1;
        });
      }
    }
  }

  void _ciftDokunus() {
    _begenToggle(sadeceBegen: true);
    setState(() => _kalpGoster = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _kalpGoster = false);
    });
  }

  Future<void> _takipToggle() async {
    final ad = widget.yorum['kullanici_adi'] as String;
    setState(() => _takipte = !_takipte);
    try {
      await Api.takipToggle(ad);
    } catch (_) {
      if (mounted) setState(() => _takipte = !_takipte);
    }
  }

  String get _icerikYolu {
    final y = widget.yorum;
    if (y['sezon'] != null) {
      return '/dizi/${y['tmdb_id']}/sezon/${y['sezon']}/bolum/${y['bolum']}';
    }
    if (y['tur'] == 'person') return '/kisi/${y['tmdb_id']}';
    return '/icerik/${y['tur']}/${y['tmdb_id']}';
  }

  Future<void> _paylas() async {
    final url = 'https://dizijpg.com$_icerikYolu';
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kopyalandı: {}'.cf([url]))));
    }
  }

  void _yanitlarAc() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DiziRenkler.koyuGri,
      builder: (_) => _YanitlarSheet(yorum: widget.yorum),
    );
  }

  String _sure(Duration s) {
    final dk = s.inMinutes, sn = s.inSeconds % 60;
    return '$dk:${sn.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final y = widget.yorum;
    final icerik =
        widget.icerikler['${y['tur']}:${y['tmdb_id']}']
            as Map<String, dynamic>? ??
        const {'ad': '?', 'poster': null};
    final avatar = dosyaUrl(y['avatar'] as String?);
    final d = _d;
    final foto = _fotoUrl;
    final poster = posterUrl(icerik['poster'] as String?, boyut: 'w500');

    Widget zemin;
    if (d != null && d.value.isInitialized) {
      zemin = Center(
        child: AspectRatio(
          aspectRatio: d.value.aspectRatio == 0 ? 9 / 16 : d.value.aspectRatio,
          child: VideoPlayer(d),
        ),
      );
    } else if (_videoUrl != null) {
      zemin = const Center(
        child: CircularProgressIndicator(color: DiziRenkler.sari),
      );
    } else if (foto != null) {
      zemin = Center(
        child: CachedNetworkImage(imageUrl: foto, fit: BoxFit.contain),
      );
    } else {
      // Yazılı yorum: poster arka planlı alıntı kartı
      zemin = Stack(
        fit: StackFit.expand,
        children: [
          if (poster != null)
            Opacity(
              opacity: 0.25,
              child: CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover),
            ),
          Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 160),
              child: EtiketliMetin(
                y['metin'] as String? ?? '',
                stil: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () {
        if (d != null) {
          d.value.isPlaying ? d.pause() : d.play();
        }
      },
      onDoubleTap: _ciftDokunus,
      // Sola kaydırma → paylaşanın profili (TikTok davranışı)
      onHorizontalDragEnd: (detay) {
        if ((detay.primaryVelocity ?? 0) < -250) {
          kullaniciyaGit(context, y['kullanici_adi'] as String);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          zemin,
          // Spoiler örtüsü
          if (!_spoilerAcik)
            GestureDetector(
              onTap: () {
                setState(() => _spoilerAcik = true);
                _d?.play();
              },
              child: Container(
                color: Colors.black.withValues(alpha: 0.85),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.visibility_off_outlined,
                        size: 44,
                        color: Colors.white70,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Spoiler olabilir — dokun ve gör'.c,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Alt karartma
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 220,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Çift dokunuş kalbi
          if (_kalpGoster)
            const Center(
              child: Icon(Icons.favorite, size: 110, color: Colors.white70),
            ),
          // Sol alt: kullanıcı + takip + metin + içerik + süre
          Positioned(
            left: 14,
            right: 86,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () =>
                          kullaniciyaGit(context, y['kullanici_adi'] as String),
                      child: CircleAvatar(
                        radius: 19,
                        backgroundColor: DiziRenkler.kart,
                        backgroundImage: avatar != null
                            ? CachedNetworkImageProvider(avatar)
                            : null,
                        child: avatar == null
                            ? const Icon(
                                Icons.person,
                                size: 19,
                                color: Colors.white54,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: GestureDetector(
                        onTap: () => kullaniciyaGit(
                          context,
                          y['kullanici_adi'] as String,
                        ),
                        child: Text(
                          '@${y['kullanici_adi']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (!_takipte)
                      SizedBox(
                        height: 30,
                        child: OutlinedButton(
                          onPressed: _takipToggle,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            side: const BorderSide(color: Colors.white70),
                          ),
                          child: Text(
                            'Takip Et'.c,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                // Yorum metni (medyalı postta altta gösterilir)
                if ((y['metin'] as String?)?.isNotEmpty == true &&
                    (foto != null || _videoUrl != null)) ...[
                  const SizedBox(height: 8),
                  Text(
                    y['metin'] as String,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, height: 1.35),
                  ),
                ],
                const SizedBox(height: 8),
                // İçerik rozeti → içerik sayfası
                GestureDetector(
                  onTap: () => rotayaGitGuvenli(context, _icerikYolu),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_movies_outlined,
                        size: 15,
                        color: DiziRenkler.sari,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '${icerik['ad']}'
                          '${y['sezon'] != null ? ' · S${y['sezon']}B${y['bolum']}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: DiziRenkler.sari,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (d != null && d.value.isInitialized) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${_sure(d.value.position)} / ${_sure(d.value.duration)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          // Sağ alt: beğeni / yorum / paylaş
          Positioned(
            right: 10,
            bottom: 30,
            child: Column(
              children: [
                _ReelsDugme(
                  ikon: _begendim ? Icons.favorite : Icons.favorite_border,
                  renk: _begendim ? Colors.redAccent : Colors.white,
                  etiket: '$_begeni',
                  onTap: _begenToggle,
                ),
                const SizedBox(height: 16),
                _ReelsDugme(
                  ikon: Icons.mode_comment_outlined,
                  etiket: 'Yanıtlar'.c,
                  onTap: _yanitlarAc,
                ),
                const SizedBox(height: 16),
                _ReelsDugme(
                  ikon: Icons.share_outlined,
                  etiket: 'Paylaş'.c,
                  onTap: _paylas,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kabuk-güvenli rota gezinmesi (Reels kök gezginin üstünde açık olabilir).
void rotayaGitGuvenli(BuildContext context, String hedef) {
  GoRouter.of(context).push(hedef);
}

class _ReelsDugme extends StatelessWidget {
  final IconData ikon;
  final Color renk;
  final String etiket;
  final VoidCallback onTap;
  const _ReelsDugme({
    required this.ikon,
    required this.etiket,
    required this.onTap,
    this.renk = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            Icon(ikon, size: 30, color: renk),
            const SizedBox(height: 3),
            Text(
              etiket,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yanıtlar alt sayfası: bu yoruma verilen yanıtlar + yanıt yazma.
class _YanitlarSheet extends StatefulWidget {
  final Map<String, dynamic> yorum;
  const _YanitlarSheet({required this.yorum});

  @override
  State<_YanitlarSheet> createState() => _YanitlarSheetState();
}

class _YanitlarSheetState extends State<_YanitlarSheet> {
  List<dynamic>? _yanitlar;
  final _kutu = TextEditingController();
  bool _gonderiliyor = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _kutu.dispose();
    super.dispose();
  }

  String get _sorgu => widget.yorum['sezon'] != null
      ? '?sezon=${widget.yorum['sezon']}&bolum=${widget.yorum['bolum']}'
      : '';

  Future<void> _yukle() async {
    try {
      final d = await Api.get(
        '/yorumlar/${widget.yorum['tur']}/${widget.yorum['tmdb_id']}$_sorgu',
      );
      if (!mounted) return;
      setState(() {
        _yanitlar = (d['yorumlar'] as List<dynamic>)
            .where((c) => c['ust_id'] == widget.yorum['id'])
            .toList();
      });
    } catch (_) {
      if (mounted) setState(() => _yanitlar = []);
    }
  }

  Future<void> _gonder() async {
    final metin = _kutu.text.trim();
    if (metin.isEmpty || _gonderiliyor) return;
    setState(() => _gonderiliyor = true);
    try {
      final y = widget.yorum;
      await Api.post('/yorumlar', {
        'tur': y['tur'],
        'tmdb_id': y['tmdb_id'],
        if (y['sezon'] != null) 'sezon': y['sezon'],
        if (y['sezon'] != null) 'bolum': y['bolum'],
        'metin': metin,
        'medya': const [],
        'ust_id': y['id'],
      });
      _kutu.clear();
      await _yukle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(
                    Icons.mode_comment_outlined,
                    size: 18,
                    color: DiziRenkler.sari,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Yanıtlar'.c,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_yanitlar?.length ?? ''}',
                    style: TextStyle(color: DiziRenkler.metin54),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _yanitlar == null
                  ? const Center(
                      child: CircularProgressIndicator(color: DiziRenkler.sari),
                    )
                  : (_yanitlar!.isEmpty
                        ? Center(
                            child: Text(
                              'Henüz yorum yok.'.c,
                              style: TextStyle(color: DiziRenkler.metin54),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            itemCount: _yanitlar!.length,
                            itemBuilder: (context, i) {
                              final c = _yanitlar![i] as Map<String, dynamic>;
                              final av = dosyaUrl(c['avatar'] as String?);
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 7,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: DiziRenkler.kart,
                                      backgroundImage: av != null
                                          ? CachedNetworkImageProvider(av)
                                          : null,
                                      child: av == null
                                          ? Icon(
                                              Icons.person,
                                              size: 14,
                                              color: DiziRenkler.metin38,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '@${c['kullanici_adi']}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                          EtiketliMetin(
                                            c['metin'] as String? ?? '',
                                            stil: TextStyle(
                                              color: DiziRenkler.metin70,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _kutu,
                      maxLength: 1000,
                      buildCounter:
                          (
                            _, {
                            required currentLength,
                            maxLength,
                            required isFocused,
                          }) => null,
                      decoration: InputDecoration(
                        hintText: 'Yorumunu yaz... (@ ile etiketle)'.c,
                      ),
                      onSubmitted: (_) => _gonder(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _gonderiliyor ? null : _gonder,
                    icon: _gonderiliyor
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: DiziRenkler.sari,
                            ),
                          )
                        : const Icon(Icons.send, color: DiziRenkler.sari),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
