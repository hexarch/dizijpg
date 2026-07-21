import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../tema.dart';
import 'bolum.dart';
import 'kisi.dart';
import 'ortak.dart';
import 'puan_sheet.dart';
import 'yorumlar.dart';

const durumSecenekleri = [
  ('izleyecegim', 'İzleyeceğim', Icons.bookmark_add_outlined),
  ('izliyorum', 'İzliyorum', Icons.play_circle_outline),
  ('bitirdim', 'Bitirdim', Icons.check_circle_outline),
  ('biraktim', 'Bıraktım', Icons.cancel_outlined),
];

class DetayEkrani extends StatefulWidget {
  final int tmdbId;
  final String tur; // 'tv' | 'movie'

  const DetayEkrani({super.key, required this.tmdbId, required this.tur});

  @override
  State<DetayEkrani> createState() => _DetayEkraniState();
}

class _DetayEkraniState extends State<DetayEkrani> {
  Map<String, dynamic>? _icerik;
  Map<String, dynamic>? _benim;
  Map<String, dynamic>? _incelemeler;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      final sonuclar = await Future.wait([
        Api.get('/tmdb/${widget.tur}/${widget.tmdbId}'),
        Api.get('/benim/${widget.tur}/${widget.tmdbId}'),
        Api.get('/incelemeler/${widget.tur}/${widget.tmdbId}'),
      ]);
      if (!mounted) return;
      setState(() {
        _icerik = sonuclar[0] as Map<String, dynamic>;
        _benim = sonuclar[1] as Map<String, dynamic>;
        _incelemeler = sonuclar[2] as Map<String, dynamic>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
    }
  }

  Future<void> _benimYenile() async {
    try {
      final b = await Api.get('/benim/${widget.tur}/${widget.tmdbId}');
      if (mounted) setState(() => _benim = b as Map<String, dynamic>);
    } catch (_) {}
  }

  Future<void> _durumSec(String? durum) async {
    await Api.post('/durum',
        {'tmdb_id': widget.tmdbId, 'tur': widget.tur, 'durum': durum ?? ''});
    _benimYenile();
  }

  Future<void> _favoriToggle() async {
    await Api.post(
        '/favori/toggle', {'tmdb_id': widget.tmdbId, 'tur': widget.tur});
    _benimYenile();
  }

  Future<void> _filmIzlendiToggle() async {
    await Api.post('/izleme/toggle',
        {'tmdb_id': widget.tmdbId, 'tur': 'movie', 'sezon': 0, 'bolum': 0});
    _benimYenile();
  }

