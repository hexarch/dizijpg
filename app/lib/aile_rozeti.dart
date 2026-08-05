import 'package:flutter/material.dart';

import 'ceviri.dart';
import 'tema.dart';

/// "Founding Member" rozeti — kapalı test (Play Console) ekibinin profil nişanı.
///
/// KULLANICI İSTEĞİ (5 Ağu 2026): "tester olarak eklediğimiz mail adresinden
/// kayıt olan kullanıcıların profilinde ülke bayrağı yanında dizi.jpg logosu
/// koy ve yanına yaz" — etiket aynı gün "Founding Member" olarak sabitlendi.
///
/// --- NEDEN "Founding Member" ÇEVRİLMİYOR ---
/// Bir unvan; `dizi.jpg` gibi marka terimi sayılır ve 45 dilde aynı kalır.
/// Bu yüzden `.c` YOK: dil dosyalarında karşılığı olmayan tek kullanıcı metni
/// budur, bilerek öyle. Rozete dokununca açılan modalın GÖVDE cümlesi ise
/// çevriliyor (aşağıda iki varyant).
///
/// --- NEDEN LOGO KOYU BİR PULUN İÇİNDE ---
/// `assets/logo.png` koyu zemin için çizilmiş: "DİZİ" harfleri AÇIK GRİ, onları
/// ayıran şey ince siyah konturdur. Rozet boyutuna (~12 dp) küçültülünce o
/// kontur piksel altına iner ve harfler açık temanın kırık beyaz zemininde
/// (#F6F6F8) erir. Ölçüldü: açık zeminde harf piksellerinin yalnız %10'u 3:1
/// kontrasta ulaşıyor, koyu zeminde %60. Bu yüzden logo DAİMA koyu bir pulun
/// üstüne çizilir. Koyu temada pul rengi zeminle aynı olduğu için görünmez —
/// logo çıplak durur; açık temada ise küçük bir marka pulu belirir. Tek kod
/// yolu, iki temada da okunur sonuç.
///
/// --- NEDEN 44 dp YÜKSEK ---
/// Rozet artık TIKLANABİLİR (rozetin ne olduğunu anlatan alt sayfayı açar), bu
/// yüzden dokunma hedefi kuralı geçerli: mürekkep ~15 dp kalır ama etrafındaki
/// dolgu satırı 44 dp'ye tamamlar. YAZI BÜYÜTÜLMEDİ — yalnız dolgu. Dolgunun
/// dışına taşan bir dokunma alanı denenmedi: Flutter'da ebeveyn sınırının
/// dışında kalan alan çizilse bile hit-test almaz.
class AileRozeti extends StatelessWidget {
  const AileRozeti({super.key, this.benMi = false, this.yukseklik = 11});

  /// Bakılan profil oturumun sahibine mi ait? Modalın gövde cümlesi buna göre
  /// ikinci tekil şahsa döner ("...birisin"). Kaynağı sunucunun `ben_mi`
  /// yargısıdır; `kullanici_profil.dart` kendi kullanıcı adınla da açılabildiği
  /// için ekranın türüne bakmak YETMEZ.
  final bool benMi;

  /// Logonun MÜREKKEP yüksekliği (saydam kenar boşluğu hariç).
  final double yukseklik;

