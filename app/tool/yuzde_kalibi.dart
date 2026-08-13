// Her dil için yüzde kalıbını CLDR'den (intl paketi) ÇIKARIR — tahminle değil.
// Çıktı: dil kodu → '%{}' anahtarının o dildeki değeri (rakamlar LATİN kalır).
import 'package:intl/intl.dart';

const diller = [
  'am','ar','az','bg','bn','cs','da','de','el','en','es','fa','fi','fil','fr',
  'gu','he','hi','hu','id','it','ja','kn','ko','ml','mr','ms','my','nb','nl',
  'pa','pl','pt','ro','ru','sr','sv','sw','ta','te','th','uk','ur','vi','zh',
];

void main() {
  for (final d in diller) {
    String kalip;
    try {
      // 0,42 → o dilin kendi yüzde biçimi. Sonra rakamları {} ile değiştiriyoruz.
      final s = NumberFormat.percentPattern(d).format(0.42);
      // Latin ya da yerel rakamları bul, hepsini tek {} ile değiştir.
      final r = RegExp(r'[0-9٠-٩۰-۹०-९'
          r'૦-૯୦-୯௦-௯౦-౯'
          r'೦-೯൦-൯๐-๙၀-၉]+');
      kalip = s.replaceAll(r, '{}');
    } catch (e) {
      kalip = 'HATA: $e';
    }
    print('$d\t$kalip');
  }
}
