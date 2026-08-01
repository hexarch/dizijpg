// dizi.jpg — gelen kutusu okuyucu (host Postfix/Dovecot Maildir'leri)
// Konteynere /mail/<hesap> altına SALT-OKUNUR bağlanır; admin panelindeki
// "Mailler" sekmesi buradan okur. Yazma yolu YOK: panel posta kutusunu
// hiçbir koşulda değiştiremez.
import fs from 'fs';
import path from 'path';
import { simpleParser } from 'mailparser';

const MAIL_KUTU_KOK = process.env.MAIL_KUTU_KOK || '/mail';

// /mail/<hesap>/{new,cur} = INBOX; /mail/<hesap>/.Sent gibi noktalı dizinler
// Dovecot IMAP klasörleridir (posta istemcisinden gönderilenler oraya düşer).
export function mailKutulari(kok = MAIL_KUTU_KOK) {
  let hesaplar = [];
  try {
    hesaplar = fs.readdirSync(kok, { withFileTypes: true })
      .filter((d) => d.isDirectory()).map((d) => d.name);
  } catch { return []; } // bağlanmamışsa panel boş liste görür, çökmez
  const kutular = [];
  for (const hesap of hesaplar) {
    const dizin = path.join(kok, hesap);
    kutular.push({ hesap, klasor: 'Gelen', kok: dizin });
    let alt = [];
    try {
      alt = fs.readdirSync(dizin, { withFileTypes: true })
        .filter((d) => d.isDirectory() && d.name.startsWith('.') && d.name.length > 1)
        .map((d) => d.name);
    } catch { /* okunamıyorsa yalnız INBOX */ }
    for (const a of alt) {
      kutular.push({ hesap, klasor: a.slice(1), kok: path.join(dizin, a) });
    }
  }
  return kutular;
}

// Maildir dosya adları: 1776432124.Vfe00I230b9M455108.mail.dizijpg.com:2,S
const MAILDIR_AD = /^[A-Za-z0-9._,:=+%-]+$/;

// Bir kutudaki dosyalar: new/ = okunmamış, cur/ = okunmuş.
export function mailDosyalari(kutu) {
  const cikti = [];
  for (const tip of ['new', 'cur']) {
    const dizin = path.join(kutu.kok, tip);
    let adlar = [];
    try { adlar = fs.readdirSync(dizin); } catch { continue; }
    for (const ad of adlar) {
      if (ad.startsWith('.') || !MAILDIR_AD.test(ad)) continue;
      let st;
      try { st = fs.statSync(path.join(dizin, ad)); } catch { continue; }
      if (!st.isFile()) continue;
      cikti.push({
        hesap: kutu.hesap,
        klasor: kutu.klasor,
        ad,
        yol: path.join(dizin, ad),
        mtime: st.mtimeMs,
        boyut: st.size,
        okunmadi: tip === 'new',
      });
    }
  }
  return cikti;
}

// Ayrıştırma pahalı; yol+mtime anahtarıyla önbelleklenir (Maildir dosyaları
// değişmez, yalnız new→cur taşınır — o da yolu değiştirir).
const ONBELLEK = new Map();
export async function mailAyristir(kayit) {
  const anahtar = `${kayit.yol}:${kayit.mtime}`;
  const hazir = ONBELLEK.get(anahtar);
  if (hazir) return hazir;
  const p = await simpleParser(await fs.promises.readFile(kayit.yol));
  const c = {
    kimden: p.from?.text || '(bilinmiyor)',
    kime: p.to?.text || '',
    konu: p.subject || '(konusuz)',
    tarih: (p.date || new Date(kayit.mtime)).toISOString(),
    metin: p.text || '',
    html: p.html || null,
    ekler: (p.attachments || []).map((e) => ({ ad: e.filename || 'ek', boyut: e.size })),
  };
  if (ONBELLEK.size > 200) ONBELLEK.clear();
  if (kayit.boyut < 512 * 1024) ONBELLEK.set(anahtar, c);
  return c;
}

// Kimlik: hesap|klasör|dosya → base64url (dosya YOLU istemciye hiç geçmez).
export const mailKimlik = (k) =>
  Buffer.from(`${k.hesap}|${k.klasor}|${k.ad}`).toString('base64url');

// Kimliği çözerken dosyayı diskten değil TARANAN kutu listesinden eşleştiririz:
// istemci uydurma ad/yol göndererek kutu dışına çıkamaz (../ , /etc/passwd…).
export function mailKimlikCoz(kimlik, kok = MAIL_KUTU_KOK) {
  let ham;
  try { ham = Buffer.from(String(kimlik), 'base64url').toString('utf8'); } catch { return null; }
  const [hesap, klasor, ad] = ham.split('|');
  if (!hesap || !klasor || !ad || !MAILDIR_AD.test(ad)) return null;
  const kutu = mailKutulari(kok).find((k) => k.hesap === hesap && k.klasor === klasor);
  if (!kutu) return null;
  return mailDosyalari(kutu).find((d) => d.ad === ad) || null;
}

const ozet = (s) => String(s || '').replace(/\s+/g, ' ').trim().slice(0, 180);

// Son N maili başlıklarıyla döker. 8'li öbekler: yüzlerce dosyada fd tükenmesin.
export async function gelenMailler(limit, kok = MAIL_KUTU_KOK) {
  const dosyalar = mailKutulari(kok).flatMap(mailDosyalari)
    .sort((a, b) => b.mtime - a.mtime).slice(0, limit);
  const cikti = [];
  for (let i = 0; i < dosyalar.length; i += 8) {
    cikti.push(...await Promise.all(dosyalar.slice(i, i + 8).map(async (d) => {
      const ortak = {
        yon: 'gelen', id: mailKimlik(d), hesap: d.hesap, klasor: d.klasor,
        okunmadi: d.okunmadi, boyut: d.boyut,
      };
      try {
        const m = await mailAyristir(d);
        return {
          ...ortak,
          kimden: m.kimden, kime: m.kime, konu: m.konu, tarih: m.tarih,
          ozet: ozet(m.metin || m.konu), ek_sayi: m.ekler.length,
        };
      } catch (e) {
        // Bozuk/yarım dosya tüm listeyi düşürmesin.
        return {
          ...ortak, kimden: '(okunamadı)', kime: '', konu: d.ad,
          tarih: new Date(d.mtime).toISOString(), ozet: e.message, ek_sayi: 0,
        };
      }
    })));
  }
  return cikti;
}

// HTML gövde panelde sandbox'lı iframe'de gösterilir; yine de script/olay
// öznitelikleri sökülür ve uzak kaynaklar (izleme pikseli) pasifleştirilir.
export function htmlKisirlastir(html) {
  return String(html)
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<iframe[\s\S]*?<\/iframe>/gi, '')
    .replace(/\son[a-z]+\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)/gi, '')
    .replace(/\ssrc\s*=/gi, ' data-uzak-src=');
}
