/// Madde 17 — PUAN DAĞILIMI (IMDb tarzı).
///
/// "Şu kadar kişi 3 yıldız verdi, şu kadar kişi 5 yıldız verdi" grafiği.
/// Detay sayfasındaki `4.2 dizi.jpg` rozetine dokununca alt sayfada açılır.
///
/// TASARIM KARARLARI (ui-ux-pro-max: Charts & Data + Touch & Interaction):
///  * Yatay çubuk — "kategori karşılaştırma" için önerilen biçim, 5 kategori
///    eşiğin (≤15) çok altında.
///  * SAYI HER ÇUBUKTA YAZILI: uzunluk/renk tek başına bilgi taşımaz
///    (erişilebilirlik kuralı). Ekran okuyucu için ayrıca satır bazlı
///    `Semantics` etiketi var.
///  * SIRALAMA 5→1, değere göre DEĞİL. Veritabanındaki "kategoriyi değere göre
///    azalan sırala" kuralı NOMİNAL kategoriler içindir; yıldız SIRALI bir
///    ölçektir, karıştırmak grafiği okunmaz yapardı (IMDb/Letterboxd da 5→1).
///  * Kullanıcının kendi puanı vurgulanır: renk TEK BAŞINA ayırt edici değil,
///    yanına ikon + `Puanın` etiketi konur.
///  * Hareket azaltma açıksa çubuklar animasyonsuz çizilir.
///
/// ALT SAYFA YÜKSEKLİĞİ (kullanıcı bildirimi 2026-08-14: "açılan div belirli
/// oranda açılıyor ama komple açılması gerekiyor"):
/// `showModalBottomSheet` varsayılanı sheet'i ekranın 9/16'sına (~%56) KISITLAR
/// ve içerik sığmayınca alttan KESER — büyük yazı tipi/uzun çeviride son çubuk
/// görünmüyordu. `isScrollControlled: true` bu tavanı kaldırır.
///
/// Neden `DraggableScrollableSheet` DEĞİL (gönderi istatistiğinden ayrılıyoruz):
/// oradaki içerik dört bölüm + iki grafik, hep tek ekrandan uzun — sabit bir
/// `initialChildSize` (0.85) mantıklı. BURADAKİ içerik SABİT ve KISA: başlık +
/// özet + her zaman tam 5 çubuk. Sabit oran seçmek ya kısa ekranda keser ya da
/// uzun ekranda yarısı boş bir panel açardı. Bu yüzden sheet İÇERİĞE göre
/// boyutlanır (`mainAxisSize.min`), tavanı ekranın %90'ı; içerik o tavanı
/// aşarsa (çok büyük yazı ölçeği) kaydırılır. Yani "komple açılır" = içeriğin
/// TAMAMI görünür, ekranı gereksiz kaplamadan.
library;

import 'package:flutter/material.dart';

import '../ceviri.dart';
import '../puan.dart';
import '../tema.dart';
import 'ortak.dart';

/// Dağılım alt sayfasını açar. Veri yoksa (hiç puan yok) HİÇ açılmaz —
/// boş bir grafik göstermek, dokunuşun karşılıksız kalması demektir.
void puanDagilimiAc(
  BuildContext context, {
  required Object? dagilim,
  required Object? ortalama,
  int? benimDbPuani,
}) {
  final kovalar = yildizDagilimi(dagilim);
  final toplam = kovalar.values.fold<int>(0, (t, a) => t + a);
  if (toplam == 0) return;
  showModalBottomSheet(
    context: context,
    backgroundColor: DiziRenkler.koyuGri,
    // Tavanı kaldırır: sheet artık 9/16 ekranla sınırlı değil, içeriği kadar.
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => PuanDagilimiSheet(
      kovalar: kovalar,
      ortalama: ortalama,
      benimDbPuani: benimDbPuani,
    ),
  );
}

class PuanDagilimiSheet extends StatelessWidget {
  final Map<int, int> kovalar;
  final Object? ortalama;
  final int? benimDbPuani;

  const PuanDagilimiSheet({
    super.key,
    required this.kovalar,
    this.ortalama,
    this.benimDbPuani,
  });

