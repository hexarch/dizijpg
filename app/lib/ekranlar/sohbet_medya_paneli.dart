import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

import '../ceviri.dart';
import '../tema.dart';
import 'kamera_ekrani.dart';

/// SOHBET MEDYA PANELİ — Telegram'ın ataç alt sayfası (15 Eyl 2026).
///
/// Kullanıcı tarifi: ataça dokununca YARIM EKRAN modal; içinde 3 sütun
/// galeri ızgarası, sol üstte 2 satırı kaplayan CANLI ARKA KAMERA karesi,
/// altta (şeffaf gezinme çubuğunun üstünde) Galeri · Dosya · Konum · GIF ·
/// Dizi/Film şeridi — Galeri seçili görünür çünkü galeri zaten ekranda.
/// Panel yukarı çekilerek tam ekrana yakın büyür.
///
/// · Kareye dokunmak → o medya ile inceleme (düzenleme) ekranı.
/// · Sağ üstteki daireye dokunmak → çoklu seçim (sıra numarası), "Gönder N".
/// · Kamera karesine dokunmak → [KameraEkrani] (flaş / çek / çevir).
///
/// İZİN: galeri ızgarası `READ_MEDIA_IMAGES/VIDEO` ister (7 Ağu 2026'da Play
/// bu izni reddetmişti; 15 Eyl'de kullanıcı bilerek geri istedi — Play
/// beyanı "sohbet içi galeri"). İzin yoksa ızgara yerine "İzin ver" durumu
/// çizilir, şerit ve kamera çalışmaya devam eder (sistem seçicisi Galeri
/// düğmesinden hep açılır).
///
/// WEB'DE KULLANILMAZ: photo_manager/camera tarayıcıda yok; sohbet.dart
/// orada eski düğme panelini açar.

/// Şeritteki seçenekler (web paneliyle ortak).
enum SohbetEkTuru { galeri, kamera, dosya, konum, gif, icerik }

/// Panel sonucu: ya medya dosyaları (galeriden) ya bir seçenek.
sealed class SohbetEkSonucu {
  const SohbetEkSonucu();
}

class SohbetEkMedya extends SohbetEkSonucu {
  final List<XFile> dosyalar;
  const SohbetEkMedya(this.dosyalar);
}

class SohbetEkSecenek extends SohbetEkSonucu {
  final SohbetEkTuru tur;
  const SohbetEkSecenek(this.tur);
}

/// Galeri öğesi — `AssetEntity`nin panelin ihtiyaç duyduğu kadarı. Testler
/// sahte öğe verir; platform kanalına hiç gidilmez.
class GaleriOgesi {
  final String kimlik;
  final bool video;
  final Duration sure;

  /// Kare kenarı (px) verilir, küçük resim baytları döner.
  final Future<Uint8List?> Function(int kenar) kucukResim;

  /// Tam dosya (gönderim için).
  final Future<XFile?> Function() dosya;

  const GaleriOgesi({
    required this.kimlik,
    required this.video,
    required this.sure,
    required this.kucukResim,
    required this.dosya,
  });
}

/// Testler için: galeri yükleyicisi yedeği. `null` döndürmek "izin yok"
/// demektir; boş liste "galeri boş".
@visibleForTesting
Future<List<GaleriOgesi>?> Function()? galeriSahte;

/// Testler için: kamera önizlemesi kurulmasın (platform kanalı yok).
@visibleForTesting
bool kameraOnizlemeKapali = false;

/// Bir seferde çekilen kare sayısı; panel kaydırıldıkça devamı gelir.
const _sayfaBoyu = 60;

