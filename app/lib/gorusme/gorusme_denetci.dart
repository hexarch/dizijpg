import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api.dart';
import '../ceviri.dart';
import 'arama_efekti.dart';
import 'gorusme_api.dart';
import 'gorusme_surucu.dart';

/// Arama ekranının gördüğü hâller.
enum GorusmeDurum {
  /// Mikrofon/kamera açılıyor, teklif üretiliyor (ekranda spinner).
  hazirlaniyor,

  /// Karşı taraf çalıyor.
  caliyor,

  /// Kabul edildi, ICE kuruluyor (ekranda spinner).
  baglaniyor,

  /// Medya akıyor; süre sayacı burada başlar.
  konusuyor,

  /// Arama bitti; [GorusmeDenetci.sonucMetni] neden bittiğini söyler.
  bitti,
}

/// Kurulmuş bir aramanın SERT üst sınırı (sözleşme §13.2).
///
/// Sunucu 4 saati aşan aramaları süpürüyor; istemci de aynı anda kapatmalı.
/// Yoksa sunucu kaydı `cevaplandi` yazıp `aktifArama` kilidini açar, istemci
/// ise hâlâ "konuşuyor" gösterir ve kullanıcı sayacı akarken kimseyi
/// arayamadığını fark etmez.
const Duration azamiAramaSuresi = Duration(hours: 4);

/// Üst sınıra bu kadar kala kullanıcı uyarılır.
const Duration aramaSuresiUyarisi = Duration(minutes: 5);

/// Kabul edildikten sonra ICE'in bağlanması için beklenecek süre.
/// Dolarsa arama `ice_basarisiz` sebebiyle kapatılır (sözleşme §13.1).
const Duration baglantiBeklemeSuresi = Duration(seconds: 30);

/// `POST /arama/bitir`in `sebep` alanını üretir. **SAF FONKSİYON.**
///
/// ***BU PROJEDE SESSİZCE BOZULABİLECEK TEK KARAR BUDUR.*** Sunucu
/// `baglaniyor → cevaplandi` geçişini ASLA göremez (bağlantı kurulunca
/// yoklama tamamen durur, sözleşme §1), bu yüzden veritabanına `basarisiz` mı
/// `cevaplandi` mı yazılacağına yalnızca bu alan karar verir. Hiç bağlanmamış
/// bir arama `cevaplandi` olarak kaydedilirse:
///   * röle oranı (`aramalar.role_dustu`) yanlış hesaplanır,
///   * görüntülü aramanın bant genişliği/maliyet kararı yanlış veriye dayanır,
///   * ve bunu hiçbir hata mesajı söylemez.
/// Bu yüzden karar buraya, yan etkisiz ve doğrudan test edilebilir bir
/// fonksiyona çıkarıldı (`test/gorusme_sebep_test.dart`).
///
/// [hicBaglandi]: medya bir kez olsun aktı mı (sürücü `bagli` dedi mi).
/// [iceKoptu]: bağlantı sonradan koptu mu.
/// [calmaZamanAsimi]: 45 sn çalma süresi doldu mu.
String bitirSebebi({
  required GorusmeDurum durum,
  required bool hicBaglandi,
  required bool iceKoptu,
  required bool calmaZamanAsimi,
}) {
  if (calmaZamanAsimi) return AramaSebep.zamanAsimi;
  // Henüz kabul edilmemiş arama: sunucu bunu `iptal`/`reddedildi` yazar,
  // sebep alanına bakmaz.
  if (durum == GorusmeDurum.hazirlaniyor || durum == GorusmeDurum.caliyor) {
    return AramaSebep.kullanici;
  }
  // Kabul edildi ama medya HİÇ akmadı → gerçekten başarısız bir arama.
  if (!hicBaglandi) return AramaSebep.iceBasarisiz;
  if (iceKoptu) return AramaSebep.agKoptu;
  return AramaSebep.kullanici;
}

