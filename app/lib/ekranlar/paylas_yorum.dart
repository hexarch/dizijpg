import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../ceviri.dart';
import '../gorsel_basliklari.dart';
import '../tema.dart';
import 'akis.dart' show AkisKarti;
import 'bolum_sec.dart';
import 'giris_istem.dart';
import 'gif_sec.dart';
import 'icerik_sec.dart';
import 'medya_inceleme.dart';
import '../medya_yukle.dart';

/// AKIŞTAN PAYLAŞIM — TAM EKRAN yazma ekranı.
///
/// KULLANICI İSTEĞİ (30 Ağu 2026, birebir): "Akışta gönderi paylaşırken yapım
/// seçme zorunlu olmasın, 'yapım seç' yazısındaki zorunluyu kaldır. Oraya da
/// yapım/yönetmen/oyuncu ekle olsun ve 1'den fazla eklenebilsin, ve
/// eklenenlerin profilinde de paylaşılacak — yani mesela Silo ve Breaking
/// Bad'i seçersem ikisinin de profilinde paylaşılacak. Ve dizilerde bölüm,
/// sezon veya dizinin kendisini de seçme olacak. Ve akıştaki 'yorum yap'a
/// tıklandığında yarım modal açma, tam ekranda aç, ve daha güzelini
/// yapabilirsin."
///
/// ---------------------------------------------------------------------------
/// NEDEN TAM EKRAN (yarım modal değil)
/// ---------------------------------------------------------------------------
/// 28 Ağu'daki alt sayfa tek bir iş için tasarlanmıştı: bir yapım seç, iki
/// satır yaz. Bugünkü ekranda dört iş var (metin · 0-6 etiket · ekler · spoiler)
/// ve telefonda klavye açıkken alt sayfanın geriye kalan yüksekliği ~%35'ti:
/// etiket rozetleri ile metin alanı aynı anda GÖRÜNMÜYORDU. Tam ekran ayrıca
/// tek bir birincil eylem (sağ üstteki Paylaş) ve tek bir çıkış (sol üstteki
/// çarpı) sözü verir — alt sayfada "aşağı sürükle" ile "çarpı" iki ayrı çıkış
/// yolu olarak yarışıyordu.
///
/// ---------------------------------------------------------------------------
/// VERİ SÖZLEŞMESİ
/// ---------------------------------------------------------------------------
/// Gönderilen şey hâlâ YENİ bir "gönderi" türü DEĞİL, sıradan bir YORUM
/// (`POST /yorumlar`). Yeni olan tek şey `etiketler` dizisi:
///   `[{tur, tmdb_id, sezon?, bolum?}, ...]`  (0..6)
/// Sunucu bu diziyi `yorum_etiketleri` bağ tablosuna yazıyor ve gönderi
/// LİSTEDEKİ HER VARLIĞIN sayfasında görünüyor.
///
/// ESKİ ALANLAR DA GÖNDERİLİYOR (`tur`/`tmdb_id`/`sezon`/`bolum`): yük hem yeni
/// hem eski sunucuda çalışsın diye. Sunucu `etiketler` varsa onu kullanır,
/// eskileri yok sayar. Dağıtım sırası sunucu → istemci olsa bile, kullanıcının
/// telefonundaki ESKİ uygulama yeni sunucuya yazmaya devam eder; tersi durum
/// (yeni web, eski sunucu) yalnız dağıtım penceresinde birkaç saniyedir ve bu
/// alanlar onu da kapatır.
class PaylasimEtiketi {
  final String tur; // tv · movie · person · company
  final int tmdbId;
  final String ad;

  /// TMDB görsel yolu (afiş / profil / logo) — tür başına ayrı alandan gelir.
  final String? gorsel;

  /// Dizide düzey: ikisi de null → dizinin kendisi, yalnız [sezon] → sezon,
  /// ikisi de dolu → bölüm.
  final int? sezon;
  final int? bolum;

  const PaylasimEtiketi({
    required this.tur,
    required this.tmdbId,
    required this.ad,
    this.gorsel,
    this.sezon,
    this.bolum,
  });

  factory PaylasimEtiketi.tmdb(Map<String, dynamic> r) => PaylasimEtiketi(
    tur: r['media_type'] as String,
    tmdbId: r['id'] as int,
    ad: (r['name'] ?? r['title'] ?? '?') as String,
    gorsel: tmdbGorselYolu(r),
  );

  PaylasimEtiketi duzeyle({int? sezon, int? bolum}) => PaylasimEtiketi(
    tur: tur,
    tmdbId: tmdbId,
    ad: ad,
    gorsel: gorsel,
    sezon: sezon,
    bolum: bolum,
  );

  bool get dizi => tur == 'tv';

  /// Aynı varlığın aynı DÜZEYİ iki kez eklenmesin diye tekillik anahtarı.
  /// Düzey anahtara DAHİL: "Silo" ile "Silo 2. sezon" ayrı etiketlerdir ve
  /// kullanıcı ikisini birden isteyebilir.
  String get anahtar => '$tur:$tmdbId:${sezon ?? ''}:${bolum ?? ''}';

