import 'package:dizijpg/veri_tasarrufu.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Veri tasarrufu kuralları: Wi-Fi varsayılan KAPALI, mobil varsayılan AÇIK.
/// Bu testler ayarların sessizce ters çevrilmesine karşı koruma sağlar —
/// yanlış varsayılan kullanıcının mobil verisini harcar.
void main() {
  setUp(() {
    // Her testte temiz tercih deposu; yukle() bağlantı eklentisini bulamayıp
    // (test ortamında MethodChannel yok) Wi-Fi varsayar — bu beklenen davranış.
    SharedPreferences.setMockInitialValues({});
    VeriTasarrufu.mobilBaglanti.value = false;
  });

  test('varsayılanlar: Wi-Fi kapalı, mobil açık', () async {
    await VeriTasarrufu.yukle();
    expect(VeriTasarrufu.wifi.value, isFalse);
    expect(VeriTasarrufu.mobil.value, isTrue);
  });

  test('Wi-Fi bağlantısında ön yükleme serbest (varsayılan)', () async {
    await VeriTasarrufu.yukle();
    VeriTasarrufu.mobilBaglanti.value = false;
    expect(VeriTasarrufu.acik, isFalse);
    expect(VeriTasarrufu.onYuklemeSerbest, isTrue);
  });

  test('mobil bağlantıda ön yükleme kapalı (varsayılan)', () async {
    await VeriTasarrufu.yukle();
    VeriTasarrufu.mobilBaglanti.value = true;
    expect(VeriTasarrufu.acik, isTrue);
    expect(VeriTasarrufu.onYuklemeSerbest, isFalse);
  });

  test('her bağlantı kendi ayarına bakar', () async {
    await VeriTasarrufu.yukle();
    await VeriTasarrufu.wifiSec(true); // Wi-Fi tasarrufu açıldı
    await VeriTasarrufu.mobilSec(false); // mobil tasarrufu kapatıldı

    VeriTasarrufu.mobilBaglanti.value = false;
    expect(VeriTasarrufu.onYuklemeSerbest, isFalse, reason: 'Wi-Fi tasarrufu açık');

    VeriTasarrufu.mobilBaglanti.value = true;
    expect(VeriTasarrufu.onYuklemeSerbest, isTrue, reason: 'mobil tasarrufu kapalı');
  });

  test('seçimler kalıcı: yeniden yüklenince korunur', () async {
    await VeriTasarrufu.yukle();
    await VeriTasarrufu.wifiSec(true);
    await VeriTasarrufu.mobilSec(false);

    // Bellekteki değerleri bozup diskten okumaya zorla
    VeriTasarrufu.wifi.value = false;
    VeriTasarrufu.mobil.value = true;
    await VeriTasarrufu.yukle();

    expect(VeriTasarrufu.wifi.value, isTrue);
    expect(VeriTasarrufu.mobil.value, isFalse);
  });
}
