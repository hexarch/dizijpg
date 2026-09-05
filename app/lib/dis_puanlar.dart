// DIŞ PUANLAR — IMDb / Rotten Tomatoes (eleştirmen + seyirci) / Metacritic
// (6 Eyl 2026). Veri `GET /dis-puan/:tur/:id` → `{dis: {...}}`; sunucu MDBList'ten
// çekip önbellekler (backend/dis_puan.js başlığı: neden MDBList, günlük 1.000
// istek bütçesi, "önce kullanıcıların izlediği yapımlar" gece işi).
//
// GÖRÜNÜM: TMDB satırının ALTINDA bir Wrap; her kaynak bir rozet.
//  · IMDb: sarı "IMDb" pulu + puan (0-10, bir ondalık, CLDR ondalık ayracı).
//  · Eleştirmen (Tomatometer): kırmızı nokta (taze, ≥60) / yeşil-gri nokta
//    (çürük) + yüzde + "Eleştirmen".
//  · Seyirci (Popcornmeter): turuncu nokta + yüzde + "Seyirci".
//  · Metacritic: kendi renk şemasında (61+ yeşil, 40-60 sarı, <40 kırmızı)
//    kare + sayı + "Metacritic".
//  Marka LOGOLARI BİLEREK YOK: IMDb ve Rotten Tomatoes'un logoları tescilli;
//  metin etiketi + renk yeter, kaynağa dokunarak gidilir.
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

class DisPuanlar extends StatelessWidget {
  const DisPuanlar({super.key, required this.dis});

  final Map<String, dynamic> dis;

  @override
  Widget build(BuildContext context) {
    final imdb = dis['imdb'];
    final rtE = dis['rt_elestirmen'];
    final rtS = dis['rt_seyirci'];
    final meta = dis['metacritic'];
    final imdbUrl = dis['imdb_url'] as String?;
    final rtUrl = dis['rt_url'] as String?;
    final rozetler = <Widget>[
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
            const SizedBox(width: 5),
            _Deger(disImdbMetni(imdb)),
          ],
        ),
      if (rtE is num)
        _Rozet(
          key: const Key('dis-rt-elestirmen'),
          url: rtUrl,
          semantik: '${'Eleştirmen'.c} ${disYuzdeMetni(rtE.toInt())}',
          children: [
            _Nokta(
              (dis['rt_taze'] as bool? ?? rtE >= 60)
                  ? const Color(0xFFFA320A)
                  : const Color(0xFF6C9A3A),
            ),
            const SizedBox(width: 5),
            _Deger(disYuzdeMetni(rtE.toInt())),
            const SizedBox(width: 4),
            _Etiket('Eleştirmen'.c),
          ],
        ),
      if (rtS is num)
        _Rozet(
          key: const Key('dis-rt-seyirci'),
          url: rtUrl,
          semantik: '${'Seyirci'.c} ${disYuzdeMetni(rtS.toInt())}',
          children: [
            const _Nokta(Color(0xFFFFB300)),
            const SizedBox(width: 5),
            _Deger(disYuzdeMetni(rtS.toInt())),
            const SizedBox(width: 4),
            _Etiket('Seyirci'.c),
          ],
        ),
      if (meta is num)
        _Rozet(
          key: const Key('dis-metacritic'),
          url: null,
          semantik: 'Metacritic ${meta.toInt()}',
          children: [
            Container(
              width: 18,
              height: 18,
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
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 5),
            _Etiket('Metacritic'),
          ],
        ),
    ];
    if (rozetler.isEmpty) return const SizedBox.shrink();
    return Wrap(
      key: const Key('dis-puanlar'),
      spacing: 8,
      runSpacing: 2,
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
    final govde = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: DiziRenkler.kart,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DiziRenkler.metin12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
    final u = url;
    // Görünen rozet ~26 dp; dokunma alanı 44 dp'ye SizedBox ile büyütülür
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

class _Nokta extends StatelessWidget {
  const _Nokta(this.renk);
  final Color renk;
  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(color: renk, shape: BoxShape.circle),
  );
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

class _Etiket extends StatelessWidget {
  const _Etiket(this.metin);
  final String metin;
  @override
  Widget build(BuildContext context) => Text(
    metin,
    style: TextStyle(
      color: DiziRenkler.metin54,
      fontWeight: FontWeight.w600,
      fontSize: 11.5,
    ),
  );
}
