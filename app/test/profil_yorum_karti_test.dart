import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/ekranlar/kesfet_akis.dart';
import 'package:dizijpg/ekranlar/kullanici_profil.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Profilin "Yorumlar" sekmesi akış kartını (AkisKarti) kullanır; kart da
/// yazar bilgisini gönderi satırından okur.
///
/// Kullanıcı bildirimi (2026-08-02): kendi profilinde yorum kartlarında
/// kullanıcı adı "@null" görünüyordu — /profil/:kullaniciAdi ucu yorum
/// satırlarını kullanici_adi/avatar/begendim OLMADAN döndürüyordu. Bu testler
/// kartın sunucudan gelen alanları doğru kullandığını kilitler.
Map<String, dynamic> _profilYorumu({
  String kullaniciAdi = 'alcelik',
  bool begendim = false,
}) => {
  'id': 11,
  'kullanici_id': 3,
  'kullanici_adi': kullaniciAdi,
  'avatar': null,
  'metin': 'Profilden gelen yorum',
  'tur': 'tv',
  'tmdb_id': 100,
  'medya': <String>[],
  'begeni': 2,
  'yanit': 0,
  'goruntulenme': 13,
  'spoiler': false,
  'begendim': begendim,
  'tarih': '2026-08-02T10:00:00Z',
  'kaynak_dil': 'tr',
  'ceviri_var': false,
  'cevrildi': false,
};

const _icerikler = {
  'tv:100': {'ad': 'Test Dizi', 'poster': null},
};

