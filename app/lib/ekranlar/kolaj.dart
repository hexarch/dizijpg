import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../ceviri.dart';
import '../tema.dart';
import 'gorsel_duzenle.dart' show gorseliJpegKodla;
import 'ortak.dart';

/// KOLAJ — birden çok fotoğrafı tek kareye yerleştirir (kullanıcı isteği,
/// 5 Eyl 2026: "hâlâ fotoğraflardan kolaj oluşturma özelliği yok").
///
/// Instagram Layout / InShot kolaj mantığı: hazır ŞABLON (2-6 hücre), oran,
/// hücre arası boşluk, köşe yuvarlaması, zemin rengi. Her hücrede fotoğraf
/// iki parmakla yaklaştırılıp kaydırılır; iki hücreye sırayla dokunmak yer
/// değiştirir.
///
/// MİMARİ: kolaj ekranı `ImageProvider` alır, **JPEG baytı** döner —
/// `gorselDuzenle` ile aynı "bayt dön, vazgeçilirse null" sözleşmesi. Çıktı
/// inceleme ekranında (`medya_inceleme.dart`) kaynak fotoğrafların YERİNE tek
/// öğe olarak girer; oradan kaleme (editör) ve yükleme hattına aynen akar.
/// Sunucu yeni bir şey görmez: sıradan bir JPEG.
///
/// NEDEN `RepaintBoundary.toImage`, NEDEN PİKSEL BİRLEŞTİRME DEĞİL: Flutter
/// zaten tuvali çiziyor; aynı ağacı yüksek `pixelRatio` ile görüntüye almak
/// ekranda görülenle çıktının BİREBİR aynı olmasını garanti eder (yakınlaşma,
/// kaydırma, köşe, boşluk dâhil). Fotoğraflar `ResizeImage` ile ~1600 px'te
/// çözülür: 6 × 12 MP'yi belleğe almak düşük segment Android'de OOM demekti;
/// 2048 px'lik çıktıda hücre başına 1600 px fazlasıyla yeter.
///
/// JPEG KODLAMA ertelenmiş editör parçasındaki `ImageConverter` ile
/// (`gorseliJpegKodla`): ana pakete kodlayıcı taşımıyoruz. Parça inemezse
/// PNG'ye düşülür — büyük dosya, ama kolaj kaybolmaz.

/// Bir kolaja en çok kaç fotoğraf girer. 6'dan fazla hücre 390 dp'lik
/// telefonda pul boyutuna iniyor; Instagram Layout'un tavanı da 6.
const kolajAzamiFoto = 6;

/// Çıktının uzun kenarı (px). Görsel editörün 4096'lık tavanının yarısı:
/// kolajda her hücre zaten kaynağın bir parçası, 4096 yalnız dosyayı şişirir.
const kolajHedefKenar = 2048.0;

/// Kolaj şablonu: hücreler BİRİM KAREDE kesirli dikdörtgenler (0..1).
/// Oran değişince aynı kesirler yeni kutuya oturur — şablon orandan bağımsız.
class KolajSablonu {
  final String kimlik;
  final List<Rect> hucreler;

  const KolajSablonu(this.kimlik, this.hucreler);

  int get adet => hucreler.length;
}

