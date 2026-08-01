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
import { spawn } from 'child_process';
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

// --- ALGISAL TEKRAR KONTROLÜ ---------------------------------------------
// TMDB aynı görseli farklı kırpım/renk varyantlarıyla AYRI backdrop olarak
// sunuyor; dosyalar byte olarak farklı olduğu için md5 yakalamaz. ffmpeg ile
// dHash üretip (9x8 gri → komşu piksel karşılaştırması → 64 bit) Hamming
// mesafesi ESIK'in altındakileri aynı görsel sayıyoruz.
// EŞİK gözle kalibre edildi (2026-08-01): 0-11 arası çiftler hep aynı
// görselin varyantı çıktı, 12'de farklı görseller yakalanmaya başladı
// (Schindler'de iki ayrı afiş) → bir basamak emniyetle 10.
const TEKRAR_ESIK = 10;

function dhash(dosyaYolu) {
  return new Promise((coz) => {
    const p = spawn('ffmpeg', ['-v', 'error', '-i', dosyaYolu,
      '-vf', 'scale=9:8,format=gray', '-f', 'rawvideo', '-']);
    const parcalar = [];
    p.stdout.on('data', (d) => parcalar.push(d));
    p.on('error', () => coz(null));
    p.on('close', () => {
      const b = Buffer.concat(parcalar);
      if (b.length < 72) return coz(null);
      let h = 0n;
      for (let y = 0; y < 8; y++) {
        for (let x = 0; x < 8; x++) {
          h = (h << 1n) | (b[y * 9 + x] > b[y * 9 + x + 1] ? 1n : 0n);
        }
      }
      coz(h);
    });
  });
}

const mesafe = (a, b) => {
  let x = a ^ b, n = 0;
  while (x) { n += Number(x & 1n); x >>= 1n; }
  return n;
};

async function indirVeHashle(kullaniciId, b) {
  const dosya = `m${kullaniciId}-${crypto.randomBytes(8).toString('hex')}.jpg`;
  const tamYol = path.join(medyaDizin, dosya);
  try {
    await indir(`https://image.tmdb.org/t/p/${KARE_BOYUT}${b.file_path}`, tamYol);
  } catch {
    return null;
  }
  const h = await dhash(tamYol);
  return { yol: `/medya/${dosya}`, tamYol, hash: h };
}

// Yapımın en oylanan sahne karelerinden BİRBİRİNDEN FARKLI olan KARE_SAYISI
// tanesini indirir. Aday havuzu hedefin 3 katıdır: tekrar çıkanlar elenince
// yine 10'a ulaşılabilsin. Elenen dosyalar hemen silinir.
// [mevcut] verilirse (eksik/kirli yorumu onarırken) yeni kareler onlara karşı
// da tekrar kontrolünden geçer.
async function kareIndir(kullaniciId, tur, tmdbId, mevcut = []) {
  const veri = await tmdb(`/${tur}/${tmdbId}/images`);
  const hepsi = (veri.backdrops || []).slice()
    .sort((a, b) => (b.vote_count || 0) - (a.vote_count || 0));
  const yazisiz = hepsi.filter((b) => !b.iso_639_1);
  let havuz = [...yazisiz, ...hepsi.filter((b) => b.iso_639_1)]
    .slice(0, KARE_SAYISI * 3);
  if (!havuz.length && veri.posters?.length) havuz = [veri.posters[0]];

  // Elde tutulan karelerin hash'leri (onarım durumunda dolu gelir)
  const tutulanHash = (await Promise.all(mevcut.map(
    (m) => dhash(path.join(medyaDizin, path.basename(m)))))).filter((h) => h !== null);
  const secilen = [...mevcut];

  // 10'arlı öbekler halinde indir: hedefe ulaşınca kalan adaylar hiç inmez.
  for (let i = 0; i < havuz.length && secilen.length < KARE_SAYISI; i += KARE_SAYISI) {
    const obek = havuz.slice(i, i + KARE_SAYISI);
    const inen = (await Promise.all(
      obek.map((b) => indirVeHashle(kullaniciId, b)))).filter(Boolean);
    for (const k of inen) {
      const tekrar = k.hash === null
        ? false // hash alınamadıysa eleme, kareyi kaybetme
        : tutulanHash.some((t) => mesafe(t, k.hash) <= TEKRAR_ESIK);
      if (tekrar || secilen.length >= KARE_SAYISI) {
        fs.unlink(k.tamYol, () => {});
        continue;
      }
      if (k.hash !== null) tutulanHash.push(k.hash);
      secilen.push(k.yol);
    }
  }
  return secilen;
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
  // Tarihler geriye doğru eşit aralıkla yayılır (hepsi aynı ana yığılmasın;
  // hesap aylardır paylaşıyormuş gibi görünsün). Aralık listenin boyuna göre
  // ölçeklenir: toplam yayılım ~60 gün.
  const aralikMs = Math.max(5, Math.round(60 * 24 * 60 / sirali.length)) * 60_000;
  let eklendi = 0, tazelendi = 0, atlandi = 0, hatali = 0;
  for (let i = 0; i < sirali.length; i++) {
    const v = sirali[i];
    try {
      // METİN de eşleşmeli: AI hesabı aynı yapıma başka gönderiler de
      // yapabiliyor (ör. Instagram'dan aktarılanlar). Yalnız tür+tmdb_id ile
      // arayınca betik onları kendi tanıtım yorumu sanıp medyasını bozuyordu.
      const mevcut = await havuz.query(
        `SELECT id, medya FROM yorumlar
         WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3 AND sezon IS NULL
           AND btrim(metin) = btrim($4)`,
        [aiId, v.tur, v.tmdb_id, v.tr]);
      if (mevcut.rows.length) {
        // Var olan yorum: önce KENDİ kareleri tekrar açısından denetlenir
        // (eski koşularda tekrar süzgeci yoktu), sonra eksik kalan sayı
        // TMDB'nin kullanılmamış karelerinden tamamlanır.
        const y = mevcut.rows[0];
        const eski = y.medya || [];
        // Hash'ler PARALEL üretilir (2400 yorum × 10 kare seri hashlenirse
        // yalnız denetim yarım saati bulur); karşılaştırma sırayla yapılır.
        const hashlar = await Promise.all(eski.map(
          (m) => dhash(path.join(medyaDizin, path.basename(m)))));
        const tut = [], at = [];
        const tutHash = [];
        eski.forEach((m, k) => {
          const h = hashlar[k];
          if (h === null) { tut.push(m); return; } // okunamadıysa dokunma
          if (tutHash.some((t) => mesafe(t, h) <= TEKRAR_ESIK)) { at.push(m); return; }
          tutHash.push(h);
          tut.push(m);
        });
        if (!at.length && tut.length >= KARE_SAYISI) { atlandi++; continue; }
        // Tekrarlar atıldı; kalan boşluğu yeni (farklı) karelerle doldur
        const medya = tut.length >= KARE_SAYISI
          ? tut
          : await kareIndir(aiId, v.tur, v.tmdb_id, tut);
        if (medya.length !== eski.length || at.length) {
          await havuz.query('UPDATE yorumlar SET medya=$1 WHERE id=$2',
            [medya, y.id]);
          for (const m of at) {
            fs.unlink(path.join(medyaDizin, path.basename(m)), () => {});
          }
          tazelendi++;
          console.log(`~ ${v.tur} ${v.ad} (${eski.length} → ${medya.length} kare, ${at.length} tekrar atıldı)`);
        } else atlandi++;
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
