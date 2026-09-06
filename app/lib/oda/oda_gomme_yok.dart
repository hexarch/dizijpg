/// İZLEME ODASI — GÖMME YÜZEYİ (ne web ne dart:io).
///
/// `flutter test` VM'de koşar: orada ne platform görünümü ne WebView vardır.
/// Bu dosya olmasaydı widget testleri gömme kipine hiç giremezdi ve bağlantı
/// kipinin düzen kararları (video tavanı, sohbet payı) sınanamazdı.
library;

import 'package:flutter/material.dart';

import 'oda_baglanti.dart';
import 'oda_oynatici.dart';

class OdaGommeYuzeyi extends StatelessWidget {
  final OdaBaglanti baglanti;
  final OdaGommeDenetci denetci;

  const OdaGommeYuzeyi({
    super.key,
    required this.baglanti,
    required this.denetci,
  });

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.black);
}
