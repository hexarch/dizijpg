// ANONİMLİK / GİZLİLİK SEÇENEKLERİ (istek md. 21) — `node --test test/*.test.js`
//
// "Kullanıcıya daha fazla saklanma alanı: yorumlarımı profilimde gizle,
//  takipçilerimi gizle, takip ettiklerimi gizle, izlediklerimi gizle vb."
//
// Bu dosyanın koruduğu ÜÇ KURAL:
//
//  1) ZORLAMA SUNUCUDA. Anahtar kapalıyken veri UÇTAN HİÇ ÇIKMAZ — istemcide
//     gizlemek yetmez, değiştirilmiş bir istemci ham JSON'u okur.
//  2) KENDİ VERİNİ HER ZAMAN GÖRÜRSÜN. Tercih yalnız BAŞKALARINA karşıdır;
//     sahibi kendi profilinde/listesinde gizlediği şeyi görmeye devam eder,
//     yoksa tercihini geri almadan neyi sakladığını bilemez.
//  3) ENGELLEME İLE KARIŞMAZ. Engelleme KİŞİYE ÖZEL, gizlilik HERKESE KARŞI.
//     İkisi aynı sorguda AND ile birleşir; biri ötekini GEVŞETMEZ.
//
// YÖNTEM: `server.js` içe aktarılamıyor (modül yüklenir yüklenmez
// `app.listen` çağırıyor — engelleme/seo_gizlilik testleriyle aynı gerekçe).
// Bu yüzden ilgili bildirimler KAYNAKTAN ÇEKİLİP GERÇEKTEN ÇALIŞTIRILIYOR:
// `takipListesi` sahte bir `havuz` ile çağrılır ve ÜRETTİĞİ SORGUNUN
// DÖNDÜRDÜĞÜ SATIRLAR sınanır — kopyası değil, canlıdaki kod.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const oku = (a) => fs.readFileSync(path.join(KOK, a), 'utf8');

const KAYNAK = oku('server.js');
const SEMA = oku('sema.sql');
const MIGRASYON = oku('migrasyon-2026-08-14.sql');
const AYARLAR = fs.readFileSync(
  path.join(path.dirname(KOK), 'app', 'lib', 'ekranlar', 'ayarlar.dart'), 'utf8');

// Migrasyonun YORUM OLMAYAN satırları: gerekçe metni komut sanılmasın
// (geri alma bölümü bilerek DROP COLUMN örneği içerir).
const MIGRASYON_KOMUTLARI = MIGRASYON.split('\n')
  .filter((s) => !s.trim().startsWith('--')).join('\n');

// ---------------------------------------------------------------------------
// Kaynaktan kod çekme (engelleme.test.js'teki kalıp, `async function` de dahil)
// ---------------------------------------------------------------------------

/** `bas` indeksindeki ilk `{`/`(`/`[` çiftini dengeleyerek bloğu döndürür. */
function blokAl(kaynak, bas, ac, kapa) {
  let derinlik = 0;
  let girdi = false;
  for (let i = bas; i < kaynak.length; i++) {
    const c = kaynak[i];
    if (c === ac) { derinlik++; girdi = true; } else if (c === kapa) {
      derinlik--;
      if (girdi && derinlik === 0) return kaynak.slice(bas, i + 1);
    }
  }
  throw new Error('blok kapanmadı');
}

/** `function` / `async function` / `const` bildiriminin TAM metni. */
function bildirimCek(ad) {
  const m = new RegExp(`^(async function|function|const) ${ad}\\b`, 'm').exec(KAYNAK);
  assert.ok(m, `server.js içinde ${ad} bildirimi bulunamadı`);
  if (m[1] === 'const') {
    // `const X = ...;` — ilk üst düzey `;`ye kadar.
    let derinlik = 0;
    for (let i = m.index; i < KAYNAK.length; i++) {
      const c = KAYNAK[i];
      if ('{(['.includes(c)) derinlik++;
      else if ('})]'.includes(c)) derinlik--;
      else if (c === ';' && derinlik === 0) return KAYNAK.slice(m.index, i + 1);
    }
    assert.fail(`${ad} bildiriminin sonu bulunamadı`);
  }
  return blokAl(KAYNAK, m.index, '{', '}');
}

