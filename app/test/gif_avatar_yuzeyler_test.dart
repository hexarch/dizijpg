// GIF PROFİL RESİMLERİ AKIŞTA / YORUMLARDA / REELS'TE OYNAMIYOR (md.13).
//
// 9 Ağu 2026'da profil başlığı ve ayarlar düzeltildi ama YALNIZ ORASI.
// Kullanıcının GIF avatarı akışta, dizi/film yorumlarında ve Reels'te hâlâ
// donuk ilk karesinde duruyordu. İki ayrı sebep üst üste biniyordu:
//
//  1. Bu üç yüzeyde avatar `KullaniciAvatari(hareketli: false)` ile, yani
//     `CircleAvatar(backgroundImage:)` = `DecorationImage` olarak çiziliyordu.
//     DecorationImage animasyonlu görselin YALNIZ İLK KARESİNİ boyar
//     (kanıt: test/gif_animasyon_test.dart).
//  2. `hareketli: true` verilse bile web'de YETMEZDİ: `CachedNetworkImage`
//     web'de <img> yoluna düşer ve kodek `frameCount == 1` bildirir.
//     Belirleyici olan ImageProvider'ın ürettiği kodektir.
//
// TEST TUZAĞI — HATA TAM BU YÜZDEN CANLIYA ÇIKTI: `flutter test` DAİMA VM'de
// koşar, `kIsWeb` orada HEP `false`'tur; hatanın olduğu dal test edilen dal
// DEĞİLDİ. Bu yüzden `agGorselWebZorla` kancası var: aşağıdaki testler her üç
// yüzeyi de İKİ DALDA birden geziyor.
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/ekranlar/kesfet_akis.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/ekranlar/yorumlar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gerçek kullanıcı verisiyle aynı biçim: canlıda `alcelik`in avatarı
/// `/avatarlar/avatar3-1786094173967.gif` (10 Ağu 2026 `GET /kesfet-akis`
/// yanıtından; o listede 60 gönderinin 7'sinin avatarı .gif).
const _gifAvatar = '/avatarlar/avatar3-1786094173967.gif';

Map<String, dynamic> _gonderi({int id = 7, List<String> medya = const []}) => {
  'id': id,
  'kullanici_id': 42,
  'kullanici_adi': 'thelostvibe0',
  'avatar': _gifAvatar,
  'metin': 'Test gönderisi',
  'tur': 'tv',
  'tmdb_id': 100,
  'medya': medya,
  'begeni': 0,
  'goruntulenme': 0,
  'spoiler': false,
  'ust_id': null,
  'tarih': '2026-08-10T10:00:00Z',
};

const _icerikler = {
  'tv:100': {'ad': 'Test Dizi', 'poster': null},
};

Future<void> _kur(WidgetTester tester, Widget cocuk) async {
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: cocuk)),
      ),
    ),
  );
  await tester.pump();
}

/// Ağaçtaki avatar görselinin ImageProvider'ını bulur.
///
/// Avatar dışındaki görseller (gönderi medyası, poster) elenmeli: yalnız
/// URL'si avatar adresine denk gelen sağlayıcı döner.
ImageProvider? _avatarSaglayici(WidgetTester tester) {
  final hedef = dosyaUrl(_gifAvatar);
  for (final w in tester.widgetList<Image>(find.byType(Image))) {
    final s = w.image;
    if (s is NetworkImage && s.url == hedef) return s;
  }
  for (final w in tester.widgetList<CachedNetworkImage>(
    find.byType(CachedNetworkImage),
  )) {
    if (w.imageUrl == hedef) return CachedNetworkImageProvider(w.imageUrl);
  }
  return null;
}

/// Ağaçta avatarı `DecorationImage` olarak boyayan bir `CircleAvatar` var mı?
/// (VARSA animasyon donar — 8 Ağu 2026'daki hatanın kalıbı.)
bool _donukAvatarVar(WidgetTester tester) => tester
    .widgetList<CircleAvatar>(find.byType(CircleAvatar))
    .any((a) => a.backgroundImage != null);

