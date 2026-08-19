import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../bayrak.dart';
import '../ceviri.dart';
import '../gorsel_basliklari.dart';
import '../tema.dart';
import '../puan.dart';
import 'ayarlar.dart' show ulkeler;
import 'giris_istem.dart';
import 'ortak.dart';
import 'puan_sheet.dart';
import 'tepki.dart';
import 'yorumlar.dart';

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

/// ---------------------------------------------------------------------------
/// RAF MODELİ — 19 Ağu 2026, kullanıcı İKİ hata birden buldu
/// ---------------------------------------------------------------------------
/// 1) BAŞLIKTAKİ SAYI YALANDI. Başlık `liste.length` yazıyordu; o liste
///    TMDB'nin TEK SAYFASI, yani en çok 20. Amazon Studios'ta üç rafın üçü de
///    "(20)" diyordu — gerçekte 26 / 166 / 125. Sayı artık `total_results`tan
///    geliyor. ("gerçekten 20 tane mi var?" — hayır, değildi.)
/// 2) ALTTAKİ IZGARA GEREKSİZDİ ve ZARARLIYDI. Raflar zaten dizileri ve
///    filmleri gösteriyordu; ızgara sonsuz sayfalanıp ALTTAKİ YORUMLARI
///    gömüyordu. Kullanıcı: "aşağıda yorumlar var, belki insanlar yorumlar
///    için ziyaret edecek." Izgara kaldırıldı; başlığa dokununca raf AŞAĞI
///    DOĞRU açılıyor.
///
/// AÇILAN RAF NEDEN KENDİLİĞİNDEN SAYFALAMIYOR: sonsuz kaydırma tam da
/// kaldırdığımız sorunu geri getirirdi. "Daha fazla" düğmesi listeyi SINIRLI
/// tutar, yorumlar birkaç ekran ötede kalır.
///
/// SAYI İLE LİSTE UZUNLUĞU BİRE BİR TUTMAYABİLİR: afişsiz kayıtlar ızgarada
/// gri delik bıraktığı için çizilmez, ama `total_results` onları da sayar.
/// Başlıktaki sayının cevapladığı soru "bu firmanın kaç yapımı var" —
/// "kaç tanesini çizebiliyoruz" değil.

/// Rafı besleyen TEK bir TMDB sorgusu ve KENDİ sayfa imleci.
class _RafKaynak {
  /// `page` parametresi HARİÇ tam yol.
  final String yol;
  final String tur;
  final List<dynamic> ogeler = [];
  int sayfa = 0;
  int toplam = 0;
  bool bitti = false;

  _RafKaynak(this.yol, this.tur);
}

/// Bir raf: başlık + bir ya da BİRDEN ÇOK kaynak.
///
/// "Devam eden yapımlar" iki kaynaktan beslenir (süren diziler + gelecek
/// filmler). Kaynaklar AYRI liste tutar ve ekrana sırayla dizilir; tek listeye
/// karıştırılsalardı ikinci dizi sayfası filmlerin ARKASINA eklenir ve sıra
/// bozulurdu.
class _Raf {
  final String anahtar;
  final IconData ikon;
  final String baslikKalibi;
  final List<_RafKaynak> kaynaklar;
  bool acik = false;
  bool yukluyor = false;
  bool ilkGeldi = false;

  /// Yatay şeridin kaydırma denetleyicisi.
  ///
  /// NEDEN İNDEKS DEĞİL KONUM: ilk denemede "son 5 karta gelince yükle" diye
  /// indekse bakılıyordu. Kısa listede (ör. 1 öğe) `i >= uzunluk - 5` daha ilk
  /// karede DOĞRU oluyor ve şerit, kullanıcı hiç dokunmadan sayfa sayfa sonuna
  /// kadar kendini yüklüyordu — testte yakalandı. Kaydırma konumu böyle bir
  /// yalan söylemez: kullanıcı gerçekten yana kaydırmadıysa tetiklenmez.
  final ScrollController kaydirma = ScrollController();

  _Raf({
    required this.anahtar,
    required this.ikon,
    required this.baslikKalibi,
    required this.kaynaklar,
  });

  List<dynamic> get ogeler => [for (final k in kaynaklar) ...k.ogeler];
  int get toplam => kaynaklar.fold(0, (t, k) => t + k.toplam);
  bool get bitti => kaynaklar.every((k) => k.bitti);
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

  /// Raflar. `baslangicTuru` ARTIK SEKME SEÇMİYOR (sekmeler kaldırıldı) ama
  /// bağlantı biçimi (`?tur=tv`) korunuyor: paylaşılmış eski adresler kırılmasın.
  late final List<_Raf> _raflar;

