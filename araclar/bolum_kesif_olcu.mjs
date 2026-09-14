// dizi.jpg — BÖLÜM KEŞİF ÖLÇÜMÜ (bağımsız, SALT OKUMA).
//
// NEDEN VAR (14 Eylül 2026):
// GSC'de bölüm ailesi tıklamaların %71'ini getiriyor (TO %5,86) ama panelin
// 211/250 URL'si "Google tarafından bilinmiyor" diyor. Yani sorun sıralama
// değil, KEŞİF. İki hipotez düzeltiliyor:
//   (A) Dizi sayfası haritadaki bölümlerin ancak bir kısmına bağlantı veriyor
//       (tavan var), kalanına yalnız bölüm→bölüm ZİNCİRİ üzerinden gidiliyor.
//   (B) Bazı dillerde (sw/am/hi/ar) bölüm sayfasının adı ve özeti YOK ama
//       sayfa yine de indekslenmeye açık — ince sayfa yığını.
//
// BU BETİK DÜZELTME YAPMAZ, ÖLÇER. Amaç: düzeltmeden ÖNCE ve SONRA aynı
// betiği koşup `--karsilastir` ile farkı görebilmek. Betik canlı siteye
// yalnız GET atar; hiçbir şey yazmaz.
//
// KULLANIM:
//   node araclar/bolum_kesif_olcu.mjs --json araclar/olcumler/bolum_kesif_2026-09-14.json
//   node araclar/bolum_kesif_olcu.mjs --karsilastir araclar/olcumler/bolum_kesif_2026-09-14.json
//
// SEÇENEKLER (hepsinin varsayılanı var):
//   --dizi N          iç bağlantı için örneklenecek dizi sayısı      (40)
//   --zincir-dizi N   zincir yürüyüşü yapılacak dizi sayısı           (8)
//   --hedef N         dizi başına kaç ulaşılamayan bölüm denensin     (2)
//   --adim N          zincir yürüyüşünde en fazla kaç sayfa çekilsin (30)
//   --dil-ornek N     dil ölçümü için kaç bölüm URL'si                (12)
//   --diller a,b,c    dil öneki kümesi        (tr,en,de,es,ar,hi,sw,am)
//   --es-zaman N      eşzamanlı istek                                  (2)
//   --bekle MS        istekler arası bekleme                        (200)
//   --tohum N         örnekleme tohumu — aynı tohum aynı örneklem  (20260914)
//   --json DOSYA      makine okunur anlık görüntü yaz
//   --karsilastir D   eski anlık görüntüyle farkı bas (tek başına da çalışır)
//
// ---------------------------------------------------------------------------
// ÖLÇÜM TUZAKLARI — hepsi bu depoda bir kez canımızı yaktı, sırayla:
//
// 1) SSR YALNIZ BOTA GİDER. nginx'teki `$og_bot` haritasında olmayan her UA
//    Flutter kabuğunu alır; kabukta tek bir <a> yoktur. İnsan UA'sıyla
//    ölçersen "0 iç bağlantı" görür ve olmayan bir arıza rapor edersin.
//    Bu yüzden her istek Googlebot UA'sı ile gider (bkz. UA sabiti).
//
// 2) `/dizi/<id>` TEK BAŞINA 404'TÜR. Dizi kökü `/icerik/tv/<id>`, bölüm ise
//    `/dizi/<id>/sezon/<n>/bolum/<m>`. Daha önce `/dizi/<id>` ile ölçülüp
//    "dizi sayfaları kırık" denmişti; değildi, yanlış adres denenmişti.
//
// 3) nginx'in bot yolunda `proxy_pass` bir DEĞİŞKEN içeriyor, bu durumda
//    `$args` düşebiliyor. Yani `?dil=de` sessizce yok sayılabilir ve sen
//    Türkçe sayfayı Almanca sanırsın. Dil ölçümü SORGU ile değil ÖNEK ile
//    yapılır: `/de/dizi/...`.
//
// 4) CLOUDFLARE UA TAKLİDİNİ IP/ASN İLE DOĞRULAR. Ev IP'sinden Googlebot
//    UA'sı ile istek 403 (ya da yönlendirme/challenge) yiyebilir. O zaman
//    site bozuk DEĞİLDİR, ÖLÇÜM bozuktur. Betik 403'leri ayrı sayar ve
//    raporun başına "ölçüm arızası" satırı basar; oranlar yalnız BAŞARILI
//    çekimler üzerinden hesaplanır ve payda raporlanır.
//
// 5) SİTE HARİTASI SOĞUKKEN YAVAŞ. `sitemap-bolum-1.xml` ~3 MB ve arka uç
//    onu üretiyor; ilk çekimde 40 sn'yi bulabiliyor (sıcakken 0,6 sn).
//    Bu yüzden harita zaman aşımı sayfalarınkinden çok daha cömert.
//
// 6) BAYAT .br TUZAĞI SAYFALARDA GEÇERLİ DEĞİL ama haritada dolaylı geçerli:
//    harita arka uçtan taze gelir, oysa dizi/bölüm sayfası Cloudflare
//    kenarından gelebilir. Bir düzeltmeden hemen sonra koşarsan "sonrası"
//    ölçümü eski kenar kopyasını görebilir. Dağıtımdan sonra en az bir tur
//    bekle, ya da farkı iki kez ölç.
// ---------------------------------------------------------------------------

