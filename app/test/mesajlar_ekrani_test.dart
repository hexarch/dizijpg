import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/ekranlar/sohbet.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// MESAJLAR EKRANI (kullanıcı isteği, 5 Ağu 2026):
///
/// "Mesajlar kısmında kişilerin arasında space var ve arka planda hafif grimsi
///  ton var ya, onları kaldır. direkt mesaj, kullanıcı adı, profil resmi olsun.
///  ve kullanıcıların çevrimiçi durumu olmalı: eğer çevrimiçi ise profil
///  fotoğrafının sağ altında yeşil nokta olacak. sağ yukarıda da 'gelen mesaj
///  istekleri' yazısı olsun, tıklayınca o kullanıcının takip etmediği kişiden
///  gelen mesajlar oraya düşecek."
///
/// Buradaki testler dört maddeyi ayrı ayrı ÖLÇEREK kilitler:
///   1. Satır arası boşluk = 0 dp, satırın altında kart/gri zemin YOK,
///      buna karşılık satır yüksekliği 44 dp'nin ALTINA düşmedi.
///   2. Yeşil nokta yalnız çevrimiçi kullanıcıda ve avatarın SAĞ ALTINDA.
///      (Çevrimiçi durumunu gizleyen için sunucu cevrimici=false gönderir ->
///      nokta çizilmez; sunucu tarafı backend/test/mesaj_istekleri.test.js.)
///   3. Takip edilmeyenden gelen sohbet ANA LİSTEDE YOK, isteklerde VAR.
///   4. İstekler boşken boş-durum metni çıkar; 360 dp'de taşma olmaz.

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _sohbet(
  String ad, {
  String metin = 'selam',
  bool cevrimici = false,
  int okunmamis = 0,
}) => {
  'id': ad.hashCode.abs() % 1000,
  'metin': metin,
  'medya': null,
  'icerik_tur': null,
  'tarih': '2026-08-05T10:00:00Z',
  'gonderen_id': 42,
  'partner_id': 42,
  'partner': ad,
  'partner_avatar': null,
  'cevrimici': cevrimici,
  'okunmamis': okunmamis,
};

int _istekle = 0;

void _sunucu({
  List<Map<String, dynamic>> sohbetler = const [],
  List<Map<String, dynamic>> istekler = const [],
}) {
  _istekle = 0;
  Api.istemci = MockClient((istek) async {
    if (istek.url.path.endsWith('/sohbetler')) {
      _istekle++;
      return _json({
        'sohbetler': sohbetler,
        'istekler': istekler,
        'istek_okunmamis': istekler
            .where((s) => (s['okunmamis'] as int) > 0)
            .length,
        'okunmamis': 0,
      });
    }
    return _json(const {});
  });
}

String? _sonRota;

