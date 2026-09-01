// TEKİLLİK KURALI — "ya izleyecektir ya izlemiştir" (kullanıcı, 14 Ağu 2026)
// `node --test backend/test/*.test.js`
//
// ŞİKÂYET: "Filmin profiline gittiğimde 'izledim'i işaretliyorum, daha sonra
// 'izleyeceğim'i de işaretleyebiliyorum."
//
// KÖK: çelişki `durumlar` tablosunun İÇİNDE değil (PK durumu zaten tekil
// tutuyor), İKİ TABLO ARASINDA: `izlemeler` satırı ⨯ `durum='izleyecegim'`.
//
// BU DOSYA İKİ KATMANI BİRDEN TUTAR (hareketlerim.test.js kalıbı):
//
//  1) YAPI — `server.js` kaynağından ilgili blokları çekip kuralın gerçekten
//     SUNUCUDA zorlandığını sınar. `server.js` içe aktarılamıyor: modül
//     yüklenir yüklenmez `app.listen` çağırıyor.
//  2) DAVRANIŞ — canlı temizlik sorgularını (migrasyon-2026-08-14e.sql) GERÇEK
//     POSTGRES'te koşturur: DOĞRU satırları seçtiğini VE yanlışlarını
//     SEÇMEDİĞİNİ kanıtlar. Çalıştırma:
//
//         createdb durum_test
//         psql -q -d durum_test -f backend/sema.sql
//         DURUM_DB=durum_test npm test --prefix backend
//
//     `DURUM_DB` yoksa §5 ATLANIR; yapı testleri her makinede koşar.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const oku = (a) => fs.readFileSync(path.join(KOK, a), 'utf8');

const KAYNAK = oku('server.js');
const SEMA = oku('sema.sql');
const MIGRASYON = oku('migrasyon-2026-08-14e.sql');
const AKTAR = oku('veri_aktar.js');

// ---------------------------------------------------------------------------
// Kaynaktan blok çekme (engelleme.test.js / hareketlerim.test.js kalıbı)
// ---------------------------------------------------------------------------

/** `bas` indeksinden başlayarak ilk dengeli `{...}` bloğunu döndürür. */
function blokAl(kaynak, bas) {
  let derinlik = 0;
  let girdi = false;
  for (let i = bas; i < kaynak.length; i++) {
    const c = kaynak[i];
    if (c === '{') { derinlik++; girdi = true; } else if (c === '}') {
      derinlik--;
      if (girdi && derinlik === 0) return kaynak.slice(bas, i + 1);
    }
  }
  assert.fail('blok sonu bulunamadı');
}

/** `app.post('<yol>' ...)` gövdesi. */
function ucGovdesi(yol) {
  const im = `app.post('${yol}'`;
  const bas = KAYNAK.indexOf(im);
  assert.ok(bas > 0, `${yol} ucu bulunamadı`);
  return blokAl(KAYNAK, KAYNAK.indexOf('{', bas));
}

/** `async function <ad>(...)` gövdesi. */
function fonksiyonGovdesi(ad) {
  const m = new RegExp(`^async function ${ad}\\b`, 'm').exec(KAYNAK);
  assert.ok(m, `${ad} bulunamadı`);
  return blokAl(KAYNAK, KAYNAK.indexOf('{', m.index));
}

const DURUM = ucGovdesi('/durum');
const TOGGLE = ucGovdesi('/izleme/toggle');
const SEZON = ucGovdesi('/izleme/sezon');
const BOLUM_PUANI = ucGovdesi('/puan');
const TOPLU = ucGovdesi('/karsilama/toplu-durum');
const CIKAR = fonksiyonGovdesi('izleyecegimdenCikar');

// Yorum satırlarını atar: gerekçe metinleri "kod var" sanılmasın.
const kodu = (s) => s.split('\n').filter((r) => !r.trim().startsWith('//')).join('\n');

