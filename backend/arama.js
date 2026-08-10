// Sesli/görüntülü arama — SAF modül.
//
// `yasak.js`, `cevrimici.js`, `kripto.js` ve `medya_imza.js` ile aynı kalıp:
// burada ne Express, ne `pg`, ne `process.env` var. İçe aktarıldığında HİÇBİR
// yan etki olmaz. Böylece `backend/test/arama.test.js` gerçek fonksiyonları
// çağırıp DAVRANIŞI ölçer — kaynak metnine regex tutturmaz.
//
// Karar belgeleri: `ARAMA-PLANI.md`, `backend/ARAMA-API-SOZLESMESI.md`.
//
// ===========================================================================
// *** MUTLAK KURAL: İÇERİK KAYDI YOK ***
// ===========================================================================
// Ses, görüntü, transkript, SDP, ICE adayı, IP adresi ve cihaz bilgisi
// HİÇBİR tabloya, HİÇBİR dosyaya, HİÇBİR günlüğe yazılmaz. SDP ve ICE yalnız
// `AramaDeposu`nun bellek içi `Map`'inde yaşar ve arama uçlaştığı anda silinir.
// Bu bir politika DEĞİL mimari zorunluluktur: 1:1 WebRTC medyası DTLS-SRTP ile
// uçtan uca şifrelidir; TURN rölesine düşse bile sunucu şifreli paketi
// ÇÖZMEDEN iletir. Sunucu kaydetmek İSTESE BİLE çözemez.
//
// `ustveri()` bu modülün veritabanına giden TEK çıktısıdır ve döndürdüğü nesne
// "kim, kimi, ne zaman, ne kadar" dışında hiçbir alan taşımaz. Testi var.

import crypto from 'node:crypto';

// ---------------------------------------------------------------------------
// Sabitler
// ---------------------------------------------------------------------------

/** Çalma süresi. SUNUCUDA zorlanır (bellek içi kaydın TTL'i), yoksa iki taraf
 *  da uygulamayı kapatınca "sonsuza kadar çalıyor" hayalet kayıt kalır. */
export const CALMA_MS = 45_000;

/**
 * Kurulmuş bir aramanın bellekteki azami ömrü: 4 saat.
 *
 * NEDEN GEREKLİ: `POST /arama/bitir` bir İSTEMCİ eylemidir. İstemci çökerse,
 * pil biterse ya da ağ kalıcı koparsa o istek HİÇ gelmez. Üst sınır olmasaydı
 * kayıt `aktifArama` haritasında sonsuza kadar kalır ve o kullanıcı bir daha
 * ASLA arama yapamaz/alamazdı ("ZATEN_ARAMADA" ile kilitlenirdi). Süpürme bu
 * kayıtları `cevaplandi` olarak (süre = 4 saat) kapatır.
 */
export const AZAMI_ARAMA_MS = 4 * 3_600_000;

/** TURN kimlik bilgisi ömrü — sözleşme §3.3. Uzun bir aramanın ortasında
 *  sona ermemeli (ayırma yenilemesi mevcut kimlik bilgisini kullanır). */
export const TURN_TTL_SN = 43_200;

/** SDP tavanı. Trickle kullanmadığımız için tüm adaylar tek pakette gelir;
 *  yine de sınırsız bırakmak bellek şişirme yoludur. */
export const SDP_AZAMI_BAYT = 65_536;

/** ICE yeniden başlatmada taşınan aday sınırları (bellek koruması). */
export const ADAY_AZAMI_ADET = 20;
export const ADAY_AZAMI_BAYT = 512;

/** Çift bazlı sessizleştirme — sözleşme §9.1. Saatlik genel limit tacizi
 *  DURDURMAZ: tacizci zaten tek kişiyi arıyor. */
export const SESSIZ_PENCERE_MS = 15 * 60_000;
export const SESSIZ_ESIK = 3;
export const SESSIZ_CEZA_MS = 3_600_000;

/** `olcum.bayt_*` üst sınırı (istemci beyanı, güvenilmez — §4.7). */
export const ROLE_BAYT_TAVAN = 50 * 1024 ** 3;

/** Üstveri saklama süresi (gün) — `tablolariBuda()` bunu kullanır. */
export const SAKLAMA_GUN = 90;

export const TURLER = Object.freeze(['ses', 'goruntu']);

/** Uç (terminal) durumlar: yalnız bunlar `aramalar` tablosuna yazılır.
 *  `caliyor`/`baglaniyor` yalnız bellekte yaşar. */
export const UC_DURUMLAR = Object.freeze([
  'cevaplandi', 'cevapsiz', 'reddedildi', 'mesgul', 'basarisiz', 'iptal',
]);

export const SEBEPLER = Object.freeze([
  'kullanici', 'ag_koptu', 'ice_basarisiz', 'zaman_asimi',
]);

/**
 * Makine-okunur hata kodları — sözleşme §8.
 *
 * İstemci Türkçe `hata` metnine göre DEĞİL, bu koda göre dallanır ve kendi
 * 45 dilli metnini basar. Bu yüzden kodlar SABİTTİR ve ÇEVRİLMEZ.
 */
