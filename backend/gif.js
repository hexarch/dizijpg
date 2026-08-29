// KENDİ GIF ARŞİVİMİZ — SAF modül (Express yok, `pg` yok, `process.env` yok).
//
// `kripto.js` / `yasak.js` / `medya_imza.js` ile aynı kalıp: içe aktarma
// HİÇBİR yan etki yapmaz, böylece `test/gif_gorunurluk.test.js` gerçek
// fonksiyonları ÇAĞIRIP davranışı ölçer — kaynak metni greplemez.
//
// ---------------------------------------------------------------------------
// NEDEN AYRI DOSYA: +18 ŞARTI TEK BİR FONKSİYONA BAĞLANSIN
// ---------------------------------------------------------------------------
// Kullanıcının sert şartı: onaysız GIF HİÇBİR başka kullanıcıya görünmemeli.
// Bu kural üç ayrı okuma ucunda (arama, trend, yüklediklerim) geçerli. Kuralı
// üç SQL metnine kopyalasaydık, birinde unutulan bir dal sessizce +18 içeriği
// yayınlardı ve hiçbir test bunu yakalamazdı. Bu yüzden kural TEK yerde:
// `gifSuzgec`. Üç uç da onu çağırır; test de onu çağırır.
//
// DURUM MAKİNESİ
//   'bekliyor'   → YALNIZ yükleyeni görür
//   'onayli'     → herkes görür
//   'reddedildi' → HİÇ KİMSE görmez (yükleyeni DE dahil — kullanıcı isteği:
//                  "reddedilen GIF hem arşivden hem yükleyenin seçicisinden
//                  düşmeli")
// Reddedilen için ayrı bir dal YOKTUR; iki dalın da dışında kaldığı için
// düşer. Bu bilinçli: "reddedileni gizle" diye NEGATİF bir koşul yazsaydık,
// yeni bir durum eklendiğinde (ör. 'karantina') varsayılan GÖRÜNÜR olurdu.
// Burada varsayılan GÖRÜNMEZ.

/** Geçerli durumlar — `sikayetler`/`gifler` CHECK kısıtıyla aynı sıra. */
export const GIF_DURUMLARI = ['bekliyor', 'onayli', 'reddedildi'];

/** Geçerli kaynaklar. 'kamu-mali' lisans + atıf ZORUNLU (tablo kısıtı). */
export const GIF_KAYNAKLARI = ['kullanici', 'kamu-mali'];

/** Bir GIF kaydına en çok kaç etiket. */
export const ETIKET_AZAMI = 8;
/** Tek etiketin karakter sınırı. */
export const ETIKET_UZUNLUK_AZAMI = 30;
/** Arama sorgusunun karakter sınırı (trigram indeksi uzun sorguda anlamsız). */
export const SORGU_UZUNLUK_AZAMI = 60;
/** Sayfa boyu — istemci ızgarası 3 sütun, 10 satır. */
export const SAYFA_BOYU = 30;

/**
 * GÖRÜNÜRLÜK KURALI — arşivin tek güvenlik kapısı.
 *
 * @param {number|null} isteyenId  Giriş yapmış kullanıcının id'si; misafir/anonim
 *                                 için null.
 * @param {number} ilkParametre    Üretilecek `$n` yer tutucusunun numarası
 *                                 (çağıran sorguda kaçıncı parametreden
 *                                 başlanacağı). Varsayılan 1.
 * @returns {{kosul: string, parametreler: any[]}}
 *   `kosul` doğrudan WHERE'e konur; `parametreler` sorgu dizisine EKLENİR.
 *
 * Tablo takma adı `g` VARSAYILIR (üç uç da `FROM gifler g` yazar).
 */
export function gifSuzgec(isteyenId, ilkParametre = 1) {
  const kimlikVar = Number.isInteger(isteyenId) && isteyenId > 0;
  if (!kimlikVar) {
    // Misafir ya da kimliksiz istek: YALNIZ onaylı. Bekleyen dalı yok.
    return { kosul: "g.durum = 'onayli'", parametreler: [] };
  }
  return {
    kosul: `(g.durum = 'onayli'`
      + ` OR (g.durum = 'bekliyor' AND g.yukleyen_id = $${ilkParametre}))`,
    parametreler: [isteyenId],
  };
}

