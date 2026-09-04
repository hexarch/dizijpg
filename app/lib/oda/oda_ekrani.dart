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
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show
        Clipboard,
        ClipboardData,
        DeviceOrientation,
        SystemChrome,
        SystemUiMode;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../api.dart';
import '../ceviri.dart';
import '../ekranlar/kabuk.dart' show KabukTamEkran;
import '../ekranlar/ortak.dart';
import '../tema.dart';
import 'oda_api.dart';
import 'oda_senkron.dart';
import 'oda_tercihi.dart';
import 'oda_yukle.dart';

/// Sohbetin yan panele geçtiği genişlik. Altında video üstte, sohbet altta.
const double _genisEsik = 900;

/// Tam ekranda (ve geniş ekranda) sohbet panelinin genişliği.
const double _sohbetPaneliGenislik = 320;

/// Panelin açılıp kapanma süresi — ui-ux-pro-max Animation: 150-300 ms.
const Duration _panelSuresi = Duration(milliseconds: 200);

/// TELEFON eşiği: kısa kenarı BUNDAN KÜÇÜK olan cihazda yön otomatiği çalışır.
///
/// 600 dp, telefon/tablet ayrımının yerleşik sınırıdır (Android `sw600dp`).
/// Otomatik tam ekran bir TELEFON davranışıdır: masaüstü tarayıcı penceresi ve
/// tablet zaten daima "yatay" sayılır; oda açılır açılmaz kendini tam ekranda
/// bulmak kimsenin istemediği bir sürpriz olurdu.
///
/// Karşılaştırma `<` (eşit DEĞİL): 600 dp'nin kendisi tablet sayılır.
const double _telefonKisaKenar = 600;

/// Kontroller dokunulmayınca bu süre sonra söner.
///
/// 3 saniye: YouTube ve sistem oynatıcılarının yerleşik değeri. Daha kısası
/// (1-2 sn) kullanıcı düğmeye uzanırken kontrolleri elinden alır; daha uzunu
/// "sadece video gözüksün" isteğini karşılamaz.
const Duration kontrolSonmeSuresi = Duration(seconds: 3);

/// Sönme/belirme geçişi. ui-ux-pro-max Animation: 150-300 ms; ani kaybolma
/// kullanıcıya "bir şey bozuldu" hissi verir.
const Duration kontrolSonmeGecisi = Duration(milliseconds: 200);

/// Tam ekrandan çıkarken DİKEY kısıtının kaç ms sonra kaldırılacağı.
///
/// Kısıt bir an dayatılır ki cihaz gerçekten dönsün; hemen kaldırılsaydı bazı
/// cihazlar yatayda kalırdı. Kalıcı bırakmak ise kullanıcıyı uygulamanın
/// tamamında dikeye kilitler — gerekçe [_OdaEkraniState._yonuAyarla]'da.
const Duration _yonSerbestGecikmesi = Duration(milliseconds: 700);

/// Tam ekranda mesajların videonun üstünde bindirildiği panelin AZAMİ genişliği.
///
/// Ekranın %38'i ile sınırlı: sabit 320 dp, dar bir telefonda yatayken bile
/// videonun üçte birinden fazlasını yerdi. Kullanıcı isteği zaten "panel"
/// değil bindirme — *"mesajlar videonun sağında emojiler gibi gözükmeli"*.
const double _bindirmeAzamiGenislik = 320;

/// Videonun kapladığı SİYAH yüzeyin anahtarı — testler genişliğini ölçer.
///
/// Dolaylı iddialar (AspectRatio boyu, GestureDetector sırası) 4 Eyl'deki
/// hatayı yakalayamıyordu: dikeyde tam ekrana geçince yan panel 320 dp alıyor,
/// videoya 40 dp kalıyordu ama en-boy oranı yine "geçerli" görünüyordu.
@visibleForTesting
const Key odaVideoYuzeyiAnahtari = ValueKey('oda-video-yuzeyi');

/// Bindirmede aynı anda en fazla kaç mesaj görünür.
///
/// Canlı yayın sohbeti kalıbı: ekranı kaplamamalı, son birkaç satır yeter.
/// Fazlası videoyu okunmaz hâle getirir.
const int _bindirmeAzamiSatir = 7;

