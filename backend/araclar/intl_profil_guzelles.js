#!/usr/bin/env node
/**
 * Tohum profillerini görsel olarak doldurur: 2.4:1 kapak, film şeridi,
 * liste öğesi, favori kişi (TMDB aramasıyla id). alcelik yok. Bildirim yok.
 *
 *   docker cp araclar/intl_profil_guzelles.js dizijpg-api:/app/
 *   docker exec -w /app dizijpg-api node intl_profil_guzelles.js
 */
import fs from 'fs';
import path from 'path';
import { spawn } from 'child_process';
import pg from 'pg';

const { DATABASE_URL, TMDB_TOKEN, AVATAR_DIZIN } = process.env;
if (!DATABASE_URL || !TMDB_TOKEN) {
  console.error('DATABASE_URL / TMDB_TOKEN gerekli');
  process.exit(1);
}

const ALCELIK = 3;
const YANLIS_FILM = [
  ['camille.ecran', 63193],
  ['daria.serial', 565085],
  ['zara.dramay', 426256],
];
const avatarDizin = AVATAR_DIZIN || '/veri/avatarlar';
const args = process.argv.slice(2);
const sadeceKapak = args.includes('--kapak');
const sadeceFilm = args.includes('--film');
const filtre = new Set(args.filter((a) => !a.startsWith('--')));
const { Pool } = pg;
const havuz = new Pool({ connectionString: DATABASE_URL });

/** Kapak: hesaptaki doğru yapım. path varsa o kare (yazısız, banner'a uygun). */
const KAPAK = {
  'yuki.dorama': { tur: 'movie', tmdb_id: 129 },
  'miles.watches': { tur: 'tv', tmdb_id: 1396 },
  'jiwon.drama': { tur: 'tv', tmdb_id: 128883, path: '/34w8KFW838QUwZaLmcC3HLY75bp.jpg' },
  'lin.binge': { tur: 'movie', tmdb_id: 843 },
  'aanya.screens': { tur: 'movie', tmdb_id: 19404 },
  'lucia.series': { tur: 'movie', tmdb_id: 219, path: '/6hA8eN37Ky8C6X6uJwKsBNTuj4t.jpg' },
  'camille.ecran': { tur: 'movie', tmdb_id: 194, path: '/9Y9K6LeLrMeofOvX7hZW36Aj3OG.jpg' },
  'lena.serie': { tur: 'tv', tmdb_id: 70523 },
  'sofia.seriesbr': { tur: 'movie', tmdb_id: 666, path: '/lrLIy9OFRQg4VkhrCyolfNXJEUH.jpg' },
  'nour.yushahid': { tur: 'tv', tmdb_id: 106590 },
  'rafi.screen': { tur: 'movie', tmdb_id: 5801, path: '/ibJuTdFmYGOiiUzJ5HzHU4EAuf1.jpg' },
  'daria.serial': { tur: 'movie', tmdb_id: 265180 },
  'zara.dramay': { tur: 'movie', tmdb_id: 962571 },
  'dimas.nonton': { tur: 'movie', tmdb_id: 94329 },
  'minh.phim': { tur: 'movie', tmdb_id: 19552 },
};

