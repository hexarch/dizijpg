// ===========================================================================
// GERÇEK İZLEME SÜRESİ — `yapim_sureleri` (21 Ağu 2026)
// ===========================================================================
// NE KORUYOR: ekran süresi artık sabitten (bölüm 42 / film 110) değil, TMDB'nin
// GERÇEK bölüm/film süresinden çıkıyor. Kapsam %100 DEĞİL (ölçülen %92,6), yani
// aynı ekranda gerçek ve tahmini dakikalar YAN YANA toplanıyor. Bu dosyanın
// varlık sebebi, o karışımın kullanıcıya ÇELİŞKİLİ İKİ SAYI göstermemesi:
//
//   DEĞİŞMEZ:  toplam == dizi + film
//              dizi   == "hangi diziyi kaç saat" listesinin toplamı
//              toplam == sure_gercek_dk + sure_tahmini_dk
//
// Bu değişmez, süre kodunun tek satırlık bir düzenlemeyle kırılabileceği
// yerdir: yapım başına listede `eksik` unutulursa alt liste üstteki sayıyı
// tutmaz ve kullanıcı iki farklı rakam görür. Aynı hata bu projede daha önce
// puanlamada yaşandı ("10/10 vs 5.0", app/lib/puan.dart).
//
// Neden kaynak okuma: `server.js` içe aktarıldığı anda `app.listen` çağırıyor
// (seo_gizlilik.test.js ile aynı gerekçe). Saf yardımcılar kaynaktan ÇEKİLİP
// gerçekten ÇALIŞTIRILIYOR — test canlıdaki kodu sınar, kopyasını değil.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { KOK, KAYNAK, bildirimCek, alan } from './yardimci/seo_kaynak.js';
import {
  filmSuresi, sezonSureleri, gecerliDakika,
  FILM_SQL, SEZON_SQL, KAPSAM_SQL, EKSIK_FILM_SQL, EKSIK_SEZON_SQL, TAZE_GUN,
} from '../sure_doldur.js';

const SEMA = fs.readFileSync(path.join(KOK, 'sema.sql'), 'utf8');
const MIGRASYON = fs.readFileSync(
  path.join(KOK, 'migrasyon-2026-08-21e.sql'), 'utf8');

const SURE_ADLARI = ['SURE_DK', 'sureParcalari', 'yapimDakikasi',
  'satirParcalari', 'izlemeDakikasi', 'izlemeKirilimi'];

/** server.js'teki gerçek süre fonksiyonlarını çalıştırılabilir hâlde ver. */
const sure = alan(SURE_ADLARI,
  `{ ${SURE_ADLARI.join(', ')} }`);
const { SURE_DK, yapimDakikasi, izlemeDakikasi, izlemeKirilimi } = sure;

