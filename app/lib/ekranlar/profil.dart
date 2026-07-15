import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../tema.dart';
import 'ortak.dart';

class ProfilEkrani extends StatefulWidget {
  const ProfilEkrani({super.key});

  @override
  State<ProfilEkrani> createState() => _ProfilEkraniState();
}

class _ProfilEkraniState extends State<ProfilEkrani>
    with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _istatistik;
  Map<String, dynamic>? _kitaplik;
  List<dynamic> _listeler = [];
  String? _hata;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      final sonuclar = await Future.wait([
        Api.get('/istatistiklerim'),
        Api.get('/kitapligim'),
        Api.get('/listelerim'),
      ]);
      if (!mounted) return;
      setState(() {
        _istatistik = sonuclar[0] as Map<String, dynamic>;
        _kitaplik = sonuclar[1] as Map<String, dynamic>;
        _listeler = sonuclar[2]['listeler'] as List<dynamic>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
    }
  }

  Future<void> _yeniListe() async {
    final ad = TextEditingController();
    final olustur = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DiziRenkler.koyuGri,
        title: const Text('Yeni Liste'),
        content: TextField(
          controller: ad,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Liste adı'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Oluştur')),
        ],
      ),
    );
    if (olustur == true && ad.text.trim().isNotEmpty) {
      await Api.post('/listeler', {'ad': ad.text.trim()});
      _yukle();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final oturum = context.watch<Oturum>();
    final kullaniciAdi =
        oturum.kullanici?['kullanici_adi'] as String? ?? 'kullanıcı';

    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_istatistik == null) {
      govde = const Center(
          child: CircularProgressIndicator(color: DiziRenkler.kirmizi));
    } else {
      final st = _istatistik!;
      final dakika = (st['tahmini_dakika'] as num?)?.toInt() ?? 0;
      final durumlar = (_kitaplik?['durumlar'] as List<dynamic>? ?? []);
      final gruplar = <String, List<dynamic>>{};
      for (final d in durumlar) {
        gruplar.putIfAbsent(d['durum'] as String, () => []).add(d);
      }
      const durumAdlari = {
        'izliyorum': '▶️ İzliyorum',
        'izleyecegim': '🔖 İzleyeceğim',
        'bitirdim': '✅ Bitirdim',
        'biraktim': '✖️ Bıraktım',
      };

      govde = RefreshIndicator(
        color: DiziRenkler.kirmizi,
        onRefresh: _yukle,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // İstatistik kartları
            Row(
              children: [
                _StatKarti(deger: '${st['izlenen_bolum']}', etiket: 'Bölüm'),
                const SizedBox(width: 10),
                _StatKarti(deger: '${st['izlenen_film']}', etiket: 'Film'),
                const SizedBox(width: 10),
                _StatKarti(
                    deger: '${st['takip_edilen_dizi']}', etiket: 'Dizi'),
                const SizedBox(width: 10),
                _StatKarti(
                    deger: dakika >= 60
                        ? '${(dakika / 60).toStringAsFixed(0)}s'
                        : '${dakika}dk',
                    etiket: 'Ekran süresi'),
              ],
            ),
            const SizedBox(height: 20),
            // Kitaplık grupları
            for (final e in gruplar.entries) ...[
              Text(durumAdlari[e.key] ?? e.key,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              SizedBox(
                height: 190,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: e.value.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final d = e.value[i] as Map<String, dynamic>;
                    return _MiniIcerik(
                        tmdbId: d['tmdb_id'] as int, tur: d['tur'] as String);
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Listelerim
            Row(
              children: [
                const Text('📋 Listelerim',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                    onPressed: _yeniListe,
                    icon: const Icon(Icons.add, color: DiziRenkler.kirmizi)),
              ],
            ),
            for (final l in _listeler)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.list, color: DiziRenkler.kirmizi),
                  title: Text(l['ad'] as String),
                  subtitle: Text('${l['oge_sayisi']} içerik'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.white38),
                    onPressed: () async {
                      await Api.delete('/listeler/${l['id']}');
                      _yukle();
                    },
                  ),
                ),
              ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => context.read<Oturum>().cikis(),
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text('Çıkış Yap',
                  style: TextStyle(color: Colors.redAccent)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('@$kullaniciAdi')),
      body: govde,
    );
  }
}

class _StatKarti extends StatelessWidget {
  final String deger;
  final String etiket;
  const _StatKarti({required this.deger, required this.etiket});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: DiziRenkler.kart,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A2A2F)),
        ),
        child: Column(
          children: [
            Text(deger,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: DiziRenkler.kirmizi)),
            const SizedBox(height: 2),
            Text(etiket,
                style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

/// Kitaplıktaki içerik: detayını sunucu önbelleğinden çekip poster gösterir.
class _MiniIcerik extends StatefulWidget {
  final int tmdbId;
  final String tur;
  const _MiniIcerik({required this.tmdbId, required this.tur});

  @override
  State<_MiniIcerik> createState() => _MiniIcerikState();
}

class _MiniIcerikState extends State<_MiniIcerik> {
  Map<String, dynamic>? _icerik;

  @override
  void initState() {
    super.initState();
    Api.get('/tmdb/${widget.tur}/${widget.tmdbId}').then((d) {
      if (mounted) setState(() => _icerik = d as Map<String, dynamic>);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    if (_icerik == null) {
      return Container(
        width: 105,
        decoration: BoxDecoration(
          color: DiziRenkler.kart,
          borderRadius: BorderRadius.circular(12),
        ),
      );
    }
    return PosterKarti(
        icerik: _icerik!, turZorla: widget.tur, genislik: 105);
  }
}
