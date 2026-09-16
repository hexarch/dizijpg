// dizi.jpg — NÖBETÇİ: sessizce duran arka plan işlerini yakalar.
//
// =============================================================================
// NEDEN VAR (17 Eyl 2026 — ölçülmüş arıza)
// =============================================================================
// 14 Eyl 19:48'de TMDB'den gelen tek bir çöp satır (`episode_number` = 10^18)
// `::int` taşmasıyla İKİ işi birden öldürdü: `seo_bolum_olcu` tazelemesi ve
// ısıtıcı. İkisi de hatayı DÜZGÜNCE loglayıp durdu — kimse 3 gün boyunca
// görmedi. Kaybı büyüten şey hatanın kendisi değil, SESSİZLİĞİYDİ:
//   · tazeleme "ATMAZ" diye hatayı yutuyor, su seviyesi ilerlemiyor ⇒ tablo
//     kalıcı donuyor ama harita dünkü kovayla çalışmaya devam ettiği için
//     dışarıdan HER ŞEY NORMAL görünüyor,
//   · ısıtıcı cron'da; çıktısı bir log dosyasına akıyor ve kimse o dosyayı
//     her gün açmıyor.
// Bu modül "işler koşuyor mu?" sorusunu VERİYE dayandırır ve cevabı yönetim
// panelinin göreceği bir yere yazar.
//
// İKİ BAĞIMSIZ SİNYAL — biri yalan söylerse diğeri yakalar:
//   1. SÜREÇ: her koşu bitişinde işin kendi NÖBET KAYDI (son koşu, son
//      başarı, ardarda hata). "İş hiç koşmuyor / koşuyor ama patlıyor."
//   2. SONUÇ: ölçü tablosunun `max(olculdu)` yaşı. "İş koştuğunu söylüyor
//      ama tabloya günlerdir tek satır yazmamış." (14 Eyl'de tazeleme ilk
//      öbekte patlıyordu: süreç sinyali hatayı, sonuç sinyali donmayı
//      gösterirdi — ikisi de doğruydu.)
//
// SAF ÇEKİRDEK: karar veren her şey (`nobetGuncelle`, `nobetSorunlari`) saf
// fonksiyon; DB'yi yalnız ince sarmalayıcılar bilir ve onlar da `sorgu`
// geri çağrısını dışarıdan alır (isitici.js'teki `getir`/`yaz` disiplini).
// Böylece eşikler ve metinler test/nobet.test.js'te gerçekten ÇALIŞTIRILARAK
// sınanıyor, kopyasıyla değil.

/** Nöbet kayıtları `ayarlar` tablosunda bu ön ekle durur (`nobet_isitici`). */
export const NOBET_ONEK = 'nobet_';

/** Nöbetçinin kendi özeti (panelin okuduğu satır). */
export const NOBET_OZET_ANAHTAR = 'nobetci';

/** Üst üste bu kadar hatalı koşu = sorun (tek hata geçici olabilir). */
export const ARDARDA_ESIK = 3;

/** Metin alanlarının azami uzunluğu — `ayarlar.deger` şişmesin. */
const AZAMI_HATA = 300;

/**
 * İZLENEN İŞLER. Eşikler işin KENDİ ritmine göre:
 *  · SEO ölçü tazelemeleri site haritası üretilirken koşar; harita kovası
 *    6 saatlik (SITEMAP_TTL_MS) ve botlar gün içinde defalarca ister ⇒
 *    24 saat sessizlik NORMAL DEĞİLDİR.
 *  · Isıtıcı cron'da 10 dakikada bir koşar (isitici.js AYAR.CRON_DAKIKA) ⇒
 *    3 saat sessizlik 18 koşunun kaçtığı anlamına gelir.
 * `tablo` DOLU olan işlerde sonuç sinyali de aranır; ısıtıcının çıktısı tek
 * bir tabloya düşmediği için (tmdb_onbellek'e kullanıcı istekleri de yazar)
 * onda yalnız süreç sinyali var.
 */
export const NOBET_ISLER = Object.freeze({
  seo_bolum_olcu: { etiket: 'bölüm ölçüsü', tablo: 'seo_bolum_olcu', esikSaat: 24 },
  seo_dizi_olcu: { etiket: 'dizi ölçüsü', tablo: 'seo_dizi_olcu', esikSaat: 24 },
  seo_kisi_olcu: { etiket: 'kişi ölçüsü', tablo: 'seo_kisi_olcu', esikSaat: 24 },
  seo_yapim_sirket: { etiket: 'firma ölçüsü', tablo: 'seo_yapim_sirket', esikSaat: 24 },
  isitici: { etiket: 'ısıtıcı', tablo: null, esikSaat: 3 },
});

