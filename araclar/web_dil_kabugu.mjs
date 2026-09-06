// dizi.jpg — dil başına Flutter KABUĞU üretir (dağıtım ritüelinde 3.6. adım,
// `web_hashla.js`ten SONRA, `scp`den ÖNCE).
//
// SORUN (6 Eylül 2026, SEO danışmanının bulgusu):
// nginx `$og_bot` haritasındaki botlar `/de` istediğinde Node'un ürettiği SSR
// sayfasını alıyor ve orada başlık/açıklama Almanca + hedef kelimeli. Ama o
// haritada OLMAYAN herkes — yani bütün insanlar ve listede yer almayan
// tarayıcılar — `try_files /index.html` ile TEK bir kabuğu alıyordu; o kabuğun
// başlığı 46 dilde de "dizi.jpg", açıklaması 46 dilde de Türkçeydi.
// Ölçüldü: `curl -A "<mobil Chrome>" https://dizijpg.com/de` -> <title>dizi.jpg</title>.
//
// ÇÖZÜM: her dil için kabuğun bir KOPYASI, kendi <title>/<meta description>/
// og:/twitter: metinleri ve kendi `<html lang>`iyle. nginx `/de`, `/de/...`
// isteklerini `/de/index.html`e düşürür (bkz. nginx `$dil_kabuk` haritası).
//
// NEDEN sub_filter DEĞİL: nginx'te `brotli_static on` var, yani index.html
// diske ÖNCEDEN sıkıştırılıp `.br` olarak servis ediliyor; sub_filter
// sıkıştırılmış gövdede çalışmaz ve kural sessizce hiçbir şey yapmaz.
//
// NEDEN `<base href="/">` KOPYADA DA "/" KALIR: kabuk `/de/index.html`
// adresinden servis edilse de içindeki `favicon.png`, `manifest.json`,
// `icons/...` göreli adresleri KÖKTEN çözülmeli. base'i `/de/` yapsaydık
// tarayıcı `/de/main.<hash>.dart.js` isterdi ve uygulama hiç açılmazdı.
//
// KULLANIM:  node araclar/web_dil_kabugu.mjs [build/web dizini]

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const BURASI = path.dirname(fileURLToPath(import.meta.url));
const KOK = path.join(BURASI, '..');
const kok = process.argv[2] || path.join(KOK, 'app', 'build', 'web');

const { SEO_DIL, SEO_DILLER } = await import(
  path.join(KOK, 'backend', 'seo_dil.js')
);

const anaDosya = path.join(kok, 'index.html');
if (!fs.existsSync(anaDosya)) {
  console.error(`HATA: ${anaDosya} yok — önce \`flutter build web\` koş.`);
  process.exit(1);
}
const kabuk = fs.readFileSync(anaDosya, 'utf8');

// HTML öznitelik değeri kaçışı. Başlıklar `&` ve `"` taşıyabiliyor
// ("Serien & Filme"), ham basılırsa etiket bozulur.
const oz = (x) =>
  String(x)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
// <title> GÖVDESİ: burada `"` kaçmaz, `&` ve `<` kaçar.
const gov = (x) => String(x).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

// Değiştirilecek her etiket için: desen + üreteç. Desenin EŞLEŞMEMESİ hatadır —
// index.html'de etiket adı değişirse bu betik sessizce eski metni bırakmasın.
const KURALLAR = [
  ['html lang', /<html lang="[^"]*">/, (d) => `<html lang="${d.dil}">`],
  ['title', /<title>[\s\S]*?<\/title>/, (d) => `<title>${gov(d.baslik)}</title>`],
  [
    'meta description',
    /<meta name="description" content="[^"]*">/,
    (d) => `<meta name="description" content="${oz(d.aciklama)}">`,
  ],
  [
    'og:title',
    /<meta property="og:title" content="[^"]*">/,
    (d) => `<meta property="og:title" content="${oz(d.baslik)}">`,
  ],
  [
    'og:description',
    /<meta property="og:description" content="[^"]*">/,
    (d) => `<meta property="og:description" content="${oz(d.aciklama)}">`,
  ],
  [
    'og:url',
    /<meta property="og:url" content="[^"]*">/,
    (d) => `<meta property="og:url" content="${d.adres}">`,
  ],
  [
    'twitter:title',
    /<meta name="twitter:title" content="[^"]*">/,
    (d) => `<meta name="twitter:title" content="${oz(d.baslik)}">`,
  ],
  [
    'twitter:description',
    /<meta name="twitter:description" content="[^"]*">/,
    (d) => `<meta name="twitter:description" content="${oz(d.aciklama)}">`,
  ],
];

function kabukUret(dil) {
  const t = SEO_DIL[dil];
  const veri = {
    dil,
    baslik: t.anaBaslik,
    aciklama: t.anaAciklama,
    adres: dil === 'tr' ? 'https://dizijpg.com' : `https://dizijpg.com/${dil}`,
  };
  let html = kabuk;
  for (const [ad, desen, uret] of KURALLAR) {
    if (!desen.test(html)) throw new Error(`index.html: "${ad}" etiketi bulunamadı`);
    html = html.replace(desen, uret(veri));
  }
  return html;
}

// Türkçe kabuk KÖKTE kalır (kanonik önek yok) — ama başlığı/açıklaması o da
// seo_dil.js'ten alır; eskiden "dizi.jpg" yazıyordu.
fs.writeFileSync(anaDosya, kabukUret('tr'));

let sayi = 0;
for (const dil of SEO_DILLER) {
  if (dil === 'tr') continue;
  const dizin = path.join(kok, dil);
  fs.mkdirSync(dizin, { recursive: true });
  fs.writeFileSync(path.join(dizin, 'index.html'), kabukUret(dil));
  sayi++;
}

console.log(`dil kabuğu: kök (tr) güncellendi + ${sayi} dil dizini yazıldı`);
