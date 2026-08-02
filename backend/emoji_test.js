// dizi.jpg — emoji ayıklama birim testi:  node emoji_test.js
// Amaç: ZWJ birleşimleri, ten tonu değiştiricileri, varyasyon seçici ve
// bayraklar TEK emoji sayılsın; parçalanıp anlamsız karakter dönmesin.
import assert from 'assert';
import { emojiSay, EMOJI_YEDEK } from './emoji.js';

let gecen = 0;
function t(ad, fn) {
  fn();
  gecen += 1;
  console.log('  ok -', ad);
}

t('düz emoji sayılır ve sıklığa göre sıralanır', () => {
  assert.deepStrictEqual(emojiSay(['😂😂 harika', 'çok iyi 🔥', '😂']), ['😂', '🔥']);
});

t('ZWJ birleşik aile emojisi TEK emoji sayılır', () => {
  const s = emojiSay(['ailecek izledik 👨‍👩‍👧‍👦']);
  assert.deepStrictEqual(s, ['👨‍👩‍👧‍👦']);
  assert.strictEqual(s[0].length, 11); // 4 kişi + 3 ZWJ = tek grafem
});

t('ZWJ meslek emojisi (👩‍💻) parçalanmaz', () => {
  assert.deepStrictEqual(emojiSay(['kod yazdım 👩‍💻 👩‍💻']), ['👩‍💻']);
});

t('ten tonu değiştiricisi emojiye dahildir', () => {
  assert.deepStrictEqual(emojiSay(['👍🏽 süper']), ['👍🏽']);
});

t('varyasyon seçicili ve seçicisiz kalp tek sayaçta birleşir', () => {
  // ❤️ (FE0F var) x2 + ❤ (FE0F yok) x1 = 3 → tek girdi, gösterim seçicili
  const s = emojiSay(['❤️', '❤️', '❤', '🔥']);
  assert.strictEqual(s.length, 2);
  assert.strictEqual(s[0], '❤️');
});

t('bayrak (bölgesel gösterge çifti) tek emoji sayılır', () => {
  assert.deepStrictEqual(emojiSay(['🇹🇷 dizileri']), ['🇹🇷']);
});

t('metin görünümlü işaretler (© ® ™ # *) emoji sayılmaz', () => {
  assert.deepStrictEqual(emojiSay(['© 2026 dizi.jpg ® ™ #dizi *']), []);
});

t('emojisiz metin boş liste döndürür', () => {
  assert.deepStrictEqual(emojiSay(['sadece düz yazı', '', null, undefined]), []);
});

t('en fazla istenen adet döner', () => {
  const metin = '😀😁😂🤣😃😄😅😆😉😊';
  assert.strictEqual(emojiSay([metin]).length, 8);
  assert.strictEqual(emojiSay([metin], 3).length, 3);
});

t('yedek liste 8 tekil emoji içerir', () => {
  assert.strictEqual(EMOJI_YEDEK.length, 8);
  assert.strictEqual(new Set(EMOJI_YEDEK).size, 8);
});

t('karışık gerçek yorum metni doğru ayıklanır', () => {
  assert.deepStrictEqual(
    emojiSay(['Bu bölüm 🔥🔥 oldu, finalde ağladım 😢 👨‍👩‍👧 ailecek 🔥']),
    ['🔥', '👨‍👩‍👧', '😢'], // 🔥 x3; eşit sayıdakiler kararlı sırada
  );
});

t('imleç konumuna ekleme için gösterim hep tek grafemdir', () => {
  const s = emojiSay(['👍🏽 ❤️ 🇹🇷 👩‍💻']);
  const bolucu = new Intl.Segmenter('en', { granularity: 'grapheme' });
  for (const e of s) assert.strictEqual([...bolucu.segment(e)].length, 1, e);
  assert.strictEqual(s.length, 4);
});

console.log(`\n${gecen} test geçti.`);
