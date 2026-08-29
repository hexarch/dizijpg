import 'dart:ui' show Locale;

import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DİL ÖNEKLİ ADRES — `/de/icerik/movie/559`   (29 Ağustos 2026)
///
/// NEDEN VAR: SSR o gün 46 dile açıldı ve arama motorlarına DİZİN TABANLI dil
/// önekli URL'ler verildi. Almanca bir arama sonucuna tıklayan ziyaretçi
/// `https://dizijpg.com/de/icerik/movie/559` adresine düşüyor.
///
/// İKİ AYRI KUSUR BURADA KİLİTLİ:
///
///  1. **ROTA EŞLEŞMESİ.** Uygulamada `/de/icerik/...` diye bir rota YOK;
///     önek atılmasaydı `errorBuilder`, yani "Bağlantı geçersiz" ekranı
///     çıkardı. Yani Google'dan gelen HER yabancı dilli ziyaretçi kırık
///     sayfa görürdü — sitenin dışarıya açılan yüzü tam da orası.
///  2. **DİL TUTARLILIĞI.** Bot o adreste Almanca SSR alıyor; insan Türkçe
///     kabuk görseydi bot ile insanın gördüğü sayfa ayrışırdı.
///
/// SIRA KUTSAL: kullanıcının SEÇİMİ > adresteki dil > cihaz dili. Seçim
/// varsa adres okunmaz (mevcut kural değişmedi).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Ceviri.cihazDilleri = () => const [];
  });

  tearDown(() {
    Ceviri.cihazDilleri = Ceviri.platformDilleri;
  });

  group('Ceviri.adresDiliKodu', () {
    test('dil öneki tanınır', () {
      expect(Ceviri.adresDiliKodu(Uri.parse('https://dizijpg.com/de/icerik/movie/559')),
          'de');
      expect(Ceviri.adresDiliKodu(Uri.parse('https://dizijpg.com/ja/kisi/1')), 'ja');
      expect(Ceviri.adresDiliKodu(Uri.parse('https://dizijpg.com/en')), 'en');
    });

    test('öneksiz adres ve `tr` öneki null (Türkçe KÖKTE yaşıyor)', () {
      expect(Ceviri.adresDiliKodu(Uri.parse('https://dizijpg.com/icerik/movie/559')),
          isNull);
      // `/tr/...` diye bir kanonik YOK — sunucu tarafı da reddediyor.
      expect(Ceviri.adresDiliKodu(Uri.parse('https://dizijpg.com/tr/icerik/movie/1')),
          isNull);
      expect(Ceviri.adresDiliKodu(Uri.parse('https://dizijpg.com/')), isNull);
      expect(Ceviri.adresDiliKodu(null), isNull);
    });

    test('DESTEKLENMEYEN kod dil öneki SAYILMAZ (rota parçası olabilir)', () {
      // `/zz/...` bir dil değil; `/kesfet` gibi gerçek bir rota da olabilirdi.
      expect(Ceviri.adresDiliKodu(Uri.parse('https://dizijpg.com/zz/kisi/1')), isNull);
      expect(Ceviri.adresDiliKodu(Uri.parse('https://dizijpg.com/kesfet')), isNull);
      expect(Ceviri.adresDiliKodu(Uri.parse('https://dizijpg.com/gozat')), isNull);
    });
  });

  group('baslangicRotasi dil önekini DÜŞÜRÜR', () {
    test('dil önekli derin bağlantı doğru rotaya açılır', () {
      expect(baslangicRotasi(Uri.parse('https://dizijpg.com/de/icerik/movie/559')),
          '/icerik/movie/559');
      expect(
          baslangicRotasi(
              Uri.parse('https://dizijpg.com/ja/dizi/1396/sezon/5/bolum/14')),
          '/dizi/1396/sezon/5/bolum/14');
      expect(baslangicRotasi(Uri.parse('https://dizijpg.com/ar/kisi/1')), '/kisi/1');
    });

    test('yalnız dil öneki olan adres ana sayfaya açılır', () {
      expect(baslangicRotasi(Uri.parse('https://dizijpg.com/en')), '/kesfet');
      expect(baslangicRotasi(Uri.parse('https://dizijpg.com/en/')), '/kesfet');
    });

    test('SORGU DİZESİ KORUNUR (süzgeç sayfanın parçası)', () {
      expect(baslangicRotasi(Uri.parse('https://dizijpg.com/es/icerik/tv/1396?tur=tv')),
          '/icerik/tv/1396?tur=tv');
    });

    test('öneksiz adresler DEĞİŞMEDİ (gerileme kilidi)', () {
      expect(baslangicRotasi(Uri.parse('https://dizijpg.com/icerik/movie/559')),
          '/icerik/movie/559');
      expect(baslangicRotasi(Uri.parse('https://dizijpg.com/kesfet')), '/kesfet');
      expect(baslangicRotasi(Uri.parse('https://dizijpg.com/')), '/kesfet');
      // Desteklenmeyen ön ek ATILMAZ: rota olarak denenir, olmayan rota
      // "Bağlantı geçersiz" verir — uydurma bir sayfaya YÖNLENDİRMEYİZ.
      expect(baslangicRotasi(Uri.parse('https://dizijpg.com/zz/kisi/1')), '/zz/kisi/1');
    });
  });

  group('Ceviri.yukle sırası: seçim > adres > cihaz', () {
    test('adresteki dil cihaz dilinin ÖNÜNE geçer', () async {
      Ceviri.cihazDilleri = () => const [Locale('fr')];
      await Ceviri.yukle(adres: Uri.parse('https://dizijpg.com/de/icerik/movie/1'));
      expect(Ceviri.dil.value, 'de');
    });

    test('KULLANICININ SEÇİMİ adresi EZER (seçim açık iradedir)', () async {
      SharedPreferences.setMockInitialValues({'dil': 'tr'});
      await Ceviri.yukle(adres: Uri.parse('https://dizijpg.com/de/icerik/movie/1'));
      expect(Ceviri.dil.value, 'tr');
    });

    test('adres yoksa cihaz dili okunur (eski davranış korunuyor)', () async {
      Ceviri.cihazDilleri = () => const [Locale('fr')];
      await Ceviri.yukle(adres: Uri.parse('https://dizijpg.com/icerik/movie/1'));
      expect(Ceviri.dil.value, 'fr');
    });
  });
}
