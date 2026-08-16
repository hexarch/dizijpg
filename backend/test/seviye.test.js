// MİNİ SEVİYE SİSTEMİ (istek md. 29) — `node --test test/*.test.js`
//
// 14 AĞU REVİZYONU: "seviye sistemi kalsın ama 7/8 gibi yazma; bir seviye
// sistemimiz olsun, ona göre artsın seviyesi."
//  · UNVANLAR KALKTI (meraklı/hevesli/…/ultra mega) — bu dosyadaki unvan
//    testleri (ad tekilliği, aşağılayıcı sözcük taraması, "üç örnek unvan
//    tabloda var", "en üst kademe ultra_mega") KALDIRILDI: ortada ad yok.
//    Aşağılamama şartı artık yapısal olarak sağlanıyor — sunucu yalnız bir
//    SAYI gönderiyor.
//  · TAVAN KALKTI — "kademe sayısı 6-10" ve "en üst kademede sonraki_esik
//    null" testleri, yerlerini TAVANSIZLIK ve GERİLEME YOK testlerine
//    bıraktı.
//  · `kod`/`toplam`/`sonraki_kod` alanları kalktı; sözleşme testleri buna
//    göre daraltıldı (açık görünümde artık YALNIZ `kademe` var).
//
// BU DOSYANIN KİLİTLEDİĞİ KARARLAR:
//
//  1) İKİNCİ SAYAÇ SİSTEMİ YOK. Seviye `rozetleriHesapla`nın ZATEN attığı
//     sorgunun sayaçlarından türer; yeni tablo/sütun açılmadı. Uç
//     `{ rozetler, seviye }` döndürür — iki kaynak ayrışamaz.
//  2) HESAP SUNUCUDA VE SAF. `seviyePuani`/`seviyeEsigi`/`seviyeKademesi`
//     yalnız sayı alır; ağ, saat, rastgelelik yok.
//  3) EĞRİ TAVANSIZ AMA TAŞMAZ: `esik(n) = 14·(n−1)³`. Kademe sonsuza dek
//     artar, çok yüksek puanda bile sonlu ve makul bir sayı üretir, hesap
//     sınırlı adımda biter (sonsuz döngü yok).
//  4) KİMSE SEVİYE KAYBETMEZ. Eski 8 kademenin HER eşiğinde yeni kademe
//     eski kademeden küçük DEĞİL. Eski eğri de yeni eğri de puana göre
//     azalmayan basamak fonksiyonu olduğundan bu, aradaki TÜM puanlar için
//     gerilemenin imkânsız olduğunu kanıtlar.
//  5) UTANDIRMAMA — 1. KADEME BAŞKASINA GİTMEZ. `seviyeAcikGorunum` null
//     döndürür; ziyaretçi "en alt seviye" yazısı değil HİÇBİR ŞEY görür.
//  6) MD. 21 UYUMU. `izlenenler_gizli` açıkken seviye açık profilde HİÇ
//     görünmez (puanın baskın bileşeni izleme sayaçları).
//  7) İLERLEME VERİSİ SIZMAZ. Açık görünümde `puan`/`esik`/`sonraki_esik`
//     YOKTUR — ilerleme çubuğu başkasının profilinde çizilemez.
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

const seviyePuani = alan(['seviyePuani'], 'seviyePuani');
const seviyeEsigi = alan(['SEVIYE_KATSAYISI', 'seviyeEsigi'], 'seviyeEsigi');
const seviyeKademesi = alan(
  ['SEVIYE_KATSAYISI', 'seviyeEsigi', 'seviyeKademesi'], 'seviyeKademesi');
const seviyeHesapla = alan(
  ['SEVIYE_KATSAYISI', 'seviyeEsigi', 'seviyeKademesi', 'seviyePuani', 'seviyeHesapla'],
  'seviyeHesapla');
const seviyeAcikGorunum = alan(['seviyeAcikGorunum'], 'seviyeAcikGorunum');

