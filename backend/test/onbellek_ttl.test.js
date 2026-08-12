// TMDB arama önbelleği: İÇERİĞE bakan TTL testleri
// `cd backend && node --test test/*.test.js`
//
// OLAY (12 Ağu): "Castle Walls" arandı, çıkmadı — TMDB'de gerçekten yoktu.
// Asıl kusur şuydu: dizi TMDB'ye EKLENDİKTEN sonra bile o sorgu için
// önbellekteki SIFIR SONUÇLU yanıt günlerce/saatlerce servis edilecekti.
// Yeni çıkan HER yapımda tekrar eden bir şikâyet sınıfı.
//
// İki katman (yasak.test.js / arama.test.js ile aynı disiplin):
//  1) DAVRANIŞ: `onbellek_ttl.js` SAF olduğu için gerçek fonksiyonlar çağrılır.
//  2) BAĞLANTI: saf modül doğru olsa bile `server.js` onu yanlış bağlarsa
//     davranış testi bunu göremez — arama uçlarının GERÇEKTEN seçiciyi
//     kullandığı ve `tmdbGetir`in seçiciyi okuduğu kaynakta denetlenir.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { tmdbSonucSayisi, aramaTtlSecici, ttlCoz } from '../onbellek_ttl.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
const DOCKERFILE = fs.readFileSync(path.join(KOK, 'Dockerfile'), 'utf8');

const SN = { varsayilan: 6 * 3600, uzun: 7 * 24 * 3600, kisa: 15 * 60, orta: 30 * 60 };
const secici = (dolu = SN.uzun, azEsigi = 3) =>
  aramaTtlSecici({ dolu, kisa: SN.kisa, orta: SN.orta, azEsigi });

const sonuclar = (n) => ({
  page: 1, total_results: n,
  results: Array.from({ length: n }, (_, i) => ({ id: i + 1, name: `Dizi ${i}` })),
});

// ===========================================================================
// 1. DAVRANIŞ — sonuç sayısı
// ===========================================================================
test('sonuç sayısı: /search/* yanıtı `results` uzunluğudur', () => {
  assert.equal(tmdbSonucSayisi(sonuclar(0)), 0);
  assert.equal(tmdbSonucSayisi(sonuclar(1)), 1);
  assert.equal(tmdbSonucSayisi(sonuclar(20)), 20);
});

test('sonuç sayısı: /find yanıtı TÜM *_results dizilerinin toplamıdır', () => {
  assert.equal(tmdbSonucSayisi({
    movie_results: [], tv_results: [{ id: 5 }], person_results: [],
    tv_episode_results: [], tv_season_results: [],
  }), 1);
  assert.equal(tmdbSonucSayisi({
    movie_results: [], tv_results: [], person_results: [],
    tv_episode_results: [], tv_season_results: [],
  }), 0);
});

test('sonuç sayısı: tanınmayan gövde 0 sayılır (güvenli yön = kısa TTL)', () => {
  for (const v of [null, undefined, 0, '', 'metin', [], {}, { id: 3, name: 'x' }]) {
    assert.equal(tmdbSonucSayisi(v), 0, `beklenmeyen: ${JSON.stringify(v)}`);
  }
});

// ===========================================================================
// 2. DAVRANIŞ — TTL seçimi (asıl hata)
// ===========================================================================
test('SIFIR sonuçlu yanıt KISA TTL alır (15 dk)', () => {
  const ttl = secici();
  assert.equal(ttl(sonuclar(0)), SN.kisa);
  assert.ok(ttl(sonuclar(0)) <= 30 * 60,
    'yeni eklenen yapım en geç yarım saatte görünmeli');
});

test('DOLU yanıt çağıranın UZUN TTL\'ini korur (TMDB\'ye boşuna yük yok)', () => {
  assert.equal(secici(SN.uzun)(sonuclar(20)), SN.uzun);
  assert.equal(secici(SN.varsayilan)(sonuclar(3)), SN.varsayilan);
});

test('NEREDEYSE sonuçsuz (1-2 sonuç) ORTA TTL alır (30 dk)', () => {
  // "Castle Walls" TMDB'de yokken de "Castle" gibi alakasız 1-2 satır
  // dönebilir; bu hâl de bayatlamamalı.
  const ttl = secici();
  assert.equal(ttl(sonuclar(1)), SN.orta);
  assert.equal(ttl(sonuclar(2)), SN.orta);
  assert.equal(ttl(sonuclar(3)), SN.uzun, 'eşik 3: üçüncü sonuçtan itibaren dolu');
});

