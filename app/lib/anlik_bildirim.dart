// UYGULAMA İÇİ ANLIK BİLDİRİM PENCERESİ (13 Eyl 2026 isteği)
//
// Kullanıcı birebir: *"uygulamada gezerken gelen bildirimleri yukarıdan görsek
// daha iyi olmaz mı; mesaj geldiğinde veya birisi gönderiyi beğendiğinde
// yukarıda popup ile gözükmeli, aynı Instagram'daki gibi"*.
//
// ===========================================================================
// NEDEN SnackBar (uyari.dart) DEĞİL
// ===========================================================================
// `uyar()` EKRANIN ALTINDA, KENDİ EYLEMİNİN sonucunu bildirir ("listenin
// altına gönderildi") ve ilk dokunuşta kapanır. Buradaki bildirim BAŞKASININ
// eyleminden geliyor, YUKARIDAN iner ve DOKUNULABİLİR bir hedefi vardır
// (mesaj → sohbet, beğeni → gönderi). İki kalıbı tek widget'ta birleştirmek
// "dokununca kapanır" kuralıyla "dokununca gider" kuralını çarpıştırırdı.
//
// ===========================================================================
// KAYNAK İKİ TANEDİR, PENCERE TEKTİR
// ===========================================================================
//  · MOBİL: ön plandaki FCM (`push.dart` → onMessage). Uygulama kullanıcının
//    elindeyken SİSTEM bildirimi basmak yanlıştı — Instagram da ön planda
//    kendi penceresini çizer, bildirim gölgesine düşürmez.
//  · WEB: FCM YOK. `bildirim_canli.dart` `/bildirimler/canli` ucunu yoklar ve
//    aynı kapıdan ([AnlikBildirim.satirGoster]) geçer.
//
// Tekrar bastırma ([AnlikBildirim._gecmis]) iki kaynağın çakıştığı ihtimale
// karşıdır: aynı bildirim 30 saniye içinde ikinci kez pencere açmaz.
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'aile_rozeti.dart';
import 'api.dart';
import 'bildirim_canli.dart';
import 'bildirim_gorunumu.dart';
import 'bildirim_hedefi.dart';
import 'ceviri.dart';
import 'gorsel_basliklari.dart';
import 'sohbet_olay.dart';
import 'tema.dart';
import 'yonlendirme.dart';

/// Pencerenin çizeceği her şey — kaynağı (FCM / yoklama) belli etmez.
@immutable
class AnlikBildirimVeri {
  const AnlikBildirimVeri({
    required this.anahtar,
    required this.metin,
    this.baslik,
    this.avatarUrl,
    this.aktor,
    this.rozetli = false,
    this.ikon = Icons.notifications,
    this.hedef,
  });

  /// Tekrar bastırma kimliği (`tur:id` ya da `tur:ad`).
  final String anahtar;

  /// Kalın üst satır — genelde `@ad`. Yoksa yalnız [metin] çizilir.
  final String? baslik;

  /// Gövde: bildirim cümlesi ya da mesajın kendisi.
  final String metin;

  /// Avatar/poster TAM adresi (null → tür ikonu).
  final String? avatarUrl;

  /// Aktörün kullanıcı adı — avatara dokunmak profiline gider.
  final String? aktor;

  /// Aile rozeti (mini tik) başlığın ardına girer.
  final bool rozetli;

  /// Avatarın köşesindeki tür rozeti (kalp, zarf, yanıt...).
  final IconData ikon;

  /// Pencereye dokununca gidilecek rota; null → pencere yalnız haber verir.
  final String? hedef;
}

/// Ekrandaki tek pencerenin denetimi. Widget değil, KAPI: her kaynak buradan
/// geçer, katman ([AnlikBildirimKatmani]) yalnız dinler.
class AnlikBildirim {
  AnlikBildirim._();

  /// Pencere ekranda ne kadar durur. UX kuralı 3-5 sn (kalıcı pencere yasak);
  /// iki satır metin + avatar için üst sınır seçildi.
  static const Duration sure = Duration(seconds: 5);

