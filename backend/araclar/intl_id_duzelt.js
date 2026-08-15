#!/usr/bin/env node
/**
 * Tohum hesaplardaki yanlış TMDB id'lerini düzeltir ve sahne karelerini
 * doğru yapıma göre yeniden indirir. API konteynerinde:
 *   node intl_id_duzelt.js
 */
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import pg from 'pg';
import { imzaCikar, ayniGorsel } from './kare_imza.js';

const { DATABASE_URL, TMDB_TOKEN, MEDYA_DIZIN, AVATAR_DIZIN } = process.env;
if (!DATABASE_URL || !TMDB_TOKEN) {
  console.error('DATABASE_URL / TMDB_TOKEN gerekli');
  process.exit(1);
}

const medyaDizin = MEDYA_DIZIN || '/veri/medya';
const avatarDizin = AVATAR_DIZIN || '/veri/avatarlar';
const KARE_SAYISI = 8;
const KARE_BOYUT = 'w780';
const BOLUM_TAVAN = 80;
const TOHUM_MIN = 163;
const TOHUM_MAX = 177;

// Zincirler önce (Raid 2, sonra Raid 1; Jujutsu, sonra Slow Horses).
const HARITA = [
  ['movie', 94329, 180299],
  ['movie', 71469, 94329],
  ['movie', 479, 20992],
  ['movie', 1443, 666],
  ['movie', 1667, 11190],
  ['movie', 1690, 3040],
  ['movie', 4488, 219],
  ['movie', 10427, 19552],
  ['movie', 10664, 7347],
  ['movie', 242578, 265180],
  ['movie', 265208, 411088],
  ['movie', 334543, 360814],
  ['movie', 397422, 416477],
  ['movie', 426426, 428495],
  ['movie', 447055, 467012],
  ['movie', 480414, 567973],
  ['movie', 504562, 517814],
  ['movie', 893341, 464293],
  ['movie', 948969, 962571],
  ['tv', 2832, 890],
  ['tv', 10950, 30981],
  ['tv', 30984, 30991],
  ['tv', 30985, 1063],
  ['tv', 42586, 42509],
  ['tv', 46260, 46298],
  ['tv', 61181, 66980],
  ['tv', 62746, 62476],
  ['tv', 67198, 68467],
  ['tv', 67744, 79352],
  ['tv', 80752, 88236],
  ['tv', 82156, 87508],
  ['tv', 82230, 81133],
  ['tv', 87917, 87382],
  ['tv', 90669, 95202],
  ['tv', 90977, 96677],
  ['tv', 91734, 106590],
  ['tv', 95480, 95479],
  ['tv', 96199, 90761],
  ['tv', 110316, 128883],
  ['tv', 123356, 126308],
  ['tv', 136311, 206010],
  ['tv', 125988, 95480],
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
    if (c.status === 404) return null;
    if (!c.ok) throw new Error(`TMDB ${c.status} ${yol}`);
    return c.json();
  }
  throw new Error(`TMDB 429 pes ${yol}`);
}

async function kapakYaz(kullaniciId, tur, tmdbId) {
  const veri = await tmdb(`/${tur}/${tmdbId}/images`);
  const b = (veri?.backdrops || [])[0];
  if (!b) return null;
  const dosya = `kapak${kullaniciId}-intl.jpg`;
  try {
    await indir(`https://image.tmdb.org/t/p/w1280${b.file_path}`,
      path.join(avatarDizin, dosya));
  } catch {
    return null;
  }
  const yol = `/avatarlar/${dosya}`;
  await havuz.query('UPDATE kullanicilar SET kapak=$1 WHERE id=$2', [yol, kullaniciId]);
  return yol;
}

async function indir(url, hedef) {
  const c = await fetch(url);
  if (!c.ok) throw new Error(`indirme ${c.status}`);
  fs.writeFileSync(hedef, Buffer.from(await c.arrayBuffer()));
}

