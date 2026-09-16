// NÖBETÇİ — arka plan işleri sessizce durursa yakalayan katman.
//
// Bu dosyanın koruduğu DERS (17 Eyl 2026): 14 Eyl'de tek bir çöp TMDB satırı
// `seo_bolum_olcu` tazelemesini ve ısıtıcıyı 3 gün boyunca öldürdü. Hata iki
// yerde de DÜZGÜNCE loglandı — ve tam da bu yüzden kimse görmedi. Nöbetçinin
// işi "hata oldu mu?" değil, **"iş hâlâ koşuyor mu?"** sorusunu sormaktır.
//
// Test yalnız saf çekirdeği değil, DB sarmalayıcılarını da sahte `sorgu` ile
// ÇALIŞTIRIR: yazılan JSON'un gerçekten okunabildiğini (gidiş-dönüş) görmek,
// alanların adını elle karşılaştırmaktan daha güvenilir.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  ARDARDA_ESIK, NOBET_ISLER, NOBET_ONEK, nobetAnahtari, nobetCoz, nobetGuncelle,
  nobetKaydet, nobetKayitlari, nobetOku, nobetSorunlari, olcuYaslari, yasDir, yasMetni,
} from '../nobet.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
const ISITICI = fs.readFileSync(path.join(KOK, 'isitici.js'), 'utf8');

const T0 = Date.parse('2026-09-17T12:00:00.000Z');
const saat = (n) => n * 3600000;
/** Belirtilen saat önce başarılı koşmuş, hatasız bir kayıt. */
const saglam = (saatOnce) => ({
  son_kosu: new Date(T0 - saat(saatOnce)).toISOString(),
  son_basari: new Date(T0 - saat(saatOnce)).toISOString(),
  ardarda_hata: 0,
  son_hata: null,
});
/** Tüm işler taze + tüm ölçü tabloları taze (temiz taban durum). */
const temizGirdi = () => ({
  kayitlar: Object.fromEntries(Object.keys(NOBET_ISLER).map((a) => [a, saglam(0.5)])),
  olculer: Object.fromEntries(Object.values(NOBET_ISLER).filter((i) => i.tablo)
    .map((i) => [i.tablo, new Date(T0 - saat(1)).toISOString()])),
  simdi: T0,
  acilis: T0 - saat(72),
});

// ---------------------------------------------------------------------------
// 1) KAYIT ÜRETİMİ
// ---------------------------------------------------------------------------
test('başarılı koşu sayacı sıfırlar, hata sayacı ARTIRIR', () => {
  const ok = nobetGuncelle(null, { simdi: T0 });
  assert.equal(ok.ardarda_hata, 0);
  assert.equal(ok.son_basari, ok.son_kosu);
  assert.equal(ok.son_hata, null);

  let k = nobetGuncelle(ok, { hata: new Error('patladı'), simdi: T0 + 1000 });
  assert.equal(k.ardarda_hata, 1);
  assert.equal(k.son_hata, 'patladı');
  // SON BAŞARI KORUNUR: "en son ne zaman gerçekten çalıştı" bilgisi, hata
  // üstüne hata gelse bile kaybolmamalı — nöbetçinin yaş hesabı ona dayanıyor.
  assert.equal(k.son_basari, ok.son_kosu);
  k = nobetGuncelle(k, { hata: new Error('yine'), simdi: T0 + 2000 });
  assert.equal(k.ardarda_hata, 2);
  assert.equal(k.son_basari, ok.son_kosu);
  // Düzelen koşu sayacı sıfırlar.
  assert.equal(nobetGuncelle(k, { simdi: T0 + 3000 }).ardarda_hata, 0);
});

test('bozuk/eksik kayıt ÇÖKERTMEZ (kayıt yok sayılır)', () => {
  for (const girdi of [null, undefined, '', 'değil-json', '[]', '5', {}]) {
    assert.doesNotThrow(() => nobetGuncelle(girdi, { hata: new Error('x'), simdi: T0 }));
  }
  assert.equal(nobetGuncelle('{bozuk', { hata: new Error('x'), simdi: T0 }).ardarda_hata, 1);
  assert.equal(nobetCoz('{"a":1}').a, 1);
  assert.equal(nobetCoz('[1,2]'), null);
});

test('hata metni kırpılır (ayarlar satırı şişmesin)', () => {
  const k = nobetGuncelle(null, { hata: new Error('x'.repeat(5000)), simdi: T0 });
  assert.ok(k.son_hata.length <= 300, `kırpılmadı: ${k.son_hata.length}`);
});

