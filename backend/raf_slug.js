// Raf başlığından KALICI adres parçası — `app/lib/ekranlar/kesfet.dart`
// içindeki `rafSlug`ın BİREBİR aynısı (17 Eyl 2026).
//
// NEDEN İKİ KOPYA VAR: slug istemcide `/raf/<slug>` adresini üretiyor,
// sunucuda ise rafın KİMLİĞİ (akışta "bir süre gösterme" kaydı bu slug'a
// yazılıyor). İki taraf aynı dizeyi üretmezse kullanıcı gizlediği raf
// kaybolmamış gibi görür. `test/raf_slug.test.js` başlık→slug eşlemesini
// kilitler; Dart tarafı da aynı örnekleri test ediyor.
//
// TÜRKÇE HARFLER ÖNCE KATLANIR, SONRA KÜÇÜLTÜLÜR: JS'te de 'İ'.toLowerCase()
// iki kod birimi ('i' + U+0307 birleşen nokta) üretir ve adreste GÖRÜNMEZ bir
// karakter bırakırdı.
const KATLA = {
  'Ç': 'C', 'Ğ': 'G', 'İ': 'I', 'Ö': 'O', 'Ş': 'S', 'Ü': 'U',
  'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u',
};

export function rafSlug(baslik) {
  const duz = [...String(baslik ?? '')].map((h) => KATLA[h] ?? h).join('');
  return duz
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}
