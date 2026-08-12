// gunluk.js — SIZINTI SÜZGECİ testleri.  `node --test test/*.test.js`
//
// Bu dosyanın TEK işi: hata logunun hassas veriyi ASLA basmadığını
// KANITLAMAK. gunluk.js saf modül olduğu için (yalnız `fs` import eder,
// pg/express/process.env okumaz) sunucu ayağa kalkmadan, saniyeler içinde
// çalışır.
//
// İKİ KATMAN ayrı ayrı kilitlenir:
//   KATMAN 1 (beyaz liste): istekBaglami() istekten YALNIZ sabit alanları
//     alır — body/headers/query DEĞERLERİ asla girmez.
//   KATMAN 2 (desen süzgeci): metniTemizle()/temizle()/hataOzeti() serbest
//     metni (hata mesajı, yığın izi) desenlerden geçirir.
//
// YÖNTEM: her gizli değer için kirli girdiyi ilgili yoldan geçir, çıktının
// SERİLEŞTİRİLMİŞ hâlinde (JSON.stringify) o gizli değerin BULUNMADIĞINI
// iddia et. Serileştirmeden test etmek yanıltıcıdır: iç içe bir alanda
// sızıntı, düz `assert` gözünden kaçabilir; `satir()` çıktısı loga giden
// gerçek bayttır.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  metniTemizle, temizle, hataOzeti, istekBaglami,
  kayitYap, satir, yaz, olumcul, gizliAnahtarMi,
  AZAMI_METIN, AZAMI_YIGIN, AZAMI_DERINLIK, AZAMI_ANAHTAR,
  GIZLI_ICEREN, GIZLI_TAM, SDP_BELIRTECI,
} from '../gunluk.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));

// Tüm süzgeç yollarını tek çağrıda dener: bir gizli değer HANGİ kapıdan
// geçerse geçsin yakalanmalı. Dönen dize, o değerin log'a ulaşabileceği
// TÜM biçimlerin birleşimidir.
function tumYollar(gizli, sarmalayici = (v) => v) {
  const parcalar = [];
  parcalar.push(satir(kayitYap(sarmalayici(gizli))));
  parcalar.push(satir({ x: temizle(sarmalayici(gizli)) }));
  parcalar.push(String(metniTemizle(String(gizli))));
  parcalar.push(satir(hataOzeti(new Error(`hata: ${gizli}`))));
  return parcalar.join('\n');
}

// Bir dizede gizli değer HİÇ geçmiyor mu? Kısa/çok yaygın parçalar
// (ör. "a") yanlış negatif üretmesin diye çağıran taraf anlamlı, uzun
// gizli değerler verir.
function icermez(cikti, gizli, mesaj) {
  assert.ok(!cikti.includes(gizli), `${mesaj}\n  SIZINTI: "${gizli}" çıktıda görünüyor:\n  ${cikti}`);
}

// ===========================================================================
// 1. ŞİFRE — düz metin ve hash
// ===========================================================================
test('şifre (düz metin) — gövde alanında loga girmez', () => {
  const sifre = 'CokGizliParola123!@#';
  const kayit = satir(kayitYap({
    olay: 'giris_hatasi',
    req: { path: '/giris', method: 'POST', body: { email: 'a@b.com', sifre } },
    // ham veri yanlışlıkla üst düzeye de konsa yakalanmalı:
    girdi: { password: sifre, parola: sifre, pwd: sifre },
  }));
  icermez(kayit, sifre, 'düz metin şifre loga sızdı');
  assert.match(kayit, /\[gizli\]/);
});

test('şifre (bcrypt hash) — desen süzgeci maskeler', () => {
  const hash = '$2b$12$R9h/cIPz0gi.URNNX3kh2OPST9/PgBkqquzi.Ss7KIUgO2t0jWMUW';
  const cikti = tumYollar(hash, (v) => ({ olay: 'x', deger: v }));
  icermez(cikti, hash, 'bcrypt hash loga sızdı');
  assert.match(metniTemizle(`kayıt: ${hash}`), /\[hash\]/);
});