// ---------------------------------------------------------------------------
// 2) SORUN KARARI — 14 Eyl senaryosu birebir
// ---------------------------------------------------------------------------
test('her şey tazeyken TEK BİR sorun bile üretilmez (yanlış alarm yok)', () => {
  assert.deepEqual(nobetSorunlari(temizGirdi()), []);
});

test('14 EYL SENARYOSU: ısıtıcı üst üste patlıyor + ölçü tablosu donmuş', () => {
  const g = temizGirdi();
  // Isıtıcı: 3 gündür her koşuda aynı hata (canlıda 324 koşu).
  g.kayitlar.isitici = {
    son_kosu: new Date(T0 - saat(0.1)).toISOString(),
    son_basari: new Date(T0 - saat(68)).toISOString(),
    ardarda_hata: 324,
    son_hata: 'value "1000000000000000000" is out of range for type integer',
  };
  // Bölüm ölçüsü: iş koşuyor ve "başarılı" görünüyor (catch hatayı yutuyordu)
  // ama tabloya 3 gündür tek satır yazılmadı — SONUÇ sinyali bunu yakalar.
  g.olculer.seo_bolum_olcu = new Date(T0 - saat(71)).toISOString();

  const s = nobetSorunlari(g);
  assert.equal(s.length, 2, `beklenen iki sorun: ${JSON.stringify(s)}`);
  const isitici = s.find((x) => x.is === 'isitici');
  assert.equal(isitici.tur, 'hata');
  assert.match(isitici.ozet, /324 koşu üst üste HATA/);
  assert.match(isitici.ozet, /out of range for type integer/,
    'sorun satırı NEDENİ taşımalı — panelde "bir şey bozuk" yazmak yetmez');
  const bolum = s.find((x) => x.is === 'seo_bolum_olcu');
  assert.equal(bolum.tur, 'olcu_bayat');
  assert.match(bolum.ozet, /seo_bolum_olcu tablosuna 3,0 gündür satır yazılmadı/);
});

test('iş başına TEK satır: hata > kosmuyor > olcu_bayat', () => {
  const g = temizGirdi();
  g.kayitlar.seo_bolum_olcu = {
    son_kosu: new Date(T0).toISOString(),
    son_basari: new Date(T0 - saat(50)).toISOString(),
    ardarda_hata: ARDARDA_ESIK,
    son_hata: 'bir şey',
  };
  g.olculer.seo_bolum_olcu = new Date(T0 - saat(99)).toISOString();
  const s = nobetSorunlari(g).filter((x) => x.is === 'seo_bolum_olcu');
  assert.equal(s.length, 1, 'aynı iş için birden çok satır panelde gürültü olur');
  assert.equal(s[0].tur, 'hata');
});

test('eşikler: ısıtıcı 3 saat, ölçü aileleri 24 saat', () => {
  // Isıtıcı 10 dakikada bir koşar: 2 saat sessizlik daha alarm değil, 4 saat.
  const az = temizGirdi(); az.kayitlar.isitici = saglam(2);
  assert.deepEqual(nobetSorunlari(az), []);
  const cok = temizGirdi(); cok.kayitlar.isitici = saglam(4);
  assert.equal(nobetSorunlari(cok)[0].tur, 'kosmuyor');
  // Ölçü aileleri harita kovasıyla (6 saat) tetikleniyor: 12 saat normal.
  const olcuAz = temizGirdi(); olcuAz.kayitlar.seo_kisi_olcu = saglam(12);
  assert.deepEqual(nobetSorunlari(olcuAz), []);
  const olcuCok = temizGirdi(); olcuCok.kayitlar.seo_kisi_olcu = saglam(30);
  assert.equal(nobetSorunlari(olcuCok)[0].is, 'seo_kisi_olcu');
  // Tek hata alarm DEĞİL (geçici olabilir); eşik ARDARDA_ESIK.
  const tekHata = temizGirdi();
  tekHata.kayitlar.isitici = { ...saglam(0.2), ardarda_hata: ARDARDA_ESIK - 1, son_hata: 'x' };
  assert.deepEqual(nobetSorunlari(tekHata), []);
});