void main() {
  tearDown(() => agGorselWebZorla = null);

  /// Üç yüzey de AYNI iki koşulu sağlamalı. Yüzey başına ayrı `group`,
  /// dal başına ayrı `test`: biri kırılırsa hangi yüzey/dal olduğu isminden
  /// okunur.
  void yuzey(String ad, Future<void> Function(WidgetTester) kur) {
    group('$ad: GIF avatar', () {
      testWidgets('WEB dalı Image.network (Flutter NetworkImage) kullanır', (
        tester,
      ) async {
        agGorselWebZorla = true;
        await kur(tester);
        final s = _avatarSaglayici(tester);
        expect(
          s,
          isA<NetworkImage>(),
          reason:
              '$ad: web dalında avatar Flutter NetworkImage ile inmeli. '
              'CachedNetworkImageProvider web\'de <img> yoluna düşer, kodek '
              'tek kare bildirir ve GIF ilk karesinde DONAR.',
        );
        expect(
          s,
          isNot(isA<CachedNetworkImageProvider>()),
          reason: '$ad: web dalında CachedNetworkImageProvider KULLANILAMAZ',
        );
        expect(
          _donukAvatarVar(tester),
          isFalse,
          reason: '$ad: backgroundImage (DecorationImage) tek kare boyar',
        );
      });

      testWidgets('MOBİL dalı CachedNetworkImage\'i korur', (tester) async {
        agGorselWebZorla = false;
        await kur(tester);
        expect(
          _avatarSaglayici(tester),
          isA<CachedNetworkImageProvider>(),
          reason:
              '$ad: mobilde <img> yolu yok, kodek bayttan çözülür (animasyon '
              'zaten oynar); disk önbelleği için CachedNetworkImage kalmalı.',
        );
        expect(
          _donukAvatarVar(tester),
          isFalse,
          reason: '$ad: mobilde de DecorationImage kullanılmamalı',
        );
      });
    });
  }

  // ---- 1. AKIŞ ----
  yuzey(
    'Akış kartı',
    (tester) =>
        _kur(tester, AkisKarti(yorum: _gonderi(), icerikler: _icerikler)),
  );

  // ---- 2. DİZİ/FİLM YORUMLARI ----
  yuzey(
    'Dizi/film yorumu',
    (tester) => _kur(
      tester,
      YorumKarti(
        yorum: _gonderi(id: 5),
        benim: false,
        benimId: null,
        sil: () {},
        yanitla: (_) {},
        yanitSil: (_) {},
        yanitlar: const [],
        medyaAc: (_, _) async {},
      ),
    ),
  );

  // ---- 2b. YANIT SATIRI (aynı yüzeyin ikinci avatarı) ----
  yuzey(
    'Yoruma gelen yanıt satırı',
    (tester) => _kur(
      tester,
      YorumKarti(
        // Üst yorumda avatar YOK: ağaçta bulunan tek GIF avatar yanıtındır,
        // yani bu test gerçekten YANIT SATIRINI ölçer.
        yorum: {..._gonderi(id: 5), 'avatar': null},
        benim: false,
        benimId: null,
        sil: () {},
        yanitla: (_) {},
        yanitSil: (_) {},
        yanitlar: [
          {..._gonderi(id: 6), 'ust_id': 5, 'metin': 'yanıt'},
        ],
        medyaAc: (_, _) async {},
      ),
    ),
  );

  // ---- 3. REELS ----
  yuzey(
    'Reels',
    (tester) => _kur(
      tester,
      SizedBox(
        width: 400,
        height: 800,
        child: ReelsGorunumu(
          liste: [
            _gonderi(medya: const ['/medya/kare0.jpg']),
          ],
          icerikler: _icerikler,
          baslangic: 0,
        ),
      ),
    ),
  );

  group('KAYNAK DENETİMİ: üç yüzey de hareketli bayrağını geçiyor', () {
    // Widget testi "şu an doğru"yu kilitler; bu test bayrağın SESSİZCE
    // düşürülmesini de yakalar (varsayılan `false` olduğu için bayrağı silmek
    // hiçbir derleme hatası vermez, ekran sessizce eski hâline döner).
    for (final yol in const [
      'lib/ekranlar/akis.dart',
      'lib/ekranlar/yorumlar.dart',
      'lib/ekranlar/kesfet_akis.dart',
    ]) {
      test('$yol: hareketli: true geçen avatar var', () {
        final kod = File(yol).readAsStringSync();
        expect(
          kod.contains('hareketli: true'),
          isTrue,
          reason:
              '$yol içindeki KullaniciAvatari artık hareketli bayrağını '
              'geçmiyor — GIF avatar bu yüzeyde yeniden DONAR (md.13).',
        );
      });
    }
  });
}
