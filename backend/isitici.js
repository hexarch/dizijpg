// ===========================================================================
// TMDB ÖNBELLEK ISITICISI — proaktif tazeleme (20 Ağu 2026)
// ===========================================================================
//
// HANGİ ÖLÇÜLEN HATAYI ÇÖZÜYOR
// `tmdb_onbellek` bugüne kadar TEMBEL bir aynaydı: bir satır ancak o sayfaya
// ziyaret gelince doluyordu. Ölçüm (20 Ağu 2026): 20.329 satırın 17.221'i
// (%85) 7 günden eski — yani en uzun TTL (`ONBELLEK_TTL_SN.uzun`) bile dolmuş.
// Sonuç: Googlebot SOĞUK bir sayfaya girince canlı TMDB çağrısını bekliyor.
// 18 Ağu 2026'da `/kisi/102426` ve `/kisi/113970` bu yüzden 504 aldı.
//
// server.js'teki `SSR_BUTCE_MS = 12000` BELİRTİYİ yumuşattı (504 yerine
// noindex kabuk döndürüyor) ama SEBEBİ çözmedi: ayna soğuk. Bu betik aynayı
// ziyaretten ÖNCE sıcak tutar.
//
// KORUNAN KARARLAR (hepsi gerçek bir tuzaktan geliyor)
//
//  1) ÖNBELLEK ANAHTARI server.js İLE BİREBİR AYNI (`onbellekAnahtari`).
//     Farklı bir anahtar üretseydik AYRI satırlar yazardık: tablo şişer,
//     önbellek ISINMAZ ve kimse fark etmez (sayfa yine soğuk açılır, tablo
//     yine dolu görünür). `test/isitici.test.js` bu eşleşmeyi server.js
//     KAYNAĞINDAN türeterek doğrular — elle kopyalanmış sabitle değil.
//
//  2) server.js'ten import EDİLMEZ: içe aktarıldığı anda `app.listen`
//     çağırıyor (projede bilinen kısıt; bkz. test/liste_duzenleme.test.js).
//     Bu yüzden kendi fetch + upsert'ümüzü yapıyoruz — (1) bu yüzden kritik.
//
//  3) BAŞARISIZ ÇAĞRI İYİ VERİYİ EZMEZ. TMDB 5xx/timeout dönerse ya da gövde
//     beklenen şekilde değilse satıra DOKUNULMAZ. Eski ama geçerli veri,
//     taze hiçliğe yeğdir (aynı disiplin server.js'te "bayat-veriyle-devam").
//     TMDB 404 dönerse satır SİLİNMEZ: SSR'ın 404/noindex mantığı server.js'te
//     yaşıyor, ısıtıcı oraya karışmaz.
//
//  4) KÜME TUZAĞI: üretimde `kume.js` 4 işçi çalıştırıyor. Bir `setInterval`
//     server.js'e gömülseydi TMDB'ye 4 KAT yüklenirdik. Bu yüzden ısıtıcı
//     TEK BAŞINA ÇALIŞAN bir betiktir (cron tetikler) ve ayrıca Postgres
//     advisory lock ile ikinci kopyayı engeller.
//
//  5) SÜREKLİ KİP — 24 SAATE YAYILMIŞ, GECE TOPLU KOŞU DEĞİL (20 Ağu 2026,
//     kullanıcı itirazı: "bunu neden aynı anda yapmak yerine 24 saate yayıp
//     sürekli güncel tutmuyoruz?"). İlk tasarım gece tek koşuydu; ÜÇ KUSURU
//     vardı ve üçü de ölçülebilir (aşağıdaki sayılar 20 Ağu 2026'da kuyruk
//     benzetimiyle ÖLÇÜLDÜ; kuyruk tahmini ~33.600 anahtar):
//       · İLK DOLDURMA: 33.600 ÷ 4.000 gecelik tavan = ~9 GECE.
//         Sürekli akışta aynı iş 70 koşu = ~11,7 SAAT sürüyor.
//       · UÇURUM: hepsi aynı anda tazelenirse hepsi AYNI ANDA bayatlar. Tek
//         bir koşu kaçarsa (bakım, dolu disk, kilit) tüm katalog bir gün daha
//         yaşlanır. Yayılmış akışta bayatlama da yayılır.
//       · ANİ YÜK: 45 dk boyunca 5 istek/sn bir sıçramadır. 24 saate yayılınca
//         ~0,5 istek/sn — TMDB'nin de bizim de fark etmeyeceği bir taban gürültü.
//     Bu yüzden cron 10 DAKİKADA BİR çalışır ve her koşu KÜÇÜK bir bütçe
//     harcar. Tasarımın gerisi aynen çalışıyordu: adaylar "en bayat önce"
//     sıralı, advisory lock çakışmayı yiyor, aday toplama koşu başına ~6 sorgu.
//
//  5b) BOŞ KOŞU UCUZ VE SESSİZ. Günde 144 koşu olacak ve kararlı durumda
//     çoğunda tazelenecek bir şey OLMAYACAK. Bayat aday yoksa TMDB'ye HİÇ
//     dokunulmaz ve stdout'a HİÇBİR ŞEY yazılmaz. Gerekçe: 144 satır
//     "0 tazelendi" günlüğü gerçek bir sorunu görünmez yapar; sessizlik
//     burada BİLGİDİR — "her şey taze" demektir. İş yapılan, hata alan ya da
//     kuyruğu boşaltamayan koşu TAM özet yazar.
//
//  6) KATMANLI TAZELEME: 1990 yapımı bir filmin verisi değişmiyor, yayını
//     süren dizininki her hafta değişiyor. Eşikler TEK YERDE (`AYAR.KATMAN`).
//
//  7) DİL: yalnız `tr-TR` + `en-US` proaktif ısıtılır (ölçüm: tr-TR 7.219
//     satır, en-US 1.109, diğer 43 dil ~385'er). Uzun kuyruk TEMBEL kalır —
//     43 dili ısıtmak istek sayısını 20 katına çıkarır, karşılığında neredeyse
//     hiç trafik yoktur. Googlebot bize dil başlığı göndermediği için SSR
//     zaten `tr-TR` görüyor (server.js: `TMDB_DIL[kod] || 'en-US'`).
//
// KULLANIM
//   node isitici.js                  (sürekli kip: cron 10 dakikada bir çağırır)
//   node isitici.js --kuru           (yazmaz; KUYRUKTA NE VAR sorusunu cevaplar)
//   node isitici.js --azami-istek=5000 --azami-dakika=60   (elle yetiştirme koşusu)
//   node isitici.js --sinif=kisi     (yalnız /kisi sayfaları)
//
// Ortam: `DATABASE_URL` ve `TMDB_TOKEN` (server.js ile aynı değişkenler).
// GİZLİ DEĞER ASLA BASILMAZ — özet yalnız sayılar ve anahtar yolları içerir.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

const BURASI = path.dirname(fileURLToPath(import.meta.url));
const TMDB = 'https://api.themoviedb.org/3';

