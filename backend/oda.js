// dizi.jpg — İZLEME ODASI: SAF mantık modülü.
//
// `arama.js` / `disk.js` / `kripto.js` ile aynı disiplin: burada Express de,
// `pg` de, `fs` de, `process.env` de YOK. İçe aktarma hiçbir yan etki yapmaz;
// her fonksiyon girdisini parametreden alır. Böylece `test/oda.test.js` bir
// oda açmadan, bir bayt yazmadan tüm kenar durumlarını sınayabilir.
//
// Kararlar ve gerekçeler: ../IZLEME-ODASI-PLANI.md.

// ---------------------------------------------------------------------------
// SABİTLER
// ---------------------------------------------------------------------------

/** Odanın ömrü. Kullanıcı kararı (3 Eyl 2026): "oda zaten 12 saat sonra silinecek". */
export const ODA_OMRU_MS = 12 * 60 * 60 * 1000;

/** Tek videonun tavanı. Kullanıcı kararı: "kullanıcı 5gb kadar dosya upload edebilir". */
export const ODA_VIDEO_AZAMI = 5 * 1024 ** 3;

/**
 * Bir odadaki azami kişi.
 *
 * NEDEN SINIR VAR: 2. turda sesli sohbet MESH kurulacak (N×(N-1) bağlantı);
 * 12 kişide 132 akış eder ve mobil cihaz bunu kaldırmaz. Sınırı ŞİMDİDEN
 * koymak, sesli tur geldiğinde canlıda 40 kişilik odalar bulmamayı sağlar —
 * sonradan daraltmak kullanıcıdan bir şey GERİ ALMAK olurdu.
 */
export const ODA_AZAMI_UYE = 12;

/** Katılım kodu uzunluğu. */
export const KOD_UZUNLUK = 6;

/**
 * Kod alfabesi — KARIŞAN KARAKTERLER YOK.
 *
 * `I`/`1`/`l`, `O`/`0` çıkarıldı: kod sesli okunacak ("odama gel, kod ...")
 * ve elle yazılacak. 32 karakter × 6 hane = 1,07 milyar kombinasyon; aynı anda
 * açık oda sayısı binlerle ölçüleceği için çakışma pratikte yok (yine de
 * INSERT tekil indekse çarparsa çağıran yeniden dener).
 */
export const KOD_ALFABE = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/** Tepki olarak kabul edilen emojiler — SABİT LİSTE. */
export const TEPKILER = ['❤️', '😂', '😮', '😢', '🔥', '👏', '👀', '💀'];

/** Oda sohbet mesajının azami uzunluğu (DM ile aynı mertebe). */
export const MESAJ_AZAMI = 1000;

/** Oda başlığının azami uzunluğu. */
export const BASLIK_AZAMI = 60;

/**
 * Bir üyenin "çevrimiçi" sayıldığı süre. Yoklama 1 sn'de bir `son_gorulme`
 * yazar; 15 sn hiç yoklamayan sekmesini kapatmıştır.
 */
export const CEVRIMICI_ESIK_MS = 15_000;

/**
 * Tek parçanın azami boyutu.
 *
 * nginx `client_max_body_size` **105m** — parça bunun ALTINDA kalmalı, yoksa
 * nginx 413'ü Node'a hiç ulaşmadan basar ve istemci "sunucu hatası" görür.
 * 8 MB seçildi, 100 MB değil: kopan bir parça YENİDEN gönderilir ve mobil
 * bağlantıda 100 MB'ı ikinci kez yollamak dakikalar demek. 5 GB'lık bir video
 * 8 MB'lık parçalarla 640 istek eder — `odaParcaLimiti` (4000/saat) buna göre.
 */
export const ODA_PARCA_AZAMI = 8 * 1024 * 1024;

/**
 * Makine hata kodu -> kullanıcıya gösterilecek TÜRKÇE metin.
 *
 * İstemci `kod` alanına göre dallanır (arama sözleşmesi §8 ile aynı disiplin);
 * bu metinler yalnız eski/bilinmeyen istemciler ve doğrudan API kullanımı
 * içindir. Uygulamadaki çeviriler `app/lib/oda/oda_api.dart`ta.
 */
