// md. 24 — TOPLU İSTATİSTİKLER · `node --test test/*.test.js`
//
// ===========================================================================
// NE KORUNUYOR
// ===========================================================================
//  1. GİZLİLİK — uç YALNIZ kendi verisini döndürür. Sorgular gerçek bir
//     Postgres'te iki kullanıcıyla koşuluyor; birinin sayısı diğerine SIZMAZ.
//  2. KIRILIM SINIRLARI — "son 30 gün" GERÇEKTEN 30 takvim günü mü? Sınıra
//     tam oturan günlerle (0, 29, 30, 59, 60, 89, 90, 119, 120 gün önce)
//     sınanıyor. Kapalı/açık aralık hatası tam da burada gizlenir.
//  3. ÇİFT SAYMAMA — biriktirme görevi aynı gün ikinci kez koşunca delta
//     KATLANMAZ. (`DO UPDATE SET ... = EXCLUDED` vs `= ... + EXCLUDED`.)
//  4. SAHTE VERİ ÜRETİLMEMESİ — ilk (taban) tur ömür boyu sayacı "bugünün
//     artışı" diye YAZMAZ; biriktirmenin başladığı gün `ayarlar`a işlenir.
//  5. ÇIPA — budama bir gönderinin SON satırını silmez; silseydi bir sonraki
//     tur ömür boyu sayacı sahte zirve olarak yazardı.
//  6. VERİ YOKKEN ÇÖKMEME — hiç gönderisi olmayan kullanıcı için sorgular
//     sıfır döner, boş liste döner, patlamaz.
//
// VERİTABANI YOKSA: DB'ye dayanan testler ATLANIR (kaynak metni testleri yine
// koşar). Yerelde Homebrew Postgres'i açıksa kendiliğinden çalışır; geçici bir
// ŞEMA açılır (`CREATE DATABASE` yetkisi gerekmez) ve sonunda düşürülür.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

import {
  GONDERI_PENCERELER, GONDERI_GUNLUK_SAKLAMA, TOPLA_SQL, BUDA_SQL, TOPLAM_SQL,
  GORUNTULENME_PENCERE_SQL, BEGENI_PENCERE_SQL, listeSql, gunFark,
} from '../gonderi_istatistik.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
const SEMA = fs.readFileSync(path.join(KOK, 'sema.sql'), 'utf8');
const MIGRASYON = fs.readFileSync(
  path.join(KOK, 'migrasyon-2026-08-14c.sql'), 'utf8');

// ---------------------------------------------------------------------------
// 0) SAF MANTIK — veritabanı gerekmez
// ---------------------------------------------------------------------------
test('pencereler istenen kırılım: 30/60/90/120', () => {
  assert.deepEqual(GONDERI_PENCERELER, [30, 60, 90, 120]);
});

test('saklama en uzun pencereden UZUN (yoksa 120 günlük sayı eksik çıkar)', () => {
  assert.ok(GONDERI_GUNLUK_SAKLAMA > Math.max(...GONDERI_PENCERELER));
});

test('gunFark: başlangıç günü DAHİL sayılır', () => {
  assert.equal(gunFark('2026-08-13', '2026-08-13'), 1);
  assert.equal(gunFark('2026-08-13', '2026-08-12'), 2);
  assert.equal(gunFark('2026-11-11', '2026-08-13'), 91);
  assert.equal(gunFark('2026-08-13', null), 0, 'başlangıç yoksa 0 gün veri');
});

test('listeSql: sıralama ve pencere BEYAZ LİSTE (SQL enjeksiyonu kapalı)', () => {
  assert.throws(() => listeSql(30, 'y.metin; DROP TABLE yorumlar'), /gecersiz/);
  assert.throws(() => listeSql(45, 'pencere_begeni'), /gecersiz/);
  assert.ok(listeSql(0, 'pencere_goruntulenme').sql.includes('kullanici_id=$1'));
});

test('listeSql: "tümü" seçiliyken sorgu $2 KULLANMAZ', () => {
  const t = listeSql(0, 'pencere_goruntulenme');
  assert.equal(t.parametreliMi, false);
  assert.ok(!t.sql.includes('$2'), 'fazla parametre bind hatası verirdi');
  const p = listeSql(30, 'pencere_goruntulenme');
  assert.equal(p.parametreliMi, true);
  assert.ok(p.sql.includes('$2'));
});

