import 'package:flutter/material.dart';

import '../aile_rozeti.dart' show MiniRozet;
import '../api.dart' show Api;
import '../ceviri.dart';
import '../tema.dart';
import 'ortak.dart';

/// [a] sürümü [b]den YENİ mi? Biçim `x.y.z` ya da `x.y.z+n` (derleme numarası
/// atılır, `Api.surum` onu taşır). Ayrıştırılamayan sürümde `true` döner:
/// bilinmeyeni "ileri" saymak güvenli taraftır — kullanıcıya yanlışlıkla
/// "zaten güncelsin" demektense "güncelle" demek daha az zarar verir.
bool surumIleri(String a, String b) {
  List<int>? parcala(String s) {
    final parcalar = s.split('+').first.split('.');
    if (parcalar.length != 3) return null;
    final sayilar = parcalar.map(int.tryParse).toList();
    return sayilar.any((s) => s == null) ? null : sayilar.cast<int>();
  }

  final sol = parcala(a);
  final sag = parcala(b);
  if (sol == null || sag == null) return true;
  for (var i = 0; i < 3; i++) {
    if (sol[i] != sag[i]) return sol[i] > sag[i];
  }
  return false;
}

/// SÜRÜM TANITIM SAYFASI — `/yenilikler/:surum` (2 Eyl 2026 isteği: "tıklayınca
/// yeni sayfada gelen güncellemeleri tanıtan yazı ve görseller olmalı").
///
/// İÇERİK UYGULAMADA GÖMÜLÜ, SUNUCUDA DEĞİL: bildirim satırı yalnız sürüm
/// numarası taşır (bkz. migrasyon-2026-09-02.sql). Sunucuda tutulsaydı 45 dil
/// × N sürüm metni panelden yönetilmek zorunda kalırdı; burada metinler
/// standart çeviri mekanizmasından geçer ve GERÇEK kullanıcı dillerine
/// çevrilir (2 Eyl ölçümü: tr, en, ru, ar, es, zh, ro — diğer diller Türkçe
/// kaynağa düşer, o dillerde bugün kullanıcı yok).
///
/// GÖRSELLER EKRAN GÖRÜNTÜSÜ DEĞİL, CANLI MİNİ MAKETLER: her kart özelliğin
/// küçük bir taklidini gerçek widget'larla çizer (bildirim satırı, rozetli ad,
/// %60 Reels modalı, üç renkli çubuk). Bitmap görsele göre üç kazanç: tema
/// duyarlı (açık/koyu ikisinde de doğru), pakete boyut eklemez ve içindeki
/// metinler çeviriden geçer.
///
/// TANITIMI OLMAYAN SÜRÜM İKİ AYRI DURUMDUR — 11 Eyl 2026'da yakalandı:
///  1. Kullanıcı GERİDE (istenen sürüm > uygulamanınki): eski uygulama yeni
///     sürümün bildirimini almış. "Uygulamayı güncelle" DOĞRU cümle.
///  2. Kullanıcı GÜNCEL ama o sürüm için kart yazılmamış: 227 (1.148.2)
///     duyurusu gönderilseydi, yeni güncellemiş kullanıcıya "uygulamayı
///     güncelle" denecekti — push "yenilikleri görmek için dokun" derken.
///     Bu hale "görünür yenilik yok, arka planda iyileştirmeler var" denir.
/// Ayrımı [surumIleri] yapar; sessiz boşluk ya da yanlış cümle yasak.
class YeniliklerEkrani extends StatelessWidget {
  final String surum;
  const YeniliklerEkrani({super.key, required this.surum});

  /// Tanıtımı gömülü olan sürümler. Yeni sürüm çıkarken buraya numara
  /// eklenir VE [_kartlar] dalı yazılır; testler ikisini birden kilitler.
  static const List<String> taniticiOlanlar = ['1.114.0', '1.149.0'];

  /// Sürüm → kart listesi. [taniticiOlanlar] ile birebir aynı kümeyi
  /// kapsamalı (`surum_duyurusu_test` boş kart listesi bırakılmasını da
  /// yakalar: listeye numara yazıp kartları unutmak = boş sayfa).
  List<Widget> _kartlar() => switch (surum) {
    '1.114.0' => _kartlar114(),
    '1.149.0' => _kartlar149(),
    _ => const <Widget>[],
  };

  /// Testin okuduğu sayaç: [taniticiOlanlar]daki her sürümün gerçekten kartı
  /// var mı? (Ekranı kurmadan sorulabilsin diye kartlar `context` almıyor.)
  @visibleForTesting
  int get kartSayisi => _kartlar().length;

