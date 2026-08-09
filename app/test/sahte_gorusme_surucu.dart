import 'dart:async';

import 'package:dizijpg/gorusme/gorusme_surucu.dart';
import 'package:flutter/material.dart';

/// Testler için sahte medya sürücüsü.
///
/// NEDEN GEREKLİ: `flutter_webrtc` bir eklentidir ve `flutter test` VM'de
/// koşar — gerçek `RTCPeerConnection` kurulamaz. Denetçinin kritik kararı
/// (`POST /arama/bitir`in `sebep` alanı) medya katmanının hâline bağlı
/// olduğu için, o hâli buradan ELLE sürüyoruz.
class SahteSurucu implements GorusmeSurucu {
  final _denetleyici = StreamController<BaglantiHali>.broadcast();

  bool kuruldu = false;
  bool kapatildi = false;
  bool goruntuIstendi = false;
  bool sonSessiz = false;
  bool sonKamera = true;
  bool sonHoparlor = false;
  int kameraCevirmeSayisi = 0;
  String? uygulananCevap;
  int uzakCevapCagrisi = 0;

  /// [kur] çağrısında fırlatılacak hata (izin reddi benzetimi).
  Object? kurHatasi;

  /// `olcumAl()` sonucu.
  GorusmeOlcum? olcum = const GorusmeOlcum(
    roleDustu: true,
    baytGonderilen: 1000,
    baytAlinan: 2000,
  );

  void hal(BaglantiHali h) => _denetleyici.add(h);

  @override
  Stream<BaglantiHali> get haller => _denetleyici.stream;

  @override
  Future<void> kur({
    required List<Map<String, dynamic>> buzSunuculari,
    required bool goruntu,
  }) async {
    if (kurHatasi != null) throw kurHatasi!;
    kuruldu = true;
    goruntuIstendi = goruntu;
  }

  @override
  Future<String> teklifUret() async => 'v=0\r\nteklif';

  @override
  Future<String> cevapUret(String uzakTeklif) async => 'v=0\r\ncevap';

  @override
  Future<void> uzakCevabiUygula(String sdp) async {
    uzakCevapCagrisi++;
    uygulananCevap = sdp;
  }

  @override
  Future<void> sessizeAl(bool sessiz) async => sonSessiz = sessiz;

  @override
  Future<void> kamerayiAc(bool acik) async => sonKamera = acik;

  @override
  Future<void> kamerayiCevir() async => kameraCevirmeSayisi++;

  @override
  Future<void> hoparlor(bool acik) async => sonHoparlor = acik;

  @override
  Future<GorusmeOlcum?> olcumAl() async => olcum;

  @override
  Future<void> kapat() async {
    kapatildi = true;
    await _denetleyici.close();
  }

  @override
  Widget? gorunum({required bool yerel}) => null;
}
