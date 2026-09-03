/// İZLEME ODASI — 5 GB'a kadar DEVAM EDİLEBİLİR video yükleme.
///
/// ===========================================================================
/// NEDEN `/medya` KULLANILMIYOR
/// ===========================================================================
/// `Api.medyaYukle` dosyanın TAMAMINI belleğe alıp tek gövdede POST eder.
/// Tavanı 100 MB ve bu bilinçli: nginx `client_max_body_size` **105m**.
/// Oda videosu 5 GB'a kadar çıkabildiği için o hat üç yerden birden kırılırdı —
/// belleğe sığmaz, nginx 413 basar, kopan bağlantı her şeyi baştan aldırır.
///
/// ===========================================================================
/// SÖZLEŞME (sunucu tarafı: backend/oda.js `parcaKarari`)
/// ===========================================================================
///   1. `POST /oda-video/basla`  -> {yukleme, ofset}
///      **`ofset > 0` ise YARIM BİR YÜKLEME VAR** ve oradan devam edilir.
///   2. `POST /oda-video/parca`  (X-Yukleme, X-Ofset + ham gövde) -> {ofset}
///      Sunucu beklediği ofseti HER yanıtta söyler; istemci ona uyar.
///   3. `POST /oda-video/bitir`  -> {video, video_sure_ms, ...}
///
/// ===========================================================================
/// NEDEN AKIŞTAN (`withReadStream`) OKUNUYOR
/// ===========================================================================
/// `PlatformFile.bytes` 5 GB'ı belleğe alırdı — Android'de süreç öldürülür,
/// tarayıcıda sekme çöker. `file_picker` her iki platformda da dosyayı
/// dilimleyerek akıtır (web'de `File.slice`, native'de dosya akışı), yani
/// bellekte aynı anda yalnız bir parça durur.
///
/// BEDELİ: bir akış YALNIZ BİR KEZ okunabilir. Uygulama kapanıp açıldıktan
/// sonra devam etmek için dosya YENİDEN seçilir ve akışın ilk `ofset` baytı
/// ATILARAK (okunup çöpe atılarak) hizalanır. Atılan baytlar AĞDAN geçmez —
/// kurtarılan şey yükleme trafiğidir, disk okuması değil.
library;

import 'dart:async';
import 'dart:typed_data';

import '../api.dart';
import '../ceviri.dart';
import 'oda_api.dart';

/// Yükleme ilerlemesi — arayüz bunu dinler.
class OdaYuklemeDurumu {
  final int gonderilen;
  final int toplam;

  /// Bu yükleme yarım kalmış bir yüklemenin DEVAMI mı (kullanıcıya söylenir:
  /// "kaldığı yerden devam ediyor" — yoksa ilerleme çubuğunun %40'tan
  /// başlaması hata gibi görünür).
  final bool devam;

  const OdaYuklemeDurumu({
    required this.gonderilen,
    required this.toplam,
    this.devam = false,
  });

  double get oran => toplam > 0 ? (gonderilen / toplam).clamp(0.0, 1.0) : 0.0;
  int get yuzde => (oran * 100).round();
}

/// Yükleme sonucu.
class OdaVideoSonuc {
  final String video;
  final String? videoAd;
  final int? videoSureMs;
  final String? videoKapak;

  const OdaVideoSonuc({
    required this.video,
    this.videoAd,
    this.videoSureMs,
    this.videoKapak,
  });
}

/// İptal edilebilir bir yükleme oturumu.
class OdaVideoYukleyici {
  final int odaId;
  bool _iptal = false;

  OdaVideoYukleyici(this.odaId);

  /// Kullanıcı vazgeçti. Süren parça biter, sonraki gönderilmez.
  ///
  /// Sunucudaki yarım dosya SİLİNMEZ: kullanıcı fikrini değiştirip aynı
  /// dosyayı yeniden seçerse kaldığı yerden devam eder. Vazgeçilen yükleme
  /// 6 saat sonra süpürgede gider (`YUKLEME_OMRU_MS`).
  void iptal() => _iptal = true;

