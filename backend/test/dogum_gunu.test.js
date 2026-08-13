// DOĞUM GÜNÜ KUTLAMASI (istek md. 36) — `node --test test/*.test.js`
//
// "Doğum günü olan kullanıcıda kutlayalım." Kutlamanın HANGİ GÜN yapılacağı
// iki tuzak barındırıyor ve ikisi de bu dosyada kilitli:
//
//  1) 29 ŞUBAT: artık olmayan yıllarda o gün TAKVİMDE YOKTUR. Karar: kutlama
//     28 Şubat'a çekilir (1 Mart'a değil) — doğum ayının içinde kalsın diye.
//     Artık yıllarda kutlama yalnız 29'undadır, yani yılda TAM BİR KEZ.
//  2) SAAT DİLİMİ: sunucu UTC çalışıyor. Kutlama KULLANICININ takvim gününe
//     göre yapılır; istemci yerel gününü `?bugun=YYYY-MM-DD` ile bildirir,
//     bildirmezse UTC gününe düşülür. Sapma ±1 günle sınırlıdır (gerçek saat
//     dilimleri UTC-12…UTC+14). 13 Ağu'da md. 37'de UTC/yerel karışıklığı
//     GERÇEK bir hata olarak yakalanmıştı; aynı sınıfı burada kilitliyoruz.
//
// GİZLİLİK: doğum tarihi kişisel veridir. `/dogum-gunu` yalnız SAHİBİNE
// çalışır ve gün/ay/yılın kendisini DÖNDÜRMEZ; herkese açık profil ucu bu
// alanlara hiç dokunmaz.
//
// YÖNTEM: `server.js` içe aktarılamıyor (modül yüklenir yüklenmez dinlemeye
// başlıyor — gizlilik_secenekleri/engelleme testleriyle aynı gerekçe). Bu
// yüzden ilgili fonksiyonlar KAYNAKTAN ÇEKİLİP GERÇEKTEN ÇALIŞTIRILIYOR:
// sınanan şey kopyası değil, canlıdaki kodun ta kendisi.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const KAYNAK = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');

/** `bas`tan sonraki ilk `{`/`}` çiftini dengeleyerek bloğun SONUNU döndürür. */
function blokSonu(kaynak, bas) {
  let derinlik = 0;
  let basladi = false;
  for (let i = bas; i < kaynak.length; i++) {
    const c = kaynak[i];
    if (c === '{') { derinlik++; basladi = true; } else if (c === '}') {
      derinlik--;
      if (basladi && derinlik === 0) return i + 1;
    }
  }
  throw new Error('blok kapanmadı');
}

/** Kaynaktaki `function ad(...) {...}` bildiriminin METNİ. */
function fonksiyonKaynagi(ad) {
  const imza = `function ${ad}(`;
  const bas = KAYNAK.indexOf(imza);
  assert.notEqual(bas, -1, `${ad} server.js'te bulunamadı`);
  return KAYNAK.slice(bas, blokSonu(KAYNAK, bas));
}

const ADLAR = ['artikYilMi', 'tarihCoz', 'gunFarki', 'kutlamaGunu', 'dogumGunuMu'];
// eslint-disable-next-line no-new-func
const { artikYilMi, tarihCoz, kutlamaGunu, dogumGunuMu } = new Function(
  `${ADLAR.map(fonksiyonKaynagi).join('\n')}\nreturn { ${ADLAR.join(', ')} };`,
)();

const gun = (yil, ay, g) => ({ yil, ay, gun: g });

// ---------------------------------------------------------------------------
// Temel tespit
// ---------------------------------------------------------------------------

test('bugün doğum günüyse kutlama var, değilse yok', () => {
  assert.equal(dogumGunuMu(13, 8, gun(2026, 8, 13)), true);
  assert.equal(dogumGunuMu(13, 8, gun(2026, 8, 12)), false);
  assert.equal(dogumGunuMu(13, 8, gun(2026, 8, 14)), false);
  // Aynı gün, BAŞKA ay: gün sayısına bakıp ayı unutmak klasik hata.
  assert.equal(dogumGunuMu(13, 8, gun(2026, 9, 13)), false);
});

test('doğum tarihi girmemiş kullanıcıda kutlama YOK', () => {
  assert.equal(dogumGunuMu(null, null, gun(2026, 8, 13)), false);
  assert.equal(dogumGunuMu(undefined, undefined, gun(2026, 8, 13)), false);
  // Yarım veri (yalnız gün ya da yalnız ay) da kutlatmaz.
  assert.equal(dogumGunuMu(13, null, gun(2026, 8, 13)), false);
  assert.equal(dogumGunuMu(null, 8, gun(2026, 8, 13)), false);
  // "0" ya da metin gelirse de patlamaz, sessizce kutlamaz.
  assert.equal(dogumGunuMu('13', '8', gun(2026, 8, 13)), false);
});