  /// Aynı bildirimin iki kaynaktan (FCM + yoklama) ikinci kez pencere açması
  /// için gereken en az süre.
  static const Duration tekrarAraligi = Duration(seconds: 30);

  /// Ekrandaki pencere (yoksa null). Katman bunu dinler.
  static final ValueNotifier<AnlikBildirimVeri?> aktif = ValueNotifier(null);

  static Timer? _sayac;
  static final Map<String, DateTime> _gecmis = {};

  /// Pencereyi açar. SON GELEN KAZANIR: ekranda duran pencere düşer, süre
  /// baştan başlar (`uyar()` ile aynı kural — art arda 5 beğeni 25 saniyelik
  /// okuma ödevi çıkarmaz).
  static void goster(AnlikBildirimVeri veri) {
    // ARAMA EKRANINDA PENCERE YOK: çalan telefonun ya da süren bir
    // görüşmenin üstüne bildirim inmez. `uri.path` DEĞİL üst konum okunur —
    // arama ekranı `push` ile açılır ve `uri` altındaki sayfada kalır
    // (sohbet_olay.dart'taki aynı tuzak).
    final yol = sohbetUstKonum(sonYonlendirici);
    if (yol != null && yenilemeyleAcilmaz(yol)) return;
    final simdi = DateTime.now();
    final onceki = _gecmis[veri.anahtar];
    if (onceki != null && simdi.difference(onceki) < tekrarAraligi) return;
    _gecmis[veri.anahtar] = simdi;
    // Bellek emniyeti: yalnız süresi geçmiş anahtarlar atılır.
    if (_gecmis.length > 50) {
      _gecmis.removeWhere((_, t) => simdi.difference(t) > tekrarAraligi);
    }
    _sayac?.cancel();
    aktif.value = veri;
    _sayac = Timer(sure, kapat);
  }

  static void kapat() {
    _sayac?.cancel();
    _sayac = null;
    aktif.value = null;
  }

  /// Bildirime dokunuldu: hedefe git, pencereyi kapat.
  static void dokunuldu() {
    final hedef = aktif.value?.hedef;
    kapat();
    if (hedef != null) rotayaGit(hedef);
  }

  /// YALNIZ TEST: testler arası sızan pencereyi/geçmişi sıfırlar.
  @visibleForTesting
  static void sifirla() {
    _sayac?.cancel();
    _sayac = null;
    aktif.value = null;
    _gecmis.clear();
  }

  // ------------------------------------------------------------------
  // Kaynak çevirileri
  // ------------------------------------------------------------------

  /// `/bildirimler/canli` satırından pencere (WEB yoklaması).
  static void satirGoster(Map<String, dynamic> satir) {
    final veri = satirdan(satir);
    if (veri != null) goster(veri);
  }

