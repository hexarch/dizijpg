import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../api.dart';
import '../ceviri.dart';
import '../gorsel_basliklari.dart';
import '../tema.dart';
import '../yonlendirme.dart' show gonderiYolu;
import 'karsilama.dart' show karsilamaAylar;
import 'ortak.dart';

/// İSTATİSTİKLERİM — Ayarlar > İstatistiklerim (md. 24).
///
/// KULLANICI İSTEĞİ: "tüm zamanların görüntülenmesi, 30 / 60 / 90 / 120 günlük
/// görüntülenme; beğenilerde aynı kırılım." AMACI kendi sözleriyle: "neyini
/// tutuyorsak en net şekilde verelim ki kendi paylaşımlarının kalitesini
/// artırsın."
///
/// ===========================================================================
/// 14 AĞU 2026 — EKRANIN DÜZENİ YENİDEN KURULDU
/// ===========================================================================
/// KULLANICI: "bu istatistikler ekranını nasıl daha güzel yapacağız ya."
///
/// ESKİ DÜZENİN ÜÇ SOMUT KUSURU (koddan doğrulandı, tahmin değil):
///  (a) Pencere seçici EKRANIN ORTASINDAYDI ve altındaki her şeyi yönetiyordu,
///      ama ÜSTÜNDEKİ blok ondan hiç etkilenmiyordu. Bir denetimin yönettiği
///      şeyin altında durması, "üstteki de mi değişiyor?" sorusunu her
///      dokunuşta yeniden doğurur.
///  (b) "Tümü" seçiliyken AYNI SAYI EKRANDA İKİ KEZ yazıyordu: üstteki ömür
///      boyu sayaç ile pencere sayacı birebir aynı değerdi (`tumZaman ?
///      toplam[...] : p[...]`). Tekrar eden sayı, ikisinden birinin farklı bir
///      şeyi ölçtüğünü sanmaya yol açar.
///  (c) Sayıların YÖNÜ yoktu. "12.480 görüntülenme" iyi mi kötü mü? Kullanıcı
///      "kalitesini artırsın" diyorsa ekranın söylemesi gereken şey seviye
///      değil DEĞİŞİMDİR.
///
/// YENİ SIRA — dört hamle:
///   1. Seçici EN ÜSTTE: yönettiği her şeyin üstünde.
///   2. TEK kahraman sayı (seçili pencerenin görüntülenmesi) + yön oku + minik
///      eğri; altında ikincil üçlü (beğeni · yanıt · etkileşim oranı).
///   3. İki üst liste TEK listeye indi + sıralama seçici (görüntülenme /
///      beğeni / YANIT). `yanit` yeni: "en çok konuşulan" gönderi, "en çok
///      görüntülenen"den başka bir gönderidir ve iyileştirilecek şey odur.
///   4. "Tüm zamanlar" TEK SATIR olarak EN ALTA: o bir ÇIPA, manşet değil.
///      (b) maddesindeki tekrar da böylece ölür — "Tümü" seçiliyken çıpa
///      görüntülenmeyi TEKRARLAMAZ, yalnız gönderi sayısını söyler.
///
/// ===========================================================================
/// EKRANIN EN ÖNEMLİ KARARI: EKSİK VERİYİ SAKLAMAMAK
/// ===========================================================================
/// Görüntülenmenin ZAMAN kırılımı ancak 14 Ağustos 2026'daki altyapıdan sonra
/// birikmeye başladı; ondan öncesi için "son 30 gün" diye bir sayı YOKTUR ve
/// üretilemez. Bu ekran o boşluğu:
///   * tahminle DOLDURMAZ (oranlayıp şişirmez),
///   * sayıyı gizleyip soruyu yok SAYMAZ,
///   * sayının yanına "veri {tarih} tarihinden beri birikiyor, şu an {n}
///     günlük veri var" satırını koyar ve kısmi sayıyı bir rozetle işaretler.
/// Beğeni kırılımı ise `yorum_begeniler.tarih` sayesinde GERİYE DÖNÜK TAMDIR;
/// o yüzden beğeni sayısında rozet çıkmaz (yalnız kaydın başladığı gün, o da
/// pencere kapsamı aşıldığında).
///
/// *** YÖN OKU VE EĞRİ: "VERİ DOLUNCA KENDİLİĞİNDEN GÖRÜNSÜN" (kullanıcı) ***
/// İkisi de BUGÜN çizilemez: 30 günlük pencerenin "önceki 30 günü" elimizde
/// yok. Kod yine de YAZILDI ve kapsam kuralına bağlandı — sunucu kapsamı
/// örtmediği sürece `degisim`/`seri` null/boş gelir, ekran o parçayı HİÇ
/// çizmez. Kapsam dolduğu gün, TEK SATIR kod değişmeden ikisi de belirir.
/// Yaklaşık değer, oranlama, tahmin YASAK.
///
/// GRAFİK: EĞRİ VAR AMA MİNİK — BİLİNÇLİ. Eskiden hiç grafik yoktu, çünkü
/// elde 4 pencere × 2 ölçü = 8 KÜMÜLATİF sayı vardı ve onları çubuk grafiğe
/// koymak "30 < 60 < 90 < 120" merdivenini, yani hep artan ve hiçbir şey
/// söylemeyen bir şekli çizerdi. Sunucu artık GÜN GÜN seri veriyor; günlük
/// seri kümülatif değildir, düşebilir — yani "son ayım yükseliyor mu?"
/// sorusuna "hayır" da diyebilir. Grafiğin var olma sebebi budur.
class IstatistiklerimEkrani extends StatefulWidget {
  const IstatistiklerimEkrani({super.key});