test('YENİ DAĞITIM sessiz: kayıt yokken eşik dolmadan alarm verilmez', () => {
  const g = temizGirdi();
  g.kayitlar = {};
  // Sunucu 10 dakikadır ayakta: hiçbir iş daha sırasını almamış olabilir.
  g.acilis = T0 - 10 * 60000;
  assert.deepEqual(nobetSorunlari(g), [], 'yeni dağıtımda yanlış alarm');
  // Eşik geçtiyse artık sessizlik bir cevaptır.
  g.acilis = T0 - saat(48);
  const s = nobetSorunlari(g);
  assert.equal(s.length, Object.keys(NOBET_ISLER).length);
  assert.ok(s.every((x) => x.tur === 'kayit_yok'));
});

test('okunamayan ölçü tablosu SUSAR (migrasyon yoksa panel yanlış suçlamasın)', () => {
  const g = temizGirdi();
  delete g.olculer.seo_yapim_sirket;          // sorgu düştü / tablo yok
  assert.deepEqual(nobetSorunlari(g), []);
  g.olculer.seo_yapim_sirket = null;          // tablo var ama BOŞ
  assert.equal(nobetSorunlari(g)[0].tur, 'olcu_bayat');
});

test('yaş metni Türkçe uyumlu ("2,8 gündür", "3,0 saattir")', () => {
  assert.equal(yasMetni(saat(3)), '3,0 saat');
  assert.equal(yasDir(saat(3)), '3,0 saattir');
  assert.equal(yasDir(saat(68)), '2,8 gündür');
  assert.equal(yasDir(45 * 60000), '45 dakikadır');
  assert.equal(yasMetni(NaN), 'bilinmiyor');
});

// ---------------------------------------------------------------------------
// 3) DB SARMALAYICILARI — sahte `sorgu` ile gidiş-dönüş
// ---------------------------------------------------------------------------
/** `ayarlar` tablosunun bellek içi taklidi (INSERT … ON CONFLICT dahil). */
function sahteDb() {
  const tablo = new Map();
  const olculdu = new Map();
  return {
    tablo,
    olculdu,
    async sorgu(metin, d = []) {
      if (/^SELECT deger FROM ayarlar/.test(metin.trim())) {
        return { rows: tablo.has(d[0]) ? [{ deger: tablo.get(d[0]) }] : [] };
      }
      if (/^SELECT anahtar, deger FROM ayarlar/.test(metin.trim())) {
        const on = String(d[0]).replace('%', '');
        return {
          rows: [...tablo.entries()].filter(([a]) => a.startsWith(on))
            .map(([anahtar, deger]) => ({ anahtar, deger })),
        };
      }
      if (/^INSERT INTO ayarlar/.test(metin.trim())) {
        tablo.set(d[0], d[1]);
        return { rows: [] };
      }
      const m = /^SELECT max\(olculdu\) AS son FROM (\w+)$/.exec(metin.trim());
      if (m) {
        if (!olculdu.has(m[1])) throw new Error(`relation "${m[1]}" does not exist`);
        return { rows: [{ son: olculdu.get(m[1]) }] };
      }
      throw new Error(`beklenmeyen sorgu: ${metin}`);
    },
  };
}

test('nobetKaydet → nobetOku gidiş-dönüşü (alan adları gerçekten tutuyor)', async () => {
  const db = sahteDb();
  await nobetKaydet(db.sorgu, 'isitici', { simdi: T0 });
  assert.ok(db.tablo.has(`${NOBET_ONEK}isitici`), 'anahtar ön eki bozulmuş');
  assert.equal(nobetAnahtari('isitici'), 'nobet_isitici');
  assert.equal((await nobetOku(db.sorgu, 'isitici')).ardarda_hata, 0);

  // Üst üste iki hata: sayaç DB'den okunarak artmalı (bellekte değil).
  await nobetKaydet(db.sorgu, 'isitici', { hata: new Error('a'), simdi: T0 + 1 });
  await nobetKaydet(db.sorgu, 'isitici', { hata: new Error('b'), simdi: T0 + 2 });
  const k = await nobetOku(db.sorgu, 'isitici');
  assert.equal(k.ardarda_hata, 2);
  assert.equal(k.son_hata, 'b');

  const hepsi = await nobetKayitlari(db.sorgu);
  assert.equal(hepsi.isitici.ardarda_hata, 2, 'ön ek kırpılmamış / kayıt okunamıyor');
});

