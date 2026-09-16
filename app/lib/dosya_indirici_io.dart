import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'api.dart';
import 'ceviri.dart';
import 'ekranlar/dosya_goruntule.dart';

/// Tek belgenin indirme durumu. [ilerleme] 0..1 (bilinmiyorsa null), iş
/// bitince [bitti] true; başarıda [yol] dolu, hatada [hata] dolu.
class DosyaIndirme {
  final ValueNotifier<double?> ilerleme = ValueNotifier(0);
  final ValueNotifier<bool> bitti = ValueNotifier(false);
  String? yol;
  Object? hata;
}

/// Belgeleri `<belgeler>/sohbet_dosyalari/` altına indirir.
///
/// ANAHTAR = URL'in YOLU (sorgu hariç): imzalı bağlantının `?imza=…&son=…`
/// kısmı her yüklemede değişir; dosya adı yoldan türetilmezse aynı belge
/// tekrar tekrar iner. Yerel ad `<sunucu adı>__<gerçek ad>`: uzantı gerçek
/// addan gelir ki sistem uygulaması ("PDF görüntüleyici") biçimi tanısın.
/// YALNIZ TEST: widget testleri gerçek dosya/ağ G/Ç'sini sahte zamanda
/// yürütemez (jest işleyicileri sahte bölgede koşar, IO future'ları asılı
/// kalır). Bu kanca indirici + açıcıyı bellek içi taklitle değiştirir;
/// gerçek indirme `test/dosya_indirici_test.dart`ta saf birim olarak sınanır.
class DosyaIndiriciSahte {
  final Future<String?> Function(String url, String ad) yerelYol;
  final DosyaIndirme Function(String url, String ad) indir;
  final Future<void> Function(BuildContext context, String yol, String ad) ac;
  const DosyaIndiriciSahte({
    required this.yerelYol,
    required this.indir,
    required this.ac,
  });
}

class DosyaIndirici {
  static bool get destekli => true;

  @visibleForTesting
  static DosyaIndiriciSahte? sahte;

  static final Map<String, DosyaIndirme> _aktif = {};

  /// YALNIZ TEST: belgeler dizini yerine geçici dizin.
  @visibleForTesting
  static Future<Directory> Function()? dizinSaglayici;

  static Future<Directory> _dizin() async {
    final kok = dizinSaglayici != null
        ? await dizinSaglayici!()
        : await getApplicationDocumentsDirectory();
    final d = Directory('${kok.path}${Platform.pathSeparator}sohbet_dosyalari');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static String _yerelAd(String url, String ad) {
    final yol = Uri.tryParse(url)?.path ?? url;
    final parcalar = yol.split('/').where((p) => p.isNotEmpty).toList();
    final sunucuAdi = parcalar.isEmpty ? 'dosya' : parcalar.last;
    var temiz = ad.replaceAll(RegExp(r'[^\w.\- ()]', unicode: true), '_');
    if (temiz.length > 80) temiz = temiz.substring(temiz.length - 80);
    if (temiz.isEmpty) temiz = 'dosya';
    return '${sunucuAdi.replaceAll(RegExp(r'[^\w.\-]'), '_')}__$temiz';
  }

  static Future<File> _hedef(String url, String ad) async => File(
    '${(await _dizin()).path}${Platform.pathSeparator}${_yerelAd(url, ad)}',
  );

  /// Daha önce indirilmişse yerel yol, yoksa null.
  static Future<String?> yerelYol(String url, String ad) async {
    if (sahte != null) return sahte!.yerelYol(url, ad);
    try {
      final f = await _hedef(url, ad);
      return await f.exists() ? f.path : null;
    } catch (_) {
      return null;
    }
  }

  /// Sürmekte olan indirme (aynı balon yeniden kurulunca yakalar).
  static DosyaIndirme? aktif(String url) =>
      _aktif[Uri.tryParse(url)?.path ?? url];

  /// İndirmeyi başlatır ya da sürene bağlanır.
  static DosyaIndirme indir(String url, String ad) {
    if (sahte != null) return sahte!.indir(url, ad);
    final anahtar = Uri.tryParse(url)?.path ?? url;
    final var_ = _aktif[anahtar];
    if (var_ != null) return var_;
    final d = DosyaIndirme();
    _aktif[anahtar] = d;
    _calistir(url, ad, d).whenComplete(() => _aktif.remove(anahtar));
    return d;
  }

  static Future<void> _calistir(String url, String ad, DosyaIndirme d) async {
    File? gecici;
    try {
      final hedef = await _hedef(url, ad);
      gecici = File('${hedef.path}.part');
      final yanit = await Api.istemci.send(http.Request('GET', Uri.parse(url)));
      if (yanit.statusCode != 200) {
        throw HttpException('HTTP ${yanit.statusCode}', uri: Uri.parse(url));
      }
      final toplam = yanit.contentLength;
      final cikis = gecici.openWrite();
      var alinan = 0;
      try {
        await for (final parca in yanit.stream) {
          cikis.add(parca);
          alinan += parca.length;
          d.ilerleme.value = (toplam != null && toplam > 0)
              ? (alinan / toplam).clamp(0.0, 1.0)
              : null;
        }
      } finally {
        await cikis.close();
      }
      await gecici.rename(hedef.path);
      d.yol = hedef.path;
      d.ilerleme.value = 1;
    } catch (e) {
      d.hata = e;
      try {
        if (gecici != null && await gecici.exists()) await gecici.delete();
      } catch (_) {}
    } finally {
      d.bitti.value = true;
    }
  }
}

const _gorselUzantilari = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'};
const _metinUzantilari = {
  'txt',
  'md',
  'srt',
  'vtt',
  'json',
  'csv',
  'log',
  'xml',
  'yaml',
  'yml',
};

String _uzanti(String ad) =>
    ad.contains('.') ? ad.split('.').last.toLowerCase() : '';

/// İndirilmiş belgeyi açar.
///
/// · görsel / düz metin → uygulama içi görüntüleyici (dosya_goruntule.dart)
/// · diğerleri → sistemdeki uygulama (open_filex). Açacak uygulama yoksa
///   ("noAppToOpen") ya da açma başarısızsa paylaşım sayfası: kullanıcı
///   dosyayı destekleyen uygulamaların listesini orada görür.
Future<void> dosyaAc(BuildContext context, String yol, String ad) async {
  if (DosyaIndirici.sahte != null)
    return DosyaIndirici.sahte!.ac(context, yol, ad);
  final u = _uzanti(ad.isNotEmpty ? ad : yol);
  if (_gorselUzantilari.contains(u)) {
    await yerelGorselGoster(context, yol, ad);
    return;
  }
  if (_metinUzantilari.contains(u)) {
    await yerelMetinGoster(context, yol, ad);
    return;
  }
  final sonuc = await OpenFilex.open(yol);
  if (sonuc.type == ResultType.done) return;
  if (!context.mounted) return;
  final mesajci = ScaffoldMessenger.maybeOf(context);
  if (sonuc.type == ResultType.noAppToOpen) {
    mesajci?.showSnackBar(
      SnackBar(content: Text('Bu dosyayı açacak uygulama yok'.c)),
    );
  }
  // Paylaşım sayfası: destekleyen uygulamalar burada listelenir.
  try {
    await Share.shareXFiles([XFile(yol, name: ad)], subject: ad);
  } catch (_) {
    mesajci?.showSnackBar(SnackBar(content: Text('Dosya açılamadı'.c)));
  }
}
