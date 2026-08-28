// ===========================================================================
// SEARCH CONSOLE İZLEME — günlük ölçüm + anlamlı değişimde bildirim
// (21 Ağu 2026)
// ===========================================================================
//
// HANGİ ÖLÇÜLEN BOŞLUĞU KAPATIYOR
// SEO-YAPILACAKLAR §10 "Ölçüm ve gözden geçirme" tablosunda dört satır
// **haftalık, ELLE** yazıyor. Elle bakılan ölçüm bakılmaz: 19 Ağu ile 21 Ağu
// arasında "tarandı – eklenmedi" 30 → 121 oldu (4 kat) ve bunu ancak biri
// paneli açtığı için gördük. Google kritik olaylarda (manuel işlem, güvenlik,
// büyük indeks düşüşü) doğrulanmış sahibe zaten e-posta atıyor — EKSİK OLAN
// tam da bu eşiğin ALTINDA kalan, ama bizim için asıl sinyal olan sayılar.
//
// ---------------------------------------------------------------------------
// EN ÖNEMLİ GERÇEK: İSTEDİĞİMİZ DÖRT SAYI API'DE YOK
// ---------------------------------------------------------------------------
// Search Console API'sinin TAMAMI dört kaynaktan ibaret (doğrulandı:
// developers.google.com/webmaster-tools/v1/api_reference_index):
//     searchanalytics · sitemaps · sites · urlInspection
// "Sayfalar" (indeks kapsamı) raporunun TOPLAM sayıları — yani
//   · Dizine eklenen            264 → 330
//   · Keşfedildi – taranmadı  2.159 → 2.076
//   · Tarandı – eklenmedi        30 →   121
//   · Sunucu hatası (5xx)        32 →    32
// HİÇBİR UÇTA YOK. Manuel işlem, güvenlik sorunu, zengin sonuç geçerliliği ve
// CrUX de yok; onlar YALNIZCA arayüzde yaşıyor. Bu dosya o sayıları
// "çektiğini" İDDİA ETMEZ — ÖRNEKLEYEREK TAHMİN EDER ve tahmin olduğunu her
// raporda yazar. Ayrıntı ve gerekçe için aşağıdaki "ÜÇ ÖLÇÜM SINIFI".
//
// ---------------------------------------------------------------------------
// ÜÇ ÖLÇÜM SINIFI — hangi sayı ne kadar güvenilir
// ---------------------------------------------------------------------------
//  A) KESİN (örnekleme yok, sayım tam):
//     · `sitemaps.list` → `contents[].submitted` (bildirilen URL sayısı),
//       `lastDownloaded` (Google haritayı ne zaman indirdi), `errors`,
//       `warnings`, `isPending`.
//       ⚠ `contents[].indexed` alanı Google tarafından KULLANIMDAN KALDIRILDI
//       ("Deprecated; do not use") — bu dosya onu OKUMAZ. Okusaydık
//       "indekslenen" diye sıfır ya da çöp bir sayıyı rapor ederdik.
//     · `searchanalytics.query` → tıklama/gösterim ve `page` boyutuyla
//       GÖSTERİM ALMIŞ farklı sayfa sayısı. Bölüm sayfası ailesi için bu,
//       "sıfırdan çıktı mı" sorusunun TAM cevabıdır (gösterim ⇒ indeksli).
//
//  B) ÖRNEKLENMİŞ (tahmin + güven aralığı):
//     · `urlInspection.index.inspect` → URL BAŞINA durum. Kota: mülk başına
//       2.000 istek/gün, 600 istek/dk (developers.google.com/webmaster-tools/limits).
//       80.936 URL'in tamamını denetlemek 40 GÜN sürerdi; bu yüzden SABİT
//       PANEL ile örnekleniyor (bkz. "NEDEN SABİT PANEL").
//
//  C) HİÇ ALINAMAYAN (bu dosya bunları RAPOR ETMEZ, uydurmaz):
//     · İndeks kapsamı rapor toplamları, manuel işlem, güvenlik sorunu,
//       zengin sonuç (Geliştirmeler) geçerliliği, CrUX/Core Web Vitals,
//       "Yinelenen/kanonik" sayacı, kaldırma istekleri.
//     · Bunların hepsi arayüzde kalıyor. Manuel işlem ve güvenlik sorunu için
//       Google zaten sahibe e-posta atıyor — o kanal ZATEN çalışıyor, burada
//       ikinci kez çözülmeye çalışılmıyor.
//
// ---------------------------------------------------------------------------
// NEDEN SABİT PANEL (kohort), HER GÜN YENİ RASTGELE ÖRNEK DEĞİL
// ---------------------------------------------------------------------------
// Bu kararın tek gerekçesi ARİTMETİK, zevk değil.
//
// Her gün YENİ rastgele örnek (n=250, p≈0,107 — 264/2453):
//     SE(p)      = sqrt(0,107 × 0,893 / 250) = 1,95 puan
//     SE(fark)   = 1,95 × sqrt(2)            = 2,76 puan
//     %95 aralık = ±5,4 puan → 2.453 URL'e ölçeklenince **±133 URL**
// Yani 19→21 Ağu'da GERÇEKTEN olan değişimi (264 → 330, yani +66) günlük
// rastgele örnek GÖREMEZ: gerçek sinyal gürültünün YARISI kadar.
//
// SABİT PANEL aynı URL'leri her gün denetler, yani karşılaştırma EŞLEŞMİŞ
// olur. Örnekleme varyansı FARKTAN tamamen düşer; yalnız gerçekten durum
// değiştiren URL'ler paya girer. 250'lik panelde 5 URL yer değiştirirse
// belirsizlik ±2,8 URL (panelde) = ±27 URL (ölçeklenmiş) — rastgele örneğin
// yaklaşık BEŞTE BİRİ. Tam olarak aradığımız büyüklükteki değişimi görür.
//
// PANEL KENDİ KENDİNİ TAZELER: panel "sha1(url)'e göre sırala, ilk N'i al"
// kuralıyla TÜRETİLİR (`panelSec`), listeye elle yazılmaz. Site haritasına
// yeni URL girdiğinde panel yine tekdüze rastgele bir örnek olarak KALIR ve
// sabit boyutta kalır (kota tavanı korunur). Panelin ne kadar değiştiği her
// raporda `panel_degisim` olarak yazılır — büyük bir değişim, karşılaştırmayı
// zayıflatır ve GÖRÜNÜR olmalıdır.
//
// KATMANLI (stratified): tek bir küresel örnek 80.936 URL'in %97'si bölüm
// olduğu için 2.453 içerik sayfası hakkında neredeyse HİÇBİR ŞEY söylemezdi.
// Bu yüzden her aile (`icerik`, `bolum`, `genel`) AYRI panel ve AYRI tahmin.
//
// ---------------------------------------------------------------------------
// KOVA EŞLEMESİ NEDEN `coverageState` STRING'İNE BAKMIYOR
// ---------------------------------------------------------------------------
// API'nin `coverageState` alanı Google dokümanında `string` olarak tanımlı —
// ENUM DEĞİL. İçeriği hem YERELLEŞTİRİLMİŞ ("Keşfedildi – dizine eklenmedi")
// hem de Google'ın istediği zaman değiştirebileceği serbest metin. Alarm
// mantığını ona bağlasaydık, Google bir kelimeyi değiştirdiği gün izleme
// SESSİZCE her şeyi "bilinmiyor" kovasına atardı ve bunu kimse fark etmezdi.
//
// Bu yüzden kova KARARI yalnız KARARLI ENUM'lardan veriliyor (`kovaBelirle`):
// `robotsTxtState`, `indexingState`, `pageFetchState`, `verdict` ve
// `lastCrawlTime`in VARLIĞI. `coverageState` yine okunuyor ama SADECE insana
// gösterilen ham etiket olarak (rapordaki "Google'ın kendi etiketi" bloğu) —
// böylece eşlemenin arayüzle tutup tutmadığı gözle DOĞRULANABİLİR kalıyor.
//
// `lastCrawlTime` ayrımı kritik: dokümana göre alan "URL hiç başarıyla
// taranmadıysa YOK". "Keşfedildi–taranmadı" ile "Tarandı–eklenmedi" arasındaki
// farkı veren tek kararlı alan bu.
//
// ---------------------------------------------------------------------------
// SESSİZLİK DİSİPLİNİ — ısıtıcıdan öğrenilen ders
// ---------------------------------------------------------------------------
// `isitici.js` 5b maddesi: günde 144 "0 tazelendi" satırı gerçek bir sorunu
// GÖRÜNMEZ yapıyordu. Aynı hata burada daha pahalı olurdu — günlük değil
// E-POSTA. "Her şey aynı" maili üçüncü haftada okunmamaya başlar ve asıl
// uyarı tam o kutuda kaybolur.
//
//   · stdout'a HER koşuda TEK satır özet yazılır (cron günlüğü = kalp atışı).
//   · E-POSTA yalnız EŞİK AŞILDIĞINDA gider.
//   · İSTİSNA 1 — İLK KOŞU: temel ölçüm maili gider. Kullanıcı hem kurulumun
//     çalıştığını görür hem de kova eşlemesini GSC arayüzüyle karşılaştırıp
//     doğrulayabilir. Bir kez.
//   · İSTİSNA 2 — AYLIK ÖZET (`AYAR.OZET_GUN`): 30 koşu boyunca hiç bildirim
//     çıkmadıysa tam tablo yine de gider. Gerekçe DÜRÜST: bu işin içinden
//     "cron ölü" ile "hiçbir şey değişmedi" ayırt EDİLEMEZ; ikisi de sessizdir.
//     Yılda 12 posta yorgunluk yapmaz, ama üç hafta süren bir ölü boruyu
//     yakalar. Tam sessizlik istenirse `OZET_GUN = 0`.
//   · BEKLENEN DEĞİŞİM BİLDİRİLMEZ: site haritası 2.518 → 80.936 URL oldu
//     (bölüm sayfaları açıldı). `bolum` ailesinde "keşfedildi – taranmadı"
//     sayısının PATLAMASI önümüzdeki haftalarda NORMALDİR ve alarm DEĞİLDİR
//     (`AYAR.BEKLENEN_ARTIS`). Aynı kovanın DÜŞMESİ ise haberdir ve gider.
//
// KULLANIM
//   node gsc_izle.js                 (günlük koşu; cron çağırır)
//   node gsc_izle.js --kuru          (API'ye yazma yok, POSTA GÖNDERMEZ, tam
//                                     raporu stdout'a basar — eşik ayarlamak
//                                     ve kova eşlemesini gözle doğrulamak için)
//   node gsc_izle.js --zorla-posta   (eşik aşılmasa da postayı gönderir; tek
//                                     seferlik "boru çalışıyor mu" testi)
//   node gsc_izle.js --panel=60      (küçük panel; kurulumun ilk denemesi)
//
// ORTAM
//   GSC_SA_YOL      servis hesabı JSON yolu (varsayılan /app/gsc-servis-hesabi.json)
//   GSC_MULK        Search Console mülk kimliği (varsayılan sc-domain:dizijpg.com)
//   GSC_MAIL_ALICI  rapor alıcısı (varsayılan admin@dizijpg.com)
//   GSC_DURUM_YOL   durum dosyası (varsayılan /veri/gsc_izle_durum.json)
//   MAIL_HOST / MAIL_PORT / MAIL_FROM — server.js ile AYNI değişkenler
//
// GİZLİ DEĞER ASLA BASILMAZ: özel anahtar, erişim jetonu ve `Authorization`
// başlığı ne stdout'a ne postaya ne durum dosyasına yazılır. Hata mesajları
// jeton taşıyabildiği için `hatayiKisirlastir`dan geçer.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import pg from 'pg';
import jwt from 'jsonwebtoken';
import nodemailer from 'nodemailer';