// ===========================================================================
// 1. POST /durum — ONAYSIZ "izleyeceğim" REDDEDİLİR
// ===========================================================================

test('POST /durum: izleyecegim seçilirken izleme kaydı SAYILIR', () => {
  const kod = kodu(DURUM);
  assert.match(kod, /durum === 'izleyecegim'/,
    'izleyecegim için özel bir kapı yok — çelişki üretilebilir');
  assert.match(kod, /count\(\*\)[\s\S]*FROM izlemeler/,
    'izleme kaydı sayılmıyor');
});

test('POST /durum: onaysız istek 409 + IZLEME_KAYDI_VAR döndürür', () => {
  const kod = kodu(DURUM);
  assert.match(kod, /status\(409\)/,
    'çakışma 409 ile bildirilmiyor (400 durum kodu "istek bozuk" der, oysa '
    + 'istek kusursuz; çakışan şey kaydın hâli)');
  assert.match(kod, /IZLEME_KAYDI_VAR/,
    'makine kodu yok — istemci Türkçe metne göre dallanmak zorunda kalır');
  assert.match(kod, /izleme_sayisi/,
    'kaç kaydın silineceği yanıtta yok; onay diyaloğu sayıyı yazamaz');
});

test('POST /durum: onay OLMADAN izleme kaydı SİLİNMEZ', () => {
  const kod = kodu(DURUM);
  assert.match(kod, /izlemeleri_sil !== true/,
    'onay bayrağı aranmıyor — veri kaybı kullanıcıya haber verilmeden olur');
  const silme = /DELETE FROM izlemeler/.exec(kod);
  assert.ok(silme, 'onaylı yolda silme yok');
  // Silme, onay kapısının ARDINDA olmalı: kapı silmeden ÖNCE `return` etmeli.
  const kapi = kod.indexOf('izlemeleri_sil !== true');
  assert.ok(kapi >= 0 && kapi < silme.index,
    'DELETE onay kapısından ÖNCE geliyor — onaysız da silinir');
});

test('POST /durum: izleyecegim `tekrar` sayacını da sıfırlar', () => {
  const kod = kodu(DURUM);
  assert.match(kod, /tekrar\s*=\s*CASE WHEN \$4 = 'izleyecegim' THEN 0/,
    '"izleyeceğim ama 3 kez izledim" ikinci bir çelişki olarak kalır');
  assert.match(kod, /ELSE durumlar\.tekrar END/,
    'diğer durumlarda tekrar sayacı KORUNMALI (md. 22)');
});

test('POST /durum: diğer üç durum kuralın DIŞINDA — biraktim ezilmez', () => {
  const kod = kodu(DURUM);
  // Kapı YALNIZ izleyecegim'e bakmalı. 'biraktim' izleme kaydıyla çelişmez:
  // 20 bölüm izleyip bırakan kullanıcının geçmişi silinemez.
  for (const d of ['biraktim', 'izliyorum']) {
    assert.ok(!new RegExp(`durum === '${d}'[\\s\\S]{0,400}DELETE FROM izlemeler`).test(kod),
      `'${d}' izleme kaydı silmeye yol açıyor — kural yalnız izleyecegim içindir`);
  }
});

// ===========================================================================
// 2. TERS YÖN — izleme işaretleyen uçlar durumu izleyecegim'de BIRAKMAZ
// ===========================================================================

test('izleyecegimdenCikar: TMDB\'ye bakmadan, yalnız izleyecegim satırını taşır', () => {
  const kod = kodu(CIKAR);
  assert.match(kod, /UPDATE durumlar SET durum=\$4/);
  assert.match(kod, /durum='izleyecegim'/,
    'WHERE izleyecegim yok — başka durumları da ezer (biraktim dahil!)');
  assert.match(kod, /'movie' \? 'bitirdim' : 'izliyorum'/,
    'film/dizi ayrımı yok: filmde ara hâl olmaz, dizide vardır');
  assert.ok(!/tmdb(Getir|Detay)|yayinlanmis/i.test(kod),
    'TMDB çağrısı var — ağ düşünce kural uygulanamaz hâle gelir');
});