Future<void> _kartKur(WidgetTester tester, Map<String, dynamic> yorum) async {
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AkisKarti(yorum: yorum, icerikler: _icerikler),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _reelsKur(WidgetTester tester, Map<String, dynamic> yorum) async {
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(
        home: ReelsGorunumu(
          liste: [yorum],
          icerikler: _icerikler,
          baslangic: 0,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('profil yorumunda yazar adı yazılır (@null değil)', (
    tester,
  ) async {
    await _kartKur(tester, _profilYorumu());
    expect(find.text('@alcelik'), findsOneWidget);
    expect(find.text('@null'), findsNothing);
  });

  testWidgets('begendim=true gelen yorumda kalp dolu çizilir', (tester) async {
    await _kartKur(tester, _profilYorumu(begendim: true));
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });

  testWidgets('begendim=false gelen yorumda kalp boş çizilir', (tester) async {
    await _kartKur(tester, _profilYorumu());
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });

  testWidgets('Reels: takip durumu bilinmiyorsa Takip Et düğmesi çıkmaz', (
    tester,
  ) async {
    // Profilden açılan Reels'te takip_ediyorum alanı yok; eskiden düğme
    // kendi gönderinde bile "Takip Et" diyordu.
    final y = _profilYorumu();
    y['medya'] = ['/medya/kare0.jpg'];
    await _reelsKur(tester, y);
    expect(find.text('Takip Et'), findsNothing);
  });

  testWidgets('Reels: takip_ediyorum=false ise Takip Et düğmesi çıkar', (
    tester,
  ) async {
    final y = _profilYorumu();
    y['medya'] = ['/medya/kare0.jpg'];
    y['takip_ediyorum'] = false;
    await _reelsKur(tester, y);
    expect(find.text('Takip Et'), findsOneWidget);
  });

  testWidgets('profil yorum kartı da ana zeminle birleşir, eylemler beyazdır', (
    tester,
  ) async {
    DiziRenkler.acik = false;
    SharedPreferences.setMockInitialValues({});
    await Api.tokenYukle();
    await tester.pumpWidget(
      ChangeNotifierProvider<Oturum>.value(
        value: Oturum(),
        child: MaterialApp(
          home: Scaffold(
            body: ProfilYorumKarti(
              yorum: _profilYorumu(),
              icerikler: _icerikler,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final kart = tester.widget<Card>(find.byType(Card));
    expect(kart.color, DiziRenkler.siyah);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.remove_red_eye)).color,
      DiziRenkler.gonderiEylem,
    );
    expect(
      tester.widget<Text>(find.text('13')).style?.color,
      DiziRenkler.gonderiEylem,
    );
    expect(
      tester.widget<Text>(find.text('2')).style?.color,
      DiziRenkler.gonderiEylem,
    );
    expect(
      tester.widget<Text>(find.text('2026-08-02')).style?.color,
      DiziRenkler.gonderiEylem,
    );
  });

  // =========================================================================
  // MEDYA LİSTEDE GÖRÜNÜR (27 Ağu 2026)
  // =========================================================================
  // Kullanıcı bildirdi: "profilimdeki göz ikonuna tıkladığımda fotoğraf video
  // ile yaptığım paylaşımların fotoğraf ve videoları gözükmüyor."
  //
  // ÖLÇÜLDÜ: veri hep vardı — `GET /profil/:ad` `y.medya`yı döndürüyor
  // (canlı yanıt: 20 gönderinin 11'i medyalı, ör. ['/medya/m3-….png']) ve
  // dosyalar 200 dönüyor. Kusur ÇİZİMDE: kart medyayı hiç basmıyordu, yalnız
  // detay modali basıyordu — fotoğraflı gönderi listede düz metin gibi
  // görünüyordu.
  Future<void> kartKur(WidgetTester tester, List<String> medya) async {
    DiziRenkler.acik = false;
    SharedPreferences.setMockInitialValues({});
    await Api.tokenYukle();
    await tester.pumpWidget(
      ChangeNotifierProvider<Oturum>.value(
        value: Oturum(),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfilYorumKarti(
                yorum: {..._profilYorumu(), 'medya': medya},
                icerikler: _icerikler,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('FOTOĞRAFLI gönderi kartında medya çizilir', (tester) async {
    await kartKur(tester, ['/medya/m3-abc.png']);
    expect(
      find.byType(MedyaGaleri),
      findsOneWidget,
      reason: 'fotoğraflı gönderi listede hâlâ düz metin gibi görünüyor',
    );
    expect(tester.widget<MedyaGaleri>(find.byType(MedyaGaleri)).yollar, [
      '/medya/m3-abc.png',
    ]);
  });

  testWidgets('VİDEOLU gönderi kartında da medya çizilir', (tester) async {
    // Video da fotoğrafla aynı bileşenden geçer: MedyaGaleri siyah kapak +
    // oynat ikonu basar ve dokununca tam ekran görüntüleyici açar.
    await kartKur(tester, ['/medya/m3-abc.mp4']);
    expect(find.byType(MedyaGaleri), findsOneWidget);
  });

  testWidgets('ÇOKLU medya tek galeriye verilir (kart başına bir bileşen)', (
    tester,
  ) async {
    await kartKur(tester, ['/medya/a.png', '/medya/b.png', '/medya/c.mp4']);
    expect(find.byType(MedyaGaleri), findsOneWidget);
    expect(
      tester.widget<MedyaGaleri>(find.byType(MedyaGaleri)).yollar.length,
      3,
    );
  });

  testWidgets('MEDYASIZ gönderide galeri HİÇ çizilmez (boş kutu kalmasın)', (
    tester,
  ) async {
    await kartKur(tester, <String>[]);
    expect(find.byType(MedyaGaleri), findsNothing);
  });

  testWidgets('liste kartında video KENDİLİĞİNDEN OYNAMAZ', (tester) async {
    // `otomatikOynat` yalnız akışa ait: listede açık olsaydı kaydırmada birden
    // çok oynatıcı açılır ve çift ses verirdi.
    await kartKur(tester, ['/medya/m3-abc.mp4']);
    expect(
      tester.widget<MedyaGaleri>(find.byType(MedyaGaleri)).otomatikOynat,
      isFalse,
    );
  });

  testWidgets('etkileşim satırı medyanın ALTINDA, üstüne BİNDİRİLMEZ', (
    tester,
  ) async {
    // Kullanıcının 14 Ağu'daki açık isteği: etkileşim satırı hiçbir hâlde
    // görselin üstüne (Stack) bindirilmez. Medya karta gelince bu kural daha
    // da bağlayıcı oldu — konum karşılaştırmasıyla kilitleniyor.
    await kartKur(tester, ['/medya/m3-abc.png']);
    final medyaAlt = tester.getBottomLeft(find.byType(MedyaGaleri)).dy;
    final gozUst = tester.getTopLeft(find.byIcon(Icons.remove_red_eye)).dy;
    expect(
      gozUst,
      greaterThanOrEqualTo(medyaAlt),
      reason: 'etkileşim satırı görselin üstüne binmiş',
    );
  });
}
