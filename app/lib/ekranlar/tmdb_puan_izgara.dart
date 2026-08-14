import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import '../tmdb_bolum_puan.dart';
import 'ortak.dart';

/// Detay sayfasındaki TMDB puanı: dokununca altında sezon×bölüm ısı
/// haritası açılır. [yan] dizi.jpg rozeti ve izleyen sayısı gibi aynı
/// satırdaki diğer çocuklar — ızgara onların ALTINA iner, yanına değil.
class TmdbPuanHaritasi extends StatefulWidget {
  final int tmdbId;
  final double ortalama;
  final List<int> sezonNolari;
  final List<Widget> yan;
  final void Function(int sezon, int bolum)? onBolumSec;

  const TmdbPuanHaritasi({
    super.key,
    required this.tmdbId,
    required this.ortalama,
    required this.sezonNolari,
    this.yan = const [],
    this.onBolumSec,
  });

  @override
  State<TmdbPuanHaritasi> createState() => _TmdbPuanHaritasiState();
}

class _TmdbPuanHaritasiState extends State<TmdbPuanHaritasi> {
  bool _acik = false;
  bool _yukleniyor = false;
  String? _hata;
  List<TmdbSezonPuani>? _sezonlar;

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final nolar = widget.sezonNolari;
      final yanitlar = await Future.wait(
        nolar.map((n) async {
          try {
            final d = await Api.get('/tmdb/tv/${widget.tmdbId}/season/$n');
            return MapEntry(n, d);
          } catch (_) {
            return MapEntry(n, null);
          }
        }),
      );
      if (!mounted) return;
      final sezonlar = <TmdbSezonPuani>[];
      for (final y in yanitlar) {
        if (y.value is! Map) continue;
        sezonlar.add(
          TmdbSezonPuani(
            sezonNo: y.key,
            bolumler: tmdbBolumleriOku((y.value as Map)['episodes']),
          ),
        );
      }
      if (sezonlar.isEmpty) {
        setState(() {
          _yukleniyor = false;
          _hata = 'Bölüm puanları yüklenemedi'.c;
        });
        return;
      }
      setState(() {
        _sezonlar = sezonlar;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _hata = 'Bölüm puanları yüklenemedi'.c;
      });
    }
  }

  Future<void> _acKapa() async {
    if (_acik) {
      setState(() => _acik = false);
      return;
    }
    setState(() => _acik = true);
    if (_sezonlar == null && !_yukleniyor) await _yukle();
  }

  void _bolumeGit(int sezon, int bolum) {
    final ozel = widget.onBolumSec;
    if (ozel != null) {
      ozel(sezon, bolum);
      return;
    }
    context.push('/dizi/${widget.tmdbId}/sezon/$sezon/bolum/$bolum');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 6,
          children: [
            // Yıldız da tıklanır: kullanıcı çoğu zaman ikona dokunur,
            // yalnız yazıya değil. Chevron sarı — aksi hâlde TMDB satırı
            // eski düz metin gibi durur, ızgara "yok" sanılır.
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _acKapa,
              child: Semantics(
                button: true,
                label: 'Bölüm puanları'.c,
                child: SizedBox(
                  height: dokunmaHedefi,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          color: DiziRenkler.sari,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '{} TMDB'.cf([widget.ortalama.toStringAsFixed(1)]),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          _acik ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                          color: DiziRenkler.sariMetin,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ...widget.yan,
          ],
        ),
        if (_acik) ...[
          const SizedBox(height: 8),
          if (_yukleniyor)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(color: DiziRenkler.sari),
              ),
            )
          else if (_hata != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _hata!,
                      style: TextStyle(color: DiziRenkler.metin54),
                    ),
                  ),
                  TextButton(onPressed: _yukle, child: Text('Tekrar dene'.c)),
                ],
              ),
            )
          else if (_sezonlar != null)
            _Izgara(sezonlar: _sezonlar!, onBolumSec: _bolumeGit),
        ],
      ],
    );
  }
}

