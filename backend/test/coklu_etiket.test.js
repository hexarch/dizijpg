// ÇOKLU ETİKET + ETİKETSİZ PAYLAŞIM — `node --test backend/test`
//
// Kullanıcı isteği (30 Ağu 2026, birebir): "Akışta gönderi paylaşırken yapım
// seçme zorunlu olmasın … Oraya da yapım/yönetmen/oyuncu ekle olsun ve 1'den
// fazla eklenebilsin, ve eklenenlerin profilinde de paylaşılacak … Ve
// dizilerde bölüm, sezon veya dizinin kendisini de seçme olacak."
//
// NEDEN KAYNAK OKUMA: `server.js` içe aktarıldığı anda `app.listen` çağırıyor,
// yani uçlar doğrudan import edilemiyor (bu depodaki yerleşik kalıp — bkz.
// kesfet_medya.test.js, yasakli_kullanici_adi.test.js). Saf fonksiyonlar
// (`etiketleriDogrula`, `akisSatiri`, `akisIcerikleri`) kaynaktan çekilip
// GERÇEKTEN çalıştırılıyor; SQL metinleri ise dizge olarak sınanıyor.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const DIZIN = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const KAYNAK = fs.readFileSync(path.join(DIZIN, 'server.js'), 'utf8');
const SEMA = fs.readFileSync(path.join(DIZIN, 'sema.sql'), 'utf8');
const MIG = fs.readFileSync(path.join(DIZIN, 'migrasyon-2026-08-30.sql'), 'utf8');
const MIG_B = fs.readFileSync(path.join(DIZIN, 'migrasyon-2026-08-30b.sql'), 'utf8');

/** Dengeli blok: `bas` konumundaki açtan kapanana kadar. */
function blokAl(kaynak, bas, ac, kapa) {
  let derinlik = 0;
  let girdi = false;
  for (let i = bas; i < kaynak.length; i++) {
    const c = kaynak[i];
    if (c === ac) { derinlik++; girdi = true; } else if (c === kapa) {
      derinlik--;
      if (girdi && derinlik === 0) return kaynak.slice(bas, i + 1);
    }
  }
  throw new Error('blok kapanmadı');
}

/** `function <ad>(...) {...}` bildiriminin TAM metni. */
function fonksiyonCek(ad) {
  const m = new RegExp(`^(async function|function) ${ad}\\b`, 'm').exec(KAYNAK);
  assert.ok(m, `server.js içinde ${ad} bulunamadı`);
  const pAc = KAYNAK.indexOf('(', m.index);
  const par = blokAl(KAYNAK, pAc, '(', ')');
  const govdeBas = KAYNAK.indexOf('{', pAc + par.length);
  return KAYNAK.slice(m.index, govdeBas + blokAl(KAYNAK, govdeBas, '{', '}').length);
}

/** `const <ad> = ...;` bildiriminin TAM metni (şablon dizeleri dahil). */
function sabitCek(ad) {
  const m = new RegExp(`^const ${ad} = `, 'm').exec(KAYNAK);
  assert.ok(m, `server.js içinde ${ad} sabiti bulunamadı`);
  let derinlik = 0;
  let tirnak = null;
  for (let i = m.index; i < KAYNAK.length; i++) {
    const c = KAYNAK[i];
    if (tirnak) {
      if (c === '\\') i++;
      else if (c === tirnak) tirnak = null;
      continue;
    }
    if (c === "'" || c === '"' || c === '`') tirnak = c;
    else if ('{(['.includes(c)) derinlik++;
    else if ('})]'.includes(c)) derinlik--;
    else if (c === ';' && derinlik === 0) return KAYNAK.slice(m.index, i + 1);
  }
  assert.fail(`${ad} bildiriminin sonu bulunamadı`);
  return '';
}

/** Bildirimleri derleyip `ifade`yi döndüren sanal alan. */
function kur(bildirimler, bagimliliklar, ifade) {
  const adlar = Object.keys(bagimliliklar);
  const govde = bildirimler.join('\n');
  // eslint-disable-next-line no-new-func
  return new Function(...adlar, `${govde}\nreturn (${ifade});`)(
    ...adlar.map((a) => bagimliliklar[a]));
}

