// Uygulama daveti — mobil/tablet TARAYICIDA açılan "uygulamayı indir" penceresi.
//
// Instagram/TikTok'un mobil webde gösterdiği alt sayfa (bottom sheet) kalıbı:
// içerik arkada görünür, pencere alttan gelir, ÇARPI ile kapanır ve kapatan
// kullanıcı bir süre bir daha rahatsız edilmez.
//
// TASARIM — neden Dialog DEĞİL, `MaterialApp.builder` içinde bir Stack katmanı:
// `showDialog` Navigator ister; builder'ın context'i Navigator'ın ÜSTÜNDEDİR
// (aynı gerekçe `surum_kapisi.dart`ta da yazılı). Katman olarak çizilince
// pencere her rotanın üstünde durur, rota değişimi onu kapatmaz.
//
// SIRA: sürüm kapısı BU KATMANIN ÜSTÜNDEDİR — zorunlu güncelleme ekranı
// varken indirme daveti onun altında kalmalı (main.dart'taki sarmalama).
//
// GÖSTERİLMEDİĞİ HALLER (hepsi `uygulama_daveti_web.dart`ta gerekçeli):
// native derleme, masaüstü tarayıcı, bot/ölçüm aracı, ana ekrana eklenmiş PWA
// ve son [_sessizlik] içinde daveti kapatmış ziyaretçi.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ceviri.dart';
import 'tema.dart';
import 'uygulama_daveti_hedef.dart';
import 'uygulama_daveti_platform.dart';

/// Daveti kapatan ziyaretçinin bir daha rahatsız edilmeyeceği süre.
/// Oturum başına değil GÜN bazında: aynı kullanıcı her sekmede yeniden
/// pencereyle karşılaşırsa davet reklamdan farksız olur.
const _sessizlik = Duration(days: 7);

/// Kapatma/indirme anının kaydedildiği yer (web'de localStorage'a düşer).
const _sessizlikAnahtari = 'uygulama_daveti_son';

/// Pencerenin ekrana gelmeden önce beklediği süre: ilk kare çizilsin, ziyaretçi
/// ARKADAKİ İÇERİĞİ görsün. Sıfır olsaydı davet açılış ekranının üstüne
/// binerdi ve "ne olduğunu görmeden kapat" refleksi doğardı.
const _gecikme = Duration(milliseconds: 900);

class UygulamaDaveti extends StatefulWidget {
  const UygulamaDaveti({
    super.key,
    required this.cocuk,
    this.hedefOku = davetHedefi,
    this.gecikme = _gecikme,
  });

  final Widget cocuk;

  /// Testten sahte platform verilebilsin diye ayrık (varsayılan: tarayıcı
  /// tespiti).
  final DavetHedefi Function() hedefOku;

  /// Testte sıfırlanabilsin diye ayrık.
  final Duration gecikme;

  /// Uygulama ömrü boyunca tek olan gösterme kararını sıfırlar.
  /// YALNIZ TEST İÇİN: testler aynı süreçte koştuğu için statik bayrak
  /// bir testten diğerine sızar (ilk test daveti kapatınca sonraki test
  /// hiç göremez).
  @visibleForTesting
  static void testSifirla() {
    _UygulamaDavetiState._bakildi = false;
    _UygulamaDavetiState._hedef = null;
  }

  @override
  State<UygulamaDaveti> createState() => _UygulamaDavetiState();
}

class _UygulamaDavetiState extends State<UygulamaDaveti> {
  // Uygulama ömrü boyunca TEK karar: dil/tema değişiminde ağaç baştan kurulur
  // (main.dart'taki anahtar), initState yeniden çalışır. Bayrak static olmasa
  // pencere her tema değişiminde geri gelirdi.
  static bool _bakildi = false;
  static DavetHedefi? _hedef;

  @override
  void initState() {
    super.initState();
    if (!_bakildi) {
      _bakildi = true;
      _hazirla();
    }
  }

  Future<void> _hazirla() async {
    final hedef = widget.hedefOku();
    if (hedef == DavetHedefi.yok) return;
    if (await _sessizMi()) return;
    await Future<void>.delayed(widget.gecikme);
    if (!mounted) return;
    setState(() => _hedef = hedef);
  }

  Future<bool> _sessizMi() async {
    try {
      final depo = await SharedPreferences.getInstance();
      final son = depo.getInt(_sessizlikAnahtari) ?? 0;
      if (son <= 0) return false;
      final gecen = DateTime.now().millisecondsSinceEpoch - son;
      return gecen >= 0 && gecen < _sessizlik.inMilliseconds;
    } catch (_) {
      // Depo okunamazsa (gizli sekme, kota) davet gösterilsin.
      return false;
    }
  }

