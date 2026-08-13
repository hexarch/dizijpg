import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../ceviri.dart';
import '../tema.dart';
import '../video_islem.dart';
import '../yerel_video.dart';
import 'ortak.dart';

/// Video kırpma (trim) + otomatik sıkıştırma (MEDYA-EDITOR-PLANI §V1).
///
/// İKİ GİRİŞ NOKTASI, ikisi de `gorsel_duzenle.dart` felsefesini izler
/// (bayt/dosya al, dosya dön; vazgeçilirse `null`; ayrı bir "editör modülü"
/// sızmaz):
///
/// 1. [videoDuzenle] — trim ekranını açar, kullanıcının KARARINI döner.
///    **Hiçbir şey kodlamaz.**
/// 2. [videoHazirla] — kararı (ve/veya otomatik sıkıştırmayı) yükleme
///    hattına girmeden HEMEN ÖNCE uygular; ilerleme + İPTAL burada.
///
/// NEDEN İKİYE AYRILDI: kodlama tek bir yerde toplanınca yüzde göstergesi ve
/// iptal düğmesi de TEK yerde yaşar. Trim ekranında "Tamam"a basınca 30 sn
/// beklemek (ve sonra "İleri"de bir daha beklemek) iki ayrı bekleme demekti.
/// Instagram da kesme kararını anında alır, kodlamayı paylaşıma bırakır.
///
/// İPTAL NEDEN ŞART: görsel editörde iptal kancası YOKTU çünkü dışa aktarım
/// saniyenin altındaydı. Videoda işlem 20-60 sn sürebilir; iptalsiz bir
/// ilerleme çubuğu kullanıcıyı rehin alır (ui-ux-pro-max, Feedback/Progress
/// Indicators + Async/loading-and-error-states).

/// Testler için: video motorunu değiştirir.
/// `() => null` vermek WEB davranışını (cihazda kodlayıcı yok) taklit eder.
@visibleForTesting
VideoIsleyici? Function()? videoIsleyiciSahte;

/// Motor çözümü. Web'de [videoIsleyici] zaten `null` döner (stub);
/// [kIsWeb] kontrolü ikinci emniyet kemeridir — `yerel_video.dart`
/// sapıyla aynı desen.
VideoIsleyici? videoMotoru() {
  if (videoIsleyiciSahte != null) return videoIsleyiciSahte!();
  return kIsWeb ? null : videoIsleyici();
}

/// Bu platformda video düzenlenebilir mi? Düzenle düğmesi buna bakar.
///
/// Web'de **pasif gri bir düğme gösterilmez**, düğme HİÇ çizilmez:
/// "desteklenmiyor" diyen ölü bir kontrol, olmayan bir kontrolden daha kötü
/// bir deneyimdir (MEDYA-EDITOR-PLANI §V1 "Web yedeği").
bool videoDuzenlenebilir() => videoMotoru() != null;

void _uyar(ScaffoldMessengerState mesajci, String metin) => mesajci
  ..clearSnackBars()
  ..showSnackBar(SnackBar(content: Text(metin)));

/// Trim ekranını açar; kullanıcının kırpma KARARINI döner.
///
/// `null` dönüşün üç anlamı var, üçü de çağıran için aynı: **olduğu gibi
/// yükle**.
/// 1. Kullanıcı vazgeçti (X / geri).
/// 2. Hiçbir şey değiştirmeden "Tamam"a bastı.
/// 3. Platform desteklemiyor ya da video okunamadı (ikincisinde SnackBar var).
Future<VideoKirpma?> videoDuzenle(
  BuildContext context,
  XFile kaynak, {
  VideoKirpma? mevcut,
  Duration azami = videoAzamiKirpmaSuresi,
}) async {
  final isleyici = videoMotoru();
  if (isleyici == null) return null;

  final mesajci = ScaffoldMessenger.of(context);
  final bayt = await isleyici.boyut(kaynak.path);
  if (bayt > videoAzamiGirdiBayt) {
    _uyar(mesajci, 'Video çok büyük'.c);
    return null;
  }
  final bilgi = await isleyici.bilgi(kaynak.path);
  if (bilgi == null || bilgi.sure <= Duration.zero) {
    _uyar(mesajci, 'Video açılamadı'.c);
    return null;
  }
  if (bilgi.sure > videoAzamiGirdiSure) {
    _uyar(mesajci, 'Video çok büyük'.c);
    return null;
  }
  if (!context.mounted) return null;

  return Navigator.of(context, rootNavigator: true).push<VideoKirpma?>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => VideoDuzenleEkrani(
        kaynak: kaynak,
        isleyici: isleyici,
        bilgi: bilgi,
        mevcut: mevcut,
        azami: azami,
      ),
    ),
  );
}

