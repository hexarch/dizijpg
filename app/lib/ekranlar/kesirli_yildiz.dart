import 'package:flutter/material.dart';

import '../tema.dart';

/// Kısmen dolu yıldız — 13 Eyl 2026, ondalıklı puanlama (bkz. `puan.dart`,
/// `yildizOndalikAdim`).
///
/// NEDEN GEREKLİ: puan artık yıldız başına 0,1 adımla veriliyor. Dolu/boş iki
/// ikonla 4,6 puanı ÇİZİLEMEZ — kullanıcı "4.6/5" yazısını görür ama şeritte
/// 5 dolu yıldız sayar ve yazıya değil şeride inanır.
///
/// NEDEN STACK + CLIP, NEDEN ÖZEL BOYA DEĞİL: dolu (`star_rounded`) ve boş
/// (`star_outline_rounded`) ikonlar AYNI glifin iki hâli; üst üste konunca
/// kenarları birebir oturur. Dolu olanı soldan `dolu` oranında kırpmak hem
/// Material ikon setine sadık kalır hem de ölçek/tema değişimlerinde kendi
/// başına doğru kalır. Elle çizilen bir yıldız poligonu ikon setiyle ilk
/// güncellemede ayrışırdı.
///
/// KIRPMA ORANI GLİFİN TAMAMINA UYGULANIR (ikon kutusuna değil): Material
/// ikonlarında glif kutunun içinde ~%8 boşlukla durur, kutuya göre kırpsaydık
/// 0,1'lik dolgu hiç görünmez, 0,9'luk dolgu tam görünürdü. [_icDoluluk]
/// oranı o boşluğu atarak eşler.
class KesirliYildiz extends StatelessWidget {
  /// 0 = boş, 1 = tam dolu. Arası kısmen dolu.
  final double dolu;
  final double boy;

  /// Dolu kısmın rengi (varsayılan: marka sarısı).
  final Color? renk;

  /// Boş kısmın rengi.
  final Color? bosRenk;

  const KesirliYildiz({
    super.key,
    required this.dolu,
    required this.boy,
    this.renk,
    this.bosRenk,
  });

  /// Glifin ikon kutusu içinde kapladığı yatay pay (Material ikonlarında
  /// 24'lük kutuda ~2 birim kenar boşluğu vardır).
  static const double _kenarPayi = 0.08;

  /// Görünen doluluğu glifin kendi genişliğine göre yeniden ölçekler.
  double get _icDoluluk {
    if (dolu <= 0) return 0;
    if (dolu >= 1) return 1;
    return (_kenarPayi + dolu * (1 - 2 * _kenarPayi)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final bos = Icon(
      Icons.star_outline_rounded,
      size: boy,
      color: bosRenk ?? DiziRenkler.metin38,
    );
    if (dolu <= 0) return bos;
    final tam = Icon(
      Icons.star_rounded,
      size: boy,
      color: renk ?? DiziRenkler.sari,
    );
    if (dolu >= 1) return tam;
    return Stack(
      // Kırpılmış dolu yıldız boş olanın ÜSTÜNDE ve sol kenarına hizalı.
      alignment: Alignment.centerLeft,
      children: [
        bos,
        // ClipRect + widthFactor: Align kutusunu daraltır, ClipRect taşan
        // kısmı keser. `widthFactor` tek başına yetmez — çocuk kutudan taşıp
        // yine tam çizilirdi.
        ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: _icDoluluk,
            child: tam,
          ),
        ),
      ],
    );
  }
}
