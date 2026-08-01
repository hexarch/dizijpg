#!/usr/bin/env node
// Instagram hesabının TÜM gönderilerini dizi.jpg'ye aktarır (içerik üreticisi
// iş birlikleri için; thelostvibe0 ve imax_archives böyle aktarıldı).
//
// insta_kopru.mjs tek gönderi içindir; bu araç toplu aktarım yapar:
//   1) Gönderileri listeler (gallery-dl -j, indirmeden)
//   2) Açıklamadan yapım adı + yılı çıkarıp TMDB'de eşleştirir
//   3) Eşleşenlerin medyasını indirip hedef hesaptan gönderi olarak paylaşır
//   4) Gönderi tarihlerini Instagram'daki ÖZGÜN tarihlere çeker (hepsi "şimdi"
//      görünüp akışı basmasın diye) — sunucuda tek SQL ile.
//
// BU MAKİNEDE çalışmalı: Instagram veri merkezi IP'lerini engelliyor.
// Çerezler insta_kopru.mjs ile aynı yerden gelir (instaloader oturumu).
//
// KULLANIM:
//   node araclar/insta_aktar.mjs --ig imax_archives --hesap imax_archives --kuru
//     → yalnız eşleştirme raporu (hiçbir şey paylaşılmaz)
//   node araclar/insta_aktar.mjs --ig imax_archives --hesap imax_archives
//     → eşleşenleri paylaşır
import fs from 'fs';
import os from 'os';
import path from 'path';
import { execFileSync, spawnSync } from 'child_process';

const API = process.env.DIZIJPG_API || 'https://dizijpg.com/api';
const AYAR_DIZIN = path.join(os.homedir(), '.config', 'dizijpg');
const CEREZ_DOSYA = path.join(AYAR_DIZIN, 'ig_cookies.txt');
const IG_OTURUM_HESAP = process.env.IG_HESAP || '42.students';
const GECICI = path.join(os.tmpdir(), 'insta_aktar');
const EN_FAZLA_MEDYA = 10;

const arg = (ad, vars = true) => {
  const i = process.argv.indexOf(`--${ad}`);
  if (i < 0) return vars ? null : false;
  return vars ? process.argv[i + 1] : true;
};
const IG = arg('ig');
const HESAP = arg('hesap');
const KURU = arg('kuru', false);
const LIMIT = parseInt(arg('limit'), 10) || 0;
if (!IG || !HESAP) {
  console.error('Kullanım: --ig <instagram_kullanici> --hesap <dizijpg_kullanici_adi> [--kuru] [--limit N]');
  process.exit(1);
}

function cerezleriHazirla() {
  const oturum = path.join(os.homedir(), '.config', 'instaloader', `session-${IG_OTURUM_HESAP}`);
  if (!fs.existsSync(oturum)) { console.error(`instaloader oturumu yok: ${oturum}`); process.exit(1); }
  const betik = `
import pickle, sys
d = pickle.load(open(sys.argv[1], 'rb'))
s = ['# Netscape HTTP Cookie File']
for k, v in d.items():
    s.append('\\t'.join(['.instagram.com','TRUE','/','TRUE','2000000000',k,str(v)]))
open(sys.argv[2],'w').write('\\n'.join(s)+'\\n')
`;
  fs.mkdirSync(AYAR_DIZIN, { recursive: true });
  execFileSync('python3', ['-c', betik, oturum, CEREZ_DOSYA]);
}

async function api(yol, { yontem = 'GET', token, govde, ham, tip } = {}) {
  const baslik = {};
  if (token) baslik.Authorization = `Bearer ${token}`;
  let icerik;
  if (ham) { baslik['Content-Type'] = tip; icerik = ham; }
  else if (govde) { baslik['Content-Type'] = 'application/json'; icerik = JSON.stringify(govde); }
  const c = await fetch(`${API}${yol}`, { method: yontem, headers: baslik, body: icerik });
  const m = await c.text();
  let v; try { v = JSON.parse(m); } catch { v = m; }
  if (!c.ok) throw new Error(`${yontem} ${yol} → ${c.status} ${JSON.stringify(v).slice(0, 160)}`);
  return v;
}

