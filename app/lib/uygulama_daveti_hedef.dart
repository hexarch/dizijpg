/// Uygulama indirme davetinin HEDEFİ — hangi mağaza(lar) gösterilecek.
///
/// Tespit web'de tarayıcıdan yapılır (`uygulama_daveti_web.dart`); native
/// derlemelerde davet HİÇ gösterilmez (`uygulama_daveti_yok.dart`), çünkü
/// uygulama zaten kurulu.
enum DavetHedefi {
  /// Davet gösterilmez: masaüstü tarayıcı, bot, ana ekrana eklenmiş PWA
  /// ya da native derleme.
  yok,

  /// Android tarayıcı (telefon veya tablet) → Google Play.
  android,

  /// iPhone / iPad (iPadOS 13+ masaüstü kimliği dahil) → App Store.
  ios,

  /// Mobil ama platform BİLİNMİYOR → kullanıcı seçsin diye iki mağaza da.
  ikisi,
}

/// Davet penceresindeki mağaza düğmeleri.
enum DavetMagaza {
  play('https://play.google.com/store/apps/details?id=com.dizijpg.dizijpg'),
  appStore('https://apps.apple.com/app/id6806987135');

  const DavetMagaza(this.adres);

  /// Mağaza kaydının adresi. App Store adresi ülke önekSİZ verilir: Apple
  /// ziyaretçiyi kendi ülkesine 301'ler (ölçüldü: /tr/app/dizi-jpg/id6806987135).
  final String adres;
}
