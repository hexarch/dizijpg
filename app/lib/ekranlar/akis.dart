import 'dart:async';
import 'dart:math' as matematik;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../api.dart';
import '../ceviri.dart';
import '../onbellek.dart';
import '../tema.dart';
import 'begenenler.dart';
import 'etiket.dart';
import 'kesfet_akis.dart' show ReelsGorunumu, yanitlariAc;
import 'ortak.dart';
import 'paylas.dart' show gonderiPaylas;
import 'yorumlar.dart' show BolumRozeti;

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
    super.dispose();
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
  Future<void> _reelsAc(int i, int medyaIndeks) async {
    if (_akis == null) return;
    // Push'un Future'ı DÖNDÜRÜLÜR: kart Reels kapanınca beğeni/takip
    // durumunu paylaşılan haritadan tazeler (Reels aynı haritalara yazar).
    await Navigator.of(context, rootNavigator: true).push(
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
                  child: AkisKarti(
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
      // Arama çubuğu akıştan KALDIRILDI (kullanıcı isteği): arama Ana
      // Sayfa'da (AramaCubugu) duruyor, akış yalnız gönderilere ayrıldı.
      body: govde,
    );
  }
}

class AkisKarti extends StatefulWidget {
  final Map<String, dynamic> yorum;
  final Map<String, dynamic> icerikler;

  /// Medyaya dokununca Reels aç — parametre DOKUNULAN medyanın sırası.
  /// Dönen Future Reels KAPANINCA tamamlanır: kart o an paylaşılan haritadan
  /// tazelenir (Reels'te beğenilen gönderi kartta da beğenili görünür).
  final Future<void> Function(int medyaIndeks)? onMedyaAc;

  const AkisKarti({
    super.key,
    required this.yorum,
    required this.icerikler,
    this.onMedyaAc,
  });

  @override
  State<AkisKarti> createState() => _AkisKartiState();
}

class _AkisKartiState extends State<AkisKarti> {
  late bool _begendim = widget.yorum['begendim'] == true;
  // spoiler=true gelen kart dokunulana dek bulanık başlar
  late bool _spoilerAcik = widget.yorum['spoiler'] != true;
  late int _begeni = (widget.yorum['begeni'] as int?) ?? 0;
  late int _yanit = (widget.yorum['yanit'] as int?) ?? 0;

  /// Takip durumu. null = SUNUCU BİLDİRMEDİ (ör. profil ekranındaki liste) →
  /// düğme hiç çizilmez. false → "Takip Et" görünür. true → düğme YOK.
  late bool? _takipEdiyorum = widget.yorum['takip_ediyorum'] as bool?;
  bool _takipIsleniyor = false;
  bool _isleniyor = false;

  /// Medyanın kesinleşen en-boy oranı: yorum metnine kaç satır kaldığını
  /// hesaplarken medyanın kapladığı yüksekliği bilmek gerekir.
  double? _medyaOran;

  @override
  void didUpdateWidget(AkisKarti eski) {
    super.didUpdateWidget(eski);
    // Yenilemeden sonra (ValueKey ile State yeniden kullanılır) beğeni
    // durumunu taze veriyle eşitle — işlem sürerken dokunma.
    // DİKKAT: harita KİMLİĞİ karşılaştırılmaz. Reels/başka bir kart AYNI
    // harita nesnesini güncellemiş olabilir (`eski.yorum == widget.yorum`
    // olduğu hâlde içerik değişmiştir); eskiden bu yüzden Reels'te atılan
    // beğeni akış kartına yansımıyordu.
    if (!_isleniyor) _haritadanTazele(kur: true);
    if (!_takipIsleniyor) {
      _takipEdiyorum = widget.yorum['takip_ediyorum'] as bool?;
    }
  }

  /// Yerel durumu PAYLAŞILAN haritaya yazar. Reels, profil ve detay ekranları
  /// aynı `Map` nesnesini okuduğu için tek doğru kaynak budur.
  void _haritayaYaz() {
    widget.yorum['begendim'] = _begendim;
    widget.yorum['begeni'] = _begeni;
  }

