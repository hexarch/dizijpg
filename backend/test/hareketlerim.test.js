// HAREKETLERİM (istek md. 20) — `node --test test/*.test.js`
//
// "Kullanıcı kendi hareketlerini görsün: beğenileri, yorumları, izlemeleri,
//  takipleri, izledikleri, gördükleri vb."
//
// `GET /hareketlerim` sekiz MEVCUT tabloyu (yorumlar, yorum_begeniler,
// puanlar, tepkiler, izlemeler, durumlar, liste_ogeleri, takipler) tek bir
// UNION ALL ile ortak biçime indirger ve `(tarih DESC, anahtar DESC)`
// sırasında imleçle sayfalar.
//
// BU DOSYA İKİ KATMANI BİRDEN TUTAR:
//
//  1) YAPI — sorgu kurucular (`hareketAltSorgu`, `hareketSorgusu`) ve imleç
//     çözücü KAYNAKTAN ÇEKİLİP GERÇEKTEN ÇALIŞTIRILIYOR. Üretilen SQL'in her
//     dalının SAHİPLİK süzgeci, kendi LIMIT'i, aynı sütun listesi, C
//     sıralaması ve KESİN KÜÇÜKTÜR imleç karşılaştırması taşıdığı sınanıyor.
//     (server.js içe aktarılamıyor: modül yüklenir yüklenmez `app.listen`
//     çağırıyor — engelleme/kisi_tepkisi testleriyle aynı gerekçe.)
//
//  2) DAVRANIŞ — §9'daki bölüm sorguyu GERÇEK POSTGRES'te çalıştırır: her tür
//     dönüyor mu, sıralama doğru mu, sayfalama tekrar/atlama yapıyor mu,
//     başkasının verisi sızıyor mu, silinmiş hedef çökertiyor mu.
//     ÇALIŞTIRMA (isteğe bağlı, dağıtım ritüelinde):
//
//         createdb hareket_test
//         psql -q -d hareket_test -f backend/sema.sql
//         HAREKET_DB=hareket_test npm test --prefix backend
//
//     `HAREKET_DB` yoksa bölüm ATLANIR — `npm test` her makinede, veritabanı
//     kurulu olmasa da yeşil kalır. Yapı testleri (§1-8) her koşulda çalışır.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const oku = (a) => fs.readFileSync(path.join(KOK, a), 'utf8');

const KAYNAK = oku('server.js');
const SEMA = oku('sema.sql');
const MIGRASYON = oku('migrasyon-2026-08-14b.sql');

// Migrasyonun YORUM OLMAYAN satırları: gerekçe metni komut sanılmasın
// (geri alma bölümü bilerek DROP INDEX örneği içerir).
const MIGRASYON_KOMUTLARI = MIGRASYON.split('\n')
  .filter((s) => !s.trim().startsWith('--')).join('\n');

// ---------------------------------------------------------------------------
// Kaynaktan kod çekme (engelleme.test.js kalıbı)
// ---------------------------------------------------------------------------

/** `bas` indeksindeki ilk `ac`/`kapa` çiftini dengeleyerek bloğu döndürür. */
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

/** `function ad(...) {...}` bildirimini kaynaktan çeker. */
function fonksiyonMetni(ad) {
  const m = new RegExp(`^function ${ad}\\b`, 'm').exec(KAYNAK);
  assert.ok(m, `${ad} bildirimi bulunamadı`);
  return blokAl(KAYNAK, m.index, '{', '}');
}

/** `const AD = { ... };` / `const AD = [ ... ];` gövdesini çeker. */
function sabitMetni(ad, ac, kapa) {
  const m = new RegExp(`^const ${ad} = \\${ac}`, 'm').exec(KAYNAK);
  assert.ok(m, `${ad} bildirimi bulunamadı`);
  return blokAl(KAYNAK, KAYNAK.indexOf(ac, m.index), ac, kapa);
}

/** `app.<metot>('<yol>'` ile başlayan uç kaydının TAM gövdesi. */
function ucGovdesi(metot, yol) {
  const ara = `app.${metot}('${yol}'`;
  const bas = KAYNAK.indexOf(ara);
  assert.ok(bas >= 0, `uç bulunamadı: ${metot.toUpperCase()} ${yol}`);
  return blokAl(KAYNAK, bas + ara.length - 1, '(', ')');
}

