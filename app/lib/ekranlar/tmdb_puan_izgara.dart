import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../puan.dart' show yildizOrtalamaMetni;
import '../tema.dart';
import '../tmdb_bolum_puan.dart';
import 'ortak.dart';

/// Izgarayı DIŞARIDAN açıp kapatan kumanda — detay sayfasındaki dizi.jpg
/// rozeti aynı paneli kendi kaynağıyla açsın diye (14 Eyl 2026).
///
/// Rozet detay'da, panel bu dosyada; ikisi kardeş widget. `GlobalKey` yerine
/// kumanda: rozet [acKapa]'yı çağırır, panel açık kaynağı [acik] üzerinden
/// duyurur (rozetin oku yön değiştirsin diye `ChangeNotifier`).
class PuanHaritasiKumandasi extends ChangeNotifier {
  PuanKaynagi? _acik;
  void Function(PuanKaynagi)? _acKapa;

  /// Şu an açık olan kaynak; kapalıysa null.
  PuanKaynagi? get acik => _acik;

  /// Paneli [kaynak] ile açar; zaten o kaynakla açıksa kapatır; başka
  /// kaynakla açıksa kaynağı değiştirir (kapatmaz).
  void acKapa(PuanKaynagi kaynak) => _acKapa?.call(kaynak);

  void _bildir(PuanKaynagi? acik) {
    if (_acik == acik) return;
    _acik = acik;
    notifyListeners();
  }
}

/// Detay sayfasındaki TMDB puanı: dokununca altında sezon×bölüm ısı
/// haritası açılır. [yan] dizi.jpg rozeti ve izleyen sayısı gibi aynı
/// satırdaki diğer çocuklar — ızgara onların ALTINA iner, yanına değil.
///
/// İKİ KAYNAK (14 Eyl 2026): panelin üstündeki sekmelerden TMDB ile
/// dizi.jpg arasında geçilir; dizi.jpg rozeti ([kumanda] üzerinden) paneli
/// doğrudan kendi kaynağıyla açar. Neden yalnız iki kaynak: [PuanKaynagi].
class TmdbPuanHaritasi extends StatefulWidget {
  final int tmdbId;
  final double ortalama;
  final List<int> sezonNolari;
  final List<Widget> yan;
  final void Function(int sezon, int bolum)? onBolumSec;

  /// Sezon no → bölüm sayısı (`episode_count`). dizi.jpg kaynağı "bölüm var
  /// ama puanı yok" hücrelerini bununla çizer; boşsa yalnız puanlı bölümler
  /// görünür.
  final Map<int, int> sezonBolumSayilari;

  /// Dıştan açma/kapama (dizi.jpg rozeti). Verilmezse yalnız TMDB satırı açar.
  final PuanHaritasiKumandasi? kumanda;

  /// dizi.jpg kaynağında panel başlığındaki "Puan dağılımı" düğmesi. Null ise
  /// düğme yok.
  final VoidCallback? onDagilim;

  const TmdbPuanHaritasi({
    super.key,
    required this.tmdbId,
    required this.ortalama,
    required this.sezonNolari,
    this.yan = const [],
    this.onBolumSec,
    this.sezonBolumSayilari = const {},
    this.kumanda,
    this.onDagilim,
  });

  @override
  State<TmdbPuanHaritasi> createState() => _TmdbPuanHaritasiState();
}

class _TmdbPuanHaritasiState extends State<TmdbPuanHaritasi> {
  /// Açık kaynak; kapalıyken null.
  PuanKaynagi? _acik;
  final _yukleniyor = <PuanKaynagi>{};
  final _hata = <PuanKaynagi, String>{};
  final _veri = <PuanKaynagi, List<TmdbSezonPuani>>{};

  @override
  void initState() {
    super.initState();
    widget.kumanda?._acKapa = _acKapa;
  }

  @override
  void didUpdateWidget(TmdbPuanHaritasi eski) {
    super.didUpdateWidget(eski);
    if (eski.kumanda != widget.kumanda) {
      eski.kumanda?._acKapa = null;
      widget.kumanda?._acKapa = _acKapa;
    }
  }

  @override
  void dispose() {
    widget.kumanda?._acKapa = null;
    super.dispose();
  }

