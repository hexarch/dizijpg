#!/usr/bin/env node
/**
 * Başka ülkelerden tohum hesaplar — profilde ülke bayrağı görünsün diye.
 * Gönderi YAZMAZ (kısa otomatik metinler canlıdan silindi).
 *
 * Gerçek kişi taklidi YOK (ünlü adı yok). Avatar: film/dizi karakter karesi
 * (`intl_avatar_karakter.js`); bu betik yalnız avatarı boş olan yeni hesaba
 * düz renk yazar. E-posta @intl.dizijpg.invalid. Şifre depoda yok.
 *
 * Tekrar çalıştırmak güvenli: aynı kullanıcı adı varsa atlar.
 *
 * API konteyneri içinde:
 *   node /app/araclar/ulke_kullanici_tohum.js
 * Host:
 *   docker cp araclar/ulke_kullanici_tohum.js dizijpg-api:/app/araclar/
 *   docker exec dizijpg-api node /app/araclar/ulke_kullanici_tohum.js
 */
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import zlib from 'zlib';
import bcrypt from 'bcryptjs';
import pg from 'pg';

const { DATABASE_URL, AVATAR_DIZIN } = process.env;
if (!DATABASE_URL) {
  console.error('DATABASE_URL gerekli');
  process.exit(1);
}

const avatarDizin = AVATAR_DIZIN || '/veri/avatarlar';
const RESMI_ID = 42; // dizi.jpg — takip edilir, bildirim üretmez (SQL)
const SIFRE_DOSYA = process.env.INTL_SIFRE_DOSYA || '/yedekler/intl-kullanicilar.txt';

const { Pool } = pg;
const havuz = new Pool({ connectionString: DATABASE_URL });

/** Tohum hesaplar: çevirisi doldurulan 15 dilin ülkeleri (TR zaten var). */
const TOHUM = [
  { ad: 'miles.watches', ulke: 'Amerika Birleşik Devletleri', renk: [60, 59, 110], bio: 'I watch too many shows and still start another one.' },
  { ad: 'lin.binge', ulke: 'Çin', renk: [222, 41, 16], bio: '追剧停不下来。' },
  { ad: 'aanya.screens', ulke: 'Hindistan', renk: [255, 153, 51], bio: 'सीरीज़ देखना मेरा रोज़ का काम है।' },
  { ad: 'lucia.series', ulke: 'İspanya', renk: [170, 21, 27], bio: 'Las series son mi segunda jornada.' },
  { ad: 'camille.ecran', ulke: 'Fransa', renk: [0, 35, 149], bio: "Je commence une série et j'oublie l'heure." },
  { ad: 'nour.yushahid', ulke: 'Mısır', renk: [206, 17, 38], bio: 'أتابع المسلسلات أكثر مما ينبغي، وما زلت أبدأ واحدة جديدة.' },
  { ad: 'rafi.screen', ulke: 'Bangladeş', renk: [0, 106, 78], bio: 'সিরিজ দেখাই আমার নিত্যদিনের কাজ।' },
  { ad: 'sofia.seriesbr', ulke: 'Brezilya', renk: [0, 156, 59], bio: 'Assisto série demais e mesmo assim começo outra.' },
  { ad: 'daria.serial', ulke: 'Rusya', renk: [0, 57, 166], bio: 'Сериалы — это мой второй рабочий день.' },
  { ad: 'zara.dramay', ulke: 'Pakistan', renk: [1, 65, 28], bio: 'ڈرامے دیکھنا میرا روز کا کام ہے۔' },
  { ad: 'dimas.nonton', ulke: 'Endonezya', renk: [206, 17, 38], bio: 'Nonton serial sampai lupa waktu.' },
  { ad: 'lena.serie', ulke: 'Almanya', renk: [221, 0, 0], bio: 'Ich schaue zu viele Serien und fange trotzdem eine neue an.' },
  { ad: 'yuki.dorama', ulke: 'Japonya', renk: [188, 0, 45], bio: 'ドラマを見すぎても、また次を始めてしまう。' },
  { ad: 'minh.phim', ulke: 'Vietnam', renk: [218, 37, 29], bio: 'Xem phim nhiều quá vẫn bắt đầu bộ mới.' },
  { ad: 'jiwon.drama', ulke: 'Güney Kore', renk: [0, 52, 120], bio: '드라마를 너무 많이 봐도 또 새 작품을 시작해요.' },
];

const AD_KALIP = /^(?!.*\.\.)[a-z0-9_][a-z0-9_.-]{1,18}[a-z0-9_]$/;

