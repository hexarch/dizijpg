import 'dart:async';

import 'api.dart';

/// Poster kartı bilgilerini TOPLU çeken ve önbellekte tutan depo.
///
/// Eskiden her karo kendi `/tmdb/{tur}/{id}` isteğini atıyordu; tek yanıt
/// ~61 KB (kadro, sezonlar, fragmanlar...) ve 30 karolu bir şerit ~1,8 MB
/// ediyordu. Kart bunlardan yalnız ad/poster/puan/bölüm sayısını kullanıyor.
///
/// Burada aynı karede istenen tüm kimlikler biriktirilip `POST /icerikler`
/// ile TEK istekte alınır (aynı şerit ~4 KB). Sonuçlar oturum boyunca
/// önbellekte kalır; aynı dizi başka ekranda tekrar istenirse ağa çıkılmaz.
class IcerikDeposu {
  static final Map<String, Map<String, dynamic>> _onbellek = {};
  static final Map<String, List<Completer<Map<String, dynamic>?>>> _bekleyen =
      {};
  static Timer? _zamanlayici;

  /// Sunucudaki tavanla aynı: tek istekte en fazla bu kadar içerik.
  static const _partiTavani = 120;

  static String _anahtar(String tur, int tmdbId) => '$tur:$tmdbId';

  /// Kart bilgisini verir. Önbellekteyse anında, değilse aynı karedeki diğer
  /// isteklerle birleştirilip tek çağrıda alınır. Bulunamazsa null.
  static Future<Map<String, dynamic>?> getir(String tur, int tmdbId) {
    final a = _anahtar(tur, tmdbId);
    final hazir = _onbellek[a];
    if (hazir != null) return Future.value(hazir);

    final tamamlayici = Completer<Map<String, dynamic>?>();
    _bekleyen.putIfAbsent(a, () => []).add(tamamlayici);
    // Bu karede istenen her şey toplansın diye bir sonraki tik'e ertelenir.
    _zamanlayici ??= Timer(Duration.zero, _bosalt);
    return tamamlayici.future;
  }

  static Future<void> _bosalt() async {
    _zamanlayici = null;
    if (_bekleyen.isEmpty) return;
    final parti = _bekleyen.keys.take(_partiTavani).toList();
    final talepler = {for (final a in parti) a: _bekleyen.remove(a)!};
    // Tavanı aşan kalanlar için yeni tur planla
    if (_bekleyen.isNotEmpty) _zamanlayici ??= Timer(Duration.zero, _bosalt);

    Map<String, dynamic> gelen = {};
    try {
      final d = await Api.post('/icerikler', {'anahtarlar': parti});
      gelen = (d['icerikler'] as Map<String, dynamic>? ?? {});
    } catch (_) {
      // Ağ hatası: bekleyenler null alır, karo kırık görsel gösterir.
    }
    talepler.forEach((a, bekleyenler) {
      final v = gelen[a] as Map<String, dynamic>?;
      if (v != null) _onbellek[a] = v;
      for (final t in bekleyenler) {
        if (!t.isCompleted) t.complete(v);
      }
    });
  }

  /// Çıkışta temizlenir (dil değişince de içerik adları yenilensin diye).
  static void temizle() => _onbellek.clear();
}
