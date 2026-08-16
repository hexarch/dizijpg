// Sohbet canlı durumu — SAF mantık (Express/pg yok).
//
// Karşı tarafa "yazıyor / ses kaydediyor" göstermek için bellek damgası.
// Kalıcılık YOK ve İSTENMİYOR: süreç düşünce herkes durmuş sayılır.
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
