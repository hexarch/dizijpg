import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import '../liste_gorunumu.dart';
import '../puan_favori_deposu.dart';
import '../tema.dart';
import 'icerik_satiri.dart';
import 'ortak.dart';

/// `/kullanici/:ad/izlenenler/:tur` — bir kullanıcının İZLEDİĞİ dizilerin ya da
/// filmlerin SALT OKUNUR, SAYFALI tam listesi.
///
/// ---------------------------------------------------------------------------
/// NEDEN VAR (7 Eyl 2026, kullanıcı bildirimi — birebir)
/// ---------------------------------------------------------------------------
/// *"1000 tane film izlemiş birisinin profilini ziyaret ettim, izlediği filmler
/// kısmına tıkladığımda ilk 100 film falan gözüküyordu, daha sonrasında aşağıya
/// kaydırılmıyordu"* ve *"o listede liste görünümüne geçiş yok ama kendi
/// profilimdeki diziler filmler kısmında liste görünümüne geçebiliyorum"*.
///
/// ESKİ DAVRANIŞ: sayaç/başlık dokunuşu bir alt sayfa (bottom sheet) açıyor ve
/// o sayfa YALNIZ `/profil/:ad` yanıtındaki kırpılmış diziyi çiziyordu — tür
/// başına 60 kayıt. Başlık "İzlediği Filmler (451)" diyordu, ızgarada 60 afiş
/// vardı ve devamını isteyecek bir çağrı YOKTU: liste bitmiş gibi görünüyordu.
/// Alt sayfada AppBar da olmadığı için görünüm anahtarı ([ListeGorunumuDugmesi])
/// takılacak yer bulamamıştı; sahibinin `/izlediklerim?tur=` ekranında o düğme
/// 1 Eyl'den beri vardı, ziyaretçininkinde hiç olmadı.
///
/// YENİ DAVRANIŞ: alt sayfa yerine TAM SAYFA — sahibinin ekranıyla (
/// [IzlenenlerEkrani]) aynı iskelet, aynı görünüm tercihi, aynı afiş/satır
/// ikilisi. Fark yalnız yazma yetkisinde: burada sürükle-bırak sıralama ve
/// "en üste taşı" YOK, çünkü başkasının listesinin sırası ziyaretçinin işi
/// değil.
///
/// ---------------------------------------------------------------------------
/// SAYFALAMA
/// ---------------------------------------------------------------------------
/// `GET /profil/:ad/izlenenler?tur=&ofset=` 60'ar satır döner ve sırası
/// profildeki şeridin ÖNEKİNİN devamıdır (sunucudaki gerekçeye bak). Kaydırma
/// listenin dibine 600 px yaklaşınca bir sonraki sayfa istenir; istek uçarken
/// ikinci bir istek AÇILMAZ ([_yukleniyor]) ve son sayfa gelince
/// ([_bitti]) kaydırma artık istek doğurmaz — yoksa dip her karede yeniden
/// tetiklenirdi.
///
/// TOPLAM SAYIYI SUNUCU SÖYLER: başlıktaki sayı elde kaç öğe olduğunu değil
/// listenin GERÇEK boyutunu yazar (`toplam`), yoksa yükleme ilerledikçe başlık
/// değişir ve kullanıcı listenin nerede biteceğini kestiremezdi.
class KullaniciIzlenenlerEkrani extends StatefulWidget {
  final String kullaniciAdi;

  /// 'tv' | 'movie'
  final String tur;

  const KullaniciIzlenenlerEkrani({
    super.key,
    required this.kullaniciAdi,
    required this.tur,
  });

  @override
  State<KullaniciIzlenenlerEkrani> createState() =>
      _KullaniciIzlenenlerEkraniState();
}

class _KullaniciIzlenenlerEkraniState extends State<KullaniciIzlenenlerEkrani> {
  final _kaydirma = ScrollController();
  final List<dynamic> _ogeler = [];

  int _toplam = 0;
  bool _gizli = false;
  bool _bitti = false;
  bool _yukleniyor = false;

