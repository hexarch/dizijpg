// Yönetim paneli · Büyüme grafiği (13 Eyl 2026)
//
// Kullanıcı isteği aynen: "admin panelinde büyüme bölümündeki günlük kayıt ve
// günlük aktif kullanıcıda mouse ile gün gün üzerine geldiğimizde tarihleri
// sayıları göster, bu istatistik verilerini google search console gibi
// detaylı yap."
//
// Grafik bir TUVAL: erişilebilirlik ağacı yok, tarayıcı otomasyonu ipucunun
// içeriğini okuyamaz. Bu yüzden panelin GERÇEK kodu (admin.html'den çekilir,
// kopya değil) sahte bir DOM + sahte 2D bağlamda koşturulur ve şunlar sınanır:
//   1) ipucu O GÜNÜN tarihini ve her açık metriğin sayısını yazıyor mu,
//   2) fare x'i doğru güne düşüyor mu (imleç matematiği),
//   3) grafikte GÖRÜNEN yarı doğru mu (uç iki kat pencere döndürüyor:
//      ilk yarı kıyas, ikinci yarı seçilen dönem — karıştırılırsa panel
//      sessizce ESKİ dönemi gösterir),
//   4) "aktif kullanıcı" TOPLANMIYOR mu (tekil kişi günler arası toplanamaz),
//   5) ok tuşları / dokunma da imleci gezdiriyor mu (fare tek yol olmasın).
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const ADMIN = fs.readFileSync(path.join(KOK, 'admin.html'), 'utf8');
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');

function blokCek(bas, son) {
  const i = ADMIN.indexOf(bas);
  assert.notEqual(i, -1, `admin.html içinde "${bas}" yok`);
  const j = ADMIN.indexOf(son, i);
  assert.notEqual(j, -1, `admin.html içinde "${son}" yok`);
  return ADMIN.slice(i, j);
}
function fonksiyonuCek(ad) {
  const bas = ADMIN.indexOf(`function ${ad}(`);
  assert.notEqual(bas, -1, `admin.html içinde ${ad}() yok`);
  let derinlik = 0; let i = ADMIN.indexOf('{', bas);
  for (; i < ADMIN.length; i++) {
    if (ADMIN[i] === '{') derinlik++;
    else if (ADMIN[i] === '}') { derinlik--; if (!derinlik) break; }
  }
  return ADMIN.slice(bas, i + 1);
}

const BUYUME_KODU = blokCek('const BU_METRIK = [', '/* ---- Cihaz dağılımı');
const YARDIMCI = `${fonksiyonuCek('esc')}\n${fonksiyonuCek('escJs')}\n${
  blokCek('const yuzde =', 'const yasFmt')}`;

/* ---- Sahte DOM ---------------------------------------------------------- */
function sahteBaglam() {
  const kayit = { metin: [], daire: 0, cizgi: 0 };
  const b = {
    kayit,
    setTransform() {}, clearRect() {}, save() {}, restore() {},
    beginPath() {}, moveTo() {}, lineTo() {}, closePath() {}, fill() {},
    stroke() { kayit.cizgi++; }, setLineDash() {},
    arc() { kayit.daire++; },
    fillText(t) { kayit.metin.push(String(t)); },
    createLinearGradient() { return { addColorStop() {} }; },
  };
  return b;
}
function sahteOge(id, ek = {}) {
  const siniflar = new Set(ek.sinif || []);
  const o = {
    id, innerHTML: '', textContent: '', dataset: {}, style: {},
    offsetLeft: 12, offsetTop: 14, offsetWidth: 180, offsetHeight: 90,
    clientWidth: 800, clientHeight: 300, dinleyici: {},
    classList: {
      add: (c) => siniflar.add(c), remove: (c) => siniflar.delete(c),
      contains: (c) => siniflar.has(c),
    },
    addEventListener(ad, fn) { o.dinleyici[ad] = fn; },
    getBoundingClientRect: () => ({ left: 0, top: 0, width: o.clientWidth, height: o.clientHeight }),
    focus() {}, appendChild() {}, remove() {},
    ...ek,
  };
  return o;
}