Future<List<GaleriOgesi>?> _galeriYukle(int sayfa) async {
  if (galeriSahte != null) return sayfa == 0 ? galeriSahte!() : const [];
  final izin = await PhotoManager.requestPermissionExtend();
  if (!izin.hasAccess) return null;
  final yollar = await PhotoManager.getAssetPathList(
    onlyAll: true,
    type: RequestType.common,
  );
  if (yollar.isEmpty) return const [];
  final liste = await yollar.first.getAssetListPaged(
    page: sayfa,
    size: _sayfaBoyu,
  );
  return [
    for (final a in liste)
      GaleriOgesi(
        kimlik: a.id,
        video: a.type == AssetType.video,
        sure: Duration(seconds: a.duration),
        kucukResim: (kenar) =>
            a.thumbnailDataWithSize(ThumbnailSize.square(kenar), quality: 80),
        dosya: () async {
          final f = await a.file;
          return f == null ? null : XFile(f.path);
        },
      ),
  ];
}

/// Paneli açar; kapatılırsa `null`.
Future<SohbetEkSonucu?> sohbetMedyaPaneliAc(BuildContext context) {
  // KENARDAN KENARA (2 Eyl 2026 kararıyla aynı): masaüstünde sohbet kolonu
  // tavanı 800.
  final en = math.min(MediaQuery.sizeOf(context).width, 800.0);
  return showModalBottomSheet<SohbetEkSonucu>(
    context: context,
    isScrollControlled: true,
    // Gezinme çubuğunun ÜSTÜNE değil, ALTINA kadar uzanır (şeffaf çubuk).
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(minWidth: en, maxWidth: en),
    builder: (_) => const SohbetMedyaPaneli(),
  );
}

class SohbetMedyaPaneli extends StatefulWidget {
  const SohbetMedyaPaneli({super.key});

  @override
  State<SohbetMedyaPaneli> createState() => _SohbetMedyaPaneliState();
}

class _SohbetMedyaPaneliState extends State<SohbetMedyaPaneli> {
  List<GaleriOgesi>? _ogeler;
  bool _izinYok = false;
  bool _yukleniyor = true;
  bool _sonSayfa = false;
  int _sayfa = 0;

  /// Seçim SIRALI: daireye basılma sırası gönderim sırasıdır.
  final List<GaleriOgesi> _secili = [];

  /// Dosyalar hazırlanırken (tam dosya okunuyor) düğme kilitli.
  bool _hazirlaniyor = false;

