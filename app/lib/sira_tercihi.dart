import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ceviri.dart';
import 'tema.dart';

/// Akış / Keşfet sıralama tercihi: **Önerilen** (algoritmik) ya da
/// **Kronolojik** (en yeniden eskiye).
///
/// VARSAYILAN "Önerilen" (kullanıcı kararı, 3 Ağu 2026: *"kullanıcıya sunalım
/// ama otomatik olarak önerilen kalsın"*). Sunucu `?sira=kronolojik` almazsa
/// zaten Önerilen'i uygular; yani tercih yalnız kronolojik seçilince tele
/// binen bir parametredir ve eski sürüm uygulamalar hiç etkilenmez.
///
/// İKİ AYRI ANAHTAR: Akış ve Keşfet ayrı yüzeylerdir, sunucuda ayrı ağırlık
/// setleriyle sıralanırlar ve kullanıcının beklentisi de farklıdır ("ne oldu"
/// vs "ne varmış"). Tek anahtar, bir ekranda yapılan seçimi diğerine sızdırırdı.
enum SiraTuru { onerilen, kronolojik }

/// Sıralama tercihi deposu. Yüzey başına tek `ValueNotifier`; ekranlar buna
/// abone olur, tercih değişince liste kendiliğinden tazelenir.
class SiraTercihi {
  static const anahtarAkis = 'sira_akis';
  static const anahtarKesfet = 'sira_kesfet';

  static final ValueNotifier<SiraTuru> akis = ValueNotifier(SiraTuru.onerilen);
  static final ValueNotifier<SiraTuru> kesfet = ValueNotifier(
    SiraTuru.onerilen,
  );

  static ValueNotifier<SiraTuru> notifier(String anahtar) =>
      anahtar == anahtarKesfet ? kesfet : akis;

  /// Kayıtlı tercihleri okur. `main.dart`ta uygulama açılırken bir kez çağrılır.
  static Future<void> yukle() async {
    try {
      final p = await SharedPreferences.getInstance();
      akis.value = _coz(p.getString(anahtarAkis));
      kesfet.value = _coz(p.getString(anahtarKesfet));
    } catch (_) {
      // Tercih okunamazsa varsayılan (Önerilen) kalır — ekran açılmadan
      // kalmasındansa varsayılanla açılması yeğdir.
    }
  }

  static SiraTuru _coz(String? d) =>
      d == 'kronolojik' ? SiraTuru.kronolojik : SiraTuru.onerilen;

  static Future<void> sec(String anahtar, SiraTuru tur) async {
    final n = notifier(anahtar);
    if (n.value == tur) return;
    n.value = tur;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        anahtar,
        tur == SiraTuru.kronolojik ? 'kronolojik' : 'onerilen',
      );
    } catch (_) {
      // Yazılamazsa tercih bu oturumda geçerli olur; kullanıcıya hata
      // göstermeye değmez (sıralama zaten değişti).
    }
  }

  /// Uçlara eklenecek sorgu parçası. Önerilen'de BOŞ döner: sunucunun
  /// varsayılanı zaten Önerilen ve gereksiz parametre imleçleri kirletmez.
  static String sorgu(String anahtar) =>
      notifier(anahtar).value == SiraTuru.kronolojik ? 'sira=kronolojik' : '';
}

/// AppBar'ın sağına konan sıralama seçici.
///
/// İkon SEÇİLİ MODU ANLATIR (menüyü açmadan görünür): Önerilen'de yıldız,
/// Kronolojik'te saat. Dokunma hedefi `IconButton` varsayılanı olan 48 px —
/// 44 px kuralının üstünde. Renkler `DiziRenkler`den gelir (açık tema var).
class SiraSecici extends StatelessWidget {
  /// `SiraTercihi.anahtarAkis` ya da `SiraTercihi.anahtarKesfet`.
  final String anahtar;

  /// Tercih değişince çağrılır — ekran listesini baştan yükler.
  final VoidCallback onDegisti;

  const SiraSecici({super.key, required this.anahtar, required this.onDegisti});

  @override
  Widget build(BuildContext context) {
    final n = SiraTercihi.notifier(anahtar);
    return ValueListenableBuilder<SiraTuru>(
      valueListenable: n,
      builder: (context, secili, _) => PopupMenuButton<SiraTuru>(
        tooltip: 'Sıralama'.c,
        position: PopupMenuPosition.under,
        icon: Icon(
          secili == SiraTuru.kronolojik ? Icons.schedule : Icons.auto_awesome,
          color: DiziRenkler.metin70,
        ),
        onSelected: (tur) async {
          if (tur == secili) return;
          await SiraTercihi.sec(anahtar, tur);
          onDegisti();
        },
        itemBuilder: (context) => [
          _oge(SiraTuru.onerilen, Icons.auto_awesome, 'Önerilen'.c, secili),
          _oge(SiraTuru.kronolojik, Icons.schedule, 'Kronolojik'.c, secili),
        ],
      ),
    );
  }

  PopupMenuItem<SiraTuru> _oge(
    SiraTuru tur,
    IconData ikon,
    String yazi,
    SiraTuru secili,
  ) {
    final aktif = tur == secili;
    return PopupMenuItem<SiraTuru>(
      value: tur,
      child: Row(
        children: [
          Icon(
            ikon,
            size: 20,
            color: aktif ? DiziRenkler.sariMetin : DiziRenkler.metin54,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              yazi,
              style: TextStyle(
                color: aktif ? DiziRenkler.sariMetin : DiziRenkler.metin,
                fontWeight: aktif ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          if (aktif) Icon(Icons.check, size: 18, color: DiziRenkler.sariMetin),
        ],
      ),
    );
  }
}
