// Gönderi dilini kestirme — dış servis YOK.
//
// NEDEN AYRI DOSYA: `server.js` içe aktarıldığı anda `app.listen` çağırıyor,
// yani oradaki bir işlev birim testinden çağrılamıyor (test/kesfet_medya.test.js
// bu yüzden kaynak metnini okuyor). Dil kestirimi ise SAF bir işlev ve
// isabeti doğrudan "çevir düğmesi çıkıyor mu" sorusunu belirliyor — testli
// olması şart. Ayrıca `veri_aktar.js` ve araclar/ da aynı işlevi kullanır;
// kopyalanmış üç sürüm ayrışırdı.
//
// AMAÇ kusursuz tespit değil: "bu gönderi zaten kullanıcının dilinde mi?"
// sorusuna yetecek isabet. Yanılırsa en fazla gereksiz bir çevir düğmesi
// çıkar; BİLİNMİYOR (null) dönmek ise düğmeyi HİÇ göstermez — bu yüzden
// kararsız kalmak, yanılmaktan daha pahalıdır (3 Eyl 2026: akıştaki
// yalnız-yazı gönderilerinin 204'ünde kaynak_dil boştu ve Arapça/Rusça
// gönderilerde bile çevir düğmesi çıkmıyordu).

// Latin DIŞI yazı sistemleri: tek eşleşme kesin karardır.
// Latin DIŞI yazı sistemleri: tek eşleşme kesin karardır.
//
// SIRA ÖNEMLİ ve iki tuzağı kapatır:
//  · Urduca Arap alfabesiyle yazılır — `ٹ ڈ ڑ ں ے ہ` harfleri Arapçada YOK,
//    bu yüzden `ur` kontrolü `ar`dan ÖNCE gelir (yoksa 7 Urduca gönderi
//    Arapça sayılıyordu ve Urduca okura "Çevir" düğmesi çıkmıyordu).
//  · Bengalce metinlerdeki `।` (danda, U+0964) Devanagari bloğundadır;
//    `hi` deseni önce çalışsaydı Bengalce metin Hintçe sayılırdı. Danda ve
//    çift danda aşağıda metinden ayıklanıyor, ayrıca `bn` sırada önde.
const YAZI_SISTEMI = [
  [/[\u3040-\u30ff]/, 'ja'], [/[\uac00-\ud7af]/, 'ko'],
  [/[\u0e00-\u0e7f]/, 'th'], [/[\u0590-\u05ff]/, 'he'],
  [/[\u0679\u067e\u0686\u0688\u0691\u06BE\u06C1\u06C3\u06D2\u06CC]/, 'ur'],
  [/[\u0600-\u06ff]/, 'ar'],
  [/[\u0980-\u09ff]/, 'bn'], [/[\u0900-\u097f]/, 'hi'],
  [/[\u0400-\u04ff]/, 'ru'],
  [/[\u0370-\u03ff]/, 'el'], [/[\u4e00-\u9fff]/, 'zh'],
];

// Latin alfabesi: ayırt edici kelimeler (küçük harfe indirgenmiş metinde aranır)
const DIL_KELIMELERI = {
  tr: ['bir', 've', 'bu', 'için', 'çok', 'ama', 'daha', 'ben', 'sen', 'değil',
    'gibi', 'olan', 'şey', 'yok', 'var', 'bence', 'gerçekten', 'kesinlikle',
    'güzel', 'kötü', 'harika', 'sanki', 'biraz', 'yine', 'sonra', 'kadar',
    'hiç', 'bile', 'zaten', 'dizi', 'dizisi', 'filmi', 'bölüm', 'sezon',
    'oyuncu', 'sahne', 'konu', 'hafta', 'zaman', 'iyi'],
  en: ['the', 'and', 'is', 'of', 'to', 'in', 'this', 'that', 'with', 'you',
    'for', 'was', 'are', 'it', 'but', 'not', 'have', 'they', 'from', 'about',
    'just', 'like', 'movie', 'show', 'season', 'episode'],
  es: ['el', 'la', 'de', 'que', 'los', 'una', 'por', 'con', 'para', 'como',
    'pero', 'más', 'muy', 'está', 'este', 'también', 'película', 'temporada'],
  pt: ['de', 'que', 'não', 'uma', 'com', 'para', 'mais', 'como', 'mas',
    'muito', 'você', 'está', 'ele', 'isso', 'filme', 'temporada'],
  fr: ['le', 'la', 'les', 'des', 'une', 'pour', 'avec', 'dans', 'pas', 'plus',
    'être', 'mais', 'est', 'sur', 'tout', 'film', 'saison'],
  de: ['der', 'die', 'das', 'und', 'ist', 'nicht', 'für', 'mit', 'auch',
    'eine', 'aber', 'sich', 'noch', 'sehr', 'wie', 'staffel', 'folge'],
  it: ['il', 'la', 'di', 'che', 'per', 'non', 'con', 'una', 'sono', 'anche',
    'più', 'ma', 'come', 'stagione'],
  nl: ['de', 'het', 'een', 'van', 'en', 'is', 'niet', 'voor', 'met', 'maar',
    'ook', 'nog', 'zijn', 'seizoen'],
  pl: ['nie', 'się', 'jest', 'tak', 'ale', 'jak', 'tym', 'czy', 'bardzo',
    'sezon', 'odcinek'],
  id: ['yang', 'dan', 'ini', 'itu', 'untuk', 'dengan', 'tidak', 'saya',
    'juga', 'film', 'musim'],
  vi: ['của', 'và', 'các', 'một', 'người', 'những', 'được', 'trong', 'không',
    'phim', 'nhưng'],
};

