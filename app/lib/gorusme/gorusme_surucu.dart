import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Medya katmanının bağlantı hâli. `RTCPeerConnectionState`'in istemcinin
/// umursadığı üç hâle indirgenmiş hâli — ekran ve denetçi WebRTC türlerini
/// hiç görmez, böylece ikisi de eklentisiz test edilebilir.
enum BaglantiHali {
  /// Henüz kurulmadı ya da kuruluyor.
  bekliyor,

  /// Medya akıyor. **Bu ana kadar hiç ulaşılmadıysa `ice_basarisiz`.**
  bagli,

  /// ICE kalıcı olarak başarısız oldu.
  koptu,
}

/// `getStats()`ten toplanan, `POST /arama/bitir`in `olcum` alanına giden
/// ölçüm. **İstemci beyanıdır ve sunucu buna güvenmez** (sözleşme §4.7);
/// faturaya değil kendi kapasite planlamamıza girer.
class GorusmeOlcum {
  /// Seçili aday çiftinin türü `relay` mi — röle oranı ölçümünün kaynağı.
  final bool roleDustu;
  final int baytGonderilen;
  final int baytAlinan;

  const GorusmeOlcum({
    required this.roleDustu,
    required this.baytGonderilen,
    required this.baytAlinan,
  });

  Map<String, dynamic> get json => {
    'role_dustu': roleDustu,
    'bayt_gonderilen': baytGonderilen,
    'bayt_alinan': baytAlinan,
  };
}

/// Medya/eş bağlantısı soyutlaması.
///
/// NEDEN SOYUT: `flutter_webrtc` bir eklentidir; `flutter test` VM'de koşar ve
/// eklenti kanalı yoktur. Denetçinin kritik kararı — `POST /arama/bitir`in
/// `sebep` alanı — medya katmanının hâline bağlı, yani test edilemezse
/// **sessizce bozulabilecek** tek karar odur (sözleşme §13.1). Bu arayüz
/// sayesinde denetçi sahte bir sürücüyle uçtan uca sınanabiliyor.
abstract class GorusmeSurucu {
  /// Bağlantı hâli değişimleri. Denetçi buradan `bagli`/`koptu` görür.
  Stream<BaglantiHali> get haller;

  /// Eş bağlantısını kurar ve yerel medyayı açar.
  /// [goruntu] false ise yalnız mikrofon açılır (kamera izni İSTENMEZ).
  Future<void> kur({
    required List<Map<String, dynamic>> buzSunuculari,
    required bool goruntu,
  });

  /// Teklif üretir ve **ICE toplama bitene kadar bekler** (trickle YOK,
  /// sözleşme §1); dönen SDP tüm adayları içerir.
  Future<String> teklifUret();

  /// Uzak teklifi uygular, cevap üretir ve ICE toplamayı bekler.
  Future<String> cevapUret(String uzakTeklif);

  /// Arayanın yoklamada aldığı cevap SDP'si. **İdempotent:** aynı SDP ikinci
  /// kez gelirse yok sayılır (sözleşme §4.3).
  Future<void> uzakCevabiUygula(String sdp);

  Future<void> sessizeAl(bool sessiz);
  Future<void> kamerayiAc(bool acik);
  Future<void> kamerayiCevir();
  Future<void> hoparlor(bool acik);

  /// Kapatmadan ÖNCE çağrılır; bağlantı kapandıktan sonra sayaçlar gider.
  Future<GorusmeOlcum?> olcumAl();

  Future<void> kapat();

  /// Video görünümü ([yerel] false ise karşı taraf). Sesli aramada ve sahte
  /// sürücüde null döner — çağıran null'ı çizmez.
  Widget? gorunum({required bool yerel});
}