// Gönderi listesi (indirmeden): [{kod, aciklama, tarih}]
function gonderileriListele() {
  const s = spawnSync('gallery-dl', ['--cookies', CEREZ_DOSYA, '-j',
    `https://www.instagram.com/${IG}/posts/`], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  const j = JSON.parse(s.stdout);
  const harita = new Map();
  for (const satir of j) {
    const m = satir[2];
    if (!m?.post_shortcode || harita.has(m.post_shortcode)) continue;
    harita.set(m.post_shortcode, {
      kod: m.post_shortcode,
      aciklama: m.description || '',
      tarih: m.date || null,
    });
  }
  return [...harita.values()];
}

// Açıklamanın ilk satırından yapım adı + yılı: "🎬 **The Batman (2022)**",
// "🎥 Avengers: Doomsday (2026) :" gibi biçimlerin hepsini karşılar.
function baslikCoz(aciklama) {
  const ilk = (aciklama || '').split('\n').find((s) => s.trim()) || '';
  let temiz = ilk
    .replace(/[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\uFE0F]/gu, ' ') // emoji
    .replace(/\*+/g, ' ')
    .replace(/\|.*$/, ' ') // "| 4K Clip" gibi kuyruklar
    .trim();
  const ym = temiz.match(/\((\d{4})\)/);
  const yil = ym ? parseInt(ym[1], 10) : null;
  temiz = temiz.replace(/\(\d{4}\)/, ' ');
  // "Season 3" eki: yapım DİZİdir, ad sezondan öncesidir. Buradaki yıl
  // SEZONun yılıdır (dizinin ilk yayın yılı değil) → dizilerde yıl puanlamaya
  // katılmaz, yoksa doğru dizi yıl farkı yüzünden eleniyor.
  const sm = temiz.match(/[\s:\u2013\u2014-]+se(?:ason|zon)\s*\d+/i);
  const dizi = !!sm;
  if (sm) temiz = temiz.slice(0, sm.index);
  temiz = temiz.replace(/[\s:\uFF1A\u2013\u2014-]+$/, '').trim();
  return temiz ? { ad: temiz.slice(0, 80), yil, dizi } : null;
}

// TMDB'de ara (kendi proxy'miz üzerinden — önbellekli). Yıl tutuyorsa öncelik.
async function tmdbEslestir(ad, yil, dizi = false) {
  const q = encodeURIComponent(ad);
  const sonuc = [];
  for (const tur of (dizi ? ['tv'] : ['movie', 'tv'])) {
    try {
      const v = await api(`/tmdb/search/${tur}?query=${q}&language=tr-TR`);
      for (const r of (v.results || []).slice(0, 5)) {
        const rAd = tur === 'movie' ? r.title : r.name;
        const rOrj = tur === 'movie' ? r.original_title : r.original_name;
        const rYil = parseInt(((tur === 'movie' ? r.release_date : r.first_air_date) || '').slice(0, 4), 10);
        sonuc.push({ tur, id: r.id, ad: rAd, orijinal: rOrj, yil: rYil, oy: r.vote_count || 0 });
      }
    } catch { /* bir tür başarısızsa diğeriyle devam */ }
  }
  if (!sonuc.length) return null;
  const norm = (s) => String(s || '').toLowerCase().replace(/[^a-z0-9]/g, '');
  const hedef = norm(ad);
  const puan = (r) => {
    let p = 0;
    if (norm(r.ad) === hedef || norm(r.orijinal) === hedef) p += 100;
    else if (norm(r.ad).startsWith(hedef) || norm(r.orijinal).startsWith(hedef)) p += 40;
    // Dizilerde başlıktaki yıl SEZONun yılı olduğu için karşılaştırılmaz.
    if (!dizi && yil && r.yil) p += Math.abs(r.yil - yil) <= 1 ? 50 : -30;
    return p + Math.min(r.oy, 5000) / 1000;
  };
  const en = sonuc.slice().sort((a, b) => puan(b) - puan(a))[0];
  // Ad hiç tutmuyorsa eşleşme sayma (yanlış yapıma gönderi düşmesin)
  if (puan(en) < 40) return null;
  // Yıl da yoksa elimizde tek dayanak ad; aynı adlı niş yapımlar yüzünden
  // yanlış eşleşme oluyor (ör. "Ironman" → alakasız 2021 belgeseli).
  // Bu durumda tanınırlık şartı koy.
  if (!yil && en.oy < 200) return null;
  return { ...en, skor: Math.round(puan(en)) };
}

function medyaIndir(kod) {
  const hedef = path.join(GECICI, kod);
  fs.rmSync(hedef, { recursive: true, force: true });
  fs.mkdirSync(hedef, { recursive: true });
  spawnSync('gallery-dl', ['--cookies', CEREZ_DOSYA, '-D', hedef, '--no-part',
    `https://www.instagram.com/p/${kod}/`], { encoding: 'utf8' });
  const dosyalar = fs.existsSync(hedef)
    ? fs.readdirSync(hedef).filter((f) => /\.(jpg|jpeg|png|webp|mp4|webm)$/i.test(f)).sort()
    : [];
  return { dizin: hedef, dosyalar: dosyalar.slice(0, EN_FAZLA_MEDYA) };
}

const MIME = { jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png',
  webp: 'image/webp', mp4: 'video/mp4', webm: 'video/webm' };
// Sunucu sınırı 30MB (nginx 35m). Instagram videoları 40-70MB olabiliyor →
// hedef boyuta göre bit hızı hesaplanıp yeniden kodlanır (CRF ile boyut
// öngörülemiyor, hedef bit hızı öngörülebiliyor).
const SINIR_BAYT = 28 * 1024 * 1024;
const HEDEF_BAYT = 26 * 1024 * 1024;

function videoKucult(tamYol) {
  const sure = parseFloat(execFileSync('ffprobe', ['-v', 'error',
    '-show_entries', 'format=duration', '-of', 'csv=p=0', tamYol], { encoding: 'utf8' }).trim());
  if (!Number.isFinite(sure) || sure <= 0) return null;
  const vb = Math.max(300, Math.floor((HEDEF_BAYT * 8 / sure) / 1000) - 128);
  const cikti = tamYol.replace(/\.[^.]+$/, '') + '_kucuk.mp4';
  const s = spawnSync('ffmpeg', ['-v', 'error', '-y', '-i', tamYol,
    '-vf', "scale='min(1280,iw)':-2", '-c:v', 'libx264', '-preset', 'veryfast',
    '-b:v', `${vb}k`, '-maxrate', `${Math.floor(vb * 1.5)}k`, '-bufsize', `${vb * 2}k`,
    '-c:a', 'aac', '-b:a', '128k', cikti], { encoding: 'utf8' });
  if (s.status !== 0 || !fs.existsSync(cikti)) return null;
  return cikti;
}

async function medyaYukle(token, tamYol) {
  let yol = tamYol;
  if (fs.statSync(yol).size > SINIR_BAYT && /\.(mp4|webm|mov)$/i.test(yol)) {
    const k = videoKucult(yol);
    if (k) {
      console.log(`  (video küçültüldü: ${(fs.statSync(tamYol).size / 1048576).toFixed(0)}MB → ${(fs.statSync(k).size / 1048576).toFixed(0)}MB)`);
      yol = k;
    }
  }
  const uz = path.extname(yol).slice(1).toLowerCase();
  const c = await api('/medya', { yontem: 'POST', token,
    ham: fs.readFileSync(yol), tip: MIME[uz] || 'application/octet-stream' });
  return c.yol;
}

// Gönderi metni: Instagram açıklaması (1000 karakter sınırına kırpılır) +
// kaynak atfı. Markdown yıldızları temizlenir, satır yapısı korunur.
function metinKur(aciklama, kod) {
  let g = (aciklama || '').replace(/\*\*/g, '').trim();
  const atif = `Instagram: @${IG} (instagram.com/p/${kod})`;
  const yer = 1000 - atif.length - 2;
  if (g.length > yer) g = `${g.slice(0, yer - 1).trimEnd()}…`;
  return g ? `${g}\n\n${atif}` : atif;
}

// ---- akış ----
cerezleriHazirla();
console.log(`@${IG} gönderileri listeleniyor...`);
let gonderiler = gonderileriListele();
if (LIMIT) gonderiler = gonderiler.slice(0, LIMIT);
console.log(`${gonderiler.length} gönderi bulundu.\n`);

const eslesenler = [], eslesmeyenler = [];
for (const g of gonderiler) {
  const b = baslikCoz(g.aciklama);
  const e = b ? await tmdbEslestir(b.ad, b.yil, b.dizi) : null;
  if (e) eslesenler.push({ ...g, hedef: e, cozulen: b });
  else eslesmeyenler.push({ ...g, cozulen: b });
}
console.log(`EŞLEŞEN (${eslesenler.length}):`);
for (const e of eslesenler) {
  console.log(`  ${e.kod}  "${e.cozulen.ad}" (${e.cozulen.yil ?? '?'}) → ${e.hedef.tur}/${e.hedef.id} ${e.hedef.ad} (${e.hedef.yil}) [skor ${e.hedef.skor}]`);
}
if (eslesmeyenler.length) {
  console.log(`\nEŞLEŞMEYEN (${eslesmeyenler.length}) — atlanacak:`);
  for (const e of eslesmeyenler) {
    console.log(`  ${e.kod}  ${e.cozulen ? `"${e.cozulen.ad}"` : '(başlık çözülemedi)'}`);
  }
}
if (KURU) { console.log('\n[kuru koşu] Hiçbir şey paylaşılmadı.'); process.exit(0); }

const sifreDosya = path.join(AYAR_DIZIN, `${HESAP}_sifre`);
if (!fs.existsSync(sifreDosya)) {
  console.error(`\n${HESAP} şifresi yok: ${sifreDosya}`);
  process.exit(1);
}
const giris = await api('/auth/giris', { yontem: 'POST',
  govde: { email: `${HESAP}@dizijpg.com`, sifre: fs.readFileSync(sifreDosya, 'utf8').trim() } });
const token = giris.token;

// MÜKERRER KORUMASI: metindeki "instagram.com/p/<kod>" atfı, o gönderinin
// daha önce aktarılıp aktarılmadığının kaydıdır. Araç yarıda kalırsa (büyük
// video, ağ hatası) yeniden çalıştırıldığında yalnız EKSİKLERİ tamamlar.
const mevcutKodlar = new Set();
try {
  const p = await api(`/profil/${HESAP}`);
  for (const y of p.yorumlar || []) {
    const m = (y.metin || '').match(/instagram\.com\/p\/([A-Za-z0-9_-]+)/);
    if (m) mevcutKodlar.add(m[1]);
  }
} catch { /* profil okunamazsa koruma yok; ilk kurulumda zaten boştur */ }
const yapilacak = eslesenler.filter((e) => !mevcutKodlar.has(e.kod));
if (mevcutKodlar.size) {
  console.log(`\nZaten aktarılmış: ${eslesenler.length - yapilacak.length} — atlanıyor.`);
}

console.log(`\n@${HESAP} olarak paylaşılıyor (${yapilacak.length})...`);
const tarihler = [];
let ok = 0;
for (const e of yapilacak) {
  try {
    const m = medyaIndir(e.kod);
    if (!m.dosyalar.length) { console.error(`! ${e.kod}: medya inmedi`); continue; }
    const yollar = [];
    for (const d of m.dosyalar) yollar.push(await medyaYukle(token, path.join(m.dizin, d)));
    const y = await api('/yorumlar', { yontem: 'POST', token, govde: {
      tur: e.hedef.tur, tmdb_id: e.hedef.id, metin: metinKur(e.aciklama, e.kod), medya: yollar,
    } });
    if (e.tarih) tarihler.push({ id: y.id, tarih: e.tarih });
    fs.rmSync(m.dizin, { recursive: true, force: true });
    console.log(`+ ${e.hedef.ad} (${yollar.length} medya)`);
    ok++;
  } catch (err) {
    console.error(`! ${e.kod}: ${err.message}`);
  }
}
console.log(`\n${ok} gönderi paylaşıldı.`);
if (tarihler.length) {
  const sql = `UPDATE yorumlar SET tarih = v.t::timestamptz FROM (VALUES ${
    tarihler.map((t) => `(${t.id}, '${t.tarih.replace(/'/g, '')}')`).join(',')
  }) AS v(id, t) WHERE yorumlar.id = v.id;`;
  fs.writeFileSync(path.join(GECICI, 'tarih.sql'), sql);
  console.log(`Özgün tarihler için SQL: ${path.join(GECICI, 'tarih.sql')}`);
}