async function indirVeHashle(kullaniciId, b) {
  const dosya = `m${kullaniciId}-${crypto.randomBytes(8).toString('hex')}.jpg`;
  const tamYol = path.join(medyaDizin, dosya);
  try {
    await indir(`https://image.tmdb.org/t/p/${KARE_BOYUT}${b.file_path}`, tamYol);
  } catch {
    return null;
  }
  const imza = await imzaCikar(tamYol);
  return { yol: `/medya/${dosya}`, tamYol, imza };
}

async function kareIndir(kullaniciId, tur, tmdbId) {
  const veri = await tmdb(`/${tur}/${tmdbId}/images`);
  if (!veri) return [];
  const hepsi = (veri.backdrops || []).slice()
    .sort((a, b) => (b.vote_count || 0) - (a.vote_count || 0));
  const yazisiz = hepsi.filter((b) => !b.iso_639_1);
  let aday = [...yazisiz, ...hepsi.filter((b) => b.iso_639_1)]
    .slice(0, KARE_SAYISI * 3);
  const posterler = (veri.posters || []).slice()
    .sort((a, b) => (b.vote_count || 0) - (a.vote_count || 0));
  if (aday.length < KARE_SAYISI) {
    aday = [...aday, ...posterler].slice(0, KARE_SAYISI * 3);
  }
  const tutulanImza = [];
  const secilen = [];
  for (let i = 0; i < aday.length && secilen.length < KARE_SAYISI; i += KARE_SAYISI) {
    const inen = (await Promise.all(
      aday.slice(i, i + KARE_SAYISI).map((b) => indirVeHashle(kullaniciId, b)),
    )).filter(Boolean);
    for (const k of inen) {
      const tekrar = k.imza && tutulanImza.some((x) => ayniGorsel(x, k.imza));
      if (tekrar || secilen.length >= KARE_SAYISI) {
        fs.unlink(k.tamYol, () => {});
        continue;
      }
      if (k.imza) tutulanImza.push(k.imza);
      secilen.push(k.yol);
    }
  }
  return secilen;
}

async function tabloTasi(sql, params) {
  await havuz.query(sql, params);
}

