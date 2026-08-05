// Çevrimiçi durumu + mesaj isteği ayrımı — SAF mantık.
//
// Buradaki her şey veritabanından ve Express'ten bağımsızdır ki
// `backend/test/mesaj_istekleri.test.js` gerçek fonksiyonları çağırıp
// davranışı ölçebilsin (kaynak metnini okuyup regex tutturmak değil).
// server.js bu modülü içe aktarır; kural değişirse test kırmızıya döner.

/**
 * "Çevrimiçi" eşiği (saniye).
 *
 * 180 sn seçildi:
 *  - Yazma seyreltmesi 60 sn olduğu için bir kullanıcının damgası en kötü
 *    60 sn bayattır. Eşik seyreltmeden BÜYÜK olmak zorunda; küçük olsaydı
 *    aralıksız gezinen bir kullanıcı bile aralıklarla çevrimdışı görünür,
 *    yeşil nokta yanıp sönerdi.
 *  - Uygulama açıkken hiç istek atmadan okunan uzun bir gönderi ~2 dk sürer;
 *    180 sn bunu tolere eder.
 *  - Uygulamayı KAPATANIN noktası en geç 180 sn (yazma anına göre en çok
 *    240 sn) içinde söner. Daha uzun bir eşik göstergeyi yalancı yapardı.
 *  - Admin panelindeki "şu an çevrimiçi" sayacı da aynı 3 dakikayı kullanır:
 *    sistemde çevrimiçiliğin TEK tanımı var.
 */
export const CEVRIMICI_ESIK_SN = 180;

/**
 * son_gorulme yazma seyreltmesi (ms).
 *
 * Her istekte UPDATE atmak pahalı: presence, sistemdeki en sık yazma olurdu.
 * Kullanıcı başına en fazla 60 sn'de bir yazılır. Ölçüm: dakikada ~30 istek
 * atan (liste kaydıran, sohbeti 5 sn'de bir yoklayan) bir kullanıcı
 * seyreltmesiz saatte 1800 UPDATE üretirdi; 60 sn ile 60 UPDATE üretir —
 * 30 KAT azalma. Eski 20 sn'ye göre de 3 kat azalma.
 */
export const SON_GORULME_YAZMA_ARALIGI_MS = 60_000;

/**
 * Bu kullanıcı için şimdi son_gorulme yazılmalı mı?
 * `harita` kullanıcı id -> son yazma zamanı (ms). Yazılacaksa harita
 * GÜNCELLENİR (çağıran ayrıca işaretlemek zorunda kalmasın).
 */
export function sonGorulmeYazilmali(harita, kullaniciId, simdi = Date.now()) {
  const oncekiZaman = harita.get(kullaniciId);
  if (oncekiZaman != null &&
      simdi - oncekiZaman < SON_GORULME_YAZMA_ARALIGI_MS) {
    return false;
  }
  harita.set(kullaniciId, simdi);
  return true;
}

/**
 * Kullanıcı çevrimiçi mi? Gizlilik tercihi BURADA uygulanır: tercihi açık
 * olan için damga ne olursa olsun false döner — istemciye ham son_gorulme
 * hiç gitmediği için tercih istemci tarafından aşılamaz.
 */
export function cevrimiciMi(sonGorulme, cevrimiciGizli, simdi = Date.now()) {
  if (cevrimiciGizli) return false;
  if (sonGorulme == null) return false;
  const an = sonGorulme instanceof Date ? sonGorulme : new Date(sonGorulme);
  if (Number.isNaN(an.getTime())) return false;
  return simdi - an.getTime() < CEVRIMICI_ESIK_SN * 1000;
}

/**
 * Bir sohbet MESAJ İSTEĞİ mi?
 *
 *   ana liste  <=> listenin sahibi karşı tarafı TAKİP EDİYOR **ya da**
 *                  o sohbete kendisi en az bir mesaj YAZMIŞ
 *   istekler   <=> ikisi de değil
 *
 * "ben_yazdim" şartı neden var:
 *  1) CEVAP VERMEK ZATEN KABULDÜR. Yazıştığım biri her açılışta istek
 *     kutusuna düşseydi sohbet sürekli gözden kaybolurdu.
 *  2) Takip etmediğim birine BEN yazdıysam sohbet, kendi başlattığım halde
 *     "bana gelen istek" diye görünürdü.
 * Takip tek yönlü yeter (karşılıklılık aranmaz). Kural DURUMDAN türetilir,
 * kalıcı bir "kabul edildi" bayrağı tutulmaz: takipten çıkıp hiç yazmamışsam
 * sohbet isteklere geri düşer, fazladan tablo ve senkron derdi olmaz.
 */
export function sohbetIstekMi(sohbet) {
  return !sohbet.takip_ediyorum && !sohbet.ben_yazdim;
}

/** Sohbet satırlarını ana liste / istekler diye ikiye ayırır (sıra korunur). */
export function sohbetleriAyir(satirlar) {
  const sohbetler = [];
  const istekler = [];
  for (const s of satirlar) (sohbetIstekMi(s) ? istekler : sohbetler).push(s);
  return { sohbetler, istekler };
}

/** Rozet sayısı: okunmamış mesajı OLAN istek sayısı. */
export function istekRozeti(istekler) {
  return istekler.filter((s) => (s.okunmamis || 0) > 0).length;
}
