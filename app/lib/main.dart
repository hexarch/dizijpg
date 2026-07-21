import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'ceviri.dart';
import 'tema.dart';
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
  // Web'de #'sız temiz URL; F5 aynı sayfayı açar (nginx try_files ile).
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  await Ceviri.yukle();
  final oturum = Oturum();
  await oturum.yukle();
  runApp(
    ChangeNotifierProvider.value(value: oturum, child: const DiziJpgApp()),
  );
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
      builder: (context, dil, _) => MaterialApp.router(
        title: 'dizi.jpg',
        debugShowCheckedModeBanner: false,
        scrollBehavior: FareKaydirma(),
        theme: diziTema(),
        locale: Locale(dil),
        supportedLocales: Ceviri.desteklenenLocaleler,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: _yonlendirici,
      ),
    );
  }
}
