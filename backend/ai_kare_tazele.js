// dizi.jpg AI karelerini TEKRARDAN ARINDIRMA + TAMAMLAMA aracı.
//
// Neden gerekli: TMDB bir yapımın aynı görselini farklı kırpım/renk
// varyantlarıyla ayrı backdrop olarak sunuyor. Sadece "en çok oylanan 10"
// alınınca aynı kare birkaç kez giriyor. Byte olarak farklı oldukları için
// md5 yakalamaz; ALGISAL parmak izi (dHash) gerekir.
//
// dHash'i ffmpeg üretir ve ffmpeg KONTEYNERDE YOK, HOST'ta var. Bu yüzden
// akış üç adımlıdır (hepsi sunucuda):
//
//   1) docker exec dizijpg-api node ai_kare_tazele.js aday
//        → eksik kareli yorumlar için TMDB'nin KULLANILMAMIŞ backdrop'larını
//          indirir (henüz yoruma eklemez), /veri/aday.json'a yazar.
//   2) bash dhash.sh > /root/dhash.txt && cp /root/dhash.txt <volume>/dhash.txt
//        → tüm karelerin (eski + aday) parmak izini üretir.
//   3) docker exec dizijpg-api node ai_kare_tazele.js yerlestir
//        → adaylardan tekrar OLMAYANLARI yoruma ekler (10'a kadar),
//          kullanılmayan aday dosyalarını siler.
//
// Sadece temizlik için: `node ai_kare_tazele.js temizle <esik>` — mevcut
// karelerden birbirine benzeyenleri düşürür (eşik: dHash Hamming mesafesi).
// ÖLÇÜLDÜ (2026-08-01, gözle doğrulandı): 0-11 arası çiftler AYNI görselin
// varyantı, 12'de farklı görseller yakalanmaya başlıyor → güvenli eşik 10.
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import pg from 'pg';

const { DATABASE_URL, TMDB_TOKEN, MEDYA_DIZIN } = process.env;
const havuz = new pg.Pool({ connectionString: DATABASE_URL });
const medyaDizin = MEDYA_DIZIN || './medya';
const HASH_DOSYA = path.join(medyaDizin, '..', 'dhash.txt');
const ADAY_DOSYA = path.join(medyaDizin, '..', 'aday.json');
const AI_ID = 51;
const HEDEF = 10;      // yorum başına istenen kare
const ESIK = 10;       // bu mesafenin altı "aynı görsel" sayılır
const KARE_BOYUT = 'w1280';

const komut = process.argv[2] || 'yerlestir';

async function tmdb(yol) {
  for (let d = 0; d < 3; d++) {
    const c = await fetch(`https://api.themoviedb.org/3${yol}`, {
      headers: { Authorization: `Bearer ${TMDB_TOKEN}` },
    });
    if (c.status === 429) { await new Promise((r) => setTimeout(r, 1500)); continue; }
    if (!c.ok) throw new Error(`TMDB ${c.status}`);
    return c.json();
  }
  throw new Error('TMDB 429');
}

// ai_tohum.js ile AYNI sıralama: yazısızlar önce, her grup oy sayısına göre.
// İlk HEDEF tanesi zaten indirilmişti; tamamlama bunlardan SONRASINI dener.
function sirali(veri) {
  const hepsi = (veri.backdrops || []).slice()
    .sort((a, b) => (b.vote_count || 0) - (a.vote_count || 0));
  return [...hepsi.filter((b) => !b.iso_639_1), ...hepsi.filter((b) => b.iso_639_1)];
}

function hashOku() {
  const h = new Map();
  if (!fs.existsSync(HASH_DOSYA)) return h;
  for (const s of fs.readFileSync(HASH_DOSYA, 'utf8').split('\n')) {
    const [a, b] = s.trim().split(/\s+/);
    if (b && /^[0-9a-f]{16}$/.test(a)) h.set(b, BigInt('0x' + a));
  }
  return h;
}

const mesafe = (a, b) => {
  let x = a ^ b, n = 0;
  while (x) { n += Number(x & 1n); x >>= 1n; }
  return n;
};

async function indir(url, hedef) {
  const c = await fetch(url);
  if (!c.ok) throw new Error(`indirme ${c.status}`);
  fs.writeFileSync(hedef, Buffer.from(await c.arrayBuffer()));
}

const aiYorumlari = () => havuz.query(
  'SELECT id, tur, tmdb_id, medya FROM yorumlar WHERE kullanici_id=$1 ORDER BY id', [AI_ID]);

