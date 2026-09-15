import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../sayfa_basligi.dart';
import '../ceviri.dart';
import '../gorsel_basliklari.dart';
import '../kitaplik_durumu.dart';
import '../tarih.dart';
import '../tema.dart';
import '../tmdb_fragman.dart';
import 'detay.dart' show SariRozet, ekibiCikar, EkipUyesi;
import 'giris_istem.dart';
import 'kahraman_karisik.dart';
import 'medya_goster.dart';
import 'ortak.dart';
import 'tepki.dart';
import 'yorumlar.dart';

/// Bölüm sayfası: görsel, özet, konuk oyuncular, izleme işareti ve
/// bölüme özel yorumlar.
///
/// TASARIM DİZİ SAYFASIYLA HİZALANDI (15 Eyl 2026, kullanıcı: *"dizilerde
/// bölüm sayfaları tasarımsal olarak geri kalmış, bölüm sayfalarını da güncel
/// tasarıma çek"*). Dizi sayfasının (detay.dart) dili birebir:
///  * Sabit `SliverAppBar` + 16:9 kahraman (fragman/kareler) — eskiden düz
///    `ListView` + `AppBar` idi.
///  * Başlık bloğunda SOLDA DİZİNİN AFİŞİ (dizi sayfasındaki `_AfisKucuk`
///    gibi; "hangi dizinin bölümündeyim" sorusu artık cevapsız değil), üstte
///    diziye götüren satır, altında sarı `S1 · B3` rozeti + tarih + süre +
///    ★ TMDB — hepsi `Wrap` (dar ekranda alt satıra iner, taşmaz).
///  * Aksiyon satırı tam genişlik `FilledButton` (İzledim), altında puan
///    şeridi ve tepkiler; özet en altta — dizi sayfasındaki sırayla.
///  * Önceki / Sonraki bölüm düğmeleri ve "Sezonun bölümleri" şeridi: sezon
///    yanıtı zaten TMDB'de bir istek; bölümler arasında dizi sayfasına
///    dönmeden gezilir. Geçiş `pushReplacement`: geri tuşu bölüm bölüm
///    geri sarmaz, doğrudan dizi sayfasına döner.
///  * Bölümün EKİBİ (yönetmen / senaryo) — TMDB bölüm yanıtındaki `crew`
///    dizi sayfasındaki `ekibiCikar` ile aynı süzgeçten geçer; konuk
///    oyuncularla aynı kişi kartı (`_KisiKarti`, rol alt satırda).
class BolumEkrani extends StatefulWidget {
  final int tmdbId;
  final int sezonNo;
  final int bolumNo;
  final bool izlendi;

  const BolumEkrani({
    super.key,
    required this.tmdbId,
    required this.sezonNo,
    required this.bolumNo,
    required this.izlendi,
  });

  @override
  State<BolumEkrani> createState() => _BolumEkraniState();
}

class _BolumEkraniState extends State<BolumEkrani> {
  Map<String, dynamic>? _bolum;

  /// Dizi (ad + afiş) — başlık bloğundaki dizi satırı için. Yanıt dizi
  /// gibi durmuyorsa (sahte sunucu bölümü döndürebilir) satır çizilmez.
  Map<String, dynamic>? _dizi;

  /// Sezonun bölüm listesi (`episodes`) — önceki/sonraki ve bölüm şeridi.
  List<Map<String, dynamic>> _sezonBolumleri = const [];

  /// Bölüme ait kare (still) yolları; ilki bölümün kapak karesidir.
  List<String> _kareler = const [];

  /// Bölüm + sezon Trailer/Teaser'ları (Clip spoiler, kahramana konmaz).
  List<TmdbFragman> _fragmanlar = const [];
  String? _hata;
  late bool _izlendi = widget.izlendi;

