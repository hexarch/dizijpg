import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../gorsel_basliklari.dart';
import '../kitaplik_durumu.dart';
import '../tarih.dart';
import '../tema.dart';
import '../tmdb_fragman.dart';
import 'giris_istem.dart';
import 'kahraman_karisik.dart';
import 'medya_goster.dart';
import 'ortak.dart';
import 'tepki.dart';
import 'yorumlar.dart';

/// Bölüm sayfası: görsel, özet, konuk oyuncular, izleme işareti ve
/// bölüme özel yorumlar.
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
    final taban =
        '/tmdb/tv/${widget.tmdbId}/season/${widget.sezonNo}/episode/${widget.bolumNo}';
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
        Api.get(
          '/tmdb/tv/${widget.tmdbId}/season/${widget.sezonNo}/videos?$videoDil',
        ).catchError((_) => null),
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
      ]);
      if (!mounted) return;
      final b = sonuc[0] as Map<String, dynamic>;
      // `izlenenler` satırlarından BU bölümün tarihi.
      String? izlenme;
      final benim = sonuc.length > 3 ? sonuc[3] : null;
      if (benim is Map) {
        for (final r in (benim['izlenenler'] as List<dynamic>? ?? [])) {
          if (r is Map &&
              r['sezon'] == widget.sezonNo &&
              r['bolum'] == widget.bolumNo) {
            izlenme = izlemeTarihiVeyaNull(r['tarih']);
            break;
          }
        }
      }
      setState(() {
        _izlenmeTarihi = izlenme;
        _bolum = b;
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

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_bolum == null) {
      govde = const Center(
        child: CircularProgressIndicator(color: DiziRenkler.sari),
      );
    } else {
      final b = _bolum!;
      final gorsel = posterUrl(b['still_path'] as String?, boyut: 'w780');
      final tarih = b['air_date'] as String? ?? '';
      final sure = (b['runtime'] as num?)?.toInt();
      final konuklar = (b['guest_stars'] as List<dynamic>? ?? []);

      govde = ListView(
        padding: EdgeInsets.only(bottom: altGuvenli(context)),
        children: [
          // Fragman ve kareler tek kaydırıcıda: video, foto, video…
          if (_fragmanlar.isNotEmpty)
            KahramanKarisik(
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
            )
          else if (_kareler.length > 1)
            AkisMedya(
              urller: [for (final y in _kareler) posterUrl(y, boyut: 'w780')!],
              oran: 16 / 9,
              // Tam ekranda daha büyük kopya; üst sınır uygulamanın her
              // yerindeki gibi w1280 ('original' 1-2 MB'a çıkıp mobil veriyi
              // yerdi).
              onAc: (i) => medyaGoster(context, [
                for (final y in _kareler) posterUrl(y, boyut: 'w1280')!,
              ], baslangic: i),
            )
          else if (gorsel != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                imageUrl: gorsel,
                httpHeaders: gorselBasliklari(gorsel),
                fit: BoxFit.cover,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b['name'] as String? ?? '{}. Bölüm'.cf([widget.bolumNo]),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    'S${widget.sezonNo}B${widget.bolumNo}',
                    if (tarih.isNotEmpty) tarihBicimle(tarih, hepYil: true),
                    if (sure != null) '{} dk'.cf([sure]),
                    if (b['vote_average'] != null)
                      '{} TMDB'.cf([
                        (b['vote_average'] as num).toStringAsFixed(1),
                      ]),
                  ].join(' · '),
                  style: TextStyle(color: DiziRenkler.metin54),
                ),
                // İZLENME TARİHİ — yayın tarihinden AYRI satırda ve göz
                // ikonuyla. Üstteki meta satırına eklenseydi "· 20 Ocak 2008 ·
                // 14 Ağustos ·" gibi iki tarih yan yana gelir, hangisinin ne
                // olduğu okunmazdı (bölüm listesinde de aynı ayrım var).
                if (_izlendi && _izlenmeTarihi != null) ...[
                  const SizedBox(height: 6),
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
                            tarihBicimle(_izlenmeTarihi, hepYil: true),
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
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _izlendiToggle,
                  style: _izlendi
                      ? FilledButton.styleFrom(
                          backgroundColor: DiziRenkler.kart,
                          foregroundColor: DiziRenkler.sariMetin,
                        )
                      : null,
                  icon: Icon(_izlendi ? Icons.check_circle : Icons.visibility),
                  label: Text(_izlendi ? 'İzledin'.c : 'İzledim'.c),
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
                if ((b['overview'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 14),
                  Text(
                    b['overview'] as String,
                    style: const TextStyle(height: 1.5),
                  ),
                ],
              ],
            ),
          ),
          if (konuklar.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                'Konuk Oyuncular'.c,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: konuklar.length.clamp(0, 15),
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final o = konuklar[i] as Map<String, dynamic>;
                  final foto = posterUrl(
                    o['profile_path'] as String?,
                    boyut: 'w185',
                  );
                  return SizedBox(
                    width: 76,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.push('/kisi/${o['id']}'),
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
                            o['name'] as String? ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TepkiSatiri(
              tur: 'tv',
              tmdbId: widget.tmdbId,
              sezon: widget.sezonNo,
              bolum: widget.bolumNo,
            ),
          ),
          YorumBolumu(
            tur: 'tv',
            tmdbId: widget.tmdbId,
            sezon: widget.sezonNo,
            bolum: widget.bolumNo,
          ),
          const SizedBox(height: 32),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('S{} · {}. Bölüm'.cf([widget.sezonNo, widget.bolumNo])),
        actions: const [GirisEylemi()],
      ),
      // PC'de akış/detay ile AYNI ortalanmış okuma kolonu (madde 26); mobilde
      // kısıt bağlamaz.
      body: OrtaKolon(azami: masaustuKolonGenisligi, cocuk: govde),
    );
  }
}