// ===========================================================================
// AYARLAR — KOORDİNATÖR BURAYI AYARLAR, BAŞKA HİÇBİR YERİ
// ===========================================================================
// Katman eşikleri BİLEREK tek nesnede: ikinci bir kopya (ör. SQL'e gömülü bir
// `interval`) ilk ayarda sessizce ayrışır ve "ısıttım sandığımız" satırlar
// bayat kalır. `katmanTtlSn` bu nesneyi ÇAĞRI ANINDA okur, modül yüklenirken
// değil — testler eşikleri değiştirip davranışın izlediğini kanıtlıyor.
export const AYAR = {
  /// Proaktif ısıtılan diller (7. karar). Uzun kuyruk tembel kalır.
  ///
  /// KISA UYGULAMA KODU ('tr'), TMDB KODU ('tr-TR') DEĞİL — çünkü içerik
  /// detay yolu artık kısa kodu İÇERİYOR (`include_video_language=tr,en,null`),
  /// yani anahtarın kendisi kısa koda bağlı. TMDB karşılığı server.js'teki
  /// `TMDB_DIL` haritasından OKUNUR (`sunucuDilHaritasi`), burada ikinci bir
  /// kopya tutulmaz: 'fil' → 'tl-PH' gibi kısaltmayla türetilemeyen eşleşmeler
  /// var, elle türetmek sessiz bir anahtar bölünmesi üretirdi.
  DILLER: ['tr', 'en'],

  // ---------------------------------------------------------------------
  // SINIF BAŞINA DİL — "hangi anahtarı KİM okuyor?" (20 Ağu 2026)
  // ---------------------------------------------------------------------
  // Her anahtarı iki dilde ısıtmak 24.000 kişi anahtarını 48.000 yapıyordu.
  // Ölçü BÜTÇE DEĞİL DOĞRULUK: bir anahtarı ısıtmanın tek gerekçesi onu
  // OKUYAN biri olmasıdır. Anahtar şekli okuyucuyu belirliyor ve bunu
  // server.js + app/lib kaynağından tek tek doğruladım:
  //
  //   PAYLAŞILAN (uygulama da okur/yazar → kullanıcının dili önemli):
  //     · icerik → `/tmdb/(tv|movie)/:id` aynı `icerikTmdbYolu`ya gidiyor.
  //     · sezon  → app `detay.dart:1671` ve `tmdb_puan_izgara.dart:51`
  //                `/tmdb/tv/:id/season/:n` çağırıyor; SSR de aynı anahtarı
  //                okuyor. Yani en-US'un GERÇEK bir okuyucusu var.
  //
  //   YALNIZ SSR (bot okuyor; Googlebot dil başlığı GÖNDERMİYOR → daima tr-TR,
  //   ölçüm: SSR anahtarlarının 554/554'ü tr-TR):
  //     · kisi    → SSR `?append_to_response=combined_credits,translations`
  //                 derken uygulama AYRI iki çağrı yapıyor (`kisi.dart:256-257`:
  //                 `/tmdb/person/:id` + `/tmdb/person/:id/combined_credits`).
  //                 Anahtarlar ÖRTÜŞMÜYOR → en-US kişi anahtarını KİMSE okumaz.
  //     · bolum   → SSR `?append_to_response=translations`, uygulamaya ise
  //                 server.js `append_to_response=videos` ekliyor (5807).
  //                 Yine ayrı anahtar → en-US'u okuyan yok.
  //     · diziDuz → `/tv/:id` (eksiz). Uygulamanın `/tmdb/tv/:id`si artık
  //                 paylaşılan yola yönleniyor, yani bu anahtarı SADECE bölüm
  //                 SSR'ı okuyor.
  //
  // Kısıtlamanın riski YOK: bu anahtarlar zaten TEMBEL doldurulmaya devam
  // ediyor. En kötü ihtimalle Türkçe olmayan bir kullanıcı bir kez bekler —
  // yani bugünkü davranışın aynısı.
  SINIF_DILLERI: {
    icerik: ['tr', 'en'],
    sezon: ['tr', 'en'],
    kisi: ['tr'],
    bolum: ['tr'],
    diziDuz: ['tr'],
  },

  // ---------------------------------------------------------------------
  // SINIF BAŞINA ASGARİ BÜTÇE PAYI (20 Ağu 2026 — CANLIDA ÖLÇÜLEN AÇLIK)
  // ---------------------------------------------------------------------
  // KANIT (/var/log/dizijpg-isitici.log, beş ardışık koşu):
  //   tazelendi=480 kuyruk=27430 sınıf_payı=kisi:480
  //   tazelendi=480 kuyruk=26950 sınıf_payı=kisi:480   (× 5)
  // Bölüme İKİ SAATTE SIFIR istek gitti; 8.557 bölüm satırının yalnız 761'i
  // tazeydi. Kişi önbelleği 297 → 28.944 satıra çıkarken bölüm hiç ilerlemedi.
  //
  // SEBEP: `siralamayiKur`un round-robin'i BANT İÇİNDE çalışıyor. Hiç
  // çekilmemiş kişi anahtarları `yas = Infinity` → `yas/ttl = Infinity` →
  // KALICI olarak en üst bant. Bölümlerin satırı VAR (bayat ama mevcut) →
  // sonlu yaş → alt bant. Üst bantta tek sınıf olunca round-robin dağıtacak
  // ikinci sınıf GÖRMÜYOR.
  //
  // Benim ilk benzetimim bunu kaçırdı çünkü üç sınıfı da AYNI ANDA soğuk
  // varsaydı. Canlıda sınıflar sırayla soğuyor: her içerik satırı önbelleğe
  // girince 10 oyuncu × dil kadar YENİ kişi adayı doğuyor, yani kişi kümesi
  // sonradan patlıyor.
  //
  // ÇÖZÜM: bant ne olursa olsun her sınıfa bütçeden bir TABAN pay. %20 =
  // 480'lik koşuda sınıf başına 96 istek; üç sınıf 288, kalan 192 bant
  // sırasına göre (yani baskın sınıfa) gider. Bölüm bu tabanla günde
  // 144 × 96 ≈ 13.800 istek alır — 7.800 bayat satırı bir günde kapanır.
  // Adayı olmayan sınıfın payı DEVROLUR (bütçe boşa gitmez).
  TABAN_PAY_ORANI: 0.2,

  // ---------------------------------------------------------------------
  // SÜREKLİ KİP — AŞAĞIDAKİ DÖRT SAYI BİRBİRİNE BAĞLIDIR
  // ---------------------------------------------------------------------
  // İKİ BAĞ (ikisi de `bagAyarlariDogrula` ile ZORLANIR, açılışta patlar):
  //
  //   (A) AZAMI_DAKIKA < CRON_DAKIKA
  //       Koşu, bir sonraki cron tetiğinden ÖNCE bitmeli. Bitmezse ikinci
  //       koşu advisory lock'a takılıp BOŞA döner: cron çalışıyor görünür,
  //       kuyruk ilerlemez. 8 < 10 → her koşuya 2 dk marj (aday sorguları,
  //       yavaş son istek, konteyner gecikmesi).
  //
  //   (B) AZAMI_ISTEK ≈ AZAMI_DAKIKA × 60 × ISTEK_SN
  //       8 dk × 60 sn × 1 istek/sn = 480. İki tavan AYNI tavanı iki yönden
  //       tarif eder; biri değişip diğeri unutulursa ya kuyruk sarkar
  //       (istek tavanı küçük kalır) ya koşular üst üste biner (büyük kalır).
  //
  // GÜNLÜK KAPASİTE: (1440 / 10) × 480 = 69.120 istek/gün.
  // ÖLÇÜM (20 Ağu 2026, kuyruk benzetimi, ~33.600 anahtarlık tahmini kuyruk):
  //   · ilk doldurma 70 koşu ≈ 11,7 saat,
  //   · kararlı durumda günlük talep ~2.430 istek = kapasitenin %3,5'i,
  //   · en büyük kuyruk derinliği 0, hiçbir sınıfta aşım 1,00×'i geçmiyor.
  // Yani bütçe bol; darboğaz kapasitede değil, sıralama ADALETİNDE (bkz.
  // `siralamayiKur`) — ve orada ölçülen bir açlık VARDI, düzeltildi.
  //
  // YENİDEN HESAP (20 Ağu 2026 akşamı, bölüm haritası tüm bölümlere açıldı):
  // `bolum` sınıfı adayı 115 → ~86.900 (78.725 bölüm + 2 × 4.089 sezon), yani
  // toplam kuyruk ~33.600 değil ~95.000 anahtar. TABAN_PAY_ORANI DEĞİŞTİRİLMEDİ;
  // aritmetik hâlâ tutuyor:
  //   · üç sınıfın tabanı 3 × 96 = 288, bandın kalanı 192 → tamamı `bolum`a
  //     gider (hepsi `yas = Infinity`) ⇒ bolum 288/koşu = 41.472/gün
  //     ⇒ ilk doldurma 86.900 / 41.472 ≈ 2,1 gün,
  //   · `icerik` ve `kisi` tabanla 96/koşu = 13.824/gün alır; ölçülen kararlı
  //     talepleri toplam ~2.430/gün ⇒ AÇ KALMIYORLAR (20 Ağu'da düzeltilen
  //     hatanın aynadaki görüntüsü bu tabanla oluşmuyor),
  //   · kararlı durum: 86.900 / 30 gün (KATMAN.bolum) = ~2.900 istek/gün =
  //     kapasitenin %4,2'si.
  // Tavan koymaya da gerek YOK: taban payı zaten diğer sınıfları koruyor.
  CRON_DAKIKA: 10,

  /// Saniyedeki TMDB isteği. Sürekli kipte 1/sn: bu iş artık GÜNDÜZ de
  /// çalışıyor ve gerçek kullanıcılarla aynı TMDB kotasını paylaşıyoruz.
  /// Gece koşusunun aceleci 5/sn ayarı burada YANLIŞ olurdu — ısıtıcı yüzünden
  /// kullanıcı 429 yememeli. Etkin ortalama: 8/10 × 1 ≈ 0,8 istek/sn.
  ISTEK_SN: 1,

  /// 8 → 7 (21 Ağu 2026, CANLI ÖLÇÜM). İş fazı 8 dk tavanına TAM oturuyordu
  /// (`süre=479.4sn`, altı ardışık koşuda birebir aynı), üstüne aday toplama
  /// ~50 sn biniyor (`adaylariTopla` 41,7 sn + yeni `ISITMA_BOLUM_SORGU` 8 sn).
  /// Toplam ≈ 530 sn, cron penceresi 600 sn → marj yalnız 70 sn (%12).
  ///
  /// TEHLİKE: `adaylariTopla` kuyruk büyüdükçe UZUYOR. 600 sn aşıldığı an
  /// bir sonraki koşu advisory lock'a takılıp BOŞA döner — yani kapasite
  /// yarıya iner ve bunu yalnız günlüğe bakan fark eder.
  /// 7 dk ile marj 130 sn'ye çıkıyor. Maliyet: 480 → 420 istek/koşu
  /// (60.480/gün), ölçülen kararlı talebin (~2.430/gün) hâlâ 24 katı.
  AZAMI_ISTEK: 420,
  AZAMI_DAKIKA: 7,

  /// KATMANLAR (saniye). Tazeleme aralığı: satırın yaşı bunu geçtiyse tazelenir.
  KATMAN: {
    /// Yayını süren dizi: bölüm listesi, sonraki bölüm tarihi ve durum haftada
    /// birkaç kez değişir. 2 gün = SSR'ın gösterdiği "sonraki bölüm" bilgisi
    /// en fazla 2 gün geride kalır.
    surenDizi: 2 * 24 * 3600,
    /// Son `YENI_YAPIM_YIL` yıl içinde çıkmış yapım: puan/afiş/özet hâlâ
    /// oturuyor, ama gün gün değişmiyor.
    yeniYapim: 7 * 24 * 3600,
    /// Bitmiş dizi / eski film: veri pratikte donmuş. Ayda bir yeter; daha sık
    /// tazelemek istek bütçesini hiçbir karşılık almadan yerdi.
    dinlenmis: 30 * 24 * 3600,
    /// Kişi: biyografi ve filmografi nadiren değişir, ama yeni proje eklenir.
    kisi: 14 * 24 * 3600,
    /// Yayınlanmış bölüm/sezon metadatası: neredeyse hiç değişmez.
    bolum: 30 * 24 * 3600,
    /// OLUMSUZ ÖNBELLEK ÖMRÜ — "TMDB bu anahtarda 404 dedi" bilgisi bu kadar
    /// süre hatırlanır ve o süre boyunca anahtar BİR DAHA İSTENMEZ.
    ///
    /// NEDEN 30 GÜN (ne daha kısa ne daha uzun):
    ///  · `KATMAN.bolum` İLE AYNI. 404'lerin tamamına yakınını bölüm sınıfı
    ///    üretiyor; VAR OLAN bir bölümü 30 günde bir tazelerken YOK OLAN bir
    ///    bölümü daha sık sormanın hiçbir gerekçesi yok.
    ///  · `tablolariBuda` da `tmdb_onbellek`i 30 günde buduyor (server.js).
    ///    "TMDB durumunu ne kadar hatırlıyoruz" sorusunun TEK cevabı olsun.
    ///  · MALİYET: canlı ölçüm 1.837 hayalet anahtar (21 Ağu 2026). 30 günde
    ///    bir yeniden denemek günde 61 istek = günlük kapasitenin %0,09'u.
    ///    Yani "sonradan eklenen bölüm" senaryosu BEDAVA karşılanıyor: TMDB'ye
    ///    bir bölüm eklenirse en geç 30 günde ısıtılır — zaten var olan bir
    ///    bölümü tazeleme sıklığımızla AYNI gecikme.
    yok404: 30 * 24 * 3600,
  },

  /// "Yeni yapım" sınırı (yıl). `KATMAN.yeniYapim` bu yaşa kadar uygulanır.
  YENI_YAPIM_YIL: 2,

  /// İçerik sayfasının bota gösterdiği oyuncu bağlantısı sayısı.
  /// server.js `/og/icerik/:tur/:tmdbId` içinde `credits.cast.slice(0, 10)`.
  /// Googlebot'un ulaşabileceği /kisi URL'leri TAM OLARAK bunlar — 504'ü de
  /// buradan gelen bir kişi sayfasında yedik.
  OYUNCU_BAGLANTI: 10,

  /// Tek TMDB denemesi için tavan (ms) ve yeniden deneme sayısı.
  ISTEK_ZAMAN_ASIMI_MS: 15000,
  DENEME: 3,

  /// Advisory lock anahtarı. Sabit ve bu betiğe özel; başka bir iş aynı sayıyı
  /// kullanırsa ikisi birbirini kilitler.
  KILIT_ANAHTARI: 620260820,
};

/// TMDB `status` değerleri: bu dizi hâlâ yayında/çekimde sayılır.
export const SUREN_DURUMLAR = new Set(['Returning Series', 'In Production', 'Planned']);

/**
 * Sürekli kipin İKİ BAĞINI denetler (bkz. AYAR'daki (A) ve (B)).
 *
 * NEDEN ÇALIŞMA ANINDA: bu bağ yorumda kalsaydı biri `AZAMI_DAKIKA`yı 20
 * yapıp `CRON_DAKIKA`yı unuttuğunda hiçbir şey patlamazdı — koşular sessizce
 * üst üste biner, ikincisi kilide takılır, kuyruk saatlerce ilerlemez ve bunu
 * ancak kimse `/kisi` sayfasında 504 yiyene kadar fark etmezdik.
 * @returns {string[]} sorunlar (boş dizi = tutarlı)
 */
export function bagAyarlariDogrula(ayar = AYAR) {
  const sorunlar = [];
  if (!(ayar.AZAMI_DAKIKA < ayar.CRON_DAKIKA)) {
    sorunlar.push(`AZAMI_DAKIKA (${ayar.AZAMI_DAKIKA}) < CRON_DAKIKA `
      + `(${ayar.CRON_DAKIKA}) olmalı; yoksa sonraki koşu kilide takılıp boşa döner`);
  }
  const beklenen = ayar.AZAMI_DAKIKA * 60 * ayar.ISTEK_SN;
  if (ayar.AZAMI_ISTEK < beklenen * 0.75 || ayar.AZAMI_ISTEK > beklenen * 1.25) {
    sorunlar.push(`AZAMI_ISTEK (${ayar.AZAMI_ISTEK}) ≈ AZAMI_DAKIKA × 60 × `
      + `ISTEK_SN (${beklenen}) olmalı; %25'ten fazla ayrışmış`);
  }
  return sorunlar;
}