// Sorgu kurucular canlı koddan derlenip ÇALIŞTIRILIYOR — test kopyayı değil
// gerçekten yayına giden kurucuyu sınar.
const {
  HAREKET_SUTUNLAR, HAREKET_TARIFLERI, HAREKET_TURLERI,
  hareketAltSorgu, hareketSorgusu, hareketImlecCoz, HAREKET_SAYFA,
} = new Function(`
  ${fonksiyonMetni('engelSuzgec')}
  const HAREKET_SAYFA = ${/^const HAREKET_SAYFA = (\d+)/m.exec(KAYNAK)[1]};
  const HAREKET_SUTUNLAR = ${sabitMetni('HAREKET_SUTUNLAR', '[', ']')};
  const HAREKET_TARIFLERI = ${sabitMetni('HAREKET_TARIFLERI', '{', '}')};
  const HAREKET_TURLERI = Object.keys(HAREKET_TARIFLERI);
  ${fonksiyonMetni('hareketAltSorgu')}
  ${fonksiyonMetni('hareketSorgusu')}
  ${fonksiyonMetni('hareketImlecCoz')}
  return { HAREKET_SUTUNLAR, HAREKET_TARIFLERI, HAREKET_TURLERI,
           hareketAltSorgu, hareketSorgusu, hareketImlecCoz, HAREKET_SAYFA };
`)();

const TUM_SORGU = hareketSorgusu(HAREKET_TURLERI);
const UC = ucGovdesi('get', '/hareketlerim');

// İsteğin saydığı sekiz kaynak. Biri düşerse "vb." kısalır — liste kayıt
// değil KARARIN kendisidir.
const BEKLENEN_TURLER = [
  'yorum', 'begeni', 'puan', 'tepki', 'izleme', 'durum', 'liste', 'takip',
];

// Tür → satırın SAHİBİNİ belirleyen sütun. Bu eşleme yanlış olursa uç
// BAŞKASININ verisini döndürür; §2 her dalda bunu arar.
const SAHIP_SUTUNU = {
  yorum: 'y.kullanici_id',
  begeni: 'b.kullanici_id',
  puan: 'p.kullanici_id',
  tepki: 't.kullanici_id',
  izleme: 'i.kullanici_id',
  durum: 'd.kullanici_id',
  liste: 'l.kullanici_id', // öğede değil LİSTEDE
  takip: 'tk.takip_eden_id',
};

// ===========================================================================
// 1. HER TÜR VAR — istek "vb." dediyse de sekiz kaynak da bağlı
// ===========================================================================

test('sekiz hareket türünün hepsi tarifli', () => {
  assert.deepEqual(HAREKET_TURLERI, BEKLENEN_TURLER);
});

test('birleşik sorgu her türü kendi etiketiyle üretir', () => {
  for (const tur of BEKLENEN_TURLER) {
    assert.match(TUM_SORGU, new RegExp(`SELECT '${tur}'::text AS tur`),
      `${tur} dalı birleşik sorguda yok`);
  }
});

test('her tür DOĞRU tabloya bağlanır', () => {
  const tablo = {
    yorum: 'yorumlar y', begeni: 'yorum_begeniler b', puan: 'puanlar p',
    tepki: 'tepkiler t', izleme: 'izlemeler i', durum: 'durumlar d',
    liste: 'liste_ogeleri o', takip: 'takipler tk',
  };
  for (const [tur, kaynak] of Object.entries(tablo)) {
    assert.ok(HAREKET_TARIFLERI[tur].kaynak.startsWith(kaynak),
      `${tur} yanlış tabloya bağlı: ${HAREKET_TARIFLERI[tur].kaynak}`);
  }
});

test('YENİ TABLO AÇILMADI: tarifler yalnız mevcut tablolara dokunur', () => {
  const mevcut = [
    'yorumlar', 'yorum_begeniler', 'puanlar', 'tepkiler', 'izlemeler',
    'durumlar', 'liste_ogeleri', 'listeler', 'takipler', 'kullanicilar',
    'engellemeler',
  ];
  for (const ad of mevcut) {
    assert.match(SEMA, new RegExp(`CREATE TABLE IF NOT EXISTS ${ad}\\b`),
      `${ad} şemada yok`);
  }
  // Migrasyon YALNIZ indeks kurar: tablo/kolon eklemez, veri silmez.
  assert.doesNotMatch(MIGRASYON_KOMUTLARI, /CREATE TABLE|ALTER TABLE|DROP TABLE|DELETE FROM/);
});