/** İstenen bildirimleri derleyip son ifadeyi döndüren sanal alan. */
function alan(adlar, ifade, disaridan = '') {
  const govde = adlar.map(bildirimCek).join('\n');
  // eslint-disable-next-line no-new-func
  return new Function(`${disaridan}\n${govde}\nreturn (${ifade});`)();
}

/** `app.<metot>('<yol>'` ile başlayan uç kaydının TAM gövdesi. */
function ucGovdesi(metot, yol) {
  const ara = `app.${metot}('${yol}'`;
  const bas = KAYNAK.indexOf(ara);
  assert.ok(bas >= 0, `uç bulunamadı: ${metot.toUpperCase()} ${yol}`);
  return blokAl(KAYNAK, bas + ara.length - 1, '(', ')');
}

const engelSuzgec = alan(['engelSuzgec'], 'engelSuzgec');
const kendiSatirSuzgec = alan(['kendiSatirSuzgec'], 'kendiSatirSuzgec');
const GIZLILIK_ALANLARI = alan(['GIZLILIK_ALANLARI'], 'GIZLILIK_ALANLARI');
const TERCIH_ALANLARI = alan(
  ['GIZLILIK_ALANLARI', 'ARAMA_TERCIH_ALANLARI', 'TERCIH_ALANLARI'], 'TERCIH_ALANLARI');
const IZLEME_ROZETLERI = alan(['IZLEME_ROZETLERI'], 'IZLEME_ROZETLERI');

// ===========================================================================
// 1. TERCİH ALANLARI — dört eski + iki yeni, hepsi aynı sözleşmede
// ===========================================================================

// md. 21'in dört isteği ve karşılıkları. "yorumlarımı profilimde gizle" ve
// "izlediklerimi gizle" ZATEN VARDI (26 Tem); yeni açılan yalnız takip
// grafiğinin iki ucu. Yeni sütun açmak eskileri ÇAKIŞTIRIRDI.
const MADDE_21 = {
  'izlediklerimi gizle': 'izlenenler_gizli',
  'yorumlarımı profilimde gizle': 'yorumlar_gizli',
  'takipçi listemi gizle': 'takipciler_gizli',
  'takip ettiklerimi gizle': 'takip_edilenler_gizli',
};

test('md. 21: istenen dört anahtarın DÖRDÜ de tercih listesinde', () => {
  for (const [istek, alan_] of Object.entries(MADDE_21)) {
    assert.ok(GIZLILIK_ALANLARI.includes(alan_),
      `"${istek}" karşılıksız: GIZLILIK_ALANLARI içinde ${alan_} yok`);
  }
});

test('gizlilik alanlarının POLARİTESİ tek yönlü: hepsi `_gizli` ile biter', () => {
  // Arama tercihleri (`_acik`) BİLEREK ayrı listede. Aynı listeye karışsalardı
  // tek `for` ile çizilen anahtarların yarısı ters anlama gelirdi.
  for (const a of GIZLILIK_ALANLARI) {
    assert.ok(a.endsWith('_gizli'), `${a}: gizlilik listesinde negatif olmayan alan`);
  }
  assert.equal(GIZLILIK_ALANLARI.length, 6);
});