export const ODA_HATA_METNI = {
  ODA_YOK: 'Böyle bir oda yok',
  ODA_KAPANDI: 'Bu oda kapandı',
  DAVET_YOK: 'Bu odaya girebilmek için davet ya da oda kodu gerekli',
  ODA_DOLU: 'Oda dolu',
  ENGELLI: 'Bu odaya giremezsin',
  UYE_DEGIL: 'Bu odanın üyesi değilsin',
  SAHIP_DEGIL: 'Bunu yalnız oda sahibi yapabilir',
  YETKI_YOK: 'Bunu oda sahibi ve yetki verdiği kişiler yapabilir',
  KENDI_ROLUN: 'Kendi yetkini değiştiremezsin',
  ROL_GECERSIZ: 'Geçersiz yetki',
  BAGLANTI_DESTEKSIZ: 'Bu adres desteklenmiyor',
};

/**
 * Yarım kalan yüklemenin ömrü. Kullanıcı 6 saat boyunca dönmezse parçası
 * silinir — yoksa kopan her yükleme diskte kalıcı bir çöp bırakırdı.
 */
export const YUKLEME_OMRU_MS = 6 * 60 * 60 * 1000;

// ---------------------------------------------------------------------------
// KOD
// ---------------------------------------------------------------------------

/**
 * Katılım kodu üretir.
 * @param {(n:number)=>Uint8Array|Buffer} rastgeleBayt kriptografik kaynak
 *   (sunucuda `crypto.randomBytes`; testte deterministik bir sahte).
 */
export function kodUret(rastgeleBayt) {
  const bayt = rastgeleBayt(KOD_UZUNLUK);
  let kod = '';
  for (let i = 0; i < KOD_UZUNLUK; i++) {
    kod += KOD_ALFABE[bayt[i] % KOD_ALFABE.length];
  }
  return kod;
}

/**
 * Kullanıcının yazdığı kodu normalleştirir; geçersizse null.
 *
 * Büyük harfe çevirir ve BOŞLUK/TİRE ATAR: kullanıcı kodu "ab3 k9x" ya da
 * "AB3-K9X" diye yazabilir, ikisi de aynı odadır.
 *
 * `O`, `0`, `I`, `1` alfabede YOK ve buraya gelirlerse REDDEDİLİR — "belki
 * sıfır demek istedi" diye tahmin edip yanlış odaya sokmaktansa "kod hatalı"
 * demek doğru. (Kod ÜRETİLİRKEN bu karakterler zaten hiç kullanılmıyor, yani
 * meşru bir kodda görülmeleri imkânsız.)
 */
export function kodNormalle(ham) {
  if (typeof ham !== 'string') return null;
  const k = ham.toUpperCase().replace(/[\s-]/g, '');
  if (k.length !== KOD_UZUNLUK) return null;
  for (const ch of k) if (!KOD_ALFABE.includes(ch)) return null;
  return k;
}

// ---------------------------------------------------------------------------
// SENKRON — bu modülün kalbi
// ---------------------------------------------------------------------------

/**
 * Odanın oynatma durumundan, verilen ANDA beklenen video konumunu türetir.
 *
 * ***BU FONKSİYON SUNUCUDA VE İSTEMCİDE AYNIDIR.*** Dart karşılığı
 * `app/lib/oda/oda_senkron.dart` içindeki `beklenenKonum`; ikisi birlikte
 * değiştirilmeli. Sunucudaki kopya, durum yazılırken konumu SÜREYE KIRPMAK
 * ve testlerin tek doğruyu kilitlemesi için var.
 *
 * @param {{oynuyor:boolean, konum_ms:number, konum_zaman:number, hiz:number}} durum
 *   `konum_zaman` epoch ms (sunucu saati).
 * @param {number} simdi epoch ms
 * @param {number|null} sureMs videonun toplam süresi; biliniyorsa konum buna kırpılır
 */
