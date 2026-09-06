/// İZLEME ODASI — OYNATICI SOYUTLAMASI.
///
/// ===========================================================================
/// NEDEN SOYUTLAMA (7 Eyl 2026)
/// ===========================================================================
/// Odanın iki kaynağı var: yüklenen dosya ve yapıştırılan bağlantı. Senkron
/// merdiveni (`oda_senkron.dart`) ikisinde de AYNEN aynı çalışmalı — "sahip 10
/// sn sardı" kararı kaynağa bakmaz.
///
/// Alternatif, `oda_ekrani.dart` içinde her yerde `if (bağlantı) ... else ...`
/// yazmaktı. Ekran 3.200 satır ve düzeltme mantığı beş ayrı yerden çağrılıyor;
/// o dallanma beşe katlanır ve biri unutulduğunda YALNIZ bağlantı kipinde
/// bozulan, testte görünmeyen bir hata bırakırdı. Burada tek bir arayüz var:
/// ekran ne oynattığını bilmiyor.
///
/// Üç gerçekleme:
///   · [OdaDosyaOynatici] — `video_player`. Yüklenen dosya VE doğrudan
///     bağlantı (`.mp4`/`.webm`) ikisi de bunu kullanır: doğrudan adres için
///     yeni oynatıcı yazmaya gerek yok, yalnız URL değişiyor.
///   · [OdaGommeDenetci] — YouTube/Vimeo. Gerçek oynatıcı bizim süreçte
///     değil (çapraz kökenli iframe / WebView); bu sınıf ona komut yollayan
///     ve ondan haber alan uzaktan kumandadır.
library;

import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

/// Oynatıcının dışarıya gösterdiği tüm durum.
///
/// `VideoPlayerValue`nun ihtiyaç duyulan alanlarının aynısı: ekran kodu
/// (`_duzelt`, `_kontroller`) alan alan aynı adları okuduğu için geçiş
/// mekanik oldu.
@immutable
class OdaOynaticiDeger {
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isInitialized;
  final bool isBuffering;
  final double aspectRatio;

  /// Gömme oynatıcı SESSİZ başlar (tarayıcı politikası; bkz. [OdaGommeDenetci]).
  /// Ekran buna bakıp "Sesi aç" düğmesi çizer.
  final bool sessiz;

  const OdaOynaticiDeger({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
    this.isInitialized = false,
    this.isBuffering = false,
    this.aspectRatio = 16 / 9,
    this.sessiz = false,
  });

  OdaOynaticiDeger kopya({
    Duration? position,
    Duration? duration,
    bool? isPlaying,
    bool? isInitialized,
    bool? isBuffering,
    double? aspectRatio,
    bool? sessiz,
  }) => OdaOynaticiDeger(
    position: position ?? this.position,
    duration: duration ?? this.duration,
    isPlaying: isPlaying ?? this.isPlaying,
    isInitialized: isInitialized ?? this.isInitialized,
    isBuffering: isBuffering ?? this.isBuffering,
    aspectRatio: aspectRatio ?? this.aspectRatio,
    sessiz: sessiz ?? this.sessiz,
  );
}

/// Ekranın gördüğü tek arayüz.
abstract class OdaOynatici extends ValueNotifier<OdaOynaticiDeger> {
  OdaOynatici() : super(const OdaOynaticiDeger());

  Future<void> oynat();
  Future<void> duraklat();
  Future<void> sar(Duration hedef);
  Future<void> hizAyarla(double hiz);

  /// Sesi açar (yalnız gömmede anlamlı; dosyada zaten açık).
  Future<void> sesiAc() async {}

  /// Video yüzeyi. Dosyada `VideoPlayer`, gömmede iframe/WebView.
  Widget yuzey();

  Future<void> sok();
}

/// `video_player` üzerine ince sarmalayıcı.
///
/// Değerini kendi tutmaz, denetçinin değerini yansıtır: iki ayrı doğruluk
/// kaynağı olsaydı sarma sırasında ikisi ayrışır ve çubuk zıplardı.
class OdaDosyaOynatici extends OdaOynatici {
  final VideoPlayerController denetci;

  OdaDosyaOynatici(this.denetci) {
    denetci.addListener(_yansit);
    _yansit();
  }

  void _yansit() {
    final d = denetci.value;
    value = OdaOynaticiDeger(
      position: d.position,
      duration: d.duration,
      isPlaying: d.isPlaying,
      isInitialized: d.isInitialized,
      isBuffering: d.isBuffering,
      // 0 en-boy oranı `AspectRatio`yu çökertir (assert). Bozuk üstbilgili
      // dosyalarda gerçekten 0 geliyor.
      aspectRatio: d.aspectRatio > 0 ? d.aspectRatio : 16 / 9,
    );
  }

