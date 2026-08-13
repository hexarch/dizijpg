// md. 23 — TEK GÖNDERİNİN İSTATİSTİĞİ · `node --test test/*.test.js`
//
// ===========================================================================
// NE KORUNUYOR
// ===========================================================================
//  1. SAHİPLİK — uca yalnız gönderinin SAHİBİ girebilir; başkasınınki 404
//     (403 değil: 403 "var ama giremezsin" derdi, yani varlığı ele verirdi).
//     Sahiplik SORGUNUN İÇİNDE olduğu için ileride eklenecek bir kod kapıyı
//     atlayamaz.
//  2. KİMLİK SIZMAMASI — bu ekranın en kritik iddiası: "görüntüleyenler" bir
//     SAYIDIR. Uç yanıtında kullanıcı adı/avatar/kimlik/izleyen özeti ALANI
//     BULUNMAZ; kaynak metni de bunları seçmediğini gösterir. md. 21'de
//     verilen "takipçilerimi/izlediklerimi gizle" sözüyle çakışmaz.
//  3. KAPALI SÖZLÜK — istemcinin gönderdiği kaynak etiketi ve ölçü adı
//     sözlüğün DIŞINA çıkamaz; DB'deki CHECK ikinci kalkandır.
//  4. PENCERELEME — "son 7/30/90 gün" gerçekten o kadar takvim günü mü?
//     Sınıra tam oturan günlerle sınanıyor.
//  5. SEYREK VERİ — eksik günler TAŞINIR (kümülatif çizgi kopmaz), ölçülmemiş
//     geçmiş SIFIRLA DOLDURULMAZ.
//  6. VERİ YOKKEN ÇÖKMEME — hiç serisi/sayacı olmayan gönderi için uç sıfır
//     ve boş dizi döner, kıyas null olur, patlamaz.
//
// VERİTABANI YOKSA: DB'ye dayanan testler ATLANIR (kaynak metni testleri yine
// koşar) — `gonderi_istatistik.test.js` ile aynı düzen.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

import {
  GONDERI_TEKIL_PENCERELER, GONDERI_KAYNAKLARI, GONDERI_ISTEMCI_OLCULERI,
  GONDERI_GUNLUK_SAKLAMA, kaynakOlcu, GORUNUM_SAYAC_SQL, GORUNTULEYEN_SQL,
  SAYAC_ARTIR_SQL, TEKIL_TEMEL_SQL, TEKIL_SAYAC_SQL, ETKILESIM_ORTALAMA_SQL,
  ETKILESIM_EN_AZ_GONDERI, seriSql, seriDoldur, gunEkle, zirveBul,
  VIDEO_KOVA_SAYISI, VIDEO_KOVA_EN_AZ, gecerliKova, eldeTutmaEgrisi,
  VIDEO_KOVA_YAZ_SQL, VIDEO_KOVA_OKU_SQL,
} from '../gonderi_istatistik.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
const SEMA = fs.readFileSync(path.join(KOK, 'sema.sql'), 'utf8');
const MIG24 = fs.readFileSync(
  path.join(KOK, 'migrasyon-2026-08-14c.sql'), 'utf8');
const MIG23 = fs.readFileSync(
  path.join(KOK, 'migrasyon-2026-08-14d.sql'), 'utf8');
// md. 23 · video elde tutma (izlenme süresi eğrisi) — ayrı migrasyon.
const MIG_VIDEO = fs.readFileSync(
  path.join(KOK, 'migrasyon-2026-08-14g.sql'), 'utf8');

// ---------------------------------------------------------------------------
// 0) SAF MANTIK — veritabanı gerekmez
// ---------------------------------------------------------------------------
test('pencereler tek gönderiye göre: 7/30/90 (120 saklamanın ötesinde olurdu)', () => {
  assert.deepEqual(GONDERI_TEKIL_PENCERELER, [7, 30, 90]);
  assert.ok(Math.max(...GONDERI_TEKIL_PENCERELER) < GONDERI_GUNLUK_SAKLAMA,
    'saklamadan uzun pencere EKSİK veri gösterirdi');
});

test('kaynak sözlüğü KAPALI; tanınmayan etiket sessizce ATILMAZ, "diger" olur', () => {
  assert.deepEqual(GONDERI_KAYNAKLARI,
    ['akis', 'profil', 'reels', 'dizi', 'paylasim', 'diger']);
  assert.equal(kaynakOlcu('akis'), 'kaynak_akis');
  assert.equal(kaynakOlcu('reels'), 'kaynak_reels');
  // Uydurma/boş/tip dışı değerlerin hepsi tek kovaya düşer.
  for (const kotu of ['uydurma', '', null, undefined, 42, 'kaynak_akis',
    "akis'; DROP TABLE yorumlar --"]) {
    assert.equal(kaynakOlcu(kotu), 'kaynak_diger', `sızan etiket: ${kotu}`);
  }
});

test('istemcinin bildirebildiği ölçüler arasında "takip" YOK', () => {
  // Takip gerçek bir sunucu eylemidir; istemci beyanına bırakılsaydı
  // takip-bırak-takip döngüsü sayacı sınırsız şişirirdi.
  assert.ok(!GONDERI_ISTEMCI_OLCULERI.includes('takip'));
  assert.deepEqual(GONDERI_ISTEMCI_OLCULERI,
    ['paylasim', 'profil_ziyaret', 'icerik_tikla', 'spoiler_acildi']);
  // Görüntülenme türevleri de istemciden gelmez (görüntülenme yolu yazar).
  for (const o of GONDERI_ISTEMCI_OLCULERI) {
    assert.ok(!o.startsWith('kaynak_') && !o.startsWith('izleyici_'));
  }
});

test('seriSql: pencere BEYAZ LİSTE (SQL enjeksiyonu kapalı)', () => {
  assert.throws(() => seriSql(45), /gecersiz/);
  assert.throws(() => seriSql('30; DROP TABLE yorumlar'), /gecersiz/);
  assert.equal(seriSql(0).parametreliMi, false);
  assert.ok(!seriSql(0).sql.includes('$2'), 'fazla parametre bind hatası verirdi');
  assert.equal(seriSql(30).parametreliMi, true);
});

test('seri günü METİN olarak çıkar (node-pg DATE kaymasına karşı)', () => {
  // node-pg bir DATE'i yerel gece yarısına oturtur; JSON'a girerken UTC'ye
  // dönüp GÜN KAYABİLİR. to_char kaymayı imkânsız kılar.
  assert.match(seriSql(0).sql, /to_char\(gun, 'YYYY-MM-DD'\)/);
});