  Future<void> _puanla() async {
    final kaydedildi = await puanlaVeKaydet(
      context,
      tur: widget.tur,
      tmdbId: widget.tmdbId,
      mevcutPuan: _benim?['puan']?['puan'] as int?,
      mevcutYorum: _benim?['puan']?['yorum'] as String?,
    );
    if (kaydedildi) {
      _benimYenile();
      try {
        final inc = await Api.get('/incelemeler/${widget.tur}/${widget.tmdbId}');
        if (mounted) setState(() => _incelemeler = inc as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  Future<void> _listeyeEkle() async {
    try {
      final d = await Api.get('/listelerim');
      if (!mounted) return;
      final listeler = d['listeler'] as List<dynamic>;
      await showModalBottomSheet(
        context: context,
        backgroundColor: DiziRenkler.koyuGri,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Listeye Ekle',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              if (listeler.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Henüz listen yok — Profil sekmesinden oluştur.'),
                ),
              for (final l in listeler)
                ListTile(
                  leading:
                      const Icon(Icons.playlist_add, color: DiziRenkler.kirmizi),
                  title: Text(l['ad'] as String),
                  subtitle: Text('${l['oge_sayisi']} içerik'),
                  onTap: () async {
                    await Api.post('/listeler/${l['id']}/oge',
                        {'tmdb_id': widget.tmdbId, 'tur': widget.tur});
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hata != null) {
      return Scaffold(
          appBar: AppBar(),
          body: HataGorunumu(mesaj: _hata!, tekrar: _yukle));
    }
    if (_icerik == null) {
      return const Scaffold(
          body: Center(
              child: CircularProgressIndicator(color: DiziRenkler.kirmizi)));
    }

    final c = _icerik!;
    final tv = widget.tur == 'tv';
    final ad = (c['name'] ?? c['title'] ?? '?') as String;
    final yil = ((c['first_air_date'] ?? c['release_date'] ?? '') as String)
        .split('-')
        .first;
    final turler = ((c['genres'] as List<dynamic>?) ?? [])
        .map((g) => g['name'])
        .take(3)
        .join(' · ');
    final arka = posterUrl(c['backdrop_path'] as String?, boyut: 'w780');
    final kadro = ((c['credits']?['cast'] as List<dynamic>?) ?? []);
    final oneriler = ((c['recommendations']?['results'] as List<dynamic>?) ?? []);
    final sezonlar = ((c['seasons'] as List<dynamic>?) ?? [])
        .where((s) => (s['season_number'] as int) > 0)
        .toList();
    final izlenenSet = {
      for (final r in (_benim?['izlenenler'] as List<dynamic>? ?? []))
        '${r['sezon']}:${r['bolum']}'
    };
    final filmIzlendi = !tv && izlenenSet.contains('0:0');
    final favori = _benim?['favori'] == true;
    final benimDurum = _benim?['durum'] as String?;
    final benimPuan = _benim?['puan']?['puan'] as int?;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: arka == null
                  ? Container(color: DiziRenkler.kart)
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(imageUrl: arka, fit: BoxFit.cover),
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, DiziRenkler.siyah],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ad,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (yil.isNotEmpty) yil,
                      if (tv) '${c['number_of_seasons']} sezon',
                      if (turler.isNotEmpty) turler,
                    ].join(' · '),
                    style: const TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, color: DiziRenkler.kirmizi, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${((c['vote_average'] as num?) ?? 0).toStringAsFixed(1)} TMDB',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (_incelemeler?['ortalama'] != null) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: DiziRenkler.kirmizi,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_incelemeler!['ortalama']} dizi.jpg',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Durum çipleri
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final (kod, etiket, ikon) in durumSecenekleri)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              avatar: Icon(ikon,
                                  size: 16,
                                  color: benimDurum == kod
                                      ? Colors.black
                                      : Colors.white70),
                              label: Text(etiket,
                                  style: TextStyle(
                                      color: benimDurum == kod
                                          ? Colors.black
                                          : Colors.white)),
                              selected: benimDurum == kod,
                              onSelected: (s) => _durumSec(s ? kod : null),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Aksiyon satırı
                  Row(
                    children: [
                      if (!tv)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _filmIzlendiToggle,
                            style: filmIzlendi
                                ? FilledButton.styleFrom(
                                    backgroundColor: DiziRenkler.kart,
                                    foregroundColor: DiziRenkler.kirmizi)
                                : null,
                            icon: Icon(filmIzlendi
                                ? Icons.check_circle
                                : Icons.visibility),
                            label:
                                Text(filmIzlendi ? 'İzledin' : 'İzledim'),
                          ),
                        ),
                      if (!tv) const SizedBox(width: 8),
                      IconButton(
                        onPressed: _favoriToggle,
                        icon: Icon(
                          favori ? Icons.favorite : Icons.favorite_border,
                          color: favori ? Colors.redAccent : Colors.white,
                        ),
                      ),
                      IconButton(
                        onPressed: _puanla,
                        icon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                                benimPuan != null
                                    ? Icons.star
                                    : Icons.star_border,
                                color: DiziRenkler.kirmizi),
                            if (benimPuan != null)
                              Text(' $benimPuan',
                                  style: const TextStyle(
                                      color: DiziRenkler.kirmizi,
                                      fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _listeyeEkle,
                        icon: const Icon(Icons.playlist_add,
                            color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if ((c['overview'] as String?)?.isNotEmpty == true)
                    Text(c['overview'] as String,
                        style: const TextStyle(height: 1.5)),
                ],
              ),
            ),
          ),
          // Sezonlar (dizi)
          if (tv)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text('Sezonlar',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  for (final s in sezonlar)
                    _SezonSatiri(
                      tmdbId: widget.tmdbId,
                      sezon: s as Map<String, dynamic>,
                      izlenenSet: izlenenSet,
                      degisti: _benimYenile,
                    ),
                ],
              ),
            ),
          // Oyuncular
          if (kadro.isNotEmpty)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: Text('Oyuncular',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  SizedBox(
                    height: 150,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: kadro.length.clamp(0, 20),
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final o = kadro[i] as Map<String, dynamic>;
                        final foto =
                            posterUrl(o['profile_path'] as String?, boyut: 'w185');
                        return InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    KisiEkrani(kisiId: o['id'] as int)),
                          ),
                          child: SizedBox(
                            width: 76,
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 34,
                                  backgroundColor: DiziRenkler.kart,
                                  backgroundImage: foto == null
                                      ? null
                                      : CachedNetworkImageProvider(foto),
                                  child: foto == null
                                      ? const Icon(Icons.person,
                                          color: Colors.white24)
                                      : null,
                                ),
                                const SizedBox(height: 6),
                                Text(o['name'] as String? ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          // İncelemeler
          if ((_incelemeler?['incelemeler'] as List<dynamic>? ?? [])
              .isNotEmpty)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text('İncelemeler',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  for (final inc in (_incelemeler!['incelemeler']
                          as List<dynamic>)
                      .take(10))
                    Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('@${inc['kullanici_adi']}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: DiziRenkler.kirmizi)),
                                const Spacer(),
                                const Icon(Icons.star,
                                    color: DiziRenkler.kirmizi, size: 14),
                                Text(' ${inc['puan']}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(inc['yorum'] as String,
                                style: const TextStyle(height: 1.4)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          // Yorumlar (fotoğraf/video destekli)
          SliverToBoxAdapter(
            child: YorumBolumu(tur: widget.tur, tmdbId: widget.tmdbId),
          ),
          // Öneriler
          if (oneriler.isNotEmpty)
            SliverToBoxAdapter(
              child: PosterSeridi(
                  baslik: 'Bunları da Beğenebilirsin',
                  icerikler: oneriler,
                  turZorla: widget.tur),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

/// Tıklayınca yeni sayfa açmaz; kartın altında bölüm listesi açılır.
/// Bölüme tıklamak bölüm sayfasını açar, sağdaki halka izleme işaretidir.
class _SezonSatiri extends StatefulWidget {
  final int tmdbId;
  final Map<String, dynamic> sezon;
  final Set<String> izlenenSet;
  final VoidCallback degisti;

  const _SezonSatiri({
    required this.tmdbId,
    required this.sezon,
    required this.izlenenSet,
    required this.degisti,
  });

  @override
  State<_SezonSatiri> createState() => _SezonSatiriState();
}

class _SezonSatiriState extends State<_SezonSatiri> {
  bool _acik = false;
  List<dynamic>? _bolumler;
  String? _hata;

  int get _no => widget.sezon['season_number'] as int;

  Future<void> _bolumleriYukle() async {
    setState(() => _hata = null);
    try {
      final d = await Api.get('/tmdb/tv/${widget.tmdbId}/season/$_no');
      if (mounted) {
        setState(() => _bolumler = d['episodes'] as List<dynamic>);
      }
    } catch (e) {
      if (mounted) setState(() => _hata = e.toString());
    }
  }

  Future<void> _toggle(int bolumNo) async {
    try {
      await Api.post('/izleme/toggle', {
        'tmdb_id': widget.tmdbId,
        'tur': 'tv',
        'sezon': _no,
        'bolum': bolumNo,
      });
      widget.degisti();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _tumu(bool isaretle, int toplam) async {
    try {
      await Api.post('/izleme/sezon', {
        'tmdb_id': widget.tmdbId,
        'sezon': _no,
        'bolum_sayisi': toplam,
        'isaretle': isaretle,
      });
      widget.degisti();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final toplam = (widget.sezon['episode_count'] as int?) ?? 0;
    final izlenen = widget.izlenenSet
        .where((k) => k.startsWith('$_no:'))
        .length
        .clamp(0, toplam);
    final tamam = toplam > 0 && izlenen >= toplam;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: toplam == 0 ? 0 : izlenen / toplam,
                    strokeWidth: 4,
                    color: DiziRenkler.kirmizi,
                    backgroundColor: Colors.white12,
                  ),
                  Text('$_no',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            title: Text(widget.sezon['name'] as String? ?? '$_no. Sezon',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('$izlenen / $toplam bölüm'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tamam)
                  const Icon(Icons.check_circle, color: DiziRenkler.kirmizi),
                Icon(_acik ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white38),
              ],
            ),
            onTap: () {
              setState(() => _acik = !_acik);
              if (_acik && _bolumler == null) _bolumleriYukle();
            },
          ),
          if (_acik) ...[
            if (_hata != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Text(_hata!, style: const TextStyle(color: Colors.white54)),
                  TextButton(
                      onPressed: _bolumleriYukle,
                      child: const Text('Tekrar dene')),
                ]),
              )
            else if (_bolumler == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                    child: CircularProgressIndicator(
                        color: DiziRenkler.kirmizi)),
              )
            else ...[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _tumu(!tamam, toplam),
                  icon: Icon(tamam ? Icons.remove_done : Icons.done_all,
                      size: 18, color: DiziRenkler.kirmizi),
                  label: Text(tamam ? 'Tümünü Kaldır' : 'Tümünü İzledim',
                      style: const TextStyle(
                          color: DiziRenkler.kirmizi, fontSize: 13)),
                ),
              ),
              for (final b in _bolumler!)
                _BolumSatiri(
                  tmdbId: widget.tmdbId,
                  sezonNo: _no,
                  bolum: b as Map<String, dynamic>,
                  izlendi: widget.izlenenSet
                      .contains('$_no:${b['episode_number']}'),
                  izlendiToggle: () =>
                      _toggle(b['episode_number'] as int),
                  degisti: widget.degisti,
                ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _BolumSatiri extends StatelessWidget {
  final int tmdbId;
  final int sezonNo;
  final Map<String, dynamic> bolum;
  final bool izlendi;
  final VoidCallback izlendiToggle;
  final VoidCallback degisti;

  const _BolumSatiri({
    required this.tmdbId,
    required this.sezonNo,
    required this.bolum,
    required this.izlendi,
    required this.izlendiToggle,
    required this.degisti,
  });

  @override
  Widget build(BuildContext context) {
    final no = bolum['episode_number'] as int;
    final gorsel = posterUrl(bolum['still_path'] as String?, boyut: 'w300');
    final tarih = bolum['air_date'] as String? ?? '';

    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BolumEkrani(
              tmdbId: tmdbId,
              sezonNo: sezonNo,
              bolumNo: no,
              izlendi: izlendi,
            ),
          ),
        );
        degisti();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 88,
                height: 50,
                child: gorsel == null
                    ? Container(
                        color: DiziRenkler.koyuGri,
                        child: const Icon(Icons.tv, color: Colors.white24))
                    : CachedNetworkImage(imageUrl: gorsel, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$no. ${bolum['name'] ?? 'Bölüm'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  if (tarih.isNotEmpty)
                    Text(tarih,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white38)),
                ],
              ),
            ),
            IconButton(
              onPressed: izlendiToggle,
              icon: Icon(
                izlendi ? Icons.check_circle : Icons.radio_button_unchecked,
                color: izlendi ? DiziRenkler.kirmizi : Colors.white24,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
