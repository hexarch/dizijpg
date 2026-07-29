import 'package:flutter/material.dart';

import '../api.dart';
import '../tema.dart';

/// Sunucudaki CHECK ile aynı sırada: bayılmış, gülmüş, şaşırmış, üzgün,
/// korkmuş, sıkılmış, ağlamış, mutlu — dizi/film tepkileri.
const tepkiEmojileri = ['😍', '😂', '😮', '😢', '😱', '🥱', '😭', '😄'];

/// Tepki emojisini RENKLİ çizer (sistem emoji fontu; karanlık temada canlı durur).
class TepkiIkonu extends StatelessWidget {
  final String emoji;
  final double boyut;
  final Color? renk; // artık kullanılmıyor (emoji kendi renginde) — uyumluluk

  const TepkiIkonu(this.emoji, {super.key, this.boyut = 20, this.renk});

  @override
  Widget build(BuildContext context) {
    return Text(emoji, style: TextStyle(fontSize: boyut, height: 1.1));
  }
}

/// 8 ikonlu tepki satırı: dizi/film geneli (sezon=null) veya tek bölüm.
class TepkiSatiri extends StatefulWidget {
  final String tur;
  final int tmdbId;
  final int? sezon;
  final int? bolum;

  const TepkiSatiri({
    super.key,
    required this.tur,
    required this.tmdbId,
    this.sezon,
    this.bolum,
  });

  @override
  State<TepkiSatiri> createState() => _TepkiSatiriState();
}

class _TepkiSatiriState extends State<TepkiSatiri> {
  Map<String, int> _sayilar = {};
  String? _benim;
  bool _isleniyor = false;

  String get _sorgu => widget.sezon != null
      ? '?sezon=${widget.sezon}&bolum=${widget.bolum}'
      : '';

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final d = await Api.get(
        '/tepkiler/${widget.tur}/${widget.tmdbId}$_sorgu',
      );
      if (!mounted) return;
      _uygula(d as Map<String, dynamic>);
    } catch (_) {}
  }

  void _uygula(Map<String, dynamic> d) {
    setState(() {
      _sayilar = ((d['sayilar'] as Map<String, dynamic>? ?? {})).map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      );
      _benim = d['benim'] as String?;
    });
  }

  Future<void> _sec(String emoji) async {
    if (_isleniyor) return;
    setState(() => _isleniyor = true);
    final yeni = _benim == emoji ? null : emoji;
    // İyimser güncelleme
    setState(() {
      if (_benim != null) {
        _sayilar[_benim!] = (_sayilar[_benim!] ?? 1) - 1;
      }
      if (yeni != null) _sayilar[yeni] = (_sayilar[yeni] ?? 0) + 1;
      _benim = yeni;
    });
    try {
      final d = await Api.post('/tepki', {
        'tmdb_id': widget.tmdbId,
        'tur': widget.tur,
        if (widget.sezon != null) 'sezon': widget.sezon,
        if (widget.sezon != null) 'bolum': widget.bolum,
        'emoji': yeni,
      });
      if (!mounted) return;
      _uygula(d as Map<String, dynamic>);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
      _yukle();
    } finally {
      if (mounted) setState(() => _isleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final e in tepkiEmojileri)
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _sec(e),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                // Seçili: sarı-tint dolgu + sarı kenar (renkli emoji kaybolmasın)
                color: _benim == e
                    ? DiziRenkler.sari.withValues(alpha: 0.20)
                    : DiziRenkler.kart,
                borderRadius: BorderRadius.circular(20),
                border: _benim == e
                    ? Border.all(color: DiziRenkler.sari, width: 1.5)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TepkiIkonu(e, boyut: 20),
                  if ((_sayilar[e] ?? 0) > 0) ...[
                    const SizedBox(width: 5),
                    Text(
                      '${_sayilar[e]}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _benim == e
                            ? DiziRenkler.sariMetin
                            : DiziRenkler.metin70,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Doğrudan tıklanan 5 yıldızlık puan satırı (sheet açmadan kaydeder).
/// Sunucuda puan 1-10 tutulur; yıldız = puan/2.
class YildizPuan extends StatefulWidget {
  final String tur;
  final int tmdbId;
  final int? baslangicPuan; // sunucu ölçeği (1-10)
  final double boyut;

  const YildizPuan({
    super.key,
    required this.tur,
    required this.tmdbId,
    this.baslangicPuan,
    this.boyut = 30,
  });

  @override
  State<YildizPuan> createState() => _YildizPuanState();
}

class _YildizPuanState extends State<YildizPuan> {
  late int _yildiz = ((widget.baslangicPuan ?? 0) / 2).round();
  bool _isleniyor = false;

  @override
  void didUpdateWidget(YildizPuan eski) {
    super.didUpdateWidget(eski);
    if (eski.baslangicPuan != widget.baslangicPuan && !_isleniyor) {
      _yildiz = ((widget.baslangicPuan ?? 0) / 2).round();
    }
  }

  Future<void> _sec(int yildiz) async {
    if (_isleniyor) return;
    final eski = _yildiz;
    final yeni = yildiz == _yildiz ? 0 : yildiz; // aynı yıldıza basınca sil
    setState(() {
      _yildiz = yeni;
      _isleniyor = true;
    });
    try {
      await Api.post('/puan', {
        'tmdb_id': widget.tmdbId,
        'tur': widget.tur,
        'puan': yeni == 0 ? null : yeni * 2,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _yildiz = eski);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var y = 1; y <= 5; y++)
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _sec(y),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Icon(
                y <= _yildiz ? Icons.star_rounded : Icons.star_outline_rounded,
                size: widget.boyut,
                color: y <= _yildiz ? DiziRenkler.sari : DiziRenkler.metin38,
              ),
            ),
          ),
      ],
    );
  }
}
