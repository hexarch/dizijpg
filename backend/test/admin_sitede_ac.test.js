// Yönetim paneli: "SİTEDE AÇ" bağlantıları (30 Ağu 2026)
//
// Kullanıcı isteği aynen: "o yorumu site içerisinde de görmek istiyorum
// tıklayıp … admin panelinde son yorumlara tıklayınca açılan modalda ilgili
// kısma yönlendiren linki de koy."
//
// Panel o güne kadar YALNIZ kendi içine bağlanıyordu (gonderiDetay →
// kullaniciDetay/icerikDetay). Yönetici bir yorumu bağlamında görmek
// isteyince adresi elle kurmak zorundaydı.
//
// Bu testin ASIL işi bağlantıların ÖLÜ OLMAMASI: ürettiğimiz her yol
// app/lib/yonlendirme.dart'taki GERÇEK bir GoRoute'a oturmalı. Elle
// kurulmuş bir yol sessizce 404 verir ve panelde hiçbir hata görünmez
// (`/dizi/<id>` tam da böyle bir tuzak — dizi sayfası /icerik/tv/<id>).
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const ADMIN = fs.readFileSync(path.join(KOK, 'admin.html'), 'utf8');
const YONLENDIRME = fs.readFileSync(
  path.join(path.dirname(KOK), 'app', 'lib', 'yonlendirme.dart'), 'utf8');

function fonksiyonuCek(kaynak, ad) {
  const bas = kaynak.indexOf(`function ${ad}(`);
  assert.notEqual(bas, -1, `admin.html içinde ${ad}() bulunamadı`);
  let derinlik = 0; let i = kaynak.indexOf('{', bas);
  for (; i < kaynak.length; i++) {
    if (kaynak[i] === '{') derinlik++;
    else if (kaynak[i] === '}') { derinlik--; if (!derinlik) break; }
  }
  return kaynak.slice(bas, i + 1);
}
const blok = (bas, son) => {
  const i = ADMIN.indexOf(bas); assert.notEqual(i, -1, `"${bas}" yok`);
  const j = ADMIN.indexOf(son, i); assert.notEqual(j, -1, `"${son}" yok`);
  return ADMIN.slice(i, j);
};

// Panelin gerçek kodu — kopya değil.
const alan = new Function(`
  ${fonksiyonuCek(ADMIN, 'esc')}
  ${blok('const siteYolu =', 'const TMDB_GORSEL')}
  return { esc, siteYolu, siteBag, siteMini, SITE_TABAN };
`)();

/** yonlendirme.dart'taki GoRoute yollarını ':param' kalıbıyla toplar. */
const ROTALAR = [...YONLENDIRME.matchAll(/path:\s*'(\/[^']*)'/g)].map((m) => m[1]);

/** Somut bir yolu rota kalıplarıyla eşleştirir (':x' herhangi bir parçayı yer). */
function rotaVarMi(yol) {
  const p = yol.split('?')[0].split('/').filter(Boolean);
  return ROTALAR.some((kalip) => {
    const k = kalip.split('/').filter(Boolean);
    return k.length === p.length
      && k.every((parca, i) => parca.startsWith(':') || parca === p[i]);
  });
}

test('rota tablosu gerçekten okundu (test kendi kendini kandırmasın)', () => {
  assert.ok(ROTALAR.length >= 30, `yonlendirme.dart'tan ${ROTALAR.length} rota çıktı`);
  assert.ok(ROTALAR.includes('/gonderi/:id'), 'tekil gönderi rotası bulunamadı');
});

