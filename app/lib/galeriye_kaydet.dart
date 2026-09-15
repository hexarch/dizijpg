import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'dosya_yaz.dart';
import 'gorsel_basliklari.dart';
import 'web_indir.dart';

/// GALERİYE KAYDET (15 Eyl 2026 isteği: "sohbette iletilen medyaları
/// galeriye kaydetme özelliği olmalı").
///
/// Mobilde `gal` ile sistem galerisine yazar; web'de tarayıcının indirme
/// akışını tetikler (tarayıcıda "galeri" yoktur, karşılığı İndirilenler).
///
/// İZİN: Android 10+ ve iOS'ta sistem "yalnız ekleme" iznini kendi sorar
/// (`Gal.requestAccess(toAlbum: true)`); reddedilirse [GaleriSonuc.izinYok]
/// döner ve çağıran yüzey kullanıcıya ayarları açmasını söyler.
enum GaleriSonuc { tamam, izinYok, hata }

/// Adresten indirip galeriye yazar. Ağ hatası, izin reddi ve yazma hatası
/// AYRI AYRI raporlanır: "kaydedilemedi" deyip susmak, kullanıcıya ne
/// yapacağını söylemez.
Future<GaleriSonuc> galeriyeKaydet(String url) async {
  try {
    final ad = _dosyaAdi(url);
    if (kIsWeb) {
      webIndir(url, ad);
      return GaleriSonuc.tamam;
    }
    final bayt = await _indir(url);
    if (bayt == null) return GaleriSonuc.hata;
    // `toAlbum: true` = "yalnız ekleme" izni; tüm kütüphaneyi OKUMA izni
    // istemiyoruz (Play/App Store incelemesinde gereksiz geniş izin).
    if (!await Gal.hasAccess(toAlbum: true)) {
      if (!await Gal.requestAccess(toAlbum: true)) return GaleriSonuc.izinYok;
    }
    if (_videoMu(url)) {
      // Video BAYTTAN kaydedilemez: `gal` dosya yolu ister. Geçici dizine
      // yazıp yolu veriyoruz; dosya sistem galerisine kopyalandıktan sonra
      // silinir (yoksa aynı video cihazda iki kez yer kaplar).
      final dizin = await getTemporaryDirectory();
      final yol = '${dizin.path}/$ad';
      await dosyaYaz(yol, bayt);
      try {
        await Gal.putVideo(yol, album: _album);
      } finally {
        await dosyaSil(yol);
      }
    } else {
      await Gal.putImageBytes(bayt, album: _album, name: _adKoku(ad));
    }
    return GaleriSonuc.tamam;
  } on GalException catch (e) {
    return e.type == GalExceptionType.accessDenied
        ? GaleriSonuc.izinYok
        : GaleriSonuc.hata;
  } catch (_) {
    return GaleriSonuc.hata;
  }
}

/// Galeride açılacak albüm adı. Tek klasörde toplanınca kullanıcı neyin
/// nereden geldiğini görür (WhatsApp/Telegram da böyle yapar).
const String _album = 'dizi.jpg';

bool _videoMu(String url) {
  final y = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  return y.endsWith('.mp4') || y.endsWith('.webm') || y.endsWith('.mov');
}

/// Adresin son parçası; sorgu dizesi ve dizinler atılır. Boşsa damgalı ad.
String _dosyaAdi(String url) {
  final yol = Uri.tryParse(url)?.path ?? url;
  final son = yol.split('/').where((p) => p.isNotEmpty).lastOrNull ?? '';
  if (son.isEmpty || !son.contains('.')) {
    return 'dizijpg_${DateTime.now().millisecondsSinceEpoch}'
        '${_videoMu(url) ? '.mp4' : '.jpg'}';
  }
  return son;
}

String _adKoku(String ad) {
  final n = ad.lastIndexOf('.');
  return n > 0 ? ad.substring(0, n) : ad;
}

Future<Uint8List?> _indir(String url) async {
  final yanit = await http.get(Uri.parse(url), headers: gorselBasliklari(url));
  if (yanit.statusCode != 200 || yanit.bodyBytes.isEmpty) return null;
  return yanit.bodyBytes;
}