test('yeni iki alan `/gizlilik-tercihleri` uçlarından OKUNUR ve YAZILIR', () => {
  // Uç, SELECT/RETURNING'i TERCIH_ALANLARI'ndan üretiyor: liste yeterli kanıt.
  for (const a of ['takipciler_gizli', 'takip_edilenler_gizli']) {
    assert.ok(TERCIH_ALANLARI.includes(a), `${a} TERCIH_ALANLARI'nda yok`);
  }
  const get = ucGovdesi('get', '/gizlilik-tercihleri');
  const post = ucGovdesi('post', '/gizlilik-tercihleri');
  assert.match(get, /TERCIH_ALANLARI\.join/);
  assert.match(post, /TERCIH_ALANLARI\.join/);
  // Yazma yalnız BİLİNEN anahtarları kabul eder (beyaz liste + boolean zorlama):
  // gövdeye rastgele bir sütun adı yollayıp UPDATE'e sızdırmak mümkün olmasın.
  assert.match(post, /for \(const a of izinli\)/);
  assert.match(post, /typeof g\[a\] === 'boolean'/);
});

test('MİSAFİR de gizlilik anahtarlarını açabilir (yalnız arama tercihleri kilitli)', () => {
  const yazilabilir = alan(
    ['GIZLILIK_ALANLARI', 'ARAMA_TERCIH_ALANLARI', 'TERCIH_ALANLARI', 'yazilabilirTercihler'],
    'yazilabilirTercihler');
  // Misafirin de gizlilik hakkı var: kısıt YALNIZ `_acik` alanlarına.
  for (const a of ['takipciler_gizli', 'takip_edilenler_gizli']) {
    assert.ok(yazilabilir(true).includes(a), `misafir ${a} yazamıyor`);
    assert.ok(yazilabilir(false).includes(a));
  }
  assert.ok(!yazilabilir(true).includes('sesli_arama_acik'));
});

// ===========================================================================
// 2. ŞEMA + MİGRASYON — sütunlar var, varsayılan false
// ===========================================================================

for (const sutun of ['takipciler_gizli', 'takip_edilenler_gizli']) {
  test(`şema: kullanicilar.${sutun} NOT NULL DEFAULT false`, () => {
    const kalip = new RegExp(
      `ADD COLUMN IF NOT EXISTS ${sutun} BOOLEAN NOT NULL DEFAULT false`);
    assert.match(SEMA, kalip, `sema.sql'de ${sutun} yok`);
    assert.match(MIGRASYON_KOMUTLARI, kalip, `migrasyon-2026-08-14.sql'de ${sutun} yok`);
  });
}

test('migrasyon idempotent ve YIKICI DEĞİL (veri satırına dokunmaz)', () => {
  assert.match(MIGRASYON_KOMUTLARI, /ADD COLUMN IF NOT EXISTS/);
  // Komut bölümünde DROP/DELETE/UPDATE/TRUNCATE OLMAMALI. Geri alma örneği
  // yorum satırındadır, MIGRASYON_KOMUTLARI onu zaten eliyor.
  assert.doesNotMatch(MIGRASYON_KOMUTLARI, /\b(DROP|DELETE|UPDATE|TRUNCATE)\b/i);
});

test('VARSAYILAN false: yükseltme kimsenin listesini SESSİZCE kapatmaz', () => {
  // Varsayılan true olsaydı, ayarları hiç açmamış her kullanıcının takipçi
  // listesi bir sürüm yükseltmesiyle kapanırdı — sunucunun kullanıcı adına
  // aldığı bir karar olurdu.
  for (const sutun of ['takipciler_gizli', 'takip_edilenler_gizli']) {
    assert.doesNotMatch(
      MIGRASYON_KOMUTLARI,
      new RegExp(`${sutun}[^;]*DEFAULT true`, 'i'));
  }
});

// ===========================================================================
// 3. SÜZGECİN KENDİSİ — `kendiSatirSuzgec`
// ===========================================================================

test('kendiSatirSuzgec: yalnız isteyenin kendi id\'sini bırakır', () => {
  assert.equal(kendiSatirSuzgec('ku.id', '$2'), 'ku.id = $2::int');
});

