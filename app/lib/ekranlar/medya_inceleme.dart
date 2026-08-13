import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../ceviri.dart';
import '../foto_secici.dart';
import '../tema.dart';
import '../video_islem.dart';
import '../yerel_gorsel.dart';
import '../yerel_video.dart';
import 'gorsel_duzenle.dart';
import 'ortak.dart';
import 'video_duzenle.dart';

/// Medya ekleme akışı: **sistem seçici → bizim inceleme ekranımız**.
///
/// TARİHÇE (neden uygulama içi ızgara GİTTİ): 6-7 Ağu 2026'da Instagram tarzı
/// bir uygulama içi galeri ızgarası yazıldı (`photo_manager`). O ekran
/// `READ_MEDIA_IMAGES` + `READ_MEDIA_VIDEO` istiyordu; Play Console AAB'yi
/// **reddetti**: "Fotoğraf ve video izinlerine erişmek isteyen tüm
/// geliştiricilerin, Google Play'i uygulamalarının temel işlevi hakkında
/// bilgilendirmeleri gerekir." Google geniş medya erişimini yalnız temel
/// işlevi bu olan uygulamalara (galeri/yedekleme/foto düzenleyici) veriyor;
/// "ara sıra medya ekleyen" uygulamaları Android Fotoğraf Seçici'ye
/// yönlendiriyor. Karar: seçim SİSTEME devredildi, izinler kaldırıldı.
///
/// KORUNAN KISIM: seçimden SONRAKİ deneyim aynen duruyor — büyük önizleme
/// (video oynatılabilir), altta seçilenlerin şeridi (kaldırma çarpısı +
/// "daha fazla ekle"), görselde KALEM (editör), videoda MAKAS (trim), sağ
/// üstte "İleri". Emek çöpe gitmedi, yalnız kaynağı değişti.
///
/// TEK GİRİŞ NOKTASI: [medyaSec]. `yorumlar.dart` bunu çağırır; ileride
/// sohbet eki / Reels yanıtı da aynı çağrıyı kullanabilir.

/// Şeridin yüksekliği. SABİT: şerit ilk kareden itibaren yer kaplar, seçim
/// boşalınca da ayakta kalır — önizleme ASLA zıplamaz (ui-ux-pro-max,
/// Layout/Content Jumping: HIGH "Reserve space for async content"; CLS).
const _seritBoy = 84.0;

/// Şerit karesinin AYRILAN genişliği (küçük resim 60 dp + çarpı payı).
/// Değeri neden 78: bkz. [_SeritKaresi].
const _kareBoy = 78.0;

/// Tür tanıması için okunan bayt sayısı. `gorselTuru`/`videoTuru` en çok
/// 12 bayta bakıyor; 16 rahat bir üst sınır.
const _tanimaBaytSayisi = 16;

/// Testler için: sistem seçicisi yedeği. `null` = gerçek seçiciyi aç.
///
/// Widget testinde gerçek `ImagePicker` platform kanalına gider; bu kanca
/// sayesinde hiçbir test cihaz seçicisine bağlı değildir.
@visibleForTesting
Future<List<XFile>> Function(int azami)? sistemSeciciSahte;

/// Testler için: [fotoSeciciyiAc] çağrısını gözlemler/atlar.
@visibleForTesting
bool Function()? fotoSeciciAcSahte;

/// Sistem seçicisini açar ve seçilen dosyaları döner (vazgeçilirse boş liste).
///
/// ANDROID: [fotoSeciciyiAc] `useAndroidPhotoPicker = true` yapar, böylece
/// `pickMultipleMedia` `ActivityResultContracts.PickMultipleVisualMedia`
/// (= `ACTION_PICK_IMAGES`, Android Fotoğraf Seçici) intent'ini kurar.
/// Bayrak açılmazsa paket `ACTION_GET_CONTENT`e düşer — bkz. `foto_secici.dart`.
///
/// `limit: 1` paketin kendisi tarafından `pickMedia()`ya devredilir
/// (`image_picker-1.2.3/lib/image_picker.dart:267`), ayrı bir dal gerekmez.
Future<List<XFile>> sistemSecici(int azami) {
  if (sistemSeciciSahte != null) return sistemSeciciSahte!(azami);
  (fotoSeciciAcSahte ?? fotoSeciciyiAc)();
  return ImagePicker().pickMultipleMedia(limit: azami < 1 ? 1 : azami);
}

