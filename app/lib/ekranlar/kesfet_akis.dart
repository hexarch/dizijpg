import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import '../veri_tasarrufu.dart';
import 'etiket.dart';
import 'ortak.dart';
import 'paylas.dart';

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

/// Tek gönderi ekranı (paylaşılan link → /gonderi/:id): yorumu çekip
/// Reels görünümünde tek sayfa olarak tam ekran açar.
class GonderiEkrani extends StatefulWidget {
  final int yorumId;
  const GonderiEkrani({super.key, required this.yorumId});

  @override
  State<GonderiEkrani> createState() => _GonderiEkraniState();
}

class _GonderiEkraniState extends State<GonderiEkrani> {
  Map<String, dynamic>? _yorum;
  Map<String, dynamic> _icerikler = {};
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  // Paylaşılan gönderiden sonra kaydırma DEVAM etsin: bu gönderi başta,
  // ardından keşfet akışı gelir (mesajdan gelen kullanıcı tek postta kilitli
  // kalmasın).
  List<dynamic> _devam = [];

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      final d = await Api.get('/yorum/${widget.yorumId}');
      if (!mounted) return;
      setState(() {
        _yorum = d['yorum'] as Map<String, dynamic>;
        _icerikler = d['icerikler'] as Map<String, dynamic>? ?? {};
      });
      _devamYukle();
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
    }
  }

  Future<void> _devamYukle() async {
    try {
      final d = await Api.get('/kesfet-akis');
      if (!mounted) return;
      final liste = (d['akis'] as List<dynamic>? ?? [])
          .where((y) => (y as Map<String, dynamic>)['id'] != widget.yorumId)
          .toList();
      setState(() {
        _devam = liste;
        _icerikler = {
          ..._icerikler,
          ...(d['icerikler'] as Map<String, dynamic>? ?? {}),
        };
      });
    } catch (_) {
      // devam listesi gelmezse tek gönderi olarak kalır
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hata != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.link_off, size: 48, color: DiziRenkler.metin38),
                const SizedBox(height: 12),
                Text(
                  'Gönderi bulunamadı'.c,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: DiziRenkler.metin54),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => GoRouter.of(context).go('/arama'),
                  child: Text('Keşfet\'e dön'.c),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_yorum == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: DiziRenkler.sari)),
      );
    }
    return ReelsGorunumu(
      liste: [_yorum!, ..._devam],
      icerikler: _icerikler,
      baslangic: 0,
    );
  }
}

/// Tam ekran dikey kaydırmalı Reels görünümü.
class ReelsGorunumu extends StatefulWidget {
  final List<dynamic> liste;
  final Map<String, dynamic> icerikler;
  final int baslangic;

  /// Açılış gönderisinde KAÇINCI medyadan başlanacağı. Akışta 5. fotoğrafa
  /// dokunan kullanıcı Reels'te de 5. fotoğrafı görmeli (eskiden hep 1.
  /// açılıyordu; kullanıcı "sonraki resim gelmiyor" diye bildirdi).
  final int medyaBaslangic;
  const ReelsGorunumu({
    super.key,
    required this.liste,
    required this.icerikler,
    required this.baslangic,
    this.medyaBaslangic = 0,
  });

  @override
  State<ReelsGorunumu> createState() => _ReelsGorunumuState();
}

