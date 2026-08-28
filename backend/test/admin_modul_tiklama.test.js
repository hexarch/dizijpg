// Yönetim paneli: SOL MODÜL MENÜSÜ + "her yer tıklanabilir" (28 Ağu 2026)
//
// Kullanıcı isteği aynen: "her yer tıklanabilir olmalı … hareketlere
// yönlendirme yok, mesela son yorumlara tıklayınca o postu div olarak
// açabilirsin … sola modüller koy, herşey yukarıda olmasın."
//
// Panelin ÖNCEKİ hâlinde:
//   · 17 sekme üst barda tek sıraydı (dar ekranda üç satıra sarıyordu),
//   · hareket satırları ÖLÜ METİNDİ (tıklayınca hiçbir şey olmuyordu),
//   · yapım adları ve şikayet hedefleri hiçbir yere gitmiyordu.
//
// Bu test o üç şeyin GERİ GELMEMESİNİ bekçiler. admin.html bir modül değil
// (tek dosyalık panel), bu yüzden yardımcılar dosya kaynağından ÇEKİLİP
// çalıştırılır — test kopyayı değil CANLIDAKİ kodu sınar.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const ADMIN = fs.readFileSync(path.join(KOK, 'admin.html'), 'utf8');
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');

/** `function ad(...) { ... }` gövdesini dengeli parantezle çeker. */
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
/** Kaynaktaki iki işaret arasındaki bloğu aynen çeker (const oklar için). */
function blokCek(kaynak, bas, son) {
  const i = kaynak.indexOf(bas);
  assert.notEqual(i, -1, `admin.html içinde "${bas}" bulunamadı`);
  const j = kaynak.indexOf(son, i);
  assert.notEqual(j, -1, `admin.html içinde "${son}" bulunamadı`);
  return kaynak.slice(i, j);
}

// Panelden gerçek kodu al: kaçış yardımcıları + tıklama yardımcıları +
// satır/kart şablonları tek bir sanal alanda çalıştırılır.
const KACIS = fonksiyonuCek(ADMIN, 'esc') + '\n' + fonksiyonuCek(ADMIN, 'escJs');
const TIKLAYICILAR = blokCek(ADMIN, 'const kBag =', 'const TMDB_GORSEL');
const H_SATIR = fonksiyonuCek(ADMIN, 'hSatir');
const G_KART = fonksiyonuCek(ADMIN, 'gKart');
const alan = new Function(`
  const MEDYA_TABAN='/api';
  ${KACIS}
  ${TIKLAYICILAR}
  ${H_SATIR}
  ${G_KART}
  return { esc, escJs, kBag, iBag, gBag, hSatir, gKart };
`)();