  Future<void> _yukle(PuanKaynagi kaynak) async {
    setState(() {
      _yukleniyor.add(kaynak);
      _hata.remove(kaynak);
    });
    try {
      final nolar = widget.sezonNolari;
      final yanitlar = await Future.wait(
        nolar.map((n) async {
          try {
            final yol = kaynak == PuanKaynagi.tmdb
                ? '/tmdb/tv/${widget.tmdbId}/season/$n'
                : '/bolum-puanlari/${widget.tmdbId}/$n';
            final d = await Api.get(yol);
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
        final m = y.value as Map;
        sezonlar.add(
          TmdbSezonPuani(
            sezonNo: y.key,
            bolumler: kaynak == PuanKaynagi.tmdb
                ? tmdbBolumleriOku(m['episodes'])
                : dizijpgBolumleriOku(
                    m['bolumler'],
                    widget.sezonBolumSayilari[y.key] ?? 0,
                  ),
          ),
        );
      }
      if (sezonlar.isEmpty) {
        setState(() {
          _yukleniyor.remove(kaynak);
          _hata[kaynak] = 'Bölüm puanları yüklenemedi'.c;
        });
        return;
      }
      setState(() {
        _veri[kaynak] = sezonlar;
        _yukleniyor.remove(kaynak);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yukleniyor.remove(kaynak);
        _hata[kaynak] = 'Bölüm puanları yüklenemedi'.c;
      });
    }
  }

  /// Aynı kaynağa ikinci dokunuş KAPATIR; başka kaynağa dokunuş kaynağı
  /// DEĞİŞTİRİR (panel açık kalır — kullanıcı kıyaslıyor, kapatmıyor).
  Future<void> _acKapa(PuanKaynagi kaynak) async {
    if (_acik == kaynak) {
      setState(() => _acik = null);
      widget.kumanda?._bildir(null);
      return;
    }
    setState(() => _acik = kaynak);
    widget.kumanda?._bildir(kaynak);
    if (!_veri.containsKey(kaynak) && !_yukleniyor.contains(kaynak)) {
      await _yukle(kaynak);
    }
  }

  void _kapat() {
    setState(() => _acik = null);
    widget.kumanda?._bildir(null);
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
    final acik = _acik;
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
              onTap: () => _acKapa(PuanKaynagi.tmdb),
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
                          acik == PuanKaynagi.tmdb
                              ? Icons.expand_less
                              : Icons.expand_more,
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
        if (acik != null) ...[
          const SizedBox(height: 8),
          _Panel(
            kaynak: acik,
            onKaynak: (k) {
              if (k != acik) _acKapa(k);
            },
            onKapat: _kapat,
            onDagilim: acik == PuanKaynagi.dizijpg ? widget.onDagilim : null,
            govde: _yukleniyor.contains(acik)
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(color: DiziRenkler.sari),
                    ),
                  )
                : _hata[acik] != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _hata[acik]!,
                            style: TextStyle(color: DiziRenkler.metin54),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _yukle(acik),
                          child: Text('Tekrar dene'.c),
                        ),
                      ],
                    ),
                  )
                : _veri[acik] != null
                ? _Izgara(
                    key: ValueKey(acik),
                    kaynak: acik,
                    sezonlar: _veri[acik]!,
                    onBolumSec: _bolumeGit,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }
}

/// Izgaranın kabı: kart zemini + üstte kaynak sekmeleri (TMDB / dizi.jpg),
/// sağda kapatma; dizi.jpg kaynağında "Puan dağılımı" kestirmesi.
///
/// NEDEN KART: eski ızgara sayfa zeminine çıplak oturuyordu ve nerede
/// başlayıp bittiği belli değildi; iki kaynak gelince "şu an hangisine
/// bakıyorum" sorusu da eklendi. Kart hem sınırı hem başlığı verir.
class _Panel extends StatelessWidget {
  final PuanKaynagi kaynak;
  final void Function(PuanKaynagi) onKaynak;
  final VoidCallback onKapat;
  final VoidCallback? onDagilim;
  final Widget govde;

