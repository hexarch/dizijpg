// TMDB proxy — YAPIM FİRMASI yolları (madde 49).
//
// Uygulamanın firma sayfası iki uca dayanıyor:
//   * `/tmdb/company/{id}`                       → firma künyesi
//   * `/tmdb/discover/(tv|movie)?with_companies=` → firmanın yapımları
// İkisi de `TMDB_IZINLI` beyaz listesinden geçmezse uç 403 döner ve ekran
// "Tekrar Dene"den ibaret kalır. Beyaz liste EN DAR biçimde açıldı: yalnız
// `/company/<sayı>`; alt yollar (`/company/1/movies`, `/company/1/images`)
// ve sayı olmayan id'ler dışarıda kalmalı.
//
// Neden kaynak okuma: `server.js` içe aktarıldığı anda `app.listen` çağırıyor
// (seo_gizlilik.test.js ile aynı gerekçe). Beyaz liste kaynaktan ÇEKİLİP
// gerçekten ÇALIŞTIRILIYOR — test canlıdaki diziyi sınar, kopyasını değil.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const KAYNAK = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');

/** `const ad = ...;` bildiriminin tam metni. */
function bildirimCek(ad) {
  const m = new RegExp(`^const ${ad}\\b`, 'm').exec(KAYNAK);
  assert.ok(m, `server.js içinde ${ad} bildirimi bulunamadı`);
  let derinlik = 0;
  for (let i = m.index; i < KAYNAK.length; i++) {
    const c = KAYNAK[i];
    if (c === '[' || c === '(' || c === '{') derinlik++;
    else if (c === ']' || c === ')' || c === '}') derinlik--;
    else if (c === ';' && derinlik === 0) return KAYNAK.slice(m.index, i + 1);
  }
  assert.fail(`${ad} bildiriminin sonu bulunamadı`);
}

const TMDB_IZINLI = new Function(
  `${bildirimCek('TMDB_IZINLI')}\nreturn TMDB_IZINLI;`,
)();

const izinli = (yol) => TMDB_IZINLI.some((r) => r.test(yol));

test('firma künyesi izinli', () => {
  assert.ok(izinli('/company/11073'));
  assert.ok(izinli('/company/1'));
});

test('beyaz liste EN DAR: alt yollar ve sayı olmayan id yasak', () => {
  for (const yol of [
    '/company/11073/movies',
    '/company/11073/images',
    '/company/abc',
    '/company/',
    '/company',
    '/company/11073/alt-liste',
    '/companies/11073',
  ]) {
    assert.equal(izinli(yol), false, `${yol} açılmamalıydı`);
  }
});

test('sezon ve bölüm videoları izinli (fragman)', () => {
  assert.ok(izinli('/tv/1396/season/1/videos'));
  assert.ok(izinli('/tv/1396/season/1/episode/1/videos'));
  assert.equal(izinli('/tv/1396/season/1/episode/1/videos/x'), false);
  assert.equal(izinli('/tv/1396/season/videos'), false);
});

test('firma yapımları için discover zaten izinli (yeni uç gerekmedi)', () => {
  assert.ok(izinli('/discover/movie'));
  assert.ok(izinli('/discover/tv'));
  // Sorgu dizesi yola dahil DEĞİL (server.js `req.path` ile eşleştirir), bu
  // yüzden `with_companies` ayrıca açılmak zorunda değil.
  assert.equal(izinli('/discover/person'), false);
});

test('beyaz liste hâlâ kapalı bir liste (genel kaçış yok)', () => {
  for (const yol of [
    '/configuration',
    '/account',
    '/authentication/token/new',
    '/../company/1',
  ]) {
    assert.equal(izinli(yol), false, `${yol} açılmamalıydı`);
  }
});

test('firma künyesi UZUN TTL kademesinde (arama kademesinde değil)', () => {
  // Firma adı/logosu/ülkesi pratikte hiç değişmez → 7 günlük katalog TTL'i.
  const m = /const uzunTtl = (\/\^[^;]+\/)\.test\(yol\);/.exec(KAYNAK);
  assert.ok(m, 'uzunTtl bildirimi bulunamadı');
  const desen = new Function(`return ${m[1]};`)();
  assert.ok(desen.test('/company/11073'), 'company uzun TTL almıyor');
  assert.ok(desen.test('/tv/1396'));
  // `/discover/*` KASITLA dışarıda: yapım listesi yeni içerikle değişir.
  assert.equal(desen.test('/discover/movie'), false);
  // Arama kademesi (onbellek_ttl.js) yalnız /search ve /find için.
  assert.ok(/const aramaMi = \/\^\\\/\(search\|find\)\\\/\/\.test\(yol\);/.test(KAYNAK));
});
