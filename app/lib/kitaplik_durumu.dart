import 'package:flutter/foundation.dart';

import 'api.dart';

/// Kullanıcının kitaplığındaki içeriklerin hafızada tutulan özeti.
///
/// Poster kartlarına "izledin" rozeti koymak için her kart tek tek sunucuya
/// sormamalı; /kitapligim bir kez çekilip burada tutulur. [surum] değişince
/// rozet gösteren widget'lar kendini yeniler.
class KitaplikDurumu {
  /// "tur:tmdbId" biçiminde izlenen/izleniyor olan içerikler.
  static final Set<String> _izlenen = {};

  /// Veri değişince artar; ValueListenableBuilder ile dinlenir.
  static final ValueNotifier<int> surum = ValueNotifier(0);

  static bool _yukleniyor = false;

  static String _anahtar(String tur, int tmdbId) => '$tur:$tmdbId';

  /// İçerik izlendi (ya da izleniyor) mu?
  static bool izlendiMi(String tur, int tmdbId) =>
      _izlenen.contains(_anahtar(tur, tmdbId));

  /// Kitaplığı sunucudan çeker. Giriş yapılmamışsa sessizce boş kalır.
  static Future<void> yukle() async {
    if (_yukleniyor || !Api.girisli) return;
    _yukleniyor = true;
    try {
      final d = await Api.get('/kitapligim');
      final yeni = <String>{};
      for (final s in (d['durumlar'] as List<dynamic>? ?? [])) {
        final m = s as Map<String, dynamic>;
        // "İzleyeceğim" henüz izlenmedi — rozet yalnız gerçekten
        // izlenmiş/izlenmekte olan içeriklerde çıkar.
        final durum = m['durum'] as String?;
        if (durum == 'izliyorum' ||
            durum == 'bitirdim' ||
            durum == 'biraktim') {
          yeni.add(_anahtar(m['tur'] as String, (m['tmdb_id'] as num).toInt()));
        }
      }
      _izlenen
        ..clear()
        ..addAll(yeni);
      surum.value++;
    } catch (_) {
      // Ağ hatası: rozet gösterilmez, uygulama etkilenmez.
    } finally {
      _yukleniyor = false;
    }
  }

  /// Kullanıcı bir içeriği izlemeye başlayınca/bırakınca anında yansısın.
  static void isaretle(String tur, int tmdbId, bool izlendi) {
    final a = _anahtar(tur, tmdbId);
    final degisti = izlendi ? _izlenen.add(a) : _izlenen.remove(a);
    if (degisti) surum.value++;
  }

  /// Çıkışta temizlenir; başka hesap önceki kitaplığı görmesin.
  static void temizle() {
    if (_izlenen.isEmpty) return;
    _izlenen.clear();
    surum.value++;
  }
}
