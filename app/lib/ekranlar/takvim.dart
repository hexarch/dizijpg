import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'ortak.dart';
import 'takvim_ay.dart';
import 'tepki.dart';
import 'yorumlar.dart';

/// ISO tarihi (2021-01-03) kompakt biçime çevirir: 03.01.2021.
String tarihKisa(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final t = iso.split('T').first.split('-');
  if (t.length != 3) return iso;
  return '${t[2]}.${t[1]}.${t[0]}';
}

/// Takip edilen dizilerin yaklaşan bölümleri.
class TakvimEkrani extends StatefulWidget {
  const TakvimEkrani({super.key});

  @override
  State<TakvimEkrani> createState() => _TakvimEkraniState();
}

class _TakvimEkraniState extends State<TakvimEkrani>
    with AutomaticKeepAliveClientMixin {
  List<dynamic>? _takvim; // pencere: son 60 gün + gelecek (izlendi bayraklı)
  List<dynamic>? _yetisme; // yayınlanmış izlenmemiş arşiv (dizi başına 15)
  String? _hata;
  final Set<int> _acik = {}; // bölümleri açılmış diziler
  bool _takvimModu = false; // liste mi ay-takvimi mi (tercih kalıcı)

  /// Görünüm modunu değiştir + tercihi kaydet (sonraki açılışlarda hatırlanır).
  Future<void> _modDegistir() async {
    setState(() => _takvimModu = !_takvimModu);
    final p = await SharedPreferences.getInstance();
    await p.setBool('takvim_modu', _takvimModu);
  }

  /// Bölüm modalını açar; "bıraktım" dönerse diziyi listeden anında kaldırır.
  Future<void> _modalAc(Map<String, dynamic> b) async {
    final birakilan = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DiziRenkler.koyuGri,
      builder: (_) => BolumModali(bolum: b),
    );
    if (!mounted) return;
    // "Bıraktım": diziyi anında kaldır (iyimser).
    if (birakilan != null) {
      setState(() {
        _takvim?.removeWhere((r) => (r['tmdb_id'] as num).toInt() == birakilan);
        _yetisme?.removeWhere(
          (r) => (r['tmdb_id'] as num).toInt() == birakilan,
        );
      });
    }
    // Modal kapanınca her durumda tazele: izlenen bölüm backend'den düşer,
    // takvimden otomatik gider (yenilemeye gerek kalmaz).
    _yukle();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _yukle();
    SharedPreferences.getInstance().then((p) {
      if (mounted) {
        setState(() => _takvimModu = p.getBool('takvim_modu') ?? false);
      }
    });
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      final d = await Api.get('/takvim');
      if (!mounted) return;
      setState(() {
        _takvim = d['takvim'] as List<dynamic>? ?? [];
        _yetisme = d['yetisme'] as List<dynamic>? ?? [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_takvim == null) {
      // İskelet satırlar
      govde = ListView(
        padding: const EdgeInsets.all(12),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < 5; i++)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    IskeletKutu(genislik: 42, yukseklik: 62),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IskeletKutu(genislik: 160, yukseklik: 14),
                          SizedBox(height: 8),
                          IskeletKutu(genislik: 110, yukseklik: 11),
                        ],
                      ),
                    ),
                    IskeletKutu(genislik: 74, yukseklik: 26),
                  ],
                ),
              ),
            ),
        ],
      );
    } else if (_takvimModu) {
      // Ay-takvimi görünümü: gerçek pencere (geçmiş ✓ + gelecek)
      govde = AyTakvimi(olaylar: _takvim!, onAc: _modalAc);
    } else if (_takvim!.isEmpty && _yetisme!.isEmpty) {
      govde = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: 44,
                color: DiziRenkler.metin24,
              ),
              const SizedBox(height: 10),
              Text(
                'Yaklaşan bölüm yok.\nDizi detayından "İzliyorum" durumuna al, '
                        'yeni bölümleri burada takip et.'
                    .c,
                textAlign: TextAlign.center,
                style: TextStyle(color: DiziRenkler.metin54, height: 1.6),
              ),
            ],
          ),
        ),
      );
    } else {
      // İki bölüm: 1) Yaklaşan Bölümler (bugün ve sonrası, tarih sıralı)
      //            2) Yetişme Listesi (yayınlanmış izlenmemişler, dizi gruplu)
      final bugun = DateTime.now().toIso8601String().substring(0, 10);
      final yaklasanlar = [
        for (final r in _takvim!)
          if ((r as Map<String, dynamic>)['izlendi'] != true &&
              (r['tarih'] as String? ?? '').compareTo(bugun) >= 0)
            r,
      ];
      // Yetişme: dizi başına grupla (liste tarih sıralı; görünüm sırası korunur)
      final gruplar = <int, List<Map<String, dynamic>>>{};
      final sira = <int>[];
      for (final r in _yetisme!) {
        final m = r as Map<String, dynamic>;
        final id = (m['tmdb_id'] as num).toInt();
        if (!gruplar.containsKey(id)) sira.add(id);
        gruplar.putIfAbsent(id, () => []).add(m);
      }
      Widget baslik(IconData ikon, String metin) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
        child: Row(
          children: [
            Icon(ikon, size: 18, color: DiziRenkler.sari),
            const SizedBox(width: 7),
            Text(
              metin,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
      govde = RefreshIndicator(
        color: DiziRenkler.sari,
        onRefresh: _yukle,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (yaklasanlar.isNotEmpty) ...[
              baslik(Icons.upcoming_outlined, 'Yaklaşan Bölümler'.c),
              for (final b in yaklasanlar) _yaklasanSatiri(b),
            ],
            if (sira.isNotEmpty) ...[
              baslik(Icons.playlist_add_check, 'Yetişme Listesi'.c),
              for (final id in sira) _diziKarti(id, gruplar[id]!),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Takvim'.c),
        actions: [
          IconButton(
            tooltip: _takvimModu ? 'Liste görünümü'.c : 'Takvim görünümü'.c,
            onPressed: _modDegistir,
            icon: Icon(
              _takvimModu ? Icons.view_agenda_outlined : Icons.calendar_month,
              color: DiziRenkler.sari,
            ),
          ),
        ],
      ),
      body: govde,
    );
  }

  /// Yaklaşan bölüm satırı: poster + dizi + SxB + tarih çipi.
  Widget _yaklasanSatiri(Map<String, dynamic> b) {
    final poster = posterUrl(b['poster'] as String?, boyut: 'w185');
    return Card(
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 42,
            height: 62,
            child: poster == null
                ? Container(color: DiziRenkler.koyuGri)
                : CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover),
          ),
        ),
        title: Text(
          b['dizi_adi'] as String? ?? '',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'S${b['sezon']}B${b['bolum']}'
          '${b['bolum_adi'] != null ? ' · ${b['bolum_adi']}' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: DiziRenkler.sari,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            tarihKisa(b['tarih'] as String?),
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
        onTap: () => _modalAc(b),
      ),
    );
  }

  /// Yetişme kartı: dizi başlığı + (birden çoksa) akordeon bölüm listesi.
  Widget _diziKarti(int id, List<Map<String, dynamic>> bolumler) {
    final ilk = bolumler.first;
    final tekBolum = bolumler.length == 1;
    final acik = _acik.contains(id);
    final poster = posterUrl(ilk['poster'] as String?, boyut: 'w185');
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 42,
                height: 62,
                child: poster == null
                    ? Container(color: DiziRenkler.koyuGri)
                    : CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover),
              ),
            ),
            title: Text(
              ilk['dizi_adi'] as String? ?? '',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              'S${ilk['sezon']}B${ilk['bolum']}'
              '${ilk['bolum_adi'] != null ? ' · ${ilk['bolum_adi']}' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: DiziRenkler.sari,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tarihKisa(ilk['tarih'] as String?),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (!tekBolum) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: DiziRenkler.koyuGri,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${bolumler.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: DiziRenkler.metin70,
                      ),
                    ),
                  ),
                  Icon(
                    acik ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: DiziRenkler.metin54,
                  ),
                ],
              ],
            ),
            // Tek bölümse direkt modal; birden çoksa altında listele
            onTap: () => tekBolum
                ? _modalAc(ilk)
                : setState(() => acik ? _acik.remove(id) : _acik.add(id)),
          ),
          if (acik) ...[
            Divider(color: DiziRenkler.metin12, height: 1),
            for (final b in bolumler)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 70, right: 16),
                title: Text(
                  'S${b['sezon']}B${b['bolum']}'
                  '${b['bolum_adi'] != null ? ' · ${b['bolum_adi']}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: Text(
                  tarihKisa(b['tarih'] as String?),
                  style: TextStyle(fontSize: 12, color: DiziRenkler.metin54),
                ),
                onTap: () => _modalAc(b),
              ),
          ],
        ],
      ),
    );
  }
}