  @override
  Widget build(BuildContext context) {
    final biliniyor = taniticiOlanlar.contains(surum);
    final geride = surumIleri(surum, Api.surum);
    return Scaffold(
      appBar: AppBar(title: Text('Yenilikler'.c)),
      body: OrtaKolon(
        azami: masaustuKolonGenisligi,
        cocuk: biliniyor
            ? ListView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, altGuvenli(context)),
                children: [
                  _baslik(context),
                  const SizedBox(height: 18),
                  ..._kartlar(),
                ],
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        geride
                            ? Icons.system_update_alt
                            : Icons.check_circle_outline,
                        size: 44,
                        color: DiziRenkler.metin24,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        geride
                            ? 'Bu sürümün notlarını görmek için uygulamayı güncelle'
                                  .c
                            : 'Bu sürümde görünür bir yenilik yok; arka planda iyileştirmeler ve düzeltmeler var.'
                                  .c,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: DiziRenkler.metin54),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _baslik(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 8),
      Row(
        children: [
          const Icon(Icons.auto_awesome, color: DiziRenkler.sari, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'dizi.jpg {} yayında'.cf([surum]),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        'Bu sürümde neler değişti, aşağıda.'.c,
        style: TextStyle(fontSize: 13, color: DiziRenkler.metin54),
      ),
    ],
  );

  // ---------------------------------------------------------------------
  // 1.114.0 kartları
  // ---------------------------------------------------------------------
  List<Widget> _kartlar114() => [
    _YenilikKarti(
      ikon: Icons.notifications,
      baslik: 'Bildirimler yenilendi'.c,
      metin:
          'Beğeniler artık gönderi başına tek satırda toplanıyor, satırın sağında gönderinin küçük görseli duruyor ve liste arka planla tek parça görünüyor.'
              .c,
      gorsel: const _BildirimMaket(),
    ),
    _YenilikKarti(
      ikon: Icons.verified,
      baslik: 'Sarı rozet her yerde'.c,
      metin:
          'Rozetli kullanıcıların adının yanında artık bildirimlerde, gönderilerde ve beğenenler listesinde sarı onay rozeti görünüyor.'
              .c,
      gorsel: const _RozetMaket(),
    ),
    _YenilikKarti(
      ikon: Icons.play_circle_outline,
      baslik: 'Reels yorumları yarım ekranda'.c,
      metin:
          'Reels izlerken yorumlar ve yazının devamı ekranın yarısından biraz fazlasını kaplayan bir pencerede açılıyor; video üstte oynamaya devam ediyor.'
              .c,
      gorsel: const _ReelsMaket(),
    ),
    _YenilikKarti(
      ikon: Icons.linear_scale,
      baslik: 'Tek renkli ilerleme çubuğu'.c,
      metin:
          'Liste görünümündeki izleme çubuğu artık tek renk: az izlediysen kırmızı, ortalarındaysan sarı, sona yaklaştıysan yeşil.'
              .c,
      gorsel: const _CubukMaket(),
    ),
    _YenilikKarti(
      ikon: Icons.chat_bubble_outline,
      baslik: 'Sohbet düzeltmeleri'.c,
      metin:
          'Mesaj yazma kutusu ile istek düğmeleri artık telefonun gezinme tuşlarının altında kalmıyor; sohbete girince alt menü kendiliğinden gizleniyor.'
              .c,
    ),
  ];

  // ---------------------------------------------------------------------
  // 1.149.0 kartları
  //
  // KAPSAM: 1.114.0'dan bu yana duyurusu YAPILMAMIŞ işlerin en görünür
  // beşi. Duyuru hiç gönderilmediği için kullanıcı bunların hiçbirini
  // tanıtım olarak görmedi; sürüm sürüm anlatmak yerine "ne kazandın"
  // sırasıyla dizildi.
  // ---------------------------------------------------------------------
  List<Widget> _kartlar149() => [
    _YenilikKarti(
      ikon: Icons.lock_outline,
      baslik: 'Hesabını gizleyebilirsin'.c,
      metin:
          'Profilini gizliye aldığında gönderilerini yalnız onayladığın takipçiler görür. Yeni takipler bildirimlerine istek olarak düşer; Onayla ya da Sil ile karar verirsin.'
              .c,
      gorsel: const _IstekMaket(),
    ),
    _YenilikKarti(
      ikon: Icons.star_outline,
      baslik: 'IMDb, Rotten Tomatoes ve Metacritic puanları'.c,
      metin:
          'Film ve dizi sayfalarında dış puanlar da görünüyor; hangi kaynağın ne verdiğini tek bakışta karşılaştırırsın.'
              .c,
      gorsel: const _PuanMaket(),
    ),
    _YenilikKarti(
      ikon: Icons.fast_forward,
      baslik: "Reels'te iki kat hız".c,
      metin:
          'Reels izlerken ekranın sağ yarısını basılı tut, video iki kat hızlı oynasın; parmağını çekince normal hıza döner.'
              .c,
      gorsel: const _HizMaket(),
    ),
    _YenilikKarti(
      ikon: Icons.movie_creation_outlined,
      baslik: 'Yönetmen ve senarist kredileri'.c,
      metin:
          'Kişi sayfasında oyunculuğun yanında, o kişinin yönetmenlik ve senaristlik yaptığı yapımlar da listeleniyor.'
              .c,
    ),
    _YenilikKarti(
      ikon: Icons.replay,
      baslik: 'Videoda geri sarma düzeldi'.c,
      metin:
          'Videoyu geri sardığında baştan yüklenmiyor; oynatma kaldığın yerden anında devam ediyor.'
              .c,
    ),
  ];
}

/// Tek yenilik kartı: renkli ikon karesi + başlık + açıklama + (varsa) canlı
/// mini maket. Kart zemini [DiziRenkler.kart] — sayfa zemininden bir ton ayrık,
/// yenilikler birbirinden gözle ayrılsın diye (bildirim listesindeki "tek
/// parça" kuralı BURAYA uygulanmaz: orası akan bir liste, burası broşür).
class _YenilikKarti extends StatelessWidget {
  final IconData ikon;
  final String baslik;
  final String metin;
  final Widget? gorsel;

