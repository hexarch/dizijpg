import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';

/// Dizi/film/kişi geneli veya tek bölüm (sezon+bolum) yorumları:
/// liste + fotoğraf/video ekli yorum yazma.
class YorumBolumu extends StatefulWidget {
  final String tur; // 'tv' | 'movie' | 'person'
  final int tmdbId;
  final int? sezon;
  final int? bolum;

  const YorumBolumu({
    super.key,
    required this.tur,
    required this.tmdbId,
    this.sezon,
    this.bolum,
  });

  @override
  State<YorumBolumu> createState() => _YorumBolumuState();
}

class _YorumBolumuState extends State<YorumBolumu> {
  List<dynamic>? _yorumlar;
  final _metin = TextEditingController();
  final List<Map<String, dynamic>> _ekler = []; // {yol, video}
  bool _ekYukleniyor = false;
  bool _gonderiliyor = false;
  Map<String, dynamic>? _yanitlanan; // yanıt modundaki üst yorum

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _metin.dispose();
    super.dispose();
  }

  String get _sorgu => widget.sezon != null
      ? '?sezon=${widget.sezon}&bolum=${widget.bolum}'
      : '';

  Future<void> _yukle() async {
    try {
      final d = await Api.get(
        '/yorumlar/${widget.tur}/${widget.tmdbId}$_sorgu',
      );
      if (mounted) {
        setState(() => _yorumlar = d['yorumlar'] as List<dynamic>);
      }
    } catch (_) {
      if (mounted) setState(() => _yorumlar = []);
    }
  }

  Future<void> _ekSec() async {
    if (_ekler.length >= 4) return;
    final secim = await ImagePicker().pickMedia();
    if (secim == null) return;
    setState(() => _ekYukleniyor = true);
    try {
      final veri = await secim.readAsBytes();
      if (veri.length > 30 * 1024 * 1024) {
        throw ApiHata('Dosya en fazla 30MB olabilir'.c);
      }
      final d = await Api.medyaYukle(veri);
      if (!mounted) return;
      setState(() => _ekler.add({'yol': d['yol'], 'video': d['video']}));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _ekYukleniyor = false);
    }
  }

  Future<void> _gonder() async {
    final metin = _metin.text.trim();
    if (metin.isEmpty) return;
    setState(() => _gonderiliyor = true);
    try {
      await Api.post('/yorumlar', {
        'tur': widget.tur,
        'tmdb_id': widget.tmdbId,
        if (widget.sezon != null) 'sezon': widget.sezon,
        if (widget.sezon != null) 'bolum': widget.bolum,
        'metin': metin,
        'medya': _ekler.map((e) => e['yol']).toList(),
        if (_yanitlanan != null) 'ust_id': _yanitlanan!['id'],
      });
      _metin.clear();
      _ekler.clear();
      _yanitlanan = null;
      await _yukle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  Future<void> _sil(int id) async {
    try {
      await Api.delete('/yorumlar/$id');
      _yukle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final benimId = context.watch<Oturum>().kullanici?['id'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              const Icon(
                Icons.chat_bubble_outline,
                size: 19,
                color: DiziRenkler.sari,
              ),
              const SizedBox(width: 7),
              Text(
                _yorumlar != null
                    ? 'Yorumlar ({})'.cf([_yorumlar!.length])
                    : 'Yorumlar'.c,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        // Yorum yazma kutusu
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_yanitlanan != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
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
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => setState(() => _yanitlanan = null),
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white38,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: _metin,
                  maxLines: 3,
                  minLines: 1,
                  maxLength: 1000,
                  buildCounter:
                      (
                        _, {
                        required currentLength,
                        maxLength,
                        required isFocused,
                      }) => null,
                  decoration: InputDecoration(
                    hintText: 'Yorumunu yaz...'.c,
                    border: InputBorder.none,
                  ),
                ),
                if (_ekler.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < _ekler.length; i++)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 72,
                                height: 72,
                                child: _ekler[i]['video'] == true
                                    ? Container(
                                        color: DiziRenkler.koyuGri,
                                        child: const Icon(
                                          Icons.videocam,
                                          color: Colors.white54,
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
                                onTap: () => setState(() => _ekler.removeAt(i)),
                                child: const CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Colors.black87,
                                  child: Icon(
                                    Icons.close,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _ekYukleniyor || _ekler.length >= 4
                          ? null
                          : _ekSec,
                      icon: _ekYukleniyor
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: DiziRenkler.sari,
                              ),
                            )
                          : const Icon(
                              Icons.attach_file,
                              color: DiziRenkler.sari,
                            ),
                      tooltip: 'Fotoğraf / video ekle'.c,
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _gonderiliyor ? null : _gonder,
                      child: _gonderiliyor
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text('Gönder'.c),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Yorum listesi
        if (_yorumlar == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(color: DiziRenkler.sari),
            ),
          )
        else if (_yorumlar!.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'İlk yorumu sen yaz!'.c,
              style: const TextStyle(color: Colors.white38),
            ),
          )
        else ...[
          for (final y in _yorumlar!.where((y) => y['ust_id'] == null))
            _YorumKarti(
              // Liste yenilenince state konuma göre değil yoruma göre eşleşsin
              key: ValueKey(y['id']),
              yorum: y as Map<String, dynamic>,
              benim: y['kullanici_id'] == benimId,
              benimId: benimId,
              sil: () => _sil(y['id'] as int),
              yanitla: (hedef) => setState(() => _yanitlanan = hedef),
              yanitSil: _sil,
              yanitlar:
                  (_yorumlar!.where((c) => c['ust_id'] == y['id']).toList()
                    ..sort(
                      (a, b) => (a['id'] as int).compareTo(b['id'] as int),
                    )),
            ),
        ],
      ],
    );
  }
}

