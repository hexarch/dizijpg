// dizi.jpg'nin KENDİ İZLEME VERİSİNDEN raflar — saf mantık (17 Eyl 2026).
//
// İSTEK (birebir): "hem ana sayfa hem akışa şu listeleri de ekle: dizi.jpg
// kullanıcılarının bu hafta en çok izlediği 10 film, en çok izlediği 10 dizi,
// bunların aylık versiyonu da olsun, yıllık versiyonu da — 2026 yılında
// dizi.jpg'de en çok izlenen 50 film / 50 dizi. Bu listeler her gün yeni
// verilerle tazelenmeli."
//
// NEDEN TMDB DEĞİL: `anaSayfaRaflari`ndaki diğer rafların hepsi TMDB'nin
// küresel popülerliği. Bu altı raf SİTENİN KENDİ verisidir (`izlemeler`
// tablosu) — TMDB'de karşılığı yok, sayfanın özgünlük gerekçesi de bu
// (SEO: /kesfet'in editöryel derleme savunması).
//
// ---------------------------------------------------------------------------
// ÖLÇÜ: "EN ÇOK İZLENEN" = KAÇ FARKLI KİŞİ (satır sayısı DEĞİL)
// ---------------------------------------------------------------------------
// `izlemeler` bir OLAY tablosudur: 62 bölümlük bir dizi TEK kullanıcıda 62
// satırdır. Ham `COUNT(*)` sıralaması uzun diziler listesine dönerdi — "en çok
// izlenen dizi" değil, "en çok bölümü olan dizi". Bu yüzden birincil ölçü
// `COUNT(DISTINCT kullanici_id)`, eşitlik bozucu satır sayısı.
//
// ---------------------------------------------------------------------------
// `tarih_kesin` ZORUNLU SÜZGEÇ — atlanırsa liste İÇE AKTARIMLA KAÇIRILIR
// ---------------------------------------------------------------------------
// Letterboxd/TV Time içe aktarımı gerçek izleme tarihini okuyamadığında satıra
// `now()` damgalar ve `tarih_kesin=false` yazar (migrasyon-2026-08-27b).
// Süzgeç olmasaydı 2.000 filmlik tek bir içe aktarım "bu hafta en çok izlenen"
// tablosunu tek başına doldururdu. Aynı sebeple yıllık liste de yalnız kesin
// tarihleri sayar.

/** Yıllık rafın yılı. SABİT — bkz. aşağıdaki "YIL NEDEN OTOMATİK DEĞİL". */
export const POPULER_YIL = 2026;

// YIL NEDEN OTOMATİK DEĞİL: başlık aynı zamanda KALICI adresin kaynağı
// (`/raf/dizi-jpg-de-2026-da-en-cok-izlenen-50-film`). `new Date().getFullYear()`
// olsaydı 1 Ocak'ta paylaşılmış/yer imlenmiş her bağlantı başka bir yılın
// listesine kayardı ve 45 dildeki çeviri anahtarı da bir gecede geçersiz
// olurdu. Yıl her 1 Ocak'ta ELDE yükseltilir (YAPILACAKLAR.md'de not var) —
// 2027 rafları da aynı gerekçeyle sabit.

/** Dönem → (raf boyu, gün penceresi). `yil` penceresi takvim yılıdır. */
export const POPULER_DONEMLER = Object.freeze({
  hafta: { boy: 10, gun: 7 },
  ay: { boy: 10, gun: 30 },
  yil: { boy: 50, gun: null },
});

export const POPULER_MEDYALAR = Object.freeze(['movie', 'tv']);

/**
 * Afişsiz/TMDB'de bulunamayan kayıtlar düştüğü için hedefin 2 katı çekilir.
 *
 * PAY NEDEN KÜÇÜK TUTULDU: aday sayısı doğrudan TMDB isteğine dönüşüyor —
 * günün ilk kurulumunda `tmdb_onbellek`te olmayan her aday için bir çağrı
 * gider (8'li öbekler). 3 kat payda yıllık raf tek başına 300 adaya çıkıyordu;
 * 2 kat, 50'lik listeyi doldurmaya fazlasıyla yetiyor (afişsizlik oranı
 * ölçülen en kötü rafta bile %35).
 */
export const POPULER_PAY = 2;

export function populerGecerli(donem, medya) {
  return Object.hasOwn(POPULER_DONEMLER, String(donem))
    && POPULER_MEDYALAR.includes(String(medya));
}

export function populerBoy(donem) {
  return POPULER_DONEMLER[donem].boy;
}

/**
 * Raf başlığı — istemcide AYNI dize çeviri anahtarıdır (kesfet.dart
 * `anaSayfaRaflari`) ve `rafSlug` ile adrese dönüşür. SUNUCUYLA BİREBİR aynı
 * kalmalı, yoksa akıştaki rafın başlığına dokunmak 404'e gider.
 *
 * "dizi.jpg'de" ÖNEKİ BİLEREK: rafın hemen üstünde TMDB'nin küresel
 * "Haftanın Filmleri" rafı duruyor. Önek olmasaydı iki raf aynı şeyi
 * söylüyormuş gibi okunurdu; oysa biri dünyanın, biri BU SİTENİN verisi.
 */
