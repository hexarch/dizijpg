#!/usr/bin/env node
/**
 * Tohum hesap avatarlarını düz renk yerine film/dizi karakter karesi yapar.
 * Kaynak: TMDB kişi profili (canlı çekim = karakterin yüzü) veya anime afişi.
 * Çocuk karakter yok. Dosya adı zaman damgalı — CDN immutable eski PNG'yi tutmasın.
 *
 *   docker cp araclar/intl_avatar_karakter.js dizijpg-api:/app/
 *   docker exec -w /app dizijpg-api node intl_avatar_karakter.js
 *   # yalnız bazı hesaplar:
 *   docker exec -w /app dizijpg-api node intl_avatar_karakter.js yuki.dorama miles.watches
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

const avatarDizin = AVATAR_DIZIN || '/veri/avatarlar';
const filtre = new Set(process.argv.slice(2));

/** person: oyuncunun TMDB profili (karakterin yüzü). path: afiş/kare. */
const AVATARLAR = [
  {
    ad: 'yuki.dorama',
    path: '/kGGDTXPqndpaNvHHtpemM3WkgsL.jpg',
    boyut: 'w1280',
    vf: 'crop=iw*0.46:iw*0.46:(iw-iw*0.46)/2:ih*0.08,scale=800:800',
    kim: 'Spike Spiegel (Cowboy Bebop)',
  },
  { ad: 'jiwon.drama', person: 1134684, kim: 'Woo Young-woo (Park Eun-bin)' },
  {
    ad: 'miles.watches',
    path: '/ztkUQFLlC19CCMYHW9o1zWhJRNq.jpg',
    boyut: 'original',
    vf: 'crop=iw*0.38:iw*0.38:(iw-iw*0.38)/2:ih*0.14,scale=800:800',
    kim: 'Walter White',
  },
  { ad: 'lin.binge', person: 1338, kim: 'Su Li-zhen (Maggie Cheung)' },
  { ad: 'aanya.screens', person: 55061, kim: 'Simran (Kajol, DDLJ)' },
  { ad: 'lucia.series', person: 955, kim: 'Raimunda (Penélope Cruz, Volver)' },
  { ad: 'camille.ecran', person: 2405, kim: 'Amélie Poulain' },
  { ad: 'lena.serie', person: 678, kim: 'Christa-Maria (Martina Gedeck)' },
  { ad: 'sofia.seriesbr', person: 10055, kim: 'Dora (Fernanda Montenegro)' },
  { ad: 'nour.yushahid', person: 1075789, kim: 'Maggie (Razane Jammal, Paranormal)' },
  { ad: 'rafi.screen', person: 120430, kim: 'Vartika Chaturvedi (Shefali Shah)' },
  { ad: 'daria.serial', person: 1067188, kim: 'Liliya (Elena Lyadova, Leviathan)' },
  { ad: 'zara.dramay', person: 2351109, kim: 'Biba (Alina Khan, Joyland)' },
  { ad: 'dimas.nonton', person: 113732, kim: 'Rama (Iko Uwais, The Raid)' },
  { ad: 'minh.phim', person: 91378, kim: 'Hai Phượng (Ngô Thanh Vân)' },
];

const { Pool } = pg;
const havuz = new Pool({ connectionString: DATABASE_URL });

async function tmdb(yol) {
  for (let d = 0; d < 4; d++) {
    const c = await fetch(`https://api.themoviedb.org/3${yol}`, {
      headers: { Authorization: `Bearer ${TMDB_TOKEN}` },
    });
    if (c.status === 429) {
      await new Promise((r) => setTimeout(r, 1500 * (d + 1)));
      continue;
    }
    if (!c.ok) throw new Error(`TMDB ${c.status} ${yol}`);
    return c.json();
  }
  throw new Error(`TMDB 429 ${yol}`);
}

async function indir(url, hedef) {
  const c = await fetch(url);
  if (!c.ok) throw new Error(`indirme ${c.status} ${url}`);
  fs.writeFileSync(hedef, Buffer.from(await c.arrayBuffer()));
}

function kareKirp(giris, cikis, vf) {
  return new Promise((ok, no) => {
    const ff = spawn('ffmpeg', [
      '-y', '-i', giris,
      '-vf', vf ||
        "crop='min(iw,ih)':'min(iw,ih)':'(iw-min(iw,ih))/2':'(ih-min(iw,ih))*0.12',scale=800:800",
      '-q:v', '3',
      cikis,
    ], { stdio: ['ignore', 'ignore', 'pipe'] });
    let err = '';
    ff.stderr.on('data', (b) => { err += b; });
    ff.on('close', (kod) => {
      if (kod === 0) ok();
      else no(new Error(`ffmpeg ${kod} ${err.slice(-200)}`));
    });
  });
}

async function kaynakYol(a) {
  if (a.path) return a.path;
  const p = await tmdb(`/person/${a.person}`);
  if (!p.profile_path) throw new Error(`profil yok person ${a.person}`);
  return p.profile_path;
}

async function ana() {
  if (!fs.existsSync(avatarDizin)) {
    throw new Error(`avatar dizini yok: ${avatarDizin}`);
  }
  for (const a of AVATARLAR) {
    if (filtre.size && !filtre.has(a.ad)) continue;
    const { rows } = await havuz.query(
      'SELECT id, avatar FROM kullanicilar WHERE kullanici_adi=$1', [a.ad]);
    if (!rows.length) {
      console.log(`YOK ${a.ad}`);
      continue;
    }
    const id = rows[0].id;
    if (id === 3) throw new Error('alcelik koruması');
    const rel = await kaynakYol(a);
    const ham = path.join(avatarDizin, `tmp-${id}-ham.jpg`);
    const dosya = `avatar${id}-${Date.now()}.jpg`;
    const tam = path.join(avatarDizin, dosya);
    const boyut = a.boyut || 'h632';
    await indir(`https://image.tmdb.org/t/p/${boyut}${rel}`, ham);
    await kareKirp(ham, tam, a.vf);
    fs.unlink(ham, () => {});
    const yol = `/avatarlar/${dosya}`;
    await havuz.query('UPDATE kullanicilar SET avatar=$1 WHERE id=$2', [yol, id]);
    const eski = rows[0].avatar;
    if (eski?.startsWith('/avatarlar/') && eski !== yol) {
      fs.unlink(path.join(avatarDizin, path.basename(eski)), () => {});
    }
    console.log(`+ ${a.ad} ${a.kim} → ${yol}`);
  }
  await havuz.end();
}

ana().catch((e) => {
  console.error(e);
  process.exit(1);
});
