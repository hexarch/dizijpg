// DIŞ PUANLAR — IMDb, Rotten Tomatoes (eleştirmen "Tomatometer" + seyirci
// "Popcornmeter"), Metacritic (6 Eyl 2026).
//
// KAYNAK: MDBList API (https://api.mdblist.com). NEDEN MDBList:
//   · IMDb'nin ücretsiz genel API'si YOK; veri dosyaları "kişisel ve ticari
//     olmayan" lisanslı, siteye uymaz.
//   · Rotten Tomatoes'un genel API'si HİÇ yok (yalnız ortaklara); sayfa
//     kazımak kullanım şartlarına aykırı ve kırılgan.
//   · OMDb IMDb + Tomatometer verir ama SEYİRCİ (patlamış mısır) puanı
//     vermez ve lisansı CC BY-NC (ticari değil).
//   MDBList tek istekte hepsini döner ve doğrudan TMDB kimliğiyle sorgulanır
//   (`/tmdb/movie/{id}`, `/tmdb/show/{id}`) — sitemiz zaten TMDB kimlikli,
//   eşleme derdi yok.
//
// BÜTÇE: ücretsiz anahtar GÜNDE 1.000 istek (`x-ratelimit-limit: 1000`,
// sıfırlama UTC gece yarısı). Kütüphanede 3.630 farklı yapım var (6 Eyl
// canlı ölçüm: durumlar ∪ izlemeler ∪ puanlar ∪ favoriler). Bu yüzden:
//   · Günlük bütçe İKİYE bölünür: gece işi (kullanıcıların izlediği/takip
//     ettiği yapımlar, EN ÇOK kullanıcıya göre sıralı) `GECE_TAVAN`a kadar;
//     sayfa açılışındaki anlık çekim geri kalanı kullanır, `GUNLUK_TAVAN`ı
//     aşmaz. Kullanıcı isteği önceliklidir: gece işi bitmemişse bile sayfa
//     açan kullanıcı puanını görür.
//   · Sayaç DB'den okunur (`dis_puanlar.cekim` bugünkü UTC günü) — işçi
//     kümesinde N süreç aynı sayacı paylaşır, bellek sayacı N kat şaşardı.
//   · Bulunamayan yapım da satır olarak yazılır (`bulundu=false`) ki her
//     açılışta yeniden istenmesin (tmdb_yok ile aynı ders: 404 döngüsü).
//
// Bu dosya SAF: ağ/DB yok. server.js çeker, burası ayıklar ve biçimler.

/** MDBList günlük istek tavanı (ücretsiz anahtar). */
const GUNLUK_TAVAN = 1000;
/** Gece işinin günlük payı; kalan (~300) kullanıcı açılışlarına. */
const GECE_TAVAN = 650;
/** Anlık çekimin durduğu eşik: tavana 50 istek marj (yarış/yeniden deneme). */
const ANLIK_TAVAN = GUNLUK_TAVAN - 50;
/** Bulunan satırın tazelenme ömrü (gün). Puanlar yavaş değişir. */
const TAZELIK_GUN = 14;
/** Bulunamayan satırın yeniden denenme ömrü (gün). */
const YOK_TAZELIK_GUN = 30;
/** Anlık çekimin süre tavanı (ms) — sayfa açılışını bloke etmemeli. */
const ANLIK_ZAMAN_ASIMI_MS = 6000;

/**
 * MDBList yanıtındaki `ratings` dizisinden BİZİM sütunlarımıza.
 * Kaynak adları MDBList'in yanıtındaki gibidir: imdb, tomatoes (eleştirmen),
 * popcorn (seyirci), metacritic. Değeri null olan kaynak YOK sayılır.
 * @param {object|null} veri MDBList `/tmdb/{tür}/{id}` gövdesi
 * @returns {object} satır alanları (`bulundu` dahil)
 */
