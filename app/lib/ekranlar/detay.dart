import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// `hide TextDirection`: intl'in kendi `TextDirection` sınıfı Flutter'ınkiyle
// çakışıyor ve [ButceRozeti] okun yönünü `Directionality.of(context)` ile,
// yani FLUTTER'ın sıralamasıyla seçiyor.
import 'package:intl/intl.dart' hide TextDirection;

import '../api.dart';
import '../gorsel_basliklari.dart';
import '../kitaplik_durumu.dart';
import '../ceviri.dart';
import '../puan.dart';
import '../tarih.dart';
import '../tema.dart';
import '../tmdb_bolum_puan.dart';
import '../tmdb_fragman.dart';
import 'giris_istem.dart';
import 'gozat.dart' show gozatYolu;
import 'kahraman_karisik.dart';
import 'medya_goster.dart';
import 'ortak.dart';
import 'puan_dagilimi.dart';
import 'sirket.dart';
import 'tmdb_puan_izgara.dart';
import 'tepki.dart';
import 'yorumlar.dart';

const durumSecenekleri = [
  ('izleyecegim', 'İzleyeceğim', Icons.bookmark_add_outlined),
  ('izliyorum', 'İzliyorum', Icons.play_circle_outline),
  ('bitirdim', 'Bitirdim', Icons.check_circle_outline),
  ('biraktim', 'Bıraktım', Icons.cancel_outlined),
];

/// TEKİLLİK KURALI — "ya izleyecektir ya izlemiştir" (kullanıcı, 14 Ağu 2026).
///
/// İzleme kaydı varken "İzleyeceğim" seçilirse sunucu 409 + `IZLEME_KAYDI_VAR`
/// döner ve isteği REDDEDER. Kuralı SUNUCU koyar (eski sürümler ve doğrudan
/// API çağrıları da tutarlı kalsın diye); burada yalnız ONAY toplanır.
///
/// VERİ KAYBI SESSİZ OLAMAZ: dizide bu, onlarca bölümlük geçmiş demektir.
/// Bu yüzden silinecek KAYIT SAYISI metne yazılır ve onay düğmesi kırmızıdır
/// (`_sifirla`daki "Sil" ile aynı dil).
///
/// Dönüş: `true` = onaylandı, aksi hâlde vazgeçildi.
Future<bool?> izlemeSilmeOnayi(
  BuildContext context, {
  required String tur,
  required int adet,
}) => showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    backgroundColor: DiziRenkler.koyuGri,
    title: Text('İzleyeceklerine taşınsın mı?'.c),
    content: Text(
      tur == 'tv'
          ? 'Bir içerik ya izlenecektir ya izlenmiştir. Devam edersen bu dizideki {} izleme işaretin silinecek.'
                .cf([adet])
          : 'Bir içerik ya izlenecektir ya izlenmiştir. Devam edersen bu filmdeki "izledim" işaretin kaldırılacak.'
                .c,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text('İptal'.c),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
        ),
        onPressed: () => Navigator.pop(context, true),
        child: Text('Sil ve taşı'.c),
      ),
    ],
  ),
);

/// Detay başlığındaki kapak yolları: ANA kapak (backdrop_path) HER ZAMAN ilk
/// sırada, ardından TMDB'nin arka plan görselleri en çok oy alandan başlayarak.
/// Aynı yol iki kez girmez; en fazla [kapakTavani] tane.
///
/// Yalnız `backdrops` kullanılır, `posters` katılmaz: başlık geniş (16:9) bir
/// şerittir, 2:3 afişler orada ya kırpılıp tanınmaz olur ya da yanlarda kalın
/// siyah bantla durur. Afiş zaten arama/kitaplık kartlarında görünüyor.
///
/// TMDB'de 3'ten az görseli olan yapımlar var; görsel uyduramayız — kaç tane
/// varsa o gösterilir, tek görselde başlık eskisi gibi sabit kalır.
const kapakTavani = 10;

List<String> kapaklariCikar(Map<String, dynamic> icerik) {
  final yollar = <String>[];
  final ana = icerik['backdrop_path'] as String?;
  if (ana != null && ana.isNotEmpty) yollar.add(ana);
  final ham = icerik['images'];
  // Tip denetimi gevşek: TMDB alanı hiç göndermeyebilir, eski önbellekten
  // gelen yanıtta bulunmayabilir — kapak galerisi süs veridir, sayfayı
  // düşürmesin.
  final gelen = ham is Map ? ham['backdrops'] : null;
  final arkalar =
      <Map<String, dynamic>>[
        for (final g in gelen is List ? gelen : const [])
          if (g is Map<String, dynamic>) g,
      ]..sort(
        (a, b) => ((b['vote_count'] as num?) ?? 0).compareTo(
          (a['vote_count'] as num?) ?? 0,
        ),
      );
  for (final g in arkalar) {
    if (yollar.length >= kapakTavani) break;
    final y = g['file_path'] as String?;
    if (y != null && y.isNotEmpty && !yollar.contains(y)) yollar.add(y);
  }
  return yollar;
}

/// ---------------------------------------------------------------------------
/// YAPIM BÜTÇESİ ROZETİ (21 Ağu 2026 isteği: "dizi ve filmlere harcanan
/// bütçeleri, yapım yılının yanında yazsın; sarı arka plan siyah yazı ile.
/// Bu bilgi tüm dizi ve filmlerde olmasına gerek yok").
///
/// YALNIZ FİLMLERDE — dizide alan HİÇ YOK, uydurulamaz.
/// Canlı önbellekte ölçüldü (21 Ağu 2026): 4.928 film satırının 3.370'inde
/// (%68,4) `budget > 0`; `budget` alanı BULUNAN dizi satırı sayısı 0. TMDB
/// dizi gövdesinde böyle bir alan yoktur. Bu yüzden dizide rozet aranmaz.
///
/// EK İSTEK YOK: `budget`, uygulamanın zaten çektiği `/tmdb/movie/:id`
/// yanıtının KÖK alanıdır (canlı doğrulama: /api/tmdb/movie/155 → 185000000).
/// Yeni uç, yeni sorgu, backend değişikliği gerekmez.
///
/// SIFIR = "BİLİNMİYOR", "bütçesiz" DEĞİL: TMDB doldurulmamış her yapımda 0
/// döndürür. "0 $" basmak YANLIŞ BİLGİ olurdu — rozet hiç çizilmez.
///
/// [butceAlt] eşiğin ta kendisi: bunun ALTINDA kalan tutar rozet üretmez.
/// Bugün 1, yani "0 ve negatif dışında her şey gösterilir" (istek birebir bu).
/// TMDB'de elle girilmiş `budget: 1` gibi çöp değerler de var; eşiği tek
/// yerden yükseltmek yeter — ama mikro bütçeli GERÇEK filmler ($7.000'lık
/// "El Mariachi", $15.000'lık "Paranormal Activity") de burada kaybolur,
/// o yüzden yükseltmek bilinçli bir karar olmalı.
///
/// AYNI EŞİK HASILATA DA UYGULANIR ([icerikHasilati]): `revenue: 0` da
/// "bilinmiyor" demektir, "hiç hasılat yapmadı" değil.
const butceAlt = 1;

/// TMDB gövdesinden gösterilebilir bütçe; yoksa `null`.
///
/// Tip denetimi gevşek (`num`): eski önbellek satırları alanı hiç
/// içermeyebilir, `double` da gelebilir. Süs veridir, sayfayı düşürmesin.
int? icerikButcesi(Map<String, dynamic> icerik) => _paraAlani(icerik, 'budget');

/// TMDB gövdesinden DÜNYA ÇAPINDA BRÜT HASILAT (`revenue`); yoksa `null`.
///
/// `budget` ile AYNI yerden gelir: `/tmdb/movie/:id` yanıtının KÖK alanı
/// (canlı doğrulama 21 Ağu 2026 — /api/tmdb/movie/27205 → budget 160000000,
/// revenue 839030630). EK İSTEK YOK, backend değişikliği yok.
///
/// BU SAYININ NE OLMADIĞI, ne olduğundan önemli:
///  * KÂR DEĞİL. Sinema hasılatının kabaca yarısı salonlarda kalır, pazarlama
///    bütçesi (çoğu blockbusterda yapım bütçesi kadar) `budget`e dâhil
///    değildir. "Hasılat > bütçe" bir filmin para kazandığını KANITLAMAZ.
///  * ENFLASYONA GÖRE DÜZELTİLMEMİŞ ve yapım yılının dolarıdır — `budget`
///    ile aynı disiplin (bkz. [butceMetni] madde 1).
///  * ESKİ FİLMLERDE SIK EKSİK. Canlı örnek: Nosferatu (1922) budget 0 /
///    revenue 27.964; M (1931) budget 0 / revenue 35.274.
///
/// Bu yüzden ekranda TÜRETİLMİŞ SAYI BASILMAZ: "kâr", "×5,2 katı", "%320"
/// gibi bir değer buradan çıkarılamaz, çıkarılırsa yanlış okunur. Rozet iki
/// HAM tutarı yan yana koyar ve yorumu okura bırakır.
int? icerikHasilati(Map<String, dynamic> icerik) =>
    _paraAlani(icerik, 'revenue');

/// [butceAlt] eşiğini ve gevşek tip denetimini iki alan için de tek yerde
/// uygular — bütçe ile hasılatın kuralı ayrışmasın diye ortak.
int? _paraAlani(Map<String, dynamic> icerik, String alan) {
  final ham = icerik[alan];
  if (ham is! num) return null;
  final tutar = ham.toInt();
  return tutar < butceAlt ? null : tutar;
}

/// Rozet metni: SEÇİLİ DİLE göre kısaltılmış DOLAR tutarı.
///
/// ÜÇ KARAR, üçü de bilinçli:
///
/// 1. PARA BİRİMİ DÖNÜŞTÜRÜLMEZ. TMDB bütçeleri USD'dir ve yapım yılının
///    dolarıdır. 1968 yapımı "2001"in 12 milyon dolarını bugünkü kurla TL'ye
///    çevirmek iki kez yanlış olurdu (58 yıllık enflasyon + bugünün kuru);
///    ortaya kimsenin doğrulayamayacağı bir sayı çıkardı. `$` gösterilir.
///
/// 2. KISALTILIR, ama ELDE DEĞİL. `$185.000.000` rozete sığmaz; `$185M` sığar.
///    Kısaltmayı elle yapıp `'{} milyon $'` gibi bir anahtar üretmedik:
///    o 45 çeviri + dile göre değişen ÖLÇEK demekti. Hintçe/Bengalce/Gucaratça
///    lakh–crore ile sayar (18,5 crore), Çince/Japonca/Korece 万–億 ile
///    (1,85 亿) — "milyon" o dillerde doğal bölüm bile değildir.
///    `NumberFormat.compactCurrency` CLDR verisini kullanır ve bunların
///    hepsini doğru yapar. YENİ ÇEVRİLEBİLİR DİZE ÜRETMEZ.
///
/// 3. YERELLEŞTİRME ücretsiz gelir: ondalık ayracı (1.2 / 1,2), `$`ın YERİ
///    (en "$185M", fr "185 M $"), yerel rakamlar (fa ۱۸۵, bn ১৮.৫) ve RTL
///    yön işaretleri CLDR'den. `sayiBicimle` ile aynı disiplin — o da
///    `NumberFormat...(Ceviri.dil.value)` kullanıyor (istatistiklerim.dart).
///
/// 45 dilin hepsinde çalıştığı ölçüldü; hiçbirinde istisna atmıyor.
String butceMetni(int tutar) => NumberFormat.compactCurrency(
  locale: Ceviri.dil.value,
  symbol: r'$',
).format(tutar);

