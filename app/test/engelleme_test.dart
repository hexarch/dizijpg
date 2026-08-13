import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/engellenen_kullanicilar.dart';
import 'package:dizijpg/ekranlar/kullanici_profil.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KULLANICI ENGELLEME — istemci tarafı (istek md. 19).
///
/// "Engellenen kişinin paylaşımları, yorumları, hiçbir şeyi görünmeyecek ve
///  iki taraf ASLA birbirine mesaj atamayacak."
///
/// İÇERİK SÜZME SUNUCUDA yapılır (bkz. backend/test/engelleme.test.js); bu
/// dosya istemcinin ÜÇ sorumluluğunu kilitler:
///
///   1. ENGELLEME ONAY İSTER. Yıkıcı ve yan etkili bir eylem: karşılıklı takip
///      KOPAR ve engel kaldırılsa bile geri gelmez. Onaysız bir menü öğesi,
///      yanlış dokunuşla takip ilişkisini sessizce silerdi.
///   2. ENGELLİ PROFİLDE Takip/Mesaj DÜĞMELERİ ÇİZİLMEZ. Çizilseydi kullanıcı
///      "Mesaj"a basar ve kesin 403 alacak bir eylemin hata mesajını okurdu.
///   3. ENGELİ KALDIRMANIN BİR YOLU HEP VAR. Engellenen kişi aramada ve
///      listelerde görünmediği için, geri alma yolu olmasa engel FİİLEN
///      KALICI olurdu — Ayarlar > Engellenen kullanıcılar ekranı tam bunun
///      için var.
///
/// Ayrıca "engeli kaldır" onay İSTEMEZ: onarıcı eylem, kaybı yok.

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// `GET /profil/:ad` yanıtı. `engel` YALNIZ engelleyen tarafa gönderilir —
/// sunucu kararının aynısı (karşı taraf beni engellediyse bayrak GELMEZ).
Map<String, dynamic> _profil({bool engel = false}) => {
  'id': 42,
  'kullanici_adi': 'kotuadam',
  'avatar': null,
  'kapak': null,
  'bio': engel ? null : 'Merhaba ben biriyim',
  'ulke': null,
  'sosyal': engel ? null : const <dynamic>[],
  'olusturma': '2026-01-01T00:00:00Z',
  'izlenenler_gizli': false,
  'yorumlar_gizli': false,
  'yanitlar_gizli': false,
  'testci': false,
  'misafir': false,
  'ben_mi': false,
  'takip_ediyorum': false,
  'engelledim': engel,
  if (engel) 'engel': true,
  'uyum': null,
  'istatistik': const {
    'bolum': 0,
    'film': 0,
    'dizi': 0,
    'takipci': 0,
    'takip_edilen': 0,
    'yorum': 0,
    'toplam_goruntulenme': 0,
    'toplam_begeni': 0,
    'tahmini_dakika': 0,
  },
  'rozetler': const <dynamic>[],
  'listeler': const <dynamic>[],
  'incelemeler': const <dynamic>[],
  'yorumlar': const <dynamic>[],
  'icerikler': const <String, dynamic>{},
  'izlenenler': const <dynamic>[],
};

int _engelleCagri = 0;
List<Map<String, dynamic>> _engellenenler = [];
bool _engelleHata = false;

/// Profil ucu her çağrıldığında GÜNCEL durumu döndürsün: ekran engelledikten
/// sonra profili TAZELİYOR (sunucu artık içeriği süzüyor), sahte sunucu da
/// öyle davranmalı — yoksa test gerçekte olmayan bir akışı doğrular.
bool _engelliDurum = false;

void _sunucu() {
  _engelleCagri = 0;
  _engelleHata = false;
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (yol.startsWith('/api/engelle/')) {
      _engelleCagri++;
      if (_engelleHata) return _json({'hata': 'Sunucu hatası'}, 500);
      _engelliDurum = !_engelliDurum;
      return _json({'engellendi': _engelliDurum});
    }
    if (yol == '/api/engellenenler') {
      return _json({'kullanicilar': _engellenenler});
    }
    if (yol.startsWith('/api/profil/')) {
      return _json(_profil(engel: _engelliDurum));
    }
    return _json(const <String, dynamic>{});
  });
}

Future<void> _oturumKur() async {
  SharedPreferences.setMockInitialValues({
    'token': 'sahte',
    'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'ben'}),
  });
  await Api.tokenYukle();
}

Future<Widget> _sar(Widget cocuk) async {
  await _oturumKur();
  final oturum = Oturum();
  await oturum.yukle();
  return ChangeNotifierProvider<Oturum>.value(
    value: oturum,
    child: MaterialApp(home: cocuk),
  );
}

