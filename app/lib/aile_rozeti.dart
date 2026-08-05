import 'package:flutter/material.dart';

import 'ceviri.dart';
import 'tema.dart';

/// "dizi.jpg aile üyesi" rozeti — kapalı test (Play Console) ekibinin profil
/// nişanı.
///
/// KULLANICI İSTEĞİ (5 Ağu 2026): "tester olarak eklediğimiz mail adresinden
/// kayıt olan kullanıcıların profilinde ülke bayrağı yanında dizi.jpg logosu
/// koy ve yanına 'Dizi jpg aile üyesi' yaz"
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
/// Rozet TIKLANABİLİR DEĞİLDİR (bir yere gitmez, bir şey açmaz), bu yüzden
/// 44 dp dokunma hedefi kuralı geçerli değil; ölçüsü yanındaki ülke metniyle
/// aynı optik ağırlıkta tutulur.
class AileRozeti extends StatelessWidget {
  const AileRozeti({super.key, this.yukseklik = 11});

  /// Logonun MÜREKKEP yüksekliği (saydam kenar boşluğu hariç).
  final double yukseklik;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DiziLogosu(yukseklik: yukseklik),
        const SizedBox(width: 5),
        // Rozet metni dar ekranda ülke adıyla yarışmasın diye Flexible:
        // yeri daralırsa üç noktayla kısalır, satırı TAŞIRMAZ.
        Flexible(
          child: Text(
            'Dizi jpg aile üyesi'.c,
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
                // Yanındaki "Dizi jpg aile üyesi" metni zaten okunuyor;
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
