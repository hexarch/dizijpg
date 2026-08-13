import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import '../yonlendirme.dart' show gonderiYolu;
import 'karsilama.dart' show karsilamaAylar;
import 'ortak.dart';

/// İSTATİSTİKLERİM — Ayarlar > İstatistiklerim (md. 24).
///
/// KULLANICI İSTEĞİ: "tüm zamanların görüntülenmesi, 30 / 60 / 90 / 120 günlük
/// görüntülenme; beğenilerde aynı kırılım." AMACI kendi sözleriyle: "neyini
/// tutuyorsak en net şekilde verelim ki kendi paylaşımlarının kalitesini
/// artırsın."
///
/// ===========================================================================
/// EKRANIN EN ÖNEMLİ KARARI: EKSİK VERİYİ SAKLAMAMAK
/// ===========================================================================
/// Görüntülenmenin ZAMAN kırılımı ancak 14 Ağustos 2026'daki altyapıdan sonra
/// birikmeye başladı; ondan öncesi için "son 30 gün" diye bir sayı YOKTUR ve
/// üretilemez. Bu ekran o boşluğu:
///   * tahminle DOLDURMAZ (oranlayıp şişirmez),
///   * sayıyı gizleyip soruyu yok SAYMAZ,
///   * sayının yanına "veri {tarih} tarihinden beri birikiyor, şu an {n}
///     günlük veri var" satırını koyar ve kısmi sayıyı bir rozetle işaretler.
/// Beğeni kırılımı ise `yorum_begeniler.tarih` sayesinde GERİYE DÖNÜK TAMDIR;
/// o yüzden beğeni sayısında rozet çıkmaz (yalnız kaydın başladığı gün, o da
/// pencere kapsamı aşıldığında).
///
/// GRAFİK YOK — BİLİNÇLİ: elde 4 pencere × 2 ölçü = 8 sayı var; bunları çubuk
/// grafiğe koymak "30 < 60 < 90 < 120" kümülatif merdivenini çizerdi ki her
/// zaman artan, hiçbir şey söylemeyen bir şekildir. Sayılar okunur boyutta ve
/// binlik ayraçlı basılıyor; kalite sinyalini asıl veren şey üstteki iki liste
/// (hangi gönderin tuttu).
class IstatistiklerimEkrani extends StatefulWidget {
  const IstatistiklerimEkrani({super.key});

  @override
  State<IstatistiklerimEkrani> createState() => _IstatistiklerimEkraniState();
}

class _IstatistiklerimEkraniState extends State<IstatistiklerimEkrani> {
  /// Seçili pencere (gün). 0 = tüm zamanlar. Sunucudaki beyaz listeyle aynı.
  int _gun = 30;
  Map<String, dynamic>? _veri;
  String? _hata;

