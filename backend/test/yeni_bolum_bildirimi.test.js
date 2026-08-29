// Yeni bölüm bildirimi (sıra farkındalıklı) testleri — `node --test test/*.test.js`
//
// KORUNAN KARARLAR (13 Ağu 2026, migrasyon-2026-08-13.sql · istek md. 27):
//
//  1) *** KULLANICI KURALI (PAZARLIKSIZ) *** İzlenen dizinin yeni bölümü için
//     bildirim YALNIZ kullanıcı BİR ÖNCEKİ BÖLÜMÜ İZLEMİŞSE gider. 1. sezonda
//     olan kullanıcıya 10. sezonun bölümü için bildirim GİTMEZ. Bu dosyanın
//     asıl işi budur; §3 bütün hâllerini tek tek sınar.
//  2) SEZON GEÇİŞİ: yeni bölüm B==1 ise "önceki bölüm" ÖNCEKİ SEZONUN SON
//     BÖLÜMÜDÜR. Sezon numarası sezon-1 diye VARSAYILMAZ (TMDB'de numara
//     atlayabilir); bölüm sayısı `/tv/{id}` gövdesindeki
//     `seasons[].episode_count`tan okunur — EK TMDB ÇAĞRISI YOK.
//  3) S1B1 (dizinin ilk bölümü) BİLDİRİLMEZ: "izliyorum" diyen zaten
//     başlamıştır ve öncesi olmayan bölüm kuralın dışındadır.
//  4) TEKRAR ÖNLEME kısmi tekil indekstedir (`bildirimler_bolum_tekil`),
//     ayrı "gönderildi" tablosu YOK. Push YALNIZ satır gerçekten yazıldıysa
//     (rowCount=1) gider — `bildirimEkle`nin koşulsuz push'u BURADA YANLIŞ
//     olurdu, o yüzden ayrı yazıcı (`bolumBildirimiEkle`) var.
//  5) 14 GÜNLÜK PENCERE bir MALİYET FRENİDİR: pencere dışındaki dizinin
//     kullanıcı satırlarına hiç bakılmaz.
//  6) TERCİH: `bildir_bolum` kapalıysa ne uygulama-içi kayıt ne push. İki
//     kapı var — görevin aday sorgusundaki JOIN ve `bolumBildirimiEkle`.
//  7) `GET /bildirimler` 'bolum' satırında tmdb_id/sezon/bolum + zenginleşmiş
//     dizi_adi/poster döner; N+1 YOK (tek `tmdbTopluGetir`).
//
// Neden kaynak okuma: `server.js` içe aktarıldığı anda `app.listen` çağırıyor
// (bolum_puani.test.js / kisi_tepkisi.test.js ile aynı gerekçe). Saf yardımcılar
// kaynaktan ÇEKİLİP gerçekten ÇALIŞTIRILIYOR — test canlıdaki kodu sınar,
// kopyasını değil.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const oku = (a) => fs.readFileSync(path.join(KOK, a), 'utf8');

const KAYNAK = oku('server.js');
const SEMA = oku('sema.sql');
const MIGRASYON = oku('migrasyon-2026-08-13.sql');

// Migrasyonun YORUM OLMAYAN satırları: gerekçe metinleri komut sanılmasın
// (geri alma bölümü bilerek DELETE/DROP örneği içerir).
const KOMUTLAR = MIGRASYON.split('\n')
  .filter((s) => !s.trim().startsWith('--')).join('\n');

// ---------------------------------------------------------------------------
// Kaynaktan bildirim çekme (kisi_tepkisi.test.js'teki kalıp)
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

// Saf çekirdek: DB/TMDB'siz koşar. Bağımlılık sırası korunuyor.
const ADLAR = ['YENI_BOLUM_PENCERE_GUN', 'YENI_BOLUM_TUR_SINIRI', 'gunEkle',
  'bolumKumesi', 'yeniBolumAdayi', 'oncekiBolum', 'bolumBildirilsinMi',
  'sbEtiketi', 'PUSH_SABLON', 'BILDIRIM_TERCIH_KOLON', 'BILDIRIM_TERCIH_ALANLARI'];
const SAF = new Function(
  `${ADLAR.map((a) => bildirimCek(KAYNAK, a)).join('\n')}\nreturn { ${ADLAR.join(', ')} };`,
)();
const {
  YENI_BOLUM_PENCERE_GUN, YENI_BOLUM_TUR_SINIRI, gunEkle, yeniBolumAdayi,
  oncekiBolum, bolumBildirilsinMi, sbEtiketi, PUSH_SABLON,
  BILDIRIM_TERCIH_KOLON, BILDIRIM_TERCIH_ALANLARI,
} = SAF;

/** `app.post('/x'` ya da `app.get('/x'` ucunun gövdesi. */
function ucGovdesi(yol, yontem = 'post') {
  const kacir = yol.replace(/[/:\-.]/g, (c) => (c === '/' ? '\\/' : `\\${c}`));
  const m = new RegExp(
    `app\\.${yontem}\\('${kacir}'[\\s\\S]*?\\n\\}\\)\\);`,
  ).exec(KAYNAK);
  assert.ok(m, `${yontem.toUpperCase()} ${yol} ucu bulunamadı`);
  return m[0];
}