import fs from 'node:fs';
import path from 'node:path';

// --- Sabitler ---------------------------------------------------------------

const KOK = 'https://dizijpg.com';

// TUZAK 1: SSR yalnız bu UA sınıfına açılır. Değiştirme.
const UA =
  'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)';

const HARITA_ZAMAN_ASIMI = 120_000; // TUZAK 5: soğuk harita 40 sn sürebiliyor
const SAYFA_ZAMAN_ASIMI = 45_000;

// Bölüm adresi deseni. Dil öneki isteğe bağlı (2-3 harf: tr/en/fil...).
const BOLUM_DESENI = /^\/(?:([a-z]{2,3})\/)?dizi\/(\d+)\/sezon\/(\d+)\/bolum\/(\d+)$/;

// --- Argümanlar -------------------------------------------------------------

const argv = process.argv.slice(2);
const arg = (ad, varsayilan) => {
  const i = argv.indexOf(ad);
  return i >= 0 && argv[i + 1] !== undefined ? argv[i + 1] : varsayilan;
};
const AYAR = {
  dizi: Number(arg('--dizi', 40)),
  zincirDizi: Number(arg('--zincir-dizi', 8)),
  hedef: Number(arg('--hedef', 2)),
  adim: Number(arg('--adim', 30)),
  dilOrnek: Number(arg('--dil-ornek', 12)),
  diller: String(arg('--diller', 'tr,en,de,es,ar,hi,sw,am')).split(','),
  esZaman: Number(arg('--es-zaman', 2)),
  bekle: Number(arg('--bekle', 200)),
  tohum: Number(arg('--tohum', 20260914)),
  json: arg('--json', null),
  karsilastir: arg('--karsilastir', null),
};

// --- Yardımcılar ------------------------------------------------------------

const uyu = (ms) => new Promise((r) => setTimeout(r, ms));

// Tekrarlanabilir örnekleme. Math.random olsaydı "öncesi" ve "sonrası" koşuları
// FARKLI dizileri ölçer, fark da düzeltmeden değil örneklemden gelirdi.
function rastgeleUret(tohum) {
  let s = tohum >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
}
function ornekle(dizi, n, rnd) {
  const k = dizi.slice();
  for (let i = k.length - 1; i > 0; i--) {
    const j = Math.floor(rnd() * (i + 1));
    [k[i], k[j]] = [k[j], k[i]];
  }
  return k.slice(0, n);
}

const yuzde = (pay, payda) => (payda ? (100 * pay) / payda : 0);
const b2 = (x) => Number(x.toFixed(2));

// --- Ağ katmanı -------------------------------------------------------------
// Sayaçlar rapora aynen basılır: ölçemediğimizi ölçmüş gibi göstermemek için.
const sayac = { istek: 0, ok: 0, engel403: 0, hata: 0, zamanAsimi: 0, bos: 0 };

async function cek(url, zamanAsimi = SAYFA_ZAMAN_ASIMI) {
  sayac.istek++;
  const iptal = new AbortController();
  const t = setTimeout(() => iptal.abort(), zamanAsimi);
  try {
    const y = await fetch(url, {
      headers: {
        'user-agent': UA,
        accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'accept-language': 'tr,en;q=0.8',
      },
      redirect: 'follow',
      signal: iptal.signal,
    });
    const metin = await y.text();
    // TUZAK 4: 403/503 = ölçüm arızası (CF bot doğrulaması), site arızası DEĞİL.
    if (y.status === 403 || y.status === 503) {
      sayac.engel403++;
      return { ok: false, durum: y.status, sebep: 'engel', metin: '' };
    }
    if (!y.ok) {
      sayac.hata++;
      return { ok: false, durum: y.status, sebep: 'http', metin: '' };
    }
    // Flutter kabuğu geldiyse SSR'ı GÖREMEDİK demektir (TUZAK 1'in sessiz hâli).
    if (metin.includes('flutter_bootstrap.js') || metin.includes('main.dart.js')) {
      sayac.bos++;
      return { ok: false, durum: y.status, sebep: 'kabuk', metin };
    }
    sayac.ok++;
    return { ok: true, durum: y.status, metin };
  } catch (e) {
    if (e.name === 'AbortError') sayac.zamanAsimi++;
    else sayac.hata++;
    return { ok: false, durum: 0, sebep: e.name === 'AbortError' ? 'zamanasimi' : 'hata', metin: '' };
  } finally {
    clearTimeout(t);
    await uyu(AYAR.bekle); // nazik ol: canlı siteyi ölçerken yükleme yapma
  }
}

