import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// Etiket seçicisinin (icerik_sec.dart) "son aradıkların" listesi.
///
/// KULLANICI İSTEĞİ (3 Eyl 2026): *"en son aradığım yapımlar listelensin
/// arama yapmadan; mesela Breaking Bad seçtim ekledim, tekrar etiket ekle
/// dediğimde geçmiş arama kısmında Breaking Bad'in firması, yönetmeni,
/// oyuncuları olsun."*
///
/// İKİ KATMAN, TEK LİSTE:
///   1. kullanıcının SEÇTİĞİ kayıt (dizi/film/kişi/firma) — en başa;
///   2. seçilen bir dizi/filmse onun İLGİLİLERİ — yapım firmaları, yaratıcı/
///      yönetmen ve başroller — hemen onun ardına, `ilgili` alanında ana
///      yapımın adıyla (listede "Breaking Bad · Oyuncu" diye yazar).
/// İlgililer TMDB detayından gelir (`/tmdb/tv/:id` — sunucu `credits`i zaten
/// ekliyor, ayrı uç yok). Seçim ANINDA kaydedilir, ilgililer ardından
/// arka planda eklenir: seçici çoktan kapanmış olur, kullanıcı bölüm düzeyini
/// seçerken istek biter; seçici yeniden açıldığında liste hazırdır.
///
/// KAYIT BİÇİMİ: TMDB arama sonucuyla AYNI şekil (`media_type`, `id`,
/// `name`/`title`, görsel yolu). Seçici bunları arama sonucu gibi çizer ve
/// aynı `Navigator.pop(r)` sözleşmesiyle döndürür — `PaylasimEtiketi.tmdb`
/// değişmeden çalışır. Yalnız gerekli alanlar tutulur (arama sonucunun tüm
/// gövdesini saklamak tercih dosyasını şişirirdi).
///
/// SINIR: [azami] kayıt. Aynı kayıt (tür+id) yeniden seçilince başa taşınır,
/// ilgilileri tazelenir; eski kopyası silinir.
class EtiketGecmisi {
  static const anahtar = 'etiket_gecmisi';
  static const azami = 40;

  /// Bir yapımdan alınacak başrol sayısı.
  static const oyuncuSayisi = 5;

  /// Test/sahte için: gerçek TMDB isteği yerine geçer.
  static Future<dynamic> Function(String yol) getir = Api.get;

