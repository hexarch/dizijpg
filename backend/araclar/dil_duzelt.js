#!/usr/bin/env node
/**
 * Gönderi kaynak dili onarımı — `yorumlar.kaynak_dil` alanını denetler.
 *
 * İki sorunu çözer:
 *   1. kaynak_dil BOŞ kayıtlar → gönderi hiç çevrilmez, çeviri düğmesi çıkmaz.
 *   2. kaynak_dil YANLIŞ kayıtlar (ör. Türkçe metne 'en' denmiş) → sistem
 *      Türkçeden Türkçeye anlamsız "çeviri" üretir ("kaç verirsiniz" →
 *      "kaçarsınız").
 *
 * GÜVENLİK: `yorumlar.metin` sütununa ASLA yazmaz. Yalnız `kaynak_dil` alanını
 * günceller ve artık geçersiz kalan `metin_cevirileri` satırlarını siler.
 * Yazan her komut önce ekrana dökülür; `--uygula` verilmedikçe hiçbir şey
 * değişmez.
 *
 * SUNUCUDA, HOST üzerinde çalışır (altyazi_uret.js ile aynı desen): veritabanı
 * dışarı port açmadığı için `docker exec dizijpg-db psql` kullanılır.
 *
 * Dil kararı ÜÇ sinyalin birleşimidir; tek sezgiye güvenilmez:
 *   a) server.js'teki `dilTespit` — POST /admin/dil-tespit ucu üzerinden
 *      (yalnız kaynak_dil'i boş olan kayıtlara bakar, kendi mantığı yazılmaz)
 *   b) Google'ın anahtarsız çeviri ucunun dil tespiti (gönderi çevirisinde
 *      zaten kullanılan uç)
 *   c) Türkçeye özgü harfler (ğ ı ş İ Ğ Ş) + yaygın Türkçe kelime/ek deseni
 * Bir etiketi değiştirmek için (b) ve (c) AYNI dili söylemelidir. Böylece
 * gerçekten İngilizce bir gönderiyi Türkçe sanma riski düşer. Emoji, bağlantı,
 * etiket ve kullanıcı adları tespitten önce metinden atılır; geriye harf
 * kalmıyorsa (yalnız emoji / yalnız bağlantı / "test") dil kavramı anlamsızdır,
 * kayda DOKUNULMAZ — uçlar boş dilde çeviri göstermiyor, doğru davranış budur.
 *
 * Kullanım (sunucuda /opt/dizijpg içinde):
 *   node araclar/dil_duzelt.js --tara                 rapor, yazma yok
 *   ADMIN_TOKEN=... node araclar/dil_duzelt.js --tara --tespit-ucu
 *   ADMIN_TOKEN=... node araclar/dil_duzelt.js --uygula
 *   node araclar/dil_duzelt.js --tara --json=/tmp/oneriler.json
 * Seçenekler:
 *   --kaynak=en   yalnız bu etiketi taşıyan kayıtları denetle (varsayılan: en)
 *   --tumu        boş olmayan TÜM etiketleri denetle (yavaş: her kayıt bir istek)
 *   --limit=N     en çok N kayıt
 *   --bekleme=ms  dış istekler arası bekleme (varsayılan 350)
 *   --onay=1733:tr,768:en   ŞÜPHELİ listeden elle onaylananlar. Yalnız tarayıcının
 *                 zaten "etiket yanlış" dediği kayıtlar ve yalnız tarayıcının
 *                 tespit ettiği dil kabul edilir; uydurma id/dil reddedilir.
 */

import { execFileSync } from 'node:child_process';
import fs from 'node:fs';

const ARG = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const [k, v] = a.replace(/^--/, '').split('=');
    return [k, v === undefined ? '1' : v];
  }),
);

const DB_KAP = process.env.DIL_DB_KAP || 'dizijpg-db';
const DB_KULLANICI = process.env.DIL_DB_KULLANICI || 'dizijpg';
const DB_AD = process.env.DIL_DB_AD || 'dizijpg';
const API = process.env.API || 'http://127.0.0.1:8500';
const TOKEN = process.env.ADMIN_TOKEN || '';