  /// İlk sayfa daha gelmediyse iskelet çizilir; sonraki sayfaların hatası
  /// listeyi silmez (altta yeniden dene şeridi çıkar).
  bool _ilkSayfaGeldi = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _kaydirma.addListener(_kaydirdi);
    // Satır görünümü açıksa puan/kalp/emoji deposu gerekir; [IcerikSatiri]
    // satır başına istek atmaz, tek toplu depodan okur.
    if (ListeGorunumu.satir.value) PuanFavoriDeposu.yukle();
    _sayfaCek();
  }

  @override
  void dispose() {
    _kaydirma.removeListener(_kaydirdi);
    _kaydirma.dispose();
    super.dispose();
  }

  void _kaydirdi() {
    if (!_kaydirma.hasClients) return;
    final kalan =
        _kaydirma.position.maxScrollExtent - _kaydirma.position.pixels;
    if (kalan < 600) _sayfaCek();
  }

  Future<void> _sayfaCek() async {
    if (_yukleniyor || _bitti || _gizli) return;
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final d = await Api.get(
        '/profil/${Uri.encodeComponent(widget.kullaniciAdi)}/izlenenler'
        '?tur=${widget.tur}&ofset=${_ogeler.length}',
      );
      if (!mounted) return;
      final gelen = (d['ogeler'] as List<dynamic>?) ?? [];
      setState(() {
        _yukleniyor = false;
        _ilkSayfaGeldi = true;
        if (d['gizli'] == true) {
          _gizli = true;
          _bitti = true;
          return;
        }
        // Toplam yalnız DOLU sayfadan okunur: son (boş) sayfa 0 döndürüyor ve
        // onu yazmak başlıktaki sayıyı sıfırlardı.
        if (gelen.isNotEmpty) _toplam = _sayi(d['toplam']) ?? _toplam;
        _ogeler.addAll(gelen);
        // Sunucunun söylediği sayfa boyundan AZ geldiyse liste bitmiştir; ayrıca
        // boş sayfa da bitiştir (tam katta sonlanan listede son istek boş gelir).
        final boy = _sayi(d['sayfa_boyu']) ?? 60;
        if (gelen.length < boy) _bitti = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _hata = e.toString();
      });
    }
  }

  /// SAYI OKUMA — METİN DE KABUL (7 Eyl 2026, canlıda yakalandı).
  ///
  /// Postgres'te `count(*)` bigint'tir ve node-pg int8'i JSON'a METİN olarak
  /// yazar ("451"). Sunucu tarafında `::int` ile düzeltildi ama istemci bunu
  /// VARSAYMAZ: eski bir sunucuya (ya da başka bir sayaç alanına) düşünce
  /// `as num` sessizce null verir ve başlıkta "İzlediği Filmler (60)" yazardı —
  /// yani hatanın kendisi geri gelirdi, üstelik sessizce.
  int? _sayi(Object? d) => d is num ? d.toInt() : int.tryParse('$d');

  /// Dip şeridi: yükleniyor halkası, hata + yeniden dene, ya da hiçbir şey.
  Widget? _dipSerit() {
    if (_hata != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: TextButton.icon(
            onPressed: _sayfaCek,
            icon: const Icon(Icons.refresh),
            label: Text('Tekrar dene'.c),
          ),
        ),
      );
    }
    if (_yukleniyor && _ilkSayfaGeldi) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ListeGorunumu.satir,
      builder: (context, satirKipi, _) {
        Widget govde;
        if (!_ilkSayfaGeldi && _hata != null) {
          govde = HataGorunumu(mesaj: _hata!, tekrar: _sayfaCek);
        } else if (!_ilkSayfaGeldi) {
          govde = GridView.builder(
            padding: EdgeInsets.fromLTRB(16, 16, 16, altGuvenli(context)),
            gridDelegate: const PosterIzgarasi(satirBoslugu: 14, bosluk: 10),
            itemCount: 9,
            itemBuilder: (_, _) => const IskeletKutu(genislik: double.infinity),
          );
        } else if (_gizli) {
          govde = BosDurum(
            ikon: Icons.lock_outline,
            baslik: 'Bu liste gizli'.c,
            ipucu:
                'Bu kullanıcı izleme listelerini gizli tutmayı tercih ediyor.'
                    .c,
          );
        } else if (_ogeler.isEmpty) {
          govde = BosDurum(
            ikon: widget.tur == 'tv' ? Icons.tv_outlined : Icons.movie_outlined,
            baslik: 'Bu listede henüz içerik yok'.c,
          );
        } else {
          govde = satirKipi ? _satirListesi() : _izgara();
        }

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            // Kitaplık paylaşım sayfasıyla (kullanici_kitaplik.dart) aynı
            // başlık kalıbı: liste adı üstte, sahibi altta.
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_baslik(), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  '@${widget.kullaniciAdi}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: DiziRenkler.metin54,
                  ),
                ),
              ],
            ),
            actions: [
              // GÖRÜNÜM ANAHTARI — sahibinin ekranındakiyle AYNI düğme ve AYNI
              // (cihazda kalıcı) tercih; altı kitaplık listesi tek anahtarı
              // paylaşıyor, ziyaretçi listesi de o ailenin üyesi.
              if (!_gizli && _ogeler.isNotEmpty) const ListeGorunumuDugmesi(),
            ],
          ),
          body: OrtaKolon(azami: masaustuIcerikGenisligi, cocuk: govde),
        );
      },
    );
  }

  /// Başlıktaki sayı profildeki şeritle AYNI kaynaktan (sunucunun `toplam`ı).
  String _baslik() {
    final anahtar = widget.tur == 'tv'
        ? 'İzlediği Diziler ({})'
        : 'İzlediği Filmler ({})';
    return anahtar.cf([_toplam > 0 ? _toplam : _ogeler.length]);
  }

  Widget _izgara() {
    final dip = _dipSerit();
    return CustomScrollView(
      controller: _kaydirma,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, dip == null ? 16 : 0),
          sliver: SliverGrid.builder(
            gridDelegate: const PosterIzgarasi(satirBoslugu: 14, bosluk: 10),
            itemCount: _ogeler.length,
            itemBuilder: (context, i) {
              final o = _ogeler[i] as Map<String, dynamic>;
              return MiniIcerik(
                key: ValueKey('izl-${o['tur']}-${o['tmdb_id']}'),
                tmdbId: (o['tmdb_id'] as num).toInt(),
                tur: o['tur'] as String,
                genislik: double.infinity,
                izlenenSayi: (o['sayi'] as num?)?.toInt(),
              );
            },
          ),
        ),
        if (dip != null) SliverToBoxAdapter(child: dip),
        SliverToBoxAdapter(child: SizedBox(height: altGuvenli(context))),
      ],
    );
  }

  Widget _satirListesi() {
    final dip = _dipSerit();
    return ListView.separated(
      controller: _kaydirma,
      padding: EdgeInsets.fromLTRB(12, 4, 12, altGuvenli(context)),
      itemCount: _ogeler.length + (dip == null ? 0 : 1),
      separatorBuilder: (_, _) =>
          Divider(height: 1, thickness: 1, color: DiziRenkler.metin12),
      itemBuilder: (context, i) {
        if (i >= _ogeler.length) return dip!;
        final o = _ogeler[i] as Map<String, dynamic>;
        return IcerikSatiri(
          key: ValueKey('izl-satir-${o['tur']}-${o['tmdb_id']}'),
          tur: o['tur'] as String,
          tmdbId: (o['tmdb_id'] as num).toInt(),
          izlenenSayi: (o['sayi'] as num?)?.toInt(),
          // KİŞİSEL SÜSLER KAPALI: puan/kalp/emoji/son izleme deposu BENİM
          // verimdir. Başkasının listesinde onları basmak "bu kullanıcı 9
          // vermiş" diye okunurdu — satırdaki tek sahibine ait bilgi, ilerleme
          // çubuğunun payı olan `izlenenSayi`dir ve o sunucudan gelir.
          kisisel: false,
        );
      },
    );
  }
}
