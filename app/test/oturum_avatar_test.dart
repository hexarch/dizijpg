import 'dart:convert';
import 'dart:io';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/kesfet_akis.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KULLANICI HATASI (7-8 Ağu 2026): "yorumlara yorum yapmadaki sol taraftaki
/// avatarda profil resmim gözükmüyor".
///
/// --- KÖK NEDEN (canlı API ile kanıtlandı) ---
///  1. Sunucuda resim VAR:
///     `GET /api/profil/alcelik` →
///     `"avatar":"/avatarlar/avatar3-1786094173967.gif"`
///  2. `dosyaUrl()` sarmalayıcısı da DOĞRU:
///     `https://dizijpg.com/api/avatarlar/avatar3-1786094173967.gif`
///     → HTTP 200, image/gif, 238 KB.
///  3. Kopan katman OTURUM: `POST /auth/giris` yanıtı yalnız
///     `{id, kullanici_adi, email, misafir}` döner (backend/server.js:1888-1891),
///     `avatar` YOK. `Oturum.yukle()` da yalnız SharedPreferences'ı okur.
///     Sonuç: `Oturum.kullanici['avatar']` null → yorum yazma satırındaki
///     `KullaniciAvatari(url: null)` kişi ikonuna düşüyordu.
///
/// Yani hata `dosyaUrl()`de de widget'ta da DEĞİL; oturum nesnesi avatarı hiç
/// taşımıyordu. Düzeltme tamamen istemcide: giriş sonrası ve açılışta
/// `/profilim` ile tazeleme (`Oturum.tazele`, `main.dart`).
///
/// Bu dosya o zinciri uçtan uca kilitler.

const _avatarYol = '/avatarlar/avatar3-1786094173967.gif';

/// Giriş ucunun GERÇEK yanıt şekli: avatar YOK (server.js:1888-1891).
Map<String, dynamic> _girisYaniti() => {
  'id': 3,
  'kullanici_adi': 'alcelik',
  'email': 'a@b.c',
  'misafir': false,
};

/// `/profilim` yanıtı: avatar BURADA var (server.js:3053-3058).
Map<String, dynamic> _profilim() => {
  'id': 3,
  'kullanici_adi': 'alcelik',
  'email': 'a@b.c',
  'avatar': _avatarYol,
  'kapak': null,
  'bio': null,
  'ulke': null,
  'sosyal': <dynamic>[],
  'testci': true,
};

/// Atılan istek yollarını kaydeden sahte istemci.
http.Client _sahteIstemci(List<String> gunluk) => MockClient((istek) async {
  gunluk.add(istek.url.path);
  Map<String, dynamic> govde = {};
  if (istek.url.path.startsWith('/api/profilim')) govde = _profilim();
  return http.Response(
    jsonEncode(govde),
    200,
    headers: {'content-type': 'application/json'},
  );
});

Future<Oturum> _girisliOturum(List<String> gunluk) async {
  SharedPreferences.setMockInitialValues({'token': 'sahte-jwt'});
  await Api.tokenYukle();
  Api.istemci = _sahteIstemci(gunluk);
  return Oturum();
}

/// Ağaçtaki TEK avatar bileşeni (yazma satırının solundaki).
KullaniciAvatari _avatar(WidgetTester tester) =>
    tester.widget<KullaniciAvatari>(find.byType(KullaniciAvatari).first);

const _emojiler = ['😂', '❤️', '🔥', '👏', '😍', '😮', '😢', '👍'];

final _yorum = <String, dynamic>{
  'id': 42,
  'kullanici_id': 1,
  'kullanici_adi': 'test',
  'avatar': null,
  'metin': 'Ana gönderi',
  'tur': 'tv',
  'tmdb_id': 100,
  'medya': <String>[],
  'begeni': 0,
  'yanit': 0,
  'goruntulenme': 0,
  'spoiler': false,
  'tarih': '2026-08-02T10:00:00Z',
};