test('seriDoldur: eksik gün TAŞINIR — kümülatif çizgi KOPMAZ, sıfıra düşmez', () => {
  const seri = seriDoldur([
    { gun: '2026-08-01', goruntulenme: 10, toplam: 10 },
    { gun: '2026-08-04', goruntulenme: 5, toplam: 15 },
  ], '2026-08-05');
  assert.deepEqual(seri.map((s) => s.gun), [
    '2026-08-01', '2026-08-02', '2026-08-03', '2026-08-04', '2026-08-05']);
  assert.deepEqual(seri.map((s) => s.toplam), [10, 10, 10, 15, 15]);
  // Günlük delta boş günlerde 0'dır (o gün ARTIŞ olmadı) — ama toplam düşmez.
  assert.deepEqual(seri.map((s) => s.gunluk), [10, 0, 0, 5, 0]);
  // MONOTONLUK = "zikzak olmayacak" şartının matematiksel güvencesi.
  for (let i = 1; i < seri.length; i += 1) {
    assert.ok(seri[i].toplam >= seri[i - 1].toplam, 'kümülatif çizgi düştü');
  }
});

test('seriDoldur: ÖLÇÜLMEMİŞ geçmiş sıfırla doldurulmaz (sahte veri yok)', () => {
  // Seri İLK KAYITLI günden başlar; ondan öncesi çizilmez.
  const seri = seriDoldur(
    [{ gun: '2026-08-10', goruntulenme: 3, toplam: 3 }], '2026-08-11');
  assert.equal(seri[0].gun, '2026-08-10');
  assert.equal(seri.length, 2);
});

test('seriDoldur: BOŞ seri boş döner (ekran "biriktiriliyor" der, patlamaz)', () => {
  assert.deepEqual(seriDoldur([], '2026-08-13'), []);
});

test('seriDoldur: TEK noktalı seri de geçerli (grafik bunu çizebilmeli)', () => {
  const seri = seriDoldur(
    [{ gun: '2026-08-13', goruntulenme: 7, toplam: 7 }], '2026-08-13');
  assert.deepEqual(seri, [{ gun: '2026-08-13', toplam: 7, gunluk: 7 }]);
});

test('seriDoldur: bozuk tarih sonsuz döngüye girmez', () => {
  const seri = seriDoldur([{ gun: 'abc', goruntulenme: 1, toplam: 1 }], '2026-08-13');
  assert.ok(seri.length <= GONDERI_GUNLUK_SAKLAMA + 3);
});

test('gunEkle: UTC gün aritmetiği (ay/yıl sınırı dahil)', () => {
  assert.equal(gunEkle('2026-08-31', 1), '2026-09-01');
  assert.equal(gunEkle('2026-12-31', 1), '2027-01-01');
  assert.equal(gunEkle('2028-02-28', 1), '2028-02-29'); // artık yıl
});

test('zirveBul: en yüksek GÜNLÜK artış, beraberlikte ERKEN gün kazanır', () => {
  const seri = [
    { gun: '2026-08-01', toplam: 5, gunluk: 5 },
    { gun: '2026-08-02', toplam: 10, gunluk: 5 },
    { gun: '2026-08-03', toplam: 12, gunluk: 2 },
  ];
  const z = zirveBul(seri, '2026-08-01');
  assert.equal(z.gun, '2026-08-01', 'beraberlikte erken gün haberdir');
  assert.equal(z.gunluk, 5);
  assert.equal(z.kacinci_gun, 1, 'paylaşım günü 1. gündür');
  assert.equal(zirveBul(seri, '2026-07-30').kacinci_gun, 3);
});

test('zirveBul: hiç artış yoksa null (ekran "zirve: 0" yazmaz)', () => {
  assert.equal(zirveBul([], '2026-08-01'), null);
  assert.equal(zirveBul([{ gun: '2026-08-01', toplam: 4, gunluk: 0 }], '2026-08-01'),
    null);
});

// ---------------------------------------------------------------------------
// 1) KAYNAK METNİ — kapı, sahiplik ve KİMLİK SIZMAMASI
// ---------------------------------------------------------------------------
const UC_BAS = SERVER.indexOf("app.get('/gonderi/:id/istatistik'");
// Uç, kendisinden sonraki İLK bölüm çizgisine kadar. (`}));` aramak yetmiyor:
// gövde girintili kapandığı için ilk eşleşme başka yerde çıkardı; `\napp.`
// da yetmiyor: sonraki uç yüzlerce satır sonra geliyor ve arada KOMŞU
// bölümün alan adları test taramasına karışırdı.)
const UC_SON = SERVER.indexOf('\n// =====', UC_BAS);
assert.ok(UC_SON > UC_BAS, 'uç bölümü kapanmıyor');
const UC = SERVER.slice(UC_BAS, UC_SON);

test('uç girisZorunlu kapısının ARKASINDA ve hız limitli', () => {
  assert.ok(UC_BAS > 0, 'uç bulunamadı');
  assert.ok(SERVER.includes(
    "app.get('/gonderi/:id/istatistik', girisZorunlu, gonderiIstatistikLimiti,"));
  assert.ok(SERVER.includes(
    "app.post('/gonderi/:id/olay', girisZorunlu, gonderiOlayLimiti,"));
});

test('SAHİPLİK SORGUNUN İÇİNDE (dışarıdaki bir if atlanabilirdi)', () => {
  assert.match(TEKIL_TEMEL_SQL, /WHERE y\.id=\$1 AND y\.kullanici_id=\$2/);
  // Uç kullanıcı seçme parametresi OKUMAZ: okusaydı "kullanici=alcelik" ile
  // başkasının gönderi performansı çekilebilirdi.
  const okunanlar = [...UC.matchAll(/req\.(query|params|body)\.(\w+)/g)]
    .map((m) => m[2]);
  assert.deepEqual([...new Set(okunanlar)].sort(), ['gun', 'id']);
  assert.ok(UC.includes('req.kullanici.id'));
});

test('başkasınınki 404 — 403 DEĞİL (403 varlığı ele verir, md. 19)', () => {
  assert.ok(UC.includes("res.status(404)"));
  assert.ok(!UC.includes('403'), 'uçta 403 yolu olmamalı');
});

test('*** UÇ KİMLİK DÖNDÜRMEZ *** — yanıtta kişiye ait alan YOK', () => {
  // Yanıt gövdesindeki alan adları taranıyor: bir gün biri "goruntuleyenler"
  // listesi eklemeye kalkarsa bu test kırılır.
  const yanit = UC.slice(UC.indexOf('res.json({'));
  for (const yasak of ['kullanici_adi', 'kullanici_id', 'avatar', 'izleyen',
    'izleyenler', 'goruntuleyenler', 'takipciler', 'begenenler', 'ip']) {
    assert.ok(!new RegExp(`\\b${yasak}\\b`).test(yanit),
      `uç yanıtında KİMLİK alanı var: ${yasak}`);
  }
  // "görüntüleyen" YALNIZ sayı olarak geçer.
  assert.match(yanit, /goruntuleyen: y\.goruntuleyen/);
});

