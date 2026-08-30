import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../cark_efekti.dart';
import '../ceviri.dart';
import '../icerik_deposu.dart';
import '../tema.dart';
import 'detay.dart' show butceAlt, butceMetni, icerikButcesi;

/// "NE İZLESEM ÇARKI" (23 Ağu 2026 isteği, birebir): "İzleyeceğim yazısının
/// yanında çark olsun, çarka tıklayınca o listedeki tüm diziler o çarkta
/// bulunsun ve kullanıcı çevirebilsin; karışık / dizi / film süzgeciyle.
/// Gelen içeriğin posterini, puanını, konusunu, bütçesini ver; tıklayınca
/// profiline gitsin."
///
/// VERİ İSTEMCİDE: çark, İzleyeceğim listesinin ZATEN çekilmiş öğeleriyle
/// dolar (yeni uç yok). Ad/poster kart bilgisi [IcerikDeposu] partisiyle
/// gelir (~4 KB); konu + bütçe içeren TAM detay (`/tmdb/{tur}/{id}`, ~61 KB)
/// yalnız ÇARK DURDUKTAN SONRA, tek içerik için çekilir — çark dönerken ağ
/// isteği atılmaz.
///
/// SEÇİM ANİMASYONDAN ÖNCE yapılır: `rastgele.nextInt(n)` sonucu belli olur,
/// varış açısı ona göre hesaplanır. Böylece animasyon süs, seçim tek satırlık
/// düz rastgeleliktir ve testte [rastgele] seed'lenerek sonuç kilitlenebilir.
///
/// ERİŞİLEBİLİRLİK: `MediaQuery.disableAnimations` açıkken dönüş 400 ms'e ve
/// tek tura iner (ui-ux-pro-max "reduced motion" kuralı) — sonuç aynı.
Future<void> izlemCarkiniAc(
  BuildContext context,
  List<Map<String, dynamic>> ogeler, {
  math.Random? rastgele,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: DiziRenkler.koyuGri,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.94,
      child: IzlemCarki(ogeler: ogeler, rastgele: rastgele),
    ),
  );
}

/// ---------------------------------------------------------------------------
/// ÇARK GEOMETRİSİ — TEK KAYNAK
///
/// HANGİ HATAYI ÇÖZÜYOR (30 Ağu 2026, kullanıcı: *"çarkı çevirdiğimde çarkta
/// gösterilen ve çıkan yapım aynı olmuyor"*):
/// Boyacı ile mantık İKİ FARKLI konvansiyon kullanıyordu.
///   · [_CarkBoyaci] sıfırıncı dilimi **-π/2'den** (ibrenin durduğu üst
///     noktadan) başlatıyor: dilim i, `-π/2 + i·dilim` açısından başlar.
///   · `_ibreDilimi` ve `_cevir` ise dilimlerin **0'dan** (saat 3 yönünden)
///     başladığını varsayan bir formül kullanıyordu.
/// Aradaki fark tam bir ÇEYREK TUR, yani `n/4` dilim. Çark, seçilen yapımın
/// çeyrek tur ötesinde duruyordu; sonuç kartı doğru yapımı gösteriyordu ama
/// ibrenin altındaki dilimde başka bir ad yazıyordu. Mevcut testler yalnız
/// SONUCU denetlediği için (o zaten animasyondan önce seçiliyor) hata
/// görünmüyordu.
///
/// Artık üç taraf da (boyacı, ibre okuması, hedef açı) aşağıdaki iki saf
/// işlevden besleniyor. Bunlar test edilebilir ve birbirinin TERSİ olmak
/// zorunda — `izlem_carki_geometri_test.dart` bunu her (n, i) için sınıyor.
/// ---------------------------------------------------------------------------

/// Sıfırıncı dilimin BAŞLADIĞI yerel açı = ibrenin durduğu yön (üst).
const double carkBaslangic = -math.pi / 2;