/// Üstte sezonlar, solda bölümler; kesişimde puan kutusu.
///
/// ─────────────────────────────────────────────────────────────────────────
/// ÖLÇÜ KARARI — İKİ AŞAMALI, ikincisi bir GERİ ALMA.
///
/// 1) Kullanıcı (14 Ağu): *"kutular hâlâ çok büyük, o ekranı %50 daha küçük
///    yapabilirsin"*. Adım 44 → 22, kutu 32 → 18 yapıldı. Kutudan puan YAZISI
///    da çıktı, çünkü 18 dp'ye sayı sığmıyordu.
/// 2) Aynı gün, kullanıcı sonucu görünce: *"şu an çok küçük oldular ve
///    sayılar gözükmüyor. %50 fazla oldu, %25 yapalım."* — yani küçültmenin
///    kendisi değil, MİKTARI ve yazının kaybı yanlıştı.
///
/// BUGÜNKÜ HÂL: referans, sayının GÖRÜNDÜĞÜ eski hâldir (adım 44 / kutu 32) ve
/// ondan %25 küçültülür.
///  * Adım 44 → 33 dp (`dokunmaHedefi * 0.75`), görünen kutu 32 → 24 dp,
///    hücreler arası boşluk 12 → 9 dp. Üç ölçü de tam 0,75 katı, yani ızgara
///    ORANTILI küçüldü; 22 dp'lik ara tur (0,50) terk edildi.
///  * 10 sezon × 20 bölüm: 484 × 924 → 363 × 693 dp. Her kenarda %25, alanda
///    %43,75 kazanç. (Ara turdaki 242 × 462'ye göre büyüme kasıtlı.)
///  * SAYI KUTUYA GERİ DÖNDÜ, üstelik eski fontSize 12 ile — 24 dp'lik kutuda
///    okunabilirlik düşmedi. Bunu mümkün kılan tek numara `10.0` yerine `10`
///    yazmak; gerekçesi [tmdbPuanKisaMetni] içinde ölçülerle duruyor.
///    `FittedBox(scaleDown)` güvence katmanı: kullanıcı yazı ölçeğini
///    büyütürse sayı taşmaz, küçülür.
///  * Sayı geri gelince 4,5:1 KONTRAST ŞARTI da geri geldi. Canlı palet YİNE
///    DE korundu: yük dolguya değil [tmdbPuanYaziRengi]'ne bindirildi (açık
///    kovada koyu yazı, koyu kovada beyaz) — ölçümler o fonksiyonun başında.
///
/// "HÜCRE GEZİNMEZ, SEÇER" KARARI DURUYOR ve hâlâ zorunlu: 33 dp < 44 dp.
///  * 44 dp KURALI ÇİĞNENMEDİ, kapsamı daraldı: kural GEZİNME denetimleri
///    içindir, çünkü orada ıskalamanın bedeli yanlış sayfa + geri tuşu +
///    kaybolan kaydırma konumudur. 33 dp'lik hücreye ıskalayarak dokunmanın
///    bedeli ise komşu hücrenin seçilmesi — ekran değişmez, düzeltme tek
///    dokunuş. GERÇEK gezinme hedefi [_Balon]'dur ve o 190 × 44 dp'dir.
///  * Sayı kutuda görünse de balon gereksiz olmadı: sezon/bölüm numarasını
///    ("S1 · 3. Bölüm") ve tam ondalığı yazar, bölüme götürür.
///  * Renk tek başına anlam taşımıyor — puan artık DÖRT kanaldan veriliyor:
///    kutudaki sayı, [_Balon], her hücrenin `Semantics` etiketi, [_Gosterge].
///
/// DİKEY TAVAN YOK (sabahki karar korunuyor): ızgara komple açılır, detay
/// sayfasının kendi `CustomScrollView`'ıyla kayar. Yatay kaydırma kalır —
/// sezon sayısı ekranı aşabilir ve orada sayfa kaydırması işe yaramaz.
class _Izgara extends StatefulWidget {
  final List<TmdbSezonPuani> sezonlar;
  final void Function(int sezon, int bolum) onBolumSec;

  const _Izgara({required this.sezonlar, required this.onBolumSec});

