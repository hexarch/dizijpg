import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ceviri.dart';
import '../hareketli_emoji.dart';
import '../tema.dart';

/// EMOJİ PANELİ (5 Eyl 2026): yazı kutusundaki gülen yüz düğmesi klavyenin
/// yerine bu paneli açar (Telegram'ın emoji sekmesi). Liste hareketli emoji
/// sözlüğüdür (`hareketli_emoji.dart`): buradan seçilen her emoji MESAJDA
/// büyük Lottie olarak oynar.
///
/// PANELDE GLİF, LOTTIE DEĞİL (Galaxy S24'te görüldü, 5 Eyl): Noto
/// animasyonlarının İLK KARESİ çoğu yüzde aynı nötr surattır (😀 🙂 😉 😊
/// dördü de boş bakan sarı daire) — kullanıcı hangisini seçtiğini göremez.
/// Ayrıca 40 görünür Lottie'yi bir anda çözmek hücreleri yarım saniye boş
/// bırakıyordu. Sistem emoji fontu anında ve tanınır çizer; Telegram'ın
/// emoji klavyesi de statiktir, hareket mesajda başlar.
///
/// Üstte "Sık kullanılanlar": bu cihazda son seçilen 16 emoji
/// (`SharedPreferences`, sohbetten bağımsız). Dokununca [onSec] çağrılır;
/// metne ekleme kutunun işidir (imleç konumunu o bilir).
class EmojiPaneli extends StatefulWidget {
  final void Function(String emoji) onSec;

  const EmojiPaneli({super.key, required this.onSec});

  static const _anahtar = 'sohbet_son_emojiler';
  static const azamiSon = 16;

  /// Seçilen emojiyi "sık kullanılanlar"ın başına yazar (tekrarı öne alır).
  static Future<void> kaydet(String emoji) async {
    final p = await SharedPreferences.getInstance();
    final liste = List<String>.from(p.getStringList(_anahtar) ?? const [])
      ..remove(emoji)
      ..insert(0, emoji);
    await p.setStringList(
      _anahtar,
      liste.length > azamiSon ? liste.sublist(0, azamiSon) : liste,
    );
  }

  static Future<List<String>> sonlar() async {
    final p = await SharedPreferences.getInstance();
    return p.getStringList(_anahtar) ?? const [];
  }

  @override
  State<EmojiPaneli> createState() => _EmojiPaneliState();
}

class _EmojiPaneliState extends State<EmojiPaneli> {
  List<String> _sonlar = const [];

  @override
  void initState() {
    super.initState();
    EmojiPaneli.sonlar().then((l) {
      if (mounted && l.isNotEmpty) setState(() => _sonlar = l);
    });
  }

  Widget _baslik(String metin) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
    child: Text(
      metin,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: DiziRenkler.metin54,
      ),
    ),
  );

  SliverGrid _izgara(List<String> emojiler, String onek, int sutun) =>
      SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: sutun,
        ),
        itemCount: emojiler.length,
        itemBuilder: (context, i) {
          final e = emojiler[i];
          return Semantics(
            button: true,
            label: e,
            child: InkWell(
              key: Key('$onek-$e'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => widget.onSec(e),
              child: Center(
                child: Text(
                  e,
                  style: const TextStyle(fontSize: 28, height: 1.15),
                ),
              ),
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, kisit) {
        // Hücre ~48 dp: 390 dp'de 8 sütun, 320'de 6, masaüstünde daha çok.
        final sutun = (kisit.maxWidth / 48).floor().clamp(5, 12);
        return Material(
          color: DiziRenkler.koyuGri,
          child: CustomScrollView(
            slivers: [
              if (_sonlar.isNotEmpty) ...[
                SliverToBoxAdapter(child: _baslik('Sık kullanılanlar'.c)),
                _izgara(_sonlar, 'son', sutun),
              ],
              SliverToBoxAdapter(child: _baslik('Emoji'.c)),
              _izgara(sohbetEmojileri, 'emoji', sutun),
              const SliverPadding(padding: EdgeInsets.only(bottom: 8)),
            ],
          ),
        );
      },
    );
  }
}
