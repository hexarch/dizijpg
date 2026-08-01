#!/usr/bin/env node
// dizi.jpg ← Instagram köprüsü
// ---------------------------------------------------------------------------
// AKIŞ: dizi.jpg uygulamasının sohbetinden @dizi.jpg.ai hesabına bir Instagram
// bağlantısı yollarsın; bu betik onu indirip AYNI hesaptan gönderi olarak
// paylaşır ve sana "paylaşıldı" yanıtı döner.
//
// Gönderi hangi dizi/filme bağlanacak? dizi.jpg'de her gönderi bir yapıma
// aittir. Bu yüzden mesaja sohbetteki "dizi/film kartı"nı da iliştir
// (sohbette içerik seçme düğmesi). Kart aynı mesajda yoksa, o sohbetteki EN
// SON kart kullanılır; hiç kart yoksa betik sana sorar ve gönderiyi atlar.
//
// NEDEN BU MAKİNEDE ÇALIŞIYOR: Instagram veri merkezi IP'lerini engelliyor.
// İndirme yalnızca buradaki ev bağlantısı + kayıtlı instaloader oturumuyla
// çalışıyor (gallery-dl'e o oturumun çerezleri aktarılıyor). Sunucuda
// çalıştırmayı deneme; login sayfasına yönlenir.
//
// KULLANIM:
//   node araclar/insta_kopru.mjs           → tek tur (bekleyenleri işler)
//   node araclar/insta_kopru.mjs --izle    → 60 sn'de bir sürekli bakar
//
// GEREKENLER: instaloader oturumu (~/.config/instaloader/session-<hesap>),
// gallery-dl, ve bot şifresi (AI_SIFRE ortam değişkeni ya da
// ~/.config/dizijpg/ai_sifre dosyası).
import fs from 'fs';
import os from 'os';
import path from 'path';
import { execFileSync, spawnSync } from 'child_process';

const API = process.env.DIZIJPG_API || 'https://dizijpg.com/api';
const BOT_EMAIL = process.env.AI_EMAIL || 'ai@dizijpg.com';
const IG_HESAP = process.env.IG_HESAP || '42.students';
// Yalnız bu kullanıcıların mesajları işlenir (başkası AI'a gönderi yaptıramasın)
const IZINLILER = (process.env.IZINLILER || 'alcelik').split(',').map((s) => s.trim());
const AYAR_DIZIN = path.join(os.homedir(), '.config', 'dizijpg');
const DURUM_DOSYA = path.join(AYAR_DIZIN, 'insta_kopru_durum.json');
const CEREZ_DOSYA = path.join(AYAR_DIZIN, 'ig_cookies.txt');
const GECICI = path.join(os.tmpdir(), 'insta_kopru');
// Sondaki eğik çizgi ve ?igsh=... gibi ekler de yutulur; yoksa metinde
// bağlantıdan artakalan çöp kalıyor.
const IG_DESEN = /https?:\/\/(?:www\.)?instagram\.com\/(?:p|reel|tv)\/([A-Za-z0-9_-]+)\/?(?:\?\S*)?/i;
const EN_FAZLA_MEDYA = 10; // sunucu sınırı: gönderi başına 10 medya

function sifreOku() {
  if (process.env.AI_SIFRE) return process.env.AI_SIFRE;
  const dosya = path.join(AYAR_DIZIN, 'ai_sifre');
  if (fs.existsSync(dosya)) return fs.readFileSync(dosya, 'utf8').trim();
  console.error(`Bot şifresi yok. AI_SIFRE ortam değişkenini ver ya da ${dosya} dosyasına yaz.`);
  process.exit(1);
}

const durumOku = () => {
  try { return JSON.parse(fs.readFileSync(DURUM_DOSYA, 'utf8')); }
  catch { return { islenen: [] }; }
};
const durumYaz = (d) => {
  fs.mkdirSync(AYAR_DIZIN, { recursive: true });
  fs.writeFileSync(DURUM_DOSYA, JSON.stringify(d));
};

