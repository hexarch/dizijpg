// ===========================================================================
// SEARCH CONSOLE İZLEME (21 Ağu 2026)
// ===========================================================================
//
// NE KİLİTLENİYOR VE NEDEN — her madde GERÇEK bir sessiz arıza biçimidir:
//
//  1) KİMLİK YOKKEN İŞ ÇÖKMEZ. Ama "hiç kurulmadı" (çıkış 0, sessiz) ile
//     "kurulmuştu, bozuldu" (çıkış 1, gürültülü) AYRILIR. İkisi de 0 olsaydı
//     silinen bir anahtar dosyası izlemeyi sonsuza dek sessizce öldürürdü.
//  2) DEĞİŞİM YOKSA POSTA GİTMEZ. Isıtıcının 5b dersi: "her şey aynı" maili
//     üçüncü haftada okunmamaya başlar ve asıl uyarı o kutuda kaybolur.
//  3) BEKLENEN ARTIŞ ALARM DEĞİL. Site haritası 2.518 → 80.936 URL oldu;
//     `bolum` ailesinde "keşfedildi – taranmadı" patlaması NORMAL. Alarm
//     sayarsak izleme daha ilk haftada güvenilirliğini kaybeder. AZALIŞI ise
//     haberdir ve gider.
//  4) KOVA KARARI `coverageState` METNİNE BAKMAZ. O alan API'de `string` ve
//     YERELLEŞTİRİLMİŞ; Google bir kelimeyi değiştirdiği gün eşleme sessizce
//     "bilinmiyor"a düşerdi. Karar yalnız KARARLI ENUM'lardan verilir.
//  5) KULLANIMDAN KALDIRILAN ALAN OKUNMAZ. `sitemaps` ucundaki
//     `contents[].indexed` Google tarafından "Deprecated; do not use" olarak
//     işaretli. Okusaydık "indekslenen" diye çöp bir sayı rapor ederdik.
//  6) EŞİK, ÖLÇÜMÜ ÜRETEN YÖNTEME GÖRE. Örneklenmiş sayıda istatistiksel
//     anlamlılık, kesin sayıda görece eşik, sıfır bariyerinde eşik YOK.
//     Sabit sayı eşiği ("100'den fazla") 2.453'lük ailede hiç ateşlemez,
//     78.480'liğinde her gün ateşler.
//  7) BAŞARISIZ DENETİM SAHTE DEĞİŞİM ÜRETMEZ. Karşılaştırma iki koşunun
//     KESİŞİMİ üzerinden yapılır; yoksa bir ağ hatası "500 sayfa indeksten
//     düştü" alarmı doğururdu.
//  8) GİZLİ DEĞER SIZMAZ. Hata metinleri hem cron günlüğüne hem E-POSTAYA
//     gidiyor; özel anahtar/jeton kısırlaştırılır.
//  9) POSTA TAŞIYICISI server.js İLE AYNI ORTAM DEĞİŞKENLERİNİ okur. Ayrışsa
//     rapor sessizce gitmezdi (server.js import EDİLEMEZ: `app.listen`).
// 10) PANEL SABİT ve KENDİ KENDİNİ TAZELER. Her gün yeni rastgele örnek,
//     aradığımız büyüklükteki değişimi (264 → 330) GÖREMEZ; hesap dosya
//     başlığında.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

import {
  AYAR, KOVA, KOVA_SIRA, IHLAL_KOVALARI, AYAR_AILE,
  hatayiKisirlastir, servisHesabiOku, iddiaUret,
  siniflandir, kumeAnahtari, locCoz, panelSec, panelleriKur,
  kovaBelirle, kovaSay, anlamliMi, sifirBariyeri, kesinEsik,
  degisimHesapla, tahminEt, sinyalleriBul, bildirimSebebi,
  raporMetni, konuSatiri, ozetSatiri, bayraklariCoz, pencereHesapla,
  durumOku, durumYaz, paneliDenetle, apiCagir, mulkYolu,
  siteHaritalari, aramaAnalitigi, raporGonder,
  kazananlariCoz, kazananlariYaz, KAZANAN_MIN_TIKLAMA,
} from '../gsc_izle.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const oku = (a) => fs.readFileSync(path.join(KOK, a), 'utf8');
const KAYNAK = oku('gsc_izle.js');
const SERVER = oku('server.js');
const gecici = () => fs.mkdtempSync(path.join(os.tmpdir(), 'gsc-izle-'));

// ---------------------------------------------------------------------------
// 1) KİMLİK — YOKKEN ÇÖKMEZ, AMA İKİ HÂL AYRILIR
// ---------------------------------------------------------------------------

test('kimlik dosyası YOK → çökme yok, anlaşılır sebep', () => {
  const r = servisHesabiOku('/boyle/bir/dosya/yok.json');
  assert.equal(r.hazir, false);
  assert.match(r.sebep, /servis hesabı anahtarı yok/);
  assert.match(r.sebep, /\/boyle\/bir\/dosya\/yok\.json/, 'hangi yola bakıldığı yazılmalı');
});

test('kimlik dosyası bozuk JSON → anlaşılır sebep, istisna FIRLATMAZ', () => {
  const d = gecici();
  const y = path.join(d, 'k.json');
  fs.writeFileSync(y, '{ bu json degil');
  const r = servisHesabiOku(y);
  assert.equal(r.hazir, false);
  assert.match(r.sebep, /geçerli JSON değil/);
});

test('eksik alan söylenir ama DEĞERİ asla basılmaz', () => {
  const d = gecici();
  const y = path.join(d, 'k.json');
  fs.writeFileSync(y, JSON.stringify({
    type: 'service_account', client_email: 'a@b.iam.gserviceaccount.com',
  }));
  const r = servisHesabiOku(y);
  assert.equal(r.hazir, false);
  assert.match(r.sebep, /private_key/, 'eksik alanın ADI söylenmeli');
  assert.ok(!/BEGIN/.test(r.sebep), 'anahtar gövdesi mesaja girmemeli');
});

test('OAuth istemci dosyası servis hesabı sanılmaz (en olası kurulum hatası)', () => {
  const d = gecici();
  const y = path.join(d, 'k.json');
  fs.writeFileSync(y, JSON.stringify({
    type: 'authorized_user', client_email: 'x@y.z', private_key: 'p',
  }));
  const r = servisHesabiOku(y);
  assert.equal(r.hazir, false);
  assert.match(r.sebep, /servis hesabı anahtarı değil/);
});

test('geçerli anahtar okunur; jetonUcu varsayılanı Google token ucudur', () => {
  const d = gecici();
  const y = path.join(d, 'k.json');
  fs.writeFileSync(y, JSON.stringify({
    type: 'service_account', client_email: 'iz@p.iam.gserviceaccount.com', private_key: 'PK',
  }));
  const r = servisHesabiOku(y);
  assert.equal(r.hazir, true);
  assert.equal(r.eposta, 'iz@p.iam.gserviceaccount.com');
  assert.equal(r.jetonUcu, 'https://oauth2.googleapis.com/token');
});

test('KAPSAM SALT-OKUNUR: jeton `webmasters.readonly` ister', () => {
  // Yazma kapsamı istenseydi bu jetonla site haritası SİLİNEBİLİRDİ. İzleme
  // işinin yazmaya hiçbir ihtiyacı yok; en az yetki ilkesi.
  assert.match(KAYNAK, /auth\/webmasters\.readonly/);
  assert.ok(!/auth\/webmasters'/.test(KAYNAK) && !/'https:\/\/www\.googleapis\.com\/auth\/webmasters'/.test(KAYNAK),
    'yazma kapsamı (webmasters) istenmemeli');
  assert.ok(!/auth\/indexing/.test(KAYNAK), 'Indexing API kapsamı istenmemeli');
});

test('JWT iddiası GERÇEKTEN imzalanır ve çözülebilir (davranış, kaynak iddiası değil)', async () => {
  // `googleapis` paketi EKLENMEDİ; imza için zaten bağımlılıkta olan
  // `jsonwebtoken` kullanılıyor. Bu akışın gerçekten çalıştığını kanıtla.
  const crypto = await import('node:crypto');
  const { privateKey, publicKey } = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
  const pem = privateKey.export({ type: 'pkcs8', format: 'pem' });
  const jwt = (await import('jsonwebtoken')).default;
  const t = iddiaUret({
    eposta: 'iz@p.iam.gserviceaccount.com',
    anahtar: pem,
    jetonUcu: 'https://oauth2.googleapis.com/token',
  }, Math.floor(Date.now() / 1000));
  const c = jwt.verify(t, publicKey.export({ type: 'spki', format: 'pem' }), { algorithms: ['RS256'] });
  assert.equal(c.iss, 'iz@p.iam.gserviceaccount.com');
  assert.equal(c.aud, 'https://oauth2.googleapis.com/token');
  assert.equal(c.scope, 'https://www.googleapis.com/auth/webmasters.readonly');
  assert.equal(c.exp - c.iat, 3600);
});

// ---------------------------------------------------------------------------
// 2) DAVRANIŞSAL: BETİK KİMLİK YOKKEN GERÇEKTEN ÇÖKMÜYOR
// ---------------------------------------------------------------------------
// Kaynak iddiası YETMEZ — betiği ÇALIŞTIRIP çıkış kodunu okuyoruz.