class _ReelsGorunumuState extends State<ReelsGorunumu> {
  late final PageController _sayfa = PageController(
    initialPage: widget.baslangic,
  );
  late int _aktif = widget.baslangic; // yalnız aktif sayfa oynar/işaretlenir

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
            // Komşu sayfalar ÖNDEN kurulur → sıradaki video kaydırmadan önce
            // yüklenmeye başlar (bunsuz her kaydırışta bekleniyordu).
            allowImplicitScrolling: true,
            // Aktif sayfa değişince: yalnız görünen sayfa video oynatır ve
            // "görüldü" işaretlenir (komşu sayfalar önden kurulsa da sessiz).
            onPageChanged: (i) => setState(() => _aktif = i),
            itemBuilder: (context, i) => _ReelSayfa(
              key: ValueKey((widget.liste[i] as Map<String, dynamic>)['id']),
              yorum: widget.liste[i] as Map<String, dynamic>,
              icerikler: widget.icerikler,
              aktif: i == _aktif,
              // Yalnız açılış gönderisi dokunulan medyadan başlar; diğerleri
              // her zaman baştan.
              medyaBaslangic: i == widget.baslangic ? widget.medyaBaslangic : 0,
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                tooltip: 'Kapat'.c,
                // Doğrudan URL ile açıldıysa (paylaşılan gönderi linki) geri
                // gidilecek yer yoktur → Keşfet'e dön.
                onPressed: () => Navigator.of(context).canPop()
                    ? Navigator.pop(context)
                    : GoRouter.of(context).go('/arama'),
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
  final bool aktif; // ekranda görünen sayfa mı (yalnız o oynar/işaretlenir)
  final int medyaBaslangic; // açılışta gösterilecek medyanın sırası
  const _ReelSayfa({
    super.key,
    required this.yorum,
    required this.icerikler,
    this.aktif = true,
    this.medyaBaslangic = 0,
  });

  @override
  State<_ReelSayfa> createState() => _ReelSayfaState();
}

class _ReelSayfaState extends State<_ReelSayfa>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _d;
  late bool _begendim = widget.yorum['begendim'] == true;
  late int _begeni = (widget.yorum['begeni'] as num?)?.toInt() ?? 0;
  late bool _takipte = widget.yorum['takip_ediyorum'] == true;
  late bool _spoilerAcik = widget.yorum['spoiler'] != true;
  // Çift dokunuş kalbi: dokunulan KONUMDA belirir, yükselip solar.
  // DİKKAT: `late final` ile TEMBEL kurulmamalı — kullanıcı hiç çift
  // dokunmadan sayfadan çıkarsa ilk erişim dispose() içinde olur ve vsync
  // araması koparılmış widget üzerinde patlar. initState'te kurulur.
  late final AnimationController _kalpAnim;
  Offset? _kalpKonum;

  /// Gönderinin TÜM medyası (sırayla) — çoklu gönderide yana kaydırılır.
  late final List<String> _medya = [
    for (final m in (widget.yorum['medya'] as List<dynamic>? ?? []))
      dosyaUrl(m as String)!,
  ];
  late int _medyaSayfa = widget.medyaBaslangic.clamp(
    0,
    _medya.isEmpty ? 0 : _medya.length - 1,
  );
  String? _kuruluUrl; // oynatıcının kurulu olduğu video adresi
  bool _metinAcik = false; // uzun yorum metni açıldı mı ("... devamı")

  static bool _videoMu(String u) => u.endsWith('.mp4') || u.endsWith('.webm');

  /// Ekranda duran medya (çoklu gönderide kaydırmayla değişir)
  String? get _aktifMedya =>
      _medya.isEmpty ? null : _medya[_medyaSayfa.clamp(0, _medya.length - 1)];

  String? get _videoUrl {
    final m = _aktifMedya;
    return (m != null && _videoMu(m)) ? m : null;
  }

  String? get _fotoUrl {
    final m = _aktifMedya;
    return (m != null && !_videoMu(m)) ? m : null;
  }

  bool _isaretlendi = false;

  /// Bu gönderiyi gördü → bir daha akış/keşfette gösterilmesin (yalnız bir kez,
  /// ve YALNIZ sayfa gerçekten aktifleşince — komşu sayfalar sayılmaz).
  void _isaretle() {
    if (_isaretlendi) return;
    _isaretlendi = true;
    Api.post('/akis/goruldu', {
      'idler': [widget.yorum['id']],
    }).catchError((_) => null);
  }

  /// Yalnız aktif (ekranda görünen) sayfa oynar → çift ses olmaz.
  void _videoDurumGuncelle() {
    final d = _d;
    if (d == null || !d.value.isInitialized) return;
    if (widget.aktif && _spoilerAcik) {
      d.play();
    } else {
      d.pause();
    }
  }

  @override
  void didUpdateWidget(_ReelSayfa eski) {
    super.didUpdateWidget(eski);
    if (widget.aktif && !eski.aktif) _isaretle();
    if (widget.aktif != eski.aktif) _videoDurumGuncelle();
    if (widget.aktif && !eski.aktif) _medyaOnbellekle();
  }