/** Bir uç bloğunun gövdesini kaynaktan çeker. */
function ucGovdesi(yol, metot = 'get') {
  const im = `app.${metot}('${yol}'`;
  const bas = KAYNAK.indexOf(im);
  assert.ok(bas >= 0, `${metot.toUpperCase()} ${yol} bulunamadı`);
  const sonraki = KAYNAK.slice(bas + im.length).search(/\napp\.[a-z]+\('/);
  return sonraki < 0 ? KAYNAK.slice(bas) : KAYNAK.slice(bas, bas + im.length + sonraki);
}

// ===========================================================================
// 1) TABLO GERÇEKTEN VAR — migrasyon ADI ve şema
// ===========================================================================
test('yapim_sureleri hem migrasyonda hem sema.sql\'de tanımlı', () => {
  for (const [ad, metin] of [['migrasyon', MIGRASYON], ['sema.sql', SEMA]]) {
    assert.match(metin, /CREATE TABLE IF NOT EXISTS yapim_sureleri/,
      `${ad} içinde tablo yok`);
    // ANAHTAR `izlemeler`in kullanıcısız aynası olmalı: JOIN'in birebir
    // kalması ve satır ÇOĞALTMAMASI buna bağlı.
    assert.match(metin, /PRIMARY KEY \(tur, tmdb_id, sezon, bolum\)/,
      `${ad} içinde anahtar yanlış`);
  }
});

test('dakika CHECK\'i 0\'ı REDDEDER — "bilinmiyor" ile "0 dakika" ayrışsın', () => {
  // 0 kabul edilseydi TMDB'nin `runtime: 0` kayıtları "süresi bilinen bölüm"
  // sayılır, sabit yedeğine DÜŞMEZ ve kullanıcının izlediği bölüm toplamdan
  // SESSİZCE silinirdi.
  assert.match(SEMA, /dakika\s+INT\s+NOT NULL CHECK \(dakika > 0 AND dakika <= 1000\)/);
  assert.equal(gecerliDakika(0), false);
  assert.equal(gecerliDakika(null), false);
  assert.equal(gecerliDakika(1001), false); // saniye girilmiş bozuk kayıt
  assert.equal(gecerliDakika(23), true);
});

// ===========================================================================
// 2) TEK FORMÜL — üç uç da aynı SQL parçasını kullanıyor
// ===========================================================================
test('SURE_KAYNAK_JOIN + SURE_OLCU_SECIM sabittir, kopyalanmaz', () => {
  const join = bildirimCek('SURE_KAYNAK_JOIN');
  const secim = bildirimCek('SURE_OLCU_SECIM');
  // JOIN dört sütunu da eşlemeli; biri düşerse (ör. sezon) bir dizinin tüm
  // sezonları aynı bölüm süresine bağlanır ve satırlar ÇOĞALIR.
  for (const k of ['s.tur = i.tur', 's.tmdb_id = i.tmdb_id',
    's.sezon = i.sezon', 's.bolum = i.bolum']) {
    assert.ok(join.includes(k), `JOIN eksik: ${k}`);
  }
  // Üç sayı da şart: yalnız `gercek_dk` gelseydi "0 dakika" ile "bilinmiyor"
  // ayrışmazdı.
  assert.ok(secim.includes('count(*)::int AS adet'));
  assert.ok(secim.includes("COALESCE(sum(s.dakika), 0)::int AS gercek_dk"));
  assert.ok(secim.includes('FILTER (WHERE s.dakika IS NULL)::int AS eksik'));
});

test('süre okuyan ÜÇ sorgu da paylaşılan sabitleri kullanıyor', () => {
  // Ömür boyu toplam + tür kırılımı
  const omur = bildirimCek('izlemeSureSatirlari');
  // 7/30/90/365 penceresi
  const pencere = ucGovdesi('/istatistiklerim/izleme');
  // "Hangi diziyi kaç saat"
  const yapim = ucGovdesi('/istatistiklerim/sure');
  for (const [ad, metin] of [['izlemeSureSatirlari', omur],
    ['/istatistiklerim/izleme', pencere], ['/istatistiklerim/sure', yapim]]) {
    assert.ok(metin.includes('${SURE_OLCU_SECIM}'), `${ad}: ölçü kopyalanmış`);
    assert.ok(metin.includes('${SURE_KAYNAK_JOIN}'), `${ad}: JOIN kopyalanmış`);
  }
  // Pencere ucundaki `b * 42 + f * 110` kopyası KALDIRILDI: geri gelirse
  // aynı ekranda iki farklı dakika üretir.
  assert.ok(!/SURE_DK\.tv\s*\+/.test(pencere) && !/\*\s*SURE_DK\.tv/.test(pencere),
    'pencere ucu sabitle yeniden çarpıyor — süre satırlardan gelmeli');
});

test('SQL sıralama ifadesi ile yapimDakikasi AYNI aritmetik', () => {
  // Liste "en çok izlenen" diye sıralanıyor ve sayfa 50'lik: sıra ifadesi
  // JS'ten ayrışırsa kullanıcı en uzun yapımı hiç göremeyebilir.
  const m = /const SURE_DAKIKA_SQL = '([^']+)'/.exec(KAYNAK);
  assert.ok(m, 'SURE_DAKIKA_SQL bulunamadı');
  const ifade = m[1]; // '(gercek_dk + eksik * $5) * (1 + tekrar)'
  const hesapla = new Function('gercek_dk', 'eksik', 'tekrar', 'birim',
    `return ${ifade.replace(/\$5/g, 'birim')};`);
  for (const [tur, adet, tekrar, gercek, eksik] of [
    ['tv', 236, 0, 5428, 0],
    ['tv', 100, 2, 1800, 40],
    ['movie', 12, 1, 1320, 0],
    ['movie', 5, 0, 0, 5],
  ]) {
    assert.equal(
      hesapla(gercek, eksik, tekrar, SURE_DK[tur]),
      yapimDakikasi(tur, adet, tekrar, gercek, eksik),
      `${tur} ${adet}/${eksik} ayrıştı`);
  }
});

