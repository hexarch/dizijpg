import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../puan.dart';
import '../tema.dart';
import 'giris_istem.dart';
import 'ortak.dart';
import 'puan_sheet.dart';
import 'yorumlar.dart';

class KisiEkrani extends StatefulWidget {
  final int kisiId;
  const KisiEkrani({super.key, required this.kisiId});

  @override
  State<KisiEkrani> createState() => _KisiEkraniState();
}

class _KisiEkraniState extends State<KisiEkrani> {
  Map<String, dynamic>? _kisi;
  List<dynamic> _isler = [];
  Map<String, dynamic>? _benimPuan;
  bool _favori = false;
  Map<String, dynamic>? _toplum;
  String? _hata;

  /// İzlenme oranı: null = henüz gelmedi (iskelet), (izlenen, toplam).
  (int, int)? _izlenme;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _puanYenile() async {
    try {
      // `/benim/...` girisZorunlu: oturumsuzda hiç istenmez (401 gelirdi ve
      // toplum puanı da onunla birlikte sessizce kaybolurdu).
      final sonuclar = await Future.wait([
        Api.get('/incelemeler/person/${widget.kisiId}'),
        if (Api.girisli) Api.get('/benim/person/${widget.kisiId}'),
      ]);
      if (mounted) {
        setState(() {
          _toplum = sonuclar[0] as Map<String, dynamic>;
          _benimPuan = sonuclar.length > 1
              ? sonuclar[1]['puan'] as Map<String, dynamic>?
              : null;
          _favori = sonuclar.length > 1 && sonuclar[1]['favori'] == true;
        });
      }
    } catch (_) {}
  }

  /// Oyuncunun yapımlarından kaçını izlediğim (puanın ALTINDAKİ "10/20").
  /// Oturumsuzda hiç istenmez: uç `girisZorunlu` ve oran zaten kişiye özel.
  Future<void> _izlenmeYukle() async {
    if (!Api.girisli) return;
    try {
      final d = await Api.get('/kisi/${widget.kisiId}/izlenme');
      if (!mounted) return;
      setState(
        () => _izlenme = (
          (d['izlenen'] as num?)?.toInt() ?? 0,
          (d['toplam'] as num?)?.toInt() ?? 0,
        ),
      );
    } catch (_) {
      // Oran ikincil bilgi: gelmezse satır hiç çizilmez, sayfa etkilenmez.
    }
  }