export function beklenenKonum(durum, simdi, sureMs = null) {
  const taban = Number(durum?.konum_ms) || 0;
  if (!durum?.oynuyor) return kirp(taban, sureMs);
  const hiz = Number(durum.hiz) > 0 ? Number(durum.hiz) : 1;
  // `|| simdi` YAZILAMAZ: `konum_zaman` 0 ise (test kurgusu, epok başı, bozuk
  // kayıt) sıfır YANLIŞLIKLA "değer yok" sayılır ve geçen süre daima 0 çıkar —
  // video hiç ilerlemez. Eksikliği `Number.isFinite` ile ayırıyoruz.
  const zamanHam = Number(durum.konum_zaman);
  const gecen = simdi - (Number.isFinite(zamanHam) ? zamanHam : simdi);
  // Geçmişe giden bir `konum_zaman` (saat geri alınmış, kayıt bozuk) konumu
  // GERİ ÇEKMEMELİ: negatif geçen süre 0 sayılır.
  return kirp(taban + Math.max(0, gecen) * hiz, sureMs);
}

function kirp(ms, sureMs) {
  const v = Math.max(0, Math.round(ms));
  if (sureMs == null || !(sureMs > 0)) return v;
  return Math.min(v, Math.round(sureMs));
}

// ---------------------------------------------------------------------------
// DOĞRULAMA
// ---------------------------------------------------------------------------

/** Kontrol karakterleri (satır sonu dahil) — tek satırlık alanlarda boşluğa çevrilir. */
const KONTROL = /[\u0000-\u001f\u007f]/g;

/** Oda başlığı: tek satır, kırpılır, boşsa null. */
export function baslikTemizle(ham) {
  if (typeof ham !== 'string') return null;
  const t = ham.replace(KONTROL, ' ').trim().slice(0, BASLIK_AZAMI).trim();
  return t || null;
}

/** Sohbet mesajı: kırpılır, boşsa null (boş mesaj gönderilemez). */
export function mesajTemizle(ham) {
  if (typeof ham !== 'string') return null;
  const t = ham.trim().slice(0, MESAJ_AZAMI);
  return t || null;
}

/** Tepki sabit listede mi. */
export function tepkiGecerli(ham) {
  return typeof ham === 'string' && TEPKILER.includes(ham);
}

/**
 * Yükleme boyutu kabul edilebilir mi.
 * @returns {{tamam:boolean, kod?:string}}
 */
export function boyutKontrol(boyut) {
  const n = Number(boyut);
  if (!Number.isFinite(n) || !Number.isInteger(n) || n <= 0) {
    return { tamam: false, kod: 'GECERSIZ_BOYUT' };
  }
  if (n > ODA_VIDEO_AZAMI) return { tamam: false, kod: 'VIDEO_COK_BUYUK' };
  return { tamam: true };
}

/**
 * Parça yazma kararı — devam edilebilir yüklemenin SÖZLEŞMESİ.
 *
 * İstemci `X-Ofset` ile "şu bayttan devam ediyorum" der. Üç durum:
 *   · ofset == beklenen  -> YAZ
 *   · ofset <  beklenen  -> TEKRAR (ağ koptu, istemci eski ofsetten döndü).
 *     Sunucu baytları YENİDEN YAZMAZ, "zaten bendeydi" der ve doğru ofseti
 *     bildirir. Yazmak, dosyanın ortasına ikinci kez aynı baytları koyup
 *     dosyayı BOZARDI (append kalıbı).
 *   · ofset >  beklenen  -> BOŞLUK. Kabul etmek dosyanın ortasında delik
 *     bırakırdı; 409 ile doğru ofset döner.
 * Ayrıca parça, beyan edilen toplam boyutu AŞAMAZ.
 */
export function parcaKarari(beklenenOfset, gelenOfset, parcaUzunluk, toplamBoyut) {
  const b = Number(beklenenOfset) || 0;
  const g = Number(gelenOfset);
  if (!Number.isInteger(g) || g < 0) return { karar: 'gecersiz', ofset: b };
  if (g < b) return { karar: 'tekrar', ofset: b };
  if (g > b) return { karar: 'bosluk', ofset: b };
  if (!(parcaUzunluk > 0)) return { karar: 'gecersiz', ofset: b };
  if (b + parcaUzunluk > toplamBoyut) return { karar: 'tasma', ofset: b };
  return { karar: 'yaz', ofset: b + parcaUzunluk };
}

// ---------------------------------------------------------------------------
// YETKİ
// ---------------------------------------------------------------------------