// ===========================================================================
// AYARLAR — KOORDİNATÖR BURAYI AYARLAR, BAŞKA HİÇBİR YERİ
// ===========================================================================
export const AYAR = {
  /// Search Console mülk kimliği. HAFIZA: mülk `sc-domain` türünde.
  /// TUZAK: `sc-domain:dizijpg.com` ile `https://dizijpg.com/` AYRI mülktür.
  /// Yanlışını verirsen API 403 döner (veri değil, YETKİ hatası) — bu yüzden
  /// 403 mesajı ikisini de hatırlatıyor (`API_HATA_IPUCU`).
  MULK: 'sc-domain:dizijpg.com',

  /// `urlInspection` yanıtındaki `coverageState` metninin dili. Kova KARARI
  /// bu metne BAKMAZ (bkz. dosya başlığı); dil yalnız insana gösterilen ham
  /// etiketi GSC arayüzüyle aynı yapar — kullanıcı Console'u Türkçe kullanıyor
  /// ve raporu arayüzle karşılaştırabilmeli.
  DIL: 'tr-TR',

  /// Site haritası kökü (aile ayrımı ve panel bu haritadan türer).
  SITE_KOK: 'https://dizijpg.com',

  // -------------------------------------------------------------------
  // PANEL BÜYÜKLÜKLERİ — kota BÜTÇESİ ve DUYARLILIK arasındaki denge
  // -------------------------------------------------------------------
  // Kota: mülk başına 2.000 denetim/gün. Toplam panel 500 → kotanın %25'i.
  // Kalan %75 bilerek boş: elle denetim, ikinci bir koşu ve ileride panel
  // büyütme için yer. Kotayı doldurup 429 yemek, izlemenin kendisini
  // SESSİZCE durdurur.
  //
  // `icerik` 250 / 2.453 = %10,2 örnekleme. Eşleşmiş karşılaştırmada 5 URL'lik
  // bir kayma ±27 URL belirsizlikle görülür (dosya başlığındaki hesap).
  //
  // `bolum` 250 / 78.480 = %0,3 örnekleme. DÜRÜST OLALIM: bu panel, bölüm
  // ailesinde 300'den AZ sayfa taranmışsa büyük olasılıkla SIFIR görür
  // (beklenen isabet = 250 × 300/78.480 ≈ 0,96). Yani panel, taramanın İLK
  // günlerini göremez. Bu bir kusur değil aritmetik: %0,3 örnekle küçük bir
  // oranı ölçmek mümkün değil. Boşluğu KESİN ölçüm kapatıyor —
  // `searchanalytics` bölüm ailesinde gösterim alan sayfa sayısını ÖRNEKLEMEDEN
  // ve TAM verir, ve o sayı 0'dan çıktığı an "sıfır bariyeri" kuralıyla
  // eşiğe bakılmadan bildirilir. Raporda bu kör nokta AÇIKÇA yazılır.
  //
  // `genel` 3 URL → örnek değil SAYIM (tamamı denetlenir).
  PANEL: { icerik: 250, bolum: 250, genel: 25 },

  /// Denetim hızı (istek/sn). Tavan 600/dk = 10/sn; 3/sn ile 500 URL ≈ 2,8 dk.
  /// Tavana dayanmıyoruz: 429 yenilebilir bir hata değil, GÜNLÜK kotayı da
  /// yakan bir hata biçimi.
  DENETIM_SN: 3,

  /// Tek koşuda yapılabilecek EN ÇOK denetim (sert tavan). Panel ayarları
  /// yanlışlıkla büyütülse bile kota bu satırla korunur.
  AZAMI_DENETIM: 900,

  /// HTTP istek zaman aşımı (ms) ve yeniden deneme sayısı.
  ISTEK_ZAMAN_ASIMI_MS: 20000,
  DENEME: 3,

  // -------------------------------------------------------------------
  // ARAMA ANALİTİĞİ PENCERESİ
  // -------------------------------------------------------------------
  // GSC verisi gecikmeli gelir; en taze günler EKSİK olur ve "düşüş" gibi
  // görünür. `dataState` varsayılanı `final` (yalnız kesinleşmiş veri) ve
  // pencere 3 gün geriden başlar. 7 günlük pencere gün gün %86 örtüşür, yani
  // günlük değişim yumuşak; tek günlük pencere hafta içi/sonu dalgasıyla
  // sürekli alarm üretirdi.
  ARAMA_GECIKME_GUN: 3,
  ARAMA_PENCERE_GUN: 7,

  // -------------------------------------------------------------------
  // EŞİKLER — NEDEN SABİT SAYI DEĞİL
  // -------------------------------------------------------------------
  // Site haritası 32 KAT büyüdü (2.518 → 80.936). "100'den fazla değişirse
  // bildir" gibi bir eşik, 2.453 URL'lik içerik ailesinde ASLA ateşlemez
  // (264 → 330 = +66 kaçar) ama 78.480 URL'lik bölüm ailesinde HER GÜN
  // ateşler. Tek bir sabit sayı iki aileye birden doğru gelemez.
  //
  // Bu yüzden eşik, ölçümü ÜRETEN yönteme göre belirleniyor:
  //   · ÖRNEKLENMİŞ sayılar → İSTATİSTİKSEL ANLAMLILIK (`anlamliMi`).
  //     Eşleşmiş panelde "kovaya giren" ile "kovadan çıkan" URL sayıları
  //     b ve c ise, değişim yoksa (b−c) ~ 0 ortalamalı, sqrt(b+c) standart
  //     sapmalı dağılır (McNemar normal yaklaşımı). Eşik 2σ + bir taban.
  //     Yani eşik, aile büyüklüğüne göre KENDİ ayarlanır.
  //   · KESİN sayılar → görece eşik (yüzde) VE mutlak taban, hangisi büyükse.
  //   · SIFIR BARİYERİ → 0'dan çıkmak ya da 0'a düşmek HER ZAMAN bildirilir,
  //     büyüklüğüne bakılmaksızın. Kullanıcının asıl sorduğu soru bu.
  //   · DEĞİŞMEZ İHLALİ → eşik YOK, tek örnek bile bildirilir (aşağıda).
  ESIK: {
    /// Örneklenmiş kovalarda anlamlılık katsayısı (σ) ve mutlak taban.
    /// TABAN neden 3: 1-2 URL'lik oynama, Google'ın olağan yeniden
    /// değerlendirmesidir; her gün posta üretirdi.
    SIGMA: 2,
    FLIP_TABAN: 3,

    /// Kesin sayılar: |Δ| ≥ max(MUTLAK, ORAN × önceki) ise bildir.
    HARITA_ORAN: 0.05,
    HARITA_MUTLAK: 500,
    GOSTERIM_ORAN: 0.30,
    GOSTERIM_MUTLAK: 25,

    /// DEĞİŞMEZ İHLALLERİ — eşiksiz.
    /// `robots` ve `noindex` TABANI 1: bunlar Google'ın kararı değil BİZİM
    /// kodumuzun ürünü. SEO-YAPILACAKLAR §8.6 "sitemap kapsamı =
    /// ozgunIcerikVar(); sitemap'te olup noindex yiyen sayfa ÜRETİLEMEZ"
    /// diyor. Panelde tek bir tane çıkması o değişmezin KIRILDIĞI anlamına
    /// gelir ve %0,3 örnekle bir tane görmek, ailede yüzlercesi var demektir.
    IHLAL_TABAN: 1,
    /// 404 / yumuşak-404 TABANI 2: bunlar bizim hatamız OLMADAN da oluşabilir
    /// (harita üretimi ile denetim arasında TMDB'den kayıt düşerse). Tek
    /// örnek gürültü olabilir, iki örnek desendir. §1'de yumuşak 404 = 0
    /// olarak ölçülmüştü; oradan sapma haberdir.
    DORT04_TABAN: 2,

    /// Denetim çağrılarının en çok yüzde kaçı başarısız olabilir. Üstü,
    /// yetki/kota arızası demektir ve KENDİSİ bildirilir — yoksa izleme
    /// bozulur ve "değişim yok" gibi görünür.
    DENETIM_HATA_ORANI: 0.2,

    /// Önceki koşunun üstünden bu kadar gün geçtiyse "izleme durmuştu"
    /// olarak bildirilir (cron ölmüş ve geri gelmiş).
    ARA_UYARI_GUN: 3,

    /// Site haritasını Google bu kadar gündür indirmediyse bildir.
    HARITA_BAYAT_GUN: 7,
  },

  /// BEKLENEN ARTIŞLAR — bildirilmez (yalnız günlüğe yazılır). AZALIŞLARI
  /// bildirilir, çünkü kuyruğun boşalması SEO-YAPILACAKLAR §0.1'in
  /// "bir sonraki gözden geçirme" ölçütüdür.
  ///
  /// Site haritası 21 Ağu'da 2.518 → 80.936 oldu. Google 78 bin yeni URL'i
  /// önce KEŞFEDER, taraması aylar alır. Bu kovanın büyümesi ARIZA DEĞİL,
  /// tasarımın beklenen sonucudur; alarm sayarsak izleme daha ilk haftada
  /// güvenilirliğini kaybeder.
  BEKLENEN_ARTIS: [{ sinif: 'bolum', kova: 'kesfedildi_taranmadi' }],

  /// Hiç bildirim çıkmadan geçen koşu sayısı bunu aşarsa TAM tablo yine de
  /// gönderilir ("boru canlı mı" kanıtı). 0 = tamamen sessiz.
  OZET_GUN: 30,

  /// Durum dosyası biçim sürümü. Biçim değişirse eski dosya YOK SAYILIR
  /// (karşılaştırma yapılmaz, yeni temel yazılır) — yarı uyumlu bir dosyayı
  /// karşılaştırmak sahte "değişim" üretirdi.
  DURUM_SURUM: 1,
};

const BURASI = path.dirname(fileURLToPath(import.meta.url));
const GSC_KOK = 'https://www.googleapis.com/webmasters/v3';
const DENETIM_UCU = 'https://searchconsole.googleapis.com/v1/urlInspection/index:inspect';
const JETON_KAPSAMI = 'https://www.googleapis.com/auth/webmasters.readonly';

/// 403 neredeyse HER ZAMAN bu iki şeyden biri. Mesaja gömülü olmazsa
/// kullanıcı "API bozuk" sanır ve kurulumu baştan yapar.
const API_HATA_IPUCU = 'Servis hesabı e-postası Search Console mülküne '
  + 'eklenmemiş olabilir (Ayarlar → Kullanıcılar ve izinler → Kullanıcı ekle '
  + '→ Mülk sahibi), ya da GSC_MULK yanlış: `sc-domain:dizijpg.com` ile '
  + '`https://dizijpg.com/` AYRI mülktür.';

// ===========================================================================
// 0) GİZLİ DEĞER SIZDIRMAMA
// ===========================================================================
/**
 * Hata metninden jeton/anahtar benzeri dizileri siler.
 *
 * NEDEN: bu betiğin hata mesajları cron günlüğüne VE e-postaya gidiyor.
 * `fetch` hataları bazen istek başlıklarını, Google hata gövdeleri bazen
 * jetonun bir bölümünü taşır. Bir kez sızan jeton, mülkün TÜM verisine
 * salt-okunur erişim demektir.
 */
