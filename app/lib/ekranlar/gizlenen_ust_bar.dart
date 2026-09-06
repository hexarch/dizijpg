import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

/// AŞAĞI KAYDIRINCA GİZLENEN ÜST BAR (Akış ve Keşfet).
///
/// KULLANICI İSTEĞİ (6 Eyl 2026): *"uygulamada akışta aşağı kaydırınca
/// yukarıdaki akış keşfet logo gizlenmeli"*. Aynı üst bar iki ekranda da
/// duruyor (logo + "Akış | Keşfet" seçicisi), o yüzden davranış tek yerde.
///
/// NEDEN SliverAppBar DEĞİL: iki gövde de kendi kalıbıyla kurulu — Akış'ta
/// `RefreshIndicator` + [OrtaKolon] sarmalayıcısı içinde `ListView.builder`,
/// Keşfet'te ölçülen kolona göre sütun sayısı hesaplayan `CustomScrollView`.
/// Slivere çevirmek [OrtaKolon] genişlik kısıtını (masaüstü hizası) kırardı.
/// Bunun yerine Scaffold'un kendi `appBar` yuvası kullanılıyor: barın
/// [PreferredSizeWidget.preferredSize] yüksekliği 0'a inince gövde boşalan
/// yeri GERÇEKTEN doldurur (bar sadece saydamlaşmaz, yer de kaplamaz).

/// Bar gizlenmeden önce gerekli en az kaydırma mesafesi.
///
/// TİTREME SİGORTASI: bar gizlenince gövde [kToolbarHeight] kadar uzar,
/// yani `maxScrollExtent` de o kadar artar. Liste zaten kıl payı
/// kaydırılabiliyorsa gizle→uzat→göster→kısalt döngüsüne girip zıplardı.
const double _asgariKaydirma = kToolbarHeight * 3;

/// Bu mesafenin üstünde bar her zaman açık: listenin tepesinde başlık görünür.
const double _tepeEsigi = 8;

/// Üst bar görünür mü? (saf karar — widget'sız test edilebilir)
///
/// [yon] `reverse` = kullanıcı AŞAĞI kaydırıyor (parmak yukarı, içerik
/// yukarı kayıyor) → gizle. `forward` = yukarı kaydırıyor → göster.
/// `idle` durumunda karar DEĞİŞMEZ: kaydırma bitince bar olduğu gibi kalır.
@visibleForTesting
bool ustBarGorunsun({
  required bool gorunur,
  required double piksel,
  required double azamiKaydirma,
  required ScrollDirection yon,
}) {
  if (azamiKaydirma < _asgariKaydirma) return true;
  if (piksel <= _tepeEsigi) return true;
  return switch (yon) {
    ScrollDirection.reverse => false,
    ScrollDirection.forward => true,
    ScrollDirection.idle => gorunur,
  };
}

/// Kaydırma yönünü dinleyip barın açıklık oranını (0..1) yürüten defter.
///
/// Ekranın `State`i kurar (vsync için `SingleTickerProviderStateMixin` şart),
/// kaydırma dinleyicisinde [kaydirmaDegisti] çağırır ve [animasyon]'u bir
/// `AnimatedBuilder`a verir. Gövde `AnimatedBuilder`ın `child`ı olarak
/// GEÇİLİR: animasyon karelerinde yalnız Scaffold+AppBar yeniden kurulur,
/// liste ağacı değil.
class UstBarGizleyici {
  UstBarGizleyici({required TickerProvider vsync})
    : _anim = AnimationController(
        vsync: vsync,
        value: 1,
        duration: const Duration(milliseconds: 180),
      );

  final AnimationController _anim;
  bool _gorunur = true;

  Listenable get animasyon => _anim;

  /// 1 = tam açık, 0 = tamamen gizli.
  double get gorunurluk => _anim.value;

  void kaydirmaDegisti(ScrollPosition konum) {
    final g = ustBarGorunsun(
      gorunur: _gorunur,
      piksel: konum.pixels,
      azamiKaydirma: konum.maxScrollExtent,
      yon: konum.userScrollDirection,
    );
    if (g == _gorunur) return;
    _gorunur = g;
    if (g) {
      _anim.forward();
    } else {
      _anim.reverse();
    }
  }

  /// Barı anında geri getirir (liste başa döndüğünde / yenilendiğinde).
  void goster() {
    _gorunur = true;
    _anim.value = 1;
  }

  void dispose() => _anim.dispose();
}

/// Üst barı [gorunurluk] oranında kırpan sarmalayıcı.
///
/// Bar yukarı KAYAR (aşağıdan kırpılmaz): görünen kısım hep alt kenardır,
/// yani başlık durum çubuğunun altına süzülür — Material'ın kendi
/// `SliverAppBar(floating: true)` davranışıyla aynı his.
///
/// DURUM ÇUBUĞU YERİNDE KALIR: Scaffold barın yüksekliğine
/// `MediaQuery.padding.top` ekliyor. O dolgu burada elle çizilir ve çocuğun
/// kendi `SafeArea`sı `removePadding` ile susturulur — yoksa dolgu iki kez
/// sayılır ve bar 20-50 dp fazla yer kaplardı.
class GizlenenUstBar extends StatelessWidget implements PreferredSizeWidget {
  /// Gerçek bar (AppBar).
  final PreferredSizeWidget cocuk;

  /// 0 = gizli, 1 = açık.
  final double gorunurluk;

  const GizlenenUstBar({
    super.key,
    required this.cocuk,
    required this.gorunurluk,
  });

  double get _oran => gorunurluk.clamp(0.0, 1.0);

  @override
  Size get preferredSize => Size.fromHeight(cocuk.preferredSize.height * _oran);

  @override
  Widget build(BuildContext context) {
    final tam = cocuk.preferredSize.height;
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      // ClipRect DOLGUNUN İÇİNDE: dışında olsaydı yukarı taşan bar durum
      // çubuğu şeridinin üstüne çizilirdi.
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.bottomCenter,
          minHeight: tam,
          maxHeight: tam,
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: cocuk,
          ),
        ),
      ),
    );
  }
}