  @override
  Widget build(BuildContext context) {
    final toplam = kovalar.values.fold<int>(0, (t, a) => t + a);
    // `bottom: false` + gövdenin `altGuvenli`si: alt boşluğu TEK yerden veririz.
    // İkisi birden açık olsaydı sistem çubuğu payı İKİ KEZ eklenirdi.
    return SafeArea(
      bottom: false,
      child: ConstrainedBox(
        // Tavan: içerik bundan uzunsa (çok büyük yazı ölçeği) kaydırılır,
        // kısaysa sheet içeriği kadar açılır — boş panel yok, kesik içerik yok.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          child: Padding(
            key: const Key('puan-dagilimi-govde'),
            padding: EdgeInsets.fromLTRB(16, 10, 16, altGuvenli(context)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sürükleme tutamağı — diğer sheet'lerle aynı görsel dil
                // (gonderi_istatistik.dart, beğenenler, paylaş).
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: DiziRenkler.metin24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      Icons.bar_chart,
                      color: DiziRenkler.sariMetin,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    // Uzun çevirilerde sarsın diye Expanded (madde 46 ailesi).
                    Expanded(
                      child: Text(
                        'Puan dağılımı'.c,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (ortalama != null) ...[
                      Icon(Icons.star, color: DiziRenkler.sariMetin, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        yildizOrtalamaMetni(ortalama),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        '{} kişi puanladı'.cf([toplam]),
                        style: TextStyle(
                          color: DiziRenkler.metin70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                PuanDagilimiGrafigi(
                  kovalar: kovalar,
                  benimDbPuani: benimDbPuani,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grafiğin kendisi — sheet'ten ayrı, çünkü ileride detay sayfasına gömülü de
/// kullanılabilir ve testte tek başına kurulabilir.
class PuanDagilimiGrafigi extends StatelessWidget {
  /// 1..5 → kişi sayısı. Boş kovalar 0 ile gelir ([yildizDagilimi] garanti eder).
  final Map<int, int> kovalar;

  /// Kullanıcının KENDİ puanı, ham DB ölçeğinde (1-10). Yıldıza burada çevrilir
  /// ki kova eşleşmesi ekrandaki yıldızla aynı işlevden çıksın.
  final int? benimDbPuani;

  const PuanDagilimiGrafigi({
    super.key,
    required this.kovalar,
    this.benimDbPuani,
  });

  @override
  Widget build(BuildContext context) {
    // Çubuk boyu EN KALABALIK kovaya göre ölçeklenir (toplama göre değil):
    // 5 kova arasındaki FARK okunacak; toplama bölünce hepsi cılız kalırdı.
    final enBuyuk = kovalar.values.fold<int>(0, (e, a) => a > e ? a : e);
    final benim = benimDbPuani == null ? 0 : yildiza(benimDbPuani);
    final sure = Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 350,
    );
    return Column(
      children: [
        for (var yildiz = yildizAzami; yildiz >= 1; yildiz--)
          _Satir(
            yildiz: yildiz,
            adet: kovalar[yildiz] ?? 0,
            enBuyuk: enBuyuk,
            benimKovam: yildiz == benim,
            sure: sure,
          ),
      ],
    );
  }
}

class _Satir extends StatelessWidget {
  final int yildiz;
  final int adet;
  final int enBuyuk;
  final bool benimKovam;
  final Duration sure;

  const _Satir({
    required this.yildiz,
    required this.adet,
    required this.enBuyuk,
    required this.benimKovam,
    required this.sure,
  });

  @override
  Widget build(BuildContext context) {
    final oran = enBuyuk <= 0 ? 0.0 : adet / enBuyuk;
    // Yan sütunların (yıldız etiketi / sayı) genişliği YAZI ÖLÇEĞİYLE büyür.
    // 34 dp sabitti: sistem yazı boyu 2 katına çıkınca satır yatayda TAŞIYORDU
    // (sheet artık tam açıldığı için bu taşma testte görünür oldu). Tavan 96:
    // çubuk 4 kat ölçekte bile ezilmesin. İçerideki `FittedBox` son güvence —
    // dört haneli sayı + devasa ölçek gibi uç birleşimde yazı bir tık küçülür,
    // taşma ASLA olmaz.
    final yanEn = MediaQuery.textScalerOf(context).scale(34).clamp(34.0, 96.0);
    return Semantics(
      // Ekran okuyucu tek cümle duysun: "4 yıldız: 32 kişi puanladı".
      label:
          '${'{} yıldız'.cf([yildiz])}: ${'{} kişi puanladı'.cf([adet])}'
          '${benimKovam ? ' (${'Puanın'.c})' : ''}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            // Yıldız etiketi: sabit genişlik, sayı + ikon (yalnız renk değil).
            SizedBox(
              width: yanEn,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$yildiz',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: benimKovam
                            ? DiziRenkler.sariMetin
                            : DiziRenkler.metin70,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.star,
                      size: 13,
                      color: benimKovam
                          ? DiziRenkler.sariMetin
                          : DiziRenkler.metin54,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  height: 10,
                  color: DiziRenkler.metin12,
                  alignment: AlignmentDirectional.centerStart,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: oran),
                    duration: sure,
                    curve: Curves.easeOutCubic,
                    builder: (_, deger, _) => FractionallySizedBox(
                      widthFactor: deger.clamp(0.0, 1.0),
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          // Kendi kovan daha parlak; ayrım YALNIZ renkle
                          // yapılmıyor (etiket + ikon da değişiyor).
                          color: benimKovam
                              ? DiziRenkler.acikSari
                              : DiziRenkler.sari,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Sayı HER ZAMAN yazılı (erişilebilirlik): 3 hane için sabit alan,
            // çubuk uçları hizada kalsın.
            SizedBox(
              width: yanEn,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  '$adet',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: benimKovam ? FontWeight.w800 : FontWeight.w600,
                    color: benimKovam
                        ? DiziRenkler.sariMetin
                        : DiziRenkler.metin,
                  ),
                ),
              ),
            ),
            if (benimKovam) ...[
              const SizedBox(width: 6),
              Icon(Icons.person, size: 14, color: DiziRenkler.sariMetin),
            ],
          ],
        ),
      ),
    );
  }
}
