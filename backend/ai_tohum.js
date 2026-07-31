// dizi.jpg AI tohum betiği — API KONTEYNERİ İÇİNDE bir kez çalıştırılır:
//   docker cp ai_tohum.js dizijpg-api:/app/ && docker cp ai_yorumlar.json dizijpg-api:/app/
//   docker exec dizijpg-api node ai_tohum.js
//
// Yaptıkları (tekrar çalıştırmak güvenlidir; var olanı atlar):
//   1. dizi.jpg.ai kullanıcısını oluşturur (avatar = dizi.jpg resmi hesabının
//      profil resminin KOPYASI — orijinal değişirse AI'ınki bozulmasın).
//   2. ai_yorumlar.json'daki 25 dizi + 25 filme, TMDB'den indirilen 2'şer
//      sahne karesiyle spoilersız Türkçe yorum ekler (kaynak_dil=tr).
//   3. Her metnin İngilizce çevirisini metin_cevirileri'ne yazar.
// Yorum tarihleri son ~6 güne yayılır (eskiden yeniye, id sırasıyla uyumlu).
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import bcrypt from 'bcryptjs';
import pg from 'pg';
const { Pool } = pg;

const { DATABASE_URL, TMDB_TOKEN, MEDYA_DIZIN, AVATAR_DIZIN, AI_SIFRE } = process.env;
if (!DATABASE_URL || !TMDB_TOKEN) {
  console.error('DATABASE_URL / TMDB_TOKEN gerekli'); process.exit(1);
}
const medyaDizin = MEDYA_DIZIN || './medya';
const avatarDizin = AVATAR_DIZIN || './avatarlar';
const havuz = new Pool({ connectionString: DATABASE_URL });

const AI_KULLANICI = 'dizi.jpg.ai';
const AI_EMAIL = 'ai@dizijpg.com';
const KARE_SAYISI = 10; // yorum başına sahne karesi
const KARE_BOYUT = 'w1280'; // tam kalite (kullanıcı sunucuda yer açacak)
const AI_BIO = "dizi.jpg'nin yapay zekasi. En sevilen dizi ve filmleri spoilersiz anlatirim.";
const RESMI_HESAP_ID = 42; // dizi.jpg resmi hesabı (avatar kaynağı)

async function tmdb(yol) {
  for (let d = 0; d < 3; d++) {
    const c = await fetch(`https://api.themoviedb.org/3${yol}`, {
      headers: { Authorization: `Bearer ${TMDB_TOKEN}` },
    });
    if (c.status === 429) { await new Promise((r) => setTimeout(r, 1500)); continue; }
    if (!c.ok) throw new Error(`TMDB ${c.status} ${yol}`);
    return c.json();
  }
  throw new Error(`TMDB 429 pes ${yol}`);
}

async function indir(url, hedef) {
  const c = await fetch(url);
  if (!c.ok) throw new Error(`indirme ${c.status} ${url}`);
  fs.writeFileSync(hedef, Buffer.from(await c.arrayBuffer()));
}

async function kullaniciHazirla() {
  const var_ = await havuz.query(
    'SELECT id, avatar FROM kullanicilar WHERE kullanici_adi=$1', [AI_KULLANICI]);
  if (var_.rows.length) {
    console.log(`kullanıcı zaten var: ${AI_KULLANICI} (id=${var_.rows[0].id})`);
    return var_.rows[0].id;
  }
  const sifre = AI_SIFRE || crypto.randomBytes(12).toString('base64url');
  const hash = await bcrypt.hash(sifre, 10);
  const { rows } = await havuz.query(
    `INSERT INTO kullanicilar (email, kullanici_adi, sifre_hash, bio, ulke)
     VALUES ($1,$2,$3,$4,'TR') RETURNING id`,
    [AI_EMAIL, AI_KULLANICI, hash, AI_BIO],
  );
  const id = rows[0].id;
  console.log(`kullanıcı oluşturuldu: ${AI_KULLANICI} (id=${id}) şifre=${AI_SIFRE ? '(env)' : sifre}`);

  // Avatar: resmi hesabın profil resminin kopyası
  const resmi = await havuz.query(
    'SELECT avatar FROM kullanicilar WHERE id=$1', [RESMI_HESAP_ID]);
  const kaynakYol = resmi.rows[0]?.avatar;
  if (kaynakYol) {
    const kaynak = path.join(avatarDizin, path.basename(kaynakYol));
    if (fs.existsSync(kaynak)) {
      const uzanti = path.extname(kaynak) || '.png';
      const dosya = `avatar${id}-${Date.now()}${uzanti}`;
      fs.copyFileSync(kaynak, path.join(avatarDizin, dosya));
      await havuz.query('UPDATE kullanicilar SET avatar=$1 WHERE id=$2',
        [`/avatarlar/${dosya}`, id]);
      console.log(`avatar kopyalandı: /avatarlar/${dosya}`);
    } else console.warn('UYARI: resmi hesabın avatar dosyası diskte yok, avatar boş kaldı');
  } else console.warn('UYARI: resmi hesabın avatarı yok, avatar boş kaldı');
  return id;
}