/** Rol değerleri — `oda_uyeler.rol` CHECK'i ile BİREBİR. */
export const ROLLER = ['sahip', 'yetkili', 'izleyici'];

/** Sahibin BAŞKASINA verebileceği roller. 'sahip' devredilemez (bu turda). */
export const VERILEBILIR_ROLLER = ['yetkili', 'izleyici'];

/**
 * Oynatma durumunu ve videoyu kim yönetebilir — **tek doğru nokta**.
 *
 * Kullanıcı isteği (4 Eyl 2026): *"oda sahibi diğer kullanıcılara yetki
 * verebilmeli yetki verdiği de aynı şekilde video durdurabilir kapatabilir"*.
 * Yani kontrol artık tek elde DEĞİL, ama dağıtımı tek elde: yalnız sahip
 * yetki verir (`rolVerebilir`).
 *
 * ===========================================================================
 * "KONTROL TEK ELDE" GEREKÇESİ NEDEN GEÇERSİZ KALDI — geri alma
 * ===========================================================================
 * İlk tasarımda yalnız sahip yazabiliyordu ve gerekçe şuydu: iki kişi aynı
 * anda sararsa her biri ötekinin konumuna düzeltme yapar ve oda SALINIMA
 * girer. Bu korku OTOMATİK düzeltme için doğruydu; burada geçerli DEĞİL:
 *   · Yazma yalnız KULLANICI EYLEMİNDE olur (düğmeye basmak), otomatik
 *     düzeltmede asla — düzeltme yalnız yerel oynatıcıyı sunucuya yaklaştırır.
 *   · Sunucudaki `surum` sayacı yazmaları SIRAYA SOKAR; herkes SON yazana
 *     uyar. İki kişi aynı saniyede sarsa bile sonuç tek ve tutarlıdır.
 * Bunu buraya yazıyorum ki ileride biri "tek elde olmalıydı" diye geri
 * almasın: geri alınacak şey yazma yetkisi değil, otomatik düzeltmenin
 * sunucuya yazmasıdır — o da zaten hiç yapılmıyor.
 *
 * KALP ATIŞI BU YETKİNİN İÇİNDE DEĞİL: 10 sn'lik konum tazeleme YALNIZ
 * sahiptedir (bkz. `oda_ekrani.dart` `_kalbiKur`). Birden fazla kişi
 * tazelerse birbirlerinin `konum_zaman` damgasını ezer ve izleyicilerde
 * küçük zıplamalar olur.
 *
 * @param {object|null} oda
 * @param {number} kullaniciId
 * @param {string|null} [rol] isteyenin `oda_uyeler.rol` değeri
 */
export function durumYazabilir(oda, kullaniciId, rol = null) {
  if (!oda) return false;
  if (oda.sahip_id === kullaniciId) return true;
  return rol === 'yetkili';
}

/**
 * Rol dağıtma yetkisi — YALNIZ SAHİP.
 *
 * Yetkili de yetki dağıtabilseydi sahip, kendi odasının kontrolünü zincirleme
 * biçimde tamamen kaybedebilirdi (yetkili yetkili atar, o da başkasını...).
 * Aynı gerekçe odayı kapatma ve davet için de geçerli; onlar da sahipte.
 */
export function rolVerebilir(oda, kullaniciId) {
  return !!oda && oda.sahip_id === kullaniciId;
}

/**
 * Bir rol ataması geçerli mi.
 *
 * @param {object|null} oda
 * @param {number} isteyenId
 * @param {number} hedefId
 * @param {string} rol
 * @param {boolean} hedefUyeMi hedef odanın `oda_uyeler` satırına sahip mi
 * @returns {{tamam:boolean, kod?:string}}
 */
export function rolAtamaKarari(oda, isteyenId, hedefId, rol, hedefUyeMi) {
  if (!rolVerebilir(oda, isteyenId)) return { tamam: false, kod: 'SAHIP_DEGIL' };
  // Sahip KENDİ rolünü değiştiremez: kendini 'izleyici'ye düşürürse oda
  // sahipsiz kalmaz (sahip_id durur) ama kimse yetki DAĞITAMAZ hâle gelir —
  // odayı kurtarma yolu kalmaz.
  if (hedefId === isteyenId) return { tamam: false, kod: 'KENDI_ROLUN' };
  if (!VERILEBILIR_ROLLER.includes(rol)) return { tamam: false, kod: 'ROL_GECERSIZ' };
  if (!hedefUyeMi) return { tamam: false, kod: 'UYE_DEGIL' };
  return { tamam: true };
}