export function hatayiKisirlastir(metin) {
  return String(metin ?? '')
    .replace(/-----BEGIN[\s\S]*?-----END[^-]*-----/g, '«özel anahtar»')
    .replace(/\bya29\.[\w.\-]+/g, '«jeton»')
    .replace(/(Bearer\s+)[\w.\-]+/gi, '$1«jeton»')
    .replace(/("(?:access_token|private_key|assertion)"\s*:\s*")[^"]*/g, '$1«gizli»')
    .slice(0, 2000);
}

// ===========================================================================
// 1) KİMLİK — SERVİS HESABI (OAuth DEĞİL)
// ===========================================================================
// KARAR VE GEREKÇE (bu iş SUNUCUDA, BAŞSIZ, HER GÜN çalışacak):
//
//  · OAuth kullanıcı akışı tarayıcı ister. Bir kez alınıp saklanan yenileme
//    jetonu da çözüm DEĞİL: uygulama Google Cloud'da "Test" yayın durumundaysa
//    yenileme jetonu 7 GÜNDE bir geçersizleşir. İzleme her hafta sessizce
//    ölür ve bunu ancak "hiç posta gelmiyor" diye fark ederiz — yani tam da
//    sessizlik disiplininin kör noktasında. "Üretim"e geçirmek ise doğrulama
//    süreci gerektirir.
//  · Servis hesabı anahtarının SÜRESİ YOKTUR, tarayıcı istemez, etkileşim
//    istemez. Başsız günlük iş için doğru olan bu.
//  · KARAR EDİCİ ARGÜMAN: bu kalıp PROJEDE ZATEN VAR. `firebase-admin.json`
//    da bir Google servis hesabı anahtarıdır; depoda değil, konteynere
//    `:ro` bağlanıyor (docker-compose.yml) ve `FIREBASE_SA_YOL` ile okunuyor.
//    Aynı kalıbı ikinci kez kurmak yeni bir işletim hikâyesi doğurmaz.
//
// RİSK VE AZALTMA: servis hesabı anahtarı uzun ömürlü bir sırdır.
//   · Kapsam SALT-OKUNUR (`webmasters.readonly`) — bu jetonla site haritası
//     silinemez, mülk eklenemez.
//   · Dosya depoya GİRMEZ (kurulum adımlarında `firebase-gizli/` altına
//     konuyor; kök .gitignore o dizini zaten dışlıyor).
//   · Sunucuda `:ro` bağlanır, imaja KOPYALANMAZ.
//   · İçeriği hiçbir yere basılmaz (`hatayiKisirlastir` + aşağıdaki alan
//     denetimi yalnız EKSİK ALAN ADINI söyler, DEĞERİ değil).
//
// NEDEN `googleapis` PAKETİ EKLENMEDİ: JWT imzası için gereken tek şey RS256,
// ve `jsonwebtoken` ZATEN bağımlılıkta (package.json). `googleapis` onlarca
// megabaytlık bir bağımlılık ağacı getirirdi; güvenlik denetiminin
// (2026-08-17 §4.8) `npm ci` + kilit disiplinine karşılıksız yüzey eklemek
// olurdu. İhtiyaç duyulan akış 30 satır: JWT üret → jeton al → çağır.

/**
 * Servis hesabı JSON'unu okur ve doğrular.
 *
 * KİMLİK YOKSA ÇÖKMEZ: `{ hazir: false, sebep }` döner. Çağıran buna göre
 * anlaşılır bir mesajla ve DOĞRU çıkış koduyla iner (bkz. `main`).
 */
export function servisHesabiOku(yol) {
  let ham;
  try {
    ham = fs.readFileSync(yol, 'utf8');
  } catch (e) {
    const sebep = e?.code === 'ENOENT'
      ? `servis hesabı anahtarı yok: ${yol}`
      : `servis hesabı anahtarı okunamadı (${yol}): ${e?.code || e?.message}`;
    return { hazir: false, sebep };
  }
  let j;
  try {
    j = JSON.parse(ham);
  } catch {
    return { hazir: false, sebep: `servis hesabı anahtarı geçerli JSON değil: ${yol}` };
  }
  // YALNIZ EKSİK ALANIN ADI basılır, değeri ASLA.
  const eksik = ['client_email', 'private_key'].filter((a) => !j[a]);
  if (eksik.length) {
    return {
      hazir: false,
      sebep: `servis hesabı anahtarında eksik alan: ${eksik.join(', ')} (${yol}). `
        + 'Google Cloud → Hizmet Hesapları → Anahtarlar → JSON ile indirilen '
        + 'dosyanın TAMAMI kopyalanmalı.',
    };
  }
  if (j.type && j.type !== 'service_account') {
    return {
      hazir: false,
      sebep: `bu dosya bir servis hesabı anahtarı değil (type=${j.type}). `
        + 'OAuth istemci kimliği indirilmiş olabilir — gereken "Hizmet hesabı" anahtarı.',
    };
  }
  return {
    hazir: true,
    eposta: j.client_email,
    anahtar: j.private_key,
    jetonUcu: j.token_uri || 'https://oauth2.googleapis.com/token',
  };
}

/**
 * İki bacaklı (2LO) JWT akışı: imzalı iddia → erişim jetonu.
 * Jeton 1 saat yaşar; koşu birkaç dakika sürdüğü için yenileme gerekmiyor.
 */
export function iddiaUret(hesap, simdiSn = Math.floor(Date.now() / 1000), kapsam = JETON_KAPSAMI) {
  return jwt.sign(
    {
      iss: hesap.eposta,
      scope: kapsam,
      aud: hesap.jetonUcu,
      iat: simdiSn,
      exp: simdiSn + 3600,
    },
    hesap.anahtar,
    { algorithm: 'RS256' },
  );
}

export async function erisimJetonu(hesap, getirici = fetch) {
  const govde = new URLSearchParams({
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion: iddiaUret(hesap),
  });
  const cevap = await getirici(hesap.jetonUcu, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: govde.toString(),
    signal: AbortSignal.timeout(AYAR.ISTEK_ZAMAN_ASIMI_MS),
  });
  const metin = await cevap.text();
  if (!cevap.ok) {
    // `invalid_grant` neredeyse her zaman saat kayması ya da bozuk anahtar.
    throw new Error(`jeton alınamadı (HTTP ${cevap.status}): `
      + `${hatayiKisirlastir(metin)}. Sunucu saati yanlışsa (>5 dk kayma) `
      + 'Google imzayı reddeder — `timedatectl` ile bak.');
  }
  const j = JSON.parse(metin);
  if (!j.access_token) throw new Error('jeton yanıtında access_token yok');
  return j.access_token;
}

// ===========================================================================
// 2) API ÇAĞRISI
// ===========================================================================
/**
 * Google API çağrısı. 429/5xx'te geri çekilerek yeniden dener; 4xx'te DENEMEZ
 * (yetki hatasını 3 kez tekrarlamak yalnız kotayı yakar).
 */
export async function apiCagir(url, secenek, jeton, ayar = AYAR, getirici = fetch) {
  let sonHata = 'bilinmiyor';
  for (let deneme = 0; deneme < ayar.DENEME; deneme++) {
    let cevap;
    try {
      cevap = await getirici(url, {
        ...secenek,
        headers: {
          ...(secenek.headers || {}),
          Authorization: `Bearer ${jeton}`,
          'Content-Type': 'application/json',
        },
        signal: AbortSignal.timeout(ayar.ISTEK_ZAMAN_ASIMI_MS),
      });
    } catch (e) {
      sonHata = `ağ: ${e?.name || e?.message}`;
      if (deneme === ayar.DENEME - 1) break;
      await bekle(800 * (deneme + 1));
      continue;
    }
    if (cevap.ok) {
      try {
        return { tamam: true, veri: await cevap.json() };
      } catch (e) {
        return { tamam: false, kod: cevap.status, hata: `gövde çözülemedi: ${e?.message}` };
      }
    }
    const govde = hatayiKisirlastir(await cevap.text().catch(() => ''));
    // 404: bu URL Google'ın indeksinde YOK — denetim ucunda GEÇERLİ bir yanıt
    // değil, gerçek bir hata. Ama tekrar denemenin anlamı yok.
    if (cevap.status === 403 || cevap.status === 401) {
      return { tamam: false, kod: cevap.status, hata: `${govde} — ${API_HATA_IPUCU}` };
    }
    if (cevap.status === 429) {
      // Kota. Yeniden denemek kotayı DAHA ÇOK yakar; hemen bırak.
      return {
        tamam: false,
        kod: 429,
        hata: `kota aşıldı: ${govde}. Mülk başına denetim kotası 2.000/gün, `
          + '600/dk. AYAR.PANEL toplamı düşürülmeli ya da başka bir iş aynı '
          + 'mülkte denetim yapıyor olmalı.',
      };
    }
    sonHata = `HTTP ${cevap.status}: ${govde}`;
    if (cevap.status < 500) return { tamam: false, kod: cevap.status, hata: sonHata };
    if (deneme === ayar.DENEME - 1) break;
    await bekle(800 * (deneme + 1));
  }
  return { tamam: false, kod: 0, hata: sonHata };
}

const bekle = (ms) => new Promise((r) => setTimeout(r, ms));

/** `sc-domain:dizijpg.com` → yol parçası olarak kaçışlanmış hâli. */
export const mulkYolu = (mulk) => encodeURIComponent(mulk);

/** A-SINIFI KESİN ÖLÇÜM: bildirilen site haritaları. */
export async function siteHaritalari(mulk, jeton, ayar = AYAR, getirici = fetch) {
  const s = await apiCagir(`${GSC_KOK}/sites/${mulkYolu(mulk)}/sitemaps`,
    { method: 'GET' }, jeton, ayar, getirici);
  if (!s.tamam) return { tamam: false, hata: s.hata };
  const parcalar = {};
  let toplam = 0;
  for (const h of s.veri.sitemap || []) {
    // `contents[].indexed` BİLEREK OKUNMUYOR — Google onu kullanımdan
    // kaldırdı ("Deprecated; do not use"). Okusaydık "indekslenen" diye
    // güvenilmez bir sayı rapor ederdik; bu dosyanın tüm amacına aykırı.
    const gonderilen = (h.contents || [])
      .reduce((t, c) => t + Number(c.submitted || 0), 0);
    parcalar[kisaAd(h.path)] = {
      gonderilen,
      sonIndirme: h.lastDownloaded || null,
      sonGonderim: h.lastSubmitted || null,
      hata: Number(h.errors || 0),
      uyari: Number(h.warnings || 0),
      bekliyor: h.isPending === true,
      dizin: h.isSitemapsIndex === true,
    };
    // Dizin dosyasının kendi `submitted`'ı çocuklarıyla ÇAKIŞIR; toplama
    // yalnız yaprak haritalar girer, yoksa her URL iki kez sayılır.
    if (h.isSitemapsIndex !== true) toplam += gonderilen;
  }
  return { tamam: true, toplam, parcalar };
}

const kisaAd = (u) => String(u || '').split('/').pop() || String(u || '');

/**
 * A-SINIFI KESİN ÖLÇÜM: arama analitiği.
 * `page` boyutuyla GÖSTERİM ALMIŞ her sayfa döner — örnekleme YOK.
 */
