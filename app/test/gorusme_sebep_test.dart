// `POST /arama/bitir`in `sebep` alanı — SAF KARAR TESTLERİ.
//
// NEDEN AYRI BİR DOSYA: sözleşme §13.1 bu alanı "sunucunun göremediği tek
// gerçek" olarak tanımlıyor. Sunucu `baglaniyor → cevaplandi` geçişini ASLA
// göremez (bağlantı kurulunca yoklama tamamen durur), bu yüzden veritabanına
// `basarisiz` mı `cevaplandi` mı yazılacağına yalnızca istemcinin gönderdiği
// `sebep` karar verir. Yanlış giderse HİÇBİR HATA MESAJI ÇIKMAZ — yalnız röle
// oranı ölçümü sessizce bozulur ve görüntülü aramanın maliyet kararı yanlış
// veriye dayanır.
//
// Uçtan uca (gerçekten HTTP gövdesine yazıldığı) kanıtı
// `gorusme_akis_test.dart`ta.
import 'package:dizijpg/gorusme/arama_servisi.dart';
import 'package:dizijpg/gorusme/gorusme_api.dart';
import 'package:dizijpg/gorusme/gorusme_denetci.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bitirSebebi', () {
    test('KABUL EDİLDİ ama medya HİÇ akmadı → ice_basarisiz', () {
      expect(
        bitirSebebi(
          durum: GorusmeDurum.baglaniyor,
          hicBaglandi: false,
          iceKoptu: false,
          calmaZamanAsimi: false,
        ),
        AramaSebep.iceBasarisiz,
      );
    });

    test('ICE başarısız bayrağı geldiyse de ice_basarisiz', () {
      expect(
        bitirSebebi(
          durum: GorusmeDurum.baglaniyor,
          hicBaglandi: false,
          iceKoptu: true,
          calmaZamanAsimi: false,
        ),
        AramaSebep.iceBasarisiz,
      );
    });

    test('bağlandı, sonra kullanıcı kapattı → kullanici', () {
      expect(
        bitirSebebi(
          durum: GorusmeDurum.konusuyor,
          hicBaglandi: true,
          iceKoptu: false,
          calmaZamanAsimi: false,
        ),
        AramaSebep.kullanici,
      );
    });

    test('bağlandı, sonra ağ koptu → ag_koptu (ice_basarisiz DEĞİL)', () {
      expect(
        bitirSebebi(
          durum: GorusmeDurum.konusuyor,
          hicBaglandi: true,
          iceKoptu: true,
          calmaZamanAsimi: false,
        ),
        AramaSebep.agKoptu,
      );
    });

    test('çalarken arayan kapattı → kullanici (sunucu `iptal` yazar)', () {
      expect(
        bitirSebebi(
          durum: GorusmeDurum.caliyor,
          hicBaglandi: false,
          iceKoptu: false,
          calmaZamanAsimi: false,
        ),
        AramaSebep.kullanici,
      );
    });

    test('45 sn doldu → zaman_asimi, her durumda', () {
      for (final d in GorusmeDurum.values) {
        expect(
          bitirSebebi(
            durum: d,
            hicBaglandi: false,
            iceKoptu: true,
            calmaZamanAsimi: true,
          ),
          AramaSebep.zamanAsimi,
          reason: '$d',
        );
      }
    });

    test('hazırlanırken iptal → kullanici', () {
      expect(
        bitirSebebi(
          durum: GorusmeDurum.hazirlaniyor,
          hicBaglandi: false,
          iceKoptu: false,
          calmaZamanAsimi: false,
        ),
        AramaSebep.kullanici,
      );
    });

    test('üretilen her sebep sunucunun enum listesinde', () {
      const gecerli = {
        AramaSebep.kullanici,
        AramaSebep.agKoptu,
        AramaSebep.iceBasarisiz,
        AramaSebep.zamanAsimi,
      };
      for (final d in GorusmeDurum.values) {
        for (final b in [true, false]) {
          for (final k in [true, false]) {
            for (final z in [true, false]) {
              expect(
                gecerli.contains(
                  bitirSebebi(
                    durum: d,
                    hicBaglandi: b,
                    iceKoptu: k,
                    calmaZamanAsimi: z,
                  ),
                ),
                isTrue,
              );
            }
          }
        }
      }
    });
  });

  group('reddedildiMi (404 ARAMA_YOK yorumu)', () {
    final erme = DateTime(2026, 8, 9, 12, 0, 45);

    test('sona ermeden önce silindiyse REDDEDİLDİ', () {
      expect(
        reddedildiMi(sonaErme: erme, simdi: DateTime(2026, 8, 9, 12, 0, 20)),
        isTrue,
      );
    });

    test('sona erme geçtiyse CEVAP YOK', () {
      expect(
        reddedildiMi(sonaErme: erme, simdi: DateTime(2026, 8, 9, 12, 0, 46)),
        isFalse,
      );
    });

    test('sona ermeye 2 sn kala süpürücü payı: cevap yok sayılır', () {
      expect(
        reddedildiMi(sonaErme: erme, simdi: DateTime(2026, 8, 9, 12, 0, 44)),
        isFalse,
      );
    });
  });

  group('BuzAyari.tazelenmeli (TURN kimliği bayatlamasın)', () {
    BuzAyari ayar(int gecerlilik, DateTime alindi) => BuzAyari(
      sunucular: const [],
      gecerlilikSn: gecerlilik,
      aramaAcik: true,
      goruntuluAcik: true,
      calmaSaniye: 45,
      alindi: alindi,
    );

    test('12 saatlik kimlik taze alındığında tazelenmez', () {
      final a = ayar(43200, DateTime(2026, 8, 9, 10));
      expect(a.tazelenmeli(DateTime(2026, 8, 9, 12)), isFalse);
    });

    test('kalan 1 saatin altına inince tazelenir', () {
      final a = ayar(43200, DateTime(2026, 8, 9, 10));
      // 11 sa 15 dk geçti → kalan 45 dk
      expect(a.tazelenmeli(DateTime(2026, 8, 9, 21, 15)), isTrue);
    });

    test('süresi tamamen dolmuşsa tazelenir', () {
      final a = ayar(43200, DateTime(2026, 8, 8));
      expect(a.tazelenmeli(DateTime(2026, 8, 9, 12)), isTrue);
    });

    test('TURN_SIR yoksa yalnız STUN gelir; arama yine açık sayılır', () {
      final a = BuzAyari.json({
        'buz_sunuculari': [
          {'urls': 'stun:turn.dizijpg.com:3478'},
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
        'gecerlilik_sn': 43200,
        'arama_acik': true,
        'goruntulu_acik': false,
        'calma_saniye': 45,
      });
      expect(a.sunucular.length, 2);
      expect(a.sunucular.first.containsKey('credential'), isFalse);
      expect(a.aramaAcik, isTrue);
      expect(a.goruntuluAcik, isFalse);
    });
  });

  group('geriTakipEdiyorMu (karşılıklı takip, LIMIT 500 tuzağı)', () {
    test('listede varsam beni takip ediyor', () {
      expect(
        AramaServisi.geriTakipEdiyorMu([
          {'kullanici_adi': 'ali'},
          {'kullanici_adi': 'ben'},
        ], 'ben'),
        isTrue,
      );
    });

    test('kısa listede yoksam takip ETMİYOR', () {
      expect(
        AramaServisi.geriTakipEdiyorMu([
          {'kullanici_adi': 'ali'},
        ], 'ben'),
        isFalse,
      );
    });

    test('liste 500 sınırına dayandıysa BİLİNMİYOR → düğme gösterilir', () {
      // Sunucu `LIMIT 500` uyguluyor; kesilmiş listede bulunamamak
      // "takip etmiyor" demek DEĞİLDİR. Kararı sunucuya bırakıyoruz.
      final liste = [
        for (var i = 0; i < AramaServisi.takipListesiSiniri; i++)
          {'kullanici_adi': 'k$i'},
      ];
      expect(AramaServisi.geriTakipEdiyorMu(liste, 'ben'), isTrue);
    });

    test('499 kişilik liste kesilmemiştir → yoksam takip etmiyor', () {
      final liste = [
        for (var i = 0; i < AramaServisi.takipListesiSiniri - 1; i++)
          {'kullanici_adi': 'k$i'},
      ];
      expect(AramaServisi.geriTakipEdiyorMu(liste, 'ben'), isFalse);
    });
  });
}
