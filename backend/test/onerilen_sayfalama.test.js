// "Sana Özel" (`/onerilen`) SAYFALAMA testleri — `node --test test/*.test.js`
//
// KORUNAN KARAR (19 Ağu 2026): Keşfet'teki "Sana Özel" rafına "Tümünü gör"
// eklendi. Raf kişiye özel üretildiği için `anaSayfaRaflari` tablosunda sabit
// bir TMDB yolu YOK; `/raf/:slug` onu sayfalayamıyordu. Çözüm `/onerilen`
// ucunu sayfalanabilir yapmak oldu ve buradaki testler o sözleşmeyi kilitler:
//
//   1) SIRA KARARLI. Uç imleç/oturum tutmuyor, sayfa 2'de HER ŞEYİ baştan
//      üretiyor. Sıralama bir tık oynarsa kullanıcı aynı diziyi iki sayfada
//      birden görür. Eski kod eşit `vote_count`ta sırayı `Promise.all` yanıt
//      sırasına bırakıyordu — testler artık tam sıralamayı şart koşuyor.
//   2) SAYFA 1 DEĞİŞMEDİ. Havuz büyütüldü (kaynak başına 8 değil 20 aday) ama
//      ilk 8'lik dilim "katman 0" olarak duruyor ve sıralamanın İLK ölçütü
//      katman; yani rafın görüntüsü aynı kaldı.
//   3) HAVUZ TÜKENİNCE BOŞ LİSTE. Uydurma doldurma yok.
//   4) OTURUM ZORUNLU KALDI (`girisZorunlu`) — öneri kişiye özel.
//
// Neden kaynak okuma: `server.js` içe aktarıldığı anda `app.listen` çağırıyor,
// yani uç doğrudan çağrılamıyor (tekrar_izleme.test.js / seo_gizlilik.test.js
// ile aynı gerekçe). Saf fonksiyon kaynaktan ÇEKİLİP gerçekten ÇALIŞTIRILIYOR:
// test canlıdaki kodu sınar, kopyasını değil. Kaynak-okuma yardımcıları SEO
// testleriyle ORTAK (`yardimci/seo_kaynak.js`) — ikinci bir kopya, birinde
// düzeltilen ayrıştırma hatasının diğerinde kalması demekti.
import test from 'node:test';
import assert from 'node:assert/strict';

import { KAYNAK, alan, bolum } from './yardimci/seo_kaynak.js';

const ONERI_SAYFA_BOYU = alan(['ONERI_SAYFA_BOYU'], 'ONERI_SAYFA_BOYU');
const ONERI_ODAK = alan(['ONERI_ODAK'], 'ONERI_ODAK');
const ONERI_KAYNAK_SAYISI = alan(['ONERI_KAYNAK_SAYISI'], 'ONERI_KAYNAK_SAYISI');
const ONERI_TMDB_SAYFA = alan(['ONERI_TMDB_SAYFA'], 'ONERI_TMDB_SAYFA');
const ONERI_AZAMI_SAYFA = alan([
  'ONERI_KAYNAK_SAYISI', 'ONERI_TMDB_SAYFA', 'ONERI_SAYFA_BOYU',
  'ONERI_AZAMI_SAYFA',
], 'ONERI_AZAMI_SAYFA');
const oneriSayfasi = alan(['ONERI_SAYFA_BOYU', 'oneriSayfasi'], 'oneriSayfasi');

// Ucun gövdesi (kaynak metni olarak) — sözleşme kontrolleri için.
const UC = bolum("app.get('/onerilen'", '// ---------- yıl özeti');