  const _Panel({
    required this.kaynak,
    required this.onKaynak,
    required this.onKapat,
    required this.onDagilim,
    required this.govde,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('puan-paneli'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 10),
      decoration: BoxDecoration(
        color: DiziRenkler.kart,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DiziRenkler.metin12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final k in PuanKaynagi.values) ...[
                _KaynakSekmesi(
                  kaynak: k,
                  secili: k == kaynak,
                  onTap: () => onKaynak(k),
                ),
                const SizedBox(width: 6),
              ],
              const Spacer(),
              if (onDagilim != null)
                Semantics(
                  button: true,
                  label: 'Puan dağılımı'.c,
                  child: IconButton(
                    key: const Key('puan-dagilimi'),
                    tooltip: 'Puan dağılımı'.c,
                    onPressed: onDagilim,
                    iconSize: 20,
                    color: DiziRenkler.metin70,
                    icon: const Icon(Icons.bar_chart),
                  ),
                ),
              Semantics(
                button: true,
                label: 'Kapat'.c,
                child: IconButton(
                  key: const Key('puan-paneli-kapat'),
                  tooltip: 'Kapat'.c,
                  onPressed: onKapat,
                  iconSize: 20,
                  color: DiziRenkler.metin70,
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          govde,
        ],
      ),
    );
  }
}

/// Kaynak sekmesi: seçili olan marka sarısıyla DOLU (siyah yazı), diğeri
/// yalnız konturlu. Dokunma alanı 44 dp; görünen pul daha alçak.
class _KaynakSekmesi extends StatelessWidget {
  final PuanKaynagi kaynak;
  final bool secili;
  final VoidCallback onTap;

