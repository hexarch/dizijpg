import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';

/// GIF sihirli baytı: kırpmadan geçirilir ki animasyon bozulmasın.
bool gifMi(Uint8List veri) =>
    veri.length > 3 && veri[0] == 0x47 && veri[1] == 0x49 && veri[2] == 0x46;

/// Kırpma/konumlama modalı: kullanıcı kadrajı ayarlar, kırpılmış
/// baytlar döner (vazgeçerse null). Ayarlar ve profil ortak kullanır.
Future<Uint8List?> gorselKirp(
  BuildContext context,
  Uint8List veri, {
  required double oran,
  bool daire = false,
}) async {
  final kontrol = CropController();
  return showModalBottomSheet<Uint8List?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DiziRenkler.siyah,
    builder: (context) {
      var kirpiliyor = false;
      return StatefulBuilder(
        builder: (context, setSheet) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Text(
                      'Konumla ve kırp'.c,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context, null),
                      child: Text(
                        'İptal'.c,
                        style: TextStyle(color: DiziRenkler.metin54),
                      ),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      onPressed: kirpiliyor
                          ? null
                          : () {
                              setSheet(() => kirpiliyor = true);
                              kontrol.crop();
                            },
                      child: kirpiliyor
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Text('Tamam'.c),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Crop(
                  image: veri,
                  controller: kontrol,
                  aspectRatio: oran,
                  withCircleUi: daire,
                  baseColor: DiziRenkler.siyah,
                  maskColor: Colors.black54,
                  onCropped: (kirpik) => Navigator.pop(context, kirpik),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Profil görseli (avatar/kapak) düzenleme akışı: seçenek sheet'i →
/// yeni foto seç + kırp + yükle YA DA mevcut görseli yeniden konumlandır.
/// Başarıda sunucudaki yeni yol ile [onYuklendi] çağrılır.
Future<void> profilGorseliDuzenle(
  BuildContext context, {
  required bool kapak,
  String? mevcutUrl,
  required void Function(String yol) onYuklendi,
  required void Function(bool) yukleniyor,
}) async {
  final secenek = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: DiziRenkler.koyuGri,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(
              Icons.photo_library_outlined,
              color: DiziRenkler.sari,
            ),
            title: Text('Fotoğrafı değiştir'.c),
            onTap: () => Navigator.pop(context, 'degistir'),
          ),
          if (mevcutUrl != null && !mevcutUrl.endsWith('.gif'))
            ListTile(
              leading: const Icon(Icons.crop_rotate, color: DiziRenkler.sari),
              title: Text('Yeniden konumlandır'.c),
              onTap: () => Navigator.pop(context, 'konumla'),
            ),
        ],
      ),
    ),
  );
  if (secenek == null || !context.mounted) return;

  Uint8List? veri;
  if (secenek == 'degistir') {
    final secim = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (secim == null) return;
    veri = await secim.readAsBytes();
  } else {
    // Mevcut görseli indirip yeniden kadrajla
    try {
      final y = await http.get(Uri.parse(mevcutUrl!));
      if (y.statusCode != 200) throw Exception();
      veri = y.bodyBytes;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Bir şeyler ters gitti'.c)));
      }
      return;
    }
  }
  if (!context.mounted) return;

  if (!gifMi(veri)) {
    final kirpik = await gorselKirp(
      context,
      veri,
      oran: kapak ? 2.4 : 1,
      daire: !kapak,
    );
    if (kirpik == null) return;
    veri = kirpik;
  }
  if (!context.mounted) return;

  yukleniyor(true);
  try {
    final sinir = kapak ? 10 : 8;
    if (veri.length > sinir * 1024 * 1024) {
      throw ApiHata('Dosya en fazla {}MB olabilir'.cf([sinir]));
    }
    final yol = kapak
        ? await Api.kapakYukle(veri)
        : await Api.avatarYukle(veri);
    if (!context.mounted) return;
    onYuklendi(yol);
    final oturum = context.read<Oturum>();
    await oturum.girisYapildi({
      ...?oturum.kullanici,
      kapak ? 'kapak' : 'avatar': yol,
    });
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  } finally {
    yukleniyor(false);
  }
}
