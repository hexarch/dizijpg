import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'kullanici_profil.dart' show ProfilYorumKarti;
import 'ortak.dart';

/// Dakikayı insancıl süreye çevirir: "1 yıl 2 ay 3 gün" (en anlamlı 3 birim).
/// Küçük süreler için saat/dakika gösterir. Yaklaşık: yıl=365g, ay=30g.
String sureBicimle(int dakika) {
  if (dakika <= 0) return '{} dk'.cf([0]);
  var kalan = dakika;
  final yil = kalan ~/ 525600;
  kalan %= 525600; // 365*24*60
  final ay = kalan ~/ 43200;
  kalan %= 43200; // 30*24*60
  final gun = kalan ~/ 1440;
  kalan %= 1440;
  final saat = kalan ~/ 60;
  final dk = kalan % 60;
  final parcalar = <String>[];
  if (yil > 0) parcalar.add('{} yıl'.cf([yil]));
  if (ay > 0) parcalar.add('{} ay'.cf([ay]));
  if (gun > 0) parcalar.add('{} gün'.cf([gun]));
  // Yıl/ay yoksa daha küçük birimleri de göster
  if (yil == 0 && ay == 0) {
    if (saat > 0) parcalar.add('{} saat'.cf([saat]));
    if (gun == 0 && dk > 0) parcalar.add('{} dk'.cf([dk]));
  }
  return parcalar.isEmpty ? '{} dk'.cf([dk]) : parcalar.take(3).join(' ');
}