  static Future<List<Map<String, dynamic>>> oku() async {
    try {
      final p = await SharedPreferences.getInstance();
      final ham = p.getString(anahtar);
      if (ham == null || ham.isEmpty) return const [];
      final liste = jsonDecode(ham);
      if (liste is! List) return const [];
      return [
        for (final r in liste)
          if (r is Map) Map<String, dynamic>.from(r),
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> temizle() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(anahtar);
    } catch (_) {}
  }

  /// Seçilen kaydı başa yazar; dizi/filmse ilgililerini ardına ekler.
  /// Dönen future ilgililer de yazılınca tamamlanır (çağıran beklemek
  /// zorunda değil — seçici `unawaited` bırakır).
  static Future<void> kaydet(Map<String, dynamic> secim) async {
    final ana = sadelestir(secim);
    if (ana == null) return;
    // İlk yazım: yalnız ana kayıt başa gelir, ESKİ ilgilileri (varsa) durur —
    // detay isteği düşerse eldekiler kaybolmasın.
    await _yaz(_birlestir(await oku(), [ana], ilgilileriDusur: false));
    final tur = ana['media_type'];
    if (tur != 'tv' && tur != 'movie') return;
    Map<String, dynamic> detay;
    try {
      final d = await getir('/tmdb/$tur/${ana['id']}');
      if (d is! Map) return;
      detay = Map<String, dynamic>.from(d);
    } catch (_) {
      return; // ilgililer olmadan da geçmiş işe yarar
    }
    final ilgili = ilgililer(detay, tur as String, ana['name'] as String);
    if (ilgili.isEmpty) return;
    // Ana kayıt yine başta; ilgililer hemen ardında. Bu arada başka bir
    // seçim yazılmış olabilir — yeniden okuyup birleştiriyoruz.
    await _yaz(_birlestir(await oku(), [ana, ...ilgili]));
  }

  /// TMDB kaydını geçmiş biçimine indirger. Adsız kayıt → null.
  static Map<String, dynamic>? sadelestir(Map<String, dynamic> r) {
    final tur = r['media_type'];
    final id = r['id'];
    final ad = r['name'] ?? r['title'];
    if (tur is! String || id is! int || ad is! String || ad.isEmpty) {
      return null;
    }
    final gorsel = r['poster_path'] ?? r['profile_path'] ?? r['logo_path'];
    return {
      'media_type': tur,
      'id': id,
      'name': ad,
      // Görsel alanı TÜRE GÖRE: seçici `tmdbGorselYolu` ile okur.
      if (gorsel is String)
        switch (tur) {
          'person' => 'profile_path',
          'company' => 'logo_path',
          _ => 'poster_path',
        }: gorsel,
      if (r['ilgili'] is String) 'ilgili': r['ilgili'],
      if (r['rol'] is String) 'rol': r['rol'],
    };
  }

  /// Detaydan ilgililer: firmalar → yaratıcı/yönetmen → başroller.
  /// Saf; testte sahte detayla sınanır.
  static List<Map<String, dynamic>> ilgililer(
    Map<String, dynamic> detay,
    String tur,
    String anaAd,
  ) {
    final sonuc = <Map<String, dynamic>>[];
    final gorulen = <String>{};
    void ekle(dynamic r, String mediaType, String rol) {
      if (r is! Map) return;
      final m = Map<String, dynamic>.from(r)
        ..['media_type'] = mediaType
        ..['ilgili'] = anaAd
        ..['rol'] = rol;
      final s = sadelestir(m);
      if (s == null) return;
      if (!gorulen.add('$mediaType:${s['id']}')) return;
      sonuc.add(s);
    }

    for (final f in detay['production_companies'] as List? ?? const []) {
      ekle(f, 'company', 'firma');
    }
    if (tur == 'tv') {
      for (final k in detay['created_by'] as List? ?? const []) {
        ekle(k, 'person', 'yaratici');
      }
    }
    final krediler = detay['credits'];
    if (krediler is Map) {
      for (final k in krediler['crew'] as List? ?? const []) {
        if (k is Map && k['job'] == 'Director') ekle(k, 'person', 'yonetmen');
      }
      final oyuncular =
          (krediler['cast'] as List? ?? const []).whereType<Map>().toList()
            ..sort(
              (a, b) => ((a['order'] ?? 999) as int).compareTo(
                (b['order'] ?? 999) as int,
              ),
            );
      for (final o in oyuncular.take(oyuncuSayisi)) {
        ekle(o, 'person', 'oyuncu');
      }
    }
    return sonuc;
  }

  /// [yeni] başa; eskilerden aynı tür+id'liler ve eski ilgilileri (aynı
  /// `ilgili` adıyla) düşer; [azami] ile kırpılır.
  static List<Map<String, dynamic>> _birlestir(
    List<Map<String, dynamic>> eski,
    List<Map<String, dynamic>> yeni, {
    bool ilgilileriDusur = true,
  }) {
    String k(Map<String, dynamic> r) => '${r['media_type']}:${r['id']}';
    final yeniAnahtarlar = yeni.map(k).toSet();
    final anaAd = yeni.first['name'];
    final kalan = eski.where(
      (r) =>
          !yeniAnahtarlar.contains(k(r)) &&
          (!ilgilileriDusur || r['ilgili'] != anaAd),
    );
    return [...yeni, ...kalan].take(azami).toList();
  }

  static Future<void> _yaz(List<Map<String, dynamic>> liste) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(anahtar, jsonEncode(liste));
    } catch (_) {}
  }
}
