// DIŞ PUANLAR — IMDb / Rotten Tomatoes (eleştirmen + seyirci) / Metacritic
// (6 Eyl 2026). Veri `GET /dis-puan/:tur/:id` → `{dis: {...}}`; sunucu MDBList'ten
// çekip önbellekler (backend/dis_puan.js başlığı: neden MDBList, günlük 1.000
// istek bütçesi, "önce kullanıcıların izlediği yapımlar" gece işi).
//
// GÖRÜNÜM: TMDB satırının DEVAMINDA, aynı Wrap içinde ("★ 8.1 TMDB · 4.3
// dizi.jpg · IMDb 8,0 · 🍅 %95 · 🍿 %79 · [75]"); YAZI YOK, yalnız simge + sayı
// (kullanıcı kararı 6 Eyl: "yanlarına yazı yazmana gerek yok, TMDB puanının
// yanından sıralamaya başla, sadece logoları olsun").
//  · IMDb: sarı "IMDb" pulu + puan (0-10, bir ondalık, CLDR ondalık ayracı).
//  · Eleştirmen (Tomatometer): KENDİ ÇİZİMİMİZ domates — kırmızı (taze, ≥60)
//    / yeşil-gri (çürük) + yüzde.
//  · Seyirci (Popcornmeter): KENDİ ÇİZİMİMİZ patlamış mısır kovası + yüzde.
//  · Metacritic: kendi renk şemasında (61+ yeşil, 40-60 sarı, <40 kırmızı)
//    kare, sayı karenin içinde.
//  "Eleştirmen"/"Seyirci" metinleri yalnız erişilebilirlik etiketinde.
//  Marka LOGOLARI BİLEREK YOK: IMDb ve Rotten Tomatoes'un logoları tescilli;
//  domates/patlamış mısır simgeleri bizim genel çizimlerimiz (CustomPainter),
//  logo kopyası değil. Kaynağa dokunarak gidilir.
//
// YÜZDE BİÇİMİ CLDR'den: Türkçe "%96", İngilizce "96%", Farsça yerel rakam.
// Yeni çevrilebilir dize yalnız iki tane: 'Eleştirmen' ve 'Seyirci'.
//
// DOKUNMA: rozet, sunucunun verdiği mutlak adresle kaynak sayfasını DIŞ
// tarayıcıda açar (`imdb_url`, `rt_url`). Adres yoksa rozet düz metindir.
// Dokunma hedefi 44 dp (`dokunmaHedefi`), görünen rozet ondan küçüktür.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ceviri.dart';
import 'ekranlar/ortak.dart' show dokunmaHedefi;
import 'tema.dart';

/// Sunucu yanıtındaki `dis` haritasında EN AZ bir gösterilecek puan var mı?
bool disPuanVar(Map<String, dynamic>? dis) {
  if (dis == null) return false;
  return dis['imdb'] is num ||
      dis['rt_elestirmen'] is num ||
      dis['rt_seyirci'] is num ||
      dis['metacritic'] is num;
}

/// 0-100 tam sayı → yerel yüzde metni ("%96" / "96%" / "۹۶٪").
String disYuzdeMetni(int n) =>
    NumberFormat.percentPattern(Ceviri.dil.value).format(n / 100);

/// IMDb puanı → bir ondalıklı yerel metin ("9,3" / "9.3").
String disImdbMetni(num v) => NumberFormat.decimalPatternDigits(
  locale: Ceviri.dil.value,
  decimalDigits: 1,
).format(v);

/// Metacritic'in kendi renk şeması.
Color metacriticRengi(int n) {
  if (n >= 61) return const Color(0xFF66CC33);
  if (n >= 40) return const Color(0xFFFFCC33);
  return const Color(0xFFFF0000);
}

