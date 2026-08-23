// SSR SÜRE BÜTÇESİ — "Googlebot'a 504 dönme" kararını koruyan testler.
//
// KORUDUĞU OLAY (18 Ağu 2026, nginx error.log):
//   18:45:11 upstream timed out (110: Connection timed out) while reading
//   response header from upstream, client: 66.249.79.129 (Googlebot),
//   request: "GET /kisi/102426", upstream: "http://127.0.0.1:8500/og/kisi/102426"
//   18:46:34 aynısı /kisi/113970 için.
//
// KÖK NEDEN — İKİ SÜRE BİRBİRİNİ TANIMIYORDU:
//   nginx `@og`          : proxy_read_timeout 20 sn
//   tmdbGetir            : 15 sn × 3 deneme + beklemeler = ~46 sn
// TMDB yavaşladığında nginx ÖNCE koptu; ucun `catch` bloğu (yani
// seo_soft404_kayit.test.js'in koruduğu "TMDB arızasında noindex dön"
// disiplini) HİÇ ÇALIŞAMADI. Google 5xx'i "site bozuk" sayar ve tarama
// bütçesini kısar — sitenin zaten en dar kaynağı o.
//
// BU DOSYANIN ASIL İŞİ: iki sürenin birbirini tanımaya DEVAM ettiğini
// doğrulamak. Biri değişip diğeri unutulursa 504 sessizce geri gelir.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { AsyncLocalStorage } from 'node:async_hooks';
import { KAYNAK, KOK, bildirimCek, bolum } from './yardimci/seo_kaynak.js';

// ---------------------------------------------------------------------------
// Kaynaktan ÇEKİLİP GERÇEKTEN ÇALIŞTIRILAN parça.
// `alan()` yerine elle kurulum: `istekBaglam` bildirimi `new AsyncLocalStorage()`
// çağırıyor, yani sanal alana o sınıfın ENJEKTE EDİLMESİ gerekiyor.
// ---------------------------------------------------------------------------
const kur = new Function(
  'AsyncLocalStorage',
  `${bildirimCek('istekBaglam')}\n${bildirimCek('ssrKalanSure')}\n`
  + 'return { istekBaglam, ssrKalanSure };',
);
const { istekBaglam, ssrKalanSure } = kur(AsyncLocalStorage);

/**
 * Bir fonksiyonun TAM gövdesi — `async function` dahil.
 *
 * NEDEN `bildirimCek` DEĞİL: paylaşılan yardımcının deseni
 * `^(const|function) ad\b`, yani `async function tmdbGetir` ile eşleşmiyor.
 * Bu dosyanın sınadığı iki fonksiyondan biri tam olarak öyle tanımlı.
 */
function govdeCek(ad) {
  const m = new RegExp(`^(?:async )?(const|function) ${ad}\\b`, 'm').exec(KAYNAK);
  assert.ok(m, `server.js içinde ${ad} bildirimi bulunamadı`);
  const bas = m.index;
  const fonksiyon = m[1] === 'function';
  let derinlik = 0;
  let girdi = false;
  for (let i = bas; i < KAYNAK.length; i++) {
    const c = KAYNAK[i];
    if (c === '{' || c === '(' || c === '[') { derinlik++; girdi = true; }
    else if (c === '}' || c === ')' || c === ']') {
      derinlik--;
      if (fonksiyon && girdi && derinlik === 0 && c === '}') {
        return KAYNAK.slice(bas, i + 1);
      }
    } else if (!fonksiyon && c === ';' && derinlik === 0) {
      return KAYNAK.slice(bas, i + 1);
    }
  }
  return assert.fail(`${ad} bildiriminin sonu bulunamadı`);
}

/**
 * Satır yorumlarını atar.
 *
 * NEDEN GEREKLİ: bu dosyadaki iddialar KODUN kendisini sınıyor. Yorumlar
 * kodu ANLATTIĞI için içlerinde `res.status(...)` gibi ifadeler geçiyor ve
 * ham metinde arama yapmak yanlış eşleşme veriyor (testin ilk sürümü tam da
 * buna takıldı: guard doğru yerdeydi, yorum yanıltmıştı).
 */