// ===========================================================================
// 3) DEĞİŞMEZ — toplam = dizi + film = yapım başına listenin toplamı
// ===========================================================================
//
// Sentetik bir izleme evreni kurulur (bazı bölümlerin süresi VAR, bazısının
// YOK), sonra iki ayrı GROUP BY simüle edilir — tıpkı sunucudaki gibi:
//   · tür + tekrar    → /istatistiklerim  (üstteki sayı)
//   · yapım           → /istatistiklerim/sure  (alttaki liste)
// İkisi aynı sayıyı vermek ZORUNDA.
function evren() {
  const satirlar = [];
  const ekle = (tur, tmdb_id, sezon, bolum, dakika) =>
    satirlar.push({ tur, tmdb_id, sezon, bolum, dakika });
  // Friends: 236 bölüm, hepsi gerçek 23 dk
  for (let b = 1; b <= 236; b++) ekle('tv', 1668, 1 + (b % 10), b, 23);
  // Süresi KISMEN bilinen dizi: 40 bölümün 7'si eksik
  for (let b = 1; b <= 40; b++) ekle('tv', 999, 1, b, b % 6 === 0 ? null : 51);
  // Süresi HİÇ bilinmeyen dizi (yeni yayın, sezon belgesi henüz yok)
  for (let b = 1; b <= 8; b++) ekle('tv', 777, 1, b, null);
  // Filmler: biri gerçek, biri bilinmiyor
  ekle('movie', 550, 0, 0, 139);
  ekle('movie', 551, 0, 0, null);
  ekle('movie', 552, 0, 0, 96);
  return satirlar;
}
const TEKRAR = { 'tv:1668': 2, 'tv:999': 0, 'tv:777': 1, 'movie:550': 3, 'movie:551': 0, 'movie:552': 0 };
const tekrarOf = (s) => TEKRAR[`${s.tur}:${s.tmdb_id}`] || 0;

/** SQL'deki `GROUP BY tur, tekrar` + `SURE_OLCU_SECIM` karşılığı. */
function turSatirlari(satirlar) {
  const m = new Map();
  for (const s of satirlar) {
    const t = tekrarOf(s);
    const k = `${s.tur}|${t}`;
    if (!m.has(k)) m.set(k, { tur: s.tur, tekrar: t, adet: 0, gercek_dk: 0, eksik: 0 });
    const r = m.get(k);
    r.adet++;
    if (s.dakika == null) r.eksik++; else r.gercek_dk += s.dakika;
  }
  return [...m.values()];
}

/** SQL'deki `GROUP BY tmdb_id` karşılığı (tek tür). */
function yapimSatirlari(satirlar, tur) {
  const m = new Map();
  for (const s of satirlar.filter((x) => x.tur === tur)) {
    if (!m.has(s.tmdb_id)) {
      m.set(s.tmdb_id, { tmdb_id: s.tmdb_id, tekrar: tekrarOf(s), adet: 0, gercek_dk: 0, eksik: 0 });
    }
    const r = m.get(s.tmdb_id);
    r.adet++;
    if (s.dakika == null) r.eksik++; else r.gercek_dk += s.dakika;
  }
  return [...m.values()];
}

test('DEĞİŞMEZ: toplam = dizi + film', () => {
  const k = izlemeKirilimi(turSatirlari(evren()));
  assert.equal(k.tv + k.movie, k.toplam);
  assert.ok(k.tv > 0 && k.movie > 0, 'test evreni iki türü de içermeli');
});

test('DEĞİŞMEZ: toplam = gerçek + tahmini', () => {
  const k = izlemeKirilimi(turSatirlari(evren()));
  assert.equal(k.gercek + k.tahmini, k.toplam);
  // Karışım GERÇEKTEN karışık olmalı, yoksa test bir şey kanıtlamaz.
  assert.ok(k.gercek > 0 && k.tahmini > 0, 'evren karışık kaynak içermeli');
});