/// Bütçe → hasılat rozetinin metni.
///
/// [hasilat] yoksa dünkü tek tutarlı hâlin TA KENDİSİ döner — biçim, eşik ve
/// yerelleştirme değişmez.
///
/// OKUN YÖNÜ METİN YÖNÜNDEN TÜRETİLİR. Arapça/İbranice/Farsça/Urduca'da
/// (45 dilin 4'ü) satır sağdan sola dizilir: mantıksal sıra yine
/// [butce] → [hasilat] olduğu için hasılat SOLDA görünür ve sabit bir "→"
/// oku yanlış yöne, yani hasılattan bütçeye bakardı. `←` ile ok hep
/// "bütçeden hasılata" okunur. Unicode'da kendiliğinden aynalanan bir ok
/// karakteri yok; bu yüzden seçim ELDE yapılır.
///
/// OKTAN SONRA BÖLÜNMEZ BOŞLUK (U+00A0): rozet dar ekranda iki satıra
/// düşerse kırılma OKTAN ÖNCE olsun ("160 Mn $" / "→ 839 Mn $"), ok tek
/// başına satır sonunda asılı kalmasın. Ok ile bütçe arasındaki NORMAL boşluk
/// bilinçli: rozetin tek meşru kırılma noktası orası.
///
/// TÜRETİLMİŞ SAYI YOK: kâr, kat, yüzde hesaplanmaz — gerekçesi
/// [icerikHasilati] belgesinde.
String paraRozetMetni(int butce, {int? hasilat, bool rtl = false}) {
  if (hasilat == null) return butceMetni(butce);
  // Ok ve bölünmez boşluk KAÇIŞ DİZİSİYLE yazılıyor: çıplak yazılsalardı
  // kaynağa bakan "buradaki boşluk normal mi bölünmez mi" sorusunu gözle
  // cevaplayamazdı (test dosyasındaki `_bb` sabiti aynı sebeple var).
  final ok = rtl ? '\u2190' : '\u2192';
  return '${butceMetni(butce)} $ok\u00a0${butceMetni(hasilat)}';
}

/// TMDB `status` → Türkçe çeviri ANAHTARI. Sıra ekranda görünmez, yalnız
/// okunurluk için TMDB'nin yaşam döngüsü sırasına göre dizildi.
///
/// DEĞERLER İNGİLİZCE VE DİLE GÖRE DEĞİŞMEZ (TMDB `status` alanı
/// `language=tr-TR` ile de İngilizce döner — canlı doğrulama 21 Ağu 2026:
/// /api/tmdb/tv/1396 → "Ended"). Bu yüzden sabit metinlerle eşleşme güvenli;
/// aynı disiplin [ekipRolleri]'ndeki `job` eşleşmesinde de var.
///
/// TÜRKÇE KARŞILIKLAR YENİ ANAHTARDIR ve BİLEREK var olan anahtarlardan
/// AYRI seçildi:
///  * 'Ended' için "Bitti" KULLANILAMAZ: bu anahtar zaten var (ortak.dart,
///    liste düzenleme kipini kapatan buton) ve İngilizcesi "Done". Dizi
///    durumunda "Done" yanlış olurdu. "Sona erdi" ayrıca kullanıcının kendi
///    izleme durumu olan "Bitirdim" çipiyle de karışmaz.
///  * "İptal edildi" ile "Sona erdi" AYRI tutulur: bir dizinin planlanan
///    sonuna varması ile yayından kaldırılması aynı şey değil (backend'in
///    SSS üreticisi de bu ikisini ayırıyor, server.js `SEO_BITMIS_DURUMLAR`).
const diziDurumMetinleri = <String, String>{
  'Planned': 'Planlandı',
  'Pilot': 'Pilot bölüm',
  'In Production': 'Yapımda',
  'Returning Series': 'Devam ediyor',
  'Ended': 'Sona erdi',
  'Canceled': 'İptal edildi',
  // TMDB tek "l" ile yazıyor; çift "l" İngiliz imlası ve veri girenlerin
  // elinden kaçabiliyor. Tek satırlık sigorta: yoksa rozet SESSİZCE kaybolur.
  'Cancelled': 'İptal edildi',
};

/// Dizi gövdesinden gösterilebilir durum ANAHTARI; tanımadığı her şeyde
/// `null` (→ rozet HİÇ çizilmez).
///
/// TANIMADIĞINI BASMAZ: TMDB yarın yeni bir durum değeri eklerse ekrana ham
/// İngilizce "Post Production" düşmesin. Bilinmeyen değer = veri yok.
String? diziDurumu(Map<String, dynamic> icerik) {
  final ham = icerik['status'];
  if (ham is! String) return null;
  return diziDurumMetinleri[ham.trim()];
}

/// Yapım yılının YANINDAKİ sarı rozetin ORTAK gövdesi.
///
/// NEDEN TEK BİLEŞEN: film (para) ve dizi (durum) rozeti AYNI görsel dili
/// konuşmak zorunda — aynı sarı, aynı yuvarlaklık, aynı iç boşluk, aynı yazı
/// ağırlığı. İki ayrı Container yazılsaydı biri gün gelip diğerinden
/// ayrışırdı ve bunu hiçbir test yakalayamazdı (ikisi de "sarı zemin siyah
/// yazı" sınavını tek başına geçer).
///
/// NEDEN "YilRozeti" adında TEK bir genel bileşen DEĞİL: film ile dizi
/// rozetinin VERİSİ ve KURALI ayrı (int + eşik ↔ String + sözlük), ipucu
/// metni ayrı, "hangi türde çizilir" kuralı ayrı. Tek bileşene indirgemek
/// bu kararları çağıran yere taşırdı; oysa "dizide para rozeti ASLA, filmde
/// durum rozeti ASLA" kuralının tek bir yerde ve sınanabilir durması işin
/// aslı. Bu yüzden: görsel kabuk ORTAK, anlam katmanı AYRI.
///
/// SARI ZEMİN + SİYAH YAZI kullanıcının açık isteği; projenin kuralıyla da
/// örtüşüyor ("sarı üstüne DAİMA siyah yazılır", tema.dart). Zemin
/// [DiziRenkler.sari] — marka sarısı iki temada da AYNI sabit; yazı
/// `Colors.black`, çünkü [DiziRenkler.siyah] tema-duyarlıdır ve AÇIK temada
/// kırık beyaza döner (sarı üstünde beyaz = 1,5:1, okunmaz). Aynı seçim
/// FilledButton temasında ve AI rozetinde de yapılıyor.
///
/// Rozet TIKLANABİLİR DEĞİL: hedefi yok, 44 px dokunma kuralı bağlamaz.
/// Tek başına "$185M" ya da "Sona erdi" ne olduğunu söylemediği için
/// [Tooltip] var — hem fareyle üstüne gelince hem de ekran okuyucuda okunur.
///
/// [kutuAnahtari] iç Container'a takılır (dışa değil): testler rozetin
/// GERÇEK dekorasyonunu ve yazı rengini ağaçtan okuyabilsin diye.
class SariRozet extends StatelessWidget {
  const SariRozet({
    required this.metin,
    required this.ipucu,
    this.kutuAnahtari,
    super.key,
  });

  final String metin;
  final String ipucu;
  final Key? kutuAnahtari;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: ipucu,
    child: Container(
      key: kutuAnahtari,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: DiziRenkler.sari,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        metin,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          height: 1.3,
        ),
      ),
    ),
  );
}

/// FİLM rozeti: yapım bütçesi ve — varsa — dünya çapında hasılat.
///
/// TEK ROZET, İKİ TUTAR (kullanıcı kararı, 21 Ağu 2026). Yan yana İKİ sarı
/// rozet denenmedi bile: aynı biçimdeki iki para tutarı hangisinin bütçe
/// hangisinin hasılat olduğunu SÖYLEMEZ. Ok, sırayı ve nedenselliği tek
/// görsel nesnede anlatır; ipucu metni de tek.
///
/// TEK TUTAR GÖRÜNÜYORSA O DAİMA BÜTÇEDİR — değişmez kural. Bu yüzden
/// hasılatı olup bütçesi olmayan filmde (Nosferatu 1922: budget 0,
/// revenue 27.964) rozet HİÇ çizilmez; "27.964 $" tek başına basılsaydı
/// okur onu bütçe sanardı ve bu, kaçınmak için tek rozete indiğimiz
/// belirsizliğin ta kendisi olurdu. [hasilat] yalnız okun HEDEFİ olarak
/// var olabilir.
class ButceRozeti extends StatelessWidget {
  const ButceRozeti({required this.tutar, this.hasilat, super.key});

  /// Yapım bütçesi. Rozetin var olma şartı; `null` olamaz.
  final int tutar;

  /// Dünya çapında brüt hasılat; `null` ise rozet dünkü tek tutarlı hâline
  /// düşer (ok da ipucunun ikinci yarısı da görünmez).
  final int? hasilat;

  @override
  Widget build(BuildContext context) => SariRozet(
    kutuAnahtari: const Key('butce-rozeti'),
    // İpucu iki tutarı SIRASIYLA adlandırır: ekran okuyucu "→" karakterini
    // yalnızca "sağ ok" diye okur, anlamı taşıyan cümle burada.
    //
    // ANAHTARIN İÇİNDE OK YOK — bilerek: 45 çevirmenin (ve makine
    // çevirisinin) elinden geçecek bir dizgede yön işareti ya düşer ya
    // aynalanır, RTL dillerde de metnin yönüyle çelişirdi.
    ipucu: hasilat == null
        ? 'Yapım bütçesi'.c
        : 'Yapım bütçesi ve dünya çapında hasılat'.c,
    metin: paraRozetMetni(
      tutar,
      hasilat: hasilat,
      rtl: Directionality.of(context) == TextDirection.rtl,
    ),
  );
}

/// DİZİ rozeti: yapımın yayın durumu.
///
/// NEDEN DİZİDE PARA DEĞİL DURUM: TMDB dizi gövdesinde bütçe/hasılat alanı
/// YOK (ölçüm: canlı önbellekte `budget` içeren dizi satırı 0) ve dünyada
/// bu veriyi derli toplu tutan bir kaynak da yok. Yılın yanındaki sarı yer
/// dizide boş kalıyordu; kullanıcı oraya durumu koymayı seçti — dizi
/// listesine bakan birinin ilk sorduğu şey ("hâlâ sürüyor mu, bitti mi")
/// zaten bu.
///
/// [durum] TÜRKÇE ANAHTARDIR, ham TMDB değeri değil: eşleme
/// [diziDurumu] ile ÇAĞIRAN yerde yapılır, tıpkı bütçedeki `null` denetimi
/// gibi — "rozet çizilsin mi" kararı tek bir yerde, `build` içinde durur.
class DiziDurumRozeti extends StatelessWidget {
  const DiziDurumRozeti({required this.durum, super.key});

  final String durum;

  @override
  Widget build(BuildContext context) => SariRozet(
    kutuAnahtari: const Key('durum-rozeti'),
    // "Sona erdi" tek başına neyin sona erdiğini söylemez; ayrıca sayfanın
    // altındaki KULLANICI durumu çipleriyle ("Bitirdim") karışmasın.
    ipucu: 'Dizinin yayın durumu'.c,
    metin: durum.c,
  );
}

