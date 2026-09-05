// KIRIK FRAGMAN SÜZGECİ — davranış + bağlantı testleri
// `cd backend && node --test test/*.test.js`
//
// OLAY (5 Eyl 2026, kullanıcı): "bazı dizilerin fragmanları kırılmış onları
// sürekli tarayıp düzeltecek script yazmalıyız ve resmi fragman olmalılar".
//
// ÖLÇÜM: TMDB'den 120 popüler yapımın 1.308 Trailer/Teaser'ı YouTube'a tek
// tek soruldu → 11 kırık. 7'si silinmiş/gizli (oEmbed görüyor), 4'ü Türkiye'ye
// KAPALI (`regionRestriction.allowed` TR içermiyor: Lioness/Paramount+,
// FROM/MGM+, Bleach/vizmedia, Demon Slayer/Crunchyroll) — bunları yalnız
// YouTube Data API görüyor.
//
// İKİ KATMAN (projedeki disiplin):
//  1) DAVRANIŞ: `fragman_suzgec.js` saf olduğu için gerçek fonksiyonlar çağrılır.
//  2) BAĞLANTI: saf modül doğru olsa bile `server.js` onu yanlış bağlarsa
//     davranış testi bunu göremez — çağrı yerleri KAYNAKTA denetlenir.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  KIRIK_DURUMLAR, AZAMI_KIRIK_ORAN, fragmanlariSuz, videoMu,
} from '../fragman_suzgec.js';
import { fragmanSatirlari, onbellekAnahtari, videoYolu, bayraklariCoz } from '../fragman_tarama.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
const TARAMA = fs.readFileSync(path.join(KOK, 'fragman_tarama.js'), 'utf8');
const SEMA = fs.readFileSync(path.join(KOK, 'sema.sql'), 'utf8');

const video = (key, ek = {}) => ({
  site: 'YouTube', type: 'Trailer', key, official: true, iso_639_1: 'en', ...ek,
});

// ---------------------------------------------------------------------------
// 1) SÜZGEÇ DAVRANIŞI
// ---------------------------------------------------------------------------

test('append_to_response gövdesinden kırık kimlik elenir', () => {
  const veri = {
    id: 1396,
    name: 'Breaking Bad',
    videos: { results: [video('iyiKey1234'), video('kirikKey12'), video('iyiKey5678')] },
  };
  const c = fragmanlariSuz(veri, new Set(['kirikKey12']));
  assert.deepEqual(c.videos.results.map((v) => v.key), ['iyiKey1234', 'iyiKey5678']);
  // Gövde YERİNDE değiştirilmemeli: `tmdbGetir` bazı yollarda önbellekten
  // okunan nesneyi doğrudan döndürüyor, yerinde değişiklik sızardı.
  assert.equal(veri.videos.results.length, 3);
  assert.equal(c.name, 'Breaking Bad');
});

test('/videos ucunun düz `results` biçimi de süzülür', () => {
  const veri = { id: 1396, results: [video('kirikKey12'), video('iyiKey1234')] };
  const c = fragmanlariSuz(veri, new Set(['kirikKey12']));
  assert.deepEqual(c.results.map((v) => v.key), ['iyiKey1234']);
});

test('değişiklik yoksa AYNI nesne döner (boşuna kopya yok)', () => {
  const veri = { videos: { results: [video('iyiKey1234')] } };
  assert.equal(fragmanlariSuz(veri, new Set(['baskaKey12'])), veri);
  assert.equal(fragmanlariSuz(veri, new Set()), veri);
  assert.equal(fragmanlariSuz(veri, null), veri);
});

