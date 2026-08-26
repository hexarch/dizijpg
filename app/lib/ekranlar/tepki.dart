import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../api.dart';
import '../ceviri.dart';
import '../puan.dart';
import 'puan_sec_sheet.dart';
import '../tema.dart';
import 'giris_istem.dart';

/// Sunucudaki CHECK ile aynı sırada: bayılmış, gülmüş, şaşırmış, üzgün,
/// korkmuş, sıkılmış, ağlamış, mutlu — dizi/film/kişi tepkileri.
const tepkiEmojileri = ['😍', '😂', '😮', '😢', '😱', '🥱', '😭', '😄'];

/// Emoji karakteri → Noto Animated Emoji dosya adı (Unicode kod noktası).
///
/// VERİTABANI YİNE EMOJİ KARAKTERİ SAKLAR (sunucudaki CHECK listesi aynı) —
/// bu harita yalnız GÖRÜNÜM katmanıdır. Kod noktası tabloya girseydi görsel
/// setini değiştirmek şema değişikliği gerektirirdi.
const _tepkiDosyalari = {
  '😄': '1f604',
  '😢': '1f622',
  '😮': '1f62e',
  '🥱': '1f971',
  '😭': '1f62d',
  '😂': '1f602',
  '😱': '1f631',
  '😍': '1f60d',
  // Yalnız MESAJ tepkilerinde (md. 43): çift tıklama kısayolu.
  '❤️': '2764_fe0f',
};

/// Mesaj (DM) tepkileri: içerik seti + başa KALP.
///
/// Kalp içerik tepkilerine EKLENMEDİ — orada 8'lik küme sunucudaki CHECK ile
/// birebir; mesajlarınki ayrı tablo, ayrı CHECK (9). Çift tıklama kalbi
/// seçer (Instagram/WhatsApp alışkanlığı), basılı tutmak tümünü açar.
const mesajTepkiEmojileri = ['❤️', ...tepkiEmojileri];

/// Tepki emojisini HAREKETLİ çizer (Noto Animated Emoji, CC BY 4.0 — Lottie).
///
/// Kullanıcı isteği (12 Ağu): "emoji kütüphanesi olarak hareketli emojileri
/// kullan... puan gibi emoji verilen her yerde".
///
/// NEDEN LOTTIE, NEDEN WEBP DEĞİL: aynı setin animasyonlu WebP'si emoji başına
/// 443 KB (8 emoji = 3,5 MB); Lottie 19-120 KB ve VEKTÖR — 20 dp çipte de tam
/// ekranda da keskin. Ayrıca oynatma DENETLENEBİLİR; WebP mount edilir edilmez
/// sonsuz döner, 8 tanesi listede sürekli boyanırdı.
///
/// OYNATMA KURALI (performans + rahatsız etmeme):
///  * Varsayılan DURAĞAN (ilk kare) — 8 emoji aynı anda dönmez.
///  * SEÇİLİ olan döner: kendi tepkin canlı durur.
///  * Dokununca bir kez oynar (seçme anının ödülü).
///  * Hareket azaltma açıksa HİÇ oynamaz (yalnız ilk kare).
/// Dosya bulunamazsa sistem emoji fontuna düşer — tepki satırı kaybolmaz.
class TepkiIkonu extends StatefulWidget {
  final String emoji;
  final double boyut;

  /// Sürekli oynasın mı (kullanıcının SEÇİLİ tepkisi).
  final bool oynat;

  /// İlk çizimde BİR KEZ oynasın mı (emoji seçici gibi kısa ömürlü yüzeyler).
  ///
  /// NEDEN [oynat] DEĞİL: 9 emojiyi sonsuz döndürmek hem düşük donanımda boş
  /// CPU hem de ekranın HİÇ DURULMAMASI demek (`pumpAndSettle` sonsuza
  /// bekliyordu — testte yakalandı; gerçek karşılığı pil).
  final bool acilistaOynat;

  /// Bir kez oynatmak için artırılan sayaç: değeri her değiştiğinde animasyon
  /// baştan çalar. (Fonksiyon geri çağırmak yerine sayaç: widget yeniden
  /// kurulmadan da tetiklenebilsin.)
  final int vurus;