  /// Bu bölümü NE ZAMAN izledim (ISO). `/benim` ucundan gelir; izlenmemişse
  /// null. Kullanıcı isteği (27 Ağu 2026): "dizi bölümlerine de bölüm
  /// izlenme tarihini eklemeyi unutma".
  String? _izlenmeTarihi;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    final dizi = '/tmdb/tv/${widget.tmdbId}';
    final sezon = '$dizi/season/${widget.sezonNo}';
    final taban = '$sezon/episode/${widget.bolumNo}';
    final videoDil = tmdbVideoDilParametre();
    try {
      // Kareler bölümle BİRLİKTE istenir: sonradan gelseydi kutu boyu/nokta
      // göstergesi yüklendikten sonra belirir, içerik zıplardı.
      // Sezon videosu paralel: bölümde Trailer yoksa sezon fragmanı kahraman
      // olur (BB S1E1'de yalnız Clip var, S1 Trailer var).
      final sonuc = await Future.wait([
        Api.get('$taban?append_to_response=videos&$videoDil'),
        // Kareler süs veridir; gelmezse sayfa eskisi gibi tek kapakla çalışır.
        Api.get('$taban/images').catchError((_) => null),
        Api.get('$sezon/videos?$videoDil').catchError((_) => null),
        // İzlenme tarihi: `/benim` dizinin TÜM izlenen bölümlerini döner,
        // içinden bu bölümünki alınır. Ayrı bir "tek bölümün tarihi" ucu
        // AÇILMADI — mevcut uç zaten bu sayfanın ihtiyacını karşılıyor ve
        // sözleşmeyi genişletmek yeni bir bakım yüzeyi olurdu.
        //
        // OTURUMSUZ ZİYARETÇİDE 401 GELİR ve `catchError` ile yutulur: tarih
        // satırı çizilmez, sayfanın geri kalanı aynen çalışır.
        if (Api.girisli)
          Api.get('/benim/tv/${widget.tmdbId}').catchError((_) => null)
        else
          Future<dynamic>.value(),
        // Dizi adı/afişi ve sezonun bölüm listesi: ikisi de SÜS + gezinme
        // verisidir, gelmezse sayfa onlarsız çalışır (dizi satırı ve
        // önceki/sonraki düğmeleri çizilmez).
        Api.get(dizi).catchError((_) => null),
        Api.get(sezon).catchError((_) => null),
      ]);
      if (!mounted) return;
      final b = sonuc[0] as Map<String, dynamic>;
      // `izlenenler` satırlarından BU bölümün tarihi. Satır varsa bölüm
      // izlenmiştir: `widget.izlendi` yalnız dizi sayfasından gelen ilk
      // bilgidir, önceki/sonraki geçişinde (`pushReplacement`) boş gelir.
      String? izlenme;
      var izlendi = _izlendi;
      final benim = sonuc[3];
      if (benim is Map) {
        for (final r in (benim['izlenenler'] as List<dynamic>? ?? [])) {
          if (r is Map &&
              r['sezon'] == widget.sezonNo &&
              r['bolum'] == widget.bolumNo) {
            izlenme = izlemeTarihiVeyaNull(r['tarih']);
            izlendi = true;
            break;
          }
        }
      }
      final diziHam = sonuc[4];
      final sezonHam = sonuc[5];
      // Sekme başlığı: "S1B2 · Bölüm adı" (bkz. sayfa_basligi.dart).
      // Anahtar rotanın yoluyla birebir: '/dizi/:id/sezon/:s/bolum/:b'.
      final bolumAdi = b['name'] as String?;
      SayfaBasligi.yaz(
        '/dizi/${widget.tmdbId}/sezon/${widget.sezonNo}/bolum/${widget.bolumNo}',
        'S${widget.sezonNo}B${widget.bolumNo}'
            '${bolumAdi == null || bolumAdi.isEmpty ? '' : ' · $bolumAdi'}',
      );
      setState(() {
        _izlenmeTarihi = izlenme;
        _izlendi = izlendi;
        _bolum = b;
        // Dizi yanıtı gerçekten dizi mi? (`seasons`/`number_of_seasons`
        // taşımalı; bölüm gövdesi dönen bir sahte sunucu dizi sanılmasın.)
        _dizi =
            diziHam is Map<String, dynamic> &&
                (diziHam['number_of_seasons'] != null ||
                    diziHam['seasons'] is List)
            ? diziHam
            : null;
        _sezonBolumleri = [
          for (final e
              in (sezonHam is Map ? sezonHam['episodes'] : null) as List? ??
                  const [])
            if (e is Map<String, dynamic> && e['episode_number'] is num) e,
        ];
        _kareler = _kareleriCikar(b, sonuc[1]);
        _fragmanlar = fragmanlariBirlestir(
          fragmanlariSec(b['videos'], dil: Ceviri.dil.value),
          fragmanlariSec(sonuc[2], dil: Ceviri.dil.value),
        );
      });
    } catch (e) {
      if (mounted) setState(() => _hata = e.toString());
    }
  }

  /// Kapak karesi + TMDB kareleri (en çok oy alan önce), tekrarsız.
  static List<String> _kareleriCikar(
    Map<String, dynamic> bolum,
    dynamic gorsel,
  ) {
    final yollar = <String>[];
    final kapak = bolum['still_path'] as String?;
    if (kapak != null && kapak.isNotEmpty) yollar.add(kapak);
    final kareler =
        <Map<String, dynamic>>[
          for (final k
              in (gorsel is Map ? gorsel['stills'] : null) as List? ?? [])
            if (k is Map<String, dynamic>) k,
        ]..sort(
          (a, b) => ((b['vote_count'] as num?) ?? 0).compareTo(
            (a['vote_count'] as num?) ?? 0,
          ),
        );
    for (final k in kareler) {
      final y = k['file_path'] as String?;
      if (y != null && y.isNotEmpty && !yollar.contains(y)) yollar.add(y);
      if (yollar.length >= 12) break;
    }
    return yollar;
  }

  Future<void> _izlendiToggle() async {
    if (!girisGerekli(context)) return;
    setState(() => _izlendi = !_izlendi);
    try {
      final c = await Api.post('/izleme/toggle', {
        'tmdb_id': widget.tmdbId,
        'tur': 'tv',
        'sezon': widget.sezonNo,
        'bolum': widget.bolumNo,
      });
      // İşaretlendiyse sunucu diziye izliyorum/bitirdim verir; poster rozeti
      // anında görünsün (kaldırmada rozet bırakılır: başka bölümler kalmış
      // olabilir, sunucuya sormadan silmek yanlış olurdu).
      if (c is Map && c['izlendi'] == true) {
        KitaplikDurumu.isaretle('tv', widget.tmdbId, true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _izlendi = !_izlendi);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  /// Bölüme puan verilince sunucu bölümü "izledim" işaretler (POST /puan
  /// `izlendi: true` döner). Yan etki SESSİZ kalmamalı: buton anında "İzledin"
  /// olur ve kullanıcıya ne olduğu söylenir.
  void _puanlaIzlendi() {
    if (_izlendi) return;
    setState(() => _izlendi = true);
    KitaplikDurumu.isaretle('tv', widget.tmdbId, true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Bölüm izlendi olarak işaretlendi'.c)),
    );
  }

  /// Aynı sezonun başka bölümüne geçer. `pushReplacement`: geri tuşu bölüm
  /// bölüm geri sarmasın, doğrudan dizi sayfasına dönsün. `extra: false` —
  /// izlenme bilgisi `/benim`den yeniden okunur (bkz. `_yukle`).
  void _bolumeGec(int bolumNo) {
    context.pushReplacement(
      '/dizi/${widget.tmdbId}/sezon/${widget.sezonNo}/bolum/$bolumNo',
      extra: false,
    );
  }

  /// Bölüm ekibi: TMDB bölüm yanıtındaki `crew` (yönetmen, senaryo…). Dizi
  /// sayfasının süzgeciyle aynı (`ekibiCikar` `credits.crew` okur; burada
  /// bölümün kendi `crew` alanı o kalıba sarılır).
  List<EkipUyesi> _ekip(Map<String, dynamic> b) => ekibiCikar({
    'credits': {'crew': b['crew']},
  });

  @override
  Widget build(BuildContext context) {
    final baslik = 'S{} · {}. Bölüm'.cf([widget.sezonNo, widget.bolumNo]);
    Widget govde;
    if (_hata != null) {
      govde = CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(baslik),
            actions: const [GirisEylemi()],
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: HataGorunumu(mesaj: _hata!, tekrar: _yukle),
          ),
        ],
      );
    } else if (_bolum == null) {
      govde = CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(baslik),
            actions: const [GirisEylemi()],
          ),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(color: DiziRenkler.sari),
            ),
          ),
        ],
      );
    } else {
      final b = _bolum!;
      final gorsel = posterUrl(b['still_path'] as String?, boyut: 'w780');
      final tarih = b['air_date'] as String? ?? '';
      final sure = (b['runtime'] as num?)?.toInt();
      final puan = b['vote_average'] as num?;
      final konuklar = (b['guest_stars'] as List<dynamic>? ?? []);
      final ekip = _ekip(b);
      final dizi = _dizi;
      final diziAdi = (dizi?['name'] as String?)?.trim() ?? '';
      final diziAfis = posterUrl(
        dizi?['poster_path'] as String?,
        boyut: 'w185',
      );
      final bolumler = _sezonBolumleri;
      final idx = bolumler.indexWhere(
        (e) => (e['episode_number'] as num).toInt() == widget.bolumNo,
      );
      final onceki = idx > 0 ? bolumler[idx - 1] : null;
      final sonraki = idx >= 0 && idx < bolumler.length - 1
          ? bolumler[idx + 1]
          : null;

      Widget? kahraman;
      if (_fragmanlar.isNotEmpty) {
        kahraman = KahramanKarisik(
          ogeler: karisikKahramanDiz(_fragmanlar, [
            for (final y in _kareler) posterUrl(y, boyut: 'w780')!,
          ]),
          onFotoAc: (url) {
            final fotolar = [
              for (final y in _kareler) posterUrl(y, boyut: 'w1280')!,
            ];
            final kucuk = [
              for (final y in _kareler) posterUrl(y, boyut: 'w780')!,
            ];
            final i = kucuk.indexOf(url);
            medyaGoster(context, fotolar, baslangic: i < 0 ? 0 : i);
          },
        );
      } else if (_kareler.length > 1) {
        kahraman = AkisMedya(
          urller: [for (final y in _kareler) posterUrl(y, boyut: 'w780')!],
          oran: 16 / 9,
          // Tam ekranda daha büyük kopya; üst sınır uygulamanın her
          // yerindeki gibi w1280 ('original' 1-2 MB'a çıkıp mobil veriyi
          // yerdi).
          onAc: (i) => medyaGoster(context, [
            for (final y in _kareler) posterUrl(y, boyut: 'w1280')!,
          ], baslangic: i),
        );
      } else if (gorsel != null) {
        kahraman = AspectRatio(
          aspectRatio: 16 / 9,
          child: GestureDetector(
            onTap: () => medyaGoster(context, [
              posterUrl(b['still_path'] as String?, boyut: 'w1280')!,
            ]),
            child: CachedNetworkImage(
              imageUrl: gorsel,
              httpHeaders: gorselBasliklari(gorsel),
              fit: BoxFit.cover,
            ),
          ),
        );
      }

      govde = CustomScrollView(
        slivers: [
          // Sabit üst çubuk: dizi sayfasındaki gibi kahramanın ÜSTÜNDE, onu
          // örtmez (fragman iframe'i webde platform görünümüdür; çubuk
          // üstüne binseydi geri tuşu tıklanamazdı).
          SliverAppBar(
            pinned: true,
            title: Text(baslik),
            actions: const [GirisEylemi()],
          ),
          if (kahraman != null) SliverToBoxAdapter(child: kahraman),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // DİZİNİN AFİŞİ BAŞLIĞIN SOLUNDA — dizi sayfasındaki
                      // afiş satırının aynısı; bölüm karesi (16:9 sahne)
                      // diziyi tanıtmaz, afiş tanıtır.
                      if (diziAfis != null) ...[
                        _DiziAfisi(
                          url: diziAfis,
                          ad: diziAdi,
                          onTap: () =>
                              context.push('/icerik/tv/${widget.tmdbId}'),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (diziAdi.isNotEmpty)
                              _DiziSatiri(
                                ad: diziAdi,
                                onTap: () =>
                                    context.push('/icerik/tv/${widget.tmdbId}'),
                              ),
                            Text(
                              b['name'] as String? ??
                                  '{}. Bölüm'.cf([widget.bolumNo]),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // META SATIRI — `Wrap`: rozet + tarih + süre +
                            // TMDB dar ekranda ya da büyük yazıda alt satıra
                            // iner, taşmaz (dizi sayfasındaki yıl satırıyla
                            // aynı karar).
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                SariRozet(
                                  kutuAnahtari: const Key('bolum-rozeti'),
                                  ipucu: 'Bölüm'.c,
                                  metin: 'S${widget.sezonNo}B${widget.bolumNo}',
                                ),
                                Text(
                                  [
                                    if (tarih.isNotEmpty)
                                      tarihBicimle(tarih, hepYil: true),
                                    if (sure != null) '{} dk'.cf([sure]),
                                  ].join(' · '),
                                  style: TextStyle(color: DiziRenkler.metin54),
                                ),
                                if (puan != null && puan > 0)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        color: DiziRenkler.sari,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '{} TMDB'.cf([puan.toStringAsFixed(1)]),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            // İZLENME TARİHİ — meta satırından AYRI ve göz
                            // ikonuyla. Meta satırına eklenseydi "20 Ocak
                            // 2008 · 14 Ağustos" gibi iki tarih yan yana
                            // gelir, hangisinin ne olduğu okunmazdı.
                            if (_izlendi && _izlenmeTarihi != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.visibility_outlined,
                                    size: 14,
                                    color: DiziRenkler.sariMetin,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      '{} tarihinde izledin'.cf([
                                        tarihBicimle(
                                          _izlenmeTarihi,
                                          hepYil: true,
                                        ),
                                      ]),
                                      style: TextStyle(
                                        color: DiziRenkler.sariMetin,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Aksiyon satırı: dizi sayfasındaki gibi TAM GENİŞLİK.
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _izlendiToggle,
                          style: _izlendi
                              ? FilledButton.styleFrom(
                                  backgroundColor: DiziRenkler.kart,
                                  foregroundColor: DiziRenkler.sariMetin,
                                )
                              : null,
                          icon: Icon(
                            _izlendi ? Icons.check_circle : Icons.visibility,
                          ),
                          label: Text(_izlendi ? 'İzledin'.c : 'İzledim'.c),
                        ),
                      ),
                    ],
                  ),
                  // BÖLÜM PUANI (8 Ağu 2026-d) — bölümün ASIL evi burası.
                  // "İzledim"in hemen altında: izleme → değerlendirme sırası
                  // kullanıcının doğal akışı. Dizinin GENEL puanı bu ekranda
                  // YOK; o dizi sayfasında durur, ikisi ayrı satırdır.
                  const SizedBox(height: 14),
                  Center(
                    child: BolumPuani(
                      tmdbId: widget.tmdbId,
                      sezon: widget.sezonNo,
                      bolum: widget.bolumNo,
                      izlendiIsaretlendi: _puanlaIzlendi,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Tepki ikonları — dizi sayfasındaki yerinde: aksiyonların
                  // altında, özetin üstünde.
                  TepkiSatiri(
                    tur: 'tv',
                    tmdbId: widget.tmdbId,
                    sezon: widget.sezonNo,
                    bolum: widget.bolumNo,
                  ),
                  if ((b['overview'] as String?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    Text(
                      b['overview'] as String,
                      style: const TextStyle(height: 1.5),
                    ),
                  ],
                  // ÖNCEKİ / SONRAKİ — sezon listesi geldiyse. Uçtaki bölümde
                  // ilgili düğme pasif kalır (kaybolmaz: satır zıplamasın).
                  if (bolumler.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _GecisDugmesi(
                            key: const Key('onceki-bolum'),
                            etiket: 'Önceki'.c,
                            bolum: onceki,
                            ileri: false,
                            onTap: onceki == null
                                ? null
                                : () => _bolumeGec(
                                    (onceki['episode_number'] as num).toInt(),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _GecisDugmesi(
                            key: const Key('sonraki-bolum'),
                            etiket: 'Sonraki'.c,
                            bolum: sonraki,
                            ileri: true,
                            onTap: sonraki == null
                                ? null
                                : () => _bolumeGec(
                                    (sonraki['episode_number'] as num).toInt(),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (ekip.isNotEmpty)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SeritBasligi(baslik: 'Yapım Ekibi'.c),
                  _KisiSeridi(
                    kisiler: [
                      for (final u in ekip)
                        _Kisi(
                          id: u.id,
                          ad: u.ad,
                          foto: u.foto,
                          alt: u.isler.map((i) => i.c).join(', '),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          if (konuklar.isNotEmpty)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SeritBasligi(
                    baslik: 'Konuk Oyuncular'.c,
                    ek: '(${konuklar.length})',
                  ),
                  _KisiSeridi(
                    kisiler: [
                      for (final o in konuklar.take(15))
                        if (o is Map<String, dynamic>)
                          _Kisi(
                            id: (o['id'] as num?)?.toInt(),
                            ad: o['name'] as String? ?? '',
                            foto: o['profile_path'] as String?,
                            alt: (o['character'] as String?)?.trim() ?? '',
                          ),
                    ],
                  ),
                ],
              ),
            ),
          if (bolumler.length > 1)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SeritBasligi(
                    baslik: 'Sezonun bölümleri'.c,
                    ek: '(${bolumler.length})',
                  ),
                  _BolumSeridi(
                    bolumler: bolumler,
                    seciliNo: widget.bolumNo,
                    onSec: _bolumeGec,
                  ),
                ],
              ),
            ),
          SliverToBoxAdapter(
            child: YorumBolumu(
              tur: 'tv',
              tmdbId: widget.tmdbId,
              sezon: widget.sezonNo,
              bolum: widget.bolumNo,
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: altGuvenli(context, ekstra: 32)),
          ),
        ],
      );
    }

    return Scaffold(
      // PC'de akış/detay ile AYNI ortalanmış okuma kolonu (madde 26); mobilde
      // kısıt bağlamaz.
      body: OrtaKolon(azami: masaustuKolonGenisligi, cocuk: govde),
    );
  }
}

/// Dizinin afişi (2:3), başlığın solunda; dokununca dizi sayfası.
class _DiziAfisi extends StatelessWidget {
  final String url;
  final String ad;
  final VoidCallback onTap;

  const _DiziAfisi({required this.url, required this.ad, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Diziye git'.c,
      excludeSemantics: true,
      child: InkWell(
        key: const Key('dizi-afisi'),
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 64,
            height: 96,
            child: CachedNetworkImage(
              imageUrl: url,
              httpHeaders: gorselBasliklari(url),
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(color: DiziRenkler.kart),
              errorWidget: (_, _, _) => Container(
                color: DiziRenkler.kart,
                child: Icon(Icons.tv, color: DiziRenkler.metin24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Dizi adı ›" — başlığın üstünde, soluk; dokununca dizi sayfası.
class _DiziSatiri extends StatelessWidget {
  final String ad;
  final VoidCallback onTap;

  const _DiziSatiri({required this.ad, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${'Diziye git'.c}: $ad',
      excludeSemantics: true,
      child: InkWell(
        key: const Key('dizi-satiri'),
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        // Dokunma hedefi 44 dp'ye yakın (ux md.2): metin 13 dp ama satır
        // 40 dp; afiş de aynı yere götürdüğü için ikinci hedef zaten geniş.
        child: SizedBox(
          height: 40,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  ad,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: DiziRenkler.sariMetin,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: DiziRenkler.sariMetin),
            ],
          ),
        ),
      ),
    );
  }
}

/// Önceki / Sonraki bölüm düğmesi: etiket + (varsa) bölümün numarası ve adı.
/// [bolum] null ise pasif (uçtaki bölüm).
class _GecisDugmesi extends StatelessWidget {
  final String etiket;
  final Map<String, dynamic>? bolum;
  final bool ileri;
  final VoidCallback? onTap;

  const _GecisDugmesi({
    super.key,
    required this.etiket,
    required this.bolum,
    required this.ileri,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final b = bolum;
    final alt = b == null
        ? null
        : '${b['episode_number']}. ${(b['name'] as String?)?.trim() ?? ''}';
    final govde = Column(
      crossAxisAlignment: ileri
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          etiket,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        if (alt != null)
          Text(
            alt,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: ileri ? TextAlign.right : TextAlign.left,
            style: TextStyle(fontSize: 11, color: DiziRenkler.metin54),
          ),
      ],
    );
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, dokunmaHedefi),
        alignment: ileri ? Alignment.centerRight : Alignment.centerLeft,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!ileri) ...[
            const Icon(Icons.chevron_left, size: 20),
            const SizedBox(width: 4),
          ],
          Flexible(child: govde),
          if (ileri) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ],
      ),
    );
  }
}

class _Kisi {
  final int? id;
  final String ad;
  final String? foto;
  final String alt;
  const _Kisi({
    required this.id,
    required this.ad,
    required this.foto,
    required this.alt,
  });
}

/// Kişi kartı şeridi (konuk oyuncu / ekip) — dizi sayfasındaki oyuncu ve
/// ekip şeritleriyle aynı ölçüler: 76 dp kart, 34 dp yuvarlak fotoğraf, ad
/// + alt satır (rol ya da karakter).
class _KisiSeridi extends StatelessWidget {
  final List<_Kisi> kisiler;
  const _KisiSeridi({required this.kisiler});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 164,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: kisiler.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final k = kisiler[i];
          final foto = posterUrl(k.foto, boyut: 'w185');
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: k.id == null ? null : () => context.push('/kisi/${k.id}'),
            child: SizedBox(
              width: 76,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: DiziRenkler.kart,
                    backgroundImage: foto == null
                        ? null
                        : CachedNetworkImageProvider(
                            foto,
                            headers: gorselBasliklari(foto),
                          ),
                    child: foto == null
                        ? Icon(Icons.person, color: DiziRenkler.metin24)
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    k.ad,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                  ),
                  if (k.alt.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      k.alt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: DiziRenkler.metin54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Sezonun bölümleri: yatay kare şeridi; açık olan bölüm sarı çerçeveli.
/// Açılışta seçili bölüm görünür konuma kaydırılır.
class _BolumSeridi extends StatefulWidget {
  final List<Map<String, dynamic>> bolumler;
  final int seciliNo;
  final void Function(int bolumNo) onSec;

  const _BolumSeridi({
    required this.bolumler,
    required this.seciliNo,
    required this.onSec,
  });

  static const kartEni = 132.0;
  static const ara = 10.0;

  @override
  State<_BolumSeridi> createState() => _BolumSeridiState();
}

class _BolumSeridiState extends State<_BolumSeridi> {
  late final ScrollController _kaydirma;

  @override
  void initState() {
    super.initState();
    final i = widget.bolumler.indexWhere(
      (e) => (e['episode_number'] as num).toInt() == widget.seciliNo,
    );
    // Seçili kart soldan bir kart payı içeride başlasın: kullanıcı önceki
    // bölümün de orada olduğunu görsün.
    final hedef = i <= 0
        ? 0.0
        : (i - 1) * (_BolumSeridi.kartEni + _BolumSeridi.ara);
    _kaydirma = ScrollController(initialScrollOffset: hedef);
  }

  @override
  void dispose() {
    _kaydirma.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView.separated(
        controller: _kaydirma,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.bolumler.length,
        separatorBuilder: (_, _) => const SizedBox(width: _BolumSeridi.ara),
        itemBuilder: (context, i) {
          final e = widget.bolumler[i];
          final no = (e['episode_number'] as num).toInt();
          final secili = no == widget.seciliNo;
          final gorsel = posterUrl(e['still_path'] as String?, boyut: 'w300');
          final ad = (e['name'] as String?)?.trim() ?? '';
          return Semantics(
            button: !secili,
            selected: secili,
            label: '$no. $ad',
            excludeSemantics: true,
            child: InkWell(
              key: Key('sezon-bolum-$no'),
              borderRadius: BorderRadius.circular(10),
              onTap: secili ? null : () => widget.onSec(no),
              child: SizedBox(
                width: _BolumSeridi.kartEni,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 74,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: secili
                              ? DiziRenkler.sari
                              : DiziRenkler.metin12,
                          width: secili ? 2 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: gorsel == null
                          ? Container(
                              color: DiziRenkler.koyuGri,
                              child: Icon(Icons.tv, color: DiziRenkler.metin24),
                            )
                          : CachedNetworkImage(
                              imageUrl: gorsel,
                              httpHeaders: gorselBasliklari(gorsel),
                              fit: BoxFit.cover,
                            ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$no. $ad',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: secili ? FontWeight.w800 : FontWeight.w600,
                        color: secili
                            ? DiziRenkler.sariMetin
                            : DiziRenkler.metin,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
