import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../ceviri.dart';
import '../tema.dart';
import '../video_islem.dart';

/// UYGULAMA İÇİ KAMERA (15 Eyl 2026, Telegram düzeni).
///
/// Sohbetin medya panelindeki canlı kamera karesine dokununca açılır:
/// solda FLAŞ (kapalı → otomatik → açık), ortada ÇEK (dokun = fotoğraf,
/// BASILI TUT = video, bırakınca biter), sağda ÖN/ARKA geçişi. Sonuç tek
/// bir [XFile]; vazgeçilirse `null`. Dosya türü çağıranda sihirli bayttan
/// okunur (medya_inceleme), uzantıya güvenilmez.
///
/// Video [videoAzamiGirdiSure]de kendiliğinden durur — daha uzununu
/// düzenleyici zaten reddediyor, kullanıcı boşuna çekmesin.
///
/// Testler için [kameraListesiSahte]: `availableCameras` platform kanalına
/// gider; sahte liste verilince ekran "kamera yok" dalına düşmeden çizilir.
/// (Panelin kamera karesi de kullanır; bu yüzden `visibleForTesting` değil.)
Future<List<CameraDescription>> Function()? kameraListesiSahte;

Future<XFile?> kameraEkraniAc(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push<XFile>(
      MaterialPageRoute(
        builder: (_) => const KameraEkrani(),
        fullscreenDialog: true,
      ),
    );

class KameraEkrani extends StatefulWidget {
  const KameraEkrani({super.key});

  @override
  State<KameraEkrani> createState() => _KameraEkraniState();
}

class _KameraEkraniState extends State<KameraEkrani>
    with WidgetsBindingObserver {
  List<CameraDescription> _kameralar = const [];
  CameraController? _denetci;
  int _indeks = 0;
  FlashMode _flas = FlashMode.off;
  bool _hazir = false;
  bool _hata = false;
  bool _mesgul = false;
  bool _kaydediyor = false;
  Timer? _sureSayaci;
  Timer? _azamiSure;
  int _saniye = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _baslat();
  }

  Future<void> _baslat() async {
    try {
      _kameralar = await (kameraListesiSahte ?? availableCameras)();
      if (_kameralar.isEmpty) throw StateError('kamera yok');
      // Arka kamera önce (Telegram varsayılanı).
      final arka = _kameralar.indexWhere(
        (k) => k.lensDirection == CameraLensDirection.back,
      );
      _indeks = arka < 0 ? 0 : arka;
      await _denetciKur();
    } catch (_) {
      if (mounted) setState(() => _hata = true);
    }
  }

  Future<void> _denetciKur() async {
    final eski = _denetci;
    _denetci = null;
    if (mounted) setState(() => _hazir = false);
    await eski?.dispose();
    final d = CameraController(
      _kameralar[_indeks],
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await d.initialize();
    try {
      await d.setFlashMode(_flas);
    } catch (_) {
      // Ön kamerada flaş olmayabilir; sessizce kapalı kalır.
    }
    if (!mounted) {
      await d.dispose();
      return;
    }
    setState(() {
      _denetci = d;
      _hazir = true;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState durum) {
    // Arka plana gidince kamera bırakılır, dönünce yeniden kurulur — aksi
    // hâlde Android kamerayı başka uygulamaya kaptırınca önizleme donar.
    if (durum == AppLifecycleState.inactive ||
        durum == AppLifecycleState.paused) {
      _denetci?.dispose();
      _denetci = null;
      if (mounted) setState(() => _hazir = false);
    } else if (durum == AppLifecycleState.resumed &&
        _kameralar.isNotEmpty &&
        _denetci == null) {
      _denetciKur().catchError((_) {
        if (mounted) setState(() => _hata = true);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sureSayaci?.cancel();
    _azamiSure?.cancel();
    _denetci?.dispose();
    super.dispose();
  }

  Future<void> _flasDegistir() async {
    final d = _denetci;
    if (d == null || _kaydediyor) return;
    final sonraki = switch (_flas) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    try {
      await d.setFlashMode(sonraki);
      if (mounted) setState(() => _flas = sonraki);
    } catch (_) {
      // desteklenmiyor → olduğu gibi kalır
    }
  }

  Future<void> _kameraDegistir() async {
    if (_kameralar.length < 2 || _kaydediyor || !_hazir) return;
    _indeks = (_indeks + 1) % _kameralar.length;
    try {
      await _denetciKur();
    } catch (_) {
      if (mounted) setState(() => _hata = true);
    }
  }

  Future<void> _cek() async {
    final d = _denetci;
    if (d == null || !_hazir || _mesgul || _kaydediyor) return;
    setState(() => _mesgul = true);
    try {
      HapticFeedback.lightImpact();
      final foto = await d.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(foto);
    } catch (_) {
      if (mounted) {
        setState(() => _mesgul = false);
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text('Fotoğraf çekilemedi'.c)));
      }
    }
  }

  Future<void> _videoBasla() async {
    final d = _denetci;
    if (d == null || !_hazir || _mesgul || _kaydediyor) return;
    try {
      await d.startVideoRecording();
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() {
        _kaydediyor = true;
        _saniye = 0;
      });
      _sureSayaci = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _saniye++);
      });
      _azamiSure = Timer(videoAzamiGirdiSure, _videoBitir);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text('Video kaydı başlamadı'.c)));
      }
    }
  }

  Future<void> _videoBitir() async {
    final d = _denetci;
    if (d == null || !_kaydediyor) return;
    _sureSayaci?.cancel();
    _azamiSure?.cancel();
    setState(() {
      _kaydediyor = false;
      _mesgul = true;
    });
    try {
      final video = await d.stopVideoRecording();
      if (!mounted) return;
      Navigator.of(context).pop(video);
    } catch (_) {
      if (mounted) {
        setState(() => _mesgul = false);
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text('Video kaydedilemedi'.c)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _denetci;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_hata)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Kamera açılamadı'.c,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (d != null && _hazir)
            // Önizleme ekranı KAPLAR (Telegram): oran korunur, taşan kırpılır.
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: d.value.previewSize?.height ?? 1080,
                height: d.value.previewSize?.width ?? 1920,
                child: CameraPreview(d),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: DiziRenkler.sari),
            ),
          // Üst: kapat + kayıt süresi
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Kapat'.c,
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _kaydediyor
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  if (_kaydediyor)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(_saniye ~/ 60).toString().padLeft(2, '0')}:'
                        '${(_saniye % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          // Alt: flaş · çek · çevir
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_kaydediyor)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          'Çekmek için dokun, video için basılı tut'.c,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _YuvarlakDugme(
                          key: const Key('kamera-flas'),
                          ipucu: 'Flaş'.c,
                          ikon: switch (_flas) {
                            FlashMode.off => Icons.flash_off,
                            FlashMode.auto => Icons.flash_auto,
                            _ => Icons.flash_on,
                          },
                          onTap: _hazir && !_kaydediyor ? _flasDegistir : null,
                        ),
                        _CekDugmesi(
                          key: const Key('kamera-cek'),
                          kaydediyor: _kaydediyor,
                          mesgul: _mesgul,
                          etkin: _hazir && !_hata,
                          onTap: _cek,
                          onBasla: _videoBasla,
                          onBirak: _videoBitir,
                        ),
                        _YuvarlakDugme(
                          key: const Key('kamera-cevir'),
                          ipucu: 'Kamerayı çevir'.c,
                          ikon: Icons.cameraswitch_outlined,
                          onTap: _kameralar.length > 1 && _hazir && !_kaydediyor
                              ? _kameraDegistir
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YuvarlakDugme extends StatelessWidget {
  final String ipucu;
  final IconData ikon;
  final VoidCallback? onTap;

  const _YuvarlakDugme({
    super.key,
    required this.ipucu,
    required this.ikon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: ipucu,
    enabled: onTap != null,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(
          ikon,
          color: onTap == null ? Colors.white38 : Colors.white,
          size: 24,
        ),
      ),
    ),
  );
}