const UYGULA = !!ARG.uygula;
const TESPIT_UCU = !!ARG['tespit-ucu'] || UYGULA;
const KAYNAK = ARG.tumu ? null : (ARG.kaynak || 'en');
const LIMIT = Math.max(1, parseInt(ARG.limit, 10) || 5000);
const BEKLEME = Math.max(0, parseInt(ARG.bekleme, 10) || 350);
// Elle onaylananlar: {id → dil}. Yalnız şüpheli listedekiler uygulanabilir.
const ONAY = new Map(String(ARG.onay || '').split(',').filter(Boolean).map((p) => {
  const [id, dil] = p.split(':');
  const kod = String(dil || '').toLowerCase();
  if (!/^\d+$/.test(String(id || '')) || !/^[a-z]{2,3}$/.test(kod)) {
    throw new Error(`--onay bicimi hatali: "${p}" (beklenen id:dil, orn. 1733:tr)`);
  }
  return [Number(id), kod];
}));
const AYRAC = '';

const bekle = (ms) => new Promise((r) => setTimeout(r, ms));
const log = (...m) => process.stdout.write(`[${new Date().toISOString().slice(0, 19)}] ${m.join(' ')}\n`);

/** psql'i `docker exec` ile çalıştırır; SQL stdin'den gider. */
function psql(sql, { satirlar = false } = {}) {
  const cikti = execFileSync('docker', [
    'exec', '-i', DB_KAP, 'psql', '-U', DB_KULLANICI, '-d', DB_AD,
    '-v', 'ON_ERROR_STOP=1', '-q', '-tA', '-F', AYRAC, '-f', '-',
  ], { input: sql, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  if (!satirlar) return cikti.trim();
  return cikti.split('\n').filter(Boolean).map((s) => s.split(AYRAC));
}

/** SQL metin sabiti — tek tırnak kaçışı (metin ASLA yazılmaz, yalnız okunur). */
const q = (s) => `'${String(s).replace(/'/g, "''")}'`;

// Satır bazlı okuduğumuz için metindeki satır sonları boşluğa çevrilir.
// (Yalnız OKUMA; `yorumlar.metin` sütunu hiçbir zaman güncellenmez.)
const TEK_SATIR = "replace(replace(coalesce(btrim(metin),''), chr(13), ' '), chr(10), ' ')";

// ---------- metin normalleştirme ----------
// Dil taşımayan parçaları at: bağlantı, etiket, kullanıcı adı, emoji, sayı.
function sadeMetin(ham) {
  return String(ham || '')
    .replace(/https?:\/\/\S+/g, ' ')
    .replace(/\S+@\S+\.\S+/g, ' ')
    .replace(/[#@][\w._À-ɏ-]+/gu, ' ')
    .replace(/[\p{Extended_Pictographic}\p{Emoji_Presentation}]/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

const harfSayisi = (m) => (m.match(/\p{L}/gu) || []).length;

/**
 * Metin yalnız büyük harfle başlayan kelimelerden mi oluşuyor? ("Hector
 * Salamanca", "Stan Lee") — özel ad dil taşımaz; dış tespit ona rastgele bir
 * dil verir (Salamanca → es). Yerel sözlük kanıtı yoksa dokunulmaz.
 */
function ozelAdGibi(sade) {
  const kelimeler = sade.split(/\s+/).filter((k) => /\p{L}/u.test(k));
  return kelimeler.length > 0 && kelimeler.every((k) => /^\p{Lu}/u.test(k));
}

// ---------- Türkçe sinyali (yerel, üçüncü görüş) ----------
const TR_HARF = /[ğışĞİŞ]/;                    // yalnız Türkçede olan harfler
const TR_HARF_GENIS = /[çöüÇÖÜ]/;              // Almanca/Fransızcada da var
const TR_KELIME = new Set(('bir ve bu şu için çok daha ama fakat ne mi mu mı mü ile gibi kadar '
  + 'var yok değil olarak sonra önce şey ben sen biz siz onlar dizi film bölüm sezon oyuncu '
  + 'izle izledim izlerken izlediniz güzel harika iyi kötü bence herkes sadece hep tabi evet '
  + 'hayır adam kız hiç çünkü zaten yani böyle şöyle nasıl neden kim kaç en iyi bu da de ki '
  + 'ya ise ancak hem her bazı kendi bile diye olan olur oldu yine hala artık gerçekten '
  + 'sahne final başladı bitti bekliyorum sevdim beğendim tavsiye ederim yorum '
  + 'puan resim video kapak izliyorum izledi seyret bakın işte oldukça').split(' '));
const TR_EK = /\p{L}+(lar|ler|dır|dir|dur|dür|ıyor|iyor|uyor|üyor|acak|ecek|mış|miş|muş|müş|ları|leri|ması|mesi|sınız|siniz|dığı|diği|lık|lik|luk|lük|nır|nir|nur|nür|maz|mez)\b/iu;

/** 0..3 arası Türkçe kanıt puanı. */
function turkcePuan(sade) {
  const kucuk = sade.toLocaleLowerCase('tr');
  const kelimeler = kucuk.replace(/[^\p{L}\s]/gu, ' ').split(/\s+/).filter(Boolean);
  const vurus = kelimeler.filter((k) => TR_KELIME.has(k)).length;
  let puan = 0;
  if (TR_HARF.test(sade)) puan += 2;
  else if (TR_HARF_GENIS.test(sade)) puan += 1;
  if (vurus >= 2) puan += 2;
  else if (vurus === 1) puan += 1;
  if (TR_EK.test(kucuk)) puan += 1;
  return { puan, vurus };
}

// ---------- Google dil tespiti (gönderi çevirisiyle AYNI uç) ----------
const CEVIRI_UCU = 'https://translate.googleapis.com/translate_a/single';

async function disTespitDene(metin) {
  const url = `${CEVIRI_UCU}?client=gtx&sl=auto&tl=en&dt=t&q=${encodeURIComponent(metin.slice(0, 1500))}`;
  let cevap;
  try {
    cevap = await fetch(url, { signal: AbortSignal.timeout(20000) });
  } catch (e) { return { durum: 'yeniden', not: e.name || e.message }; }
  if (cevap.status === 429 || cevap.status >= 500) return { durum: 'yeniden', not: `http ${cevap.status}` };
  if (!cevap.ok) return { durum: 'hata', not: `http ${cevap.status}` };
  let veri;
  try { veri = await cevap.json(); } catch { return { durum: 'yeniden', not: 'bozuk json' }; }
  const dil = typeof veri?.[2] === 'string' ? veri[2].toLowerCase().split('-')[0] : null;
  const guven = typeof veri?.[6] === 'number' ? veri[6] : null;
  return dil ? { durum: 'tamam', dil, guven } : { durum: 'hata', not: 'dil yok' };
}

/** 429/5xx/ağ hatasında üstel geri çekilme: 2s, 4s, 8s, 16s, 32s */
async function disTespit(metin) {
  for (let deneme = 0; deneme < 6; deneme += 1) {
    const s = await disTespitDene(metin);
    if (s.durum !== 'yeniden') return s;
    if (deneme === 5) return { durum: 'hata', not: s.not };
    const geri = 2000 * 2 ** deneme;
    log(`  geri cekilme ${geri / 1000}s (${s.not})`);
    await bekle(geri);
  }
  return { durum: 'hata' };
}

// ---------- adım 1: boş kaynak_dil ----------
async function bosDilleriIsle() {
  const once = Number(psql("SELECT count(*) FROM yorumlar WHERE kaynak_dil IS NULL;"));
  log(`bos kaynak_dil: ${once}`);

  if (TESPIT_UCU) {
    if (!TOKEN) { log('  ADMIN_TOKEN yok — /admin/dil-tespit atlandi'); } else {
      const c = await fetch(`${API}/admin/dil-tespit`, {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'x-admin-token': TOKEN },
        body: JSON.stringify({ limit: 20000 }),
      });
      const g = c.ok ? await c.json() : { hata: c.status };
      log(`  /admin/dil-tespit → ${JSON.stringify(g)}`);
    }
  }

  const kalan = psql(
    `SELECT id, ${TEK_SATIR} FROM yorumlar
      WHERE kaynak_dil IS NULL ORDER BY id LIMIT ${LIMIT};`,
    { satirlar: true },
  );
  const oneriler = [];
  const dokunulmaz = [];
  for (const [id, metin] of kalan) {
    const sade = sadeMetin(metin);
    if (harfSayisi(sade) < 3) {
      dokunulmaz.push({ id, metin, neden: 'dil tasimayan metin (emoji/baglanti/kisa)' });
      continue;
    }
    const d = await disTespit(sade);
    await bekle(BEKLEME);
    if (d.durum !== 'tamam') {
      dokunulmaz.push({ id, metin, neden: `dis tespit basarisiz: ${d.not || ''}` });
      continue;
    }
    const { puan } = turkcePuan(sade);
    if (ozelAdGibi(sade) && puan === 0) {
      dokunulmaz.push({ id, metin, neden: `ozel ad gibi, dil tasimiyor (dis=${d.dil})` });
      continue;
    }
    // Türkçe iddiası yerel kanıt istemez ama diğer dillerde tek başına
    // Google'a güvenmeyelim: en az 2 kelime ve 8 harf olsun.
    const yeter = d.dil === 'tr' ? puan >= 1 || sade.split(/\s+/).length >= 2
      : harfSayisi(sade) >= 8 && sade.split(/\s+/).length >= 2;
    if (!yeter) {
      dokunulmaz.push({ id, metin, neden: `zayif kanit (dis=${d.dil}, trpuan=${puan})` });
      continue;
    }
    oneriler.push({ id, metin, eski: null, yeni: d.dil, dis: d.dil, trpuan: puan });
  }
  return { once, oneriler, dokunulmaz };
}

// ---------- adım 2: yanlış etiketli kayıtlar ----------
async function yanlisEtiketleriIsle() {
  const kosul = KAYNAK ? `kaynak_dil = ${q(KAYNAK)}` : 'kaynak_dil IS NOT NULL';
  const satirlar = psql(
    `SELECT id, kaynak_dil, ${TEK_SATIR} FROM yorumlar
      WHERE ${kosul} AND metin IS NOT NULL ORDER BY id LIMIT ${LIMIT};`,
    { satirlar: true },
  );
  log(`denetlenecek etiketli kayit: ${satirlar.length} (kaynak=${KAYNAK || 'tumu'})`);
  const oneriler = [];
  const supheli = [];
  for (const [id, eski, metin] of satirlar) {
    const sade = sadeMetin(metin);
    if (harfSayisi(sade) < 6) continue;         // kısa metinde tespit güvenilmez
    const { puan, vurus } = turkcePuan(sade);
    // Ön eleme: yerel Türkçe kanıtı yoksa dış istek harcama (etiket zaten 'en').
    // --onelemesiz ile kapatılır: her kayda dış tespit sorulur (ölçüm/denetim).
    if (!ARG.onelemesiz && eski !== 'tr' && puan === 0) continue;
    const d = await disTespit(sade);
    await bekle(BEKLEME);
    if (d.durum !== 'tamam' || d.dil === eski) continue;
    const kayit = {
      id, metin, eski, yeni: d.dil, dis: d.dil, trpuan: puan, vurus,
    };
    // KURAL: yalnız iki sinyal aynı dili söylerse değiştir.
    if (d.dil === 'tr' && puan >= 2) oneriler.push(kayit);
    else if (ONAY.has(Number(id))) {
      // Elle okunup onaylanmış. Yalnız TARAYICININ "etiket yanlış" dediği
      // kayıtlar onaylanabilir; rastgele bir id buraya giremez. Dil, metni
      // okuyan kişinin verdiği koddur (dış tespit romaji/karışık metinlerde
      // şaşabiliyor: "it's okey ..." → ja).
      oneriler.push({ ...kayit, yeni: ONAY.get(Number(id)), onayli: true });
    } else supheli.push(kayit);
  }
  return { oneriler, supheli };
}

// ---------- yazma ----------
function uygula(oneriler) {
  if (!oneriler.length) return { guncellenen: 0, silinen: 0 };
  const idler = oneriler.map((o) => o.id);
  const diller = oneriler.map((o) => o.yeni);
  // Kaynak dil düzeltmesi + o metnin TÜM önbellek çevirilerinin silinmesi tek
  // işlemde. Neden hepsi: çeviri ucu `sl=kaynak_dil` ile çağrılıyor, yani
  // kaynak dil yanlışken üretilmiş her hedef dil de yanlış üretilmiştir
  // (Türkçe metni "es" sanıp Türkçeye çevirmek → "kaçarsınız"). Silinen
  // satırlar ceviri_doldur.js ile doğru kaynak dilden yeniden üretilir.
  const sql = `BEGIN;
CREATE TEMP TABLE _duzeltme (id int, dil text) ON COMMIT DROP;
INSERT INTO _duzeltme (id, dil)
  SELECT * FROM unnest(ARRAY[${idler.join(',')}]::int[],
                       ARRAY[${diller.map(q).join(',')}]::text[]);
UPDATE yorumlar y SET kaynak_dil = d.dil FROM _duzeltme d WHERE y.id = d.id;
DELETE FROM metin_cevirileri c
 USING yorumlar y, _duzeltme d
 WHERE y.id = d.id AND c.ozet = md5(btrim(y.metin));
COMMIT;`;
  const cikti = psql(sql);
  return { cikti, guncellenen: idler.length };
}

/** Kaynak diliyle hedef dili aynı olan (anlamsız) önbellek satırlarını sayar. */
function kendineCeviriSayisi() {
  return Number(psql(
    `SELECT count(*) FROM metin_cevirileri c
      WHERE EXISTS (SELECT 1 FROM yorumlar y
                     WHERE y.metin IS NOT NULL AND md5(btrim(y.metin)) = c.ozet
                       AND y.kaynak_dil = c.dil);`,
  ));
}

// ---------- ana akış ----------
(async () => {
  const bos = await bosDilleriIsle();
  const yanlis = await yanlisEtiketleriIsle();
  const tumOneriler = [...bos.oneriler, ...yanlis.oneriler];

  const kisa = (m) => String(m).replace(/\s+/g, ' ').slice(0, 70);
  log('--- BOS DIL: oneri ---');
  for (const o of bos.oneriler) log(`  #${o.id} → ${o.yeni}  | ${kisa(o.metin)}`);
  log('--- BOS DIL: dokunulmayan ---');
  for (const o of bos.dokunulmaz) log(`  #${o.id} (${o.neden}) | ${kisa(o.metin)}`);
  log(`--- YANLIS ETIKET: ${yanlis.oneriler.length} oneri ---`);
  for (const o of yanlis.oneriler) log(`  #${o.id} ${o.eski} → ${o.yeni} (trpuan ${o.trpuan}${o.onayli ? ', elle onayli' : ''}) | ${kisa(o.metin)}`);
  log(`--- YANLIS ETIKET: ${yanlis.supheli.length} supheli (tek sinyal, DEGISTIRILMEDI) ---`);
  for (const o of yanlis.supheli) log(`  #${o.id} ${o.eski} ?→ ${o.yeni} (trpuan ${o.trpuan}) | ${kisa(o.metin)}`);

  if (ARG.json) {
    fs.writeFileSync(ARG.json, JSON.stringify({ bos, yanlis }, null, 2));
    log(`oneriler yazildi: ${ARG.json}`);
  }

  log(`kendine ceviri satiri (once): ${kendineCeviriSayisi()}`);
  if (!UYGULA) {
    log(`KURU CALISMA — ${tumOneriler.length} kayit degistirilecekti. --uygula ile yaz.`);
    return;
  }
  const sonuc = uygula(tumOneriler);
  log(`UYGULANDI — guncellenen ${sonuc.guncellenen}`);
  log(sonuc.cikti || '');
  log(`kendine ceviri satiri (sonra): ${kendineCeviriSayisi()}`);
  log(`bos kaynak_dil (sonra): ${psql('SELECT count(*) FROM yorumlar WHERE kaynak_dil IS NULL;')}`);
})().catch((e) => { console.error('COKME:', e); process.exit(1); });