class _YorumKarti extends StatefulWidget {
  final Map<String, dynamic> yorum;
  final bool benim;
  final Object? benimId;
  final VoidCallback sil;
  final void Function(Map<String, dynamic>) yanitla;
  final void Function(int) yanitSil;
  final List<dynamic> yanitlar;

  const _YorumKarti({
    super.key,
    required this.yorum,
    required this.benim,
    required this.benimId,
    required this.sil,
    required this.yanitla,
    required this.yanitSil,
    required this.yanitlar,
  });

  @override
  State<_YorumKarti> createState() => _YorumKartiState();
}

class _YorumKartiState extends State<_YorumKarti> {
  late bool _begendim = widget.yorum['begendim'] == true;
  late int _begeni = (widget.yorum['begeni'] as int?) ?? 0;
  bool _isleniyor = false;

  @override
  void didUpdateWidget(_YorumKarti eski) {
    super.didUpdateWidget(eski);
    if (eski.yorum != widget.yorum) {
      _begendim = widget.yorum['begendim'] == true;
      _begeni = (widget.yorum['begeni'] as int?) ?? 0;
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
      final d = await Api.yorumBegen(widget.yorum['id'] as int);
      if (mounted) {
        setState(() {
          _begendim = d['begendim'] as bool;
          _begeni = d['begeni'] as int;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _begendim = !_begendim;
          _begeni += _begendim ? 1 : -1;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final yorum = widget.yorum;
    final benim = widget.benim;
    final avatar = dosyaUrl(yorum['avatar'] as String?);
    final tarih = (yorum['tarih'] as String? ?? '').split('T').first;
    final medya = (yorum['medya'] as List<dynamic>? ?? []).cast<String>();
    final goruntulenme = (yorum['goruntulenme'] as int?) ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: DiziRenkler.koyuGri,
                  backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                  child: avatar == null
                      ? const Icon(
                          Icons.person,
                          size: 14,
                          color: Colors.white38,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () =>
                      context.push('/kullanici/${yorum['kullanici_adi']}'),
                  child: Text(
                    '@${yorum['kullanici_adi']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: DiziRenkler.sari,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  tarih,
                  style: const TextStyle(fontSize: 11, color: Colors.white38),
                ),
                const Spacer(),
                if (benim)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: widget.sil,
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.white38,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(yorum['metin'] as String, style: const TextStyle(height: 1.4)),
            if (medya.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in medya)
                    m.endsWith('.mp4') || m.endsWith('.webm')
                        ? VideoOynatici(url: dosyaUrl(m)!)
                        : InkWell(
                            onTap: () => showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                backgroundColor: Colors.transparent,
                                child: InteractiveViewer(
                                  child: CachedNetworkImage(
                                    imageUrl: dosyaUrl(m)!,
                                  ),
                                ),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: CachedNetworkImage(
                                imageUrl: dosyaUrl(m)!,
                                width: 140,
                                height: 140,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            // Görüntülenme + beğeni
            Row(
              children: [
                const Icon(
                  Icons.remove_red_eye,
                  size: 16,
                  color: Colors.white38,
                ),
                const SizedBox(width: 4),
                Text(
                  '$goruntulenme',
                  style: const TextStyle(fontSize: 12, color: Colors.white38),
                ),
                const SizedBox(width: 16),
                InkWell(
                  onTap: _begen,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _begendim ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: _begendim ? DiziRenkler.sari : Colors.white38,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$_begeni',
                          style: TextStyle(
                            fontSize: 12,
                            color: _begendim
                                ? DiziRenkler.sari
                                : Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                InkWell(
                  onTap: () => widget.yanitla(widget.yorum),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.reply,
                          size: 16,
                          color: Colors.white38,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Yanıtla'.c,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Yanıtlar (tek seviye)
            if (widget.yanitlar.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final c in widget.yanitlar)
                      _YanitSatiri(
                        key: ValueKey(c['id']),
                        yanit: c as Map<String, dynamic>,
                        benim: c['kullanici_id'] == widget.benimId,
                        sil: () => widget.yanitSil(c['id'] as int),
                        yanitla: () => widget.yanitla(c),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tıklayınca yüklenen ve oynayan basit video kutusu.
class VideoOynatici extends StatefulWidget {
  final String url;
  const VideoOynatici({super.key, required this.url});

  @override
  State<VideoOynatici> createState() => _VideoOynaticiState();
}

class _VideoOynaticiState extends State<VideoOynatici> {
  VideoPlayerController? _denetleyici;
  bool _yukleniyor = false;

  @override
  void dispose() {
    _denetleyici?.dispose();
    super.dispose();
  }

  Future<void> _baslat() async {
    setState(() => _yukleniyor = true);
    try {
      final d = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await d.initialize();
      if (!mounted) {
        d.dispose();
        return;
      }
      setState(() {
        _denetleyici = d;
        _yukleniyor = false;
      });
      d.play();
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _denetleyici;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 220,
        height: 124,
        child: d == null
            ? InkWell(
                onTap: _yukleniyor ? null : _baslat,
                child: Container(
                  color: DiziRenkler.koyuGri,
                  child: Center(
                    child: _yukleniyor
                        ? const CircularProgressIndicator(
                            color: DiziRenkler.sari,
                          )
                        : const Icon(
                            Icons.play_circle_outline,
                            size: 44,
                            color: Colors.white70,
                          ),
                  ),
                ),
              )
            : InkWell(
                onTap: () =>
                    setState(() => d.value.isPlaying ? d.pause() : d.play()),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: d.value.size.width,
                        height: d.value.size.height,
                        child: VideoPlayer(d),
                      ),
                    ),
                    if (!d.value.isPlaying)
                      const Icon(
                        Icons.play_circle_outline,
                        size: 44,
                        color: Colors.white70,
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Tek yanıt satırı: küçük avatar + metin + beğeni; kendi yanıtını silebilir.
class _YanitSatiri extends StatefulWidget {
  final Map<String, dynamic> yanit;
  final bool benim;
  final VoidCallback sil;
  final VoidCallback yanitla;

  const _YanitSatiri({
    super.key,
    required this.yanit,
    required this.benim,
    required this.sil,
    required this.yanitla,
  });

  @override
  State<_YanitSatiri> createState() => _YanitSatiriState();
}

class _YanitSatiriState extends State<_YanitSatiri> {
  late bool _begendim = widget.yanit['begendim'] == true;
  late int _begeni = (widget.yanit['begeni'] as int?) ?? 0;
  bool _isleniyor = false;

  @override
  void didUpdateWidget(_YanitSatiri eski) {
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
      if (mounted) {
        setState(() {
          _begendim = !_begendim;
          _begeni += _begendim ? 1 : -1;
        });
      }
    } finally {
      if (mounted) _isleniyor = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final y = widget.yanit;
    final avatar = dosyaUrl(y['avatar'] as String?);
    final tarih = (y['tarih'] as String? ?? '').split('T').first;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: DiziRenkler.koyuGri,
                backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                child: avatar == null
                    ? const Icon(Icons.person, size: 11, color: Colors.white38)
                    : null,
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => context.push('/kullanici/${y['kullanici_adi']}'),
                child: Text(
                  '@${y['kullanici_adi']}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: DiziRenkler.sari,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                tarih,
                style: const TextStyle(fontSize: 10, color: Colors.white38),
              ),
              const Spacer(),
              // Dokunma hedefleri 44px'e yakın olsun diye geniş padding
              InkWell(
                onTap: _begen,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _begendim ? Icons.favorite : Icons.favorite_border,
                        size: 15,
                        color: _begendim ? DiziRenkler.sari : Colors.white38,
                      ),
                      if (_begeni > 0) ...[
                        const SizedBox(width: 3),
                        Text(
                          '$_begeni',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
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
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Icon(Icons.reply, size: 15, color: Colors.white38),
                ),
              ),
              if (widget.benim)
                InkWell(
                  onTap: widget.sil,
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Icon(
                      Icons.delete_outline,
                      size: 15,
                      color: Colors.white38,
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 26, top: 2),
            child: Text(
              y['metin'] as String? ?? '',
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
