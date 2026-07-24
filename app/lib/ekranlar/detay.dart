import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'ortak.dart';
import 'puan_sheet.dart';
import 'tepki.dart';
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
  Map<String, dynamic>? _izleyenler;
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
      // İzleyen sayısı sayfayı bloke etmesin: ayrı ve sessizce yüklenir
      Api.get('/izleyenler/${widget.tur}/${widget.tmdbId}')
          .then((d) {
            if (mounted) {
              setState(() => _izleyenler = d as Map<String, dynamic>);
            }
          })
          .catchError((_) {});
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

  /// Mutasyonu çalıştırır; hata olursa SnackBar gösterir.
  Future<void> _mutasyon(Future<void> Function() istek) async {
    try {
      await istek();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
    _benimYenile();
  }

  Future<void> _durumSec(String? durum) => _mutasyon(
    () => Api.post('/durum', {
      'tmdb_id': widget.tmdbId,
      'tur': widget.tur,
      'durum': durum ?? '',
    }),
  );

  /// İzleyenler listesi: avatar + kullanıcı adı, dokununca profile gider.
  void _izleyenlerAc() {
    final liste = (_izleyenler?['kullanicilar'] as List<dynamic>? ?? []);
    if (liste.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DiziRenkler.koyuGri,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.visibility_outlined,
                    color: DiziRenkler.sari,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'İzleyenler'.c,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_izleyenler?['sayi'] ?? liste.length}',
                    style: TextStyle(color: DiziRenkler.metin54),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: liste.length,
                itemBuilder: (context, i) {
                  final k = liste[i] as Map<String, dynamic>;
                  final av = dosyaUrl(k['avatar'] as String?);
                  final ad = k['kullanici_adi'] as String;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: DiziRenkler.kart,
                      backgroundImage: av != null ? NetworkImage(av) : null,
                      child: av == null
                          ? Icon(Icons.person, color: DiziRenkler.metin38)
                          : null,
                    ),
                    title: Text('@$ad'),
                    onTap: () {
                      // Yönlendiriciyi modal kapanmadan ÖNCE al: kapanan
                      // modalın context'i ölür, onunla push çalışmaz.
                      final yonlendirici = GoRouter.of(context);
                      Navigator.pop(context);
                      yonlendirici.push('/kullanici/$ad');
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _favoriToggle() => _mutasyon(
    () => Api.post('/favori/toggle', {
      'tmdb_id': widget.tmdbId,
      'tur': widget.tur,
    }),
  );

  Future<void> _filmIzlendiToggle() => _mutasyon(
    () => Api.post('/izleme/toggle', {
      'tmdb_id': widget.tmdbId,
      'tur': 'movie',
      'sezon': 0,
      'bolum': 0,
    }),
  );

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
        final inc = await Api.get(
          '/incelemeler/${widget.tur}/${widget.tmdbId}',
        );
        if (mounted) setState(() => _incelemeler = inc as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  /// Tüm izleme izlerini siler: hiç izlenmemiş sayılır + listelerden kalkar.
  Future<void> _sifirla() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DiziRenkler.koyuGri,
        title: Text('Sil'.c),
        content: Text(
          'Bu içerik hiç izlenmemiş olarak işaretlenecek ve listelerinden kaldırılacak.'
              .c,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal'.c),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sil'.c),
          ),
        ],
      ),
    );
    if (onay != true) return;
    try {
      await Api.post('/icerik/sifirla', {
        'tmdb_id': widget.tmdbId,
        'tur': widget.tur,
      });
      if (!mounted) return;
      _yukle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Listeye Ekle'.c,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (listeler.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Henüz listen yok — Profil sekmesinden oluştur.'.c,
                  ),
                ),
              for (final l in listeler)
                ListTile(
                  leading: const Icon(
                    Icons.playlist_add,
                    color: DiziRenkler.sari,
                  ),
                  title: Text(l['ad'] as String),
                  subtitle: Text('{} içerik'.cf([l['oge_sayisi']])),
                  onTap: () async {
                    try {
                      await Api.post('/listeler/${l['id']}/oge', {
                        'tmdb_id': widget.tmdbId,
                        'tur': widget.tur,
                      });
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Listeye eklendi'.c)),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
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
    if (_icerik == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: DiziRenkler.sari)),
      );
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
    final oneriler =
        ((c['recommendations']?['results'] as List<dynamic>?) ?? []);
    final sezonlar = ((c['seasons'] as List<dynamic>?) ?? [])
        .where((s) => (s['season_number'] as int) > 0)
        .toList();
    final izlenenSet = {
      for (final r in (_benim?['izlenenler'] as List<dynamic>? ?? []))
        '${r['sezon']}:${r['bolum']}',
    };
    final filmIzlendi = !tv && izlenenSet.contains('0:0');
    final favori = _benim?['favori'] == true;
    final benimDurum = _benim?['durum'] as String?;
    final benimPuan = _benim?['puan']?['puan'] as int?;
    // Gelecek bölüm: tarih belliyse kaç gün kaldığını göster
    final sonrakiTarih = tv
        ? ((c['next_episode_to_air'] as Map<String, dynamic>?)?['air_date']
              as String?)
        : null;
    int? kalanGun;
    if (sonrakiTarih != null) {
      final simdi = DateTime.now();
      kalanGun = DateTime.parse(
        sonrakiTarih,
      ).difference(DateTime(simdi.year, simdi.month, simdi.day)).inDays;
    }

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
                          decoration: BoxDecoration(
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
                  Text(
                    ad,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (yil.isNotEmpty) yil,
                      if (tv) '{} sezon'.cf([c['number_of_seasons']]),
                      if (turler.isNotEmpty) turler,
                    ].join(' · '),
                    style: TextStyle(color: DiziRenkler.metin54),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 6,
                    children: [
                      const Icon(Icons.star, color: DiziRenkler.sari, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '{} TMDB'.cf([
                          ((c['vote_average'] as num?) ?? 0).toStringAsFixed(1),
                        ]),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (_incelemeler?['ortalama'] != null) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: DiziRenkler.sari,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '{} dizi.jpg'.cf([
                              ((num.tryParse('${_incelemeler!['ortalama']}') ??
                                          0) /
                                      2)
                                  .toStringAsFixed(1),
                            ]),
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      // Uygulamada kaç kişi izledi — dokununca liste açılır
                      if ((_izleyenler?['sayi'] as num? ?? 0) > 0) ...[
                        const SizedBox(width: 12),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: _izleyenlerAc,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.visibility_outlined,
                                  size: 18,
                                  color: DiziRenkler.metin70,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_izleyenler!['sayi']}',
                                  style: TextStyle(
                                    color: DiziRenkler.metin70,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Durum çipleri: dar ekranda sağa taşmak yerine alt satıra sarar
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (kod, etiket, ikon) in durumSecenekleri)
                        FilterChip(
                          avatar: Icon(
                            ikon,
                            size: 16,
                            color: benimDurum == kod
                                ? Colors.black
                                : DiziRenkler.metin70,
                          ),
                          label: Text(
                            etiket.c,
                            style: TextStyle(
                              color: benimDurum == kod
                                  ? Colors.black
                                  : DiziRenkler.metin,
                            ),
                          ),
                          selected: benimDurum == kod,
                          onSelected: (s) => _durumSec(s ? kod : null),
                        ),
                      // Sil: tüm izleme izini kaldırır (uyarılı)
                      if (benimDurum != null || izlenenSet.isNotEmpty)
                        ActionChip(
                          avatar: const Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: Colors.redAccent,
                          ),
                          label: Text(
                            'Sil'.c,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                          onPressed: _sifirla,
                        ),
                    ],
                  ),
                  // Gelecek bölüm geri sayımı
                  if (kalanGun != null && kalanGun >= 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 16,
                          color: DiziRenkler.sari,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          kalanGun == 0
                              ? 'Gelecek bölüm bugün'.c
                              : 'Gelecek bölüm {} gün sonra'.cf([kalanGun]),
                          style: const TextStyle(
                            color: DiziRenkler.sari,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          sonrakiTarih!,
                          style: TextStyle(
                            color: DiziRenkler.metin38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
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
                                    foregroundColor: DiziRenkler.sari,
                                  )
                                : null,
                            icon: Icon(
                              filmIzlendi
                                  ? Icons.check_circle
                                  : Icons.visibility,
                            ),
                            label: Text(
                              filmIzlendi ? 'İzledin'.c : 'İzledim'.c,
                            ),
                          ),
                        ),
                      if (!tv) const SizedBox(width: 8),
                      IconButton(
                        onPressed: _favoriToggle,
                        tooltip: 'Favori'.c,
                        icon: Icon(
                          favori ? Icons.favorite : Icons.favorite_border,
                          color: favori ? Colors.redAccent : DiziRenkler.metin,
                        ),
                      ),
                      IconButton(
                        onPressed: _puanla,
                        tooltip: 'Puanla'.c,
                        icon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              benimPuan != null
                                  ? Icons.star
                                  : Icons.star_border,
                              color: DiziRenkler.sari,
                            ),
                            if (benimPuan != null)
                              Text(
                                ' ${(benimPuan / 2).round()}',
                                style: const TextStyle(
                                  color: DiziRenkler.sari,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _listeyeEkle,
                        tooltip: 'Listeye ekle'.c,
                        icon: Icon(
                          Icons.playlist_add,
                          color: DiziRenkler.metin,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Tepki ikonları
                  TepkiSatiri(tur: widget.tur, tmdbId: widget.tmdbId),
                  const SizedBox(height: 12),
                  if ((c['overview'] as String?)?.isNotEmpty == true)
                    Text(
                      c['overview'] as String,
                      style: const TextStyle(height: 1.5),
                    ),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Sezonlar'.c,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: Text(
                      'Oyuncular'.c,
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
                      itemCount: kadro.length.clamp(0, 20),
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final o = kadro[i] as Map<String, dynamic>;
                        final foto = posterUrl(
                          o['profile_path'] as String?,
                          boyut: 'w185',
                        );
                        return InkWell(
                          onTap: () => context.push('/kisi/${o['id']}'),
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
                                      ? Icon(
                                          Icons.person,
                                          color: DiziRenkler.metin24,
                                        )
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
              ),
            ),
          // İncelemeler
          if ((_incelemeler?['incelemeler'] as List<dynamic>? ?? []).isNotEmpty)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      'İncelemeler'.c,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  for (final inc
                      in (_incelemeler!['incelemeler'] as List<dynamic>).take(
                        10,
                      ))
                    Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                InkWell(
                                  onTap: () => context.push(
                                    '/kullanici/${inc['kullanici_adi']}',
                                  ),
                                  child: Text(
                                    '@${inc['kullanici_adi']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: DiziRenkler.sari,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                const Icon(
                                  Icons.star,
                                  color: DiziRenkler.sari,
                                  size: 14,
                                ),
                                Text(
                                  ' ${(((inc['puan'] as num?) ?? 0) / 2).round()}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              inc['yorum'] as String,
                              style: const TextStyle(height: 1.4),
                            ),
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
                baslik: 'Bunları da Beğenebilirsin'.c,
                icerikler: oneriler,
                turZorla: widget.tur,
              ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
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
                    color: DiziRenkler.sari,
                    backgroundColor: DiziRenkler.metin12,
                  ),
                  Text(
                    '$_no',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            title: Text(
              widget.sezon['name'] as String? ?? '{}. Sezon'.cf([_no]),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('{} / {} bölüm'.cf([izlenen, toplam])),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tamam)
                  const Icon(Icons.check_circle, color: DiziRenkler.sari),
                Icon(
                  _acik ? Icons.expand_less : Icons.expand_more,
                  color: DiziRenkler.metin38,
                ),
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
                child: Column(
                  children: [
                    Text(_hata!, style: TextStyle(color: DiziRenkler.metin54)),
                    TextButton(
                      onPressed: _bolumleriYukle,
                      child: Text('Tekrar dene'.c),
                    ),
                  ],
                ),
              )
            else if (_bolumler == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(color: DiziRenkler.sari),
                ),
              )
            else ...[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _tumu(!tamam, toplam),
                  icon: Icon(
                    tamam ? Icons.remove_done : Icons.done_all,
                    size: 18,
                    color: DiziRenkler.sari,
                  ),
                  label: Text(
                    tamam ? 'Tümünü Kaldır'.c : 'Tümünü İzledim'.c,
                    style: const TextStyle(
                      color: DiziRenkler.sari,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              for (final b in _bolumler!)
                _BolumSatiri(
                  tmdbId: widget.tmdbId,
                  sezonNo: _no,
                  bolum: b as Map<String, dynamic>,
                  izlendi: widget.izlenenSet.contains(
                    '$_no:${b['episode_number']}',
                  ),
                  izlendiToggle: () => _toggle(b['episode_number'] as int),
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
        await context.push(
          '/dizi/$tmdbId/sezon/$sezonNo/bolum/$no',
          extra: izlendi,
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
                        child: Icon(Icons.tv, color: DiziRenkler.metin24),
                      )
                    : CachedNetworkImage(imageUrl: gorsel, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$no. ${bolum['name'] ?? 'Bölüm'.c}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  if (tarih.isNotEmpty)
                    Text(
                      tarih,
                      style: TextStyle(
                        fontSize: 11,
                        color: DiziRenkler.metin38,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: izlendiToggle,
              icon: Icon(
                izlendi ? Icons.check_circle : Icons.radio_button_unchecked,
                color: izlendi ? DiziRenkler.sari : DiziRenkler.metin24,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
