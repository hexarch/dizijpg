#!/usr/bin/env node
/**
 * `seo_talep_dizi` tazeleyici — bölüm haritasının TALEP dalının kaynağı.
 *
 * ---------------------------------------------------------------------------
 * NE İŞE YARIYOR
 * ---------------------------------------------------------------------------
 * Bölüm site haritası dizi düzeyinde kesiliyor (`SITEMAP_BOLUM_SORGU`). Beşinci
 * dal (29 Ağu 2026) "dizi yüksek talepli listede mi" diye soruyor ve o listeyi
 * BU BETİK yazıyor. Liste zamanla değişir (yeni diziler puan kazanır, eskiler
 * düşer); markdown bir rapor veri kaynağı olamaz, koda gömülü 250 kimlik ise
 * her tazelemede DAĞITIM gerektirirdi.
 *
 * KAYNAK: TMDB `/discover/tv`
 *   sort_by=vote_average.desc & vote_count.gte=1000 & language=tr-TR
 * Oy tabanı ŞART: ham puan sıralaması 3 oylu bilinmeyen yapımları getirir
 * (IMDb'nin 25.000 oy şartının bizdeki karşılığı). Doğrulama: 29 Ağu koşusunda
 * 1. sıra Breaking Bad — IMDb Top 250 Dizi ile örtüşüyor.
 *
 * ---------------------------------------------------------------------------
 * KULLANIM
 * ---------------------------------------------------------------------------
 *   docker cp araclar/seo_talep_dizi_tazele.js dizijpg-api:/app/
 *   docker exec -w /app dizijpg-api node seo_talep_dizi_tazele.js         # KURU
 *   docker exec -w /app dizijpg-api node seo_talep_dizi_tazele.js --yaz   # yazar
 *
 * Bayraklar:
 *   --yaz          tabloyu gerçekten değiştirir (varsayılan: yalnız rapor)
 *   --adet=N       kaç dizi alınacak (varsayılan 250)
 *   --enaz=N       yazma emniyeti: bundan az satır çekildiyse HİÇBİR ŞEY yazma
 *                  (varsayılan 200)
 *
 * SIKLIK: ayda bir yeter. Her tazeleme haritanın ~20 binlik bir dilimini
 * oynatır; Google'ı gereksiz yere yeniden taramaya zorlamak istemiyoruz.
 * SEO-YAPILACAKLAR §12 ölçüm ritüelinin parçası.
 *
 * ---------------------------------------------------------------------------
 * İKİ EMNİYET — VE NEDEN GEREKLİ
 * ---------------------------------------------------------------------------
 * 1. YARIM YANITTA YAZMA YOK. Betik TAM DEĞİŞİM yapıyor (listeden düşen dizi
 *    tablodan da düşüyor). TMDB bir sayfada 500 dönerse ve biz eldekini
 *    yazsaydık tablo boşalır, bölüm haritası 25 binden 5 bine düşer ve bunu
 *    kimse fark etmezdi. `--enaz` bu senaryoyu imkânsız kılıyor.
 * 2. DÜŞENLER ADIYLA LOGLANIR. "Sessiz kesme yok" kuralı: bir dizinin
 *    listeden düşmesi onun BÜTÜN bölüm URL'lerinin haritadan çıkması demek.
 *
 * DÜŞEN DİZİNİN KAZANAN BÖLÜMÜ ÖKSÜZ KALMAZ: `seo_kazanan_bolum` AYRI bir
 * muafiyet dalı ve o tablodan satır SİLİNMİYOR. İki tablo tam da bunun için
 * birbirini tamamlıyor — talep listesi DEĞİŞKEN, kazanan listesi KALICI.
 *
 * TEK İŞLEM: silme + yazma aynı transaction'da. Yarıda kalırsa tablo eski
 * hâlinde kalır; harita hiçbir an "yarım liste" görmez.
 */
import pg from 'pg';

const { DATABASE_URL, TMDB_TOKEN } = process.env;
if (!DATABASE_URL || !TMDB_TOKEN) {
  console.error('DATABASE_URL ve TMDB_TOKEN gerekli');
  process.exit(1);
}

const KAYNAK = 'tmdb_top250_tv';
const OY_TABANI = 1000;
const SAYFA_BOYU = 20;          // TMDB discover sayfa başına 20 sonuç verir
const BEKLEME_MS = 300;         // TMDB hız sınırına saygı (sayfalar arası)

function bayrak(ad, varsayilan) {
  const e = process.argv.slice(2).find((a) => a.startsWith(`--${ad}=`));
  return e ? Number(e.split('=')[1]) : varsayilan;
}
const YAZ = process.argv.includes('--yaz');
const ADET = bayrak('adet', 250);
const ENAZ = bayrak('enaz', 200);