export const KOD = Object.freeze({
  ARAMA_KAPALI: 'ARAMA_KAPALI',
  GORUNTULU_KAPALI: 'GORUNTULU_KAPALI',
  GECERSIZ_ISTEK: 'GECERSIZ_ISTEK',

  // ---- MİSAFİR HESAPLAR (sürüm 4, kullanıcı kararı 10 Ağu) ----
  // "misafir hesaplar aranamasın ve bu ayarları açamasınlar, sebebini de
  // onlara söyle." İki YÖN, iki AYRI kod — çünkü kullanıcıya gösterilecek
  // metin de, yapması gereken de farklı:
  //   · MISAFIR_ARAMA_YOK → ARAYAN misafir. Çözüm ONDA: hesap oluştursun.
  //   · ALICI_MISAFIR     → ARANAN misafir. Çözüm onda DEĞİL; yapabileceği
  //                          tek şey karşı tarafa hesap açmasını söylemek.
  // Tek kod kullansaydık istemci hangi tarafın eksik olduğunu bilemez,
  // "hesap oluştur" derdi — arayan zaten kayıtlıyken.
  MISAFIR_ARAMA_YOK: 'MISAFIR_ARAMA_YOK',

  // *** BU KOD `KULLANICI_YOK`UN YERİNİ ALIR. ***
  // Önceki davranış: `hedefBul` sorgusu `AND misafir=false` içerdiği için
  // misafir hedef HİÇ BULUNAMIYOR ve 404 `KULLANICI_YOK` dönüyordu. Kullanıcı
  // ekranda "Kullanıcı bulunamadı" görüyordu — ama kullanıcı VARDI, karşısında
  // duruyordu, sohbet ediyordu. Yanlış sebep, "uygulama bozuk" algısı yaratır
  // (sözleşme §5.0 bunu zaten yazıyor). Artık hedef BULUNUR ve doğru sebep
  // döner.
  ALICI_MISAFIR: 'ALICI_MISAFIR',

  KULLANICI_YOK: 'KULLANICI_YOK',
  KENDINE_ARAMA: 'KENDINE_ARAMA',
  ENGELLI: 'ENGELLI',
  TAKIP_YOK: 'TAKIP_YOK',
  ALICI_YASAKLI: 'ALICI_YASAKLI',
  // Aranan kullanıcının KENDİ tercihi kapalı (`kullanicilar.sesli_arama_acik` /
  // `goruntulu_arama_acik`, ikisi de VARSAYILAN false). `ARAMA_KAPALI` /
  // `GORUNTULU_KAPALI` ile KARIŞTIRILMAMALI: onlar sunucu geneli kill
  // switch'tir, bunlar tek bir kullanıcının kararıdır. Ayrı kod olmasının
  // sebebi tam da bu — istemci "aradığınız kişide ... devre dışı" derken
  // "uygulama şu an kapalı" demek zorunda kalmasın (yanlış sebep, "uygulama
  // bozuk" algısı yaratır).
  ALICI_SESLI_KAPALI: 'ALICI_SESLI_KAPALI',
  ALICI_GORUNTULU_KAPALI: 'ALICI_GORUNTULU_KAPALI',
  COK_FAZLA_CEVAPSIZ: 'COK_FAZLA_CEVAPSIZ',
  ZATEN_ARAMADA: 'ZATEN_ARAMADA',
  DURUM_UYGUN_DEGIL: 'DURUM_UYGUN_DEGIL',
  TARAF_DEGIL: 'TARAF_DEGIL',
  ARAMA_YOK: 'ARAMA_YOK',
});

const hata = (http, kod, metin, ek = null) =>
  ({ tamam: false, http, kod, hata: metin, ...(ek || {}) });

// ---------------------------------------------------------------------------
// Kimlik
// ---------------------------------------------------------------------------

/**
 * Arama kimliği: RASTGELE 128 bit hex — artan tamsayı DEĞİL.
 *
 * Yetki kontrolü zaten var (`/arama/durum` tarafa bakar), ama tahmin edilebilir
 * bir kimlik üçüncü bir kullanıcının başkasının aramasını NUMARALANDIRMASINI
 * kolaylaştırırdı. Numaralandırmayı en baştan imkânsız kılmak bedava.
 */
export function aramaKimlik() {
  return crypto.randomBytes(16).toString('hex');
}

// ---------------------------------------------------------------------------
// TURN kimlik bilgisi (TURN REST API — coturn `use-auth-secret`)
// ---------------------------------------------------------------------------

/**
 * Kısa ömürlü TURN kimlik bilgisi üretir.
 *
 *   son_kullanma = floor(now/1000) + ttl
 *   username     = `${son_kullanma}:${kullanici_id}`
 *   credential   = base64( HMAC-SHA1( TURN_SIR, username ) )
 *
 * HMAC-SHA1 zayıf GÖRÜNÜR ama seçenek yok: coturn'ün `use-auth-secret` kipi
 * standart gereği SHA1 kullanır. Burada SHA1 bir ÇARPIŞMA direnci işi değil,
 * MAC işidir; HMAC-SHA1'in MAC olarak kırıldığına dair bir sonuç yoktur.
 * Sırrı 256 bit tutmak yeterli marjı verir.
 *
 * `username`in ikinci alanı kullanıcı kimliğidir: coturn onu yorumlamaz, ama
 * `user-quota` kişi başına uygulanabilsin ve kötüye kullanan hesap coturn
 * günlüğünden teşhis edilebilsin diye oradadır.
 *
 * @param {string} sir  TURN_SIR (.env) — KODA GÖMÜLMEZ
 * @returns {{username:string, credential:string, gecerlilik_sn:number}|null}
 *          sır yoksa null (çökme YOK; çağıran yalnız STUN döner)
 */
export function turnKimlik(sir, kullaniciId, ttlSn = TURN_TTL_SN, simdi = Date.now()) {
  if (!sir || typeof sir !== 'string') return null;
  const ttl = Number.isInteger(ttlSn) && ttlSn > 0 ? ttlSn : TURN_TTL_SN;
  const sonKullanma = Math.floor(simdi / 1000) + ttl;
  const username = `${sonKullanma}:${kullaniciId}`;
  const credential = crypto.createHmac('sha1', sir).update(username).digest('base64');
  return { username, credential, gecerlilik_sn: ttl };
}

