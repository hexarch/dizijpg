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

/**
 * Oynatma durumunu kim yazabilir.
 *
 * Kullanıcı isteği açık: *"oda sahibi 10 saniye ileri sararsa izleyenlerde de
 * ileri sarılmalı"* — yani kontrol TEK ELDE. İzleyici de yazabilseydi iki kişi
 * aynı anda sardığında oda salınıma girerdi (her biri ötekinin konumuna
 * düzeltme yapar).
 */
export function durumYazabilir(oda, kullaniciId) {
  return !!oda && oda.sahip_id === kullaniciId;
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
