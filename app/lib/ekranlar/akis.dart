import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
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

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _yukle();
    _kaydirma.addListener(() {
      if (_kaydirma.position.pixels >
          _kaydirma.position.maxScrollExtent - 400) {
        _devamYukle();
      }
    });
  }

  @override
  void dispose() {
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
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
      govde = RefreshIndicator(
        color: DiziRenkler.sari,
        onRefresh: _yukle,
        child: ListView.builder(
          controller: _kaydirma,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          itemCount: _akis!.length,
          itemBuilder: (context, i) => _AkisKarti(
            key: ValueKey((_akis![i] as Map<String, dynamic>)['id']),
            yorum: _akis![i] as Map<String, dynamic>,
            icerikler: _icerikler,
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
          // Kullanıcı arama: tıklayınca arama sayfasına gider
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push('/kisi-ara'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: DiziRenkler.kart,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_search,
                      color: DiziRenkler.metin38,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Kullanıcı adı ara...'.c,
                      style: TextStyle(color: DiziRenkler.metin38),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: govde),
        ],
      ),
    );
  }
}

class _AkisKarti extends StatefulWidget {
  final Map<String, dynamic> yorum;
  final Map<String, dynamic> icerikler;

  const _AkisKarti({super.key, required this.yorum, required this.icerikler});

  @override
  State<_AkisKarti> createState() => _AkisKartiState();
}

class _AkisKartiState extends State<_AkisKarti> {
  late bool _begendim = widget.yorum['begendim'] == true;
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
        : '/icerik/${y['tur']}/${y['tmdb_id']}';
    final tarih = (y['tarih'] as String? ?? '').split('T').first;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst satır: kullanıcı + içerik
            Row(
              children: [
                InkWell(
                  onTap: () => context.push('/kullanici/${y['kullanici_adi']}'),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: DiziRenkler.koyuGri,
                    backgroundImage: avatar != null
                        ? NetworkImage(avatar)
                        : null,
                    child: avatar == null
                        ? Icon(
                            Icons.person,
                            size: 18,
                            color: DiziRenkler.metin38,
                          )
                        : null,
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
                          '${bolumlu ? ' · S${y['sezon']}B${y['bolum']}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: DiziRenkler.sari,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
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
            const SizedBox(height: 10),
            Text(
              (y['metin'] as String?) ?? '',
              style: const TextStyle(height: 1.45),
            ),
            if (medya.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: medya.length,
                  separatorBuilder: (context, i) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final m = medya[i] as String;
                    final video = m.endsWith('.mp4') || m.endsWith('.webm');
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 130,
                        child: video
                            ? Container(
                                color: DiziRenkler.koyuGri,
                                child: Icon(
                                  Icons.play_circle_outline,
                                  color: DiziRenkler.metin54,
                                  size: 34,
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: dosyaUrl(m)!,
                                fit: BoxFit.cover,
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
            // Alt satır: beğeni + görüntülenme + tarih
            Row(
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
                              ? DiziRenkler.sari
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
          ],
        ),
      ),
    );
  }
}
