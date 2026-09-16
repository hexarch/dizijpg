// PANODAN MEDYA (kopyala-yapıştır) — 16 Eyl 2026 kullanıcı isteği:
// *"paylaşımlarda tüm türleri desteklemeliyiz yani görsel video gif olarak
// ve kopyala yapıştır görsel desteği de olmalı."*
//
// Seçici yolu (sistem Fotoğraf Seçici → inceleme → `/medya`) görsel/GIF/video
// için zaten çalışıyordu; PANO yolu hiç yoktu. Ekran görüntüsü alıp yapıştırmak
// masaüstü webde en sık kullanılan medya ekleme yoludur ve bizde tek yol
// "dosyayı diske kaydet, sonra seçiciden bul" idi.
//
// ÜÇ YÜZEY, ÜÇ MEKANİZMA — hepsi aynı sözleşmenin arkasında:
//  · WEB: belge üzerinde `paste` olayı (`ClipboardEvent.clipboardData.files`).
//    Ctrl/⌘+V ile gelen dosyalar YAKALANIR; ayrıca düğme için Async Clipboard
//    (`navigator.clipboard.read`) kullanılır.
//  · ANDROID: `ClipboardManager` → `content://` uri'leri (MainActivity.kt).
//  · iOS: `UIPasteboard` (AppDelegate.swift).
//
// DÖNEN ŞEY [XFile]: mevcut yükleme hattına (`medyalariYukle` → `/medya`)
// DEĞİŞMEDEN girer. Sunucuda hiçbir değişiklik yok — sihirli bayt kapısı
// zaten GIF/PNG/JPEG/WebP/MP4/WebM tanıyor.
export 'pano_medya_io.dart' if (dart.library.js_interop) 'pano_medya_web.dart';
