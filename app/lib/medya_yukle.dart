import 'dart:typed_data' show Uint8List;

import 'package:image_picker/image_picker.dart' show XFile;

import 'api.dart';
import 'ceviri.dart';
import 'video_islem.dart' show videoAzamiBayt;

/// Seçilen dosyaları `/medya` ucuna yükleyen ORTAK hat.
///
/// NEDEN ORTAK (7 Ağu 2026): aynı döngü üç ekranda ayrı ayrı yazılmıştı —
/// yorum kutusu (`yorumlar.dart`), sohbet eki (`sohbet.dart`) ve Reels yanıtı
/// (`kesfet_akis.dart`). Üçü de ayrı sınırlarla çalışıyordu: yorum 100 MB,
/// sohbet **30 MB** (metni de sabit yazılmıştı), Reels yanıtı yine 30 MB.
/// Sunucu ise üçünde de AYNI ucu kullanıyor (`express.raw({limit:'100mb'})`,
/// nginx `client_max_body_size 105m`), yani iki ekran 40-70 MB'lık videoları
/// sunucu kabul edecekken istemcide sebepsiz reddediyordu. Tek fonksiyon =
/// tek sınır, tek hata metni, tek kısmi-başarı davranışı.
///
/// SIRAYLA yüklenir (paralel değil): 10 dosyayı aynı anda belleğe alıp paralel
/// POST etmek düşük bellekli Android'de uygulamayı öldürür ve sunucunun
/// yükleme hız limitini tetikler. Sıralı akış ayrıca "3/5" gibi dürüst bir
/// ilerleme göstergesi verir (ui-ux-pro-max, Feedback/Progress Indicators).

/// TEK DOSYA sınırı — sunucudaki `/medya` sınırının BİREBİR aynısı.
///
/// Bu sınırı 100 MB tutmak "100 MB'lık video yükleyin" demek DEĞİL: 20 MB'ı
/// aşan videolar `videoHazirla` ile cihazda 720p/5 Mbps'e sıkıştırılıyor,
/// yani pratikte yüklenen dosya çoğu zaman 5-12 MB. Sınır yalnız sıkıştırma
/// yapılamayan hâller (web, kodlaması başarısız kaynak) için tavandır.
const medyaAzamiBayt = videoAzamiBayt;

/// TEK GÖNDERİDEKİ TOPLAM sınır. Tek dosya 100 MB × 10 = 1 GB eder; bunu
/// mobil veriyle yüklemek gerçekçi değil ve yarısında kopan bir yükleme
/// kullanıcıyı en çok yoran hata.
const medyaToplamAzamiBayt = 100 * 1024 * 1024;

/// Bir yükleme turunun sonucu — KISMİ BAŞARI dâhil.
class MedyaYuklemeSonuc {
  /// Sunucuya giren dosyalar, SEÇİM SIRASIYLA: `{yol, video}`.
  final List<Map<String, dynamic>> yuklenen;

  /// Denenen dosya sayısı.
  final int denenen;

  /// İlk somut hata metni — kullanıcı NEDENİNİ öğrensin ("Dosya en fazla
  /// 100 MB olabilir" ile "sunucu hatası" farklı şeyler.)
  final String? hata;

  const MedyaYuklemeSonuc({
    required this.yuklenen,
    required this.denenen,
    this.hata,
  });

  int get basarisiz => denenen - yuklenen.length;

  /// Hepsi yüklendi mi?
  bool get tamam => basarisiz == 0;

  /// Kullanıcıya gösterilecek uyarı; her şey yolundaysa **null**.
  ///
  /// BAŞARIDA SnackBar YOK: sonuç zaten görünür (ek karosu / mesaj baloncuğu
  /// belirir). Gereksiz onay mesajı basmak sonraki gerçek hatayı da gürültüye
  /// çevirir. Ama sessiz KAYIP da yok: bir dosya düştüyse kaçının düştüğü
  /// söylenir (ui-ux-pro-max, Feedback/Confirmation Messages: "Don't: Silent
  /// success" — burada görünür sonuç o onayın kendisidir).
  String? get bildirim {
    if (tamam) return null;
    if (yuklenen.isEmpty) return hata ?? 'Hiçbir medya yüklenemedi'.c;
    return '{} medya eklendi, {} yüklenemedi'.cf([yuklenen.length, basarisiz]);
  }
}

