// İZLEME ODASI — video HAZIRLAMA (MKV desteği) arayüz testleri.
//
// Sunucu yüklenen dosyayı ffprobe ile inceleyip gerekiyorsa kabı MP4'e
// çeviriyor ve/veya sesi AAC'ye indiriyor (kök sebep: Matroska ile WebM aynı
// sihirli baytları taşıdığı için MKV sessizce kabul edilip `.webm` diye
// kaydediliyordu; içindeki H.264+AC3 tarayıcıda hiç, Android'de SESSİZ oynardı).
//
// Bu dosya İSTEMCİNİN o süreçte doğru şeyi çizdiğini kilitler. Kararın
// kendisi sunucuda ve saf: `backend/test/video_hazirla.test.js`.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/oda/oda_api.dart';
import 'package:dizijpg/oda/oda_ekrani.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _benimId = 184;

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _oda({
  bool sahibiMiyim = true,
  String? video,
  String durum = 'yok',
  int yuzde = 0,
  String? hata,
  String? videoKodek,
  List<String> uyumsuz = const [],
}) => {
  'id': 5,
  'kod': 'AB2CD3',
  'baslik': 'Cuma gecesi',
  'sahip_id': sahibiMiyim ? _benimId : 9,
  'sahip': sahibiMiyim ? 'ben' : 'baskasi',
  'sahip_avatar': null,
  'video': video,
  'video_ad': video == null ? null : 'film.mkv',
  'video_boyut': null,
  'video_sure_ms': null,
  'video_kapak': null,
  'oynuyor': false,
  'konum_ms': 0,
  'konum_zaman': DateTime.now().millisecondsSinceEpoch,
  'hiz': 1.0,
  'surum': 1,
  'biter': DateTime.now().millisecondsSinceEpoch + 12 * 3600 * 1000,
  'sahibi_miyim': sahibiMiyim,
  'sunucu_zaman': DateTime.now().millisecondsSinceEpoch,
  'hazirlik_durum': durum,
  'hazirlik_yuzde': yuzde,
  'hazirlik_hata': hata,
  'video_kodek': videoKodek,
  'ses_kodek': 'aac',
  'uyumsuz': uyumsuz,
  'uyeler': [
    {
      'id': sahibiMiyim ? _benimId : 9,
      'ad': sahibiMiyim ? 'ben' : 'baskasi',
      'avatar': null,
      'rol': 'sahip',
      'katildi': 1,
      'hazir': true,
      'cevrimici': true,
    },
  ],
};

late List<String> gonderilen;

/// Sahte sunucu. [akisOdalari] verilirse yoklama SIRAYLA o durumları döndürür
/// — hazırlığın ilerlemesini taklit etmenin tek yolu bu.
void _sunucu(Map<String, dynamic> oda, {List<Map<String, dynamic>>? akislar}) {
  gonderilen = [];
  var tur = 0;
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    gonderilen.add('${istek.method} $yol');
    if (yol.endsWith('/akis')) {
      final kaynak = akislar == null
          ? oda
          : akislar[tur < akislar.length ? tur++ : akislar.length - 1];
      return _json({
        'sunucu_zaman': DateTime.now().millisecondsSinceEpoch,
        'surum': kaynak['surum'],
        'biter': kaynak['biter'],
        'durum': null,
        'uyeler': null,
        'mesajlar': <dynamic>[],
        'hazirlik_durum': kaynak['hazirlik_durum'],
        'hazirlik_yuzde': kaynak['hazirlik_yuzde'],
        'hazirlik_hata': kaynak['hazirlik_hata'],
        'video_kodek': kaynak['video_kodek'],
        'ses_kodek': kaynak['ses_kodek'],
        'uyumsuz': kaynak['uyumsuz'],
      });
    }
    if (yol.endsWith('/video-cevir')) return _json({'tamam': true});
    if (yol.endsWith('/hazir')) return _json({'tamam': true});
    return _json(oda);
  });
}

