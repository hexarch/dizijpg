// Kişiye (oyuncu/yönetmen) emoji tepkisi testleri — `node --test test/*.test.js`
//
// KORUNAN KARARLAR (12 Ağu 2026, migrasyon-2026-08-12.sql):
//
//  1) `tepkiler.tur` artık 'person' KABUL EDER. Kullanıcı isteği: "oyuncuları
//     da unutma, puan gibi emoji verilen her yerde" — `puanlar`, `yorumlar` ve
//     `favoriler` 'person'ı çoktan kabul ediyordu, tepkiler geride kalmıştı.
//  2) BÖLÜM YALNIZ DİZİDE OLUR. Kişiye/filme sezon+bolum gönderilirse istek
//     SESSİZCE YOK SAYILMAZ, 400 döner (`tepkiHedef` null verir). Sessiz yok
//     sayma, kullanıcının kişi tepkisini yanlış hedefe yazıp sayacı doğru
//     sanmasına yol açardı. Veritabanı tarafında da aynı kural CHECK'lidir.
//  3) TÜR LİSTESİ PAYLAŞILMAZ: /durum, /kaynak, /izleme/* uçları kişiyi kabul
//     ETMEMELİDİR (kişi izlenmez, kişinin platformu olmaz). Aşağıdaki test
//     bu uçların kendi ['tv','movie'] listelerini koruduğunu denetler.
//  4) MİGRASYON İDEMPOTENT ve VERİ YAZMAZ: yalnız CHECK kısıtı DROP+ADD.
//
// Neden kaynak okuma: `server.js` içe aktarıldığı anda `app.listen` çağırıyor
// (bolum_puani.test.js / seo_gizlilik.test.js ile aynı gerekçe). Saf yardımcı
// `tepkiHedef` kaynaktan ÇEKİLİP gerçekten ÇALIŞTIRILIYOR — test canlıdaki
// kodu sınar, kopyasını değil.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const oku = (a) => fs.readFileSync(path.join(KOK, a), 'utf8');

const KAYNAK = oku('server.js');
const SEMA = oku('sema.sql');
const MIGRASYON = oku('migrasyon-2026-08-12.sql');

// Migrasyonun YORUM OLMAYAN satırları: gerekçe metinleri komut sanılmasın
// (geri alma bölümü bilerek DELETE/DROP örneği içerir).
const KOMUTLAR = MIGRASYON.split('\n')
  .filter((s) => !s.trim().startsWith('--')).join('\n');

// ---------------------------------------------------------------------------
// Kaynaktan bildirim çekme (bolum_puani.test.js'teki kalıp)
// ---------------------------------------------------------------------------
function bildirimCek(kaynak, ad) {
  const m = new RegExp(`^(const|function) ${ad}\\b`, 'm').exec(kaynak);
  assert.ok(m, `${ad} bildirimi bulunamadı`);
  const bas = m.index;
  const fonksiyon = m[1] === 'function';
  let derinlik = 0;
  let girdi = false;
  for (let i = bas; i < kaynak.length; i++) {
    const c = kaynak[i];
    if (c === '{' || c === '(' || c === '[') { derinlik++; girdi = true; } else if (c === '}' || c === ')' || c === ']') {
      derinlik--;
      if (fonksiyon && girdi && derinlik === 0 && c === '}') {
        return kaynak.slice(bas, i + 1);
      }
    } else if (!fonksiyon && c === ';' && derinlik === 0) {
      return kaynak.slice(bas, i + 1);
    }
  }
  assert.fail(`${ad} bildiriminin sonu bulunamadı`);
}

const hedefCek = (ad) => new Function(
  `${bildirimCek(KAYNAK, 'gecerliTmdb')}\n${bildirimCek(KAYNAK, ad)}\nreturn ${ad};`,
)();
const tepkiHedef = hedefCek('tepkiHedef');
const puanHedef = hedefCek('puanHedef');

/** `app.post('/x'` ya da `app.get('/x'` ucunun gövdesi. */
function ucGovdesi(yol, yontem = 'post') {
  const m = new RegExp(
    `app\\.${yontem}\\('${yol.replace(/[/:]/g, (c) => (c === '/' ? '\\/' : c))}'[\\s\\S]*?\\n\\}\\)\\);`,
  ).exec(KAYNAK);
  assert.ok(m, `${yontem.toUpperCase()} ${yol} ucu bulunamadı`);
  return m[0];
}

