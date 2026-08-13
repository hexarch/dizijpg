import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'istatistiklerim.dart' show sayiBicimle;
import 'ortak.dart';

/// GÖNDERİ İSTATİSTİKLERİ — kendi gönderinin göz ikonundan açılır (md. 23).
///
/// ===========================================================================
/// EKRANIN ÜÇ KURALI
/// ===========================================================================
/// 1. **YALNIZ SAHİBİ.** Uç başkasının gönderisine 404 verir; bu ekran o
///    durumda "bulunamadı" der ve hiçbir sayı göstermez.
/// 2. **KİMLİK YOK.** "Görüntüleyen" bir SAYIDIR — kaç FARKLI kişi gördü.
///    İsim/avatar listesi yoktur ve uç zaten döndürmez. Gerekçe: kullanıcıya
///    md. 21'de "takipçilerimi/izlediklerimi gizle" sözü verildi; aynı kişinin
///    bir gönderiyi izlediğini yazara isimle söylemek o sözle çelişirdi.
/// 3. **ÖLÇÜLMEYEN GÖSTERİLMEZ.** Bir ölçü henüz birikmiyorsa kutusu ya hiç
///    çizilmez ya da yanında "{tarih} tarihinden beri birikiyor" notu durur.
///    Sıfır yazıp "kimse yapmadı" izlenimi vermek YASAK (md. 24 kalıbı).
///
/// ===========================================================================
/// GRAFİK KARARI — "tek çizgi, zikzak olmayacak"
/// ===========================================================================
/// Çizgi KÜMÜLATİF toplamı gösterir, günlük artışı değil:
///  * Günlük artış düşük trafikli bir gönderide 0,0,3,0,1 diye gider —
///    kullanıcının istemediği zikzak tam olarak budur ve düzeltmenin tek yolu
///    yumuşatmak, yani SAYIYI BOZMAKTIR.
///  * Kümülatif eğri matematiksel olarak azalamaz: zikzak yapması imkânsız ve
///    tek bir sayı bile değiştirilmemiş olur. Hangi günün patladığı EĞİMDEN
///    okunur; günün kendi artışı çizgiye dokununca ipucunda, ayrıca "zirve"
///    cümlesinde yazılıdır.
///
/// SEYREK VERİ: sunucu yalnız görüntülenmesi ARTAN günlere satır yazar. Eksik
/// gün "veri yok" değil "o gün artış olmadı" demektir; sunucu bir önceki
/// toplamı TAŞIR (`seriDoldur`), çizgi kopmaz ve sıfıra düşmez. Ölçüm
/// başlamadan önceki günler ise HİÇ çizilmez — sıfırla doldurmak, ölçmediğimiz
/// bir geçmişi "hiç görüntülenmemiş" diye göstermek olurdu.
///
/// RENK: tek seri olduğu için efsane (legend) YOK — başlık serinin adıdır.
/// Marka sarısı `sariMetin` ile alınır (açık temada koyulaştırılmış hardal,
/// koyuda parlak sarı); ızgara `metin12` ile geri planda kalır.
class GonderiIstatistikEkrani extends StatefulWidget {
  final int gonderiId;

  const GonderiIstatistikEkrani({super.key, required this.gonderiId});

  @override
  State<GonderiIstatistikEkrani> createState() =>
      _GonderiIstatistikEkraniState();
}

class _GonderiIstatistikEkraniState extends State<GonderiIstatistikEkrani> {
  /// Seçili aralık (gün). 0 = tümü. Sunucudaki beyaz listeyle aynı.
  int _gun = 30;
  Map<String, dynamic>? _veri;
  String? _hata;
  bool _yok = false;
  bool _yukleniyor = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final istenen = _gun;
    setState(() {
      _hata = null;
      _yukleniyor = true;
    });
    try {
      final d = await Api.get(
        '/gonderi/${widget.gonderiId}/istatistik?gun=$istenen',
      );
      if (!mounted || istenen != _gun) return;
      setState(() {
        _veri = (d as Map).cast<String, dynamic>();
        _yukleniyor = false;
      });
    } on ApiHata catch (e) {
      if (!mounted || istenen != _gun) return;
      setState(() {
        // 404 = gönderi yok VEYA benim değil. Uç ikisini AYIRMIYOR (ayırmak
        // "var ama senin değil" demek olurdu); ekran da ayırmaz.
        _yok = e.kod == 404;
        _hata = e.toString();
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted || istenen != _gun) return;
      setState(() {
        _hata = e.toString();
        _yukleniyor = false;
      });
    }
  }