async function idTasi(tur, eski, yeni) {
  const aralik = [tur, eski, yeni, TOHUM_MIN, TOHUM_MAX];
  // Çakışan satırları sil, kalanı güncelle.
  await tabloTasi(
    `DELETE FROM durumlar d
      USING durumlar k
      WHERE d.kullanici_id = k.kullanici_id
        AND d.tur = $1 AND d.tmdb_id = $2
        AND k.tur = $1 AND k.tmdb_id = $3
        AND d.kullanici_id BETWEEN $4 AND $5`,
    aralik,
  );
  await tabloTasi(
    `UPDATE durumlar SET tmdb_id=$3
      WHERE tur=$1 AND tmdb_id=$2 AND kullanici_id BETWEEN $4 AND $5`,
    aralik,
  );

  await tabloTasi(
    `DELETE FROM izlemeler d
      USING izlemeler k
      WHERE d.kullanici_id = k.kullanici_id
        AND d.tur = $1 AND d.tmdb_id = $2
        AND k.tur = $1 AND k.tmdb_id = $3
        AND d.sezon = k.sezon AND d.bolum = k.bolum
        AND d.kullanici_id BETWEEN $4 AND $5`,
    aralik,
  );
  await tabloTasi(
    `UPDATE izlemeler SET tmdb_id=$3
      WHERE tur=$1 AND tmdb_id=$2 AND kullanici_id BETWEEN $4 AND $5`,
    aralik,
  );

  await tabloTasi(
    `DELETE FROM puanlar d
      USING puanlar k
      WHERE d.kullanici_id = k.kullanici_id
        AND d.tur = $1 AND d.tmdb_id = $2
        AND k.tur = $1 AND k.tmdb_id = $3
        AND COALESCE(d.sezon,-1)=COALESCE(k.sezon,-1)
        AND COALESCE(d.bolum,-1)=COALESCE(k.bolum,-1)
        AND d.kullanici_id BETWEEN $4 AND $5`,
    aralik,
  );
  await tabloTasi(
    `UPDATE puanlar SET tmdb_id=$3
      WHERE tur=$1 AND tmdb_id=$2 AND kullanici_id BETWEEN $4 AND $5`,
    aralik,
  );

  await tabloTasi(
    `DELETE FROM tepkiler d
      USING tepkiler k
      WHERE d.kullanici_id = k.kullanici_id
        AND d.tur = $1 AND d.tmdb_id = $2
        AND k.tur = $1 AND k.tmdb_id = $3
        AND COALESCE(d.sezon,-1)=COALESCE(k.sezon,-1)
        AND COALESCE(d.bolum,-1)=COALESCE(k.bolum,-1)
        AND d.kullanici_id BETWEEN $4 AND $5`,
    aralik,
  );
  await tabloTasi(
    `UPDATE tepkiler SET tmdb_id=$3
      WHERE tur=$1 AND tmdb_id=$2 AND kullanici_id BETWEEN $4 AND $5`,
    aralik,
  );

  await tabloTasi(
    `DELETE FROM izleme_kaynaklari d
      USING izleme_kaynaklari k
      WHERE d.kullanici_id = k.kullanici_id
        AND d.tur = $1 AND d.tmdb_id = $2
        AND k.tur = $1 AND k.tmdb_id = $3
        AND d.kullanici_id BETWEEN $4 AND $5`,
    aralik,
  );
  await tabloTasi(
    `UPDATE izleme_kaynaklari SET tmdb_id=$3
      WHERE tur=$1 AND tmdb_id=$2 AND kullanici_id BETWEEN $4 AND $5`,
    aralik,
  );

  await tabloTasi(
    `DELETE FROM favoriler d
      USING favoriler k
      WHERE d.kullanici_id = k.kullanici_id
        AND d.tur = $1 AND d.tmdb_id = $2
        AND k.tur = $1 AND k.tmdb_id = $3
        AND d.kullanici_id BETWEEN $4 AND $5`,
    aralik,
  );
  await tabloTasi(
    `UPDATE favoriler SET tmdb_id=$3
      WHERE tur=$1 AND tmdb_id=$2 AND kullanici_id BETWEEN $4 AND $5`,
    aralik,
  );

  await tabloTasi(
    `DELETE FROM liste_ogeleri d
      USING listeler l
      WHERE d.liste_id = l.id
        AND d.tur = $1 AND d.tmdb_id = $2
        AND l.kullanici_id BETWEEN $4 AND $5
        AND EXISTS (
          SELECT 1 FROM liste_ogeleri k
          JOIN listeler l2 ON l2.id = k.liste_id
          WHERE l2.kullanici_id = l.kullanici_id
            AND k.tur = $1 AND k.tmdb_id = $3
        )`,
    aralik,
  );
  await tabloTasi(
    `UPDATE liste_ogeleri o SET tmdb_id=$3
      FROM listeler l
     WHERE o.liste_id = l.id
       AND o.tur=$1 AND o.tmdb_id=$2
       AND l.kullanici_id BETWEEN $4 AND $5`,
    aralik,
  );

  await tabloTasi(
    `UPDATE yorumlar SET tmdb_id=$3
      WHERE tur=$1 AND tmdb_id=$2 AND kullanici_id BETWEEN $4 AND $5`,
    aralik,
  );
}

function medyaDosya(yol) {
  const ad = String(yol || '').split('/').pop();
  return ad ? path.join(medyaDizin, ad) : null;
}

async function kareYenile(yorum) {
  const yeni = await kareIndir(yorum.kullanici_id, yorum.tur, yorum.tmdb_id);
  for (const eski of yorum.medya || []) {
    const f = medyaDosya(eski);
    if (f && fs.existsSync(f)) fs.unlink(f, () => {});
  }
  await havuz.query('UPDATE yorumlar SET medya=$1 WHERE id=$2', [yeni, yorum.id]);
  return yeni.length;
}