  /// Haritadan yerel duruma okur. [kur] true ise setState çağrılmaz
  /// (didUpdateWidget zaten yeniden çizim içinde).
  void _haritadanTazele({bool kur = false}) {
    final begendim = widget.yorum['begendim'] == true;
    final begeni = (widget.yorum['begeni'] as num?)?.toInt() ?? 0;
    final yanit = (widget.yorum['yanit'] as num?)?.toInt() ?? 0;
    if (begendim == _begendim && begeni == _begeni && yanit == _yanit) return;
    void ata() {
      _begendim = begendim;
      _begeni = begeni;
      _yanit = yanit;
    }

    kur ? ata() : setState(ata);
  }

  /// Ortak yanıt sheet'i (Reels/profil ile AYNI). Kapanınca sayı tazelenir ki
  /// kullanıcı yazdığı yorumun sayıya yansıdığını görsün.
  Future<void> _yanitlariAc() async {
    await yanitlariAc(context, widget.yorum);
    if (!mounted) return;
    try {
      final y = widget.yorum;
      final sorgu = y['sezon'] != null
          ? '?sezon=${y['sezon']}&bolum=${y['bolum']}'
          : '';
      final d = await Api.get('/yorumlar/${y['tur']}/${y['tmdb_id']}$sorgu');
      if (!mounted) return;
      final sayi = (d['yorumlar'] as List<dynamic>)
          .where((c) => c['ust_id'] == y['id'])
          .length;
      widget.yorum['yanit'] = sayi; // paylaşılan harita da tazelensin
      setState(() => _yanit = sayi);
    } catch (_) {
      /* sayı eski kalır; yanıt sheet'inde doğrusu zaten görüldü */
    }
  }

  /// Paylaş: Reels ile BİREBİR aynı sheet (gonderiPaylas) — kişilere DM,
  /// telefonun paylaşım sayfası, bağlantıyı kopyala.
  Future<void> _paylas() => gonderiPaylas(context, widget.yorum);

  Future<void> _takipEt() async {
    if (_takipIsleniyor) return;
    // İyimser: düğme hemen kaybolur. Hata olursa geri gelir + SnackBar.
    setState(() {
      _takipIsleniyor = true;
      _takipEdiyorum = true;
    });
    widget.yorum['takip_ediyorum'] = true;
    try {
      final d = await Api.takipToggle(widget.yorum['kullanici_adi'] as String);
      widget.yorum['takip_ediyorum'] = d['takip'] == true;
      if (!mounted) return;
      setState(() => _takipEdiyorum = d['takip'] == true);
    } catch (e) {
      widget.yorum['takip_ediyorum'] = false;
      if (!mounted) return;
      setState(() => _takipEdiyorum = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _takipIsleniyor = false);
    }
  }

  /// Beğeni: iyimser güncelleme + sunucu doğrulaması. HER adımda sonuç
  /// paylaşılan haritaya yazılır — Reels ve profil aynı haritayı okuduğu için
  /// akışta beğenilen gönderi orada da beğenili açılır.
  Future<void> _begen() async {
    if (_isleniyor) return;
    setState(() {
      _isleniyor = true;
      _begendim = !_begendim;
      _begeni += _begendim ? 1 : -1;
    });
    _haritayaYaz();
    try {
      final d = await Api.yorumBegen(widget.yorum['id'] as int);
      _begendim = d['begendim'] == true;
      _begeni = (d['begeni'] as num?)?.toInt() ?? _begeni;
      _haritayaYaz();
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      // Hata: iyimser güncelleme hem yerelde hem haritada geri alınır.
      _begendim = !_begendim;
      _begeni += _begendim ? 1 : -1;
      _haritayaYaz();
      if (!mounted) return;
      setState(() {});
    } finally {
      if (mounted) _isleniyor = false;
    }
  }

  /// Medyaya dokunuş: Reels açılır, KAPANINCA kart haritadan tazelenir
  /// (Reels'te atılan beğeni/geri alma karta yansır).
  Future<void> _medyaAc(int medyaIndeks) async {
    await widget.onMedyaAc?.call(medyaIndeks);
    if (!mounted || _isleniyor) return;
    _haritadanTazele();
  }

