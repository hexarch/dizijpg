import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../bayrak.dart';
import '../ceviri.dart';
import '../gorsel_basliklari.dart';
import '../tema.dart';
import 'ayarlar.dart' show ulkeler;
import 'ortak.dart';

/// ---------------------------------------------------------------------------
/// YAPIM FİRMASI SAYFASI (madde 49)
///
/// İSTEK: "Bu kişiler ve firmalar gösterilsin, TIKLANABİLİR olsun,
/// profillerine gidilebilsin." Kişilerin sayfası zaten vardı (`/kisi/:id`);
/// firmaların YOKTU — bu ekran o boşluğu kapatıyor.
///
/// NEDEN TAM SAYFA (modal değil): liste UZUN ve sayfalanıyor (Sony Pictures
/// Television'ın tek başına 239 dizisi var — canlı ölçüm 13 Ağu 2026), üstelik
/// karolara dokununca `/icerik/...` açılıyor. Modalden push edilen sayfadan
/// dönünce modal kapanır ve kullanıcı bağlamı kaybederdi. Ayrıca kendi adresi
/// olan ekran web'de paylaşılabilir ve F5'te yerinde kalır
/// (ui-ux-pro-max, Navigation/Deep Linking).
///
/// TMDB KAYNAKLARI (ikisi de `/tmdb/*` proxy'sinin beyaz listesinde):
///  * `/company/{id}` — ad, logo, ülke, merkez. Katalog verisi: 7 günlük TTL.
///  * `/discover/{tv|movie}?with_companies={id}` — firmanın yapımları.
/// ---------------------------------------------------------------------------

/// Firma sayfasının adresi. `ad` ve `tur` yalnız İLK KAREYİ iyileştirir:
/// başlık `/company/{id}` yanıtı gelmeden dolu olur ve doğru sekme seçili
/// gelir. İkisi de olmadan sayfa yine çalışır (paylaşılan çıplak bağlantı).
String sirketYolu(int id, {String? ad, String? tur}) {
  final temizAd = ad?.trim() ?? '';
  final q = <String>[
    if (temizAd.isNotEmpty) 'ad=${Uri.encodeQueryComponent(temizAd)}',
    if (tur == 'tv' || tur == 'movie') 'tur=$tur',
  ];
  return q.isEmpty ? '/sirket/$id' : '/sirket/$id?${q.join('&')}';
}

/// TMDB `origin_country` İKİ HARFLİ ISO KODUDUR ("US").
///
/// [ulkeAdi] bunu 44 dilde çözer ama TÜRKÇE'de çözemez: `ulkeAdlari`nda 'tr'
/// haritası YOKTUR — Türkçe anahtar dilidir ve profilde saklanan değerler
/// zaten Türkçe adlardır. Kodu olduğu gibi basmak Türkçe arayüzde "US"
/// göstermek olurdu. Bu yüzden çözülemeyen kod, uygulamanın kendi ülke
/// listesi ([ulkeler]) üzerinden Türkçe adına geri çevrilir — yeni çeviri
/// anahtarı gerekmez. Hiçbiri tutmazsa ham kod kalır (ekranda kaybolmasın).
Map<String, String> get _koddanTurkce =>
    _tersDizin ??= {for (final a in ulkeler) ulkeKodu(a) ?? a: a};
Map<String, String>? _tersDizin;

String ulkeAdiKoddan(String kod) {
  final cevrilmis = ulkeAdi(kod);
  if (cevrilmis.toLowerCase() != kod.toLowerCase()) return cevrilmis;
  return _koddanTurkce[kod.toLowerCase()] ?? kod;
}

/// Firma logosu.
///
/// ZEMİN NEDEN BEYAZ: TMDB logoları saydam PNG ve ezici çoğunluğu KOYU çizim
/// (Warner Bros kalkanı, Sony'nin siyah yazısı). Uygulamanın koyu zemininde
/// bunlar tamamen kaybolurdu. Beyaz kutu iki temada da AYNI görünür ve
/// stüdyo logosunun endüstri standardı sunumudur.
///
/// Logosu olmayan firmada beyaz kutu yerine kart zemini + ikon çizilir: boş
/// beyaz dikdörtgen "görsel yüklenemedi" gibi durur.
class FirmaLogosu extends StatelessWidget {
  final String? logoYolu;
  final double genislik;
  final double yukseklik;

  const FirmaLogosu({
    super.key,
    required this.logoYolu,
    this.genislik = 112,
    this.yukseklik = 56,
  });

  @override
  Widget build(BuildContext context) {
    final url = posterUrl(logoYolu, boyut: 'w185');
    final yedek = Center(
      child: Icon(
        Icons.business_outlined,
        size: yukseklik * 0.45,
        color: DiziRenkler.metin38,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: genislik,
        height: yukseklik,
        color: url == null ? DiziRenkler.kart : Colors.white,
        padding: const EdgeInsets.all(8),
        child: url == null
            ? yedek
            : CachedNetworkImage(
                imageUrl: url,
                httpHeaders: gorselBasliklari(url),
                fit: BoxFit.contain,
                // Firma adı logonun hemen altında/yanında yazıyor; ekran
                // okuyucu aynı şeyi iki kez okumasın.
                errorWidget: (_, _, _) => yedek,
                placeholder: (_, _) => const SizedBox.shrink(),
              ),
      ),
    );
  }
}