const yorumsuz = (metin) => metin.replace(/^\s*\/\/.*$/gm, '');

/** `const AD = 12000;` bildiriminden sayıyı çeker. */
function sayiSabiti(ad) {
  const m = new RegExp(`const ${ad}\\s*=\\s*(\\d+)`).exec(KAYNAK);
  assert.ok(m, `server.js içinde ${ad} sayı sabiti bulunamadı`);
  return Number(m[1]);
}

const SSR_BUTCE_MS = sayiSabiti('SSR_BUTCE_MS');
const TMDB_ZAMAN_ASIMI_MS = sayiSabiti('TMDB_ZAMAN_ASIMI_MS');

// ===========================================================================
// 1) ssrKalanSure — saf fonksiyon, GERÇEKTEN çalıştırılıyor
// ===========================================================================
test('ssrKalanSure: SSR dışı istekte son tarih YOK → null (sınırsız)', () => {
  // Normal kullanıcı/API isteği bu bütçeye TABİ DEĞİL: orada uzun bir TMDB
  // beklemesi kabul edilebilir, kimse indeksten düşmüyor. null = eski davranış.
  assert.equal(ssrKalanSure(), null);
  istekBaglam.run({ tmdbDil: 'tr-TR', dil: 'tr' }, () => {
    assert.equal(ssrKalanSure(), null,
      'ssrBitis yazılmamış bağlamda da sınırsız olmalı (API uçları etkilenmesin)');
  });
});

test('ssrKalanSure: SSR bağlamında kalan süreyi ms olarak döner', () => {
  istekBaglam.run({ ssrBitis: Date.now() + 5000 }, () => {
    const kalan = ssrKalanSure();
    assert.ok(kalan > 4000 && kalan <= 5000,
      `kalan süre beklenen aralıkta değil: ${kalan}`);
  });
});

test('ssrKalanSure: süre dolduysa <= 0 — tmdbGetir buradan 502 fırlatır', () => {
  istekBaglam.run({ ssrBitis: Date.now() - 1 }, () => {
    assert.ok(ssrKalanSure() <= 0);
  });
});

test('ssrKalanSure: bağlamlar birbirine SIZMAZ (iç içe istek)', () => {
  istekBaglam.run({ ssrBitis: Date.now() + 9000 }, () => {
    assert.ok(ssrKalanSure() > 8000);
    istekBaglam.run({ tmdbDil: 'tr-TR' }, () => {
      assert.equal(ssrKalanSure(), null,
        'iç bağlam son tarihi devralmamalı — API isteği SSR bütçesine düşerdi');
    });
  });
});

// ===========================================================================
// 2) ASIL KİLİT: uygulama bütçesi < nginx zaman aşımı
// ===========================================================================
/** Depodaki EN GÜNCEL nginx site yapılandırması. */
function nginxKaynagi() {
  const adaylar = fs.readdirSync(KOK)
    .filter((d) => /^nginx-dizijpg\.com-\d+\.conf$/.test(d))
    .sort();
  assert.ok(adaylar.length, 'depoda nginx-dizijpg.com-*.conf bulunamadı');
  return fs.readFileSync(path.join(KOK, adaylar[adaylar.length - 1]), 'utf8');
}

