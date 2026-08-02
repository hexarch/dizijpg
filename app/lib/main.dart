import 'dart:async';
import 'dart:ui' show PlatformDispatcher, PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'altyazi.dart';
import 'api.dart';
import 'ceviri.dart';
import 'push.dart';
import 'kitaplik_durumu.dart';
import 'tema.dart';
import 'veri_tasarrufu.dart';
import 'yonlendirme.dart';

/// Web'de yatay rafların fareyle sürüklenebilmesi için (varsayılanda kapalı).
class FareKaydirma extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

Future<void> main() async {
  // Yakalanan Flutter hataları önce konsola, sonra sunucuya (self-hosted günlük).
  FlutterError.onError = (ayrinti) {
    FlutterError.presentError(ayrinti);
    Api.hataBildir(ayrinti.exception, ayrinti.stack);
  };
  // Widget ağacı dışındaki (platform/async) hatalar.
  PlatformDispatcher.instance.onError = (hata, yigin) {
    Api.hataBildir(hata, yigin);
    return true;
  };
  runZonedGuarded(() async {
    // Web'de #'sız temiz URL; F5 aynı sayfayı açar (nginx try_files ile).
    usePathUrlStrategy();
    WidgetsFlutterBinding.ensureInitialized();
    await pushCekirdek(); // Firebase çekirdeği + arka plan mesaj işleyicisi
    await Ceviri.yukle();
    await TemaAyar.yukle();
    await VeriTasarrufu.yukle(); // bağlantı türü + veri tasarrufu tercihleri
    await AltyaziAyar.yukle(); // videolarda altyazı gösterilsin mi
    final oturum = Oturum();
    await oturum.yukle();
    // Girişli kullanıcıda push'u başlat (izin + token kaydı)
    if (oturum.girisli) pushBaslat();
    if (oturum.girisli) KitaplikDurumu.yukle();
    runApp(
      ChangeNotifierProvider.value(value: oturum, child: const DiziJpgApp()),
    );
  }, (hata, yigin) => Api.hataBildir(hata, yigin));
}

class DiziJpgApp extends StatefulWidget {
  const DiziJpgApp({super.key});

  @override
  State<DiziJpgApp> createState() => _DiziJpgAppState();
}

class _DiziJpgAppState extends State<DiziJpgApp> {
  late final GoRouter _yonlendirici = yonlendiriciOlustur(
    context.read<Oturum>(),
  );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: Ceviri.dil,
      // TemaKapsayici tema tercihini + cihaz parlaklığını dinler,
      // DiziRenkler.acik bayrağını tazeler ve DİL ya da TEMA değişince
      // ağacı baştan kurduran anahtarı üretir. Yeniden kurulmazsa keep-alive
      // sekmeler eski dilde, DiziRenkler okuyan her şey eski temada kalıyor
      // (bkz. tema.dart'taki açıklama + test/tema_gecisi_test.dart).
      builder: (context, dil, _) => TemaKapsayici(
        ekAnahtar: dil,
        olustur: (context, tema, anahtar) => MaterialApp.router(
          key: anahtar,
          title: 'dizi.jpg',
          debugShowCheckedModeBanner: false,
          scrollBehavior: FareKaydirma(),
          theme: tema,
          locale: Locale(dil),
          supportedLocales: Ceviri.desteklenenLocaleler,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: _yonlendirici,
        ),
      ),
    );
  }
}