/** `rozetleriHesapla`nın sorgusunun döndürdüğü satırın tam şekli. */
const sayac = (o = {}) => ({
  bolum: 0, film: 0, yorum: 0, puan: 0,
  takipci: 0, bitirilen: 0, begeni_alinan: 0, ...o,
});

/** 14 Ağu'dan ÖNCEKİ 8 kademenin eşikleri — gerileme kilidi bunlara bakar. */
const ESKI_ESIKLER = [0, 30, 120, 400, 1000, 2500, 6000, 12000];

// ===========================================================================
// 1. EŞİK EĞRİSİ — saf, kesin artan, TAVANSIZ
// ===========================================================================

test('1. kademenin eşiği 0 — sıfır veriyle de bir seviyen olur', () => {
  assert.equal(seviyeEsigi(1), 0);
});

test('eşikler KESİN ARTAN (eşitlik olsa bir kademe erişilemez olurdu)', () => {
  for (let n = 1; n < 500; n++) {
    assert.ok(seviyeEsigi(n + 1) > seviyeEsigi(n),
      `esik(${n + 1}) > esik(${n}) değil`);
  }
});

test('eşikler TAM SAYI — "1249,5 puan" diye bir hedef gösterilemez', () => {
  for (let n = 1; n <= 200; n++) {
    assert.ok(Number.isSafeInteger(seviyeEsigi(n)), `esik(${n}) tam sayı değil`);
  }
});

test('İLK KADEMELER ÇABUK: 2. seviye 14 puan (14 bölüm / 7 film)', () => {
  assert.equal(seviyeEsigi(2), 14);
  assert.equal(seviyeKademesi(14), 2);
  assert.equal(seviyeHesapla(sayac({ bolum: 14 })).kademe, 2);
  assert.equal(seviyeHesapla(sayac({ film: 7 })).kademe, 2);
  // İlk üç kademe, ilk gerçek kullanım oturumunun menzilinde.
  assert.ok(seviyeEsigi(3) <= 150, `3. kademe çok uzak: ${seviyeEsigi(3)}`);
});

test('SONRA YAVAŞLAR: kademeler arası fark her adımda BÜYÜR', () => {
  for (let n = 2; n < 300; n++) {
    const oncekiFark = seviyeEsigi(n) - seviyeEsigi(n - 1);
    const fark = seviyeEsigi(n + 1) - seviyeEsigi(n);
    assert.ok(fark > oncekiFark, `${n}. kademede eğri dikleşmiyor`);
  }
});

test('AMA DURMAZ: her puanın üstünde ulaşılabilir bir kademe var', () => {
  // Tavansızlığın işlemsel tanımı: puan büyüdükçe kademe de büyümeye devam
  // eder — eski tablodaki gibi 8'de takılıp kalmaz.
  for (const p of [12_000, 50_000, 250_000, 1_000_000, 50_000_000]) {
    assert.ok(seviyeKademesi(p * 10) > seviyeKademesi(p),
      `${p} puandan sonra seviye artmıyor — tavan var`);
  }
});

// ===========================================================================
// 2. KADEME HESABI — eşiğin tersi, sınırda kesin
// ===========================================================================

test('MONOTON: puan arttıkça kademe asla düşmez (0..200.000 taranır)', () => {
  let onceki = 1;
  for (let p = 0; p <= 200_000; p++) {
    const n = seviyeKademesi(p);
    assert.ok(n >= onceki, `puan ${p}: kademe ${onceki} → ${n} düştü`);
    onceki = n;
  }
});

test('TANIM: esik(n) ≤ puan < esik(n+1) — her eşikte ve bir eksiğinde', () => {
  for (let n = 1; n <= 300; n++) {
    const esik = seviyeEsigi(n);
    assert.equal(seviyeKademesi(esik), n, `eşikte (${esik}) kademe yanlış`);
    if (n > 1) {
      assert.equal(seviyeKademesi(esik - 1), n - 1,
        `eşiğin 1 altında (${esik - 1}) yükselmiş`);
    }
    assert.equal(seviyeKademesi(esik + 1), n);
  }
});

