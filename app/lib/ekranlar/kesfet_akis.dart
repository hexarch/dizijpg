import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show Uint8List, listEquals;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import '../veri_tasarrufu.dart';
import 'etiket.dart';
import 'ortak.dart';
import 'paylas.dart';

/// Keşfet sayfalama defteri (saf mantık — ekrandan ayrı ki test edilebilsin).
///
/// Sunucu iki tur döndürür: önce görülmemişler, havuz tükenince `tekrar: true`
/// ile baştan (görülenler dahil). Her yanıtta bir sonraki sayfanın `imlec`i
/// gelir; `imlec: null` → gerçekten bitti, bir daha istenmez. Sonsuz istek
/// döngüsü böyle engellenir.
class KesfetSayfalama {
  /// Emniyet tavanı: sunucu zaten bitişi bildiriyor, bu yalnız bellek sigortası.
  static const tavan = 2000;

  String? imlec;
  bool bitti = false;

  /// "Daha önce gördüklerin" turunun başladığı indeks (yoksa null).
  int? tekrarBasi;

  void sifirla() {
    imlec = null;
    bitti = false;
    tekrarBasi = null;
  }

  /// Sıradaki sayfa istenebilir mi? İlk sayfa (imlec null, bitti false) hariç.
  bool get devamVar => !bitti && imlec != null;

  /// Gelen sayfayı defterle: [oncekiUzunluk] sayfa eklenmeden önceki liste
  /// uzunluğu, [gelenAdet] bu sayfada eklenen gönderi sayısı.
  void yanitIsle(
    Map<String, dynamic> d, {
    required int oncekiUzunluk,
    required int gelenAdet,
  }) {
    if (d['tekrar'] == true && tekrarBasi == null && gelenAdet > 0) {
      tekrarBasi = oncekiUzunluk;
    }
    imlec = d['imlec'] as String?;
    bitti =
        imlec == null || gelenAdet == 0 || oncekiUzunluk + gelenAdet >= tavan;
  }
}

/// "Hepsini gördün" ayracı: buradan sonrası daha önce gösterilenlerin tekrarı.
class TekrarAyraci extends StatelessWidget {
  const TekrarAyraci({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
    child: Row(
      children: [
        const Expanded(child: Divider(color: Colors.white24)),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'Hepsini gördün, baştan gösteriyoruz'.c,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const Expanded(child: Divider(color: Colors.white24)),
      ],
    ),
  );
}

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
  /// Gönderiler. Sayfalar SONUNA eklenir, asla araya girmez → indeksler
  /// kaymaz (Reels'in açık listesi ve video görünürlük indeksleri bozulmaz).
  List<dynamic>? _liste;
  Map<String, dynamic> _icerikler = {};
  String? _hata;

  final _kaydirma = ScrollController();
  final _sayfalama = KesfetSayfalama();
  bool _yukluyor = false;

  /// Ekranda görünen VİDEOLU karoların sırası (görünme anına göre).
  final List<int> _gorunurVideolar = [];

  /// Aynı anda oynayan karo sayısı. İkiden fazlası hem veri hem pil yakar.
  static const _esZamanliOynatma = 2;

  @override
  bool get wantKeepAlive => true;

  bool _videoluMu(int i) =>
      (_liste?[i] as Map<String, dynamic>?)?['videolu'] == true;

  /// Karo görünürlüğü değişince oynayacak ikiliyi yeniden belirler.
  void _gorunurlukDegisti(int i, bool gorunur) {
    if (!_videoluMu(i)) return;
    final vardi = _gorunurVideolar.contains(i);
    if (gorunur == vardi) return;
    final oncekiIkili = _gorunurVideolar.take(_esZamanliOynatma).toList();
    if (gorunur) {
      _gorunurVideolar.add(i);
    } else {
      _gorunurVideolar.remove(i);
    }
    // Kaydırırken görünürlük sürekli değişir; YALNIZ oynayan ikili
    // değiştiyse yeniden çiz. Aksi halde her olayda tüm ızgara yeniden
    // kurulur ve kaydırma takılır.
    final yeniIkili = _gorunurVideolar.take(_esZamanliOynatma).toList();
    if (!listEquals(oncekiIkili, yeniIkili)) setState(() {});
  }