export async function aramaAnalitigi(mulk, jeton, pencere, ayar = AYAR, getirici = fetch) {
  const url = `${GSC_KOK}/sites/${mulkYolu(mulk)}/searchAnalytics/query`;
  const satirlar = [];
  const SAYFA = 25000;                       // API tavanı
  for (let bas = 0; bas < 100000; bas += SAYFA) {
    const s = await apiCagir(url, {
      method: 'POST',
      body: JSON.stringify({
        startDate: pencere.bas,
        endDate: pencere.son,
        dimensions: ['page'],
        type: 'web',
        rowLimit: SAYFA,
        startRow: bas,
        // `dataState` verilmiyor → varsayılan `final`. `all` taze ama
        // KESİNLEŞMEMİŞ veri katar; ertesi gün yukarı düzeltilir ve sahte
        // "düşüş" alarmı üretirdi.
      }),
    }, jeton, ayar, getirici);
    if (!s.tamam) return { tamam: false, hata: s.hata };
    const r = s.veri.rows || [];
    satirlar.push(...r);
    if (r.length < SAYFA) break;
  }
  const ozet = { tiklama: 0, gosterim: 0, sayfa: {}, pencere };
  for (const ad of Object.keys(AYAR_AILE)) ozet.sayfa[ad] = 0;
  for (const r of satirlar) {
    ozet.tiklama += Number(r.clicks || 0);
    ozet.gosterim += Number(r.impressions || 0);
    ozet.sayfa[siniflandir(r.keys?.[0] || '')] += 1;
  }
  // Aynı yanıttan KAZANANLARI da süz: satırlar zaten elimizde, ikinci bir
  // API çağrısı YOK (gerekçe `kazananlariCoz` başlığında).
  return {
    tamam: true, ...ozet, satirSayisi: satirlar.length,
    kazananlar: kazananlariCoz(satirlar),
  };
}

// ===========================================================================
// KAZANAN BÖLÜMLER — site haritası kesme kuralının MUAFİYET listesi
// ===========================================================================
// NEDEN VAR (28 Ağu 2026, ölçümle bulundu):
// Bölüm site haritası bilinçli olarak kesiliyor (`SITEMAP_BOLUM_SORGU`):
// bir bölüm haritaya ancak dizi TR yapımıysa, sezon gelecek sezonsa YA DA
// `seo_kazanan_bolum` tablosundaysa girer. Amaç 78 binlik kuyruğu şişirmemek.
//
// Ama o tablo 27 Ağu'da ELLE dolduruldu (6 satır) ve ertesi gün BAYATLADI:
// GSC 9 tıklamadan 42'ye çıktı, tıklama alan üç bölüm — /dizi/61175/sezon/3/
// bolum/19, /dizi/67667/sezon/4/bolum/4, /dizi/68073/sezon/5/bolum/22 —
// haritada YOKTU. Yani kesme kuralı, kazanan sayfaları yeniden öksüz
// bırakmıştı. Elle tutulan muafiyet listesi tanımı gereği bayatlar.
//
// ÇÖZÜM: liste artık her gece GSC'nin KENDİ verisinden üretiliyor. Fazladan
// API çağrısı yok — `aramaAnalitigi` zaten TÜM sayfaları tıklama/gösterimle
// çekiyordu ve satırları atıyordu.
//
// EŞİK 1 TIKLAMA: "ölçülmüş performans" tanımı bu. Gösterim yetmez (32
// gösterim/0 tıklama alan sayfalar var); tıklama, sayfanın arama sonucunda
// gerçekten iş gördüğünün kanıtı. Tablo tanımı gereği küçük kalır.
export const KAZANAN_YOL = /\/dizi\/(\d+)\/sezon\/(\d+)\/bolum\/(\d+)\/?$/;
export const KAZANAN_MIN_TIKLAMA = 1;

/** GSC satırlarından bölüm kazananları. Saf: ağ/DB yok, test doğrudan çağırır. */
export function kazananlariCoz(satirlar, esik = KAZANAN_MIN_TIKLAMA) {
  const harita = new Map();
  for (const r of satirlar || []) {
    const tiklama = Number(r?.clicks || 0);
    if (tiklama < esik) continue;
    const m = KAZANAN_YOL.exec(String(r?.keys?.[0] || ''));
    if (!m) continue;
    const kayit = {
      tmdbId: Number(m[1]),
      sezon: Number(m[2]),
      bolum: Number(m[3]),
      tiklama,
      gosterim: Number(r?.impressions || 0),
    };
    if (!Number.isInteger(kayit.tmdbId) || kayit.tmdbId <= 0) continue;
    if (!Number.isInteger(kayit.sezon) || kayit.sezon < 1) continue;
    if (!Number.isInteger(kayit.bolum) || kayit.bolum < 1) continue;
    // Aynı bölüm birden çok satırda gelirse (http/https, sondaki eğik çizgi)
    // TIKLAMALAR TOPLANIR: aynı sayfanın iki yazımı iki kazanan değildir.
    const anahtar = `${kayit.tmdbId}:${kayit.sezon}:${kayit.bolum}`;
    const eski = harita.get(anahtar);
    if (eski) {
      eski.tiklama += kayit.tiklama;
      eski.gosterim += kayit.gosterim;
    } else {
      harita.set(anahtar, kayit);
    }
  }
  return [...harita.values()].sort((a, b) => b.tiklama - a.tiklama);
}

/**
 * Kazananları tabloya yazar (upsert).
 *
 * SİLME YOK — BİLİNÇLİ: bir bölüm 28 günlük pencereden düşerse satırı
 * kalmalı. Sayfa aramada bir kez iş gördüyse haritadan atılması onu yeniden
 * öksüz bırakır; tablo zaten küçük ve `SITEMAP_BOLUM_SORGU` içerik ölçüsünü
 * bu dalda da arıyor (içeriksiz bölüm bu tablodayken bile haritaya giremez).
 */
export async function kazananlariYaz(havuz, kazananlar, gun) {
  if (!kazananlar?.length) return { yazildi: 0, yeni: 0 };
  const oncekiler = await havuz.query('SELECT tmdb_id, sezon, bolum FROM seo_kazanan_bolum');
  const vardi = new Set(oncekiler.rows.map((r) => `${r.tmdb_id}:${r.sezon}:${r.bolum}`));
  let yeni = 0;
  for (const k of kazananlar) {
    if (!vardi.has(`${k.tmdbId}:${k.sezon}:${k.bolum}`)) yeni += 1;
    await havuz.query(
      `INSERT INTO seo_kazanan_bolum
         (tmdb_id, sezon, bolum, kaynak, tiklama, gosterim, olcum_gunu)
       VALUES ($1, $2, $3, 'gsc', $4, $5, $6)
       ON CONFLICT (tmdb_id, sezon, bolum) DO UPDATE
         SET tiklama = EXCLUDED.tiklama,
             gosterim = EXCLUDED.gosterim,
             olcum_gunu = EXCLUDED.olcum_gunu,
             guncellendi = now()`,
      [k.tmdbId, k.sezon, k.bolum, k.tiklama, k.gosterim, gun],
    );
  }
  return { yazildi: kazananlar.length, yeni };
}

/** B-SINIFI ÖRNEKLENMİŞ ÖLÇÜM: tek URL denetimi. */
export async function urlDenetle(mulk, url, jeton, ayar = AYAR, getirici = fetch) {
  const s = await apiCagir(DENETIM_UCU, {
    method: 'POST',
    body: JSON.stringify({ inspectionUrl: url, siteUrl: mulk, languageCode: ayar.DIL }),
  }, jeton, ayar, getirici);
  if (!s.tamam) return { tamam: false, kod: s.kod, hata: s.hata };
  return { tamam: true, sonuc: s.veri?.inspectionResult?.indexStatusResult || {} };
}

// ===========================================================================
// 3) AİLE (KATMAN) AYRIMI
// ===========================================================================
// Her aile AYRI panel ve AYRI eşik alır. Sebep §1'de ölçüldü: gösterim alan
// 37 sayfanın %100'ü `/icerik/*`. Bölüm ailesi bambaşka bir evrede; ikisini
// tek sayıda toplamak, ikisini de görünmez yapardı.
export const AYAR_AILE = {
  icerik: /^\/icerik\/(tv|movie)\/\d+/,
  bolum: /^\/dizi\/\d+\/sezon\/\d+\/bolum\/\d+/,
  genel: /^\/(|gozat|kesfet|kisi\/\d+|sirket\/\d+|listeler\/\d+|gonderi\/\d+)$/,
};

/** URL → aile adı. Eşleşmeyen her şey `genel` sayılır (kova kaybolmasın). */
export function siniflandir(url) {
  let yol;
  try {
    yol = new URL(url).pathname.replace(/\/+$/, '') || '/';
  } catch {
    return 'genel';
  }
  if (AYAR_AILE.icerik.test(yol)) return 'icerik';
  if (AYAR_AILE.bolum.test(yol)) return 'bolum';
  return 'genel';
}

/**
 * KÜME ANAHTARI — istatistiksel anlamlılık için.
 *
 * NEDEN GEREKLİ: bir dizinin 300 bölüm sayfası BAĞIMSIZ değildir. Googlebot
 * o diziye girdiğinde onlarcası birden durum değiştirir. Anlamlılığı URL
 * sayısıyla ölçseydik, tek bir dizinin taranması "300 bağımsız kanıt" gibi
 * görünür ve eşiği sahte biçimde aşardı. Bölüm ailesinde ayrışma DİZİ
 * düzeyinde sayılıyor; içerik ailesinde her URL zaten kendi kümesi.
 */
export function kumeAnahtari(url) {
  const e = /^https?:\/\/[^/]+(\/dizi\/\d+)\//.exec(url);
  return e ? e[1] : url;
}

// ===========================================================================
// 4) SİTE HARİTASI OKUMA + PANEL SEÇİMİ
// ===========================================================================
/** `<loc>` değerlerini çeker. Tam XML ayrıştırıcı gerekmez (harita düz). */
export function locCoz(xml) {
  const cikti = [];
  const im = /<loc>\s*([^<\s]+)\s*<\/loc>/g;
  let e;
  while ((e = im.exec(xml)) !== null) cikti.push(e[1]);
  return cikti;
}

/** Site haritası dizinini ve alt haritaları indirir; tüm URL'leri döner. */
export async function haritaUrlleri(kok, getirici = fetch, ayar = AYAR) {
  const indir = async (u) => {
    const c = await getirici(u, { signal: AbortSignal.timeout(ayar.ISTEK_ZAMAN_ASIMI_MS) });
    if (!c.ok) throw new Error(`${u} → HTTP ${c.status}`);
    return c.text();
  };
  const dizin = locCoz(await indir(`${kok}/sitemap.xml`));
  // Dizin ile yaprakları ayırmak için `sitemap-` öneki YETMEZ: dizinin kendisi
  // de öyle. Dizinin döndürdüğü her `loc` bir ALT HARİTADIR, tanım gereği.
  const urller = [];
  for (const alt of dizin) urller.push(...locCoz(await indir(alt)));
  return { urller, altHarita: dizin.map(kisaAd) };
}

/**
 * PANEL SEÇİMİ — sha1(url)'e göre sıralayıp ilk N.
 *
 * NEDEN BU KURAL:
 *  · TEKDÜZE: sha1 çıktısı düzgün dağıldığı için ilk N, tekdüze rastgele bir
 *    örnektir. `%` (modulo) ile seçseydik panel boyutu evrenle BİRLİKTE
 *    büyürdü ve 80 bin URL'de kotayı aşardı.
 *  · SABİT: aynı URL kümesi her gün aynı paneli verir → eşleşmiş karşılaştırma.
 *  · KENDİ KENDİNİ TAZELER: haritaya yeni URL girince panel yine tekdüze
 *    kalır; yalnız evrenin büyüme oranı kadar değişim olur.
 *
 * `onceki` verilirse (harita indirilemediğinde) panel oradan kurtarılır:
 * dünkü paneli denetlemek, hiç denetlememekten iyidir ve eşleşmeyi korur.
 */
