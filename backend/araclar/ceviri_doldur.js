#!/usr/bin/env node
/**
 * Toplu çeviri doldurma — çevirisi olmayan gönderileri önceden çevirir.
 *
 * Kullanıcı akışta düğmeye basmadan kendi dilinde okusun diye eksik
 * çevirileri arka planda üretir. Veritabanına DOĞRUDAN yazmaz: server.js'in
 * kendi admin uçlarını kullanır, böylece üretilen kayıtlar uçların okuduğu
 * biçimle birebir aynı olur.
 *   - GET  /admin/cevrilecek?dil=&limit=&kaynak=  → çevrilmeyi bekleyen
 *     BENZERSİZ metinler (NOT EXISTS ile; iş yarıda kesilirse kaldığı yerden
 *     devam eder, hiçbir metin iki kez çevrilmez)
 *   - POST /admin/ceviri {ceviriler:[{ozet,dil,metin}]} → metin_cevirileri
 *
 * Çeviri ucu anahtarsız ve ücretsiz; bu yüzden eşzamanlılık düşük tutulur,
 * istekler arasına bekleme konur, 429/5xx'te üstel geri çekilme uygulanır.
 *
 * Kullanım (sunucuda):
 *   ADMIN_TOKEN=... node araclar/ceviri_doldur.js
 *   ... node araclar/ceviri_doldur.js --hedef=de --kaynak=tr   (tek geçiş)
 *   ... node araclar/ceviri_doldur.js --kuru                   (yalnız sayım)
 *
 * Varsayılan kapsam: yabancı gönderiler → tr, Türkçe gönderiler → en.
 */

const ARG = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const [k, v] = a.replace(/^--/, '').split('=');
    return [k, v === undefined ? '1' : v];
  }),
);

const API = process.env.API || 'http://127.0.0.1:8500';
const TOKEN = process.env.ADMIN_TOKEN || '';
const KURU = !!ARG.kuru;                                  // yalnız ölç, yazma
const OBEK = Math.max(1, parseInt(ARG.obek, 10) || 25);   // kaç çeviride bir yaz
const ESZAMAN = Math.min(3, Math.max(1, parseInt(ARG.eszaman, 10) || 2));
const BEKLEME = Math.max(0, parseInt(ARG.bekleme, 10) || 400); // ms, istek arası
const ASGARI = 3;   // bundan kısa metni çevirmenin anlamı yok

// Varsayılan geçişler: {hedef, kaynak|null}
const GECISLER = ARG.hedef
  ? [{ hedef: ARG.hedef, kaynak: ARG.kaynak || null }]
  : [{ hedef: 'tr', kaynak: null }, { hedef: 'en', kaynak: 'tr' }];

const bekle = (ms) => new Promise((r) => setTimeout(r, ms));
const damga = () => new Date().toISOString().replace('T', ' ').slice(0, 19);
const log = (...a) => console.log(`[${damga()}]`, ...a);

// ---------- çeviri ucu (server.js'teki metniCevir ile aynı istek/ayrıştırma) ----------
const CEVIRI_UCU = 'https://translate.googleapis.com/translate_a/single';
const CEVIRI_AZAMI = 4000; // uzun metinler ucu 413'e düşürüyor

async function ceviriDene(metin, hedefDil, kaynakDil) {
  const kirp = String(metin || '').slice(0, CEVIRI_AZAMI);
  if (kirp.trim().length < 2) return { durum: 'atla' };
  const url = `${CEVIRI_UCU}?client=gtx&sl=${encodeURIComponent(kaynakDil || 'auto')}`
    + `&tl=${encodeURIComponent(hedefDil)}&dt=t&q=${encodeURIComponent(kirp)}`;
  let cevap;
  try {
    cevap = await fetch(url, { signal: AbortSignal.timeout(20000) });
  } catch (e) {
    return { durum: 'yeniden', not: `ag: ${e.name || e.message}` };
  }
  if (cevap.status === 429 || cevap.status >= 500) {
    return { durum: 'yeniden', not: `http ${cevap.status}` };
  }
  if (!cevap.ok) return { durum: 'hata', not: `http ${cevap.status}` };
  let veri;
  try {
    veri = await cevap.json();
  } catch {
    return { durum: 'yeniden', not: 'bozuk json' };
  }
  if (!Array.isArray(veri?.[0])) return { durum: 'hata', not: 'beklenmedik govde' };
  const sonuc = veri[0]
    .map((p) => (Array.isArray(p) && typeof p[0] === 'string' ? p[0] : ''))
    .join('');
  return sonuc.trim() ? { durum: 'tamam', metin: sonuc } : { durum: 'hata', not: 'bos sonuc' };
}

// 429/5xx/ağ hatasında üstel geri çekilme: 2s, 4s, 8s, 16s, 32s
async function ceviriGetir(metin, hedefDil, kaynakDil) {
  for (let deneme = 0; deneme < 6; deneme += 1) {
    const s = await ceviriDene(metin, hedefDil, kaynakDil);
    if (s.durum !== 'yeniden') return s;
    if (deneme === 5) return { durum: 'hata', not: s.not };
    const geri = 2000 * 2 ** deneme;
    log(`  geri cekilme ${geri / 1000}s (${s.not})`);
    await bekle(geri);
  }
  return { durum: 'hata' };
}