const sqlSadeles = (s) => s.replace(/\s+/g, ' ').trim();
const UC = (metot, yol) => {
  const bas = KAYNAK.indexOf(`app.${metot}('${yol}'`);
  assert.ok(bas >= 0, `uç bulunamadı: ${metot} ${yol}`);
  const s = KAYNAK.indexOf('sarici(', bas);
  return blokAl(KAYNAK, s + 'sarici'.length, '(', ')');
};

// ===========================================================================
// 1) etiketleriDogrula — GERÇEKTEN ÇALIŞTIRILIYOR
// ===========================================================================
const etiketleriDogrula = kur(
  [sabitCek('YORUM_TURLERI'), sabitCek('YORUM_ETIKET_AZAMI'),
    fonksiyonCek('etiketleriDogrula')],
  { gecerliTmdb: (v) => Number.isInteger(v) && v > 0 },
  'etiketleriDogrula');

test('ETİKETSİZ paylaşım geçerli — boş liste hata DEĞİL', () => {
  // Kullanıcının birinci isteği: "yapım seçme zorunlu olmasın".
  const d = etiketleriDogrula([]);
  assert.equal(d.hata, undefined);
  assert.deepEqual(d.etiketler, []);
});

test('ÇOKLU etiket: Silo + Breaking Bad ikisi de sırayla korunur', () => {
  const d = etiketleriDogrula([
    { tur: 'tv', tmdb_id: 125988 },
    { tur: 'tv', tmdb_id: 1396 },
  ]);
  assert.equal(d.hata, undefined);
  assert.equal(d.etiketler.length, 2);
  assert.equal(d.etiketler[0].tmdb_id, 125988);
  assert.equal(d.etiketler[1].tmdb_id, 1396);
});

test('DÖRT TÜR birlikte: dizi + film + kişi + firma', () => {
  const d = etiketleriDogrula([
    { tur: 'tv', tmdb_id: 1396 }, { tur: 'movie', tmdb_id: 550 },
    { tur: 'person', tmdb_id: 17419 }, { tur: 'company', tmdb_id: 2 },
  ]);
  assert.equal(d.hata, undefined);
  assert.equal(d.etiketler.length, 4);
});

test('ÜÇ DÜZEY: dizi · sezon · bölüm hepsi geçerli', () => {
  // Kullanıcı isteği: "dizilerde bölüm, sezon veya dizinin kendisini de
  // seçme olacak". Sezon düzeyi 30 Ağu'da AÇILDI — eskiden `bolum_sec.dart`
  // yalnız bölüm döndürüyordu ve sunucu sezonsuz/bölümsüz çifti reddediyordu.
  const d = etiketleriDogrula([
    { tur: 'tv', tmdb_id: 125988 },
    { tur: 'tv', tmdb_id: 125988, sezon: 2 },
    { tur: 'tv', tmdb_id: 125988, sezon: 2, bolum: 3 },
  ]);
  assert.equal(d.hata, undefined);
  assert.equal(d.etiketler.length, 3, 'üç düzey ayrı etiket olmalı');
  assert.deepEqual(
    d.etiketler.map((e) => [e.sezon, e.bolum]),
    [[null, null], [2, null], [2, 3]]);
});

test('AYNI varlık iki kez seçilirse SESSİZCE tekilleşir (400 değil)', () => {
  const d = etiketleriDogrula([
    { tur: 'tv', tmdb_id: 1396 }, { tur: 'tv', tmdb_id: 1396 },
  ]);
  assert.equal(d.hata, undefined);
  assert.equal(d.etiketler.length, 1);
});

test('Sezon FİLMDE reddedilir, bölüm SEZONSUZ reddedilir', () => {
  assert.ok(etiketleriDogrula([{ tur: 'movie', tmdb_id: 550, sezon: 1 }]).hata);
  assert.ok(etiketleriDogrula([{ tur: 'tv', tmdb_id: 1396, bolum: 3 }]).hata);
});

test('Tanınmayan tür ve bozuk tmdb_id reddedilir', () => {
  assert.ok(etiketleriDogrula([{ tur: 'kitap', tmdb_id: 1 }]).hata);
  assert.ok(etiketleriDogrula([{ tur: 'tv', tmdb_id: 'abc' }]).hata);
  assert.ok(etiketleriDogrula([{ tur: 'tv', tmdb_id: 1396, sezon: 0 }]).hata);
});

