// Ban / ceza sistemi + güven skoru — SAF modül.
//
// `cevrimici.js` ve `kripto.js` ile aynı kalıp: burada ne Express, ne `pg`,
// ne `process.env` var. İçe aktarıldığında HİÇBİR yan etki olmaz. Böylece
// `backend/test/yasak.test.js` gerçek fonksiyonları çağırıp DAVRANIŞI ölçer —
// kaynak metnine regex tutturmaz.
//
// ===========================================================================
// DÜRÜSTLÜK BÖLÜMÜ — abartma, aynı cümleleri panelde ve raporda da kur
// ===========================================================================
//
// 1) CİHAZ BANI "BİR DAHA ASLA AÇAMAZ" DEMEK DEĞİLDİR.
//    Android kalıcı bir donanım kimliği vermiyor ve Play politikası kalıcı
//    donanım tanımlayıcılarını (IMEI, MAC, Android ID'nin kalıcı kimlik olarak
//    kullanımı) YASAKLIYOR. Bizim kullandığımız `cihaz kimliği` UYGULAMANIN
//    KENDİ ÜRETTİĞİ rastgele bir KURULUM kimliğidir: uygulama silinip yeniden
//    kurulursa, veriler temizlenirse, başka bir cihaz/emülatör kullanılırsa ya
//    da istemci başlığı hiç göndermezse (web, eski sürümler) DEĞİŞİR/YOKTUR.
//    Yani bu bir KİLİT değil, CAYDIRICI bir sürtünme katmanıdır: kararlı bir
//    saldırganı yavaşlatır, sıradan tekrar-kayıtçıyı durdurur.
//    Kullanıcıya görünen hiçbir metinde "bir daha asla" sözü VERİLMEZ.
//
// 2) GÜVEN SKORU KENDİ BAŞINA CEZA VERMEZ.
//    Varsayılan `otoBanAyari()` KAPALIDIR. Skor yalnız SİNYAL üretir; aksiyonu
//    insan yönetici alır. Gerekçe: otomatik ceza yanlış pozitifte masum
//    kullanıcıyı banlar, kullanıcı sebebini anlamaz, geri dönüşü pahalıdır ve
//    örgütlü şikayet (brigading) doğrudan silaha dönüşür. Skor DÜŞÜŞÜ de
//    ham şikayet sayısına değil, YÖNETİCİNİN DOĞRULADIĞI olaya bağlıdır.

/** Süre birimi → milisaniye. Kullanıcının istediği dört birim. */
export const SURE_BIRIMLERI = Object.freeze({
  dakika: 60_000,
  saat: 3_600_000,
  gun: 86_400_000,
  // 365 gün. Takvim yılı (artık yıl) değil: ceza süresinin hesabı, uygulandığı
  // tarihe göre bir gün oynasın istemiyoruz — sabit uzunluk hem test edilebilir
  // hem de kullanıcıya söylediğimiz "365 gün" ile birebir aynı.
  yil: 365 * 86_400_000,
});

/**
 * Tek seferde verilebilecek en uzun süreli ban: 10 YIL (üstü = kalıcı sayılır).
 * Yıl cinsinden yazılıdır; `bitisHesapla` bunu `SURE_BIRIMLERI.yil` ile çarpar.
 */
export const AZAMI_MIKTAR = 10;

/**
 * Süreli banın bitiş anını hesaplar.
 *
 * @param {string} birim 'dakika' | 'saat' | 'gun' | 'yil'
 * @param {number} miktar 1 ve üzeri tam sayı. Üst sınır YOK — hesap sonucu
 *        AZAMI_MIKTAR yıla kırpılır (aşağıdaki `enFazla`), yani 'yil' 999 da
 *        geçerli bir giriştir ve 10 yıl döner.
 * @param {number} simdi epoch ms
 * @returns {number} bitiş epoch ms
 * @throws geçersiz birim/miktarda — sessizce "kalıcı"ya düşmek TEHLİKELİ
 *         olurdu (yönetici 5 dakika yazar, kullanıcı sonsuza banlanır).
 */