  /// Puan/tepki/yorum (19 Ağu 2026 isteği). Kişi sayfasıyla BİREBİR aynı
  /// desen: `/incelemeler/company/:id` toplum puanını, `/benim/company/:id`
  /// kendi puanımı verir.
  Map<String, dynamic>? _benimPuan;
  Map<String, dynamic>? _toplum;

  bool get _gecerli => widget.sirketId > 0;

  @override
  void initState() {
    super.initState();
    final bugun = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final firma = 'with_companies=${widget.sirketId}';
    const onek = '/tmdb/discover';
    _raflar = [
      // DEVAM EDEN = yayını süren dizi (`with_status=0` Returning Series)
      //            + HENÜZ ÇIKMAMIŞ film (`primary_release_date.gte=bugün`).
      // İkisi tek rafta birleşir çünkü sorulan şey "bu firmadan şu an ne
      // geliyor" — türü değil. Dizi önce: "devam eden" sezgisi önce yayında
      // olanı çağrıştırıyor.
      _Raf(
        anahtar: 'devam',
        ikon: Icons.play_circle_outline,
        baslikKalibi: 'Devam eden yapımlar ({})',
        kaynaklar: [
          _RafKaynak(
            '$onek/tv?$firma&with_status=0&sort_by=popularity.desc',
            'tv',
          ),
          _RafKaynak(
            '$onek/movie?$firma&primary_release_date.gte=$bugun'
                '&sort_by=primary_release_date.asc',
            'movie',
          ),
        ],
      ),
      _Raf(
        anahtar: 'dizi',
        ikon: Icons.tv_outlined,
        baslikKalibi: 'Diziler ({})',
        kaynaklar: [
          _RafKaynak('$onek/tv?$firma&sort_by=popularity.desc', 'tv'),
        ],
      ),
      _Raf(
        anahtar: 'film',
        ikon: Icons.movie_outlined,
        baslikKalibi: 'Filmler ({})',
        kaynaklar: [
          _RafKaynak('$onek/movie?$firma&sort_by=popularity.desc', 'movie'),
        ],
      ),
    ];
    for (final r in _raflar) {
      r.kaydirma.addListener(() {
        if (!r.kaydirma.hasClients || r.acik) return;
        // Sağ kenara 400 px kala sıradaki sayfa: parmak dibe varmadan gelsin.
        if (r.kaydirma.position.pixels >=
            r.kaydirma.position.maxScrollExtent - 400) {
          _dahaFazla(r);
        }
      });
    }
    if (_gecerli) {
      _firmaYukle();
      _puanYenile();
      _raflariYukle();
    }
  }

