// ===========================================================================
// SSR ile UYGULAMA AYNI TMDB ÖNBELLEK SATIRINI PAYLAŞIR (20 Ağu 2026)
// `cd backend && node --test test/*.test.js`
// ===========================================================================
//
// BU TESTİN VAR OLMA SEBEBİ — BUGÜN ÖLÇÜLEN ISKALAMA:
// `tmdb_onbellek` read-through bir aynadır ve ANAHTARI TAM URL'dir. Aynı yapım
// için iki ayrı satır yazılıyordu:
//   SSR (/og/icerik) : /tv/1396?append_to_response=credits,similar&language=tr-TR
//   Uygulama (/tmdb) : /tv/1396?append_to_response=credits%2Cvideos%2C…&…
// Uygulamada AÇILMIŞ, taze verisi önbellekte DURAN bir yapıma Googlebot
// girdiğinde SSR o satırı göremiyor, canlı TMDB çağrısı yapıyordu.
// Canlı sayım (20 Ağu 2026): 1.261 farklı yapımın tr-TR detayı uygulama
// anahtarı altında vardı, SSR anahtarı altında yalnız 554'ü.
//
// DAHASI: uygulama anahtarı KARARSIZDI. `/tv/1396` için AYNI append kümesinin
// 5 varyantı birikmişti; tek fark `include_image_language` /
// `include_video_language`in VARLIĞI ve SIRASI (eski web derlemesi göndermiyor,
// yeni istemci gönderiyor; `URLSearchParams` istemcinin sırasını koruyordu).
// Beş varyant = beş satır = beş kez TMDB isteği.
//
// Bu yüzden anahtar artık TEK SABİTten (`ICERIK_APPEND`) ve TEK
// fonksiyondan (`icerikTmdbYolu`) SABİT SIRAYLA kuruluyor; hem SSR hem
// `/tmdb/(tv|movie)/:id` ucu onu çağırıyor. Testler o birliği kilitler:
// biri diğerinden kayarsa önbellek SESSİZCE ikiye bölünür — sayfa yine
// açılır, tablo yine dolu görünür, kimse fark etmez. Kırıldığında testi
// zayıflatma; iki tarafı yeniden aynı fonksiyona bağla.
import test from 'node:test';
import assert from 'node:assert/strict';
import { KAYNAK, bildirimCek, alan, bolum } from './yardimci/seo_kaynak.js';

const ICERIK_APPEND = alan(['ICERIK_APPEND'], 'ICERIK_APPEND');
const icerikTmdbYolu = alan(['ICERIK_APPEND', 'icerikTmdbYolu'], 'icerikTmdbYolu');

/** `tmdbGetir` anahtarı böyle tamamlıyor: yolda `language` yoksa sona ekler. */
const tamAnahtar = (yol, dil = 'tr-TR') => `${yol}&language=${dil}`;

// CANLIDAN OKUNAN GERÇEK SATIR (20 Ağu 2026, tmdb_onbellek):
//   SELECT count(*) FROM tmdb_onbellek WHERE anahtar = '…'  ->  1
// Yani bu dize "eşleşmeli" değil, canlıda BU HÂLİYLE DURUYOR. Sabit burada
// duruyor ki parametre sırası ya da adı kazara değişirse test kırmızıya dönsün
// (değişimin kendisi meşru olabilir; o zaman önbellek bir kez soğur, bunu
// BİLEREK kabul etmiş olursun).
const CANLI_ANAHTAR = '/tv/1396?append_to_response=credits%2Cvideos%2C'
  + 'recommendations%2Cexternal_ids%2Cwatch%2Fproviders%2Cimages'
  + '&include_image_language=null&include_video_language=tr%2Cen%2Cnull'
  + '&language=tr-TR';

// ===========================================================================
// 1) Üretilen anahtar CANLIDA VAR OLAN satırla birebir aynı
// ===========================================================================
test('paylaşılan anahtar canlı önbellekteki satırla birebir aynı', () => {
  assert.equal(tamAnahtar(icerikTmdbYolu('tv', 1396, 'tr')), CANLI_ANAHTAR);
});