export function bitisHesapla(birim, miktar, simdi = Date.now()) {
  const carpan = SURE_BIRIMLERI[birim];
  if (!carpan) {
    throw new Error(`Geçersiz süre birimi: ${birim} (dakika|saat|gun|yil)`);
  }
  const n = Number(miktar);
  if (!Number.isInteger(n) || n < 1) {
    throw new Error(`Geçersiz süre miktarı: ${miktar} (1 ve üzeri tam sayı)`);
  }
  // Üst sınır. Daha uzunu isteniyorsa "kalıcı" seçilmelidir; 500 yıllık ban
  // veri tabanında timestamp taşmasına ve saçma arayüz metnine yol açar.
  // Sayı burada ELLE YAZILMAZ: AZAMI_MIKTAR dışarıya bu sınırın adı olarak
  // veriliyor, ikinci bir "10" bırakmak ikisinin ayrışmasına davetiyedir.
  const enFazla = AZAMI_MIKTAR * SURE_BIRIMLERI.yil;
  const sure = Math.min(n * carpan, enFazla);
  return simdi + sure;
}

/** `bitis` alanını epoch ms'e çevirir (Date | ISO metin | ms | null). */
export function bitisMs(bitis) {
  if (bitis == null) return null;
  if (bitis instanceof Date) return bitis.getTime();
  if (typeof bitis === 'number') return bitis;
  const t = Date.parse(String(bitis));
  return Number.isNaN(t) ? null : t;
}

/**
 * Kullanıcı ŞU AN yasaklı mı?
 *
 * KURAL: `yasakli` bayrağı TEK BAŞINA yetmez — süresi dolmuş bir ban için
 * bayrak veritabanında bir süre daha `true` kalabilir (süpürme gecikmesi).
 * Bu yüzden karar HER OKUMADA burada verilir; cron'a ihtiyaç yoktur.
 *
 *   yasakli=false                 -> yasak YOK
 *   yasakli=true,  bitis=null     -> KALICI ban
 *   yasakli=true,  bitis>simdi    -> SÜRELİ ban, sürüyor
 *   yasakli=true,  bitis<=simdi   -> süresi DOLDU, yasak YOK (kendiliğinden serbest)
 *
 * @param {{yasakli?:boolean, yasak_bitis?:any}} satir kullanicilar satırı
 */
export function yasakAktif(satir, simdi = Date.now()) {
  if (!satir || !satir.yasakli) return false;
  const b = bitisMs(satir.yasak_bitis);
  if (b == null) return true;          // kalıcı
  return b > simdi;                    // süreli: bitiş geleceğe mi bakıyor
}

/** Süresi dolmuş ama bayrağı hâlâ açık mı? (süpürme bunu temizler) */
export function yasakSuresiDoldu(satir, simdi = Date.now()) {
  if (!satir || !satir.yasakli) return false;
  const b = bitisMs(satir.yasak_bitis);
  return b != null && b <= simdi;
}

/**
 * İSTEMCİYE GÖNDERİLECEK yasak yükü. Kullanıcı sebebi ve kalan süreyi
 * GÖRMELİDİR — sessizce çalışmayan bir uygulama en kötü deneyimdir.
 * @returns {{kalici:boolean, bitis:string|null, kalan_sn:number|null,
 *            sebep:string}|null} yasak yoksa null
 */
export function yasakYuku(satir, simdi = Date.now()) {
  if (!yasakAktif(satir, simdi)) return null;
  const b = bitisMs(satir.yasak_bitis);
  return {
    kalici: b == null,
    bitis: b == null ? null : new Date(b).toISOString(),
    kalan_sn: b == null ? null : Math.max(0, Math.ceil((b - simdi) / 1000)),
    sebep: String(satir.yasak_sebep || '').slice(0, 500),
  };
}