  const _YenilikKarti({
    required this.ikon,
    required this.baslik,
    required this.metin,
    this.gorsel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DiziRenkler.kart,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: DiziRenkler.sari.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(ikon, size: 21, color: DiziRenkler.sariMetin),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  baslik,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            metin,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: DiziRenkler.metin70,
            ),
          ),
          if (gorsel != null) ...[const SizedBox(height: 12), gorsel!],
        ],
      ),
    );
  }
}

/// Maketlerin ortak çerçevesi: bir ton koyu/açık zemin + yumuşak köşe.
class _MaketCercevesi extends StatelessWidget {
  final Widget cocuk;
  const _MaketCercevesi({required this.cocuk});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DiziRenkler.acikGri,
        borderRadius: BorderRadius.circular(10),
      ),
      child: cocuk,
    );
  }
}

/// Yeni bildirim satırının mini maketi: avatar + sarı ikon rozeti, gruplu
/// beğeni metni, sağda gönderi görseli yer tutucusu.
class _BildirimMaket extends StatelessWidget {
  const _BildirimMaket();

  @override
  Widget build(BuildContext context) {
    return _MaketCercevesi(
      cocuk: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: DiziRenkler.metin12,
                child: Icon(Icons.person, size: 18, color: DiziRenkler.metin38),
              ),
              const Positioned(
                right: 0,
                bottom: 0,
                child: CircleAvatar(
                  radius: 7,
                  backgroundColor: DiziRenkler.sari,
                  child: Icon(Icons.favorite, size: 9, color: Colors.black),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              // Gerçek satırla AYNI çeviri anahtarı — maket de dile uyar.
              '{} ve {} kişi yorumunu beğendi'.cf(['@alcelik, @melisa', 10]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: DiziRenkler.metin12,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.image, size: 18, color: DiziRenkler.metin38),
          ),
        ],
      ),
    );
  }
}

/// Rozetli kullanıcı adının mini maketi.
class _RozetMaket extends StatelessWidget {
  const _RozetMaket();

  @override
  Widget build(BuildContext context) {
    return _MaketCercevesi(
      cocuk: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: DiziRenkler.metin12,
            child: Icon(Icons.person, size: 16, color: DiziRenkler.metin38),
          ),
          const SizedBox(width: 8),
          const Text(
            '@alcelik',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 3),
            child: MiniRozet(olcu: 15),
          ),
        ],
      ),
    );
  }
}

