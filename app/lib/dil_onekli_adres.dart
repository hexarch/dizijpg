import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'ceviri.dart';
import 'yonlendirme.dart' show dilOnekiDusur;

/// WEB'DE DİL ÖNEKİ ADRES ÇUBUĞUNDA KALIR  (5 Eyl 2026, kullanıcı kararı)
///
/// Almanca arayüzde Keşfet `/de`, dizi sayfası `/de/icerik/tv/2098`,
/// ayarlar `/de/ayarlar` olarak görünür. Türkçe kökte yaşar (`/kesfet`,
/// `/icerik/tv/2098`); `/tr/...` diye bir adres YOK.
///
/// NEDEN: sunucu arama motorlarına dil önekli kanonik adres veriyor ve
/// hreflang halkası o adresler arasında kurulu. İnsan aynı sayfayı `/kesfet`
/// adresinde görürse bot ile insanın adresi ayrışır: paylaşılan bağlantı dili
/// taşımaz, dış bağlantılar Türkçe adrese yazılır, Chrome kullanıcı deneyimi
/// verisi ve GSC raporu yanlış sayfada toplanır. Aynı adreste aynı sayfa
/// ilkesi.
///
/// NASIL: go_router'ın ayrıştırıcısı iki yönde sarılır.
///  · GELEN (tarayıcı adresi, `go()` konumu): önek DÜŞER, rota ağacı öneksiz
///    kalır — 45 dil için rota kopyalamak yok. `/de` → `/kesfet`.
///  · GİDEN (adres çubuğuna yazılacak konum): uygulama dili `tr` değilse önek
///    EKLENİR. `/kesfet` → `/de` (kanonik ana sayfa `/de/kesfet` değil `/de`;
///    sunucu `/de/kesfet`e 404+noindex döner).
/// Rota ağacı, `context.go/push` çağrıları ve `currentConfiguration` öneksiz
/// kalır; önek yalnız adres çubuğunda yaşar. `sohbet_olay`, `push`, `kabuk`
/// gibi `currentConfiguration.uri.path` okuyan yerler bu yüzden değişmedi.
///
/// YALNIZ WEB: mobilde adres çubuğu yok; [web] false iken giden yön dokunmaz.
/// Gelen yön her platformda çalışır (derin bağlantı `/de/icerik/...` gelirse
/// mobilde de doğru rotaya açılmalı).
///
/// DİL KAYNAĞI: [dil] varsayılan `Ceviri.dil.value`. Sıra kutsal (kullanıcı
/// seçimi > adres > cihaz): Türkçe seçmiş kullanıcı `/de/icerik/tv/1`
/// bağlantısını açarsa sayfa Türkçe çizilir ve adres `/icerik/tv/1` olur —
/// gördüğü sayfa ile adres yine tutarlı.
class DilOnekliRotaAyristirici extends RouteInformationParser<RouteMatchList> {
  DilOnekliRotaAyristirici(this.ic, {String Function()? dil, bool? web})
    : _dil = dil ?? (() => Ceviri.dil.value),
      _web = web ?? kIsWeb;

  /// go_router'ın kendi ayrıştırıcısı (`GoRouter.routeInformationParser`).
  final GoRouteInformationParser ic;
  final String Function() _dil;
  final bool _web;

  @override
  Future<RouteMatchList> parseRouteInformationWithDependencies(
    RouteInformation routeInformation,
    BuildContext context,
  ) {
    final dilsiz = dilOnekiDusur(routeInformation.uri);
    final hedef = dilsiz == null
        ? routeInformation
        : RouteInformation(
            uri: Uri.parse(dilsiz),
            state: routeInformation.state,
          );
    return ic.parseRouteInformationWithDependencies(hedef, context);
  }

  @override
  Future<RouteMatchList> parseRouteInformation(
    RouteInformation routeInformation,
  ) => ic.parseRouteInformation(routeInformation);

  @override
  RouteInformation? restoreRouteInformation(RouteMatchList configuration) {
    final r = ic.restoreRouteInformation(configuration);
    if (r == null || !_web) return r;
    final onekli = dilOnekiEkle(r.uri, _dil());
    return onekli == null ? r : RouteInformation(uri: onekli, state: r.state);
  }
}

/// Öneksiz uygulama adresine [dil] önekini ekler; eklenecek bir şey yoksa null.
///
/// `/kesfet` + de → `/de` (kanonik ana sayfa), `/icerik/tv/2098` + de →
/// `/de/icerik/tv/2098`, sorgu ve parça korunur. [dil] `tr` ya da bilinmeyen
/// bir kodsa null (Türkçe kökte yaşar). Adres zaten önekliyse null (çift
/// önek üretilmez). Göreli URI (`/kesfet?x=1`) ve mutlak URI ikisi de olur.
Uri? dilOnekiEkle(Uri adres, String dil) {
  final kod = dil.toLowerCase();
  if (kod == 'tr' || !Ceviri.diller.containsKey(kod)) return null;
  if (Ceviri.adresDiliKodu(adres) != null) return null;
  final yol = adres.path;
  final yeniYol = (yol.isEmpty || yol == '/' || yol == '/kesfet')
      ? '/$kod'
      : '/$kod$yol';
  return adres.replace(path: yeniYol);
}
