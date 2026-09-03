import 'package:flutter/material.dart';

/// Ne web ne de dart:io (ör. bazı test/wasm hedefleri): platform görünümü
/// yok. Android/iOS `fragman_gom_io.dart` ile oynatıcı yüzeyini kurar.
class FragmanGomucu extends StatelessWidget {
  final String youtubeId;
  final bool aktif;
  final double altBosluk;
  final Duration baslangic;
  final bool tamEkran;
  final String? baslik;
  final String? kapakUrl;
  final String? kapakYedekUrl;

  const FragmanGomucu({
    super.key,
    required this.youtubeId,
    this.aktif = true,
    this.altBosluk = 8,
    this.baslangic = Duration.zero,
    this.tamEkran = false,
    this.baslik,
    this.kapakUrl,
    this.kapakYedekUrl,
  });

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Colors.black);
  }
}