  /// Rozetin görünen etiketi. Unvan olduğu için çevrilmez.
  static const String etiket = 'Founding Member';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: () => aileRozetiSheet(context, benMi: benMi),
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          // Dokunma hedefi: en az 44x44 dp (etiket metniyle genişlik zaten
          // fazlasıyla aşılıyor; kritik olan yükseklik).
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DiziLogosu(yukseklik: yukseklik),
                const SizedBox(width: 5),
                // Rozet metni dar ekranda ülke adıyla yarışmasın diye Flexible:
                // yeri daralırsa üç noktayla kısalır, satırı TAŞIRMAZ.
                Flexible(
                  child: Text(
                    etiket,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: DiziRenkler.sariMetin,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rozetin ne anlama geldiğini anlatan alt sayfa.
///
/// Projedeki alt sayfa kalıbının aynısı (`begenenler.dart`, `paylas.dart`):
/// yuvarlatılmış üst köşeler, sürükleme tutamağı ve **SafeArea**. SafeArea
/// şart: bu hafta üç modalde (ListeSheet, takvim gün detayı, puan verme) alt
/// içerik sistem gezinme çubuğunun altında kalmıştı.
///
/// Kapanma yolları: tutamaktan aşağı sürükleme, dışına dokunma (barrier) ve
/// "Kapat" düğmesi.
Future<void> aileRozetiSheet(BuildContext context, {required bool benMi}) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: DiziRenkler.koyuGri,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AileRozetiSheet(benMi: benMi),
    );

/// Gövde cümlesinin ÜÇÜNCÜ ŞAHIS varyantı (başkasının profili).
const String aileRozetiBaskasi =
    'İlk kullanıcılarımızdan biri. Geri bildirimleriyle uygulamanın bugün '
    'olduğu hale gelmesine katkı sağladı.';

/// Gövde cümlesinin İKİNCİ TEKİL ŞAHIS varyantı (kendi profilin).
const String aileRozetiBenim =
    'İlk kullanıcılarımızdan birisin. Geri bildirimlerinle uygulamanın bugün '
    'olduğu hale gelmesine katkı sağladın.';

class _AileRozetiSheet extends StatelessWidget {
  const _AileRozetiSheet({required this.benMi});

  final bool benMi;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          // Sürükleme tutamağı (beğenenler/paylaş sheet'iyle aynı ölçü).
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: DiziRenkler.metin24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Row(
              children: [
                // Rozetteki pulun büyüğü. Logo yine koyu pulun üstünde:
                // açık temada çıplak logo okunmuyor (dosya başındaki not).
                const DiziLogosu(yukseklik: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AileRozeti.etiket,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: DiziRenkler.sariMetin,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Text(
              (benMi ? aileRozetiBenim : aileRozetiBaskasi).c,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: DiziRenkler.metin70,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Kapat'.c,
                  style: TextStyle(color: DiziRenkler.sariMetin),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Küçük boyda kullanılabilen dizi.jpg marka pulu.
///
/// `assets/logo.png` 640x640 bir tuvalde durur ama mürekkep yalnız aşağıdaki
/// dikdörtgendedir; gerisi saydam. Doğrudan `Image.asset(height: 12)` denseydi
/// harfler 640'ta ölçekleneceği için ~3,6 dp kalır, okunmazdı. Bu yüzden
/// saydam kenar boşluğu kırpılır ve istenen yükseklik MÜREKKEBE uygulanır.
class DiziLogosu extends StatelessWidget {
  const DiziLogosu({super.key, this.yukseklik = 11});

  final double yukseklik;

  /// Tuval ölçüsü ve mürekkebin sınırları (alfa > 16 olan piksellerin kutusu).
  /// Varlık değişirse `aile_rozeti_test.dart` bunu PNG'yi çözerek doğrular ve
  /// uyuşmazsa kırmızıya döner.
  static const double tuval = 640;
  static const Rect murekkep = Rect.fromLTRB(76, 195, 566, 389);

  /// Mürekkep kutusunun tuval içindeki konumunu `Alignment`e çevirir:
  /// kırpma penceresinde mürekkep tam ortalanır.
  static Alignment get _hiza => Alignment(
    2 * murekkep.left / (tuval - murekkep.width) - 1,
    2 * murekkep.top / (tuval - murekkep.height) - 1,
  );

  @override
  Widget build(BuildContext context) {
    final olcek = yukseklik / murekkep.height;
    final tam = tuval * olcek;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DiziRenkler.markaKoyu,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: SizedBox(
          width: murekkep.width * olcek,
          height: yukseklik,
          child: ClipRect(
            child: OverflowBox(
              minWidth: tam,
              maxWidth: tam,
              minHeight: tam,
              maxHeight: tam,
              alignment: _hiza,
              child: Image.asset(
                'assets/logo.png',
                width: tam,
                height: tam,
                filterQuality: FilterQuality.medium,
                // Yanındaki "Founding Member" metni zaten okunuyor;
                // ekran okuyucu markayı iki kez söylemesin.
                excludeFromSemantics: true,
                // Varlık açılmazsa rozet metni tek başına kalır, satır bozulmaz.
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