/**
 * `GET /arama/buz-sunuculari` gövdesindeki liste — SIRA BAĞLAYICIDIR.
 * Kendi STUN'umuz birincil, Google YEDEK (gerekçe `turn/KURULUM.md` §5:
 * dışa bağımlılık sıfır, kullanıcı IP'si Google'a gitmez; Google yedekte kalır
 * ki tek bir kesinti tüm aramaları düşürmesin).
 *
 * TURN_SIR yoksa YALNIZ iki `stun:` girdisi döner ve `username`/`credential`
 * alanları HİÇ BULUNMAZ — sözleşme §3.1'deki "yokluk davranışı".
 */
export function buzSunuculari({ sir, kullaniciId, alan = 'turn.dizijpg.com',
  ttlSn = TURN_TTL_SN, simdi = Date.now() } = {}) {
  const kimlik = turnKimlik(sir, kullaniciId, ttlSn, simdi);
  const liste = [{ urls: `stun:${alan}:3478` }];
  if (kimlik) {
    const { username, credential } = kimlik;
    liste.push(
      { urls: `turn:${alan}:3478?transport=udp`, username, credential },
      { urls: `turn:${alan}:3478?transport=tcp`, username, credential },
      { urls: `turns:${alan}:5349?transport=tcp`, username, credential },
    );
  }
  liste.push({ urls: 'stun:stun.l.google.com:19302' });
  return { buz_sunuculari: liste, gecerlilik_sn: kimlik ? kimlik.gecerlilik_sn : 0 };
}

// ---------------------------------------------------------------------------
// Kill switch — İKİ KATMAN (sözleşme §6.2)
// ---------------------------------------------------------------------------

/**
 * Katman 1: `ayarlar` tablosu (admin panelinden anahtarlanır).
 * Katman 2: `ARAMA_GORUNTULU=kapali` ortam değişkeni — veritabanını EZER.
 *
 * İkinci katman neden var: fatura sürprizi gece 03:00'te fark edilirse admin
 * paneline girmek (2FA, IP kontrolü, tarayıcı) yerine `docker compose restart`
 * bir satırdır. Ayrıca VERİTABANI ERİŞİLEMEZSE panel zaten çalışmaz — o
 * senaryoda tek kaldıraç budur.
 *
 * `ARAMA_KAPALI=kapali` de aynı mantıkla tüm özelliği kapatır.
 *
 * *** ZORLAMA SUNUCUDADIR. *** İstemci `goruntulu_acik:false` gelince düğmeyi
 * gizler, ama yayındaki ESKİ bir APK bayrağı yok sayarsa yine 503 alır.
 * Kill switch'in anlamı, UYGULAMAYI GÜNCELLEMEDEN kapatabilmektir.
 */
export function ozellikBayraklari(ayarlar = {}, env = {}) {
  const acikMi = (d) => String(d) === '1' || String(d).toLowerCase() === 'acik';
  const kapaliEnv = (d) => String(d || '').trim().toLowerCase() === 'kapali';
  const aramaAcik = !kapaliEnv(env.ARAMA_KAPALI) && acikMi(ayarlar.arama_acik);
  const goruntuluAcik = aramaAcik
    && !kapaliEnv(env.ARAMA_GORUNTULU)
    && acikMi(ayarlar.arama_goruntulu_acik);
  return { aramaAcik, goruntuluAcik };
}

// ---------------------------------------------------------------------------
// Girdi doğrulama
// ---------------------------------------------------------------------------

/** SDP: `v=0` ile başlamalı ve ≤ 64 KB olmalı. */
export function sdpGecerliMi(s) {
  if (typeof s !== 'string') return false;
  if (!s.startsWith('v=0')) return false;
  return Buffer.byteLength(s, 'utf8') <= SDP_AZAMI_BAYT;
}

export function turGecerliMi(t) { return TURLER.includes(t); }

export function sebepGecerliMi(s) { return SEBEPLER.includes(s); }

/**
 * ICE aday dizisini temizler/doğrular. En çok 20 aday, her aday dizesi ≤512 B.
 * @returns {{tamam:boolean, adaylar:Array, hata:string|null}}
 */
export function adaylariTemizle(ham) {
  if (!Array.isArray(ham)) return { tamam: false, adaylar: [], hata: 'adaylar dizi olmalı' };
  if (ham.length === 0) return { tamam: false, adaylar: [], hata: 'adaylar boş' };
  if (ham.length > ADAY_AZAMI_ADET) {
    return { tamam: false, adaylar: [], hata: `en çok ${ADAY_AZAMI_ADET} aday` };
  }
  const cikti = [];
  for (const a of ham) {
    if (!a || typeof a !== 'object') return { tamam: false, adaylar: [], hata: 'aday nesne olmalı' };
    const c = a.candidate;
    if (typeof c !== 'string' || !c) return { tamam: false, adaylar: [], hata: 'candidate eksik' };
    if (Buffer.byteLength(c, 'utf8') > ADAY_AZAMI_BAYT) {
      return { tamam: false, adaylar: [], hata: `aday ${ADAY_AZAMI_BAYT} baytı aşamaz` };
    }
    const mid = a.sdpMid == null ? null : String(a.sdpMid).slice(0, 32);
    const idx = Number.isInteger(a.sdpMLineIndex) ? a.sdpMLineIndex : null;
    cikti.push({ candidate: c, sdpMid: mid, sdpMLineIndex: idx });
  }
  return { tamam: true, adaylar: cikti, hata: null };
}

/**
 * `olcum` istemci beyanıdır ve GÜVENİLMEZ (§4.7). Faturalandırmaya değil,
 * kendi kapasite planlamamıza girer. Buradaki iş temizlemek: saçma değerler
 * veritabanına girip aylık raporu bozmasın.
 * @returns {{roleDustu:boolean|null, roleBayt:number|null}}
 */