  @override
  State<IstatistiklerimEkrani> createState() => _IstatistiklerimEkraniState();
}

/// Tek listenin sıralama seçenekleri: sunucu etiketi → ekran etiketi anahtarı.
///
/// Anahtarlar sunucudaki `GONDERI_SIRALAMALARI` beyaz listesiyle BİREBİR aynı;
/// tanınmayan bir etiket sunucuda sessizce 'goruntulenme'ye düşer.
const Map<String, String> istatistikSiralamalari = {
  'goruntulenme': 'Görüntülenme',
  'begeni': 'Beğeni',
  'yanit': 'Yanıtlar',
};

/// Sıralama ölçüsünün satırda gösterilen alanı ve ikonu.
const Map<String, ({String alan, IconData ikon})> _siralamaOlcusu = {
  'goruntulenme': (
    alan: 'pencere_goruntulenme',
    ikon: Icons.visibility_outlined,
  ),
  'begeni': (alan: 'pencere_begeni', ikon: Icons.favorite),
  'yanit': (alan: 'pencere_yanit', ikon: Icons.mode_comment_outlined),
};

class _IstatistiklerimEkraniState extends State<IstatistiklerimEkrani> {
  /// Seçili pencere (gün). 0 = tüm zamanlar. Sunucudaki beyaz listeyle aynı.
  int _gun = 30;

  /// Seçili sıralama (`istatistikSiralamalari` anahtarı).
  String _sirala = 'goruntulenme';
  Map<String, dynamic>? _veri;
  String? _hata;

  /// Pencere değiştirilirken ESKİ SAYILAR EKRANDA KALIR (yalnız üstte ince bir
  /// çizgi döner): her dokunuşta ekranı iskelete çevirmek, kullanıcının iki
  /// pencereyi karşılaştırmasını imkânsız kılardı.
  bool _yukleniyor = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final gun = _gun;
    final sirala = _sirala;
    setState(() {
      _hata = null;
      _yukleniyor = true;
    });
    try {
      final d = await Api.get(
        '/istatistiklerim/gonderiler?gun=$gun&sirala=$sirala',
      );
      // Hızlı pencere/sıralama geçişinde geciken ESKİ yanıt düşsün: yoksa
      // 120'ye basıp 30'a dönen kullanıcı bir an 120'nin sayılarını görürdü.
      if (!mounted || gun != _gun || sirala != _sirala) return;
      setState(() {
        _veri = (d as Map).cast<String, dynamic>();
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted || gun != _gun || sirala != _sirala) return;
      setState(() {
        _hata = e.toString();
        _yukleniyor = false;
      });
    }
  }

  void _pencereSec(int gun) {
    if (gun == _gun) return;
    setState(() => _gun = gun);
    _yukle();
  }

  void _siralaSec(String sirala) {
    if (sirala == _sirala || !istatistikSiralamalari.containsKey(sirala)) {
      return;
    }
    setState(() => _sirala = sirala);
    _yukle();
  }