// ===========================================================================
// 2. BAŞKASININ VERİSİ ASLA — her dal sahiplik süzgecinden geçer
// ===========================================================================

test('her dal $1 (benim id) ile sahiplik süzgeci uygular', () => {
  for (const tur of BEKLENEN_TURLER) {
    const sql = hareketAltSorgu(tur);
    const beklenen = `${SAHIP_SUTUNU[tur]} = $1`;
    assert.ok(sql.includes(beklenen),
      `${tur} dalında sahiplik süzgeci yok (beklenen: ${beklenen})`);
  }
});

test('liste dalı sahibi ÖĞEDEN değil LİSTEDEN okur', () => {
  // `liste_ogeleri`nde kullanici_id YOKTUR; süzgeç `listeler`e bağlanmazsa
  // uç herkesin liste öğesini döndürürdü.
  const sql = hareketAltSorgu('liste');
  assert.match(sql, /liste_ogeleri o LEFT JOIN listeler l ON l\.id = o\.liste_id/);
  assert.ok(sql.includes('l.kullanici_id = $1'));
  const bas = SEMA.indexOf('CREATE TABLE IF NOT EXISTS liste_ogeleri');
  const tanim = SEMA.slice(bas, SEMA.indexOf(');', bas));
  assert.doesNotMatch(tanim, /kullanici_id/,
    'liste_ogeleri artık kullanici_id taşıyor — süzgeç gözden geçirilmeli');
});

test('uç kimliği YALNIZ oturumdan alır — istemciden kullanıcı id\'si okumaz', () => {
  assert.ok(UC.includes('req.kullanici.id'), 'oturum kimliği kullanılmıyor');
  assert.doesNotMatch(UC, /req\.query\.(kullanici|kullanici_id|id)\b/);
  assert.doesNotMatch(UC, /req\.params/);
});

test('uç girisZorunlu ve hız limitiyle korunur', () => {
  assert.match(KAYNAK, /app\.get\('\/hareketlerim', girisZorunlu, hareketLimiti,/);
  assert.match(KAYNAK, /const hareketLimiti = hizLimiti\(\d+, \(req\) => `hr:\$\{req\.kullanici\.id\}`\)/);
});

test('kişisel veri önbelleğe alınmaz (private, no-store)', () => {
  assert.match(UC, /res\.set\('Cache-Control', 'private, no-store'\)/);
});

// ===========================================================================
// 3. UNION ALL TÜR UYUMU — her dal AYNI sütunları AYNI sırayla üretir
// ===========================================================================

test('ortak biçim on sütun: her dal hepsini üretir', () => {
  assert.deepEqual(HAREKET_SUTUNLAR, [
    'hedef_tur', 'tmdb_id', 'sezon', 'bolum',
    'yorum_id', 'liste_id', 'ad', 'avatar', 'ozet', 'deger',
  ]);
  for (const tur of BEKLENEN_TURLER) {
    for (const sutun of HAREKET_SUTUNLAR) {
      assert.ok(HAREKET_TARIFLERI[tur].alanlar[sutun] !== undefined,
        `${tur} dalında ${sutun} alanı yok — UNION ALL tür uyuşmazlığı`);
    }
    assert.equal(Object.keys(HAREKET_TARIFLERI[tur].alanlar).length,
      HAREKET_SUTUNLAR.length, `${tur} dalında FAZLA alan var`);
  }
});

test('her dal sütunları AYNI SIRADA yazar (UNION ALL konuma göre eşler)', () => {
  for (const tur of BEKLENEN_TURLER) {
    const sql = hareketAltSorgu(tur);
    const sira = HAREKET_SUTUNLAR
      .map((s) => sql.indexOf(` AS ${s}`))
      .filter((i) => i >= 0);
    assert.equal(sira.length, HAREKET_SUTUNLAR.length, `${tur}: eksik sütun`);
    assert.deepEqual(sira, [...sira].sort((a, b) => a - b),
      `${tur} dalında sütun sırası bozuk`);
  }
});

test('boş alanlar TÜRLÜ NULL yazar (NULL::int / NULL::text)', () => {
  // Kapsamsız `NULL` UNION ALL'da "text" varsayılır ve int sütunla çakışır.
  for (const tur of BEKLENEN_TURLER) {
    for (const [sutun, ifade] of Object.entries(HAREKET_TARIFLERI[tur].alanlar)) {
      if (/^NULL\b/.test(ifade.trim())) {
        assert.match(ifade, /^NULL::(int|text)$/,
          `${tur}.${sutun} kapsamsız NULL yazıyor`);
      }
    }
  }
});

// ===========================================================================
// 4. SAYFALAMA — dal başına LIMIT, kesin küçüktür imleç, eşitlik bozucu
// ===========================================================================

test('HER dal kendi içinde LIMIT\'lidir (8 tabloyu birleştirip sıralamaz)', () => {
  for (const tur of BEKLENEN_TURLER) {
    assert.match(hareketAltSorgu(tur), /ORDER BY [^\n]*DESC\n?\s*LIMIT \$4\)$/,
      `${tur} dalında kendi LIMIT'i yok`);
  }
  // 8 dal + 1 dış limit
  assert.equal((TUM_SORGU.match(/LIMIT \$4/g) || []).length,
    BEKLENEN_TURLER.length + 1);
});