// ===========================================================================
// 2. JWT / TOKEN / Authorization
// ===========================================================================
test('JWT — hata mesajı içinde bile maskelenir', () => {
  const jwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6MywiZXhwIjo5OTk5fQ.s3cr3tS1gnatureXYZ_abcDEF';
  const cikti = tumYollar(jwt, (v) => ({ olay: 'yetki', not: `invalid token ${v}` }));
  icermez(cikti, jwt, 'JWT loga sızdı');
  assert.match(metniTemizle(`invalid token ${jwt}`), /\[token\]/);
});

test('token — hassas anahtar adı altında değer atılır', () => {
  const tok = 'sk_live_9f8e7d6c5b4a3928abcdefABCDEF0123456789xyz';
  const kayit = satir(kayitYap({ olay: 'x', veri: { token: tok, jwt: tok, apikey: tok } }));
  icermez(kayit, tok, 'token hassas anahtar altında sızdı');
});

test('Authorization başlığı değeri — hem ad hem Bearer deseni yakalar', () => {
  const bearer = 'Bearer eyJhbGciOiJIUzI1NiJ9.eyJhIjoxfQ.QWERTYuiop1234567890asdfgh';
  const kayit = satir(kayitYap({
    olay: 'x',
    baslik: { authorization: bearer },
    serbest: `header vardı: ${bearer}`,
  }));
  icermez(kayit, bearer, 'Authorization değeri loga sızdı');
  // Token gövdesi maskelense de "Bearer" etiketi kalabilir; kritik olan token değeri.
  const tokenGovde = 'QWERTYuiop1234567890asdfgh';
  icermez(kayit, tokenGovde, 'Bearer token gövdesi loga sızdı');
});

// ===========================================================================
// 3. MESAJ İÇERİĞİ
// ===========================================================================
test('mesaj içeriği — mesaj/metin/icerik/govde anahtarları altında atılır', () => {
  const mesaj = 'Buluşalım mı? Saat 8 gibi köşedeki kafede.';
  const kayit = satir(kayitYap({
    olay: 'dm_hatasi',
    veri: { mesaj, metin: mesaj, icerik: mesaj, govde: mesaj, body: mesaj },
  }));
  icermez(kayit, mesaj, 'mesaj içeriği loga sızdı');
});

// ===========================================================================
// 4. E-POSTA ADRESİ
// ===========================================================================
test('e-posta — anahtar adı altında VE serbest metinde maskelenir', () => {
  const eposta = 'gercek.kullanici@ornek-alan.com';
  const kayit = satir(kayitYap({
    olay: 'kayit_hatasi',
    veri: { email: eposta, eposta },
    serbest: `zaten kayıtlı: ${eposta}`,
    yolda: `/sifirla/${eposta}/token`,
  }));
  icermez(kayit, eposta, 'e-posta loga sızdı');
  assert.match(metniTemizle(`kullanıcı ${eposta} bulundu`), /\[e-posta\]/);
});

// ===========================================================================
// 5. SDP / ICE gövdesi (WebRTC arama)
// ===========================================================================
test('SDP gövdesi (v=0...) — tamamı [sdp/ice] ile atılır', () => {
  const sdp = [
    'v=0',
    'o=- 4611731400430051336 2 IN IP4 127.0.0.1',
    's=-',
    'm=audio 9 UDP/TLS/RTP/SAVPF 111',
    'a=fingerprint:sha-256 AB:CD:EF:00:11:22:33:44',
    'a=ice-ufrag:F7g2',
    'a=ice-pwd:x9zQwErTyUiOpAsDfGhJkL',
  ].join('\r\n');
  assert.equal(metniTemizle(sdp), '[sdp/ice]');
  const kayit = satir(kayitYap({ olay: 'arama_hatasi', teklif: sdp }));
  icermez(kayit, 'ice-pwd', 'SDP ice-pwd loga sızdı');
  icermez(kayit, 'fingerprint', 'SDP fingerprint loga sızdı');
  icermez(kayit, '127.0.0.1', 'SDP IP loga sızdı');
});

