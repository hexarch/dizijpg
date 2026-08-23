// Soft 404 kapatma testleri — `node --test backend/test/*.test.js`
//
// KORUDUĞU KARAR (14 Ağu 2026): `/boyle-bir-sayfa-yok` artık 200 + boş Flutter
// kabuğu DÖNMEYECEK. Bot için:
//   · bilinen rota + SSR yok -> 200 + noindex,follow minimal sayfa,
//   · bilinmeyen rota        -> GERÇEK 404 + noindex.
// İnsan trafiği HİÇ değişmez (nginx yalnız `$og_bot` isteklerini Node'a taşır).
//
// Bu dosyanın en kritik testi "tablo yonlendirme.dart ile BİREBİR eşleşiyor":
// rota tablosu elle yazılıdır (backend imajında `app/` yok, çalışma zamanında
// okunamaz) ve gerçekle ayrışırsa YENİ eklenen bir ekran botlara 404 döner.
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  KAYNAK, bildirimCek, alan, bolum, flutterRotalari, ornekYol, robotsKapali,
} from './yardimci/seo_kaynak.js';

const BOT_ROTALARI = alan(['BOT_ROTALARI'], 'BOT_ROTALARI');
const botRotasiVar = alan(['BOT_ROTALARI', 'botRotasiVar'], 'botRotasiVar');
const ogSayfa = alan(
  ['SITE_KOK', 'htmlKacir', 'seoKamuYolu', 'seoKanonikYol', 'kanonikUrl', 'jsonLdGom', 'seoIstDil', 'seoOgYerel', 'ogSayfa'], 'ogSayfa');

// Flutter rotası OLMADIĞI hâlde tabloda bulunması GEREKENLER ve gerekçeleri.
// Tabloya bunun dışında bir şey eklenirse test kırmızıya döner: uydurma yol
// bilinen rota sayılıp 404 yerine 200 alırdı.
const TABLO_EK_YOLLAR = new Map([
  ['/', 'kök: Flutter rotası değil ama SSR\'ı var (/og/ana)'],
]);

// ===========================================================================
// 1) Tablo gerçekle eşleşiyor mu
// ===========================================================================
test('yonlendirme.dart ayrıştırıcısı çalışıyor (test etkisiz kalmasın)', () => {
  const rotalar = flutterRotalari();
  assert.ok(rotalar.length >= 30, `rota bulunamadı (${rotalar.length})`);
  // İç içe rota ve sabit üzerinden verilen yol da çözülmüş olmalı — ikisi de
  // basit ayrıştırıcının GÖZDEN KAÇIRDIĞI durumlar.
  for (const beklenen of [
    '/kullanici/:ad/takipciler', '/kullanici/:ad/takip',
    '/tam-arama', '/arama-gelen',
    '/dizi/:id/sezon/:sezon/bolum/:bolum',
  ]) {
    assert.ok(rotalar.includes(beklenen), `rota ayrıştırılamadı: ${beklenen}`);
  }
});

test('BOT_ROTALARI tablosu yonlendirme.dart ile BİREBİR eşleşiyor', () => {
  const gercek = new Set(flutterRotalari());
  const tablo = BOT_ROTALARI.map((r) => r.yol);
  assert.equal(tablo.length, new Set(tablo).size, `tabloda yinelenen yol: ${tablo}`);

  const eksik = [...gercek].filter((y) => !tablo.includes(y));
  assert.deepEqual(eksik, [],
    `yonlendirme.dart'ta olup BOT_ROTALARI'nda OLMAYAN rota (bota 404 döner): ${eksik}`);

  const fazla = tablo.filter((y) => !gercek.has(y) && !TABLO_EK_YOLLAR.has(y));
  assert.deepEqual(fazla, [],
    `BOT_ROTALARI'nda olup yonlendirme.dart'ta olmayan yol (silinmiş ekran?): ${fazla}`);
});

test('her desen kendi `yol`undan üretilen örnek adresi eşliyor', () => {
  // Yazım hatası kalkanı: `yol` doğru ama `desen` yanlışsa tablo sessizce
  // etkisiz kalır ve gerçek bir ekran 404 alır.
  for (const r of BOT_ROTALARI) {
    const ornek = ornekYol(r.yol);
    assert.ok(r.desen.test(ornek),
      `desen kendi yolunu eşlemiyor: ${r.yol} -> ${ornek} (${r.desen})`);
    // Desenler bağlanmış (anchored) olmalı: `/ayarlar-bilmemne` bilinen rota
    // sayılmamalı.
    assert.match(String(r.desen), /^\/\^/, `desen ^ ile başlamıyor: ${r.yol}`);
    assert.match(String(r.desen), /\$\/$/, `desen $ ile bitmiyor: ${r.yol}`);
  }
});