/// [aci] kadar dönmüş çarkta ibrenin ALTINDAKİ dilimin indeksi.
///
/// Çark `Transform.rotate(angle: aci)` ile döndürülüyor: yerel açı α olan bir
/// nokta ekranda α + aci'de görünür. İbre ekranda [carkBaslangic] yönünde
/// sabit durduğu için gösterdiği YEREL açı `carkBaslangic - aci`dir; sıfırıncı
/// dilimin başlangıcına göre uzaklığı da sadece `-aci` olur.
@visibleForTesting
int carkIbreDilimi(double aci, int adet) {
  if (adet <= 0) return 0;
  final dilim = 2 * math.pi / adet;
  var uzaklik = (-aci) % (2 * math.pi);
  if (uzaklik < 0) uzaklik += 2 * math.pi;
  return (uzaklik / dilim).floor() % adet;
}

/// [i]. dilimin ORTASI ibrenin altına gelsin diye çarkın durması gereken açı,
/// `[0, 2π)` aralığında. Tam turları çağıran ekler.
///
/// Türetme: dilim i'nin ortası yerel `carkBaslangic + (i+0.5)·dilim`; ibrenin
/// gösterdiği yerel açı `carkBaslangic - aci`. İkisini eşitleyince
/// `aci ≡ -(i+0.5)·dilim (mod 2π)`.
@visibleForTesting
double carkDilimAcisi(int i, int adet) {
  if (adet <= 0) return 0;
  final dilim = 2 * math.pi / adet;
  var aci = (-(i + 0.5) * dilim) % (2 * math.pi);
  if (aci < 0) aci += 2 * math.pi;
  return aci;
}

class IzlemCarki extends StatefulWidget {
  /// İzleyeceğim listesinin öğeleri; her biri en az `tur` ve `tmdb_id` taşır
  /// (kitaplık ekranıyla aynı sözleşme).
  final List<Map<String, dynamic>> ogeler;

  /// Testte seed'lenebilir rastgelelik; üründe null → [math.Random].
  final math.Random? rastgele;

  /// Testte ses/titreşim yerine sayaç geçilir; üründe null → cihaz efekti.
  final CarkEfekti? efekt;

  const IzlemCarki({
    super.key,
    required this.ogeler,
    this.rastgele,
    this.efekt,
  });

  @override
  State<IzlemCarki> createState() => _IzlemCarkiState();
}

