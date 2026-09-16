import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Ekran görüntüsü kanalı (aşağıdaki EkranGoruntusu). Messenger'ı
    // registrar'dan alıyoruz: UIScene mimarisinde `window?.rootViewController`
    // bu anda henüz nil olabiliyor (aynı tuzak iOS push jetonunu da
    // askıya almıştı).
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "EkranGoruntusu") {
      EkranGoruntusu.kur(registrar.messenger())
    }
    // Pano (kopyala-yapıştır) kanalı — aynı gerekçeyle registrar'dan.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "Pano") {
      Pano.kur(registrar.messenger())
    }
  }
}

/// EKRAN GÖRÜNTÜSÜ TESPİTİ — iOS (15 Eyl 2026 isteği: sohbette "ekran
/// görüntüsü alındı" yazısı).
///
/// iOS, ekran görüntüsü alındıktan SONRA
/// `UIApplication.userDidTakeScreenshotNotification` yayınlar. Engelleme ya
/// da görüntüye erişim yoktur (ve istenmiyor): tek bilgi "alındı".
///
/// Kanal Android'le AYNI adı taşır (`dizijpg/ekran_goruntusu`) ve gövdesiz
/// (null) olay gönderir — Dart tarafı iki platformu ayırt etmez.
///
/// AYRI DOSYAYA ALINMADI: Xcode'da yeni bir .swift dosyası ancak
/// `Runner.xcodeproj/project.pbxproj`e elle işlenirse derlenir; eklenmeyen
/// dosya SESSİZCE atlanır (uygulama çalışır, kanal hiç cevap vermez).
/// AppDelegate zaten hedefte olduğu için burada durması bu tuzağı kapatır.
class EkranGoruntusu: NSObject, FlutterStreamHandler {
  private static var canli: EkranGoruntusu?
  private var akis: FlutterEventSink?

  /// AppDelegate motoru kurarken çağrılır. Örnek statik tutulur: yerel
  /// değişkende bırakılsa ARC kanalı hemen serbest bırakır ve akış sessizce
  /// hiç olay taşımaz.
  static func kur(_ messenger: FlutterBinaryMessenger) {
    let nesne = EkranGoruntusu()
    canli = nesne
    FlutterEventChannel(
      name: "dizijpg/ekran_goruntusu", binaryMessenger: messenger
    ).setStreamHandler(nesne)
  }

  func onListen(
    withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    akis = events
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(alindi),
      name: UIApplication.userDidTakeScreenshotNotification,
      object: nil
    )
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NotificationCenter.default.removeObserver(
      self, name: UIApplication.userDidTakeScreenshotNotification, object: nil)
    akis = nil
    return nil
  }

  @objc private func alindi() {
    akis?(nil)
  }
}


/// PANODAN MEDYA — iOS (16 Eyl 2026 isteği: "kopyala yapıştır görsel
/// desteği de olmalı").
///
/// Kanal Android'le AYNI adı ve AYNI sözleşmeyi taşır (`dizijpg/pano`):
///   · `varMi` → Bool. Panonun İÇERİĞİ OKUNMAZ, yalnız TÜRÜ sorulur
///     (`hasImages` / `contains(pasteboardTypes:)`). Bu ayrım iOS 16'da
///     önemli: pano İÇERİĞİNİ okumak "… Yapıştır?" iznini ekrana getirir,
///     tür sorgusu getirmez. Yani düğmeyi çizmek için kullanıcıyı
///     rahatsız etmiyoruz.
///   · `oku` → `[{yol, ad, tur}]`. Ancak kullanıcı DÜĞMEYE BASINCA çağrılır;
///     izin diyaloğu çıkarsa bir dokunuşun karşılığıdır.
///
/// GIF ÖNCE DENENİR: pano bir GIF taşıyorsa `UIPasteboard.image` onu tek
/// kareye indirger, animasyon ölürdü. Ham veriyi `com.compuserve.gif`
/// türünden almak animasyonu korur (aynı kural uygulamanın her yerinde:
/// GIF kırpma/düzenleme hattına da sokulmaz).
///
/// AppDelegate dosyasında durmasının gerekçesi yukarıdaki pbxproj notuyla aynı.
class Pano {
  private static var kanal: FlutterMethodChannel?

  /// UTI → (dosya uzantısı, MIME). Sıra ÖNEMLİ: pano aynı görseli birden çok
  /// biçimde taşıyabiliyor ve ilk eşleşen alınıyor.
  private static let turler: [(uti: String, uzanti: String, mime: String)] = [
    ("com.compuserve.gif", "gif", "image/gif"),
    ("public.png", "png", "image/png"),
    ("public.jpeg", "jpg", "image/jpeg"),
    ("org.webmproject.webp", "webp", "image/webp"),
    ("public.webp", "webp", "image/webp"),
    ("public.mpeg-4", "mp4", "video/mp4"),
  ]

  static func kur(_ messenger: FlutterBinaryMessenger) {
    let yeni = FlutterMethodChannel(name: "dizijpg/pano", binaryMessenger: messenger)
    kanal = yeni
    yeni.setMethodCallHandler { cagri, sonuc in
      switch cagri.method {
      case "varMi":
        sonuc(varMi())
      case "oku":
        sonuc(oku())
      default:
        sonuc(FlutterMethodNotImplemented)
      }
    }
  }

  private static func varMi() -> Bool {
    let pano = UIPasteboard.general
    if pano.hasImages { return true }
    return pano.contains(pasteboardTypes: ["public.mpeg-4"])
  }

  private static func oku() -> [[String: String]] {
    let pano = UIPasteboard.general
    var cikti: [[String: String]] = []
    for oge in pano.items {
      guard let esles = turler.first(where: { oge[$0.uti] != nil }) else { continue }
      guard let veri = oge[esles.uti] as? Data, !veri.isEmpty else { continue }
      if let yol = yaz(veri, esles.uzanti) {
        cikti.append(["yol": yol.path, "ad": yol.lastPathComponent, "tur": esles.mime])
      }
    }
    // Hiçbir ham tür tanınmadıysa son çare: sistemin verdiği görsel (ekran
    // görüntüsü kopyalayan bazı uygulamalar yalnız `UIImage` koyuyor).
    if cikti.isEmpty, let resim = pano.image, let veri = resim.pngData(),
      let yol = yaz(veri, "png")
    {
      cikti.append(["yol": yol.path, "ad": yol.lastPathComponent, "tur": "image/png"])
    }
    return cikti
  }

  /// Geçici dizine yazar; Dart tarafı yolu `XFile` ile okur (bkz.
  /// `pano_medya_io.dart`: bayt platform kanalından GEÇMEZ).
  private static func yaz(_ veri: Data, _ uzanti: String) -> URL? {
    let yol = FileManager.default.temporaryDirectory
      .appendingPathComponent("pano-\(UUID().uuidString).\(uzanti)")
    do {
      try veri.write(to: yol)
      return yol
    } catch {
      return nil
    }
  }
}