  const TepkiIkonu(
    this.emoji, {
    super.key,
    this.boyut = 20,
    this.oynat = false,
    this.acilistaOynat = false,
    this.vurus = 0,
  });

  @override
  State<TepkiIkonu> createState() => _TepkiIkonuState();
}

class _TepkiIkonuState extends State<TepkiIkonu>
    with SingleTickerProviderStateMixin {
  /// `late final ... = AnimationController(...)` KULLANMA: sistem fontuna
  /// düşen (animasyonsuz) durumda build denetleyiciye hiç dokunmaz, ilk erişim
  /// `dispose()` olur ve denetleyici ÖLMEKTE OLAN elemanda kurulmaya çalışır —
  /// ticker TickerMode'u arar, "deactivated widget's ancestor" patlar
  /// (test/hareketli_tepki_test.dart bunu yakaladı).
  late final AnimationController _denetci;
  bool _yuklenemedi = false;

  @override
  void initState() {
    super.initState();
    _denetci = AnimationController(vsync: this);
  }

  /// "Hareketi azalt" tercihi ÖNBELLEKLENİR, geri çağrılardan okunmaz:
  /// `onLoaded` animasyon yüklendiğinde (widget çoktan ağaçtan düşmüş
  /// olabilir) çalışıyor ve orada MediaQuery aramak "deactivated widget's
  /// ancestor" hatası veriyor — testte yakalandı.
  bool _hareketKapali = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final yeni = MediaQuery.disableAnimationsOf(context);
    if (yeni != _hareketKapali) {
      _hareketKapali = yeni;
      _akisiAyarla();
    }
  }

  @override
  void didUpdateWidget(TepkiIkonu eski) {
    super.didUpdateWidget(eski);
    if (widget.vurus != eski.vurus) _tekSeferOynat();
    if (widget.oynat != eski.oynat) _akisiAyarla();
  }

  /// `acilistaOynat` yalnız BİR KEZ çalışsın (didChangeDependencies her tema/
  /// ölçü değişiminde de tetiklenir).
  bool _acilisOynadi = false;

  void _akisiAyarla() {
    if (!mounted) return;
    if (widget.oynat && !_hareketKapali) {
      _denetci.repeat();
      return;
    }
    _denetci
      ..stop()
      ..value = 0; // durağan hâl = ilk kare
    if (widget.acilistaOynat && !_acilisOynadi && !_hareketKapali) {
      _acilisOynadi = true;
      _denetci.forward();
    }
  }

  void _tekSeferOynat() {
    if (!mounted || _hareketKapali) return;
    _denetci
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _denetci.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dosya = _tepkiDosyalari[widget.emoji];
    if (dosya == null || _yuklenemedi) {
      // Bilinmeyen emoji (sunucu listesi genişlemiş olabilir) ya da bozuk
      // varlık: sessizce sistem fontuna düş.
      return Text(
        widget.emoji,
        style: TextStyle(fontSize: widget.boyut, height: 1.1),
      );
    }
    return SizedBox(
      width: widget.boyut * 1.25,
      height: widget.boyut * 1.25,
      child: Lottie.asset(
        'assets/tepkiler/$dosya.json',
        controller: _denetci,
        fit: BoxFit.contain,
        // Ekran okuyucuya "😍" diye okutmak anlamsız; etiketi satır veriyor.
        addRepaintBoundary: true,
        onLoaded: (kompozisyon) {
          if (!mounted) return;
          _denetci.duration = kompozisyon.duration;
          _akisiAyarla();
        },
        errorBuilder: (_, _, _) {
          // build sırasında setState yasak — kareden sonra düş.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _yuklenemedi = true);
          });
          return Text(
            widget.emoji,
            style: TextStyle(fontSize: widget.boyut, height: 1.1),
          );
        },
      ),
    );
  }
}

/// 8 ikonlu tepki satırı: dizi/film geneli (sezon=null) veya tek bölüm.
class TepkiSatiri extends StatefulWidget {
  final String tur;
  final int tmdbId;
  final int? sezon;
  final int? bolum;

  const TepkiSatiri({
    super.key,
    required this.tur,
    required this.tmdbId,
    this.sezon,
    this.bolum,
  });

  @override
  State<TepkiSatiri> createState() => _TepkiSatiriState();
}