  /// Izgara adımı: dokunma hedefinin %75'i (44 → 33 dp).
  static const hucre = dokunmaHedefi * 0.75;

  /// Görünen renkli kutu (32 → 24; aradaki 9 dp hücreler arası boşluk).
  static const kutu = 32.0 * 0.75;

  /// Kutudaki puanın yazı boyu. Küçültmeden ÖNCEKİ değerle aynı (12 dp):
  /// kutu %25 küçüldü ama okunabilirlik küçülmedi. Poppins ExtraBold ile en
  /// geniş hücre metni `9.2` = 17,7 dp ve kontur içi 22 dp'ye rahat sığıyor
  /// (bkz. [tmdbPuanKisaMetni]).
  static const yazi = 12.0;

  /// Satır/sütun başlıkları (`S1`, `E20`) — veriden bir kademe geride.
  static const baslikYazi = 11.0;

  /// Okuma balonu: seçilen hücrenin puanını YAZIYLA veren ve bölüm sayfasına
  /// götüren gerçek gezinme hedefi. Yükseklik dokunma hedefine eşit.
  static const balonEni = 190.0;
  static const balonBoyu = dokunmaHedefi;

  @override
  State<_Izgara> createState() => _IzgaraState();
}

class _IzgaraState extends State<_Izgara> {
  /// Seçili hücre: (sezon no, bölüm no). Aynı hücreye tekrar dokunmak kapatır.
  (int, int)? _secili;

  @override
  Widget build(BuildContext context) {
    final maxB = tmdbMaxBolum(widget.sezonlar);
    if (maxB == 0) return const SizedBox.shrink();
    final sezonlar = widget.sezonlar;
    final izgaraEni = (1 + sezonlar.length) * _Izgara.hucre;
    final boy = (1 + maxB) * _Izgara.hucre;
    // Balon ızgaradan geniş olabilir (tek sezonluk dizi): Stack o zaman
    // balona göre genişler. Aksi hâlde `Positioned` Stack sınırının dışına
    // taşar ve TIKLANAMAZ olur (bu projede bilinen tuzak).
    final en = math.max(izgaraEni, _Izgara.balonEni);

    return Semantics(
      label: 'Bölüm puanları'.c,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: en,
                height: boy,
                child: Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            const SizedBox(
                              width: _Izgara.hucre,
                              height: _Izgara.hucre,
                            ),
                            for (var b = 1; b <= maxB; b++)
                              _BaslikKutusu('E{}'.cf([b])),
                          ],
                        ),
                        for (final s in sezonlar)
                          Column(
                            children: [
                              _BaslikKutusu('S{}'.cf([s.sezonNo])),
                              for (var b = 1; b <= maxB; b++)
                                _PuanHucresi(
                                  kayit: s.bolumler[b],
                                  sezon: s.sezonNo,
                                  bolum: b,
                                  secili: _secili == (s.sezonNo, b),
                                  onTap: () => _sec(s.sezonNo, b),
                                ),
                            ],
                          ),
                      ],
                    ),
                    ..._balon(en, boy),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const _Gosterge(),
        ],
      ),
    );
  }

  void _sec(int sezon, int bolum) {
    setState(() => _secili = _secili == (sezon, bolum) ? null : (sezon, bolum));
  }

  /// Seçili hücrenin ÜSTÜNE (yer yoksa altına) tutturulan okuma balonu.
  ///
  /// Konum aritmetikle bulunur — ızgara birörnek olduğu için `GlobalKey`
  /// gerekmez: sütun i, x = (1+i)·adım; bölüm b, y = b·adım.
  List<Widget> _balon(double en, double boy) {
    final sec = _secili;
    if (sec == null) return const [];
    final sIdx = widget.sezonlar.indexWhere((s) => s.sezonNo == sec.$1);
    if (sIdx < 0) return const [];
    final kayit = widget.sezonlar[sIdx].bolumler[sec.$2];
    if (kayit == null) return const [];

    const w = _Izgara.balonEni;
    const h = _Izgara.balonBoyu;
    final merkezX = (1 + sIdx) * _Izgara.hucre + _Izgara.hucre / 2;
    final sol = (merkezX - w / 2).clamp(0.0, math.max(0.0, en - w)).toDouble();
    // Üstte yer varsa üste, yoksa alta; her hâlükârda Stack İÇİNE kırpılır —
    // sınır dışına taşan `Positioned` dokunuş almaz.
    final ustteYer = sec.$2 * _Izgara.hucre - 4 >= h;
    final istenen = ustteYer
        ? sec.$2 * _Izgara.hucre - 4 - h
        : (sec.$2 + 1) * _Izgara.hucre + 4;
    final ust = istenen.clamp(0.0, math.max(0.0, boy - h)).toDouble();

    return [
      Positioned(
        left: sol,
        top: ust,
        width: w,
        height: h,
        child: _Balon(
          sezon: sec.$1,
          bolum: sec.$2,
          puan: kayit.puan,
          // Oyu olmayan bölüm eskiden de gezinmezdi (o hücre "—"ydi);
          // balon bilgiyi verir ama bölüme götürmez.
          onGit: kayit.puan == null
              ? null
              : () => widget.onBolumSec(sec.$1, sec.$2),
        ),
      ),
    ];
  }
}