/// Reels yanıt sayfası (yorumlara yorum yazma kutusunun bulunduğu ekran).
Future<void> _yanitSayfasi(WidgetTester tester, Oturum oturum) async {
  SikEmojiler.onbellek = _emojiler;
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp(
        theme: diziTema(acik: false),
        home: Scaffold(body: YanitlarSheet(yorum: _yorum)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  tearDown(() => SikEmojiler.onbellek = null);

  group('KÖK NEDEN — oturum nesnesi avatarı taşımıyordu', () {
    test(
      'GİRİŞ yanıtında avatar YOK → oturum /profilim ile tazelenir',
      () async {
        final gunluk = <String>[];
        final oturum = await _girisliOturum(gunluk);

        // Giriş ekranının yaptığı şey birebir bu:
        await oturum.girisYapildi(_girisYaniti());
        // `unawaited(tazele())` bir sonraki mikro-görevde biter.
        await Future<void>.delayed(Duration.zero);

        expect(
          gunluk.where((y) => y.startsWith('/api/profilim')).length,
          1,
          reason: 'avatarsız giriş yanıtı /profilim ile tazelenmeli',
        );
        expect(
          oturum.kullanici!['avatar'],
          _avatarYol,
          reason: 'avatar oturuma girmeli — hatanın kırıldığı yer tam burası',
        );
        // Giriş yanıtındaki alanlar KORUNUR (atama değil birleştirme).
        expect(oturum.kullanici!['misafir'], false);
      },
    );

    test('avatar anahtarı OLAN birleştirmede gereksiz istek atılmaz', () async {
      final gunluk = <String>[];
      final oturum = await _girisliOturum(gunluk);

      // Ayarlar'daki `{...?oturum.kullanici, 'avatar': yol}` birleştirmesi.
      await oturum.girisYapildi({..._girisYaniti(), 'avatar': '/a/yeni.png'});
      await Future<void>.delayed(Duration.zero);

      expect(
        gunluk.where((y) => y.startsWith('/api/profilim')),
        isEmpty,
        reason: 'avatar zaten elde: boşa ağ isteği atılmamalı',
      );
      expect(oturum.kullanici!['avatar'], '/a/yeni.png');
    });

    // `main()` widget testinde çalıştırılamaz (runApp + eklentiler), ama açılış
    // tazelemesi SESSİZCE silinirse "eskiden giriş yapmış" herkes avatarsız
    // kalır — kullanıcının bildirdiği durumun ta kendisi. Bu yüzden çağrının
    // varlığı kaynaktan doğrulanır (sürüm sabitiyle aynı yaklaşım:
    // surum_tutarlilik_test.dart).
    test('main.dart açılışta oturumu tazeler (kaynak kontrolü)', () {
      // Yorum satırları ELENİR: çağrıyı "// ..." hâline getirmek de silmektir.
      final kod = File('lib/main.dart')
          .readAsLinesSync()
          .where((s) => !s.trimLeft().startsWith('//'))
          .join('\n');
      expect(
        RegExp(r'oturum\.tazele\(\)').hasMatch(kod),
        isTrue,
        reason:
            'main.dart açılışta oturum.tazele() çağırmalı; yoksa prefs\'ten '
            'gelen avatarsız oturum hiç tazelenmez',
      );
    });

    test(
      'ZATEN GİRİŞLİ oturum (prefs): yukle() avatarsız, tazele() doldurur',
      () async {
        final gunluk = <String>[];
        // Düzeltmeden ÖNCE kaydedilmiş oturum: prefs'te avatar yok.
        SharedPreferences.setMockInitialValues({
          'token': 'sahte-jwt',
          'kullanici': jsonEncode(_girisYaniti()),
        });
        await Api.tokenYukle();
        Api.istemci = _sahteIstemci(gunluk);

        final oturum = Oturum();
        await oturum.yukle();
        expect(
          oturum.kullanici!['avatar'],
          isNull,
          reason: 'yukle() yalnız prefs okur — hatanın kaynağı bu',
        );

        // main.dart açılışta bunu çağırır.
        await oturum.tazele();
        expect(oturum.kullanici!['avatar'], _avatarYol);
      },
    );
  });

  group('WIDGET — KullaniciAvatari', () {
    testWidgets('url VERİLİNCE resim çizilir, kişi ikonu yedeği çıkmaz', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: diziTema(acik: false),
          home: Scaffold(
            body: KullaniciAvatari(
              url: dosyaUrl(_avatarYol),
              kullaniciAdi: 'alcelik',
            ),
          ),
        ),
      );
      final cember = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(
        cember.backgroundImage,
        isNotNull,
        reason: 'avatar resmi zemin görseli olarak verilmeli',
      );
      expect(
        find.byIcon(Icons.person),
        findsNothing,
        reason: 'resim varken yedek ikon çizilmemeli',
      );
    });

    testWidgets('url YOKSA düzgün yedek (kişi ikonu) çizilir', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: diziTema(acik: false),
          home: const Scaffold(
            body: KullaniciAvatari(url: null, kullaniciAdi: 'alcelik'),
          ),
        ),
      );
      final cember = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(cember.backgroundImage, isNull);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    test('dosyaUrl göreli avatar yolunu TAM adrese çevirir', () {
      // Ham göreli yol tarayıcıya gitseydi 404 olurdu.
      expect(dosyaUrl(_avatarYol), '$apiTaban$_avatarYol');
      expect(dosyaUrl(_avatarYol)!.startsWith('https://'), isTrue);
      expect(dosyaUrl(null), isNull);
    });
  });

  group('UÇTAN UCA — yorum yazma satırındaki avatar', () {
    testWidgets('oturumda avatar VARSA yazma satırında resim çizilir', (
      tester,
    ) async {
      final gunluk = <String>[];
      final oturum = await _girisliOturum(gunluk);
      await oturum.girisYapildi({..._girisYaniti(), 'avatar': _avatarYol});

      await _yanitSayfasi(tester, oturum);

      expect(
        _avatar(tester).url,
        dosyaUrl(_avatarYol),
        reason: 'yazma satırındaki avatara TAM adres geçmeli',
      );
    });

    testWidgets('GERİLEME TESTİ: avatarsız giriş yanıtı sonrası da resim gelir', (
      tester,
    ) async {
      final gunluk = <String>[];
      final oturum = await _girisliOturum(gunluk);
      // Kullanıcının yaşadığı senaryo: giriş yanıtında avatar yok.
      await oturum.girisYapildi(_girisYaniti());

      await _yanitSayfasi(tester, oturum);
      await tester.pump(); // tazele() → notifyListeners → yeniden çizim

      expect(
        _avatar(tester).url,
        dosyaUrl(_avatarYol),
        reason:
            'oturum /profilim ile tazelenmeliydi; null kalırsa kişi ikonu çizilir',
      );
    });
  });
}
