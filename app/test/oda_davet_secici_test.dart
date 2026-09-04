// Oda daveti — KİŞİ SEÇİCİ testleri.
//
// İSTEK (4 Eyl 2026): "arkadaş davet ederken takipettiklerimden seç olsun ve
// son mesajlaştığı kişilere göre sıralansın" + "belki olmayan kullanıcıya
// istek gönderir bu hatayı ortadan kaldıralım".
//
// NEYİ KİLİTLİYOR: elle kullanıcı adı yazma yolunun AĞAÇTA OLMADIĞINI ve
// davetin yalnız listeden seçmeyle gittiğini. Bu iddia doğrudan kullanıcının
// şikâyetine karşılık gelir — var olmayan birine davet göndermek yapısal
// olarak imkânsız olmalı.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/ekranlar/ortak.dart' show IskeletListe;
import 'package:dizijpg/oda/oda_ekrani.dart';
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

const _benimId = 184;

Map<String, dynamic> _aday(
  String ad, {
  String durum = 'davet_edilebilir',
  int? sonMesaj,
}) => {
  'kullanici_adi': ad,
  'avatar': null,
  'son_mesaj': sonMesaj,
  'durum': durum,
};

/// Sunucuya giden istekler (sıra ve gövde dahil).
late List<String> gonderilen;

/// `/kullanici-ara` kaç kez çağrıldı — debounce kanıtı.
late int aramaSayisi;

void _sunucu({
  List<dynamic> adaylar = const [],
  List<dynamic> aramaSonucu = const [],
  bool davetHatasi = false,
}) {
  gonderilen = [];
  aramaSayisi = 0;
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    gonderilen.add('${istek.method} $yol ${istek.body}');
    if (yol.endsWith('/davet-adaylari')) {
      return _json({'adaylar': adaylar, 'kod': 'AB2CD3'});
    }
    if (yol == '/api/kullanici-ara') {
      aramaSayisi++;
      return _json({'kullanicilar': aramaSonucu});
    }
    if (yol.endsWith('/davet')) {
      if (davetHatasi) {
        return http.Response(
          jsonEncode({'hata': 'Oda dolu', 'kod': 'ODA_DOLU'}),
          409,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return _json({'tamam': true});
    }
    return _json({});
  });
}

Widget _sar(Widget cocuk) => ChangeNotifierProvider<Oturum>(
  create: (_) => Oturum()..kullanici = {'id': _benimId, 'kullanici_adi': 'ben'},
  child: MaterialApp(home: Scaffold(body: cocuk)),
);