function disPuanAyikla(veri) {
  const bos = {
    bulundu: false, imdb_id: null, imdb: null, imdb_oy: null,
    rt_elestirmen: null, rt_taze: null, rt_seyirci: null, metacritic: null,
    rt_yol: null,
  };
  if (!veri || typeof veri !== 'object' || !Array.isArray(veri.ratings)) return bos;
  const kaynak = (ad) => veri.ratings.find((r) => r && r.source === ad) || null;
  const sayi = (x) => (typeof x === 'number' && Number.isFinite(x) ? x : null);
  const imdb = kaynak('imdb');
  const tom = kaynak('tomatoes');
  const pop = kaynak('popcorn');
  const meta = kaynak('metacritic');
  const imdbDeger = sayi(imdb?.value);
  const satir = {
    bulundu: true,
    imdb_id: (typeof veri.ids?.imdb === 'string' && veri.ids.imdb) || (typeof veri.imdbid === 'string' && veri.imdbid) || null,
    // IMDb 0-10, bir ondalık. 0 puan "puan yok" demektir.
    imdb: imdbDeger && imdbDeger > 0 ? Math.round(imdbDeger * 10) / 10 : null,
    imdb_oy: Number.isInteger(imdb?.votes) && imdb.votes > 0 ? imdb.votes : null,
    rt_elestirmen: yuzde(tom?.value),
    // MDBList `fresh: 1` = taze domates (≥60). Alan yoksa puandan türet.
    rt_taze: tom && yuzde(tom.value) !== null
      ? (typeof tom.fresh === 'number' ? tom.fresh === 1 : yuzde(tom.value) >= 60)
      : null,
    rt_seyirci: yuzde(pop?.value),
    metacritic: yuzde(meta?.value),
    rt_yol: typeof tom?.url === 'string' && /^\/(m|tv)\//.test(tom.url) ? tom.url
      : (typeof pop?.url === 'string' && /^\/(m|tv)\//.test(pop.url) ? pop.url : null),
  };
  return satir;
}

/** 0-100 tam sayı yüzde; geçersizde null. */
function yuzde(x) {
  if (typeof x !== 'number' || !Number.isFinite(x)) return null;
  const n = Math.round(x);
  return n >= 0 && n <= 100 ? n : null;
}

/**
 * Satırın istemciye giden görünümü. İç sütunlar (cekim, bulundu, rt_yol)
 * saklanır; bağlantılar burada MUTLAK adrese çevrilir ki istemci kaynak
 * adresi kurallarını bilmek zorunda kalmasın.
 * Hiç puan yoksa null döner — istemci bloğu çizmez.
 */
function disPuanGorunum(satir) {
  if (!satir || !satir.bulundu) return null;
  const g = {};
  // NUMERIC sütunu node-pg'den METİN gelir ("9.3"); istemci `is num` bakıyor,
  // metin gönderilse IMDb rozeti sessizce kaybolurdu. Burada sayıya çevrilir.
  const imdb = Number(satir.imdb);
  if (Number.isFinite(imdb) && imdb > 0) {
    g.imdb = Math.round(imdb * 10) / 10;
    if (satir.imdb_oy) g.imdb_oy = satir.imdb_oy;
    if (satir.imdb_id) g.imdb_url = `https://www.imdb.com/title/${satir.imdb_id}/`;
  }
  if (satir.rt_elestirmen !== null && satir.rt_elestirmen !== undefined) {
    g.rt_elestirmen = satir.rt_elestirmen;
    g.rt_taze = !!satir.rt_taze;
  }
  if (satir.rt_seyirci !== null && satir.rt_seyirci !== undefined) g.rt_seyirci = satir.rt_seyirci;
  if ((g.rt_elestirmen !== undefined || g.rt_seyirci !== undefined) && satir.rt_yol) {
    g.rt_url = `https://www.rottentomatoes.com${satir.rt_yol}`;
  }
  if (satir.metacritic !== null && satir.metacritic !== undefined) g.metacritic = satir.metacritic;
  return Object.keys(g).length ? g : null;
}

/**
 * SSR künye satırı: marka adları çevrilmez, o yüzden 46 dilde ek çeviri yok.
 * Yüzde işaretinin yeri dile göre: Türkçe "%96", diğerleri "96%".
 * @returns {string} boşsa ''
 */
function disPuanKunye(satir, dil = 'tr') {
  const g = disPuanGorunum(satir);
  if (!g) return '';
  const yz = (n) => (dil === 'tr' ? `%${n}` : `${n}%`);
  const p = [];
  if (g.imdb !== undefined) p.push(`IMDb ${dil === 'tr' ? String(g.imdb).replace('.', ',') : g.imdb}`);
  if (g.rt_elestirmen !== undefined) p.push(`Rotten Tomatoes ${yz(g.rt_elestirmen)}`);
  if (g.rt_seyirci !== undefined) p.push(`Popcornmeter ${yz(g.rt_seyirci)}`);
  if (g.metacritic !== undefined) p.push(`Metacritic ${g.metacritic}`);
  return p.join(' · ');
}

/**
 * Bütçe kararı. `kullanilan` = bugün (UTC) atılmış istek sayısı.
 * @param {number} kullanilan
 * @param {'anlik'|'gece'} kip
 * @returns {number} atılabilecek istek sayısı (0 = dur)
 */
function disPuanKalan(kullanilan, kip) {
  const n = Number.isFinite(kullanilan) && kullanilan > 0 ? Math.trunc(kullanilan) : 0;
  const tavan = kip === 'gece' ? GECE_TAVAN : ANLIK_TAVAN;
  return Math.max(0, tavan - n);
}

/** Satır tazelenmeli mi? (yoksa → evet; bulunduysa 14 gün; bulunmadıysa 30) */
function disPuanBayatMi(satir, simdi = Date.now()) {
  if (!satir) return true;
  const c = satir.cekim ? new Date(satir.cekim).getTime() : 0;
  const omurGun = satir.bulundu ? TAZELIK_GUN : YOK_TAZELIK_GUN;
  return !c || simdi - c > omurGun * 86400_000;
}

/** MDBList medya türü: TMDB 'tv' → 'show'. */
function mdbTur(tur) { return tur === 'tv' ? 'show' : 'movie'; }

export {
  GUNLUK_TAVAN, GECE_TAVAN, ANLIK_TAVAN, TAZELIK_GUN, YOK_TAZELIK_GUN,
  ANLIK_ZAMAN_ASIMI_MS,
  disPuanAyikla, disPuanGorunum, disPuanKunye, disPuanKalan, disPuanBayatMi,
  mdbTur,
};