// Yapımın en oylanan KARE_SAYISI sahne karesi (yazısız olanlar öncelikli)
// → /medya dosyaları. Hiç backdrop yoksa poster tek kare olarak kullanılır.
async function kareIndir(kullaniciId, tur, tmdbId) {
  const veri = await tmdb(`/${tur}/${tmdbId}/images`);
  const hepsi = (veri.backdrops || []).slice()
    .sort((a, b) => (b.vote_count || 0) - (a.vote_count || 0));
  const yazisiz = hepsi.filter((b) => !b.iso_639_1);
  let secim = [...yazisiz, ...hepsi.filter((b) => b.iso_639_1)]
    .slice(0, KARE_SAYISI);
  if (!secim.length && veri.posters?.length) secim = [veri.posters[0]];
  const yollar = [];
  for (const b of secim) {
    const dosya = `m${kullaniciId}-${crypto.randomBytes(8).toString('hex')}.jpg`;
    await indir(`https://image.tmdb.org/t/p/${KARE_BOYUT}${b.file_path}`,
      path.join(medyaDizin, dosya));
    yollar.push(`/medya/${dosya}`);
  }
  return yollar;
}

async function ana() {
  const veriler = JSON.parse(
    fs.readFileSync(new URL('./ai_yorumlar.json', import.meta.url), 'utf8'));
  const aiId = await kullaniciHazirla();

  // tv/film dönüşümlü sırala ki akışta tek tür üst üste yığılmasın
  const tv = veriler.filter((v) => v.tur === 'tv');
  const film = veriler.filter((v) => v.tur === 'movie');
  const sirali = [];
  for (let i = 0; i < Math.max(tv.length, film.length); i++) {
    if (tv[i]) sirali.push(tv[i]);
    if (film[i]) sirali.push(film[i]);
  }

  const simdi = Date.now();
  const aralikMs = 90 * 60 * 1000; // 90 dk arayla; 250 yorum ~2 haftaya yayılır
  let eklendi = 0, tazelendi = 0, atlandi = 0, hatali = 0;
  for (let i = 0; i < sirali.length; i++) {
    const v = sirali[i];
    try {
      const mevcut = await havuz.query(
        `SELECT id, medya FROM yorumlar
         WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3 AND sezon IS NULL`,
        [aiId, v.tur, v.tmdb_id]);
      if (mevcut.rows.length) {
        // Var olan yorum: kare sayısı eksikse medya setini yenile
        // (eskiler en oylanan 2'ydi; taze 10'luk set indirilir, eskiler silinir).
        const y = mevcut.rows[0];
        if ((y.medya || []).length >= KARE_SAYISI) { atlandi++; continue; }
        const medya = await kareIndir(aiId, v.tur, v.tmdb_id);
        if (!medya.length) { atlandi++; continue; }
        await havuz.query('UPDATE yorumlar SET medya=$1 WHERE id=$2',
          [medya, y.id]);
        for (const m of y.medya || []) {
          fs.unlink(path.join(medyaDizin, path.basename(m)), () => {});
        }
        tazelendi++;
        console.log(`~ ${v.tur} ${v.ad} (medya ${y.medya?.length || 0}→${medya.length})`);
        continue;
      }

      const medya = await kareIndir(aiId, v.tur, v.tmdb_id);
      const tarih = new Date(simdi - (sirali.length - 1 - i) * aralikMs);
      await havuz.query(
        `INSERT INTO yorumlar (kullanici_id, tur, tmdb_id, metin, medya, spoiler, kaynak_dil, tarih)
         VALUES ($1,$2,$3,$4,$5,false,'tr',$6)`,
        [aiId, v.tur, v.tmdb_id, v.tr, medya, tarih]);
      await havuz.query(
        `INSERT INTO metin_cevirileri (ozet, dil, metin)
         VALUES (md5(btrim($1)), 'en', $2) ON CONFLICT (ozet, dil) DO NOTHING`,
        [v.tr, v.en]);
      eklendi++;
      console.log(`+ ${v.tur} ${v.ad} (${medya.length} kare)`);
    } catch (e) {
      hatali++;
      console.error(`! ${v.tur} ${v.ad}: ${e.message}`);
    }
  }
  console.log(`bitti: ${eklendi} eklendi, ${tazelendi} tazelendi, ${atlandi} atlandı, ${hatali} hatalı`);
  await havuz.end();
}

ana().catch((e) => { console.error(e); process.exit(1); });