test('dış sorgu (tarih DESC, anahtar DESC) ile sıralar ve limitler', () => {
  assert.match(TUM_SORGU, /ORDER BY h\.tarih DESC, h\.anahtar DESC\s*\n?\s*LIMIT \$4/);
});

test('her dal dıştakiyle AYNI sırayı üretir (dal limiti satır kaçırmaz)', () => {
  // Dal içi sıralama dıştakinden farklı olsaydı, dalın ilk 31'i küresel ilk
  // 31'i içermeyebilir ve satır SESSİZCE kaybolurdu.
  for (const tur of BEKLENEN_TURLER) {
    const t = HAREKET_TARIFLERI[tur];
    const sql = hareketAltSorgu(tur);
    assert.ok(sql.includes(`ORDER BY ${t.tarih} DESC, `),
      `${tur}: dal sıralaması tarih DESC ile başlamıyor`);
    assert.match(sql, /ORDER BY .*DESC, .*anahtar-yok|ORDER BY [^\n]*COLLATE "C"\) DESC/,
      `${tur}: dal sıralamasında anahtar eşitlik bozucusu yok`);
  }
});

test('imleç KESİN küçüktür + eşitlik dalı: ne tekrar ne atlama', () => {
  for (const tur of BEKLENEN_TURLER) {
    const t = HAREKET_TARIFLERI[tur];
    const sql = hareketAltSorgu(tur);
    // "tarih < imleç" tek başına EŞİT tarihli satırları ATLARDI;
    // "tarih <= imleç" ise son satırı TEKRARLARDI. İkisi birlikte doğru.
    assert.ok(sql.includes(`${t.tarih} < $2::timestamptz`), `${tur}: kesin küçüktür yok`);
    assert.ok(sql.includes(`${t.tarih} = $2::timestamptz AND `), `${tur}: eşitlik dalı yok`);
    assert.doesNotMatch(sql, /<= \$2::timestamptz/, `${tur}: <= tekrar üretir`);
    assert.ok(sql.includes('< $3::text'), `${tur}: anahtar eşitlik bozucusu yok`);
    assert.ok(sql.includes('$2::timestamptz IS NULL'), `${tur}: ilk sayfa dalı yok`);
  }
});

test('anahtar önekleri TÜRE ÖZEL: sıralama anahtarı akış genelinde benzersiz', () => {
  const onekler = BEKLENEN_TURLER.map((t) => {
    const m = /^'([a-z]+):'/.exec(HAREKET_TARIFLERI[t].anahtar);
    assert.ok(m, `${t}: anahtar '<tur>:' ile başlamıyor`);
    return m[1];
  });
  assert.deepEqual(onekler, BEKLENEN_TURLER);
  assert.equal(new Set(onekler).size, onekler.length);
});

test('anahtar HER YERDE COLLATE "C" — üç karşılaştırma aynı sırayı verir', () => {
  // SELECT, WHERE ve ORDER BY aynı ifadeyi kullanır; C sıralaması bayt
  // sırasıdır, veritabanı yerel ayarı değişse de üçü ayrışmaz.
  for (const tur of BEKLENEN_TURLER) {
    const sql = hareketAltSorgu(tur);
    assert.equal((sql.match(/COLLATE "C"/g) || []).length, 3,
      `${tur}: COLLATE "C" üç yerde olmalı (SELECT/WHERE/ORDER BY)`);
  }
});

