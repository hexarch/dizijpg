// Favori kişinin yeni yapımı bildirimi testleri — `node --test test/*.test.js`
//
// KORUNAN KARARLAR (13 Ağu 2026, migrasyon-2026-08-13c.sql · istek md. 28):
//
//  1) *** KAPSAM *** Favori KİŞİ (oyuncu/yönetmen AYRIMI ŞEMADA YOK —
//     `favoriler.tur` yalnız 'person' der). `cast` kredileri + `crew`
//     kredilerinden YALNIZ Director/Creator sayılır; bütün crew tek favoriden
//     düzinelerce bildirim üretirdi.
//  2) *** YENİ = SON 21 GÜN, GELECEK DEĞİL *** Pencere md. 27'nin 14'ünden
//     UZUN çünkü kişi kredileri topluluk tarafından elle giriliyor (geç
//     tamamlanabiliyor) ve bu görev 6 saatte bir değil GÜNDE BİR koşuyor.
//     Gelecek tarihli yapım BİLDİRİLMEZ: duyuru tarihinde bildirseydik tarih
//     kayınca gerçek çıkışta bir daha bildiremezdik (tekil indeks).
//  3) *** KİTAPLIKTA OLAN BİLDİRİLMEZ *** "Kitaplık" en geniş anlamıyla:
//     `durumlar`da HERHANGİ bir durum ('izleyecegim' dahil), `izlemeler`de
//     kayıt, ya da `gizli_icerikler` (kullanıcı görmek istemediğini söylemiş).
//  4) *** TEKRAR ÖNLEME: kısmi tekil indeks, ANAHTARDA `kisi_id` YOK ***
//     Aynı kullanıcıya aynı YAPIM için ikinci bildirim ASLA — bir filmde üç
//     favori oyuncu olsa bile. Push yalnız satır gerçekten yazıldıysa gider.
//  5) *** KİŞİNİN id'si `sezon` SÜTUNUNA SIKIŞTIRILMADI *** ayrı `kisi_id` +
//     `icerik_tur` sütunları; `tmdb_id` md. 27'den devralınır ve YENİ YAPIMIN
//     id'sidir.
//  6) *** İKİ KATMANLI TERCİH *** genel `bildir_kisi` (boolean) + kişi bazlı
//     `favoriler.bildirim` üç durumlu ('acik'|'uygulama'|'kapali').
//     'uygulama' = SATIR YAZILIR, PUSH GİTMEZ.
//  7) *** KİŞİ BAŞINA TEK TMDB ÇAĞRISI *** aday sorgusu kişiye göre gruplanır
//     (`GROUP BY f.tmdb_id`); `append_to_response=combined_credits` sayesinde
//     ad ve krediler tek yanıtta gelir (ikinci `/person/{id}` çağrısı YOK).
//
// Neden kaynak okuma: `server.js` içe aktarıldığı anda `app.listen` çağırıyor
// (yeni_bolum_bildirimi.test.js ile aynı gerekçe). Saf yardımcılar kaynaktan
// ÇEKİLİP gerçekten ÇALIŞTIRILIYOR — test canlıdaki kodu sınar, kopyasını değil.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const oku = (a) => fs.readFileSync(path.join(KOK, a), 'utf8');

const KAYNAK = oku('server.js');
const SEMA = oku('sema.sql');
const MIGRASYON = oku('migrasyon-2026-08-13c.sql');

// Migrasyonun YORUM OLMAYAN satırları: gerekçe metinleri komut sanılmasın
// (geri alma bölümü bilerek DELETE/DROP örneği içerir).
const KOMUTLAR = MIGRASYON.split('\n')
  .filter((s) => !s.trim().startsWith('--')).join('\n');

// ---------------------------------------------------------------------------
// Kaynaktan bildirim çekme (yeni_bolum_bildirimi.test.js'teki kalıp)
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
const ADLAR = ['YENI_YAPIM_PENCERE_GUN', 'YENI_YAPIM_KISI_SINIRI',
  'YENI_YAPIM_TUR_SINIRI', 'YENI_YAPIM_OBEK', 'YENI_YAPIM_ISLERI',
  'gunEkle', 'yeniYapimlar', 'PUSH_SABLON', 'BILDIRIM_TERCIH_KOLON',
  'BILDIRIM_TERCIH_ALANLARI', 'KISI_BILDIRIM_KIPLERI'];