/// ICE toplamanın bitmesi için beklenecek en uzun süre.
///
/// NEDEN ÜST SINIR VAR: `iceGatheringState == complete` bazı ağlarda (TURN
/// ulaşılamıyorsa, IPv6 yalnızca ağlarda) hiç gelmez ya da çok gecikir.
/// Sınırsız beklemek "arama tuşuna bastım, hiçbir şey olmadı" demektir.
/// Süre dolunca elde toplanmış adaylarla devam edilir: eksik aday çiftiyle
/// bağlanma ihtimali, hiç davet göndermemekten daima yüksektir.
const Duration buzToplamaSuresi = Duration(seconds: 6);

/// `flutter_webrtc` tabanlı gerçek sürücü.
class WebrtcSurucu implements GorusmeSurucu {
  RTCPeerConnection? _es;
  MediaStream? _yerel;
  MediaStream? _uzak;
  RTCVideoRenderer? _yerelCizer;
  RTCVideoRenderer? _uzakCizer;
  bool _goruntu = false;
  bool _onKamera = true;
  bool _uzakCevapUygulandi = false;

  final _haller = StreamController<BaglantiHali>.broadcast();

  @override
  Stream<BaglantiHali> get haller => _haller.stream;

  @override
  Future<void> kur({
    required List<Map<String, dynamic>> buzSunuculari,
    required bool goruntu,
  }) async {
    _goruntu = goruntu;
    final es = await createPeerConnection({
      'iceServers': buzSunuculari,
      // Unified Plan: tek yönlü sdpSemantics 'plan-b' emekli ve web'de yok.
      'sdpSemantics': 'unified-plan',
    });
    _es = es;
    es.onConnectionState = (durum) {
      switch (durum) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _haller.add(BaglantiHali.bagli);
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          _haller.add(BaglantiHali.koptu);
        default:
          break;
      }
    };
    es.onTrack = (olay) {
      if (olay.streams.isEmpty) return;
      _uzak = olay.streams.first;
      _uzakCizer?.srcObject = _uzak;
    };

