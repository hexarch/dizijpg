#!/usr/bin/env node
/**
 * Video altyazı üretici — konuşma tanıma (whisper.cpp) + çeviri.
 *
 * SUNUCUDA, HOST üzerinde çalışır (Docker'ın İÇİNDE değil): whisper.cpp ikilisi
 * ve medya dosyaları host'ta duruyor. Veritabanına `docker exec dizijpg-db psql`
 * ile ulaşılır (DB dışarı port açmıyor).
 *
 * Akış (video başına):
 *   1. ffprobe   → süre + ses akışı var mı (yoksa 'sessiz', bir daha denenmez)
 *   2. ffmpeg    → 16 kHz mono WAV
 *   3. whisper   → zaman damgalı segmentler + kaynak dil tespiti
 *                  (VAD AÇIK: sessizlik atılır, damgalar konuşmaya oturur)
 *   4. çeviri    → kaynak 'tr' ise İngilizce, değilse Türkçe
 *                  (gönderi metni çevirisiyle AYNI kural, AYNI anahtarsız uç)
 *   5. yazma     → video_altyazilar + video_altyazi_durum='bitti'
 *
 * SUNUCUYU BOĞMAMA: ffmpeg/whisper `nice` ile düşük öncelikli koşar, aynı anda
 * TEK video işlenir ve iş parçacığı sayısı çekirdeğin yarısını geçmez. Site
 * yavaşlarsa --iplik düşürülür.
 *
 * Kullanım:
 *   node altyazi_uret.js --doldur              kuyruğu mevcut videolarla doldur
 *   node altyazi_uret.js --isle                kuyruğu işle (bitince çıkar)
 *   node altyazi_uret.js --isle --surekli      kuyruğu işle, boşsa bekle (servis)
 *   node altyazi_uret.js --durum               ilerleme özeti
 *   Seçenekler: --model base|small|medium  --iplik 8  --limit N  --yeniden
 *               --vadsiz  (VAD'ı kapatır; yalnız karşılaştırma/ölçüm için)
 */

