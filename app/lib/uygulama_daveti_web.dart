import 'package:web/web.dart' as web;

import 'uygulama_daveti_hedef.dart';

/// Mobil/tablet tarayıcıyı ve platformunu tarayıcı kimliğinden (user agent)
/// çıkarır.
///
/// NEDEN USER AGENT (ve neden yalnız o değil): platform tespiti için tarayıcıda
/// başka güvenilir kanal yok — `navigator.userAgentData` yalnız Chromium'da var
/// ve mobil markayı `platform` alanında ancak yüksek entropili izinle veriyor.
/// Bu yüzden kimlik dizgesi + `maxTouchPoints` birlikte okunuyor.
///
/// ÜÇ TUZAK:
/// 1. **iPadOS 13+ MASAÜSTÜ GİBİ TANITIYOR:** Safari'nin varsayılan ayarında
///    iPad'in kimliği "Macintosh; Intel Mac OS X" olur, "iPad" GEÇMEZ. Ayırt
///    eden tek işaret `maxTouchPoints > 1` (gerçek Mac'te 0'dır, dokunmatik
///    Mac yok). Bu dal olmazsa iPad kullanıcısı daveti hiç görmez.
/// 2. **BOTLAR:** Googlebot mobil tarama yaparken Android kimliği kullanır.
///    Tarayıcı ekranını bot da görseydi Google'ın "araya giren geçiş sayfası"
///    (intrusive interstitial) ölçütüne takılırdık ve Lighthouse/PageSpeed
///    ölçümü de örtülü katmanla bozulurdu. Bot kimlikleri bu yüzden ELENİR.
/// 3. **ANA EKRANA EKLENMİŞ PWA:** `display-mode: standalone` ise kullanıcı
///    siteyi zaten uygulama gibi kullanıyor; "indir" demek anlamsız.
DavetHedefi davetHedefi() {
  final kimlik = web.window.navigator.userAgent;
  if (kimlik.isEmpty) return DavetHedefi.yok;
  if (_bot.hasMatch(kimlik)) return DavetHedefi.yok;
  if (_ayriUygulamaGibi()) return DavetHedefi.yok;

  // Android ÖNCE: "Linux; Android 14; SM-..." kimliğinde tablet sürümünde
  // "Mobile" geçmez — bu yüzden ölçüt yalnız "android".
  if (_android.hasMatch(kimlik)) return DavetHedefi.android;
  if (_ios.hasMatch(kimlik)) return DavetHedefi.ios;
  if (kimlik.contains('Macintosh') && web.window.navigator.maxTouchPoints > 1) {
    return DavetHedefi.ios;
  }
  // Mobil ama platform tanınmadı (KaiOS, Windows Phone, az bilinen tarayıcılar):
  // kullanıcı seçsin diye iki mağaza da gösterilir.
  if (_mobil.hasMatch(kimlik)) return DavetHedefi.ikisi;
  return DavetHedefi.yok;
}

final _android = RegExp('android', caseSensitive: false);
final _ios = RegExp('iphone|ipad|ipod', caseSensitive: false);
final _mobil = RegExp('mobile|tablet|kaios|phone', caseSensitive: false);

/// Bot/ölçüm aracı kimlikleri. Liste kısa ve GENEL tutuldu: tek tek bot adı
/// saymak yerine ortak kökler (bot/crawl/spider) + ölçüm araçları.
final _bot = RegExp(
  'bot|crawl|spider|slurp|lighthouse|headless|pagespeed|preview|'
  'facebookexternalhit|embedly|whatsapp|telegrambot|discordbot',
  caseSensitive: false,
);

bool _ayriUygulamaGibi() {
  try {
    for (final kip in ['standalone', 'fullscreen', 'minimal-ui']) {
      if (web.window.matchMedia('(display-mode: $kip)').matches) {
        return true;
      }
    }
  } catch (_) {
    // Çok eski tarayıcıda matchMedia patlarsa davet gösterilsin; yutuluyor.
  }
  return false;
}
