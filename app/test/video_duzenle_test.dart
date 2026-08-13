import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dizijpg/ekranlar/medya_inceleme.dart';
import 'package:dizijpg/ekranlar/video_duzenle.dart';
import 'package:dizijpg/video_islem.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'gercek_video_baslik.dart';

/// Video kırpma (trim) + otomatik sıkıştırma (MEDYA-EDITOR-PLANI §V1).
///
/// CLAUDE.md md.7: etkileşimli widget'a dokunduysan KANIT ZORUNLU.
/// Bu dosya sekiz soruya cevap veriyor:
/// 1. Tutamakla seçilen aralık ÇIKTIYA gerçekten yansıyor mu?
/// 2. İptal GERÇEKTEN iptal ediyor mu ve geçici dosyayı SİLİYOR mu?
/// 3. İlerleme yüzdesi çiziliyor mu?
/// 4. Çıktının sihirli baytı sunucunun kapısından geçiyor mu (m4a tuzağı)?
/// 5. Boyut sınırları (girdi 300 MB, çıktı 100 MB) nasıl davranıyor?
/// 6. Otomatik sıkıştırma NE ZAMAN çalışıyor, ne zaman hiç çalışmıyor?
/// 7. Fotoğrafta video editörü açılmıyor, videoda görsel editörü açılmıyor mu?
/// 8. Web yolunda (motor yok) her şey düzgünce devre dışı mı?
///
/// Motor (`pro_video_editor` → Media3/AVFoundation) sahteleniyor: paketin iç
/// davranışı bizim testimizin konusu değil, BİZİM akışımız konu.

/// Geçerli 1×1 PNG — kare şeridi ve önizleme bunu çizer.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
  '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

Uint8List _bas(List<int> b) =>
    Uint8List.fromList([...b, ...List.filled(16 - b.length, 0)]);

/// `.... f t y p i s o m` — Media3 muxer çıktısının başı.
final _mp4Bas = _bas([
  0, 0, 0, 0x18, //
  0x66, 0x74, 0x79, 0x70, // ftyp
  0x69, 0x73, 0x6F, 0x6D, // isom
]);

/// `.... f t y p M 4 A ` — sunucuda **SES** sayılır (`server.js:3155`),
/// dosya `.m4a` olur ve video kaybolur. Kabul EDİLMEMELİ.
final _m4aBas = _bas([
  0, 0, 0, 0x18, //
  0x66, 0x74, 0x79, 0x70, // ftyp
  0x4D, 0x34, 0x41, 0x20, // M4A
]);

final _webmBas = _bas([0x1A, 0x45, 0xDF, 0xA3]);

class _Is {
  final String gorev;
  final String kaynak;
  final String hedef;
  final Duration? bas;
  final Duration? bit;
  final bool ses;
  final double olcek;
  final int? bitHizi;
  const _Is({
    required this.gorev,
    required this.kaynak,
    required this.hedef,
    required this.bas,
    required this.bit,
    required this.ses,
    required this.olcek,
    required this.bitHizi,
  });
}

/// Sahte video motoru. Gerçek Media3'e HİÇBİR test bağlı değildir.
class _SahteMotor implements VideoIsleyici {
  _SahteMotor({
    this.girdiBayt = 4 * 1024 * 1024,
    this.ciktiBayt = 2 * 1024 * 1024,
    Uint8List? ciktiBas,
    Uint8List? kaynakVeri,
    this.bilgiVeri = const VideoBilgi(
      sure: Duration(seconds: 60),
      genislik: 1080,
      yukseklik: 1920,
    ),
    this.elleBiter = false,
    this.patlar = false,
    this.iptalTamamlar = true,
  }) : ciktiBas = ciktiBas ?? _mp4Bas,
       // Varsayılan kaynak GERÇEK bir H.264 MP4: kodek kapısı eklendikten
       // sonra da eski testlerin anlamı değişmesin (H.264 = dokunulmaz).
       kaynakVeri = kaynakVeri ?? gercekH264;

  final int girdiBayt;
  final int ciktiBayt;
  final Uint8List ciktiBas;

  /// KAYNAK dosyanın baytları — `videoKodegi` bunu okur.
  final Uint8List kaynakVeri;
  final VideoBilgi? bilgiVeri;

  /// true → [isle] bir Completer bekler; ancak [iptal] ya da [bitir] onu
  /// tamamlar. İptal ve ilerleme testleri bunu kullanır.
  final bool elleBiter;
  final bool patlar;

  /// false → [iptal] işi HEMEN bitirmez (gerçek motorda da iptal anlık
  /// değildir); "İptal ediliyor…" ara hâli böyle gözlemlenebilir.
  final bool iptalTamamlar;

  final List<_Is> isler = [];
  final List<String> silinenler = [];
  final List<String> iptaller = [];
  final _ilerlemeler = StreamController<double>.broadcast();
  Completer<String?>? _bekleyen;
  int _sayac = 0;

  void ilerlemeYolla(double o) => _ilerlemeler.add(o);

  void bitir(String? yol) => _bekleyen?.complete(yol);

  @override
  Future<VideoBilgi?> bilgi(String yol) async => bilgiVeri;

  @override
  Future<List<Uint8List>> kareler(
    String yol, {
    required int adet,
    required Duration bas,
    required Duration bit,
    int boy = 96,
  }) async => [for (var i = 0; i < adet; i++) _png];

  @override
  Stream<double> ilerleme(String gorevKimlik) => _ilerlemeler.stream;

  @override
  Future<String?> isle({
    required String gorevKimlik,
    required String kaynak,
    required String hedef,
    Duration? bas,
    Duration? bit,
    bool ses = true,
    double olcek = 1,
    int? bitHizi,
  }) {
    isler.add(
      _Is(
        gorev: gorevKimlik,
        kaynak: kaynak,
        hedef: hedef,
        bas: bas,
        bit: bit,
        ses: ses,
        olcek: olcek,
        bitHizi: bitHizi,
      ),
    );
    if (patlar) return Future.error(Exception('kodlayıcı patladı'));
    if (!elleBiter) return Future.value(hedef);
    return (_bekleyen = Completer<String?>()).future;
  }

  @override
  Future<void> iptal(String gorevKimlik) async {
    iptaller.add(gorevKimlik);
    // Gerçek motor `RenderCanceledException` fırlatır, `video_islem_io`
    // onu `null`a çevirir — burada aynı sözleşme taklit ediliyor.
    if (iptalTamamlar) _bekleyen?.complete(null);
  }

  @override
  Future<String> geciciYol(String uzanti) async =>
      '/gecici/v${_sayac++}.$uzanti';

  @override
  Future<Uint8List> parca(String yol, {int bas = 0, int adet = 16}) async {
    // Kaynak yolu için GERÇEK bir MP4 kutu ağacı sunulur ki `videoKodegi`
    // sahte motorla da ölçülebilsin; çıktı yolu için sihirli baytlar.
    final tam = yol.startsWith('/gecici/') ? ciktiBas : kaynakVeri;
    if (bas >= tam.length) return Uint8List(0);
    final son = math.min(tam.length, bas + adet);
    return Uint8List.sublistView(tam, bas, son);
  }

  @override
  Future<int> boyut(String yol) async =>
      yol.startsWith('/gecici/') ? ciktiBayt : girdiBayt;

  @override
  Future<void> sil(String yol) async => silinenler.add(yol);
}

