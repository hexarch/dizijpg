// İLK AÇILIŞTA CİHAZ DİLİ TESPİTİ (21 Ağu 2026).
//
// KÖK NEDEN: uygulama Türkçe yazıldı, 45 dil SONRADAN eklendi ve "ilk
// açılışta hangi dil?" sorusu hiç sorulmadı. Kod tabanında cihaz dili HİÇ
// okunmuyordu (`PlatformDispatcher` yalnız hata yakalamada kullanılıyordu),
// bu yüzden temiz kurulumda Londra'daki kullanıcı da Türkçe bir uygulama
// açıyordu. 45 çevirinin hiçbiri kendiliğinden uygulanmıyordu.
//
// KİLİTLENEN DAVRANIŞLAR:
//  1. Seçim yoksa cihazın TERCİH LİSTESİ sırayla taranır, ilk desteklenen dil.
//  2. Bölge/yazı kodu düşer: en-GB→en, pt-BR→pt, zh-Hant-TW→zh.
//  3. Hiçbiri desteklenmiyorsa TÜRKÇE DEĞİL İNGİLİZCE (ürün kararı).
//  4. KULLANICI SEÇİMİ KUTSAL: `dil` kaydı varsa cihaz dili onu EZMEZ —
//     ne bu açılışta ne de güncellemeden sonraki açılışlarda.
//  5. Tespit edilen dil `X-Dil` başlığına ve `/tmdb/` adresindeki `dil=`
//     parametresine de yansır (arayüz İngilizce ama özetler Türkçe OLMAZ).
import 'dart:convert';
import 'dart:io';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uygulamayı "açar": kayıtlı tercihler [kayit], cihazın bildirdiği diller
/// [cihaz]. Gerçek açılışta `main()` de tam olarak bunu yapıyor
/// (`acilisAdimi('ceviri', Ceviri.yukle)`).
Future<void> _ac(List<Locale> cihaz, {Map<String, Object> kayit = const {}}) {
  SharedPreferences.setMockInitialValues(kayit);
  Ceviri.cihazDilleri = () => cihaz;
  return Ceviri.yukle();
}

