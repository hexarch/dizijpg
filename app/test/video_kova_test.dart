// md. 23 — VİDEO İZLENME SÜRESİ (ELDE TUTMA) ÖLÇÜSÜ · istemci tarafı
//
// Kilitlenen davranışlar (CLAUDE.md kural 7):
//   * KOVA HESABI saf ve sınırlarda doğru: süre 0, konum 0, çok kısa video,
//     konumun süreyi aşması.
//   * *** EN YÜKSEK KOVA DÜŞMEZ ***: ileri sarma yükseltir, GERİ SARMA ve
//     döngü (setLooping) DÜŞÜRMEZ. Ölçü "en uzağa nereye gidildi" sorusudur.
//   * *** TEK GÖNDERİM ***: gonder() kaç kez çağrılırsa çağrılsın uca BİR
//     istek çıkar. dispose + "oynatma bitti" aynı anda tetiklenebilir.
//   * HİÇ OYNAMAYAN kart HİÇ İSTEK ATMAZ: akış ilerideki kartları önden kurar,
//     onlar eğrinin paydasına girmemeli.
//   * gonderiId yoksa (bölüm kareleri, düzenleme önizlemesi) ölçü KAPALI.
//   * Gövde yalnız {kova: n} — KİŞİ BİLGİSİ YOK.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/video_kova.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Uca giden istekleri toplar (yol + çözülmüş gövde).
class _Kayit {
  final List<Uri> yollar = [];
  final List<Map<String, dynamic>> govdeler = [];
}

