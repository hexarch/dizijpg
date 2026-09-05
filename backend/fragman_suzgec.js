// ===========================================================================
// FRAGMAN SÜZGECİ — kırık YouTube fragmanlarını yanıttan ele (5 Eyl 2026)
// ===========================================================================
//
// NE YAPAR: TMDB yanıtının içindeki `videos.results` (ve `/videos` ucunun
// `results`) listesinden, `fragman_durum` tablosunda KIRIK işaretli YouTube
// kimliklerini çıkarır. Uygulama hiçbir şey bilmez — elinde yalnız oynayan
// fragmanlar kalır ve `fragmanlariSec` bir sonrakini seçer.
//
// ÜÇ KARAR, ÜÇÜ DE BİR TUZAKTAN GELİYOR:
//
//  1) SÜZME SERVİS ANINDA, ÖNBELLEĞE YAZARKEN DEĞİL.
//     `tmdb_onbellek` HAM TMDB yanıtını saklar ve öyle kalmalı. Süzülmüş
//     gövde yazsaydık: (a) video geri geldiğinde (gizli→herkese açık) onu
//     ancak TTL dolunca görürdük, (b) önbellekteki veri artık TMDB'nin
//     söylediği şey OLMAZDI — hata ayıklarken en pahalı yalan budur.
//
//  2) TANIMADIĞIMIZ KİMLİK GEÇER ('bilinmiyor' gizlenmez).
//     Tarama kuyruğu 21.650 yapımı dolaşıyor; yeni eklenen bir fragman biz
//     sorana kadar "kanıtsız" durumdadır. Kanıtsız gizlemek, ölçülen hatayı
//     (7/1308 kırık) ölçülmeyen bir hatayla (binlerce sağlam fragman kayıp)
//     takas etmek olurdu.
//
//  3) FELAKET FRENİ TABLO GENELİNDE, LİSTE BAŞINA DEĞİL.
//     İlk yazımda fren liste başınaydı: "bir yanıttaki videoların %80'inden
//     fazlası kırıksa dokunma". YANLIŞTI ve tam da düzeltmek istediğimiz
//     durumu engelliyordu — TEK fragmanı olan ve o fragmanı ölmüş bir yapımda
//     oran 1,0 çıkıyor, fren devreye giriyor ve siyah iframe gömülmeye devam
//     ediyordu. Oysa doğru davranış listeyi BOŞALTMAK: kahramanda kapak
//     fotoğrafları kalır.
//     Korunması gereken gerçek felaket ayrı: `fragman_durum` toplu bir yazma
//     hatasıyla bozulursa (ya da YouTube günlerce arıza verip her şey 'yok'
//     işaretlenirse) BÜTÜN sitenin fragmanı sessizce kaybolur. O yüzden fren
//     YÜKLEME anında ve TABLO ORANINA bakarak çalışır: kırık oranı eşiği
//     aşarsa küme BOŞ bırakılır (süzgeç kapalı) ve günlüğe yazılır.
//     Ölçülen gerçek oran %0,84 (1.308 fragmanın 11'i); eşik %30'da.

/** Kırık sayılan durumlar. 'bilinmiyor' KASITLA yok — bkz. karar (2). */
const KIRIK_DURUMLAR = ['yok', 'gizli', 'gomulemez', 'bolge'];

/**
 * Süzgecin kendini kapattığı TABLO oranı — bkz. karar (3).
 * Ölçülen normal oran %0,84; %30 hem bol marj bırakıyor hem de gerçek bir
 * felaketi (tablonun üçte birinden fazlası kırık) mutlaka yakalıyor.
 */
const AZAMI_KIRIK_ORAN = 0.3;

/** Bir dizi öğesi TMDB VİDEO nesnesi mi? (`/search/*` sonucu da `results`
 *  taşır; oradaki nesnelerde `site`/`key` YOKTUR — karıştırırsak arama
 *  sonuçlarını silerdik.) */
const videoMu = (v) => v != null && typeof v === 'object'
  && typeof v.key === 'string' && typeof v.site === 'string';

/**
 * Tek bir `results` dizisini süzer. Değişiklik yoksa AYNI diziyi döndürür
 * (çağıran bunu `===` ile sınayıp gövdeyi hiç kopyalamıyor).
 */
function listeyiSuz(liste, kirikSet) {
  if (!Array.isArray(liste) || liste.length === 0) return liste;
  const kirikMi = (v) => videoMu(v) && v.site === 'YouTube' && kirikSet.has(v.key);
  if (!liste.some(kirikMi)) return liste;
  // Liste TAMAMEN boşalabilir ve bu DOĞRUDUR: tek fragmanı ölmüş yapımda
  // kahraman kapak fotoğraflarıyla çizilir (`karisikKahramanDiz`), siyah
  // iframe gömülmez. Felaket freni burada değil, `KirikFragmanlar.yukle`de.
  return liste.filter((v) => !kirikMi(v));
}

