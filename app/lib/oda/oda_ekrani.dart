/// İZLEME ODASI — oda ekranı (senkron oynatma + sohbet + tepkiler).
///
/// ===========================================================================
/// SENKRON NASIL ÇALIŞIYOR (özet; matematiği `oda_senkron.dart`te)
/// ===========================================================================
/// Sunucu "video ŞU ANDA şuradaydı" tutar (`konumMs` + `konumZaman`). Her
/// yoklama yanıtında `sunucu_zaman` da gelir; [SaatSapmasi] onunla cihaz saati
/// ile sunucu saati arasındaki farkı ölçer. İzleyici beklenen konumu kendisi
/// hesaplar ve oynatıcısını üç kademeli merdivenle düzeltir:
///   ≤250 ms  dokunma · ≤3 sn  hızı %7 oynat · >3 sn ya da KASITLI eylem  sar.
///
/// **Kasıtlı eylem** = sunucudaki `surum` atladı. Kullanıcı isteği aynen
/// buydu: *"oda sahibi 10 saniye ileri sararsa izleyenlerde de ileri
/// sarılmalı"* — 10 saniyelik farkı yumuşak düzeltmeye bırakmak onu ~2,5
/// dakikaya yayardı, yani pratikte hiç olmamış görünürdü.
///
/// ===========================================================================
/// KONTROL TEK ELDE
/// ===========================================================================
/// Oynat/duraklat/sar YALNIZ oda sahibinde. İzleyicinin oynatıcısı salt
/// okunurdur; kontrolleri hiç çizilmez ve dokunma da oynatmaz. İki kişi aynı
/// anda sarabilseydi oda salınıma girerdi (her biri ötekinin konumuna
/// düzeltme yapar, düzeltme karşıya yeni bir düzeltme doğurur).
///
/// ===========================================================================
/// GERİ BESLEME DÖNGÜSÜNÜ KIRAN ŞEY
/// ===========================================================================
/// Sahip de kendi durumunu yoklamayla geri okur. Uyguladığımız her
/// programatik `seekTo`/`play`/`pause` yeni bir "kullanıcı eylemi" sanılsaydı
/// sonsuz bir yankı olurdu. Bu yüzden durum sunucuya YALNIZ bu ekrandaki
/// düğmelerden (ve 10 sn'lik kalp atışından) yazılır — oynatıcıyı dinleyerek
/// DEĞİL.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../api.dart';
import '../ceviri.dart';
import '../ekranlar/ortak.dart';
import '../tema.dart';
import 'oda_api.dart';
import 'oda_senkron.dart';
import 'oda_yukle.dart';

/// Sohbetin yan panele geçtiği genişlik. Altında video üstte, sohbet altta.
const double _genisEsik = 900;

class OdaEkrani extends StatefulWidget {
  final int odaId;
  const OdaEkrani({super.key, required this.odaId});

  @override
  State<OdaEkrani> createState() => _OdaEkraniState();
}

class _OdaEkraniState extends State<OdaEkrani> with WidgetsBindingObserver {
  Oda? _oda;
  String? _hata;
  bool _kapandi = false;

  final _mesajlar = <OdaMesaj>[];
  final _metin = TextEditingController();
  final _kaydirma = ScrollController();

  final _sapma = SaatSapmasi();
  Timer? _yoklama;
  Timer? _kalp;

  /// Yoklama turu sayacı — üye listesi her 5 turda bir istenir.
  int _tur = 0;
  bool _yoklamaUcuyor = false;

  VideoPlayerController? _oynatici;
  bool _oynaticiHazir = false;
  String? _kuruluVideo;

  /// Programatik seek sürerken düzeltme YAPILMAZ: art arda gelen iki seek
  /// oynatıcıyı tampon boşaltma döngüsüne sokar.
  bool _sariyor = false;

  /// Uygulanan son hız — her turda `setPlaybackSpeed` çağırmamak için.
  double _uygulananHiz = 1.0;

  /// Yükleme durumu (yalnız sahipte).
  OdaVideoYukleyici? _yukleyici;
  OdaYuklemeDurumu? _yuklemeDurumu;

  /// Uçuşan tepkiler.
  final _ucusan = <_UcusanTepki>[];
  int _tepkiSayac = 0;

  int get _benimId =>
      (context.read<Oturum>().kullanici?['id'] as num?)?.toInt() ?? -1;