test('kendiSatirSuzgec `::int` döküm taşır: oturumsuzda ($2=0) hiçbir satır tutmaz', () => {
  // Döküm olmasaydı pg "could not determine data type of parameter" derdi;
  // 0 ile eşleşen kullanıcı da yok (id BIGSERIAL, 1'den başlar).
  assert.match(kendiSatirSuzgec('ku.id', '$2'), /::int/);
});

// ===========================================================================
// 4. DAVRANIŞ — `takipListesi` SAHTE HAVUZ ile GERÇEKTEN çalıştırılıyor
// ===========================================================================
//
// Sahte havuz, üretilen SQL'in İKİ SÜZGEÇ PARÇASINI da yorumlar:
//   · engelSuzgec  -> engelli çiftin satırı düşer   (KİŞİYE ÖZEL)
//   · kendiSatirSuzgec -> yalnız isteyenin satırı kalır (HERKESE KARŞI)
// Böylece "açıkken görünür / kapalıyken gelmiyor" iddiaları SATIR SEVİYESİNDE
// sınanıyor, sorgu metnine bakılarak değil.

const KULLANICILAR = {
  ayse: { id: 10, takipciler_gizli: true, takip_edilenler_gizli: false },
  can: { id: 20, takipciler_gizli: false, takip_edilenler_gizli: true },
  deniz: { id: 30, takipciler_gizli: false, takip_edilenler_gizli: false },
};
// (takip_eden_id, takip_edilen_id)
const TAKIPLER = [[20, 10], [30, 10], [40, 10], [10, 20], [10, 30]];
const ADLAR = { 10: 'ayse', 20: 'can', 30: 'deniz', 40: 'engelli' };
// engelli(40) ile bakan(20) birbirini engellemiş.
const ENGELLER = [[20, 40]];

function sahteHavuz(kayit = {}) {
  return {
    async query(sql, deg) {
      if (sql.includes('FROM kullanicilar WHERE kullanici_adi=$1')) {
        const k = KULLANICILAR[deg[0]];
        if (!k) return { rows: [] };
        // Uç, gizli sütunu `AS gizli` diye seçiyor; hangi sütunu seçtiğini
        // sorgudan okuyoruz — yanlış sütuna bakılırsa test kırmızıya döner.
        const m = /SELECT id, (\w+) AS gizli/.exec(sql);
        assert.ok(m, 'takipListesi gizli sütunu `AS gizli` ile seçmeli');
        kayit.gizliSutun = m[1];
        return { rows: [{ id: k.id, gizli: k[m[1]] }] };
      }
      kayit.sql = sql;
      const [sahipId, benId] = deg;
      const eden = sql.includes('t.takip_edilen_id = $1');
      let satirlar = TAKIPLER
        .filter(([e, h]) => (eden ? h : e) === sahipId)
        .map(([e, h]) => (eden ? e : h));
      // 1) ENGELLEME — kişiye özel, çift yönlü, oturumsuzda kısa devre.
      assert.ok(sql.includes(engelSuzgec('ku.id', '$2')),
        'takipListesi engelleme süzgecini KAYBETMİŞ');
      if (benId !== 0) {
        const engelli = new Set(ENGELLER.flatMap(([a, b]) =>
          (a === benId ? [b] : b === benId ? [a] : [])));
        satirlar = satirlar.filter((id) => !engelli.has(id));
      }
      // 2) GİZLİLİK — herkese karşı; SQL'de varsa yalnız isteyenin satırı kalır.
      if (sql.includes(kendiSatirSuzgec('ku.id', '$2'))) {
        satirlar = satirlar.filter((id) => id === benId);
      }
      return { rows: satirlar.map((id) => ({ kullanici_adi: ADLAR[id], avatar: null, bio: null })) };
    },
  };
}