/// Çek düğmesi: dokun = fotoğraf, basılı tut = video (bırakınca biter).
/// Kayıtta halka kırmızıya döner ve büyür.
class _CekDugmesi extends StatelessWidget {
  final bool kaydediyor;
  final bool mesgul;
  final bool etkin;
  final VoidCallback onTap;
  final VoidCallback onBasla;
  final VoidCallback onBirak;

  const _CekDugmesi({
    super.key,
    required this.kaydediyor,
    required this.mesgul,
    required this.etkin,
    required this.onTap,
    required this.onBasla,
    required this.onBirak,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Çek'.c,
    enabled: etkin && !mesgul,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: etkin && !mesgul ? onTap : null,
      onLongPressStart: etkin && !mesgul ? (_) => onBasla() : null,
      onLongPressEnd: (_) => onBirak(),
      onLongPressCancel: onBirak,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: kaydediyor ? 84 : 76,
        height: kaydediyor ? 84 : 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: kaydediyor ? Colors.redAccent : Colors.white,
            width: 4,
          ),
        ),
        padding: const EdgeInsets.all(6),
        child: mesgul
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              )
            : AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: kaydediyor ? Colors.redAccent : Colors.white,
                  shape: kaydediyor ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: kaydediyor ? BorderRadius.circular(8) : null,
                ),
                margin: EdgeInsets.all(kaydediyor ? 14 : 0),
              ),
      ),
    ),
  );
}
