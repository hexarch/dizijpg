// Açık sohbet damgası — SAF mantık (Express/pg yok).
//
// Amaç: karşı taraf BU konuşmanın ekranındayken mesaj push'u gitmesin.
// WhatsApp/Telegram davranışı: bakıyorsan zil çalmaz; ekranı kapatınca çalar.
//
// Neden ayrı modül: TTL / kapat-lütfu / budama kuralları kaynak regex'ine
// kilitlenmesin diye gerçek fonksiyonlar test edilir
// (`backend/test/sohbet_bakiyor.test.js`).
//
// ESKİ İSTEMCİ: `bakiyor=1` göndermez → damga hiç yazılmaz → push eskisi
// gibi gider. Yeni istemci sohbet görünürken yoklamaya `bakiyor=1` ekler;
// sekme/uygulama arka plana düşünce `POST /sohbet/bakiyor {acik:false}`
// damgayı hemen kapatır.

/** Yoklama 3 sn. İki kaçan tur + ağ payı: hâlâ "bakıyor" sayılsın. */
export const SOHBET_ACIK_MS = 8_000;

/**
 * Kapatmanın ardından gelen GEÇ kalmış GET (uçuştaki yoklama) damgayı
 * yeniden açmasın. 1,5 sn tipik RTT'nin üstünde, sohbeti hemen geri
 * açanın POST {acik:true} zorla yolunu kullanmasına yeter.
 */
export const SOHBET_KAPAT_LUTFU_MS = 1_500;

/** Bellek tavanı; aşılınca 60 sn'den eski damgalar budanır. */
export const SOHBET_ACIK_TAVAN = 5_000;

/**
 * @param {number|string} bakanId sohbeti AÇIK tutan kullanıcı
 * @param {number|string} partnerId konuştuğu kişi
 * @returns {string}
 */
export function sohbetAcikAnahtar(bakanId, partnerId) {
  return `${Number(bakanId)}:${Number(partnerId)}`;
}

/**
 * @param {Map<string, {z:number, kapali:boolean}>} harita
 * @param {number} zaman
 */
function budan(harita, zaman) {
  if (harita.size <= SOHBET_ACIK_TAVAN) return;
  const esik = zaman - 60_000;
  for (const [k, v] of harita) {
    if ((v?.z ?? 0) < esik) harita.delete(k);
  }
}

/**
 * Sohbet ekranı açık: damgayı yenile.
 * `zorla` değilse, az önce kapatılmışsa uçuştaki GET yok sayılır.
 *
 * @param {Map<string, {z:number, kapali:boolean}>} harita
 * @param {number|string} bakanId
 * @param {number|string} partnerId
 * @param {number} [zaman]
 * @param {boolean} [zorla]
 */
export function sohbetAcikIsaretle(
  harita, bakanId, partnerId, zaman = Date.now(), zorla = false,
) {
  const anahtar = sohbetAcikAnahtar(bakanId, partnerId);
  const onceki = harita.get(anahtar);
  if (!zorla && onceki?.kapali && zaman - onceki.z < SOHBET_KAPAT_LUTFU_MS) {
    return;
  }
  harita.set(anahtar, { z: zaman, kapali: false });
  budan(harita, zaman);
}

/**
 * Ekran kapandı / uygulama arka plana düştü: damgayı hemen kapat.
 *
 * @param {Map<string, {z:number, kapali:boolean}>} harita
 * @param {number|string} bakanId
 * @param {number|string} partnerId
 * @param {number} [zaman]
 */
export function sohbetAcikKapat(harita, bakanId, partnerId, zaman = Date.now()) {
  harita.set(sohbetAcikAnahtar(bakanId, partnerId), { z: zaman, kapali: true });
}

/**
 * Alıcı bu konuşmanın ekranında mı? Evetse mesaj bildirimi (push + zil
 * satırı) üretilmez — mesaj zaten yoklamayla balon olarak iner.
 *
 * @param {Map<string, {z:number, kapali:boolean}>} harita
 * @param {number|string} bakanId alıcı
 * @param {number|string} partnerId gönderen
 * @param {number} [zaman]
 * @returns {boolean}
 */
export function sohbetAcikMi(harita, bakanId, partnerId, zaman = Date.now()) {
  const v = harita.get(sohbetAcikAnahtar(bakanId, partnerId));
  if (!v || v.kapali) return false;
  return zaman - v.z < SOHBET_ACIK_MS;
}
