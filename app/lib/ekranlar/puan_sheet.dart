import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import '../puan.dart';
import '../tema.dart';
import 'ortak.dart' show altGuvenli;

/// 1-10 puan + isteğe bağlı inceleme sheet'i. Kaydederse true döner.
/// tur: 'tv' | 'movie' | 'person'
Future<bool> puanlaVeKaydet(
  BuildContext context, {
  required String tur,
  required int tmdbId,
  int? mevcutPuan,
  String? mevcutYorum,
}) async {
  final yorumKutusu = TextEditingController(text: mevcutYorum ?? '');
  // 5 yıldız ölçeği; sunucuda 1-10 tutulur (bkz. lib/puan.dart)
  var secilen = yildiza(mevcutPuan);
  var kaydediyor = false;

  try {
    final kaydedildi = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DiziRenkler.koyuGri,
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) {
          // Kaydet: buton kilidi + spinner → başarıda kapat (çift gönderim yok).
          Future<void> gonder() async {
            setModal(() => kaydediyor = true);
            try {
              await Api.post('/puan', {
                'tmdb_id': tmdbId,
                'tur': tur,
                'puan': secilen == 0 ? null : dbPuani(secilen),
                'yorum': yorumKutusu.text.trim().isEmpty
                    ? null
                    : yorumKutusu.text.trim(),
              });
              if (context.mounted) Navigator.pop(context, true);
            } catch (e) {
              // Sessiz veri kaybı olmasın: kullanıcıya bildir, sheet açık kalsın.
              setModal(() => kaydediyor = false);
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Puan kaydedilemedi'.c)));
              }
            }
          }

          // ALT PAY: klavye (viewInsets) + sistem gezinme çubuğu (altGuvenli).
          //
          // ÇİFT SAYIM YOK, çünkü ikisi AYNI ANDA sıfırdan büyük olamaz:
          // klavye açıkken sistem çubuğu klavyenin ALTINDA kalır, platform da
          // `padding.bottom`u 0'a çeker (`viewPadding` korunur, bkz. FlutterView
          // dokümanı) → altGuvenli o an yalnız 20 döner. Klavye kapalıyken
          // viewInsets 0'dır → yalnız 48 + 20 eklenir.
          //
          // Eskiden yalnız `viewInsets + 20` vardı: klavye KAPALIYKEN "Kaydet"
          // ve "Puanı Sil" butonlarının alt kenarı 763'e düşüyordu, yani 48 dp
          // navi çubuğu olan 360x800 telefonda güvenli sınırın (752) ALTINDA.
          // `useSafeArea: true` bunu çözmez — Flutter onu `SafeArea(bottom:
          // false)` olarak uygular, alt kenara hiç dokunmaz.
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(context).viewInsets.bottom +
                  altGuvenli(context, ekstra: 20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Puanın'.c,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  children: [
                    for (var p = 1; p <= 5; p++)
                      IconButton(
                        onPressed: () => setModal(() => secilen = p),
                        icon: Icon(
                          p <= secilen
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: DiziRenkler.sari,
                          size: 40,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: yorumKutusu,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'İncelemen (isteğe bağlı)'.c,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if ((mevcutPuan ?? 0) > 0)
                      TextButton(
                        onPressed: kaydediyor
                            ? null
                            : () {
                                secilen = 0;
                                gonder();
                              },
                        child: Text(
                          'Puanı Sil'.c,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: kaydediyor ? null : gonder,
                      child: kaydediyor
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Text('Kaydet'.c),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return kaydedildi == true;
  } finally {
    yorumKutusu.dispose();
  }
}
