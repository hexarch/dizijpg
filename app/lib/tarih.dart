/// İZLEME TARİHİ BİÇİMLENDİRME — tek kaynak.
///
/// ---------------------------------------------------------------------------
/// NEDEN `intl`in DateFormat'ı DEĞİL
/// ---------------------------------------------------------------------------
/// Uygulama `initializeDateFormatting()` çağırmıyor; `DateFormat('d MMMM y',
/// dil)` çağrısı yerel veri yüklü olmayan dillerde fırlatır. 45 dilin tarih
/// verisini paketlemek de derlemeyi büyütürdü.
///
/// Ay adları KARŞILAMA ekranının 12 çeviri anahtarından okunur
/// ([karsilamaAylar]) — aynı listeyi ikinci kez açmak, 45 dilde 12 anahtarı
/// boşuna çoğaltmak olurdu. Bu yaklaşım `istatistiklerim.dart`ta zaten
/// kullanılıyordu; buraya taşındı ki iki kopya ayrışmasın.
///
/// ---------------------------------------------------------------------------
/// YIL NE ZAMAN YAZILIR
/// ---------------------------------------------------------------------------
/// İÇİNDE BULUNULAN YILDA YAZILMAZ: "14 Ağustos" — bölüm listesi gibi dar
/// satırlarda her satıra "2026" eklemek bilgi taşımadan yer yer. Geçmiş
/// yıllarda tam yazılır ("14 Ağustos 2025"), çünkü orada yıl AYIRT EDİCİDİR.
/// `hepYil: true` ile bu davranış kapatılabilir (detay sayfasındaki tek
/// satırlık özet gibi, yılın hep görünmesi istenen yerler için).
library;

import 'ceviri.dart';
import 'ekranlar/karsilama.dart' show karsilamaAylar;

/// ISO 8601 metnini ("2026-08-14T09:12:00Z") okunur tarihe çevirir.
///
/// Çözülemeyen değerde girdiyi OLDUĞU GİBİ döndürür — ekranda ham metin
/// görmek, satırın sessizce boş kalmasından iyidir (hata görünür olur).
String tarihBicimle(Object? ham, {bool hepYil = false}) {
  final metin = ham?.toString() ?? '';
  if (metin.isEmpty) return '';
  final parca = metin.split('T').first.split('-');
  if (parca.length != 3) return metin;
  final yil = int.tryParse(parca[0]);
  final ay = int.tryParse(parca[1]);
  final gun = int.tryParse(parca[2]);
  if (yil == null || ay == null || gun == null || ay < 1 || ay > 12) {
    return metin;
  }
  final ayAdi = karsilamaAylar[ay - 1].c;
  final buYil = DateTime.now().year;
  return (hepYil || yil != buYil) ? '$gun $ayAdi $yil' : '$gun $ayAdi';
}

/// Sunucudan gelen izleme tarihini "yoksa null" biçimine indirger.
///
/// NEDEN AYRI YARDIMCI (27 Ağu 2026): sunucu, güvenilmeyen izleme tarihini
/// (toplu içe aktarım damgası) `null` döndürüyor. JSON'dan okunan değer
/// `(x ?? '').toString()` ile boş DİZGEYE dönüşürse, bölüm satırındaki
/// `izlenmeTarihi != null` kontrolünden GEÇER ve göz ikonunun yanına BOŞ bir
/// tarih basılır. Boşluğu null'a çevirmek tek satırlık bir iş ama iki ayrı
/// ekranda tekrarlanıyor; kopyalanınca biri unutulur.
String? izlemeTarihiVeyaNull(Object? ham) {
  final metin = (ham ?? '').toString().trim();
  return metin.isEmpty ? null : metin;
}

/// ISO tarihini SAYISAL biçime çevirir: "2008-01-20" → "20.01.2008".
///
/// NEDEN AYRI BİR BİÇİM (28 Ağu 2026, kullanıcı isteği): "dizilerde
/// sezonlardaki bölümleri listeleyince tarih yazıyor ya, orada ay ismi
/// kullanma sayı kullan, sadece ikisi için de". Bölüm satırı DAR ve satırda
/// İKİ tarih yan yana duruyor (yayın · izlenme); "20 Ocak 2008" gibi bir ad
/// satırın yarısını yiyordu. Ay adı yalnız o listede sayıya çevrildi —
/// [tarihBicimle] öteki 15 çağrı yerinde AYNEN duruyor (detay sayfasındaki
/// "Son izleme" satırı, istatistikler, karşılama…).
///
/// YIL KURALI [tarihBicimle] İLE BİREBİR AYNI: `hepYil` false iken içinde
/// bulunulan yılda yıl YAZILMAZ ("20.01"). Kullanıcı ay adını değiştirmemizi
/// istedi, yılın ne zaman görüneceğini değil — o karar (dar satır, "bu yıl"
/// baskın durum) korunuyor.
///
/// Çözülemeyen değerde girdiyi OLDUĞU GİBİ döndürür ([tarihBicimle] ile aynı
/// disiplin): ekranda ham metin görmek, satırın sessizce boş kalmasından iyi.
String tarihSayi(Object? ham, {bool hepYil = false}) {
  final metin = ham?.toString() ?? '';
  if (metin.isEmpty) return '';
  final parca = metin.split('T').first.split('-');
  if (parca.length != 3) return metin;
  final yil = int.tryParse(parca[0]);
  final ay = int.tryParse(parca[1]);
  final gun = int.tryParse(parca[2]);
  if (yil == null || ay == null || gun == null || ay < 1 || ay > 12) {
    return metin;
  }
  final iki = (int n) => n.toString().padLeft(2, '0');
  final buYil = DateTime.now().year;
  return (hepYil || yil != buYil)
      ? '${iki(gun)}.${iki(ay)}.$yil'
      : '${iki(gun)}.${iki(ay)}';
}

