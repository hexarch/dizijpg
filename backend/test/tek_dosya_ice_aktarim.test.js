// TEK DOSYA (CSV/JSON) İÇE AKTARIMI — 13 Eyl 2026.
//
// Eskiden yalnız ZIP kabul ediliyordu; oysa TV Time'ın 2026 dışa aktarımı TEK
// bir `tv-time-export.csv`, kendi yedeğimiz de TEK bir `dizijpg.json`.
// Kullanıcı bunları yükleyebilmek için önce ELİYLE zip'lemek zorundaydı.
//
// Bu test, arşivin verdiği iki bağlam (klasör yolu ve kardeş dosyalar) yokken
// biçim kararının hâlâ doğru verildiğini kilitler. Kritik nokta: karar DOSYA
// ADINA EMANET EDİLEMEZ — `ratings.csv` adını hem Letterboxd hem kendi dışa
// aktarımımız kullanıyor. Ad yalnızca başlık tek başına yetmediğinde konuşur
// (watched.csv ile watchlist.csv'nin başlıkları BİREBİR AYNI).
import test from 'node:test';
import assert from 'node:assert/strict';

import { iceAktarTekDosya, tekDosyaTuru } from '../veri_aktar.js';

function sahteHavuz() {
  const sorgular = [];
  return {
    sorgular,
    async query(metin, parametreler) {
      sorgular.push({ metin, parametreler });
      if (/^\s*SELECT/.test(metin)) return { rows: [{ n: 0 }], rowCount: 0 };
      return { rows: [], rowCount: 1 };
    },
  };
}

const TMDB_FILM = { 'Iron Man|2008': 1726, 'Bird Box|2018': 405774, 'Iron Man|': 1726 };
const araFilm = async (isim, yil) => TMDB_FILM[`${isim}|${yil ?? ''}`] || null;
const araTv = async (isim) => (isim === 'Severance' ? 95396 : null);

const tampon = (s) => Buffer.from(s, 'utf8');

// ---------------------------------------------------------------------------
// BİÇİM TANIMA
// ---------------------------------------------------------------------------
test('Letterboxd ile kendi ratings.csv dosyamız BAŞLIKTAN ayrılır', () => {
  const lb = 'Date,Name,Year,Letterboxd URI,Rating\n2026-09-01,Iron Man,2008,https://boxd.it/28dA,4.5\n';
  const bizim = 'user_id,type,tmdb_id,season_number,episode_number,rating,review,created_at\n'
    + '7,movie,1726,,,90,,2026-09-01T00:00:00.000Z\n';
  // İKİSİNİN DE ADI ratings.csv — ad aynıyken başlık karar veriyor.
  assert.deepEqual(tekDosyaTuru('ratings.csv', lb), { lbAd: 'ratings.csv' });
  assert.deepEqual(tekDosyaTuru('ratings.csv', bizim), { ad: 'ratings.csv' });
});

test('watched.csv ile watchlist.csv YALNIZCA addan ayrılabilir', () => {
  const govde = 'Date,Name,Year,Letterboxd URI\n2026-09-01,Iron Man,2008,https://boxd.it/28dA\n';
  assert.deepEqual(tekDosyaTuru('watched.csv', govde), { lbAd: 'watched.csv' });
  assert.deepEqual(tekDosyaTuru('watchlist.csv', govde), { lbAd: 'watchlist.csv' });
  // Ad yoksa ayırt edilemez: izleme kaydı yazmak, izlenmiş filmi
  // "izleyeceğim"e atmaktan daha az yanıltıcı.
  assert.deepEqual(tekDosyaTuru('', govde), { lbAd: 'watched.csv' });
});

test('ad tanınmazsa başlık imzası devreye girer', () => {
  const esler = [
    ['type,media_type,tmdb_id,imdb_id,tvdb_id,title,year,season,episode,watched_at,rating,review\n',
      'tv-time-export.csv'],
    ['user_id,tv_show_id,episode_season_number,episode_number,created_at\n',
      'seen_episode_latest.csv'],
    ['user_id,movie_id,created_at\n', 'seen_movie.csv'],
    ['user_id,tv_show_id,tv_show_name,active,archived,created_at\n', 'followed_tv_show.csv'],
    ['user_id,type,tmdb_id,season_number,episode_number,comment,created_at\n', 'comments.csv'],
    ['list_name,is_public,type,tmdb_id,created_at\n', 'lists.csv'],
    ['series_name,season_number,episode_number,watched_at\n', 'tracking-prod-records-v2.csv'],
  ];
  for (const [basliklar, beklenen] of esler) {
    assert.deepEqual(tekDosyaTuru('disaaktarim.csv', basliklar), { ad: beklenen }, basliklar);
  }
});

