import 'package:flutter/material.dart';

/// Web OLMAYAN derleme (Android/iOS ve `flutter test` VM): platform görünümü
/// yok. Oynatma [FragmanOynatici] içinde YouTube'a yönlendirilir; burası
/// yalnız içe aktarma simetrisi için duran bir yer tutucu.
class FragmanGomucu extends StatelessWidget {
  final String youtubeId;

  const FragmanGomucu({super.key, required this.youtubeId});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Colors.black);
  }
}