/// Sistem seçicisinden dönmüş gibi bir VİDEO dosyası. İçeriği GERÇEK bir
/// `ftyp isom` başlığı ([_mp4Bas]): inceleme ekranı türü uzantıdan değil
/// SİHİRLİ BAYTTAN okuyor.
XFile _video([String ad = 'a.mp4']) => XFile.fromData(_mp4Bas, name: ad);

/// Sistem seçicisinden dönmüş gibi bir FOTOĞRAF dosyası.
XFile _foto([String ad = 'a.png']) => XFile.fromData(_png, name: ad);

/// `videoHazirla`yı bir widget ağacı içinde başlatır ama BEKLEMEZ:
/// böylece açılan ilerleme kutusuyla etkileşilebilir.
class _Kosu {
  XFile? sonuc;
  bool bitti = false;
}

Future<_Kosu> _hazirlaBaslat(
  WidgetTester tester,
  XFile kaynak, {
  VideoKirpma? kirpma,
}) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (c) {
          ctx = c;
          return const Scaffold(body: SizedBox.expand());
        },
      ),
    ),
  );
  final kosu = _Kosu();
  unawaited(
    videoHazirla(ctx, kaynak, kirpma: kirpma).then((v) {
      kosu.sonuc = v;
      kosu.bitti = true;
    }),
  );
  // Boyut/bilgi Future'ları + diyalog kurulumu için birkaç kare.
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
  return kosu;
}

Future<void> _kacKare(WidgetTester tester, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump();
  }
}

/// Trim ekranını açıp pop sonucunu tutar.
class _EkranSonuc {
  VideoKirpma? kirpma;
  bool dondu = false;
}

Future<_EkranSonuc> _ekranAc(
  WidgetTester tester,
  VideoIsleyici motor, {
  VideoBilgi bilgi = const VideoBilgi(
    sure: Duration(seconds: 60),
    genislik: 1080,
    yukseklik: 1920,
  ),
  Duration azami = const Duration(seconds: 60),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final sonuc = _EkranSonuc();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                sonuc.kirpma = await Navigator.of(ctx).push<VideoKirpma?>(
                  MaterialPageRoute(
                    builder: (_) => VideoDuzenleEkrani(
                      kaynak: XFile('/kaynak/a.mp4'),
                      isleyici: motor,
                      bilgi: bilgi,
                      azami: azami,
                    ),
                  ),
                );
                sonuc.dondu = true;
              },
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
  return sonuc;
}