// Düşük eşzamanlılıklı havuz.
async function havuz(isler, n) {
  const sonuc = new Array(isler.length);
  let i = 0;
  const isci = async () => {
    while (i < isler.length) {
      const k = i++;
      sonuc[k] = await isler[k]();
    }
  };
  await Promise.all(Array.from({ length: Math.min(n, isler.length) }, isci));
  return sonuc;
}

// --- HTML ayrıştırma (regex yeterli: SSR çıktısı bizim ürettiğimiz sade HTML) -

const etiketSil = (s) =>
  s
    .replace(/<[^>]+>/g, ' ')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&amp;/g, '&')
    .replace(/&nbsp;/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

function govde(html) {
  const i = html.indexOf('<body');
  const g = i < 0 ? html : html.slice(i);
  return g.replace(/(?:<(script|style|noscript)\b[^>]*>[\s\S]*?<\/\1>)/gi, ' ');
}

function baglantilar(html) {
  const out = [];
  for (const m of html.matchAll(/href="([^"]+)"/g)) {
    let h = m[1];
    if (h.startsWith(KOK)) h = h.slice(KOK.length);
    if (!h.startsWith('/')) continue;
    out.push(h.split('#')[0].split('?')[0]);
  }
  return out;
}

// Sayfadaki bölüm adreslerini (dil ÖNEKSİZ, kanonik hâlde) döndürür.
function bolumBaglantilari(html) {
  const s = new Set();
  for (const h of baglantilar(html)) {
    const m = BOLUM_DESENI.exec(h);
    if (m && !m[1]) s.add(h); // yalnız öneksiz (tr) hâlleri say
  }
  return s;
}

const ilk = (html, re) => {
  const m = re.exec(html);
  return m ? m[1] : null;
};

// --- Site haritası ----------------------------------------------------------

async function haritaKumesi() {
  console.log('• Site haritası indeksi çekiliyor…');
  const idx = await cek(`${KOK}/sitemap.xml`, HARITA_ZAMAN_ASIMI);
  if (!idx.ok) throw new Error(`sitemap.xml alınamadı (${idx.sebep}/${idx.durum})`);
  const tumu = [...idx.metin.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]);

  // tr = öneksiz `sitemap-bolum-N.xml`, en = `sitemap-en-bolum-N.xml`.
  // Diğer 44 dilin haritaları da var ama onlar aynı bölüm kümesinin dil
  // önekli kopyası; keşif darboğazını tr+en üzerinden ölçmek yeterli, 46 dili
  // çekmek ölçümü gereksizce 20 katına çıkarır.
  const trHarita = tumu.filter((u) => /\/sitemap-bolum-\d+\.xml$/.test(u));
  const enHarita = tumu.filter((u) => /\/sitemap-en-bolum-\d+\.xml$/.test(u));
  console.log(`  ${trHarita.length} tr + ${enHarita.length} en bölüm alt haritası`);

  const trUrl = new Set();
  const enUrl = new Set();
  for (const [liste, kume, ad] of [
    [trHarita, trUrl, 'tr'],
    [enHarita, enUrl, 'en'],
  ]) {
    for (const u of liste) {
      const y = await cek(u, HARITA_ZAMAN_ASIMI); // TUZAK 5: cömert zaman aşımı
      if (!y.ok) {
        console.log(`  ! ${ad} haritası alınamadı: ${u} (${y.sebep})`);
        continue;
      }
      for (const m of y.metin.matchAll(/<loc>([^<]+)<\/loc>/g)) {
        kume.add(m[1].replace(KOK, ''));
      }
      console.log(`  ${path.basename(u)}: toplam ${kume.size}`);
    }
  }

  // Dizi başına bölüm kümesi (tr adresleri üzerinden).
  const diziBolum = new Map();
  for (const yol of trUrl) {
    const m = BOLUM_DESENI.exec(yol);
    if (!m) continue;
    const id = m[2];
    if (!diziBolum.has(id)) diziBolum.set(id, new Set());
    diziBolum.get(id).add(yol);
  }
  return { trUrl, enUrl, diziBolum, trHarita, enHarita };
}

// --- 2) İç bağlantı kapsaması ----------------------------------------------
// ÖLÇÜLEN: bir dizinin HARİTADAKİ bölümlerinin yüzde kaçı, o dizinin
// `/icerik/tv/<id>` sayfasından DOĞRUDAN bağlantı alıyor.
// Harita dışı bağlantılar sayılmaz (kesişim alınır) — aksi hâlde tavan
// aşılmış gibi görünürdü.