/** Şeridi dolduracak filmler — yıl ile aranır, id ezbere yazılmaz. */
const FILM_ARA = {
  'miles.watches': [
    ['Fight Club', 1999], ['Pulp Fiction', 1994], ['The Shawshank Redemption', 1994],
    ['The Godfather', 1972], ['The Dark Knight', 2008], ['Se7en', 1995],
    ['Goodfellas', 1990], ['No Country for Old Men', 2007],
    ['Taxi Driver', 1976], ['The Conversation', 1974],
  ],
  'lin.binge': [
    ['Chungking Express', 1994], ['Raise the Red Lantern', 1991], ['To Live', 1994],
    ['A City of Sadness', 1989], ['Farewell My Concubine', 1993], ['Hero', 2002],
    ['Spring in a Small Town', 1948],
  ],
  'aanya.screens': [
    ['Sholay', 1975], ['Dil Chahta Hai', 2001], ['Rang De Basanti', 2006],
    ['Andaz Apna Apna', 1994], ['Black Friday', 2004], ['Guide', 1965],
  ],
  'lucia.series': [
    ['Pan\'s Labyrinth', 2006], ['All About My Mother', 1999],
    ['The Spirit of the Beehive', 1973], ['Open Your Eyes', 1997],
    ['The Skin I Live In', 2011], ['Women on the Verge of a Nervous Breakdown', 1988],
  ],
  'camille.ecran': [
    ['The 400 Blows', 1959], ['La Haine', 1995], ['The Intouchables', 2011],
    ['Cléo from 5 to 7', 1962], ['Portrait of a Lady on Fire', 2019],
    ['Entre les murs', 2008], ['Breathless', 1960], ['The Umbrellas of Cherbourg', 1964],
  ],
  'lena.serie': [
    ['Das Boot', 1981], ['Good Bye Lenin!', 2003], ['Wings of Desire', 1987],
    ['Run Lola Run', 1998], ['The Lives of Others', 2006], ['Toni Erdmann', 2016],
    ['Phoenix', 2014], ['Never Look Away', 2018],
  ],
  'sofia.seriesbr': [
    ['Elite Squad', 2007], ['Neighboring Sounds', 2012], ['Aquarius', 2016],
    ['Bacurau', 2019], ['Central Station', 1998], ['City of God', 2002],
  ],
  'nour.yushahid': [
    ['The Yacoubian Building', 2006], ['The Insult', 2017], ['Clash', 2016],
    ['Sheikh Jackson', 2017], ['The Nile Hilton Incident', 2017],
    ['Cairo Station', 1958], ['The Night of Counting the Years', 1969],
  ],
  'rafi.screen': [
    ['Pather Panchali', 1955], ['The Clay Bird', 2002], ['Monpura', 2009],
    ['Television', 2012], ['Made in Bangladesh', 2019],
  ],
  'daria.serial': [
    ['Andrei Rublev', 1966], ['Zerkalo', 1975], ['Russian Ark', 2002],
    ['Cargo 200', 2007], ['Leviathan', 2014], ['Stalker', 1979],
  ],
  'zara.dramay': [
    ['Bol', 2011], ['Cake', 2018, 'ur'], ['Khuda Kay Liye', 2007],
    ['Superstar', 2019], ['The Legend of Maula Jatt', 2022],
  ],
  'dimas.nonton': [
    ['The Raid', 2011], ['The Raid 2', 2014], ['Marlina the Murderer in Four Acts', 2017],
    ['Impetigore', 2019], ['Vengeance Is Mine, All Others Pay Cash', 2021],
  ],
  'minh.phim': [
    ['The Scent of Green Papaya', 1993], ['Cyclo', 1995], ['The Third Wife', 2018],
    ['Song Lang', 2018], ['Furie', 2019], ['The Vertical Ray of the Sun', 2000],
  ],
  'yuki.dorama': [
    ['Howl\'s Moving Castle', 2004], ['Akira', 1988], ['Castle in the Sky', 1986],
    ['Perfect Blue', 1997], ['Millennium Actress', 2001], ['Princess Mononoke', 1997],
  ],
  'jiwon.drama': [
    ['Memories of Murder', 2003], ['Burning', 2018], ['The Handmaiden', 2016],
    ['Decision to Leave', 2022], ['Oldboy', 2003], ['Parasite', 2019],
    ['Little Forest', 2018], ['Train to Busan', 2016], ['The Wailing', 2016],
    ['A Taxi Driver', 2017], ['Joint Security Area', 2000], ['Poetry', 2010],
  ],
};

const KISI_ARA = {
  'miles.watches': ['Bryan Cranston', 'James Gandolfini', 'Idris Elba'],
  'lin.binge': ['Maggie Cheung', 'Tony Leung Chiu-wai', 'Leslie Cheung'],
  'aanya.screens': ['Kajol', 'Shah Rukh Khan', 'Irrfan Khan'],
  'lucia.series': ['Penélope Cruz', 'Pedro Almodóvar', 'Javier Bardem'],
  'camille.ecran': ['Audrey Tautou', 'Juliette Binoche', 'Jean-Pierre Jeunet'],
  'lena.serie': ['Martina Gedeck', 'Nina Hoss', 'Ulrich Mühe'],
  'sofia.seriesbr': ['Fernanda Montenegro', 'Wagner Moura', 'Sônia Braga'],
  'nour.yushahid': ['Razane Jammal', 'Faten Hamama', 'Amr Waked'],
  'rafi.screen': ['Satyajit Ray', 'Shefali Shah', 'Ritwik Ghatak'],
  'daria.serial': ['Elena Lyadova', 'Aleksei Balabanov', 'Andrey Zvyagintsev'],
  'zara.dramay': ['Alina Khan', 'Mahira Khan', 'Fawad Khan'],
  'dimas.nonton': ['Iko Uwais', 'Joe Taslim', 'Timo Tjahjanto'],
  'minh.phim': ['Ngô Thanh Vân', 'Tran Anh Hung', 'Lê Khanh'],
  'yuki.dorama': ['Hayao Miyazaki', 'Hideaki Anno', 'Satoshi Kon'],
  'jiwon.drama': ['Song Kang-ho', 'Park Chan-wook', 'Park Eun-bin'],
};