/// Şablon seti — SIRA ARAYÜZ SIRASIDIR (her adet için en yaygın ilk).
const List<KolajSablonu> kolajSablonlari = [
  // 2
  KolajSablonu('2-yan', [
    Rect.fromLTWH(0, 0, .5, 1),
    Rect.fromLTWH(.5, 0, .5, 1),
  ]),
  KolajSablonu('2-ust', [
    Rect.fromLTWH(0, 0, 1, .5),
    Rect.fromLTWH(0, .5, 1, .5),
  ]),
  KolajSablonu('2-buyuk-sol', [
    Rect.fromLTWH(0, 0, 2 / 3, 1),
    Rect.fromLTWH(2 / 3, 0, 1 / 3, 1),
  ]),
  // 3
  KolajSablonu('3-sol-buyuk', [
    Rect.fromLTWH(0, 0, .5, 1),
    Rect.fromLTWH(.5, 0, .5, .5),
    Rect.fromLTWH(.5, .5, .5, .5),
  ]),
  KolajSablonu('3-ust-buyuk', [
    Rect.fromLTWH(0, 0, 1, .5),
    Rect.fromLTWH(0, .5, .5, .5),
    Rect.fromLTWH(.5, .5, .5, .5),
  ]),
  KolajSablonu('3-sutun', [
    Rect.fromLTWH(0, 0, 1 / 3, 1),
    Rect.fromLTWH(1 / 3, 0, 1 / 3, 1),
    Rect.fromLTWH(2 / 3, 0, 1 / 3, 1),
  ]),
  KolajSablonu('3-satir', [
    Rect.fromLTWH(0, 0, 1, 1 / 3),
    Rect.fromLTWH(0, 1 / 3, 1, 1 / 3),
    Rect.fromLTWH(0, 2 / 3, 1, 1 / 3),
  ]),
  // 4
  KolajSablonu('4-izgara', [
    Rect.fromLTWH(0, 0, .5, .5),
    Rect.fromLTWH(.5, 0, .5, .5),
    Rect.fromLTWH(0, .5, .5, .5),
    Rect.fromLTWH(.5, .5, .5, .5),
  ]),
  KolajSablonu('4-sol-buyuk', [
    Rect.fromLTWH(0, 0, 2 / 3, 1),
    Rect.fromLTWH(2 / 3, 0, 1 / 3, 1 / 3),
    Rect.fromLTWH(2 / 3, 1 / 3, 1 / 3, 1 / 3),
    Rect.fromLTWH(2 / 3, 2 / 3, 1 / 3, 1 / 3),
  ]),
  KolajSablonu('4-ust-buyuk', [
    Rect.fromLTWH(0, 0, 1, 2 / 3),
    Rect.fromLTWH(0, 2 / 3, 1 / 3, 1 / 3),
    Rect.fromLTWH(1 / 3, 2 / 3, 1 / 3, 1 / 3),
    Rect.fromLTWH(2 / 3, 2 / 3, 1 / 3, 1 / 3),
  ]),
  // 5
  KolajSablonu('5-ust2-alt3', [
    Rect.fromLTWH(0, 0, .5, .5),
    Rect.fromLTWH(.5, 0, .5, .5),
    Rect.fromLTWH(0, .5, 1 / 3, .5),
    Rect.fromLTWH(1 / 3, .5, 1 / 3, .5),
    Rect.fromLTWH(2 / 3, .5, 1 / 3, .5),
  ]),
  KolajSablonu('5-sol-buyuk', [
    Rect.fromLTWH(0, 0, .5, 1),
    Rect.fromLTWH(.5, 0, .25, .5),
    Rect.fromLTWH(.75, 0, .25, .5),
    Rect.fromLTWH(.5, .5, .25, .5),
    Rect.fromLTWH(.75, .5, .25, .5),
  ]),
  // 6
  KolajSablonu('6-izgara', [
    Rect.fromLTWH(0, 0, 1 / 3, .5),
    Rect.fromLTWH(1 / 3, 0, 1 / 3, .5),
    Rect.fromLTWH(2 / 3, 0, 1 / 3, .5),
    Rect.fromLTWH(0, .5, 1 / 3, .5),
    Rect.fromLTWH(1 / 3, .5, 1 / 3, .5),
    Rect.fromLTWH(2 / 3, .5, 1 / 3, .5),
  ]),
  KolajSablonu('6-dikey', [
    Rect.fromLTWH(0, 0, .5, 1 / 3),
    Rect.fromLTWH(.5, 0, .5, 1 / 3),
    Rect.fromLTWH(0, 1 / 3, .5, 1 / 3),
    Rect.fromLTWH(.5, 1 / 3, .5, 1 / 3),
    Rect.fromLTWH(0, 2 / 3, .5, 1 / 3),
    Rect.fromLTWH(.5, 2 / 3, .5, 1 / 3),
  ]),
];

/// [adet] fotoğraf için şablonlar (en az bir tane, 2..6 için garanti).
List<KolajSablonu> kolajSablonlariIcin(int adet) =>
    kolajSablonlari.where((s) => s.adet == adet).toList();

/// Kolaj oranları: etiket SAYI olduğu için çeviri gerektirmez.
const List<(String, double)> kolajOranlari = [
  ('1:1', 1),
  ('4:5', 4 / 5),
  ('3:4', 3 / 4),
  ('9:16', 9 / 16),
  ('16:9', 16 / 9),
];

/// Zemin renkleri. Siyah/beyaz/marka sarısı/koyu gri — dört seçenek yeter,
/// renk paleti açmak kolajı "tasarım programı"na çevirirdi.
const List<Color> kolajZeminleri = [
  Colors.black,
  Colors.white,
  DiziRenkler.sari,
  Color(0xFF2A2A2E),
];

/// Testler için: JPEG kodlayıcı yerine geçer (gerçek parça inmez).
@visibleForTesting
Future<Uint8List?> Function(ui.Image)? kolajKodlaSahte;

