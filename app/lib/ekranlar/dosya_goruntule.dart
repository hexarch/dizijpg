import 'dart:io';

import 'package:flutter/material.dart';

import '../ceviri.dart';
import '../tema.dart';

/// İNDİRİLEN BELGE GÖRÜNTÜLEYİCİLERİ (16 Eyl 2026) — sohbetteki belge
/// indirildikten sonra "formatı destekliyorsak bizde aç" yolu: görsel ve
/// düz metin için tam ekran, yakınlaştırılabilir / kaydırılabilir sayfa.
/// Diğer biçimler sistem uygulamasına gider (dosya_indirici_io.dart).

/// Yerel görsel: siyah zemin, çimdikle yakınlaştır, dokununca kapanmaz
/// (yanlışlıkla kapanma); geri/kapat düğmesiyle çıkılır.
Future<void> yerelGorselGoster(BuildContext context, String yol, String ad) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(ad, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        body: Center(
          child: InteractiveViewer(
            maxScale: 6,
            child: Image.file(
              File(yol),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Text(
                'Dosya açılamadı'.c,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Düz metin (txt/md/srt/json/csv…): tek parça, seçilebilir metin. 2 MB'tan
/// büyük dosyada yalnız baş kısmı okunur, altına kırpıldığı yazılır.
Future<void> yerelMetinGoster(BuildContext context, String yol, String ad) {
  const azami = 2 * 1024 * 1024;
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: Text(ad, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        body: FutureBuilder<({String metin, bool kirpildi})>(
          future: () async {
            final f = File(yol);
            final boy = await f.length();
            if (boy <= azami) {
              return (metin: await f.readAsString(), kirpildi: false);
            }
            final bayt = await f
                .openRead(0, azami)
                .fold<List<int>>(<int>[], (a, b) => a..addAll(b));
            return (metin: String.fromCharCodes(bayt), kirpildi: true);
          }(),
          builder: (context, s) {
            if (s.hasError) {
              return Center(child: Text('Dosya açılamadı'.c));
            }
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    s.data!.metin,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.4,
                      color: DiziRenkler.metin,
                    ),
                  ),
                  if (s.data!.kirpildi)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Dosyanın yalnız başı gösteriliyor'.c,
                        style: TextStyle(color: DiziRenkler.metin54),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}