Future<void> _kur(
  WidgetTester tester, {
  Size ekran = const Size(390, 844),
  bool acikTema = false,
  String baslangic = '/sohbetler',
}) async {
  _sonRota = null;
  DiziRenkler.acik = acikTema;
  addTearDown(() => DiziRenkler.acik = false);
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = ekran;
  addTearDown(tester.view.reset);
  final yonlendirici = GoRouter(
    initialLocation: baslangic,
    routes: [
      GoRoute(path: '/sohbetler', builder: (_, _) => const SohbetlerEkrani()),
      GoRoute(
        path: '/mesaj-istekleri',
        builder: (_, _) => const MesajIstekleriEkrani(),
      ),
      GoRoute(
        path: '/sohbet/:ad',
        builder: (_, s) {
          _sonRota = s.uri.path;
          return const Scaffold(body: Text('sohbet-sayfasi'));
        },
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: yonlendirici));
  await tester.pump(); // ilk /sohbetler cevabı
}

Finder _satir(String ad) =>
    find.ancestor(of: find.text('@$ad'), matching: find.byType(SohbetSatiri));

void main() {
  testWidgets('satırlar arasında BOŞLUK YOK ve satırın gri zemini YOK', (
    tester,
  ) async {
    _sunucu(sohbetler: [_sohbet('ayse'), _sohbet('mehmet'), _sohbet('zeynep')]);
    await _kur(tester);

    // 1) Kart kalktı: listede tek bir Card/ListTile yok.
    expect(find.byType(Card), findsNothing);
    expect(find.byType(ListTile), findsNothing);

    // 2) Ardışık satırlar BİTİŞİK: birincinin altı = ikincinin üstü (0 dp).
    final a = tester.getRect(_satir('ayse'));
    final b = tester.getRect(_satir('mehmet'));
    final c = tester.getRect(_satir('zeynep'));
    expect(b.top - a.bottom, 0.0, reason: 'satır arası boşluk 0 dp olmalı');
    expect(c.top - b.bottom, 0.0);

    // 3) Satır yüksekliği 44 dp'nin ALTINA DÜŞMEDİ (ölçüm: 60 dp).
    expect(a.height, 60.0);
    expect(a.height, greaterThanOrEqualTo(44.0));

    // 4) Satırın TAMAMINI kaplayan renkli bir zemin yok. (Avatarın kendi
    //    daire zemini 44 dp geniş, satırın tamamını kaplamaz — o kalmalı.)
    for (final el
        in find
            .descendant(of: _satir('ayse'), matching: find.byType(DecoratedBox))
            .evaluate()) {
      final dekor = (el.widget as DecoratedBox).decoration;
      if (dekor is! BoxDecoration) continue;
      final renk = dekor.color;
      if (renk == null || renk.a == 0) continue;
      final kutu = el.renderObject! as RenderBox;
      expect(
        kutu.size.width,
        lessThan(a.width),
        reason: 'satırın tamamını kaplayan renkli zemin (gri ton) olmamalı',
      );
    }
  });

  testWidgets('satır sadece profil resmi + kullanıcı adı + son mesaj', (
    tester,
  ) async {
    _sunucu(sohbetler: [_sohbet('ayse', metin: 'bu akşam izliyor musun')]);
    await _kur(tester);

    expect(find.byType(CevrimiciAvatar), findsOneWidget);
    expect(find.text('@ayse'), findsOneWidget);
    expect(find.text('bu akşam izliyor musun'), findsOneWidget);
  });

  testWidgets('çevrimiçi kullanıcıda yeşil nokta VAR ve avatarın SAĞ ALTINDA', (
    tester,
  ) async {
    _sunucu(sohbetler: [_sohbet('ayse', cevrimici: true)]);
    await _kur(tester);

    final nokta = find.byKey(const Key('cevrimici-nokta'));
    expect(nokta, findsOneWidget);

    final avatar = tester.getRect(find.byType(CevrimiciAvatar));
    final n = tester.getRect(nokta);
    // SAĞ ALT: noktanın merkezi avatarın merkezinden hem SAĞDA hem AŞAĞIDA
    expect(n.center.dx, greaterThan(avatar.center.dx));
    expect(n.center.dy, greaterThan(avatar.center.dy));
    // ve avatarın sağ-alt köşesine yapışık (Positioned right:0, bottom:0)
    expect(n.right, avatar.right);
    expect(n.bottom, avatar.bottom);
    // Nokta avatarın SINIRLARI İÇİNDE: taşan Positioned tıklanamaz olurdu.
    expect(avatar.contains(n.topLeft), isTrue);

    // Renk: tema-duyarlı yeşil, sabit Colors.green DEĞİL.
    final kutu = tester.widget<Container>(nokta);
    final dekor = kutu.decoration! as BoxDecoration;
    expect(dekor.color, DiziRenkler.cevrimiciYesil);
    expect(dekor.shape, BoxShape.circle);
  });

  testWidgets('çevrimdışı kullanıcıda yeşil nokta YOK', (tester) async {
    _sunucu(sohbetler: [_sohbet('ayse')]);
    await _kur(tester);
    expect(find.byKey(const Key('cevrimici-nokta')), findsNothing);
  });

  testWidgets('"Çevrimiçi durumumu gizle" açıkken başkaları noktayı görmez', (
    tester,
  ) async {
    // Sunucu, gizleyen kullanıcı için cevrimici=false gönderir (ham
    // son_gorulme damgası hiç gelmez) -> nokta çizilmez.
    _sunucu(
      sohbetler: [
        _sohbet('gizleyen'), // cevrimici:false — tercih açık
        _sohbet('acik', cevrimici: true),
      ],
    );
    await _kur(tester);

    expect(
      find.descendant(
        of: _satir('gizleyen'),
        matching: find.byKey(const Key('cevrimici-nokta')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: _satir('acik'),
        matching: find.byKey(const Key('cevrimici-nokta')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('yeşil nokta AÇIK temada da görünür ve zemin konturu var', (
    tester,
  ) async {
    _sunucu(sohbetler: [_sohbet('ayse', cevrimici: true)]);
    await _kur(tester, acikTema: true);

    final kutu = tester.widget<Container>(
      find.byKey(const Key('cevrimici-nokta')),
    );
    final dekor = kutu.decoration! as BoxDecoration;
    // Açık ve koyu tema AYRI ton kullanır (aynı olsaydı biri erirdi).
    expect(dekor.color, const Color(0xFF1B9E4B));
    DiziRenkler.acik = false;
    expect(DiziRenkler.cevrimiciYesil, const Color(0xFF3DDC6B));
    DiziRenkler.acik = true;
    // Zemin renginde 2 dp kontur: koyu/açık avatar üstünde de ayırt edilir.
    expect(dekor.border, Border.all(color: DiziRenkler.siyah, width: 2));
  });

  testWidgets('sağ üstte "Gelen mesaj istekleri" girişi var ve 44 dp', (
    tester,
  ) async {
    _sunucu(sohbetler: [_sohbet('ayse')], istekler: [_sohbet('yabanci')]);
    await _kur(tester);

    final dugme = find.byType(MesajIstekleriDugmesi);
    expect(dugme, findsOneWidget);
    expect(
      find.descendant(of: dugme, matching: find.text('Gelen mesaj istekleri')),
      findsOneWidget,
    );
    final r = tester.getRect(dugme);
    expect(r.height, greaterThanOrEqualTo(44.0));
    // SAĞ ÜST: başlığın sağında ve ekranın sağ yarısında
    expect(r.center.dx, greaterThan(390 / 2));
    expect(r.center.dy, lessThan(56.0 + 8));
  });

  testWidgets(
    'takip EDİLMEYENDEN gelen sohbet ana listede YOK, isteklerde VAR',
    (tester) async {
      _sunucu(
        sohbetler: [_sohbet('takipettigim')],
        istekler: [_sohbet('yabanci')],
      );
      await _kur(tester);

      // Ana liste: yalnız takip ettiğim
      expect(find.text('@takipettigim'), findsOneWidget);
      expect(find.text('@yabanci'), findsNothing);

      // "Gelen mesaj istekleri"ne dokun -> istekler ekranı
      await tester.tap(find.byType(MesajIstekleriDugmesi));
      await tester.pumpAndSettle();

      expect(find.byType(MesajIstekleriEkrani), findsOneWidget);
      expect(find.text('@yabanci'), findsOneWidget);
      expect(find.text('@takipettigim'), findsNothing);
    },
  );

  testWidgets('okunmamış isteği olduğunda giriş rozet gösterir', (
    tester,
  ) async {
    _sunucu(
      sohbetler: [_sohbet('ayse')],
      istekler: [
        _sohbet('yabanci', okunmamis: 2),
        _sohbet('yabanci2', okunmamis: 1),
        _sohbet('okunmus'), // okunmamışı yok -> rozeti şişirmez
      ],
    );
    await _kur(tester);

    final rozet = find.descendant(
      of: find.byType(MesajIstekleriDugmesi),
      matching: find.byType(OkunmamisRozeti),
    );
    expect(rozet, findsOneWidget);
    expect(tester.widget<OkunmamisRozeti>(rozet).adet, 2);
  });

  testWidgets('istek yokken rozet YOK', (tester) async {
    _sunucu(sohbetler: [_sohbet('ayse')]);
    await _kur(tester);
    expect(
      find.descendant(
        of: find.byType(MesajIstekleriDugmesi),
        matching: find.byType(OkunmamisRozeti),
      ),
      findsNothing,
    );
  });

  testWidgets('istekler ekranı BOŞken boş-durum metni çıkar', (tester) async {
    _sunucu(sohbetler: [_sohbet('ayse')]);
    await _kur(tester, baslangic: '/mesaj-istekleri');

    expect(find.byType(BosDurum), findsOneWidget);
    expect(find.text('Mesaj isteğin yok'), findsOneWidget);
    expect(
      find.text('Takip etmediğin kişilerden gelen mesajlar burada görünür.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'istekten dönünce ana liste TAZELENİR (cevap ana listeye geçer)',
    (tester) async {
      _sunucu(sohbetler: [_sohbet('ayse')], istekler: [_sohbet('yabanci')]);
      await _kur(tester);
      expect(_istekle, 1);

      await tester.tap(find.byType(MesajIstekleriDugmesi));
      await tester.pumpAndSettle();
      expect(_istekle, 2); // istekler ekranı kendi verisini çeker

      // Cevap verildi: sunucu artık aynı kişiyi ANA listede döndürür.
      _sunucu(sohbetler: [_sohbet('ayse'), _sohbet('yabanci')]);
      Navigator.of(tester.element(find.byType(MesajIstekleriEkrani))).pop();
      await tester.pumpAndSettle();

      expect(find.byType(SohbetlerEkrani), findsOneWidget);
      expect(find.text('@yabanci'), findsOneWidget);
    },
  );

  testWidgets('satıra dokunmak sohbeti açar', (tester) async {
    _sunucu(sohbetler: [_sohbet('ayse')]);
    await _kur(tester);
    await tester.tap(_satir('ayse'));
    await tester.pumpAndSettle();
    expect(_sonRota, '/sohbet/ayse');
  });

  testWidgets('360 dp: uzun kullanıcı adı ve uzun son mesaj TAŞMAZ', (
    tester,
  ) async {
    _sunucu(
      sohbetler: [
        _sohbet(
          'cok-uzun-bir-kullanici-adi-buraya-sigmaz-kesinlikle-uzun',
          metin:
              'Bu son mesaj bilerek çok uzun yazıldı ki tek satıra sığmasın ve '
              'kırpılması gerektiği ölçülebilsin; taşarsa test kırmızıya döner.',
          okunmamis: 12,
        ),
      ],
    );
    await _kur(tester, ekran: const Size(360, 640));

    expect(tester.takeException(), isNull);
    final satir = tester.getRect(find.byType(SohbetSatiri));
    expect(satir.width, lessThanOrEqualTo(360.0));

    // Ad ve son mesaj TEK SATIRA kırpılıyor (ellipsis), sarmıyor.
    for (final t in [
      find.textContaining('@cok-uzun'),
      find.textContaining('Bu son mesaj'),
    ]) {
      final yazi = tester.widget<Text>(t);
      expect(yazi.maxLines, 1);
      expect(yazi.overflow, TextOverflow.ellipsis);
      expect(tester.getRect(t).right, lessThanOrEqualTo(360.0));
    }
  });

  testWidgets('360 dp: uzun çeviride istekler girişi başlığı taşırmaz', (
    tester,
  ) async {
    _sunucu(sohbetler: [_sohbet('ayse')]);
    await _kur(tester, ekran: const Size(360, 640));

    expect(tester.takeException(), isNull);
    final r = tester.getRect(find.byType(MesajIstekleriDugmesi));
    expect(r.right, lessThanOrEqualTo(360.0));
    expect(r.width, lessThanOrEqualTo(168.0 + 4));
    // İki satıra sarabilir: en uzun çeviri (Almanca) kırpılmadan sığsın.
    final yazi = tester.widget<Text>(find.text('Gelen mesaj istekleri'));
    expect(yazi.maxLines, 2);
  });

  testWidgets('masaüstü: sohbet satırları 720 kolonunda ortalanır', (
    tester,
  ) async {
    _sunucu(sohbetler: [_sohbet('ayse')]);
    await _kur(tester, ekran: const Size(1440, 900));

    final r = tester.getRect(_satir('ayse'));
    expect(r.width, lessThanOrEqualTo(masaustuKolonGenisligi));
    expect(r.left, closeTo((1440 - r.width) / 2, 1));
    expect(r.left, greaterThan(200), reason: 'kullanıcılar sola yapışmamalı');
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobil: sohbet satırı tam genişlikte kalır (kısıt bağlamaz)', (
    tester,
  ) async {
    _sunucu(sohbetler: [_sohbet('ayse')]);
    await _kur(tester, ekran: const Size(360, 800));

    final r = tester.getRect(_satir('ayse'));
    expect(r.left, 0);
    expect(r.width, 360);
    expect(tester.takeException(), isNull);
  });

  testWidgets('masaüstü: mesaj istekleri listesi de ortalanır', (tester) async {
    _sunucu(istekler: [_sohbet('yabanci')]);
    await _kur(
      tester,
      ekran: const Size(1440, 900),
      baslangic: '/mesaj-istekleri',
    );

    final r = tester.getRect(_satir('yabanci'));
    expect(r.width, lessThanOrEqualTo(masaustuKolonGenisligi));
    expect(r.left, closeTo((1440 - r.width) / 2, 1));
    expect(tester.takeException(), isNull);
  });
}
