import 'dart:async';
import 'dart:ui' show PlatformDispatcher, PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'ceviri.dart';
import 'push.dart';
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
    final oturum = Oturum();
    await oturum.yukle();
    // Girişli kullanıcıda push'u başlat (izin + token kaydı)
    if (oturum.girisli) pushBaslat();
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

class _DiziJpgAppState extends State<DiziJpgApp> with WidgetsBindingObserver {
  late final GoRouter _yonlendirici = yonlendiriciOlustur(
    context.read<Oturum>(),
  );

  @override
  void initState() {
    super.initState();
    // "Sistem" modunda cihaz teması değişince yeniden kur
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: Ceviri.dil,
      builder: (context, dil, _) => ValueListenableBuilder<String>(
        valueListenable: TemaAyar.mod,
        builder: (context, mod, _) {
          // Ekranlardaki DiziRenkler getter'ları bu bayrağı okur —
          // MaterialApp kurulmadan HEMEN önce güncellenmeli.
          final acik =
              mod == 'acik' ||
              (mod == 'sistem' &&
                  WidgetsBinding
                          .instance
                          .platformDispatcher
                          .platformBrightness ==
                      Brightness.light);
          DiziRenkler.acik = acik;
          return MaterialApp.router(
            // Dil değişince tüm ağaç taze kurulur; keep-alive sekme ekranları
            // (Keşfet/Takvim/Akış/Profil) yeni dili anında yansıtır. Yoksa
            // yalnız nav çubuğu çevriliyor, gövdeler eski dilde kalıyordu.
            key: ValueKey('uygulama-$dil'),
            title: 'dizi.jpg',
            debugShowCheckedModeBanner: false,
            scrollBehavior: FareKaydirma(),
            theme: diziTema(acik: acik),
            locale: Locale(dil),
            supportedLocales: Ceviri.desteklenenLocaleler,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: _yonlendirici,
          );
        },
      ),
    );
  }
}