Locale _y(String dil, [String? bolge]) => Locale(dil, bolge);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    // Sonraki dosya/test gerçek platformu görsün, dil de anahtar diline dönsün.
    Ceviri.cihazDilleri = Ceviri.platformDilleri;
    SharedPreferences.setMockInitialValues({'dil': Ceviri.varsayilan});
    await Ceviri.yukle();
  });

  // ---------------------------------------------------------------------
  // 1. Temiz kurulum: cihaz ne diyorsa o
  // ---------------------------------------------------------------------
  test('cihaz en-US → uygulama İngilizce açılır', () async {
    await _ac([_y('en', 'US')]);
    expect(Ceviri.dil.value, 'en');
    // Kod doğru olması yetmez: çeviri haritası da GERÇEKTEN yüklenmeli.
    expect('Ayarlar'.c, 'Settings');
  });

  test('cihaz de-DE → Almanca', () async {
    await _ac([_y('de', 'DE')]);
    expect(Ceviri.dil.value, 'de');
    expect('Ayarlar'.c, 'Einstellungen');
  });

  test('cihaz tr-TR → Türkçe (anahtar dili, harita boş kalır)', () async {
    await _ac([_y('tr', 'TR')]);
    expect(Ceviri.dil.value, 'tr');
    expect('Ayarlar'.c, 'Ayarlar');
  });

  // ---------------------------------------------------------------------
  // 2. Bölge / yazı kodu düşer
  // ---------------------------------------------------------------------
  test('pt-BR → pt (bölge kodu düşer)', () async {
    await _ac([_y('pt', 'BR')]);
    expect(Ceviri.dil.value, 'pt');
    expect('Ayarlar'.c, 'Configurações');
  });

  test('en-GB → en (bölge kodu düşer)', () async {
    await _ac([_y('en', 'GB')]);
    expect(Ceviri.dil.value, 'en');
  });

  test('zh-Hant-TW → zh (yazı kodu düşer, tek Çince dosyamız)', () async {
    await _ac([
      const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
        countryCode: 'TW',
      ),
    ]);
    expect(
      Ceviri.dil.value,
      'zh',
      reason:
          'Basitleştirilmiş Çince göstermek geleneksel yazı okuruna kusurlu '
          'ama İngilizceye düşürmekten yakın; karar cihaz_dili notunda',
    );
    expect('Ayarlar'.c, '设置');
  });

  test('zh-Hans-CN → zh', () async {
    await _ac([
      const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
        countryCode: 'CN',
      ),
    ]);
    expect(Ceviri.dil.value, 'zh');
  });

  // ---------------------------------------------------------------------
  // 3. Desteklenmeyen dil → İngilizce (Türkçe DEĞİL)
  // ---------------------------------------------------------------------
  test(
    'sv-SE ASLINDA destekleniyor → İsveççe (istek listesindeki yanılgı)',
    () async {
      // İstek listesi sv'yi "desteklenmiyor" örneği diye veriyordu; oysa
      // `Ceviri.diller` içinde 'sv': 'Svenska' VAR. Bu yüzden geri düşüş
      // örneği olarak gerçekten listede olmayan bir dil (is/mt/lb) kullanıldı.
      expect(Ceviri.diller.containsKey('sv'), isTrue);
      await _ac([_y('sv', 'SE')]);
      expect(Ceviri.dil.value, 'sv');
    },
  );

  test('is-IS (desteklenmiyor) → İngilizce', () async {
    await _ac([_y('is', 'IS')]);
    expect(
      Ceviri.dil.value,
      'en',
      reason: 'Türkçe bilmeyene Türkçe göstermek İngilizceden kötü',
    );
    expect(Ceviri.dil.value, isNot(Ceviri.varsayilan));
    expect('Ayarlar'.c, 'Settings');
  });

  test('geri düşüş dili anahtar dilinden AYRI bir kavram', () {
    expect(Ceviri.varsayilan, 'tr', reason: 'çeviri anahtarlarının kaynağı');
    expect(Ceviri.tespitGerilemesi, 'en', reason: 'tanınmayan cihaz dili');
  });

  // ---------------------------------------------------------------------
  // 4. Cihaz BİRDEN FAZLA dil verir: sırayla dene
  // ---------------------------------------------------------------------
  test('[sv, de, en] → de (ilk desteklenen; sv listede yok)', () async {
    // sv listede VAR olduğu için gerçek bir "atlama" senaryosu kurmak
    // adına desteklemediğimiz bir dille başlıyoruz.
    await _ac([_y('is'), _y('de'), _y('en')]);
    expect(Ceviri.dil.value, 'de');
  });

  test('birinci tercih desteklenmiyorsa ÜÇÜNCÜYE kadar bakılır', () async {
    await _ac([_y('is'), _y('mt'), _y('ko', 'KR')]);
    expect(Ceviri.dil.value, 'ko');
  });

  test('hiçbir tercih desteklenmiyorsa İngilizce', () async {
    await _ac([_y('is'), _y('mt'), _y('lb')]);
    expect(Ceviri.dil.value, 'en');
  });

  test('birinci tercih desteklenirse sonrakilere BAKILMAZ', () async {
    await _ac([_y('fr', 'CA'), _y('en', 'CA')]);
    expect(Ceviri.dil.value, 'fr');
  });

  // ---------------------------------------------------------------------
  // 5. Eski/eş anlamlı platform kodları
  // ---------------------------------------------------------------------
  test('Android eski kodları: iw→he, in→id (ikisi de DESTEKLİ dil)', () async {
    await _ac([_y('iw', 'IL')]);
    expect(Ceviri.dil.value, 'he', reason: 'Java Locale İbranice için iw der');
    await _ac([_y('in', 'ID')]);
    expect(Ceviri.dil.value, 'id', reason: 'Java Locale Endonezce için in der');
  });

  test('tl → fil (Tagalog/Filipino aynı dosyamız)', () async {
    await _ac([_y('tl', 'PH')]);
    expect(Ceviri.dil.value, 'fil');
    expect('Ayarlar'.c, 'Mga Setting');
  });

  test('no/nn → nb (elimizdeki tek Norveççe yazı normu)', () async {
    await _ac([_y('no', 'NO')]);
    expect(Ceviri.dil.value, 'nb');
    await _ac([_y('nn', 'NO')]);
    expect(Ceviri.dil.value, 'nb');
    expect('Ayarlar'.c, 'Innstillinger');
  });

  test('desteklenen 45 dilin HEPSİ kendi kodundan bulunur', () {
    for (final kod in Ceviri.diller.keys) {
      expect(
        Ceviri.cihazDiliEsle([Locale(kod)]),
        kod,
        reason: '$kod cihaz dili olarak verilse bulunamıyor',
      );
    }
  });

  // ---------------------------------------------------------------------
  // 6. KULLANICI SEÇİMİ KUTSAL
  // ---------------------------------------------------------------------
  test('kullanıcı Türkçe seçtiyse cihaz İngilizcesi onu EZMEZ', () async {
    await _ac([_y('en', 'US')], kayit: {'dil': 'tr'});
    expect(Ceviri.dil.value, 'tr');
    expect('Ayarlar'.c, 'Ayarlar');
  });

  test('kullanıcı Japonca seçtiyse Almanca cihaz onu EZMEZ', () async {
    await _ac([_y('de', 'DE')], kayit: {'dil': 'ja'});
    expect(Ceviri.dil.value, 'ja');
    expect('Ayarlar'.c, '設定');
  });

  test('ayarlardan seçim SONRAKİ açılışta da korunur', () async {
    await _ac([_y('en', 'US')]);
    expect(Ceviri.dil.value, 'en', reason: 'seçim yokken cihaz dili');
    // Kullanıcı ayarlardan Fransızcayı seçiyor (tek yazan yer: Ceviri.sec).
    await Ceviri.sec('fr');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('dil'), 'fr');
    // Uygulama kapanıp açılıyor: cihaz hâlâ İngilizce.
    Ceviri.cihazDilleri = () => [_y('en', 'US')];
    await Ceviri.yukle();
    expect(Ceviri.dil.value, 'fr');
    expect('Ayarlar'.c, 'Paramètres');
  });

  test('tespit edilen dil KAYDEDİLMEZ (seçim ile karışmasın)', () async {
    await _ac([_y('de', 'DE')]);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('dil'),
      isNull,
      reason:
          '`dil` anahtarının varlığı "kullanıcı seçti" demek; tespit onu '
          'yazsaydı sonraki açılışlarda cihaz dili değişse bile takılı kalırdı',
    );
  });

  test('telefonun dili değişirse (seçim yokken) uygulama uyar', () async {
    await _ac([_y('de', 'DE')]);
    expect(Ceviri.dil.value, 'de');
    // Kullanıcı telefonunu İtalyancaya çeviriyor; kayıt hâlâ boş.
    Ceviri.cihazDilleri = () => [_y('it', 'IT')];
    await Ceviri.yukle();
    expect(Ceviri.dil.value, 'it');
  });

  // ---------------------------------------------------------------------
  // 7. GÜNCELLEME: mevcut kullanıcı dilini KAYBETMEZ
  // ---------------------------------------------------------------------
  test(
    'kayıtlı dili olan mevcut kullanıcı güncellemeden sonra da o dilde',
    () async {
      // Güncelleme öncesi kurulumdan kalan tipik kayıt kümesi.
      await _ac(
        [_y('en', 'US'), _y('tr', 'TR')],
        kayit: {
          'dil': 'de',
          'token': 'eski-oturum',
          'cihaz_kimlik': '0123456789abcdef0123456789abcdef',
          'tema': 'koyu',
        },
      );
      expect(Ceviri.dil.value, 'de');
      expect('Ayarlar'.c, 'Einstellungen');
    },
  );

  test('kayıt biçimi DEĞİŞMEDİ: eski sürümün yazdığı `dil` okunur', () async {
    // Eski sürüm de aynı anahtarı aynı biçimde yazıyordu; migrasyon yok.
    for (final kod in ['tr', 'en', 'ru', 'fil', 'nb']) {
      await _ac([_y('is')], kayit: {'dil': kod});
      expect(Ceviri.dil.value, kod);
    }
  });

  test('artık desteklenmeyen kayıtlı kod → tespite düşülür', () async {
    await _ac([_y('de', 'DE')], kayit: {'dil': 'xx'});
    expect(Ceviri.dil.value, 'de');
  });

  // ---------------------------------------------------------------------
  // 8. Platform hiç dil bildirmezse tahmin yürütme
  // ---------------------------------------------------------------------
  test('boş dil listesi → eldeki dil korunur (İngilizceye ZIPLAMAZ)', () async {
    await _ac([]);
    expect(
      Ceviri.dil.value,
      Ceviri.varsayilan,
      reason:
          'arka plan izolatında platform dil bildirmeyebilir; orada '
          'İngilizceye atlamak Türk kullanıcının bildirim düğmelerini bozar',
    );
  });

  // ---------------------------------------------------------------------
  // 9. TMDB içerik dili de değişir (X-Dil + adres)
  // ---------------------------------------------------------------------
  test('tespit edilen dil X-Dil başlığına ve /tmdb/ adresine yansır', () async {
    await _ac([_y('de', 'DE')]);
    String? gonderilenDil;
    Uri? gidilenAdres;
    Api.istemci = MockClient((istek) async {
      gonderilenDil = istek.headers['X-Dil'];
      gidilenAdres = istek.url;
      return http.Response(
        jsonEncode(<String, dynamic>{}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    addTearDown(() => Api.istemci = http.Client());

    await Api.get('/tmdb/dizi/1399');
    expect(gonderilenDil, 'de', reason: 'özetler de Almanca gelmeli');
    expect(gidilenAdres!.queryParameters['dil'], 'de');
  });

  test('kullanıcı seçimi X-Dil başlığını da belirler', () async {
    await _ac([_y('de', 'DE')], kayit: {'dil': 'tr'});
    String? gonderilenDil;
    Api.istemci = MockClient((istek) async {
      gonderilenDil = istek.headers['X-Dil'];
      return http.Response(
        jsonEncode(<String, dynamic>{}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    addTearDown(() => Api.istemci = http.Client());

    await Api.get('/tmdb/dizi/1399');
    expect(gonderilenDil, 'tr');
  });

  // ---------------------------------------------------------------------
  // 10. Açılış sırası: dil İLK KAREDEN önce kurulur (göz kırpması yok)
  // ---------------------------------------------------------------------
  test('main() dili runApp\'ten ÖNCE yükler', () {
    final kaynak = File('lib/main.dart').readAsStringSync();
    // 29 Ağu 2026: çağrı iki satıra yayıldı (`acilisAdimi(\n  'ceviri', ...)`)
    // çünkü artık adres parametresi de veriliyor. Arama bu yüzden yalnız
    // ADIM ADINA bakıyor — biçimlendirici satır kırdığında test kırılmasın.
    final ceviriYeri = kaynak.indexOf("'ceviri',");
    final runAppYeri = kaynak.indexOf('runApp(');
    final bagliyici = kaynak.indexOf('WidgetsFlutterBinding.ensureInitialized');
    expect(ceviriYeri, greaterThan(-1));
    expect(runAppYeri, greaterThan(-1));
    expect(
      ceviriYeri,
      lessThan(runAppYeri),
      reason: 'sonraya kalırsa ilk kare Türkçe çizilir, sonra dil değişir',
    );
    expect(
      bagliyici,
      lessThan(ceviriYeri),
      reason: 'platform dil listesi bağlayıcı kurulmadan güvenilir değil',
    );
    // `await` ile çağrılıyor mu — beklenmezse açılış yarışına girer.
    // Çağrı 29 Ağu 2026'da iki satıra yayıldı (adres parametresi eklendi),
    // bu yüzden `await acilisAdimi(` ile `'ceviri',` arasına yalnız boşluk /
    // satır sonu girebilir.
    expect(
      RegExp(r"await acilisAdimi\(\s*'ceviri',").hasMatch(kaynak),
      isTrue,
      reason: 'beklenmezse açılış yarışına girer',
    );
    // Dil ADRESTEN de okunuyor (dil önekli SSR URL'leri, 29 Ağu 2026).
    expect(
      kaynak.contains('Ceviri.yukle(adres:'),
      isTrue,
      reason: '/de/icerik/... ile gelen ziyaretçi uygulamayı Türkçe açardı',
    );
  });
}
