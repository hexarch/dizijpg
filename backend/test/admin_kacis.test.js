// Yönetim paneli kaçış (XSS) birim testleri — `node --test backend/test`
//
// 3 Ağu 2026 güvenlik denetimi §2.1: canlı istek akışı, dışarıdan gelen ham
// `req.path` değerini kaçırmadan innerHTML'e basıyordu — hesabı olmayan biri
// tek bir istekle yöneticinin tarayıcısında kod çalıştırabiliyordu.
//
// admin.html bir modül değil (tek dosya panel), bu yüzden yardımcılar dosya
// kaynağından ÇEKİLİP çalıştırılıyor: böylece test gerçekten CANLIDAKİ kodu
// sınar, kopyasını değil. Ayrıca kritik şablon satırları (kaçışın çağrıldığı
// yerler) metin olarak denetlenir — biri esc()'i silerse test kırmızıya döner.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const ADMIN = fs.readFileSync(path.join(KOK, 'admin.html'), 'utf8');
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');

// --- admin.html içinden yardımcıları çek ve çalıştırılabilir hale getir ---
function fonksiyonuCek(kaynak, ad) {
  const bas = kaynak.indexOf(`function ${ad}(`);
  assert.notEqual(bas, -1, `admin.html içinde ${ad}() bulunamadı`);
  let derinlik = 0; let i = kaynak.indexOf('{', bas);
  const govdeBas = i;
  for (; i < kaynak.length; i++) {
    if (kaynak[i] === '{') derinlik++;
    else if (kaynak[i] === '}') { derinlik--; if (!derinlik) break; }
  }
  return kaynak.slice(bas, i + 1);
}
const yardimci = (ad) => new Function(`${fonksiyonuCek(ADMIN, ad)}\nreturn ${ad};`)();
const esc = yardimci('esc');
const escJs = yardimci('escJs');

