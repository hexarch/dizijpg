// Çeviri cinsiyet kilidi — 45 dilin bildirim/etkileşim metinleri.
//
// KULLANICI KARARI (13 Ağu 2026): "kimseye cinsiyete göre hitap etmeyelim."
// Uygulama kullanıcıların cinsiyetini HİÇ SORMUYOR ve SAKLAMIYOR; buna rağmen
// bazı diller kullanıcıya atıfla ERİL çekim varsayıyordu. Örnekler (düzeltildi):
//   ru '@{} подписался на тебя'      -> 'Новый подписчик: @{}'
//   pl '@{} zaczął cię obserwować'   -> '@{} obserwuje cię teraz'
//   he '@{} עוקב אחריך'              -> 'מעקב חדש: @{}'
//   sr 'Одгледао/ла си'              -> 'Одгледано'
//
// AYRIM — bu kilidin BİLEREK dokunmadığı şey: dilbilgisel cinsiyeti NESNEDEN
// gelen çekimler. '{} {} yayınlandı' çevirisinde ru `вышел` (özne "эпизод",
// eril ad) ve ar `متاحة` (özne "حلقة", dişil ad) DOĞRUDUR. Bu yüzden tarama
// tüm haritada değil, YALNIZ kişiye atıf yapan anahtarlarda çalışır.
import 'package:dizijpg/diller/diller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kişiye (aktör @{} ya da alıcı "sen") atıf yapan anahtarlar.
const _kisiAnahtarlari = [
  '@{} seni takip etti',
  '@{} yorumunu beğendi',
  '@{} yorumuna yanıt verdi',
  '@{} sana mesaj gönderdi',
  '@{} bir yorumda seni etiketledi',
  '@{} kullanıcısına yanıt veriyorsun',
  'Kimseyi takip etmiyor',
  'yazıyor...',
  'son görülme {} dk önce',
  'son görülme {} saat önce',
  'son görülme {} gün önce',
  'Nereden izledin?',
  'Şifreni mi unuttun?',
  'İzlemeyi Bıraktım',
  'İzledin',
  '10 Dizi Bitirdin',
  '25 Dizi Bitirdin',
  '50 Dizi Bitirdin',
  'Profilinde izlediğin dizi ve filmler görünmez',
  'Profilinde gizlediğin yorumları tekrar göster',
  'Bu kullanıcı yorumlarını gizli tutmayı tercih ediyor.',
];

/// Kelime sonu: Dart'ta `\b` ASCII'ye göre çalışır, Kiril/Latin-genişletilmiş
/// harflerde YANLIŞ sonuç verir (ör. `ł\b` "pozostały" içinde de eşleşirdi).
/// O yüzden kelime sonunu boşluk/noktalama/dize sonu olarak açıkça yazıyoruz.
const _son = r'(?=[\s.,!?:;…»)]|$)';

/// Dile göre "kişiye göre çekimlenmiş eril biçim" kalıpları. Hepsi bu turda
/// gerçekten dosyalarda bulunmuş ve düzeltilmiş biçimlerdir.
final _erilKaliplar = <String, List<RegExp>>{
  // Slav dilleri: eril tekil geçmiş zaman.
  'ru': [RegExp('[а-яё]+л(ся)?$_son', caseSensitive: false)],
  'uk': [
    RegExp('(підписався|вподобав|відповів|надіслав|згадав|дивився|забув)$_son'),
  ],
  'pl': [
    RegExp('[a-ząćęłńóśźż]*[aeiouyąę]ł(em|eś)?$_son', caseSensitive: false),
  ],
  'cs': [
    RegExp('(začal|odpověděl|poslal|označil|sledoval|zapomněl|přestal)$_son'),
  ],
  'sr': [
    RegExp('(одговорио|послао|означио|гледао|Заборавио|Престао|/ла)$_son'),
  ],
  'bg': [RegExp('(видян|скрил|дошъл)$_son')],
  // Sami diller: eril fiil çekimi / eril iyelik eki.
  'he': [
    RegExp(r'(עוקב אחריך|אהב את|הגיב ל|שלח לך|תייג אותך|מקליד|נראה לפני|אתה)'),
  ],
  'ar': [
    RegExp(
      r'(^|\s)(تابعك|أعجب ب|ردّ? على|أرسل لك|أشار إلي|يكتب\.'
      r'|لا يتابع|قوائمه|شاهدها|يفضّل)',
    ),
  ],
  // Amharca: eril 3./2. tekil çekim ekleri (-ህ / -ከ / -ም eril tekil).
  'am': [RegExp(r'(ተከተለህ|ወደደ|መለሰ|ላከልህ|ሰይሞሃል|አይከተልም|እየጻፈ|አይተሃል|ጨርሰሃል|ረሳህ)')],
  // Hint-Ari dilleri: eril saygı-çoğul yardımcı fiiller.
  'hi': [RegExp(r'(रहे हो|रहे हैं|नहीं करते|करता है|भूल गए)')],
  'ur': [RegExp(r'(رہے ہیں|نہیں کرتے|کرتا ہے|بھول گئے)')],
  'pa': [RegExp(r'(ਰਹੇ ਹੋ|ਰਹੇ ਹਨ|ਨਹੀਂ ਕਰਦੇ|ਕਰਦਾ ਹੈ|ਭੁੱਲ ਗਏ)')],
  'mr': [RegExp(r'(विसरलास|करतो\b|करतोस)')],
  // Romen/Cermen dilleri: geçmiş nesne zamiriyle uyum, eril iyelik.
  'fr': [RegExp(r"t['’]a\s+(suivi|appelé|mentionné|identifié)")],
  'it': [RegExp(r'\bti ha (taggato|chiamato|menzionato|seguito)\b')],
  'de': [RegExp(r'\bseine Kommentare\b')],
  'nl': [RegExp(r'\bzijn reacties\b')],
  // Yunanca: kişiye ilişen eril tanımlık.
  'el': [RegExp(r'(^Ο @|^Ο/Η @|^Στον @|λίστες του|σχόλιά του ιδ)')],
};