test('anahtar SABİT SIRALI — beş varyanta bölünme buradan başlamıştı', () => {
  const yol = icerikTmdbYolu('movie', 27205, 'tr');
  const sira = [...yol.slice(yol.indexOf('?') + 1).split('&')].map((p) => p.split('=')[0]);
  assert.deepEqual(sira,
    ['append_to_response', 'include_image_language', 'include_video_language']);
  // Aynı girdi -> aynı dize (çağrı sırası/ortam anahtarı değiştirmez).
  assert.equal(yol, icerikTmdbYolu('movie', 27205, 'tr'));
  // `language` YOLDA YOK: onu `tmdbGetir` isteğin diline göre sona ekler.
  // Yolda da olsaydı `tmdbGetir` onu değiştirir, sıra istemciye göre kayardı.
  assert.ok(!/[?&]language=/.test(yol), 'language yola girmiş — sırası istemciye göre kayar');
});

test('kimlik sayıya normalleşiyor (/tv/01396 ile /tv/1396 tek satır)', () => {
  assert.equal(icerikTmdbYolu('tv', '01396', 'tr'), icerikTmdbYolu('tv', 1396, 'tr'));
});

test('fragman dili anahtara giriyor (TR kullanıcı ile EN kullanıcı ayrı satır)', () => {
  assert.match(icerikTmdbYolu('tv', 1396, 'tr'), /include_video_language=tr%2Cen%2Cnull/);
  assert.match(icerikTmdbYolu('tv', 1396, 'en'), /include_video_language=en%2Cen%2Cnull/);
});

test('append kümesi uygulamanın istediği ALT KAYNAKLARIN TAMAMINI taşır', () => {
  // Eksik biri: uygulama ekranı sessizce boşalır (kadro/fragman/sağlayıcı yok).
  // Fazlası: SSR boşuna büyük gövde ayrıştırır.
  assert.deepEqual(ICERIK_APPEND.split(','), [
    'credits', 'videos', 'recommendations', 'external_ids', 'watch/providers', 'images',
  ]);
});