class _IzlemCarkiState extends State<IzlemCarki>
    with SingleTickerProviderStateMixin {
  late final math.Random _rastgele = widget.rastgele ?? math.Random();
  late final AnimationController _donus = AnimationController(vsync: this);

  /// Ses + titreşim. Testte [SessizCarkEfekti] geçilir.
  late final CarkEfekti _efekt = widget.efekt ?? CihazCarkEfekti();

  /// İbrenin en son hangi dilimde olduğu — DEĞİŞTİĞİ an tık çalar.
  /// `null` = henüz ölçülmedi (ilk karede tık çalmasın).
  int? _sonDilim;

  /// Elle çevirirken parmağın çark merkezine göre son açısı.
  double? _tutusAcisi;

  /// Elle çevirme sırasında biriken açısal hız (rad/sn) — bırakınca savurur.
  double _elHiz = 0;

  /// 'hepsi' | 'tv' | 'movie'
  String _suzgec = 'hepsi';

  /// 'tur:id' → kart bilgisi (ad, poster, puan). Çark adları buradan.
  final Map<String, Map<String, dynamic>> _kartlar = {};
  bool _kartlarYukleniyor = true;

  /// Dönüşün vardığı açı (radyan, birikimli — her çevirişte büyür).
  double _aci = 0;
  bool _donuyor = false;

  /// Duran çarkın seçtiği öğe; null iken çark görünümdedir.
  Map<String, dynamic>? _sonuc;

  /// Seçilen içeriğin tam detayı (konu + bütçe); gelene dek iskelet.
  Map<String, dynamic>? _detay;
  bool _detayHatasi = false;

  @override
  void initState() {
    super.initState();
    _donus.addListener(() => setState(() {}));
    _kartlariYukle();
  }

  @override
  void dispose() {
    _efekt.kapat();
    _donus.dispose();
    super.dispose();
  }

  /// İbrenin şu an gösterdiği dilim indeksi (bkz. [carkIbreDilimi]).
  int _ibreDilimi(int adet) => carkIbreDilimi(_aci, adet);

  /// --- TESTE AÇIK ÜÇLÜ ---
  /// "Çarkta gösterilen ile çıkan yapım aynı mı?" sorusu ancak bu üçü bir
  /// arada okunarak yanıtlanabiliyor: duran açı, o an çizilen liste ve
  /// seçilen öğe. Üçü de yalnız okunur; testler dışında kullanılmaz.
  @visibleForTesting
  double get aci => _aci;

  @visibleForTesting
  List<Map<String, dynamic>> get gorunenListe => _suzulmus;

  @visibleForTesting
  Map<String, dynamic>? get sonucOge => _sonuc;

  /// Dilim değiştiyse tık çalar. Çark yavaşladıkça dilim değişimi de
  /// seyrekleşir — gerçek çarkın "tık… tık…  tık" ritmi buradan gelir,
  /// ayrıca döngüsel bir ses dosyası gerekmez.
  void _tikDenetle(int adet) {
    final d = _ibreDilimi(adet);
    if (_sonDilim != null && _sonDilim != d) _efekt.tik();
    _sonDilim = d;
  }

  String _anahtar(Map<String, dynamic> o) => '${o['tur']}:${o['tmdb_id']}';

  Future<void> _kartlariYukle() async {
    await Future.wait([
      for (final o in widget.ogeler)
        IcerikDeposu.getir(
          o['tur'] as String,
          (o['tmdb_id'] as num).toInt(),
        ).then((d) {
          if (d != null) _kartlar[_anahtar(o)] = d;
        }),
    ]);
    if (mounted) setState(() => _kartlarYukleniyor = false);
  }

  List<Map<String, dynamic>> get _suzulmus => [
    for (final o in widget.ogeler)
      if (_suzgec == 'hepsi' || o['tur'] == _suzgec) o,
  ];

  String _ad(Map<String, dynamic> o) =>
      (_kartlar[_anahtar(o)]?['name'] ?? _kartlar[_anahtar(o)]?['title'])
          as String? ??
      '…';

  void _cevir() {
    final liste = _suzulmus;
    if (_donuyor || liste.isEmpty) return;
    final secilen = liste[_rastgele.nextInt(liste.length)];
    final i = liste.indexOf(secilen);
    final dilim = 2 * math.pi / liste.length;

    // Hedef açı TEK KAYNAKTAN gelir ([carkDilimAcisi]) — boyacının dilim
    // düzeniyle birebir aynı hesap. Eskiden burada yerel bir formül vardı ve
    // boyacıdan çeyrek tur kayıyordu (bkz. geometri başlığı).
    final hedefAci = carkDilimAcisi(i, liste.length);
    final kisitli = MediaQuery.of(context).disableAnimations;
    // 3-4 tur: eski 4-6 tur / 3,6 sn kurgusunda kalkış anındaki hız
    // bulanıklığa dönüşüyordu (24 Ağu 2026 bildirimi: "çark çok hızlı
    // dönüyor"). Daha az tur + daha uzun süre = aynı tören, okunur hız.
    final tamTur = kisitli ? 1 : 3 + _rastgele.nextInt(2);
    var mevcutKalan = _aci % (2 * math.pi);
    if (mevcutKalan < 0) mevcutKalan += 2 * math.pi;
    var delta = (hedefAci - mevcutKalan) % (2 * math.pi);
    if (delta < 0) delta += 2 * math.pi;
    final hedef = _aci + tamTur * 2 * math.pi + delta;
    // Son "tık": çark hedefi dilimin üçte biri kadar İLERİ geçip kısa bir
    // yaylanmayla geri oturur — gerçek çarkın ibreden dönen son dişi.
    // Kısıtlı animasyonda (reduced motion) taşma yok, sonuç aynı.
    final tasma = kisitli ? 0.0 : dilim / 3;

    setState(() {
      _donuyor = true;
      _sonuc = null;
      _detay = null;
      _detayHatasi = false;
    });
    _donus.value = 0;
    final baslangic = _aci;
    final ilkHedef = hedef + tasma;
    final animasyon = CurvedAnimation(
      parent: _donus,
      // easeInOutCubicEmphasized: YUMUŞAK kalkış, ortada tepe hız, çok uzun
      // ve kararlı yavaşlama. easeOutQuart sıfırıncı milisaniyede tepe hızla
      // fırlıyordu; sürecin "hızlanıyor → süzülüyor → duruyor" diye
      // okunması bu eğriyle geldi.
      curve: Curves.easeInOutCubicEmphasized,
    );
    void dinle() {
      _aci = baslangic + (ilkHedef - baslangic) * animasyon.value;
      _tikDenetle(liste.length);
    }

    _donus.addListener(dinle);
    _donus
        .animateTo(1, duration: Duration(milliseconds: kisitli ? 400 : 5200))
        .whenComplete(() async {
          _donus.removeListener(dinle);
          if (!mounted) return;
          if (tasma > 0) {
            _donus.value = 0;
            final geri = CurvedAnimation(parent: _donus, curve: Curves.easeOut);
            void geriDinle() {
              _aci = ilkHedef - tasma * geri.value;
            }

            _donus.addListener(geriDinle);
            await _donus.animateTo(
              1,
              duration: const Duration(milliseconds: 320),
            );
            _donus.removeListener(geriDinle);
            if (!mounted) return;
          }
          setState(() {
            _aci = hedef;
            _donuyor = false;
            _sonuc = secilen;
          });
          _efekt.durdu();
          _detayGetir(secilen);
        });
  }

  /// İki sürükleme olayı arasındaki süre (hız için).
  Duration? _oncekiDamga;
  Duration _dt(Duration damga) {
    final onceki = _oncekiDamga;
    _oncekiDamga = damga;
    return onceki == null ? const Duration(milliseconds: 16) : damga - onceki;
  }

  /// Parmağın çark merkezine göre açısı.
  double _parmakAcisi(Offset yerel, Size kutu) =>
      math.atan2(yerel.dy - kutu.height / 2, yerel.dx - kutu.width / 2);

  /// ELLE ÇEVİRME (29 Ağu 2026, kullanıcı: "elle de çevrilebilmeli, çevir
  /// butonu saçma"). Parmak çarkı doğrudan döndürür; bırakınca son hızla
  /// savrulur ve sürtünmeyle bir dilimde durur.
  void _elBasla(Offset yerel, Size kutu) {
    if (_donuyor) return;
    _donus.stop();
    _tutusAcisi = _parmakAcisi(yerel, kutu);
    _elHiz = 0;
  }

  void _elSurukle(Offset yerel, Size kutu, Duration? dt) {
    if (_donuyor || _tutusAcisi == null) return;
    final yeni = _parmakAcisi(yerel, kutu);
    // Fark ±π'ye sarmalanır: -π/π sınırından geçerken çark ters dönmesin.
    var fark = yeni - _tutusAcisi!;
    if (fark > math.pi) fark -= 2 * math.pi;
    if (fark < -math.pi) fark += 2 * math.pi;
    _tutusAcisi = yeni;
    final sn = (dt?.inMicroseconds ?? 16000) / 1e6;
    // Anlık hız yerine yumuşatılmış hız: tek karelik sıçrama savurmayı
    // saçma biçimde hızlandırıyordu.
    if (sn > 0) _elHiz = _elHiz * 0.6 + (fark / sn) * 0.4;
    setState(() => _aci += fark);
    _tikDenetle(_suzulmus.length);
  }

  /// Parmak kalktı: hız eşiğin altındaysa çark olduğu yerde kalır (kullanıcı
  /// sadece hizalıyordur), üstündeyse savrulup bir dilimde durur.
  void _elBirak() {
    _tutusAcisi = null;
    final liste = _suzulmus;
    if (_donuyor || liste.isEmpty) return;
    final hiz = _elHiz;
    _elHiz = 0;
    if (hiz.abs() < 1.2) return; // yavaş çevirme: sonuç seçme, serbest bırak

    // Sürtünme modeli: v(t) = v0·e^(-kt) → toplam yol v0/k.
    const k = 1.9;
    final yol = hiz / k;
    // Serbest yolun bittiği yere EN YAKIN dilim ortasına oturt: sonuç
    // rastgele DEĞİL, kullanıcının kendi savurmasının sonucu.
    final ham = _aci + yol;
    // Savurmanın bittiği yerde ibrenin ÜSTÜNDE duracağı dilim. Eskiden
    // `.round()` ile en yakın dilim SINIRINA yuvarlanıyordu; dilimin ikinci
    // yarısında duran çark komşu dilime atlıyordu. `floor` (yani
    // [carkIbreDilimi]) gerçekten durulan dilimi verir ve o dilimin ortası
    // zaten en yakın merkezdir.
    final i = carkIbreDilimi(ham, liste.length);
    final hedefAci = carkDilimAcisi(i, liste.length);
    var mevcutKalan = _aci % (2 * math.pi);
    if (mevcutKalan < 0) mevcutKalan += 2 * math.pi;
    var delta = (hedefAci - mevcutKalan) % (2 * math.pi);
    if (delta < 0) delta += 2 * math.pi;
    // Savurma yönü korunur: geriye savurduysa tur sayısını negatiften kur.
    final tur = (yol.abs() / (2 * math.pi)).floor();
    final hedef =
        _aci +
        (hiz > 0 ? 1 : -1) * tur * 2 * math.pi +
        (hiz > 0 ? delta : delta - 2 * math.pi);
    final secilen = liste[i];

    setState(() {
      _donuyor = true;
      _sonuc = null;
      _detay = null;
      _detayHatasi = false;
    });
    final baslangic = _aci;
    _donus.value = 0;
    final egri = CurvedAnimation(parent: _donus, curve: Curves.easeOutCubic);
    void dinle() {
      _aci = baslangic + (hedef - baslangic) * egri.value;
      _tikDenetle(liste.length);
    }

    _donus.addListener(dinle);
    final ms = (900 + (hiz.abs() * 260)).clamp(900, 4200).toInt();
    _donus.animateTo(1, duration: Duration(milliseconds: ms)).whenComplete(() {
      _donus.removeListener(dinle);
      if (!mounted) return;
      setState(() {
        _aci = hedef;
        _donuyor = false;
        _sonuc = secilen;
      });
      _efekt.durdu();
      _detayGetir(secilen);
    });
  }

  Future<void> _detayGetir(Map<String, dynamic> o) async {
    try {
      final d = await Api.get(
        '/tmdb/${o['tur']}/${(o['tmdb_id'] as num).toInt()}',
      );
      if (!mounted || _sonuc != o) return;
      setState(() => _detay = d);
    } catch (_) {
      if (!mounted || _sonuc != o) return;
      // Konu/bütçe süstür; kart bilgisiyle (ad+poster+puan) yine gösterilir.
      setState(() => _detayHatasi = true);
    }
  }

  void _suzgecSec(String yeni) {
    if (_donuyor) return;
    final bosMu =
        yeni != 'hepsi' && !widget.ogeler.any((o) => o['tur'] == yeni);
    if (bosMu) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Bu türde içerik yok'.c)));
      return;
    }
    setState(() {
      _suzgec = yeni;
      _sonuc = null;
      _detay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final liste = _suzulmus;
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: DiziRenkler.metin24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
          child: Row(
            children: [
              Icon(Icons.attractions, color: DiziRenkler.sariMetin),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ne izlesem?'.c,
                  style: TextStyle(
                    color: DiziRenkler.metin,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Kapat'.c,
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, color: DiziRenkler.metin70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        _suzgecSatiri(),
        const SizedBox(height: 8),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _sonuc != null
                ? _SonucKarti(
                    key: ValueKey('sonuc-${_anahtar(_sonuc!)}'),
                    oge: _sonuc!,
                    kart: _kartlar[_anahtar(_sonuc!)],
                    detay: _detay,
                    detayHatasi: _detayHatasi,
                    tekrarCevir: _cevir,
                  )
                : _carkGorunumu(liste),
          ),
        ),
      ],
    );
  }

  Widget _suzgecSatiri() {
    Widget parca(String deger, String etiket) {
      final secili = _suzgec == deger;
      final bos =
          deger != 'hepsi' && !widget.ogeler.any((o) => o['tur'] == deger);
      return Opacity(
        // Boş tür SOLUK ama dokunulabilir kalır: dokununca SnackBar sebebini
        // söyler (sessizce tepkisiz bir düğme bırakmak yasak — kural 3).
        opacity: bos ? 0.4 : 1,
        child: ChoiceChip(
          key: Key('cark-suzgec-$deger'),
          label: Text(etiket),
          selected: secili,
          onSelected: (_) => _suzgecSec(deger),
          selectedColor: DiziRenkler.sari,
          labelStyle: TextStyle(
            color: secili ? Colors.black : DiziRenkler.metin,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      children: [
        parca('hepsi', 'Karışık'.c),
        parca('tv', 'Dizi'.c),
        parca('movie', 'Film'.c),
      ],
    );
  }

  Widget _carkGorunumu(List<Map<String, dynamic>> liste) {
    if (_kartlarYukleniyor) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      key: const ValueKey('cark'),
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: LayoutBuilder(
              builder: (context, kisit) {
                final kenar = math.min(kisit.maxWidth, kisit.maxHeight);
                return Center(
                  child: SizedBox(
                    width: kenar,
                    height: kenar,
                    child: GestureDetector(
                      key: const Key('izlem-carki-cark'),
                      // DOKUN = otomatik çevir (eski davranış korunur),
                      // SÜRÜKLE = elle çevir. "Çarkı çevir" düğmesi kaldırıldı
                      // (29 Ağu 2026, kullanıcı: "elle de çevrilebilmeli,
                      // çevir butonu saçma") — çarkın kendisi zaten dokunma
                      // hedefi ve 44 dp'nin kat kat üstünde.
                      onTap: _cevir,
                      onPanStart: (d) =>
                          _elBasla(d.localPosition, Size.square(kenar)),
                      onPanUpdate: (d) => _elSurukle(
                        d.localPosition,
                        Size.square(kenar),
                        d.sourceTimeStamp == null
                            ? null
                            : _dt(d.sourceTimeStamp!),
                      ),
                      onPanEnd: (_) => _elBirak(),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.rotate(
                            angle: _aci,
                            child: CustomPaint(
                              size: Size.square(kenar),
                              painter: _CarkBoyaci(
                                adlar: [for (final o in liste) _ad(o)],
                              ),
                            ),
                          ),
                          // Orta göbek: içerik sayısı
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: DiziRenkler.markaKoyu,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: DiziRenkler.sari,
                                width: 3,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${liste.length}',
                              style: const TextStyle(
                                color: DiziRenkler.sari,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          // İbre (üstte, sabit)
                          Align(
                            alignment: Alignment.topCenter,
                            child: CustomPaint(
                              size: const Size(30, 26),
                              painter: _IbreBoyaci(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // DÜĞME YERİNE İPUCU: çarkın kendisi çevriliyor, ayrı bir düğme
        // gereksizdi. Ama keşfedilebilirlik kaybolmasın diye ne yapılacağı
        // yazıyor — dokunma hedefi ≥44 dp kuralını çark zaten fazlasıyla
        // karşılıyor (ekran kenarı kadar).
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
          child: Text(
            'Çarkı çevirmek için sürükle veya dokun'.c,
            key: const Key('cark-ipucu'),
            textAlign: TextAlign.center,
            style: TextStyle(color: DiziRenkler.metin54, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

/// Duran çarkın seçtiği içerik: büyük poster, ad, yıl, puan, konu ve (yalnız
/// filmde, biliniyorsa) bütçe. Karta dokunmak içeriğin sayfasını açar.
class _SonucKarti extends StatelessWidget {
  final Map<String, dynamic> oge;
  final Map<String, dynamic>? kart;
  final Map<String, dynamic>? detay;
  final bool detayHatasi;
  final VoidCallback tekrarCevir;

  const _SonucKarti({
    super.key,
    required this.oge,
    required this.kart,
    required this.detay,
    required this.detayHatasi,
    required this.tekrarCevir,
  });

  @override
  Widget build(BuildContext context) {
    final tur = oge['tur'] as String;
    final id = (oge['tmdb_id'] as num).toInt();
    final ad =
        (detay?['name'] ??
                detay?['title'] ??
                kart?['name'] ??
                kart?['title'] ??
                '?')
            .toString();
    final posterYolu = posterUrl(
      (detay?['poster_path'] ?? kart?['poster_path']) as String?,
      boyut: 'w342',
    );
    final puan =
        ((detay?['vote_average'] ?? kart?['vote_average']) as num?)
            ?.toDouble() ??
        0;
    final tarih =
        (detay?['first_air_date'] ?? detay?['release_date']) as String?;
    final yil = (tarih != null && tarih.length >= 4)
        ? tarih.substring(0, 4)
        : null;
    final konu = detay?['overview'] as String?;
    // Bütçe YALNIZ filmde aranır; TMDB dizi gövdesinde alan hiç yok.
    // 0 = "bilinmiyor" → satır hiç çizilmez (detay.dart'taki eşik disiplini).
    final butce = tur == 'movie' && detay != null
        ? icerikButcesi(detay!)
        : null;

    return SingleChildScrollView(
      key: const ValueKey('cark-sonuc'),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          InkWell(
            key: const Key('cark-sonuc-kart'),
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              // Önce sayfa kapanır, sonra kabuk İÇİNDE içerik sayfası açılır
              // (alt gezinme çubuğu kaybolmaz — mevcut /icerik kalıbı).
              final yonlendirici = GoRouter.of(context);
              Navigator.of(context).pop();
              yonlendirici.push('/icerik/$tur/$id');
            },
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 200,
                    child: AspectRatio(
                      aspectRatio: 2 / 3,
                      child: posterYolu == null
                          ? Container(
                              color: DiziRenkler.kart,
                              child: Icon(
                                Icons.movie,
                                color: DiziRenkler.metin24,
                                size: 48,
                              ),
                            )
                          : Image.network(posterYolu, fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  ad,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: DiziRenkler.metin,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (yil != null) ...[
                      Text(yil, style: TextStyle(color: DiziRenkler.metin70)),
                      const SizedBox(width: 10),
                    ],
                    if (puan > 0) ...[
                      const Icon(Icons.star, color: DiziRenkler.sari, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        puan.toStringAsFixed(1),
                        style: TextStyle(
                          color: DiziRenkler.metin,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                if (butce != null && butce >= butceAlt) ...[
                  const SizedBox(height: 8),
                  Container(
                    key: const Key('cark-butce'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: DiziRenkler.sari,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${'Bütçe'.c}: ${butceMetni(butce)}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                if (detay == null && !detayHatasi)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (konu != null && konu.isNotEmpty)
                  Text(
                    konu,
                    textAlign: TextAlign.center,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: DiziRenkler.metin70, height: 1.45),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              key: const Key('cark-tekrar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: DiziRenkler.sariMetin,
                side: BorderSide(color: DiziRenkler.sariMetin),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              onPressed: tekrarCevir,
              icon: const Icon(Icons.refresh),
              label: Text('Tekrar çevir'.c),
            ),
          ),
        ],
      ),
    );
  }
}

/// Çark dilimleri. Dilim sayısı 16'yı aşınca ad yazılmaz (okunmaz sliver'lara
/// metin sıkıştırmak yerine yalnız renkli dilimler + göbek sayısı kalır).
class _CarkBoyaci extends CustomPainter {
  final List<String> adlar;

  _CarkBoyaci({required this.adlar});

  @override
  void paint(Canvas canvas, Size size) {
    final merkez = size.center(Offset.zero);
    final yaricap = size.shortestSide / 2;
    final n = adlar.length;
    if (n == 0) return;
    final dilim = 2 * math.pi / n;

    // Dilim zeminleri: iki koyu ton + her üçte bir sarıya çalan vurgu.
    // (Ardışık iki dilim aynı renge düşmesin diye n % 3 == 0 değilse desen
    // kendini tekrar etmeden döner; n % 3 == 0'da da üçlü desen tutarlıdır.)
    const tonlar = [Color(0xFF232328), Color(0xFF2E2E34), Color(0xFF4A3F14)];
    final boya = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < n; i++) {
      boya.color = n == 1 ? tonlar[0] : tonlar[i % 3];
      canvas.drawArc(
        Rect.fromCircle(center: merkez, radius: yaricap - 4),
        // 0. dilim ibreden (üstten) başlar; sabit [carkBaslangic]'ta ve
        // ibre okuması ile hedef açı da ONU kullanıyor — tek kaynak.
        carkBaslangic + i * dilim,
        dilim,
        true,
        boya,
      );
    }

    // Dilim ayırıcıları
    final cizgi = Paint()
      ..color = const Color(0x33F5C518)
      ..strokeWidth = 1;
    if (n > 1) {
      for (var i = 0; i < n; i++) {
        final a = carkBaslangic + i * dilim;
        canvas.drawLine(
          merkez,
          merkez + Offset(math.cos(a), math.sin(a)) * (yaricap - 4),
          cizgi,
        );
      }
    }

    // Jant
    canvas.drawCircle(
      merkez,
      yaricap - 3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = DiziRenkler.sari,
    );

    // ADLAR HER ZAMAN ÇİZİLİR, dilim daraldıkça YAZI KÜÇÜLÜR.
    //
    // ⚠ ESKİ HÂLİ `if (n <= 16)` idi ve BU BİR HATAYDI (29 Ağu 2026,
    // kullanıcı: "liste büyünce yazılar gözükmüyor"). 17. yapımdan itibaren
    // adların hepsi birden KAYBOLUYORDU — küçülmüyor, hiç çizilmiyordu.
    // Kullanıcı "font küçülmeli" diye tarif etti; kök sebep font değil sert
    // kesmeydi, ikisi birden düzeltildi.
    //
    // ÖLÇÜ: yazı yüksekliği dilimin dış yaydaki kalınlığını AŞMAMALI, yoksa
    // komşu dilimlerin adları üst üste biner. Dış yay kalınlığı ≈ dilim
    // açısı × yazının oturduğu yarıçap. Alt sınır 7 dp: altında okunmuyor,
    // o noktadan sonra yazıyı kısaltmak daha iyi.
    final olcu = carkYaziOlcusu(n, yaricap);
    final iciYaricap = olcu.iciYaricap;
    final yaziAlani = olcu.yaziAlani;
    final punto = olcu.punto;
    final azamiHarf = olcu.azamiHarf;

    for (var i = 0; i < n; i++) {
      final a = carkBaslangic + (i + 0.5) * dilim;
      final ham = adlar[i];
      final metin = TextPainter(
        text: TextSpan(
          text: ham.length > azamiHarf
              ? '${ham.substring(0, azamiHarf - 1)}…'
              : ham,
          style: TextStyle(
            color: Colors.white,
            fontSize: punto,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: yaziAlani);
      canvas.save();
      canvas.translate(merkez.dx, merkez.dy);
      canvas.rotate(a);
      metin.paint(canvas, Offset(iciYaricap, -metin.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CarkBoyaci eski) => eski.adlar != adlar;
}

/// Üstteki sabit ibre (aşağı bakan sarı üçgen).
class _IbreBoyaci extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final yol = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(yol, Paint()..color = DiziRenkler.sari);
    canvas.drawPath(
      yol,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF0B0B0D),
    );
  }

  @override
  bool shouldRepaint(_IbreBoyaci eski) => false;
}

/// Çark dilimindeki adın ölçüleri — punto ve harf sınırı.
@visibleForTesting
class CarkYaziOlcusu {
  final double iciYaricap;
  final double yaziAlani;
  final double punto;
  final int azamiHarf;
  const CarkYaziOlcusu({
    required this.iciYaricap,
    required this.yaziAlani,
    required this.punto,
    required this.azamiHarf,
  });
}

/// [n] dilimli, [yaricap] yarıçaplı çarkta ad yazısının ölçüsü.
///
/// DIŞARI ALINDI ki "liste büyüdükçe yazı küçülüyor" SAYIYLA test edilebilsin;
/// boyacının içinde gömülü kalsaydı test ancak kaynak metnine bakabilirdi.
///
/// Ölçü: yazı yüksekliği dilimin dış yaydaki kalınlığını aşmamalı, yoksa
/// komşu adlar üst üste biner. Alt sınır 7 dp — altında okunmuyor, o
/// noktadan sonra küçültmek yerine adı kısaltmak gerekir.
@visibleForTesting
CarkYaziOlcusu carkYaziOlcusu(int n, double yaricap) {
  const iciYaricap = 72.0;
  final yaziAlani = yaricap - iciYaricap - 16;
  final dilim = 2 * math.pi / (n <= 0 ? 1 : n);
  final yayKalinligi = dilim * (iciYaricap + yaziAlani / 2);
  final punto = (yayKalinligi * 0.62).clamp(7.0, 13.0);
  return CarkYaziOlcusu(
    iciYaricap: iciYaricap,
    yaziAlani: yaziAlani,
    punto: punto,
    azamiHarf: (yaziAlani / (punto * 0.52)).floor().clamp(4, 22),
  );
}
