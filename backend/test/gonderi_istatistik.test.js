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
  YANIT_PENCERE_SQL, GUNLUK_SERI_SQL, GONDERI_SIRALAMALARI,
  YON_EN_AZ_GORUNTULENME, degisimYuzde, pencereSerisi, etkilesimSql,
  ETKILESIM_ORTALAMA_SQL, ETKILESIM_EN_AZ_GONDERI,
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
// Ucun TAM gövdesi: başlangıçtan ilk `\n}));` kapanışına kadar. Sabit uzunluk
// (eskiden 4000 karakter) uç büyüdükçe sessizce yarım okur ve "yeni alan
// yanıtta var mı" testleri sebepsiz düşerdi.
const UC = (() => {
  const bas = SERVER.indexOf("app.get('/istatistiklerim/gonderiler'");
  return SERVER.slice(bas, SERVER.indexOf('\n}));', bas));
})();

test('uç girisZorunlu kapısının ARKASINDA', () => {
  assert.ok(SERVER.includes(
    "app.get('/istatistiklerim/gonderiler', girisZorunlu,"));
});

test('uç BAŞKA kullanıcı seçme parametresi kabul etmiyor', () => {
  // `gun` ve `sirala` DIŞINDA bir sorgu/yol parametresi okunmamalı; okunsaydı
  // "kullanici=alcelik" ile başkasının performansı çekilebilirdi.
  // (14 Ağu 2026: tek listenin sıralaması `sirala` ile geliyor — o da KAPALI
  // SÖZLÜK, `GONDERI_SIRALAMALARI` beyaz listesinden geçiyor.)
  const okunanlar = [...UC.matchAll(/req\.(query|params|body)\.(\w+)/g)]
    .map((m) => m[2]);
  assert.deepEqual([...new Set(okunanlar)].sort(), ['gun', 'sirala']);
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
// 1b) 14 AĞU 2026 — YENİ DÜZEN: yanıt ölçüsü, yön oku, eğri, etkileşim oranı
// ---------------------------------------------------------------------------
// Kilitlenenler:
//   * `yanit` üçüncü SIRALAMA olarak var ve beyaz liste hâlâ kapalı.
//   * Yön oku ALT EŞİĞİN altında ve kapsam eksikken HİÇ DÖNMEZ (tahmin yok).
//   * Etkileşim oranının TEK TANIMI var — md. 23 ile md. 24 aynı SQL'den.
//   * Saklama süresi önceki dönemi ÖRTÜYOR; örtmeseydi 90/120 günlük
//     pencerelerin oku ASLA görünemezdi ("veri dolunca görünsün" sözü tutmaz).

test('sıralama beyaz listesi ÜÇ ölçü: görüntülenme, beğeni, YANIT', () => {
  assert.deepEqual(Object.keys(GONDERI_SIRALAMALARI),
    ['goruntulenme', 'begeni', 'yanit']);
  assert.equal(GONDERI_SIRALAMALARI.yanit, 'pencere_yanit');
});

test('listeSql: yanıt sıralaması geçerli, uydurma ölçü REDDEDİLİYOR', () => {
  const s = listeSql(30, 'pencere_yanit');
  assert.match(s.sql, /ORDER BY pencere_yanit DESC/);
  assert.match(s.sql, /AS pencere_yanit/);
  // Üç ölçü de HER satırda dönüyor: istemci sıralamayı değiştirmeden de
  // satırdaki sayıyı doğru gösterebilsin.
  for (const a of ['pencere_goruntulenme', 'pencere_begeni', 'pencere_yanit']) {
    assert.ok(s.sql.includes(`AS ${a}`), `${a} sütunu yok`);
  }
  assert.throws(() => listeSql(30, 'pencere_yanit; DROP TABLE yorumlar'),
    /gecersiz/);
  assert.throws(() => listeSql(30, 'y.metin'), /gecersiz/);
});

test('yanıt penceresi YANITIN tarihine göre sınırlanıyor', () => {
  // Gönderinin tarihine göre sınırlansaydı "son 30 günde aldığım yanıt"
  // aslında "son 30 günde YAZDIĞIM gönderilere gelen yanıt" olurdu.
  assert.match(YANIT_PENCERE_SQL, /c\.tarih AT TIME ZONE 'utc'/);
  assert.ok(!/y\.tarih/.test(YANIT_PENCERE_SQL));
  assert.match(YANIT_PENCERE_SQL, /kullanici_id=\$1/);
});

test('SAKLAMA önceki dönemi de örtüyor (yoksa 120 günün oku ASLA çıkmaz)',
  () => {
    assert.ok(GONDERI_GUNLUK_SAKLAMA >= 2 * Math.max(...GONDERI_PENCERELER),
      `saklama ${GONDERI_GUNLUK_SAKLAMA} gün: 240 günlük kıyas taşınamaz`);
    // Pencere sorgusu da o kadar geriye bakmalı.
    assert.match(GORUNTULENME_PENCERE_SQL, /\$2::date - 240/);
    assert.match(GORUNTULENME_PENCERE_SQL, /AS o120/);
  });

test('önceki dönem seçili dönemle ÖRTÜŞMÜYOR (kendini saymaz)', () => {
  // o30 = "son 60 gün" AMA "son 30 gün DEĞİL" ⇒ tam 30 günlük ayrık aralık.
  assert.match(GORUNTULENME_PENCERE_SQL,
    /FILTER \(WHERE g\.gun > \$2::date - 60 AND NOT \(g\.gun > \$2::date - 30\)\)\)?,?0\)::int AS o30/);
});