const SAF = new Function(
  `${ADLAR.map((a) => bildirimCek(KAYNAK, a)).join('\n')}\nreturn { ${ADLAR.join(', ')} };`,
)();
const {
  YENI_YAPIM_PENCERE_GUN, YENI_YAPIM_KISI_SINIRI, YENI_YAPIM_TUR_SINIRI,
  YENI_YAPIM_OBEK, YENI_YAPIM_ISLERI, gunEkle, yeniYapimlar, PUSH_SABLON,
  BILDIRIM_TERCIH_KOLON, BILDIRIM_TERCIH_ALANLARI, KISI_BILDIRIM_KIPLERI,
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

/** `async function ad(...) { ... }` gövdesi (süslü parantez dengesiyle). */
function fnGovdesi(ad) {
  const m = new RegExp(`^(?:async )?function ${ad}\\b`, 'm').exec(KAYNAK);
  assert.ok(m, `${ad} fonksiyonu bulunamadı`);
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

const BUGUN = '2026-08-13';
const DUN = '2026-08-12';

/** TMDB `/person/{id}?append_to_response=combined_credits` gövdesinin gereken kadarı. */
const kisi = (cast = [], crew = [], ad = 'Bryan Cranston') => ({
  id: 17419,
  name: ad,
  combined_credits: { cast, crew },
});

/** Tek bir kredi satırı. */
const kredi = (o = {}) => ({
  id: 1396,
  media_type: 'movie',
  title: 'Yeni Film',
  poster_path: '/p.jpg',
  release_date: DUN,
  ...o,
});

const diziKredisi = (o = {}) => kredi({
  media_type: 'tv', name: 'Yeni Dizi', title: undefined,
  release_date: undefined, first_air_date: DUN, ...o,
});

// ===========================================================================
// 1) ŞEMA (sema.sql)
// ===========================================================================
test('sema: bildirimler.tur CHECK ı "kisi" türünü kabul eder', () => {
  // 29 Ağu 2026: 'sondaki tur CHECK ı bildirimler inkidir' varsayımı GIF arşivi
  // sikayetler.tur CHECK ını sema.sql sonuna ekleyince çöktü. Kısıt artık ADIYLA
  // aranıyor — başka tablo sona eklenince bir daha kaymaz.
  const son = (SEMA.match(
    /bildirimler_tur_check\s+CHECK \(tur IN \([^)]*\)\)/g) || []).pop();
  assert.ok(son, 'bildirimler tur CHECK ı bulunamadı');
  assert.match(son, /'kisi'/, "sema.sql 'kisi' türünü kabul etmiyor");
});

test('sema: ÖNCEKİ YEDİ tür CHECK ten DÜŞMEDİ (md.27 ve 8 Ağu dahil)', () => {
  // 29 Ağu 2026: 'sondaki tur CHECK ı bildirimler inkidir' varsayımı GIF arşivi
  // sikayetler.tur CHECK ını sema.sql sonuna ekleyince çöktü. Kısıt artık ADIYLA
  // aranıyor — başka tablo sona eklenince bir daha kaymaz.
  const son = (SEMA.match(
    /bildirimler_tur_check\s+CHECK \(tur IN \([^)]*\)\)/g) || []).pop();
  for (const t of ['yanit', 'begeni', 'takip', 'mesaj', 'etiket',
    'kacirilan_arama', 'bolum']) {
    assert.match(son, new RegExp(`'${t}'`), `${t} türü kayboldu`);
  }
});

test('sema: kisi_id + icerik_tur NULLABLE eklendi, icerik_tur KAPALI SÖZLÜK', () => {
  assert.match(SEMA, /ALTER TABLE bildirimler ADD COLUMN IF NOT EXISTS kisi_id INT;/);
  assert.match(SEMA, /ALTER TABLE bildirimler ADD COLUMN IF NOT EXISTS icerik_tur TEXT;/);
  assert.ok(
    !/ADD COLUMN IF NOT EXISTS (kisi_id|icerik_tur) (INT|TEXT) NOT NULL/.test(SEMA),
    'hedef sütunları NOT NULL olamaz (diğer yedi tür NULL bırakır)',
  );
  assert.match(
    SEMA,
    /CHECK \(icerik_tur IS NULL OR icerik_tur IN \('tv','movie'\)\)/,
    'icerik_tur serbest metin kabul ediyor — bozuk /icerik/{tur}/{id} üretilebilir',
  );
});

test('sema: KİŞİNİN id si `sezon`/`bolum` sütunlarına SIKIŞTIRILMADI', () => {
  // md. 27 sütunlarının anlamı ("sezon numarası") korunmalı; kişi id sini
  // oraya yazmak "sezon > 20" gibi her gelecek sorguyu sessizce bozardı.
  const g = fnGovdesi('kisiBildirimiEkle');
  assert.ok(!/\bsezon\b/.test(g), 'kisi yazıcısı `sezon` sütununa dokunuyor');
  assert.ok(!/\bbolum\b/.test(g), 'kisi yazıcısı `bolum` sütununa dokunuyor');
  assert.match(g, /INSERT INTO bildirimler \(kullanici_id, tur, kisi_id, icerik_tur, tmdb_id\)/);
});

test('sema: tekrar önleme KISMİ TEKİL İNDEKS ve anahtarda kisi_id YOK', () => {
  assert.match(
    SEMA,
    /CREATE UNIQUE INDEX IF NOT EXISTS bildirimler_kisi_tekil\s+ON bildirimler \(kullanici_id, icerik_tur, tmdb_id\) WHERE tur = 'kisi';/,
  );
  const anahtar = /bildirimler_kisi_tekil\s+ON bildirimler \(([^)]*)\)/.exec(SEMA)?.[1];
  assert.ok(!/kisi_id/.test(anahtar),
    'anahtarda kisi_id var — aynı yapımdaki üç favori üç bildirim üretir');
  // Ayrı bir "gönderildi" tablosu açılmamış olmalı (ikinci doğruluk kaynağı).
  assert.ok(!/CREATE TABLE[^;]*kisi_bildirim/i.test(SEMA),
    'ayrı gönderildi tablosu açılmış');
});

test('sema: md. 27 nin bolum tekil indeksi BOZULMADI (gerileme)', () => {
  assert.match(
    SEMA,
    /CREATE UNIQUE INDEX IF NOT EXISTS bildirimler_bolum_tekil\s+ON bildirimler \(kullanici_id, tmdb_id, sezon, bolum\) WHERE tur = 'bolum';/,
  );
});

test('sema: kullanicilar.bildir_kisi var, varsayılan AÇIK', () => {
  assert.match(SEMA, /ADD COLUMN IF NOT EXISTS bildir_kisi BOOLEAN NOT NULL DEFAULT true/);
});

test('sema: kişi bazlı tercih `favoriler.bildirim` (AYRI TABLO DEĞİL), 3 durum', () => {
  assert.match(SEMA, /ALTER TABLE favoriler\s+ADD COLUMN IF NOT EXISTS bildirim TEXT NOT NULL DEFAULT 'acik';/);
  assert.match(SEMA, /CHECK \(bildirim IN \('acik','uygulama','kapali'\)\)/);
  assert.ok(!/CREATE TABLE[^;]*kisi_bildirim_tercih/i.test(SEMA),
    'ayrı tercih tablosu açılmış — favori silinince öksüz satır kalırdı');
});

