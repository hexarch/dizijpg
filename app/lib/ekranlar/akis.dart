import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../api.dart';
import '../ceviri.dart';
import '../onbellek.dart';
import '../tema.dart';
import 'kesfet_akis.dart' show ReelsGorunumu;
import 'ortak.dart';

/// Sosyal akış: kitaplığındaki içeriklere başkalarının yorumları.
/// Spoiler emniyeti sunucuda: izlemediğin bölümün/filmin yorumu gelmez.
class AkisEkrani extends StatefulWidget {
  const AkisEkrani({super.key});

  @override
  State<AkisEkrani> createState() => _AkisEkraniState();
}

class _AkisEkraniState extends State<AkisEkrani>
    with AutomaticKeepAliveClientMixin {
  List<dynamic>? _akis;
  Map<String, dynamic> _icerikler = {};
  String? _hata;
  int _bildirimSayi = 0;
  int _mesajSayi = 0;
  bool _dahaVar = true;
  bool _yukluyor = false;
  final _kaydirma = ScrollController();
  // Satır-içi arama: sonuçlar modal/ayrı sayfa yerine çubuğun altında listelenir
  final _aramaKutu = TextEditingController();
  Timer? _aramaGecikme;
  String _sorgu = '';
  bool _araniyor = false;
  List<dynamic> _aramaIcerik = []; // dizi + film
  List<dynamic> _aramaKisiler = []; // oyuncu/yönetmen (TMDB)
  List<dynamic> _aramaKullanicilar = []; // uygulama kullanıcıları
  String? _duzeltme; // "şunu mu demek istedin" — sunucu yazım düzeltmesi

  // "Görüldü" biriktirme: ekranda beliren kartlar toplanıp toplu bildirilir;
  // bir daha akışta gösterilmezler.
  final Set<int> _goruldu = {};
  Timer? _gorulduZaman;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _onbellektenYukle();
    _yukle();
    _kaydirma.addListener(() {
      if (_kaydirma.position.pixels >
          _kaydirma.position.maxScrollExtent - 400) {
        _devamYukle();
      }
    });
  }

  /// Bir kart ekranda belirdi: id'yi biriktir, kısa gecikmeyle toplu bildir.
  void _kartGorundu(int id) {
    if (!_goruldu.add(id)) return;
    _gorulduZaman?.cancel();
    _gorulduZaman = Timer(const Duration(seconds: 1), _gorulduGonder);
  }

  void _gorulduGonder() {
    if (_goruldu.isEmpty) return;
    final idler = _goruldu.toList();
    _goruldu.clear();
    Api.post('/akis/goruldu', {'idler': idler}).catchError((_) => null);
  }

  @override
  void dispose() {
    _gorulduGonder(); // kalan id'leri gönder
    _gorulduZaman?.cancel();
    _kaydirma.dispose();
    _aramaKutu.dispose();
    _aramaGecikme?.cancel();
    super.dispose();
  }

  void _aramaDegisti(String s) {
    setState(() => _sorgu = s);
    _aramaGecikme?.cancel();
    if (s.trim().length < 2) return;
    _aramaGecikme = Timer(const Duration(milliseconds: 450), () => _ara(s));
  }

  Future<void> _ara(String sorgu) async {
    setState(() => _araniyor = true);
    try {
      final q = Uri.encodeComponent(sorgu.trim());
      final y = await Future.wait([
        Api.get('/ara?q=$q'),
        Api.get('/kullanici-ara?q=$q').catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted || _sorgu.trim() != sorgu.trim()) return;
      final sonuclar = (y[0]['results'] as List<dynamic>? ?? []);
      // Sunucu yazım hatasını düzeltip "duzeltme" döndürdüyse başlıkta göster
      final d = y[0]['duzeltme'] as String?;
      setState(() {
        _duzeltme = (d != null && d.toLowerCase() != sorgu.trim().toLowerCase())
            ? d
            : null;
        _aramaIcerik = sonuclar
            .where(
              (r) => r['media_type'] != 'person' && r['poster_path'] != null,
            )
            .toList();
        _aramaKisiler = sonuclar
            .where(
              (r) => r['media_type'] == 'person' && r['profile_path'] != null,
            )
            .toList();
        _aramaKullanicilar = y[1]['kullanicilar'] as List<dynamic>? ?? [];
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _araniyor = false);
    }
  }

  Future<void> _rozetleriYukle() async {
    try {
      final sonuclar = await Future.wait([
        Api.get('/bildirimler'),
        Api.get('/sohbetler'),
      ]);
      if (!mounted) return;
      setState(() {
        _bildirimSayi = (sonuclar[0]['okunmamis'] as int?) ?? 0;
        _mesajSayi = (sonuclar[1]['okunmamis'] as int?) ?? 0;
      });
    } catch (_) {}
  }

  /// Son başarılı akış anında gösterilir (SWR); taze veri arkadan gelir.
  Future<void> _onbellektenYukle() async {
    final d = await Onbellek.oku('akis');
    if (d == null || !mounted || _akis != null) return;
    setState(() {
      _akis = d['akis'] as List<dynamic>;
      _icerikler = (d['icerikler'] as Map<String, dynamic>? ?? {});
      _dahaVar = (_akis!.length) >= 30;
    });
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    _rozetleriYukle();
    try {
      final d = await Api.get('/akis');
      if (!mounted) return;
      setState(() {
        _akis = d['akis'] as List<dynamic>;
        _icerikler = (d['icerikler'] as Map<String, dynamic>? ?? {});
        _dahaVar = (_akis!.length) >= 30;
      });
      Onbellek.yaz('akis', {'akis': _akis, 'icerikler': _icerikler});
    } catch (e) {
      if (!mounted) return;
      // Önbellekten gösteriliyorsa ağ hatasını yut
      if (_akis == null) setState(() => _hata = e.toString());
    }
  }

  Future<void> _devamYukle() async {
    if (_yukluyor || !_dahaVar || _akis == null || _akis!.isEmpty) return;
    _yukluyor = true;
    try {
      final sonId = (_akis!.last as Map<String, dynamic>)['id'];
      final d = await Api.get('/akis?once=$sonId');
      if (!mounted) return;
      final yeni = d['akis'] as List<dynamic>;
      setState(() {
        _akis!.addAll(yeni);
        _icerikler.addAll(d['icerikler'] as Map<String, dynamic>? ?? {});
        _dahaVar = yeni.length >= 30;
      });
    } catch (_) {
    } finally {
      _yukluyor = false;
    }
  }

  /// Akıştaki medyaya dokununca: o gönderiden başlayıp tüm akışı Reels
  /// (dikey kaydırmalı, çift-dokunuş beğeni, sola kaydırma profil) modunda açar.
  void _reelsAc(int i, int medyaIndeks) {
    if (_akis == null) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => ReelsGorunumu(
          liste: _akis!,
          icerikler: _icerikler,
          baslangic: i,
          // Dokunulan fotoğraftan devam et (eskiden hep ilkinden açılıyordu).
          medyaBaslangic: medyaIndeks,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_akis == null) {
      // İskelet kartlar
      govde = ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < 3; i++)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        IskeletKutu(genislik: 36, yukseklik: 36),
                        SizedBox(width: 10),
                        IskeletKutu(genislik: 130, yukseklik: 14),
                      ],
                    ),
                    SizedBox(height: 12),
                    IskeletKutu(genislik: 280, yukseklik: 12),
                    SizedBox(height: 6),
                    IskeletKutu(genislik: 190, yukseklik: 12),
                  ],
                ),
              ),
            ),
        ],
      );
    } else if (_akis!.isEmpty) {
      govde = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.dynamic_feed, size: 44, color: DiziRenkler.metin24),
              const SizedBox(height: 10),
              Text(
                'Akışın boş.\nİzlediğin dizi ve filmlere yorum yapılınca burada görünecek.'
                    .c,
                textAlign: TextAlign.center,
                style: TextStyle(color: DiziRenkler.metin54, height: 1.6),
              ),
            ],
          ),
        ),
      );
    } else {
      // PC'de kartlar tüm genişliğe yayılmasın: 720px ortalanmış kolon
      govde = RefreshIndicator(
        color: DiziRenkler.sari,
        onRefresh: _yukle,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView.builder(
              controller: _kaydirma,
              // Yatay dolgu YOK: medya sağa-sola tam dayanır (kart kenarları
              // ekrana yaslı; başlık/metin kendi iç dolgusunu alır).
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              // İlerideki kartlar önden kurulur → videoları erkenden yüklenir
              cacheExtent: 4000,
              itemCount: _akis!.length,
              itemBuilder: (context, i) {
                final y = _akis![i] as Map<String, dynamic>;
                // "Görüldü": kart GERÇEKTEN ekranda (>%60) belirince işaretle —
                // build ≈ görüldü DEĞİL (ListView ekran dışı kartları da kurar).
                return VisibilityDetector(
                  key: ValueKey('gor-${y['id']}'),
                  onVisibilityChanged: (info) {
                    if (info.visibleFraction > 0.6) {
                      _kartGorundu(y['id'] as int);
                    }
                  },
                  child: _AkisKarti(
                    key: ValueKey(y['id']),
                    yorum: y,
                    icerikler: _icerikler,
                    onMedyaAc: (mi) => _reelsAc(i, mi),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 34),
            const SizedBox(width: 10),
            Text('Akış'.c),
          ],
        ),
        actions: [
          RozetliIkon(
            ikon: Icons.notifications_none,
            sayi: _bildirimSayi,
            etiket: 'Bildirimler'.c,
            onTap: () async {
              await context.push('/bildirimler');
              _rozetleriYukle();
            },
          ),
          RozetliIkon(
            ikon: Icons.mail_outline,
            sayi: _mesajSayi,
            etiket: 'Mesajlar'.c,
            onTap: () async {
              await context.push('/sohbetler');
              _rozetleriYukle();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Satır-içi arama: dizi/film/kişi + kullanıcılar; sonuçlar
          // modal yerine çubuğun hemen altında listelenir
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: TextField(
                  controller: _aramaKutu,
                  onChanged: _aramaDegisti,
                  decoration: InputDecoration(
                    hintText: 'Dizi, film veya kişi ara...'.c,
                    prefixIcon: Icon(Icons.search, color: DiziRenkler.metin54),
                    suffixIcon: _araniyor
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: DiziRenkler.sari,
                              ),
                            ),
                          )
                        : (_sorgu.isNotEmpty
                              ? IconButton(
                                  tooltip: 'Kapat'.c,
                                  icon: Icon(
                                    Icons.close,
                                    color: DiziRenkler.metin54,
                                  ),
                                  onPressed: () {
                                    _aramaKutu.clear();
                                    setState(() => _sorgu = '');
                                  },
                                )
                              : null),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _sorgu.trim().length >= 2 ? _aramaSonuclari() : govde,
          ),
        ],
      ),
    );
  }

  /// Arama sonuçları: çubuğun altında bölümlü, satır tabanlı liste.
  Widget _aramaSonuclari() {
    final bos =
        _aramaKullanicilar.isEmpty &&
        _aramaIcerik.isEmpty &&
        _aramaKisiler.isEmpty;
    if (bos && !_araniyor) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 44, color: DiziRenkler.metin24),
            const SizedBox(height: 10),
            Text(
              'Sonuç bulunamadı'.c,
              style: TextStyle(color: DiziRenkler.metin54),
            ),
          ],
        ),
      );
    }
    Widget baslik(IconData ikon, String metin) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          Icon(ikon, size: 17, color: DiziRenkler.sariMetin),
          const SizedBox(width: 6),
          Text(
            metin,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (_duzeltme != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 13, color: DiziRenkler.metin54),
                    children: [
                      TextSpan(text: '${'Şunu mu demek istedin'.c}: '),
                      TextSpan(
                        text: _duzeltme,
                        style: TextStyle(
                          color: DiziRenkler.sariMetin,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_aramaKullanicilar.isNotEmpty) ...[
              baslik(Icons.people_outline, 'Kullanıcılar'.c),
              for (final k in _aramaKullanicilar.take(6))
                _AramaSatiri(
                  gorselUrl: dosyaUrl(
                    (k as Map<String, dynamic>)['avatar'] as String?,
                  ),
                  yuvarlak: true,
                  kullaniciAdi: k['kullanici_adi'] as String?,
                  ad: '@${k['kullanici_adi']}',
                  altYazi: (k['bio'] as String?) ?? '',
                  onTap: () =>
                      kullaniciyaGit(context, k['kullanici_adi'] as String),
                ),
            ],
            if (_aramaIcerik.isNotEmpty) ...[
              baslik(Icons.local_movies_outlined, 'Dizi ve Filmler'.c),
              for (final r in _aramaIcerik.take(12))
                _AramaSatiri(
                  gorselUrl: posterUrl(
                    (r as Map<String, dynamic>)['poster_path'] as String?,
                    boyut: 'w185',
                  ),
                  ad: (r['name'] ?? r['title'] ?? '?') as String,
                  altYazi: [
                    ((r['first_air_date'] ?? r['release_date']) as String? ??
                            '')
                        .split('-')
                        .first,
                    r['media_type'] == 'tv' ? 'Dizi'.c : 'Film'.c,
                  ].where((p) => p.isNotEmpty).join(' · '),
                  onTap: () =>
                      context.push('/icerik/${r['media_type']}/${r['id']}'),
                ),
            ],
            if (_aramaKisiler.isNotEmpty) ...[
              baslik(Icons.person_outline, 'Kişiler'.c),
              for (final r in _aramaKisiler.take(8))
                _AramaSatiri(
                  gorselUrl: posterUrl(
                    (r as Map<String, dynamic>)['profile_path'] as String?,
                    boyut: 'w185',
                  ),
                  yuvarlak: true,
                  ad: (r['name'] ?? '?') as String,
                  altYazi: '',
                  onTap: () => context.push('/kisi/${r['id']}'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Arama sonucu satırı: küçük görsel (poster ya da yuvarlak avatar) +
/// ad + alt bilgi. Tüm ekran boylarında aynı düzen.
class _AramaSatiri extends StatelessWidget {
  final String? gorselUrl;
  final bool yuvarlak;
  final String ad;
  final String altYazi;
  final VoidCallback onTap;
  final String? kullaniciAdi; // kullanıcı satırlarında AI rozeti için
  const _AramaSatiri({
    required this.gorselUrl,
    this.yuvarlak = false,
    required this.ad,
    required this.altYazi,
    required this.onTap,
    this.kullaniciAdi,
  });

  @override
  Widget build(BuildContext context) {
    final gorsel = gorselUrl == null
        ? Container(
            color: DiziRenkler.kart,
            child: Icon(
              yuvarlak ? Icons.person : Icons.movie_outlined,
              color: DiziRenkler.metin38,
              size: 20,
            ),
          )
        : CachedNetworkImage(imageUrl: gorselUrl!, fit: BoxFit.cover);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            yuvarlak
                ? KullaniciAvatari(
                    url: gorselUrl,
                    kullaniciAdi: kullaniciAdi,
                    yaricap: 22,
                    arkaplan: DiziRenkler.kart,
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(width: 40, height: 56, child: gorsel),
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ad,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (altYazi.isNotEmpty)
                    Text(
                      altYazi,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: DiziRenkler.metin54,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: DiziRenkler.metin38),
          ],
        ),
      ),
    );
  }
}

class _AkisKarti extends StatefulWidget {
  final Map<String, dynamic> yorum;
  final Map<String, dynamic> icerikler;

  /// Medyaya dokununca Reels aç — parametre DOKUNULAN medyanın sırası.
  final void Function(int medyaIndeks)? onMedyaAc;

  const _AkisKarti({
    super.key,
    required this.yorum,
    required this.icerikler,
    this.onMedyaAc,
  });

  @override
  State<_AkisKarti> createState() => _AkisKartiState();
}

class _AkisKartiState extends State<_AkisKarti> {
  late bool _begendim = widget.yorum['begendim'] == true;
  // spoiler=true gelen kart dokunulana dek bulanık başlar
  late bool _spoilerAcik = widget.yorum['spoiler'] != true;
  late int _begeni = (widget.yorum['begeni'] as int?) ?? 0;
  bool _isleniyor = false;

  @override
  void didUpdateWidget(_AkisKarti eski) {
    super.didUpdateWidget(eski);
    // Yenilemeden sonra (ValueKey ile State yeniden kullanılır) beğeni
    // durumunu sunucudan gelen taze veriyle eşitle — işlem sürerken dokunma.
    if (!_isleniyor && eski.yorum != widget.yorum) {
      _begendim = widget.yorum['begendim'] == true;
      _begeni = (widget.yorum['begeni'] as int?) ?? 0;
    }
  }

  Future<void> _begen() async {
    if (_isleniyor) return;
    setState(() {
      _isleniyor = true;
      _begendim = !_begendim;
      _begeni += _begendim ? 1 : -1;
    });
    try {
      final d = await Api.yorumBegen(widget.yorum['id'] as int);
      if (!mounted) return;
      setState(() {
        _begendim = d['begendim'] == true;
        _begeni = (d['begeni'] as num?)?.toInt() ?? _begeni;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _begendim = !_begendim;
        _begeni += _begendim ? 1 : -1;
      });
    } finally {
      if (mounted) _isleniyor = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final y = widget.yorum;
    final icerik =
        widget.icerikler['${y['tur']}:${y['tmdb_id']}']
            as Map<String, dynamic>? ??
        const {'ad': '?', 'poster': null};
    final poster = posterUrl(icerik['poster'] as String?, boyut: 'w185');
    final avatar = dosyaUrl(y['avatar'] as String?);
    final medya = (y['medya'] as List<dynamic>? ?? []);
    final bolumlu = y['sezon'] != null;
    final hedef = bolumlu
        ? '/dizi/${y['tmdb_id']}/sezon/${y['sezon']}/bolum/${y['bolum']}'
        : (y['tur'] == 'person'
              ? '/kisi/${y['tmdb_id']}'
              : '/icerik/${y['tur']}/${y['tmdb_id']}');
    final tarih = (y['tarih'] as String? ?? '').split('T').first;

    // Kart ekran kenarlarına dayanır (yatay kenar boşluğu yok) ki medya
    // sağa-sola TAM otursun; köşe yuvarlaması da bu yüzden kapalı.
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: const RoundedRectangleBorder(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst satır: kullanıcı + içerik
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: () =>
                        context.push('/kullanici/${y['kullanici_adi']}'),
                    child: KullaniciAvatari(
                      url: avatar,
                      kullaniciAdi: y['kullanici_adi'] as String?,
                      yaricap: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () =>
                              context.push('/kullanici/${y['kullanici_adi']}'),
                          child: Text(
                            '@${y['kullanici_adi']}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        InkWell(
                          onTap: () => context.push(hedef),
                          child: Text(
                            '${icerik['ad']}'
                            '${bolumlu ? ' · ${'S{}B{}'.cf([y['sezon'], y['bolum']])}' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: DiziRenkler.sariMetin,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Şikayet menüsü: posterin solunda, başlık satırının sonunda
                  UcNoktaMenu(
                    tur: 'yorum',
                    hedefId: y['id'] as int,
                    benimMi:
                        y['kullanici_id'] ==
                        context.read<Oturum>().kullanici?['id'],
                    renk: DiziRenkler.metin54,
                  ),
                  if (poster != null)
                    InkWell(
                      onTap: () => context.push(hedef),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 32,
                          height: 46,
                          child: CachedNetworkImage(
                            imageUrl: poster,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // İzlemediğin içeriğin yorumu: dokunana kadar bulanık
            if (!_spoilerAcik)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _spoilerAcik = true),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: DiziRenkler.koyuGri,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.visibility_off_outlined,
                          size: 18,
                          color: DiziRenkler.metin54,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Spoiler olabilir — dokun ve gör'.c,
                            style: TextStyle(color: DiziRenkler.metin54),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_spoilerAcik && (y['metin'] as String? ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: CeviriliMetin(
                  yorumId: y['id'] as int,
                  metin: (y['metin'] as String?) ?? '',
                  kaynakDil: y['kaynak_dil'] as String?,
                  ceviriVar: y['ceviri_var'] == true,
                  yapici: (m) => Text(m, style: const TextStyle(height: 1.45)),
                ),
              ),
            if (_spoilerAcik && medya.isNotEmpty) ...[
              const SizedBox(height: 10),
              // Medya SAĞA-SOLA TAM DAYALI (kart dolgusunun dışında):
              // ilk medya başta gelir, yana kaydırınca sonraki; videolar
              // ekran ortasına gelince yerinde sessiz oynar, dokununca Reels.
              MedyaGaleri(
                yollar: medya.cast<String>(),
                onAc: (mi) => widget.onMedyaAc?.call(mi),
                otomatikOynat: true,
              ),
            ],
            const SizedBox(height: 4),
            // Alt satır: beğeni + görüntülenme + tarih
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _begen,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _begendim ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: _begendim
                                ? DiziRenkler.sariMetin
                                : DiziRenkler.metin54,
                          ),
                          if (_begeni > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '$_begeni',
                              style: TextStyle(
                                fontSize: 12,
                                color: DiziRenkler.metin70,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.visibility_outlined,
                    size: 16,
                    color: DiziRenkler.metin38,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${y['goruntulenme'] ?? 0}',
                    style: TextStyle(fontSize: 12, color: DiziRenkler.metin38),
                  ),
                  const Spacer(),
                  Text(
                    tarih,
                    style: TextStyle(fontSize: 11, color: DiziRenkler.metin38),
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