  Future<void> _sessizeAl() async {
    try {
      final depo = await SharedPreferences.getInstance();
      await depo.setInt(
        _sessizlikAnahtari,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // Yazılamazsa en kötü ihtimalle davet sonraki ziyarette tekrar çıkar.
    }
  }

  void _kapat() {
    setState(() => _hedef = null);
    _sessizeAl();
  }

  Future<void> _indir(DavetMagaza magaza) async {
    // Mağazaya giden ziyaretçi de "kapatmış" sayılır: dönüp geldiğinde aynı
    // pencereyle karşılaşmasın.
    _kapat();
    final adres = Uri.tryParse(magaza.adres);
    if (adres == null) return;
    // `_self`: mağaza adresi AYNI sekmede açılır — mobil işletim sistemi bunu
    // yakalayıp Play/App Store uygulamasını açar, geri tuşu siteye döner.
    // Yeni sekme açsaydık ziyaretçi boş bir sekmeye düşerdi.
    await launchUrl(adres, webOnlyWindowName: '_self');
  }

  @override
  Widget build(BuildContext context) {
    final hedef = _hedef;
    return Stack(
      children: [
        widget.cocuk,
        if (hedef != null)
          Positioned.fill(
            child: UygulamaDavetiKatmani(
              hedef: hedef,
              onIndir: _indir,
              onKapat: _kapat,
            ),
          ),
      ],
    );
  }
}

/// Davet penceresinin kendisi. Testten doğrudan kurulabilsin diye public
/// (bkz. test/uygulama_daveti_test.dart).
class UygulamaDavetiKatmani extends StatelessWidget {
  const UygulamaDavetiKatmani({
    super.key,
    required this.hedef,
    required this.onIndir,
    required this.onKapat,
  });

  final DavetHedefi hedef;
  final void Function(DavetMagaza magaza) onIndir;
  final VoidCallback onKapat;

  @override
  Widget build(BuildContext context) {
    final metin = Theme.of(context).textTheme;
    final yaziRengi = DiziRenkler.acik ? const Color(0xFF17171A) : Colors.white;
    final ikiMagaza = hedef == DavetHedefi.ikisi;
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: Stack(
        children: [
          // Karartmaya dokunmak da kapatır (Instagram/TikTok davranışı).
          // `behavior: opaque` olmadan boş alan dokunuşu ALTTAKİ uygulamaya
          // geçer ve ziyaretçi pencerenin arkasındaki düğmeye basmış olur.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onKapat,
              child: const SizedBox.expand(),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              tween: Tween<double>(begin: 1, end: 0),
              builder: (context, deger, cocuk) => FractionalTranslation(
                translation: Offset(0, deger),
                child: cocuk,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  decoration: BoxDecoration(
                    color: DiziRenkler.koyuGri,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              onPressed: onKapat,
                              tooltip: 'Kapat'.c,
                              icon: const Icon(Icons.close),
                              color: DiziRenkler.acikGri,
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Logo koyu zemin için çizildi: açık temada
                              // marka pulu (markaKoyu) altına konur.
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: DiziRenkler.markaKoyu,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Image.asset(
                                  'assets/logo.png',
                                  width: 48,
                                  height: 48,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'dizi.jpg uygulamasını indir'.c,
                                      style: metin.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: yaziRengi,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Daha hızlı gezinme, bildirimler ve tam ekran deneyim uygulamada.'
                                          .c,
                                      style: metin.bodySmall?.copyWith(
                                        color: DiziRenkler.acikGri,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          if (ikiMagaza) ...[
                            _MagazaDugmesi(
                              magaza: DavetMagaza.play,
                              ikon: Icons.android,
                              etiket: 'Google Play',
                              dolgulu: true,
                              onBas: onIndir,
                            ),
                            const SizedBox(height: 10),
                            _MagazaDugmesi(
                              magaza: DavetMagaza.appStore,
                              ikon: Icons.apple,
                              etiket: 'App Store',
                              dolgulu: false,
                              onBas: onIndir,
                            ),
                          ] else
                            _MagazaDugmesi(
                              magaza: hedef == DavetHedefi.ios
                                  ? DavetMagaza.appStore
                                  : DavetMagaza.play,
                              ikon: hedef == DavetHedefi.ios
                                  ? Icons.apple
                                  : Icons.android,
                              etiket: 'Uygulamayı indir'.c,
                              dolgulu: true,
                              onBas: onIndir,
                            ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: onKapat,
                            child: Text(
                              'Tarayıcıda devam et'.c,
                              style: TextStyle(color: DiziRenkler.acikGri),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MagazaDugmesi extends StatelessWidget {
  const _MagazaDugmesi({
    required this.magaza,
    required this.ikon,
    required this.etiket,
    required this.dolgulu,
    required this.onBas,
  });

  final DavetMagaza magaza;
  final IconData ikon;
  final String etiket;
  final bool dolgulu;
  final void Function(DavetMagaza magaza) onBas;

  @override
  Widget build(BuildContext context) {
    // Dikey 14 dolgu = ~48 px dokunma hedefi (44 px alt sınırının üstünde).
    const dolgu = EdgeInsets.symmetric(vertical: 14);
    final icerik = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ikon, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            etiket,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
    if (dolgulu) {
      return FilledButton(
        onPressed: () => onBas(magaza),
        style: FilledButton.styleFrom(
          backgroundColor: DiziRenkler.sari,
          foregroundColor: Colors.black,
          padding: dolgu,
        ),
        child: icerik,
      );
    }
    return OutlinedButton(
      onPressed: () => onBas(magaza),
      style: OutlinedButton.styleFrom(
        foregroundColor: DiziRenkler.sariMetin,
        side: BorderSide(color: DiziRenkler.sariMetin),
        padding: dolgu,
      ),
      child: icerik,
    );
  }
}