  /// Seçili pencerenin sunucudan gelen satırı (tüm zamanlarda null).
  Map<String, dynamic>? get _pencere {
    final liste = _veri?['pencereler'] as List<dynamic>? ?? const [];
    for (final p in liste) {
      if ((p as Map)['gun'] == _gun) return p.cast<String, dynamic>();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_hata != null && _veri == null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_veri == null) {
      govde = const _Iskelet();
    } else if ((_veri!['gonderi_sayisi'] as int? ?? 0) == 0) {
      govde = BosDurum(
        ikon: Icons.insights_outlined,
        baslik: 'Henüz gönderin yok'.c,
        ipucu:
            'Bir dizi ya da filme yorum yazdığında görüntülenme ve beğeni sayıların burada birikmeye başlar.'
                .c,
      );
    } else {
      govde = RefreshIndicator(
        color: DiziRenkler.sari,
        onRefresh: _yukle,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            12,
            12,
            12,
            altGuvenli(context, ekstra: 24),
          ),
          children: _icerik(context),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('İstatistiklerim'.c),
        // Yükleme göstergesi başlıkta: liste yerinde kalsın, sayılar zıplamasın.
        bottom: _yukleniyor
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: DiziRenkler.sari,
                ),
              )
            : null,
      ),
      body: OrtaKolon(azami: masaustuKolonGenisligi, cocuk: govde),
    );
  }

  List<Widget> _icerik(BuildContext context) {
    final v = _veri!;
    final toplam = (v['toplam'] as Map?)?.cast<String, dynamic>() ?? const {};
    final p = _pencere;
    final tumZaman = _gun == 0;
    // Tüm zamanlar seçiliyken pencere ölçüsü = ömür boyu sayaç.
    final gorSayi = tumZaman
        ? (toplam['goruntulenme'] as int? ?? 0)
        : (p?['goruntulenme'] as int? ?? 0);
    final begSayi = tumZaman
        ? (toplam['begeni'] as int? ?? 0)
        : (p?['begeni'] as int? ?? 0);
    final yanSayi = tumZaman
        ? (toplam['yanit'] as int? ?? 0)
        : (p?['yanit'] as int? ?? 0);
    // "Tam" bilgisi yalnız pencerelerde anlamlı: ömür boyu sayaç eksiksizdir
    // (o rakam ilk günden beri artıyor, kaybolan bir şey yok).
    final gorTam = tumZaman || (p?['goruntulenme_tam'] == true);
    final begTam = tumZaman || (p?['begeni_tam'] == true);

    // YÖN ve EĞRİ: sunucu kapsamı örtmüyorsa null/boş gelir ⇒ ÇİZİLMEZ.
    final degisim = tumZaman ? null : p?['degisim'] as int?;
    final seri = [
      for (final s in (v['seri'] as List<dynamic>? ?? const []))
        (s as Map)['goruntulenme'] as int? ?? 0,
    ];

    final etkilesim = (v['etkilesim'] as Map?)?.cast<String, dynamic>();
    final oran = (etkilesim?['oran'] as num?)?.toDouble();

    return [
      // --- 1) SEÇİCİ EN ÜSTTE: yönettiği her şeyin üstünde ------------------
      _PencereSecici(secili: _gun, onSec: _pencereSec),
      const SizedBox(height: 12),

      // --- 2) KAHRAMAN SAYI + yön + eğri -----------------------------------
      _Kahraman(
        deger: gorSayi,
        eksik: !gorTam,
        degisim: degisim,
        oncekiGun: _gun,
        seri: seri,
      ),
      const SizedBox(height: 8),

      // --- İKİNCİL ÜÇLÜ ----------------------------------------------------
      // IntrinsicHeight ŞART: üç kartın etiketi farklı uzunlukta ("Beğeni" tek
      // satır, "Etkileşim oranı" çoğu dilde iki satır) ve `stretch` TEK BAŞINA
      // ListView'in SONSUZ yüksekliğini çocuklara geçirip patlıyor. Üçünün alt
      // kenarı hizalı olmazsa satır kırık görünür.
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _Sayac(
                ikon: Icons.favorite_border,
                etiket: 'Beğeni'.c,
                deger: sayiBicimle(begSayi),
                eksik: !begTam,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Sayac(
                ikon: Icons.mode_comment_outlined,
                etiket: 'Yanıtlar'.c,
                deger: sayiBicimle(yanSayi),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Sayac(
                ikon: Icons.auto_graph,
                etiket: 'Etkileşim oranı'.c,
                // Oran ancak pencere TAM ölçüldüyse ve yeterli gönderi varsa
                // gelir; gelmediğinde tire konur, uydurma sayı DEĞİL.
                deger: oran == null
                    ? '—'
                    : '%{}'.cf([yuzdeBicimle(oran * 100)]),
                ipucu: oran == null
                    ? 'Etkileşim oranı henüz ölçülemedi'.c
                    : null,
              ),
            ),
          ],
        ),
      ),
      ..._kapsamNotu(gorTam: gorTam, begTam: begTam),
      const SizedBox(height: 18),

      // --- 3) TEK LİSTE + SIRALAMA SEÇİCİ ----------------------------------
      Row(
        children: [
          Expanded(child: _Baslik('Gönderilerin'.c)),
          _SiralaSecici(secili: _sirala, onSec: _siralaSec),
        ],
      ),
      const SizedBox(height: 2),
      ..._liste(v['gonderiler']),
      const SizedBox(height: 16),

      // --- 4) TÜM ZAMANLAR: ÇIPA, EN ALTTA, TEK SATIR ----------------------
      // "Tümü" seçiliyken görüntülenme YAZILMAZ: kahraman sayı zaten o rakam.
      _Cipa(
        gonderi: v['gonderi_sayisi'] as int? ?? 0,
        goruntulenme: tumZaman ? null : (toplam['goruntulenme'] as int? ?? 0),
      ),
    ];
  }

  /// "Veri biriktiriliyor" satırı — SAHTE SAYI ÜRETMEMENİN GÖRÜNEN YÜZÜ.
  List<Widget> _kapsamNotu({required bool gorTam, required bool begTam}) {
    final v = _veri!;
    final notlar = <String>[];
    if (!gorTam) {
      final bas = v['goruntulenme_baslangic'] as String?;
      final kacGun = v['goruntulenme_gun'] as int? ?? 0;
      notlar.add(
        bas == null
            ? 'Görüntülenme geçmişi henüz birikmeye başlamadı; ilk gün verisi yarın görünür.'
                  .c
            : 'Görüntülenme geçmişi {} tarihinden beri birikiyor ({} günlük veri var), bu yüzden {} günlük sayı henüz eksik.'
                  .cf([_tarih(bas), kacGun, _gun]),
      );
    }
    if (!begTam && v['begeni_baslangic'] != null) {
      notlar.add(
        'Beğeni geçmişi {} tarihinden beri kayıtlı.'.cf([
          _tarih(v['begeni_baslangic'] as String),
        ]),
      );
    }
    if (notlar.isEmpty) return const [];
    return [
      const SizedBox(height: 10),
      for (final n in notlar)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.hourglass_bottom,
                size: 15,
                color: DiziRenkler.metin38,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  n,
                  style: TextStyle(
                    color: DiziRenkler.metin54,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _liste(dynamic ham) {
    final satirlar = (ham as List<dynamic>? ?? const []);
    if (satirlar.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Bu dönemde gösterilecek gönderi yok.'.c,
            style: TextStyle(color: DiziRenkler.metin38, fontSize: 13),
          ),
        ),
      ];
    }
    final icerikler =
        (_veri!['icerikler'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return [
      for (final s in satirlar)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _GonderiSatiri(
            gonderi: (s as Map).cast<String, dynamic>(),
            icerik: (icerikler['${s['tur']}:${s['tmdb_id']}'] as Map?)
                ?.cast<String, dynamic>(),
            sirala: _sirala,
          ),
        ),
    ];
  }

  /// "2026-08-14" → "14 Ağustos 2026". Ay adları KARŞILAMA ekranındaki 12
  /// çeviri anahtarından okunuyor — aynı listeyi ikinci kez açmak, 45 dilde
  /// 12 anahtarı boşuna çoğaltmak olurdu (`intl`in DateFormat'ı kullanılamaz:
  /// uygulama `initializeDateFormatting` çağırmıyor).
  String _tarih(String iso) {
    final p = iso.split('T').first.split('-');
    if (p.length != 3) return iso;
    final ay = int.tryParse(p[1]);
    if (ay == null || ay < 1 || ay > 12) return iso;
    return '${int.tryParse(p[2]) ?? p[2]} ${karsilamaAylar[ay - 1].c} ${p[0]}';
  }
}