/** `ayarlar` anahtarı. */
export const nobetAnahtari = (ad) => `${NOBET_ONEK}${ad}`;

/** Milisaniye farkını okunur saat/gün metnine çevirir ("3,2 saat", "2,1 gün"). */
export function yasMetni(ms) {
  if (!Number.isFinite(ms) || ms < 0) return 'bilinmiyor';
  const saat = ms / 3600000;
  if (saat < 1) return `${Math.round(ms / 60000)} dakika`;
  if (saat < 48) return `${saat.toFixed(1).replace('.', ',')} saat`;
  return `${(saat / 24).toFixed(1).replace('.', ',')} gün`;
}

/**
 * Aynı yaş, "…dır" ekiyle: ek TÜRKÇE UYUMLU olmalı (gün→gündür, saat→saattir,
 * dakika→dakikadır). Şablonda düz "tir" eklemek "2,8 güntir" üretiyordu.
 */
export function yasDir(ms) {
  const m = yasMetni(ms);
  if (m.endsWith('dakika')) return `${m}dır`;
  if (m.endsWith('saat')) return `${m}tir`;
  if (m.endsWith('gün')) return `${m}dür`;
  return m;
}

/** Kayıt metin de olabilir (DB'den ham gelir) nesne de (testte/bellekte). */
export const kayitCoz = (v) => (typeof v === 'string' ? nobetCoz(v)
  : (v && typeof v === 'object' && !Array.isArray(v) ? v : null));

/** Bozuk/eksik JSON kaydı ÇÖKERTMEZ: okunamayan kayıt "kayıt yok" sayılır. */
export function nobetCoz(metin) {
  if (typeof metin !== 'string' || !metin) return null;
  try {
    const k = JSON.parse(metin);
    return k && typeof k === 'object' && !Array.isArray(k) ? k : null;
  } catch {
    return null;
  }
}

/**
 * Koşu bitişinde yazılacak YENİ kaydı üretir (SAF).
 *
 * `son_basari` hatalı koşuda KORUNUR: "en son ne zaman gerçekten çalıştı"
 * sorusunun cevabı, hata sayacı sıfırlansa bile kaybolmamalı.
 */
export function nobetGuncelle(eski, { hata = null, simdi = Date.now() } = {}) {
  const onceki = kayitCoz(eski);
  const an = new Date(simdi).toISOString();
  if (!hata) {
    return {
      son_kosu: an, son_basari: an, ardarda_hata: 0, son_hata: null,
    };
  }
  const mesaj = String(hata?.message || hata || 'bilinmeyen hata').slice(0, AZAMI_HATA);
  return {
    son_kosu: an,
    son_basari: onceki?.son_basari ?? null,
    ardarda_hata: Number(onceki?.ardarda_hata || 0) + 1,
    son_hata: mesaj,
  };
}

/** ISO metnini ms'ye çevirir; bozuksa null (tarih hesabı NaN'a düşmesin). */
const an = (v) => {
  if (!v) return null;
  const t = v instanceof Date ? v.getTime() : Date.parse(v);
  return Number.isFinite(t) ? t : null;
};

/**
 * SORUN LİSTESİ (SAF). İş başına EN FAZLA BİR satır döner; öncelik:
 *   hata > kosmuyor > olcu_bayat > kayit_yok
 * Gerekçe: aynı arıza üç satır üretirse panelde gürültü olur ve asıl neden
 * (üst üste patlayan koşu) alt satırlarda kaybolur.
 *
 * @param {object} a
 * @param {Record<string, object|null>} a.kayitlar  iş adı → nöbet kaydı
 * @param {Record<string, string|Date|null>} a.olculer  tablo adı → max(olculdu)
 * @param {number} a.simdi  şimdi (ms)
 * @param {number} a.acilis sunucunun açılış anı (ms) — yeni dağıtımda "hiç
 *   koşmadı" diye alarm vermemek için: eşik kadar zaman geçmeden kayıtsızlık
 *   bir SORUN DEĞİLDİR, sadece henüz sıra gelmemiştir.
 */
