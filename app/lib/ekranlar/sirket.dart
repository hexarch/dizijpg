import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
///
/// `sirala` ADRESE YAZILIR (19 Ağu 2026): F5'te seçim korunsun ve
/// "HBO'nun en çok izlenenleri" bağlantısı paylaşılabilsin. Varsayılan
/// (popülerlik) parametreyi HİÇ basmaz — eski bağlantılar birebir aynı kalır.
String sirketYolu(int id, {String? ad, String? tur, String? sirala}) {
  final temizAd = ad?.trim() ?? '';
  final q = <String>[
    if (temizAd.isNotEmpty) 'ad=${Uri.encodeQueryComponent(temizAd)}',
    if (tur == 'tv' || tur == 'movie') 'tur=$tur',
    if (sirala != null && sirala.isNotEmpty) 'sirala=$sirala',
  ];
  return q.isEmpty ? '/sirket/$id' : '/sirket/$id?${q.join('&')}';
}

/// ---------------------------------------------------------------------------
/// SIRALAMA SEÇENEKLERİ (19 Ağu 2026 isteği)
/// ---------------------------------------------------------------------------
/// İSTEK: firmanın rafları TMDB puanına · yapım yılına · dizi.jpg puanına ·
/// dizi.jpg izlenmesine · yorum sayısına göre sıralanabilsin.
///
/// SEÇENEKLER İKİ AYRI YOLDAN ÇALIŞIR ve bu ayrım tesadüfi değil:
///
///  * TMDB TABANLI (`sortBy` dolu) — `discover` bunları ZATEN biliyor. Tek
///    yapılan sorguya `sort_by` eklemek; sayfalama, `total_results`, hepsi
///    olduğu gibi kalır ve liste SINIRSIZ kaydırılabilir.
///
///  * BİZİM VERİMİZ (`alan` dolu) — TMDB puanımızı, izlenmemizi, yorum
///    sayımızı BİLMEZ; `discover` ile sıralanamazlar. Bu modda istemci TMDB'den
///    havuzu doldurur ([_havuzTavani] kadar), sayaçları `POST /yapim-sayaclari`
///    ile tek seferde alır ve sıralamayı KENDİ yapar. Sunucu firmayı hiç
///    bilmez: `puanlar`/`izlemeler`/`yorumlar` tablolarında firma sütunu YOK,
///    firma↔yapım eşlemesi yalnız TMDB'de duruyor.
class _Sira {
  /// Adresteki `?sirala=` değeri. `null` = varsayılan (popülerlik) —
  /// adrese hiç yazılmaz.
  final String? deger;

  /// Çipteki metin (çeviri anahtarı).
  final String etiket;

  /// TMDB `discover` `sort_by` değeri; dizi ve film için ayrı, çünkü tarih
  /// alanının adı türe göre değişiyor (`first_air_date` / `primary_release_date`).
  final String? tvSort;
  final String? filmSort;

  /// Bizim sayaç alanımız: 'puan' | 'izlenme' | 'yorum'.
  final String? alan;

  /// TMDB puanına göre sıralarken uygulanan EN AZ OY sayısı.
  ///
  /// NEDEN GEREKLİ: `sort_by=vote_average.desc` tek oylu yapımları 10,0 ile
  /// tepeye taşır — TMDB'nin bilinen tuzağı. Süzgeçsiz raf "en iyi HBO
  /// dizileri" diye kimsenin duymadığı bir belgeseli gösterirdi. 50, TMDB'nin
  /// kendi sitesindeki 200'den GEVŞEK seçildi: 200'de küçük yapım firmalarının
  /// rafı bomboş kalıyor, boş raf yanlış sıradan daha kötü.
  final int? enAzOy;

  const _Sira({
    required this.deger,
    required this.etiket,
    this.tvSort,
    this.filmSort,
    this.alan,
    this.enAzOy,
  });
}