// ---------------------------------------------------------------------------
// Sahte aday üreteci
// ---------------------------------------------------------------------------
/** `kaynak` sayısı kadar kaynaktan, her birinden `adet` aday üretir. */
function havuzUret({ kaynak = ONERI_KAYNAK_SAYISI, adet = ONERI_TMDB_SAYFA } = {}) {
  const cikti = [];
  let id = 1000;
  for (let k = 0; k < kaynak; k++) {
    for (let i = 0; i < adet; i++) {
      cikti.push({
        id: ++id,
        media_type: k % 2 === 0 ? 'tv' : 'movie',
        // Oy sayısı BİLEREK çok tekrarlı: eşitlikte sıranın ikincil
        // ölçütlerle çözülmesi gerektiğini kanıtlasın.
        vote_count: (i % 3) * 100,
        katman: i < ONERI_ODAK ? 0 : 1,
      });
    }
  }
  return cikti;
}

/** Tohumlu (deterministik) karıştırma — testin kendisi rastgele olmasın. */
function karistir(dizi, tohum) {
  const d = [...dizi];
  let s = tohum;
  for (let i = d.length - 1; i > 0; i--) {
    s = (s * 1103515245 + 12345) % 2147483648;
    const j = s % (i + 1);
    [d[i], d[j]] = [d[j], d[i]];
  }
  return d;
}

const kimlik = (liste) => liste.map((r) => `${r.media_type}:${r.id}`);

// ===========================================================================
// 1) KARARLILIK — sayfa 2 sayfa 1'i TEKRARLAMAZ
// ===========================================================================
test('sıra girdi sırasından BAĞIMSIZ (Promise.all yarışı sonucu değiştirmesin)', () => {
  const havuz = havuzUret();
  const beklenen = kimlik(oneriSayfasi(havuz, 1));
  for (const tohum of [1, 7, 42, 1234, 99999]) {
    assert.deepEqual(
      kimlik(oneriSayfasi(karistir(havuz, tohum), 1)), beklenen,
      `havuz karıştırılınca sayfa 1 değişti (tohum ${tohum})`);
  }
  // Eşit oy sayılı yapımlar var mı? Yoksa test etkisiz kalır.
  const oylar = havuz.map((r) => `${r.katman}:${r.vote_count}`);
  assert.ok(oylar.length > new Set(oylar).size,
    'havuzda eşit ölçütlü aday yok — kararlılık testi etkisiz');
});

test('sayfa 2 sayfa 1\'deki yapımları TEKRAR DÖNDÜRMÜYOR', () => {
  const havuz = havuzUret();
  const s1 = new Set(kimlik(oneriSayfasi(havuz, 1)));
  const s2 = kimlik(oneriSayfasi(havuz, 2));
  assert.equal(s2.length, ONERI_SAYFA_BOYU);
  const tekrar = s2.filter((k) => s1.has(k));
  assert.deepEqual(tekrar, [], `sayfa 2'de tekrar eden yapım: ${tekrar}`);
});

test('TÜM sayfalar birleşince havuzu TAM ve TEKRARSIZ kaplar', () => {
  const havuz = havuzUret();
  const hepsi = [];
  for (let s = 1; s <= ONERI_AZAMI_SAYFA; s++) hepsi.push(...kimlik(oneriSayfasi(havuz, s)));
  assert.equal(hepsi.length, havuz.length, 'sayfalar havuzun tamamını vermiyor');
  assert.equal(new Set(hepsi).size, hepsi.length, 'sayfalarda yinelenen yapım var');
});

// ===========================================================================
// 2) SAYFA 1 ESKİ DAVRANIŞLA AYNI
// ===========================================================================
test('sayfa boyutu 20 (eski `slice(0, 20)` ile aynı)', () => {
  assert.equal(ONERI_SAYFA_BOYU, 20);
  assert.equal(oneriSayfasi(havuzUret(), 1).length, 20);
});

