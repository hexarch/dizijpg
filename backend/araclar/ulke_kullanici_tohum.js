#!/usr/bin/env node
/**
 * Başka ülkelerden tohum hesaplar — profilde bayrak görünsün, akışta
 * çevirisi hazır kısa bir gönderi dursun diye.
 *
 * Gerçek kişi taklidi YOK (ünlü adı, çalıntı fotoğraf yok). Kullanıcı adı
 * uydurma; avatar düz renk kare; e-posta @intl.dizijpg.invalid (asla mail
 * gitmez). Şifre rastgele, dosyaya yazılır, depoYA GİRMEZ.
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
  {
    ad: 'miles.watches', dil: 'en', ulke: 'Amerika Birleşik Devletleri',
    renk: [60, 59, 110], tur: 'tv', tmdb: 1396,
    bio: 'I watch too many shows and still start another one.',
    post: 'The first season looks small, then it just does not let go.',
    en: 'The first season looks small, then it just does not let go.',
    tr: 'İlk sezon küçük duruyor, sonra bırakmıyor.',
  },
  {
    ad: 'lin.binge', dil: 'zh', ulke: 'Çin',
    renk: [222, 41, 16], tur: 'tv', tmdb: 1399,
    bio: '追剧停不下来。',
    post: '人物太多，但每一季都更放不下。',
    en: 'Too many characters, but each season is harder to put down.',
    tr: 'Karakter çok, her sezon daha bırakılmaz oluyor.',
  },
  {
    ad: 'aanya.screens', dil: 'hi', ulke: 'Hindistan',
    renk: [255, 153, 51], tur: 'tv', tmdb: 1396,
    bio: 'सीरीज़ देखना मेरा रोज़ का काम है।',
    post: 'पहला सीज़न धीमा लगता है, फिर छोड़ नहीं सकते।',
    en: 'The first season feels slow, then you cannot leave it.',
    tr: 'İlk sezon yavaş gelir, sonra bırakamazsın.',
  },
  {
    ad: 'lucia.series', dil: 'es', ulke: 'İspanya',
    renk: [170, 21, 27], tur: 'tv', tmdb: 71446,
    bio: 'Las series son mi segunda jornada.',
    post: 'El plan parece imposible y aun así no puedes dejar de mirar.',
    en: 'The plan looks impossible, and you still cannot stop watching.',
    tr: 'Plan imkânsız duruyor, yine de bakmadan duramıyorsun.',
  },
  {
    ad: 'camille.ecran', dil: 'fr', ulke: 'Fransa',
    renk: [0, 35, 149], tur: 'tv', tmdb: 1399,
    bio: "Je commence une série et j'oublie l'heure.",
    post: 'Trop de personnages, et pourtant chaque saison accroche plus.',
    en: 'Too many characters, and yet each season hooks you more.',
    tr: 'Karakter çok, her sezon daha çok sarıyor.',
  },
  {
    ad: 'nour.yushahid', dil: 'ar', ulke: 'Mısır',
    renk: [206, 17, 38], tur: 'tv', tmdb: 1399,
    bio: 'أتابع المسلسلات أكثر مما ينبغي، وما زلت أبدأ واحدة جديدة.',
    post: 'الموسم الأول يبدو هادئاً، بعدها لا تستطيع التوقف.',
    en: 'The first season seems quiet, then you cannot stop.',
    tr: 'İlk sezon sakin duruyor, sonra duramıyorsun.',
  },
  {
    ad: 'rafi.screen', dil: 'bn', ulke: 'Bangladeş',
    renk: [0, 106, 78], tur: 'tv', tmdb: 1396,
    bio: 'সিরিজ দেখাই আমার নিত্যদিনের কাজ।',
    post: 'প্রথম সিজন ছোট মনে হয়, তারপর আর ছাড়া যায় না।',
    en: 'The first season feels small, then you cannot let go.',
    tr: 'İlk sezon küçük gelir, sonra bırakılmaz.',
  },
  {
    ad: 'sofia.seriesbr', dil: 'pt', ulke: 'Brezilya',
    renk: [0, 156, 59], tur: 'tv', tmdb: 71446,
    bio: 'Assisto série demais e mesmo assim começo outra.',
    post: 'O plano parece impossível, mas você não consegue parar.',
    en: 'The plan looks impossible, but you cannot stop.',
    tr: 'Plan imkânsız görünüyor ama duramıyorsun.',
  },
  {
    ad: 'daria.serial', dil: 'ru', ulke: 'Rusya',
    renk: [0, 57, 166], tur: 'tv', tmdb: 1399,
    bio: 'Сериалы — это мой второй рабочий день.',
    post: 'Первый сезон кажется скромным — потом уже не отпустить.',
    en: 'The first season seems modest — then you cannot let go.',
    tr: 'İlk sezon mütevazı duruyor, sonra bırakmıyor.',
  },
  {
    ad: 'zara.dramay', dil: 'ur', ulke: 'Pakistan',
    renk: [1, 65, 28], tur: 'tv', tmdb: 1396,
    bio: 'ڈرامے دیکھنا میرا روز کا کام ہے۔',
    post: 'پہلا سیزن ہلکا لگتا ہے، پھر چھوڑ نہیں سکتے۔',
    en: 'The first season feels light, then you cannot leave it.',
    tr: 'İlk sezon hafif gelir, sonra bırakamazsın.',
  },
  {
    ad: 'dimas.nonton', dil: 'id', ulke: 'Endonezya',
    renk: [206, 17, 38], tur: 'tv', tmdb: 71446,
    bio: 'Nonton serial sampai lupa waktu.',
    post: 'Rencananya mustahil, tapi tetap tidak bisa berhenti nonton.',
    en: 'The plan is impossible, but you still cannot stop watching.',
    tr: 'Plan imkânsız, yine de izlemeyi bırakamıyorsun.',
  },
  {
    ad: 'lena.serie', dil: 'de', ulke: 'Almanya',
    renk: [221, 0, 0], tur: 'tv', tmdb: 1396,
    bio: 'Ich schaue zu viele Serien und fange trotzdem eine neue an.',
    post: 'Staffel eins wirkt klein, danach lässt es dich nicht mehr los.',
    en: 'Season one feels small, then it does not let go.',
    tr: 'Birinci sezon küçük duruyor, sonra bırakmıyor.',
  },
  {
    ad: 'yuki.dorama', dil: 'ja', ulke: 'Japonya',
    renk: [188, 0, 45], tur: 'tv', tmdb: 1399,
    bio: 'ドラマを見すぎても、また次を始めてしまう。',
    post: '登場人物は多いのに、シーズンごとに手放せなくなる。',
    en: 'So many characters, and each season is harder to put down.',
    tr: 'Karakter çok, her sezon daha bırakılmaz.',
  },
  {
    ad: 'minh.phim', dil: 'vi', ulke: 'Vietnam',
    renk: [218, 37, 29], tur: 'tv', tmdb: 71446,
    bio: 'Xem phim nhiều quá vẫn bắt đầu bộ mới.',
    post: 'Kế hoạch trông bất khả thi mà vẫn không tắt nổi.',
    en: 'The plan looks impossible, yet you cannot switch it off.',
    tr: 'Plan imkânsız duruyor, yine de kapatamıyorsun.',
  },
  {
    ad: 'jiwon.drama', dil: 'ko', ulke: 'Güney Kore',
    renk: [0, 52, 120], tur: 'tv', tmdb: 1399,
    bio: '드라마를 너무 많이 봐도 또 새 작품을 시작해요.',
    post: '사람이 너무 많은데도 시즌이 갈수록 더 붙어 있게 돼요.',
    en: 'Too many people, and you stick more with every season.',
    tr: 'İnsan çok, her sezon daha yapışıyorsun.',
  },
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

async function ceviriYaz(ozetKaynak, dil, metin) {
  if (!metin || !String(metin).trim()) return;
  await havuz.query(
    `INSERT INTO metin_cevirileri (ozet, dil, metin)
     VALUES (md5(btrim($1)), $2, $3)
     ON CONFLICT (ozet, dil) DO NOTHING`,
    [ozetKaynak, dil, metin],
  );
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

    const dosya = `avatar${id}-intl.png`;
    fs.writeFileSync(path.join(avatarDizin, dosya), karePng(...t.renk));
    await havuz.query(
      'UPDATE kullanicilar SET avatar=$1 WHERE id=$2',
      [`/avatarlar/${dosya}`, id],
    );

    await havuz.query(
      `INSERT INTO takipler (takip_eden_id, takip_edilen_id)
       SELECT $1::int, $2::int WHERE $1::int <> $2::int
       ON CONFLICT DO NOTHING`,
      [id, RESMI_ID],
    );

    const postVar = await havuz.query(
      `SELECT id FROM yorumlar
        WHERE kullanici_id=$1 AND ust_id IS NULL AND md5(btrim(metin))=md5(btrim($2))
        LIMIT 1`,
      [id, t.post],
    );
    if (!postVar.rows.length) {
      const tarih = new Date(Date.now() - (TOHUM.length - i) * 9 * 3600 * 1000);
      await havuz.query(
        `INSERT INTO yorumlar
           (kullanici_id, tur, tmdb_id, metin, medya, spoiler, kaynak_dil, tarih)
         VALUES ($1,$2,$3,$4,'{}',false,$5,$6)`,
        [id, t.tur, t.tmdb, t.post, t.dil, tarih],
      );
    }
    await ceviriYaz(t.post, 'en', t.en);
    await ceviriYaz(t.post, 'tr', t.tr);
    if (t.dil !== 'en' && t.dil !== 'tr') {
      await ceviriYaz(t.post, t.dil, t.post);
    }
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