// ---------- admin uçları ----------
async function adminGet(yol) {
  const c = await fetch(`${API}${yol}`, { headers: { 'x-admin-token': TOKEN } });
  if (!c.ok) throw new Error(`GET ${yol} → ${c.status} ${await c.text()}`);
  return c.json();
}

async function ceviriYaz(ceviriler) {
  if (!ceviriler.length || KURU) return 0;
  const c = await fetch(`${API}/admin/ceviri`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-admin-token': TOKEN },
    body: JSON.stringify({ ceviriler }),
  });
  if (!c.ok) throw new Error(`POST /admin/ceviri → ${c.status} ${await c.text()}`);
  return (await c.json()).eklenen || 0;
}

// Yalnız emoji/noktalama olan metni çevirmek kotayı boşa yer
const anlamli = (m) => /[\p{L}\p{N}]/u.test(m || '');

async function gecisiCalistir({ hedef, kaynak }, sayac) {
  log(`=== gecis: hedef=${hedef} kaynak=${kaynak || '(tum yabanci)'} ===`);
  const islenen = new Set(); // aynı turda tekrar çekilenleri sonsuz döngüye sokma
  for (;;) {
    const yol = `/admin/cevrilecek?dil=${hedef}&limit=500`
      + (kaynak ? `&kaynak=${kaynak}` : '');
    const { metinler } = await adminGet(yol);
    const bekleyen = metinler.filter((m) => !islenen.has(m.ozet));
    if (!bekleyen.length) { log(`gecis bitti: ${hedef}`); return; }
    log(`kuyrukta ${metinler.length}, bu turda ${bekleyen.length} kayit`);

    let tampon = [];
    const yaz = async () => {
      if (!tampon.length) return;
      // Önce al-ve-boşalt: iki işçi aynı anda yazarsa aynı kayıt iki kez
      // gönderilmesin (ve await sırasında eklenen kayıt kaybolmasın).
      const paket = tampon;
      tampon = [];
      const n = await ceviriYaz(paket);
      sayac.yazilan += paket.length;
      log(`  yazildi +${n} (toplam cevrilen ${sayac.cevrildi}, atlanan ${sayac.atlanan}, basarisiz ${sayac.basarisiz})`);
    };

    // Eşzamanlılık: en fazla ESZAMAN işçi, her istek sonrası bekleme
    let sira = 0;
    const isci = async () => {
      for (;;) {
        const i = sira; sira += 1;
        const kayit = bekleyen[i];
        if (!kayit) return;
        islenen.add(kayit.ozet);
        const metin = String(kayit.metin || '').trim();
        if (metin.length < ASGARI || !anlamli(metin)) {
          sayac.atlanan += 1;
          sayac.atlananlar.push({ ozet: kayit.ozet, hedef, neden: 'kisa/anlamsiz' });
          continue;
        }
        if (!kayit.kaynak_dil) { // dili bilinmeyen: uçlar zaten çeviri göstermez
          sayac.atlanan += 1;
          sayac.atlananlar.push({ ozet: kayit.ozet, hedef, neden: 'kaynak_dil bos' });
          continue;
        }
        if (KURU) { sayac.cevrildi += 1; continue; }
        const s = await ceviriGetir(metin, hedef, kayit.kaynak_dil);
        if (s.durum === 'tamam') {
          sayac.cevrildi += 1;
          tampon.push({ ozet: kayit.ozet, dil: hedef, metin: s.metin });
        } else if (s.durum === 'atla') {
          sayac.atlanan += 1;
          sayac.atlananlar.push({ ozet: kayit.ozet, hedef, neden: 'cok kisa' });
        } else {
          sayac.basarisiz += 1;
          sayac.basarisizlar.push({ ozet: kayit.ozet, hedef, not: s.not || '' });
          log(`  BASARISIZ ${kayit.ozet} (${s.not || ''})`);
        }
        if (tampon.length >= OBEK) await yaz();
        await bekle(BEKLEME);
      }
    };
    await Promise.all(Array.from({ length: ESZAMAN }, isci));
    await yaz();
    if (KURU) { log(`kuru calisma: ${sayac.cevrildi} kayit cevrilecekti`); return; }
  }
}

(async () => {
  if (!TOKEN && !KURU) { console.error('ADMIN_TOKEN gerekli'); process.exit(1); }
  const basla = Date.now();
  const sayac = {
    cevrildi: 0, atlanan: 0, basarisiz: 0, yazilan: 0,
    atlananlar: [], basarisizlar: [],
  };
  for (const g of GECISLER) await gecisiCalistir(g, sayac);
  const dk = ((Date.now() - basla) / 60000).toFixed(1);
  log(`BITTI — cevrilen ${sayac.cevrildi}, atlanan ${sayac.atlanan}, basarisiz ${sayac.basarisiz}, sure ${dk} dk`);
  if (sayac.basarisizlar.length) {
    log('basarisiz ozetler:', JSON.stringify(sayac.basarisizlar.slice(0, 50)));
  }
  if (sayac.atlananlar.length) {
    log('atlanan ozetler:', JSON.stringify(sayac.atlananlar.slice(0, 50)));
  }
})().catch((e) => { console.error('COKME:', e); process.exit(1); });