/**
 * TMDB gövdesinden kırık fragmanları eler.
 *
 * İki biçimi de tanır:
 *   · `/tv/123?append_to_response=videos` → `veri.videos.results`
 *   · `/tv/123/videos`                    → `veri.results`
 *
 * GÖVDEYİ DEĞİŞTİRMEZ: değişiklik varsa sığ kopya üretir. Sebep, `tmdbGetir`
 * bazı yollarda önbellekten okunan nesneyi doğrudan döndürüyor — yerinde
 * değişiklik, aynı sürecin sonraki isteklerine sızardı.
 *
 * @param {*} veri TMDB yanıt gövdesi (her şey olabilir)
 * @param {Set<string>} kirikSet kırık YouTube kimlikleri
 */
function fragmanlariSuz(veri, kirikSet) {
  if (!kirikSet || kirikSet.size === 0) return veri;
  if (veri == null || typeof veri !== 'object' || Array.isArray(veri)) return veri;

  const ustListe = listeyiSuz(veri.results, kirikSet);
  const icVar = veri.videos != null && typeof veri.videos === 'object'
    && Array.isArray(veri.videos.results);
  const icListe = icVar ? listeyiSuz(veri.videos.results, kirikSet) : null;

  const ustDegisti = ustListe !== veri.results;
  const icDegisti = icVar && icListe !== veri.videos.results;
  if (!ustDegisti && !icDegisti) return veri;

  const kopya = { ...veri };
  if (ustDegisti) kopya.results = ustListe;
  if (icDegisti) kopya.videos = { ...veri.videos, results: icListe };
  return kopya;
}

/**
 * Kırık kimlik kümesini veritabanından okuyup bellekte tutar.
 *
 * KÜME (kume.js) TUZAĞI: üretimde 4 işçi var, yani bu nesneden 4 kopya
 * olacak ve her biri kendi zamanlayıcısını kuracak. Bilerek: küme genelinde
 * paylaşılan bir önbellek (kume_ipc) burada KAZANÇ GETİRMEZ — sorgu
 * kısmi indeksten okunan birkaç bin satır, 10 dakikada 4 kez. Paylaşım
 * karmaşıklığı, kazandırdığından pahalı olurdu.
 *
 * İLK YÜKLEME BAŞARISIZSA SÜZGEÇ KAPALI kalır (boş küme = hiçbir şeyi eleme).
 * Tersi — "yükleyemedim, ihtiyatla hepsini gizleyeyim" — bütün fragmanları
 * öldürürdü.
 */
class KirikFragmanlar {
  /**
   * @param {import('pg').Pool} havuz
   * @param {number} tazelemeMs kaç ms'de bir yeniden okunsun
   */
  constructor(havuz, tazelemeMs = 10 * 60 * 1000) {
    this.havuz = havuz;
    this.tazelemeMs = tazelemeMs;
    this.set = new Set();
    this.sonYukleme = 0;
    this.zamanlayici = null;
  }

  async yukle() {
    try {
      // Kırıklar ve TOPLAM tek sorguda: fren oranı ikisini de gerektiriyor,
      // iki ayrı sorgu arasında tablo değişebilirdi.
      const { rows } = await this.havuz.query(
        `SELECT youtube_id FROM fragman_durum WHERE durum = ANY($1::text[])`,
        [KIRIK_DURUMLAR],
      );
      const { rows: [t] } = await this.havuz.query(
        `SELECT count(*)::int AS n FROM fragman_durum WHERE son_kontrol IS NOT NULL`);
      const toplam = t?.n || 0;
      // Karar (3): tablo bozulduysa süzgeci KAPAT, gizleme yapma.
      if (toplam > 0 && rows.length / toplam > AZAMI_KIRIK_ORAN) {
        console.error(`fragman_suzgec: ${rows.length}/${toplam} kimlik kırık `
          + `işaretli (eşik %${Math.round(AZAMI_KIRIK_ORAN * 100)}) — SÜZGEÇ KAPATILDI; `
          + 'fragman_durum tablosunu denetle');
        this.set = new Set();
        this.sonYukleme = Date.now();
        return 0;
      }
      this.set = new Set(rows.map((r) => r.youtube_id));
      this.sonYukleme = Date.now();
      return this.set.size;
    } catch (e) {
      // Tablo henüz migrasyonla gelmediyse (42P01) SESSİZ geç: yeni sürüm
      // eski veritabanına karşı da ayağa kalkmalı.
      if (e?.code !== '42P01') {
        console.error(`fragman_suzgec: kırık liste okunamadı — ${e?.message || e}`);
      }
      return -1;
    }
  }

  /** Zamanlayıcıyı başlatır; süreç kapanışını engellemez (`unref`). */
  baslat() {
    if (this.zamanlayici) return this;
    this.yukle();
    this.zamanlayici = setInterval(() => this.yukle(), this.tazelemeMs);
    this.zamanlayici.unref?.();
    return this;
  }

  durdur() {
    if (this.zamanlayici) clearInterval(this.zamanlayici);
    this.zamanlayici = null;
  }

  /** `fragmanlariSuz`un tek argümanlı hali — çağrı yerinde okunaklı olsun. */
  suz(veri) {
    return fragmanlariSuz(veri, this.set);
  }
}

export {
  KIRIK_DURUMLAR, AZAMI_KIRIK_ORAN, fragmanlariSuz, listeyiSuz, videoMu, KirikFragmanlar,
};
