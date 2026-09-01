// LETTERBOXD İÇE AKTARIMI (1 Eyl 2026).
//
// Letterboxd dışa aktarımı TMDB kimliği TAŞIMAZ (Ad+Yıl+Letterboxd URI verir)
// ve kendi dosya adları (ratings.csv, reviews.csv) hem bizim dışa aktarımımız
// hem TV Time ile ÇAKIŞIR. Bu test gerçek bir ZIP kurup `iceAktar`ı sahte
// havuzla uçtan uca çalıştırır: algılama başlıktan mı yapılıyor, silinmiş/
// beğeni kopyaları eleniyor mu, tarih güvenilirliği doğru mu, puan ölçeği
// (0,5-5 yıldız → 1-100) doğru taşınıyor mu?
import test from 'node:test';
import assert from 'node:assert/strict';
import JSZip from 'jszip';

import { iceAktar } from '../veri_aktar.js';

// ---- sahte havuz: tüm sorguları kaydeder, makul yanıtlar döner ----
function sahteHavuz() {
  const sorgular = [];
  return {
    sorgular,
    async query(metin, parametreler) {
      sorgular.push({ metin, parametreler });
      if (/^\s*SELECT 1 FROM yorumlar/.test(metin)) return { rows: [], rowCount: 0 };
      if (/^\s*SELECT/.test(metin)) return { rows: [], rowCount: 0 };
      // INSERT/UPDATE: kaç satır yazıldıysa o kadar say (VALUES öbeği başına 1)
      const values = metin.match(/\(\$1,'movie'/g);
      return { rows: [], rowCount: values ? values.length : 1 };
    },
  };
}

// Adı bilinen filmler için sahte TMDB araması. Yıl da doğrulanır:
// isimdenTmdbFilm imzası (isim, yil) — yıl iletilmiyorsa eşleme zayıflar.
const TMDB = {
  'Iron Man|2008': 1726,
  'The Blair Witch Project|1999': 2667,
  'Blair Witch|2016': 351211,
  'Bird Box|2018': 405774,
  'Until Dawn|2025': 1232546,
};
async function sahteAraFilm(isim, yil) {
  return TMDB[`${isim}|${yil ?? ''}`] || null;
}

async function lbZip(ekstra = {}) {
  const zip = new JSZip();
  zip.file('profile.csv',
    'Date Joined,Username,Given Name,Family Name,Email Address,Location,Website,Bio,Pronoun,Favorite Films\n'
    + '2026-08-14,alcelikk,,,,,,,They / their,\n');
  zip.file('watched.csv',
    'Date,Name,Year,Letterboxd URI\n'
    + '2026-09-01,Iron Man,2008,https://boxd.it/28dA\n'
    + '2026-09-01,The Blair Witch Project,1999,https://boxd.it/26ua\n'
    + '2026-09-01,Bilinmeyen Film,2020,https://boxd.it/xxxx\n');
  zip.file('diary.csv',
    'Date,Name,Year,Letterboxd URI,Rating,Rewatch,Tags,Watched Date\n'
    + '2026-09-01,Iron Man,2008,https://boxd.it/28dA,4.5,No,,2019-03-04\n');
  zip.file('ratings.csv',
    'Date,Name,Year,Letterboxd URI,Rating\n'
    + '2026-09-01,Iron Man,2008,https://boxd.it/28dA,4.5\n'
    + '2026-09-01,The Blair Witch Project,1999,https://boxd.it/26ua,3.5\n');
  zip.file('reviews.csv',
    'Date,Name,Year,Letterboxd URI,Rating,Rewatch,Review,Tags,Watched Date\n'
    + '2026-09-01,The Blair Witch Project,1999,https://boxd.it/26ua,3.5,No,"Ormanda, gece.",,2020-05-05\n'
    + '2026-09-01,Bird Box,2018,https://boxd.it/eh1i,,No,Puansız inceleme.,,\n');
  zip.file('watchlist.csv',
    'Date,Name,Year,Letterboxd URI\n'
    + '2026-09-01,Until Dawn,2025,https://boxd.it/KOb0\n');
  zip.file('likes/films.csv',
    'Date,Name,Year,Letterboxd URI\n'
    + '2026-09-01,Blair Witch,2016,https://boxd.it/bO28\n');
  // Elenmesi gerekenler: silinmiş günlük + başkalarının beğenilen incelemeleri.
  zip.file('deleted/diary.csv',
    'Date,Name,Year,Letterboxd URI,Rating,Rewatch,Tags,Watched Date\n'
    + '2026-09-01,Bird Box,2018,https://boxd.it/eh1i,1,No,,2011-01-01\n');
  zip.file('likes/reviews.csv', 'Date,Rating\n2026-09-01,5\n');
  zip.file('comments.csv', 'Date,Content,Comment\n');
  for (const [ad, icerik] of Object.entries(ekstra)) zip.file(ad, icerik);
  return zip.generateAsync({ type: 'nodebuffer' });
}

test('Letterboxd ZIP başlıktan algılanır ve uçtan uca aktarılır', async () => {
  const havuz = sahteHavuz();
  const ozet = await iceAktar(havuz, 7, await lbZip(), null, null, null, sahteAraFilm);

  // İzlenen 4 film (Iron Man, Blair Witch Project, Bird Box, Bilinmeyen);
  // Bilinmeyen eşleşmez → 3 izleme + 1 atlanan.
  assert.equal(ozet.izleme, 3, JSON.stringify(ozet));
  assert.ok(ozet.atlanan >= 1, 'eşleşmeyen film atlanan sayılmadı');
  assert.equal(ozet.puan, 2, 'Iron Man 4,5★ + Blair Witch 3,5★');
  assert.equal(ozet.yorum, 1, 'puansız inceleme yorum olarak taşınmalı');
  assert.equal(ozet.favori, 1);
  assert.equal(ozet.profil, 0, 'boş bio profil yazdırmamalı');
  assert.ok(ozet.durum >= 1, 'izleme listesi durum üretmedi');

  const izleme = havuz.sorgular.find((s) => /INSERT INTO izlemeler/.test(s.metin));
  assert.ok(izleme, 'izleme INSERT edilmedi');
  // Iron Man: diary'deki Watched Date (2019) kesin tarihtir; watched.csv'nin
  // toplu işaretleme günü (2026-09-01) onu EZMEMELİ.
  const p = izleme.parametreler;
  const ironIx = p.indexOf(1726);
  assert.ok(ironIx > 0);
  assert.equal(p[ironIx + 1].toISOString().slice(0, 10), '2019-03-04');
  assert.equal(p[ironIx + 2], true, 'diary tarihi kesin sayılmalı');
  // Blair Witch Project: reviews Watched Date (2020-05-05) kesin.
  const bwIx = p.indexOf(2667);
  assert.equal(p[bwIx + 1].toISOString().slice(0, 10), '2020-05-05');
  assert.equal(p[bwIx + 2], true);
  // Bird Box: yalnız işaretleme günü var → tarih_kesin=false.
  // (deleted/diary.csv'deki 2011 tarihi OKUNMAMALI.)
  const bbIx = p.indexOf(405774);
  assert.equal(p[bbIx + 2], false, 'işaretleme günü kesin sayılmamalı');
  assert.notEqual(String(p[bbIx + 1] || ''),
    '2011-01-01', 'silinmiş günlük satırı okunmuş');

  // Puan ölçeği: 4,5★ → 90; inceleme puan satırına yorum olarak bağlanır.
  const puan = havuz.sorgular.find((s) => /INSERT INTO puanlar/.test(s.metin)
    && s.parametreler.includes(1726));
  assert.equal(puan.parametreler[2], 90);
  const bwPuan = havuz.sorgular.find((s) => /INSERT INTO puanlar/.test(s.metin)
    && s.parametreler.includes(2667));
  assert.equal(bwPuan.parametreler[2], 70);
  assert.equal(bwPuan.parametreler[3], 'Ormanda, gece.');

  // İzleme listesi: Until Dawn 'izleyecegim' olur (izlenmemiş).
  const durum = havuz.sorgular.find((s) => /INSERT INTO durumlar/.test(s.metin)
    && s.parametreler?.includes(1232546));
  assert.ok(durum, 'watchlist filmi durum almadı');
  assert.match(durum.metin, /'izleyecegim'/);

  // Beğeni: likes/films.csv → favoriler; likes/reviews.csv OKUNMAZ.
  const favori = havuz.sorgular.find((s) => /INSERT INTO favoriler/.test(s.metin));
  assert.equal(favori.parametreler[1], 351211);

  // Çelişki çözümü her yolda koşar.
  assert.ok(havuz.sorgular.some((s) => /UPDATE durumlar d/.test(s.metin)),
    'izleyeceğim çelişkisi çözülmedi');
});

test('kendi ratings.csv dosyamız Letterboxd SANILMAZ (başlık farklı)', async () => {
  const zip = new JSZip();
  zip.file('ratings.csv',
    'user_id,type,tmdb_id,season_number,episode_number,rating,review,created_at\n'
    + '7,movie,550,,,80,,2020-01-01\n');
  const havuz = sahteHavuz();
  const ozet = await iceAktar(havuz, 7, await zip.generateAsync({ type: 'nodebuffer' }),
    null, null, null, sahteAraFilm);
  // Letterboxd yolu koşmamalı: isim eşleme sayacı hiç kurulmaz.
  assert.equal(ozet.izleme, 0);
  assert.ok(!havuz.sorgular.some((s) => /INSERT INTO izlemeler/.test(s.metin)));
});

test('profile.csv dolu bio taşır, mevcut bio ezilmez (COALESCE)', async () => {
  const havuz = sahteHavuz();
  await iceAktar(havuz, 7, await lbZip({
    'profile.csv':
      'Date Joined,Username,Given Name,Family Name,Email Address,Location,Website,Bio,Pronoun,Favorite Films\n'
      + '2026-08-14,alcelikk,,,,,,Film günlüğü tutarım.,,\n',
  }), null, null, null, sahteAraFilm);
  const bio = havuz.sorgular.find((s) => /UPDATE kullanicilar SET bio/.test(s.metin));
  assert.ok(bio, 'bio yazılmadı');
  assert.match(bio.metin, /COALESCE/);
  assert.equal(bio.parametreler[0], 'Film günlüğü tutarım.');
});
