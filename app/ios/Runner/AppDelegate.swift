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