  @override
  Future<void> oynat() => denetci.play();

  @override
  Future<void> duraklat() => denetci.pause();

  @override
  Future<void> sar(Duration hedef) => denetci.seekTo(hedef);

  @override
  Future<void> hizAyarla(double hiz) => denetci.setPlaybackSpeed(hiz);

  @override
  Widget yuzey() => VideoPlayer(denetci);

  @override
  Future<void> sok() async {
    denetci.removeListener(_yansit);
    await denetci.dispose();
    dispose();
  }
}

/// Gömme oynatıcının uzaktan kumandası (YouTube / Vimeo).
///
/// ===========================================================================
/// NEDEN "SESSİZ BAŞLA"
/// ===========================================================================
/// Tarayıcı, kullanıcı jesti olmadan SESLİ oynatmayı engeller ve çapraz
/// kökenli bir iframe'de bizim uygulamamıza yapılan dokunuş o iframe için
/// jest SAYILMAZ. Sesli başlatmayı denemek, izleyicinin videosunun hiç
/// açılmaması demekti — üstelik sessizce, hata bile vermeden.
///
/// Bu yüzden gömme daima sessiz başlar ve ekran belirgin bir "Sesi aç"
/// düğmesi çizer. Dokunuş hem jesti verir hem sesi açar. Yüklenen dosyada bu
/// sorun yok (aynı köken), orada ses açıktır.
///
/// Yüzey widget'ı (`oda_gomme_web.dart` / `oda_gomme_io.dart`) kurulurken
/// [gonder]i doldurur ve oynatıcıdan haber geldikçe [bildir]i çağırır.
class OdaGommeDenetci extends OdaOynatici {
  /// Yüzey tarafından kurulur: komutu gerçek oynatıcıya iletir.
  /// `komut` ∈ {oynat, duraklat, sar, hiz, ses}.
  void Function(String komut, Object? arg)? gonder;

  /// Yüzey söküldüğünde tekrar null olur; komutlar sessizce düşer.
  bool get bagli => gonder != null;

  OdaGommeDenetci() {
    value = const OdaOynaticiDeger(sessiz: true);
  }

  /// Yüzeyin bildirdiği durum. Yalnız DOLU alanlar yazılır: YouTube süreyi bir
  /// kez, konumu sürekli gönderir; her mesajda tam nesne beklenseydi süre
  /// ikinci mesajda sıfırlanırdı.
  void bildir({
    int? konumMs,
    int? sureMs,
    bool? oynuyor,
    bool? hazir,
    bool? tamponluyor,
    bool? sessiz,
  }) {
    value = value.kopya(
      position: konumMs == null ? null : Duration(milliseconds: konumMs),
      // Süre 0 gelirse YAZILMAZ: oynatıcı hazır olmadan 0 bildiriyor ve bunu
      // yazmak `_duzelt`in konumu 0'a kırpmasına yol açardı.
      duration: (sureMs == null || sureMs <= 0)
          ? null
          : Duration(milliseconds: sureMs),
      isPlaying: oynuyor,
      isInitialized: hazir,
      isBuffering: tamponluyor,
      sessiz: sessiz,
    );
  }

  @override
  Future<void> oynat() async => gonder?.call('oynat', null);

  @override
  Future<void> duraklat() async => gonder?.call('duraklat', null);

  @override
  Future<void> sar(Duration hedef) async {
    // İYİMSER YAZMA: gerçek oynatıcının `timeupdate` haberi 250-400 ms sonra
    // geliyor. O ana kadar eski konumu göstermek, senkron düzelticisinin
    // "hâlâ geride" deyip İKİNCİ bir sarma atmasına yol açıyordu (video
    // iki kez zıplıyordu).
    value = value.kopya(position: hedef);
    gonder?.call('sar', hedef.inMilliseconds / 1000);
  }

  @override
  Future<void> hizAyarla(double hiz) async => gonder?.call('hiz', hiz);

  @override
  Future<void> sesiAc() async {
    value = value.kopya(sessiz: false);
    gonder?.call('ses', false);
  }

  /// Yüzey widget'ı ayrı: denetçi ekranda tutulur, yüzey ağaçta yaşar.
  @override
  Widget yuzey() => const SizedBox.shrink();

  @override
  Future<void> sok() async {
    gonder = null;
    dispose();
  }
}