  void _araliksec(int gun) {
    if (gun == _gun) return;
    setState(() => _gun = gun);
    _yukle();
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_yok) {
      govde = BosDurum(
        ikon: Icons.lock_outline,
        baslik: 'Gönderi bulunamadı'.c,
        ipucu: 'Yalnız kendi gönderilerinin istatistiklerini görebilirsin.'.c,
      );
    } else if (_hata != null && _veri == null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_veri == null) {
      govde = const _Iskelet();
    } else {
      govde = RefreshIndicator(
        color: DiziRenkler.sari,
        onRefresh: _yukle,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            12,
            12,
            12,
            altGuvenli(context, ekstra: 24),
          ),
          children: _icerik(),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Gönderi istatistikleri'.c),
        // Yükleme başlıkta: aralık değişirken sayılar yerinde kalsın,
        // kullanıcı iki aralığı karşılaştırabilsin.
        bottom: _yukleniyor
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: DiziRenkler.sari,
                ),
              )
            : null,
      ),
      body: OrtaKolon(azami: masaustuKolonGenisligi, cocuk: govde),
    );
  }

  // -------------------------------------------------------------------------
  // İÇERİK
  // -------------------------------------------------------------------------
  List<Widget> _icerik() {
    final v = _veri!;
    final o = (v['olcu'] as Map?)?.cast<String, dynamic>() ?? const {};
    final gonderi = (v['gonderi'] as Map?)?.cast<String, dynamic>() ?? const {};
    final kapsam = (v['kapsam'] as Map?)?.cast<String, dynamic>() ?? const {};
    final olcuBas = kapsam['olcu_baslangic'] as String?;
    final int gor = o['goruntulenme'] as int? ?? 0;

    return [
      // --- ERİŞİM ---------------------------------------------------------
      _Baslik('Erişim'.c),
      _KutuIzgara(
        kutular: [
          _KutuVeri(
            ikon: Icons.remove_red_eye_outlined,
            etiket: 'Görüntülenme'.c,
            deger: gor,
            buyuk: true,
          ),
          _KutuVeri(
            ikon: Icons.people_alt_outlined,
            etiket: 'Görüntüleyen'.c,
            deger: o['goruntuleyen'] as int? ?? 0,
            buyuk: true,
            // Tekil kişi sayacı bu turda başladı ve 90 gün saklanıyor.
            not: 'Kaç farklı kişi gördü (son {} gün)'.cf([
              kapsam['goruntuleyen_gun'] ?? 90,
            ]),
            eksik: true,
          ),
        ],
      ),
      const SizedBox(height: 8),
      _KutuIzgara(
        kutular: [
          _KutuVeri(
            ikon: Icons.favorite_border,
            etiket: 'Beğeni'.c,
            deger: o['begeni'] as int? ?? 0,
          ),
          _KutuVeri(
            ikon: Icons.mode_comment_outlined,
            etiket: 'Yorum'.c,
            deger: o['yanit'] as int? ?? 0,
          ),
          _KutuVeri(
            ikon: Icons.share_outlined,
            etiket: 'Paylaşım'.c,
            deger: o['paylasim'] as int? ?? 0,
            eksik: true,
          ),
        ],
      ),
      ..._etkilesim(),

      // --- BU GÖNDERİDEN SONRA --------------------------------------------
      const SizedBox(height: 20),
      _Baslik('Bu gönderiden sonra'.c),
      _KutuIzgara(
        kutular: [
          _KutuVeri(
            ikon: Icons.person_outline,
            etiket: 'Profil ziyareti'.c,
            deger: o['profil_ziyaret'] as int? ?? 0,
            eksik: true,
          ),
          _KutuVeri(
            ikon: Icons.person_add_alt,
            etiket: 'Yeni takip'.c,
            deger: o['takip'] as int? ?? 0,
            eksik: true,
          ),
          _KutuVeri(
            ikon: Icons.movie_outlined,
            etiket: 'İçeriğe tıklama'.c,
            deger: o['icerik_tikla'] as int? ?? 0,
            eksik: true,
          ),
        ],
      ),
      // SPOILER KUTUSU YALNIZ SPOILER GÖNDERİDE. Perdesi olmayan bir gönderide
      // "perde açılma: 0" yazmak anlamsız bir sıfır olurdu.
      if (gonderi['spoiler'] == true) ...[
        const SizedBox(height: 8),
        _OranSatiri(
          ikon: Icons.visibility_off_outlined,
          etiket: 'Spoiler perdesini açan'.c,
          pay: o['spoiler_acildi'] as int? ?? 0,
          payda: gor,
        ),
      ],
      if (olcuBas != null) ...[
        const SizedBox(height: 8),
        _KapsamNotu(
          'Paylaşım, profil ziyareti, takip, içeriğe tıklama, kaynak kırılımı ve '
                  'spoiler ölçüleri {} tarihinden beri birikiyor; daha eskisi ölçülmedi.'
              .cf([tarihBicimle(olcuBas)]),
        ),
      ],

      // --- GRAFİK ----------------------------------------------------------
      const SizedBox(height: 20),
      _Baslik('Zamana yayılmış görüntülenme'.c),
      _AralikSecici(secili: _gun, onSec: _araliksec),
      const SizedBox(height: 10),
      _grafikBolumu(),

      // --- VİDEO ELDE TUTMA ------------------------------------------------
      // YALNIZ VİDEOLU GÖNDERİDE. Sunucu videosuz gönderide `video` alanını
      // null döndürür ve bu bölüm HİÇ çizilmez — fotoğraflı bir gönderide
      // "izlenme süresi: veri yok" yazmak anlamsız bir boşluk olurdu.
      ..._videoEgrisi(),

      // --- KAYNAKLAR -------------------------------------------------------
      const SizedBox(height: 20),
      _Baslik('Görüntülenme nereden geldi'.c),
      ..._kaynaklar(),

      // --- İZLEYİCİ KIRILIMI ------------------------------------------------
      const SizedBox(height: 20),
      _Baslik('Kimler gördü'.c),
      ..._izleyici(),
    ];
  }

  /// ETKİLEŞİM ORANI + kendi ortalamanla kıyas.
  ///
  /// Sunucu `etkilesim` alanını görüntülenme 0 iken NULL döndürür (0/0
  /// tanımsızdır); kıyası da yeterli gönderi yoksa null yapar. Ekran ikisini
  /// de "yok" olarak ele alır — uydurma bir "%0" basmaz.
  List<Widget> _etkilesim() {
    final e = (_veri!['etkilesim'] as Map?)?.cast<String, dynamic>();
    if (e == null) return const [];
    final oran = (e['oran'] as num?)?.toDouble() ?? 0;
    final fark = e['fark_yuzde'] as int?;
    return [
      const SizedBox(height: 8),
      _EtkilesimKarti(oran: oran, farkYuzde: fark),
    ];
  }

  Widget _grafikBolumu() {
    final v = _veri!;
    final seri = (v['seri'] as List<dynamic>? ?? const [])
        .map((s) => (s as Map).cast<String, dynamic>())
        .toList();
    final kapsam = (v['kapsam'] as Map?)?.cast<String, dynamic>() ?? const {};
    final bas = kapsam['goruntulenme_baslangic'] as String?;

    // İKİ NOKTADAN AZ VERİ ÇİZGİ DEĞİLDİR. Tek nokta bir "çizgi" çizemez ve
    // boş bir tuval kullanıcıya hata gibi görünür — bunun yerine ne olduğu
    // YAZIYLA söylenir (md. 24'ün dürüstlük kalıbı).
    if (seri.length < 2) {
      return _BosGrafik(
        mesaj: bas == null
            ? 'Günlük veri henüz birikmeye başlamadı.'.c
            : 'Grafik için en az iki günlük veri gerekiyor. Veri {} tarihinden beri birikiyor.'
                  .cf([tarihBicimle(bas)]),
      );
    }
    final zirve = (v['zirve'] as Map?)?.cast<String, dynamic>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CizgiGrafik(seri: seri),
        if (zirve != null) ...[
          const SizedBox(height: 8),
          _Ipucu(
            ikon: Icons.trending_up,
            metin: 'En çok görüntülenme paylaşımdan sonraki {}. gün geldi: {}'
                .cf([
                  zirve['kacinci_gun'] ?? 1,
                  sayiBicimle(zirve['gunluk'] as int? ?? 0),
                ]),
          ),
        ],
        if (bas != null) ...[
          const SizedBox(height: 6),
          _KapsamNotu(
            'Günlük görüntülenme {} tarihinden beri birikiyor; öncesi ölçülmedi.'
                .cf([tarihBicimle(bas)]),
          ),
        ],
      ],
    );
  }

  /// VİDEO İZLENME SÜRESİ (ELDE TUTMA) EĞRİSİ.
  ///
  /// ÜÇ DURUM, ÜÇÜ DE AÇIKÇA SÖYLENİR:
  ///  1. Gönderi VİDEOSUZ (`video == null`) → bölüm HİÇ ÇİZİLMEZ.
  ///  2. Videolu ama örneklem ALT EŞİĞİN ALTINDA (`egri == null`) → eğri
  ///     çizilmez, kaç izlemenin biriktiği ve kaç gerektiği YAZILIR. "3
  ///     izlemede %67 elde tutma" bir ölçü değil tesadüftür; çizmek
  ///     kullanıcının güveneceği yanlış bir sayı üretirdi.
  ///  3. Eğri var → çizilir + iki cümlelik okuma (ortanca, tamamlama) ve
  ///     ölçünün NE ZAMANDAN BERİ biriktiği notu.
  List<Widget> _videoEgrisi() {
    final v = (_veri!['video'] as Map?)?.cast<String, dynamic>();
    if (v == null) return const []; // videosuz gönderi
    final gorunum = v['gorunum'] as int? ?? 0;
    final enAz = v['en_az'] as int? ?? 20;
    final bas = v['baslangic'] as String?;
    final ham = v['egri'] as List<dynamic>?;
    final egri = ham
        ?.map((x) => (x as num).toDouble().clamp(0.0, 1.0))
        .toList();

    final basliklar = <Widget>[
      const SizedBox(height: 20),
      _Baslik('Videonun ne kadarı izlendi'.c),
    ];

    if (egri == null || egri.length < 2) {
      return [
        ...basliklar,
        _BosGrafik(
          mesaj: 'Eğri için en az {} izlenme gerekiyor; şu an {} izlenme var.'
              .cf([enAz, gorunum]),
        ),
        if (bas != null) ...[
          const SizedBox(height: 6),
          _KapsamNotu(
            'İzlenme süresi {} tarihinden beri ölçülüyor; daha eski görüntülenmeler bu sayıya girmez.'
                .cf([tarihBicimle(bas)]),
          ),
        ],
      ];
    }

    final ortanca = v['ortanca'] as int? ?? 0;
    final tamamlama = (v['tamamlama'] as num?)?.toDouble() ?? 0;
    return [
      ...basliklar,
      _EldeTutmaGrafigi(egri: egri, gorunum: gorunum),
      const SizedBox(height: 8),
      _Ipucu(
        ikon: Icons.timelapse,
        metin: 'İzleyenlerin yarısı videonun en az %{} kadarını gördü.'.cf([
          ortanca,
        ]),
      ),
      const SizedBox(height: 6),
      _Ipucu(
        ikon: Icons.flag_outlined,
        metin: 'Sonuna kadar izleyen: %{}'.cf([(tamamlama * 100).round()]),
      ),
      const SizedBox(height: 6),
      // ZAMAN ARALIĞI SEÇİCİSİ BU EĞRİYİ ETKİLEMEZ: ölçü ömür boyudur (kova
      // tablosunda tarih yok — tarih tutmak tek izleyicili bir gönderide kişiyi
      // işaret ederdi). Kullanıcı yukarıda "Son 7 gün" seçiliyken bu eğrinin de
      // 7 günlük olduğunu sanmasın.
      _KapsamNotu(
        'Eğri {} izlenmeden çıkarıldı ve seçili zaman aralığından etkilenmez.'
            .cf([gorunum]),
      ),
      if (bas != null) ...[
        const SizedBox(height: 6),
        _KapsamNotu(
          'İzlenme süresi {} tarihinden beri ölçülüyor; daha eski görüntülenmeler bu sayıya girmez.'
              .cf([tarihBicimle(bas)]),
        ),
      ],
    ];
  }

  /// Kaynak kırılımı — TEK ÖLÇÜ, birçok kategori ⇒ hepsi AYNI renk.
  /// Kategoriye ayrı renk vermek, çubuk uzunluğunun zaten söylediği şeyi
  /// renkle tekrar kodlamak olurdu (ve 6 renk ayırt edilemezdi).
  List<Widget> _kaynaklar() {
    final liste = (_veri!['kaynaklar'] as List<dynamic>? ?? const [])
        .map((k) => (k as Map).cast<String, dynamic>())
        .toList();
    final toplam = liste.fold<int>(0, (t, k) => t + (k['adet'] as int? ?? 0));
    if (toplam == 0) {
      return [
        _KapsamNotu(
          'Kaynak kırılımı yeni ölçülmeye başladı; bu gönderi henüz etiketli bir görüntülenme almadı.'
              .c,
        ),
      ];
    }
    liste.sort(
      (a, b) => (b['adet'] as int? ?? 0).compareTo(a['adet'] as int? ?? 0),
    );
    return [
      for (final k in liste)
        _CubukSatiri(
          etiket: _kaynakAdi(k['kaynak'] as String? ?? ''),
          deger: k['adet'] as int? ?? 0,
          enBuyuk: liste.first['adet'] as int? ?? 1,
          toplam: toplam,
        ),
    ];
  }

  /// Takipçi / dışarıdan kırılımı. Sunucu bunu görüntülenme ANINDA ölçüyor
  /// (kişi bazlı satır tutmadan, iki agregat sayaçla).
  List<Widget> _izleyici() {
    final i = (_veri!['izleyici'] as Map?)?.cast<String, dynamic>() ?? const {};
    final takipci = i['takipci'] as int? ?? 0;
    final disari = i['disari'] as int? ?? 0;
    final toplam = takipci + disari;
    if (toplam == 0) {
      return [
        _KapsamNotu(
          'Takipçi/keşif kırılımı yeni ölçülmeye başladı; henüz veri yok.'.c,
        ),
      ];
    }
    final enBuyuk = math.max(takipci, disari);
    return [
      _CubukSatiri(
        etiket: 'Takip edenler'.c,
        deger: takipci,
        enBuyuk: enBuyuk,
        toplam: toplam,
      ),
      _CubukSatiri(
        etiket: 'Keşiften gelenler'.c,
        deger: disari,
        enBuyuk: enBuyuk,
        toplam: toplam,
      ),
    ];
  }

  String _kaynakAdi(String k) => switch (k) {
    'akis' => 'Akış'.c,
    'profil' => 'Profil'.c,
    'reels' => 'Reels'.c,
    'dizi' => 'Dizi/film sayfası'.c,
    'paylasim' => 'Paylaşılan bağlantı'.c,
    _ => 'Diğer'.c,
  };
}