export function panelSec(urller, boy, oncekiUrller = null) {
  if (!urller.length && oncekiUrller?.length) return [...oncekiUrller].slice(0, boy);
  return urller
    .map((u) => ({ u, h: crypto.createHash('sha1').update(u).digest('hex') }))
    .sort((a, b) => (a.h < b.h ? -1 : a.h > b.h ? 1 : 0))
    .slice(0, boy)
    .map((x) => x.u);
}

/** Aileleri ayırıp her birine kendi panelini kurar. */
export function panelleriKur(urller, oncekiPanel = {}, ayar = AYAR) {
  const aile = { icerik: [], bolum: [], genel: [] };
  for (const u of urller) aile[siniflandir(u)].push(u);
  const panel = {};
  for (const ad of Object.keys(ayar.PANEL)) {
    panel[ad] = panelSec(aile[ad] || [], ayar.PANEL[ad],
      oncekiPanel[ad] ? Object.keys(oncekiPanel[ad]) : null);
  }
  return { panel, evren: { icerik: aile.icerik.length, bolum: aile.bolum.length, genel: aile.genel.length } };
}

// ===========================================================================
// 5) KOVA EŞLEMESİ — YALNIZ KARARLI ENUM'LARDAN
// ===========================================================================
export const KOVA = {
  ROBOTS_ENGELLI: 'robots_engelli',
  NOINDEX: 'noindex',
  SUNUCU_HATASI: 'sunucu_hatasi',
  BULUNAMADI: 'bulunamadi',
  YUMUSAK_404: 'yumusak_404',
  DIZINE_EKLENDI: 'dizine_eklendi',
  TARANDI_EKLENMEDI: 'tarandi_eklenmedi',
  KESFEDILDI_TARANMADI: 'kesfedildi_taranmadi',
  BILINMIYOR: 'bilinmiyor',
};

/// Raporda bu sırayla gösterilir (kritikten olağana).
export const KOVA_SIRA = [
  KOVA.ROBOTS_ENGELLI, KOVA.NOINDEX, KOVA.SUNUCU_HATASI, KOVA.BULUNAMADI,
  KOVA.YUMUSAK_404, KOVA.DIZINE_EKLENDI, KOVA.TARANDI_EKLENMEDI,
  KOVA.KESFEDILDI_TARANMADI, KOVA.BILINMIYOR,
];

export const KOVA_ETIKET = {
  robots_engelli: 'robots.txt ENGELLİ (DEĞİŞMEZ İHLALİ)',
  noindex: 'noindex (DEĞİŞMEZ İHLALİ)',
  sunucu_hatasi: 'sunucu hatası (5xx)',
  bulunamadi: '404 bulunamadı',
  yumusak_404: 'yumuşak 404',
  dizine_eklendi: 'dizine eklendi',
  tarandi_eklenmedi: 'tarandı – eklenmedi',
  kesfedildi_taranmadi: 'keşfedildi – taranmadı',
  bilinmiyor: 'sınıflanamadı',
};

/// Site haritasındaki bir URL'de ASLA olmaması gereken kovalar. Google'ın
/// kararı değil, BİZİM kodumuzun çıktısı (SEO-YAPILACAKLAR §8 md. 1 ve 6).
export const IHLAL_KOVALARI = new Set([KOVA.ROBOTS_ENGELLI, KOVA.NOINDEX]);
export const DORT04_KOVALARI = new Set([KOVA.BULUNAMADI, KOVA.YUMUSAK_404]);

/**
 * `indexStatusResult` → kova. YALNIZ ENUM ve alan VARLIĞI kullanılır;
 * `coverageState` metnine BAKILMAZ (dosya başlığındaki gerekçe).
 *
 * SIRALAMA ARIZA-ÖNCELİKLİ ve BU BİLİNÇLİ: bir sayfa hem indeksli olup hem
 * bugün Googlebot'a 5xx dönebilir. GSC arayüzü onu "Dizine eklendi" sayar;
 * BİZ `sunucu_hatasi` sayarız, çünkü bu dosyanın işi arayüzün sayısını
 * kopyalamak değil ARIZAYI GÖRÜNÜR KILMAK. Ayrımın kaybolmaması için ham
 * `verdict === 'PASS'` sayısı `indeksliHam` olarak AYRICA raporlanır —
 * arayüzle karşılaştırılacak sayı odur.
 */
export function kovaBelirle(s) {
  if (!s || typeof s !== 'object') return KOVA.BILINMIYOR;
  if (s.robotsTxtState === 'DISALLOWED') return KOVA.ROBOTS_ENGELLI;
  if (s.indexingState === 'BLOCKED_BY_META_TAG'
    || s.indexingState === 'BLOCKED_BY_HTTP_HEADER') return KOVA.NOINDEX;
  if (s.pageFetchState === 'SERVER_ERROR') return KOVA.SUNUCU_HATASI;
  if (s.pageFetchState === 'NOT_FOUND') return KOVA.BULUNAMADI;
  if (s.pageFetchState === 'SOFT_404') return KOVA.YUMUSAK_404;
  if (s.verdict === 'PASS') return KOVA.DIZINE_EKLENDI;
  // `lastCrawlTime` dokümana göre "URL hiç BAŞARIYLA taranmadıysa YOK".
  // Keşfedildi ↔ Tarandı ayrımını veren TEK kararlı alan bu.
  if (s.lastCrawlTime) return KOVA.TARANDI_EKLENMEDI;
  if (s.verdict === 'FAIL' || s.verdict === 'NEUTRAL' || s.verdict === 'PARTIAL') {
    return KOVA.KESFEDILDI_TARANMADI;
  }
  return KOVA.BILINMIYOR;
}

// ===========================================================================
// 6) PANEL KOŞUSU
// ===========================================================================
/**
 * Paneli denetler. Hız kapısı `DENETIM_SN`, sert tavan `AZAMI_DENETIM`.
 *
 * BAŞARISIZ DENETİM SESSİZCE "DEĞİŞİM" ÜRETMEZ: hata alan URL sonuç haritasına
 * HİÇ girmez. Karşılaştırma iki günün KESİŞİMİ üzerinden yapıldığı için
 * (`degisimHesapla`), eksik bir URL "kovadan çıktı" gibi sayılmaz. Bu, sessiz
 * yanlış alarmın en olası kaynağıydı.
 */
export async function paneliDenetle({ panel, denetle, ayar = AYAR, bekleyici = bekle }) {
  const sonuc = {};       // aile → { url: kova }
  const hamEtiket = {};   // aile → { coverageState metni: adet }
  const indeksliHam = {}; // aile → verdict PASS sayısı
  const hata = {};        // aile → başarısız denetim sayısı
  const hataOrnek = [];
  let istek = 0;
  const araMs = Math.ceil(1000 / ayar.DENETIM_SN);
  let sonIstek = 0;

  for (const aile of Object.keys(panel)) {
    sonuc[aile] = {};
    hamEtiket[aile] = {};
    indeksliHam[aile] = 0;
    hata[aile] = 0;
    for (const url of panel[aile]) {
      if (istek >= ayar.AZAMI_DENETIM) break;
      const gecen = Date.now() - sonIstek;
      if (gecen < araMs) await bekleyici(araMs - gecen);
      sonIstek = Date.now();
      istek++;
      const c = await denetle(url);
      if (!c.tamam) {
        hata[aile]++;
        if (hataOrnek.length < 3) hataOrnek.push(`${url}: ${c.hata}`);
        // KOTA BİTTİYSE DEVAM ETMEK ANLAMSIZ: kalan her istek de 429 yer.
        if (c.kod === 429) return { sonuc, hamEtiket, indeksliHam, hata, hataOrnek, istek, kotaBitti: true };
        continue;
      }
      sonuc[aile][url] = kovaBelirle(c.sonuc);
      if (c.sonuc?.verdict === 'PASS') indeksliHam[aile]++;
      const etiket = c.sonuc?.coverageState || '(boş)';
      hamEtiket[aile][etiket] = (hamEtiket[aile][etiket] || 0) + 1;
    }
  }
  return { sonuc, hamEtiket, indeksliHam, hata, hataOrnek, istek, kotaBitti: false };
}

// ===========================================================================
// 7) DEĞİŞİM VE EŞİK
// ===========================================================================
/** Kova → adet sayımı. */
export function kovaSay(harita) {
  const s = {};
  for (const k of KOVA_SIRA) s[k] = 0;
  for (const kova of Object.values(harita || {})) s[kova] = (s[kova] || 0) + 1;
  return s;
}

/**
 * ANLAMLILIK — McNemar normal yaklaşımı.
 *
 * `giren` (b) ve `cikan` (c) ayrışan gözlemler. Gerçek bir değişim yoksa
 * (b−c) ortalaması 0, standart sapması sqrt(b+c)'dir. Eşik SIGMA×sqrt(b+c),
 * ve altına bir MUTLAK TABAN konur.
 *
 * TABAN NEDEN VAR: b+c küçükken 2σ da küçüktür (b=2,c=0 → eşik 2,83) ve
 * Google'ın olağan yeniden değerlendirmesi her gün posta üretirdi.
 *
 * BİLİNEN İYİMSERLİK: gözlemler tam bağımsız değil (aynı dizinin bölümleri
 * birlikte kıpırdar). Bu yüzden bölüm ailesinde b ve c URL değil KÜME (dizi)
 * sayısıdır — `degisimHesapla` öyle besliyor. Yine de eşik, bağımlılığı
 * tamamen yok saymaz sadece azaltır; o yüzden bu bir kanıt değil ELEK.
 */
export function anlamliMi(giren, cikan, ayar = AYAR) {
  const toplam = giren + cikan;
  if (!toplam) return false;
  const fark = Math.abs(giren - cikan);
  return fark >= Math.max(ayar.ESIK.FLIP_TABAN, ayar.ESIK.SIGMA * Math.sqrt(toplam));
}

/** 0'dan çıkmak ya da 0'a düşmek — büyüklüğe bakılmaz. */
export const sifirBariyeri = (onceki, simdi) =>
  (Number(onceki) === 0) !== (Number(simdi) === 0);

/** Kesin sayılar için görece + mutlak eşik. */
export function kesinEsik(onceki, simdi, oran, mutlak) {
  if (sifirBariyeri(onceki, simdi)) return true;
  const fark = Math.abs(simdi - onceki);
  return fark >= Math.max(mutlak, oran * Math.abs(onceki));
}

/**
 * Eşleşmiş değişim: SADECE iki koşuda da denetlenmiş URL'ler üzerinden.
 *
 * Çıktıda hem URL düzeyinde sayılar (insana) hem KÜME düzeyinde ayrışanlar
 * (anlamlılık testine) var — ikisi farklı işler ve karıştırılırsa ya sahte
 * alarm ya sağır eşik doğar.
 */
export function degisimHesapla(onceki, simdi) {
  const ortakUrl = Object.keys(simdi || {}).filter((u) => u in (onceki || {}));
  const kovalar = {};
  for (const k of KOVA_SIRA) {
    kovalar[k] = { giren: 0, cikan: 0, girenKume: new Set(), cikanKume: new Set() };
  }
  for (const u of ortakUrl) {
    const a = onceki[u];
    const b = simdi[u];
    if (a === b) continue;
    if (kovalar[b]) { kovalar[b].giren++; kovalar[b].girenKume.add(kumeAnahtari(u)); }
    if (kovalar[a]) { kovalar[a].cikan++; kovalar[a].cikanKume.add(kumeAnahtari(u)); }
  }
  const cikti = {};
  for (const k of KOVA_SIRA) {
    cikti[k] = {
      giren: kovalar[k].giren,
      cikan: kovalar[k].cikan,
      net: kovalar[k].giren - kovalar[k].cikan,
      girenKume: kovalar[k].girenKume.size,
      cikanKume: kovalar[k].cikanKume.size,
    };
  }
  const yeniUrl = Object.keys(simdi || {}).filter((u) => !(u in (onceki || {}))).length;
  const dusenUrl = Object.keys(onceki || {}).filter((u) => !(u in (simdi || {}))).length;
  return { kovalar: cikti, ortak: ortakUrl.length, yeniUrl, dusenUrl };
}