test('yıl bilinmese de kutlama çalışır (yıl kutlamanın parçası değil)', () => {
  // dogumGunuMu yıla HİÇ bakmaz — imzasında yok. Yılsız kullanıcı için de
  // aynı sonuç çıkar; yıl yalnız YAŞ hesabında kullanılır.
  assert.equal(dogumGunuMu(1, 1, gun(2026, 1, 1)), true);
  assert.equal(dogumGunuMu(1, 1, gun(1999, 1, 1)), true);
});

// ---------------------------------------------------------------------------
// 29 Şubat
// ---------------------------------------------------------------------------

test('artık yılda 29 Şubat doğumlu 29 Şubat`ta kutlanır, 28`inde DEĞİL', () => {
  assert.equal(artikYilMi(2028), true);
  assert.equal(dogumGunuMu(29, 2, gun(2028, 2, 29)), true);
  assert.equal(dogumGunuMu(29, 2, gun(2028, 2, 28)), false);
  assert.equal(dogumGunuMu(29, 2, gun(2028, 3, 1)), false);
});

test('artık OLMAYAN yılda 29 Şubat doğumlu 28 Şubat`ta kutlanır', () => {
  assert.equal(artikYilMi(2026), false);
  assert.equal(dogumGunuMu(29, 2, gun(2026, 2, 28)), true);
  // 1 Mart'a KAYDIRILMADI: kutlama doğum ayının içinde kalır.
  assert.equal(dogumGunuMu(29, 2, gun(2026, 3, 1)), false);
});

test('yüzyıl kuralı: 1900 artık DEĞİL, 2000 artık', () => {
  assert.equal(artikYilMi(1900), false);
  assert.equal(artikYilMi(2000), true);
  assert.equal(dogumGunuMu(29, 2, gun(1900, 2, 28)), true);
  assert.equal(dogumGunuMu(29, 2, gun(2000, 2, 28)), false);
  assert.equal(dogumGunuMu(29, 2, gun(2000, 2, 29)), true);
});

test('28 Şubat doğumlu artık yılda 29`unda kutlanmaz (yalnız 28`inde)', () => {
  assert.equal(dogumGunuMu(28, 2, gun(2028, 2, 28)), true);
  assert.equal(dogumGunuMu(28, 2, gun(2028, 2, 29)), false);
  // Artık olmayan yılda 28 Şubat doğumlu ile 29 Şubat doğumlu AYNI gün
  // kutlanır; ikisi de yılda bir kez kutlanmış olur.
  assert.equal(dogumGunuMu(28, 2, gun(2026, 2, 28)), true);
});

// ---------------------------------------------------------------------------
// Saat dilimi
// ---------------------------------------------------------------------------

test('istemcinin yerel günü kullanılır (UTC günü değil)', () => {
  // Sunucuda 12 Ağustos 22:00 UTC; UTC+3'teki kullanıcıda 13 Ağustos.
  const simdi = new Date(Date.UTC(2026, 7, 12, 22, 0, 0));
  assert.deepEqual(kutlamaGunu('2026-08-13', simdi), gun(2026, 8, 13));
  assert.equal(dogumGunuMu(13, 8, kutlamaGunu('2026-08-13', simdi)), true);
  // Aynı an, UTC gününe göre karar verilseydi kutlama KAÇARDI:
  assert.equal(dogumGunuMu(13, 8, kutlamaGunu(null, simdi)), false);
});

test('yerel gün geri yönde de çalışır (UTC-5)', () => {
  // Sunucuda 14 Ağustos 02:00 UTC; UTC-5'teki kullanıcıda hâlâ 13 Ağustos.
  const simdi = new Date(Date.UTC(2026, 7, 14, 2, 0, 0));
  assert.deepEqual(kutlamaGunu('2026-08-13', simdi), gun(2026, 8, 13));
});

test('parametre yoksa/bozuksa UTC gününe düşülür', () => {
  const simdi = new Date(Date.UTC(2026, 7, 13, 12, 0, 0));
  const utc = gun(2026, 8, 13);
  assert.deepEqual(kutlamaGunu(undefined, simdi), utc);
  assert.deepEqual(kutlamaGunu('', simdi), utc);
  assert.deepEqual(kutlamaGunu('bugün', simdi), utc);
  assert.deepEqual(kutlamaGunu('2026-8-13', simdi), utc); // dolgusuz
  assert.deepEqual(kutlamaGunu('2026-02-30', simdi), utc); // takvimde yok
  assert.deepEqual(kutlamaGunu('2026-13-01', simdi), utc); // 13. ay
  assert.deepEqual(kutlamaGunu({ yil: 2026 }, simdi), utc); // nesne enjeksiyonu
});