export function olcumTemizle(ham) {
  if (!ham || typeof ham !== 'object') return { roleDustu: null, roleBayt: null };
  const roleDustu = typeof ham.role_dustu === 'boolean' ? ham.role_dustu : null;
  const say = (v) => {
    const n = Number(v);
    if (!Number.isFinite(n) || n < 0 || n > ROLE_BAYT_TAVAN) return null;
    return Math.floor(n);
  };
  const g = say(ham.bayt_gonderilen);
  const a = say(ham.bayt_alinan);
  // Röle iki yönü de taşır; toplamı tek sütunda tutuyoruz (`role_bayt`).
  const roleBayt = g == null && a == null ? null : Math.min((g || 0) + (a || 0), ROLE_BAYT_TAVAN);
  return { roleDustu, roleBayt };
}

// ---------------------------------------------------------------------------
// Yetki — SIRA BAĞLAYICIDIR (sözleşme §5)
// ---------------------------------------------------------------------------

/**
 * `POST /arama/baslat` yetki zinciri.
 *
 * NEDEN CALLBACK ALIYOR: sıra sözleşmenin bir parçası (ucuz ve bilgi
 * sızdırmayan kontroller ÖNCE) ve bunu ancak gerçek çağrı sırasını gözleyen
 * bir test kanıtlayabilir. Sunucu bu fonksiyonu ÇAĞIRIR — yani testin ölçtüğü
 * sıra, üretimde çalışan sıradır. Sorguları burada yapsaydık modül `pg`ye
 * bağlanır ve saflığını kaybederdi.
 *
 * @param {object} girdi {aramaAcik, goruntuluAcik, benId, benMisafir,
 *   kullaniciAdi, tur, sdp}
 *   `benMisafir` ARAYANIN misafir olup olmadığıdır (sürüm 4). VARSAYILAN-RET
 *   DEĞİL, varsayılan-geçer (`=== true` diye bakılır): bilinmiyorsa arama
 *   engellenmez. Yönü bilinçli — burada yanlış "engelle" kararı GERÇEK
 *   kullanıcıları susturur, yanlış "geçir" kararı ise yalnız bir misafirin
 *   arama başlatmasına izin verir ve o arama zaten ALICI tarafında hiçbir
 *   veri kaybına yol açmaz. (Adım 12'deki tercih okumasının tersi: orada
 *   bilinmeyeni "açık" saymak HERKESİ aranabilir yapardı.)
 * @param {object} kaynak {hedefBul, engelliMi, karsilikliMi, sessizKalanSn, mesgulMu}
 *   `hedefBul(ad)` -> `{id, misafir, yasakli, kabulSesli, kabulGoruntulu}`.
 *   `kabul*` ARANANIN KENDİ tercihidir (`kullanicilar.sesli_arama_acik` /
 *   `goruntulu_arama_acik`); eksikse arama REDDEDİLİR (varsayılan-ret, aşağıda).
 *   `misafir` ise hedefin hesap TÜRÜdür — `hedefBul` artık misafirleri
 *   SÜZMEZ, çünkü süzmek onları "yok" gösteriyordu (bkz. `ALICI_MISAFIR`).
 * @returns {Promise<{tamam:true, hedef:object, mesgul:boolean}|{tamam:false,http,kod,hata}>}
 */
