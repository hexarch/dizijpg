// Bildirime dokunulunca GİDİLECEK YER — saf kural, platformsuz.
//
// NEDEN AYRI DOSYA (13 Eyl 2026): kural eskiden `push.dart` içindeydi, o dosya
// ise `dart:io` ve Firebase eklentilerini çekiyor. Uygulama içi anlık bildirim
// penceresi (anlik_bildirim.dart) WEBDE de aynı hedefi hesaplamak zorunda —
// yani kuralın Firebase'siz bir yerde durması gerekiyordu. Davranış aynen
// korundu; `push.dart` bu dosyayı yeniden yayımlıyor.
import 'yonlendirme.dart';

/// Bildirim verisindeki bir alanı METİN olarak okur.
///
/// NEDEN `as String?` DEĞİL: FCM `data` değerleri kablo üzerinde hep metindir
/// ama aynı çözümleyici YEREL bildirim yükünü de (kendi ürettiğimiz JSON) ve
/// ileride sunucunun sayı gönderebileceği alanları da okuyor —
/// `/bildirimler` uçları `sezon`/`bolum`u SAYI döndürüyor. Sert dönüşüm o
/// durumda `TypeError` fırlatır; `onMessageOpenedApp` dinleyicisinde bu hata
/// yakalanmaz ve bildirime dokunmak hiçbir yere GİTMEZ. Metne çevirmek her iki
/// biçimi de doğru çalıştırır.
String _alan(Map<String, dynamic> veri, String anahtar) {
  final deger = veri[anahtar];
  return deger == null ? '' : '$deger'.trim();
}

/// Bildirim verisinin götüreceği YOL; gidilecek yer yoksa `null`.
///
/// AYRI FONKSİYON: gezinmenin kendisi ([rotayaGit]) canlı bir GoRouter ister,
/// hedef HESABI istemez — böylece kural testten doğrudan okunabiliyor.
///
/// `@visibleForTesting` DEĞİL (13 Eyl 2026): kural artık ÜRETİMDE de iki
/// yerden okunuyor — `push.dart` (FCM dokunuşu) ve `anlik_bildirim.dart`
/// (uygulama içi pencere). İşaret kalsaydı her çağrı bir analiz uyarısı
/// üretirdi.
String? bildirimHedefi(Map<String, dynamic> veri) {
  final tur = _alan(veri, 'tur');
  final ad = _alan(veri, 'ad');
  switch (tur) {
    case 'arama':
      // Teklif SDP'si bildirimde YOK (FCM veri sınırı 4 KB, SDP 64 KB'a
      // kadar): ekran açılınca `GET /arama/gelen` ile çekilir.
      return gelenAramaYolu;
    case 'kacirilan_arama':
      // Kaçırılan aramada doğal eylem geri aramaktır; sohbet ekranında arama
      // düğmeleri zaten duruyor.
      return ad.isEmpty ? null : '/sohbet/$ad';
    case 'mesaj':
      return ad.isEmpty ? null : '/sohbet/$ad';
    case 'takip':
      return ad.isEmpty ? null : '/kullanici/$ad';
    // GİZLİ HESAP (8 Eyl 2026): istek kararı bildirim listesinde verilir;
    // kabul haberi ise kabul edenin profiline götürür.
    case 'takip_istegi':
      return '/bildirimler';
    case 'takip_kabul':
      return ad.isEmpty ? null : '/kullanici/$ad';
    case 'bolum':
      // Md. 27 — yeni bölüm: doğrudan bölüm sayfasına. Alanlar FCM data'sında
      // STRING gelir; biri eksikse bildirim listesine düş (yanlış rotaya
      // gitmektense liste güvenli).
      final tmdb = _alan(veri, 'tmdb_id');
      final sezon = _alan(veri, 'sezon');
      final bolum = _alan(veri, 'bolum');
      return tmdb.isNotEmpty && sezon.isNotEmpty && bolum.isNotEmpty
          ? '/dizi/$tmdb/sezon/$sezon/bolum/$bolum'
          : '/bildirimler';
    case 'kisi':
      // Md. 28 — favori kişinin yeni yapımı: doğrudan YAPIMIN sayfasına.
      // `icerik_tur` OLMADAN adres kurulamaz (TMDB'de dizi 1396 ile film 1396
      // ayrı yapımlardır); tür beklenmedik bir değerse yanlış sayfa açmaktansa
      // bildirim listesine düşülür.
      final icerikTur = _alan(veri, 'icerik_tur');
      final yapimId = _alan(veri, 'tmdb_id');
      return (icerikTur == 'tv' || icerikTur == 'movie') && yapimId.isNotEmpty
          ? '/icerik/$icerikTur/$yapimId'
          : '/bildirimler';
    case 'begeni' || 'yanit' || 'etiket':
      // yorum_id varsa doğrudan o gönderiye; yoksa bildirim listesine
      final yorumId = _alan(veri, 'yorum_id');
      return yorumId.isEmpty
          ? '/bildirimler'
          // Yanıt bildiriminde id YANITIN kendisidir: ekran üst gönderiyi
          // çözüp normal yorum ekranını açsın (md.15, bkz. [gonderiYolu]).
          : gonderiYolu(yorumId, yanit: tur == 'yanit');
    case 'surum':
      // Sürüm duyurusu (2 Eyl 2026): dokununca yeniliklerin tanıtım sayfası.
      // Sürüm eksik/bozuksa bildirim listesine düş (yanlış rota açmaktansa
      // liste güvenli — bolum/kisi ile aynı kural).
      final surum = _alan(veri, 'surum');
      return RegExp(r'^\d+\.\d+\.\d+$').hasMatch(surum)
          ? '/yenilikler/$surum'
          : '/bildirimler';
    case 'oda_davet':
      // İzleme odası daveti (4 Eyl 2026). Kullanıcı bildirdi: "bildirime
      // tıklayınca oda açılmıyor" — KÖK SEBEP bu switch'te 'oda_davet'
      // vakasının HİÇ OLMAMASIYDI; hedef null dönüyor ve dokunuş hiçbir yere
      // gitmiyordu. Sunucu tarafı doğruydu (FCM data'sında `oda_id` var).
      //
      // id sayısal değilse bildirim listesine düş — bolum/kisi/surum ile AYNI
      // güvenli kural (yanlış rota açmaktansa liste).
      final odaId = _alan(veri, 'oda_id');
      return RegExp(r'^\d+$').hasMatch(odaId) ? '/oda/$odaId' : '/bildirimler';
  }
  return null;
}
