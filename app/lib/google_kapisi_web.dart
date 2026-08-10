import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi;

import 'ceviri.dart';
import 'google_kapisi.dart';
import 'tema.dart';

GoogleKapisi googleWebKapisi() => GoogleKapisiWeb();

/// Web dalı: Google'ın KENDİ düğmesi (`renderButton`) + kimlik akışı.
///
/// ESKİ YOL NEDEN ÇALIŞMIYORDU (10 Ağu 2026, tarayıcıda üretildi):
/// `GoogleSignIn.signIn()` webde OAuth "implicit" açılır penceresini açıyor;
/// konsolda `[GSI_LOGGER-TOKEN_CLIENT]: Starting popup flow` görünüyor, ardından
/// `Checking popup closed` SONSUZA kadar dönüyordu. Future hiç tamamlanmadığı
/// için ekran "yükleniyor" halinde kilitleniyor, hata da atılmıyordu — yani
/// sunucuya hiç istek gitmiyordu (nginx kayıtlarında sıfır `/api/auth/google`).
/// Üstelik bu yol başarılı olsa bile id_token VERMEZ; paketin kendi kaynağı da
/// "`signIn` web'de önerilmez, `renderButton` kullan" diye uyarıyor.
class GoogleKapisiWeb implements GoogleKapisi {
  GoogleKapisiWeb() {
    // `GoogleSignIn` yapıcısı webde eklentiyi HEMEN başlatır ve
    // `userDataEvents` akışını `onCurrentUserChanged`e bağlar; Google'ın
    // düğmesiyle gelen JWT kimliği bize buradan ulaşır.
    _google = GoogleSignIn(clientId: googleIstemcisi, scopes: const ['email']);
    _abone = _google.onCurrentUserChanged.listen(_hesapGeldi);
    // Yan etkisiz "hazır mı" ölçüsü: eklenti `isSignedIn()` içinde SDK'nın
    // yüklenmesini ve `init`i bekler. Zaman aşımı ŞART — SDK engellenirse
    // (reklam engelleyici, ağ) bu future hiç çözülmez ve düğme sonsuza kadar
    // yer tutucuda kalırdı; SESSİZ başarısızlık bu hatanın özüydü.
    _hazir = _google.isSignedIn().timeout(const Duration(seconds: 12));
  }

  late final GoogleSignIn _google;
  late final Future<void> _hazir;
  StreamSubscription<GoogleSignInAccount?>? _abone;
  final _denetci = StreamController<GoogleKimligi>.broadcast();

  Future<void> _hesapGeldi(GoogleSignInAccount? hesap) async {
    if (hesap == null) return;
    try {
      final yetki = await hesap.authentication;
      _denetci.add(
        GoogleKimligi(idToken: yetki.idToken, erisimToken: yetki.accessToken),
      );
    } catch (e) {
      _denetci.addError(e);
    }
  }

  @override
  Stream<GoogleKimligi> get akis => _denetci.stream;

  @override
  Widget? dugme(BuildContext context) => _GoogleWebDugmesi(hazir: _hazir);

  /// Webde çağrılmaz: Google'ın düğmesi akışı kendisi başlatır.
  @override
  Future<GoogleKimligi?> dokun() =>
      throw UnsupportedError('Webde giriş Google\'ın düğmesinden başlar.');

  @override
  void birak() {
    _abone?.cancel();
    _denetci.close();
  }
}

class _GoogleWebDugmesi extends StatefulWidget {
  const _GoogleWebDugmesi({required this.hazir});

  final Future<void> hazir;

  @override
  State<_GoogleWebDugmesi> createState() => _GoogleWebDugmesiState();
}

class _GoogleWebDugmesiState extends State<_GoogleWebDugmesi> {
  /// Ayar nesnesi TEK KOPYA tutulur ve yalnız genişlik değişince yenilenir.
  /// NEDEN: `renderButton`, widget anahtarını `configuration.hashCode`den
  /// üretiyor ve `GSIButtonConfiguration` `hashCode` TANIMLAMIYOR (kimlik
  /// karması). Her `build`de yeni nesne üretilseydi anahtar her seferinde
  /// değişir, HtmlElementView sökülüp yeniden kurulur ve Google'ın düğmesi
  /// her `setState`te yeniden çizilirdi.
  gsi.GSIButtonConfiguration? _ayar;
  double _genislik = 0;

  gsi.GSIButtonConfiguration _ayarAl(double genislik) {
    // Google düğmeyi en fazla 400 px çizer; kalan boşluk ortalanır.
    final g = genislik.clamp(1.0, 400.0);
    if (_ayar == null || (g - _genislik).abs() > 0.5) {
      _genislik = g;
      _ayar = gsi.GSIButtonConfiguration(
        // GÖRÜNÜM KARARI: `outline` (beyaz zemin + gri kontur). `filledBlack`
        // denenmedi değil — uygulamanın koyu teması GERÇEK SİYAH (#000) ve
        // Google'ın siyah düğmesi #131314; kenarı görünmez olurdu (ui-ux-pro-max
        // "Border and divider visibility" kuralı). `outline` her iki temada da
        // konturunu ve 4.5:1 üstü metin kontrastını korur.
        theme: gsi.GSIButtonTheme.outline,
        // "large" ~40 px: Material'ın OutlinedButton yüksekliğiyle aynı.
        size: gsi.GSIButtonSize.large,
        // Yanındaki "Misafir olarak devam et" düğmesi StadiumBorder; `pill`
        // aynı hattı tutturur.
        shape: gsi.GSIButtonShape.pill,
        // "Google ile devam et" — bizim eski etiketimizin Google'daki karşılığı.
        text: gsi.GSIButtonText.continueWith,
        logoAlignment: gsi.GSIButtonLogoAlignment.left,
        minimumWidth: g,
        // Düğme metnini uygulamanın diliyle aynı tutar (45 dil).
        locale: Ceviri.dil.value,
      );
    }
    return _ayar!;
  }

  /// Google'ın düğmesi gelene kadar (ve hata halinde) çizilen, TIKLANAMAZ
  /// eşdeğer düğme: aynı yükseklik, aynı ikon, aynı metin → yer değişmez.
  Widget _yerTutucu({required bool hata}) => OutlinedButton.icon(
    onPressed: null,
    icon: SvgPicture.asset('assets/google_g.svg', width: 18, height: 18),
    label: Text(
      hata ? 'Google girişi başarısız'.c : 'Google ile devam et'.c,
      style: TextStyle(color: DiziRenkler.metin54),
    ),
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    height: googleDugmeYuksekligi,
    child: FutureBuilder<void>(
      future: widget.hazir,
      builder: (context, kar) {
        if (kar.connectionState != ConnectionState.done) {
          return _yerTutucu(hata: false);
        }
        if (kar.hasError) return _yerTutucu(hata: true);
        return LayoutBuilder(
          builder: (context, kisit) => Center(
            child: gsi.renderButton(configuration: _ayarAl(kisit.maxWidth)),
          ),
        );
      },
    ),
  );
}