class _TepkiSatiriState extends State<TepkiSatiri> {
  Map<String, int> _sayilar = {};
  String? _benim;
  bool _isleniyor = false;

  /// Emoji başına "bir kez oynat" sayacı: dokunulan emoji animasyonunu baştan
  /// çalsın diye artırılır (seçmek de, seçimi kaldırmak da oynatır — dokunuşun
  /// karşılığı her iki yönde de görünür olsun).
  final Map<String, int> _vuruslar = {};

  String get _sorgu => widget.sezon != null
      ? '?sezon=${widget.sezon}&bolum=${widget.bolum}'
      : '';

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final d = await Api.get(
        '/tepkiler/${widget.tur}/${widget.tmdbId}$_sorgu',
      );
      if (!mounted) return;
      _uygula(d as Map<String, dynamic>);
    } catch (_) {}
  }

  void _uygula(Map<String, dynamic> d) {
    setState(() {
      _sayilar = ((d['sayilar'] as Map<String, dynamic>? ?? {})).map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      );
      _benim = d['benim'] as String?;
    });
  }

  Future<void> _sec(String emoji) async {
    // `/tepki` girisZorunlu: oturumsuzda iyimser güncelleme yapıp 401 ile geri
    // almak yerine hiç başlamayız; kullanıcı doğrudan giriş istemini görür.
    if (!girisGerekli(context)) return;
    if (_isleniyor) return;
    setState(() {
      _isleniyor = true;
      _vuruslar[emoji] = (_vuruslar[emoji] ?? 0) + 1;
    });
    final yeni = _benim == emoji ? null : emoji;
    // İyimser güncelleme
    setState(() {
      if (_benim != null) {
        _sayilar[_benim!] = (_sayilar[_benim!] ?? 1) - 1;
      }
      if (yeni != null) _sayilar[yeni] = (_sayilar[yeni] ?? 0) + 1;
      _benim = yeni;
    });
    try {
      final d = await Api.post('/tepki', {
        'tmdb_id': widget.tmdbId,
        'tur': widget.tur,
        if (widget.sezon != null) 'sezon': widget.sezon,
        if (widget.sezon != null) 'bolum': widget.bolum,
        'emoji': yeni,
      });
      if (!mounted) return;
      _uygula(d as Map<String, dynamic>);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
      _yukle();
    } finally {
      if (mounted) setState(() => _isleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final e in tepkiEmojileri)
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _sec(e),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                // Seçili: sarı-tint dolgu + sarı kenar (renkli emoji kaybolmasın)
                color: _benim == e
                    ? DiziRenkler.sari.withValues(alpha: 0.20)
                    : DiziRenkler.kart,
                borderRadius: BorderRadius.circular(20),
                border: _benim == e
                    ? Border.all(color: DiziRenkler.sari, width: 1.5)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TepkiIkonu(
                    e,
                    boyut: 20,
                    // Satır AÇILINCA hepsi BİR KEZ oynar (kullanıcı bildirimi
                    // 14 Ağu: "diziye emoji bırakınca animasyon oynamıyor" —
                    // eskiden yalnız seçili olan dönüyordu, hiç tepki
                    // vermemiş kullanıcı hiçbir hareket görmüyordu).
                    // Kendi tepkin SÜREKLİ döner; ötekiler bir kez oynayıp
                    // dinlenir (8 emoji sonsuz dönseydi gürültü + boş CPU).
                    acilistaOynat: true,
                    oynat: _benim == e,
                    vurus: _vuruslar[e] ?? 0,
                  ),
                  if ((_sayilar[e] ?? 0) > 0) ...[
                    const SizedBox(width: 5),
                    Text(
                      '${_sayilar[e]}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _benim == e
                            ? DiziRenkler.sariMetin
                            : DiziRenkler.metin70,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Doğrudan tıklanan puan satırı (sheet açmadan kaydeder).
///
/// ÖLÇEK: sunucuda puan kanonik 1-100 tutulur, kullanıcı KENDİ SEÇTİĞİ
/// ölçeği (5-100) görür. Dönüşüm BURADA YAPILMAZ — `lib/puan.dart`taki
/// `yildiza()`/`dbPuani()` TEK KAYNAKTIR (7 Ağu 2026 SEO denetimi: altı
/// dosyada kopyalanan `/2` hesabı sunucu çıktısıyla uygulamayı ayrıştırmıştı).
///
/// İKİ KİP (26 Ağu 2026, kullanıcı isteği):
///   * ölçek ≤ 10 → yıldızlar SATIR hâlinde, tek dokunuşla puan.
///   * ölçek > 10 → tek ROZET ("73/100"); dokununca [puanSecSheet] açılır.
/// Eşiğin gerekçesi `yildizSatiriOlur()` içinde yazılı. Kip değişimi ölçeğe
/// bağlı olduğu için widget `PuanOlcegi.deger`i DİNLER: kullanıcı Ayarlar'dan
/// ölçeği değiştirince açık ekranlar kendini yeniden çizer.
///
/// HEDEF (8 Ağu 2026-d): `sezon`+`bolum` verilirse puan O BÖLÜME, verilmezse
/// dizi/film/kişi GENELİNE yazılır — `TepkiSatiri` ve yorumlarla aynı
/// sözleşme. İkisi sunucuda AYRI satırdır, birbirine karışmaz.
class YildizPuan extends StatefulWidget {
  final String tur;
  final int tmdbId;
  final int? sezon;
  final int? bolum;
  final int? baslangicPuan; // sunucu (kanonik) ölçeği 1-100
  final double boyut;

  /// Kaydetme BAŞARILI olduğunda çağrılır: (yıldız 0..N, sunucu yanıtı).
  /// 0 = puan silindi. Üst blok ortalamayı tazelemek ve sunucunun bildirdiği
  /// yan etkiyi (bölüm "izlendi" işaretlendi) göstermek için kullanır.
  final void Function(int yildiz, Map<String, dynamic> yanit)? kaydedildi;

  const YildizPuan({
    super.key,
    required this.tur,
    required this.tmdbId,
    this.sezon,
    this.bolum,
    this.baslangicPuan,
    this.boyut = 30,
    this.kaydedildi,
  });

  @override
  State<YildizPuan> createState() => _YildizPuanState();
}

class _YildizPuanState extends State<YildizPuan> {
  late int _yildiz = yildiza(widget.baslangicPuan);
  bool _isleniyor = false;

  @override
  void didUpdateWidget(YildizPuan eski) {
    super.didUpdateWidget(eski);
    if (eski.baslangicPuan != widget.baslangicPuan && !_isleniyor) {
      _yildiz = yildiza(widget.baslangicPuan);
    }
  }

  Future<void> _sec(int yildiz) async {
    // `/puan` girisZorunlu: oturumsuzda iyimser güncelleme yapıp 401 ile geri
    // almak yerine hiç başlamayız — kullanıcı doğrudan giriş istemini görür
    // (`TepkiSatiri._sec` ile aynı kural; burada 8 Ağu 2026'ya kadar eksikti).
    if (!girisGerekli(context)) return;
    if (_isleniyor) return;
    // Aynı yıldıza basınca sil — YALNIZ SATIR KİPİNDE geçerli kısayol.
    await _yaz(yildiz == _yildiz ? 0 : yildiz);
  }

  /// Puanı yaz (0 = sil). İyimser güncelleme; hata olursa ESKİ DEĞERE DÖNER.
  Future<void> _yaz(int yeni) async {
    final eski = _yildiz;
    setState(() {
      _yildiz = yeni;
      _isleniyor = true;
    });
    try {
      final d = await Api.post('/puan', {
        'tmdb_id': widget.tmdbId,
        'tur': widget.tur,
        // Bölüm hedefi ikisi birden gider ya da hiç gitmez (sunucu sözleşmesi).
        if (widget.sezon != null) 'sezon': widget.sezon,
        if (widget.sezon != null) 'bolum': widget.bolum,
        'puan': yeni == 0 ? null : dbPuani(yeni),
        // Sunucuya "bu puan KANONİK 1-100 ölçeğinde" de. Bayrak yoksa sunucu
        // gönderileni 1-10 sayıp ×10 uygular (eski sürüm koruması).
        'kanonik': true,
      });
      if (!mounted) return;
      widget.kaydedildi?.call(
        yeni,
        d is Map<String, dynamic> ? d : const <String, dynamic>{},
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _yildiz = eski);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isleniyor = false);
    }
  }

  /// Geniş ölçek kipi: rozete dokununca kaydırıcılı sayfa açılır.
  Future<void> _sheetAc(int olcek) async {
    if (!girisGerekli(context)) return;
    if (_isleniyor) return;
    final secim = await puanSecSheet(context, olcek: olcek, mevcut: _yildiz);
    // null = vazgeçti. 0 = sil. Diğerleri puan. `_sec` "aynı değere basınca
    // sil" mantığı taşıdığı için BURADA kullanılamaz: kullanıcı sayfada
    // mevcut puanını onaylamak isteyebilir, bu silme olmamalı.
    if (secim == null || !mounted) return;
    await _yaz(secim);
  }

  @override
  Widget build(BuildContext context) {
    // Ölçek değişince (Ayarlar) açık ekranlar kendiliğinden yeniden çizilir.
    return ValueListenableBuilder<int>(
      valueListenable: PuanOlcegi.deger,
      builder: (context, olcek, _) {
        if (!yildizSatiriOlur(olcek)) return _rozet(olcek);
        final boy = yildizIkonBoyu(olcek, taban: widget.boyut);
        // DOKUNMA HEDEFİ — ÖLÇÜLMÜŞ TAVİZ (26 Ağu 2026):
        // 10 yıldız × 44 dp = 440 dp, 360 dp'lik telefona SIĞMAZ. Yani
        // "10'a kadar satır" (kullanıcı kuralı) ile "her hedef 44 dp"
        // aynı anda sağlanamıyor. Seçim: DİKEYDE 44 dp GARANTİ, yatayda
        // eldeki genişliği yıldızlara EŞİT böl — IMDb/Letterboxd'un 10'luk
        // ölçeklerinde yaptığı gibi. Bitişik ölçek elemanlarında yatay
        // daralma kabul edilebilir; hedefin TAMAMEN kaybolması değil.
        // Ölçek 5'te (varsayılan) hiçbir taviz yok: 44x44 korunur.
        return LayoutBuilder(
          builder: (context, kisit) {
            // Sonsuz genişlikte (Row içinde ölçüsüz) eldeki tek bilgi ikon
            // boyu; o durumda eski sabit payı kullan.
            final kullanilabilir = kisit.maxWidth.isFinite
                ? kisit.maxWidth
                : olcek * (boy + 14);
            final hucre = (kullanilabilir / olcek).clamp(boy + 4, 44.0);
            final yatay = ((hucre - boy) / 2).clamp(2.0, 7.0);
            return _satir(olcek, boy, yatay);
          },
        );
      },
    );
  }

  Widget _satir(int olcek, double boy, double yatay) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var y = 1; y <= olcek; y++)
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _sec(y),
            // DOKUNMA HEDEFİ: ikon + 2x yatay pay = 44 dp; dikeyde
            // + 2x8. Eski 2x4 pay 38 dp veriyordu, yani asgari
            // 44x44'ün ALTINDA (ui-ux-pro-max "Touch Target Size", High).
            // Yıldızlar arasında BİLEREK boşluk yok: puan şeridi tek bir
            // ölçektir, komşu hedefler arası 8 dp kuralı ayrı EYLEMLERİ
            // olan butonlar içindir; boşluk ölçeği kesikli gösterirdi.
            child: Padding(
              // Dikey pay: ikon ne kadar küçülürse küçülsün hedef en az
              // 44 dp yüksekliğinde kalır (yukarıdaki taviz notu).
              padding: EdgeInsets.symmetric(
                horizontal: yatay,
                vertical: ((44 - boy) / 2).clamp(8.0, 20.0),
              ),
              child: Icon(
                y <= _yildiz ? Icons.star_rounded : Icons.star_outline_rounded,
                size: boy,
                color: y <= _yildiz ? DiziRenkler.sari : DiziRenkler.metin38,
              ),
            ),
          ),
      ],
    );
  }

  /// Geniş ölçekte satır yerine çizilen rozet. Puansızken de dokunulabilir
  /// olmalı — yoksa geniş ölçekteki kullanıcı puan VEREMEZ.
  Widget _rozet(int olcek) {
    final puanli = _yildiz > 0;
    return InkWell(
      onTap: () => _sheetAc(olcek),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              puanli ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 22,
              color: puanli ? DiziRenkler.sari : DiziRenkler.metin38,
            ),
            const SizedBox(width: 6),
            Text(
              puanli ? '$_yildiz/$olcek' : 'Puanla'.c,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: puanli ? DiziRenkler.metin : DiziRenkler.metin54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bölüm puanı bloğu: etiket + 5 yıldız + topluluk ortalaması.
///
/// NEDEN AYRI WIDGET: bölüm sayfası (`bolum.dart`) ve takvimin bölüm modalı
/// (`takvim.dart/BolumModali`) AYNI şeyi göstermeli. İki yerde iki kopya
/// olsaydı biri sezon/bolum göndermeyi unutup puanı sessizce DİZİ GENELİNE
/// yazardı — takvim modalında 8 Ağu 2026'ya kadar tam olarak bu oluyordu
/// (modaldaki yıldızlar bölüme değil dizinin tamamına puan veriyordu).
class BolumPuani extends StatefulWidget {
  final int tmdbId;
  final int sezon;
  final int bolum;

  /// Sunucu "bölümü izledim olarak işaretledim" dediğinde çağrılır.
  /// Yan etki SESSİZ kalmamalı: üst ekran "İzledin" butonunu günceller.
  final VoidCallback? izlendiIsaretlendi;

  const BolumPuani({
    super.key,
    required this.tmdbId,
    required this.sezon,
    required this.bolum,
    this.izlendiIsaretlendi,
  });

  @override
  State<BolumPuani> createState() => _BolumPuaniState();
}

class _BolumPuaniState extends State<BolumPuani> {
  int? _benim; // sunucu ölçeği (1-10)
  num? _ortalama; // sunucu ölçeği (1-10)
  int _adet = 0;
  bool _yuklendi = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final d = await Api.get(
        '/bolum-puanlari/${widget.tmdbId}/${widget.sezon}',
      );
      if (!mounted) return;
      final b = (d is Map ? d['bolumler'] : null) as Map<String, dynamic>?;
      final bu = b?['${widget.bolum}'] as Map<String, dynamic>?;
      setState(() {
        _benim = (bu?['benim'] as num?)?.toInt();
        _ortalama = puanSayisi(bu?['ortalama']);
        _adet = (bu?['adet'] as num?)?.toInt() ?? 0;
        _yuklendi = true;
      });
    } catch (_) {
      // Ortalama süs veridir; gelmezse yıldızlar yine de çalışsın.
      if (mounted) setState(() => _yuklendi = true);
    }
  }

  void _kaydedildi(int yildiz, Map<String, dynamic> yanit) {
    setState(() => _benim = yildiz == 0 ? null : dbPuani(yildiz));
    if (yanit['izlendi'] == true) widget.izlendiIsaretlendi?.call();
    _yukle(); // ortalama + sayaç tazelensin
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          _benim == null ? 'Bu bölüme puan ver'.c : 'Puanın'.c,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: DiziRenkler.metin70,
          ),
        ),
        // YÜKSEKLİK REZERVASYONU: yıldızlar veri gelmeden de çizilir, yalnız
        // başlangıç puanı sonradan dolar. Blok hiç yer değiştirmez (CLS yok).
        YildizPuan(
          tur: 'tv',
          tmdbId: widget.tmdbId,
          sezon: widget.sezon,
          bolum: widget.bolum,
          baslangicPuan: _benim,
          kaydedildi: _kaydedildi,
        ),
        // Sabit yükseklik: ortalama satırı sonradan gelince blok zıplamasın.
        SizedBox(
          height: 22,
          child: _yuklendi && _adet > 0
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: DiziRenkler.sari,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        // Dizi kartındaki rozetle AYNI biçim ve AYNI ölçek
                        // dönüşümü (puan.dart) — 10'luk değer BASILMAZ.
                        '{} dizi.jpg'.cf([yildizOrtalamaMetni(_ortalama)]),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '{} kişi puanladı'.cf([_adet]),
                      style: TextStyle(
                        fontSize: 12,
                        color: DiziRenkler.metin54,
                      ),
                    ),
                  ],
                )
              : null,
        ),
      ],
    );
  }
}