test('bir günden UZAK yerel tarih yok sayılır (±1 gün sınırı)', () => {
  const simdi = new Date(Date.UTC(2026, 7, 13, 12, 0, 0));
  const utc = gun(2026, 8, 13);
  // Gerçek saat dilimleri UTC-12…UTC+14: sapma en çok bir gündür.
  assert.deepEqual(kutlamaGunu('2026-08-14', simdi), gun(2026, 8, 14));
  assert.deepEqual(kutlamaGunu('2026-08-12', simdi), gun(2026, 8, 12));
  // İki gün ötesi = uydurma; kutlamayı öne çekmeye çalışan istemci UTC'ye düşer.
  assert.deepEqual(kutlamaGunu('2026-08-15', simdi), utc);
  assert.deepEqual(kutlamaGunu('2026-12-25', simdi), utc);
  assert.deepEqual(kutlamaGunu('1999-01-01', simdi), utc);
});

test('ay/yıl sınırında ±1 gün doğru hesaplanır', () => {
  // 31 Ara ↔ 1 Oca: gün numaralarının farkı 30, gerçek fark 1 gün.
  const yilbasi = new Date(Date.UTC(2027, 0, 1, 1, 0, 0));
  assert.deepEqual(kutlamaGunu('2026-12-31', yilbasi), gun(2026, 12, 31));
  const yilsonu = new Date(Date.UTC(2026, 11, 31, 23, 0, 0));
  assert.deepEqual(kutlamaGunu('2027-01-01', yilsonu), gun(2027, 1, 1));
});

test('tarihCoz artık yıl gününü tanır', () => {
  assert.deepEqual(tarihCoz('2028-02-29'), gun(2028, 2, 29));
  assert.equal(tarihCoz('2026-02-29'), null);
});

// ---------------------------------------------------------------------------
// Uç sözleşmesi (gizlilik + kısıtlar)
// ---------------------------------------------------------------------------

/** `/dogum-gunu` ucunun kaynak metni. */
function ucGovdesi() {
  const bas = KAYNAK.indexOf("app.get('/dogum-gunu'");
  assert.notEqual(bas, -1, '/dogum-gunu ucu yok');
  return KAYNAK.slice(bas, blokSonu(KAYNAK, bas));
}

test('/dogum-gunu giriş ister ve hız limitlidir', () => {
  const govde = ucGovdesi();
  assert.match(govde, /girisZorunlu/);
  assert.match(govde, /dogumGunuLimiti/);
  // Limit kullanıcı BAŞINA (id) anahtarlanır, IP başına değil.
  assert.match(KAYNAK, /const dogumGunuLimiti = hizLimiti\(\d+, \(req\) => `dg:\$\{req\.kullanici\.id\}`\)/);
});

test('/dogum-gunu yalnız İSTEK SAHİBİNİN satırını okur', () => {
  const govde = ucGovdesi();
  // Sorgu `WHERE id=$1` + `req.kullanici.id`: başka kullanıcının doğum
  // tarihine bakmanın yolu yok (yol parametresi de yok).
  assert.match(govde, /WHERE id=\$1/);
  assert.match(govde, /\[req\.kullanici\.id\]/);
  assert.doesNotMatch(govde, /req\.params/);
});

test('/dogum-gunu doğum tarihini DIŞARI VERMEZ, önbelleğe de girmez', () => {
  const govde = ucGovdesi();
  const yanit = govde.slice(govde.indexOf('res.json('));
  assert.doesNotMatch(yanit, /dogum_gun/);
  assert.doesNotMatch(yanit, /dogum_ay/);
  assert.doesNotMatch(yanit, /dogum_yil/);
  assert.match(yanit, /kutlama/);
  // Kişisel yanıt paylaşılan önbelleğe (Cloudflare/nginx) DÜŞMEMELİ.
  assert.match(govde, /res\.set\('Cache-Control', 'private, no-store'\)/);
});

test('herkese açık profil ucu doğum tarihine hiç dokunmaz', () => {
  const bas = KAYNAK.indexOf("app.get('/profil/:kullaniciAdi'");
  assert.notEqual(bas, -1);
  const govde = KAYNAK.slice(bas, KAYNAK.indexOf('app.delete(', bas));
  assert.doesNotMatch(govde, /dogum_gun|dogum_ay|dogum_yil/);
});

test('yaş yalnız yıl paylaşıldıysa döner', () => {
  const govde = ucGovdesi();
  // `Number.isInteger(k.dogum_yil)` koşulu: yıl null ise yaş null kalır.
  assert.match(govde, /Number\.isInteger\(k\.dogum_yil\)/);
  assert.match(govde, /bugun\.yil - k\.dogum_yil/);
  // Yaş yalnız kutlama günü hesaplanır — başka gün sorulunca da sızmaz.
  assert.match(govde, /kutlama && Number\.isInteger/);
});
