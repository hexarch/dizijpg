import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';

/// DOĞUM GÜNÜ KUTLAMASI (istek md. 36).
///
/// "Doğum günü olan kullanıcıda uygulama ikonu değişsin, kutlayalım."
///
/// UYGULAMA İKONU BİLEREK DEĞİŞTİRİLMEDİ. Android'de çalışma anında ikon
/// değiştirmenin resmi bir API'si yok; tek yol manifeste gömülü
/// `activity-alias`ları açıp kapatmak ve yan etkileri gerçek: bazı
/// başlatıcılarda ikon ANA EKRANDAN DÜŞER, kısayollar/widget'lar kırılır,
/// uygulama o anda kapanabilir. "Kutlama" niyetiyle kullanıcının ana
/// ekranındaki kısayolunu kaybettiremeyiz — kutlama UYGULAMA İÇİNDE yapılır,
/// bu ekran odur. (İkon tasarım önerileri `ikon-onerileri/` altında duruyor;
/// uygulanmadı, kullanıcının kararını bekliyor.)
///
/// DAVRANIŞ
///   * Kabuk açılışında BİR KEZ sunucuya sorulur (`GET /dogum-gunu`).
///     Sunucu "bugün"ü kullanıcının YEREL takvim gününe göre değerlendirir
///     (istemci `?bugun=` ile bildirir) — sunucu UTC çalıştığı için UTC
///     gününe bakmak UTC+3'teki kullanıcıyı 03:00'a kadar kutlamasız
///     bırakırdı.
///   * GÜNDE BİR KEZ görünür: gösterildiği gün [dogumGunuKutlandiAnahtari]'na
///     damgalanır. Doğum günü yılda bir gün olduğu için bu damga aynı zamanda
///     "bu yıl kutlandı" anlamına gelir.
///   * Kullanıcı kapatabilir: kapat ikonu, "Teşekkürler" düğmesi ya da
///     perdeye dokunma.
///   * HAREKET AZALTMA açıksa (`MediaQuery.disableAnimations`) konfeti HİÇ
///     oynamaz, yalnız mesaj kartı görünür.
///   * Doğum tarihi girmemiş kullanıcıda hiç çıkmaz (sunucu `kutlama: false`).

/// Sunucuya en son hangi gün sorulduğu (YYYY-MM-DD). Doğum günü OLMAYAN
/// günlerde her açılışta istek atmamak için.
const String dogumGunuSorulduAnahtari = 'dogum_gunu_soruldu';

/// Kutlamanın GERÇEKTEN gösterildiği gün (YYYY-MM-DD) — günde bir kez kuralı.
///
/// İki ayrı damga olmasının sebebi: "soruldu" damgası kutlama gününde
/// YAZILMAZ. Yazsaydık, sunucu yanıtı geldikten hemen sonra uygulama
/// öldürülen kullanıcı o yılki kutlamasını hiç görmeden kaybederdi.
const String dogumGunuKutlandiAnahtari = 'dogum_gunu_kutlandi';

/// Konfetinin toplam süresi. Tek seferlik: SONSUZ TEKRAR YOK — hem
/// erişilebilirlik kuralı (sürekli hareket dikkat dağıtır) hem de widget
/// testinde `pumpAndSettle`'ın asla oturmamasının sebebi tam olarak budur
/// (13 Ağu'da emoji animasyonunda yaşandı).
const Duration konfetiSuresi = Duration(milliseconds: 2600);

/// Sunucudan gelen kutlama durumu.
class DogumGunuDurumu {
  /// Bugün kullanıcının doğum günü mü?
  final bool kutlama;

  /// Kaç yaşına girdiği — yalnız doğum YILINI paylaşmışsa dolu.
  final int? yas;

  const DogumGunuDurumu({required this.kutlama, this.yas});
}

/// Kutlama sorgusu. Testte sahte bir işlevle değiştirilebilsin diye ayrı tip.
typedef DogumGunuSorgusu = Future<DogumGunuDurumu> Function();