// `alan()` dışarıdan değişken alamadığı için sahte havuzu bir kez, modül
// düzeyinde kuruyoruz: son çalıştırılan sorgu `KAYIT`e yazılır ve testler onu
// da denetleyebilir (hangi sütuna bakıldı, süzgeç parçaları duruyor mu).
const KAYIT = {};
const takipListesi = (() => {
  const govde = ['engelSuzgec', 'kendiSatirSuzgec', 'TAKIP_GIZLILIK_ALANI', 'takipListesi']
    .map(bildirimCek).join('\n');
  // eslint-disable-next-line no-new-func
  return new Function('kayit', 'sahteHavuz', 'assert', `
    const havuz = sahteHavuz(kayit);
    ${govde}
    return takipListesi;`)(KAYIT, sahteHavuz, assert);
})();

const takipcilerinden = (ad, ben) =>
  takipListesi(ad, 'takip_edilen_id', 'takip_eden_id', ben, 'takipciler');
const takipEttikleri = (ad, ben) =>
  takipListesi(ad, 'takip_eden_id', 'takip_edilen_id', ben, 'takip_edilenler');

const adlari = (s) => s.kullanicilar.map((k) => k.kullanici_adi).sort();

test('AÇIKKEN GÖRÜNÜR: gizlemeyen kullanıcının takipçi listesi tam gelir', async () => {
  // deniz(30) hiçbir şeyi gizlemiyor; can(20) bakıyor.
  const s = await takipcilerinden('deniz', 20);
  assert.equal(s.gizli, false);
  assert.deepEqual(adlari(s), ['ayse']);
});

test('KAPALIYKEN SUNUCUDAN GELMİYOR: takipciler_gizli listeyi boşaltır', async () => {
  // ayse(10) takipçilerini gizlemiş. esra(50) bakıyor ve ayse'yi TAKİP
  // ETMİYOR, dolayısıyla listede kendi satırı da yok -> tamamen boş.
  // (İstemcide gizlemek yetmezdi: ham JSON'da satırlar durur ve
  // değiştirilmiş bir istemci onları okurdu.)
  const s = await takipcilerinden('ayse', 50);
  assert.equal(s.gizli, true);
  assert.deepEqual(s.kullanicilar, [], 'gizli listede yabancıya satır sızdı');
});

test('KAPALIYKEN OTURUMSUZ OKUMA DA BOŞ (ben=0)', async () => {
  const s = await takipcilerinden('ayse', 0);
  assert.equal(s.gizli, true);
  assert.deepEqual(s.kullanicilar, []);
});

test('KENDİ VERİMİ BEN GÖRÜYORUM: sahibi gizli listesini TAM görür', async () => {
  const s = await takipcilerinden('ayse', 10);
  assert.equal(s.gizli, false, 'sahibine `gizli` bayrağı gönderilmemeli');
  assert.deepEqual(adlari(s), ['can', 'deniz', 'engelli']);
  assert.ok(!KAYIT.sql.includes('ku.id = $2::int'),
    'sahibinin sorgusuna gizlilik süzgeci girmiş');
});

test('KENDİ KENARIN SANA GÖRÜNÜR: gizli listede İSTEYENİN satırı kalır', async () => {
  // can(20), ayse'yi takip ediyor. ayse listeyi gizlese de "ben onu takip
  // ediyorum" bilgisi can'ın KENDİ verisi — saklamak kimseyi korumaz, ama
  // `AramaServisi.karsilikliTakipMi`yi bozar (arama düğmesi kaybolurdu).
  const s = await takipcilerinden('ayse', 20);
  assert.equal(s.gizli, true);
  assert.deepEqual(adlari(s), ['can']);
});

test('İKİ ANAHTAR BAĞIMSIZ: takipciler_gizli, takip listesini kapatmaz', async () => {
  // ayse yalnız TAKİPÇİLERİNİ gizledi; kimi takip ettiği açık kalmalı.
  const s = await takipEttikleri('ayse', 30);
  assert.equal(s.gizli, false);
  assert.deepEqual(adlari(s), ['can', 'deniz']);
});

test('İKİ ANAHTAR BAĞIMSIZ: takip_edilenler_gizli, takipçi listesini kapatmaz', async () => {
  // can yalnız TAKİP ETTİKLERİNİ gizledi.
  assert.equal((await takipEttikleri('can', 30)).gizli, true);
  assert.equal((await takipcilerinden('can', 30)).gizli, false);
});