test('sayfa 1 YALNIZ katman 0\'dan gelir ve oy sayısına göre iner', () => {
  // Havuz büyütüldü ama ilk sayfanın bileşimi değişmedi: katman 0 adayları
  // (kaynak başına ilk 8) tek başına 6×8=48 tane, yani ilk iki sayfayı
  // fazlasıyla dolduruyor.
  const sayfa = oneriSayfasi(havuzUret(), 1);
  const ham = havuzUret();
  const katmanli = new Map(ham.map((r) => [`${r.media_type}:${r.id}`, r.katman]));
  for (const k of kimlik(sayfa)) {
    assert.equal(katmanli.get(k), 0, `sayfa 1'e katman 1 adayı sızdı: ${k}`);
  }
  for (let i = 1; i < sayfa.length; i++) {
    assert.ok(sayfa[i - 1].vote_count >= sayfa[i].vote_count,
      'sayfa 1 oy sayısına göre inen sırada değil');
  }
});

test('katman ALANI yanıta SIZMIYOR (istemci sözleşmesi değişmedi)', () => {
  for (const r of oneriSayfasi(havuzUret(), 1)) {
    assert.ok(!('katman' in r), 'iç sıralama alanı istemciye gidiyor');
    assert.ok('id' in r && 'media_type' in r, 'yapım alanları kaybolmuş');
  }
});

// ===========================================================================
// 3) HAVUZ TÜKENDİĞİNDE BOŞ LİSTE — uydurma doldurma YOK
// ===========================================================================
test('havuz bitince sonraki sayfalar BOŞ döner', () => {
  const havuz = havuzUret({ kaynak: 1, adet: ONERI_ODAK });   // 8 aday
  assert.equal(oneriSayfasi(havuz, 1).length, 8, 'tek sayfalık havuz eksik döndü');
  assert.deepEqual(oneriSayfasi(havuz, 2), [], 'tükenen havuz doldurulmuş');
  assert.deepEqual(oneriSayfasi(havuz, 99), []);
  assert.deepEqual(oneriSayfasi([], 1), [], 'boş havuz boş sayfa vermiyor');
});

