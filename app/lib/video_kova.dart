/// VİDEO İZLENME SÜRESİ / ELDE TUTMA ÖLÇÜMÜ (md. 23) — istemci tarafı.
///
/// ===========================================================================
/// NE ÖLÇÜLÜYOR
/// ===========================================================================
/// Videonun süresi 20 EŞİT KOVAYA bölünür (%0, %5, …, %95). Oynatma ilerledikçe
/// ulaşılan en yüksek kova hatırlanır; kart ekrandan çıkınca (ya da oynatıcı
/// bırakılınca) SUNUCUYA TEK İSTEK gider: `{kova: 13}`.
///
/// SANİYEDE OLAY YOK. 30 saniyelik bir videoda da 30 dakikalıkta da GÖRÜNTÜLENME
/// BAŞINA EN FAZLA BİR istek çıkar — bugünkü `/akis/goruldu` ile aynı mertebe.
///
/// ===========================================================================
/// *** GİZLİLİK ***
/// ===========================================================================
/// Gönderilen gövdede KİŞİ YOK: yalnız "şu gönderide bu izleme şu kovaya
/// kadar geldi". Sunucu tabloya (gönderi, kova) → adet yazar; kimin nereye
/// kadar izlediği HİÇBİR YERDE durmaz.
///
/// ===========================================================================
/// NEDEN AYRI DOSYA (ve neden saf fonksiyon)
/// ===========================================================================
/// Kova hesabı üç ekranda paylaşılıyor ve kenar durumları (süre 0, çok kısa
/// video, ileri/geri sarma, döngüye giren video) ancak SAF bir fonksiyon
/// olarak sınanabilir — widget testine gerçek bir video dosyası sokmadan.
/// `cihaz_sinif.js` ve `gonderi_olcu.dart` ile aynı disiplin.
library;

import 'api.dart';

/// Kova sayısı — sunucudaki `VIDEO_KOVA_SAYISI` ile BİREBİR. İkisi kayarsa
/// istemci 0..24 gönderir, sunucu 400 verir ve ölçü sessizce durur.
const int videoKovaSayisi = 20;

/// Oynatma konumunun düştüğü kova (0..19); ölçülemiyorsa null.
///
/// null DÖNEN DURUMLAR ve gerekçeleri:
///  * `sure <= 0`  — oynatıcı henüz süreyi bilmiyor (hazırlanma anı). Sıfıra
///    bölme olurdu; "0. kova" demek de yanlış olurdu çünkü hiçbir şey
///    izlenmedi.
///  * `konum <= 0` — video kuruldu ama OYNAMADI. Bu kişi eğrinin PAYDASINA da
///    girmemeli: elde tutma "başlayanların ne kadarı devam etti" sorusudur,
///    "kaç kart ekranda kuruldu" değil. Akış ilerideki kartları önden kurar;
///    onlar sayılsaydı her videonun eğrisi yapay olarak dibe vururdu.
///
/// Konum süreyi aşarsa (son karede yuvarlama, döngüde sıçrama) SON KOVAYA
/// kırpılır — 20. kova diye bir şey yok.
int? videoKovaHesapla(Duration konum, Duration sure) {
  final s = sure.inMilliseconds;
  final k = konum.inMilliseconds;
  if (s <= 0 || k <= 0) return null;
  final kova = (k * videoKovaSayisi) ~/ s;
  if (kova < 0) return null;
  return kova >= videoKovaSayisi ? videoKovaSayisi - 1 : kova;
}

/// Tek bir İZLEMENİN elde tutma ölçüsü.
///
/// KULLANIM: oynatıcı kurulduğunda bir tane oluştur, konum değiştikçe
/// [guncelle] çağır, `dispose()` içinde [gonder] çağır.
///
/// İKİ GÜVENCE:
///  1. **EN YÜKSEK KOVA DÜŞMEZ.** Geri sarma, baştan başlama ve `setLooping`
///     ile döngüye giren video konumu sıfırlar; ölçü "en uzağa nereye gidildi"
///     sorusunun cevabıdır, o yüzden yalnız BÜYÜR.
///  2. **TEK GÖNDERİM.** [gonder] kaç kez çağrılırsa çağrılsın istek BİR KEZ
///     çıkar. Widget ağacında `dispose` ile "oynatma bitti" aynı anda
///     tetiklenebilir; ikisi de aynı izlemeyi bildirirdi ve sayaç şişerdi.
class VideoKovaIzleyici {
  /// Gönderi kimliği. null/geçersizse ölçü TAMAMEN kapalıdır (bölüm kareleri,
  /// düzenleme önizlemesi, gönderiye bağlı olmayan oynatmalar).
  final int? gonderiId;

  int? _enYuksek;
  bool _gonderildi = false;

  /// Ölçülen video adresi. Çoklu videolu gönderide YALNIZ İLK OYNAYAN video
  /// ölçülür: iki farklı videonun ilerlemesini tek eğride toplamak hangi
  /// videonun bırakıldığını okunamaz kılardı, üstelik "görüntülenme başına en
  /// fazla bir istek" sözünü de bozardı.
  String? _url;

  VideoKovaIzleyici(Object? gonderiId)
    : gonderiId = switch (gonderiId) {
        final int i when i > 0 => i,
        final String s => int.tryParse(s),
        _ => null,
      };

  /// Ölçü açık mı (test ve çağıran için).
  bool get acik => gonderiId != null;

  /// Şu ana kadar ulaşılan en yüksek kova (hiç oynamadıysa null).
  int? get enYuksekKova => _enYuksek;

  /// İstek gönderildi mi (tek gönderim güvencesinin görünen yüzü).
  bool get gonderildi => _gonderildi;

  /// Oynatıcının o anki konumunu bildirir. Saniyede onlarca kez çağrılabilir:
  /// gövdesi tek bölme ve tek karşılaştırmadır, AĞA HİÇBİR ŞEY GİTMEZ.
  void guncelle({
    required String url,
    required Duration konum,
    required Duration sure,
  }) {
    if (gonderiId == null || _gonderildi) return;
    _url ??= url;
    if (_url != url) return; // gönderinin ikinci videosu: ölçüye karışmaz
    final k = videoKovaHesapla(konum, sure);
    if (k == null) return;
    if (_enYuksek == null || k > _enYuksek!) _enYuksek = k;
  }

  /// Ölçüyü ATEŞLE-UNUT bildirir. Hiç oynamadıysa (kova null) İSTEK ÇIKMAZ:
  /// kurulup hiç oynamamış bir kart eğrinin paydasına girmemeli.
  ///
  /// Hata YUTULUR: bir istatistik sayacı yüzünden kullanıcıya hata balonu
  /// göstermek ölçünün değerinden pahalıdır (`GonderiOlcu.bildir` ile aynı
  /// karar). Girişsiz kullanıcıda uç 401 döner ve sessizce düşer.
  void gonder() {
    if (_gonderildi) return;
    final k = _enYuksek;
    if (gonderiId == null || k == null) return;
    _gonderildi = true;
    Api.post('/gonderi/$gonderiId/video-kova', {
      'kova': k,
    }).catchError((_) => null);
  }
}