/// ISO tarihi (YYYY-MM-DD) okunur biçime çevirir; çevrilemezse ham döner.
String tarihBicimle(String iso) {
  final p = iso.split('-');
  if (p.length != 3) return iso;
  final ay = int.tryParse(p[1]);
  if (ay == null || ay < 1 || ay > 12) return iso;
  return '${int.tryParse(p[2]) ?? p[2]}.${p[1]}.${p[0]}';
}

// ===========================================================================
// PARÇALAR
// ===========================================================================

class _Baslik extends StatelessWidget {
  final String metin;

  const _Baslik(this.metin);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      metin,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
    ),
  );
}

class _KutuVeri {
  final IconData ikon;
  final String etiket;
  final int deger;
  final bool buyuk;
  final bool eksik;
  final String? not;

  const _KutuVeri({
    required this.ikon,
    required this.etiket,
    required this.deger,
    this.buyuk = false,
    this.eksik = false,
    this.not,
  });
}

/// Eşit genişlikte sayı kutuları. Aralarında 8 px: dokunulabilir olmasalar da
/// bitişik kartlar tek bir yüzey gibi okunurdu.
class _KutuIzgara extends StatelessWidget {
  final List<_KutuVeri> kutular;

  const _KutuIzgara({required this.kutular});

  // IntrinsicHeight + stretch: kutulardan biri (açıklama satırı olan)
  // uzunsa hepsi ONA UYAR. Olmasaydı kartlar farklı boylarda kalır ve satır
  // kırık görünürdü. `stretch` TEK BAŞINA kullanılamaz — ListView'in sonsuz
  // yüksekliği içinde "esnetilecek" bir sınır yoktur (layout hatası).
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < kutular.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _Kutu(kutular[i])),
        ],
      ],
    ),
  );
}