/**
 * Odaya girme kararı — **odaya giden HER kapının tek doğrusu**.
 *
 * ===========================================================================
 * DAVET ZATEN YETKİDİR (4 Eyl 2026, canlıda iki kez ısırdı)
 * ===========================================================================
 * Davetli ama henüz "kabul"e dokunmamış kişi İÇERİ ALINIR. Kabul ayrı bir
 * güvenlik adımı DEĞİLDİR: oda sahibi o kişiyi zaten açıkça çağırdı ve davet
 * kapasiteden düşüldü (`POST /odalar/:id/davet` bekleyenleri de sayar). Ayrı
 * bir kabul adımı yalnız ODAYA GİDEN HER KAPIDA tekrar edilmesi gereken bir
 * tuzak üretir — nitekim üretti:
 *   1. tur: modalda davet satırı doğrudan `/oda/:id`e gidiyordu  -> 403.
 *           Düzeltme İSTEMCİYE yazıldı (satır önce `/odalar/katil` çağırıyor).
 *   2. tur: kullanıcı bu kez PUSH BİLDİRİMİNDEN girdi -> yine 403. Çünkü
 *           bildirim, uygulama içi bildirim listesi, derin bağlantı ve tarayıcı
 *           geçmişi AYRI kapılar ve her biri kendi düzeltmesini bekliyordu.
 * Kapıyı tek yerde açmak (burada) bu sınıfı bitirir.
 *
 * ***BU FONKSİYON `odaKapisi` TARAFINDAN ÇAĞRILMALIDIR.*** İlk yazımda kural
 * iki yere yazılmıştı: burada "davetli geçer", `odaKapisi`nde ise elle
 * `uye.katildi` şartı. İkisi ayrıştı ve kullanıcının gördüğü hata TAM OLARAK
 * bu ayrışmaydı. Aynı kuralın ikinci bir kopyasını yazma.
 *
 * @param {object|null} oda
 * @param {number} simdi epoch ms
 * @param {{uye:boolean, davetli:boolean, kodDogru:boolean, uyeSayisi:number, engelli:boolean}} d
 *   `uye` = KATILMIŞ üye · `davetli` = `oda_uyeler` satırı var (katılmış olsun
 *   olmasın) · `kodDogru` = doğru oda koduyla geldi.
 * @returns {{tamam:boolean, kod?:string, kabulGerek?:boolean}}
 *   `kabulGerek` true ise çağıran, içeri almadan ÖNCE daveti kabul yazmalıdır
 *   (`katildi=now()`); yani bu bir OKUMA kararı değil, yazma gerektiren bir
 *   geçiştir.
 */
export function girisKarari(oda, simdi, d) {
  if (!oda) return { tamam: false, kod: 'ODA_YOK' };
  if (oda.kapandi || simdi >= Number(oda.biter)) return { tamam: false, kod: 'ODA_KAPANDI' };
  // ZATEN ÜYE olan HER ŞEYDEN ÖNCE geçer: kapasite dolduğunda içerideki
  // birinin yoklaması "oda dolu" ile reddedilseydi, kişi kendi odasından
  // atılmış olurdu (kapasite kontrolü YENİ girişler içindir).
  if (d.uye) return { tamam: true };
  if (d.engelli) return { tamam: false, kod: 'ENGELLI' };
  if (!d.davetli && !d.kodDogru) return { tamam: false, kod: 'DAVET_YOK' };
  // DAVETLİ (satırı var) ise kapasite YENİDEN sorulmaz: davet verilirken
  // bekleyenler de sayılmıştı, yani bu kişinin yeri ZATEN ayrıldı. Burada
  // "oda dolu" demek, çağrılan kişiyi kapıda çevirmek olurdu.
  if (d.davetli) return { tamam: true, kabulGerek: !d.uye };
  if (d.uyeSayisi >= ODA_AZAMI_UYE) return { tamam: false, kod: 'ODA_DOLU' };
  return { tamam: true };
}