test('"tümü" ölçüsü gonderi_gunluk TOPLAMI DEĞİL, ömür boyu sayaçtır', () => {
  // Taban turu 0 yazdığı için günlük toplam ömür boyu değeri VERMEZ; ikisi
  // karıştırılırsa "tüm zamanlar" listesi yanlış sıralanır.
  const t = listeSql(0, 'pencere_goruntulenme').sql;
  assert.ok(t.includes('y.goruntulenme AS toplam_goruntulenme'));
  assert.ok(!t.includes('gonderi_gunluk'));
});

test('biriktirme ÜZERİNE yazar, ÜSTÜNE EKLEMEZ (çift sayma kalkanı)', () => {
  assert.ok(/SET\s+goruntulenme = EXCLUDED\.goruntulenme/.test(TOPLA_SQL));
  assert.ok(!/goruntulenme\s*=\s*gonderi_gunluk\.goruntulenme\s*\+/.test(TOPLA_SQL),
    'delta toplanırsa ikinci koşu sayıyı KATLAR');
});

test('budama, gönderinin SON satırını (çıpayı) korur', () => {
  assert.ok(/EXISTS\s*\(SELECT 1 FROM gonderi_gunluk n/.test(BUDA_SQL));
});

// ---------------------------------------------------------------------------
// 1) KAYNAK METNİ — uç kapısı ve gizlilik sınırı
// ---------------------------------------------------------------------------
const UC = SERVER.slice(
  SERVER.indexOf("app.get('/istatistiklerim/gonderiler'"),
  SERVER.indexOf("app.get('/istatistiklerim/gonderiler'") + 4000,
);

test('uç girisZorunlu kapısının ARKASINDA', () => {
  assert.ok(SERVER.includes(
    "app.get('/istatistiklerim/gonderiler', girisZorunlu,"));
});

test('uç BAŞKA kullanıcı seçme parametresi kabul etmiyor', () => {
  // `req.query.gun` dışında bir sorgu/yol parametresi okunmamalı; okunsaydı
  // "kullanici=alcelik" ile başkasının performansı çekilebilirdi.
  const okunanlar = [...UC.matchAll(/req\.(query|params|body)\.(\w+)/g)]
    .map((m) => m[2]);
  assert.deepEqual([...new Set(okunanlar)], ['gun']);
  assert.ok(UC.includes('req.kullanici.id'));
});

test('tüm sorgular kullanıcıya bağlı ($1 = kendi id)', () => {
  for (const sql of [TOPLAM_SQL, GORUNTULENME_PENCERE_SQL, BEGENI_PENCERE_SQL,
    listeSql(30, 'pencere_begeni').sql, listeSql(0, 'pencere_begeni').sql]) {
    assert.ok(/kullanici_id=\$1/.test(sql), `süzgeçsiz sorgu:\n${sql}`);
  }
});

test('biriktirme görevi ISCI_GOREVLI kapısında (kümede tek işçi)', () => {
  const i = SERVER.indexOf('setInterval(gonderiGunlukTopla');
  assert.ok(i > 0);
  assert.ok(SERVER.lastIndexOf('if (ISCI_GOREVLI) {', i) > 0);
});

test('şema ve migrasyon aynı tabloyu tarif ediyor', () => {
  for (const metin of [SEMA, MIGRASYON]) {
    assert.match(metin, /CREATE TABLE IF NOT EXISTS gonderi_gunluk/);
    assert.match(metin, /PRIMARY KEY \(gonderi_id, gun\)/);
  }
});

test('yanıt, verinin ne zamandan beri biriktiğini SÖYLER', () => {
  // Ekran "30 günlük veri" derken eksik kapsamı gizlememeli.
  assert.ok(UC.includes('goruntulenme_baslangic'));
  assert.ok(UC.includes('goruntulenme_tam'));
  assert.ok(UC.includes('begeni_tam'));
});

// ---------------------------------------------------------------------------
// 2) GERÇEK POSTGRES — sınırlar, çift sayma, izolasyon
// ---------------------------------------------------------------------------
/** Bağlanabilen ilk yapılandırma (yoksa null → DB testleri atlanır). */
async function baglan() {
  const adaylar = [
    process.env.TEST_DATABASE_URL && { connectionString: process.env.TEST_DATABASE_URL },
    { connectionString: 'postgres://localhost:5432/postgres' },
    { host: '/tmp', database: 'postgres' },
  ].filter(Boolean);
  for (const cfg of adaylar) {
    const c = new pg.Client({ ...cfg, connectionTimeoutMillis: 2000 });
    try { await c.connect(); return c; } catch { try { await c.end(); } catch {} }
  }
  return null;
}

const db = await baglan();
const atla = db ? false : 'Postgres yok — DB testleri atlandı';
const SEMA_AD = `md24_test_${process.pid}`;
const BUGUN = '2026-08-13';

/** Kullanıcı 1'in gönderileri: 101 (100 gör.), 102 (50). Kullanıcı 2: 201. */
async function kur() {
  await db.query(`DROP SCHEMA IF EXISTS ${SEMA_AD} CASCADE`);
  await db.query(`CREATE SCHEMA ${SEMA_AD}`);
  await db.query(`SET search_path TO ${SEMA_AD}`);
  await db.query(`
    CREATE TABLE yorumlar (
      id INT PRIMARY KEY, kullanici_id INT NOT NULL,
      tur TEXT, tmdb_id INT, sezon INT, bolum INT,
      ust_id INT,
      metin TEXT NOT NULL DEFAULT '', medya TEXT[] NOT NULL DEFAULT '{}',
      goruntulenme INT NOT NULL DEFAULT 0,
      spoiler BOOLEAN NOT NULL DEFAULT false,
      tarih TIMESTAMPTZ DEFAULT now());
    CREATE TABLE yorum_begeniler (
      yorum_id INT REFERENCES yorumlar(id) ON DELETE CASCADE,
      kullanici_id INT, tarih TIMESTAMPTZ DEFAULT now(),
      PRIMARY KEY (yorum_id, kullanici_id));
    CREATE TABLE ayarlar (
      anahtar TEXT PRIMARY KEY, deger TEXT,
      guncelleme TIMESTAMPTZ DEFAULT now());`);
  // MİGRASYONUN KENDİSİ koşuyor: dosya geçerli SQL değilse test burada patlar.
  await db.query(MIGRASYON);
  await db.query(`
    INSERT INTO yorumlar (id, kullanici_id, tur, tmdb_id, metin, goruntulenme)
    VALUES (101, 1, 'tv', 5, 'bir', 100),
           (102, 1, 'tv', 6, 'iki', 50),
           (201, 2, 'movie', 7, 'baskasinin', 999)`);
}

async function bitir() {
  await db.query(`DROP SCHEMA IF EXISTS ${SEMA_AD} CASCADE`);
}

/** Belirli gün-önce ofsetlerine 1'er görüntülenme yazar. */
async function gunlukEkle(gonderiId, ofsetler) {
  await db.query(
    `INSERT INTO gonderi_gunluk (gonderi_id, gun, goruntulenme, toplam)
     SELECT $1, $2::date - o, 1, 0 FROM unnest($3::int[]) AS x(o)
     ON CONFLICT (gonderi_id, gun) DO UPDATE SET goruntulenme = 1`,
    [gonderiId, BUGUN, ofsetler]);
}

test('DB: taban turu SAHTE ZİRVE yazmaz (ömür boyu sayaç 0 delta olur)',
  { skip: atla }, async () => {
    await kur();
    await db.query(TOPLA_SQL, [BUGUN, true]);
    const { rows } = await db.query(
      'SELECT gonderi_id, goruntulenme, toplam FROM gonderi_gunluk ORDER BY gonderi_id');
    assert.deepEqual(rows, [
      { gonderi_id: 101, goruntulenme: 0, toplam: 100 },
      { gonderi_id: 102, goruntulenme: 0, toplam: 50 },
      { gonderi_id: 201, goruntulenme: 0, toplam: 999 },
    ]);
  });

test('DB: görev İKİ KEZ koşunca çift saymaz', { skip: atla }, async () => {
  await kur();
  await db.query(TOPLA_SQL, [BUGUN, true]);          // taban (dün gibi düşün)
  await db.query(`UPDATE gonderi_gunluk SET gun = $1::date - 1`, [BUGUN]);
  await db.query('UPDATE yorumlar SET goruntulenme = 130 WHERE id = 101');

  await db.query(TOPLA_SQL, [BUGUN, false]);
  const ilk = await db.query(
    'SELECT goruntulenme, toplam FROM gonderi_gunluk WHERE gonderi_id=101 AND gun=$1',
    [BUGUN]);
  assert.deepEqual(ilk.rows[0], { goruntulenme: 30, toplam: 130 });

  // İKİNCİ KOŞU — aynı gün, veri değişmedi.
  await db.query(TOPLA_SQL, [BUGUN, false]);
  const ikinci = await db.query(
    'SELECT goruntulenme, toplam FROM gonderi_gunluk WHERE gonderi_id=101 AND gun=$1',
    [BUGUN]);
  assert.deepEqual(ikinci.rows[0], { goruntulenme: 30, toplam: 130 },
    'ikinci koşu deltayı KATLADI');

  // Aynı gün içinde sayaç artarsa delta BÜYÜR (ama toplanmaz).
  await db.query('UPDATE yorumlar SET goruntulenme = 145 WHERE id = 101');
  await db.query(TOPLA_SQL, [BUGUN, false]);
  const ucuncu = await db.query(
    'SELECT goruntulenme FROM gonderi_gunluk WHERE gonderi_id=101 AND gun=$1',
    [BUGUN]);
  assert.equal(ucuncu.rows[0].goruntulenme, 45);
});

test('DB: değişmeyen gönderi için yeni satır AÇILMAZ (hacim kalkanı)',
  { skip: atla }, async () => {
    await kur();
    await db.query(TOPLA_SQL, [BUGUN, true]);
    await db.query(`UPDATE gonderi_gunluk SET gun = $1::date - 1`, [BUGUN]);
    await db.query('UPDATE yorumlar SET goruntulenme = 130 WHERE id = 101');
    await db.query(TOPLA_SQL, [BUGUN, false]);
    const { rows } = await db.query(
      'SELECT gonderi_id FROM gonderi_gunluk WHERE gun=$1 ORDER BY gonderi_id',
      [BUGUN]);
    assert.deepEqual(rows.map((r) => r.gonderi_id), [101],
      'yalnız görüntülenmesi ARTAN gönderi satır açmalı');
  });

test('DB: GÖRÜNTÜLENME kırılım sınırları tam 30/60/90/120 gün',
  { skip: atla }, async () => {
    await kur();
    // 0 ve 29 → 30 günlük pencerede; 30 → dışında. Aynı mantık 60/90/120'de.
    await gunlukEkle(101, [0, 29, 30, 59, 60, 89, 90, 119, 120]);
    const { rows } = await db.query(GORUNTULENME_PENCERE_SQL, [1, BUGUN]);
    assert.deepEqual(rows[0], { g30: 2, g60: 4, g90: 6, g120: 8 },
      '120 gün önceki satır HİÇBİR pencereye girmemeli');
  });

test('DB: BEĞENİ kırılımı görüntülenmeyle AYNI sınırları kullanıyor',
  { skip: atla }, async () => {
    await kur();
    await db.query(
      `INSERT INTO yorum_begeniler (yorum_id, kullanici_id, tarih)
       SELECT 101, 1000 + o, ($1::date - o)::timestamptz + interval '13 hours'
         FROM unnest($2::int[]) AS x(o)`,
      [BUGUN, [0, 29, 30, 59, 60, 89, 90, 119, 120]]);
    const { rows } = await db.query(BEGENI_PENCERE_SQL, [1, BUGUN]);
    assert.deepEqual(rows[0], { b30: 2, b60: 4, b90: 6, b120: 8 });
  });

test('DB: YALNIZ KENDİ VERİSİ — başkasının sayısı sızmıyor',
  { skip: atla }, async () => {
    await kur();
    await gunlukEkle(101, [0, 1]);      // kullanıcı 1
    await gunlukEkle(201, [0, 1, 2]);   // kullanıcı 2
    await db.query(
      `INSERT INTO yorum_begeniler (yorum_id, kullanici_id, tarih)
       VALUES (101, 9, now()), (201, 9, now()), (201, 8, now())`);

    const bir = await db.query(GORUNTULENME_PENCERE_SQL, [1, BUGUN]);
    const iki = await db.query(GORUNTULENME_PENCERE_SQL, [2, BUGUN]);
    assert.equal(bir.rows[0].g30, 2);
    assert.equal(iki.rows[0].g30, 3);

    const t1 = await db.query(TOPLAM_SQL, [1]);
    assert.deepEqual(t1.rows[0], { gonderi: 2, goruntulenme: 150, begeni: 1 },
      '999 görüntülenmeli başkasının gönderisi toplamıma girdi');

    const b1 = await db.query(BEGENI_PENCERE_SQL, [1, BUGUN]);
    assert.equal(b1.rows[0].b120, 1);

    const l = listeSql(30, 'pencere_goruntulenme');
    const liste = await db.query(l.sql, [1, BUGUN]);
    assert.deepEqual(liste.rows.map((r) => r.id), [101, 102]);
  });

test('DB: VERİ YOKKEN çökmüyor, sıfır dönüyor', { skip: atla }, async () => {
  await kur();
  const bos = 99; // hiç gönderisi olmayan kullanıcı
  const t = await db.query(TOPLAM_SQL, [bos]);
  assert.deepEqual(t.rows[0], { gonderi: 0, goruntulenme: 0, begeni: 0 });
  const g = await db.query(GORUNTULENME_PENCERE_SQL, [bos, BUGUN]);
  assert.deepEqual(g.rows[0], { g30: 0, g60: 0, g90: 0, g120: 0 });
  const b = await db.query(BEGENI_PENCERE_SQL, [bos, BUGUN]);
  assert.deepEqual(b.rows[0], { b30: 0, b60: 0, b90: 0, b120: 0 });
  for (const gun of [0, ...GONDERI_PENCERELER]) {
    const s = listeSql(gun, 'pencere_begeni');
    const r = await db.query(s.sql, s.parametreliMi ? [bos, BUGUN] : [bos]);
    assert.equal(r.rows.length, 0);
  }
});

test('DB: "tümü" ile pencereli liste FARKLI sıralar (ölçü gerçekten değişiyor)',
  { skip: atla }, async () => {
    await kur();
    // 102 ömür boyu daha AZ (50 < 100) ama son 30 günde daha ÇOK gösterildi.
    await gunlukEkle(101, [40]);
    await gunlukEkle(102, [0, 1, 2]);
    const tum = listeSql(0, 'pencere_goruntulenme');
    const p30 = listeSql(30, 'pencere_goruntulenme');
    const a = await db.query(tum.sql, [1]);
    const c = await db.query(p30.sql, [1, BUGUN]);
    assert.deepEqual(a.rows.map((r) => r.id), [101, 102]);
    assert.deepEqual(c.rows.map((r) => r.id), [102, 101]);
    assert.equal(c.rows[0].pencere_goruntulenme, 3);
    assert.equal(c.rows[0].toplam_goruntulenme, 50);
  });

test('DB: budama eskiyi siler ama ÇIPAYI korur', { skip: atla }, async () => {
  await kur();
  // 101: biri çok eski, biri yeni → eski silinir.
  await gunlukEkle(101, [GONDERI_GUNLUK_SAKLAMA + 5, 0]);
  // 102: SADECE çok eski satır → silinmemeli, yoksa çıpa kaybolur.
  await gunlukEkle(102, [GONDERI_GUNLUK_SAKLAMA + 5]);
  await db.query(BUDA_SQL, [BUGUN, GONDERI_GUNLUK_SAKLAMA]);
  const { rows } = await db.query(
    'SELECT gonderi_id, count(*)::int AS n FROM gonderi_gunluk GROUP BY 1 ORDER BY 1');
  assert.deepEqual(rows, [
    { gonderi_id: 101, n: 1 },
    { gonderi_id: 102, n: 1 },
  ]);
  // NOT (md. 23 için): node-pg bir DATE'i YEREL gece yarısına oturan Date
  // nesnesine çevirir; `toISOString()` UTC+3'te bir gün GERİYE kayar. Gün
  // dizesi lazımsa SQL'de `to_char` ile alınmalı.
  const kalan = await db.query(
    `SELECT to_char(gun,'YYYY-MM-DD') AS gun FROM gonderi_gunluk WHERE gonderi_id=101`);
  assert.equal(kalan.rows[0].gun, BUGUN);
});

test('DB: migrasyon TEKRAR koşabilir ve beğeni geçmişinin başladığı günü yazar',
  { skip: atla }, async () => {
    await kur();
    await db.query(
      `INSERT INTO yorum_begeniler (yorum_id, kullanici_id, tarih)
       VALUES (101, 7, '2026-07-16 08:00+00'), (101, 8, '2026-08-01 10:00+00')`);
    // İkinci kez koşuyor: CREATE ... IF NOT EXISTS + ON CONFLICT DO NOTHING.
    await db.query(MIGRASYON);
    const { rows } = await db.query(
      `SELECT deger FROM ayarlar WHERE anahtar='begeni_gecmis_baslangic'`);
    assert.equal(rows[0]?.deger, '2026-07-16',
      'ekran "beğeni geçmişi şu tarihten beri kayıtlı" diyemez');
  });

test('DB: gönderi silinince günlük satırları da düşüyor (CASCADE)',
  { skip: atla }, async () => {
    await kur();
    await gunlukEkle(101, [0, 1]);
    await db.query('DELETE FROM yorumlar WHERE id=101');
    const { rows } = await db.query(
      'SELECT count(*)::int AS n FROM gonderi_gunluk WHERE gonderi_id=101');
    assert.equal(rows[0].n, 0);
  });

test.after(async () => {
  if (!db) return;
  await bitir().catch(() => {});
  await db.end().catch(() => {});
});
