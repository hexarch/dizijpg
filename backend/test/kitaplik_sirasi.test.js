// KİTAPLIK SIRASI — altı listede elle sıra (21 Ağu 2026)
//
// İSTEK: "Profilimdeki listeler de sürükle bırak ile düzenleme özelliği ekler
// misin? Mesela İzliyorum listesine girdiğimde basılı tutup sürükle bırak ile
// dizi film afişlerinin konumunu değiştirebilmeliyim."
//
// KORUNAN KARARLAR
//  1) TEK TABLO, ALTI LİSTE. `izlemeler` bir OLAY tablosu (anahtarı sezon+bölüm
//     içerir): 62 bölümlük dizi orada 62 satır, ekranda TEK afiş. Sıra oraya
//     sütun olarak konsaydı bir afişi taşımak 62 satır yazmak olur, okuma ucu
//     GROUP BY yaptığı için sıra min()/max()'a sokulurdu. `durumlar`a sütun
//     eklemek mümkündü ama o zaman TEK özellik iki mekanizmayla yürürdü.
//  2) MİGRASYON VERİ YAZMAZ. Satırı olmayan liste = hiç düzenlenmemiş liste;
//     `NULLS FIRST` ile BUGÜNKÜ sırasını birebir korur (578 öğelik "Bitirdim"
//     kullanıcı hiçbir şey yapmadan yeniden dizilmez).
//  3) SIRA TAM LİSTE OLARAK ve TEK SORGUDA yazılır. 19 Ağu 2026'da
//     `liste_ogeleri`nde CANLIDA ölçülen tuzak: 8 öğelik listeye 4 öğelik sıra
//     yazılınca kalan 4'ü NULL kalıyor, `NULLS FIRST` onları BAŞA taşıyor ve
//     kullanıcının sıraladıkları listenin SONUNA düşüyordu.
//  4) ÜYELİK DENETİMİ: doğru SAYIDA ama listeye ait OLMAYAN öğeler
//     gönderilebilirdi; tabloya öksüz satır yazılırdı.
//  5) `/izlediklerim` PENCERESİ: elle sıra ancak istemcinin TAMAMINI gördüğü
//     listede yazılabildiği için pencere 500'den 2000'e çıktı (ölçüm 21 Ağu
//     2026: en büyük gerçek liste 429 yapım). Pencere aşılırsa elle sıra
//     UYGULANMAZ — yoksa `NULLS FIRST` sıralanmışları sona iter ve LIMIT
//     onları keserdi (aynı tuzağın ikinci hâli).
//
// Neden kaynak okuma: `server.js` içe aktarıldığı anda `app.listen` çağırıyor
// (kisi_tepkisi.test.js / liste_duzenleme.test.js ile aynı gerekçe).
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const oku = (a) => fs.readFileSync(path.join(KOK, a), 'utf8');

const KAYNAK = oku('server.js');
const SEMA = oku('sema.sql');
const MIGRASYON = oku('migrasyon-2026-08-21c.sql');

/** Migrasyonun YORUM OLMAYAN satırları: gerekçe metni komut sanılmasın. */
const KOMUTLAR = MIGRASYON.split('\n')
  .filter((s) => !s.trim().startsWith('--')).join('\n');