// instaloader oturumundaki çerezleri gallery-dl'in anladığı biçime çevirir.
// Her turda yeniden yazılır: instaloader oturumu tazeledikçe güncel kalsın.
function cerezleriHazirla() {
  const oturum = path.join(os.homedir(), '.config', 'instaloader', `session-${IG_HESAP}`);
  if (!fs.existsSync(oturum)) {
    console.error(`instaloader oturumu yok: ${oturum}\n` +
      `Çözüm: instaloader --login ${IG_HESAP}`);
    process.exit(1);
  }
  const betik = `
import pickle, sys
d = pickle.load(open(sys.argv[1], 'rb'))
satirlar = ['# Netscape HTTP Cookie File']
for k, v in d.items():
    satirlar.append('\\t'.join(['.instagram.com', 'TRUE', '/', 'TRUE', '2000000000', k, str(v)]))
open(sys.argv[2], 'w').write('\\n'.join(satirlar) + '\\n')
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
  const metin = await c.text();
  let veri; try { veri = JSON.parse(metin); } catch { veri = metin; }
  if (!c.ok) throw new Error(`${yontem} ${yol} → ${c.status} ${JSON.stringify(veri).slice(0, 200)}`);
  return veri;
}

// Instagram gönderisini indirir → { dosyalar, yaratici, aciklama }
// Çoklu (karusel) gönderide TÜM karolar iner (sunucu sınırına kadar).
// Bağlantıdaki ?img_index=N yalnızca linki kopyalarken açık olan karoyu
// gösterir, "sadece bunu istiyorum" demek DEĞİLDİR — bu yüzden yok sayılır.
function instaIndir(kisaKod) {
  const hedef = path.join(GECICI, kisaKod);
  fs.rmSync(hedef, { recursive: true, force: true });
  fs.mkdirSync(hedef, { recursive: true });
  const s = spawnSync('gallery-dl', [
    '--cookies', CEREZ_DOSYA, '-D', hedef, '--no-part', '--write-metadata',
    `https://www.instagram.com/p/${kisaKod}/`,
  ], { encoding: 'utf8' });
  const dosyalar = fs.existsSync(hedef)
    ? fs.readdirSync(hedef).filter((f) => /\.(jpg|jpeg|png|webp|mp4|webm)$/i.test(f)).sort()
    : [];
  if (!dosyalar.length) {
    throw new Error(`indirilemedi: ${(s.stderr || '').split('\n').filter(Boolean).pop() || 'bilinmeyen hata'}`);
  }
  let yaratici = null, aciklama = '';
  const meta = fs.readdirSync(hedef).find((f) => f.endsWith('.json'));
  if (meta) {
    try {
      const m = JSON.parse(fs.readFileSync(path.join(hedef, meta), 'utf8'));
      yaratici = m.username || null;
      aciklama = m.description || '';
    } catch { /* metadata okunamazsa atfsız devam */ }
  }
  return { dizin: hedef, dosyalar: dosyalar.slice(0, EN_FAZLA_MEDYA), yaratici, aciklama };
}

const MIME = { jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png',
  webp: 'image/webp', mp4: 'video/mp4', webm: 'video/webm' };
// Sunucu sınırı 100MB: videolar ÖZGÜN kalitesinde yüklenir. Küçültme yalnız
// sınırı aşan devasa dosyalar için son çaredir (hedef bit hızıyla).
const SINIR_BAYT = 95 * 1024 * 1024;
const HEDEF_BAYT = 90 * 1024 * 1024;

function videoKucult(tamYol) {
  const sure = parseFloat(execFileSync('ffprobe', ['-v', 'error',
    '-show_entries', 'format=duration', '-of', 'csv=p=0', tamYol], { encoding: 'utf8' }).trim());
  if (!Number.isFinite(sure) || sure <= 0) return null;
  const vb = Math.max(300, Math.floor((HEDEF_BAYT * 8 / sure) / 1000) - 128);
  const cikti = tamYol.replace(/\.[^.]+$/, '') + '_kucuk.mp4';
  // Çözünürlük KORUNUR (yalnız 1920 üstü kaynak kırpılır); preset slow aynı bit
  // hızında daha iyi görüntü verir; +faststart moov atomunu başa alır (yoksa
  // tarayıcı dosyanın tamamını indirmeden oynatmaya başlayamıyor).
  const s = spawnSync('ffmpeg', ['-v', 'error', '-y', '-i', tamYol,
    '-vf', "scale='min(1920,iw)':-2", '-c:v', 'libx264', '-preset', 'slow',
    '-profile:v', 'high', '-pix_fmt', 'yuv420p',
    '-b:v', `${vb}k`, '-maxrate', `${Math.floor(vb * 1.5)}k`, '-bufsize', `${vb * 2}k`,
    '-c:a', 'aac', '-b:a', '128k',
    '-movflags', '+faststart', cikti], { encoding: 'utf8' });
  if (s.status !== 0 || !fs.existsSync(cikti)) return null;
  return cikti;
}

async function medyaYukle(token, tamYol) {
  let yol = tamYol;
  if (fs.statSync(yol).size > SINIR_BAYT && /\.(mp4|webm|mov)$/i.test(yol)) {
    const k = videoKucult(yol);
    if (k) yol = k;
  }
  const uzanti = path.extname(yol).slice(1).toLowerCase();
  const c = await api('/medya', {
    yontem: 'POST', token, ham: fs.readFileSync(yol), tip: MIME[uzanti] || 'application/octet-stream',
  });
  return c.yol;
}