  /// Rozetin altındaki küçük satır: tür ya da seçilen düzey.
  String get altYazi {
    if (bolum != null) return '{}. sezon {}. bölüm'.cf(['$sezon', '$bolum']);
    if (sezon != null) return '{}. sezon'.cf(['$sezon']);
    return tmdbTurEtiketi(tur);
  }

  Map<String, dynamic> get json => {
    'tur': tur,
    'tmdb_id': tmdbId,
    if (sezon != null) 'sezon': sezon,
    if (bolum != null) 'bolum': bolum,
  };
}

/// Paylaşım iki ADIMLI (kullanıcı isteği, 30 Ağu 2026): önce yazılır, sonra
/// gönderinin akışta görüneceği hâli önizlenir. Paylaş düğmesi YALNIZ ikinci
/// adımda — "yazdım, bir de bakayım" ile "paylaş" arasına bilinçli bir durak
/// kondu; spoiler kararı da orada veriliyor çünkü etkisi ancak kartta görülür.
enum _Adim { yazma, onizleme }

/// Etiket kutusunun yükseklik tavanı (dp). Aşılırsa kutu kendi içinde kayar.
const double _etiketKutuTavani = 132;

/// Yazma adımının altındaki ek önizleme karesinin kenarı (dp).
const double _ekKaresi = 128;

/// İkisinin küçüğü. (`dart:math`i tek bir çağrı için içeri almıyoruz.)
double _enKucuk(double a, double b) => a < b ? a : b;

class PaylasYorumEkrani extends StatefulWidget {
  const PaylasYorumEkrani({super.key});

  @override
  State<PaylasYorumEkrani> createState() => _PaylasYorumEkraniState();
}

class _PaylasYorumEkraniState extends State<PaylasYorumEkrani> {
  /// Etiket tavanı SUNUCUYLA AYNI (`YORUM_ETIKET_AZAMI`). Burada da durması
  /// gerekiyor ki kullanıcı 7. rozeti ekleyip 400 yemesin.
  static const etiketAzami = 6;

  final _metin = TextEditingController();
  final _odak = FocusNode();

  final List<PaylasimEtiketi> _etiketler = [];
  final List<Map<String, dynamic>> _ekler = []; // {yol, video}
  bool _ekYukleniyor = false;
  int _ekToplam = 0;
  int _ekBiten = 0;
  bool _spoiler = false;
  bool _gonderiliyor = false;

  /// Hangi adımdayız — bkz. [_Adim].
  _Adim _adim = _Adim.yazma;

  @override
  void initState() {
    super.initState();
    _metin.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _metin.dispose();
    _odak.dispose();
    super.dispose();
  }

  /// ETİKET ARTIK KAPI DEĞİL — tek koşul metin (sunucu da boş metni reddediyor).
  bool get _gonderilebilir =>
      _metin.text.trim().isNotEmpty && !_gonderiliyor && !_ekYukleniyor;

  /// Önizlemeye geçilebilir mi. Kapı [_gonderilebilir] ile AYNI: önizlemede
  /// paylaşamayacağı bir gönderiyle kullanıcıyı ileri almak, ikinci adımda
  /// kapalı bir Paylaş düğmesiyle karşılaştırmak demektir.
  bool get _ileriyeGecilebilir => _gonderilebilir;

  /// Yazmadan önizlemeye. Klavye KAPATILIR: önizlemenin tek işi kartı
  /// göstermek ve klavye ekranın yarısını yiyordu.
  void _ileriGit() {
    if (!_ileriyeGecilebilir) return;
    _odak.unfocus();
    setState(() => _adim = _Adim.onizleme);
  }

  // ------------------------------------------------------------------ etiket
  Future<void> _etiketEkle() async {
    if (_etiketler.length >= etiketAzami) {
      _uyar('En fazla {} yapım ekleyebilirsin.'.cf(['$etiketAzami']));
      return;
    }
    final secim = await icerikSecAc(context);
    if (secim == null || !mounted) return;
    var etiket = PaylasimEtiketi.tmdb(secim);
    // DİZİDE DÜZEY HEMEN SORULUR: seçici kapanır kapanmaz üç düzey açılır.
    // Ayrı bir "bölüm seç" satırı bırakmak, çoklu etikette hangi rozete ait
    // olduğunu belirsizleştirirdi (tek etiketliyken sorun değildi).
    if (etiket.dizi) {
      final duzey = await _duzeySec(etiket);
      if (!mounted) return;
      if (duzey == null) return; // vazgeçti → etiket HİÇ eklenmez
      etiket = duzey;
    }
    if (_etiketler.any((e) => e.anahtar == etiket.anahtar)) {
      _uyar('Bu zaten ekli.'.c);
      return;
    }
    setState(() => _etiketler.add(etiket));
  }

  /// Dizinin kendisi / sezon / bölüm. `null` = vazgeçildi.
  Future<PaylasimEtiketi?> _duzeySec(PaylasimEtiketi etiket) async {
    final secim = await bolumSecAc(
      context,
      diziId: etiket.tmdbId,
      diziAd: etiket.ad,
    );
    if (secim == null) return null;
    // Sözleşme (bolum_sec.dart): `{}` dizinin kendisi, `{sezon}` sezon,
    // `{sezon, bolum}` bölüm.
    return etiket.duzeyle(
      sezon: secim['sezon'] as int?,
      bolum: secim['bolum'] as int?,
    );
  }