/// Giden arama yoklaması 404 (`ARAMA_YOK`) aldığında ne olduğunu çıkarır.
///
/// Uç duruma gelen arama sunucunun BELLEĞİNDEN SİLİNİR (arama.js `uclastir`),
/// yani `/arama/durum` artık 404 döner ve "neden bitti" bilgisini TAŞIMAZ.
/// Ayrım zamanlamadan çıkar: aranan reddederse kayıt `sona_erme`den ÖNCE
/// silinir; kimse cevaplamazsa süpürücü kaydı ancak `sona_erme` dolunca
/// `cevapsiz` yapar.
///
/// **Bilinen tek yanlış hâl:** sunucu arama çalarken yeniden başlarsa bellek
/// içi kayıt erken kaybolur ve bu, "reddedildi" gibi okunur. Yanlış bir
/// bilgilendirme ama zararsız; alternatifi (her 404'te "arama sona erdi"
/// demek) gerçek retleri de gizlerdi.
bool reddedildiMi({required DateTime sonaErme, DateTime? simdi}) =>
    (simdi ?? DateTime.now()).isBefore(
      sonaErme.subtract(const Duration(seconds: 2)),
    );

/// Tek bir aramanın yaşam döngüsü: sinyalleşme, yoklama, sürücü ve kapanış.
///
/// Ekran bunu dinler; WebRTC türlerini hiç görmez.
class GorusmeDenetci extends ChangeNotifier {
  GorusmeDenetci({
    required this.surucu,
    required this.karsiTaraf,
    required this.tur,
    required this.gelen,
    this.karsiAvatar,
    this.aramaId,
    this.gelenTeklifSdp,
    this.calmaSaniye = 45,
    this.efekt = const SessizEfekti(),
  });

  final GorusmeSurucu surucu;

  /// Zil (ringback) + haptik. Varsayılan [SessizEfekti] (testlerde ve efektsiz
  /// akışta güvenli); ekranlar [CihazEfekti] takar. GİDEN aramada zil `caliyor`
  /// hâlinde çalar, karşı taraf cevaplayınca (`baglaniyor`) SUSAR; bağlanınca ve
  /// kapanınca haptik verilir. Zil YALNIZ giden aramada çalar — `caliyor` hâline
  /// yalnız [aramaBaslat] (arayan) girer, [kabulEt] doğrudan `baglaniyor`a geçer.
  final AramaEfekti efekt;

  /// Karşı tarafın kullanıcı adı (başlıkta gösterilir).
  final String karsiTaraf;
  final String? karsiAvatar;

  /// `'ses'` | `'goruntu'`.
  final String tur;

  /// Bu bir GELEN arama mı (aranan tarafı mıyız).
  final bool gelen;

  /// Gelen aramada baştan bilinir; giden aramada `/arama/baslat` doldurur.
  String? aramaId;

  /// Gelen aramada karşı tarafın teklif SDP'si.
  final String? gelenTeklifSdp;

  /// Sunucudan gelen çalma süresi (sözleşme: 45 sn).
  final int calmaSaniye;

  GorusmeDurum durum = GorusmeDurum.hazirlaniyor;

  /// Arama bittiyse kullanıcıya gösterilecek kapanış metni.
  String? sonucMetni;

  /// Bittiyse hata mı (SnackBar kırmızısı) yoksa olağan bir kapanış mı.
  bool sonucHata = false;

  bool sessiz = false;
  bool kameraAcik = true;
  bool hoparlor = false;

  /// Medya akmaya başladığı an; süre sayacı buradan hesaplanır.
  DateTime? baglandiAn;

  bool _hicBaglandi = false;
  bool _iceKoptu = false;
  bool _calmaZamanAsimi = false;
  bool _kapaniyor = false;
  bool _cevapUygulandi = false;

