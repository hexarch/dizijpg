import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';

/// Bir dizinin SEZON → BÖLÜM seçicisi.
///
/// Döndürdüğü değer:
///   · `{sezon, bolum, ad}` — bölüm seçildi,
///   · `{}` (boş harita)    — "Bölüm seçme" (varsa seçimi TEMİZLE),
///   · `null`               — kullanıcı vazgeçti (mevcut seçim korunur).
///
/// BOŞ HARİTA İLE `null` AYRI ŞEYLER — ve bu ayrım bilerek: ikisi de `null`
/// olsaydı "seçimi kaldır" ile "geri tuşuna bastım" aynı davranışa düşerdi ve
/// kullanıcı bir kez bölüm seçtikten sonra onu asla kaldıramazdı.
///
/// SEZON 0 (ÖZEL BÖLÜMLER) LİSTEDE YOK: `/yorumlar` uçlarında ve site
/// haritasında bölüm `sezon >= 1` varsayılıyor (`SITEMAP_BOLUM_SORGU`
/// `s.sezon >= 1` diyor). Özel bölüm seçilebilseydi yorum yazılır ama bölüm
/// sayfası hiç üretilmezdi.
class BolumSecSheet extends StatefulWidget {
  final int diziId;
  final String diziAd;
  const BolumSecSheet({super.key, required this.diziId, required this.diziAd});

  @override
  State<BolumSecSheet> createState() => _BolumSecSheetState();
}

class _BolumSecSheetState extends State<BolumSecSheet> {
  List<dynamic>? _sezonlar;
  int? _acikSezon;
  List<dynamic>? _bolumler;
  bool _yukleniyor = true;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _sezonlariYukle();
  }

  Future<void> _sezonlariYukle() async {
    try {
      final d = await Api.get('/tmdb/tv/${widget.diziId}');
      if (!mounted) return;
      setState(() {
        _sezonlar = (d['seasons'] as List<dynamic>? ?? [])
            .where((s) => ((s as Map)['season_number'] as int? ?? 0) >= 1)
            .toList();
        _yukleniyor = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _hata = e.toString();
          _yukleniyor = false;
        });
      }
    }
  }

  Future<void> _bolumleriYukle(int sezon) async {
    setState(() {
      _acikSezon = sezon;
      _bolumler = null;
      _hata = null;
    });
    try {
      final d = await Api.get('/tmdb/tv/${widget.diziId}/season/$sezon');
      if (!mounted) return;
      setState(() {
        _bolumler = (d['episodes'] as List<dynamic>? ?? [])
            .where((b) => ((b as Map)['episode_number'] as int? ?? 0) >= 1)
            .toList();
      });
    } catch (e) {
      if (mounted) setState(() => _hata = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _acikSezon == null
                        ? 'Sezon seç'.c
                        : '{}. sezon'.cf(['$_acikSezon']),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: DiziRenkler.metin,
                    ),
                  ),
                ),
                if (_acikSezon != null)
                  TextButton(
                    onPressed: () => setState(() {
                      _acikSezon = null;
                      _bolumler = null;
                    }),
                    child: Text('Sezonlar'.c),
                  ),
                IconButton(
                  tooltip: 'Kapat'.c,
                  icon: Icon(Icons.close, color: DiziRenkler.metin),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // "Bölüm seçme": mevcut seçimi kaldırmanın TEK yolu.
          ListTile(
            leading: Icon(Icons.block, color: DiziRenkler.metin38),
            title: Text(
              'Bölüm seçme (yalnız dizi hakkında)'.c,
              style: TextStyle(color: DiziRenkler.metin),
            ),
            onTap: () => Navigator.pop(context, <String, dynamic>{}),
          ),
          const Divider(height: 1),
          Expanded(child: _govde()),
        ],
      ),
    );
  }

  Widget _govde() {
    if (_yukleniyor) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hata != null && _sezonlar == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Sezonlar yüklenemedi.'.c,
            style: TextStyle(color: DiziRenkler.metin54),
          ),
        ),
      );
    }
    if (_acikSezon == null) {
      final sezonlar = _sezonlar ?? const [];
      if (sezonlar.isEmpty) {
        return Center(
          child: Text(
            'Bu dizide bölüm bilgisi yok.'.c,
            style: TextStyle(color: DiziRenkler.metin54),
          ),
        );
      }
      return ListView.builder(
        itemCount: sezonlar.length,
        itemBuilder: (context, i) {
          final s = sezonlar[i] as Map<String, dynamic>;
          final no = s['season_number'] as int;
          final adet = s['episode_count'] as int? ?? 0;
          return ListTile(
            title: Text(
              '{}. sezon'.cf(['$no']),
              style: TextStyle(color: DiziRenkler.metin),
            ),
            subtitle: adet > 0
                ? Text(
                    '{} bölüm'.cf(['$adet']),
                    style: TextStyle(fontSize: 12, color: DiziRenkler.metin38),
                  )
                : null,
            trailing: Icon(Icons.chevron_right, color: DiziRenkler.metin38),
            onTap: () => _bolumleriYukle(no),
          );
        },
      );
    }
    if (_bolumler == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final bolumler = _bolumler!;
    if (bolumler.isEmpty) {
      return Center(
        child: Text(
          'Bu sezonda bölüm yok.'.c,
          style: TextStyle(color: DiziRenkler.metin54),
        ),
      );
    }
    return ListView.builder(
      itemCount: bolumler.length,
      itemBuilder: (context, i) {
        final b = bolumler[i] as Map<String, dynamic>;
        final no = b['episode_number'] as int;
        final ad = (b['name'] as String?)?.trim();
        return ListTile(
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: DiziRenkler.kart,
            child: Text(
              '$no',
              style: TextStyle(fontSize: 12, color: DiziRenkler.metin),
            ),
          ),
          title: Text(
            ad == null || ad.isEmpty ? '{}. bölüm'.cf(['$no']) : ad,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: DiziRenkler.metin),
          ),
          onTap: () => Navigator.pop(context, <String, dynamic>{
            'sezon': _acikSezon,
            'bolum': no,
            'ad': ad ?? '',
          }),
        );
      },
    );
  }
}

/// Bölüm seçiciyi alt sayfada açar. Dönüş sözleşmesi [BolumSecSheet]'te.
Future<Map<String, dynamic>?> bolumSecAc(
  BuildContext context, {
  required int diziId,
  required String diziAd,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DiziRenkler.koyuGri,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => BolumSecSheet(diziId: diziId, diziAd: diziAd),
  );
}