test('sayfa boyu 30, sunucu bir fazlasını isteyip "devam" kararını verir', () => {
  assert.equal(HAREKET_SAYFA, 30);
  assert.ok(UC.includes('HAREKET_SAYFA + 1'), 'bir fazlası istenmiyor');
  assert.match(UC, /const devam = rows\.length > HAREKET_SAYFA/);
  assert.match(UC, /rows\.slice\(0, HAREKET_SAYFA\)/);
  // Devamı yoksa imleç NULL: istemci boşuna istek atmasın.
  assert.match(UC, /imlec: devam && son\s*\n?\s*\?/);
});

// ===========================================================================
// 5. İMLEÇ ÇÖZÜCÜ — çalıştırılarak sınanır
// ===========================================================================

test('imleç: boş istek ilk sayfadır (tarih null)', () => {
  assert.deepEqual(hareketImlecCoz(''), { tarih: null, anahtar: '' });
  assert.deepEqual(hareketImlecCoz(undefined), { tarih: null, anahtar: '' });
});

test('imleç: geçerli "<ISO>|<anahtar>" çözülür', () => {
  const c = hareketImlecCoz('2026-08-01T05:00:00.000Z|izleme:tv:1396:1:1');
  assert.equal(c.tarih, '2026-08-01T05:00:00.000Z');
  assert.equal(c.anahtar, 'izleme:tv:1396:1:1');
});

test('imleç: bozuk girdi null döner (uç 400 verir, 500 DEĞİL)', () => {
  for (const kotu of [
    'ayracyok', '|anahtar', '2026-13-45T99:99:99Z|x', 'abc|x',
    `2026-08-01T05:00:00Z|${'a'.repeat(200)}`, '2026-08-01T05:00:00Z|',
  ]) {
    assert.equal(hareketImlecCoz(kotu), null, `bozuk imleç kabul edildi: ${kotu}`);
  }
  assert.match(UC, /if \(!imlec\) return res\.status\(400\)/);
});

test('geçersiz ?tur= 400 döner (SQL\'e enterpolasyon YOK)', () => {
  assert.match(UC, /!HAREKET_TURLERI\.includes\(istenenTur\)/);
  assert.match(UC, /return res\.status\(400\)\.json\(\{ hata: 'Geçersiz tür' \}\)/);
  // Tür adı sorguya ancak beyaz listeden geçtikten sonra girer.
  assert.doesNotMatch(UC, /req\.query\.tur[^)]*\)\s*\+/);
});

// ===========================================================================
// 6. SİLİNMİŞ HEDEF — satır çöker değil, boş döner
// ===========================================================================

test('hedef taşıyan her dal LEFT JOIN kullanır', () => {
  for (const tur of BEKLENEN_TURLER) {
    const kaynak = HAREKET_TARIFLERI[tur].kaynak;
    if (!/JOIN/.test(kaynak)) continue;
    assert.doesNotMatch(kaynak, /(?<!LEFT )\bJOIN\b/,
      `${tur}: iç JOIN silinmiş hedefte satırı DÜŞÜRÜR`);
  }
});

test('silinmiş yorumun beğenisi engel süzgecine TAKILMAZ', () => {
  // `NULL NOT IN (...)` NULL döner ve satır sessizce elenirdi; açık
  // "IS NULL VEYA" dalı olmadan silinmiş hedefli beğeni kaybolur.
  assert.ok(HAREKET_TARIFLERI.begeni.ek.startsWith('(y.kullanici_id IS NULL OR '));
});

// ===========================================================================
// 7. ENGELLEME (md. 19) İLE İLİŞKİ — kararın kendisi
// ===========================================================================