/// Kontroller ŞU AN sönebilir mi — SAF kural, tek doğru.
///
/// Ayrı ve saf, çünkü asıl değer KENAR DURUMLARINDA: her biri atlanırsa
/// gerçek bir sinir bozukluğu üretiyor ve hiçbiri widget testinde kolayca
/// kurulamıyor (gerçek bir `VideoPlayerController` gerekirdi). `oda_senkron`
/// ve `oda.js` ile aynı disiplin: kararı saf tut, kenarları testle kilitle.
///
/// SÖNMEYEN HÂLLER:
///  · [videoHazir] değil — sönecek kontrol yok; "Video yükle" düğmesi
///    kaybolursa ekranın tek çıkış yolu gider.
///  · [oynuyor] değil — kullanıcı bilinçli duraklattı; o an ekranda aradığı
///    şey zaten kontrollerdir.
///  · [cubukSuruklemede] — parmağın altındaki ilerleme çubuğunu kaybetmek.
///  · [yaziyor] — sohbete yazarken kontroller giderse, kullanıcı mesajı
///    gönderdikten sonra ekrana ayrıca dokunmak zorunda kalır.
///  · [yuklemeVar] — ilerleme çubuğu bir DURUM göstergesi; 5 GB yüklenirken
///    kaybolmamalı.
@visibleForTesting
bool kontrolSonebilir({
  required bool videoHazir,
  required bool oynuyor,
  required bool cubukSuruklemede,
  required bool yaziyor,
  required bool yuklemeVar,
}) => videoHazir && oynuyor && !cubukSuruklemede && !yaziyor && !yuklemeVar;

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

  /// Hata KALICI mı — yani ekranın geri kalanını göstermenin anlamı kalmadı mı.
  ///
  /// ⚠ Bu bayrak olmadan `_hata` yalnız oda HİÇ YÜKLENMEMİŞKEN görünüyordu
  /// (`build`: `_hata != null && oda == null`). Oda yüklendikten SONRA kapanan
  /// ya da üyeliği düşen kullanıcı hiçbir şey görmüyor, boş bir odaya bakıp
  /// mesaj yazmayı deniyordu (3 Eyl 2026, canlıda "mesajlarım gitmiyor").
  bool _kalici = false;

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

  /// SUNUCUDAN GÖRÜLEN son satır id'si — yoklamanın imleci.
  ///
  /// ===========================================================================
  /// NEDEN [_mesajlar]'DAN TÜRETİLMİYOR (3 Eyl 2026, canlıda emoji sonsuz
  /// döngüsü)
  /// ===========================================================================
  /// İmleç `_mesajlar.last.id` idi. Ama TEPKİLER listeye girmiyor (bilinçli:
  /// 12 kişilik bir odada sohbet emoji yağmuruna dönerdi). Yani en yeni satır
  /// bir tepkiyse imleç onu ASLA geçmiyordu; sunucu `id > mesajdan` sorgusuna
  /// her turda AYNI tepkiyi döndürüyor, `_tepkiUcur` saniyede bir yeniden
  /// çağrılıyor ve emoji sonsuza kadar uçuyordu.
  ///
  /// KURAL: **çizilen liste ile imleç AYNI ŞEY DEĞİLDİR.** İmleci listeden
  /// türetmek, listeye girmeyen bir satır türü olduğu anda sonsuz tekrara yol
  /// açar. Buradaki imleç GÖRÜLEN her satırı sayar — tepki, sistem satırı ve
  /// kendi mesajın dahil.
  ///
  /// İyimser satırlar da ayrıca imleci bozardı: onların id'si YERELDİR
  /// (negatif) ve sunucunun sırasıyla ilgisi yoktur.
  int _sonMesajId = 0;

  /// Listede ÇİZİLİ gerçek satır id'leri — yoklamanın çift satır eklemesini
  /// önler (iyimser satır onaylanınca gerçek id'sini alır, sonra yoklama aynı
  /// satırı getirir; burada elenir).
  final _cizilenIdler = <int>{};

  /// İyimser satır anahtarı sayacı ve "tekrar dene" eylemleri.
  int _yerelSayac = 0;
  final _yerelTekrar = <String, Future<void> Function()>{};

  // ---- TAM EKRAN ----------------------------------------------------------

  bool _tamEkran = false;

  /// Sohbet paneli açık mı (tam ekranda ve geniş ekranda). [OdaTercihi]'nden
  /// yüklenir, değişince oraya yazılır.
  bool _sohbetAcik = OdaTercihi.sohbetAcik.value;

  /// EN SON İŞLENEN yön. Otomatik karar YALNIZ bu değiştiğinde uygulanır.
  ///
  /// ===========================================================================
  /// NEDEN "yalnız yön DEĞİŞİNCE" — kullanıcının elle verdiği karar kutsaldır
  /// ===========================================================================
  /// İstek iki cümle: *"yan çevirince otomatik tam ekrana geçsin"* ve
  /// *"sohbeti gizleme açma kapama olsun"*. Yani otomatik davranış var ama
  /// kullanıcı hâlâ yönetiyor. Otomatiği her yeniden çizimde uygulasaydık,
  /// telefon yatayken tam ekrandan ELLE çıkan kullanıcı bir sonraki karede
  /// geri tam ekrana atılırdı — düğmesi çalışmıyor sanırdı.
  ///
  /// Çözüm: otomatik karar bir OLAYA bağlı, bir DURUMA değil. Yön değişimi bir
  /// olaydır; o an karar uygulanır ve [_sonYon] güncellenir. Elle yapılan
  /// değişiklik [_sonYon]'a DOKUNMAZ, dolayısıyla aynı yön içinde otomatik bir
  /// daha konuşmaz. Kullanıcı telefonu çevirdiğinde otomatik yeniden devreye
  /// girer — çünkü orada gerçekten yeni bir niyet vardır.
  Orientation? _sonYon;

  /// Tam ekrandan çıkarken dayatılan DİKEY kısıtını kaldıracak sayaç.
  /// (Gerekçe [_yonuAyarla]'da: kalıcı kısıt kullanıcıyı uygulamanın
  /// tamamında dikeye kilitlerdi.)
  Timer? _yonKisitiSayaci;

  /// Cihaza GERÇEKTEN bir yön kısıtı uyguladık mı. `dispose` bunu okur;
  /// oradan `context`e bakmak yasak olduğu için bayrak şart.
  bool _yonDayatildi = false;

  // ---- KONTROLLERİN KENDİLİĞİNDEN SÖNMESİ --------------------------------

  /// Oynatma kontrolleri ve tepki şeridi şu an görünür mü.
  ///
  /// KULLANICI İSTEĞİ (4 Eyl 2026): *"ekrana bir süre tıklanmayınca da video
  /// player şeyleri gitsin ileri sarma falan sadece video gözüksün"*.
  bool _kontrolGorunur = true;

  Timer? _sonmeSayaci;

  /// İlerleme çubuğu ŞU AN sürükleniyor mu — sürüklerken sönmek, kullanıcının
  /// elinin altındaki çubuğu kaybetmesi demek olurdu.
  bool _cubukSuruklemede = false;

  /// Sohbet yazı alanının odağı. Klavye açıkken kontroller sönmemeli:
  /// kullanıcı yazarken video kontrollerini de kaybederse, mesajı gönderip
  /// ekrana ayrıca dokunmak zorunda kalır.
  final _metinOdak = FocusNode();

  /// `_cik()` sırasında PopScope'un programlı `pop`u yutmasını engeller.
  ///
  /// ⚠ `canPop: false` YALNIZ geri hareketini değil `Navigator.pop`u da
  /// yakalar (aynı tuzak `paylas_yorum.dart`ta yazılı). Odayı kapatıp
  /// çıkarken tam ekrandaysak, pop "tam ekrandan çık"a dönüşür ve kullanıcı
  /// KAPANMIŞ bir odanın içinde kalırdı.
  bool _cikiliyor = false;

  int get _benimId =>
      (context.read<Oturum>().kullanici?['id'] as num?)?.toInt() ?? -1;

  bool get _sahipMiyim => _oda?.sahibiMiyim == true;

  /// Oynatmayı ve videoyu YÖNETEBİLİR miyim — sahip ya da yetkili.
  ///
  /// Kontrollerin çizilip çizilmeyeceği buna bakar; `_sahipMiyim` ise artık
  /// yalnız SAHİBE ÖZEL işlerde (odayı kapat, davet et, yetki ver) kullanılır.
  /// İkisini ayırmak şart: kullanıcı kararı (4 Eyl) "yetki verdiği de aynı
  /// şekilde video durdurabilir kapatabilir" ama odayı kapatamaz.
  bool get _yonetebilirMiyim {
    final rol = _oda?.benimRol;
    return _sahipMiyim || rol == 'yetkili';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ilkYukle();
    OdaTercihi.yukle().then((_) {
      if (mounted) setState(() => _sohbetAcik = OdaTercihi.sohbetAcik.value);
    });
    // Klavye açılıp kapanınca sönme kuralı değişir: yazarken sönmemeli,
    // yazmayı bırakınca yeniden sönebilmeli.
    _metinOdak.addListener(() {
      if (!mounted) return;
      if (_metinOdak.hasFocus) {
        _kontrolleriGoster();
      } else {
        _sonmeyiKur();
      }
    });
    // İlk kare: o anki yönü İŞLE. Telefonu zaten yatay tutarken odaya giren
    // biri videoyu büyük görmek istiyordur; dikeye çevirince kendiliğinden
    // çıkacağı için bu bir tuzak değil.
    WidgetsBinding.instance.addPostFrameCallback((_) => _yonuIsle());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // SİSTEM ÇUBUKLARINI GERİ VER. Atlanırsa odadan çıkan kullanıcı,
    // uygulamanın geri kalanında çubuksuz (immersive) bir telefonla kalırdı —
    // ve bunun oda ekranından geldiğini asla anlayamazdı.
    if (_tamEkran) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    // KABUK ÇUBUĞUNU KOŞULSUZ GERİ VER. `if (_tamEkran)` ile koşullamak
    // yetmez: bayrak global ve açık kalırsa kullanıcı odadan çıktıktan sonra
    // uygulamanın HİÇBİR yerinde gezinme çubuğu göremez.
    KabukTamEkran.sifirla();
    // YÖN KISITINI KOŞULSUZ GERİ VER — aynı gerekçe: kısıt cihaz genelinde
    // etkili, açık kalırsa kullanıcı uygulamanın hiçbir yerinde telefonunu
    // çeviremez ve sebebini asla bulamaz.
    _yonKisitiniKaldir();
    _sonmeSayaci?.cancel();
    _yoklama?.cancel();
    _kalp?.cancel();
    _yukleyici?.iptal();
    _oynatici?.dispose();
    _metin.dispose();
    _metinOdak.dispose();
    _kaydirma.dispose();
    super.dispose();
  }

  /// Cihaz döndüğünde Flutter bunu çağırır (test: `tester.view.physicalSize`).
  @override
  void didChangeMetrics() {
    if (!mounted) return;
    // Ölçüler `View`den okunuyor, `MediaQuery`den DEĞİL: bu geri çağırma
    // MediaQuery yeniden kurulmadan önce de gelebilir ve o an bayat bir yön
    // okunurdu.
    WidgetsBinding.instance.addPostFrameCallback((_) => _yonuIsle());
  }

  /// Yön değiştiyse otomatik tam ekran kararını uygular.
  void _yonuIsle() {
    if (!mounted) return;
    final gorunum = View.of(context);
    final boyut = gorunum.physicalSize / gorunum.devicePixelRatio;
    if (boyut.isEmpty) return;
    final yon = boyut.width >= boyut.height
        ? Orientation.landscape
        : Orientation.portrait;
    if (_sonYon == yon) return; // aynı yön: ELLE verilen kararı ezme
    _sonYon = yon;
    // Masaüstü/tablet daima "yatay"dır; orada otomatik konuşmaz.
    if (boyut.shortestSide >= _telefonKisaKenar) return;
    final hedef = yon == Orientation.landscape;
    if (hedef != _tamEkran) _tamEkraniAyarla(hedef);
  }

  /// Tam ekranı açar/kapatır ve sistem çubuklarını buna göre ayarlar.
  ///
  /// ***TEK YOL.*** Düğme, geri tuşu ve yön otomatiği ÜÇÜ DE buradan geçer.
  /// Üçüne ayrı ayrı yazsaydık biri düzelip öteki kalırdı — nitekim 4 Eyl'de
  /// yön çevirme hiç yazılmadığı için üçü birden kırıktı.
  void _tamEkraniAyarla(bool acik) {
    if (_tamEkran == acik) return;
    setState(() => _tamEkran = acik);
    _yonuAyarla(acik);
    // UYGULAMANIN alt gezinme çubuğu (kabuk) da gizlensin: sistem çubuklarını
    // saklayıp uygulamanınkini bırakmak "tam ekran"ı yarım bırakırdı.
    KabukTamEkran.ayarla(acik);
    SystemChrome.setEnabledSystemUIMode(
      // `immersiveSticky`: çubuklar gizlenir, kenardan kaydırınca GEÇİCİ
      // görünür ve kendiliğinden geri kaybolur. `immersive` (sticky olmayan)
      // ilk dokunuşta çubukları kalıcı geri getirirdi — video ortasında
      // ekranın üstü aniden dolar.
      acik ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    // Tam ekrana girerken/çıkarken kontroller görünsün ve sayaç yeniden
    // başlasın: kullanıcı yeni düzeni bir kez görmeli.
    _kontrolleriGoster();
  }

  /// Tam ekranda cihazı YATAYA, çıkışta DİKEYE çevirir.
  ///
  /// ===========================================================================
  /// NEDEN GEREKLİ (4 Eyl 2026, kullanıcı canlıda bildirdi)
  /// ===========================================================================
  /// *"dikey moddayken ekranı büyüt diyince yatay moda geçmiyor sağdaki sohbet
  /// kocaman oluyor solu komple baskılıyor"* — ölçüldü: 360 dp genişlikte
  /// sohbet paneli 320 dp alıyor, videoya **40 dp** kalıyordu. Tam ekran
  /// bayrağı yerleşimi değiştiriyor ama cihaz dikey kalıyordu.
  ///
  /// ===========================================================================
  /// ⚠ KISIT KALICI BIRAKILMAZ
  /// ===========================================================================
  /// `setPreferredOrientations([portraitUp])` verip ORADA BIRAKMAK, kullanıcıyı
  /// uygulamanın TAMAMINDA dikeye kilitler — odadan çıkar, bir daha hiçbir
  /// ekranda telefonunu çeviremez ve bunun oda ekranından geldiğini asla
  /// anlayamaz. Bu yüzden dikey yalnız BİR AN dayatılır (cihaz gerçekten
  /// dönsün diye), sonra kısıt kaldırılır. Aynı disiplin [KabukTamEkran]
  /// bayrağında da var: global olan şey koşulsuz geri verilir.
  ///
  /// Yalnız TELEFONDA çalışır: masaüstü/tablette yön dayatmak anlamsızdır
  /// (pencere zaten kullanıcının kontrolünde) ve web'de etkisizdir.
  void _yonuAyarla(bool tamEkran) {
    if (!_yonDayatilabilir) return;
    // Bir kısıt UYGULADIK: `dispose` bunu context'e dokunmadan geri alabilsin.
    _yonDayatildi = true;
    if (tamEkran) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      return;
    }
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _yonKisitiSayaci?.cancel();
    _yonKisitiSayaci = Timer(_yonSerbestGecikmesi, _yonKisitiniKaldir);
  }

  /// Yön kısıtını kaldırır — `dispose`ta da çağrılır, KOŞULSUZ.
  ///
  /// `context`e DOKUNMAZ: `dispose` sırasında `View.maybeOf(context)` okumak
  /// yasaktır. Bunun yerine "kısıt uyguladık mı" bayrağına bakar.
  void _yonKisitiniKaldir() {
    _yonKisitiSayaci?.cancel();
    _yonKisitiSayaci = null;
    if (!_yonDayatildi) return;
    _yonDayatildi = false;
    SystemChrome.setPreferredOrientations([]);
  }

  /// Yön dayatması yalnız telefonda anlamlı (masaüstü penceresi ve tablet hariç).
  bool get _yonDayatilabilir {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    final gorunum = View.maybeOf(context);
    if (gorunum == null) return false;
    final boyut = gorunum.physicalSize / gorunum.devicePixelRatio;
    if (boyut.isEmpty) return false;
    return boyut.shortestSide < _telefonKisaKenar;
  }

  // -------------------------------------------------------------------------
  // KONTROLLERİN SÖNMESİ
  // -------------------------------------------------------------------------

  /// Kontrolleri görünür yapar ve sönme sayacını sıfırdan başlatır.
  void _kontrolleriGoster() {
    if (!_kontrolGorunur) setState(() => _kontrolGorunur = true);
    _sonmeyiKur();
  }

  /// Sönme sayacını kurar — sönmemesi gereken hâllerde hiç kurmaz.
  ///
  /// SÖNMEYEN HÂLLER ve gerekçeleri:
  ///  · **Video duraklatılmış:** kullanıcı bilinçli durdurdu; o an ekranda
  ///    aradığı şey zaten kontrollerdir.
  ///  · **Çubuk sürükleniyor:** parmağın altındaki çubuğu kaybetmek.
  ///  · **Sohbete yazılıyor (klavye açık):** yazarken kontrollerin gitmesi,
  ///    mesajı gönderdikten sonra ekrana ayrıca dokunmayı zorunlu kılardı.
  ///  · **Video henüz yok:** sönecek kontrol de yok; "Video yükle" düğmesinin
  ///    kaybolması ekranı çıkışsız bırakırdı.
  ///  · **Yükleme sürüyor:** ilerleme çubuğu bir DURUM göstergesidir, 5 GB
  ///    yüklerken kaybolmamalı.
  void _sonmeyiKur() {
    _sonmeSayaci?.cancel();
    if (!_sonebilirMi) return;
    _sonmeSayaci = Timer(kontrolSonmeSuresi, () {
      if (!mounted || !_sonebilirMi) return;
      setState(() => _kontrolGorunur = false);
    });
  }

  bool get _sonebilirMi => kontrolSonebilir(
    videoHazir: _oynatici != null && _oynaticiHazir,
    oynuyor: _oda?.durum.oynuyor ?? false,
    cubukSuruklemede: _cubukSuruklemede,
    yaziyor: _metinOdak.hasFocus,
    yuklemeVar: _yuklemeDurumu != null,
  );

  Future<void> _sohbetiAcKapa() async {
    final yeni = !_sohbetAcik;
    setState(() => _sohbetAcik = yeni);
    await OdaTercihi.sohbetSec(yeni);
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
        _kalici = true;
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
        // İmleç ÇİZİLEN listeden değil, GÖRÜLEN son id'den (bkz. _sonMesajId).
        mesajdan: _sonMesajId,
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
      // ROL DEĞİŞİMİ: sahip kontrolü verdiğinde/aldığında karşı taraf ekranı
      // yeniden AÇMADAN kontrolleri görmeli (ya da kaybetmeli). Sunucu rolü
      // her turda gönderiyor; değiştiyse hemen uygula.
      if (akis.benimRol != null && akis.benimRol != _oda!.benimRol) {
        setState(() => _oda = _oda!.kopya(benimRol: akis.benimRol));
        // Yetki GİDERSE süren kalp atışını da durdur: yetkisi alınmış biri
        // 10 sn'de bir konum yazmaya devam ederse sunucuda 403 yığar.
        _kalbiKur(_oda!.durum.oynuyor);
        degisti = true;
      }
      // HAZIRLIK her turda güncellenir (durumdan bağımsız): yüzde sürüm
      // artmadan da ilerliyor. Değişmediyse setState çağırmayız — 1 sn'lik
      // yoklamada her turda yeniden çizim boşuna iş olurdu.
      if (akis.hazirlik.durum != _oda!.hazirlik.durum ||
          akis.hazirlik.yuzde != _oda!.hazirlik.yuzde ||
          akis.hazirlik.hata != _oda!.hazirlik.hata) {
        setState(() => _oda = _oda!.kopya(hazirlik: akis.hazirlik));
        degisti = true;
      }
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
        // İZLEYİCİDE de kural işlesin: sahip DURAKLATTIYSA kontroller geri
        // gelip kalmalı, yeniden OYNATTIYSA sönme sayacı baştan başlamalı.
        // Bu satır olmasaydı izleyici, sahibin duraklattığı videoda sönmüş
        // kontrollerle kalırdı.
        _kontrolleriGoster();
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
            // İMLEÇ HER SATIRDA İLERLER — çizilsin çizilmesin. Bu satır
            // olmasaydı tepkiler imleci geçemez ve sunucu aynı tepkiyi
            // sonsuza dek göndermeye devam ederdi (bkz. `_sonMesajId`).
            if (m.id > _sonMesajId) _sonMesajId = m.id;
            if (m.tepki != null) {
              // Kendi tepkin gönderirken ZATEN uçtu; ikinci kez uçurma.
              if (m.kullaniciId != _benimId) _tepkiUcur(m.tepki!);
              // Tepkiler sohbet listesine GİRMEZ: 12 kişilik bir odada sohbeti
              // emoji yağmuruna çevirirdi. Yalnız uçuşurlar.
              continue;
            }
            // Kendi iyimser satırım onaylandıysa yoklama onu YENİDEN eklemesin.
            if (_cizilenIdler.contains(m.id)) continue;
            _cizilenIdler.add(m.id);
            _mesajlar.add(m);
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
          _kalici = true;
          _hata = 'Bu oda kapandı'.c;
        });
      } else if (e.makineKodu == OdaKod.uyeDegil ||
          e.makineKodu == OdaKod.odaYok) {
        // KALICI durumlar SESSİZ KALAMAZ. Davet edilip odaya HENÜZ GİRMEMİŞ
        // biri her uçtan 403 alır; ekran sessiz kalırsa kullanıcı boş bir oda
        // görür, mesaj yazar, hiçbir şey olmaz ve nedenini ASLA öğrenemez
        // (3 Eyl 2026, canlıda "mesajlarım gitmiyor" olarak bildirildi).
        // Yoklamayı da durduruyoruz: saniyede bir 403 almanın faydası yok.
        _yoklama?.cancel();
        _oynatici?.pause();
        setState(() {
          _kalici = true;
          _hata = odaHataMetni(e);
        });
      }
      // GEÇİCİ hatalar sessiz: 1 sn'lik yoklamada bir ağ tökezlemesi için
      // SnackBar basmak ekranı kullanılamaz hâle getirirdi.
    } finally {
      _yoklamaUcuyor = false;
    }
  }

  // -------------------------------------------------------------------------
  // OYNATICI
  // -------------------------------------------------------------------------

  Future<void> _videoyuKur(String? url) async {
    // HAZIRLIK SÜRERKEN OYNATICI KURULMAZ (4 Eyl 2026). Sunucu dosyayı
    // dönüştürüyor ve çıktıyı YENİ BİR ADA yazıyor; şu anki adrese oynatıcı
    // kurmak (a) boşuna, (b) `initialize()` yarıda kalan dosyada ASILI
    // kalabiliyor ve o sırada `_ilkYukle` yoklamayı hiç başlatamıyor — yani
    // ilerleme çubuğu %0'da donuyordu. Hazırlık bitince sürüm artıyor ve
    // oynatıcı yeni adresle normal yoldan kuruluyor.
    if (_oda?.hazirlik.suruyor == true) return;
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
    // Video artık var: sönme kuralı bu andan itibaren geçerli.
    _kontrolleriGoster();
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

  /// 10 saniyelik konum tazeleme — **YALNIZ SAHİPTE**, yetkilide DEĞİL.
  ///
  /// Yetkili oynatmayı yönetebiliyor (kullanıcı kararı, 4 Eyl) ama kalp atışı
  /// o yetkinin İÇİNDE DEĞİL: birden fazla kişi 10 sn'de bir `konum_zaman`
  /// damgasını tazelerse birbirlerinin damgasını ezerler ve izleyicilerde
  /// küçük zıplamalar olur. Yetkili yalnız KASITLI eylemde (oynat/duraklat/
  /// sar) yazar; sürekli tazeleme tek elde kalır.
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
    // Duraklatınca sayaç durur (kontroller kalır), oynatınca yeniden kurulur.
    _kontrolleriGoster();
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

  /// İYİMSER GÖNDERİM — `sohbet.dart`taki `_yerelEkle` kalıbının tipli eşi.
  ///
  /// ===========================================================================
  /// NEDEN İYİMSER (3 Eyl 2026, canlıda "mesajlarım gitmiyor")
  /// ===========================================================================
  /// Eskiden kutu ANINDA temizleniyor ama listeye hiçbir şey eklenmiyordu:
  /// mesaj ancak bir sonraki yoklama turunda görünürdü. Ağ yavaşsa ya da POST
  /// başarısız olursa kullanıcı yazdığının KAYBOLDUĞUNU görüyordu — kutu boş,
  /// listede yok, hiçbir uyarı yok. Klasik SESSİZ BAŞARISIZLIK; proje kuralı
  /// her eylemin ÜÇ HÂLİNİ ister: yükleniyor / başarı / hata.
  ///
  /// ÇİFT SATIR RİSKİ nasıl kapandı: iyimser satır YEREL (negatif) bir id ile
  /// eklenir; sunucu onaylayınca aynı satırın id'si gerçek id ile değiştirilir
  /// ve o id [_cizilenIdler]'e girer. Yoklama aynı satırı getirdiğinde orada
  /// elenir. Yani satır ASLA ikinci kez eklenmez.
  Future<void> _mesajGonder() async {
    final metin = _metin.text.trim();
    if (metin.isEmpty) return;
    _metin.clear();
    final konum = _oynatici?.value.position.inMilliseconds;
    await _metniGonder(metin, konum);
  }

  Future<void> _metniGonder(String metin, int? konumMs) async {
    final anahtar =
        'y${DateTime.now().microsecondsSinceEpoch}-${_yerelSayac++}';
    final benim = _benimId;
    final bendeki = _oda?.uyeler.where((u) => u.id == benim).firstOrNull;
    setState(() {
      _mesajlar.add(
        OdaMesaj(
          // NEGATİF id: sunucunun sırasıyla çakışmaz ve `_sonMesajId`
          // imlecini asla kirletmez.
          id: -(_yerelSayac),
          tarih: DateTime.now().millisecondsSinceEpoch,
          sistem: false,
          kullaniciId: benim,
          ad: bendeki?.ad,
          avatar: bendeki?.avatar,
          metin: metin,
          konumMs: konumMs,
          yerel: anahtar,
          bekliyor: true,
        ),
      );
    });
    _yerelTekrar[anahtar] = () => _yenidenGonder(anahtar, metin, konumMs);
    _sonaKaydir();
    try {
      final y = await OdaApi.mesaj(
        widget.odaId,
        metin: metin,
        konumMs: konumMs,
      );
      if (!mounted) return;
      final gercekId = (y['id'] as num?)?.toInt();
      setState(() {
        if (gercekId != null) _cizilenIdler.add(gercekId);
        _yerelDegistir(
          anahtar,
          (m) => m.kopya(id: gercekId ?? m.id, bekliyor: false),
        );
      });
      _yerelTekrar.remove(anahtar);
    } on ApiHata catch (e) {
      if (!mounted) return;
      // Satır KALIR ve "tekrar dene" der — yazdığı metin kaybolmasın.
      setState(
        () => _yerelDegistir(
          anahtar,
          (m) => m.kopya(bekliyor: false, hataliMi: true),
        ),
      );
      _uyar(odaHataMetni(e));
    }
  }

  Future<void> _yenidenGonder(
    String anahtar,
    String metin,
    int? konumMs,
  ) async {
    setState(
      () => _yerelDegistir(
        anahtar,
        (m) => m.kopya(bekliyor: true, hataliMi: false),
      ),
    );
    try {
      final y = await OdaApi.mesaj(
        widget.odaId,
        metin: metin,
        konumMs: konumMs,
      );
      if (!mounted) return;
      final gercekId = (y['id'] as num?)?.toInt();
      setState(() {
        if (gercekId != null) _cizilenIdler.add(gercekId);
        _yerelDegistir(
          anahtar,
          (m) => m.kopya(id: gercekId ?? m.id, bekliyor: false),
        );
      });
      _yerelTekrar.remove(anahtar);
    } on ApiHata catch (e) {
      if (!mounted) return;
      setState(
        () => _yerelDegistir(
          anahtar,
          (m) => m.kopya(bekliyor: false, hataliMi: true),
        ),
      );
      _uyar(odaHataMetni(e));
    }
  }

  /// Yerel anahtarlı satırı YERİNDE değiştirir (setState çağıranın işi).
  void _yerelDegistir(String anahtar, OdaMesaj Function(OdaMesaj) yama) {
    for (var i = 0; i < _mesajlar.length; i++) {
      if (_mesajlar[i].yerel == anahtar) {
        _mesajlar[i] = yama(_mesajlar[i]);
        return;
      }
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
    // Elle ad yazma KALKTI: davet yalnız listeden seçmeyle gider, böylece
    // "Kullanıcı bulunamadı" (404) ve "karşılıklı takip yok" (403) hataları
    // kullanıcının hiç görmeyeceği şeyler olur.
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: DiziRenkler.koyuGri,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => OdaDavetSecici(odaId: widget.odaId),
    );
    if (mounted) _tamYenile();
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
    // PopScope aşağıdaki `context.pop()`u da yakalar; `_cikiliyor` onu serbest
    // bırakır (bkz. alanın başındaki not).
    setState(() => _cikiliyor = true);
    try {
      if (sahip) {
        await OdaApi.kapat(widget.odaId);
      } else {
        await OdaApi.ayril(widget.odaId);
      }
      if (mounted) context.pop();
    } on ApiHata catch (e) {
      if (mounted) setState(() => _cikiliyor = false);
      _uyar(odaHataMetni(e));
    }
  }

  // -------------------------------------------------------------------------
  // ÇİZİM
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final oda = _oda;
    if (_hata != null && (oda == null || _kalici)) {
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
    final olcu = MediaQuery.of(context).size;
    final genis = olcu.width >= _genisEsik;
    // ***YERLEŞİM KARARI YÖNE BAKAR, TAM EKRAN BAYRAĞINA DEĞİL.***
    //
    // 4 Eyl 2026, kullanıcı canlıda: *"dikey moddayken ekranı büyüt diyince
    // yatay moda geçmiyor sağdaki sohbet kocaman oluyor solu komple
    // baskılıyor"*. Ölçüldü: 360 dp genişlikte yan panel 320 dp alıyor,
    // videoya 40 dp kalıyordu. Kök sebep yön çevirmenin yazılmamış olmasıydı
    // (artık yazıldı) ama YALNIZ onu düzeltmek yetmez: yön dayatması cihazda
    // reddedilebilir (kullanıcı otomatik döndürmeyi kapatmış olabilir, tablet
    // olabilir). O yüzden dikeyde yan/bindirme düzeni ASLA devreye girmez —
    // dikeyde sohbet HER ZAMAN videonun altındadır.
    final yatay = olcu.width > olcu.height;
    return PopScope(
      canPop: _cikiliyor || !_tamEkran,
      // GERİ TUŞU tam ekranda ÖNCE tam ekrandan çıkar, odayı kapatmaz: tam
      // ekran bir ADIMDIR ve geri hareketi bir adım geri almalıdır (aynı
      // gerekçe `paylas_yorum.dart` önizleme adımında yazılı). Çıkış
      // `_tamEkraniAyarla` üzerinden gider, yani yön de dikeye döner.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _tamEkraniAyarla(false);
      },
      child: _tamEkran
          ? _tamEkranIskelet(oda, yatay: yatay)
          : _normalIskelet(oda, genis: genis && yatay),
    );
  }

  /// TAM EKRAN: AppBar yok, zemin siyah.
  ///
  /// YATAYDA sohbet videonun ÜSTÜNE, sağa BİNDİRİLİR — katı panel değil.
  /// Kullanıcı isteği birebir (4 Eyl): *"mesajlar videonun sağında emojiler
  /// gibi gözükmeli"*. Katı panel videodan yer çalıyordu; bindirme videoyu tam
  /// genişlikte bırakır ve sohbet yine sağda kalır.
  ///
  /// DİKEYDE (yön dayatması cihazca reddedildiyse) sohbet videonun ALTINDA
  /// kalır — 360 dp'lik bir ekranda yan yana koymak videoyu 40 dp'ye indirirdi.
  Widget _tamEkranIskelet(Oda oda, {required bool yatay}) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: yatay
            ? _tamEkranVideo(oda)
            : LayoutBuilder(
                builder: (context, k) => Column(
                  children: [
                    _videoBolumu(
                      oda,
                      videoTavan: _videoTavani(k.maxHeight),
                      sohbetDugmesi: false,
                    ),
                    Expanded(child: _sohbet(oda)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _normalIskelet(Oda oda, {required bool genis}) {
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
                        // Sohbet düğmesi YALNIZ panel düzeninde anlamlı: dar
                        // ekranda sohbet videonun ALTINDA, gizlenince yerine
                        // koca bir boşluk kalırdı.
                        sohbetDugmesi: true,
                      ),
                    ),
                  ),
                  _sohbetPaneli(oda),
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
    final kontrolPayi = _yonetebilirMiyim ? 150.0 : 110.0;
    if (sohbetAyri) return math.max(120.0, yukseklik - kontrolPayi);
    // Sohbete en az bu kadar: üye şeridi + yazı alanı + birkaç satır balon.
    const sohbetAsgari = 170.0;
    final kalan = yukseklik - kontrolPayi - sohbetAsgari;
    return kalan.clamp(120.0, yukseklik * 0.62);
  }

  /// SOHBET PANELİ — kapalıyken ağaçta HİÇ YOK.
  ///
  /// `AnimatedContainer(width: 0)` da düşünülebilirdi ama o, panel kapalıyken
  /// bile sohbeti kurar: 1 sn'lik yoklamayla dolan bir liste, ölçülemeyecek bir
  /// genişlikte çizilmeye çalışır ve taşma uyarıları üretir. [AnimatedSize] ile
  /// çocuk YOK olur, genişlik yine de yumuşak kayar.
  Widget _sohbetPaneli(Oda oda) {
    return AnimatedSize(
      duration: _panelSuresi,
      curve: Curves.easeOut,
      alignment: Alignment.centerLeft,
      child: _sohbetAcik
          ? SizedBox(width: _sohbetPaneliGenislik, child: _sohbet(oda))
          : const SizedBox.shrink(),
    );
  }

  /// SOHBET BİNDİRMESİ — yatay/tam ekranda mesajlar videonun ÜSTÜNDE, sağda.
  ///
  /// ===========================================================================
  /// NEDEN PANEL DEĞİL BİNDİRME (4 Eyl 2026, kullanıcı isteği)
  /// ===========================================================================
  /// *"mesajlar videonun sağında emojiler gibi gözükmeli"*. Eskiden sohbet
  /// `Row` içinde 320 dp'lik KATI bir panel idi ve videodan o kadar yer
  /// çalıyordu. Bindirme, videoyu tam genişlikte bırakır; sohbet yine sağda
  /// durur ama videonun üstünde yüzer — canlı yayın kalıbı.
  ///
  /// ===========================================================================
  /// OKUNABİLİRLİK: HER SATIRIN KENDİ ZEMİNİ VAR
  /// ===========================================================================
  /// Video karesi bir anda bembeyaz olabilir; düz beyaz metin o karede
  /// TAMAMEN kaybolur. Bu yüzden her balonun altında yarı saydam siyah bir
  /// zemin var (ui-ux-pro-max, Color Contrast: en az 4.5:1 — siyah zemin
  /// üstünde beyaz metin sahneden BAĞIMSIZ olarak bu oranı aşar). Yalnız
  /// gölge/kontur denenseydi açık zeminlerde yine sınırda kalırdı.
  ///
  /// ===========================================================================
  /// DOKUNMAYI YUTMAZ
  /// ===========================================================================
  /// Mesaj listesi [IgnorePointer] içinde: videoya dokunup kontrolleri geri
  /// getirmek, bindirmenin altında kalan yerlerde de çalışmalı. Yazı alanı ve
  /// üye satırı ise gerçek dokunma alanı — onlar hariç tutuldu.
  Widget _sohbetBindirmesi(Oda oda) {
    final en = MediaQuery.of(context).size.width;
    final genislik = math.min(_bindirmeAzamiGenislik, en * 0.38);
    // Yalnız SON birkaç satır: bindirme ekranı kaplamamalı. Sistem satırları
    // da dahil, çünkü "X odaya katıldı" izlerken görülmesi gereken bir olay.
    final son = _mesajlar.length <= _bindirmeAzamiSatir
        ? _mesajlar
        : _mesajlar.sublist(_mesajlar.length - _bindirmeAzamiSatir);
    return Positioned(
      top: 44, // üst köşedeki düğmelerin altından başla
      right: 0,
      bottom: 0,
      width: genislik,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Üye avatarları bindirmede de görünür: kiminle izlediğini bilmek
          // tam ekranda da gerekli. Bindirmede KÜÇÜK boy — videonun üstünde
          // yer kaplamamalı.
          _uyeSatiri(oda, dar: true, bindirme: true),
          Expanded(
            child: IgnorePointer(
              // TERS LİSTE (`reverse: true`): satırlar ALTTAN yukarı dizilir,
              // yani en yeni mesaj hep en altta ve görünür kalır; sığmayanlar
              // ÜSTTEN kırpılır. Düz bir `Column` kullanılamaz — 780×360'ta
              // yedi satır + üye satırı + yazı alanı 140 dp TAŞIYORDU (bu
              // dosyadaki taşma testi yakaladı). Liste ayrıca kaydırmıyor
              // (`NeverScrollable`): bindirme salt görsel, sohbetin kendisi
              // dikeydeki panelde.
              child: ListView(
                reverse: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  for (var i = son.length - 1; i >= 0; i--)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
                      child: Opacity(
                        // ESKİ SATIRLAR SOLUK: en yeni altta ve en okunur.
                        // Hepsi aynı parlaklıkta olsaydı göz en yeniyi
                        // bulamazdı (uçuşan tepkilerdeki solma mantığı).
                        opacity: _bindirmeSaydamlik(i, son.length),
                        child: _BindirmeSatiri(
                          mesaj: son[i],
                          benim: son[i].kullaniciId == _benimId,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // YAZMA YOLU KAYBOLMAZ: bindirme salt okunur olsaydı tam ekranda
          // sohbete katılmak imkânsızlaşırdı. Bu satır dokunulabilir.
          _sonebilir(_yaziAlani(saydam: true)),
        ],
      ),
    );
  }

  /// Bindirmedeki satırın saydamlığı: en yeni tam görünür, eskiler solar.
  ///
  /// Son üç satır tam opak — göz oraya bakıyor. Daha eskiler kademeli soluyor
  /// ama 0,35'in altına inmiyor: tamamen kaybolan bir satır "mesajım gitmedi"
  /// sanılır.
  double _bindirmeSaydamlik(int sira, int toplam) {
    final gerideKalan = toplam - 1 - sira;
    if (gerideKalan <= 2) return 1;
    return (1 - (gerideKalan - 2) * 0.18).clamp(0.35, 1.0);
  }

  /// Tam ekrandaki video yüzeyi: video ortada, kontroller ve tepkiler ÜSTÜNE
  /// bindirilmiş. Bindirme şart — tam ekranda altta ayrı bir şerit olsaydı
  /// "tam ekran" olmazdı.
  Widget _tamEkranVideo(Oda oda) {
    final d = _oynatici;
    return Stack(
      children: [
        Positioned.fill(
          // Testler videonun GERÇEK genişliğini bu anahtarla ölçüyor: 4 Eyl'de
          // dikeyde tam ekrana geçince video 40 dp'ye düşmüştü ve hiçbir
          // dolaylı iddia bunu yakalamıyordu.
          key: odaVideoYuzeyiAnahtari,
          child: _dokunmaKatmani(
            cocuk: ColoredBox(
              color: Colors.black,
              child: Center(
                child: AspectRatio(
                  aspectRatio: d != null && _oynaticiHazir
                      ? d.value.aspectRatio
                      : 16 / 9,
                  child: d != null && _oynaticiHazir
                      ? VideoPlayer(d)
                      : _videoYerine(oda),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Stack(children: [for (final t in _ucusan) _ucusanCiz(t)]),
          ),
        ),
        // SOHBET BİNDİRMESİ — videonun sağında, tıpkı uçuşan tepkiler gibi.
        if (_sohbetAcik) _sohbetBindirmesi(oda),
        // Üst düğmeler de kontrollerle BİRLİKTE söner: "sadece video gözüksün"
        // isteği köşede duran iki ikonu da kapsıyor. Geri gelmeleri için
        // ekrana dokunmak yetiyor.
        Positioned(
          top: 6,
          right: 6,
          child: _sonebilir(_ustDugmeler(sohbetDugmesi: true)),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _sonebilir(
            DecoratedBox(
              // Kontroller parlak bir karenin üstüne düşerse okunmaz; alttan
              // yukarı koyulaşan ince bir perde onları her sahnede ayırır.
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    Colors.black.withValues(alpha: 0),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ..._uyumsuzSerit(oda),
                  if (_yuklemeDurumu != null) _yuklemeCubugu(_yuklemeDurumu!),
                  if (d != null && _oynaticiHazir) _kontroller(oda, d),
                  _tepkiSeridi(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Sönebilen katman: kontroller + tepki şeridi.
  ///
  /// `AnimatedOpacity` + `IgnorePointer` ikilisi bilinçli. Widget'ı ağaçtan
  /// KALDIRMAK yerine saydamlaştırıyoruz çünkü kaldırmak video kutusunun
  /// yüksekliğini değiştirir ve her sönmede sahne ZIPLAR. Saydamken dokunma
  /// da yutulmamalı: `IgnorePointer` olmasaydı görünmeyen bir "10 sn ileri"
  /// düğmesi kullanıcının parmağını yakalardı.
  Widget _sonebilir(Widget cocuk) => IgnorePointer(
    ignoring: !_kontrolGorunur,
    child: AnimatedOpacity(
      opacity: _kontrolGorunur ? 1 : 0,
      duration: kontrolSonmeGecisi,
      child: cocuk,
    ),
  );

  /// Videonun üstündeki dokunma yakalayıcı.
  ///
  /// SÖNMÜŞKEN DOKUNMA YALNIZ KONTROLLERİ GERİ GETİRİR — oynatmayı
  /// başlatmaz/durdurmaz. İzleyicide zaten kontrol yok; sahipte ise "videoyu
  /// büyütmek için dokundum, film durdu" en can sıkıcı kaza olurdu.
  Widget _dokunmaKatmani({required Widget cocuk}) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: _kontrolleriGoster,
    child: cocuk,
  );

  /// Video köşesindeki ikon-only düğmeler: sohbeti gizle/göster + tam ekran.
  ///
  /// İkisi de `tooltip` + `Semantics` taşır: ekran okuyucu kullanan biri de
  /// düğmenin ne yaptığını bilmeli (aynı kural `MesajIstekleriDugmesi`nde).
  Widget _ustDugmeler({required bool sohbetDugmesi}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (sohbetDugmesi)
          _VideoDugmesi(
            ikon: _sohbetAcik ? Icons.chat_bubble : Icons.chat_bubble_outline,
            etiket: _sohbetAcik ? 'Sohbeti gizle'.c : 'Sohbeti göster'.c,
            onTap: _sohbetiAcKapa,
          ),
        const SizedBox(width: 4),
        _VideoDugmesi(
          ikon: _tamEkran ? Icons.fullscreen_exit : Icons.fullscreen,
          etiket: _tamEkran ? 'Tam ekrandan çık'.c : 'Tam ekran'.c,
          onTap: () => _tamEkraniAyarla(!_tamEkran),
        ),
      ],
    );
  }

  Widget _videoBolumu(
    Oda oda, {
    required double videoTavan,
    bool sohbetDugmesi = false,
  }) {
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
            _dokunmaKatmani(
              cocuk: Container(
                key: odaVideoYuzeyiAnahtari,
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
            // Tam ekran düğmesi HER İKİ ROLDE de var: izleyicinin oynatma
            // kontrolü yok ama videoyu büyütme hakkı var.
            Positioned(
              right: 6,
              bottom: 6,
              child: _sonebilir(_ustDugmeler(sohbetDugmesi: sohbetDugmesi)),
            ),
          ],
        ),
        // Yükleme çubuğu SÖNMEZ: 5 GB yüklerken ilerlemeyi görmek gerekiyor
        // (`_sonebilirMi` de bu hâlde sayacı hiç kurmuyor; burada ayrıca
        // sarmalamıyoruz ki tam ekranda da aynı kural okunsun).
        ..._uyumsuzSerit(oda),
        if (_yuklemeDurumu != null) _yuklemeCubugu(_yuklemeDurumu!),
        if (d != null && _oynaticiHazir) _sonebilir(_kontroller(oda, d)),
        _sonebilir(_tepkiSeridi()),
      ],
    );
  }

  Widget _videoYerine(Oda oda) {
    if (_yuklemeDurumu != null) {
      return const Center(child: CircularProgressIndicator());
    }
    // HAZIRLIK (MKV desteği): dosya sunucuda kabı/sesi düzeltilirken video
    // henüz oynatılamaz. Sessiz bir spinner "bozuk" görünürdü — ne olduğunu
    // ve ne kadar kaldığını SÖYLE.
    if (oda.hazirlik.suruyor) return _hazirlikYerine(oda);
    if (oda.hazirlik.hataliMi) return _hazirlikHatasi(oda);
    if (oda.video != null) {
      return const Center(child: CircularProgressIndicator());
    }
    // KAYDIRILABİLİR: bu yer tutucu ikon + metin + düğme ile ~180 dp ister,
    // oysa video kutusunun boyu KALAN YERDEN hesaplanıyor ve yatay telefonda
    // 120 dp'ye kadar inebiliyor. Doğrudan `Center` içinde dursaydı Column
    // TAŞARDI (4 Eyl 2026, tam ekran testi 780×390'da yakaladı). Kaydırma
    // içinde en kötü ihtimalle biraz kaydırılır.
    return SingleChildScrollView(
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
              _yonetebilirMiyim
                  ? 'Bir video yükle, izlemeye başlayın'.c
                  : 'Oda sahibi henüz video yüklemedi'.c,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
            ),
            if (_yonetebilirMiyim) ...[
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

  /// Sunucu videoyu hazırlarken gösterilen ekran.
  ///
  /// KUYRUKTA ile İŞLENİYOR ayrı yazılır: kuyruktaki bir iş için yüzde
  /// göstermek yanlış olurdu (henüz başlamadı), "sırada" demek dürüst.
  Widget _hazirlikYerine(Oda oda) {
    final h = oda.hazirlik;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(
                // Kuyruktayken yüzde YOK: belirsiz gösterge dürüst olan.
                value: h.kuyrukta ? null : (h.yuzde / 100).clamp(0.0, 1.0),
                strokeWidth: 3,
                color: DiziRenkler.sari,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              h.kuyrukta
                  ? 'Sırada bekliyor'.c
                  : 'Hazırlanıyor · %{}'.cf([h.yuzde]),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              // NE YAPILDIĞINI söyle: "hazırlanıyor" tek başına ne kadar
              // süreceği hakkında hiçbir şey demez.
              'Video, her cihazda oynayacak biçime çevriliyor.'.c,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hazırlık başarısız — sebebi söyle, sahibe çıkış yolu ver.
  Widget _hazirlikHatasi(Oda oda) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: DiziRenkler.ilerlemeKirmizi,
            ),
            const SizedBox(height: 10),
            Text(
              odaHazirlikHatasi(oda.hazirlik.hata),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
            ),
            if (_yonetebilirMiyim) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: FilledButton.icon(
                  onPressed: _videoSec,
                  icon: const Icon(Icons.upload_outlined, size: 20),
                  label: Text('Başka video yükle'.c),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Uyarı şeridini LİSTE olarak verir.
  ///
  /// Koşullu eleman (`if (x case final u?)`) burada `use_null_aware_elements`
  /// uyarısı doğuruyor ve bu projede YENİ uyarı bırakmak yasak — aynı gerekçe
  /// `Api.takipToggle` ve `OdaApi.olustur` içinde de yazılı.
  List<Widget> _uyumsuzSerit(Oda oda) {
    final u = _uyumsuzUyarisi(oda);
    return u == null ? const [] : [u];
  }

  /// Bu cihazda oynatılamayan bir kodek varsa açık uyarı + sahibe çıkış yolu.
  ///
  /// H.265 telefonda oynar, tarayıcıda oynamaz; VP9 tersine iOS'ta oynamaz.
  /// Kullanıcıya siyah bir ekran göstermektense SEBEBİ söylemek gerekir.
  Widget? _uyumsuzUyarisi(Oda oda) {
    final u = oda.hazirlik.uyumsuz;
    final webSorunu = kIsWeb && u.contains('web');
    final iosSorunu =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        u.contains('ios');
    if (!webSorunu && !iosSorunu) return null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: DiziRenkler.ilerlemeKirmizi.withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: DiziRenkler.ilerlemeKirmizi,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              webSorunu
                  ? 'Bu videoyu tarayıcı oynatamıyor. Telefondan aç.'.c
                  : 'Bu videoyu iPhone oynatamıyor.'.c,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (webSorunu && _yonetebilirMiyim)
            TextButton(
              onPressed: _tarayiciIcinHazirla,
              child: Text('Tarayıcı için hazırla'.c),
            ),
        ],
      ),
    );
  }

  /// Elle çevrim onayının metni — TEK PARÇA dizgi.
  ///
  /// Bitişik iki dizgi olarak yazılsaydı Dart onları birleştirip doğru anahtarı
  /// arardı ama KAYNAKTA iki parça görünürdü; çeviri toplayıcı betikler o
  /// dosyayı tarayınca yalnız son parçayı anahtar sanar ve 45 dile YANLIŞ
  /// anahtar eklenir.
  static const _cevrimUyarisi =
      'Video tarayıcıda oynayacak biçime çevrilecek. Uzun sürebilir; bu sırada oda izlenemez.';

  /// Sahip elle tetikler: H.265 -> H.264. PAHALI olduğu için otomatik değil,
  /// ve süresi kullanıcıya SÖYLENİR — sessizce 30 dakika beklemesin.
  Future<void> _tarayiciIcinHazirla() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Tarayıcı için hazırla'.c),
        content: Text(_cevrimUyarisi.c),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Vazgeç'.c),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Başlat'.c),
          ),
        ],
      ),
    );
    if (onay != true) return;
    try {
      await OdaApi.videoCevir(widget.odaId);
      await _tamYenile();
    } on ApiHata catch (e) {
      _uyar(odaHataMetni(e));
    }
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
                    child: _yonetebilirMiyim
                        ? Slider(
                            value: sure > 0
                                ? konum.toDouble().clamp(0, sure.toDouble())
                                : 0,
                            max: sure > 0 ? sure.toDouble() : 1,
                            // Sürüklerken sönme sayacı DURUR: parmağın
                            // altındaki çubuğun kaybolması kabul edilemez.
                            onChangeStart: (_) {
                              _cubukSuruklemede = true;
                              _kontrolleriGoster();
                            },
                            onChanged: (v) => _sar(d, v.round()),
                            onChangeEnd: (v) {
                              _cubukSuruklemede = false;
                              _konumaSar(v.round());
                              _sonmeyiKur();
                            },
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
              if (_yonetebilirMiyim)
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
          // ÜYE SATIRI ARTIK HİÇ GİZLENMİYOR — yalnız KÜÇÜLÜYOR.
          //
          // Eskiden `if (k.maxHeight > 200)` idi ve kısa alanlarda düşüyordu.
          // Kullanıcı 4 Eyl'de bildirdi: *"dikey modda odadaki kişiler
          // gözükmüyor ... sohbetin sol yukarısında logoları dizilmeli"*.
          // "Kiminle izliyorum" sorusu bir odanın en temel bilgisi; yer
          // sıkışınca ilk feda edilecek şey o olamaz. Dar alanda avatarlar
          // küçülür (bkz. [_uyeSatiri]), listeden DÜŞMEZ.
          _uyeSatiri(oda, dar: k.maxHeight < 200),
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
                      // ANAHTAR yerel satırda YEREL anahtardır: iyimser satır
                      // onaylanınca id'si değişiyor ve id anahtarı kullansaydık
                      // Flutter satırı YENİ sanıp durumunu atardı.
                      key: ValueKey(
                        _mesajlar[i].yerel ?? 's${_mesajlar[i].id}',
                      ),
                      mesaj: _mesajlar[i],
                      benim: _mesajlar[i].kullaniciId == _benimId,
                      onTekrar: _mesajlar[i].hataliMi
                          ? () => _yerelTekrar[_mesajlar[i].yerel]?.call()
                          : null,
                    ),
                  ),
          ),
          _yaziAlani(),
        ],
      ),
    );
  }

  /// ODADAKİ KİŞİLER — sohbetin SOL ÜSTÜNDE, avatarlar yan yana.
  ///
  /// Kullanıcı isteği (4 Eyl 2026, birebir): *"dikey modda sol yukarıda odadaki
  /// kişiler gözükmeli logoları dizilmeli sohbetin sol yukarısında"*.
  ///
  /// [dar] — alan sıkışık (yatay telefon): avatarlar küçülür ama GİZLENMEZ.
  /// [bindirme] — tam ekranda videonun üstünde çiziliyor; okunabilirlik için
  /// yarı saydam koyu bir zemin gerekir (video karesi beyaz olabilir).
  Widget _uyeSatiri(Oda oda, {bool dar = false, bool bindirme = false}) {
    final yaricap = dar ? 12.0 : 18.0;
    final yukseklik = dar ? 34.0 : 56.0;
    final satir = SizedBox(
      height: yukseklik,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: bindirme ? 6 : 10),
        itemCount: oda.uyeler.length,
        itemBuilder: (context, i) {
          final u = oda.uyeler[i];
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: dar ? 2 : 4,
              vertical: dar ? 3 : 6,
            ),
            child: Tooltip(
              message: [
                '@${u.ad}',
                if (u.sahip) 'oda sahibi'.c else if (u.yetkili) 'Yetkili'.c,
                if (u.bekliyor)
                  'davet bekliyor'.c
                else if (u.cevrimici)
                  'çevrimiçi'.c
                else
                  'çevrimdışı'.c,
              ].join(' · '),
              child: InkWell(
                // Rol menüsü YALNIZ sahipte ve KENDİSİ DIŞINDAKİ üyelerde
                // açılır. `onTap: null` verildiğinde InkWell dalgayı da
                // çizmez, yani izleyici "dokunulabilir ama bir şey olmuyor"
                // hissi yaşamaz.
                onTap: (_sahipMiyim && u.id != _benimId)
                    ? () => _rolMenusu(u)
                    : null,
                borderRadius: BorderRadius.circular(24),
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
                        yaricap: yaricap,
                      ),
                    ),
                    if (!u.bekliyor && u.cevrimici)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: dar ? 7 : 10,
                          height: dar ? 7 : 10,
                          decoration: BoxDecoration(
                            color: DiziRenkler.cevrimiciYesil,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: DiziRenkler.koyuGri,
                              width: dar ? 1 : 2,
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
                          size: dar ? 9 : 12,
                          color: DiziRenkler.sariMetin,
                        ),
                      )
                    // Yetkili sahipten AYRI bir ikon taşır: ikisi de yıldız
                    // olsaydı odada kimin sahip olduğu görünmezdi.
                    else if (u.yetkili)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Icon(
                          Icons.shield_outlined,
                          size: dar ? 9 : 12,
                          color: DiziRenkler.sariMetin,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (!bindirme) return satir;
    // BİNDİRMEDE ZEMİN ŞART: video karesi beyaz olduğunda avatar kenarları ve
    // rozet ikonları kaybolur (ui-ux-pro-max, Color Contrast).
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12)),
      ),
      child: satir,
    );
  }

  /// Sahibin bir üyeye kontrolü verip aldığı yarım sayfa.
  ///
  /// Yalnız sahipte ve yalnız BAŞKA bir üyede açılır (`_uyeSeridi`teki
  /// `onTap` koşulu). Sahip kendi rolünü değiştiremez — sunucu da bunu
  /// `KENDI_ROLUN` ile reddeder, ama menüyü hiç açmamak daha iyi: kullanıcı
  /// yapamayacağı bir seçeneği görmemeli.
  Future<void> _rolMenusu(OdaUye u) async {
    final ver = !u.yetkili;
    final onay = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: DiziRenkler.koyuGri,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  KullaniciAvatari(
                    url: dosyaUrl(u.avatar),
                    kullaniciAdi: u.ad,
                    yaricap: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '@${u.ad}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(
                ver ? Icons.shield_outlined : Icons.shield_moon_outlined,
                color: DiziRenkler.sariMetin,
              ),
              title: Text(ver ? 'Kontrolü ver'.c : 'Kontrolü al'.c),
              subtitle: Text(
                ver
                    ? 'Videoyu oynatıp durdurabilir ve değiştirebilir.'.c
                    : 'Artık videoyu yönetemez.'.c,
                style: TextStyle(fontSize: 12, color: DiziRenkler.metin54),
              ),
              onTap: () => Navigator.pop(c, true),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (onay != true || !mounted) return;
    try {
      final uyeler = await OdaApi.rolVer(
        widget.odaId,
        kullanici: u.ad,
        yetkili: ver,
      );
      // Sunucu güncel listeyi döndürüyor: rozet BİR TUR beklemeden değişsin.
      if (mounted) setState(() => _oda = _oda?.kopya(uyeler: uyeler));
    } on ApiHata catch (e) {
      _uyar(odaHataMetni(e));
    }
  }

  /// [saydam] — tam ekran bindirmesinde çiziliyor: kutunun kendi koyu zemini
  /// olur, yoksa video karesinin üstünde ne çerçeve ne ipucu metni okunur.
  Widget _yaziAlani({bool saydam = false}) {
    return Padding(
      padding: EdgeInsets.only(
        left: saydam ? 6 : 10,
        right: saydam ? 6 : 10,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _metin,
              focusNode: _metinOdak,
              minLines: 1,
              maxLines: saydam ? 2 : 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _mesajGonder(),
              style: saydam ? const TextStyle(color: Colors.white) : null,
              decoration: InputDecoration(
                hintText: 'Mesaj yaz...'.c,
                isDense: true,
                filled: saydam,
                fillColor: saydam ? Colors.black.withValues(alpha: 0.55) : null,
                hintStyle: saydam
                    ? TextStyle(color: Colors.white.withValues(alpha: 0.7))
                    : null,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: saydam ? 8 : 12,
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

/// Video üstündeki yuvarlak, ikon-only düğme (tam ekran / sohbeti gizle).
///
/// Zemin YARI SAYDAM SİYAH: düğme hem parlak hem karanlık sahnelerde görünür
/// kalmalı. Dokunma hedefi 44 dp (ui-ux-pro-max, Touch Target Size) — ikon 20
/// dp ama kutu büyük.
class _VideoDugmesi extends StatelessWidget {
  final IconData ikon;
  final String etiket;
  final VoidCallback onTap;
  const _VideoDugmesi({
    required this.ikon,
    required this.etiket,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: etiket,
      child: Semantics(
        button: true,
        label: etiket,
        child: Material(
          color: Colors.black.withValues(alpha: 0.45),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(ikon, size: 20, color: Colors.white),
            ),
          ),
        ),
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

/// Tam ekran bindirmesindeki tek mesaj — videonun ÜSTÜNDE okunmalı.
///
/// [_MesajSatiri]'nın kopyası DEĞİL, kasten ayrı: oradaki satır bir panelin
/// içinde, bilinen bir zemin üstünde yaşıyor ve avatar + zaman damgası +
/// "tekrar dene" gibi ayrıntılar taşıyor. Burada zemin BİLİNMEZ (her kare
/// farklı) ve yer dar; ayrıntı değil OKUNABİLİRLİK önceliklidir.
///
/// Zemin yarı saydam siyah: beyaz metin sahneden bağımsız olarak 4.5:1
/// kontrast oranını aşar (ui-ux-pro-max, Color Contrast). Yalnız metin gölgesi
/// denenseydi bembeyaz bir karede yine sınırda kalırdı.
class _BindirmeSatiri extends StatelessWidget {
  final OdaMesaj mesaj;
  final bool benim;
  const _BindirmeSatiri({required this.mesaj, required this.benim});

  @override
  Widget build(BuildContext context) {
    final sistem = mesaj.sistem;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: sistem ? 0.4 : 0.58),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: sistem
            ? Text(
                mesaj.sistemMetni(),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.8),
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${mesaj.ad ?? ''}: ',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        // Kendi adın marka sarısı: yoğun bir sohbette kendi
                        // satırını bir bakışta bulmak.
                        color: benim
                            ? DiziRenkler.acikSari
                            : Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                    TextSpan(
                      text: mesaj.metin ?? '',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                style: const TextStyle(fontSize: 12, height: 1.3),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
      ),
    );
  }
}

class _MesajSatiri extends StatelessWidget {
  final OdaMesaj mesaj;
  final bool benim;

  /// Gönderilemeyen satırın "tekrar dene" eylemi.
  final VoidCallback? onTekrar;
  const _MesajSatiri({
    super.key,
    required this.mesaj,
    required this.benim,
    this.onTekrar,
  });

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
                Opacity(
                  // Onay bekleyen satır SOLUK: gönderildiği değil, yolda
                  // olduğu okunsun.
                  opacity: mesaj.bekliyor ? 0.55 : 1,
                  child: Text(
                    mesaj.metin ?? '',
                    style: const TextStyle(fontSize: 14, height: 1.35),
                  ),
                ),
                // ÜÇ HÂLİN görünür kısmı: bekliyor (saat) ve hata (tekrar
                // dene). Başarıda hiçbir şey çizilmez — satırın kendisi zaten
                // onaydır.
                if (mesaj.bekliyor)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.schedule,
                      size: 12,
                      color: DiziRenkler.metin38,
                    ),
                  ),
                if (mesaj.hataliMi)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: InkWell(
                      onTap: onTekrar,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 12,
                            color: DiziRenkler.ilerlemeKirmizi,
                          ),
                          const SizedBox(width: 4),
                          // ESNEK: sohbet paneli 320 dp ve metin uzun dillerde
                          // (Almanca, Fince) satıra sığmıyor — Row TAŞARDI.
                          Flexible(
                            child: Text(
                              'Gönderilemedi · tekrar dene'.c,
                              style: TextStyle(
                                fontSize: 11,
                                color: DiziRenkler.ilerlemeKirmizi,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Davet seçicisi — oda sahibinin kişi seçerek davet ettiği ekran.
///
/// ===========================================================================
/// NEDEN ELLE AD YAZMA KALKTI
/// ===========================================================================
/// Önceki hâl boş bir metin kutusuydu. Kullanıcı adı yanlış yazınca 404
/// (`KULLANICI_YOK`), karşılıklı takip yoksa 403 (`TAKIP_YOK`) alınıyordu.
/// İkisi de kullanıcının ekranda GÖRMEMESİ gereken hatalar: seçilecek bir
/// satır yoksa gönderilecek bir davet de olmamalı. Artık davet YALNIZ listeden
/// seçmeyle gidiyor — var olmayan birine davet göndermek YAPISAL OLARAK
/// imkânsız.
///
/// ===========================================================================
/// ARAMA İKİ KATMANLI
/// ===========================================================================
///   1. YEREL SÜZME — elde duran karşılıklı takip listesi anında süzülür.
///      Ağ turu yok; her tuşta anında tepki.
///   2. SUNUCU ARAMASI — yerelde eşleşme yoksa `/kullanici-ara` (MEVCUT uç)
///      sorulur. 300 ms geciktirilir ve uçuşan eski yanıt YOK SAYILIR
///      (`_aramaTur` sayacı): her harfte istek atmak hız limitini yer ve
///      yanıtlar sırasız dönerse kullanıcı bir önceki harfin sonucunu görür.
///
/// Sunucudan gelen ama KARŞILIKLI TAKİPLEŞİLMEYEN kişi listeden DÜŞÜRÜLMEZ:
/// tıklanamaz olur ve sebebi yazılır. Düşürseydik kullanıcı arkadaşını arar,
/// bulamaz ve "uygulama bozuk" derdi — sebebi görmek ona ne yapacağını söyler.
class OdaDavetSecici extends StatefulWidget {
  final int odaId;
  const OdaDavetSecici({super.key, required this.odaId});

  @override
  State<OdaDavetSecici> createState() => _OdaDavetSeciciState();
}

class _OdaDavetSeciciState extends State<OdaDavetSecici> {
  final _arama = TextEditingController();
  final _odak = FocusNode();

  List<OdaAday>? _adaylar;
  String _kod = '';
  String? _hata;
  String _sorgu = '';

  /// Sunucu arama sonuçları (yalnız yerelde eşleşme yokken kullanılır).
  List<OdaAday>? _sunucuSonuc;
  bool _araniyor = false;

  /// Uçuşan istek sayacı: geç dönen eski yanıt yok sayılsın.
  int _aramaTur = 0;
  Timer? _gecikme;

  /// Davet isteği süren satırlar — çift dokunuş kilidi.
  final _gonderiliyor = <String>{};

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _gecikme?.cancel();
    _arama.dispose();
    _odak.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    try {
      final s = await OdaApi.davetAdaylari(widget.odaId);
      if (!mounted) return;
      setState(() {
        _adaylar = s.adaylar;
        _kod = s.kod;
        _hata = null;
      });
    } on ApiHata catch (e) {
      if (mounted) setState(() => _hata = odaHataMetni(e));
    }
  }

  void _uyar(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  /// Yerelde eşleşenler (kullanıcı adına göre, büyük/küçük harf duyarsız).
  List<OdaAday> get _yerel {
    final liste = _adaylar ?? const <OdaAday>[];
    if (_sorgu.isEmpty) return liste;
    final q = _sorgu.toLowerCase();
    return liste
        .where((a) => a.kullaniciAdi.toLowerCase().contains(q))
        .toList();
  }

  void _sorguDegisti(String v) {
    final q = v.trim();
    setState(() {
      _sorgu = q;
      // Yerelde eşleşme varsa sunucu sonuçları GÖRÜNMEZ: kullanıcı önce
      // gerçekten davet edebileceği kişileri görsün.
      if (q.isEmpty) _sunucuSonuc = null;
    });
    _gecikme?.cancel();
    if (q.length < 2 || _yerel.isNotEmpty) {
      setState(() {
        _sunucuSonuc = null;
        _araniyor = false;
      });
      return;
    }
    setState(() => _araniyor = true);
    _gecikme = Timer(const Duration(milliseconds: 300), () => _sunucudaAra(q));
  }

  Future<void> _sunucudaAra(String q) async {
    final tur = ++_aramaTur;
    try {
      final ham = await Api.kullaniciAra(q);
      // Geç dönen eski yanıtı YOK SAY.
      if (!mounted || tur != _aramaTur) return;
      final adaylar = _adaylar ?? const <OdaAday>[];
      final sonuc = <OdaAday>[];
      for (final e in ham) {
        final m = e as Map<String, dynamic>;
        if (m['ben_mi'] == true) continue; // kendini davet edemezsin
        final ad = (m['kullanici_adi'] as String?) ?? '';
        if (ad.isEmpty) continue;
        // Aday listesi karşılıklı takipleşilenlerin TAMAMI; burada yoksa
        // karşılıklı takip YOKTUR. Ek uca gerek yok.
        final eslesen = adaylar.where((a) => a.kullaniciAdi == ad).firstOrNull;
        sonuc.add(
          eslesen ??
              OdaAday(
                kullaniciAdi: ad,
                avatar: m['avatar'] as String?,
                durum: 'davet_edilebilir',
                takipYok: true,
              ),
        );
      }
      setState(() {
        _sunucuSonuc = sonuc;
        _araniyor = false;
      });
    } on ApiHata catch (_) {
      if (mounted && tur == _aramaTur) setState(() => _araniyor = false);
    }
  }

  Future<void> _davetEt(OdaAday a) async {
    if (_gonderiliyor.contains(a.kullaniciAdi)) return;
    setState(() => _gonderiliyor.add(a.kullaniciAdi));
    // İYİMSER: satır anında "Davet edildi" olur. Hata gelirse GERİ ALINIR
    // (üç hal kuralı: yükleniyor -> başarı -> hata + geri alma).
    _durumDegistir(a.kullaniciAdi, 'davet_edildi');
    try {
      await OdaApi.davet(widget.odaId, a.kullaniciAdi);
      if (mounted) _uyar('@{} davet edildi'.cf([a.kullaniciAdi]));
    } on ApiHata catch (e) {
      _durumDegistir(a.kullaniciAdi, 'davet_edilebilir');
      if (mounted) _uyar(odaHataMetni(e));
    } finally {
      if (mounted) setState(() => _gonderiliyor.remove(a.kullaniciAdi));
    }
  }

  void _durumDegistir(String ad, String durum) {
    if (!mounted) return;
    setState(() {
      _adaylar = _adaylar
          ?.map((x) => x.kullaniciAdi == ad ? x.kopya(durum: durum) : x)
          .toList();
      _sunucuSonuc = _sunucuSonuc
          ?.map((x) => x.kullaniciAdi == ad ? x.kopya(durum: durum) : x)
          .toList();
    });
  }

  Future<void> _kodKopyala() async {
    if (_kod.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _kod));
    _uyar('Oda kodu kopyalandı'.c);
  }

  @override
  Widget build(BuildContext context) {
    final yerel = _yerel;
    final sunucu = _sunucuSonuc;
    final liste = yerel.isNotEmpty ? yerel : (sunucu ?? const <OdaAday>[]);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.person_add_alt_1_outlined,
                    color: DiziRenkler.sariMetin,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Arkadaşını davet et'.c,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _arama,
                focusNode: _odak,
                autocorrect: false,
                onChanged: _sorguDegisti,
                decoration: InputDecoration(
                  hintText: 'Kişi ara...'.c,
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _araniyor
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(child: _govde(liste)),
            _kodSeridi(),
          ],
        ),
      ),
    );
  }

  Widget _govde(List<OdaAday> liste) {
    if (_hata != null) {
      return BosDurum(ikon: Icons.error_outline, baslik: _hata!);
    }
    if (_adaylar == null) return const IskeletListe(adet: 5);
    if (liste.isEmpty) {
      // ÇIKIŞSIZ BOŞ EKRAN YOK: her iki boş hâlde de oda kodu bir davet
      // yoludur ve altta duruyor (ui-ux-pro-max: Empty States / No Results —
      // "Show helpful message and action").
      return BosDurum(
        ikon: _sorgu.isEmpty ? Icons.group_outlined : Icons.search_off,
        baslik: _sorgu.isEmpty
            ? 'Karşılıklı takipleştiğin kimse yok'.c
            : 'Böyle bir kullanıcı yok'.c,
        ipucu: 'Oda kodunu paylaşarak da davet edebilirsin.'.c,
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: liste.length,
      itemBuilder: (context, i) => _AdaySatiri(
        key: ValueKey(liste[i].kullaniciAdi),
        aday: liste[i],
        mesgul: _gonderiliyor.contains(liste[i].kullaniciAdi),
        onDavet: () => _davetEt(liste[i]),
      ),
    );
  }

  Widget _kodSeridi() {
    if (_kod.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: InkWell(
        onTap: _kodKopyala,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Oda kodu'.c,
                style: TextStyle(fontSize: 12, color: DiziRenkler.metin54),
              ),
              const SizedBox(width: 8),
              Text(
                _kod,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: DiziRenkler.sariMetin,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.copy, size: 14, color: DiziRenkler.metin54),
            ],
          ),
        ),
      ),
    );
  }
}

/// Seçicideki tek satır: avatar + ad + sağda durum/eylem.
class _AdaySatiri extends StatelessWidget {
  final OdaAday aday;
  final bool mesgul;
  final VoidCallback onDavet;
  const _AdaySatiri({
    super.key,
    required this.aday,
    required this.mesgul,
    required this.onDavet,
  });

  @override
  Widget build(BuildContext context) {
    final etiket = aday.takipYok
        ? 'Karşılıklı takipleşmiyorsunuz'.c
        : aday.durum == 'odada'
        ? 'Odada'.c
        : aday.durum == 'davet_edildi'
        ? 'Davet edildi'.c
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            KullaniciAvatari(
              url: dosyaUrl(aday.avatar),
              kullaniciAdi: aday.kullaniciAdi,
              yaricap: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '@${aday.kullaniciAdi}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            if (etiket != null)
              Flexible(
                child: Text(
                  etiket,
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  style: TextStyle(fontSize: 11, color: DiziRenkler.metin38),
                ),
              )
            else
              SizedBox(
                height: 44,
                child: FilledButton(
                  onPressed: mesgul ? null : onDavet,
                  child: mesgul
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Davet et'.c),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