/// Binlik ayraçlı sayı: "1234567" değil "1.234.567" (okunurluk kuralı).
String sayiBicimle(int n) =>
    NumberFormat.decimalPattern(Ceviri.dil.value).format(n);

/// Tek ondalıklı yüzde GÖVDESİ ("7,8" / "7.8") — işaretsiz.
///
/// YÜZDE İŞARETİ BURADA YOK, BİLEREK: işaretin yeri dile göre değişiyor
/// (tr "%7,8", en "7.8%", fr "7,8 %", fa "۷٫۸٪"). Sayı `'%{}'` çeviri
/// anahtarına GÖVDE olarak veriliyor, işareti dil dosyası koyuyor.
/// Ondalık AYRACI da yereldir; bu yüzden `toStringAsFixed` değil NumberFormat.
String yuzdeBicimle(double n) =>
    (NumberFormat.decimalPattern(Ceviri.dil.value)
          ..minimumFractionDigits = 1
          ..maximumFractionDigits = 1)
        .format(n);

/// Artış rengi.
///
/// Koyu tema `DiziRenkler.cevrimiciYesil` ile AYNI ton (tek yeşil kimliği),
/// AÇIK tema ise BİLEREK FARKLI: `cevrimiciYesil`in açık tonu (#1B9E4B) beyaz
/// kart üstünde 3,5:1 verir ve o değer GRAFİK NESNE eşiğine (3:1) göre
/// seçilmişti — orası bir NOKTA. Burada aynı renk 14 px KALIN YAZI taşıyor;
/// yazının eşiği 4,5:1'dir (WCAG 1.4.3; 14 px kalın "büyük yazı" sayılmaz,
/// büyük sayılmak için ≥18,66 px kalın gerekir). #157A38 beyazda 5,4:1,
/// kırık beyazda 5,0:1 verir.
Color get _artisRengi =>
    DiziRenkler.acik ? const Color(0xFF157A38) : DiziRenkler.cevrimiciYesil;

/// Düşüş rengi. Açık temada beyaz kart üstünde 5,6:1, koyu temada #1F1F23
/// üstünde 7,2:1 — ikisi de metin eşiğinin (4,5:1) üstünde.
Color get _dususRengi =>
    DiziRenkler.acik ? const Color(0xFFC0332F) : const Color(0xFFFF8A85);

class _Baslik extends StatelessWidget {
  final String metin;

  const _Baslik(this.metin);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      metin,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
    ),
  );
}

/// KAHRAMAN SAYI — ekranın tek manşeti: seçili penceredeki görüntülenme.
///
/// Neden TEK sayı: eskiden burada iki büyük sayaç (görüntülenme + beğeni) yan
/// yanaydı ve göz hangisinin manşet olduğunu bilemiyordu. Bir ekranın bir
/// cevabı olur; beğeni/yanıt/etkileşim bir tık aşağıda, daha küçük puntoda.
///
/// YÖN OKU ve EĞRİ, VERİ YOKSA HİÇ ÇİZİLMEZ (sunucu null/boş gönderir).
class _Kahraman extends StatelessWidget {
  final int deger;

  /// Pencerenin tamamı ölçülemediyse true → kum saati rozeti.
  final bool eksik;

  /// Önceki EŞİT UZUNLUKTAKİ döneme göre yüzde değişim; null → ok yok.
  final int? degisim;

  /// Kıyas döneminin uzunluğu ("önceki 30 güne göre").
  final int oncekiGun;

  /// Gün gün görüntülenme; 2'den az nokta varsa eğri çizilmez.
  final List<int> seri;

  const _Kahraman({
    required this.deger,
    required this.eksik,
    required this.degisim,
    required this.oncekiGun,
    required this.seri,
  });