/** Büyüme kodunu sahte DOM'da kurar; panelin gerçek fonksiyonlarını döndürür. */
function panelKur({ gun = 7, seri, sec = ['kayit', 'aktif'], kiyas = false, ort = false } = {}) {
  const ogeler = {
    '#bu-tuval': sahteOge('bu-tuval', {
      clientWidth: 800, clientHeight: 300,
      getContext() { return this.bglm || (this.bglm = sahteBaglam()); },
    }),
    '#bu-ipucu': sahteOge('bu-ipucu', { sinif: ['gizli'] }),
    '#bu-anlati': sahteOge('bu-anlati'),
    '#bu-metrikler': sahteOge('bu-metrikler'),
    '#bu-tablo': sahteOge('bu-tablo'),
    '#bu-tablo-bilgi': sahteOge('bu-tablo-bilgi'),
    '#bu-kartlar': sahteOge('bu-kartlar'),
    '#bu-donem': sahteOge('bu-donem', { value: String(gun) }),
    '#bu-kiyas': sahteOge('bu-kiyas', { checked: kiyas }),
    '#bu-ort': sahteOge('bu-ort', { checked: ort }),
    '#bu-gun': sahteOge('bu-gun'),
    '#bu-icerik': sahteOge('bu-icerik'),
    '#bu-tutundurma': sahteOge('bu-tutundurma'),
    '#s-buyume': sahteOge('s-buyume'),
  };
  ogeler['#bu-ipucu'].parentElement = ogeler['#bu-tuval'].parent = {
    clientWidth: 824, clientHeight: 320,
  };
  const kur = new Function('$', 'devicePixelRatio', 'addEventListener', 'document', 'URL', 'Blob', `
    ${YARDIMCI}
    const iBag=(t,i,a)=>a, api=async()=>({}), icerikDetay=()=>{};
    ${BUYUME_KODU}
    return {BU,BU_METRIK,buyumeCiz,buTuvalBagla,buMetrikKutulari,buMetrikSec,
            buTabloCiz,buTavan,buOrtala,buSeri,buImlece,buSirala};
  `);
  const p = kur(
    (s) => ogeler[s] || sahteOge('yok'), 2, () => {},
    { createElement: () => sahteOge('a'), body: { appendChild() {}, remove() {} } },
    { createObjectURL: () => 'blob:x', revokeObjectURL() {} },
    function Blob() {},
  );
  p.BU.veri = { gun, seri, ozet: {}, push: {}, etkin: {}, bugun: seri[seri.length - 1].gun };
  p.BU.gun = gun;
  p.BU.sec = new Set(sec);
  p.ogeler = ogeler;
  return p;
}

/** gun*2 günlük seri: kıyas yarısı düşük, görünen yarı yüksek sayılar. */
function seriUret(gun, { kayitBas = 100, aktifBas = 200 } = {}) {
  const s = [];
  const bugun = new Date('2026-09-13T12:00:00Z');
  for (let i = gun * 2 - 1; i >= 0; i--) {
    const t = new Date(bugun); t.setUTCDate(t.getUTCDate() - i);
    const g = t.toISOString().slice(0, 10);
    const gorunen = i < gun;
    s.push({
      gun: g,
      kayit: (gorunen ? kayitBas : 10) + (gun - 1 - (i % gun)),
      uye: gorunen ? 7 : 3,
      aktif: (gorunen ? aktifBas : 20) + (gun - 1 - (i % gun)),
      izleme: 5, yorum: 2, mesaj: 1,
    });
  }
  return s;
}