/// Kullanıcıya medya seçtirir ve **inceleme ekranından geçirip** döner.
///
/// * Vazgeçilirse (seçici kapatılırsa ya da incelemede X'e basılırsa) `[]`.
/// * Dönen [XFile]lar mevcut yükleme hattına DEĞİŞMEDEN girer
///   (`readAsBytes()` → `Api.medyaYukle`); sunucuda hiçbir değişiklik yok.
Future<List<XFile>> medyaSec(BuildContext context, {int azami = 10}) async {
  final secim = await sistemSecici(azami);
  if (secim.isEmpty || !context.mounted) return const [];
  final sonuc = await Navigator.of(context, rootNavigator: true)
      .push<List<XFile>>(
        MaterialPageRoute(
          builder: (_) => MedyaIncelemeEkrani(dosyalar: secim, azami: azami),
          fullscreenDialog: true,
        ),
      );
  return sonuc ?? const [];
}

/// Mikro etkileşim süresi. Kullanıcı "hareketi azalt" dediyse SIFIR döner.
///
/// ui-ux-pro-max: Animation/Reduced Motion (severity HIGH) ve Duration Timing
/// ("150-300ms for micro-interactions"). Bu ekranda keyfi süre yok.
Duration _sure(BuildContext c, int ms) => MediaQuery.disableAnimationsOf(c)
    ? Duration.zero
    : Duration(milliseconds: ms);

/// Seçilen bir dosyanın türü. **Sihirli bayttan** okunur, uzantıdan değil —
/// `server.js`in yaptığının aynısı (`gorselTuru` / `videoTuru`).
enum MedyaTur {
  /// Henüz ilk baytlar okunmadı.
  bekliyor,

  /// JPEG / PNG / WebP → KALEM (görsel editör).
  gorsel,

  /// GIF → düğme YOK: editör tuvali tek kare üretir, animasyon ölürdü
  /// (`gorsel_kirp.dart:gifMi` ile aynı kural).
  gif,

  /// MP4 / WebM → MAKAS (trim), yalnız [videoDuzenlenebilir] ise.
  video,

  /// Tanınmayan bayt. Düğme yok; dosya yine de yükleme hattına girer,
  /// son sözü sunucunun sihirli bayt kapısı söyler.
  diger,
}

/// İncelemedeki tek bir öğe. [kimlik] listedeki konumdan BAĞIMSIZDIR:
/// düzenleme/kırpma haritaları buna anahtarlanır, öğe kaldırılıp geri
/// eklenince emek kaybolmasın.
class _Ogem {
  final String kimlik;
  final XFile dosya;
  MedyaTur tur = MedyaTur.bekliyor;

  _Ogem(this.kimlik, this.dosya);
}

/// İnceleme ekranı. `Navigator.pop` ile **`List<XFile>`** döndürür;
/// vazgeçilirse `null` (çağıran onu `[]`e çevirir).
class MedyaIncelemeEkrani extends StatefulWidget {
  /// Sistem seçicisinden dönen dosyalar (en az bir tane).
  final List<XFile> dosyalar;

  /// En çok kaç öğe gönderilebilir ("daha fazla ekle" tavanı).
  final int azami;

  const MedyaIncelemeEkrani({
    super.key,
    required this.dosyalar,
    this.azami = 10,
  });

  @override
  State<MedyaIncelemeEkrani> createState() => _MedyaIncelemeEkraniState();
}

class _MedyaIncelemeEkraniState extends State<MedyaIncelemeEkrani> {
  final List<_Ogem> _liste = [];

  /// Önizlemede duran öğe. Kaldırma sonrası komşuya kayar.
  _Ogem? _odak;

  /// Düzenlenmiş görseller: öğe kimliği → düzenlenmiş JPEG baytları.
  ///
  /// NEDEN HARİTA: düzenleme LİSTEDEN bağımsız yaşar. Kullanıcı bir
  /// fotoğrafı düzenleyip şeritten çıkarır, sonra "daha fazla ekle" ile
  /// geri getirirse emeği durmaz.
  final Map<String, Uint8List> _duzenlenen = {};

  /// Kırpılan videolar: öğe kimliği → kullanıcının trim KARARI
  /// (MEDYA-EDITOR-PLANI §V1).
  ///
  /// NEDEN KARAR SAKLANIYOR, ÇIKTI DEĞİL: kodlama 20-60 sn sürebilir. Karar
  /// burada durur, tek kodlama "İleri"de (`videoHazirla`) ilerleme + iptal
  /// ile yapılır.
  final Map<String, VideoKirpma> _videoKirpma = {};

  /// Düzenleyici açılırken (tam çözünürlüklü dosya okunuyor) düğme kilitli +
  /// spinner. İki kez basıp iki editör açmayı da engeller.
  bool _duzenleAciliyor = false;