/**
 * Bir koşunun GERÇEK istek bütçesi: iki tavandan hangisi önce bağlarsa o.
 * Taban payları da bu sayıdan hesaplanır — `azamiIstek`ten hesaplansaydı hız
 * kapısı yüzünden hiç ulaşılamayan bir tavana göre pay dağıtırdık.
 */
export const kosuButcesi = (secim) =>
  Math.min(secim.azamiIstek, Math.floor(secim.azamiDakika * 60 * secim.istekSn));

/** Sürekli kipte günde kaç istek harcanabilir (kuyruk boşalma süresi bundan çıkar). */
export function gunlukKapasite(secim, ayar = AYAR) {
  return Math.floor((1440 / ayar.CRON_DAKIKA) * kosuButcesi(secim));
}

/** Bu sınıf hangi dillerde ısıtılır? (`SINIF_DILLERI` ∩ seçilen diller) */
export function sinifDilleri(dilSinifi, secim, ayar = AYAR) {
  const izinli = ayar.SINIF_DILLERI[dilSinifi];
  if (!izinli) return secim.diller;            // tanımsız sınıf → hepsi
  const kesisim = secim.diller.filter((d) => izinli.includes(d));
  // Kesişim boşsa kullanıcı `--diller` ile bu sınıfı tamamen dışarıda
  // bırakmıştır; sessizce "hepsi"ne dönmek bayrağı ters yorumlamak olurdu.
  return kesisim;
}

// ===========================================================================
// 1) ÖNBELLEK ANAHTARI — server.js:820 `tmdbGetir` ile BİREBİR
// ===========================================================================
/**
 * server.js `tmdbGetir` içindeki anahtar kuruluşunun AYNADAKİ kopyası.
 *
 * NEDEN KOPYA: server.js import edilemiyor (2. karar). Kopyanın kaymaması
 * `test/isitici.test.js` ile kilitli: test server.js KAYNAĞINDAN o bloğu
 * çekip `new Function` ile çalıştırıyor ve iki çıktıyı karşılaştırıyor.
 * Buradaki bir satırı değiştirirsen test kırmızıya döner — kırıldığında
 * "testi düzeltme", server.js'e uy.
 *
 * `/images` uçlarında dil TAMAMEN çıkarılır: `language` görselleri dile göre
 * süzer, bölüm kareleri ise dilsizdir (iso_639_1: null) → dil verilirse liste
 * BOŞ döner. Tek girdi bütün dillere hizmet eder.
 */
export function onbellekAnahtari(yolGirdi, dil) {
  let yol = yolGirdi;
  if (/\/images(\?|$)/.test(yol)) {
    yol = yol
      .replace(/([?&])language=[a-zA-Z-]*&?/g, '$1')
      .replace(/[?&]$/, '');
  } else if (/[?&]language=/.test(yol)) {
    yol = yol.replace(/([?&]language=)[a-zA-Z-]+/, `$1${dil}`);
  } else {
    yol += (yol.includes('?') ? '&' : '?') + 'language=' + dil;
  }
  return yol;
}

// ===========================================================================
// 2) HANGİ YOLLAR ISITILIR — SSR uçlarının GERÇEKTEN istediği yollar
// ===========================================================================
// Bu üç fonksiyon server.js'teki üç SSR ucuyla birebir eşleşir. Fazladan yol
// ısıtmak istek bütçesini boşa harcar; eksik yol ısıtmak sayfayı yine soğuk
// bırakır (ör. `/tv/:id` ile içerik detay yolu AYRI anahtarlardır — bölüm
// sayfası birincisini, içerik sayfası ikincisini ister; ikisi de gerekli).

// ---------------------------------------------------------------------------
// İÇERİK DETAY YOLU — server.js `icerikTmdbYolu` İLE BİREBİR (20 Ağu 2026)
// ---------------------------------------------------------------------------
// DEĞİŞİKLİĞİN SEBEBİ (server.js tarafında ölçüldü): SSR ile uygulama AYNI
// yapım için İKİ AYRI önbellek satırı yazıyordu; SSR
// `?append_to_response=credits,similar` derken uygulama kendi (kararsız)
// anahtarını kullanıyordu. server.js ikisini TEK paylaşılan yolda birleştirdi.
//
// ISITICI İÇİN BU HAYATİ: eski yolu ısıtmaya devam etseydik ÖLÜ bir anahtarı
// tazeler, SSR'ın gerçekten okuduğu satır ise soğur kalırdı — yani ısıtıcı
// çalışıyor görünüp SSR'ı GERİLETİRDİ. Ölçüm: eski anahtarda 375 taze yapım,
// yeni paylaşılan anahtarda yalnız 39.
//
// DAĞITIM SIRASI: bu dosya server.js değişikliğiyle AYNI dağıtımda gitmeli.
// Geçişten sonra `icerik` sınıfının tamamı bir kerelik soğuk kalır; kuyruk
// benzetimiyle ölçüldü (20 Ağu 2026): 1.261 yapım → 6 koşu (1,0 saat),
// 2.400 yapım → 10 koşu (1,7 saat), 4.000 yapım → 17 koşu (2,8 saat).
// Yani NORMAL 480'lik bütçe yetiyor; geçici bütçe artışına gerek yok.
//
// NEDEN YİNE KOPYA: server.js import edilemiyor (`app.listen` tetikleniyor).
// Kopyanın kaymaması `test/isitici.test.js` ile kilitli: test `ICERIK_APPEND`
// sabitini ve `icerikTmdbYolu` gövdesini server.js KAYNAĞINDAN çekip
// `new Function` ile çalıştırıyor ve çıktıyı buradakiyle karşılaştırıyor.
// Buradaki bir karakter kayarsa test kırmızıya döner — o zaman "testi
// düzeltme", server.js'e uy.
const ICERIK_APPEND = 'credits,videos,recommendations,external_ids,watch/providers,images';

/**
 * `/og/icerik/:tur/:tmdbId` ve `/tmdb/(tv|movie)/:id` ucunun PAYLAŞTIĞI yol.
 * `language` BİLEREK yok: onu `onbellekAnahtari` (server.js'te `tmdbGetir`)
 * sona ekler.
 * @param {'tv'|'movie'} tur
 * @param {number|string} tmdbId
 * @param {string} dilKodu KISA uygulama dil kodu ('tr', 'en') — fragman dili
 */
export function icerikYolu(tur, tmdbId, dilKodu = 'tr') {
  // Kimlik SAYIYA çevriliyor: `/tv/01396` ile `/tv/1396` AYNI yapımdır ama
  // dize olarak iki AYRI anahtar olurdu.
  const kimlik = Number(tmdbId);
  const p = new URLSearchParams();
  p.set('append_to_response', ICERIK_APPEND);
  p.set('include_image_language', 'null');
  p.set('include_video_language', `${dilKodu},en,null`);
  return `/${tur}/${kimlik}?${p.toString()}`;
}

/** `/og/kisi/:id` → tek istek (combined_credits + translations). */
export function kisiYolu(tmdbId) {
  return `/person/${tmdbId}?append_to_response=combined_credits,translations`;
}

/** `/og/dizi/:id/sezon/:s/bolum/:b` → üç paralel istek. */
export function bolumYollari(tmdbId, sezon, bolum) {
  return [
    `/tv/${tmdbId}`,
    `/tv/${tmdbId}/season/${sezon}`,
    `/tv/${tmdbId}/season/${sezon}/episode/${bolum}?append_to_response=translations`,
  ];
}

// ===========================================================================
// 3) KATMAN SEÇİMİ
// ===========================================================================
/**
 * Bu anahtar kaç saniyede bir tazelenmeli?
 *
 * `AYAR.KATMAN`ı ÇAĞRI ANINDA okur (modül yüklenirken değil) — eşiği tek
 * yerden değiştirmek gerçekten yeterli olsun diye.
 *
 * @param {{sinif:'icerik'|'kisi'|'bolum', durum?:string|null, tarih?:string|null}} bilgi
 * @param {number} simdiMs
 */
export function katmanTtlSn(bilgi, simdiMs = Date.now()) {
  const { KATMAN, YENI_YAPIM_YIL } = AYAR;
  if (bilgi.sinif === 'kisi') return KATMAN.kisi;
  if (bilgi.sinif === 'bolum') return KATMAN.bolum;
  if (bilgi.durum && SUREN_DURUMLAR.has(bilgi.durum)) return KATMAN.surenDizi;
  const yil = parseInt(String(bilgi.tarih || '').slice(0, 4), 10);
  const buYil = new Date(simdiMs).getUTCFullYear();
  if (Number.isInteger(yil) && buYil - yil <= YENI_YAPIM_YIL) return KATMAN.yeniYapim;
  return KATMAN.dinlenmis;
}

// ===========================================================================
// 4) GÖVDE DOĞRULAMA — 3. karar (başarısız çağrı iyi veriyi ezmez)
// ===========================================================================
/**
 * Yazmaya değer bir TMDB gövdesi mi?
 *
 * TMDB hata gövdeleri 200 ile de gelebiliyor (`{success:false, status_code}`).
 * Isıttığımız uçların HEPSİ nesne döndürür ve `id` taşır (tv/movie/person/
 * season/episode). Bu yüzden ölçü katı: nesne + `id` + `success !== false`.
 * Katı olmak güvenli yön — şüpheli gövdede satıra DOKUNMAYIZ, eski veri kalır.
 */
export function gecerliGovde(veri) {
  if (!veri || typeof veri !== 'object' || Array.isArray(veri)) return false;
  if (veri.success === false) return false;
  return Number.isFinite(Number(veri.id));
}

// ===========================================================================
// 5) BAYRAKLAR
// ===========================================================================
/**
 * `--ad=deger`, `--ad deger` ve `--bayrak` biçimlerini çözer.
 * Bilinmeyen bayrak SESSİZCE yutulmaz: yazım hatası yüzünden tavansız koşan
 * bir cron, bu betiğin en pahalı hata biçimi olurdu.
 */
export function bayraklariCoz(argv, ayar = AYAR) {
  const sonuc = {
    kuru: false,
    azamiIstek: ayar.AZAMI_ISTEK,
    azamiDakika: ayar.AZAMI_DAKIKA,
    istekSn: ayar.ISTEK_SN,
    diller: [...ayar.DILLER],
    siniflar: ['icerik', 'kisi', 'bolum'],
  };
  const sayi = (v, ad) => {
    const n = Number(v);
    if (!Number.isFinite(n) || n <= 0) throw new Error(`${ad} pozitif sayı olmalı: ${v}`);
    return n;
  };
  for (let i = 0; i < argv.length; i++) {
    const parca = argv[i];
    if (!parca.startsWith('--')) throw new Error(`Tanınmayan argüman: ${parca}`);
    const esit = parca.indexOf('=');
    const ad = esit >= 0 ? parca.slice(2, esit) : parca.slice(2);
    const deger = () => (esit >= 0 ? parca.slice(esit + 1) : argv[++i]);
    switch (ad) {
      case 'kuru': sonuc.kuru = true; break;
      case 'azami-istek': sonuc.azamiIstek = sayi(deger(), '--azami-istek'); break;
      case 'azami-dakika': sonuc.azamiDakika = sayi(deger(), '--azami-dakika'); break;
      case 'istek-sn': sonuc.istekSn = sayi(deger(), '--istek-sn'); break;
      case 'diller': sonuc.diller = String(deger()).split(',').filter(Boolean); break;
      case 'sinif': case 'siniflar': {
        const s = String(deger()).split(',').filter(Boolean);
        const gecersiz = s.filter((x) => !['icerik', 'kisi', 'bolum'].includes(x));
        if (gecersiz.length) throw new Error(`Bilinmeyen sınıf: ${gecersiz.join(',')}`);
        sonuc.siniflar = s;
        break;
      }
      default: throw new Error(`Tanınmayan bayrak: --${ad}`);
    }
  }
  if (!sonuc.diller.length) throw new Error('--diller boş olamaz');
  return sonuc;
}

