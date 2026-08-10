// Demo hesabın biyografisini 46 dile çevirir → araclar/rehber-bio.json
// Backend'in kendi kullandığı anahtarsız gtx ucunu kullanır (server.js:4899).
import { writeFile } from 'node:fs/promises';

const TR = 'Jeneriği atlamayanlardanım. Günde bir bölüm, haftada bir film; '
  + 'puanlarım sert ama adil. Takvimim hep dolu, listelerim herkese açık. '
  + 'Yeni sezon, yeni bahane.';

// KAYNAK NEDEN İNGİLİZCE: Türkçe'den doğrudan çevirince "jenerik" birçok dilde
// AKADEMİK KREDİ'ye dönüşüyordu (nb "studiepoengene", fi "krediittejä",
// sw "mikopo" = borç). Anlamı kilitlenmiş bir İngilizce özet üzerinden
// çevirmek bu tuzağı kapatıyor; Türkçe metin olduğu gibi kalır.
const EN = 'I never skip the intro. One episode a day, one movie a week; '
  + 'my ratings are strict but fair. My calendar is always full and my lists '
  + 'are open to everyone. New season, new excuse.';

const DILLER = ['en','zh','hi','es','fr','ar','bn','pt','ru','ur','id','de','ja','sw','mr',
  'te','vi','ko','ta','it','fa','pl','uk','ro','nl','th','gu','kn','ml','pa','ms','my','am',
  'az','el','hu','cs','sv','he','fil','sr','bg','da','fi','nb'];

// Google'ın kod adları birkaç yerde ayrışıyor.
const GTX = { fil: 'tl', nb: 'no', zh: 'zh-CN', he: 'iw' };

async function cevir(metin, hedef) {
  const tl = GTX[hedef] || hedef;
  const url = 'https://translate.googleapis.com/translate_a/single'
    + `?client=gtx&sl=en&tl=${encodeURIComponent(tl)}&dt=t&q=${encodeURIComponent(metin)}`;
  for (let i = 0; i < 4; i++) {
    try {
      const c = await fetch(url, { signal: AbortSignal.timeout(15000) });
      if (!c.ok) throw new Error(`HTTP ${c.status}`);
      const v = await c.json();
      const s = v[0].map((p) => (Array.isArray(p) && typeof p[0] === 'string' ? p[0] : '')).join('').trim();
      if (s) return s;
      throw new Error('boş');
    } catch (e) {
      if (i === 3) throw new Error(`${hedef}: ${e.message}`);
      await new Promise((r) => setTimeout(r, 1500 * (i + 1)));
    }
  }
}

const sonuc = { tr: TR, en: EN };
for (const d of DILLER) {
  if (d === 'en') continue;
  sonuc[d] = await cevir(EN, d);
  console.log(`${d.padEnd(4)} ${sonuc[d].slice(0, 70)}`);
  await new Promise((r) => setTimeout(r, 350));
}
const eksik = Object.entries(sonuc).filter(([, v]) => !v || v.length < 20);
if (eksik.length) throw new Error(`eksik çeviri: ${eksik.map((e) => e[0]).join(',')}`);
// 300 karakter sunucu sınırı
for (const [k, v] of Object.entries(sonuc)) {
  if (v.length > 300) throw new Error(`${k} bio 300 karakteri aştı (${v.length})`);
}
await writeFile(process.argv[2], JSON.stringify(sonuc, null, 2) + '\n');
console.log(`\n${Object.keys(sonuc).length} dil yazıldı → ${process.argv[2]}`);
