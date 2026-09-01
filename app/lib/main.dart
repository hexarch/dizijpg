import 'dart:async';
import 'dart:ui' show PlatformDispatcher, PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'altyazi.dart';
import 'api.dart';
import 'ceviri.dart';
import 'cihaz_kimlik.dart';
import 'ekranlar/kabuk.dart' show KabukKatlama;
import 'gorusme/arama_servisi.dart';
import 'push.dart';
import 'kitaplik_durumu.dart';
import 'liste_gorunumu.dart';
import 'puan.dart';
import 'reels_ceviri.dart';
import 'sira_tercihi.dart';
import 'spoiler_tercihi.dart';
import 'surum_kapisi.dart';
import 'tema.dart';
import 'veri_tasarrufu.dart';
import 'yonlendirme.dart';

/// Web'de yatay rafların fareyle sürüklenebilmesi için (varsayılanda kapalı).
class FareKaydirma extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

/// Açılış adımını çalıştırır; PATLASA DA yukarı taşımaz.
///
/// NEDEN: `main` içindeki her `await` doğrudan `runZonedGuarded`'ın hata
/// işleyicisine düşüyordu — yani TEK bir hazırlık adımı (Firebase çekirdeği,
/// çeviri dosyası, SharedPreferences) patladığında `runApp` HİÇ çağrılmıyor,
/// kullanıcı BEMBEYAZ bir sayfa görüyordu. Üstelik konsolda da bir şey
/// çıkmıyordu: `PlatformDispatcher.onError` `true` döndürdüğü için varsayılan
/// yazdırıcı devre dışı kalıyor. Bu sarmalayıcı ile eksik kalan tek şey o
/// adımın kendisi olur (ör. varsayılan dil), uygulama yine açılır.
///
/// Test edilebilirlik için public: test/acilis_dayaniklilik_test.dart.
Future<void> acilisAdimi(String ad, Future<void> Function() calistir) async {
  try {
    await calistir();
  } catch (hata, yigin) {
    debugPrint('Açılış adımı başarısız ($ad): $hata');
    Api.hataBildir(hata, yigin, yol: 'acilis/$ad');
  }
}