async function icBaglantiOlc(diziBolum, rnd) {
  const idler = ornekle([...diziBolum.keys()], AYAR.dizi, rnd);
  console.log(`\n• İç bağlantı kapsaması: ${idler.length} dizi örneklendi`);

  const isler = idler.map((id) => async () => {
    const y = await cek(`${KOK}/icerik/tv/${id}`);
    const haritada = diziBolum.get(id);
    if (!y.ok) {
      return { id, olculdu: false, sebep: y.sebep, durum: y.durum, haritaBolum: haritada.size };
    }
    const link = bolumBaglantilari(y.metin);
    let kesisim = 0;
    for (const u of link) if (haritada.has(u)) kesisim++;
    return {
      id,
      olculdu: true,
      haritaBolum: haritada.size,
      sayfadaBolumLink: link.size,
      kapsanan: kesisim,
      kapsamaYuzde: b2(yuzde(kesisim, haritada.size)),
      baslik: ilk(y.metin, /<title>([^<]*)<\/title>/i),
    };
  });

  const satir = await havuz(isler, AYAR.esZaman);
  const olculen = satir.filter((s) => s.olculdu);
  const toplamHarita = olculen.reduce((a, s) => a + s.haritaBolum, 0);
  const toplamKapsanan = olculen.reduce((a, s) => a + s.kapsanan, 0);

  const yuzdeler = olculen.map((s) => s.kapsamaYuzde).sort((a, b) => a - b);
  const medyan = yuzdeler.length ? yuzdeler[Math.floor(yuzdeler.length / 2)] : 0;
  const tamKapsanan = olculen.filter((s) => s.kapsamaYuzde >= 99.99).length;

  return {
    orneklenenDizi: idler.length,
    olculenDizi: olculen.length,
    olculemeyen: satir.filter((s) => !s.olculdu),
    toplamHaritaBolum: toplamHarita,
    toplamKapsanan,
    // TOPLAM kapsama: bölüm başına ağırlıklı. Büyük diziler tavanı burada
    // aşağı çeker; dizi başına medyan ise "tipik dizi"yi gösterir. İkisi
    // birlikte okunmalı, tek başına biri yanıltır.
    toplamKapsamaYuzde: b2(yuzde(toplamKapsanan, toplamHarita)),
    diziBasinaMedyanYuzde: medyan,
    tamKapsananDizi: tamKapsanan,
    dagilim: olculen
      .slice()
      .sort((a, b) => a.kapsamaYuzde - b.kapsamaYuzde)
      .map((s) => ({
        id: s.id,
        haritaBolum: s.haritaBolum,
        kapsanan: s.kapsanan,
        yuzde: s.kapsamaYuzde,
        sayfadaLink: s.sayfadaBolumLink,
      })),
  };
}

// --- 3) Zincir kontrolü -----------------------------------------------------
// ÖLÇÜLEN: dizi sayfasından DOĞRUDAN bağlantı almayan bir bölüme, bölüm
// sayfalarındaki önceki/sonraki + sezon içi liste bağlantılarını takip ederek
// en fazla `--adim` sayfa çekerek ulaşılabiliyor mu?
//
// YÖNTEM: AÇGÖZLÜ yürüyüş — her adımda hedefe (sezon, bölüm) olarak en yakın,
// henüz çekilmemiş bölüm sayfası açılır. Bu KASTEN İYİMSER bir testtir:
// gerçek tarayıcı hedefi bilmez, rastgele yürür. Yani buradaki oran bir ÜST
// SINIRDIR. Açgözlü yürüyüş bile ulaşamıyorsa zincir gerçekten KOPUKTUR;
// ulaşıyorsa "kopmadı" iddiası olası ama kanıtlanmış değildir (adım sayısı
// raporlanır, 30 adım = Google için ucuz değildir).

function konum(yol) {
  const m = BOLUM_DESENI.exec(yol);
  return m ? { sezon: +m[3], bolum: +m[4] } : null;
}
const uzaklik = (a, b) => Math.abs(a.sezon - b.sezon) * 10000 + Math.abs(a.bolum - b.bolum);