/// Videoyu YÜKLEMEYE hazırlar: gerekiyorsa kırpar ve/veya sıkıştırır.
///
/// Dönüş:
/// * **aynı [kaynak]** → iş yoktu, bugünkü akış hızında geçildi;
/// * **yeni [XFile]** → geçici dizindeki işlenmiş MP4;
/// * **`null`** → kullanıcı İPTAL etti ya da düzeltilemez bir hata oldu
///   (hata SnackBar ile söylendi). Çağıran bu dosyayı YÜKLEMEMELİ.
///
/// OTOMATİK SIKIŞTIRMA GÖRÜNMEZDİR: kullanıcı hiçbir düğmeye basmaz, yalnız
/// yüklemesi hızlanır. Sıkıştırmanın tek gerekçesi yükleme boyutudur.
///
/// TETİK İKİ KAPILIDIR (13 Ağu 2026'da ikincisi eklendi, madde 35a):
/// 1. Ucuz ön eleme — dosya [videoSikistirmaEsigiBayt]'ı aşmıyorsa üst veri
///    bile okunmaz.
/// 2. [videoSikistirmaKarari] — kaynağın BİT HIZI hedefin altındaysa
///    sıkıştırma dosyayı küçültemez, yalnız kaliteyi düşürür; bu durumda
///    video hiç işlenmez. Eski kod bu kapıyı taşımıyordu ve 33,6 MB'lık
///    1080p bir kaynağı 40,9 MB'lık 720p'ye çeviriyordu (ölçüm:
///    `video_islem_ortak.dart:videoKazancEsigi`).
Future<XFile?> videoHazirla(
  BuildContext context,
  XFile kaynak, {
  VideoKirpma? kirpma,
}) async {
  final isleyici = videoMotoru();
  // Web: cihazda kodlayıcı yok → bugünkü davranış birebir korunur.
  if (isleyici == null) return kaynak;

  final mesajci = ScaffoldMessenger.of(context);
  final girdiBayt = await isleyici.boyut(kaynak.path);

  // OOM/süre kalkanı: bu boyutun üstünü hiç denemiyoruz. Sessiz çökme yerine
  // açık mesaj (MEDYA-EDITOR-PLANI §V1 risk: "Bellek / OOM").
  if (girdiBayt > videoAzamiGirdiBayt) {
    _uyar(mesajci, 'Video çok büyük'.c);
    return null;
  }

  // 1. KAPI (ucuz): küçük ve kırpılmamış video için üst veri bile okunmaz.
  if (kirpma == null && girdiBayt <= videoSikistirmaEsigiBayt) return kaynak;

  var karar = VideoSikistirmaKarari.yok;
  var tahminSure = Duration.zero;
  final bilgi = await isleyici.bilgi(kaynak.path);
  if (bilgi != null) {
    if (bilgi.sure > videoAzamiGirdiSure) {
      _uyar(mesajci, 'Video çok büyük'.c);
      return null;
    }
    karar = videoSikistirmaKarari(
      girdiBayt: girdiBayt,
      sure: bilgi.sure,
      genislik: bilgi.genislik,
      yukseklik: bilgi.yukseklik,
    );
    // Kaba tahmin: yeniden kodlama gerçek zamanın ~0,5 katı (MEDYA-EDITOR-
    // PLANI §6.1). Yalnız "Bu biraz sürebilir" satırını göstermeye yarar.
    final islenen = kirpma?.uzunluk ?? bilgi.sure;
    tahminSure = Duration(milliseconds: islenen.inMilliseconds ~/ 2);
  } else if (girdiBayt > videoSikistirmaEsigiBayt) {
    // Üst veri okunamadı ama dosya büyük: kararı süre olmadan da alalım
    // (fonksiyon bu hâli biliyor ve ölçek vermeden yalnız tavan koyuyor).
    karar = videoSikistirmaKarari(
      girdiBayt: girdiBayt,
      sure: Duration.zero,
      genislik: 0,
      yukseklik: 0,
    );
  }

  // 2. KAPI: sıkıştırma kazanç getirmiyorsa ve kırpma da istenmediyse
  // kullanıcının dosyasına DOKUNMUYORUZ. Bozmadan bırakmak en iyi sonuçtur.
  if (kirpma == null && !karar.sikistir) return kaynak;

  final hedef = await isleyici.geciciYol('mp4');
  final gorev = 'dizijpg-video-${DateTime.now().microsecondsSinceEpoch}';
  if (!context.mounted) {
    await isleyici.sil(hedef);
    return null;
  }

  final sonuc = await showDialog<_IsSonuc>(
    context: context,
    // Yanlışlıkla dışarı dokunup işi yarıda bırakmak YOK; çıkış yolu tek ve
    // görünür: İptal düğmesi.
    barrierDismissible: false,
    builder: (_) => _IsleniyorKutusu(
      isleyici: isleyici,
      gorev: gorev,
      uzunSurebilir: tahminSure > videoUzunIsEsigi,
      calistir: () => isleyici.isle(
        gorevKimlik: gorev,
        kaynak: kaynak.path,
        hedef: hedef,
        bas: kirpma?.bas,
        bit: kirpma?.bit,
        ses: !(kirpma?.sessiz ?? false),
        olcek: karar.olcek,
        bitHizi: karar.bitHizi,
      ),
    ),
  );

  // İPTAL → geçici dosya TEMİZLENİR. Yarım yazılmış bir MP4 cihazın önbellek
  // dizininde kalırsa kullanıcı onu asla göremez ama yerini işgal eder.
  if (sonuc == null || sonuc.iptal) {
    await isleyici.sil(hedef);
    return null;
  }
  final yol = sonuc.yol;
  if (yol == null) {
    await isleyici.sil(hedef);
    return _yedegeDus(mesajci, kaynak, kirpma, girdiBayt);
  }

  // ÇIKTI SÖZLEŞMESİ — VARSAYIM YOK, KONTROL VAR.
  // Sunucu türü sihirli baytla belirliyor ve SES'i VİDEO'dan ÖNCE deniyor
  // (`server.js:3179`): `ftyp` + `M4A` markalı bir çıktı orada `.m4a` olur ve
  // uygulama onu ses sanır. Bu yüzden çıktının ilk baytları burada
  // `videoTuru` ile doğrulanır.
  final bas = await isleyici.basBaytlar(yol);
  final ciktiBayt = await isleyici.boyut(yol);
  if (videoTuru(bas) != VideoTur.mp4 ||
      ciktiBayt <= 0 ||
      ciktiBayt > videoAzamiBayt) {
    await isleyici.sil(yol);
    return _yedegeDus(mesajci, kaynak, kirpma, girdiBayt);
  }

  return XFile(
    yol,
    mimeType: 'video/mp4',
    name: 'duzenlendi.mp4',
    length: ciktiBayt,
  );
}

