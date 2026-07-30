import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'etiket.dart';
import 'ortak.dart';

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
  bool _yorumHatasi = false; // yükleme başarısız mı (boş ≠ hata)
  final _metin = TextEditingController();
  final _odak = FocusNode(); // Yanıtla → kutuya odaklan
  final _kutuKey = GlobalKey(); // Yanıtla → kutuya kaydır
  final List<Map<String, dynamic>> _ekler = []; // {yol, video}
  bool _ekYukleniyor = false;
  bool _gonderiliyor = false;
  bool _spoiler = false; // "spoiler içerir" işareti
  Map<String, dynamic>? _yanitlanan; // yanıt modundaki üst yorum

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _metin.dispose();
    _odak.dispose();
    super.dispose();
  }

  /// Yanıtla: yazma kutusunu yanıtlanana ayarla, kutuya kaydır ve klavyeyi aç
  /// (kutu ekranın üstünde olduğundan kullanıcı "bir şey olmadı" sanmasın).
  void _yanitla(Map<String, dynamic> hedef) {
    setState(() => _yanitlanan = hedef);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _kutuKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          alignment: 0.1,
        );
      }
      _odak.requestFocus();
    });
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
        setState(() {
          _yorumlar = d['yorumlar'] as List<dynamic>;
          _yorumHatasi = false;
        });
      }
    } catch (_) {
      // Hata boş durumla karışmasın: ayrı bayrak, "tekrar dene" göster
      if (mounted) setState(() => _yorumHatasi = true);
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
        'spoiler': _spoiler,
        if (_yanitlanan != null) 'ust_id': _yanitlanan!['id'],
      });
      _metin.clear();
      _ekler.clear();
      _yanitlanan = null;
      _spoiler = false;
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
              Icon(
                Icons.chat_bubble_outline,
                size: 19,
                color: DiziRenkler.sariMetin,
              ),
              const SizedBox(width: 7),
              Text(
                _yorumlar != null
                    // Yalnız üst yorumları say (yanıtlar hariç): görünen sayı
                    // listedeki üst yorum sayısıyla tutarlı olsun.
                    ? 'Yorumlar ({})'.cf([
                        _yorumlar!.where((y) => y['ust_id'] == null).length,
                      ])
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
          key: _kutuKey,
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
                        Icon(
                          Icons.reply,
                          size: 16,
                          color: DiziRenkler.sariMetin,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '@{} kullanıcısına yanıt veriyorsun'.cf([
                              _yanitlanan!['kullanici_adi'],
                            ]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: DiziRenkler.sariMetin,
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => setState(() => _yanitlanan = null),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: DiziRenkler.metin38,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                EtiketliGirdi(
                  controller: _metin,
                  focusNode: _odak,
                  maxLines: 3,
                  minLines: 1,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    hintText: 'Yorumunu yaz... (@ ile etiketle)'.c,
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
                                        child: Icon(
                                          Icons.videocam,
                                          color: DiziRenkler.metin54,
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
                                borderRadius: BorderRadius.circular(20),
                                // Görünmez padding: rozet küçük kalır ama
                                // dokunma alanı 40px olur (20 avatar + 2×10)
                                child: const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircleAvatar(
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
                          : Icon(
                              Icons.attach_file,
                              color: DiziRenkler.sariMetin,
                            ),
                      tooltip: 'Fotoğraf / video ekle'.c,
                    ),
                    // Spoiler işareti: yorumu bulanık gönderir
                    InkWell(
                      onTap: () => setState(() => _spoiler = !_spoiler),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _spoiler
                                  ? Icons.visibility_off
                                  : Icons.visibility_off_outlined,
                              size: 20,
                              color: _spoiler
                                  ? DiziRenkler.sariMetin
                                  : DiziRenkler.metin54,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Spoiler'.c,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _spoiler
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: _spoiler
                                    ? DiziRenkler.sariMetin
                                    : DiziRenkler.metin54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _gonderiliyor ? null : _gonder,
                      child: _gonderiliyor
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: DiziRenkler.metin,
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
        if (_yorumHatasi && _yorumlar == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 18, color: DiziRenkler.metin38),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Yorumlar yüklenemedi'.c,
                    style: TextStyle(color: DiziRenkler.metin54),
                  ),
                ),
                TextButton(onPressed: _yukle, child: Text('Tekrar dene'.c)),
              ],
            ),
          )
        else if (_yorumlar == null)
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
              style: TextStyle(color: DiziRenkler.metin38),
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
              yanitla: _yanitla,
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
                      ? Icon(Icons.person, size: 14, color: DiziRenkler.metin38)
                      : null,
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () =>
                      kullaniciyaGit(context, yorum['kullanici_adi'] as String),
                  child: Text(
                    '@${yorum['kullanici_adi']}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: DiziRenkler.sariMetin,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  tarih,
                  style: TextStyle(fontSize: 11, color: DiziRenkler.metin38),
                ),
                const Spacer(),
                if (benim)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: widget.sil,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: DiziRenkler.metin38,
                      ),
                    ),
                  )
                else if (widget.benimId != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () =>
                        sikayetEtSheet(context, 'yorum', yorum['id'] as int),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        Icons.flag_outlined,
                        size: 18,
                        color: DiziRenkler.metin38,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            CeviriliMetin(
              yorumId: yorum['id'] as int,
              metin: yorum['metin'] as String? ?? '',
              kaynakDil: yorum['kaynak_dil'] as String?,
              ceviriVar: yorum['ceviri_var'] == true,
              yapici: (m) => SpoilerMetin(
                m,
                spoiler: yorum['spoiler'] == true,
                stil: TextStyle(height: 1.4, color: DiziRenkler.metin),
              ),
            ),
            if (medya.isNotEmpty) ...[
              const SizedBox(height: 10),
              // Tek medya tam genişlik büyük, çoklu 2 sütun ızgara; dokununca
              // tam ekran (fotoğrafta yakınlaştırma, videoda oynatma + sarma).
              MedyaGaleri(yollar: medya.cast<String>()),
            ],
            const SizedBox(height: 8),
            // Görüntülenme + beğeni
            Row(
              children: [
                Icon(
                  Icons.remove_red_eye,
                  size: 16,
                  color: DiziRenkler.metin38,
                ),
                const SizedBox(width: 4),
                Text(
                  '$goruntulenme',
                  style: TextStyle(fontSize: 12, color: DiziRenkler.metin38),
                ),
                const SizedBox(width: 16),
                InkWell(
                  onTap: _begen,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _begendim ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: _begendim
                              ? DiziRenkler.sariMetin
                              : DiziRenkler.metin38,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$_begeni',
                          style: TextStyle(
                            fontSize: 12,
                            color: _begendim
                                ? DiziRenkler.sariMetin
                                : DiziRenkler.metin38,
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
                      horizontal: 8,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.reply, size: 16, color: DiziRenkler.metin38),
                        const SizedBox(width: 4),
                        Text(
                          'Yanıtla'.c,
                          style: TextStyle(
                            fontSize: 12,
                            color: DiziRenkler.metin38,
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

/// Spoiler işaretli yorum metni: kapalıyken "Spoiler — dokun ve gör" örtüsü,
/// dokununca açılıp [EtiketliMetin] olarak gösterir. İşaretsizse doğrudan metin.
class SpoilerMetin extends StatefulWidget {
  final String metin;
  final bool spoiler;
  final TextStyle? stil;
  const SpoilerMetin(this.metin, {super.key, required this.spoiler, this.stil});

  @override
  State<SpoilerMetin> createState() => _SpoilerMetinState();
}

class _SpoilerMetinState extends State<SpoilerMetin> {
  bool _acik = false;

  @override
  void didUpdateWidget(SpoilerMetin eski) {
    super.didUpdateWidget(eski);
    // Liste yenilenip farklı yoruma denk gelirse kapalıya dön
    if (eski.metin != widget.metin) _acik = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.spoiler || _acik) {
      return EtiketliMetin(widget.metin, stil: widget.stil);
    }
    return InkWell(
      onTap: () => setState(() => _acik = true),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: DiziRenkler.koyuGri,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: DiziRenkler.metin12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.visibility_off_outlined,
              size: 18,
              color: DiziRenkler.metin54,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Spoiler — dokun ve gör'.c,
                style: TextStyle(
                  color: DiziRenkler.metin54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tıklayınca yüklenen ve oynayan basit video kutusu.
/// [tamEkran] verilirse sağ üstte tam ekran düğmesi görünür.
class VideoOynatici extends StatefulWidget {
  final String url;
  final VoidCallback? tamEkran;
  const VideoOynatici({super.key, required this.url, this.tamEkran});

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
                        : Icon(
                            Icons.play_circle_outline,
                            size: 44,
                            color: DiziRenkler.metin70,
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
                    if (widget.tamEkran != null)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: IconButton(
                          tooltip: 'Tam ekran'.c,
                          // Tam ekrana geçerken yerindeki videoyu DURDUR —
                          // aksi halde iki oynatıcı aynı anda çalıp çift ses verir.
                          onPressed: () {
                            _denetleyici?.pause();
                            widget.tamEkran!();
                          },
                          icon: const Icon(
                            Icons.fullscreen,
                            size: 20,
                            color: Colors.white,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black38,
                          ),
                        ),
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
                    ? Icon(Icons.person, size: 11, color: DiziRenkler.metin38)
                    : null,
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () =>
                    kullaniciyaGit(context, y['kullanici_adi'] as String),
                child: Text(
                  '@${y['kullanici_adi']}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: DiziRenkler.sariMetin,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                tarih,
                style: TextStyle(fontSize: 10, color: DiziRenkler.metin38),
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
                        color: _begendim
                            ? DiziRenkler.sariMetin
                            : DiziRenkler.metin38,
                      ),
                      if (_begeni > 0) ...[
                        const SizedBox(width: 3),
                        Text(
                          '$_begeni',
                          style: TextStyle(
                            fontSize: 11,
                            color: DiziRenkler.metin38,
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: Icon(
                    Icons.reply,
                    size: 15,
                    color: DiziRenkler.metin38,
                  ),
                ),
              ),
              if (widget.benim)
                InkWell(
                  onTap: widget.sil,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      size: 15,
                      color: DiziRenkler.metin38,
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 26, top: 2),
            child: SpoilerMetin(
              y['metin'] as String? ?? '',
              spoiler: y['spoiler'] == true,
              stil: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: DiziRenkler.metin,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
