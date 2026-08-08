// SEO gizlilik + keşif sayfası testleri — `node --test backend/test/*.test.js`
//
// Bu dosyanın koruduğu KARAR (kullanıcı, 6 Ağu 2026):
//   "Kullanıcı profilleri ASLA arama motorlarında indekslenmeyecek."
// Plandaki `/og/kullanici/:ad` maddesi bu yüzden İPTAL edildi. Karar tek bir
// yerde değil ÜÇ yerde birden tutuluyor (robots.txt, SSR ucunun yokluğu,
// sitemap kapsamı) ve üçü de burada kilitli — biri gevşerse test kırmızıya
// döner.
//
// Neden kaynak okuma: `server.js` içe aktarıldığı anda `app.listen` çağırıyor,
// yani uçlar doğrudan çağrılamıyor (kesfet_medya.test.js ile aynı gerekçe).
// Saf yardımcılar (htmlKacir, ogSayfa, seoKesifGovde, ...) kaynaktan ÇEKİLİP
// gerçekten ÇALIŞTIRILIYOR: test canlıdaki kodu sınar, kopyasını değil.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const PROJE = path.dirname(KOK);
const KAYNAK = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
const ROBOTS = fs.readFileSync(path.join(KOK, 'robots.txt'), 'utf8');
const YONLENDIRME = fs.readFileSync(
  path.join(PROJE, 'app', 'lib', 'yonlendirme.dart'), 'utf8');

// ---------------------------------------------------------------------------
// Kaynaktan bildirim çekme (admin_kacis.test.js'teki kalıbın genelleştirilmişi)
// ---------------------------------------------------------------------------
/** `function ad(...) {...}` ya da `const ad = ...;` bildiriminin tam metni. */
function bildirimCek(ad) {
  const m = new RegExp(`^(const|function) ${ad}\\b`, 'm').exec(KAYNAK);
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
  assert.fail(`${ad} bildiriminin sonu bulunamadı`);
}

/** İstenen bildirimleri sırayla derleyip son ifadeyi döndüren sanal alan. */
function alan(adlar, ifade) {
  const govde = adlar.map(bildirimCek).join('\n');
  return new Function(`${govde}\nreturn (${ifade});`)();
}

const htmlKacir = alan(['htmlKacir'], 'htmlKacir');
const jsonLdGom = alan(['jsonLdGom'], 'jsonLdGom');
// seoYildiz: puan başlıkta 10'luk değil 5 yıldız basılıyor (7 Ağu 2026).
const seoYorumHtml = alan(
  ['htmlKacir', 'seoGun', 'seoMetin', 'seoYildiz', 'seoYorumHtml'], 'seoYorumHtml');
const seoBaglantiListesi = alan(
  ['htmlKacir', 'seoBaglantiListesi'], 'seoBaglantiListesi');
const seoKesifGovde = alan(
  ['htmlKacir', 'seoBaglantiListesi', 'seoKesifGovde'], 'seoKesifGovde');
const seoKesifAdet = alan(['seoKesifAdet'], 'seoKesifAdet');
const seoKesifJsonLd = alan(
  ['SITE_KOK', 'seoKesifJsonLd'], 'seoKesifJsonLd');
const ogSayfa = alan(
  ['SITE_KOK', 'htmlKacir', 'kanonikUrl', 'jsonLdGom', 'ogSayfa'], 'ogSayfa');

/** Kaynağın [bas, son) arasındaki bölümü; sınır yoksa test patlar. */
function bolum(bas, son) {
  const i = KAYNAK.indexOf(bas);
  assert.notEqual(i, -1, `kaynakta bulunamadı: ${bas}`);
  const j = KAYNAK.indexOf(son, i + bas.length);
  assert.notEqual(j, -1, `kaynakta bulunamadı: ${son}`);
  return KAYNAK.slice(i, j);
}

