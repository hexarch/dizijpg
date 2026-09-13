import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/kesfet_akis.dart' show YanitlarSheet;
import 'package:dizijpg/ekranlar/yorumlar.dart';
import 'package:dizijpg/yorum_agaci.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// YANITIN YANITI GİRİNTİLİ ÇİZİLİR — 13 Eylül 2026.
///
/// Kullanıcı (birebir): "akışta bir gönderiye yorum yapmış birinin yorumuna
/// yanıt verince gönderiye yorum yapmış gibi oluyorum ama oysa Reddit'teki gibi
/// gönderideki yorumun altına azıcık sağlı olarak yorum gözükmeliydi."
///
/// ESKİ DAVRANIŞ: sunucu yanıtın yanıtını KÖK gönderiye bağlıyor
/// (`gercekUst = u.ust_id || u.id`) ve hangi yoruma yanıt verildiği HİÇBİR
/// yerde tutulmuyordu; iki satır da listede aynı hizada, ayırt edilemez
/// duruyordu.
///
/// YENİ: `yanit_id` sütunu (migrasyon-2026-09-13.sql) + [yorumAgaci]. `ust_id`
/// DEĞİŞMEDİ — "ust_id IS NULL = gönderi" sözleşmesine bağlı 20'den fazla sorgu
/// aynen çalışıyor.
///
/// Bu dosyanın kilitlediği dört şey:
///   1. Ağaç sırası + derinlik (saf mantık).
///   2. `yanit_id` taşımayan ESKİ satırlar düz kalır (geriye dönük uyum).
///   3. Yanıt sheet'inde (akış) girinti GERÇEKTEN çiziliyor.
///   4. İçerik sayfasındaki yorum kartında da aynısı.
http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _yorum(
  int id, {
  required String metin,
  required String ad,
  int? ustId,
  int? yanitId,
}) => {
  'id': id,
  'kullanici_id': 40 + id,
  'kullanici_adi': ad,
  'avatar': null,
  'metin': metin,
  'medya': const <dynamic>[],
  'tarih': '2026-09-13T10:00:00Z',
  'tur': 'movie',
  'tmdb_id': 550,
  'sezon': null,
  'bolum': null,
  'ust_id': ustId,
  'yanit_id': yanitId,
  'goruntulenme': 0,
  'spoiler': false,
  'begeni': 0,
  'begendim': false,
  'kaynak_dil': 'tr',
  'ceviri_metin': null,
};

/// Gönderi (1) · ona yorum (2) · o yoruma yanıt (3) · gönderiye ikinci yorum (4)
List<Map<String, dynamic>> get _isParcacigi => [
  _yorum(1, metin: 'gönderi', ad: 'ali'),
  _yorum(2, metin: 'ilk yorum', ad: 'ayse', ustId: 1),
  _yorum(3, metin: 'yoruma yanıt', ad: 'mehmet', ustId: 1, yanitId: 2),
  _yorum(4, metin: 'gönderiye ikinci yorum', ad: 'zeynep', ustId: 1),
];

void _ag(List<Map<String, dynamic>> yorumlar) {
  Api.istemci = MockClient((istek) async {
    if (istek.url.path.contains('/yorumlar/')) {
      return _json({'yorumlar': yorumlar});
    }
    return _json(const {});
  });
}

Future<void> _oturum(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
}

Widget _agac(Widget govde) => ChangeNotifierProvider<Oturum>.value(
  value: Oturum()..kullanici = {'id': 1, 'kullanici_adi': 'ben'},
  child: MaterialApp(home: Scaffold(body: govde)),
);

void main() {
  group('yorumAgaci', () {
    test('yanıtın yanıtı, yanıtladığı satırın ALTINDA ve bir kademe içeride', () {
      final agac = yorumAgaci(_isParcacigi.sublist(1), 1);
      expect(agac.map((d) => d.id).toList(), [2, 3, 4]);
      expect(agac.map((d) => d.derinlik).toList(), [0, 1, 0]);
    });

    test('zincir derinleşir: yanıtın yanıtının yanıtı 2. kademe', () {
      final agac = yorumAgaci([
        _yorum(2, metin: 'a', ad: 'a', ustId: 1),
        _yorum(3, metin: 'b', ad: 'b', ustId: 1, yanitId: 2),
        _yorum(4, metin: 'c', ad: 'c', ustId: 1, yanitId: 3),
      ], 1);
      expect(agac.map((d) => d.derinlik).toList(), [0, 1, 2]);
    });

    test('ESKİ satırlar (yanit_id yok) düz kalır — geçmiş bozulmaz', () {
      final agac = yorumAgaci([
        _yorum(2, metin: 'a', ad: 'a', ustId: 1),
        _yorum(3, metin: 'b', ad: 'b', ustId: 1),
      ], 1);
      expect(agac.every((d) => d.derinlik == 0), isTrue);
    });

    test('hedefi listede olmayan yanıt öksüz kalmaz, köke düşer', () {
      // 9 numaralı yorum silinmiş / engellenen kişinin ve süzülmüş.
      final agac = yorumAgaci([
        _yorum(3, metin: 'b', ad: 'b', ustId: 1, yanitId: 9),
      ], 1);
      expect(agac.single.derinlik, 0);
    });

    test('bozuk veri döngü yaratamaz (hedef kendinden YENİ olamaz)', () {
      final agac = yorumAgaci([
        _yorum(2, metin: 'a', ad: 'a', ustId: 1, yanitId: 3),
        _yorum(3, metin: 'b', ad: 'b', ustId: 1, yanitId: 2),
      ], 1);
      expect(agac.length, 2, reason: 'Her satır TAM BİR KEZ çizilmeli.');
      expect(agac.map((d) => d.id).toList(), [2, 3]);
    });
  });

  testWidgets('AKIŞ yanıt sheet\'i: yanıtın yanıtı sağa kaymış çizilir', (
    tester,
  ) async {
    await _oturum(tester);
    _ag(_isParcacigi);
    await tester.pumpWidget(
      _agac(YanitlarSheet(yorum: _isParcacigi.first)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final ilk = tester.getTopLeft(find.text('@ayse')).dx;
    final yanitinYaniti = tester.getTopLeft(find.text('@mehmet')).dx;
    final ikinci = tester.getTopLeft(find.text('@zeynep')).dx;

    expect(
      yanitinYaniti,
      greaterThan(ilk),
      reason: 'Yanıtın yanıtı GİRİNTİLİ — kullanıcının bildirdiği hatanın özü.',
    );
    expect(
      ikinci,
      ilk,
      reason: 'Gönderiye doğrudan yazılan yorum hizasını korur.',
    );
    // Sıra da ağaca uymalı: yanıt, yanıtladığı satırın hemen ALTINDA.
    expect(
      tester.getTopLeft(find.text('@mehmet')).dy,
      greaterThan(tester.getTopLeft(find.text('@ayse')).dy),
    );
    expect(
      tester.getTopLeft(find.text('@zeynep')).dy,
      greaterThan(tester.getTopLeft(find.text('@mehmet')).dy),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('İÇERİK SAYFASI yorum kartı: aynı girinti orada da var', (
    tester,
  ) async {
    await _oturum(tester);
    _ag(_isParcacigi);
    await tester.pumpWidget(
      _agac(
        const SingleChildScrollView(
          child: YorumBolumu(tur: 'movie', tmdbId: 550),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('@mehmet'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('@mehmet')).dx,
      greaterThan(tester.getTopLeft(find.text('@ayse')).dx),
      reason: 'Dizi/film sayfasındaki liste ile akış AYNI kalıbı çizmeli.',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
