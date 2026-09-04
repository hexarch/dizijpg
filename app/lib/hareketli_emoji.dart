/// HAREKETLİ EMOJİ HARİTASI — sohbetin tek emoji sözlüğü (5 Eyl 2026).
///
/// Kullanıcı isteği: "hareketli emojiler, emojilere tıklayınca ekranda
/// animasyonlar, Telegram gibi akıcı sohbet". Noto Animated Emoji (Google,
/// CC BY 4.0) Lottie dosyaları `assets/tepkiler/<kod noktası>.json` altında.
/// Tepki emojileri de aynı klasörden çizilir (`ekranlar/tepki.dart`); harita
/// oradan buraya taşındı ki tepki seti + sohbet paneli + büyük emoji balonu
/// TEK kaynağı okusun.
///
/// NEDEN VARLIK, NEDEN AĞ DEĞİL: Telegram animasyonlu emojiyi sunucudan
/// indirir; bizde web CSP dış kaynağı keser ve uçakta da emoji çalışmalı.
/// 76 dosya, 4,2 MB; APK'da (82 MB) %5, webde TEMBEL (assets: girdileri
/// açılışta inmez, yalnız görüntülenince çekilir — pubspec'teki font notu).
/// 150 KB üstü dosyalar (💀 🤖 👑 💩 👻 🤬) BİLEREK alınmadı: tek başına
/// 200 KB JSON çözmek düşük donanımda panel açılışını takıtıyor.
library;

/// Emoji → Lottie dosya adı (Unicode kod noktası, küçük harf, `_` ile ayrık).
///
/// SIRA ANLAMLI: emoji paneli bu sırayla çizer — yüzler, eller, kalpler,
/// nesneler. Değiştirirken paneli de düşün.
const Map<String, String> hareketliEmojiDosyalari = {
  // Yüzler
  '😀': '1f600',
  '😃': '1f603',
  '😁': '1f601',
  '😆': '1f606',
  '😅': '1f605',
  '🤣': '1f923',
  '😂': '1f602',
  '🙂': '1f642',
  '😉': '1f609',
  '😊': '1f60a',
  '😍': '1f60d',
  '🥰': '1f970',
  '😘': '1f618',
  '😜': '1f61c',
  '🤪': '1f92a',
  '🤩': '1f929',
  '🥳': '1f973',
  '😎': '1f60e',
  '🤓': '1f913',
  '😄': '1f604',
  '😐': '1f610',
  '🙄': '1f644',
  '😏': '1f60f',
  '😔': '1f614',
  '😢': '1f622',
  '😭': '1f62d',
  '😮': '1f62e',
  '😱': '1f631',
  '🥱': '1f971',
  '😴': '1f634',
  '🤔': '1f924',
  '🤧': '1f927',
  '🥵': '1f975',
  '🥶': '1f976',
  '🤯': '1f92f',
  '😳': '1f633',
  '🥺': '1f97a',
  '😠': '1f620',
  '😡': '1f621',
  '😈': '1f608',
  '🤡': '1f921',
  // Eller
  '👍': '1f44d',
  '👎': '1f44e',
  '👏': '1f44f',
  '🙌': '1f64c',
  '🙏': '1f64f',
  '🤝': '1f91d',
  '👋': '1f44b',
  '💪': '1f4aa',
  // Kalpler
  '❤️': '2764_fe0f',
  '💕': '1f495',
  '💛': '1f49b',
  '💙': '1f499',
  '💚': '1f49a',
  '💜': '1f49c',
  '💔': '1f494',
  '💋': '1f48b',
  '🌹': '1f339',
  // Nesneler / efektler
  '🔥': '1f525',
  '✨': '2728',
  '🎉': '1f389',
  '🎈': '1f388',
  '🎁': '1f381',
  '💯': '1f4af',
  '💥': '1f4a5',
  '💫': '1f4ab',
  '🌟': '1f31f',
  '🌈': '1f308',
  '⚡': '26a1',
  '🍿': '1f37f',
  '🎬': '1f3ac',
  '📺': '1f4fa',
  '✅': '2705',
  '❌': '274c',
  '👀': '1f440',
  '🍻': '1f37b',
  '☕': '2615',
  '🚀': '1f680',
  '🍪': '1f36a',
};

/// Emoji panelinin sırası (haritanın anahtar sırası).
final List<String> sohbetEmojileri = List.unmodifiable(
  hareketliEmojiDosyalari.keys,
);

/// Verilen metnin (bütünüyle) hareketli bir emoji olup olmadığı; varsa Lottie
/// dosya adı, yoksa null.
///
/// Varyasyon seçicisi (U+FE0F) hoşgörülür: klavye "❤" (seçicisiz) yazar,
/// harita "❤️" tutar; ikisi de kalp. Tersi de: "✅️" → "✅".
String? hareketliEmojiDosyasi(String? metin) {
  if (metin == null) return null;
  final t = metin.trim();
  if (t.isEmpty || t.length > 16) return null;
  return hareketliEmojiDosyalari[t] ??
      hareketliEmojiDosyalari[t.replaceAll('\uFE0F', '')] ??
      hareketliEmojiDosyalari['$t\uFE0F'];
}

/// Mesaj metni TEK hareketli emojiden mi ibaret (büyük çizilecek)?
bool tekHareketliEmoji(String? metin) => hareketliEmojiDosyasi(metin) != null;