test('/izleme/toggle: bölüm İŞARETLENDİĞİNDE izleyecegim bozulur', () => {
  const kod = kodu(TOGGLE);
  assert.match(kod, /izleyecegimdenCikar\(req\.kullanici\.id, 'tv', tmdb_id\)/,
    'dizi toggle izleyecegim durumunu bırakıyor');
  // KALDIRMADA çağrılmamalı: kayıt silinince "izleyeceğim" çelişki değildir.
  assert.match(kod, /silindi\.rowCount === 0\)?\s*\{?\s*\n?\s*await izleyecegimdenCikar/,
    'çıkarma işaretleme koşuluna bağlı değil (kaldırırken de çalışıyor)');
  // Sıra önemli: `diziDurumunuGuncelle` TMDB'ye bakar ve null dönebilir.
  const a = kod.indexOf('izleyecegimdenCikar');
  const b = kod.indexOf('diziDurumunuGuncelle');
  assert.ok(a > 0 && b > a,
    'izleyecegimdenCikar, diziDurumunuGuncelle\'den SONRA çağrılıyor');
  // Filmde ayrıca gerek yok: filmDurumunuGuncelle zaten 'bitirdim'e eziyor.
  assert.match(kod, /filmDurumunuGuncelle/);
});

test('/izleme/sezon: sezon işaretlemesi de izleyecegim\'i bozar', () => {
  const kod = kodu(SEZON);
  assert.match(kod, /if \(isaretle\) await izleyecegimdenCikar/,
    'sezon işaretleyip "izleyeceğim"de kalınabiliyor');
});

test('POST /puan: puan verilen bölüm izlenmiş sayılır → izleyecegim biter', () => {
  const kod = kodu(BOLUM_PUANI);
  assert.match(kod, /izleyecegimdenCikar\(req\.kullanici\.id, 'tv', tmdb_id\)/,
    'bölüme puan verip "izleyeceğim"de kalınabiliyor '
    + '(bölüme puan = o bölümü izledim, 8 Ağu 2026-d kararı)');
});

test('filmDurumunuGuncelle: "İzledim" hâlâ eski durumu eziyor (bozulmadı)', () => {
  const kod = kodu(fonksiyonGovdesi('filmDurumunuGuncelle'));
  assert.match(kod, /DO UPDATE SET durum='bitirdim'/,
    'ters yön kırılmış: "izledim" artık izleyecegim durumunu ezmiyor');
});

// ===========================================================================
// 3. TOPLU KARŞILAMA — onay sorulacak kimse yok → KAYIT kazanır
// ===========================================================================

test('/karsilama/toplu-durum: izlenmiş başlık "izleyeceğim"e ÇEKİLMEZ', () => {
  const kod = kodu(TOPLU);
  assert.match(kod, /durum === 'izleyecegim'/,
    'toplu uçta izleyecegim çakışması hiç düşünülmemiş');
  assert.match(kod, /FROM izlemeler/,
    'izleme kaydı sorgulanmıyor — toplu uç çelişki üretebilir');
  assert.ok(!/DELETE FROM izlemeler/.test(kod),
    'toplu uç izleme kaydı SİLİYOR: karşılamada seçilen bir kutucuk '
    + 'kullanıcının geçmişini silmeye yetkili olamaz');
  assert.match(kod, /izleme_cakismasi/,
    'atlanan öğe sayısı yanıtta dönmüyor (sessiz atlama)');
});

// ===========================================================================
// 4. İÇE AKTARIM + ŞEMA BELGESİ
// ===========================================================================