  /// Küçük resim önbelleği: kaydırınca yeniden çözülmesin.
  final Map<String, Future<Uint8List?>> _kucukler = {};

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      // Zaman aşımı: eklenti cevap vermezse (masaüstü/test) spinner sonsuza
      // dek dönmesin; izin yok durumuna düşer, şerit ve kamera çalışır.
      final l = await _galeriYukle(_sayfa).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        if (l == null) {
          _izinYok = true;
          _ogeler = const [];
        } else {
          _ogeler = [...?_ogeler, ...l];
          _sonSayfa = l.length < _sayfaBoyu;
        }
      });
    } catch (_) {
      // Platform kanalı yok (test/masaüstü) ya da beklenmedik hata: izin
      // durumu gibi davran — panel yine de şerit ve kamerayla kullanılır.
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _izinYok = true;
        _ogeler = const [];
      });
    }
  }

  void _dahaFazla() {
    if (_yukleniyor || _sonSayfa || _izinYok) return;
    _yukleniyor = true;
    _sayfa++;
    _yukle();
  }

  Future<Uint8List?> _kucuk(GaleriOgesi o, int kenar) =>
      _kucukler.putIfAbsent(o.kimlik, () => o.kucukResim(kenar));

  void _sec(GaleriOgesi o) {
    setState(() {
      if (!_secili.remove(o)) _secili.add(o);
    });
  }

  Future<void> _gonder(List<GaleriOgesi> liste) async {
    if (_hazirlaniyor || liste.isEmpty) return;
    setState(() => _hazirlaniyor = true);
    final dosyalar = <XFile>[];
    for (final o in liste) {
      try {
        final d = await o.dosya();
        if (d != null) dosyalar.add(d);
      } catch (_) {
        // okunamayan kare atlanır; aşağıda sayıyla bildirilir
      }
    }
    if (!mounted) return;
    if (dosyalar.isEmpty) {
      setState(() => _hazirlaniyor = false);
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('Seçilen dosya okunamadı'.c)));
      return;
    }
    Navigator.of(context).pop(SohbetEkMedya(dosyalar));
  }

  void _secenek(SohbetEkTuru t) =>
      Navigator.of(context).pop(SohbetEkSecenek(t));

  @override
  Widget build(BuildContext context) {
    final altBosluk = MediaQuery.paddingOf(context).bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, kaydirma) => Container(
        decoration: BoxDecoration(
          color: DiziRenkler.koyuGri,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              children: [
                // Sürükleme tutamacı
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(top: 8, bottom: 6),
                    decoration: BoxDecoration(
                      color: DiziRenkler.metin38,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Expanded(
                  child: _izinYok
                      ? _izinDurumu(kaydirma)
                      : _izgara(kaydirma, altBosluk),
                ),
              ],
            ),
            // Alt şerit: gezinme çubuğunun üstünde, ızgaranın üstüne biner.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Serit(
                altBosluk: altBosluk,
                secili: SohbetEkTuru.galeri,
                onSec: _secenek,
              ),
            ),
            if (_secili.isNotEmpty)
              Positioned(
                right: 14,
                bottom: _Serit.boy + altBosluk + 10,
                child: FilledButton.icon(
                  key: const Key('panel-gonder'),
                  onPressed: _hazirlaniyor ? null : () => _gonder(_secili),
                  icon: _hazirlaniyor
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text('${'Gönder'.c} ${_secili.length}'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// İzin verilmemiş: ızgara yerine açıklama + ayar düğmesi. Kamera karesi
  /// yine çizilir (ayrı izin).
  Widget _izinDurumu(ScrollController kaydirma) => ListView(
    controller: kaydirma,
    padding: EdgeInsets.fromLTRB(
      16,
      8,
      16,
      _Serit.boy + MediaQuery.paddingOf(context).bottom + 16,
    ),
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            height: 150,
            child: _KameraKaresi(onTap: () => _secenek(SohbetEkTuru.kamera)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  color: DiziRenkler.metin54,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  'Galeri izni gerekli'.c,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Son fotoğrafların burada görünsün diye galerine erişim gerekir.'
                      .c,
                  style: TextStyle(fontSize: 13, color: DiziRenkler.metin54),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      key: const Key('panel-izin'),
                      onPressed: () async {
                        if (galeriSahte != null) return;
                        await PhotoManager.openSetting();
                      },
                      child: Text('İzin ver'.c),
                    ),
                    OutlinedButton(
                      onPressed: () => _secenek(SohbetEkTuru.galeri),
                      child: Text('Galeriden seç'.c),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );

  /// 3 sütun; sol üstte 2 satırlık kamera karesi (Telegram).
  Widget _izgara(ScrollController kaydirma, double altBosluk) {
    final ogeler = _ogeler ?? const <GaleriOgesi>[];
    return LayoutBuilder(
      builder: (context, kisit) {
        const bosluk = 2.0;
        final kare = (kisit.maxWidth - bosluk * 4) / 3;
        // İlk blok: kamera (2 satır) + 4 kare; sonra 3'erli satırlar.
        final kalan = ogeler.length > 4 ? ogeler.length - 4 : 0;
        final satirSayisi = (kalan / 3).ceil();
        Widget kareW(GaleriOgesi o) => _GaleriKaresi(
          key: ValueKey('kare-${o.kimlik}'),
          oge: o,
          kenar: kare,
          kucuk: _kucuk(
            o,
            (kare * MediaQuery.devicePixelRatioOf(context)).round(),
          ),
          sira: _secili.indexOf(o),
          secimVar: _secili.isNotEmpty,
          onTap: () => _secili.isEmpty ? _gonder([o]) : _sec(o),
          onSec: () => _sec(o),
        );
        Widget bosKare() => SizedBox(width: kare, height: kare);
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 400) _dahaFazla();
            return false;
          },
          child: CustomScrollView(
            controller: kaydirma,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  bosluk,
                  0,
                  bosluk,
                  _Serit.boy + altBosluk + 8,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: bosluk),
                        child: SizedBox(
                          height: kare * 2 + bosluk,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: kare,
                                height: kare * 2 + bosluk,
                                child: _KameraKaresi(
                                  onTap: () => _secenek(SohbetEkTuru.kamera),
                                ),
                              ),
                              const SizedBox(width: bosluk),
                              Expanded(
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        ogeler.isNotEmpty
                                            ? kareW(ogeler[0])
                                            : bosKare(),
                                        const SizedBox(width: bosluk),
                                        ogeler.length > 1
                                            ? kareW(ogeler[1])
                                            : bosKare(),
                                      ],
                                    ),
                                    const SizedBox(height: bosluk),
                                    Row(
                                      children: [
                                        ogeler.length > 2
                                            ? kareW(ogeler[2])
                                            : bosKare(),
                                        const SizedBox(width: bosluk),
                                        ogeler.length > 3
                                            ? kareW(ogeler[3])
                                            : bosKare(),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final bas = 4 + (i - 1) * 3;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: bosluk),
                      child: Row(
                        children: [
                          for (var k = 0; k < 3; k++) ...[
                            if (k > 0) const SizedBox(width: bosluk),
                            bas + k < ogeler.length
                                ? kareW(ogeler[bas + k])
                                : bosKare(),
                          ],
                        ],
                      ),
                    );
                  }, childCount: 1 + satirSayisi),
                ),
              ),
              if (_yukleniyor)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: DiziRenkler.sari,
                        ),
                      ),
                    ),
                  ),
                )
              else if (ogeler.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Galeride medya yok'.c,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: DiziRenkler.metin54),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Galeri karesi: küçük resim + video süresi + seçim dairesi.
class _GaleriKaresi extends StatelessWidget {
  final GaleriOgesi oge;
  final double kenar;
  final Future<Uint8List?> kucuk;

  /// Seçim sırası (0 tabanlı); seçili değilse -1.
  final int sira;
  final bool secimVar;
  final VoidCallback onTap;
  final VoidCallback onSec;

  const _GaleriKaresi({
    super.key,
    required this.oge,
    required this.kenar,
    required this.kucuk,
    required this.sira,
    required this.secimVar,
    required this.onTap,
    required this.onSec,
  });

  @override
  Widget build(BuildContext context) {
    final secili = sira >= 0;
    return SizedBox(
      width: kenar,
      height: kenar,
      child: Semantics(
        button: true,
        label: oge.video ? 'Video'.c : 'Fotoğraf'.c,
        selected: secili,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder<Uint8List?>(
                future: kucuk,
                builder: (context, s) {
                  final b = s.data;
                  if (b == null) {
                    return ColoredBox(color: DiziRenkler.kart);
                  }
                  return Image.memory(
                    b,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.low,
                  );
                },
              ),
              // Seçili kare hafif küçülür + sarı çerçeve (Telegram).
              if (secili)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: DiziRenkler.sari, width: 3),
                    color: Colors.black26,
                  ),
                ),
              if (oge.video)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.videocam,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _sureMetni(oge.sure),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                top: 5,
                right: 5,
                child: GestureDetector(
                  key: ValueKey('sec-${oge.kimlik}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onSec,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: secili ? DiziRenkler.sari : Colors.black26,
                        border: Border.all(
                          color: secili ? DiziRenkler.sari : Colors.white,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: secili
                          ? Text(
                              '${sira + 1}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : null,
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

  static String _sureMetni(Duration d) {
    final s = d.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

/// Sol üstteki canlı arka kamera karesi. Önizleme kurulamazsa (izin yok,
/// masaüstü, test) kamera ikonu çizilir; dokunma her durumda kamera açar.
class _KameraKaresi extends StatefulWidget {
  final VoidCallback onTap;
  const _KameraKaresi({required this.onTap});

  @override
  State<_KameraKaresi> createState() => _KameraKaresiState();
}

class _KameraKaresiState extends State<_KameraKaresi> {
  CameraController? _denetci;

  @override
  void initState() {
    super.initState();
    if (!kameraOnizlemeKapali && !kIsWeb) _kur();
  }

  Future<void> _kur() async {
    try {
      final kameralar = await (kameraListesiSahte ?? availableCameras)();
      if (kameralar.isEmpty) return;
      final arka = kameralar.firstWhere(
        (k) => k.lensDirection == CameraLensDirection.back,
        orElse: () => kameralar.first,
      );
      final d = CameraController(
        arka,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await d.initialize();
      if (!mounted) {
        await d.dispose();
        return;
      }
      setState(() => _denetci = d);
    } catch (_) {
      // ikon karesi kalır
    }
  }

  @override
  void dispose() {
    _denetci?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = _denetci;
    return Semantics(
      button: true,
      label: 'Kamera'.c,
      child: GestureDetector(
        key: const Key('panel-kamera'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (d != null && d.value.isInitialized)
                FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: d.value.previewSize?.height ?? 480,
                    height: d.value.previewSize?.width ?? 640,
                    child: CameraPreview(d),
                  ),
                )
              else
                const ColoredBox(color: Color(0xFF1C1C21)),
              Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.photo_camera,
                    color: Colors.white,
                    size: 24,
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

/// Alt şerit: yuvarlak renkli düğmeler (Telegram). Zemini yukarı doğru
/// şeffaflaşır ki ızgara altından akıp geçsin; gezinme çubuğu payı
/// [altBosluk] ile eklenir.
class _Serit extends StatelessWidget {
  static const boy = 78.0;

  final double altBosluk;
  final SohbetEkTuru secili;
  final void Function(SohbetEkTuru) onSec;

  const _Serit({
    required this.altBosluk,
    required this.secili,
    required this.onSec,
  });

  @override
  Widget build(BuildContext context) {
    final secenekler =
        <({SohbetEkTuru tur, IconData ikon, Color renk, String ad})>[
          (
            tur: SohbetEkTuru.galeri,
            ikon: Icons.photo_library,
            renk: const Color(0xFF459DF5),
            ad: 'Galeri'.c,
          ),
          (
            tur: SohbetEkTuru.dosya,
            ikon: Icons.insert_drive_file,
            renk: const Color(0xFF34B9F1),
            ad: 'Dosya'.c,
          ),
          (
            tur: SohbetEkTuru.konum,
            ikon: Icons.location_on,
            renk: const Color(0xFF60C255),
            ad: 'Konum'.c,
          ),
          (
            tur: SohbetEkTuru.gif,
            ikon: Icons.gif_box,
            renk: const Color(0xFFE37B5C),
            ad: 'GIF'.c,
          ),
          (
            tur: SohbetEkTuru.icerik,
            ikon: Icons.local_movies,
            renk: DiziRenkler.sari,
            ad: 'Dizi / Film'.c,
          ),
        ];
    return Container(
      height: boy + altBosluk,
      padding: EdgeInsets.only(bottom: altBosluk),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            DiziRenkler.koyuGri.withValues(alpha: 0),
            DiziRenkler.koyuGri.withValues(alpha: 0.92),
            DiziRenkler.koyuGri,
          ],
          stops: const [0, 0.35, 1],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final s in secenekler)
            _SeritDugmesi(
              key: ValueKey('serit-${s.tur.name}'),
              ikon: s.ikon,
              renk: s.renk,
              ad: s.ad,
              secili: s.tur == secili,
              onTap: () => onSec(s.tur),
            ),
        ],
      ),
    );
  }
}

class _SeritDugmesi extends StatelessWidget {
  final IconData ikon;
  final Color renk;
  final String ad;
  final bool secili;
  final VoidCallback onTap;

  const _SeritDugmesi({
    super.key,
    required this.ikon,
    required this.renk,
    required this.ad,
    required this.secili,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: secili,
    label: ad,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: renk,
                shape: BoxShape.circle,
                border: secili
                    ? Border.all(color: Colors.white, width: 2)
                    : null,
              ),
              child: Icon(ikon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 5),
            Text(
              ad,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: secili ? FontWeight.w700 : FontWeight.w500,
                color: secili ? DiziRenkler.sariMetin : DiziRenkler.metin,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