test('Etiket sayısı tavanı uygulanıyor', () => {
  const cok = Array.from({ length: 7 }, (_, i) => ({ tur: 'movie', tmdb_id: i + 1 }));
  assert.ok(etiketleriDogrula(cok).hata, '7 etiket kabul edilmiş');
  assert.equal(etiketleriDogrula(cok.slice(0, 6)).hata, undefined);
});

test('etiketler dizi değilse 400 (istemci bozuk gövde gönderemesin)', () => {
  assert.ok(etiketleriDogrula('tv:1396').hata);
  assert.ok(etiketleriDogrula([null]).hata);
});

// ===========================================================================
// 2) İÇERİK SAYFASI — gönderi HER etiketin sayfasında
// ===========================================================================
test('GET /yorumlar/:tur/:tmdbId eşleşmeyi BAĞ TABLOSUNDA arıyor', () => {
  const uc = sqlSadeles(UC('get', '/yorumlar/:tur/:tmdbId'));
  assert.match(uc, /FROM yorum_etiketleri et/,
    'içerik sayfası hâlâ yorumlar.tur/tmdb_id eşliyor — çoklu etiket görünmez');
  assert.match(uc, /et\.tur = \$1 AND et\.tmdb_id = \$2::int/);
  // Eski koşul GERİ GELMESİN: geri gelirse gönderi yalnız BİRİNCİL etiketin
  // sayfasında görünür ve "ikisinin de profilinde" isteği sessizce ölür.
  assert.doesNotMatch(uc, /WHERE y\.tur=\$1 AND y\.tmdb_id=\$2/,
    'eski tek-etiket koşulu geri gelmiş');
});

test('spoiler perdesi EŞLEŞEN etikete bakar, birincil etikete değil', () => {
  const uc = sqlSadeles(UC('get', '/yorumlar/:tur/:tmdbId'));
  assert.match(uc, /COALESCE\(u\.e_bolum, y\.bolum\) IS NOT NULL/,
    'perde hâlâ y.sezon üzerinden — çapraz etikette yanlış bulanıklık');
  assert.match(uc, /iz\.sezon = COALESCE\(u\.e_sezon, y\.sezon\)/);
});

test('içerik sayfası yanıtı etiket listesini de döndürüyor', () => {
  assert.match(UC('get', '/yorumlar/:tur/:tmdbId'), /\$\{ETIKET_ALANI\}/);
});