test('veri_aktar: geri yükleme çelişkiyi KAYIT SİLMEDEN çözer', () => {
  assert.match(AKTAR, /async function izleyecegimCelikisiniCoz/,
    'eski (çelişkili) bir yedeği geri yüklemek hatayı geri getirir');
  const kod = kodu(AKTAR.slice(AKTAR.indexOf('async function izleyecegimCelikisiniCoz')));
  const govde = blokAl(kod, kod.indexOf('{'));
  assert.match(govde, /UPDATE durumlar/,
    'düzeltme durumu ilerletmiyor');
  assert.ok(!/DELETE FROM izlemeler/.test(govde),
    'içe aktarım izleme kaydı siliyor — orada onay sorulacak kimse yok');
  assert.match(govde, /'movie' THEN 'bitirdim' ELSE 'izliyorum'/);
  // Her geri yükleme yolunda çağrılmalı:
  // json (iceAktarNative), tek dosyalı TV Time CSV, çok dosyalı TV Time
  // CSV'leri ve Letterboxd (1 Eyl 2026'da eklendi).
  const cagri = (AKTAR.match(/await izleyecegimCelikisiniCoz\(havuz, userId\)/g) || []).length;
  assert.equal(cagri, 4,
    `beklenen 4 çağrı yerine ${cagri} — bir aktarım yolu düzeltmesiz kalmış`);
});

test('sema.sql: tablolar arası kural yazılı (CHECK ile ifade edilemez)', () => {
  // Kural metni satır sonuna sarabilir → yorum işaretlerini/boşlukları düzle.
  const duz = SEMA.replace(/\n--\s?/g, ' ').replace(/\s+/g, ' ');
  assert.match(duz, /ya izleyecektir ya izlemiştir/,
    'kural şemada belgelenmemiş; bir sonraki geliştirici bilmeden bozar');
  assert.match(duz, /AYNI ANDA OLAMAZ/);
  assert.match(SEMA, /migrasyon-2026-08-14e\.sql/);
});

// ===========================================================================
// 5. TEMİZLİK SORGULARI — GERÇEK POSTGRES (DURUM_DB verilmezse atlanır)
// ===========================================================================

/** Migrasyondaki `>>> SAYIM: <ad>` işaretçileri arasındaki sorgu. */
function sayimSorgusu(ad) {
  const m = new RegExp(`>>> SAYIM: ${ad}\\n([\\s\\S]*?)<<< SAYIM: ${ad}`).exec(MIGRASYON);
  assert.ok(m, `${ad} sayım sorgusu migrasyonda bulunamadı`);
  return m[1].split('\n')
    .map((s) => s.replace(/^--\s?/, ''))
    .join('\n').trim();
}

test('migrasyon: sayım sorguları belgede DURUYOR', () => {
  assert.match(sayimSorgusu('CELISKILI'), /^SELECT d\.tur,/);
  assert.match(sayimSorgusu('DOKUNULMAYAN'), /^SELECT d\.durum, d\.tur,/);
  // Körlemesine UPDATE olmasın diye migrasyon yedek de alıyor.
  assert.match(MIGRASYON, /CREATE TABLE IF NOT EXISTS durum_yedek_20260814/);
  assert.ok(!/DELETE FROM izlemeler/.test(MIGRASYON),
    'canlı temizlik izleme kaydı siliyor — GERİ ALINAMAZ veri kaybı');
});

const DB = process.env.DURUM_DB;
const dbSuite = DB ? test : test.skip;

