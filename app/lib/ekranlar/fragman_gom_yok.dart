import 'package:flutter/material.dart';

/// Ne web ne de dart:io (ör. bazı test/wasm hedefleri): platform görünümü
/// yok. Android/iOS `fragman_gom_io.dart` ile oynatıcı yüzeyini kurar.
class FragmanGomucu extends StatelessWidget {
  final String youtubeId;
  final bool aktif;
  final double altBosluk;

  const FragmanGomucu({
    super.key,
    required this.youtubeId,
    this.aktif = true,
    this.altBosluk = 8,
  });

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Colors.black);
  }
}
