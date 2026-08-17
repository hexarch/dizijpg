// Disk eşiği kapısı — davranış + BAĞLANTI testleri.
//
// `medya_imza.test.js` / `arama.test.js` ile aynı iki katman:
//  1) DAVRANIŞ: `disk.js` SAF olduğu için gerçek fonksiyonlar çağrılır; ölçüm
//     enjekte edilir, yani testin doğruladığı karar üretimde çalışan kararın
//     ta kendisidir. Diski doldurmaya gerek yok.
//  2) BAĞLANTI: `server.js` ve `Dockerfile` denetlenir — saf modül doğru olsa
//     bile sunucu onu yanlış yere bağlarsa (ör. express.raw'dan SONRA, ya da
//     yükleme uçlarından birini unutarak) davranış testi bunu göremez.
//     §3.1 bulgusunun kapatıldığını kanıtlayan asıl katman budur.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  VARSAYILAN_ESIK_GB, VARSAYILAN_TTL_MS, DEPO_DOLU_KODU, DEPO_DOLU_MESAJ,
  VARSAYILAN_IP_BAYT_SAAT, BUTCE_PENCERE_MS,
  esikBayt, bosBayt, diskKapisi, govdeUzunlugu, baytButcesi,
} from '../disk.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
const DISK_SRC = fs.readFileSync(path.join(KOK, 'disk.js'), 'utf8');
const DOCKERFILE = fs.readFileSync(path.join(KOK, 'Dockerfile'), 'utf8');

const GB = 1024 ** 3;

/** Sahte statfs: verilen GB kadar KULLANILABİLİR (bavail) alan. */
const statfsYap = (bosGb, uzer = {}) => ({
  bsize: 4096,
  blocks: 20 * GB / 4096,
  bfree: (bosGb + 4) * GB / 4096, // root rezervi: bavail'den DAİMA büyük
  bavail: bosGb * GB / 4096,
  ...uzer,
});

/** Ara katmanı çalıştırıp sonucu döndürür: {gecti, durum, govde}. */
function calistir(katman) {
  const sonuc = { gecti: false, durum: null, govde: null };
  const res = {
    status(k) { sonuc.durum = k; return this; },
    json(g) { sonuc.govde = g; return this; },
  };
  katman({}, res, () => { sonuc.gecti = true; });
  return sonuc;
}

// ===========================================================================
// 1. Eşik okuma
// ===========================================================================

test('esikBayt: varsayılan 10 GB, env yoksa da bilinir', () => {
  assert.equal(esikBayt({}), VARSAYILAN_ESIK_GB * GB);
  assert.equal(esikBayt({ DISK_ESIK_GB: '' }), VARSAYILAN_ESIK_GB * GB);
});

test('esikBayt: geçerli değer okunur, ondalık kabul edilir', () => {
  assert.equal(esikBayt({ DISK_ESIK_GB: '25' }), 25 * GB);
  assert.equal(esikBayt({ DISK_ESIK_GB: ' 2.5 ' }), Math.round(2.5 * GB));
});

test('esikBayt: 0 BİLİNÇLİ kaçış yoludur (kapı devre dışı)', () => {
  assert.equal(esikBayt({ DISK_ESIK_GB: '0' }), 0);
});

test('esikBayt: çöp değer varsayılana düşer — kapı sessizce açılmaz', () => {
  // Bu satırın önemi: `.env`e "10gb" yazan biri kapıyı KAPATMIŞ olmamalı.
  for (const ham of ['abc', '10gb', '-5', 'NaN', 'Infinity']) {
    assert.equal(esikBayt({ DISK_ESIK_GB: ham }), VARSAYILAN_ESIK_GB * GB, ham);
  }
});

// ===========================================================================
// 2. Boş alan hesabı
// ===========================================================================