// ---------------------------------------------------------------------------
// 1) ŞEMA
// ---------------------------------------------------------------------------
test('ŞEMA: tepkiler.tur person kabul ediyor (puanlar ile aynı küme)', () => {
  const govde = /CREATE TABLE IF NOT EXISTS tepkiler \(([\s\S]*?)\n\);/.exec(SEMA);
  assert.ok(govde, 'sema.sql içinde tepkiler tablosu bulunamadı');
  assert.match(govde[1], /tur TEXT NOT NULL CHECK \(tur IN \('tv','movie','person'\)\)/,
    "tepkiler.tur 'person' kabul etmiyor");
  // Emoji listesi ve tekil indeks bozulmamalı (kişi başına da tek tepki).
  assert.match(govde[1], /emoji TEXT NOT NULL CHECK \(emoji IN \(/);
  assert.match(SEMA, /CREATE UNIQUE INDEX IF NOT EXISTS tepkiler_tekil\s*\n?\s*ON tepkiler \(kullanici_id, tur, tmdb_id, COALESCE\(sezon,-1\), COALESCE\(bolum,-1\)\)/);
});

test('ŞEMA: kişiye/filme sezon CHECK ile imkânsız (puanlar kalıbı)', () => {
  assert.match(SEMA, /tepkiler_bolum_ciftli CHECK \(\(sezon IS NULL\) = \(bolum IS NULL\)\)/);
  assert.match(SEMA, /tepkiler_bolum_yalniz_tv CHECK \(sezon IS NULL OR tur = 'tv'\)/);
  assert.match(SEMA, /tepkiler_bolum_pozitif\s*\n?\s*CHECK \(sezon IS NULL OR \(sezon >= 0 AND bolum >= 0\)\)/);
  // `puanlar` ile aynı ifadeler olmalı: iki tabloda ayrışan kural = sürpriz.
  for (const ad of ['bolum_ciftli', 'bolum_yalniz_tv', 'bolum_pozitif']) {
    assert.ok(SEMA.includes(`puanlar_${ad}`) && SEMA.includes(`tepkiler_${ad}`),
      `${ad} kısıtı iki tablodan birinde yok`);
  }
});

// ---------------------------------------------------------------------------
// 2) MİGRASYON
// ---------------------------------------------------------------------------
test('MİGRASYON: tür CHECK’i DROP+ADD ile değişiyor, ad sema.sql ile aynı', () => {
  assert.match(KOMUTLAR,
    /ALTER TABLE tepkiler DROP CONSTRAINT IF EXISTS tepkiler_tur_check;/);
  assert.match(KOMUTLAR,
    /ALTER TABLE tepkiler ADD CONSTRAINT tepkiler_tur_check\s*\n?\s*CHECK \(tur IN \('tv','movie','person'\)\);/);
  // Bölüm kısıtları da aynı dosyada kuruluyor.
  for (const ad of ['tepkiler_bolum_ciftli', 'tepkiler_bolum_yalniz_tv',
    'tepkiler_bolum_pozitif']) {
    assert.match(KOMUTLAR, new RegExp(`ADD CONSTRAINT ${ad}\\b`), `${ad} eklenmiyor`);
  }
});

test('MİGRASYON: İDEMPOTENT — her ADD CONSTRAINT’in DROP IF EXISTS eşi var', () => {
  const eklenen = [...KOMUTLAR.matchAll(/ADD CONSTRAINT (\w+)/g)].map((m) => m[1]);
  const dusurulen = new Set(
    [...KOMUTLAR.matchAll(/DROP CONSTRAINT IF EXISTS (\w+)/g)].map((m) => m[1]),
  );
  assert.ok(eklenen.length >= 4, `beklenenden az kısıt eklenmiş: ${eklenen.length}`);
  for (const ad of eklenen) {
    assert.ok(dusurulen.has(ad),
      `${ad} önce DROP CONSTRAINT IF EXISTS ile düşürülmüyor — ikinci çalıştırma 42710 verir`);
  }
  // Koşulsuz DROP yok (dosya yarıda kalıp yeniden çalıştırılabilmeli).
  assert.doesNotMatch(KOMUTLAR, /DROP CONSTRAINT (?!IF EXISTS)/,
    'IF EXISTS’siz DROP CONSTRAINT idempotentliği bozar');
});

test('MİGRASYON: mevcut tepkileri BOZMAZ (veri yazmaz/silmez)', () => {
  for (const yasak of [/\bDELETE\s+FROM\b/i, /\bUPDATE\s+tepkiler\b/i,
    /\bINSERT\s+INTO\b/i, /\bDROP\s+TABLE\b/i, /\bTRUNCATE\b/i,
    /\bDROP\s+COLUMN\b/i, /\bDROP\s+INDEX\b/i]) {
    assert.doesNotMatch(KOMUTLAR, yasak, `migrasyon veri/şema kaybettiriyor: ${yasak}`);
  }
  // Eski satır kuralı bozarsa dağıtım DÜŞMESİN: kısıtlar NOT VALID eklenir,
  // doğrulama ancak temizse yapılır.
  assert.match(KOMUTLAR, /NOT VALID;/);
  assert.match(KOMUTLAR, /VALIDATE CONSTRAINT tepkiler_bolum_yalniz_tv;/);
  // Tür CHECK'i genişlediği için NOT VALID GEREKMEZ (eski satırlar zaten geçer).
  assert.doesNotMatch(KOMUTLAR,
    /ADD CONSTRAINT tepkiler_tur_check[\s\S]{0,120}NOT VALID/);
});

test('MİGRASYON: GERİ ALMA yolu dosyanın başında yazılı', () => {
  // İlk KOMUT satırına kadarki başlık (satır başındaki ALTER); gerekçe
  // metinlerinin içinde de "ALTER TABLE" geçiyor, oradan kesilemez.
  const bas = MIGRASYON.slice(0, MIGRASYON.search(/^ALTER TABLE/m));
  assert.match(bas, /GERİ ALMA \(rollback\)/, 'geri alma bölümü yok');
  assert.match(bas, /CHECK \(tur IN \('tv','movie'\)\)/,
    'geri almada dar CHECK geri konmuyor');
  assert.match(bas, /DELETE FROM tepkiler WHERE tur = 'person'/,
    'geri almada kişi satırları temizlenmiyor — dar CHECK 23514 verir');
});

// ---------------------------------------------------------------------------
// 3) HEDEF DOĞRULAMA (tepkiHedef canlı koddan çalıştırılıyor)
// ---------------------------------------------------------------------------
test('HEDEF: kişi tepkisi KABUL (sezon/bolum yok)', () => {
  assert.deepEqual(tepkiHedef({ tur: 'person', tmdb_id: 287 }),
    { tur: 'person', tmdb_id: 287, sezon: null, bolum: null });
});

test('HEDEF: dizi/film/bölüm davranışı AYNEN korunuyor', () => {
  assert.deepEqual(tepkiHedef({ tur: 'tv', tmdb_id: 1399 }),
    { tur: 'tv', tmdb_id: 1399, sezon: null, bolum: null });
  assert.deepEqual(tepkiHedef({ tur: 'movie', tmdb_id: 550 }),
    { tur: 'movie', tmdb_id: 550, sezon: null, bolum: null });
  assert.deepEqual(tepkiHedef({ tur: 'tv', tmdb_id: 1399, sezon: 1, bolum: 9 }),
    { tur: 'tv', tmdb_id: 1399, sezon: 1, bolum: 9 });
  // sezon 0 = özel bölümler sezonu, gerçek bir değer.
  assert.deepEqual(tepkiHedef({ tur: 'tv', tmdb_id: 1399, sezon: 0, bolum: 0 }),
    { tur: 'tv', tmdb_id: 1399, sezon: 0, bolum: 0 });
});

test('HEDEF: KİŞİYE sezon/bolum ile tepki REDDEDİLİR (sessizce yutulmaz)', () => {
  assert.equal(tepkiHedef({ tur: 'person', tmdb_id: 287, sezon: 1, bolum: 1 }), null);
  assert.equal(tepkiHedef({ tur: 'person', tmdb_id: 287, sezon: 0, bolum: 0 }), null);
  assert.equal(tepkiHedef({ tur: 'person', tmdb_id: 287, sezon: 1 }), null);
  assert.equal(tepkiHedef({ tur: 'person', tmdb_id: 287, bolum: 1 }), null);
  // Filmin de bölümü yoktur (puanlar ile aynı kural).
  assert.equal(tepkiHedef({ tur: 'movie', tmdb_id: 550, sezon: 1, bolum: 1 }), null);
});

test('HEDEF: saçma değerler ve bilinmeyen tür REDDEDİLİR', () => {
  assert.equal(tepkiHedef({ tur: 'tv', tmdb_id: 1399, sezon: 1 }), null);
  assert.equal(tepkiHedef({ tur: 'tv', tmdb_id: 1399, sezon: -1, bolum: 1 }), null);
  assert.equal(tepkiHedef({ tur: 'tv', tmdb_id: 1399, sezon: 1.5, bolum: 1 }), null);
  assert.equal(tepkiHedef({ tur: 'tv', tmdb_id: 1399, sezon: '1', bolum: '1' }), null);
  assert.equal(tepkiHedef({ tur: 'kisi', tmdb_id: 287 }), null);
  assert.equal(tepkiHedef({ tur: 'person', tmdb_id: 0 }), null);
  assert.equal(tepkiHedef({ tur: 'person', tmdb_id: '287' }), null);
  assert.equal(tepkiHedef(null), null);
});

test('HEDEF: `puanHedef` ile BİREBİR aynı sözleşme', () => {
  for (const tur of ['tv', 'movie', 'person', 'dizi']) {
    for (const g of [
      { tur, tmdb_id: 1399 },
      { tur, tmdb_id: 1399, sezon: 2, bolum: 3 },
      { tur, tmdb_id: 1399, sezon: 0, bolum: 0 },
      { tur, tmdb_id: 1399, sezon: 2 },
      { tur, tmdb_id: 1399, sezon: -5, bolum: 1 },
      { tur, tmdb_id: -1 },
    ]) {
      assert.deepEqual(tepkiHedef(g), puanHedef(g),
        `hedef sözleşmesi ayrıştı: ${JSON.stringify(g)}`);
    }
  }
});

// ---------------------------------------------------------------------------
// 4) UÇLAR — geçersiz hedef 400 döner (sessiz düzeltme yok)
// ---------------------------------------------------------------------------
test('UÇ: POST /tepki geçersiz hedefte 400 (kişi+sezon dâhil)', () => {
  const govde = ucGovdesi('/tepki');
  assert.match(govde, /const hedef = tepkiHedef\(req\.body\);/);
  assert.match(govde, /if \(!hedef\) return res\.status\(400\)/);
  // sezon/bolum doğrudan gövdeden değil, DOĞRULANMIŞ hedeften yazılmalı.
  assert.match(govde, /INSERT INTO tepkiler \(kullanici_id, tur, tmdb_id, sezon, bolum, emoji\)/);
  assert.match(govde, /hedef\.sezon, hedef\.bolum, emoji/);
  assert.doesNotMatch(govde, /req\.body\.sezon/,
    'sezon gövdeden okunuyor — tepkiHedef doğrulaması atlanır');
});

test('UÇ: GET /tepkiler/:tur/:tmdbId aynı doğrulamadan geçiyor', () => {
  const govde = ucGovdesi('/tepkiler/:tur/:tmdbId', 'get');
  assert.match(govde, /const hedef = tepkiHedef\(\{/);
  assert.match(govde, /if \(!hedef\) return res\.status\(400\)/);
  assert.match(govde, /tur: req\.params\.tur/);
});

// ---------------------------------------------------------------------------
// 5) YAYILMA YOK — 'person' yalnız tepkiye eklendi
// ---------------------------------------------------------------------------
test('DİĞER UÇLAR: kişi izlenmez / kişinin platformu olmaz — hâlâ tv+movie', () => {
  for (const [yol, yontem] of [['/durum', 'post'], ['/kaynak', 'post'],
    ['/izleme/toggle', 'post']]) {
    const govde = ucGovdesi(yol, yontem);
    assert.match(govde, /\['tv', 'movie'\]\.includes\(tur\)/,
      `${yol} kendi tür listesini kaybetmiş`);
    assert.doesNotMatch(govde, /'person'/,
      `${yol} kişiyi kabul ediyor — tepki değişikliği sızmış`);
  }
});

test('TÜR LİSTESİ PAYLAŞILAN SABİT DEĞİL (sızma imkânsız)', () => {
  // Ortak bir TURLER sabiti olsaydı tepkiye 'person' eklemek /durum'u da
  // açardı. Uçlar listeyi satır içi yazar; sayı düşerse burada durulur.
  const satirIci = [...KAYNAK.matchAll(/\['tv', 'movie'\]\.includes/g)].length;
  assert.ok(satirIci >= 10,
    `satır içi ['tv', 'movie'] listeleri kaybolmuş (${satirIci}) — paylaşılan sabite mi dönüştü?`);
  const tepki = bildirimCek(KAYNAK, 'tepkiHedef');
  assert.match(tepki, /\['tv', 'movie', 'person'\]\.includes\(tur\)/,
    'tepkiHedef tür listesi kendi içinde olmalı');
});