async function tmdb(yol) {
  for (let d = 0; d < 4; d++) {
    const c = await fetch(`https://api.themoviedb.org/3${yol}`, {
      headers: { Authorization: `Bearer ${TMDB_TOKEN}` },
    });
    if (c.status === 429) {
      await new Promise((r) => setTimeout(r, 1500 * (d + 1)));
      continue;
    }
    if (c.status === 404) return null;
    if (!c.ok) throw new Error(`TMDB ${c.status} ${yol}`);
    return c.json();
  }
  throw new Error(`TMDB 429 ${yol}`);
}

async function araFilm(ad, yil, dil) {
  const j = await tmdb(
    `/search/movie?query=${encodeURIComponent(ad)}&year=${yil}`);
  const liste = j?.results || [];
  const yilUyan = (r) => {
    const y = parseInt(String(r.release_date || '').slice(0, 4), 10);
    return y && Math.abs(y - yil) <= 1;
  };
  if (dil) {
    const d = liste.find((r) => r.original_language === dil && yilUyan(r));
    if (d) return d;
  }
  return liste.find(yilUyan) || liste[0] || null;
}

async function araKisi(ad) {
  const j = await tmdb(`/search/person?query=${encodeURIComponent(ad)}`);
  const liste = (j?.results || []).filter((r) => r.profile_path);
  return liste[0] || null;
}

async function indir(url, hedef) {
  const c = await fetch(url);
  if (!c.ok) throw new Error(`indirme ${c.status}`);
  fs.writeFileSync(hedef, Buffer.from(await c.arrayBuffer()));
}

function kirpKapak(giris, cikis) {
  return new Promise((ok, no) => {
    const ff = spawn('ffmpeg', [
      '-y', '-i', giris,
      '-vf',
      "crop=iw:'min(ih,iw/2.4)':0:'(ih-min(ih,iw/2.4))*0.28',scale=1920:800",
      '-q:v', '3',
      cikis,
    ], { stdio: ['ignore', 'ignore', 'pipe'] });
    let err = '';
    ff.stderr.on('data', (b) => { err += b; });
    ff.on('close', (kod) => {
      if (kod === 0) ok();
      else no(new Error(`ffmpeg ${kod} ${err.slice(-180)}`));
    });
  });
}

function kapakAday(backdrops) {
  const yazisiz = backdrops.filter((x) => !x.iso_639_1);
  const havuz = (yazisiz.length ? yazisiz : backdrops).slice();
  havuz.sort((a, b) => {
    const puan = (x) => (x.vote_count || 0) * ((x.aspect_ratio || 0) >= 2 ? 1.35 : 1);
    return puan(b) - puan(a);
  });
  return havuz[0] || null;
}

async function kapakYaz(kid, tur, tmdbId, sabitYol) {
  let filePath = sabitYol || null;
  if (!filePath) {
    const veri = await tmdb(`/${tur}/${tmdbId}/images`);
    const b = kapakAday(veri?.backdrops || []);
    filePath = b?.file_path || null;
  }
  if (!filePath) return null;
  const ham = path.join(avatarDizin, `tmp-kapak-${kid}.jpg`);
  const dosya = `kapak${kid}-${Date.now()}.jpg`;
  const tam = path.join(avatarDizin, dosya);
  await indir(`https://image.tmdb.org/t/p/w1280${filePath}`, ham);
  await kirpKapak(ham, tam);
  fs.unlink(ham, () => {});
  const yol = `/avatarlar/${dosya}`;
  const { rows } = await havuz.query(
    'SELECT kapak FROM kullanicilar WHERE id=$1', [kid]);
  await havuz.query('UPDATE kullanicilar SET kapak=$1 WHERE id=$2', [yol, kid]);
  const eski = rows[0]?.kapak;
  // Yalnız bu hesabın eski kapak dosyasını sil; başka yola dokunma.
  if (eski && eski !== yol && eski.startsWith(`/avatarlar/kapak${kid}-`)) {
    fs.unlink(path.join(avatarDizin, path.basename(eski)), () => {});
  }
  return yol;
}

