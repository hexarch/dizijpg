// Sohbete özel PAYLAŞILAN ayarlar (15 Eyl 2026): tema + takma ad.
//
// · TEMA çift başına TEK kayıttır (sohbet_temalari, a_id<b_id). İki taraf da
//   değiştirebilir, ikisi de aynı temayı görür ("temayı ben değiştirince
//   karşı tarafta da değişmeli"). Anahtar istemcinin tema listesindeki
//   kimliktir; sunucu listeyi bilmez, yalnız biçimi doğrular — tanınmayan
//   anahtar istemcide varsayılana düşer (SohbetTemalari.bul).
// · TAKMA AD tek yönlüdür (dm_takma_adlar): "ben ona ne diyorum". Karşı
//   taraf görmez, sunucu yalnız sahibine döndürür (dm_sessiz kalıbı).

export const TEMA_ANAHTAR_AZAMI = 32;
export const TAKMA_AD_AZAMI = 32;

/** Tema anahtarı: küçük harf/rakam/alt çizgi, 1-32. 'varsayilan' silme demektir. */
export function temaAnahtariGecerli(s) {
  return typeof s === 'string' && /^[a-z0-9_]{1,32}$/.test(s);
}

/** Çift anahtarı: küçük id önce. Aynı sohbet iki yönden de tek satıra düşer. */
export function ciftAnahtari(aId, bId) {
  const a = Number(aId), b = Number(bId);
  return a < b ? [a, b] : [b, a];
}

// Denetim karakterleri (C0 + DEL) ve görünmez biçimlendirme işaretleri.
const GORUNMEZ = new RegExp(
  '[' + String.fromCharCode(0) + '-' + String.fromCharCode(31) +
  String.fromCharCode(127) + '\\u200b-\\u200f\\u2028\\u2029]', 'g',
);

/**
 * Takma adı temizler: kırpma, ardışık boşlukları teke indirme, denetim
 * karakterlerini atma, 32 karakter tavanı. Boş → null (= kaldır).
 * Geçersiz tür → undefined (400).
 */
export function takmaAdTemizle(ham) {
  if (ham === null || ham === undefined) return null;
  if (typeof ham !== 'string') return undefined;
  const t = ham.replace(GORUNMEZ, '').replace(/\s+/g, ' ').trim();
  if (!t) return null;
  return Array.from(t).slice(0, TAKMA_AD_AZAMI).join('');
}
