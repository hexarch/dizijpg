// Sohbet canlı durumu — SAF mantık (Express/pg yok).
//
// Karşı tarafa "yazıyor / ses kaydediyor" göstermek için bellek damgası.
// Kalıcılık İSTENMİYOR: süreç düşünce herkes durmuş sayılır.
// Kümede aynı damga `sohbet_canli` tablosuna da yazılır (server.js) — yoksa
// POST işçi A, GET işçi B boş harita okur; çevrimiçi (PG) görünür, yazıyor yok.
//
// Eski kayıt biçimi yalnız epoch sayısıydı; okuma onu hâlâ "yaziyor" sayar
// ki küme işçilerinden biri eski paket gönderirse gösterge kaybolmasın.

/** Yoklama 3 sn, istemci 2 sn'de bir tazeler; bir kaçan tur payı. */
export const SOHBET_DURUM_MS = 10_000;

export const SOHBET_DURUM_TAVAN = 5_000;

export const SOHBET_DURUM_TURLER = Object.freeze(['yaziyor', 'kayit']);

/**
 * Gövdedeki `tur` alanını kapalı kümeye çevirir. Bilinmeyen → yazıyor
 * (eski istemci tur göndermez).
 *
 * @param {unknown} ham
 * @returns {'yaziyor'|'kayit'}
 */
export function sohbetDurumTur(ham) {
  return ham === 'kayit' ? 'kayit' : 'yaziyor';
}

/**
 * @param {unknown} kayit
 * @returns {number}
 */
function zamanAl(kayit) {
  if (kayit == null) return 0;
  if (typeof kayit === 'number') return kayit;
  return Number(kayit.z) || 0;
}

/**
 * @param {Map<string, {z:number, tur:string}|number>} harita
 * @param {string} anahtar `gonderenId:aliciId`
 * @param {unknown} tur
 * @param {number} [zaman]
 */
export function sohbetDurumYaz(harita, anahtar, tur, zaman = Date.now()) {
  harita.set(anahtar, { z: zaman, tur: sohbetDurumTur(tur) });
  if (harita.size <= SOHBET_DURUM_TAVAN) return;
  const esik = zaman - 60_000;
  for (const [k, v] of harita) {
    if (zamanAl(v) < esik) harita.delete(k);
  }
}

/**
 * @param {Map<string, unknown>} harita
 * @param {string} anahtar
 */
export function sohbetDurumSil(harita, anahtar) {
  harita.delete(anahtar);
}

/**
 * @param {Map<string, {z:number, tur:string}|number>} harita
 * @param {string} anahtar
 * @param {number} [simdi]
 * @returns {'yaziyor'|'kayit'|null}
 */
export function sohbetDurumOku(harita, anahtar, simdi = Date.now()) {
  const kayit = harita.get(anahtar);
  if (kayit == null) return null;
  const z = zamanAl(kayit);
  if (!z || simdi - z >= SOHBET_DURUM_MS) return null;
  if (typeof kayit === 'number') return 'yaziyor';
  return kayit.tur === 'kayit' ? 'kayit' : 'yaziyor';
}

// ---------- Emoji efekti (5 Eyl 2026) ----------
//
// Büyük emoji balonuna dokunulunca karşı taraf da aynı patlamayı görsün
// (Telegram'ın etkileşimli emojisi). Yazıyor damgasıyla AYNI kalıp: bellek
// içi, kısa ömürlü, kümede `yayinla` ile kardeş işçilere kopyalanır.
// Kalıcılık YOK: efekt "şu an" içindir, sonradan görülmesi anlamsız.

/** İstemci yoklaması 1 sn; 8 sn bir kaçan tur payıyla bol. */
export const SOHBET_EFEKT_MS = 8_000;

const EFEKT_DESEN = /^(?:\p{Extended_Pictographic}|\p{Regional_Indicator}|\p{Emoji_Modifier}|\u200D|\uFE0F)+$/u;

/**
 * Gövdedeki emojiyi doğrular: yalnız resimsi karakterler (ZWJ/seçici/ten
 * tonu dahil), en çok 16 kod birimi. Geçersiz → null.
 *
 * @param {unknown} ham
 * @returns {string|null}
 */
export function sohbetEfektEmoji(ham) {
  if (typeof ham !== 'string') return null;
  const t = ham.trim();
  if (!t || t.length > 16) return null;
  return EFEKT_DESEN.test(t) ? t : null;
}

/**
 * @param {Map<string, {emoji:string, z:number}>} harita
 * @param {string} anahtar `gonderenId:aliciId`
 * @param {string} emoji
 * @param {number} [zaman]
 */
export function sohbetEfektYaz(harita, anahtar, emoji, zaman = Date.now()) {
  harita.set(anahtar, { emoji, z: zaman });
  if (harita.size <= SOHBET_DURUM_TAVAN) return;
  const esik = zaman - 60_000;
  for (const [k, v] of harita) {
    if (!v || v.z < esik) harita.delete(k);
  }
}

/**
 * @param {Map<string, {emoji:string, z:number}>} harita
 * @param {string} anahtar
 * @param {number} [simdi]
 * @returns {{emoji:string, z:number}|null}
 */
export function sohbetEfektOku(harita, anahtar, simdi = Date.now()) {
  const k = harita.get(anahtar);
  if (!k || !k.emoji || !Number.isFinite(k.z)) return null;
  if (simdi - k.z >= SOHBET_EFEKT_MS) return null;
  return { emoji: k.emoji, z: k.z };
}