/// Reels %60 modalının mini maketi: üstte "video" bandı (oynat ikonu), altta
/// yuvarlatılmış üst köşeli sheet taklidi.
class _ReelsMaket extends StatelessWidget {
  const _ReelsMaket();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 120,
        width: double.infinity,
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: Container(
                color: Colors.black87,
                child: const Center(
                  child: Icon(
                    Icons.play_circle_outline,
                    size: 30,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: DiziRenkler.acikGri,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 30,
                        height: 4,
                        decoration: BoxDecoration(
                          color: DiziRenkler.metin24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Yorumlar'.c,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _cizgi(0.9),
                    const SizedBox(height: 4),
                    _cizgi(0.6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cizgi(double oran) => FractionallySizedBox(
    alignment: AlignmentDirectional.centerStart,
    widthFactor: oran,
    child: Container(
      height: 6,
      decoration: BoxDecoration(
        color: DiziRenkler.metin12,
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );
}

/// Takip isteği satırının mini maketi: kilitli avatar + ad + Onayla/Sil.
/// Düğme metinleri GERÇEK anahtarlar ('Onayla', 'Sil') — maket de dile uyar.
class _IstekMaket extends StatelessWidget {
  const _IstekMaket();

  @override
  Widget build(BuildContext context) {
    Widget dugme(String etiket, {required bool dolu}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: dolu ? DiziRenkler.sari : Colors.transparent,
        border: dolu ? null : Border.all(color: DiziRenkler.metin24),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        etiket,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: dolu ? Colors.black : DiziRenkler.metin70,
        ),
      ),
    );
    return _MaketCercevesi(
      cocuk: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: DiziRenkler.metin12,
                child: Icon(Icons.person, size: 16, color: DiziRenkler.metin38),
              ),
              const Positioned(
                right: 0,
                bottom: 0,
                child: CircleAvatar(
                  radius: 6.5,
                  backgroundColor: DiziRenkler.sari,
                  child: Icon(Icons.lock, size: 8, color: Colors.black),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '@melisa',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
          dugme('Onayla'.c, dolu: true),
          const SizedBox(width: 6),
          dugme('Sil'.c, dolu: false),
        ],
      ),
    );
  }
}

/// Dış puan rozetlerinin mini maketi. Sayılar ÖRNEK: gerçek puanlar
/// MDBList'ten gelir, burada yalnız yerleşim gösterilir.
class _PuanMaket extends StatelessWidget {
  const _PuanMaket();

  @override
  Widget build(BuildContext context) {
    Widget rozet(String kaynak, String deger, Color renk) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            kaynak,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: renk,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            deger,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
    return _MaketCercevesi(
      cocuk: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          rozet('IMDb', '8,4', DiziRenkler.sariMetin),
          rozet('RT', '%92', DiziRenkler.ilerlemeKirmizi),
          rozet('METACRITIC', '76', DiziRenkler.ilerlemeYesil),
        ],
      ),
    );
  }
}

/// 2x basılı tutmanın mini maketi: siyah video bandı, sağ yarısı vurgulu,
/// ortasında gerçek göstergenin aynısı olan "2x" etiketi.
class _HizMaket extends StatelessWidget {
  const _HizMaket();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 92,
        width: double.infinity,
        child: Stack(
          children: [
            // Zemin iki eşit yarı: sağdaki "basılı tutulan" bölge, siyahın
            // üstüne sarı bir perde. İki Expanded, FractionallySizedBox'a
            // göre daha dayanıklı — genişliği Row veriyor, sınırsız kutu yok.
            Positioned.fill(
              child: Row(
                children: [
                  const Expanded(child: ColoredBox(color: Colors.black87)),
                  Expanded(
                    child: ColoredBox(
                      color: Color.alphaBlend(
                        DiziRenkler.sari.withValues(alpha: 0.16),
                        Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fast_forward, size: 15, color: Colors.white),
                    SizedBox(width: 5),
                    Text(
                      '2x',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Üç renkli tek renk çubuk maketi: %20 kırmızı, %50 sarı, %90 yeşil.
class _CubukMaket extends StatelessWidget {
  const _CubukMaket();

  @override
  Widget build(BuildContext context) {
    Widget cubuk(double oran) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 5,
                child: ColoredBox(
                  color: DiziRenkler.metin12,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: oran,
                      heightFactor: 1,
                      child: ColoredBox(color: DiziRenkler.ilerlemeRengi(oran)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 38,
            child: Text(
              '%{}'.cf([(oran * 100).round()]),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: DiziRenkler.ilerlemeRengi(oran),
              ),
            ),
          ),
        ],
      ),
    );
    return _MaketCercevesi(
      cocuk: Column(children: [cubuk(0.2), cubuk(0.5), cubuk(0.9)]),
    );
  }
}