/**
 * `async function ad(...) { ... }` gövdesi — `bildirimCek` yalnız `const` ve
 * `function` biliyor; bu dosyanın ilgilendiği yazıcıların çoğu `async`.
 * Süslü parantez dengesiyle gövde sonu bulunur (kaynakta bu fonksiyonların
 * içinde dengelenmemiş süslü parantez taşıyan dizge/regex yok).
 */
function fnGovdesi(ad) {
  const m = new RegExp(`^(?:async )?function ${ad}\\b`, 'm').exec(KAYNAK);
  assert.ok(m, `${ad} fonksiyonu bulunamadı`);
  // GÖVDE başı, PARAMETRE listesi kapandıktan SONRAKİ ilk `{`. Doğrudan ilk
  // `{`i almak, `function f({ a, b })` gibi yıkımlı imzalarda parametre
  // parantezini gövde sanardı.
  let i = KAYNAK.indexOf('(', m.index);
  for (let p = 0; i < KAYNAK.length; i++) {
    if (KAYNAK[i] === '(') p++;
    else if (KAYNAK[i] === ')' && --p === 0) break;
  }
  const bas = KAYNAK.indexOf('{', i);
  let derinlik = 0;
  for (let j = bas; j < KAYNAK.length; j++) {
    if (KAYNAK[j] === '{') derinlik++;
    else if (KAYNAK[j] === '}' && --derinlik === 0) return KAYNAK.slice(m.index, j + 1);
  }
  return assert.fail(`${ad} gövdesinin sonu bulunamadı`);
}

// TMDB `/tv/{id}` gövdesinin testte gereken kadarı.
const dizi = (sonS, sonB, tarih, sezonlar) => ({
  name: 'Deneme Dizisi',
  poster_path: '/p.jpg',
  last_episode_to_air: { season_number: sonS, episode_number: sonB, air_date: tarih },
  seasons: sezonlar.map(([no, adet]) => ({ season_number: no, episode_count: adet })),
});

const BUGUN = '2026-08-13';
const DUN = '2026-08-12';

// ===========================================================================
// 1) ŞEMA (sema.sql)
// ===========================================================================
// 29 Ağu 2026: bu iki test önce sema.sql'deki SON `CHECK (tur IN (...))`
// ifadesini alıyordu — "en son eklenen tur CHECK'i bildirimler'inkidir"
// varsayımıyla. GIF arşivi `sikayetler.tur` CHECK'ini dosyanın sonuna eklediği
// an varsayım çöktü ve testler yanlış kısıtı ölçmeye başladı. Artık kısıt ADIYLA
// aranıyor; başka bir tablo sona eklenince bir daha kaymaz.
const BILDIRIM_TUR_CHECK = () => {
  const hepsi = SEMA.match(
    /bildirimler_tur_check\s+CHECK \(tur IN \([^)]*\)\)/g) || [];
  return hepsi[hepsi.length - 1];
};

test('sema: bildirimler.tur CHECK ı "bolum" türünü kabul eder', () => {
  const son = BILDIRIM_TUR_CHECK();
  assert.ok(son, 'bildirimler tur CHECK ı bulunamadı');
  assert.match(son, /'bolum'/, "sema.sql 'bolum' türünü kabul etmiyor");
});

test('sema: 8 Ağu\'nun kacirilan_arama türü CHECK ten DÜŞMEDİ', () => {
  // Yeni liste eski listenin ÜST KÜMESİ olmalı; düşerse canlıdaki kaçırılan
  // arama bildirimi bir daha yazılamaz.
  const son = BILDIRIM_TUR_CHECK();
  for (const t of ['yanit', 'begeni', 'takip', 'mesaj', 'etiket', 'kacirilan_arama']) {
    assert.match(son, new RegExp(`'${t}'`), `${t} türü kayboldu`);
  }
});

test('sema: bildirimler e tmdb_id/sezon/bolum NULLABLE eklendi', () => {
  for (const s of ['tmdb_id', 'sezon', 'bolum']) {
    assert.match(
      SEMA, new RegExp(`ALTER TABLE bildirimler ADD COLUMN IF NOT EXISTS ${s} INT;`),
      `bildirimler.${s} sema.sql de yok`,
    );
  }
  // NOT NULL YASAK: tablo altı türü birden taşıyor, diğerleri NULL bırakır.
  assert.ok(
    !/ADD COLUMN IF NOT EXISTS (tmdb_id|sezon|bolum) INT NOT NULL/.test(SEMA),
    'bölüm hedef sütunları NOT NULL olamaz (diğer türler NULL bırakır)',
  );
});

test('sema: tekrar önleme KISMİ TEKİL İNDEKS (ayrı tablo değil)', () => {
  assert.match(
    SEMA,
    /CREATE UNIQUE INDEX IF NOT EXISTS bildirimler_bolum_tekil\s+ON bildirimler \(kullanici_id, tmdb_id, sezon, bolum\) WHERE tur = 'bolum';/,
  );
  // Ayrı bir "gönderildi" tablosu açılmamış olmalı (ikinci doğruluk kaynağı).
  assert.ok(!/CREATE TABLE[^;]*bolum_bildirim/i.test(SEMA),
    'ayrı gönderildi tablosu açılmış — karar 3 e aykırı');
});