/** Bir uç bloğunun gövdesini kaynaktan çeker. */
function ucGovdesi(yol, metot = 'post') {
  const im = `app.${metot}('${yol}'`;
  const bas = KAYNAK.indexOf(im);
  assert.ok(bas >= 0, `${metot.toUpperCase()} ${yol} bulunamadı`);
  const sonraki = KAYNAK.slice(bas + im.length).search(/\napp\.[a-z]+\('/);
  return sonraki < 0 ? KAYNAK.slice(bas) : KAYNAK.slice(bas, bas + im.length + sonraki);
}

const ALTI_LISTE = [
  'izliyorum', 'izleyecegim', 'bitirdim', 'biraktim',
  'izlenen_tv', 'izlenen_movie',
];

// ---------------------------------------------------------------------------
// MİGRASYON + ŞEMA
// ---------------------------------------------------------------------------
test('migrasyon tabloyu IF NOT EXISTS ile kurar (idempotent)', () => {
  assert.match(KOMUTLAR, /CREATE TABLE IF NOT EXISTS kitaplik_sirasi/);
  assert.match(KOMUTLAR, /BEGIN;/);
  assert.match(KOMUTLAR, /COMMIT;/);
});

test('migrasyon VERİ YAZMAZ: mevcut listelere sıra atanmıyor', () => {
  // Atansaydı 578 öğelik "Bitirdim" kullanıcı hiçbir şey yapmadan yeniden
  // dizilirdi. "Sırasız" hâl satırın YOKLUĞUDUR.
  assert.doesNotMatch(KOMUTLAR, /INSERT\s+INTO\s+kitaplik_sirasi/i);
  assert.doesNotMatch(KOMUTLAR, /UPDATE\s+(durumlar|izlemeler)/i);
});

test('migrasyon altı listeyi de beyaz listeye alır', () => {
  for (const l of ALTI_LISTE) {
    assert.match(KOMUTLAR, new RegExp(`'${l}'`), `${l} beyaz listede yok`);
  }
});

test('şema migrasyonla AYNI tabloyu taşır (kolon + kısıt + anahtar)', () => {
  const tablo = SEMA.slice(SEMA.indexOf('CREATE TABLE IF NOT EXISTS kitaplik_sirasi'))
    .split(');')[0];
  assert.match(tablo, /kullanici_id INT NOT NULL REFERENCES kullanicilar\(id\) ON DELETE CASCADE/);
  assert.match(tablo, /liste TEXT NOT NULL CHECK/);
  assert.match(tablo, /tur TEXT NOT NULL CHECK \(tur IN \('tv','movie'\)\)/);
  assert.match(tablo, /\bsira INT NOT NULL\b/, 'sira NOT NULL değil');
  assert.match(tablo, /PRIMARY KEY \(kullanici_id, liste, tur, tmdb_id\)/);
  for (const l of ALTI_LISTE) assert.match(tablo, new RegExp(`'${l}'`));
});

// ---------------------------------------------------------------------------
// OKUMA UÇLARI
// ---------------------------------------------------------------------------
test('GET /kitapligim elle sırayı NULLS FIRST ile uygular', () => {
  const govde = ucGovdesi('/kitapligim', 'get');
  assert.match(govde, /LEFT JOIN kitaplik_sirasi s/);
  // Her satır KENDİ listesinin sırasını almalı: eşleme `liste = durum`.
  assert.match(govde, /s\.liste = d\.durum/, 'sıra listeden bağımsız eşleşiyor');
  assert.match(
    govde,
    /ORDER BY s\.sira ASC NULLS FIRST, d\.guncelleme DESC/,
    'düzenlenmemiş liste eski sırasını kaybediyor',
  );
});

test('GET /kitapligim `sira` alanını istemciye DÖNER', () => {
  // İstemci "bu liste elle sıralanmış mı" bilgisini buradan okuyor
  // ("Sırayı sıfırla" düğmesi yalnız sıralı listede çıkıyor).
  assert.match(ucGovdesi('/kitapligim', 'get'), /d\.guncelleme, s\.sira/);
});

test('GET /izlediklerim?tur= elle sırayı uygular ve doğru listeye bakar', () => {
  const govde = ucGovdesi('/izlediklerim', 'get');
  assert.match(govde, /LEFT JOIN kitaplik_sirasi s/);
  assert.match(govde, /s\.liste=\$3/);
  assert.match(govde, /`izlenen_\$\{tur\}`/, 'liste anahtarı türden türetilmiyor');
  assert.match(govde, /ASC NULLS FIRST/);
});

test('pencere aşılırsa elle sıra UYGULANMAZ (LIMIT sıralananı kesmesin)', () => {
  const govde = ucGovdesi('/izlediklerim', 'get');
  assert.match(
    govde,
    /CASE WHEN toplam > \$4 THEN NULL ELSE sira END/,
    'pencere taşmasında sıra devre dışı bırakılmıyor — LIMIT sıralananı keser',
  );
  assert.match(govde, /count\(\*\) OVER \(\) AS toplam/);
  assert.match(govde, /LIMIT \$4/, 'pencere ile tavan aynı sabitten gelmiyor');
});

test('IZLENEN_PENCERE hem pencere hem yazma tavanı (tek sabit)', () => {
  assert.match(KAYNAK, /const IZLENEN_PENCERE = 2000;/);
  const put = ucGovdesi('/kitaplik/sira/:liste', 'put');
  assert.match(put, /ham\.length > IZLENEN_PENCERE/, 'yazma tavanı ayrı sabit');
});

test('TÜRSÜZ /izlediklerim sırayı UYGULAMAZ (kırpılmış önizleme)', () => {
  const govde = ucGovdesi('/izlediklerim', 'get');
  // Tür başına LIMIT 200'lük önizleme beslemesi; kırpılmış pencereye elle sıra
  // uygulamak ya sıralananı keser ya da tam listeden farklı dizerdi.
  const turSuz = govde.slice(govde.indexOf('UNION ALL') - 400);
  assert.doesNotMatch(turSuz, /kitaplik_sirasi/);
});

// ---------------------------------------------------------------------------
// YAZMA UCU
// ---------------------------------------------------------------------------
test('PUT giriş ZORUNLU + hız limiti + liste beyaz listesi', () => {
  const govde = ucGovdesi('/kitaplik/sira/:liste', 'put');
  assert.match(govde, /girisZorunlu/);
  assert.match(govde, /kitaplikSiraLimiti/, 'hız limiti yok');
  assert.match(
    govde,
    /!Object\.hasOwn\(KITAPLIK_LISTELERI, liste\)/,
    'liste adı doğrulanmıyor — istemci uydurma liste yazabilir',
  );
});

test('PUT sahiplik: satırlar YALNIZ req.kullanici.id ile yazılır', () => {
  const govde = ucGovdesi('/kitaplik/sira/:liste', 'put');
  // Kullanıcı kimliği YOLDAN/GÖVDEDEN gelmiyor; token'dan geliyor. Bu uçta
  // "başkasının listesi" diye bir şey olamaz.
  assert.match(govde, /const p = \[req\.kullanici\.id, liste, tanim\.suzgec\]/);
  assert.doesNotMatch(govde, /req\.body\?\.kullanici_id|params\.kullanici/);
});

test('PUT: boş / aşırı uzun / geçersiz / TEKRARLI gövde 400', () => {
  const govde = ucGovdesi('/kitaplik/sira/:liste', 'put');
  assert.match(govde, /Array\.isArray\(ham\)/);
  assert.match(govde, /ham\.length > IZLENEN_PENCERE/);
  assert.match(govde, /ham\.every\(listeOgesiGecerli\)/);
  assert.match(
    govde,
    /anahtarlar\.size !== ham\.length/,
    'aynı yapım iki kez gönderilebiliyor — ON CONFLICT ifadeyi patlatır',
  );
});

test('PUT: izlenen_tv/izlenen_movie listesine yanlış TÜR giremez', () => {
  const govde = ucGovdesi('/kitaplik/sira/:liste', 'put');
  assert.match(govde, /tanim\.kaynak === 'izleme' && !ham\.every\(\(o\) => o\.tur === tanim\.suzgec\)/);
});

test('PUT EKSİK liste kabul ETMEZ (kısmi yazım sırayı bozar)', () => {
  const govde = ucGovdesi('/kitaplik/sira/:liste', 'put');
  assert.match(govde, /count\(\*\)::int FROM durumlar WHERE kullanici_id=\$1 AND durum=\$3/);
  assert.match(govde, /count\(DISTINCT tmdb_id\)::int FROM izlemeler/);
  // DENETİMİN VARLIĞI YETMEZ, ETKİN OLMALI: koşulu `if (false && ...)` ile
  // devre dışı bırakmak sadece "ham.length !== adet" arayan bir iddiadan
  // KAÇIYORDU (mutasyon denemesi, 21 Ağu 2026). Bu yüzden koşul ve hemen
  // ardından gelen 400 dönüşü BİRLİKTE aranıyor.
  assert.match(
    govde,
    /\n {2}if \(ham\.length !== adet\) \{\n {4}return res\.status\(400\)/,
    'kısmi sıralama reddedilmiyor — 19 Ağu tuzağı geri geldi',
  );
  assert.match(govde, /beklenen: adet/);
});

test('PUT: listede OLMAYAN yapım 400 (üyelik denetimi)', () => {
  const govde = ucGovdesi('/kitaplik/sira/:liste', 'put');
  assert.match(govde, /AS eslesme/);
  assert.match(
    govde,
    /\n {2}if \(eslesme !== ham\.length\) \{\n {4}return res\.status\(400\)/,
    'yalnız SAYI denetleniyor; yanlış yapımlar öksüz satır yazardı',
  );
});

test('PUT TEK sorguda yazar: silme + yazma aynı ifadede, döngüde sorgu YOK', () => {
  const govde = ucGovdesi('/kitaplik/sira/:liste', 'put');
  assert.match(govde, /WITH yeni AS \(SELECT \* FROM \$\{degerler\}\)/);
  assert.match(govde, /sil AS \(\s*\n\s*DELETE FROM kitaplik_sirasi/);
  assert.match(govde, /INSERT INTO kitaplik_sirasi/);
  assert.match(govde, /ON CONFLICT \(kullanici_id, liste, tur, tmdb_id\)/);
  assert.match(govde, /DO UPDATE SET sira = EXCLUDED\.sira/);
  // Döngü içinde sorgu ATILMAMALI (yarım uygulanmış sıra riski).
  assert.doesNotMatch(govde.replace(/`[^`]*`/gs, ''), /for\s*\(.*havuz\.query/s);
});

test('PUT gönderilmeyen satırları TEMİZLER (öksüz sıra kalmasın)', () => {
  const govde = ucGovdesi('/kitaplik/sira/:liste', 'put');
  assert.match(
    govde,
    /AND \(tur, tmdb_id\) NOT IN \(SELECT tur, tmdb_id FROM yeni\)/,
    'listeden düşen yapımın sıra satırı sonsuza dek kalır',
  );
});

// ---------------------------------------------------------------------------
// SIFIRLAMA UCU
// ---------------------------------------------------------------------------
test('DELETE yalnız kendi satırlarını ve BİLİNEN listeyi siler', () => {
  const govde = ucGovdesi('/kitaplik/sira/:liste', 'delete');
  assert.match(govde, /girisZorunlu/);
  assert.match(govde, /!Object\.hasOwn\(KITAPLIK_LISTELERI, liste\)/);
  assert.match(
    govde,
    /DELETE FROM kitaplik_sirasi WHERE kullanici_id=\$1 AND liste=\$2/,
    'silme kullanıcıya kapatılmamış',
  );
});

// ---------------------------------------------------------------------------
// SAF VERİ — kaynaktan çekilip GERÇEKTEN çalıştırılıyor
// ---------------------------------------------------------------------------
test('KITAPLIK_LISTELERI: altı liste, doğru kaynak ve süzgeç', () => {
  const m = /const KITAPLIK_LISTELERI = \{[\s\S]*?\n\};/.exec(KAYNAK);
  assert.ok(m, 'KITAPLIK_LISTELERI bulunamadı');
  const tablo = new Function(`${m[0]}\nreturn KITAPLIK_LISTELERI;`)();

  assert.deepEqual(Object.keys(tablo).sort(), [...ALTI_LISTE].sort());
  // Durum listelerinde süzgeç DURUMUN KENDİSİ; izleme listelerinde TÜR.
  for (const l of ['izliyorum', 'izleyecegim', 'bitirdim', 'biraktim']) {
    assert.equal(tablo[l].kaynak, 'durum');
    assert.equal(tablo[l].suzgec, l);
  }
  assert.deepEqual(tablo.izlenen_tv, { kaynak: 'izleme', suzgec: 'tv' });
  assert.deepEqual(tablo.izlenen_movie, { kaynak: 'izleme', suzgec: 'movie' });
  // Uydurma liste adı tabloda YOK → uç 400 döner.
  assert.equal(Object.hasOwn(tablo, 'favoriler'), false);
  assert.equal(Object.hasOwn(tablo, '__proto__'), false);
});
