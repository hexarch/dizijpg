import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../ceviri.dart';
import '../sohbet_olay.dart';
import '../tema.dart';
import 'arama_cubugu.dart';
import 'ortak.dart';

/// Ana Sayfa rafları: (başlık, TMDB yolu, tür).
///
/// Yol sayfa parametresi İÇERMEZ — raf ilk sayfayı gösterir, "Tümünü gör"
/// ekranı aynı yolu sayfalayarak devam ettirir.
const anaSayfaRaflari = <(String, String, String)>[
  ('Haftanın Dizileri', '/tmdb/trending/tv/week', 'tv'),
  ('Haftanın Filmleri', '/tmdb/trending/movie/week', 'movie'),
  (
    'Türk Dizileri',
    '/tmdb/discover/tv?sort_by=popularity.desc&with_original_language=tr',
    'tv',
  ),
  (
    'Türk Filmleri',
    '/tmdb/discover/movie?sort_by=popularity.desc&with_original_language=tr',
    'movie',
  ),
  (
    'En Yüksek Puanlı Filmler',
    '/tmdb/discover/movie?sort_by=vote_average.desc&vote_count.gte=3000',
    'movie',
  ),
  (
    'En Yüksek Puanlı Diziler',
    '/tmdb/discover/tv?sort_by=vote_average.desc&vote_count.gte=1000',
    'tv',
  ),
  (
    'En Çok İzlenen Filmler',
    '/tmdb/discover/movie?sort_by=popularity.desc&vote_count.gte=500',
    'movie',
  ),
  (
    'Popüler Diziler',
    '/tmdb/discover/tv?sort_by=popularity.desc&vote_count.gte=200',
    'tv',
  ),
  (
    'En Çok Kazanan Filmler',
    '/tmdb/discover/movie?sort_by=revenue.desc&vote_count.gte=500',
    'movie',
  ),
  (
    'Kült Filmler',
    '/tmdb/discover/movie?sort_by=vote_count.desc&vote_average.gte=7.5'
        '&primary_release_date.lte=2005-12-31',
    'movie',
  ),
  (
    'Tüm Zamanların En İyileri',
    '/tmdb/discover/movie?sort_by=vote_count.desc&vote_average.gte=8',
    'movie',
  ),
  (
    'Yeni Diziler',
    '/tmdb/discover/tv?sort_by=first_air_date.desc&vote_count.gte=20',
    'tv',
  ),
  (
    'Yeni Filmler',
    '/tmdb/discover/movie?sort_by=primary_release_date.desc'
        '&vote_count.gte=100',
    'movie',
  ),
];

/// "Sana Özel" rafının başlığı (çeviri anahtarı) ve tam sayfa adresi.
///
/// NEDEN `anaSayfaRaflari`NDA DEĞİL: o tablo üçlüsü (ad, TMDB yolu, tür)
/// Keşfet'in raf ÇEKME döngüsünü de besliyor (`for (final r in anaSayfaRaflari)
/// Api.get(r.$2)`). Buraya bir kayıt eklemek üç şeyi birden bozardı:
///  1. Raf İKİ KEZ çekilirdi (döngüde bir, aşağıdaki `if (Api.girisli)`
///     dalında bir),
///  2. Döngü oturumu SORMUYOR — oturumsuz ziyaretçi `/onerilen`den 401 yerdi,
///  3. Yanıtın liste alanı `results` değil `oneriler`.
///
/// NEDEN ADRES `/raf/sana-ozel` DEĞİL, KÖK YOL: bu raf kişiye özel, yani rota
/// OTURUM ZORUNLU ve robots.txt ile kapatılmalı. Projede robots.txt kuralları
/// JOKER İÇERMİYOR (`backend/test/seo_gizlilik.test.js` kilitliyor); tek bir
/// `/raf/...` alt yolunu kapatmanın yolu ya joker ya da `/raf/` ön ekinin
/// tamamını kapatmaktı — ikincisi herkese açık katalog sayfalarını da taramaya
/// kapatırdı. Kök yol ikisini de gerektirmez.
const sanaOzelBaslik = 'Sana Özel';
const sanaOzelYolu = '/sana-ozel';