/// İşlem başarısızsa ne yapmalı?
///
/// * Kullanıcı KIRPMA istediyse → orijinali yüklemek onun kararını çöpe atar
///   (kesilen bölüm sunucuya gider). Hata söylenir, yükleme yapılmaz.
/// * Yalnız GÖRÜNMEZ sıkıştırma denendiyse → kullanıcının böyle bir isteği
///   yoktu; orijinal sunucu sınırına sığıyorsa sessizce onunla devam edilir.
///   Görünmez bir iyileştirmenin başarısızlığı yüklemeyi engellememeli.
XFile? _yedegeDus(
  ScaffoldMessengerState mesajci,
  XFile kaynak,
  VideoKirpma? kirpma,
  int girdiBayt,
) {
  if (kirpma == null && girdiBayt > 0 && girdiBayt <= videoAzamiBayt) {
    return kaynak;
  }
  _uyar(mesajci, 'Video hazırlanamadı'.c);
  return null;
}

/// İşlemin sonucu: yol geldiyse başarı, [iptal] ise kullanıcı durdurdu,
/// ikisi de yoksa hata.
class _IsSonuc {
  final String? yol;
  final bool iptal;
  const _IsSonuc({this.yol, this.iptal = false});
}

/// "Hazırlanıyor %38 [İptal]" kutusu.
///
/// ui-ux-pro-max bulguları:
/// * Feedback/Progress Indicators (MEDIUM) — "Show progress for multi-step
///   processes… no indication of progress" anti-deseni. Yüzde METİN olarak da
///   yazılır: çubuk tek gösterge değildir.
/// * Async/Handle loading and error states (HIGH, flutter) — üç hâl de var:
///   yükleniyor (çubuk), başarı (kutu kapanır, karo görünür), hata (SnackBar).
/// * Touch/Touch Target Size (HIGH) — İptal düğmesi 44 dp yüksekliğinde.
class _IsleniyorKutusu extends StatefulWidget {
  final VideoIsleyici isleyici;
  final String gorev;
  final bool uzunSurebilir;
  final Future<String?> Function() calistir;