export function populerBasligi(donem, medya) {
  const boy = populerBoy(donem);
  const tur = medya === 'tv' ? 'Dizi' : 'Film';
  if (donem === 'yil') return `dizi.jpg'de ${POPULER_YIL}'da En Çok İzlenen ${boy} ${tur}`;
  const ne = donem === 'hafta' ? 'Bu Hafta' : 'Bu Ay';
  return `dizi.jpg'de ${ne} En Çok İzlenen ${boy} ${tur}`;
}

/** İstemcinin çektiği yol (`anaSayfaRaflari` ikinci alanı). */
export function populerYolu(donem, medya) {
  return `/populer/${donem}/${medya}`;
}

/**
 * Sorgunun tarih aralığı: `[bas, bit)`.
 *
 * HAFTA/AY KAYAN PENCERE, TAKVİM HAFTASI DEĞİL: liste her gün tazeleniyor
 * (aşağıdaki gün anahtarı); takvim haftası kullanılsaydı liste pazartesi
 * sabahı BOŞALIR, salı 2 kişilik bir tabloya dönerdi. Kayan 7/30 gün her gün
 * dolu ve her gün farklıdır — istenen "her gün yeni veri" tam da bu.
 */
export function populerAralik(donem, simdi = new Date()) {
  if (donem === 'yil') {
    // Takvim yılı, İSTANBUL saatiyle: sunucu UTC koşuyor ve 1 Ocak 02:00'de
    // izlenen bir film UTC'de hâlâ 31 Aralık'tır.
    return {
      bas: new Date(`${POPULER_YIL}-01-01T00:00:00+03:00`),
      bit: new Date(`${POPULER_YIL + 1}-01-01T00:00:00+03:00`),
    };
  }
  const gun = POPULER_DONEMLER[donem].gun;
  return { bas: new Date(simdi.getTime() - gun * 24 * 60 * 60 * 1000), bit: simdi };
}

/**
 * Ana sayfa/akış serpiştirme sırası: dönem içinde film+dizi ikilisi.
 * (hafta film, hafta dizi, ay film, ay dizi, yıl film, yıl dizi)
 */
export function populerRafSirasi() {
  const sira = [];
  for (const donem of Object.keys(POPULER_DONEMLER)) {
    for (const medya of POPULER_MEDYALAR) sira.push({ donem, medya });
  }
  return sira;
}

/**
 * "Her gün tazelensin" için gün anahtarı — İSTANBUL takvim günü.
 *
 * Konteyner UTC koşuyor; `toISOString().slice(0,10)` kullansaydık liste
 * gece 03:00'te (TSİ) değil, sabah 03:00'te değişirdi. Aynı tuzağın ölçülmüş
 * hâli: Büyüme paneli gün kovaları (13 Eyl 2026).
 */
export function populerGunu(simdi = new Date()) {
  return simdi.toLocaleDateString('en-CA', { timeZone: 'Europe/Istanbul' });
}

/**
 * Sıra satırlarını ({tmdb_id, kisi, satir}) TMDB kartlarıyla birleştirir.
 *
 * `kartlar`: `icerikKartlari` çıktısı — anahtar `tur:id`. TMDB'de bulunamayan
 * ya da afişsiz kayıt DÜŞER (uygulamada da listelenmiyor), kalanlar `sira`
 * 1..N ile numaralanır ve `azami`de kesilir.
 */
export function populerSirala(medya, satirlar, kartlar, azami) {
  const liste = [];
  for (const r of satirlar || []) {
    const kart = kartlar[`${medya}:${r.tmdb_id}`];
    if (!kart || !kart.poster_path || !(kart.title || kart.name)) continue;
    liste.push({
      ...kart,
      media_type: medya,
      tur: medya,
      tmdb_id: r.tmdb_id,
      // Kaç kişinin izlediği: liste sayfasında "N kişi izledi" diye
      // gösterilebilsin diye taşınıyor (şu an arayüzde kullanılmıyor).
      izleyen: Number(r.kisi) || 0,
      sira: liste.length + 1,
    });
    if (liste.length >= azami) break;
  }
  return liste;
}

/** 1 tabanlı sayfa dilimi — `kanonSayfaDilimi` ile aynı sözleşme. */
export function populerSayfaDilimi(liste, sayfa, adet, varsayilanAdet = 20) {
  const s = Math.max(1, parseInt(sayfa, 10) || 1);
  const a = Math.min(1000, Math.max(1, parseInt(adet, 10) || varsayilanAdet));
  const bas = (s - 1) * a;
  return {
    ogeler: liste.slice(bas, bas + a),
    devam: bas + a < liste.length,
    toplam: liste.length,
    sayfa: s,
    adet: a,
  };
}