test('ICE candidate satırı — [sdp/ice] ile atılır', () => {
  const cand = 'candidate:842163049 1 udp 1677729535 203.0.113.7 54321 typ srflx raddr 0.0.0.0 rport 0';
  assert.equal(metniTemizle(cand), '[sdp/ice]');
  icermez(satir(kayitYap({ olay: 'x', aday: cand })), '203.0.113.7', 'ICE aday IP loga sızdı');
});

// ===========================================================================
// 6. PG HATA MESAJI İÇİNDEKİ PARAMETRE DEĞERİ — asıl sinsi kapı
// ===========================================================================
test('pg hata mesajı — mesaj/detail içindeki değer basılmaz; kod tutulur', () => {
  const eposta = 'kurban@gizli.com';
  const pgHata = new Error(`duplicate key value violates unique constraint "kullanici_email_key"`);
  pgHata.code = '23505';
  // pg sürücüsü `detail`i DEĞER İLE doldurur: bu, hataOzeti tarafından
  // BİLEREK alınmaz (whitelist dışı). Yine de mesaja değer sızmış senaryoyu
  // da test edelim:
  pgHata.detail = `Key (email)=(${eposta}) already exists.`;
  const mesajliPg = new Error(`insert failed: Key (email)=(${eposta}) already exists.`);
  mesajliPg.code = '23505';

  const ozet1 = satir(hataOzeti(pgHata));
  const ozet2 = satir(hataOzeti(mesajliPg));
  icermez(ozet1, eposta, 'pg detail üzerinden e-posta sızdı');
  icermez(ozet2, eposta, 'pg mesajı içindeki e-posta sızdı');
  // Teşhis için hassas OLMAYAN pg kodu KORUNMALI:
  assert.match(ozet1, /23505/, 'pg kodu (teşhis için kritik, hassas değil) düştü');
  // detail alanı hiç alınmamalı:
  assert.ok(!ozet1.includes('detail'), 'hataOzeti detail alanını almamalı');
});

// ===========================================================================
// 7. DOĞRULAMA HATASI İÇİNDEKİ KULLANICI GİRDİSİ
// ===========================================================================
test('doğrulama hatası — mesaja gömülü kullanıcı girdisi maskelenir', () => {
  const girdi = 'admin@sirket.com';
  const err = new Error(`Geçersiz e-posta: "${girdi}" kabul edilmedi`);
  const ozet = satir(hataOzeti(err));
  icermez(ozet, girdi, 'doğrulama hatasındaki kullanıcı e-postası sızdı');
});

test('doğrulama hatası — girdi bir JWT ise de yakalanır', () => {
  const girdi = 'eyJhbGciOiJub25lIn0.eyJzdWIiOiJhdHRhY2sifQ.forgedSignatureAAAAAAAAAAAAAA';
  const err = new Error(`token doğrulanamadı: ${girdi}`);
  icermez(satir(hataOzeti(err)), girdi, 'doğrulama hatasındaki JWT sızdı');
});

// ===========================================================================
// 8. YIĞIN İZİ (stack) — mesaj kadar tehlikeli, o da süzülür
// ===========================================================================
test('yığın izi — stack içine gömülü gizli değer maskelenir', () => {
  const gizli = 'gizli.kisi@mail.com';
  const err = new Error('patladı');
  err.stack = `Error: patladı\n    at f (/app/server.js:1:1) // ${gizli}\n    at g (/app/x.js:2:2)`;
  const ozet = satir(hataOzeti(err));
  icermez(ozet, gizli, 'yığın izindeki e-posta sızdı');
  // Yığın izi TAMAMEN atılmamalı: teşhis için dosya/satır kalmalı.
  assert.match(ozet, /server\.js/, 'yığın izi tamamen kaybolmuş; teşhis imkânsız');
});

test('yığın izi — AZAMI_YIGIN kadar kare tutulur', () => {
  const err = new Error('derin');
  const kareler = ['Error: derin'];
  for (let i = 0; i < 50; i++) kareler.push(`    at kare${i} (/app/f.js:${i}:1)`);
  err.stack = kareler.join('\n');
  assert.ok(hataOzeti(err).yigin.length <= AZAMI_YIGIN, 'yığın izi kırpılmadı');
});