  /// "Daha fazla ekle" sistem seçicisi açık — çift açılmayı engeller.
  bool _ekleniyor = false;

  bool _onaylaniyor = false; // "İleri" → dosyalar hazırlanıyor
  int _hazirlanan = 0; // onay sırasında kaçıncı dosya (ilerleme göstergesi)
  int _sayac = 0; // kimlik üreteci

  @override
  void initState() {
    super.initState();
    _ekle(widget.dosyalar);
  }

  /// Dosyaları listeye katar ve tür tanımasını başlatır.
  ///
  /// TEKRAR ELEME: sistem seçicisi ikinci kez açıldığında kullanıcı aynı
  /// fotoğrafı yeniden seçebilir; aynı yolu iki kez göndermek sunucuya iki
  /// özdeş yükleme demektir.
  void _ekle(List<XFile> yeni) {
    final mevcut = _liste.map((o) => o.dosya.path).toSet();
    final eklenen = <_Ogem>[];
    var kontenjanAsildi = false;
    for (final d in yeni) {
      if (_liste.length + eklenen.length >= widget.azami) {
        kontenjanAsildi = true;
        break;
      }
      if (d.path.isNotEmpty && mevcut.contains(d.path)) continue;
      mevcut.add(d.path);
      eklenen.add(_Ogem('m${_sayac++}', d));
    }
    // SESSİZ KIRPMA YOK: sistem seçicisi limiti yok sayabiliyor (eski cihaz,
    // SAF yedeği). Kullanıcı 12 fotoğraf seçip 10'unu bulursa nedenini
    // bilmeli — üç hâl kuralı (yükleniyor/başarı/hata) burada da geçerli.
    if (kontenjanAsildi) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _uyar('En fazla {} medya seçebilirsin'.cf([widget.azami])),
      );
    }
    if (eklenen.isEmpty) return;
    setState(() {
      _liste.addAll(eklenen);
      _odak ??= _liste.first;
    });
    for (final o in eklenen) {
      _tani(o);
    }
  }

  /// İlk [_tanimaBaytSayisi] baytı okuyup türü belirler.
  ///
  /// UZANTIYA GÜVENİLMEZ: sistem seçicisi `.jpg` adlı bir HEIC ya da `.mp4`
  /// adlı bir m4a verebilir. Sunucu da içeriğe bakıyor; burada AYNI kural
  /// uygulanır ki kullanıcıya gösterdiğimiz düğme yalan olmasın.
  Future<void> _tani(_Ogem o) async {
    var tur = MedyaTur.diger;
    try {
      // SINIR ŞART: `XFile.fromData` için `openRead(0, n)` bir `sublist`e
      // dönüşüyor (`cross_file/src/types/io.dart:130`) ve dosya n bayttan
      // kısaysa RangeError atıyor. Uzunluğa göre kırpıyoruz.
      final boy = await o.dosya.length();
      final son = boy < _tanimaBaytSayisi ? boy : _tanimaBaytSayisi;
      final parcalar = await o.dosya
          .openRead(0, son)
          .fold<List<int>>(<int>[], (a, b) => a..addAll(b));
      final bas = Uint8List.fromList(parcalar);
      if (videoTuru(bas) != VideoTur.bilinmeyen) {
        tur = MedyaTur.video;
      } else if (gifBaytlari(bas)) {
        tur = MedyaTur.gif;
      } else if (duzenlenebilirMi(bas)) {
        tur = MedyaTur.gorsel;
      }
    } catch (_) {
      // Okunamadı → düğmesiz "diger". Dosya yine de yüklenmeyi dener.
    }
    if (!mounted) return;
    setState(() => o.tur = tur);
  }

  void _uyar(String mesaj) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(mesaj)));
  }

  /// Şeritten kaldırma. Odaktaki öğe kalkarsa önizleme komşuya kayar —
  /// kullanıcı boş kutuya bakmaz.
  void _cikar(int i) {
    setState(() {
      final silinen = _liste.removeAt(i);
      if (_odak == silinen) {
        _odak = _liste.isEmpty
            ? null
            : _liste[i >= _liste.length ? _liste.length - 1 : i];
      }
    });
  }

  /// "Daha fazla ekle": sistem seçicisini KALAN kontenjanla yeniden açar.
  Future<void> _dahaFazla() async {
    final kalan = widget.azami - _liste.length;
    if (kalan <= 0 || _ekleniyor) return;
    setState(() => _ekleniyor = true);
    try {
      final yeni = await sistemSecici(kalan);
      if (!mounted || yeni.isEmpty) return;
      _ekle(yeni);
    } catch (_) {
      _uyar('Medya seçilemedi'.c);
    } finally {
      if (mounted) setState(() => _ekleniyor = false);
    }
  }

  /// "Kalem": odaktaki fotoğrafı editöre sokar (MEDYA-EDITOR-PLANI §G1).
  ///
  /// İSTEĞE BAĞLI ADIM: bu düğmeye HİÇ dokunmayan kullanıcı için akış aynı
  /// hızda kalır. Zorunlu editör gönderi sayısını düşürür (§8).
  Future<void> _duzenleyiAc() async {
    final o = _odak;
    if (o == null || o.tur != MedyaTur.gorsel || _duzenleAciliyor) return;
    setState(() => _duzenleAciliyor = true);
    try {
      // Düzenlenmişi tekrar düzenlerken sıfırdan başlamayız: kullanıcı
      // çizimini kaybetmeden üstüne devam eder.
      final veri = _duzenlenen[o.kimlik] ?? await o.dosya.readAsBytes();
      if (!mounted) return;
      final yeni = await gorselDuzenle(context, veri);
      if (yeni == null || !mounted) return; // vazgeçti → ORİJİNAL korunur
      setState(() => _duzenlenen[o.kimlik] = yeni);
    } catch (_) {
      _uyar('Düzenlenemedi'.c);
    } finally {
      if (mounted) setState(() => _duzenleAciliyor = false);
    }
  }

  /// "Makas": odaktaki VİDEOYU trim ekranına sokar (MEDYA-EDITOR-PLANI §V1).
  ///
  /// Kalemle aynı üç kural: isteğe bağlı adım, üç hâl (boşta/meşgul/
  /// düzenlendi). Fark: burada hiçbir şey KODLANMAZ — yalnız karar alınır.
  Future<void> _videoDuzenleyiAc() async {
    final o = _odak;
    if (o == null || o.tur != MedyaTur.video || _duzenleAciliyor) return;
    setState(() => _duzenleAciliyor = true);
    try {
      final kirpma = await videoDuzenle(
        context,
        o.dosya,
        mevcut: _videoKirpma[o.kimlik],
      );
      if (kirpma == null || !mounted) return; // vazgeçti → ORİJİNAL korunur
      setState(() => _videoKirpma[o.kimlik] = kirpma);
    } catch (_) {
      _uyar('Video hazırlanamadı'.c);
    } finally {
      if (mounted) setState(() => _duzenleAciliyor = false);
    }
  }

  /// "İleri": listeyi yükleme hattına verilebilir dosyalara çevirip kapatır.
  ///
  /// KISMİ BAŞARI: bir dosya hazırlanamazsa sessizce düşürülmez — kaçının
  /// düştüğü SnackBar ile söylenir. Hiçbiri hazırlanamadıysa ekran KAPANMAZ.
  Future<void> _onayla() async {
    if (_liste.isEmpty || _onaylaniyor) return;
    setState(() {
      _onaylaniyor = true;
      _hazirlanan = 0;
    });
    final dosyalar = <XFile>[];
    for (final o in _liste) {
      try {
        // DÜZENLENMİŞ ÇIKTI MEVCUT HATTA DEĞİŞMEDEN GİRER: çağıranlar
        // `XFile.readAsBytes()` → `Api.medyaYukle` yapıyor; `XFile.fromData`
        // bunu web'de de karşılar (MEDYA-EDITOR-PLANI G1-not).
        final duzenli = _duzenlenen[o.kimlik];
        if (duzenli != null) {
          // TÜR SABİT DEĞİL (madde 54): editör saydam girdide PNG üretiyor.
          // Adı/MIME'ı "jpg" diye yazmak dosyayı bozmaz (sunucu sihirli
          // bayta bakıyor, `Api.medyaYukle` da octet-stream gönderiyor) ama
          // yalan olur; tür baytlardan okunuyor.
          final png = gorselTuru(duzenli) == GorselTur.png;
          dosyalar.add(
            XFile.fromData(
              duzenli,
              mimeType: png ? 'image/png' : 'image/jpeg',
              name: 'duzenlendi-${o.kimlik}.${png ? 'png' : 'jpg'}',
              length: duzenli.length,
            ),
          );
        } else if (o.tur != MedyaTur.video) {
          dosyalar.add(o.dosya);
        } else {
          // VİDEO HATTI (§V1): kırpma varsa uygulanır, yoksa da 20 MB'ı
          // aşan video sessizce sıkıştırılır. İlerleme + İptal içeride.
          if (!mounted) return;
          final hazir = await videoHazirla(
            context,
            o.dosya,
            kirpma: _videoKirpma[o.kimlik],
          );
          // İPTAL ya da düzeltilemez hata → tüm "İleri" durur. Kullanıcı
          // iptal ettiği videoyu yine de yüklenmiş bulmasın.
          if (hazir == null) {
            if (!mounted) return;
            setState(() => _onaylaniyor = false);
            return;
          }
          dosyalar.add(hazir);
        }
      } catch (_) {
        // yut: aşağıda sayıya bakıp kullanıcıya topluca bildiriyoruz
      }
      if (!mounted) return;
      setState(() => _hazirlanan++);
    }
    if (!mounted) return;
    if (dosyalar.isEmpty) {
      setState(() => _onaylaniyor = false);
      _uyar('Seçilen dosya okunamadı'.c);
      return;
    }
    final eksik = _liste.length - dosyalar.length;
    // SnackBar uygulama düzeyindeki ScaffoldMessenger'da: pop sonrası görünür.
    if (eksik > 0) _uyar('{} dosya okunamadı'.cf([eksik]));
    Navigator.of(context).pop(dosyalar);
  }

  @override
  Widget build(BuildContext context) {
    // Zemin/ön plan renkleri TEMADAN gelir (appBarTheme zemin+metin veriyor):
    // ekran açık temada da doğru okunur, ton tek yerden yönetilir.
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          // 48 dp: IconButton varsayılan dokunma alanı.
          icon: const Icon(Icons.close),
          tooltip: 'Kapat'.c,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Medya ekle'.c,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [_ileriDugmesi()],
      ),
      // SafeArea YOK: şerit ekranın dibine kadar aksın; sistem gezinme
      // çubuğu altında kalmaması alttaki dolguyla çözülür (pro-rules,
      // Layout: "Scroll and fixed element coexistence").
      body: _liste.isEmpty ? _bosDurum() : _govde(),
    );
  }

  Widget _bosDurum() => BosDurum(
    ikon: Icons.photo_library_outlined,
    baslik: 'Seçili medya kalmadı'.c,
    ipucu: 'Yorumuna eklemek için fotoğraf veya video seç.'.c,
    aksiyon: FilledButton.icon(
      onPressed: _ekleniyor ? null : _dahaFazla,
      icon: const Icon(Icons.add_photo_alternate_outlined),
      label: Text('Medya seç'.c),
    ),
  );

  Widget _govde() => Column(
    children: [
      Expanded(
        // clipBehavior VARSAYILAN (hardEdge): düzenle düğmesi kutunun
        // İÇİNDE durur. Stack sınırının dışına taşan Positioned görünse
        // bile TIKLANAMAZ — bu projede daha önce yaşandı.
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                // Odak değişince sert kesme yerine yumuşak geçiş; süre
                // ui-ux-pro-max Duration Timing aralığında (150-300 ms),
                // giriş easeOut ("ease-out for entering").
                duration: _sure(context, 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _odak == null
                    ? ColoredBox(
                        key: const ValueKey('bos'),
                        color: DiziRenkler.markaKoyu,
                      )
                    : _Onizleme(
                        // Key: odak değişince oynatıcı sıfırlansın.
                        key: ValueKey(_odak!.kimlik),
                        ogem: _odak!,
                        duzenli: _duzenlenen[_odak!.kimlik],
                        hata: _uyar,
                      ),
              ),
            ),
            // GÖRSEL → kalem, VİDEO → makas, GIF/tanınmayan → HİÇBİRİ.
            //
            // Web'de video düğmesi HİÇ ÇİZİLMEZ ([videoDuzenlenebilir] orada
            // false): tarayıcıda kodlayıcı yok. Pasif gri bir düğme gösterip
            // "desteklenmiyor" demek daha kötü bir UX'tir (§V1 "Web yedeği").
            if (_odak?.tur == MedyaTur.gorsel)
              Positioned(
                top: 8,
                right: 8,
                child: _DuzenleDugmesi(
                  duzenli: _duzenlenen.containsKey(_odak!.kimlik),
                  mesgul: _duzenleAciliyor,
                  bas: _duzenleyiAc,
                ),
              ),
            if (_odak?.tur == MedyaTur.video && videoDuzenlenebilir())
              Positioned(
                top: 8,
                right: 8,
                child: _DuzenleDugmesi(
                  duzenli: _videoKirpma.containsKey(_odak!.kimlik),
                  mesgul: _duzenleAciliyor,
                  bas: _videoDuzenleyiAc,
                  video: true,
                ),
              ),
          ],
        ),
      ),
      _Serit(
        liste: _liste,
        azami: widget.azami,
        odak: _odak,
        duzenli: (o) =>
            _duzenlenen.containsKey(o.kimlik) ||
            _videoKirpma.containsKey(o.kimlik),
        cikar: _cikar,
        odakla: (o) => setState(() => _odak = o),
        ekle: _liste.length >= widget.azami ? null : _dahaFazla,
        ekleniyor: _ekleniyor,
      ),
      // Şerit sistem gezinme çubuğunun altında kalmasın.
      SizedBox(height: altGuvenli(context, ekstra: 0)),
    ],
  );

  Widget _ileriDugmesi() {
    final sayi = _liste.length;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton(
        onPressed: sayi == 0 || _onaylaniyor ? null : _onayla,
        style: TextButton.styleFrom(
          // ≥44 dp dokunma hedefi.
          minimumSize: const Size(64, 44),
          foregroundColor: DiziRenkler.sariMetin,
          disabledForegroundColor: DiziRenkler.metin38,
        ),
        child: _onaylaniyor
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: DiziRenkler.sariMetin,
                    ),
                  ),
                  // İlerleme göstergesi (ui-ux-pro-max, Feedback/Progress
                  // Indicators) — çok dosya hazırlanırken donmuş sanılmasın.
                  if (sayi > 1) ...[
                    const SizedBox(width: 8),
                    Text(
                      '$_hazirlanan/$sayi',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'İleri'.c,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (sayi > 1) ...[
                    const SizedBox(width: 6),
                    _SayiPulu(sayi: sayi),
                  ],
                ],
              ),
      ),
    );
  }
}