void main() {
  setUp(() => videoIsleyiciSahte = null);
  tearDown(() => videoIsleyiciSahte = null);

  // ---- 4. Sihirli bayt: sunucudaki VIDEO_TURLERI kapısının istemci ikizi ----

  group('sihirli bayt', () {
    test('mp4 ve webm tanınır', () {
      expect(videoTuru(_mp4Bas), VideoTur.mp4);
      expect(videoTuru(_webmBas), VideoTur.webm);
    });

    test('ftyp + M4A SES sayılır — video olarak kabul EDİLMEZ', () {
      // server.js SES'i VİDEO'dan ÖNCE deniyor; bu dosya orada `.m4a` olur
      // ve `medya_goster.dart` onu ses oynatıcıya yollardı.
      expect(videoTuru(_m4aBas), VideoTur.bilinmeyen);
    });

    test('ogg / mp3 / png / kısa gövde reddedilir', () {
      expect(videoTuru(_bas([0x4F, 0x67, 0x67, 0x53])), VideoTur.bilinmeyen);
      expect(videoTuru(_bas([0x49, 0x44, 0x33])), VideoTur.bilinmeyen);
      expect(videoTuru(_bas([0xFF, 0xFB])), VideoTur.bilinmeyen);
      expect(videoTuru(_png), VideoTur.bilinmeyen);
      // Sunucu 12 bayttan kısa gövdeyi zaten 400'lüyor.
      expect(videoTuru(Uint8List(8)), VideoTur.bilinmeyen);
    });
  });

  // ---- Sıkıştırma ölçeği ----

  group('sıkıştırma ölçeği', () {
    test('dikey 1080×1920 → KISA kenar 720 olur (405 değil)', () {
      final o = videoOlcek(1080, 1920);
      expect((1080 * o).round(), 720);
      expect((1920 * o).round(), 1280);
    });

    test('yatay 1920×1080 → 1280×720', () {
      final o = videoOlcek(1920, 1080);
      expect((1920 * o).round(), 1280);
      expect((1080 * o).round(), 720);
    });

    test('4K → 1280×720, zaten küçük olan BÜYÜTÜLMEZ', () {
      expect((3840 * videoOlcek(3840, 2160)).round(), 1280);
      expect(videoOlcek(640, 360), 1);
      expect(videoOlcek(0, 0), 1);
    });
  });

  // ---- Sıkıştırma KARARI (madde 35a) ----
  //
  // Bu grup tek bir cümleyi kilitliyor: **zaten verimli bir video TEKRAR
  // sıkıştırılmaz.** 13 Ağu'ya kadar kural yalnız "20 MB'ı aştı mı" idi ve
  // canlıdan alınan gerçek bir dosyada (1080×1920, 70,9 sn, 3,98 Mbps,
  // 33,6 MB) çıktı 40,9 MB / 720×1280 oluyordu: dosya %21,8 BÜYÜYOR,
  // piksel sayısı yarıya iniyordu.

  group('sıkıştırma kararı', () {
    VideoSikistirmaKarari karar({
      required int mb,
      required int saniye,
      int genislik = 1080,
      int yukseklik = 1920,
    }) => videoSikistirmaKarari(
      girdiBayt: mb * 1024 * 1024,
      sure: Duration(seconds: saniye),
      genislik: genislik,
      yukseklik: yukseklik,
    );

    test('20 MB altı hiç sorgulanmaz', () {
      expect(karar(mb: 8, saniye: 5), VideoSikistirmaKarari.yok);
    });

    test('ÖLÇÜLEN VAKA: 33,6 MB / 70,9 sn / 3,98 Mbps → DOKUNULMAZ', () {
      // Eski kod burada 720p/5 Mbps'e kodluyordu ve 40,9 MB üretiyordu.
      final k = videoSikistirmaKarari(
        girdiBayt: 35228685,
        sure: const Duration(milliseconds: 70863),
        genislik: 1080,
        yukseklik: 1920,
      );
      expect(k.sikistir, isFalse);
      expect(k.olcek, 1);
      expect(k.bitHizi, isNull);
    });

    test('bit hızı hedefin altında olan UZUN video da dokunulmaz', () {
      // 50 MB / 9 dk = 0,78 Mbps. Büyük dosya ≠ şişkin dosya.
      expect(karar(mb: 50, saniye: 540).sikistir, isFalse);
    });

    test('bit hızı YÜKSEK olan video sıkıştırılır (720p kutusu + tavan)', () {
      // 60 MB / 60 sn = 8,4 Mbps → 5 Mbps × 1,25 eşiğinin çok üstünde.
      final k = karar(mb: 60, saniye: 60);
      expect(k.sikistir, isTrue);
      expect(k.bitHizi, videoBitHizi);
      expect((1080 * k.olcek).round(), 720);
      expect((1920 * k.olcek).round(), 1280);
    });

    test('eşiğin HEMEN altı sıkıştırılmaz, hemen üstü sıkıştırılır', () {
      // Kazanç eşiği 1,25 → 6,25 Mbps sınır. Süre 60 sn seçildi ki
      // MB ↔ Mbps çevrimi okunur olsun (1 MiB/sn ≈ 8,39 Mbps).
      int bayt(double mbps) => (mbps * 1000000 * 60 / 8).round();
      VideoSikistirmaKarari k(double mbps) => videoSikistirmaKarari(
        girdiBayt: bayt(mbps),
        sure: const Duration(seconds: 60),
        genislik: 1080,
        yukseklik: 1920,
      );
      expect(k(6.0).sikistir, isFalse, reason: '6 Mbps < 6,25 → kazanç yok');
      expect(k(6.5).sikistir, isTrue);
      // Paketin kendi transmux toleransıyla (BitrateCapPolicy.TOLERANCE =
      // 1,2) çelişmemeli: sıkıştır dediğimiz her kaynak paket tarafında da
      // yeniden kodlanmalı, yoksa boşuna beklemiş oluruz.
      expect(videoKazancEsigi, greaterThan(1.2));
    });

    test('sunucu sınırını AŞAN dosya kazanç eşiğine bakılmadan sığdırılır', () {
      // 150 MB / 300 sn = 4,2 Mbps: eşiğin altında ama 100 MB'a sığmıyor.
      final k = karar(mb: 150, saniye: 300);
      expect(k.sikistir, isTrue);
      // Tavan, 100 MB'ın %92'sine sığacak şekilde 5 Mbps'ten AŞAĞI çekilmeli.
      expect(k.bitHizi, lessThan(videoBitHizi));
      final tahminiBayt = k.bitHizi! * 300 / 8;
      expect(tahminiBayt, lessThan(videoAzamiBayt));
    });

    test('süre okunamadıysa ölçek verilmez (yeniden kodlama ZORLANMAZ)', () {
      final k = karar(mb: 40, saniye: 0);
      expect(k.sikistir, isTrue);
      expect(k.olcek, 1, reason: 'ölçek Media3\'te efekttir, kodlamayı zorlar');
      expect(k.bitHizi, videoBitHizi);
    });
  });

  // ---- Kodek algılama (madde 53) ----
  //
  // ÖLÇÜM (13 Ağu 2026, canlı): 25.851 medya dosyasının video olan 481'i
  // ffprobe'dan geçirildi → 448 H.264, **33 VP9**, 0 HEVC. Yani "tarayıcıda
  // oynamayan video" ÖNGÖRÜ değil, canlıda duran bir olgu; üstelik VP9
  // dosyalardan biri (`m85-cea0ca2bba88e369.mp4`) madde 35(a)'nın ölçüm
  // dosyasının ta kendisi. Kural bu yüzden HEVC'ye özel değil: H.264
  // olmayan her görüntü kodeki yeniden kodlanır.
  //
  // Baytlar GERÇEK ffmpeg çıktısıdır (`gercek_video_baslik.dart`).

  group('kodek algılama', () {
    Future<VideoKodek> kodek(Uint8List v) =>
        videoKodegi(bellektenOku(v), v.length);

    test('gerçek H.264 dosyası avc1 olarak tanınır', () async {
      expect(await kodek(gercekH264), VideoKodek.h264);
    });

    test('gerçek HEVC dosyası hvc1 olarak tanınır', () async {
      expect(await kodek(gercekHevc), VideoKodek.hevc);
    });

    test('gerçek VP9 dosyası vp09 olarak tanınır', () async {
      // Canlıdaki 33 dosyanın kodeki. `moov` bu dosyada mdat'tan SONRA:
      // ayrıştırıcı mdat gövdesini okumadan üzerinden atlayabilmeli.
      expect(await kodek(gercekVp9), VideoKodek.vp9);
    });

    test('`moov` DOSYANIN SONUNDA olsa da bulunur', () async {
      // Telefon kamerası faststart yazmaz; moov sondadır. Bu vaka kaçarsa
      // gerçek cihaz videolarının HİÇBİRİ tanınmaz.
      expect(await kodek(gercekH264MoovSonda), VideoKodek.h264);
    });

    test('`mdat` GÖVDESİ okunmaz — yalnız 16 baytlık başlığı', () async {
      // BU TESTİN ASIL DERDİ 813 baytlık oyuncak dosya değil, 100 MB'lık
      // gerçek video: kodek öğrenmek için `mdat` gövdesini okumak, kullanıcıyı
      // her yüklemede yüz megabaytlık bir disk okumasına mahkûm etmek demek.
      // `moov` gövdesi okunur (kutu ağacı orada), `mdat` gövdesi ASLA.
      //
      // `gercekH264MoovSonda` kutuları: ftyp(0,32) free(32,8) mdat(40,722)
      // moov(762,752). mdat'tan okunmasına izin verilen tek şey 16 baytlık
      // başlık penceresidir (64 bitlik boy alanı da oraya sığsın diye 16);
      // yani 56. bayttan `moov`a kadar olan aralığa HİÇ dokunulmamalı.
      const mdatGovdeBas = 40 + 16;
      const mdatGovdeSon = 762;
      final okunan = <List<int>>[];
      final ham = bellektenOku(gercekH264MoovSonda);
      final k = await videoKodegi((bas, adet) async {
        final v = await ham(bas, adet);
        okunan.add([bas, bas + v.length]);
        return v;
      }, gercekH264MoovSonda.length);
      expect(k, VideoKodek.h264);
      for (final aralik in okunan) {
        expect(
          aralik[0] < mdatGovdeSon && aralik[1] > mdatGovdeBas,
          isFalse,
          reason: 'mdat gövdesine dokunuldu: $aralik',
        );
      }
      // mdat'ın üzerinden 16 baytlık tek bir başlık okumasıyla atlanmalı.
      expect(okunan.where((a) => a[0] == 40), hasLength(1));
    });

    test('BOZUK/KISA dosyalarda ÇÖKMEZ, "bilinmiyor" döner', () async {
      expect(await kodek(Uint8List(0)), VideoKodek.bilinmiyor);
      expect(await kodek(Uint8List(4)), VideoKodek.bilinmiyor);
      // ftyp diyor ama gerisi yok.
      expect(await kodek(_mp4Bas), VideoKodek.bilinmiyor);
      // WebM (EBML) — MP4 kutu ağacı değil; rastgele baytlar kutu boyu
      // sanılıp gezilmemeli.
      expect(await kodek(_webmBas), VideoKodek.bilinmiyor);
      // Gerçek dosyanın ortasından kesilmiş hâli: `moov` yarım.
      expect(
        await kodek(Uint8List.sublistView(gercekH264, 0, 200)),
        VideoKodek.bilinmiyor,
      );
      // Boy alanı 0 olan kutu (dosya sonuna kadar) sonsuz döngü yapmamalı.
      expect(
        await kodek(_bas([0, 0, 0, 0, 0x66, 0x74, 0x79, 0x70])),
        VideoKodek.bilinmiyor,
      );
    });

    test('dosya boyutu bilinmiyorsa okumaya hiç girişilmez', () async {
      var okumaOldu = false;
      final k = await videoKodegi((bas, adet) async {
        okumaOldu = true;
        return Uint8List(0);
      }, 0);
      expect(k, VideoKodek.bilinmiyor);
      expect(okumaOldu, isFalse);
    });

    test('okuma İSTİSNA fırlatırsa yutulur', () async {
      final k = await videoKodegi(
        (bas, adet) async => throw Exception('disk gitti'),
        1000,
      );
      expect(k, VideoKodek.bilinmiyor);
    });

    test('yalnız H.264 ve bilinmiyor "dokunma" der', () {
      expect(VideoKodek.h264.yenidenKodlaGerek, isFalse);
      // Emin değilsek dokunmuyoruz: bugünkü davranış korunur.
      expect(VideoKodek.bilinmiyor.yenidenKodlaGerek, isFalse);
      expect(VideoKodek.hevc.yenidenKodlaGerek, isTrue);
      expect(VideoKodek.vp9.yenidenKodlaGerek, isTrue);
      expect(VideoKodek.av1.yenidenKodlaGerek, isTrue);
      expect(VideoKodek.digerVideo.yenidenKodlaGerek, isTrue);
    });
  });

  // ---- Oynatılabilirlik KARARI (madde 53) ----

  group('oynatılabilirlik kararı', () {
    VideoSikistirmaKarari karar({
      required int mb,
      required int saniye,
      VideoKodek kodek = VideoKodek.hevc,
      int genislik = 1080,
      int yukseklik = 1920,
    }) => videoSikistirmaKarari(
      girdiBayt: mb * 1024 * 1024,
      sure: Duration(seconds: saniye),
      genislik: genislik,
      yukseklik: yukseklik,
      kodek: kodek,
    );

    test('H.264 kaynak madde 35(a) kuralına DOKUNMAZ', () {
      // Bu satır 35(a)'yı koruyor: kodek parametresi eklendi diye "zaten
      // verimli" bir H.264 video yeniden kodlanmaya başlamamalı.
      expect(karar(mb: 8, saniye: 5, kodek: VideoKodek.h264).sikistir, isFalse);
      expect(
        karar(mb: 50, saniye: 540, kodek: VideoKodek.h264).sikistir,
        isFalse,
      );
    });

    test('20 MB ALTINDAKİ HEVC bile yeniden kodlanır', () {
      // Boyut kapısı bunu hiç sorgulamazdı; oynamayan video küçük de olabilir.
      final k = karar(mb: 8, saniye: 20);
      expect(k.sikistir, isTrue);
    });

    test('ÖLÇÜLEN VAKA: 33,6 MB VP9 dosya artık H.264\'e çevrilir', () {
      // `m85-cea0ca2bba88e369.mp4` — 35(a) bunu "dokunma" diye bırakıyordu
      // (boyut açısından DOĞRU), ama dosya VP9 ve Safari'de oynamıyor.
      final k = videoSikistirmaKarari(
        girdiBayt: 35228685,
        sure: const Duration(milliseconds: 70863),
        genislik: 1080,
        yukseklik: 1920,
        kodek: VideoKodek.vp9,
      );
      expect(k.sikistir, isTrue);
      // ÇÖZÜNÜRLÜK KORUNUR: yeniden kodlamanın gerekçesi kodek, piksel değil.
      expect(
        k.olcek,
        1,
        reason: '35(a) piksel yarıya indirmenin bedelini ölçtü',
      );
      // Kaynak 3,98 Mbps → tavan %80'i.
      expect(k.bitHizi, closeTo(3977103 * videoOynatilabilirlikPayi, 20000));
    });

    test('tavan kaynağın ALTINDA kalır — yoksa iOS kayıpsız KOPYALAR', () {
      // `RenderVideo.swift:61` → kaynak ≤ tavan × 1,2 ise
      // AVAssetExportPresetPassthrough; kodek DEĞİŞMEZ, düzeltme boşa gider.
      // Paketin toleransı 1,2; bizim payımız 1/0,8 = 1,25 > 1,2.
      for (final mbps in [0.5, 1.0, 2.0, 4.0, 6.0]) {
        final bayt = (mbps * 1000000 * 30 / 8).round();
        final k = videoSikistirmaKarari(
          girdiBayt: bayt,
          sure: const Duration(seconds: 30),
          genislik: 1080,
          yukseklik: 1920,
          kodek: VideoKodek.hevc,
        );
        expect(k.sikistir, isTrue, reason: '$mbps Mbps');
        final kaynakBitHizi = bayt * 8 / 30;
        expect(
          kaynakBitHizi,
          greaterThan(k.bitHizi! * 1.2),
          reason: '$mbps Mbps — paket kayıpsız kopyalama yoluna düşmemeli',
        );
      }
      expect(1 / videoOynatilabilirlikPayi, greaterThan(1.2));
    });

    test(
      'çıktı kaynaktan BÜYÜK olamaz (35a\'nın şişme hatası tekrarlanmaz)',
      () {
        for (final mbps in [0.3, 1.0, 3.98, 6.0]) {
          final bayt = (mbps * 1000000 * 40 / 8).round();
          final k = videoSikistirmaKarari(
            girdiBayt: bayt,
            sure: const Duration(seconds: 40),
            genislik: 1080,
            yukseklik: 1920,
            kodek: VideoKodek.vp9,
          );
          final tahminiBayt = k.bitHizi! * 40 / 8;
          expect(
            tahminiBayt,
            lessThanOrEqualTo(bayt.toDouble()),
            reason: '$mbps',
          );
        }
      },
    );

    test('tavan 5 Mbps\'i ve 100 MB sığdırmasını aşmaz', () {
      // Yüksek bit hızlı kaynakta zaten BOYUT kararı devreye girer ve o da
      // H.264 üretir; oynatılabilirlik dalı ikinci kez bit harcamaz.
      final k = karar(mb: 60, saniye: 60);
      expect(k.bitHizi, lessThanOrEqualTo(videoBitHizi));
      // 100 MB'ı aşan kaynakta sığdırma tavanı kazanır.
      final b = karar(mb: 150, saniye: 300);
      expect(b.bitHizi! * 300 / 8, lessThan(videoAzamiBayt));
    });

    test('süre okunamadıysa ölçek verilmez, yalnız tavan konur', () {
      final k = karar(mb: 8, saniye: 0);
      expect(k.sikistir, isTrue);
      expect(k.olcek, 1);
      expect(k.bitHizi, videoBitHizi);
    });

    test('BOYUT kararı zaten sıkıştırıyorsa o kazanır', () {
      // Çıktı ne olursa olsun H.264; ikinci bir kural gereksiz. Kodekli ve
      // kodeksiz çağrı AYNI kararı vermeli.
      final kodekli = karar(mb: 60, saniye: 60, kodek: VideoKodek.hevc);
      final kodeksiz = karar(mb: 60, saniye: 60, kodek: VideoKodek.bilinmiyor);
      expect(kodekli, kodeksiz);
      expect(
        kodekli.olcek,
        lessThan(1),
        reason: 'boyut dalı 720p kutusu ister',
      );
    });
  });

  // ---- 1. Trim aralığı ----

  group('trim aralığı', () {
    testWidgets('bitiş tutamağı sürüklenince aralık kısalır', (tester) async {
      Duration? bas;
      Duration? bit;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 344, // film alanı = 344 - 2×22 = 300 px
                child: KirpmaSeridi(
                  kareler: const [],
                  toplam: const Duration(seconds: 60),
                  bas: Duration.zero,
                  bit: const Duration(seconds: 60),
                  tutamak: (baslangicMi, d) {
                    if (baslangicMi) {
                      bas = d;
                    } else {
                      bit = d;
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      );
      // 300 px = 60 sn → 100 px = 20 sn.
      // BİLEREK tek `drag` çağrısı: Flutter sürükleme eşiğini (slop) ayrı bir
      // `onUpdate` olarak yolluyor ve arada yeniden çizim OLMUYOR. Tutamak
      // deltayı kendi biriktirmeseydi burada 40 sn yerine ~57 sn çıkardı —
      // parmak 100 px gidip tutamağın 40 px oynadığı gerçek hata bu.
      await tester.drag(
        find.byKey(const ValueKey('kirpma-bit')),
        const Offset(-100, 0),
      );
      expect(bas, isNull);
      expect(bit!.inSeconds, 40);
    });

    testWidgets('Tamam seçilen aralığı döndürür', (tester) async {
      final motor = _SahteMotor();
      final sonuc = await _ekranAc(tester, motor);
      await tester.drag(
        find.byKey(const ValueKey('kirpma-bit')),
        const Offset(-60, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();
      expect(sonuc.dondu, isTrue);
      expect(sonuc.kirpma, isNotNull);
      expect(sonuc.kirpma!.bas, Duration.zero);
      expect(sonuc.kirpma!.bit.inSeconds, lessThan(60));
      expect(sonuc.kirpma!.bit.inSeconds, greaterThan(0));
    });

    testWidgets('hiçbir şey değişmediyse null döner (orijinal kullanılır)', (
      tester,
    ) async {
      final sonuc = await _ekranAc(tester, _SahteMotor());
      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();
      expect(sonuc.dondu, isTrue);
      expect(sonuc.kirpma, isNull);
    });

    testWidgets('X ile çıkınca null döner', (tester) async {
      final sonuc = await _ekranAc(tester, _SahteMotor());
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(sonuc.dondu, isTrue);
      expect(sonuc.kirpma, isNull);
    });

    testWidgets('kaynak 60 sn sınırından uzunsa pencere KIRPILMIŞ açılır', (
      tester,
    ) async {
      await _ekranAc(
        tester,
        _SahteMotor(),
        bilgi: const VideoBilgi(
          sure: Duration(seconds: 180),
          genislik: 720,
          yukseklik: 1280,
        ),
      );
      // 0:00 — 1:00 · 1:00
      expect(find.textContaining('0:00 — 1:00'), findsOneWidget);
    });

    testWidgets('sınır zorlanınca METİNLE uyarılır (renk tek gösterge değil)', (
      tester,
    ) async {
      await _ekranAc(
        tester,
        _SahteMotor(),
        bilgi: const VideoBilgi(
          sure: Duration(seconds: 180),
          genislik: 720,
          yukseklik: 1280,
        ),
      );
      expect(find.textContaining('60 saniye'), findsNothing);
      // Bitişi sağa it: pencere 60 sn'yi aşmaya çalışır → başlangıç birlikte
      // kayar, aralık 60 sn'de KİLİTLENİR ve uyarı METİNLE çıkar.
      await tester.drag(
        find.byKey(const ValueKey('kirpma-bit')),
        const Offset(120, 0),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('60 saniye'), findsOneWidget);
    });

    testWidgets('kırpma aralığı motora AYNEN geçer', (tester) async {
      final motor = _SahteMotor();
      videoIsleyiciSahte = () => motor;
      final kosu = await _hazirlaBaslat(
        tester,
        XFile('/kaynak/a.mp4'),
        kirpma: const VideoKirpma(
          bas: Duration(seconds: 4),
          bit: Duration(seconds: 19),
        ),
      );
      await _kacKare(tester);
      expect(kosu.bitti, isTrue);
      expect(motor.isler, hasLength(1));
      expect(motor.isler.first.bas, const Duration(seconds: 4));
      expect(motor.isler.first.bit, const Duration(seconds: 19));
      expect(kosu.sonuc!.path, startsWith('/gecici/'));
    });

    testWidgets('sesi kapat kararı motora geçer', (tester) async {
      final motor = _SahteMotor();
      videoIsleyiciSahte = () => motor;
      await _hazirlaBaslat(
        tester,
        XFile('/kaynak/a.mp4'),
        kirpma: const VideoKirpma(
          bas: Duration.zero,
          bit: Duration(seconds: 10),
          sessiz: true,
        ),
      );
      await _kacKare(tester);
      expect(motor.isler.single.ses, isFalse);
    });
  });

  // ---- 2. İPTAL ----

  group('iptal', () {
    testWidgets('İptal işi durdurur, null döner ve geçici dosyayı SİLER', (
      tester,
    ) async {
      final motor = _SahteMotor(elleBiter: true);
      videoIsleyiciSahte = () => motor;
      final kosu = await _hazirlaBaslat(
        tester,
        XFile('/kaynak/a.mp4'),
        kirpma: const VideoKirpma(
          bas: Duration.zero,
          bit: Duration(seconds: 10),
        ),
      );
      expect(kosu.bitti, isFalse, reason: 'iş sürüyor olmalı');
      expect(find.text('İptal'), findsOneWidget);

      await tester.tap(find.text('İptal'));
      await _kacKare(tester);

      // Gerçekten motora iptal gitti mi?
      expect(motor.iptaller, hasLength(1));
      expect(motor.iptaller.single, motor.isler.single.gorev);
      await _kacKare(tester);
      expect(kosu.bitti, isTrue);
      expect(kosu.sonuc, isNull, reason: 'iptal → yükleme yapılmamalı');
      // Yarım yazılmış MP4 önbellekte kalmamalı.
      expect(motor.silinenler, contains(motor.isler.single.hedef));
    });

    testWidgets('İptal basılınca düğme kilitlenir ve durum yazılır', (
      tester,
    ) async {
      final motor = _SahteMotor(elleBiter: true, iptalTamamlar: false);
      videoIsleyiciSahte = () => motor;
      await _hazirlaBaslat(
        tester,
        XFile('/kaynak/a.mp4'),
        kirpma: const VideoKirpma(
          bas: Duration.zero,
          bit: Duration(seconds: 10),
        ),
      );
      await tester.tap(find.text('İptal'));
      await tester.pump();
      expect(find.text('İptal ediliyor…'), findsOneWidget);
      final dugme = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'İptal'),
      );
      expect(dugme.onPressed, isNull, reason: 'çift iptal engellenmeli');
      motor.bitir(null);
      await _kacKare(tester);
    });

    testWidgets('İptal düğmesi ≥44 dp', (tester) async {
      final motor = _SahteMotor(elleBiter: true);
      videoIsleyiciSahte = () => motor;
      await _hazirlaBaslat(
        tester,
        XFile('/kaynak/a.mp4'),
        kirpma: const VideoKirpma(
          bas: Duration.zero,
          bit: Duration(seconds: 10),
        ),
      );
      final boy = tester.getSize(find.widgetWithText(TextButton, 'İptal'));
      expect(boy.height, greaterThanOrEqualTo(44));
      expect(boy.width, greaterThanOrEqualTo(44));
      motor.bitir(null);
      await _kacKare(tester);
    });
  });

  // ---- 3. İLERLEME ----

  group('ilerleme', () {
    testWidgets('yüzde hem çubukla hem METİNLE gösterilir', (tester) async {
      final motor = _SahteMotor(elleBiter: true);
      videoIsleyiciSahte = () => motor;
      await _hazirlaBaslat(
        tester,
        XFile('/kaynak/a.mp4'),
        kirpma: const VideoKirpma(
          bas: Duration.zero,
          bit: Duration(seconds: 10),
        ),
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // İlk kare: yüzde yok → belirsiz çubuk ("0%"da donmuş görünmesin).
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        isNull,
      );

      motor.ilerlemeYolla(0.42);
      await _kacKare(tester);
      expect(find.text('%42'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(0.42, 0.001),
      );

      // Geri akan değer çubuğu GERİ ÇEKMEZ.
      motor.ilerlemeYolla(0.10);
      await _kacKare(tester);
      expect(find.text('%42'), findsOneWidget);

      motor.bitir(null);
      await _kacKare(tester);
    });

    testWidgets('uzun sürecek işte "Bu biraz sürebilir" yazar', (tester) async {
      // 90 sn kaynak → tahmin 45 sn > 30 sn eşiği. Bit hızı da yüksek
      // (75 MB / 90 sn ≈ 7 Mbps) ki sıkıştırma kararı GERÇEKTEN çıksın:
      // 9 dk'lık 50 MB'lık eski kurgu artık (haklı olarak) atlanıyor.
      final motor = _SahteMotor(
        elleBiter: true,
        girdiBayt: 75 * 1024 * 1024,
        bilgiVeri: const VideoBilgi(
          sure: Duration(seconds: 90),
          genislik: 1920,
          yukseklik: 1080,
        ),
      );
      videoIsleyiciSahte = () => motor;
      await _hazirlaBaslat(tester, XFile('/kaynak/a.mp4'));
      expect(find.text('Bu biraz sürebilir'), findsOneWidget);
      motor.bitir(null);
      await _kacKare(tester);
    });
  });

  // ---- 6. OTOMATİK SIKIŞTIRMA ----

  group('otomatik sıkıştırma', () {
    testWidgets('20 MB altı ve kırpmasız video HİÇ işlenmez', (tester) async {
      final motor = _SahteMotor(girdiBayt: 8 * 1024 * 1024);
      videoIsleyiciSahte = () => motor;
      final kaynak = XFile('/kaynak/a.mp4');
      final kosu = await _hazirlaBaslat(tester, kaynak);
      await _kacKare(tester);
      expect(motor.isler, isEmpty, reason: 'gereksiz bekleme olmamalı');
      expect(kosu.sonuc, same(kaynak));
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('BİT HIZI ŞİŞKİN video sessizce 720p/5 Mbps ile sıkıştırılır', (
      tester,
    ) async {
      // 60 MB / 60 sn ≈ 8,4 Mbps — 5 Mbps'lik hedefin belirgin üstünde,
      // yani sıkıştırma gerçekten bayt kazandırıyor.
      final motor = _SahteMotor(girdiBayt: 60 * 1024 * 1024);
      videoIsleyiciSahte = () => motor;
      final kosu = await _hazirlaBaslat(tester, XFile('/kaynak/a.mp4'));
      await _kacKare(tester);
      expect(motor.isler, hasLength(1));
      final is0 = motor.isler.single;
      expect(is0.bitHizi, videoBitHizi);
      expect((1080 * is0.olcek).round(), 720);
      // Kırpma istenmedi → aralık verilmez, video baştan sona kalır.
      expect(is0.bas, isNull);
      expect(is0.bit, isNull);
      expect(kosu.sonuc!.path, startsWith('/gecici/'));
    });

    testWidgets('20 MB ÜSTÜ ama zaten verimli video HİÇ işlenmez (madde 35a)', (
      tester,
    ) async {
      // Canlıdan ölçülen gerçek dosyanın ikizi: 33,6 MB, 70,9 sn, 3,98 Mbps.
      // Eski kod bunu 40,9 MB'lık bir 720p'ye çeviriyordu.
      final motor = _SahteMotor(
        girdiBayt: 35228685,
        bilgiVeri: const VideoBilgi(
          sure: Duration(milliseconds: 70863),
          genislik: 1080,
          yukseklik: 1920,
        ),
      );
      videoIsleyiciSahte = () => motor;
      final kaynak = XFile('/kaynak/a.mp4');
      final kosu = await _hazirlaBaslat(tester, kaynak);
      await _kacKare(tester);
      expect(motor.isler, isEmpty, reason: 'kodlayıcı hiç çalışmamalı');
      expect(kosu.sonuc, same(kaynak), reason: 'özgün dosya yüklenmeli');
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('kırpma varken küçük dosyada bit hızı ZORLANMAZ', (
      tester,
    ) async {
      final motor = _SahteMotor(girdiBayt: 5 * 1024 * 1024);
      videoIsleyiciSahte = () => motor;
      await _hazirlaBaslat(
        tester,
        XFile('/kaynak/a.mp4'),
        kirpma: const VideoKirpma(
          bas: Duration.zero,
          bit: Duration(seconds: 8),
        ),
      );
      await _kacKare(tester);
      expect(motor.isler.single.bitHizi, isNull);
      expect(motor.isler.single.olcek, 1);
    });
  });

  // ---- KODEK KAPISI, uçtan uca (madde 53) ----
  //
  // Yukarıdaki karar testleri saf hesabı kilitliyor; bunlar hesabın GERÇEKTEN
  // hatta bağlı olduğunu kilitliyor. Motorun `parca` çağrısı kaynağın gerçek
  // baytlarını veriyor, `videoHazirla` kodeki oradan okuyor.

  group('kodek kapısı', () {
    testWidgets('KÜÇÜK bir HEVC video artık işlenir (1. kapıyı geçer)', (
      tester,
    ) async {
      // 8 MB: 20 MB eşiğinin ALTINDA, yani madde 35a'dan sonra bu dosya
      // sorgusuz sunucuya gidiyordu — ve Chrome'da oynamıyordu.
      final motor = _SahteMotor(
        girdiBayt: 8 * 1024 * 1024,
        kaynakVeri: gercekHevc,
        bilgiVeri: const VideoBilgi(
          sure: Duration(seconds: 20),
          genislik: 1080,
          yukseklik: 1920,
        ),
      );
      videoIsleyiciSahte = () => motor;
      final kosu = await _hazirlaBaslat(tester, XFile('/kaynak/a.mp4'));
      await _kacKare(tester);
      expect(motor.isler, hasLength(1), reason: 'HEVC H.264\'e çevrilmeli');
      expect(motor.isler.single.olcek, 1, reason: 'çözünürlük korunur');
      expect(motor.isler.single.bitHizi, isNotNull);
      expect(kosu.sonuc!.path, startsWith('/gecici/'));
    });

    testWidgets('35(a)\'nın ÖLÇÜM DOSYASI (VP9) artık dönüştürülür', (
      tester,
    ) async {
      // Aynı boyut/süre/çözünürlük — tek fark kaynağın GERÇEKTEN VP9 olması.
      // Bir üstteki "zaten verimli video HİÇ işlenmez" testiyle bilinçli
      // olarak zıt: 35(a) boyut için haklı, madde 53 kodek için haklı.
      final motor = _SahteMotor(
        girdiBayt: 35228685,
        kaynakVeri: gercekVp9,
        bilgiVeri: const VideoBilgi(
          sure: Duration(milliseconds: 70863),
          genislik: 1080,
          yukseklik: 1920,
        ),
      );
      videoIsleyiciSahte = () => motor;
      final kosu = await _hazirlaBaslat(tester, XFile('/kaynak/a.mp4'));
      await _kacKare(tester);
      expect(motor.isler, hasLength(1));
      final is0 = motor.isler.single;
      expect(is0.olcek, 1);
      // Tavan kaynağın (3,98 Mbps) altında: iOS kayıpsız kopyalamaya düşmesin.
      expect(is0.bitHizi, lessThan((3977103 / 1.2).round()));
      expect(kosu.sonuc!.path, startsWith('/gecici/'));
    });

    testWidgets('H.264 kaynak DOKUNULMADAN geçer (35a korunuyor)', (
      tester,
    ) async {
      // Aynı dosya H.264 olsaydı: kodlayıcı hiç çalışmamalı.
      final motor = _SahteMotor(
        girdiBayt: 35228685,
        kaynakVeri: gercekH264MoovSonda,
        bilgiVeri: const VideoBilgi(
          sure: Duration(milliseconds: 70863),
          genislik: 1080,
          yukseklik: 1920,
        ),
      );
      videoIsleyiciSahte = () => motor;
      final kaynak = XFile('/kaynak/a.mp4');
      final kosu = await _hazirlaBaslat(tester, kaynak);
      await _kacKare(tester);
      expect(motor.isler, isEmpty);
      expect(kosu.sonuc, same(kaynak));
    });

    testWidgets('kodek OKUNAMAZSA dosyaya dokunulmaz', (tester) async {
      // Bozuk/bilinmeyen kap: emin olmadığımız için bugünkü davranış.
      final motor = _SahteMotor(
        girdiBayt: 8 * 1024 * 1024,
        kaynakVeri: Uint8List.fromList(const [1, 2, 3, 4, 5, 6, 7, 8]),
      );
      videoIsleyiciSahte = () => motor;
      final kaynak = XFile('/kaynak/a.mp4');
      final kosu = await _hazirlaBaslat(tester, kaynak);
      await _kacKare(tester);
      expect(motor.isler, isEmpty);
      expect(kosu.sonuc, same(kaynak));
    });

    testWidgets('kodlayıcı patlarsa HEVC orijinali yine de yüklenir', (
      tester,
    ) async {
      // Oynamayan bir dosya yüklemek, kullanıcıyı hiçbir çare bırakmadan
      // reddetmekten iyidir (`_yedegeDus` sözleşmesi).
      final motor = _SahteMotor(
        girdiBayt: 8 * 1024 * 1024,
        kaynakVeri: gercekHevc,
        patlar: true,
        bilgiVeri: const VideoBilgi(
          sure: Duration(seconds: 20),
          genislik: 1080,
          yukseklik: 1920,
        ),
      );
      videoIsleyiciSahte = () => motor;
      final kaynak = XFile('/kaynak/a.mp4');
      final kosu = await _hazirlaBaslat(tester, kaynak);
      await _kacKare(tester);
      expect(kosu.sonuc, same(kaynak));
    });
  });

  // ---- 5. BOYUT SINIRLARI ----

  group('boyut sınırları', () {
    testWidgets('300 MB üstü girdi hiç denenmez, anlaşılır hata verilir', (
      tester,
    ) async {
      final motor = _SahteMotor(girdiBayt: 400 * 1024 * 1024);
      videoIsleyiciSahte = () => motor;
      final kosu = await _hazirlaBaslat(tester, XFile('/kaynak/a.mp4'));
      await _kacKare(tester);
      expect(kosu.sonuc, isNull);
      expect(motor.isler, isEmpty, reason: 'OOM kalkanı: denenmemeli');
      expect(find.text('Video çok büyük'), findsOneWidget);
    });

    testWidgets('10 dk üstü kaynak reddedilir', (tester) async {
      final motor = _SahteMotor(
        girdiBayt: 30 * 1024 * 1024,
        bilgiVeri: const VideoBilgi(
          sure: Duration(minutes: 22),
          genislik: 1920,
          yukseklik: 1080,
        ),
      );
      videoIsleyiciSahte = () => motor;
      final kosu = await _hazirlaBaslat(tester, XFile('/kaynak/a.mp4'));
      await _kacKare(tester);
      expect(kosu.sonuc, isNull);
      expect(motor.isler, isEmpty);
      expect(find.text('Video çok büyük'), findsOneWidget);
    });

    testWidgets('sunucu sınırını aşan ÇIKTI kabul edilmez', (tester) async {
      final motor = _SahteMotor(
        girdiBayt: 40 * 1024 * 1024,
        ciktiBayt: videoAzamiBayt + 1,
      );
      videoIsleyiciSahte = () => motor;
      final kosu = await _hazirlaBaslat(
        tester,
        XFile('/kaynak/a.mp4'),
        kirpma: const VideoKirpma(
          bas: Duration.zero,
          bit: Duration(seconds: 10),
        ),
      );
      await _kacKare(tester);
      expect(kosu.sonuc, isNull);
      expect(motor.silinenler, contains(motor.isler.single.hedef));
      expect(find.text('Video hazırlanamadı'), findsOneWidget);
    });
  });

  // ---- 4b. ÇIKTI DOĞRULAMASI ----

  group('çıktı doğrulaması', () {
    testWidgets('m4a markalı çıktı REDDEDİLİR (kırpma varsa hata verilir)', (
      tester,
    ) async {
      final motor = _SahteMotor(ciktiBas: _m4aBas);
      videoIsleyiciSahte = () => motor;
      final kosu = await _hazirlaBaslat(
        tester,
        XFile('/kaynak/a.mp4'),
        kirpma: const VideoKirpma(
          bas: Duration.zero,
          bit: Duration(seconds: 10),
        ),
      );
      await _kacKare(tester);
      expect(kosu.sonuc, isNull);
      expect(motor.silinenler, contains(motor.isler.single.hedef));
      expect(find.text('Video hazırlanamadı'), findsOneWidget);
    });

    testWidgets(
      'yalnız SIKIŞTIRMA başarısızsa orijinale düşülür (yükleme durmaz)',
      (tester) async {
        // 60 MB / 60 sn: sıkıştırma kararı GERÇEKTEN çıkar (8,4 Mbps),
        // böylece test yedeğe düşme yolunu sınar, kararın atlanmasını değil.
        final motor = _SahteMotor(
          girdiBayt: 60 * 1024 * 1024,
          ciktiBas: _m4aBas,
        );
        videoIsleyiciSahte = () => motor;
        final kaynak = XFile('/kaynak/a.mp4');
        final kosu = await _hazirlaBaslat(tester, kaynak);
        await _kacKare(tester);
        expect(motor.isler, hasLength(1), reason: 'sıkıştırma denenmiş olmalı');
        // Kullanıcı sıkıştırma İSTEMEMİŞTİ; görünmez bir iyileştirmenin
        // başarısızlığı yüklemeyi engellememeli.
        expect(kosu.sonuc, same(kaynak));
        expect(find.text('Video hazırlanamadı'), findsNothing);
      },
    );

    testWidgets('kodlayıcı patlarsa sessiz kalınmaz', (tester) async {
      final motor = _SahteMotor(patlar: true);
      videoIsleyiciSahte = () => motor;
      final kosu = await _hazirlaBaslat(
        tester,
        XFile('/kaynak/a.mp4'),
        kirpma: const VideoKirpma(
          bas: Duration.zero,
          bit: Duration(seconds: 10),
        ),
      );
      await _kacKare(tester);
      expect(kosu.sonuc, isNull);
      expect(find.text('Video hazırlanamadı'), findsOneWidget);
    });
  });

  // ---- 8. WEB YOLU ----

  group('web yolu (motor yok)', () {
    test('düzenleme kapalı', () {
      videoIsleyiciSahte = () => null;
      expect(videoMotoru(), isNull);
      expect(videoDuzenlenebilir(), isFalse);
    });

    testWidgets('videoDuzenle hiçbir ekran açmadan null döner', (tester) async {
      videoIsleyiciSahte = () => null;
      VideoKirpma? k;
      var cagrildi = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    k = await videoDuzenle(ctx, XFile('/kaynak/a.mp4'));
                    cagrildi = true;
                  },
                  child: const Text('aç'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      expect(cagrildi, isTrue);
      expect(k, isNull);
      expect(find.byType(VideoDuzenleEkrani), findsNothing);
    });

    testWidgets('videoHazirla ORİJİNALİ döner (bugünkü davranış korunur)', (
      tester,
    ) async {
      videoIsleyiciSahte = () => null;
      final kaynak = XFile('/kaynak/a.mp4');
      final kosu = await _hazirlaBaslat(tester, kaynak);
      await _kacKare(tester);
      expect(kosu.sonuc, same(kaynak));
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  // ---- 7. MEDYA İNCELEME EKRANI BAĞLANTISI ----
  //
  // 7 Ağu 2026: uygulama içi galeri ızgarası (photo_manager + READ_MEDIA_*)
  // Play politikası yüzünden kalktı. Seçim artık sistem Fotoğraf Seçici'den
  // geliyor; MAKAS düğmesi ve "İleri"deki kodlama hattı AYNI ekranda duruyor.

  group('medya inceleme ekranı', () {
    Future<List<XFile>?> ac(WidgetTester tester, List<XFile> dosyalar) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      List<XFile>? sonuc;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    sonuc = await Navigator.of(ctx).push<List<XFile>>(
                      MaterialPageRoute(
                        builder: (_) => MedyaIncelemeEkrani(dosyalar: dosyalar),
                      ),
                    );
                  },
                  child: const Text('aç'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      return sonuc;
    }

    testWidgets('videoda MAKAS var, kalem YOK', (tester) async {
      videoIsleyiciSahte = () => _SahteMotor();
      await ac(tester, [_video()]);
      expect(find.byTooltip('Videoyu düzenle'), findsOneWidget);
      expect(find.byTooltip('Görseli düzenle'), findsNothing);
    });

    testWidgets('fotoğrafta KALEM var, makas YOK', (tester) async {
      videoIsleyiciSahte = () => _SahteMotor();
      await ac(tester, [_foto()]);
      expect(find.byTooltip('Görseli düzenle'), findsOneWidget);
      expect(find.byTooltip('Videoyu düzenle'), findsNothing);
    });

    testWidgets('web yolunda video düğmesi HİÇ ÇİZİLMEZ', (tester) async {
      videoIsleyiciSahte = () => null;
      await ac(tester, [_video()]);
      expect(find.byTooltip('Videoyu düzenle'), findsNothing);
      expect(find.byTooltip('Görseli düzenle'), findsNothing);
    });

    testWidgets('İleri: büyük video sıkıştırılıp öyle döner', (tester) async {
      final motor = _SahteMotor(girdiBayt: 60 * 1024 * 1024);
      videoIsleyiciSahte = () => motor;
      List<XFile>? sonuc;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    sonuc = await Navigator.of(ctx).push<List<XFile>>(
                      MaterialPageRoute(
                        builder: (_) =>
                            MedyaIncelemeEkrani(dosyalar: [_video()]),
                      ),
                    );
                  },
                  child: const Text('aç'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İleri'));
      await tester.pumpAndSettle();
      expect(motor.isler, hasLength(1));
      expect(motor.isler.single.bitHizi, videoBitHizi);
      expect(sonuc, hasLength(1));
      expect(sonuc!.single.path, startsWith('/gecici/'));
    });

    testWidgets('İleri: iptal edilirse HİÇBİR dosya dönmez', (tester) async {
      final motor = _SahteMotor(girdiBayt: 60 * 1024 * 1024, elleBiter: true);
      videoIsleyiciSahte = () => motor;
      var dondu = false;
      List<XFile>? sonuc;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    sonuc = await Navigator.of(ctx).push<List<XFile>>(
                      MaterialPageRoute(
                        builder: (_) =>
                            MedyaIncelemeEkrani(dosyalar: [_video()]),
                      ),
                    );
                    dondu = true;
                  },
                  child: const Text('aç'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İleri'));
      await _kacKare(tester);
      await tester.tap(find.text('İptal'));
      await _kacKare(tester, 10);
      expect(motor.silinenler, contains(motor.isler.single.hedef));
      expect(dondu, isFalse, reason: 'inceleme ekranı AÇIK kalmalı');
      expect(sonuc, isNull);
      // Kullanıcı yeniden deneyebilmeli: "İleri" tekrar etkin.
      expect(find.text('İleri'), findsOneWidget);
    });
  });

  // ---- DOKUNMA HEDEFLERİ ----

  group('dokunma hedefleri', () {
    testWidgets('trim tutamakları ≥44 dp', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 344,
                child: KirpmaSeridi(
                  kareler: const [],
                  toplam: const Duration(seconds: 60),
                  bas: Duration.zero,
                  bit: const Duration(seconds: 60),
                  tutamak: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      );
      for (final anahtar in ['kirpma-bas', 'kirpma-bit']) {
        final boy = tester.getSize(find.byKey(ValueKey(anahtar)));
        expect(boy.width, greaterThanOrEqualTo(44), reason: anahtar);
        expect(boy.height, greaterThanOrEqualTo(44), reason: anahtar);
      }
    });

    testWidgets('tutamakların dokunma kutusu şeridin İÇİNDE kalır', (
      tester,
    ) async {
      // Stack sınırının DIŞINA taşan Positioned görünse bile TIKLANMAZ —
      // bu projede bizzat yaşanmış tuzak (UX kontrol listesi §2).
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 344,
                child: KirpmaSeridi(
                  kareler: const [],
                  toplam: const Duration(seconds: 60),
                  bas: Duration.zero,
                  bit: const Duration(seconds: 60),
                  tutamak: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      );
      final serit = tester.getRect(find.byType(KirpmaSeridi));
      for (final anahtar in ['kirpma-bas', 'kirpma-bit']) {
        final t = tester.getRect(find.byKey(ValueKey(anahtar)));
        expect(
          t.left,
          greaterThanOrEqualTo(serit.left - 0.01),
          reason: anahtar,
        );
        expect(t.right, lessThanOrEqualTo(serit.right + 0.01), reason: anahtar);
      }
    });

    testWidgets('ses düğmesi ≥44 dp ve etiketi okunur', (tester) async {
      await _ekranAc(tester, _SahteMotor());
      final boy = tester.getSize(find.widgetWithText(TextButton, 'Sesi kapat'));
      expect(boy.height, greaterThanOrEqualTo(44));
      await tester.tap(find.text('Sesi kapat'));
      await tester.pumpAndSettle();
      expect(find.text('Sesi aç'), findsOneWidget);
    });
  });
}