class SirketEkrani extends StatefulWidget {
  final int sirketId;

  /// Detay sayfasından taşınan ad — `/company/{id}` yanıtı gelmeden başlık
  /// dolu olsun diye. Yoksa yanıt gelene kadar genel başlık gösterilir.
  final String? sirketAdi;

  /// Hangi sekme açık başlasın: 'tv' | 'movie'.
  ///
  /// VARSAYILAN 'movie': TMDB'de firma kayıtlarının büyük çoğunluğu film
  /// stüdyosudur. Ama detay sayfasından gelindiyse ORADAKİ tür taşınır —
  /// bir diziden gelen kullanıcı doğrudan "Diziler" sekmesini görür.
  final String? baslangicTuru;

  const SirketEkrani({
    super.key,
    required this.sirketId,
    this.sirketAdi,
    this.baslangicTuru,
  });

  @override
  State<SirketEkrani> createState() => _SirketEkraniState();
}

class _SirketEkraniState extends State<SirketEkrani> {
  Map<String, dynamic>? _firma;

  /// Firma başlığının kendi hatası GÖVDEYİ DÜŞÜRMEZ: ad zaten adresten
  /// gelmiş olabilir ve yapım ızgarası bu uçtan bağımsız çalışır.
  bool _firmaDustu = false;

  late String _tur;
  final List<dynamic> _icerikler = [];
  final _kaydirma = ScrollController();
  int _sayfa = 0;
  bool _yukluyor = false;
  bool _bitti = false;
  String? _hata;

  bool get _gecerli => widget.sirketId > 0;

  @override
  void initState() {
    super.initState();
    _tur = widget.baslangicTuru == 'tv' ? 'tv' : 'movie';
    if (_gecerli) {
      _firmaYukle();
      _sonrakiSayfa();
    }
    _kaydirma.addListener(() {
      // Dibe 600 px kala sıradaki sayfa: kullanıcı beklemesin.
      if (_kaydirma.position.pixels >=
          _kaydirma.position.maxScrollExtent - 600) {
        _sonrakiSayfa();
      }
    });
  }

  @override
  void dispose() {
    _kaydirma.dispose();
    super.dispose();
  }

  Future<void> _firmaYukle() async {
    setState(() => _firmaDustu = false);
    try {
      final d = await Api.get('/tmdb/company/${widget.sirketId}');
      if (!mounted) return;
      setState(() => _firma = d);
    } catch (_) {
      if (!mounted) return;
      setState(() => _firmaDustu = true);
    }
  }

  Future<void> _sonrakiSayfa() async {
    if (_yukluyor || _bitti || !_gecerli) return;
    setState(() {
      _yukluyor = true;
      _hata = null;
    });
    try {
      final d = await Api.get(
        '/tmdb/discover/$_tur'
        '?with_companies=${widget.sirketId}'
        '&sort_by=popularity.desc&page=${_sayfa + 1}',
      );
      if (!mounted) return;
      // Afişsiz kayıtlar ızgarada gri delik bırakıyor — gözat ekranıyla aynı
      // süzgeç. Sayfanın DOLU olup olmadığına ham sonuçla karar verilir,
      // yoksa afişsiz bir sayfa listeyi erkenden bitirirdi.
      final ham = (d['results'] as List<dynamic>? ?? []);
      setState(() {
        _sayfa++;
        _icerikler.addAll(ham.where((r) => r['poster_path'] != null));
        // TMDB sayfa tavanı 500; boş sayfa da sonu gösterir.
        if (ham.isEmpty || _sayfa >= 500) _bitti = true;
        _yukluyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yukluyor = false;
        // İlk sayfa patladıysa hata görünümü; sonraki sayfalarda sessizce dur
        // (ekranda zaten dolu bir ızgara var, onu hata ekranıyla silmek yanlış).
        if (_icerikler.isEmpty) {
          _hata = e.toString();
        } else {
          _bitti = true;
        }
      });
    }
  }

  void _turDegis(String tur) {
    if (tur == _tur) return;
    setState(() {
      _tur = tur;
      _icerikler.clear();
      _sayfa = 0;
      _bitti = false;
      _hata = null;
    });
    _sonrakiSayfa();
  }

  String get _ad {
    final gelen = (_firma?['name'] as String?)?.trim();
    if (gelen != null && gelen.isNotEmpty) return gelen;
    final tasinan = widget.sirketAdi?.trim();
    if (tasinan != null && tasinan.isNotEmpty) return tasinan;
    return 'Yapım Firması'.c;
  }