test('olcuYaslari: olmayan tablo anahtarı HİÇ döndürmez (alarm üretmesin)', async () => {
  const db = sahteDb();
  db.olculdu.set('seo_bolum_olcu', new Date(T0).toISOString());
  const y = await olcuYaslari(db.sorgu);
  assert.equal(y.seo_bolum_olcu, new Date(T0).toISOString());
  assert.ok(!('seo_kisi_olcu' in y), 'okunamayan tablo "bayat" sanılır');
});

// ---------------------------------------------------------------------------
// 4) BAĞLANTI KİLİDİ — nöbetçi gerçekten takılı mı?
// ---------------------------------------------------------------------------
// Saf çekirdek doğru olsa bile kimse ÇAĞIRMIYORSA nöbetçi yoktur. Aşağısı
// kaynaktan okur: ısıtıcı ve ölçü tazelemeleri kayıt yazıyor mu, sunucu
// düzenli bakıyor mu, panel sonucu alıyor mu?
test('ölçü tazelemeleri koşu sonucunu YAZIYOR (hata yutulsa bile iz kalır)', () => {
  assert.match(SERVER, /await nobetKaydet\(\(m, d\) => havuz\.query\(m, d\), a\.ad, \{ hata: kosuHatasi \}\)/,
    'ortak tazeleme sürücüsü nöbet kaydı yazmıyor');
  assert.match(SERVER, /await nobetKaydet\(\(m, d\) => havuz\.query\(m, d\), 'seo_kisi_olcu'/,
    'kişi ölçüsü nöbet kaydı yazmıyor');
  // Hata dalı sayacı besleyecekse yakalanan hatayı SAKLAMALI.
  assert.match(SERVER, /olay: `\$\{a\.ad\}_tazeleme`, hata: e, obek, satir \}\);\n\s+kosuHatasi = e;/,
    'tazeleme hatası nöbet kaydına taşınmıyor');
});

test('ısıtıcı koşu sonucunu YAZIYOR — ama kilide takılan kopya yazmıyor', () => {
  assert.match(ISITICI, /import \{ nobetKaydet \} from '\.\/nobet\.js'/);
  const son = ISITICI.slice(ISITICI.indexOf('async function main'));
  assert.match(son, /if \(kilit\) \{[\s\S]*nobetKaydet\([\s\S]*'isitici'/,
    'nöbet kaydı `if (kilit)` bloğunun İÇİNDE olmalı: kilide takılıp dönen kopya'
    + ' hiçbir şey denemedi, "başarılı" damgası nöbetçiyi kör eder');
  assert.match(son, /catch \(e\) \{\n\s+kosuHatasi = e;\n\s+throw e;/,
    'koşu hatası yakalanıp yeniden atılmıyor — kayıt hep "başarılı" olur');
});

test('sunucu düzenli bakıyor ve sonucu PANELE veriyor', () => {
  assert.match(SERVER, /setInterval\(nobetciBak, NOBET_BAKIS_MS\)/, 'periyodik bakış yok');
  assert.match(SERVER, /setTimeout\(nobetciBak, NOBET_ILK_BAKIS_MS\)/, 'açılış bakışı yok');
  assert.match(SERVER, /if \(ISCI_GOREVLI\) \{\n\s+setInterval\(nobetciBak/,
    'kümede her işçi ayrı bakarsa aynı soru N kez sorulur');
  assert.match(SERVER, /nobetci: nobet,/, '/admin/ozet nöbetçiyi döndürmüyor');
  assert.match(SERVER, /seviye: 'hata',\n\s+olay: 'nobetci',/,
    'sorun varken HATA seviyesinde log yazılmıyor');
  // Panel: şerit + kart.
  const ADMIN = fs.readFileSync(path.join(KOK, 'admin.html'), 'utf8');
  assert.match(ADMIN, /id="nobet-serit"/, 'panelde nöbetçi şeridi yok');
  assert.match(ADMIN, /e:'Nöbetçi'/, 'panelde nöbetçi kartı yok');
  assert.match(ADMIN, /d\.nobetci&&d\.nobetci\.sorunlar/, 'kart nöbetçi verisini okumuyor');
});

test('imaja giren dosya listesi nobet.js içeriyor (yoksa konteyner açılmaz)', () => {
  const dockerfile = fs.readFileSync(path.join(KOK, 'Dockerfile'), 'utf8');
  assert.match(dockerfile, /^COPY server\.js .*\bnobet\.js\b/m,
    'nobet.js Dockerfile COPY listesinde yok — server.js import\'ta patlar');
});