  /// Arama KURULUMU sürüyor: [aramaBaslat] ya da [kabulEt] hâlâ çalışıyor.
  ///
  /// *** BU BAYRAK BİR HATA DÜZELTMESİDİR (10 Ağu 2026). ***
  ///
  /// Ne oluyordu: kurulum sırasında (teklif/cevap üretilirken ya da
  /// `POST /arama/baslat` uçarken) medya katmanı `koptu` derse
  /// (`RTCPeerConnectionState` -> failed/closed; ağ değişimi, TURN'e
  /// erişilememesi, eş bağlantının erken kapanması) [_halleriDinle] hemen
  /// `kapat(metin: 'Bağlanılamadı')` çağırıyordu. O çağrı [_bitir]'i
  /// çalıştırıp `_kapaniyor`u true yapıyor ve [sonucMetni]'ni GENEL metne
  /// sabitliyordu. Saniyeler sonra sunucunun ÖZEL cevabı
  /// (`ALICI_MISAFIR`, `ALICI_SESLI_KAPALI`, `TAKIP_YOK`...) gelip
  /// [aramaBaslat]'ın `catch`ine düşüyor, orada DOĞRU metne çevriliyor — ama
  /// ikinci [_bitir] çağrısı `if (_kapaniyor) return` ile geri dönüyordu.
  /// Sonuç: sunucu sebebi söylüyor, kullanıcı "Bağlanılamadı" görüyor.
  /// (`test/misafir_arama_test.dart` -> "YARIŞ" testleri bunu kilitliyor.)
  ///
  /// Neden ÇÖZÜM BURADA, `_bitir`de değil: kurulum sürerken taşıma katmanının
  /// GENEL hatası kullanıcıya SEBEP olarak gösterilemez. Davet daha karşıya
  /// ulaşmadan "bağlanılamadı" demek zaten anlamsız — kurulacak bir bağlantı
  /// yok. Otoriter cevap kurulum akışından gelir; `koptu` yalnız kaydedilir
  /// ([_iceKoptu]) ve iki yerde kullanılır: `POST /arama/bitir`in `sebep`
  /// alanı, ve kurulum BAŞARIYLA bittiğinde "aslında medya öldü" kararı.
  ///
  /// *** ERTELEME UNUTULAMAZ ***: kurulum başarılı biterse [_iceKoptu] orada
  /// tekrar okunup arama kapatılıyor. Yoksa ekran 45 saniye "Çalıyor..."
  /// gösterir, sonra "Cevap yok" der — kullanıcıya YANLIŞ sebep.
  bool _kurulumSuruyor = false;

  /// [dispose] çağrıldı mı.
  ///
  /// GEREKLİ: ekran kapanırken `dispose()` önce `kapat()`i (ASENKRON) sonra
  /// `super.dispose()`u çağırıyor; `kapat()` bittiğinde nesne çoktan atılmış
  /// oluyor ve `notifyListeners()` hata ayıklama kipinde
  /// "A GorusmeDenetci was used after being disposed" assertion'ı atıyordu.
  /// Yayın derlemesinde sessizdi ama hata ayıklamada her arama kapanışında
  /// kırmızı ekran demekti (`test/gorusme_ekrani_test.dart` yakaladı).
  bool _atildi = false;
  DateTime? _sonaErme;

  Timer? _yoklama;
  Timer? _calmaSayaci;
  Timer? _baglantiBekleme;
  Timer? _sureSayaci;
  StreamSubscription<BaglantiHali>? _halAbonelik;

  /// Arama süresi (yalnız `konusuyor` hâlinde anlamlı).
  Duration get sure => baglandiAn == null
      ? Duration.zero
      : DateTime.now().difference(baglandiAn!);

  /// 4 saatlik üst sınıra son [aramaSuresiUyarisi] kadar kaldı mı.
  bool get sureUyarisi =>
      baglandiAn != null && sure >= azamiAramaSuresi - aramaSuresiUyarisi;

  void _bildir() {
    if (_atildi) return;
    if (!_kapaniyor || durum == GorusmeDurum.bitti) notifyListeners();
  }