/// `YYYY-MM-DD` — sunucuya gönderilen ve prefs'e damgalanan YEREL gün.
String dogumGunuGunDamgasi(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-'
    '${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';

/// Varsayılan sorgu: `GET /dogum-gunu?bugun=<yerel gün>`.
Future<DogumGunuDurumu> dogumGunuSor() async {
  final bugun = dogumGunuGunDamgasi(DateTime.now());
  final d = await Api.get('/dogum-gunu?bugun=$bugun') as Map<String, dynamic>;
  return DogumGunuDurumu(
    kutlama: d['kutlama'] == true,
    yas: (d['yas'] as num?)?.toInt(),
  );
}

/// Kabuğun gövdesini saran katman: gerektiğinde üstüne kutlamayı çizer.
///
/// Gövdeyi SARMASININ sebebi: kullanıcı hangi sekmede olursa olsun kutlamayı
/// görmeli. Tek bir sekmeye koysaydık oraya uğramayan kullanıcı doğum gününü
/// kaçırırdı.
class DogumGunuKatmani extends StatefulWidget {
  final Widget child;

  /// Sunucu sorgusu (test için değiştirilebilir).
  final DogumGunuSorgusu sorgu;

  /// Girişli mi? Varsayılanı gerçek oturum; testte sabitlenebilir.
  final bool Function() girisli;

  /// "Bugün" — testte sabitlenebilir.
  final DateTime Function() simdi;

  const DogumGunuKatmani({
    super.key,
    required this.child,
    this.sorgu = dogumGunuSor,
    this.girisli = _girisliVarsayilan,
    this.simdi = DateTime.now,
  });

  static bool _girisliVarsayilan() => Api.girisli;

  @override
  State<DogumGunuKatmani> createState() => _DogumGunuKatmaniState();
}

class _DogumGunuKatmaniState extends State<DogumGunuKatmani> {
  DogumGunuDurumu? _kutlama;

  @override
  void initState() {
    super.initState();
    unawaited(_kontrol());
  }

  Future<void> _kontrol() async {
    // Misafir/çıkış yapmış kullanıcının doğum tarihi zaten yok; boşuna istek
    // atıp 401 yemeyelim.
    if (!widget.girisli()) return;
    final bugun = dogumGunuGunDamgasi(widget.simdi());
    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return; // yerel depo yoksa kutlamayı atla (tekrar tekrar gösterme riski)
    }
    // Bugün zaten kutlandı → günde bir kez.
    if (prefs.getString(dogumGunuKutlandiAnahtari) == bugun) return;
    // Bugün sorduk, doğum günü değildi → tekrar sorma.
    if (prefs.getString(dogumGunuSorulduAnahtari) == bugun) return;
    DogumGunuDurumu durum;
    try {
      durum = await widget.sorgu();
    } catch (_) {
      // Çevrimdışı/oturum hatası: damga YAZILMAZ, bir sonraki açılışta
      // yeniden denenir — kutlama ağ hatasına kurban gitmesin.
      return;
    }
    if (!durum.kutlama) {
      await prefs.setString(dogumGunuSorulduAnahtari, bugun);
      return;
    }
    if (!mounted) return;
    // Damga GÖSTERİM ANINDA yazılır: kullanıcı kapatmadan uygulamayı
    // öldürürse kutlama tekrar tekrar açılmasın.
    await prefs.setString(dogumGunuKutlandiAnahtari, bugun);
    if (!mounted) return;
    setState(() => _kutlama = durum);
  }

  void _kapat() {
    if (mounted) setState(() => _kutlama = null);
  }

  @override
  Widget build(BuildContext context) {
    final k = _kutlama;
    if (k == null) return widget.child;
    return Stack(
      children: [
        widget.child,
        DogumGunuKutlamasi(durum: k, onKapat: _kapat),
      ],
    );
  }
}

/// Kutlamanın kendisi: karartma perdesi + konfeti + mesaj kartı.
class DogumGunuKutlamasi extends StatelessWidget {
  final DogumGunuDurumu durum;
  final VoidCallback onKapat;

  const DogumGunuKutlamasi({
    super.key,
    required this.durum,
    required this.onKapat,
  });

  @override
  Widget build(BuildContext context) {
    // Hareket azaltma: konfeti HİÇ kurulmaz (durdurulmaz — hiç oluşturulmaz),
    // mesaj aynen görünür. Kutlamanın bilgisi hareketten değil metinden gelir.
    final hareketKapali = MediaQuery.disableAnimationsOf(context);
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Perde: dokununca kapanır. Kutlama kilitleyici değil — kullanıcı
          // dilediği an uygulamasına dönebilir. Ekran okuyucuya perde
          // ANLATILMAZ (etiketsiz dev bir düğme gibi okunurdu); erişilebilir
          // kapatma yolu kapat ikonu ve "Teşekkürler" düğmesidir.
          ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onKapat,
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.62)),
            ),
          ),
          if (!hareketKapali)
            const IgnorePointer(child: KonfetiYagmuru(key: Key('konfeti'))),
          Center(child: _kart(context)),
        ],
      ),
    );
  }

  Widget _kart(BuildContext context) {
    final metin = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: IconButton(
                  key: const Key('dogum-gunu-kapat'),
                  // Dokunma hedefi: IconButton varsayılan 48×48 (asgari 44'ün
                  // üstünde) — ikon küçültülse bile kutu korunur.
                  tooltip: 'Kapat'.c,
                  onPressed: onKapat,
                  icon: const Icon(Icons.close),
                ),
              ),
              // Emoji DEĞİL Material ikon (proje kuralı): pasta.
              Icon(Icons.cake, size: 56, color: DiziRenkler.sariMetin),
              const SizedBox(height: 12),
              Text(
                'Doğum günün kutlu olsun!'.c,
                textAlign: TextAlign.center,
                style: metin.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                durum.yas != null
                    ? 'Bugün {} yaşına girdin'.cf([durum.yas])
                    : 'İyi ki doğdun, iyi ki buradasın.'.c,
                textAlign: TextAlign.center,
                style: metin.bodyMedium,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('dogum-gunu-tesekkurler'),
                  onPressed: onKapat,
                  child: Text('Teşekkürler'.c),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marka renklerinde tek seferlik konfeti yağmuru.
///
/// YENİ PAKET EKLENMEDİ: bir `CustomPainter` + tek [AnimationController]
/// yetiyor. (`file_picker` geçmişi: bu projede paket eklemek bedava değil —
/// web derlemesini bozma riski var.)
class KonfetiYagmuru extends StatefulWidget {
  const KonfetiYagmuru({super.key});

  @override
  State<KonfetiYagmuru> createState() => _KonfetiYagmuruState();
}

class _KonfetiYagmuruState extends State<KonfetiYagmuru>
    with SingleTickerProviderStateMixin {
  late final AnimationController _denetci = AnimationController(
    vsync: this,
    duration: konfetiSuresi,
  );

  /// Parçacıklar SABİT TOHUMLU rastgeleyle üretilir: görüntü rastgele
  /// görünür ama her çalıştırmada AYNIdır — test kararsızlığı olmaz.
  late final List<_Parca> _parcalar = _parcaUret();

  @override
  void initState() {
    super.initState();
    _denetci.forward(); // tek geçiş; bitince kare istemez
  }

  @override
  void dispose() {
    _denetci.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _KonfetiBoyaci(ilerleme: _denetci, parcalar: _parcalar),
      size: Size.infinite,
    );
  }
}