/// Kolaj ekranını açar; kolajın JPEG (parça inemezse PNG) baytlarını döner.
/// Vazgeçilirse `null`. [fotolar] 2..[kolajAzamiFoto] adet olmalı.
Future<Uint8List?> kolajOlustur(
  BuildContext context,
  List<ImageProvider> fotolar,
) {
  assert(fotolar.length >= 2 && fotolar.length <= kolajAzamiFoto);
  return Navigator.of(context, rootNavigator: true).push<Uint8List?>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => KolajEkrani(fotolar: fotolar),
    ),
  );
}

/// Alt araç sekmeleri.
enum KolajArac { duzen, oran, bosluk, kose, zemin }

class KolajEkrani extends StatefulWidget {
  final List<ImageProvider> fotolar;

  const KolajEkrani({super.key, required this.fotolar});

  @override
  State<KolajEkrani> createState() => _KolajEkraniState();
}

class _KolajEkraniState extends State<KolajEkrani> {
  late KolajSablonu _sablon;
  double _oran = 1;
  double _bosluk = 6;
  double _kose = 0;
  Color _zemin = kolajZeminleri.first;

  /// Hücre → fotoğraf indeksi. Yer değiştirme bu listeyi çevirir.
  late List<int> _sira;

  /// Yer değiştirme için ilk dokunulan hücre.
  int? _secili;

  /// Hücre başına yaklaştırma/kaydırma. Yer değiştirince sıfırlanır: bir
  /// fotoğrafın kadrajı başka fotoğrafa taşınmaz.
  late List<TransformationController> _donusumler;

  KolajArac _arac = KolajArac.duzen;
  bool _hazirlaniyor = false;

  final _tuval = GlobalKey();

  int get _adet => widget.fotolar.length;

  @override
  void initState() {
    super.initState();
    _sablon = kolajSablonlariIcin(_adet).first;
    _sira = List.generate(_adet, (i) => i);
    _donusumler = List.generate(_adet, (_) => TransformationController());
  }

  @override
  void dispose() {
    for (final d in _donusumler) {
      d.dispose();
    }
    super.dispose();
  }

  void _hucreyeDokun(int i) {
    setState(() {
      if (_secili == null) {
        _secili = i;
        return;
      }
      if (_secili == i) {
        _secili = null;
        return;
      }
      final a = _secili!;
      final t = _sira[a];
      _sira[a] = _sira[i];
      _sira[i] = t;
      _donusumler[a].value = Matrix4.identity();
      _donusumler[i].value = Matrix4.identity();
      _secili = null;
    });
  }