  /// Pencere değiştirilirken ESKİ SAYILAR EKRANDA KALIR (yalnız üstte ince bir
  /// çizgi döner): her dokunuşta ekranı iskelete çevirmek, kullanıcının iki
  /// pencereyi karşılaştırmasını imkânsız kılardı.
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
      final d = await Api.get('/istatistiklerim/gonderiler?gun=$istenen');
      // Hızlı pencere geçişinde geciken ESKİ yanıt düşsün: yoksa 120'ye
      // basıp 30'a dönen kullanıcı bir an 120'nin sayılarını görürdü.
      if (!mounted || istenen != _gun) return;
      setState(() {
        _veri = (d as Map).cast<String, dynamic>();
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

  void _pencereSec(int gun) {
    if (gun == _gun) return;
    setState(() => _gun = gun);
    _yukle();
  }

  /// Seçili pencerenin sunucudan gelen satırı (tüm zamanlarda null).
  Map<String, dynamic>? get _pencere {
    final liste = _veri?['pencereler'] as List<dynamic>? ?? const [];
    for (final p in liste) {
      if ((p as Map)['gun'] == _gun) return p.cast<String, dynamic>();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_hata != null && _veri == null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_veri == null) {
      govde = const _Iskelet();
    } else if ((_veri!['gonderi_sayisi'] as int? ?? 0) == 0) {
      govde = BosDurum(
        ikon: Icons.insights_outlined,
        baslik: 'Henüz gönderin yok'.c,
        ipucu:
            'Bir dizi ya da filme yorum yazdığında görüntülenme ve beğeni sayıların burada birikmeye başlar.'
                .c,
      );
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
          children: _icerik(context),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('İstatistiklerim'.c),
        // Yükleme göstergesi başlıkta: liste yerinde kalsın, sayılar zıplamasın.
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

  List<Widget> _icerik(BuildContext context) {
    final v = _veri!;
    final toplam = (v['toplam'] as Map?)?.cast<String, dynamic>() ?? const {};
    final p = _pencere;
    final tumZaman = _gun == 0;
    // Tüm zamanlar seçiliyken pencere ölçüsü = ömür boyu sayaç.
    final gorSayi = tumZaman
        ? (toplam['goruntulenme'] as int? ?? 0)
        : (p?['goruntulenme'] as int? ?? 0);
    final begSayi = tumZaman
        ? (toplam['begeni'] as int? ?? 0)
        : (p?['begeni'] as int? ?? 0);
    // "Tam" bilgisi yalnız pencerelerde anlamlı: ömür boyu sayaç eksiksizdir
    // (o rakam ilk günden beri artıyor, kaybolan bir şey yok).
    final gorTam = tumZaman || (p?['goruntulenme_tam'] == true);
    final begTam = tumZaman || (p?['begeni_tam'] == true);

    return [
      // --- TÜM ZAMANLAR: ekranın değişmeyen çıpası ------------------------
      _Baslik('Tüm zamanlar'.c),
      Row(
        children: [
          Expanded(
            child: _Sayac(
              ikon: Icons.chat_bubble_outline,
              etiket: 'Gönderi'.c,
              deger: v['gonderi_sayisi'] as int? ?? 0,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Sayac(
              ikon: Icons.visibility_outlined,
              etiket: 'Görüntülenme'.c,
              deger: toplam['goruntulenme'] as int? ?? 0,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Sayac(
              ikon: Icons.favorite_border,
              etiket: 'Beğeni'.c,
              deger: toplam['begeni'] as int? ?? 0,
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),

      // --- ZAMAN KIRILIMI -------------------------------------------------
      _Baslik('Zaman kırılımı'.c),
      _PencereSecici(secili: _gun, onSec: _pencereSec),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _Sayac(
              ikon: Icons.visibility_outlined,
              etiket: 'Görüntülenme'.c,
              deger: gorSayi,
              buyuk: true,
              eksik: !gorTam,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Sayac(
              ikon: Icons.favorite_border,
              etiket: 'Beğeni'.c,
              deger: begSayi,
              buyuk: true,
              eksik: !begTam,
            ),
          ),
        ],
      ),
      ..._kapsamNotu(gorTam: gorTam, begTam: begTam),
      const SizedBox(height: 20),

      // --- ÜST LİSTELER ---------------------------------------------------
      _Baslik('En çok görüntülenen gönderilerin'.c),
      ..._liste(v['en_cok_goruntulenen'], gorunum: true),
      const SizedBox(height: 20),
      _Baslik('En çok beğenilen gönderilerin'.c),
      ..._liste(v['en_cok_begenilen'], gorunum: false),
    ];
  }

  /// "Veri biriktiriliyor" satırı — SAHTE SAYI ÜRETMEMENİN GÖRÜNEN YÜZÜ.
  List<Widget> _kapsamNotu({required bool gorTam, required bool begTam}) {
    final v = _veri!;
    final notlar = <String>[];
    if (!gorTam) {
      final bas = v['goruntulenme_baslangic'] as String?;
      final kacGun = v['goruntulenme_gun'] as int? ?? 0;
      notlar.add(
        bas == null
            ? 'Görüntülenme geçmişi henüz birikmeye başlamadı; ilk gün verisi yarın görünür.'
                  .c
            : 'Görüntülenme geçmişi {} tarihinden beri birikiyor ({} günlük veri var), bu yüzden {} günlük sayı henüz eksik.'
                  .cf([_tarih(bas), kacGun, _gun]),
      );
    }
    if (!begTam && v['begeni_baslangic'] != null) {
      notlar.add(
        'Beğeni geçmişi {} tarihinden beri kayıtlı.'.cf([
          _tarih(v['begeni_baslangic'] as String),
        ]),
      );
    }
    if (notlar.isEmpty) return const [];
    return [
      const SizedBox(height: 10),
      for (final n in notlar)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.hourglass_bottom,
                size: 15,
                color: DiziRenkler.metin38,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  n,
                  style: TextStyle(
                    color: DiziRenkler.metin54,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _liste(dynamic ham, {required bool gorunum}) {
    final satirlar = (ham as List<dynamic>? ?? const []);
    if (satirlar.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Bu dönemde gösterilecek gönderi yok.'.c,
            style: TextStyle(color: DiziRenkler.metin38, fontSize: 13),
          ),
        ),
      ];
    }
    final icerikler =
        (_veri!['icerikler'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return [
      for (final s in satirlar)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _GonderiSatiri(
            gonderi: (s as Map).cast<String, dynamic>(),
            icerik: (icerikler['${s['tur']}:${s['tmdb_id']}'] as Map?)
                ?.cast<String, dynamic>(),
            gorunum: gorunum,
          ),
        ),
    ];
  }

  /// "2026-08-14" → "14 Ağustos 2026". Ay adları KARŞILAMA ekranındaki 12
  /// çeviri anahtarından okunuyor — aynı listeyi ikinci kez açmak, 45 dilde
  /// 12 anahtarı boşuna çoğaltmak olurdu (`intl`in DateFormat'ı kullanılamaz:
  /// uygulama `initializeDateFormatting` çağırmıyor).
  String _tarih(String iso) {
    final p = iso.split('T').first.split('-');
    if (p.length != 3) return iso;
    final ay = int.tryParse(p[1]);
    if (ay == null || ay < 1 || ay > 12) return iso;
    return '${int.tryParse(p[2]) ?? p[2]} ${karsilamaAylar[ay - 1].c} ${p[0]}';
  }
}

/// Binlik ayraçlı sayı: "1234567" değil "1.234.567" (okunurluk kuralı).
String sayiBicimle(int n) =>
    NumberFormat.decimalPattern(Ceviri.dil.value).format(n);

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

/// Tek sayı kutusu. Sayı BÜYÜK ve kalın, etiket altında küçük — "en net
/// şekilde" isteğinin karşılığı.
class _Sayac extends StatelessWidget {
  final IconData ikon;
  final String etiket;
  final int deger;
  final bool buyuk;

  /// Pencerenin tamamı ölçülemediyse true: sayının yanına kum saati konur.
  /// RENKLE DEĞİL İKONLA işaretlenir — renk körlüğünde de görünsün.
  final bool eksik;

  const _Sayac({
    required this.ikon,
    required this.etiket,
    required this.deger,
    this.buyuk = false,
    this.eksik = false,
  });

  @override
  Widget build(BuildContext context) {
    final yazi = sayiBicimle(deger);
    return Semantics(
      label:
          '$etiket: $yazi'
          '${eksik ? ', ${'eksik veri'.c}' : ''}',
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
                  Icon(ikon, size: 16, color: DiziRenkler.sariMetin),
                  if (eksik) ...[
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
              // FittedBox: 7 haneli bir sayı dar sütunda taşmasın, küçülsün.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  yazi,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: buyuk ? 26 : 20,
                    fontWeight: FontWeight.w800,
                    color: DiziRenkler.metin,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                etiket,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: DiziRenkler.metin54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pencere seçici: BEŞ SEÇENEK TEK SATIRDA.
///
/// NEDEN ROW, NEDEN WRAP DEĞİL (13 Ağu 2026 — kullanıcı: "saçma yer kaplıyor"):
/// Eskiden çipler bir `Wrap` içindeydi ve her çip `Container(alignment: ...)`
/// kullanıyordu. `alignment` verilen bir Container child'ını `Align`a sarar;
/// `Align` da GEVŞEK kısıtta ELİNDEKİ TÜM GENİŞLİĞİ kaplar. Yani her çip
/// satırın tamamını yiyordu ve beş çip ALT ALTA beş satır oluyordu: 360 dp'de
/// 252 dp yükseklik (5×44 + 4×8). İskeletin bu bloğa 44 dp ayırmış olması
/// (bkz. [_Iskelet]) tek satırın en baştaki niyet olduğunu gösteriyor —
/// bu bir tasarım tercihi değil, sessiz bir yerleşim hatasıydı.
///
/// Şimdi beş eşit segment tek `Row`da: blok 252 → 44 dp.
///
/// ETİKET KISALTMASI: görünen yazı `'{} gün'` anahtarından ("30 gün",
/// "30 days", "30 Tg.", "30 pv") — bu anahtar 45 dilde ZATEN var (profil ve
/// yasaklı ekranları kullanıyor), yani yeni çeviri borcu YOK. "30g" gibi bir
/// kısaltma seçilmedi: gün birimi Türkçe'de "g", İngilizce'de "d", Fince'de
/// "pv", Japonca'da "日" — tek harfe indirgemek 45 dilin çoğunda anlamsız ya
/// da çevrilemez olurdu. Ekran okuyucu ise kısaltılmış yazıyı DEĞİL, tam
/// cümleyi ("Son 30 gün") duyar; kısalma yalnız GÖZE yapılan bir kısalmadır.
class _PencereSecici extends StatelessWidget {
  /// Seçili pencere (gün); 0 = tüm zamanlar.
  final int secili;
  final ValueChanged<int> onSec;

  const _PencereSecici({required this.secili, required this.onSec});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final g in const [30, 60, 90, 120, 0]) ...[
        if (g != 30) const SizedBox(width: 5),
        Expanded(
          child: _PencereSegmenti(
            gun: g,
            etiket: g == 0 ? 'Tümü'.c : '{} gün'.cf([g]),
            sesli: g == 0 ? 'Tümü'.c : 'Son {} gün'.cf([g]),
            secili: secili == g,
            onSec: () => onSec(g),
          ),
        ),
      ],
    ],
  );
}

/// Seçicinin tek segmenti.
///
/// DOKUNMA HEDEFİ 44 dp KALIYOR ama GÖRSEL yükseklik 34 dp: aradaki 10 dp
/// saydam dolgu. Böylece satır hafif görünürken parmak hedefi küçülmüyor.
///
/// SEÇİLİ DURUM RENKTEN BAŞKA İŞARET TAŞIR (erişilebilirlik): 2 px çerçeve
/// (seçilmemişte 1 px) + w800 yazı (seçilmemişte w500). Gri tonlamalı bir
/// ekranda ya da renk körlüğünde de hangisinin açık olduğu okunur.
class _PencereSegmenti extends StatelessWidget {
  final int gun;

  /// Gözle okunan KISA etiket ("30 gün").
  final String etiket;

  /// Ekran okuyucunun duyduğu TAM etiket ("Son 30 gün").
  final String sesli;
  final bool secili;
  final VoidCallback onSec;

  const _PencereSegmenti({
    required this.gun,
    required this.etiket,
    required this.sesli,
    required this.secili,
    required this.onSec,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: secili,
    label: sesli,
    excludeSemantics: true,
    child: InkWell(
      // Anahtar ÇEVİRİYE DEĞİL sayıya bağlı: dil değişince test/otomasyon
      // hedefi kaymasın ('pencere-0' = tümü).
      key: Key('pencere-$gun'),
      onTap: onSec,
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 44,
        child: Center(
          child: Container(
            height: 34,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: secili ? DiziRenkler.sari.withValues(alpha: 0.16) : null,
              border: Border.all(
                color: secili ? DiziRenkler.sari : DiziRenkler.metin12,
                width: secili ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(17),
            ),
            // FittedBox: en uzun çevirilerde (it "120 giorni", el
            // "120 μέρες") yazı taşmak yerine bir tık küçülür — segment
            // genişliği sabit kaldığı için satır ASLA ikiye çıkmaz.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                etiket,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: secili ? FontWeight.w800 : FontWeight.w500,
                  color: secili ? DiziRenkler.sariMetin : DiziRenkler.metin54,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Üst listelerin satırı: poster + içerik adı + gönderi metni + ölçü.
class _GonderiSatiri extends StatelessWidget {
  final Map<String, dynamic> gonderi;
  final Map<String, dynamic>? icerik;

  /// true → görüntülenme ölçüsü, false → beğeni ölçüsü gösterilir.
  final bool gorunum;

  const _GonderiSatiri({
    required this.gonderi,
    required this.icerik,
    required this.gorunum,
  });

  @override
  Widget build(BuildContext context) {
    final poster = posterUrl(icerik?['poster'] as String?, boyut: 'w185');
    final spoiler = gonderi['spoiler'] == true;
    final metin = spoiler
        ? 'Spoiler içeren gönderi'.c
        : ((gonderi['metin'] as String?) ?? '').trim();
    final medya = gonderi['medya_sayi'] as int? ?? 0;
    final sayi =
        (gorunum ? gonderi['pencere_goruntulenme'] : gonderi['pencere_begeni'])
            as int? ??
        0;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        // Gönderinin kendisine gider: "hangisi tuttu" sorusunun devamı
        // "neden tuttu"dur ve o cevap gönderinin sayfasındadır.
        // `yanit` bayrağı ŞART (md. 15): bir YANIT `/gonderi/:id` ile tam ekran
        // Reels olarak çizilirse medyası olmadığı için dev puntolu tek yazıya
        // dönüyor. `ust_id` doluysa uygun ekran açılır.
        onTap: () => context.push(
          gonderiYolu('${gonderi['id']}', yanit: gonderi['ust_id'] != null),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (poster != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 34,
                    height: 50,
                    child: CachedNetworkImage(
                      imageUrl: poster,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: DiziRenkler.kart),
                      errorWidget: (_, _, _) =>
                          Container(color: DiziRenkler.kart),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${icerik?['ad'] ?? '?'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: DiziRenkler.sariMetin,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      metin.isEmpty && medya > 0 ? 'Görsel gönderi'.c : metin,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: spoiler
                            ? DiziRenkler.metin38
                            : DiziRenkler.metin54,
                        fontSize: 12.5,
                        height: 1.35,
                        fontStyle: spoiler ? FontStyle.italic : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Ölçü sağda: göz gezdirirken sayılar tek sütunda alt alta gelir.
              Semantics(
                label:
                    '${gorunum ? 'Görüntülenme'.c : 'Beğeni'.c}: '
                    '${sayiBicimle(sayi)}',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      sayiBicimle(sayi),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: DiziRenkler.metin,
                      ),
                    ),
                    Icon(
                      gorunum ? Icons.visibility_outlined : Icons.favorite,
                      size: 13,
                      color: DiziRenkler.metin38,
                    ),
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

/// İlk yükleme iskeleti — boş ekran yerine yerleşimin şekli görünür (CLS yok).
class _Iskelet extends StatelessWidget {
  const _Iskelet();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
    children: const [
      // `genislik` verilmezse IskeletKutu 105 px kalır — listede tek sütun
      // yerine ince bir şerit görünürdü.
      IskeletKutu(genislik: double.infinity, yukseklik: 84),
      SizedBox(height: 20),
      IskeletKutu(genislik: double.infinity, yukseklik: 44),
      SizedBox(height: 10),
      IskeletKutu(genislik: double.infinity, yukseklik: 96),
      SizedBox(height: 20),
      IskeletKutu(genislik: double.infinity, yukseklik: 70),
      SizedBox(height: 8),
      IskeletKutu(genislik: double.infinity, yukseklik: 70),
    ],
  );
}
