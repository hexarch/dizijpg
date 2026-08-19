// CSP — index.html'deki SATIR İÇİ BETİĞİN HASH BEKÇİSİ (19 Ağu 2026)
//
// NEDEN VAR
// nginx'teki CSP `script-src`'ı satır içi betiğe `'sha256-...'` ile izin
// veriyor. `'unsafe-inline'` KULLANILMADI — o, CSP'nin bütün XSS korumasını
// iptal ederdi; hash yalnız BU betiğe izin verir.
//
// Hash betiğin TAM METNİ üzerinden hesaplanır: tek bir boşluk değişse bile
// tarayıcı betiği ENGELLER. `web/index.html`i düzenleyen biri nginx'i
// güncellemeyi unutursa açılış katmanı kalkmaz ve viewport onarımı çalışmaz —
// üstelik bu, dağıtımdan SONRA ve yalnız GERÇEK tarayıcıda ortaya çıkar,
// hiçbir Dart testi yakalamaz. Bu test o boşluğu kapatıyor: betik değişirse
// BURADA kırmızıya döner ve ne yapılacağını söyler.
//
// NEDEN BETİK AYRI DOSYAYA TAŞINMADI: index.html'deki kendi yorumu bunu
// bilerek reddediyor ("ayrı dosya = fazladan istek, ki bu betiğin varlık
// sebebi tam da onu önlemek... ileride CSP açılırsa yalnız hash/nonce eklemek
// yeter"). Yol zaten bırakılmıştı, o yol kullanıldı.
//
// HASH DEĞİŞTİĞİNDE NE YAPILIR
//   1) Bu testin verdiği yeni `sha256-...` değerini al.
//   2) Sunucuda nginx CSP'sindeki eski `'sha256-...'` ile değiştir
//      (/etc/nginx/sites-available/dizijpg.com — 10 blokta geçiyor).
//   3) `nginx -t && systemctl reload nginx`.
//   4) Aşağıdaki [beklenenHash] sabitini güncelle.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// nginx CSP'sinde `script-src` içinde duran değer.
const String beklenenHash =
    'sha256-RJ/D5BTfkRmRMxMKCW/0OVhx1yUCR3lJaAw9RjfZi+E=';

/// `index.html` içindeki `src` TAŞIMAYAN tek `<script>` bloğunun gövdesi.
String _satirIciBetik(String html) {
  final desen = RegExp(r'<script(?![^>]*\ssrc=)[^>]*>([\s\S]*?)</script>');
  final eslesmeler = desen.allMatches(html).toList();
  expect(
    eslesmeler.length,
    1,
    reason:
        'index.html içinde ${eslesmeler.length} satır içi <script> var. '
        'CSP her biri için AYRI hash ister; yenisini eklediyseniz nginx '
        'politikasına da hash ekleyin.',
  );
  return eslesmeler.first.group(1)!;
}

String _hash(String metin) =>
    'sha256-${base64.encode(sha256.convert(utf8.encode(metin)).bytes)}';

void main() {
  test('satır içi betiğin hash`i nginx CSP`sindekiyle AYNI', () {
    final html = File('web/index.html').readAsStringSync();
    final gercek = _hash(_satirIciBetik(html));
    expect(
      gercek,
      beklenenHash,
      reason:
          'index.html satır içi betiği DEĞİŞTİ. CSP zorunlu modda olduğu için '
          'tarayıcı bu betiği ENGELLER: açılış katmanı kalkmaz, viewport '
          'onarımı çalışmaz.\n'
          'YAPILACAK: nginx CSP script-src`ındaki hash`i ve bu dosyadaki '
          'beklenenHash sabitini şu değerle güncelleyin:\n  $gercek',
    );
  });

  test('betik `eval` ya da satır içi olay özniteliği KULLANMIYOR', () {
    // Hash `'unsafe-eval'` gereksinimini KALDIRMAZ: betik eval/new Function
    // kullansaydı politikaya ayrıca izin eklemek gerekirdi ve o izin BÜTÜN
    // betikleri kapsardı — hash`in sağladığı daraltma boşa giderdi.
    final betik = _satirIciBetik(File('web/index.html').readAsStringSync());
    expect(betik.contains('eval('), isFalse, reason: 'betik eval kullanıyor');
    expect(
      betik.contains('new Function('),
      isFalse,
      reason: 'betik new Function kullanıyor',
    );
  });

  test('derleme çıktısı kaynakla AYNI betiği taşır', () {
    // Flutter `web/index.html`i kopyalarken yalnız `\$FLUTTER_BASE_HREF`i
    // değiştiriyor; o da betiğin DIŞINDA. Bir gün şablon işleme değişir de
    // betiğe dokunursa hash sessizce tutmaz — bu test onu yakalar.
    final derleme = File('build/web/index.html');
    if (!derleme.existsSync()) {
      markTestSkipped('build/web yok — `flutter build web` sonrası anlamlı');
      return;
    }
    expect(
      _satirIciBetik(derleme.readAsStringSync()),
      _satirIciBetik(File('web/index.html').readAsStringSync()),
      reason: 'derleme çıktısındaki satır içi betik kaynaktakinden FARKLI',
    );
  });
}