test('sema: kullanicilar.bildir_bolum var, varsayılan AÇIK', () => {
  assert.match(
    SEMA,
    /ADD COLUMN IF NOT EXISTS bildir_bolum BOOLEAN NOT NULL DEFAULT true/,
  );
});

// ===========================================================================
// 2) MİGRASYON
// ===========================================================================
test('migrasyon: idempotent (iki kez çalışsa patlamaz)', () => {
  assert.match(KOMUTLAR, /DROP CONSTRAINT IF EXISTS bildirimler_tur_check/);
  assert.match(KOMUTLAR, /ADD COLUMN IF NOT EXISTS tmdb_id INT/);
  assert.match(KOMUTLAR, /ADD COLUMN IF NOT EXISTS sezon INT/);
  assert.match(KOMUTLAR, /ADD COLUMN IF NOT EXISTS bolum INT/);
  assert.match(KOMUTLAR, /CREATE UNIQUE INDEX IF NOT EXISTS bildirimler_bolum_tekil/);
  assert.match(KOMUTLAR, /ADD COLUMN IF NOT EXISTS bildir_bolum BOOLEAN NOT NULL DEFAULT true/);
});

test('migrasyon: VERİ YAZMAZ / SİLMEZ (yalnız şema)', () => {
  assert.ok(!/\bDELETE\s+FROM\b/i.test(KOMUTLAR), 'migrasyon veri siliyor');
  assert.ok(!/\bDROP\s+TABLE\b/i.test(KOMUTLAR), 'migrasyon tablo düşürüyor');
  assert.ok(!/\bUPDATE\s+\w+\s+SET\b/i.test(KOMUTLAR), 'migrasyon veri güncelliyor');
  assert.ok(!/\bINSERT\s+INTO\b/i.test(KOMUTLAR), 'migrasyon veri yazıyor');
});

test('migrasyon: işlem içinde + gerekçe ve GERİ ALMA yorumu var', () => {
  assert.match(KOMUTLAR, /^BEGIN;/m);
  assert.match(KOMUTLAR, /^COMMIT;/m);
  assert.match(MIGRASYON, /GERİ ALMA/);
  assert.match(MIGRASYON, /md\. ?27/);
});

test('migrasyon: yeni CHECK eski ALTI türü aynen korur', () => {
  const m = /CHECK \(tur IN \(([^)]*)\)\)/.exec(KOMUTLAR);
  assert.ok(m, 'migrasyonda CHECK yok');
  for (const t of ['yanit', 'begeni', 'takip', 'mesaj', 'etiket', 'kacirilan_arama', 'bolum']) {
    assert.match(m[1], new RegExp(`'${t}'`), `${t} türü listede yok`);
  }
});

test('migrasyon ve sema aynı indeks yüklemini yazar (ON CONFLICT çıkarımı)', () => {
  const al = (s) => /bildirimler_bolum_tekil\s+ON bildirimler \(([^)]*)\) WHERE tur = 'bolum'/
    .exec(s)?.[1];
  assert.equal(al(KOMUTLAR), 'kullanici_id, tmdb_id, sezon, bolum');
  assert.equal(al(SEMA), 'kullanici_id, tmdb_id, sezon, bolum');
});

// ===========================================================================
// 3) *** KULLANICI KURALI *** — asıl iş (saf, DB'siz)
// ===========================================================================
const izlenenSezon = (sezon, adet) => {
  const k = new Set();
  for (let b = 1; b <= adet; b++) k.add(`${sezon}:${b}`);
  return k;
};

test('KURAL: 1. sezondaki kullanıcıya 10. sezon bölümü BİLDİRİLMEZ', () => {
  // Maddenin kendi örneği. Kullanıcı 1. sezonun 10 bölümünü izlemiş;
  // dizi 10. sezonun 5. bölümünü yayınlıyor.
  const d = dizi(10, 5, DUN, [[1, 10], [2, 10], [9, 10], [10, 5]]);
  const aday = yeniBolumAdayi(d, BUGUN);
  assert.deepEqual({ sezon: aday.sezon, bolum: aday.bolum }, { sezon: 10, bolum: 5 });
  const onceki = oncekiBolum(d, aday.sezon, aday.bolum);
  assert.deepEqual(onceki, { sezon: 10, bolum: 4 });
  assert.equal(
    bolumBildirilsinMi({ izlenen: izlenenSezon(1, 10), sezon: 10, bolum: 5, onceki }),
    false,
  );
});

test('KURAL: bir öncekini İZLEMİŞ kullanıcıya bildirim GİDER', () => {
  const d = dizi(10, 5, DUN, [[1, 10], [9, 10], [10, 5]]);
  const onceki = oncekiBolum(d, 10, 5);
  const izlenen = new Set(['10:1', '10:2', '10:3', '10:4']);
  assert.equal(bolumBildirilsinMi({ izlenen, sezon: 10, bolum: 5, onceki }), true);
});