// ===========================================================================
// 2) MİGRASYON
// ===========================================================================
test('migrasyon: idempotent (iki kez çalışsa patlamaz)', () => {
  assert.match(KOMUTLAR, /DROP CONSTRAINT IF EXISTS bildirimler_tur_check/);
  assert.match(KOMUTLAR, /ADD COLUMN IF NOT EXISTS kisi_id INT/);
  assert.match(KOMUTLAR, /ADD COLUMN IF NOT EXISTS icerik_tur TEXT/);
  assert.match(KOMUTLAR, /CREATE UNIQUE INDEX IF NOT EXISTS bildirimler_kisi_tekil/);
  assert.match(KOMUTLAR, /ADD COLUMN IF NOT EXISTS bildir_kisi BOOLEAN NOT NULL DEFAULT true/);
  assert.match(KOMUTLAR, /ADD COLUMN IF NOT EXISTS bildirim TEXT NOT NULL DEFAULT 'acik'/);
  assert.match(KOMUTLAR, /DROP CONSTRAINT IF EXISTS favoriler_bildirim_check/);
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
  assert.match(MIGRASYON, /md\. ?28/);
});

test('migrasyon: yeni CHECK önceki YEDİ türü aynen korur', () => {
  const m = /CHECK \(tur IN \(([^)]*)\)\)/.exec(KOMUTLAR);
  assert.ok(m, 'migrasyonda CHECK yok');
  for (const t of ['yanit', 'begeni', 'takip', 'mesaj', 'etiket',
    'kacirilan_arama', 'bolum', 'kisi']) {
    assert.match(m[1], new RegExp(`'${t}'`), `${t} türü listede yok`);
  }
});

test('migrasyon ve sema aynı indeks yüklemini yazar (ON CONFLICT çıkarımı)', () => {
  const al = (s) => /bildirimler_kisi_tekil\s+ON bildirimler \(([^)]*)\) WHERE tur = 'kisi'/
    .exec(s)?.[1];
  assert.equal(al(KOMUTLAR), 'kullanici_id, icerik_tur, tmdb_id');
  assert.equal(al(SEMA), 'kullanici_id, icerik_tur, tmdb_id');
});

test('migrasyon: DOĞRULAMA bloğu kisi_id in anahtarda OLMADIĞINI denetler', () => {
  assert.match(MIGRASYON, /pg_get_indexdef/);
  assert.match(MIGRASYON, /bildirimler_kisi_tekil kisi_id iceriyor/);
});

// ===========================================================================
// 3) *** ASIL KURAL *** — "yeni yapım" süzgeci (saf, DB'siz)
// ===========================================================================
test('YENİ: son 21 gün içinde çıkmış yapım ADAY', () => {
  assert.equal(YENI_YAPIM_PENCERE_GUN, 21);
  const y = yeniYapimlar(kisi([kredi({ release_date: gunEkle(BUGUN, -20) })]), BUGUN);
  assert.equal(y.length, 1);
  assert.deepEqual(
    { tur: y[0].tur, tmdb_id: y[0].tmdb_id, ad: y[0].ad },
    { tur: 'movie', tmdb_id: 1396, ad: 'Yeni Film' },
  );
  // Tam sınır (21 gün önce) hâlâ aday.
  assert.equal(
    yeniYapimlar(kisi([kredi({ release_date: gunEkle(BUGUN, -21) })]), BUGUN).length, 1,
  );
});

test('ESKİ: 21 günden eski yapım BİLDİRİLMEZ', () => {
  assert.deepEqual(yeniYapimlar(kisi([kredi({ release_date: gunEkle(BUGUN, -22) })]), BUGUN), []);
  assert.deepEqual(yeniYapimlar(kisi([kredi({ release_date: '2019-01-01' })]), BUGUN), []);
});

test('GELECEK tarihli yapım BİLDİRİLMEZ (henüz çıkmadı)', () => {
  assert.deepEqual(yeniYapimlar(kisi([kredi({ release_date: gunEkle(BUGUN, 1) })]), BUGUN), []);
  assert.deepEqual(yeniYapimlar(kisi([kredi({ release_date: '2030-01-01' })]), BUGUN), []);
  // Bugün çıkan SAYILIR (sınır dahil).
  assert.equal(yeniYapimlar(kisi([kredi({ release_date: BUGUN })]), BUGUN).length, 1);
});

test('DİZİ: tarih first_air_date ten, ad `name` alanından okunur', () => {
  const y = yeniYapimlar(kisi([diziKredisi()]), BUGUN);
  assert.equal(y.length, 1);
  assert.equal(y[0].tur, 'tv');
  assert.equal(y[0].ad, 'Yeni Dizi');
  // Dizide release_date YOKTUR: filmin alanına bakılırsa hiç aday çıkmaz.
  assert.deepEqual(yeniYapimlar(kisi([diziKredisi({ first_air_date: '2019-01-01' })]), BUGUN), []);
});

test('SÜZGEÇ: postersiz / adsız / tarihsiz / yabancı media_type atılır', () => {
  assert.deepEqual(yeniYapimlar(kisi([kredi({ poster_path: null })]), BUGUN), []);
  assert.deepEqual(yeniYapimlar(kisi([kredi({ title: '  ' })]), BUGUN), []);
  assert.deepEqual(yeniYapimlar(kisi([kredi({ release_date: '' })]), BUGUN), []);
  assert.deepEqual(yeniYapimlar(kisi([kredi({ release_date: '2026' })]), BUGUN), []);
  assert.deepEqual(yeniYapimlar(kisi([kredi({ media_type: 'person' })]), BUGUN), []);
  assert.deepEqual(yeniYapimlar(kisi([kredi({ id: 0 })]), BUGUN), []);
});

