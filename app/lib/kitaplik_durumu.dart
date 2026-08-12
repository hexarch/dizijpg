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

  /// "tur:tmdbId" → yeniden izleme sayısı (`durumlar.tekrar`). 0 olanlar
  /// TUTULMAZ: harita yalnız tekrar izlenmiş içerikleri taşır.
  static final Map<String, int> _tekrar = {};

  /// Veri değişince artar; ValueListenableBuilder ile dinlenir.
  static final ValueNotifier<int> surum = ValueNotifier(0);

  static bool _yukleniyor = false;

  static String _anahtar(String tur, int tmdbId) => '$tur:$tmdbId';

  /// İçerik izlendi (ya da izleniyor) mu?
  static bool izlendiMi(String tur, int tmdbId) =>
      _izlenen.contains(_anahtar(tur, tmdbId));

  /// Kaç kez YENİDEN izlendi? 0 = bir kez izlendi (rozette sayı çıkmaz).
  static int tekrarSayisi(String tur, int tmdbId) =>
      _tekrar[_anahtar(tur, tmdbId)] ?? 0;

  /// Kitaplığı sunucudan çeker. Giriş yapılmamışsa sessizce boş kalır.
  static Future<void> yukle() async {
    if (_yukleniyor || !Api.girisli) return;
    _yukleniyor = true;
    try {
      final d = await Api.get('/kitapligim');
      final yeni = <String>{};
      final yeniTekrar = <String, int>{};
      for (final s in (d['durumlar'] as List<dynamic>? ?? [])) {
        final m = s as Map<String, dynamic>;
        // "İzleyeceğim" henüz izlenmedi — rozet yalnız gerçekten
        // izlenmiş/izlenmekte olan içeriklerde çıkar.
        final durum = m['durum'] as String?;
        if (durum == 'izliyorum' ||
            durum == 'bitirdim' ||
            durum == 'biraktim') {
          final a = _anahtar(m['tur'] as String, (m['tmdb_id'] as num).toInt());
          yeni.add(a);
          // `tekrar` eski sunucuda yok (alan sonradan eklendi) → 0 sayılır.
          final t = (m['tekrar'] as num?)?.toInt() ?? 0;
          if (t > 0) yeniTekrar[a] = t;
        }
      }
      _izlenen
        ..clear()
        ..addAll(yeni);
      _tekrar
        ..clear()
        ..addAll(yeniTekrar);
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
    // Kitaplıktan düşen içeriğin tekrar sayacı da gider: sunucuda durum
    // silinince `durumlar` satırı (dolayısıyla `tekrar`) silinir.
    if (!izlendi && _tekrar.remove(a) != null) {
      surum.value++;
      return;
    }
    if (degisti) surum.value++;
  }

  /// POST /rewatch yanıtından gelen yeni tekrar sayısı: poster rozetindeki
  /// "×2" sayfa yenilenmeden güncellensin.
  static void tekrarAyarla(String tur, int tmdbId, int tekrar) {
    final a = _anahtar(tur, tmdbId);
    final eski = _tekrar[a] ?? 0;
    final yeni = tekrar < 0 ? 0 : tekrar;
    if (eski == yeni) return;
    if (yeni == 0) {
      _tekrar.remove(a);
    } else {
      _tekrar[a] = yeni;
    }
    surum.value++;
  }

  /// Çıkışta temizlenir; başka hesap önceki kitaplığı görmesin.
  static void temizle() {
    if (_izlenen.isEmpty && _tekrar.isEmpty) return;
    _izlenen.clear();
    _tekrar.clear();
    surum.value++;
  }
}