  /// Yorum metnine kalan yükseklik: ekrandan kartın DİĞER parçaları düşülür.
  /// Sabit satır sayısı YOK — aynı gönderi küçük telefonda 1, tablette 5
  /// satır görünebilir; medyası uzun olan kartta metne daha az yer kalır.
  double _metinButcesi(double kartGenislik, bool medyaVar) {
    final ekran = MediaQuery.sizeOf(context).height;
    // Üst çubuk + alt menü + güvenli alan: kartın hiç kullanamayacağı bant.
    final gorunur =
        ekran - _kabukYuksekligi - MediaQuery.paddingOf(context).vertical;
    var kullanilan = _basligYukseklik + _eylemYukseklik + _kartDolgu;
    if (medyaVar && kartGenislik > 0) {
      // Medya kutusu: genişlik / en-boy oranı. Oran ölçülene dek 4:5 varsayılır.
      kullanilan += kartGenislik / (_medyaOran ?? 4 / 5);
    }
    // En az bir satır her zaman görünür (taşarsa "Devam et" çıkar).
    return matematik.max(gorunur - kullanilan, _enAzMetin);
  }

  // Ölçüm sabitleri: kartın metin dışındaki parçalarının yaklaşık yüksekliği.
  static const _kabukYuksekligi = 116.0; // uygulama çubuğu + alt menü
  static const _basligYukseklik = 104.0; // avatar/ad/takip + içerik adı satırı
  static const _eylemYukseklik = 48.0; // beğeni-yorum-görüntülenme-paylaş
  static const _kartDolgu = 34.0; // kart iç/dış boşlukları
  static const _enAzMetin = 30.0; // en az bir satır

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
    // İçerik adı DAİMA içeriğin kendi sayfasına gider; bölüm rozeti ise o
    // bölüme. İkisi ayrı dokunma hedefi (kullanıcı isteği).
    final icerikYolu = y['tur'] == 'person'
        ? '/kisi/${y['tmdb_id']}'
        : '/icerik/${y['tur']}/${y['tmdb_id']}';
    final posterYolu = bolumlu
        ? '/dizi/${y['tmdb_id']}/sezon/${y['sezon']}/bolum/${y['bolum']}'
        : icerikYolu;
    final tarih = (y['tarih'] as String? ?? '').split('T').first;
    final metin = (y['metin'] as String?) ?? '';
    final benim = y['kullanici_id'] == context.read<Oturum>().kullanici?['id'];
    // Takip düğmesi: sunucu durumu bildirdiyse, takip ETMİYORSAN ve gönderi
    // senin değilse çıkar. Takip ediyorsan düğme hiç çizilmez.
    final takipGoster = _takipEdiyorum == false && !benim;