test('SSR bütçesi nginx @og zaman aşımından KÜÇÜK (504 kalkanı)', () => {
  const conf = nginxKaynagi();
  // Botların SSR'a girdiği İKİ kapı: @og (tüm yollar) ve @og_ana (kök).
  for (const blok of ['location @og {', 'location @og_ana {']) {
    const i = conf.indexOf(blok);
    assert.notEqual(i, -1, `nginx conf'ta bulunamadı: ${blok}`);
    const govde = conf.slice(i, conf.indexOf('}', i));
    const m = /proxy_read_timeout\s+(\d+)s/.exec(govde);
    assert.ok(m, `${blok} içinde proxy_read_timeout yok`);
    const nginxMs = Number(m[1]) * 1000;
    assert.ok(
      SSR_BUTCE_MS < nginxMs,
      `${blok}: SSR_BUTCE_MS (${SSR_BUTCE_MS}ms) nginx'in ${nginxMs}ms'inden `
      + 'KÜÇÜK OLMALI. Değilse uygulama yanıtı yetiştiremez, nginx 504 basar '
      + 've ucun catch bloğu (noindex dönüşü) hiç çalışamaz.',
    );
    // Marj: yanıtın kurulması (JSON-LD, afiş listesi) + ağ için pay kalmalı.
    assert.ok(
      nginxMs - SSR_BUTCE_MS >= 3000,
      `${blok}: bütçe ile nginx arasında en az 3 sn marj olmalı `
      + `(şu an ${nginxMs - SSR_BUTCE_MS}ms)`,
    );
  }
});

test('Tek TMDB denemesi bile SSR bütçesini TEK BAŞINA aşamaz', () => {
  // Regresyon kilidi: TMDB tavanı bütçeden büyük olsaydı, ilk deneme
  // tek başına bütçeyi yiyip güvenlik ağını tetiklerdi — yani her yavaş
  // istek boş kabuk dönerdi.
  assert.ok(
    TMDB_ZAMAN_ASIMI_MS >= SSR_BUTCE_MS,
    'TMDB tavanı bütçeden küçükse SSR dışı istekler gereksiz yere kısalır',
  );
});

// ===========================================================================
// 3) tmdbGetir son tarihe UYUYOR MU
// ===========================================================================
test('tmdbGetir son tarihi okur ve süre dolunca 502 fırlatır (404 DEĞİL)', () => {
  const govde = yorumsuz(govdeCek('tmdbGetir'));
  assert.match(govde, /ssrKalanSure\(\)/,
    'tmdbGetir son tarihi okumuyor — nginx yine 504 basar');
  // Süre dolduğunda YENİDEN DENEME olmamalı: 502 fırlatılıp catch'e gidilmeli.
  assert.match(
    govde,
    /kalan\s*!==\s*null\s*&&\s*kalan\s*<=\s*0[\s\S]{0,200}status:\s*502/,
    'süre dolduğunda 502 fırlatılmıyor — istek nginx koptuktan sonra da sürer',
  );
  // 502 ŞART: 404 olsaydı geçici arızada var olan sayfa indeksten düşerdi.
  assert.ok(
    !/süre bütçesi doldu[\s\S]{0,80}status:\s*404/.test(govde),
    'süre aşımı 404 ile işaretlenmiş — geçici arıza sayfayı indeksten düşürür',
  );
});

test('tmdbGetir deneme süresi kalan süreyle SINIRLANIR', () => {
  const govde = yorumsuz(govdeCek('tmdbGetir'));
  assert.match(govde, /Math\.min\(TMDB_ZAMAN_ASIMI_MS,\s*kalan\)/,
    'deneme tavanı kalan süreye kırpılmıyor');
  assert.ok(
    !/AbortSignal\.timeout\(\s*15000\s*\)/.test(govde),
    'sabit 15000 sihirli sayısı geri gelmiş — bütçe devre dışı kalır',
  );
  assert.match(govde, /AbortSignal\.timeout\(bekleme\)/,
    'fetch hesaplanan `bekleme` yerine başka bir süre kullanıyor');
});