// ---------------------------------------------------------------------------
// Yazma kapısı — TEK KONTROL NOKTASI
// ---------------------------------------------------------------------------
//
// KARAR: Yasaklı kullanıcı GİREBİLİR ve OKUYABİLİR, ama HERKESE AÇIK hiçbir
// şey YAZAMAZ.
//
// GEREKÇE:
//  * Girebilmeli ki cezayı, sebebini ve kalan süreyi UYGULAMA İÇİNDE görsün.
//    "Giriş yapamıyorum" ekranı kullanıcıya hiçbir şey öğretmez ve destek
//    kutusunu doldurur.
//  * Okuyabilmeli ki cezası bir "veri hapsi"ne dönüşmesin; izleme geçmişi
//    onun kişisel verisi.
//  * Yazamamalı: banın AMACI başkalarını korumaktır. Yorum, mesaj, beğeni,
//    takip, profil metni, medya yükleme — hepsi başkasına ULAŞAN eylemlerdir.
//
// MUAF listesi (yasaklıyken de yapılabilen YAZMA işlemleri) BİLEREK KISADIR ve
// yaklaşım VARSAYILAN-RET'tir: listede olmayan her yazma ucu yasaklıya kapalı.
// Böylece yarın eklenen yeni bir uç "unutulduğu için açık kalmaz".
export const YASAK_MUAF = Object.freeze([
  // Oturum: girip cezasını görebilmeli. (Cihaz banı ayrı kapıda kontrol edilir.)
  '/auth/',
  // Push token tazeleme — bildirim ayarları bozulmasın.
  '/cihaz-token',
  // İstemci çökme günlüğü: yasaklı kullanıcının çökmesini de görmek isteriz.
  '/hata-bildir',
  // KİŞİSEL takip verisi (kimseye ulaşmaz): izleme/durum/puan/favori/tekrar izleme
  '/izleme/toggle', '/izleme/sezon', '/icerik/sifirla', '/durum', '/puan',
  '/favori/toggle', '/rewatch',
  // Kendi tercihleri
  '/bildirim-tercihleri', '/gizlilik-tercihleri', '/gizle',
  // Bildirim okundu işareti + mesaj "iletildi" tiki: yeni içerik ÜRETMEZ
  '/bildirimler/okundu', '/mesajlar/iletildi',
  // Açık sohbet damgasını kapatmak da içerik ÜRETMEZ; yasaklı sohbeti
  // okuyup çıkınca push'un yeniden açılabilmesi için muaf.
  '/sohbet/bakiyor',
  // ***** ARAMAYI KAPATMA — BU SATIRI ASLA SİLME *****
  // Aramanın ORTASINDA ban yiyen kullanıcı `/arama/bitir`den 403 alırsa
  // aramayı TEMİZ KAPATAMAZ: karşı taraf hayalet bir aramada kalır, süre
  // sayacı akmaya devam eder, üstveri satırı `bitis`siz kalır ve iki kullanıcı
  // birden "zaten aramadasın" kilidine düşer. Yukarıdaki iki satırla AYNI
  // gerekçe: bu uç yeni içerik ÜRETMEZ, TÜKETİMİ BİTİRİR.
  // `/arama/baslat` ve `/arama/yanit` ise BİLEREK muaf DEĞİL — ban süresince
  // iletişim kapalıdır. `backend/test/arama.test.js` ikisini de kilitliyor.
  '/arama/bitir',
  // Kendini koruma ve moderasyona yardım: engelleme + şikayet açık kalır
  '/engelle/', '/sikayet',
  // ***** İTİRAZ — BU SATIRI ASLA SİLME *****
  // Yazma kapısı VARSAYILAN-RET olduğu için `/itiraz` bu listede DEĞİLSE
  // yasaklı kullanıcı itiraz EDEMEZ. O zaman sistem kendi kendini kilitler:
  // ceza veririz, kullanıcı ona itiraz edemez, "ban kararları geri
  // alınabilir olmalı" ilkesi kâğıt üstünde kalır. Cezaya itiraz, cezanın
  // KENDİSİNDEN muaf olmak zorundadır.
  // `backend/test/yasak.test.js` bunu ayrı bir testle kilitliyor.
  '/itiraz',
  // Veri taşınabilirliği ve hesabını silme hakkı (KVKK/GDPR) ASLA kapatılmaz
  '/veri/disa-aktar', '/hesabim',
  // TMDB toplu okuma (POST yalnız gövde için kullanılıyor; yazma değil)
  '/icerikler',
]);

/**
 * Bu istek, yasaklı kullanıcı için ENGELLENMELİ mi?
 * @param {string} metot HTTP metodu
 * @param {string} yol req.path (ör. '/yorumlar', '/engelle/ali')
 */
