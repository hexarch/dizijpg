// dizi.jpg — sık kullanılan emoji ayıklama (yorum kutusunun üstündeki 8'li satır)
//
// AYRI TAKİP TABLOSU YOK: mevcut `yorumlar.metin` sütunu taranır. Ayıklama
// GRAFEM KÜMESİ bazlıdır (Intl.Segmenter), yani şunlar TEK emoji sayılır:
//   - ZWJ birleşimleri: 👨‍👩‍👧‍👦, 👩‍💻
//   - ten tonu değiştiricileri: 👍🏽
//   - varyasyon seçici (U+FE0F): ❤️
//   - bayraklar (bölgesel gösterge çifti): 🇹🇷
// Kod noktası bazlı bir ayıklama bunları parçalayıp anlamsız karakter döndürür.

/// Hiç veri yoksa (yeni kurulum) gösterilecek yedek satır.
export const EMOJI_YEDEK = ['😂', '❤️', '🔥', '👏', '😍', '😮', '😢', '👍'];

const BOLUCU = new Intl.Segmenter('en', { granularity: 'grapheme' });

// Emoji adayı: resimsi karakter, bölgesel gösterge (bayrak) veya tuş kapağı.
const EMOJI_DESEN = /\p{Extended_Pictographic}|\p{Regional_Indicator}|\u20E3/u;

// Metin görünümlü işaretler emoji sayılmasın (klavyeden emoji olarak girilmez).
const DISLA = new Set(['©', '®', '™', '‼', '⁉', '#', '*']);

/// Verilen metinlerdeki emojileri sayar, en çok kullanılan [adet] tanesini
/// (çoktan aza) döndürür. Aynı emojinin varyasyon seçicili ve seçicisiz hali
/// (❤️ / ❤) tek sayaçta birleşir; gösterimde seçicili hal tercih edilir.
export function emojiSay(metinler, adet = 8) {
  const sayac = new Map();
  for (const metin of metinler) {
    if (!metin) continue;
    for (const { segment } of BOLUCU.segment(String(metin))) {
      if (!EMOJI_DESEN.test(segment)) continue;
      const anahtar = segment.replace(/[\uFE0E\uFE0F]/g, '');
      if (!anahtar || DISLA.has(anahtar)) continue;
      const kayit = sayac.get(anahtar) || { sayi: 0, gosterim: segment };
      kayit.sayi += 1;
      // Seçicili hal daha doğru çizilir (❤️ kırmızı, ❤ siyah olabilir)
      if (segment.includes('\uFE0F')) kayit.gosterim = segment;
      sayac.set(anahtar, kayit);
    }
  }
  return [...sayac.values()]
    .sort((a, b) => b.sayi - a.sayi || a.gosterim.localeCompare(b.gosterim))
    .slice(0, adet)
    .map((k) => k.gosterim);
}
