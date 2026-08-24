import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
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

class IzlemCarki extends StatefulWidget {
  /// İzleyeceğim listesinin öğeleri; her biri en az `tur` ve `tmdb_id` taşır
  /// (kitaplık ekranıyla aynı sözleşme).
  final List<Map<String, dynamic>> ogeler;

  /// Testte seed'lenebilir rastgelelik; üründe null → [math.Random].
  final math.Random? rastgele;

  const IzlemCarki({super.key, required this.ogeler, this.rastgele});

  @override
  State<IzlemCarki> createState() => _IzlemCarkiState();
}

class _IzlemCarkiState extends State<IzlemCarki>
    with SingleTickerProviderStateMixin {
  late final math.Random _rastgele = widget.rastgele ?? math.Random();
  late final AnimationController _donus = AnimationController(vsync: this);

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
    _donus.dispose();
    super.dispose();
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

    // İbre üstte (-π/2). Çark θ kadar dönünce ibrenin gösterdiği yerel açı
    // (-π/2 - θ)'dır; i. dilimin ORTASINA denk gelmesi için:
    //   -π/2 - θ ≡ i·dilim + dilim/2  (mod 2π)
    final hedefYerel = i * dilim + dilim / 2;
    final kisitli = MediaQuery.of(context).disableAnimations;
    // 3-4 tur: eski 4-6 tur / 3,6 sn kurgusunda kalkış anındaki hız
    // bulanıklığa dönüşüyordu (24 Ağu 2026 bildirimi: "çark çok hızlı
    // dönüyor"). Daha az tur + daha uzun süre = aynı tören, okunur hız.
    final tamTur = kisitli ? 1 : 3 + _rastgele.nextInt(2);
    final mevcutKalan = _aci % (2 * math.pi);
    var delta = (-math.pi / 2 - hedefYerel - mevcutKalan) % (2 * math.pi);
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
                      onTap: _cevir,
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
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              key: const Key('cark-cevir'),
              style: FilledButton.styleFrom(
                backgroundColor: DiziRenkler.sari,
                foregroundColor: Colors.black,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              onPressed: _donuyor || liste.isEmpty ? null : _cevir,
              icon: const Icon(Icons.refresh),
              label: Text('Çarkı çevir'.c),
            ),
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
        // -π/2: 0. dilim ibreden (üstten) başlar — [_cevir] hesabıyla aynı.
        -math.pi / 2 + i * dilim,
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
        final a = -math.pi / 2 + i * dilim;
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

    // Adlar (yalnız okunacak kadar az dilim varsa)
    if (n <= 16) {
      for (var i = 0; i < n; i++) {
        final a = -math.pi / 2 + (i + 0.5) * dilim;
        final metin = TextPainter(
          text: TextSpan(
            text: adlar[i].length > 14
                ? '${adlar[i].substring(0, 13)}…'
                : adlar[i],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: yaricap - 88);
        canvas.save();
        canvas.translate(merkez.dx, merkez.dy);
        canvas.rotate(a);
        metin.paint(canvas, Offset(72, -metin.height / 2));
        canvas.restore();
      }
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