// Gönderi metni: kullanıcının kendi notu varsa o, yoksa Instagram açıklaması.
// Sonuna kaynak atfı eklenir (başkasının emeği görünür olsun).
function metinKur(kullaniciNotu, aciklama, yaratici, kisaKod) {
  let govde = (kullaniciNotu || '').replace(IG_DESEN, '').trim();
  if (!govde) govde = (aciklama || '').trim();
  const atif = yaratici
    ? `Instagram: @${yaratici} (instagram.com/p/${kisaKod})`
    : `Instagram: instagram.com/p/${kisaKod}`;
  const bosluk = 1000 - atif.length - 2;
  if (govde.length > bosluk) govde = `${govde.slice(0, bosluk - 1).trimEnd()}…`;
  return govde ? `${govde}\n\n${atif}` : atif;
}

async function tur() {
  cerezleriHazirla();
  const durum = durumOku();
  const islenen = new Set(durum.islenen);
  const giris = await api('/auth/giris', {
    yontem: 'POST', govde: { email: BOT_EMAIL, sifre: sifreOku() },
  });
  const token = giris.token;
  const benId = giris.kullanici?.id;

  const { sohbetler = [] } = await api('/sohbetler', { token });
  let yeni = 0;

  // Bir bağlantıyı işleyip gönderiye çevirir.
  async function paylas(partner, m, hedef) {
    const eslesme = (m.metin || '').match(IG_DESEN);
    const kisaKod = eslesme[1];
    try {
      const g = instaIndir(kisaKod);
      const yollar = [];
      for (const d of g.dosyalar) yollar.push(await medyaYukle(token, path.join(g.dizin, d)));
      await api('/yorumlar', { yontem: 'POST', token, govde: {
        tur: hedef.tur, tmdb_id: hedef.id,
        metin: metinKur(m.metin, g.aciklama, g.yaratici, kisaKod),
        medya: yollar,
      } });
      await api('/mesajlar', { yontem: 'POST', token, govde: { kullanici_adi: partner,
        metin: `Paylaşıldı (${yollar.length} medya) — ${hedef.tur}/${hedef.id}` } });
      fs.rmSync(g.dizin, { recursive: true, force: true });
      console.log(`+ ${kisaKod} → ${hedef.tur}/${hedef.id} (${yollar.length} medya)`);
      yeni++;
    } catch (e) {
      console.error(`! ${kisaKod}: ${e.message}`);
      await api('/mesajlar', { yontem: 'POST', token, govde: { kullanici_adi: partner,
        metin: `Paylaşılamadı: ${String(e.message).slice(0, 200)}` } }).catch(() => {});
    }
    islenen.add(m.id);
  }

  for (const s of sohbetler) {
    const partner = s.partner;
    if (!IZINLILER.includes(partner)) continue;
    const { mesajlar = [] } = await api(`/mesajlar/${partner}`, { token });
    let sonKart = null;   // sohbette görülen en son dizi/film kartı
    let bekleyen = null;  // kartı beklenen bağlantı mesajı
    for (const m of mesajlar) {
      const kart = (m.icerik_tur && m.icerik_id)
        ? { tur: m.icerik_tur, id: m.icerik_id } : null;
      if (kart) sonKart = kart;
      const gelen = m.gonderen_id !== benId;
      // Kart, kendisinden ÖNCE gelmiş kartsız bağlantıyı da tamamlar
      // (kullanıcı önce linki, sonra kartı yolluyor).
      if (gelen && kart && bekleyen) {
        await paylas(partner, bekleyen, kart);
        bekleyen = null;
        continue;
      }
      if (!gelen || !IG_DESEN.test(m.metin || '') || islenen.has(m.id)) continue;

      const hedef = kart || sonKart;
      if (hedef) { await paylas(partner, m, hedef); continue; }
      // Hedef yok: mesajı İŞLENMİŞ SAYMA, kart gelince tamamlanacak.
      if (!bekleyen) {
        bekleyen = m;
        await api('/mesajlar', { yontem: 'POST', token, govde: { kullanici_adi: partner,
          metin: 'Bu gönderiyi hangi dizi/filme ekleyeyim? Sohbetten içerik kartını yolla, hemen paylaşayım.' } });
      }
    }
  }
  // Durum dosyası şişmesin: son 500 kayıt yeter
  durumYaz({ islenen: [...islenen].slice(-500) });
  return yeni;
}

const izle = process.argv.includes('--izle');
if (izle) {
  console.log('İzleme başladı (60 sn aralık). Durdurmak için Ctrl+C.');
  for (;;) {
    try { const n = await tur(); if (n) console.log(`${n} gönderi paylaşıldı`); }
    catch (e) { console.error('tur hatası:', e.message); }
    await new Promise((r) => setTimeout(r, 60_000));
  }
} else {
  const n = await tur();
  console.log(n ? `${n} gönderi paylaşıldı.` : 'Bekleyen gönderi yok.');
}
