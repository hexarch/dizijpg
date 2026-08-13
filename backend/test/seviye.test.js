// MİNİ SEVİYE SİSTEMİ (istek md. 29) — `node --test test/*.test.js`
//
// "Amatör izleyici → profesör izleyici → ultra mega izleyici gibi unvanlar.
//  Unvanları BİZ koyacağız (kullanıcı seçmeyecek)."
// Maddenin notu: "Eşikler kullanıcıyı UTANDIRMAMALI — düşük seviyeyi
// başkasına göstermek caydırıcı olabilir; md. 21'deki gizleme tercihleriyle
// uyumlu düşünülmeli."
//
// BU DOSYANIN KİLİTLEDİĞİ BEŞ KARAR:
//
//  1) İKİNCİ SAYAÇ SİSTEMİ YOK. Seviye `rozetleriHesapla`nın ZATEN attığı
//     sorgunun sayaçlarından türer; yeni tablo/sütun açılmadı. Uç
//     `{ rozetler, seviye }` döndürür — iki kaynak ayrışamaz.
//  2) HESAP SUNUCUDA VE SAF. `seviyeHesapla` yalnız sayaç nesnesi alır;
//     ağ, saat, rastgelelik yok. Aşağıdaki sınır testleri her kademenin
//     alt sınırını ve bir eksiğini tek tek dener.
//  3) UTANDIRMAMA — 1. KADEME BAŞKASINA GİTMEZ. `seviyeAcikGorunum` null
//     döndürür; ziyaretçi "en alt seviye" yazısı değil HİÇBİR ŞEY görür.
//     Kişi kendi profilinde unvanını görmeye devam eder.
//  4) MD. 21 UYUMU. `izlenenler_gizli` açıkken unvan açık profilde HİÇ
//     görünmez: puanın baskın bileşeni izleme sayaçları, yani unvan
//     gizlenen kütüphanenin boyutunu ele verir (`IZLEME_ROZETLERI`
//     gerekçesinin aynısı). AYRI `seviye_gizli` sütunu AÇILMADI.
//  5) İLERLEME VERİSİ SIZMAZ. Açık görünümde `puan`/`esik`/`sonraki_esik`
//     alanları YOKTUR — ilerleme çubuğu başkasının profilinde çizilemez.
//
// YÖNTEM: `server.js` içe aktarılamıyor (modül yüklenir yüklenmez
// `app.listen` çağırıyor). Bildirimler KAYNAKTAN ÇEKİLİP GERÇEKTEN
// ÇALIŞTIRILIYOR — kopyası değil, canlıdaki kod sınanıyor.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const oku = (a) => fs.readFileSync(path.join(KOK, a), 'utf8');

const KAYNAK = oku('server.js');
const SEMA = oku('sema.sql');

// ---------------------------------------------------------------------------
// Kaynaktan kod çekme (gizlilik_secenekleri.test.js'teki kalıp)
// ---------------------------------------------------------------------------
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

