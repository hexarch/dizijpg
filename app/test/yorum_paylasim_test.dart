// YORUMU ARKADAŞA GÖNDERME (13 Eyl 2026 isteği, birebir): "gönderideki
// yorumlara basılı tutunca instagramdaki gibi arkadaşlarıma
// gönderebilmeliyim; mesajlar kısmında da gönderi ve gönderinin altında solu
// %10 boş kalacak şekilde sağa doğru kullanıcı logosu ve yorum olmalı, yorum
// eğer uzunsa alt satıra inmeli."
//
// İki uç kilitleniyor:
//   1. GÖNDERME — yanıt satırına BASILI TUTUNCA paylaşım sheet'i açılır.
//   2. GÖRÜNÜM — sohbetteki kart üst gönderinin, altında %10 girintili
//      avatar + yorum satırı var ve uzun yorum SARILIR (tek satırda kesilmez).
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/kesfet_akis.dart'
    show SikEmojiler, YanitlarSheet;
import 'package:dizijpg/ekranlar/ortak.dart' show Oturum;
import 'package:dizijpg/ekranlar/sohbet.dart' show PaylasilanGonderi;
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

// ---------------------------------------------------------------------------
// 1) GÖNDERME: yanıta basılı tutunca paylaşım sheet'i
// ---------------------------------------------------------------------------
final _gonderi = <String, dynamic>{
  'id': 42,
  'kullanici_id': 1,
  'kullanici_adi': 'alcelik',
  'avatar': null,
  'metin': 'Ana gönderi',
  'tur': 'tv',
  'tmdb_id': 100,
  'medya': <String>[],
  'begeni': 0,
  'yanit': 1,
  'goruntulenme': 0,
  'spoiler': false,
  'tarih': '2026-09-13T10:00:00Z',
};

final _yanit = <String, dynamic>{
  'id': 43,
  'kullanici_id': 2,
  'kullanici_adi': 'melisa',
  'avatar': null,
  'metin': 'bu sahne efsaneydi',
  'medya': <String>[],
  'tarih': '2026-09-13T11:00:00Z',
  'ust_id': 42,
  'tur': 'tv',
  'tmdb_id': 100,
  'begeni': 0,
  'begendim': false,
  'goruntulenme': 0,
  'spoiler': false,
};

Future<void> _sheetKur(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  SikEmojiler.onbellek = const ['😂', '❤️', '🔥', '👏', '😍', '😮', '😢', '👍'];
  Api.istemci = MockClient((istek) async {
    if (istek.url.path.contains('/paylas-hedefler')) {
      return _json({
        'kullanicilar': [
          {'id': 7, 'kullanici_adi': 'cem', 'avatar': null},
        ],
      });
    }
    if (istek.url.path.contains('/yorumlar/')) {
      return _json({
        'yorumlar': [_gonderi, _yanit],
      });
    }
    return _json(const <String, dynamic>{});
  });
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum()..kullanici = {'id': 1, 'kullanici_adi': 'alcelik'},
      child: MaterialApp(
        theme: diziTema(acik: false),
        home: Scaffold(body: YanitlarSheet(yorum: _gonderi)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

// ---------------------------------------------------------------------------
// 2) GÖRÜNÜM: sohbetteki "gönderi + altında yorum" önizlemesi
// ---------------------------------------------------------------------------
Map<String, dynamic> _onizleme({String yorumMetni = 'kısa yorum'}) => {
  'id': 43,
  'ust_id': 42,
  // Kart ÜST gönderinin (sunucu böyle döndürüyor)
  'kullanici_adi': 'alcelik',
  'metin': 'Ana gönderi',
  'kapak': null,
  'medya_oran': null,
  'yorum': {
    'kullanici_adi': 'melisa',
    'avatar': null,
    'metin': yorumMetni,
    'medya': null,
  },
};

Future<void> _onizlemeKur(
  WidgetTester tester,
  Map<String, dynamic> gonderi,
) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: diziTema(acik: false),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: PaylasilanGonderi(
            gonderi: gonderi,
            onTap: () {},
            yaziRengi: DiziRenkler.metin,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  tearDown(() => SikEmojiler.onbellek = null);

  group('GÖNDERME — yanıta basılı tutunca paylaşım sheet i açılır', () {
    testWidgets('uzun basış paylaşım sheet ini açar', (tester) async {
      await _sheetKur(tester);
      expect(find.text('bu sahne efsaneydi'), findsOneWidget);
      await tester.longPress(find.text('bu sahne efsaneydi'));
      await tester.pumpAndSettle();
      expect(
        find.byIcon(Icons.send_outlined),
        findsOneWidget,
        reason: 'Paylaş sheet i açılmalı (başlığında gönder ikonu var).',
      );
      expect(
        find.text('@cem'),
        findsOneWidget,
        reason: 'DM hedefi listelenir (dokununca yorum ona gider)',
      );
    });

    testWidgets('KISA dokunuş sheet i AÇMAZ (yanlışlıkla açılmasın)', (
      tester,
    ) async {
      await _sheetKur(tester);
      await tester.tap(find.text('bu sahne efsaneydi'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.send_outlined), findsNothing);
    });
  });

  group('GÖRÜNÜM — sohbette gönderi + altında yorum', () {
    testWidgets('yorum satırı çizilir: avatarın yanında @ad + metin', (
      tester,
    ) async {
      await _onizlemeKur(tester, _onizleme());
      expect(find.byKey(const Key('paylasilan-yorum')), findsOneWidget);
      final metin = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('paylasilan-yorum')),
          matching: find.byType(Text),
        ),
      );
      expect(metin.textSpan!.toPlainText(), '@melisa kısa yorum');
    });

    testWidgets('SOLU %10 BOŞ: girinti kartın onda biri', (tester) async {
      await _onizlemeKur(tester, _onizleme());
      final p = tester.widget<Padding>(
        find.byKey(const Key('paylasilan-yorum')),
      );
      final kenar = p.padding as EdgeInsets;
      // Kapaksız gönderide kart genişliği azamiEn (220) → girinti 22.
      expect(kenar.left, closeTo(PaylasilanGonderi.azamiEn * 0.10, 0.01));
    });

    testWidgets('UZUN yorum alt satıra iner, taşma çizilmez', (tester) async {
      await _onizlemeKur(
        tester,
        _onizleme(
          yorumMetni:
              'bu dizinin final sahnesini defalarca izledim ve her seferinde '
              'aynı yerde tüylerim diken diken oluyor',
        ),
      );
      final metin = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('paylasilan-yorum')),
          matching: find.byType(Text),
        ),
      );
      final kutu = tester.renderObject<RenderBox>(
        find.descendant(
          of: find.byKey(const Key('paylasilan-yorum')),
          matching: find.byType(Text),
        ),
      );
      expect(metin.maxLines, greaterThan(1));
      expect(
        kutu.size.height,
        greaterThan(20),
        reason: 'Tek satırda kalmamalı — sarmalı.',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('YORUMSUZ gönderide ek satır YOK (eski davranış)', (
      tester,
    ) async {
      final g = _onizleme()..remove('yorum');
      await _onizlemeKur(tester, g);
      expect(find.byKey(const Key('paylasilan-yorum')), findsNothing);
    });
  });
}
