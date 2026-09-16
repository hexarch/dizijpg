// SOHBET BELGE İNDİRİCİSİ — koşullu içe aktarma (16 Eyl 2026).
//
// İSTEK: "Dosya gönderince indire basınca tarayıcıya yönlendiriyor …
// uygulama içinde indirmeli, WhatsApp/Telegram gibi orada indirilmeli ve
// tıklayınca formatı destekliyorsak bizde aç, desteklemiyorsak
// destekleyecek uygulamaları göster."
//
// · Mobil/masaüstü (dart:io): belge uygulamanın belgeler dizinine akışlı
//   indirilir, halka ilerleme gösterir; indirilmiş belgeye dokunmak açar
//   ([dosyaAc]): görsel ve düz metin UYGULAMA İÇİNDE, diğer biçimler
//   sistemdeki uygulamayla; açacak uygulama yoksa paylaşım sayfası
//   (destekleyen uygulamalar listesi).
// · Web (stub): tarayıcının indirme akışı tek seçenek; sohbet.dart orada
//   eski `launchUrl` yolunu kullanır. [DosyaIndirici.destekli] false döner.
export 'dosya_indirici_stub.dart' if (dart.library.io) 'dosya_indirici_io.dart';