/// Kişiselleştirilmiş tematik raf başlığı (çeviri anahtarı + firma/yönetmen adı).
///
/// TEK ANAHTAR, YER TUTUCULU: raf başlıkları firma ya da yönetmen ADI içeriyor
/// ("Marvel Studios filmleri", "Nuri Bilge Ceylan filmleri"). Her ad için ayrı
/// anahtar açmak 45 dil × N firma demekti; iki anahtar (`{} dizileri`,
/// `{} filmleri`) bütün rafları karşılıyor. Ad ÇEVRİLMEZ — TMDB'deki özel ad.
///
/// Türkçede iki tür için ayrı anahtar şart: "dizileri"/"filmleri" tek bir
/// "{} yapımları"na indirgenebilirdi ama o zaman kullanıcı rafın dizi mi film
/// mi olduğunu başlıktan anlayamazdı (raf ikiye bölünmüş halde geliyor).
String kisiselRafBasligi(Map<String, dynamic> raf) {
  final ad = '${raf['ad'] ?? ''}';
  return (raf['medya'] == 'tv' ? '{} dizileri' : '{} filmleri').cf([ad]);
}

/// Kişisel raf başlığına dokununca açılan sayfa.
///
/// YENİ ROTA AÇILMADI: firma rafının tam listesi zaten `/sirket/:id`, yönetmen
/// rafınınki `/kisi/:id`. Bu sayfalar SSR'lı, oturumsuz da açılıyor ve rafla
/// AYNI TMDB sorgusundan besleniyor — "Tümünü gör" için ayrı bir ekran yazmak
/// üçüncü bir kopya olurdu.
String kisiselRafYolu(Map<String, dynamic> raf) =>
    raf['tip'] == 'firma' ? '/sirket/${raf['id']}' : '/kisi/${raf['id']}';

/// Türkçe raf başlığından üretilen KALICI adres parçası (`/raf/:slug`).
///
/// NEDEN BAŞLIKTAN, NEDEN İNDEKSTEN DEĞİL: indeks kullansaydık
/// [anaSayfaRaflari]'na araya bir raf eklemek paylaşılmış/yer imlenmiş tüm
/// adresleri BAŞKA bir rafa çevirirdi. Slug listedeki sırayla değil, rafın
/// kendi kimliğiyle bağlı.
///
/// ÇEVİRİDEN DEĞİL, TÜRKÇE ANAHTARDAN: başlık 45 dile çevriliyor; çeviriden
/// üretilen adres kullanıcının diline göre değişir ve İngilizce açılan bir
/// bağlantı Türkçe oturumda kırılırdı.
///
/// Türkçe harfler ÖNCE katlanır, SONRA küçük harfe inilir: Dart'ın
/// `toLowerCase()`i 'İ'yi iki kod birimine ('i' + birleşen nokta) çevirir ve
/// adreste görünmez bir karakter bırakırdı.
String rafSlug(String baslik) {
  const katla = {
    'Ç': 'C',
    'Ğ': 'G',
    'İ': 'I',
    'Ö': 'O',
    'Ş': 'S',
    'Ü': 'U',
    'ç': 'c',
    'ğ': 'g',
    'ı': 'i',
    'ö': 'o',
    'ş': 's',
    'ü': 'u',
  };
  final duz = baslik.split('').map((h) => katla[h] ?? h).join();
  return duz
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp('^-+|-+\$'), '');
}

/// [rafSlug] ile eşleşen rafı bulur; yoksa null (bozuk/eski bağlantı).
(String, String, String)? rafBul(String? slug) {
  if (slug == null || slug.isEmpty) return null;
  for (final raf in anaSayfaRaflari) {
    if (rafSlug(raf.$1) == slug) return raf;
  }
  return null;
}