  const _IsleniyorKutusu({
    required this.isleyici,
    required this.gorev,
    required this.uzunSurebilir,
    required this.calistir,
  });

  @override
  State<_IsleniyorKutusu> createState() => _IsleniyorKutusuState();
}

class _IsleniyorKutusuState extends State<_IsleniyorKutusu> {
  StreamSubscription<double>? _abone;
  double _oran = 0;
  bool _iptalEdiliyor = false;

  @override
  void initState() {
    super.initState();
    _abone = widget.isleyici.ilerleme(widget.gorev).listen((o) {
      if (!mounted) return;
      // Geriye akan/■taşan değer gelmesin: çubuk asla geri gitmemeli.
      final y = o.clamp(0.0, 1.0);
      if (y > _oran) setState(() => _oran = y);
    }, onError: (_) {});
    _basla();
  }

  Future<void> _basla() async {
    String? yol;
    var hata = false;
    try {
      yol = await widget.calistir();
    } catch (_) {
      hata = true;
    }
    if (!mounted) return;
    // `isle` null döndüyse iş İPTAL edilmiştir (paket
    // `RenderCanceledException` fırlatır, motor onu null'a çevirir).
    Navigator.of(context).pop(
      hata
          ? const _IsSonuc()
          : _IsSonuc(yol: yol, iptal: yol == null && _iptalEdiliyor),
    );
  }

  @override
  void dispose() {
    // Abonelik dispose'da kapatılır (ui-ux-pro-max flutter/Async: "Cancel
    // subscriptions… memory leaks", severity HIGH).
    _abone?.cancel();
    super.dispose();
  }

  Future<void> _iptal() async {
    if (_iptalEdiliyor) return;
    setState(() => _iptalEdiliyor = true);
    await widget.isleyici.iptal(widget.gorev);
  }