test('KURAL: kullanıcı O BÖLÜMÜ zaten izlemişse bildirim GİTMEZ', () => {
  const d = dizi(3, 7, DUN, [[1, 10], [2, 10], [3, 7]]);
  const onceki = oncekiBolum(d, 3, 7);
  const izlenen = new Set(['3:6', '3:7']); // hem öncekini hem yenisini izlemiş
  assert.equal(bolumBildirilsinMi({ izlenen, sezon: 3, bolum: 7, onceki }), false);
});

test('KURAL: ARAYI ATLAMIŞ kullanıcıya bildirim GİTMEZ (B-2 izlenmiş, B-1 değil)', () => {
  const d = dizi(2, 6, DUN, [[1, 8], [2, 6]]);
  const onceki = oncekiBolum(d, 2, 6);
  assert.equal(
    bolumBildirilsinMi({ izlenen: new Set(['2:1', '2:2', '2:3', '2:4']), sezon: 2, bolum: 6, onceki }),
    false,
  );
});

test('KURAL: hiç bölüm izlememiş kullanıcıya bildirim GİTMEZ', () => {
  const d = dizi(4, 2, DUN, [[1, 10], [2, 10], [3, 10], [4, 2]]);
  const onceki = oncekiBolum(d, 4, 2);
  assert.equal(bolumBildirilsinMi({ izlenen: new Set(), sezon: 4, bolum: 2, onceki }), false);
  assert.equal(bolumBildirilsinMi({ izlenen: [], sezon: 4, bolum: 2, onceki }), false);
});

// --- SEZON GEÇİŞİ (B == 1) ---
test('SEZON GEÇİŞİ: önceki sezonun SON bölümünü izlemişse GİDER', () => {
  // S3B1 çıktı; önceki sezon S2 ve 10 bölümlük → aranan izleme "2:10".
  const d = dizi(3, 1, DUN, [[1, 8], [2, 10], [3, 1]]);
  const onceki = oncekiBolum(d, 3, 1);
  assert.deepEqual(onceki, { sezon: 2, bolum: 10 });
  assert.equal(bolumBildirilsinMi({ izlenen: new Set(['2:9', '2:10']), sezon: 3, bolum: 1, onceki }), true);
});

test('SEZON GEÇİŞİ: önceki sezonun son bölümünü İZLEMEMİŞSE GİTMEZ', () => {
  const d = dizi(3, 1, DUN, [[1, 8], [2, 10], [3, 1]]);
  const onceki = oncekiBolum(d, 3, 1);
  // S2 nin 9. bölümüne kadar gelmiş, finali izlememiş.
  assert.equal(bolumBildirilsinMi({ izlenen: izlenenSezon(2, 9), sezon: 3, bolum: 1, onceki }), false);
});

test('SEZON GEÇİŞİ: özel sezon (0) ve numarası ATLAYAN sezonlar', () => {
  // Özel sezon 0 asla "önceki sezon" olamaz; S4 yokken S5B1 in öncesi S3 tür.
  const d = dizi(5, 1, DUN, [[0, 12], [1, 8], [3, 6], [5, 1]]);
  assert.deepEqual(oncekiBolum(d, 5, 1), { sezon: 3, bolum: 6 });
  const onceki = oncekiBolum(d, 5, 1);
  assert.equal(bolumBildirilsinMi({ izlenen: new Set(['3:6']), sezon: 5, bolum: 1, onceki }), true);
  assert.equal(bolumBildirilsinMi({ izlenen: new Set(['1:8']), sezon: 5, bolum: 1, onceki }), false);
});

test('SEZON GEÇİŞİ: önceki sezonun bölüm sayısı bilinmiyorsa SESSİZ KAL', () => {
  // episode_count 0/eksik → yanlış bölümü sormaktansa hiç bildirme.
  assert.equal(oncekiBolum(dizi(2, 1, DUN, [[1, 0], [2, 1]]), 2, 1), null);
  assert.equal(oncekiBolum({ seasons: [{ season_number: 1 }] }, 2, 1), null);
  assert.equal(
    bolumBildirilsinMi({ izlenen: new Set(['1:8']), sezon: 2, bolum: 1, onceki: null }),
    false,
  );
});

test('S1B1: dizinin İLK bölümü için bildirim GİTMEZ', () => {
  const d = dizi(1, 1, DUN, [[1, 8]]);
  assert.equal(oncekiBolum(d, 1, 1), null);
  assert.equal(bolumBildirilsinMi({ izlenen: new Set(), sezon: 1, bolum: 1, onceki: null }), false);
});

test('KURAL: bozuk girdi hiçbir zaman true dönmez', () => {
  const onceki = { sezon: 1, bolum: 1 };
  const izlenen = new Set(['1:1', '0:0']);
  assert.equal(bolumBildirilsinMi({ izlenen, sezon: 0, bolum: 1, onceki }), false); // özel sezon
  assert.equal(bolumBildirilsinMi({ izlenen, sezon: 1, bolum: 0, onceki }), false);
  assert.equal(bolumBildirilsinMi({ izlenen, sezon: null, bolum: 2, onceki }), false);
  assert.equal(bolumBildirilsinMi({ izlenen, sezon: 1, bolum: 2, onceki: undefined }), false);
});