class KesfetEkrani extends StatefulWidget {
  const KesfetEkrani({super.key});

  @override
  State<KesfetEkrani> createState() => _KesfetEkraniState();
}

class _KesfetEkraniState extends State<KesfetEkrani> {
  Map<String, List<dynamic>>? _bolumler;

  // --- kişiselleştirilmiş tematik raflar (21 Ağu 2026) ---
  //
  // YERLEŞİM KARARI: 1. SAYFA "Sana Özel"in hemen ALTINDA, sonraki sayfalar
  // listenin EN SONUNDA. Gerekçe kaydırma sıçraması: bir ListView'a içerik
  // EKLEMEK yalnız SONA eklendiğinde okunmakta olan içeriği yerinden
  // oynatmaz. Sayfa 2+ kullanıcı zaten dibe indiğinde geliyor, yani sona
  // eklenmeli; 1. sayfa ise ilk çizimin parçası (ve önbellekten anında
  // geliyor), o yüzden en değerli yere — üste — konabiliyor.
  final List<dynamic> _kisisel = [];
  // Önceki oturumun 1. sayfası (SWR). Ağdan ilk sayfa gelene KADAR çizilir;
  // `_kisisel` ile ASLA birleştirilmez, yoksa aynı raf iki kez görünürdü.
  List<dynamic> _kisiselOnbellek = const [];
  // Ağdan gelen 1. sayfanın raf sayısı; listenin üst/alt bloğa bölündüğü yer.
  int _kisiselUstBlok = 0;
  int _kisiselSayfa = 0;
  bool _kisiselDevam = true;
  bool _kisiselYukleniyor = false;
  // Ağdan BİR yanıt alındı mı (boş bile olsa). Bayrak `_kisisel.isEmpty`
  // yerine gerekiyor: kullanıcı raflardaki her şeyi işaretlediğinde sunucu
  // BOŞ liste döner ve o an bayat önbellek kopyası sonsuza dek çizilmeye
  // devam ederdi — hem de içinde ARTIK İZLENMİŞ yapımlarla.
  bool _kisiselAgYaniti = false;

  /// Üst blok (Sana Özel'in altı): ağdan geldiyse o, gelmediyse önbellek.
  List<dynamic> get _kisiselUst => _kisiselAgYaniti
      ? _kisisel.sublist(0, _kisiselUstBlok)
      : _kisiselOnbellek;

  /// Alt blok (listenin sonu): 2. sayfadan itibaren gelenler.
  List<dynamic> get _kisiselAlt => _kisisel.length > _kisiselUstBlok
      ? _kisisel.sublist(_kisiselUstBlok)
      : const [];

  /// Okunmamış mesaj sayısını ORTAK KAYNAĞA yazar.
  ///
  /// Bu ekran artık sayıyı KENDİ ÇİZMİYOR (28 Ağu 2026: üst bardaki mesaj
  /// düğmesi kaldırıldı), ama istek YİNE DE atılıyor: alt çubuğun mesaj
  /// rozetini ve masaüstü gezinme adasını `SohbetOlaylari.okunmamis` besliyor
  /// ve ikisi de kendi isteğini atmıyor. Bu çağrı silinirse Ana Sayfa'da
  /// açılan kullanıcı, sohbete girene kadar rozeti hiç görmez.
  Future<void> _mesajSayisiYukle() async {
    // Oturumsuz ziyaretçi (SEO 1.4, 14 Ağu): rozet ucu girisZorunlu, 401
    // yememek için hiç isteme. Rozet zaten 0 kalır.
    if (!Api.girisli) return;
    try {
      final d = await Api.get('/sohbetler/okunmamis');
      SohbetOlaylari.okunmamis.value = (d['okunmamis'] as int?) ?? 0;
    } catch (_) {}
  }

  String? _hata;

  @override
  void initState() {
    super.initState();
    _onbellektenYukle();
    _yukle();
    _kisiselYukle();
    _mesajSayisiYukle();
  }