test('DEĞİŞMEZ: dizi toplamı = yapım başına listenin toplamı', () => {
  const satirlar = evren();
  const k = izlemeKirilimi(turSatirlari(satirlar));
  for (const tur of ['tv', 'movie']) {
    const liste = yapimSatirlari(satirlar, tur).reduce(
      (a, r) => a + yapimDakikasi(tur, r.adet, r.tekrar, r.gercek_dk, r.eksik), 0);
    assert.equal(liste, k[tur], `${tur}: alt liste üstteki sayıyı tutmuyor`);
  }
});

// ===========================================================================
// 4) GERÇEK SÜRESİ OLMAYAN YAPIM — davranış
// ===========================================================================
test('süresi HİÇ bilinmeyen yapım sabit yedeğine düşer', () => {
  // 8 bölüm, hiçbirinin süresi yok, tekrar yok → 8 × 42
  assert.equal(yapimDakikasi('tv', 8, 0, 0, 8), 8 * SURE_DK.tv);
  assert.equal(yapimDakikasi('movie', 3, 0, 0, 3), 3 * SURE_DK.movie);
  // Ve TAMAMI "tahmini" tarafında sayılır — ekran "~" koyabilsin.
  const k = izlemeKirilimi([{ tur: 'tv', adet: 8, tekrar: 0, gercek_dk: 0, eksik: 8 }]);
  assert.equal(k.gercek, 0);
  assert.equal(k.tahmini, 8 * SURE_DK.tv);
});

test('KISMEN bilinen yapımda iki parça birlikte sayılır', () => {
  // 40 bölüm: 33'ü 51 dk (=1683), 7'si bilinmiyor (7 × 42 = 294)
  assert.equal(yapimDakikasi('tv', 40, 0, 1683, 7), 1683 + 7 * 42);
});

test('tekrar çarpanı GERÇEK ve TAHMİNİ parçaya AYNI uygulanır', () => {
  // Ayrı uygulansaydı `gercek + tahmini` toplamı tutmazdı.
  const r = { tur: 'tv', adet: 40, tekrar: 2, gercek_dk: 1683, eksik: 7 };
  const k = izlemeKirilimi([r]);
  assert.equal(k.gercek, 1683 * 3);
  assert.equal(k.tahmini, 7 * 42 * 3);
  assert.equal(k.toplam, (1683 + 7 * 42) * 3);
});

test('SÜRE TABLOSU BOŞKEN eski davranış birebir korunur', () => {
  // Migrasyon uygulandı ama betik henüz koşmadıysa uçlar `gercek_dk=0,
  // eksik=adet` görür; ayrıca eski çağıranlar (yıl özeti) hiç ölçü vermez.
  assert.equal(yapimDakikasi('tv', 62, 1), 62 * 42 * 2);
  assert.equal(yapimDakikasi('tv', 62, 1, 0, 62), 62 * 42 * 2);
  assert.equal(izlemeDakikasi([{ tur: 'movie', adet: 10, tekrar: 0 }]), 10 * 110);
});

test('bozuk ölçü toplamı ŞİŞİREMEZ: eksik, adedi aşamaz', () => {
  // `eksik > adet` yalnız bozuk bir sorgudan gelebilir; kırpılmazsa tahmini
  // parça satır sayısından fazla bölüm sayar ve toplam gerçeği geçer.
  assert.equal(yapimDakikasi('tv', 5, 0, 0, 999), 5 * 42);
  assert.equal(yapimDakikasi('tv', 5, 0, -100, 5), 5 * 42);
  assert.equal(yapimDakikasi('tv', -3, -1, 0, 0), 0);
  assert.equal(yapimDakikasi('kitap', 10, 0, 0, 10), 0); // bilinmeyen tür
});

// ===========================================================================
// 5) SOMUT ÖRNEK — Friends: sabit vs gerçek
// ===========================================================================
test('Friends: sabit 42 dk, gerçeğin 1,8 katını gösteriyordu', () => {
  const BOLUM = 236;
  const GERCEK_DK = 23; // TMDB bölüm süresi (ölçülen medyan)
  const sabit = yapimDakikasi('tv', BOLUM, 0);              // eski yol
  const gercek = yapimDakikasi('tv', BOLUM, 0, BOLUM * GERCEK_DK, 0);
  assert.equal(sabit, 9912);   // 165 sa 12 dk
  assert.equal(gercek, 5428);  //  90 sa 28 dk
  assert.equal(sabit - gercek, 4484); // 3 gün 2 saat fazladan sayılıyordu
  assert.ok(sabit / gercek > 1.8);
});