/** Üye çevrimiçi mi (son yoklaması eşiğin içinde mi). */
export function cevrimiciMi(sonGorulme, simdi) {
  return simdi - (Number(sonGorulme) || 0) <= CEVRIMICI_ESIK_MS;
}

// ---------------------------------------------------------------------------
// BAĞLANTI KAYNAĞI (7 Eyl 2026)
// ---------------------------------------------------------------------------
//
// Kullanıcı isteği: *"video upload yerine kullanıcıya tarayıcı açabilir miyiz
// … youtube gibi tüm platformların url'ini destekleyecek şekilde yapsak"*.
// Yükleme DURUYOR; bu ikinci bir kaynak.
//
// ===========================================================================
// BURASI İSTEMCİNİN İKİZİ DEĞİL, TEK OTORİTE
// ===========================================================================
// İstemci `app/lib/oda/oda_baglanti.dart` ile aynı çözümlemeyi yapıyor ve
// sonucu gönderiyor — ama VERİTABANINA YAZILAN, buranın kendi sonucudur.
// İstemcinin çözümlemesine güvenmek, `baglanti_saglayici='youtube'` diyip
// `kimlik` alanına rastgele bir adres koyan bir isteğin gömme yüzeyimize
// istediği sayfayı yükletmesi demekti (kendi sayfamızda üçüncü taraf iframe).
//
// ===========================================================================
// LİSTE NEDEN KISA — 7 Eyl 2026'da ÖLÇÜLDÜ
// ===========================================================================
// Senkron için oynatıcı KONTROL edilebilmeli. Ölçüm (yerel sayfaya iframe
// kurup komut yollayarak):
//   · YouTube  : IFrame API çalışıyor (zaten üründe)
//   · Vimeo    : getDuration -> 62, setCurrentTime onaylandı
//   · Dailymotion: yeni `geo` oynatıcı yalnız `pes_listen_eid` yayıyor,
//                  komutlara yanıt YOK (kontrol için hesaplı SDK gerekiyor)
//   · OK.ru    : `{"event":"inited"}` yayıyor, 8 komut biçimine SIFIR yanıt
//   · VK       : dış gömme `hash` istiyor, yapıştırılan adresten üretilemiyor
// Son üçü kabul edilseydi "gömülür ama sahip sardığında kimse sarmaz" olurdu:
// odanın tek varlık sebebi olan senkron SESSİZCE bozulurdu.

/** Doğrudan oynatılabilir uzantılar — `<video>` bunları açabiliyor. */
export const ODA_DOSYA_UZANTILARI = ['mp4', 'webm', 'm3u8', 'mov'];

/** Desteklenen sağlayıcılar; `izleme_odalari.baglanti_saglayici` CHECK'i ile birebir. */
export const ODA_SAGLAYICILAR = ['youtube', 'vimeo', 'dosya'];

const YOUTUBE_KIMLIK = /^[A-Za-z0-9_-]{11}$/;
const VIMEO_KIMLIK = /^\d{6,}$/;
const VIMEO_GIZLI = /^[0-9a-f]{6,}$/;

/**
 * Bir adresi çözer.
 *
 * @returns {{saglayici:string, kimlik:string, url:string, gizli:string|null}|null}
 *   null = desteklenmiyor (çağıran `BAGLANTI_DESTEKSIZ` döner).
 */