export async function baslatYetki(girdi, kaynak) {
  const {
    aramaAcik, goruntuluAcik, benId, benMisafir, kullaniciAdi, tur, sdp,
  } = girdi || {};

  // 2 — özellik kapalı
  if (!aramaAcik) return hata(503, KOD.ARAMA_KAPALI, 'Arama şu anda kapalı');
  // 3 — görüntülü kapalı (sesli çalışmaya devam eder)
  if (tur === 'goruntu' && !goruntuluAcik) {
    return hata(503, KOD.GORUNTULU_KAPALI, 'Görüntülü arama şu anda kapalı');
  }
  // 4 — ARAYAN MİSAFİR (sürüm 4). Kullanıcı kararı: "misafir hesaplar
  //     aranamasın ve bu ayarları açamasınlar, sebebini de onlara söyle."
  //
  // NEDEN TAM BURADA (sıra bağlayıcı):
  //  · Kill switch'lerden (2,3) SONRA: özellik sunucu genelinde kapalıysa
  //    hesap türünü tartışmanın anlamı yok; "şu anda kapalı" daha doğru.
  //  · Alan doğrulamasından (5) ÖNCE: bu kontrol ne gövdeyi ayrıştırmayı ne
  //    de veritabanını gerektirir — zincirin EN UCUZ adımı.
  //  · Hedefe bakan her şeyden (6+) ÖNCE: misafir bir arayan hiç kimse
  //    hakkında bilgi almamalı. Sonraya bıraksaydık misafir bir hesap
  //    `KULLANICI_YOK`/`TAKIP_YOK` farkından kullanıcı adı numaralandırabilirdi.
  //
  // BİLGİ SIZINTISI YOK: kullanıcı kendi hesabının misafir olduğunu zaten
  // biliyor (uygulamada "hesabını bağla" çağrısını görüyor).
  if (benMisafir === true) {
    return hata(403, KOD.MISAFIR_ARAMA_YOK,
      'Misafir hesaplar arama yapamaz; hesap oluşturunca kullanabilirsin');
  }
  // 5 — alan doğrulama (DB'ye hiç gitmeden)
  if (!turGecerliMi(tur) || !sdpGecerliMi(sdp)
      || typeof kullaniciAdi !== 'string' || !kullaniciAdi.trim()) {
    return hata(400, KOD.GECERSIZ_ISTEK, 'Geçersiz kullanici_adi/tur/sdp');
  }
  // 6 — kullanıcı var mı
  const hedef = await kaynak.hedefBul(kullaniciAdi);
  if (!hedef) return hata(404, KOD.KULLANICI_YOK, 'Kullanıcı bulunamadı');
  // 7 — kendini arama
  if (hedef.id === benId) return hata(400, KOD.KENDINE_ARAMA, 'Kendini arayamazsın');
  // 8 — ARANAN MİSAFİR (sürüm 4).
  //
  // ESKİDEN NE OLUYORDU: `hedefBul` sorgusu `AND misafir=false` içeriyordu,
  // hedef hiç bulunamıyor ve adım 6'da 404 `KULLANICI_YOK` dönüyordu. 10 Ağu'da
  // canlıda yaşanan olay bu: gerçek bir kullanıcı, sohbet ettiği misafiri
  // aradı ve "kullanıcı bulunamadı" gördü. Kural doğruydu, SEBEBİ yanlıştı.
  //
  // NEDEN ENGELLEME (9) VE KARŞILIKLI TAKİP (10) ÖNCESİNDE — adım 12'nin
  // (kendi tercihi) TERSİ yönde bir karar, ve bilinçli:
  //  · Misafirlik bir TERCİH DEĞİL, hesap TÜRÜdür. Adım 12 "bu kişi ayarından
  //    kapatmış" der ve o bir ifşadır; burada ifşa edilecek bir ayar yok.
  //  · `TAKIP_YOK` ÖNCE dönseydi kullanıcıya YAPILAMAZ bir iş önerirdik:
  //    "karşılıklı takipleşin" deyip takipleşse bile arama yine olmayacaktı.
  //    Kurtarma yolu göstermeyen mesaj kötüdür; YANLIŞ kurtarma yolu gösteren
  //    mesaj daha kötüdür.
  //  · Bir sorgu da tasarruf ediyor: `engelliMi` ve `karsilikliMi` hiç
  //    çalışmıyor.
  //
  // BİLGİ SIZINTISI DEĞERLENDİRMESİ (bilerek yazıldı, §5.0.2):
  // "Bu hesap misafir" demek yeni bir bilgi vermiyor. Misafir kullanıcı adı
  // SUNUCUNUN ürettiği `misafir_<8 hex>` kalıbıdır (`/auth/misafir`) ve adı
  // değiştirmenin TEK yolu `/auth/bagla`dır — o da aynı UPDATE içinde
  // `misafir=false` yapar. Yani `misafir=true` ⟺ ad `misafir_` ile başlar,
  // ve kullanıcı adları zaten herkese açık. Sızan sıfır bit var.
  if (hedef.misafir === true) {
    return hata(403, KOD.ALICI_MISAFIR, 'Misafir hesaplar aranamaz');
  }
  // 9 — engelleme (ÇİFT YÖNLÜ). Bugün engelleme yalnız GÖNDERMEDE zorlanıyor,
  //     okumada değil. Aramada bu gevşeklik kabul edilemez — telefon çalıyor.
  if (await kaynak.engelliMi(benId, hedef.id)) {
    return hata(403, KOD.ENGELLI, 'Bu kullanıcıyı arayamazsın');
  }
  // 10 — karşılıklı takip (kullanıcı kararı; tartışma kapalı).
  //     İstenmeyen mesaj bir rahatsızlık, istenmeyen arama bir ihlaldir.
  if (!await kaynak.karsilikliMi(benId, hedef.id)) {
    return hata(403, KOD.TAKIP_YOK, 'Aramak için karşılıklı takipleşmelisiniz');
  }
  // 11 — aranan yasaklı
  if (hedef.yasakli) return hata(403, KOD.ALICI_YASAKLI, 'Bu hesap şu anda aranamıyor');
  // 12 — ARANANIN KENDİ TERCİHİ (madde 38). Varsayılan KAPALI.
  //
  // NEDEN BURADA (sıra bağlayıcı, sözleşme §5):
  //  · Karşılıklı takip (10) ve engelleme (9) SONRASI: "bu kişide arama kapalı"
  //    demek başkasının ayarını ifşa etmektir. Yalnız karşılıklı takipleştiğin
  //    biri hakkında öğrenebilirsin. (İfşa BİLİNÇLİ: alternatif "bağlanılamadı"
  //    demekti, o da kullanıcıya uygulamayı bozuk gösterirdi.)
  //  · `ALICI_YASAKLI` (11) SONRASI: yasaklı bir hesapta tercihini de sızdırmak
  //    gereksiz — genel "şu anda aranamıyor" yeterli.
  //  · Sessizleştirme (13) ÖNCESİ: kapalı olması KALICI bir engel, sessizleştirme
  //    geçici bir soğuma. Kalıcı sebep önce söylenir.
  //
  // *** SESSİZLEŞTİRME MUAFİYETİ BURADAN GELİYOR ***: burada dönmek demek
  // bellekte kayıt OLUŞMAMASI, dolayısıyla hiçbir uç durumun (`cevapsiz`/
  // `reddedildi`) yazılmaması demektir. `cevapsizKaydet` yalnız uçlaşan bir
  // kayıtla çağrılır; kayıt hiç doğmadığı için sayaç ARTMAZ. Yoksa özelliği
  // kapatan kişi, kendisini arayan masum kullanıcıyı 1 saat susturmuş olurdu.
  // Testle kilitli ("KAPALI reddi sessizleştirme sayacına GİRMEZ").
  // VARSAYILAN-RET (`!== true`, `=== false` DEĞİL): tercih okunamadıysa,
  // sütun yoksa ya da `hedefBul` alanı yollamayı unuttuysa arama BAŞLAMAZ.
  // Kullanıcı kararı "otomatik olarak KAPALI" idi; bilinmeyeni "açık" saymak o
  // kararı sessizce tersine çevirirdi. Ters yönde hata gürültülüdür (kimse
  // aranamaz, hemen fark edilir), bu yönde hata SESSİZDİR (herkes aranabilir,
  // kimse fark etmez).
  if (tur === 'ses' && hedef.kabulSesli !== true) {
    return hata(403, KOD.ALICI_SESLI_KAPALI, 'Bu kullanıcıda sesli arama kapalı');
  }
  if (tur === 'goruntu' && hedef.kabulGoruntulu !== true) {
    return hata(403, KOD.ALICI_GORUNTULU_KAPALI, 'Bu kullanıcıda görüntülü arama kapalı');
  }
  // 13 — çift bazlı sessizleştirme
  const kalan = await kaynak.sessizKalanSn(benId, hedef.id);
  if (kalan > 0) {
    return hata(429, KOD.COK_FAZLA_CEVAPSIZ,
      'Bu kişiye çok fazla cevapsız arama yaptın', { kalan_sn: kalan });
  }
  // 14 — arayan zaten bir aramada (istemci hatası: kendi ekranında arama var)
  if (await kaynak.mesgulMu(benId)) {
    return hata(409, KOD.ZATEN_ARAMADA, 'Zaten bir aramadasın');
  }
  // 15 — aranan zaten bir aramada. HATA DEĞİL: aramanın normal bir sonucu.
  //      200 + durum:'mesgul' döner ve üstveriye `mesgul` olarak yazılır.
  const mesgul = await kaynak.mesgulMu(hedef.id);
  return { tamam: true, hedef, mesgul };
}