/** CRC32 + IHDR/IDAT/IEND ile düz renkli PNG üretir (dış paket yok). */
function karePng(r, g, b, kenar = 400) {
  const satir = kenar * 3 + 1;
  const ham = Buffer.alloc(satir * kenar);
  for (let y = 0; y < kenar; y++) {
    ham[y * satir] = 0;
    for (let x = 0; x < kenar; x++) {
      const i = y * satir + 1 + x * 3;
      ham[i] = r;
      ham[i + 1] = g;
      ham[i + 2] = b;
    }
  }
  const parca = (tip, veri) => {
    const govde = Buffer.concat([Buffer.from(tip), veri]);
    const crc = crc32(govde);
    const uzun = Buffer.alloc(4);
    uzun.writeUInt32BE(veri.length);
    const crcBuf = Buffer.alloc(4);
    crcBuf.writeUInt32BE(crc);
    return Buffer.concat([uzun, govde, crcBuf]);
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(kenar, 0);
  ihdr.writeUInt32BE(kenar, 4);
  ihdr[8] = 8;
  ihdr[9] = 2;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    parca('IHDR', ihdr),
    parca('IDAT', zlib.deflateSync(ham, { level: 9 })),
    parca('IEND', Buffer.alloc(0)),
  ]);
}

function crc32(buf) {
  let c = ~0;
  for (let i = 0; i < buf.length; i++) {
    c ^= buf[i];
    for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (0xedb88320 & -(c & 1));
  }
  return (~c) >>> 0;
}

async function ana() {
  for (const t of TOHUM) {
    if (!AD_KALIP.test(t.ad)) throw new Error(`kullanıcı adı geçersiz: ${t.ad}`);
  }
  if (!fs.existsSync(avatarDizin)) {
    throw new Error(`avatar dizini yok: ${avatarDizin}`);
  }

  const sifreler = [];
  let eklenen = 0;
  let atlanan = 0;

  for (let i = 0; i < TOHUM.length; i++) {
    const t = TOHUM[i];
    const email = `${t.ad}@intl.dizijpg.invalid`;
    const varOlan = await havuz.query(
      'SELECT id, avatar FROM kullanicilar WHERE kullanici_adi=$1', [t.ad]);
    let id;
    if (varOlan.rows.length) {
      id = varOlan.rows[0].id;
      atlanan++;
      await havuz.query(
        `UPDATE kullanicilar
            SET bio=$1, ulke=$2, karsilama_bitti=true, email=COALESCE(email,$3)
          WHERE id=$4`,
        [t.bio, t.ulke, email, id],
      );
      console.log(`var ${t.ad} (id=${id}) — bio/ulke güncellendi`);
    } else {
      const sifre = crypto.randomBytes(12).toString('base64url');
      const hash = await bcrypt.hash(sifre, 10);
      const olusturma = new Date(Date.now() - (TOHUM.length - i) * 11 * 3600 * 1000);
      const { rows } = await havuz.query(
        `INSERT INTO kullanicilar
           (email, kullanici_adi, sifre_hash, bio, ulke, karsilama_bitti, misafir, olusturma)
         VALUES ($1,$2,$3,$4,$5,true,false,$6)
         RETURNING id`,
        [email, t.ad, hash, t.bio, t.ulke, olusturma],
      );
      id = rows[0].id;
      sifreler.push(`${t.ad}\t${email}\t${sifre}`);
      eklenen++;
      console.log(`+ ${t.ad} (id=${id}) ${t.ulke}`);
    }

    // Var olan avatarı ezme (karakter karesi intl_avatar_karakter.js ile gelir).
    const eskiAvatar = varOlan.rows[0]?.avatar;
    if (!eskiAvatar) {
      const dosya = `avatar${id}-intl.png`;
      fs.writeFileSync(path.join(avatarDizin, dosya), karePng(...t.renk));
      await havuz.query(
        'UPDATE kullanicilar SET avatar=$1 WHERE id=$2',
        [`/avatarlar/${dosya}`, id],
      );
    }

    await havuz.query(
      `INSERT INTO takipler (takip_eden_id, takip_edilen_id)
       SELECT $1::int, $2::int WHERE $1::int <> $2::int
       ON CONFLICT DO NOTHING`,
      [id, RESMI_ID],
    );
  }

  if (sifreler.length) {
    const baslik = '# dizi.jpg intl tohum — asla git\'e koyma\n# kullanici_adi\\temail\\tsifre\n';
    try {
      fs.writeFileSync(SIFRE_DOSYA, baslik + sifreler.join('\n') + '\n', { mode: 0o600 });
      console.log(`şifreler: ${SIFRE_DOSYA}`);
    } catch (e) {
      console.log('şifre dosyası yazılamadı, stdout:');
      console.log(sifreler.join('\n'));
    }
  }
  console.log(`bitti: ${eklenen} yeni, ${atlanan} vardı`);
  await havuz.end();
}

ana().catch((e) => {
  console.error(e);
  process.exit(1);
});