/// Takvimden açılan bölüm modalı: emoji tepkisi, puan, platform ve
/// bölüme özel yorumlar — diziye gitmeden her şey burada.
class BolumModali extends StatefulWidget {
  final Map<String, dynamic> bolum;

  const BolumModali({super.key, required this.bolum});

  @override
  State<BolumModali> createState() => _BolumModaliState();
}

class _BolumModaliState extends State<BolumModali> {
  int? _benimPuan; // sunucu ölçeği (1-10)
  bool _puanYuklendi = false;
  bool _izlendi = false;
  bool _izleIsleniyor = false;

  int get _tmdbId => (widget.bolum['tmdb_id'] as num).toInt();
  int get _sezon => (widget.bolum['sezon'] as num?)?.toInt() ?? 1;
  int get _bolumNo => (widget.bolum['bolum'] as num?)?.toInt() ?? 1;

  @override
  void initState() {
    super.initState();
    _puanYukle();
  }

  Future<void> _puanYukle() async {
    try {
      final d = await Api.get('/benim/tv/$_tmdbId') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _benimPuan = (d['puan']?['puan'] as num?)?.toInt();
        _izlendi = (d['izlenenler'] as List<dynamic>? ?? []).any(
          (r) =>
              (r['sezon'] as num?)?.toInt() == _sezon &&
              (r['bolum'] as num?)?.toInt() == _bolumNo,
        );
        _puanYuklendi = true;
      });
    } catch (_) {
      if (mounted) setState(() => _puanYuklendi = true);
    }
  }

  /// Diziyi "bıraktım" yapar: takvimden tüm bölümleri kalkar.
  Future<void> _birak() async {
    try {
      await Api.post('/durum', {
        'tmdb_id': _tmdbId,
        'tur': 'tv',
        'durum': 'biraktim',
      });
      if (!mounted) return;
      Navigator.pop(context, _tmdbId); // takvim bu diziyi anında kaldırsın
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  /// Dizi sayfasına git (modal kapanır; ölü-context tuzağına karşı önce alınır).
  void _diziyeGit() {
    final yonlendirici = GoRouter.of(context);
    Navigator.pop(context);
    yonlendirici.push('/icerik/tv/$_tmdbId');
  }

  Future<void> _izleToggle() async {
    if (_izleIsleniyor) return;
    setState(() {
      _izleIsleniyor = true;
      _izlendi = !_izlendi;
    });
    try {
      await Api.post('/izleme/toggle', {
        'tmdb_id': _tmdbId,
        'tur': 'tv',
        'sezon': _sezon,
        'bolum': _bolumNo,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _izlendi = !_izlendi);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _izleIsleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bolum;
    final poster = posterUrl(b['poster'] as String?, boyut: 'w185');

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, kontrol) => ListView(
        controller: kontrol,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: DiziRenkler.metin24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Poster + dizi adı tıklanır → dizi sayfası
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _diziyeGit,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 56,
                    height: 82,
                    child: poster == null
                        ? Container(color: DiziRenkler.kart)
                        : CachedNetworkImage(
                            imageUrl: poster,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              b['dizi_adi'] as String? ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: DiziRenkler.metin38,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'S{} · {}. Bölüm'.cf([_sezon, _bolumNo]) +
                            (b['bolum_adi'] != null
                                ? ' · ${b['bolum_adi']}'
                                : ''),
                        style: TextStyle(color: DiziRenkler.metin70),
                      ),
                      if (b['tarih'] != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: DiziRenkler.sari,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tarihKisa(b['tarih'] as String?),
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Bu bölüme emoji tepkisi
          TepkiSatiri(
            tur: 'tv',
            tmdbId: _tmdbId,
            sezon: _sezon,
            bolum: _bolumNo,
          ),
          const SizedBox(height: 12),
          // Bu bölümü izledim işareti
          if (_puanYuklendi)
            Center(
              child: FilledButton.icon(
                onPressed: _izleToggle,
                style: _izlendi
                    ? FilledButton.styleFrom(
                        backgroundColor: DiziRenkler.kart,
                        foregroundColor: DiziRenkler.sari,
                      )
                    : null,
                icon: Icon(
                  _izlendi ? Icons.check_circle : Icons.visibility_outlined,
                ),
                label: Text(_izlendi ? 'İzledin'.c : 'İzledim'.c),
              ),
            ),
          const SizedBox(height: 10),
          // Doğrudan 5 yıldız (diziye puan)
          if (_puanYuklendi)
            Center(
              child: YildizPuan(
                tur: 'tv',
                tmdbId: _tmdbId,
                baslangicPuan: _benimPuan,
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ActionChip(
                avatar: const Icon(
                  Icons.open_in_new,
                  size: 16,
                  color: DiziRenkler.sari,
                ),
                label: Text('Diziye git'.c),
                onPressed: _diziyeGit,
              ),
              ActionChip(
                avatar: const Icon(
                  Icons.stop_circle_outlined,
                  size: 16,
                  color: Colors.redAccent,
                ),
                label: Text(
                  'İzlemeyi Bıraktım'.c,
                  style: const TextStyle(color: Colors.redAccent),
                ),
                onPressed: _birak,
              ),
            ],
          ),
          Divider(color: DiziRenkler.metin12, height: 28),
          // Bölüme özel yorumlar
          YorumBolumu(
            tur: 'tv',
            tmdbId: _tmdbId,
            sezon: _sezon,
            bolum: _bolumNo,
          ),
        ],
      ),
    );
  }
}