// ===========================================================================
// 9. KATMAN 1 — BEYAZ LİSTE (istekBaglami)
// ===========================================================================
test('istekBaglami — YALNIZ sabit alanları geçirir; body/header/query DEĞERİ girmez', () => {
  const b = istekBaglami({
    istekId: 'req-1',
    path: '/mesaj/gonder',
    method: 'POST',
    kullanici: { id: 7, email: 'kotu@sizinti.com' }, // email GEÇMEMELİ
    query: { token: 'GIZLI_TOKEN_DEGERI', sayfa: '2' },
    body: { sifre: 'GIZLI_SIFRE', mesaj: 'gizli mesaj', to: 5 },
    headers: { authorization: 'Bearer GIZLI' }, // hiç alınmamalı
  });
  const s = JSON.stringify(b);
  // Beklenen sabit alanlar VAR:
  assert.equal(b.istek, 'req-1');
  assert.equal(b.yol, '/mesaj/gonder');
  assert.equal(b.metot, 'POST');
  assert.equal(b.kullanici, 7);
  // Sorgu/gövde yalnız ANAHTAR ADLARI (değer YOK):
  assert.deepEqual(b.sorgu, ['token', 'sayfa']);
  assert.deepEqual(b.alanlar, ['sifre', 'mesaj', 'to']);
  // Hiçbir DEĞER sızmamalı:
  icermez(s, 'GIZLI_TOKEN_DEGERI', 'query değeri beyaz listeyi deldi');
  icermez(s, 'GIZLI_SIFRE', 'body değeri beyaz listeyi deldi');
  icermez(s, 'gizli mesaj', 'body mesaj değeri beyaz listeyi deldi');
  icermez(s, 'kotu@sizinti.com', 'kullanıcı e-postası beyaz listeyi deldi');
  icermez(s, 'Bearer', 'header beyaz listeyi deldi');
  // Bilinmeyen üst-düzey alan (headers) hiç alınmamalı:
  assert.equal(b.headers, undefined);
  assert.equal(b.baslik, undefined);
});

test('istekBaglami — originalUrl DEĞİL path kullanır (sorgu dizesi taşımaz)', () => {
  const b = istekBaglami({
    path: '/ara',
    originalUrl: '/ara?token=SIZAN_TOKEN&q=abc',
  });
  icermez(JSON.stringify(b), 'SIZAN_TOKEN', 'originalUrl sorgu dizesi loga sızdı');
});

test('gizliAnahtarMi — bilinen hassas adları yakalar, masumları geçirir', () => {
  for (const p of ['sifre', 'password', 'token', 'jwt', 'authorization',
    'secret', 'cookie', 'email', 'mesaj', 'sdp', 'candidate']) {
    assert.ok(gizliAnahtarMi(p), `hassas ad kaçtı: ${p}`);
  }
  // Ad İÇİNDE geçmesi yeter:
  assert.ok(gizliAnahtarMi('kullanici_sifresi'));
  assert.ok(gizliAnahtarMi('X-Authorization'));
  // TAM eşleşenler yaygın kelimeleri yakalamamalı:
  assert.ok(!gizliAnahtarMi('siralama'), '"sir" TAM eşleşme "siralama"yı yakaladı');
  assert.ok(!gizliAnahtarMi('monkey'), '"key" TAM eşleşme "monkey"i yakaladı');
  assert.ok(!gizliAnahtarMi('yorum'));
  assert.ok(!gizliAnahtarMi('id'));
});

// ===========================================================================
// 10. DAYANIKLILIK — süzgeç girdi ne olursa olsun ÇÖKMEZ
// ===========================================================================
test('döngüsel referans — WeakSet ile çökmez, [dongusel] yazar', () => {
  const a = { ad: 'a' };
  a.kendisi = a;
  a.liste = [a, a];
  let s;
  assert.doesNotThrow(() => { s = satir(kayitYap({ olay: 'x', veri: a })); });
  assert.match(s, /\[dongusel\]/);
});