async function izlemeYenile(kid, tur, tmdbId, oran, bitis) {
  if (tur !== 'tv' || !oran || oran <= 0) return 0;
  await havuz.query(
    `DELETE FROM izlemeler
      WHERE kullanici_id=$1 AND tur='tv' AND tmdb_id=$2`,
    [kid, tmdbId],
  );
  const info = await tmdb(`/tv/${tmdbId}`);
  if (!info) return 0;
  const sezonlar = (info.seasons || [])
    .filter((s) => s.season_number > 0 && (s.episode_count || 0) > 0);
  const hepsi = [];
  for (const s of sezonlar) {
    for (let b = 1; b <= s.episode_count; b++) {
      hepsi.push([s.season_number, b]);
      if (hepsi.length >= BOLUM_TAVAN) break;
    }
    if (hepsi.length >= BOLUM_TAVAN) break;
  }
  if (!hepsi.length) return 0;
  const n = Math.max(1, Math.min(hepsi.length, Math.floor(hepsi.length * oran)));
  const degerler = [];
  const params = [];
  for (let i = 0; i < n; i++) {
    const [sezon, bolum] = hepsi[i];
    const tarih = new Date(bitis.getTime() - (n - 1 - i) * 6 * 3600 * 1000);
    const b = params.length;
    degerler.push(`($${b + 1},'tv',$${b + 2},$${b + 3},$${b + 4},$${b + 5})`);
    params.push(kid, tmdbId, sezon, bolum, tarih);
  }
  await havuz.query(
    `INSERT INTO izlemeler (kullanici_id, tur, tmdb_id, sezon, bolum, tarih)
     VALUES ${degerler.join(',')}
     ON CONFLICT DO NOTHING`,
    params,
  );
  return n;
}

async function ana() {
  const ham = fs.readFileSync(new URL('./intl_profiller.json', import.meta.url), 'utf8');
  const profiller = JSON.parse(ham);
  const yeniKume = new Set(HARITA.map(([tur, , yeni]) => `${tur}:${yeni}`));
  const eskiKume = new Set(HARITA.map(([tur, eski]) => `${tur}:${eski}`));

  for (const [tur, eski, yeni] of HARITA) {
    console.log(`id ${tur} ${eski} → ${yeni}`);
    await idTasi(tur, eski, yeni);
  }

  const { rows: yorumlar } = await havuz.query(
    `SELECT id, kullanici_id, tur, tmdb_id, medya
       FROM yorumlar
      WHERE kullanici_id BETWEEN $1 AND $2 AND ust_id IS NULL`,
    [TOHUM_MIN, TOHUM_MAX],
  );
  for (const y of yorumlar) {
    const anahtar = `${y.tur}:${y.tmdb_id}`;
    const azKare = !y.medya || y.medya.length < 4;
    if (!yeniKume.has(anahtar) && !azKare) continue;
    const n = await kareYenile(y);
    console.log(`  kare yorum ${y.id} ${y.tur}:${y.tmdb_id} → ${n}`);
  }

  const ad2id = Object.fromEntries(
    (await havuz.query(
      `SELECT id, kullanici_adi FROM kullanicilar WHERE id BETWEEN $1 AND $2`,
      [TOHUM_MIN, TOHUM_MAX],
    )).rows.map((r) => [r.kullanici_adi, r.id]),
  );

  for (const p of profiller) {
    const kid = ad2id[p.ad];
    if (!kid) continue;
    const kapakKaynak = (p.yapimlar || []).find((y) => y.gonderi) || p.yapimlar[0];
    if (kapakKaynak) {
      const yol = await kapakYaz(kid, kapakKaynak.tur, kapakKaynak.tmdb_id);
      console.log(`  kapak ${p.ad} ${yol || 'yok'}`);
    }
    for (const y of p.yapimlar || []) {
      if (y.tur !== 'tv' || y.durum === 'izleyecegim') continue;
      if (!yeniKume.has(`${y.tur}:${y.tmdb_id}`) && !eskiKume.has(`${y.tur}:${y.tmdb_id}`)) {
        continue;
      }
      const n = await izlemeYenile(kid, y.tur, y.tmdb_id, y.oran ?? 1, new Date());
      console.log(`  izleme ${p.ad} tv:${y.tmdb_id} ${n} bölüm`);
    }
  }

  console.log('duzeltme bitti');
  await havuz.end();
}

ana().catch((e) => {
  console.error(e);
  process.exit(1);
});
