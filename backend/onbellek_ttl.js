// TMDB ARAMA yanıtları için İÇERİĞE BAKAN önbellek ömrü (TTL) seçicisi.
//
// NEDEN VAR: `tmdb_onbellek` satırlarının kendi son kullanma tarihi YOK —
// tazeliğe OKUYAN karar veriyor (`guncelleme > now() - ttl`). Arama uçları
// sabit uzun TTL verdiği için SIFIR SONUÇLU bir sorgu da günlerce "yok"
// diye servis ediliyordu: TMDB katalogu topluluk tarafından doldurulduğundan
// bugün yayınlanan bir dizi (ör. "Castle Walls") TMDB'ye EKLENDİKTEN sonra
// bile bizde bir hafta görünmüyordu. Yeni çıkan her yapımda tekrar eden bir
// şikâyet sınıfı.
//
// ÇÖZÜM: TTL artık yanıtın İÇERİĞİNDEN türetiliyor — sonuçsuz sorgu dakikalar,
// dolu sonuç eskisi gibi uzun süre yaşar. TTL okuma tarafında hesaplandığı
// için ÖNBELLEKTE ŞU AN DURAN eski sıfır sonuçlu satırlar da geriye dönük
// olarak kısa ömürlü sayılır (elle temizlik şart değil).
//
// SAF MODÜL: pg/express/env yok — davranışı `test/onbellek_ttl.test.js`
// gerçek fonksiyonlarla ölçer.

/// TMDB yanıtındaki sonuç sayısı.
/// - `/search/*` → `results`
/// - `/find/*`   → `tv_results` + `movie_results` + `person_results` ...
/// Tanınmayan/boş gövde 0 sayılır (en kötü ihtimalle kısa TTL — güvenli yön).
export function tmdbSonucSayisi(govde) {
  if (!govde || typeof govde !== 'object') return 0;
  if (Array.isArray(govde.results)) return govde.results.length;
  let toplam = 0;
  for (const [k, v] of Object.entries(govde)) {
    if (k.endsWith('_results') && Array.isArray(v)) toplam += v.length;
  }
  return toplam;
}

/// Yanıta göre TTL seçen bir geri çağrı üretir: `tmdbGetir(yol, secici)`.
///
/// EŞİKLER (gerekçe):
///  - 0 sonuç → `kisa` (15 dk): sorgunun karşılığı TMDB'de HENÜZ yok. Yeni
///    eklenen yapım en geç 15 dakikada görünür (hedef "yarım saat"in yarısı).
///  - 1-2 sonuç → `orta` (30 dk): TMDB araması gevşek eşleşir; aranan yapım
///    yokken de birkaç alakasız satır dönebilir ("Castle Walls" → "Castle").
///    Bu "neredeyse sonuçsuz" hâl de bayatlamamalı.
///  - 3+ sonuç → çağıranın verdiği `dolu` TTL (6 saat / 7 gün): gerçek bir
///    sorgu; TMDB'ye boşuna yük bindirmeden uzun süre önbellekte kalsın.
///
/// `azEsigi` çağıran başına ayarlanır: `/find/:tvdbId` gibi TEK sonuç dönen
/// (ve tek sonucu TAM İSABET olan) uçlarda 1 verilir — orada yalnız gerçekten
/// boş yanıt kısa ömürlüdür.
export function aramaTtlSecici({ dolu, kisa, orta, azEsigi = 3 }) {
  return (govde) => {
    const n = tmdbSonucSayisi(govde);
    if (n === 0) return kisa;
    if (n < azEsigi) return orta;
    return dolu;
  };
}

/// TTL'i çözer: sayı ise aynen, seçici (fonksiyon) ise gövdeye uygulanarak.
/// Geriye uyumluluğun tek noktası — mevcut çağıranlar sayı vermeye devam eder.
export function ttlCoz(ttl, govde) {
  return typeof ttl === 'function' ? ttl(govde) : ttl;
}