test('derinlik sınırı — çok derin nesnede [derin] ile durur', () => {
  let derin = { son: 'DIP_DEGER' };
  for (let i = 0; i < 20; i++) derin = { alt: derin };
  const s = satir({ x: temizle(derin) });
  assert.match(s, /\[derin\]/, 'derinlik sınırı uygulanmadı');
});

test('uzunluk kırpma — AZAMI_METIN üstündeki dize kırpılır', () => {
  // Boşluklu dize: 40+ kesintisiz blok olmadığı için blob deseni yerine
  // gerçekten uzunluk kırpması test edilir.
  const uzun = 'ab '.repeat(AZAMI_METIN);
  const kirpik = metniTemizle(uzun);
  assert.ok(kirpik.length < uzun.length, 'uzun dize kırpılmadı');
  assert.match(kirpik, /…\(\d+\)$/, 'kırpma işareti yok');
});

test('anahtar sayısı — AZAMI_ANAHTAR ile sınırlı', () => {
  const genis = {};
  for (let i = 0; i < AZAMI_ANAHTAR + 30; i++) genis[`k${i}`] = i;
  assert.ok(Object.keys(temizle(genis)).length <= AZAMI_ANAHTAR, 'anahtar sayısı sınırlanmadı');
});

test('temizle — null/undefined/sayı/BigInt/Date/fonksiyon güvenli', () => {
  assert.equal(temizle(null), null);
  assert.equal(temizle(undefined), undefined);
  assert.equal(temizle(42), 42);
  assert.equal(temizle(true), true);
  assert.equal(temizle(10n), '10');
  assert.equal(typeof temizle(() => {}), 'string');
  assert.match(temizle(() => {}), /\[function\]/);
  assert.match(temizle(new Date('2020-01-01T00:00:00Z')), /2020-01-01/);
});

test('satir — serileştirilemeyen kayıtta bile asla fırlatmaz', () => {
  const kotu = { toJSON() { throw new Error('patla'); } };
  let s;
  assert.doesNotThrow(() => { s = satir(kotu); });
  assert.match(s, /log_serilestirilemedi/);
});

test('hataOzeti — Error olmayan reddetme (throw metin / reject sayı) güvenli', () => {
  const o1 = hataOzeti('sadece metin');
  assert.equal(o1.ad, 'string');
  const o2 = hataOzeti(42);
  assert.equal(o2.ad, 'number');
  // Error olmayan reddetmenin içindeki gizli değer de süzülmeli:
  const gizli = 'gizli@x.com';
  icermez(satir(hataOzeti(`reddedildi: ${gizli}`)), gizli, 'Error-olmayan reddetmede e-posta sızdı');
});

test('hata.cause zinciri — iç içe hatadaki gizli değer de süzülür', () => {
  const gizli = 'zincir@gizli.com';
  const ic = new Error(`iç: ${gizli}`);
  const dis = new Error('dış patlama', { cause: ic });
  icermez(satir(hataOzeti(dis)), gizli, 'hata.cause içindeki e-posta sızdı');
});

// ===========================================================================
// 11. YAZ / OLUMCUL — gerçek log yolları da süzgeçten geçer
// ===========================================================================
test('yaz() — döndürdüğü satır süzülmüş ve geçerli JSON', () => {
  const gizli = 'yaz@gizli.com';
  const s = yaz({ olay: 'x', veri: { email: gizli }, not: `serbest ${gizli}` });
  icermez(s, gizli, 'yaz() çıktısında e-posta sızdı');
  assert.doesNotThrow(() => JSON.parse(s), 'yaz() geçerli JSON üretmedi');
  assert.equal(JSON.parse(s).seviye, 'hata');
});

test('olumcul() — seviye olumcul, süzülmüş ve geçerli JSON', () => {
  const gizli = 'CokGizliSifre!';
  const s = olumcul({ olay: 'cokme', veri: { sifre: gizli } });
  icermez(s, gizli, 'olumcul() çıktısında şifre sızdı');
  assert.equal(JSON.parse(s).seviye, 'olumcul');
});