  @override
  void initState() {
    super.initState();
    _kalpAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.aktif) _isaretle();
    _videoKur();
    if (widget.aktif) _medyaOnbellekle();
  }

  bool _onbellekBasladi = false;

  /// Aktif gönderinin TÜM fotoğraflarını önden indirir. Eskiden yalnız ekranda
  /// duran kare iniyordu; kullanıcı yana kaydırdıkça her seferinde indirmeyi
  /// bekliyordu. Kareler ~180 KB, 10'luk gönderi ~1,8 MB → önden almak ucuz.
  /// Yalnız AKTİF sayfa için çalışır (komşu gönderiler kendi ilk karesini
  /// zaten PageView'ın önden kurmasıyla yüklüyor).
  ///
  /// Veri tasarrufu o bağlantı için AÇIKSA hiç indirmez (varsayılan: mobil
  /// veride açık, Wi-Fi'da kapalı) — Ayarlar > Veri tasarrufu.
  void _medyaOnbellekle() {
    if (!VeriTasarrufu.onYuklemeSerbest) return;
    if (_onbellekBasladi || _medya.length < 2) return;
    _onbellekBasladi = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final u in _medya) {
        if (_videoMu(u)) continue; // videolar akışla gelir, önbelleğe alınmaz
        precacheImage(
          CachedNetworkImageProvider(u),
          context,
          onError: (_, _) {}, // ağ hatası sessiz geçilir, gösterim etkilenmez
        );
      }
    });
  }

  /// Ekrandaki medya videoysa oynatıcıyı kurar (kaydırınca yenisine geçilir).
  void _videoKur() {
    final v = _videoUrl;
    if (v == null || v == _kuruluUrl) return;
    _kuruluUrl = v;
    final eski = _d;
    setState(() => _d = null);
    eski?.dispose();
    final d = VideoPlayerController.networkUrl(Uri.parse(v));
    d
        .initialize()
        .then((_) {
          if (!mounted || _kuruluUrl != v) {
            d.dispose();
            return;
          }
          setState(() => _d = d);
          d.setLooping(true);
          _videoDurumGuncelle(); // yalnız aktifse oynar
          d.addListener(() {
            if (mounted) setState(() {});
          });
        })
        .catchError((_) {});
  }

  /// Yana kaydırma: sonraki/önceki medya; SON medyadan sonra sola kaydırınca
  /// paylaşan kişinin profiline gidilir (TikTok davranışı).
  void _yanaKaydir(double hiz) {
    final y = widget.yorum;
    if (hiz < 0) {
      if (_medyaSayfa < _medya.length - 1) {
        setState(() => _medyaSayfa++);
        _videoKur();
      } else {
        kullaniciyaGit(context, y['kullanici_adi'] as String);
      }
    } else if (hiz > 0 && _medyaSayfa > 0) {
      setState(() => _medyaSayfa--);
      _videoKur();
    }
  }

  @override
  void dispose() {
    _kalpAnim.dispose();
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

  void _ciftDokunus(Offset konum) {
    _begenToggle(sadeceBegen: true);
    setState(() => _kalpKonum = konum);
    _kalpAnim.forward(from: 0);
  }

  /// Tek dokunuş: video varsa durdur/oynat (TikTok davranışı).
  void _dokunus() {
    final d = _d;
    if (d == null || !d.value.isInitialized) return;
    d.value.isPlaying ? d.pause() : d.play();
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
    // Paylaşım sayfası: kişilere DM olarak gönder + telefonun kendi paylaşım
    // sayfası (WhatsApp/e-posta/Instagram...) + bağlantıyı kopyala.
    // Bağlantı içeriğe değil bu GÖNDERİYE gider (/gonderi/:id).
    await paylasSheet(
      context,
      url: 'https://dizijpg.com/gonderi/${widget.yorum['id']}',
      metin: widget.yorum['metin'] as String?,
      yorumId: widget.yorum['id'] as int,
    );
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
    // Android'in alt sistem çubuğu (geri/ana/menü tuşları) sabit olduğundan
    // alt bilgiler (kullanıcı/süre) ve ilerleme çubuğu onun ALTINDA kalmasın.
    final altInset = MediaQuery.of(context).padding.bottom;

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
                koyuZemin: true, // Reels daima siyah zemin → parlak sarı etiket
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

    return Stack(
      fit: StackFit.expand,
      children: [
        zemin,
        // Dokunuş katmanı: web'de video bir platform görünümüdür ve
        // dokunuşları DOM'da yutar — PointerInterceptor olayları Flutter'a
        // geri taşır. Videonun ÜSTÜNDE durmalı, diğer kontrollerin altında.
        Positioned.fill(
          child: PointerInterceptor(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dokunus,
              // Konumlu: kalp tam dokunulan yerde belirir
              onDoubleTapDown: (d) => _ciftDokunus(d.localPosition),
              onDoubleTap: () {},
              // Yana kaydırma: sonraki/önceki medya; son medyadan sonra
              // sola kaydırınca paylaşanın profili açılır.
              onHorizontalDragEnd: (detay) {
                final hiz = detay.primaryVelocity ?? 0;
                if (hiz.abs() > 250) _yanaKaydir(hiz);
              },
            ),
          ),
        ),
        // Çoklu medya sayacı sağ üstte ("3/10") — noktalar altta, alt blokta.
        if (_medya.length > 1)
          Positioned(
            top: MediaQuery.of(context).padding.top + 14,
            right: 14,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_medyaSayfa + 1}/${_medya.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        // Duraklatıldığında ortada oynat ikonu (dokunuşun görünür sonucu)
        if (d != null &&
            d.value.isInitialized &&
            !d.value.isPlaying &&
            _spoilerAcik)
          const IgnorePointer(
            child: Center(
              child: Icon(
                Icons.play_arrow_rounded,
                size: 88,
                color: Colors.white70,
              ),
            ),
          ),
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
        // Çift dokunuş kalbi: dokunulan KONUMDA belirir, hafifçe yükselip solar
        if (_kalpKonum != null)
          AnimatedBuilder(
            animation: _kalpAnim,
            builder: (context, _) {
              final t = _kalpAnim.value; // 0→1
              if (t == 0 || t == 1) return const SizedBox.shrink();
              // Ölçek: hızlı büyür sonra sabit; opaklık: sonlara doğru solar;
              // konum: 40px yukarı kayar
              final olcek = t < 0.3 ? (0.4 + t / 0.3 * 0.9) : 1.3;
              final opaklik = t < 0.6 ? 1.0 : (1 - (t - 0.6) / 0.4);
              return Positioned(
                left: _kalpKonum!.dx - 55,
                top: _kalpKonum!.dy - 55 - t * 40,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: opaklik.clamp(0, 1),
                    child: Transform.scale(
                      scale: olcek,
                      child: const Icon(
                        Icons.favorite,
                        size: 110,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        // Alt blok: solda kullanıcı/metin/içerik, EN ALTTA ORTADA medya
        // noktaları (kullanıcılar taşıyıcı göstergesini altta arıyor).
        Positioned(
          left: 0,
          right: 0,
          bottom: 18 + altInset,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 14, right: 86),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => kullaniciyaGit(
                            context,
                            y['kullanici_adi'] as String,
                          ),
                          child: KullaniciAvatari(
                            url: avatar,
                            kullaniciAdi: y['kullanici_adi'] as String?,
                            yaricap: 19,
                            arkaplan: DiziRenkler.kart,
                            ikonRenk: Colors.white54,
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
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
                    // Yorum metni: uzunsa İKİ SATIR + "... devamı"; dokununca
                    // tamamı açılır (üstteki kullanıcı satırı yukarı kayar, uzun
                    // metin ekranı taşırmasın diye kendi içinde kaydırılır).
                    if ((y['metin'] as String?)?.isNotEmpty == true &&
                        (foto != null || _videoUrl != null)) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => setState(() => _metinAcik = !_metinAcik),
                        behavior: HitTestBehavior.opaque,
                        child: _metinAcik
                            ? ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight:
                                      MediaQuery.of(context).size.height * 0.42,
                                ),
                                child: SingleChildScrollView(
                                  child: Text(
                                    y['metin'] as String,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              )
                            : Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(text: y['metin'] as String),
                                    TextSpan(
                                      text: '  ${'devamı'.c}',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.75,
                                        ),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  height: 1.35,
                                ),
                              ),
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
                              '${y['sezon'] != null ? ' · ${'S{}B{}'.cf([y['sezon'], y['bolum']])}' : ''}',
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
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Çoklu medya nokta göstergesi: ekranın tam altında, ortada.
              if (_medya.length > 1) ...[
                const SizedBox(height: 12),
                IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _medya.length; i++)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _medyaSayfa
                                ? Colors.white
                                : Colors.white38,
                            boxShadow: const [
                              BoxShadow(color: Colors.black45, blurRadius: 3),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        // Sağ alt: görüntülenme / beğeni / yorum / paylaş
        Positioned(
          right: 10,
          bottom: 30 + altInset,
          child: Column(
            children: [
              // Görüntülenme (salt bilgi, buton değil)
              Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  children: [
                    const Icon(
                      Icons.remove_red_eye_outlined,
                      size: 28,
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${(y['goruntulenme'] as num?)?.toInt() ?? 0}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
                // Sohbete gönder: alt sayfada kişiler listelenir, dokunulan
                // kişiye gönderinin KENDİSİ gider (kart olarak).
                ikon: Icons.send_outlined,
                etiket: 'Paylaş'.c,
                onTap: _paylas,
              ),
            ],
          ),
        ),
        // En altta ince ilerleme çubuğu (IG/TikTok): dokunarak/sürükleyerek
        // sarılır; üst padding dokunma hedefini büyütür.
        if (d != null && d.value.isInitialized)
          Positioned(
            left: 0,
            right: 0,
            bottom: altInset,
            child: VideoProgressIndicator(
              d,
              allowScrubbing: true,
              padding: const EdgeInsets.only(top: 14, bottom: 2),
              colors: const VideoProgressColors(
                playedColor: DiziRenkler.sari,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
      ],
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
  final List<Map<String, dynamic>> _ekler = []; // {yol, video}
  bool _ekYukleniyor = false;
  Map<String, dynamic>? _yanitlanan; // yanıtın yanıtı: hedeflenen satır

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
        _yanitlar =
            (d['yorumlar'] as List<dynamic>)
                .where((c) => c['ust_id'] == widget.yorum['id'])
                .toList()
              // Sohbet akışı gibi eskiden yeniye
              ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
      });
    } catch (_) {
      if (mounted) setState(() => _yanitlar = []);
    }
  }

  Future<void> _sil(int id) async {
    try {
      await Api.delete('/yorumlar/$id');
      await _yukle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _ekSec() async {
    if (_ekler.length >= 4) return;
    final secim = await ImagePicker().pickMedia();
    if (secim == null) return;
    setState(() => _ekYukleniyor = true);
    try {
      final veri = await secim.readAsBytes();
      if (veri.length > 30 * 1024 * 1024) {
        throw ApiHata('Dosya en fazla {}MB olabilir'.cf([30]));
      }
      final d = await Api.medyaYukle(veri);
      if (!mounted) return;
      setState(() => _ekler.add({'yol': d['yol'], 'video': d['video']}));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _ekYukleniyor = false);
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
        'medya': _ekler.map((e) => e['yol']).toList(),
        // Bir yanıta yanıt veriliyorsa onun id'si gider; sunucu üst yoruma
        // bağlar ve yanıtlanan kişiye bildirim düşer.
        'ust_id': _yanitlanan?['id'] ?? y['id'],
      });
      _kutu.clear();
      _ekler.clear();
      _yanitlanan = null;
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
                              return _KesfetYanitSatiri(
                                key: ValueKey(c['id']),
                                yanit: c,
                                benim:
                                    c['kullanici_id'] ==
                                    context.read<Oturum>().kullanici?['id'],
                                sil: () => _sil(c['id'] as int),
                                yanitla: () => setState(() => _yanitlanan = c),
                              );
                            },
                          )),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_yanitlanan != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.reply,
                          size: 16,
                          color: DiziRenkler.sari,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '@{} kullanıcısına yanıt veriyorsun'.cf([
                              _yanitlanan!['kullanici_adi'],
                            ]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: DiziRenkler.sari,
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => setState(() => _yanitlanan = null),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: DiziRenkler.metin38,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (_ekler.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          for (var i = 0; i < _ekler.length; i++)
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 60,
                                    height: 60,
                                    child: _ekler[i]['video'] == true
                                        ? Container(
                                            color: DiziRenkler.kart,
                                            child: Icon(
                                              Icons.videocam,
                                              color: DiziRenkler.metin54,
                                            ),
                                          )
                                        : CachedNetworkImage(
                                            imageUrl: dosyaUrl(
                                              _ekler[i]['yol'] as String,
                                            )!,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: InkWell(
                                    onTap: () =>
                                        setState(() => _ekler.removeAt(i)),
                                    child: const CircleAvatar(
                                      radius: 9,
                                      backgroundColor: Colors.black87,
                                      child: Icon(
                                        Icons.close,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: _ekYukleniyor || _ekler.length >= 4
                            ? null
                            : _ekSec,
                        tooltip: 'Fotoğraf / video ekle'.c,
                        icon: _ekYukleniyor
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: DiziRenkler.sari,
                                ),
                              )
                            : const Icon(
                                Icons.attach_file,
                                color: DiziRenkler.sari,
                              ),
                      ),
                      Expanded(
                        child: EtiketliGirdi(
                          controller: _kutu,
                          maxLength: 1000,
                          maxLines: 3,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: 'Yorumunu yaz... (@ ile etiketle)'.c,
                          ),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yanıtlar sayfasındaki tek satır: avatar + @ad (profil), tarih,
/// görüntülenme, beğeni (iyimser), yanıtla ve kendi yanıtını silme.
class _KesfetYanitSatiri extends StatefulWidget {
  final Map<String, dynamic> yanit;
  final bool benim;
  final VoidCallback sil;
  final VoidCallback yanitla;

  const _KesfetYanitSatiri({
    super.key,
    required this.yanit,
    required this.benim,
    required this.sil,
    required this.yanitla,
  });

  @override
  State<_KesfetYanitSatiri> createState() => _KesfetYanitSatiriState();
}

class _KesfetYanitSatiriState extends State<_KesfetYanitSatiri> {
  late bool _begendim = widget.yanit['begendim'] == true;
  late int _begeni = (widget.yanit['begeni'] as int?) ?? 0;
  bool _isleniyor = false;

  @override
  void didUpdateWidget(_KesfetYanitSatiri eski) {
    super.didUpdateWidget(eski);
    if (eski.yanit != widget.yanit) {
      _begendim = widget.yanit['begendim'] == true;
      _begeni = (widget.yanit['begeni'] as int?) ?? 0;
    }
  }

  Future<void> _begen() async {
    if (_isleniyor) return;
    setState(() {
      _isleniyor = true;
      // iyimser güncelleme
      _begendim = !_begendim;
      _begeni += _begendim ? 1 : -1;
    });
    try {
      final d = await Api.yorumBegen(widget.yanit['id'] as int);
      if (mounted) {
        setState(() {
          _begendim = d['begendim'] as bool;
          _begeni = d['begeni'] as int;
        });
      }
    } catch (_) {
      // geri al
      if (mounted) {
        setState(() {
          _begendim = !_begendim;
          _begeni += _begendim ? 1 : -1;
        });
      }
    } finally {
      if (mounted) setState(() => _isleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.yanit;
    final av = dosyaUrl(c['avatar'] as String?);
    final tarih = (c['tarih'] as String? ?? '').split('T').first;
    final goruntulenme = (c['goruntulenme'] as int?) ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => kullaniciyaGit(context, c['kullanici_adi'] as String),
            child: KullaniciAvatari(
              url: av,
              kullaniciAdi: c['kullanici_adi'] as String?,
              yaricap: 14,
              arkaplan: DiziRenkler.kart,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () =>
                          kullaniciyaGit(context, c['kullanici_adi'] as String),
                      child: Text(
                        '@${c['kullanici_adi']}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          // Yanıtlar sheet'i açık temada açık zemin → sariMetin
                          color: DiziRenkler.sariMetin,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tarih,
                      style: TextStyle(
                        fontSize: 10,
                        color: DiziRenkler.metin38,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                EtiketliMetin(
                  c['metin'] as String? ?? '',
                  stil: TextStyle(color: DiziRenkler.metin70, fontSize: 13),
                ),
                if ((c['medya'] as List<dynamic>? ?? []).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: MedyaGaleri(
                      yollar: (c['medya'] as List<dynamic>).cast<String>(),
                    ),
                  ),
                Row(
                  children: [
                    Icon(
                      Icons.remove_red_eye,
                      size: 13,
                      color: DiziRenkler.metin38,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$goruntulenme',
                      style: TextStyle(
                        fontSize: 11,
                        color: DiziRenkler.metin38,
                      ),
                    ),
                    // Dokunma hedefleri geniş padding ile ~44px
                    InkWell(
                      onTap: _begen,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _begendim
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 15,
                              color: _begendim
                                  ? DiziRenkler.sari
                                  : DiziRenkler.metin38,
                            ),
                            if (_begeni > 0) ...[
                              const SizedBox(width: 3),
                              Text(
                                '$_begeni',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _begendim
                                      ? DiziRenkler.sari
                                      : DiziRenkler.metin38,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: widget.yanitla,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        child: Icon(
                          Icons.reply,
                          size: 15,
                          color: DiziRenkler.metin38,
                        ),
                      ),
                    ),
                    if (widget.benim)
                      InkWell(
                        onTap: widget.sil,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          child: Icon(
                            Icons.delete_outline,
                            size: 15,
                            color: DiziRenkler.metin38,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