test('azEsigi=1 (/find): TEK sonuç TAM İSABETTİR, uzun yaşar', () => {
  const ttl = secici(SN.uzun, 1);
  assert.equal(ttl({ tv_results: [{ id: 1 }] }), SN.uzun,
    '/find tek sonucu isabettir — her seferinde TMDB\'ye gidilmemeli');
  assert.equal(ttl({ tv_results: [], movie_results: [] }), SN.kisa);
});

test('kısa TTL sıralaması tutarlı: kisa < orta < varsayilan < uzun', () => {
  assert.ok(SN.kisa < SN.orta && SN.orta < SN.varsayilan && SN.varsayilan < SN.uzun);
});

// ===========================================================================
// 3. DAVRANIŞ — GERİYE UYUMLULUK
// ===========================================================================
test('ttlCoz: SAYI verildiğinde gövdeye BAKMADAN aynen döner', () => {
  assert.equal(ttlCoz(SN.uzun, sonuclar(0)), SN.uzun);
  assert.equal(ttlCoz(0, sonuclar(0)), 0);
  assert.equal(ttlCoz(SN.varsayilan, null), SN.varsayilan);
});

test('ttlCoz: SEÇİCİ verildiğinde gövdeye uygulanır', () => {
  assert.equal(ttlCoz(secici(), sonuclar(0)), SN.kisa);
  assert.equal(ttlCoz(secici(), sonuclar(9)), SN.uzun);
});