async function zincirOlc(diziBolum, icSonuc, rnd) {
  // Yalnız kapsaması eksik dizilerde anlamlı; tam kapsananlarda test edilecek
  // "ulaşılamayan bölüm" zaten yok.
  const adaylar = icSonuc.dagilim.filter((d) => d.yuzde < 99.99);
  const secilen = ornekle(adaylar, AYAR.zincirDizi, rnd);
  console.log(
    `\n• Zincir kontrolü: ${secilen.length} dizi (kapsaması eksik ${adaylar.length} aday içinden)`,
  );

  const kayitlar = [];
  for (const d of secilen) {
    const id = d.id;
    const haritada = [...diziBolum.get(id)];
    const kok = await cek(`${KOK}/icerik/tv/${id}`);
    if (!kok.ok) {
      kayitlar.push({ id, olculdu: false, sebep: kok.sebep });
      continue;
    }
    const dogrudan = bolumBaglantilari(kok.metin);
    const ulasilamayan = haritada.filter((u) => !dogrudan.has(u));
    if (!ulasilamayan.length) continue;

    const hedefler = ornekle(ulasilamayan, AYAR.hedef, rnd);
    // Sayfa önbelleği dizi içinde PAYLAŞILIR: iki hedef için aynı sayfayı
    // iki kez çekip canlıya boşuna yük bindirmeyelim.
    const gorulenLink = new Set(dogrudan);
    const cekilen = new Set();

    for (const hedef of hedefler) {
      const hk = konum(hedef);
      let bulundu = gorulenLink.has(hedef);
      let adim = 0;
      let arizali = 0;
      while (!bulundu && adim < AYAR.adim) {
        // Açgözlü seçim: hedefe en yakın, henüz çekilmemiş bölüm sayfası.
        let en = null;
        let enU = Infinity;
        for (const u of gorulenLink) {
          if (cekilen.has(u)) continue;
          const k = konum(u);
          if (!k) continue;
          const uz = uzaklik(k, hk);
          if (uz < enU) {
            enU = uz;
            en = u;
          }
        }
        if (!en) break; // yürüyecek yer kalmadı = zincir gerçekten KOPUK
        cekilen.add(en);
        adim++;
        const y = await cek(`${KOK}${en}`);
        if (!y.ok) {
          arizali++;
          continue;
        }
        for (const u of bolumBaglantilari(y.metin)) gorulenLink.add(u);
        bulundu = gorulenLink.has(hedef);
      }
      kayitlar.push({
        id,
        hedef,
        olculdu: true,
        ulasildi: bulundu,
        adim,
        arizaliCekim: arizali,
        haritaBolum: d.haritaBolum,
        dogrudanLink: dogrudan.size,
      });
      console.log(
        `  ${id} → ${hedef}  ${bulundu ? `ULAŞILDI (${adim} adım)` : `ULAŞILAMADI (${adim} adım)`}`,
      );
    }
  }

  const olculen = kayitlar.filter((k) => k.olculdu);
  const ulasan = olculen.filter((k) => k.ulasildi);
  const adimlar = ulasan.map((k) => k.adim).sort((a, b) => a - b);
  return {
    denenenHedef: olculen.length,
    ulasilan: ulasan.length,
    ulasilabilirlikYuzde: b2(yuzde(ulasan.length, olculen.length)),
    medyanAdim: adimlar.length ? adimlar[Math.floor(adimlar.length / 2)] : null,
    enFazlaAdim: adimlar.length ? adimlar[adimlar.length - 1] : null,
    adimTavani: AYAR.adim,
    yontem: 'acgozlu-iyimser-ust-sinir',
    kayitlar,
    olculemeyen: kayitlar.filter((k) => !k.olculdu),
  };
}

// --- 4) Dil varyantı içerik doluluğu ---------------------------------------
// ÖLÇÜLEN (her dil × her bölüm için):
//   robots      : <meta name="robots"> içeriği (yoksa null → noindex YOK)
//   noindex     : robots metninde "noindex" geçiyor mu
//   title       : <title>
//   adVar       : h1'de ayraçtan ("—"/"–"/":") sonra bölüm ADI var mı
//   adYerTutucu : o ad, h1'in başındaki numaralı kısmın KOPYASI mı
//                 (ör. ar: "… الموسم 1 الحلقة 5 — الحلقة 5" → ad yok sayılır;
//                  başlık dolu görünür ama hiçbir bilgi taşımaz)
//   ozetVar     : bir <h2> hemen ardından <p> geliyor mu (özet bloğu)
//                 — SSS bloğu <h2>+<dl> olduğu için bu ikisi karışmaz
//   kelime      : görünür gövde kelime sayısı (script/style çıkarılmış)

// SSR h1'in kalıbı: "<dizi adı> <sezon/bölüm etiketi> — <bölüm adı>".
// Ayraç 46 dilde de uzun tire. İKİ NOKTAYI AYRAÇ SAYMA TUZAĞI: dizi adının
// kendisinde iki nokta olabiliyor ("Fullmetal Alchemist: Brotherhood",
// "الخيميائي الفولاذي : الأخوَّة") ve ilk eşleşmeye bakarsan dizi adının
// yarısını "bölüm adı" sanırsın. Bu yüzden SON uzun tire alınır.
const AYRAC_G = /\s[—–]\s/g;

function bolumSayfasiOlc(html) {
  const g = govde(html);
  const h1ham = ilk(g, /<h1[^>]*>([\s\S]*?)<\/h1>/i);
  const h1 = h1ham ? etiketSil(h1ham) : null;

  let adVar = false;
  let adYerTutucu = false;
  if (h1) {
    const yerler = [...h1.matchAll(AYRAC_G)];
    if (yerler.length) {
      const son = yerler[yerler.length - 1];
      const bas = h1.slice(0, son.index).trim();
      const ad = h1.slice(son.index + son[0].length).trim();
      adVar = ad.length > 0;
      // Yer tutucu tespiti: "ad" zaten başlığın numaralı kısmında geçiyorsa
      // (ör. "… Bölüm 5 — Bölüm 5"), gerçek bir bölüm adı yoktur. Sayfa dolu
      // görünür, hiçbir bilgi taşımaz.
      adYerTutucu = adVar && bas.includes(ad);
    }
  }

  const metin = etiketSil(g);
  return {
    robots: ilk(html, /<meta name="robots"[^>]*content="([^"]*)"/i),
    title: ilk(html, /<title>([^<]*)<\/title>/i),
    h1,
    adVar,
    adYerTutucu,
    gercekAd: adVar && !adYerTutucu,
    // Özet bloğu: <h2>…</h2> hemen ardından <p>. SSS bloğu <dl> ile gelir.
    ozetVar: /<h2[^>]*>[\s\S]*?<\/h2>\s*<p[^>]*>/i.test(g),
    kelime: metin ? metin.split(/\s+/).length : 0,
  };
}