/* ---- 1) İPUCU: tarih + sayı ---------------------------------------------- */
test('ipucu imlecin GÜNÜNÜ ve her açık metriğin SAYISINI yazar', () => {
  const gun = 7, seri = seriUret(gun);
  const p = panelKur({ gun, seri });
  p.BU.imlec = 3;
  p.buyumeCiz();

  const ip = p.ogeler['#bu-ipucu'];
  assert.equal(ip.classList.contains('gizli'), false, 'ipucu gizli kaldı');
  const gorunen = seri.slice(-gun), g = gorunen[3];
  const t = new Date(`${g.gun}T12:00:00`);
  assert.ok(ip.innerHTML.includes(String(t.getDate())), 'ipucunda gün yok');
  assert.ok(ip.innerHTML.includes(String(t.getFullYear())), 'ipucunda yıl yok');
  assert.ok(ip.innerHTML.includes('Günlük kayıt'), 'kayıt metriği yazılmamış');
  assert.ok(ip.innerHTML.includes('Aktif kullanıcı'), 'aktif metriği yazılmamış');
  assert.ok(ip.innerHTML.includes(String(g.kayit)), `o günün kayıt sayısı (${g.kayit}) yok`);
  assert.ok(ip.innerHTML.includes(String(g.aktif)), `o günün aktif sayısı (${g.aktif}) yok`);
  // Aynı sayılar ekran okuyucuya da gitmeli (tuval role=img, ipucu görsel).
  const anlati = p.ogeler['#bu-anlati'].textContent;
  assert.ok(anlati.includes(String(g.kayit)) && anlati.includes(String(g.aktif)),
    'aria-live kutusu (#bu-anlati) günün sayılarını yazmıyor');
});

test('imleç yokken ipucu gizlenir, özet satırı dönemi anlatır', () => {
  const p = panelKur({ gun: 7, seri: seriUret(7) });
  p.BU.imlec = -1;
  p.buyumeCiz();
  assert.equal(p.ogeler['#bu-ipucu'].classList.contains('gizli'), true, 'ipucu açık kaldı');
  assert.match(p.ogeler['#bu-anlati'].textContent, /7 gün/, 'dönem özeti yok');
});

test('kıyas kutusu açıkken ipucu önceki dönemin aynı gününü de yazar', () => {
  const gun = 7, seri = seriUret(gun);
  const p = panelKur({ gun, seri, kiyas: true });
  p.BU.imlec = 2;
  p.buyumeCiz();
  const ip = p.ogeler['#bu-ipucu'].innerHTML;
  assert.ok(ip.includes('(önceki)'), 'önceki dönem satırı yok');
  assert.ok(ip.includes(String(seri[2].kayit)), 'önceki dönemin sayısı yok');
});

/* ---- 2) İMLEÇ MATEMATİĞİ ------------------------------------------------- */
test('fare x koordinatı doğru güne düşer; alanın dışı imleci kapatır', () => {
  const gun = 28, seri = seriUret(gun);
  const p = panelKur({ gun, seri });
  p.buTuvalBagla();
  p.buyumeCiz();                      // BU.olcu'yu doldurur
  const tuval = p.ogeler['#bu-tuval'];
  const gez = tuval.dinleyici.mousemove;
  assert.ok(gez, 'mousemove bağlanmamış');

  const { sol, pw, n } = p.BU.olcu;
  assert.equal(n, gun, 'grafikte gün sayısı dönemle aynı değil');
  gez({ clientX: sol });                       assert.equal(p.BU.imlec, 0);
  gez({ clientX: sol + pw });                  assert.equal(p.BU.imlec, n - 1);
  gez({ clientX: sol + pw / 2 });
  assert.ok(Math.abs(p.BU.imlec - (n - 1) / 2) <= 0.5, 'orta nokta ortadaki güne düşmüyor');
  // Y ekseni etiketlerinin üstünde imleç OLMAZ (yoksa ipucu boşlukta takılıyor).
  gez({ clientX: 2 });
  assert.equal(p.BU.imlec, -1, 'grafik alanının dışında imleç kapanmadı');
  tuval.dinleyici.mouseleave();
  assert.equal(p.BU.imlec, -1, 'fare çıkınca imleç sıfırlanmadı');
});