test('dizijpg.json hem addan hem gövdeden tanınır', () => {
  assert.deepEqual(tekDosyaTuru('dizijpg.json', '{"surum":2}'), { native: true });
  assert.deepEqual(tekDosyaTuru('yedek (1).json', '{"surum":2}'), { native: true });
  assert.deepEqual(tekDosyaTuru('', '  {"surum":2}'), { native: true });
});

test('tanınmayan CSV null döner (sessizce "0 kayıt" DEĞİL)', () => {
  assert.equal(tekDosyaTuru('bakiye.csv', 'tarih,tutar,aciklama\n2026-01-01,100,x\n'), null);
});

// ---------------------------------------------------------------------------
// UÇTAN UCA
// ---------------------------------------------------------------------------
test('tek tv-time-export.csv zip olmadan aktarılır', async () => {
  const havuz = sahteHavuz();
  const csv = 'type,media_type,tmdb_id,imdb_id,tvdb_id,title,year,season,episode,watched_at,rating,review\n'
    + 'watch,episode,,,,Severance,2022,1,1,2023-04-05T00:00:00Z,,\n'
    + 'watch,movie,1726,,,Iron Man,2008,,,2019-03-04T00:00:00Z,,\n';
  const ozet = await iceAktarTekDosya(
    havuz, 7, tampon(csv), 'tv-time-export (1).csv', null, araTv, null, araFilm);

  assert.ok(ozet.izleme >= 2, JSON.stringify(ozet));
  const izlemeler = havuz.sorgular.filter((s) => /INSERT INTO izlemeler/.test(s.metin));
  assert.ok(izlemeler.length >= 2, 'izleme yazılmadı');
  // TARİH DÜŞMEMELİ: 27 Ağu dersi ("2019'da izledim" → içe aktarım günü).
  const film = izlemeler.find((s) => s.parametreler.includes(1726));
  assert.equal(String(film.parametreler[2]), '2019-03-04T00:00:00Z');
});

test('tek dizijpg.json (kendi yedeğimiz) zip olmadan geri yüklenir', async () => {
  const havuz = sahteHavuz();
  const json = JSON.stringify({
    surum: 2, puan_olcegi: 100,
    durumlar: [{ tur: 'movie', tmdb_id: 1726, durum: 'bitirdim' }],
    favoriler: [{ tur: 'movie', tmdb_id: 1726 }],
  });
  const ozet = await iceAktarTekDosya(havuz, 7, tampon(json), 'dizijpg.json');
  // (durum >= 1: `filmDurumlariniEsitle` izleme kaydından da durum türetir.)
  assert.ok(ozet.durum >= 1, JSON.stringify(ozet));
  assert.ok(havuz.sorgular.some((s) => /INSERT INTO favoriler/.test(s.metin)));
});

test('tek Letterboxd watchlist.csv izleyeceğim durumu yazar', async () => {
  const havuz = sahteHavuz();
  const csv = 'Date,Name,Year,Letterboxd URI\n2026-09-01,Bird Box,2018,https://boxd.it/eh1i\n';
  await iceAktarTekDosya(havuz, 7, tampon(csv), 'watchlist.csv', null, null, null, araFilm);
  const durum = havuz.sorgular.find((s) => /INSERT INTO durumlar/.test(s.metin)
    && s.parametreler?.includes(405774));
  assert.ok(durum, 'watchlist filmi durum almadı');
  assert.match(durum.metin, /'izleyecegim'/);
});

test('BOM ilk sütun adını bozmaz', async () => {
  const havuz = sahteHavuz();
  const csv = '﻿Date,Name,Year,Letterboxd URI\n2026-09-01,Iron Man,2008,https://boxd.it/28dA\n';
  const ozet = await iceAktarTekDosya(havuz, 7, tampon(csv), 'watched.csv', null, null, null, araFilm);
  assert.equal(ozet.izleme, 1, JSON.stringify(ozet));
});

