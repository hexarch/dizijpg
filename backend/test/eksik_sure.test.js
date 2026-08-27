// Admin paneli · EKSİK SÜRELER (22 Ağu 2026 isteği) — `node --test`
//
// İSTEK (birebir): "admin panelinde hangi dizilerin filmlerin dakikalarını
// bilmiyoruz onları listele görebilelim biz gidip bakıp ekleriz."
//
// Bu testler üç şeyi korur:
//   1. YETKİ + PAYLAŞILAN SQL — iki uç da `adminKisit` arkasında ve süre
//      JOIN'i kopyalanmadan `SURE_KAYNAK_JOIN` sabitinden geliyor (kopya
//      sürüklenmesi bu projede bir kez yaşandı, bkz. gercek_sure.test.js).
//   2. ELLE GİRİŞ GERÇEĞİ EZEMEZ — INSERT'ler `ON CONFLICT ... DO NOTHING`:
//      TMDB'den türetilmiş satırın üstüne insan değeri yazılamaz; tersi
//      (sure_doldur.js'in elle satırı ezmesi) serbesttir ve DO UPDATE onda.
//   3. ŞEMA — 'elle' kaynağı migrasyonda VE sema.sql'de birlikte tanımlı;
//      dakika sınırı uçta da tabloda da aynı (1..1000).
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
const ADMIN = fs.readFileSync(path.join(KOK, 'admin.html'), 'utf8');
const SEMA = fs.readFileSync(path.join(KOK, 'sema.sql'), 'utf8');
const MIGRASYON = fs.readFileSync(path.join(KOK, 'migrasyon-2026-08-23.sql'), 'utf8');

// Uçların gövdelerini kabaca kes: bir sonraki `app.` kaydına kadar.
function ucGovdesi(yol) {
  const i = SERVER.indexOf(yol);
  assert.ok(i > -1, `${yol} server.js'te yok`);
  const son = SERVER.indexOf('\napp.', i);
  return SERVER.slice(i, son === -1 ? undefined : son);
}

test('iki uç da var ve adminKisit arkasında', () => {
  assert.match(SERVER, /app\.get\('\/admin\/eksik-sureler', adminKisit/);
  assert.match(SERVER, /app\.post\('\/admin\/eksik-sure', adminKisit/);
});

test('liste ucu paylaşılan SURE_KAYNAK_JOIN sabitini kullanıyor, kopya yok', () => {
  const g = ucGovdesi("app.get('/admin/eksik-sureler'");
  assert.ok(g.includes('${SURE_KAYNAK_JOIN}'), 'JOIN sabitten gelmeli');
  assert.ok(!/LEFT JOIN yapim_sureleri/.test(g), 'JOIN metni kopyalanmamalı');
});

test('liste ucu kişi bazlı satır sızdırmaz', () => {
  const g = ucGovdesi("app.get('/admin/eksik-sureler'");
  assert.ok(!/kullanici_id/.test(g),
    'uç yalnız yapım kimliği + sayaç döndürmeli, kullanıcı satırı değil');
});

test('eksik bölüm sayısı bölüm bazında (DISTINCT), kullanıcı çarpımı değil', () => {
  const g = ucGovdesi("app.get('/admin/eksik-sureler'");
  assert.match(g, /count\(DISTINCT \(i\.sezon, i\.bolum\)\) FILTER/,
    'aynı bölümü 40 kişi izlediyse eksik 1 sayılmalı');
});

test('elle giriş: iki INSERT de DO NOTHING — gerçek ölçüm ezilmez', () => {
  const g = ucGovdesi("app.post('/admin/eksik-sure'");
  const adet = (g.match(/ON CONFLICT \(tur, tmdb_id, sezon, bolum\) DO NOTHING/g) || []).length;
  assert.equal(adet, 2, 'film ve dizi INSERT`lerinin ikisi de DO NOTHING olmalı');
  assert.ok(!/DO UPDATE/.test(g), 'elle uç DO UPDATE içermemeli');
});

test('elle giriş: dizide yalnız İZLENMİŞ ve süresiz bölümler doldurulur', () => {
  const g = ucGovdesi("app.post('/admin/eksik-sure'");
  assert.match(g, /FROM izlemeler i/);
  assert.match(g, /s\.dakika IS NULL/);
});

test('doğrulama: tur beyaz listesi + dakika 1..1000 (tablo CHECK ile aynı)', () => {
  const g = ucGovdesi("app.post('/admin/eksik-sure'");
  assert.match(g, /tur !== 'tv' && tur !== 'movie'/);
  assert.match(g, /dakika <= 0 \|\| dakika > 1000/);
  assert.match(SEMA, /dakika > 0 AND dakika <= 1000/);
});

test("şema: 'elle' kaynağı migrasyonda VE sema.sql'de tanımlı", () => {
  assert.match(MIGRASYON, /'film','sezon','bolum','elle'/);
  assert.match(SEMA, /'film','sezon','bolum','elle'/);
});

test('sure_doldur upsert hâlâ DO UPDATE: TMDB gerçeği elle girişi ezebilmeli', () => {
  const DOLDUR = fs.readFileSync(path.join(KOK, 'sure_doldur.js'), 'utf8');
  assert.match(DOLDUR, /ON CONFLICT \(tur, tmdb_id, sezon, bolum\) DO UPDATE/);
});

test('panel: sekme düğmesi, bölüm ve yükleyici bağlı', () => {
  assert.match(ADMIN, /data-sekme="sureler"/);
  assert.match(ADMIN, /id="s-sureler"/);
  assert.match(ADMIN, /if\(s==='sureler'\) sureleriYukle\(\)/);
  assert.match(ADMIN, /min="1" max="1000"/);
});

// 27 Ağu 2026: dizi dalı canlıda 500 veriyordu. `SELECT DISTINCT` içindeki
// TİPSİZ `$2` parse aşamasında `text`e çözülüyor, `dakika int` sütununa
// yazılamıyor (Postgres 42804). Cast olmadan uç HİÇ çalışmaz — 0 satır
// eşleşse bile atar. Bu testler statik; SQL'i çalıştırmadıkları için hatayı
// ancak cast'in VARLIĞINI şart koşarak yakalayabilirler.
test('elle giriş: dizi INSERT`inde $2::int cast`i var (Postgres 42804 koruması)', () => {
  const g = ucGovdesi("app.post('/admin/eksik-sure'");
  assert.match(g, /SELECT DISTINCT 'tv'[\s\S]*?\$2::int/,
    'SELECT DISTINCT içinde tipsiz $2 `text`e çözülür, dakika int sütununa yazılamaz');
});