async function dilOlc(diziBolum, rnd) {
  // Örneklem: her seferinde AYNI bölümler (tohumlu), ki diller arası fark
  // içerikten gelsin, örneklemden değil.
  const tumBolum = [];
  for (const kume of diziBolum.values()) tumBolum.push(...kume);
  const ornek = ornekle(tumBolum, AYAR.dilOrnek, rnd);
  console.log(
    `\n• Dil doluluğu: ${ornek.length} bölüm × ${AYAR.diller.length} dil = ${
      ornek.length * AYAR.diller.length
    } istek`,
  );

  const isler = [];
  for (const dil of AYAR.diller) {
    for (const yol of ornek) {
      // TUZAK 3: dil SORGU ile değil ÖNEK ile verilir.
      const url = dil === 'tr' ? `${KOK}${yol}` : `${KOK}/${dil}${yol}`;
      isler.push(async () => {
        const y = await cek(url);
        if (!y.ok) return { dil, yol, olculdu: false, sebep: y.sebep, durum: y.durum };
        return { dil, yol, olculdu: true, ...bolumSayfasiOlc(y.metin) };
      });
    }
  }
  const satir = await havuz(isler, AYAR.esZaman);

  const tablo = {};
  for (const dil of AYAR.diller) {
    const s = satir.filter((x) => x.dil === dil && x.olculdu);
    const ariza = satir.filter((x) => x.dil === dil && !x.olculdu);
    const kelimeler = s.map((x) => x.kelime).sort((a, b) => a - b);
    tablo[dil] = {
      olculen: s.length,
      arizali: ariza.length,
      noindex: s.filter((x) => (x.robots || '').toLowerCase().includes('noindex')).length,
      robotsEtiketiVar: s.filter((x) => x.robots).length,
      gercekAdVar: s.filter((x) => x.gercekAd).length,
      adYerTutucu: s.filter((x) => x.adYerTutucu).length,
      ozetVar: s.filter((x) => x.ozetVar).length,
      medyanKelime: kelimeler.length ? kelimeler[Math.floor(kelimeler.length / 2)] : null,
      enAzKelime: kelimeler.length ? kelimeler[0] : null,
      enCokKelime: kelimeler.length ? kelimeler[kelimeler.length - 1] : null,
      ornekTitle: s.length ? s[0].title : null,
      ornekH1: s.length ? s[0].h1 : null,
    };
  }
  return { ornekBolumler: ornek, tablo, satirlar: satir };
}

// --- Rapor ------------------------------------------------------------------

function pad(s, n) {
  s = String(s ?? '');
  // Kaba genişlik: Arapça/Amharca glifler tek sütun sayılır, hizalama
  // mükemmel olmayabilir. Sayı sütunları ASCII olduğu için sorun çıkmaz.
  return s.length >= n ? s.slice(0, n) : s + ' '.repeat(n - s.length);
}
const sag = (s, n) => String(s ?? '').padStart(n);