/// Tek sayı kutusu. `istatistiklerim.dart`taki `_Sayac` ile aynı dil: sayı
/// büyük ve kalın, etiket altta küçük, eksik ölçü RENKLE DEĞİL İKONLA
/// (kum saati) işaretlenir — renk körlüğünde de görünsün.
class _Kutu extends StatelessWidget {
  final _KutuVeri v;

  const _Kutu(this.v);

  @override
  Widget build(BuildContext context) {
    final yazi = sayiBicimle(v.deger);
    return Semantics(
      label: '${v.etiket}: $yazi${v.eksik ? ', ${'yeni ölçülüyor'.c}' : ''}',
      excludeSemantics: true,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(v.ikon, size: 16, color: DiziRenkler.sariMetin),
                  if (v.eksik) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.hourglass_bottom,
                      size: 14,
                      color: DiziRenkler.metin38,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              // FittedBox: 7 haneli sayı dar sütunda taşmasın, küçülsün.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  yazi,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: v.buyuk ? 26 : 20,
                    fontWeight: FontWeight.w800,
                    color: DiziRenkler.metin,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                v.etiket,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: DiziRenkler.metin54, fontSize: 12),
              ),
              if (v.not != null) ...[
                const SizedBox(height: 4),
                Text(
                  v.not!,
                  style: TextStyle(color: DiziRenkler.metin38, fontSize: 10),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// ETKİLEŞİM ORANI KARTI — ekranın en değerli parçası.
///
/// Çıplak "412 görüntülenme" bağlamsızdır; "%3,4 etkileşim, kendi ortalamanın
/// %28 üstünde" cümlesi kullanıcıya NE YAPACAĞINI söyler. Kıyas yalnız yeterli
/// gönderi varsa gelir (sunucu kararı) — 1-2 gönderiyle "ortalamanın %300
/// üstünde" demek gönderiyi kendisiyle kıyaslamaktır.
///
/// YÖN RENKLE DEĞİL, İKON + YAZIYLA da anlatılır (renk körlüğü kuralı).
class _EtkilesimKarti extends StatelessWidget {
  final double oran;
  final int? farkYuzde;

  const _EtkilesimKarti({required this.oran, required this.farkYuzde});

  @override
  Widget build(BuildContext context) {
    final yuzde = (oran * 100);
    // Küçük oranlarda tek ondalık: "%0" demek "hiç" demektir, oysa %0,4 var.
    final metin = '%${yuzde < 10 ? yuzde.toStringAsFixed(1) : yuzde.round()}';
    final f = farkYuzde;
    // ±%5'lik bant "aynı düzeyde" sayılır: 1-2 puanlık gürültüyü haber diye
    // sunmak kullanıcıyı yanıltır.
    final String? kiyas;
    final IconData? kiyasIkon;
    if (f == null) {
      kiyas = null;
      kiyasIkon = null;
    } else if (f.abs() <= 5) {
      kiyas = 'Kendi ortalamanla aynı düzeyde'.c;
      kiyasIkon = Icons.trending_flat;
    } else if (f > 0) {
      kiyas = 'Kendi ortalamanın %{} üstünde'.cf([f]);
      kiyasIkon = Icons.trending_up;
    } else {
      kiyas = 'Kendi ortalamanın %{} altında'.cf([-f]);
      kiyasIkon = Icons.trending_down;
    }
    return Semantics(
      label: '${'Etkileşim oranı'.c}: $metin${kiyas == null ? '' : ', $kiyas'}',
      excludeSemantics: true,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              Icon(Icons.auto_graph, size: 18, color: DiziRenkler.sariMetin),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Etkileşim oranı'.c,
                      style: TextStyle(
                        color: DiziRenkler.metin54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      metin,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: DiziRenkler.metin,
                      ),
                    ),
                    Text(
                      '(beğeni + yorum) ÷ görüntülenme'.c,
                      style: TextStyle(
                        color: DiziRenkler.metin38,
                        fontSize: 11,
                      ),
                    ),
                    if (kiyas != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(kiyasIkon, size: 15, color: DiziRenkler.metin70),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              kiyas,
                              style: TextStyle(
                                color: DiziRenkler.metin70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pay/payda oranı (spoiler perdesi gibi). Payda 0 ise oran YAZILMAZ.
class _OranSatiri extends StatelessWidget {
  final IconData ikon;
  final String etiket;
  final int pay;
  final int payda;

  const _OranSatiri({
    required this.ikon,
    required this.etiket,
    required this.pay,
    required this.payda,
  });

  @override
  Widget build(BuildContext context) {
    final oran = payda > 0 ? pay / payda : null;
    final sag = oran == null
        ? sayiBicimle(pay)
        : '${sayiBicimle(pay)}  ·  %${(oran * 100).round()}';
    return Semantics(
      label: '$etiket: $sag',
      excludeSemantics: true,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              Icon(ikon, size: 16, color: DiziRenkler.sariMetin),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  etiket,
                  style: TextStyle(color: DiziRenkler.metin70, fontSize: 13),
                ),
              ),
              Text(
                sag,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: DiziRenkler.metin,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kaynak/izleyici kırılımının yatay çubuğu.
///
/// YATAY, dikey değil: etiketler uzun ("Paylaşılan bağlantı") ve dikey
/// çubukta yan yatar ya da kırpılırdı. Çubuk uzunluğu EN BÜYÜK değere göre
/// ölçeklenir (karşılaştırma), sağdaki yüzde ise TOPLAMA göre (pay).
class _CubukSatiri extends StatelessWidget {
  final String etiket;
  final int deger;
  final int enBuyuk;
  final int toplam;

  const _CubukSatiri({
    required this.etiket,
    required this.deger,
    required this.enBuyuk,
    required this.toplam,
  });

  @override
  Widget build(BuildContext context) {
    final pay = enBuyuk > 0 ? deger / enBuyuk : 0.0;
    final yuzde = toplam > 0 ? (deger / toplam * 100).round() : 0;
    return Semantics(
      label: '$etiket: ${sayiBicimle(deger)}, %$yuzde',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    etiket,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: DiziRenkler.metin70, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                // Sayı ve yüzde METİN RENGİNDE — seri rengi kimliği çubuk
                // taşır, yazı okunurluk tonunda kalır (dataviz kuralı).
                Text(
                  '${sayiBicimle(deger)}  ·  %$yuzde',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: DiziRenkler.metin,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pay.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: DiziRenkler.metin12,
                color: DiziRenkler.sariMetin,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aralık çipleri (7/30/90/Tümü) — `istatistiklerim.dart`taki çiple aynı
/// davranış: 44 px dokunma hedefi, seçili durum renkten BAŞKA bir işaretle
/// (kalın çerçeve + kalın yazı) de belli.
class _AralikSecici extends StatelessWidget {
  final int secili;
  final void Function(int) onSec;

  const _AralikSecici({required this.secili, required this.onSec});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final g in const [7, 30, 90])
        _Cip(
          etiket: 'Son {} gün'.cf([g]),
          anahtar: 'aralik-$g',
          secili: secili == g,
          onSec: () => onSec(g),
        ),
      _Cip(
        etiket: 'Tümü'.c,
        anahtar: 'aralik-0',
        secili: secili == 0,
        onSec: () => onSec(0),
      ),
    ],
  );
}

class _Cip extends StatelessWidget {
  final String etiket;
  final String anahtar;
  final bool secili;
  final VoidCallback onSec;

  const _Cip({
    required this.etiket,
    required this.anahtar,
    required this.secili,
    required this.onSec,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: secili,
    child: InkWell(
      key: Key(anahtar),
      onTap: onSec,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: secili ? DiziRenkler.sari.withValues(alpha: 0.16) : null,
          border: Border.all(
            color: secili ? DiziRenkler.sari : DiziRenkler.metin12,
            width: secili ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          etiket,
          style: TextStyle(
            fontSize: 13,
            fontWeight: secili ? FontWeight.w800 : FontWeight.w500,
            color: secili ? DiziRenkler.sariMetin : DiziRenkler.metin54,
          ),
        ),
      ),
    ),
  );
}

/// TEK ÇİZGİ, KÜMÜLATİF GRAFİK.
///
/// Efsane YOK (tek seri — başlık serinin adıdır), ızgara geri planda, çizgi
/// 2 px. Dokunma/sürükleme bir imleç açar: o günün TARİHİ, o güne kadarki
/// TOPLAM ve o günün ARTIŞI okunur. Böylece kümülatif eğri günlük detayı
/// gizlememiş olur.
class _CizgiGrafik extends StatefulWidget {
  final List<Map<String, dynamic>> seri;

  const _CizgiGrafik({required this.seri});

  @override
  State<_CizgiGrafik> createState() => _CizgiGrafikState();
}

class _CizgiGrafikState extends State<_CizgiGrafik> {
  /// Seçili gün (imleç). null = imleç kapalı, son değer etiketlenir.
  int? _secili;

  void _konumdanSec(Offset yerel, double genislik) {
    final n = widget.seri.length;
    if (n < 2 || genislik <= 0) return;
    // Çizim alanı sol dolgudan sonra başlıyor; imleç aynı eşlemeyi kullanır.
    final x =
        (yerel.dx - _CizgiCizer.solDolgu) /
        math.max(1, genislik - _CizgiCizer.solDolgu - _CizgiCizer.sagDolgu);
    final i = (x * (n - 1)).round().clamp(0, n - 1);
    if (i != _secili) setState(() => _secili = i);
  }

  @override
  Widget build(BuildContext context) {
    final seri = widget.seri;
    final sonuncu = seri.last;
    final s = _secili == null ? sonuncu : seri[_secili!];
    final gun = s['gun'] as String? ?? '';
    final toplam = s['toplam'] as int? ?? 0;
    final gunluk = s['gunluk'] as int? ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // OKUNAN DEĞER GRAFİĞİN ÜSTÜNDE: mobilde parmak grafiğin üstünde
        // durur, ipucu balonu tam parmağın altında kalırdı.
        Row(
          children: [
            Text(
              sayiBicimle(toplam),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: DiziRenkler.metin,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _secili == null
                    ? 'Toplam görüntülenme'.c
                    : '${tarihBicimle(gun)}  ·  +${sayiBicimle(gunluk)}',
                style: TextStyle(color: DiziRenkler.metin54, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, kisit) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _konumdanSec(d.localPosition, kisit.maxWidth),
            onHorizontalDragUpdate: (d) =>
                _konumdanSec(d.localPosition, kisit.maxWidth),
            onHorizontalDragEnd: (_) => setState(() => _secili = null),
            onTapUp: (_) => setState(() => _secili = null),
            onTapCancel: () => setState(() => _secili = null),
            child: Semantics(
              // Grafiğin ERİŞİLEBİLİR KARŞILIĞI: ekran okuyucu tuvali
              // okuyamaz, bu yüzden özeti metin olarak veriyoruz.
              label: '{} ile {} arasında toplam {} görüntülenme'.cf([
                tarihBicimle(seri.first['gun'] as String? ?? ''),
                tarihBicimle(sonuncu['gun'] as String? ?? ''),
                sayiBicimle(sonuncu['toplam'] as int? ?? 0),
              ]),
              excludeSemantics: true,
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: CustomPaint(
                  painter: _CizgiCizer(
                    seri: seri,
                    secili: _secili,
                    cizgi: DiziRenkler.sariMetin,
                    izgara: DiziRenkler.metin12,
                    yazi: DiziRenkler.metin54,
                    zemin: DiziRenkler.kart,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CizgiCizer extends CustomPainter {
  /// Y ekseni etiketleri için sol dolgu; imleç eşlemesi de bunu kullanır.
  static const double solDolgu = 40;
  static const double sagDolgu = 8;
  static const double ustDolgu = 8;

  /// X ekseni tarih etiketlerine ayrılan alt şerit.
  static const double altDolgu = 20;

  final List<Map<String, dynamic>> seri;
  final int? secili;
  final Color cizgi;
  final Color izgara;
  final Color yazi;
  final Color zemin;

  const _CizgiCizer({
    required this.seri,
    required this.secili,
    required this.cizgi,
    required this.izgara,
    required this.yazi,
    required this.zemin,
  });

  @override
  void paint(Canvas tuval, Size boyut) {
    final n = seri.length;
    if (n < 2) return;
    final sol = solDolgu;
    final sag = boyut.width - sagDolgu;
    final ust = ustDolgu;
    final alt = boyut.height - altDolgu;
    if (sag <= sol || alt <= ust) return;

    final degerler = [for (final s in seri) (s['toplam'] as int? ?? 0)];
    final enBuyuk = degerler.reduce(math.max);
    final enKucuk = degerler.reduce(math.min);
    // TABAN SIFIR DEĞİL, EN KÜÇÜK DEĞER: ölçüme gönderi zaten görüntülenmişken
    // başlanmış olabilir (md. 24 taban turu) — sıfırdan başlayan bir eksen o
    // durumda eğriyi ekranın tepesine yapıştırıp değişimi görünmez kılardı.
    // Aralık sıfırsa (hiç artış yok) yapay bir 1'lik aralık açılır, yoksa
    // bölme sıfıra düşerdi.
    final taban = enKucuk;
    final aralik = math.max(1, enBuyuk - enKucuk).toDouble();

    double xKonum(int i) => sol + (sag - sol) * (i / (n - 1));
    double yKonum(int v) => alt - (alt - ust) * ((v - taban) / aralik);

    // --- IZGARA + Y ETİKETLERİ (geri planda) ------------------------------
    final izgaraKalem = Paint()
      ..color = izgara
      ..strokeWidth = 1;
    for (var k = 0; k <= 2; k++) {
      final deger = taban + (aralik * k / 2).round();
      final y = yKonum(deger);
      tuval.drawLine(Offset(sol, y), Offset(sag, y), izgaraKalem);
      _yaz(tuval, sayiBicimle(deger), Offset(0, y - 6), 10, yazi, sol - 6);
    }

    // --- DOLGU (tek seri: alan çizgiyi destekler, kimlik taşımaz) ---------
    final yol = Path()..moveTo(xKonum(0), yKonum(degerler[0]));
    for (var i = 1; i < n; i++) {
      yol.lineTo(xKonum(i), yKonum(degerler[i]));
    }
    final dolgu = Path.from(yol)
      ..lineTo(xKonum(n - 1), alt)
      ..lineTo(xKonum(0), alt)
      ..close();
    tuval.drawPath(dolgu, Paint()..color = cizgi.withValues(alpha: 0.12));

    // --- ÇİZGİ (2 px, yuvarlak uç) ----------------------------------------
    tuval.drawPath(
      yol,
      Paint()
        ..color = cizgi
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // --- SON NOKTA: tek doğrudan etiket (her noktaya sayı BASILMAZ) -------
    final sonX = xKonum(n - 1);
    final sonY = yKonum(degerler[n - 1]);
    // 2 px zemin halkası: nokta ızgara/dolgu üstünde de sınırlı görünsün.
    tuval.drawCircle(Offset(sonX, sonY), 5, Paint()..color = zemin);
    tuval.drawCircle(Offset(sonX, sonY), 3.5, Paint()..color = cizgi);

    // --- İMLEÇ -------------------------------------------------------------
    if (secili != null && secili! >= 0 && secili! < n) {
      final x = xKonum(secili!);
      final y = yKonum(degerler[secili!]);
      tuval.drawLine(
        Offset(x, ust),
        Offset(x, alt),
        Paint()
          ..color = cizgi.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
      tuval.drawCircle(Offset(x, y), 6, Paint()..color = zemin);
      tuval.drawCircle(Offset(x, y), 4, Paint()..color = cizgi);
    }

    // --- X ETİKETLERİ: yalnız iki uç (ara etiketler üst üste binerdi) -----
    _yaz(tuval, _kisaGun(seri.first), Offset(sol, alt + 4), 10, yazi, 80);
    _yaz(
      tuval,
      _kisaGun(seri.last),
      Offset(sag - 60, alt + 4),
      10,
      yazi,
      60,
      sag: true,
    );
  }

  static String _kisaGun(Map<String, dynamic> s) {
    final p = (s['gun'] as String? ?? '').split('-');
    return p.length == 3 ? '${p[2]}.${p[1]}' : '';
  }

  void _yaz(
    Canvas tuval,
    String metin,
    Offset konum,
    double boy,
    Color renk,
    double genislik, {
    bool sag = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: metin,
        style: TextStyle(color: renk, fontSize: boy),
      ),
      textDirection: TextDirection.ltr,
      textAlign: sag ? TextAlign.right : TextAlign.left,
    )..layout(maxWidth: math.max(1, genislik));
    tp.paint(
      tuval,
      sag ? Offset(konum.dx + genislik - tp.width, konum.dy) : konum,
    );
  }

  @override
  bool shouldRepaint(_CizgiCizer eski) =>
      eski.secili != secili ||
      eski.seri != seri ||
      eski.cizgi != cizgi ||
      eski.zemin != zemin;
}

/// VİDEO ELDE TUTMA EĞRİSİ — "%100'den başlayıp azalan izlenme süresi eğrisi".
///
/// ===========================================================================
/// NEDEN BU EĞRİ YUMUŞATILMIYOR
/// ===========================================================================
/// elde tutma[k] = (videonun k. yirmide birine ULAŞAN izleme sayısı) ÷ (hiç
/// oynayan izleme sayısı). Bu bir SONEK TOPLAMI oranıdır: matematiksel olarak
/// elde tutma[0] tam 1'dir ve dizi ARTAMAZ. Yani kullanıcının istediği şekil
/// (soldan %100, sağa doğru azalan) veriden DOĞRUDAN çıkar — kümülatif
/// görüntülenme çizgisiyle aynı karar: tek bir sayı bile bozulmuyor.
///
/// ===========================================================================
/// EKSEN KARARLARI
/// ===========================================================================
/// * Y EKSENİ SABİT %0–%100. Diğer grafikte taban EN KÜÇÜK DEĞERdi (kümülatif
///   sayı sıfırdan başlamayabilir); burada tam tersi: oranın anlamı ölçeğin
///   kendisinde. Ekrana sığdırmak için tabanı %40'a çekmek, %60'ta biten iyi
///   bir videoyu "dibe vurmuş" gibi gösterirdi.
/// * X EKSENİ videonun KENDİ yüzdesi (%0 → %95): son nokta 19. kova, yani
///   "%95'i geçenler". "%100" yazmak son kovayı bitirenlerle karıştırırdı.
/// * ÇÖZÜNÜRLÜK 20 KOVA: veriyi olduğundan ince göstermemek için noktalar
///   ARALARI DÜZ ÇİZGİYLE birleştirilir, eğri (spline) çizilmez.
/// * TEK SERİ ⇒ efsane YOK, başlık serinin adıdır (dataviz kuralı). Renk tek
///   başına anlam TAŞIMAZ: okunan değer grafiğin üstünde YAZIYLA durur ve
///   ekran okuyucu için Semantics özeti verilir (tuval okunamaz).
class _EldeTutmaGrafigi extends StatefulWidget {
  /// 0..1 arası, MONOTON AZALAN, en az 2 elemanlı dizi (sunucu böyle üretir).
  final List<double> egri;

  /// Örneklem — erişilebilir özette ve ipucunda geçer.
  final int gorunum;

  const _EldeTutmaGrafigi({required this.egri, required this.gorunum});

  @override
  State<_EldeTutmaGrafigi> createState() => _EldeTutmaGrafigiState();
}

class _EldeTutmaGrafigiState extends State<_EldeTutmaGrafigi> {
  /// Seçili kova (imleç). null = imleç kapalı, BAŞLANGIÇ değeri etiketlenir.
  int? _secili;

  void _konumdanSec(Offset yerel, double genislik) {
    final n = widget.egri.length;
    if (n < 2 || genislik <= 0) return;
    final x =
        (yerel.dx - _EldeTutmaCizer.solDolgu) /
        math.max(
          1,
          genislik - _EldeTutmaCizer.solDolgu - _EldeTutmaCizer.sagDolgu,
        );
    final i = (x * (n - 1)).round().clamp(0, n - 1);
    if (i != _secili) setState(() => _secili = i);
  }

  /// Kovanın videodaki yüzde karşılığı (0 → %0, 19 → %95).
  int _yuzde(int kova) => (kova * 100 / widget.egri.length).round();

  @override
  Widget build(BuildContext context) {
    final egri = widget.egri;
    final i = _secili ?? 0;
    final deger = (egri[i] * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // OKUNAN DEĞER GRAFİĞİN ÜSTÜNDE: mobilde parmak grafiğin üstünde
        // durur, ipucu balonu tam parmağın altında kalırdı.
        Row(
          children: [
            Text(
              // YÜZDE İŞARETİ DİLE GÖRE YER DEĞİŞTİRİR — sabit yazılamaz.
              // Türkçe "%45", İngilizce "45%", Almanca/Fransızca/Rusça
              // "45 %", Farsça "45٪". Burası '%$deger' diye sabitti ve bu
              // sayı, hemen sağındaki çeviriyle tek cümle olarak okunuyor
              // ("%45 videonun %60 noktasına ulaştı") — yani yanlış taraftaki
              // işaret cümlenin tamamını bozuyordu (13 Ağu, çeviri turunda
              // yakalandı). Kalıplar CLDR'den çıkarıldı: `tool/yuzde_kalibi.dart`.
              '%{}'.cf([deger]),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: DiziRenkler.metin,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _secili == null
                    ? 'Videoyu başlatanlar'.c
                    : 'videonun %{} noktasına ulaştı'.cf([_yuzde(i)]),
                style: TextStyle(color: DiziRenkler.metin54, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, kisit) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _konumdanSec(d.localPosition, kisit.maxWidth),
            onHorizontalDragUpdate: (d) =>
                _konumdanSec(d.localPosition, kisit.maxWidth),
            onHorizontalDragEnd: (_) => setState(() => _secili = null),
            onTapUp: (_) => setState(() => _secili = null),
            onTapCancel: () => setState(() => _secili = null),
            child: Semantics(
              // Ekran okuyucu tuvali okuyamaz: eğrinin ÖZETİ metin olarak.
              label:
                  '{} izlenme. Videonun yarısına ulaşan %{}, sonuna ulaşan %{}.'
                      .cf([
                        widget.gorunum,
                        (egri[egri.length ~/ 2] * 100).round(),
                        (egri.last * 100).round(),
                      ]),
              excludeSemantics: true,
              child: SizedBox(
                // Testin dokunacağı tuval: ekranda başka CustomPaint'ler de
                // var (görüntülenme grafiği, Material'in kendi çizimleri).
                key: const Key('elde-tutma-tuval'),
                height: 160,
                width: double.infinity,
                child: CustomPaint(
                  painter: _EldeTutmaCizer(
                    egri: egri,
                    secili: _secili,
                    cizgi: DiziRenkler.sariMetin,
                    izgara: DiziRenkler.metin12,
                    yazi: DiziRenkler.metin54,
                    zemin: DiziRenkler.kart,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EldeTutmaCizer extends CustomPainter {
  /// Y ekseni etiketleri için sol dolgu; imleç eşlemesi de bunu kullanır.
  static const double solDolgu = 40;
  static const double sagDolgu = 8;
  static const double ustDolgu = 8;
  static const double altDolgu = 20;

  final List<double> egri;
  final int? secili;
  final Color cizgi;
  final Color izgara;
  final Color yazi;
  final Color zemin;

  const _EldeTutmaCizer({
    required this.egri,
    required this.secili,
    required this.cizgi,
    required this.izgara,
    required this.yazi,
    required this.zemin,
  });

  @override
  void paint(Canvas tuval, Size boyut) {
    final n = egri.length;
    if (n < 2) return;
    final sol = solDolgu;
    final sag = boyut.width - sagDolgu;
    final ust = ustDolgu;
    final alt = boyut.height - altDolgu;
    if (sag <= sol || alt <= ust) return;

    double xKonum(int i) => sol + (sag - sol) * (i / (n - 1));
    // SABİT ÖLÇEK: 0 = alt kenar, 1 = üst kenar. Veriye göre esnemez.
    double yKonum(double oran) => alt - (alt - ust) * oran.clamp(0.0, 1.0);

    // --- IZGARA + Y ETİKETLERİ (%0 / %50 / %100, geri planda) -------------
    final izgaraKalem = Paint()
      ..color = izgara
      ..strokeWidth = 1;
    for (final oran in const [0.0, 0.5, 1.0]) {
      final y = yKonum(oran);
      tuval.drawLine(Offset(sol, y), Offset(sag, y), izgaraKalem);
      _yaz(
        tuval,
        '%${(oran * 100).round()}',
        Offset(0, y - 6),
        10,
        yazi,
        sol - 6,
      );
    }

    // --- DOLGU (tek seri: alan çizgiyi destekler, kimlik taşımaz) ---------
    final yol = Path()..moveTo(xKonum(0), yKonum(egri[0]));
    for (var i = 1; i < n; i++) {
      yol.lineTo(xKonum(i), yKonum(egri[i]));
    }
    final dolgu = Path.from(yol)
      ..lineTo(xKonum(n - 1), alt)
      ..lineTo(xKonum(0), alt)
      ..close();
    tuval.drawPath(dolgu, Paint()..color = cizgi.withValues(alpha: 0.12));

    // --- ÇİZGİ (2 px, yuvarlak uç) ----------------------------------------
    tuval.drawPath(
      yol,
      Paint()
        ..color = cizgi
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // --- BAŞLANGIÇ NOKTASI: eğrinin %100'den başladığını gösteren çıpa -----
    tuval.drawCircle(
      Offset(xKonum(0), yKonum(egri[0])),
      5,
      Paint()..color = zemin,
    );
    tuval.drawCircle(
      Offset(xKonum(0), yKonum(egri[0])),
      3.5,
      Paint()..color = cizgi,
    );

    // --- İMLEÇ -------------------------------------------------------------
    if (secili != null && secili! >= 0 && secili! < n) {
      final x = xKonum(secili!);
      final y = yKonum(egri[secili!]);
      tuval.drawLine(
        Offset(x, ust),
        Offset(x, alt),
        Paint()
          ..color = cizgi.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
      tuval.drawCircle(Offset(x, y), 6, Paint()..color = zemin);
      tuval.drawCircle(Offset(x, y), 4, Paint()..color = cizgi);
    }

    // --- X ETİKETLERİ: yalnız iki uç (ara etiketler üst üste binerdi) -----
    // Sağ uç "%95": son kova videonun %95'ini GEÇENLERİ sayar, bitirenleri
    // değil — "%100" yazmak eğrinin son noktasını yanlış okuturdu.
    _yaz(tuval, '%0', Offset(sol, alt + 4), 10, yazi, 40);
    final sonYuzde = ((n - 1) * 100 / n).round();
    _yaz(
      tuval,
      '%$sonYuzde',
      Offset(sag - 40, alt + 4),
      10,
      yazi,
      40,
      sag: true,
    );
  }

  void _yaz(
    Canvas tuval,
    String metin,
    Offset konum,
    double boy,
    Color renk,
    double genislik, {
    bool sag = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: metin,
        style: TextStyle(color: renk, fontSize: boy),
      ),
      textDirection: TextDirection.ltr,
      textAlign: sag ? TextAlign.right : TextAlign.left,
    )..layout(maxWidth: math.max(1, genislik));
    tp.paint(
      tuval,
      sag ? Offset(konum.dx + genislik - tp.width, konum.dy) : konum,
    );
  }

  @override
  bool shouldRepaint(_EldeTutmaCizer eski) =>
      eski.secili != secili ||
      eski.egri != egri ||
      eski.cizgi != cizgi ||
      eski.zemin != zemin;
}

/// Grafik çizilemediğinde: boş bir tuval yerine NE OLDUĞUNU söyleyen kutu.
class _BosGrafik extends StatelessWidget {
  final String mesaj;

  const _BosGrafik({required this.mesaj});

  @override
  Widget build(BuildContext context) => Container(
    height: 120,
    alignment: Alignment.center,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: DiziRenkler.metin12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.show_chart, size: 18, color: DiziRenkler.metin38),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            mesaj,
            style: TextStyle(color: DiziRenkler.metin54, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _Ipucu extends StatelessWidget {
  final IconData ikon;
  final String metin;

  const _Ipucu({required this.ikon, required this.metin});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(ikon, size: 15, color: DiziRenkler.sariMetin),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          metin,
          style: TextStyle(
            color: DiziRenkler.metin70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

/// "Veri şu tarihten beri birikiyor" satırı — sahte sayı üretmemenin görünen
/// yüzü (md. 24 ile aynı kalıp).
class _KapsamNotu extends StatelessWidget {
  final String metin;

  const _KapsamNotu(this.metin);

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.hourglass_bottom, size: 14, color: DiziRenkler.metin38),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          metin,
          style: TextStyle(color: DiziRenkler.metin54, fontSize: 11),
        ),
      ),
    ],
  );
}

/// Yükleme iskeleti: kutuların yerini ÖNCEDEN ayırır (içerik gelince sayfa
/// zıplamaz).
class _Iskelet extends StatelessWidget {
  const _Iskelet();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      for (var i = 0; i < 3; i++) ...[
        Row(
          children: [
            for (var j = 0; j < 3; j++) ...[
              if (j > 0) const SizedBox(width: 8),
              Expanded(child: _kutu(84)),
            ],
          ],
        ),
        const SizedBox(height: 16),
      ],
      _kutu(160),
    ],
  );

  Widget _kutu(double yukseklik) => Container(
    height: yukseklik,
    decoration: BoxDecoration(
      color: DiziRenkler.metin12,
      borderRadius: BorderRadius.circular(12),
    ),
  );
}