  /// Satır → pencere verisi. `null` = bu satır pencere açmaz.
  @visibleForTesting
  static AnlikBildirimVeri? satirdan(Map<String, dynamic> s) {
    final tur = '${s['tur'] ?? ''}';
    // Gelen ARAMA bir pencere değil, ÇALAN TELEFONDUR: tam ekran gelen arama
    // rotası açılır (bkz. push.dart). Pencereyle haber vermek "cevapla"
    // düğmesini 5 saniyeye sıkıştırmak olurdu.
    if (tur.isEmpty || tur == 'arama') return null;
    final aktor = (s['aktor'] as String?)?.trim();
    // Açık konuşmada pencere YOK: mesaj zaten balon olarak iniyor. Sunucu da
    // bakıyor damgasına bakıp satırı hiç yazmıyor; bu, uçuştaki bir satırın
    // geç gelmesine karşı yedek kapı.
    if (tur == 'mesaj' &&
        (SohbetOlaylari.buSohbetAcik(aktor) ||
            sohbetYoluBu(sohbetUstKonum(sonYonlendirici), aktor ?? ''))) {
      return null;
    }
    final (ikon, cumle) = bildirimGorunumu(s);
    // Aktörsüz türlerde ('bolum', 'kisi', 'surum', 'geri_bildirim') avatar
    // yerine YAPIMIN posteri durur; kişi ikonu "biri bir şey yaptı" der ve
    // yanıltırdı (liste ekranıyla aynı kural).
    final poster = posterUrl(s['poster'] as String?, boyut: 'w185');
    final avatar = dosyaUrl(s['aktor_avatar'] as String?);
    return AnlikBildirimVeri(
      anahtar: 'b${s['id'] ?? '$tur:$aktor'}',
      // Mesajda başlık gönderen, gövde MESAJIN KENDİSİDİR (Instagram/WhatsApp
      // kalıbı); metin yoksa (yalnız medya) etiketi yazılır.
      baslik: tur == 'mesaj' && aktor != null ? '@$aktor' : null,
      metin: tur == 'mesaj' ? _mesajOnizleme(s, cumle) : cumle,
      avatarUrl: avatar ?? poster,
      aktor: aktor,
      rozetli: s['aktor_testci'] == true,
      ikon: ikon,
      hedef: _satirHedefi(s, aktor),
    );
  }

  /// Mesaj penceresinin gövdesi: metin > medya etiketi > "sana mesaj gönderdi".
  static String _mesajOnizleme(Map<String, dynamic> s, String yedek) {
    final metin = (s['metin'] as String?)?.trim() ?? '';
    if (metin.isNotEmpty) return metin;
    return switch (s['medya_tur']) {
      'video' => 'Video'.c,
      'foto' => 'Fotoğraf'.c,
      _ => yedek,
    };
  }

  static String? _satirHedefi(Map<String, dynamic> s, String? aktor) {
    // Geri bildirim yanıtı GİDİLECEK BİR SAYFA DEĞİL, okunacak bir metindir:
    // listede modal açılıyor, pencereden de listeye götürülür.
    if (s['tur'] == 'geri_bildirim') return '/bildirimler';
    // Yorum silinmişse gönderi 404 verir → aktörün profili (liste ekranıyla
    // aynı kural, bkz. bildirimler.dart `_hedef`).
    if (s['yorum_id'] != null && s['yorum_tur'] == null) {
      return aktor == null || aktor.isEmpty
          ? '/bildirimler'
          : '/kullanici/$aktor';
    }
    // `bildirimHedefi` FCM SÖZLÜĞÜNÜ okur: aktörün adı orada `ad` anahtarında
    // durur, API satırında ise `aktor`. Çevrilmezse 'mesaj'/'takip' gibi
    // ADA dayanan türlerin hepsi hedefsiz kalır (pencere dokunulunca hiçbir
    // yere gitmezdi — testte tam bu yakalandı).
    return bildirimHedefi({...s, 'ad': aktor ?? ''});
  }

  /// FCM verisinden pencere (MOBİL ön plan). [govde] sunucudan ALICININ
  /// DİLİNDE gelir (PUSH_SABLON); varsa o yazılır, yoksa istemci cümlesi.
  static void fcmGoster(Map<String, dynamic> veri, {String? govde}) {
    final tur = '${veri['tur'] ?? ''}';
    if (tur.isEmpty || tur == 'arama') return;
    final aktor = (veri['ad'] as String?)?.trim();
    final (ikon, cumle) = bildirimGorunumu({...veri, 'aktor': aktor});
    final mesaj = tur == 'mesaj';
    final metin = mesaj ? ((veri['metin'] as String?) ?? '') : (govde ?? '');
    goster(
      AnlikBildirimVeri(
        // FCM satır id'si taşımaz; aynı kişiden gelen ikinci mesaj yeni
        // pencere AÇMALI, bu yüzden anahtara zaman damgası girer.
        anahtar: '$tur:$aktor:${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        baslik: mesaj && aktor != null ? '@$aktor' : null,
        metin: metin.trim().isEmpty ? cumle : metin,
        avatarUrl: dosyaUrl((veri['avatar'] as String?)?.trim()),
        aktor: aktor,
        ikon: ikon,
        hedef: bildirimHedefi(veri),
      ),
    );
  }
}