export function nobetSorunlari({
  kayitlar = {}, olculer = {}, simdi = Date.now(), acilis = 0, isler = NOBET_ISLER,
} = {}) {
  const sorunlar = [];
  for (const [ad, is] of Object.entries(isler)) {
    const esikMs = is.esikSaat * 3600000;
    const k = kayitCoz(kayitlar[ad]);
    const ekle = (tur, ozet, ek = {}) => {
      sorunlar.push({ is: ad, etiket: is.etiket, tur, ozet, ...ek });
      return true;
    };
    const ayakta = simdi - acilis;
    if (!k) {
      // Açılışın üstünden eşik kadar geçmediyse sessiz kal (yeni dağıtım).
      if (acilis && ayakta < esikMs) continue;
      ekle('kayit_yok', `${is.etiket}: nöbet kaydı yok — iş hiç koşmamış olabilir`);
      continue;
    }
    if (Number(k.ardarda_hata || 0) >= ARDARDA_ESIK) {
      ekle('hata', `${is.etiket}: ${k.ardarda_hata} koşu üst üste HATA`
        + `${k.son_hata ? ` — ${k.son_hata}` : ''}`, { ardarda: Number(k.ardarda_hata) });
      continue;
    }
    const basari = an(k.son_basari);
    if (!basari || simdi - basari > esikMs) {
      ekle('kosmuyor', `${is.etiket}: ${basari
        ? `${yasDir(simdi - basari)} başarılı koşu yok`
        : 'hiç başarılı koşu olmamış'} (eşik ${is.esikSaat} saat)`
        + `${k.son_hata ? ` — son hata: ${k.son_hata}` : ''}`);
      continue;
    }
    if (is.tablo) {
      // Tablo hiç okunamadıysa (migrasyon uygulanmamış / sorgu düştü) SUS:
      // yanlış alarm, alarmsızlıktan daha pahalıdır — süreç sinyali (yukarısı)
      // gerçek bir duruşu zaten yakalıyor.
      if (olculer[is.tablo] === undefined) continue;
      const olcu = an(olculer[is.tablo]);
      if (!olcu || simdi - olcu > esikMs) {
        ekle('olcu_bayat', `${is.etiket}: iş koşuyor ama ${is.tablo} tablosuna `
          + `${olcu ? yasDir(simdi - olcu) : 'hiç'} satır yazılmadı`);
      }
    }
  }
  return sorunlar;
}

// ---------------------------------------------------------------------------
// DB sarmalayıcıları — `sorgu(metin, parametreler) => { rows }`
// ---------------------------------------------------------------------------

/** İşin nöbet kaydını okur (yoksa null). */
export async function nobetOku(sorgu, ad) {
  const { rows } = await sorgu('SELECT deger FROM ayarlar WHERE anahtar = $1',
    [nobetAnahtari(ad)]);
  return nobetCoz(rows[0]?.deger);
}

/**
 * Koşu sonucunu yazar. OKU-YAZ yarışı yok: her işi tek bir koşucu çalıştırır
 * (ısıtıcı `flock` + advisory lock, tazelemeler küme içinde görevli işçi).
 */
export async function nobetKaydet(sorgu, ad, { hata = null, simdi = Date.now() } = {}) {
  const eski = await nobetOku(sorgu, ad).catch(() => null);
  const yeni = nobetGuncelle(eski, { hata, simdi });
  await sorgu(
    `INSERT INTO ayarlar (anahtar, deger, guncelleme) VALUES ($1, $2, now())
       ON CONFLICT (anahtar) DO UPDATE SET deger = EXCLUDED.deger, guncelleme = now()`,
    [nobetAnahtari(ad), JSON.stringify(yeni)]);
  return yeni;
}

/** Tüm nöbet kayıtları: `{ isitici: {...}, seo_bolum_olcu: {...} }`. */
export async function nobetKayitlari(sorgu) {
  const { rows } = await sorgu(
    'SELECT anahtar, deger FROM ayarlar WHERE anahtar LIKE $1', [`${NOBET_ONEK}%`]);
  const k = {};
  for (const r of rows) k[String(r.anahtar).slice(NOBET_ONEK.length)] = nobetCoz(r.deger);
  return k;
}

/**
 * Ölçü tablolarının son yazım zamanı: `{ seo_bolum_olcu: '2026-09-17T…' }`.
 *
 * Tablo adları NOBET_ISLER'den gelir (kullanıcı girdisi değil) — dize
 * birleştirme burada güvenli. Tablo yoksa (migrasyon uygulanmamış) anahtar
 * DÖNMEZ: `nobetSorunlari` onu "bilinmiyor" sayıp susar, panel de yanlış
 * alarm vermez.
 */
export async function olcuYaslari(sorgu, isler = NOBET_ISLER) {
  const tablolar = Object.values(isler).map((i) => i.tablo).filter(Boolean);
  const sonuc = {};
  for (const t of tablolar) {
    try {
      const { rows } = await sorgu(`SELECT max(olculdu) AS son FROM ${t}`);
      sonuc[t] = rows[0]?.son ?? null;
    } catch {
      /* tablo yok / sorgu düştü: anahtarı hiç koyma (bkz. üstteki not) */
    }
  }
  return sonuc;
}
