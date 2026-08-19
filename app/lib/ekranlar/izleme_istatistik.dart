import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
// `sayiBicimle` gönderi istatistikleri ekranından geliyor: binlik ayracı
// YEREL ("1.234.567" / "1,234,567") — elde `replaceAllMapped` ile nokta
// koymak Almanca'da doğru, İngilizce'de yanlış olurdu.
import 'istatistiklerim.dart' show sayiBicimle;
import 'ortak.dart';

/// İZLEME İSTATİSTİKLERİM — Ayarlar > İzleme İstatistiklerim (19 Ağu 2026).
///
/// İSTEK: "kullanıcı profilindeki ayarlardan izleme istatistikleri tarafını
/// daha iyi bir hale getir, biraz instagram ve tiktoktan örnek al, onlarda
/// olan her şey bizde de olsun istatistik konusunda."
///
/// ===========================================================================
/// INSTAGRAM/TIKTOK'TAN NE ALINDI — VE NE ALINMADI
/// ===========================================================================
/// O ekranların istatistikte iyi yaptığı şey metrik ÇEŞİTLİLİĞİ değil,
/// SUNUMUDUR. Alınanlar:
///   * TEK kahraman sayı (ekran süresi) + önceki döneme göre YÖN,
///   * pencere seçici EN ÜSTTE (yönettiği her şeyin üstünde),
///   * günlük çubuk/eğri — kümülatif değil, düşebilen bir seri,
///   * "seri/streak" — art arda izlenen gün,
///   * "en çok" listesi,
///   * haftanın hangi günü izliyorsun dağılımı.
/// ALINMAYAN: erişim/etkileşim oranı gibi YAYINCI metrikleri. Burada ölçülen
/// şey kullanıcının KENDİ izlemesi, bir kitleye ulaşma değil; o metrikler
/// gönderi tarafında (`İstatistiklerim`) zaten var ve ikisini karıştırmak
/// "kaç kişi gördü" ile "kaç bölüm izledim"i aynı ekranda eşitlerdi.
///
/// ===========================================================================
/// TAHMİN YOK — EKRAN SÜRESİ "YAKLAŞIK" DİYE ETİKETLENİR
/// ===========================================================================
/// `dakika` ölçülmüş değil TÜRETİLMİŞ bir sayıdır (bölüm 42 dk, film 110 dk).
/// Gerçek süreyi bilmiyoruz. `İstatistiklerim` ekranının "eksik veriyi
/// saklamamak" kuralı burada da geçerli: sayı gösterilir ama yanında
/// "yaklaşık" yazar. Şişirme, oranlama, tahmin YASAK.
///
/// YÖN OKU: önceki pencere BOŞSA çizilmez (sunucu `degisim: null` döner).
/// 0'dan artışı "%100 arttı" diye sunmak, ilk kez izleyen herkese sahte bir
/// başarı grafiği çizmek olurdu.
class IzlemeIstatistikEkrani extends StatefulWidget {
  const IzlemeIstatistikEkrani({super.key});

  @override
  State<IzlemeIstatistikEkrani> createState() => _IzlemeIstatistikEkraniState();
}