// ===========================================================================
// 6) server.js KAYNAĞINDAN SİTE HARİTASI SORGULARI
// ===========================================================================
// "Hangi kimlikler yayınlanıyor?" sorusunun TEK doğru kaynağı server.js'in
// `SITEMAP_SORGU` / `SITEMAP_BOLUM_SORGU` sabitleridir. Sorguyu buraya elle
// kopyalasaydık, SEO eşikleri (SEO_YORUM_MIN vb.) değiştiği gün ısıtıcı
// haritayla ayrışır ve tam da Google'ın gezdiği sayfaları ISITMAMAYA başlardı
// — hem de sessizce. Bu yüzden sorgular kaynaktan ÇEKİLİP kuruluyor.

/** Bir `const AD = ...;` bildiriminin bittiği indeksi bulur (string/şablon farkında). */
function bildirimSonu(kaynak, bas) {
  const yigin = [{ tur: 'kod', derinlik: 0 }];
  for (let i = bas; i < kaynak.length; i++) {
    const c = kaynak[i];
    const ust = yigin[yigin.length - 1];
    if (ust.tur === 'tirnak') {
      if (c === '\\') { i++; continue; }
      if (c === ust.kar) yigin.pop();
      continue;
    }
    if (ust.tur === 'sablon') {
      if (c === '\\') { i++; continue; }
      if (c === '`') { yigin.pop(); continue; }
      if (c === '$' && kaynak[i + 1] === '{') { yigin.push({ tur: 'kod', derinlik: 0 }); i++; }
      continue;
    }
    if (c === '\'' || c === '"') { yigin.push({ tur: 'tirnak', kar: c }); continue; }
    if (c === '`') { yigin.push({ tur: 'sablon' }); continue; }
    if (c === '{' || c === '(' || c === '[') { ust.derinlik++; continue; }
    if (c === '}' || c === ')' || c === ']') {
      if (ust.derinlik === 0 && yigin.length > 1) { yigin.pop(); continue; }
      ust.derinlik--;
      continue;
    }
    if (c === ';' && ust.derinlik === 0 && yigin.length === 1) return i + 1;
  }
  throw new Error('bildirim sonu bulunamadı');
}

/** server.js kaynağından `const AD = ...;` bildirimini olduğu gibi çeker. */
export function bildirimCek(kaynak, ad) {
  const im = new RegExp(`^const ${ad} =`, 'm');
  const e = im.exec(kaynak);
  if (!e) throw new Error(`server.js içinde ${ad} bulunamadı`);
  return kaynak.slice(e.index, bildirimSonu(kaynak, e.index + e[0].length));
}

/**
 * Site haritası SQL'lerini server.js kaynağından kurar (bağımlılıklarıyla).
 *
 * ÜÇ SORGU, İKİ FARKLI İŞ (20 Ağu 2026):
 *  · `SITEMAP_SORGU` / `SITEMAP_BOLUM_SORGU` — Google'a BİLDİRİLEN URL'ler.
 *  · `ISITMA_BOLUM_SORGU` — ısıtılacak bölüm kuyruğu. Harita sorgusundan
 *    AYRI olmak ZORUNDA: harita yalnız sezon yanıtı ÖNBELLEKTE OLAN bölümü
 *    döndürür, ısıtıcı da yalnız haritadakini çekseydi önbellekte olmayan
 *    sezon hiç çekilmez, harita da hiç büyümezdi (kendi kuyruğunu besleyen
 *    kilit). Gerekçenin tamamı server.js'te sorgunun başlığında.
 */