  @override
  Widget build(BuildContext context) {
    final yazi = sayiBicimle(deger);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Semantics(
                    // *** container: true ŞART ***  `Semantics` VARSAYILAN OLARAK kendi
                    // düğümünü KURMAZ; etiketini en yakın ÜST düğüme yazar. Bu ekranda
                    // sayaçlar ve rozetler yan yana duruyor; hepsi tek düğüme karışınca
                    // ekran okuyucu "Görüntülenme: 12.480 Beğeni: 842 Yanıtlar: 126" diye
                    // TEK cümle okuyor ve parmakla tek tek gezilemiyordu (14 Ağu 2026,
                    // semantik ağaç dökülerek görüldü).
                    container: true,
                    label:
                        '${'Görüntülenme'.c}: $yazi'
                        '${eksik ? ', ${'eksik veri'.c}' : ''}',
                    excludeSemantics: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // FittedBox: 7 haneli sayı 360 dp'de taşmasın, küçülsün.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            yazi,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 32,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                              color: DiziRenkler.metin,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.visibility_outlined,
                              size: 14,
                              color: DiziRenkler.sariMetin,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'Görüntülenme'.c,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: DiziRenkler.metin54,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (eksik) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.hourglass_bottom,
                                size: 13,
                                color: DiziRenkler.metin38,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (degisim != null) ...[
                  const SizedBox(width: 8),
                  _YonRozeti(yuzde: degisim!, oncekiGun: oncekiGun),
                ],
              ],
            ),
            if (seri.length >= 2) ...[
              const SizedBox(height: 10),
              _Sparkline(seri: seri),
            ],
          ],
        ),
      ),
    );
  }
}

/// YÖN ROZETİ — "▲ +%18 / önceki 30 güne göre".
///
/// ANLAM ÜÇ KANALDAN BİRDEN GİDER (renk körlüğü kuralı, md. 24):
///   1. İŞARET: yazının başındaki + / − (U+2212, gerçek eksi).
///   2. ŞEKİL:  trending_up / trending_down / trending_flat ikonu.
///   3. RENK:   yeşil / kırmızı / nötr — YALNIZ bu üçüncüsü olsaydı gri
///              tonlamalı bir ekranda artışla düşüş ayırt edilemezdi.
/// Ekran okuyucu ise tam cümleyi duyar ("önceki 30 güne göre %18 arttı").
///
/// ±%2'lik bant "değişmedi" sayılır: 1 puanlık salınımı haber diye sunmak
/// kullanıcıyı yanıltır (md. 23'teki ±%5 bandıyla aynı disiplin; burada bant
/// dar tutuldu çünkü sunucu zaten `YON_EN_AZ_GORUNTULENME` eşiğini geçmiş
/// bir paydayla hesaplıyor).
class _YonRozeti extends StatelessWidget {
  final int yuzde;
  final int oncekiGun;

  const _YonRozeti({required this.yuzde, required this.oncekiGun});

