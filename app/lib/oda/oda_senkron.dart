/// İZLEME ODASI — SENKRON MATEMATİĞİ (saf, Flutter'sız, test edilebilir).
///
/// ===========================================================================
/// NEDEN AYRI VE SAF DOSYA
/// ===========================================================================
/// Burada tek bir `import 'package:flutter/...'` yok. Sebep `video_kova.dart`
/// ve `gonderi_olcu.dart` ile aynı: kenar durumları (saat kayması, duraklatma
/// anında gelen yanıt, sonuna gelmiş video, ağır ağ turu) ancak SAF bir
/// fonksiyon olarak sınanabilir — widget testine gerçek bir video dosyası ve
/// gerçek bir sunucu sokmadan. Testler: `test/oda_senkron_test.dart`.
///
/// ===========================================================================
/// TASARIMIN TEK KRİTİK FİKRİ — DUVAR SAATİ
/// ===========================================================================
/// Sunucu "video ŞU AN nerede" değil, "video ŞU ANDA şuradaydı" tutar:
/// (`oynuyor`, `konumMs`, `konumZaman`). Beklenen konumu izleyici KENDİSİ
/// türetir:
///
///     beklenen = konumMs + (oynuyor ? (sunucuŞimdi - konumZaman) * hız : 0)
///
/// Böylece **yoklama gecikmesi senkronu bozmaz**: yanıt 1 saniye geç gelse
/// bile `konumZaman` o saniyeyi zaten içerir. Sunucu yalnız `konumMs`
/// gönderseydi her izleyici sistematik olarak bir yoklama turu geride kalırdı
/// ve bu gecikme HİÇBİR ZAMAN kapanmazdı (her turda yeniden oluşur).
///
/// Sunucudaki eşi: `backend/oda.js` içindeki `beklenenKonum`. **İki kopya
/// birlikte değiştirilmelidir**; `backend/test/oda.test.js` bu dosyanın
/// formülü taşıdığını ayrıca denetler.
library;

/// Fark bu eşiğin altındaysa HİÇBİR ŞEY yapılmaz.
///
/// 250 ms insan algısının altındadır ve sürekli düzeltme yapmak oynatıcıyı
/// titretir (her `seek` bir tampon boşaltmadır). Eşiksiz bir düzeltici
/// mükemmel senkronda bile saniyede bir seek atardı.
const int kucukFarkMs = 250;

/// Bu eşiğe kadar hız ayarıyla, üstünde SEEK ile kapatılır.
///
/// 3 saniyelik bir farkı %7 hızla kapatmak ~43 saniye sürer — kabul edilebilir
/// ve GÖRÜNMEZ. 10 saniyelik farkı kapatmak 2,5 dakika sürerdi; orada sarma
/// (görünür ama TEK seferlik) daha dürüst.
const int yumusakFarkMs = 3000;

/// Yumuşak düzeltmede kullanılan hız sapması (%7).
///
/// Ses perdesi %7'de fark edilmez (video_player `setPlaybackSpeed` sesi de
/// hızlandırır). %20 denenseydi konuşma "cıvık" duyulurdu.
const double hizSapmasi = 0.07;

/// Sahip oynatırken konumunu bu sıklıkla tazeler (kalp atışı).
///
/// Sürüm ARTMAZ (`kalp: true`) — yoksa izleyiciler her 10 saniyede bir seek
/// eder ve düzgün akan video zıplardı. Amaç yalnız `konumZaman`ı tazelemek:
/// sahibin oynatıcısı gerçekte biraz yavaş/hızlı akıyorsa (tampon duraklaması,
/// cihaz yükü) bu tazeleme onu geri hizalar.
const Duration sahipKalpAraligi = Duration(seconds: 10);

/// Odanın yoklama sıklığı — sohbetle aynı (`sohbetYoklamaAraligi`).
const Duration odaYoklamaAraligi = Duration(seconds: 1);

/// Odanın oynatma durumunun anlık görüntüsü (sunucudan geldiği gibi).
class OdaDurum {
  final bool oynuyor;
  final int konumMs;

