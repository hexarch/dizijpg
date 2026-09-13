// Ekran altı bildirimleri (SnackBar) — TEK KAPI + "dokununca kapanır".
//
// ===========================================================================
// HANGİ HATAYI ÇÖZÜYOR (13 Eyl 2026, kullanıcı bildirimi)
// ===========================================================================
// Kullanıcı birebir: *"profildeki listeleri açınca basılı tutunca en aşağı al
// olayı varya onu çok hızlı şekilde yapınca aşağıda sürekli art arda listenin
// altına gönderilmiştir deniyor; orada belirli süre kullanmak yerine ekrana
// tekrar tıklayınca o bildirimi hemen yok etsek daha mantıklı olmaz mı"*.
//
// İKİ AYRI KUSUR VARDI:
//
//  1) KUYRUK. `ScaffoldMessenger.showSnackBar` çağrıları BİRİKİR: aynı mesajı
//     5 kez tetikleyen kullanıcı 5 × 4 sn = 20 saniye boyunca bildirim
//     okuyor. Flutter'ın varsayılanı budur ve "en aşağıya gönder" gibi
//     saniyede birkaç kez basılabilen bir eylemde yanlış varsayılan.
//     → [uyar] önce kuyruğu temizler: EN SON mesaj kazanır, süre baştan başlar.
//
//  2) KAÇIŞ YOLU YOK. Bildirim yalnız süresi dolunca ya da üstünde yatay
//     sürükleme yapılınca kapanıyordu (sürüklemeyi kimse bilmiyor). Ekrana
//     dokunmak kapatmıyordu.
//     → [UyariKatmani] uygulamanın tamamını sarar; İLK dokunuşta ekrandaki
//       bildirimi (ve kuyruğu) düşürür.
//
// ===========================================================================
// KATMAN NEDEN `Listener` (GestureDetector DEĞİL)
// ===========================================================================
// [Listener] jest ARENASINA girmez: dokunma alttaki düğmeye, kaydırmaya,
// sürükleme-bırakmaya AYNEN ulaşır, biz yalnız haberdar oluruz. Aynı işi
// `GestureDetector(onTap:)` ile yapmak arenada yarışmak demekti — bir
// `onTap`in kazandığı her yerde bildirim kapanmaz, kaydırmada hiç kapanmazdı.
//
// ===========================================================================
// EYLEM DÜĞMELİ BİLDİRİM KORUNUR
// ===========================================================================
// "Yorum profilinde gizlendi · GERİ AL" gibi bir bildirim kullanıcıdan KARAR
// bekler; ilk dokunuşta silinmesi geri alma yolunu elinden almak olurdu.
// Bu yüzden eylem düğmesi taşıyan bildirimler [eylemliUyar] ile gösterilir ve
// katman onlara dokunmaz (süresi dolar ya da düğmeye basılır).
//
// YENİ EYLEM DÜĞMELİ BİLDİRİM EKLERKEN: `showSnackBar`ı doğrudan çağırma,
// [eylemliUyar]dan geçir — yoksa düğmesi ilk dokunuşta kaybolur.
import 'package:flutter/material.dart';

/// Ekranda duran EYLEM DÜĞMELİ bildirimin denetçisi (yoksa null).
/// Katman buna bakıp kapatmaktan vazgeçer.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _eylemli;

/// Ekranda karar bekleyen (eylem düğmeli) bir bildirim var mı?
bool get eylemliUyariAcik => _eylemli != null;

/// KUYRUĞA GİRMEYEN bildirim: varsa öncekini düşürür, yenisini gösterir.
///
/// Hızlı tekrarlanan eylemlerde ("en aşağıya gönder", "en üste taşı") tek
/// doğru davranış bu: kullanıcı 5 kez bastıysa 5 mesaj değil, SON mesajı
/// görmeli.
void uyar(BuildContext context, String mesaj, {Duration? sure}) {
  final kapi = ScaffoldMessenger.maybeOf(context);
  if (kapi == null) return;
  kapi.clearSnackBars();
  kapi.showSnackBar(
    SnackBar(
      content: Text(mesaj),
      duration: sure ?? const Duration(seconds: 4),
    ),
  );
}

/// EYLEM DÜĞMELİ bildirim ("Geri al", "Ayarlar"...). Ekrana dokunmak bunu
/// KAPATMAZ — bkz. dosya başlığı.
///
/// Eylemsiz bir bildirim verilirse ([SnackBar.action] null) korumaya
/// alınmaz: o zaman [uyar] ile hiçbir farkı yoktur.
void eylemliUyar(BuildContext context, SnackBar bildirim) {
  final kapi = ScaffoldMessenger.maybeOf(context);
  if (kapi == null) return;
  kapi.clearSnackBars();
  final denetci = kapi.showSnackBar(bildirim);
  if (bildirim.action == null) return;
  _eylemli = denetci;
  // Kapanınca (süre doldu / düğmeye basıldı / sürüklendi) koruma kalkar.
  // Karşılaştırma ŞART: arada yeni bir eylemli bildirim açıldıysa onun
  // korumasını silmemeliyiz.
  denetci.closed.then((_) {
    if (_eylemli == denetci) _eylemli = null;
  });
}

/// YALNIZ TEST: ekranlar arası sızan korumayı sıfırlar.
@visibleForTesting
void eylemliUyariSifirla() => _eylemli = null;

/// Uygulamanın tamamını saran katman: ekrana dokunulduğu AN bildirimi düşürür.
///
/// [MaterialApp.builder] içinde kurulur — oradaki context [ScaffoldMessenger]
/// ile Navigator'ın ARASINDADIR, yani hem mesajlayıcıya erişir hem de her
/// rotanın dokunuşunu görür.
class UyariKatmani extends StatelessWidget {
  const UyariKatmani({super.key, required this.cocuk});

  final Widget cocuk;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        if (eylemliUyariAcik) return;
        // Bildirim yoksa `clearSnackBars` bedelsiz döner (kuyruk boşsa
        // hiçbir şey yapmaz) — her dokunuşta çağrılması sorun değil.
        ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
      },
      child: cocuk,
    );
  }
}