  bool get _sahipMiyim => _oda?.sahibiMiyim == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ilkYukle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _yoklama?.cancel();
    _kalp?.cancel();
    _yukleyici?.iptal();
    _oynatici?.dispose();
    _metin.dispose();
    _kaydirma.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState durum) {
    // Arka planda yoklama DURUR: 1 sn'lik tur cebe girmiş bir telefonda pil
    // yakar ve sunucuya karşılığı olmayan yük bindirir. Öne dönünce tek bir
    // tam yenileme yapılır — arada kaçırılan mesajlar ve durum böyle toplanır.
    if (durum == AppLifecycleState.resumed) {
      _yoklamayiKur();
      _tamYenile();
    } else {
      _yoklama?.cancel();
      _yoklama = null;
      // Sahip arka plana geçince video zaten duraklar; izleyicileri de
      // duraklatmak İSTEMİYORUZ — sahip bildirime bakıp dönebilir. Durum
      // sunucuda olduğu gibi kalır, sahip dönünce kendini hizalar.
    }
  }

  void _uyar(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // -------------------------------------------------------------------------
  // YÜKLEME / YOKLAMA
  // -------------------------------------------------------------------------

  Future<void> _ilkYukle() async {
    try {
      final oda = await OdaApi.getir(widget.odaId);
      if (!mounted) return;
      setState(() {
        _oda = oda;
        _hata = null;
      });
      await _videoyuKur(oda.video);
      _yoklamayiKur();
    } on ApiHata catch (e) {
      if (!mounted) return;
      setState(() {
        _kapandi = e.makineKodu == OdaKod.odaKapandi;
        _hata = odaHataMetni(e);
      });
    } catch (_) {
      // BEKLENMEDİK gövde/çözümleme hatası da EKRANA düşmeli: yakalanmazsa
      // Flutter kırmızı hata kutusu çizer ve kullanıcı ham bir tip hatası
      // okur. Burada dürüst ve çevrili tek cümle kalır.
      if (!mounted) return;
      setState(() => _hata = 'Oda açılamadı'.c);
    }
  }

  Future<void> _tamYenile() async {
    try {
      final oda = await OdaApi.getir(widget.odaId);
      if (!mounted) return;
      setState(() => _oda = oda);
      await _videoyuKur(oda.video);
      _duzelt();
    } on ApiHata catch (_) {
      /* sonraki yoklama zaten deneyecek */
    }
  }

  void _yoklamayiKur() {
    _yoklama?.cancel();
    _yoklama = Timer.periodic(odaYoklamaAraligi, (_) => _yokla());
  }

  Future<void> _yokla() async {
    // Aynı anda TEK tur: yavaş bir ağda turlar üst üste binerse hem sunucuya
    // hem oynatıcıya çakışan düzeltmeler gider.
    if (_yoklamaUcuyor || _oda == null) return;
    _yoklamaUcuyor = true;
    final basi = DateTime.now().millisecondsSinceEpoch;
    try {
      final akis = await OdaApi.akis(
        widget.odaId,
        surum: _oda!.durum.surum,
        mesajdan: _mesajlar.isEmpty ? 0 : _mesajlar.last.id,
        uyeler: _tur % 5 == 0,
      );
      if (!mounted) return;
      _sapma.besle(
        istekBasi: basi,
        yanitSonu: DateTime.now().millisecondsSinceEpoch,
        sunucuZaman: akis.sunucuZaman,
      );
      _tur++;
      var degisti = false;
      if (akis.durum != null) {
        // Sunucu durumu YALNIZ sürüm değiştiyse gönderir; geldiyse kasıtlı
        // bir eylem olmuştur (oynat/duraklat/sar/video değişti).
        setState(() {
          _oda = _oda!.kopya(
            durum: akis.durum,
            video: akis.video,
            videoAd: akis.videoAd,
            videoSureMs: akis.videoSureMs,
          );
        });
        await _videoyuKur(akis.video);
        _duzelt(kasitli: true);
        degisti = true;
      } else {
        _duzelt();
      }
      if (akis.uyeler != null) {
        setState(() => _oda = _oda!.kopya(uyeler: akis.uyeler));
        degisti = true;
      }
      if (akis.mesajlar.isNotEmpty) {
        setState(() {
          for (final m in akis.mesajlar) {
            if (m.tepki != null && m.kullaniciId != _benimId) {
              _tepkiUcur(m.tepki!);
            }
            // Tepkiler sohbet listesine de girer ama YALNIZ uçuşurlar:
            // listeye eklemek 20 kişilik bir odada sohbeti emoji yağmuruna
            // çevirirdi. Metinli mesajlar ve sistem satırları listede durur.
            if (m.tepki == null) _mesajlar.add(m);
          }
        });
        _sonaKaydir();
        degisti = true;
      }
      if (!degisti && _kapandi) setState(() => _kapandi = false);
    } on ApiHata catch (e) {
      if (!mounted) return;
      if (e.makineKodu == OdaKod.odaKapandi || e.kod == 410) {
        _yoklama?.cancel();
        _oynatici?.pause();
        setState(() {
          _kapandi = true;
          _hata = 'Bu oda kapandı'.c;
        });
      }
      // Diğer hatalar SESSİZ: 1 sn'lik yoklamada geçici bir ağ tökezlemesi
      // için SnackBar basmak ekranı kullanılamaz hâle getirirdi.
    } finally {
      _yoklamaUcuyor = false;
    }
  }

  // -------------------------------------------------------------------------
  // OYNATICI
  // -------------------------------------------------------------------------

  Future<void> _videoyuKur(String? url) async {
    if (url == null || url == _kuruluVideo) return;
    _kuruluVideo = url;
    final eski = _oynatici;
    setState(() {
      _oynatici = null;
      _oynaticiHazir = false;
    });
    await eski?.dispose();
    final tam = dosyaUrl(url);
    if (tam == null) return;
    final d = VideoPlayerController.networkUrl(Uri.parse(tam));
    try {
      await d.initialize();
    } catch (_) {
      await d.dispose();
      if (mounted) _uyar('Video açılamadı'.c);
      return;
    }
    if (!mounted) {
      await d.dispose();
      return;
    }
    setState(() {
      _oynatici = d;
      _oynaticiHazir = true;
    });
    // "Hazırım" bayrağı: sahip üye listesinde kimin tamponladığını görür.
    OdaApi.hazir(widget.odaId, true).catchError((_) {});
    _duzelt(kasitli: true);
  }

  /// Yerel oynatıcıyı sunucudaki duruma yaklaştırır.
  void _duzelt({bool kasitli = false}) {
    final d = _oynatici;
    final oda = _oda;
    if (d == null || oda == null || !_oynaticiHazir || _sariyor) return;
    final durum = oda.durum;
    final sunucuSimdi = _sapma.sunucuAni(DateTime.now().millisecondsSinceEpoch);
    final sure = d.value.duration.inMilliseconds;
    final beklenen = beklenenKonum(
      durum,
      sunucuSimdi,
      sureMs: sure > 0 ? sure : oda.videoSureMs,
    );
    final yerel = d.value.position.inMilliseconds;

    // 1) OYNUYOR/DURDU eşitlemesi — konumdan ÖNCE. Duraklatılmış bir
    // oynatıcıda konum düzeltmesi anlamlı ama oynatma durumu yanlışsa
    // kullanıcı "video donmuş" görür.
    if (durum.oynuyor && !d.value.isPlaying) {
      d.play();
    } else if (!durum.oynuyor && d.value.isPlaying) {
      d.pause();
    }

    final karar = duzeltmeKarari(yerel, beklenen, kasitli: kasitli);
    switch (karar.tur) {
      case DuzeltmeTuru.yok:
        _hiziUygula(d, 1.0);
        break;
      case DuzeltmeTuru.hiz:
        // Duraklatılmışken hız düzeltmesinin anlamı yok (zaman akmıyor).
        if (durum.oynuyor) {
          _hiziUygula(d, karar.hiz);
        } else {
          _sar(d, beklenen);
        }
        break;
      case DuzeltmeTuru.sar:
        _hiziUygula(d, 1.0);
        _sar(d, karar.hedefMs);
        break;
    }
  }

  void _hiziUygula(VideoPlayerController d, double hiz) {
    if ((hiz - _uygulananHiz).abs() < 0.001) return;
    _uygulananHiz = hiz;
    d.setPlaybackSpeed(hiz).catchError((_) {});
  }

  Future<void> _sar(VideoPlayerController d, int hedefMs) async {
    _sariyor = true;
    try {
      await d.seekTo(Duration(milliseconds: hedefMs));
    } catch (_) {
      /* oynatıcı sökülmüş olabilir */
    } finally {
      _sariyor = false;
    }
  }

  // -------------------------------------------------------------------------
  // SAHİP KONTROLLERİ
  // -------------------------------------------------------------------------

  /// Sahibin bir eylemini sunucuya yazar ve YEREL durumu hemen günceller
  /// (iyimser): sahip kendi dokunuşunun sonucunu bir yoklama turu beklemeden
  /// görmeli.
  Future<void> _durumYaz({
    required bool oynuyor,
    required int konumMs,
    bool kalp = false,
  }) async {
    final oda = _oda;
    if (oda == null) return;
    try {
      final y = await OdaApi.durumYaz(
        widget.odaId,
        oynuyor: oynuyor,
        konumMs: konumMs,
        kalp: kalp,
      );
      if (!mounted) return;
      // Sunucunun damgaladığı `konum_zaman`ı ALIYORUZ: yerel saatle
      // damgalasaydık sahibin saati sapmışsa TÜM oda o sapma kadar kayardı.
      setState(() {
        _oda = oda.kopya(
          durum: OdaDurum(
            oynuyor: oynuyor,
            konumMs: konumMs,
            konumZaman:
                (y['konum_zaman'] as num?)?.toInt() ??
                _sapma.sunucuAni(DateTime.now().millisecondsSinceEpoch),
            surum: (y['surum'] as num?)?.toInt() ?? oda.durum.surum,
          ),
        );
      });
      _sapma.besle(
        istekBasi: DateTime.now().millisecondsSinceEpoch,
        yanitSonu: DateTime.now().millisecondsSinceEpoch,
        sunucuZaman:
            (y['sunucu_zaman'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      );
    } on ApiHata catch (e) {
      _uyar(odaHataMetni(e));
    }
  }

  void _kalbiKur(bool oynuyor) {
    _kalp?.cancel();
    if (!oynuyor || !_sahipMiyim) return;
    // Kalp atışı SÜRÜMÜ ARTIRMAZ (`kalp: true`): amaç yalnız `konum_zaman`ı
    // tazelemek. Artırsaydı izleyiciler her 10 saniyede bir "kasıtlı eylem"
    // sanıp seek eder, düzgün akan video zıplardı.
    _kalp = Timer.periodic(sahipKalpAraligi, (_) {
      final d = _oynatici;
      if (d == null || !d.value.isInitialized || !d.value.isPlaying) return;
      _durumYaz(
        oynuyor: true,
        konumMs: d.value.position.inMilliseconds,
        kalp: true,
      );
    });
  }

  Future<void> _oynatDurdur() async {
    final d = _oynatici;
    if (d == null || !_oynaticiHazir) return;
    final yeni = !(_oda?.durum.oynuyor ?? false);
    if (yeni) {
      await d.play();
    } else {
      await d.pause();
    }
    await _durumYaz(oynuyor: yeni, konumMs: d.value.position.inMilliseconds);
    _kalbiKur(yeni);
  }

  Future<void> _atla(int saniye) async {
    final d = _oynatici;
    if (d == null || !_oynaticiHazir) return;
    final sure = d.value.duration.inMilliseconds;
    var hedef = d.value.position.inMilliseconds + saniye * 1000;
    if (hedef < 0) hedef = 0;
    if (sure > 0 && hedef > sure) hedef = sure;
    await _sar(d, hedef);
    await _durumYaz(oynuyor: _oda?.durum.oynuyor ?? false, konumMs: hedef);
  }

  Future<void> _konumaSar(int hedefMs) async {
    final d = _oynatici;
    if (d == null || !_oynaticiHazir) return;
    await _sar(d, hedefMs);
    await _durumYaz(oynuyor: _oda?.durum.oynuyor ?? false, konumMs: hedefMs);
  }

  // -------------------------------------------------------------------------
  // VİDEO YÜKLEME (sahip)
  // -------------------------------------------------------------------------

  Future<void> _videoSec() async {
    FilePickerResult? secim;
    try {
      secim = await FilePicker.platform.pickFiles(
        type: FileType.video,
        // 5 GB'ı belleğe ALMIYORUZ: dosya dilimlenerek akıtılır.
        withReadStream: true,
        withData: false,
      );
    } catch (_) {
      _uyar('Dosya seçilemedi'.c);
      return;
    }
    final d = secim?.files.single;
    final akis = d?.readStream;
    if (d == null || akis == null || !mounted) return;
    if (d.size > odaVideoAzamiBayt) {
      _uyar('Video en fazla {} GB olabilir'.cf([odaVideoAzamiGb]));
      return;
    }
    final y = OdaVideoYukleyici(widget.odaId);
    setState(() {
      _yukleyici = y;
      _yuklemeDurumu = OdaYuklemeDurumu(gonderilen: 0, toplam: d.size);
    });
    try {
      final sonuc = await y.yukle(
        akis: akis,
        boyut: d.size,
        ad: d.name,
        ilerleme: (p) {
          if (mounted) setState(() => _yuklemeDurumu = p);
        },
      );
      if (!mounted) return;
      setState(() {
        _yukleyici = null;
        _yuklemeDurumu = null;
      });
      await _videoyuKur(sonuc.video);
      await _tamYenile();
    } on OdaYuklemeIptal {
      if (mounted) {
        setState(() {
          _yukleyici = null;
          _yuklemeDurumu = null;
        });
      }
    } on ApiHata catch (e) {
      if (!mounted) return;
      setState(() {
        _yukleyici = null;
        _yuklemeDurumu = null;
      });
      _uyar(odaHataMetni(e));
    }
  }

  // -------------------------------------------------------------------------
  // SOHBET / TEPKİ / DAVET
  // -------------------------------------------------------------------------

  void _sonaKaydir() {
    if (!_kaydirma.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_kaydirma.hasClients) return;
      _kaydirma.animateTo(
        _kaydirma.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _mesajGonder() async {
    final metin = _metin.text.trim();
    if (metin.isEmpty) return;
    _metin.clear();
    try {
      await OdaApi.mesaj(
        widget.odaId,
        metin: metin,
        konumMs: _oynatici?.value.position.inMilliseconds,
      );
      // Mesaj bir sonraki yoklamada (en çok 1 sn) listeye düşer; iyimser
      // eklemiyoruz çünkü sunucu id'yi o zaman veriyor ve çift satır riski
      // (iyimser + yoklama) sohbeti bozardı.
    } on ApiHata catch (e) {
      _uyar(odaHataMetni(e));
    }
  }

  Future<void> _tepkiGonder(String emoji) async {
    _tepkiUcur(emoji); // kendi tepkin ANINDA uçar, tur beklemez
    try {
      await OdaApi.mesaj(
        widget.odaId,
        tepki: emoji,
        konumMs: _oynatici?.value.position.inMilliseconds,
      );
    } on ApiHata catch (_) {
      /* tepki kaybolabilir; hata basmaya değmez */
    }
  }

  void _tepkiUcur(String emoji) {
    final id = _tepkiSayac++;
    final t = _UcusanTepki(
      id: id,
      emoji: emoji,
      sol: 0.1 + math.Random().nextDouble() * 0.8,
    );
    setState(() => _ucusan.add(t));
    Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _ucusan.removeWhere((e) => e.id == id));
    });
  }

  Future<void> _davetEt() async {
    final ad = await showDialog<String>(
      context: context,
      builder: (_) => const _DavetDialog(),
    );
    if (ad == null || ad.isEmpty) return;
    try {
      await OdaApi.davet(widget.odaId, ad);
      _uyar('@{} davet edildi'.cf([ad]));
      _tamYenile();
    } on ApiHata catch (e) {
      _uyar(odaHataMetni(e));
    }
  }

  Future<void> _kodKopyala() async {
    final kod = _oda?.kod;
    if (kod == null) return;
    await Clipboard.setData(ClipboardData(text: kod));
    _uyar('Oda kodu kopyalandı'.c);
  }

  Future<void> _cik() async {
    final sahip = _sahipMiyim;
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(sahip ? 'Odayı kapat'.c : 'Odadan ayrıl'.c),
        content: Text(
          sahip
              ? 'Oda kapanacak ve video silinecek. Bu geri alınamaz.'.c
              : 'Odadan çıkacaksın. Kodla ya da davetle geri dönebilirsin.'.c,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Vazgeç'.c),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(sahip ? 'Kapat'.c : 'Ayrıl'.c),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    try {
      if (sahip) {
        await OdaApi.kapat(widget.odaId);
      } else {
        await OdaApi.ayril(widget.odaId);
      }
      if (mounted) context.pop();
    } on ApiHata catch (e) {
      _uyar(odaHataMetni(e));
    }
  }

  // -------------------------------------------------------------------------
  // ÇİZİM
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final oda = _oda;
    if (_hata != null && oda == null) {
      return Scaffold(
        appBar: AppBar(title: Text('İzleme odası'.c)),
        body: BosDurum(
          ikon: _kapandi ? Icons.timer_off_outlined : Icons.error_outline,
          baslik: _hata!,
          ipucu: _kapandi
              ? 'Odalar 12 saat sonra kendiliğinden kapanır.'.c
              : null,
        ),
      );
    }
    if (oda == null) {
      return Scaffold(
        appBar: AppBar(title: Text('İzleme odası'.c)),
        body: const IskeletListe(adet: 4),
      );
    }
    final genis = MediaQuery.of(context).size.width >= _genisEsik;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              oda.baslik?.isNotEmpty == true
                  ? oda.baslik!
                  : '@{} odası'.cf([oda.sahip]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              '{} kişi · {} kaldı'.cf([
                oda.uyeler.where((u) => !u.bekliyor).length,
                odaSureKisa(oda.biter - DateTime.now().millisecondsSinceEpoch),
              ]),
              style: TextStyle(fontSize: 11, color: DiziRenkler.metin54),
            ),
          ],
        ),
        actions: [
          _KodRozeti(kod: oda.kod, onTap: _kodKopyala),
          if (_sahipMiyim)
            IconButton(
              tooltip: 'Davet et'.c,
              onPressed: _davetEt,
              icon: const Icon(Icons.person_add_alt_1_outlined),
            ),
          IconButton(
            tooltip: _sahipMiyim ? 'Odayı kapat'.c : 'Odadan ayrıl'.c,
            onPressed: _cik,
            icon: Icon(_sahipMiyim ? Icons.delete_outline : Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: genis
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, k) => _videoBolumu(
                        oda,
                        videoTavan: _videoTavani(k.maxHeight, sohbetAyri: true),
                      ),
                    ),
                  ),
                  SizedBox(width: 340, child: _sohbet(oda)),
                ],
              )
            // DAR EKRAN: video ve sohbet AYNI dikey alanı paylaşır, yani
            // videonun boyu sohbeti EZEBİLİR. 3 Eyl 2026'da widget testi tam
            // bunu yakaladı: 800×600'de 16:9 video 450 dp yiyor, kontroller ve
            // tepki şeridiyle birlikte sohbete 46 dp kalıyor ve Column TAŞIYOR
            // (sarı-siyah şerit). Bu yüzden videonun tavanı KALAN YERDEN
            // hesaplanır, sabit bir orandan değil.
            : LayoutBuilder(
                builder: (context, k) => Column(
                  children: [
                    _videoBolumu(oda, videoTavan: _videoTavani(k.maxHeight)),
                    Expanded(child: _sohbet(oda)),
                  ],
                ),
              ),
      ),
    );
  }

  /// Video yüzeyinin AZAMİ boyu.
  ///
  /// Sohbete ayrılan pay ÖNCE düşülür: video kendi en-boy oranını dayatıp
  /// sohbeti sıfıra indiremez. Geniş ekranda sohbet ayrı sütunda olduğu için
  /// videoya neredeyse tüm yükseklik kalır.
  double _videoTavani(double yukseklik, {bool sohbetAyri = false}) {
    if (!yukseklik.isFinite || yukseklik <= 0) return 240;
    // Kontroller + tepki şeridi. Sahipte oynat/sar satırı da var, izleyicide
    // yalnız tek satırlık "eşleniyor" göstergesi.
    final kontrolPayi = _sahipMiyim ? 150.0 : 110.0;
    if (sohbetAyri) return math.max(120.0, yukseklik - kontrolPayi);
    // Sohbete en az bu kadar: üye şeridi + yazı alanı + birkaç satır balon.
    const sohbetAsgari = 170.0;
    final kalan = yukseklik - kontrolPayi - sohbetAsgari;
    return kalan.clamp(120.0, yukseklik * 0.62);
  }

  Widget _videoBolumu(Oda oda, {required double videoTavan}) {
    final d = _oynatici;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Zemin TAM GENİŞLİK ve siyah; video oranını koruyarak İÇİNE
            // sığar. Tavan devreye girince yanlarda siyah bant kalır
            // (letterbox) — kırpmaktansa bant: kadraj bozulmasın.
            Container(
              width: double.infinity,
              color: Colors.black,
              constraints: BoxConstraints(maxHeight: videoTavan),
              alignment: Alignment.center,
              child: AspectRatio(
                aspectRatio: d != null && _oynaticiHazir
                    ? d.value.aspectRatio
                    : 16 / 9,
                child: d != null && _oynaticiHazir
                    ? VideoPlayer(d)
                    : _videoYerine(oda),
              ),
            ),
            // Uçuşan tepkiler videonun ÜSTÜNDE ama dokunmayı YUTMAZ
            // (IgnorePointer): oynatma kontrolleri hep erişilebilir kalmalı.
            Positioned.fill(
              child: IgnorePointer(
                child: Stack(
                  children: [for (final t in _ucusan) _ucusanCiz(t)],
                ),
              ),
            ),
          ],
        ),
        if (_yuklemeDurumu != null) _yuklemeCubugu(_yuklemeDurumu!),
        if (d != null && _oynaticiHazir) _kontroller(oda, d),
        _tepkiSeridi(),
      ],
    );
  }

  Widget _videoYerine(Oda oda) {
    if (_yuklemeDurumu != null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (oda.video != null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.movie_outlined,
              size: 42,
              color: Colors.white.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 10),
            Text(
              _sahipMiyim
                  ? 'Bir video yükle, izlemeye başlayın'.c
                  : 'Oda sahibi henüz video yüklemedi'.c,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
            ),
            if (_sahipMiyim) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: FilledButton.icon(
                  onPressed: _videoSec,
                  icon: const Icon(Icons.upload_outlined, size: 20),
                  label: Text('Video yükle'.c),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'En fazla {} GB · MP4 veya WebM'.cf([odaVideoAzamiGb]),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _yuklemeCubugu(OdaYuklemeDurumu p) {
    final mb = (p.toplam / (1024 * 1024)).round();
    final gonderilenMb = (p.gonderilen / (1024 * 1024)).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  // İlerleme SAYIYLA da yazılır: yalnız çubuk "ne kadar
                  // kaldı" sorusunu 5 GB'lık bir yüklemede cevaplamaz
                  // (ui-ux-pro-max, Feedback/Progress Indicators).
                  p.devam
                      ? 'Kaldığı yerden yükleniyor · {}/{} MB'.cf([
                          gonderilenMb,
                          mb,
                        ])
                      : 'Yükleniyor · {}/{} MB'.cf([gonderilenMb, mb]),
                  style: TextStyle(fontSize: 12, color: DiziRenkler.metin54),
                ),
              ),
              Text(
                '%{}'.cf([p.yuzde]),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                child: TextButton(
                  onPressed: () => _yukleyici?.iptal(),
                  child: Text('Vazgeç'.c),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: p.oran,
              minHeight: 6,
              color: DiziRenkler.sari,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kontroller(Oda oda, VideoPlayerController d) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: d,
      builder: (context, deger, _) {
        final sure = deger.duration.inMilliseconds;
        final konum = deger.position.inMilliseconds
            .clamp(0, math.max(sure, 1))
            .toInt();
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    odaKonumBicim(konum),
                    style: TextStyle(
                      fontSize: 11,
                      color: DiziRenkler.metin54,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Expanded(
                    child: _sahipMiyim
                        ? Slider(
                            value: sure > 0
                                ? konum.toDouble().clamp(0, sure.toDouble())
                                : 0,
                            max: sure > 0 ? sure.toDouble() : 1,
                            onChanged: (v) => _sar(d, v.round()),
                            onChangeEnd: (v) => _konumaSar(v.round()),
                          )
                        // İZLEYİCİ: salt okunur çubuk. Slider verilseydi
                        // dokunan kişi kendi videosunu kaydırır ve bir sonraki
                        // düzeltmede geri zıplardı — "bozuk" hissi verirdi.
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: sure > 0 ? konum / sure : 0,
                                minHeight: 4,
                                color: DiziRenkler.sari,
                              ),
                            ),
                          ),
                  ),
                  Text(
                    odaKonumBicim(sure),
                    style: TextStyle(
                      fontSize: 11,
                      color: DiziRenkler.metin54,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              if (_sahipMiyim)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: '10 saniye geri'.c,
                      onPressed: () => _atla(-10),
                      icon: const Icon(Icons.replay_10),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: oda.durum.oynuyor ? 'Duraklat'.c : 'Oynat'.c,
                      onPressed: _oynatDurdur,
                      icon: Icon(
                        oda.durum.oynuyor ? Icons.pause : Icons.play_arrow,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: '10 saniye ileri'.c,
                      onPressed: () => _atla(10),
                      icon: const Icon(Icons.forward_10),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 44,
                      child: TextButton.icon(
                        onPressed: _videoSec,
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        label: Text('Videoyu değiştir'.c),
                      ),
                    ),
                  ],
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.sync,
                        size: 14,
                        color: DiziRenkler.cevrimiciYesil,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Oda sahibiyle eşleniyor'.c,
                        style: TextStyle(
                          fontSize: 11,
                          color: DiziRenkler.metin54,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _tepkiSeridi() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: [
          for (final e in const [
            '❤️',
            '😂',
            '😮',
            '😢',
            '🔥',
            '👏',
            '👀',
            '💀',
          ])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: () => _tepkiGonder(e),
                borderRadius: BorderRadius.circular(22),
                // 44×44 dokunma hedefi (ui-ux-pro-max, Touch Target Size);
                // aradaki 4 px + iç dolgu 8 px boşluk kuralını karşılar.
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Text(e, style: const TextStyle(fontSize: 22)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ucusanCiz(_UcusanTepki t) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(t.id),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 2500),
      curve: Curves.easeOut,
      builder: (context, v, _) => Align(
        alignment: Alignment(t.sol * 2 - 1, 1 - v * 1.7),
        child: Opacity(
          opacity: (1 - v).clamp(0.0, 1.0),
          child: Text(t.emoji, style: const TextStyle(fontSize: 30)),
        ),
      ),
    );
  }

  Widget _sohbet(Oda oda) {
    return LayoutBuilder(
      builder: (context, k) => Column(
        children: [
          // Alan gerçekten darsa (yatay telefon) üye şeridi DÜŞER: mesajlar ve
          // yazı alanı ondan önce gelir. Şerit sabit dursaydı Column taşardı.
          if (k.maxHeight > 200) _uyeSeridi(oda),
          Expanded(
            child: _mesajlar.isEmpty
                // BOŞ DURUM KAYDIRILABİLİR bir listenin içinde: `BosDurum`
                // ikon + iki satır metinle ~130 dp ister ve sohbet alanı yatay
                // telefonda bunun altına düşebilir. Doğrudan konsaydı Column
                // TAŞARDI (3 Eyl 2026, widget testi yakaladı); ListView'in
                // içinde en fazla kaydırılır.
                ? ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      BosDurum(
                        ikon: Icons.forum_outlined,
                        baslik: 'Sohbet boş'.c,
                        ipucu: 'İzlerken buradan konuşabilirsiniz.'.c,
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _kaydirma,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: _mesajlar.length,
                    itemBuilder: (context, i) => _MesajSatiri(
                      key: ValueKey(_mesajlar[i].id),
                      mesaj: _mesajlar[i],
                      benim: _mesajlar[i].kullaniciId == _benimId,
                    ),
                  ),
          ),
          _yaziAlani(),
        ],
      ),
    );
  }

  Widget _uyeSeridi(Oda oda) {
    return SizedBox(
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: oda.uyeler.length,
        itemBuilder: (context, i) {
          final u = oda.uyeler[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Tooltip(
              message: [
                '@${u.ad}',
                if (u.sahip) 'oda sahibi'.c,
                if (u.bekliyor)
                  'davet bekliyor'.c
                else if (u.cevrimici)
                  'çevrimiçi'.c
                else
                  'çevrimdışı'.c,
              ].join(' · '),
              child: Stack(
                children: [
                  Opacity(
                    // Bekleyen davet SOLUK: listede duruyor ama "burada"
                    // değil. Hiç göstermemek sahibin kimi davet ettiğini
                    // unutmasına yol açardı.
                    opacity: u.bekliyor ? 0.4 : 1,
                    child: KullaniciAvatari(
                      url: dosyaUrl(u.avatar),
                      kullaniciAdi: u.ad,
                      yaricap: 18,
                    ),
                  ),
                  if (!u.bekliyor && u.cevrimici)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: DiziRenkler.cevrimiciYesil,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: DiziRenkler.koyuGri,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  if (u.sahip)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Icon(
                        Icons.star,
                        size: 12,
                        color: DiziRenkler.sariMetin,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _yaziAlani() {
    return Padding(
      padding: EdgeInsets.only(
        left: 10,
        right: 10,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _metin,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _mesajGonder(),
              decoration: InputDecoration(
                hintText: 'Mesaj yaz...'.c,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Gönder düğmesi TextField'ın suffixIcon'una KONMAZ: erişilebilirlik
          // servisi açıkken `_mergeSiblingGroup` sonsuz özyinelemeye giriyor
          // (1.115.0'da düzeltilen ANR). Düğme satır KARDEŞİ kalmalı.
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              onPressed: _mesajGonder,
              icon: Icon(Icons.send, color: DiziRenkler.sariMetin),
              tooltip: 'Gönder'.c,
            ),
          ),
        ],
      ),
    );
  }
}

class _UcusanTepki {
  final int id;
  final String emoji;

  /// 0..1 arası yatay konum.
  final double sol;
  const _UcusanTepki({
    required this.id,
    required this.emoji,
    required this.sol,
  });
}

/// Başlıktaki oda kodu rozeti — dokununca panoya kopyalar.
class _KodRozeti extends StatelessWidget {
  final String kod;
  final VoidCallback onTap;
  const _KodRozeti({required this.kod, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Oda kodunu kopyala'.c,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Semantics(
          button: true,
          label: 'Oda kodu {} — kopyala'.cf([kod]),
          child: Container(
            height: 44,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Text(
                  kod,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: DiziRenkler.sariMetin,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.copy, size: 14, color: DiziRenkler.metin54),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MesajSatiri extends StatelessWidget {
  final OdaMesaj mesaj;
  final bool benim;
  const _MesajSatiri({super.key, required this.mesaj, required this.benim});

  @override
  Widget build(BuildContext context) {
    if (mesaj.sistem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Text(
            mesaj.sistemMetni(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: DiziRenkler.metin38),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KullaniciAvatari(
            url: dosyaUrl(mesaj.avatar),
            kullaniciAdi: mesaj.ad,
            yaricap: 14,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        mesaj.ad ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: benim
                              ? DiziRenkler.sariMetin
                              : DiziRenkler.metin70,
                        ),
                      ),
                    ),
                    if (mesaj.konumMs != null) ...[
                      const SizedBox(width: 6),
                      // Videonun kaçıncı anında yazıldığı: sohbeti sahneye
                      // bağlar ("burada güldüm"). Sunucu bunu zaten kaydediyor.
                      Text(
                        odaKonumBicim(mesaj.konumMs!),
                        style: TextStyle(
                          fontSize: 10,
                          color: DiziRenkler.metin38,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  mesaj.metin ?? '',
                  style: const TextStyle(fontSize: 14, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DavetDialog extends StatefulWidget {
  const _DavetDialog();

  @override
  State<_DavetDialog> createState() => _DavetDialogState();
}

class _DavetDialogState extends State<_DavetDialog> {
  final _ad = TextEditingController();

  @override
  void dispose() {
    _ad.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Arkadaşını davet et'.c),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ad,
            autofocus: true,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'kullanıcı adı'.c,
              prefixText: '@',
            ),
            onSubmitted: (v) => Navigator.pop(context, v.trim()),
          ),
          const SizedBox(height: 8),
          Text(
            'Yalnız karşılıklı takipleştiğin kişileri davet edebilirsin.'.c,
            style: TextStyle(fontSize: 12, color: DiziRenkler.metin54),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Vazgeç'.c),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ad.text.trim()),
          child: Text('Davet et'.c),
        ),
      ],
    );
  }
}