  /// Konumun ölçüldüğü an — **SUNUCU saatinde**, epoch ms.
  final int konumZaman;
  final double hiz;

  /// Her KASITLI değişimde artar (oynat/duraklat/sar/video değişti).
  final int surum;

  const OdaDurum({
    required this.oynuyor,
    required this.konumMs,
    required this.konumZaman,
    required this.surum,
    this.hiz = 1.0,
  });

  static const bos = OdaDurum(
    oynuyor: false,
    konumMs: 0,
    konumZaman: 0,
    surum: 0,
  );

  factory OdaDurum.json(Map<String, dynamic> d, {int surum = 0}) => OdaDurum(
    oynuyor: d['oynuyor'] == true,
    konumMs: (d['konum_ms'] as num?)?.toInt() ?? 0,
    konumZaman: (d['konum_zaman'] as num?)?.toInt() ?? 0,
    hiz: (d['hiz'] as num?)?.toDouble() ?? 1.0,
    surum: surum,
  );
}

/// Verilen SUNUCU anında videonun olması gereken konumu.
///
/// [sunucuSimdi] sunucu saatinde epoch ms — yerel saatten [SaatSapmasi] ile
/// türetilir. [sureMs] biliniyorsa konum ona kırpılır (videonun sonunu geçen
/// bir hedefe seek etmek oynatıcıyı başa sardırabilir).
int beklenenKonum(OdaDurum durum, int sunucuSimdi, {int? sureMs}) {
  var v = durum.konumMs;
  if (durum.oynuyor) {
    final hiz = durum.hiz > 0 ? durum.hiz : 1.0;
    // Negatif geçen süre 0 sayılır: bozuk bir `konumZaman` (ya da sapma
    // ölçümü henüz oturmamışken) videoyu GERİ ÇEKMEMELİ.
    final gecen = sunucuSimdi - durum.konumZaman;
    v += (gecen > 0 ? gecen * hiz : 0).round();
  }
  if (v < 0) v = 0;
  if (sureMs != null && sureMs > 0 && v > sureMs) v = sureMs;
  return v;
}

/// Yerel oynatıcının ne yapması gerektiği.
enum DuzeltmeTuru {
  /// Fark önemsiz: hız 1,0'a çekilir ve bırakılır.
  yok,

  /// Küçük fark: hız hafifçe artırılır/azaltılır, kayıp görünmeden kapanır.
  hiz,

  /// Büyük fark ya da KASITLI eylem (sürüm atladı): doğrudan sar.
  sar,
}

/// Düzeltme kararı: ne yapılacak ve (hız düzeltmesiyse) hangi hızla.
class Duzeltme {
  final DuzeltmeTuru tur;

  /// [DuzeltmeTuru.hiz] için uygulanacak oynatma hızı; ötekilerde 1,0.
  final double hiz;

  /// [DuzeltmeTuru.sar] için hedef konum.
  final int hedefMs;

  /// Beklenen − yerel (pozitif = geridesin). Günlük/teşhis için.
  final int farkMs;

  const Duzeltme(
    this.tur, {
    this.hiz = 1.0,
    this.hedefMs = 0,
    required this.farkMs,
  });
}

/// Yerel oynatıcı konumunu beklenen konuma yaklaştırma kararı.
///
/// [kasitli] — sunucudaki `surum` atladıysa true. O zaman merdiven ATLANIR ve
/// DOĞRUDAN sarılır: kullanıcı isteği aynen böyleydi — *"oda sahibi 10 saniye
/// ileri sararsa izleyenlerde de ileri sarılmalı"*. Yumuşak düzeltmeye
/// bırakılsaydı 10 saniyelik sarma izleyicide ~2,5 dakikada kapanırdı, yani
/// pratikte hiç olmamış görünürdü.
Duzeltme duzeltmeKarari(int yerelMs, int beklenenMs, {bool kasitli = false}) {
  final fark = beklenenMs - yerelMs;
  if (kasitli) {
    return Duzeltme(DuzeltmeTuru.sar, hedefMs: beklenenMs, farkMs: fark);
  }
  final mutlak = fark.abs();
  if (mutlak <= kucukFarkMs) return Duzeltme(DuzeltmeTuru.yok, farkMs: fark);
  if (mutlak <= yumusakFarkMs) {
    // Geride kaldıysak HIZLAN, ilerideysek YAVAŞLA.
    return Duzeltme(
      DuzeltmeTuru.hiz,
      hiz: fark > 0 ? 1.0 + hizSapmasi : 1.0 - hizSapmasi,
      farkMs: fark,
    );
  }
  return Duzeltme(DuzeltmeTuru.sar, hedefMs: beklenenMs, farkMs: fark);
}

