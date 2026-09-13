/// YANIT AĞACI — bir iş parçacığının satırlarını Reddit kalıbında sıralar.
///
/// KULLANICI BİLDİRİMİ (13 Eyl 2026, birebir): "akışta bir gönderiye yorum
/// yapmış birinin yorumuna yanıt verince gönderiye yorum yapmış gibi oluyorum
/// ama oysa Reddit'teki gibi gönderideki yorumun altına azıcık sağlı olarak
/// yorum gözükmeliydi."
///
/// VERİ SÖZLEŞMESİ (backend/migrasyon-2026-09-13.sql):
///   · `ust_id`   → iş parçacığının KÖKÜ (gönderi). Her yanıtta aynı; sunucu
///                  bilerek düzlüyor ("ust_id IS NULL = gönderi" sözleşmesi).
///   · `yanit_id` → DOĞRUDAN yanıtlanan yorum. NULL ise satır gönderinin
///                  altındadır (0. düzey).
/// Bu fonksiyon düz listeyi o ikinci alandan ağaca dizer ve her satıra bir
/// [YorumDugumu.derinlik] verir; girintiyi çizen widget'lar odur.
///
/// ESKİ SATIRLAR (13 Eyl öncesi yanıtlar) `yanit_id` taşımaz → hepsi 0. düzeyde
/// kalır ve liste bugünkü gibi düz görünür. Yani bu değişiklik geçmişi
/// BOZMAZ, yalnız yenisini doğru çizer.
library;

import 'package:flutter/material.dart';

import 'tema.dart';

/// Ağaçtaki tek satır: yorumun kendisi + kaç kademe içeride çizileceği.
class YorumDugumu {
  final Map<String, dynamic> yorum;

  /// 0 = doğrudan gönderiye yazılmış yorum, 1 = ona verilen yanıt, …
  final int derinlik;

  const YorumDugumu(this.yorum, this.derinlik);

  int get id => yorum['id'] as int;
}

/// GİRİNTİ TAVANI — bundan sonrası aynı hizada çizilir.
///
/// Neden tavan var: sheet telefonda 360 dp; her kademe 14 dp yerse 7. kademede
/// metin sütunu avatarla birlikte ~100 dp'ye iner ve yanıt okunmaz olur.
/// Reddit de aynı yerde (derin zincirde) girintiyi bırakır. 4 kademe pratikte
/// bütün iş parçacıklarını karşılıyor: en uzun zincir bugün 3.
const int yorumGirintiTavani = 4;

/// Bir kademe girinti (dp). "Azıcık sağlı" — avatar yarıçapı 14 dp olduğu için
/// bundan büyüğü satırı hızla daraltır, küçüğü ise kademeyi göz seçemez.
const double yorumGirintiAdimi = 14;

/// [tumu] iş parçacığının TÜM satırları (kökün kendisi hariç; çağıran zaten
/// `ust_id == kokId` diye süzmüş olur), [kokId] gönderinin id'si.
///
/// Çıktı EKRAN SIRASINDA: her yanıt, yanıtladığı satırın hemen altında ve bir
/// kademe içeride. Kardeşler eskiden yeniye (id artan) — sohbet akışının aynısı.
List<YorumDugumu> yorumAgaci(Iterable<dynamic> tumu, int kokId) {
  final satirlar = <int, Map<String, dynamic>>{};
  for (final y in tumu) {
    final m = (y as Map).cast<String, dynamic>();
    final id = m['id'];
    if (id is int) satirlar[id] = m;
  }

  // Çocuk listeleri: anahtar = ebeveyn id (kök için [kokId]).
  final cocuklar = <int, List<Map<String, dynamic>>>{};
  for (final m in satirlar.values) {
    final hedef = m['yanit_id'];
    // EBEVEYN YALNIZ AYNI PARÇACIKTAN VE DAHA ESKİ OLABİLİR:
    //  · listede yoksa (silinmiş ya da engellenen kişinin yanıtı süzülmüş)
    //    satır öksüz kalmasın diye kökün altına düşer — görünmeyen bir
    //    ebeveynin altında kaybolmaktansa düz çizilsin.
    //  · id karşılaştırması döngüye karşı emniyet: yanıt her zaman
    //    yanıtladığından SONRA yazılır, yani id'si BÜYÜKTÜR. Bozuk bir satır
    //    (elle düzenlenmiş veri) sonsuz özyineleme yaratamaz.
    final ebeveyn =
        hedef is int &&
            hedef != m['id'] &&
            satirlar.containsKey(hedef) &&
            hedef < (m['id'] as int)
        ? hedef
        : kokId;
    (cocuklar[ebeveyn] ??= []).add(m);
  }
  for (final liste in cocuklar.values) {
    liste.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
  }

  // Derinlik-öncelikli gezinti — ÖZYİNELEMESİZ (yığınla): 1.000 satırlık bir
  // parçacıkta bile çağrı yığını taşmaz.
  final sonuc = <YorumDugumu>[];
  final yigin = <YorumDugumu>[];
  for (final m in (cocuklar[kokId] ?? const []).reversed) {
    yigin.add(YorumDugumu(m, 0));
  }
  while (yigin.isNotEmpty) {
    final d = yigin.removeLast();
    sonuc.add(d);
    for (final c in (cocuklar[d.id] ?? const []).reversed) {
      yigin.add(YorumDugumu(c, d.derinlik + 1));
    }
  }
  return sonuc;
}

/// Bir yanıt satırını ağaçtaki yerine göre içeri alan sarmalayıcı.
///
/// Girinti TEK BAŞINA yetmez: iki kademe arası 14 dp ve satırlar uzun olduğu
/// için göz, alttaki satırın hangi yoruma bağlı olduğunu kaybediyordu. Sol
/// kenardaki 1 dp'lik çizgi (Reddit'in "thread line"ı) bağı sürekli tutar.
/// 0. düzeyde çizgi YOK: gönderiye doğrudan yazılan yorumlar zaten aynı
/// hizada ve çizgi orada yalnız gürültü olurdu.
class YorumGirintisi extends StatelessWidget {
  final int derinlik;
  final Widget child;

  const YorumGirintisi({
    super.key,
    required this.derinlik,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (derinlik <= 0) return child;
    final kademe = derinlik.clamp(1, yorumGirintiTavani);
    return Container(
      margin: EdgeInsets.only(left: kademe * yorumGirintiAdimi),
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: DiziRenkler.metin24)),
      ),
      child: child,
    );
  }
}