async function ana() {
  if (!fs.existsSync(avatarDizin)) throw new Error(`avatar yok: ${avatarDizin}`);
  const { rows: tohumlar } = await havuz.query(
    `SELECT id, kullanici_adi FROM kullanicilar
      WHERE kullanici_adi = ANY($1::text[])`,
    [Object.keys(KAPAK)],
  );
  const idOf = Object.fromEntries(tohumlar.map((r) => [r.kullanici_adi, r.id]));
  if (Object.values(idOf).includes(ALCELIK)) throw new Error('alcelik');
  for (const ad of Object.keys(KAPAK)) {
    if (!idOf[ad]) throw new Error(`tohum yok: ${ad}`);
  }

  let kapakN = 0;
  if (!sadeceFilm) {
    for (const [ad, k] of Object.entries(KAPAK)) {
      if (filtre.size && !filtre.has(ad)) continue;
      const id = idOf[ad];
      const yol = await kapakYaz(id, k.tur, k.tmdb_id, k.path);
      console.log(`kapak ${ad} ${yol || 'YOK'}`);
      if (yol) kapakN++;
    }
  }
  if (sadeceKapak) {
    const al = await havuz.query(
      'SELECT kapak FROM kullanicilar WHERE id=$1', [ALCELIK]);
    console.log('alcelik kapak', al.rows[0]?.kapak);
    await havuz.end();
    return;
  }

  for (const [ad, tmdb] of YANLIS_FILM) {
    if (filtre.size && !filtre.has(ad)) continue;
    const id = idOf[ad];
    await havuz.query(
      `DELETE FROM izlemeler WHERE kullanici_id=$1 AND tur='movie' AND tmdb_id=$2`,
      [id, tmdb]);
    await havuz.query(
      `DELETE FROM durumlar WHERE kullanici_id=$1 AND tur='movie' AND tmdb_id=$2`,
      [id, tmdb]);
    await havuz.query(
      `DELETE FROM liste_ogeleri o USING listeler l
        WHERE o.liste_id=l.id AND l.kullanici_id=$1 AND o.tur='movie' AND o.tmdb_id=$2`,
      [id, tmdb]);
    console.log(`silindi yanlis ${ad} ${tmdb}`);
  }

  let filmN = 0;
  for (const [ad, liste] of Object.entries(FILM_ARA)) {
    if (filtre.size && !filtre.has(ad)) continue;
    const id = idOf[ad];
    for (let i = 0; i < liste.length; i++) {
      const [sorgu, yil, dil] = liste[i];
      const f = await araFilm(sorgu, yil, dil);
      if (!f?.id) {
        console.log(`film yok ${ad} ${sorgu} ${yil}`);
        continue;
      }
      const yayin = String(f.release_date || '').slice(0, 4);
      console.log(`  film ${ad} ${sorgu} → ${f.id} ${f.title} (${yayin})`);
      // Eski izlemeler şeridin başında kalsın; ekler 40–70 gün önce.
      const tarih = new Date(Date.now() - (40 + i * 3) * 24 * 3600 * 1000);
      const { rows: dur } = await havuz.query(
        `SELECT durum FROM durumlar WHERE kullanici_id=$1 AND tur='movie' AND tmdb_id=$2`,
        [id, f.id],
      );
      if (!dur.length) {
        await havuz.query(
          `INSERT INTO durumlar (kullanici_id, tur, tmdb_id, durum, guncelleme)
           VALUES ($1,'movie',$2,'bitirdim',$3)`,
          [id, f.id, tarih],
        );
      } else if (dur[0].durum === 'izleyecegim') {
        // izleyecegim + izlemeler satırı aynı anda olamaz.
        await havuz.query(
          `UPDATE durumlar SET durum='bitirdim', guncelleme=$3
            WHERE kullanici_id=$1 AND tur='movie' AND tmdb_id=$2`,
          [id, f.id, tarih],
        );
      }
      await havuz.query(
        `INSERT INTO izlemeler (kullanici_id, tur, tmdb_id, sezon, bolum, tarih)
         VALUES ($1,'movie',$2,0,0,$3) ON CONFLICT DO NOTHING`,
        [id, f.id, tarih],
      );
      filmN++;
      const { rows: listeler } = await havuz.query(
        `SELECT l.id, count(o.tmdb_id)::int AS n
           FROM listeler l LEFT JOIN liste_ogeleri o ON o.liste_id=l.id
          WHERE l.kullanici_id=$1 GROUP BY l.id ORDER BY n ASC`,
        [id],
      );
      for (const L of listeler) {
        if (L.n >= 8) continue;
        const ek = await havuz.query(
          `INSERT INTO liste_ogeleri (liste_id, tmdb_id, tur)
           VALUES ($1,$2,'movie') ON CONFLICT DO NOTHING`,
          [L.id, f.id],
        );
        if (ek.rowCount) {
          L.n++;
          break;
        }
      }
    }
  }
  console.log(`film +${filmN}`);

  if (sadeceFilm) {
    const { rows: kanit } = await havuz.query(
      `SELECT k.kullanici_adi,
              (SELECT count(DISTINCT tmdb_id) FROM izlemeler i
                WHERE i.kullanici_id=k.id AND i.tur='movie') AS iz_film
         FROM kullanicilar k WHERE k.id = ANY($1::int[]) ORDER BY k.id`,
      [Object.values(idOf)],
    );
    for (const r of kanit) console.log(`  ${r.kullanici_adi} iz_film=${r.iz_film}`);
    const al = await havuz.query('SELECT kapak FROM kullanicilar WHERE id=$1', [ALCELIK]);
    console.log('alcelik kapak', al.rows[0]?.kapak);
    await havuz.end();
    return;
  }

  let kisiN = 0;
  for (const [ad, isimler] of Object.entries(KISI_ARA)) {
    if (filtre.size && !filtre.has(ad)) continue;
    const id = idOf[ad];
    const bulunan = [];
    for (const isim of isimler) {
      const k = await araKisi(isim);
      if (!k?.id) {
        console.log(`kisi yok ${ad} ${isim}`);
        continue;
      }
      console.log(`  kisi ${ad} ${isim} → ${k.id} ${k.name}`);
      bulunan.push(k.id);
    }
    if (!bulunan.length) continue;
    await havuz.query(
      `DELETE FROM favoriler WHERE kullanici_id=$1 AND tur='person'`, [id]);
    for (const kid of bulunan) {
      await havuz.query(
        `INSERT INTO favoriler (kullanici_id, tur, tmdb_id, tarih)
         VALUES ($1,'person',$2,now()) ON CONFLICT DO NOTHING`,
        [id, kid],
      );
      kisiN++;
    }
  }
  console.log(`kisi +${kisiN}`);

  const { rows: kanit } = await havuz.query(
    `SELECT k.kullanici_adi, k.kapak,
            (SELECT count(*) FILTER (WHERE d.tur='movie' AND d.durum='bitirdim')
               FROM durumlar d WHERE d.kullanici_id=k.id) AS film,
            (SELECT count(DISTINCT tmdb_id) FROM izlemeler i
              WHERE i.kullanici_id=k.id AND i.tur='movie') AS iz_film,
            (SELECT count(*) FROM liste_ogeleri o JOIN listeler l ON l.id=o.liste_id
              WHERE l.kullanici_id=k.id) AS liste_oge,
            (SELECT count(*) FROM favoriler f WHERE f.kullanici_id=k.id AND f.tur='person') AS kisi
       FROM kullanicilar k WHERE k.id = ANY($1::int[]) ORDER BY k.id`,
    [Object.values(idOf)],
  );
  for (const r of kanit) {
    console.log(`  ${r.kullanici_adi} film=${r.film} iz=${r.iz_film} liste=${r.liste_oge} kisi=${r.kisi} ${r.kapak}`);
  }
  const al = await havuz.query(
    'SELECT kapak FROM kullanicilar WHERE id=$1', [ALCELIK]);
  console.log('alcelik kapak', al.rows[0]?.kapak);
  await havuz.end();
}

ana().catch((e) => {
  console.error(e);
  process.exit(1);
});