/// ---------------------------------------------------------------------------
/// EKİP (madde 49): yönetmen / senarist / yapımcı — TIKLANABİLİR, `/kisi/:id`.
///
/// KAYNAK İKİ AYRI ALAN:
///  * `credits.crew` — `append_to_response=credits` ile ana yanıtla gelir
///    (ek istek YOK). Her satırda `job` alanı vardır.
///  * `created_by` — DİZİLERDE gövdenin kendi alanı. ZORUNLU: TMDB'de dizi
///    kredisi BÖLÜM bazlıdır; dizi düzeyindeki `crew` listesinde çoğu zaman
///    HİÇ "Director"/"Writer" yoktur (canlı ölçüm 13 Ağu 2026 — Breaking Bad
///    /tv/1396: 27 kişilik ekipte tek bir Director/Writer satırı yok, ama
///    `created_by` Vince Gilligan'ı veriyor). `created_by` olmasaydı dizilerde
///    bölüm ekrandaki en önemli ismi kaçırırdı.
///
/// TMDB `job` değerleri İNGİLİZCE ve dile göre değişmez (department/job
/// sözlüğü çevrilmez) — bu yüzden eşleştirme sabit metinlerle güvenli.
const ekipRolleri = <(String, List<String>)>[
  // Sıra = ekrandaki öncelik sırası. Bir kişi birden çok rolde geçerse kartı
  // İLK (en yüksek öncelikli) rolünün yerinde durur.
  ('Yaratıcı', <String>[]), // yalnız `created_by`
  ('Yönetmen', ['Director']),
  // "Screenplay" ve "Writer" TMDB'de aynı işin iki adı; "Story" konuyu yazan,
  // "Teleplay" dizi bölümünün senaryosu. Dördü de kullanıcı için "senarist".
  // "Novel"/"Author" KASITLA DIŞARIDA: uyarlanan kitabın yazarı senarist değil.
  ('Senaryo', ['Screenplay', 'Writer', 'Story', 'Teleplay']),
  // TMDB'de bir düzine yapımcı türevi var (Co-Executive, Associate, Line,
  // Coordinating...). Yalnız iki ANA unvan alınır; gerisi jenerik gürültüsü.
  ('Yapımcı', ['Producer', 'Executive Producer']),
];

/// Her rolün şeride koyabileceği EN FAZLA kişi.
///
/// NEDEN TAVAN VAR: yapım ekibi listeleri uçsuz. Canlı ölçüm (13 Ağu 2026):
/// Inception (/movie/27205) 736 kişilik ekip, bunun 4'ü "Producer" + 3'ü
/// "Executive Producer". Tavansız bırakılsaydı bölüm bir jenerik dökümüne
/// dönerdi ve asıl bilgi (yönetmen/senarist) yapımcı kalabalığında kaybolurdu.
///
/// Sayıların gerekçesi:
///  * Yaratıcı 4 — `created_by` neredeyse hiç 2-3'ü geçmez (Game of Thrones 2).
///  * Yönetmen 3 — filmde tipik olarak 1, kardeş/ikili yönetmenlerde 2;
///    3 kolektifleri de karşılar.
///  * Senaryo 4 — Screenplay + Writer + Story çoğu zaman AYNI 2-3 kişidir.
///  * Yapımcı 4 — bu bölümün "şişme" riski buradan gelir, en sıkı tavan burada.
///
/// Üst sınır 15 kart; yatay şeritte ~3 ekran genişliği, kaydırılabilir.
const ekipRolTavani = <String, int>{
  'Yaratıcı': 4,
  'Yönetmen': 3,
  'Senaryo': 4,
  'Yapımcı': 4,
};

/// Şeritteki tek ekip üyesi: kişi + o yapımda üstlendiği İŞLER.
class EkipUyesi {
  final int id;
  final String ad;
  final String? foto;

  /// Türkçe rol anahtarları ("Senaryo", "Yapımcı"). Ekranda `.c` ile çevrilip
  /// virgülle birleştirilir — aynı kişi iki kez listelenmez.
  final List<String> isler;

  EkipUyesi({
    required this.id,
    required this.ad,
    required this.foto,
    required this.isler,
  });
}

/// Detay yanıtından ekip şeridini üretir. TEKİLLEŞTİRİR: bir kişi hem
/// "Writer" hem "Producer" ise TEK kart alır, işleri birleşir ("Senaryo,
/// Yapımcı").
///
/// TAVAN MUHASEBESİ: zaten kartı olan kişi bir sonraki rolün tavanını
/// HARCAMAZ — yalnız etiketine o rol eklenir. Aksi hâlde senaryoyu da yazan
/// yapımcılar, kendilerinden başka yapımcı gösterilmesini engellerdi.
///
/// Alanlar EKSİK gelirse (TMDB'de `credits` ya da `created_by` olmayabilir,
/// eski önbellek yanıtında bulunmayabilir) boş liste döner → bölüm HİÇ
/// çizilmez, hata/boş kutu görünmez.
List<EkipUyesi> ekibiCikar(Map<String, dynamic> icerik) {
  final ham = icerik['credits'];
  final ekipHam = ham is Map ? ham['crew'] : null;
  final ekip = <Map<String, dynamic>>[
    for (final e in ekipHam is List ? ekipHam : const [])
      if (e is Map<String, dynamic>) e,
  ];
  final yaratanHam = icerik['created_by'];
  final yaratanlar = <Map<String, dynamic>>[
    for (final k in yaratanHam is List ? yaratanHam : const [])
      if (k is Map<String, dynamic>) k,
  ];

  // LinkedHashMap: ekleme sırası korunur → ekrandaki sıra rol önceliğidir.
  final sonuc = <int, EkipUyesi>{};
  for (final (rol, isler) in ekipRolleri) {
    final adaylar = isler.isEmpty
        ? yaratanlar
        : [
            for (final e in ekip)
              if (isler.contains(e['job'])) e,
          ];
    var eklenen = 0;
    for (final k in adaylar) {
      final id = (k['id'] as num?)?.toInt();
      final ad = (k['name'] as String?)?.trim();
      if (id == null || ad == null || ad.isEmpty) continue;
      final varOlan = sonuc[id];
      if (varOlan != null) {
        if (!varOlan.isler.contains(rol)) varOlan.isler.add(rol);
        continue; // tavanı harcamaz
      }
      if (eklenen >= (ekipRolTavani[rol] ?? 0)) continue;
      sonuc[id] = EkipUyesi(
        id: id,
        ad: ad,
        foto: k['profile_path'] as String?,
        isler: [rol],
      );
      eklenen++;
    }
  }
  return sonuc.values.toList();
}

/// Yapım firması şeridinde gösterilecek en fazla firma. TMDB'de tek filme
/// 20'den fazla ortak yapımcı iliştirilmiş örnekler var; şerit bir firma
/// rehberine dönüşmesin.
const firmaTavani = 10;

/// `production_companies` → tıklanabilir firma kayıtları.
///
/// SÜZGEÇ: `id` ve `name` OLMAYAN kayıt atılır — tıklanınca gidilecek bir
/// sayfası (ya da yazılacak bir adı) yoksa kartın anlamı yok. Aynı id iki kez
/// gelirse bir kez gösterilir.
List<Map<String, dynamic>> yapimFirmalari(Map<String, dynamic> icerik) {
  final ham = icerik['production_companies'];
  final sonuc = <int, Map<String, dynamic>>{};
  for (final f in ham is List ? ham : const []) {
    if (f is! Map<String, dynamic>) continue;
    final id = (f['id'] as num?)?.toInt();
    final ad = (f['name'] as String?)?.trim();
    if (id == null || ad == null || ad.isEmpty) continue;
    if (sonuc.length >= firmaTavani) break;
    sonuc.putIfAbsent(id, () => f);
  }
  return sonuc.values.toList();
}

/// İçerik sayfasındaki "İncelemeler" bölümü çizilsin mi.
///
/// 30 Ağu 2026'da KAPATILDI (kullanıcı: "şu an inceleme kısmı olmamalı, o
/// ileriki aşamada moderatörler için açık olacak"). Uç ve veri duruyor;
/// moderatör ekranı gelince bu bayrak `true` olacak.
@visibleForTesting
const bool incelemeBolumuAcik = false;

class DetayEkrani extends StatefulWidget {
  final int tmdbId;
  final String tur; // 'tv' | 'movie'

  const DetayEkrani({super.key, required this.tmdbId, required this.tur});

  @override
  State<DetayEkrani> createState() => _DetayEkraniState();
}