// ---------------------------------------------------------------------------
// robots.txt ayrıştırma
// ---------------------------------------------------------------------------
/** `User-agent: *` bloğundaki Disallow yolları (joker kurallar hariç). */
const yildizBlogu = (() => {
  const satirlar = ROBOTS.split('\n').map((s) => s.replace(/#.*$/, '').trim());
  const disallow = [];
  const allow = [];
  let icerde = false;
  for (const s of satirlar) {
    const ua = /^User-agent:\s*(.+)$/i.exec(s);
    if (ua) { icerde = ua[1].trim() === '*'; continue; }
    if (!icerde) continue;
    const d = /^Disallow:\s*(.+)$/i.exec(s);
    if (d) disallow.push(d[1].trim());
    const a = /^Allow:\s*(.+)$/i.exec(s);
    if (a) allow.push(a[1].trim());
  }
  return { disallow, allow };
})();

/** Joker içermeyen ön ek kuralları — `yol` bunlardan biriyle kapanıyor mu? */
const kapali = (yol) => yildizBlogu.disallow
  .filter((d) => !d.includes('*'))
  .some((d) => yol.startsWith(d));

// yonlendirme.dart'taki KÖK yollar (`:param` -> örnek değer).
const ROTALAR = [
  ...new Set(
    [...YONLENDIRME.matchAll(/path:\s*'(\/[^']*)'/g)].map((m) => m[1])
      .concat(['/tam-arama']) // path: tamAramaYolu (sabit üzerinden)
      .map((y) => y.replace(/:[a-zA-Z]+/g, 'x')),
  ),
];

// Arama motoruna AÇIK olması GEREKENLER: SSR karşılığı olan içerik yolları,
// keşif liste sayfaları ve gizlilik politikası. Geri kalan HER rota kişisel
// ya da oturum gerektiren bir ekrandır ve robots.txt ile kapatılmalıdır.
const ACIK_ROTALAR = new Set([
  '/icerik/x/x', '/kisi/x', '/gonderi/x', '/dizi/x/sezon/x/bolum/x',
  '/gozat', '/kesfet', '/gizlilik',
  // 7 Ağu 2026: /listeler/:id artık gerçek bir rota ve oturumsuz açılıyor.
  // Sunucu bu yol için indekslenebilir SSR basıyordu ama uygulamada rota
  // YOKTU (bot içerik, insan giriş formu = cloaking). Rota eklendiği için
  // artık kişisel değil herkese açık içerik yolu; aşağıdaki "SSR ile
  // indekslenen yollar" testi de /listeler/1'in kapatılmamasını bekliyor.
  '/listeler/x',
]);

// ===========================================================================
// 1) KULLANICI PROFİLLERİ — üç katmanlı güvence
// ===========================================================================
test('robots.txt kullanıcı profillerini KAPATIYOR (/kullanici/)', () => {
  assert.ok(kapali('/kullanici/alcelik'),
    'profil sayfası robots.txt ile kapatılmamış — kullanıcı verisi taranır');
  assert.ok(kapali('/kullanici/alcelik/takipciler'), 'takipçi listesi açık');
  assert.ok(kapali('/kullanici/alcelik/takip'), 'takip listesi açık');
});

test('server.js içinde /og/kullanici SSR ucu YOK (madde iptal edildi)', () => {
  assert.ok(!/app\.get\(\s*['"`]\/og\/kullanici/.test(KAYNAK),
    '/og/kullanici ucu eklenmiş — kullanıcı kararı: profiller asla indekslenmez');
  assert.ok(!/\/og\/kullanici/.test(KAYNAK), 'kaynakta /og/kullanici izi var');
});

test('hiçbir SSR sayfası kullanıcı profiline BAĞLANTI vermiyor', () => {
  // Profil sayfası taranmasa bile bir <a href="/kullanici/..."> Google'a
  // yolu bildirir ve URL-only indekslemeye kapı açar. @kullanici_adi her
  // yerde DÜZ METİN basılmalı.
  const og = bolum('// ---------- OG / link önizleme', '// ---------- IndexNow');
  assert.ok(!og.includes('href="/kullanici'), 'SSR gövdesinde profil bağlantısı var');
  assert.ok(!/\/kullanici\/\$\{/.test(og), 'SSR gövdesinde profil URL şablonu var');
  // Çalıştırılabilir kanıt: yorum bloğu kullanıcı adını bağlantıya çevirmiyor.
  const h = seoYorumHtml({
    kullanici_adi: 'alcelik', metin: 'Uzunca bir yorum metni.',
    tarih: new Date('2026-08-06T10:00:00Z'), puan: 9,
  });
  assert.ok(h.includes('@alcelik'), 'kullanıcı adı basılmıyor');
  assert.ok(!h.includes('<a '), 'yorum bloğu bağlantı üretiyor');
});

test('sitemap YALNIZ /icerik/:tur/:id üretir — profil/kişisel URL yok', () => {
  const uret = bolum('async function sitemapUret()', 'async function sitemapVerisi');
  assert.match(uret, /loc: `\$\{SITE_KOK\}\/icerik\/\$\{r\.tur\}\/\$\{r\.tmdb_id\}`/);
  for (const y of ['kullanici', 'profil', 'sohbet', 'bildirim', 'kitaplik']) {
    assert.ok(!uret.includes(y), `sitemap şablonuna ${y} sızmış`);
  }
  // Sorgu yalnız içerik tablolarından tur+tmdb_id seçiyor; kullanıcı kimliği
  // ya da adı çıktıya HİÇ girmiyor.
  const sorgu = bildirimCek('SITEMAP_SORGU');
  assert.match(sorgu, /SELECT tur, tmdb_id, max\(tarih\) AS son/);
  assert.ok(!/kullanici_adi/.test(sorgu), 'sitemap sorgusu kullanıcı adı seçiyor');
  assert.ok(!/\bemail\b/.test(sorgu), 'sitemap sorgusu e-posta seçiyor');
});

// ===========================================================================
// 2) robots.txt — kişisel rotaların tamamı kapalı, içerik yolları açık
// ===========================================================================
test('yonlendirme.dart rota listesi ayrıştırıldı (test etkisiz kalmasın)', () => {
  assert.ok(ROTALAR.length >= 20, `rota bulunamadı (${ROTALAR.length})`);
  for (const beklenen of ['/kullanici/x', '/profil', '/gozat', '/kesfet']) {
    assert.ok(ROTALAR.includes(beklenen), `rota ayrıştırılamadı: ${beklenen}`);
  }
});

test('oturum gerektiren HER rota robots.txt ile kapalı', () => {
  // Bu test yeni rotaları da yakalar: yonlendirme.dart'a kişisel bir ekran
  // eklenip robots.txt unutulursa kırmızıya döner.
  const acik = ROTALAR.filter((y) => !ACIK_ROTALAR.has(y) && !kapali(y));
  assert.deepEqual(acik, [], `robots.txt'te kapatılmamış kişisel rota: ${acik}`);
});

test('SSR ile indekslenen yollar robots.txt ile yanlışlıkla kapatılmamış', () => {
  for (const y of ['/icerik/tv/1396', '/kisi/17419', '/gonderi/1',
    '/dizi/1396/sezon/1/bolum/1', '/listeler/1', '/gozat', '/kesfet',
    '/gizlilik', '/sitemap.xml', '/robots.txt']) {
    assert.ok(!kapali(y), `SSR yolu robots.txt ile kapatılmış: ${y}`);
  }
});

test('robots.txt Sitemap satırı ve görsel istisnaları duruyor', () => {
  assert.match(ROBOTS, /^Sitemap:\s*https:\/\/dizijpg\.com\/sitemap\.xml$/m);
  assert.ok(kapali('/api/yorumlar'), '/api/ kapatılmamış');
  assert.ok(yildizBlogu.allow.includes('/api/medya/'), 'medya Allow istisnası yok');
  assert.ok(yildizBlogu.allow.includes('/api/avatarlar/'), 'avatar Allow istisnası yok');
});

test('robots.txt Node tarafından servis ediliyor ve imaja giriyor', () => {
  assert.match(KAYNAK, /app\.get\('\/robots\.txt'/);
  assert.match(KAYNAK, /readFileSync\(ROBOTS_YOL/);
  const dockerfile = fs.readFileSync(path.join(KOK, 'Dockerfile'), 'utf8');
  assert.match(dockerfile, /^COPY robots\.txt \.\/$/m,
    'robots.txt Dockerfile COPY listesinde yok — uç canlıda 404 döner');
});

// ===========================================================================
// 3) SSR sayfalarında kişisel veri sızıntısı
// ===========================================================================
const OG_BOLUM = bolum('// ---------- OG / link önizleme', '// ---------- IndexNow');

// SSR bölümündeki TÜM SQL'ler (SQL bu dosyada her zaman şablon dizesindedir;
// yorum satırlarını taramamak için gövde değil bunlar denetlenir).
const sqlCek = (metin) =>
  [...metin.matchAll(/`([^`]*\bSELECT\b[\s\S]*?)`/g)].map((m) => m[1]).join('\n---\n');
const OG_SQL = [...OG_BOLUM.matchAll(/`([^`]*\bSELECT\b[\s\S]*?)`/g)].map((m) => m[1]);

// UYARI (kırmızıya döndürme denemesinde yakalandı): süzgeç denetimleri uç
// gövdesinin TAMAMINA bakarsa, süzgeci ANLATAN yorum satırı testi ayakta
// tutar — `NOT y.spoiler`i WHERE'den silmek testi kırmızıya döndürmüyordu.
// Bu yüzden aşağıdaki testler yalnızca SQL metnine bakar.
const GONDERI_SQL = sqlCek(bolum("app.get('/og/gonderi/:id'", "app.get('/og/dizi/"));
const LISTE_SQL = sqlCek(bolum("app.get('/og/listeler/:id'", "app.get('/og/ana'"));

test('SSR sorguları YASAK sütunların hiçbirine dokunmuyor', () => {
  // Kullanıcıdan basılmasına izin verilen tek kişisel alan: kullanici_adi.
  // (metin/puan/tarih içeriktir, kimliğe bağlı gizli veri değildir.)
  assert.ok(OG_SQL.length >= 5, `SSR SQL'leri bulunamadı (${OG_SQL.length})`);
  const YASAK = [
    'email', 'sifre_hash', 'sifre_surumu', 'son_gorulme', 'ulke', 'bio',
    'bildir_begeni', 'bildir_yanit', 'bildir_takip', 'bildir_mesaj',
    'bildir_etiket', 'izlenenler_gizli', 'yorumlar_gizli', 'yanitlar_gizli',
    'cevrimici_gizli', 'misafir', 'mesajlar', 'engellemeler', 'oturumlar',
    'ip_adresi', 'cihazlar', 'sohbetler',
  ];
  for (const sql of OG_SQL) {
    for (const alan of YASAK) {
      assert.ok(!new RegExp(`\\b${alan}\\b`).test(sql),
        `SSR sorgusunda kişisel alan geçiyor: ${alan}\n${sql.slice(0, 160)}`);
    }
  }
});

test('SSR sayfaları hesap DURUMUNU (yasaklı) ele vermiyor', () => {
  // `yasakli` yalnız WHERE süzgecinde geçmeli; SELECT'e girerse "bu hesap
  // yasaklı" bilgisi HTML'e düşer.
  const secimler = [...OG_BOLUM.matchAll(/SELECT[\s\S]*?FROM/g)].map((m) => m[0]);
  assert.ok(secimler.length >= 5, 'SSR SELECT listeleri bulunamadı');
  for (const s of secimler) {
    assert.ok(!/yasakli/.test(s), `SELECT listesinde yasakli var: ${s.slice(0, 80)}`);
  }
});

test('YASAKLI kullanıcının metni hiçbir SSR yüzeyine düşmüyor', () => {
  const kosul = bildirimCek('SEO_YORUM_KOSUL');
  const inceleme = bildirimCek('SEO_INCELEME_KOSUL');
  assert.match(kosul, /NOT k\.yasakli/);
  assert.match(inceleme, /NOT k\.yasakli/);
  // Gönderi ve liste uçlarının kendi süzgeci var (ortak sabiti kullanmıyorlar).
  assert.match(GONDERI_SQL, /NOT k\.yasakli/);
  assert.match(LISTE_SQL, /NOT k\.yasakli/);
  assert.match(LISTE_SQL, /herkese_acik/);
});

test('SPOİLER metin hiçbir SSR yüzeyine düşmüyor (gönderi dahil)', () => {
  assert.match(bildirimCek('SEO_YORUM_KOSUL'), /NOT y\.spoiler/);
  // 6 Ağu denetiminin bulduğu sızıntı: /og/gonderi spoiler süzmüyordu, yani
  // WhatsApp önizlemesi spoiler'ı tıklamadan gösteriyordu.
  assert.match(GONDERI_SQL, /NOT y\.spoiler/,
    '/og/gonderi spoiler süzmüyor — önizlemede spoiler açığa çıkar');
});

test('"bu içeriği gizle" diyen kullanıcının metni SEO yüzeyine çıkmıyor', () => {
  const yardimci = bildirimCek('SEO_GIZLI_ICERIK_YOK');
  assert.match(yardimci, /FROM gizli_icerikler g/);
  for (const [ad, sabit] of [
    ['SEO_YORUM_KOSUL', bildirimCek('SEO_YORUM_KOSUL')],
    ['SEO_INCELEME_KOSUL', bildirimCek('SEO_INCELEME_KOSUL')],
  ]) {
    assert.match(sabit, /SEO_GIZLI_ICERIK_YOK/, `${ad} gizleme tercihini yok sayıyor`);
  }
  assert.match(GONDERI_SQL, /SEO_GIZLI_ICERIK_YOK/);
});

test('bölüm sayfası ortak süzgeci kullanıyor (kendi kuralını uydurmuyor)', () => {
  const b = bolum('async function seoBolumYorumlari(', "app.get('/og/dizi/");
  assert.match(b, /\$\{SEO_YORUM_KOSUL\}/);
});

test('SSR tarih alanı yalnız GÜN basıyor (saat/dakika parmak izi vermiyor)', () => {
  const h = seoYorumHtml({
    kullanici_adi: 'testkullanici', metin: 'metin',
    tarih: new Date('2026-08-06T21:34:56Z'),
  });
  assert.match(h, /<time datetime="2026-08-06">2026-08-06<\/time>/);
  assert.ok(!h.includes('21:34'), 'saat bilgisi HTML e düşüyor');
});

// ===========================================================================
// 4) Spam yüzeyi: kullanıcı metnindeki dış bağlantılar
// ===========================================================================
test('kullanıcı metnindeki URL bağlantıya ÇEVRİLMİYOR (ugc spam yüzeyi yok)', () => {
  // rel="nofollow ugc" ancak <a> üretilirse gerekir. Burada verilen karar
  // daha güçlüsü: kullanıcı metni HİÇ bağlantıya çevrilmez, düz metin kalır.
  const h = seoYorumHtml({
    kullanici_adi: 'spamci',
    metin: 'Bedava izle https://korsan.example/dizi ve <a href="https://x">tikla</a>',
    tarih: new Date('2026-08-06T00:00:00Z'),
  });
  assert.ok(!/<a\s/i.test(h), 'kullanıcı metninden bağlantı üretilmiş');
  assert.ok(h.includes('&lt;a href=&quot;https://x&quot;&gt;'), 'ham HTML kaçırılmamış');
  // Kaynakta da linkleştirme (autolink) yardımcısı OLMAMALI.
  assert.ok(!/linkle|autolink|nofollow/i.test(OG_BOLUM),
    'SSR bölümünde linkleştirme izi var — varsa rel="nofollow ugc" şart');
});

test('SSR bağlantıları YALNIZ kendi site yollarımıza gidiyor', () => {
  // seoBaglantiListesi'ne dışarıdan URL verilse bile yol olarak basılır;
  // gövdeyi üreten uçların hiçbiri kullanıcı metninden yol türetmiyor.
  const li = seoBaglantiListesi('Oyuncular', [{ ad: 'Bryan Cranston', yol: '/kisi/17419' }]);
  assert.equal(li, '\n<h2>Oyuncular</h2>\n<ul><li><a href="/kisi/17419">Bryan Cranston</a></li></ul>');
});

// ===========================================================================
// 5) Kaçış — kullanıcı metni HTML ve JSON-LD'yi kıramaz
// ===========================================================================
test('htmlKacir beş tehlikeli karakteri de kaçırıyor', () => {
  assert.equal(htmlKacir(`<&">'`), '&lt;&amp;&quot;&gt;&#39;');
});

test('jsonLdGom </script> kaçışını yapıyor (bio XSS senaryosu)', () => {
  const s = jsonLdGom({ ad: '</script><img src=x onerror=alert(1)>' });
  assert.ok(!s.includes('</script><img'), 'script bloğu erken kapanıyor');
  assert.ok(!/<\/script>[^\n]*<img/.test(s));
  assert.ok(s.includes('\\u003c/script\\u003e'), 'kaçış beklenen biçimde değil');
  // Gömülen metin JSON.stringify ile üretiliyor -> elle birleştirme yok.
  assert.match(bildirimCek('jsonLdGom'), /JSON\.stringify\(nesne\)/);
});

test('ogSayfa başlık/açıklama/JSON-LD kaçışını uçtan uca yapıyor', () => {
  const yuk = '"><script>alert(1)</script>';
  const html = ogSayfa({
    baslik: yuk,
    aciklama: yuk,
    url: 'https://dizijpg.com/icerik/tv/1?utm_source=x',
    jsonLd: { name: yuk },
  });
  assert.ok(!html.includes('<script>alert(1)</script>'), 'ham script HTML e düştü');
  assert.ok(html.includes('&quot;&gt;&lt;script&gt;'), 'başlık kaçırılmamış');
  // canonical tek biçim: apex host, sorgu parametresiz, sondaki eğik çizgisiz.
  assert.ok(html.includes('<link rel="canonical" href="https://dizijpg.com/icerik/tv/1">'));
});

test('noindex istenen sayfa gerçekten noindex,follow basıyor', () => {
  const html = ogSayfa({ baslik: 'x', url: 'https://dizijpg.com/gozat', indexle: false });
  assert.ok(html.includes('<meta name="robots" content="noindex,follow">'));
  const acik = ogSayfa({ baslik: 'x', url: 'https://dizijpg.com/gozat' });
  assert.ok(!acik.includes('name="robots"'));
});

// ===========================================================================
// 6) /gozat ve /kesfet liste sayfaları (SEO-PLANI 1.4 kalanı)
// ===========================================================================
test('/og/gozat ve /og/kesfet uçları tanımlı', () => {
  assert.match(KAYNAK, /app\.get\('\/og\/gozat'/);
  assert.match(KAYNAK, /app\.get\('\/og\/kesfet'/);
});

test('CLOAKING KİLİDİ: Flutter rotaları oturumsuz açılmadıkça noindex', () => {
  // yonlendirme.dart'taki acikYolOnEkleri'nde '/gozat' ve '/kesfet' YOK:
  // oturumsuz ziyaretçi /giris'e atılıyor. O halde bu sayfalar indekse
  // GİRMEMELİ (SEO-PLANI 3.1). Kilidin iki ucu da burada denetleniyor.
  const acikListe = /const acikYolOnEkleri = <String>\[([^\]]*)\]/
    .exec(YONLENDIRME);
  assert.ok(acikListe, 'acikYolOnEkleri listesi bulunamadı');
  const flutterAcik = (yol) => acikListe[1].includes(`'${yol}'`);
  const sabit = /const SEO_KESIF_INDEKS = (true|false);/.exec(KAYNAK);
  assert.ok(sabit, 'SEO_KESIF_INDEKS sabiti yok');
  if (sabit[1] === 'true') {
    assert.ok(flutterAcik('/gozat') && flutterAcik('/kesfet'),
      'SEO_KESIF_INDEKS=true ama Flutter bu rotaları oturumsuz açmıyor — CLOAKING');
  }
  // İndeksleme kararı hem kilide hem "ince değil" eşiğine bağlı olmalı.
  const uc = bolum('function ogKesifUcu(', "app.get('/og/kesfet'");
  assert.match(uc, /indexle: SEO_KESIF_INDEKS && adet >= SEO_KESIF_MIN/);
});

test('keşif sayfaları İNCE olamaz: eşik gerçekten aşılabilir', () => {
  const oge = Number(/const SEO_KESIF_OGE = (\d+);/.exec(KAYNAK)[1]);
  const min = Number(/const SEO_KESIF_MIN = (\d+);/.exec(KAYNAK)[1]);
  const raflar = (KAYNAK.match(/\{ baslik: '[^']+', tur: '(tv|movie)', yol:/g) || []).length;
  const katalog = (KAYNAK.match(/\{ baslik: '[^']+', tur: '(tv|movie)', genre: \d+ \}/g) || []).length;
  assert.ok(raflar >= 10, `/kesfet raf sayısı yetersiz: ${raflar}`);
  assert.ok(katalog >= 10, `/gozat tür sayısı yetersiz: ${katalog}`);
  assert.ok(min >= 24, `ince sayfa eşiği fazla düşük: ${min}`);
  assert.ok(raflar * oge >= min * 2, 'raflar eşiği ancak kıl payı geçiyor');
  assert.ok(katalog * oge >= min * 2, 'katalog eşiği ancak kıl payı geçiyor');
});

test('/gozat ve /kesfet AYNI listeyi basmıyor (yinelenen içerik)', () => {
  const rafKaynak = bildirimCek('SEO_KESFET_RAFLARI');
  const katKaynak = bildirimCek('SEO_GOZAT_KATALOG');
  const raf = [...rafKaynak.matchAll(/yol: '([^']+)'/g)].map((m) => m[1]);
  // Katalog yolları `.map()` ile üretiliyor: tür kimliğinden aynı şablonla kur.
  const genreler = [...katKaynak.matchAll(/tur: '(tv|movie)', genre: (\d+)/g)];
  const kat = genreler.map(([, tur, g]) =>
    `/discover/${tur}?sort_by=popularity.desc&vote_count.gte=80&with_genres=${g}`);
  assert.ok(raf.length >= 10, `raf sayısı: ${raf.length}`);
  assert.ok(kat.length >= 10, `tür sayısı: ${kat.length}`);
  const ortak = raf.filter((y) => kat.includes(y));
  assert.deepEqual(ortak, [], `iki sayfa aynı TMDB sorgusunu paylaşıyor: ${ortak}`);
  // /gozat türe göre süzer, /kesfet süzmez — ayrımın kaynağı bu.
  assert.match(katKaynak, /with_genres=\$\{t\.genre\}/, 'katalog tür süzgeci yok');
  assert.ok(raf.every((y) => !y.includes('with_genres=')), 'raflara tür süzgeci sızmış');
  // Şablon değişirse yukarıdaki `kat` kurgusu sessizce yanlışlaşır: kilitle.
  assert.ok(katKaynak.includes('/discover/${t.tur}?sort_by=popularity.desc&vote_count.gte=80'),
    'katalog yol şablonu değişmiş — testteki kurgu güncellenmeli');
});

test('keşif sayfaları OLMAYAN URL üretmiyor (tür sayfası rotası yok)', () => {
  const govde = seoKesifGovde([
    { baslik: 'Dram dizileri', ogeler: [{ ad: 'Breaking Bad', yol: '/icerik/tv/1396' }] },
  ]);
  assert.ok(govde.includes('<h2>Dram dizileri</h2>'), 'tür adı başlık olarak basılmıyor');
  const hrefler = [...govde.matchAll(/href="([^"]+)"/g)].map((m) => m[1]);
  assert.ok(hrefler.length > 0);
  assert.ok(hrefler.every((h) => h.startsWith('/icerik/')),
    `keşif sayfası /icerik dışına bağlanıyor: ${hrefler}`);
});

test('keşif gövdesi başlık ve içerik adını kaçırıyor', () => {
  const govde = seoKesifGovde([{
    baslik: '<script>alert(1)</script>',
    ogeler: [{ ad: '"><img src=x onerror=alert(2)>', yol: '/icerik/tv/1' }],
  }]);
  assert.ok(!govde.includes('<script>'), 'başlık kaçırılmamış');
  assert.ok(!govde.includes('<img'), 'içerik adı kaçırılmamış');
});

test('keşif JSON-LD: CollectionPage + görünen listelerin ItemList karşılığı', () => {
  const bloklar = [
    { baslik: 'Dram dizileri', ogeler: [{ ad: 'A', yol: '/icerik/tv/1' }, { ad: 'B', yol: '/icerik/tv/2' }] },
    { baslik: 'Komedi filmleri', ogeler: [{ ad: 'C', yol: '/icerik/movie/3' }] },
  ];
  const ld = seoKesifJsonLd({
    url: 'https://dizijpg.com/gozat', ad: 'Gözat', aciklama: 'katalog',
    kirintiAd: 'Gözat', bloklar,
  });
  const sayfa = ld['@graph'][0];
  assert.equal(sayfa['@type'], 'CollectionPage');
  assert.equal(sayfa.hasPart.length, 2);
  assert.equal(sayfa.hasPart[0]['@type'], 'ItemList');
  assert.equal(sayfa.hasPart[0].numberOfItems, 2);
  assert.equal(sayfa.hasPart[0].itemListElement[1].url, 'https://dizijpg.com/icerik/tv/2');
  assert.equal(ld['@graph'][1]['@type'], 'BreadcrumbList');
  // Sayfada GÖRÜNMEYEN öğe yapısal veriye girmemeli: sayılar birebir.
  assert.equal(
    sayfa.hasPart.reduce((n, l) => n + l.itemListElement.length, 0),
    seoKesifAdet(bloklar));
  // Gömme jsonLdGom'dan geçmeli (elle string birleştirme yok).
  const uc = bolum('function ogKesifUcu(', "app.get('/og/kesfet'");
  assert.match(uc, /jsonLd: bloklar\.length/);
});

test('keşif ucu boş listede İNDEKSLEMEZ ve JSON-LD basmaz (soft 404)', () => {
  const uc = bolum('function ogKesifUcu(', "app.get('/og/kesfet'");
  assert.match(uc, /: null,/, 'blok yokken jsonLd null değil');
  assert.match(uc, /adet >= SEO_KESIF_MIN/);
  // Boş blok DÜŞMELİ: başlığı olup listesi olmayan bölüm ince içeriktir.
  const bloklayici = bolum('async function seoKesifBloklari(', 'const seoKesifGovde');
  assert.match(bloklayici, /\.filter\(\(b\) => b\.ogeler\.length > 0\)/);
});

test('keşif tanımları gozat.dart/kesfet.dart ile aynı TMDB sorgularını kullanıyor', () => {
  // Bot ile kullanıcının gördüğü sayfa içerik olarak örtüşmeli (3.1).
  const gozat = fs.readFileSync(
    path.join(PROJE, 'app', 'lib', 'ekranlar', 'gozat.dart'), 'utf8');
  assert.ok(gozat.includes('sort_by=popularity.desc') && gozat.includes('vote_count.gte=80'),
    'gozat.dart sorgusu değişmiş — SEO_GOZAT_KATALOG güncellenmeli');
  const katalog = bildirimCek('SEO_GOZAT_KATALOG');
  assert.ok(katalog.includes('sort_by=popularity.desc&vote_count.gte=80'));

  const kesfet = fs.readFileSync(
    path.join(PROJE, 'app', 'lib', 'ekranlar', 'kesfet.dart'), 'utf8');
  const raflar = bildirimCek('SEO_KESFET_RAFLARI');
  for (const ad of ['Türk Dizileri', 'Kült Filmler', 'Haftanın Dizileri']) {
    assert.ok(kesfet.includes(`'${ad}'`), `kesfet.dart'ta raf yok: ${ad}`);
    assert.ok(raflar.includes(`'${ad}'`), `SEO rafları eksik: ${ad}`);
  }
});