test('ETIKET_ALANI sıralı ve boşta [] döner (istemci null kontrolü yapmasın)', () => {
  const s = sqlSadeles(sabitCek('ETIKET_ALANI'));
  assert.match(s, /coalesce\(json_agg\(/);
  assert.match(s, /ORDER BY e\.sira, e\.id/);
  assert.match(s, /'\[\]'::json/);
});

// ===========================================================================
// 3) AKIŞ — etiketsiz gönderi düşmesin, bulanıklaşmasın
// ===========================================================================
test('AKIS_KURAL etiketsiz gönderiyi ELEMİYOR (NULL <> metin tuzağı)', () => {
  const s = sqlSadeles(sabitCek('AKIS_KURAL'));
  assert.match(s, /coalesce\(y\.tur, ''\) <> 'person'/,
    "y.tur <> 'person' üç değerli mantıkta NULL döner: etiketsiz gönderi akıştan düşer");
});

test('AKIS_ALANLAR etiket listesini taşıyor', () => {
  assert.match(sabitCek('AKIS_ALANLAR'), /\$\{ETIKET_ALANI\}/);
});

test('akisSatiri: ETİKETSİZ gönderi spoiler DEĞİL', () => {
  const akisSatiri = kur([fonksiyonCek('ceviriUygula').replace(
    'const dil = istekBaglam.getStore()?.dil || \'tr\';', 'const dil = "tr";'),
  sabitCek('akisSatiri')], {}, 'akisSatiri');
  const temel = {
    id: 1, metin: 'bugün hiçbir şey izlemedim', tur: null, tmdb_id: null,
    kaynak_dil: 'tr',
  };
  // Etiketsizde `guvenli` daima false gelir (eşleşecek kitaplık kaydı yok).
  assert.equal(
    akisSatiri({ ...temel, guvenli: false, spoiler_isaret: false }).spoiler, false,
    'etiketsiz gönderi akışta bulanık çıkıyor — ortada spoiler edilecek şey yok');
  // Yazan kişi işaretlediyse yine bulanık.
  assert.equal(
    akisSatiri({ ...temel, guvenli: false, spoiler_isaret: true }).spoiler, true);
  // ETİKETLİ ve izlenmemiş içerik BULANIK KALMALI (regresyon).
  assert.equal(
    akisSatiri({ ...temel, tur: 'tv', tmdb_id: 1396, guvenli: false, spoiler_isaret: false })
      .spoiler, true,
    'izlenmemiş dizinin bölüm yorumu açığa çıkmış');
});

test('akisIcerikleri: null etiket TMDB çağrısı üretmiyor, tüm etiketler toplanıyor', async () => {
  let istenen = null;
  const akisIcerikleri = kur([fonksiyonCek('akisIcerikleri')], {
    icerikBilgileri: async (a) => { istenen = a; return {}; },
  }, 'akisIcerikleri');
  await akisIcerikleri([
    { tur: null, tmdb_id: null, etiketler: [] },
    {
      tur: 'tv',
      tmdb_id: 125988,
      etiketler: [
        { tur: 'tv', tmdb_id: 125988, sezon: 2, bolum: 3 },
        { tur: 'tv', tmdb_id: 1396, sezon: null, bolum: null },
        { tur: 'person', tmdb_id: 17419, sezon: null, bolum: null },
      ],
    },
  ]);
  assert.ok(!istenen.includes('null:null'),
    'etiketsiz gönderi TMDB\'ye /null/null yolu gönderiyor');
  assert.deepEqual([...istenen].sort(),
    ['person:17419', 'tv:125988', 'tv:1396']);
});

// ===========================================================================
// 4) POST /yorumlar — yazma yolu
// ===========================================================================
test('POST /yorumlar etiketsiz gönderiyi KABUL ediyor (tur/tmdb_id NULL)', () => {
  const uc = sqlSadeles(UC('post', '/yorumlar'));
  // Eski kapı: tür/tmdb_id yoksa koşulsuz 400. Geri gelirse istek ölür.
  assert.doesNotMatch(uc, /if \(!YORUM_TURLERI\.includes\(tur\) \|\| !gecerliTmdb\(tmdb_id\)\) \{/,
    'koşulsuz "tür zorunlu" kapısı geri gelmiş');
  assert.match(uc, /\(tur == null\) !== \(tmdb_id == null\)/,
    'yarım etiket kontrolü yok');
});

test('POST /yorumlar SEZON düzeyini yorumlar.sezon sütununa YAZMIYOR', () => {
  // `y.sezon IS NULL` bu dosyada 20+ yerde "dizi/film geneli" demek; sezon
  // etiketi oraya konsaydı SEO sorguları, akış spoiler kuralı ve içerik
  // sayfası sayaçları hiçbir değişiklik yapılmadan yanlış cevap verirdi.
  const uc = sqlSadeles(UC('post', '/yorumlar'));
  assert.match(uc, /sezon = birincil\?\.bolum != null \? birincil\.sezon : null/,
    'sezon düzeyi yorumlar.sezon sütununa sızıyor');
});

test('POST /yorumlar önce EKLİYOR sonra artığı siliyor (etiketsiz an yok)', () => {
  const uc = UC('post', '/yorumlar');
  const ekle = uc.indexOf('INSERT INTO yorum_etiketleri');
  const sil = uc.indexOf('DELETE FROM yorum_etiketleri');
  assert.ok(ekle > 0 && sil > 0, 'etiket yazma adımı yok');
  assert.ok(ekle < sil,
    'önce silip sonra yazmak gönderiyi bir an ETİKETSİZ bırakır');
  assert.match(sqlSadeles(uc), /ON CONFLICT DO NOTHING/);
});

test('YANIT (ust_id) etiket listesi ALMIYOR — hedef üst yorumdan gelir', () => {
  const uc = sqlSadeles(UC('post', '/yorumlar'));
  assert.match(uc, /if \(ust_id == null\) \{/,
    'yanıtta da istemci etiketi okunuyor — thread başka yapıma kayabilir');
});

// ===========================================================================
// 5) ŞEMA / MİGRASYON
// ===========================================================================
test('migrasyon: tur/tmdb_id NULL\'a açılıyor ve yarım etiket yasak', () => {
  assert.match(MIG, /ALTER COLUMN tur\s+DROP NOT NULL/);
  assert.match(MIG, /ALTER COLUMN tmdb_id DROP NOT NULL/);
  assert.match(MIG, /CHECK \(\(tur IS NULL\) = \(tmdb_id IS NULL\)\)/);
});

test('migrasyon: birincil etiketi TRIGGER yazıyor (uygulama değil)', () => {
  // ai_tohum.js / araclar/seo_bolum_tohum.js / Instagram aktarımı `yorumlar`a
  // DOĞRUDAN INSERT atıyor. Bağ satırını uygulama yazsaydı o yollardan gelen
  // yorumlar içerik sayfasında görünmezdi — sessiz bir gerileme.
  for (const metin of [MIG, SEMA]) {
    assert.match(metin, /CREATE OR REPLACE FUNCTION yorum_birincil_etiket\(\)/);
    assert.match(metin, /AFTER INSERT OR UPDATE OF tur, tmdb_id, sezon, bolum ON yorumlar/);
  }
});

test('migrasyon: 5.211 mevcut yorum geriye dönük dolduruluyor', () => {
  assert.match(MIG, /INSERT INTO yorum_etiketleri[\s\S]*FROM yorumlar y/);
  assert.match(MIG, /ON CONFLICT DO NOTHING/);
});

test('migrasyon: tekil indeks NULL sezon/bölümü de eşitliyor', () => {
  // PostgreSQL 15 öncesi NULL'ları FARKLI sayar: COALESCE olmadan aynı dizi
  // aynı gönderiye defalarca bağlanabilirdi.
  for (const metin of [MIG, SEMA]) {
    assert.match(metin,
      /UNIQUE INDEX IF NOT EXISTS yorum_etiket_tekil[\s\S]*COALESCE\(sezon,-1\), COALESCE\(bolum,-1\)/);
  }
});

test('sema.sql ile migrasyon aynı tabloyu kuruyor (sıfırdan kurulum bozulmasın)', () => {
  assert.match(SEMA, /CREATE TABLE IF NOT EXISTS yorum_etiketleri/);
  assert.match(SEMA, /ALTER TABLE puanlar\s*\n?\s*ADD COLUMN IF NOT EXISTS tasinan_yorum_id/);
  // yorumlar.tur artık NOT NULL DEĞİL — sema.sql geride kalırsa temiz kurulum
  // etiketsiz gönderiyi reddeder ve hata yalnız üretimde görünür.
  const tablo = SEMA.slice(SEMA.indexOf('CREATE TABLE IF NOT EXISTS yorumlar ('));
  const govde = tablo.slice(0, tablo.indexOf(');'));
  assert.doesNotMatch(govde, /tur TEXT NOT NULL/);
  assert.doesNotMatch(govde, /tmdb_id INT NOT NULL/);
});

// ===========================================================================
// 6) İNCELEME TAŞIMA MİGRASYONU (2026-08-30b)
// ===========================================================================
test('taşıma İDEMPOTENT: işaretli satır ikinci koşuda görülmez', () => {
  assert.match(MIG_B, /ADD COLUMN IF NOT EXISTS tasinan_yorum_id/);
  assert.match(MIG_B, /WHERE p\.tasinan_yorum_id IS NULL/);
  assert.match(MIG_B, /SET tasinan_yorum_id = e\.id/);
});

test('taşıma `puanlar.yorum`u SİLMİYOR (moderatör ekranı okuyor)', () => {
  assert.doesNotMatch(MIG_B, /UPDATE puanlar SET yorum\s*=\s*NULL/);
  assert.doesNotMatch(MIG_B, /ALTER TABLE puanlar DROP COLUMN yorum/);
});

test('taşıma ORİJİNAL TARİHİ koruyor ("bugün yazılmış" görünmesin)', () => {
  const govde = MIG_B.slice(MIG_B.indexOf('WITH kaynak AS'));
  assert.match(govde, /INSERT INTO yorumlar \(kullanici_id, tur, tmdb_id, sezon, bolum, metin, tarih\)/);
  assert.doesNotMatch(govde, /now\(\)/, 'taşınan yorum bugüne kayıyor');
});

test('taşıma BİREBİR ÇİFTLERİ atlıyor (2 satır zaten yorum olarak yazılmış)', () => {
  assert.match(MIG_B, /NOT EXISTS \(\s*SELECT 1 FROM yorumlar y/);
  assert.match(MIG_B, /btrim\(y\.metin\) = btrim\(p\.yorum\)/);
});