/** Örnekten evrene ölçekleme + %95 aralık (normal yaklaşım). */
export function tahminEt(adet, panelN, evrenN) {
  if (!panelN || !evrenN) return { tahmin: 0, aralik: 0, oran: 0 };
  const p = adet / panelN;
  const se = Math.sqrt(Math.max(p * (1 - p), 0) / panelN);
  return {
    tahmin: Math.round(p * evrenN),
    aralik: Math.round(1.96 * se * evrenN),
    oran: p,
  };
}

const beklenenArtisMi = (sinif, kova, ayar = AYAR) =>
  ayar.BEKLENEN_ARTIS.some((b) => b.sinif === sinif && b.kova === kova);

/**
 * SİNYAL ÜRETİMİ — postanın gidip gitmeyeceğine burası karar verir.
 * `agirlik`: 3 kritik · 2 önemli · 1 bilgi. Sıralama ve konu satırı bundan.
 */
export function sinyalleriBul(bugun, dun, ayar = AYAR) {
  const s = [];
  const ekle = (agirlik, metin, etiket) => s.push({ agirlik, metin, etiket });

  // --- 1) DEĞİŞMEZ İHLALLERİ — eşiksiz, mutlak sayıya bakılır ---------------
  for (const aile of Object.keys(bugun.kovaSayim || {})) {
    const say = bugun.kovaSayim[aile];
    for (const k of IHLAL_KOVALARI) {
      if ((say[k] || 0) >= ayar.ESIK.IHLAL_TABAN) {
        const t = tahminEt(say[k], bugun.panelN[aile], bugun.evren[aile]);
        ekle(3, `DEĞİŞMEZ İHLALİ — ${aile}: panelde ${say[k]} URL "${KOVA_ETIKET[k]}" `
          + `(ailede ~${t.tahmin}). Site haritasındaki bir URL noindex/robots ile `
          + 'engellenemez (SEO-YAPILACAKLAR §8 md. 6). Bu Google\'ın değil BİZİM '
          + 'kodumuzun ürettiği bir durum.', `${aile}/${k}`);
      }
    }
    for (const k of DORT04_KOVALARI) {
      if ((say[k] || 0) >= ayar.ESIK.DORT04_TABAN) {
        const t = tahminEt(say[k], bugun.panelN[aile], bugun.evren[aile]);
        ekle(3, `${aile}: panelde ${say[k]} URL "${KOVA_ETIKET[k]}" (ailede ~${t.tahmin}). `
          + '19 Ağu ölçümünde yumuşak 404 = 0 idi.', `${aile}/${k}`);
      }
    }
    if ((say[KOVA.SUNUCU_HATASI] || 0) > 0) {
      const t = tahminEt(say[KOVA.SUNUCU_HATASI], bugun.panelN[aile], bugun.evren[aile]);
      ekle(3, `${aile}: panelde ${say[KOVA.SUNUCU_HATASI]} URL Googlebot'a 5xx `
        + `dönüyor (ailede ~${t.tahmin}). §6.9'da 32 → 0 hedeflenmişti.`,
      `${aile}/5xx`);
    }
  }

  // --- 2) İZLEMENİN KENDİ SAĞLIĞI -----------------------------------------
  for (const aile of Object.keys(bugun.denetimHatasi || {})) {
    const h = bugun.denetimHatasi[aile];
    const n = bugun.panelN[aile] + h;
    if (n && h / n > ayar.ESIK.DENETIM_HATA_ORANI) {
      ekle(3, `İZLEME ARIZASI — ${aile} panelinde ${h}/${n} denetim başarısız. `
        + 'Yetki, kota ya da ağ sorunu; bu koşunun sayıları güvenilmez.', `arıza/${aile}`);
    }
  }
  if (bugun.kotaBitti) {
    ekle(3, 'İZLEME ARIZASI — denetim kotası (2.000/gün) bitti, panel yarım kaldı.', 'arıza/kota');
  }
  if (bugun.haritaHatasi) {
    ekle(3, `İZLEME ARIZASI — site haritası okunamadı: ${bugun.haritaHatasi}. `
      + 'Panel dünkü listeden kurtarıldı.', 'arıza/harita');
  }
  if (dun?.tarih) {
    const gun = (new Date(bugun.tarih) - new Date(dun.tarih)) / 86400000;
    if (gun > ayar.ESIK.ARA_UYARI_GUN) {
      ekle(2, `İZLEME DURMUŞTU — önceki ölçüm ${gun.toFixed(1)} gün önce. `
        + 'Cron çalışmamış; aradaki değişim GÖRÜLMEDİ.', 'arıza/ara');
    }
  }

  // --- 3) SİTE HARİTASI (KESİN) -------------------------------------------
  if (dun?.siteHaritasi && bugun.siteHaritasi) {
    const a = dun.siteHaritasi.toplam || 0;
    const b = bugun.siteHaritasi.toplam || 0;
    if (kesinEsik(a, b, ayar.ESIK.HARITA_ORAN, ayar.ESIK.HARITA_MUTLAK)) {
      ekle(2, `Site haritası: ${a.toLocaleString('tr-TR')} → ${b.toLocaleString('tr-TR')} URL `
        + `(${b - a >= 0 ? '+' : ''}${(b - a).toLocaleString('tr-TR')}).`, 'harita/toplam');
    }
  }
  for (const [ad, p] of Object.entries(bugun.siteHaritasi?.parcalar || {})) {
    if (p.hata > 0) ekle(3, `Site haritası ${ad}: Google ${p.hata} HATA bildiriyor.`, `harita/${ad}/hata`);
    const oncekiUyari = dun?.siteHaritasi?.parcalar?.[ad]?.uyari ?? 0;
    if (p.uyari > oncekiUyari) {
      ekle(2, `Site haritası ${ad}: uyarı ${oncekiUyari} → ${p.uyari}.`, `harita/${ad}/uyari`);
    }
    if (p.sonIndirme) {
      const gun = (Date.now() - new Date(p.sonIndirme)) / 86400000;
      if (gun > ayar.ESIK.HARITA_BAYAT_GUN) {
        ekle(2, `Site haritası ${ad}: Google ${gun.toFixed(0)} gündür indirmedi `
          + `(son: ${p.sonIndirme.slice(0, 10)}).`, `harita/${ad}/bayat`);
      }
    }
  }

  // --- 4) ARAMA ANALİTİĞİ (KESİN) -----------------------------------------
  if (dun?.arama && bugun.arama) {
    for (const aile of Object.keys(bugun.arama.sayfa || {})) {
      const a = dun.arama.sayfa?.[aile] ?? 0;
      const b = bugun.arama.sayfa[aile];
      if (sifirBariyeri(a, b)) {
        // KULLANICININ ASIL SORDUĞU SORU BURADA CEVAPLANIYOR.
        ekle(b > a ? 3 : 2, `SIFIR BARİYERİ — "${aile}" ailesinde gösterim alan `
          + `farklı sayfa sayısı ${a} → ${b}. ${b > a
            ? 'Bu aile arama sonuçlarında İLK KEZ görünüyor.'
            : 'Bu aile arama sonuçlarından TAMAMEN düştü.'}`, `arama/${aile}/sifir`);
      } else if (kesinEsik(a, b, ayar.ESIK.GOSTERIM_ORAN, ayar.ESIK.GOSTERIM_MUTLAK)) {
        ekle(2, `"${aile}" ailesinde gösterim alan sayfa: ${a} → ${b}.`, `arama/${aile}`);
      }
    }
    const ta = dun.arama.tiklama ?? 0;
    const tb = bugun.arama.tiklama;
    if (sifirBariyeri(ta, tb)) {
      ekle(tb > ta ? 3 : 2, `SIFIR BARİYERİ — tıklama ${ta} → ${tb} `
        + `(${bugun.arama.pencere.bas} … ${bugun.arama.pencere.son}).`, 'arama/tiklama');
    }
  }

  // --- 5) PANEL KOVALARI (ÖRNEKLENMİŞ) ------------------------------------
  for (const aile of Object.keys(bugun.degisim || {})) {
    const d = bugun.degisim[aile];
    for (const k of KOVA_SIRA) {
      const v = d.kovalar[k];
      if (!v || (!v.giren && !v.cikan)) continue;
      // Küme düzeyinde ayrışanlar (bölüm ailesinde dizi başına bir oy).
      if (!anlamliMi(v.girenKume, v.cikanKume, ayar)) continue;
      const artis = v.net > 0;
      if (artis && beklenenArtisMi(aile, k, ayar)) continue;   // BEKLENEN — sus
      const oncekiT = tahminEt((dun?.kovaSayim?.[aile]?.[k]) ?? 0,
        dun?.panelN?.[aile] ?? bugun.panelN[aile], bugun.evren[aile]);
      const simdiT = tahminEt(bugun.kovaSayim[aile][k], bugun.panelN[aile], bugun.evren[aile]);
      ekle(2, `${aile} / ${KOVA_ETIKET[k]}: panelde ${artis ? '+' : ''}${v.net} URL `
        + `(${v.giren} girdi, ${v.cikan} çıktı; ${v.girenKume}/${v.cikanKume} farklı küme). `
        + `Aile tahmini ~${oncekiT.tahmin} → ~${simdiT.tahmin} (±${simdiT.aralik}).`,
      `panel/${aile}/${k}`);
    }
    // "Bölüm sayfaları taranmaya başladı mı" — panelde sıfır bariyeri.
    const oncekiTarandi = (dun?.kovaSayim?.[aile]?.[KOVA.TARANDI_EKLENMEDI] ?? 0)
      + (dun?.kovaSayim?.[aile]?.[KOVA.DIZINE_EKLENDI] ?? 0);
    const simdiTarandi = (bugun.kovaSayim[aile][KOVA.TARANDI_EKLENMEDI] || 0)
      + (bugun.kovaSayim[aile][KOVA.DIZINE_EKLENDI] || 0);
    if (dun && sifirBariyeri(oncekiTarandi, simdiTarandi)) {
      ekle(3, `SIFIR BARİYERİ — "${aile}" panelinde TARANMIŞ sayfa ${oncekiTarandi} → `
        + `${simdiTarandi}. Aile tahmini ~${tahminEt(simdiTarandi, bugun.panelN[aile], bugun.evren[aile]).tahmin} sayfa.`,
      `panel/${aile}/tarandi-sifir`);
    }
  }

  s.sort((a, b) => b.agirlik - a.agirlik);
  return s;
}

// ===========================================================================
// 8) RAPOR
// ===========================================================================
const yuzde = (x) => `%${(x * 100).toFixed(1)}`;
const say = (n) => Number(n || 0).toLocaleString('tr-TR');