test('SÜZGEÇ: bozuk/boş gövde çökertmez', () => {
  assert.deepEqual(yeniYapimlar(null, BUGUN), []);
  assert.deepEqual(yeniYapimlar({}, BUGUN), []);
  assert.deepEqual(yeniYapimlar(kisi(), BUGUN), []);
  assert.deepEqual(yeniYapimlar(kisi([null, undefined, 5]), BUGUN), []);
  assert.deepEqual(yeniYapimlar(kisi([kredi()]), 'bozuk-tarih'), []);
});

test('İKİ GÖVDE BİÇİMİ: append_to_response ve düz combined_credits', () => {
  const cast = [kredi()];
  // Görevin kullandığı biçim (kişinin adı da aynı yanıtta).
  assert.equal(yeniYapimlar({ name: 'X', combined_credits: { cast } }, BUGUN).length, 1);
  // `/kisi/:id/izlenme` ucunun kullandığı düz biçim.
  assert.equal(yeniYapimlar({ cast }, BUGUN).length, 1);
});

test('YÖNETMEN: crew den YALNIZ Director/Creator sayılır', () => {
  assert.deepEqual([...YENI_YAPIM_ISLERI].sort(), ['Creator', 'Director']);
  const yonetti = kisi([], [kredi({ job: 'Director', id: 700 })]);
  const y = yeniYapimlar(yonetti, BUGUN);
  assert.equal(y.length, 1);
  assert.equal(y[0].rol, 'yonetmen');
  // Diğer crew işleri SAYILMAZ: tek favoriden düzinelerce bildirim gelirdi.
  for (const is of ['Writer', 'Producer', 'Executive Producer', 'Thanks',
    'Stunts', 'Editor', undefined]) {
    assert.deepEqual(yeniYapimlar(kisi([], [kredi({ job: is })]), BUGUN), [],
      `crew işi "${is}" bildirim üretmemeli`);
  }
});

test('TEKİLLEŞTİRME: aynı yapımda iki rol / hem oyuncu hem yönetmen = TEK aday', () => {
  const iki = kisi(
    [kredi({ character: 'A' }), kredi({ character: 'B' })],
    [kredi({ job: 'Director' })],
  );
  const y = yeniYapimlar(iki, BUGUN);
  assert.equal(y.length, 1);
  assert.equal(y[0].rol, 'oyuncu', 'cast önce taranır');
  // Dizi 1396 ile film 1396 AYRI yapımlardır — tekilleştirme türü de içerir.
  assert.equal(yeniYapimlar(kisi([kredi(), diziKredisi({ id: 1396 })]), BUGUN).length, 2);
});

test('SIRA: en yeni önce; KİŞİ SINIRI en eskileri keser', () => {
  assert.equal(YENI_YAPIM_KISI_SINIRI, 5);
  const cast = [];
  for (let i = 0; i < 8; i++) {
    cast.push(kredi({ id: 100 + i, release_date: gunEkle(BUGUN, -i) }));
  }
  const y = yeniYapimlar(kisi(cast), BUGUN);
  assert.equal(y.length, 5, 'kişi başına en fazla 5 yapım değerlendirilmeli');
  assert.deepEqual(y.map((k) => k.tmdb_id), [100, 101, 102, 103, 104]);
  assert.equal(y[0].tarih, BUGUN);
});