  @override
  Widget build(BuildContext context) {
    final duz = yuzde.abs() <= 2;
    final artis = yuzde > 0;
    final renk = duz
        ? DiziRenkler.metin70
        : (artis ? _artisRengi : _dususRengi);
    final ikon = duz
        ? Icons.trending_flat
        : (artis ? Icons.trending_up : Icons.trending_down);
    final govde = '%{}'.cf([yuzde.abs()]);
    final metin = duz ? govde : '${artis ? '+' : '−'}$govde';
    final sesli = duz
        ? 'önceki {} güne göre değişmedi'.cf([oncekiGun])
        : (artis
              ? 'önceki {} güne göre %{} arttı'.cf([oncekiGun, yuzde])
              : 'önceki {} güne göre %{} azaldı'.cf([oncekiGun, -yuzde]));
    return Semantics(
      // container: true — yoksa etiket üst düğüme karışır (bkz. [_Kahraman]).
      container: true,
      label: sesli,
      excludeSemantics: true,
      child: ConstrainedBox(
        // Kahraman sayı sahnenin ortasında kalsın: rozet en fazla ekranın
        // üçte biri kadar yer kaplar, uzun çevirilerde iki satıra sarar.
        constraints: const BoxConstraints(maxWidth: 132),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(ikon, size: 16, color: renk),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    metin,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: renk,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            Text(
              'önceki {} güne göre'.cf([oncekiGun]),
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: DiziRenkler.metin38, fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// MİNİK EĞRİ (sparkline) — kahraman sayının şekli.
///
/// Yeni paket YOK: md. 23'ün `_CizgiCizer`ıyla aynı görsel dil ve aynı
/// `CustomPainter` kalıbı — ince çizgi, düşük opaklıkta alan dolgusu,
/// `metin12` taban çizgisi. Fark: burada eksen, ızgara ve etiket YOK; bir
/// sparkline "kaç" sorusunu değil "nasıl gidiyor" sorusunu cevaplar, sayı
/// zaten hemen üstünde yazıyor.
///
/// TABAN SIFIR (md. 23'te en küçük değerdi): burada seri GÜNLÜK görüntülenme,
/// yani 0 gerçek ve anlamlı bir dip — "o gün hiç görüntülenme gelmedi". Tabanı
/// en küçük değere oturtmak, sıfır günleri sanki bir taban seviyesiymiş gibi
/// gösterirdi.
class _Sparkline extends StatelessWidget {
  final List<int> seri;

  const _Sparkline({required this.seri});

  @override
  Widget build(BuildContext context) {
    final enBuyuk = seri.reduce(math.max);
    final enKucuk = seri.reduce(math.min);
    return Semantics(
      // container: true — yoksa etiket üst düğüme karışır (bkz. [_Kahraman]).
      container: true,
      // Tuvalin ERİŞİLEBİLİR KARŞILIĞI: ekran okuyucu çizimi okuyamaz.
      label: 'Günlük görüntülenme: en düşük {}, en yüksek {}'.cf([
        sayiBicimle(enKucuk),
        sayiBicimle(enBuyuk),
      ]),
      excludeSemantics: true,
      child: SizedBox(
        height: 34,
        width: double.infinity,
        child: CustomPaint(
          painter: _SparklineCizer(
            seri: seri,
            cizgi: DiziRenkler.sariMetin,
            taban: DiziRenkler.metin12,
          ),
        ),
      ),
    );
  }
}

class _SparklineCizer extends CustomPainter {
  final List<int> seri;
  final Color cizgi;
  final Color taban;

  const _SparklineCizer({
    required this.seri,
    required this.cizgi,
    required this.taban,
  });

  @override
  void paint(Canvas tuval, Size boyut) {
    final n = seri.length;
    if (n < 2 || boyut.width <= 0 || boyut.height <= 0) return;
    // Çizginin 2 px kalınlığı üst/alt kenarda yarılanmasın diye 2 px pay.
    const pay = 2.0;
    final ust = pay;
    final alt = boyut.height - pay;
    if (alt <= ust) return;
    final enBuyuk = seri.reduce(math.max);
    // Aralık sıfırsa (hepsi aynı, ör. hepsi 0) yapay 1'lik aralık: bölme
    // sıfıra düşmesin, çizgi düpedüz yatay geçsin.
    final aralik = math.max(1, enBuyuk).toDouble();

    double x(int i) => boyut.width * (i / (n - 1));
    double y(int v) => alt - (alt - ust) * (v / aralik);

    // Taban çizgisi: eğrinin nereye göre yükseldiği görünsün.
    tuval.drawLine(
      Offset(0, alt),
      Offset(boyut.width, alt),
      Paint()
        ..color = taban
        ..strokeWidth = 1,
    );

    final yol = Path()..moveTo(x(0), y(seri[0]));
    for (var i = 1; i < n; i++) {
      yol.lineTo(x(i), y(seri[i]));
    }
    final dolgu = Path.from(yol)
      ..lineTo(x(n - 1), alt)
      ..lineTo(x(0), alt)
      ..close();
    tuval.drawPath(dolgu, Paint()..color = cizgi.withValues(alpha: 0.12));
    tuval.drawPath(
      yol,
      Paint()
        ..color = cizgi
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklineCizer eski) =>
      eski.seri != seri || eski.cizgi != cizgi || eski.taban != taban;
}

/// İkincil üçlünün tek hücresi. Sayı kalın, etiket altında küçük.
class _Sayac extends StatelessWidget {
  final IconData ikon;
  final String etiket;

  /// BİÇİMLENMİŞ değer ("1.234", "%7,8" ya da ölçülemediğinde "—").
  final String deger;

  /// Pencerenin tamamı ölçülemediyse true: sayının yanına kum saati konur.
  /// RENKLE DEĞİL İKONLA işaretlenir — renk körlüğünde de görünsün.
  final bool eksik;

  /// Değer yerine tire yazıldığında sebebi (yalnız ekran okuyucuya).
  final String? ipucu;

  const _Sayac({
    required this.ikon,
    required this.etiket,
    required this.deger,
    this.eksik = false,
    this.ipucu,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    // container: true — yoksa etiket üst düğüme karışır (bkz. [_Kahraman]).
    container: true,
    label: ipucu ?? '$etiket: $deger${eksik ? ', ${'eksik veri'.c}' : ''}',
    excludeSemantics: true,
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ikon, size: 15, color: DiziRenkler.sariMetin),
                if (eksik) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.hourglass_bottom,
                    size: 13,
                    color: DiziRenkler.metin38,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 5),
            // FittedBox: 7 haneli bir sayı dar sütunda taşmasın, küçülsün.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                deger,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: DiziRenkler.metin,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              etiket,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: DiziRenkler.metin54, fontSize: 11.5),
            ),
          ],
        ),
      ),
    ),
  );
}

/// TÜM ZAMANLAR ÇIPASI — ekranın en altında, tek blok, iki satır yazı.
///
/// NEDEN EN ALTTA: bu sayı gün geçtikçe değişmeyen bir referanstır, manşet
/// değil. Eskiden ekranın TEPESİNDEydi ve "Tümü" seçilince kahraman sayıyla
/// birebir aynı rakamı ikinci kez basıyordu; şimdi hem yerini buldu hem
/// tekrar öldü ("Tümü" seçiliyken [goruntulenme] null gelir ve yazılmaz).
class _Cipa extends StatelessWidget {
  final int gonderi;

  /// null → "Tümü" seçili; görüntülenme kahraman sayıda zaten yazıyor.
  final int? goruntulenme;

  const _Cipa({required this.gonderi, required this.goruntulenme});