test('Stranger Things: final süresi kullanılsaydı 2,5 kat şişerdi', () => {
  // `last_episode_to_air.runtime` = 129 dk (final), gerçek medyan 50 dk.
  // Bu alanın BİLEREK kullanılmadığını sure_doldur.js belgeliyor.
  const bolum = 42;
  assert.equal(yapimDakikasi('tv', bolum, 0, bolum * 50, 0), 2100);
  assert.equal(yapimDakikasi('tv', bolum, 0, bolum * 129, 0), 5418);
  assert.ok(!/last_episode_to_air/.test(FILM_SQL + SEZON_SQL),
    'geri doldurma final süresine DÜŞMEMELİ');
  assert.ok(!/episode_run_time/.test(FILM_SQL + SEZON_SQL),
    'geri doldurma %22 dolu alana DÜŞMEMELİ');
});

// ===========================================================================
// 6) UÇ SÖZLEŞMELERİ — ekranın dürüst etiket yazabilmesi buna bağlı
// ===========================================================================
test('/istatistiklerim kaynak kırılımını gönderiyor', () => {
  const g = ucGovdesi('/istatistiklerim');
  assert.ok(g.includes('sure_gercek_dk: dakika.gercek'));
  assert.ok(g.includes('sure_tahmini_dk: dakika.tahmini'));
  // Eski anahtar KORUNDU: yeniden adlandırmak eski istemcilerde kartı
  // boşaltırdı.
  assert.ok(g.includes('tahmini_dakika: dakika.toplam'));
  assert.ok(g.includes('sure_bolum_dk: SURE_DK.tv'), 'yedek sabit de gitmeli');
});

test('/istatistiklerim/sure her satırın `eksik` sayısını gönderiyor', () => {
  const g = ucGovdesi('/istatistiklerim/sure');
  assert.ok(/dakika: yapimDakikasi\(tur, r\.adet, r\.tekrar, r\.gercek_dk, r\.eksik\)/.test(g),
    'satır dakikası ölçüyü kullanmıyor');
  assert.ok(/\beksik: r\.eksik\b/.test(g),
    'satır düzeyinde dürüstlük yok — ekran "~"yı satıra göre koyamaz');
  // Sıralama da gerçek dakikaya göre olmalı, ham adede göre değil.
  assert.ok(g.includes('ORDER BY ${SURE_DAKIKA_SQL} DESC'));
});

test('/istatistiklerim/izleme pencere + ömür kaynak kırılımı veriyor', () => {
  const g = ucGovdesi('/istatistiklerim/izleme');
  assert.ok(g.includes('gercek_dk: pencereK.gercek'));
  assert.ok(g.includes('tahmini_dk: pencereK.tahmini'));
  assert.ok(g.includes('tahminiDakikaKirilim(kid)'),
    'ömür boyu sayı profildekiyle aynı fonksiyondan çıkmalı');
});

// ===========================================================================
// 7) GERİ DOLDURMA — saf ayrıştırıcılar
// ===========================================================================
test('filmSuresi: runtime yoksa/0 ise null', () => {
  assert.equal(filmSuresi({ runtime: 139 }), 139);
  assert.equal(filmSuresi({ runtime: 0 }), null);
  assert.equal(filmSuresi({ runtime: null }), null);
  assert.equal(filmSuresi({}), null);
  assert.equal(filmSuresi(null), null);
});

test('sezonSureleri: süresiz bölüm ATLANIR, 0 yazılmaz', () => {
  const veri = { episodes: [
    { episode_number: 1, runtime: 23 },
    { episode_number: 2, runtime: null },  // TMDB'de girilmemiş
    { episode_number: 3, runtime: 0 },     // 0 = bilinmiyor
    { episode_number: 4, runtime: 24 },
  ] };
  assert.deepEqual(sezonSureleri(veri), [
    { bolum: 1, dakika: 23 }, { bolum: 4, dakika: 24 },
  ]);
});

test('sezonSureleri: yinelenen bölüm numarası ELENİR', () => {
  // Aynı INSERT'te yineleme olursa ON CONFLICT DO UPDATE Postgres 21000
  // ("cannot affect row a second time") ile patlar — geri doldurma tamamen
  // durur. Yineleme veritabanına GİTMEDEN eleniyor.
  const veri = { episodes: [
    { episode_number: 5, runtime: 42 },
    { episode_number: 5, runtime: 44 },
  ] };
  assert.deepEqual(sezonSureleri(veri), [{ bolum: 5, dakika: 44 }]);
});