  /// İlk gören ilk oynar: listedeki ilk iki görünür video.
  bool _oynasinMi(int i) =>
      _gorunurVideolar.take(_esZamanliOynatma).contains(i);

  @override
  void initState() {
    super.initState();
    _yukle();
    _kaydirma.addListener(() {
      // Dibe 600px kala sıradaki sayfayı çek: kullanıcı beklemesin.
      if (_kaydirma.hasClients &&
          _kaydirma.position.pixels >=
              _kaydirma.position.maxScrollExtent - 600) {
        _sonrakiSayfa();
      }
    });
  }

  @override
  void dispose() {
    _kaydirma.dispose();
    super.dispose();
  }

  /// İlk yükleme + aşağı çekince yenileme: her şey baştan kurulur.
  Future<void> _yukle() async {
    if (_yukluyor) return;
    setState(() {
      _hata = null;
      _yukluyor = true;
    });
    try {
      final d = await Api.get('/kesfet-akis') as Map<String, dynamic>;
      if (!mounted) return;
      final gelen = d['akis'] as List<dynamic>? ?? [];
      setState(() {
        // YENİ liste/harita nesnesi: açık duran Reels eski listesiyle
        // tutarlı kalsın (aynı nesneyi temizlemek onu bozardı).
        _liste = List<dynamic>.from(gelen);
        _icerikler = Map<String, dynamic>.from(
          d['icerikler'] as Map<String, dynamic>? ?? {},
        );
        _sayfalama.sifirla();
        _sayfalama.yanitIsle(d, oncekiUzunluk: 0, gelenAdet: gelen.length);
        _gorunurVideolar.clear();
        _yukluyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yukluyor = false;
        _hata = e.toString();
      });
    }
  }

  /// Sonraki sayfa. Sunucu `imlec: null` derse havuz gerçekten bitmiştir —
  /// bir daha istenmez (sonsuz istek döngüsü olmaz).
  Future<void> _sonrakiSayfa() async {
    if (_yukluyor || _liste == null || !_sayfalama.devamVar) return;
    setState(() => _yukluyor = true);
    try {
      final d =
          await Api.get(
                '/kesfet-akis?imlec=${Uri.encodeQueryComponent(_sayfalama.imlec!)}',
              )
              as Map<String, dynamic>;
      if (!mounted) return;
      final gelen = d['akis'] as List<dynamic>? ?? [];
      setState(() {
        _sayfalama.yanitIsle(
          d,
          oncekiUzunluk: _liste!.length,
          gelenAdet: gelen.length,
        );
        // Listeye YALNIZ EKLEME: açık Reels'in indeksleri ve ızgaranın video
        // görünürlük indeksleri kaymasın.
        _liste!.addAll(gelen);
        _icerikler.addAll(d['icerikler'] as Map<String, dynamic>? ?? {});
        _yukluyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Sonraki sayfa patlarsa sessizce dur: eldeki içerik kaybolmasın.
      setState(() {
        _yukluyor = false;
        _sayfalama.bitti = true;
      });
    }
  }

  void _ac(int i) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => ReelsGorunumu(
          liste: _liste!,
          icerikler: _icerikler,
          baslangic: i,
          // Reels sona yaklaşınca ızgarayla AYNI listeye sayfa ekler; ızgara
          // listeye yalnız EKLEME yaptığı için açık sayfanın indeksi kaymaz.
          dahaGetir: _sonrakiSayfa,
        ),
      ),
    );
  }

  Widget _izgara(int bas, int son, int sutun) => SliverGrid.builder(
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: sutun,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      childAspectRatio: 0.66,
    ),
    itemCount: son - bas,
    itemBuilder: (context, j) {
      final i = bas + j;
      return _KesfetKutusu(
        // Tekrar turunda AYNI gönderi listede iki kez bulunabilir; anahtar
        // yalnız id olursa görünürlük takibi karışır → indeks de girer.
        sira: i,
        yorum: _liste![i] as Map<String, dynamic>,
        icerikler: _icerikler,
        onTap: () => _ac(i),
        oynat: _oynasinMi(i),
        onGorunurluk: (gorunur) => _gorunurlukDegisti(i, gorunur),
      );
    },
  );

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
      final sutun = genis ? 5 : 3;
      final tekrarBasi = _sayfalama.tekrarBasi;
      // Görülmemişler → ayraç → tekrar gösterilenler. Tek ızgara yerine iki
      // sliver: ayraç tam genişlikte durur, indeksler global kalır.
      govde = RefreshIndicator(
        color: DiziRenkler.sari,
        onRefresh: _yukle,
        child: CustomScrollView(
          controller: _kaydirma,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(2),
              sliver: _izgara(0, tekrarBasi ?? _liste!.length, sutun),
            ),
            if (tekrarBasi != null) ...[
              const SliverToBoxAdapter(child: TekrarAyraci()),
              SliverPadding(
                padding: const EdgeInsets.all(2),
                sliver: _izgara(tekrarBasi, _liste!.length, sutun),
              ),
            ],
            // Sonraki sayfa yüklenirken alt tarafta dönen gösterge
            if (_yukluyor)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: DiziRenkler.sari,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('Keşfet'.c)),
      body: govde,
    );
  }
}

