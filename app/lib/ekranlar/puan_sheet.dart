import 'package:flutter/material.dart';

import '../api.dart';
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
  var secilen = mevcutPuan ?? 0;

  final kaydet = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DiziRenkler.koyuGri,
    builder: (context) => StatefulBuilder(
      builder: (context, setModal) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Puanın',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: [
                for (var p = 1; p <= 10; p++)
                  IconButton(
                    onPressed: () => setModal(() => secilen = p),
                    icon: Icon(
                      p <= secilen ? Icons.star : Icons.star_border,
                      color: DiziRenkler.kirmizi,
                      size: 28,
                    ),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 30, minHeight: 30),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: yorumKutusu,
              maxLines: 4,
              decoration:
                  const InputDecoration(hintText: 'İncelemen (isteğe bağlı)'),
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
                    child: const Text('Puanı Sil',
                        style: TextStyle(color: Colors.redAccent)),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Kaydet'),
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
    'puan': secilen == 0 ? null : secilen,
    'yorum': yorumKutusu.text.trim().isEmpty ? null : yorumKutusu.text.trim(),
  });
  return true;
}