  /// "Tamam": tuvali yüksek çözünürlükte görüntüye alır, JPEG'e kodlar.
  Future<void> _bitir() async {
    if (_hazirlaniyor) return;
    setState(() {
      _hazirlaniyor = true;
      _secili = null; // seçim çerçevesi çıktıya girmez ama yine de temiz
    });
    final gezgin = Navigator.of(context);
    final mesajci = ScaffoldMessenger.of(context);
    ui.Image? gorsel;
    try {
      // Seçim vurgusu kalktıktan sonra bir kare bekle ki tuval güncel çizilsin.
      await WidgetsBinding.instance.endOfFrame;
      final sinir =
          _tuval.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final uzunKenar = math.max(sinir.size.width, sinir.size.height);
      gorsel = await sinir.toImage(pixelRatio: kolajHedefKenar / uzunKenar);
      var bayt = await (kolajKodlaSahte ?? gorseliJpegKodla)(gorsel);
      // Kodlayıcı (ertelenmiş parça) inemediyse PNG: büyük ama kayıpsız;
      // kolajı çöpe atmaktan iyi. Gerekirse editör hattı zaten küçültür.
      bayt ??= (await gorsel.toByteData(
        format: ui.ImageByteFormat.png,
      ))?.buffer.asUint8List();
      if (!mounted) return;
      if (bayt == null || bayt.isEmpty) {
        mesajci
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text('Kolaj oluşturulamadı'.c)));
        setState(() => _hazirlaniyor = false);
        return;
      }
      gezgin.pop(bayt);
    } catch (_) {
      if (!mounted) return;
      mesajci
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('Kolaj oluşturulamadı'.c)));
      setState(() => _hazirlaniyor = false);
    } finally {
      gorsel?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Kapat'.c,
          onPressed: _hazirlaniyor ? null : () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Kolaj'.c,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: TextButton(
              key: const ValueKey('kolaj-tamam'),
              onPressed: _hazirlaniyor ? null : _bitir,
              style: TextButton.styleFrom(
                minimumSize: const Size(64, 44),
                foregroundColor: DiziRenkler.sariMetin,
                disabledForegroundColor: DiziRenkler.metin38,
              ),
              child: _hazirlaniyor
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: DiziRenkler.sariMetin,
                      ),
                    )
                  : Text(
                      'Tamam'.c,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _tuvalAlani()),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              'Yer değiştirmek için iki fotoğrafa dokun'.c,
              style: TextStyle(fontSize: 12, color: DiziRenkler.metin54),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 84, child: _aracPaneli()),
          _AracCubugu(secili: _arac, sec: (a) => setState(() => _arac = a)),
          SizedBox(height: altGuvenli(context, ekstra: 8)),
        ],
      ),
    );
  }

  Widget _tuvalAlani() {
    return ColoredBox(
      color: DiziRenkler.markaKoyu,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: AspectRatio(
            aspectRatio: _oran,
            child: LayoutBuilder(
              builder: (context, kutu) {
                final boy = Size(kutu.maxWidth, kutu.maxHeight);
                return Stack(
                  children: [
                    RepaintBoundary(
                      key: _tuval,
                      child: Container(
                        key: const ValueKey('kolaj-tuval'),
                        color: _zemin,
                        width: boy.width,
                        height: boy.height,
                        child: Stack(
                          children: [
                            for (var i = 0; i < _adet; i++) _hucre(i, boy),
                          ],
                        ),
                      ),
                    ),
                    // Seçim çerçevesi TUVAL DIŞINDA: `toImage` onu görmez.
                    if (_secili != null)
                      Positioned.fromRect(
                        rect: _hucreKutusu(_secili!, boy),
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(_kose),
                              border: Border.all(
                                color: DiziRenkler.sari,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Hücrenin tuvaldeki kutusu: şablon kesri × boyut, her kenardan yarım
  /// boşluk içeri. Böylece hücre arası TAM boşluk, dış kenar da aynı.
  Rect _hucreKutusu(int i, Size boy) {
    final r = _sablon.hucreler[i];
    final y = _bosluk / 2;
    return Rect.fromLTRB(
      r.left * boy.width + y,
      r.top * boy.height + y,
      r.right * boy.width - y,
      r.bottom * boy.height - y,
    );
  }

  Widget _hucre(int i, Size boy) {
    final kutu = _hucreKutusu(i, boy);
    return Positioned.fromRect(
      rect: kutu,
      child: Semantics(
        button: true,
        selected: _secili == i,
        label: 'Fotoğraf'.c,
        child: GestureDetector(
          key: ValueKey('kolaj-hucre-$i'),
          behavior: HitTestBehavior.opaque,
          onTap: () => _hucreyeDokun(i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_kose),
            child: InteractiveViewer(
              transformationController: _donusumler[i],
              minScale: 1,
              maxScale: 3,
              // Hücre dışına taşma yok; kaydırma hücre içinde kalır.
              constrained: true,
              child: SizedBox.expand(
                child: Image(
                  image: widget.fotolar[_sira[i]],
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: DiziRenkler.kart,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: DiziRenkler.metin54,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _aracPaneli() => switch (_arac) {
    KolajArac.duzen => ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      children: [
        for (final s in kolajSablonlariIcin(_adet)) ...[
          _SablonKaresi(
            key: ValueKey('sablon-${s.kimlik}'),
            sablon: s,
            secili: s == _sablon,
            bas: () => setState(() => _sablon = s),
          ),
          const SizedBox(width: 8),
        ],
      ],
    ),
    KolajArac.oran => ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
      children: [
        for (final (etiket, deger) in kolajOranlari) ...[
          _Cip(
            key: ValueKey('oran-$etiket'),
            etiket: etiket,
            secili: deger == _oran,
            bas: () => setState(() => _oran = deger),
          ),
          const SizedBox(width: 8),
        ],
      ],
    ),
    KolajArac.bosluk => _Kaydirici(
      key: const ValueKey('bosluk-kaydirici'),
      deger: _bosluk,
      azami: 24,
      degistir: (v) => setState(() => _bosluk = v),
    ),
    KolajArac.kose => _Kaydirici(
      key: const ValueKey('kose-kaydirici'),
      deger: _kose,
      azami: 32,
      degistir: (v) => setState(() => _kose = v),
    ),
    KolajArac.zemin => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final renk in kolajZeminleri)
          Semantics(
            button: true,
            selected: renk == _zemin,
            label: 'Arka plan'.c,
            child: InkWell(
              key: ValueKey('zemin-${renk.toARGB32()}'),
              customBorder: const CircleBorder(),
              onTap: () => setState(() => _zemin = renk),
              child: Padding(
                // 32 + 2×6 = 44 dp dokunma hedefi.
                padding: const EdgeInsets.all(6),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: renk,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: renk == _zemin
                          ? DiziRenkler.sariMetin
                          : DiziRenkler.metin38,
                      width: renk == _zemin ? 3 : 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  };
}

/// Şablonun küçük çizimi: hücreler koyu zeminde açık dikdörtgenler.
class _SablonKaresi extends StatelessWidget {
  final KolajSablonu sablon;
  final bool secili;
  final VoidCallback bas;
  const _SablonKaresi({
    super.key,
    required this.sablon,
    required this.secili,
    required this.bas,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: secili,
    label: 'Düzen'.c,
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: bas,
      child: Container(
        width: 64,
        height: 64,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: DiziRenkler.kart,
          borderRadius: BorderRadius.circular(8),
          border: secili ? Border.all(color: DiziRenkler.sari, width: 2) : null,
        ),
        child: CustomPaint(
          painter: _SablonCizici(
            sablon,
            secili ? DiziRenkler.sari : DiziRenkler.metin70,
          ),
        ),
      ),
    ),
  );
}

class _SablonCizici extends CustomPainter {
  final KolajSablonu sablon;
  final Color renk;
  const _SablonCizici(this.sablon, this.renk);

  @override
  void paint(Canvas canvas, Size size) {
    final boya = Paint()..color = renk;
    for (final r in sablon.hucreler) {
      final k = Rect.fromLTRB(
        r.left * size.width + 1.5,
        r.top * size.height + 1.5,
        r.right * size.width - 1.5,
        r.bottom * size.height - 1.5,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(k, const Radius.circular(2)),
        boya,
      );
    }
  }

  @override
  bool shouldRepaint(_SablonCizici eski) =>
      eski.sablon != sablon || eski.renk != renk;
}

class _Kaydirici extends StatelessWidget {
  final double deger;
  final double azami;
  final void Function(double) degistir;
  const _Kaydirici({
    super.key,
    required this.deger,
    required this.azami,
    required this.degistir,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(
      children: [
        Expanded(
          child: Slider(
            value: deger,
            min: 0,
            max: azami,
            onChanged: degistir,
            activeColor: DiziRenkler.sari,
            inactiveColor: DiziRenkler.metin12,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '${deger.round()}',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: DiziRenkler.metin,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Alt araç çubuğu: Düzen · Oran · Boşluk · Köşe · Arka plan.
class _AracCubugu extends StatelessWidget {
  final KolajArac secili;
  final void Function(KolajArac) sec;
  const _AracCubugu({required this.secili, required this.sec});

  @override
  Widget build(BuildContext context) {
    final araclar = [
      (KolajArac.duzen, Icons.dashboard_outlined, 'Düzen'.c),
      (KolajArac.oran, Icons.aspect_ratio, 'Oran'.c),
      (KolajArac.bosluk, Icons.space_bar, 'Boşluk'.c),
      (KolajArac.kose, Icons.rounded_corner, 'Köşe'.c),
      (KolajArac.zemin, Icons.format_color_fill, 'Arka plan'.c),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: DiziRenkler.metin12)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          for (final (arac, ikon, ad) in araclar)
            Expanded(
              child: Semantics(
                button: true,
                selected: arac == secili,
                label: ad,
                child: InkWell(
                  key: ValueKey('kolaj-arac-${arac.name}'),
                  onTap: () => sec(arac),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          ikon,
                          size: 22,
                          color: arac == secili
                              ? DiziRenkler.sariMetin
                              : DiziRenkler.metin70,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ad,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: arac == secili
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: arac == secili
                                ? DiziRenkler.sariMetin
                                : DiziRenkler.metin70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Seçilebilir çip (oran). 44 dp dokunma hedefi; `video_duzenle.dart`taki
/// hız çipiyle aynı görünüm.
class _Cip extends StatelessWidget {
  final String etiket;
  final bool secili;
  final VoidCallback bas;
  const _Cip({
    super.key,
    required this.etiket,
    required this.secili,
    required this.bas,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: secili,
    label: etiket,
    child: Material(
      color: secili ? DiziRenkler.sari : DiziRenkler.kart,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: bas,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Text(
            etiket,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: secili ? Colors.black : DiziRenkler.metin,
            ),
          ),
        ),
      ),
    ),
  );
}