import { execFile, execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// ---------- ayarlar ----------
const WHISPER_KOK = process.env.WHISPER_KOK || '/opt/altyazi/whisper.cpp';
const MEDYA_KOK = process.env.ALTYAZI_MEDYA_KOK
  || '/var/lib/docker/volumes/dizijpg_dizijpg_dosyalar/_data/medya';
const DB_KAP = process.env.ALTYAZI_DB_KAP || 'dizijpg-db';
const DB_KULLANICI = process.env.ALTYAZI_DB_KULLANICI || 'dizijpg';
const DB_AD = process.env.ALTYAZI_DB_AD || 'dizijpg';
const GECICI = process.env.ALTYAZI_GECICI || '/tmp/altyazi';

const args = process.argv.slice(2);
const bayrak = (ad) => args.includes(ad);
const deger = (ad, varsayilan) => {
  const i = args.indexOf(ad);
  return i >= 0 && args[i + 1] ? args[i + 1] : varsayilan;
};

const MODEL = deger('--model', 'base');
// Çekirdeğin yarısı: kalan yarısı siteye (api/db) ve komşu servislere kalır.
const IPLIK = parseInt(deger('--iplik', String(Math.max(2, Math.floor(os.cpus().length / 2)))), 10);
const LIMIT = parseInt(deger('--limit', '0'), 10) || 0;
const SUREKLI = bayrak('--surekli');
const YENIDEN = bayrak('--yeniden'); // 'hata' durumundakileri de yeniden dene

// whisper.cpp: BLAS'lı derleme varsa onu kullan (bu CPU'da AVX yok, BLAS hızlandırır)
const WHISPER_IKILI = [
  path.join(WHISPER_KOK, 'build-blas/bin/whisper-cli'),
  path.join(WHISPER_KOK, 'build/bin/whisper-cli'),
].find((p) => fs.existsSync(p));

const MODEL_YOLU = path.join(WHISPER_KOK, `models/ggml-${MODEL}.bin`);

/**
 * Konuşma etkinliği tespiti (VAD) modeli — TIMING'İN ANAHTARI.
 *
 * VAD'siz whisper, sessizlik/müzik bölümlerini komşu cümleye yazıyordu:
 * ilk segment DAİMA 0 ms'de başlıyor ve konuşma başlayana kadar ekranda
 * asılı kalıyordu. Kullanıcı şikâyeti tam buydu ("konuşma 10. saniyede ama
 * çeviri ilk saniyeden beri orada").
 *
 * Aynı video (m42-24ae48088df35659.mp4), aynı model (small), ölçüm:
 *   VAD'siz : [0.000 → 22.000] "Bir de Ömer'in deliler gibi sevdiği..."
 *   VAD'li  : [3.040 → 7.530]  "Gönül şanslı günündeyim de."   (hiç yoktu)
 *             [7.530 → 16.920] "Bir de Ömer'in deliler gibi sevdiği,"
 * Yani cümle GERÇEKTE 7,5. saniyede başlıyor; VAD'siz sürüm onu 0'dan
 * gösteriyordu. VAD ayrıca HIZLANDIRIYOR — sessizlik atıldığı için bu videoda
 * ses %74,9 kısaldı, süre 42,5 sn → 30,3 sn (%29 daha hızlı).
 *
 * Model yoksa üretim durmaz, VAD'siz (eski) davranışa düşer ve uyarır:
 *   models/download-vad-model.sh silero-v5.1.2
 */
const VAD_MODEL_YOLU = process.env.ALTYAZI_VAD_MODEL
  || path.join(WHISPER_KOK, 'models/ggml-silero-v5.1.2.bin');
const VAD_VAR = fs.existsSync(VAD_MODEL_YOLU) && !bayrak('--vadsiz');

// Yalnız bu biçimdeki dosya adları işlenir (yükleme ucu böyle üretir).
const DOSYA_KALIBI = /^m\d+-[0-9a-f]{6,32}\.(mp4|webm)$/;

// ---------- küçük yardımcılar ----------
const bekle = (ms) => new Promise((r) => setTimeout(r, ms));
const b64 = (s) => Buffer.from(String(s), 'utf8').toString('base64');
/** Postgres'e metin göndermenin tırnak-güvenli yolu: base64 → convert_from. */
const sqlMetin = (s) => (s === null || s === undefined
  ? 'NULL'
  : `convert_from(decode('${b64(s)}','base64'),'UTF8')`);

function gunluk(...m) {
  process.stdout.write(`[${new Date().toISOString()}] ${m.join(' ')}\n`);
}

/** psql'i `docker exec` ile çalıştırır; SQL stdin'den gider (uzun olabilir). */
function psql(sql, { satirlar = false } = {}) {
  const bayraklar = satirlar ? ['-tAF', ''] : ['-tA'];
  const cikti = execFileSync('docker', [
    'exec', '-i', DB_KAP,
    'psql', '-U', DB_KULLANICI, '-d', DB_AD,
    '-v', 'ON_ERROR_STOP=1', '-q', ...bayraklar, '-f', '-',
  ], { input: sql, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  if (!satirlar) return cikti;
  return cikti.split('\n').filter(Boolean).map((s) => s.split(''));
}

/** Komutu düşük öncelikli (nice) çalıştırır, çıktıyı toplar. */
function calistir(komut, komutArgs, { zamanAsimi = 60 * 60 * 1000 } = {}) {
  return new Promise((cozum, ret) => {
    execFile('nice', ['-n', '19', komut, ...komutArgs],
      { timeout: zamanAsimi, maxBuffer: 64 * 1024 * 1024 },
      (hata, stdout, stderr) => (hata ? ret(new Error(`${komut}: ${stderr || hata.message}`))
        : cozum({ stdout, stderr })));
  });
}

// ---------- 1. ses bilgisi ----------
async function sesBilgisi(dosyaYolu) {
  const { stdout } = await calistir('ffprobe', [
    '-v', 'error', '-show_entries', 'format=duration',
    '-select_streams', 'a', '-show_entries', 'stream=codec_name',
    '-of', 'json', dosyaYolu,
  ], { zamanAsimi: 60_000 });
  const j = JSON.parse(stdout);
  return {
    sureMs: Math.round(parseFloat(j.format?.duration || '0') * 1000) || 0,
    sesVar: Array.isArray(j.streams) && j.streams.length > 0,
  };
}

// ---------- 2. konuşma tanıma ----------
// Whisper konuşma DIŞI sesleri de yazar; bunlar altyazı değildir ve ekranda
// "[MÜZİK ÇALIYOR]" diye asılı kalırlardı. Üç süzgeç var:

/** Tümüyle noktalama/simge olan segment. */
const COP_KALIBI = /^[\s\-—_.*~"'`[\](){}<>♪♫]*$/;

/** Tamamı parantez/köşeli parantez içinde: sahne notu, konuşma değil.
 *  "[MÜZİK ÇALIYOR]", "(upbeat music)", "- (indistinct chatter)" → elenir.
 *  "(Bak) dedi." gibi cümle içinde parantez → ELENMEZ (sonu harfle biter). */
const SAHNE_NOTU = /^[-–—\s]*[[(][^)\]]*[)\]][\s.!?]*$/;

/** ♪ ile çevrili şarkı sözü satırı. */
const NOTA_KALIBI = /^[\s♪♫]*♪[\s\S]*♪[\s♪♫]*$/;

/** Parantezsiz gelen klasik whisper halüsinasyonları / kanal kapanışları. */
const MUZIK_KALIBI = /^[\s*]*(m[uü]zik|music|musique|música|музыка|applause|alk[ıi][şs]|laughter|g[uü]l[uü][şs]me|sessizlik|silence|noise|g[uü]r[uü]lt[uü]|inaudible|foreign|altyaz[ıi][\s:.]*(m\.?k\.?)?|amara\.org|thanks? for watching|abone ol(un)?|subscribe|www\.[^\s]+|https?:\/\/[^\s]+)[\s.!*]*$/i;

function segmentGecerli(metin) {
  const t = String(metin || '').trim();
  if (t.length < 2) return false;
  if (COP_KALIBI.test(t)) return false;
  if (SAHNE_NOTU.test(t)) return false;
  if (NOTA_KALIBI.test(t)) return false;
  if (MUZIK_KALIBI.test(t)) return false;
  return true;
}

/** Dil tespiti bu olasılığın altındaysa ses konuşma İÇERMİYOR sayılır.
 *  Ölçüm: gerçek konuşmada p≈0.97, yalnız müzik/gürültü olan videoda p≈0.26.
 *  Düşük güvende model cümle UYDURUYOR ("I don't think so!" gibi). */
const DIL_ESIGI = 0.40;

async function tani(wavYolu, cikisOnEk) {
  // --no-prints VERİLMEZ: dil olasılığı yalnız stderr'e yazılıyor, onu okuyoruz.
  const { stderr } = await calistir(WHISPER_IKILI, [
    '-m', MODEL_YOLU,
    '-f', wavYolu,
    '-t', String(IPLIK),
    '-oj', '-of', cikisOnEk,
    '--language', 'auto',
    // Konuşma dışı ses atılır → zaman damgaları GERÇEK konuşmaya oturur.
    // -vsd 200: 200 ms sessizlik cümleyi böler (varsayılan 100 ms fazla
    // bölüyor). -vp 100: konuşmanın ilk/son hecesi kırpılmasın diye pay.
    ...(VAD_VAR ? [
      '--vad', '-vm', VAD_MODEL_YOLU,
      '-vsd', '200', '-vp', '100',
    ] : []),
  ], { zamanAsimi: 2 * 60 * 60 * 1000 });

  const olasilikEsleme = /auto-detected language:\s*(\S+)\s*\(p\s*=\s*([\d.]+)\)/
    .exec(stderr || '');
  const dilOlasilik = olasilikEsleme ? parseFloat(olasilikEsleme[2]) : 1;

  const j = JSON.parse(fs.readFileSync(`${cikisOnEk}.json`, 'utf8'));
  const kaynakDil = j.result?.language || null;
  if (dilOlasilik < DIL_ESIGI) return { kaynakDil, dilOlasilik, segmentler: [] };

  const ham = (j.transcription || []).map((s) => ({
    baslangicMs: Math.round((s.offsets?.from ?? 0)),
    bitisMs: Math.round((s.offsets?.to ?? 0)),
    metin: String(s.text || '').trim(),
  }));
  return {
    kaynakDil,
    dilOlasilik,
    segmentler: ham.filter((s) => segmentGecerli(s.metin)),
  };
}

// ---------- 3. çeviri (mevcut anahtarsız uç, backend ile AYNI) ----------
const CEVIRI_UCU = 'https://translate.googleapis.com/translate_a/single';
const CEVIRI_AZAMI = 4000;

async function metniCevir(metin, hedefDil, kaynakDil) {
  const kirp = String(metin || '').slice(0, CEVIRI_AZAMI);
  if (kirp.trim().length < 2) return null;
  const url = `${CEVIRI_UCU}?client=gtx&sl=${encodeURIComponent(kaynakDil || 'auto')}`
    + `&tl=${encodeURIComponent(hedefDil)}&dt=t&q=${encodeURIComponent(kirp)}`;
  try {
    const c = await fetch(url, { signal: AbortSignal.timeout(15_000) });
    if (!c.ok) return null;
    const veri = await c.json();
    if (!Array.isArray(veri?.[0])) return null;
    const metinler = veri[0].map((p) => (Array.isArray(p) ? p[0] : '')).join('');
    return metinler.trim() || null;
  } catch (_) {
    return null;
  }
}

/**
 * Segmentleri zaman damgalarını KORUYARAK çevirir. Her segment zaten bir
 * cümledir; öbek halinde (8 paralel) çevrilir — bağlam cümle içinde korunur,
 * istek sayısı düşer. Aynı metin `metin_cevirileri` önbelleğinden okunur
 * (Instagram aktarımlarında aynı replik onlarca videoda tekrar ediyor).
 */
async function segmentleriCevir(segmentler, hedefDil, kaynakDil) {
  if (!segmentler.length) return;

  // Önbellek: benzersiz metinler için tek sorgu
  const benzersiz = [...new Set(segmentler.map((s) => s.metin))];
  const secim = benzersiz
    .map((m) => `(${sqlMetin(m)})`).join(',');
  const onbellek = new Map();
  try {
    const satirlar = psql(
      `SELECT g.m, c.metin FROM (VALUES ${secim}) AS g(m)
         JOIN metin_cevirileri c ON c.ozet = md5(btrim(g.m)) AND c.dil = '${hedefDil}';`,
      { satirlar: true });
    for (const [ham, ceviri] of satirlar) onbellek.set(ham, ceviri);
  } catch (_) { /* önbellek okunamadıysa hepsi taze çevrilir */ }

  const eksik = benzersiz.filter((m) => !onbellek.has(m));
  const OBEK = 8;
  for (let i = 0; i < eksik.length; i += OBEK) {
    const dilim = eksik.slice(i, i + OBEK);
    const sonuclar = await Promise.all(
      dilim.map((m) => metniCevir(m, hedefDil, kaynakDil)));
    dilim.forEach((m, j) => { if (sonuclar[j]) onbellek.set(m, sonuclar[j]); });
  }

  // Yeni çevirileri önbelleğe yaz (bir daha dışarı sorulmasın)
  const yeni = eksik.filter((m) => onbellek.has(m));
  if (yeni.length) {
    const satirlar = yeni.map((m) =>
      `(md5(btrim(${sqlMetin(m)})), '${hedefDil}', ${sqlMetin(onbellek.get(m))})`).join(',');
    try {
      psql(`INSERT INTO metin_cevirileri (ozet, dil, metin) VALUES ${satirlar}
            ON CONFLICT (ozet, dil) DO NOTHING;`);
    } catch (_) { /* önbelleğe yazamamak işi bozmaz */ }
  }

  for (const s of segmentler) s.ceviri = onbellek.get(s.metin) || null;
}

// ---------- 4. tek videoyu işle ----------
async function videoIsle(medya) {
  const dosya = path.basename(medya);
  const tamYol = path.join(MEDYA_KOK, dosya);
  const basladi = Date.now();

  if (!fs.existsSync(tamYol)) {
    durumYaz(medya, { durum: 'hata', hata: 'dosya yok' });
    return 'yok';
  }

  const { sureMs, sesVar } = await sesBilgisi(tamYol);
  if (!sesVar) {
    durumYaz(medya, { durum: 'sessiz', sureMs, islemMs: Date.now() - basladi });
    return 'sessiz';
  }

  fs.mkdirSync(GECICI, { recursive: true });
  const wav = path.join(GECICI, `${dosya}.wav`);
  const onEk = path.join(GECICI, dosya);
  try {
    await calistir('ffmpeg', [
      '-y', '-v', 'error', '-i', tamYol,
      '-ar', '16000', '-ac', '1', '-c:a', 'pcm_s16le', wav,
    ], { zamanAsimi: 10 * 60 * 1000 });

    const { kaynakDil, segmentler } = await tani(wav, onEk);
    if (!segmentler.length) {
      durumYaz(medya, {
        durum: 'sessiz', kaynakDil, sureMs, islemMs: Date.now() - basladi,
      });
      return 'sessiz';
    }

    // Hedef dil: kaynak Türkçe ise İngilizce, değilse Türkçe.
    const hedefDil = kaynakDil === 'tr' ? 'en' : 'tr';
    await segmentleriCevir(segmentler, hedefDil, kaynakDil);

    const satirlar = segmentler.map((s, i) => `(${sqlMetin(medya)}, ${i}, `
      + `${s.baslangicMs}, ${Math.max(s.bitisMs, s.baslangicMs + 300)}, `
      + `${sqlMetin(s.ceviri || s.metin)}, ${sqlMetin(s.metin)}, `
      + `${kaynakDil ? `'${kaynakDil.replace(/[^a-z-]/gi, '')}'` : 'NULL'}, '${hedefDil}')`).join(',\n');

    psql(`BEGIN;
DELETE FROM video_altyazilar WHERE medya = ${sqlMetin(medya)};
INSERT INTO video_altyazilar
  (medya, sira, baslangic_ms, bitis_ms, metin, orijinal, kaynak_dil, hedef_dil)
VALUES
${satirlar};
COMMIT;`);

    durumYaz(medya, {
      durum: 'bitti',
      kaynakDil,
      hedefDil,
      segmentSayi: segmentler.length,
      sureMs,
      islemMs: Date.now() - basladi,
    });
    return 'bitti';
  } finally {
    for (const p of [wav, `${onEk}.json`]) {
      try { fs.unlinkSync(p); } catch (_) { /* zaten yok */ }
    }
  }
}

function durumYaz(medya, {
  durum, kaynakDil = null, hedefDil = null, segmentSayi = 0,
  sureMs = null, islemMs = null, hata = null,
}) {
  const dil = (d) => (d ? `'${String(d).replace(/[^a-z-]/gi, '')}'` : 'NULL');
  psql(`INSERT INTO video_altyazi_durum
      (medya, durum, kaynak_dil, hedef_dil, segment_sayi, sure_ms, islem_ms, hata, deneme, guncelleme)
    VALUES (${sqlMetin(medya)}, '${durum}', ${dil(kaynakDil)}, ${dil(hedefDil)},
            ${segmentSayi}, ${sureMs === null ? 'NULL' : sureMs},
            ${islemMs === null ? 'NULL' : islemMs}, ${sqlMetin(hata)}, 1, now())
    ON CONFLICT (medya) DO UPDATE SET
      durum = EXCLUDED.durum, kaynak_dil = EXCLUDED.kaynak_dil,
      hedef_dil = EXCLUDED.hedef_dil, segment_sayi = EXCLUDED.segment_sayi,
      sure_ms = EXCLUDED.sure_ms, islem_ms = EXCLUDED.islem_ms,
      hata = EXCLUDED.hata, deneme = video_altyazi_durum.deneme + 1,
      guncelleme = now();`);
}

// ---------- 5. kuyruk ----------
/** Gönderilerde geçen TÜM videoları kuyruğa alır (zaten olanlara dokunmaz). */
function kuyrugaDoldur() {
  psql(`INSERT INTO video_altyazi_durum (medya, durum)
        SELECT DISTINCT m, 'bekliyor'
          FROM (SELECT unnest(medya) AS m FROM yorumlar WHERE medya IS NOT NULL) t
         WHERE m LIKE '/medya/%.mp4' OR m LIKE '/medya/%.webm'
        ON CONFLICT (medya) DO NOTHING;`);
  const [[bekleyen]] = psql(
    `SELECT count(*) FROM video_altyazi_durum WHERE durum = 'bekliyor';`,
    { satirlar: true });
  gunluk(`kuyruk dolduruldu; bekleyen: ${bekleyen}`);
}

function siradaki() {
  const durumlar = YENIDEN ? `('bekliyor','hata')` : `('bekliyor')`;
  const satirlar = psql(
    `SELECT medya FROM video_altyazi_durum
      WHERE durum IN ${durumlar} AND deneme < 3
      ORDER BY olusturma LIMIT 1;`, { satirlar: true });
  return satirlar.length ? satirlar[0][0] : null;
}

function ozet() {
  const satirlar = psql(
    `SELECT durum, count(*), coalesce(sum(segment_sayi),0),
            coalesce(round(sum(islem_ms)/1000.0),0), coalesce(round(sum(sure_ms)/1000.0),0)
       FROM video_altyazi_durum GROUP BY durum ORDER BY durum;`, { satirlar: true });
  gunluk('durum | video | segment | islem_sn | video_sn');
  for (const s of satirlar) gunluk(s.join(' | '));
}

// ---------- ana ----------
async function ana() {
  if (bayrak('--durum')) { ozet(); return; }
  if (bayrak('--doldur')) { kuyrugaDoldur(); if (!bayrak('--isle')) return; }
  if (!bayrak('--isle')) {
    gunluk('kullanım: --doldur | --isle [--surekli] | --durum');
    return;
  }
  if (!WHISPER_IKILI) throw new Error(`whisper-cli bulunamadı: ${WHISPER_KOK}`);
  if (!fs.existsSync(MODEL_YOLU)) throw new Error(`model yok: ${MODEL_YOLU}`);
  gunluk(`işçi başladı — model=${MODEL} iplik=${IPLIK} ikili=${WHISPER_IKILI}`);
  gunluk(VAD_VAR
    ? `VAD açık — ${VAD_VAR ? VAD_MODEL_YOLU : ''}`
    : `UYARI: VAD modeli yok (${VAD_MODEL_YOLU}) — zaman damgaları sessizliğe `
      + 'kayacak. Kur: models/download-vad-model.sh silero-v5.1.2');

  // Önceki çalışma yarıda kesildiyse (sunucu yeniden başladı, işçi öldürüldü)
  // 'isleniyor'da asılı kalan işler bir daha hiç seçilmezdi. En uzun video
  // bile 2 saatten kısa sürer; bu eşiğin üstündekiler kesin ölmüştür.
  psql(`UPDATE video_altyazi_durum SET durum='bekliyor'
         WHERE durum='isleniyor' AND guncelleme < now() - interval '2 hours';`);

  let islenen = 0;
  for (;;) {
    const medya = siradaki();
    if (!medya) {
      if (!SUREKLI) { gunluk(`kuyruk boş — toplam ${islenen} video işlendi`); break; }
      await bekle(30_000);
      continue;
    }
    // Aynı medyayı ikinci bir işçi kapmasın + kesilirse 'isleniyor'da kalmasın
    psql(`UPDATE video_altyazi_durum SET durum='isleniyor', guncelleme=now()
           WHERE medya = ${sqlMetin(medya)};`);
    const t0 = Date.now();
    try {
      const sonuc = await videoIsle(medya);
      gunluk(`${medya} → ${sonuc} (${Math.round((Date.now() - t0) / 1000)} sn)`);
    } catch (e) {
      gunluk(`${medya} → HATA: ${e.message.slice(0, 300)}`);
      try {
        durumYaz(medya, { durum: 'hata', hata: e.message.slice(0, 500) });
      } catch (_) { /* DB de gittiyse sonraki turda görülür */ }
    }
    islenen++;
    if (LIMIT && islenen >= LIMIT) { gunluk(`--limit ${LIMIT} doldu`); break; }
    // Nefes payı: CPU'yu sürekli doyurmayalım, site öncelikli kalsın.
    await bekle(1500);
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  ana().catch((e) => { gunluk('ÖLÜMCÜL:', e.message); process.exit(1); });
}

export { segmentGecerli, MUZIK_KALIBI, DOSYA_KALIBI };
