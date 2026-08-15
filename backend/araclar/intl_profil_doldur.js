#!/usr/bin/env node
/**
 * Tohum hesap profillerini A'dan Z'ye doldurur.
 *
 * intl_profiller.json'daki her hesap için:
 *   kapak (TMDB sahne), izleme kaydı, durum, puan + inceleme,
 *   uzun gönderi + sahne kareleri, açık liste, favori kişi/yapım,
 *   tepki, platform, takip, son görülme.
 *
 * Kısa cümle YAZMAZ. Tekrar çalışınca aynı (kullanıcı, tur, tmdb) gönderiyi
 * atlar. Google yok; TR/EN çeviri JSON'dan, diğer diller sonra Argos.
 *
 * API konteyneri (kare_imza.js + TMDB_TOKEN gerekir):
 *   docker cp kare_imza.js dizijpg-api:/app/
 *   docker cp araclar/intl_profil_doldur.js dizijpg-api:/app/
 *   docker cp araclar/intl_profiller.json dizijpg-api:/app/
 *   docker exec -w /app dizijpg-api node intl_profil_doldur.js
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
const KARE_SAYISI = 8; // POST /yorumlar tavanı 10; AI tohum 10 kullanır
const KARE_BOYUT = 'w780';
const BOLUM_TAVAN = 80;
const MEDYA_TAVAN = 10;

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
      const tekrar = k.imza && tutulanImza.some((t) => ayniGorsel(t, k.imza));
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

async function izlemeleriYaz(kid, tur, tmdbId, oran, bitis) {
  if (!oran || oran <= 0) return 0;
  if (tur === 'movie') {
    await havuz.query(
      `INSERT INTO izlemeler (kullanici_id, tur, tmdb_id, sezon, bolum, tarih)
       VALUES ($1,'movie',$2,0,0,$3)
       ON CONFLICT DO NOTHING`,
      [kid, tmdbId, bitis],
    );
    return 1;
  }
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
  if (!degerler.length) return 0;
  await havuz.query(
    `INSERT INTO izlemeler (kullanici_id, tur, tmdb_id, sezon, bolum, tarih)
     VALUES ${degerler.join(',')}
     ON CONFLICT DO NOTHING`,
    params,
  );
  return n;
}

async function ceviriYaz(kaynak, dil, metin) {
  if (!metin || !String(metin).trim()) return;
  await havuz.query(
    `INSERT INTO metin_cevirileri (ozet, dil, metin)
     VALUES (md5(btrim($1)), $2, $3)
     ON CONFLICT (ozet, dil) DO NOTHING`,
    [kaynak, dil, metin],
  );
}

async function kullaniciId(ad) {
  const { rows } = await havuz.query(
    'SELECT id FROM kullanicilar WHERE kullanici_adi=$1', [ad]);
  return rows[0]?.id || null;
}

async function profilDoldur(p, sira, toplam) {
  const id = await kullaniciId(p.ad);
  if (!id) {
    console.log(`YOK ${p.ad}`);
    return { atla: 1 };
  }
  const say = { izleme: 0, gonderi: 0, atla: 0, hata: 0 };
  const simdi = Date.now();
  const yayilim = 95 * 24 * 3600 * 1000;

  await havuz.query(
    `UPDATE kullanicilar
        SET bio=$1, karsilama_bitti=true,
            son_gorulme=$2
      WHERE id=$3`,
    [p.bio, new Date(simdi - (toplam - sira) * 5 * 3600 * 1000), id],
  );

  const kapakKaynak = p.yapimlar.find((y) => y.gonderi) || p.yapimlar[0];
  if (kapakKaynak) {
    await kapakYaz(id, kapakKaynak.tur, kapakKaynak.tmdb_id);
  }

  for (const ad of (p.takip || [])) {
    const hedef = await kullaniciId(ad);
    if (!hedef || hedef === id) continue;
    await havuz.query(
      `INSERT INTO takipler (takip_eden_id, takip_edilen_id)
       SELECT $1::int, $2::int WHERE $1::int <> $2::int
       ON CONFLICT DO NOTHING`,
      [id, hedef],
    );
  }

  for (let i = 0; i < p.yapimlar.length; i++) {
    const y = p.yapimlar[i];
    const tarih = new Date(simdi - ((p.yapimlar.length - i) / p.yapimlar.length) * yayilim);
    try {
      await havuz.query(
        `INSERT INTO durumlar (kullanici_id, tur, tmdb_id, durum, guncelleme)
         VALUES ($1,$2,$3,$4,$5)
         ON CONFLICT (kullanici_id, tur, tmdb_id)
         DO UPDATE SET durum=EXCLUDED.durum, guncelleme=EXCLUDED.guncelleme`,
        [id, y.tur, y.tmdb_id, y.durum, tarih],
      );
      if (y.durum !== 'izleyecegim') {
        say.izleme += await izlemeleriYaz(id, y.tur, y.tmdb_id, y.oran ?? 1, tarih);
      }
      if (y.platform) {
        await havuz.query(
          `INSERT INTO izleme_kaynaklari (kullanici_id, tur, tmdb_id, platform, tarih)
           VALUES ($1,$2,$3,$4,$5)
           ON CONFLICT (kullanici_id, tur, tmdb_id)
           DO UPDATE SET platform=EXCLUDED.platform`,
          [id, y.tur, y.tmdb_id, String(y.platform).slice(0, 30), tarih],
        );
      }
      if (y.puan) {
        const varPuan = await havuz.query(
          `SELECT 1 FROM puanlar
            WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3 AND sezon IS NULL`,
          [id, y.tur, y.tmdb_id],
        );
        if (!varPuan.rows.length) {
          await havuz.query(
            `INSERT INTO puanlar (kullanici_id, tur, tmdb_id, puan, yorum, tarih)
             VALUES ($1,$2,$3,$4,$5,$6)`,
            [id, y.tur, y.tmdb_id, y.puan, y.inceleme || null, tarih],
          );
        }
        if (y.inceleme) {
          await ceviriYaz(y.inceleme, 'en', y.inceleme_en);
          await ceviriYaz(y.inceleme, 'tr', y.inceleme_tr);
          await ceviriYaz(y.inceleme, p.dil, y.inceleme);
        }
      }
      if (y.tepki) {
        await havuz.query(
          `INSERT INTO tepkiler (kullanici_id, tur, tmdb_id, emoji, tarih)
           VALUES ($1,$2,$3,$4,$5)
           ON CONFLICT DO NOTHING`,
          [id, y.tur, y.tmdb_id, y.tepki, tarih],
        );
      }
      if (y.gonderi && y.metin) {
        const varMi = await havuz.query(
          `SELECT id FROM yorumlar
            WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3 AND ust_id IS NULL
              AND btrim(metin)=btrim($4)`,
          [id, y.tur, y.tmdb_id, y.metin],
        );
        if (varMi.rows.length) {
          say.atla++;
        } else {
          const medya = (await kareIndir(id, y.tur, y.tmdb_id)).slice(0, MEDYA_TAVAN);
          await havuz.query(
            `INSERT INTO yorumlar
               (kullanici_id, tur, tmdb_id, metin, medya, spoiler, kaynak_dil, tarih)
             VALUES ($1,$2,$3,$4,$5,false,$6,$7)`,
            [id, y.tur, y.tmdb_id, y.metin, medya, p.dil, tarih],
          );
          await ceviriYaz(y.metin, 'en', y.en);
          await ceviriYaz(y.metin, 'tr', y.tr);
          await ceviriYaz(y.metin, p.dil, y.metin);
          say.gonderi++;
          console.log(`  + ${p.ad} ${y.tur}:${y.tmdb_id} (${medya.length} kare)`);
        }
      }
    } catch (e) {
      say.hata++;
      console.error(`  ! ${p.ad} ${y.tur}:${y.tmdb_id} ${e.message}`);
    }
  }

  for (const f of (p.favoriler || [])) {
    await havuz.query(
      `INSERT INTO favoriler (kullanici_id, tur, tmdb_id, tarih)
       VALUES ($1,$2,$3,now()) ON CONFLICT DO NOTHING`,
      [id, f.tur, f.tmdb_id],
    );
  }

  for (const liste of (p.listeler || [])) {
    let { rows } = await havuz.query(
      `SELECT id FROM listeler WHERE kullanici_id=$1 AND ad=$2`,
      [id, liste.ad],
    );
    let lid = rows[0]?.id;
    if (!lid) {
      const ek = await havuz.query(
        `INSERT INTO listeler (kullanici_id, ad, aciklama, herkese_acik)
         VALUES ($1,$2,$3,true) RETURNING id`,
        [id, liste.ad.slice(0, 60), (liste.aciklama || '').slice(0, 300)],
      );
      lid = ek.rows[0].id;
    }
    for (const o of liste.ogeler || []) {
      await havuz.query(
        `INSERT INTO liste_ogeleri (liste_id, tmdb_id, tur)
         VALUES ($1,$2,$3) ON CONFLICT DO NOTHING`,
        [lid, o.tmdb_id, o.tur],
      );
    }
  }

  return say;
}

async function ana() {
  const ham = fs.readFileSync(new URL('./intl_profiller.json', import.meta.url), 'utf8');
  const profiller = JSON.parse(ham);
  const ozet = { gonderi: 0, izleme: 0, atla: 0, hata: 0 };
  for (let i = 0; i < profiller.length; i++) {
    const p = profiller[i];
    console.log(`--- ${p.ad} (${i + 1}/${profiller.length})`);
    const s = await profilDoldur(p, i, profiller.length);
    ozet.gonderi += s.gonderi || 0;
    ozet.izleme += s.izleme || 0;
    ozet.atla += s.atla || 0;
    ozet.hata += s.hata || 0;
  }
  console.log('bitti', ozet);
  await havuz.end();
}

ana().catch((e) => {
  console.error(e);
  process.exit(1);
});