// ===========================================================================
// 2) İKİ ÇAĞIRAN DA AYNI FONKSİYONU KULLANIYOR — ıskalamanın kökü buydu
// ===========================================================================
test('SSR /og/icerik anahtarı paylaşılan fonksiyondan üretir', () => {
  const uc = bolum("app.get('/og/icerik/:tur/:tmdbId'", "app.get('/og/kisi");
  assert.match(uc, /tmdbGetir\(\s*\n?\s*icerikTmdbYolu\(tur, tmdbId/);
  // Eski, uygulamayla PAYLAŞILMAYAN anahtar geri gelmesin. Yorum satırları
  // atılıyor: gerekçe yorumu o dizeyi ANLATIYOR, kod olarak kurmuyor.
  const kod = uc.split('\n').filter((s) => !/^\s*(\/\/|\*|\/\*)/.test(s)).join('\n');
  assert.ok(!/append_to_response=credits,similar/.test(kod),
    'SSR yine kendine özel `credits,similar` anahtarını kuruyor');
});

test('/tmdb/(tv|movie)/:id ucu istemcinin parametrelerini ATAR', () => {
  const uc = bolum("app.get('/tmdb/*'", 'res.json(veri);');
  // Detay yolu tanınıyor ve `tam` (önbellek anahtarı) ondan kuruluyor.
  assert.match(uc, /const icerikDetayi = \/\^\\\/\(tv\|movie\)/);
  assert.match(uc, /const tam = icerikDetayi\s*\n?\s*\?\s*icerikTmdbYolu\(/);
  // İstemci gönderdi diye dokunmama davranışı GERİ GELMESİN: eski kod
  // `!parametreler.has('append_to_response')` koşuluyla istemciye uyuyordu.
  assert.ok(!/\(tv\|movie\)\\\/\\d\+\$\/\.test\(yol\) && !parametreler\.has/.test(uc),
    'detay ucu yine istemcinin append/sıra tercihine uyuyor');
});

test('server.js içinde SSR için ayrı bir TMDB detay anahtarı KALMADI', () => {
  // Yorum satırları hariç: gerçek bir şablon dizesi olarak geçmemeli.
  assert.ok(!/`\/\$\{tur\}\/\$\{tmdbId\}\?append_to_response=/.test(KAYNAK));
});

// ===========================================================================
// 3) İÇ BAĞLANTILAR — `similar` yerine `recommendations` (ölçüldü)
// ===========================================================================
// Canlı önbellek sayımı (20 Ağu 2026):
//   similar         : 554 satır,   6'sı boş (%1,08), ortalama 19,78 sonuç
//   recommendations : 1.933 satır, 3'ü boş (%0,16), ortalama 19,95 sonuç
// Örnek: Arka Sokaklar (tv/32836) `similar`=0 iken `recommendations`=20.
// Yani geçiş bir GERİLEME değil; iç bağlantısız kalan sayfa oranı DÜŞÜYOR.
test('benzer yapım bloğu önce recommendations, yedeği similar', () => {
  const uc = bolum("app.get('/og/icerik/:tur/:tmdbId'", "app.get('/og/kisi");
  assert.match(uc, /v\.recommendations\?\.results \|\| v\.similar\?\.results/);
  // Tavan disiplini bozulmadı: 1 ana afiş + 10 oyuncu + 8 benzer = 19 <= 20.
  assert.match(uc, /\.slice\(0, 8\)/);
});

// ===========================================================================
// 4) GÖVDE BÜYÜDÜ AMA SAYFA BÜYÜMEDİ
// ===========================================================================
// Paylaşılan anahtar SSR'a `images`, `videos`, `watch/providers`,
// `external_ids` de getiriyor (canlı ölçüm: ortalama 38,2 kB -> 91,5 kB,
// p95 90,9 kB -> 220,5 kB). Bu YALNIZ ayrıştırma maliyetidir; bot HTML'ine
// tek bayt eklememeli — eklerse hem sayfa şişer hem görsel tavanı delinir.
test('/og/icerik yeni gelen ağır alanları HTML’e BASMIYOR', () => {
  const uc = bolum("app.get('/og/icerik/:tur/:tmdbId'", "app.get('/og/kisi");
  for (const alanAdi of ['v.images', 'v.videos', 'v.external_ids', "v['watch/providers']"]) {
    assert.ok(!uc.includes(alanAdi), `${alanAdi} SSR gövdesine sızmış`);
  }
});

// ===========================================================================
// 5) SSR SÜRE BÜTÇESİ — büyüyen gövde onu zorlamıyor
// ===========================================================================
test('SSR bütçesi hâlâ tek bir TMDB isteğini fazlasıyla karşılıyor', () => {
  const butce = alan(['SSR_BUTCE_MS'], 'SSR_BUTCE_MS');
  assert.ok(butce >= 10000, 'SSR bütçesi 10 sn altına düştüyse bu ölçüm yenilenmeli');
  // İçerik SSR'ı TÜRKÇEDE TEK TMDB isteği yapar (bölüm kuyruğu ayrı, o zaten
  // vardı). 29 Ağu 2026'da İKİNCİ bir çağrı eklendi ama KOŞULLU: yalnız
  // istenen dilde TMDB özeti YOKSA ve dilin Argos çifti varsa İngilizce yük
  // okunur. Türkçe/İngilizce sayfada `argosDiliMi(dil)` false, yani bu dal
  // HİÇ çalışmaz — bugünkü tek-istek davranışı aynen korunur.
  const uc = bolum("app.get('/og/icerik/:tur/:tmdbId'", "app.get('/og/kisi");
  assert.equal((uc.match(/tmdbGetir\(/g) || []).length, 2);
  assert.match(uc, /if \(!ozetMetni && argosDiliMi\(dil\)\)/,
    'ikinci TMDB çağrısı koşulsuz — her SSR isteği iki katına çıkar');
});

// ===========================================================================
// 6) ESKİ ANAHTARLAR ÇÖP OLUYOR — budama onları TOPLUYOR
// ===========================================================================
// Hizalamadan sonra eski `?append_to_response=credits,similar` satırlarını
// kimse okumayacak. Elle temizlik SQL'i GEREKMİYOR: günlük budama 30 günden
// eski TÜM `tmdb_onbellek` satırlarını siliyor, bu satırlar da 30 gün içinde
// düşecek. Bu test o güvencenin kaybolmadığını kilitler.
test('günlük budama eskiyen önbellek satırlarını siliyor', () => {
  const buda = bolum('async function tablolariBuda()', 'for (const sql of isler)');
  assert.match(buda, /DELETE FROM tmdb_onbellek WHERE guncelleme < now\(\) - interval '30 days'/);
});