  void _halleriDinle() {
    _halAbonelik = surucu.haller.listen((hal) {
      switch (hal) {
        case BaglantiHali.bagli:
          if (_hicBaglandi) return;
          _hicBaglandi = true;
          _baglantiBekleme?.cancel();
          // ***YOKLAMA TAMAMEN DURUR*** (sözleşme §1). Sunucu boyutlandırması
          // buna göre yapıldı; medya P2P akıyor, sunucunun haberi olmasına
          // gerek yok.
          _yoklamaDur();
          // Zil SUSAR (bağlandık) + "bağlandı" haptiği: geçiş hissedilsin.
          unawaited(efekt.zilDurdur());
          unawaited(efekt.haptik(AramaHaptik.baglandi));
          durum = GorusmeDurum.konusuyor;
          baglandiAn = DateTime.now();
          _sureSayaci = Timer.periodic(const Duration(seconds: 1), (_) {
            if (sure >= azamiAramaSuresi) {
              // Sunucu da tam bu anda kaydı `cevaplandi` yapıp kilidi açıyor.
              kapat(zamanAsimi: true, metin: 'Arama süre sınırına ulaştı'.c);
              return;
            }
            _bildir();
          });
          _bildir();
        case BaglantiHali.koptu:
          _iceKoptu = true;
          if (_kapaniyor) return;
          // Kurulum SÜRÜYORSA sebebi kurulum akışı söyler; genel
          // "Bağlanılamadı" metni onu ezmemeli (bkz. [_kurulumSuruyor]).
          // `_iceKoptu` yukarıda zaten kaydedildi: `POST /arama/bitir`in
          // `sebep` alanı da, kurulum sonundaki erteleme kontrolü de ondan
          // besleniyor, yani hiçbir bilgi kaybolmuyor.
          if (_kurulumSuruyor) return;
          kapat(
            metin: _hicBaglandi ? 'Bağlantı koptu'.c : 'Bağlanılamadı'.c,
            hata: true,
          );
        case BaglantiHali.bekliyor:
          break;
      }
    });
  }

  /// Mikrofonu (görüntülüyse kamerayı da) açar ve eş bağlantısını kurar.
  ///
  /// İzin reddi burada yakalanır ve **kullanıcıya söylenir**. `sohbet.dart`ın
  /// sesli mesaj kaydındaki `if (!await hasPermission()) return;` kalıbı
  /// arama ekranında KABUL EDİLEMEZ (sözleşme §14.5): kullanıcı "ara"ya
  /// basar, hiçbir şey olmaz ve nedenini öğrenemez.
  Future<AramaHatasi?> _medyayiAc(BuzAyari buz) async {
    try {
      _halleriDinle();
      await surucu.kur(buzSunuculari: buz.sunucular, goruntu: tur == 'goruntu');
      // Görüntülü aramada sürücü HOPARLÖRÜ açtı (sesli aramada AHİZE); düğme
      // durumu bunu yansıtsın (sözleşme kalite turu §2, ses yönlendirme).
      if (tur == 'goruntu') hoparlor = true;
      return null;
    } catch (_) {
      final h = AramaHatasi(
        null,
        tur == 'goruntu'
            ? 'Görüntülü arama için kamera ve mikrofon izni gerekiyor'.c
            : 'Arama için mikrofon izni gerekiyor'.c,
        AramaTepkisi.kapat,
      );
      await _bitir(sunucuyaBildir: false, metin: h.metin, hata: true);
      return h;
    }
  }

  // ---------------- Giden arama ----------------