/**
 * "Yüklediklerim" listesinin kuralı — AYRI, çünkü burada kullanıcı kendi
 * BEKLEYEN kayıtlarını da onaylılarıyla birlikte görmeli ama BAŞKASININ
 * hiçbir kaydını görmemeli. Reddedilen yine düşer (kullanıcı isteği).
 */
export function kendiGifSuzgeci(isteyenId, ilkParametre = 1) {
  if (!(Number.isInteger(isteyenId) && isteyenId > 0)) {
    return { kosul: 'false', parametreler: [] };
  }
  return {
    kosul: `g.yukleyen_id = $${ilkParametre} AND g.durum <> 'reddedildi'`,
    parametreler: [isteyenId],
  };
}

/**
 * Yüklenen dosyanın GERÇEKTEN bu kullanıcının, GERÇEKTEN bizim ürettiğimiz
 * bir GIF adı olduğunu doğrular. `POST /mesajlar`daki sahiplik regex'iyle
 * AYNI kalıp; tek fark uzantının yalnız `gif` olması.
 *
 * Dosyanın diskte var olduğunu BU FONKSİYON DOĞRULAMAZ (saf modül, `fs` yok);
 * çağıran `fs.existsSync` ile tamamlar — `POST /mesajlar` da öyle yapıyor.
 */
export function gifYoluGecerli(yol, kullaniciId) {
  if (typeof yol !== 'string') return false;
  if (!(Number.isInteger(kullaniciId) && kullaniciId > 0)) return false;
  return new RegExp(`^/medya/m${kullaniciId}-[0-9a-f]{16}\\.gif$`).test(yol);
}

/**
 * Etiketleri temizler: kırp → küçült → boşlukları teke indir → tekilleştir.
 * Sıra korunur (kullanıcının yazdığı sıra anlamlıdır).
 *
 * Neden `toLocaleLowerCase('tr')` DEĞİL: Türkçe kuralında 'I' → 'ı' olur ve
 * "GIF" etiketi "gıf"a döner; arama "gif" yazan herkes için kaçırırdı.
 * Arama tarafı da düz `toLowerCase` kullanır — iki taraf AYNI olmalı.
 */
export function etiketleriTemizle(ham) {
  if (!Array.isArray(ham)) return [];
  const cikti = [];
  for (const parca of ham) {
    if (typeof parca !== 'string') continue;
    const t = parca.trim().toLowerCase().replace(/\s+/g, ' ')
      .slice(0, ETIKET_UZUNLUK_AZAMI).trim();
    if (t.length < 2) continue;
    if (cikti.includes(t)) continue;
    cikti.push(t);
    if (cikti.length >= ETIKET_AZAMI) break;
  }
  return cikti;
}

/**
 * Trigram indeksinin taradığı düz metin. Etiketler boşlukla birleşir.
 * Kolon ayrı tutuluyor çünkü `gin_trgm_ops` TEXT[] üzerinde çalışmaz.
 */
export function aramaMetniUret(etiketler) {
  return etiketler.join(' ').slice(0, 400);
}

/** Arama sorgusunu normalleştirir; boş dönerse çağıran trend listesine düşer. */
export function sorguNormalle(ham) {
  if (typeof ham !== 'string') return '';
  return ham.trim().toLowerCase().replace(/\s+/g, ' ')
    .slice(0, SORGU_UZUNLUK_AZAMI);
}

/** Sayfa numarasını güvenli aralığa çeker (0 tabanlı offset döner). */
export function sayfaOfseti(ham, sayfaBoyu = SAYFA_BOYU) {
  const n = Number.parseInt(ham, 10);
  if (!Number.isFinite(n) || n < 1) return 0;
  return Math.min(n - 1, 200) * sayfaBoyu;   // en fazla 200. sayfa
}