test('ok tuşları ve dokunma da gün gezdirir (fare tek yol değil)', () => {
  const gun = 7;
  const p = panelKur({ gun, seri: seriUret(gun) });
  p.buTuvalBagla(); p.buyumeCiz();
  const t = p.ogeler['#bu-tuval'];
  let engellendi = 0;
  const tus = (key) => t.dinleyici.keydown({ key, preventDefault: () => engellendi++ });
  tus('ArrowLeft');  assert.equal(p.BU.imlec, gun - 2, 'sol ok son günden geriye gitmedi');
  tus('ArrowRight'); assert.equal(p.BU.imlec, gun - 1);
  tus('Home');       assert.equal(p.BU.imlec, 0);
  tus('ArrowLeft');  assert.equal(p.BU.imlec, 0, 'ilk günün solunda taşma var');
  tus('End');        assert.equal(p.BU.imlec, gun - 1);
  tus('Escape');     assert.equal(p.BU.imlec, -1, 'Esc imleci kapatmıyor');
  assert.equal(engellendi, 6, 'ok tuşları sayfayı kaydırmasın diye preventDefault şart');
  t.dinleyici.keydown({ key: 'a', preventDefault: () => { throw new Error('yutuldu'); } });

  p.buyumeCiz();
  const dokun = { touches: [{ clientX: p.BU.olcu.sol }], preventDefault() {} };
  t.dinleyici.touchstart(dokun);
  assert.equal(p.BU.imlec, 0, 'dokunma imleci taşımıyor');
});

/* ---- 3) GÖRÜNEN YARI ---------------------------------------------------- */
test('grafik pencerenin İKİNCİ yarısını çizer (ilk yarı kıyas dönemidir)', () => {
  const gun = 7, seri = seriUret(gun);
  const p = panelKur({ gun, seri, sec: ['kayit'] });
  const s = p.buSeri('kayit', false);
  assert.equal(s.gorunen.length, gun);
  assert.equal(s.onceki.length, gun);
  assert.deepEqual(s.gorunen, seri.slice(-gun).map((r) => r.kayit), 'görünen yarı yanlış');
  assert.deepEqual(s.onceki, seri.slice(0, gun).map((r) => r.kayit), 'kıyas yarısı yanlış');
  assert.ok(Math.min(...s.gorunen) > Math.max(...s.onceki),
    'kurgu bozuk: görünen yarı kıyas yarısından yüksek olmalı');
});

test('x ekseni ilk ve SON günü mutlaka etiketler', () => {
  const gun = 90, seri = seriUret(gun);
  const p = panelKur({ gun, seri });
  p.buyumeCiz();
  const metin = p.ogeler['#bu-tuval'].bglm.kayit.metin.join('|');
  const ilk = seri.slice(-gun)[0].gun, son = seri[seri.length - 1].gun;
  const kisa = (g) => {
    const AY = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    const t = new Date(`${g}T12:00:00`);
    return `${t.getDate()} ${AY[t.getMonth()]}`;
  };
  assert.ok(metin.includes(kisa(ilk)), 'ilk gün etiketi yok');
  assert.ok(metin.includes(kisa(son)), 'son gün (bugün) etiketi yok');
});

/* ---- 4) METRİK KUTULARI ------------------------------------------------- */
test('metrik kutusu: kayıt TOPLAM, aktif kullanıcı ORTALAMA gösterir', () => {
  const gun = 7, seri = seriUret(gun);
  const p = panelKur({ gun, seri });
  p.buMetrikKutulari();
  const h = p.ogeler['#bu-metrikler'].innerHTML;
  const gorunen = seri.slice(-gun);
  const kayitTop = gorunen.reduce((a, r) => a + r.kayit, 0);
  const aktifOrt = gorunen.reduce((a, r) => a + r.aktif, 0) / gun;
  assert.ok(h.includes(kayitTop.toLocaleString('tr')), 'kayıt dönem toplamı yok');
  assert.ok(h.includes('dönem toplamı') && h.includes('günlük ortalama'),
    'toplam/ortalama ayrımı kutuda yazılmıyor');
  assert.ok(h.includes((Math.round(aktifOrt * 10) / 10).toLocaleString('tr')),
    'aktif kullanıcı günlük ortalaması yok (tekil kişi TOPLANMAZ)');
  assert.ok(h.includes('▲'), 'artış oku yok (görünen dönem kıyastan yüksek)');
  assert.ok(h.includes('aria-pressed="true"'), 'açık metrik aria-pressed taşımıyor');
});