test('sezonSureleri: bozuk belge ÇÖKERTMEZ', () => {
  assert.deepEqual(sezonSureleri(null), []);
  assert.deepEqual(sezonSureleri({ episodes: 'yok' }), []);
  assert.deepEqual(sezonSureleri({ episodes: [{ episode_number: 'x', runtime: 5 }] }), []);
});

test('geri doldurma SQL\'i yalnız izlenmiş yapımları detoast eder', () => {
  // `veri` sütununa DOKUNMADAN süzme sırası: kimsenin izlemediği yapımın
  // 191-342 KB'lik belgesi hiç açılmasın. Sıra ters kurulursa tüm katalog
  // detoast edilir (yerel ölçüm: 83 MB).
  for (const sql of [FILM_SQL, SEZON_SQL]) {
    assert.ok(sql.includes('FROM izlemeler'), 'hedef kümesi izlemeler olmalı');
    const hedefIndeks = sql.indexOf('JOIN hedef');
    const veriIndeks = sql.indexOf("veri->>'");
    assert.ok(hedefIndeks > 0 && (veriIndeks < 0 || hedefIndeks < veriIndeks),
      'jsonb süzgeci hedef birleşiminden ÖNCE geliyor — tüm katalog açılır');
  }
  // Alt yollar (`/movie/1/credits`) kimlik desenine TAKILMAMALI.
  assert.ok(FILM_SQL.includes("'^/movie/[0-9]+\\?'"));
  assert.ok(SEZON_SQL.includes("'^/tv/[0-9]+/season/[0-9]+\\?'"));
});

test('eksik listeleri BÖLÜM değil SEZON düzeyinde soruyor', () => {
  // TMDB süreyi sezon belgesinde veriyor; bölüm bölüm istemek aynı belgeyi
  // onlarca kez indirmek olurdu.
  assert.ok(EKSIK_SEZON_SQL.includes('DISTINCT i.tmdb_id, i.sezon'));
  assert.ok(EKSIK_FILM_SQL.includes('DISTINCT i.tmdb_id'));
  assert.ok(KAPSAM_SQL.includes('count(s.dakika)'), 'kapsam raporu satır sayar');
});

test('SONSUZ YENİDEN İNDİRME YOK: taze sezon 30 gün susturulur', () => {
  // Kapsam asla %100 olmaz, yani "eksik bölümü olan sezon" listesi HİÇ
  // boşalmaz. Susturma olmasaydı cron her koşuda aynı ~750 sezon belgesini
  // yeniden indirirdi. (Yerel ölçüm: susturma açıkken 750 → 0.)
  assert.equal(TAZE_GUN, 30);
  assert.ok(
    EKSIK_SEZON_SQL.includes(`interval '${TAZE_GUN} days'`),
    'sezon susturması yok — cron aynı belgeleri sonsuza dek indirir');
  // Susturma SEZON düzeyinde (bolum koşulu YOK): o sezonu yakın zamanda
  // sorduysak, kalan boşluk TMDB'nin eksiği, bizim değil.
  const parca = EKSIK_SEZON_SQL.slice(EKSIK_SEZON_SQL.lastIndexOf('NOT EXISTS'));
  assert.ok(parca.includes('guncelleme >'), 'susturma son blokta olmalı');
  assert.ok(!parca.includes('s.bolum = i.bolum'),
    'susturma bölüm düzeyine inerse hiçbir şeyi susturmaz');
});

test('geri doldurma tmdb_onbellek\'e YAZMAZ', () => {
  // Orası `tmdbGetir` ve `isitici.js`in ortak aynası: TTL'i, dil anahtarını
  // ve 404 işaretini onlar yönetiyor.
  const betik = fs.readFileSync(path.join(KOK, 'sure_doldur.js'), 'utf8');
  assert.ok(!/INSERT INTO tmdb_onbellek/i.test(betik));
  assert.ok(!/UPDATE tmdb_onbellek/i.test(betik));
  assert.ok(!/DELETE FROM tmdb_onbellek/i.test(betik));
});