test('degisimYuzde: ALT EŞİĞİN altında yön DÖNMEZ', () => {
  const az = YON_EN_AZ_GORUNTULENME - 1;
  assert.equal(degisimYuzde({ simdi: 100, onceki: az, tam: true }), null,
    `${az} görüntülenmede yüzde gürültüdür, ok çizilmemeli`);
  assert.equal(degisimYuzde({ simdi: 100, onceki: 0, tam: true }), null,
    '0\'dan artışın yüzdesi tanımsız');
  assert.equal(degisimYuzde({ simdi: 5, onceki: 1, tam: true }), null);
});

test('degisimYuzde: KAPSAM EKSİKKEN yön DÖNMEZ (tahminle doldurulmaz)', () => {
  assert.equal(degisimYuzde({ simdi: 118, onceki: 100, tam: false }), null);
});

test('degisimYuzde: eşiğin üstünde tam sayı yüzde, işaretiyle', () => {
  assert.equal(degisimYuzde({ simdi: 118, onceki: 100, tam: true }), 18);
  assert.equal(degisimYuzde({ simdi: 77, onceki: 100, tam: true }), -23);
  assert.equal(degisimYuzde({ simdi: 100, onceki: 100, tam: true }), 0);
  // Tam eşikte HESAPLANIR (eşik "en az" demek).
  assert.equal(
    degisimYuzde({ simdi: 60, onceki: YON_EN_AZ_GORUNTULENME, tam: true }),
    100);
});

test('pencereSerisi: uzunluk TAM pencere kadar, eksik gün SIFIR', () => {
  const seri = pencereSerisi(
    [{ gun: '2026-08-12', goruntulenme: 7 }], '2026-08-14', 3);
  assert.deepEqual(seri, [
    { gun: '2026-08-12', goruntulenme: 7 },
    { gun: '2026-08-13', goruntulenme: 0 },
    { gun: '2026-08-14', goruntulenme: 0 },
  ]);
  // "Tümü"nün eğrisi YOKTUR: başlangıcı olmayan pencerenin günlük serisi olmaz.
  assert.deepEqual(pencereSerisi([{ gun: '2026-08-12', goruntulenme: 7 }],
    '2026-08-14', 0), []);
  assert.deepEqual(pencereSerisi([], '2026-08-14', 2).map((s) => s.goruntulenme),
    [0, 0], 'veri yokken bile dizi tam uzunlukta');
});

test('günlük seri kullanıcıya bağlı ve GÜN dizesi olarak dönüyor', () => {
  assert.match(GUNLUK_SERI_SQL, /kullanici_id=\$1/);
  // to_char ŞART: node-pg DATE'i yerel gece yarısına oturtur, JSON'a girerken
  // bir gün KAYABİLİR (md. 24 ajanının notu).
  assert.match(GUNLUK_SERI_SQL, /to_char\(g\.gun, 'YYYY-MM-DD'\)/);
});

test('ETKİLEŞİM ORANI TEK TANIM: md. 23 sabiti md. 24 fonksiyonundan', () => {
  assert.equal(ETKILESIM_ORTALAMA_SQL, etkilesimSql(0).sql,
    'iki ekran aynı kullanıcı için farklı yüzde gösterebilir');
  assert.equal(etkilesimSql(0).parametreliMi, false, '"tümü" $2 kullanmamalı');
  assert.equal(etkilesimSql(30).parametreliMi, true);
  assert.throws(() => etkilesimSql(45), /gecersiz/);
});