const List<_Sira> _siralamaSecenekleri = [
  // İLK SIRA = MEVCUT DAVRANIŞ. Varsayılanın değişmemesi şart: bugüne kadar
  // paylaşılmış her `/sirket/...` bağlantısı aynı listeyi göstermeye devam eder.
  _Sira(
    deger: null,
    etiket: 'Popülerlik',
    tvSort: 'popularity.desc',
    filmSort: 'popularity.desc',
  ),
  _Sira(
    deger: 'tmdb',
    etiket: 'TMDB puanı',
    tvSort: 'vote_average.desc',
    filmSort: 'vote_average.desc',
    enAzOy: 50,
  ),
  _Sira(
    deger: 'yil',
    etiket: 'Yapım yılı',
    tvSort: 'first_air_date.desc',
    filmSort: 'primary_release_date.desc',
  ),
  _Sira(deger: 'puan', etiket: 'dizi.jpg puanı', alan: 'puan'),
  _Sira(deger: 'izlenme', etiket: 'İzlenme', alan: 'izlenme'),
  _Sira(deger: 'yorum', etiket: 'Yorum sayısı', alan: 'yorum'),
];

/// Adresten gelen ham değeri seçeneğe çevirir; tanınmayan değer VARSAYILANA
/// düşer (elle yazılmış `?sirala=abc` sayfayı bozmasın).
_Sira _siralamaCoz(String? deger) => _siralamaSecenekleri.firstWhere(
  (s) => s.deger == deger,
  orElse: () => _siralamaSecenekleri.first,
);

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
  /// `page` VE `sort_by` HARİÇ yol. Sıralama seçimi çalışma anında eklenir —
  /// yol sabit metin olsaydı her seçimde kaynak nesnesini yeniden kurmak
  /// (ve `ScrollController`ı atmak) gerekirdi.
  final String temel;

  /// Bu kaynağın KENDİ doğal sırası (varsayılan seçenekte kullanılır).
  ///
  /// "Devam eden filmler" bilerek `primary_release_date.asc`: raf "şu an ne
  /// geliyor" sorusunu cevaplıyor, yani EN YAKIN tarihli önce gelmeli.
  final String varsayilanSira;

  final String tur;
  final List<dynamic> ogeler = [];
  int sayfa = 0;
  int toplam = 0;
  bool bitti = false;

  _RafKaynak(this.temel, this.tur, {required this.varsayilanSira});

  /// Seçili sıralamaya göre tam yol (`page` hariç).
  ///
  /// BİZİM VERİMİZLE sıralarken TMDB tarafı VARSAYILAN sırada kalır: havuz
  /// popülerlikten doldurulur, sıralamayı istemci sayaçlarla yapar. Aksi hâlde
  /// TMDB'ye anlamsız bir `sort_by` gönderilirdi.
  String yol(_Sira sira) {
    final sortBy = tur == 'tv' ? sira.tvSort : sira.filmSort;
    final buf = StringBuffer(temel)
      ..write('&sort_by=${sortBy ?? varsayilanSira}');
    // Oy eşiği yalnız TMDB puanı sıralamasında anlamlı; başka seçenekte
    // eklenirse raftan sessizce yapım düşer.
    if (sira.enAzOy != null) buf.write('&vote_count.gte=${sira.enAzOy}');
    return buf.toString();
  }

  /// Sayfa imlecini ve birikmiş listeyi sıfırla (sıralama değişince).
  void sifirla() {
    ogeler.clear();
    sayfa = 0;
    toplam = 0;
    bitti = false;
  }
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

  void sifirla() {
    for (final k in kaynaklar) {
      k.sifirla();
    }
    ilkGeldi = false;
    yukluyor = false;
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

class _SirketEkraniState extends State<SirketEkrani>
    with OlcekDinler<SirketEkrani> {
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

  /// Seçili sıralama. Kaynak doğru: ADRES (`?sirala=`) — [didChangeDependencies]
  /// her adres değişiminde buraya yazar, böylece geri/ileri tuşu ve paylaşılan
  /// bağlantı da doğru sırayı gösterir.
  _Sira _sira = _siralamaSecenekleri.first;
  bool _adresOkundu = false;

  /// `'<tur>:<tmdbId>'` → `{puan_ort, puan_adet, izlenme, yorum}`.
  ///
  /// Anahtar TÜRÜ DE taşır: TMDB'de aynı sayı hem bir diziye hem bir filme ait
  /// olabilir ve ikisinin sayacı ayrıdır.
  /// Sunucu HER sorulan kimlik için satır döndürüyor (veri yoksa sıfırlarla),
  /// bu yüzden haritada bulunmak "soruldu" demek — aynı kimlik ikinci kez
  /// sorulmaz.
  final Map<String, Map<String, dynamic>> _sayaclar = {};

  /// BİZİM VERİMİZLE sıralarken bir rafa alınacak EN ÇOK yapım.
  ///
  /// NEDEN TAVAN VAR: sıralamanın DOĞRU olması için havuzun sıralamadan ÖNCE
  /// dolu olması gerekiyor. Yalnız yüklü 20 kartı kendi puanımıza göre dizmek
  /// "en yüksek puanlı yapımlar" değil "ilk 20 popülerin en yüksek puanlısı"
  /// olurdu — sessiz bir yalan. Sınırsız doldurmak ise 166 dizilik bir firmada
  /// 9 TMDB isteği + 2 sayaç isteği demekti.
  ///
  /// 100 aynı zamanda sunucudaki `YAPIM_SAYAC_TAVAN` ile BİREBİR: bir raf tek
  /// istekte sorulur, dilimleme gerekmez.
  static const int _havuzTavani = 100;

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
            '$onek/tv?$firma&with_status=0',
            'tv',
            varsayilanSira: 'popularity.desc',
          ),
          _RafKaynak(
            '$onek/movie?$firma&primary_release_date.gte=$bugun',
            'movie',
            varsayilanSira: 'primary_release_date.asc',
          ),
        ],
      ),
      _Raf(
        anahtar: 'dizi',
        ikon: Icons.tv_outlined,
        baslikKalibi: 'Diziler ({})',
        kaynaklar: [
          _RafKaynak(
            '$onek/tv?$firma',
            'tv',
            varsayilanSira: 'popularity.desc',
          ),
        ],
      ),
      _Raf(
        anahtar: 'film',
        ikon: Icons.movie_outlined,
        baslikKalibi: 'Filmler ({})',
        kaynaklar: [
          _RafKaynak(
            '$onek/movie?$firma',
            'movie',
            varsayilanSira: 'popularity.desc',
          ),
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
    }
    // RAFLAR BURADA YÜKLENMEZ: hangi sırayla isteneceklerini ADRES söylüyor
    // (`?sirala=`) ve adres ancak [didChangeDependencies] içinde okunabilir
    // (`GoRouterState.of` bir InheritedWidget aramasıdır, `initState`te YASAK).
    // İlk yükleme oraya taşındı — yoksa paylaşılan `?sirala=izlenme`
    // bağlantısı önce popülerlik listesini çekip sonra onu atardı.
  }

  /// Adres → [_sira]. Her adres değişiminde çalışır: tarayıcının geri/ileri
  /// tuşu da doğru sırayı geri getirir.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_gecerli) return;
    final yeni = _siralamaCoz(_adrestenSirala());
    if (!_adresOkundu) {
      _adresOkundu = true;
      _sira = yeni;
      _raflariYukle();
      return;
    }
    // Adres DIŞARIDAN değiştiyse (geri tuşu, elle yazma) rafları yenile.
    // Çipe dokunulduğunda [_siralaSec] `_sira`yı ÖNCE yazdığı için burası
    // sessiz kalır — aynı iş iki kez yapılmaz.
    if (yeni.deger != _sira.deger) {
      _sira = yeni;
      _raflariTazele();
    }
  }

  /// Adresteki `?sirala=` değeri.
  ///
  /// try/catch: ekran yönlendirici olmadan da kurulabiliyor (widget testleri,
  /// gelecekte bir modal). O durumda varsayılan sıra kullanılır — sayfa
  /// yönlendiriciye BAĞIMLI olmamalı.
  String? _adrestenSirala() {
    try {
      return GoRouterState.of(context).uri.queryParameters['sirala'];
    } catch (_) {
      return null;
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
  ///
  /// BİZİM VERİMİZLE sıralarken raf ayrıca [_havuzuDoldur] ile tavana kadar
  /// çekilir ve sayaçları alınır — gerekçe [_havuzTavani] üstünde.
  Future<void> _raflariYukle() async {
    await Future.wait([for (final r in _raflar) _rafiYukle(r)]);
  }

  Future<void> _rafiYukle(_Raf raf) async {
    await Future.wait([for (final k in raf.kaynaklar) _kaynakSayfa(k)]);
    if (_sira.alan != null) await _havuzuDoldur(raf);
    if (!mounted) return;
    setState(() => raf.ilkGeldi = true);
  }

  /// SIRALAMA DEĞİŞTİ: rafları boşalt, baştan yükle.
  ///
  /// `_Raf` NESNELERİ KORUNUR (yenisi kurulmaz): `ScrollController` onların
  /// alanı ve hâlâ ekrandaki `ListView`a bağlı. Yeniden kurmak, kullanılan bir
  /// denetleyiciyi `dispose` etmek olurdu. Açık/kapalı hâl de bilerek korunuyor:
  /// kullanıcı "Tümünü gör" dedikten sonra sırayı değiştirince rafın kapanması
  /// niyetini geri almak olurdu.
  Future<void> _raflariTazele() async {
    setState(() {
      for (final r in _raflar) {
        r.sifirla();
        // Şerit başa dönmeli: yeni liste eskisinin kaydırma konumunda açılırsa
        // kullanıcı listenin ortasına düşer.
        if (r.kaydirma.hasClients) r.kaydirma.jumpTo(0);
      }
    });
    await _raflariYukle();
  }

  /// Bizim sayaçlarımızla sıralanacak rafı TAVANA kadar doldurur, sonra
  /// sayaçları tek istekte alır ve rafı BİTMİŞ sayar.
  ///
  /// BİTMİŞ SAYMAK BİLİNÇLİ: liste bu modda sonludur. Kaydırdıkça yeni sayfa
  /// gelseydi sıra her sayfada yeniden hesaplanır ve kartlar kullanıcının
  /// gözünün önünde yer değiştirirdi.
  Future<void> _havuzuDoldur(_Raf raf) async {
    var koruma = 0;
    while (mounted &&
        !raf.bitti &&
        raf.ogeler.length < _havuzTavani &&
        koruma++ < 12) {
      await _kaynakSayfa(raf.kaynaklar.firstWhere((k) => !k.bitti));
    }
    if (!mounted) return;
    await _sayaclariGetir(raf.ogeler);
    for (final k in raf.kaynaklar) {
      k.bitti = true;
    }
  }

  /// Eksik sayaçları `POST /yapim-sayaclari` ile getirir.
  ///
  /// TÜR BAŞINA AYRI İSTEK: uç `tur` alıyor (tablolarda `tur`+`tmdb_id` birlikte
  /// anahtar). "Devam eden" rafı hem dizi hem film taşıdığı için orada iki
  /// istek olur; ikisi paralel gider.
  Future<void> _sayaclariGetir(List<dynamic> ogeler) async {
    final eksik = <String, List<int>>{'tv': [], 'movie': []};
    for (final o in ogeler) {
      final tur = (o as Map<String, dynamic>)['_tur'] as String?;
      final id = puanSayisi(o['id'])?.toInt();
      if (tur == null || id == null || _sayaclar.containsKey('$tur:$id')) {
        continue;
      }
      if (!eksik[tur]!.contains(id)) eksik[tur]!.add(id);
    }
    await Future.wait([
      for (final girdi in eksik.entries)
        if (girdi.value.isNotEmpty) _sayacIste(girdi.key, girdi.value),
    ]);
  }

  Future<void> _sayacIste(String tur, List<int> idler) async {
    // Tavanı sunucu da uyguluyor (400 döner); istemci burada BİLEREK dilimliyor
    // ki gelecekte tavan aşan bir çağıran sessizce hata almasın.
    for (var i = 0; i < idler.length; i += _havuzTavani) {
      final son = (i + _havuzTavani).clamp(0, idler.length);
      final dilim = idler.sublist(i, son);
      try {
        final d = await Api.post('/yapim-sayaclari', {
          'tur': tur,
          'tmdb_idler': dilim,
        });
        for (final s in (d['sayaclar'] as List<dynamic>? ?? [])) {
          final m = s as Map<String, dynamic>;
          final id = puanSayisi(m['tmdb_id'])?.toInt();
          if (id != null) _sayaclar['$tur:$id'] = m;
        }
      } catch (_) {
        // SESSİZ: sayaç gelmezse sıralama TMDB'nin verdiği sırada kalır. Rafı
        // boşaltmak ya da hata basmak, çalışan bir listeyi bozmak olurdu.
        // Sorulmuş sayılsın ki her sayfada yeniden denenmesin.
        for (final id in dilim) {
          _sayaclar.putIfAbsent('$tur:$id', () => const {});
        }
      }
    }
  }

  /// Bir yapımın seçili alandaki sayacı; sıralamada kullanılır.
  /// Veri YOKSA `null` — [_siraliOgeler] onu SONA atar (gizlemez).
  num? _sayacDegeri(dynamic oge, String alan) {
    final m = oge as Map<String, dynamic>;
    final s = _sayaclar['${m['_tur']}:${puanSayisi(m['id'])?.toInt()}'];
    if (s == null) return null;
    final ham = puanSayisi(s[alan == 'puan' ? 'puan_ort' : alan]);
    if (ham == null || ham == 0) return null;
    return ham;
  }

  /// Rafın EKRANA ÇİZİLECEK listesi.
  ///
  /// TMDB tabanlı sıralamalarda liste olduğu gibi döner (sıra sunucudan
  /// geliyor). Bizim verimizde burada sıralanır.
  ///
  /// İNDEKSLE SÜSLEME ŞART: `List.sort` Dart'ta KARARLI DEĞİL. Sayaçların
  /// büyük kısmı eşit (çoğu yapımın hiç puanı yok) ve kararsız sıralama o
  /// eşitlerin sırasını her `setState`te değiştirir — kartlar gözün önünde
  /// zıplar. İkincil ölçüt "TMDB'nin verdiği sıra" (yani popülerlik).
  List<dynamic> _siraliOgeler(_Raf raf) {
    final alan = _sira.alan;
    final ham = raf.ogeler;
    if (alan == null) return ham;
    final indeksli = [for (var i = 0; i < ham.length; i++) (i, ham[i])];
    indeksli.sort((a, b) {
      final da = _sayacDegeri(a.$2, alan);
      final db = _sayacDegeri(b.$2, alan);
      // Veri olmayan yapım GİZLENMEZ, SONA gider.
      if (da == null || db == null) {
        if (da == db) return a.$1.compareTo(b.$1);
        return da == null ? 1 : -1;
      }
      final c = db.compareTo(da);
      if (c != 0) return c;
      // dizi.jpg puanında EŞİTLİĞİ PUAN SAYISI bozar: 10,0'ı tek kişi de
      // vermiş olabilir. Eşiğe (ör. "en az 5 puan") gidilmedi — bugünkü
      // hacimde eşik rafı bomboş bırakırdı; boş raf yanlış sıradan kötüdür.
      if (alan == 'puan') {
        final aa =
            puanSayisi(
              _sayaclar['${a.$2['_tur']}:${a.$2['id']}']?['puan_adet'],
            ) ??
            0;
        final ba =
            puanSayisi(
              _sayaclar['${b.$2['_tur']}:${b.$2['id']}']?['puan_adet'],
            ) ??
            0;
        final ca = ba.compareTo(aa);
        if (ca != 0) return ca;
      }
      return a.$1.compareTo(b.$1);
    });
    return [for (final e in indeksli) e.$2];
  }

  /// Tek kaynaktan SIRADAKİ sayfa.
  ///
  /// `total_results` HER sayfada okunur ki başlıktaki sayı ilk yanıtla
  /// birlikte doğru olsun — kullanıcının "daha fazla"ya basmasını beklemesin.
  Future<void> _kaynakSayfa(_RafKaynak kaynak) async {
    if (kaynak.bitti) return;
    try {
      final d = await Api.get('${kaynak.yol(_sira)}&page=${kaynak.sayfa + 1}');
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

  /// ---------------------------------------------------------------------
  /// SIRALAMA SEÇİCİ
  /// ---------------------------------------------------------------------
  /// NEDEN SAYFANIN ÜSTÜNDE VE TEK: raf başına ayrı seçici koymak üç ayrı
  /// durum, üç ayrı adres parametresi ve "hangisini değiştirmiştim" sorusu
  /// demekti. Kullanıcının cümlesi "HBO'nun en çok izlenenleri" — dizi/film
  /// ayrımını sıralarken YAPMIYOR; o ayrımı zaten rafların kendisi yapıyor.
  ///
  /// BELİRSİZLİK "Tüm raflara uygulanır" ALT METNİYLE KAPANIYOR: seçici
  /// rafların ÜSTÜNDE durduğu için "yalnız ilk rafa mı?" sorusu doğardı;
  /// tek satırlık metin bunu sözle kapatıyor (ui-ux-pro-max, "sistem durumunun
  /// görünürlüğü").
  ///
  /// AÇILIR LİSTE DEĞİL ÇİP: seçenekler altı tane ve kısa — çipler hepsini
  /// dokunmadan gösterir, seçili olan tek bakışta okunur. Projede aynı desen
  /// Gözat ekranında zaten var.
  Widget get _siralamaSecici => Padding(
    padding: const EdgeInsets.fromLTRB(12, 12, 0, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.sort, size: 17, color: DiziRenkler.metin54),
            const SizedBox(width: 6),
            Text(
              'Sıralama'.c,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: DiziRenkler.metin54,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tüm raflara uygulanır'.c,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: DiziRenkler.metin38),
              ),
            ),
          ],
        ),
        SizedBox(
          // 48 px: çipin dokunma hedefi (`padded`) sığsın, satır kırpılmasın.
          height: 48,
          // TEMBEL LİSTE DEĞİL `SingleChildScrollView` + `Row`: seçenek sayısı
          // SABİT ve altı tane. `ListView` yalnız GÖRÜNENİ kurar, yani dar
          // ekranda "Yorum sayısı" çipi ağaca hiç girmezdi — ekran okuyucu onu
          // duyuramaz, klavyeyle sekmeyle ulaşılamaz ve widget testi
          // bulamaz (ilk yazımda tam bu yüzden iki test düştü). Altı kısa çipi
          // peşin kurmanın maliyeti yok.
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                for (final s in _siralamaSecenekleri) ...[
                  if (s != _siralamaSecenekleri.first) const SizedBox(width: 8),
                  ChoiceChip(
                    key: Key('sirala-${s.deger ?? 'varsayilan'}'),
                    label: Text(s.etiket.c),
                    selected: s.deger == _sira.deger,
                    // Dokunma hedefi ikonla değil ÇEVRESİYLE büyütülür (44 px
                    // kuralı) — `padded` bunu Material'a yaptırır.
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onSelected: (secildi) {
                      if (secildi) _siralaSec(s);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        // DÜRÜSTLÜK NOTU: bizim verimizle sıralarken liste sonludur
        // (bkz. [_havuzTavani]). Bunu yazmazsak kullanıcı "firmanın TÜM
        // yapımları arasında en yüksek puanlı" sanır — oysa sıralama en
        // popüler 100 yapım havuzunda yapılıyor.
        if (_sira.alan != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2, right: 12),
            child: Text(
              'En popüler {} yapım arasında sıralandı'.cf([_havuzTavani]),
              style: TextStyle(fontSize: 11.5, color: DiziRenkler.metin38),
            ),
          ),
      ],
    ),
  );

  /// Çipe dokunuldu: durumu ÖNCE yaz, adresi sonra güncelle.
  ///
  /// SIRA ÖNEMLİ: `replace` sayfayı aynı sayfa anahtarıyla değiştirdiği için
  /// durum korunur ve [didChangeDependencies] yeni adresle bir kez daha
  /// çalışır. `_sira` orada zaten güncel olduğu için raflar İKİNCİ KEZ
  /// yüklenmez.
  void _siralaSec(_Sira yeni) {
    if (yeni.deger == _sira.deger) return;
    setState(() => _sira = yeni);
    _raflariTazele();
    _adresiGuncelle();
  }

  /// Seçimi adrese yaz — F5'te korunsun, bağlantı paylaşılabilsin.
  ///
  /// `replace` (push DEĞİL): her sıralama denemesi geçmişe bir kayıt eklerse
  /// kullanıcı geri tuşuyla firmadan çıkamaz, altı kez sıralama gezinir.
  /// try/catch: yönlendirici olmadan kurulmuş ekranda (widget testi) sessiz
  /// geçilir — seçim yine de çalışır.
  void _adresiGuncelle() {
    try {
      GoRouter.of(context).replace(
        sirketYolu(
          widget.sirketId,
          ad: widget.sirketAdi,
          tur: widget.baslangicTuru,
          sirala: _sira.deger,
        ),
      );
    } catch (_) {
      // Adres yazılamadı; sayfa çalışmaya devam eder.
    }
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
    final ogeler = _siraliOgeler(raf);
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
            // Sıralama seçici RAFLARIN ÜSTÜNDE: hepsine birden uygulanıyor
            // (gerekçe [_siralamaSecici] üstünde).
            SliverToBoxAdapter(child: _siralamaSecici),
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