class _BaslikKutusu extends StatelessWidget {
  final String yazi;
  const _BaslikKutusu(this.yazi);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _Izgara.hucre,
      height: _Izgara.hucre,
      child: Center(
        // 33 dp hücrede "E20"/"S10" 11 dp'de rahat durur (Poppins ExtraBold
        // "E20" = 19,5 dp). FittedBox daha uzun numaralarda (E100) taşırmak
        // yerine bir tık küçültür.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            yazi,
            style: TextStyle(
              fontSize: _Izgara.baslikYazi,
              fontWeight: FontWeight.w800,
              color: DiziRenkler.metin70,
            ),
          ),
        ),
      ),
    );
  }
}

class _PuanHucresi extends StatelessWidget {
  final TmdbBolumPuani? kayit;
  final int sezon;
  final int bolum;
  final bool secili;
  final VoidCallback onTap;

  const _PuanHucresi({
    required this.kayit,
    required this.sezon,
    required this.bolum,
    required this.secili,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // OLMAYAN BÖLÜM (kullanıcı: "olmayan bölümlerde — kullanmak yerine boş
    // bırak"). Izgara dikdörtgen olduğu için 8 bölümlük sezonun 22. satırında
    // da bir hücre yeri vardır; orada gösterilecek HİÇBİR ŞEY yoktur: kutu
    // yok, yazı yok, `Semantics` yok, dokunuş yok.
    if (kayit == null) {
      return const SizedBox(width: _Izgara.hucre, height: _Izgara.hucre);
    }
    // VAR OLAN AMA OYU OLMAYAN BÖLÜM: nötr GRİ kutu + "—". Ayrım iki kanallı:
    // kutunun VARLIĞI "bölüm var" der, GRİ + tire "puan yok" der. Grinin
    // zeminden 3:1 ayrışması yine ZORUNLU (bkz. `tmdbPuanKutuRengi`) — renk
    // körü ya da yazıyı okuyamayan kullanıcı için kutunun kendisi sınırdır.
    final puan = kayit!.puan;
    return Semantics(
      button: true,
      selected: secili,
      label:
          'S{} · {}. Bölüm'.cf([sezon, bolum]) +
          (puan == null ? '' : ', ${tmdbPuanMetni(puan)} TMDB'),
      // Kutudaki sayı ayrıca SESLENDİRİLMEZ: etiket zaten sezonu, bölümü ve
      // puanı söylüyor. Dışlanmazsa hücre "S1 · 1. Bölüm, 7.6 TMDB" + "7.6"
      // diye iki kez okunur ve etiket kirlenir.
      excludeSemantics: true,
      child: SizedBox(
        width: _Izgara.hucre,
        height: _Izgara.hucre,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: Container(
              width: _Izgara.kutu,
              height: _Izgara.kutu,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tmdbPuanKutuRengi(puan),
                borderRadius: BorderRadius.circular(6),
                // Seçim GERİ BİLDİRİMİ: kutu büyümez (ızgara zıplamasın),
                // konturu kalınlaşır ve tema metin rengine döner. Parmağın
                // altında kalan bir splash'tan daha görünür.
                border: Border.all(
                  color: secili ? DiziRenkler.metin : tmdbPuanKenarRengi(puan),
                  width: secili ? 2 : 1,
                ),
              ),
              // PUAN KUTUNUN İÇİNDE (kullanıcı: "sayılar gözükmüyor").
              // FittedBox yalnız GÜVENCE: 12 dp'de en geniş metin (`9.2`
              // 17,7 dp) kontur içi 22 dp'ye zaten sığıyor, ama kullanıcının
              // yazı ölçeği büyükse taşmak yerine küçülsün.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tmdbPuanKisaMetni(puan),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: _Izgara.yazi,
                    fontWeight: FontWeight.w800,
                    // M3 gövde metni 0,25 dp harf aralığı taşır; 22 dp'lik
                    // yerde bu bedava genişlik demek. Sıfırlanınca `9.2`
                    // 19,5 → 17,7 dp'ye iner ve ölçü temadan bağımsızlaşır.
                    letterSpacing: 0,
                    // Kova başına seçilir: açık dolguda koyu, koyu dolguda
                    // beyaz. Canlı rampanın 4,5:1 taşımasının tek yolu.
                    color: tmdbPuanYaziRengi(puan),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Seçili hücrenin okuma balonu: hangi bölüm olduğunu söyler ve oraya götürür.
///
/// Sayı hücreye geri geldikten sonra da zorunlu, çünkü iki iş yapıyor:
///  * 44 dp'lik GERÇEK gezinme hedefidir (33 dp'lik hücre yalnız seçer).
///  * Hücrenin söyleyemediğini söyler: sezon/bölüm numarası ("S1 · 3. Bölüm")
///    ve tam ondalık (`10.0`, hücrede yer darlığından `10` yazıyor).
class _Balon extends StatelessWidget {
  final int sezon;
  final int bolum;
  final double? puan;
  final VoidCallback? onGit;

  const _Balon({
    required this.sezon,
    required this.bolum,
    required this.puan,
    required this.onGit,
  });

  @override
  Widget build(BuildContext context) {
    final baslik = 'S{} · {}. Bölüm'.cf([sezon, bolum]);
    final govde = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: tmdbPuanKutuRengi(puan),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tmdbPuanMetni(puan),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: tmdbPuanYaziRengi(puan),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              baslik,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: DiziRenkler.metin,
              ),
            ),
          ),
          if (onGit != null)
            Icon(Icons.chevron_right, size: 18, color: DiziRenkler.metin54),
        ],
      ),
    );
    return Semantics(
      button: onGit != null,
      label: puan == null ? baslik : '$baslik, ${tmdbPuanMetni(puan)} TMDB',
      child: Material(
        color: DiziRenkler.kart,
        // Balon ızgaranın ÜSTÜNDE yüzer: gölge + ince kontur olmadan renkli
        // kutuların arasında yamalı görünür. Tint kapalı — kart rengi M3'ün
        // yüzey boyamasıyla kaymasın.
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: DiziRenkler.metin24),
        ),
        clipBehavior: Clip.antiAlias,
        child: onGit == null ? govde : InkWell(onTap: onGit, child: govde),
      ),
    );
  }
}

/// Renk → puan göstergesi. Hücrede sayı olsa da KALIYOR: ızgaraya bakan göz
/// önce ÖRÜNTÜYÜ görür, örüntü ise renkten okunur — hangi rengin hangi aralık
/// olduğunu söyleyen tek yer burasıdır.
///
/// Etiketler sayı/simge olduğu için çeviri anahtarı gerektirmez.
class _Gosterge extends StatelessWidget {
  const _Gosterge();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Puan göstergesi'.c,
      child: Wrap(
        spacing: 10,
        runSpacing: 4,
        children: [
          for (final k in tmdbPuanKovalari)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: tmdbPuanKutuRengi(k.ornek),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: tmdbPuanKenarRengi(k.ornek)),
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  k.etiket,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: DiziRenkler.metin54,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