test('doğru sütuna bakılıyor: /takipciler -> takipciler_gizli', async () => {
  await takipcilerinden('ayse', 30);
  assert.equal(KAYIT.gizliSutun, 'takipciler_gizli');
  await takipEttikleri('ayse', 30);
  assert.equal(KAYIT.gizliSutun, 'takip_edilenler_gizli');
});

test('bilinmeyen kullanıcı: null (404) — gizlilik 404\'ü yutmaz', async () => {
  assert.equal(await takipcilerinden('yok', 30), null);
});

// ===========================================================================
// 5. ENGELLEME × GİZLİLİK — iki eksen, aynı sorgu, KARIŞMIYOR
// ===========================================================================

test('BİRLEŞİM: gizli liste açıkken de engelleme SÜZGECİ duruyor', async () => {
  // ayse'nin takipçisi: can(20), deniz(30), engelli(40). can, engelli'yi
  // engellemiş. Liste GİZLİ DEĞİLKEN can bakarsa engelli düşer, ötekiler kalır.
  const s = await takipcilerinden('deniz', 20); // deniz gizlemiyor
  assert.equal(s.gizli, false);
  assert.ok(KAYIT.sql.includes(engelSuzgec('ku.id', '$2')));
});

test('BİRLEŞİM: engelleme KİŞİYE ÖZEL kalır — gizlilik onu HERKESE yaymaz', async () => {
  // can(20), engelli(40)'ı engelledi. deniz(30) ENGELLEMEDİ, dolayısıyla
  // ayse'nin (gizli OLMAYAN) takip listesinde herkesi görür. Aynı listeye can
  // baksaydı yalnız engelli(40) düşerdi — engel üçüncü kişiye taşmaz.
  const denizGorusu = await takipcilerinden('deniz', 30);
  assert.deepEqual(adlari(denizGorusu), ['ayse']);
  const canGorusu = await takipcilerinden('deniz', 20);
  assert.deepEqual(adlari(canGorusu), ['ayse']);
});

test('BİRLEŞİM: engelli olan kendi satırını GİZLİ listede de göremez', async () => {
  // engelli(40) ayse'yi takip ediyor ve ayse'nin listesi gizli. Kendi satırı
  // gizlilikten muaf ama ENGELDEN muaf değil... burada engel çifti (20,40),
  // yani 40 kendi bakışında engelli değil: satırı gelir. Bu BEKLENEN — engel
  // kişiye özel, üçüncü kişinin engeli 40'ı bağlamaz.
  const s = await takipcilerinden('ayse', 40);
  assert.equal(s.gizli, true);
  assert.deepEqual(adlari(s), ['engelli']);
});

test('BİRLEŞİM: iki süzgeç AND ile yan yana, biri ötekini DEĞİŞTİRMEZ', async () => {
  await takipcilerinden('ayse', 20); // gizli + engelli bakan
  const sql = KAYIT.sql;
  assert.ok(sql.includes(engelSuzgec('ku.id', '$2')), 'engel süzgeci kaybolmuş');
  // İKİSİ DE `AND` ile bağlanıyor: biri OR'la gevşetilseydi engelli kişi
  // gizli listede (ya da yabancı, engel süzgecinin içinden) geri gelirdi.
  assert.ok(sql.includes(`AND ${engelSuzgec('ku.id', '$2')}`),
    'engel süzgeci AND ile bağlı değil');
  assert.ok(sql.includes(`AND ${kendiSatirSuzgec('ku.id', '$2')}`),
    'gizlilik süzgeci AND ile bağlı değil');
});

test('kendini engelleyemezsin: kendi satırın engel süzgecine takılmaz', () => {
  const uc = ucGovdesi('post', '/engelle/:kullaniciAdi');
  assert.match(uc, /Kendini engelleyemezsin/);
});