  @override
  Widget build(BuildContext context) {
    final g = goruntulenme;
    final ozet = g == null
        ? '{} gönderi'.cf([sayiBicimle(gonderi)])
        : '{} gönderi · {} görüntülenme'.cf([
            sayiBicimle(gonderi),
            sayiBicimle(g),
          ]);
    return Semantics(
      // container: true — yoksa etiket üst düğüme karışır (bkz. [_Kahraman]).
      container: true,
      label: '${'Tüm zamanlar'.c}: $ozet',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.all_inclusive, size: 15, color: DiziRenkler.metin38),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tüm zamanlar'.c,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: DiziRenkler.metin54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ozet,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: DiziRenkler.metin70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pencere seçici: BEŞ SEÇENEK TEK SATIRDA.
///
/// NEDEN ROW, NEDEN WRAP DEĞİL (13 Ağu 2026 — kullanıcı: "saçma yer kaplıyor"):
/// Eskiden çipler bir `Wrap` içindeydi ve her çip `Container(alignment: ...)`
/// kullanıyordu. `alignment` verilen bir Container child'ını `Align`a sarar;
/// `Align` da GEVŞEK kısıtta ELİNDEKİ TÜM GENİŞLİĞİ kaplar. Yani her çip
/// satırın tamamını yiyordu ve beş çip ALT ALTA beş satır oluyordu: 360 dp'de
/// 252 dp yükseklik (5×44 + 4×8). İskeletin bu bloğa 44 dp ayırmış olması
/// (bkz. [_Iskelet]) tek satırın en baştaki niyet olduğunu gösteriyor —
/// bu bir tasarım tercihi değil, sessiz bir yerleşim hatasıydı.
///
/// Şimdi beş eşit segment tek `Row`da: blok 252 → 44 dp.
///
/// 14 AĞU 2026'da BLOK EKRANIN EN ÜSTÜNE TAŞINDI ve "Zaman kırılımı" başlığı
/// KALDIRILDI: seçici artık ilk şey olduğu için neyi yönettiği yerinden belli
/// (altındaki her şey), üstelik başlık 23 dp'lik bir vergi alıyordu.
///
/// ETİKET KISALTMASI: görünen yazı `'{} gün'` anahtarından ("30 gün",
/// "30 days", "30 Tg.", "30 pv") — bu anahtar 45 dilde ZATEN var (profil ve
/// yasaklı ekranları kullanıyor), yani yeni çeviri borcu YOK. "30g" gibi bir
/// kısaltma seçilmedi: gün birimi Türkçe'de "g", İngilizce'de "d", Fince'de
/// "pv", Japonca'da "日" — tek harfe indirgemek 45 dilin çoğunda anlamsız ya
/// da çevrilemez olurdu. Ekran okuyucu ise kısaltılmış yazıyı DEĞİL, tam
/// cümleyi ("Son 30 gün") duyar; kısalma yalnız GÖZE yapılan bir kısalmadır.
class _PencereSecici extends StatelessWidget {
  /// Seçili pencere (gün); 0 = tüm zamanlar.
  final int secili;
  final ValueChanged<int> onSec;

  const _PencereSecici({required this.secili, required this.onSec});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final g in const [30, 60, 90, 120, 0]) ...[
        if (g != 30) const SizedBox(width: 5),
        Expanded(
          child: _PencereSegmenti(
            gun: g,
            etiket: g == 0 ? 'Tümü'.c : '{} gün'.cf([g]),
            sesli: g == 0 ? 'Tümü'.c : 'Son {} gün'.cf([g]),
            secili: secili == g,
            onSec: () => onSec(g),
          ),
        ),
      ],
    ],
  );
}

/// Seçicinin tek segmenti.
///
/// DOKUNMA HEDEFİ 44 dp KALIYOR ama GÖRSEL yükseklik 34 dp: aradaki 10 dp
/// saydam dolgu. Böylece satır hafif görünürken parmak hedefi küçülmüyor.
///
/// SEÇİLİ DURUM RENKTEN BAŞKA İŞARET TAŞIR (erişilebilirlik): 2 px çerçeve
/// (seçilmemişte 1 px) + w800 yazı (seçilmemişte w500). Gri tonlamalı bir
/// ekranda ya da renk körlüğünde de hangisinin açık olduğu okunur.
class _PencereSegmenti extends StatelessWidget {
  final int gun;

  /// Gözle okunan KISA etiket ("30 gün").
  final String etiket;

  /// Ekran okuyucunun duyduğu TAM etiket ("Son 30 gün").
  final String sesli;
  final bool secili;
  final VoidCallback onSec;