test('bosBayt: bavail × bsize (bfree DEĞİL — root rezervi sayılmaz)', () => {
  const s = statfsYap(3);
  assert.equal(bosBayt(s), 3 * GB);
  assert.notEqual(bosBayt(s), s.bfree * s.bsize);
});

test('bosBayt: tanınmayan şekil -> null (fail-open sinyali)', () => {
  assert.equal(bosBayt(null), null);
  assert.equal(bosBayt({}), null);
  assert.equal(bosBayt({ bavail: 'x', bsize: 4096 }), null);
});

// ===========================================================================
// 3. Kapı kararı
// ===========================================================================

test('bol alan varken istek GEÇER', () => {
  const k = diskKapisi({ dizin: '/veri', esik: 10 * GB, olc: () => statfsYap(21) });
  assert.equal(calistir(k).gecti, true);
});

test('eşiğin ALTINDA istek 507 + makine kodu ile reddedilir', () => {
  const k = diskKapisi({ dizin: '/veri', esik: 10 * GB, olc: () => statfsYap(3) });
  const s = calistir(k);
  assert.equal(s.gecti, false);
  assert.equal(s.durum, 507);
  assert.equal(s.govde.kod, DEPO_DOLU_KODU);
  assert.equal(s.govde.hata, DEPO_DOLU_MESAJ);
});

test('tam eşikte GEÇER (>=): sınır kullanıcı lehine', () => {
  const k = diskKapisi({ dizin: '/veri', esik: 10 * GB, olc: () => statfsYap(10) });
  assert.equal(calistir(k).gecti, true);
});

test('esik=0 kapıyı tamamen devre dışı bırakır — ölçüm bile yapılmaz', () => {
  let olcum = 0;
  const k = diskKapisi({
    dizin: '/veri', esik: 0, olc: () => { olcum++; return statfsYap(0); },
  });
  assert.equal(calistir(k).gecti, true);
  assert.equal(olcum, 0, 'kapı kapalıyken statfs çağrılmamalı');
});

test('FAIL-OPEN: ölçüm fırlatırsa istek GEÇER', () => {
  // Gerekçe disk.js başında: yanlış "kapat" kararı gerçek kullanıcıların
  // yüklemesini keser; yanlış "geçir" kararı en kötü ihtimalle eski davranış.
  const k = diskKapisi({
    dizin: '/veri', esik: 10 * GB, olc: () => { throw new Error('ENOSYS'); },
  });
  assert.equal(calistir(k).gecti, true);
});

test('FAIL-OPEN: statfs tanınmayan şekil dönerse istek GEÇER', () => {
  const k = diskKapisi({ dizin: '/veri', esik: 10 * GB, olc: () => ({ tuhaf: 1 }) });
  assert.equal(calistir(k).gecti, true);
});

// ===========================================================================
// 4. Önbellek ve uyarı
// ===========================================================================

test('ölçüm TTL boyunca önbellekten okunur, sonra tazelenir', () => {
  let olcum = 0;
  let t = 1_000_000;
  const k = diskKapisi({
    dizin: '/veri',
    esik: 10 * GB,
    ttlMs: 5000,
    simdi: () => t,
    olc: () => { olcum++; return statfsYap(21); },
  });
  calistir(k); calistir(k); calistir(k);
  assert.equal(olcum, 1, 'TTL içinde tek ölçüm olmalı');
  t += 5001;
  calistir(k);
  assert.equal(olcum, 2, 'TTL dolunca yeniden ölçülmeli');
});

test('VARSAYILAN_TTL_MS makul: saldırı hızında kaçak eşiğin içinde kalır', () => {
  // 5 sn'lik pencerede tek işçinin geçirebileceği en fazla bayt, 10 GB'lık
  // eşiğin çok altında. Bu sayı büyütülürse kaçak da büyür.
  assert.ok(VARSAYILAN_TTL_MS > 0 && VARSAYILAN_TTL_MS <= 30_000);
});