export function baglantiCoz(ham) {
  if (typeof ham !== 'string') return null;
  const metin = ham.trim();
  if (!metin || metin.length > 2000) return null;
  // Şemasız yapıştırma en sık kullanıcı davranışı ("youtu.be/..."). `http://`
  // AÇIKÇA yazıldıysa reddedilir: sayfamız https, karışık içerik tarayıcıda
  // SESSİZCE engellenir ve kullanıcı sebebini asla göremez.
  const tam = metin.includes('://') ? metin : `https://${metin}`;
  let u;
  try {
    u = new URL(tam);
  } catch {
    return null;
  }
  if (u.protocol !== 'https:' || !u.hostname) return null;

  const host = u.hostname.toLowerCase().replace(/^www\./, '');
  const yol = u.pathname.split('/').filter(Boolean);

  // --- YouTube -------------------------------------------------------------
  if (host === 'youtu.be' || host.endsWith('.youtu.be')) {
    const id = yol[0] || '';
    if (!YOUTUBE_KIMLIK.test(id)) return null;
    return { saglayici: 'youtube', kimlik: id, url: `https://youtu.be/${id}`, gizli: null };
  }
  if (
    host === 'youtube.com' || host === 'm.youtube.com' ||
    host === 'music.youtube.com' || host === 'youtube-nocookie.com' ||
    host.endsWith('.youtube.com') || host.endsWith('.youtube-nocookie.com')
  ) {
    const q = u.searchParams.get('v') || '';
    if (YOUTUBE_KIMLIK.test(q)) {
      return { saglayici: 'youtube', kimlik: q, url: `https://www.youtube.com/watch?v=${q}`, gizli: null };
    }
    if (yol.length >= 2 && ['embed', 'shorts', 'live', 'v'].includes(yol[0]) && YOUTUBE_KIMLIK.test(yol[1])) {
      return { saglayici: 'youtube', kimlik: yol[1], url: `https://www.youtube.com/watch?v=${yol[1]}`, gizli: null };
    }
    return null;
  }

  // --- Vimeo ---------------------------------------------------------------
  if (host === 'vimeo.com' || host === 'player.vimeo.com' || host.endsWith('.vimeo.com')) {
    const sayilar = yol.filter((s) => VIMEO_KIMLIK.test(s));
    if (!sayilar.length) return null;
    const id = sayilar[sayilar.length - 1];
    const sira = yol.indexOf(id);
    // Gizli (unlisted) videonun anahtarı: `h=` sorgusu ya da id'den SONRAKİ
    // onaltılık parça. Anahtarsız gömme 403 verir, yani düşürülemez.
    let gizli = u.searchParams.get('h');
    if (!gizli && sira >= 0 && yol[sira + 1] && VIMEO_GIZLI.test(yol[sira + 1])) {
      gizli = yol[sira + 1];
    }
    return {
      saglayici: 'vimeo',
      kimlik: id,
      url: gizli ? `https://vimeo.com/${id}/${gizli}` : `https://vimeo.com/${id}`,
      gizli: gizli || null,
    };
  }

  // --- Doğrudan dosya ------------------------------------------------------
  const nokta = u.pathname.lastIndexOf('.');
  const uzanti = nokta >= 0 ? u.pathname.slice(nokta + 1).toLowerCase() : '';
  if (ODA_DOSYA_UZANTILARI.includes(uzanti)) {
    // ÖZEL AĞ ADRESLERİ REDDEDİLİR. Sunucu bu adresi hiç istemiyor (dosyayı
    // istemci çekiyor), ama kabul etmek uygulamayı bir iç ağ tarayıcısına
    // çevirirdi: oda kuran kişi 10 kişiye `https://192.168.1.1/a.mp4`
    // yükletip yanıt sürelerinden ağ haritası çıkarabilirdi.
    if (ozelAgAdresi(u.hostname)) return null;
    return { saglayici: 'dosya', kimlik: u.href, url: u.href, gizli: null };
  }
  return null;
}

/**
 * Adres yerel/özel ağa mı bakıyor.
 *
 * Alan adı çözümlemesi YAPILMAZ (DNS yeniden bağlama bu kapıyı zaten aşar);
 * amaç bariz olanı kapatmak, tam SSRF savunması değil — sunucu bu adrese
 * hiçbir istek atmıyor.
 */
export function ozelAgAdresi(host) {
  const h = String(host || '').toLowerCase();
  if (h === 'localhost' || h.endsWith('.localhost') || h.endsWith('.local') || h.endsWith('.internal')) return true;
  if (h === '[::1]' || h === '::1') return true;
  const p = h.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (!p) return false;
  const [a, b] = [Number(p[1]), Number(p[2])];
  if (a === 10 || a === 127 || a === 0) return true;
  if (a === 192 && b === 168) return true;
  if (a === 172 && b >= 16 && b <= 31) return true;
  if (a === 169 && b === 254) return true;
  if (a === 100 && b >= 64 && b <= 127) return true;
  return false;
}