void main() {
  setUp(() {
    _engelliDurum = false;
    _engellenenler = [];
    _sunucu();
  });

  // =========================================================================
  // 1. PROFİL — engelle akışı ve onay
  // =========================================================================

  testWidgets('ENGELLE onay ister; İptal edilirse sunucuya İSTEK GİTMEZ', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _sar(const KullaniciProfilEkrani(kullaniciAdi: 'kotuadam')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Engelle').last);
    await tester.pumpAndSettle();

    // Onay penceresi açıldı mı? (Yıkıcı eylem — sessiz uygulanmamalı.)
    expect(find.byType(AlertDialog), findsOneWidget);
    // Kullanıcı ne kaybedeceğini BİLMELİ: takip bağının koptuğu yazıyor.
    expect(find.textContaining('takip'), findsWidgets);

    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();
    expect(_engelleCagri, 0, reason: 'iptal edilen onay istek atmamalı');
  });

  testWidgets('ONAYLANINCA engellenir ve profil SUNUCUDAN tazelenir', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _sar(const KullaniciProfilEkrani(kullaniciAdi: 'kotuadam')),
    );
    await tester.pumpAndSettle();

    // Engel yokken Takip/Mesaj düğmeleri duruyor.
    expect(find.text('Takip Et'), findsOneWidget);
    expect(find.text('Mesaj'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Engelle').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Engelle'));
    await tester.pumpAndSettle();

    expect(_engelleCagri, 1);
    // Durum kartı geldi, Takip/Mesaj GİTTİ.
    expect(find.text('Bu kullanıcıyı engelledin'), findsOneWidget);
    expect(find.text('Engeli kaldır'), findsWidgets);
    expect(find.text('Takip Et'), findsNothing);
    expect(
      find.text('Mesaj'),
      findsNothing,
      reason: 'engellediğin kişiye mesaj düğmesi çizilmemeli (kesin 403)',
    );
  });

  testWidgets('ENGELLİ PROFİLDE içerik sekmeleri HİÇ çizilmez', (tester) async {
    _engelliDurum = true; // profil doğrudan engelli açılıyor
    await tester.pumpWidget(
      await _sar(const KullaniciProfilEkrani(kullaniciAdi: 'kotuadam')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bu kullanıcıyı engelledin'), findsOneWidget);
    // Sunucu boş liste döndüğü için sekme içeriği "Bu kullanıcı henüz bir şey
    // izlememiş" gibi YANLIŞ bir sebep gösterirdi; doğru sebep kartta yazıyor.
    expect(find.textContaining('henüz bir şey izlememiş'), findsNothing);
    // bio da sunucuda NULL'lanıyor — ekranda kalıntı olmamalı.
    expect(find.text('Merhaba ben biriyim'), findsNothing);
  });

  testWidgets('ENGELİ KALDIRMA onay İSTEMEZ (onarıcı eylem)', (tester) async {
    _engelliDurum = true;
    await tester.pumpWidget(
      await _sar(const KullaniciProfilEkrani(kullaniciAdi: 'kotuadam')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Engeli kaldır'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing, reason: 'onay sorulmamalı');
    expect(_engelleCagri, 1);
    // Profil tazelendi: içerik geri geldi.
    expect(find.text('Bu kullanıcıyı engelledin'), findsNothing);
    expect(find.text('Takip Et'), findsOneWidget);
    expect(find.text('Merhaba ben biriyim'), findsOneWidget);
  });

  testWidgets('MENÜDE etiket duruma göre değişir', (tester) async {
    _engelliDurum = true;
    await tester.pumpWidget(
      await _sar(const KullaniciProfilEkrani(kullaniciAdi: 'kotuadam')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Engeli kaldır'), findsWidgets);
    expect(find.text('Engelle'), findsNothing);
  });

  // =========================================================================
  // 2. ENGELLENEN KULLANICILAR EKRANI
  // =========================================================================

  testWidgets('LİSTE: engellenenler avatar + adla listelenir', (tester) async {
    _engellenenler = [
      {'id': 42, 'kullanici_adi': 'kotuadam', 'avatar': null},
      {'id': 43, 'kullanici_adi': 'digeri', 'avatar': null},
    ];
    await tester.pumpWidget(await _sar(const EngellenenKullanicilarEkrani()));
    await tester.pumpAndSettle();

    expect(find.text('@kotuadam'), findsOneWidget);
    expect(find.text('@digeri'), findsOneWidget);
    expect(find.text('Engeli kaldır'), findsNWidgets(2));
  });

  testWidgets('LİSTE BOŞSA yol gösteren boş durum çıkar', (tester) async {
    await tester.pumpWidget(await _sar(const EngellenenKullanicilarEkrani()));
    await tester.pumpAndSettle();

    expect(find.text('Engellediğin kimse yok'), findsOneWidget);
    // Boş durum ne yapılacağını SÖYLEMELİ (yalnız "yok" demek yetmez).
    expect(find.textContaining('üç nokta'), findsOneWidget);
  });

  testWidgets('LİSTE: engeli kaldır satırı düşürür ve İSTEK atar', (
    tester,
  ) async {
    _engellenenler = [
      {'id': 42, 'kullanici_adi': 'kotuadam', 'avatar': null},
      {'id': 43, 'kullanici_adi': 'digeri', 'avatar': null},
    ];
    await tester.pumpWidget(await _sar(const EngellenenKullanicilarEkrani()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('engelli-kotuadam')),
        matching: find.text('Engeli kaldır'),
      ),
    );
    await tester.pumpAndSettle();

    expect(_engelleCagri, 1);
    expect(find.text('@kotuadam'), findsNothing);
    expect(find.text('@digeri'), findsOneWidget, reason: 'diğeri kalmalı');
  });

  testWidgets('LİSTE: sunucu hata verirse satır GERİ GELİR (iyimser geri al)', (
    tester,
  ) async {
    _engellenenler = [
      {'id': 42, 'kullanici_adi': 'kotuadam', 'avatar': null},
    ];
    await tester.pumpWidget(await _sar(const EngellenenKullanicilarEkrani()));
    await tester.pumpAndSettle();

    _engelleHata = true;
    await tester.tap(find.text('Engeli kaldır'));
    await tester.pumpAndSettle();

    // Sessiz başarısızlık YASAK: satır geri gelir + hata bildirilir.
    expect(find.text('@kotuadam'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