  /// Ekli bir dizi rozetine dokunuş: düzeyini DEĞİŞTİR.
  Future<void> _duzeyDegistir(int i) async {
    final yeni = await _duzeySec(_etiketler[i]);
    if (yeni == null || !mounted) return;
    // Düzey değişince başka bir rozetle çakışabilir (Silo 2. sezon zaten
    // ekliyken Silo'yu 2. sezona çevirmek gibi) — çakışırsa yenisi düşer.
    if (_etiketler.asMap().entries.any(
      (g) => g.key != i && g.value.anahtar == yeni.anahtar,
    )) {
      _uyar('Bu zaten ekli.'.c);
      return;
    }
    setState(() => _etiketler[i] = yeni);
  }

  // -------------------------------------------------------------------- ekler
  Future<void> _gifSec() async {
    if (!girisGerekli(context)) return;
    if (_ekler.length >= 10 || _ekYukleniyor) return;
    final gif = await gifSecAc(context);
    if (gif == null || !mounted) return;
    final yol = gif['yol'] as String?;
    if (yol == null) return;
    setState(() => _ekler.add({'yol': yol, 'video': false}));
  }

  Future<void> _ekSec() async {
    if (!girisGerekli(context)) return;
    final kalan = 10 - _ekler.length;
    if (kalan <= 0 || _ekYukleniyor) return;
    final secim = await medyaSec(context, azami: kalan);
    if (secim.isEmpty || !mounted) return;
    setState(() {
      _ekYukleniyor = true;
      _ekToplam = secim.length;
      _ekBiten = 0;
    });
    final sonuc = await medyalariYukle(
      secim,
      adim: (biten) {
        if (mounted) setState(() => _ekBiten = biten);
      },
    );
    if (!mounted) return;
    setState(() {
      _ekler.addAll(sonuc.yuklenen);
      _ekYukleniyor = false;
    });
    if (sonuc.hata != null) _uyar(sonuc.hata!);
  }