  Widget get _baslik {
    final ulke = (_firma?['origin_country'] as String?)?.trim();
    final merkez = (_firma?['headquarters'] as String?)?.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FirmaLogosu(
            logoYolu: _firma?['logo_path'] as String?,
            genislik: 96,
            yukseklik: 56,
          ),
          const SizedBox(width: 14),
          // Expanded + maxLines: 45 dilde firma adları uzun olabiliyor
          // ("Sony Pictures Television Studios"); satır TAŞMAZ, sarar.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _ad,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (ulke != null && ulke.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  // Bayrak + ülke adı. `UlkeBayragi` iki harfli kodu doğrudan
                  // kabul eder (bkz. `ulkeKodu`); ad [ulkeAdiKoddan] ile
                  // seçili dile çevrilir. Satır kendi genişliğinde kalır ve
                  // uzun adda ("Amerika Birleşik Devletleri") üç noktayla
                  // kısalır — başlık kolonu TAŞMAZ.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      UlkeBayragi(ulke: ulke),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          ulkeAdiKoddan(ulke),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: DiziRenkler.metin54,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (merkez != null && merkez.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    merkez,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: DiziRenkler.metin54),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget get _sekmeler => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    child: SegmentedButton<String>(
      // FittedBox: uzun çeviri dar hücrede satır kırmaz, sığmazsa yazı küçülür
      // (gözat ekranıyla aynı kalıp).
      segments: [
        ButtonSegment(
          value: 'movie',
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('Filmler'.c, maxLines: 1, softWrap: false),
          ),
        ),
        ButtonSegment(
          value: 'tv',
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('Diziler'.c, maxLines: 1, softWrap: false),
          ),
        ),
      ],
      selected: {_tur},
      onSelectionChanged: (s) => _turDegis(s.first),
    ),
  );

  /// Alt gezinme çubuğu/jest çizgisi payı. Yalnız KAYAN hâllerde eklenir:
  /// `SliverFillRemaining` zaten kalan yüksekliği doldurduğu için hata/boş
  /// hâlinde bunu da koymak sayfaya sebepsiz kaydırma açardı.
  Widget get _altBosluk => SliverToBoxAdapter(
    child: SizedBox(height: altGuvenli(context, ekstra: 24)),
  );

  /// Izgaranın ÜÇ HÂLİ (yükleniyor / boş / hata) + dolu hâl.
  List<Widget> get _govde {
    if (_hata != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: HataGorunumu(
            mesaj: _hata!,
            tekrar: () {
              setState(() => _bitti = false);
              _sonrakiSayfa();
            },
          ),
        ),
      ];
    }
    if (_icerikler.isEmpty && _yukluyor) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid.builder(
            gridDelegate: const PosterIzgarasi(satirBoslugu: 12, bosluk: 10),
            itemCount: 9,
            itemBuilder: (_, _) => const IskeletKutu(
              genislik: double.infinity,
              yukseklik: double.infinity,
            ),
          ),
        ),
        _altBosluk,
      ];
    }
    if (_icerikler.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: BosDurum(
            ikon: Icons.movie_outlined,
            baslik: 'Yapım bulunamadı'.c,
            ipucu: 'Bu firmanın bu türde listelenecek yapımı yok.'.c,
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverGrid.builder(
          gridDelegate: const PosterIzgarasi(satirBoslugu: 12, bosluk: 10),
          itemCount: _icerikler.length,
          itemBuilder: (context, i) => PosterKarti(
            icerik: _icerikler[i] as Map<String, dynamic>,
            turZorla: _tur,
            genislik: double.infinity,
          ),
        ),
      ),
      // Sonraki sayfa gelirken listenin ALTINDA dönen gösterge.
      if (_yukluyor)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: DiziRenkler.sari,
                ),
              ),
            ),
          ),
        ),
      _altBosluk,
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (!_gecerli) {
      // Bozuk adres (`/sirket/abc`): API'ye hiç gidilmez.
      return Scaffold(
        appBar: AppBar(title: Text('Yapım Firması'.c)),
        body: BosDurum(
          ikon: Icons.business_outlined,
          baslik: 'Firma bulunamadı'.c,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _ad,
          maxLines: 2,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: [
          // Başlık ucu düştüyse (logo/ülke gelmedi) sessiz kalmak yerine
          // yeniden denenebilir bir işaret bırakılır; ızgara etkilenmez.
          if (_firmaDustu)
            IconButton(
              tooltip: 'Tekrar Dene'.c,
              onPressed: _firmaYukle,
              icon: Icon(Icons.refresh, color: DiziRenkler.metin54),
            ),
        ],
      ),
      // PC'de ızgara ortalanmış ve [masaustuIcerikGenisligi] ile sınırlı
      // (madde 26); mobilde kısıt bağlamaz.
      body: OrtaKolon(
        azami: masaustuIcerikGenisligi,
        cocuk: CustomScrollView(
          controller: _kaydirma,
          slivers: [
            SliverToBoxAdapter(child: _baslik),
            SliverToBoxAdapter(child: _sekmeler),
            ..._govde,
          ],
        ),
      ),
    );
  }
}