// ===========================================================================
// 4) /og güvenlik ağı middleware'i
// ===========================================================================
test('/og middleware bütçeyi bağlama yazar ve zamanlayıcıyı TEMİZLER', () => {
  const govde = yorumsuz(bolum("app.use('/og', (req, res, next) => {", 'app.get(\'/og/icerik'));
  assert.match(govde, /baglam\.ssrBitis\s*=\s*Date\.now\(\)\s*\+\s*SSR_BUTCE_MS/,
    'son tarih bağlama yazılmıyor — tmdbGetir bütçeyi göremez');
  assert.match(govde, /clearTimeout\(zamanlayici\)/,
    'zamanlayıcı temizlenmiyor — her bot isteği 12 sn boşta timer tutar');
  assert.match(govde, /res\.on\('close'/,
    'temizlik `close` olayına bağlı değil');
});

test('/og güvenlik ağı noindex KABUK döner — 404 da 5xx de DEĞİL', () => {
  const govde = yorumsuz(bolum("app.use('/og', (req, res, next) => {", 'app.get(\'/og/icerik'));
  assert.match(govde, /indexle:\s*false/,
    'bütçe aşımında indexle:false yok — eksik içerik indekslenir');
  // KRİTİK: durum kodu değiştirilmemeli. res.status(...) çağrısı olmamalı.
  assert.ok(
    !/res\.status\(/.test(govde),
    'güvenlik ağı durum kodunu değiştiriyor — 200 dışı her kod ya soft 404 '
    + 'ya da yeni bir 5xx demektir',
  );
  assert.match(govde, /res\.headersSent/,
    'yanıt zaten gittiyse karışmama kontrolü yok — çift yanıt riski');
});

// ===========================================================================
// 5) sarici: geç gelen hata süreci DÜŞÜRMESİN
// ===========================================================================
test('sarici, yanıt gönderildikten sonra İKİNCİ KEZ yazmaya çalışmaz', () => {
  const govde = yorumsuz(govdeCek('sarici'));
  assert.match(govde, /if \(res\.headersSent\)/,
    'headersSent kontrolü yok: güvenlik ağı yanıtı bastıktan sonra asıl '
    + 'işleyici bitince ERR_HTTP_HEADERS_SENT unhandled rejection olur');
  // Guard, res.status'tan ÖNCE gelmeli — sonra gelirse işe yaramaz.
  assert.ok(
    govde.indexOf('res.headersSent') < govde.indexOf('res.status('),
    'headersSent kontrolü res.status çağrısından SONRA — kalkan etkisiz',
  );
});

// ===========================================================================
// 6) DAVRANIŞSAL KANIT: güvenlik ağı GERÇEKTEN çalıştırılıyor
// ===========================================================================
// Yukarıdaki 4-5. bölüm kaynağın ŞEKLİNİ sınıyor. Burada middleware kaynaktan
// çekilip SAHTE req/res ile ÇALIŞTIRILIYOR: bütçe dolunca ne olduğunu iddia
// etmek yerine GÖRÜYORUZ. ("Kodu okudum, doğru görünüyor" YETMEZ.)
const araKatmanKaynagi = (() => {
  const bas = KAYNAK.indexOf("app.use('/og', (req, res, next) => {");
  assert.notEqual(bas, -1, "kaynakta app.use('/og', ...) bulunamadı");
  const son = KAYNAK.indexOf('\n});', bas);
  assert.notEqual(son, -1, 'middleware kapanışı bulunamadı');
  return KAYNAK.slice(bas + "app.use('/og', ".length, son + 2);
})();

/** Middleware'i enjekte edilmiş bağımlılıklarla kurar. */
function araKatmanKur(butceMs) {
  const ogSayfaKaynak = ['SITE_KOK', 'htmlKacir', 'seoKamuYolu', 'seoKanonikYol', 'kanonikUrl', 'jsonLdGom', 'seoIstDil', 'seoOgYerel', 'ogSayfa']
    .map(bildirimCek).join('\n');
  const kaydedilen = [];
  const fn = new Function(
    'istekBaglam', 'SSR_BUTCE_MS', 'logYaz',
    `${ogSayfaKaynak}\nreturn (${araKatmanKaynagi});`,
  )(istekBaglam, butceMs, (a) => kaydedilen.push(a));
  return { fn, kaydedilen };
}

/** Express `res` taklidi: send/headersSent/close + Cache-Control başlığı. */
function sahteRes() {
  const kapanis = [];
  const kayit = { tip: null, govde: null, kod: 200, basliklar: {} };
  const res = {
    get headersSent() { return kayit.govde !== null; },
    status(k) { kayit.kod = k; return res; },
    type(t) { kayit.tip = t; return res; },
    set(k, v) { kayit.basliklar[String(k).toLowerCase()] = v; return res; },
    setHeader(k, v) { return res.set(k, v); },
    getHeader(k) { return kayit.basliklar[String(k).toLowerCase()]; },
    send(g) {
      assert.equal(kayit.govde, null, 'ÇİFT YANIT: res.send iki kez çağrıldı');
      kayit.govde = g;
      return res;
    },
    on(olay, cb) { if (olay === 'close') kapanis.push(cb); return res; },
    kapat() { kapanis.forEach((cb) => cb()); },
  };
  return { res, kayit };
}

test('DAVRANIŞ: bütçe dolunca 200 + noindex kabuk basılır (5xx DEĞİL)', async () => {
  const { fn, kaydedilen } = araKatmanKur(30);
  const { res, kayit } = sahteRes();
  const req = { originalUrl: '/og/kisi/102426' };

  await istekBaglam.run({ tmdbDil: 'tr-TR' }, async () => {
    fn(req, res, () => {});
    // Bütçe dolana kadar bekle: "asılı kalan" bir SSR ucunu taklit eder.
    await new Promise((r) => setTimeout(r, 90));
  });

  assert.equal(kayit.kod, 200,
    'durum kodu değişmiş — 200 dışı her kod ya soft 404 ya yeni bir 5xx');
  assert.equal(kayit.tip, 'html');
  assert.match(kayit.govde, /<meta name="robots" content="noindex/,
    'bütçe aşımı sayfası noindex DEĞİL — eksik içerik indekslenir');
  assert.match(kayit.govde, /rel="canonical"/,
    'canonical yok: Google sayfayı başka bir adresle eşleştirebilir');
  assert.equal(kaydedilen.length, 1, 'olay günlüğe düşmemiş — sessiz arıza');
  assert.equal(kaydedilen[0].olay, 'ssr_butce_asimi');
  res.kapat();
});

test('DAVRANIŞ: son tarih bağlama yazılıyor — tmdbGetir onu GÖRÜYOR', () => {
  const { fn } = araKatmanKur(5000);
  const { res } = sahteRes();
  let gorulen = null;
  istekBaglam.run({ tmdbDil: 'tr-TR' }, () => {
    // `next` içinde bakıyoruz: uç işleyicisinin gördüğü durum tam olarak bu.
    fn({ originalUrl: '/og/ana' }, res, () => { gorulen = ssrKalanSure(); });
  });
  assert.ok(gorulen !== null && gorulen > 4000 && gorulen <= 5000,
    `uç işleyicisi son tarihi görmüyor (kalan=${gorulen})`);
  res.kapat();
});

test('DAVRANIŞ: yanıt zamanında geldiyse güvenlik ağı KARIŞMAZ', async () => {
  const { fn, kaydedilen } = araKatmanKur(40);
  const { res, kayit } = sahteRes();
  await istekBaglam.run({ tmdbDil: 'tr-TR' }, async () => {
    fn({ originalUrl: '/og/kisi/1' }, res, () => {
      // Uç kendi yanıtını hemen basar (mutlu yol).
      res.type('html').send('<html>gerçek sayfa</html>');
      res.kapat();   // Express `close` olayını taklit eder
    });
    await new Promise((r) => setTimeout(r, 90));
  });
  // sahteRes ikinci send'de patlar; buraya gelmek "çift yanıt yok" demektir.
  assert.equal(kayit.govde, '<html>gerçek sayfa</html>');
  assert.equal(kaydedilen.length, 0,
    'yanıt zamanında geldiği hâlde bütçe aşımı loglanmış');
});
