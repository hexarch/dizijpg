import 'package:flutter/foundation.dart';

import 'api.dart';

/// Kullanıcının KENDİ puanları + favorileri — satır görünümünün deposu.
///
/// NEDEN STATİK DEPO: satır görünümü üç ekranda birden var (İzlediklerim,
/// kitaplık durum listesi ve ileride liste içeriği). Her satır kendi puanını
/// sorsaydı 578 öğelik bir listede 578 istek çıkardı; bu depo `/puanlarim`ı
/// TEK kez çeker ve hepsi aynı haritadan okur.
///
/// TAZELİK: satır görünümü her AÇILDIĞINDA [yukle] çağrılır.
/// Kullanıcı bir dizinin sayfasına girip puan verip geri döndüğünde satırdaki
/// puan güncel olmalı; tek küçük istek bunun en ucuz garantisi — detay
/// ekranını depoya bağlamak (her puanlama/favori dokunuşunda burayı da
/// güncellemek) aynı sonucu daha çok kaçak noktasıyla verirdi.
class PuanFavoriDeposu {
  /// "tur:tmdbId" → KANONİK db puanı (1-100). Görünüm ölçeğine çeviren
  /// [yildiza]'dır; burada ham değer durur (bkz. puan.dart).
  static final Map<String, int> _puanlar = {};

  /// "tur:tmdbId" — favorilenmiş dizi/filmler.
  static final Set<String> _favoriler = {};

  /// Veri değişince artar; satırlar bunu dinleyip kendini yeniler.
  static final ValueNotifier<int> surum = ValueNotifier(0);

  static bool _yukleniyor = false;

  static String _anahtar(String tur, int tmdbId) => '$tur:$tmdbId';

  /// Kullanıcının bu başlığa verdiği db puanı (1-100); yoksa null.
  static int? puan(String tur, int tmdbId) => _puanlar[_anahtar(tur, tmdbId)];

  static bool favoriMi(String tur, int tmdbId) =>
      _favoriler.contains(_anahtar(tur, tmdbId));

  /// Puan + favori haritasını çeker. Giriş yapılmamışsa sessizce boş kalır;
  /// ağ hatası da SESSİZDİR — satır o zaman puansız/kalpsiz çizilir, liste
  /// yine görünür (puan satırın süsü, listenin kendisi değil).
  static Future<void> yukle() async {
    if (_yukleniyor || !Api.girisli) return;
    _yukleniyor = true;
    try {
      final d = await Api.get('/puanlarim');
      final yeniPuan = <String, int>{};
      for (final p in (d['puanlar'] as List<dynamic>? ?? [])) {
        final m = p as Map<String, dynamic>;
        final v = (m['puan'] as num?)?.toInt();
        if (v != null && v > 0) {
          yeniPuan[_anahtar(
                m['tur'] as String,
                (m['tmdb_id'] as num).toInt(),
              )] =
              v;
        }
      }
      final yeniFavori = <String>{
        for (final f in (d['favoriler'] as List<dynamic>? ?? []))
          _anahtar(
            (f as Map<String, dynamic>)['tur'] as String,
            (f['tmdb_id'] as num).toInt(),
          ),
      };
      _puanlar
        ..clear()
        ..addAll(yeniPuan);
      _favoriler
        ..clear()
        ..addAll(yeniFavori);
      surum.value++;
    } catch (_) {
      // sessiz: satırlar puansız çizilir
    } finally {
      _yukleniyor = false;
    }
  }

  /// Çıkışta temizlenir; başka hesap önceki puanları görmesin.
  static void temizle() {
    if (_puanlar.isEmpty && _favoriler.isEmpty) return;
    _puanlar.clear();
    _favoriler.clear();
    surum.value++;
  }
}