/// TMDB satırının DEVAMINA eklenecek rozetler (kullanıcı, 6 Eyl: "yanlarına
/// yazı yazmana gerek yok, TMDB puanının yanından sıralamaya başla, sadece
/// logoları olsun"). Yalnız simge + sayı; etiket metni yalnız erişilebilirlik
/// (Semantics) için. Çağıran bunları TMDB satırının Wrap'ine yayar.
List<Widget> disPuanRozetleri(Map<String, dynamic>? dis) {
  if (dis == null) return const [];
  final imdb = dis['imdb'];
  final rtE = dis['rt_elestirmen'];
  final rtS = dis['rt_seyirci'];
  final meta = dis['metacritic'];
  final imdbUrl = dis['imdb_url'] as String?;
  final rtUrl = dis['rt_url'] as String?;
  return [
    if (imdb is num)
      _Rozet(
        key: const Key('dis-imdb'),
        url: imdbUrl,
        semantik: 'IMDb ${disImdbMetni(imdb)}',
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: DiziRenkler.sari,
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text(
              'IMDb',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 10,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(width: 4),
          _Deger(disImdbMetni(imdb)),
        ],
      ),
    if (rtE is num)
      _Rozet(
        key: const Key('dis-rt-elestirmen'),
        url: rtUrl,
        semantik: '${'Eleştirmen'.c} ${disYuzdeMetni(rtE.toInt())}',
        children: [
          DomatesIkonu(taze: dis['rt_taze'] as bool? ?? rtE >= 60, boyut: 16),
          const SizedBox(width: 4),
          _Deger(disYuzdeMetni(rtE.toInt())),
        ],
      ),
    if (rtS is num)
      _Rozet(
        key: const Key('dis-rt-seyirci'),
        url: rtUrl,
        semantik: '${'Seyirci'.c} ${disYuzdeMetni(rtS.toInt())}',
        children: [
          const PatlamisMisirIkonu(boyut: 16),
          const SizedBox(width: 4),
          _Deger(disYuzdeMetni(rtS.toInt())),
        ],
      ),
    if (meta is num)
      _Rozet(
        key: const Key('dis-metacritic'),
        url: null,
        semantik: 'Metacritic ${meta.toInt()}',
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: metacriticRengi(meta.toInt()),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              '${meta.toInt()}',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
  ];
}

/// Tek başına kullanım (test/önizleme): rozetleri kendi Wrap'inde çizer.
class DisPuanlar extends StatelessWidget {
  const DisPuanlar({super.key, required this.dis});

  final Map<String, dynamic> dis;

  @override
  Widget build(BuildContext context) {
    final rozetler = disPuanRozetleri(dis);
    if (rozetler.isEmpty) return const SizedBox.shrink();
    return Wrap(
      key: const Key('dis-puanlar'),
      spacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: rozetler,
    );
  }
}

class _Rozet extends StatelessWidget {
  const _Rozet({
    super.key,
    required this.children,
    required this.semantik,
    this.url,
  });

  final List<Widget> children;
  final String semantik;
  final String? url;

  @override
  Widget build(BuildContext context) {
    // Kutu/kenarlık YOK: TMDB satırındaki "★ 8.1 TMDB" ile aynı ağırlıkta,
    // yalnız simge + sayı. Dokunma alanı yine 44 dp (SizedBox).
    final govde = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
    final u = url;
    // Görünen rozet ~24 dp; dokunma alanı 44 dp'ye SizedBox ile büyütülür
    // (ikon değil, hedef büyür — dizijpg-ux-kontrol §2).
    return Semantics(
      label: semantik,
      button: u != null,
      child: SizedBox(
        height: dokunmaHedefi,
        child: Center(
          widthFactor: 1,
          child: u == null
              ? govde
              : InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => disBaglantiAc(u),
                  child: govde,
                ),
        ),
      ),
    );
  }
}

/// Testte ele geçirilebilsin diye üst düzey ve değiştirilebilir.
Future<void> Function(String url) disBaglantiAc = (url) async {
  final u = Uri.tryParse(url);
  if (u == null) return;
  try {
    await launchUrl(u, mode: LaunchMode.externalApplication);
  } catch (_) {
    // Tarayıcı yoksa sessiz: rozet bilgi amaçlı, açılmaması hata değil.
  }
};

/// Kendi çizimimiz domates — Rotten Tomatoes'un tescilli logosu DEĞİL,
/// genel bir domates: taze (kırmızı) / çürük (yeşil-gri) + yeşil sap.
/// 14 dp; rozet metniyle aynı satırda durur.
class DomatesIkonu extends StatelessWidget {
  const DomatesIkonu({super.key, required this.taze, this.boyut = 14});

