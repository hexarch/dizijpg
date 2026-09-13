// Bildirim satırının İKONU + METNİ — TEK KAYNAK.
//
// NEDEN AYRI DOSYA: aynı cümleler artık İKİ yüzeyde yazılıyor —
//  1) `/bildirimler` listesi (ekranlar/bildirimler.dart),
//  2) uygulama içi anlık pencere (anlik_bildirim.dart, 13 Eyl 2026).
// Metin ekranın içinde private kalsaydı pencere kendi kopyasını taşırdı:
// 45 dilin çeviri anahtarları iki yerde ayrışır, yeni bir bildirim türü
// eklendiğinde biri güncellenip diğeri unutulurdu.
//
// ÇEVİRİ: cümleler `.c` / `.cf` ile ÇALIŞMA ZAMANINDA seçili dile çevrilir —
// bu yüzden fonksiyon `const` bir haritaya indirgenemez.
import 'package:flutter/material.dart';

import 'ceviri.dart';

/// "S5B3" etiketi — `S{}B{}` anahtarı ZATEN VAR (bölüm yorumlarında
/// kullanılıyor), yeni çeviri anahtarı açılmadı.
String bildirimSezonBolum(Map<String, dynamic> b) =>
    'S{}B{}'.cf([b['sezon'], b['bolum']]);

/// Bildirim satırının (ikon, metin) görünümü.
///
/// [b] hem `/bildirimler` satırı hem `/bildirimler/canli` satırı olabilir —
/// alan adları aynıdır. `begenenler` YALNIZ listede doludur (gönderi başına
/// gruplanan beğeniler); pencerede tek beğeni gelir ve alt dala düşer.
(IconData, String) bildirimGorunumu(Map<String, dynamic> b) {
  switch (b['tur'] as String?) {
    case 'yanit':
      return (Icons.reply, '@{} yorumuna yanıt verdi'.cf([b['aktor']]));
    case 'etiket':
      return (
        Icons.alternate_email,
        '@{} bir yorumda seni etiketledi'.cf([b['aktor']]),
      );
    case 'begeni':
      // Gruplu satır: son iki beğenen adla, kalanı sayıyla yazılır
      // ("@alcelik ve @melisa" / "@alcelik, @melisa ve 10 kişi").
      final grup = (b['begenenler'] as List?)?.cast<Map<String, dynamic>>();
      if (grup != null && grup.length == 2) {
        return (
          Icons.favorite,
          '{} ve {} yorumunu beğendi'.cf([
            '@${grup[0]['ad']}',
            '@${grup[1]['ad']}',
          ]),
        );
      }
      if (grup != null && grup.length > 2) {
        return (
          Icons.favorite,
          '{} ve {} kişi yorumunu beğendi'.cf([
            '@${grup[0]['ad']}, @${grup[1]['ad']}',
            grup.length - 2,
          ]),
        );
      }
      return (Icons.favorite, '@{} yorumunu beğendi'.cf([b['aktor']]));
    case 'takip':
      return (Icons.person_add, '@{} seni takip etti'.cf([b['aktor']]));
    // GİZLİ HESAP (8 Eyl 2026): istek satırının sağında Onayla/Sil
    // düğmeleri var (_istekDugmeleri); dokunuş isteyenin profilini açar.
    case 'takip_istegi':
      return (
        Icons.person_add_alt_1,
        '@{} seni takip etmek istiyor'.cf([b['aktor']]),
      );
    case 'takip_kabul':
      return (
        Icons.how_to_reg,
        '@{} takip isteğini kabul etti'.cf([b['aktor']]),
      );
    case 'mesaj':
      return (Icons.mail, '@{} sana mesaj gönderdi'.cf([b['aktor']]));
    // 4 Eyl 2026 — İZLEME ODASI DAVETİ. Aktörlü tür: davet edenin avatarı
    // solda durur, köşedeki mini ikon eylemi anlatır.
    case 'oda_davet':
      return (
        Icons.groups_2_outlined,
        '@{} seni izleme odasına davet etti'.cf([b['aktor']]),
      );
    case 'kacirilan_arama':
      // METİN "Cevapsız arama" (YENİ ANAHTAR AÇILMADI): anahtar gelen arama
      // ekranında zaten var ve 45 dile çevrili. Kimin aradığı pencerenin
      // BAŞLIK satırında (@ad) yazdığı için cümleye ikinci kez girmesi
      // gerekmiyor.
      return (Icons.call_missed, 'Cevapsız arama'.c);
    case 'bolum':
      // Aktörsüz bildirim: "@" ile başlayan kalıba GİRMEZ, dizi adını yazar.
      // Dizi adı sunucudan gelmezse (TMDB önbelleği ıskaladı) sayı biçimi
      // tek başına anlamlı kalsın diye ad yerine "Yeni bölüm" denir.
      return (
        Icons.new_releases_outlined,
        (b['dizi_adi'] as String?)?.isNotEmpty == true
            ? '{} {} yayınlandı'.cf([b['dizi_adi'], bildirimSezonBolum(b)])
            : 'Yeni bölüm yayınlandı'.c,
      );
    // 28 Ağu 2026 — GERİ BİLDİRİM YANITI. Üçüncü aktörsüz tür: gönderen
    // SİTEDİR, bir kullanıcı değil; '@' kalıbına GİRMEZ.
    case 'geri_bildirim':
      return (
        Icons.mark_email_read_outlined,
        'Geri bildirimine yanıt verdik'.c,
      );
    // 2 Eyl 2026 — SÜRÜM DUYURUSU. Aktörsüz dördüncü tür: gönderen SİTEDİR,
    // '@' kalıbına GİRMEZ. Dokununca /yenilikler/<surum> tanıtım sayfası.
    case 'surum':
      return (Icons.auto_awesome, 'dizi.jpg {} yayında'.cf([b['surum'] ?? '']));
    case 'kisi':
      // Md. 28 — aktörsüz ikinci tür. Adlar TMDB'den gelir ve KULLANICI ADI
      // DEĞİLDİR: "@" kalıbına GİRMEZ. Sunucu TMDB'den ad çekemediyse
      // (önbellek ıskaladı) yarım cümle basmak yerine yedek metin yazılır.
      final kisiAdi = b['kisi_adi'] as String?;
      final yapimAdi = b['yapim_adi'] as String?;
      return (
        Icons.theaters_outlined,
        (kisiAdi?.isNotEmpty == true && yapimAdi?.isNotEmpty == true)
            ? '{} yeni bir yapımda: {}'.cf([kisiAdi, yapimAdi])
            : 'Favori kişinden yeni yapım'.c,
      );
    default:
      return (Icons.notifications, '@${b['aktor']}');
  }
}