Future<void> main() async {
  // Yakalanan Flutter hataları önce konsola, sonra sunucuya (self-hosted günlük).
  FlutterError.onError = (ayrinti) {
    FlutterError.presentError(ayrinti);
    Api.hataBildir(ayrinti.exception, ayrinti.stack);
  };
  // Widget ağacı dışındaki (platform/async) hatalar.
  // `true` dönmek varsayılan yazdırıcıyı devre dışı bırakır; konsol sessiz
  // kalmasın diye ÖNCE kendimiz yazdırıyoruz (7 Ağu'daki "beyaz sayfa ama
  // konsolda hata yok" bildirimi tam da bu sessizlik yüzünden izlenemedi).
  PlatformDispatcher.instance.onError = (hata, yigin) {
    debugPrint('Yakalanmayan hata: $hata\n$yigin');
    Api.hataBildir(hata, yigin);
    return true;
  };
  runZonedGuarded(() async {
    // Web'de #'sız temiz URL; F5 aynı sayfayı açar (nginx try_files ile).
    usePathUrlStrategy();
    WidgetsFlutterBinding.ensureInitialized();
    // Tepki emojileri Noto Animated Emoji (CC BY 4.0) — lisans ATIF ŞART
    // koşuyor. Flutter'ın yerleşik lisans sayfasına eklenir (showLicensePage).
    LicenseRegistry.addLicense(() async* {
      yield const LicenseEntryWithLineBreaks(
        ['Noto Animated Emoji'],
        'Tepki animasyonları (assets/tepkiler/*.json): Noto Animated Emoji, '
        'Google. Creative Commons Attribution 4.0 International '
        '(CC BY 4.0) altında kullanılmıştır.\n'
        'https://googlefonts.github.io/noto-emoji-animation/\n'
        'https://creativecommons.org/licenses/by/4.0/',
      );
    });
    // Firebase çekirdeği + arka plan mesaj işleyicisi
    await acilisAdimi('push', pushCekirdek);
    // Dil: önce kullanıcının SEÇİMİ, seçim yoksa CİHAZIN dili
    // (`Ceviri.yukle` → `cihazDiliEsle`; desteklenmeyen dilde İngilizce).
    // BURADA, `runApp`'ten ÖNCE olmak ZORUNDA: `Ceviri.dil` hem arayüzü hem
    // `X-Dil` başlığıyla TMDB içeriğini belirliyor (api.dart `_basliklar` /
    // `_dilliYol`). Sonraya bırakılsaydı ilk kare Türkçe çizilir, dil sonra
    // değişirdi — göz kırpması; üstelik açılışta atılan istekler yanlış
    // dille gider ve `Onbellek` yanlış dil anahtarına yazardı.
    // `WidgetsFlutterBinding.ensureInitialized()`ten SONRA olmalı (yukarıda):
    // platform dil listesi bağlama kurulmadan güvenilir değil.
    // ADRESTEKİ DİL ÖNEKİ (29 Ağu 2026): `/de/icerik/movie/559` ile gelen
    // ziyaretçi uygulamayı Almanca açar. Bot o adreste Almanca SSR alıyor;
    // insanın Türkçe kabuk görmesi tutarsızlık olurdu. Seçim varsa bu adım
    // devreye girmez (bkz. `Ceviri.yukle` sırası).
    await acilisAdimi(
      'ceviri',
      () => Ceviri.yukle(adres: kIsWeb ? Uri.base : null),
    );
    // KURULUM kimliği: ilk açılışta üretilir, sonraki açılışlarda okunur.
    // DONANIMDAN OKUNMAZ (Play politikası + gizlilik); yalnız moderasyon
    // için `X-Cihaz` başlığıyla gider. Ayrıntı: lib/cihaz_kimlik.dart
    await acilisAdimi('cihaz-kimlik', CihazKimlik.yukle);
    await acilisAdimi('tema', TemaAyar.yukle);
    // bağlantı türü + veri tasarrufu tercihleri
    await acilisAdimi('veri-tasarrufu', VeriTasarrufu.yukle);
    // spoiler uyarısı (perdesi) gösterilsin mi
    await acilisAdimi('spoiler-tercihi', SpoilerTercihi.yukle);
    // videolarda altyazı gösterilsin mi
    await acilisAdimi('altyazi', AltyaziAyar.yukle);
    // Reels'te otomatik çeviri açık mı
    await acilisAdimi('reels-ceviri', ReelsCeviri.yukle);
    // Akış/Keşfet: Kronolojik mi Önerilen mi
    await acilisAdimi('sira', SiraTercihi.yukle);
    // Kitaplık listeleri: afiş ızgarası mı satır listesi mi. İLK KAREDEN
    // ÖNCE okunmalı — sonraya kalsaydı liste ızgarayla açılıp bir kare sonra
    // satıra dönerdi (kullanıcının şikâyet ettiği "yine eski görünüş"ün
    // gözle görünür hâli).
    await acilisAdimi('liste-gorunumu', ListeGorunumu.yukle);
    // Puan ölçeği (5-100): ÖNBELLEKTEN. Doğrunun kaynağı sunucudur ama ilk
    // kare ağı bekleyemez — yanlış ölçekte çizilen yıldız satırı saniye sonra
    // 100'lük rozete dönüşseydi göze çarpan bir zıplama olurdu. Sunucu
    // tazelemesi oturum kurulduktan SONRA, arka planda.
    await acilisAdimi('puan-olcegi', PuanOlcegi.yukle);
    // Masaüstü gezinme adası katlı mı? İlk kareden ÖNCE okunmalı, yoksa
    // çubuk bir açılıp hemen kapanır (göze çarpan bir zıplama).
    await acilisAdimi('cubuk-katlama', KabukKatlama.yukle);
    final oturum = Oturum();
    await acilisAdimi('oturum', oturum.yukle);
    // Girişli kullanıcıda push'u başlat (izin + token kaydı)
    if (oturum.girisli) pushBaslat();
    if (oturum.girisli) KitaplikDurumu.yukle();
    // Ölçeği sunucudan tazele (cihazlar arası tutarlılık). Bloklamaz.
    if (oturum.girisli) PuanOlcegi.tazele();
    if (oturum.girisli) {
      // Arama özellik bayrakları + ICE/TURN kimliği: açılışta BİR KEZ
      // (sözleşme §14.1). Yalnız BELLEKTE tutulur. Beklenmez — ağ yoksa
      // arama düğmeleri gizli kalır, uygulamanın geri kalanı etkilenmez.
      unawaited(
        AramaServisi.baslat().then((_) {
          // Gelen aramanın ASIL yolu FCM; bu 4 sn'lik yoklama onun YEDEĞİ
          // (sözleşme §1). Web'de ikisi de yok — bkz. arama_servisi.dart.
          AramaServisi.gelenAramaGeldi = (_) => rotayaGit(gelenAramaYolu);
          AramaServisi.gelenYoklamaBaslat();
        }),
      );
    }
    // Oturumu `/profilim` ile tazele. ŞART: giriş yanıtında `avatar` YOK
    // (backend/server.js:1888) ve `oturum.yukle()` yalnız prefs'i okur — yani
    // ZATEN girişli olan herkesin avatarı bu çağrı olmadan null kalır ve
    // yorum kutusundaki avatar kişi ikonuna düşer (bkz. `Oturum.tazele`).
    // Beklenmez: açılış bir ağ isteği kadar gecikmesin, tazelenince
    // notifyListeners ile ekranlar kendiliğinden güncellenir.
    if (oturum.girisli) unawaited(oturum.tazele());
    runApp(
      ChangeNotifierProvider.value(value: oturum, child: const DiziJpgApp()),
    );
  }, (hata, yigin) => Api.hataBildir(hata, yigin));
}

