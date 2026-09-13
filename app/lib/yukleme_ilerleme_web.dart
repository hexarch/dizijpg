import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

/// Web'de yükleme yüzdesi — `XMLHttpRequest.upload` olayından.
///
/// NEDEN `package:http` DEĞİL: `BrowserClient` gövdeyi XHR'e verip yalnız
/// YANITI bekler; `upload.onprogress` dışarı hiç açılmaz. Yani tarayıcı
/// yüklenen baytı biliyor ama uygulama öğrenemiyordu — sohbetteki halka o
/// yüzden sonuna kadar dönüyordu (13 Eyl 2026 kullanıcı bildirimi).
/// `fetch` de ("duplex" akışları Safari/Firefox'ta yok) bu işi taşımıyor;
/// yükleme ilerlemesi bugün hâlâ yalnız XHR'de var.
///
/// [istemci] KULLANILMAZ (imza io tarafıyla aynı kalsın diye durur): XHR
/// doğrudan kurulur.
Future<http.Response> ilerlemeliGonder({
  required http.Client istemci,
  required Uri adres,
  required Uint8List veri,
  required Map<String, String> basliklar,
  required void Function(double oran) ilerleme,
}) {
  final xhr = web.XMLHttpRequest();
  final tamam = Completer<http.Response>();
  xhr.open('POST', adres.toString(), true);
  xhr.responseType = 'arraybuffer';
  // `forEach(xhr.setRequestHeader)` YAZILMAZ: dış uzantı üyesinin tear-off'u
  // dart2js'te derleme hatasıdır ("Tear-offs of external extension type interop
  // member ... are disallowed").
  for (final e in basliklar.entries) {
    xhr.setRequestHeader(e.key, e.value);
  }

  xhr.upload.addEventListener(
    'progress',
    ((web.Event o) {
      final p = o as web.ProgressEvent;
      if (!p.lengthComputable || p.total <= 0) return;
      ilerleme(math.min(1, p.loaded / p.total));
    }).toJS,
  );

  void kopti(String neden) {
    if (!tamam.isCompleted) {
      // `ClientException`: `Api._agHatasi` taşıma hatalarını bu tipten
      // tanıyor; kendi sınıfımızı atsaydık ekrana ham metin sızardı.
      tamam.completeError(http.ClientException(neden, adres));
    }
  }

  xhr.addEventListener(
    'load',
    ((web.Event _) {
      if (tamam.isCompleted) return;
      final tampon = xhr.response as JSArrayBuffer?;
      final govde = tampon == null ? Uint8List(0) : tampon.toDart.asUint8List();
      tamam.complete(
        http.Response.bytes(
          govde,
          xhr.status,
          // BAŞLIKLAR ŞART: `http.Response.body` karakter kümesini yanıtın
          // `content-type`ından okur; başlıksız yanıt latin1 sayılır ve
          // Türkçe hata metinleri ("Ã¼") bozuk çıkardı.
          headers: _yanitBasliklari(xhr),
          reasonPhrase: xhr.statusText,
        ),
      );
    }).toJS,
  );
  xhr.addEventListener(
    'error',
    ((web.Event _) => kopti('Bağlantı koptu')).toJS,
  );
  xhr.addEventListener(
    'abort',
    ((web.Event _) => kopti('Yükleme durduruldu')).toJS,
  );

  xhr.send(veri.toJS);
  return tamam.future;
}

Map<String, String> _yanitBasliklari(web.XMLHttpRequest xhr) {
  final basliklar = <String, String>{};
  for (final satir in xhr.getAllResponseHeaders().split('\r\n')) {
    final i = satir.indexOf(':');
    if (i <= 0) continue;
    basliklar[satir.substring(0, i).trim().toLowerCase()] = satir
        .substring(i + 1)
        .trim();
  }
  return basliklar;
}
