import 'package:web/web.dart' as web;

/// Tarayıcı sekmesinin başlığı.
///
/// NEDEN DOĞRUDAN DOM (6 Eyl 2026, canlıda ölçüldü): `MaterialApp.title` /
/// `onGenerateTitle` bu uygulamada `document.title`a HİÇ ULAŞMIYOR. Ölçüm:
/// `/en/icerik/tv/1396` açıldı, JS'ten `document.title='DAMGA'` yazıldı,
/// 15 saniye boyunca 1,5 sn'de bir okundu — Flutter tek bir kez bile üzerine
/// yazmadı. `Title` widget'ı `SystemChrome.setApplicationSwitcherDescription`
/// çağırıyor, web motoru bu kanalı sekme başlığına bağlamıyor.
///
/// İYİ HABER: kabuğun HTML `<title>`ı (dil başına doğru metin,
/// `araclar/web_dil_kabugu.mjs`) bu yüzden EZİLMİYOR. Kötü haber: sayfaya özel
/// başlık da ancak buradan yazılabilir.
void belgeBasligiYaz(String baslik) {
  if (baslik.isEmpty) return;
  if (web.document.title == baslik) return;
  web.document.title = baslik;
}