  /// [akis] dosyanın baytlarını veren akış (file_picker `readStream`),
  /// [boyut] toplam bayt, [ad] özgün dosya adı.
  ///
  /// [ilerleme] her parçadan sonra çağrılır.
  Future<OdaVideoSonuc> yukle({
    required Stream<List<int>> akis,
    required int boyut,
    required String ad,
    void Function(OdaYuklemeDurumu)? ilerleme,
  }) async {
    if (boyut > odaVideoAzamiBayt) {
      throw ApiHata(
        'Video en fazla {} GB olabilir'.cf([odaVideoAzamiGb]),
        makineKodu: OdaKod.videoCokBuyuk,
      );
    }
    final bas =
        await Api.post('/oda-video/basla', {
              'oda': odaId,
              'boyut': boyut,
              'ad': ad,
            })
            as Map<String, dynamic>;
    final yuklemeId = bas['yukleme'] as String;
    var ofset = (bas['ofset'] as num?)?.toInt() ?? 0;
    final devam = ofset > 0;
    ilerleme?.call(
      OdaYuklemeDurumu(gonderilen: ofset, toplam: boyut, devam: devam),
    );

    // Tampon: akış 1 MB'lık dilimler verir, biz 8 MB'lık parçalar göndeririz.
    // Her 1 MB için ayrı istek atmak 5 GB'ta 5000 tur ederdi (hız limiti ve
    // TLS el sıkışma maliyeti).
    final tampon = BytesBuilder(copy: false);
    var okunan = 0; // akışta şu ana kadar GÖRÜLEN bayt (atılanlar dahil)

    Future<void> gonder() async {
      final veri = tampon.takeBytes();
      if (veri.isEmpty) return;
      final yanit = await Api.odaParcaYukle(
        veri,
        yukleme: yuklemeId,
        ofset: ofset,
      );
      // Sunucu beklediği ofseti HER yanıtta söyler. `tekrar: true` gelirse
      // baytlarımız zaten ondaydı (biz geride kalmışız) — hata DEĞİL,
      // senkronizasyon. Her iki durumda da sunucunun dediği ofsete uyarız.
      ofset = (yanit['ofset'] as num?)?.toInt() ?? (ofset + veri.length);
      ilerleme?.call(
        OdaYuklemeDurumu(gonderilen: ofset, toplam: boyut, devam: devam),
      );
    }

    await for (final dilim in akis) {
      if (_iptal) throw const OdaYuklemeIptal();
      final basi = okunan;
      okunan += dilim.length;
      // DEVAM: sunucuda zaten olan baytları ağdan geçirme. Dilim kısmen
      // eskiyse (sınır ortada kalıyorsa) yalnız yeni kısmı al.
      if (basi + dilim.length <= ofset) continue;
      final atla = ofset > basi ? ofset - basi : 0;
      tampon.add(atla > 0 ? dilim.sublist(atla) : dilim);
      while (tampon.length >= odaParcaBayt) {
        // Tam 8 MB'lık bir parça çıkar; artan tamponda kalsın.
        final hepsi = tampon.takeBytes();
        final parca = Uint8List.sublistView(hepsi, 0, odaParcaBayt);
        final artan = Uint8List.sublistView(hepsi, odaParcaBayt);
        final yanit = await Api.odaParcaYukle(
          parca,
          yukleme: yuklemeId,
          ofset: ofset,
        );
        ofset = (yanit['ofset'] as num?)?.toInt() ?? (ofset + parca.length);
        ilerleme?.call(
          OdaYuklemeDurumu(gonderilen: ofset, toplam: boyut, devam: devam),
        );
        tampon.add(artan);
        if (_iptal) throw const OdaYuklemeIptal();
      }
    }
    await gonder(); // son (8 MB'tan küçük) parça

    final bitti =
        await Api.post('/oda-video/bitir', {'yukleme': yuklemeId})
            as Map<String, dynamic>;
    return OdaVideoSonuc(
      video: bitti['video'] as String,
      videoAd: bitti['video_ad'] as String?,
      videoSureMs: (bitti['video_sure_ms'] as num?)?.toInt(),
      videoKapak: bitti['video_kapak'] as String?,
    );
  }
}

/// Kullanıcı yüklemeyi iptal etti — hata SnackBar'ı gösterilmez.
class OdaYuklemeIptal implements Exception {
  const OdaYuklemeIptal();
  @override
  String toString() => 'OdaYuklemeIptal';
}
