import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../ceviri.dart';
import '../gorsel_basliklari.dart';
import '../tema.dart';
import 'arama_cubugu.dart';
import 'ortak.dart';
import 'sirket.dart';

class AramaEkrani extends StatefulWidget {
  const AramaEkrani({super.key});

  @override
  State<AramaEkrani> createState() => _AramaEkraniState();
}

class _AramaEkraniState extends State<AramaEkrani>
    with AutomaticKeepAliveClientMixin {
  final _kutu = TextEditingController();
  Timer? _geciktirici;
  List<dynamic> _sonuclar = [];
  List<dynamic> _kisiler = [];
  List<dynamic> _sirketler = [];
  List<dynamic> _kullanicilar = [];
  bool _yukleniyor = false;
  List<String> _gecmis = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) {
        setState(() => _gecmis = p.getStringList('arama_gecmisi') ?? []);
      }
    });
  }

  Future<void> _gecmiseEkle(String sorgu) async {
    final s = sorgu.trim();
    if (s.length < 2) return;
    _gecmis.remove(s);
    _gecmis.insert(0, s);
    if (_gecmis.length > 10) _gecmis = _gecmis.sublist(0, 10);
    final p = await SharedPreferences.getInstance();
    await p.setStringList('arama_gecmisi', _gecmis);
  }

  Future<void> _gecmistenSil(String sorgu) async {
    setState(() => _gecmis = List.of(_gecmis)..remove(sorgu));
    final p = await SharedPreferences.getInstance();
    await p.setStringList('arama_gecmisi', _gecmis);
  }

  @override
  void dispose() {
    _kutu.dispose();
    _geciktirici?.cancel();
    super.dispose();
  }

  void _degisti(String sorgu) {
    _geciktirici?.cancel();
    _geciktirici = Timer(const Duration(milliseconds: 450), () => _ara(sorgu));
  }

  Future<void> _ara(String sorgu) async {
    if (sorgu.trim().length < 2) {
      setState(() {
        _sonuclar = [];
        _kisiler = [];
        _sirketler = [];
        _kullanicilar = [];
      });
      return;
    }
    setState(() => _yukleniyor = true);
    try {
      final q = Uri.encodeComponent(sorgu.trim());
      // İçerik/kişi (TMDB) ve uygulama kullanıcıları birlikte aranır.
      final yanitlar = await Future.wait([
        Api.get('/ara?q=$q'),
        Api.get('/kullanici-ara?q=$q').catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;
      setState(() {
        final ham = yanitlar[0]['results'] as List<dynamic>? ?? [];
        _sonuclar = aramaIcerikListesi(ham);
        _kisiler = aramaKisiListesi(ham);
        _sirketler = aramaSirketListesi(ham);
        _kullanicilar = yanitlar[1]['kullanicilar'] as List<dynamic>? ?? [];
      });
      if (_sonuclar.isNotEmpty ||
          _kisiler.isNotEmpty ||
          _sirketler.isNotEmpty) {
        _gecmiseEkle(sorgu);
      }
    } catch (e) {
      // Sessiz yutma yok: arama başarısızsa kullanıcıya bildir.
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(title: Text('Arama'.c)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _kutu,
              onChanged: _degisti,
              decoration: InputDecoration(
                hintText: 'Dizi, film, kişi veya şirket ara...'.c,
                prefixIcon: Icon(Icons.search, color: DiziRenkler.metin54),
                suffixIcon: _yukleniyor
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: DiziRenkler.sari,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child:
                _sonuclar.isEmpty &&
                    _kisiler.isEmpty &&
                    _sirketler.isEmpty &&
                    _kullanicilar.isEmpty
                ? (_gecmis.isEmpty
                      ? BosDurum(
                          ikon: Icons.local_movies_outlined,
                          baslik: 'Aramaya başla'.c,
                        )
                      // Geçmiş aramalar: satır satır, sağda çarpı ile silinir
                      : ListView(
                          padding: const EdgeInsets.only(top: 4, bottom: 16),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.history,
                                    size: 16,
                                    color: DiziRenkler.metin54,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Son aramalar'.c,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: DiziRenkler.metin54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            for (final g in _gecmis)
                              ListTile(
                                key: ValueKey('gecmis-$g'),
                                dense: true,
                                visualDensity: const VisualDensity(
                                  vertical: -2,
                                ),
                                leading: Icon(
                                  Icons.history,
                                  size: 20,
                                  color: DiziRenkler.metin38,
                                ),
                                title: Text(
                                  g,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: IconButton(
                                  tooltip: 'Sil'.c,
                                  onPressed: () => _gecmistenSil(g),
                                  icon: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: DiziRenkler.metin54,
                                  ),
                                ),
                                onTap: () {
                                  _kutu.text = g;
                                  _ara(g);
                                },
                              ),
                          ],
                        ))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Eşleşen uygulama kullanıcıları: yatay şerit
                      if (_kullanicilar.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 18,
                                color: DiziRenkler.sariMetin,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Kullanıcılar'.c,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 92,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _kullanicilar.length,
                            itemBuilder: (context, i) {
                              final k =
                                  _kullanicilar[i] as Map<String, dynamic>;
                              return _KullaniciKutusu(kullanici: k);
                            },
                          ),
                        ),
                      ],
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const PosterIzgarasi(
                            satirBoslugu: 14,
                            bosluk: 10,
                          ),
                          itemCount: _sonuclar.length + _kisiler.length,
                          itemBuilder: (context, i) {
                            if (i < _kisiler.length) {
                              return _KisiKarti(
                                kisi: _kisiler[i] as Map<String, dynamic>,
                              );
                            }
                            return PosterKarti(
                              icerik:
                                  _sonuclar[i - _kisiler.length]
                                      as Map<String, dynamic>,
                            );
                          },
                        ),
                      ),
                      // Şirketler dizi/film ızgarasından SONRA (kullanıcı isteği).
                      if (_sirketler.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.apartment_outlined,
                                size: 18,
                                color: DiziRenkler.sariMetin,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Şirketler'.c,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 92,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _sirketler.take(8).length,
                            itemBuilder: (context, i) {
                              final s = _sirketler[i] as Map<String, dynamic>;
                              return _SirketKutusu(sirket: s);
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Arama sonucundaki uygulama kullanıcısı: avatar + @ad, dokununca profil.
class _KullaniciKutusu extends StatelessWidget {
  final Map<String, dynamic> kullanici;
  const _KullaniciKutusu({required this.kullanici});

  @override
  Widget build(BuildContext context) {
    final av = dosyaUrl(kullanici['avatar'] as String?);
    final ad = kullanici['kullanici_adi'] as String;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => kullaniciyaGit(context, ad),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KullaniciAvatari(
              url: av,
              kullaniciAdi: ad,
              yaricap: 26,
              arkaplan: DiziRenkler.kart,
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: 72,
              child: Text(
                '@$ad',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KisiKarti extends StatelessWidget {
  final Map<String, dynamic> kisi;
  const _KisiKarti({required this.kisi});

  @override
  Widget build(BuildContext context) {
    final foto = posterUrl(kisi['profile_path'] as String?, boyut: 'w185');
    final alt = kisiAramaAltYazi(kisi);
    return InkWell(
      key: Key('arama-kisi-${aramaTmdbId(kisi)}'),
      onTap: () => context.push('/kisi/${kisi['id']}'),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: foto == null
                  ? Container(
                      color: DiziRenkler.kart,
                      child: Icon(Icons.person, color: DiziRenkler.metin),
                    )
                  : CachedNetworkImage(
                      imageUrl: foto,
                      httpHeaders: gorselBasliklari(foto),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorWidget: (_, _, _) => Container(
                        color: DiziRenkler.kart,
                        child: Icon(Icons.person, color: DiziRenkler.metin),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.theater_comedy_outlined,
                size: 13,
                color: DiziRenkler.sariMetin,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  kisi['name'] as String? ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (alt.isNotEmpty)
            Text(
              alt,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: DiziRenkler.metin54),
            ),
        ],
      ),
    );
  }
}

/// Yatay şeritteki şirket: logo + ad, dokununca `/sirket/:id`.
class _SirketKutusu extends StatelessWidget {
  final Map<String, dynamic> sirket;
  const _SirketKutusu({required this.sirket});

  @override
  Widget build(BuildContext context) {
    final ad = (sirket['name'] as String?) ?? '';
    final id = aramaTmdbId(sirket);
    return SizedBox(
      width: 88,
      child: InkWell(
        key: Key('arama-sirket-$id'),
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          if (id == null) return;
          context.push(sirketYolu(id, ad: ad));
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FirmaLogosu(
                  logoYolu: sirket['logo_path'] as String?,
                  genislik: 56,
                  yukseklik: 40,
                ),
                const SizedBox(height: 5),
                Text(
                  ad,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