  @override
  void dispose() {
    for (final r in _raflar) {
      r.kaydirma.dispose();
    }
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

  /// Toplum puanı + kendi puanım. Kişi sayfasındaki `_puanYenile` ile aynı;
  /// oturumsuzda `/benim/...` HİÇ istenmez (girisZorunlu, 401 dönerdi ve
  /// toplum puanı da onunla birlikte sessizce kaybolurdu).
  Future<void> _puanYenile() async {
    try {
      final sonuclar = await Future.wait([
        Api.get('/incelemeler/company/${widget.sirketId}'),
        if (Api.girisli) Api.get('/benim/company/${widget.sirketId}'),
      ]);
      if (!mounted) return;
      setState(() {
        _toplum = sonuclar[0] as Map<String, dynamic>;
        _benimPuan = sonuclar.length > 1
            ? sonuclar[1]['puan'] as Map<String, dynamic>?
            : null;
      });
    } catch (_) {
      // Puan bloğu düşerse SESSİZ kal: yapım ızgarası bundan bağımsız ve
      // sayfanın asıl işi o. Hata görünümü basmak ekranı boşaltırdı.
    }
  }

  Future<void> _puanla() async {
    if (!girisGerekli(context)) return;
    final kaydedildi = await puanlaVeKaydet(
      context,
      tur: 'company',
      tmdbId: widget.sirketId,
      mevcutPuan: puanSayisi(_benimPuan?['puan'])?.toInt(),
      mevcutYorum: _benimPuan?['yorum'] as String?,
    );
    if (kaydedildi) _puanYenile();
  }

  /// Her rafın HER kaynağından İLK sayfa; hepsi paralel. Dört küçük istek,
  /// hepsi `/tmdb/*` beyaz listesinde ve sunucuda önbellekli.
  Future<void> _raflariYukle() async {
    await Future.wait([
      for (final r in _raflar)
        for (final k in r.kaynaklar) _kaynakSayfa(k),
    ]);
    if (!mounted) return;
    setState(() {
      for (final r in _raflar) {
        r.ilkGeldi = true;
      }
    });
  }

  /// Tek kaynaktan SIRADAKİ sayfa.
  ///
  /// `total_results` HER sayfada okunur ki başlıktaki sayı ilk yanıtla
  /// birlikte doğru olsun — kullanıcının "daha fazla"ya basmasını beklemesin.
  Future<void> _kaynakSayfa(_RafKaynak kaynak) async {
    if (kaynak.bitti) return;
    try {
      final d = await Api.get('${kaynak.yol}&page=${kaynak.sayfa + 1}');
      if (!mounted) return;
      final ham = (d['results'] as List<dynamic>? ?? []);
      kaynak.sayfa++;
      kaynak.toplam = (d['total_results'] as num?)?.toInt() ?? kaynak.toplam;
      final sayfaSayisi = (d['total_pages'] as num?)?.toInt() ?? 0;
      // Afişsizler ayıklanır: ızgarada gri delik bırakıyorlar. Sayfanın DOLU
      // olup olmadığına HAM sonuçla karar verilir — yoksa tamamı afişsiz bir
      // sayfa listeyi erkenden bitirirdi.
      kaynak.ogeler.addAll(
        ham
            .where((r) => r['poster_path'] != null)
            .map((r) => {...r as Map<String, dynamic>, '_tur': kaynak.tur}),
      );
      // TMDB sayfa tavanı 500.
      if (ham.isEmpty || kaynak.sayfa >= sayfaSayisi || kaynak.sayfa >= 500) {
        kaynak.bitti = true;
      }
    } catch (_) {
      // SESSİZ: bir raf düşerse sayfanın geri kalanı (puan, yorumlar) ayakta
      // kalmalı. Bitmiş sayılır ki "daha fazla" sonsuza kadar denemesin.
      kaynak.bitti = true;
    }
  }

  /// "Daha fazla": BİTMEMİŞ İLK kaynaktan bir sayfa daha.
  ///
  /// Kaynak sırası korunur (önce diziler biter, sonra filmler) — böylece
  /// karışık rafta yeni gelenler listenin ortasına düşmez.
  Future<void> _dahaFazla(_Raf raf) async {
    if (raf.yukluyor || raf.bitti) return;
    setState(() => raf.yukluyor = true);
    await _kaynakSayfa(raf.kaynaklar.firstWhere((k) => !k.bitti));
    if (!mounted) return;
    setState(() => raf.yukluyor = false);
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

  /// Puan düğmesi + emoji tepkileri. Kişi sayfasındaki yerleşimin aynısı:
  /// ikisi de "senin bu firmaya dair hislerin" olduğu için alt alta durur.
  Widget get _puanSatiri {
    // `as num?` DEĞİL `puanSayisi`: sunucu bu uçta `adet`i METİN olarak
    // gönderiyor ("0"), çünkü SQL `count(*)` (bigint) ve node-postgres
    // bigint'i dizgeye çeviriyor. `ortalama` da `numeric` olduğu için aynı
    // kapıya çıkar. 19 Ağu 2026'da sayfa TAM DA BURADA gri ekrana düştü:
    // "type 'String' is not a subtype of type 'num?'". Kardeş ekranlar
    // (kisi.dart, detay.dart) zaten `puanSayisi`/`yildizOrtalamaMetni`
    // kullanıyordu; kopyalarken bu satır atlanmıştı.
    final ort = puanSayisi(_toplum?['ortalama'])?.toDouble();
    final adet = (puanSayisi(_toplum?['adet']) ?? 0).toInt();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: _puanla,
                icon: Icon(
                  _benimPuan != null ? Icons.star : Icons.star_border,
                  size: 20,
                ),
                label: Text(
                  _benimPuan != null
                      ? '${yildiza(_benimPuan!['puan'])}/$yildizAzami'
                      : 'Puanla'.c,
                ),
              ),
              if (ort != null && adet > 0) ...[
                const SizedBox(width: 12),
                Icon(
                  Icons.people_outline,
                  size: 16,
                  color: DiziRenkler.metin54,
                ),
                const SizedBox(width: 4),
                Text(
                  '${yildiza(ort)}/$yildizAzami · $adet',
                  style: TextStyle(color: DiziRenkler.metin54, fontSize: 13),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          TepkiSatiri(tur: 'company', tmdbId: widget.sirketId),
        ],
      ),
    );
  }

  /// Raftaki tek kartın genişliği. Yükseklik bundan TÜRETİLİR.
  static const double _rafKartGenisligi = 124;

