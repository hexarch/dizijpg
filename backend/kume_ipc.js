// dizi.jpg — işçi tarafı küme IPC istemcisi (yapilacaklar2 D1).
//
// server.js bir `node:cluster` İŞÇİSİ olarak çalışırken süreçler arası üç
// ihtiyacı var; üçü de bu modülden geçer:
//
//   1. YAYIN (broadcast): bellek-içi durumun işçiler arasında tutarlı kalması
//      gereken küçük olayları birincil süreç ÜZERİNDEN tüm kardeş işçilere
//      iletir. Kullanım yerleri ve gerekçeleri server.js'te, çağrı başında:
//      `yaziyor` (yazıyor... göstergesi), `sohbet_bakiyor` (açık sohbet
//      damgası — bakıyorken mesaj push'u kesilir), `ozel_medya_*` (DM medya gizliliği),
//      `sv_sil` (şifre/ban önbelleği düşürme), `tohum` (akış sayfalama listesi).
//   2. SAYAÇ RPC: kaba kuvvete bakan hız limitleri (auth, şifre sıfırlama)
//      işçi başına değil KÜME GENELİNDE sayılmalı — yoksa N işçide limit
//      fiilen N katına gevşer. Sayacı birincil tutar.
//   3. İSTEK TELEMETRİSİ: admin panelin istek/dk grafiği ve 3D globe'u
//      bellek-içi `ISTEK` halkasından beslenir. İşçi başına halka, paneli
//      1/N'lik ve her yenilemede zıplayan bir görüntüye çevirirdi; kayıtlar
//      birincile gönderilir, panel oradan okur.
//
// TASARIM KURALLARI:
//   · KÜMESİZ ÇALIŞMA AYNEN KORUNUR: `node server.js` (testler, geliştirme,
//     NODE_ISCI=0) altında process.send yoktur → yayinla no-op olur, abone
//     hiç tetiklenmez, RPC'ler null döner ve çağıran yerel yoluna düşer.
//   · RPC ASLA REJECT ETMEZ, en fazla null döner. Hız limiti ya da admin
//     paneli yüzünden bir kullanıcı isteği 500 YEMEZ; birincil cevap
//     veremiyorsa işçi kendi yerel katmanıyla yaşamaya devam eder (fail-open,
//     gerekçesi server.js `hizLimitiMerkezi` başlığında).
//   · Birincil ile mesaj zarfı: {k:'yayin'|'rpc'|'rpc_cevap'|'istek', ...}.
//     `cluster` modülünün kendi iç mesajları (cmd:'NODE_...') `k` alanı
//     taşımadığı için burada sessizce elenir.

/** İşçi sırası ('1'..'N') ya da boş dize (kümesiz). Fork eden birincil verir. */
const SIRA = String(process.env.ISCI_SIRA || '');

/** Küme işçisi miyiz? İKİ koşul birden: IPC kanalı var VE sıra atanmış.
 *  (Yalnız process.send'e bakmak yetmez: başka bir süreç de bizi IPC ile
 *  spawn edebilir — testler bunu yapıyor.) */
export function kumelenmisMi() {
  return typeof process.send === 'function' && SIRA !== '';
}

export function isciSira() { return SIRA; }

// ---------------------------------------------------------------------------
// Gelen mesaj dağıtımı
// ---------------------------------------------------------------------------

const aboneler = new Map();   // konu -> [fn]
const bekleyenRpc = new Map(); // id -> {coz, zamanlayici}
let rpcSayaci = 0;

if (kumelenmisMi()) {
  process.on('message', (m) => {
    if (!m || typeof m !== 'object') return;
    if (m.k === 'yayin') {
      for (const fn of aboneler.get(m.konu) || []) {
        // Tek bozuk abone diğerlerini (ve mesaj döngüsünü) düşürmesin.
        try { fn(m.veri); } catch { /* abone hatası yayını durdurmaz */ }
      }
    } else if (m.k === 'rpc_cevap') {
      const b = bekleyenRpc.get(m.id);
      if (b) {
        bekleyenRpc.delete(m.id);
        clearTimeout(b.zamanlayici);
        b.coz(m.veri ?? null);
      }
    }
  });
}

/** Bir yayın konusuna abone ol. Kümesizken kayıt zararsızdır (hiç tetiklenmez). */
export function abone(konu, fn) {
  const dizi = aboneler.get(konu) || [];
  dizi.push(fn);
  aboneler.set(konu, dizi);
}

/** Konuyu birincile gönder; birincil DİĞER işçilere dağıtır (gönderen zaten
 *  yerel uygulamış olur — çift uygulama olmaz). Kümesizken no-op. */
export function yayinla(konu, veri) {
  if (!kumelenmisMi()) return false;
  try { process.send({ k: 'yayin', konu, veri }); return true; } catch { return false; }
}

/**
 * Birincile RPC. Zaman aşımında/hatada NULL döner, asla fırlatmaz —
 * çağıranlar null'u "birincile ulaşamadım, yerel yola düş" okur.
 */
export function rpc(ad, veri, zamanAsimiMs = 500) {
  if (!kumelenmisMi()) return Promise.resolve(null);
  return new Promise((coz) => {
    const id = ++rpcSayaci;
    const zamanlayici = setTimeout(() => {
      bekleyenRpc.delete(id);
      coz(null);
    }, zamanAsimiMs);
    zamanlayici.unref?.(); // bekleyen RPC tek başına süreci ayakta tutmasın
    bekleyenRpc.set(id, { coz, zamanlayici });
    try {
      process.send({ k: 'rpc', id, ad, veri });
    } catch {
      bekleyenRpc.delete(id);
      clearTimeout(zamanlayici);
      coz(null);
    }
  });
}

/** Küme geneli saatlik sayaç: birincildeki sayacı 1 artırır ve yeni değeri
 *  döndürür. Ulaşamazsa null (çağıran yerel limitiyle yetinir). Zaman aşımı
 *  KISA (300 ms): bu çağrı auth yolunun üstünde, kullanıcıyı bekletemez. */
export function sayacArtir(anahtar) {
  return rpc('sayac', { a: String(anahtar) }, 300).then((c) => (
    c && Number.isInteger(c.sayi) ? c.sayi : null));
}

/** İstek telemetri kaydını birincile yolla (ateşle-unut). */
export function istekKaydet(kayit) {
  if (!kumelenmisMi()) return;
  try { process.send({ k: 'istek', veri: kayit }); } catch { /* telemetri isteği bozmaz */ }
}

/** Birincildeki birleşik istek telemetrisi. Ulaşamazsa null (çağıran işçinin
 *  yerel halkasına düşer — eksik ama boş değil). */
export function istekOzet() {
  return rpc('istek_ozet', null, 800);
}