test('izlenen listesi hem [[s,b]] hem [{sezon,bolum}] biçiminde kabul edilir', () => {
  const onceki = { sezon: 2, bolum: 4 };
  assert.equal(bolumBildirilsinMi({ izlenen: [[2, 4]], sezon: 2, bolum: 5, onceki }), true);
  assert.equal(
    bolumBildirilsinMi({ izlenen: [{ sezon: 2, bolum: 4 }], sezon: 2, bolum: 5, onceki }), true,
  );
});

// ===========================================================================
// 4) 14 GÜNLÜK PENCERE (maliyet freni)
// ===========================================================================
test('pencere: sabit 14 gün ve gunEkle doğru sayıyor (ay/yıl sınırı dahil)', () => {
  assert.equal(YENI_BOLUM_PENCERE_GUN, 14);
  assert.equal(gunEkle('2026-08-13', -14), '2026-07-30');
  assert.equal(gunEkle('2026-01-05', -14), '2025-12-22');
  assert.equal(gunEkle('2026-03-01', -1), '2026-02-28');
  assert.equal(gunEkle('bozuk', -1), null);
});

test('pencere: 14 gün İÇİNDE yayınlanan bölüm ADAY', () => {
  const d = dizi(2, 3, gunEkle(BUGUN, -13), [[1, 8], [2, 3]]);
  assert.deepEqual(yeniBolumAdayi(d, BUGUN), {
    sezon: 2, bolum: 3, tarih: '2026-07-31',
  });
  // tam sınır (14 gün önce) hâlâ aday
  assert.ok(yeniBolumAdayi(dizi(2, 3, gunEkle(BUGUN, -14), [[1, 8]]), BUGUN));
});

test('pencere: 14 GÜNDEN ESKİ bölüm bildirim ÜRETMEZ', () => {
  assert.equal(yeniBolumAdayi(dizi(2, 3, gunEkle(BUGUN, -15), [[1, 8]]), BUGUN), null);
  assert.equal(yeniBolumAdayi(dizi(2, 3, '2024-01-01', [[1, 8]]), BUGUN), null);
});

test('pencere: GELECEK tarihli / özel sezon / tarihsiz bölüm aday DEĞİL', () => {
  assert.equal(yeniBolumAdayi(dizi(2, 3, gunEkle(BUGUN, 1), [[1, 8]]), BUGUN), null);
  assert.equal(yeniBolumAdayi(dizi(0, 1, DUN, [[0, 5]]), BUGUN), null); // özel sezon
  assert.equal(yeniBolumAdayi(dizi(2, 3, null, [[1, 8]]), BUGUN), null);
  assert.equal(yeniBolumAdayi({}, BUGUN), null);
  assert.equal(yeniBolumAdayi(null, BUGUN), null);
});