test('son açık metrik kapatılamaz (boş grafik hata gibi görünür)', () => {
  const p = panelKur({ gun: 7, seri: seriUret(7), sec: ['kayit'] });
  p.buMetrikSec('kayit');
  assert.deepEqual([...p.BU.sec], ['kayit'], 'tek kalan seri kapatıldı');
  p.buMetrikSec('izleme');
  assert.equal(p.BU.sec.has('izleme'), true, 'metrik açılamıyor');
  p.buMetrikSec('kayit');
  assert.equal(p.BU.sec.has('kayit'), false, 'ikinci seri varken kapatma çalışmıyor');
});

/* ---- 5) TABLO ----------------------------------------------------------- */
test('gün tablosu: her gün bir satır, sıralanabilir, satır imleci taşır', () => {
  const gun = 28, seri = seriUret(gun);
  const p = panelKur({ gun, seri });
  p.buTabloCiz();
  const h = p.ogeler['#bu-tablo'].innerHTML;
  assert.equal((h.match(/<tr class="satir-tikla"/g) || []).length, gun,
    'tabloda gün sayısı kadar satır yok');
  assert.ok(h.includes('onclick="buImlece('), 'satır grafikteki güne bağlanmıyor');
  // Varsayılan sıra: en yeni gün üstte.
  const govde = h.indexOf('<tbody>');
  const ilkSatir = h.slice(govde, h.indexOf('</tr>', govde));
  const t = new Date(`${seri[seri.length - 1].gun}T12:00:00`);
  assert.ok(ilkSatir.includes(String(t.getDate())), 'en yeni gün üstte değil');
  p.buSirala('kayit');
  assert.equal(p.BU.sira, 'kayit');
  p.buSirala('kayit');
  assert.equal(p.BU.yon, 1, 'aynı sütuna ikinci tık yönü çevirmiyor');
  p.buImlece(5);
  assert.equal(p.BU.imlec, 5, 'satır tıklaması imleci taşımıyor');
});

/* ---- 6) ÖLÇEK ----------------------------------------------------------- */
test('y ekseni tavanı okunur sayıya yuvarlanır ve sıfır seriyi çökertmez', () => {
  const p = panelKur({ gun: 7, seri: seriUret(7) });
  assert.equal(p.buTavan(0), 1, 'tamamen boş seride tavan 0 olmamalı (bölme hatası)');
  assert.equal(p.buTavan(3), 3);
  assert.equal(p.buTavan(37), 40);
  assert.equal(p.buTavan(213), 250);
  assert.equal(p.buTavan(1), 1);
  const sifir = seriUret(7).map((r) => ({ ...r, kayit: 0, aktif: 0 }));
  const q = panelKur({ gun: 7, seri: sifir });
  q.buyumeCiz();                       // NaN/Infinity ile çizim çökmesin
  assert.equal(q.ogeler['#bu-tuval'].bglm.kayit.metin.includes('0'), true);
});

test('7 günlük ortalama pencereyi GERİYE doğru alır', () => {
  const p = panelKur({ gun: 7, seri: seriUret(7) });
  const o = p.buOrtala([0, 0, 0, 0, 0, 0, 7, 7]);
  assert.equal(o[0], 0);
  assert.equal(Math.round(o[6] * 100) / 100, 1, '7 günlük pencere yanlış');
  assert.equal(Math.round(o[7] * 100) / 100, 2);
});

