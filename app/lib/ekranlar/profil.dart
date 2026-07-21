import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../tema.dart';
import 'ayarlar.dart';
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
  Map<String, dynamic>? _profil;
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
        Api.get('/profilim'),
      ]);
      if (!mounted) return;
      setState(() {
        _istatistik = sonuclar[0] as Map<String, dynamic>;
        _kitaplik = sonuclar[1] as Map<String, dynamic>;
        _listeler = sonuclar[2]['listeler'] as List<dynamic>;
        _profil = sonuclar[3] as Map<String, dynamic>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
    }
  }

  Future<void> _hesabiBagla() async {
    final email = TextEditingController();
    final kullaniciAdi = TextEditingController();
    final sifre = TextEditingController();

    final bagla = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DiziRenkler.koyuGri,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Hesabını Bağla',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
              'İzleme geçmişin ve listelerin korunur; artık her cihazdan girebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'E-posta')),
            const SizedBox(height: 10),
            TextField(
                controller: kullaniciAdi,
                decoration: const InputDecoration(
                    hintText: 'Yeni kullanıcı adı (isteğe bağlı)')),
            const SizedBox(height: 10),
            TextField(
                controller: sifre,
                obscureText: true,
                decoration: const InputDecoration(hintText: 'Şifre')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Bağla'),
            ),
          ],
        ),
      ),
    );

    if (bagla == true) {
      try {
        final kullanici = await Api.hesabiBagla(
            email.text.trim(),
            kullaniciAdi.text.trim().isEmpty ? null : kullaniciAdi.text.trim(),
            sifre.text);
        if (!mounted) return;
        await context.read<Oturum>().girisYapildi(kullanici);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hesabın bağlandı! 🎉')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
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
            // Profil başlığı: avatar (GIF olabilir), bio, ülke
            Row(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: DiziRenkler.kart,
                  backgroundImage: dosyaUrl(_profil?['avatar'] as String?) !=
                          null
                      ? NetworkImage(dosyaUrl(_profil!['avatar'] as String)!)
                      : null,
                  child: _profil?['avatar'] == null
                      ? const Icon(Icons.person,
                          size: 38, color: Colors.white38)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('@$kullaniciAdi',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w900)),
                      if ((_profil?['bio'] as String?)?.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(_profil!['bio'] as String,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                        ),
                      if ((_profil?['ulke'] as String?)?.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(children: [
                            const Icon(Icons.location_on,
                                size: 14, color: DiziRenkler.kirmizi),
                            const SizedBox(width: 3),
                            Text(_profil!['ulke'] as String,
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                          ]),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Misafir hesabı bağlama bandı
            if (oturum.kullanici?['misafir'] == true) ...[
              Card(
                color: DiziRenkler.kirmizi,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _hesabiBagla,
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(Icons.link, color: Colors.white),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Misafir hesabındasın — e-postanla bağla, '
                            'verilerini kaybetme!',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
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
      appBar: AppBar(
        title: Text('@$kullaniciAdi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AyarlarEkrani()));
              _yukle();
            },
          ),
        ],
      ),
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