test('boş ve tanınmayan dosya 400 verir', async () => {
  const havuz = sahteHavuz();
  await assert.rejects(
    () => iceAktarTekDosya(havuz, 7, tampon('   '), 'bos.csv'),
    (e) => e.status === 400);
  await assert.rejects(
    () => iceAktarTekDosya(havuz, 7, tampon('a,b\n1,2\n'), 'bakiye.csv'),
    (e) => e.status === 400 && /tanınmadı/.test(e.message));
});

test('tek başına hiçbir şey aktarmayan dosya SEBEBİYLE reddedilir', async () => {
  // Ölçüldü: bu dosyalar okuyucu tarafından hiç okunmuyor, tek başlarına
  // yüklenirse kullanıcı sessizce "0 kayıt" görürdü.
  const havuz = sahteHavuz();
  const ornekler = {
    'seen_movie.csv': 'user_id,movie_id,created_at\n7,555,2023-04-05\n',
    'lists.csv': 'list_name,is_public,type,tmdb_id,created_at\nFavorilerim,,movie,1726,2026-01-01\n',
    'ratings.csv': 'user_id,type,tmdb_id,season_number,episode_number,rating,review,created_at\n'
      + '7,movie,1726,,,90,,2026-01-01\n',
    // Kendi comments.csv'miz: tmdb_id TheTVDB sanılıp YANLIŞ diziye yazılırdı.
    'comments.csv': 'user_id,type,tmdb_id,season_number,episode_number,comment,created_at\n'
      + '7,tv,95396,1,1,güzel,2026-01-01\n',
  };
  for (const [ad, icerik] of Object.entries(ornekler)) {
    await assert.rejects(
      () => iceAktarTekDosya(havuz, 7, tampon(icerik), ad, null, null, null, null),
      (e) => e.status === 400 && /tek başına aktarılamıyor/.test(e.message), ad);
  }
  assert.equal(havuz.sorgular.length, 0, 'reddedilen dosya için DB yazması olmamalı');
});

// ---------------------------------------------------------------------------
// KABLOLAMA — `server.js` içe aktarılamıyor (yüklenir yüklenmez `app.listen`
// çağırıyor), bu yüzden uç noktanın sözleşmesi KAYNAKTAN denetlenir. Buradaki
// dört satırdan biri düşerse özellik sessizce ölür: dosya uca ya hiç ulaşmaz
// ya da yanlış yoldan girer.
// ---------------------------------------------------------------------------
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SUNUCU = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');

test('gövde içerik tipine bakılmadan ham okunur', () => {
  // Tip listesi tutulsaydı tarayıcının .csv'ye taktığı beklenmedik bir tip
  // (Windows'ta sık: application/vnd.ms-excel) gövdeyi ayrıştırılmadan
  // geçirir, uç da "Dosya verisi gerekli" derdi.
  const uc = SUNUCU.slice(SUNUCU.indexOf("app.post('/veri/ice-aktar'"));
  assert.match(uc.slice(0, 600), /express\.raw\(\{ type: \(\) => true, limit: '50mb' \}\)/);
});

test('genel express.json ayrıştırıcısı bu ucu ATLAR', () => {
  // Atlamazsa: 1 MB üstü dizijpg.json 413 alır, altındaki nesneye dönüşüp
  // `express.raw`ı atlatır ve uç "Dosya verisi gerekli" der.
  assert.match(SUNUCU, /req\.path !== '\/veri\/ice-aktar'/);
});

test('biçim İÇERİKTEN anlaşılır: PK → ZIP, değilse tek dosya', () => {
  assert.match(SUNUCU, /const zipMi = req\.body\[0\] === 0x50 && req\.body\[1\] === 0x4b/);
  assert.match(SUNUCU, /iceAktarTekDosya\(\s*\n?\s*havuz, req\.kullanici\.id, req\.body/);
});

test('ikili dosya metin sanılmaz: NUL baytı reddedilir', () => {
  assert.match(SUNUCU, /req\.body\.subarray\(0, 8192\)\.includes\(0x00\)/);
});

test('X-Dosya-Adi CORS başlıklarında izinli', () => {
  assert.match(SUNUCU, /Access-Control-Allow-Headers'[^\n]*X-Dosya-Adi/);
});