  /// Arayan akışı: medya aç → teklif (ICE toplama TAMAMLANANA KADAR bekle) →
  /// `POST /arama/baslat` → 1 sn'lik yoklama.
  ///
  /// Hata olursa [sonucMetni] doldurulur ve durum `bitti` olur; **sessizce
  /// dönmez** — arama ekranında sessiz başarısızlık kabul edilemez.
  Future<AramaHatasi?> aramaBaslat(BuzAyari buz) async {
    // Bayrak `_medyayiAc`ten ÖNCE kalkıyor: `koptu`, teklif üretilirken de
    // (ICE toplama 6 sn'ye kadar sürebiliyor) gelebilir ve o an da otoriter
    // sebep bu akıştadır — izin reddiyse "mikrofon izni gerekiyor".
    _kurulumSuruyor = true;
    try {
      final izin = await _medyayiAc(buz);
      if (izin != null) return izin;
      final sdp = await surucu.teklifUret();
      final d = await GorusmeApi.baslat(
        kullaniciAdi: karsiTaraf,
        tur: tur,
        sdp: sdp,
      );
      if (d['durum'] == 'mesgul') {
        // §13.3: `arama_id` null gelir; yoklamaya HİÇ başlanmaz.
        await _bitir(sunucuyaBildir: false, metin: 'Meşgul'.c, hata: true);
        return null;
      }
      aramaId = d['arama_id'] as String?;
      _sonaErme = DateTime.fromMillisecondsSinceEpoch(
        ((d['sona_erme'] as num?)?.toInt() ?? 0) * 1000,
      );
      durum = GorusmeDurum.caliyor;
      _bildir();
      // Kurulum sırasında gelen `koptu` ERTELENMİŞTİ ([_kurulumSuruyor]);
      // davet başarılı olduğuna göre artık otoriter bir sunucu sebebi yok ve
      // medya gerçekten ölü. Ele almazsak ekran 45 saniye "Çalıyor..."
      // gösterir, sonra "Cevap yok" der — kullanıcıya YANLIŞ sebep.
      if (_iceKoptu) {
        final metin = 'Bağlanılamadı'.c;
        await _bitir(sunucuyaBildir: true, metin: metin, hata: true);
        return AramaHatasi(null, metin, AramaTepkisi.kapat);
      }
      // ZİL BURADA BAŞLAR: davet karşıya ulaştı ve gerçekten çalıyor. Daha
      // erken (durum=caliyor anında) başlatmıyoruz — `_iceKoptu` yukarıda
      // aramayı kapatabilirdi ve o zaman bir an bile zil çalması yanıltıcı olur.
      // Zil YALNIZ giden aramada duyulur: bu akışa (arayan) özgü.
      unawaited(efekt.haptik(AramaHaptik.caliyor));
      unawaited(efekt.zilCal());
      _yoklamaBaslat();
      _calmaSayaci = Timer(Duration(seconds: calmaSaniye + 2), () {
        if (durum != GorusmeDurum.caliyor) return;
        _calmaZamanAsimi = true;
        kapat(metin: 'Cevap yok'.c, hata: true);
      });
      return null;
    } catch (e) {
      final h = aramaHatasiCozumle(e);
      await _bitir(sunucuyaBildir: aramaId != null, metin: h.metin, hata: true);
      return h;
    } finally {
      // Hata yolunda da inmeli: yoksa sonraki her `koptu` sonsuza kadar
      // yutulur ve arama ekranı bir daha hiç kapanmaz.
      _kurulumSuruyor = false;
    }
  }