if (komut === 'temizle') {
  const esik = parseInt(process.argv[3], 10) || ESIK;
  const hash = hashOku();
  const { rows } = await aiYorumlari();
  let atilan = 0, guncel = 0;
  for (const r of rows) {
    const tut = [], at = [];
    for (const m of r.medya || []) {
      const h = hash.get(path.basename(m));
      if (h === undefined) { tut.push(m); continue; }
      const benzer = tut.some((t) => {
        const th = hash.get(path.basename(t));
        return th !== undefined && mesafe(h, th) <= esik;
      });
      (benzer ? at : tut).push(m);
    }
    if (!at.length) continue;
    await havuz.query('UPDATE yorumlar SET medya=$1 WHERE id=$2', [tut, r.id]);
    for (const m of at) fs.unlink(path.join(medyaDizin, path.basename(m)), () => {});
    atilan += at.length; guncel++;
  }
  console.log(`temizlendi: ${atilan} kare atıldı, ${guncel} yorum güncellendi`);
} else if (komut === 'aday') {
  const { rows } = await aiYorumlari();
  const eksik = rows.filter((r) => (r.medya || []).length < HEDEF);
  console.log(`eksik kareli yorum: ${eksik.length}`);
  const adaylar = {}; // yorum_id → [/medya/... ]
  let sayac = 0;
  for (const r of eksik) {
    try {
      const veri = await tmdb(`/${r.tur}/${r.tmdb_id}/images`);
      const liste = sirali(veri);
      const gerek = HEDEF - (r.medya || []).length;
      // Zaten ilk HEDEF tanesi denenmişti; sonrakilerden 2 katı aday çek
      // (bir kısmı yine tekrar çıkacağı için fazladan alıyoruz).
      const secim = liste.slice(HEDEF, HEDEF + gerek * 2);
      if (!secim.length) continue;
      const yollar = (await Promise.all(secim.map(async (b) => {
        const dosya = `m${AI_ID}-${crypto.randomBytes(8).toString('hex')}.jpg`;
        try {
          await indir(`https://image.tmdb.org/t/p/${KARE_BOYUT}${b.file_path}`,
            path.join(medyaDizin, dosya));
          return `/medya/${dosya}`;
        } catch { return null; }
      }))).filter(Boolean);
      if (yollar.length) { adaylar[r.id] = yollar; sayac += yollar.length; }
    } catch (e) {
      console.error(`! ${r.tur}/${r.tmdb_id}: ${e.message}`);
    }
  }
  fs.writeFileSync(ADAY_DOSYA, JSON.stringify(adaylar));
  console.log(`aday indirildi: ${sayac} kare, ${Object.keys(adaylar).length} yorum için`);
  console.log('SIRADAKİ: host üzerinde dhash.sh çalıştır, sonra `yerlestir`');
} else if (komut === 'yerlestir') {
  const hash = hashOku();
  const adaylar = JSON.parse(fs.readFileSync(ADAY_DOSYA, 'utf8'));
  const { rows } = await aiYorumlari();
  let eklenen = 0, silinen = 0, guncel = 0;
  for (const r of rows) {
    const aday = adaylar[r.id];
    if (!aday?.length) continue;
    const tut = [...(r.medya || [])];
    const kullanilmayan = [];
    for (const m of aday) {
      if (tut.length >= HEDEF) { kullanilmayan.push(m); continue; }
      const h = hash.get(path.basename(m));
      if (h === undefined) { kullanilmayan.push(m); continue; }
      const benzer = tut.some((t) => {
        const th = hash.get(path.basename(t));
        return th !== undefined && mesafe(h, th) <= ESIK;
      });
      if (benzer) kullanilmayan.push(m); else tut.push(m);
    }
    if (tut.length !== (r.medya || []).length) {
      await havuz.query('UPDATE yorumlar SET medya=$1 WHERE id=$2', [tut, r.id]);
      eklenen += tut.length - (r.medya || []).length;
      guncel++;
    }
    for (const m of kullanilmayan) {
      fs.unlink(path.join(medyaDizin, path.basename(m)), () => {});
      silinen++;
    }
  }
  fs.unlinkSync(ADAY_DOSYA);
  console.log(`yerleştirildi: +${eklenen} kare (${guncel} yorum), ${silinen} tekrar aday silindi`);
}
await havuz.end();