test('pencereli etkileşimde ÜÇ ölçÜ de aynı pencereye kısılıyor', () => {
  const s = etkilesimSql(30).sql;
  // Beğeni, yanıt ve görüntülenme: üçü de 30 günlük sınırı taşımalı. Yalnız
  // beğeni/yanıt kısılsaydı oran sistematik olarak KÜÇÜK çıkardı.
  assert.equal((s.match(/\$2::date - 30/g) || []).length, 4,
    'beğeni + yanıt + görüntülenme (SELECT ve WHERE) sınırlanmamış');
  assert.ok(!/y\.goruntulenme/.test(s), 'pencerede ömür boyu sayaç kullanılmış');
});

test('uç yeni parçaları döndürüyor ve eşikleri BİLDİRİYOR', () => {
  for (const alan of ['degisim', 'onceki_goruntulenme', 'onceki_tam',
    'seri:', 'etkilesim:', 'yanit:', 'gonderiler:', 'secili_sirala']) {
    assert.ok(UC.includes(alan), `uç ${alan} döndürmüyor`);
  }
  // Alt eşikler yanıtta: ekran "neden yok?" sorusunu cevaplayabilsin.
  assert.ok(UC.includes('ETKILESIM_EN_AZ_GONDERI'));
  assert.ok(UC.includes('YON_EN_AZ_GORUNTULENME'));
});