  void _yoklamaBaslat() {
    _yoklama?.cancel();
    _yoklama = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _yoklamaTuru(),
    );
  }

  void _yoklamaDur() {
    _yoklama?.cancel();
    _yoklama = null;
  }

  Future<void> _yoklamaTuru() async {
    final id = aramaId;
    if (id == null || _kapaniyor) return;
    try {
      final d = await GorusmeApi.durum(id);
      final sdp = d['sdp'] as String?;
      if (sdp != null && sdp.isNotEmpty && !_cevapUygulandi) {
        _cevapUygulandi = true;
        durum = GorusmeDurum.baglaniyor;
        _calmaSayaci?.cancel();
        // Karşı taraf CEVAPLADI: zil susar (telefon disiplini — ringback,
        // aranan açınca kesilir). Medya birazdan akacak, "Bağlanıyor..." görünür.
        unawaited(efekt.zilDurdur());
        _bildir();
        await surucu.uzakCevabiUygula(sdp);
        _baglantiBeklemeBaslat();
      }
      // `adaylar` normal akışta DAİMA boştur (trickle YOK, sözleşme §4.3).
      // Yalnız ICE yeniden başlatmada dolar ve o özellik bu turda YOK
      // (bkz. dosya sonundaki "F2'ye kalanlar" notu) — okunup atılıyor,
      // çünkü sunucu teslim ettiğini bellekten siliyor.
    } catch (e) {
      if (e is ApiHata && e.makineKodu == AramaKod.aramaYok) {
        // Kayıt uç duruma geldi ve bellekten silindi.
        final erme = _sonaErme;
        final reddedildi = erme != null && reddedildiMi(sonaErme: erme);
        _calmaZamanAsimi = !reddedildi;
        await _bitir(
          sunucuyaBildir: false,
          metin: reddedildi ? 'Arama reddedildi'.c : 'Cevap yok'.c,
          hata: true,
        );
      }
      // Diğer hatalar (ağ dalgalanması) yutulur; bir sonraki tur dener.
    }
  }

  // ---------------- Gelen arama ----------------

  /// Aranan akışı: medya aç → cevap üret (ICE toplama tamam) →
  /// `POST /arama/yanit {kabul:true}`.
  Future<AramaHatasi?> kabulEt(BuzAyari buz) async {
    // Giden aramadaki ile AYNI gerekçe (bkz. [_kurulumSuruyor]): cevap
    // üretilirken gelen `koptu`, sunucunun söyleyeceği sebebi
    // (409 DURUM_UYGUN_DEGIL, 403 TAKIP_YOK/ENGELLI...) ezmemeli.
    _kurulumSuruyor = true;
    try {
      final izin = await _medyayiAc(buz);
      if (izin != null) {
        // İzin verilmediyse arayan sonsuza kadar çalmasın: aramayı REDDET.
        // Sessizce dönmek, arayanın 45 sn boyunca "Çalıyor..." görmesi demekti.
        try {
          await GorusmeApi.yanit(aramaId: aramaId!, kabul: false);
        } catch (_) {}
        return izin;
      }
      final sdp = await surucu.cevapUret(gelenTeklifSdp!);
      await GorusmeApi.yanit(aramaId: aramaId!, kabul: true, sdp: sdp);
      durum = GorusmeDurum.baglaniyor;
      _bildir();
      // Ertelenmiş `koptu` (bkz. [aramaBaslat]'taki aynı blok).
      if (_iceKoptu) {
        final metin = 'Bağlanılamadı'.c;
        await _bitir(sunucuyaBildir: true, metin: metin, hata: true);
        return AramaHatasi(null, metin, AramaTepkisi.kapat);
      }
      _baglantiBeklemeBaslat();
      return null;
    } catch (e) {
      final h = aramaHatasiCozumle(e);
      await _bitir(sunucuyaBildir: true, metin: h.metin, hata: true);
      return h;
    } finally {
      _kurulumSuruyor = false;
    }
  }

  /// `POST /arama/yanit {kabul:false}` — SDP yok sayılır, kayıt uçlaşır.
  Future<void> reddet() async {
    try {
      await GorusmeApi.yanit(aramaId: aramaId!, kabul: false);
    } catch (_) {
      // Arayan çoktan kapatmış olabilir (409 DURUM_UYGUN_DEGIL); ekran yine
      // kapanır.
    }
    await _bitir(sunucuyaBildir: false, metin: null);
  }

  void _baglantiBeklemeBaslat() {
    _baglantiBekleme?.cancel();
    _baglantiBekleme = Timer(baglantiBeklemeSuresi, () {
      if (_hicBaglandi || _kapaniyor) return;
      // Kabul edildi ama ICE hiç kurulamadı → `ice_basarisiz`.
      kapat(metin: 'Bağlanılamadı'.c, hata: true);
    });
  }

  // ---------------- Kapanış ----------------

  /// Kullanıcı "Kapat"a bastığında ya da bağlantı düştüğünde çağrılır.
  Future<void> kapat({
    String? metin,
    bool hata = false,
    bool zamanAsimi = false,
  }) async {
    if (zamanAsimi) _calmaZamanAsimi = true;
    await _bitir(sunucuyaBildir: true, metin: metin, hata: hata);
  }

  Future<void> _bitir({
    required bool sunucuyaBildir,
    String? metin,
    bool hata = false,
  }) async {
    if (_kapaniyor) return;
    _kapaniyor = true;
    _yoklamaDur();
    _calmaSayaci?.cancel();
    _baglantiBekleme?.cancel();
    _sureSayaci?.cancel();
    // Zil her hâlde SUSAR (idempotent) + kapanış haptiği. Susmayan zil, hiç
    // olmayan zilden beterdir.
    unawaited(efekt.zilDurdur());
    unawaited(efekt.haptik(AramaHaptik.kapandi));
    await _halAbonelik?.cancel();

    final id = aramaId;
    if (sunucuyaBildir && id != null) {
      final sebep = bitirSebebi(
        durum: durum,
        hicBaglandi: _hicBaglandi,
        iceKoptu: _iceKoptu,
        calmaZamanAsimi: _calmaZamanAsimi,
      );
      // Ölçüm bağlantı KAPANMADAN önce alınır; sonra sayaçlar gider.
      final olcum = _hicBaglandi ? await surucu.olcumAl() : null;
      try {
        await GorusmeApi.bitir(aramaId: id, sebep: sebep, olcum: olcum?.json);
      } catch (_) {
        // Sunucu yeniden başlamış olabilir (200 + durum:null) ya da ağ
        // kopmuş olabilir. İkisi de KULLANICIYA HATA OLARAK GÖSTERİLMEZ
        // (sözleşme §11 ve §13.10): medya zaten kesildi, yapılacak bir şey
        // yok.
      }
    }
    await surucu.kapat();
    durum = GorusmeDurum.bitti;
    sonucMetni = metin;
    sonucHata = hata;
    if (!_atildi) notifyListeners();
  }

  Future<void> sessizDegistir() async {
    sessiz = !sessiz;
    await surucu.sessizeAl(sessiz);
    _bildir();
  }

  Future<void> kameraDegistir() async {
    kameraAcik = !kameraAcik;
    await surucu.kamerayiAc(kameraAcik);
    _bildir();
  }

  Future<void> hoparlorDegistir() async {
    hoparlor = !hoparlor;
    await surucu.hoparlor(hoparlor);
    _bildir();
  }

  Future<void> kamerayiCevir() => surucu.kamerayiCevir();

  @override
  void dispose() {
    _atildi = true;
    _yoklamaDur();
    _calmaSayaci?.cancel();
    _baglantiBekleme?.cancel();
    _sureSayaci?.cancel();
    _halAbonelik?.cancel();
    // Oynatıcıyı bırak (zil kaynağını kapat). `_bitir` zaten susturdu; bu son
    // temizlik.
    efekt.bosalt();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// F2'YE KALANLAR (bilinçli kapsam dışı, sözleşme §14.1 madde 9)
//
// **ICE yeniden başlatma (`POST /arama/aday`) BAĞLANMADI.** Ağ değişince
// (Wi-Fi ↔ hücresel) yeni aday üretip karşıya yollamak, bağlantı kurulduktan
// SONRA yoklamayı yeniden başlatmayı gerektirir — ki §1 tam tersini söylüyor
// ("bağlantı kurulunca yoklama TAMAMEN durur") ve sunucunun hız limiti
// boyutlandırması da o varsayıma göre yapıldı. İkisini birden doğru yapmak
// ayrı bir karar ister: yoklamayı yalnız `RTCPeerConnectionState`
// `disconnected` olduğunda, sınırlı süreyle geri açmak.
//
// Bugünkü davranış: ağ değişince bağlantı kopar, sürücü `koptu` der, arama
// `ag_koptu` sebebiyle temiz kapanır ve kullanıcı "Bağlantı koptu" görür.
// Sessiz bir arıza DEĞİL, eksik bir özellik. `GorusmeApi.aday` uç
// sarmalayıcısı bu iş için hazır duruyor.
// ---------------------------------------------------------------------------
