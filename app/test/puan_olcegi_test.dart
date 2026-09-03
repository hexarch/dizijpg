// Puan ölçeği — kanonik DB 1-100 ↔ kullanıcının SEÇTİĞİ görünüm ölçeği (5-100).
//
// 7 Ağu 2026: sunucunun SSR sayfası ve JSON-LD'si "10/10" basarken uygulama
// aynı puanı "5.0" gösteriyordu. Doğru olan UYGULAMA tarafıdır (5 yıldız).
// Dönüşüm altı dosyada kopyalanmıştı; artık yalnız lib/puan.dart'ta.
//
// 26 Ağu 2026: ölçek KULLANICI TERCİHİ oldu (5/10/50/100 ya da arası) ve
// kanonik depolama 1-100'e taşındı (migrasyon-2026-08-26b.sql). Ölçek
// değiştirmek VERİ GÖÇÜ DEĞİLDİR — bu testlerin ana yükü budur.
//
// Bu testler kilitler:
//  1. dönüşümün matematiği (her iki yön, her ölçek),
//  2. ölçek değiştirmenin puanı KAYBETMEDİĞİ,
//  3. dönüşümün TEK YERDEN geldiği (kaynak taraması),
//  4. kanonik değerin ekranda seçilen ölçekte göründüğü (widget).
import 'dart:convert';
import 'dart:io';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/puan.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kisi = {
  'id': 6193,
  'name': 'Leonardo DiCaprio',
  'biography': '',
  'profile_path': null,
};

http.Client _sahteIstemci() => MockClient((istek) async {
  final yol = istek.url.path;
  http.Response cevap(Object govde) => http.Response(
    jsonEncode(govde),
    200,
    headers: {'content-type': 'application/json'},
  );
  if (yol == '/api/tmdb/person/6193') return cevap(_kisi);
  if (yol == '/api/tmdb/person/6193/combined_credits') {
    return cevap({'cast': <dynamic>[], 'crew': <dynamic>[]});
  }
  if (yol.startsWith('/api/incelemeler/')) {
    // Sunucu `avg(puan)` sonucunu METİN olarak da döndürebiliyor.
    // 100 = kanonik ölçeğin tavanı (migrasyon-2026-08-26b.sql sonrası).
    return cevap({'incelemeler': <dynamic>[], 'ortalama': '100'});
  }
  if (yol.startsWith('/api/yorumlar/')) return cevap({'yorumlar': <dynamic>[]});
  if (yol.startsWith('/api/tepkiler/')) {
    return cevap({'sayilar': <String, dynamic>{}, 'benim': null});
  }
  return cevap(<String, dynamic>{});
});