// ===========================================================================
// 4) GÖREV: maliyet freni + hacim freni + zamanlama
// ===========================================================================
test('maliyet: KİŞİ başına tek TMDB çağrısı (kullanıcı başına DEĞİL)', () => {
  const g = fnGovdesi('yeniYapimlariBildir');
  assert.match(g, /GROUP BY f\.tmdb_id/,
    'kişiye göre gruplanmıyor → aynı oyuncuyu favorileyen her kullanıcı için ayrı çağrı');
  assert.match(g, /array_agg\(f\.kullanici_id/);
  // Toplu getirici öbek başına BİR kez; tekil çağrı hiç olmamalı.
  assert.equal((g.match(/tmdbTopluGetir\(/g) || []).length, 1);
  assert.ok(!/tmdbGetir\(/.test(g), 'döngü içinde tekil TMDB çağrısı var');
  // Kişinin ADI için İKİNCİ çağrı YOK: append_to_response ile aynı yanıtta.
  assert.match(g, /append_to_response=combined_credits/);
  assert.equal((g.match(/`\/person\//g) || []).length, 1,
    'kişi başına birden çok TMDB yolu kuruluyor');
  // Bayat kredilerle yeni yapım kaçmasın: TTL "uzun" DEĞİL.
  assert.match(g, /ONBELLEK_TTL_SN\.varsayilan/);
  assert.ok(!/ONBELLEK_TTL_SN\.uzun/.test(g));
});

test('maliyet: kitaplık kontrolü TEK sorgu (kullanıcı başına sorgu YOK)', () => {
  const g = fnGovdesi('yeniYapimlariBildir');
  // Kullanıcı döngüsünün içinde ham sorgu olmamalı; tek yazıcı
  // `kisiBildirimiEkle` (o da yalnız gerçekten bildirilecek kullanıcı için).
  const dongu = /for \(const a of adaylar\) \{[\s\S]*?\n {10}\}/.exec(g);
  assert.ok(dongu, 'kullanıcı döngüsü bulunamadı');
  assert.ok(!/havuz\.query/.test(dongu[0]), 'kullanıcı döngüsünde ham sorgu var (N+1)');
  const k = fnGovdesi('kitaplikKumeleri');
  assert.equal((k.match(/havuz\.query\(/g) || []).length, 1, 'kitaplık kontrolü tek sorgu değil');
  assert.match(k, /unnest\(\$2::text\[\], \$3::int\[\]\)/);
  assert.match(k, /kullanici_id = ANY\(\$1::int\[\]\)/);
});

test('kitaplık: durumlar + izlemeler + gizli_icerikler (üçü de)', () => {
  const k = fnGovdesi('kitaplikKumeleri');
  assert.match(k, /FROM durumlar d/);
  assert.match(k, /FROM izlemeler i/);
  assert.match(k, /FROM gizli_icerikler g/);
  // 'izleyecegim' DAHİL: durum süzgeci OLMAMALI (kullanıcı zaten haberdar).
  assert.ok(!/durum\s*(=|IN)/.test(k),
    "kitaplık sorgusu durumu süzüyor — 'izleyecegim' de kitaplıktır");
});

test('hacim freni: kullanıcı başına turda en fazla 3 bildirim', () => {
  assert.equal(YENI_YAPIM_TUR_SINIRI, 3);
  const g = fnGovdesi('yeniYapimlariBildir');
  assert.match(g, /sayac\.get\(id\) \|\| 0\) < YENI_YAPIM_TUR_SINIRI/,
    'aday süzgeci hacim frenini uygulamıyor');
  assert.match(g, /sayac\.get\(a\.id\) \|\| 0\) >= YENI_YAPIM_TUR_SINIRI\) break;/,
    'aynı kişinin 5 yapımı tek turda freni aşabiliyor');
  // Sayaç YALNIZ gerçekten yazılan bildirimde artmalı (çakışan INSERT kotayı
  // yemesin) — artış `kisiBildirimiEkle` true dönüşünün İÇİNDE olmalı.
  assert.match(g, /if \(await kisiBildirimiEkle\([\s\S]{0,140}?sayac\.set\(a\.id/);
});

test('bellek freni: kişiler ÖBEK ÖBEK işlenir (combined_credits gövdeleri büyük)', () => {
  assert.equal(YENI_YAPIM_OBEK, 20);
  const g = fnGovdesi('yeniYapimlariBildir');
  assert.match(g, /i \+= YENI_YAPIM_OBEK/);
  // Öbekleme çağrı SAYISINI değiştirmemeli: yol yine kişi başına tek.
  assert.match(g, /obek\.map\(\(r\) => yol\(r\.kisi_id\)\)/);
});

test('aday sorgusu: person + genel tercih + kişi bazlı tercih + yasaklı değil', () => {
  const g = fnGovdesi('yeniYapimlariBildir');
  assert.match(g, /f\.tur='person'/, "yalnız 'person' favorileri taranmalı");
  assert.match(g, /k\.bildir_kisi/, 'genel tercih kapısı aday sorgusunda yok');
  assert.match(g, /f\.bildirim <> 'kapali'/, 'kişi bazlı tercih aday sorgusunda süzülmüyor');
  assert.match(g, /NOT k\.yasakli/, 'yasaklı kullanıcıya push gitmemeli');
  // Kip kullanıcı BAŞINA gelmeli (yoksa yazıcı için ikinci sorgu = N+1).
  assert.match(g, /array_agg\(f\.bildirim/);
});

test('zamanlama: 24 saatte bir, ISCI_GOREVLI kapısında, md.27 den SONRA', () => {
  const m = /if \(ISCI_GOREVLI\) \{\s*setInterval\(yeniYapimlariBildir, ([^)]*)\);[\s\S]*?setTimeout\(yeniYapimlariBildir, ([^)]*)\);/
    .exec(KAYNAK);
  assert.ok(m, 'yeniYapimlariBildir ISCI_GOREVLI kapısında kurulmamış');
  // eslint-disable-next-line no-eval
  assert.equal(eval(m[1]), 24 * 60 * 60 * 1000, 'aralık 24 saat olmalı');
  // eslint-disable-next-line no-eval
  const ilk = eval(m[2]);
  // Diğer üç görev 1/3/5 dk'da başlıyor; bu onlardan SONRA gelmeli.
  assert.ok(ilk > 5 * 60 * 1000 && ilk <= 15 * 60 * 1000,
    'ilk tur diğer görevlerden sonra, dakikalar içinde olmalı');
});

test('dayanıklılık: tek kişinin hatası turu düşürmez', () => {
  const g = fnGovdesi('yeniYapimlariBildir');
  assert.ok((g.match(/try \{/g) || []).length >= 2, 'kişi başına try/catch yok');
  assert.match(g, /catch \(e\) \{[\s\S]*?console\.error\(`yeni yapim \(person\//);
});

// ===========================================================================
// 5) YAZICI: kisiBildirimiEkle (tekrar önleme + iki tercih katmanı + push)
// ===========================================================================
test('yazıcı: ON CONFLICT kısmi indeksi hedefler ve DO NOTHING der', () => {
  const g = fnGovdesi('kisiBildirimiEkle');
  assert.match(
    g,
    /ON CONFLICT \(kullanici_id, icerik_tur, tmdb_id\) WHERE tur='kisi'\s*\n?\s*DO NOTHING/,
  );
  // *** AYNI YAPIM İÇİN İKİNCİ BİLDİRİM ASLA *** — anahtarda kisi_id yok.
  assert.ok(!/ON CONFLICT \([^)]*kisi_id/.test(g),
    'çakışma hedefinde kisi_id var — aynı filmdeki üç favori üç bildirim üretir');
});

test('yazıcı: PUSH yalnız satır GERÇEKTEN yazıldıysa gider', () => {
  const g = fnGovdesi('kisiBildirimiEkle');
  const i = g.indexOf('rowCount');
  const j = g.indexOf('pushBildirim');
  assert.ok(i > 0 && j > i, 'rowCount kapısı push tan ÖNCE olmalı');
  assert.match(g, /if \(!y\.rowCount\) return false;/);
});

test('yazıcı: GENEL tercih kapalıysa NE kayıt NE push', () => {
  const g = fnGovdesi('kisiBildirimiEkle');
  const t = g.indexOf('bildir_kisi');
  assert.ok(t > 0, 'genel tercih kontrolü yok');
  assert.ok(t < g.indexOf('INSERT INTO bildirimler'), 'tercih INSERT ten SONRA bakılıyor');
  assert.match(g, /if \(t\.rows\.length && t\.rows\[0\]\.ac === false\) return false;/);
});

test("yazıcı: kip 'kapali' → hiçbir şey (sorgu bile yapılmaz)", () => {
  const g = fnGovdesi('kisiBildirimiEkle');
  const k = g.indexOf("kip === 'kapali'");
  assert.ok(k > 0, 'kişi bazlı kapalı kipi kontrol edilmiyor');
  assert.ok(k < g.indexOf('havuz'), "'kapali' kipi boşuna DB ye vuruyor");
  assert.match(g, /if \(kip === 'kapali'\) return false;/);
});

test("yazıcı: kip 'uygulama' → SATIR YAZILIR ama PUSH GİTMEZ", () => {
  const g = fnGovdesi('kisiBildirimiEkle');
  // Push, 'acik' kipinin İÇİNDE olmalı; INSERT ise dışında.
  assert.match(g, /if \(kip === 'acik'\) \{\s*\n\s*pushBildirim\(aliciId, 'kisi', null, \{/);
  assert.ok(g.indexOf('INSERT INTO bildirimler') < g.indexOf("kip === 'acik'"),
    "INSERT 'acik' kipinin içine kaymış — 'yalnız uygulama içi' satır yazmaz");
});

test('yazıcı: aktörsüz — pushBildirim e aktorId olarak null verilir', () => {
  assert.match(fnGovdesi('kisiBildirimiEkle'), /pushBildirim\(aliciId, 'kisi', null, \{/);
});

test('yazıcı: bildirimEkle KULLANILMIYOR (aktör varsayar + koşulsuz push atar)', () => {
  const g = fnGovdesi('kisiBildirimiEkle');
  assert.ok(!/\bbildirimEkle\(/.test(g), 'bildirimEkle aktör varsayar, burada kullanılamaz');
});

test('yazıcı: girdi doğrulaması (kisi_id / yapım id / yapım türü)', () => {
  const g = fnGovdesi('kisiBildirimiEkle');
  assert.match(g, /!gecerliTmdb\(kisiId\) \|\| !gecerliTmdb\(yapim\?\.tmdb_id\)/);
  assert.match(g, /yapim\.tur !== 'tv' && yapim\.tur !== 'movie'/);
});

test('gerileme: md. 27 yazıcısı (bolumBildirimiEkle) DEĞİŞMEDİ', () => {
  const g = fnGovdesi('bolumBildirimiEkle');
  assert.match(
    g,
    /ON CONFLICT \(kullanici_id, tmdb_id, sezon, bolum\) WHERE tur='bolum'\s*\n?\s*DO NOTHING/,
  );
  assert.match(g, /pushBildirim\(aliciId, 'bolum', null, \{/);
});

// ===========================================================================
// 6) TERCİH UÇLARI (iki katman)
// ===========================================================================
test('tercih: BILDIRIM_TERCIH_KOLON da kisi -> bildir_kisi', () => {
  assert.equal(BILDIRIM_TERCIH_KOLON.kisi, 'bildir_kisi');
  // Diğer türler bozulmamış
  assert.equal(BILDIRIM_TERCIH_KOLON.bolum, 'bildir_bolum');
  assert.equal(BILDIRIM_TERCIH_KOLON.begeni, 'bildir_begeni');
  assert.equal(BILDIRIM_TERCIH_KOLON.kacirilan_arama, 'bildir_arama');
});

test('tercih: GET ve POST /bildirim-tercihleri bildir_kisi yi içerir', () => {
  assert.ok(BILDIRIM_TERCIH_ALANLARI.includes('bildir_kisi'));
  for (const a of ['bildir_begeni', 'bildir_yanit', 'bildir_takip',
    'bildir_mesaj', 'bildir_etiket', 'bildir_bolum']) {
    assert.ok(BILDIRIM_TERCIH_ALANLARI.includes(a), `${a} listeden düşmüş`);
  }
});

test('kişi bazlı uç: üç kip, kapalı sözlük', () => {
  assert.deepEqual(KISI_BILDIRIM_KIPLERI, ['acik', 'uygulama', 'kapali']);
  const p = ucGovdesi('/kisi/:id/bildirim', 'post');
  assert.match(p, /KISI_BILDIRIM_KIPLERI\.includes\(bildirim\)/,
    'kip doğrulanmıyor — serbest metin veritabanına gidebilir');
  assert.match(p, /gecerliTmdb\(kisiId\)/);
  assert.match(p, /res\.status\(400\)/);
});

test('kişi bazlı uç: SATIR YARATMAZ, favori yoksa 400', () => {
  const p = ucGovdesi('/kisi/:id/bildirim', 'post');
  assert.match(p, /UPDATE favoriler SET bildirim=\$3/);
  assert.ok(!/INSERT INTO favoriler/.test(p),
    'tercih ucu favori yaratıyor — favorileme /favori/toggle in işi');
  assert.match(p, /if \(!rows\.length\) return res\.status\(400\)/);
  assert.match(p, /tur='person'/, 'dizi/film favorisinin kipi değiştirilebiliyor');
});

test('kişi bazlı uç: GET favori değilse null kip döner + hız limitli', () => {
  const g = ucGovdesi('/kisi/:id/bildirim', 'get');
  assert.match(g, /SELECT bildirim FROM favoriler/);
  assert.match(g, /favori: rows\.length > 0, bildirim: rows\[0\]\?\.bildirim \|\| null/);
  for (const y of ['get', 'post']) {
    assert.match(ucGovdesi('/kisi/:id/bildirim', y), /girisZorunlu, kisiLimiti/,
      `${y.toUpperCase()} ucunda giriş/hız limiti yok`);
  }
});

// ===========================================================================
// 7) GET /bildirimler — 'kisi' satırı + N+1 yok
// ===========================================================================
test('/bildirimler: kisi satırı kisi_id/icerik_tur/tmdb_id döndürür', () => {
  const g = ucGovdesi('/bildirimler', 'get');
  assert.match(g, /b\.kisi_id, b\.icerik_tur/);
  assert.match(g, /b\.tmdb_id, b\.sezon, b\.bolum/); // md. 27 gerilemesi
});

test('/bildirimler: yapim_adi + poster + kisi_adi ZENGİNLEŞTİRMESİ', () => {
  const g = ucGovdesi('/bildirimler', 'get');
  assert.match(g, /r\.tur === 'kisi' && r\.tmdb_id && r\.icerik_tur/);
  assert.match(g, /r\.yapim_adi = y\?\.name \|\| y\?\.title \|\| null;/,
    'dizide name, filmde title — ikisi de okunmalı');
  assert.match(g, /r\.kisi_adi = p\?\.name \|\| null;/);
  assert.match(g, /r\.poster = y\?\.poster_path \|\| null;/);
});

test('/bildirimler: N+1 YOK — sayfadaki HER ŞEY için TEK toplu çağrı', () => {
  const g = ucGovdesi('/bildirimler', 'get');
  assert.equal((g.match(/tmdbTopluGetir\(/g) || []).length, 1,
    'ikinci toplu çağrı = sayfa başına iki TMDB turu');
  assert.ok(!/tmdbGetir\(|diziDetay\(/.test(g), 'tekil TMDB çağrısı = N+1');
  // Zenginleştirme döngülerinde await OLMAMALI (await varsa seri N istek).
  for (const ad of ['bolumler', 'kisiler']) {
    const dongu = new RegExp(`for \\(const r of ${ad}\\) \\{[\\s\\S]*?\\n {4}\\}`).exec(g);
    assert.ok(dongu, `${ad} zenginleştirme döngüsü yok`);
    assert.ok(!/await/.test(dongu[0]), `${ad} döngüsünde await var`);
  }
});

test('/bildirimler: kişi adı `/favori-kisiler` ile AYNI önbellek anahtarını kullanır', () => {
  // `/person/{id}` (dilsiz yol) — `tmdbGetir` dili kendi ekler. Farklı bir yol
  // yazmak aynı veriyi ikinci kez önbelleğe almak demekti.
  assert.match(ucGovdesi('/bildirimler', 'get'), /kisiYolu = \(id\) => `\/person\/\$\{id\}`/);
  assert.match(ucGovdesi('/favori-kisiler', 'get'), /`\/person\/\$\{r\.tmdb_id\}`/);
});

test('/bildirimler: TMDB tökezlerse kutu yine de açılır', () => {
  assert.match(ucGovdesi('/bildirimler', 'get'), /\.catch\(\(\) => new Map\(\)\)/);
});

// ===========================================================================
// 8) PUSH — 16 dil + data yükü
// ===========================================================================
test('push: 16 dilin HEPSİNDE kisi şablonu var ve {kisi}/{yapim} taşıyor', () => {
  const diller = Object.keys(PUSH_SABLON);
  assert.equal(diller.length, 16, 'dil sayısı değişmiş');
  for (const d of diller) {
    const s = PUSH_SABLON[d].kisi;
    assert.ok(s, `${d} dilinde kisi şablonu yok`);
    assert.ok(s.includes('{kisi}'), `${d}: {kisi} yer tutucusu yok`);
    assert.ok(s.includes('{yapim}'), `${d}: {yapim} yer tutucusu yok`);
    assert.ok(!s.includes('{ad}'), `${d}: kisi türünün aktörü yok, {ad} olamaz`);
    assert.ok(!s.includes('@'), `${d}: TMDB adı kullanıcı adı değildir, '@' konmaz`);
  }
  assert.equal(PUSH_SABLON.tr.kisi, '{kisi} yeni bir yapımda: {yapim}');
  assert.equal(PUSH_SABLON.en.kisi, 'New from {kisi}: {yapim}');
});

test('push: md. 27 nin bolum şablonları BOZULMADI (gerileme)', () => {
  for (const [d, s] of Object.entries(PUSH_SABLON)) {
    assert.ok(s.bolum?.includes('{dizi}'), `${d}.bolum bozuldu`);
    assert.ok(s.bolum?.includes('{sb}'), `${d}.bolum bozuldu`);
  }
  assert.equal(PUSH_SABLON.tr.bolum, '{dizi} {sb} yayınlandı');
});

test('push: kisi gövdesi {kisi}/{yapim} ile kurulur, {ad} ile DEĞİL', () => {
  const g = fnGovdesi('pushBildirim');
  assert.match(g, /tur === 'kisi'\s*\n?\s*\? \(ekstra\?\.kisi_adi && ekstra\?\.yapim_adi/);
  assert.match(g, /\.replace\('\{kisi\}'/);
  assert.match(g, /\.replace\('\{yapim\}'/);
});

test('push: adlardan biri eksikse YARIM CÜMLE basılmaz (push hiç gitmez)', () => {
  const g = fnGovdesi('pushBildirim');
  // Boş gövde `if (!govde) return;` kapısına takılır.
  assert.match(g, /: ''\)/);
  assert.match(g, /if \(!govde\) return;/);
});

test('push: data yükü icerik_tur/tmdb_id/kisi_id ve HEPSİ STRING', () => {
  const g = fnGovdesi('pushBildirim');
  assert.match(g, /veri\.icerik_tur = String\(ekstra\?\.icerik_tur \?\? ''\);/);
  assert.match(g, /veri\.kisi_id = String\(ekstra\?\.kisi_id \?\? ''\);/);
  assert.match(g, /if \(tur === 'kisi'\) \{[\s\S]{0,200}?veri\.tmdb_id = String/);
});

test('push: kisi türü SIRADAN bildirim paketiyle gider (arama/mesaj dalı değil)', () => {
  const g = fnGovdesi('pushBildirim');
  assert.ok(!/tur === 'kisi'[\s\S]{0,120}priority: 'high', ttl/.test(g));
  assert.match(g, /channelId: 'dizijpg_bildirim'/);
});

// ===========================================================================
// 9) UÇTAN UCA (saf) — karar zinciri baştan sona
// ===========================================================================
test('uçtan uca: bir kişinin dört kredisi, tek doğru sonuç', () => {
  const c = [
    kredi({ id: 11, release_date: DUN }), // YENİ film → aday
    kredi({ id: 12, release_date: gunEkle(BUGUN, -60) }), // eski → hayır
    kredi({ id: 13, release_date: gunEkle(BUGUN, 30) }), // gelecek → hayır
    diziKredisi({ id: 14, first_air_date: gunEkle(BUGUN, -3) }), // YENİ dizi → aday
  ];
  const y = yeniYapimlar(kisi(c, [kredi({ id: 15, job: 'Writer' })]), BUGUN);
  // Sıra EN YENİ ÖNCE: film dün, dizi 3 gün önce.
  assert.deepEqual(y.map((k) => `${k.tur}:${k.tmdb_id}`), ['movie:11', 'tv:14']);
});

// ===========================================================================
// 10) ENGELLEME BOŞLUĞU — etiket bildirimi (md. 19 eki, 13 Ağu 2026)
// ===========================================================================
// Engellenen kullanıcı `@etiket` ile hâlâ bildirim gönderebiliyordu: engel
// okuma uçlarında ve yazma kapılarında zorlanmıştı ama BİLDİRİM yolu açıktı.
test('engelleme: etiketlenen kişi engelliyse bildirim YAZILMAZ (ne kayıt ne push)', () => {
  const g = fnGovdesi('etiketBildirimleriGonder');
  // Süzgeç ADAY SORGUSUNDA olmalı: engellenen kişi DB'den hiç dönmesin, o
  // yüzden `bildirimEkle` (kayıt + push) hiç çağrılmasın.
  assert.match(g, /AND \$\{engelSuzgec\('id', '\$2'\)\}/,
    'aday sorgusu engel süzgeci taşımıyor — engellenen kişiye etiket bildirimi gider');
  assert.match(g, /\[\[\.\.\.bulunan\], aktorId\]/,
    'süzgecin $2 yer tutucusuna aktör id si bağlanmamış');
  // Süzgeç bildirim yazımından ÖNCE gelmeli.
  assert.ok(g.indexOf('engelSuzgec') < g.indexOf('bildirimEkle'),
    'engel kontrolü bildirim yazıldıktan sonra yapılıyor');
});

test('engelleme: N+1 YOK — kaç kişi etiketlenirse etiketlensin TEK sorgu', () => {
  const g = fnGovdesi('etiketBildirimleriGonder');
  assert.equal((g.match(/havuz\.query\(/g) || []).length, 1,
    'etiket çözümlemesi birden çok sorgu yapıyor');
  // `engelliMi()` çift BAŞINA bir sorgudur; burada kullanılırsa N+1 olur.
  assert.ok(!/engelliMi\(/.test(g),
    'engelliMi() çift başına sorgudur — toplu etiketlemede N+1 yaratır');
  // Üçüncü bir kopya SQL yazılmamalı; ortak parça kullanılmalı.
  assert.ok(!/FROM engellemeler/.test(g),
    'engel SQL i elle kopyalanmış — ortak `engelSuzgec()` kullanılmalı');
});

test('engelleme: süzgeç ÇİFT YÖNLÜ (kim kimi engellemiş olursa olsun)', () => {
  const s = fnGovdesi('engelSuzgec');
  assert.match(s, /SELECT engellenen_id FROM engellemeler WHERE engelleyen_id=/);
  assert.match(s, /UNION SELECT engelleyen_id FROM engellemeler WHERE engellenen_id=/);
});

test('engelleme GERİLEME: engel yokken etiket bildirimi eskisi gibi gider', () => {
  const g = fnGovdesi('etiketBildirimleriGonder');
  // Eski davranış aynen duruyor: misafir hariç, kendine ve haricId ye bildirim yok.
  assert.match(g, /misafir = false/);
  assert.match(g, /if \(r\.id === aktorId \|\| r\.id === haricId\) continue;/);
  assert.match(g, /bildirimEkle\(r\.id, 'etiket', aktorId, yorumId\);/);
  // Süzgeç SATIRLARI ELEMEKTEN başka bir şey yapmıyor: hata durumunda yorum
  // akışı hâlâ bozulmuyor.
  assert.match(g, /catch \{/);
});

test('uçtan uca: kitaplıkta olan aday süzülür (görev döngüsünün kuralı)', () => {
  // Görev, `kitaplikKumeleri`nden dönen kümeyle adayı eler; kural burada
  // kaynaktan doğrulanır (DB'siz).
  const g = fnGovdesi('yeniYapimlariBildir');
  assert.match(g, /if \(sahip\?\.has\(`\$\{y\.tur\}:\$\{y\.tmdb_id\}`\)\) continue;/,
    'kitaplıkta olan yapım elenmiyor');
});