// ===========================================================================
// 2) Çalışma zamanı davranışı
// ===========================================================================
test('bilinen yollar tabloda BULUNUYOR', () => {
  for (const y of [
    '/', '/gozat', '/kesfet', '/gizlilik', '/ayarlar',
    '/icerik/tv/1396', '/icerik/movie/550', '/kisi/17419', '/gonderi/1',
    '/listeler/1', '/sirket/33', '/dizi/1396/sezon/1/bolum/1',
    '/kullanici/alcelik', '/kullanici/alcelik/takipciler', '/kullanici/alcelik/takip',
    '/kitaplik/izliyorum', '/ozet/2026', '/yapimlar/500', '/hareketlerim',
  ]) {
    assert.ok(botRotasiVar(y), `bilinen yol tabloda yok (404 alır): ${y}`);
  }
});

test('uydurma yollar tabloda YOK — gerçek 404 alacaklar', () => {
  for (const y of [
    '/boyle-bir-sayfa-yok',
    '/ayarlar-bilmemne',          // ön ek tuzağı
    '/gozat/dram',                // olmayan alt yol
    '/icerik/tv',                 // eksik parametre
    '/icerik/tv/1396/yorumlar',   // fazladan parça
    '/dizi/1396/sezon/1',         // sezon sayfası ROTASI YOK
    '/dizi/1396/sezon/1/bolum',
    '/kisi/abc',                  // sayısal olmayan id
    '/ozet/yirmiyirmialti',
    '/wp-login.php', '/admin', '/.env', '/index.php',
  ]) {
    assert.ok(!botRotasiVar(y), `uydurma yol bilinen sayıldı (200 alır): ${y}`);
  }
});

