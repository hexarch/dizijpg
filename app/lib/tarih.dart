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
