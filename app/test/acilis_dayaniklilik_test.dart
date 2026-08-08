// Açılış dayanıklılığı — "beyaz sayfa, konsolda hata yok" ailesi.
//
// `main()` içindeki her `await` doğrudan runZonedGuarded'a düşüyordu: TEK bir
// hazırlık adımı patlarsa `runApp` hiç çağrılmıyor, kullanıcı bembeyaz sayfa
// görüyordu. `PlatformDispatcher.onError` `true` döndüğü için konsolda da iz
// kalmıyordu. [acilisAdimi] adımı yalıtır; uygulama yine açılır.
import 'package:dizijpg/api.dart';
import 'package:dizijpg/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Hata bildirimi ağa çıkmasın; adımın kendisi ölçülüyor.
    Api.istemci = MockClient((_) async => http.Response('{}', 200));
  });

  test('patlayan açılış adımı YUKARI TAŞINMAZ (runApp yine çalışır)', () async {
    var sonraki = false;

    await acilisAdimi('deneme', () async {
      throw StateError('Firebase çekirdeği başlatılamadı');
    });
    // Buraya gelinebiliyorsa main akışı kesilmemiş demektir.
    sonraki = true;

    expect(sonraki, isTrue);
  });

  test('senkron fırlatan adım da yutulur', () async {
    await acilisAdimi('senkron', () => throw Exception('bozuk'));
    expect(true, isTrue); // istisna yayılmadı
  });

  test('sağlıklı adım normal çalışır', () async {
    var calisti = false;
    await acilisAdimi('sağlıklı', () async => calisti = true);
    expect(calisti, isTrue);
  });
}