  const _KaynakSekmesi({
    required this.kaynak,
    required this.secili,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: secili,
      label: kaynak.etiket,
      excludeSemantics: true,
      child: InkWell(
        key: Key('kaynak-${kaynak.name}'),
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(
          height: dokunmaHedefi,
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: secili ? DiziRenkler.sari : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: secili ? DiziRenkler.sari : DiziRenkler.metin24,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (kaynak == PuanKaynagi.tmdb) ...[
                    Icon(
                      Icons.star,
                      size: 14,
                      color: secili ? Colors.black : DiziRenkler.sariMetin,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    kaynak.etiket,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: secili ? Colors.black : DiziRenkler.metin70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hücre / balon / özet METİNLERİ kaynağa göre: TMDB 0-10 tek ondalık;
/// dizi.jpg kullanıcının ölçeğinde ([yildizOrtalamaMetni]: 5'likte "4.2",
/// 100'lükte "83"). [ham] dizi.jpg'nin kanonik (1-100) değeridir; TMDB'de
/// yok sayılır.
String _puanMetni(PuanKaynagi kaynak, double? puan, {num? ham}) {
  if (puan == null) return '—';
  if (kaynak == PuanKaynagi.tmdb) return tmdbPuanMetni(puan);
  return yildizOrtalamaMetni(ham ?? puan * 10);
}

/// Hücre metni: [_puanMetni] ama TMDB'de `10.0` → `10` (yer darlığı,
/// bkz. [tmdbPuanKisaMetni]). dizi.jpg ölçeği zaten kısa: 10'luk ölçekte
/// "10.0" yine [tmdbPuanKisaMetni] kuralıyla kısalır.
String _hucreMetni(PuanKaynagi kaynak, double? puan, {num? ham}) {
  final s = _puanMetni(kaynak, puan, ham: ham);
  return s == '10.0' ? '10' : s;
}

/// Üstte sezonlar, solda bölümler; kesişimde puan kutusu. En altta sezon
/// ortalaması satırı ("Ort."), en üstte en iyi bölüm özeti.
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
/// SEZON ORTALAMASI SATIRI (14 Eyl 2026): ızgaranın en altında, bölüm
/// satırlarıyla aynı adımda bir satır daha. Etiketi "Ort.", her sezon
/// sütununda oyla ağırlıklı ortalama ([tmdbSezonOrtalamasi]) — kutudan
/// alçak bir pul, aynı kova rengi. Bölüm hücresiyle karışmasın diye pul
/// 24 dp KARE DEĞİL (24 × 18) ve dokununca seçmez.
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
  final PuanKaynagi kaynak;
  final List<TmdbSezonPuani> sezonlar;
  final void Function(int sezon, int bolum) onBolumSec;

  const _Izgara({
    super.key,
    required this.kaynak,
    required this.sezonlar,
    required this.onBolumSec,
  });

  /// Izgara adımı: dokunma hedefinin %75'i (44 → 33 dp).
  static const hucre = dokunmaHedefi * 0.75;

  /// Görünen renkli kutu (32 → 24; aradaki 9 dp hücreler arası boşluk).
  static const kutu = 32.0 * 0.75;

  /// Sezon ortalaması pulunun boyu (kutudan alçak: bölüm hücresi değil).
  static const ortalamaBoyu = 18.0;

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
    if (maxB == 0) {
      // dizi.jpg kaynağında hiç bölüm kaydı yok (sezon listesi de boş):
      // boş ızgara yerine tek satır. TMDB'de sezon yanıtı gelmişse bölüm
      // de vardır; buraya pratikte dizi.jpg düşer.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Henüz değerlendirme yok'.c,
          style: TextStyle(color: DiziRenkler.metin54),
        ),
      );
    }
    final sezonlar = widget.sezonlar;
    final izgaraEni = (1 + sezonlar.length) * _Izgara.hucre;
    // Başlık satırı + bölüm satırları + ortalama satırı.
    final boy = (2 + maxB) * _Izgara.hucre;
    // Balon ızgaradan geniş olabilir (tek sezonluk dizi): Stack o zaman
    // balona göre genişler. Aksi hâlde `Positioned` Stack sınırının dışına
    // taşar ve TIKLANAMAZ olur (bu projede bilinen tuzak).
    final en = math.max(izgaraEni, _Izgara.balonEni);
    final enIyi = tmdbEnIyiBolum(sezonlar);

    return Semantics(
      label: 'Bölüm puanları'.c,
      // Çocuklar KENDİ düğümlerini kursun: "En iyi bölüm" özeti kaydırma
      // sınırının DIŞINDA (hücreler içinde) ve bu bayrak olmadan etiketli
      // ebeveyne karışıp ekran okuyucuda kayboluyordu.
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (enIyi != null) ...[
            _EnIyiOzeti(
              kaynak: widget.kaynak,
              sezon: enIyi.sezon,
              bolum: enIyi.bolum,
              onTap: () => _sec(enIyi.sezon, enIyi.bolum.bolumNo),
            ),
            const SizedBox(height: 4),
          ],
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
                            _BaslikKutusu('Ort.'.c, vurgulu: true),
                          ],
                        ),
                        for (final s in sezonlar)
                          Column(
                            children: [
                              _BaslikKutusu('S{}'.cf([s.sezonNo])),
                              for (var b = 1; b <= maxB; b++)
                                _PuanHucresi(
                                  kaynak: widget.kaynak,
                                  kayit: s.bolumler[b],
                                  sezon: s.sezonNo,
                                  bolum: b,
                                  secili: _secili == (s.sezonNo, b),
                                  onTap: () => _sec(s.sezonNo, b),
                                ),
                              _OrtalamaPulu(
                                kaynak: widget.kaynak,
                                sezon: s.sezonNo,
                                ortalama: tmdbSezonOrtalamasi(s),
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
          kaynak: widget.kaynak,
          sezon: sec.$1,
          bolum: sec.$2,
          kayit: kayit,
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

/// Izgaranın üstündeki tek satırlık özet: en yüksek puanlı bölüm. Dokununca
/// o hücre SEÇİLİR (balonu açılır) — gezinme balondan, alışılmış yoldan.
///
/// Metin "S1 E3" biçiminde (başlık hücreleriyle aynı dil), balonun
/// "S1 · 3. Bölüm"ünden bilerek farklı: ikisi aynı anda görünebilir.
class _EnIyiOzeti extends StatelessWidget {
  final PuanKaynagi kaynak;
  final int sezon;
  final TmdbBolumPuani bolum;
  final VoidCallback onTap;

  const _EnIyiOzeti({
    required this.kaynak,
    required this.sezon,
    required this.bolum,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final puan = bolum.puan;
    final yer = '${'S{}'.cf([sezon])} ${'E{}'.cf([bolum.bolumNo])}';
    final metin = _puanMetni(kaynak, puan, ham: bolum.ham);
    return Semantics(
      button: true,
      label: '${'En iyi bölüm'.c}: $yer, $metin ${kaynak.etiket}',
      excludeSemantics: true,
      child: InkWell(
        key: const Key('en-iyi-bolum'),
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          height: dokunmaHedefi * 0.75,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.emoji_events_outlined,
                size: 16,
                color: DiziRenkler.sariMetin,
              ),
              const SizedBox(width: 6),
              Text(
                'En iyi bölüm'.c,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: DiziRenkler.metin70,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                yer,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: DiziRenkler.metin,
                ),
              ),
              const SizedBox(width: 6),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tmdbPuanKutuRengi(puan),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tmdbPuanKenarRengi(puan)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  child: Text(
                    metin,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                      color: tmdbPuanYaziRengi(puan),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BaslikKutusu extends StatelessWidget {
  final String yazi;

  /// "Ort." etiketi: bölüm numaralarından ayrışsın diye tema metin rengi.
  final bool vurgulu;
  const _BaslikKutusu(this.yazi, {this.vurgulu = false});

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
              color: vurgulu ? DiziRenkler.metin : DiziRenkler.metin70,
            ),
          ),
        ),
      ),
    );
  }
}

/// Sezon sütununun altındaki ortalama pulu: kova rengi, kutudan alçak
/// (24 × 18), dokunmaz. Puanlı bölüm yoksa gri "—".
class _OrtalamaPulu extends StatelessWidget {
  final PuanKaynagi kaynak;
  final int sezon;
  final double? ortalama;

  const _OrtalamaPulu({
    required this.kaynak,
    required this.sezon,
    required this.ortalama,
  });

  @override
  Widget build(BuildContext context) {
    final metin = _hucreMetni(kaynak, ortalama);
    return Semantics(
      label: '${'S{}'.cf([sezon])} ${'Ort.'.c} $metin',
      excludeSemantics: true,
      child: SizedBox(
        width: _Izgara.hucre,
        height: _Izgara.hucre,
        child: Center(
          child: SizedBox(
            width: _Izgara.kutu,
            height: _Izgara.ortalamaBoyu,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tmdbPuanKutuRengi(ortalama),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: tmdbPuanKenarRengi(ortalama)),
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      metin,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                        color: tmdbPuanYaziRengi(ortalama),
                      ),
                    ),
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

class _PuanHucresi extends StatelessWidget {
  final PuanKaynagi kaynak;
  final TmdbBolumPuani? kayit;
  final int sezon;
  final int bolum;
  final bool secili;
  final VoidCallback onTap;

  const _PuanHucresi({
    required this.kaynak,
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
    final metin = _puanMetni(kaynak, puan, ham: kayit!.ham);
    return Semantics(
      button: true,
      selected: secili,
      label:
          'S{} · {}. Bölüm'.cf([sezon, bolum]) +
          (puan == null ? '' : ', $metin ${kaynak.etiket}'),
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
                  _hucreMetni(kaynak, puan, ham: kayit!.ham),
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
///
/// dizi.jpg kaynağında ikinci satır: kaç kişi puanladı + varsa SENİN puanın
/// ("Sen 4.5") — TMDB'de bu bilgi yok, satır çizilmez.
class _Balon extends StatelessWidget {
  final PuanKaynagi kaynak;
  final int sezon;
  final int bolum;
  final TmdbBolumPuani kayit;
  final VoidCallback? onGit;

  const _Balon({
    required this.kaynak,
    required this.sezon,
    required this.bolum,
    required this.kayit,
    required this.onGit,
  });

  @override
  Widget build(BuildContext context) {
    final puan = kayit.puan;
    final baslik = 'S{} · {}. Bölüm'.cf([sezon, bolum]);
    final metin = _puanMetni(kaynak, puan, ham: kayit.ham);
    final dizijpg = kaynak == PuanKaynagi.dizijpg;
    final benim = kayit.benim;
    // dizi.jpg alt satırı: "N kişi puanladı · Sen 4.5". Puan yoksa ama
    // kullanıcının kendi puanı varsa yalnız ikincisi (tohum süzgeci ortalamayı
    // düşürmüş olabilir).
    final alt = !dizijpg
        ? null
        : [
            if (kayit.oy > 0) '{} kişi puanladı'.cf([kayit.oy]),
            if (benim != null) '${'Sen'.c} ${yildizOrtalamaMetni(benim)}',
          ].join(' · ');
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
              metin,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: tmdbPuanYaziRengi(puan),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baslik,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: DiziRenkler.metin,
                  ),
                ),
                if (alt != null && alt.isNotEmpty)
                  Text(
                    alt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: DiziRenkler.metin54,
                    ),
                  ),
              ],
            ),
          ),
          if (onGit != null)
            Icon(Icons.chevron_right, size: 18, color: DiziRenkler.metin54),
        ],
      ),
    );
    return Semantics(
      button: onGit != null,
      label: [
        puan == null ? baslik : '$baslik, $metin ${kaynak.etiket}',
        if (alt != null && alt.isNotEmpty) alt,
      ].join(', '),
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
/// Etiketler sayı/simge olduğu için çeviri anahtarı gerektirmez. dizi.jpg
/// kaynağında da 0-10 kovaları geçerli: renk normalize puandan gelir
/// (kanonik 1-100'ün onda biri), kullanıcının ölçeği yalnız hücre METNİNİ
/// değiştirir.
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
