// İZLEME TARİHİ — detay sayfası satırı + bölüm satırlarında tarih.
//
// İSTEK (27 Ağu 2026): "İzlenen dizi filmlere tarihlerini de ekler misin"
// + "dizi bölümlerine de bölüm izlenme tarihini eklemeyi unutma".
//
// KARARLAR (kullanıcıyla konuşuldu):
//   * yerleşim: DETAY SAYFASINDA SATIR (listeler temiz kalsın, elle sıralama
//     bozulmasın),
//   * dizide gösterilen tarih: SON İZLENEN BÖLÜM (bitirme tarihi değil).
//
// Kilitlenen davranışlar:
//   1) `tarihBicimle` yılı yalnız GEREKTİĞİNDE yazar (bu yıl → yıl yok).
//   2) Filmde "… tarihinde izledin", dizide "Son izleme: …".
//   3) İzlenmemiş içerikte satır HİÇ çizilmez.
//   4) Bölüm satırında yayın tarihi ve izlenme tarihi AYRI AYRI görünür.
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/ekranlar/karsilama.dart' show karsilamaAylar;
import 'package:dizijpg/tarih.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tarihBicimle', () {
    test('geçmiş yılda YIL yazılır', () {
      expect(tarihBicimle('2008-01-20T00:00:00Z'), '20 Ocak 2008');
      expect(tarihBicimle('2025-12-05'), '5 Aralık 2025');
    });

    test('içinde bulunulan yılda YIL YAZILMAZ (dar satır kuralı)', () {
      final buYil = DateTime.now().year;
      expect(tarihBicimle('$buYil-08-14'), '14 Ağustos');
    });

    test('hepYil: true ile yıl DAİMA yazılır (tek satırlık özet)', () {
      final buYil = DateTime.now().year;
      expect(tarihBicimle('$buYil-08-14', hepYil: true), '14 Ağustos $buYil');
    });

    test('boş/bozuk değer sessizce kaybolmaz', () {
      // Boş → boş (satır hiç çizilmez).
      expect(tarihBicimle(null), '');
      expect(tarihBicimle(''), '');
      // Çözülemeyen → HAM DEĞER döner: ekranda görünür bir hata, sessiz
      // boşluktan iyidir.
      expect(tarihBicimle('bozuk'), 'bozuk');
      expect(tarihBicimle('2026-13-40'), '2026-13-40');
    });

    test('ay adları çeviriden gelir (intl locale verisi olmadan)', () {
      // `initializeDateFormatting` çağrılmıyor; DateFormat kullanılsaydı
      // burada fırlardı. Türkçe kaynak dilde anahtar = değer.
      for (var ay = 1; ay <= 12; ay++) {
        final s = tarihBicimle('2020-${ay.toString().padLeft(2, '0')}-01');
        expect(s.startsWith('1 '), isTrue);
        expect(s.endsWith(' 2020'), isTrue);
        expect(s.length, greaterThan('1  2020'.length));
      }
    });
  });

  group('çeviri anahtarları', () {
    test('film ve dizi metinleri AYRI anahtarlar', () {
      // Aynı anahtarı iki bağlamda kullanmak, dile göre bozuk cümle üretirdi
      // ("Son izleme" bir filmde yanlış, "izledin" bir dizide eksik).
      expect(
        '{} tarihinde izledin'.cf(['14 Ağustos 2026']),
        contains('14 Ağustos 2026'),
      );
      expect(
        'Son izleme: {}'.cf(['14 Ağustos 2026']),
        contains('14 Ağustos 2026'),
      );
      expect(
        '{} tarihinde izledin'.cf(['x']),
        isNot(equals('Son izleme: {}'.cf(['x']))),
      );
    });
  });

  group('izlemeTarihiVeyaNull — güvenilmeyen tarih EKRANA ÇIKMAZ', () {
    // 27 Ağu 2026: içe aktarım yolları `tarih`i okumadığında satır DEFAULT
    // now() ile damgalanıyordu (ölçüm: melis.izler 14.872 satır / 5 gün,
    // dizi.jpg 10.756 / 1). Sunucu artık o satırlarda `tarih: null` dönüyor.
    //
    // TUZAK: JSON'dan okunan null `(x ?? '').toString()` ile BOŞ DİZGEYE
    // dönüşüyordu ve bölüm satırındaki `izlenmeTarihi != null` kontrolünden
    // GEÇİYORDU — göz ikonunun yanına boş bir tarih basılırdı.
    test('null ve boş değerler null olur (satır çizilmez)', () {
      expect(izlemeTarihiVeyaNull(null), isNull);
      expect(izlemeTarihiVeyaNull(''), isNull);
      expect(izlemeTarihiVeyaNull('   '), isNull);
    });

    test('gerçek tarih AYNEN korunur', () {
      expect(
        izlemeTarihiVeyaNull('2019-03-04T20:00:00Z'),
        '2019-03-04T20:00:00Z',
      );
      expect(izlemeTarihiVeyaNull('2026-08-14'), '2026-08-14');
    });

    test('çıktı doğrudan tarihBicimle ile eşleşiyor (uçtan uca)', () {
      // Satırın gerçek akışı: JSON → izlemeTarihiVeyaNull → != null → biçimle.
      final t = izlemeTarihiVeyaNull('2008-01-20T00:00:00Z');
      expect(t, isNotNull);
      expect(tarihBicimle(t, hepYil: true), '20 Ocak 2008');
      // Güvenilmeyen satırda hiç biçimlemeye GİRİLMEZ.
      expect(izlemeTarihiVeyaNull(''), isNull);
    });
  });

  // =========================================================================
  // BÖLÜM LİSTESİNDE SAYISAL TARİH (28 Ağu 2026)
  // =========================================================================
  // Kullanıcı: "dizilerde sezonlardaki bölümleri listeleyince tarih yazıyor ya
  // orada ay ismi kullanma sayı kullan sadece ikisi içinde" — yani hem yayın
  // hem izlenme tarihi. Satır dar ve iki tarih yan yana duruyor.
  group('tarihSayi', () {
    test('geçmiş yılda gg.aa.yyyy', () {
      expect(tarihSayi('2008-01-20T00:00:00Z'), '20.01.2008');
      expect(tarihSayi('2025-12-05'), '05.12.2025');
    });

    test('gün ve ay İKİ HANEYE tamamlanır (hizalı sütun)', () {
      // "5.1.2025" satırda zıplardı; sabit genişlik listede sütun hissi verir.
      expect(tarihSayi('2025-01-05'), '05.01.2025');
    });

    test(
      'içinde bulunulan yılda YIL YAZILMAZ (tarihBicimle ile aynı kural)',
      () {
        final buYil = DateTime.now().year;
        expect(tarihSayi('$buYil-08-14'), '14.08');
      },
    );

    test(
      'hepYil: true ile yıl DAİMA yazılır (yayın tarihi böyle basılıyor)',
      () {
        final buYil = DateTime.now().year;
        expect(tarihSayi('$buYil-08-14', hepYil: true), '14.08.$buYil');
      },
    );

    test('AY ADI HİÇ GEÇMEZ (asıl istek)', () {
      for (final g in ['2008-01-20', '2026-08-14', '2020-12-31']) {
        final s = tarihSayi(g, hepYil: true);
        for (final ay in karsilamaAylar) {
          expect(s.contains(ay.c), isFalse, reason: '$s içinde ay adı var');
        }
      }
    });

    test('bozuk/boş değer sessizce kaybolmaz', () {
      expect(tarihSayi(null), '');
      expect(tarihSayi(''), '');
      expect(tarihSayi('yok'), 'yok');
      expect(tarihSayi('2026-13-01'), '2026-13-01');
    });

    test('tarihBicimle DEĞİŞMEDİ (öteki 15 çağrı yeri aynen ay adı yazar)', () {
      // Değişiklik YALNIZ bölüm listesi içindi; genel biçimlendirici aynı
      // kalmalı, yoksa "Son izleme", istatistikler ve karşılama da sayıya
      // döner ve kullanıcının istemediği bir gerileme olur.
      expect(tarihBicimle('2008-01-20'), '20 Ocak 2008');
    });
  });
}