  /// Rafta ŞU AN yüklü öğe sayısı (başlıkta `total_results` yokken kullanılır).
  int ogeSayisi(_Raf raf) => raf.ogeler.length;

  /// Tek rafın SLIVER'ları: başlık + (kapalıysa yatay şerit / açıksa ızgara).
  ///
  /// Widget değil SLIVER döndürür: açık raf yüzlerce kart taşıyabilir ve
  /// `SliverGrid` yalnız görünenleri kurar. Hepsini bir `Column`a koymak
  /// 166 kartı birden çizmek olurdu.
  List<Widget> _rafSliverlari(_Raf raf) {
    if (!raf.ilkGeldi) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 16, 12, 0),
            child: IskeletKutu(genislik: double.infinity, yukseklik: 208),
          ),
        ),
      ];
    }
    final ogeler = raf.ogeler;
    // Boş raf HİÇ çizilmez: "(0)" yazan bir başlık gürültüden ibaret.
    if (ogeler.isEmpty) return const [];
    return [
      SliverToBoxAdapter(child: _rafBasligi(raf)),
      if (!raf.acik)
        SliverToBoxAdapter(child: _rafSeridi(raf, ogeler))
      else ...[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          sliver: SliverGrid.builder(
            gridDelegate: const PosterIzgarasi(satirBoslugu: 12, bosluk: 10),
            itemCount: ogeler.length,
            itemBuilder: (context, i) {
              // KAYDIRDIKÇA YÜKLE (19 Ağu 2026 isteği): "daha fazla yazısını
              // çıkarma, kaydırdıkça yükle; kullanıcı zaten hepsini görmek
              // istediği için tıklıyor." Doğru: "Tümünü gör" ZATEN açık bir
              // niyet beyanı, ikinci bir düğme gereksiz sürtünme.
              //
              // TETİKLEYİCİ SAYFANIN DİBİ DEĞİL, IZGARANIN SONU. Genişletilmiş
              // raf sayfanın ORTASINDA olabilir (altında öbür raflar ve yorum
              // bölümü var); `maxScrollExtent`e bakan bir dinleyici o durumda
              // ya hiç ateşlenmez ya da yanlış rafı besler. Son kartlar ekrana
              // girdiğinde tetiklemek, rafın nerede olduğundan BAĞIMSIZ çalışır.
              //
              // 6 KART ÖNCE: bir satır 3-6 kart; kullanıcı dibe varmadan
              // sayfa yolda olsun ki bekleme görünmesin.
              // `ogeler.length >= 12` ŞART: kısa listede `i >= uzunluk - 6`
              // ilk karede doğru olur ve ızgara kullanıcı kaydırmadan kendini
              // sonuna kadar yükler (şeritte tam bu tuzağa düşüldü).
              if (ogeler.length >= 12 && i >= ogeler.length - 6) {
                // Çizim sırasında setState YASAK — kare sonuna ertele.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && raf.acik) _dahaFazla(raf);
                });
              }
              final o = ogeler[i] as Map<String, dynamic>;
              return PosterKarti(
                icerik: o,
                turZorla: o['_tur'] as String?,
                genislik: double.infinity,
              );
            },
          ),
        ),
        SliverToBoxAdapter(child: _dahaFazlaSatiri(raf)),
      ],
    ];
  }

  /// Raf başlığı = AÇMA/KAPAMA DÜĞMESİ.
  ///
  /// Sayı `total_results`tan gelir (bkz. [_Raf] üstündeki not). Dokunma
  /// hedefi 44 px: ikon değil SATIRIN KENDİSİ büyütüldü.
  Widget _rafBasligi(_Raf raf) => InkWell(
    key: Key('raf-baslik-${raf.anahtar}'),
    onTap: () => setState(() => raf.acik = !raf.acik),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Icon(raf.ikon, size: 19, color: DiziRenkler.sariMetin),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                // Toplam 0 ise (uç düştü) yüklenen öğe sayısına düşülür:
                // "Diziler (0)" yazıp altında 20 kart çizmek yeni bir yalan
                // olurdu.
                raf.baslikKalibi.cf([
                  raf.toplam > 0 ? raf.toplam : ogeSayisi(raf),
                ]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            // Durum ÜÇ KANALDAN: yazı + ok yönü + `Semantics.expanded`.
            // Yalnız ok olsaydı ekran okuyucu hiçbir şey duymazdı.
            Semantics(
              expanded: raf.acik,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    raf.acik ? 'Daralt'.c : 'Tümünü gör'.c,
                    style: TextStyle(
                      color: DiziRenkler.sariMetin,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(
                    raf.acik ? Icons.expand_less : Icons.expand_more,
                    color: DiziRenkler.sariMetin,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  /// Kapalı hâl: yatay poster şeridi — O DA KAYDIRDIKÇA YÜKLENİR.
  ///
  /// 19 AĞU 2026: eskiden şerit 20 kartta KESİLİYORDU, açık ızgara ise
  /// sonsuza gidiyordu. Kullanıcı tutarsızlığı yakaladı: "tümünü gör diyince
  /// neden sonsuza kadar gidiyor da... kaydırınca gitmiyor". Haklı — 20
  /// sayısının kullanıcı açısından hiçbir anlamı yok, yalnızca TMDB'nin sayfa
  /// boyutuydu. Yana kaydırmak da en az aşağı kaydırmak kadar açık bir "devamını
  /// göster" isteğidir.
  Widget _rafSeridi(_Raf raf, List<dynamic> ogeler) => Padding(
    padding: const EdgeInsets.only(left: 12, top: 8),
    child: SizedBox(
      // YÜKSEKLİK TÜRETİLİR, SABİT DEĞİL: `PosterKarti` posterin 2:3 oranına
      // BİR DE başlık+puan satırı ekliyor. 208 px sabiti yazınca test
      // "RenderFlex overflowed by 18 pixels" ile patlamıştı; sabit sayı, yazı
      // tipi ölçeği büyüyen kullanıcıda aynı taşmayı sessizce geri getirirdi.
      height: _rafKartGenisligi * 3 / 2 + posterBaslikYuksekligi,
      child: ListView.separated(
        controller: raf.kaydirma,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 12),
        // Yükleniyorken SONA bir hücre daha: dönen gösterge oraya çizilir,
        // yoksa kullanıcı şeridin bittiğini sanır.
        itemCount: ogeler.length + (raf.yukluyor ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          if (i >= ogeler.length) {
            return const SizedBox(
              width: _rafKartGenisligi,
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
            );
          }
          final o = ogeler[i] as Map<String, dynamic>;
          return SizedBox(
            width: _rafKartGenisligi,
            child: PosterKarti(
              icerik: o,
              turZorla: o['_tur'] as String?,
              genislik: double.infinity,
            ),
          );
        },
      ),
    ),
  );

  /// Alt gezinme çubuğu/jest çizgisi payı.
  Widget get _altBosluk => SliverToBoxAdapter(
    child: SizedBox(height: altGuvenli(context, ekstra: 24)),
  );

  /// Açık rafın altı: yalnızca YÜKLENİYOR göstergesi.
  ///
  /// "Daha fazla" DÜĞMESİ KALDIRILDI (19 Ağu 2026): raf başlığındaki
  /// "Tümünü gör" zaten "hepsini göreyim" demek; ondan sonra her sayfa için
  /// bir düğmeye daha bastırmak kullanıcıyı iki kez niyet beyanına zorlardı.
  /// Sayfalama artık ızgaranın sonu görününce kendiliğinden ilerliyor.
  ///
  /// LİSTE BİTTİĞİNDE HİÇBİR ŞEY ÇİZİLMEZ — "hepsi bu kadar" yazısı da yok:
  /// başlıktaki sayı (`Diziler (166)`) zaten kaç tane olduğunu söylüyor,
  /// ikinci bir bitiş işareti gürültü olurdu.
  Widget _dahaFazlaSatiri(_Raf raf) {
    if (!raf.yukluyor) return const SizedBox(height: 12);
    return const Padding(
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
    );
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
          slivers: [
            SliverToBoxAdapter(child: _baslik),
            // Puan + tepki: başlığın hemen altında (kişi sayfasıyla aynı yer).
            SliverToBoxAdapter(child: _puanSatiri),
            // Raflar: devam edenler → diziler → filmler. Başlığa dokununca
            // raf AŞAĞI DOĞRU açılır. Altta ayrı bir "Tüm yapımlar" ızgarası
            // ARTIK YOK: sonsuz sayfalanıp yorumları gömüyordu (19 Ağu 2026).
            for (final r in _raflar) ..._rafSliverlari(r),
            _altBosluk,
            // Yorumlar en altta: firma kartı Reels'e buradan verilir
            // (`/icerikler` ucu yalnız dizi/film bilir, firma adı olmadan
            // Reels üstünde "?" görünürdü — kişi sayfasındaki aynı tuzak).
            SliverToBoxAdapter(
              child: YorumBolumu(
                tur: 'company',
                tmdbId: widget.sirketId,
                icerik: {'ad': _ad, 'poster': _firma?['logo_path']},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