// ===========================================================================
// 12. C1 — HATA SATIRI ALAN SETİ
// ===========================================================================
// server.js'in son durak yakalayıcısı ve `sarici` tam bu çağrı biçimini
// kullanır. Alanlardan biri düşerse (ya da süzgece takılıp "[gizli]" olursa)
// 500 teşhisi yine körleşir — set burada kilitlenir.
test('C1 alan seti: zaman/seviye/olay/istek/yol/metot/kullanici/durum/hata tam', () => {
  const err = new Error('patladı');
  const kayit = JSON.parse(satir(kayitYap({
    olay: 'son_durak_hatasi',
    req: {
      istekId: 'abc12345',
      path: '/icerik/123/yorumlar',
      method: 'POST',
      kullanici: { id: 42 },
    },
    durum: 500,
    hata: err,
  })));
  assert.match(kayit.ts, /^\d{4}-\d{2}-\d{2}T/, 'ISO zaman damgası yok');
  assert.equal(kayit.seviye, 'hata');
  assert.equal(kayit.olay, 'son_durak_hatasi');
  assert.equal(kayit.istek, 'abc12345');
  assert.equal(kayit.yol, '/icerik/123/yorumlar');
  assert.equal(kayit.metot, 'POST');
  assert.equal(kayit.kullanici, 42);
  assert.equal(kayit.durum, 500, 'durum kodu düşmüş ya da süzgece takılmış');
  assert.equal(kayit.hata.ad, 'Error');
  assert.equal(kayit.hata.mesaj, 'patladı');
  assert.ok(Array.isArray(kayit.hata.yigin) && kayit.hata.yigin.length > 0, 'yığın izi yok');
});

test('C1 ad tuzağı: `kod` alanı [gizli]lenir, `durum` geçer — çağrı yerleri durum kullanmalı', () => {
  // `kod` GIZLI_TAM listesinde (doğrulama kodu varsayımı). HTTP durum kodunu
  // `kod` adıyla loglayan çağrı "[gizli]" basar ve kimse fark etmez —
  // yaşandı. kapanma.test.js server.js'teki çağrıları ayrıca tarar.
  const kayit = JSON.parse(satir(kayitYap({ olay: 'x', kod: 500, durum: 500 })));
  assert.equal(kayit.kod, '[gizli]', '`kod` artık süzülmüyorsa GIZLI_TAM değişmiş — doğrulama kodları sızar');
  assert.equal(kayit.durum, 500, '`durum` süzgece takılıyor — durum kodu loglanamaz olur');
});

// ===========================================================================
// 13. KONTEYNER / SAFLIK TUZAĞI (yasak.test.js disipliniyle)
// ===========================================================================
test('gunluk.js Dockerfile COPY listesinde (yoksa konteyner hiç açılmaz)', () => {
  const dockerfile = fs.readFileSync(path.join(KOK, 'Dockerfile'), 'utf8');
  assert.match(dockerfile, /\bgunluk\.js\b/,
    'gunluk.js imaja girmiyor — "Cannot find module ./gunluk.js" ile restart döngüsü');
});

test('gunluk.js SAF: yalnız fs import eder; pg/express/process.env okumaz', () => {
  const ham = fs.readFileSync(path.join(KOK, 'gunluk.js'), 'utf8');
  const kod = ham.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');
  assert.doesNotMatch(kod, /from 'pg'|from 'express'|require\(/);
  assert.doesNotMatch(kod, /process\.env/,
    'saf modül ortamı doğrudan okuyor — test ayarı enjekte edilemez hale gelir');
});

test('docker-compose.yml — api ve db log boyut sınırı (C2)', () => {
  const yml = fs.readFileSync(path.join(KOK, 'docker-compose.yml'), 'utf8');
  const maxSize = (yml.match(/max-size:/g) || []).length;
  assert.ok(maxSize >= 2, 'iki servis için de max-size tanımlı değil (sınırsız log = disk tuzağı)');
  assert.match(yml, /max-file:/);
});
