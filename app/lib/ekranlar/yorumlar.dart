import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../api.dart';
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
      final d =
          await Api.get('/yorumlar/${widget.tur}/${widget.tmdbId}$_sorgu');
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
        throw ApiHata('Dosya en fazla 30MB olabilir');
      }
      final d = await Api.medyaYukle(veri);
      if (!mounted) return;
      setState(() => _ekler.add({'yol': d['yol'], 'video': d['video']}));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
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
      });
      _metin.clear();
      _ekler.clear();
      await _yukle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
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
          child: Text(
            '💬 Yorumlar${_yorumlar != null ? ' (${_yorumlar!.length})' : ''}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
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
                TextField(
                  controller: _metin,
                  maxLines: 3,
                  minLines: 1,
                  maxLength: 1000,
                  buildCounter: (_, {required currentLength, maxLength, required isFocused}) =>
                      null,
                  decoration: const InputDecoration(
                      hintText: 'Yorumunu yaz...', border: InputBorder.none),
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
                                        child: const Icon(Icons.videocam,
                                            color: Colors.white54))
                                    : CachedNetworkImage(
                                        imageUrl: dosyaUrl(
                                            _ekler[i]['yol'] as String)!,
                                        fit: BoxFit.cover),
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
                                  child: Icon(Icons.close,
                                      size: 13, color: Colors.white),
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
                      onPressed:
                          _ekYukleniyor || _ekler.length >= 4 ? null : _ekSec,
                      icon: _ekYukleniyor
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: DiziRenkler.kirmizi))
                          : const Icon(Icons.attach_file,
                              color: DiziRenkler.kirmizi),
                      tooltip: 'Fotoğraf / video ekle',
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _gonderiliyor ? null : _gonder,
                      child: _gonderiliyor
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Gönder'),
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
                child: CircularProgressIndicator(color: DiziRenkler.kirmizi)),
          )
        else if (_yorumlar!.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('İlk yorumu sen yaz!',
                style: TextStyle(color: Colors.white38)),
          )
        else
          for (final y in _yorumlar!)
            _YorumKarti(
              yorum: y as Map<String, dynamic>,
              benim: y['kullanici_id'] == benimId,
              sil: () => _sil(y['id'] as int),
            ),
      ],
    );
  }
}

class _YorumKarti extends StatelessWidget {
  final Map<String, dynamic> yorum;
  final bool benim;
  final VoidCallback sil;

  const _YorumKarti(
      {required this.yorum, required this.benim, required this.sil});

  @override
  Widget build(BuildContext context) {
    final avatar = dosyaUrl(yorum['avatar'] as String?);
    final tarih = (yorum['tarih'] as String? ?? '').split('T').first;
    final medya = (yorum['medya'] as List<dynamic>? ?? []).cast<String>();

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
                  backgroundImage:
                      avatar != null ? NetworkImage(avatar) : null,
                  child: avatar == null
                      ? const Icon(Icons.person,
                          size: 14, color: Colors.white38)
                      : null,
                ),
                const SizedBox(width: 8),
                Text('@${yorum['kullanici_adi']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: DiziRenkler.kirmizi)),
                const SizedBox(width: 8),
                Text(tarih,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.white38)),
                const Spacer(),
                if (benim)
                  InkWell(
                    onTap: sil,
                    child: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.white38),
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
                                      imageUrl: dosyaUrl(m)!),
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
                            color: DiziRenkler.kirmizi)
                        : const Icon(Icons.play_circle_outline,
                            size: 44, color: Colors.white70),
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
                      const Icon(Icons.play_circle_outline,
                          size: 44, color: Colors.white70),
                  ],
                ),
              ),
      ),
    );
  }
}