/// Izgara karosu.
///
/// Video gönderilerinde İÇERİK POSTERİ değil, videonun kendi karesi gösterilir
/// (sunucu yüklemede `<yol>.jpg` üretir). Böylece ızgara resim gösterir;
/// onlarca video çözücü açılmaz. [oynat] verilen karo — ekranda aynı anda en
/// fazla iki tanesi — sessiz ve döngüsel olarak gerçekten oynar.
class _KesfetKutusu extends StatefulWidget {
  final Map<String, dynamic> yorum;
  final Map<String, dynamic> icerikler;
  final VoidCallback onTap;
  final bool oynat;

  /// Listedeki global indeks — görünürlük anahtarını benzersiz kılar (tekrar
  /// turunda aynı gönderi listede iki kez yer alabilir).
  final int sira;

  /// Karo ekranda görünür hale gelince/çıkınca haber verir (ebeveyn hangi
  /// videoların oynayacağını buna göre seçer).
  final void Function(bool gorunur) onGorunurluk;

  const _KesfetKutusu({
    required this.sira,
    required this.yorum,
    required this.icerikler,
    required this.onTap,
    required this.oynat,
    required this.onGorunurluk,
  });

  @override
  State<_KesfetKutusu> createState() => _KesfetKutusuState();
}

class _KesfetKutusuState extends State<_KesfetKutusu> {
  VideoPlayerController? _d;

  static bool _videoMu(String u) => u.endsWith('.mp4') || u.endsWith('.webm');

  List<String> get _medya =>
      (widget.yorum['medya'] as List<dynamic>? ?? []).cast<String>();

  String? get _ilkVideo {
    for (final m in _medya) {
      if (_videoMu(m)) return m;
    }
    return null;
  }

  @override
  void didUpdateWidget(_KesfetKutusu eski) {
    super.didUpdateWidget(eski);
    if (widget.oynat != eski.oynat) {
      widget.oynat ? _oynatmayiKur() : _oynatmayiBirak();
    }
  }

  Future<void> _oynatmayiKur() async {
    final v = _ilkVideo;
    if (v == null || _d != null) return;
    final d = VideoPlayerController.networkUrl(Uri.parse(dosyaUrl(v)!));
    _d = d;
    try {
      await d.initialize();
      if (!mounted || !widget.oynat) return _oynatmayiBirak();
      await d.setVolume(0); // ızgarada ses ASLA çalmaz
      await d.setLooping(true);
      await d.play();
      if (mounted) setState(() {});
    } catch (_) {
      _oynatmayiBirak(); // ağ/kodek hatası: sessizce kapağa düşer
    }
  }