class DiziJpgApp extends StatefulWidget {
  const DiziJpgApp({super.key});

  @override
  State<DiziJpgApp> createState() => _DiziJpgAppState();
}

class _DiziJpgAppState extends State<DiziJpgApp> {
  late final GoRouter _yonlendirici = yonlendiriciOlustur(
    context.read<Oturum>(),
  );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: Ceviri.dil,
      // TemaKapsayici tema tercihini + cihaz parlaklığını dinler,
      // DiziRenkler.acik bayrağını tazeler ve DİL ya da TEMA değişince
      // ağacı baştan kurduran anahtarı üretir. Yeniden kurulmazsa keep-alive
      // sekmeler eski dilde, DiziRenkler okuyan her şey eski temada kalıyor
      // (bkz. tema.dart'taki açıklama + test/tema_gecisi_test.dart).
      builder: (context, dil, _) => TemaKapsayici(
        ekAnahtar: dil,
        olustur: (context, tema, anahtar) => MaterialApp.router(
          key: anahtar,
          title: 'dizi.jpg',
          debugShowCheckedModeBanner: false,
          scrollBehavior: FareKaydirma(),
          theme: tema,
          locale: Locale(dil),
          supportedLocales: Ceviri.desteklenenLocaleler,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: _yonlendirici,
          // Sürüm kapısı en dışta: zorunlu güncelleme ekranı her rotanın
          // üstünde durur ve geri tuşuyla kapatılamaz (bkz. surum_kapisi.dart).
          //
          // AnnotatedRegion: sistem gezinme çubuğunun VARSAYILAN rengi = sayfa
          // zemini. Alt menülü kabuk ekranlarında kabuk.dart daha içteki
          // bildirimle bunu çubuk zeminine çevirir; alt menüsüz (push edilen)
          // ekranlarda ise sistem çubuğu sayfanın zeminine uyar — hiçbir
          // ekranda "önceki ekrandan kalma" renk kalmaz.
          builder: (context, cocuk) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: sistemCubukStili(tema.scaffoldBackgroundColor),
            child: SurumKapisi(cocuk: cocuk ?? const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }
}