/// "İleri" yanındaki sayaç. Sayı METİN olarak okunur: gösterge yalnız renge
/// dayanmaz (ui-ux-pro-max, Accessibility/Color Only: HIGH).
class _SayiPulu extends StatelessWidget {
  final int sayi;
  const _SayiPulu({required this.sayi});

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: DiziRenkler.sari,
      shape: BoxShape.circle,
    ),
    child: Text(
      '$sayi',
      style: const TextStyle(
        // Sarı (#F5C518) üstünde siyah ≈ 11:1 — WCAG AAA.
        color: Colors.black,
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

/// Alttaki şerit: seçilenlerin küçük resimleri + çarpıyla kaldırma +
/// "daha fazla ekle" karesi + sayaç.
class _Serit extends StatelessWidget {
  final List<_Ogem> liste;
  final int azami;
  final _Ogem? odak;
  final bool Function(_Ogem) duzenli;
  final void Function(int) cikar;
  final void Function(_Ogem) odakla;

  /// null → kontenjan dolu, "+" karesi çizilmez.
  final Future<void> Function()? ekle;
  final bool ekleniyor;

  const _Serit({
    required this.liste,
    required this.azami,
    required this.odak,
    required this.duzenli,
    required this.cikar,
    required this.odakla,
    required this.ekle,
    required this.ekleniyor,
  });

  @override
  Widget build(BuildContext context) {
    final eklenebilir = ekle != null;
    return Container(
      height: _seritBoy,
      width: double.infinity,
      color: DiziRenkler.koyuGri,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
              itemCount: liste.length + (eklenebilir ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                if (i >= liste.length) {
                  return _EkleKaresi(bas: ekle!, mesgul: ekleniyor);
                }
                return _SeritKaresi(
                  ogem: liste[i],
                  secili: liste[i] == odak,
                  duzenli: duzenli(liste[i]),
                  cikar: () => cikar(i),
                  odakla: () => odakla(liste[i]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${liste.length}/$azami',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: DiziRenkler.metin70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Daha fazla ekle" karesi — şeridin sonunda çerçeveli bir EYLEM kutusu.
class _EkleKaresi extends StatelessWidget {
  final Future<void> Function() bas;
  final bool mesgul;

  const _EkleKaresi({required this.bas, required this.mesgul});

  @override
  Widget build(BuildContext context) {
    final etiket = 'Daha fazla ekle'.c;
    return SizedBox(
      width: _kareBoy,
      child: Semantics(
        button: true,
        enabled: !mesgul,
        label: etiket,
        child: Tooltip(
          message: etiket,
          child: Material(
            color: DiziRenkler.sari.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: mesgul ? null : bas,
              child: Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: DiziRenkler.sariMetin.withValues(alpha: 0.55),
                  ),
                ),
                child: mesgul
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: DiziRenkler.sariMetin,
                        ),
                      )
                    : Icon(Icons.add, size: 24, color: DiziRenkler.sariMetin),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SeritKaresi extends StatelessWidget {
  final _Ogem ogem;
  final bool secili;
  final bool duzenli;
  final VoidCallback cikar;
  final VoidCallback odakla;

  const _SeritKaresi({
    required this.ogem,
    required this.secili,
    required this.duzenli,
    required this.cikar,
    required this.odakla,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // 60 karo + sağ/üstte taşan çarpı için 18 pay.
      //
      // NEDEN 78, 74 DEĞİL (7 Ağu 2026, widget testiyle yakalandı): kaldırma
      // çarpısının GÖRÜNMEZ dokunma alanı 44 dp ve sağa dayalı. 74 dp'lik
      // karede o alan x=30'dan başlıyordu — yani karonun TAM ORTASINDAN.
      // Küçük resmin ortasına dokunan kullanıcı odaklamak yerine öğeyi
      // SİLİYORDU. 78 dp'de çarpı x=34'ten başlar, karonun merkezi (x=30)
      // serbest kalır. (Aynı hata eski `galeri_secici.dart`te de vardı.)
      width: _kareBoy,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Semantics(
              button: true,
              selected: secili,
              label: ogem.tur == MedyaTur.video ? 'Video'.c : 'Fotoğraf'.c,
              child: GestureDetector(
                onTap: odakla,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    // ODAKTAKİ kare çerçeveli. Renk TEK gösterge değil:
                    // önizleme zaten o öğeyi gösteriyor ve erişilebilirlik
                    // ağacında `selected` işaretli.
                    border: secili
                        ? Border.all(color: DiziRenkler.sari, width: 2)
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: _Kucuk(ogem: ogem),
                  ),
                ),
              ),
            ),
          ),
          // Düzenlendi rozeti: hangi karenin işlendiği tek bakışta okunur.
          // Renk TEK gösterge değil — içinde kalem glifi var.
          if (duzenli)
            Positioned(
              left: 2,
              bottom: 2,
              child: IgnorePointer(
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: DiziRenkler.sari,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, size: 11, color: Colors.black),
                ),
              ),
            ),
          // Kaldırma düğmesi. Rozet 20 dp ama görünmez dolguyla dokunma
          // alanı 44 dp (pro-rules: Touch Target Minimum, hitSlop mantığı).
          Positioned(
            right: 0,
            top: -12,
            child: Semantics(
              button: true,
              label: 'Seçimi kaldır'.c,
              child: InkWell(
                onTap: cikar,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Colors.black87,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 13,
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
}

/// Şerit karesinin içi.
///
/// VİDEODA KÜÇÜK RESİM YOK, İKON VAR: sistem seçicisi küçük resim vermiyor;
/// kare çıkarmak için videoyu çözmek gerekirdi (10 video × kod çözme). Koyu
/// zemin + `videocam` glifi hem dürüst hem bedava.
class _Kucuk extends StatelessWidget {
  final _Ogem ogem;
  const _Kucuk({required this.ogem});

  @override
  Widget build(BuildContext context) {
    if (ogem.tur == MedyaTur.video) {
      return ColoredBox(
        color: DiziRenkler.kart,
        child: Icon(Icons.videocam, size: 22, color: DiziRenkler.metin70),
      );
    }
    // Yolu olmayan dosya (bellek içi `XFile.fromData`) çizilemez: boş yollu
    // bir `FileImage` kurmak yerine doğrudan yer tutucuya düşülür.
    if (ogem.dosya.path.isEmpty) return _yerTutucu(20);
    return Image(
      // 60 dp karo, en çok 3× piksel oranı → 180 px yeter.
      image: yerelGorsel(ogem.dosya.path, genislik: 180),
      fit: BoxFit.cover,
      width: 60,
      height: 60,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _yerTutucu(20),
    );
  }

  Widget _yerTutucu(double boy) => ColoredBox(
    color: DiziRenkler.kart,
    child: Icon(
      Icons.broken_image_outlined,
      size: boy,
      color: DiziRenkler.metin54,
    ),
  );
}

/// Önizlemenin sağ üstündeki düzenle düğmesi (MEDYA-EDITOR-PLANI §G1).
///
/// ÜÇ HÂL, ÜÇÜ DE İKONDAN OKUNUR (ui-ux-pro-max, Accessibility/Color Only —
/// severity HIGH: renk tek gösterge olamaz):
/// * boşta   → kalem/makas ikonu, koyu perde üstünde beyaz
/// * meşgul  → spinner (dosya okunuyor / editör açılıyor), düğme kilitli
/// * düzenli → DOLU sarı zemin + tik ikonu, etiket "Düzenlendi"
///
/// DOKUNMA HEDEFİ: 20 px ikon + 2×12 dolgu = 44 dp (Touch Target Minimum).
/// İKON-ONLY DÜĞME: [Semantics.label] + [Tooltip] ile adı var (ARIA Labels).
class _DuzenleDugmesi extends StatelessWidget {
  final bool duzenli;
  final bool mesgul;
  final VoidCallback bas;

  /// Video kipi: kalem yerine makas, etiket "Videoyu düzenle".
  final bool video;

  const _DuzenleDugmesi({
    required this.duzenli,
    required this.mesgul,
    required this.bas,
    this.video = false,
  });

  @override
  Widget build(BuildContext context) {
    final etiket = duzenli
        ? 'Düzenlendi'.c
        : (video ? 'Videoyu düzenle'.c : 'Görseli düzenle'.c);
    return Semantics(
      button: true,
      enabled: !mesgul,
      label: etiket,
      child: Tooltip(
        message: etiket,
        child: Material(
          // Sarı zeminde siyah glif ≈ 11:1 (WCAG AAA); boştayken yarı saydam
          // siyah perde her fotoğrafın üstünde beyaz ikonu okutur.
          color: duzenli ? DiziRenkler.sari : Colors.black54,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: mesgul ? null : bas,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: mesgul
                    ? const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: DiziRenkler.sari,
                      )
                    : Icon(
                        duzenli
                            ? Icons.check
                            : (video ? Icons.content_cut : Icons.edit_outlined),
                        size: 20,
                        color: duzenli ? Colors.black : Colors.white,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Üstteki büyük önizleme. Video ise ortada oynat düğmesi çıkar; dokununca
/// yerinde oynatılır.
class _Onizleme extends StatefulWidget {
  final _Ogem ogem;

  /// Düzenlenmiş baytlar varsa önizleme ONLARI gösterir: kullanıcı ne
  /// göndereceğini görür.
  final Uint8List? duzenli;
  final void Function(String) hata;

  const _Onizleme({
    super.key,
    required this.ogem,
    required this.duzenli,
    required this.hata,
  });

  @override
  State<_Onizleme> createState() => _OnizlemeState();
}

class _OnizlemeState extends State<_Onizleme> {
  VideoPlayerController? _oynatici;
  bool _hazirlaniyor = false;

  @override
  void dispose() {
    _oynatici?.dispose();
    super.dispose();
  }

  Future<void> _oynat() async {
    if (_hazirlaniyor) return;
    setState(() => _hazirlaniyor = true);
    VideoPlayerController? d;
    try {
      d = yerelVideo(widget.ogem.dosya.path);
      if (d == null) throw Exception('platform desteklemiyor');
      await d.initialize();
      if (!mounted) {
        await d.dispose();
        return;
      }
      await d.setLooping(true);
      await d.play();
      setState(() {
        _oynatici = d;
        _hazirlaniyor = false;
      });
    } catch (_) {
      await d?.dispose();
      if (!mounted) return;
      setState(() => _hazirlaniyor = false);
      // Sessiz başarısızlık yok: kullanıcı neden oynamadığını bilir.
      widget.hata('Video açılamadı'.c);
    }
  }

  Widget _yerTutucu() => Center(
    child: Icon(
      Icons.broken_image_outlined,
      size: 48,
      color: DiziRenkler.metin54,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final d = _oynatici;
    if (d != null && d.value.isInitialized) {
      return Container(
        color: DiziRenkler.markaKoyu,
        child: Center(
          child: AspectRatio(
            aspectRatio: d.value.aspectRatio,
            child: VideoPlayer(d),
          ),
        ),
      );
    }
    final video = widget.ogem.tur == MedyaTur.video;
    return Container(
      color: DiziRenkler.markaKoyu,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (video)
            Center(
              child: Icon(
                Icons.movie_outlined,
                size: 64,
                color: DiziRenkler.metin24,
              ),
            )
          else if (widget.duzenli != null)
            Image.memory(
              widget.duzenli!,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            )
          else if (widget.ogem.dosya.path.isEmpty)
            _yerTutucu()
          else
            Image(
              image: yerelGorsel(widget.ogem.dosya.path),
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => _yerTutucu(),
            ),
          if (video)
            Center(
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _hazirlaniyor ? null : _oynat,
                  child: Padding(
                    // 22 ikon + 2×11 dolgu = 44 dp dokunma hedefi.
                    padding: const EdgeInsets.all(11),
                    child: _hazirlaniyor
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: DiziRenkler.sari,
                            ),
                          )
                        : const Icon(
                            Icons.play_arrow,
                            size: 22,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