test('0 puan geçerli: 1. kademe (çökme yok, negatif kademe yok)', () => {
  assert.equal(seviyeKademesi(0), 1);
  assert.equal(seviyeHesapla(sayac()).kademe, 1);
});

test('ÇOK YÜKSEK PUAN: sonlu, makul, taşmayan bir sayı', () => {
  // Gerçekçi tavan: 14.814 bölüm izleyen kullanıcımız ~18.400 puanda.
  // Buradaki değerler onun 500 katına kadar çıkıyor.
  for (const p of [1e6, 1e9, 1e12, Number.MAX_SAFE_INTEGER]) {
    const n = seviyeKademesi(p);
    assert.ok(Number.isSafeInteger(n), `${p} puanda kademe tam sayı değil: ${n}`);
    assert.ok(n > 1 && n < 1e6, `${p} puanda saçma kademe: ${n}`);
    assert.ok(seviyeEsigi(n) <= p, `${p} puanda kademe fazla yüksek`);
  }
  // Sonsuz/çöp girdi çökertmez, döngüye sokmaz.
  assert.equal(seviyeKademesi(Infinity), 1);
  assert.equal(seviyeKademesi(NaN), 1);
  assert.equal(seviyeKademesi(-5), 1);
  assert.equal(seviyeKademesi('abc'), 1);
});

test('SAF: aynı girdi aynı sonucu verir, girdiyi DEĞİŞTİRMEZ', () => {
  const s = sayac({ bolum: 137, yorum: 4 });
  const kopya = { ...s };
  assert.deepEqual(seviyeHesapla(s), seviyeHesapla(s));
  assert.deepEqual(s, kopya, 'seviyeHesapla girdiyi kirletti');
});

// ===========================================================================
// 3. GERİLEME YOK — kimse seviye kaybetmeyecek
// ===========================================================================

test('GERİLEME YOK: eski 8 kademenin HER eşiğinde yeni kademe ≥ eski', () => {
  // Kullanıcının en sert kısıtı. Eski tablo: 0/30/120/400/1000/2500/6000/12000.
  ESKI_ESIKLER.forEach((esik, i) => {
    const eskiKademe = i + 1;
    const yeni = seviyeKademesi(esik);
    assert.ok(yeni >= eskiKademe,
      `${esik} puan: eski ${eskiKademe} → yeni ${yeni} (DÜŞÜŞ)`);
  });
});

test('GERİLEME YOK: eşikler arasındaki HER puan için de geçerli', () => {
  // Yukarıdaki eşik testi matematiksel olarak yeterli (iki fonksiyon da
  // azalmayan), ama kanıtı elle de yürütüyoruz: eski tablonun kapsadığı
  // aralıkta tek tek karşılaştırma.
  const eskiKademe = (p) => {
    let i = 0;
    while (i + 1 < ESKI_ESIKLER.length && p >= ESKI_ESIKLER[i + 1]) i++;
    return i + 1;
  };
  for (let p = 0; p <= 60_000; p++) {
    assert.ok(seviyeKademesi(p) >= eskiKademe(p),
      `${p} puan: eski ${eskiKademe(p)} → yeni ${seviyeKademesi(p)}`);
  }
});