/// Tek bir kâğıt parçası. Konumlar 0-1 ORANIDIR (ekran boyutundan bağımsız).
class _Parca {
  final double x; // yatay başlangıç (0-1)
  final double gecikme; // 0-1 arası; hepsi aynı anda düşmesin
  final double hiz; // düşüş hızı çarpanı
  final double salinim; // yanal salınım genliği (0-1)
  final double faz; // salınımın başlangıç fazı
  final double en; // parça eni (dp)
  final double boy; // parça boyu (dp)
  final double donus; // toplam dönüş (tur)
  final Color renk;

  const _Parca({
    required this.x,
    required this.gecikme,
    required this.hiz,
    required this.salinim,
    required this.faz,
    required this.en,
    required this.boy,
    required this.donus,
    required this.renk,
  });
}

/// Marka paleti: sarı + siyah kimliği bozulmasın diye ağırlık sarıda.
/// Beyaz ve gri, koyu perdede sarının yanında okunur kalıyor.
const List<Color> konfetiRenkleri = [
  DiziRenkler.sari,
  DiziRenkler.acikSari,
  DiziRenkler.sari,
  Colors.white,
  Color(0xFFBDBDC4),
];

List<_Parca> _parcaUret() {
  final r = math.Random(20260813);
  return List.generate(48, (i) {
    return _Parca(
      x: r.nextDouble(),
      gecikme: r.nextDouble() * 0.35,
      hiz: 0.85 + r.nextDouble() * 0.45,
      salinim: 0.02 + r.nextDouble() * 0.06,
      faz: r.nextDouble() * math.pi * 2,
      en: 6 + r.nextDouble() * 5,
      boy: 9 + r.nextDouble() * 8,
      donus: 1 + r.nextDouble() * 3,
      renk: konfetiRenkleri[i % konfetiRenkleri.length],
    );
  });
}

class _KonfetiBoyaci extends CustomPainter {
  final Animation<double> ilerleme;
  final List<_Parca> parcalar;

  _KonfetiBoyaci({required this.ilerleme, required this.parcalar})
    : super(repaint: ilerleme);

  @override
  void paint(Canvas tuval, Size boyut) {
    final t = ilerleme.value;
    final firca = Paint()..style = PaintingStyle.fill;
    for (final p in parcalar) {
      // Gecikmeyi düşüp 0-1'e normalle; henüz başlamadıysa çizme.
      final yerel = (t - p.gecikme) / (1 - p.gecikme);
      if (yerel <= 0) continue;
      final ilerlemeY = (yerel * p.hiz).clamp(0.0, 1.4);
      // Yukarıdan (-%10) aşağıya (%120) düşer.
      final y = (-0.1 + ilerlemeY * 1.3) * boyut.height;
      if (y > boyut.height) continue;
      final x =
          (p.x + math.sin(p.faz + yerel * math.pi * 4) * p.salinim) *
          boyut.width;
      // Son %20'de sönümlenerek kaybolur — animasyon "kesilmiş" gibi durmasın.
      final sonum = yerel > 0.8
          ? (1 - (yerel - 0.8) / 0.2).clamp(0.0, 1.0)
          : 1.0;
      firca.color = p.renk.withValues(alpha: sonum);
      tuval.save();
      tuval.translate(x, y);
      tuval.rotate(yerel * p.donus * math.pi * 2);
      tuval.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.en, height: p.boy),
        firca,
      );
      tuval.restore();
    }
  }

  @override
  bool shouldRepaint(_KonfetiBoyaci eski) =>
      eski.parcalar != parcalar || eski.ilerleme != ilerleme;
}