test('saf modül: yan etkisi/bağımlılığı yok (pg/express/env okumuyor)', () => {
  const kod = fs.readFileSync(path.join(KOK, 'onbellek_ttl.js'), 'utf8')
    .replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');
  assert.doesNotMatch(kod, /require\(|from ['"]pg['"]|from ['"]express['"]/);
  assert.doesNotMatch(kod, /process\.env/);
  assert.deepEqual(kod.match(/^import .*$/gm), null, 'saf modülün importu olmamalı');
});

// ===========================================================================
// 4. BAĞLANTI — server.js gerçekten seçiciyi kullanıyor mu?
// ===========================================================================
/** Kaynaktaki her `tmdbGetir(...)` çağrısının metni. */
function tmdbGetirCagrilari(src) {
  const cagrilar = [];
  const re = /tmdbGetir\(/g;
  let m;
  while ((m = re.exec(src))) {
    const son = src.indexOf(');', m.index);
    cagrilar.push(src.slice(m.index, son < 0 ? m.index + 300 : son + 2));
  }
  return cagrilar;
}

test('KAYNAK KİLİDİ: hiçbir arama çağrısı KOŞULSUZ sabit TTL kullanmıyor', () => {
  const aramalar = tmdbGetirCagrilari(SERVER)
    .filter((c) => /\/(search|find)\//.test(c));
  assert.ok(aramalar.length >= 4,
    `arama çağrıları bulunamadı (${aramalar.length}) — regex mi bozuldu?`);
  for (const c of aramalar) {
    assert.match(c, /aramaTtl\(/,
      `arama çağrısı içeriğe bakmayan TTL kullanıyor:\n${c}`);
    assert.doesNotMatch(c, /,\s*ONBELLEK_TTL_SN\.(uzun|varsayilan)\s*[,)]/,
      `arama çağrısı hâlâ doğrudan sabit TTL veriyor:\n${c}`);
  }
});

test('/tmdb/* proxy: search/find yolları içeriğe bakan TTL alır', () => {
  const i = SERVER.indexOf("app.get('/tmdb/*'");
  assert.ok(i > 0, '/tmdb/* ucu yok');
  const uc = SERVER.slice(i, i + 3000);
  assert.match(uc, /const aramaMi = \/\^\\\/\(search\|find\)\\\/\/\.test\(yol\)/,
    'proxy arama yollarını ayırt etmiyor');
  assert.match(uc, /aramaMi\s*\n?\s*\?\s*aramaTtl\(/,
    'proxy arama yolunda aramaTtl kullanmıyor');
  // Sunucudaki kısa TTL, Cloudflare kenarında 6 saatlik s-maxage ile
  // etkisizleşirdi: kenar önbelleği de kısalmalı.
  assert.match(uc, /bosArama[\s\S]{0,200}s-maxage=900/,
    'sonuçsuz arama kenarda (CDN) hâlâ uzun yaşıyor');
  assert.match(uc, /tmdbSonucSayisi\(veri\) < azEsigi/);
});

test('/ara ucu: her sorgu VARYANTI kendi doluluğuna göre yaşar', () => {
  const i = SERVER.indexOf("app.get('/ara'");
  assert.ok(i > 0, '/ara ucu yok');
  const uc = SERVER.slice(i, i + 2500);
  assert.match(uc, /\/search\/multi\?query=\$\{encodeURIComponent\(v\)\}`,\s*\n\s*aramaTtl\(/,
    '/ara sorgu varyantları hâlâ sabit TTL ile önbellekleniyor');
});

test('ONBELLEK_TTL_SN: kisa=15dk, orta=30dk eklendi; eskiler DEĞİŞMEDİ', () => {
  const m = SERVER.match(/const ONBELLEK_TTL_SN = \{[\s\S]*?\};/);
  assert.ok(m, 'ONBELLEK_TTL_SN tanımı bulunamadı');
  assert.match(m[0], /varsayilan: 6 \* 3600/, 'katalog TTL\'ine dokunulmamalı');
  assert.match(m[0], /uzun: 7 \* 24 \* 3600/, 'katalog TTL\'ine dokunulmamalı');
  assert.match(m[0], /kisa: 15 \* 60/);
  assert.match(m[0], /orta: 30 \* 60/);
});

test('tmdbGetir: seçici TTL\'de satır YAŞIYLA okunur (eski satırlar da düzelir)', () => {
  const i = SERVER.indexOf('async function tmdbGetir(');
  const govde = SERVER.slice(i, i + 2000);
  assert.match(govde, /const secici = typeof ttlSn === 'function'/);
  assert.match(govde, /EXTRACT\(EPOCH FROM \(now\(\) - guncelleme\)\)/,
    'seçici TTL satırın yaşını okumadan tazeliğe karar veremez');
  assert.match(govde, /ttlCoz\(ttlSn, rows\[0\]\.veri\)/);
  // GERİYE UYUMLULUK: sayı TTL'de eski SQL süzgeci aynen duruyor.
  assert.match(govde, /guncelleme > now\(\) - \(\$2 \|\| ' seconds'\)::interval/);
});

test('tmdbTopluGetir: seçici TTL SQL aralığını BOZMAZ (JS tarafında süzülür)', () => {
  const i = SERVER.indexOf('async function tmdbTopluGetir(');
  const govde = SERVER.slice(i, i + 2000);
  assert.match(govde, /const secici = typeof ttlSn === 'function'/,
    'seçici geçirilirse ($2 || \' seconds\')::interval fonksiyonla patlar');
  assert.match(govde, /filter\(\(r\) => !secici \|\| Number\(r\.yas\) < ttlCoz\(ttlSn, r\.veri\)\)/);
  assert.match(govde, /guncelleme > now\(\) - \(\$2 \|\| ' seconds'\)::interval/,
    'sayı TTL yolu değişmemeli — bayat satırlar boşuna okunmasın');
});

test('KATALOG TTL\'İ KORUNDU: detay uçları hâlâ uzun önbellekli', () => {
  // Kapsam ARAMA uçlarıyla sınırlıydı; /tv/:id, /person/:id vb. dokunulmadı.
  assert.ok(SERVER.includes('`/tv/${tmdbId}?language=tr-TR`, ONBELLEK_TTL_SN.uzun'));
  assert.ok(SERVER.includes('`/person/${req.params.id}`, ONBELLEK_TTL_SN.uzun'));
});

// ===========================================================================
// 5. BAĞLANTI — imaj
// ===========================================================================
test('onbellek_ttl.js Dockerfile COPY listesinde (yoksa konteyner HİÇ AÇILMAZ)', () => {
  const copy = DOCKERFILE.split('\n').find((s) => s.startsWith('COPY server.js'));
  assert.ok(copy, 'COPY server.js satırı bulunamadı');
  assert.ok(/(^|\s)onbellek_ttl\.js(\s|$)/.test(copy),
    'onbellek_ttl.js imaja girmiyor: "Cannot find module" ile restart döngüsü');
  assert.match(SERVER, /import \{[^}]*\} from '\.\/onbellek_ttl\.js';/);
});