  /// Favori kalbi. İYİMSER: dokunma anında dolar/boşalır, istek düşerse
  /// ESKİ HÂLE GERİ ALINIR + SnackBar (sessiz başarısızlık yasak).
  Future<void> _favoriToggle() async {
    if (!girisGerekli(context)) return;
    final onceki = _favori;
    setState(() => _favori = !onceki);
    try {
      final c = await Api.post('/favori/toggle', {
        'tmdb_id': widget.kisiId,
        'tur': 'person',
      });
      if (!mounted) return;
      setState(() => _favori = c is Map ? c['favori'] == true : !onceki);
    } catch (e) {
      if (!mounted) return;
      setState(() => _favori = onceki);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _puanla() async {
    if (!girisGerekli(context)) return;
    final kaydedildi = await puanlaVeKaydet(
      context,
      tur: 'person',
      tmdbId: widget.kisiId,
      mevcutPuan: _benimPuan?['puan'] as int?,
      mevcutYorum: _benimPuan?['yorum'] as String?,
    );
    if (kaydedildi) _puanYenile();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    _puanYenile();
    _izlenmeYukle();
    try {
      final sonuclar = await Future.wait([
        Api.get('/tmdb/person/${widget.kisiId}'),
        Api.get('/tmdb/person/${widget.kisiId}/combined_credits'),
      ]);
      if (!mounted) return;
      final isler =
          (sonuclar[1]['cast'] as List<dynamic>)
              .where((c) => c['poster_path'] != null)
              .toList()
            ..sort(
              (a, b) => ((b['vote_count'] as num?) ?? 0).compareTo(
                (a['vote_count'] as num?) ?? 0,
              ),
            );
      setState(() {
        _kisi = sonuclar[0] as Map<String, dynamic>;
        _isler = isler.take(60).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hata != null) {
      return Scaffold(
        appBar: AppBar(),
        body: HataGorunumu(mesaj: _hata!, tekrar: _yukle),
      );
    }
    if (_kisi == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: DiziRenkler.sari)),
      );
    }
    final k = _kisi!;
    final foto = posterUrl(k['profile_path'] as String?, boyut: 'w342');

    return Scaffold(
      appBar: AppBar(
        title: Text(k['name'] as String? ?? ''),
        actions: [
          // Favori oyuncu: dizi/filmdeki kalple AYNI yerde (sağ üst) ve AYNI
          // renkte — kullanıcı öğrendiği jesti burada da uygular.
          IconButton(
            onPressed: _favoriToggle,
            tooltip: 'Favori'.c,
            icon: Icon(
              _favori ? Icons.favorite : Icons.favorite_border,
              color: _favori ? Colors.redAccent : DiziRenkler.metin,
            ),
          ),
          const GirisEylemi(),
        ],
      ),
      // PC'de akış/detay ile AYNI ortalanmış okuma kolonu (madde 26); mobilde
      // kısıt bağlamaz, tam genişlik korunur.
      body: OrtaKolon(
        azami: masaustuKolonGenisligi,
        cocuk: ListView(
          padding: EdgeInsets.fromLTRB(0, 16, 0, altGuvenli(context)),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 110,
                          height: 165,
                          child: foto == null
                              ? Container(
                                  color: DiziRenkler.kart,
                                  child: Icon(
                                    Icons.person,
                                    color: DiziRenkler.metin24,
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: foto,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              k['name'] as String? ?? '',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (k['birthday'] != null)
                              _BilgiSatiri(
                                ikon: Icons.cake_outlined,
                                metin: '${k['birthday']}',
                              ),
                            if ((k['place_of_birth'] as String?)?.isNotEmpty ==
                                true)
                              _BilgiSatiri(
                                ikon: Icons.location_on_outlined,
                                metin: k['place_of_birth'] as String,
                              ),
                            _BilgiSatiri(
                              ikon: Icons.movie_outlined,
                              metin: '{}+ yapım'.cf([_isler.length]),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _puanla,
                                  icon: Icon(
                                    _benimPuan != null
                                        ? Icons.star
                                        : Icons.star_border,
                                    size: 18,
                                    color: DiziRenkler.sari,
                                  ),
                                  label: Text(
                                    _benimPuan != null
                                        ? '${yildiza(_benimPuan!['puan'])}/$yildizAzami'
                                        : 'Puanla'.c,
                                    style: TextStyle(
                                      color: DiziRenkler.sariMetin,
                                    ),
                                  ),
                                ),
                                if (_toplum?['ortalama'] != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    'ort. {}'.cf([
                                      yildizOrtalamaMetni(_toplum!['ortalama']),
                                    ]),
                                    style: TextStyle(
                                      color: DiziRenkler.metin54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            // İSTEK: "puanla yazısının ALTINDA 10/20 gibi".
                            // Oturumsuzda ve oran gelmeden hiç çizilmez.
                            if (_izlenme != null && _izlenme!.$2 > 0)
                              IzlenmeOraniSatiri(
                                izlenen: _izlenme!.$1,
                                toplam: _izlenme!.$2,
                                onTap: () => context.push(
                                  '/yapimlar/${widget.kisiId}',
                                  extra: k['name'] as String?,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if ((k['biography'] as String?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 14),
                    // Biyografi 6 satırda kırpılır, taşarsa sonunda üç nokta
                    // çıkar ve METNE DOKUNUNCA tamamı açılır (AcilirMetin).
                    AcilirMetin(
                      k['biography'] as String,
                      stil: TextStyle(height: 1.5, color: DiziRenkler.metin70),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    'Yapımları'.c,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const PosterIzgarasi(
                      satirBoslugu: 14,
                      bosluk: 10,
                    ),
                    itemCount: _isler.length,
                    itemBuilder: (context, i) =>
                        PosterKarti(icerik: _isler[i] as Map<String, dynamic>),
                  ),
                ],
              ),
            ),
            // Kişi kartı Reels'e buradan verilir: /icerikler ucu yalnız dizi/film
            // bilir, kişi adı olmadan Reels üstünde "?" görünürdü.
            YorumBolumu(
              tur: 'person',
              tmdbId: widget.kisiId,
              icerik: {'ad': k['name'], 'poster': k['profile_path']},
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// "10/20 izledin" — oyuncunun yapımlarından kaçını izlediğim.
///
/// İSTEK (8 Ağu 2026): "puanla yazısının altında göstermeli, mesela 10/20 gibi
/// — 20 oynadığı dizi filmden 10 tanesini izlemiş gibi. Tıklayınca da list view
/// halinde..."
///
/// TIKLANABİLİRLİK GÖRÜNÜR OLMALI: yalnız metin bırakılsaydı dokunulabildiği
/// anlaşılmazdı; sağdaki chevron ve InkWell dalgası bunu söylüyor. Yükseklik
/// 44 dp'ye SABİTLENİR (dokunma hedefi asgarisi) — 12 px'lik metin tek başına
/// ~20 dp'lik bir hedef bırakırdı.
/// ---------------------------------------------------------------------------
class IzlenmeOraniSatiri extends StatelessWidget {
  final int izlenen;
  final int toplam;
  final VoidCallback onTap;

  const IzlenmeOraniSatiri({
    super.key,
    required this.izlenen,
    required this.toplam,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '{} yapımdan {} tanesini izledin'.cf([toplam, izlenen]),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.remove_red_eye_outlined,
                size: 16,
                color: DiziRenkler.sariMetin,
              ),
              const SizedBox(width: 6),
              // ExcludeSemantics: üstteki Semantics zaten tam cümleyi okuyor,
              // ekran okuyucu "10/20 izledin" diye İKİ KEZ tekrarlamasın.
              ExcludeSemantics(
                child: Text(
                  '$izlenen/$toplam',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              // TAŞMA: 110 dp'lik fotoğrafın yanındaki sütun dar telefonda
              // ~200 dp; uzun çevirilerde ("izledin" bazı dillerde 3 kelime)
              // Flexible + ellipsis satırı kırpar, sarı-siyah şerit çıkmaz.
              Flexible(
                child: ExcludeSemantics(
                  child: Text(
                    'izledin'.c,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: DiziRenkler.metin54),
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: DiziRenkler.metin38),
            ],
          ),
        ),
      ),
    );
  }
}

/// Küçük ikonlu bilgi satırı (doğum günü, yer, yapım sayısı).
class _BilgiSatiri extends StatelessWidget {
  final IconData ikon;
  final String metin;

  const _BilgiSatiri({required this.ikon, required this.metin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 14, color: DiziRenkler.metin54),
          const SizedBox(width: 5),
          // TAŞMA: uzun doğum yeri ("Los Angeles, California, USA") 360-500 dp
          // telefonda satırı 74 px taşırıyor ve Flutter sarı-siyah şerit
          // çiziyordu. Flexible + ellipsis: metin sığmazsa kırpılır, sayfa
          // bozulmaz. (MainAxisSize.min korunuyor — satır içeriği kadar geniş.)
          Flexible(
            child: Text(
              metin,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: DiziRenkler.metin54),
            ),
          ),
        ],
      ),
    );
  }
}