  void _uyar(String mesaj) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(mesaj)));

  Future<void> _gonder() async {
    if (!_gonderilebilir) return;
    if (!girisGerekli(context)) return;
    setState(() => _gonderiliyor = true);
    try {
      final birincil = _etiketler.isEmpty ? null : _etiketler.first;
      await Api.post('/yorumlar', {
        'etiketler': _etiketler.map((e) => e.json).toList(),
        // ---- ESKİ SUNUCU İÇİN YEDEK ALANLAR ----
        // Yalnız BÖLÜM düzeyinde sezon/bolum konur: eski sunucu "sezon ve
        // bolum birlikte" şartını uyguluyor ve sezon-düzeyi bir yükü 400
        // ile reddederdi.
        if (birincil != null) 'tur': birincil.tur,
        if (birincil != null) 'tmdb_id': birincil.tmdbId,
        if (birincil?.bolum != null) 'sezon': birincil!.sezon,
        if (birincil?.bolum != null) 'bolum': birincil!.bolum,
        'metin': _metin.text.trim(),
        'medya': _ekler.map((e) => e['yol']).toList(),
        'spoiler': _spoiler,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _gonderiliyor = false);
        _uyar(e.toString());
      }
    }
  }

  // ------------------------------------------------------------------- çıkış
  /// Yazılmış bir şey var mı — kapatma onayı buna bakar.
  bool get _dolu =>
      _metin.text.trim().isNotEmpty ||
      _ekler.isNotEmpty ||
      _etiketler.isNotEmpty;

  /// Kapatmadan önce onay. `true` dönerse ekran kapanır.
  ///
  /// ux md.4 + `sheet-dismiss-confirm` (Apple HIG, ui-ux-pro-max veritabanı):
  /// "Kaydedilmemiş değişiklik varken kapatmadan önce onay iste." Tam ekranda
  /// bu kural alt sayfadakinden DAHA önemli: kullanıcı burada uzun metin
  /// yazıyor ve Android'in geri hareketi tek parmak kaydırmasıyla geliyor.
  Future<bool> _cikilsinMi() async {
    if (!_dolu || _gonderiliyor) return true;
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: DiziRenkler.koyuGri,
        title: Text(
          'Gönderiden vazgeç'.c,
          style: TextStyle(color: DiziRenkler.metin),
        ),
        content: Text(
          'Yazdıkların kaydedilmeyecek.'.c,
          style: TextStyle(color: DiziRenkler.metin54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Yazmaya devam et'.c),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Vazgeç'.c, style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    return onay == true;
  }

  // -------------------------------------------------------------------- çizim
  @override
  Widget build(BuildContext context) {
    final kalan = 1000 - _metin.text.characters.length;
    return PopScope(
      // ANDROID GERİ HAREKETİ de onaydan geçsin. `WillPopScope` kullanılmadı:
      // Flutter'da kullanımdan kaldırıldı (Flutter yığını kuralı #21).
      //
      // ⚠ `canPop` SABİT `false` OLAMAZ. PopScope PROGRAMLI `Navigator.pop`u
      // da yakalıyor: paylaşım bittikten sonraki `Navigator.pop(context, true)`
      // engellenir, yerine `onPopInvokedWithResult` çalışır ve o dal SONUÇ
      // TAŞIMADAN kapatırdı. Çağıran `true` yerine `null` alır, akış
      // TAZELENMEZ — yani kullanıcı paylaştığı gönderiyi göremezdi.
      // Bu yüzden `_gonderiliyor` koşulu EN BAŞTA duruyor ve ÖNİZLEME
      // ADIMINDA DA geçerli: paylaşım oradan başlıyor.
      //
      // ÖNİZLEMEDEYKEN GERİ = YAZMAYA DÖN (ekranı kapatmaz). Kullanıcı bir
      // adım ilerledi; geri hareketi o adımı geri almalı, yazdığı her şeyi
      // atmayı sormamalı.
      canPop: _gonderiliyor || (_adim == _Adim.yazma && !_dolu),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_adim == _Adim.onizleme) {
          setState(() => _adim = _Adim.yazma);
          return;
        }
        if (await _cikilsinMi() && mounted) {
          if (!context.mounted) return;
          Navigator.pop(context);
        }
      },
      child: _adim == _Adim.yazma ? _yazmaAdimi(kalan) : _onizlemeAdimi(),
    );
  }

  // ====================================================================
  // ADIM 1 — YAZMA
  // ====================================================================
  /// KULLANICI İSTEĞİ (30 Ağu 2026, birebir): *"yukarıda profil resmim yanında
  /// adım, altında etiket ekle, onun da altında en aşağıya kadar 'ne
  /// düşünüyorsun' yazısı ve en aşağı solda galeri iconu sağda ileri iconu.
  /// Galeriye basıp görsel seçtiğinde input alanı küçülerek yukarı çıkacak,
  /// görsel aşağıda olacak. İleri dediğimde gönderinin bana paylaşılmış gibi
  /// hâlini gösterecek ve spoiler etiketi vurma iconu olacak. Input alanı arka
  /// plan ile aynı renkte olmalı, farklı renklerde yapma."*
  ///
  /// ÖNCEKİ DÜZENDEN FARKI: metin alanı avatarın SAĞINDA dar bir sütundu ve
  /// etiketler ile ekler onun ALTINDA, kaydırılan bir listede duruyordu —
  /// yazarken üçü aynı anda görünmüyordu. Şimdi kimlik/etiket üstte SABİT,
  /// metin aradaki tüm boşluğu kaplıyor, ekler dibe oturuyor.
  Widget _yazmaAdimi(int kalan) {
    return Scaffold(
      backgroundColor: DiziRenkler.siyah,
      appBar: AppBar(
        // TEK ÇIKIŞ: sol üstte çarpı. Alt sayfadaki "aşağı sürükle" yolu
        // bilerek kalktı — iki çıkış, yazılmış metni kazayla atma riskini
        // ikiye katlıyordu.
        leading: IconButton(
          tooltip: 'Kapat'.c,
          icon: Icon(Icons.close, color: DiziRenkler.metin),
          onPressed: () async {
            if (await _cikilsinMi() && mounted) {
              if (!context.mounted) return;
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          'Paylaş'.c,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: DiziRenkler.metin,
          ),
        ),
      ),
      // MASAÜSTÜNDE ORTALANMIŞ KOLON — akış, takvim, Reels ve profil ile AYNI
      // kalıp ([OrtaKolon], tema.dart). Kolon kısıtı olmadan metin alanı
      // 1.300 dp'ye yayılıyor ve satır uzunluğu okunabilir aralığın (35-60
      // karakter) çok üstüne çıkıyordu. TELEFON BOZULMAZ: [OrtaKolon] sabit
      // genişlik değil ÜST SINIR verir.
      body: SafeArea(
        child: OrtaKolon(
          azami: masaustuKolonGenisligi,
          cocuk: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                  // TAVANLAR EKRANA GÖRE: sabit 132/128 dp, klavye açık kısa
                  // bir telefonda (kalan yükseklik ~330 dp) etiket kutusu +
                  // ek şeridi metin alanını sıfıra indirip Column'u
                  // taşırabiliyordu. Oranla sınırlayınca metin alanı HER
                  // ZAMAN payını alır.
                  child: LayoutBuilder(
                    builder: (context, kisit) {
                      final y = kisit.maxHeight;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _kimlikSatiri(),
                          const SizedBox(height: 10),
                          _etiketKutusu(
                            tavan: _enKucuk(_etiketKutuTavani, y * 0.3),
                          ),
                          const SizedBox(height: 6),
                          // "en aşağıya kadar" — metin, kalan boşluğun TAMAMI.
                          // Ek seçilince aşağıdaki şerit yer kaplar ve bu alan
                          // kendiliğinden küçülür ("input alanı küçülerek
                          // yukarı çıkacak"): yükseklik iki widget arasında
                          // paylaşılıyor, elle hesaplanmıyor.
                          Expanded(child: _yaziAlani()),
                          if (_ekler.isNotEmpty)
                            _ekOnizleme(kenar: _enKucuk(_ekKaresi, y * 0.35)),
                        ],
                      );
                    },
                  ),
                ),
              ),
              _yazmaAltCubugu(kalan),
            ],
          ),
        ),
      ),
    );
  }

  /// Profil resmi + ad. Gönderiyi KİMİN paylaşacağını en başta gösterir
  /// (akış kartının başlığıyla aynı sıra: avatar, sonra ad).
  Widget _kimlikSatiri() {
    final k = _oturumKullanicisi;
    final ad = (k?['ad'] as String?)?.trim();
    final kadi = (k?['kullanici_adi'] as String?)?.trim() ?? '';
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: DiziRenkler.kart,
          backgroundImage: _avatarUrl == null
              ? null
              : CachedNetworkImageProvider(
                  _avatarUrl!,
                  headers: gorselBasliklari(_avatarUrl!),
                ),
          child: _avatarUrl == null
              ? Icon(Icons.person, size: 22, color: DiziRenkler.metin38)
              : null,
        ),
        const SizedBox(width: 12),
        // Flexible + ellipsis: uzun ad satırı taşırmasın.
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                // Görünen ad yoksa kullanıcı adı: satır ASLA boş kalmaz.
                ad != null && ad.isNotEmpty ? ad : '@$kadi',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: DiziRenkler.metin,
                ),
              ),
              // İkinci satır yalnız ad VARSA çizilir; yoksa @kadi zaten
              // üstte duruyor ve iki kez yazmanın anlamı yok.
              if (ad != null && ad.isNotEmpty && kadi.isNotEmpty)
                Text(
                  '@$kadi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: DiziRenkler.metin38),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Etiket rozetleri + "Etiket ekle" — kimliğin ALTINDA, metnin ÜSTÜNDE.
  ///
  /// YÜKSEKLİK TAVANLI ve KENDİ İÇİNDE KAYDIRILIR: altı rozet (tavan) dar bir
  /// telefonda üç satır ediyor ve tavansız bırakılırsa metin alanını yiyip
  /// klavye açıkken "ne düşünüyorsun" alanını sıfıra indiriyordu.
  Widget _etiketKutusu({required double tavan}) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: tavan),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // "ETİKET EKLE" EN BAŞTA — rozetlerin ARDINDA değil.
                // Kullanıcı düzeni "adım, altında etiket ekle" diye tarif
                // etti; ayrıca kutu yükseklik tavanlı ve kendi içinde kayıyor:
                // düğme sonda dursaydı üçüncü etiketten sonra görüş alanının
                // ALTINA düşer, kullanıcı yeni etiket eklemek için önce
                // kaydırmak zorunda kalırdı (widget testinde birebir bu
                // yaşandı — dokunma hedefi ekranda yokken tıklanamıyor).
                if (_etiketler.length < etiketAzami) _ekleRozeti(),
                for (var i = 0; i < _etiketler.length; i++)
                  _EtiketRozeti(
                    etiket: _etiketler[i],
                    // Dizide rozete dokunmak DÜZEYİ değiştirir; film/kişi/
                    // firmada değiştirilecek düzey yok, o yüzden dokunma da
                    // yok (tıklanınca hiçbir şey olmayan hedef bırakmıyoruz).
                    onDuzey: _etiketler[i].dizi
                        ? () => _duzeyDegistir(i)
                        : null,
                    onKaldir: () => setState(() => _etiketler.removeAt(i)),
                  ),
              ],
            ),
            if (_etiketler.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  // "(zorunlu)" GİTTİ — kullanıcı isteği. Yerine ne işe
                  // yaradığını söyleyen bir ipucu kondu; boş bırakmak da
                  // geçerli bir seçim olduğu için uyarı tonunda DEĞİL.
                  'Dizi, film, oyuncu ya da yönetmen etiketle — gönderin onların sayfasında da görünür.'
                      .c,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: DiziRenkler.metin38,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _ekleRozeti() {
    return Semantics(
      button: true,
      label: 'Dizi, film, oyuncu ya da yönetmen etiketle'.c,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: _etiketEkle,
        child: Container(
          // Dokunma hedefi 44 dp (ux md.2); genişlik tavanı taşmayı önler.
          constraints: const BoxConstraints(minHeight: 44, maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: DiziRenkler.sariMetin.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 18, color: DiziRenkler.sariMetin),
              const SizedBox(width: 6),
              // Flexible + ellipsis: çeviri uzarsa rozet taşmaz, kısalır.
              Flexible(
                child: Text(
                  'Etiket ekle'.c,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: DiziRenkler.sariMetin,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Ne düşünüyorsun?" — kalan yüksekliğin TAMAMINI kaplayan metin alanı.
  ///
  /// ZEMİN YOK, ÇERÇEVE YOK (kullanıcı: *"input alanı arka plan ile aynı
  /// renkte olmalı, farklı renklerde yapma"*): `filled: false` + `InputBorder
  /// .none`. Kutu çizmek hem alanı daraltıyor hem "form doldur" hissi
  /// veriyordu; burada yazılan şey bir gönderi.
  ///
  /// `expands: true` ile `textAlignVertical: top` BİRLİKTE gider: yalnız
  /// `expands` verilirse imleç ve ipucu alanın DİKEY ORTASINA oturur ve
  /// boş ekranda "ne düşünüyorsun" havada asılı görünür.
  Widget _yaziAlani() {
    return TextField(
      controller: _metin,
      focusNode: _odak,
      autofocus: true,
      expands: true,
      maxLines: null,
      minLines: null,
      maxLength: 1000,
      keyboardType: TextInputType.multiline,
      textAlignVertical: TextAlignVertical.top,
      // Sayaç alt çubukta; buradaki yerleşik sayaç ikinci kez yazardı.
      buildCounter:
          (_, {required currentLength, required isFocused, maxLength}) => null,
      style: TextStyle(color: DiziRenkler.metin, fontSize: 17, height: 1.45),
      decoration: InputDecoration(
        hintText: 'Ne düşünüyorsun?'.c,
        hintStyle: TextStyle(color: DiziRenkler.metin38, fontSize: 17),
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  /// Seçilen görseller — METNİN ALTINDA, ekranın dibinde.
  ///
  /// Eski 84 dp'lik şerit "ne eklediğimi göremiyorum" sorununu ancak yarı
  /// çözüyordu; burada kare [_ekKaresi] dp ve gönderide nasıl görüneceğine
  /// yakın duruyor.
  Widget _ekOnizleme({required double kenar}) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: SizedBox(
        height: kenar,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _ekler.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final ek = _ekler[i];
            final video = ek['video'] == true;
            final url = dosyaUrl(ek['yol'] as String?);
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: kenar,
                    height: kenar,
                    color: DiziRenkler.kart,
                    child: video || url == null
                        ? Icon(
                            video
                                ? Icons.play_circle_outline
                                : Icons.image_outlined,
                            size: 34,
                            color: DiziRenkler.metin38,
                          )
                        : CachedNetworkImage(
                            imageUrl: url,
                            httpHeaders: gorselBasliklari(url),
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                // Kaldırma düğmesi KARENİN İÇİNDE: `Positioned`ı Stack
                // sınırının dışına taşırmak (negatif offset) onu Flutter'da
                // TIKLANAMAZ yapar (ux md.2).
                Positioned(
                  top: 0,
                  right: 0,
                  child: Semantics(
                    button: true,
                    label: 'Kaldır'.c,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => _ekler.removeAt(i)),
                        child: const Padding(
                          padding: EdgeInsets.all(11),
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Yazma adımının alt çubuğu: SOLDA galeri (+GIF), SAĞDA ileri.
  ///
  /// ZEMİN SAYFAYLA AYNI RENK — kullanıcı isteği. Ayırıcı olarak yalnız saç
  /// teli kalınlığında bir çizgi var: renk bloğu değil, sınır.
  ///
  /// GIF DÜĞMESİ KALDIRILMADI. Kullanıcı "solda galeri, sağda ileri" dedi;
  /// GIF de bir EK EKLEME düğmesi, yani solun işi. Çıkarsaydık çalışan bir
  /// özellik sessizce kaybolurdu.
  Widget _yazmaAltCubugu(int kalan) {
    return Container(
      decoration: BoxDecoration(
        color: DiziRenkler.siyah,
        border: Border(top: BorderSide(color: DiziRenkler.metin12)),
      ),
      padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Fotoğraf/video ekle'.c,
            onPressed: _ekYukleniyor ? null : _ekSec,
            icon: Icon(
              Icons.photo_library_outlined,
              color: DiziRenkler.sariMetin,
            ),
          ),
          IconButton(
            tooltip: 'GIF ekle'.c,
            onPressed: _ekYukleniyor ? null : _gifSec,
            icon: Icon(Icons.gif_box_outlined, color: DiziRenkler.sariMetin),
          ),
          const Spacer(),
          if (_ekYukleniyor)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                '{}/{} yükleniyor'.cf(['$_ekBiten', '$_ekToplam']),
                style: TextStyle(fontSize: 12, color: DiziRenkler.metin54),
              ),
            )
          // Sayaç yalnız SON 100 KARAKTERDE çıkar: sürekli görünen bir sayaç
          // kısa gönderilerde gereksiz baskı kuruyor.
          else if (kalan <= 100)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                '$kalan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kalan < 0 ? Colors.redAccent : DiziRenkler.metin54,
                ),
              ),
            ),
          _ileriDugmesi(),
        ],
      ),
    );
  }

  /// Sağ alttaki "ileri" düğmesi — bu adımın TEK birincil eylemi.
  ///
  /// DOLU DAİRE, düz ikon değil: yanındaki galeri/GIF ile aynı ağırlıkta
  /// çizilseydi "hangisi devam ettiriyor?" sorusu ekranda cevapsız kalırdı.
  /// Metin boşken KAPALI (sunucu da boş metni reddediyor) ve `Tooltip`
  /// hâlâ duruyor: kapalı düğmenin neden kapalı olduğunu tahmin ettirmeyiz.
  Widget _ileriDugmesi() {
    final acik = _ileriyeGecilebilir;
    return Semantics(
      button: true,
      enabled: acik,
      label: 'İleri'.c,
      child: IconButton(
        tooltip: 'İleri'.c,
        onPressed: acik ? _ileriGit : null,
        style: IconButton.styleFrom(
          backgroundColor: acik ? DiziRenkler.sari : DiziRenkler.kart,
          disabledForegroundColor: DiziRenkler.metin38,
          // Sarı üstüne DAİMA siyah (tema.dart kuralı).
          foregroundColor: Colors.black,
          minimumSize: const Size(44, 44),
        ),
        icon: const Icon(Icons.arrow_forward, size: 20),
      ),
    );
  }

  // ====================================================================
  // ADIM 2 — ÖNİZLEME
  // ====================================================================
  /// *"İleri dediğimde gönderinin bana paylaşılmış gibi hâlini gösterecek."*
  ///
  /// GERÇEK AKIŞ KARTI ÇİZİLİR ([AkisKarti]), taklidi değil: önizlemenin tek
  /// işi "akışta böyle görünecek" sözünü tutmak ve ayrı bir kopya widget o
  /// sözü ilk kart değişikliğinde bozar. Kart [IgnorePointer] içinde —
  /// beğeni/yanıt/takip düğmeleri henüz var olmayan bir gönderiye (id 0)
  /// istek atmasın diye. (`GonderiOlcu.bildir` zaten `id <= 0`'ı eler; yine
  /// de dokunmayı kaynağında kesiyoruz.)
  Widget _onizlemeAdimi() {
    return Scaffold(
      backgroundColor: DiziRenkler.siyah,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Geri'.c,
          icon: Icon(Icons.arrow_back, color: DiziRenkler.metin),
          onPressed: () => setState(() => _adim = _Adim.yazma),
        ),
        title: Text(
          'Önizleme'.c,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: DiziRenkler.metin,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: OrtaKolon(
                  azami: masaustuKolonGenisligi,
                  cocuk: IgnorePointer(
                    child: AkisKarti(
                      // Anahtar spoiler durumunu TAŞIR: kartın perde durumu
                      // `State` alanında ilk yapılışta hesaplanıyor, harita
                      // değişince kendiliğinden güncellenmez. Anahtar değişince
                      // State yeniden kurulur ve perde anında iner/kalkar.
                      key: ValueKey('onizleme-$_spoiler'),
                      yorum: _onizlemeYorumu,
                      icerikler: _onizlemeIcerikleri,
                    ),
                  ),
                ),
              ),
            ),
            _onizlemeAltCubugu(),
          ],
        ),
      ),
    );
  }

  /// Önizleme adımının alt çubuğu: SOLDA spoiler damgası, SAĞDA Paylaş.
  Widget _onizlemeAltCubugu() {
    return Container(
      decoration: BoxDecoration(
        color: DiziRenkler.siyah,
        border: Border(top: BorderSide(color: DiziRenkler.metin12)),
      ),
      padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
      child: Row(
        children: [
          _spoilerDamgasi(),
          const Spacer(),
          FilledButton(
            onPressed: _gonderilebilir ? _gonder : null,
            child: _gonderiliyor
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Paylaş'.c),
          ),
        ],
      ),
    );
  }

  /// SPOİLER DAMGASI — *"spoiler etiketi vurma ikonu"*.
  ///
  /// Önizleme adımında durmasının sebebi geri bildirim: damgaya basınca
  /// üstteki kart ANINDA perdeleniyor, yani kullanıcı "spoiler işaretlersem
  /// karşı taraf ne görecek" sorusunu deneyerek cevaplıyor. Yazma adımında
  /// gösterecek bir kart olmadığı için orada yalnız bir onay kutusuydu.
  ///
  /// Durum ÜÇ kanaldan okunur: ikonun dolu/boş hâli, rengi ve
  /// `Semantics.toggled` (ekran okuyucu).
  Widget _spoilerDamgasi() {
    return Semantics(
      button: true,
      toggled: _spoiler,
      label: 'Spoiler'.c,
      child: Tooltip(
        message: 'Spoiler'.c,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => setState(() => _spoiler = !_spoiler),
          child: Container(
            // Dokunma hedefi 44 dp (ux md.2).
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _spoiler
                      ? Icons.visibility_off
                      : Icons.visibility_off_outlined,
                  size: 22,
                  color: _spoiler ? DiziRenkler.sariMetin : DiziRenkler.metin54,
                ),
                const SizedBox(width: 8),
                Text(
                  'Spoiler'.c,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: _spoiler ? FontWeight.w700 : FontWeight.w400,
                    color: _spoiler
                        ? DiziRenkler.sariMetin
                        : DiziRenkler.metin54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ önizleme veri
  /// Önizlemenin çizdiği SAHTE gönderi haritası — akış/Reels ile AYNI
  /// sözleşme (`akisSatiri`, server.js). `id: 0` bilerek: gerçek bir gönderi
  /// yok ve sayaç uçları sıfırı eler.
  Map<String, dynamic> get _onizlemeYorumu {
    final k = _oturumKullanicisi;
    final birincil = _etiketler.isEmpty ? null : _etiketler.first;
    return {
      'id': 0,
      'kullanici_id': k?['id'],
      'kullanici_adi': k?['kullanici_adi'] ?? '',
      'avatar': k?['avatar'],
      // Etiketsiz gönderide `tur` NULL kalmalı: kart o zaman içerik adı
      // satırını hiç çizmiyor (yoksa sarı bir "?" yazardı).
      'tur': birincil?.tur,
      'tmdb_id': birincil?.tmdbId,
      // SEZON/BÖLÜM İKİSİ BİRDEN ya da HİÇBİRİ — sunucunun yorum satırına
      // yazdığı kuralın aynısı (`server.js`: `sezon = birincil?.bolum != null
      // ? birincil.sezon : null`, ve yarım çift 400 ile reddediliyor).
      // Kart `sezon != null` görünce `bolum`u da `int` diye okuyor; sezon
      // düzeyi etiketli bir önizlemede yarım çift bırakmak kartı ÇÖKERTİYORDU
      // (widget testinde yakalandı).
      'sezon': birincil?.bolum != null ? birincil!.sezon : null,
      'bolum': birincil?.bolum,
      'etiketler': _etiketler.map((e) => e.json).toList(),
      'metin': _metin.text.trim(),
      'medya': _ekler.map((e) => e['yol']).toList(),
      'spoiler': _spoiler,
      'begeni': 0,
      'yanit': 0,
      'begendim': false,
      // null = "sunucu bildirmedi" → kart Takip Et düğmesini hiç çizmez.
      'takip_ediyorum': null,
      'tarih': _bugun,
      'goruntulenme': 0,
    };
  }

  /// Etiketlerin ad/afiş haritası — kartın `icerikler['tur:id']` beklentisi.
  Map<String, dynamic> get _onizlemeIcerikleri => {
    for (final e in _etiketler)
      '${e.tur}:${e.tmdbId}': {'ad': e.ad, 'poster': e.gorsel},
  };

  /// Kartın tarih satırı `YYYY-AA-GG` bekliyor (sunucu ISO gönderiyor,
  /// kart `T`den bölüyor).
  String get _bugun => DateTime.now().toIso8601String();

  // ------------------------------------------------------------------ ortak
  /// Oturumdaki kullanıcı haritası. SAĞLAYICI YOKSA ÇÖKMEZ: bu ekran widget
  /// testlerinde `Provider<Oturum>` olmadan da kuruluyor.
  Map<String, dynamic>? get _oturumKullanicisi {
    try {
      return context.watch<Oturum>().kullanici;
    } on ProviderNotFoundException {
      return null;
    }
  }

  String? get _avatarUrl {
    final ham = _oturumKullanicisi?['avatar'];
    return ham is String && ham.trim().isNotEmpty ? dosyaUrl(ham) : null;
  }
}

/// Tek bir etiket rozeti: görsel + ad + düzey + kaldırma.
class _EtiketRozeti extends StatelessWidget {
  final PaylasimEtiketi etiket;
  final VoidCallback? onDuzey;
  final VoidCallback onKaldir;

  const _EtiketRozeti({
    required this.etiket,
    required this.onDuzey,
    required this.onKaldir,
  });

  @override
  Widget build(BuildContext context) {
    final gorsel = posterUrl(etiket.gorsel, boyut: 'w92');
    return Container(
      constraints: const BoxConstraints(minHeight: 44, maxWidth: 260),
      decoration: BoxDecoration(
        color: DiziRenkler.kart,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: DiziRenkler.metin12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(4),
            child: ClipOval(
              child: SizedBox(
                width: 32,
                height: 32,
                child: gorsel == null
                    ? Container(
                        color: DiziRenkler.acikGri,
                        child: Icon(
                          etiket.tur == 'person'
                              ? Icons.person
                              : etiket.tur == 'company'
                              ? Icons.business
                              : Icons.movie_outlined,
                          size: 16,
                          color: DiziRenkler.metin38,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: gorsel,
                        httpHeaders: gorselBasliklari(gorsel),
                        // Firma logosu şeffaf ve GENİŞ: `cover` onu kırpıp
                        // tanınmaz hâle getirir.
                        fit: etiket.tur == 'company'
                            ? BoxFit.contain
                            : BoxFit.cover,
                      ),
              ),
            ),
          ),
          Flexible(
            child: InkWell(
              onTap: onDuzey,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      etiket.ad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: DiziRenkler.metin,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            etiket.altYazi,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: DiziRenkler.metin38,
                            ),
                          ),
                        ),
                        // Düzey DEĞİŞTİRİLEBİLİR olduğunu gösteren tek işaret;
                        // yalnız dizide çizilir.
                        if (onDuzey != null)
                          Icon(
                            Icons.expand_more,
                            size: 14,
                            color: DiziRenkler.metin38,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 44 dp'lik ayrı dokunma hedefi: rozetin gövdesi düzeyi açar,
          // buradaki çarpı rozeti KALDIRIR. İkisi karışmasın diye ayrık.
          Semantics(
            button: true,
            label: 'Kaldır'.c,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onKaldir,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.close, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paylaşım ekranını TAM EKRAN açar. Paylaşım yapıldıysa `true` döner
/// (çağıran akışı tazelesin diye).
///
/// `fullscreenDialog: true`: iOS'ta aşağıdan yukarı geçiş + çarpı ikonu,
/// Android'de de "bu bir görev, bir sayfa değil" davranışı.
Future<bool> paylasYorumAc(BuildContext context) async {
  final sonuc = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const PaylasYorumEkrani(),
    ),
  );
  return sonuc == true;
}
