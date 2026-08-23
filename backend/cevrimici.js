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
 * Takip tek yönlü yeter (karşılıklılık aranmaz). Kural DURUMDAN türetilir;
 * tek istisna kullanıcının AÇIK kararıdır (mesaj_istek_kararlari tablosu,
 * satırda `istek_karar` olarak gelir): "Kabul et" cevap yazmadan ana listeye
 * taşır — bu durumdan türetilemez, o yüzden kalıcı tutulur. Takipten çıkıp
 * hiç yazmamışsam ve karar da vermemişsem sohbet isteklere geri düşer.
 */
export function sohbetIstekMi(sohbet) {
  return !sohbet.takip_ediyorum && !sohbet.ben_yazdim &&
         sohbet.istek_karar !== 'kabul';
}

/**
 * Sohbet satırlarını ana liste / istekler / reddedilenler diye ayırır
 * (sıra korunur). Reddedilen (istek_karar='red') bir istek İstekler'de
 * GÖRÜNMEZ ama silinmez: Reddedilenler bölümünde durur, kullanıcı oradan
 * geri kabul edebilir (Instagram davranışı). Karşı tarafı takip etmeye
 * başlamak ya da cevap yazmak reddi türetilmiş düzeyde geçersiz kılar —
 * sohbet ana listeye döner (sohbetIstekMi false olur).
 */
export function sohbetleriAyir(satirlar) {
  const sohbetler = [];
  const istekler = [];
  const reddedilenler = [];
  for (const s of satirlar) {
    if (!sohbetIstekMi(s)) sohbetler.push(s);
    else if (s.istek_karar === 'red') reddedilenler.push(s);
    else istekler.push(s);
  }
  return { sohbetler, istekler, reddedilenler };
}

/** Rozet sayısı: okunmamış mesajı OLAN istek sayısı. */
export function istekRozeti(istekler) {
  return istekler.filter((s) => (s.okunmamis || 0) > 0).length;
}
