import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import '../puan.dart';
import '../tema.dart';
import 'ortak.dart' show altGuvenli;
import 'puan_sec_sheet.dart';

/// Puan + isteğe bağlı YORUM sheet'i. Kaydederse true döner.
///
/// ⚠ 30 Ağu 2026: yazılan metin artık İNCELEMEYE (`puanlar.yorum`) DEĞİL,
/// normal YORUMA (`/yorumlar`) gidiyor. Kullanıcı kararı: "puan verirken
/// yapılan yorum inceleme kısmına gidiyor ama yorum kısmına gitmeli; şu an
/// inceleme kısmı olmamalı, o ileriki aşamada moderatörler için açılacak."
///
/// ESKİ VERİ SİLİNMEDİ: `puanlar.yorum`daki mevcut incelemeler yerinde
/// duruyor (moderatör ekranı için) — yalnız yeni metin oraya YAZILMIYOR ve
/// içerik sayfasında bölüm GÖSTERİLMİYOR.
/// tur: 'tv' | 'movie' | 'person'
///
/// ÖLÇEK (26 Ağu 2026): yıldız satırı yalnız ölçek ≤ 10 iken çizilir; üstünde
/// satır yerine dokunulabilir bir ROZET durur ve [puanSecSheet] açılır
/// (gerekçe: `yildizSatiriOlur`). Böylece bu sheet 100'lük ölçekte de
/// inceleme yazma işlevini korur — puan seçimi iç sayfaya devredilir.
Future<bool> puanlaVeKaydet(
  BuildContext context, {
  required String tur,
  required int tmdbId,
  int? mevcutPuan,
  String? mevcutYorum,
}) async {
  // Kutu BOŞ başlar: yorum düzenlenebilir bir alan değil, EKLENEN bir
  // gönderidir. Eski inceleme metnini öndoldurmak, kaydete her basışta aynı
  // metnin yeni bir yorum olarak tekrar gönderilmesine yol açardı.
  final yorumKutusu = TextEditingController();
  // Görünüm ölçeği; sunucuda kanonik 1-100 tutulur (bkz. lib/puan.dart).
  // Sheet açıkken ölçek değişemeyeceği için bir kez okunur.
  final olcek = PuanOlcegi.deger.value;
  var secilen = yildiza(mevcutPuan, olcek: olcek);
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
              final metin = yorumKutusu.text.trim();
              // PUAN ve YORUM AYRI: `/puan` yalnız sayıyı taşır, metin
              // `/yorumlar`a gider. `yorum` alanı BİLEREK gönderilmiyor —
              // gönderilseydi metin yine `puanlar.yorum`a, yani inceleme
              // bölümüne düşerdi.
              await Api.post('/puan', {
                'tmdb_id': tmdbId,
                'tur': tur,
                'puan': secilen == 0 ? null : dbPuani(secilen, olcek: olcek),
                'kanonik': true, // bkz. tepki.dart'taki gerekçe
              });
              // Yorum İKİNCİ istek: puan kaydı yorumun başarısına BAĞLI
              // OLMASIN. Yorum düşerse puan yine kaydedilmiş olur ve
              // kullanıcıya ayrıca haber verilir — sessiz kayıp yok.
              if (metin.isNotEmpty) {
                try {
                  await Api.post('/yorumlar', {
                    'tur': tur,
                    'tmdb_id': tmdbId,
                    'metin': metin,
                  });
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      // Mevcut ve 45 dilde çevrili anahtar kullanıldı:
                      // GIF ajanı şu an dil dosyalarında çalışıyor, yeni
                      // anahtar eklemek çakışma üretirdi.
                      SnackBar(content: Text('Bir şeyler ters gitti'.c)),
                    );
                  }
                }
              }
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
                if (yildizSatiriOlur(olcek))
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4,
                    children: [
                      for (var p = 1; p <= olcek; p++)
                        IconButton(
                          onPressed: () => setModal(() => secilen = p),
                          icon: Icon(
                            p <= secilen
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: DiziRenkler.sari,
                            // 10 yıldızda 40 dp ikonlar Wrap'i iki satıra
                            // kırıyordu; ölçekle küçülür (tek kaynak:
                            // yildizIkonBoyu).
                            size: yildizIkonBoyu(olcek, taban: 40),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                        ),
                    ],
                  )
                else
                  // Geniş ölçek: satır yerine rozet → kaydırıcılı iç sayfa.
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final s = await puanSecSheet(
                          context,
                          olcek: olcek,
                          mevcut: secilen,
                        );
                        if (s != null) setModal(() => secilen = s);
                      },
                      icon: Icon(
                        secilen > 0
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: DiziRenkler.sari,
                      ),
                      label: Text(
                        secilen > 0 ? '$secilen/$olcek' : 'Puanla'.c,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: yorumKutusu,
                  maxLines: 4,
                  decoration: InputDecoration(hintText: 'Yorum yaz...'.c),
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