Widget _sar(Widget cocuk) => ChangeNotifierProvider<Oturum>(
  create: (_) => Oturum()..kullanici = {'id': _benimId, 'kullanici_adi': 'ben'},
  child: MaterialApp(home: cocuk),
);

Future<void> _ac(WidgetTester t) async {
  await t.pumpWidget(_sar(const OdaEkrani(odaId: 5)));
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ceviri.yukle();
  });

  testWidgets('İŞLENİYOR: yüzde ve ne yapıldığı yazıyor', (t) async {
    _sunucu(_oda(video: '/medya/o5-a.mp4', durum: 'isleniyor', yuzde: 42));
    await _ac(t);
    expect(find.text('Hazırlanıyor · %{}'.cf([42])), findsOneWidget);
    // NE YAPILDIĞI da söylenmeli: yalnız "hazırlanıyor" ne kadar süreceği
    // hakkında hiçbir şey demez.
    expect(
      find.text('Video, her cihazda oynayacak biçime çevriliyor.'.c),
      findsOneWidget,
    );
  });

  testWidgets('KUYRUKTA: yüzde DEĞİL "sırada" yazar', (t) async {
    // Kuyruktaki iş henüz başlamadı; %0 göstermek yanlış olurdu.
    _sunucu(_oda(video: '/medya/o5-a.mp4', durum: 'kuyrukta'));
    await _ac(t);
    expect(find.text('Sırada bekliyor'.c), findsOneWidget);
    // Kuyruktaki iş için yüzde gösterilmemeli (henüz başlamadı).
    expect(find.text('Hazırlanıyor · %{}'.cf([0])), findsNothing);
  });

  testWidgets('ilerleme yoklama turlarıyla GÜNCELLENİYOR', (t) async {
    // Sürüm ARTMIYOR — yüzde yine de akmalı. `durum` bloğuna konsaydı çubuk
    // %10'da donardı (sunucu tarafında ayrı alan olmasının sebebi bu).
    _sunucu(
      _oda(video: '/medya/o5-a.mp4', durum: 'isleniyor', yuzde: 10),
      akislar: [
        _oda(video: '/medya/o5-a.mp4', durum: 'isleniyor', yuzde: 10),
        _oda(video: '/medya/o5-a.mp4', durum: 'isleniyor', yuzde: 77),
      ],
    );
    await _ac(t);
    expect(find.text('Hazırlanıyor · %{}'.cf([10])), findsOneWidget);
    // İKİ tur: ilk yoklama listenin ilk öğesini (10) tüketir, ikincisi 77'yi
    // getirir. Sürüm ARTMIYOR — yüzde yine de akmalı.
    for (var i = 0; i < 2; i++) {
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Hazırlanıyor · %{}'.cf([77])), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
  });

  testWidgets('HATA: sebep yazılıyor ve sahibe ÇIKIŞ YOLU veriliyor', (
    t,
  ) async {
    _sunucu(_oda(durum: 'hata', hata: 'VIDEO_KODEK_DESTEKSIZ'));
    await _ac(t);
    // "Desteklenmiyor" tek başına çıkmaz bir hata mesajıdır; ne yapacağını söyle.
    expect(
      find.text(
        'Bu videonun görüntü biçimi oynatılamıyor. MP4 (H.264) olarak çevirip yeniden dene.'
            .c,
      ),
      findsOneWidget,
    );
    expect(find.text('Başka video yükle'.c), findsOneWidget);
  });

  testWidgets('HATA: izleyiciye yükleme düğmesi ÇİZİLMEZ', (t) async {
    _sunucu(_oda(sahibiMiyim: false, durum: 'hata', hata: 'VIDEO_OKUNAMADI'));
    await _ac(t);
    expect(
      find.text('Video okunamadı, dosya bozuk olabilir'.c),
      findsOneWidget,
    );
    expect(find.text('Başka video yükle'.c), findsNothing);
  });

  testWidgets('hazırlık bitince yer tutucu kalkar (oynatıcı kurulur)', (
    t,
  ) async {
    _sunucu(
      _oda(video: '/medya/o5-a.mp4', durum: 'isleniyor', yuzde: 90),
      akislar: [
        _oda(video: '/medya/o5-a.mp4', durum: 'isleniyor', yuzde: 90),
        _oda(video: '/medya/o5-a.mp4', durum: 'yok', yuzde: 100),
      ],
    );
    await _ac(t);
    expect(find.text('Hazırlanıyor · %{}'.cf([90])), findsOneWidget);
    for (var i = 0; i < 2; i++) {
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(milliseconds: 50));
    }
    // Hazırlık bitti: yer tutucu metinlerinin HİÇBİRİ kalmamalı.
    expect(find.text('Hazırlanıyor · %{}'.cf([90])), findsNothing);
    expect(find.text('Sırada bekliyor'.c), findsNothing);
    await t.pump(const Duration(seconds: 2));
  });

  testWidgets('hazırlık sürerken "Video yükle" boş durumu GÖSTERİLMEZ', (
    t,
  ) async {
    // Yer tutucular birbirini ezmemeli: hazırlık sürerken kullanıcıya "video
    // yok, yükle" demek yanlış bilgi olurdu.
    _sunucu(_oda(video: '/medya/o5-a.mp4', durum: 'isleniyor', yuzde: 5));
    await _ac(t);
    expect(find.text('Video yükle'.c), findsNothing);
    expect(find.text('Bir video yükle, izlemeye başlayın'.c), findsNothing);
  });

  testWidgets('uyumsuz kodek uyarısı MOBİLDE web için GÖSTERİLMEZ', (t) async {
    // H.265 telefonda ZATEN oynar; orada uyarı göstermek yanlış alarm olurdu.
    _sunucu(
      _oda(video: '/medya/o5-a.mp4', videoKodek: 'hevc', uyumsuz: ['web']),
    );
    await _ac(t);
    expect(
      find.text('Bu videoyu tarayıcı oynatamıyor. Telefondan aç.'.c),
      findsNothing,
    );
    await t.pump(const Duration(seconds: 2));
  });

  group('model', () {
    test('OdaHazirlik: durum bayrakları', () {
      const h = OdaHazirlik(durum: 'isleniyor', yuzde: 30);
      expect(h.suruyor, isTrue);
      expect(h.kuyrukta, isFalse);
      expect(h.hataliMi, isFalse);
      expect(const OdaHazirlik(durum: 'kuyrukta').kuyrukta, isTrue);
      expect(const OdaHazirlik(durum: 'hata').hataliMi, isTrue);
      expect(const OdaHazirlik().suruyor, isFalse);
    });

    test('OdaHazirlik.json: eksik alanlar güvenli varsayılana düşer', () {
      // Migrasyon uygulanmadan yeni istemci eski sunucuya bağlanabilir;
      // alanlar yoksa "hazırlık yok" doğru varsayımdır — yoksa ekran boş bir
      // ilerleme çubuğunda takılırdı.
      final h = OdaHazirlik.json(const {});
      expect(h.durum, 'yok');
      expect(h.yuzde, 0);
      expect(h.uyumsuz, isEmpty);
      expect(h.suruyor, isFalse);
    });

    test(
      'hata anahtarları çevrili cümleye dönüyor, bilinmeyen genel metne',
      () {
        expect(
          odaHazirlikHatasi('VIDEO_GORUNTU_YOK'),
          'Bu dosyada görüntü yok'.c,
        );
        expect(
          odaHazirlikHatasi('DISK_YETERSIZ'),
          'Sunucuda yer kalmadı, biraz sonra tekrar dene'.c,
        );
        expect(odaHazirlikHatasi('BILINMEYEN_KOD'), 'Video hazırlanamadı'.c);
        expect(odaHazirlikHatasi(null), 'Video hazırlanamadı'.c);
      },
    );
  });
}