test('arama sonuçları KORUNUR — `results` var ama video değil', () => {
  // En tehlikeli yanlış pozitif: `/search/tv` de `results` taşıyor. Oradaki
  // nesnelerde `site`/`key` yok; karıştırsaydık arama sonuçlarını silerdik.
  const arama = { results: [{ id: 1396, name: 'Breaking Bad' }, { id: 2, name: 'X' }] };
  assert.equal(fragmanlariSuz(arama, new Set(['kirikKey12'])), arama);
  assert.equal(videoMu({ id: 1396, name: 'Breaking Bad' }), false);
  assert.equal(videoMu(video('iyiKey1234')), true);
});

test('YouTube DIŞI site (Vimeo) kimliği aynı olsa bile elenmez', () => {
  const veri = { results: [{ ...video('ayniKey123'), site: 'Vimeo' }] };
  assert.equal(fragmanlariSuz(veri, new Set(['ayniKey123'])), veri);
});

test('tek fragman kırıksa liste BOŞALIR — asıl düzeltilen davranış', () => {
  // Kullanıcının gördüğü hata tam olarak buydu: yapımın tek fragmanı ölmüş,
  // uygulama siyah iframe gömüyor. Liste boşalınca `karisikKahramanDiz`
  // kahramanı kapak fotoğraflarıyla çiziyor.
  const veri = { results: [video('kirikKey12')] };
  const c = fragmanlariSuz(veri, new Set(['kirikKey12']));
  assert.deepEqual(c.results, []);
  assert.equal(veri.results.length, 1, 'kaynak gövde değiştirilmemeli');
});

test('felaket freni TABLO oranına bakar, liste oranına DEĞİL', () => {
  // Liste başına fren, tek fragmanlı yapımı korurdu (yukarıdaki test) —
  // yanlıştı. Gerçek felaket `fragman_durum`un toplu bir yazma hatasıyla
  // bozulması; o yüzden eşik YÜKLEME anında, tablo oranına uygulanıyor.
  const veri = { results: [video('k1aaaaaaaa'), video('k2aaaaaaaa'), video('k3aaaaaaaa')] };
  const c = fragmanlariSuz(veri, new Set(['k1aaaaaaaa', 'k2aaaaaaaa', 'k3aaaaaaaa']));
  assert.deepEqual(c.results, [], 'süzgeç liste oranına bakmamalı');
  assert.ok(AZAMI_KIRIK_ORAN > 0 && AZAMI_KIRIK_ORAN < 1);
  const SUZGEC = fs.readFileSync(path.join(KOK, 'fragman_suzgec.js'), 'utf8');
  const iYukle = SUZGEC.indexOf('async yukle()');
  assert.ok(iYukle > 0);
  assert.match(SUZGEC.slice(iYukle, iYukle + 1400), /AZAMI_KIRIK_ORAN/,
    'fren yükleme fonksiyonunda olmalı');
  assert.match(SUZGEC.slice(iYukle, iYukle + 1400), /this\.set = new Set\(\);/,
    'eşik aşılınca küme BOŞ bırakılmalı (süzgeç kapalı)');
});

test("'bilinmiyor' süzülmez: kanıtsız gizleme yok", () => {
  assert.deepEqual(KIRIK_DURUMLAR, ['yok', 'gizli', 'gomulemez', 'bolge']);
  assert.ok(!KIRIK_DURUMLAR.includes('bilinmiyor'));
  assert.ok(!KIRIK_DURUMLAR.includes('iyi'));
});

test('çöp gövdeler patlamaz', () => {
  const k = new Set(['kirikKey12']);
  for (const v of [null, undefined, 42, 'metin', [], { results: null }, { videos: 5 }]) {
    assert.doesNotThrow(() => fragmanlariSuz(v, k));
  }
});

// ---------------------------------------------------------------------------
// 2) TARAYICI — saf yardımcılar
// ---------------------------------------------------------------------------