/// Uygulamanın tamamını saran katman: pencereyi EN ÜSTTE çizer.
///
/// `MaterialApp.builder` içinde, [UyariKatmani]'nın altında kurulur — yani
/// Navigator'ın üstünde: rota değişse de pencere ekranda kalır ve her
/// sayfanın üzerinde görünür.
class AnlikBildirimKatmani extends StatefulWidget {
  const AnlikBildirimKatmani({super.key, required this.cocuk});

  final Widget cocuk;

  @override
  State<AnlikBildirimKatmani> createState() => _AnlikBildirimKatmaniState();
}

class _AnlikBildirimKatmaniState extends State<AnlikBildirimKatmani>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kontrol = AnimationController(
    vsync: this,
    // UX kuralı: mikro etkileşim 150-300 ms; çıkış girişten HIZLI.
    duration: const Duration(milliseconds: 240),
    reverseDuration: const Duration(milliseconds: 170),
  );

  /// Eğri BİR KEZ kurulur: `build` içinde kurulsaydı her karede yeni bir
  /// `CurvedAnimation` doğar ve dispose edilmeyen dinleyici bırakırdı.
  late final Animation<double> _egri = CurvedAnimation(
    parent: _kontrol,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  AnlikBildirimVeri? _veri;

  /// WEB YOKLAMASININ ÖN PLAN KAPISI (bkz. bildirim_canli.dart).
  ///
  /// Arkaya atılan sekmede tarayıcı zamanlayıcıları kısar ama DURDURMAZ:
  /// kimsenin bakmadığı bir sekme dakikalarca sunucuyu yoklar ve döndüğünde
  /// eski bildirimler pencere olarak patlardı. Katman uygulamanın tamamını
  /// sardığı için bu kapının doğal yeri burası.
  AppLifecycleListener? _yasam;

  void _yasamDegisti(AppLifecycleState durum) {
    if (durum == AppLifecycleState.resumed) {
      BildirimCanli.baslat();
    } else {
      BildirimCanli.dur();
    }
  }

  @override
  void initState() {
    super.initState();
    AnlikBildirim.aktif.addListener(_degisti);
    _yasam = AppLifecycleListener(onStateChange: _yasamDegisti);
    _degisti();
  }

  @override
  void dispose() {
    _yasam?.dispose();
    AnlikBildirim.aktif.removeListener(_degisti);
    (_egri as CurvedAnimation).dispose();
    _kontrol.dispose();
    super.dispose();
  }

  void _degisti() {
    final yeni = AnlikBildirim.aktif.value;
    if (!mounted) return;
    if (yeni != null) {
      setState(() => _veri = yeni);
      _kontrol.forward(from: _kontrol.value == 1 ? 0 : _kontrol.value);
      return;
    }
    // Kapanış animasyonu bitene kadar veri DURUR (yoksa pencere anında
    // kaybolur, çıkış animasyonu hiç görünmezdi).
    _kontrol.reverse().whenComplete(() {
      if (mounted && AnlikBildirim.aktif.value == null) {
        setState(() => _veri = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final veri = _veri;
    return Stack(
      children: [
        widget.cocuk,
        if (veri != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _Pencere(veri: veri, egri: _egri),
          ),
      ],
    );
  }
}

class _Pencere extends StatelessWidget {
  const _Pencere({required this.veri, required this.egri});

  final AnlikBildirimVeri veri;
  final Animation<double> egri;

  @override
  Widget build(BuildContext context) {
    // Erişilebilirlik: kullanıcı hareketi kapattıysa pencere kayarak inmez,
    // olduğu yerde belirir (UX kuralı: prefers-reduced-motion'a saygı).
    final hareketsiz = MediaQuery.disableAnimationsOf(context);
    final ust = MediaQuery.paddingOf(context).top;
    Widget kart = Padding(
      padding: EdgeInsets.fromLTRB(8, ust + 8, 8, 0),
      child: Center(
        // Masaüstünde ekranın tamamına yayılan bir şerit yerine okuma
        // genişliğinde kart (akış kolonuyla aynı his).
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: _Kart(veri: veri),
        ),
      ),
    );
    if (hareketsiz) return kart;
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(egri),
      child: FadeTransition(opacity: egri, child: kart),
    );
  }
}

class _Kart extends StatelessWidget {
  const _Kart({required this.veri});

  final AnlikBildirimVeri veri;

  @override
  Widget build(BuildContext context) {
    final baslik = veri.baslik;
    return Dismissible(
      key: ValueKey('anlik-${veri.anahtar}'),
      // YUKARI sürüklenince kapanır (Instagram/iOS kalıbı). Aşağı sürüklemek
      // pencereyi ekranın içine iterdi; yatay sürükleme ise altındaki
      // sayfanın (Reels, galeri) jestleriyle çakışırdı.
      direction: DismissDirection.up,
      onDismissed: (_) => AnlikBildirim.kapat(),
      child: Material(
        color: DiziRenkler.kart,
        elevation: 8,
        shadowColor: Colors.black54,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('anlik-bildirim'),
          onTap: AnlikBildirim.dokunuldu,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                _Avatar(veri: veri),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (baslik != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                baslik,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: DiziRenkler.metin,
                                ),
                              ),
                            ),
                            if (veri.rozetli) ...[
                              const SizedBox(width: 3),
                              const MiniRozet(olcu: 13),
                            ],
                          ],
                        ),
                      Text(
                        veri.metin,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          // RichText DEĞİL: renk açıkça verilir (tema devralma
                          // tuzağı — uyari.dart/md.2).
                          color: baslik == null
                              ? DiziRenkler.metin
                              : DiziRenkler.metin70,
                        ),
                      ),
                    ],
                  ),
                ),
                // Sürüklemeyi bilmeyen kullanıcı için görünür kaçış yolu.
                // 44×44 dokunma hedefi (ikon 18 px, padding büyütür).
                IconButton(
                  key: const Key('anlik-bildirim-kapat'),
                  onPressed: AnlikBildirim.kapat,
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  // TOOLTIP YOK: pencere `MaterialApp.builder` içinde,
                  // Navigator'ın ÜSTÜNDE yaşıyor — üstünde Overlay YOK ve
                  // `Tooltip` Overlay olmadan ASSERT ATIYOR ("No Overlay
                  // widget found"). Erişilebilirlik etiketi ikona verilir.
                  icon: Icon(
                    Icons.close,
                    color: DiziRenkler.metin38,
                    semanticLabel: 'Kapat'.c,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.veri});

  final AnlikBildirimVeri veri;

  @override
  Widget build(BuildContext context) {
    final url = veri.avatarUrl;
    final ad = veri.aktor;
    Widget daire = Stack(
      children: [
        CircleAvatar(
          radius: 21,
          backgroundColor: DiziRenkler.koyuGri,
          backgroundImage: url != null
              ? CachedNetworkImageProvider(url, headers: gorselBasliklari(url))
              : null,
          child: url == null
              ? Icon(veri.ikon, size: 20, color: DiziRenkler.metin38)
              : null,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: CircleAvatar(
            radius: 9,
            backgroundColor: DiziRenkler.sari,
            child: Icon(veri.ikon, size: 11, color: Colors.black),
          ),
        ),
      ],
    );
    if (ad == null || ad.isEmpty) return daire;
    // Avatar PROFİLE gider, kartın kendisi gönderiye/sohbete — bildirim
    // listesindeki kuralın aynısı (13 Eyl 2026).
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        AnlikBildirim.kapat();
        rotayaGit('/kullanici/$ad');
      },
      child: daire,
    );
  }
}