/// ISO tarihinden yaş — ölüm tarihi varsa yaş ORADA durur.
///
/// NEDEN ÖLÜM TARİHİNE BAKIYOR (14 Eyl 2026): kişi sayfasında doğum tarihinin
/// yanına yaş yazılacaktı. Yaşı körü körüne "bugün - doğum" diye hesaplamak
/// vefat etmiş oyuncular için YANLIŞ bir sayı üretir (Marlon Brando 1924
/// doğumlu; bugüne göre 102, oysa 80 yaşında öldü) ve sayfa onu yaşıyormuş
/// gibi gösterirdi. TMDB `deathday` alanını zaten döndürüyor.
///
/// Çözülemeyen/saçma değerde `null` döner (ham metin BASILMAZ — parantez
/// içinde çöp bir sayı, satırın hiç çıkmamasından kötüdür).
int? yasHesapla(Object? dogum, {Object? olum, DateTime? bugun}) {
  List<int>? parcala(Object? ham) {
    final p = (ham?.toString() ?? '').split('T').first.split('-');
    if (p.length != 3) return null;
    final y = int.tryParse(p[0]);
    final a = int.tryParse(p[1]);
    final g = int.tryParse(p[2]);
    if (y == null || a == null || g == null) return null;
    if (a < 1 || a > 12 || g < 1 || g > 31) return null;
    return [y, a, g];
  }

  final d = parcala(dogum);
  if (d == null) return null;
  final s = bugun ?? DateTime.now();
  final b = parcala(olum) ?? [s.year, s.month, s.day];
  var yas = b[0] - d[0];
  if (b[1] < d[1] || (b[1] == d[1] && b[2] < d[2])) yas -= 1;
  return (yas >= 0 && yas < 130) ? yas : null;
}

/// Kişi sayfasının doğum satırı: "1956-03-07 (70)", vefat edenlerde
/// "1924-04-03 – 2004-07-01 (80)".
///
/// NEDEN VEFAT EDENDE İKİ TARİH: yalnız doğum + "(80)" yazsaydık okur sayıyı
/// bugünkü yaş sanardı. Kısa çizgili aralık bunu TEK bakışta çözüyor ve YENİ
/// ÇEVİRİ METNİ GEREKTİRMİYOR (45 dilde "vefat" anahtarı açmak yerine tarih ve
/// sayı — her dilde aynı okunan işaretler).
String dogumYasMetni(Object? dogum, {Object? olum, DateTime? bugun}) {
  final d = (dogum?.toString() ?? '').split('T').first;
  if (d.isEmpty) return '';
  final o = (olum?.toString() ?? '').split('T').first;
  final yas = yasHesapla(dogum, olum: olum, bugun: bugun);
  final aralik = o.isEmpty ? d : '$d – $o';
  return yas == null ? aralik : '$aralik ($yas)';
}

/// Gönderi/yorum damgasını GÖRELİ zamana çevirir: "az önce", "12 dk önce",
/// "3 saat önce", "5 gün önce", "2 hafta önce".
///
/// NEDEN (15 Eyl 2026, kullanıcı isteği): "akışta paylaşılanlarda tarih
/// yazmak yerine önce dakika sonra saat sonra gün sonra hafta kullan".
/// Sosyal akışta "14 Ağustos" okurun kafasında bir çıkarma işlemi ister;
/// "5 gün önce" cevabın kendisidir.
///
/// EŞİKLER: 60 dk'ya kadar dakika, 24 saate kadar saat, 7 güne kadar gün,
/// 5 haftaya kadar hafta ("4 hafta önce"). Daha eskisi [tarihBicimle] ile
/// TAKVİM tarihine döner ("14 Ağustos", geçmiş yılda "14 Ağustos 2025") —
/// "37 hafta önce" kimseye bir şey söylemez, tarih söyler. Ay/yıl birimi
/// bilerek YOK: kullanıcı listesi haftada bitiyor.
///
/// Sunucu damgası UTC ISO ("…Z"); `DateTime.parse` bunu UTC üstünden okur,
/// [simdi] ile farkı dilimden bağımsızdır. Saat kayması (istemci saati
/// geride) negatif fark üretebilir; o durumda "az önce" basılır, "-3 dk
/// önce" değil. Çözülemeyen değerde girdinin TARİH kısmı döner (öteki
/// yardımcılarla aynı disiplin: ham metin, sessiz boşluktan iyidir).
///
/// ÇOĞUL: birim anahtarları [CeviriMetin.cs] ile tekil/çoğul seçer
/// ("1 hour ago" / "2 hours ago"); dakika her dilde kısaltma ("min").
String goreliZaman(Object? ham, {DateTime? simdi}) {
  final metin = ham?.toString() ?? '';
  if (metin.isEmpty) return '';
  final an = DateTime.tryParse(metin);
  if (an == null) return metin.split('T').first;
  final fark = (simdi ?? DateTime.now()).difference(an);
  if (fark.inMinutes < 1) return 'az önce'.c;
  if (fark.inMinutes < 60) return '{} dk önce'.cs(fark.inMinutes);
  if (fark.inHours < 24) return '{} saat önce'.cs(fark.inHours);
  if (fark.inDays < 7) return '{} gün önce'.cs(fark.inDays);
  if (fark.inDays < 35) return '{} hafta önce'.cs(fark.inDays ~/ 7);
  return tarihBicimle(metin);
}