test('uç: KAPSAM EKSİKKEN eğri ve oran HİÇ SORGULANMIYOR', () => {
  // Yarım kapsamda hesaplanıp sonra gizlenseydi, bir gün "gizleme" satırı
  // düşünce uydurma sayı ekrana sızardı. Sorgu hiç koşmuyor.
  assert.match(UC, /gun !== 0 && seciliTam[\s\S]{0,120}GUNLUK_SERI_SQL/);
  assert.match(UC, /seciliTam\s*\n?\s*\?\s*havuz\.query\(etkSorgu\.sql/);
});

test('uç: ESKİ İSTEMCİ (sirala YOK) iki listeyi almaya devam ediyor', () => {
  // Telefonlardaki APK sunucuyla birlikte güncellenmez; `sirala` göndermeyen
  // istemciye eski alanlar korunur.
  assert.ok(UC.includes('eskiIstemci'));
  assert.ok(UC.includes('en_cok_goruntulenen'));
  assert.ok(UC.includes('en_cok_begenilen'));
});

test('etkileşim alt eşiği md. 23 ile AYNI (tek gerekçe, tek sayı)', () => {
  assert.equal(ETKILESIM_EN_AZ_GONDERI, 3);
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
    // o* = ÖNCEKİ eşit uzunluktaki dönem (14 Ağu 2026, yön oku): o30 = 30-59
    // gün öncesi {30,59}, o60 = 60-119 {60,89,90,119}, o90 = 90-179
    // {90,119,120}, o120 = 120-239 {120}. SEÇİLİ dönemin sayıları DEĞİŞMEDİ.
    assert.deepEqual(rows[0], {
      g30: 2, o30: 2, g60: 4, o60: 4, g90: 6, o90: 3, g120: 8, o120: 1,
    }, '120 gün önceki satır HİÇBİR SEÇİLİ pencereye girmemeli');
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
    assert.deepEqual(t1.rows[0],
      { gonderi: 2, goruntulenme: 150, begeni: 1, yanit: 0 },
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
  assert.deepEqual(t.rows[0],
    { gonderi: 0, goruntulenme: 0, begeni: 0, yanit: 0 });
  const g = await db.query(GORUNTULENME_PENCERE_SQL, [bos, BUGUN]);
  assert.deepEqual(g.rows[0], {
    g30: 0, o30: 0, g60: 0, o60: 0, g90: 0, o90: 0, g120: 0, o120: 0,
  });
  const b = await db.query(BEGENI_PENCERE_SQL, [bos, BUGUN]);
  assert.deepEqual(b.rows[0], { b30: 0, b60: 0, b90: 0, b120: 0 });
  const y = await db.query(YANIT_PENCERE_SQL, [bos, BUGUN]);
  assert.deepEqual(y.rows[0], { y30: 0, y60: 0, y90: 0, y120: 0 });
  const seri = await db.query(GUNLUK_SERI_SQL, [bos, BUGUN, 30]);
  assert.deepEqual(seri.rows, []);
  const e = await db.query(etkilesimSql(30).sql, [bos, BUGUN]);
  assert.deepEqual(e.rows[0], { n: 0, ort: null });
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

// ---------------------------------------------------------------------------
// 2b) GERÇEK POSTGRES — yanıt kırılımı, önceki dönem, pencereli etkileşim
// ---------------------------------------------------------------------------

/** Belirli gün-önce ofsetlerinde 1'er yanıt yazar (id'ler 900+). */
let yanitSayaci = 900;
async function yanitEkle(gonderiId, ofsetler) {
  for (const o of ofsetler) {
    yanitSayaci += 1;
    await db.query(
      // *** AÇIKÇA UTC ***: `::timestamptz` yerel saat dilimini uygular ve
      // `AT TIME ZONE 'utc'` geri çevirince gün BİR GERİ kayar (UTC+3'te
      // gece yarısı → önceki günün 21:00'i). Sınır testi tam da o günü ölçüyor.
      `INSERT INTO yorumlar (id, kullanici_id, tur, tmdb_id, metin, ust_id, tarih)
       VALUES ($1, 2, 'tv', 5, 'yanit', $2,
               (($3::date - $4::int)::timestamp AT TIME ZONE 'utc'))`,
      [yanitSayaci, gonderiId, BUGUN, o]);
  }
}

test('DB: YANIT kırılım sınırları tam 30/60/90/120 gün',
  { skip: atla }, async () => {
    await kur();
    try {
      // Sınıra tam oturan günler: 0 ve 29 içeride (30'luk), 30 dışarıda.
      await yanitEkle(101, [0, 29, 30, 59, 60, 89, 90, 119, 120]);
      const { rows } = await db.query(YANIT_PENCERE_SQL, [1, BUGUN]);
      assert.equal(rows[0].y30, 2, '30 gün: 0 ve 29 gün öncesi');
      assert.equal(rows[0].y60, 4, '60 gün: + 30 ve 59');
      assert.equal(rows[0].y90, 6);
      assert.equal(rows[0].y120, 8, '120 gün öncesi DIŞARIDA kalmalı');
    } finally { await bitir(); }
  });

test('DB: yanıt sayısı BAŞKASININ gönderisinden sızmıyor',
  { skip: atla }, async () => {
    await kur();
    try {
      await yanitEkle(201, [0, 1, 2]); // 201 = kullanıcı 2'nin gönderisi
      const bizim = await db.query(YANIT_PENCERE_SQL, [1, BUGUN]);
      const onun = await db.query(YANIT_PENCERE_SQL, [2, BUGUN]);
      assert.equal(bizim.rows[0].y30, 0);
      assert.equal(onun.rows[0].y30, 3);
    } finally { await bitir(); }
  });

test('DB: liste YANITA göre sıralanınca sıra GERÇEKTEN değişiyor',
  { skip: atla }, async () => {
    await kur();
    try {
      // 101 çok görüntülendi (100) ama az konuşuldu; 102 tersi.
      await gunlukEkle(101, [0, 1, 2, 3]);
      await gunlukEkle(102, [0]);
      await yanitEkle(102, [0, 1, 2]);
      await yanitEkle(101, [0]);
      const g = listeSql(30, 'pencere_goruntulenme');
      const y = listeSql(30, 'pencere_yanit');
      const a = await db.query(g.sql, [1, BUGUN]);
      const b = await db.query(y.sql, [1, BUGUN]);
      assert.deepEqual(a.rows.map((r) => r.id), [101, 102]);
      assert.deepEqual(b.rows.map((r) => r.id), [102, 101],
        'yanıt sıralaması görüntülenme sıralamasıyla aynı çıktı');
      assert.equal(b.rows[0].pencere_yanit, 3);
      // "En çok konuşulan" ≠ "en çok görüntülenen": ekranın var oluş sebebi.
      assert.equal(b.rows[0].pencere_goruntulenme, 1);
    } finally { await bitir(); }
  });

test('DB: ÖNCEKİ DÖNEM seçili dönemle örtüşmüyor, tam N gün ölçüyor',
  { skip: atla }, async () => {
    await kur();
    try {
      // Son 30 gün: 0 ve 29 → 2. Önceki 30 gün: 30 ve 59 → 2. 60 DIŞARIDA.
      await gunlukEkle(101, [0, 29, 30, 59, 60]);
      const { rows } = await db.query(GORUNTULENME_PENCERE_SQL, [1, BUGUN]);
      assert.equal(rows[0].g30, 2);
      assert.equal(rows[0].o30, 2, 'önceki 30 gün (30…59) yanlış sayıldı');
      assert.equal(rows[0].g60, 4);
      assert.equal(rows[0].o60, 1, 'önceki 60 gün (60…119): yalnız 60');
      // Toplam kaçırılmıyor: seçili + önceki = son 2N günün tamamı.
      assert.equal(rows[0].g30 + rows[0].o30, rows[0].g60);
    } finally { await bitir(); }
  });

test('DB: GÜNLÜK SERİ kullanıcının TÜM gönderilerini gün gün topluyor',
  { skip: atla }, async () => {
    await kur();
    try {
      await gunlukEkle(101, [0, 2]);
      await gunlukEkle(102, [0]);
      await gunlukEkle(201, [0]); // başkasının: sızmamalı
      const { rows } = await db.query(GUNLUK_SERI_SQL, [1, BUGUN, 30]);
      const seri = pencereSerisi(rows, BUGUN, 30);
      assert.equal(seri.length, 30, 'dizi pencere boyunda değil');
      assert.equal(seri.at(-1).gun, BUGUN);
      assert.equal(seri.at(-1).goruntulenme, 2, 'iki gönderi TOPLANMALI');
      assert.equal(seri.at(-3).goruntulenme, 1);
      assert.equal(seri.at(-2).goruntulenme, 0, 'artışsız gün SIFIR');
      assert.equal(seri.reduce((t, s) => t + s.goruntulenme, 0), 3,
        'başkasının görüntülenmesi seriye karışmış');
    } finally { await bitir(); }
  });

test('DB: ETKİLEŞİM ORANI pencereye kısılıyor (pencere dışı sayılmaz)',
  { skip: atla }, async () => {
    await kur();
    try {
      // 101: pencerede 10 görüntülenme, 1 beğeni (bugün) + 1 beğeni (60 gün
      // önce, PENCERE DIŞI) + 1 yanıt (bugün).
      await db.query(
        `INSERT INTO gonderi_gunluk (gonderi_id, gun, goruntulenme, toplam)
         VALUES (101, $1::date, 10, 10)`, [BUGUN]);
      await db.query(
        `INSERT INTO yorum_begeniler (yorum_id, kullanici_id, tarih)
         VALUES (101, 5, ($1::date::timestamp AT TIME ZONE 'utc')),
                (101, 6, (($1::date - 60)::timestamp AT TIME ZONE 'utc'))`,
        [BUGUN]);
      await yanitEkle(101, [0, 60]);
      const s = etkilesimSql(30);
      const { rows } = await db.query(s.sql, [1, BUGUN]);
      assert.equal(rows[0].n, 1, 'yalnız pencerede görüntülenen gönderi girer');
      // (1 beğeni + 1 yanıt) / 10 görüntülenme = 0,2 — pencere dışındaki
      // beğeni/yanıt sayılsaydı 0,4 çıkardı.
      assert.ok(Math.abs(Number(rows[0].ort) - 0.2) < 1e-9, `ort=${rows[0].ort}`);
    } finally { await bitir(); }
  });

test('DB: penceresinde HİÇ görüntülenmeyen gönderi orana GİRMEZ (0/0)',
  { skip: atla }, async () => {
    await kur();
    try {
      // Hiç günlük satır yok ⇒ pencere görüntülenmesi 0 ⇒ oran tanımsız.
      const s = etkilesimSql(30);
      const { rows } = await db.query(s.sql, [1, BUGUN]);
      assert.equal(rows[0].n, 0);
      assert.equal(rows[0].ort, null);
      // Ekran bu durumda tire koyar; eşik de zaten geçilmez.
      assert.ok(rows[0].n < ETKILESIM_EN_AZ_GONDERI);
    } finally { await bitir(); }
  });

test('DB: ÖMÜR BOYU yanıt sayacı toplamlarda dönüyor ("Tümü" üçlüsü)',
  { skip: atla }, async () => {
    await kur();
    try {
      // 200 gün öncesi: 120 günlük pencerenin DIŞINDA ama ömür boyu İÇİNDE.
      await yanitEkle(101, [0, 200]);
      const { rows } = await db.query(TOPLAM_SQL, [1]);
      assert.equal(rows[0].yanit, 2,
        '"tümü" yanıt sayısı 120 günle sınırlı kalmış');
      const p = await db.query(YANIT_PENCERE_SQL, [1, BUGUN]);
      assert.equal(p.rows[0].y120, 1);
    } finally { await bitir(); }
  });

test.after(async () => {
  if (!db) return;
  await bitir().catch(() => {});
  await db.end().catch(() => {});
});
