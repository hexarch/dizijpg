// GIF SEÇİCİ DÖRT YÜZEYE DE BAĞLI MI? (29 Ağu 2026)
//
// Ortak bir seçici yazmanın tek anlamı DÖRT yüzeyin de onu kullanmasıdır.
// Bir yüzey unutulursa kimse hata görmez: o ekranda GIF düğmesi ya hiç olmaz
// ya eski `FilePicker` yolunda kalır — ve arşiv o yüzeyden hiç beslenmez.
// Bu tam olarak `IcerikSecSheet`in başına gelen şeydi: sohbette özel bir kopya
// olarak yaşadı, akış kutusu ihtiyaç duyunca ortaklaştırıldı (bkz.
// icerik_sec.dart başlığı). Aynı ayrışma bir daha olmasın diye kilit burada.
//
// KAYNAK OKUMA, WIDGET AĞACI DEĞİL: dört ekranın hepsini gerçek veriyle
// kurmak (Reels video oynatıcısı, sohbet yoklaması, akış sağlayıcıları)
// testi kırılgan ve yavaş yapar. Ölçtüğümüz şey bir DAVRANIŞ değil bir
// BAĞLANTI: "bu dosya ortak seçiciyi çağırıyor mu?" — bunun doğru aracı
// kaynağı okumaktır. Seçicinin KENDİ davranışı `gif_secici_test.dart`ta
// gerçek widget testleriyle ölçülüyor.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ortak seçiciyi kullanması ZORUNLU dört yüzey.
const _yuzeyler = <String, String>{
  'Reels yanıt kutusu': 'lib/ekranlar/kesfet_akis.dart',
  'Sohbet/DM eki': 'lib/ekranlar/sohbet.dart',
  'Yorum yazma kutusu': 'lib/ekranlar/yorumlar.dart',
  'Akış paylaşım kutusu': 'lib/ekranlar/paylas_yorum.dart',
};

String _oku(String yol) {
  final d = File(yol);
  expect(d.existsSync(), isTrue, reason: '$yol yok');
  return d.readAsStringSync();
}

void main() {
  group('DÖRT YÜZEY ortak GIF seçicisine bağlı', () {
    _yuzeyler.forEach((ad, yol) {
      test('$ad → gifSecAc', () {
        final k = _oku(yol);
        expect(
          k.contains("import 'gif_sec.dart';"),
          isTrue,
          reason: '$ad ortak seçiciyi içe aktarmıyor',
        );
        expect(
          k.contains('gifSecAc(context)'),
          isTrue,
          reason: '$ad seçiciyi AÇMIYOR — o yüzeyden arşiv beslenmez',
        );
        expect(
          k.contains('gif_box_outlined'),
          isTrue,
          reason: '$ad üzerinde GIF düğmesi yok (kullanıcı seçiciye ulaşamaz)',
        );
      });
    });
  });

  test('Reels kutusu artık DOSYADAN seçmeye doğrudan gitmiyor', () {
    // Eski yol seçicinin İÇİNE taşındı ("GIF yükle"). Burada kalsaydı iki ayrı
    // GIF girişi olurdu ve yüklenen dosya arşive HİÇ kaydedilmezdi.
    final k = _oku('lib/ekranlar/kesfet_akis.dart');
    expect(
      k.contains('FilePicker.platform'),
      isFalse,
      reason: 'Reels hâlâ dosya seçiciyi doğrudan açıyor; arşiv beslenmez',
    );
  });

  test('DOSYADAN SEÇME YOLU KAYBOLMADI — seçicinin içinde', () {
    // Kullanıcı arşivde bulamadığında kilitlenmemeli. `file_picker` tam olarak
    // burada yaşamaya devam eder.
    final k = _oku('lib/ekranlar/gif_sec.dart');
    expect(k.contains('FilePicker.platform.pickFiles'), isTrue);
    expect(k.contains("allowedExtensions: ['gif']"), isTrue);
    // Yükleme mevcut medya boru hattından geçer (yeni hat KURULMADI).
    expect(k.contains('medyalariYukle('), isTrue);
    // ...ve arşive kaydedilir, yoksa yalnız o mesaja gider, seçicide durmaz.
    expect(k.contains("Api.post('/gif'"), isTrue);
  });

  test('ŞİKAYET YOLU var ve MEVCUT altyapıyı kullanır', () {
    final k = _oku('lib/ekranlar/gif_sec.dart');
    expect(
      k.contains("Api.sikayetEt('gif'"),
      isTrue,
      reason: 'GIF şikayeti yok ya da yeni bir altyapı uydurulmuş',
    );
  });

  test('SUNUCU SÜZGECİ İSTEMCİDE TAKLİT EDİLMİYOR', () {
    // +18 kilidi TEK yerde (sunucu) durmalı. İstemci "durum" alanına bakıp
    // kendi süzgecini kurarsa iki kural ayrışır ve biri gevşeyince sessizce
    // sızıntı olur. İstemci `durum`u YALNIZ rozet çizmek için okur.
    final k = _oku('lib/ekranlar/gif_sec.dart');
    expect(
      RegExp(r"where\(.*durum").hasMatch(k),
      isFalse,
      reason: 'istemci tarafında GIF durumu süzülüyor — kural ikiye ayrıldı',
    );
    expect(k.contains("g['durum'] == 'bekliyor'"), isTrue,
        reason: 'bekleyen rozeti kayboldu');
  });
}
