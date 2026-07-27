import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';

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

  @override
  void initState() {
    super.initState();
    Api.get('/tmdb/${widget.tur}/${widget.tmdbId}')
        .then((d) {
          if (mounted) setState(() => _icerik = d as Map<String, dynamic>);
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
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
              ? Image.network(poster, fit: BoxFit.cover)
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