// Tarayıcının öznitelik değerini çözme sırası: varlıklar çözülür, SONRA JS
// ayrıştırılır. Testte de aynı sırayı taklit ediyoruz (&amp; en sonda).
const varlikCoz = (s) => s
  .replace(/&lt;/g, '<').replace(/&gt;/g, '>')
  .replace(/&quot;/g, '"').replace(/&#39;/g, "'")
  .replace(/&amp;/g, '&');

// Denetimde geçen gerçek yükler + Türkçe/tırnak/& içeren normal metinler.
const YUKLER = [
  '/DENEME<b>XSSISARET</b>',
  '/api/<img src=x onerror=alert(1)>',
  '</span><script>alert(document.cookie)</script>',
  '" onmouseover="alert(1)',
  "x');alert(1);//",
  "');fetch('/api/admin/kullanicilar');//",
  'a\\b"c\'d&e<f>g',
  'Şu diziyi çok sevdim — "Ateş & Kül", Ayşe\'nin oyunculuğu harika!',
  'İçğüöş ÇĞÜÖİŞ 😀',
];

// ---------------------------------------------------------------------------
test('esc: HTML metakarakterlerini kaçırır (tek tırnak dahil)', () => {
  assert.equal(esc('<b>x</b>'), '&lt;b&gt;x&lt;/b&gt;');
  assert.equal(esc('a&b'), 'a&amp;b');
  assert.equal(esc('"'), '&quot;');
  assert.equal(esc("'"), '&#39;');
  assert.equal(esc('/DENEME<b>XSSISARET</b>'), '/DENEME&lt;b&gt;XSSISARET&lt;/b&gt;');
});

test('esc: null/undefined boş dizeye düşer, sayı bozulmaz', () => {
  assert.equal(esc(null), '');
  assert.equal(esc(undefined), '');
  assert.equal(esc(0), '0');
  assert.equal(esc(404), '404');
  assert.equal(esc(false), 'false');
});

test('esc: zararsız metin (Türkçe, emoji, boşluk) AYNEN kalır', () => {
  const m = 'İçğüöş ÇĞÜÖİŞ 😀 — 3. bölüm çok iyiydi!';
  assert.equal(esc(m), m);
});

test('esc: çıktısında HTML etiketi açacak karakter kalmaz', () => {
  for (const y of YUKLER) {
    const c = esc(y);
    assert.ok(!/[<>]/.test(c), `kaçışta ham < > kaldı: ${y}`);
    assert.ok(!c.includes('"'), `kaçışta ham " kaldı: ${y}`);
  }
});

test('esc: tarayıcı çözünce ORİJİNAL metin geri gelir (çift kaçış yok)', () => {
  // Panelde metin görsel olarak bozulmamalı: & ' " aynen görünmeli.
  for (const y of YUKLER) assert.equal(varlikCoz(esc(y)), y);
});

// ---------------------------------------------------------------------------
test('escJs: onclick="fn(\'…\')" bağlamında dizeden ÇIKILAMAZ', () => {
  for (const y of YUKLER) {
    const oz = escJs(y);
    // 1) Öznitelik değeri erken bitmemeli
    assert.ok(!oz.includes('"'), `öznitelik tırnağı kırıldı: ${y}`);
    // 2) Varlıklar çözüldükten sonra hâlâ geçerli TEK tırnaklı JS dizesi olmalı
    const coz = varlikCoz(oz);
    const geri = eval(`'${coz}'`); // eslint-disable-line no-eval
    assert.equal(geri, y, `JS dizesi bozuldu: ${y}`);
  }
});

test('escJs: klasik kırma denemesi kod ÇALIŞTIRMAZ', () => {
  globalThis.__xssIsaret = 0;
  const kotu = "x');globalThis.__xssIsaret=1;//";
  const deger = eval(`'${varlikCoz(escJs(kotu))}'`); // eslint-disable-line no-eval
  assert.equal(globalThis.__xssIsaret, 0, 'yük çalıştı — kaçış işe yaramıyor');
  assert.equal(deger, kotu);
});

test('escJs: HTML varlığı taklidi (&#39;) yeniden tırnağa dönüşmez', () => {
  // Ham metin "&#39;" ise, çözüldükten sonra da düz metin kalmalı.
  const coz = varlikCoz(escJs("a&#39;b"));
  assert.equal(eval(`'${coz}'`), "a&#39;b"); // eslint-disable-line no-eval
});

// ---------------------------------------------------------------------------
// Şablon denetimi: kaçışın ÇAĞRILDIĞI yerler. Denetimdeki açık tam da burada
// "esc() var ama bir blokta çağrılmamış" biçiminde ortaya çıkmıştı.
const akisBlok = ADMIN.slice(
  ADMIN.indexOf('function akisGuncelle'),
  ADMIN.indexOf('/* ---- Kartlar'));

test('canlı akış şablonu: yol ve metot kaçırılmadan basılmıyor', () => {
  assert.ok(akisBlok.includes('title="${esc(i.yol)}"'), 'title= özniteliği kaçışsız');
  assert.ok(akisBlok.includes('>${esc(i.yol)}<'), 'yol metni kaçışsız');
  assert.ok(akisBlok.includes('${esc(i.method)}'), 'metot kaçışsız');
  // Kaçışsız hiçbir ${i.…} kalmamalı (sayısal/yardımcı sarmalar hariç)
  const ham = [...akisBlok.matchAll(/\$\{i\.[a-z_]+/g)].map((m) => m[0]);
  assert.deepEqual(ham, [], `kaçışsız alan(lar) var: ${ham.join(', ')}`);
});

test('panelde onclick içinde esc() DEĞİL escJs() kullanılır', () => {
  // esc() tek tırnağı &#39; yapar; tarayıcı onu çözünce JS dizesinden çıkar.
  // Bu yüzden onclick="fn('${…}')" kalıbında escJs zorunludur.
  const kotu = [...ADMIN.matchAll(/onclick="[^"]*\(\s*'\$\{esc\(/g)].map((m) => m[0]);
  assert.deepEqual(kotu, [], `onclick içinde esc() kullanılmış: ${kotu.join(' | ')}`);
});

test('panelde bilinen kullanıcı verisi alanları kaçışsız basılmıyor', () => {
  const yasak = [
    '${h.hata}', '${i.yol}', '${i.method}', '${s.tur}',
    '${y.metin}', '${k.bio}', '${g.metin}', '${m.konu}', '${m.ozet}',
    '${u.kullanici_adi}', '${k.kullanici_adi}', '${y.kullanici_adi}',
  ];
  const bulunan = yasak.filter((y) => ADMIN.includes(y));
  assert.deepEqual(bulunan, [], `kaçışsız alan(lar): ${bulunan.join(', ')}`);
});

// ---------------------------------------------------------------------------
// Sunucu katmanı (derinlemesine savunma): halkaya ham yol yazılmamalı.
const yolTemiz = new Function(
  SERVER.match(/const yolTemiz = [^\n]+/)[0] + '\nreturn yolTemiz;')();

test('server: yolTemiz HTML metakarakterlerini yola hiç sokmaz', () => {
  assert.equal(yolTemiz('/DENEME<b>XSSISARET</b>'), '/DENEMEbXSSISARET/b');
  assert.ok(!/[<>"'\s]/.test(yolTemiz('/api/<img src=x onerror=alert(1)>')));
  assert.equal(yolTemiz('/api/akis'), '/api/akis');            // normal yol bozulmaz
  assert.equal(yolTemiz('/api/medya/a_b-c.1%20d.jpg'), '/api/medya/a_b-c.1%20d.jpg');
  assert.equal(yolTemiz('/x'.repeat(500)).length, 200);        // uzunluk sınırı
  assert.equal(yolTemiz(null), '');
});

test('server: istek halkasına ham req.path/req.method yazılmıyor', () => {
  const blok = SERVER.slice(SERVER.indexOf('ISTEK.son.unshift'),
    SERVER.indexOf('ISTEK.son.unshift') + 400);
  assert.ok(blok.includes('yol: yolTemiz(req.path)'), 'ham req.path yazılıyor');
  assert.ok(blok.includes('method: metotTemiz(req.method)'), 'ham req.method yazılıyor');
});
