// KULLANICI BİLDİRİMİ (13 Ağu): "Android'de Google ile girişte 'giriş
// başarısız' diyor." Sunucu kayıtlarında İZ YOKTU (istek hiç ulaşmamış),
// ekranda da yalnız çevrilmiş genel metin vardı → hangi Play Services
// hatası olduğu (10 mu 16 mı) ayırt edilemedi.
//
// Bu testler `googleHataKodu`nun gerçek PlatformException metinlerinden kodu
// çıkardığını ve kod yokken ARTIK PARANTEZ bırakmadığını kilitler.
import 'package:dizijpg/google_kapisi.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ApiException: 10 (DEVELOPER_ERROR) kodu çıkar', () {
    final e = PlatformException(
      code: 'sign_in_failed',
      message: 'com.google.android.gms.common.api.ApiException: 10: ',
    );
    expect(googleHataKodu(e), ' (10)');
  });

  test('ApiException: 16 (hesap yeniden doğrulama) kodu çıkar', () {
    final e = PlatformException(
      code: 'sign_in_failed',
      message:
          'com.google.android.gms.common.api.ApiException: 16: '
          '[16] Account reauth failed',
    );
    expect(googleHataKodu(e), ' (16)');
  });

  test('kullanıcı iptali (12501) kodu çıkar', () {
    final e = PlatformException(
      code: 'sign_in_failed',
      message: 'com.google.android.gms.common.api.ApiException: 12501: ',
    );
    expect(googleHataKodu(e), ' (12501)');
  });

  test('kodsuz hata BOŞ döner — arayüzde "( )" artığı olmaz', () {
    expect(googleHataKodu(Exception('ağ yok')), '');
    expect(googleHataKodu(null), '');
  });

  test(
    'döndürülen kuyruk metnin sonuna eklenebilir biçimde (boşluk+parantez)',
    () {
      final e = PlatformException(
        code: 'sign_in_failed',
        message: 'com.google.android.gms.common.api.ApiException: 7: ',
      );
      expect(
        'Google girişi başarısız${googleHataKodu(e)}',
        'Google girişi başarısız (7)',
      );
    },
  );
}