  /// Son başarılı raflar anında gösterilir (SWR): ekran boş iskelette
  /// beklemez, taze veri arkadan gelip üzerine yazar.
  Future<void> _onbellektenYukle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ham = prefs.getString('kesfet_onbellek');
      // Kişisel rafların İLK sayfası da önbellekten gelir. Amacı hız değil
      // DÜZEN: bu blok listenin ORTASINDA duruyor, ağdan sonradan gelirse
      // altındaki sabit rafları aşağı iterdi. Önbellekten gelince ilk çizimin
      // parçası olur ve hiçbir şey yerinden oynamaz.
      final hamKisisel = prefs.getString('kesfet_kisisel');
      if (!mounted || _bolumler != null) return;
      if (hamKisisel != null && _kisiselOnbellek.isEmpty) {
        _kisiselOnbellek = jsonDecode(hamKisisel) as List<dynamic>;
      }
      if (ham == null) {
        if (_kisiselOnbellek.isNotEmpty) setState(() {});
        return;
      }
      final d = jsonDecode(ham) as Map<String, dynamic>;
      setState(() {
        _bolumler = {for (final e in d.entries) e.key: e.value as List};
      });
    } catch (_) {}
  }

  /// Kişiselleştirilmiş tematik rafların BİR sayfası.
  ///
  /// SABİT RAFLARDAN AYRI İSTEK: uç soğuk önbellekte katalog profilini
  /// kurmak zorunda kalabiliyor (ölçülen en kötü hâl ~9 sn). Aynı
  /// `Future.wait` içine konsaydı bütün ana sayfa o süre boyunca iskelette
  /// beklerdi; ayrı istek geç gelirse yalnız kendi bloğu geç dolar.
  ///
  /// BOŞ SAYFA ATLAMA: bir sayfanın raflarının hepsi sunucudaki içerik eşiğini
  /// geçemezse liste BÜYÜMEZ, yani kaydırma tetikleyicisi bir daha ateşlenmez
  /// ve sayfalama orada donardı. Sunucu `devam: true` diyorsa en çok üç sayfa
  /// ileri atlanır (tavan `RAF_AZAMI_SAYFA` = 4 olduğu için bu tüm listeyi
  /// tarar, sonsuz döngü kurulamaz).
  Future<void> _kisiselYukle() async {
    if (_kisiselYukleniyor || !_kisiselDevam || !Api.girisli) return;
    _kisiselYukleniyor = true;
    if (mounted) setState(() {});
    final eklenen = <dynamic>[];
    var yanitVar = false;
    try {
      var sayfa = _kisiselSayfa + 1;
      for (var deneme = 0; deneme < 3; deneme++) {
        final d = await Api.get('/kisisel-raflar?sayfa=$sayfa');
        yanitVar = true;
        final gelen = d['raflar'] as List<dynamic>? ?? const <dynamic>[];
        _kisiselSayfa = sayfa;
        _kisiselDevam = d['devam'] == true;
        if (gelen.isNotEmpty) {
          eklenen.addAll(gelen);
          break;
        }
        if (!_kisiselDevam) break;
        sayfa++;
      }
    } catch (_) {
      // Sessiz DURDURMA: kişisel raf ikincil bir zenginleştirme, hata mesajı
      // basıp ana sayfayı kirletmez. Aşağı çekip yenilemek yeniden dener.
      // Ağ yanıtı ALINAMADIĞI için önbellek bloğu ekranda KALIR (çevrimdışı).
      _kisiselDevam = false;
    }
    _kisiselYukleniyor = false;
    if (!mounted) return;
    final ilkYanit = yanitVar && !_kisiselAgYaniti;
    setState(() {
      _kisisel.addAll(eklenen);
      if (ilkYanit) {
        _kisiselAgYaniti = true;
        _kisiselUstBlok = _kisisel.length;
      }
    });
    if (!ilkYanit) return;
    // Boş yanıt da YAZILIR (silinir): kullanıcı raftaki her şeyi izlediyse
    // eski kopya bir daha çizilmesin.
    SharedPreferences.getInstance().then((p) {
      if (_kisiselUstBlok == 0) return p.remove('kesfet_kisisel');
      return p.setString(
        'kesfet_kisisel',
        jsonEncode(_kisisel.sublist(0, _kisiselUstBlok)),
      );
    });
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      // Tüm raflar + öneriler paralel çekilir (öneri hatası rafları düşürmez).
      final istekler = <Future<dynamic>>[
        for (final r in anaSayfaRaflari) Api.get(r.$2),
        // /onerilen girisZorunlu — oturumsuz ziyaretçiye "Sana Özel" rafı yok.
        if (Api.girisli)
          Api.get(
            '/onerilen',
          ).catchError((_) => <String, dynamic>{'oneriler': <dynamic>[]})
        else
          Future<Map<String, dynamic>>.value({'oneriler': <dynamic>[]}),
      ];
      final sonuclar = await Future.wait(istekler);
      if (!mounted) return;
      final onerilen =
          (sonuclar.last['oneriler'] as List<dynamic>? ?? <dynamic>[]);
      final bolumler = <String, List<dynamic>>{
        if (onerilen.isNotEmpty) sanaOzelBaslik: onerilen,
        for (var i = 0; i < anaSayfaRaflari.length; i++)
          anaSayfaRaflari[i].$1:
              (sonuclar[i]['results'] as List<dynamic>? ?? <dynamic>[]),
      };
      setState(() => _bolumler = bolumler);
      SharedPreferences.getInstance().then(
        (p) => p.setString('kesfet_onbellek', jsonEncode(bolumler)),
      );
    } catch (e) {
      if (!mounted) return;
      if (_bolumler == null) setState(() => _hata = e.toString());
    }
  }

  /// Aşağı çekip yenileme: sabit rafları TAZELE, kişisel rafları SIFIRLA.
  ///
  /// Sıfırlamadan `_kisiselYukle()` çağırmak sayfa 2'yi isterdi; kullanıcı
  /// yenilediğinde beklediği şey listenin BAŞTAN kurulmasıdır. Önbellek
  /// bloğu (`_kisiselOnbellek`) DURUYOR: ağ yanıtı gelene kadar üst blok boş
  /// kalmasın, düzen oynamasın.
  Future<void> _tazele() async {
    // Ekrandaki 1. sayfa, ağ yanıtı gelene kadar SWR bloğu olarak dursun:
    // aksi hâlde blok bir an yok olur, altındaki her şey yukarı zıplardı.
    if (_kisiselAgYaniti && _kisiselUstBlok > 0) {
      _kisiselOnbellek = List<dynamic>.from(
        _kisisel.sublist(0, _kisiselUstBlok),
      );
    }
    _kisisel.clear();
    _kisiselUstBlok = 0;
    _kisiselSayfa = 0;
    _kisiselDevam = true;
    _kisiselAgYaniti = false;
    await Future.wait([_yukle(), _kisiselYukle()]);
  }

  /// Dikey liste dibe yaklaşınca bir sonraki kişisel raf sayfasını ister.
  ///
  /// `axis` KONTROLÜ ŞART: afiş şeritleri de YATAY kaydırma bildirimi
  /// yolluyor ve bu bildirimler aynı ağaçtan yukarı çıkıyor. Süzmezsek
  /// kullanıcı bir şeridi yana ittiğinde sayfalama tetiklenirdi.
  bool _kaydirmayiIzle(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    if (n.metrics.pixels >= n.metrics.maxScrollExtent - 800) _kisiselYukle();
    return false;
  }

  /// Kişisel raf listesini widget'lara çevirir (üst ve alt blok aynı biçim).
  List<Widget> _kisiselSeritler(List<dynamic> raflar) => [
    for (final ham in raflar)
      if (ham is Map)
        Builder(
          builder: (context) {
            final raf = Map<String, dynamic>.from(ham);
            final icerikler =
                raf['icerikler'] as List<dynamic>? ?? const <dynamic>[];
            // Sunucu ince rafı zaten göndermiyor; bu ikinci kapı ESKİ
            // önbellek kopyasına karşı (biçim değişirse boş şerit çizilmesin).
            if (icerikler.isEmpty) return const SizedBox.shrink();
            return PosterSeridi(
              baslik: kisiselRafBasligi(raf),
              icerikler: icerikler,
              turZorla: raf['medya'] as String?,
              onBaslikTap: () => context.push(kisiselRafYolu(raf)),
            );
          },
        ),
  ];

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_bolumler == null) {
      // İskelet raflar: içerik gelene dek nabız atan kutular
      govde = ListView(
        padding: const EdgeInsets.only(top: 8),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var s = 0; s < 3; s++) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IskeletKutu(genislik: 150, yukseklik: 18),
              ),
            ),
            // İskelet ölçüsü GERÇEK şeritle aynı olmalı: masaüstünde şerit
            // kartı 168 dp'ye büyüdü, iskelet 118'de kalsaydı içerik gelince
            // düzen zıplardı (CLS).
            SizedBox(
              height: seritKartiGenisligi(context) * 1.5 + seritBaslikPayi,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, __) =>
                    IskeletKutu(genislik: seritKartiGenisligi(context)),
              ),
            ),
          ],
        ],
      );
    } else {
      final rafMap = {for (final r in anaSayfaRaflari) r.$1: r};
      // "Sana Özel" varsa İLK sıradadır; kişisel tematik raflar onun HEMEN
      // ardına giriyor (ikisi de kişiye özel, birlikte tek bir blok okunuyor).
      final tumEntries = _bolumler!.entries.toList();
      final sanaOzelVar =
          tumEntries.isNotEmpty && tumEntries.first.key == sanaOzelBaslik;
      final ustDilim = sanaOzelVar
          ? tumEntries.take(1)
          : const <MapEntry<String, List<dynamic>>>[];
      final altDilim = sanaOzelVar ? tumEntries.skip(1) : tumEntries;
      Widget seritYap(MapEntry<String, List<dynamic>> e) => PosterSeridi(
        baslik: e.key.c,
        icerikler: e.value,
        turZorla: rafMap[e.key]?.$3,
        // "Sana Özel" 19 Ağu 2026'ya kadar "Tümünü gör"süz TEK raftı:
        // içeriği `/onerilen` ucundan geliyor, `anaSayfaRaflari`ndaki
        // gibi sabit bir TMDB yolu YOK, yani `/raf/:slug` onu
        // sayfalayamıyordu. Artık uç `?sayfa=` alıyor ve rafın kendi
        // tam sayfa adresi var ([sanaOzelYolu]).
        //
        // ADRESE YAZILAN gezinme (14 Ağu 2026). Eskiden burada
        // `Navigator.push(MaterialPageRoute(...))` vardı: sayfa
        // açılıyor ama URL `/kesfet`te kalıyordu, yani F5 kullanıcıyı
        // Keşfet'e geri atıyordu (canlıda ölçüldü). `context.push`
        // aynı görünümü verir — rota Keşfet şubesinin içinde, alt
        // gezinme çubuğu yerinde kalır — ama adres sayfayı yansıtır.
        onBaslikTap: e.key == sanaOzelBaslik
            ? () => context.push(sanaOzelYolu)
            : rafMap[e.key] == null
            ? null
            : () => context.push('/raf/${rafSlug(rafMap[e.key]!.$1)}'),
      );
      govde = RefreshIndicator(
        color: DiziRenkler.sari,
        onRefresh: _tazele,
        child: NotificationListener<ScrollNotification>(
          onNotification: _kaydirmayiIzle,
          child: ListView(
            children: [
              for (final e in ustDilim) seritYap(e),
              ..._kisiselSeritler(_kisiselUst),
              for (final e in altDilim) seritYap(e),
              ..._kisiselSeritler(_kisiselAlt),
              // Sayfa 2+ yüklenirken dipte küçük bir gösterge. Kişisel raf
              // KALMADIYSA hiçbir şey çizilmez — "bitti" yazısı, kullanıcının
              // farkında bile olmadığı bir bölümü ilan etmek olurdu.
              if (_kisiselYukleniyor && _kisisel.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    }

    final genis = masaustuMu(context);

    // Marka bloğu ve eylem ikonları iki düzende de AYNI yerden gelir: dar
    // ekranda AppBar'a, masaüstünde AramaCubugu'nun üst barına verilir.
    //
    // DAR EKRAN ÖLÇÜSÜ (360 dp): logo 40 + BETA 57 + sürüm 77 + boşluklar =
    // 204 dp, iki eylem ikonu 100 dp → arama kutusuna 56 dp kalıyordu; büyüteç
    // + tek kelimelik ipucu bile sığmaz. Bu yüzden dar ekranda logo 30'a
    // küçültüldü ve BETA rozeti gizlendi; beta ibaresi sürümün altına indi
    // (genişlik sürüm metniyle aynı kaldığı için kutudan yer çalmıyor).
    // Böylece kutuya ~127 dp açıldı.
    final marka = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/logo.png', height: genis ? 40 : 30),
        SizedBox(width: genis ? 8 : 6),
        // BETA rozeti (marka sarısı pill) — yalnız masaüstünde yer var
        if (genis) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: DiziRenkler.sari,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'BETA',
              style: TextStyle(
                color: Colors.black,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        // Sürüm numarası (yapı numarası olmadan). Dar ekranda BETA rozeti
        // sığmadığı için ibare sürümün ALTINDA küçük metinle yazılır
        // (23 Ağu 2026, kullanıcı isteği; önceki ipucu/erişilebilirlik
        // dolambacı kalktı — beta artık gözle görülür).
        genis
            ? Text(
                'v${Api.surum.split('+').first}',
                style: TextStyle(
                  color: DiziRenkler.metin38,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'v${Api.surum.split('+').first}',
                    style: TextStyle(
                      color: DiziRenkler.metin38,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'BETA',
                    style: TextStyle(
                      color: DiziRenkler.sari,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
      ],
    );
    final eylemler = <Widget>[
      // Katalog gözat (türe göre keşif)
      IconButton(
        tooltip: 'Gözat'.c,
        icon: const Icon(Icons.grid_view_outlined),
        onPressed: () => context.push('/gozat'),
      ),
      // MESAJLAR DÜĞMESİ KALDIRILDI (28 Ağu 2026, kullanıcı isteği) — gerekçe
      // ve uyarı akis.dart'taki ikizinde. Kısaca: alt çubukta zaten var,
      // rozeti de orada; ama [_mesajSayisiYukle] KALIR çünkü o rozeti besleyen
      // ortak kaynağa (`SohbetOlaylari.okunmamis`) yazan yer burasıdır.
      const SizedBox(width: 4),
    ];

    return Scaffold(
      // Masaüstünde AppBar YOK: arama kutusu pencerenin en üst satırında,
      // yatayda tam ortada dursun diye üst bar AramaCubugu'na devredildi.
      //
      // DAR EKRANDA arama kutusu artık üst barın İÇİNDE: marka bloğu (logo +
      // sürüm) ile eylem ikonlarının (Gözat, Mesajlar) TAM ARASINDA. Expanded
      // aradaki boşluğun tamamını kutuya verir; kutu ne taşar ne kırpılır.
      appBar: genis
          ? null
          : AppBar(
              titleSpacing: 12,
              title: Row(
                children: [
                  marka,
                  const SizedBox(width: 8),
                  const Expanded(child: AramaAcmaKutusu()),
                ],
              ),
              actions: eylemler,
            ),
      // Akışla AYNI arama bileşeni (ortak widget)
      body: AramaCubugu(
        cocuk: govde,
        logo: genis ? marka : null,
        eylemler: genis ? eylemler : const [],
      ),
    );
  }
}