/// [dosyalar]ı sırayla `/medya`ya yükler. **ASLA fırlatmaz**: bir dosya
/// patlarsa geri kalanı yüklenmeye devam eder, sonuç [MedyaYuklemeSonuc]
/// içinde döner. Çağıran `bildirim`i SnackBar'a basar.
///
/// [toplamAzamiBayt] `null` verilirse toplam sınır UYGULANMAZ — tek dosyalık
/// akışlarda (sohbet eki) toplam = tek dosya olduğu için ikinci bir kapı
/// yalnız kafa karıştırırdı.
///
/// [adim] her dosyadan sonra (başarılı ya da değil) kaçının bittiğiyle
/// çağrılır; çağıran ilerleme çubuğunu buradan besler.
Future<MedyaYuklemeSonuc> medyalariYukle(
  List<XFile> dosyalar, {
  int azamiBayt = medyaAzamiBayt,
  int? toplamAzamiBayt = medyaToplamAzamiBayt,
  void Function(int biten)? adim,
}) async {
  final yuklenen = <Map<String, dynamic>>[];
  var toplamBayt = 0;
  var biten = 0;
  String? hata;
  for (final dosya in dosyalar) {
    try {
      final veri = await dosya.readAsBytes();
      if (veri.length > azamiBayt) {
        throw ApiHata(
          'Dosya en fazla {} MB olabilir'.cf([azamiBayt ~/ (1024 * 1024)]),
        );
      }
      toplamBayt += veri.length;
      if (toplamAzamiBayt != null && toplamBayt > toplamAzamiBayt) {
        throw ApiHata(
          'Tek yorumda toplam {} MB medya yükleyebilirsin'.cf([
            toplamAzamiBayt ~/ (1024 * 1024),
          ]),
        );
      }
      final d = await _yukleDenemeli(veri);
      yuklenen.add({'yol': d['yol'], 'video': d['video']});
    } on ApiHata catch (e) {
      // Sunucunun bilinçli reddi (kota, tür, boyut): metni zaten anlamlı.
      hata ??= e.mesaj.c;
    } catch (_) {
      // Taşıma katmanı (soket kopması, zaman aşımı): ham İngilizce istisna
      // metni ("ClientException: Connection closed...") kullanıcıya hiçbir
      // şey söylemiyordu — 23 Ağu 2026'da canlıda ölçüldü (nginx 499, dakika
      // içinde vazgeçilmiş videolu yorum). Tek tekrar da burada denendi
      // ([_yukleDenemeli]); yine düştüyse dürüst ve çevrili tek cümle kalır.
      hata ??= 'Bağlantı koptu'.c;
    }
    adim?.call(++biten);
  }
  return MedyaYuklemeSonuc(
    yuklenen: yuklenen,
    denenen: dosyalar.length,
    hata: hata,
  );
}

/// Ağ kopmasına karşı TEK otomatik tekrar.
///
/// [ApiHata] TEKRARLANMAZ: o, sunucunun bilinçli reddidir (kota dolu, tür
/// desteklenmiyor, dosya büyük) — aynı gövdeye aynı cevap gelir, tekrar yalnız
/// kullanıcıyı bekletir. Tekrar edilen yalnız TAŞIMA hatalarıdır (soket
/// kopması, zaman aşımı): mobil ağda birkaç saniyelik kopma olağandır ve
/// 23 Ağu 2026'da canlıda tam bu yüzden bir videolu yorum yarıda kalmıştır
/// (nginx 499). İki saniyelik ara, hücre ağının toparlanma payıdır.
///
/// NEDEN 1 TEKRAR: dosya onlarca MB olabilir; üç-beş kez yeniden göndermek
/// kullanıcıyı dakikalarca bekletir ve saatlik yükleme bütçesini boşa yakar.
Future<Map<String, dynamic>> _yukleDenemeli(Uint8List veri) async {
  try {
    return await Api.medyaYukle(veri);
  } on ApiHata {
    rethrow;
  } catch (_) {
    await Future<void>.delayed(const Duration(seconds: 2));
    return Api.medyaYukle(veri);
  }
}