/**
 * `POST /arama/yanit` yetki zinciri.
 *
 * Karşılıklı takip ve engelleme kontrolleri BURADA TEKRARLANIR: A arama
 * başlattıktan sonra, B cevaplamadan önce takipten çıkabilir ya da engelleyebilir.
 * 45 saniyelik pencere küçük ama gerçek.
 */
export async function yanitYetki(girdi, kaynak) {
  const { aramaAcik, goruntuluAcik, benId, kayit, kabul, sdp } = girdi || {};

  if (!aramaAcik) return hata(503, KOD.ARAMA_KAPALI, 'Arama şu anda kapalı');
  if (!kayit) return hata(404, KOD.ARAMA_YOK, 'Arama bulunamadı');
  // Yalnız ARANAN cevaplayabilir. (Arayan da bu aramanın tarafı ama yanıt
  // veremez — bu yüzden 404 değil 403 TARAF_DEGIL.)
  if (kayit.arananId !== benId) return hata(403, KOD.TARAF_DEGIL, 'Bu aramanın tarafı değilsin');
  if (kayit.durum !== 'caliyor') {
    return hata(409, KOD.DURUM_UYGUN_DEGIL, 'Arama artık çalmıyor');
  }
  // Görüntülü kill switch, kabul anında da zorlanır: arama çalarken görüntülü
  // kapatılırsa devam ettirilmez.
  if (kayit.tur === 'goruntu' && !goruntuluAcik) {
    return hata(503, KOD.GORUNTULU_KAPALI, 'Görüntülü arama şu anda kapalı');
  }
  if (kabul === true && !sdpGecerliMi(sdp)) {
    return hata(400, KOD.GECERSIZ_ISTEK, 'Geçersiz sdp');
  }
  if (await kaynak.engelliMi(benId, kayit.arayanId)) {
    return hata(403, KOD.ENGELLI, 'Bu kullanıcıyla görüşemezsin');
  }
  if (!await kaynak.karsilikliMi(benId, kayit.arayanId)) {
    return hata(403, KOD.TAKIP_YOK, 'Karşılıklı takip yok');
  }
  return { tamam: true };
}

// ---------------------------------------------------------------------------
// Çift bazlı sessizleştirme (§9.1)
// ---------------------------------------------------------------------------

/**
 * "Aynı kişiye 15 dakika içinde 3 CEVAPSIZ arama yapıldıysa, o kişiye 1 saat
 * boyunca yeni arama başlatılamaz."
 *
 * Yalnız CEVAPSIZ sayılır (`cevapsiz`, `reddedildi`, `iptal`). Karşılıklı
 * konuşan iki arkadaşın arka arkaya araması cezalandırılmamalı — bir
 * `cevaplandi` sayacı SIFIRLAR.
 *
 * Kalıcılık gerekmiyor: sunucu yeniden başlarsa sayaç sıfırlanır. Bu bir CEZA
 * değil bir SOĞUMA PENCERESİ.
 */
export class SessizDepo {
  constructor({ pencereMs = SESSIZ_PENCERE_MS, esik = SESSIZ_ESIK,
    cezaMs = SESSIZ_CEZA_MS, tavan = 5000 } = {}) {
    this.pencereMs = pencereMs;
    this.esik = esik;
    this.cezaMs = cezaMs;
    this.tavan = tavan;
    this.kayitlar = new Map(); // "arayan:aranan" -> number[]
  }

  static anahtar(arayanId, arananId) { return `${arayanId}:${arananId}`; }

  cevapsizKaydet(arayanId, arananId, simdi = Date.now()) {
    const k = SessizDepo.anahtar(arayanId, arananId);
    const dizi = this.kayitlar.get(k) || [];
    dizi.push(simdi);
    // Ceza penceresinden de eski olanlar hiçbir karara giremez.
    const esik = simdi - (this.pencereMs + this.cezaMs);
    this.kayitlar.set(k, dizi.filter((t) => t >= esik).slice(-50));
    this.supur(simdi);
  }

  /** `cevaplandi` sayacı SIFIRLAR — iki arkadaşın konuşması ceza almasın. */
  sifirla(arayanId, arananId) {
    this.kayitlar.delete(SessizDepo.anahtar(arayanId, arananId));
    // Ters yön de sıfırlanır: konuşma karşılıklı bir rıza sinyalidir.
    this.kayitlar.delete(SessizDepo.anahtar(arananId, arayanId));
  }