function rapor(anlik) {
  const { ic, zincir, dil, sayaclar, harita } = anlik;
  const c = [];
  c.push('');
  c.push('═══ dizi.jpg · BÖLÜM KEŞİF ÖLÇÜMÜ ═══');
  c.push(`tarih: ${anlik.tarih}   tohum: ${anlik.ayar.tohum}`);
  c.push('');

  c.push('— ÖLÇÜM SAĞLIĞI —');
  c.push(
    `istek ${sayaclar.istek} · başarılı ${sayaclar.ok} · 403/503 engel ${sayaclar.engel403} · ` +
      `zaman aşımı ${sayaclar.zamanAsimi} · diğer hata ${sayaclar.hata} · Flutter kabuğu ${sayaclar.bos}`,
  );
  if (sayaclar.engel403) {
    c.push(
      '  ! 403/503 GÖRÜLDÜ = Cloudflare bot doğrulaması bu IP\'den Googlebot UA\'sına',
      '    izin vermedi. Bu ÖLÇÜM ARIZASIDIR, site arızası değil. Aşağıdaki oranlar',
      '    yalnız başarılı çekimler üzerinden hesaplandı; paydaları kontrol et.',
    );
  }
  if (sayaclar.bos) {
    c.push(
      '  ! Flutter kabuğu döndü = o istekte SSR görülemedi (bot yolu atlandı).',
      '    O sayfa "0 bağlantı" sayılmadı, ÖLÇÜLEMEDİ olarak ayrıldı.',
    );
  }
  c.push('');

  c.push('— HARİTA KÜMESİ —');
  c.push(`tr bölüm URL: ${harita.trAdet}   ·   en bölüm URL: ${harita.enAdet}`);
  c.push(`haritada dizi sayısı: ${harita.diziAdet}`);
  c.push('');

  c.push('— 1) İÇ BAĞLANTI KAPSAMASI (dizi sayfası → bölüm) —');
  c.push(`örneklenen dizi: ${ic.orneklenenDizi} · ölçülen: ${ic.olculenDizi}`);
  c.push(
    `TOPLAM: ${ic.toplamKapsanan}/${ic.toplamHaritaBolum} bölüm doğrudan bağlantı alıyor = ` +
      `%${ic.toplamKapsamaYuzde}`,
  );
  c.push(`dizi başına MEDYAN kapsama: %${ic.diziBasinaMedyanYuzde}`);
  c.push(`tam kapsanan dizi: ${ic.tamKapsananDizi}/${ic.olculenDizi}`);
  c.push('');
  c.push(`  ${pad('dizi', 9)}${sag('harita', 7)}${sag('link', 6)}${sag('kapsanan', 9)}${sag('%', 8)}`);
  for (const d of ic.dagilim) {
    c.push(
      `  ${pad(d.id, 9)}${sag(d.haritaBolum, 7)}${sag(d.sayfadaLink, 6)}${sag(d.kapsanan, 9)}${sag(
        d.yuzde.toFixed(1),
        8,
      )}`,
    );
  }
  if (ic.olculemeyen.length) {
    c.push(`  ölçülemeyen dizi: ${ic.olculemeyen.map((x) => `${x.id}(${x.sebep})`).join(', ')}`);
  }
  c.push('');

  c.push('— 2) ZİNCİR ULAŞILABİLİRLİĞİ (bağlantısız bölüme yürüyerek) —');
  c.push(
    `denenen hedef: ${zincir.denenenHedef} · ulaşılan: ${zincir.ulasilan} = ` +
      `%${zincir.ulasilabilirlikYuzde}  (adım tavanı ${zincir.adimTavani})`,
  );
  c.push(
    `ulaşılanlarda medyan adım: ${zincir.medyanAdim ?? '—'} · en fazla: ${zincir.enFazlaAdim ?? '—'}`,
  );
  c.push(
    '  NOT: yürüyüş AÇGÖZLÜ (hedefe en yakın sayfayı seçer) — gerçek tarayıcıdan',
    '  daha şanslıdır. Bu oran bir ÜST SINIRDIR; buradaki başarısızlık kesin,',
    '  buradaki başarı "Google da bulur" demek DEĞİLDİR.',
  );
  c.push('');

  c.push('— 3) DİL VARYANTI İÇERİK DOLULUĞU —');
  c.push(`örneklem: ${dil.ornekBolumler.length} bölüm, dil başına aynı bölümler`);
  c.push('');
  c.push(
    `  ${pad('dil', 5)}${sag('ölç', 5)}${sag('arıza', 6)}${sag('noindex', 8)}${sag('ad', 5)}${sag(
      'yer-tut',
      8,
    )}${sag('özet', 6)}${sag('med.kel', 8)}${sag('min', 6)}${sag('max', 6)}`,
  );
  for (const [d, t] of Object.entries(dil.tablo)) {
    c.push(
      `  ${pad(d, 5)}${sag(t.olculen, 5)}${sag(t.arizali, 6)}${sag(t.noindex, 8)}${sag(
        t.gercekAdVar,
        5,
      )}${sag(t.adYerTutucu, 8)}${sag(t.ozetVar, 6)}${sag(t.medyanKelime, 8)}${sag(
        t.enAzKelime,
        6,
      )}${sag(t.enCokKelime, 6)}`,
    );
  }
  c.push('');
  c.push('  sütunlar: ad=gerçek bölüm adı olan sayfa · yer-tut="Bölüm 5 — Bölüm 5"');
  c.push('  gibi içi boş ad · özet=özet paragrafı olan sayfa · kel=görünür kelime');
  c.push('');
  for (const [d, t] of Object.entries(dil.tablo)) {
    if (t.olculen && t.gercekAdVar === 0 && t.noindex === 0) {
      c.push(
        `  ! ${d}: ${t.olculen}/${t.olculen} sayfada gerçek bölüm adı YOK, özet ${
          t.ozetVar
        }/${t.olculen}, ama noindex 0 → ince sayfa indekse açık.`,
      );
    }
  }
  c.push('');
  return c.join('\n');
}

// --- Karşılaştırma ----------------------------------------------------------