test('fragmanSatirlari: yalnız YouTube Trailer/Teaser, tekrarsız', () => {
  const satirlar = fragmanSatirlari({
    results: [
      video('trailer123'),
      { ...video('teaser1234'), type: 'Teaser', official: false, iso_639_1: 'tr' },
      { ...video('clip123456'), type: 'Clip' },          // spoiler → alınmaz
      { ...video('vimeo12345'), site: 'Vimeo' },          // YouTube değil
      { ...video('bozuk key!') },                         // geçersiz kimlik
      video('trailer123'),                                // tekrar
    ],
  });
  assert.deepEqual(satirlar.map((s) => s.youtubeId), ['trailer123', 'teaser1234']);
  assert.equal(satirlar[0].resmi, true);
  assert.equal(satirlar[1].resmi, false);
  assert.equal(satirlar[1].iso, 'tr');
});

test('önbellek anahtarı server.js `tmdbGetir` ile AYNI biçimde kurulur', () => {
  // Farklı anahtar üretsek: tablo şişer, kullanıcı isteği bu satırlardan
  // faydalanmaz, ısıtıcı aynı veriyi ikinci kez çeker.
  assert.equal(
    onbellekAnahtari('/tv/1396/videos?include_video_language=tr,en,null'),
    '/tv/1396/videos?include_video_language=tr,en,null&language=tr-TR',
  );
  assert.equal(onbellekAnahtari('/tv/1396'), '/tv/1396?language=tr-TR');
  assert.equal(onbellekAnahtari('/tv/1396?language=en-US'), '/tv/1396?language=tr-TR');
  // server.js'teki kural: yolda `language` yoksa sona eklenir.
  assert.match(SERVER, /yol \+= \(yol\.includes\('\?'\) \? '&' : '\?'\) \+ 'language=' \+ dil;/);
});

test('videoYolu: `include_video_language` server.js ile aynı', () => {
  assert.equal(videoYolu('movie', 27205), '/movie/27205/videos?include_video_language=tr,en,null');
  assert.equal(videoYolu('tv', 1396, 2), '/tv/1396/season/2/videos?include_video_language=tr,en,null');
  assert.match(SERVER, /'include_video_language', `\$\{kod\},en,null`/);
});

test('bayraklar: geçersiz değer SESSİZ geçmez', () => {
  assert.equal(bayraklariCoz(['--kuru']).kuru, true);
  assert.equal(bayraklariCoz(['--icerik=0']).icerik, 0);
  assert.deepEqual(bayraklariCoz(['--tmdb=tv:1396']).tekYapim, { tur: 'tv', id: 1396 });
  assert.throws(() => bayraklariCoz(['--bilinmeyen']), /bilinmeyen bayrak/);
  assert.throws(() => bayraklariCoz(['--icerik=abc']), /sayı olmalı/);
  assert.throws(() => bayraklariCoz(['--tmdb=1396']), /biçiminde/);
});

// ---------------------------------------------------------------------------
// 3) SINIFLANDIRMA DİSİPLİNİ (kaynak denetimi)
// ---------------------------------------------------------------------------

test("'unlisted' KIRIK SAYILMAZ — 5 Eyl'de 16 resmi fragmanı yanlışlıkla eledi", () => {
  // Illumination, Sony Pictures, Universal, Sky TV, Star Wars ve
  // "Interstellar Movie" kanallarının RESMİ fragmanları liste dışı
  // yayımlanmış; `embeddable: true` ve iframe'de sorunsuz oynuyorlar.
  // Gerileme burada durur: yalnız 'private' erişilemezdir.
  assert.match(TARAMA, /st\.privacyStatus === 'private'/);
  assert.ok(!/privacyStatus !== 'public'/.test(TARAMA),
    "privacyStatus !== 'public' testi geri geldi: unlisted resmi fragmanlar elenir");
});

