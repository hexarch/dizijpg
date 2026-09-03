// Gönderi dili kestirimi — `node --test backend/test`
//
// NEDEN VAR: kestirimin çıktısı doğrudan kullanıcının gördüğü bir düğmedir.
// `dilTespit` boş dönerse akıştaki gönderide "Çevir" HİÇ çıkmaz; yanlış dil
// dönerse Türkçe gönderiye Türkçe "çeviri" düğmesi çıkar. 3 Eyl 2026'da
// kullanıcı "akışta sadece metin içeren içeriklerde çevir butonu yok" diye
// bildirdi; kök sebep 204 yazı gönderisinde `kaynak_dil`in boş olmasıydı.
// Buradaki durumlar CANLI veriden (208 dili bilinmeyen + 4.871 etiketli
// gönderi) seçildi.
import test from 'node:test';
import assert from 'node:assert/strict';

import { dilTespit } from '../dil_tespit.js';

test('Latin dışı yazı sistemi tek eşleşmeyle karar verir', () => {
  assert.equal(dilTespit('القاهرة بطلة. الرعب الذي يبقى بعد إغلاق الحلقة'), 'ar');
  assert.equal(dilTespit('Дачи важнее спецназа. Не про вирус.'), 'ru');
  assert.equal(dilTespit('ধৈর্যের পুলিশি কাজ। চিৎকার কম, নোটবুক বেশি।'), 'bn');
  assert.equal(dilTespit('カメラが優しい。事件より人。'), 'ja');
  assert.equal(dilTespit('감정이 정직하다. 결말은 조용하다.'), 'ko');
});

test('Urduca Arapçadan ayrılır (Arap alfabesi ORTAK)', () => {
  // `ٹ ڈ ڑ ے ہ` Arapçada yok. Sıra bozulursa bu gönderi 'ar' döner ve
  // Urduca okur "Çevir" görmez — canlıda 7 gönderide böyleydi.
  assert.equal(dilTespit('کہانی سست ہے لیکن کردار ٹھیک ہیں۔ ڈراما دیکھنے'), 'ur');
});

test('Bengalce dandası (।) Hintçe sanılmaz', () => {
  // `।` U+0964 Devanagari bloğunda ama Bengalce de kullanır.
  assert.equal(dilTespit('গল্পটা ধীরে চলে। তবু ধরে রাখে।'), 'bn');
  assert.equal(dilTespit('कहानी धीमी है। फिर भी बांधे रखती है।'), 'hi');
});

test('Türkçe: özel harf, çekim eki ve kelime — üçü de yeter', () => {
  assert.equal(dilTespit('evlat sevgisi işte napacaksin'), 'tr');       // ş
  assert.equal(dilTespit('Tedesco yine kaybediyor'), 'tr');             // -iyor
  assert.equal(dilTespit('minimum 2-3 defa izlemeniz gerekebilir'), 'tr'); // -ebilir
  assert.equal(dilTespit('bence bu dizi çok iyi'), 'tr');               // kelime
});

test('ö/ü ALMANCA KANITI DEĞİLDİR (Türkçede de var)', () => {
  // Ölçüldü: `äöü` Almanca sayılınca 4.871 etiketli gönderinin 71'i
  // Türkçeden Almancaya kayıyordu.
  assert.equal(dilTespit('sonu çok kötü bitti ölüm sahnesi gereksizdi'), 'tr');
  assert.equal(dilTespit('Die Staffel ist nicht gut, aber die Folge war schön'), 'de');
});

test('Tek başına PAYLAŞILAN kelime dil kanıtı değildir', () => {
  // "en" hem Felemenkçe hem İspanyolca listesinde. Eski sürüm bu Türkçe
  // cümleyi yalnız o kelime yüzünden 'nl' sayıyordu.
  assert.notEqual(dilTespit('son zamanlar izledigim en iyi korku filmi'), 'nl');
});

test('İngilizce yazı gönderisi tanınır', () => {
  assert.equal(
    dilTespit('A face arguing with a landscape. The church scene is the movie.'),
    'en',
  );
});

test('Dil kanıtı yoksa BOŞ döner (uydurmaz)', () => {
  assert.equal(dilTespit('#breakingbad #bettercallsaul'), null); // etiket yığını
  assert.equal(dilTespit('😍😍😍😍'), null);
  assert.equal(dilTespit('7.7'), null);
  assert.equal(dilTespit('kullanici@dizijpg.com'), null); // e-posta dil değil
  assert.equal(dilTespit(''), null);
  assert.equal(dilTespit(null), null);
});

test('Etiket ve bağlantı dile karışmaz', () => {
  // `#thewire` içindeki "the" İngilizce kanıtı sayılsaydı Türkçe gönderi
  // İngilizce olurdu.
  assert.equal(dilTespit('şu dizi harika bence #thewire #theboys'), 'tr');
});

// ---------------------------------------------------------------------------
// Sunucu bağlantısı: `ceviriUygula` sütun boşsa kestirime DÜŞMELİ.
//
// `server.js` içe aktarıldığı anda `app.listen` çağırıyor, o yüzden burada
// kaynak metni okunuyor (test/kesfet_medya.test.js ile aynı yöntem). Bu satır
// düşerse hata sessizdir: uçlar yine 200 döner, yalnız düğme kaybolur.
// ---------------------------------------------------------------------------
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KAYNAK = fs.readFileSync(
  path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'server.js'),
  'utf8',
);

test('ceviriUygula: kaynak_dil boşsa metinden kestirir', () => {
  const bas = KAYNAK.indexOf('function ceviriUygula');
  assert.ok(bas > 0, 'ceviriUygula bulunamadı — test etkisiz kalmış olabilir');
  const govde = KAYNAK.slice(bas, bas + 900);
  assert.match(govde, /r\.kaynak_dil \|\| dilTespit\(r\.metin\)/,
    'kaynak_dil boşken kestirime düşülmüyor — yazı gönderilerinde çevir '
    + 'düğmesi yine kaybolur');
});

test('/ceviri ucu düğmeyle AYNI kestirimi kullanır', () => {
  const bas = KAYNAK.indexOf("app.get('/ceviri/:yorumId'");
  assert.ok(bas > 0, '/ceviri ucu bulunamadı');
  const govde = KAYNAK.slice(bas, bas + 2200);
  assert.match(govde, /y\.kaynak_dil \|\| dilTespit\(y\.metin\)/,
    'uç ile düğme farklı karar verirse düğme çıkar ama uç {yok:true} döner');
});
