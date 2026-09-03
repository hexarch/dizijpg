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
    // TEK SIRA, ARKA PLAN YOK, SAYI EMOJİNİN ALTINDA (30 Ağu 2026).
    //
    // KULLANICI İSTEĞİ (birebir): *"oyuncu profilindeki emojileri tek sıraya
    // sığdır arka planları da olmasın yani neden temadan farklı renk arka plan
    // atıyorsun"* ve *"bu sadece oyuncu için değil dizi yönetmen firma
    // hepsinde öyle olmalı ve aldığı emoji sayısını altında göster emojinin
    // yanında değil"*. Tek bileşen olduğu için altı çağrı yerinin (dizi/film,
    // bölüm, kişi, şirket, takvim) hepsi aynı anda değişiyor.
    //
    // ÜÇ KARAR VE GEREKÇELERİ
    //
    // 1. `Wrap` DEĞİL `Row` + `Expanded`. Wrap "sığmazsa alt satıra taşır"
    //    demekti; sayı rozeti çıkınca haplar genişleyip gerçekten taşıyordu
    //    (eski yorumda "bu doğru davranış" yazıyordu — kullanıcı aksini
    //    istedi). Expanded sekiz hücreyi eşit böler, TAŞMA MATEMATİKSEL OLARAK
    //    İMKÂNSIZ hale gelir: sayı üç haneye çıksa da satır tek kalır.
    //
    // 2. ARKA PLAN KALKTI. Hap `DiziRenkler.kart` ile boyanıyordu; sayfa
    //    zemininden farklı bu ton, kullanıcının deyimiyle "temadan farklı
    //    renk". Arka plan gidince emoji doğrudan sayfanın üstünde durur.
    //
    // 3. SEÇİLİ HÂLİ ARTIK RENK + HAREKET TAŞIYOR, KUTU DEĞİL. Dolgu ve kenar
    //    gidince "hangisi benim tepkim" işaretini iki şey veriyor: sayı sarı
    //    yazılır ve o emoji SÜREKLİ döner (ötekiler bir kez oynayıp durur).
    //    Seçmek sayacı en az 1 yaptığı için sarı sayı HER ZAMAN görünür —
    //    yani işaretin kaybolduğu bir durum yok.
    //
    // HİZA: sayı satırı sayaç 0 iken de çizilir (boş metin). Çizilmeseydi
    // tepki almış ve almamış emojiler farklı yükseklikte olur, satır zıplardı.
    //
    // 44 dp KURALI KORUNDU (ux md.2): görünen içerik ~30 dp, ama `InkWell`
    // `minHeight: 44` kutusunun tamamını kaplıyor.
    return Row(
      children: [
        for (final e in tepkiEmojileri)
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _sec(e),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TepkiIkonu(
                      e,
                      boyut: 22,
                      // Satır AÇILINCA hepsi BİR KEZ oynar (kullanıcı
                      // bildirimi 14 Ağu: "diziye emoji bırakınca animasyon
                      // oynamıyor" — eskiden yalnız seçili olan dönüyordu, hiç
                      // tepki vermemiş kullanıcı hiçbir hareket görmüyordu).
                      // Kendi tepkin SÜREKLİ döner; ötekiler bir kez oynayıp
                      // dinlenir (8 emoji sonsuz dönseydi gürültü + boş CPU).
                      acilistaOynat: true,
                      oynat: _benim == e,
                      vurus: _vuruslar[e] ?? 0,
                    ),
                    const SizedBox(height: 1),
                    // Sayaç 0 iken BOŞ METİN: satır yüksekliği yine ayrılır,
                    // emojiler aynı hizada durur.
                    Text(
                      (_sayilar[e] ?? 0) > 0 ? '${_sayilar[e]}' : '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _benim == e
                            ? DiziRenkler.sariMetin
                            : DiziRenkler.metin70,
                      ),
                    ),
                  ],
                ),
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
/// SÜRÜKLEMELİ (3 Eyl 2026, kullanıcı isteği): satır kipinde parmağı
/// yıldızların üzerinde gezdirmek puanı CANLI değiştirir, bırakınca kaydeder.
/// Dokunma da çalışmaya devam eder — sürükleme onun YERİNE değil YANINA
/// eklendi. Neden gerekli: 10'luk ölçekte hücre 44 dp'nin altına iniyor
/// (aşağıdaki taviz notu); tek tek isabet ettirmek zorlaşınca kullanıcı
/// yanlış yıldıza basıyordu. Sürüklerken dolan yıldızlar geri bildirimi
/// parmağın altında verir, isabet gereksinimi ortadan kalkar.
/// KAYIT YALNIZ BIRAKINCA: her `onUpdate`te POST atmak 10 yıldızlık bir
/// sürüklemede 10 istek + 10 yanlış "kaydedildi" demekti.
///
/// DAR KUTU: satır, verilen genişliğe SIĞAR (Expanded/dar sütun). Hücre
/// yıldızı 18 dp'nin altına itiyorsa satır çizilmez, rozet kipine düşülür —
/// 14 dp'lik bir yıldız şeridi ne okunur ne dokunulur.
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

  /// Yıldızların ALTINA küçük bir etiket koy: puansızken "Puanla", puanlıyken
  /// "4/5". 3 Eyl 2026, kullanıcı: *"5 yıldız koy, altına puanla yaz ufak bir
  /// şekilde."*
  ///
  /// NEDEN VARSAYILAN KAPALI: bölüm satırında (`BolumPuani`) yıldızların
  /// solunda zaten "S1B4" etiketi, sağında topluluk ortalaması var; oraya bir
  /// de alt yazı koymak aynı bilgiyi üçüncü kez tekrar ederdi. Etiket YALNIZ
  /// yıldızların tek başına durduğu profil başlıklarında (dizi/film, kişi,
  /// şirket) açılır — orada eskiden "Puanla" yazan bir düğme vardı ve
  /// yıldızlara geçince o sözcük kayboluyordu.
  ///
  /// ROZET KİPİNDE ÇİZİLMEZ: rozetin kendi içinde zaten "Puanla" / "73/100"
  /// yazıyor (bkz. [_rozet]).
  final bool altYazi;

  /// Alt yazının SONUNA eklenen kısa metin: "Puanla · ort. 4.2".
  ///
  /// NEDEN YANDA DEĞİL ALTTA: kişi sayfasında topluluk ortalaması şeridin
  /// SAĞINDAYDI ve 390 dp telefonda ondan 98 dp çalıyordu — geriye 128 dp
  /// kalınca yıldızlar 21,6 dp'ye, dokunma hücresi 25,6 dp'ye iniyordu
  /// (ölçüldü). Ortalama zaten ufak, gri, ikincil bir bilgi; alt yazının
  /// yanına inince şerit sütunun TAMAMINI (234 dp) kullanıyor ve yıldız
  /// 30 dp'ye, hücre 44 dp'ye çıkıyor.
  ///
  /// [altYazi] kapalıyken YOK SAYILIR.
  final String? altYaziEki;

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
    this.altYazi = false,
    this.altYaziEki,
    this.kaydedildi,
  });

  @override
  State<YildizPuan> createState() => _YildizPuanState();
}