test('uyarı eşiğin altına İLK inişte bir kez basılır, düzelince sıfırlanır', () => {
  let bosGb = 3;
  const uyarilar = [];
  const k = diskKapisi({
    dizin: '/veri',
    esik: 10 * GB,
    ttlMs: 0, // her istekte tazele
    olc: () => statfsYap(bosGb),
    uyar: (b) => uyarilar.push(b),
  });
  calistir(k); calistir(k); calistir(k);
  assert.equal(uyarilar.length, 1, 'log her istekte tekrarlanmamalı');
  assert.equal(uyarilar[0].bos, 3 * GB);
  bosGb = 21;
  calistir(k);
  bosGb = 3;
  calistir(k);
  assert.equal(uyarilar.length, 2, 'düzelip yeniden bozulunca tekrar uyarmalı');
});

test('katman.bos() ölçümü dışarı verir (admin paneli okuyor)', () => {
  const k = diskKapisi({ dizin: '/veri', esik: 10 * GB, olc: () => statfsYap(7) });
  assert.equal(k.bos(), 7 * GB);
});

// ===========================================================================
// 5. Saflık
// ===========================================================================

test('disk.js SAF: içe aktarma yan etkisi yok (env/fs/pg/express okumuyor)', () => {
  // Yorumlar ayıklanır (yasak.test.js / arama.test.js ile aynı disiplin):
  // gerekçe metinlerinde `process.env` GEÇEBİLİR, önemli olan KODUN onu
  // okumaması — okusaydı eşik testte enjekte edilemezdi.
  const kod = DISK_SRC.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');
  assert.doesNotMatch(kod, /require\(|from ['"]pg['"]|from ['"]express['"]|from ['"]node:fs['"]/);
  assert.doesNotMatch(kod, /process\.env/,
    'saf modül ortamı doğrudan okuyor — eşik testte enjekte edilemez hale gelir');
  assert.deepEqual(kod.match(/^import .*$/gm) || [], [],
    'disk.js hiçbir şey import etmemeli: ölçüm parametreyle gelir');
  assert.doesNotMatch(kod, /^setInterval|^setTimeout/m);
});

// ===========================================================================
// 6. BAĞLANTI DENETİMLERİ (asıl §3.1 kanıtı)
// ===========================================================================

/**
 * Bir uç bildiriminin başlangıcından `sarici(`ye kadarki ara katman zinciri —
 * YORUMLAR AYIKLANMIŞ olarak.
 *
 * Ayıklama şart ve bunu test kendisi öğretti: `/medya` ucundaki gerekçe
 * yorumu "Disk eşiği express.raw'dan ÖNCE" cümlesini içeriyor. Ham metinde
 * arayınca `express.raw` ilk olarak O YORUMDA görünüyor ve sıra kontrolü
 * KODU doğru olduğu hâlde kırmızıya dönüyordu. Ölçtüğümüz şey kod olmalı.
 */
function zincir(imza) {
  const bas = SERVER.indexOf(imza);
  assert.notEqual(bas, -1, `uç bulunamadı: ${imza}`);
  const son = SERVER.indexOf('sarici(', bas);
  assert.notEqual(son, -1, `sarici bulunamadı: ${imza}`);
  return SERVER.slice(bas, son)
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^\s*\/\/.*$/gm, '');
}

test('POST /medya: disk kapısı express.raw ÖNCESİNDE', () => {
  const z = zincir("app.post('/medya',");
  const kapi = z.indexOf('diskKapi');
  const ham = z.indexOf('express.raw');
  assert.notEqual(kapi, -1, '/medya disk kapısı bağlanmamış — §3.1 açık');
  assert.notEqual(ham, -1);
  assert.ok(kapi < ham,
    'disk kapısı express.raw SONRASINDA: reddedilecek 100 MB gövde yine belleğe alınır');
});