  /** @returns {number} kalan ceza saniyesi (0 = serbest) */
  kalanSn(arayanId, arananId, simdi = Date.now()) {
    const dizi = this.kayitlar.get(SessizDepo.anahtar(arayanId, arananId));
    if (!dizi || dizi.length < this.esik) return 0;
    const s = [...dizi].sort((a, b) => a - b);
    let bitis = 0;
    for (let i = this.esik - 1; i < s.length; i++) {
      if (s[i] - s[i - this.esik + 1] <= this.pencereMs) {
        bitis = Math.max(bitis, s[i] + this.cezaMs);
      }
    }
    return bitis > simdi ? Math.ceil((bitis - simdi) / 1000) : 0;
  }

  /** `yaziyorlar` kalıbı: tavan aşılınca süresi dolanlar atılır. */
  supur(simdi = Date.now()) {
    if (this.kayitlar.size <= this.tavan) return;
    const esik = simdi - (this.pencereMs + this.cezaMs);
    for (const [k, dizi] of this.kayitlar) {
      const kalan = dizi.filter((t) => t >= esik);
      if (kalan.length) this.kayitlar.set(k, kalan); else this.kayitlar.delete(k);
    }
  }
}

// ---------------------------------------------------------------------------
// Bellek içi sinyalleşme deposu (§11)
// ---------------------------------------------------------------------------

/**
 * `yaziyorlar` (`server.js`) kalıbının aynısı: `Map`, TTL, tavanda süpürme.
 * KALICILIK YOK VE İSTENMİYOR — SDP/ICE diske yazılmaz.
 *
 * Sunucu yeniden başlarsa devam eden aramalar kaybolur. Kabul edilebilir:
 * medya P2P aktığı için KONUŞMA KESİLMEZ; yalnız `POST /arama/bitir`
 * `ARAMA_YOK` alır ve üstveri satırı yazılamaz. İstemci bunu HATA OLARAK
 * GÖSTERMEZ, sessizce arama ekranını kapatır.
 */
export class AramaDeposu {
  constructor({ calmaMs = CALMA_MS, azamiSureMs = AZAMI_ARAMA_MS,
    kimlikUret = aramaKimlik } = {}) {
    this.calmaMs = calmaMs;
    this.azamiSureMs = azamiSureMs;
    this.kimlikUret = kimlikUret;
    this.aramalar = new Map();   // arama_id -> kayıt
    this.aktif = new Map();      // kullanici_id -> arama_id  (aynı anda TEK arama)
  }

  /** Kullanıcı şu an bir aramada mı (arayan ya da aranan olarak)? */
  mesgulMu(kullaniciId) { return this.aktif.has(kullaniciId); }

  getir(aramaId) { return this.aramalar.get(aramaId) || null; }

  tarafMi(kayit, kullaniciId) {
    return !!kayit && (kayit.arayanId === kullaniciId || kayit.arananId === kullaniciId);
  }

  olustur({ arayanId, arananId, tur, teklifSdp }, simdi = Date.now()) {
    const kayit = {
      id: this.kimlikUret(),
      arayanId,
      arananId,
      tur,
      durum: 'caliyor',
      baslangic: simdi,
      kabulZamani: null,
      sonaErme: simdi + this.calmaMs,
      teklifSdp,
      cevapSdp: null,
      adaylar: { [arayanId]: [], [arananId]: [] },
    };
    this.aramalar.set(kayit.id, kayit);
    this.aktif.set(arayanId, kayit.id);
    this.aktif.set(arananId, kayit.id);
    return kayit;
  }

  /** Ön plandaki kullanıcıya gösterilecek ÇALAN arama (GET /arama/gelen). */
  gelenBul(kullaniciId) {
    for (const kayit of this.aramalar.values()) {
      if (kayit.durum === 'caliyor' && kayit.arananId === kullaniciId) return kayit;
    }
    return null;
  }

  /**
   * Karşı tarafın SDP cevabı — BİR KEZ teslim edilir, sonra bellekten silinir.
   * İstemci bunu idempotent ele almalı (zaten uyguladıysa yoksay).
   */
  cevapAl(kayit, okuyanId) {
    if (!kayit || kayit.arayanId !== okuyanId || !kayit.cevapSdp) return null;
    const sdp = kayit.cevapSdp;
    kayit.cevapSdp = null;
    return sdp;
  }

  /** Kabul: `baglaniyor`. TTL çalma süresinden AZAMİ ARAMA süresine geçer. */
  kabulEt(kayit, cevapSdp, simdi = Date.now()) {
    kayit.durum = 'baglaniyor';
    kayit.cevapSdp = cevapSdp;
    kayit.kabulZamani = simdi;
    kayit.sonaErme = simdi + this.azamiSureMs;
    return kayit;
  }

  adayEkle(kayit, gonderenId, adaylar) {
    const hedef = gonderenId === kayit.arayanId ? kayit.arananId : kayit.arayanId;
    const kuyruk = kayit.adaylar[hedef] || (kayit.adaylar[hedef] = []);
    for (const a of adaylar) kuyruk.push(a);
    // Bellek koruması: kuyruk sınırsız büyümesin (istemci hiç okumazsa).
    if (kuyruk.length > ADAY_AZAMI_ADET * 5) {
      kayit.adaylar[hedef] = kuyruk.slice(-ADAY_AZAMI_ADET * 5);
    }
  }

  /** Teslim edilir VE silinir. */
  adaylariAl(kayit, okuyanId) {
    const kuyruk = kayit.adaylar[okuyanId] || [];
    kayit.adaylar[okuyanId] = [];
    return kuyruk;
  }

