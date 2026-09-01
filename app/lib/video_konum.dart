/// AKIŞ ↔ REELS VİDEO KONUM DEFTERİ (1 Eyl 2026 isteği).
///
/// SORUN: akış kartındaki video, Reels'e geçince BAŞTAN başlıyordu; Reels'ten
/// dönünce akış kartı da kaldığı yeri bilmiyordu. Her oynatıcı
/// (`AkisVideo`, `_ReelSayfa`, `_KesfetKutusu`) kendi denetleyicisini sıfırdan
/// kurar — denetleyiciyi PAYLAŞMAK yerine yalnız KONUM paylaşılır:
///
///  * Denetleyici paylaşımı cazip görünse de ömür yönetimi kırılgandır: akış
///    kartı sessiz, Reels sesli oynar; biri dispose edince öbürü kör kalırdı.
///    Konum paylaşımı ise iki tarafta da tek `seekTo` — kurulum maliyeti
///    (ağdan ilk parça) zaten Reels açılışında ödeniyor.
///  * Defter OTURUM BOYU yaşar, diske yazılmaz: "kaldığın yerden" güvencesi
///    yalnız aynı oturumdaki geçişler için anlamlı; günler sonra açılan bir
///    gönderinin ortasından başlamak şaşırtırdı.
///
/// KİM YAZAR: oynayan HER oynatıcı, konum dinleyicisinde ([yaz]). Aynı anda
/// tek video oynadığı için (akışta merkez seçimi, Reels'te aktif sayfa)
/// yazanlar çakışmaz.
///
/// KİM OKUR: oynatıcı kurulurken ve oynamaya başlarken ([devral]). Kayıtlı
/// konum, oynatıcının kendi konumundan [esik]ten fazla ayrıysa `seekTo`
/// hedefi döner; değilse null — böylece normal akış kaydırmasında (konumlar
/// zaten eş) gereksiz sarma olmaz.
library;

import 'package:flutter/foundation.dart' show visibleForTesting;

class VideoKonumDefteri {
  VideoKonumDefteri._();

  /// Hafıza sınırı: en eski kayıt düşer. Bir kayıt yalnız bir `Duration`
  /// olduğu için sınır cömert; 100 video geriye dönmek pratikte olmuyor.
  static const int sinir = 100;

  /// Devralma eşiği: bundan yakın konumlar "zaten aynı yer" sayılır.
  /// Küçük tutulsa her oynatışta yarım saniyelik ileri-geri sarmalar olurdu;
  /// büyük tutulsa kısa videolarda süreklilik hissi kaybolurdu.
  static const Duration esik = Duration(milliseconds: 800);

  /// URL → son bilinen oynatma konumu. `LinkedHashMap` (varsayılan) ekleme
  /// sırasını korur; [yaz] kaydı sona taşır, sınır aşılınca baştaki (en eski)
  /// düşer — küçük bir LRU.
  static final Map<String, Duration> _konumlar = <String, Duration>{};

  /// Oynayan videonun konumunu kaydeder. Süre bilinmiyorsa (hazırlanma anı)
  /// yazılmaz — sıfır süreli "konum" devralınınca ilk kareye sarardı.
  static void yaz(String url, Duration konum, Duration sure) {
    if (sure <= Duration.zero || konum < Duration.zero) return;
    _konumlar.remove(url); // sona taşı (tazelik sırası)
    _konumlar[url] = konum;
    if (_konumlar.length > sinir) _konumlar.remove(_konumlar.keys.first);
  }

  /// Kayıtlı konum [mevcut]tan [esik]ten fazla ayrıysa `seekTo` hedefi,
  /// değilse null (sarma gereksiz ya da kayıt yok).
  static Duration? devral(String url, Duration mevcut) {
    final kayit = _konumlar[url];
    if (kayit == null) return null;
    return (kayit - mevcut).abs() > esik ? kayit : null;
  }

  @visibleForTesting
  static void temizle() => _konumlar.clear();

  @visibleForTesting
  static int get kayitSayisi => _konumlar.length;
}
