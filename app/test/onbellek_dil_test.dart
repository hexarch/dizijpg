// DİL DEĞİŞİNCE ÖNBELLEK ESKİ DİLİ GÖSTERİYOR (8 Ağu 2026).
//
// KÖK NEDEN: `Onbellek` anahtarları dilden bağımsızdı (`onb_takvim`). Oysa
// saklanan gövde DİLE BAĞLI: `Api._basliklar` her isteğe `X-Dil` koyuyor ve
// sunucu TMDB başlık/özetlerini o dilde döndürüyor (api.dart:109-118). Dil
// değişince ekran "önce önbellek" (SWR) kuralıyla ESKİ DİLDEKİ gövdeyi
// boyuyordu; taze yanıt gelene kadar kullanıcı yanlış dil görüyordu.
//
// ÇÖZÜM: anahtar dil kodunu taşır (`onb_takvim@en`) ve YAZARKEN aynı kaydın
// diğer dillerdeki kopyaları (ve dilsiz eski biçim) silinir.
// NEDEN DİL BAŞINA SAKLAMIYORUZ: /takvim gövdesi yüzlerce TMDB kaydı; web'de
// SharedPreferences localStorage demek ve kota köken başına ~5 MB. 45 dilin
// kopyasını tutmak kotayı yakar, kazancı ise yok denecek kadar az — kullanıcı
// pratikte tek dil kullanır ve SWR zaten her açılışta tazeliyor.
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/onbellek.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _dil(String kod) async {
  await Ceviri.sec(kod);
}

Future<List<String>> _onbellekAnahtarlari() async {
  final p = await SharedPreferences.getInstance();
  return p.getKeys().where((k) => k.startsWith('onb_')).toList()..sort();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ceviri.yukle();
    await _dil('tr');
  });

  test('anahtar dil kodunu taşır', () async {
    await Onbellek.yaz('takvim', {'a': 1});
    expect(await _onbellekAnahtarlari(), ['onb_takvim@tr']);
  });

  test('dil değişince ESKİ dilin kaydı okunmaz', () async {
    await Onbellek.yaz('takvim', {'takvim': 'türkçe gövde'});
    expect((await Onbellek.oku('takvim'))!['takvim'], 'türkçe gövde');

    await _dil('en');
    expect(
      await Onbellek.oku('takvim'),
      isNull,
      reason: 'İngilizce açılışta Türkçe gövde BOYANMAMALI',
    );
    expect(await Onbellek.okuKayit('takvim'), isNull);
  });

  test('yeni dile yazınca eski dilin kopyası silinir (kota)', () async {
    await Onbellek.yaz('takvim', {'v': 'tr'});
    await Onbellek.yaz('akis', {'v': 'tr'});
    await _dil('en');
    await Onbellek.yaz('takvim', {'v': 'en'});
    expect(
      await _onbellekAnahtarlari(),
      ['onb_akis@tr', 'onb_takvim@en'],
      reason: 'yalnız YAZILAN anahtarın eski dil kopyası düşer',
    );
    expect((await Onbellek.oku('takvim'))!['v'], 'en');
  });

  test('eski sürümden kalan DİLSİZ kayıt okunmaz ve temizlenir', () async {
    SharedPreferences.setMockInitialValues({
      'onb_takvim': '{"z":1,"v":{"takvim":"eski biçim"}}',
    });
    await Ceviri.yukle();
    await _dil('tr');
    expect(await Onbellek.oku('takvim'), isNull);
    await Onbellek.yaz('takvim', {'v': 'yeni'});
    expect(await _onbellekAnahtarlari(), ['onb_takvim@tr']);
  });

  test('temizle() bütün dillerin kayıtlarını siler', () async {
    await Onbellek.yaz('takvim', {'v': 'tr'});
    await _dil('en');
    await Onbellek.yaz('akis', {'v': 'en'});
    await Onbellek.temizle();
    expect(await _onbellekAnahtarlari(), isEmpty);
  });

  test('zaman damgası ve bayatlık dil ayrımından etkilenmez', () async {
    await Onbellek.yaz('profil', {'v': 1});
    final k = await Onbellek.okuKayit('profil');
    expect(k, isNotNull);
    expect(k!.zaman, isNotNull);
    expect(k.bayatMi(const Duration(days: 1)), isFalse);
  });
}