test('CANLI DAĞILIM (14 Ağu, 142 kullanıcı): tek bir hesap bile düşmüyor', () => {
  // Canlı veritabanından YALNIZ OKUMA ile çıkarılan GERÇEK puanlar
  // (rozetleriHesapla sorgusunun tüm kullanıcılar için hâli; sorgu
  //  scratchpad'de, veriye dokunulmadı). Puanı 0 olan 94 hesap listede yok:
  //  hepsi eskiden de yeniden de 1. kademe. [puan, eski kademe]:
  const CANLI = [
    [18429, 8], [17022, 8], [8866, 7], [8486, 7], [7233, 7], [6843, 7],
    [1496, 5], [1107, 5], [934, 4], [871, 4], [309, 3], [292, 3], [249, 3],
    [149, 3], [112, 2], [104, 2], [94, 2], [94, 2], [84, 2], [76, 2],
    [72, 2], [69, 2], [64, 2], [44, 2], [43, 2], [33, 2], [31, 2], [27, 1],
    [25, 1], [25, 1], [23, 1], [18, 1], [16, 1], [13, 1], [10, 1], [10, 1],
    [7, 1], [7, 1], [7, 1], [6, 1], [3, 1], [3, 1], [2, 1], [2, 1], [2, 1],
    [2, 1], [2, 1], [1, 1],
  ];
  assert.equal(CANLI.length, 48, 'canlı örneklem eksik');
  let dusen = 0;
  for (const [puan, eski] of CANLI) {
    if (seviyeKademesi(puan) < eski) dusen++;
  }
  assert.equal(dusen, 0, 'canlı veride seviye kaybeden kullanıcı var');
  // En çok izleyen iki hesap 8 → 11; kimse aynı kalmaktan kötüsünü görmüyor.
  assert.equal(seviyeKademesi(18429), 11);
  assert.equal(seviyeKademesi(17022), 11);
  assert.equal(seviyeKademesi(0), 1);
});

// ===========================================================================
// 4. PUAN FORMÜLÜ — mevcut sayaçlardan türer, popülerliği SAYMAZ (DEĞİŞMEDİ)
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
  // İkisi de kullanıcının denetiminde değil. Seviyeyi bunlara bağlamak,
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
// 5. KAYDIN ŞEKLİ — salt sayı; unvan/kesir alanı YOK
// ===========================================================================

test('kayıt YALNIZ kademe/puan/esik/sonraki_esik taşır (kod, toplam GİTTİ)', () => {
  const sv = seviyeHesapla(sayac({ bolum: 500 }));
  assert.deepEqual(Object.keys(sv).sort(),
    ['esik', 'kademe', 'puan', 'sonraki_esik']);
  for (const eskiAlan of ['kod', 'toplam', 'sonraki_kod']) {
    assert.ok(!(eskiAlan in sv), `kaldırılan alan hâlâ gönderiliyor: ${eskiAlan}`);
  }
});

test('TAVAN YOK: sonraki_esik HER kademede dolu (ilerleme çubuğu hep çizilir)', () => {
  for (const p of [0, 13, 14, 12_000, 1_000_000]) {
    const sv = seviyeHesapla(sayac({ bolum: p }));
    assert.ok(Number.isSafeInteger(sv.sonraki_esik) && sv.sonraki_esik > sv.esik,
      `${p} puanda sonraki_esik yok — "en üst seviye" durumu geri gelmiş`);
  }
});

test('esik ≤ puan < sonraki_esik (ilerleme oranı 0..1 arasında kalır)', () => {
  for (const p of [0, 1, 13, 14, 111, 112, 5000, 18_429]) {
    const sv = seviyeHesapla(sayac({ bolum: p }));
    assert.ok(sv.esik <= sv.puan, `${p}: esik > puan`);
    assert.ok(sv.puan < sv.sonraki_esik, `${p}: puan >= sonraki_esik`);
  }
});

test('yeni kullanıcı 1. kademede ve ilerleme çubuğu ÇİZİLEBİLİR', () => {
  const sv = seviyeHesapla(sayac());
  assert.equal(sv.kademe, 1);
  assert.equal(sv.puan, 0);
  assert.equal(sv.esik, 0);
  assert.ok(sv.sonraki_esik > 0, 'ilk kademede sonraki eşik yok — ilerleme çizilemez');
});

// ===========================================================================
// 6. AÇIK GÖRÜNÜM — utandırmama + md. 21 gizliliği
// ===========================================================================