// ===========================================================================
// 6. AÇIK PROFİL UCU — izlenenler_gizli ARTIK TÜREVLERİ DE KAPATIYOR
// ===========================================================================

const PROFIL = ucGovdesi('get', '/profil/:kullaniciAdi');

test('profil: dört gizlilik bayrağı da `!benMi` ile başlar (sahibi her şeyi görür)', () => {
  for (const [degisken, sutun] of [
    ['izlenenlerGizli', 'izlenenler_gizli'],
    ['yorumlarGizli', 'yorumlar_gizli'],
    ['yanitlarGizli', 'yanitlar_gizli'],
  ]) {
    assert.match(
      PROFIL,
      new RegExp(`const ${degisken} = !benMi && k\\.rows\\[0\\]\\.${sutun} === true`),
      `${degisken} sahibi için de gizliyor olabilir`);
  }
});

test('profil: ENGELLEME kapısı gizlilikten ÖNCE gelir (engel her şeyi yener)', () => {
  const engelDonus = PROFIL.indexOf('if (engel !== null)');
  const gizlilik = PROFIL.indexOf('const benMi = benId === id');
  assert.ok(engelDonus >= 0 && gizlilik > engelDonus,
    'engellenen profil, gizlilik hesabından ÖNCE boş dönmeli');
});

test('profil: izlenenler_gizli açıkken izleme SAYAÇLARI da sıfırlanır', () => {
  // Şerit boşken "1.240 Bölüm · 96 Film" yazmak, gizlenen şeyin boyutunu
  // gizlemiyordu. 0 dönüyoruz (null değil): istemci sayacı dize olarak basıyor.
  assert.match(PROFIL, /izlenenlerGizli \? \{ bolum: 0, film: 0, dizi: 0 \} : \{\}/);
});

test('profil: izlenenler_gizli açıkken EKRAN SÜRESİ hiç hesaplanmaz', () => {
  // Karar `Promise.all` içinde veriliyor: yardımcı ÇAĞRILMIYOR, dolayısıyla
  // değer yanıta sızacak bir yoldan geçmiyor (yalnız yanıttan silseydik bir
  // sonraki düzenlemede geri gelebilirdi). `tekrar_izleme.test.js`in
  // "iki uç da AYNI yardımcıyı çağırır" kuralı da böylece korunuyor.
  assert.match(PROFIL, /izlenenlerGizli \? Promise\.resolve\(0\) : tahminiDakika\(id\)/);
  assert.match(PROFIL, /tahmini_dakika: dakika/);
});

test('profil: izlenenler_gizli açıkken UYUM hiç hesaplanmaz', () => {
  // Yalnız yanıttan silmek yetmez: iki ek sorgu boşuna atılırdı ve bir sonraki
  // düzenlemede biri yanıta geri sızabilirdi.
  assert.match(PROFIL, /if \(benId && benId !== id && !izlenenlerGizli\)/);
});

test('profil: izlenenler_gizli açıkken İZLEME TÜREVİ rozetler düşer', () => {
  assert.match(PROFIL, /IZLEME_ROZETLERI\.test\(r\.kod\)/);
});