  /**
   * Kaydı bellekten SİLER ve `aramalar` tablosuna yazılacak üstveriyi döndürür.
   * SDP ve ICE adayları burada kaybolur — diske hiç yazılmaz.
   */
  uclastir(kayit, durum, { sonlandiranId = null, saniye = null, olcum = null } = {},
    simdi = Date.now()) {
    this.aramalar.delete(kayit.id);
    if (this.aktif.get(kayit.arayanId) === kayit.id) this.aktif.delete(kayit.arayanId);
    if (this.aktif.get(kayit.arananId) === kayit.id) this.aktif.delete(kayit.arananId);
    return ustveri(kayit, durum, { sonlandiranId, saniye, olcum, bitis: simdi });
  }

  /**
   * `POST /arama/bitir` — uç durumu HESAPLAR.
   *
   * `caliyor` iken:  arayan kapatırsa `iptal`, aranan kapatırsa `reddedildi`.
   * `baglaniyor` iken: `sebep==='ice_basarisiz'` → `basarisiz`, aksi halde
   *   `cevaplandi` (süre kabul anından itibaren).
   *
   * *** SÖZLEŞMEYE EKLENEN NETLEŞTİRME ***: sözleşme §2'de `baglaniyor →
   * cevaplandi` geçişi "ICE bağlandı" olarak yazılmış ama bunu sunucuya
   * bildiren BİR UÇ YOK (bağlantı kurulunca yoklama TAMAMEN DURUYOR, §1).
   * Yani sunucu medyanın aktığını asla öğrenemez. Tek dürüst kaynak istemcinin
   * `bitir` çağrısındaki `sebep` alanıdır: ICE başarısızlığını istemci
   * `ice_basarisiz` ile bildirir; diğer her sebep, aranan KABUL ETTİĞİ için
   * kullanıcı açısından "cevaplanmış" bir aramadır.
   */
  bitir(kayit, kullaniciId, sebep, olcum, simdi = Date.now()) {
    let durum;
    let saniye = null;
    if (kayit.durum === 'caliyor') {
      durum = kullaniciId === kayit.arayanId ? 'iptal' : 'reddedildi';
    } else if (sebep === 'ice_basarisiz') {
      durum = 'basarisiz';
    } else {
      durum = 'cevaplandi';
      saniye = Math.max(0, Math.round((simdi - (kayit.kabulZamani ?? simdi)) / 1000));
    }
    return {
      durum,
      saniye,
      satir: this.uclastir(kayit, durum,
        { sonlandiranId: kullaniciId, saniye, olcum }, simdi),
    };
  }

  /**
   * Süresi geçen kayıtları uçlaştırır — 45 saniyelik ÇALMA SINIRININ SUNUCU
   * TARAFINDA ZORLANMA BİÇİMİ budur.
   * @returns {Array<{durum:string, satir:object, kayit:object}>}
   */
  supur(simdi = Date.now()) {
    const cikti = [];
    for (const kayit of [...this.aramalar.values()]) {
      if (kayit.sonaErme > simdi) continue;
      if (kayit.durum === 'caliyor') {
        cikti.push({
          durum: 'cevapsiz', kayit,
          satir: this.uclastir(kayit, 'cevapsiz', {}, simdi),
        });
      } else {
        // 4 saati aşan kurulmuş arama: istemci `bitir` göndermemiş (çöktü /
        // pil bitti / ağ koptu). Kaydı kapatmazsak kullanıcı sonsuza kadar
        // "ZATEN_ARAMADA" ile kilitlenirdi.
        const saniye = Math.round(this.azamiSureMs / 1000);
        cikti.push({
          durum: 'cevaplandi', kayit,
          satir: this.uclastir(kayit, 'cevaplandi', { saniye }, simdi),
        });
      }
    }
    return cikti;
  }
}

/**
 * `aramalar` tablosuna gidecek TEK nesne.
 *
 * *** BU FONKSİYON İÇERİK SIZDIRMAMA NOKTASIDIR. *** Döndürülen nesnede
 * `teklifSdp`, `cevapSdp`, `adaylar`, IP ya da cihaz bilgisi YOKTUR ve
 * eklenmeyecektir; `test/arama.test.js` anahtar listesini kilitliyor.
 */
export function ustveri(kayit, durum, { sonlandiranId = null, saniye = null,
  olcum = null, bitis = null } = {}) {
  if (!UC_DURUMLAR.includes(durum)) throw new Error(`Uç olmayan durum: ${durum}`);
  const o = olcum || { roleDustu: null, roleBayt: null };
  return {
    arayan_id: kayit.arayanId,
    aranan_id: kayit.arananId,
    tur: kayit.tur,
    durum,
    baslangic: new Date(kayit.baslangic),
    bitis: bitis == null ? null : new Date(bitis),
    // Şema kısıtı: süre YALNIZ `cevaplandi`da dolu olabilir.
    saniye: durum === 'cevaplandi' ? saniye : null,
    role_dustu: o.roleDustu ?? null,
    role_bayt: o.roleBayt ?? null,
    sonlandiran_id: sonlandiranId,
  };
}

/** `GET /arama/gecmis`: istemci `arayan_id` GÖRMEZ, sunucu yönü hesaplar. */
export function gecmisYon(satir, benId) {
  return satir.arayan_id === benId ? 'giden' : 'gelen';
}

/** Kaçırılan arama bildirimi hangi uç durumlarda düşer. */
export const KACIRILAN_DURUMLAR = Object.freeze(['cevapsiz', 'iptal', 'mesgul']);

/** Çift bazlı sessizleştirme sayacına hangi uç durumlar yazılır. */
export const CEVAPSIZ_DURUMLAR = Object.freeze(['cevapsiz', 'reddedildi', 'iptal']);