test('regionRestriction iki yönlü okunur (blocked VE allowed)', () => {
  // Ölçülen dört kırığın DÖRDÜ de `allowed` listesiyle engelli (TR listede
  // yok); yalnız `blocked` bakılsaydı hiçbiri yakalanmazdı.
  assert.match(TARAMA, /kis\.blocked\)\s*&&\s*kis\.blocked\.includes\(AYAR\.ULKE\)/);
  assert.match(TARAMA, /kis\.allowed\)\s*&&\s*kis\.allowed\.length[\s\S]{0,80}!kis\.allowed\.includes\(AYAR\.ULKE\)/);
  assert.match(TARAMA, /ULKE: 'TR'/);
});

test('InnerTube yolu KULLANILMIYOR (sağlam videoya bile DENIED dönüyordu)', () => {
  // Yorum satırı bilerek geçilir: kararın GEREKÇESİ dosyada kalmalı, yasak
  // olan ÇAĞRIDIR. Bu yüzden yalnız kod satırlarına bakılıyor.
  const kodSatirlari = TARAMA.split('\n').filter((l) => !/^\s*(\/\/|\*|\/\*)/.test(l));
  assert.ok(!kodSatirlari.some((l) => /youtubei/.test(l)),
    'InnerTube çağrısı geri geldi: sağlam fragmanları da kırık işaretler');
  // Gerekçe ise SİLİNMEMELİ — yoksa biri "en doğrusu bu" diye geri ekler.
  assert.match(TARAMA, /EMBEDDER_IDENTITY_DENIED/);
});

// ---------------------------------------------------------------------------
// 4) BAĞLANTI — server.js süzgeci GERÇEKTEN uyguluyor mu
// ---------------------------------------------------------------------------

test('server.js: `tmdbGetir` her iki dönüş yolunda da süzüyor', () => {
  const i = SERVER.indexOf('async function tmdbGetir(');
  assert.ok(i > 0, 'tmdbGetir bulunamadı');
  const govde = SERVER.slice(i, SERVER.indexOf('async function tmdbTopluGetir('));
  const cagrilar = govde.match(/kirikFragmanlar\.suz\(/g) || [];
  assert.equal(cagrilar.length, 2,
    'tmdbGetir iki yerden dönüyor (önbellek isabeti + taze yanıt); ikisi de süzülmeli');
  // Önbelleğe HAM yazılmalı: süzülmüş gövde yazılırsa, video geri geldiğinde
  // (gizli→açık, bölge kısıtı kalktı) ancak TTL dolunca görürüz.
  assert.match(govde, /\[anahtar, veri\],\s*\);\s*\n\s*\/\/[^\n]*\n\s*return kirikFragmanlar\.suz\(veri\);/);
});

test('server.js: `tmdbTopluGetir` önbellek ve bayat dalları da süzüyor', () => {
  const i = SERVER.indexOf('async function tmdbTopluGetir(');
  const govde = SERVER.slice(i, i + 6000);
  assert.match(govde, /sonuc\.set\(yol, kirikFragmanlar\.suz\(v\)\)/);
  assert.match(govde, /sonuc\.set\(y, kirikFragmanlar\.suz\(v\)\)/);
});

test('server.js: süzgeç örneği kurulur ve tazeleme başlatılır', () => {
  assert.match(SERVER, /import \{ KirikFragmanlar \} from '\.\/fragman_suzgec\.js';/);
  assert.match(SERVER, /new KirikFragmanlar\(havuz\)\.baslat\(\)/);
});

test('sema.sql üç tabloyu da tanıyor (yeni veritabanı migrasyonsuz kurulur)', () => {
  for (const t of ['fragman_durum', 'fragman_baglanti', 'fragman_icerik']) {
    assert.match(SEMA, new RegExp(`CREATE TABLE IF NOT EXISTS ${t}\\b`), `${t} sema.sql'de yok`);
  }
  // CHECK kısıtı ile modüldeki durum listesi ayrışmamalı.
  for (const d of [...KIRIK_DURUMLAR, 'iyi', 'bilinmiyor']) {
    assert.ok(SEMA.includes(`'${d}'`), `sema.sql '${d}' durumunu tanımıyor`);
  }
});