  @override
  Widget build(BuildContext context) {
    final yuzde = (_oran * 100).round();
    // Sistem geri jesti kutuyu kapatıp işi arkada çalışır bırakmasın.
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: DiziRenkler.kart,
        title: Text(
          'Hazırlanıyor…'.c,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                // İlk yüzde gelene kadar belirsiz çubuk: "0%"da donmuş
                // görünen bir çubuk kullanıcıya iş yürümüyor dedirtir.
                value: _oran > 0 ? _oran : null,
                minHeight: 6,
                backgroundColor: DiziRenkler.metin12,
                color: DiziRenkler.sari,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _iptalEdiliyor ? 'İptal ediliyor…'.c : '%$yuzde',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: DiziRenkler.metin70,
              ),
            ),
            if (widget.uzunSurebilir && !_iptalEdiliyor) ...[
              const SizedBox(height: 6),
              Text(
                'Bu biraz sürebilir'.c,
                style: TextStyle(fontSize: 12, color: DiziRenkler.metin54),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _iptalEdiliyor ? null : _iptal,
            style: TextButton.styleFrom(
              minimumSize: const Size(88, 44),
              foregroundColor: DiziRenkler.sariMetin,
              disabledForegroundColor: DiziRenkler.metin38,
            ),
            child: Text('İptal'.c),
          ),
        ],
      ),
    );
  }
}

/// Şerit yüksekliği (küçük resimler).
const _seritBoy = 56.0;

/// Tutamağın GÖRÜNEN genişliği.
const _tutamakEn = 16.0;

/// Tutamağın DOKUNMA yarıçapı. 22+22 = 44 dp (ui-ux-pro-max, Touch/Touch
/// Target Size — severity HIGH). Şerit bu kadar içeriden başlar ki tutamağın
/// dokunma kutusu Stack'in DIŞINA taşmasın: taşan `Positioned` görünse bile
/// TIKLANMAZ ve bu tuzağa bu projede daha önce düşüldü (UX kontrol §2).
const _tutamakYari = 22.0;

/// Trim ekranı. [isleyici] ve [bilgi] enjekte edilir: hiçbir test gerçek
/// Media3'e bağlı değildir.
class VideoDuzenleEkrani extends StatefulWidget {
  final XFile kaynak;
  final VideoIsleyici isleyici;
  final VideoBilgi bilgi;
  final VideoKirpma? mevcut;
  final Duration azami;

  const VideoDuzenleEkrani({
    super.key,
    required this.kaynak,
    required this.isleyici,
    required this.bilgi,
    required this.azami,
    this.mevcut,
  });

  @override
  State<VideoDuzenleEkrani> createState() => _VideoDuzenleEkraniState();
}

class _VideoDuzenleEkraniState extends State<VideoDuzenleEkrani> {
  late Duration _bas;
  late Duration _bit;
  late bool _sessiz;

  List<Uint8List> _kareler = const [];
  VideoPlayerController? _oynatici;
  bool _oynuyor = false;

  /// Sınır kırmızıya döndü mü (kullanıcı [widget.azami]'yi zorladı).
  bool _sinirda = false;

  Duration get _toplam => widget.bilgi.sure;

  @override
  void initState() {
    super.initState();
    _bas = widget.mevcut?.bas ?? Duration.zero;
    // Kaynak sınırdan uzunsa pencere baştan KIRPILMIŞ açılır: kullanıcı
    // önce 3 dakika seçip sonra "olmaz" cevabı almasın.
    _bit =
        widget.mevcut?.bit ?? (_toplam > widget.azami ? widget.azami : _toplam);
    _sessiz = widget.mevcut?.sessiz ?? false;
    _kareleriYukle();
    _oynaticiHazirla();
  }

  @override
  void dispose() {
    _oynatici?.removeListener(_oynaticiDinle);
    _oynatici?.dispose();
    super.dispose();
  }

  Future<void> _kareleriYukle() async {
    final k = await widget.isleyici.kareler(
      widget.kaynak.path,
      adet: 10,
      bas: Duration.zero,
      bit: _toplam,
    );
    if (!mounted || k.isEmpty) return;
    setState(() => _kareler = k);
  }

  /// Önizleme oynatıcısı BEST-EFFORT: kurulamazsa ekran kare şeridiyle
  /// çalışmaya devam eder (kırpma yine yapılabilir). Sessiz başarısızlık
  /// değil — kullanıcı oynat düğmesinin yerine düz kareyi görür.
  Future<void> _oynaticiHazirla() async {
    VideoPlayerController? d;
    try {
      d = yerelVideo(widget.kaynak.path);
      if (d == null) return;
      await d.initialize();
      if (!mounted) {
        await d.dispose();
        return;
      }
      await d.setVolume(_sessiz ? 0 : 1);
      await d.seekTo(_bas);
      d.addListener(_oynaticiDinle);
      setState(() => _oynatici = d);
    } catch (_) {
      await d?.dispose();
    }
  }