export function raporMetni(bugun, dun, sinyaller, sebep, ayar = AYAR) {
  const L = [];
  L.push(`dizi.jpg — Search Console izleme · ${bugun.tarih.slice(0, 10)}`);
  L.push('='.repeat(72));
  L.push('');
  if (sebep) L.push(`GÖNDERİM SEBEBİ: ${sebep}`);
  L.push(dun
    ? `Karşılaştırma tabanı: ${dun.tarih.slice(0, 10)}`
    : 'Karşılaştırma tabanı YOK — bu ilk ölçüm (temel).');
  L.push('');

  if (sinyaller.length) {
    L.push('SİNYALLER');
    L.push('-'.repeat(72));
    for (const s of sinyaller) {
      L.push(`[${['', 'bilgi', 'ÖNEMLİ', 'KRİTİK'][s.agirlik]}] ${s.metin}`);
    }
    L.push('');
  }

  L.push('KESİN ÖLÇÜMLER (örnekleme yok)');
  L.push('-'.repeat(72));
  L.push(`Site haritası toplam bildirilen URL : ${say(bugun.siteHaritasi?.toplam)}`);
  for (const [ad, p] of Object.entries(bugun.siteHaritasi?.parcalar || {})) {
    L.push(`  ${ad.padEnd(24)} ${String(say(p.gonderilen)).padStart(8)} URL · `
      + `son indirme ${p.sonIndirme ? p.sonIndirme.slice(0, 10) : 'YOK'} · `
      + `hata ${p.hata} · uyarı ${p.uyari}${p.bekliyor ? ' · BEKLİYOR' : ''}`);
  }
  const a = bugun.arama;
  if (a) {
    L.push('');
    L.push(`Arama (${a.pencere.bas} … ${a.pencere.son}, yalnız kesinleşmiş veri):`);
    L.push(`  tıklama ${say(a.tiklama)} · gösterim ${say(a.gosterim)} · `
      + `gösterim alan farklı sayfa ${say(a.satirSayisi)}`);
    for (const [aile, n] of Object.entries(a.sayfa)) {
      L.push(`    ${aile.padEnd(10)} ${String(n).padStart(6)} sayfa`);
    }
  }
  L.push('');

  L.push('ÖRNEKLENMİŞ ÖLÇÜMLER (sabit panel — tahmin, sayım DEĞİL)');
  L.push('-'.repeat(72));
  for (const aile of Object.keys(bugun.kovaSayim || {})) {
    const n = bugun.panelN[aile];
    const N = bugun.evren[aile];
    const d = bugun.degisim?.[aile];
    // Oran 1'e KIRPILIR: `genel` ailesinde panel tavanı (25) evrenden (3)
    // büyük ve harita okunamayıp evren dünden kurtarıldığında ikisi geçici
    // olarak ayrışabiliyor. "%833" yazan bir satır raporun tamamını
    // güvenilmez gösterirdi.
    L.push(`${aile.toUpperCase()} — panel ${n}/${say(N)} URL (${yuzde(N ? Math.min(n / N, 1) : 0)})`
      + (d ? ` · eşleşen ${d.ortak} · panel değişimi +${d.yeniUrl}/−${d.dusenUrl}` : '')
      + (bugun.denetimHatasi[aile] ? ` · DENETİM HATASI ${bugun.denetimHatasi[aile]}` : ''));
    for (const k of KOVA_SIRA) {
      const adet = bugun.kovaSayim[aile][k] || 0;
      const onceki = dun?.kovaSayim?.[aile]?.[k];
      if (!adet && !onceki) continue;
      const t = tahminEt(adet, n, N);
      const dd = d?.kovalar?.[k];
      const hareket = dd && (dd.giren || dd.cikan)
        ? `  Δpanel ${dd.net >= 0 ? '+' : ''}${dd.net} (↑${dd.giren} ↓${dd.cikan})` : '';
      L.push(`  ${KOVA_ETIKET[k].padEnd(34)} panel ${String(adet).padStart(4)} → `
        + `aile ~${say(t.tahmin)} ±${say(t.aralik)}${hareket}`);
    }
    L.push(`  ${'(ham verdict=PASS)'.padEnd(34)} panel ${String(bugun.indeksliHam[aile] || 0).padStart(4)} `
      + '← GSC arayüzündeki "Dizine eklenen" ile KARŞILAŞTIRILACAK sayı budur');
    L.push('');
  }

  L.push('GOOGLE\'IN KENDİ ETİKETLERİ (ham `coverageState`, yalnız DOĞRULAMA için)');
  L.push('-'.repeat(72));
  L.push('Kova kararı bu metinlere BAKMAZ (metin yerelleştirilmiş ve Google');
  L.push('istediği zaman değiştirebilir). Burada, eşlemenin GSC arayüzüyle');
  L.push('tuttuğunu gözle doğrulayabilesin diye basılıyor.');
  for (const aile of Object.keys(bugun.hamEtiket || {})) {
    const girdiler = Object.entries(bugun.hamEtiket[aile])
      .sort((x, y) => y[1] - x[1]).slice(0, 6);
    if (!girdiler.length) continue;
    L.push(`  ${aile}:`);
    for (const [e, n] of girdiler) L.push(`    ${String(n).padStart(4)} × ${e}`);
  }
  L.push('');

  L.push('BU RAPORUN ÖLÇEMEDİKLERİ');
  L.push('-'.repeat(72));
  L.push('Search Console API\'sinde şu veriler HİÇ YOK; aşağıdakiler için hâlâ');
  L.push('arayüze bakmak gerekir (Google kritik olanlarda sahibe e-posta atıyor):');
  L.push('  · "Sayfalar" raporunun resmî toplamları (bizimki ÖRNEKLEME TAHMİNİ)');
  L.push('  · Manuel işlem · Güvenlik sorunları');
  L.push('  · Zengin sonuç (Geliştirmeler) geçerlilik sayıları');
  L.push('  · Core Web Vitals / CrUX saha verisi');
  const bp = bugun.panelN.bolum || 0;
  const bN = bugun.evren.bolum || 0;
  if (bp && bN) {
    const gorunur = Math.ceil(bN / bp);
    L.push('');
    L.push(`KÖR NOKTA: bölüm paneli ${bp}/${say(bN)} örnekliyor. Ailede taranan sayfa`);
    L.push(`sayısı ~${say(gorunur)}'in altındayken panelin SIFIR görmesi beklenir.`);
    L.push('İlk taramaları görecek olan KESİN ölçüm: yukarıdaki "bolum" gösterim');
    L.push('sayısı ve sunucumuzun kendi erişim günlüğü (nginx), panel değil.');
  }
  L.push('');
  L.push(`Denetim isteği: ${bugun.denetimIstegi} (mülk kotası 2.000/gün)`);
  return L.join('\n');
}

/** Konu satırı: en ağır sinyali ADIYLA taşır — kutuda okunmadan anlaşılsın. */
export function konuSatiri(bugun, sinyaller, sebep) {
  const gun = bugun.tarih.slice(0, 10);
  if (sebep === 'ilk') return `dizi.jpg GSC — temel ölçüm alındı (${gun})`;
  if (!sinyaller.length) return `dizi.jpg GSC — ${AYAR.OZET_GUN} günlük özet (${gun})`;
  const bas = sinyaller[0];
  const kisa = bas.metin.split('.')[0].slice(0, 90);
  const n = sinyaller.length > 1 ? ` (+${sinyaller.length - 1})` : '';
  return `dizi.jpg GSC — ${kisa}${n}`;
}

// ===========================================================================
// 9) DURUM DOSYASI
// ===========================================================================
export function durumOku(yol, ayar = AYAR) {
  let ham;
  try {
    ham = fs.readFileSync(yol, 'utf8');
  } catch {
    return null;                       // ilk koşu — hata DEĞİL
  }
  try {
    const d = JSON.parse(ham);
    // Biçim sürümü tutmuyorsa karşılaştırma YAPILMAZ. Yarı uyumlu bir dosyayı
    // karşılaştırmak, gerçek olmayan "değişim" üretir — sessiz yanlış alarm.
    if (d?.surum !== ayar.DURUM_SURUM) return null;
    return d;
  } catch (e) {
    console.error(`gsc_izle: durum dosyası bozuk, yok sayılıyor (${hatayiKisirlastir(e.message)})`);
    return null;
  }
}

/**
 * Durumu ATOMİK yazar (geçici dosya → rename).
 * Yerinde yazan bir sürüm, koşu ortasında kesilirse YARIM JSON bırakır ve
 * ertesi gün karşılaştırma sessizce kaybolur (`web_brotli.sh` ile aynı ders).
 */
export function durumYaz(yol, durum) {
  const gecici = `${yol}.gecici`;
  fs.mkdirSync(path.dirname(yol), { recursive: true });
  fs.writeFileSync(gecici, JSON.stringify(durum, null, 1));
  fs.renameSync(gecici, yol);
}

// ===========================================================================
// 10) POSTA
// ===========================================================================
// KANAL KARARI — E-POSTA, PUSH DEĞİL. Üç somut sebep:
//  1) İÇERİK BİÇİMİ: bu rapor çok satırlı bir tablo. Push bildirimi tek satır
//     gösterir; kullanıcı yine bir yere bakmak zorunda kalır, yani push
//     yalnızca "bir şey oldu" der ve asıl işi ertelemiş olur.
//  2) ARŞİV: eşik ayarlamak ve eğilim okumak için ESKİ raporlar gerekiyor
//     ("geçen hafta ne demişti"). Posta kutusu bunu bedava verir; push uçucu.
//  3) ZATEN GÖRÜNÜR: `admin@dizijpg.com` host'ta gerçek bir Maildir ve
//     docker-compose onu `/mail/admin` olarak API'ye SALT-OKUNUR bağlıyor —
//     yani rapor admin panelindeki "Mailler" sekmesinde de görünür. Yeni bir
//     yüzey açmadan hem posta hem panel elde ediliyor.
// Ayrıca push, kullanıcı-cihaz jetonu gerektirir (`kullanici_cihazlar`);
// bir bakım işini bir son kullanıcı kaydına bağlamak kırılgan olurdu.
//
// TAŞIYICI server.js'teki `mailUlastirici` ile AYNI: konteynerden host
// Postfix'ine `host.docker.internal:25`. server.js import EDİLEMEZ (içe
// aktarıldığı an `app.listen` çağırıyor — isitici.js 2. kararıyla aynı kısıt),
// bu yüzden taşıyıcı burada yeniden kuruluyor; AYNI ortam değişkenlerinden
// okuduğu için ayrışamaz.
export function postaTasiyici(env = process.env) {
  return nodemailer.createTransport({
    host: env.MAIL_HOST || 'host.docker.internal',
    port: parseInt(env.MAIL_PORT || '25', 10),
    secure: false,
    ignoreTLS: true,
    tls: { rejectUnauthorized: false },
  });
}

export async function raporGonder(konu, govde, env = process.env, tasiyiciUret = postaTasiyici) {
  const alici = env.GSC_MAIL_ALICI || 'admin@dizijpg.com';
  await tasiyiciUret(env).sendMail({
    from: env.MAIL_FROM || 'dizi.jpg <noreply@dizijpg.com>',
    to: alici,
    subject: konu,
    text: govde,
  });
  return alici;
}

// ===========================================================================
// 11) BAYRAKLAR
// ===========================================================================
/** Bilinmeyen bayrak SESSİZCE yutulmaz (isitici.js ile aynı disiplin). */
export function bayraklariCoz(argv, ayar = AYAR) {
  const s = { kuru: false, zorlaPosta: false, panel: null };
  for (let i = 0; i < argv.length; i++) {
    const parca = argv[i];
    if (!parca.startsWith('--')) throw new Error(`Tanınmayan argüman: ${parca}`);
    const esit = parca.indexOf('=');
    const ad = esit >= 0 ? parca.slice(2, esit) : parca.slice(2);
    const deger = () => (esit >= 0 ? parca.slice(esit + 1) : argv[++i]);
    switch (ad) {
      case 'kuru': s.kuru = true; break;
      case 'zorla-posta': s.zorlaPosta = true; break;
      case 'panel': {
        const n = Number(deger());
        if (!Number.isFinite(n) || n <= 0) throw new Error('--panel pozitif sayı olmalı');
        s.panel = n;
        break;
      }
      default: throw new Error(`Tanınmayan bayrak: --${ad}`);
    }
  }
  if (s.kuru && s.zorlaPosta) {
    throw new Error('--kuru ile --zorla-posta birlikte kullanılamaz (kuru koşu POSTA GÖNDERMEZ)');
  }
  if (s.panel) {
    // Tavan koru: `--panel` yalnız KÜÇÜLTMEK içindir.
    for (const k of Object.keys(ayar.PANEL)) ayar.PANEL[k] = Math.min(ayar.PANEL[k], s.panel);
  }
  return s;
}

