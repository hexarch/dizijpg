import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Gövdeyi POST ederken KAÇ BAYTININ GİTTİĞİNİ söyleyen yükleme.
///
/// NEDEN AYRI BİR HAT (13 Eyl 2026, kullanıcı bildirimi: "videonun gönderim
/// yüzdesini hiç göremiyorum, hep dönüyor"): `http`nin kısa yolu
/// (`Client.post(body: …)`) gövdeyi TEK parça olarak verir — istemci "ne kadarı
/// gitti" diye sorulabilecek hiçbir kanca sunmaz. Dolayısıyla sohbetteki
/// yükleme halkası **belirsiz** (dönen) hâlde kalıyordu: 12 MB'lık video
/// dakikalarca aynı spinner'la bekliyor, kullanıcı takıldı mı ilerliyor mu
/// bilmiyordu (ui-ux-pro-max, Feedback/Progress Indicators: 1 sn'den uzun
/// süren iş BELİRLİ ilerleme ister).
///
/// ÇÖZÜM: gövdeyi kendimiz [_parcaBayt]'lık dilimler hâlinde akıtıyoruz.
/// `IOClient` bu akışı sokete `addStream` ile yazar ve akışı ancak soket
/// kabul ettikçe çeker (akış denetimi), yani "yazılan bayt" ≈ "giden bayt".
/// Sapma yalnız çekirdek soket tamponu kadardır (birkaç yüz KB) — 5-100 MB'lık
/// bir yüklemede yüzde göstergesini yanıltmaz.
///
/// [istemci] DIŞARIDAN verilir: testler `Api.istemci`yi sahte istemciyle
/// değiştiriyor, bu hat onu atlarsa testler ağa çıkmaya çalışırdı.
Future<http.Response> ilerlemeliGonder({
  required http.Client istemci,
  required Uri adres,
  required Uint8List veri,
  required Map<String, String> basliklar,
  required void Function(double oran) ilerleme,
}) async {
  final istek = _ParcaliIstek(adres, veri, ilerleme)..headers.addAll(basliklar);
  return http.Response.fromStream(await istemci.send(istek));
}

/// 64 KB: telefon soket tamponuyla aynı mertebede. Daha küçüğü (8 KB) yüzde
/// başına onlarca gereksiz `setState` demek, daha büyüğü (1 MB) 10 MB'lık
/// videoda 10 basamaklı zıplayan bir yüzde demek.
const _parcaBayt = 64 * 1024;

class _ParcaliIstek extends http.BaseRequest {
  final Uint8List _veri;
  final void Function(double oran) _ilerleme;

  _ParcaliIstek(Uri url, this._veri, this._ilerleme) : super('POST', url) {
    contentLength = _veri.length;
  }

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(_akis());
  }

  Stream<List<int>> _akis() async* {
    if (_veri.isEmpty) {
      _ilerleme(1);
      return;
    }
    var gonderilen = 0;
    while (gonderilen < _veri.length) {
      final son = math.min(gonderilen + _parcaBayt, _veri.length);
      yield Uint8List.sublistView(_veri, gonderilen, son);
      gonderilen = son;
      // `yield` GERİ DÖNDÜĞÜNDE tüketici (soket) önceki dilimi almıştır:
      // bildirilen oran gerçekten yazılmış baytı gösterir.
      _ilerleme(gonderilen / _veri.length);
    }
  }
}
