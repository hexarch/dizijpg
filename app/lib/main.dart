import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'ekranlar/giris.dart';
import 'ekranlar/kabuk.dart';
import 'tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final oturum = Oturum();
  await oturum.yukle();
  runApp(
    ChangeNotifierProvider.value(value: oturum, child: const DiziJpgApp()),
  );
}

class DiziJpgApp extends StatelessWidget {
  const DiziJpgApp({super.key});

  @override
  Widget build(BuildContext context) {
    final oturum = context.watch<Oturum>();
    return MaterialApp(
      title: 'dizi.jpg',
      debugShowCheckedModeBanner: false,
      theme: diziTema(),
      home: oturum.girisli ? const KabukEkrani() : const GirisEkrani(),
    );
  }
}