test('begeni dalı engel süzgecini yorumun YAZARINA uygular', () => {
  // Engellenen kişinin yorumunu beğenmişsem satır onun metnini, adını ve
  // avatarını taşır; süzülmezse bu ekran engelin arka kapısı olur.
  const sql = hareketAltSorgu('begeni');
  assert.match(sql, /y\.kullanici_id NOT IN \(\s*SELECT engellenen_id FROM engellemeler WHERE engelleyen_id=\$1/);
  assert.match(sql, /UNION SELECT engelleyen_id FROM engellemeler WHERE engellenen_id=\$1/);
});

test('KENDİ verisi olan altı tür süzülmez (gerekçesi: hedefi TMDB/kendi listem)', () => {
  for (const tur of ['yorum', 'puan', 'tepki', 'izleme', 'durum', 'liste']) {
    assert.equal(HAREKET_TARIFLERI[tur].ek, undefined,
      `${tur}: gereksiz engel süzgeci (hedefi başka kullanıcı değil)`);
  }
});

test('takip dalında süzgeç YOK çünkü ENGEL TAKİBİ ZATEN SİLİYOR', () => {
  // Karar ölü koda dayanmasın diye gerekçe BURADA doğrulanıyor: engel kurma
  // ucu `takipler`i iki yönde siliyorsa engelli bir takip satırı hiç kalmaz.
  assert.equal(HAREKET_TARIFLERI.takip.ek, undefined);
  const engelle = ucGovdesi('post', '/engelle/:kullaniciAdi');
  assert.match(engelle, /DELETE FROM takipler WHERE \(takip_eden_id=\$1 AND takip_edilen_id=\$2\)\s*\n?\s*OR \(takip_eden_id=\$2 AND takip_edilen_id=\$1\)/);
});

// ===========================================================================
// 8. N+1 YOK + İNDEKSLER
// ===========================================================================

test('TMDB zenginleştirme TEK toplu çağrı (icerikBilgileri), satır başına DEĞİL', () => {
  assert.match(UC, /const icerikler = anahtarlar\.length \? await icerikBilgileri\(anahtarlar\) : \{\}/);
  assert.doesNotMatch(UC, /tmdbGetir\(/, 'satır başına TMDB çağrısı (N+1)');
  // Hedef anahtarları önce TEKİLLEŞTİRİLİR
  assert.match(UC, /\[\.\.\.new Set\(sayfa/);
});

test('sayfa TEK sorguyla gelir: uçta ikinci havuz sorgusu yok', () => {
  assert.equal((UC.match(/havuz\.query\(/g) || []).length, 1);
});

test('migrasyon 8 eksik indeksi kurar', () => {
  const indeksler = [
    ['yorum_begeniler_kullanici_tarih', 'yorum_begeniler (kullanici_id, tarih DESC)'],
    ['izlemeler_kullanici_tarih', 'izlemeler (kullanici_id, tarih DESC)'],
    ['takipler_eden_tarih', 'takipler (takip_eden_id, tarih DESC)'],
    ['puanlar_kullanici_tarih', 'puanlar (kullanici_id, tarih DESC)'],
    ['durumlar_kullanici_guncelleme', 'durumlar (kullanici_id, guncelleme DESC)'],
    ['tepkiler_kullanici_tarih', 'tepkiler (kullanici_id, tarih DESC)'],
    ['listeler_kullanici', 'listeler (kullanici_id)'],
    ['liste_ogeleri_eklenme', 'liste_ogeleri (liste_id, eklenme DESC)'],
  ];
  for (const [ad, tanim] of indeksler) {
    assert.ok(MIGRASYON_KOMUTLARI.includes(`CREATE INDEX IF NOT EXISTS ${ad}`),
      `migrasyonda ${ad} yok`);
    assert.ok(MIGRASYON_KOMUTLARI.includes(`ON ${tanim}`), `${ad} tanımı yanlış`);
    // SIFIRDAN KURULAN veritabanı da aynı indeksleri almalı.
    assert.ok(SEMA.includes(`CREATE INDEX IF NOT EXISTS ${ad}`),
      `sema.sql'de ${ad} yok — yeni kurulum yavaş kalır`);
  }
});

test('yorumlar için indeks EKLENMEZ: zaten var', () => {
  assert.match(SEMA, /idx_yorum_kullanici ON yorumlar\(kullanici_id, tarih DESC\)/);
  assert.doesNotMatch(MIGRASYON_KOMUTLARI, /ON yorumlar\b/);
});

test('her dalın sıralama sütunu indeksin ÖNDEKİ sütunlarıyla eşleşir', () => {
  const beklenen = {
    yorum: 'y.tarih', begeni: 'b.tarih', puan: 'p.tarih', tepki: 't.tarih',
    izleme: 'i.tarih', durum: 'd.guncelleme', liste: 'o.eklenme', takip: 'tk.tarih',
  };
  for (const [tur, sutun] of Object.entries(beklenen)) {
    assert.equal(HAREKET_TARIFLERI[tur].tarih, sutun,
      `${tur}: zaman sütunu indeksle uyumsuz`);
  }
});

// ===========================================================================
// 9. DAVRANIŞ — GERÇEK POSTGRES (HAREKET_DB verilmezse atlanır)
// ===========================================================================

const DB = process.env.HAREKET_DB;
const dbSuite = DB ? test : test.skip;

dbSuite('gerçek veritabanı: sıralama, sayfalama, izolasyon, silinmiş hedef', async (t) => {
  const { default: pg } = await import('pg');
  const havuz = new pg.Pool({ database: DB });
  const q = (s, v) => havuz.query(s, v);
  t.after(() => havuz.end());

  // Temiz sayfa (aynı veritabanı tekrar tekrar kullanılabilsin)
  await q(`TRUNCATE kullanicilar, yorumlar, yorum_begeniler, puanlar, tepkiler,
           izlemeler, durumlar, listeler, liste_ogeleri, takipler, engellemeler
           RESTART IDENTITY CASCADE`);
  await q(`INSERT INTO kullanicilar (id, kullanici_adi) VALUES
           (1,'ben'),(2,'baskasi'),(3,'engelli')`);
  await q(`INSERT INTO yorumlar (id, kullanici_id, tur, tmdb_id, metin, tarih) VALUES
           (10,1,'tv',1399,'yorumum','2026-08-01T01:00:00Z'),
           (11,2,'movie',550,'onun yorumu','2026-08-01T00:30:00Z'),
           (12,3,'tv',66732,'engellinin yorumu','2026-08-01T00:20:00Z')`);
  await q(`INSERT INTO yorum_begeniler (yorum_id, kullanici_id, tarih) VALUES
           (11,1,'2026-08-01T02:00:00Z'),(12,1,'2026-08-01T02:30:00Z'),
           (10,2,'2026-08-01T09:00:00Z')`);
  await q(`INSERT INTO puanlar (kullanici_id, tur, tmdb_id, puan, tarih) VALUES
           (1,'movie',603,9,'2026-08-01T03:00:00Z'),
           (2,'movie',603,3,'2026-08-01T09:00:00Z')`);
  await q(`INSERT INTO tepkiler (kullanici_id, tur, tmdb_id, emoji, tarih) VALUES
           (1,'tv',1396,'😍','2026-08-01T04:00:00Z')`);
  await q(`INSERT INTO izlemeler (kullanici_id, tur, tmdb_id, sezon, bolum, tarih) VALUES
           (1,'tv',1396,1,1,'2026-08-01T05:00:00Z'),
           (1,'movie',603,0,0,'2026-08-01T05:30:00Z')`);
  await q(`INSERT INTO durumlar (kullanici_id, tur, tmdb_id, durum, guncelleme) VALUES
           (1,'tv',1396,'izliyorum','2026-08-01T06:00:00Z')`);
  await q(`INSERT INTO listeler (id, kullanici_id, ad) VALUES (5,1,'Favorilerim'),(6,2,'Onunki')`);
  await q(`INSERT INTO liste_ogeleri (liste_id, tur, tmdb_id, eklenme) VALUES
           (5,'tv',1399,'2026-08-01T07:00:00Z'),(6,'tv',999,'2026-08-01T09:00:00Z')`);
  await q(`INSERT INTO takipler (takip_eden_id, takip_edilen_id, tarih) VALUES
           (1,2,'2026-08-01T08:00:00Z'),(2,1,'2026-08-01T09:00:00Z')`);

  const calistir = async (imlec, anahtar, limit, turler = HAREKET_TURLERI) =>
    (await q(hareketSorgusu(turler), [1, imlec, anahtar, limit])).rows;

  // --- her tür dönüyor + sıralama ---
  const hepsi = await calistir(null, '', 100);
  assert.deepEqual(
    [...new Set(hepsi.map((r) => r.tur))].sort(),
    [...BEKLENEN_TURLER].sort(), 'birleşik sorgu her türü döndürmüyor');
  for (let i = 1; i < hepsi.length; i++) {
    assert.ok(new Date(hepsi[i].tarih) <= new Date(hepsi[i - 1].tarih),
      'sıralama bozuk: en yeni üstte değil');
  }
  assert.equal(hepsi[0].anahtar, 'takip:2', 'en yeni hareket başta değil');

  // --- başkasının verisi ASLA ---
  for (const yabanci of ['yorum:11', 'liste:6:tv:999', 'begeni:10']) {
    assert.ok(!hepsi.some((r) => r.anahtar === yabanci),
      `başkasının verisi sızdı: ${yabanci}`);
  }
  assert.equal((await calistir(null, '', 100, ['puan'])).length, 1);
  assert.equal((await calistir(null, '', 100, ['takip'])).length, 1);

  // --- tür süzgeci ---
  for (const tur of BEKLENEN_TURLER) {
    const r = await calistir(null, '', 100, [tur]);
    assert.ok(r.every((x) => x.tur === tur), `?tur=${tur} başka tür döndürdü`);
  }

  // --- engelleme: iki yönde de beğeni düşer ---
  assert.ok(hepsi.some((r) => r.anahtar === 'begeni:12'), 'engelsizken beğeni yok');
  for (const [a, b] of [[1, 3], [3, 1]]) {
    await q('DELETE FROM engellemeler');
    await q('INSERT INTO engellemeler (engelleyen_id, engellenen_id) VALUES ($1,$2)', [a, b]);
    const r = await calistir(null, '', 100);
    assert.ok(!r.some((x) => x.anahtar === 'begeni:12'),
      `engel ${a}->${b}: engellinin yorumuna verilen beğeni hâlâ görünüyor`);
    assert.ok(r.some((x) => x.anahtar === 'begeni:11'), 'engelsiz beğeni de düştü');
  }
  await q('DELETE FROM engellemeler');

  // --- silinmiş hedef: satır döner, ÇÖKMEZ ---
  await q('ALTER TABLE yorum_begeniler DROP CONSTRAINT IF EXISTS yorum_begeniler_yorum_id_fkey');
  await q(`INSERT INTO yorum_begeniler (yorum_id, kullanici_id, tarih)
           VALUES (9999,1,'2026-08-01T02:45:00Z')`);
  const oksuzlu = await calistir(null, '', 100);
  const oksuz = oksuzlu.find((r) => r.anahtar === 'begeni:9999');
  assert.ok(oksuz, 'silinmiş hedefli satır kayboldu');
  assert.equal(oksuz.hedef_tur, null);
  assert.equal(oksuz.ad, null);

  // --- EŞİT TARİHLİ blok (toplu içe aktarım) ---
  await q(`INSERT INTO izlemeler (kullanici_id, tur, tmdb_id, sezon, bolum, tarih)
           SELECT 1,'tv',1396,2,g,'2026-07-01T00:00:00Z' FROM generate_series(1,50) g`);

  // --- sayfalama: tekrar YOK, atlama YOK (tek seferlik listeyle birebir) ---
  const tam = (await calistir(null, '', 5000)).map((r) => r.anahtar);
  assert.equal(new Set(tam).size, tam.length, 'sıralama anahtarı benzersiz değil');
  for (const boy of [1, 3, 7, 30]) {
    const toplanan = [];
    let imlec = null; let anahtar = '';
    for (let adim = 0; adim < 500; adim++) {
      const r = await calistir(imlec, anahtar, boy + 1);
      const devam = r.length > boy;
      const sayfa = devam ? r.slice(0, boy) : r;
      toplanan.push(...sayfa.map((x) => x.anahtar));
      if (!devam || !sayfa.length) break;
      imlec = new Date(sayfa[sayfa.length - 1].tarih).toISOString();
      anahtar = sayfa[sayfa.length - 1].anahtar;
    }
    assert.deepEqual(toplanan, tam,
      `sayfa boyu ${boy}: sayfalama tekrar ya da atlama yaptı`);
  }

  // --- indeksler gerçekten kullanılıyor mu (en hacimli dal) ---
  // Gerçekçi hacim ŞART: birkaç düzine satırda sıralı tarama zaten ucuzdur ve
  // planlayıcı indeksi haklı olarak seçmez. Asıl korunan durum "kitaplığı
  // büyük kullanıcı"; 20 bin satır onu temsil eder.
  await q(`INSERT INTO izlemeler (kullanici_id, tur, tmdb_id, sezon, bolum, tarih)
           SELECT 1,'tv',9000+g,1,1, now() - (g || ' minutes')::interval
             FROM generate_series(1,20000) g`);
  await q('ANALYZE');
  const plan = (await q(
    `EXPLAIN ${hareketSorgusu(['izleme'])}`, [1, null, '', 31],
  )).rows.map((r) => r['QUERY PLAN']).join('\n');
  assert.match(plan, /Index Scan using izlemeler_kullanici_tarih/,
    `izleme dalı indeksi kullanmıyor:\n${plan}`);
});