test('sorgular da kimlik SEÇMİYOR (SELECT listesi kilitli)', () => {
  for (const sql of [TEKIL_TEMEL_SQL, TEKIL_SAYAC_SQL, seriSql(0).sql,
    seriSql(30).sql, ETKILESIM_ORTALAMA_SQL]) {
    assert.ok(!/\bk\.kullanici_adi\b|\bavatar\b|\bizleyen\b/.test(sql),
      `sorgu kimlik seçiyor:\n${sql}`);
  }
  // Tekil görüntüleyen YALNIZ count(*) olarak okunuyor.
  assert.match(TEKIL_TEMEL_SQL,
    /count\(\*\)::int FROM yorum_goruntuleyen v WHERE v\.yorum_id=y\.id/);
});

test('yorum_goruntuleyen HAM kimlik/IP değil, ANAHTARLI ÖZET yazıyor', () => {
  assert.match(SERVER, /createHmac\('sha256', GORUNTULEYEN_ANAHTAR\)/);
  // Ham değer yalnız HMAC girdisi olarak var; sorguya `ozet` gidiyor.
  assert.match(SERVER, /havuz\.query\(GORUNTULEYEN_SQL, \[idler, ozet\]\)/);
  assert.match(GORUNTULEYEN_SQL, /ON CONFLICT DO NOTHING/,
    'tekrar görüntüleme yeni satır açarsa "tekil" sayısı bozulur');
});