  /// Oynatma seçili aralıkta DÖNGÜYE alınır: kullanıcı tam olarak
  /// göndereceği kesiti izler, kesilen bölümü değil.
  void _oynaticiDinle() {
    final d = _oynatici;
    if (d == null || !d.value.isInitialized) return;
    if (d.value.isPlaying && d.value.position >= _bit) {
      d.seekTo(_bas);
    }
    if (d.value.isPlaying != _oynuyor && mounted) {
      setState(() => _oynuyor = d.value.isPlaying);
    }
  }

  Future<void> _oynatDuraklat() async {
    final d = _oynatici;
    if (d == null || !d.value.isInitialized) return;
    if (d.value.isPlaying) {
      await d.pause();
    } else {
      if (d.value.position < _bas || d.value.position >= _bit) {
        await d.seekTo(_bas);
      }
      await d.play();
    }
    if (mounted) setState(() => _oynuyor = d.value.isPlaying);
  }

  void _sesDegistir() {
    setState(() => _sessiz = !_sessiz);
    _oynatici?.setVolume(_sessiz ? 0 : 1);
  }

  /// Tutamak sürüklemesi. Sınırlar burada TEK yerde uygulanır:
  /// * aralık [videoAsgariKirpmaSuresi]'nin altına inemez,
  /// * aralık [widget.azami]'yi aşamaz (aşmaya çalışınca karşı tutamak
  ///   birlikte kayar ve süre etiketi kırmızıya döner).
  void _tutamak(bool baslangic, Duration yeni) {
    setState(() {
      _sinirda = false;
      if (baslangic) {
        var b = yeni;
        if (b < Duration.zero) b = Duration.zero;
        if (b > _bit - videoAsgariKirpmaSuresi) {
          b = _bit - videoAsgariKirpmaSuresi;
        }
        _bas = b;
        if (_bit - _bas > widget.azami) {
          _bit = _bas + widget.azami;
          _sinirda = true;
        }
      } else {
        var s = yeni;
        if (s > _toplam) s = _toplam;
        if (s < _bas + videoAsgariKirpmaSuresi) {
          s = _bas + videoAsgariKirpmaSuresi;
        }
        _bit = s;
        if (_bit - _bas > widget.azami) {
          _bas = _bit - widget.azami;
          _sinirda = true;
        }
      }
    });
    final d = _oynatici;
    if (d != null && d.value.isInitialized) {
      d.seekTo(baslangic ? _bas : _bit);
    }
  }

