import 'package:web/web.dart' as web;

/// Aynı origin'deki medyayı tarayıcıya indirtir. Blob'a çevirmeye gerek
/// yok: medya kendi sunucumuzdan geliyor, adres doğrudan indirilebiliyor.
void webIndir(String url, String ad) {
  final a = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = ad
    ..style.display = 'none';
  web.document.body?.append(a);
  a.click();
  a.remove();
}