test('siteYolu: her tür DOĞRU ve VAR OLAN rotaya çıkar', () => {
  const bekleme = [
    [['tv', 1396, null, null], '/icerik/tv/1396'],
    [['movie', 27205, null, null], '/icerik/movie/27205'],
    [['person', 17419, null, null], '/kisi/17419'],
    [['company', 213, null, null], '/sirket/213'],
    [['tv', 1396, 5, 14], '/dizi/1396/sezon/5/bolum/14'],
  ];
  for (const [girdi, beklenen] of bekleme) {
    const uretilen = alan.siteYolu(...girdi);
    assert.equal(uretilen, beklenen, `siteYolu(${girdi}) yanlış`);
    assert.ok(rotaVarMi(uretilen),
      `${uretilen} uygulamada BÖYLE BİR ROTA YOK — bağlantı 404 verir`);
  }
});

test('dizi sayfası /dizi/<id> DEĞİL /icerik/tv/<id> (bilinen tuzak)', () => {
  assert.equal(alan.siteYolu('tv', 1396, null, null), '/icerik/tv/1396');
  assert.equal(rotaVarMi('/dizi/1396'), false,
    '/dizi/<id> rota olarak var görünüyor — tuzak notu güncellenmeli');
});

test('sezon/bölüm yalnız İKİSİ de doluyken bölüm sayfasına gider', () => {
  assert.equal(alan.siteYolu('tv', 1396, 5, null), '/icerik/tv/1396');
  assert.equal(alan.siteYolu('tv', 1396, null, 14), '/icerik/tv/1396');
  assert.equal(alan.siteYolu('tv', 1396, 5, 14), '/dizi/1396/sezon/5/bolum/14');
});

test('bağlantılar yeni sekmede ve noopener ile açılır', () => {
  for (const html of [alan.siteBag('/gonderi/42', 'Yorumu sitede aç'),
                      alan.siteMini('/gonderi/42', 'Sitede aç')]) {
    assert.match(html, /target="_blank"/, 'yeni sekmede açmıyor');
    assert.match(html, /rel="noopener noreferrer"/, 'noopener yok');
    assert.match(html, /href="[^"]*\/gonderi\/42"/, 'href yanlış');
    // Satır tıklaması modalı yeniden açmasın.
    assert.match(html, /event\.stopPropagation\(\)/, 'tıklama yukarı sızıyor');
  }
});

test('SITE_TABAN gömülü alan adı DEĞİL, location.origin türevidir', () => {
  assert.equal(alan.SITE_TABAN, '', 'tarayıcı dışında taban boş olmalıydı');
  assert.match(ADMIN, /const SITE_TABAN = \(typeof location !== 'undefined'/);
  assert.equal(/href="https:\/\/dizijpg\.com/.test(ADMIN), false,
    'panelde canlı alan adı GÖMÜLÜ — yerelde açan yönetici canlıya atlar');
});

test('metin ve başlık kaçırılır (XSS)', () => {
  const html = alan.siteMini('/kullanici/x', '<img src=x onerror=1>');
  assert.equal(html.includes('<img'), false, 'başlık kaçırılmamış');
  assert.match(html, /&lt;img/);
});

test('gönderi modalı üç bağlantıyı da basar; etiketsiz gönderide yapım atlanır', () => {
  const g = fonksiyonuCek(ADMIN, 'gonderiDetay');
  assert.match(g, /siteBag\('\/gonderi\/'\+g\.id/, 'yorumun kendi sayfası yok');
  assert.match(g, /siteBag\(siteYolu\(g\.tur,g\.tmdb_id,g\.sezon,g\.bolum\)/, 'bağlam yok');
  assert.match(g, /siteBag\('\/kullanici\/'\+encodeURIComponent\(g\.kullanici_adi\)/, 'yazar yok');
  // Etiketsiz gönderi artık mümkün (1.102.0 çoklu etiket): tmdb_id null olabilir.
  assert.match(g, /g\.tmdb_id \? siteBag\(/,
    'tmdb_id koruması yok — etiketsiz gönderide /icerik/tv/0 basar');
});

test('yanıt kartlarının her biri kendi sitedeki adresini taşır', () => {
  assert.match(fonksiyonuCek(ADMIN, 'gKart'), /siteMini\('\/gonderi\/'\+y\.id/);
});