/**
 * SESSİZLİK KARARI — postanın gidip gitmeyeceğini SADECE burası söyler.
 *
 * Ayrı bir fonksiyon olması bilinçli: bu projenin en kolay sessizce bozulacak
 * kuralı bu. `main` içine gömülü kalsaydı testle sürülemezdi ve bir gün
 * "her koşuda posta" hâline dönerdi — ısıtıcıda tam olarak bu oldu (5b).
 *
 * @returns {'ilk'|'sinyal'|'ozet'|'zorla'|null} null = SESSİZ KAL
 */
export function bildirimSebebi(dun, sinyaller, bildirimsizKosu, zorla = false, ayar = AYAR) {
  if (!dun) return 'ilk';                                   // temel ölçüm, bir kez
  if (sinyaller.length) return 'sinyal';
  if (ayar.OZET_GUN > 0 && bildirimsizKosu >= ayar.OZET_GUN) return 'ozet';
  if (zorla) return 'zorla';
  return null;                                              // DEĞİŞİM YOK → SUS
}

/** GSC tarih penceresi (PT saatine göre; gün hassasiyeti yeterli). */
export function pencereHesapla(simdiMs = Date.now(), ayar = AYAR) {
  const g = (n) => new Date(simdiMs - n * 86400000).toISOString().slice(0, 10);
  return {
    son: g(ayar.ARAMA_GECIKME_GUN),
    bas: g(ayar.ARAMA_GECIKME_GUN + ayar.ARAMA_PENCERE_GUN - 1),
  };
}

/** Cron günlüğüne giden TEK satır — her koşuda, iş olsun olmasın. */
export function ozetSatiri(bugun, sinyaller, postaGitti) {
  const kova = Object.entries(bugun.kovaSayim || {})
    .map(([aile, s]) => `${aile}:${s[KOVA.DIZINE_EKLENDI] || 0}/${bugun.panelN[aile]}`)
    .join(' ');
  return [
    'gsc_izle koşusu bitti',
    `harita=${bugun.siteHaritasi?.toplam ?? '?'}`,
    `gösterim=${bugun.arama?.gosterim ?? '?'}`,
    `bölüm_sayfa=${bugun.arama?.sayfa?.bolum ?? '?'}`,
    `denetim=${bugun.denetimIstegi}`,
    `indeksli_panel=${kova}`,
    `sinyal=${sinyaller.length}`,
    `posta=${postaGitti ? 'gitti' : 'yok'}`,
    `süre=${(bugun.sureMs / 1000).toFixed(1)}sn`,
  ].join(' ');
}

// ===========================================================================
// 12) ANA AKIŞ
// ===========================================================================
async function main(argv) {
  const basladi = Date.now();
  let secim;
  try {
    secim = bayraklariCoz(argv);
  } catch (e) {
    console.error(`gsc_izle: ${e.message}`);
    process.exit(2);
  }

  const saYol = process.env.GSC_SA_YOL || '/app/gsc-servis-hesabi.json';
  const durumYol = process.env.GSC_DURUM_YOL || '/veri/gsc_izle_durum.json';
  const mulk = process.env.GSC_MULK || AYAR.MULK;

  const dun = durumOku(durumYol);

  // --- KİMLİK YOKSA ÇÖKME, AMA "HİÇ ÇALIŞMADI" İLE "BOZULDU"YU AYIR -------
  // Kurulum HENÜZ YAPILMADIYSA (durum dosyası da yok) her gün hata koduyla
  // dönmek cron gürültüsüdür → 0 ile in, açıklamayı yaz.
  // DAHA ÖNCE ÇALIŞTIYSA (durum dosyası var) anahtarın kaybolması GERÇEK bir
  // arızadır ve SESSİZ kalmamalı → 1 ile in.
  const hesap = servisHesabiOku(saYol);
  if (!hesap.hazir) {
    console.error(`gsc_izle: ${hesap.sebep}`);
    console.error('gsc_izle: kurulum adımları için backend/gsc_izle.js başlığındaki '
      + '"KİMLİK" bölümüne bak. İzleme ÇALIŞMIYOR, ama başka hiçbir şey etkilenmedi.');
    process.exit(dun ? 1 : 0);
  }

  let jeton;
  try {
    jeton = await erisimJetonu(hesap);
  } catch (e) {
    console.error(`gsc_izle: kimlik doğrulanamadı — ${hatayiKisirlastir(e.message)}`);
    process.exit(dun ? 1 : 0);
  }

  // --- KESİN ÖLÇÜMLER -----------------------------------------------------
  const harita = await siteHaritalari(mulk, jeton, AYAR);
  if (!harita.tamam) {
    console.error(`gsc_izle: site haritası ucu okunamadı — ${harita.hata}`);
    process.exit(1);
  }
  const pencere = pencereHesapla(Date.now(), AYAR);
  const arama = await aramaAnalitigi(mulk, jeton, pencere, AYAR);
  if (!arama.tamam) {
    console.error(`gsc_izle: arama analitiği okunamadı — ${arama.hata}`);
    process.exit(1);
  }

  // --- KAZANAN BÖLÜMLER ---------------------------------------------------
  // Site haritası kesme kuralının muafiyet listesini TAZELE (gerekçe
  // `kazananlariCoz` başlığında). RAPORU BLOKLAMAZ: DB düşse bile izleme
  // koşusu tamamlanmalı, tek satır uyarı bırakır.
  let kazananOzet = null;
  if (process.env.DATABASE_URL) {
    const havuz = new pg.Pool({
      connectionString: process.env.DATABASE_URL,
      max: 1,
      connectionTimeoutMillis: 5000,
    });
    try {
      kazananOzet = await kazananlariYaz(havuz, arama.kazananlar, pencere.son);
      console.log(`gsc_izle: kazanan bölüm — ${kazananOzet.yazildi} yazıldı`
        + `, ${kazananOzet.yeni} yeni`);
    } catch (e) {
      console.error('gsc_izle: kazanan bölüm yazılamadı — '
        + hatayiKisirlastir(e?.message || e));
    } finally {
      await havuz.end().catch(() => {});
    }
  } else {
    console.error('gsc_izle: DATABASE_URL yok — kazanan bölüm tablosu ATLANDI');
  }

  // --- PANEL --------------------------------------------------------------
  let urller = [];
  let haritaHatasi = null;
  try {
    ({ urller } = await haritaUrlleri(AYAR.SITE_KOK));
  } catch (e) {
    haritaHatasi = hatayiKisirlastir(e.message);
  }
  const { panel, evren } = panelleriKur(urller, dun?.panel || {}, AYAR);
  // Harita indirilemediyse evren sayıları dünden kurtarılır; yoksa tahminler
  // sıfıra düşer ve rapor yanlış olur.
  if (haritaHatasi && dun?.evren) Object.assign(evren, dun.evren);

  const d = await paneliDenetle({
    panel,
    denetle: (u) => urlDenetle(mulk, u, jeton, AYAR),
    ayar: AYAR,
  });

  const bugun = {
    surum: AYAR.DURUM_SURUM,
    tarih: new Date().toISOString(),
    siteHaritasi: { toplam: harita.toplam, parcalar: harita.parcalar },
    arama: {
      tiklama: arama.tiklama,
      gosterim: arama.gosterim,
      sayfa: arama.sayfa,
      satirSayisi: arama.satirSayisi,
      pencere,
    },
    panel: d.sonuc,
    kovaSayim: Object.fromEntries(Object.keys(d.sonuc).map((a) => [a, kovaSay(d.sonuc[a])])),
    panelN: Object.fromEntries(Object.keys(d.sonuc).map((a) => [a, Object.keys(d.sonuc[a]).length])),
    evren,
    indeksliHam: d.indeksliHam,
    hamEtiket: d.hamEtiket,
    denetimHatasi: d.hata,
    denetimIstegi: d.istek,
    kotaBitti: d.kotaBitti,
    haritaHatasi,
    bildirimsizKosu: 0,
    sureMs: 0,
  };
  bugun.degisim = Object.fromEntries(Object.keys(d.sonuc)
    .map((a) => [a, degisimHesapla(dun?.panel?.[a] || {}, d.sonuc[a])]));
  bugun.sureMs = Date.now() - basladi;

  const sinyaller = sinyalleriBul(bugun, dun, AYAR);

  // --- SESSİZLİK DİSİPLİNİ ------------------------------------------------
  const bildirimsiz = (dun?.bildirimsizKosu ?? 0) + 1;
  const sebep = bildirimSebebi(dun, sinyaller, bildirimsiz, secim.zorlaPosta, AYAR);
  bugun.bildirimsizKosu = sebep ? 0 : bildirimsiz;

  const rapor = raporMetni(bugun, dun, sinyaller, {
    ilk: 'ilk koşu — temel ölçüm. Bu raporu GSC arayüzüyle karşılaştırıp kova '
      + 'eşlemesini DOĞRULA; sonraki raporlar yalnız değişimde gelecek.',
    sinyal: null,
    ozet: `${AYAR.OZET_GUN} koşudur değişim yok — bu posta yalnız izlemenin `
      + 'CANLI olduğunu kanıtlamak için gönderiliyor.',
    zorla: '--zorla-posta bayrağı verildi.',
  }[sebep], AYAR);

  if (secim.kuru) {
    console.log(rapor);
    console.log('');
    console.log(`gsc_izle KURU ÇALIŞMA — posta GÖNDERİLMEDİ, durum dosyası YAZILMADI. `
      + `Gerçek koşuda posta ${sebep ? 'GİDERDİ' : 'gitmezdi'}.`);
    console.log(ozetSatiri(bugun, sinyaller, false));
    return;
  }

  let postaGitti = false;
  if (sebep) {
    try {
      const alici = await raporGonder(konuSatiri(bugun, sinyaller, sebep), rapor);
      postaGitti = true;
      console.log(`gsc_izle: rapor gönderildi → ${alici}`);
    } catch (e) {
      // Posta gidemediyse rapor KAYBOLMASIN: günlüğe tamamını bas.
      console.error(`gsc_izle: POSTA GÖNDERİLEMEDİ — ${hatayiKisirlastir(e.message)}`);
      console.error(rapor);
    }
  }

  durumYaz(durumYol, bugun);
  // KALP ATIŞI: iş olsun olmasın HER koşuda tek satır. Isıtıcıdan farkı
  // bilinçli — orada 144 koşu/gün vardı, burada 1. Günde tek satır günlüğü
  // şişirmez ama "cron çalışıyor mu" sorusunu cevaplar.
  console.log(ozetSatiri(bugun, sinyaller, postaGitti));
}

// Test/import güvenliği: doğrudan çalıştırıldığında koşar, import edildiğinde
// koşmaz (isitici.js ile aynı kalıp).
const dogrudan = process.argv[1]
  && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (dogrudan) {
  main(process.argv.slice(2)).catch((e) => {
    console.error('gsc_izle: koşu hatası:', hatayiKisirlastir(e?.message || e));
    process.exit(1);
  });
}

export { BURASI, GSC_KOK, DENETIM_UCU, JETON_KAPSAMI, bekle };