/**
 * Betiği ÇALIŞTIR ve {kod, cikti} döndür. Kaynak okumakla yetinmiyoruz:
 * "kimlik yokken çökmüyor" iddiası ancak süreç gerçekten koşup çıkış kodunu
 * verdiğinde kanıtlanır.
 */
function betigiKos(env, argv = []) {
  const r = spawnSync(process.execPath, [path.join(KOK, 'gsc_izle.js'), ...argv], {
    env: { ...process.env, ...env },
    encoding: 'utf8',
    timeout: 30000,
  });
  return { kod: r.status, cikti: `${r.stdout || ''}${r.stderr || ''}` };
}

test('KİMLİK YOK + HİÇ ÇALIŞMAMIŞ → çıkış 0, açıklayıcı mesaj (cron gürültüsü yok)', () => {
  const d = gecici();
  const r = betigiKos({
    GSC_SA_YOL: path.join(d, 'yok.json'),
    GSC_DURUM_YOL: path.join(d, 'durum.json'),
  });
  assert.equal(r.kod, 0, 'kurulum yapılmadan her gün hata koduyla dönmek cron gürültüsüdür');
  assert.match(r.cikti, /servis hesabı anahtarı yok/);
  assert.match(r.cikti, /İzleme ÇALIŞMIYOR, ama başka hiçbir şey etkilenmedi/);
  assert.ok(!/Cannot find module|TypeError|ReferenceError|at Object\./.test(r.cikti),
    `yığın izi ile çökmemeli:\n${r.cikti}`);
});

test('KİMLİK YOK + DAHA ÖNCE ÇALIŞMIŞ → çıkış 1 (sessiz ölüm YASAK)', () => {
  const d = gecici();
  const durumYol = path.join(d, 'durum.json');
  // Geçerli bir durum dosyası = "bu iş bir zamanlar çalışıyordu".
  fs.writeFileSync(durumYol, JSON.stringify({ surum: AYAR.DURUM_SURUM, tarih: new Date().toISOString() }));
  const r = betigiKos({ GSC_SA_YOL: path.join(d, 'yok.json'), GSC_DURUM_YOL: durumYol });
  assert.equal(r.kod, 1, 'çalışan bir izlemenin anahtarı kaybolduysa bu GERÇEK arızadır');
  assert.match(r.cikti, /servis hesabı anahtarı yok/);
});

test('bilinmeyen bayrak SESSİZCE yutulmaz', () => {
  const d = gecici();
  const r = betigiKos({ GSC_SA_YOL: path.join(d, 'yok.json'), GSC_DURUM_YOL: path.join(d, 'x.json') },
    ['--tanimsiz-bayrak']);
  assert.equal(r.kod, 2);
  assert.match(r.cikti, /Tanınmayan bayrak/);
});

test('--kuru ile --zorla-posta birlikte REDDEDİLİR', () => {
  assert.throws(() => bayraklariCoz(['--kuru', '--zorla-posta']), /birlikte kullanılamaz/);
});

test('--panel yalnız KÜÇÜLTÜR (kota tavanı yanlışlıkla aşılamaz)', () => {
  const ayar = JSON.parse(JSON.stringify({ PANEL: { icerik: 250, bolum: 250, genel: 25 } }));
  bayraklariCoz(['--panel=60'], ayar);
  assert.deepEqual(ayar.PANEL, { icerik: 60, bolum: 60, genel: 25 },
    'küçüğü büyütmemeli, büyüğü küçültmeli');
  bayraklariCoz(['--panel=9000'], ayar);
  assert.deepEqual(ayar.PANEL, { icerik: 60, bolum: 60, genel: 25 },
    '--panel ile kota tavanı AŞILAMAMALI');
});

// ---------------------------------------------------------------------------
// 3) KOVA EŞLEMESİ — YALNIZ KARARLI ENUM'LARDAN
// ---------------------------------------------------------------------------

test('KAYNAK İDDİASI: kova kararı `coverageState` metnine BAKMIYOR', () => {
  const bas = KAYNAK.indexOf('export function kovaBelirle');
  assert.ok(bas > 0);
  const govde = KAYNAK.slice(bas, KAYNAK.indexOf('\n}', bas));
  assert.ok(!/coverageState/.test(govde),
    'coverageState API\'de `string` ve YERELLEŞTİRİLMİŞ; ona dallanmak, Google '
    + 'metni değiştirdiği gün eşlemeyi SESSİZCE bozar');
  for (const alan of ['robotsTxtState', 'indexingState', 'pageFetchState', 'verdict', 'lastCrawlTime']) {
    assert.match(govde, new RegExp(alan), `${alan} kararın parçası olmalı`);
  }
});

test('coverageState yalan söylese bile kova ENUM\'a uyar', () => {
  // Google metni "Gönderildi ve dizine eklendi" dese de verdict PASS değilse
  // indeksli SAYMIYORUZ. Testin amacı: metnin hiçbir etkisi olmadığını görmek.
  assert.equal(
    kovaBelirle({ verdict: 'NEUTRAL', coverageState: 'Gönderildi ve dizine eklendi' }),
    KOVA.KESFEDILDI_TARANMADI,
  );
  assert.equal(
    kovaBelirle({ verdict: 'PASS', coverageState: 'Keşfedildi – dizine eklenmedi' }),
    KOVA.DIZINE_EKLENDI,
  );
});

test('keşfedildi ↔ tarandı ayrımını YALNIZ lastCrawlTime verir', () => {
  assert.equal(kovaBelirle({ verdict: 'NEUTRAL' }), KOVA.KESFEDILDI_TARANMADI);
  assert.equal(kovaBelirle({ verdict: 'NEUTRAL', lastCrawlTime: '2026-08-19T04:00:00Z' }),
    KOVA.TARANDI_EKLENMEDI);
});

test('ARIZA-ÖNCELİKLİ sıralama: 5xx, indeksli olsa bile kazanır', () => {
  // GSC arayüzü bunu "Dizine eklendi" sayar; BİZ arızayı görünür kılmak
  // istiyoruz. Ham `verdict=PASS` sayısı ayrıca raporlanıyor (indeksliHam),
  // yani arayüzle karşılaştırma yeteneği kaybolmuyor.
  assert.equal(kovaBelirle({ verdict: 'PASS', pageFetchState: 'SERVER_ERROR' }),
    KOVA.SUNUCU_HATASI);
  assert.equal(kovaBelirle({ verdict: 'PASS', pageFetchState: 'NOT_FOUND' }), KOVA.BULUNAMADI);
  assert.equal(kovaBelirle({ verdict: 'PASS', pageFetchState: 'SOFT_404' }), KOVA.YUMUSAK_404);
});

test('DEĞİŞMEZ İHLALLERİ her şeyin ÜSTÜNDE', () => {
  assert.equal(kovaBelirle({ verdict: 'PASS', robotsTxtState: 'DISALLOWED' }), KOVA.ROBOTS_ENGELLI);
  assert.equal(kovaBelirle({ verdict: 'PASS', indexingState: 'BLOCKED_BY_META_TAG' }), KOVA.NOINDEX);
  assert.equal(kovaBelirle({ verdict: 'PASS', indexingState: 'BLOCKED_BY_HTTP_HEADER' }), KOVA.NOINDEX);
});

test('tanınmayan/boş yanıt `bilinmiyor` olur — sessizce indeksli sayılmaz', () => {
  assert.equal(kovaBelirle(null), KOVA.BILINMIYOR);
  assert.equal(kovaBelirle({}), KOVA.BILINMIYOR);
  assert.equal(kovaBelirle({ verdict: 'VERDICT_UNSPECIFIED' }), KOVA.BILINMIYOR);
});

test('KOVA_SIRA her kovayı TAM BİR KEZ içerir (rapor satırı düşmesin)', () => {
  const hepsi = Object.values(KOVA);
  assert.deepEqual([...KOVA_SIRA].sort(), [...hepsi].sort());
  assert.equal(new Set(KOVA_SIRA).size, KOVA_SIRA.length);
});

// ---------------------------------------------------------------------------
// 4) KULLANIMDAN KALDIRILAN / OLMAYAN VERİ İDDİA EDİLMİYOR
// ---------------------------------------------------------------------------

/**
 * Yorumları at: kaynak iddiaları KOD üzerinde kurulmalı, açıklama üzerinde
 * değil (bu dosyanın açıklamaları uzun ve alan adlarını sık anıyor).
 * `//`den önce `:` varsa DOKUNMA — `https://` bir yorum değildir.
 */
