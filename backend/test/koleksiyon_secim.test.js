// KARŞILAMA AKIŞI — FİLM SERİSİ SEÇİMİ (md. 25, 13 Ağu)
//
// CANLI DOĞRULAMADA YAKALANAN GERÇEK HATA: `/karsilama/seriler` ucu koleksiyon
// id'lerini isimden çözüyor ve "ilk posterli sonucu al" diyordu. 'The Lord of
// the Rings' araması TMDB'de **"The Making of The Lord of the Rings
// Collection"** (yapım belgeselleri) getirdi — kullanıcı "Tümünü izledim"
// deseydi kitaplığına ÜÇLEME yerine BELGESELLER yazılacaktı.
//
// `koleksiyonSec()` bu seçimi kurala bağlar; buradaki testler kuralı kilitler.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

// Fonksiyon server.js içinde (uç ile aynı yerde dursun diye). Kaynaktan
// çekilip çalıştırılır — projedeki diğer saf-fonksiyon testleriyle aynı kalıp.
const KAYNAK = readFileSync(new URL('../server.js', import.meta.url), 'utf8');

function koleksiyonSeciciyiCek() {
  const elemeSatiri = KAYNAK.match(/const KOLEKSIYON_ELEME = .+;/);
  assert.ok(elemeSatiri, 'KOLEKSIYON_ELEME bulunamadı (tarayıcı bozuk?)');
  const bas = KAYNAK.indexOf('function koleksiyonSec(');
  assert.ok(bas > 0, 'koleksiyonSec bulunamadı');
  // Fonksiyonun sonu: ilk sütundaki kapanış parantezi.
  const son = KAYNAK.indexOf('\n}\n', bas);
  const govde = KAYNAK.slice(bas, son + 3);
  // eslint-disable-next-line no-new-func
  return new Function(`${elemeSatiri[0]}\n${govde}\nreturn koleksiyonSec;`)();
}

const koleksiyonSec = koleksiyonSeciciyiCek();

const k = (id, name, { poster = true, original } = {}) => ({
  id,
  name,
  original_name: original ?? name,
  poster_path: poster ? `/p${id}.jpg` : null,
});

test('YÜZÜKLERİN EFENDİSİ: yapım belgeseli koleksiyonu SEÇİLMEZ', () => {
  // TMDB'nin gerçek sonuç sırası (13 Ağu canlı ölçüm): belgesel önde geldi.
  const sonuclar = [
    k(1, 'The Making of The Lord of the Rings Collection'),
    k(119, 'The Lord of the Rings Collection'),
  ];
  assert.equal(koleksiyonSec(sonuclar, 'The Lord of the Rings').id, 119);
});

test('belgesel/derleme kalıpları elenir (birden çok biçim)', () => {
  for (const kotu of [
    'Behind the Scenes of Alien',
    'Alien Documentary Collection',
    'Alien Belgesel Koleksiyonu',
  ]) {
    const s = [k(1, kotu), k(8091, 'Alien Collection')];
    assert.equal(koleksiyonSec(s, 'Alien').id, 8091, `elenmedi: ${kotu}`);
  }
});

test('TAM eşleşme, sadece başlayana yeğlenir', () => {
  const sonuclar = [
    k(2, 'Star Wars: The Clone Wars Collection'),
    k(10, 'Star Wars Collection'),
  ];
  assert.equal(koleksiyonSec(sonuclar, 'Star Wars').id, 10);
});

test('Türkçe koleksiyon adı da tam eşleşme sayılır', () => {
  // Uç `dil=tr` ile çağrılıyor: TMDB adları çevrilmiş gelir.
  const sonuclar = [
    k(3, 'Harry Potter Hayran Filmleri'),
    k(1241, 'Harry Potter Koleksiyonu'),
  ];
  assert.equal(koleksiyonSec(sonuclar, 'Harry Potter').id, 1241);
});

test('eşit puanda POSTERLİ olan seçilir (ızgarada boş kutu olmasın)', () => {
  const sonuclar = [
    k(4, 'Rocky Collection', { poster: false }),
    k(1575, 'Rocky Collection'),
  ];
  assert.equal(koleksiyonSec(sonuclar, 'Rocky').id, 1575);
});

test('HEPSİ eleme kalıbına uyuyorsa yine de bir sonuç döner (boş ekran yok)', () => {
  const sonuclar = [k(5, 'The Making of Something Collection')];
  assert.equal(koleksiyonSec(sonuclar, 'Something')?.id, 5);
});

test('boş/bozuk girdi çökertmez', () => {
  assert.equal(koleksiyonSec([], 'Alien'), null);
  assert.equal(koleksiyonSec(null, 'Alien'), null);
  assert.equal(koleksiyonSec([{ ad: 'idsiz' }], 'Alien'), null);
});

test('KAYNAK KİLİDİ: uç eski "ilk posterli sonucu al" kuralına dönmesin', () => {
  assert.ok(
    !/sonuclar\.find\(\(r\) => r\?\.id && r\.poster_path\)/.test(KAYNAK),
    'koleksiyon seçimi elle "ilk posterli" kuralına geri dönmüş',
  );
  assert.match(KAYNAK, /const bulunan = koleksiyonSec\(sonuclar, ad\);/);
});