  /// "Tamam". Hiçbir şey değişmediyse `null` döner = "olduğu gibi yükle"
  /// (`gorselDuzenle` ile aynı sözleşme: değişmemiş çıktıyı "düzenlendi"
  /// diye işaretlemek yalan olur).
  void _bitir() {
    final degisti = _bas > Duration.zero || _bit < _toplam || _sessiz;
    Navigator.of(
      context,
    ).pop(degisti ? VideoKirpma(bas: _bas, bit: _bit, sessiz: _sessiz) : null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Kapat'.c,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: TextButton(
              onPressed: _bitir,
              style: TextButton.styleFrom(
                // ≥44 dp dokunma hedefi.
                minimumSize: const Size(64, 44),
                foregroundColor: DiziRenkler.sariMetin,
              ),
              child: Text(
                'Tamam'.c,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _onizleme()),
          _bilgiSatiri(),
          KirpmaSeridi(
            kareler: _kareler,
            toplam: _toplam,
            bas: _bas,
            bit: _bit,
            tutamak: _tutamak,
          ),
          // Alt tutamaklar sistem gezinme çubuğunun ALTINDA kalmasın:
          // `gorsel_kirp.dart:78-87`'de bizzat sahada bulunmuş hata.
          SizedBox(height: altGuvenli(context, ekstra: 8)),
        ],
      ),
    );
  }

  Widget _onizleme() {
    final d = _oynatici;
    final hazir = d != null && d.value.isInitialized;
    return ColoredBox(
      color: DiziRenkler.markaKoyu,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hazir)
            Center(
              child: AspectRatio(
                aspectRatio: d.value.aspectRatio,
                child: VideoPlayer(d),
              ),
            )
          else if (_kareler.isNotEmpty)
            Image.memory(_kareler.first, fit: BoxFit.contain)
          else
            Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: DiziRenkler.sari,
                ),
              ),
            ),
          if (hazir)
            Center(
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _oynatDuraklat,
                  child: Padding(
                    // 22 ikon + 2×11 dolgu = 44 dp.
                    padding: const EdgeInsets.all(11),
                    child: Semantics(
                      button: true,
                      label: _oynuyor ? 'Duraklat'.c : 'Oynat'.c,
                      child: Icon(
                        _oynuyor ? Icons.pause : Icons.play_arrow,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bilgiSatiri() {
    final uzunluk = _bit - _bas;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${videoSureMetni(_bas)} — ${videoSureMetni(_bit)}'
                  '  ·  ${videoSureMetni(uzunluk)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: DiziRenkler.metin,
                  ),
                ),
                // Sınır uyarısı METİNLE söylenir; renk tek gösterge değil
                // (ui-ux-pro-max, Accessibility/Color Only — HIGH).
                if (_sinirda)
                  Text(
                    'En çok {} saniye seçebilirsin'.cf([
                      widget.azami.inSeconds,
                    ]),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE5484D),
                    ),
                  ),
              ],
            ),
          ),
          _SesDugmesi(sessiz: _sessiz, bas: _sesDegistir),
        ],
      ),
    );
  }
}

/// "Sesi kapat / Sesi aç" düğmesi. İkon + metin birlikte: ikon tek başına
/// (çizgili hoparlör) küçük ekranda ayırt edilmiyor.
class _SesDugmesi extends StatelessWidget {
  final bool sessiz;
  final VoidCallback bas;
  const _SesDugmesi({required this.sessiz, required this.bas});