test('UTANDIRMAMA: 1. kademe BAŞKASINA gösterilmez (null)', () => {
  assert.equal(seviyeAcikGorunum(seviyeHesapla(sayac()), false), null);
  assert.equal(seviyeAcikGorunum(seviyeHesapla(sayac({ bolum: 1 })), false), null);
  // Eşiğin bir altı hâlâ 1. kademe → hâlâ gizli.
  assert.equal(seviyeAcikGorunum(seviyeHesapla(sayac({ bolum: 13 })), false), null);
});

test('2. kademeden itibaren seviye açık profilde görünür', () => {
  const sv = seviyeHesapla(sayac({ bolum: seviyeEsigi(2) }));
  const acik = seviyeAcikGorunum(sv, false);
  assert.ok(acik, '2. kademede seviye gizlenmiş');
  assert.equal(acik.kademe, 2);
});

test('MD. 21: izlenenler_gizli açıkken seviye HİÇ gitmez (yüksek kademede bile)', () => {
  const sv = seviyeHesapla(sayac({ bolum: 50_000 }));
  assert.ok(sv.kademe > 10);
  assert.equal(seviyeAcikGorunum(sv, true), null);
});

test('AÇIK GÖRÜNÜMDE İLERLEME VERİSİ YOK — puan/eşik sızmaz', () => {
  const sv = seviyeHesapla(sayac({ bolum: 3_333, yorum: 12 }));
  const acik = seviyeAcikGorunum(sv, false);
  assert.deepEqual(Object.keys(acik), ['kademe']);
  for (const alan_ of ['puan', 'esik', 'sonraki_esik', 'kod', 'toplam']) {
    assert.ok(!(alan_ in acik), `açık profile ${alan_} sızıyor`);
  }
});

test('seviyeAcikGorunum null/eksik kayda dayanır', () => {
  assert.equal(seviyeAcikGorunum(null, false), null);
  assert.equal(seviyeAcikGorunum(undefined, false), null);
});

// ===========================================================================
// 7. UÇLAR — kaynak sözleşmesi
// ===========================================================================

const ROZETLERI_HESAPLA = bildirimCek('rozetleriHesapla');

test('rozetleriHesapla { rozetler, seviye } döner — TEK sorgu, TEK kaynak', () => {
  assert.match(ROZETLERI_HESAPLA, /seviye:\s*SEVIYE_ACIK \? seviyeHesapla\(s\) : null/);
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
  assert.match(PROFIL, /SEVIYE_ACIK/);
  assert.match(PROFIL, /rozetSeviye\.seviye/);
  assert.match(PROFIL,
    /seviyeAcikGorunum\(rozetSeviye\.seviye, izlenenlerGizli\)/);
  assert.match(PROFIL, /\n\s*seviye,\n/);
});

test('SEVIYE_ACIK false: uçlar seviye göndermez (şimdilik kapalı)', () => {
  assert.match(KAYNAK, /const SEVIYE_ACIK = false/);
  assert.match(ROZETLERI_HESAPLA, /SEVIYE_ACIK \? seviyeHesapla\(s\) : null/);
  assert.match(PROFIL, /!SEVIYE_ACIK/);
});

test('/profil: ENGELLİ profilde seviye null döner', () => {
  // Engel dalı "içerik tamamen düşer" diyor; seviye de izleme hacminden türer.
  const engelDali = /return res\.json\(\{[\s\S]*?\}\);/.exec(PROFIL);
  assert.ok(engelDali, 'engel dalı bulunamadı');
  assert.match(engelDali[0], /seviye: null/);
});

test('UNVAN TABLOSU KAYNAKTAN SİLİNDİ (ekranda hiçbir yerde görünmesin)', () => {
  assert.ok(!/SEVIYE_KADEMELERI/.test(KAYNAK), 'eski kademe tablosu duruyor');
  for (const kod of ['merakli', 'hevesli', 'kidemli', 'profesor', 'ultra_mega']) {
    assert.ok(!new RegExp(`'${kod}'`).test(KAYNAK), `unvan kodu kalmış: ${kod}`);
  }
});