  final bool taze;
  final double boyut;

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: Key(taze ? 'domates-taze' : 'domates-curuk'),
    size: Size(boyut, boyut),
    painter: _DomatesBoyaci(taze: taze),
  );
}

class _DomatesBoyaci extends CustomPainter {
  const _DomatesBoyaci({required this.taze});
  final bool taze;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final govde = Paint()
      ..color = taze ? const Color(0xFFFA320A) : const Color(0xFF7A8F3C);
    // Gövde: hafif basık daire (domates yuvarlak ama basıktır)
    canvas.drawOval(Rect.fromLTWH(0, h * 0.22, w, h * 0.78), govde);
    // Parlama
    canvas.drawCircle(
      Offset(w * 0.32, h * 0.5),
      w * 0.09,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
    // Sap ve yapraklar (yeşil)
    final yesil = Paint()..color = const Color(0xFF3E9B2F);
    canvas.drawRect(Rect.fromLTWH(w * 0.46, 0, w * 0.08, h * 0.3), yesil);
    final yaprak = Path()
      ..moveTo(w * 0.5, h * 0.3)
      ..quadraticBezierTo(w * 0.2, h * 0.1, w * 0.12, h * 0.34)
      ..quadraticBezierTo(w * 0.35, h * 0.32, w * 0.5, h * 0.3)
      ..quadraticBezierTo(w * 0.65, h * 0.32, w * 0.88, h * 0.34)
      ..quadraticBezierTo(w * 0.8, h * 0.1, w * 0.5, h * 0.3)
      ..close();
    canvas.drawPath(yaprak, yesil);
  }

  @override
  bool shouldRepaint(_DomatesBoyaci eski) => eski.taze != taze;
}

/// Kendi çizimimiz patlamış mısır: kırmızı-beyaz çizgili kova + üstte
/// sarı-beyaz taneler. Seyirci puanının simgesi.
class PatlamisMisirIkonu extends StatelessWidget {
  const PatlamisMisirIkonu({super.key, this.boyut = 14});

  final double boyut;

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: const Key('patlamis-misir'),
    size: Size(boyut, boyut),
    painter: const _PatlamisMisirBoyaci(),
  );
}

class _PatlamisMisirBoyaci extends CustomPainter {
  const _PatlamisMisirBoyaci();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Kova: alta doğru daralan yamuk, kırmızı-beyaz dikey şeritler
    final kova = Path()
      ..moveTo(w * 0.12, h * 0.42)
      ..lineTo(w * 0.88, h * 0.42)
      ..lineTo(w * 0.78, h)
      ..lineTo(w * 0.22, h)
      ..close();
    canvas.save();
    canvas.clipPath(kova);
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.42, w, h * 0.58),
      Paint()..color = const Color(0xFFE53935),
    );
    final beyaz = Paint()..color = Colors.white;
    for (final x in [0.27, 0.55]) {
      canvas.drawRect(Rect.fromLTWH(w * x, h * 0.42, w * 0.14, h), beyaz);
    }
    canvas.restore();
    // Taneler: sarı ve krem toplar
    final sari = Paint()..color = const Color(0xFFFFC107);
    final krem = Paint()..color = const Color(0xFFFFF3C4);
    canvas.drawCircle(Offset(w * 0.5, h * 0.2), w * 0.2, sari);
    canvas.drawCircle(Offset(w * 0.24, h * 0.34), w * 0.17, krem);
    canvas.drawCircle(Offset(w * 0.76, h * 0.34), w * 0.17, krem);
    canvas.drawCircle(Offset(w * 0.5, h * 0.4), w * 0.16, sari);
  }

  @override
  bool shouldRepaint(_PatlamisMisirBoyaci eski) => false;
}

class _Deger extends StatelessWidget {
  const _Deger(this.metin);
  final String metin;
  @override
  Widget build(BuildContext context) => Text(
    metin,
    style: TextStyle(
      color: DiziRenkler.metin,
      fontWeight: FontWeight.w800,
      fontSize: 12.5,
    ),
  );
}