test('görüntülenme yazan TEK kapı var (yeni yol da dört ölçüyü işler)', () => {
  const artislar = SERVER.match(
    /UPDATE yorumlar SET goruntulenme = goruntulenme \+ 1/g) || [];
  assert.equal(artislar.length, 1,
    'görüntülenme birden çok yerde artıyor — kaynak/tekil ölçüleri kaçırır');
  assert.ok(SERVER.includes('function gorunumKaydet('));
  // Üç görüntülenme yolu da tek kapıdan geçiyor.
  assert.equal((SERVER.match(/gorunumKaydet\(/g) || []).length, 4,
    'tanım + üç çağrı bekleniyor');
});

test('dizi sayfası kaynağı SUNUCUDAN gelir (istemci beyanı değil)', () => {
  assert.match(SERVER, /gorunumKaydet\(rows\.map\(\(r\) => r\.id\), \{\s*\n\s*kaynak: 'dizi'/);
});

test('takip atfı YALNIZ gerçek yeni takip dalında sayılır', () => {
  const i = SERVER.indexOf("'takip', 1 FROM yorumlar y");
  assert.ok(i > 0);
  // Aynı dalda `bildirimEkle(hedefId, 'takip'` var; yani DELETE dönmediği
  // (yani gerçekten YENİ satır açılan) daldayız.
  const dal = SERVER.slice(i - 1500, i);
  assert.ok(dal.includes("if (silindi.rowCount === 0) {"));
  // Gönderi hedef kişiye ait olmalı: başkasının gönderisine takip yazılamaz.
  assert.match(SERVER, /WHERE y\.id=\$1 AND y\.kullanici_id=\$2\s*\n\s*ON CONFLICT \(gonderi_id, olcu\)/);
});

test('istemci ölçüsü BEYAZ LİSTEDEN geçiyor', () => {
  assert.match(SERVER, /if \(!GONDERI_ISTEMCI_OLCULERI\.includes\(olcu\)\) \{/);
});

test('şema ve migrasyon aynı tabloyu tarif ediyor + kapalı sözlük DB\'de de var', () => {
  for (const metin of [SEMA, MIG23]) {
    assert.match(metin, /CREATE TABLE IF NOT EXISTS gonderi_sayac/);
    assert.match(metin, /PRIMARY KEY \(gonderi_id, olcu\)/);
    assert.match(metin, /CHECK \(olcu IN \(/);
    // Sunucudaki her ölçü DB sözlüğünde de olmalı.
    for (const k of GONDERI_KAYNAKLARI) assert.ok(metin.includes(`'kaynak_${k}'`));
    for (const o of GONDERI_ISTEMCI_OLCULERI) assert.ok(metin.includes(`'${o}'`));
    for (const o of ['izleyici_takipci', 'izleyici_disari', 'takip']) {
      assert.ok(metin.includes(`'${o}'`));
    }
  }
});

test('gonderi_sayac KİŞİSEL sütun içermiyor (agregat sözü)', () => {
  // ŞEMADAN oku, migrasyon metninden değil: migrasyonun CHECK listesindeki
  // 'izleyici_takipci' gibi ETİKETLER metin taramasında sütun sanılırdı.
  const t = SEMA.slice(SEMA.indexOf('CREATE TABLE IF NOT EXISTS gonderi_sayac'));
  const govde = t.slice(0, t.indexOf('\n);'));
  // Sütun adları = her satırın ilk kelimesi (CHECK/PRIMARY KEY satırları hariç).
  const sutunlar = govde.split('\n').slice(1)
    .map((s) => s.trim().split(/[\s(]/)[0])
    .filter((s) => /^[a-z_]+$/.test(s) && !['primary', 'check'].includes(s));
  assert.deepEqual(sutunlar, ['gonderi_id', 'olcu', 'adet']);
  for (const yasak of ['kullanici_id', 'izleyen', 'ip', 'oturum', 'cihaz', 'tarih']) {
    assert.ok(!sutunlar.includes(yasak), `agregat tabloda kişisel sütun: ${yasak}`);
  }
});

test('yanıt verinin NE ZAMANDAN BERİ biriktiğini söylüyor (md. 24 kalıbı)', () => {
  assert.ok(UC.includes('olcu_baslangic'));
  assert.ok(UC.includes('goruntulenme_baslangic'));
  assert.ok(MIG23.includes("'gonderi_olcu_baslangic'"));
});

// ---------------------------------------------------------------------------
// 1b) VİDEO İZLENME SÜRESİ (ELDE TUTMA) EĞRİSİ — md. 23'ün ertelenen parçası
// ---------------------------------------------------------------------------
// NE KORUNUYOR:
//  a. EĞRİNİN ŞEKLİ: %100'den başlar ve MONOTON AZALIR. Kullanıcının istediği
//     şey budur ve tanım gereği doğrudur — bir gün biri "yumuşatma" eklerse
//     ya da payı/paydayı karıştırırsa bu testler kırılır.
//  b. ALT EŞİK: az izlenen videoda eğri YANILTIR ("3 kişide %67 elde tutma"),
//     o yüzden eşiğin altında eğri HİÇ DÖNMEZ.
//  c. KAPALI SÖZLÜK: kova 0..19; sözlük dışı değer hem sunucuda hem DB'de
//     reddedilir.
//  d. GİZLİLİK: tabloda kişisel sütun yok, uç yanıtında kimlik yok.
test('video eğrisi UYGULANDI: plan da, şema da, sorgular da yerinde', () => {
  assert.match(SERVER, /VİDEO İZLENME SÜRESİ EĞRİSİ \(ELDE TUTMA\) — UYGULANDI/);
  assert.match(SEMA, /CREATE TABLE IF NOT EXISTS video_kova/);
  assert.match(MIG_VIDEO, /CREATE TABLE IF NOT EXISTS video_kova/);
  // Kova sözlüğü DB'de de kapalı.
  for (const metin of [SEMA, MIG_VIDEO]) {
    assert.match(metin, /CHECK \(kova BETWEEN 0 AND 19\)/);
    assert.match(metin, /PRIMARY KEY \(gonderi_id, kova\)/);
  }
});

test('kova sözlüğü: yalnız 0..19 TAMSAYI kabul (istemci beyanı)', () => {
  assert.equal(VIDEO_KOVA_SAYISI, 20);
  for (let k = 0; k < VIDEO_KOVA_SAYISI; k += 1) assert.ok(gecerliKova(k));
  for (const kotu of [-1, 20, 21, 1.5, NaN, Infinity, '3', null, undefined,
    true, [], {}, '3; DROP TABLE yorumlar']) {
    assert.ok(!gecerliKova(kotu), `sızan kova: ${String(kotu)}`);
  }
});

test('EĞRİ %100\'DEN BAŞLAR ve MONOTON AZALIR (yumuşatma gerekmiyor)', () => {
  // 10 izleme baştan bıraktı, 10'u yarıda, 20'si sonuna kadar gitti.
  const c = eldeTutmaEgrisi([
    { kova: 0, adet: 10 }, { kova: 9, adet: 10 }, { kova: 19, adet: 20 },
  ]);
  assert.equal(c.gorunum, 40);
  assert.equal(c.egri.length, VIDEO_KOVA_SAYISI);
  assert.equal(c.egri[0], 1, 'eğri TAM %100\'den başlamalı');
  for (let k = 1; k < c.egri.length; k += 1) {
    assert.ok(c.egri[k] <= c.egri[k - 1],
      `eğri ${k}. kovada ARTTI: ${c.egri[k - 1]} → ${c.egri[k]}`);
    assert.ok(c.egri[k] >= 0 && c.egri[k] <= 1, 'oran 0..1 dışında');
  }
  // 30/40 = 0.75 (kova ≥ 1 olanlar), 20/40 = 0.5 (kova ≥ 10 olanlar).
  assert.equal(c.egri[1], 0.75);
  assert.equal(c.egri[10], 0.5);
  assert.equal(c.tamamlama, 0.5);
});

test('EĞRİ: tek kovada toplanan izlemede de monotonluk bozulmaz', () => {
  const c = eldeTutmaEgrisi([{ kova: 19, adet: 25 }]);
  // Herkes sonuna kadar izledi ⇒ düz %100 çizgi.
  assert.deepEqual(c.egri, new Array(VIDEO_KOVA_SAYISI).fill(1));
  assert.equal(c.tamamlama, 1);
  assert.equal(c.ortanca, 95, 'yarısı en az %95\'ini gördü');
});

test('ALT EŞİK: az izlenen videoda EĞRİ DÖNMEZ (yanıltıcı olurdu)', () => {
  assert.equal(VIDEO_KOVA_EN_AZ, 20);
  // Kullanıcının verdiği örnek: 3 kişide "%67 elde tutma" bir ölçü değildir.
  const az = eldeTutmaEgrisi([{ kova: 0, adet: 1 }, { kova: 19, adet: 2 }]);
  assert.equal(az.egri, null);
  assert.equal(az.tamamlama, null);
  assert.equal(az.ortanca, null);
  // Ama SAYI dönmeli: ekran "şu an 3 izlenme var" diyebilmeli.
  assert.equal(az.gorunum, 3);
  assert.equal(az.en_az, VIDEO_KOVA_EN_AZ);
  // Eşiğin TAM ALTI hâlâ çizilmez, TAM ÜSTÜ çizilir (kapalı/açık sınır).
  assert.equal(eldeTutmaEgrisi([{ kova: 0, adet: 19 }]).egri, null);
  assert.notEqual(eldeTutmaEgrisi([{ kova: 0, adet: 20 }]).egri, null);
});

test('EĞRİ: hiç veri yokken null döner, patlamaz', () => {
  for (const bos of [[], null, undefined]) {
    const c = eldeTutmaEgrisi(bos);
    assert.equal(c.gorunum, 0);
    assert.equal(c.egri, null);
  }
});

test('EĞRİ: bozuk satır (sözlük dışı kova, negatif adet) SESSİZCE atılır', () => {
  const c = eldeTutmaEgrisi([
    { kova: 0, adet: 20 },
    { kova: 20, adet: 999 },   // sözlük dışı
    { kova: -1, adet: 999 },   // sözlük dışı
    { kova: 5, adet: -5 },     // negatif
    { kova: 'x', adet: 3 },    // tip dışı
  ]);
  assert.equal(c.gorunum, 20, 'bozuk satırlar paydayı şişirmemeli');
  assert.deepEqual(c.egri.slice(1), new Array(VIDEO_KOVA_SAYISI - 1).fill(0));
});

test('ORTANCA: elde tutmanın hâlâ %50 olduğu EN BÜYÜK kova', () => {
  // 20 izlemenin 10'u 5. kovada, 10'u 15. kovada bıraktı.
  const c = eldeTutmaEgrisi([{ kova: 5, adet: 10 }, { kova: 15, adet: 10 }]);
  // kova ≤ 5 için oran 1; 6..15 için 0.5; sonrası 0 ⇒ en büyük ≥0.5 kova 15.
  assert.equal(c.egri[15], 0.5);
  assert.equal(c.ortanca, 75, '15/20 = %75');
  // Herkes hemen bıraktıysa ortanca %0'dır (TANIMSIZ KALAMAZ: egri[0]=1).
  assert.equal(eldeTutmaEgrisi([{ kova: 0, adet: 20 }]).ortanca, 0);
});

test('uç: kova bildirimi girisZorunlu + hız limitli, BEYAZ LİSTEDEN geçiyor', () => {
  assert.ok(SERVER.includes(
    "app.post('/gonderi/:id/video-kova', girisZorunlu, videoKovaLimiti,"));
  assert.match(SERVER, /if \(!gecerliKova\(kova\)\) \{/);
  // Kova limiti gönderi olay limitiyle AYNI sayacı paylaşmamalı.
  assert.match(SERVER, /hizLimiti\(600, \(req\) => `vk:\$\{req\.kullanici\.id\}`\)/);
});

test('kova YAZMA sorgusu: videosuz gönderiye satır AÇMAZ', () => {
  // WHERE içinde hem varlık hem VİDEOLULUK kontrolü var; düz VALUES olsaydı
  // elle atılan bir istek fotoğraflı gönderiye kova yazdırabilirdi.
  assert.match(VIDEO_KOVA_YAZ_SQL, /FROM yorumlar y/);
  assert.match(VIDEO_KOVA_YAZ_SQL, /m LIKE '%\.mp4' OR m LIKE '%\.webm'/);
  assert.match(VIDEO_KOVA_YAZ_SQL,
    /DO UPDATE SET adet = video_kova\.adet \+ 1/);
  // "videolu" tanımı ekranın baktığı tanımla AYNI olmalı.
  assert.match(TEKIL_TEMEL_SQL, /m LIKE '%\.mp4' OR m LIKE '%\.webm'/);
});

test('kova sorguları KİMLİK seçmiyor (agregat sözü)', () => {
  for (const sql of [VIDEO_KOVA_YAZ_SQL, VIDEO_KOVA_OKU_SQL]) {
    assert.ok(!/kullanici_id|izleyen|\bavatar\b|\bip\b|oturum/.test(sql),
      `kova sorgusu kimlik taşıyor:\n${sql}`);
  }
});

test('video_kova ŞEMASINDA kişisel sütun YOK (zaman damgası dahil)', () => {
  const t = SEMA.slice(SEMA.indexOf('CREATE TABLE IF NOT EXISTS video_kova'));
  const govde = t.slice(0, t.indexOf('\n);'));
  const sutunlar = govde.split('\n').slice(1)
    .map((s) => s.trim().split(/[\s(]/)[0])
    .filter((s) => /^[a-z_]+$/.test(s) && !['primary', 'check'].includes(s));
  assert.deepEqual(sutunlar, ['gonderi_id', 'kova', 'adet']);
  for (const yasak of ['kullanici_id', 'izleyen', 'ip', 'oturum', 'cihaz',
    'tarih']) {
    assert.ok(!sutunlar.includes(yasak), `kova tablosunda kişisel sütun: ${yasak}`);
  }
});

test('gizlilik politikasına eklenecek cümle migrasyonda YAZILI', () => {
  // Çeviri turunda unutulmasın diye kaynakta duruyor (46 dil ayrı işlem).
  // Satır sarması olabilir: yorum işaretleri ve boşluklar tek boşluğa indirgenir.
  const duz = MIG_VIDEO.replace(/\n--\s*/g, ' ').replace(/\s+/g, ' ');
  assert.ok(duz.includes(
    'videonun hangi bölümüne kadar izlendiği kimliksiz ve toplu olarak sayılır'),
  'gizlilik cümlesi migrasyonda yazılı değil');
});

// ---------------------------------------------------------------------------
// 2) GERÇEK POSTGRES
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
    try { await c.connect(); return c; } catch { try { await c.end(); } catch { /* yut */ } }
  }
  return null;
}

const db = await baglan();
const atla = db ? false : 'Postgres yok — DB testleri atlandı';
const SEMA_AD = `md23_test_${process.pid}`;
const BUGUN = '2026-08-13';

/**
 * Kullanıcı 1: gönderi 101 (100 gör.) ve 102 (50). Kullanıcı 2: gönderi 201.
 * Kullanıcı 3 kullanıcı 1'i TAKİP EDİYOR (izleyici kırılımı için).
 */
async function kur() {
  await db.query(`DROP SCHEMA IF EXISTS ${SEMA_AD} CASCADE`);
  await db.query(`CREATE SCHEMA ${SEMA_AD}`);
  await db.query(`SET search_path TO ${SEMA_AD}`);
  await db.query(`
    CREATE TABLE yorumlar (
      id INT PRIMARY KEY, kullanici_id INT NOT NULL,
      tur TEXT, tmdb_id INT, sezon INT, bolum INT, ust_id INT,
      metin TEXT NOT NULL DEFAULT '', medya TEXT[] NOT NULL DEFAULT '{}',
      goruntulenme INT NOT NULL DEFAULT 0,
      spoiler BOOLEAN NOT NULL DEFAULT false,
      tarih TIMESTAMPTZ DEFAULT now());
    CREATE TABLE yorum_begeniler (
      yorum_id INT REFERENCES yorumlar(id) ON DELETE CASCADE,
      kullanici_id INT, tarih TIMESTAMPTZ DEFAULT now(),
      PRIMARY KEY (yorum_id, kullanici_id));
    CREATE TABLE yorum_goruntuleyen (
      yorum_id INT REFERENCES yorumlar(id) ON DELETE CASCADE,
      izleyen TEXT NOT NULL, tarih TIMESTAMPTZ DEFAULT now(),
      PRIMARY KEY (yorum_id, izleyen));
    CREATE TABLE takipler (
      takip_eden_id INT, takip_edilen_id INT,
      PRIMARY KEY (takip_eden_id, takip_edilen_id));
    CREATE TABLE ayarlar (
      anahtar TEXT PRIMARY KEY, deger TEXT,
      guncelleme TIMESTAMPTZ DEFAULT now());`);
  // MİGRASYONLARIN KENDİSİ koşuyor: dosya geçerli SQL değilse test patlar.
  await db.query(MIG24);
  await db.query(MIG23);
  await db.query(MIG_VIDEO);
  await db.query(`
    INSERT INTO yorumlar (id, kullanici_id, tur, tmdb_id, metin, goruntulenme,
                          spoiler, medya, tarih)
    VALUES (101, 1, 'tv', 5, 'bir', 100, false, '{}',   '2026-08-01T00:00:00Z'),
           (102, 1, 'tv', 6, 'iki',  50, true,  '{"/medya/a.mp4"}',
                                                        '2026-08-05T00:00:00Z'),
           (103, 1, 'tv', 7, 'uc',    0, false, '{}',   '2026-08-12T00:00:00Z'),
           (201, 2, 'movie', 7, 'baskasinin', 999, false, '{}',
                                                        '2026-08-01T00:00:00Z');
    INSERT INTO takipler VALUES (3, 1);`);
}

async function bitir() {
  await db.query(`DROP SCHEMA IF EXISTS ${SEMA_AD} CASCADE`);
}

/** Belirli gün-önce ofsetlerine artış yazar (toplam kümülatif ilerler). */
async function gunlukEkle(gonderiId, ofsetler) {
  let toplam = 0;
  for (const o of [...ofsetler].sort((a, b) => b - a)) {
    toplam += 1;
    await db.query(
      `INSERT INTO gonderi_gunluk (gonderi_id, gun, goruntulenme, toplam)
       VALUES ($1, $2::date - $3::int, 1, $4)`,
      [gonderiId, BUGUN, o, toplam]);
  }
}

test('SAHİPLİK: başkasının gönderisi SIFIR SATIR döner (uç 404 verir)', { skip: atla },
  async () => {
    await kur();
    try {
      const benim = await db.query(TEKIL_TEMEL_SQL, [101, 1]);
      assert.equal(benim.rows.length, 1);
      // Aynı gönderi, BAŞKA kullanıcı → boş.
      const baskasi = await db.query(TEKIL_TEMEL_SQL, [101, 2]);
      assert.equal(baskasi.rows.length, 0);
      // Ve tersi: 201 kullanıcı 1'e görünmez.
      assert.equal((await db.query(TEKIL_TEMEL_SQL, [201, 1])).rows.length, 0);
      // Olmayan gönderi de boş — "yok" ile "senin değil" AYNI cevabı verir.
      assert.equal((await db.query(TEKIL_TEMEL_SQL, [9999, 1])).rows.length, 0);
    } finally { await bitir(); }
  });

test('TEKİL GÖRÜNTÜLEYEN: aynı kişi tekrar bakınca ARTMAZ', { skip: atla },
  async () => {
    await kur();
    try {
      // Aynı özet 3 kez, farklı özet 1 kez.
      for (let i = 0; i < 3; i += 1) {
        await db.query(GORUNTULEYEN_SQL, [[101], 'h:aaaaaaaaaaaaaaaaaaaaaa']);
      }
      await db.query(GORUNTULEYEN_SQL, [[101], 'h:bbbbbbbbbbbbbbbbbbbbbb']);
      const r = await db.query(TEKIL_TEMEL_SQL, [101, 1]);
      assert.equal(r.rows[0].goruntuleyen, 2, 'tekil sayaç tekrarları saymamalı');
      // Görüntülenme (toplam) ile görüntüleyen (tekil) AYRI kalıyor.
      assert.equal(r.rows[0].goruntulenme, 100);
    } finally { await bitir(); }
  });

test('KAYNAK + İZLEYİCİ: tek ifade iki sayacı birden artırır', { skip: atla },
  async () => {
    await kur();
    try {
      // Kullanıcı 3 gönderi 101'in yazarını (1) TAKİP EDİYOR.
      await db.query(GORUNUM_SAYAC_SQL, [[101], 3, kaynakOlcu('akis')]);
      // Kullanıcı 4 takip etmiyor.
      await db.query(GORUNUM_SAYAC_SQL, [[101], 4, kaynakOlcu('reels')]);
      // Anonim (0) — takipçi değildir.
      await db.query(GORUNUM_SAYAC_SQL, [[101], 0, kaynakOlcu('uydurma')]);
      const s = Object.fromEntries(
        (await db.query(TEKIL_SAYAC_SQL, [101])).rows.map((r) => [r.olcu, r.adet]));
      assert.equal(s.kaynak_akis, 1);
      assert.equal(s.kaynak_reels, 1);
      assert.equal(s.kaynak_diger, 1, 'tanınmayan etiket "diger" kovasına düşmeli');
      assert.equal(s.izleyici_takipci, 1);
      assert.equal(s.izleyici_disari, 2, 'anonim + takip etmeyen');
      // KAYNAK TOPLAMI = İZLEYİCİ TOPLAMI: ikisi de her görüntülenmede bir kez
      // artar; tutmazsa ekran "kalanı nerede?" sorusunu doğurur.
      const kaynakToplam = GONDERI_KAYNAKLARI
        .reduce((t, k) => t + (s[`kaynak_${k}`] || 0), 0);
      assert.equal(kaynakToplam, s.izleyici_takipci + s.izleyici_disari);
    } finally { await bitir(); }
  });

test('KAYNAK: tekrarlanan id, GÖRÜNTÜLENME SAYACI ile AYNI şekilde bir kez sayılır',
  { skip: atla }, async () => {
    await kur();
    try {
      await db.query(GORUNUM_SAYAC_SQL, [[101, 101, 102], 0, 'kaynak_akis']);
      const s = await db.query(
        `SELECT gonderi_id, olcu, adet FROM gonderi_sayac
          WHERE olcu='kaynak_akis' ORDER BY gonderi_id`);
      // `id = ANY($1)` bir SATIRI bir kez eşler; `UPDATE yorumlar SET
      // goruntulenme = goruntulenme + 1 WHERE id = ANY(...)` de öyle davranır.
      // İKİSİ AYNI DAVRANMAK ZORUNDA: kaynak toplamı görüntülenme toplamını
      // tutmazsa ekran "kalanı nerede?" sorusunu doğurur.
      assert.deepEqual(s.rows.map((r) => [r.gonderi_id, Number(r.adet)]),
        [[101, 1], [102, 1]]);
      const g = await db.query(
        `SELECT sum(adet)::int t FROM gonderi_sayac
          WHERE olcu IN ('izleyici_takipci','izleyici_disari')`);
      assert.equal(g.rows[0].t, 2, 'izleyici kırılımı da aynı sayıda artmalı');
    } finally { await bitir(); }
  });

test('KAPALI SÖZLÜK: uydurma ölçü DB tarafından REDDEDİLİR', { skip: atla },
  async () => {
    await kur();
    try {
      await assert.rejects(
        () => db.query(SAYAC_ARTIR_SQL, [101, 'uydurma_olcu']),
        /check constraint|kısıt/i);
      // Sözlükteki her değer ise kabul edilmeli (CHECK ile sunucu listesi
      // birbirinden kaymasın).
      for (const o of [...GONDERI_ISTEMCI_OLCULERI, 'takip']) {
        await db.query(SAYAC_ARTIR_SQL, [101, o]);
      }
      for (const k of GONDERI_KAYNAKLARI) {
        await db.query(SAYAC_ARTIR_SQL, [101, `kaynak_${k}`]);
      }
    } finally { await bitir(); }
  });

test('SAYAÇ ARTIRMA: ikinci çağrı ÜSTÜNE EKLER (üzerine yazmaz)', { skip: atla },
  async () => {
    await kur();
    try {
      await db.query(SAYAC_ARTIR_SQL, [101, 'paylasim']);
      await db.query(SAYAC_ARTIR_SQL, [101, 'paylasim']);
      await db.query(SAYAC_ARTIR_SQL, [101, 'paylasim']);
      const r = await db.query(
        `SELECT adet FROM gonderi_sayac WHERE gonderi_id=101 AND olcu='paylasim'`);
      assert.equal(Number(r.rows[0].adet), 3);
    } finally { await bitir(); }
  });

test('GÖNDERİ SİLİNİNCE sayaçlar da gider (CASCADE)', { skip: atla }, async () => {
  await kur();
  try {
    await db.query(SAYAC_ARTIR_SQL, [101, 'paylasim']);
    await db.query(GORUNTULEYEN_SQL, [[101], 'h:cccccccccccccccccccccc']);
    await db.query('DELETE FROM yorumlar WHERE id=101');
    assert.equal((await db.query(
      'SELECT 1 FROM gonderi_sayac WHERE gonderi_id=101')).rows.length, 0);
    assert.equal((await db.query(
      'SELECT 1 FROM yorum_goruntuleyen WHERE yorum_id=101')).rows.length, 0);
  } finally { await bitir(); }
});

test('PENCERE: "son 7 gün" tam 7 takvim günü (sınır günleri dahil/hariç)',
  { skip: atla }, async () => {
    await kur();
    try {
      // 0, 6 gün önce → 7 günlük pencerede. 7, 8 → dışında.
      await gunlukEkle(101, [0, 6, 7, 8]);
      const s7 = seriSql(7);
      const r7 = await db.query(s7.sql, [101, BUGUN]);
      assert.deepEqual(r7.rows.map((r) => r.gun),
        ['2026-08-07', '2026-08-13'], 'gun > BUGÜN-7 ⇒ bugün dahil 7 gün');
      // 30 günlük pencere hepsini alır; "tümü" de öyle ama parametresiz.
      assert.equal((await db.query(seriSql(30).sql, [101, BUGUN])).rows.length, 4);
      assert.equal((await db.query(seriSql(0).sql, [101])).rows.length, 4);
    } finally { await bitir(); }
  });

test('SERİ: başka gönderinin günleri KARIŞMAZ', { skip: atla }, async () => {
  await kur();
  try {
    await gunlukEkle(101, [0, 1]);
    await gunlukEkle(201, [0, 1, 2]);
    const r = await db.query(seriSql(0).sql, [101]);
    assert.equal(r.rows.length, 2);
  } finally { await bitir(); }
});

test('VERİ YOKKEN: seri boş, sayaç boş, ölçüler 0 — hiçbiri patlamıyor',
  { skip: atla }, async () => {
    await kur();
    try {
      const t = (await db.query(TEKIL_TEMEL_SQL, [103, 1])).rows[0];
      assert.equal(t.goruntulenme, 0);
      assert.equal(t.begeni, 0);
      assert.equal(t.yanit, 0);
      assert.equal(t.goruntuleyen, 0);
      assert.equal((await db.query(TEKIL_SAYAC_SQL, [103])).rows.length, 0);
      assert.deepEqual(seriDoldur(
        (await db.query(seriSql(0).sql, [103])).rows, BUGUN), []);
    } finally { await bitir(); }
  });

test('BEĞENİ/YANIT: yanıtlar üst gönderiye sayılır, başkasınınki karışmaz',
  { skip: atla }, async () => {
    await kur();
    try {
      await db.query(`
        INSERT INTO yorum_begeniler (yorum_id, kullanici_id) VALUES (101,2),(101,3);
        INSERT INTO yorumlar (id, kullanici_id, tur, tmdb_id, metin, ust_id)
        VALUES (301, 2, 'tv', 5, 'yanit', 101),
               (302, 3, 'tv', 5, 'yanit2', 101),
               (303, 3, 'movie', 7, 'baskasina yanit', 201)`);
      const t = (await db.query(TEKIL_TEMEL_SQL, [101, 1])).rows[0];
      assert.equal(t.begeni, 2);
      assert.equal(t.yanit, 2);
    } finally { await bitir(); }
  });

test('ETKİLEŞİM ORTALAMASI: görüntülenmesi 0 olan gönderi tabana GİRMEZ',
  { skip: atla }, async () => {
    await kur();
    try {
      await db.query(`
        INSERT INTO yorum_begeniler (yorum_id, kullanici_id) VALUES (101,2);
        INSERT INTO yorumlar (id, kullanici_id, tur, tmdb_id, metin, ust_id)
        VALUES (301, 2, 'tv', 5, 'yanit', 101)`);
      const r = (await db.query(ETKILESIM_ORTALAMA_SQL, [1])).rows[0];
      // 103 (0 görüntülenme) hariç; 101 ve 102 içeride.
      assert.equal(r.n, 2, '0 görüntülenmeli gönderi tanımsız oran verirdi');
      // 101: (1+1)/100 = 0.02 ; 102: 0/50 = 0 ⇒ ortalama 0.01
      assert.ok(Math.abs(Number(r.ort) - 0.01) < 1e-9, `ort=${r.ort}`);
      // Yanıtlar (301) gönderi sayılmaz.
      assert.ok(r.n < 3);
      // Kıyas eşiği: 2 gönderi YETMEZ (ekran kıyası göstermez).
      assert.ok(r.n < ETKILESIM_EN_AZ_GONDERI);
    } finally { await bitir(); }
  });

test('ETKİLEŞİM: başka kullanıcının gönderileri ortalamaya KARIŞMAZ',
  { skip: atla }, async () => {
    await kur();
    try {
      const r1 = (await db.query(ETKILESIM_ORTALAMA_SQL, [1])).rows[0];
      const r2 = (await db.query(ETKILESIM_ORTALAMA_SQL, [2])).rows[0];
      assert.equal(r1.n, 2);
      assert.equal(r2.n, 1);
    } finally { await bitir(); }
  });

test('MİGRASYON İDEMPOTENT: iki kez koşmak veriyi bozmuyor', { skip: atla },
  async () => {
    await kur();
    try {
      await db.query(SAYAC_ARTIR_SQL, [101, 'paylasim']);
      await db.query(GORUNTULEYEN_SQL, [[101], 'h:dddddddddddddddddddddd']);
      await db.query(MIG23);
      const r = await db.query(
        `SELECT adet FROM gonderi_sayac WHERE gonderi_id=101 AND olcu='paylasim'`);
      assert.equal(Number(r.rows[0].adet), 1);
      // 'h:' biçimindeki satır DELETE'ten etkilenmedi.
      assert.equal((await db.query(
        'SELECT count(*)::int n FROM yorum_goruntuleyen')).rows[0].n, 1);
      // Başlangıç günü ilk yazandan kalmalı (ON CONFLICT DO NOTHING).
      const a = await db.query(
        `SELECT deger FROM ayarlar WHERE anahtar='gonderi_olcu_baslangic'`);
      assert.match(a.rows[0].deger, /^\d{4}-\d{2}-\d{2}$/);
    } finally { await bitir(); }
  });

test('MİGRASYON: eski biçimli (ham kimlikli) satır varsa TEMİZLENİR',
  { skip: atla }, async () => {
    await kur();
    try {
      await db.query(
        `INSERT INTO yorum_goruntuleyen (yorum_id, izleyen)
         VALUES (101,'u:7'),(101,'ip:1.2.3.4'),(101,'h:eeeeeeeeeeeeeeeeeeeeee')`);
      await db.query(MIG23);
      const r = await db.query('SELECT izleyen FROM yorum_goruntuleyen');
      assert.deepEqual(r.rows.map((x) => x.izleyen), ['h:eeeeeeeeeeeeeeeeeeeeee']);
    } finally { await bitir(); }
  });

// ---------------------------------------------------------------------------
// 3) VİDEO KOVA — GERÇEK POSTGRES
// ---------------------------------------------------------------------------
test('KOVA CHECK: 0..19 DIŞI reddedilir (istemci beyanının ikinci kalkanı)',
  { skip: atla }, async () => {
    await kur();
    try {
      for (const kotu of [-1, 20, 99]) {
        await assert.rejects(
          () => db.query(
            'INSERT INTO video_kova (gonderi_id, kova, adet) VALUES (102,$1,1)',
            [kotu]),
          /check constraint|kısıt/i, `kova ${kotu} kabul edildi`);
      }
      // Sözlük içindeki her değer kabul edilmeli.
      for (let k = 0; k < VIDEO_KOVA_SAYISI; k += 1) {
        await db.query(VIDEO_KOVA_YAZ_SQL, [102, k]);
      }
      const n = await db.query(
        'SELECT count(*)::int n FROM video_kova WHERE gonderi_id=102');
      assert.equal(n.rows[0].n, VIDEO_KOVA_SAYISI,
        'gönderi başına EN ÇOK 20 satır');
    } finally { await bitir(); }
  });

test('KOVA YAZMA: aynı kova ÜSTÜNE EKLER; satır sayısı TRAFİKLE BÜYÜMEZ',
  { skip: atla }, async () => {
    await kur();
    try {
      for (let i = 0; i < 50; i += 1) await db.query(VIDEO_KOVA_YAZ_SQL, [102, 7]);
      const r = await db.query(VIDEO_KOVA_OKU_SQL, [102]);
      assert.equal(r.rows.length, 1, '50 izleme TEK satır olmalı');
      assert.deepEqual(r.rows[0], { kova: 7, adet: 50 });
    } finally { await bitir(); }
  });

test('KOVA YAZMA: VİDEOSUZ gönderiye ve OLMAYAN gönderiye satır AÇILMAZ',
  { skip: atla }, async () => {
    await kur();
    try {
      // 101 fotoğrafsız/videosuz, 9999 hiç yok. İkisi de sessizce 0 satır.
      for (const id of [101, 103, 9999]) {
        const r = await db.query(VIDEO_KOVA_YAZ_SQL, [id, 5]);
        assert.equal(r.rowCount, 0, `videosuz/olmayan gönderiye yazıldı: ${id}`);
      }
      assert.equal((await db.query('SELECT count(*)::int n FROM video_kova'))
        .rows[0].n, 0);
      // 102 videolu (medya '{/medya/a.mp4}') → yazılır.
      assert.equal((await db.query(VIDEO_KOVA_YAZ_SQL, [102, 5])).rowCount, 1);
    } finally { await bitir(); }
  });

test('AGREGASYON: DB\'den okunan satırlar eğriye çevrilince MONOTON AZALIR',
  { skip: atla }, async () => {
    await kur();
    try {
      // 12 izleme 0. kovada, 8 izleme 19. kovada bıraktı (toplam 20 = eşik).
      for (let i = 0; i < 12; i += 1) await db.query(VIDEO_KOVA_YAZ_SQL, [102, 0]);
      for (let i = 0; i < 8; i += 1) await db.query(VIDEO_KOVA_YAZ_SQL, [102, 19]);
      const c = eldeTutmaEgrisi((await db.query(VIDEO_KOVA_OKU_SQL, [102])).rows);
      assert.equal(c.gorunum, 20);
      assert.equal(c.egri[0], 1);
      for (let k = 1; k < c.egri.length; k += 1) {
        assert.ok(c.egri[k] <= c.egri[k - 1], `eğri ${k}. kovada arttı`);
      }
      assert.equal(c.egri[1], 0.4, '8/20');
      assert.equal(c.tamamlama, 0.4);
    } finally { await bitir(); }
  });

test('KOVA: başka gönderinin izlemeleri KARIŞMAZ', { skip: atla }, async () => {
  await kur();
  try {
    await db.query(`UPDATE yorumlar SET medya='{"/medya/b.mp4"}' WHERE id=201`);
    for (let i = 0; i < 5; i += 1) await db.query(VIDEO_KOVA_YAZ_SQL, [102, 3]);
    for (let i = 0; i < 9; i += 1) await db.query(VIDEO_KOVA_YAZ_SQL, [201, 9]);
    assert.equal(eldeTutmaEgrisi(
      (await db.query(VIDEO_KOVA_OKU_SQL, [102])).rows).gorunum, 5);
    assert.equal(eldeTutmaEgrisi(
      (await db.query(VIDEO_KOVA_OKU_SQL, [201])).rows).gorunum, 9);
  } finally { await bitir(); }
});

test('KOVA: gönderi silinince kovalar da gider (CASCADE)', { skip: atla },
  async () => {
    await kur();
    try {
      await db.query(VIDEO_KOVA_YAZ_SQL, [102, 4]);
      await db.query('DELETE FROM yorumlar WHERE id=102');
      assert.equal((await db.query(
        'SELECT 1 FROM video_kova WHERE gonderi_id=102')).rows.length, 0);
    } finally { await bitir(); }
  });

test('KOVA MİGRASYONU İDEMPOTENT: iki kez koşmak sayacı bozmuyor',
  { skip: atla }, async () => {
    await kur();
    try {
      await db.query(VIDEO_KOVA_YAZ_SQL, [102, 11]);
      await db.query(MIG_VIDEO);
      const r = await db.query(VIDEO_KOVA_OKU_SQL, [102]);
      assert.deepEqual(r.rows, [{ kova: 11, adet: 1 }]);
      // Ölçüm başlangıcı İLK yazandan kalmalı (ON CONFLICT DO NOTHING).
      const a = await db.query(
        `SELECT deger FROM ayarlar WHERE anahtar='video_kova_baslangic'`);
      assert.match(a.rows[0].deger, /^\d{4}-\d{2}-\d{2}$/);
    } finally { await bitir(); }
  });

test.after(async () => { if (db) await db.end(); });