/// Profil sekmesi seçildiğinde tazeleme tetiği (kabuk artırır).
final ValueNotifier<int> profilYenileTetik = ValueNotifier(0);

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
  List<dynamic> _izlenenler = [];
  List<dynamic> _rozetler = [];
  String? _hata;
  // Varsayılan: rozetler en altta
  List<String> _bolumSirasi = const [
    'seritler',
    'ozet',
    'listeler',
    'rozetler',
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _yukle();
    _siraYukle();
    // Sekmeye her dönüşte veriyi tazele (izlenenler sırası güncel kalsın)
    profilYenileTetik.addListener(_tetikle);
  }

  void _tetikle() {
    _yukle();
    _siraYukle();
  }

  @override
  void dispose() {
    profilYenileTetik.removeListener(_tetikle);
    super.dispose();
  }

  Future<void> _siraYukle() async {
    final p = await SharedPreferences.getInstance();
    final kayitli = p.getStringList('profil_sira');
    if (kayitli == null || !mounted) return;
    const gecerli = ['seritler', 'ozet', 'listeler', 'rozetler'];
    final sira = [
      for (final b in kayitli)
        if (gecerli.contains(b)) b,
    ];
    for (final b in gecerli) {
      if (!sira.contains(b)) sira.add(b);
    }
    setState(() => _bolumSirasi = sira);
  }

  /// Profil bölümleri: kullanıcı Ayarlar'dan sıralarını değiştirebilir.
  List<Widget> _bolumUret(String ad) {
    switch (ad) {
      case 'seritler':
        return _seritlerBolumu();
      case 'ozet':
        return _ozetBolumu();
      case 'rozetler':
        return _rozetlerBolumu();
      case 'listeler':
        return _listelerBolumu();
      default:
        return const [];
    }
  }

  List<Widget> _seritlerBolumu() => [
    for (final grup in [
      (
        Icons.tv_outlined,
        'İzlediğim Diziler ({})',
        _izlenenler.where((o) => o['tur'] == 'tv').toList(),
      ),
      (
        Icons.movie_outlined,
        'İzlediğim Filmler ({})',
        _izlenenler.where((o) => o['tur'] == 'movie').toList(),
      ),
    ])
      if (grup.$3.isNotEmpty) ...[
        Row(
          children: [
            Icon(grup.$1, size: 19, color: DiziRenkler.sari),
            const SizedBox(width: 6),
            Text(
              grup.$2.cf([grup.$3.length]),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => context.push('/izlediklerim'),
              child: Text(
                'Tümünü gör'.c,
                style: const TextStyle(color: DiziRenkler.sari, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: grup.$3.length > 30 ? 30 : grup.$3.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final o = grup.$3[i] as Map<String, dynamic>;
              return MiniIcerik(
                tmdbId: o['tmdb_id'] as int,
                tur: o['tur'] as String,
                izlenenSayi: (o['sayi'] as num?)?.toInt(),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
  ];

  List<Widget> _ozetBolumu() => [
    Card(
      child: ListTile(
        leading: const Icon(Icons.auto_awesome, color: DiziRenkler.sari),
        title: Text(
          '{} özetin'.cf([DateTime.now().year]),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'Yıllık izleme istatistiklerin'.c,
          style: TextStyle(color: DiziRenkler.metin38, fontSize: 12),
        ),
        trailing: Icon(Icons.chevron_right, color: DiziRenkler.metin38),
        onTap: () => context.push('/ozet/${DateTime.now().year}'),
      ),
    ),
    const SizedBox(height: 16),
  ];

  List<Widget> _rozetlerBolumu() => [
    if (_rozetler.isNotEmpty) ...[
      Row(
        children: [
          const Icon(
            Icons.military_tech_outlined,
            size: 20,
            color: DiziRenkler.sari,
          ),
          const SizedBox(width: 6),
          Text(
            'Rozetler'.c,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final r in _rozetler)
            _RozetCipi(rozet: r as Map<String, dynamic>),
        ],
      ),
      const SizedBox(height: 16),
    ],
  ];

  List<Widget> _listelerBolumu() => [
    Row(
      children: [
        const Icon(Icons.playlist_play, size: 20, color: DiziRenkler.sari),
        const SizedBox(width: 6),
        Text(
          'Listelerim'.c,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        IconButton(
          onPressed: _yeniListe,
          icon: const Icon(Icons.add, color: DiziRenkler.sari),
        ),
      ],
    ),
    // Otomatik izlenenler listesi (silinemez, kapak kolajı arka planlı)
    if (_izlenenler.isNotEmpty)
      _IzlenenlerKarti(
        ogeler: _izlenenler,
        onTap: () => context.push('/izlediklerim'),
      ),
    for (final l in _listeler)
      Card(
        child: ListTile(
          // Dokununca liste içeriği modalda açılır (başkasının profilindekiyle aynı)
          onTap: () => ListeSheet.ac(
            context,
            listeId: (l['id'] as num).toInt(),
            ad: l['ad'] as String,
          ),
          leading: const Icon(Icons.list, color: DiziRenkler.sari),
          title: Text(l['ad'] as String),
          subtitle: Text('{} içerik'.cf([l['oge_sayisi']])),
          trailing: IconButton(
            icon: Icon(Icons.delete_outline, color: DiziRenkler.metin38),
            onPressed: () async {
              // Silmeden önce onay iste; hatayı kullanıcıya göster
              final onay = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: DiziRenkler.koyuGri,
                  title: Text('Listeyi sil?'.c),
                  content: Text(l['ad'] as String),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('İptal'.c),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('Tamam'.c),
                    ),
                  ],
                ),
              );
              if (onay != true) return;
              try {
                await Api.delete('/listeler/${l['id']}');
                _yukle();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
          ),
        ),
      ),
    const SizedBox(height: 16),
  ];

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      final sonuclar = await Future.wait([
        Api.get('/istatistiklerim'),
        Api.get('/kitapligim'),
        Api.get('/listelerim'),
        Api.get('/profilim'),
        Api.get('/izlediklerim'),
        Api.get(
          '/rozetler',
        ).catchError((_) => <String, dynamic>{'rozetler': <dynamic>[]}),
      ]);
      if (!mounted) return;
      setState(() {
        _istatistik = sonuclar[0] as Map<String, dynamic>;
        _kitaplik = sonuclar[1] as Map<String, dynamic>;
        _listeler = sonuclar[2]['listeler'] as List<dynamic>;
        _profil = sonuclar[3] as Map<String, dynamic>;
        _izlenenler = sonuclar[4]['ogeler'] as List<dynamic>;
        _rozetler = sonuclar[5]['rozetler'] as List<dynamic>? ?? [];
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
    try {
      final bagla = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: DiziRenkler.koyuGri,
        builder: (context) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Hesabını Bağla'.c,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'İzleme geçmişin ve listelerin korunur; artık her cihazdan girebilirsin.'
                    .c,
                textAlign: TextAlign.center,
                style: TextStyle(color: DiziRenkler.metin54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(hintText: 'E-posta'.c),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: kullaniciAdi,
                decoration: InputDecoration(
                  hintText: 'Yeni kullanıcı adı (isteğe bağlı)'.c,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: sifre,
                obscureText: true,
                decoration: InputDecoration(hintText: 'Şifre'.c),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Bağla'.c),
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
            sifre.text,
          );
          if (!mounted) return;
          await context.read<Oturum>().girisYapildi(kullanici);
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Hesabın bağlandı!'.c)));
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    } finally {
      email.dispose();
      kullaniciAdi.dispose();
      sifre.dispose();
    }
  }

  /// Yorum sayacına dokununca: kendi yorumların, dokununca tam hedefe gider.
  void _yorumlarAc(String kullaniciAdi) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DiziRenkler.koyuGri,
      builder: (_) => _YorumlarSheet(kullaniciAdi: kullaniciAdi),
    );
  }

  void _takipListe(String kullaniciAdi, bool takipciler) {
    context.push(
      '/kullanici/$kullaniciAdi/${takipciler ? 'takipciler' : 'takip'}',
    );
  }

  Future<void> _yeniListe() async {
    final ad = TextEditingController();
    try {
      final olustur = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: DiziRenkler.koyuGri,
          title: Text('Yeni Liste'.c),
          content: TextField(
            controller: ad,
            autofocus: true,
            decoration: InputDecoration(hintText: 'Liste adı'.c),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('İptal'.c),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Oluştur'.c),
            ),
          ],
        ),
      );
      if (olustur == true && ad.text.trim().isNotEmpty) {
        try {
          await Api.post('/listeler', {'ad': ad.text.trim()});
          _yukle();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }
      }
    } finally {
      ad.dispose();
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
        child: CircularProgressIndicator(color: DiziRenkler.sari),
      );
    } else {
      final st = _istatistik!;
      final dakika = (st['tahmini_dakika'] as num?)?.toInt() ?? 0;
      final durumlar = (_kitaplik?['durumlar'] as List<dynamic>? ?? []);
      final gruplar = <String, List<dynamic>>{};
      for (final d in durumlar) {
        gruplar.putIfAbsent(d['durum'] as String, () => []).add(d);
      }
      const durumAdlari = {
        'izliyorum': (Icons.play_circle_outline, 'İzliyorum'),
        'izleyecegim': (Icons.bookmark_add_outlined, 'İzleyeceğim'),
        'bitirdim': (Icons.check_circle_outline, 'Bitirdim'),
        'biraktim': (Icons.cancel_outlined, 'Bıraktım'),
      };

      govde = RefreshIndicator(
        color: DiziRenkler.sari,
        onRefresh: _yukle,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Kapak resmi (varsa)
            if (dosyaUrl(_profil?['kapak'] as String?) != null)
              SizedBox(
                height: 130,
                width: double.infinity,
                child: Image.network(
                  dosyaUrl(_profil!['kapak'] as String)!,
                  fit: BoxFit.cover,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profil başlığı: avatar (GIF olabilir), bio, ülke
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 38,
                        backgroundColor: DiziRenkler.kart,
                        backgroundImage:
                            dosyaUrl(_profil?['avatar'] as String?) != null
                            ? NetworkImage(
                                dosyaUrl(_profil!['avatar'] as String)!,
                              )
                            : null,
                        child: _profil?['avatar'] == null
                            ? Icon(
                                Icons.person,
                                size: 38,
                                color: DiziRenkler.metin38,
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '@$kullaniciAdi',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if ((_profil?['bio'] as String?)?.isNotEmpty ==
                                true)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  _profil!['bio'] as String,
                                  style: TextStyle(
                                    color: DiziRenkler.metin70,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            if ((_profil?['ulke'] as String?)?.isNotEmpty ==
                                true)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: DiziRenkler.sari,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      _profil!['ulke'] as String,
                                      style: TextStyle(
                                        color: DiziRenkler.metin54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 6),
                            // Takipçi / takip (kendi listelerine gider)
                            Row(
                              children: [
                                _TakipSayac(
                                  deger: '${st['takipci_sayisi'] ?? 0}',
                                  etiket: 'takipçi'.c,
                                  onTap: () => _takipListe(kullaniciAdi, true),
                                ),
                                const SizedBox(width: 16),
                                _TakipSayac(
                                  deger: '${st['takip_sayisi'] ?? 0}',
                                  etiket: 'takip'.c,
                                  onTap: () => _takipListe(kullaniciAdi, false),
                                ),
                              ],
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
                      color: DiziRenkler.sari,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _hesabiBagla,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              const Icon(Icons.link, color: Colors.black),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Misafir hesabındasın — e-postanla bağla, verilerini kaybetme!'
                                      .c,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.black,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  // İstatistik kartları (dar ekranda alt satıra kayar)
                  LayoutBuilder(
                    builder: (context, kutu) {
                      const bosluk = 10.0;
                      final genislik = (kutu.maxWidth - bosluk * 3) / 4;
                      return Wrap(
                        spacing: bosluk,
                        runSpacing: bosluk,
                        children: [
                          // Sayaçlar tıklanır: ilgili liste/modal açılır
                          _StatKarti(
                            genislik: genislik,
                            deger: '${st['izlenen_bolum']}',
                            etiket: 'Bölüm'.c,
                            onTap: () => context.push('/izlediklerim?tur=tv'),
                          ),
                          _StatKarti(
                            genislik: genislik,
                            deger: '${st['izlenen_film']}',
                            etiket: 'Film'.c,
                            onTap: () =>
                                context.push('/izlediklerim?tur=movie'),
                          ),
                          _StatKarti(
                            genislik: genislik,
                            deger: '${st['takip_edilen_dizi']}',
                            etiket: 'Dizi'.c,
                            onTap: () => context.push('/izlediklerim?tur=tv'),
                          ),
                          _StatKarti(
                            genislik: genislik,
                            deger: '${st['yorum_sayisi'] ?? 0}',
                            etiket: 'Yorum'.c,
                            onTap: () => _yorumlarAc(kullaniciAdi),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  // Toplam ekran süresi (yıl/ay/gün)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: DiziRenkler.kart,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2A2A2F)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          color: DiziRenkler.sari,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Toplam ekran süresi'.c,
                          style: TextStyle(
                            color: DiziRenkler.metin54,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          sureBicimle(dakika),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: DiziRenkler.sari,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Kitaplık grupları
                  // Sabit sıra: İzliyorum → İzleyeceğim → Bitirdim → Bıraktım
                  for (final e in [
                    for (final durum in durumAdlari.keys)
                      if (gruplar[durum]?.isNotEmpty == true)
                        MapEntry(durum, gruplar[durum]!),
                  ]) ...[
                    // Başlığa tıklayınca o durumun tam listesi açılır
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => context.push('/kitaplik/${e.key}'),
                      child: Row(
                        children: [
                          Icon(
                            durumAdlari[e.key]?.$1 ?? Icons.tv,
                            size: 19,
                            color: DiziRenkler.sari,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            (durumAdlari[e.key]?.$2 ?? e.key).c,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
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
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 190,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: e.value.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, i) {
                          final d = e.value[i] as Map<String, dynamic>;
                          return MiniIcerik(
                            tmdbId: d['tmdb_id'] as int,
                            tur: d['tur'] as String,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Bölümler kullanıcı sırasına göre (Ayarlar > Profil düzeni)
                  for (final bolum in _bolumSirasi) ..._bolumUret(bolum),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('@$kullaniciAdi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_search),
            tooltip: 'Kişi ara'.c,
            onPressed: () => context.push('/kisi-ara'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await context.push('/ayarlar');
              _yukle();
              _siraYukle();
            },
          ),
        ],
      ),
      body: govde,
    );
  }
}

class _TakipSayac extends StatelessWidget {
  final String deger;
  final String etiket;
  final VoidCallback onTap;
  const _TakipSayac({
    required this.deger,
    required this.etiket,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: RichText(
          // RichText tema rengini devralmaz; renk açıkça verilmeli
          text: TextSpan(
            style: TextStyle(fontSize: 13, color: DiziRenkler.metin),
            children: [
              TextSpan(
                text: deger,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: DiziRenkler.metin,
                ),
              ),
              TextSpan(
                text: ' $etiket',
                style: TextStyle(color: DiziRenkler.metin54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatKarti extends StatelessWidget {
  final String deger;
  final String etiket;
  final double genislik;
  final VoidCallback? onTap;
  const _StatKarti({
    required this.deger,
    required this.etiket,
    required this.genislik,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: genislik,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
          decoration: BoxDecoration(
            color: DiziRenkler.kart,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A2A2F)),
          ),
          child: Column(
            children: [
              Text(
                deger,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 19,
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

/// İzlediklerim kartı: son izlenen 5 içeriğin kapağı arka plan kolajı,
/// üstünde başlık ve sayı. Tıklayınca tüm ızgara açılır.
class _IzlenenlerKarti extends StatefulWidget {
  final List<dynamic> ogeler;
  final VoidCallback onTap;
  const _IzlenenlerKarti({required this.ogeler, required this.onTap});

  @override
  State<_IzlenenlerKarti> createState() => _IzlenenlerKartiState();
}

class _IzlenenlerKartiState extends State<_IzlenenlerKarti> {
  List<String> _kapaklar = [];

  @override
  void initState() {
    super.initState();
    _kapaklariYukle();
  }

  Future<void> _kapaklariYukle() async {
    final ilk5 = widget.ogeler.take(5).toList();
    final sonuc = await Future.wait(
      ilk5.map((o) async {
        try {
          final d = await Api.get('/tmdb/${o['tur']}/${o['tmdb_id']}');
          final yol = (d['backdrop_path'] ?? d['poster_path']) as String?;
          return posterUrl(yol, boyut: 'w500');
        } catch (_) {
          return null;
        }
      }),
    );
    if (mounted) {
      setState(() => _kapaklar = sonuc.whereType<String>().toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: SizedBox(
          height: 116,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Kapak kolajı
              if (_kapaklar.isNotEmpty)
                Row(
                  children: [
                    for (final k in _kapaklar)
                      Expanded(
                        child: CachedNetworkImage(
                          imageUrl: k,
                          fit: BoxFit.cover,
                        ),
                      ),
                  ],
                )
              else
                Container(color: DiziRenkler.kart),
              // Karartma
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      DiziRenkler.siyah.withValues(alpha: 0.85),
                      DiziRenkler.siyah.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
              // Başlık
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.visibility,
                          color: DiziRenkler.sari,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'İzlediklerim'.c,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right, color: Colors.white70),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '{} içerik · otomatik'.cf([widget.ogeler.length]),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rozet çipi: kazanılanlar sarı, kalanlar soluk + ilerleme.
class _RozetCipi extends StatelessWidget {
  final Map<String, dynamic> rozet;

  const _RozetCipi({required this.rozet});

  static const _bilgi = {
    'ilk_bolum': (Icons.play_arrow_rounded, 'İlk Bölüm'),
    'bolum_100': (Icons.local_fire_department_outlined, '100 Bölüm'),
    'bolum_500': (Icons.bolt_outlined, '500 Bölüm'),
    'bolum_1000': (Icons.workspace_premium_outlined, '1000 Bölüm'),
    'bolum_5000': (Icons.diamond_outlined, '5000 Bölüm'),
    'ilk_film': (Icons.movie_outlined, 'İlk Film'),
    'film_10': (Icons.movie_filter_outlined, '10 Film'),
    'film_50': (Icons.theaters_outlined, '50 Film'),
    'film_100': (Icons.camera_roll_outlined, '100 Film'),
    'ilk_yorum': (Icons.chat_bubble_outline, 'İlk Yorum'),
    'yorum_25': (Icons.forum_outlined, '25 Yorum'),
    'yorum_100': (Icons.campaign_outlined, '100 Yorum'),
    'puan_10': (Icons.star_outline_rounded, '10 Puan'),
    'puan_50': (Icons.star_half_rounded, '50 Puan'),
    'puan_100': (Icons.stars_outlined, '100 Puan'),
    'ilk_takipci': (Icons.person_add_alt, 'İlk Takipçi'),
    'takipci_10': (Icons.group_outlined, '10 Takipçi'),
    'takipci_50': (Icons.groups_outlined, '50 Takipçi'),
    'bitiren_10': (Icons.emoji_events_outlined, '10 Dizi Bitirdin'),
    'bitiren_25': (Icons.military_tech_outlined, '25 Dizi Bitirdin'),
    'bitiren_50': (Icons.workspace_premium, '50 Dizi Bitirdin'),
    'begeni_10': (Icons.favorite_border, '10 Beğeni'),
    'begeni_100': (Icons.volunteer_activism_outlined, '100 Beğeni'),
  };

  @override
  Widget build(BuildContext context) {
    final kod = rozet['kod'] as String? ?? '';
    final kazanildi = rozet['kazanildi'] == true;
    final (ikon, ad) = _bilgi[kod] ?? (Icons.military_tech_outlined, kod);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: kazanildi ? DiziRenkler.sari : DiziRenkler.kart,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ikon,
            size: 15,
            color: kazanildi ? Colors.black : DiziRenkler.metin38,
          ),
          const SizedBox(width: 5),
          Text(
            ad.c,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kazanildi ? Colors.black : DiziRenkler.metin38,
            ),
          ),
          if (!kazanildi) ...[
            const SizedBox(width: 4),
            Text(
              '${rozet['deger']}/${rozet['esik']}',
              style: TextStyle(fontSize: 10, color: DiziRenkler.metin24),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kendi yorumların modalı: içerik adı + bölüm bilgisiyle listeler;
/// karta dokununca ilgili sayfaya (bölüm/dizi/film) tam hedefle gider.
class _YorumlarSheet extends StatefulWidget {
  final String kullaniciAdi;
  const _YorumlarSheet({required this.kullaniciAdi});

  @override
  State<_YorumlarSheet> createState() => _YorumlarSheetState();
}

class _YorumlarSheetState extends State<_YorumlarSheet> {
  Map<String, dynamic>? _veri;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final d = await Api.acikProfil(widget.kullaniciAdi);
      if (mounted) setState(() => _veri = d);
    } catch (e) {
      if (mounted) setState(() => _hata = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final yorumlar = (_veri?['yorumlar'] as List<dynamic>? ?? []);
    final icerikler = _veri?['icerikler'] as Map<String, dynamic>? ?? {};

    Widget govde;
    if (_hata != null) {
      govde = Center(
        child: Text(_hata!, style: TextStyle(color: DiziRenkler.metin54)),
      );
    } else if (_veri == null) {
      govde = const Center(
        child: CircularProgressIndicator(color: DiziRenkler.sari),
      );
    } else if (yorumlar.isEmpty) {
      govde = Center(
        child: Text(
          'Henüz yorum yok.'.c,
          style: TextStyle(color: DiziRenkler.metin38),
        ),
      );
    } else {
      govde = ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
        children: [
          for (final y in yorumlar)
            ProfilYorumKarti(
              yorum: y as Map<String, dynamic>,
              icerikler: icerikler,
            ),
        ],
      );
    }

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline, color: DiziRenkler.sari),
                const SizedBox(width: 8),
                Text(
                  'Yorumlar'.c,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (yorumlar.isNotEmpty)
                  Text(
                    '${yorumlar.length}',
                    style: TextStyle(color: DiziRenkler.metin54),
                  ),
              ],
            ),
          ),
          Expanded(child: govde),
        ],
      ),
    );
  }
}