// Bir kelime KAÇ dilin listesinde geçiyor? Paylaşılan kelime ("de", "en",
// "la", "is") tek başına KANIT DEĞİLDİR: eski sürüm "son zamanlar izledigim
// en iyi korku filmi" cümlesini yalnız "en" kelimesi Felemenkçe listesinde
// diye `nl` sayıyordu — Türkçe gönderiye "Çevir" düğmesi çıkıyordu.
const KELIME_YAYGINLIGI = (() => {
  const h = new Map();
  for (const kelimeler of Object.values(DIL_KELIMELERI)) {
    for (const k of new Set(kelimeler)) h.set(k, (h.get(k) || 0) + 1);
  }
  return h;
})();

// Dile ÖZGÜ harfler/işaretler: kelime bulunmasa da güçlü kanıt.
// Sıra önemli — Türkçe'nin `ı/İ/ğ/ş` üçlüsü Azerice dışında tekildir.
const HARF_KANITI = [
  ['vi', /[ăâđêôơư]|[ạảãáàằẳẵắặầẩẫấậềểễếệỉĩịọỏõóòồổỗốộờởỡớợủũụừửữứựỳỷỹỵ]/u, 3],
  ['tr', /[ğışĞİŞ]/u, 3],
  ['pl', /[łżśćęąźń]/u, 3],
  ['es', /[ñ¿¡]/u, 3],
  ['pt', /[ãõ]/u, 3],
  ['de', /ß/u, 3],
  // `ö` ve `ü` ALMANCA KANITI DEĞİLDİR: Türkçede de var ve Türkçe gönderi
  // hacmi kat kat fazla. Ölçüldü (3 Eyl 2026): `äöü` Almanca sayılınca
  // 4.871 etiketli gönderinin 71'i Türkçeden Almancaya kayıyordu.
  ['de', /ä/u, 1],
  ['tr', /[çöü]/u, 1],
  ['fr', /[œàèùêîû]/u, 1],
  ['it', /[àèìòù]/u, 1],
];

// Türkçe çekim ekleri: özel harf içermeyen kısa yorumlar ("Tedesco yine
// kaybediyor", "izlemeniz gerekebilir") başka türlü BİLİNMİYOR kalıyordu.
// Yalnız 5 harften uzun kelimelerde aranır — "dolar", "lugar", "hablar" gibi
// yabancı kelimelerin `-lar` yanılgısını doğurmaması için ek listesi dar
// tutuldu (yalnız Türkçeye özgü çekimler).
const TR_EKLERI = /(iyor|ıyor|uyor|üyor|mışt?ı|mişt?i|muşt?u|müşt?ü|acak|ecek|malı|meli|dığı|diği|duğu|düğü|lardı|lerdi|larla|lerle|miz|mız|ınız|iniz|unuz|ünüz|ebilir|abilir|maz|mez)$/u;

/**
 * Metnin dilini kestirir. Kestiremezse `null` — çağıran taraf "bilinmiyor"
 * olarak davranır (çevir düğmesi çıkmaz).
 */
export function dilTespit(ham) {
  const metin = String(ham || '')
    .replace(/[#@][\w._-]+/g, ' ') // etiket ve kullanıcı adları dile karışmasın
    .replace(/https?:\/\/\S+/g, ' ')
    .replace(/\S+@\S+\.\S+/g, ' ') // e-posta adresi dil kanıtı değildir
    .replace(/[\u0964\u0965]/g, ' ')  // danda: Hintçe bloğunda ama Bengalce de kullanır
    .trim();
  if (metin.length < 3) return null;
  for (const [desen, kod] of YAZI_SISTEMI) {
    if (desen.test(metin)) return kod;
  }
  const kucuk = ' '
    + metin.toLowerCase().replace(/[^\p{L}\s]/gu, ' ').replace(/\s+/g, ' ')
    + ' ';
  const puanlar = {};
  for (const [kod, kelimeler] of Object.entries(DIL_KELIMELERI)) {
    puanlar[kod] = kelimeler.reduce((t, k) => {
      if (!kucuk.includes(` ${k} `)) return t;
      // Tek dile ait kelime tam puan; paylaşılan kelime yalnız ONDALIK
      // katkı verir (üst üste binerse yine anlam taşır, tek başına taşımaz).
      return t + (KELIME_YAYGINLIGI.get(k) === 1 ? 1 : 0.25);
    }, 0);
  }
  for (const [kod, desen, puan] of HARF_KANITI) {
    if (desen.test(metin)) puanlar[kod] += puan;
  }
  // Türkçe ek sayacı: iki ayrı kelime çekimliyse kelime listesi kadar güçlü.
  const ekli = kucuk.trim().split(' ')
    .filter((k) => k.length > 5 && TR_EKLERI.test(k)).length;
  if (ekli) puanlar.tr += Math.min(ekli, 2);

  const sirali = Object.entries(puanlar).sort((a, b) => b[1] - a[1]);
  const [enIyi, puan] = sirali[0];
  const ikinci = sirali[1]?.[1] ?? 0;
  // Kararlılık eşiği: kazanan en az 1 puan toplamalı VE ikinciden açık ara
  // önde olmalı. Berabere biten kanıt (iki dilin ortak kelimesi) BİLİNMİYOR
  // sayılır — yanlış dil yazmak, hazır çeviriyi de yanlış dile bağlar.
  if (puan >= 1 && puan - ikinci >= 0.75) return enIyi;
  // Ayırt edici kelime yok (çok kısa/emoji): Türkçe harf varsa tr, yoksa boş.
  return /[ğışçöüĞİŞÇÖÜ]/.test(metin) ? 'tr' : null;
}

export default dilTespit;