// Tarayıcının öznitelik çözme sırası: önce varlıklar, sonra JS.
const varlikCoz = (s) => s
  .replace(/&lt;/g, '<').replace(/&gt;/g, '>')
  .replace(/&quot;/g, '"').replace(/&#39;/g, "'")
  .replace(/&amp;/g, '&');

// ---------------------------------------------------------------------------
// 1) SOL MODÜL MENÜSÜ — 17 sayfanın hepsi bir modüle ait ve bölümü var mı?
// ---------------------------------------------------------------------------
test('sol menü: MODULLER listesi var ve üstteki sekme çubuğu kaldırıldı', () => {
  assert.match(ADMIN, /const MODULLER\s*=\s*\[/, 'MODULLER tanımı yok');
  assert.match(ADMIN, /<aside id="yan">/, 'sol menü kabı (#yan) yok');
  assert.equal(
    /class="sekme-btn/.test(ADMIN), false,
    'eski üst sekme düğmeleri (.sekme-btn) hâlâ duruyor — her şey yine yukarıda',
  );
});

test('sol menü: her sayfanın <section id="s-…"> karşılığı var (ölü sekme yok)', () => {
  const anahtarlar = [...ADMIN.matchAll(/\{k:'([a-z]+)'/g)].map((m) => m[1]);
  assert.ok(anahtarlar.length >= 17, `menüde 17 sayfa bekleniyordu, ${anahtarlar.length} var`);
  for (const k of anahtarlar) {
    assert.ok(
      ADMIN.includes(`<section id="s-${k}"`),
      `"${k}" menüde var ama <section id="s-${k}"> YOK — tıklayınca boş sayfa açılır`,
    );
  }
  // Ters yön: her bölümün de menüde bir girdisi olmalı, yoksa ulaşılamaz.
  const bolumler = [...ADMIN.matchAll(/<section id="s-([a-z]+)"/g)].map((m) => m[1]);
  for (const b of bolumler) {
    assert.ok(anahtarlar.includes(b), `<section id="s-${b}"> menüde YOK — ulaşılamaz sayfa`);
  }
});

test('sol menü: sayfa değişimi #hash yazar (yenileme ve geri tuşu çalışsın)', () => {
  assert.match(ADMIN, /history\.replaceState\(null,'','#'\+k\)/, 'hash yazılmıyor');
  assert.match(ADMIN, /addEventListener\('hashchange'/, 'hashchange dinlenmiyor');
});

test('sol menü: dokunma hedefi 44px (parmakla da kullanılıyor)', () => {
  const kural = ADMIN.match(/\.yan-btn\{[^}]*\}/);
  assert.ok(kural, '.yan-btn kuralı yok');
  assert.match(kural[0], /min-height:44px/, 'menü düğmesi 44px altında');
});

// 28 Ağu 2026, tarayıcı testinde yakalandı: `.yan-ac{display:none}` yazılmış
// ama dar ekran medya sorgusuna GÖRÜNÜR yapan kural konmamıştı. Sonuç: menü
// ekran dışına kayıyor ve AÇILAMIYORDU — telefonda panel gezilemez hâle
// geliyordu. Kuralın varlığı bekçilenir.
test('sol menü: dar ekranda ☰ düğmesi GÖRÜNÜR olur (menü ulaşılabilir kalsın)', () => {
  const dar = ADMIN.match(/@media\(max-width:900px\)\{[\s\S]*?\n\}/);
  assert.ok(dar, 'dar ekran medya sorgusu yok');
  assert.match(dar[0], /\.yan-ac\{display:inline-flex/,
    'dar ekranda ☰ görünmüyor — sol menü açılamaz');
  assert.match(dar[0], /#yan\.acik\{transform:translateX\(0\)/, 'çekmece açılmıyor');
});

// ---------------------------------------------------------------------------
// 2) HAREKETLER TIKLANABİLİR Mİ? — isteğin merkezindeki madde
// ---------------------------------------------------------------------------
test('hareket satırı: tikla verilince tıklanabilir, verilmeyince değil', () => {
  const olu = alan.hSatir('üst', 'alt', '1dk');
  assert.equal(/onclick=/.test(olu), false, 'hedefsiz satıra onclick basılmış');

  const canli = alan.hSatir('üst', 'alt', '1dk', 'gonderiDetay(42)');
  assert.match(canli, /class="istek tik"/, 'tıklanabilir satır .tik sınıfı almamış');
  assert.match(canli, /onclick="gonderiDetay\(42\)"/, 'satır tıklaması bağlanmamış');
  assert.match(canli, /role="button"/, 'erişilebilirlik rolü yok');
  assert.match(canli, /onkeydown="if\(event\.key==='Enter'\)\{gonderiDetay\(42\)\}"/,
    'klavyeyle açılamıyor (Enter)');
});

test('hareketleriYukle: dört listenin DÖRDÜ de bir yere gidiyor', () => {
  const g = fonksiyonuCek(ADMIN, 'hareketleriYukle');
  assert.match(g, /gonderiDetay\(\$\{y\.id\}\)/, 'son yorumlar gönderiyi AÇMIYOR');
  assert.match(g, /icerikDetay\('\$\{escJs\(i\.tur\)\}',\$\{i\.tmdb_id\}\)/,
    'son izlemeler yapımı açmıyor');
  assert.match(g, /icerikDetay\('\$\{escJs\(x\.tur\)\}',\$\{x\.tmdb_id\}\)/,
    'kitaplık eklemeleri yapımı açmıyor');
  assert.match(g, /kullaniciDetay\('\$\{escJs\(u\.kullanici_adi\)\}'\)/,
    'yeni kayıtlar profili açmıyor');
});

test('gönderi modalı ve yapım modalı gerçekten var', () => {
  assert.match(ADMIN, /<div id="g-modal"/, 'gönderi modalı (div) yok');
  assert.match(ADMIN, /<div id="i-modal"/, 'yapım modalı (div) yok');
  assert.match(ADMIN, /async function gonderiDetay\(id\)/, 'gonderiDetay() yok');
  assert.match(ADMIN, /async function icerikDetay\(tur,tmdbId\)/, 'icerikDetay() yok');
  // Modal yığını: kullanıcı → gönderi → yapım zincirinden geri dönülebilmeli.
  assert.match(ADMIN, /function modalGeri\(\)/, 'modal "geri" yok');
});

// ---------------------------------------------------------------------------
// 3) TIKLAMA YARDIMCILARI — kaçış ve olay yalıtımı
// ---------------------------------------------------------------------------
const YUKLER = [
  "x');alert(1);//",
  '</span><script>alert(1)</script>',
  '" onmouseover="alert(1)',
  'Ayşe\'nin "favori" dizisi & şu',
];

test('kBag/iBag/gBag: düşmanca ad öznitelikten KAÇAMAZ', () => {
  for (const y of YUKLER) {
    for (const html of [alan.kBag(y), alan.iBag('tv', 1399, y)]) {
      // Ham etiket başlangıcı çıktıda olmamalı (yalnız bizim <span>'imiz).
      const govde = html.replace(/^<span[^>]*>/, '').replace(/<\/span>$/, '');
      assert.equal(/<script/i.test(govde), false, `ham <script> sızdı: ${y}`);
      // onclick içindeki JS dizesi, varlıklar çözüldükten SONRA da kapanmamalı.
      const oc = html.match(/onclick="([^"]*)"/);
      assert.ok(oc, 'onclick bulunamadı');
      const js = varlikCoz(oc[1]);
      const tirnak = (js.match(/(?<!\\)'/g) || []).length;
      assert.equal(tirnak % 2, 0, `tek tırnak dengesiz — dizeden çıkılmış: ${y}`);
    }
  }
  // gBag sayısal id alır: sayı olmayan girdi 0'a düşer (enjeksiyon kapısı yok).
  assert.match(alan.gBag('12); alert(1', 'x'), /gonderiDetay\(0\)/);
});

test('tıklama yardımcıları olayı DURDURUR (satır hedefiyle çakışmasın)', () => {
  // Yapım adı bir gönderi satırının İÇİNDE duruyor: durdurulmazsa yapıma
  // tıklayınca gönderi açılırdı — kullanıcının şikayet ettiği tam da bu.
  assert.match(alan.iBag('tv', 1, 'Ad'), /onclick="event\.stopPropagation\(\)/);
  assert.match(alan.kBag('ali'), /onclick="event\.stopPropagation\(\)/);
  assert.match(alan.gBag(5, '#5'), /onclick="event\.stopPropagation\(\)/);
});

test('gKart: gönderi metni ve medyası kaçırılarak basılır', () => {
  const html = alan.gKart({
    id: 7, kullanici_adi: "kot'u<b>", metin: '<img src=x onerror=alert(1)>',
    medya: ['/medya/a.png', '/medya/b.mp4'], begeni: 1, goruntulenme: 2,
    tarih: '2026-08-28T10:00:00Z', yasakli: false, spoiler: true,
  }, true);
  // Ham etiket açılmamalı; kaçırılmış hâli metin olarak GÖRÜNMELİ.
  assert.equal(/<img src=x/.test(html), false, 'gönderi metninden ham <img> geçti');
  assert.match(html, /&lt;img src=x onerror=alert\(1\)&gt;/, 'metin kaçırılmamış');
  assert.match(html, /<img src="\/api\/medya\/a\.png"/, 'fotoğraf gösterilmiyor');
  assert.match(html, /<video src="\/api\/medya\/b\.mp4"/, 'video gösterilmiyor');
  assert.match(html, /spoiler/, 'spoiler rozeti yok');
});

// ---------------------------------------------------------------------------
// 4) DİĞER LİSTELER DE BİR YERE GİDİYOR MU?
// ---------------------------------------------------------------------------
test('gönderi listesi, şikayetler, hatalar, büyüme: hepsi tıklanabilir', () => {
  const yo = fonksiyonuCek(ADMIN, 'yorumlariYukle');
  assert.match(yo, /onclick="gonderiDetay\(\$\{y\.id\}\)"/, 'gönderi kartı açılmıyor');
  assert.match(yo, /iBag\(y\.tur,y\.tmdb_id,ad\)/, 'yapım adı tıklanmıyor');

  const sik = fonksiyonuCek(ADMIN, 'satirSik');
  assert.match(sik, /gBag\(s\.hedef_id, hedefMetin\)/, 'yorum şikayeti gönderiyi açmıyor');
  assert.match(sik, /kBag\(s\.eden\)/, 'şikayet eden tıklanmıyor');

  const ht = fonksiyonuCek(ADMIN, 'hatalariYukle');
  assert.match(ht, /kBag\(h\.kullanici_adi\)/, 'hatadaki kullanıcı tıklanmıyor');

  const bu = fonksiyonuCek(ADMIN, 'buyumeYukle');
  assert.match(bu, /icerikDetay\('\$\{escJs\(t\.tur\)\}',\$\{t\.tmdb_id\}\)/,
    'en çok izlenenler yapımı açmıyor');
});

test('üst arama kutusu: kullanıcı, #gönderi ve tv/1399 biçimlerini tanır', () => {
  const garaCoz = new Function(`${fonksiyonuCek(ADMIN, 'garaCoz')}\nreturn garaCoz;`)();
  assert.deepEqual(garaCoz('#123').map((x) => x.tip), ['gonderi']);
  assert.deepEqual(garaCoz('123').map((x) => x.tip), ['gonderi']);
  assert.deepEqual(garaCoz('tv/1399')[0], { tip: 'icerik', tur: 'tv', id: 1399, ad: 'Dizi #1399', ik: '🎬' });
  assert.deepEqual(garaCoz('movie 550')[0].tur, 'movie');
  assert.deepEqual(garaCoz('film:550')[0].tur, 'movie');
  assert.deepEqual(garaCoz('alcelik'), [], 'düz metin özel biçim sanılmamalı');
});

// ---------------------------------------------------------------------------
// 5) SUNUCU UÇLARI — modalleri besleyen iki yeni uç
// ---------------------------------------------------------------------------
test('yeni uçlar adminKisit arkasında', () => {
  assert.match(SERVER, /app\.get\('\/admin\/gonderi\/:id', adminKisit,/,
    '/admin/gonderi/:id yok ya da korumasız');
  assert.match(SERVER, /app\.get\('\/admin\/icerik\/:tur\/:tmdbId', adminKisit,/,
    '/admin/icerik/:tur/:tmdbId yok ya da korumasız');
});

test('yeni uçlar girdiyi doğruluyor (id tamsayı, tür kapalı küme)', () => {
  const g = SERVER.slice(SERVER.indexOf("app.get('/admin/gonderi/:id'"));
  assert.match(g.slice(0, 400), /Number\.isInteger\(id\)/, 'gönderi id doğrulanmıyor');
  const i = SERVER.slice(SERVER.indexOf("app.get('/admin/icerik/:tur/:tmdbId'"));
  assert.match(i.slice(0, 500), /tur !== 'tv' && tur !== 'movie'/, 'tür doğrulanmıyor');
  assert.match(i.slice(0, 600), /gecerliTmdb\(tmdbId\)/, 'tmdb id doğrulanmıyor');
});

test('gönderi ucu yanıtları KÖKE bağlar (yanıta tıklansa da başlık görünür)', () => {
  const g = SERVER.slice(SERVER.indexOf("app.get('/admin/gonderi/:id'"), SERVER.indexOf("app.get('/admin/icerik/"));
  assert.match(g, /const kok = gonderi\.ust_id \|\| gonderi\.id;/);
  assert.match(g, /WHERE y\.ust_id=\$1/);
});

test('hareketler ucu gönderi kimliğini ve yanıt bayrağını döndürüyor', () => {
  const h = SERVER.slice(SERVER.indexOf("app.get('/admin/hareketler'"));
  const yorumSorgu = h.slice(0, 900);
  assert.match(yorumSorgu, /SELECT y\.id,/, 'gönderi id gelmiyor — satır tıklanamaz');
  assert.match(yorumSorgu, /y\.ust_id/, 'yanıt bayrağı gelmiyor');
});
