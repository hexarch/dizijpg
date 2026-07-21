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

  try {
    final kaydet = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DiziRenkler.koyuGri,
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) => Padding(
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
                      onPressed: () {
                        secilen = 0;
                        Navigator.pop(context, true);
                      },
                      child: Text(
                        'Puanı Sil'.c,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('Kaydet'.c),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (kaydet != true) return false;
    await Api.post('/puan', {
      'tmdb_id': tmdbId,
      'tur': tur,
      'puan': secilen == 0 ? null : secilen * 2,
      'yorum': yorumKutusu.text.trim().isEmpty ? null : yorumKutusu.text.trim(),
    });
    return true;
  } finally {
    yorumKutusu.dispose();
  }
}
