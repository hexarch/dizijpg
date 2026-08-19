// LİSTE DÜZENLEME MODU — elle sıra + öğe gizleme (19 Ağu 2026)
//
// İSTEK: "liste isminin yanında edit ikonu... sürükle bırak ile sırayı
// değiştirebilsin, istediğini gizleyebilsin, listeden kaldırabilsin."
//
// KORUNAN KARARLAR
//  1) GİZLİ ÖĞE TEL ÜZERİNDE GİTMEZ. `GET /listeler/:id` gizlileri yalnız
//     SAHİBİNE gönderir; süzgeç SQL'de (`AND NOT gizli`). İstemcide süzmek,
//     ağ sekmesine bakan herkese gizlenen yapımı okutmak olurdu.
//  2) SIRALAMA `sira ASC NULLS FIRST, eklenme DESC`. NULLS FIRST ŞART:
//     hiç düzenlenmemiş liste ESKİSİ GİBİ (en yeni önce) görünmeli, sessizce
//     yeniden sıralanmamalı.
//  3) SIRA TAM LİSTE OLARAK YAZILIR ve TEK SORGUDA. Tekil "şunu şuraya taşı"
//     komutları eşzamanlı iki cihazda birbirinin üstüne biner; N ayrı UPDATE
//     ise istek ortada kesilirse YARISI uygulanmış sıra bırakır.
//  4) SAHİPLİK KAPISI: başkasının listesi 404 (403 değil — listenin varlığını
//     bile sızdırmayalım, gizli liste zaten 404 veriyor).
//  5) GİRDİ DOĞRULAMA: tur beyaz listede, tmdb_id geçerli, `gizli` boolean.
//
// Neden kaynak okuma: `server.js` içe aktarıldığı anda `app.listen` çağırıyor
// (kisi_tepkisi.test.js / seo_gizlilik.test.js ile aynı gerekçe). Saf yardımcı
// `listeOgesiGecerli` kaynaktan ÇEKİLİP gerçekten ÇALIŞTIRILIYOR.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const oku = (a) => fs.readFileSync(path.join(KOK, a), 'utf8');

const KAYNAK = oku('server.js');
const SEMA = oku('sema.sql');
const MIGRASYON = oku('migrasyon-2026-08-19b.sql');

/** Migrasyonun YORUM OLMAYAN satırları: gerekçe metni komut sanılmasın. */
const KOMUTLAR = MIGRASYON.split('\n')
  .filter((s) => !s.trim().startsWith('--')).join('\n');

