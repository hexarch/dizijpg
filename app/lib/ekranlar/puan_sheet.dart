import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';

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
  // 5 yıldız ölçeği; sunucuda 1-10 tutulur (yıldız × 2)
  var secilen = ((mevcutPuan ?? 0) / 2).round();
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
                'puan': secilen == 0 ? null : secilen * 2,
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

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
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