  void _oynatmayiBirak() {
    final d = _d;
    _d = null;
    d?.dispose();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _d?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final medya = _medya;
    final videolu = widget.yorum['videolu'] == true;
    final spoiler = widget.yorum['spoiler'] == true;
    final icerik =
        widget.icerikler['${widget.yorum['tur']}:${widget.yorum['tmdb_id']}']
            as Map<String, dynamic>? ??
        const {'ad': '?', 'poster': null};
    final goruntulenme = (widget.yorum['goruntulenme'] as num?)?.toInt() ?? 0;

    // Arka plan sırası: fotoğraf → video karesi → içerik posteri.
    final ilkFoto = medya.where((m) => !_videoMu(m)).toList();
    final video = _ilkVideo;
    final poster = posterUrl(icerik['poster'] as String?, boyut: 'w342');
    final arka = ilkFoto.isNotEmpty
        ? dosyaUrl(ilkFoto.first)
        : (video != null ? dosyaUrl('$video.jpg') : poster);

    final d = _d;
    return VisibilityDetector(
      key: Key('kesfet-${widget.sira}-${widget.yorum['id']}'),
      onVisibilityChanged: (bilgi) =>
          widget.onGorunurluk(bilgi.visibleFraction > 0.6),
      child: InkWell(
        onTap: widget.onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (d != null && d.value.isInitialized)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: d.value.size.width,
                  height: d.value.size.height,
                  child: VideoPlayer(d),
                ),
              )
            else if (arka != null)
              CachedNetworkImage(
                imageUrl: arka,
                fit: BoxFit.cover,
                // Video karesi henüz üretilmemişse içerik posterine düş
                errorWidget: (context, url, hata) => poster != null
                    ? CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover)
                    : Container(color: DiziRenkler.kart),
              )
            else
              Container(color: DiziRenkler.kart),
            // Yazılı yorum: alt yarıda metin bandı
            if (medya.isEmpty)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 22),
                  color: Colors.black54,
                  child: Text(
                    spoiler ? '•••' : (widget.yorum['metin'] as String? ?? ''),
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
            // Sol alt: göz + izlenme sayısı (okunurluk için gölgeli)
            Positioned(
              left: 6,
              bottom: 5,
              child: IgnorePointer(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.remove_red_eye_outlined,
                      size: 13,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$goruntulenme',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
                      ),
                    ),
                  ],
                ),
              ),
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

  /// Sona yaklaşınca çağrılır: ızgarayla AYNI listeye sayfa ekler. Liste
  /// yalnız büyüdüğü için açık sayfanın indeksi kaymaz. Null → sayfalama yok
  /// (tek gönderi ekranı).
  final Future<void> Function()? dahaGetir;

  const ReelsGorunumu({
    super.key,
    required this.liste,
    required this.icerikler,
    required this.baslangic,
    this.medyaBaslangic = 0,
    this.dahaGetir,
  });

  @override
  State<ReelsGorunumu> createState() => _ReelsGorunumuState();
}

class _ReelsGorunumuState extends State<ReelsGorunumu> {
  late final PageController _sayfa = PageController(
    initialPage: widget.baslangic,
  );
  late int _aktif = widget.baslangic; // yalnız aktif sayfa oynar/işaretlenir
  bool _getiriyor = false;

  @override
  void dispose() {
    _sayfa.dispose();
    super.dispose();
  }

