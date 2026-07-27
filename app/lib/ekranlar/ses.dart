import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../ceviri.dart';

// ---------------------------------------------------------------------------
// Ses dalgası (waveform) kodlama
//
// Kayıt sırasında mikrofon genliği örneklenir, gönderirken 40 kovaya indirilip
// "<saniye>:<40 karakter>" biçiminde mesajla birlikte saklanır. Her karakter
// 0-31 arası bir şiddet (0-9a-v). Böylece karşı taraf çubukları GERÇEK ses
// şiddetiyle çizer; dosyayı çözmeye gerek kalmaz.
// ---------------------------------------------------------------------------

const String _alfabe = '0123456789abcdefghijklmnopqrstuv';

/// Oynatıcıda/kayıt çubuğunda gösterilen çubuk sayısı.
const int dalgaOrnekSayisi = 40;

/// Ham genlik listesini (0..1) 40 kovaya indirip kodlar. Boşsa boş dize döner.
String dalgaKodla(List<double> seviyeler, int saniye) {
  if (seviyeler.isEmpty) return '';
  final tampon = StringBuffer('${saniye.clamp(0, 999)}:');
  for (var i = 0; i < dalgaOrnekSayisi; i++) {
    final bas = (i * seviyeler.length / dalgaOrnekSayisi).floor();
    final son = ((i + 1) * seviyeler.length / dalgaOrnekSayisi).ceil().clamp(
      bas + 1,
      seviyeler.length,
    );
    var tepe = 0.0;
    for (var j = bas; j < son; j++) {
      if (seviyeler[j] > tepe) tepe = seviyeler[j];
    }
    tampon.write(_alfabe[(tepe.clamp(0.0, 1.0) * 31).round()]);
  }
  return tampon.toString();
}

/// Kodlanmış dalgayı çözer. Bozuk/eksik veride null döner (eski mesajlar).
({int saniye, List<double> seviyeler})? dalgaCoz(String? kod) {
  if (kod == null || kod.isEmpty) return null;
  final ayrac = kod.indexOf(':');
  if (ayrac <= 0) return null;
  final saniye = int.tryParse(kod.substring(0, ayrac));
  if (saniye == null) return null;
  final seviyeler = <double>[];
  for (final harf in kod.substring(ayrac + 1).split('')) {
    final v = _alfabe.indexOf(harf);
    if (v < 0) return null;
    seviyeler.add(v / 31);
  }
  if (seviyeler.isEmpty) return null;
  return (saniye: saniye, seviyeler: seviyeler);
}

/// Genlik (dBFS, sessizlik ≈ -45 ve altı) → 0..1 çubuk yüksekliği.
double genlikNormalle(double dbfs) => ((dbfs + 45) / 45).clamp(0.0, 1.0);

// ---------------------------------------------------------------------------
// Çizim
// ---------------------------------------------------------------------------

class _DalgaCizer extends CustomPainter {
  final List<double> seviyeler; // 0..1
  final double oran; // çalınmış kısım (0..1)
  final Color renk;

  _DalgaCizer({
    required this.seviyeler,
    required this.oran,
    required this.renk,
  });

  @override
  void paint(Canvas tuval, Size boyut) {
    if (seviyeler.isEmpty) return;
    final n = seviyeler.length;
    final dilim = boyut.width / n;
    final kalinlik = (dilim * 0.6).clamp(1.5, 3.5);
    final orta = boyut.height / 2;
    final calinan = Paint()
      ..color = renk
      ..strokeCap = StrokeCap.round
      ..strokeWidth = kalinlik;
    final kalan = Paint()
      ..color = renk.withValues(alpha: 0.32)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = kalinlik;
    for (var i = 0; i < n; i++) {
      // En sönük ses bile görünür kalsın (nokta gibi), en yükseği kutuyu doldursun
      final yukseklik = (kalinlik + seviyeler[i] * (boyut.height - kalinlik))
          .clamp(kalinlik, boyut.height);
      final x = dilim * (i + 0.5);
      tuval.drawLine(
        Offset(x, orta - yukseklik / 2),
        Offset(x, orta + yukseklik / 2),
        (i + 1) / n <= oran ? calinan : kalan,
      );
    }
  }

  @override
  bool shouldRepaint(_DalgaCizer eski) =>
      eski.oran != oran || eski.renk != renk || eski.seviyeler != seviyeler;
}

/// Ses çubukları. Oynatıcıda ilerlemeyle dolar, kayıtta canlı akar.
class SesDalga extends StatelessWidget {
  final List<double> seviyeler;
  final double oran;
  final Color renk;
  final double yukseklik;

  const SesDalga({
    super.key,
    required this.seviyeler,
    required this.renk,
    this.oran = 1,
    this.yukseklik = 26,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: yukseklik,
    child: CustomPaint(
      painter: _DalgaCizer(seviyeler: seviyeler, oran: oran, renk: renk),
      size: Size.infinite,
    ),
  );
}

// ---------------------------------------------------------------------------
// Oynatıcı
// ---------------------------------------------------------------------------

/// Sesli mesaj baloncuğu: oynat/duraklat + dalga formu (dokunarak sarılır) + süre.
class SesOynatici extends StatefulWidget {
  final String url;
  final Color renk; // baloncuğa göre metin/ikon rengi
  final String? dalga; // mesajla gelen kodlanmış dalga (eski mesajlarda null)

