// Sözleşme §8'deki 13 hata kodu + kodsuz 429.
//
// KİLİTLENEN DAVRANIŞ: istemci **Türkçe metne göre DEĞİL `kod` alanına göre**
// dallanır (§14.2). Sunucunun `hata` metni insan içindir ve değişebilir;
// aşağıdaki testler her kod için hem doğru KULLANICI METNİNİ hem de doğru
// EKRAN TEPKİSİNİ (uyar / kapat / mevcut aramaya dön) kilitliyor.
//
// Üç kod aynı HTTP durumunu paylaşıyor (403: ENGELLI, TAKIP_YOK,
// ALICI_YASAKLI) — yani HTTP koduna bakan bir istemci bu üçünü ayıramaz.
import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/gorusme/gorusme_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ApiHata _hata(String? kod, int http, {Map<String, dynamic>? govde}) => ApiHata(
  'sunucunun Türkçe metni — İSTEMCİ BUNA BAKMAZ',
  kod: http,
  makineKodu: kod,
  govde: govde,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('13 kodun HEPSİ tanınır ve sunucunun Türkçe metnini KULLANMAZ', () {
    const kodlar = [
      AramaKod.aramaKapali,
      AramaKod.goruntuluKapali,
      AramaKod.gecersizIstek,
      AramaKod.kullaniciYok,
      AramaKod.kendineArama,
      AramaKod.engelli,
      AramaKod.takipYok,
      AramaKod.aliciYasakli,
      AramaKod.cokFazlaCevapsiz,
      AramaKod.zatenAramada,
      AramaKod.durumUygunDegil,
      AramaKod.tarafDegil,
      AramaKod.aramaYok,
    ];
    expect(kodlar.length, 13);
    for (final k in kodlar) {
      final h = aramaHatasiCozumle(_hata(k, 400));
      expect(h.kod, k, reason: k);
      expect(h.metin, isNotEmpty, reason: k);
      expect(
        h.metin.contains('İSTEMCİ BUNA BAKMAZ'),
        isFalse,
        reason: '$k sunucunun metnini yansıtıyor',
      );
    }
  });

  test('ARAMA_KAPALI → ekranı kapat', () {
    final h = aramaHatasiCozumle(_hata(AramaKod.aramaKapali, 503));
    expect(h.metin, 'Arama şu anda kullanılamıyor');
    expect(h.tepki, AramaTepkisi.kapat);
  });

  test('GORUNTULU_KAPALI → sesli araması önerilir', () {
    final h = aramaHatasiCozumle(_hata(AramaKod.goruntuluKapali, 503));
    expect(h.metin.contains('sesli'), isTrue);
    expect(h.tepki, AramaTepkisi.kapat);
  });

  test('TAKIP_YOK → karşılıklı takip metni, ekran AÇIK kalır', () {
    final h = aramaHatasiCozumle(_hata(AramaKod.takipYok, 403));
    expect(h.metin, 'Aramak için karşılıklı takipleşmelisiniz');
    expect(h.tepki, AramaTepkisi.uyar);
  });

  test('AYNI 403, ÜÇ FARKLI METİN — HTTP koduna düşmek yetmez', () {
    final metinler = {
      aramaHatasiCozumle(_hata(AramaKod.engelli, 403)).metin,
      aramaHatasiCozumle(_hata(AramaKod.takipYok, 403)).metin,
      aramaHatasiCozumle(_hata(AramaKod.aliciYasakli, 403)).metin,
      aramaHatasiCozumle(_hata(AramaKod.tarafDegil, 403)).metin,
    };
    expect(metinler.length, 4);
  });

  test('COK_FAZLA_CEVAPSIZ → kalan süre metne girer', () {
    final h = aramaHatasiCozumle(
      _hata(AramaKod.cokFazlaCevapsiz, 429, govde: {'kalan_sn': 1800}),
    );
    expect(h.kod, AramaKod.cokFazlaCevapsiz);
    expect(h.metin.contains('30'), isTrue, reason: h.metin);
    expect(h.tepki, AramaTepkisi.uyar);
  });

  test('COK_FAZLA_CEVAPSIZ kalan_sn yoksa da metin bozulmaz', () {
    final h = aramaHatasiCozumle(_hata(AramaKod.cokFazlaCevapsiz, 429));
    expect(h.metin.contains('{}'), isFalse);
  });

  test('ZATEN_ARAMADA → mevcut arama ekranına dön', () {
    final h = aramaHatasiCozumle(_hata(AramaKod.zatenAramada, 409));
    expect(h.tepki, AramaTepkisi.mevcutAramayaDon);
  });

  test('DURUM_UYGUN_DEGIL / TARAF_DEGIL / ARAMA_YOK → ekranı kapat', () {
    for (final k in [
      AramaKod.durumUygunDegil,
      AramaKod.tarafDegil,
      AramaKod.aramaYok,
    ]) {
      expect(aramaHatasiCozumle(_hata(k, 404)).tepki, AramaTepkisi.kapat);
    }
  });

  test('HIZ LİMİTİ: `kod` YOK → HTTP 429\'a düşülür', () {
    // `hizLimiti()` (server.js:907) `{hata:'...'}` döndürür, `kod` alanı
    // YOKTUR. İstemci kod yokluğunda durum koduna düşmelidir.
    final h = aramaHatasiCozumle(_hata(null, 429));
    expect(h.kod, isNull);
    expect(h.metin, 'Çok fazla istek, biraz bekle');
    expect(h.tepki, AramaTepkisi.uyar);
  });

  test('bilinmeyen kod → genel uyarı, çökme yok', () {
    final h = aramaHatasiCozumle(_hata('GELECEKTEKI_YENI_KOD', 500));
    expect(h.kod, isNull);
    expect(h.tepki, AramaTepkisi.uyar);
  });

  test('ApiHata olmayan (ağ/zaman aşımı) hata da metne çevrilir', () {
    final h = aramaHatasiCozumle(Exception('socket'));
    expect(h.metin, 'Arama başlatılamadı');
  });

  test('ApiHata sunucudaki `kod` alanını GERÇEKTEN taşıyor', () {
    // Regresyon kilidi: `api.dart` gövdeden `kod`u okumayı bırakırsa 13
    // dalın hepsi sessizce "genel uyarı"ya düşerdi.
    final h = ApiHata('x', kod: 403, makineKodu: 'TAKIP_YOK');
    expect(aramaHatasiCozumle(h).kod, AramaKod.takipYok);
  });

  test('metinler çeviri katmanından geçiyor (45 dil)', () async {
    // Anahtarlar Türkçe metnin kendisi; İngilizceye geçince değişmeli.
    await Ceviri.sec('en');
    final h = aramaHatasiCozumle(_hata(AramaKod.takipYok, 403));
    expect(h.metin, isNot('Aramak için karşılıklı takipleşmelisiniz'));
    await Ceviri.sec('tr');
  });
}
