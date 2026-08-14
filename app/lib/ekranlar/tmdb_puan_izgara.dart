import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import '../tmdb_bolum_puan.dart';
import 'ortak.dart';

/// Detay sayfasındaki TMDB puanı: dokununca altında sezon×bölüm ısı
/// haritası açılır. [yan] dizi.jpg rozeti ve izleyen sayısı gibi aynı
/// satırdaki diğer çocuklar — ızgara onların ALTINA iner, yanına değil.
class TmdbPuanHaritasi extends StatefulWidget {
  final int tmdbId;
  final double ortalama;
  final List<int> sezonNolari;
  final List<Widget> yan;
  final void Function(int sezon, int bolum)? onBolumSec;

  const TmdbPuanHaritasi({
    super.key,
    required this.tmdbId,
    required this.ortalama,
    required this.sezonNolari,
    this.yan = const [],
    this.onBolumSec,
  });

  @override
  State<TmdbPuanHaritasi> createState() => _TmdbPuanHaritasiState();
}

class _TmdbPuanHaritasiState extends State<TmdbPuanHaritasi> {
  bool _acik = false;
  bool _yukleniyor = false;
  String? _hata;
  List<TmdbSezonPuani>? _sezonlar;

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final nolar = widget.sezonNolari;
      final yanitlar = await Future.wait(
        nolar.map((n) async {
          try {
            final d = await Api.get('/tmdb/tv/${widget.tmdbId}/season/$n');
            return MapEntry(n, d);
          } catch (_) {
            return MapEntry(n, null);
          }
        }),
      );
      if (!mounted) return;
      final sezonlar = <TmdbSezonPuani>[];
      for (final y in yanitlar) {
        if (y.value is! Map) continue;
        sezonlar.add(
          TmdbSezonPuani(
            sezonNo: y.key,
            bolumler: tmdbBolumleriOku((y.value as Map)['episodes']),
          ),
        );
      }
      if (sezonlar.isEmpty) {
        setState(() {
          _yukleniyor = false;
          _hata = 'Bölüm puanları yüklenemedi'.c;
        });
        return;
      }
      setState(() {
        _sezonlar = sezonlar;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _hata = 'Bölüm puanları yüklenemedi'.c;
      });
    }
  }

  Future<void> _acKapa() async {
    if (_acik) {
      setState(() => _acik = false);
      return;
    }
    setState(() => _acik = true);
    if (_sezonlar == null && !_yukleniyor) await _yukle();
  }

  void _bolumeGit(int sezon, int bolum) {
    final ozel = widget.onBolumSec;
    if (ozel != null) {
      ozel(sezon, bolum);
      return;
    }
    context.push('/dizi/${widget.tmdbId}/sezon/$sezon/bolum/$bolum');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 6,
          children: [
            // Yıldız da tıklanır: kullanıcı çoğu zaman ikona dokunur,
            // yalnız yazıya değil. Chevron sarı — aksi hâlde TMDB satırı
            // eski düz metin gibi durur, ızgara "yok" sanılır.
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _acKapa,
              child: Semantics(
                button: true,
                label: 'Bölüm puanları'.c,
                child: SizedBox(
                  height: dokunmaHedefi,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          color: DiziRenkler.sari,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '{} TMDB'.cf([widget.ortalama.toStringAsFixed(1)]),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          _acik ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                          color: DiziRenkler.sariMetin,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ...widget.yan,
          ],
        ),
        if (_acik) ...[
          const SizedBox(height: 8),
          if (_yukleniyor)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(color: DiziRenkler.sari),
              ),
            )
          else if (_hata != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _hata!,
                      style: TextStyle(color: DiziRenkler.metin54),
                    ),
                  ),
                  TextButton(onPressed: _yukle, child: Text('Tekrar dene'.c)),
                ],
              ),
            )
          else if (_sezonlar != null)
            _Izgara(sezonlar: _sezonlar!, onBolumSec: _bolumeGit),
        ],
      ],
    );
  }
}

/// Üstte sezonlar, solda bölümler; kesişimde puan kutusu.
class _Izgara extends StatelessWidget {
  final List<TmdbSezonPuani> sezonlar;
  final void Function(int sezon, int bolum) onBolumSec;

  const _Izgara({required this.sezonlar, required this.onBolumSec});

  static const _kenar = 48.0;

  @override
  Widget build(BuildContext context) {
    final maxB = tmdbMaxBolum(sezonlar);
    if (maxB == 0) return const SizedBox.shrink();
    // En fazla 8 bölüm satırı + başlık görünsün; fazlası dikey kayar.
    const maxYukseklik = _kenar * 9;
    return Semantics(
      label: 'Bölüm puanları'.c,
      child: Scrollbar(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: maxYukseklik),
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      const SizedBox(width: _kenar, height: _kenar),
                      for (var b = 1; b <= maxB; b++)
                        _BaslikKutusu('E{}'.cf([b])),
                    ],
                  ),
                  for (final s in sezonlar)
                    Column(
                      children: [
                        _BaslikKutusu('S{}'.cf([s.sezonNo])),
                        for (var b = 1; b <= maxB; b++)
                          _PuanHucresi(
                            kayit: s.bolumler[b],
                            sezon: s.sezonNo,
                            bolum: b,
                            onTap: s.bolumler[b]?.puan == null
                                ? null
                                : () => onBolumSec(s.sezonNo, b),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BaslikKutusu extends StatelessWidget {
  final String yazi;
  const _BaslikKutusu(this.yazi);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _Izgara._kenar,
      height: _Izgara._kenar,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            yazi,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: DiziRenkler.metin70,
            ),
          ),
        ),
      ),
    );
  }
}

class _PuanHucresi extends StatelessWidget {
  final TmdbBolumPuani? kayit;
  final int sezon;
  final int bolum;
  final VoidCallback? onTap;

  const _PuanHucresi({
    required this.kayit,
    required this.sezon,
    required this.bolum,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final puan = kayit?.puan;
    final govde = Container(
      width: _Izgara._kenar - 4,
      height: _Izgara._kenar - 4,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tmdbPuanKutuRengi(puan),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tmdbPuanMetni(puan),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: tmdbPuanYaziRengi(puan),
        ),
      ),
    );
    return Semantics(
      button: onTap != null,
      label:
          'S{} · {}. Bölüm'.cf([sezon, bolum]) +
          (puan == null ? '' : ', ${tmdbPuanMetni(puan)} TMDB'),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: SizedBox(
          width: _Izgara._kenar,
          height: _Izgara._kenar,
          child: onTap == null
              ? Center(child: govde)
              : Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(8),
                    child: Center(child: govde),
                  ),
                ),
        ),
      ),
    );
  }
}
