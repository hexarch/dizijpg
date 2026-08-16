import 'package:flutter/material.dart';

/// Ne web ne de dart:io (ör. bazı test/wasm hedefleri): platform görünümü
/// yok. Android/iOS `fragman_gom_io.dart` ile WebView gömer.
class FragmanGomucu extends StatelessWidget {
  final String youtubeId;

  const FragmanGomucu({super.key, required this.youtubeId});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Colors.black);
  }
}
