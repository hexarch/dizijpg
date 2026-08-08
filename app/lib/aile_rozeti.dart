import 'package:flutter/material.dart';

import 'ceviri.dart';
import 'tema.dart';

/// Kapalı test (Play Console) ekibinin profil nişanı: **kullanıcı adının hemen
/// yanında altın renkli onay tiki**.
///
/// KULLANICI İSTEĞİ (5 Ağu 2026): "tester olarak eklediğimiz mail adresinden
/// kayıt olan kullanıcıların profilinde ülke bayrağı yanında dizi.jpg logosu
/// koy ve yanına yaz" — o gün etiketli rozet ("Founding Member" yazısı +
/// dizi.jpg logosu) ülke satırının yanına konmuştu.
///
/// KULLANICI İSTEĞİ (7 Ağu 2026): "Profildeki fonding member yazısını ve
/// dizi jpg yazısını kaldır, kullanıcı adının yanına gold renkde onaylı
/// iconu koy (tabi sadece test kullanıcı olarak belirlediğimiz kişilerde
/// bunlar olacak)" — rozet METİNSİZ bir tike indi ve ülke satırından çıkıp
/// kullanıcı adının yanına taşındı. `DiziLogosu` ile birlikte metin de gitti.
///
/// --- NEDEN `sariMetin`, MARKA SARISI DEĞİL ---
/// Onay tiki bir GRAFİK NESNE; WCAG 1.4.11 eşiği 3:1. Marka sarısı (#F5C518)
/// koyu temada muhteşem ama AÇIK temada kırık beyaz zemine karşı **1,51:1** —
/// tik kaybolur (ölçüm: `kontrast.py`, üç zemin × beş aday). Tema-duyarlı
/// `sariMetin` her iki temada da geçer:
///
///   zemin                 #F5C518   sariMetin
///   koyu scaffold #0B0B0D  12,06 ✓   4,00 ✓
///   koyu kart     #1F1F23  10,08 ✓   3,34 ✓
///   açık scaffold #F6F6F8   1,51 ✗   4,56 ✓
///   açık kart     #FFFFFF   1,63 ✗   4,92 ✓
///   açık sheet    #ECECEF   1,38 ✗   4,17 ✓
///
/// Ayrı bir "altın" ton (ör. #B8860B) denendi: açık sheet zemininde 2,76 ile
/// eşiğin ALTINDA kaldı. Projede zaten sarı metin/ikonun tek doğru yolu
/// `sariMetin`; onay tiki de oradan boyanır.
///
/// --- NEDEN `Icons.verified` ---
/// Material'ın dolu mührü; çek işareti mührün İÇİNDE OYULMUŞ (saydam), yani
/// zeminin rengiyle görünür. Koyu temada altın mühür + koyu çek (12,06:1),
/// açık temada hardal mühür + beyaz çek (4,92:1) — iki temada da çek okunur.
/// Emoji kullanılmadı (skill kuralı: yapısal ikon = vektör ikon).
///
/// --- NEDEN 44 dp ---
/// Tik TIKLANABİLİR (ne olduğunu anlatan alt sayfayı açar) ve İKON-ONLY:
/// dokunma hedefi 44x44 dp, ekran okuyucu için `Semantics(label:)` şart.
/// Mürekkep 18 dp kalır, gerisi dolgudur. Flutter'da ebeveyn sınırının dışına
/// taşan alan çizilse bile hit-test ALMAZ, o yüzden hedef kutunun kendisi
/// büyütülür.
///
/// Bu 44 dp kullanıcı adı satırını yükseltir ama TOPLAM yükseklik DÜŞER:
/// eski etiketli rozet zaten 44 dp'lik ayrı bir satırdaydı (ülkesi olmayan
/// testçide o satır tek başına duruyordu), şimdi o satır tamamen kalktı.
class AileRozeti extends StatelessWidget {
  const AileRozeti({super.key, this.benMi = false, this.olcu = 18});

  /// Bakılan profil oturumun sahibine mi ait? Modalın gövde cümlesi buna göre
  /// ikinci tekil şahsa döner ("...birisin"). Kaynağı sunucunun `ben_mi`
  /// yargısıdır; `kullanici_profil.dart` kendi kullanıcı adınla da açılabildiği
  /// için ekranın türüne bakmak YETMEZ.
  final bool benMi;