    // Kart ekran kenarlarına dayanır (yatay kenar boşluğu yok) ki medya
    // sağa-sola TAM otursun; köşe yuvarlaması da bu yüzden kapalı.
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: const RoundedRectangleBorder(),
      child: LayoutBuilder(
        builder: (context, kisit) {
          final butce = _metinButcesi(
            kisit.maxWidth,
            _spoilerAcik && medya.isNotEmpty,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- 1. Üst satır: avatar + ad + Takip Et / içerik adı + S4B6
              //      ve EN SAĞDA içeriğin kapak görseli.
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 6, 0),
                child: Row(
                  children: [
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () =>
                          context.push('/kullanici/${y['kullanici_adi']}'),
                      child: KullaniciAvatari(
                        url: avatar,
                        kullaniciAdi: y['kullanici_adi'] as String?,
                        yaricap: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () => context.push(
                                    '/kullanici/${y['kullanici_adi']}',
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      '@${y['kullanici_adi']}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (takipGoster) ...[
                                const SizedBox(width: 8),
                                _TakipDugmesi(
                                  isleniyor: _takipIsleniyor,
                                  onTap: _takipEt,
                                ),
                              ],
                            ],
                          ),
                          // Film yorumu → film adı, dizi yorumu → dizi adı,
                          // bölüm yorumu → dizi adı + S4B6 rozeti.
                          Row(
                            children: [
                              Flexible(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () => context.push(icerikYolu),
                                  child: Container(
                                    // Dokunma hedefi 44px (yazı değil dolgu
                                    // büyür): parmakla ıskalanmaz.
                                    constraints: const BoxConstraints(
                                      minHeight: 44,
                                    ),
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '${icerik['ad']}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: DiziRenkler.sariMetin,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (bolumlu) ...[
                                const SizedBox(width: 6),
                                BolumRozeti(
                                  diziId: y['tmdb_id'] as int,
                                  sezon: y['sezon'] as int,
                                  bolum: y['bolum'] as int,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    UcNoktaMenu(
                      tur: 'yorum',
                      hedefId: y['id'] as int,
                      benimMi: benim,
                      renk: DiziRenkler.metin54,
                    ),
                    if (poster != null)
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => context.push(posterYolu),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 2, right: 6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 42,
                              height: 60,
                              child: CachedNetworkImage(
                                imageUrl: poster,
                                fit: BoxFit.cover,
                                placeholder: (_, _) =>
                                    Container(color: DiziRenkler.kart),
                                errorWidget: (_, _, _) =>
                                    Container(color: DiziRenkler.kart),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // ---- 2. Spoiler perdesi: açılana dek MEDYA DA METİN DE çizilmez
              if (!_spoilerAcik)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
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
              // ---- 3. Medya: sağa-sola TAM dayalı, kaydırmalı. Sayaç medyanın
              //      sağ üstünde ve 3 sn sonra söner (AkisMedya).
              if (_spoilerAcik && medya.isNotEmpty) ...[
                const SizedBox(height: 6),
                MedyaGaleri(
                  yollar: medya.cast<String>(),
                  onAc: _medyaAc,
                  // Çift dokunuş beğenir; tek dokunuş DOKUNULAN kareden
                  // Reels açar (indeks düşerse ilk kareden başlardı).
                  onCiftDokunus: _begen,
                  otomatikOynat: true,
                  onOranBelirlendi: (o) {
                    if (mounted && _medyaOran != o) {
                      setState(() => _medyaOran = o);
                    }
                  },
                ),
              ],
              // ---- 4. Eylem satırı: beğeni, yorum, görüntülenme, paylaş
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    _EylemDugmesi(
                      ikon: _begendim ? Icons.favorite : Icons.favorite_border,
                      etiket: _begeni > 0 ? '$_begeni' : null,
                      renk: _begendim
                          ? DiziRenkler.sariMetin
                          : DiziRenkler.metin54,
                      ipucu: 'Beğen'.c,
                      onTap: _begen,
                      // Basılı tut → beğenenler listesi (her yerde aynı sheet)
                      onUzunBas: () =>
                          begenenleriAc(context, widget.yorum['id'] as int),
                    ),
                    _EylemDugmesi(
                      ikon: Icons.mode_comment_outlined,
                      etiket: _yanit > 0 ? '$_yanit' : 'Yorum yap'.c,
                      renk: DiziRenkler.metin54,
                      ipucu: 'Yorum yap'.c,
                      onTap: _yanitlariAc,
                    ),
                    _EylemDugmesi(
                      ikon: Icons.visibility_outlined,
                      etiket: '${y['goruntulenme'] ?? 0}',
                      renk: DiziRenkler.metin38,
                      ipucu: 'Görüntülenme'.c,
                    ),
                    const Spacer(),
                    Text(
                      tarih,
                      style: TextStyle(
                        fontSize: 11,
                        color: DiziRenkler.metin38,
                      ),
                    ),
                    _EylemDugmesi(
                      ikon: Icons.send_outlined,
                      renk: DiziRenkler.metin54,
                      ipucu: 'Paylaş'.c,
                      onTap: _paylas,
                    ),
                  ],
                ),
              ),
              // ---- 5. En altta: kullanıcı adı + yazılan yorum. Ekrana SIĞAN
              //      kadarı görünür; taşarsa "Devam et".
              if (_spoilerAcik && metin.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: CeviriliMetin(
                    yorumId: y['id'] as int,
                    metin: metin,
                    kaynakDil: y['kaynak_dil'] as String?,
                    ceviriVar: y['ceviri_var'] == true,
                    cevrildi: y['cevrildi'] == true,
                    orijinalMetin: y['orijinal_metin'] as String?,
                    yapici: (m) => SiganYorum(
                      metin: m,
                      kullaniciAdi: y['kullanici_adi'] as String? ?? '',
                      kullanilabilirYukseklik: butce,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Akış kartındaki "Takip Et" düğmesi. Görsel yüksekliği 30px ama dokunma
/// alanı 48px'tir (tapTargetSize.padded) — parmakla ıskalanmaz.
class _TakipDugmesi extends StatelessWidget {
  final bool isleniyor;
  final VoidCallback onTap;
  const _TakipDugmesi({required this.isleniyor, required this.onTap});

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: isleniyor ? null : onTap,
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 30),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
    ),
    child: isleniyor
        // Yükleniyor hâli: düğme kilitli + spinner (sessiz bekleme yok)
        ? const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text('Takip Et'.c),
  );
}

/// Eylem satırı düğmesi: ikon + isteğe bağlı sayı. Dokunma hedefi 44px.
/// [onTap] yoksa (görüntülenme) yalnız gösterge olur.
/// [onUzunBas] verilirse basılı tutmak ayrı bir eylemdir (beğenenler listesi);
/// uzun basma tanınınca [onTap] ATEŞLENMEZ, yani kazara beğeni atılmaz.
class _EylemDugmesi extends StatelessWidget {
  final IconData ikon;
  final String? etiket;
  final Color renk;
  final String ipucu;
  final VoidCallback? onTap;
  final VoidCallback? onUzunBas;
  const _EylemDugmesi({
    required this.ikon,
    this.etiket,
    required this.renk,
    required this.ipucu,
    this.onTap,
    this.onUzunBas,
  });

  @override
  Widget build(BuildContext context) {
    final govde = Container(
      constraints: const BoxConstraints(minHeight: 44),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 19, color: renk),
          if (etiket != null) ...[
            const SizedBox(width: 5),
            Text(
              etiket!,
              style: TextStyle(fontSize: 12.5, color: DiziRenkler.metin70),
            ),
          ],
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label: etiket == null ? ipucu : '$ipucu ${etiket!}',
      child: onTap == null
          ? govde
          : InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              onLongPress: onUzunBas,
              child: govde,
            ),
    );
  }
}

/// Gönderi açıklaması: `@kullanici metin` tek paragraf hâlinde, VERİLEN
/// yüksekliğe SIĞAN satır kadar gösterilir; taşarsa altında "Devam et" çıkar.
///
/// Satır sayısı SABİT DEĞİL: [TextPainter] ile gerçek metin ölçülür, kaç
/// satırın sığdığı [kullanilabilirYukseklik] / satır yüksekliğinden bulunur.
/// Böylece aynı gönderi küçük telefonda 1, tablette 5 satır görünebilir.
class SiganYorum extends StatefulWidget {
  final String metin;
  final String kullaniciAdi;
  final double kullanilabilirYukseklik;
  const SiganYorum({
    super.key,
    required this.metin,
    required this.kullaniciAdi,
    required this.kullanilabilirYukseklik,
  });

  @override
  State<SiganYorum> createState() => _SiganYorumState();
}

class _SiganYorumState extends State<SiganYorum> {
  bool _acik = false;

  @override
  void didUpdateWidget(SiganYorum eski) {
    super.didUpdateWidget(eski);
    // Metin değiştiyse (Çevir/Orijinali göster) kırpma yeniden hesaplanır.
    if (eski.metin != widget.metin) _acik = false;
  }

  @override
  Widget build(BuildContext context) {
    final stil = TextStyle(
      fontSize: 14,
      height: 1.45,
      color: DiziRenkler.metin,
    );
    return LayoutBuilder(
      builder: (context, kisit) {
        // Ölçüm, EKRANDA GÖRÜNEN metinle yapılır: [[tv:1|Ad]] işaretlemesi
        // ham hâliyle ölçülseydi satırlar olduğundan uzun sanılırdı.
        final olcer = TextPainter(
          text: TextSpan(
            style: stil,
            children: [
              TextSpan(
                text: '@${widget.kullaniciAdi}  ',
                style: stil.copyWith(fontWeight: FontWeight.w800),
              ),
              TextSpan(text: duzMetin(widget.metin)),
            ],
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: kisit.maxWidth);
        final satirYuk = olcer.preferredLineHeight;
        final toplamSatir = olcer.computeLineMetrics().length;
        // Bütçeye kaç satır sığıyor?
        final sigan = (widget.kullanilabilirYukseklik / satirYuk).floor();
        final tasiyor = toplamSatir > sigan;
        // Taşıyorsa bir satır "Devam et" düğmesine ayrılır.
        final gosterilecek = tasiyor
            ? (sigan - 1).clamp(1, toplamSatir - 1)
            : toplamSatir;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EtiketliMetin(
              widget.metin,
              stil: stil,
              onekKullanici: widget.kullaniciAdi,
              maxLines: (_acik || !tasiyor) ? null : gosterilecek,
            ),
            if (tasiyor && !_acik)
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => setState(() => _acik = true),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 36),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Devam et'.c,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: DiziRenkler.metin54,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
