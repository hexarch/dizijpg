// Puan verirken yazılan metin İNCELEMEYE değil YORUMA gider.
//
// Kullanıcı (30 Ağu 2026): "dizi ve filme puan verirken yapılan yorum
// inceleme kısmına gidiyor ama yorum kısmına gitmeli; şu an inceleme kısmı
// olmamalı, o ileriki aşamada moderatörler için açık olacak."
//
// ⚠ NEDEN WIDGET TESTİ YOK: `puanlaVeKaydet` sheet'i kapanırken çerçeve
// `_FocusInheritedScope` üzerinde `_dependents.isEmpty` iddiası atıyor —
// yazı kutusu odaktayken sheet kapanıp controller atıldığı için. Bu iddia
// ÖNCEDEN DE VARDI (aynı gün eski `puan_sheet.dart` ile ölçülerek
// doğrulandı; hiçbir test "Kaydet"e basmadığı için görülmemiş) ve teardown
// sırasında atıldığı için `takeException` ile boşaltılamıyor. Sürüm
// derlemesinde iddialar kapalı olduğundan kullanıcıya çıkmıyor.
// Akış bu yüzden EMÜLATÖRDE elle geçilerek doğrulandı (CLAUDE.md md.7'nin
// ikinci yolu). Ayrı bir iş olarak duruyor.
import 'package:dizijpg/ekranlar/detay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inceleme bölümü KAPALI (moderatör aşamasına kadar)', () {
    // Bölüm silinmedi, bayrakla kapatıldı: moderatör ekranı gelince
    // `true` yapılınca eski davranış birebir döner. `puanlar.yorum`daki
    // veri de yerinde duruyor.
    expect(incelemeBolumuAcik, isFalse);
  });
}