  /// Son 3 sayfaya girince sıradaki sayfayı ızgaraya çektir; gelen gönderiler
  /// aynı liste nesnesine eklendiği için burada tek setState yeter.
  Future<void> _dahaGetir() async {
    final f = widget.dahaGetir;
    if (f == null || _getiriyor) return;
    _getiriyor = true;
    try {
      await f();
    } finally {
      _getiriyor = false;
      if (mounted) setState(() {});
    }
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
            onPageChanged: (i) {
              setState(() => _aktif = i);
              if (i >= widget.liste.length - 3) _dahaGetir();
            },
            itemBuilder: (context, i) => _ReelSayfa(
              // Tekrar turunda aynı id iki kez bulunabilir → indeks de girer.
              key: ValueKey('$i-${(widget.liste[i] as Map)['id']}'),
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
  // Takip durumu HER kaynakta gelmez (profilden açılan Reels'te yok). Bilinmiyorsa
  // düğme hiç çizilmez: kendi gönderinde "Takip Et" göstermek ya da zaten takip
  // ettiğin kişiye yeniden sormak yanlış olur; profil sayfasının kendi düğmesi var.
  late final bool _takipBilinir = widget.yorum.containsKey('takip_ediyorum');
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

  // Reels de akış kartıyla AYNI sheet'i açar (tek açılış ayarı: yanitlariAc)
  void _yanitlarAc() => yanitlariAc(context, widget.yorum);

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
                        if (_takipBilinir && !_takipte)
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
              const SizedBox(height: 8),
              // Şikayet menüsü (kendi gönderinde ve misafirde gizli)
              UcNoktaMenu(
                tur: 'yorum',
                hedefId: y['id'] as int,
                benimMi:
                    y['kullanici_id'] ==
                    context.read<Oturum>().kullanici?['id'],
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

/// Gönderinin yanıt sheet'ini açar (Reels, profil yorum akışı vb.).
/// TAM AÇILIR: sheet ekranın tamamını (durum çubuğu hariç) kaplar; eskiden
/// ekranın %60'ında takılıydı ve klavye açılınca yazma kutusu ortada kalıyordu.
Future<void> yanitlariAc(BuildContext context, Map<String, dynamic> yorum) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DiziRenkler.koyuGri,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => YanitlarSheet(yorum: yorum),
    );

/// Yorum kutusunun üstündeki 8'li hızlı emoji satırının kaynağı.
///
/// Sunucu `/emojiler/sik` ucundan KENDİ yorumlarındaki emojileri (`benim`) ve
/// uygulama genelindekileri (`genel`) döndürür — ayrı bir takip tablosu yok,
/// mevcut yorum metinleri sayılır. Kendi listen kısa kalırsa genel liste,
/// ikisi de boşsa [yedek] tamamlar; satır asla boş görünmez.
/// Sonuç oturum boyunca istemcide tutulur (her sheet açılışında istek atılmaz).
class SikEmojiler {
  static const int adet = 8;

  /// Yeni kurulumda (hiç yorum yokken) gösterilen sabit liste.
  static const List<String> yedek = [
    '😂',
    '❤️',
    '🔥',
    '👏',
    '😍',
    '😮',
    '😢',
    '👍',
  ];

  /// Oturum önbelleği. Testler doğrudan yazabilir (ağ isteği atılmaz).
  static List<String>? onbellek;

  /// Sıralı birleştirme: önce kişinin kendi emojileri, sonra uygulama geneli,
  /// eksik kalırsa yedek. Tekrar eden emoji bir kez yazılır.
  static List<String> birlestir(List<String> benim, List<String> genel) {
    final liste = <String>[];
    for (final e in [...benim, ...genel, ...yedek]) {
      if (e.trim().isEmpty || liste.contains(e)) continue;
      liste.add(e);
      if (liste.length == adet) break;
    }
    return liste;
  }

  static Future<List<String>> getir() async {
    if (onbellek != null) return onbellek!;
    try {
      final d = await Api.get('/emojiler/sik') as Map<String, dynamic>;
      final liste = birlestir(
        (d['benim'] as List<dynamic>? ?? []).cast<String>(),
        (d['genel'] as List<dynamic>? ?? []).cast<String>(),
      );
      onbellek = liste;
      return liste;
    } catch (_) {
      // Önbelleğe YAZMA: bir sonraki açılışta tekrar denensin.
      return yedek;
    }
  }
}

/// Metnin [secim] konumuna emoji ekler, imleci emojinin sonuna taşır.
/// Seçim yoksa (imleç kaybolmuşsa) metnin sonuna eklenir.
TextEditingValue emojiEkle(TextEditingValue deger, String emoji) {
  final metin = deger.text;
  final secim = deger.selection;
  final bas = secim.isValid ? secim.start.clamp(0, metin.length) : metin.length;
  final son = secim.isValid ? secim.end.clamp(0, metin.length) : metin.length;
  return TextEditingValue(
    text: metin.replaceRange(bas, son, emoji),
    selection: TextSelection.collapsed(offset: bas + emoji.length),
  );
}

/// Bir gönderinin yanıtları + yazma kutusu. Reels ve profil yorum akışı
/// AYNI sheet'i kullanır: beğeni ve yanıtlar tek veri kaynağından geldiği için
/// nerede atılırsa atılsın her iki tarafta da görünür.
class YanitlarSheet extends StatefulWidget {
  final Map<String, dynamic> yorum;
  const YanitlarSheet({super.key, required this.yorum});

  @override
  State<YanitlarSheet> createState() => _YanitlarSheetState();
}

class _YanitlarSheetState extends State<YanitlarSheet> {
  List<dynamic>? _yanitlar;
  final _kutu = TextEditingController();
  final _liste = ScrollController();
  // Sheet ekranı kapladığı için kök ScaffoldMessenger'ın SnackBar'ı ARKADA
  // kalır; sheet kendi messenger'ını taşır, hatalar burada görünür.
  final _mesajci = GlobalKey<ScaffoldMessengerState>();
  bool _gonderiliyor = false;
  final List<Map<String, dynamic>> _ekler = []; // {yol, video}
  bool _ekYukleniyor = false;
  // Medya yüklenirken gönder'e basıldı: yükleme bitince metin+medya BİRLİKTE
  // gider (sohbet ekranında medyasız gönderim hatası buradan çıkmıştı).
  bool _gonderBekliyor = false;
  bool _yaziVar = false; // gönder düğmesi bu bayrakla belirir
  Map<String, dynamic>? _yanitlanan; // yanıtın yanıtı: hedeflenen satır
  List<String> _emojiler = SikEmojiler.onbellek ?? SikEmojiler.yedek;

  @override
  void initState() {
    super.initState();
    _kutu.addListener(_metinDegisti);
    _yukle();
    _emojileriYukle();
  }

  @override
  void dispose() {
    _kutu.removeListener(_metinDegisti);
    _kutu.dispose();
    _liste.dispose();
    super.dispose();
  }

  void _metinDegisti() {
    final dolu = _kutu.text.trim().isNotEmpty;
    if (dolu != _yaziVar) setState(() => _yaziVar = dolu);
  }

  Future<void> _emojileriYukle() async {
    final liste = await SikEmojiler.getir();
    if (mounted && !listEquals(liste, _emojiler)) {
      setState(() => _emojiler = liste);
    }
  }

  void _uyar(String mesaj) =>
      _mesajci.currentState?.showSnackBar(SnackBar(content: Text(mesaj)));

  void _emojiSec(String emoji) {
    _kutu.value = emojiEkle(_kutu.value, emoji);
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
      if (mounted) _uyar(e.toString());
    }
  }

  /// Fotoğraf / video eki (galeri).
  Future<void> _ekSec() async {
    if (_ekler.length >= 4) return;
    final secim = await ImagePicker().pickMedia();
    if (secim == null) return;
    await _ekYukle(() => secim.readAsBytes());
  }

  /// GIF eki. Dış GIF servisi (Giphy/Tenor) YOK — anahtar/gizli bilgi
  /// gerektirir; kullanıcının kendi galerisinden .gif seçilir. Sunucu GIF'i
  /// sihirli baytla doğrular ve kırpmadan geçirir (animasyon bozulmaz).
  Future<void> _gifSec() async {
    if (_ekler.length >= 4) return;
    final secim = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gif'],
      withData: true,
    );
    final veri = secim?.files.single.bytes;
    if (veri == null) return;
    await _ekYukle(() async => veri);
  }

  Future<void> _ekYukle(Future<Uint8List> Function() oku) async {
    setState(() => _ekYukleniyor = true);
    try {
      final veri = await oku();
      if (veri.length > 30 * 1024 * 1024) {
        throw ApiHata('Dosya en fazla {}MB olabilir'.cf([30]));
      }
      final d = await Api.medyaYukle(veri);
      if (!mounted) return;
      setState(() => _ekler.add({'yol': d['yol'], 'video': d['video']}));
    } catch (e) {
      if (!mounted) return;
      _gonderBekliyor = false; // yükleme başarısız: bekleyen gönderim iptal
      _uyar(e.toString());
    } finally {
      if (mounted) setState(() => _ekYukleniyor = false);
      // Yükleme sürerken gönder'e basılmışsa şimdi gönder: metin de medya da
      // kaybolmaz.
      if (mounted && _gonderBekliyor) {
        _gonderBekliyor = false;
        await _gonder();
      }
    }
  }

  Future<void> _gonder() async {
    final metin = _kutu.text.trim();
    if (metin.isEmpty || _gonderiliyor) return;
    if (_ekYukleniyor) {
      // Yükleme bitmeden gönderilirse medya eksik giderdi; sıraya al.
      setState(() => _gonderBekliyor = true);
      return;
    }
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
      // Başarı görünür olsun: yeni yanıt listenin sonunda, oraya kaydır.
      if (mounted && _liste.hasClients) {
        await _liste.animateTo(
          _liste.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) _uyar(e.toString());
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  /// Yazma kutusunun içindeki kompakt eylem ikonu (dosya / GIF / gönder).
  /// Dokunma hedefi 44x44: ikon 22 px kalır, PADDING büyütülür.
  Widget _kutuIkonu({
    required String ipucu,
    required IconData ikon,
    required VoidCallback onTap,
    bool kapali = false,
    bool yukleniyor = false,
  }) {
    return Tooltip(
      message: ipucu,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: kapali ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: yukleniyor
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: DiziRenkler.sari,
                  ),
                )
              : Icon(
                  ikon,
                  size: 22,
                  color: kapali ? DiziRenkler.metin24 : DiziRenkler.sari,
                ),
        ),
      ),
    );
  }

  /// Sık kullanılan 8 emoji, yazma satırının ÜSTÜNDE yan yana. Dar ekranda
  /// (360 dp) sığmazsa yatay kaydırılır — taşma çizgisi çıkmaz, hepsi
  /// erişilebilir kalır.
  Widget _emojiSatiri() {
    const olcu = 44.0; // dokunma hedefi
    final dugmeler = [
      for (final e in _emojiler)
        InkWell(
          key: ValueKey('emoji-$e'),
          borderRadius: BorderRadius.circular(22),
          onTap: () => _emojiSec(e),
          child: SizedBox(
            width: olcu,
            height: olcu,
            child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
          ),
        ),
    ];
    return SizedBox(
      height: olcu,
      child: LayoutBuilder(
        builder: (_, kisit) => olcu * dugmeler.length <= kisit.maxWidth
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: dugmeler,
              )
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: dugmeler),
              ),
      ),
    );
  }

  /// Yazma satırı: SOLDA profil fotoğrafı, ortada metin alanı, SAĞDA
  /// (dosya + GIF) ya da yazı yazılmışsa (gönder).
  Widget _girisSatiri(Map<String, dynamic>? ben) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: KullaniciAvatari(
            url: dosyaUrl(ben?['avatar'] as String?),
            kullaniciAdi: ben?['kullanici_adi'] as String?,
            yaricap: 16,
            arkaplan: DiziRenkler.kart,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: EtiketliGirdi(
            controller: _kutu,
            maxLength: 1000,
            maxLines: 4,
            minLines: 1,
            decoration: InputDecoration(
              hintText: 'Yorumunu yaz... (@ ile etiketle)'.c,
              isDense: true,
              contentPadding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _yaziVar
                      // Yazı yazılınca yalnız GÖNDER kalır
                      ? [
                          _kutuIkonu(
                            ipucu: 'Gönder'.c,
                            ikon: Icons.send,
                            kapali: _gonderiliyor || _gonderBekliyor,
                            yukleniyor: _gonderiliyor || _gonderBekliyor,
                            onTap: _gonder,
                          ),
                        ]
                      // Boşken dosya ve GIF ekleme
                      : [
                          _kutuIkonu(
                            ipucu: 'Fotoğraf / video ekle'.c,
                            ikon: Icons.attach_file,
                            kapali: _ekYukleniyor || _ekler.length >= 4,
                            yukleniyor: _ekYukleniyor,
                            onTap: _ekSec,
                          ),
                          _kutuIkonu(
                            ipucu: 'GIF ekle'.c,
                            ikon: Icons.gif_box_outlined,
                            kapali: _ekYukleniyor || _ekler.length >= 4,
                            onTap: _gifSec,
                          ),
                        ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final olcum = MediaQuery.of(context);
    final klavye = olcum.viewInsets.bottom;
    // TAM AÇILIŞ: kullanılabilir yüksekliğin tamamı (eskiden ekranın %60'ı).
    // Klavye açılınca sheet kısalır, yazma kutusu klavyenin ÜSTÜNDE kalır.
    final yukseklik = (olcum.size.height - olcum.padding.top - klavye).clamp(
      200.0,
      olcum.size.height,
    );
    final ben = context.watch<Oturum>().kullanici;
    return Padding(
      padding: EdgeInsets.only(bottom: klavye),
      child: SizedBox(
        height: yukseklik,
        // Sheet ekranı kapladığı için kök SnackBar arkada kalırdı; sheet kendi
        // messenger'ını taşıyor (hata mesajları görünür).
        child: ScaffoldMessenger(
          key: _mesajci,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            resizeToAvoidBottomInset: false, // klavye payı zaten yukarıda
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 2),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: DiziRenkler.metin24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
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
                      const SizedBox(width: 8),
                      Text(
                        '${_yanitlar?.length ?? ''}',
                        style: TextStyle(color: DiziRenkler.metin54),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Kapat'.c,
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(Icons.close, color: DiziRenkler.metin54),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _yanitlar == null
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: DiziRenkler.sari,
                          ),
                        )
                      : (_yanitlar!.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.forum_outlined,
                                      size: 34,
                                      color: DiziRenkler.metin24,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Henüz yorum yok.'.c,
                                      style: TextStyle(
                                        color: DiziRenkler.metin54,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'İlk yorumu sen yaz'.c,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: DiziRenkler.metin38,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: _liste,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                itemCount: _yanitlar!.length,
                                itemBuilder: (context, i) {
                                  final c =
                                      _yanitlar![i] as Map<String, dynamic>;
                                  return _KesfetYanitSatiri(
                                    key: ValueKey(c['id']),
                                    yanit: c,
                                    benim: c['kullanici_id'] == ben?['id'],
                                    sil: () => _sil(c['id'] as int),
                                    yanitla: () =>
                                        setState(() => _yanitlanan = c),
                                  );
                                },
                              )),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: DiziRenkler.metin12)),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                  child: SafeArea(
                    top: false,
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
                                borderRadius: BorderRadius.circular(22),
                                onTap: () => setState(() => _yanitlanan = null),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
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
                                          onTap: () => setState(
                                            () => _ekler.removeAt(i),
                                          ),
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
                        _emojiSatiri(),
                        const SizedBox(height: 2),
                        _girisSatiri(ben),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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
