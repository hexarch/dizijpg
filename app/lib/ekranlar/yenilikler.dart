import 'package:flutter/material.dart';

import '../aile_rozeti.dart' show MiniRozet;
import '../ceviri.dart';
import '../tema.dart';
import 'ortak.dart';

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
/// BİLİNMEYEN SÜRÜM: eski bir uygulama yeni sürümün bildirimini alabilir
/// (ör. Android'de güncellemeden önce). Boş sayfa ya da hata yerine "bu
/// sürümün notları için uygulamayı güncelle" denir — sessiz boşluk yasak.
class YeniliklerEkrani extends StatelessWidget {
  final String surum;
  const YeniliklerEkrani({super.key, required this.surum});

  /// Tanıtımı gömülü olan sürümler. Yeni sürüm çıkarken buraya kart listesi
  /// eklenir; testler en son sürümün burada olduğunu kilitler.
  static const List<String> taniticiOlanlar = ['1.114.0'];

  @override
  Widget build(BuildContext context) {
    final biliniyor = taniticiOlanlar.contains(surum);
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
                  ..._kartlar114(context),
                ],
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.system_update_alt,
                        size: 44,
                        color: DiziRenkler.metin24,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Bu sürümün notlarını görmek için uygulamayı güncelle'
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
  List<Widget> _kartlar114(BuildContext context) => [
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