Future<void> _kur(WidgetTester t) async {
  await t.pumpWidget(_sar(const OdaDavetSecici(odaId: 5)));
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ceviri.yukle();
  });

  testWidgets('liste çiziliyor ve SUNUCU SIRASI korunuyor', (t) async {
    // Sıralama sunucuda yapılıyor (son mesaja göre); istemci onu yeniden
    // sıralamamalı, yoksa "son mesajlaştığın kişi üstte" kuralı bozulur.
    _sunucu(
      adaylar: [
        _aday('ayse', sonMesaj: 3000),
        _aday('burak', sonMesaj: 2000),
        _aday('cem'),
      ],
    );
    await _kur(t);
    final satirlar = t
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data)
        .where((s) => s != null && s.startsWith('@'))
        .toList();
    expect(satirlar, ['@ayse', '@burak', '@cem']);
  });

  testWidgets(
    '"Davet et" ucu çağırıyor ve satır ANINDA "Davet edildi" oluyor',
    (t) async {
      _sunucu(adaylar: [_aday('ayse')]);
      await _kur(t);
      expect(find.text('Davet et'.c), findsOneWidget);
      await t.tap(find.text('Davet et'.c));
      await t.pump();
      // İYİMSER: sunucu yanıtı beklenmeden satır değişir.
      expect(find.text('Davet edildi'.c), findsOneWidget);
      await t.pumpAndSettle();
      expect(
        gonderilen.any((g) => g.contains('/davet') && g.contains('ayse')),
        isTrue,
        reason: 'davet ucu çağrılmalı',
      );
    },
  );

  testWidgets('davet HATASINDA satır GERİ ALINIYOR ve SnackBar çıkıyor', (
    t,
  ) async {
    _sunucu(adaylar: [_aday('ayse')], davetHatasi: true);
    await _kur(t);
    await t.tap(find.text('Davet et'.c));
    await t.pumpAndSettle();
    // Sessiz başarısızlık YASAK: satır eski hâline döner, sebep söylenir.
    expect(find.text('Davet et'.c), findsOneWidget);
    expect(find.text('Davet edildi'.c), findsNothing);
    expect(find.text('Oda dolu'.c), findsOneWidget);
  });

  testWidgets('davetli/odada satırları TIKLANAMIYOR', (t) async {
    _sunucu(
      adaylar: [
        _aday('ayse', durum: 'davet_edildi'),
        _aday('burak', durum: 'odada'),
      ],
    );
    await _kur(t);
    expect(find.text('Davet edildi'.c), findsOneWidget);
    expect(find.text('Odada'.c), findsOneWidget);
    // Düğme HİÇ ÇİZİLMEZ — devre dışı düğme çizmek "neden basmıyor" sorusunu
    // doğururdu; etiket ne olduğunu söylüyor.
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('arama kutusu YERELDE süzüyor, AĞ TURU YOK', (t) async {
    _sunucu(adaylar: [_aday('ayse'), _aday('burak')]);
    await _kur(t);
    await t.enterText(find.byType(TextField), 'bur');
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('@burak'), findsOneWidget);
    expect(find.text('@ayse'), findsNothing);
    expect(
      aramaSayisi,
      0,
      reason: 'yerelde eşleşme varken sunucuya sorulmamalı',
    );
  });

  testWidgets('yerelde eşleşme yoksa SUNUCUDA aranıyor', (t) async {
    _sunucu(
      adaylar: [_aday('ayse')],
      aramaSonucu: [
        {'kullanici_adi': 'zeynep', 'avatar': null, 'ben_mi': false},
      ],
    );
    await _kur(t);
    await t.enterText(find.byType(TextField), 'zey');
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(aramaSayisi, 1);
    expect(find.text('@zeynep'), findsOneWidget);
  });

  testWidgets('DEBOUNCE: hızlı yazımda TEK istek gidiyor', (t) async {
    _sunucu(
      adaylar: [_aday('ayse')],
      aramaSonucu: [
        {'kullanici_adi': 'zeynep', 'avatar': null, 'ben_mi': false},
      ],
    );
    await _kur(t);
    // Her harfte istek atmak hız limitini yer ve yanıtlar sırasız dönerse
    // kullanıcı bir önceki harfin sonucunu görür.
    for (final q in ['ze', 'zey', 'zeyn', 'zeyne', 'zeynep']) {
      await t.enterText(find.byType(TextField), q);
      await t.pump(const Duration(milliseconds: 60));
    }
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(aramaSayisi, 1, reason: '5 harf için tek istek gitmeli');
  });

  testWidgets(
    'karşılıklı takipleşilmeyen sonuç TIKLANAMIYOR ve SEBEBİ yazıyor',
    (t) async {
      _sunucu(
        adaylar: [_aday('ayse')],
        aramaSonucu: [
          {'kullanici_adi': 'zeynep', 'avatar': null, 'ben_mi': false},
        ],
      );
      await _kur(t);
      await t.enterText(find.byType(TextField), 'zey');
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      // Boş sonuç döndürmek YANLIŞ olurdu: kullanıcı arkadaşını arar, bulamaz,
      // "uygulama bozuk" der. Sebebi görmek ona ne yapacağını söyler.
      expect(find.text('Karşılıklı takipleşmiyorsunuz'.c), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    },
  );

  testWidgets('KENDİ hesabın arama sonucunda ÇIKMIYOR', (t) async {
    _sunucu(
      adaylar: const [],
      aramaSonucu: [
        {'kullanici_adi': 'ben', 'avatar': null, 'ben_mi': true},
        {'kullanici_adi': 'benzer', 'avatar': null, 'ben_mi': false},
      ],
    );
    await _kur(t);
    await t.enterText(find.byType(TextField), 'ben');
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(find.text('@ben'), findsNothing);
    expect(find.text('@benzer'), findsOneWidget);
  });

  testWidgets('hiç sonuç yoksa sebep + ODA KODU görünüyor', (t) async {
    _sunucu(adaylar: const [], aramaSonucu: const []);
    await _kur(t);
    await t.enterText(find.byType(TextField), 'yokboyle');
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    // Çıkışsız boş ekran yok: kod hâlâ geçerli bir davet yolu.
    expect(find.text('Böyle bir kullanıcı yok'.c), findsOneWidget);
    expect(find.text('AB2CD3'), findsOneWidget);
  });

  testWidgets('aday listesi boşken anlamlı boş durum + oda kodu', (t) async {
    _sunucu(adaylar: const []);
    await _kur(t);
    expect(find.text('Karşılıklı takipleştiğin kimse yok'.c), findsOneWidget);
    expect(find.text('AB2CD3'), findsOneWidget);
  });

  testWidgets('ELLE kullanıcı adı yazma yolu AĞAÇTA YOK', (t) async {
    // Kullanıcı isteğinin özü: "belki olmayan kullanıcıya istek gönderir bu
    // hatayı ortadan kaldıralım". Elle yazılıp gönderilen bir alan kalırsa
    // 404 KULLANICI_YOK geri gelir.
    _sunucu(adaylar: [_aday('ayse')]);
    await _kur(t);
    // Tek TextField var ve o ARAMA kutusu: gönderme eylemi yok.
    expect(find.byType(TextField), findsOneWidget);
    final alan = t.widget<TextField>(find.byType(TextField));
    expect(alan.onSubmitted, isNull, reason: 'arama kutusu davet göndermemeli');
    // Eski diyaloğun "Vazgeç/Davet et" ikilisi yok.
    expect(find.text('Vazgeç'.c), findsNothing);
  });

  testWidgets('yüklenirken İSKELET çiziliyor (boş ekran değil)', (t) async {
    // Yanıtı bilerek geciktiriyoruz: gerçek ağda liste anında gelmez ve o
    // aralıkta kullanıcı boş bir ekrana bakmamalı (ui-ux-pro-max, Loading
    // Indicators: 300 ms üstü her işlem için iskelet/spinner).
    Api.istemci = MockClient((istek) async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return _json({
        'adaylar': [_aday('ayse')],
        'kod': 'AB2CD3',
      });
    });
    await t.pumpWidget(_sar(const OdaDavetSecici(odaId: 5)));
    await t.pump();
    expect(find.byType(IskeletListe), findsOneWidget);
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(find.byType(IskeletListe), findsNothing);
    expect(find.text('@ayse'), findsOneWidget);
  });

  testWidgets('dokunma hedefi 44 dp (ui-ux-pro-max Touch Target)', (t) async {
    _sunucu(adaylar: [_aday('ayse')]);
    await _kur(t);
    final dugme = t.getSize(find.byType(FilledButton));
    expect(dugme.height, greaterThanOrEqualTo(44));
  });
}
