/// Bir metin YALNIZ emojiden mi oluşuyor?
///
/// KULLANICI İSTEĞİ (24 Ağu 2026): "sohbette sadece emoji gönderildiğinde
/// büyük gözüksün, %100 oranında büyüt". Mesaj balonu metni bu süzgeçten
/// geçirir ve yalnız emojiyse yazı boyutunu iki katına çıkarır
/// (WhatsApp/Telegram geleneği).
///
/// Tanım bilinçli olarak DAR: pictografik karakterler
/// (`\p{Extended_Pictographic}`), onları birleştiren görünmez işaretler
/// (ZWJ `200D`, varyasyon seçici `FE0F`, ten rengi `1F3FB-1F3FF`) ve boşluk.
/// Rakam+keycap ("1️⃣") gibi METİN KÖKENLİ diziler büyütülmez: rakam tek
/// başına da geçerli metin olduğundan süzgeci gevşetmek "1" yazan sıradan
/// mesajı da büyütürdü. Bayrak emojileri (bölgesel gösterge çiftleri,
/// `1F1E6-1F1FF`) pictografik sayılır ve büyür.
// ignore: valid_regexps — analizcinin doğrulayıcısı Regional_Indicator /
// Emoji_Modifier ikili Unicode özelliklerini tanımıyor; çalışma zamanı
// (irregexp) tanıyor ve testler bayrak/ten rengi örnekleriyle bunu kilitliyor.
final RegExp _emojiDisi = RegExp(
  '[^\\p{Extended_Pictographic}\\p{Regional_Indicator}'
  '\\p{Emoji_Modifier}\\u200D\\uFE0F\\s]',
  unicode: true,
);

bool yalnizEmoji(String metin) {
  final t = metin.trim();
  if (t.isEmpty) return false;
  return !_emojiDisi.hasMatch(t);
}