const kodu = (s) => s
  .replace(/\/\*[\s\S]*?\*\//g, '')
  .replace(/(^|[^:])\/\/[^\n]*/g, '$1');

test('`sitemaps.contents[].indexed` OKUNMUYOR (Google: "Deprecated; do not use")', () => {
  const bas = KAYNAK.indexOf('export async function siteHaritalari');
  const govde = kodu(KAYNAK.slice(bas, KAYNAK.indexOf('\nconst kisaAd', bas)));
  assert.match(govde, /submitted/, 'gönderilen URL sayısı submitted alanından gelmeli');
  assert.ok(!/\.indexed\b|\['indexed'\]/.test(govde),
    'deprecated `indexed` alanı okunursa "indekslenen" diye çöp bir sayı raporlanır');
});

test('YALNIZ var olan uçlar çağrılıyor (uydurma uç yok)', () => {
  // Search Console API v1'in TAMAMI: searchanalytics · sitemaps · sites ·
  // urlInspection. "Sayfalar" (indeks kapsamı) raporunun API'si YOK; bu
  // dosyanın onu çağırıyormuş gibi görünmesi bile yanıltıcı olurdu.
  const IZINLI = new Set([
    'https://www.googleapis.com/webmasters/v3',
    'https://searchconsole.googleapis.com/v1/urlInspection/index:inspect',
    'https://www.googleapis.com/auth/webmasters.readonly',
    'https://oauth2.googleapis.com/token',
  ]);
  const ucler = [...kodu(KAYNAK).matchAll(/'(https:\/\/[^']*googleapis\.com[^']*)'/g)]
    .map((m) => m[1]);
  assert.ok(ucler.length >= 4, `beklenen uçlar bulunamadı: ${ucler}`);
  for (const u of ucler) assert.ok(IZINLI.has(u), `bilinmeyen/uydurma uç: ${u}`);
  assert.ok(!/indexCoverage|coverageReport|pagesReport|manualActions|securityIssues/i.test(KAYNAK),
    'API\'de OLMAYAN uçlar çağrılıyormuş gibi görünmemeli');
});

test('rapor, ölçemediklerini AÇIKÇA yazıyor', () => {
  const b = temelDurum();
  const m = raporMetni(b, null, [], null);
  assert.match(m, /BU RAPORUN ÖLÇEMEDİKLERİ/);
  assert.match(m, /Manuel işlem/);
  assert.match(m, /Core Web Vitals/);
  assert.match(m, /ÖRNEKLEME TAHMİNİ/);
  assert.match(m, /tahmin, sayım DEĞİL/i);
});

// ---------------------------------------------------------------------------
// 5) EŞİK MANTIĞI
// ---------------------------------------------------------------------------

test('anlamliMi: küçük oynama ateşlemez, sistematik kayma ateşler', () => {
  assert.equal(anlamliMi(0, 0), false, 'hiç hareket yoksa sinyal yok');
  assert.equal(anlamliMi(1, 0), false, 'tek URL Google\'ın olağan yeniden değerlendirmesi');
  assert.equal(anlamliMi(2, 0), false, '2σ = 2,83 > 2');
  assert.equal(anlamliMi(5, 5), false, 'dengeli gidiş-geliş = değişim YOK');
  assert.equal(anlamliMi(4, 0), true, '4 ≥ max(3, 2·√4=4)');
  assert.equal(anlamliMi(12, 1), true, '11 ≥ max(3, 2·√13≈7,2)');
  assert.equal(anlamliMi(0, 6), true, 'DÜŞÜŞ de anlamlıdır');
});

test('anlamliMi eşiği ölçekle BÜYÜR (gürültü de büyüdüğü için)', () => {
  // 100 gidiş 90 geliş: net +10 ama 2σ = 2·√190 ≈ 27,6 → sinyal YOK.
  assert.equal(anlamliMi(100, 90), false);
  assert.equal(anlamliMi(130, 60), true);
});

test('FLIP_TABAN, küçük sayılarda 2σ\'nın altına düşmeyi engeller', () => {
  // b=3,c=0 → 2σ=3,46 > 3 → ateşlemez. Taban olmasaydı da ateşlemezdi;
  // taban asıl b+c=1 gibi uçlarda koruyor.
  assert.equal(anlamliMi(3, 0), false);
  assert.equal(anlamliMi(1, 0), false);
});

test('sifirBariyeri: büyüklüğe BAKILMAZ, sıfırı geçmek her zaman haberdir', () => {
  assert.equal(sifirBariyeri(0, 1), true, 'kullanıcının asıl sorduğu soru');
  assert.equal(sifirBariyeri(1, 0), true);
  assert.equal(sifirBariyeri(0, 0), false);
  assert.equal(sifirBariyeri(2000, 3000), false, 'büyük değişim ama sıfır bariyeri değil');
});

test('kesinEsik: görece VE mutlak tabandan büyük olan uygulanır', () => {
  // 32 KAT büyüyen site haritasında sabit eşik anlamsız; oran taşır.
  assert.equal(kesinEsik(2518, 80936, 0.05, 500), true);
  assert.equal(kesinEsik(80936, 80900, 0.05, 500), false, 'küçük dalgalanma susmalı');
  assert.equal(kesinEsik(80936, 60000, 0.05, 500), true);
  // Küçük tabanda oran çok hassas olurdu; mutlak taban koruyor.
  assert.equal(kesinEsik(10, 20, 0.05, 500), false, '10→20: oran %100 ama mutlak taban 500');
  assert.equal(kesinEsik(0, 1, 0.05, 500), true, 'sıfır bariyeri mutlak tabanı EZER');
});

test('tahminEt: örnekten evrene ölçekler ve aralık verir', () => {
  const t = tahminEt(25, 250, 2453);
  assert.equal(t.tahmin, 245);
  assert.ok(t.aralik > 0 && t.aralik < 245, `aralık makul olmalı: ${t.aralik}`);
  assert.deepEqual(tahminEt(5, 0, 100), { tahmin: 0, aralik: 0, oran: 0 }, 'boş panelde bölme yok');
});

// ---------------------------------------------------------------------------
// 6) EŞLEŞMİŞ DEĞİŞİM — SAHTE ALARM ÜRETMİYOR
// ---------------------------------------------------------------------------

test('yalnız KESİŞİM karşılaştırılır: başarısız denetim "kayboldu" sayılmaz', () => {
  const dun = { a: KOVA.DIZINE_EKLENDI, b: KOVA.DIZINE_EKLENDI, c: KOVA.DIZINE_EKLENDI };
  const bugun = { a: KOVA.DIZINE_EKLENDI };   // b ve c denetlenemedi (ağ hatası)
  const d = degisimHesapla(dun, bugun);
  assert.equal(d.ortak, 1);
  assert.equal(d.kovalar[KOVA.DIZINE_EKLENDI].cikan, 0,
    'denetlenemeyen URL "indeksten düştü" sayılırsa her ağ hatası alarm üretir');
  assert.equal(d.dusenUrl, 2, 'ama panel değişimi olarak GÖRÜNÜR olmalı');
});

test('gerçek geçişler doğru kovalara yazılır', () => {
  const dun = { a: KOVA.KESFEDILDI_TARANMADI, b: KOVA.KESFEDILDI_TARANMADI, c: KOVA.DIZINE_EKLENDI };
  const bugun = { a: KOVA.DIZINE_EKLENDI, b: KOVA.TARANDI_EKLENMEDI, c: KOVA.DIZINE_EKLENDI };
  const d = degisimHesapla(dun, bugun);
  assert.equal(d.kovalar[KOVA.KESFEDILDI_TARANMADI].cikan, 2);
  assert.equal(d.kovalar[KOVA.DIZINE_EKLENDI].giren, 1);
  assert.equal(d.kovalar[KOVA.TARANDI_EKLENMEDI].giren, 1);
  assert.equal(d.kovalar[KOVA.DIZINE_EKLENDI].net, 1);
});

test('KÜME SAYIMI: tek dizinin 40 bölümü 40 bağımsız kanıt SAYILMAZ', () => {
  // Googlebot bir diziye girince onlarca bölümü birden tarar. URL sayısıyla
  // ölçseydik tek bir dizi eşiği sahte biçimde aşardı.
  const dun = {};
  const bugun = {};
  for (let i = 1; i <= 40; i++) {
    const u = `https://dizijpg.com/dizi/45/sezon/1/bolum/${i}`;
    dun[u] = KOVA.KESFEDILDI_TARANMADI;
    bugun[u] = KOVA.TARANDI_EKLENMEDI;
  }
  const d = degisimHesapla(dun, bugun);
  assert.equal(d.kovalar[KOVA.TARANDI_EKLENMEDI].giren, 40, 'insana gösterilen sayı URL sayısı');
  assert.equal(d.kovalar[KOVA.TARANDI_EKLENMEDI].girenKume, 1,
    'anlamlılığa giren sayı KÜME (dizi) sayısı olmalı');
  assert.equal(anlamliMi(1, 0), false, 'tek dizi tek başına eşiği aşmamalı');
});

test('kumeAnahtari: bölüm URL\'leri diziye, içerik URL\'leri kendine düşer', () => {
  assert.equal(kumeAnahtari('https://dizijpg.com/dizi/45/sezon/2/bolum/7'), '/dizi/45');
  assert.equal(kumeAnahtari('https://dizijpg.com/dizi/99/sezon/1/bolum/1'), '/dizi/99');
  assert.equal(kumeAnahtari('https://dizijpg.com/icerik/tv/1396'),
    'https://dizijpg.com/icerik/tv/1396');
});

// ---------------------------------------------------------------------------
// 7) SESSİZLİK DİSİPLİNİ
// ---------------------------------------------------------------------------

test('DEĞİŞİM YOKSA POSTA GİTMEZ (ısıtıcı 5b dersi)', () => {
  const dun = { tarih: new Date().toISOString() };
  assert.equal(bildirimSebebi(dun, [], 1, false), null);
  assert.equal(bildirimSebebi(dun, [], 5, false), null);
  assert.equal(bildirimSebebi(dun, [], 29, false), null);
});

test('İLK KOŞU temel ölçümü gönderir (bir kez) — kurulum doğrulanabilsin', () => {
  assert.equal(bildirimSebebi(null, [], 1, false), 'ilk');
});

test('sinyal varsa gider', () => {
  assert.equal(bildirimSebebi({ tarih: 'x' }, [{ agirlik: 2, metin: 'm' }], 1, false), 'sinyal');
});

test('AYLIK ÖZET: 30 sessiz koşudan sonra "boru canlı" postası', () => {
  const dun = { tarih: 'x' };
  assert.equal(bildirimSebebi(dun, [], 30, false), 'ozet');
  // Tam sessizlik istenirse kapatılabilir olmalı.
  assert.equal(bildirimSebebi(dun, [], 999, false, { ...AYAR, OZET_GUN: 0 }), null);
});

test('--zorla-posta sessizliği DELER (boru testi için)', () => {
  assert.equal(bildirimSebebi({ tarih: 'x' }, [], 1, true), 'zorla');
});

test('BEKLENEN ARTIŞ bildirilmez, AZALIŞI bildirilir', () => {
  // Site haritası 2.518 → 80.936 oldu; bölüm ailesinde "keşfedildi–taranmadı"
  // patlaması NORMAL. Alarm sayılırsa izleme ilk haftada güven kaybeder.
  const artis = ikiGun('bolum', KOVA.KESFEDILDI_TARANMADI, 20, 200);
  const s1 = sinyalleriBul(artis.bugun, artis.dun);
  assert.equal(s1.filter((x) => x.etiket === `panel/bolum/${KOVA.KESFEDILDI_TARANMADI}`).length, 0,
    'BEKLENEN artış postaya girmemeli');

  const azalis = ikiGun('bolum', KOVA.KESFEDILDI_TARANMADI, 200, 20);
  const s2 = sinyalleriBul(azalis.bugun, azalis.dun);
  assert.ok(s2.some((x) => x.etiket === `panel/bolum/${KOVA.KESFEDILDI_TARANMADI}`),
    'kuyruğun boşalması SEO-YAPILACAKLAR §0.1\'in gözden geçirme ölçütü — HABERDİR');
});

test('AYNI kova `icerik` ailesinde BEKLENEN sayılmaz', () => {
  const a = ikiGun('icerik', KOVA.KESFEDILDI_TARANMADI, 20, 200);
  const s = sinyalleriBul(a.bugun, a.dun);
  assert.ok(s.some((x) => x.etiket === `panel/icerik/${KOVA.KESFEDILDI_TARANMADI}`),
    'muafiyet AİLEYE özgü olmalı, kovaya değil');
});

// ---------------------------------------------------------------------------
// 8) SİNYAL ÜRETİMİ
// ---------------------------------------------------------------------------

test('hiç değişmeyen iki gün SIFIR sinyal üretir', () => {
  const dun = temelDurum();
  const bugun = temelDurum();
  bugun.degisim = Object.fromEntries(Object.keys(bugun.panel)
    .map((a) => [a, degisimHesapla(dun.panel[a], bugun.panel[a])]));
  assert.deepEqual(sinyalleriBul(bugun, dun), []);
});

test('DEĞİŞMEZ İHLALİ tek örnekte bile KRİTİK sinyal verir', () => {
  // SEO-YAPILACAKLAR §8 md.6: sitemap'te olup noindex yiyen sayfa ÜRETİLEMEZ.
  // %0,3 örnekle bir tane görmek, ailede yüzlercesi var demektir.
  const dun = temelDurum();
  const bugun = temelDurum();
  bugun.kovaSayim.icerik[KOVA.NOINDEX] = 1;
  bugun.degisim = bosDegisim(bugun);
  const s = sinyalleriBul(bugun, dun);
  const i = s.find((x) => x.etiket === `icerik/${KOVA.NOINDEX}`);
  assert.ok(i, 'tek noindex bile bildirilmeli');
  assert.equal(i.agirlik, 3);
  assert.match(i.metin, /DEĞİŞMEZ İHLALİ/);
});

test('404 tabanı 2: tek örnek susar, iki örnek konuşur', () => {
  // 404 bizim hatamız OLMADAN da oluşabilir (harita üretimi ile denetim
  // arasında TMDB'den kayıt düşerse). Tek örnek gürültü, iki örnek desen.
  const dun = temelDurum();
  const b1 = temelDurum();
  b1.kovaSayim.icerik[KOVA.BULUNAMADI] = 1;
  b1.degisim = bosDegisim(b1);
  assert.equal(sinyalleriBul(b1, dun).filter((x) => /bulunamadi/.test(x.etiket)).length, 0);

  const b2 = temelDurum();
  b2.kovaSayim.icerik[KOVA.BULUNAMADI] = 2;
  b2.degisim = bosDegisim(b2);
  assert.equal(sinyalleriBul(b2, dun).filter((x) => /bulunamadi/.test(x.etiket)).length, 1);
});

test('5xx TEK örnekte bildirilir (§6.9 hedefi 32 → 0 idi)', () => {
  const dun = temelDurum();
  const bugun = temelDurum();
  bugun.kovaSayim.icerik[KOVA.SUNUCU_HATASI] = 1;
  bugun.degisim = bosDegisim(bugun);
  const s = sinyalleriBul(bugun, dun);
  assert.ok(s.some((x) => x.etiket === 'icerik/5xx' && x.agirlik === 3));
});

test('SIFIR BARİYERİ: bölüm ailesi ilk kez gösterim alınca KRİTİK', () => {
  // Kullanıcının asıl sorduğu soru. `searchanalytics` KESİN ölçüm — örnekleme
  // yok, eşik yok: 0 → herhangi bir sayı her zaman bildirilir.
  const dun = temelDurum();
  const bugun = temelDurum();
  bugun.arama.sayfa.bolum = 3;
  bugun.degisim = bosDegisim(bugun);
  const s = sinyalleriBul(bugun, dun);
  const z = s.find((x) => x.etiket === 'arama/bolum/sifir');
  assert.ok(z, 'sıfırdan çıkış her zaman bildirilmeli');
  assert.equal(z.agirlik, 3);
  assert.match(z.metin, /İLK KEZ/);
});

test('SIFIR BARİYERİ: panelde taranmış bölüm sayfası belirince KRİTİK', () => {
  const dun = temelDurum();
  const bugun = temelDurum();
  bugun.kovaSayim.bolum[KOVA.TARANDI_EKLENMEDI] = 2;
  bugun.degisim = bosDegisim(bugun);
  const s = sinyalleriBul(bugun, dun);
  assert.ok(s.some((x) => x.etiket === 'panel/bolum/tarandi-sifir' && x.agirlik === 3),
    'BEKLENEN_ARTIS muafiyeti "taranmaya başladı" sinyalini BASTIRMAMALI');
});

test('İZLEMENİN KENDİ ARIZASI bildirilir (sessiz kalmak en kötüsü)', () => {
  const dun = temelDurum();
  const bugun = temelDurum();
  bugun.denetimHatasi.icerik = 200;    // 200/(50+200) = %80 > %20
  bugun.panelN.icerik = 50;
  bugun.degisim = bosDegisim(bugun);
  const s = sinyalleriBul(bugun, dun);
  assert.ok(s.some((x) => x.etiket === 'arıza/icerik' && x.agirlik === 3));
});

test('CRON ÖLÜP GERİ GELİRSE bildirilir', () => {
  const dun = temelDurum();
  dun.tarih = new Date(Date.now() - 9 * 86400000).toISOString();
  const bugun = temelDurum();
  bugun.degisim = bosDegisim(bugun);
  const s = sinyalleriBul(bugun, dun);
  const a = s.find((x) => x.etiket === 'arıza/ara');
  assert.ok(a, 'aradaki değişim GÖRÜLMEDİ uyarısı gelmeli');
  assert.match(a.metin, /İZLEME DURMUŞTU/);
});

test('site haritası HATASI ve BAYATLIĞI bildirilir', () => {
  const dun = temelDurum();
  const b1 = temelDurum();
  b1.siteHaritasi.parcalar['sitemap-icerik-1.xml'].hata = 4;
  b1.degisim = bosDegisim(b1);
  assert.ok(sinyalleriBul(b1, dun).some((x) => /harita\/.*\/hata/.test(x.etiket)));

  const b2 = temelDurum();
  b2.siteHaritasi.parcalar['sitemap-icerik-1.xml'].sonIndirme =
    new Date(Date.now() - 20 * 86400000).toISOString();
  b2.degisim = bosDegisim(b2);
  assert.ok(sinyalleriBul(b2, dun).some((x) => /harita\/.*\/bayat/.test(x.etiket)));
});

test('sinyaller AĞIRLIĞA göre sıralı gelir (konu satırı en ağırı taşısın)', () => {
  const dun = temelDurum();
  const bugun = temelDurum();
  bugun.kovaSayim.icerik[KOVA.NOINDEX] = 2;            // ağırlık 3
  bugun.siteHaritasi.toplam = 200000;                   // ağırlık 2
  bugun.degisim = bosDegisim(bugun);
  const s = sinyalleriBul(bugun, dun);
  assert.ok(s.length >= 2);
  assert.equal(s[0].agirlik, 3);
  assert.match(konuSatiri(bugun, s, 'sinyal'), /dizi\.jpg GSC —/);
});

// ---------------------------------------------------------------------------
// 9) PANEL SEÇİMİ
// ---------------------------------------------------------------------------

const sahteUrl = (n, on = 'https://dizijpg.com/icerik/tv/') =>
  Array.from({ length: n }, (_, i) => `${on}${i + 1}`);

test('panel SABİT: aynı evren her zaman aynı paneli verir (eşleşmiş karşılaştırma)', () => {
  const e = sahteUrl(5000);
  assert.deepEqual(panelSec(e, 250), panelSec(e, 250));
  assert.deepEqual(panelSec([...e].reverse(), 250), panelSec(e, 250),
    'girdi sırası paneli DEĞİŞTİRMEMELİ');
});

test('panel BOYUTU sabit kalır — evren 32 kat büyüse bile (kota koruması)', () => {
  assert.equal(panelSec(sahteUrl(2500), 250).length, 250);
  assert.equal(panelSec(sahteUrl(80000), 250).length, 250);
});

test('panel KENDİ KENDİNİ TAZELER: evren büyüyünce çoğu üye kalır', () => {
  const kucuk = sahteUrl(2500);
  const buyuk = [...kucuk, ...sahteUrl(500, 'https://dizijpg.com/icerik/movie/')];
  const a = new Set(panelSec(kucuk, 250));
  const b = panelSec(buyuk, 250);
  const kalan = b.filter((u) => a.has(u)).length;
  // %20 büyüme → beklenen kalıcılık ~%83. Çok düşerse eşleşme zayıflar.
  assert.ok(kalan > 180, `panelin çoğu korunmalı, kalan=${kalan}`);
  assert.ok(kalan < 250, 'yeni URL\'ler de panele girebilmeli');
});

test('panel TEKDÜZE: evrenin belli bir bölgesine yığılmıyor', () => {
  const p = panelSec(sahteUrl(10000), 500);
  const yarim = p.filter((u) => Number(u.split('/').pop()) <= 5000).length;
  // Tekdüze olsa ~250 beklenir; ±5σ (≈56) dışına çıkarsa hash bozuk demektir.
  assert.ok(Math.abs(yarim - 250) < 60, `ilk yarıdan ${yarim} çıktı — tekdüze değil`);
});

test('harita indirilemezse panel DÜNKÜ listeden kurtarılır', () => {
  const dun = Object.fromEntries(sahteUrl(30).map((u) => [u, KOVA.DIZINE_EKLENDI]));
  const p = panelSec([], 250, Object.keys(dun));
  assert.equal(p.length, 30, 'dünkü paneli denetlemek, hiç denetlememekten iyidir');
});

test('panelleriKur aileleri AYIRIR (katmanlı örnekleme)', () => {
  const urller = [
    ...sahteUrl(3000, 'https://dizijpg.com/icerik/tv/'),
    ...Array.from({ length: 9000 }, (_, i) => `https://dizijpg.com/dizi/${i}/sezon/1/bolum/1`),
    ...sahteUrl(10000, 'https://dizijpg.com/kisi/'),
    ...sahteUrl(224, 'https://dizijpg.com/sirket/'),
    'https://dizijpg.com/',
  ];
  const { panel, evren } = panelleriKur(urller, {}, AYAR);
  assert.equal(evren.icerik, 3000);
  assert.equal(evren.bolum, 9000);
  assert.equal(evren.kisi, 10000);
  assert.equal(evren.sirket, 224);
  assert.equal(evren.genel, 1);
  for (const ad of Object.keys(AYAR.PANEL)) {
    const beklenen = Math.min(AYAR.PANEL[ad], evren[ad]);
    assert.equal(panel[ad].length, beklenen, `${ad} paneli`);
    assert.ok(panel[ad].every((u) => siniflandir(u) === ad),
      `${ad} paneline başka aileden URL sızmış`);
  }
});

test('panel toplamı kota tavanının ALTINDA kalır', () => {
  // Kota mülk başına 2.000 denetim/gün; `AZAMI_DENETIM` sert tavan.
  // Yeni aile eklerken panel büyütmek KOLAY, kotayı aşmak SESSİZDİR:
  // 429 yenilebilir bir hata değil, günlük kotayı da yakar.
  const toplam = Object.values(AYAR.PANEL).reduce((a, b) => a + b, 0);
  assert.ok(toplam <= AYAR.AZAMI_DENETIM,
    `panel toplamı ${toplam} > AZAMI_DENETIM ${AYAR.AZAMI_DENETIM}`);
  assert.ok(toplam <= 1000, `panel toplamı ${toplam} — kotanın yarısını aşıyor`);
});

test('KATMANLI olmasaydı içerik ailesi görünmez olurdu (gerekçenin kanıtı)', () => {
  // 2.453 içerik + 78.480 bölüm. Tek küresel 250'lik örnekte beklenen içerik
  // sayısı 250 × 2453/80936 ≈ 7,6 — hiçbir şey ölçemezdi.
  const beklenen = 250 * (2453 / 80936);
  assert.ok(beklenen < 10, `küresel örnekte içerikten ~${beklenen.toFixed(1)} URL düşerdi`);
  assert.equal(AYAR.PANEL.icerik, 250, 'bu yüzden içerik AYRI panel alıyor');
});

test('siniflandir: aileler doğru ayrılıyor, tanınmayan yol GENELE düşer', () => {
  assert.equal(siniflandir('https://dizijpg.com/icerik/movie/603'), 'icerik');
  assert.equal(siniflandir('https://dizijpg.com/icerik/tv/1396/'), 'icerik');
  assert.equal(siniflandir('https://dizijpg.com/dizi/1396/sezon/5/bolum/16'), 'bolum');
  // 28 Ağu 2026'ya kadar kişi/şirket `genel`e düşüyordu — site haritasının
  // %58'i (10.748 URL) 25 URL'lik bir panelle "ölçülüyor" görünüyordu.
  assert.equal(siniflandir('https://dizijpg.com/kisi/102426'), 'kisi');
  assert.equal(siniflandir('https://dizijpg.com/sirket/420'), 'sirket');
  assert.equal(siniflandir('https://dizijpg.com/gozat'), 'genel');
  assert.equal(siniflandir('bozuk url'), 'genel', 'hiçbir URL kaybolmamalı');
  assert.deepEqual(Object.keys(AYAR_AILE).sort(),
    ['bolum', 'genel', 'icerik', 'kisi', 'sirket']);
  // Her ailenin paneli OLMALI: panelsiz aile sessizce ölçülmez.
  for (const ad of Object.keys(AYAR_AILE)) {
    assert.ok(AYAR.PANEL[ad] > 0, `${ad} ailesinin paneli yok`);
  }
});

test('locCoz site haritası XML\'ini çözer', () => {
  const xml = `<?xml version="1.0"?><urlset>
    <url><loc>https://dizijpg.com/icerik/tv/1</loc><lastmod>2026-08-21</lastmod></url>
    <url><loc>  https://dizijpg.com/icerik/tv/2  </loc></url></urlset>`;
  assert.deepEqual(locCoz(xml),
    ['https://dizijpg.com/icerik/tv/1', 'https://dizijpg.com/icerik/tv/2']);
  assert.deepEqual(locCoz(''), []);
});

// ---------------------------------------------------------------------------
// 10) PANEL KOŞUSU — TAVAN VE KOTA
// ---------------------------------------------------------------------------

test('AZAMI_DENETIM sert tavanı GERÇEKTEN uygulanır', async () => {
  let n = 0;
  const r = await paneliDenetle({
    panel: { icerik: sahteUrl(50), bolum: sahteUrl(50, 'https://dizijpg.com/dizi/1/sezon/1/bolum/') },
    denetle: async () => { n++; return { tamam: true, sonuc: { verdict: 'PASS' } }; },
    ayar: { ...AYAR, AZAMI_DENETIM: 30, DENETIM_SN: 1e6 },
    bekleyici: async () => {},
  });
  assert.equal(n, 30, 'panel ayarı yanlışlıkla büyütülse bile kota korunmalı');
  assert.equal(r.istek, 30);
});

test('429 (kota) gelince koşu HEMEN durur — kalan istekler de yanardı', async () => {
  let n = 0;
  const r = await paneliDenetle({
    panel: { icerik: sahteUrl(100) },
    denetle: async () => { n++; return { tamam: false, kod: 429, hata: 'kota' }; },
    ayar: { ...AYAR, DENETIM_SN: 1e6 },
    bekleyici: async () => {},
  });
  assert.equal(n, 1);
  assert.equal(r.kotaBitti, true);
});

test('başarısız denetim sonuç haritasına GİRMEZ ama SAYILIR', async () => {
  let i = 0;
  const r = await paneliDenetle({
    panel: { icerik: sahteUrl(4) },
    denetle: async () => (++i % 2
      ? { tamam: true, sonuc: { verdict: 'PASS', coverageState: 'Gönderildi ve dizine eklendi' } }
      : { tamam: false, kod: 500, hata: 'ağ' }),
    ayar: { ...AYAR, DENETIM_SN: 1e6 },
    bekleyici: async () => {},
  });
  assert.equal(Object.keys(r.sonuc.icerik).length, 2);
  assert.equal(r.hata.icerik, 2);
  assert.equal(r.indeksliHam.icerik, 2, 'ham verdict=PASS ayrıca sayılmalı (arayüzle karşılaştırma)');
  assert.equal(r.hamEtiket.icerik['Gönderildi ve dizine eklendi'], 2,
    'Google\'ın kendi etiketi DOĞRULAMA için toplanmalı');
});

test('HIZ KAPISI var: denetimler arasında bekleniyor (600/dk tavanı)', async () => {
  const beklemeler = [];
  await paneliDenetle({
    panel: { icerik: sahteUrl(3) },
    denetle: async () => ({ tamam: true, sonuc: { verdict: 'PASS' } }),
    ayar: { ...AYAR, DENETIM_SN: 3 },
    bekleyici: async (ms) => { beklemeler.push(ms); },
  });
  assert.ok(beklemeler.length >= 2, 'ardışık isteklerde bekleme olmalı');
  assert.ok(beklemeler.every((m) => m <= Math.ceil(1000 / 3)), 'bekleme 1/DENETIM_SN\'yi aşmamalı');
});

// ---------------------------------------------------------------------------
// 11) API SARMALAYICISI
// ---------------------------------------------------------------------------

const sahteCevap = (durum, govde) => ({
  ok: durum >= 200 && durum < 300,
  status: durum,
  json: async () => govde,
  text: async () => (typeof govde === 'string' ? govde : JSON.stringify(govde)),
});

test('403 YENİDEN DENENMEZ ve ipucu taşır (en sık kurulum hatası)', async () => {
  let n = 0;
  const r = await apiCagir('https://x/y', {}, 'jeton', AYAR, async () => { n++; return sahteCevap(403, 'denied'); });
  assert.equal(n, 1, 'yetki hatasını 3 kez tekrarlamak yalnız kotayı yakar');
  assert.equal(r.tamam, false);
  assert.match(r.hata, /Kullanıcılar ve izinler/);
  assert.match(r.hata, /sc-domain:dizijpg\.com/, 'mülk türü tuzağı hatırlatılmalı');
});

test('429 YENİDEN DENENMEZ (kotayı daha çok yakardı)', async () => {
  let n = 0;
  const r = await apiCagir('https://x/y', {}, 'j', AYAR, async () => { n++; return sahteCevap(429, 'quota'); });
  assert.equal(n, 1);
  assert.equal(r.kod, 429);
  assert.match(r.hata, /2\.000\/gün/);
});

test('5xx YENİDEN DENENİR', async () => {
  let n = 0;
  const r = await apiCagir('https://x/y', {}, 'j', { ...AYAR, DENEME: 3 }, async () => {
    n++;
    return n < 3 ? sahteCevap(503, 'gecici') : sahteCevap(200, { iyi: true });
  });
  assert.equal(n, 3);
  assert.deepEqual(r.veri, { iyi: true });
});

test('mülk kimliği yol parçası olarak KAÇIŞLANIR (sc-domain: iki nokta taşır)', () => {
  assert.equal(mulkYolu('sc-domain:dizijpg.com'), 'sc-domain%3Adizijpg.com');
  assert.equal(mulkYolu('https://dizijpg.com/'), 'https%3A%2F%2Fdizijpg.com%2F');
});

test('siteHaritalari: dizin dosyası TOPLAMA girmez (URL iki kez sayılmasın)', async () => {
  const getirici = async () => sahteCevap(200, {
    sitemap: [
      { path: 'https://dizijpg.com/sitemap.xml', isSitemapsIndex: true, contents: [{ submitted: '80936' }] },
      { path: 'https://dizijpg.com/sitemap-icerik-1.xml', lastDownloaded: '2026-08-21T00:00:00Z', contents: [{ type: 'web', submitted: '2453', indexed: '0' }] },
      { path: 'https://dizijpg.com/sitemap-bolum-1.xml', contents: [{ type: 'web', submitted: '20000' }], errors: 0, warnings: 2 },
    ],
  });
  const r = await siteHaritalari('sc-domain:dizijpg.com', 'j', AYAR, getirici);
  assert.equal(r.toplam, 22453, 'dizin sayılsaydı 103.389 çıkardı');
  assert.equal(r.parcalar['sitemap-icerik-1.xml'].gonderilen, 2453);
  assert.equal(r.parcalar['sitemap-bolum-1.xml'].uyari, 2);
  assert.ok(!('indekslenen' in r.parcalar['sitemap-icerik-1.xml']),
    'deprecated `indexed` alanı çıktıya SIZMAMALI');
});

test('aramaAnalitigi: sayfaları AİLEYE göre sayar, tıklama/gösterim toplar', async () => {
  const getirici = async () => sahteCevap(200, {
    rows: [
      { keys: ['https://dizijpg.com/icerik/tv/1396'], clicks: 0, impressions: 40 },
      { keys: ['https://dizijpg.com/icerik/movie/603'], clicks: 1, impressions: 30 },
      { keys: ['https://dizijpg.com/dizi/45/sezon/1/bolum/2'], clicks: 0, impressions: 7 },
    ],
  });
  const r = await aramaAnalitigi('sc-domain:dizijpg.com', 'j',
    { bas: '2026-08-12', son: '2026-08-18' }, AYAR, getirici);
  assert.equal(r.tamam, true);
  assert.equal(r.gosterim, 77);
  assert.equal(r.tiklama, 1);
  // Aile anahtarları `AYAR_AILE`den türer: kişi/şirket 28 Ağu 2026'da
  // eklendiği için gösterim almasalar da 0 ile listede DURURLAR — sıfır
  // görünmesi, ailenin ölçüldüğünün kanıtı.
  assert.deepEqual(r.sayfa,
    { icerik: 2, bolum: 1, kisi: 0, sirket: 0, genel: 0 });
});

test('aramaAnalitigi `dataState: all` KULLANMAZ (kesinleşmemiş veri sahte düşüş üretir)', () => {
  const bas = KAYNAK.indexOf('export async function aramaAnalitigi');
  const govde = KAYNAK.slice(bas, KAYNAK.indexOf('/** B-SINIFI', bas));
  assert.ok(!/dataState/.test(govde.replace(/\/\/[^\n]*/g, '')),
    'dataState verilmemeli → varsayılan `final`');
  assert.match(govde, /rowLimit: SAYFA/);
  assert.match(govde, /startRow: bas/, 'sayfalama olmalı (25.000 satır tavanı)');
});

// ---------------------------------------------------------------------------
// 12) GİZLİ DEĞER SIZDIRMAMA
// ---------------------------------------------------------------------------

test('özel anahtar, jeton ve Bearer başlığı kısırlaştırılır', () => {
  const k = hatayiKisirlastir('hata: -----BEGIN PRIVATE KEY-----MIIEvQ...-----END PRIVATE KEY-----');
  assert.ok(!/MIIEvQ/.test(k));
  assert.match(k, /«özel anahtar»/);

  assert.match(hatayiKisirlastir('Authorization: Bearer ya29.a0AfB_x'), /«jeton»/);
  assert.ok(!/ya29\.a0AfB_x/.test(hatayiKisirlastir('ya29.a0AfB_x çöktü')));
  assert.match(hatayiKisirlastir('{"access_token":"secret123"}'), /«gizli»/);
});

test('kısırlaştırma çok uzun gövdeyi kırpar (posta/günlük şişmesin)', () => {
  assert.ok(hatayiKisirlastir('x'.repeat(50000)).length <= 2000);
});

test('KAYNAK İDDİASI: anahtar/jeton hiçbir yere BASILMIYOR', () => {
  assert.ok(!/console\.(log|error)\([^)]*hesap\.anahtar/.test(KAYNAK));
  assert.ok(!/console\.(log|error)\([^)]*jeton\b(?!Ucu)/.test(KAYNAK.replace(/«jeton»/g, '')));
  // Durum dosyası da diske yazılıyor — oraya da gizli değer girmemeli.
  const bas = KAYNAK.indexOf('const bugun = {');
  const govde = KAYNAK.slice(bas, KAYNAK.indexOf('bugun.degisim =', bas));
  assert.ok(!/hesap|jeton|anahtar/.test(govde), 'durum dosyasına kimlik bilgisi yazılmamalı');
});

// ---------------------------------------------------------------------------
// 13) POSTA KANALI
// ---------------------------------------------------------------------------

test('posta taşıyıcısı server.js İLE AYNI ortam değişkenlerini okur', () => {
  // server.js import EDİLEMEZ (`app.listen` tetikleniyor — isitici.js 2.
  // kararıyla aynı kısıt), bu yüzden taşıyıcı burada yeniden kuruldu.
  // Ayrışırsa rapor SESSİZCE gitmez. Bu test kaymayı yakalar.
  const s = SERVER.slice(SERVER.indexOf('const MAIL_FROM'), SERVER.indexOf('// Kod mailleri'));
  for (const d of ['MAIL_HOST', 'MAIL_PORT', 'MAIL_FROM']) {
    assert.match(s, new RegExp(`process\\.env\\.${d}`), `server.js ${d} okuyor olmalı`);
    assert.match(KAYNAK, new RegExp(`env\\.${d}`), `gsc_izle ${d} okumalı`);
  }
  assert.match(s, /host\.docker\.internal/);
  assert.match(KAYNAK, /host\.docker\.internal/, 'aynı varsayılan host kullanılmalı');
  assert.match(s, /ignoreTLS: true/);
  assert.match(KAYNAK, /ignoreTLS: true/);
});

test('alıcı varsayılanı admin@dizijpg.com — admin panelinde de GÖRÜNÜR', async () => {
  // docker-compose /home/admin/Maildir'i `/mail/admin` olarak SALT-OKUNUR
  // bağlıyor; yani rapor hem postaya hem panelin "Mailler" sekmesine düşer.
  let gonderilen = null;
  const alici = await raporGonder('konu', 'gövde', {},
    () => ({ sendMail: async (m) => { gonderilen = m; } }));
  assert.equal(alici, 'admin@dizijpg.com');
  assert.equal(gonderilen.to, 'admin@dizijpg.com');
  assert.equal(gonderilen.subject, 'konu');
  assert.equal(gonderilen.text, 'gövde');
  assert.ok(!gonderilen.html, 'düz metin yeterli; HTML posta yüzeyi açmıyoruz');
});

test('GSC_MAIL_ALICI alıcıyı ezer', async () => {
  const alici = await raporGonder('k', 'g', { GSC_MAIL_ALICI: 'baska@dizijpg.com' },
    () => ({ sendMail: async () => {} }));
  assert.equal(alici, 'baska@dizijpg.com');
});

test('posta gidemezse rapor KAYBOLMAZ (günlüğe basılır)', () => {
  const bas = KAYNAK.indexOf('POSTA GÖNDERİLEMEDİ');
  assert.ok(bas > 0);
  assert.match(KAYNAK.slice(bas, bas + 200), /console\.error\(rapor\)/,
    'posta düşerse tek kopya cron günlüğünde kalmalı');
});

// ---------------------------------------------------------------------------
// 14) DURUM DOSYASI
// ---------------------------------------------------------------------------

test('durum dosyası yoksa ilk koşu sayılır (hata DEĞİL)', () => {
  assert.equal(durumOku(path.join(gecici(), 'yok.json')), null);
});

test('BİÇİM SÜRÜMÜ tutmuyorsa karşılaştırma YAPILMAZ', () => {
  const y = path.join(gecici(), 'd.json');
  fs.writeFileSync(y, JSON.stringify({ surum: 999, kovaSayim: { icerik: {} } }));
  assert.equal(durumOku(y), null,
    'yarı uyumlu bir dosyayı karşılaştırmak gerçek olmayan "değişim" üretir');
});

test('bozuk durum dosyası çökertmez', () => {
  const y = path.join(gecici(), 'd.json');
  fs.writeFileSync(y, 'yarim json {');
  assert.equal(durumOku(y), null);
});

test('durum ATOMİK yazılır (yarım JSON bırakmaz) ve geri okunur', () => {
  const d = gecici();
  const y = path.join(d, 'alt', 'dizin', 'durum.json');
  const veri = { surum: AYAR.DURUM_SURUM, tarih: '2026-08-21T00:00:00.000Z', x: 1 };
  durumYaz(y, veri);
  assert.deepEqual(durumOku(y), veri);
  assert.ok(!fs.existsSync(`${y}.gecici`), 'geçici dosya rename ile temizlenmeli');
  // Kaynak iddiası: yerinde yazan bir sürüm koşu ortasında kesilirse ertesi
  // gün karşılaştırma sessizce kaybolurdu.
  const bas = KAYNAK.indexOf('export function durumYaz');
  assert.match(KAYNAK.slice(bas, bas + 400), /renameSync/);
});

// ---------------------------------------------------------------------------
// 15) RAPOR VE KALP ATIŞI
// ---------------------------------------------------------------------------

test('rapor üretilir, tahmin olduğunu SÖYLER ve kör noktayı yazar', () => {
  const dun = temelDurum();
  const bugun = temelDurum();
  bugun.kovaSayim.icerik[KOVA.DIZINE_EKLENDI] = 33;
  bugun.degisim = bosDegisim(bugun);
  const m = raporMetni(bugun, dun, sinyalleriBul(bugun, dun), null);
  assert.match(m, /KESİN ÖLÇÜMLER \(örnekleme yok\)/);
  assert.match(m, /ÖRNEKLENMİŞ ÖLÇÜMLER/);
  assert.match(m, /KÖR NOKTA/, 'bölüm panelinin göremediği aralık yazılmalı');
  assert.match(m, /ham verdict=PASS/, 'arayüzle karşılaştırılacak sayı gösterilmeli');
  assert.match(m, /GOOGLE'IN KENDİ ETİKETLERİ/);
});

test('ilk koşu raporu, kullanıcıya DOĞRULAMA görevini söyler', () => {
  const b = temelDurum();
  const m = raporMetni(b, null, [], 'ilk koşu — temel ölçüm. Bu raporu GSC arayüzüyle karşılaştır.');
  assert.match(m, /GÖNDERİM SEBEBİ/);
  assert.match(m, /Karşılaştırma tabanı YOK/);
});

test('KALP ATIŞI: her koşuda tek satır özet (cron ölü mü canlı mı)', () => {
  const b = temelDurum();
  const s = ozetSatiri(b, [], false);
  assert.match(s, /gsc_izle koşusu bitti/);
  assert.match(s, /bölüm_sayfa=0/, 'asıl izlenen sayı özet satırında olmalı');
  assert.match(s, /posta=yok/);
  assert.match(s, /sinyal=0/);
  assert.equal(s.split('\n').length, 1, 'TEK satır — günlük şişmesin');
});

test('pencereHesapla: gecikmeli ve KESİNLEŞMİŞ veri penceresi', () => {
  const p = pencereHesapla(Date.parse('2026-08-21T12:00:00Z'));
  assert.equal(p.son, '2026-08-18', 'GSC verisi gecikmeli; taze günler eksik gelir');
  assert.equal(p.bas, '2026-08-12');
  const gun = (Date.parse(p.son) - Date.parse(p.bas)) / 86400000 + 1;
  assert.equal(gun, AYAR.ARAMA_PENCERE_GUN);
});

// ---------------------------------------------------------------------------
// 16) AYAR TUTARLILIĞI
// ---------------------------------------------------------------------------

test('panel toplamı günlük denetim kotasının YARISINI aşmıyor', () => {
  const toplam = Object.values(AYAR.PANEL).reduce((a, b) => a + b, 0);
  assert.ok(toplam <= 1000, `panel toplamı ${toplam}; mülk kotası 2.000/gün`);
  assert.ok(AYAR.AZAMI_DENETIM <= 2000, 'sert tavan da kotanın altında olmalı');
  assert.ok(toplam <= AYAR.AZAMI_DENETIM, 'sert tavan paneli kesmemeli');
});

test('denetim hızı dakikalık tavanın (600/dk) ALTINDA', () => {
  assert.ok(AYAR.DENETIM_SN * 60 < 600, `${AYAR.DENETIM_SN * 60}/dk — tavana dayanmamalı`);
});

test('BEKLENEN_ARTIS listesi tanınan aile ve kova adları kullanıyor', () => {
  for (const b of AYAR.BEKLENEN_ARTIS) {
    assert.ok(b.sinif in AYAR.PANEL, `bilinmeyen aile: ${b.sinif}`);
    assert.ok(KOVA_SIRA.includes(b.kova), `bilinmeyen kova: ${b.kova}`);
  }
});

test('IHLAL_KOVALARI gerçekten BİZİM kodumuzun ürettiği durumlar', () => {
  assert.ok(IHLAL_KOVALARI.has(KOVA.NOINDEX));
  assert.ok(IHLAL_KOVALARI.has(KOVA.ROBOTS_ENGELLI));
  assert.ok(!IHLAL_KOVALARI.has(KOVA.KESFEDILDI_TARANMADI),
    'Google\'ın tarama kararı bizim "değişmezimiz" değildir');
});

test('Dockerfile gsc_izle.js\'i imaja KOPYALIYOR', () => {
  // Kopyalanmazsa `docker exec dizijpg-api node gsc_izle.js` her gece
  // "Cannot find module" verir ve izleme hiç başlamaz — isitici.js ile aynı tuzak.
  assert.match(oku('Dockerfile'), /COPY [^\n]*\bgsc_izle\.js\b/);
});

test('kova sayımı her kovayı içerir (rapor satırı sessizce düşmesin)', () => {
  const s = kovaSay({ a: KOVA.DIZINE_EKLENDI });
  for (const k of KOVA_SIRA) assert.ok(k in s, `${k} sayımda yok`);
  assert.equal(s[KOVA.DIZINE_EKLENDI], 1);
  assert.equal(s[KOVA.NOINDEX], 0);
});

// ---------------------------------------------------------------------------
// YARDIMCILAR
// ---------------------------------------------------------------------------

/** §1'deki 19 Ağu ölçümüne yakın, değişmeyen bir taban durum. */
function temelDurum() {
  const panel = { icerik: {}, bolum: {}, genel: {} };
  for (let i = 0; i < 250; i++) {
    panel.icerik[`https://dizijpg.com/icerik/tv/${i}`] =
      i < 26 ? KOVA.DIZINE_EKLENDI : KOVA.KESFEDILDI_TARANMADI;
    panel.bolum[`https://dizijpg.com/dizi/${i}/sezon/1/bolum/1`] = KOVA.KESFEDILDI_TARANMADI;
  }
  const d = {
    surum: AYAR.DURUM_SURUM,
    tarih: new Date().toISOString(),
    siteHaritasi: {
      toplam: 80936,
      parcalar: {
        'sitemap-icerik-1.xml': {
          gonderilen: 2453, sonIndirme: new Date().toISOString(),
          sonGonderim: null, hata: 0, uyari: 0, bekliyor: false, dizin: false,
        },
      },
    },
    arama: {
      tiklama: 0, gosterim: 77, satirSayisi: 37,
      sayfa: { icerik: 37, bolum: 0, genel: 0 },
      pencere: { bas: '2026-08-12', son: '2026-08-18' },
    },
    panel,
    kovaSayim: Object.fromEntries(Object.keys(panel).map((a) => [a, kovaSay(panel[a])])),
    panelN: Object.fromEntries(Object.keys(panel).map((a) => [a, Object.keys(panel[a]).length])),
    evren: { icerik: 2453, bolum: 78480, genel: 3 },
    indeksliHam: { icerik: 26, bolum: 0, genel: 3 },
    hamEtiket: { icerik: {}, bolum: {}, genel: {} },
    denetimHatasi: { icerik: 0, bolum: 0, genel: 0 },
    denetimIstegi: 525,
    kotaBitti: false,
    haritaHatasi: null,
    bildirimsizKosu: 0,
    sureMs: 190000,
  };
  d.degisim = bosDegisim(d);
  return d;
}

/** Hiç hareket olmayan değişim yapısı (sinyal testlerinde taban). */
function bosDegisim(d) {
  return Object.fromEntries(Object.keys(d.panel).map((a) => [a, degisimHesapla(d.panel[a], d.panel[a])]));
}

/**
 * Bir kovada `once` → `sonra` geçişi kuran iki gün üretir.
 * Bölüm ailesinde her URL AYRI diziye konur, yoksa küme sayısı 1 kalır ve
 * anlamlılık testi (doğru biçimde) ateşlemez.
 */
function ikiGun(aile, kova, once, sonra) {
  const url = (i) => (aile === 'bolum'
    ? `https://dizijpg.com/dizi/${i}/sezon/1/bolum/1`
    : `https://dizijpg.com/icerik/tv/${i}`);
  const dunP = {};
  const bugunP = {};
  for (let i = 0; i < 250; i++) {
    dunP[url(i)] = i < once ? kova : KOVA.DIZINE_EKLENDI;
    bugunP[url(i)] = i < sonra ? kova : KOVA.DIZINE_EKLENDI;
  }
  const dun = temelDurum();
  const bugun = temelDurum();
  dun.panel[aile] = dunP;
  bugun.panel[aile] = bugunP;
  for (const g of [dun, bugun]) {
    g.kovaSayim[aile] = kovaSay(g.panel[aile]);
    g.panelN[aile] = Object.keys(g.panel[aile]).length;
  }
  bugun.degisim = Object.fromEntries(Object.keys(bugun.panel)
    .map((a) => [a, degisimHesapla(dun.panel[a], bugun.panel[a])]));
  return { dun, bugun };
}

// ===========================================================================
// KAZANAN BÖLÜMLER — site haritası muafiyet listesi (28 Ağu 2026)
// ===========================================================================
// NEDEN: bölüm haritası bilinçli kesiliyor; muafiyet listesi 27 Ağu'da ELLE
// dolduruldu ve ERTESİ GÜN bayatladı — tıklama alan üç bölüm haritada yoktu.
// Bu testler listenin GSC verisinden üretilmesini ve bayatlamamasını kilitler.

const satir = (yol, clicks, impressions = clicks) => ({
  keys: [`https://dizijpg.com${yol}`], clicks, impressions,
});

test('kazananlariCoz: yalnız TIKLAMA almış BÖLÜM yolları', () => {
  const k = kazananlariCoz([
    satir('/dizi/30984/sezon/2/bolum/45', 9, 24),
    satir('/dizi/61175/sezon/3/bolum/19', 2, 5),
    // Gösterim var, tıklama YOK -> kazanan değil (32/0 alan sayfalar var).
    satir('/kisi/77880', 0, 32),
    satir('/dizi/1/sezon/1/bolum/1', 0, 99),
    // Bölüm olmayan yollar hiç girmez.
    satir('/icerik/tv/1396', 5, 5),
    satir('/', 2, 5),
  ]);
  assert.deepEqual(k.map((x) => [x.tmdbId, x.sezon, x.bolum, x.tiklama]), [
    [30984, 2, 45, 9],
    [61175, 3, 19, 2],
  ]);
  assert.equal(k[0].gosterim, 24);
});

test('kazananlariCoz: tıklamaya göre AZALAN sıralı', () => {
  const k = kazananlariCoz([
    satir('/dizi/2/sezon/1/bolum/1', 1),
    satir('/dizi/3/sezon/1/bolum/1', 7),
    satir('/dizi/4/sezon/1/bolum/1', 3),
  ]);
  assert.deepEqual(k.map((x) => x.tmdbId), [3, 4, 2]);
});

test('kazananlariCoz: aynı bölümün iki yazımı TEK kazanan, tıklama toplanır', () => {
  const k = kazananlariCoz([
    satir('/dizi/9/sezon/1/bolum/2', 3, 10),
    satir('/dizi/9/sezon/1/bolum/2/', 2, 4),   // sondaki eğik çizgi
  ]);
  assert.equal(k.length, 1);
  assert.equal(k[0].tiklama, 5);
  assert.equal(k[0].gosterim, 14);
});

test('kazananlariCoz: bozuk/negatif kimlikler elenir', () => {
  assert.deepEqual(kazananlariCoz([
    satir('/dizi/0/sezon/1/bolum/1', 5),
    satir('/dizi/9/sezon/0/bolum/1', 5),
    satir('/dizi/9/sezon/1/bolum/0', 5),
    { keys: [], clicks: 5 },
    {},
  ]), []);
});

test('eşik SABİT 1: gösterim değil TIKLAMA kanıt sayılır', () => {
  assert.equal(KAZANAN_MIN_TIKLAMA, 1);
});

test('kazananlariYaz: upsert eder, SİLMEZ ve yeni sayısını döndürür', async () => {
  const sorgular = [];
  const havuz = {
    query: async (sql, par) => {
      sorgular.push({ sql, par });
      if (/SELECT tmdb_id/.test(sql)) {
        return { rows: [{ tmdb_id: 30984, sezon: 2, bolum: 45 }] };
      }
      return { rows: [] };
    },
  };
  const sonuc = await kazananlariYaz(havuz, [
    { tmdbId: 30984, sezon: 2, bolum: 45, tiklama: 9, gosterim: 24 },
    { tmdbId: 61175, sezon: 3, bolum: 19, tiklama: 2, gosterim: 5 },
  ], '2026-08-26');
  assert.deepEqual(sonuc, { yazildi: 2, yeni: 1 });

  const yazmalar = sorgular.filter((q) => /INSERT INTO seo_kazanan_bolum/.test(q.sql));
  assert.equal(yazmalar.length, 2);
  assert.match(yazmalar[0].sql, /ON CONFLICT \(tmdb_id, sezon, bolum\) DO UPDATE/);
  assert.deepEqual(yazmalar[0].par, [30984, 2, 45, 9, 24, '2026-08-26']);
  // SİLME YOK: pencereden düşen bölüm yeniden öksüz kalmamalı.
  assert.ok(!sorgular.some((q) => /DELETE/i.test(q.sql)),
    'kazanan satırı SİLİNMEMELİ — bkz. kazananlariYaz başlığı');
});

test('kazananlariYaz: boş listede DB\'ye hiç dokunmaz', async () => {
  let cagri = 0;
  const havuz = { query: async () => { cagri += 1; return { rows: [] }; } };
  assert.deepEqual(await kazananlariYaz(havuz, [], '2026-08-26'), { yazildi: 0, yeni: 0 });
  assert.equal(cagri, 0);
});

test('aramaAnalitigi kazananları AYNI yanıttan süzer (ikinci API çağrısı YOK)', () => {
  const bas = KAYNAK.indexOf('export async function aramaAnalitigi');
  const govde = KAYNAK.slice(bas, bas + 2200);
  assert.match(govde, /kazananlar: kazananlariCoz\(satirlar\)/);
});

test('main: kazanan yazımı raporu BLOKLAMAZ (DB düşse bile koşu biter)', () => {
  const i = KAYNAK.indexOf('--- KAZANAN BÖLÜMLER ---');
  assert.ok(i > 0, 'main içindeki kazanan bloğu bulunamadı');
  const blok = KAYNAK.slice(i, i + 1200);
  assert.match(blok, /try \{/);
  assert.match(blok, /catch \(e\)/);
  assert.ok(!/process\.exit/.test(blok),
    'kazanan yazımı hatası koşuyu öldürmemeli');
  assert.match(blok, /havuz\.end\(\)/, 'havuz kapatılmalı');
});

test('harita indirmesi API\'den AYRI ve GENİŞ zaman aşımı kullanır', () => {
  // 28 Ağu 2026, ilk gerçek koşu: haritalar istek anında ÜRETİLİYOR ve soğuk
  // önbellekte 20 sn'yi aşabiliyor. Aşınca `urller` boş kalır, paneller
  // kurulamaz ve indeks kapsamı kanalı SESSİZCE ölür (özet satırında 0/0).
  assert.ok(AYAR.HARITA_ZAMAN_ASIMI_MS > AYAR.ISTEK_ZAMAN_ASIMI_MS,
    'harita sınırı API sınırından geniş olmalı');
  const bas = KAYNAK.indexOf('export async function haritaUrlleri');
  const govde = KAYNAK.slice(bas, bas + 700);
  assert.match(govde, /AbortSignal\.timeout\(ayar\.HARITA_ZAMAN_ASIMI_MS\)/);
  assert.ok(!/ISTEK_ZAMAN_ASIMI_MS/.test(govde),
    'harita indirmesi API sınırını KULLANMAMALI');
});