    _yerel = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      // Sesli aramada 'video': false — KAMERA İZNİ HİÇ İSTENMEZ.
      'video': goruntu
          ? {
              'facingMode': 'user',
              'width': {'ideal': 640},
              'height': {'ideal': 480},
            }
          : false,
    });
    for (final iz in _yerel!.getTracks()) {
      await es.addTrack(iz, _yerel!);
    }
    if (goruntu) {
      _yerelCizer = RTCVideoRenderer();
      await _yerelCizer!.initialize();
      _yerelCizer!.srcObject = _yerel;
      _uzakCizer = RTCVideoRenderer();
      await _uzakCizer!.initialize();
      _uzakCizer!.srcObject = _uzak;
    }
  }

  /// `iceGatheringState == complete` olmasını bekler; [buzToplamaSuresi]
  /// dolarsa eldekiyle devam eder.
  Future<void> _buzToplamayiBekle(RTCPeerConnection es) async {
    if (es.iceGatheringState ==
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      return;
    }
    final tamam = Completer<void>();
    es.onIceGatheringState = (durum) {
      if (durum == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !tamam.isCompleted) {
        tamam.complete();
      }
    };
    await tamam.future.timeout(buzToplamaSuresi, onTimeout: () {});
  }

  @override
  Future<String> teklifUret() async {
    final es = _es!;
    final teklif = await es.createOffer({});
    await es.setLocalDescription(teklif);
    await _buzToplamayiBekle(es);
    return (await es.getLocalDescription())?.sdp ?? teklif.sdp!;
  }

  @override
  Future<String> cevapUret(String uzakTeklif) async {
    final es = _es!;
    await es.setRemoteDescription(RTCSessionDescription(uzakTeklif, 'offer'));
    final cevap = await es.createAnswer({});
    await es.setLocalDescription(cevap);
    await _buzToplamayiBekle(es);
    return (await es.getLocalDescription())?.sdp ?? cevap.sdp!;
  }

  @override
  Future<void> uzakCevabiUygula(String sdp) async {
    // İDEMPOTENT: sunucu cevabı bir kez verir ama ağ hatasında yoklama aynı
    // paketi iki kez okuyabilir; ikinci `setRemoteDescription` yanlış
    // durumda çağrıldığı için istisna fırlatır ve aramayı düşürürdü.
    if (_uzakCevapUygulandi) return;
    _uzakCevapUygulandi = true;
    await _es!.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
  }

  @override
  Future<void> sessizeAl(bool sessiz) async {
    for (final iz in _yerel?.getAudioTracks() ?? const []) {
      iz.enabled = !sessiz;
    }
  }

  @override
  Future<void> kamerayiAc(bool acik) async {
    for (final iz in _yerel?.getVideoTracks() ?? const []) {
      iz.enabled = acik;
    }
  }

  @override
  Future<void> kamerayiCevir() async {
    final izler = _yerel?.getVideoTracks() ?? const <MediaStreamTrack>[];
    if (izler.isEmpty) return;
    _onKamera = !_onKamera;
    await Helper.switchCamera(izler.first);
  }

  @override
  Future<void> hoparlor(bool acik) => Helper.setSpeakerphoneOn(acik);

  @override
  Future<GorusmeOlcum?> olcumAl() async {
    final es = _es;
    if (es == null) return null;
    try {
      final raporlar = await es.getStats();
      var role = false;
      var gonderilen = 0;
      var alinan = 0;
      // Seçili aday çifti: `candidate-pair` içinde `nominated`/`selected`
      // olan. Yerel adayın türü `relay` ise medya TURN üzerinden akıyor.
      String? yerelAdayId;
      for (final r in raporlar) {
        if (r.type == 'candidate-pair' &&
            (r.values['nominated'] == true || r.values['selected'] == true) &&
            (r.values['state'] == 'succeeded' || r.values['state'] == null)) {
          yerelAdayId = r.values['localCandidateId'] as String?;
          gonderilen += (r.values['bytesSent'] as num?)?.toInt() ?? 0;
          alinan += (r.values['bytesReceived'] as num?)?.toInt() ?? 0;
        }
      }
      for (final r in raporlar) {
        if (r.type == 'local-candidate' && r.id == yerelAdayId) {
          role = r.values['candidateType'] == 'relay';
        }
      }
      // Aday çiftinden bayt gelmediyse (bazı platformlarda boş) akış
      // sayaçlarına düş.
      if (gonderilen == 0 && alinan == 0) {
        for (final r in raporlar) {
          if (r.type == 'outbound-rtp') {
            gonderilen += (r.values['bytesSent'] as num?)?.toInt() ?? 0;
          }
          if (r.type == 'inbound-rtp') {
            alinan += (r.values['bytesReceived'] as num?)?.toInt() ?? 0;
          }
        }
      }
      return GorusmeOlcum(
        roleDustu: role,
        baytGonderilen: gonderilen,
        baytAlinan: alinan,
      );
    } catch (_) {
      // Ölçüm alınamadıysa arama yine de TEMİZ kapatılmalı: `olcum` boş
      // gider, `sebep` yine doğru gider.
      return null;
    }
  }

  @override
  Future<void> kapat() async {
    try {
      for (final iz in _yerel?.getTracks() ?? const []) {
        await iz.stop();
      }
      await _yerel?.dispose();
      await _yerelCizer?.dispose();
      await _uzakCizer?.dispose();
      await _es?.close();
      await _es?.dispose();
    } catch (_) {
      // Kapatma en son çare yolu; burada patlamak aramanın bitmesini
      // engellememeli.
    }
    _es = null;
    _yerel = null;
    _uzak = null;
    _yerelCizer = null;
    _uzakCizer = null;
    await _haller.close();
  }

  @override
  Widget? gorunum({required bool yerel}) {
    if (!_goruntu) return null;
    final cizer = yerel ? _yerelCizer : _uzakCizer;
    if (cizer == null) return null;
    return RTCVideoView(
      cizer,
      mirror: yerel && _onKamera,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }
}