function fark(eski, yeni) {
  const c = [];
  const ok = (d) => (d > 0 ? `+${d.toFixed(2)}` : d.toFixed(2));
  c.push('');
  c.push('═══ ÖNCESİ / SONRASI ═══');
  c.push(`öncesi: ${eski.tarih}   sonrası: ${yeni.tarih}`);
  if (eski.ayar.tohum !== yeni.ayar.tohum) {
    c.push('! TOHUMLAR FARKLI — örneklemler farklı dizileri kapsıyor, fark');
    c.push('  düzeltmeden değil örneklemden geliyor olabilir. Aynı tohumla koş.');
  }
  c.push('');
  c.push('— iç bağlantı kapsaması —');
  c.push(
    `  toplam %: ${eski.ic.toplamKapsamaYuzde} → ${yeni.ic.toplamKapsamaYuzde}  (${ok(
      yeni.ic.toplamKapsamaYuzde - eski.ic.toplamKapsamaYuzde,
    )})`,
  );
  c.push(
    `  medyan %: ${eski.ic.diziBasinaMedyanYuzde} → ${yeni.ic.diziBasinaMedyanYuzde}  (${ok(
      yeni.ic.diziBasinaMedyanYuzde - eski.ic.diziBasinaMedyanYuzde,
    )})`,
  );
  c.push(
    `  tam kapsanan dizi: ${eski.ic.tamKapsananDizi}/${eski.ic.olculenDizi} → ${yeni.ic.tamKapsananDizi}/${yeni.ic.olculenDizi}`,
  );

  // Dizi başına fark — hangi dizi düzeldi, hangisi geriledi.
  const e = new Map(eski.ic.dagilim.map((d) => [d.id, d]));
  const degisen = [];
  for (const d of yeni.ic.dagilim) {
    const o = e.get(d.id);
    if (o && Math.abs(d.yuzde - o.yuzde) >= 0.5) degisen.push({ id: d.id, o: o.yuzde, y: d.yuzde });
  }
  degisen.sort((a, b) => a.y - a.o - (b.y - b.o));
  if (degisen.length) {
    c.push('  değişen diziler (≥0,5 puan):');
    for (const d of degisen) c.push(`    ${pad(d.id, 9)} %${d.o.toFixed(1)} → %${d.y.toFixed(1)}`);
  } else {
    c.push('  dizi başına anlamlı değişiklik YOK.');
  }
  c.push('');
  c.push('— zincir ulaşılabilirliği —');
  c.push(
    `  %${eski.zincir.ulasilabilirlikYuzde} (${eski.zincir.ulasilan}/${eski.zincir.denenenHedef}) → ` +
      `%${yeni.zincir.ulasilabilirlikYuzde} (${yeni.zincir.ulasilan}/${yeni.zincir.denenenHedef})`,
  );
  c.push(`  medyan adım: ${eski.zincir.medyanAdim ?? '—'} → ${yeni.zincir.medyanAdim ?? '—'}`);
  c.push('');
  c.push('— dil doluluğu (noindex / gerçek ad / özet / medyan kelime) —');
  const diller = new Set([...Object.keys(eski.dil.tablo), ...Object.keys(yeni.dil.tablo)]);
  for (const d of diller) {
    const o = eski.dil.tablo[d];
    const y = yeni.dil.tablo[d];
    if (!o || !y) {
      c.push(`  ${pad(d, 5)} yalnız bir koşuda var — kıyaslanamaz`);
      continue;
    }
    c.push(
      `  ${pad(d, 5)} noindex ${o.noindex}/${o.olculen} → ${y.noindex}/${y.olculen}` +
        ` · ad ${o.gercekAdVar} → ${y.gercekAdVar}` +
        ` · özet ${o.ozetVar} → ${y.ozetVar}` +
        ` · kel ${o.medyanKelime} → ${y.medyanKelime}`,
    );
  }
  c.push('');
  return c.join('\n');
}

// --- Akış -------------------------------------------------------------------

async function main() {
  // Yalnız karşılaştırma isteniyorsa ağa hiç çıkma.
  if (AYAR.karsilastir && !AYAR.json && argv.length === 2) {
    console.error('--karsilastir tek başına verildi ama kıyaslanacak YENİ koşu yok.');
    console.error('Ya --json ile yeni anlık görüntü al, ya da iki dosyayı da ver.');
    process.exit(1);
  }

  const rnd = rastgeleUret(AYAR.tohum);
  const t0 = Date.now();

  const { trUrl, enUrl, diziBolum } = await haritaKumesi();
  const ic = await icBaglantiOlc(diziBolum, rnd);
  const zincir = await zincirOlc(diziBolum, ic, rnd);
  const d = await dilOlc(diziBolum, rnd);

  const anlik = {
    surum: 1,
    tarih: new Date().toISOString(),
    sureSn: Math.round((Date.now() - t0) / 1000),
    ayar: AYAR,
    harita: { trAdet: trUrl.size, enAdet: enUrl.size, diziAdet: diziBolum.size },
    ic,
    zincir,
    dil: d,
    sayaclar: sayac,
  };

  console.log(rapor(anlik));

  if (AYAR.json) {
    fs.mkdirSync(path.dirname(AYAR.json), { recursive: true });
    fs.writeFileSync(AYAR.json, JSON.stringify(anlik, null, 2));
    console.log(`anlık görüntü yazıldı: ${AYAR.json}`);
  }
  if (AYAR.karsilastir) {
    const eski = JSON.parse(fs.readFileSync(AYAR.karsilastir, 'utf8'));
    console.log(fark(eski, anlik));
  }
}

main().catch((e) => {
  console.error('ÖLÇÜM DURDU:', e.message);
  process.exit(1);
});