  /// Tik mürekkebinin boyutu (dokunma hedefi buna bakmaz, hep 44 dp).
  /// Kullanıcı adının punto'suyla orantılı verilir.
  final double olcu;

  /// Nişanın adı — modal başlığında görünür. Unvan/marka terimi olduğu için
  /// 45 dilde aynı kalır (bkz. `aileRozetiSheet`).
  static const String etiket = 'Founding Member';

  /// İkon-only olduğu için ekran okuyucunun okuyacağı metin.
  static const String erisimEtiketi = 'Doğrulanmış testçi';

  /// Dokunma hedefi (dp). Testler bu sabiti okur.
  static const double hedef = 44;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: erisimEtiketi.c,
      child: InkWell(
        onTap: () => aileRozetiSheet(context, benMi: benMi),
        borderRadius: BorderRadius.circular(hedef / 2),
        child: SizedBox(
          width: hedef,
          height: hedef,
          child: Center(
            child: Icon(
              Icons.verified,
              size: olcu,
              color: DiziRenkler.sariMetin,
              // Etiketi ÜSTTEKİ Semantics veriyor; ikon kendi düğümünü
              // açarsa ekran okuyucu aynı şeyi iki kez söyler.
              semanticLabel: null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tikin ne anlama geldiğini anlatan alt sayfa.
///
/// KARAR (7 Ağu): metinli rozet kalkınca modal KORUNDU. Üç gerekçe:
///  1. Tik artık tek başına duran bir SEMBOL — "bu tik ne?" sorusunun tek
///     cevabı bu modal. Etiket varken metin cevabı kendisi veriyordu.
///  2. UX kuralı "bilgiyi yalnız renkle/şekille aktarma": tikin anlamı bir
///     yerde YAZILI olmalı; modal o yazıdır.
///  3. Gövde cümlesi zaten 45 dile çevrili ve testli — silmek ölü çeviri
///     anahtarı bırakırdı.
///
/// Projedeki alt sayfa kalıbının aynısı (`begenenler.dart`, `paylas.dart`):
/// yuvarlatılmış üst köşeler, sürükleme tutamağı ve **SafeArea**. SafeArea
/// şart: bu hafta üç modalde (ListeSheet, takvim gün detayı, puan verme) alt
/// içerik sistem gezinme çubuğunun altında kalmıştı.
///
/// Kapanma yolları: tutamaktan aşağı sürükleme, dışına dokunma (barrier) ve
/// "Kapat" düğmesi.
Future<void> aileRozetiSheet(BuildContext context, {required bool benMi}) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: DiziRenkler.koyuGri,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AileRozetiSheet(benMi: benMi),
    );

/// Gövde cümlesinin ÜÇÜNCÜ ŞAHIS varyantı (başkasının profili).
const String aileRozetiBaskasi =
    'İlk kullanıcılarımızdan biri. Geri bildirimleriyle uygulamanın bugün '
    'olduğu hale gelmesine katkı sağladı.';

/// Gövde cümlesinin İKİNCİ TEKİL ŞAHIS varyantı (kendi profilin).
const String aileRozetiBenim =
    'İlk kullanıcılarımızdan birisin. Geri bildirimlerinle uygulamanın bugün '
    'olduğu hale gelmesine katkı sağladın.';

class _AileRozetiSheet extends StatelessWidget {
  const _AileRozetiSheet({required this.benMi});

  final bool benMi;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          // Sürükleme tutamağı (beğenenler/paylaş sheet'iyle aynı ölçü).
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: DiziRenkler.metin24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Row(
              children: [
                // Başlıkta da AYNI tik: dokunulan sembolle açılan sayfa
                // arasında görsel süreklilik (kullanıcı neye bastığını görür).
                Icon(
                  Icons.verified,
                  size: 24,
                  color: DiziRenkler.sariMetin,
                  // Başlık metni zaten okunuyor; ikon sessiz kalsın.
                  semanticLabel: null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AileRozeti.etiket,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: DiziRenkler.sariMetin,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Text(
              (benMi ? aileRozetiBenim : aileRozetiBaskasi).c,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: DiziRenkler.metin70,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Kapat'.c,
                  style: TextStyle(color: DiziRenkler.sariMetin),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
