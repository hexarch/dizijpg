import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'ortak.dart';

/// Başka bir kullanıcının herkese açık profili: istatistik, takip, yorumlar.
class KullaniciProfilEkrani extends StatefulWidget {
  final String kullaniciAdi;
  const KullaniciProfilEkrani({super.key, required this.kullaniciAdi});

  @override
  State<KullaniciProfilEkrani> createState() => _KullaniciProfilEkraniState();
}

class _KullaniciProfilEkraniState extends State<KullaniciProfilEkrani> {
  Map<String, dynamic>? _profil;
  String? _hata;
  bool _takipIsleniyor = false;
  bool _yorumlarAcik = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      final p = await Api.acikProfil(widget.kullaniciAdi);
      if (mounted) setState(() => _profil = p);
    } catch (e) {
      if (mounted) setState(() => _hata = e.toString());
    }
  }

  Future<void> _takip() async {
    setState(() => _takipIsleniyor = true);
    try {
      final d = await Api.takipToggle(widget.kullaniciAdi);
      if (!mounted) return;
      setState(() {
        _profil!['takip_ediyorum'] = d['takip'];
        _profil!['istatistik']['takipci'] = d['takipci'];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _takipIsleniyor = false);
    }
  }

  void _liste(bool takipciler) {
    context.push(
      '/kullanici/${widget.kullaniciAdi}/${takipciler ? 'takipciler' : 'takip'}',
    );
  }

  void _listeAc(int id, String? ad) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DiziRenkler.koyuGri,
      builder: (_) => ListeSheet(listeId: id, ad: ad ?? ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_profil == null) {
      govde = const Center(
        child: CircularProgressIndicator(color: DiziRenkler.sari),
      );
    } else {
      final p = _profil!;
      final st = p['istatistik'] as Map<String, dynamic>;
      final avatar = dosyaUrl(p['avatar'] as String?);
      final girisli = context.watch<Oturum>().girisli;
      final benMi = p['ben_mi'] == true;
      final takipEdiyorum = p['takip_ediyorum'] == true;
      final yorumlar = (p['yorumlar'] as List<dynamic>? ?? []);
      final listeler = (p['listeler'] as List<dynamic>? ?? []);
      final izlenenler = (p['izlenenler'] as List<dynamic>? ?? []);

      final kapak = dosyaUrl(p['kapak'] as String?);
      govde = RefreshIndicator(
        color: DiziRenkler.sari,
        onRefresh: _yukle,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            if (kapak != null)
              SizedBox(
                height: 130,
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: kapak,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      Container(color: DiziRenkler.koyuGri),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: DiziRenkler.kart,
                        backgroundImage: avatar != null
                            ? NetworkImage(avatar)
                            : null,
                        child: avatar == null
                            ? Icon(
                                Icons.person,
                                size: 40,
                                color: DiziRenkler.metin38,
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '@${p['kullanici_adi']}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if ((p['ulke'] as String?)?.isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: DiziRenkler.sari,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      p['ulke'] as String,
                                      style: TextStyle(
                                        color: DiziRenkler.metin54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if ((p['bio'] as String?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    Text(
                      p['bio'] as String,
                      style: TextStyle(color: DiziRenkler.metin70, height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Takipçi / takip / yorum sayaçları
                  Row(
                    children: [
                      _Sayac(
                        deger: '${st['takipci']}',
                        etiket: 'Takipçi'.c,
                        onTap: () => _liste(true),
                      ),
                      _Sayac(
                        deger: '${st['takip_edilen']}',
                        etiket: 'Takip'.c,
                        onTap: () => _liste(false),
                      ),
                      _Sayac(deger: '${st['yorum']}', etiket: 'Yorum'.c),
                      _Sayac(deger: '${st['film']}', etiket: 'Film'.c),
                      _Sayac(deger: '${st['bolum']}', etiket: 'Bölüm'.c),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Takip + Mesaj (kendi profilinde gösterme)
                  if (!benMi && girisli)
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _takipIsleniyor ? null : _takip,
                            style: takipEdiyorum
                                ? FilledButton.styleFrom(
                                    backgroundColor: DiziRenkler.kart,
                                    foregroundColor: DiziRenkler.metin,
                                  )
                                : null,
                            icon: Icon(
                              takipEdiyorum
                                  ? Icons.person_remove
                                  : Icons.person_add,
                            ),
                            label: Text(
                              takipEdiyorum ? 'Takibi Bırak'.c : 'Takip Et'.c,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                context.push('/sohbet/${widget.kullaniciAdi}'),
                            icon: const Icon(
                              Icons.mail_outline,
                              size: 18,
                              color: DiziRenkler.sari,
                            ),
                            label: Text(
                              'Mesaj'.c,
                              style: TextStyle(color: DiziRenkler.metin),
                            ),
                          ),
                        ),
                      ],
                    ),
                  // İzledikleri: diziler ve filmler ayrı şeritler.
                  // Başlıktaki sayı GERÇEK toplamdır (şerit son 60'ı gösterir).
                  for (final grup in [
                    (
                      Icons.tv_outlined,
                      'İzlediği Diziler ({})',
                      izlenenler.where((o) => o['tur'] == 'tv').toList(),
                      (st['dizi'] as num?)?.toInt(),
                    ),
                    (
                      Icons.movie_outlined,
                      'İzlediği Filmler ({})',
                      izlenenler.where((o) => o['tur'] == 'movie').toList(),
                      (st['film'] as num?)?.toInt(),
                    ),
                  ])
                    if (grup.$3.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Icon(grup.$1, size: 19, color: DiziRenkler.sari),
                          const SizedBox(width: 6),
                          Text(
                            grup.$2.cf([grup.$4 ?? grup.$3.length]),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 190,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: grup.$3.length > 30 ? 30 : grup.$3.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, i) {
                            final o = grup.$3[i] as Map<String, dynamic>;
                            return MiniIcerik(
                              tmdbId: (o['tmdb_id'] as num).toInt(),
                              tur: o['tur'] as String,
                              izlenenSayi: (o['sayi'] as num?)?.toInt(),
                            );
                          },
                        ),
                      ),
                    ],
                  if (listeler.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(
                          Icons.playlist_play,
                          size: 20,
                          color: DiziRenkler.sari,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Listeleri ({})'.cf([listeler.length]),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final l in listeler)
                      Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.playlist_play,
                            color: DiziRenkler.sari,
                          ),
                          title: Text(l['ad'] as String? ?? ''),
                          subtitle: Text(
                            '{} içerik'.cf([l['oge_sayisi'] ?? 0]),
                            style: TextStyle(
                              color: DiziRenkler.metin38,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: DiziRenkler.metin38,
                          ),
                          onTap: () =>
                              _listeAc(l['id'] as int, l['ad'] as String?),
                        ),
                      ),
                  ],
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () => setState(() => _yorumlarAcik = !_yorumlarAcik),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 18,
                          color: DiziRenkler.sari,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Yorumları ({})'.cf([yorumlar.length]),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          _yorumlarAcik
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: DiziRenkler.metin54,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_yorumlarAcik) ...[
                    if (yorumlar.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Henüz yorum yok.'.c,
                          style: TextStyle(color: DiziRenkler.metin38),
                        ),
                      ),
                    for (final y in yorumlar)
                      ProfilYorumKarti(
                        yorum: y as Map<String, dynamic>,
                        icerikler:
                            p['icerikler'] as Map<String, dynamic>? ?? {},
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('@${widget.kullaniciAdi}')),
      body: govde,
    );
  }
}

class _Sayac extends StatelessWidget {
  final String deger;
  final String etiket;
  final VoidCallback? onTap;
  const _Sayac({required this.deger, required this.etiket, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Text(
                deger,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: DiziRenkler.sari,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                etiket,
                style: TextStyle(fontSize: 11, color: DiziRenkler.metin54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Profildeki yorum: metin + görüntülenme/beğeni sayıları, içeriğe götürür.
class ProfilYorumKarti extends StatelessWidget {
  final Map<String, dynamic> yorum;
  final Map<String, dynamic> icerikler;
  const ProfilYorumKarti({required this.yorum, this.icerikler = const {}});

  @override
  Widget build(BuildContext context) {
    final tur = yorum['tur'] as String;
    final tarih = (yorum['tarih'] as String? ?? '').split('T').first;
    final bolumMu = yorum['sezon'] != null;
    final icerik =
        icerikler['$tur:${yorum['tmdb_id']}'] as Map<String, dynamic>?;
    final ad = icerik?['ad'] as String?;
    final poster = posterUrl(icerik?['poster'] as String?, boyut: 'w92');
    // Bölüm yorumu doğrudan bölüm sayfasına, diğerleri içerik/kişi sayfasına
    final hedef = tur == 'person'
        ? '/kisi/${yorum['tmdb_id']}'
        : bolumMu
        ? '/dizi/${yorum['tmdb_id']}/sezon/${yorum['sezon']}/bolum/${yorum['bolum']}'
        : '/icerik/$tur/${yorum['tmdb_id']}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: DiziRenkler.koyuGri,
          builder: (_) => _YorumDetayModal(
            yorum: yorum,
            ad: ad,
            poster: poster,
            bolumMu: bolumMu,
            hedef: hedef,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (poster != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: SizedBox(
                          width: 24,
                          height: 34,
                          child: CachedNetworkImage(
                            imageUrl: poster,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                Container(color: DiziRenkler.koyuGri),
                          ),
                        ),
                      ),
                    )
                  else ...[
                    Icon(
                      tur == 'person'
                          ? Icons.person
                          : tur == 'movie'
                          ? Icons.movie
                          : Icons.tv,
                      size: 15,
                      color: DiziRenkler.sari,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      (ad ??
                              (tur == 'person'
                                  ? 'Kişi yorumu'.c
                                  : tur == 'movie'
                                  ? 'Film yorumu'.c
                                  : 'Dizi yorumu'.c)) +
                          (bolumMu
                              ? ' · S${yorum['sezon']}B${yorum['bolum']}'
                              : ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: DiziRenkler.sari,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tarih,
                    style: TextStyle(fontSize: 11, color: DiziRenkler.metin38),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                yorum['metin'] as String,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(height: 1.4),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.remove_red_eye,
                    size: 15,
                    color: DiziRenkler.metin38,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${yorum['goruntulenme'] ?? 0}',
                    style: TextStyle(fontSize: 12, color: DiziRenkler.metin38),
                  ),
                  const SizedBox(width: 14),
                  const Icon(Icons.favorite, size: 15, color: DiziRenkler.sari),
                  const SizedBox(width: 4),
                  Text(
                    '${yorum['begeni'] ?? 0}',
                    style: TextStyle(fontSize: 12, color: DiziRenkler.metin38),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Takipçi ya da takip edilenlerin listesi.
class KullaniciListesiEkrani extends StatefulWidget {
  final String kullaniciAdi;
  final bool takipciler;
  const KullaniciListesiEkrani({
    super.key,
    required this.kullaniciAdi,
    required this.takipciler,
  });

  @override
  State<KullaniciListesiEkrani> createState() => _KullaniciListesiEkraniState();
}

class _KullaniciListesiEkraniState extends State<KullaniciListesiEkrani> {
  List<dynamic>? _liste;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final l = widget.takipciler
          ? await Api.takipciler(widget.kullaniciAdi)
          : await Api.takipEdilenler(widget.kullaniciAdi);
      if (mounted) setState(() => _liste = l);
    } catch (e) {
      if (mounted) setState(() => _hata = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_liste == null) {
      govde = const Center(
        child: CircularProgressIndicator(color: DiziRenkler.sari),
      );
    } else if (_liste!.isEmpty) {
      govde = Center(
        child: Text(
          widget.takipciler ? 'Takipçi yok'.c : 'Kimseyi takip etmiyor'.c,
          style: TextStyle(color: DiziRenkler.metin38),
        ),
      );
    } else {
      govde = ListView(
        children: [for (final u in _liste!) KullaniciSatiri(kullanici: u)],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.takipciler ? 'Takipçiler'.c : 'Takip Edilenler'.c),
      ),
      body: govde,
    );
  }
}

/// Kullanıcı listelerinde tek satır (avatar + ad + bio), profile götürür.
class KullaniciSatiri extends StatelessWidget {
  final Map<String, dynamic> kullanici;
  const KullaniciSatiri({super.key, required this.kullanici});

  @override
  Widget build(BuildContext context) {
    final avatar = dosyaUrl(kullanici['avatar'] as String?);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: DiziRenkler.kart,
        backgroundImage: avatar != null ? NetworkImage(avatar) : null,
        child: avatar == null
            ? Icon(Icons.person, color: DiziRenkler.metin38)
            : null,
      ),
      title: Text(
        '@${kullanici['kullanici_adi']}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: (kullanici['bio'] as String?)?.isNotEmpty == true
          ? Text(
              kullanici['bio'] as String,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      onTap: () => context.push('/kullanici/${kullanici['kullanici_adi']}'),
    );
  }
}

/// Kullanıcı arama ekranı (takip edilecek kişileri keşfet).
class KullaniciAramaEkrani extends StatefulWidget {
  const KullaniciAramaEkrani({super.key});

  @override
  State<KullaniciAramaEkrani> createState() => _KullaniciAramaEkraniState();
}

class _KullaniciAramaEkraniState extends State<KullaniciAramaEkrani> {
  final _arama = TextEditingController();
  List<dynamic> _sonuc = [];
  bool _yukleniyor = false;

  @override
  void dispose() {
    _arama.dispose();
    super.dispose();
  }

  Future<void> _ara(String q) async {
    if (q.trim().length < 2) {
      setState(() => _sonuc = []);
      return;
    }
    setState(() => _yukleniyor = true);
    try {
      final r = await Api.kullaniciAra(q);
      if (mounted) setState(() => _sonuc = r);
    } catch (_) {
      // sessiz geç
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _arama,
          autofocus: true,
          onChanged: _ara,
          decoration: InputDecoration(
            hintText: 'Kullanıcı adı ara...'.c,
            border: InputBorder.none,
          ),
        ),
      ),
      body: _yukleniyor
          ? const Center(
              child: CircularProgressIndicator(color: DiziRenkler.sari),
            )
          : _sonuc.isEmpty
          ? Center(
              child: Text(
                'En az 2 harf yaz'.c,
                style: TextStyle(color: DiziRenkler.metin38),
              ),
            )
          : ListView(
              children: [for (final u in _sonuc) KullaniciSatiri(kullanici: u)],
            ),
    );
  }
}

/// Açık listenin içeriğini gösteren alt sayfa.
/// Profildeki yorumun modal görünümü: içerik başlığı + tam metin + medya.
class _YorumDetayModal extends StatelessWidget {
  final Map<String, dynamic> yorum;
  final String? ad;
  final String? poster;
  final bool bolumMu;
  final String hedef;

  const _YorumDetayModal({
    required this.yorum,
    required this.ad,
    required this.poster,
    required this.bolumMu,
    required this.hedef,
  });

  @override
  Widget build(BuildContext context) {
    final medya = (yorum['medya'] as List<dynamic>? ?? []).cast<String>();
    final tarih = (yorum['tarih'] as String? ?? '').split('T').first;
    final baslik =
        (ad ?? '') + (bolumMu ? ' · S${yorum['sezon']}B${yorum['bolum']}' : '');

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
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
          // İçerik başlığı: tıklayınca ilgili sayfaya gider
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              // Yönlendirici modal kapanmadan ÖNCE alınır (ölü context)
              final yonlendirici = GoRouter.of(context);
              Navigator.pop(context);
              yonlendirici.push(hedef);
            },
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 46,
                    height: 68,
                    child: poster != null
                        ? CachedNetworkImage(
                            imageUrl: poster!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: DiziRenkler.kart,
                              child: Icon(
                                Icons.movie,
                                color: DiziRenkler.metin38,
                              ),
                            ),
                          )
                        : Container(
                            color: DiziRenkler.kart,
                            child: Icon(
                              Icons.movie,
                              color: DiziRenkler.metin38,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    baslik,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: DiziRenkler.sari,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: DiziRenkler.metin38),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            yorum['metin'] as String? ?? '',
            style: const TextStyle(height: 1.5, fontSize: 14),
          ),
          if (medya.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: medya.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: medya[i].endsWith('.mp4') || medya[i].endsWith('.webm')
                      ? Container(
                          width: 120,
                          color: DiziRenkler.kart,
                          child: Icon(
                            Icons.play_circle_outline,
                            color: DiziRenkler.metin54,
                            size: 32,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: dosyaUrl(medya[i])!,
                          width: 120,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 120,
                            color: DiziRenkler.kart,
                            child: Icon(
                              Icons.broken_image,
                              color: DiziRenkler.metin38,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.remove_red_eye, size: 15, color: DiziRenkler.metin38),
              const SizedBox(width: 4),
              Text(
                '${yorum['goruntulenme'] ?? 0}',
                style: TextStyle(fontSize: 12, color: DiziRenkler.metin38),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.favorite, size: 15, color: DiziRenkler.sari),
              const SizedBox(width: 4),
              Text(
                '${yorum['begeni'] ?? 0}',
                style: TextStyle(fontSize: 12, color: DiziRenkler.metin38),
              ),
              const Spacer(),
              Text(
                tarih,
                style: TextStyle(fontSize: 11, color: DiziRenkler.metin38),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