dbSuite('gerçek veritabanı: temizlik doğru satırları seçer, yanlışlara dokunmaz',
  async (t) => {
    const { default: pg } = await import('pg');
    const havuz = new pg.Pool({ database: DB });
    const q = (s, v) => havuz.query(s, v);
    t.after(() => havuz.end());

    await q('DROP TABLE IF EXISTS durum_yedek_20260814');
    await q('TRUNCATE kullanicilar, izlemeler, durumlar RESTART IDENTITY CASCADE');
    await q(`INSERT INTO kullanicilar (id, kullanici_adi) VALUES (1,'ali'),(2,'veli')`);

    // --- SEÇİLMESİ GEREKENLER (çelişkili) ---
    //  100 film: izledi + sonradan "izleyeceğim" dedi  → ŞİKÂYETİN TA KENDİSİ
    //  200 dizi: 3 bölüm işaretli + "izleyeceğim"
    //  300 dizi: yalnız ÖZEL bölüm (sezon 0) işaretli + "izleyeceğim"
    //  400 film (BAŞKA kullanıcı): kişi başına ayrı ayrı düzeltilmeli
    // --- SEÇİLMEMESİ GEREKENLER ---
    //  500 dizi: "biraktim" + 5 bölüm  → ÇELİŞMEZ (izlemiş ama bırakmış)
    //  600 film: "bitirdim" + izleme   → beklenen hâl
    //  700 dizi: "izliyorum" + izleme  → beklenen hâl
    //  800 dizi: "izleyecegim", izleme YOK → DOĞRU satır
    //  900 : durum 'izleyecegim' TV, ama izleme kaydı FİLM tarafında
    //        → `tur` eşleşmesi atlanırsa yanlışlıkla seçilir (tuzak)
    //  1000: BAŞKA kullanıcının izlemesi → kullanici_id atlanırsa seçilir (tuzak)
    await q(`INSERT INTO durumlar (kullanici_id, tur, tmdb_id, durum, tekrar) VALUES
             (1,'movie',100,'izleyecegim',2),
             (1,'tv',   200,'izleyecegim',0),
             (1,'tv',   300,'izleyecegim',0),
             (2,'movie',400,'izleyecegim',0),
             (1,'tv',   500,'biraktim',   0),
             (1,'movie',600,'bitirdim',   1),
             (1,'tv',   700,'izliyorum',  0),
             (1,'tv',   800,'izleyecegim',0),
             (1,'tv',   900,'izleyecegim',0),
             (1,'tv',  1000,'izleyecegim',0)`);
    await q(`INSERT INTO izlemeler (kullanici_id, tur, tmdb_id, sezon, bolum) VALUES
             (1,'movie',100,0,0),
             (1,'tv',   200,1,1),(1,'tv',200,1,2),(1,'tv',200,1,3),
             (1,'tv',   300,0,1),
             (2,'movie',400,0,0),
             (1,'tv',   500,1,1),(1,'tv',500,1,2),(1,'tv',500,1,3),
               (1,'tv',500,1,4),(1,'tv',500,1,5),
             (1,'movie',600,0,0),
             (1,'tv',   700,1,1),
             (1,'movie',900,0,0),
             (2,'tv',  1000,1,1)`);

    // ---- ÖNCE SAY (körlemesine UPDATE yok) ----
    const sayim = (await q(sayimSorgusu('CELISKILI'))).rows;
    assert.deepEqual(
      sayim.map((r) => [r.tur, r.celiskili_satir, r.etkilenen_kullanici, r.izleme_kaydi]),
      [['movie', 2, 2, 2], ['tv', 2, 1, 4]],
      'sayım sorgusu yanlış satırları sayıyor (film 100+400, dizi 200+300 '
      + 'beklenir; 500/600/700/800/900/1000 SEÇİLMEMELİ)');

    const oncekiDokunulmayan = (await q(sayimSorgusu('DOKUNULMAYAN'))).rows;

    // ---- DÜZELT (migrasyonun TAMAMI — doğrulama DO bloğu dahil) ----
    await q(MIGRASYON);

    const durumlar = new Map((await q(
      'SELECT kullanici_id, tur, tmdb_id, durum, tekrar FROM durumlar')).rows
      .map((r) => [`${r.kullanici_id}:${r.tur}:${r.tmdb_id}`, r]));

    // --- düzeltilenler ---
    assert.equal(durumlar.get('1:movie:100').durum, 'bitirdim',
      'şikâyet edilen film düzeltilmedi');
    assert.equal(durumlar.get('1:tv:200').durum, 'izliyorum',
      'dizide izleyecegim + bölüm çelişkisi duruyor');
    assert.equal(durumlar.get('1:tv:300').durum, 'izliyorum',
      'yalnız özel bölüm işaretliyken de "izleyeceğim" yalandır');
    assert.equal(durumlar.get('2:movie:400').durum, 'bitirdim',
      'ikinci kullanıcının satırı atlanmış');

    // --- DOKUNULMAMASI gerekenler ---
    assert.equal(durumlar.get('1:tv:500').durum, 'biraktim',
      '"bıraktım" ezildi: izlemiş olmak bırakmakla ÇELİŞMEZ');
    assert.equal(durumlar.get('1:movie:600').durum, 'bitirdim');
    assert.equal(durumlar.get('1:tv:700').durum, 'izliyorum');
    assert.equal(durumlar.get('1:tv:800').durum, 'izleyecegim',
      'izleme kaydı OLMAYAN "izleyeceğim" satırı DOĞRUDUR, düzeltilemez');
    assert.equal(durumlar.get('1:tv:900').durum, 'izleyecegim',
      'tur eşleşmesi atlanmış: film izlemesi diziyi düzelttirdi');
    assert.equal(durumlar.get('1:tv:1000').durum, 'izleyecegim',
      'kullanici_id eşleşmesi atlanmış: başkasının izlemesi düzelttirdi');

    // --- tekrar sayacı korundu (md. 22): temizlik onu SIFIRLAMAZ ---
    assert.equal(durumlar.get('1:movie:100').tekrar, 2,
      'temizlik yeniden izleme sayacını bozdu');
    assert.equal(durumlar.get('1:movie:600').tekrar, 1);

    // --- HİÇBİR izleme kaydı silinmedi ---
    const izleme = await q('SELECT count(*)::int AS n FROM izlemeler');
    assert.equal(izleme.rows[0].n, 15, 'temizlik izleme kaydı sildi');

    // --- çelişki kalmadı, "dokunulmayan" tablo aynı kaldı ---
    assert.equal((await q(sayimSorgusu('CELISKILI'))).rows.length, 0,
      'düzeltmeden sonra hâlâ çelişkili satır var');
    const sonrakiDokunulmayan = (await q(sayimSorgusu('DOKUNULMAYAN'))).rows;
    for (const eski of oncekiDokunulmayan) {
      if (eski.durum === 'izleyecegim') continue; // düzeltilenler zaten taşındı
      const yeni = sonrakiDokunulmayan.find(
        (r) => r.durum === eski.durum && r.tur === eski.tur);
      assert.ok(yeni && yeni.izleme_kaydi_olan_satir >= eski.izleme_kaydi_olan_satir,
        `${eski.durum}/${eski.tur} bucket'ı küçüldü — kural dışı satır kaybolmuş`);
    }

    // --- yedek: geri sarılabilir mi? ---
    const yedek = (await q(
      'SELECT tur, tmdb_id, eski_durum, izleme_kaydi FROM durum_yedek_20260814 ORDER BY tmdb_id'))
      .rows;
    assert.equal(yedek.length, 4, 'yedeğe yanlış sayıda satır alınmış');
    assert.ok(yedek.every((r) => r.eski_durum === 'izleyecegim' && r.izleme_kaydi > 0),
      'yedekte kural dışı satır var');

    // --- İDEMPOTENT: ikinci koşu hiçbir şeyi değiştirmez ---
    await q(MIGRASYON);
    assert.equal((await q('SELECT count(*)::int AS n FROM durum_yedek_20260814')).rows[0].n, 4,
      'migrasyon ikinci koşuda yedeği çiftledi');
    assert.equal(
      (await q(`SELECT durum FROM durumlar WHERE kullanici_id=1 AND tur='tv' AND tmdb_id=800`))
        .rows[0].durum,
      'izleyecegim', 'ikinci koşu doğru satırı bozdu');
  });