/// Yerel saat ile sunucu saati arasındaki sapmayı ölçer.
///
/// ===========================================================================
/// NEDEN GEREKLİ
/// ===========================================================================
/// `beklenenKonum` SUNUCU saatinde bir an ister. Telefonun saati sunucununkiyle
/// aynı olmak zorunda değil — elle ayarlanmış, saat dilimi/yaz saati güncellemesi
/// gecikmiş ya da uykudan yeni uyanmış bir cihazda dakikalarca sapabilir.
/// Sapma ölçülmezse video o sapma kadar ileri/geri oynar.
///
/// ===========================================================================
/// NEDEN "EN KÜÇÜK RTT KAZANIR"
/// ===========================================================================
/// Her ölçüm `sapma = sunucuZaman + rtt/2 - yerelBitiş` verir. `rtt/2`
/// varsayımı yolun simetrik olduğunu kabul eder; yavaş bir turda (ağ tıkandı,
/// istek kuyrukta bekledi) bu varsayım kötü bozulur. NTP'nin de kullandığı
/// çözüm: ölçümleri ORTALAMA — çünkü ortalama, tek bir kötü turdan zehirlenir.
/// En KÜÇÜK gidiş-dönüşlü ölçüm en az gürültülüdür; onu tut.
///
/// [kayma] ile eski en-iyi ölçüm zamanla unutulur: bağlantı kalıcı olarak
/// yavaşladıysa (Wi-Fi'dan hücresele geçiş) 2 dakika önceki "şanslı" tur
/// sonsuza dek en iyi kalmamalı.
class SaatSapmasi {
  int? _sapmaMs;
  int _enIyiRtt = 1 << 30;
  int _olcumZamani = 0;

  /// En iyi ölçümün unutulma süresi.
  static const Duration kayma = Duration(minutes: 2);

  /// Ölçüm var mı (yoksa yerel saat sapmasız kabul edilir).
  bool get olculdu => _sapmaMs != null;

  /// Ölçülen sapma (ms): `sunucu - yerel`.
  int get sapmaMs => _sapmaMs ?? 0;

  /// Son turun gidiş-dönüş süresi (ms) — teşhis için.
  int get rttMs => _enIyiRtt == 1 << 30 ? 0 : _enIyiRtt;

  /// Bir yanıttan ölçüm besler.
  ///
  /// [istekBasi] / [yanitSonu] yerel saatte epoch ms, [sunucuZaman] sunucunun
  /// yanıtta bildirdiği epoch ms.
  void besle({
    required int istekBasi,
    required int yanitSonu,
    required int sunucuZaman,
  }) {
    final rtt = yanitSonu - istekBasi;
    // Negatif RTT (saat isteğin ortasında değişti) ölçümü zehirler.
    if (rtt < 0) return;
    final eskidi =
        _olcumZamani != 0 && yanitSonu - _olcumZamani > kayma.inMilliseconds;
    if (_sapmaMs != null && rtt > _enIyiRtt && !eskidi) return;
    _enIyiRtt = rtt;
    _olcumZamani = yanitSonu;
    _sapmaMs = sunucuZaman + (rtt ~/ 2) - yanitSonu;
  }

  /// Yerel epoch ms'yi sunucu saatine çevirir.
  int sunucuAni(int yerelMs) => yerelMs + sapmaMs;
}