// ===========================================================================
// 4) UÇ SÖZLEŞMESİ (kaynak okuma)
// ===========================================================================
test('uç OTURUM ZORUNLU kaldı — öneri kişiye özel', () => {
  assert.match(KAYNAK, /app\.get\('\/onerilen', girisZorunlu, takvimLimiti,/,
    'girisZorunlu ya da hız limiti kaldırılmış');
});

test('oturumsuz istek 401 alır (ara katman ÇALIŞTIRILARAK)', async () => {
  // "Middleware yazılı mı" kontrolü tek başına yetmez; ara katmanın gerçekten
  // 401 verdiği çalıştırılarak kanıtlanıyor. Token yoksa fonksiyon ilk
  // `await`e HİÇ gelmiyor, yani DB'siz koşuyor.
  // `bildirimCek` yalnız `const`/`function` ile başlayan bildirimleri tanıyor;
  // bu ara katman `async function`. Gövde kaynaktan olduğu gibi alınıp
  // derleniyor.
  const kod0 = bolum('async function girisZorunluHam(', '\nasync function girisIsteğeBagliHam(');
  const girisZorunluHam = new Function(`${kod0}\nreturn girisZorunluHam;`)();
  let kod = null;
  let govde = null;
  const res = {
    status(k) { kod = k; return this; },
    json(g) { govde = g; return this; },
  };
  let sonrakiCagrildi = false;
  await girisZorunluHam({ headers: {} }, res, () => { sonrakiCagrildi = true; });
  assert.equal(kod, 401, 'oturumsuz istek 401 almadı');
  assert.deepEqual(govde, { hata: 'Giriş gerekli' });
  assert.equal(sonrakiCagrildi, false, 'oturumsuz istek uca ULAŞTI');
});

test('geçersiz sayfa 400 döner (tam sayı ve >= 1 şartı)', () => {
  assert.match(UC, /Number\.isInteger\(sayfa\) \|\| sayfa < 1/);
  assert.match(UC, /res\.status\(400\)/, 'geçersiz sayfa için 400 yok');
  // Kaynaktaki doğrulamanın AYNISI çalıştırılıyor: '0', '-1', 'abc', '1.5',
  // '' değerlerinin hepsi elenmeli, '1'/'3' geçmeli.
  const gecerli = (q) => {
    const sayfa = q === undefined ? 1 : Number(q);
    return Number.isInteger(sayfa) && sayfa >= 1;
  };
  for (const q of ['0', '-1', 'abc', '1.5', '', ' ', '1e999']) {
    assert.equal(gecerli(q), false, `geçersiz sayfa kabul edildi: ${JSON.stringify(q)}`);
  }
  for (const q of [undefined, '1', '3', '6']) {
    assert.equal(gecerli(q), true, `geçerli sayfa reddedildi: ${q}`);
  }
});

test('havuz üstü sayfa DB\'ye ve TMDB\'ye HİÇ gitmeden boş döner', () => {
  // Kazıyıcı `?sayfa=999` ile ucu dövmesin: yanıt zaten boş olacağı için
  // sorgu bile açılmıyor. 400 DEĞİL 200 — sayfa geçersiz değil, o kadar
  // öneri yok.
  const i = UC.indexOf('sayfa > ONERI_AZAMI_SAYFA');
  assert.notEqual(i, -1, 'havuz üstü sayfa için kısa devre yok');
  assert.match(UC.slice(i, i + 120), /res\.json\(\{ oneriler: \[\] \}\)/);
  for (const agir of ['havuz.query', 'tmdbGetir']) {
    assert.ok(UC.indexOf(agir) > i,
      `${agir} kısa devreden ÖNCE çalışıyor — boş sayfa da DB/TMDB dövüyor`);
  }
});

test('azami sayfa SABİTLERDEN türetiliyor (elle güncellenen ikinci sayı yok)', () => {
  assert.equal(ONERI_AZAMI_SAYFA,
    Math.ceil((ONERI_KAYNAK_SAYISI * ONERI_TMDB_SAYFA) / ONERI_SAYFA_BOYU));
  assert.match(KAYNAK, /const ONERI_AZAMI_SAYFA = Math\.ceil\(/);
});

test('yinelenen aday EN KÜÇÜK katmanı korur (kaynak yarışı sonucu bozmasın)', () => {
  // Aynı yapım iki kaynağın önerisinde çıkabilir: birinde ilk 8'de (katman 0),
  // diğerinde kuyrukta (katman 1). Hangisinin önce döndüğü sonucu
  // DEĞİŞTİRMEMELİ — uç bunu Map + `eski.katman <= katman` kuralıyla çözüyor.
  assert.match(UC, /if \(eski && eski\.katman <= katman\) return;/);
  assert.match(UC, /adaylar\.set\(anahtar, \{ \.\.\.r, media_type: rTur, katman \}\)/);
});

test('kitaplıktakiler ELENİYOR (regresyon)', () => {
  assert.match(UC, /if \(eldeki\.has\(anahtar\)\) return;/);
  assert.match(UC, /UNION SELECT tur, tmdb_id FROM durumlar/);
});

// ===========================================================================
// 5) ROTA TUTARLILIĞI — /sana-ozel kişiye özel, indekslenmemeli
// ===========================================================================
test('/sana-ozel BOT_ROTALARI\'nda var ve robots.txt ile KAPALI', async () => {
  const { robotsKapali } = await import('./yardimci/seo_kaynak.js');
  const botRotasiVar = alan(['BOT_ROTALARI', 'botRotasiVar'], 'botRotasiVar');
  assert.ok(botRotasiVar('/sana-ozel'), 'tabloda yok — bota 404 döner');
  assert.ok(robotsKapali('/sana-ozel'),
    'oturumsuz açılmayan kişisel rota robots.txt ile kapatılmamış');
  // Ön ek tuzağı: `/sana-ozel-bilmemne` bilinen rota SAYILMAMALI.
  assert.ok(!botRotasiVar('/sana-ozel-bilmemne'));
  assert.ok(!botRotasiVar('/sana-ozel/2'));
});