class _DetayEkraniState extends State<DetayEkrani>
    with OlcekDinler<DetayEkrani> {
  Map<String, dynamic>? _icerik;
  Map<String, dynamic>? _benim;
  Map<String, dynamic>? _incelemeler;
  Map<String, dynamic>? _izleyenler;

  /// Başlıktaki kapak görselleri; ilki yapımın ANA kapağıdır (backdrop_path).
  List<String> _kapaklar = const [];
  String? _hata;

  /// Detay ucuna eklenen alt kaynaklar. `images` LİSTEYE SONRADAN EKLENDİ:
  /// sunucu bu parametre verilmezse kendi varsayılanını koyar, verilirse
  /// olduğu gibi kullanır — bu yüzden liste sunucudakiyle birebir aynı
  /// olmalı, yoksa kadro/fragman gelmez.
  static const _ekVeri =
      'credits,videos,recommendations,external_ids,watch/providers,images';

  /// Görseller ayrı bir istekle DEĞİL ana veriyle birlikte gelir: sonradan
  /// gelseydi başlık tek kapakla çizilir, kaydırıcı ve sayaç sonradan belirirdi.
  /// `include_image_language=null` = YAZISIZ kapaklar (üstüne dizi adı basılmış
  /// afiş değil); TMDB ana kapağı da bunlardan seçer ve yük ~4 KB artar.
  String get _icerikYolu =>
      '/tmdb/${widget.tur}/${widget.tmdbId}'
      '?append_to_response=$_ekVeri&include_image_language=null'
      '&${tmdbVideoDilParametre()}';

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      // `/benim/...` girisZorunlu bir uçtur ve oturumsuzda 401 döner. Listeye
      // koşulsuz konsaydı Future.wait tümünü düşürür, aramadan gelen
      // ziyaretçi içerik yerine kırmızı hata ekranı görürdü. Diğer iki uç
      // (tmdb, incelemeler) oturum istemez.
      final sonuclar = await Future.wait([
        Api.get(_icerikYolu),
        Api.get('/incelemeler/${widget.tur}/${widget.tmdbId}'),
        if (Api.girisli) Api.get('/benim/${widget.tur}/${widget.tmdbId}'),
      ]);
      if (!mounted) return;
      setState(() {
        _icerik = sonuclar[0] as Map<String, dynamic>;
        _kapaklar = kapaklariCikar(_icerik!);
        _incelemeler = sonuclar[1] as Map<String, dynamic>;
        _benim = sonuclar.length > 2
            ? sonuclar[2] as Map<String, dynamic>
            : null;
      });
      // İzleyen sayısı sayfayı bloke etmesin: ayrı ve sessizce yüklenir
      Api.get('/izleyenler/${widget.tur}/${widget.tmdbId}')
          .then((d) {
            if (mounted) {
              setState(() => _izleyenler = d as Map<String, dynamic>);
            }
          })
          .catchError((_) {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
    }
  }

  /// Kapakların tam adresleri. w780 idi: 3x yoğunluklu telefonda bu alan ~1290
  /// fiziksel piksel, görsel büyütülüp gözle görülür bulanıklaşıyordu; tam
  /// ekranda daha da belliydi. w1280 tam oturuyor ("original" birkaç MB
  /// olabildiği için tercih edilmedi). Şeritte ve tam ekranda AYNI adres
  /// kullanılır: ikincisi zaten önbellekten gelir, yeniden indirilmez.
  List<String> get kapakUrlleri => [
    for (final y in _kapaklar) posterUrl(y, boyut: 'w1280')!,
  ];

  /// Görselin altını sayfanın zeminine bağlayan karartma.
  Widget get _karartma => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, DiziRenkler.siyah],
      ),
    ),
  );

  /// Kapak kaydırıcısı / tek görsel (fragman yokken kahraman bu).
  Widget _kapakZemini({required String? arka, required double sayacUstBosluk}) {
    if (_kapaklar.length > 1) {
      return AkisMedya(
        urller: kapakUrlleri,
        tumunuKapla: true,
        sayacUstBosluk: sayacUstBosluk,
        gorselUstu: _karartma,
        onAc: (i) => medyaGoster(context, kapakUrlleri, baslangic: i),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        if (arka != null)
          GestureDetector(
            onTap: () => medyaGoster(context, [arka]),
            child: CachedNetworkImage(
              imageUrl: arka,
              httpHeaders: gorselBasliklari(arka),
              fit: BoxFit.cover,
            ),
          )
        else
          Container(color: DiziRenkler.kart),
        IgnorePointer(child: _karartma),
      ],
    );
  }

  Future<void> _benimYenile() async {
    if (!Api.girisli) return; // uç 401 döner; oturumsuzda kişisel veri yok
    try {
      final b = await Api.get('/benim/${widget.tur}/${widget.tmdbId}');
      if (mounted) setState(() => _benim = b as Map<String, dynamic>);
    } catch (_) {}
  }

  /// Mutasyonu çalıştırır; hata olursa SnackBar gösterir.
  /// Oturumsuzda istek HİÇ atılmaz: 401 SnackBar'ı yerine giriş istemi çıkar.
  Future<void> _mutasyon(Future<void> Function() istek) async {
    if (!girisGerekli(context)) return;
    try {
      await istek();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
    _benimYenile();
  }

  /// Durum çipi. "İzleyeceğim"de sunucu izleme kaydı görürse 409 +
  /// `IZLEME_KAYDI_VAR` döner; o zaman onay alınıp istek `izlemeleri_sil: true`
  /// ile BİR KEZ tekrarlanır (bkz. [izlemeSilmeOnayi]).
  ///
  /// ELDEKİ `_benim['izlenenler']` ile ÖN KONTROL YAPILMAZ: sayı sunucudan
  /// gelirse başka cihazda az önce işaretlenen bölümler de doğru sayılır ve
  /// kural tek yerde (sunucuda) yaşar. İstemci burada yalnızca onay toplar.
  Future<void> _durumSec(String? durum) => _mutasyon(() async {
    var izlemeleriSil = false;
    while (true) {
      try {
        await Api.post('/durum', {
          'tmdb_id': widget.tmdbId,
          'tur': widget.tur,
          'durum': durum ?? '',
          if (izlemeleriSil) 'izlemeleri_sil': true,
        });
        break;
      } on ApiHata catch (h) {
        // Onaydan SONRA yine gelirse (olmamalı) SnackBar'a düşsün: sonsuz
        // döngüde kullanıcıya aynı diyaloğu tekrar tekrar sormayız.
        if (h.makineKodu != 'IZLEME_KAYDI_VAR' || izlemeleriSil) rethrow;
        if (!mounted) return;
        final onay = await izlemeSilmeOnayi(
          context,
          tur: widget.tur,
          adet: (h.govde?['izleme_sayisi'] as num?)?.toInt() ?? 0,
        );
        // Vazgeçti: durum DEĞİŞMEZ, izleme kayıtları DURUR, hata da gösterilmez.
        if (onay != true) return;
        izlemeleriSil = true;
      }
    }
    // Poster kartlarındaki "izledin" rozeti anında doğru olsun.
    KitaplikDurumu.isaretle(
      widget.tur,
      widget.tmdbId,
      durum == 'izliyorum' || durum == 'bitirdim' || durum == 'biraktim',
    );
    // Sunucu "izleyeceğim"de `tekrar`ı sıfırlar (bkz. POST /durum); rozetin
    // yanındaki "×2" burada da düşsün, yoksa "izleyeceğim ama 2 kez izledim"
    // çelişkisi poster kartında yaşamaya devam ederdi.
    if (durum == 'izleyecegim') {
      KitaplikDurumu.tekrarAyarla(widget.tur, widget.tmdbId, 0);
    }
  });

  /// Yeniden izleme sayacı (+1 / -1); yalnız "bitirdim" durumunda çalışır.
  Future<void> _rewatch(int deger) => _mutasyon(() async {
    final c = await Api.post('/rewatch', {
      'tmdb_id': widget.tmdbId,
      'tur': widget.tur,
      'deger': deger,
    });
    // Poster kartlarındaki göz rozetinin yanındaki sayı (×2) anında
    // güncellensin — sunucunun döndürdüğü değerle, iyimser tahminle DEĞİL.
    final t = c is Map ? (c['tekrar'] as num?)?.toInt() : null;
    if (t != null) KitaplikDurumu.tekrarAyarla(widget.tur, widget.tmdbId, t);
  });

  /// İzleyenler listesi: avatar + kullanıcı adı, dokununca profile gider.
  void _izleyenlerAc() {
    final liste = (_izleyenler?['kullanicilar'] as List<dynamic>? ?? []);
    if (liste.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DiziRenkler.koyuGri,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.visibility_outlined, color: DiziRenkler.sariMetin),
                  const SizedBox(width: 8),
                  Text(
                    'İzleyenler'.c,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_izleyenler?['sayi'] ?? liste.length}',
                    style: TextStyle(color: DiziRenkler.metin54),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: liste.length,
                itemBuilder: (context, i) {
                  final k = liste[i] as Map<String, dynamic>;
                  final av = dosyaUrl(k['avatar'] as String?);
                  final ad = k['kullanici_adi'] as String;
                  return ListTile(
                    leading: KullaniciAvatari(
                      url: av,
                      kullaniciAdi: ad,
                      arkaplan: DiziRenkler.kart,
                    ),
                    title: Text('@$ad'),
                    onTap: () {
                      // Dış context: kapanan modalın context'i ölür.
                      final dis = this.context;
                      Navigator.pop(context);
                      kullaniciyaGit(dis, ad);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _favoriToggle() => _mutasyon(
    () => Api.post('/favori/toggle', {
      'tmdb_id': widget.tmdbId,
      'tur': widget.tur,
    }),
  );

  /// Film "İzledim" düğmesi. Sunucu izleme kaydını yazar VE durumu
  /// "bitirdim" yapar (bkz. server.js filmDurumunuGuncelle) — poster
  /// kartlarındaki göz rozeti tek kaynaktan, `durumlar`dan okunur.
  /// Rozet cevabı BEKLEDİKTEN sonra güncellenir: istek başarısızsa
  /// (SnackBar) yanlış rozet yanıp sönmez, geri alma da gerekmez.
  Future<void> _filmIzlendiToggle() => _mutasyon(() async {
    final c = await Api.post('/izleme/toggle', {
      'tmdb_id': widget.tmdbId,
      'tur': 'movie',
      'sezon': 0,
      'bolum': 0,
    });
    KitaplikDurumu.isaretle(
      'movie',
      widget.tmdbId,
      (c is Map && c['izlendi'] == true),
    );
  });

  /// Yıldız şeridi puanı KAYDETTİKTEN sonra çağrılır (3 Eyl 2026).
  ///
  /// ESKİDEN: yıldıza dokunmak `puanlaVeKaydet` sheet'ini açıyordu — puan
  /// seçimi + "Yorum yaz..." kutusu + Kaydet. Kullanıcı: *"yıldıza tıklayınca
  /// yorum yaz açılmasın, puan verme kısmı olsun, sürüklemeli"*. Artık şerit
  /// SAYFANIN İÇİNDE duruyor, sürüklenerek puan veriliyor ve hiçbir modal
  /// açılmıyor. Yorum yazma kaybolmadı: sayfanın altındaki [YorumBolumu]
  /// zaten fotoğraf/video destekli tam bir yorum alanı.
  ///
  /// İKİ ŞEY TAZELENİR: `_benim` (kendi puanın — sayfaya geri gelince dolu
  /// yıldızları o besler) ve `_incelemeler` (topluluk ortalaması + dağılım;
  /// kendi oyun ortalamayı hemen değiştirir, eski değeri bırakmak kullanıcıya
  /// "kaydedilmedi" hissi verirdi).
  Future<void> _puanKaydedildi() async {
    _benimYenile();
    try {
      final inc = await Api.get('/incelemeler/${widget.tur}/${widget.tmdbId}');
      if (mounted) setState(() => _incelemeler = inc as Map<String, dynamic>);
    } catch (_) {}
  }

  /// Tüm izleme izlerini siler: hiç izlenmemiş sayılır + listelerden kalkar.
  Future<void> _sifirla() async {
    if (!girisGerekli(context)) return;
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DiziRenkler.koyuGri,
        title: Text('Sil'.c),
        content: Text(
          'Bu içerik hiç izlenmemiş olarak işaretlenecek ve listelerinden kaldırılacak.'
              .c,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal'.c),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sil'.c),
          ),
        ],
      ),
    );
    if (onay != true) return;
    try {
      await Api.post('/icerik/sifirla', {
        'tmdb_id': widget.tmdbId,
        'tur': widget.tur,
      });
      if (!mounted) return;
      _yukle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  /// Bu içeriği açık profilden gizler/gösterir (iyimser, hatada geri alınır).
  Future<void> _gizleToggle() async {
    if (!girisGerekli(context)) return;
    final eski = _benim?['gizli'] == true;
    setState(() => _benim?['gizli'] = !eski);
    try {
      await Api.post('/gizle', {
        'tmdb_id': widget.tmdbId,
        'tur': widget.tur,
        'gizli': !eski,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _benim?['gizli'] = eski);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _listeyeEkle() async {
    if (!girisGerekli(context)) return;
    try {
      final d = await Api.get('/listelerim');
      if (!mounted) return;
      final listeler = d['listeler'] as List<dynamic>;
      await showModalBottomSheet(
        context: context,
        backgroundColor: DiziRenkler.koyuGri,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Listeye Ekle'.c,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (listeler.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Henüz listen yok — Profil sekmesinden oluştur.'.c,
                  ),
                ),
              for (final l in listeler)
                ListTile(
                  leading: Icon(
                    Icons.playlist_add,
                    color: DiziRenkler.sariMetin,
                  ),
                  title: Text(l['ad'] as String),
                  subtitle: Text('{} içerik'.cf([l['oge_sayisi']])),
                  onTap: () async {
                    // Messenger'ı pop'tan ÖNCE al: modal kapanınca context ölür,
                    // onunla SnackBar aramak "deactivated widget" hatası verir.
                    final messenger = ScaffoldMessenger.of(context);
                    final sayfa = Navigator.of(context);
                    try {
                      await Api.post('/listeler/${l['id']}/oge', {
                        'tmdb_id': widget.tmdbId,
                        'tur': widget.tur,
                      });
                      sayfa.pop();
                      messenger.showSnackBar(
                        SnackBar(content: Text('Listeye eklendi'.c)),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hata != null) {
      return Scaffold(
        appBar: AppBar(),
        body: HataGorunumu(mesaj: _hata!, tekrar: _yukle),
      );
    }
    if (_icerik == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: DiziRenkler.sari)),
      );
    }

    final c = _icerik!;
    final tv = widget.tur == 'tv';
    final ad = (c['name'] ?? c['title'] ?? '?') as String;
    final yil = ((c['first_air_date'] ?? c['release_date'] ?? '') as String)
        .split('-')
        .first;
    // Yapım bütçesi (+ varsa hasılat) — YALNIZ FİLMDE. Dizide TMDB'nin böyle
    // bir alanı yok; `tv` dalında hiç bakılmaz ki eski/bozuk bir önbellek
    // satırı yanlışlıkla dizide rozet çıkarmasın.
    final butce = tv ? null : icerikButcesi(c);
    // Hasılat yalnız okun HEDEFİ: bütçe yoksa hiç kullanılmaz, çünkü tek
    // başına duran sarı tutar DAİMA bütçe demektir (bkz. [ButceRozeti]).
    final hasilat = butce == null ? null : icerikHasilati(c);
    // Yayın durumu — YALNIZ DİZİDE. Filmde de bir `status` alanı var
    // ("Released", "Post Production"...) ama sözlükte karşılığı yok; yine de
    // `tv` denetimi burada duruyor ki kural veriye değil TÜRE bağlı kalsın.
    final durum = tv ? diziDurumu(c) : null;
    // TÜRLER ARTIK METİN DEĞİL, TIKLANABİLİR (19 Ağu 2026 isteği: "türlere
    // tıklanabilsin, tıklayınca o türdeki dizileri listele"). `id`si olmayan
    // kayıt atılır: dokunulacak bir hedefi yok, çip çizmek yalan olurdu.
    final turler = ((c['genres'] as List<dynamic>?) ?? [])
        .whereType<Map<String, dynamic>>()
        .where(
          (g) => g['id'] is num && (g['name'] as String?)?.isNotEmpty == true,
        )
        .take(3)
        .toList();
    // w780 idi: 3x yoğunluklu telefonda bu alan ~1290 fiziksel piksel,
    // görsel büyütülüp gözle görülür bulanıklaşıyordu. w1280 tam oturuyor;
    // "original" birkaç MB olabildiği için tercih edilmedi.
    final arka = posterUrl(c['backdrop_path'] as String?, boyut: 'w1280');
    // Resmi fragmanlar (Trailer/Teaser) kapaklarla TEK kaydırıcıda karışır:
    // video, foto, video… Clip spoiler, seçilmez.
    final videolar = fragmanlariSec(c['videos'], dil: Ceviri.dil.value);
    final karisik = karisikKahramanDiz(videolar, kapakUrlleri);
    final kadro = ((c['credits']?['cast'] as List<dynamic>?) ?? []);
    // Md. 49 — ekip ve yapım firmaları. İkisi de EKSİK gelebilir (TMDB'de
    // olmayan alanlar); boş dönerse aşağıdaki bölümler hiç çizilmez.
    final ekip = ekibiCikar(c);
    final firmalar = yapimFirmalari(c);
    final oneriler =
        ((c['recommendations']?['results'] as List<dynamic>?) ?? []);
    final sezonlar = ((c['seasons'] as List<dynamic>?) ?? [])
        .where((s) => (s['season_number'] as int) > 0)
        .toList();
    // '$sezon:$bolum' → izlenme tarihi (ISO). Küme yerine HARİTA (27 Ağu
    // 2026, kullanıcı isteği): bölüm satırı artık "izledin mi" sorusunun
    // yanında "ne zaman" sorusunu da yanıtlıyor. `izlenenSet` aynı haritanın
    // anahtarlarından türetiliyor — tek kaynak, iki görünüm.
    // DEĞER NULL OLABİLİR, ANAHTAR HER ZAMAN VAR: anahtarlar "izlendi mi"
    // sorusunu (`izlenenSet`) besliyor, değer yalnız tarihi. Sunucu güvenilmeyen
    // tarihi null döndürüyor (içe aktarım damgası — bkz. /benim ucu); boş dizge
    // BURADA null'a çevrilmezse bölüm satırındaki `!= null` kontrolünden geçip
    // göz ikonunun yanına BOŞ bir tarih basılırdı.
    final izlenmeTarihleri = <String, String?>{
      for (final r in (_benim?['izlenenler'] as List<dynamic>? ?? []))
        '${r['sezon']}:${r['bolum']}': izlemeTarihiVeyaNull(r['tarih']),
    };
    final izlenenSet = izlenmeTarihleri.keys.toSet();
    // Dizide EN SON izlenen bölümün, filmde tek satırın tarihi (sunucu
    // hesaplıyor; kullanıcı kararı: bitirme tarihi değil son izleme).
    final sonIzleme = (_benim?['son_izleme'] ?? '').toString();
    final filmIzlendi = !tv && izlenenSet.contains('0:0');
    final favori = _benim?['favori'] == true;
    final benimDurum = _benim?['durum'] as String?;
    final tekrar = (_benim?['tekrar'] as int?) ?? 0; // yeniden izleme sayısı
    final benimPuan = _benim?['puan']?['puan'] as int?;
    // Gelecek bölüm: tarih belliyse kaç gün kaldığını göster
    final sonrakiTarih = tv
        ? ((c['next_episode_to_air'] as Map<String, dynamic>?)?['air_date']
              as String?)
        : null;
    int? kalanGun;
    if (sonrakiTarih != null) {
      final simdi = DateTime.now();
      kalanGun = DateTime.parse(
        sonrakiTarih,
      ).difference(DateTime(simdi.year, simdi.month, simdi.day)).inDays;
    }

    return Scaffold(
      // PC'de içerik tüm genişliğe yayılmasın: akış/Reels ile AYNI ortalanmış
      // okuma kolonu ([masaustuKolonGenisligi], tema.dart). Kullanıcı isteği
      // (madde 26): "genişliklerini akış ve reelsdeki gibi yap". Arka kapak
      // şeridi de bu kolona sığar; mobilde ([masaustuMu] false) kısıt hiç
      // bağlamaz, sayfa eskisi gibi tam genişlik kalır.
      body: OrtaKolon(
        azami: masaustuKolonGenisligi,
        cocuk: CustomScrollView(
          slivers: [
            // Fragman iframe webde platform görünümüdür: SliverAppBar'ın üstüne
            // binerse geri tuşu tıklanamaz. Video varsa çubuk örtmez; fragman
            // ve kapaklar AYNI 16:9 kaydırıcıda (video, foto, video…).
            if (videolar.isNotEmpty) ...[
              const SliverAppBar(pinned: true, actions: [GirisEylemi()]),
              SliverToBoxAdapter(
                child: KahramanKarisik(
                  ogeler: karisik,
                  onFotoAc: (url) {
                    final i = kapakUrlleri.indexOf(url);
                    medyaGoster(
                      context,
                      kapakUrlleri,
                      baslangic: i < 0 ? 0 : i,
                    );
                  },
                ),
              ),
            ] else
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                // Oturumsuz ziyaretçinin alt gezinme çubuğu yoktur (kabuk giriş
                // ister); bu buton olmasa sayfada çıkışsız kalırdı.
                actions: const [GirisEylemi()],
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.none,
                  background: _kapakZemini(
                    arka: arka,
                    sayacUstBosluk:
                        MediaQuery.paddingOf(context).top + kToolbarHeight,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // POSTER BAŞLIĞIN SOLUNDA (19 Ağu 2026 isteği).
                    //
                    // NEDEN KAPAĞA EK OLARAK: yukarıdaki kapak 16:9 bir
                    // SAHNE görselidir (backdrop) ve çoğu yapımda afişle
                    // hiç benzeşmez. Kullanıcı bir yapımı AFİŞİNDEN tanır;
                    // arama sonucunda, kitaplıkta, Keşfet'te hep o afişi
                    // görüyor. Başlığın yanında olmayınca sayfa "doğru
                    // yapıma mı geldim" sorusunu cevapsız bırakıyordu.
                    //
                    // Yükseklik posterin 2:3 oranından TÜRETİLİR; sabit
                    // sayı yazı tipi ölçeği büyüyen kullanıcıda taşardı.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AfisKucuk(yol: c['poster_path'] as String?, ad: ad),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ad,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // YIL SATIRI + BÜTÇE ROZETİ.
                              //
                              // `Row` DEĞİL `Wrap`: uzun yıl/sezon metni ve
                              // rozet dar telefonda ya da büyük yazı tipi
                              // ölçeğinde aynı satıra sığmayabilir. Row'da bu
                              // sarı taşma çizgisi demek; Wrap rozeti alt
                              // satıra indirir. (Bu sütun zaten `Expanded`
                              // içinde: solundaki afiş kadar daralabiliyor.)
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    [
                                      if (yil.isNotEmpty) yil,
                                      if (tv)
                                        '{} sezon'.cf([c['number_of_seasons']]),
                                    ].join(' · '),
                                    style: TextStyle(
                                      color: DiziRenkler.metin54,
                                    ),
                                  ),
                                  // Dizide `budget` alanı hiç yok → null →
                                  // rozet çizilmez. Filmde 0 gelirse de aynı:
                                  // 0 "bilinmiyor" demek, "sıfır" değil.
                                  //
                                  // İKİSİ AYNI ANDA ASLA ÇIKMAZ: `butce` yalnız
                                  // filmde, `durum` yalnız dizide dolar. Yılın
                                  // yanında hep EN FAZLA BİR sarı rozet durur —
                                  // iki tane olsaydı hangisinin ne olduğu
                                  // okunmazdı, tek rozete inmemizin sebebi de bu.
                                  if (butce != null)
                                    ButceRozeti(tutar: butce, hasilat: hasilat),
                                  if (durum != null)
                                    DiziDurumRozeti(durum: durum),
                                ],
                              ),
                              // FAVORİ + PUANLA YIL SATIRININ ALTINDA (3 Eyl
                              // 2026, kullanıcı: "favori ve yıldız vermeyi
                              // dizi ve filmlerde yapım yılı ve maliyetin
                              // altına al"). Eskiden aşağıdaki aksiyon
                              // satırındaydı (İzledim / Listeye ekle'nin
                              // yanında); afişin sağındaki boşluk boş
                              // kalıyordu ve kişisel iki eylem sayfanın
                              // ortasına gömülüydü.
                              //
                              // Dokunma hedefi 44 px korunur; ikon kutunun
                              // SOL kenarına yaslı ki başlık ve yılla aynı
                              // hizada dursun (varsayılan ortalama 10 px
                              // içeri iterdi).
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  IconButton(
                                    key: const Key('favori-dugmesi'),
                                    onPressed: _favoriToggle,
                                    tooltip: 'Favori'.c,
                                    padding: EdgeInsets.zero,
                                    alignment: Alignment.centerLeft,
                                    constraints: const BoxConstraints(
                                      minWidth: 44,
                                      minHeight: 44,
                                    ),
                                    icon: Icon(
                                      favori
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: favori
                                          ? Colors.redAccent
                                          : DiziRenkler.metin,
                                    ),
                                  ),
                                  // PUAN ŞERİDİ — MODAL YOK (3 Eyl 2026).
                                  //
                                  // Eskiden burada tek bir yıldız düğmesi
                                  // vardı ve dokununca puan + "Yorum yaz..."
                                  // sheet'i açılıyordu. Kullanıcı: *"yıldıza
                                  // tıklayınca yorum yaz açılmasın, yıldız
                                  // işareti yerine puan verme kısmı olsun,
                                  // sürüklemeli"*. Şerit sayfanın İÇİNDE:
                                  // dokun ya da parmağını üzerinde gezdir,
                                  // bırakınca kaydeder ([YildizPuan]).
                                  //
                                  // GERİ GELİNCE PUANIN GÖRÜNÜR: `benimPuan`
                                  // `/benim` ucundan gelir ve şeridin
                                  // başlangıç değeridir; dolu yıldızlar
                                  // kullanıcının KENDİ puanıdır (topluluk
                                  // ortalaması ayrı sarı rozette).
                                  //
                                  // Expanded: şerit afişin sağındaki sütunun
                                  // KALAN genişliğine sığar. [YildizPuan]
                                  // kendi LayoutBuilder'ıyla yıldızı o
                                  // genişliğe göre boyutlar; sığmayacak kadar
                                  // dar kalırsa rozet + kaydırıcı kipine
                                  // düşer (bkz. tepki.dart).
                                  Expanded(
                                    child: Tooltip(
                                      message: benimPuan != null
                                          ? 'Puanın'.c
                                          : 'Puanla'.c,
                                      child: YildizPuan(
                                        key: const Key('puanla-dugmesi'),
                                        tur: widget.tur,
                                        tmdbId: widget.tmdbId,
                                        baslangicPuan: benimPuan,
                                        // Yıldızların altında ufak "Puanla"
                                        // (puanlıyken "4/5"): düğme gidince
                                        // sözcük de gitmişti, şeridin ne işe
                                        // yaradığı yalnız ikondan okunuyordu.
                                        altYazi: true,
                                        kaydedildi: (_, _) => _puanKaydedildi(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // TÜR ÇİPLERİ AFİŞ SATIRININ DIŞINDA — 30 Ağu 2026,
                    // kullanıcı: *"filmin türleri alt alta dizilmiş ama
                    // sağında ve solunda boşluk var; mesela komedi drama yan
                    // yana, gerilim komedinin altında kalmış, yanında
                    // olabilirdi."*
                    //
                    // ÖLÇÜM (390 dp telefon, "Once Upon a Time in Hollywood"
                    // → Komedi · Drama · Gerilim):
                    //   · afişin sağındaki sütun 254 dp → çipler 109 + 96,5 +
                    //     121,5 = 327 dp yer istiyor, üçüncüsü ALT SATIRA
                    //     düşüyordu (blok 86 dp);
                    //   · sayfanın tam genişliği 358 dp → üçü TEK SATIRA
                    //     sığıyor (blok 40 dp).
                    // Yani boşluk gerçekten vardı, sadece çipler ona
                    // erişemiyordu. Afişin altı zaten boştu (başlık + yıl
                    // satırı afişten kısa), çipler oraya inince o boşluk da
                    // doldu.
                    if (turler.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      TurCipleri(turler: turler, tur: widget.tur),
                    ],
                    const SizedBox(height: 8),
                    if (tv && tmdbSezonNolari(c).isNotEmpty)
                      TmdbPuanHaritasi(
                        tmdbId: widget.tmdbId,
                        ortalama: ((c['vote_average'] as num?) ?? 0).toDouble(),
                        sezonNolari: tmdbSezonNolari(c),
                        yan: _puanSatiriYani(),
                      )
                    else
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 6,
                        children: [
                          const Icon(
                            Icons.star,
                            color: DiziRenkler.sari,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '{} TMDB'.cf([
                              ((c['vote_average'] as num?) ?? 0)
                                  .toStringAsFixed(1),
                            ]),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          ..._puanSatiriYani(),
                        ],
                      ),
                    // Sosyal kanıt: takip ettiklerin arasında kim izlemiş
                    if ((_izleyenler?['takip_sayi'] as num? ?? 0) > 0) ...[
                      const SizedBox(height: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _izleyenlerAc,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              // Takip edilen izleyenlerin üst üste binen avatarları
                              Builder(
                                builder: (context) {
                                  final takipliler =
                                      (_izleyenler?['kullanicilar']
                                                  as List<dynamic>? ??
                                              [])
                                          .where(
                                            (k) => k['takip_ediyorum'] == true,
                                          )
                                          .take(4)
                                          .toList();
                                  if (takipliler.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return SizedBox(
                                    width: 24.0 + (takipliler.length - 1) * 16,
                                    height: 28,
                                    child: Stack(
                                      children: [
                                        for (
                                          var i = 0;
                                          i < takipliler.length;
                                          i++
                                        )
                                          Positioned(
                                            left: i * 16.0,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: DiziRenkler.siyah,
                                                  width: 2,
                                                ),
                                              ),
                                              child: CircleAvatar(
                                                radius: 12,
                                                backgroundColor:
                                                    DiziRenkler.koyuGri,
                                                backgroundImage:
                                                    dosyaUrl(
                                                          takipliler[i]['avatar']
                                                              as String?,
                                                        ) !=
                                                        null
                                                    ? NetworkImage(
                                                        dosyaUrl(
                                                          takipliler[i]['avatar']
                                                              as String?,
                                                        )!,
                                                      )
                                                    : null,
                                                child:
                                                    takipliler[i]['avatar'] ==
                                                        null
                                                    ? Icon(
                                                        Icons.person,
                                                        size: 13,
                                                        color:
                                                            DiziRenkler.metin38,
                                                      )
                                                    : null,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Takip ettiğin {} kişi izledi'.cf([
                                    (_izleyenler?['takip_sayi'] as num).toInt(),
                                  ]),
                                  style: TextStyle(
                                    color: DiziRenkler.metin70,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: DiziRenkler.metin38,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    // Durum çipleri: dar ekranda sağa taşmak yerine alt satıra sarar
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (kod, etiket, ikon) in durumSecenekleri)
                          FilterChip(
                            avatar: Icon(
                              ikon,
                              size: 16,
                              color: benimDurum == kod
                                  ? Colors.black
                                  : DiziRenkler.metin70,
                            ),
                            label: Text(
                              etiket.c,
                              style: TextStyle(
                                color: benimDurum == kod
                                    ? Colors.black
                                    : DiziRenkler.metin,
                              ),
                            ),
                            selected: benimDurum == kod,
                            onSelected: (s) => _durumSec(s ? kod : null),
                          ),
                        // Profilimde gizle: içerik açık profilde ve izleyenler
                        // listesinde görünmez (durum/izleme varsa anlamlı)
                        if (benimDurum != null || izlenenSet.isNotEmpty)
                          FilterChip(
                            avatar: Icon(
                              Icons.visibility_off_outlined,
                              size: 16,
                              color: _benim?['gizli'] == true
                                  ? Colors.black
                                  : DiziRenkler.metin70,
                            ),
                            label: Text(
                              'Profilimde gizle'.c,
                              style: TextStyle(
                                color: _benim?['gizli'] == true
                                    ? Colors.black
                                    : DiziRenkler.metin,
                              ),
                            ),
                            selected: _benim?['gizli'] == true,
                            onSelected: (_) => _gizleToggle(),
                          ),
                        // Sil: tüm izleme izini kaldırır (uyarılı)
                        if (benimDurum != null || izlenenSet.isNotEmpty)
                          ActionChip(
                            avatar: const Icon(
                              Icons.delete_outline,
                              size: 16,
                              color: Colors.redAccent,
                            ),
                            label: Text(
                              'Sil'.c,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                            onPressed: _sifirla,
                          ),
                      ],
                    ),
                    // ---- İZLEME TARİHİ (27 Ağu 2026, kullanıcı isteği) ----
                    // Filmde "12 Ağustos 2026'da izledin", dizide "Son izleme:
                    // 12 Ağustos 2026". Dizide BİTİRME tarihi değil SON İZLEME
                    // gösteriliyor (kullanıcı kararı): izlemeye devam edende de
                    // anlamlı olan tek tarih budur, bitirme yalnız bir durumda
                    // vardır.
                    //
                    // Yıl DAİMA yazılır (`hepYil`): bu tek satırlık özet
                    // arşiv bilgisidir, "14 Ağustos" tek başına hangi yıl
                    // olduğunu söylemezdi.
                    if (sonIzleme.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.event_available_outlined,
                            size: 16,
                            color: DiziRenkler.sariMetin,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              tv
                                  ? 'Son izleme: {}'.cf([
                                      tarihBicimle(sonIzleme, hepYil: true),
                                    ])
                                  : '{} tarihinde izledin'.cf([
                                      tarihBicimle(sonIzleme, hepYil: true),
                                    ]),
                              style: TextStyle(
                                color: DiziRenkler.metin70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Yeniden izleme (yalnız "bitirdim" durumunda): Letterboxd tarzı
                    if (benimDurum == 'bitirdim') ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ActionChip(
                            avatar: Icon(
                              Icons.replay,
                              size: 16,
                              color: DiziRenkler.sariMetin,
                            ),
                            label: Text('Yeniden izledim'.c),
                            onPressed: () => _rewatch(1),
                          ),
                          if (tekrar > 0) ...[
                            const SizedBox(width: 10),
                            Text(
                              // tekrar=1 → toplam 2. izleme
                              '{}. kez izlendi'.cf([tekrar + 1]),
                              style: TextStyle(
                                color: DiziRenkler.metin54,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            // Geri alma. İkon 16 px kalır ama dokunma hedefi
                            // 44 px'e çıkar (16 + 2×14) — ikonu büyütmeden
                            // padding'le, UX kuralı gereği. Tooltip/Semantics
                            // olmadan ikon tek başına ne yaptığını söylemiyordu.
                            Tooltip(
                              message: 'Geri al'.c,
                              child: InkWell(
                                onTap: () => _rewatch(-1),
                                borderRadius: BorderRadius.circular(22),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Icon(
                                    Icons.remove_circle_outline,
                                    size: 16,
                                    color: DiziRenkler.metin38,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    // Gelecek bölüm geri sayımı
                    if (kalanGun != null && kalanGun >= 0) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 16,
                            color: DiziRenkler.sariMetin,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            kalanGun == 0
                                ? 'Gelecek bölüm bugün'.c
                                : 'Gelecek bölüm {} gün sonra'.cf([kalanGun]),
                            style: TextStyle(
                              color: DiziRenkler.sariMetin,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            sonrakiTarih!,
                            style: TextStyle(
                              color: DiziRenkler.metin38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    // Aksiyon satırı
                    Row(
                      children: [
                        if (!tv)
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _filmIzlendiToggle,
                              style: filmIzlendi
                                  ? FilledButton.styleFrom(
                                      backgroundColor: DiziRenkler.kart,
                                      foregroundColor: DiziRenkler.sariMetin,
                                    )
                                  : null,
                              icon: Icon(
                                filmIzlendi
                                    ? Icons.check_circle
                                    : Icons.visibility,
                              ),
                              label: Text(
                                filmIzlendi ? 'İzledin'.c : 'İzledim'.c,
                              ),
                            ),
                          ),
                        if (!tv) const SizedBox(width: 8),
                        // Favori ve Puanla artık yıl satırının altında
                        // (yukarıda). Dizide bu satırda yalnız "Listeye
                        // ekle" kalıyor; tek başına duran 24 px'lik ikon
                        // satırı yarım bırakılmış görünürdü → dizide
                        // etiketli, tam genişlikte düğme; filmde İzledim'in
                        // yanında ikon olarak kalır.
                        if (tv)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _listeyeEkle,
                              icon: const Icon(Icons.playlist_add),
                              label: Text('Listeye ekle'.c),
                            ),
                          )
                        else
                          IconButton(
                            onPressed: _listeyeEkle,
                            tooltip: 'Listeye ekle'.c,
                            icon: Icon(
                              Icons.playlist_add,
                              color: DiziRenkler.metin,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Tepki ikonları
                    TepkiSatiri(tur: widget.tur, tmdbId: widget.tmdbId),
                    const SizedBox(height: 12),
                    if ((c['overview'] as String?)?.isNotEmpty == true)
                      Text(
                        c['overview'] as String,
                        style: const TextStyle(height: 1.5),
                      ),
                  ],
                ),
              ),
            ),
            // Nerede izlenir (TMDB / JustWatch)
            SliverToBoxAdapter(
              child: _NeredeIzlenir(saglayicilar: c['watch/providers']),
            ),
            // Sezonlar (dizi)
            if (tv)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        'Sezonlar'.c,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    for (final s in sezonlar)
                      _SezonSatiri(
                        tmdbId: widget.tmdbId,
                        sezon: s as Map<String, dynamic>,
                        izlenenSet: izlenenSet,
                        izlenmeTarihleri: izlenmeTarihleri,
                        degisti: _benimYenile,
                      ),
                  ],
                ),
              ),
            // Oyuncular
            if (kadro.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Başlık tıklanabilir: yatay şerit yalnız ilk 20 kişiyi
                    // gösteriyor, dokununca TÜM kadro listelenir.
                    SeritBasligi(
                      baslik: 'Oyuncular'.c,
                      ek: '(${kadro.length})',
                      onTap: () => tumOyuncularAc(context, kadro),
                    ),
                    SizedBox(
                      height: 150,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: kadro.length.clamp(0, 20),
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final o = kadro[i] as Map<String, dynamic>;
                          final foto = posterUrl(
                            o['profile_path'] as String?,
                            boyut: 'w185',
                          );
                          return InkWell(
                            onTap: () => context.push('/kisi/${o['id']}'),
                            child: SizedBox(
                              width: 76,
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 34,
                                    backgroundColor: DiziRenkler.kart,
                                    backgroundImage: foto == null
                                        ? null
                                        : CachedNetworkImageProvider(
                                            foto,
                                            headers: gorselBasliklari(foto),
                                          ),
                                    child: foto == null
                                        ? Icon(
                                            Icons.person,
                                            color: DiziRenkler.metin24,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    o['name'] as String? ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            // Yapım ekibi (md. 49) — yönetmen/senarist/yapımcı, tıklanabilir.
            // Kadro şeridiyle AYNI kart kalıbı: yeni bir tasarım dili yok,
            // tek fark adın altındaki iş satırı.
            if (ekip.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // "Tümünü gör" YOK: liste zaten tavanlı ve kısa
                    // ([ekipRolTavani]), açılacak ikinci bir ekran olmazdı.
                    SeritBasligi(baslik: 'Yapım Ekibi'.c),
                    SizedBox(
                      // Kadro şeridi 150: 68 (avatar) + 6 + 2 satır ad.
                      // Burada bir de iş satırı var (2 satıra kadar) → 164.
                      // Ölçülen içerik ~127 dp; kalan pay yazı ölçeği
                      // büyütülmüş cihazlar için.
                      height: 164,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: ekip.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final u = ekip[i];
                          final foto = posterUrl(u.foto, boyut: 'w185');
                          return InkWell(
                            // Kart 76x~127 dp — 44 dp dokunma asgarisinin
                            // çok üstünde.
                            onTap: () => context.push('/kisi/${u.id}'),
                            child: SizedBox(
                              width: 76,
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 34,
                                    backgroundColor: DiziRenkler.kart,
                                    backgroundImage: foto == null
                                        ? null
                                        : CachedNetworkImageProvider(
                                            foto,
                                            headers: gorselBasliklari(foto),
                                          ),
                                    child: foto == null
                                        ? Icon(
                                            Icons.person,
                                            color: DiziRenkler.metin24,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    u.ad,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    // Tekilleştirilmiş işler: "Senaryo, Yapımcı"
                                    u.isler.map((i) => i.c).join(', '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: DiziRenkler.metin54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            // Yapım firmaları (md. 49) — dokununca firma sayfası açılır.
            if (firmalar.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SeritBasligi(baslik: 'Yapım Firmaları'.c),
                    SizedBox(
                      // 56 (logo) + 6 + 2 satır ad (~26) = 88; pay bırakıldı.
                      height: 108,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: firmalar.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final f = firmalar[i];
                          final ad = f['name'] as String;
                          return InkWell(
                            // Kart 112x~88 dp — dokunma asgarisinin üstünde.
                            onTap: () => context.push(
                              sirketYolu(
                                (f['id'] as num).toInt(),
                                ad: ad,
                                tur: widget.tur,
                              ),
                            ),
                            child: SizedBox(
                              width: 112,
                              child: Column(
                                children: [
                                  FirmaLogosu(
                                    logoYolu: f['logo_path'] as String?,
                                    genislik: 112,
                                    yukseklik: 56,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    ad,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            // İNCELEMELER BÖLÜMÜ KAPALI (30 Ağu 2026, kullanıcı kararı:
            // "şu an inceleme kısmı olmamalı, o ileriki aşamada moderatörler
            // için açık olacak").
            //
            // NEDEN SİLMEDİM, BAYRAKLA KAPATTIM: bölüm ileride moderatör
            // ekranı olarak GERİ AÇILACAK. Silseydim aynı kod yeniden
            // yazılırdı; bayrak `true` yapılınca eski davranış birebir döner.
            //
            // VERİ DE SİLİNMEDİ: `puanlar.yorum`daki mevcut incelemeler
            // yerinde duruyor ve `/incelemeler` ucu hâlâ çalışıyor —
            // yalnız BURADA çizilmiyor. Puan sheet'i artık yeni metni
            // oraya değil `/yorumlar`a yazıyor (bkz. puan_sheet.dart).
            if (incelemeBolumuAcik &&
                (_incelemeler?['incelemeler'] as List<dynamic>? ?? [])
                    .isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        'İncelemeler'.c,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    for (final inc
                        in (_incelemeler!['incelemeler'] as List<dynamic>).take(
                          10,
                        ))
                      Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () => kullaniciyaGit(
                                      context,
                                      inc['kullanici_adi'] as String,
                                    ),
                                    child: Text(
                                      '@${inc['kullanici_adi']}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: DiziRenkler.sariMetin,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(
                                    Icons.star,
                                    color: DiziRenkler.sari,
                                    size: 14,
                                  ),
                                  Text(
                                    ' ${yildiza(inc['puan'])}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                inc['yorum'] as String,
                                style: const TextStyle(height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            // Yorumlar (fotoğraf/video destekli)
            SliverToBoxAdapter(
              child: YorumBolumu(tur: widget.tur, tmdbId: widget.tmdbId),
            ),
            // Öneriler
            if (oneriler.isNotEmpty)
              SliverToBoxAdapter(
                child: PosterSeridi(
                  baslik: 'Bunları da Beğenebilirsin'.c,
                  icerikler: oneriler,
                  turZorla: widget.tur,
                ),
              ),
            SliverToBoxAdapter(
              child: SizedBox(height: altGuvenli(context, ekstra: 32)),
            ),
          ],
        ),
      ),
    );
  }

  /// TMDB yazısının sağındaki rozetler (dizi.jpg dağılımı + izleyen sayısı).
  List<Widget> _puanSatiriYani() => [
    if (_incelemeler?['ortalama'] != null) ...[
      const SizedBox(width: 12),
      InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => puanDagilimiAc(
          context,
          dagilim: _incelemeler?['dagilim'],
          ortalama: _incelemeler?['ortalama'],
          benimDbPuani: _benim?['puan']?['puan'] as int?,
        ),
        child: SizedBox(
          height: dokunmaHedefi,
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: DiziRenkler.sari,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '{} dizi.jpg'.cf([
                      yildizOrtalamaMetni(_incelemeler!['ortalama']),
                    ]),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.bar_chart, size: 13, color: Colors.black),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
    if ((_izleyenler?['sayi'] as num? ?? 0) > 0) ...[
      const SizedBox(width: 12),
      InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _izleyenlerAc,
        child: SizedBox(
          height: dokunmaHedefi,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.visibility_outlined,
                  size: 18,
                  color: DiziRenkler.metin70,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_izleyenler!['sayi']}',
                  style: TextStyle(
                    color: DiziRenkler.metin70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  ];
}

/// Tıklayınca yeni sayfa açmaz; kartın altında bölüm listesi açılır.
/// Bölüme tıklamak bölüm sayfasını açar, sağdaki halka izleme işaretidir.
class _SezonSatiri extends StatefulWidget {
  final int tmdbId;
  final Map<String, dynamic> sezon;
  final Set<String> izlenenSet;

  /// '$sezon:$bolum' → izlenme tarihi (ISO). Bölüm satırı bunu gösterir.
  final Map<String, String?> izlenmeTarihleri;
  final VoidCallback degisti;

  const _SezonSatiri({
    required this.tmdbId,
    required this.sezon,
    required this.izlenenSet,
    required this.izlenmeTarihleri,
    required this.degisti,
  });

  @override
  State<_SezonSatiri> createState() => _SezonSatiriState();
}

class _SezonSatiriState extends State<_SezonSatiri> {
  bool _acik = false;
  List<dynamic>? _bolumler;
  String? _hata;

  int get _no => widget.sezon['season_number'] as int;

  Future<void> _bolumleriYukle() async {
    setState(() => _hata = null);
    try {
      final d = await Api.get('/tmdb/tv/${widget.tmdbId}/season/$_no');
      if (mounted) {
        setState(() => _bolumler = d['episodes'] as List<dynamic>);
      }
    } catch (e) {
      if (mounted) setState(() => _hata = e.toString());
    }
  }

  Future<void> _toggle(int bolumNo) async {
    if (!girisGerekli(context)) return;
    try {
      final c = await Api.post('/izleme/toggle', {
        'tmdb_id': widget.tmdbId,
        'tur': 'tv',
        'sezon': _no,
        'bolum': bolumNo,
      });
      // Bölüm işaretlendiyse sunucu diziyi izliyorum/bitirdim yapar → poster
      // rozeti anında çıksın. Kaldırmada rozet BIRAKILIR: başka bölümler hâlâ
      // izlenmiş olabilir, sunucuya sormadan silmek yanlış olurdu.
      if (c is Map && c['izlendi'] == true) {
        KitaplikDurumu.isaretle('tv', widget.tmdbId, true);
      }
      widget.degisti();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _tumu(bool isaretle, int toplam) async {
    if (!girisGerekli(context)) return;
    try {
      await Api.post('/izleme/sezon', {
        'tmdb_id': widget.tmdbId,
        'sezon': _no,
        'bolum_sayisi': toplam,
        'isaretle': isaretle,
      });
      if (isaretle) KitaplikDurumu.isaretle('tv', widget.tmdbId, true);
      widget.degisti();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final toplam = (widget.sezon['episode_count'] as int?) ?? 0;
    final izlenen = widget.izlenenSet
        .where((k) => k.startsWith('$_no:'))
        .length
        .clamp(0, toplam);
    final tamam = toplam > 0 && izlenen >= toplam;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: toplam == 0 ? 0 : izlenen / toplam,
                    strokeWidth: 4,
                    color: DiziRenkler.sari,
                    backgroundColor: DiziRenkler.metin12,
                  ),
                  Text(
                    '$_no',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            title: Text(
              widget.sezon['name'] as String? ?? '{}. Sezon'.cf([_no]),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('{} / {} bölüm'.cf([izlenen, toplam])),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tamam)
                  Icon(Icons.check_circle, color: DiziRenkler.sariMetin),
                Icon(
                  _acik ? Icons.expand_less : Icons.expand_more,
                  color: DiziRenkler.metin38,
                ),
              ],
            ),
            onTap: () {
              setState(() => _acik = !_acik);
              if (_acik && _bolumler == null) _bolumleriYukle();
            },
          ),
          if (_acik) ...[
            if (_hata != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(_hata!, style: TextStyle(color: DiziRenkler.metin54)),
                    TextButton(
                      onPressed: _bolumleriYukle,
                      child: Text('Tekrar dene'.c),
                    ),
                  ],
                ),
              )
            else if (_bolumler == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(color: DiziRenkler.sari),
                ),
              )
            else ...[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _tumu(!tamam, toplam),
                  icon: Icon(
                    tamam ? Icons.remove_done : Icons.done_all,
                    size: 18,
                    color: DiziRenkler.sariMetin,
                  ),
                  label: Text(
                    tamam ? 'Tümünü Kaldır'.c : 'Tümünü İzledim'.c,
                    style: TextStyle(
                      color: DiziRenkler.sariMetin,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              for (final b in _bolumler!)
                _BolumSatiri(
                  tmdbId: widget.tmdbId,
                  sezonNo: _no,
                  bolum: b as Map<String, dynamic>,
                  izlendi: widget.izlenenSet.contains(
                    '$_no:${b['episode_number']}',
                  ),
                  izlenmeTarihi:
                      widget.izlenmeTarihleri['$_no:${b['episode_number']}'],
                  izlendiToggle: () => _toggle(b['episode_number'] as int),
                  degisti: widget.degisti,
                ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _BolumSatiri extends StatelessWidget {
  final int tmdbId;
  final int sezonNo;
  final Map<String, dynamic> bolum;
  final bool izlendi;

  /// Bu bölümü NE ZAMAN izledin (ISO). İzlenmemişse null.
  final String? izlenmeTarihi;
  final VoidCallback izlendiToggle;
  final VoidCallback degisti;

  const _BolumSatiri({
    required this.tmdbId,
    required this.sezonNo,
    required this.bolum,
    required this.izlendi,
    required this.izlenmeTarihi,
    required this.izlendiToggle,
    required this.degisti,
  });

  @override
  Widget build(BuildContext context) {
    final no = bolum['episode_number'] as int;
    final gorsel = posterUrl(bolum['still_path'] as String?, boyut: 'w300');
    final yayin = bolum['air_date'] as String? ?? '';

    return InkWell(
      onTap: () async {
        await context.push(
          '/dizi/$tmdbId/sezon/$sezonNo/bolum/$no',
          extra: izlendi,
        );
        degisti();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 88,
                height: 50,
                child: gorsel == null
                    ? Container(
                        color: DiziRenkler.koyuGri,
                        child: Icon(Icons.tv, color: DiziRenkler.metin24),
                      )
                    : CachedNetworkImage(
                        imageUrl: gorsel,
                        httpHeaders: gorselBasliklari(gorsel),
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$no. ${bolum['name'] ?? 'Bölüm'.c}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  // ALT SATIR: yayın tarihi · izlenme tarihi.
                  //
                  // İKİSİ AYNI SATIRDA AMA AYRIŞIYOR: yayın tarihi soluk ve
                  // düz, izlenme tarihi göz ikonuyla ve sarı. Kullanıcı
                  // "bölüm ne zaman yayınlandı" ile "ben ne zaman izledim"i
                  // karıştırmasın — ikisi de tarihtir, ayırt edici işaret
                  // ikondur (renk TEK BAŞINA ayırt edici sayılmaz).
                  //
                  // TARİHLER SAYISAL (28 Ağu 2026, kullanıcı isteği: "orada ay
                  // ismi kullanma sayı kullan, sadece ikisi için de"). Satır
                  // DAR ve İKİ tarih yan yana; "20 Ocak 2008" satırın yarısını
                  // yiyordu. Ay adı YALNIZ BURADA sayıya çevrildi —
                  // `tarihBicimle` öteki yerlerde (detaydaki "Son izleme",
                  // istatistikler…) aynen duruyor. Ham ISO'ya da DÖNÜLMEDİ:
                  // "2008-01-20" makine çıktısı gibi durur.
                  if (yayin.isNotEmpty || izlenmeTarihi != null)
                    Row(
                      children: [
                        if (yayin.isNotEmpty)
                          Flexible(
                            child: Text(
                              tarihSayi(yayin, hepYil: true),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: DiziRenkler.metin38,
                              ),
                            ),
                          ),
                        if (izlenmeTarihi != null &&
                            izlenmeTarihi!.isNotEmpty) ...[
                          if (yayin.isNotEmpty)
                            Text(
                              '  ·  ',
                              style: TextStyle(
                                fontSize: 11,
                                color: DiziRenkler.metin24,
                              ),
                            ),
                          Icon(
                            Icons.visibility_outlined,
                            size: 11,
                            color: DiziRenkler.sariMetin,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              // Yıl yok: bölüm listesi uzun, satır dar ve
                              // "bu yıl" zaten baskın durum. Geçmiş yıllarda
                              // `tarihSayi` yılı kendisi ekler.
                              tarihSayi(izlenmeTarihi),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: DiziRenkler.sariMetin,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: izlendiToggle,
              icon: Icon(
                izlendi ? Icons.check_circle : Icons.radio_button_unchecked,
                color: izlendi ? DiziRenkler.sariMetin : DiziRenkler.metin,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// TMDB "watch/providers" verisinden içeriğin hangi platformlarda
/// (abonelik/kirala/satın al) olduğunu bölgeye göre gösterir.
class _NeredeIzlenir extends StatelessWidget {
  final dynamic saglayicilar; // c['watch/providers']
  const _NeredeIzlenir({required this.saglayicilar});

  /// Uygulama diline göre öncelikli bölge (ISO ülke kodu).
  static const _bolgeler = {
    'tr': 'TR',
    'en': 'US',
    'zh': 'CN',
    'hi': 'IN',
    'es': 'ES',
    'fr': 'FR',
    'ar': 'SA',
    'bn': 'BD',
    'pt': 'BR',
    'ru': 'RU',
    'ur': 'PK',
    'id': 'ID',
    'de': 'DE',
    'ja': 'JP',
    'sw': 'TZ',
    'mr': 'IN',
    'te': 'IN',
    'vi': 'VN',
    'ko': 'KR',
    'ta': 'IN',
    'it': 'IT',
    'fa': 'IR',
    'pl': 'PL',
    'uk': 'UA',
    'ro': 'RO',
    'nl': 'NL',
    'th': 'TH',
    'gu': 'IN',
    'kn': 'IN',
    'ml': 'IN',
    'pa': 'IN',
    'ms': 'MY',
    'my': 'MM',
    'am': 'ET',
    'az': 'AZ',
    'el': 'GR',
    'hu': 'HU',
    'cs': 'CZ',
    'sv': 'SE',
    'he': 'IL',
    'fil': 'PH',
    'sr': 'RS',
    'bg': 'BG',
    'da': 'DK',
    'fi': 'FI',
    'nb': 'NO',
  };

  @override
  Widget build(BuildContext context) {
    final sonuclar = (saglayicilar is Map)
        ? (saglayicilar['results'] as Map<String, dynamic>?)
        : null;
    if (sonuclar == null || sonuclar.isEmpty) return const SizedBox.shrink();

    // Tercih bölgesi → ABD → İngiltere → mevcut ilk bölge
    final tercih = _bolgeler[Ceviri.dil.value] ?? 'US';
    final bolgeKod = sonuclar.containsKey(tercih)
        ? tercih
        : sonuclar.containsKey('US')
        ? 'US'
        : sonuclar.containsKey('GB')
        ? 'GB'
        : sonuclar.keys.first;
    final bolge = sonuclar[bolgeKod] as Map<String, dynamic>;

    final gruplar = <(String, List<dynamic>)>[
      ('Abonelik'.c, (bolge['flatrate'] as List<dynamic>?) ?? const []),
      ('Kirala'.c, (bolge['rent'] as List<dynamic>?) ?? const []),
      ('Satın al'.c, (bolge['buy'] as List<dynamic>?) ?? const []),
    ].where((g) => g.$2.isNotEmpty).toList();
    if (gruplar.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Text(
            'Nerede İzlenir'.c,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
        for (final g in gruplar)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  g.$1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: DiziRenkler.metin54,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final s in g.$2)
                      _saglayiciRozet(s as Map<String, dynamic>),
                  ],
                ),
              ],
            ),
          ),
        // JustWatch atıfı (TMDB kullanım koşulu)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            'Veri: JustWatch'.c,
            style: TextStyle(fontSize: 11, color: DiziRenkler.metin38),
          ),
        ),
      ],
    );
  }

  Widget _saglayiciRozet(Map<String, dynamic> s) {
    final logo = posterUrl(s['logo_path'] as String?, boyut: 'w92');
    final ad = (s['provider_name'] as String?) ?? '';
    return Tooltip(
      message: ad,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: logo == null
            ? Container(
                width: 48,
                height: 48,
                color: DiziRenkler.metin12,
                alignment: Alignment.center,
                child: Text(
                  ad.isNotEmpty ? ad[0] : '?',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              )
            : CachedNetworkImage(
                imageUrl: logo,
                httpHeaders: gorselBasliklari(logo),
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
      ),
    );
  }
}

/// Dizinin/filmin TÜM oyuncu kadrosunu alt sayfada listeler.
///
/// Detaydaki yatay şerit yalnız ilk 20 kişiyi gösteriyor; kalabalık
/// kadrolarda (Kurtlar Vadisi gibi) geri kalanına ulaşmanın yolu yoktu.
Future<void> tumOyuncularAc(
  BuildContext context,
  List<dynamic> kadro,
) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: DiziRenkler.koyuGri,
  isScrollControlled: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (sheetContext) => DraggableScrollableSheet(
    initialChildSize: 0.75,
    minChildSize: 0.4,
    maxChildSize: 0.95,
    expand: false,
    builder: (context, kaydirma) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(
            children: [
              Icon(Icons.people_outline, color: DiziRenkler.sari),
              const SizedBox(width: 10),
              // Flexible: my/ar çevirileri uzun; sığmazsa sarsın, kesilmesin.
              Flexible(
                child: Text(
                  'Oyuncular'.c,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(${kadro.length})',
                style: TextStyle(color: DiziRenkler.metin54, fontSize: 14),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: kaydirma,
            itemCount: kadro.length,
            itemBuilder: (context, i) {
              final o = kadro[i] as Map<String, dynamic>;
              final foto = posterUrl(
                o['profile_path'] as String?,
                boyut: 'w185',
              );
              final rol = o['character'] as String?;
              return ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: DiziRenkler.kart,
                  backgroundImage: foto != null
                      ? CachedNetworkImageProvider(
                          foto,
                          headers: gorselBasliklari(foto),
                        )
                      : null,
                  child: foto == null
                      ? Icon(Icons.person, color: DiziRenkler.metin38)
                      : null,
                ),
                title: Text(
                  '${o['name']}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: rol != null && rol.isNotEmpty
                    ? Text(
                        rol,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: DiziRenkler.metin54),
                      )
                    : null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push('/kisi/${o['id']}');
                },
              );
            },
          ),
        ),
      ],
    ),
  ),
);

/// Başlığın SOLUNDAKİ küçük afiş (19 Ağu 2026 isteği).
///
/// Afişi olmayan yapımda beyaz/boş dikdörtgen yerine kart zemini + ikon
/// çizilir: boş kutu "görsel yüklenemedi" gibi durur, oysa TMDB'de o afiş
/// gerçekten yok. Görsele dokunulunca BÜYÜTÜLÜR — üstteki kapak şeridiyle
/// aynı jest, ayrı bir öğrenme yükü yok.
class _AfisKucuk extends StatelessWidget {
  final String? yol;
  final String ad;

  /// Genişlik; yükseklik posterin 2:3 oranından TÜRETİLİR.
  static const double genislik = 92;

  const _AfisKucuk({required this.yol, required this.ad});

  @override
  Widget build(BuildContext context) {
    final url = posterUrl(yol, boyut: 'w342');
    final kutu = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: genislik,
        height: genislik * 3 / 2,
        child: url == null
            ? ColoredBox(
                color: DiziRenkler.kart,
                child: Icon(
                  Icons.movie_outlined,
                  color: DiziRenkler.metin38,
                  size: 28,
                ),
              )
            : CachedNetworkImage(
                imageUrl: url,
                httpHeaders: gorselBasliklari(url),
                fit: BoxFit.cover,
                placeholder: (_, _) => ColoredBox(color: DiziRenkler.kart),
                errorWidget: (_, _, _) => ColoredBox(
                  color: DiziRenkler.kart,
                  child: Icon(
                    Icons.movie_outlined,
                    color: DiziRenkler.metin38,
                    size: 28,
                  ),
                ),
              ),
      ),
    );
    if (url == null) return Semantics(label: ad, child: kutu);
    return Semantics(
      button: true,
      label: ad,
      child: InkWell(
        key: const Key('detay-afis'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => medyaGoster(context, [url]),
        child: kutu,
      ),
    );
  }
}

/// Tür etiketleri — TIKLANABİLİR.
///
/// İSTEK: "türlere tıklanabilsin, tıklayınca o türdeki dizileri listele."
/// Hedef Gözat ekranı: türe göre süzülmüş, sonsuz kaydırmalı poster ızgarası
/// ZATEN orada. İkinci bir liste ekranı yazmak aynı ızgaranın kopyası olurdu.
///
/// Dizinin türüne dokununca DİZİ listesi, filmin türüne dokununca FİLM listesi
/// açılır (`tur` taşınır): TMDB'nin tür kimlikleri iki katalogda AYRIDIR ve
/// yanlış katalogda süzmek sessizce boş/alakasız sonuç verirdi.
@visibleForTesting
class TurCipleri extends StatelessWidget {
  final List<Map<String, dynamic>> turler;
  final String tur;

  const TurCipleri({super.key, required this.turler, required this.tur});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final g in turler)
        ActionChip(
          key: Key('tur-cip-${g['id']}'),
          label: Text('${g['name']}'),
          labelStyle: TextStyle(
            color: DiziRenkler.sariMetin,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
          // DOLGU DARALTILDI (ölçüm, 390 dp telefon): "Komedi" yazısı 75 dp,
          // çip 109 dp idi — 34 dp'si boşluktu. `labelPadding` sıfırlanıp
          // dolgu tek yerden veriliyor; çip 24 dp kısalıyor ve üç tür 360 dp
          // genişliğindeki telefonlarda da tek satıra sığıyor. Dokunma
          // hedefi DÜŞMÜYOR: yükseklik ve `materialTapTargetSize.padded`
          // aynen duruyor, kısalan yalnız yatay boşluk.
          labelPadding: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          side: BorderSide(color: DiziRenkler.sari.withValues(alpha: 0.35)),
          backgroundColor: DiziRenkler.sari.withValues(alpha: 0.10),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.padded,
          onPressed: () => GoRouter.of(
            context,
          ).push(gozatYolu(tur: tur, genre: (g['id'] as num).toInt())),
        ),
    ],
  );
}