/* ---- 7) UÇ SÖZLEŞMESİ --------------------------------------------------- */
test('/admin/buyume panelin okuduğu alanları döndürüyor', () => {
  const i = SERVER.indexOf("app.get('/admin/buyume'");
  assert.notEqual(i, -1, 'uç yok');
  const uc = SERVER.slice(i, SERVER.indexOf("app.get('/admin/surumler'", i));
  assert.match(uc, /adminKisit/, 'uç korumasız');
  for (const alan of ['seri:', 'etkin:', 'tutundurma:', 'top_icerik:', 'push:', 'ozet:']) {
    assert.ok(uc.includes(alan), `yanıtta ${alan} yok`);
  }
  // Panel her gün için bu altı sayıyı bekliyor.
  for (const kolon of ['AS kayit', 'AS uye', 'AS aktif', 'AS izleme', 'AS yorum', 'AS mesaj']) {
    assert.ok(uc.includes(kolon), `seride ${kolon} yok`);
  }
  // Pencere İKİ KAT: kıyas dönemi olmadan "önceki dönem" hesaplanamaz.
  assert.match(uc, /const pencere = gun \* 2/, 'kıyas penceresi kaldırılmış');
  assert.match(uc, /generate_series/, 'boş günler 0 ile doldurulmuyor');
  // Olgunlaşmamış kohortta yüzde yazılmasın diye bayraklar şart.
  for (const b of ['olgun1', 'olgun7', 'olgun30']) {
    assert.ok(uc.includes(b), `tutundurmada ${b} bayrağı yok`);
  }
  assert.match(uc, /Math\.min\(Math\.max\(parseInt\(req\.query\.gun, 10\) \|\| 28, 7\), 365\)/,
    'dönem parametresi sınırlanmıyor (7-365)');
});

test('dönem seçeneklerinin hepsi ucun kabul ettiği aralıkta', () => {
  const secim = blokCek('<select id="bu-donem"', '</select>');
  const degerler = [...secim.matchAll(/value="(\d+)"/g)].map((m) => Number(m[1]));
  assert.deepEqual(degerler, [7, 28, 90, 180, 365]);
  for (const d of degerler) assert.ok(d >= 7 && d <= 365, `${d} gün uçta kırpılır`);
});

/* ---- 8) KISMİ GÜN + ZAMAN DİLİMİ --------------------------------------- */
test('son gün KISMİ olarak işaretlenir (grafikteki düşüş veri kaybı değil)', () => {
  const gun = 7, seri = seriUret(gun);
  const p = panelKur({ gun, seri });
  p.BU.imlec = gun - 1;                 // bugün
  p.buyumeCiz();
  assert.match(p.ogeler['#bu-ipucu'].innerHTML, /kısmi/,
    'bugünün ipucunda "kısmi" uyarısı yok — son günün düşüşü hata sanılır');
  p.BU.imlec = gun - 2;                 // dün
  p.buyumeCiz();
  assert.equal(/kısmi/.test(p.ogeler['#bu-ipucu'].innerHTML), false,
    'dolmuş gün de kısmi diye işaretlenmiş');
  p.buTabloCiz();
  assert.match(p.ogeler['#bu-tablo'].innerHTML, /· kısmi/, 'tabloda kısmi gün rozeti yok');
});

test('gün kovaları TÜRKİYE gününe göre kesiliyor (konteyner UTC)', () => {
  const i = SERVER.indexOf("app.get('/admin/buyume'");
  const uc = SERVER.slice(i - 1200, SERVER.indexOf("app.get('/admin/surumler'", i));
  assert.match(uc, /BUYUME_TZ = 'Europe\/Istanbul'/, 'zaman dilimi sabiti yok');
  // Ham `tarih::date` UTC gününe düşer: 13 Eyl 00:48'de "bugün" 12 Eyl olur ve
  // panel bugünü HİÇ göstermez. Bu yüzden ham ::date kalmamalı.
  const uyariSiz = uc.replace(/AT TIME ZONE \$\d\)::date/g, '');
  assert.equal(/(tarih|olusturma)\)?::date/.test(uyariSiz), false,
    'çevrilmemiş ::date kalmış — gün kovası UTC\'ye kayar');
  assert.match(uc, /bugun:/, 'yanıtta bugun alanı yok (panel kısmi günü bilemez)');
  assert.equal((uc.match(/AT TIME ZONE \$2/g) || []).length >= 10, true,
    'damgaların hepsi çevrilmemiş görünüyor');
});