void main() {
  group('ölçek dönüşümü', () {
    test('kanonik puan (1-100) → 5 yıldız', () {
      expect(yildiza(100, olcek: 5), 5);
      expect(yildiza(80, olcek: 5), 4);
      expect(yildiza(60, olcek: 5), 3);
      expect(yildiza(20, olcek: 5), 1);
      expect(yildiza(null, olcek: 5), 0);
      // Ara değerler yuvarlanır (90 → 4.5 → 5).
      expect(yildiza(90, olcek: 5), 5);
      expect(yildiza(70, olcek: 5), 4);
      // Metin gelen alanlar da çevrilir; bozuk değer 0.
      expect(yildiza('80', olcek: 5), 4);
      expect(yildiza('abc', olcek: 5), 0);
      // Ölçek dışına taşan bozuk veri kırpılır.
      expect(yildiza(999, olcek: 5), 5);
    });

    test('kanonik puan → geniş ölçekler', () {
      // 100'lük ölçek kanonikle BİREBİR: kayıp yok.
      expect(yildiza(73, olcek: 100), 73);
      expect(dbPuani(73, olcek: 100), 73);
      // 10'luk ölçek: 73 → 7,3 → 7.
      expect(yildiza(73, olcek: 10), 7);
      // 50'lik ölçek: 73 → 36,5 → 37 (yukarı).
      expect(yildiza(73, olcek: 50), 37);
    });

    test('ortalama metni: dar ölçekte ondalıklı, geniş ölçekte tam', () {
      expect(yildizOrtalamaMetni(100, olcek: 5), '5.0');
      expect(yildizOrtalamaMetni('84', olcek: 5), '4.2');
      expect(yildizOrtalamaMetni(70, olcek: 5), '3.5');
      expect(yildizOrtalamaMetni(null, olcek: 5), '0.0');
      // 10'un üstünde ondalık SAHTE KESİNLİK: atılır.
      expect(yildizOrtalamaMetni('83.4', olcek: 100), '83');
      expect(yildizOrtalamaMetni(50, olcek: 50), '25');
    });

    test('yıldız → kanonik puan (yazma yönü)', () {
      expect(dbPuani(5, olcek: 5), 100);
      expect(dbPuani(3, olcek: 5), 60);
      expect(dbPuani(0, olcek: 5), 0);
      expect(dbPuani(7, olcek: 10), 70);
      // Gidiş-dönüş HER ölçekte kayıpsız: kullanıcının kendi ölçeğinde
      // verdiği puan aynı ölçekte birebir geri okunmalı.
      for (final olcek in [5, 10, 20, 50, 100]) {
        for (var y = 0; y <= olcek; y++) {
          expect(
            yildiza(dbPuani(y, olcek: olcek), olcek: olcek),
            y,
            reason: 'ölçek $olcek, yıldız $y gidiş-dönüşte kaydı',
          );
        }
      }
    });

    test('ÖLÇEK DEĞİŞTİRMEK PUANI SİLMEZ (yeniden ifade eder)', () {
      // 5'lik ölçekte verilen 4 yıldız kanonikte 80'dir.
      final kanonik = dbPuani(4, olcek: 5);
      expect(kanonik, 80);
      // Kullanıcı 100'lük ölçeğe geçer: puanı kaybolmaz, 80 görür.
      expect(yildiza(kanonik, olcek: 100), 80);
      // 10'luğa geçer: 8 görür.
      expect(yildiza(kanonik, olcek: 10), 8);
      // 5'liğe döner: yine 4.
      expect(yildiza(kanonik, olcek: 5), 4);
    });

    test('dbPuani en az 1 döner (geniş ölçekte sıfıra yuvarlanmaz)', () {
      // 100'lük ölçekte 1 → 1. Yuvarlama 0 verseydi "puan yok" sayılır ve
      // kullanıcının verdiği en düşük puan sessizce SİLİNİRDİ.
      expect(dbPuani(1, olcek: 100), 1);
      expect(dbPuani(1, olcek: 50), 2);
      expect(dbPuani(1, olcek: 5), 20);
    });

    test('ölçek sabitleri ve satır/sheet eşiği', () {
      expect(dbPuanAzami, 100);
      expect(puanOlcekAlt, 5);
      expect(puanOlcekUst, 100);
      expect(puanOlcekSecenekleri, [5, 10, 50, 100]);
      // 10 ve altı satır, üstü sheet (kullanıcı kararı).
      expect(yildizSatiriOlur(5), isTrue);
      expect(yildizSatiriOlur(10), isTrue);
      expect(yildizSatiriOlur(11), isFalse);
      expect(yildizSatiriOlur(100), isFalse);
    });

    test('dağılım kovaları: 10 üstü ölçek 10 kovaya gruplanır', () {
      expect(dagilimKovaSayisi(5), 5);
      expect(dagilimKovaSayisi(10), 10);
      expect(dagilimKovaSayisi(50), 10);
      expect(dagilimKovaSayisi(100), 10);
      // Etiketler: dar ölçekte tek sayı, geniş ölçekte aralık.
      expect(dagilimKovaEtiketi(4, 5), '4');
      expect(dagilimKovaEtiketi(10, 100), '91-100');
      expect(dagilimKovaEtiketi(1, 100), '1-10');
      expect(dagilimKovaEtiketi(1, 50), '1-5');
    });

    test('yıldız ikon boyu ölçekle küçülür (satır taşmasın)', () {
      expect(yildizIkonBoyu(5), 30);
      expect(yildizIkonBoyu(10), 22);
      // Ara ölçek: 5 ile 10 arasında kalır.
      final ara = yildizIkonBoyu(8);
      expect(ara, lessThan(30));
      expect(ara, greaterThan(22));
    });
  });

  test('ölçek dönüşümü lib/ içinde TEK YERDE', () {
    // NEDEN kaynak taraması: hata tam da kopyalanmış `/ 2` satırlarından
    // doğdu. Yeni bir ekran kendi dönüşümünü yazarsa bu test kırmızıya döner.
    // Kanonik ölçek 1-100 olduğundan kaçak dönüşüm artık `/ 100`, `* 100`,
    // `/ 20`, `* 20` ya da eski `/ 2` biçiminde görünür — hepsini ara.
    final kacak = RegExp(
      r'(?:puan|ortalama)[^\n;]*(?:/|\*)\s*(?:2|20|100)\b'
      r'|(?:/|\*)\s*(?:2|20|100)[^\n;]*(?:puan|ortalama)',
      caseSensitive: false,
    );
    final bulgular = <String>[];
    for (final girdi in Directory('lib').listSync(recursive: true)) {
      if (girdi is! File || !girdi.path.endsWith('.dart')) continue;
      // puan.dart dönüşümün KENDİSİ; diller/ yalnız çeviri metni tutar.
      if (girdi.path.endsWith('lib/puan.dart')) continue;
      if (girdi.path.contains('lib/diller/')) continue;
      final satirlar = girdi.readAsLinesSync();
      for (var i = 0; i < satirlar.length; i++) {
        final s = satirlar[i].trim();
        if (s.startsWith('//')) continue;
        // YANLIŞ POZİTİF AYIKLAMA: "ortalama" sözcüğü puan dışında da geçiyor
        // (gönderi istatistiğindeki `ortalamaIzlenme * 100` bir YÜZDE hesabı,
        // ölçek çevirisi değil). Yüzde/oran/izlenme bağlamı elenir — aksi
        // halde test kalıcı kırmızı kalır ve gerçek kaçağı gizler.
        if (RegExp(
          r'izlenme|yuzde|yüzde|oran|percent',
          caseSensitive: false,
        ).hasMatch(satirlar[i])) {
          continue;
        }
        if (kacak.hasMatch(satirlar[i])) {
          bulgular.add('${girdi.path}:${i + 1}: $s');
        }
      }
    }
    expect(
      bulgular,
      isEmpty,
      reason:
          'Ölçek dönüşümü kopyalanmış. lib/puan.dart içindeki yildiza / '
          'yildizOrtalamaMetni / dbPuani kullan:\n${bulgular.join('\n')}',
    );
  });

  testWidgets('kanonik 100 ortalaması varsayılan 5 yıldız ölçeğinde 5.0', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    Oturum.karsilamaGerekli = false;

    SharedPreferences.setMockInitialValues({});
    await Api.tokenYukle();
    Api.istemci = _sahteIstemci();
    final oturum = Oturum();
    await oturum.yukle();
    final yonlendirici = yonlendiriciOlustur(oturum);
    await tester.pumpWidget(
      ChangeNotifierProvider<Oturum>.value(
        value: oturum,
        child: MaterialApp.router(
          routerConfig: yonlendirici,
          theme: diziTema(acik: false),
        ),
      ),
    );
    await tester.pump();
    yonlendirici.go('/kisi/6193');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    // Sunucu kanonik 100 dedi; varsayılan ölçekte (5) kullanıcı 5.0 görür.
    //
    // findRichText: 3 Eyl 2026'dan beri ortalama, yıldız şeridinin ufak alt
    // yazısında İKİNCİ BİR SPAN olarak duruyor ("4/5  ·  ort. 5.0"), ayrı bir
    // `Text` değil (bkz. YildizPuan.altYaziEki). Gösterilen metin AYNI.
    // (`text` DEĞİL `textContaining`: span'in düz metni "4/5  ·  ort. 5.0",
    // tam eşleşme aramaz.)
    expect(find.textContaining('ort. 5.0', findRichText: true), findsOneWidget);
    expect(find.textContaining('ort. 100.0', findRichText: true), findsNothing);
  });

  testWidgets('ölçek 100 iken AYNI ortalama 100 olarak görünür', (
    tester,
  ) async {
    // ÖLÇEK GÖRÜNÜMDÜR kilidi: aynı sunucu yanıtı, farklı ölçek, farklı
    // ekran metni — ama ALTTAKİ VERİ aynı. Ölçek değişince ekranın gerçekten
    // yeniden çizildiğini de doğrular (OlcekDinler karışımı).
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(() => PuanOlcegi.deger.value = puanOlcekAlt);
    Oturum.karsilamaGerekli = false;

    SharedPreferences.setMockInitialValues({});
    await Api.tokenYukle();
    Api.istemci = _sahteIstemci();
    PuanOlcegi.deger.value = 100;
    final oturum = Oturum();
    await oturum.yukle();
    final yonlendirici = yonlendiriciOlustur(oturum);
    await tester.pumpWidget(
      ChangeNotifierProvider<Oturum>.value(
        value: oturum,
        child: MaterialApp.router(
          routerConfig: yonlendirici,
          theme: diziTema(acik: false),
        ),
      ),
    );
    await tester.pump();
    yonlendirici.go('/kisi/6193');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    // 100'lük ölçekte ondalık atılır (sahte kesinlik) → "ort. 100".
    // Bu ölçekte şerit ROZET kipinde; ek rozetin sağında ayrı `Text` olarak
    // çizilir (kaybolmaması bilerek kilitli — bkz. `_rozet`).
    expect(find.textContaining('ort. 100', findRichText: true), findsOneWidget);
    expect(find.textContaining('ort. 5.0', findRichText: true), findsNothing);
  });
}
