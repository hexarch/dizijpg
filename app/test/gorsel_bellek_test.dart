import 'package:dizijpg/gorsel_bellek.dart';
import 'package:flutter_test/flutter_test.dart';

/// Önbellek anahtarı imza kovasından bağımsız (16 Eyl 2026): aynı dosya,
/// farklı `<son>/<imza>` → aynı anahtar; sorgu atılır; imzasız adres aynen.
void main() {
  test('imzalı yol → /medya/<dosya>', () {
    const a =
        'https://dizijpg.com/api/medya/i/tlic00/5e9dd251726c43011f1f2d2b/m184-a1.jpg';
    const b =
        'https://dizijpg.com/api/medya/i/tlj9zz/ffffffffffffffffffffffff/m184-a1.jpg';
    expect(onbellekAnahtari(a), 'https://dizijpg.com/api/medya/m184-a1.jpg');
    expect(onbellekAnahtari(a), onbellekAnahtari(b));
    expect(
      onbellekAnahtari(
        'https://dizijpg.com/api/medya/i/tlic00/abc123/m184-a1.jpg.k.jpg',
      ),
      'https://dizijpg.com/api/medya/m184-a1.jpg.k.jpg',
    );
  });
  test('sorgu atılır, imzasız adres olduğu gibi', () {
    expect(
      onbellekAnahtari('https://x/medya/m1-a.jpg?imza=1&son=2'),
      'https://x/medya/m1-a.jpg',
    );
    expect(
      onbellekAnahtari('https://image.tmdb.org/t/p/w342/a.jpg'),
      'https://image.tmdb.org/t/p/w342/a.jpg',
    );
  });
}