const bekle = (ms) => new Promise((r) => { setTimeout(r, ms); });

async function tmdb(yol) {
  const y = await fetch(`https://api.themoviedb.org/3${yol}`, {
    headers: { Authorization: `Bearer ${TMDB_TOKEN}`, accept: 'application/json' },
  });
  if (!y.ok) throw new Error(`TMDB ${y.status} — ${yol}`);
  return y.json();
}

/** Listeyi TMDB'den çeker. Hata FIRLATIR — yarım liste yazılmasın. */
async function listeCek() {
  const ogeler = [];
  const gorulen = new Set();
  const sayfaAdedi = Math.ceil(ADET / SAYFA_BOYU);
  for (let sayfa = 1; sayfa <= sayfaAdedi; sayfa++) {
    const veri = await tmdb('/discover/tv?language=tr-TR&sort_by=vote_average.desc'
      + `&vote_count.gte=${OY_TABANI}&page=${sayfa}`);
    for (const r of veri.results || []) {
      // TMDB sayfalamasında aynı yapım iki sayfada birden çıkabiliyor
      // (29 Ağu koşusunda SPY×FAMILY 60. ve 61. sırada geldi). Tablo tekil.
      if (!Number.isInteger(r?.id) || gorulen.has(r.id)) continue;
      gorulen.add(r.id);
      ogeler.push({
        tmdb_id: r.id,
        ad: String(r.name || r.original_name || '').slice(0, 200),
        puan: Number(r.vote_average) || null,
        oy: Number(r.vote_count) || null,
        sira: ogeler.length + 1,
      });
      if (ogeler.length >= ADET) return ogeler;
    }
    await bekle(BEKLEME_MS);
  }
  return ogeler;
}

async function ana() {
  const havuz = new pg.Pool({ connectionString: DATABASE_URL });
  try {
    const yeni = await listeCek();
    const { rows: eskiler } = await havuz.query(
      'SELECT tmdb_id, ad FROM seo_talep_dizi');
    const eskiHarita = new Map(eskiler.map((r) => [r.tmdb_id, r.ad]));
    const yeniKume = new Set(yeni.map((o) => o.tmdb_id));
    const eklenen = yeni.filter((o) => !eskiHarita.has(o.tmdb_id));
    const dusen = eskiler.filter((r) => !yeniKume.has(r.tmdb_id));

    console.log(`çekilen=${yeni.length} mevcut=${eskiler.length}`
      + ` eklenen=${eklenen.length} düşen=${dusen.length}`);
    // SESSİZ KESME YOK: düşen dizi = tüm bölüm URL'lerinin haritadan çıkması.
    for (const d of dusen) console.log(`  DÜŞEN  ${d.tmdb_id} ${d.ad}`);
    for (const e of eklenen) console.log(`  EKLENEN ${e.tmdb_id} ${e.ad}`);

    if (yeni.length < ENAZ) {
      console.error(`YAZILMADI: ${yeni.length} < --enaz=${ENAZ}.`
        + ' Yarım TMDB yanıtı tabloyu boşaltıp haritayı 25 binden 5 bine'
        + ' düşürebilirdi. Sorunu bulup yeniden koştur.');
      process.exitCode = 1;
      return;
    }
    if (!YAZ) {
      console.log('KURU KOŞU — hiçbir şey yazılmadı. Yazmak için: --yaz');
      return;
    }

    const istemci = await havuz.connect();
    try {
      await istemci.query('BEGIN');
      // TAM DEĞİŞİM tek işlemde: harita hiçbir an yarım liste görmez.
      await istemci.query('DELETE FROM seo_talep_dizi');
      for (const o of yeni) {
        await istemci.query(
          `INSERT INTO seo_talep_dizi
             (tmdb_id, ad, puan, oy, sira, kaynak, olcum_gunu, guncellendi)
           VALUES ($1, $2, $3, $4, $5, $6, current_date, now())`,
          [o.tmdb_id, o.ad, o.puan, o.oy, o.sira, KAYNAK],
        );
      }
      await istemci.query('COMMIT');
    } catch (e) {
      await istemci.query('ROLLBACK').catch(() => {});
      throw e;
    } finally {
      istemci.release();
    }
    console.log(`✓ seo_talep_dizi yazıldı: ${yeni.length} dizi`);
    console.log('  ŞİMDİ: harita 6 saatlik TTL ile tazelenir; hemen görmek için'
      + ' /sitemap-bolum-1.xml isteğini bekle ya da API yeniden başlat.');
  } finally {
    await havuz.end();
  }
}

ana().catch((e) => { console.error(e); process.exit(1); });