Future<_Kayit> _agiKur() async {
  final k = _Kayit();
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  Api.istemci = MockClient((istek) async {
    k.yollar.add(istek.url);
    k.govdeler.add(
      istek.body.isEmpty
          ? <String, dynamic>{}
          : (jsonDecode(istek.body) as Map).cast<String, dynamic>(),
    );
    return http.Response(
      jsonEncode({'tamam': true}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  return k;
}

Duration _sn(num s) => Duration(milliseconds: (s * 1000).round());

/// İstek ATEŞLE-UNUT gider (Future beklenmez); MockClient geri çağırması bir
/// sonraki olay turunda koşar. Doğrulamadan önce o turu bekletiyoruz —
/// beklemeden bakmak testi "istek hiç gitmedi" diye yanıltırdı.
Future<void> _tur() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  // -------------------------------------------------------------------------
  // SAF KOVA HESABI
  // -------------------------------------------------------------------------
  test('kova hesabı: 20 EŞİT dilim, %0 → 0, %50 → 10, son an → 19', () {
    final sure = _sn(100);
    expect(videoKovaHesapla(_sn(0.001), sure), 0);
    expect(videoKovaHesapla(_sn(4.9), sure), 0);
    expect(videoKovaHesapla(_sn(5), sure), 1);
    expect(videoKovaHesapla(_sn(50), sure), 10);
    expect(videoKovaHesapla(_sn(95), sure), 19);
    expect(videoKovaHesapla(_sn(99.9), sure), 19);
  });

  test('kova hesabı: SÜRE 0 iken null (sıfıra bölme yok)', () {
    expect(videoKovaHesapla(_sn(3), Duration.zero), isNull);
    expect(videoKovaHesapla(Duration.zero, Duration.zero), isNull);
    expect(videoKovaHesapla(_sn(3), const Duration(milliseconds: -5)), isNull);
  });

  test('kova hesabı: KONUM 0 iken null (kurulan ama oynamayan kart)', () {
    // Akış ilerideki kartları önden kurar; onlar paydaya girmemeli.
    expect(videoKovaHesapla(Duration.zero, _sn(30)), isNull);
    expect(videoKovaHesapla(const Duration(milliseconds: -1), _sn(30)), isNull);
  });

  test('kova hesabı: ÇOK KISA videoda da 0..19 dışına çıkmaz', () {
    // 200 ms'lik bir GIF-video: her 10 ms bir kova.
    const sure = Duration(milliseconds: 200);
    expect(videoKovaHesapla(const Duration(milliseconds: 1), sure), 0);
    expect(videoKovaHesapla(const Duration(milliseconds: 100), sure), 10);
    expect(videoKovaHesapla(const Duration(milliseconds: 199), sure), 19);
    // 1 ms'lik saçma süre bile taşmaz.
    const mini = Duration(milliseconds: 1);
    expect(videoKovaHesapla(const Duration(milliseconds: 1), mini), 19);
  });

  test('kova hesabı: konum SÜREYİ AŞARSA son kovaya kırpılır', () {
    // Son karede yuvarlama / döngüde sıçrama gerçek bir durumdur.
    expect(videoKovaHesapla(_sn(120), _sn(100)), 19);
    expect(videoKovaHesapla(_sn(100), _sn(100)), 19);
  });

  // -------------------------------------------------------------------------
  // İZLEYİCİ — en yüksek kova ve tek gönderim
  // -------------------------------------------------------------------------
  test('EN YÜKSEK KOVA DÜŞMEZ: geri sarma ve döngü ölçüyü bozmaz', () async {
    await _agiKur();
    final iz = VideoKovaIzleyici(42);
    void gor(num sn) =>
        iz.guncelle(url: 'a.mp4', konum: _sn(sn), sure: _sn(100));
    gor(10); // kova 2
    expect(iz.enYuksekKova, 2);
    gor(80); // ileri sarma → 16
    expect(iz.enYuksekKova, 16);
    gor(20); // GERİ sarma → düşmemeli
    expect(iz.enYuksekKova, 16);
    gor(0.001); // döngü başa sardı → düşmemeli
    expect(iz.enYuksekKova, 16);
    gor(99); // ikinci turda sonuna gitti → 19
    expect(iz.enYuksekKova, 19);
  });

  test(
    'TEK GÖNDERİM: gonder() üç kez çağrılsa da uca BİR istek gider',
    () async {
      final k = await _agiKur();
      final iz = VideoKovaIzleyici(42)
        ..guncelle(url: 'a.mp4', konum: _sn(60), sure: _sn(100));
      iz.gonder();
      iz.gonder();
      iz.gonder();
      await _tur();
      expect(k.yollar.length, 1);
      expect(k.yollar.first.path, endsWith('/gonderi/42/video-kova'));
      expect(iz.gonderildi, isTrue);
    },
  );

  test('GÖVDE yalnız {kova: n} — KİŞİ BİLGİSİ YOK', () async {
    final k = await _agiKur();
    VideoKovaIzleyici(42)
      ..guncelle(url: 'a.mp4', konum: _sn(60), sure: _sn(100))
      ..gonder();
    await _tur();
    expect(k.govdeler.single.keys.toList(), ['kova']);
    expect(k.govdeler.single['kova'], 12); // 60/100 → 12. kova
    for (final yasak in const [
      'kullanici_id',
      'kullanici_adi',
      'izleyen',
      'ip',
      'oturum',
      'cihaz',
    ]) {
      expect(k.govdeler.single.containsKey(yasak), isFalse, reason: yasak);
    }
  });

  test('HİÇ OYNAMAYAN kart HİÇ İSTEK ATMAZ (paydayı şişirmez)', () async {
    final k = await _agiKur();
    // Kart kuruldu, süre öğrenildi, ama konum hep 0.
    final iz = VideoKovaIzleyici(42)
      ..guncelle(url: 'a.mp4', konum: Duration.zero, sure: _sn(30));
    iz.gonder();
    await _tur();
    expect(iz.enYuksekKova, isNull);
    expect(k.yollar, isEmpty);
  });

  test(
    'gonderiId YOKSA ölçü kapalı (bölüm kareleri, düzenleme önizlemesi)',
    () async {
      final k = await _agiKur();
      for (final kimlik in [null, 0, -3, 'abc', '']) {
        final iz = VideoKovaIzleyici(kimlik)
          ..guncelle(url: 'a.mp4', konum: _sn(60), sure: _sn(100));
        iz.gonder();
        expect(iz.acik, isFalse, reason: '$kimlik');
        expect(iz.enYuksekKova, isNull, reason: '$kimlik');
      }
      await _tur();
      expect(k.yollar, isEmpty);
    },
  );

  test('gonderiId METİN olarak gelirse de çalışır (harita dinamik)', () async {
    final k = await _agiKur();
    VideoKovaIzleyici('42')
      ..guncelle(url: 'a.mp4', konum: _sn(99), sure: _sn(100))
      ..gonder();
    await _tur();
    expect(k.yollar.single.path, endsWith('/gonderi/42/video-kova'));
    expect(k.govdeler.single['kova'], 19);
  });

  test('ÇOKLU VİDEOLU gönderi: yalnız İLK oynayan video ölçülür', () async {
    final k = await _agiKur();
    final iz = VideoKovaIzleyici(42)
      // İlk video: %30'a kadar (kova 6).
      ..guncelle(url: 'bir.mp4', konum: _sn(30), sure: _sn(100))
      // Kullanıcı yana kaydırdı, ikinci video sonuna kadar oynadı.
      ..guncelle(url: 'iki.mp4', konum: _sn(99), sure: _sn(100));
    expect(iz.enYuksekKova, 6, reason: 'ikinci video ölçüye karışmamalı');
    iz.gonder();
    await _tur();
    expect(k.yollar.length, 1, reason: 'görüntülenme başına EN FAZLA 1 istek');
  });

  test('GÖNDERİMDEN SONRA gelen konum güncellemeleri yok sayılır', () async {
    final k = await _agiKur();
    final iz = VideoKovaIzleyici(42)
      ..guncelle(url: 'a.mp4', konum: _sn(10), sure: _sn(100));
    iz.gonder();
    iz.guncelle(url: 'a.mp4', konum: _sn(99), sure: _sn(100));
    iz.gonder();
    await _tur();
    expect(k.yollar.length, 1);
    expect(
      k.govdeler.single['kova'],
      2,
      reason: 'gönderilen değer sonradan değişmez',
    );
  });

  test('SUNUCU HATASI kullanıcıya sızmaz (ateşle-unut)', () async {
    SharedPreferences.setMockInitialValues({'token': 'sahte'});
    await Api.tokenYukle();
    Api.istemci = MockClient(
      (_) async => http.Response(
        jsonEncode({'hata': 'Çok fazla istek'}),
        429,
        headers: {'content-type': 'application/json'},
      ),
    );
    // Fırlatmamalı; hata yutulur.
    VideoKovaIzleyici(42)
      ..guncelle(url: 'a.mp4', konum: _sn(60), sure: _sn(100))
      ..gonder();
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });

  test('istemci kova sayısı SUNUCUYLA aynı (20)', () {
    // Kayarsa istemci sözlük dışı değer gönderir, sunucu 400 verir ve ölçü
    // sessizce durur — hiçbir yerde hata görünmez.
    expect(videoKovaSayisi, 20);
  });

  // -------------------------------------------------------------------------
  // BAĞLANTI — gönderi kimliği oynatıcıya GERÇEKTEN ULAŞIYOR mu?
  // -------------------------------------------------------------------------
  // Saf birim testi "hesap doğru" der ama kimlik yolda kaybolursa ölçü sessizce
  // hiç yazılmaz ve kimse fark etmez (eğri hep boş kalır). Bu yüzden akış
  // kartının GERÇEK widget ağacı kuruluyor.
  Future<void> galeriKur(WidgetTester tester, {Object? gonderiId}) async {
    // AkisVideo bir VisibilityDetector içinde: varsayılan 500 ms'lik iç
    // zamanlayıcı testin sonunda "Timer is still pending" hatası verirdi.
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    await tester.pumpWidget(
      MaterialApp(
        theme: diziTema(acik: false),
        home: Scaffold(
          body: MedyaGaleri(
            yollar: const ['/medya/a.mp4'],
            otomatikOynat: true,
            gonderiId: gonderiId,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('AKIŞ KARTI: gönderi kimliği AkisVideo\'ya ULAŞIYOR', (
    tester,
  ) async {
    await galeriKur(tester, gonderiId: 7);
    final video = tester.widget<AkisVideo>(find.byType(AkisVideo));
    expect(video.gonderiId, 7);
    // Kimlik gerçekten ölçüyü AÇIYOR mu (tip dönüşümü dahil)?
    expect(VideoKovaIzleyici(video.gonderiId).acik, isTrue);
  });

  testWidgets('gönderi kimliği VERİLMEZSE ölçü kapalı kalır (bölüm kareleri)', (
    tester,
  ) async {
    await galeriKur(tester);
    final video = tester.widget<AkisVideo>(find.byType(AkisVideo));
    expect(video.gonderiId, isNull);
    expect(VideoKovaIzleyici(video.gonderiId).acik, isFalse);
  });
}