test('IZLEME_ROZETLERI: izleme rozetlerini yakalar, ötekilere DOKUNMAZ', () => {
  // Kodlar `rozetleriHesapla`daki `tanimlar` dizisinden okunuyor: rozet
  // eklenip listeye yazılmazsa bu test kırmızıya döner.
  const tanimlar = bildirimCek('rozetleriHesapla');
  const kodlar = [...tanimlar.matchAll(/\['([a-z0-9_]+)',\s*s\.\w+/g)].map((m) => m[1]);
  assert.ok(kodlar.length >= 20, `rozet kodları okunamadı (${kodlar.length})`);
  const izleme = kodlar.filter((k) => IZLEME_ROZETLERI.test(k));
  const oteki = kodlar.filter((k) => !IZLEME_ROZETLERI.test(k));
  assert.deepEqual(izleme.sort(), [
    'bitiren_10', 'bitiren_25', 'bitiren_50',
    'bolum_100', 'bolum_1000', 'bolum_500', 'bolum_5000',
    'film_10', 'film_100', 'film_50', 'ilk_bolum', 'ilk_film',
  ]);
  // Yorum/puan/takipçi/beğeni rozetleri BAŞKA eksenlerin verisi: bu tercihle
  // ilgileri yok, düşürülürlerse kullanıcı hak ettiği nişanı kaybeder.
  for (const k of ['ilk_yorum', 'yorum_25', 'puan_10', 'ilk_takipci', 'begeni_10']) {
    assert.ok(oteki.includes(k), `${k} yanlışlıkla izleme rozeti sayılıyor`);
  }
});

test('profil: yeni iki bayrak yanıta konuyor (istemci kilidi çizebilsin)', () => {
  assert.match(PROFIL, /takipciler_gizli, takip_edilenler_gizli/);
});

test('profil: SAYAÇLAR süzülmüyor — bilinçli karar, gerekçesi yazılı', () => {
  // Liste kapanır, sayaç açık kalır (aynı karar /izleyenler'de de verildi).
  // Gerekçe kaynakta duruyor; silinirse bu test sebebi sorar.
  assert.match(PROFIL, /count\(\*\)::int FROM takipler WHERE takip_edilen_id=\$1\) AS takipci/);
  assert.match(SEMA, /SAYAÇLAR SÜZÜLMEZ/);
});

// ===========================================================================
// 7. AYARLAR EKRANI — her anahtarın karşılığı var
// ===========================================================================

// DİKKAT: `ayarlar.dart` içinde `_alanlar` adında İKİ liste var — biri
// bildirim tercihleri sheet'inde, biri gizlilik sheet'inde. Arama bu yüzden
// `_GizlilikSheetState` sınıfının başından itibaren yapılır; düz `indexOf`
// bildirim listesini bulup testi yanlış yerde yeşile boyardı.
const GIZLILIK_ALANLAR_BLOGU = (() => {
  const sinif = AYARLAR.indexOf('class _GizlilikSheetState');
  assert.ok(sinif >= 0, 'ayarlar.dart içinde _GizlilikSheetState yok');
  const bas = AYARLAR.indexOf('static const _alanlar = [', sinif);
  assert.ok(bas >= 0, 'gizlilik sheet\'inde _alanlar listesi yok');
  return blokAl(AYARLAR, bas + 'static const _alanlar = '.length, '[', ']');
})();

test('ayarlar: sunucudaki HER gizlilik alanının ekranda bir anahtarı var', () => {
  for (const a of GIZLILIK_ALANLARI) {
    assert.ok(GIZLILIK_ALANLAR_BLOGU.includes(`'${a}',`),
      `Ayarlar > Gizlilik ekranında ${a} anahtarı yok`);
  }
});

test('ayarlar: her anahtarın ALTINDA tek satırlık açıklaması var', () => {
  // `_alanlar` üçlüsü: (alan, etiket, aciklama). Üçüncü eleman boş kalırsa
  // kullanıcı anahtarın ne yaptığını bilemez (ekrandaki kalıp bu).
  const blok = GIZLILIK_ALANLAR_BLOGU;
  for (const a of GIZLILIK_ALANLARI) {
    const i = blok.indexOf(`'${a}',`);
    assert.ok(i >= 0, `${a} _alanlar listesinde yok`);
    // Alanı izleyen iki dize: etiket + açıklama.
    const kalan = blok.slice(i);
    const dizeler = [...kalan.matchAll(/'([^']{4,})'/g)].map((m) => m[1]);
    assert.ok(dizeler.length >= 3, `${a} için etiket/açıklama eksik`);
    assert.ok(dizeler[2].length > 20, `${a} açıklaması çok kısa: ${dizeler[2]}`);
  }
});