class _IzlemeIstatistikEkraniState extends State<IzlemeIstatistikEkrani> {
  Map<String, dynamic>? _veri;
  String? _hata;
  bool _yukleniyor = false;
  int _gun = 30;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final d = await Api.get('/istatistiklerim/izleme?gun=$_gun');
      if (!mounted) return;
      setState(() {
        _veri = d;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        // Veri VARSA hata ekranı basma: pencere değiştirirken ağ koparsa
        // ekranı boşaltmak, elde duran doğru sayıları da silmek olurdu.
        if (_veri == null) _hata = e.toString();
      });
    }
  }

  void _pencereSec(int g) {
    if (g == _gun) return;
    setState(() => _gun = g);
    _yukle();
  }

  /// Dakikayı okunur süreye çevirir: "1.240 sa 30 dk".
  String _sure(num? dk) {
    final t = (dk ?? 0).toInt();
    final saat = t ~/ 60;
    final kalan = t % 60;
    // `.cs` = çoğul bilinçli biçim ("1 min" / "2 mins"); ayrıntı: [Ceviri.cogul].
    if (saat == 0) return '{} dk'.cs(kalan);
    return '{} sa {} dk'.cf([sayiBicimle(saat), kalan]);
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_hata != null && _veri == null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_veri == null) {
      govde = const Padding(
        padding: EdgeInsets.all(12),
        child: IskeletKutu(genislik: double.infinity, yukseklik: 220),
      );
    } else if (((_veri!['omur'] as Map?)?['bolum'] as num? ?? 0) == 0 &&
        ((_veri!['omur'] as Map?)?['film'] as num? ?? 0) == 0) {
      govde = BosDurum(
        ikon: Icons.play_circle_outline,
        baslik: 'Henüz izleme kaydın yok'.c,
        ipucu:
            'Bir bölümü ya da filmi izlendi olarak işaretlediğinde '
                    'istatistiklerin burada birikmeye başlar.'
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
          children: _icerik(),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('İzleme İstatistiklerim'.c),
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
      body: OrtaKolon(azami: masaustuIcerikGenisligi, cocuk: govde),
    );
  }

  List<Widget> _icerik() {
    final v = _veri!;
    final p = v['pencere'] as Map<String, dynamic>;
    final d = p['degisim'] as Map<String, dynamic>;
    final omur = v['omur'] as Map<String, dynamic>;
    final zincir = v['zincir'] as Map<String, dynamic>;
    final pencereler = (v['pencereler'] as List<dynamic>).cast<int>();
    return [
      // ORTAK seçici (ortak.dart): 360 dp'de FittedBox ile küçülüp taşmaz,
      // seçili durumu renkten başka iki kanalla da (2 px çerçeve + w800)
      // taşır. Sunucunun döndürdüğü pencere listesi olduğu gibi verilir.
      PencereSecici(secili: _gun, gunler: pencereler, onSec: _pencereSec),
      const SizedBox(height: 16),
      _Kahraman(
        deger: _sure(p['dakika'] as num?),
        etiket: 'Yaklaşık ekran süresi'.c,
        degisim: (d['dakika'] as num?)?.toInt(),
        gun: _gun,
      ),
      const SizedBox(height: 12),
      _GunlukEgri(
        seri: (v['seri'] as List<dynamic>?) ?? const [],
        gunSayisi: _gun,
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: _Sayac(
              ikon: Icons.tv_outlined,
              deger: sayiBicimle((p['bolum'] as num?)?.toInt() ?? 0),
              etiket: 'Bölüm'.c,
              degisim: (d['bolum'] as num?)?.toInt(),
              gun: _gun,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Sayac(
              ikon: Icons.movie_outlined,
              deger: sayiBicimle((p['film'] as num?)?.toInt() ?? 0),
              etiket: 'Film'.c,
              degisim: (d['film'] as num?)?.toInt(),
              gun: _gun,
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      // "Seri" TEK BAŞINA yazılmadı: Türkçede hem "streak" hem "dizi"
      // demek ve çeviri dosyalarında iki anlam birbirine karışırdı.
      _Baslik(
        ikon: Icons.local_fire_department_outlined,
        metin: 'İzleme serisi'.c,
      ),
      Row(
        children: [
          Expanded(
            child: _Sayac(
              ikon: Icons.bolt_outlined,
              deger: '{} gün'.cs((zincir['guncel'] as num?)?.toInt() ?? 0),
              etiket: 'Şu anki seri'.c,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Sayac(
              ikon: Icons.emoji_events_outlined,
              deger: '{} gün'.cs((zincir['en_uzun'] as num?)?.toInt() ?? 0),
              etiket: 'En uzun seri'.c,
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      _Baslik(ikon: Icons.bar_chart, metin: 'Haftanın günleri'.c),
      _GunDagilimi(gunler: (v['gunler'] as List<dynamic>?) ?? const []),
      const SizedBox(height: 20),
      _Baslik(ikon: Icons.leaderboard_outlined, metin: 'En çok izlediklerin'.c),
      _EnCok(liste: (v['en_cok'] as List<dynamic>?) ?? const []),
      const SizedBox(height: 20),
      // ÇIPA: ömür boyu toplam EN ALTTA — manşet değil, bağlam.
      // (İstatistiklerim ekranındaki aynı karar: tekrar eden sayı, ikisinden
      //  birinin başka bir şeyi ölçtüğünü sanmaya yol açıyordu.)
      _Cipa(
        metin: 'Tüm zamanlar: {} bölüm · {} film · ~{}'.cf([
          sayiBicimle((omur['bolum'] as num?)?.toInt() ?? 0),
          sayiBicimle((omur['film'] as num?)?.toInt() ?? 0),
          _sure(omur['dakika'] as num?),
        ]),
      ),
    ];
  }
}

/// Tek büyük sayı + yön. Yön null ise HİÇ çizilmez (sahte yön yok).
class _Kahraman extends StatelessWidget {
  final String deger;
  final String etiket;
  final int? degisim;
  final int gun;

  const _Kahraman({
    required this.deger,
    required this.etiket,
    required this.gun,
    this.degisim,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        deger,
        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 2),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ESNEK: 360 dp'de "Yaklaşık ekran süresi" + 132 px'lik rozet
          // satırı 82 px taşıyordu (test/izleme_istatistik_test.dart). Uzun
          // çevirilerde (el "Κατά προσέγγιση χρόνος οθόνης") fark daha da
          // büyür — sabit genişlikli metin bir zaman meselesiydi.
          Expanded(
            child: Text(
              etiket,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: DiziRenkler.metin54, fontSize: 13),
            ),
          ),
          if (degisim != null) ...[
            const SizedBox(width: 8),
            YonRozeti(yuzde: degisim!, oncekiGun: gun),
          ],
        ],
      ),
    ],
  );
}

class _Sayac extends StatelessWidget {
  final IconData ikon;
  final String deger;
  final String etiket;
  final int? degisim;
  final int? gun;

  const _Sayac({
    required this.ikon,
    required this.deger,
    required this.etiket,
    this.degisim,
    this.gun,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: DiziRenkler.kart,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(ikon, size: 18, color: DiziRenkler.sariMetin),
        const SizedBox(height: 6),
        Text(
          deger,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        Row(
          children: [
            Flexible(
              child: Text(
                etiket,
                style: TextStyle(color: DiziRenkler.metin54, fontSize: 12),
              ),
            ),
            if (degisim != null) ...[
              const SizedBox(width: 6),
              YonRozeti(yuzde: degisim!, oncekiGun: gun ?? 0, kompakt: true),
            ],
          ],
        ),
      ],
    ),
  );
}

class _Baslik extends StatelessWidget {
  final IconData ikon;
  final String metin;

  const _Baslik({required this.ikon, required this.metin});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(ikon, size: 19, color: DiziRenkler.sariMetin),
        const SizedBox(width: 6),
        // Esnek: uzun çevirilerde ("Ulizotazama zaidi", "Legtöbbet nézett")
        // başlık taşmak yerine sarar.
        Expanded(
          child: Text(
            metin,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

/// Haftanın günleri: en yoğun gün 1.0 kabul edilip diğerleri ona oranlanır.
/// Mutlak yükseklik değil ORAN çizilir — amaç "hangi gün daha çok" sorusu.
class _GunDagilimi extends StatelessWidget {
  final List<dynamic> gunler;

  const _GunDagilimi({required this.gunler});

  /// Postgres `dow`: 0=Pazar … 6=Cumartesi.
  static const _adlar = [
    'Paz', 'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', //
  ];

  @override
  Widget build(BuildContext context) {
    final sayilar = List<int>.filled(7, 0);
    for (final g in gunler) {
      final i = (g['gun'] as num?)?.toInt() ?? -1;
      if (i >= 0 && i < 7) sayilar[i] = (g['adet'] as num?)?.toInt() ?? 0;
    }
    final enBuyuk = sayilar.fold<int>(0, (a, b) => b > a ? b : a);
    if (enBuyuk == 0) {
      return Text(
        'Bu dönemde izleme yok'.c,
        style: TextStyle(color: DiziRenkler.metin54, fontSize: 13),
      );
    }
    return SizedBox(
      height: 96,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    sayilar[i] == 0 ? '' : '${sayilar[i]}',
                    style: TextStyle(fontSize: 10, color: DiziRenkler.metin54),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    height: 8 + 52 * (sayilar[i] / enBuyuk),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: sayilar[i] == enBuyuk
                          ? DiziRenkler.sari
                          : DiziRenkler.sari.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _adlar[i].c,
                    style: TextStyle(fontSize: 11, color: DiziRenkler.metin54),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// En çok izlenen ilk 5: poster kartı `MiniIcerik`ten gelir (ad/afiş
/// `IcerikDeposu`ndan çözülür — sunucu yalnız tmdb_id gönderiyor).
class _EnCok extends StatelessWidget {
  final List<dynamic> liste;

  const _EnCok({required this.liste});

  @override
  Widget build(BuildContext context) {
    if (liste.isEmpty) {
      return Text(
        'Bu dönemde izleme yok'.c,
        style: TextStyle(color: DiziRenkler.metin54, fontSize: 13),
      );
    }
    return SizedBox(
      height: 232,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: liste.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final o = liste[i] as Map<String, dynamic>;
          final tur = o['tur'] as String;
          final adet = (o['adet'] as num?)?.toInt() ?? 0;
          return SizedBox(
            width: 105,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MiniIcerik(
                  key: ValueKey('$tur-${o['tmdb_id']}'),
                  tmdbId: (o['tmdb_id'] as num).toInt(),
                  tur: tur,
                ),
                const SizedBox(height: 2),
                Text(
                  // `izlenenSayi` BİLEREK verilmiyor: o rozet, izlenen bölümü
                  // dizinin TOPLAM bölümüne oranlayan bir ilerleme çubuğu
                  // çiziyor. Buradaki sayı ise yalnız SEÇİLİ PENCEREDEKİ
                  // izleme — tekrar izlemelerle toplamı aşabilir ve çubuk
                  // 1.0'a kırpıldığı için "diziyi bitirdin" gibi görünürdü.
                  tur == 'tv' ? '{} bölüm'.cs(adet) : '{} kez'.cs(adet),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: DiziRenkler.sariMetin,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// GÜNLÜK EĞRİ — seçili penceredeki her gün için bir çubuk.
///
/// EKSİK GÜNLER BURADA DOLDURULUR: sunucu yalnız izleme OLAN günleri döner
/// (uydurma satır üretmemek için). İzlenmeyen gün 0 çizilir — aksi hâlde
/// çubuklar sıkışır ve "her gün izlemişim" yanılsaması doğardı.
///
/// Çok gün varsa (365) çubuk başına 1 px bile düşmez; o yüzden pencere
/// haftalık kovalara toplanır ve eksen etiketi buna göre değişir.
class _GunlukEgri extends StatelessWidget {
  final List<dynamic> seri;
  final int gunSayisi;

  const _GunlukEgri({required this.seri, required this.gunSayisi});

  @override
  Widget build(BuildContext context) {
    final bugun = DateTime.now().toUtc();
    final baslangic = DateTime.utc(
      bugun.year,
      bugun.month,
      bugun.day,
    ).subtract(Duration(days: gunSayisi - 1));
    final gunluk = List<int>.filled(gunSayisi, 0);
    for (final r in seri) {
      final ham = r['gun'];
      final t = ham is String ? DateTime.tryParse(ham) : null;
      if (t == null) continue;
      final i = DateTime.utc(
        t.year,
        t.month,
        t.day,
      ).difference(baslangic).inDays;
      if (i >= 0 && i < gunSayisi) {
        gunluk[i] = (r['adet'] as num?)?.toInt() ?? 0;
      }
    }
    // 60 çubuktan fazlası ekrana sığmıyor: haftalık kovaya topla.
    final kova = gunSayisi > 60 ? 7 : 1;
    final cubuklar = <int>[];
    for (var i = 0; i < gunluk.length; i += kova) {
      var t = 0;
      for (var j = i; j < i + kova && j < gunluk.length; j++) {
        t += gunluk[j];
      }
      cubuklar.add(t);
    }
    final enBuyuk = cubuklar.fold<int>(0, (a, b) => b > a ? b : a);
    if (enBuyuk == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 56,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final c in cubuklar)
                Expanded(
                  child: Container(
                    // 2 px taban: 0 olan gün de bir iz bırakır, yoksa boşluk
                    // "veri gelmedi" gibi okunurdu.
                    height: 2 + 54 * (c / enBuyuk),
                    margin: const EdgeInsets.symmetric(horizontal: 0.6),
                    decoration: BoxDecoration(
                      color: c == 0
                          ? DiziRenkler.sari.withValues(alpha: 0.18)
                          : DiziRenkler.sari.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          kova == 1
              ? 'Son {} gün · günlük'.cf([gunSayisi])
              : 'Son {} gün · haftalık'.cf([gunSayisi]),
          style: TextStyle(fontSize: 11, color: DiziRenkler.metin54),
        ),
      ],
    );
  }
}

class _Cipa extends StatelessWidget {
  final String metin;

  const _Cipa({required this.metin});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: DiziRenkler.kart,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      metin,
      style: TextStyle(color: DiziRenkler.metin54, fontSize: 12.5),
    ),
  );
}
