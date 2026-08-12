/// Puan ölçeği — TEK KAYNAK.
///
/// TARİHÇE / NEDEN: veritabanındaki `puanlar.puan` sütunu 1-10 tutar.
/// Uygulama 5 yıldızlı arayüze geçtiğinde şema DEĞİŞMEDİ; her ekran ölçeği
/// kendi içinde `/ 2` ve `* 2` yaparak çevirdi. Aynı hesap altı ayrı dosyada
/// kopyalanınca sunucunun SSR/JSON-LD çıktısı "10/10" derken uygulama aynı
/// puanı "5.0" gösteriyordu (7 Ağu 2026 SEO denetimi). Doğru olan uygulama
/// tarafıdır; çeviri ARTIK YALNIZ BURADA yapılır.
///
/// DİKKAT — TMDB ile karıştırma: TMDB'nin `vote_average` alanı 0-10'dur ve
/// KENDİ ölçeğinde gösterilir ("8.4 TMDB" / poster rozeti). Bu dosyadaki
/// dönüşümler yalnız dizi.jpg'nin KENDİ puanları (`puanlar` tablosu) içindir.
library;

/// Veritabanı ölçeğinin üst sınırı (`puanlar.puan`).
const int dbPuanAzami = 10;

/// Kullanıcıya gösterilen yıldız sayısı.
const int yildizAzami = 5;

/// Herhangi bir kaynaktan gelen puanı sayıya çevirir.
///
/// Sunucu `avg(puan)` sonucunu kimi uçta sayı, kimi uçta metin (`numeric`)
/// olarak döndürüyor; çağıran taraflar bu yüzden `num.tryParse('$x')`
/// kopyalıyordu.
num? puanSayisi(Object? ham) {
  if (ham == null) return null;
  if (ham is num) return ham;
  return num.tryParse('$ham');
}

/// DB puanı (1-10) → yıldız (0-5), tam sayı.
///
/// `null`/bozuk değer 0 döner: puanlanmamış demektir.
int yildiza(Object? dbPuan) {
  final p = puanSayisi(dbPuan) ?? 0;
  return (p / 2).round().clamp(0, yildizAzami);
}

/// DB ortalaması (1-10) → yıldız ortalaması (0-5), ondalıklı.
double yildizOrtalamasi(Object? dbOrtalama) {
  final p = puanSayisi(dbOrtalama) ?? 0;
  return (p / 2).clamp(0, yildizAzami).toDouble();
}

/// Ekranda gösterilecek ortalama metni: `4.2` (tek ondalık).
String yildizOrtalamaMetni(Object? dbOrtalama) =>
    yildizOrtalamasi(dbOrtalama).toStringAsFixed(1);

/// Yıldız (0-5) → DB puanı (0-10). Sunucuya YAZARKEN kullanılır.
int dbPuani(int yildiz) => yildiz.clamp(0, yildizAzami) * 2;

/// Sunucunun ham puan dağılımını (`[{puan: 1-10, adet: n}, ...]`) yıldız
/// kovalarına toplar. Anahtarlar HER ZAMAN 1..5, boş kovalar 0 ile doludur.
///
/// Kovalama [yildiza] ile yapılır — yani ekranda görünen yıldızla kovanın
/// yıldızı aynı işlevden çıkar. Sunucu bilerek ham ölçek gönderir: yuvarlamayı
/// orada da yapsaydık çeviri ikinci bir yerde yaşar ve iki taraf ayrışabilirdi
/// (bu dosyanın başlığındaki hatanın aynısı).
Map<int, int> yildizDagilimi(Object? ham) {
  final kovalar = <int, int>{for (var y = 1; y <= yildizAzami; y++) y: 0};
  if (ham is! List) return kovalar;
  for (final satir in ham) {
    if (satir is! Map) continue;
    final yildiz = yildiza(satir['puan']);
    // 0 = puansız/bozuk satır; kovası yok, sayılmaz.
    if (yildiz < 1) continue;
    final adet = (puanSayisi(satir['adet']) ?? 0).toInt();
    if (adet > 0) kovalar[yildiz] = kovalar[yildiz]! + adet;
  }
  return kovalar;
}