// ===========================================================================
// 5) HACİM FRENİ + ZAMANLAMA
// ===========================================================================
test('hacim freni: tur başına kullanıcı başına en fazla 3 bildirim', () => {
  assert.equal(YENI_BOLUM_TUR_SINIRI, 3);
  const g = fnGovdesi('yeniBolumleriBildir');
  assert.match(g, /sayac\.get\(id\) \|\| 0\) < YENI_BOLUM_TUR_SINIRI/,
    'aday süzgeci hacim frenini uygulamıyor');
  // Sayaç YALNIZ gerçekten yazılan bildirimde artmalı (çakışan INSERT kotayı
  // yemesin) — artış `bolumBildirimiEkle` true dönüşünün İÇİNDE olmalı.
  assert.match(g, /if \(await bolumBildirimiEkle\([\s\S]{0,120}?sayac\.set\(id/);
});

test('zamanlama: 6 saatte bir, ISCI_GOREVLI kapısında, açılıştan dakikalar sonra', () => {
  const m = /if \(ISCI_GOREVLI\) \{\s*setInterval\(yeniBolumleriBildir, ([^)]*)\);\s*(?:\/\/[^\n]*\n\s*)*\/\/[^\n]*\n\s*\/\/[^\n]*\n\s*setTimeout\(yeniBolumleriBildir, ([^)]*)\);/
    .exec(KAYNAK);
  assert.ok(m, 'yeniBolumleriBildir ISCI_GOREVLI kapısında kurulmamış');
  // eslint-disable-next-line no-eval
  assert.equal(eval(m[1]), 6 * 60 * 60 * 1000, 'aralık 6 saat olmalı');
  // eslint-disable-next-line no-eval
  const ilk = eval(m[2]);
  assert.ok(ilk >= 60 * 1000 && ilk <= 10 * 60 * 1000, 'ilk tur dakikalar içinde olmalı');
});

// ===========================================================================
// 6) ADAY SORGUSU + MALİYET (dizi başına TEK TMDB çağrısı, N+1 yok)
// ===========================================================================
test('aday sorgusu: izliyorum + tv + en az bir bölüm izlemesi + tercih açık', () => {
  const g = fnGovdesi('yeniBolumleriBildir');
  assert.match(g, /d\.durum='izliyorum'/, "yalnız 'izliyorum' taranmalı");
  assert.match(g, /d\.tur='tv'/);
  assert.match(g, /EXISTS \(SELECT 1 FROM izlemeler i/, 'bölüm izlemesi şartı yok');
  assert.match(g, /i\.sezon >= 1/, 'özel sezon izlemesi aday saymamalı');
  assert.match(g, /k\.bildir_bolum/, 'tercih kapısı aday sorgusunda yok');
  assert.match(g, /NOT k\.yasakli/, 'yasaklı kullanıcıya push gitmemeli');
});

test('maliyet: dizi BAŞINA tek TMDB çağrısı (kullanıcı başına değil)', () => {
  const g = fnGovdesi('yeniBolumleriBildir');
  assert.match(g, /GROUP BY d\.tmdb_id/, 'diziye göre gruplanmıyor → kullanıcı başına çağrı');
  assert.match(g, /array_agg\(d\.kullanici_id\)/);
  // Toplu getirici TEK kez, döngü DIŞINDA çağrılmalı.
  assert.equal((g.match(/tmdbTopluGetir\(/g) || []).length, 1);
  assert.ok(!/tmdbGetir\(|diziDetay\(/.test(g), 'döngü içinde tekil TMDB çağrısı var');
  // Bayat veriyle yeni bölüm kaçmasın: TTL "uzun" DEĞİL.
  assert.match(g, /ONBELLEK_TTL_SN\.varsayilan/);
  assert.ok(!/ONBELLEK_TTL_SN\.uzun/.test(g));
});

test('maliyet: bir dizinin izlemeleri TEK sorguda (kullanıcı başına sorgu YOK)', () => {
  const g = fnGovdesi('yeniBolumleriBildir');
  assert.match(g, /kullanici_id = ANY\(\$2::int\[\]\)/);
  // Kullanıcı döngüsünün içinde `havuz.query` olmamalı; tek yazıcı
  // `bolumBildirimiEkle` (o da yalnız GERÇEKTEN bildirilecek kullanıcı için).
  const dongu = /for \(const id of adaylar\) \{[\s\S]*?\n {8}\}/.exec(g);
  assert.ok(dongu, 'kullanıcı döngüsü bulunamadı');
  assert.ok(!/havuz\.query/.test(dongu[0]), 'kullanıcı döngüsünde ham sorgu var (N+1)');
});

test('dayanıklılık: tek dizinin hatası turu düşürmez', () => {
  const g = fnGovdesi('yeniBolumleriBildir');
  // İç döngüde kendi try/catch i olmalı + dış sarmalayıcı.
  assert.ok((g.match(/try \{/g) || []).length >= 2, 'dizi başına try/catch yok');
  assert.match(g, /catch \(e\) \{[\s\S]*?console\.error\(`yeni bolum \(tv\//);
});

// ===========================================================================
// 7) YAZICI: bolumBildirimiEkle (tekrar önleme + tercih + push)
// ===========================================================================
test('yazıcı: ON CONFLICT kısmi indeksi hedefler ve DO NOTHING der', () => {
  const g = fnGovdesi('bolumBildirimiEkle');
  assert.match(
    g,
    /ON CONFLICT \(kullanici_id, tmdb_id, sezon, bolum\) WHERE tur='bolum'\s*\n?\s*DO NOTHING/,
  );
});

test('yazıcı: PUSH yalnız satır GERÇEKTEN yazıldıysa gider', () => {
  const g = fnGovdesi('bolumBildirimiEkle');
  const i = g.indexOf('rowCount');
  const j = g.indexOf('pushBildirim');
  assert.ok(i > 0 && j > i, 'rowCount kapısı push tan ÖNCE olmalı');
  assert.match(g, /if \(!y\.rowCount\) return false;/);
});

test('yazıcı: tercih kapalıysa NE kayıt NE push', () => {
  const g = fnGovdesi('bolumBildirimiEkle');
  const t = g.indexOf('bildir_bolum');
  assert.ok(t > 0, 'tercih kontrolü yok');
  assert.ok(t < g.indexOf('INSERT INTO bildirimler'), 'tercih INSERT ten SONRA bakılıyor');
  assert.match(g, /if \(t\.rows\.length && t\.rows\[0\]\.ac === false\) return false;/);
});

test('yazıcı: aktörsüz — pushBildirim e aktorId olarak null verilir', () => {
  assert.match(fnGovdesi('bolumBildirimiEkle'), /pushBildirim\(aliciId, 'bolum', null, \{/);
});

test('yazıcı: bildirimEkle KULLANILMIYOR (aktör varsayar + koşulsuz push atar)', () => {
  const g = fnGovdesi('bolumBildirimiEkle');
  assert.ok(!/bildirimEkle\(/.test(g), 'bildirimEkle aktör varsayar, burada kullanılamaz');
  // bildirimEkle in kendi davranışı korunuyor mu (regresyon):
  const b = fnGovdesi('bildirimEkle');
  assert.match(b, /if \(!aliciId \|\| aliciId === aktorId\) return;/);
});

test('yazıcı: girdi doğrulaması (tmdb_id/sezon/bolum)', () => {
  assert.match(
    fnGovdesi('bolumBildirimiEkle'),
    /!gecerliTmdb\(tmdbId\) \|\| !\(sezon >= 1\) \|\| !\(bolum >= 1\)/,
  );
});

// ===========================================================================
// 8) TERCİH UÇLARI
// ===========================================================================
test('tercih: BILDIRIM_TERCIH_KOLON da bolum -> bildir_bolum', () => {
  assert.equal(BILDIRIM_TERCIH_KOLON.bolum, 'bildir_bolum');
  // Diğer türler bozulmamış
  assert.equal(BILDIRIM_TERCIH_KOLON.begeni, 'bildir_begeni');
  assert.equal(BILDIRIM_TERCIH_KOLON.kacirilan_arama, 'bildir_arama');
});

test('tercih: GET ve POST /bildirim-tercihleri bildir_bolum u içerir', () => {
  assert.ok(BILDIRIM_TERCIH_ALANLARI.includes('bildir_bolum'));
  for (const a of ['bildir_begeni', 'bildir_yanit', 'bildir_takip', 'bildir_mesaj', 'bildir_etiket']) {
    assert.ok(BILDIRIM_TERCIH_ALANLARI.includes(a), `${a} listeden düşmüş`);
  }
  // Üç yer de AYNI listeden üretilmeli (seç / kabul et / geri döndür).
  const g = ucGovdesi('/bildirim-tercihleri', 'get');
  const p = ucGovdesi('/bildirim-tercihleri', 'post');
  assert.match(g, /SELECT \$\{BILDIRIM_TERCIH_ALANLARI\.join\(', '\)\}/,
    'GET listeyi elle yazıyor');
  assert.match(p, /for \(const a of BILDIRIM_TERCIH_ALANLARI\)/,
    'POST kabul ettiği anahtarları listeden almıyor');
  assert.match(p, /RETURNING \$\{BILDIRIM_TERCIH_ALANLARI\.join\(', '\)\}/,
    'POST döndürdüğü alanları listeden almıyor');
});

test('tercih: POST hâlâ yalnız boolean kabul eder (SQL enjeksiyonu yok)', () => {
  const p = ucGovdesi('/bildirim-tercihleri', 'post');
  assert.match(p, /typeof g\[a\] === 'boolean'/);
  assert.match(p, /set\.push\(`\$\{a\}=\$\$\{deg\.length\}`\)/);
});

// ===========================================================================
// 9) GET /bildirimler — 'bolum' satırı + N+1 yok
// ===========================================================================
test('/bildirimler: bolum satırı tmdb_id/sezon/bolum döndürür', () => {
  const g = ucGovdesi('/bildirimler', 'get');
  assert.match(g, /b\.tmdb_id, b\.sezon, b\.bolum/);
});

test('/bildirimler: dizi_adi + poster ZENGİNLEŞTİRMESİ var', () => {
  const g = ucGovdesi('/bildirimler', 'get');
  assert.match(g, /r\.dizi_adi = d\?\.name \|\| null;/);
  assert.match(g, /r\.poster = d\?\.poster_path \|\| null;/);
  assert.match(g, /r\.tur === 'bolum'/);
});

test('/bildirimler: N+1 YOK — sayfadaki bölümler için TEK toplu çağrı', () => {
  const g = ucGovdesi('/bildirimler', 'get');
  assert.equal((g.match(/tmdbTopluGetir\(/g) || []).length, 1);
  assert.ok(!/tmdbGetir\(|diziDetay\(/.test(g), 'tekil TMDB çağrısı = N+1');
  // Zenginleştirme döngüsünde await OLMAMALI (await varsa seri N istek demek).
  const dongu = /for \(const r of bolumler\) \{[\s\S]*?\n {4}\}/.exec(g);
  assert.ok(dongu && !/await/.test(dongu[0]), 'zenginleştirme döngüsünde await var');
});

test('/bildirimler: TMDB tökezlerse kutu yine de açılır', () => {
  assert.match(ucGovdesi('/bildirimler', 'get'), /\.catch\(\(\) => new Map\(\)\)/);
});

test("/bildirimler: aktör alanları 'bolum' türünde NULL kalır (LEFT JOIN)", () => {
  const g = ucGovdesi('/bildirimler', 'get');
  assert.match(g, /LEFT JOIN kullanicilar k ON k\.id = b\.aktor_id/);
  assert.match(g, /k\.kullanici_adi AS aktor, k\.avatar AS aktor_avatar/);
});

// ===========================================================================
// 10) PUSH — 16 dil + data yükü
// ===========================================================================
test('push: 16 dilin HEPSİNDE bolum şablonu var ve {dizi}/{sb} taşıyor', () => {
  const diller = Object.keys(PUSH_SABLON);
  assert.equal(diller.length, 16, 'dil sayısı değişmiş');
  for (const d of diller) {
    const s = PUSH_SABLON[d].bolum;
    assert.ok(s, `${d} dilinde bolum şablonu yok`);
    assert.ok(s.includes('{dizi}'), `${d}: {dizi} yer tutucusu yok`);
    assert.ok(s.includes('{sb}'), `${d}: {sb} yer tutucusu yok`);
    assert.ok(!s.includes('{ad}'), `${d}: bolum türünün aktörü yok, {ad} olamaz`);
  }
  assert.equal(PUSH_SABLON.tr.bolum, '{dizi} {sb} yayınlandı');
  assert.equal(PUSH_SABLON.en.bolum, '{dizi} {sb} is out');
});

test('push: her dilde eski 7 tür de duruyor (regresyon)', () => {
  for (const [d, s] of Object.entries(PUSH_SABLON)) {
    for (const t of ['takip', 'begeni', 'yanit', 'mesaj', 'etiket', 'arama', 'kacirilan_arama']) {
      assert.ok(s[t], `${d}.${t} kayboldu`);
    }
  }
});

test('push: {sb} etiketi tr de "S5B3", diğer dillerde "S5E3"', () => {
  assert.equal(sbEtiketi('tr', 5, 3), 'S5B3');
  assert.equal(sbEtiketi('en', 5, 3), 'S5E3');
  assert.equal(sbEtiketi('ja', 12, 1), 'S12E1');
});

test('push: bolum gövdesi {dizi}/{sb} ile kurulur, {ad} ile DEĞİL', () => {
  const g = fnGovdesi('pushBildirim');
  assert.match(g, /tur === 'bolum'\s*\n?\s*\? \(sablon\.bolum \|\| ''\)/);
  assert.match(g, /\.replace\('\{dizi\}'/);
  assert.match(g, /\.replace\('\{sb\}', sbEtiketi\(dil, ekstra\?\.sezon, ekstra\?\.bolum\)\)/);
});

test('push: data yükü tur/tmdb_id/sezon/bolum ve HEPSİ STRING', () => {
  const g = fnGovdesi('pushBildirim');
  assert.match(g, /veri\.tmdb_id = String\(ekstra\?\.tmdb_id \?\? ''\);/);
  assert.match(g, /veri\.sezon = String\(ekstra\?\.sezon \?\? ''\);/);
  assert.match(g, /veri\.bolum = String\(ekstra\?\.bolum \?\? ''\);/);
  assert.match(g, /tur: String\(tur\),/);
});

test('push: aktörsüz türde kullanıcı sorgusu HİÇ yapılmaz', () => {
  const g = fnGovdesi('pushBildirim');
  assert.match(g, /aktorId\s*\n?\s*\? havuz\.query\('SELECT kullanici_adi, avatar/);
  assert.match(g, /: Promise\.resolve\(\{ rows: \[\] \}\)/);
});

test('push: bolum türü SIRADAN bildirim paketiyle gider (arama/mesaj dalı değil)', () => {
  // 'bolum' data-only olmamalı: sistem bildirimi bassın, kanal dizijpg_bildirim.
  const g = fnGovdesi('pushBildirim');
  assert.match(g, /if \(tur === 'arama'\)/);
  assert.match(g, /\} else if \(tur === 'mesaj'\)/);
  assert.ok(!/tur === 'bolum'[\s\S]{0,80}priority: 'high', ttl/.test(g));
  assert.match(g, /channelId: 'dizijpg_bildirim'/);
});

// ===========================================================================
// 11) UÇTAN UCA (saf) — görevin karar zinciri baştan sona
// ===========================================================================
test('uçtan uca: aynı dizi, dört farklı kullanıcı, tek doğru sonuç', () => {
  // Dizi: 10 sezon; 10. sezonun 5. bölümü DÜN yayınlandı.
  const d = dizi(10, 5, DUN, [[0, 6], [1, 10], [9, 10], [10, 5]]);
  const aday = yeniBolumAdayi(d, BUGUN);
  const onceki = oncekiBolum(d, aday.sezon, aday.bolum);
  const karar = (izlenen) => bolumBildirilsinMi({
    izlenen, sezon: aday.sezon, bolum: aday.bolum, onceki,
  });
  assert.equal(karar(izlenenSezon(1, 10)), false); // 1. sezondaki — GİTMEZ
  assert.equal(karar(new Set(['10:3', '10:4'])), true); // güncel — GİDER
  assert.equal(karar(new Set(['10:4', '10:5'])), false); // zaten izlemiş
  assert.equal(karar(new Set()), false); // hiç işaretlememiş
});

test('uçtan uca: eski bölüm hiçbir kullanıcı için bildirim üretmez', () => {
  // Aynı senaryo ama bölüm 20 gün önce yayınlanmış: aday yok → kullanıcı
  // satırlarına HİÇ bakılmaz (maliyet freni).
  const d = dizi(10, 5, gunEkle(BUGUN, -20), [[1, 10], [10, 5]]);
  assert.equal(yeniBolumAdayi(d, BUGUN), null);
});