test('POST /veri/ice-aktar: disk kapısı express.raw ÖNCESİNDE', () => {
  const z = zincir("app.post('/veri/ice-aktar',");
  const kapi = z.indexOf('diskKapi');
  const ham = z.indexOf('express.raw');
  assert.notEqual(kapi, -1, 'içe aktarım disk kapısı bağlanmamış');
  assert.ok(kapi < ham, 'disk kapısı express.raw sonrasında');
});

test('avatar/kapak yükleme ucu da disk kapısından geçiyor', () => {
  // `profilResmiUcu` avatar VE kapak uçlarının ORTAK üreticisi: tek yerde
  // bağlanınca ikisi birden korunur, ama unutulursa ikisi birden açık kalır.
  const z = zincir('function profilResmiUcu(sutun)');
  const kapi = z.indexOf('diskKapi');
  const ham = z.indexOf('express.raw');
  assert.notEqual(kapi, -1, 'profil resmi ucu disk kapısına bağlanmamış');
  assert.ok(kapi < ham, 'disk kapısı express.raw sonrasında');
});

test('kapı fs.statfsSync ile GERÇEK dizini ölçüyor', () => {
  assert.match(SERVER, /diskKapisi\(\{[\s\S]*?dizin:\s*MEDYA_DIZIN[\s\S]*?olc:\s*fs\.statfsSync/,
    'kapı yanlış dizini ölçüyor ya da ölçüm bağlanmamış');
});

// ===========================================================================
// 7. IP başına saatlik yükleme baytı bütçesi (§3.1'in kalanı)
// ===========================================================================

/** Content-Length taşıyan sahte istek. */
const istekYap = (uzunluk) => ({
  headers: uzunluk == null ? {} : { 'content-length': String(uzunluk) },
});

function calistirIstek(katman, req) {
  const sonuc = { gecti: false, durum: null, govde: null };
  const res = {
    status(k) { sonuc.durum = k; return this; },
    json(g) { sonuc.govde = g; return this; },
  };
  katman(req, res, () => { sonuc.gecti = true; });
  return sonuc;
}

test('govdeUzunlugu: geçerli Content-Length okunur', () => {
  assert.equal(govdeUzunlugu(istekYap(1234)), 1234);
  assert.equal(govdeUzunlugu(istekYap(0)), 0);
});

test('govdeUzunlugu: yok/bozuk/negatif/ondalık -> null', () => {
  for (const v of [null, 'abc', '-5', '1.5', 'Infinity', '']) {
    assert.equal(govdeUzunlugu(istekYap(v)), null, String(v));
  }
});

test('bütçe içindeki yüklemeler GEÇER, aşınca 429 + makine kodu', () => {
  const k = baytButcesi({ butce: 100, anahtar: () => 'ip' });
  assert.equal(calistirIstek(k, istekYap(60)).gecti, true);
  assert.equal(calistirIstek(k, istekYap(40)).gecti, true, 'tam bütçe geçmeli');
  const s = calistirIstek(k, istekYap(1));
  assert.equal(s.gecti, false);
  assert.equal(s.durum, 429, '507 DEĞİL: bu hız limiti, depo tükenmesi değil');
  assert.equal(s.govde.kod, 'YUKLEME_BUTCESI');
});

test('reddedilen istek bütçeyi TÜKETMEZ (küçük yükleme sonra geçebilir)', () => {
  const k = baytButcesi({ butce: 100, anahtar: () => 'ip' });
  calistirIstek(k, istekYap(90));
  assert.equal(calistirIstek(k, istekYap(50)).gecti, false, 'aşan istek reddedilir');
  // Ret sayacı artırmadıysa 10 baytlık istek hâlâ sığmalı. Artırsaydı
  // saldırgan tek büyük istekle herkesin bütçesini yakabilirdi.
  assert.equal(calistirIstek(k, istekYap(10)).gecti, true);
});

test('Content-Length YOKSA en yüksek ücret kesilir (belirsizlik bütçe lehine)', () => {
  const k = baytButcesi({ butce: 100, anahtar: () => 'ip', bilinmeyen: 100 });
  assert.equal(calistirIstek(k, istekYap(null)).gecti, true);
  assert.equal(calistirIstek(k, istekYap(1)).gecti, false,
    'başlıksız istek bedava geçseydi bütçe chunked ile atlanırdı');
});

test('bütçe IP BAŞINA ayrı tutulur', () => {
  let ip = 'a';
  const k = baytButcesi({ butce: 100, anahtar: () => ip });
  assert.equal(calistirIstek(k, istekYap(100)).gecti, true);
  assert.equal(calistirIstek(k, istekYap(1)).gecti, false);
  ip = 'b';
  assert.equal(calistirIstek(k, istekYap(100)).gecti, true, 'başka IP etkilenmemeli');
});

test('pencere dolunca bütçe tazelenir', () => {
  let t = 1_000_000;
  const k = baytButcesi({
    butce: 100, anahtar: () => 'ip', pencereMs: 1000, simdi: () => t,
  });
  assert.equal(calistirIstek(k, istekYap(100)).gecti, true);
  assert.equal(calistirIstek(k, istekYap(1)).gecti, false);
  t += 1001;
  assert.equal(calistirIstek(k, istekYap(100)).gecti, true);
});

test('butce=0 bütçeyi tamamen kapatır (kırılacak cam)', () => {
  const k = baytButcesi({ butce: 0, anahtar: () => 'ip' });
  assert.equal(calistirIstek(k, istekYap(10 ** 12)).gecti, true);
});

test('varsayılanlar makul: 1 GB/saat, 1 saatlik pencere', () => {
  assert.equal(VARSAYILAN_IP_BAYT_SAAT, 1024 ** 3);
  assert.equal(BUTCE_PENCERE_MS, 3600_000);
});

// ===========================================================================
// 8. Yükleme limitleri BAĞLANTI denetimi
// ===========================================================================

test('bayt bütçesi ÜÇ yükleme ucunda da ve express.raw ÖNCESİNDE', () => {
  for (const imza of [
    "app.post('/medya',",
    "app.post('/veri/ice-aktar',",
    'function profilResmiUcu(sutun)',
  ]) {
    const z = zincir(imza);
    const butce = z.indexOf('yuklemeBaytButcesi');
    const ham = z.indexOf('express.raw');
    assert.notEqual(butce, -1, `${imza} bayt bütçesine bağlanmamış`);
    assert.ok(butce < ham, `${imza}: bütçe express.raw sonrasında`);
  }
});

test('bayt bütçesi İŞÇİ SAYISINA bölünüyor (küme gevşekliği)', () => {
  // CANLI ÖLÇÜM (17 Ağu): bütçe 107 bayta indirilip 6 x 33 bayt yüklendi;
  // 198 > 107 olmasına rağmen ALTISI DA 200 döndü. Sebep: nginx her yeni
  // bağlantıyı başka işçiye veriyor ve her işçinin sayacı ayrı. Bölme
  // olmadan gerçek tavan N katıdır — yani ayarın söylediği sayı YALAN olur.
  assert.match(SERVER, /const ISCI_BUTCE = Math\.floor\(IP_BAYT_BUTCE \/ ISCI_SAYISI\)/,
    'bütçe işçi sayısına bölünmüyor — gerçek tavan N katı olur');
  assert.match(SERVER, /baytButcesi\(\{\s*\n\s*butce: ISCI_BUTCE/,
    'bölünmüş değer kullanılmıyor');
});

test('bayt bütçesi req.ip ile anahtarlanıyor (spoof edilemez)', () => {
  // `gercekIp` ham CF-Connecting-IP/X-Real-IP okur; nginx bunları eziyor ama
  // `req.ip` (trust proxy: 1) tek doğru kaynaktır — hız limitlerinin tamamı
  // bu yüzden req.ip kullanıyor (denetim 2026-08-07 §4.2).
  assert.match(SERVER, /anahtar:\s*\(req\)\s*=>\s*`yb:\$\{req\.ip\}`/,
    'bütçe gercekIp ile anahtarlanmış olabilir — sahte başlıkla tazelenirdi');
});

test('MİSAFİR yükleme sayısı üyeden DÜŞÜK ve ayrı anahtarda', () => {
  // Hesap bedava ve saniyede açılıyor; misafire üyeyle aynı hakkı vermek
  // "sınırsız hesap aç, her biriyle 40 dosya yükle" demekti.
  assert.match(SERVER, /const MISAFIR_YUKLEME_SAAT = (\d+)/);
  const misafir = Number(/const MISAFIR_YUKLEME_SAAT = (\d+)/.exec(SERVER)[1]);
  const uye = Number(/const UYE_YUKLEME_SAAT = (\d+)/.exec(SERVER)[1]);
  assert.ok(misafir < uye, `misafir (${misafir}) üyeden (${uye}) düşük olmalı`);
  assert.match(SERVER, /`ym:\$\{req\.kullanici\.id\}`/,
    'misafir sayacı ayrı önek taşımıyor — bağlanınca sayaç taşınır');
  assert.match(SERVER, /req\.misafir === true \? yuklemeLimitiMisafir : yuklemeLimitiUye/,
    'seçim `req.misafir` üzerinden yapılmıyor');
});

test('KAÇIŞ YOLLARI compose ile konteynere AKTARILIYOR', () => {
  // TURN_SIR tuzağı (docker-compose.yml, 9 Ağu 2026): `.env`de değişken VARDI
  // ama compose onu konteynere aktarmıyordu, kod varsayılana düşüyordu ve ayar
  // SESSİZCE etkisizdi. Bu kapıların kaçış yolları aynı sessiz ölümle
  // kaybolursa, disk dolduğunda ya da bütçe yanlış ayarlandığında müdahale
  // etmenin yolu kalmaz. Test bu yüzden `process.env`den OKUNAN her ayarı
  // compose'da arar — yeni bir ayar eklenip aktarımı unutulursa kırmızıya döner.
  const compose = fs.readFileSync(path.join(KOK, 'docker-compose.yml'), 'utf8');
  // İKİ KAYNAK birden taranır: `IP_BAYT_SAAT_GB` server.js'te `process.env`den
  // okunuyor, `DISK_ESIK_GB` ise disk.js'in `esikBayt(env)` fonksiyonunda
  // (saf modül ortamı doğrudan okumaz, adı yine orada geçer). Yalnız server.js
  // taransaydı ikincisi gözden kaçardı.
  const kaynak = SERVER + DISK_SRC;
  const okunanlar = [...kaynak.matchAll(/\b(DISK_ESIK_GB|IP_BAYT_SAAT_GB)\b/g)]
    .map((m) => m[1]);
  assert.ok(new Set(okunanlar).size === 2,
    `beklenen iki ayar kaynakta bulunamadı: ${[...new Set(okunanlar)]}`);
  for (const ad of new Set(okunanlar)) {
    assert.match(compose, new RegExp(`^\\s*${ad}:\\s*\\$\\{${ad}`, 'm'),
      `${ad} compose api.environment içinde yok — .env'e yazmak etkisiz kalır`);
  }
});

test('disk.js imaja giriyor (Cannot find module ile restart döngüsü tuzağı)', () => {
  const copy = DOCKERFILE.split('\n').find((s) => s.startsWith('COPY server.js'));
  assert.ok(copy, 'COPY server.js satırı bulunamadı');
  assert.ok(/(^|\s)disk\.js(\s|$)/.test(copy),
    'disk.js imaja girmiyor: "Cannot find module ./disk.js" ile restart döngüsü');
});