export function sunucuSorgulari(kaynak) {
  const adlar = [
    'SEO_YORUM_MIN', 'SEO_INCELEME_MIN', 'seoOzUzunluk', 'SEO_GIZLI_ICERIK_YOK',
    'SEO_YORUM_KOSUL', 'SEO_INCELEME_KOSUL', 'SITEMAP_SORGU', 'SITEMAP_BOLUM_SORGU',
    'ISITMA_BOLUM_SORGU',
  ];
  const govde = adlar.map((a) => bildirimCek(kaynak, a)).join('\n');
  // eslint-disable-next-line no-new-func
  const sorgular = new Function(
    `${govde}\nreturn { SITEMAP_SORGU, SITEMAP_BOLUM_SORGU, ISITMA_BOLUM_SORGU };`)();
  for (const [ad, sql] of Object.entries(sorgular)) {
    if (/\$\{/.test(sql)) throw new Error(`${ad} içinde çözülmemiş şablon var`);
  }
  return sorgular;
}

/**
 * Uygulama dil kodu → TMDB dil kodu (`TMDB_DIL`), server.js kaynağından.
 *
 * NEDEN KOPYALANMIYOR: 45 satırlık bir harita ve eşleşmeler kısaltmayla
 * türetilemiyor ('fil' → 'tl-PH', 'nb' → 'nb-NO'). Yanlış TMDB kodu = yanlış
 * `language=` = ayrı bir önbellek satırı; ısıtılan satırı kimse okumaz.
 */
export function sunucuDilHaritasi(kaynak) {
  // eslint-disable-next-line no-new-func
  const harita = new Function(`${bildirimCek(kaynak, 'TMDB_DIL')}\nreturn TMDB_DIL;`)();
  if (!harita || typeof harita !== 'object' || !harita.tr) {
    throw new Error('server.js TMDB_DIL haritası okunamadı');
  }
  return harita;
}

/** server.js ile aynı düşme kuralı: bilinmeyen kod → 'en-US'. */
export const tmdbDilKodu = (harita, kod) => harita[kod] || 'en-US';

// ===========================================================================
// 7) ADAY TOPLAMA (veritabanı)
// ===========================================================================
const OBEK = 2000;   // `anahtar = ANY($1)` sorgusunu parça parça çalıştır

/** Anahtar listesinin yaşı + katman bilgisi (tek sorgu, öbekli). */
async function onbellekDurumu(havuz, anahtarlar) {
  const harita = new Map();
  for (let i = 0; i < anahtarlar.length; i += OBEK) {
    const { rows } = await havuz.query(
      `SELECT anahtar,
              EXTRACT(EPOCH FROM (now() - guncelleme)) AS yas,
              veri->>'status' AS durum,
              COALESCE(veri->>'first_air_date', veri->>'release_date') AS tarih
         FROM tmdb_onbellek WHERE anahtar = ANY($1::text[])`,
      [anahtarlar.slice(i, i + OBEK)],
    );
    for (const r of rows) {
      harita.set(r.anahtar, { yas: Number(r.yas), durum: r.durum, tarih: r.tarih });
    }
  }
  return harita;
}

// ===========================================================================
// 7b) OLUMSUZ ÖNBELLEK (`tmdb_yok`) — "TMDB burada YOK dedi" bilgisini SAKLA
// ===========================================================================
// ÖLÇÜLEN SONSUZ DÖNGÜ (canlı /var/log/dizijpg-isitici.log, 21 Ağu 2026):
//   tazelendi=480 hata=0 tmdb_404=0     ← normal
//   tazelendi=12  hata=0 tmdb_404=468   ← sonra HER koşuda aynı sayılar
// 480 isteğin 468'i 404 dönüyordu ve AYNI anahtarlar her 10 dakikada bir
// yeniden isteniyordu: günde 144 × 468 ≈ 67.000 boşa istek.
//
// KÖK NEDEN — DOĞRULANDI: 404 dönünce `tmdb_onbellek`e satır YAZILMIYOR
// (3. karar: bozuk/boş yanıtla iyi veriyi ezme — bu karar DOĞRU ve duruyor).
// Ama satır olmayınca `adaylariTopla` o anahtara `yas = Infinity` veriyor,
// `Infinity / ttl = Infinity` en üst aşım bandı demek, yani anahtar kuyruğun
// BAŞINA geri geliyor. Başarısızlık kendini ödüllendiriyordu.
//
// DAHA DA KÖTÜSÜ — KALICI DURMA: anahtar sırası sabit olduğu için hayaletler
// frontier'in gerisinde BİRİKİYOR. 21 Ağu'da tek bir dizinin (`/tv/31910`)
// 468 hayaleti bütçenin %97,5'ini yiyordu; sıra `/tv/37854`e (One Piece,
// 1.120 hayalet) geldiğinde birikim 1.588 > 480 olacak ve ısıtıcı SIFIR
// ilerlemeye düşecekti. Bu yüzden "israf" değil, ARIZA.
//
// NEDEN AYRI TABLO, `tmdb_onbellek`te BİR İŞARET DEĞİL
// -----------------------------------------------------
// Bu tasarımın TEK gerçek tehlikesi işaretin VERİ sanılmasıdır. server.js
// `tmdbGetir` şunu yapıyor:
//     SELECT veri FROM tmdb_onbellek WHERE anahtar=$1 AND guncelleme > ...
//     ... return rows[0].veri;
// İşareti aynı tabloya koysaydık SSR ve `/tmdb/*` ucu onu GERÇEK YANIT gibi
// döndürürdü — sayfa bozulur, üstelik sessizce. Güvenli hâle getirmek için
// `tmdbGetir`, `tmdbTopluGetir`, `SITEMAP_BOLUM_SORGU`, `ISITMA_BOLUM_SORGU`,
// katalog sorgusu, `kisiKimlikleri` cast taraması ve admin istatistikleri —
// yani 17 bin satırlık server.js'in yedi ayrı okuyucusu — tek tek süzgeç
// eklemek zorunda kalırdı; birini unutmak sessiz bir arıza olurdu.
// AYRI TABLO bu hatayı YAPILAMAZ kılar: SSR/uygulama yolu `tmdb_yok`u
// hiç sorgulamıyor, dolayısıyla YANLIŞLIKLA okuyamaz. Testler bunu hem
// kaynak üzerinden hem davranış üzerinden kilitliyor.
//
// BUDAMA İLE İLİŞKİ: `tablolariBuda` yalnız `tmdb_onbellek`i buduyor, bu
// tabloya DOKUNMUYOR — yani "budama sildi, yeniden 404 aldık, döngü geri
// geldi" senaryosu YOK. Şişmeyi kendimiz `yokIsaretleriniBuda` ile
// engelliyoruz: 2 × TTL'den eski satır, aday kümesinden çıkmış bir anahtardır
// (kümede kalsaydı TTL dolunca yeniden denenir ve damgası tazelenirdi).
//
// ŞEMA: `migrasyon-2026-08-21b.sql`. Tablo YOKKEN betik ÇÖKMEZ — her koşuda
// GÜRÜLTÜLÜ bir hata satırı basıp eski davranışla devam eder. Gerekçe: cron
// 10 dakikada bir koşuyor; dağıtım ile migrasyon arasında kalan bir koşunun
// yığın iziyle patlaması, ısıtmayı tamamen durdurmaktan daha kötü. Sessizlik
// yok: uyarı her koşuda log'a düşer.
const YOK_TABLO_HATASI = /relation "tmdb_yok" does not exist|undefined_table/i;
let yokTabloUyarildi = false;

/** Tablo henüz yoksa GÜRÜLTÜLÜ uyar (koşu başına bir kez) ve devam et. */
function yokTabloEksik(e) {
  if (e?.code !== '42P01' && !YOK_TABLO_HATASI.test(e?.message || '')) return false;
  if (!yokTabloUyarildi) {
    yokTabloUyarildi = true;
    console.error('isitici: UYARI — `tmdb_yok` tablosu yok, olumsuz önbellek '
      + 'DEVRE DIŞI (404 alan anahtarlar her koşuda yeniden istenir). '
      + 'migrasyon-2026-08-21b.sql uygulanmalı.');
  }
  return true;
}

/**
 * Bütün 404 işaretleri (anahtar → saniye cinsinden yaş).
 *
 * TABLONUN TAMAMI TEK SORGUDA okunuyor, `anahtar = ANY($1)` ile öbeklenmiyor:
 * aday kümesi 112.000 anahtar (57 öbek) ama işaret tablosu ölçülen 1.837
 * satır. Öbekli okuma 57 gidiş-gelişi İKİYE KATLARDI, tam liste ise tek
 * seq scan. Tablonun sınırı `yokIsaretleriniBuda` ile korunuyor.
 */
export async function yokIsaretleriniOku(havuz) {
  try {
    const { rows } = await havuz.query(
      `SELECT anahtar, EXTRACT(EPOCH FROM (now() - guncelleme)) AS yas FROM tmdb_yok`);
    return new Map(rows.map((r) => [r.anahtar, Number(r.yas)]));
  } catch (e) {
    if (yokTabloEksik(e)) return new Map();
    throw e;
  }
}

/**
 * 404 işaretini yaz/tazele. `sayac` yalnız TEŞHİS için: bir anahtar kaç kez
 * 404 aldığını söyler, yani "bu gerçekten yok" ile "TMDB o gün tökezledi"
 * ayrımını sonradan SORGULANABİLİR kılar (404 kalıcı bir cevaptır, ama
 * ölçmeden varsaymıyoruz).
 */
export async function yokIsaretiYaz(havuz, anahtar) {
  try {
    await havuz.query(
      `INSERT INTO tmdb_yok (anahtar, ilk, guncelleme, sayac)
       VALUES ($1, now(), now(), 1)
       ON CONFLICT (anahtar) DO UPDATE
         SET guncelleme = now(), sayac = tmdb_yok.sayac + 1`,
      [anahtar],
    );
  } catch (e) {
    if (!yokTabloEksik(e)) throw e;
  }
}

/**
 * İşareti kaldır — anahtar SONRADAN TMDB'ye eklenmişse.
 *
 * Yalnız süresi DOLMUŞ bir işaretin ardından başarılı bir çekim olduğunda
 * çağrılır (`aday.yokEskimis`), yani sıcak yolda ek bir DELETE yok.
 */
export async function yokIsaretiSil(havuz, anahtar) {
  try {
    await havuz.query('DELETE FROM tmdb_yok WHERE anahtar = $1', [anahtar]);
  } catch (e) {
    if (!yokTabloEksik(e)) throw e;
  }
}

/**
 * Aday kümesinden çıkmış işaretleri unut (tablo sınırsız şişmesin).
 *
 * EŞİK 2 × TTL: hâlâ aday olan bir anahtar TTL dolar dolmaz yeniden denenir
 * ve damgası tazelenir, yani 2 × TTL'yi ASLA geçemez. Geçen satır artık
 * kuyrukta olmayan (dizi haritadan düştü, sezon değişti) bir anahtardır.
 */
export async function yokIsaretleriniBuda(havuz, ayar = AYAR) {
  try {
    const { rowCount } = await havuz.query(
      `DELETE FROM tmdb_yok WHERE guncelleme < now() - ($1 || ' seconds')::interval`,
      [2 * ayar.KATMAN.yok404],
    );
    return rowCount;
  } catch (e) {
    if (yokTabloEksik(e)) return 0;
    throw e;
  }
}

/**
 * Adaylara 404 işaretini UYGULA — saf fonksiyon (testler bunu doğrudan sürer).
 *
 * İKİ HAL, İKİSİ DE GEREKLİ:
 *  · İşaret TAZE (yas < TTL) → `yokMu = true` + `tazeMi = true`. Anahtar
 *    listede KALIR (sayımı dürüst olsun) ama bütçe HARCAMAZ. Döngü burada
 *    kırılıyor.
 *  · İşaret ESKİ (yas ≥ TTL) → `yokEskimis = true`, aday BAYAT kalır: yeniden
 *    denenir. Bölüm sonradan TMDB'ye eklenmişse böyle geri döner; çekim
 *    başarılıysa `kosuYap` işareti siler.
 *
 * GERÇEK SATIR HER ZAMAN KAZANIR: `tmdb_onbellek`te satır varsa işarete
 * bakılmaz. (Normalde ikisi bir arada olmaz — başarılı çekim işareti siler —
 * ama elle doldurulmuş bir satırı 404 işareti gizlemesin.)
 */
export function yokIsaretiUygula(adaylar, isaretler, ayar = AYAR) {
  const ttl = ayar.KATMAN.yok404;
  let taze = 0;
  let eskimis = 0;
  for (const a of adaylar) {
    if (a.satirVar) continue;
    const yas = isaretler.get(a.anahtar);
    if (yas === undefined) continue;
    if (yas < ttl) {
      a.yokMu = true;
      a.tazeMi = true;
      taze++;
    } else {
      a.yokEskimis = true;
      eskimis++;
    }
  }
  return { taze, eskimis };
}

/** Sitemap + kullanıcı dokunuşu birleşimi: ısıtılacak tv/movie kimlikleri. */
async function icerikKimlikleri(havuz, sitemapSorgu) {
  const { rows } = await havuz.query(`
    WITH harita AS (${sitemapSorgu}),
    dokunulan AS (
      SELECT tur, tmdb_id FROM izlemeler
      UNION SELECT tur, tmdb_id FROM puanlar WHERE tur IN ('tv','movie')
      UNION SELECT l.tur, l.tmdb_id FROM liste_ogeleri l
      UNION SELECT tur, tmdb_id FROM favoriler WHERE tur IN ('tv','movie')
    )
    SELECT tur, tmdb_id, min(oncelik) AS oncelik FROM (
      SELECT tur, tmdb_id, 0 AS oncelik FROM harita
      UNION ALL
      SELECT tur, tmdb_id, 1 AS oncelik FROM dokunulan
    ) t
    WHERE tur IN ('tv','movie') AND tmdb_id > 0
    GROUP BY tur, tmdb_id`);
  return rows.map((r) => ({ tur: r.tur, tmdbId: r.tmdb_id, oncelik: Number(r.oncelik) }));
}

/** Isıtılacak bölüm sayfaları (tv, sezon, bölüm) — `ISITMA_BOLUM_SORGU`. */
async function bolumKimlikleri(havuz, bolumSorgu) {
  const { rows } = await havuz.query(bolumSorgu);
  return rows.map((r) => ({ tmdbId: r.tmdb_id, sezon: r.sezon, bolum: r.bolum }));
}

/**
 * Isıtılacak kişi kimlikleri.
 *  · öncelik 0 — kullanıcının DOKUNDUĞU kişiler (favori/puan/tepki),
 *  · öncelik 1 — indekslenen içerik sayfalarının bota BASILAN ilk N oyuncusu.
 *    Googlebot'un `/kisi/:id` sayfalarına ulaşabildiği TEK yol budur (kişi
 *    haritası yok), 18 Ağu'daki 504 de tam olarak böyle bir sayfada yendi.
 *    Liste, ZATEN ÖNBELLEKTE olan içerik satırlarından çıkarılır — ek TMDB
 *    isteği yok.
 */
async function kisiKimlikleri(havuz, icerikAnahtarlari) {
  const oncelik = new Map();
  const { rows: dokunulan } = await havuz.query(`
    SELECT DISTINCT tmdb_id FROM (
      SELECT tmdb_id FROM favoriler WHERE tur = 'person'
      UNION ALL SELECT tmdb_id FROM puanlar WHERE tur = 'person'
      UNION ALL SELECT tmdb_id FROM tepkiler WHERE tur = 'person'
    ) t WHERE tmdb_id > 0`);
  for (const r of dokunulan) oncelik.set(r.tmdb_id, 0);

  for (let i = 0; i < icerikAnahtarlari.length; i += OBEK) {
    const { rows } = await havuz.query(
      `SELECT DISTINCT (a.e->>'id')::int AS tmdb_id
         FROM tmdb_onbellek o,
              LATERAL jsonb_array_elements(
                CASE WHEN jsonb_typeof(o.veri->'credits'->'cast') = 'array'
                     THEN o.veri->'credits'->'cast' ELSE '[]'::jsonb END
              ) WITH ORDINALITY AS a(e, n)
        WHERE o.anahtar = ANY($1::text[])
          AND a.n <= $2
          AND a.e->>'id' ~ '^[0-9]+$'`,
      [icerikAnahtarlari.slice(i, i + OBEK), AYAR.OYUNCU_BAGLANTI],
    );
    for (const r of rows) if (!oncelik.has(r.tmdb_id)) oncelik.set(r.tmdb_id, 1);
  }
  // ADAY KÜMESİ BÜYÜMESİ — kuru koşunun "neden 7.382 dedin de 27.910 oldu?"
  // sorusunun cevabı. Kişi adayları ÖNBELLEKTEKİ içerik satırlarından türüyor:
  // bir içerik anahtarı ilk kez ısıtılınca 10 oyuncusu O ANDAN İTİBAREN aday
  // oluyor. Yani içerik önbelleği doldukça kişi kuyruğu BÜYÜR. Bu beklenen ve
  // SINIRLI bir büyüme — tavanı `içerik sayısı × OYUNCU_BAGLANTI` — ama kuru
  // koşuda görünmezse kuyruk sıçraması kontrolsüz sanılır.
  let kapsananSayi = 0;
  for (let i = 0; i < icerikAnahtarlari.length; i += OBEK) {
    const { rows: kapsam } = await havuz.query(
      `SELECT count(*)::int AS dolu FROM tmdb_onbellek WHERE anahtar = ANY($1::text[])`,
      [icerikAnahtarlari.slice(i, i + OBEK)],
    );
    kapsananSayi += kapsam[0]?.dolu ?? 0;
  }
  const liste = [...oncelik].map(([tmdbId, o]) => ({ tmdbId, oncelik: o }));
  liste.icerikToplam = icerikAnahtarlari.length;
  liste.icerikDolu = kapsananSayi;
  return liste;
}

/**
 * Bütün adayları kurar ve SIRALAR.
 *
 * SIRA ÖNEMLİ: tavana takılan koşu listeyi ORTADAN keser, yani sıra fiilen
 * "hangi sayfalar sıcak kalır"a karar verir. Ölçü: önce Google'ın gezdiği
 * (öncelik 0) sayfalar, sonra EN BAYAT olan — hiç satırı olmayan anahtar en
 * bayat sayılır (o sayfa bugün kesin soğuk açılıyor).
 */
export async function adaylariTopla(havuz, secim, kaynak, simdiMs = Date.now()) {
  const { SITEMAP_SORGU, ISITMA_BOLUM_SORGU } = sunucuSorgulari(kaynak);
  const dilHaritasi = sunucuDilHaritasi(kaynak);
  // `istekler`: dilden BAĞIMSIZ yollar (kişi, bölüm, `/tv/:id`).
  // `dilliIstekler`: yolun KENDİSİ dile bağlı olanlar (içerik detayı —
  // `include_video_language` kısa dil kodunu taşıyor). İkisi ayrı tutuluyor
  // çünkü birincisinde tek yol N dile açılır, ikincisinde her dil AYRI yol.
  // `istekler`: yolu dilden BAĞIMSIZ olanlar (kişi, sezon, bölüm, `/tv/:id`).
  // `dilliIstekler`: yolun KENDİSİ dile bağlı olanlar (içerik detayı —
  // `include_video_language` kısa dil kodunu taşıyor). İkisi ayrı tutuluyor
  // çünkü birincisinde tek yol N dile açılır, ikincisinde her dil AYRI yol.
  //
  // `dilSinifi` `sinif`ten AYRI bir alan: `sinif` TAZELEME KATMANINI ve
  // raporlamayı, `dilSinifi` ise HANGİ DİLLERDE ısıtılacağını belirler
  // (`AYAR.SINIF_DILLERI`). İkisi her zaman örtüşmüyor — bkz. `/tv/:id`.
  const istekler = [];
  const dilliIstekler = [];
  const icerikAnahtarlari = [];
  let kisiBuyume = null;   // kişi adaylarının ne kadar büyüyeceği (kuru koşu raporu)

  const icerikler = secim.siniflar.includes('icerik') || secim.siniflar.includes('kisi')
    ? await icerikKimlikleri(havuz, SITEMAP_SORGU) : [];
  const icerikDilleri = sinifDilleri('icerik', secim);
  for (const i of icerikler) {
    // Kişi listesi ÖNBELLEKTEKİ içerik satırından çıkarılıyor; cast bütün
    // dillerde aynı olduğu için ilk dilin anahtarı yeter.
    const ilkKod = icerikDilleri[0] || secim.diller[0];
    icerikAnahtarlari.push(onbellekAnahtari(
      icerikYolu(i.tur, i.tmdbId, ilkKod), tmdbDilKodu(dilHaritasi, ilkKod)));
    if (secim.siniflar.includes('icerik')) {
      for (const kod of icerikDilleri) {
        dilliIstekler.push({
          yol: icerikYolu(i.tur, i.tmdbId, kod), kod, sinif: 'icerik', oncelik: i.oncelik,
        });
      }
    }
  }

  if (secim.siniflar.includes('bolum')) {
    // SIRA: sorgu (tv, sezon, bölüm) sıralı geliyor; dizi ve sezon anahtarı
    // sezon DEĞİŞTİĞİNDE bir kez üretilir. Eskiden her bölüm satırı için
    // yeniden üretilip Map'te tekilleşiyordu — 61 satırda görünmez, 78.725
    // satırda 236 bin gereksiz nesne demek.
    let sonSezon = '';
    for (const b of await bolumKimlikleri(havuz, ISITMA_BOLUM_SORGU)) {
      const [dizi, sezon, bolum] = bolumYollari(b.tmdbId, b.sezon, b.bolum);
      if (sezon !== sonSezon) {
        sonSezon = sezon;
        // `/tv/:id` (eksiz) içerik anahtarından FARKLIDIR ve onu YALNIZ bölüm
        // SSR'ı okur. `sinif: 'icerik'` çünkü tazeleme aralığını dizinin durumu
        // belirlemeli; `dilSinifi: 'diziDuz'` çünkü dili SSR'ınki (yalnız tr).
        istekler.push({ yol: dizi, sinif: 'icerik', dilSinifi: 'diziDuz', oncelik: 0 });
        // ÖNCELİK 0 — SEZON ÖNCE, BÖLÜM SONRA (20 Ağu 2026).
        // `siralamayiKur`da `oncelik` EN BAŞTAKİ sıralama anahtarı. Sezon
        // yanıtı iki iş birden yapar: site haritasının kapsamını AÇAR
        // (`SITEMAP_BOLUM_SORGU` sezon yanıtından okuyor) ve dizi sayfasının
        // bölüm listesini besler. 8.178 sezon anahtarı ~1 günde biter ve
        // harita o gün 78 bin URL'e ulaşır; 78.725 bölüm anahtarı arkadan
        // gelir. Ters sırada harita günlerce dar kalırdı.
        istekler.push({ yol: sezon, sinif: 'bolum', dilSinifi: 'sezon', oncelik: 0 });
      }
      istekler.push({ yol: bolum, sinif: 'bolum', dilSinifi: 'bolum', oncelik: 1 });
    }
  }

  if (secim.siniflar.includes('kisi')) {
    const kisiler = await kisiKimlikleri(havuz, icerikAnahtarlari);
    kisiBuyume = { toplam: kisiler.icerikToplam, dolu: kisiler.icerikDolu };
    for (const k of kisiler) {
      istekler.push({
        yol: kisiYolu(k.tmdbId), sinif: 'kisi', dilSinifi: 'kisi', oncelik: k.oncelik,
      });
    }
  }

  // Dil × yol, tekilleştirilmiş anahtarlar.
  const harita = new Map();
  const ekle = (yol, kod, sinif, oncelik) => {
    const anahtar = onbellekAnahtari(yol, tmdbDilKodu(dilHaritasi, kod));
    const eski = harita.get(anahtar);
    if (!eski) harita.set(anahtar, { anahtar, sinif, oncelik, dil: kod });
    else if (oncelik < eski.oncelik) eski.oncelik = oncelik;
  };
  for (const i of istekler) {
    for (const kod of sinifDilleri(i.dilSinifi, secim)) ekle(i.yol, kod, i.sinif, i.oncelik);
  }
  for (const i of dilliIstekler) ekle(i.yol, i.kod, i.sinif, i.oncelik);

  const adaylar = [...harita.values()];
  const durumlar = await onbellekDurumu(havuz, adaylar.map((a) => a.anahtar));
  for (const a of adaylar) {
    const d = durumlar.get(a.anahtar);
    a.satirVar = Boolean(d);
    a.yas = d ? d.yas : Infinity;         // satır yoksa "sonsuz bayat"
    a.ttl = katmanTtlSn({ sinif: a.sinif, durum: d?.durum, tarih: d?.tarih }, simdiMs);
    a.tazeMi = a.yas < a.ttl;
  }
  // OLUMSUZ ÖNBELLEK — `yas = Infinity` kapısını KAPATAN kat (7b). Sıralamadan
  // ÖNCE uygulanmalı: `siralamayiKur` ve `payiDagit` `tazeMi`ye bakıyor, yani
  // işaretli anahtar buradan sonra ne bütçe harcar ne sınıf kotası bozar.
  const yokOzet = yokIsaretiUygula(adaylar, await yokIsaretleriniOku(havuz));
  // İKİ KAT: önce bant/aşım sırası, sonra sınıf başına asgari pay. Sıra
  // önemli — `payiDagit` her sınıfın KENDİ EN İYİ adaylarını öne alabilmek
  // için zaten sıralanmış bir liste bekliyor.
  const sirali = payiDagit(siralamayiKur(adaylar), kosuButcesi(secim));
  sirali.kisiBuyume = kisiBuyume;
  sirali.yokOzet = yokOzet;
  return sirali;
}

/// Aşım bandı tavanı: 5 katından fazla gecikmiş anahtarlar arasında ayrım
/// yapmanın anlamı yok, hepsi "çok geç kalmış" kovasında adilce yarışsın.
const ASIM_BANT_TAVAN = 5;

/// Azalan sıralama karşılaştırıcısı. `Infinity - Infinity = NaN` olduğu için
/// çıkarma KULLANILAMAZ: hiç çekilmemiş anahtarların hepsi Infinity ve NaN
/// dönen bir comparator sıralamayı sessizce bozar.
const azalan = (x, y) => (x === y ? 0 : (y > x ? 1 : -1));

/**
 * SIRALAMA = FİİLEN POLİTİKA. Küçük bütçeyle sık koşarken liste her koşuda
 * ortadan kesilir; yani sıra "hangi sayfa sıcak kalır"a karar verir.
 *
 * ÜÇ ANAHTAR, SIRASIYLA:
 *
 *  1) ÖNCELİK — Google'ın gezdiği (sitemap + kullanıcı dokunuşu) sayfalar
 *     her zaman önce. Bilinçli değer yargısı.
 *
 *  2) AŞIM BANDI (`yas / ttl`, tam katlara yuvarlanmış) — HAM YAŞ DEĞİL.
 *     Ham yaş kullanılsaydı 30 gün TTL'li bir bölüm anahtarı, 2 gün TTL'li
 *     yayını süren diziyi HEP geçerdi: yaşı büyük ama TTL'i de büyük.
 *     Aşım oranı her sınıfı KENDİ katmanına göre ölçer, böylece uzun TTL'li
 *     sınıf kısa TTL'liyi aç bırakamaz.
 *
 *  3) SINIF İÇİ PAY (round-robin) — sınıf açlığına karşı. Aşım bandı eşit
 *     olan adaylar arasında sınıflar SIRAYLA hizmet alır (her sınıfın 0.
 *     adayı, sonra 1. adayı...).
 *
 *     BU BİR TAHMİN DEĞİL, ÖLÇÜM (20 Ağu 2026, kuyruk benzetimi): eski
 *     sıralamada (ham yaş + alfabetik tiebreak) soğuk doldurmanın İLK
 *     SAATİNDE — 6 koşu, 2.880 istek — `bolum` sınıfına SIFIR istek gitti;
 *     1. koşunun tamamı `kisi`, 3.-6. koşuların tamamı `icerik` oldu. Sebep:
 *     hiç çekilmemiş anahtarların hepsi `yas = Infinity` ile berabere kalıyor
 *     ve tiebreak alfabetik oluyordu (`/movie/…` < `/person/…` < `/tv/…`).
 *     Round-robin ile aynı 6 koşu 160/160/160 dağıldı ve TOPLAM DOLDURMA
 *     SÜRESİ DEĞİŞMEDİ (iki sıralamada da 70 koşu ≈ 11,7 saat) — yani adalet
 *     burada verimden hiçbir şey götürmüyor.
 *
 *     KARARLI DURUMDA açlık YOK (ölçüm: talep 2.430 istek/gün, kapasite
 *     69.120; en büyük kuyruk derinliği 0). Yani bu tiebreak yalnız SOĞUK
 *     DOLDURMADA ve ARAYA GİREN BİR BİRİKMEDE (uzun kesinti sonrası) iş
 *     görür — ama tam da o anlarda sayfaların hangi sırayla ısındığı önemli.
 *
 *  BANTLAMA NEDEN ŞART: `yas` bir float (EXTRACT EPOCH); iki anahtarın aşımı
 *  pratikte HİÇ tam eşit olmaz. Bantlanmasaydı (3) ölü kod olurdu.
 */
export function siralamayiKur(adaylar) {
  for (const a of adaylar) {
    a.asim = a.yas / a.ttl;
    a.bant = Number.isFinite(a.asim) ? Math.min(Math.floor(a.asim), ASIM_BANT_TAVAN) : Infinity;
  }
  // 1. geçiş: sınıf içi sıra → her adayın "kaçıncı sıradayım" payı.
  const sayac = new Map();
  for (const a of [...adaylar].sort((x, y) => (x.oncelik - y.oncelik)
    || azalan(x.bant, y.bant)
    || azalan(x.asim, y.asim)
    || (x.anahtar < y.anahtar ? -1 : 1))) {
    const n = sayac.get(a.sinif) || 0;
    a.payi = n;
    sayac.set(a.sinif, n + 1);
  }
  // 2. geçiş: genel sıra (pay, aşımdan ÖNCE gelir — adalet önce).
  adaylar.sort((x, y) => (x.oncelik - y.oncelik)
    || azalan(x.bant, y.bant)
    || (x.payi - y.payi)
    || azalan(x.asim, y.asim)
    || (x.anahtar < y.anahtar ? -1 : 1));
  return adaylar;
}

/**
 * SINIF BAŞINA ASGARİ PAY — `siralamayiKur`un ÜSTÜNE binen ikinci kat.
 *
 * NEDEN AYRI BİR KAT GEREKTİ (canlıda ölçüldü, bkz. `AYAR.TABAN_PAY_ORANI`):
 * `siralamayiKur`un round-robin'i yalnız AYNI BANT içinde adil. Canlıda
 * sınıflar aynı anda soğumadı — kişi kümesi sonradan patladı ve hepsi
 * `yas = Infinity` (en üst bant) oldu; bölümlerin satırı vardı, yani alt
 * banttaydı. Üst bantta tek sınıf kalınca round-robin dağıtacak ikinci sınıf
 * bulamadı ve bütçenin %100'ü kişiye gitti (beş koşu üst üste `kisi:480`).
 *
 * ÇÖZÜM SIRALAMA KATMANINDA: `kosuYap` listeyi baştan yürüyüp bütçede kesiyor,
 * dolayısıyla listenin BAŞINI yeniden dizmek kotayı UYGULAMAK demektir —
 * `kosuYap`ın hiçbir şeyden haberi olmasına gerek yok.
 *
 * NASIL: her sınıf kendi sırasından ilk `taban` adayını verir, bunlar
 * sınıflar arasında DÖNÜŞÜMLÜ olarak listenin başına alınır; geri kalan her
 * şey eski (bant) sırasında arkaya eklenir. Böylece:
 *   · her sınıf bütçeden en az `taban` kadar pay alır (bant ne olursa olsun),
 *   · adayı `taban`dan az olan sınıfın artığı DEVROLUR (bütçe boşa gitmez),
 *   · taban dışındaki bütçe yine en bayat/en öncelikli işe gider.
 *
 * ÖNCELİK 0 GARANTİSİ KORUNUR: her sınıfın kendi kuyruğu zaten `oncelik`e
 * göre sıralı, yani bir sınıf tabanını ÖNCE öncelik 0 adaylarıyla doldurur.
 * Bir sınıfın öncelik 1 adayı, BAŞKA sınıfın öncelik 0 adayının önüne
 * geçebilir — ama o sınıf da aynı koşuda kendi tabanını aldığı için AÇ KALMAZ.
 */
export function payiDagit(adaylar, butce, tabanOran = AYAR.TABAN_PAY_ORANI) {
  const bayat = [];
  const digerleri = [];   // taze olanlar: bütçe harcamıyorlar, sıraları önemsiz
  for (const a of adaylar) (a.tazeMi ? digerleri : bayat).push(a);
  const taban = Math.floor(butce * tabanOran);
  if (!bayat.length || taban < 1) return adaylar;

  const kuyruklar = new Map();
  for (const a of bayat) {
    if (!kuyruklar.has(a.sinif)) kuyruklar.set(a.sinif, []);
    kuyruklar.get(a.sinif).push(a);
  }
  // Tek sınıf varsa paylaştıracak kimse yok; sırayı bozmanın anlamı olmaz.
  if (kuyruklar.size < 2) return adaylar;

  const secilen = new Set();
  const on = [];
  for (let n = 0; n < taban; n++) {
    for (const kuyruk of kuyruklar.values()) {
      const a = kuyruk[n];
      if (a) { on.push(a); secilen.add(a); }
    }
  }
  return [...on, ...bayat.filter((a) => !secilen.has(a)), ...digerleri];
}

// ===========================================================================
// 8) KOŞU ÇEKİRDEĞİ — saf, enjekte edilebilir (testler bunu sürüyor)
// ===========================================================================
/**
 * @param {object} p
 * @param {Array} p.adaylar   `adaylariTopla` çıktısı
 * @param {(anahtar:string)=>Promise<{durum:'tamam'|'yok'|'hata', veri?:any}>} p.getir
 * @param {(anahtar:string, veri:any)=>Promise<void>} p.yaz
 * @param {(anahtar:string)=>Promise<void>} [p.yokYaz] 404 işaretini kaydet (7b)
 * @param {(anahtar:string)=>Promise<void>} [p.yokSil] süresi dolmuş işareti kaldır
 */
export async function kosuYap({
  adaylar, getir, yaz,
  // VARSAYILAN BOŞ, ÇÜNKÜ: bu iki geri çağrı yalnız veritabanı yan etkisidir;
  // `kosuYap`ın saf çekirdek olma özelliği (testler onu havuzsuz sürüyor)
  // korunsun diye zorunlu değiller. Ana akışın GERÇEKTEN geçirdiği testle
  // ayrıca kilitli — yoksa düzeltme sessizce devre dışı kalabilirdi.
  yokYaz = async () => {}, yokSil = async () => {},
  bekle = (ms) => new Promise((r) => setTimeout(r, ms)),
  simdi = () => Date.now(),
  azamiIstek = AYAR.AZAMI_ISTEK,
  azamiMs = AYAR.AZAMI_DAKIKA * 60000,
  istekSn = AYAR.ISTEK_SN,
  kuru = false,
  ornekTavan = 10,
}) {
  // KUYRUK DERİNLİĞİ: sürekli kipte "bitti" diye bir an yok, o yüzden gidişat
  // ancak bu sayıyla ölçülebilir. `bayatToplam` = şu an tazelenmeyi bekleyen
  // her şey; `kuyruk` = bunlardan bu koşunun bütçesine SIĞMAYANLAR. Günden güne
  // düşüyorsa doluyoruz; sabit kalıyorsa bütçe yetmiyor demektir.
  const bayatToplam = adaylar.reduce((n, a) => n + (a.tazeMi ? 0 : 1), 0);
  // 404 İŞARETLİ adaylar `tazeMi = true` ile geliyor (bütçe harcamasınlar
  // diye) ama "taze veri" DEĞİLLER — ayrı sayılıyorlar. Aynı kovaya
  // atsaydık `zaten_taze` bir gün sessizce "aslında hiç veri yok" demeye
  // başlardı ve olumsuz önbelleğin büyüklüğü GÖRÜNMEZ olurdu.
  const yokIsareti = adaylar.reduce((n, a) => n + (a.yokMu ? 1 : 0), 0);
  // `bakilan`/`taze` LİSTENİN TAMAMINDAN sayılır, döngü ilerledikçe DEĞİL.
  // Gerekçe: `payiDagit` taze adayları listenin sonuna atıyor ve bütçe
  // dolunca döngü erken kırılıyor; artımlı sayım "zaten_taze=0" gibi yanlış
  // bir rapor üretirdi. Bu iki sayı kuyruk ölçümünün bağlamı — yanlış olamaz.
  const ozet = {
    bakilan: adaylar.length, taze: adaylar.length - bayatToplam - yokIsareti,
    tazelendi: 0, hata: 0, yok: 0, yokIsareti, yokYeni: 0, yokCozuldu: 0,
    atlanan: 0,
    istek: 0, tavan: null, ornekler: [], sureMs: 0, kuru,
    bayatToplam, kuyruk: bayatToplam, sinifSayaci: {},
  };
  const baslangic = simdi();
  const araMs = 1000 / istekSn;
  let sonIstek = -Infinity;

  for (let i = 0; i < adaylar.length; i++) {
    const aday = adaylar[i];
    if (aday.tazeMi) continue;   // bütçe harcamaz; sayımı yukarıda yapıldı
    // TAVANLAR: aşıldığında listenin KALANI atlanır (kısmi koşu, sessiz değil).
    if (ozet.istek >= azamiIstek) { ozet.tavan = 'istek'; ozet.atlanan = adaylar.length - i; break; }
    if (simdi() - baslangic >= azamiMs) { ozet.tavan = 'sure'; ozet.atlanan = adaylar.length - i; break; }
    ozet.istek++;
    // Sınıf başına pay: açlık olup olmadığı ancak burada GÖRÜNÜR olur.
    ozet.sinifSayaci[aday.sinif] = (ozet.sinifSayaci[aday.sinif] || 0) + 1;
    if (ozet.ornekler.length < ornekTavan) ozet.ornekler.push(aday.anahtar);
    // KURU: istek sayılır (plan gerçekçi olsun) ama ne çağrı ne yazma yapılır.
    if (kuru) continue;

    const gecen = simdi() - sonIstek;
    if (gecen < araMs) await bekle(araMs - gecen);
    sonIstek = simdi();

    let sonuc;
    try {
      sonuc = await getir(aday.anahtar);
    } catch (e) {
      sonuc = { durum: 'hata', mesaj: e?.message || String(e) };
    }
    if (sonuc?.durum === 'tamam' && gecerliGovde(sonuc.veri)) {
      await yaz(aday.anahtar, sonuc.veri);
      ozet.tazelendi++;
      // SÜRESİ DOLMUŞ İŞARET ÇÖZÜLDÜ: anahtar bir zamanlar 404'tü, artık VAR
      // (bölüm sonradan TMDB'ye eklendi). İşareti kaldır ki bir daha
      // beklemesin. Yalnız bu dalda — sıcak yolda fazladan DELETE yok.
      if (aday.yokEskimis) { await yokSil(aday.anahtar); ozet.yokCozuldu++; }
    } else if (sonuc?.durum === 'yok') {
      // TMDB 404: bu kayıt YOK. SATIRA DOKUNMA — 404/noindex kararı
      // server.js'in işi, ısıtıcı oraya karışmaz (3. karar). Ama "yok" bir
      // BİLGİDİR ve AYRI tabloya yazılır (7b): aksi hâlde satırsız anahtar
      // `yas = Infinity` ile her koşuda kuyruğun başına döner — canlıda
      // ölçülen sonsuz döngü tam olarak buydu.
      ozet.yok++;
      await yokYaz(aday.anahtar);
      ozet.yokYeni++;
    } else {
      // 5xx / timeout / beklenmedik gövde → ESKİ VERİ KALIR.
      ozet.hata++;
    }
  }
  ozet.sureMs = simdi() - baslangic;
  ozet.kuyruk = bayatToplam - ozet.istek;
  return ozet;
}

// ===========================================================================
// 9) TMDB ÇAĞRISI + YAZMA
// ===========================================================================
/** Tek anahtarı TMDB'den çeker. 404 → 'yok', diğer her sorun → 'hata'. */
export async function tmdbCek(anahtar, jeton, ayar = AYAR) {
  for (let deneme = 0; deneme < ayar.DENEME; deneme++) {
    let cevap;
    try {
      cevap = await fetch(`${TMDB}${anahtar}`, {
        headers: { Authorization: `Bearer ${jeton}` },
        signal: AbortSignal.timeout(ayar.ISTEK_ZAMAN_ASIMI_MS),
      });
    } catch (e) {
      if (deneme === ayar.DENEME - 1) return { durum: 'hata', mesaj: e?.name || 'ağ' };
      await new Promise((r) => setTimeout(r, 600 * (deneme + 1)));
      continue;
    }
    if (cevap.status === 429) {
      await new Promise((r) => setTimeout(r, 1500 * (deneme + 1)));
      continue;
    }
    if (cevap.status === 404) return { durum: 'yok' };
    if (!cevap.ok) {
      if (deneme === ayar.DENEME - 1) return { durum: 'hata', mesaj: `TMDB ${cevap.status}` };
      await new Promise((r) => setTimeout(r, 600 * (deneme + 1)));
      continue;
    }
    try {
      return { durum: 'tamam', veri: await cevap.json() };
    } catch {
      return { durum: 'hata', mesaj: 'gövde çözülemedi' };
    }
  }
  return { durum: 'hata', mesaj: 'deneme tükendi' };
}

/** server.js `tmdbGetir` ile AYNI upsert. */
export async function onbellegeYaz(havuz, anahtar, veri) {
  await havuz.query(
    `INSERT INTO tmdb_onbellek (anahtar, veri, guncelleme)
     VALUES ($1, $2, now())
     ON CONFLICT (anahtar) DO UPDATE SET veri = $2, guncelleme = now()`,
    [anahtar, veri],
  );
}

// ===========================================================================
// 10) ANA AKIŞ
// ===========================================================================
const sn = (ms) => (ms / 1000).toFixed(1);

/** Sınıf payları: `icerik:120 kisi:240 bolum:120` (açlık gözle görülür olsun). */
const sinifPaylari = (sayac) => Object.keys(sayac).sort()
  .map((k) => `${k}:${sayac[k]}`).join(',') || 'yok';

export function ozetSatiri(ozet, secim) {
  return [
    `ısıtıcı ${ozet.kuru ? 'KURU ÇALIŞMA' : 'koşusu'} bitti`,
    `bakılan=${ozet.bakilan}`,
    `zaten_taze=${ozet.taze}`,
    ozet.kuru ? `tazelenecek=${ozet.istek}` : `tazelendi=${ozet.tazelendi}`,
    `hata=${ozet.hata}`,
    `tmdb_404=${ozet.yok}`,
    // OLUMSUZ ÖNBELLEK GÖRÜNÜR OLMALI (7b): `yok_işareti` bu koşuda kaç
    // anahtarın "TMDB'de yok" diye İSTENMEDİĞİNİ, `yok_yeni` kaç yeni işaret
    // konduğunu, `yok_çözüldü` kaç anahtarın sonradan TMDB'ye eklendiğini
    // söyler. Bunlar basılmasaydı düzeltme sessizce bozulabilir ve döngü
    // "her şey normal" görünümü altında geri gelebilirdi.
    `yok_işareti=${ozet.yokIsareti}`,
    `yok_yeni=${ozet.yokYeni}`,
    `yok_çözüldü=${ozet.yokCozuldu}`,
    `atlanan=${ozet.atlanan}`,
    `${ozet.kuru ? 'planlanan_istek' : 'istek'}=${ozet.istek}`,
    // KUYRUK: sürekli kipin TEK ilerleme göstergesi (bkz. kosuYap).
    `kuyruk=${ozet.kuyruk}`,
    `bayat_toplam=${ozet.bayatToplam}`,
    `sınıf_payı=${sinifPaylari(ozet.sinifSayaci)}`,
    `süre=${sn(ozet.sureMs)}sn`,
    ozet.tavan ? `TAVAN=${ozet.tavan}` : 'tavan=yok',
    `diller=${secim.diller.join('+')}`,
  ].join(' ');
}

/**
 * Bu koşu günlüğe YAZMAYA değer mi?
 *
 * Kararlı durumda günde 144 koşu olacak ve çoğu hiçbir iş yapmayacak. O
 * koşuların "0 tazelendi" satırı hem log dosyasını şişirir hem GERÇEK bir
 * sorunu görünmez yapar. Sessizlik burada BİLGİDİR: "hiçbir şey bayat değil".
 * İş yapılan, hata alan ya da kuyruğu boşaltamayan koşu KONUŞUR.
 */
export function konusmaliMi(ozet) {
  return ozet.kuru || ozet.istek > 0 || ozet.hata > 0 || ozet.kuyruk > 0;
}

/** Kuyruğun bu kapasiteyle boşalma süresi (saat). */
export function bosalmaSaati(bayatToplam, gunluk) {
  if (!bayatToplam) return 0;
  if (!gunluk) return Infinity;
  return (bayatToplam / gunluk) * 24;
}

async function main(argv) {
  let secim;
  try {
    secim = bayraklariCoz(argv);
  } catch (e) {
    console.error(`isitici: ${e.message}`);
    process.exit(2);
  }
  // Sürekli kipin bağları TUTMUYORSA hiç başlama: bozuk ayarla sessizce
  // çalışan bir cron, bu betiğin en pahalı hata biçimidir.
  const sorunlar = bagAyarlariDogrula();
  if (sorunlar.length) {
    for (const s of sorunlar) console.error(`isitici: AYAR tutarsız — ${s}`);
    process.exit(2);
  }
  // Bayraklarla verilen süre cron aralığını aşarsa koşular üst üste biner.
  // Elle yetiştirme koşusu için MEŞRU, o yüzden hata değil UYARI.
  if (secim.azamiDakika >= AYAR.CRON_DAKIKA) {
    console.error(`isitici: UYARI — --azami-dakika=${secim.azamiDakika} cron `
      + `aralığından (${AYAR.CRON_DAKIKA} dk) küçük değil; sonraki koşu(lar) `
      + 'kilide takılıp boşa dönecek. Elle koşu için beklenen davranış.');
  }
  const { DATABASE_URL, TMDB_TOKEN } = process.env;
  if (!DATABASE_URL || !TMDB_TOKEN) {
    // Değerler DEĞİL, yalnız hangisinin eksik olduğu basılır.
    console.error('isitici: eksik ortam değişkeni (DATABASE_URL / TMDB_TOKEN)');
    process.exit(1);
  }
  const kaynak = fs.readFileSync(path.join(BURASI, 'server.js'), 'utf8');

  const havuz = new pg.Pool({
    connectionString: DATABASE_URL, max: 4, connectionTimeoutMillis: 5000,
  });
  // KİLİT: advisory lock OTURUM düzeyindedir, yani havuzdan gelen RASTGELE bir
  // bağlantıda alınamaz — koşu boyunca AYNI istemci elde tutulur.
  const istemci = await havuz.connect();
  let kilit = false;
  try {
    const { rows } = await istemci.query('SELECT pg_try_advisory_lock($1) AS alindi',
      [AYAR.KILIT_ANAHTARI]);
    kilit = rows[0].alindi === true;
    if (!kilit) {
      console.log('isitici: başka bir kopya çalışıyor (advisory lock alınamadı), çıkılıyor');
      return;
    }
    const adaylar = await adaylariTopla(havuz, secim, kaynak);
    const bayat = adaylar.filter((a) => !a.tazeMi);

    // OLUMSUZ ÖNBELLEK BUDAMASI (7b) — BOŞ KOŞU KAPISININ ÖNÜNDE.
    // NEDEN BURADA: kararlı durumda 404 işaretli adaylar `tazeMi = true`
    // sayılıyor, yani `bayat.length === 0` olan koşular OLAĞAN hale gelecek.
    // Budama kapının arkasında kalsaydı `tmdb_yok` tam da her şeyin yolunda
    // olduğu dönemde hiç budanmazdı. Boş koşunun SESSİZLİĞİ bozulmuyor:
    // silinecek satır yoksa hiçbir şey yazılmaz.
    // `tablolariBuda` bu tabloyu bilmiyor, bilerek: ısıtıcının tek sahibi
    // olduğu bir tabloyu iki yerden yönetmek, eşiklerin sessizce ayrışmasıdır.
    if (!secim.kuru) {
      const budanan = await yokIsaretleriniBuda(havuz);
      if (budanan) console.log(`isitici: ${budanan} eski 404 işareti budandı`);
    }

    // BOŞ KOŞU: TMDB'ye HİÇ dokunma, stdout'a HİÇBİR ŞEY yazma (5b maddesi).
    // Kuru koşu istisna: "kuyrukta ne var" sorusuna "hiçbir şey" da cevaptır.
    if (!bayat.length && !secim.kuru) return;

    const ozet = await kosuYap({
      adaylar,
      getir: (anahtar) => tmdbCek(anahtar, TMDB_TOKEN),
      yaz: (anahtar, veri) => onbellegeYaz(havuz, anahtar, veri),
      // OLUMSUZ ÖNBELLEK (7b) — kuru koşuda ZATEN yazılmıyor (`kosuYap` istek
      // döngüsünü `kuru` bayrağında kesiyor), o yüzden burada ayrıca
      // dallanmıyoruz: tek doğru yer o kapı.
      yokYaz: (anahtar) => yokIsaretiYaz(havuz, anahtar),
      yokSil: (anahtar) => yokIsaretiSil(havuz, anahtar),
      azamiIstek: secim.azamiIstek,
      azamiMs: secim.azamiDakika * 60000,
      istekSn: secim.istekSn,
      kuru: secim.kuru,
    });
    if (secim.kuru) {
      // KURU ÇALIŞMA artık "bir gecede ne yapılacak" değil, "ŞU AN KUYRUKTA
      // NE VAR" sorusunu cevaplıyor — sürekli kipte anlamlı olan soru bu.
      const gunluk = gunlukKapasite(secim);
      const sinifOzeti = {};
      for (const a of adaylar) {
        const s = (sinifOzeti[a.sinif] ||= { aday: 0, bayat: 0 });
        s.aday++;
        if (!a.tazeMi) s.bayat++;
      }
      console.log('isitici KURU ÇALIŞMA — kuyruk durumu');
      for (const ad of Object.keys(sinifOzeti).sort()) {
        const s = sinifOzeti[ad];
        console.log(`  sınıf ${ad.padEnd(7)} aday=${s.aday} bayat=${s.bayat}`);
      }
      console.log(`  bayat toplam      : ${ozet.bayatToplam}`);
      // OLUMSUZ ÖNBELLEK: kuru koşunun "kuyrukta ne var" cevabının parçası.
      // Bu satır olmadan 1.837 anahtarın NEREYE gittiği görünmez olurdu.
      const yo = adaylar.yokOzet;
      console.log(`  404 işaretli      : ${ozet.yokIsareti} (istenmeyecek, `
        + `${Math.round(AYAR.KATMAN.yok404 / (24 * 3600))} gün) `
        + `+ süresi dolmuş ${yo ? yo.eskimis : 0} (yeniden denenecek)`);
      console.log(`  bu koşuya sığar   : ${ozet.istek} `
        + `(tavan ${secim.azamiIstek} istek / ${secim.azamiDakika} dk / ${secim.istekSn}/sn)`);
      console.log(`  koşudan sonra kuyruk: ${ozet.kuyruk}`);
      console.log(`  günlük kapasite   : ${gunluk} istek `
        + `(${Math.floor(1440 / AYAR.CRON_DAKIKA)} koşu × ${AYAR.CRON_DAKIKA} dk)`);
      console.log(`  kuyruk bu hızla boşalır: `
        + `${bosalmaSaati(ozet.bayatToplam, gunluk).toFixed(1)} saat`);
      // ADAY KÜMESİ BÜYÜMESİ: kuru koşunun verdiği sayı SABİT DEĞİL. Kişi
      // adayları önbellekteki içerik satırlarından türüyor, yani içerik
      // önbelleği doldukça kuyruk BÜYÜR. 20 Ağu 2026'da kuru koşu 7.382 dedi,
      // iki saat sonra bayat_toplam 27.910'du — sebebi buydu, kontrolsüzlük
      // değil. Tavan: kapsanmayan içerik × OYUNCU_BAGLANTI × kişi dili.
      const b = adaylar.kisiBuyume;
      if (b && b.toplam) {
        const yuzde = ((b.dolu / b.toplam) * 100).toFixed(0);
        const kalan = Math.max(0, b.toplam - b.dolu);
        console.log(`  içerik önbelleği  : ${b.dolu}/${b.toplam} (%${yuzde}) dolu`);
        if (kalan) {
          console.log(`  UYARI: aday kümesi BÜYÜYECEK — kalan ${kalan} içerik `
            + `satırı ısındıkça en fazla `
            + `${kalan * AYAR.OYUNCU_BAGLANTI * sinifDilleri('kisi', secim).length} `
            + 'yeni kişi anahtarı doğabilir (tekilleşmeden önceki TAVAN).');
        }
      }
      for (const a of ozet.ornekler) console.log(`  örnek anahtar: ${a}`);
    }
    if (konusmaliMi(ozet)) console.log(ozetSatiri(ozet, secim));
  } finally {
    if (kilit) {
      await istemci.query('SELECT pg_advisory_unlock($1)', [AYAR.KILIT_ANAHTARI])
        .catch(() => {});
    }
    istemci.release();
    await havuz.end();
  }
}

// Test/import güvenliği: dosya DOĞRUDAN çalıştırıldığında main koşar, import
// edildiğinde koşmaz (server.js'in `app.listen` tuzağını tekrarlamıyoruz).
const dogrudan = process.argv[1]
  && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (dogrudan) {
  main(process.argv.slice(2)).catch((e) => {
    console.error('isitici: koşu hatası:', e?.message || e);
    process.exit(1);
  });
}