test('sezon sayfası rotası YOK — bölüm SSR sayfası da ona bağlanmıyor', () => {
  // `partOfSeason`a url verilmemesinin ve "sezon" bağlantısı basılmamasının
  // gerekçesi: böyle bir rota yok, olmayan URL bota bildirilemez.
  assert.ok(!botRotasiVar('/dizi/1396/sezon/1'));
  const b = bolum('function bolumJsonLd(', "app.get('/og/dizi/");
  assert.match(b, /partOfSeason: \{ '@type': 'TVSeason', seasonNumber: sezon \}/);
  assert.ok(!/sezon\/\$\{sezon\}'/.test(b), 'sezon sayfası URL şablonu üretilmiş');
});

// ===========================================================================
// 3) Uç sözleşmesi: durum kodu, noindex, çıkış bağlantıları
// ===========================================================================
const UC = bolum('app.get(/^\\/og(?:\\/(.*))?$/', '// robots.txt Node\'dan servis');

test('yakalayıcı uç: bilinmeyen yolda 404, bilinen yolda 200', () => {
  assert.match(UC, /if \(!botRotasiVar\(yol\)\)/,
    'karar tablo üzerinden verilmiyor');
  assert.match(UC, /res\.status\(404\)/, 'bilinmeyen yol için 404 yok');
  // Bilinen yol dalında status DEĞİŞTİRİLMEMELİ (200 kalmalı): dalın tamamında
  // tek bir res.status çağrısı olmalı ve o da 404 dalında.
  assert.equal((UC.match(/res\.status\(/g) || []).length, 1,
    'bilinen rota dalında da durum kodu değiştiriliyor');
});

test('yakalayıcı uç HER İKİ dalda da noindex basıyor', () => {
  assert.equal((UC.match(/indexle: false/g) || []).length, 2,
    'iki daldan biri indekslenebilir sayfa basıyor');
  // Çalıştırılabilir kanıt: ogSayfa gerçekten noindex meta'sı üretiyor.
  const html = ogSayfa({
    baslik: 'Sayfa bulunamadı — dizi.jpg',
    url: 'https://dizijpg.com/boyle-bir-sayfa-yok', indexle: false,
  });
  assert.ok(html.includes('<meta name="robots" content="noindex,follow">'));
});

test('yakalayıcı uç hız limitli ve DB/TMDB\'ye dokunmuyor', () => {
  assert.match(UC, /botYolLimiti/, 'yakalayıcı uçta hız limiti yok');
  const limit = bildirimCek('botYolLimiti');
  assert.match(limit, /hizLimiti\(\d+,/);
  assert.match(limit, /req\.ip/, 'limit IP anahtarlı değil');
  for (const yasak of ['havuz.query', 'tmdbGetir', 'tmdbTopluGetir', 'await']) {
    assert.ok(!UC.includes(yasak),
      `yakalayıcı uç ${yasak} çağırıyor — bot seli DB/TMDB'yi dövebilir`);
  }
});

test('yakalayıcı uç uzun yolu kırpıyor (uydurma dev URL sayfaya basılmasın)', () => {
  assert.match(UC, /\.slice\(0, 200\)/, 'yol uzunluğu kırpılmıyor');
});

test('404 sayfası çıkmaz değil: ana sayfaya ve keşif sayfalarına bağlanıyor', () => {
  assert.match(UC, /SEO_KESIF_HUB/, '404 sayfasında çıkış bağlantısı yok');
  const hub = bildirimCek('SEO_KESIF_HUB');
  assert.match(hub, /'\/gozat'/);
  assert.match(hub, /'\/kesfet'/);
  // GİZLİLİK: çıkış bağlantıları profile GİTMEZ.
  assert.ok(!/kullanici/.test(hub), 'hub bağlantısı kullanıcı profiline gidiyor');
});

test('yakalayıcı uç TÜM özel /og uçlarından SONRA tanımlı', () => {
  // Express ilk eşleşen rotayı çalıştırır: yakalayıcı önce gelirse /og/icerik,
  // /og/kisi, /og/gozat ... hepsi gölgelenir ve site SSR'sını komple kaybeder.
  const yakalayici = KAYNAK.indexOf('app.get(/^\\/og(?:\\/(.*))?$/');
  assert.notEqual(yakalayici, -1, 'yakalayıcı uç bulunamadı');
  for (const ozel of [
    "app.get('/og/icerik/:tur/:tmdbId'", "app.get('/og/kisi/:id'",
    "app.get('/og/gonderi/:id'", "app.get('/og/dizi/:id/sezon/:sezon/bolum/:bolum'",
    "app.get('/og/listeler/:id'", "app.get('/og/ana'",
    "app.get('/og/kesfet'", "app.get('/og/gozat'",
  ]) {
    const i = KAYNAK.indexOf(ozel);
    assert.notEqual(i, -1, `uç bulunamadı: ${ozel}`);
    assert.ok(i < yakalayici, `yakalayıcı uç ${ozel} ucunu gölgeliyor`);
  }
});

// ===========================================================================
// 4) nginx parçası — dosya var ve insan trafiğini bozmuyor
// ===========================================================================
test('nginx parça dosyası SPA geri dönüşünü yalnız BOT için Node\'a taşıyor', async () => {
  const fs = await import('node:fs');
  const path = await import('node:path');
  const { KOK } = await import('./yardimci/seo_kaynak.js');
  const parca = fs.readFileSync(
    path.join(KOK, 'nginx-seo-20260814.parca.conf'), 'utf8');
  // Bot kapısı `$og_bot` değişkenine bağlı olmalı: koşulsuz proxy_pass insan
  // trafiğini de SSR'a taşır (kabuk gitmez, uygulama açılmaz).
  assert.match(parca, /if \(\$og_bot\)/, 'bot koşulu yok — insan trafiği bozulur');
  // Var olan STATİK dosya önce servis edilmeli: aksi halde bot /main.js\'i de
  // /og/main.js diye isteyip 404 alır.
  assert.match(parca, /try_files \$uri @spa;/,
    'statik dosyalar SPA geri dönüşünden önce servis edilmiyor');
  assert.match(parca, /location @spa/);
  // Uygulama adımları ve geri alma yazılı olmalı (6 Ağu parçasındaki disiplin).
  for (const bas of ['NEREYE', 'GERI ALMA', 'DOGRULAMA']) {
    assert.ok(parca.includes(bas), `nginx parçasında ${bas} bölümü yok`);
  }
});

test('robots.txt bilinen rotalar için hâlâ tutarlı (regresyon)', () => {
  // Tabloya rota eklemek robots.txt kararlarını DEĞİŞTİRMEZ: kişisel ekranlar
  // kapalı kalmalı. (Asıl kilit seo_gizlilik.test.js'te; bu, tablo üzerinden
  // ikinci bir kontrol.)
  for (const y of ['/kullanici/alcelik', '/hareketlerim', '/istatistiklerim',
    '/engellenenler', '/kitaplik/izliyorum', '/takvim']) {
    assert.ok(botRotasiVar(y), `tabloda yok: ${y}`);
    assert.ok(robotsKapali(y), `robots.txt ile kapatılmamış kişisel rota: ${y}`);
  }
});