  @override
  Widget build(BuildContext context) {
    final etiket = sessiz ? 'Sesi aç'.c : 'Sesi kapat'.c;
    return Semantics(
      button: true,
      toggled: sessiz,
      label: etiket,
      child: TextButton.icon(
        onPressed: bas,
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 44),
          foregroundColor: sessiz ? DiziRenkler.sariMetin : DiziRenkler.metin70,
        ),
        icon: Icon(sessiz ? Icons.volume_off : Icons.volume_up, size: 20),
        label: Text(
          etiket,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Kare şeridi + iki tutamak.
///
/// Ayrı ve PUBLIC bir widget: ergonomi (44 dp tutamak, sınır davranışı)
/// ekranın tamamını ayağa kaldırmadan test edilebilsin.
class KirpmaSeridi extends StatelessWidget {
  final List<Uint8List> kareler;
  final Duration toplam;
  final Duration bas;
  final Duration bit;

  /// `(baslangicMi, yeniDeger)`
  final void Function(bool, Duration) tutamak;

  const KirpmaSeridi({
    super.key,
    required this.kareler,
    required this.toplam,
    required this.bas,
    required this.bit,
    required this.tutamak,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _seritBoy + 16,
      child: LayoutBuilder(
        builder: (context, kutu) {
          // Film alanı iki yandan tutamak yarıçapı kadar içeride: tutamağın
          // 44 dp'lik dokunma kutusu her zaman Stack'in İÇİNDE kalır.
          final filmEn = math.max(1.0, kutu.maxWidth - 2 * _tutamakYari);
          final us = toplam.inMicroseconds <= 0 ? 1 : toplam.inMicroseconds;
          double x(Duration d) =>
              _tutamakYari + filmEn * (d.inMicroseconds / us);
          Duration t(double px) => Duration(
            microseconds: (((px - _tutamakYari) / filmEn) * us).round(),
          );

          return Stack(
            children: [
              Positioned(
                left: _tutamakYari,
                top: 8,
                width: filmEn,
                height: _seritBoy,
                child: _film(),
              ),
              // Seçim DIŞI bölge karartılır: ne gideceği ne kalacağı tek
              // bakışta okunur (renk tek gösterge değil — tutamaklar da var).
              Positioned(
                left: _tutamakYari,
                top: 8,
                width: math.max(0, x(bas) - _tutamakYari),
                height: _seritBoy,
                child: const IgnorePointer(
                  child: ColoredBox(color: Colors.black54),
                ),
              ),
              Positioned(
                left: x(bit),
                top: 8,
                width: math.max(0, _tutamakYari + filmEn - x(bit)),
                height: _seritBoy,
                child: const IgnorePointer(
                  child: ColoredBox(color: Colors.black54),
                ),
              ),
              _Tutamak(
                key: const ValueKey('kirpma-bas'),
                merkez: x(bas),
                baslangic: true,
                surukle: (px) => tutamak(true, t(px)),
              ),
              _Tutamak(
                key: const ValueKey('kirpma-bit'),
                merkez: x(bit),
                baslangic: false,
                surukle: (px) => tutamak(false, t(px)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _film() {
    if (kareler.isEmpty) {
      // Kare çıkarılamadıysa düz bant: tutamaklar yine çalışır, ekran boş
      // görünmez (CLS = 0, yükseklik zaten ayrılmış).
      return ColoredBox(color: DiziRenkler.kart);
    }
    return Row(
      children: [
        for (final k in kareler)
          Expanded(
            child: Image.memory(
              k,
              fit: BoxFit.cover,
              height: _seritBoy,
              gaplessPlayback: true,
            ),
          ),
      ],
    );
  }
}

/// Tek tutamak: 16 dp görünen sarı bar, 44 dp görünmez dokunma kutusu.
///
/// SÜRÜKLEME MUTLAK KONUM BİLDİRİR, delta değil. Delta biriktirmeyi çağırana
/// bırakmak, jestin İKİ ardışık `onUpdate`i arasında yeniden çizim olmadığında
/// (Flutter işaretçi olaylarını tek karede toplayabilir) ikinci deltanın
/// ESKİ konuma uygulanması demekti: parmak 100 px gidiyor, tutamak 40 px
/// oynuyordu. Başlangıç konumu jestin başında bir kez okunuyor, üstüne
/// delta ekleniyor — yeniden çizim zamanlamasından bağımsız.
class _Tutamak extends StatefulWidget {
  final double merkez;
  final bool baslangic;

  /// Şeridin sol kenarına göre YENİ merkez (piksel).
  final void Function(double px) surukle;

  const _Tutamak({
    super.key,
    required this.merkez,
    required this.baslangic,
    required this.surukle,
  });

  @override
  State<_Tutamak> createState() => _TutamakState();
}

class _TutamakState extends State<_Tutamak> {
  double? _x;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.merkez - _tutamakYari,
      top: 0,
      width: _tutamakYari * 2,
      height: _seritBoy + 16,
      child: Semantics(
        slider: true,
        label: widget.baslangic ? 'Başlangıç'.c : 'Bitiş'.c,
        child: GestureDetector(
          // Görünmez alan da dokunuş yakalasın.
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _x = widget.merkez,
          onHorizontalDragUpdate: (d) {
            final yeni = (_x ?? widget.merkez) + d.delta.dx;
            _x = yeni;
            widget.surukle(yeni);
          },
          onHorizontalDragEnd: (_) => _x = null,
          onHorizontalDragCancel: () => _x = null,
          child: Center(
            child: Container(
              width: _tutamakEn,
              height: _seritBoy + 8,
              decoration: BoxDecoration(
                color: DiziRenkler.sari,
                borderRadius: BorderRadius.circular(4),
              ),
              // Sarı zeminde siyah glif ≈ 11:1 (WCAG AAA). Tutamağın
              // sürüklenebilir olduğunu çizgiler söyler.
              child: const Icon(
                Icons.drag_indicator,
                size: 14,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