class _YildizPuanState extends State<YildizPuan> {
  late int _yildiz = yildiza(widget.baslangicPuan);
  bool _isleniyor = false;

  /// Parmak yıldızların üzerindeyken canlı önizleme; sürükleme bitince null.
  /// `null` DEĞİL de 0 kullanılsaydı "sürüklemiyor" ile "sıfır yıldız" aynı
  /// değere düşerdi — sıfır bu dosyada "puanı sil" demek.
  int? _surukleme;

  /// Bir yıldızın kapladığı yatay genişlik (build'de ölçülür). Sürükleme
  /// bunu kullanarak parmağın x'ini yıldıza çevirir; sabit sayı yazsaydık
  /// dar kutuda önizleme parmağın altındaki yıldızdan kayardı.
  double _hucre = 0;

  @override
  void initState() {
    super.initState();
    // Ölçek değişince (Ayarlar) yerel yıldız sayısı da yeni ölçeğe çevrilmeli.
    // `build` zaten ValueListenableBuilder ile yenileniyor ama `_yildiz`
    // ondan bağımsız bir alan: 5'lik ölçekte 4 yıldız duran ekran 100'lük
    // ölçeğe geçince 4/100 gösterirdi.
    PuanOlcegi.deger.addListener(_olcekDegisti);
  }