  const _PencereSegmenti({
    required this.gun,
    required this.etiket,
    required this.sesli,
    required this.secili,
    required this.onSec,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: secili,
    label: sesli,
    excludeSemantics: true,
    child: InkWell(
      // Anahtar ÇEVİRİYE DEĞİL sayıya bağlı: dil değişince test/otomasyon
      // hedefi kaymasın ('pencere-0' = tümü).
      key: Key('pencere-$gun'),
      onTap: onSec,
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 44,
        child: Center(
          child: Container(
            height: 34,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: secili ? DiziRenkler.sari.withValues(alpha: 0.16) : null,
              border: Border.all(
                color: secili ? DiziRenkler.sari : DiziRenkler.metin12,
                width: secili ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(17),
            ),
            // FittedBox: en uzun çevirilerde (it "120 giorni", el
            // "120 μέρες") yazı taşmak yerine bir tık küçülür — segment
            // genişliği sabit kaldığı için satır ASLA ikiye çıkmaz.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                etiket,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: secili ? FontWeight.w800 : FontWeight.w500,
                  color: secili ? DiziRenkler.sariMetin : DiziRenkler.metin54,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// SIRALAMA SEÇİCİ — iki listeyi tek listeye indiren şey.
///
/// Eskiden ekranda "En çok görüntülenen" ve "En çok beğenilen" diye İKİ liste
/// alt alta duruyordu; ikisi de çoğu zaman AYNI gönderilerle doluydu ve ekranı
/// iki katına çıkarıyordu. Tek liste + ölçü seçimi aynı bilgiyi yarı yerde
/// verir, üstelik ÜÇÜNCÜ bir ölçüye yer açar: `yanit` ("en çok konuşulan").
///
/// Menü `PopupMenuButton` — Flutter'ın kendi menüsü klavye/ekran okuyucu
/// desteğini hazır getirir. Dokunma hedefi 44 dp (görünen hap 34 dp, md. 24'ün
/// pencere segmentleriyle aynı ölçü) ve seçili ölçü YAZIYLA görünür: kullanıcı
/// menüyü açmadan neye göre sıralandığını bilir.
class _SiralaSecici extends StatelessWidget {
  final String secili;
  final ValueChanged<String> onSec;

  const _SiralaSecici({required this.secili, required this.onSec});

  @override
  Widget build(BuildContext context) => Semantics(
    // container: true — yoksa etiket üst düğüme karışır (bkz. [_Kahraman]).
    container: true,
    button: true,
    label:
        '${'Sıralama'.c}: '
        '${(istatistikSiralamalari[secili] ?? '').c}',
    excludeSemantics: true,
    child: PopupMenuButton<String>(
      key: const Key('sirala-secici'),
      tooltip: 'Sıralama'.c,
      padding: EdgeInsets.zero,
      initialValue: secili,
      onSelected: onSec,
      itemBuilder: (_) => [
        for (final s in istatistikSiralamalari.entries)
          PopupMenuItem<String>(
            key: Key('sirala-${s.key}'),
            value: s.key,
            child: Text(s.value.c),
          ),
      ],
      child: SizedBox(
        height: 44,
        child: Center(
          child: Container(
            height: 34,
            constraints: const BoxConstraints(maxWidth: 150),
            padding: const EdgeInsets.only(left: 10, right: 4),
            decoration: BoxDecoration(
              border: Border.all(color: DiziRenkler.metin12),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    (istatistikSiralamalari[secili] ?? '').c,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: DiziRenkler.metin70,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  size: 20,
                  color: DiziRenkler.metin54,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Listenin satırı: poster + içerik adı + gönderi metni + SEÇİLİ ÖLÇÜ.
class _GonderiSatiri extends StatelessWidget {
  final Map<String, dynamic> gonderi;
  final Map<String, dynamic>? icerik;

  /// Hangi ölçü gösterilecek (`istatistikSiralamalari` anahtarı).
  final String sirala;

  const _GonderiSatiri({
    required this.gonderi,
    required this.icerik,
    required this.sirala,
  });

  @override
  Widget build(BuildContext context) {
    final poster = posterUrl(icerik?['poster'] as String?, boyut: 'w185');
    final spoiler = gonderi['spoiler'] == true;
    final metin = spoiler
        ? 'Spoiler içeren gönderi'.c
        : ((gonderi['metin'] as String?) ?? '').trim();
    final medya = gonderi['medya_sayi'] as int? ?? 0;
    final olcu = _siralamaOlcusu[sirala] ?? _siralamaOlcusu['goruntulenme']!;
    final sayi = gonderi[olcu.alan] as int? ?? 0;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        // Gönderinin kendisine gider: "hangisi tuttu" sorusunun devamı
        // "neden tuttu"dur ve o cevap gönderinin sayfasındadır.
        // `yanit` bayrağı ŞART (md. 15): bir YANIT `/gonderi/:id` ile tam ekran
        // Reels olarak çizilirse medyası olmadığı için dev puntolu tek yazıya
        // dönüyor. `ust_id` doluysa uygun ekran açılır.
        onTap: () => context.push(
          gonderiYolu('${gonderi['id']}', yanit: gonderi['ust_id'] != null),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (poster != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 34,
                    height: 50,
                    child: CachedNetworkImage(
                      imageUrl: poster,
                      httpHeaders: gorselBasliklari(poster),
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: DiziRenkler.kart),
                      errorWidget: (_, _, _) =>
                          Container(color: DiziRenkler.kart),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${icerik?['ad'] ?? '?'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: DiziRenkler.sariMetin,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      metin.isEmpty && medya > 0 ? 'Görsel gönderi'.c : metin,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: spoiler
                            ? DiziRenkler.metin38
                            : DiziRenkler.metin54,
                        fontSize: 12.5,
                        height: 1.35,
                        fontStyle: spoiler ? FontStyle.italic : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Ölçü sağda: göz gezdirirken sayılar tek sütunda alt alta gelir.
              Semantics(
                // container: true — yoksa etiket üst düğüme karışır (bkz. [_Kahraman]).
                container: true,
                label:
                    '${(istatistikSiralamalari[sirala] ?? '').c}: '
                    '${sayiBicimle(sayi)}',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      sayiBicimle(sayi),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: DiziRenkler.metin,
                      ),
                    ),
                    Icon(olcu.ikon, size: 13, color: DiziRenkler.metin38),
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

/// İlk yükleme iskeleti — boş ekran yerine yerleşimin şekli görünür (CLS yok).
/// Kutular gerçek yerleşimin sırasını izler: seçici (44), kahraman (110),
/// üçlü (74), liste başlığı (44), iki satır (70+70).
class _Iskelet extends StatelessWidget {
  const _Iskelet();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
    children: const [
      // `genislik` verilmezse IskeletKutu 105 px kalır — listede tek sütun
      // yerine ince bir şerit görünürdü.
      IskeletKutu(genislik: double.infinity, yukseklik: 44),
      SizedBox(height: 12),
      IskeletKutu(genislik: double.infinity, yukseklik: 110),
      SizedBox(height: 8),
      IskeletKutu(genislik: double.infinity, yukseklik: 74),
      SizedBox(height: 18),
      IskeletKutu(genislik: double.infinity, yukseklik: 44),
      SizedBox(height: 10),
      IskeletKutu(genislik: double.infinity, yukseklik: 70),
      SizedBox(height: 8),
      IskeletKutu(genislik: double.infinity, yukseklik: 70),
    ],
  );
}