/// BİLEREK DOKUNULMAYANLAR: çekim kişiye değil, cümledeki ADA göredir.
/// ru "@{} понравился твой комментарий" — `понравился` ERİL çünkü ÖZNESİ
/// "комментарий" (eril ad); "@{}" burada mantıksal olarak yönelme hâlindedir.
/// Kadın bir aktör için de DOĞRUDUR, düzeltilmemelidir.
const _nesneCinsiyeti = {'ru|@{} yorumunu beğendi'};

void main() {
  test('45 dilin kişiye atıflı metinlerinde eril çekim kalmadı', () {
    final hatalar = <String>[];
    for (final girdi in _erilKaliplar.entries) {
      final harita = tumCeviriler[girdi.key];
      expect(harita, isNotNull, reason: '${girdi.key} dili kayboldu');
      for (final anahtar in _kisiAnahtarlari) {
        if (_nesneCinsiyeti.contains('${girdi.key}|$anahtar')) continue;
        final deger = harita![anahtar];
        expect(
          deger,
          isNotNull,
          reason: '${girdi.key} · "$anahtar" çevirisi yok',
        );
        for (final kalip in girdi.value) {
          if (kalip.hasMatch(deger!)) {
            hatalar.add('${girdi.key} · "$anahtar" -> "$deger"');
          }
        }
      }
    }
    expect(
      hatalar,
      isEmpty,
      reason:
          'Kişiye göre çekimlenmiş eril biçim geri gelmiş:\n'
          '${hatalar.join('\n')}\n'
          'Çözüm: çekimden kaçan isim öbeği / edilgen yapı kur.',
    );
  });

  test(
    'kişiye atıflı metinlerde parantezli veya eğik çizgili çift biçim yok',
    () {
      // 'подписался(ась)' ve 'Одгледао/ла' gibi kalıplar hem çirkindir hem de
      // ekran okuyucuda kötü okunur — çözüm çift biçim değil, çekimden kaçmaktır.
      final cift = RegExp(r'\w\([^)]{1,4}\)|[^\s/]{2}/[^\s/]{1,3}\b');
      final hatalar = <String>[];
      for (final dil in tumCeviriler.keys) {
        for (final anahtar in _kisiAnahtarlari) {
          final deger = tumCeviriler[dil]![anahtar];
          if (deger != null && cift.hasMatch(deger)) {
            hatalar.add('$dil · "$anahtar" -> "$deger"');
          }
        }
      }
      expect(
        hatalar,
        isEmpty,
        reason: 'Çift cinsiyet biçimi:\n${hatalar.join('\n')}',
      );
    },
  );

  test('yeniden yazılan metinlerde yer tutucular korundu', () {
    final yerTutucu = RegExp(r'\{\}');
    for (final dil in tumCeviriler.keys) {
      for (final anahtar in _kisiAnahtarlari) {
        final deger = tumCeviriler[dil]![anahtar];
        expect(deger, isNotNull, reason: '$dil · "$anahtar" yok');
        expect(
          yerTutucu.allMatches(deger!).length,
          yerTutucu.allMatches(anahtar).length,
          reason: '$dil · "$anahtar" -> "$deger" yer tutucu sayısı değişmiş',
        );
      }
    }
  });

  test('nesne kaynaklı çekim KORUNUYOR — kullanıcı cinsiyeti değildir', () {
    // '{} {} yayınlandı': ru öznesi "эпизод" (eril), ar öznesi "حلقة" (dişil).
    // Biri bunu "eril varsayım" sanıp düzeltmeye kalkarsa burası patlar.
    expect(tumCeviriler['ru']!['{} {} yayınlandı'], contains('вышел'));
    expect(tumCeviriler['ar']!['{} {} yayınlandı'], contains('متاحة'));
  });
}