  @override
  void dispose() {
    PuanOlcegi.deger.removeListener(_olcekDegisti);
    super.dispose();
  }

  void _olcekDegisti() {
    if (!mounted || _isleniyor) return;
    setState(() => _yildiz = yildiza(widget.baslangicPuan));
  }

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
            // Kaydırıcı SINIRLI genişlik ister (Slider sonsuz kutuda patlar).
            // Ölçüsüz bir Row'un içindeysek tek dürüst seçenek eski rozet.
            final sonsuz = !kisit.maxWidth.isFinite;
            // GENİŞ ÖLÇEK → SAYFA İÇİ KAYDIRICI (3 Eyl 2026, kullanıcı:
            // *"5'ten fazla yıldızlama kullanıyorsa kaydırma slider koy"*).
            //
            // ESKİDEN ROZETTİ ve rozet "Puanla" yazan bir DÜĞMEYDİ: dokununca
            // kaydırıcı bir sheet'te açılıyordu. Kullanıcı ölçeğini 100 yapmış
            // olduğu için ekranda gördüğü şey hâlâ "Puanla" düğmesiydi —
            // istediği değişiklik onun hesabında hiç görünmedi. Kaydırıcı artık
            // sayfanın İÇİNDE; sheet yalnız ince ayar/silme için kalıyor.
            if (!yildizSatiriOlur(olcek)) {
              return sonsuz ? _rozet(olcek) : _kaydirici(olcek);
            }
            // Sonsuz genişlikte (Row içinde ölçüsüz) eldeki tek bilgi ikon
            // boyu; o durumda eski sabit payı kullan.
            final kullanilabilir = sonsuz ? olcek * (boy + 14) : kisit.maxWidth;
            // TAŞMA YASAK: eski sürüm hücreyi `boy + 4`ün ALTINA indirmiyordu,
            // yani dar bir kutuda (içerik sayfasında favori düğmesinin yanı,
            // 3 Eyl 2026) satır kutudan taşıp sarı çizgi basıyordu. Artık dar
            // kutuda önce İKON küçülür...
            var b = boy;
            final ham = kullanilabilir / olcek;
            if (ham < boy + 4) b = ham - 4;
            // ...18 dp de sığmıyorsa satır hiç çizilmez: o boyutta yıldız ne
            // okunur ne dokunulur. Dar kutuda kaydırıcı yıldızdan İYİ çalışır
            // (tek parmakla tüm aralık), o yüzden burada da ona düşülür.
            if (b < 18) return sonsuz ? _rozet(olcek) : _kaydirici(olcek);
            final hucre = ham.clamp(b + 4, 44.0);
            final yatay = ((hucre - b) / 2).clamp(2.0, 7.0);
            final satir = _satir(olcek, b, yatay, hucre);
            if (!widget.altYazi) return satir;
            // Etiket yıldızlarla SOLDAN HİZALI: `yatay` ilk yıldızın sol payı,
            // aynısını metne de vererek "Puanla" sözcüğü ilk yıldızın gövdesi
            // altında başlar (yoksa 4-7 dp sola kayık görünürdü).
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [satir, _altYazi(olcek, yatay)],
            );
          },
        );
      },
    );
  }

  /// Parmağın yatay konumunu (satırın soluna göre) yıldıza çevirir.
  /// `ceil`: 1. hücrenin herhangi bir noktası 1 yıldızdır, sınırı geçince 2.
  /// Sola taşan sürükleme 1'e kırpılır — 0 (silme) SÜRÜKLEMEYLE VERİLMEZ,
  /// çünkü kullanıcı puan vermek için sürüklerken kazara silmemeli; silme
  /// yine "aynı yıldıza dokun" kısayolu.
  int _hedefYildiz(double dx, int olcek) {
    if (_hucre <= 0) return 1;
    return (dx / _hucre).ceil().clamp(1, olcek);
  }

  Widget _satir(int olcek, double boy, double yatay, double hucre) {
    _hucre = hucre;
    // Sürüklerken dolan yıldız sayısı parmağı izler; bırakınca gerçek puana
    // döner (kaydetme başarısızsa iyimser güncelleme zaten geri alıyor).
    final gosterilen = _surukleme ?? _yildiz;
    return GestureDetector(
      // Yıldızların ARASINDAKİ paylar da sürüklemeyi taşısın.
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (d) {
        // Oturumsuzda hiç başlatma: iyimser önizleme gösterip 401 ile geri
        // almak yerine kullanıcı doğrudan giriş istemini görür (`_sec` ile
        // aynı kural).
        if (!girisGerekli(context)) return;
        if (_isleniyor) return;
        setState(() => _surukleme = _hedefYildiz(d.localPosition.dx, olcek));
      },
      onHorizontalDragUpdate: (d) {
        if (_surukleme == null) return;
        final h = _hedefYildiz(d.localPosition.dx, olcek);
        if (h != _surukleme) setState(() => _surukleme = h);
      },
      onHorizontalDragEnd: (_) {
        final secim = _surukleme;
        setState(() => _surukleme = null);
        // Aynı değere sürükleyip bırakmak DEĞİŞİKLİK DEĞİLDİR: ne istek
        // atılır ne de "aynı yıldıza dokununca sil" kısayolu tetiklenir
        // (sürükleyerek puan verirken kazara silme olmamalı).
        if (secim != null && secim != _yildiz) _yaz(secim);
      },
      onHorizontalDragCancel: () {
        if (_surukleme != null) setState(() => _surukleme = null);
      },
      child: _yildizlar(olcek, boy, yatay, gosterilen),
    );
  }

  Widget _yildizlar(int olcek, double boy, double yatay, int gosterilen) {
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
                y <= gosterilen
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                size: boy,
                color: y <= gosterilen ? DiziRenkler.sari : DiziRenkler.metin38,
              ),
            ),
          ),
      ],
    );
  }

  /// Yıldız satırının altındaki küçük etiket ([YildizPuan.altYazi]).
  ///
  /// Satır YÜKSEKLİĞİ SABİT: puansızken "Puanla", puanlıyken "4/5" yazar ama
  /// hiçbir zaman kaybolmaz. Kaybolsaydı ilk puanı veren kullanıcının altında
  /// bir satır çöker, sayfanın geri kalanı 13 dp yukarı zıplardı.
  ///
  /// Sürükleme sırasında parmağı izler (`_surukleme`): kullanıcı bırakmadan
  /// önce kaç puan verdiğini SAYIYLA da görür — 8 yıldızı gözle saymak zor.
  Widget _altYazi(int olcek, double yatay) => Padding(
    padding: EdgeInsets.only(left: yatay),
    child: _altYaziMetni(olcek),
  );

  /// Alt yazının kendisi (sarmalayıcısız) — kaydırıcı kipi bunu kendi
  /// satırında, "ince ayar" ikonunun yanında kullanır.
  Widget _altYaziMetni(int olcek) {
    final gosterilen = _surukleme ?? _yildiz;
    final ek = widget.altYaziEki;
    return Text.rich(
      TextSpan(
        children: [
          // SENİN girdin/çağrın: tam kontrast. `metin38` (pasif ton)
          // BİLEREK kullanılmadı — "Puanla" tıklanabilir bir çağrı, ipucu
          // değil; 11 dp'de white38 zaten okunmuyor (tema.dart md.).
          TextSpan(text: gosterilen > 0 ? '$gosterilen/$olcek' : 'Puanla'.c),
          // Ek (topluluk ortalaması) İKİNCİL: aynı renkte olsaydı
          // "3/5 · ort. 4.2" tek bir sayı dizisi gibi okunur, kullanıcı
          // hangisinin kendi puanı olduğunu ayırt edemezdi. `acikGri`
          // projenin ikincil metin tonu (siyah zeminde ~8,7:1 kontrast),
          // `metin38` gibi eşiğin altına düşmez.
          if (ek != null && ek.isNotEmpty)
            TextSpan(
              text: '  ·  $ek',
              style: TextStyle(
                color: DiziRenkler.acikGri,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
      // RichText tema rengini DEVRALMAZ; taban stil (RENK DAHİL) burada
      // açıkça verilir — skill md. 2, koyu temada siyah basma tuzağı.
      style: TextStyle(
        fontSize: 11,
        height: 1,
        fontWeight: FontWeight.w700,
        color: DiziRenkler.metin,
      ),
      // Dar sütunda ek uzunsa satırı taşırmasın.
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// GENİŞ ÖLÇEK KİPİ: sayfa içi kaydırıcı + altında ufak etiket.
  ///
  /// TASARIM KARARLARI
  /// -----------------
  ///  * ALT UÇ 0, 1 DEĞİL: 0 "puan yok" demek ve kaydırıcıyı sonuna kadar
  ///    sola çekmek puanı GERÇEKTEN siler. [puanSecSheet]'te alt uç 1'dir,
  ///    çünkü orada silme ayrı bir düğmedir ve 0'a inen bir kaydırıcı
  ///    "sildim" der ama silmezdi (kullanıcıya yalan söyleyen kontrol).
  ///    Burada yalan yok: 0 = sil.
  ///  * PUANSIZ AÇILIŞ SOLDA: tutamak 0'da durur, etiket "Puanla" der.
  ///    1'den başlasaydı puan vermemiş kullanıcı 1/100 vermiş görünürdü.
  ///  * BIRAKINCA YAZAR (`onChangeEnd`): sürüklerken her adımda POST atmak
  ///    100'lük ölçekte tek bir sürüklemede onlarca istek demekti.
  ///  * OTURUM KONTROLÜ BAŞTA (`onChangeStart`): satır kipiyle aynı kural —
  ///    iyimser önizleme gösterip 401 ile geri almak yerine kullanıcı
  ///    doğrudan giriş istemini görür ve tutamak hiç kıpırdamaz.
  ///  * ETİKET DOKUNULABİLİR (ince ayar ikonu): 100 bölmeli bir kaydırıcıda
  ///    bir adım ~3 dp; "73 mü 74 mü" sorusunu parmakla çözmek imkânsız.
  ///    Dokununca ±1 düğmeli [puanSecSheet] açılır.
  ///  * DİKEY PAY 14 DP: `padding: EdgeInsets.zero` verilince Slider'ın
  ///    yüksekliği 20 dp'ye düşüyordu — dokunma hedefi 44 dp eşiğinin ALTINDA
  ///    (puan_olcek_secimi_test yakaladı). 20 + 2x14 = 48 dp.
  ///  * YATAY PAY = TUTAMAK YARIÇAPI: 0 verilirse uçtaki tutamak kutudan taşar
  ///    ve kırpılır. Etiket de aynı payla girintilenir ki metin tutamağın
  ///    başlangıcıyla hizalansın.
  Widget _kaydirici(int olcek) {
    const yatayPay = 10.0;
    final gosterilen = (_surukleme ?? _yildiz).clamp(0, olcek);
    return ConstrainedBox(
      // TAVAN 420 DP: şirket sayfasında satır tam sayfa genişliğinde ve
      // kaydırıcı masaüstünde 1.050 dp'ye yayılıyordu — bir puan denetimi
      // değil, ilerleme çubuğu gibi duruyordu. 420 dp'de 100 bölmenin her
      // adımı ~4 dp; kesin değer zaten "ince ayar" sayfasından giriliyor.
      constraints: const BoxConstraints(maxWidth: 420),
      child: _kaydiriciGovde(olcek, yatayPay, gosterilen),
    );
  }

  Widget _kaydiriciGovde(int olcek, double yatayPay, int gosterilen) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: DiziRenkler.sari,
            inactiveTrackColor: DiziRenkler.metin24,
            thumbColor: DiziRenkler.sari,
            overlayColor: DiziRenkler.sari.withValues(alpha: 0.14),
            valueIndicatorColor: DiziRenkler.sari,
            valueIndicatorTextStyle: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w800,
            ),
            showValueIndicator: ShowValueIndicator.onlyForDiscrete,
            // BÖLME NOKTALARI 10 ÜSTÜNDE GİZLİ: 100 bölmede yol boyunca 99
            // nokta çıkıyor ve şerit TARAK gibi görünüyor (3 Eyl 2026,
            // şirket sayfası ekran görüntüsü). 10 ve altında (dar kutuya
            // düşen yıldız ölçeği) noktalar okunur ve adımı gösterir.
            activeTickMarkColor: olcek > 10 ? Colors.transparent : null,
            inactiveTickMarkColor: olcek > 10 ? Colors.transparent : null,
          ),
          child: Slider(
            value: gosterilen.toDouble(),
            min: 0,
            max: olcek.toDouble(),
            divisions: olcek,
            label: gosterilen == 0 ? 'Puanla'.c : '$gosterilen/$olcek',
            padding: EdgeInsets.symmetric(horizontal: yatayPay, vertical: 14),
            onChangeStart: (_) {
              _kaydirmaIzni = !_isleniyor && girisGerekli(context);
            },
            onChanged: (d) {
              if (!_kaydirmaIzni) return;
              final y = d.round();
              if (y != _surukleme) setState(() => _surukleme = y);
            },
            onChangeEnd: (d) {
              if (!_kaydirmaIzni) return;
              final y = d.round();
              setState(() => _surukleme = null);
              if (y != _yildiz) _yaz(y);
            },
          ),
        ),
        InkWell(
          onTap: () => _sheetAc(olcek),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: EdgeInsets.fromLTRB(yatayPay, 0, 6, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: _altYaziMetni(olcek)),
                const SizedBox(width: 4),
                Icon(Icons.tune, size: 13, color: DiziRenkler.acikGri),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Kaydırıcıya dokunan kişi giriş yapmış mı (dokunuş başında bir kez
  /// ölçülür). `false` ise `onChanged` değeri değiştirmez: tutamak yerinde
  /// kalır, kullanıcı giriş istemini görür.
  bool _kaydirmaIzni = false;

  /// ÖLÇÜSÜZ kutuda (Row içinde Expanded'sız) çizilen rozet — kaydırıcı
  /// sonsuz genişlikte çizilemediği için tek yedek bu. Puansızken de dokunulabilir
  /// olmalı — yoksa geniş ölçekteki kullanıcı puan VEREMEZ.
  ///
  /// [YildizPuan.altYaziEki] BURADA DA ÇİZİLİR (rozetin sağında, sönük):
  /// ek çağıranın tek "ortalama" göstergesi olabiliyor. Yalnız satır kipinde
  /// çizseydik ölçeğini 100 yapan kullanıcı kişi sayfasındaki "ort. 42"yi
  /// SESSİZCE KAYBEDERDİ — `puan_olcegi_test.dart` bunu yakaladı.
  Widget _rozet(int olcek) {
    final puanli = _yildiz > 0;
    final ek = widget.altYazi ? widget.altYaziEki : null;
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
            Flexible(
              child: Text(
                puanli ? '$_yildiz/$olcek' : 'Puanla'.c,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: puanli ? DiziRenkler.metin : DiziRenkler.metin54,
                ),
              ),
            ),
            if (ek != null && ek.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  ek,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: DiziRenkler.acikGri,
                  ),
                ),
              ),
            ],
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