function bildirimCek(ad) {
  const m = new RegExp(`^(async function|function|const) ${ad}\\b`, 'm').exec(KAYNAK);
  assert.ok(m, `server.js içinde ${ad} bildirimi bulunamadı`);
  if (m[1] === 'const') {
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

function alan(adlar, ifade) {
  // eslint-disable-next-line no-new-func
  return new Function(`${adlar.map(bildirimCek).join('\n')}\nreturn (${ifade});`)();
}

const SEVIYE_KADEMELERI = alan(['SEVIYE_KADEMELERI'], 'SEVIYE_KADEMELERI');
const seviyePuani = alan(['seviyePuani'], 'seviyePuani');
const seviyeHesapla = alan(
  ['SEVIYE_KADEMELERI', 'seviyePuani', 'seviyeHesapla'], 'seviyeHesapla');
const seviyeAcikGorunum = alan(['seviyeAcikGorunum'], 'seviyeAcikGorunum');

/** `rozetleriHesapla`nın sorgusunun döndürdüğü satırın tam şekli. */
const sayac = (o = {}) => ({
  bolum: 0, film: 0, yorum: 0, puan: 0,
  takipci: 0, bitirilen: 0, begeni_alinan: 0, ...o,
});

// ===========================================================================
// 1. KADEME TABLOSU — 6-10 kademe, eşikler kesin artan, ilki 0
// ===========================================================================

test('kademe sayısı 6-10 aralığında', () => {
  assert.ok(SEVIYE_KADEMELERI.length >= 6 && SEVIYE_KADEMELERI.length <= 10,
    `beklenen 6-10, bulunan ${SEVIYE_KADEMELERI.length}`);
});

test('ilk kademenin eşiği 0 — sıfır veriyle de bir unvanın olur', () => {
  assert.equal(SEVIYE_KADEMELERI[0].esik, 0);
});

test('eşikler KESİN ARTAN — eşitlik bile olsa bir kademe erişilemez olurdu', () => {
  for (let i = 1; i < SEVIYE_KADEMELERI.length; i++) {
    assert.ok(SEVIYE_KADEMELERI[i].esik > SEVIYE_KADEMELERI[i - 1].esik,
      `${SEVIYE_KADEMELERI[i].kod} eşiği bir öncekinden büyük değil`);
  }
});

test('kodlar tekil ve dilden bağımsız (küçük harf + alt çizgi)', () => {
  const kodlar = SEVIYE_KADEMELERI.map((k) => k.kod);
  assert.equal(new Set(kodlar).size, kodlar.length, 'yinelenen kod var');
  for (const k of kodlar) assert.match(k, /^[a-z][a-z0-9_]*$/, `kod dile sızmış: ${k}`);
});

test('UTANDIRMAMA: hiçbir kademe kodu aşağılayıcı bir sözcük taşımaz', () => {
  // Maddenin şartı. Kod listesi Türkçe etiketin kaynağıdır
  // (app/lib/seviye.dart), o yüzden yasak sözcük burada da tutulur.
  const YASAK = ['acemi', 'caylak', 'toy', 'ezik', 'zayif', 'kotu', 'aptal',
    'cahil', 'beceriksiz', 'tembel', 'sifir', 'hicbir', 'bos'];
  for (const { kod } of SEVIYE_KADEMELERI) {
    for (const y of YASAK) {
      assert.ok(!kod.includes(y), `aşağılayıcı kademe kodu: ${kod} (${y})`);
    }
  }
});

test('kullanıcının verdiği üç örnek unvan tabloda karşılık buluyor', () => {
  const kodlar = SEVIYE_KADEMELERI.map((k) => k.kod);
  for (const k of ['amator', 'profesor', 'ultra_mega']) {
    assert.ok(kodlar.includes(k), `istekteki örnek unvan yok: ${k}`);
  }
  // "ultra mega" EN ÜST kademe olmalı — istekteki sıralamanın sonu.
  assert.equal(SEVIYE_KADEMELERI[SEVIYE_KADEMELERI.length - 1].kod, 'ultra_mega');
});

// ===========================================================================
// 2. PUAN FORMÜLÜ — mevcut sayaçlardan türer, popülerliği SAYMAZ
// ===========================================================================

test('yeni kullanıcı: tüm sayaçlar 0 → puan 0', () => {
  assert.equal(seviyePuani(sayac()), 0);
});

test('formül ağırlıkları: bölüm ×1, film ×2, bitirilen ×5, yorum ×3, puan ×2', () => {
  assert.equal(seviyePuani(sayac({ bolum: 1 })), 1);
  assert.equal(seviyePuani(sayac({ film: 1 })), 2);
  assert.equal(seviyePuani(sayac({ bitirilen: 1 })), 5);
  assert.equal(seviyePuani(sayac({ yorum: 1 })), 3);
  assert.equal(seviyePuani(sayac({ puan: 1 })), 2);
  // Bileşik: 100 bölüm + 10 film + 2 bitirilen + 4 yorum + 6 puan
  assert.equal(
    seviyePuani(sayac({ bolum: 100, film: 10, bitirilen: 2, yorum: 4, puan: 6 })),
    100 + 20 + 10 + 12 + 12);
});

test('TAKİPÇİ VE ALINAN BEĞENİ SEVİYEYİ DEĞİŞTİRMEZ (popülerlik ölçmüyoruz)', () => {
  // İkisi de kullanıcının denetiminde değil. Unvanı bunlara bağlamak,
  // "utandırmasın" şartının tam tersi olurdu.
  const sade = seviyePuani(sayac({ bolum: 50 }));
  const unlu = seviyePuani(sayac({ bolum: 50, takipci: 10_000, begeni_alinan: 9_999 }));
  assert.equal(unlu, sade);
});

test('yalnız film izleyen biri de ilerler (bölüm tek ölçüt değil)', () => {
  assert.ok(seviyeHesapla(sayac({ film: 60 })).kademe >= 2,
    '60 film izleyen hâlâ 1. kademedeyse formül film izleyicisini cezalandırıyor');
});

test('bozuk/eksik sayaç puanı çökertmez, negatife düşürmez', () => {
  assert.equal(seviyePuani({}), 0);
  assert.equal(seviyePuani(null), 0);
  assert.equal(seviyePuani(sayac({ bolum: -5, film: null, yorum: 'x' })), 0);
  // pg bazı sürümlerde count'u string döndürebilir — sayıya çevrilmeli.
  assert.equal(seviyePuani(sayac({ bolum: '7' })), 7);
});

// ===========================================================================
// 3. SINIRLAR — her kademenin ALT SINIRI ve BİR EKSİĞİ
// ===========================================================================

test('her kademenin ALT SINIRINDA o kademe, BİR EKSİĞİNDE bir önceki', () => {
  for (let i = 0; i < SEVIYE_KADEMELERI.length; i++) {
    const { kod, esik } = SEVIYE_KADEMELERI[i];
    // Puan bire bir bölüm sayısıyla üretilir (bölüm ×1) — sınır tam denenir.
    const tam = seviyeHesapla(sayac({ bolum: esik }));
    assert.equal(tam.kademe, i + 1, `${kod}: eşikte (${esik}) kademe yanlış`);
    assert.equal(tam.kod, kod, `${kod}: eşikte kod yanlış`);
    if (i > 0) {
      const eksik = seviyeHesapla(sayac({ bolum: esik - 1 }));
      assert.equal(eksik.kademe, i, `${kod}: eşiğin 1 altında (${esik - 1}) yükselmiş`);
      assert.equal(eksik.kod, SEVIYE_KADEMELERI[i - 1].kod);
    }
  }
});

test('yeni kullanıcı EN ALT kademede ve unvanı vardır (boş değil)', () => {
  const sv = seviyeHesapla(sayac());
  assert.equal(sv.kademe, 1);
  assert.equal(sv.kod, SEVIYE_KADEMELERI[0].kod);
  assert.equal(sv.puan, 0);
  assert.equal(sv.esik, 0);
  assert.ok(sv.sonraki_esik > 0, 'ilk kademede sonraki eşik yok — ilerleme çizilemez');
});

test('en üst kademede sonraki_esik/sonraki_kod null (ilerleme çubuğu gizlensin)', () => {
  const son = SEVIYE_KADEMELERI[SEVIYE_KADEMELERI.length - 1];
  const sv = seviyeHesapla(sayac({ bolum: son.esik * 10 }));
  assert.equal(sv.kademe, SEVIYE_KADEMELERI.length);
  assert.equal(sv.kod, son.kod);
  assert.equal(sv.sonraki_esik, null);
  assert.equal(sv.sonraki_kod, null);
});

test('sonraki_kod BİR SONRAKİ kademenin kodudur (istemci sırayı bilmez)', () => {
  for (let i = 0; i + 1 < SEVIYE_KADEMELERI.length; i++) {
    const sv = seviyeHesapla(sayac({ bolum: SEVIYE_KADEMELERI[i].esik }));
    assert.equal(sv.sonraki_kod, SEVIYE_KADEMELERI[i + 1].kod);
    assert.equal(sv.sonraki_esik, SEVIYE_KADEMELERI[i + 1].esik);
  }
});

test('kayıt her zaman toplam kademe sayısını taşır (istemci "5/8" yazabilsin)', () => {
  assert.equal(seviyeHesapla(sayac()).toplam, SEVIYE_KADEMELERI.length);
});

test('SAF: aynı sayaç iki çağrıda aynı sonucu verir, girdiyi DEĞİŞTİRMEZ', () => {
  const s = sayac({ bolum: 137, yorum: 4 });
  const kopya = { ...s };
  assert.deepEqual(seviyeHesapla(s), seviyeHesapla(s));
  assert.deepEqual(s, kopya, 'seviyeHesapla girdiyi kirletti');
});

// ===========================================================================
// 4. AÇIK GÖRÜNÜM — utandırmama + md. 21 gizliliği
// ===========================================================================

test('UTANDIRMAMA: 1. kademe BAŞKASINA gösterilmez (null)', () => {
  assert.equal(seviyeAcikGorunum(seviyeHesapla(sayac()), false), null);
  assert.equal(seviyeAcikGorunum(seviyeHesapla(sayac({ bolum: 1 })), false), null);
});

test('2. kademeden itibaren unvan açık profilde görünür', () => {
  const sv = seviyeHesapla(sayac({ bolum: SEVIYE_KADEMELERI[1].esik }));
  const acik = seviyeAcikGorunum(sv, false);
  assert.ok(acik, '2. kademede unvan gizlenmiş');
  assert.equal(acik.kod, SEVIYE_KADEMELERI[1].kod);
  assert.equal(acik.kademe, 2);
});

test('MD. 21: izlenenler_gizli açıkken unvan HİÇ gitmez (en üst kademede bile)', () => {
  const son = SEVIYE_KADEMELERI[SEVIYE_KADEMELERI.length - 1];
  const sv = seviyeHesapla(sayac({ bolum: son.esik }));
  assert.equal(seviyeAcikGorunum(sv, true), null);
});

test('AÇIK GÖRÜNÜMDE İLERLEME VERİSİ YOK — puan/eşik sızmaz', () => {
  const sv = seviyeHesapla(sayac({ bolum: 3_333, yorum: 12 }));
  const acik = seviyeAcikGorunum(sv, false);
  assert.deepEqual(Object.keys(acik).sort(), ['kademe', 'kod', 'toplam']);
  for (const alan_ of ['puan', 'esik', 'sonraki_esik', 'sonraki_kod']) {
    assert.ok(!(alan_ in acik), `açık profile ${alan_} sızıyor`);
  }
});

test('seviyeAcikGorunum null/eksik kayda dayanır', () => {
  assert.equal(seviyeAcikGorunum(null, false), null);
  assert.equal(seviyeAcikGorunum(undefined, false), null);
});

// ===========================================================================
// 5. UÇLAR — kaynak sözleşmesi
// ===========================================================================

const ROZETLERI_HESAPLA = bildirimCek('rozetleriHesapla');

test('rozetleriHesapla { rozetler, seviye } döner — TEK sorgu, TEK kaynak', () => {
  assert.match(ROZETLERI_HESAPLA, /seviye:\s*seviyeHesapla\(s\)/);
  assert.match(ROZETLERI_HESAPLA, /rozetler:\s*tanimlar\.map/);
});

test('YENİ TABLO/SÜTUN AÇILMADI: şemada seviye/unvan sütunu yok', () => {
  // Maddenin şartı: "mevcut sayaçlardan türesin, yeni tablo AÇMA."
  // Yalnız KOMUT satırları taranır; şemanın gerekçe yorumlarında "tek seviye
  // iş parçacığı" gibi masum kullanımlar var.
  const komutlar = SEMA.split('\n')
    .filter((satir) => !satir.trim().startsWith('--')).join('\n');
  assert.ok(!/\bseviye\w*\b/i.test(komutlar), 'sema.sql içinde seviye sütunu belirmiş');
  assert.ok(!/\bunvan\w*\b/i.test(komutlar), 'sema.sql içinde unvan sütunu belirmiş');
  assert.ok(!/seviye_gizli/i.test(SEMA), 'seviye_gizli sütunu açılmış — md. 21 '
    + 'anahtarı (izlenenler_gizli) bu ekseni zaten yönetiyor');
});

test('/rozetler ucu kaydın TAMAMINI gönderir (kendi verin, ilerleme çizilebilsin)', () => {
  const uc = /app\.get\('\/rozetler'[\s\S]{0,400}?\}\)\);/.exec(KAYNAK);
  assert.ok(uc, '/rozetler ucu bulunamadı');
  assert.match(uc[0], /res\.json\(await rozetleriHesapla\(req\.kullanici\.id\)\)/);
});

const PROFIL = (() => {
  const ara = "app.get('/profil/:kullaniciAdi'";
  const bas = KAYNAK.indexOf(ara);
  assert.ok(bas >= 0, '/profil ucu bulunamadı');
  return blokAl(KAYNAK, bas + ara.length - 1, '(', ')');
})();

test('/profil: sahibine TAM kayıt, ziyaretçiye SÜZGEÇTEN geçmiş kayıt', () => {
  assert.match(PROFIL,
    /const seviye = benMi\s*\n?\s*\? rozetSeviye\.seviye\s*\n?\s*: seviyeAcikGorunum\(rozetSeviye\.seviye, izlenenlerGizli\)/);
  assert.match(PROFIL, /\n\s*seviye,\n/);
});

test('/profil: ENGELLİ profilde seviye null döner', () => {
  // Engel dalı "içerik tamamen düşer" diyor; unvan da izleme hacminden türer.
  const engelDali = /return res\.json\(\{[\s\S]*?\}\);/.exec(PROFIL);
  assert.ok(engelDali, 'engel dalı bulunamadı');
  assert.match(engelDali[0], /seviye: null/);
});