  const SesOynatici({
    super.key,
    required this.url,
    required this.renk,
    this.dalga,
  });

  @override
  State<SesOynatici> createState() => _SesOynaticiState();
}

class _SesOynaticiState extends State<SesOynatici> {
  final _oynatici = AudioPlayer();
  late final ({int saniye, List<double> seviyeler})? _dalga = dalgaCoz(
    widget.dalga,
  );
  Duration _sure = Duration.zero;
  Duration _konum = Duration.zero;
  bool _oynuyor = false;
  bool _hazirlaniyor = false;
  bool _basladi = false; // kaynak yüklendi mi (resume/play ayrımı)
  final List<StreamSubscription<dynamic>> _abonelikler = [];

  /// Çubukların dolma oranı için toplam süre: oynatıcı bildirdiyse o, yoksa
  /// kayıtta ölçülen süre. (Ogg/Opus'ta süre üstverisi hep gelmeyebiliyor —
  /// eski sürümde bar bu yüzden hiç ilerlemiyordu.)
  Duration get _toplam =>
      _sure > Duration.zero ? _sure : Duration(seconds: _dalga?.saniye ?? 0);

  @override
  void initState() {
    super.initState();
    _oynatici.setReleaseMode(ReleaseMode.stop);
    _abonelikler.addAll([
      _oynatici.onDurationChanged.listen((d) {
        if (mounted && d > Duration.zero) setState(() => _sure = d);
      }),
      _oynatici.onPositionChanged.listen((d) {
        if (mounted) setState(() => _konum = d);
      }),
      _oynatici.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _oynuyor = false;
            _basladi = false; // baştan çalsın
            _konum = Duration.zero;
          });
        }
      }),
    ]);
  }

  @override
  void dispose() {
    for (final a in _abonelikler) {
      a.cancel();
    }
    _oynatici.dispose();
    super.dispose();
  }

  /// Bazı Ogg/Opus dosyalarında süre ilk karede gelmez; kısa süre yoklarız.
  Future<void> _sureyiYakala() async {
    for (var i = 0; i < 15 && mounted && _sure == Duration.zero; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      final d = await _oynatici.getDuration();
      if (d != null && d > Duration.zero) {
        if (mounted) setState(() => _sure = d);
        return;
      }
    }
  }

  Future<void> _toggle() async {
    if (_hazirlaniyor) return;
    if (_oynuyor) {
      await _oynatici.pause();
      if (mounted) setState(() => _oynuyor = false);
      return;
    }
    setState(() => _hazirlaniyor = true);
    try {
      if (_basladi) {
        await _oynatici.resume();
      } else {
        await _oynatici.play(UrlSource(widget.url));
        _basladi = true;
      }
      if (mounted) setState(() => _oynuyor = true);
      _sureyiYakala();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ses oynatılamadı'.c)));
      }
    } finally {
      if (mounted) setState(() => _hazirlaniyor = false);
    }
  }

  /// Dalga üzerinde dokunulan/sürüklenen orana atla.
  Future<void> _sar(double oran, double genislik) async {
    final toplam = _toplam;
    if (toplam == Duration.zero || genislik <= 0) return;
    final hedef = Duration(
      milliseconds: (toplam.inMilliseconds * oran.clamp(0.0, 1.0)).round(),
    );
    setState(() => _konum = hedef); // iyimser: çubuk anında yerine gitsin
    try {
      if (!_basladi) {
        await _oynatici.play(UrlSource(widget.url));
        _basladi = true;
        if (mounted) setState(() => _oynuyor = true);
        _sureyiYakala();
      }
      await _oynatici.seek(hedef);
    } catch (_) {
      if (mounted) setState(() => _konum = Duration.zero);
    }
  }

  String _fmt(Duration d) {
    final dk = d.inMinutes.remainder(60);
    final sn = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$dk:$sn';
  }

  @override
  Widget build(BuildContext context) {
    final toplam = _toplam;
    final oran = toplam.inMilliseconds == 0
        ? 0.0
        : (_konum.inMilliseconds / toplam.inMilliseconds).clamp(0.0, 1.0);
    // Dalga yoksa (bu sürümden önceki mesajlar) düz çubuklu şerit göster.
    final seviyeler = _dalga?.seviyeler ?? List.filled(dalgaOrnekSayisi, 0.28);
    return SizedBox(
      width: 216,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: _toggle,
              tooltip: _oynuyor ? 'Duraklat'.c : 'Oynat'.c,
              icon: _hazirlaniyor
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.renk,
                      ),
                    )
                  : Icon(
                      _oynuyor
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                      size: 34,
                      color: widget.renk,
                    ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutBuilder(
                  builder: (_, sinir) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => _sar(
                      d.localPosition.dx / sinir.maxWidth,
                      sinir.maxWidth,
                    ),
                    onHorizontalDragUpdate: (d) => _sar(
                      d.localPosition.dx / sinir.maxWidth,
                      sinir.maxWidth,
                    ),
                    child: Padding(
                      // dokunma hedefi: 26 çizim + 2×7 boşluk = 40
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: SesDalga(
                        seviyeler: seviyeler,
                        oran: oran,
                        renk: widget.renk,
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.mic,
                      size: 12,
                      color: widget.renk.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _fmt(
                        _oynuyor || _konum > Duration.zero ? _konum : toplam,
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.renk.withValues(alpha: 0.7),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