/** Bir uç bloğunun gövdesini kaynaktan çeker. */
function ucGovdesi(yol, metot = 'post') {
  const im = `app.${metot}('${yol}'`;
  const bas = KAYNAK.indexOf(im);
  assert.ok(bas >= 0, `${metot.toUpperCase()} ${yol} bulunamadı`);
  // Bir sonraki `app.<metot>(` ya da dosya sonu: kaba ama yeterli sınır.
  const sonraki = KAYNAK.slice(bas + im.length).search(/\napp\.[a-z]+\('/);
  return sonraki < 0 ? KAYNAK.slice(bas) : KAYNAK.slice(bas, bas + im.length + sonraki);
}

// ---------------------------------------------------------------------------
// MİGRASYON
// ---------------------------------------------------------------------------
test('migrasyon iki sütunu da IF NOT EXISTS ile ekler (idempotent)', () => {
  assert.match(KOMUTLAR, /ADD COLUMN IF NOT EXISTS sira INT/);
  assert.match(KOMUTLAR, /ADD COLUMN IF NOT EXISTS gizli BOOLEAN NOT NULL DEFAULT false/);
});

test('migrasyon VERİ YAZMAZ: mevcut satırlara sıra atanmıyor', () => {
  // `sira` bilerek NULL bırakılıyor — atanmış olsaydı düzenlenmemiş listeler
  // sessizce yeniden sıralanırdı.
  assert.doesNotMatch(KOMUTLAR, /UPDATE\s+liste_ogeleri/i);
  assert.doesNotMatch(KOMUTLAR, /DEFAULT\s+0/i);
});

test('migrasyon işlem içinde (BEGIN/COMMIT)', () => {
  assert.match(KOMUTLAR, /BEGIN;/);
  assert.match(KOMUTLAR, /COMMIT;/);
});

test('sema.sql migrasyonla AYNI iki sütunu taşır', () => {
  const tablo = SEMA.slice(
    SEMA.indexOf('CREATE TABLE IF NOT EXISTS liste_ogeleri'),
  ).split(');')[0];
  assert.match(tablo, /\bsira INT\b/);
  assert.match(tablo, /\bgizli BOOLEAN NOT NULL DEFAULT false\b/);
});

// ---------------------------------------------------------------------------
// OKUMA UCU
// ---------------------------------------------------------------------------
test('GET /listeler/:id gizlileri YALNIZ sahibine gönderir', () => {
  const govde = ucGovdesi('/listeler/:id', 'get');
  assert.match(govde, /sahibiyim/);
  // Süzgeç SQL'de olmalı: istemciye gönderip orada saklamak sızıntıdır.
  assert.match(govde, /AND NOT gizli/);
  assert.match(
    govde,
    /sahibiyim\s*\?\s*''\s*:\s*'AND NOT gizli'/,
    'gizli süzgeci sahiplik koşuluna bağlı değil',
  );
});

test('GET /listeler/:id sıralaması NULLS FIRST + eklenme DESC', () => {
  const govde = ucGovdesi('/listeler/:id', 'get');
  assert.match(
    govde,
    /ORDER BY sira ASC NULLS FIRST, eklenme DESC/,
    'düzenlenmemiş liste eski sırasını kaybediyor',
  );
});

test('GET /listeler/:id sira ve gizli alanlarını DÖNER', () => {
  const govde = ucGovdesi('/listeler/:id', 'get');
  assert.match(govde, /SELECT tmdb_id, tur, eklenme, sira, gizli/);
});

test('sahiplik geçersiz token`da FALSE tarafına düşer', () => {
  const govde = ucGovdesi('/listeler/:id', 'get');
  // `!!req.kullanici &&` şart: girisIsteğeBagli süresi dolmuş token'da
  // req.kullanici'yi boş bırakır ve `undefined === id` yanlışlıkla true
  // dönemez ama açık kontrol niyeti belgeler.
  assert.match(govde, /!!req\.kullanici && req\.kullanici\.id === liste\.rows\[0\]\.kullanici_id/);
});

// ---------------------------------------------------------------------------
// SIRA UCU
// ---------------------------------------------------------------------------
test('PUT /listeler/:id/sira giriş ZORUNLU ve sahiplik kapısı var', () => {
  const govde = ucGovdesi('/listeler/:id/sira', 'put');
  assert.match(govde, /girisZorunlu/);
  assert.match(
    govde,
    /SELECT 1 FROM listeler WHERE id=\$1 AND kullanici_id=\$2/,
    'başkasının listesi sıralanabiliyor',
  );
  assert.match(govde, /status\(404\)/, 'sahip değilse 404 dönmüyor');
});

test('PUT sira TEK sorguda yazar (yarım uygulanmış sıra olmasın)', () => {
  const govde = ucGovdesi('/listeler/:id/sira', 'put');
  assert.match(govde, /UPDATE liste_ogeleri o SET sira = v\.sira/);
  assert.match(govde, /FROM \(VALUES \$\{satirlar\.join\(','\)\}\)/);
  // Döngü içinde sorgu ATILMAMALI.
  assert.doesNotMatch(
    govde.replace(/`[^`]*`/gs, ''), // SQL şablonlarını çıkar
    /for\s*\(.*havuz\.query/s,
  );
});

test('PUT sira: boş/aşırı uzun/geçersiz gövde 400', () => {
  const govde = ucGovdesi('/listeler/:id/sira', 'put');
  assert.match(govde, /Array\.isArray\(ham\)/);
  assert.match(govde, /ham\.length > 2000/, 'öğe sayısı tavanı yok');
  assert.match(govde, /ham\.every\(listeOgesiGecerli\)/);
});

// CANLIDA ÖLÇÜLEN TUZAK (19 Ağu 2026): 8 öğelik listeye 4 öğelik sıra
// yazıldığında yazılanlar sira=0..3 alıyor, kalan 4'ü NULL kalıyor ve
// `NULLS FIRST` onları BAŞA taşıyor — kullanıcının sıraladığı öğeler listenin
// SONUNA düşüyordu. Uygulama hep tam listeyi gönderiyor ama sözleşme bunu
// söylemiyordu.
test('PUT sira EKSİK liste kabul ETMEZ (kısmi yazım sırayı bozar)', () => {
  const govde = ucGovdesi('/listeler/:id/sira', 'put');
  assert.match(
    govde,
    /SELECT count\(\*\)::int AS adet FROM liste_ogeleri WHERE liste_id=\$1/,
    'liste uzunluğu sayılmıyor',
  );
  assert.match(
    govde,
    /ham\.length !== sayim\.rows\[0\]\.adet/,
    'kısmi sıralama reddedilmiyor',
  );
});

// ---------------------------------------------------------------------------
// GİZLE UCU
// ---------------------------------------------------------------------------
test('POST /listeler/:id/oge/gizle sahiplik + gizli tip denetimi', () => {
  const govde = ucGovdesi('/listeler/:id/oge/gizle', 'post');
  assert.match(govde, /girisZorunlu/);
  assert.match(govde, /l\.kullanici_id=\$2/, 'sahiplik kapısı yok');
  assert.match(govde, /typeof gizli !== 'boolean'/, 'gizli tipi denetlenmiyor');
  assert.match(govde, /rowCount/, 'eşleşme yoksa 404 dönmüyor');
});

test('gizle ucu SİLMEZ: öğe listede kalır', () => {
  const govde = ucGovdesi('/listeler/:id/oge/gizle', 'post');
  assert.match(govde, /UPDATE liste_ogeleri o SET gizli=/);
  assert.doesNotMatch(govde, /DELETE FROM liste_ogeleri/);
});

// ---------------------------------------------------------------------------
// SAF YARDIMCI — kaynaktan çekilip GERÇEKTEN çalıştırılıyor
// ---------------------------------------------------------------------------
test('listeOgesiGecerli: tür beyaz listesi + tmdb_id doğrulaması', () => {
  const m = /const listeOgesiGecerli = \(o\) =>[\s\S]*?;\n/.exec(KAYNAK);
  assert.ok(m, 'listeOgesiGecerli bulunamadı');
  const gecerliTmdb = (x) => Number.isInteger(x) && x > 0 && x <= 1e9;
  const fn = new Function('gecerliTmdb', `${m[0]}\nreturn listeOgesiGecerli;`)(
    gecerliTmdb,
  );

  assert.equal(fn({ tur: 'tv', tmdb_id: 1396 }), true);
  assert.equal(fn({ tur: 'movie', tmdb_id: 550 }), true);
  // Kişi/şirket listeye giremez: liste yalnız izlenebilir yapım tutar.
  assert.equal(fn({ tur: 'person', tmdb_id: 1 }), false);
  assert.equal(fn({ tur: 'company', tmdb_id: 1 }), false);
  // Dizge tmdb_id SQL'e sayı olarak gitmeli; burada reddedilir.
  assert.equal(fn({ tur: 'tv', tmdb_id: '1396' }), false);
  assert.equal(fn({ tur: 'tv', tmdb_id: 0 }), false);
  assert.equal(fn({ tur: 'tv', tmdb_id: -5 }), false);
  assert.equal(fn({ tur: 'tv', tmdb_id: 1.5 }), false);
  assert.equal(fn(null), false);
  assert.equal(fn({}), false);
});