export function yazmaYasakli(metot, yol) {
  const m = String(metot || '').toUpperCase();
  if (m === 'GET' || m === 'HEAD' || m === 'OPTIONS') return false;
  const y = String(yol || '');
  for (const muaf of YASAK_MUAF) {
    // '/' ile biten girdi ÖN EK ('/engelle/ali'), diğerleri TAM eşleşme.
    if (muaf.endsWith('/') ? y.startsWith(muaf) : y === muaf) return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// Cihaz kimliği
// ---------------------------------------------------------------------------

/**
 * İstemcinin ürettiği KURULUM kimliği: 32 haneli küçük harf onaltılık
 * (16 rastgele bayt). Donanımdan OKUNMAZ (bkz. üstteki dürüstlük notu 1).
 *
 * Neden dar bir kalıp: kimlik hem birincil anahtar hem de panelde gösterilen
 * bir metin. Serbest metin kabul etseydik hem 4 KB'lık anahtarlar hem de
 * gösterim katmanında kaçış hataları riski gelirdi.
 */
export function cihazKimlikGecerli(k) {
  return typeof k === 'string' && /^[0-9a-f]{32}$/.test(k);
}

// ---------------------------------------------------------------------------
// Güven skoru
// ---------------------------------------------------------------------------

export const GUVEN_TABAN = 100;   // yeni hesabın skoru
export const GUVEN_ALT = 0;
export const GUVEN_UST = 100;

/**
 * Skoru düşüren olaylar ve ağırlıkları.
 *
 * HEPSİ YÖNETİCİ DOĞRULAMASINA BAĞLIDIR. Ham şikayet sayısı skora GİRMEZ:
 * girseydi 5 kişilik bir grup, masum bir kullanıcıyı birkaç dakikada dibe
 * çekerdi. "Şikayet geldi" bir iddiadır; "yönetici incelendi dedi" bir bulgudur.
 */
export const GUVEN_OLAYLARI = Object.freeze({
  sikayet_dogrulandi: -5,   // yönetici şikayeti HAKLI bulup 'incelendi' yaptı
  yorum_silindi: -10,       // yönetici gönderiyi kaldırdı
  ban_sureli: -20,          // süreli ban verildi
  ban_kalici: -100,         // kalıcı ban: skor dibe
  itiraz_kabul: +15,        // yanlış ceza geri alındı — skor İADE edilir
  manuel: 0,                // yönetici elle değer girer
});

/** Skoru [0,100] aralığına sıkıştırır. */
export function guvenSinirla(skor) {
  const n = Number(skor);
  if (!Number.isFinite(n)) return GUVEN_TABAN;
  return Math.max(GUVEN_ALT, Math.min(GUVEN_UST, Math.round(n)));
}

/**
 * Olayı uygular ve YENİ skoru döndürür (saf hesap; DB'ye yazmaz).
 * @param {number} mevcut
 * @param {string} olay GUVEN_OLAYLARI anahtarı
 * @param {number} elle 'manuel' olayında kullanılan değişim (+/-)
 */
export function guvenUygula(mevcut, olay, elle = 0) {
  if (!(olay in GUVEN_OLAYLARI)) throw new Error(`Bilinmeyen güven olayı: ${olay}`);
  const degisim = olay === 'manuel' ? Math.trunc(Number(elle) || 0) : GUVEN_OLAYLARI[olay];
  return guvenSinirla(guvenSinirla(mevcut) + degisim);
}

// ---------------------------------------------------------------------------
// Güven skoru TOPARLANMASI (zaman içinde kendini onarma)
// ---------------------------------------------------------------------------
//
// KURAL: son İHLALDEN bu yana her GUVEN_TOPARLANMA_GUN günde +1, tavan 100.
//
// ÜÇ KARAR, gerekçeleriyle:
//
// 1) NEDEN "son ihlal", "son olay" değil?
//    Saat, skoru DÜŞÜREN son olaydan sayılır. "Son olay"tan sayılsaydı,
//    yöneticinin iyi niyetle verdiği elle +5 ya da bir itiraz iadesi saati
//    SIFIRLAR ve kullanıcının toparlanmasını GECİKTİRİRDİ — yani ödül ceza
//    gibi davranırdı. Kural tek cümleyle anlatılabilmeli: "son ihlalinden bu
//    yana kaç 30 gün geçtiyse o kadar puan geri gelir."
//
// 2) NEDEN CRON YOK?
//    `yasakAktif()` ile aynı kalıp: değer OKUMA ANINDA hesaplanır. Skor
//    kolonu "son yazma anındaki taban"dır; toparlanma üstüne eklenir. Böylece
//    hiçbir zamanlayıcı, hiçbir gece işi, hiçbir "çalışmayı unuttu" durumu yok.
//    Yazma anında (`guvenIsle`) toparlanma tabana GÖMÜLÜR ve saat tüketilen
//    TAM dönem kadar ileri alınır — kısmi ilerleme kaybolmaz, iki kez sayılmaz.
//
// 3) NEDEN KALICI/AKTİF BANLIDA TOPARLANMA YOK?
//    Ban süresince kullanıcı zaten yazamıyor; "iyi davranış" diye
//    ödüllendirebileceğimiz bir davranış üretmiyor. Ceza sürerken skorun
//    kendiliğinden yükselmesi, kalıcı banlı bir hesabın aylar sonra "temiz"
//    görünmesi demek olurdu. Ban KALKINCA saat işlemeye başlar (kaldırma anı
//    zaten yeni bir güven olayı yazar ve saati oradan devam ettirir).
export const GUVEN_TOPARLANMA_GUN = 30;
const GUN_MS = 86_400_000;

/** İhlal tarihini epoch ms'e çevirir (Date | ISO | ms | null). */
export function ihlalMs(t) { return bitisMs(t); }

/**
 * Son ihlalden bu yana kazanılan TAM toparlanma puanı (0, 1, 2, …).
 * @param {any} sonIhlal `kullanicilar.guven_ihlal`
 */
export function guvenToparlanma(sonIhlal, simdi = Date.now()) {
  const t = ihlalMs(sonIhlal);
  if (t == null) return 0;                 // hiç ihlal yok → toparlanacak şey yok
  const gecen = simdi - t;
  if (!(gecen > 0)) return 0;              // gelecek tarih / bozuk veri
  return Math.floor(gecen / (GUVEN_TOPARLANMA_GUN * GUN_MS));
}

/**
 * Kullanıcının GÜNCEL (toparlanma dahil) güven skoru.
 *
 * @param {{guven_skoru?:number, guven_ihlal?:any, yasakli?:boolean,
 *          yasak_bitis?:any}} satir
 * @returns {{taban:number, toparlanma:number, skor:number, donuk:boolean}}
 *          `donuk` = ban sürdüğü için toparlanma işlemiyor.
 */
export function guvenGuncel(satir, simdi = Date.now()) {
  const taban = guvenSinirla(satir?.guven_skoru ?? GUVEN_TABAN);
  // Ban sürerken saat DURUR (bkz. karar 3).
  if (yasakAktif(satir, simdi)) {
    return { taban, toparlanma: 0, skor: taban, donuk: true };
  }
  const ham = guvenToparlanma(satir?.guven_ihlal, simdi);
  const skor = guvenSinirla(taban + ham);
  // Tavana çarpanı olduğu gibi bildirmeyelim: "gerçekten uygulanan" kadarı.
  return { taban, toparlanma: skor - taban, skor, donuk: false };
}

/**
 * Yazma anında saati ne kadar ileri almalıyız?
 *
 * Toparlanma tabana gömülürken saat TÜKETİLEN TAM DÖNEM kadar ilerletilir
 * (`sonIhlal + n*30 gün`). `now()` yapsaydık kullanıcının biriktirdiği kısmi
 * günler (ör. 29 gün) her yazmada çöpe giderdi.
 * @returns {number|null} yeni `guven_ihlal` epoch ms; değişmeyecekse null
 */
export function ihlalSaatiIlerlet(sonIhlal, toparlanma) {
  const t = ihlalMs(sonIhlal);
  if (t == null || !(toparlanma > 0)) return null;
  return t + toparlanma * GUVEN_TOPARLANMA_GUN * GUN_MS;
}

/** Panelde gösterilen risk etiketi (yalnız SİNYAL; hiçbir yaptırımı yok). */
export function guvenEtiketi(skor) {
  const s = guvenSinirla(skor);
  if (s >= 80) return 'iyi';
  if (s >= 50) return 'izlemede';
  if (s >= 25) return 'riskli';
  return 'kritik';
}

/**
 * Otomatik ban ayarını ortamdan okur — VARSAYILAN KAPALI.
 *
 *   GUVEN_OTO_BAN=acik      bayrağı açar (KAPALI olan varsayılan budur)
 *   GUVEN_OTO_ESIK=15       bu skorun ALTINA düşünce (< eşik)
 *   GUVEN_OTO_GUN=7         kaç günlük SÜRELİ ban verilir (kalıcı ASLA otomatik)
 */
export function otoBanAyari(env = {}) {
  const acik = String(env.GUVEN_OTO_BAN || '').trim().toLowerCase() === 'acik';
  const esik = Number.parseInt(env.GUVEN_OTO_ESIK ?? '15', 10);
  const gun = Number.parseInt(env.GUVEN_OTO_GUN ?? '7', 10);
  return {
    acik,
    esik: Number.isInteger(esik) ? Math.max(0, Math.min(99, esik)) : 15,
    gun: Number.isInteger(gun) && gun > 0 ? Math.min(365, gun) : 7,
  };
}

/**
 * Skor düştükten SONRA çağrılır. Bir ÖNERİ döndürür — ban VERMEZ.
 *
 * `uygula` ancak bayrak AÇIKSA true olur. Bayrak kapalıyken dönen nesne
 * yalnız panelde "bu hesap eşiğin altında" rozetini yakmak içindir; sunucu
 * hiçbir şey yapmaz. Otomatik cezayı isteyen kişi .env'e bilerek yazar.
 *
 * KALICI ban ASLA otomatik verilmez: geri dönüşü en pahalı karar, insana ait.
 */
export function otoBanOnerisi(skor, ayar) {
  const s = guvenSinirla(skor);
  const a = ayar || otoBanAyari({});
  const esikAltinda = s < a.esik;
  return {
    esikAltinda,
    uygula: !!(a.acik && esikAltinda),
    gun: a.gun,
    sebep: `Güven skoru ${s} (eşik ${a.esik}) — otomatik ${a.gun} günlük kısıtlama`,
  };
}

// ---------------------------------------------------------------------------
// Metin yardımcıları
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// İtiraz metni
// ---------------------------------------------------------------------------

/** İtiraz metni sınırları — `itirazlar.metin` CHECK'i ile BİREBİR aynı. */
export const ITIRAZ_EN_AZ = 10;
export const ITIRAZ_EN_COK = 2000;

/**
 * İtiraz metnini temizler ve doğrular.
 *
 * Alt sınır 10: "aç" / "neden" gibi tek kelimelik itirazlar yöneticiye karar
 * verecek hiçbir bilgi vermez, kuyruğu doldurur ve gerçek itirazları gömer.
 * Üst sınır 2000: `mesajlar` ile aynı büyüklük sınıfı; panelde okunabilir kalsın.
 * @returns {{tamam:boolean, metin:string, hata:string|null}}
 */
export function itirazMetni(ham) {
  // Satır sonları KORUNUR (paragraf yapısı okunabilirliği artırır), yalnız
  // baştaki/sondaki boşluk ve 3+ ardışık boş satır kırpılır.
  const metin = String(ham ?? '')
    .replace(/\r\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim()
    .slice(0, ITIRAZ_EN_COK);
  if (metin.length < ITIRAZ_EN_AZ) {
    return { tamam: false, metin, hata: `İtiraz en az ${ITIRAZ_EN_AZ} karakter olmalı` };
  }
  return { tamam: true, metin, hata: null };
}

/** Ban sebebi: zorunlu, 1..500 karakter. Denetim izi boş sebeple dolmasın. */
export function sebepTemizle(s) {
  const t = String(s ?? '').replace(/\s+/g, ' ').trim().slice(0, 500);
  return t;
}

/** Panelde/istemcide okunur süre: 90 dk -> "1 saat 30 dakika". */
export function sureMetni(kalanSn, sozluk = null) {
  const s = sozluk || { gun: 'gün', saat: 'saat', dakika: 'dakika', az: 'birkaç saniye' };
  let kalan = Math.max(0, Math.floor(Number(kalanSn) || 0));
  const gun = Math.floor(kalan / 86400); kalan -= gun * 86400;
  const saat = Math.floor(kalan / 3600); kalan -= saat * 3600;
  const dk = Math.floor(kalan / 60);
  const parca = [];
  if (gun) parca.push(`${gun} ${s.gun}`);
  if (saat) parca.push(`${saat} ${s.saat}`);
  if (dk && !gun) parca.push(`${dk} ${s.dakika}`);   // gün varken dakika gürültü
  return parca.length ? parca.join(' ') : s.az;
}
