import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart'
    show HapticFeedback, HardwareKeyboard, KeyDownEvent, LogicalKeyboardKey;
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../ceviri.dart';
import '../dosya_oku.dart';
import '../gorsel_basliklari.dart';
import '../gorusme/arama_dugmeleri.dart';
import '../medya_yukle.dart';
import '../yalniz_emoji.dart';
import '../yerel_gorsel.dart';
import '../push.dart';
import '../sohbet_olay.dart';
import '../sohbet_tema.dart';
import '../tema.dart';
import 'tepki.dart';
import 'medya_goster.dart';
import 'medya_inceleme.dart';
import 'icerik_sec.dart';
import 'gif_sec.dart';
import 'ortak.dart';
import 'ses.dart';

/// Çevrimiçi eşiği (saniye) — sunucudaki `CEVRIMICI_ESIK_SN` ile AYNI OLMALI.
/// Liste satırındaki yeşil noktayı sunucu hesaplar (`cevrimici` alanı); bu
/// sabit yalnız sohbet BAŞLIĞINDAKİ "çevrimiçi / son görülme" satırı içindir.
/// İkisi ayrı eşik kullansaydı aynı kişi listede çevrimiçi, sohbeti açınca
/// "son görülme 2 dk önce" görünebilirdi.
const cevrimiciEsikSn = 180;

/// Açık konuşma yoklaması. 3 sn WhatsApp hissini bozuyordu; 1 sn ucuz
/// `?sonra=` turu (yeni satır yoksa küçük JSON).
const Duration sohbetYoklamaAraligi = Duration(seconds: 1);

/// Sohbet listesi: yazıyor önizlemesi için yeter, konuşma kadar sık değil.
const Duration sohbetListeYoklamaAraligi = Duration(seconds: 3);

/// GET /mesajlar yanıtından karşı tarafın canlı durumunu okur.
///
/// Yeni sunucu `durum` gönderir (`yaziyor` / `kayit`). Eski sürüm yalnız
/// `yaziyor: true` basar — onu yazıyor say.
String? sohbetDurumCoz(Map<String, dynamic> d) {
  final durum = d['durum'];
  if (durum == 'kayit' || durum == 'yaziyor') return durum as String;
  if (d['yaziyor'] == true) return 'yaziyor';
  return null;
}

/// Karşı tarafın canlı durumunun kullanıcıya gösterilecek metni.
String? sohbetDurumYazi(String? durum) {
  if (durum == 'kayit') return 'ses kaydediyor...'.c;
  if (durum == 'yaziyor') return 'yazıyor...'.c;
  return null;
}

/// Yazıyor/kayıt damgası kapatılsın mı?
///
/// Rota bu sohbet değilse evet. Kayıt sürerken Android mikrofon izni
/// `paused` basar; onu "sohbet kapandı" sayınca `acik:false` gider ve
/// karşı taraf "ses kaydediyor" hiç görmez.
bool sohbetDurumKapatilmali({required bool rotaBu, required bool kaydediyor}) {
  if (!rotaBu) return true;
  if (kaydediyor) return false;
  return true;
}

/// Heartbeat bu turda POST atmalı mı? Kayıt `paused` iken de taze tutulur
/// (TTL 10 sn; atlanırsa gösterge söner).
bool sohbetDurumHeartbeatGonder({
  required bool gorunur,
  required String tur,
  required bool kaydediyor,
  required bool metinVar,
}) {
  if (tur == 'kayit') return kaydediyor;
  if (tur == 'yaziyor') return metinVar && gorunur;
  return gorunur;
}

/// Yoklamada setState'i boş yere tetiklememek için satır parmak izi.
bool _sohbetSatirlariAyni(List<dynamic>? a, List<dynamic> b) {
  if (a == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final x = a[i] as Map;
    final y = b[i] as Map;
    if (x['id'] != y['id'] ||
        x['metin'] != y['metin'] ||
        x['okunmamis'] != y['okunmamis'] ||
        x['cevrimici'] != y['cevrimici'] ||
        x['medya'] != y['medya'] ||
        x['durum'] != y['durum'] ||
        x['yaziyor'] != y['yaziyor']) {
      return false;
    }
  }
  return true;
}

/// Avatar boyu ve satır dolgusu — testler bu sabitleri ölçer.
/// Satır yüksekliği = 44 (avatar) + 2*8 (dikey dolgu) = 60 dp (>= 44 dp).
const double _avatarCap = 44;
const double _satirDikeyDolgu = 8;

/// Kaydırarak yanıtla (2 Eyl 2026, Telegram düzeni).
///
/// TARİHÇE: 5 Ağu 2026'da kullanıcı saatin balonun altında YAZMAMASINI, tüm
/// sohbetin sola sürüklenince sağda belirmesini istemişti (WhatsApp jesti,
/// `_ZamanliSatir`). 2 Eyl'de "sohbeti Telegram gibi yap" isteğiyle saat
/// balonun İÇİNE (sağ alt köşe, Telegram yerleşimi) taşındı ve yatay
/// sürükleme Telegram'daki gibi YANITLA oldu. Eski jest kalktı.
///
/// Satır sola sürüklenince yanıt oku belirir; [esik] geçilince titreşim +
/// bırakınca [onYanitla]. Dikey kaydırmayı yutmaz: yalnız yatay eşiği aşan
/// parmakta arenayı kazanır. Kenardan başlayan sürüklemeye karışmaz
/// (Android geri jesti için 24 dp pay).
class _KaydirYanitla extends StatefulWidget {
  final Widget child;
  final bool etkin;
  final VoidCallback onYanitla;

  const _KaydirYanitla({
    super.key,
    required this.child,
    required this.etkin,
    required this.onYanitla,
  });

  static const esik = 64.0;
  static const tavan = 88.0;

  @override
  State<_KaydirYanitla> createState() => _KaydirYanitlaState();
}

class _KaydirYanitlaState extends State<_KaydirYanitla>
    with SingleTickerProviderStateMixin {
  // initState'te KURULUR, alan başlatıcısında DEĞİL: `late final` tembeldir;
  // `etkin: false` satırda (id'siz iyimser satır) build ona hiç dokunmaz,
  // dispose ilk kez kurmaya kalkar → "Looking up a deactivated widget's
  // ancestor is unsafe" (aynı tuzak 7 Ağu 2026'da saat sütununda yaşandı).
  late final AnimationController _c;
  bool _titredi = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 0,
      upperBound: _KaydirYanitla.tavan,
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _guncelle(DragUpdateDetails d) {
    final yeni = (_c.value - d.delta.dx).clamp(0.0, _KaydirYanitla.tavan);
    _c.value = yeni;
    if (yeni >= _KaydirYanitla.esik && !_titredi) {
      _titredi = true;
      HapticFeedback.mediumImpact();
    } else if (yeni < _KaydirYanitla.esik) {
      _titredi = false;
    }
  }

  void _birak([DragEndDetails? _]) {
    final yanitla = _c.value >= _KaydirYanitla.esik;
    _titredi = false;
    _c.animateBack(0, curve: Curves.easeOutCubic);
    if (yanitla) widget.onYanitla();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.etkin) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      dragStartBehavior: DragStartBehavior.down,
      onHorizontalDragStart: (d) {
        // Kenar payı: sistem geri jesti (sol 24 dp) rakipsiz kalsın.
        if (d.globalPosition.dx < 24) return;
        _c.stop();
      },
      onHorizontalDragUpdate: _guncelle,
      onHorizontalDragEnd: _birak,
      onHorizontalDragCancel: _birak,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final k = _c.value;
          final oran = (k / _KaydirYanitla.esik).clamp(0.0, 1.0);
          return Stack(
            alignment: Alignment.centerRight,
            children: [
              Transform.translate(offset: Offset(-k, 0), child: child),
              if (k > 0)
                Positioned(
                  right: 8,
                  child: Opacity(
                    opacity: oran,
                    child: Transform.scale(
                      scale: 0.6 + 0.4 * oran,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: oran >= 1
                              ? DiziRenkler.sari
                              : DiziRenkler.kart,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.reply,
                          size: 18,
                          color: oran >= 1 ? Colors.black : DiziRenkler.metin54,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Tarih rozeti: listedeki gün ayracı ve üstte yüzen kopyası aynı görünüm.
class _TarihRozeti extends StatelessWidget {
  final String etiket;
  final bool golge;
  const _TarihRozeti(this.etiket, {this.golge = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: DiziRenkler.koyuGri,
        borderRadius: BorderRadius.circular(10),
        boxShadow: golge
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Text(
        etiket,
        style: TextStyle(fontSize: 11, color: DiziRenkler.metin54),
      ),
    );
  }
}

/// Mesajın "SS:DD" saati. Sunucu ISO damga gönderir; biçim eskisiyle AYNI
/// (ham damganın 11..16 aralığı) — yalnız gösterildiği YER değişti.
String mesajSaati(Map<String, dynamic> m) {
  final t = m['tarih'] as String? ?? '';
  return t.length >= 16 ? t.substring(11, 16) : '';
}

/// Sohbet listesi: partner başına son mesaj + okunmamış rozeti.
///
/// KULLANICI İSTEĞİ (5 Ağu 2026): "Mesajlar kısmında kişilerin arasında space
/// var ve arka planda hafif grimsi ton var ya, onları kaldır. direkt mesaj,
/// kullanıcı adı, profil resmi olsun."
///
/// Eskiden her satır bir `Card` + `ListTile` idi: Card teması satır başına
/// `EdgeInsets.symmetric(vertical: 4)` kenar boşluğu (yani satır arası 8 dp)
/// ve `DiziRenkler.kart` zemini (koyu temada #1F1F23, ana zemin #0B0B0D'nin
/// üstünde "hafif grimsi ton") veriyordu. İkisi de kalktı: satırlar artık
/// zeminsiz, aralıksız, düz bir liste.
class SohbetlerEkrani extends StatefulWidget {
  const SohbetlerEkrani({super.key});

  @override
  State<SohbetlerEkrani> createState() => _SohbetlerEkraniState();
}

class _SohbetlerEkraniState extends State<SohbetlerEkrani>
    with WidgetsBindingObserver {
  List<dynamic>? _sohbetler;
  List<dynamic> _istekler = const [];
  String? _hata;
  Timer? _sayac;
  bool _cekiliyor = false;
  bool _bekleyenYukle = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SohbetOlaylari.nesil.addListener(_olay);
    _yukle();
    _sayac = Timer.periodic(
      sohbetListeYoklamaAraligi,
      (_) => _yukle(sessiz: true),
    );
  }

  @override
  void dispose() {
    _sayac?.cancel();
    SohbetOlaylari.nesil.removeListener(_olay);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState durum) {
    if (durum == AppLifecycleState.resumed) _yukle(sessiz: true);
  }

  void _olay() => _yukle(sessiz: true);

  Future<void> _yukle({bool sessiz = false}) async {
    if (_cekiliyor) {
      _bekleyenYukle = true;
      return;
    }
    _cekiliyor = true;
    if (!sessiz) setState(() => _hata = null);
    try {
      final d = await Api.get('/sohbetler');
      if (!mounted) return;
      final sohbetler = d['sohbetler'] as List<dynamic>;
      // Eski sunucu `istekler` göndermez -> bölüm boş kalır, çökme olmaz.
      final istekler = (d['istekler'] as List<dynamic>?) ?? const [];
      if (sessiz &&
          _hata == null &&
          _sohbetSatirlariAyni(_sohbetler, sohbetler) &&
          _sohbetSatirlariAyni(_istekler, istekler)) {
        return;
      }
      setState(() {
        _sohbetler = sohbetler;
        _istekler = istekler;
        _hata = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (!sessiz || _sohbetler == null) {
        setState(() => _hata = e.toString());
      }
    } finally {
      _cekiliyor = false;
      if (_bekleyenYukle && mounted) {
        _bekleyenYukle = false;
        _yukle(sessiz: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(
        mesaj: _hata!,
        tekrar: () {
          _yukle();
        },
      );
    } else if (_sohbetler == null) {
      govde = const IskeletListe();
    } else if (_sohbetler!.isEmpty) {
      govde = BosDurum(
        ikon: Icons.chat_outlined,
        baslik: 'Henüz sohbetin yok'.c,
        ipucu: 'Bir profile girip mesaj gönderebilirsin.'.c,
      );
    } else {
      govde = RefreshIndicator(
        color: DiziRenkler.sari,
        onRefresh: () => _yukle(),
        child: ListView.builder(
          // Yatay dolgu SATIRIN İÇİNDE (dokunma alanı kenara kadar sürsün),
          // listede yalnız uçlarda küçük bir nefes payı kalır.
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: _sohbetler!.length,
          itemBuilder: (context, i) => SohbetSatiri(
            sohbet: _sohbetler![i] as Map<String, dynamic>,
            onTap: () async {
              await context.push('/sohbet/${_sohbetler![i]['partner']}');
              _yukle();
            },
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Mesajlar'.c),
        actions: [
          MesajIstekleriDugmesi(
            okunmamisIstek: _istekler
                .where((s) => ((s['okunmamis'] as int?) ?? 0) > 0)
                .length,
            onTap: () async {
              await context.push('/mesaj-istekleri');
              _yukle(); // istekten cevap verildiyse sohbet ana listeye geçer
            },
          ),
        ],
      ),
      // PC'de akış/bildirimler ile AYNI ortalanmış okuma kolonu (720);
      // mobilde kısıt bağlamaz, kullanıcı satırları tam genişlikte kalır.
      body: OrtaKolon(azami: masaustuKolonGenisligi, cocuk: govde),
    );
  }
}

/// Başlığın EN SAĞINDAKİ "Gelen mesaj istekleri" girişi — YALNIZ İKON.
///
/// 5 Ağu 2026'da yazı + ikon istenmişti; 1 Eyl 2026'da kullanıcı geri aldı:
/// *"Mesajlar kısmında 'gelen istekler' yazısı olmasın, ikon olarak onu en
/// sağa al."* Yazı 168 dp'ye kadar yer kaplıyor ve uzun çevirilerde (Almanca
/// "Eingegangene Nachrichtenanfragen") iki satıra sararak başlığı şişiriyordu.
///
/// METİN KAYBOLMADI: `tooltip` (fare/uzun basış) ve `Semantics` (TalkBack)
/// aynı 45 dilli anahtarı okur — ikon-only bir düğmenin ne yaptığını ekran
/// okuyucu kullanan biri de bilmeli.
///
/// Dokunma alanı [dokunmaAsgari] (44 dp) — ui-ux-pro-max "Touch Target Size".
class MesajIstekleriDugmesi extends StatelessWidget {
  final int okunmamisIstek;
  final VoidCallback onTap;
  const MesajIstekleriDugmesi({
    super.key,
    required this.okunmamisIstek,
    required this.onTap,
  });

  /// Sayı 0'ken [Badge] hiç çizilmez: boş rozet ikonu kaydırırdı.
  Widget _rozetle(Widget ikon) => okunmamisIstek > 0
      ? Badge.count(
          count: okunmamisIstek,
          backgroundColor: DiziRenkler.sari,
          textColor: Colors.black,
          child: ikon,
        )
      : ikon;

  @override
  Widget build(BuildContext context) {
    final etiket = 'Gelen mesaj istekleri'.c;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: etiket,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Semantics(
            button: true,
            label: etiket,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                // Rozet KIRMIZI değil marka sarısı: istek kutusu düşük
                // öncelikli, alarm değil. Rozet olmasaydı yeni istek hiçbir
                // yerde görünmezdi (istekler ana listeden çıkarıldı).
                child: _rozetle(
                  Icon(
                    Icons.mark_email_unread_outlined,
                    size: 22,
                    color: DiziRenkler.sariMetin,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Takip edilmeyen kişilerden gelen, hiç cevaplanmamış sohbetler.
class MesajIstekleriEkrani extends StatefulWidget {
  const MesajIstekleriEkrani({super.key});

  @override
  State<MesajIstekleriEkrani> createState() => _MesajIstekleriEkraniState();
}

class _MesajIstekleriEkraniState extends State<MesajIstekleriEkrani>
    with WidgetsBindingObserver {
  List<dynamic>? _istekler;
  List<dynamic> _reddedilenler = const [];
  String? _hata;
  Timer? _sayac;
  bool _cekiliyor = false;
  bool _bekleyenYukle = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SohbetOlaylari.nesil.addListener(_olay);
    _yukle();
    _sayac = Timer.periodic(
      sohbetListeYoklamaAraligi,
      (_) => _yukle(sessiz: true),
    );
  }

  @override
  void dispose() {
    _sayac?.cancel();
    SohbetOlaylari.nesil.removeListener(_olay);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState durum) {
    if (durum == AppLifecycleState.resumed) _yukle(sessiz: true);
  }

  void _olay() => _yukle(sessiz: true);

  Future<void> _yukle({bool sessiz = false}) async {
    if (_cekiliyor) {
      _bekleyenYukle = true;
      return;
    }
    _cekiliyor = true;
    if (!sessiz) setState(() => _hata = null);
    try {
      final d = await Api.get('/sohbetler');
      if (!mounted) return;
      final istekler = (d['istekler'] as List<dynamic>?) ?? const [];
      final reddedilenler = (d['reddedilenler'] as List<dynamic>?) ?? const [];
      if (sessiz &&
          _hata == null &&
          _sohbetSatirlariAyni(_istekler, istekler) &&
          _sohbetSatirlariAyni(_reddedilenler, reddedilenler)) {
        return;
      }
      setState(() {
        _istekler = istekler;
        _reddedilenler = reddedilenler;
        _hata = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (!sessiz || _istekler == null) {
        setState(() => _hata = e.toString());
      }
    } finally {
      _cekiliyor = false;
      if (_bekleyenYukle && mounted) {
        _bekleyenYukle = false;
        _yukle(sessiz: true);
      }
    }
  }

  /// Tek sekmenin gövdesi: istekler ya da reddedilenler listesi.
  ///
  /// Kabul et / Reddet BURADA YOK (26 Ağu 2026): düğmeler sohbet ekranının
  /// içinde (`_istekCubugu`). Listede aynı iki buton hem yer kaplıyor hem
  /// "kararı burada mı içeride mi vereceğim?" diye iki yüzey üretiyordu.
  /// Satıra dokunmak sohbeti açar; karar orada verilir. Reddedilenler'den
  /// geri kabul de aynı yol — sohbeti aç, içeride Kabul et.
  Widget _liste({required bool reddedilenler}) {
    final satirlar = reddedilenler ? _reddedilenler : (_istekler ?? const []);
    if (satirlar.isEmpty) {
      return reddedilenler
          ? BosDurum(
              ikon: Icons.block_outlined,
              baslik: 'Reddettiğin istek yok'.c,
              ipucu:
                  'Reddettiğin istekler burada durur; dilersen geri kabul edebilirsin.'
                      .c,
            )
          : BosDurum(
              ikon: Icons.mark_email_unread_outlined,
              baslik: 'Mesaj isteğin yok'.c,
              ipucu:
                  'Takip etmediğin kişilerden gelen mesajlar burada görünür.'.c,
            );
    }
    return RefreshIndicator(
      color: DiziRenkler.sari,
      onRefresh: () => _yukle(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: satirlar.length,
        itemBuilder: (context, i) {
          final sohbet = satirlar[i] as Map<String, dynamic>;
          return SohbetSatiri(
            sohbet: sohbet,
            onTap: () async {
              await context.push('/sohbet/${sohbet['partner']}');
              // Karar içeride verildiyse satır kovadan düşer.
              _yukle();
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(
        mesaj: _hata!,
        tekrar: () {
          _yukle();
        },
      );
    } else if (_istekler == null) {
      govde = const IskeletListe();
    } else {
      govde = TabBarView(
        children: [_liste(reddedilenler: false), _liste(reddedilenler: true)],
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Gelen mesaj istekleri'.c),
          bottom: TabBar(
            tabs: [
              Tab(text: 'İstekler'.c),
              Tab(text: 'Reddedilenler'.c),
            ],
          ),
        ),
        // Sohbet listesiyle aynı kolon: masaüstünde satırlar sola yapışmasın.
        body: OrtaKolon(azami: masaustuKolonGenisligi, cocuk: govde),
      ),
    );
  }
}

/// Tek sohbet satırı: [avatar (+yeşil nokta)] @ad / son mesaj [okunmamış].
/// Kart YOK, ayraç YOK, satır arası boşluk YOK — düz liste.
class SohbetSatiri extends StatelessWidget {
  final Map<String, dynamic> sohbet;
  final VoidCallback onTap;
  const SohbetSatiri({super.key, required this.sohbet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final okunmamis = (sohbet['okunmamis'] as int?) ?? 0;
    final ozet = mesajOzeti(sohbet);
    final canli = sohbetDurumYazi(sohbetDurumCoz(sohbet));
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: _satirDikeyDolgu,
        ),
        child: Row(
          children: [
            CevrimiciAvatar(
              url: dosyaUrl(sohbet['partner_avatar'] as String?),
              kullaniciAdi: sohbet['partner'] as String?,
              cevrimici: sohbet['cevrimici'] == true,
            ),
            const SizedBox(width: 12),
            // Expanded: uzun kullanıcı adı ve uzun son mesaj 360 dp'de
            // taşmaz, tek satırda kırpılır.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '@${sohbet['partner']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: DiziRenkler.metin,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (canli != null)
                    Text(
                      canli,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: DiziRenkler.sariMetin,
                      ),
                    )
                  else
                    Row(
                      children: [
                        // Metinsiz son mesaj: türünü söyle (ses/foto/video/içerik)
                        if (ozet.ikon != null) ...[
                          Icon(ozet.ikon, size: 14, color: DiziRenkler.metin54),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            ozet.metin,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: DiziRenkler.metin54,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (okunmamis > 0) ...[
              const SizedBox(width: 8),
              OkunmamisRozeti(adet: okunmamis),
            ],
          ],
        ),
      ),
    );
  }
}

/// Okunmamış sayısı rozeti (sarı zemin üstüne DAİMA koyu yazı).
class OkunmamisRozeti extends StatelessWidget {
  final int adet;
  const OkunmamisRozeti({super.key, required this.adet});

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 11,
    backgroundColor: DiziRenkler.sari,
    child: Text(
      '$adet',
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        // Sarı zemin İKİ TEMADA DA aynı olduğu için üstündeki koyu ton da
        // sabittir (tema-duyarlı olsaydı açık temada sarı üstü beyaz olurdu).
        color: DiziRenkler.markaKoyu,
      ),
    ),
  );
}

/// 44x44 avatar; kullanıcı çevrimiçiyse SAĞ ALT köşede yeşil nokta.
///
/// Nokta `Stack`in SINIRLARI İÇİNDE (right:0, bottom:0 -> 30..44 aralığı):
/// dışarı taşan `Positioned` görünür ama tıklanamaz olurdu.
class CevrimiciAvatar extends StatelessWidget {
  final String? url;
  final String? kullaniciAdi;
  final bool cevrimici;
  const CevrimiciAvatar({
    super.key,
    required this.url,
    required this.kullaniciAdi,
    required this.cevrimici,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _avatarCap,
      height: _avatarCap,
      child: Stack(
        children: [
          KullaniciAvatari(
            url: url,
            kullaniciAdi: kullaniciAdi,
            yaricap: _avatarCap / 2,
          ),
          if (cevrimici)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                key: const Key('cevrimici-nokta'),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: DiziRenkler.cevrimiciYesil,
                  shape: BoxShape.circle,
                  // Zemin renginde kontur: nokta koyu da olsa açık da olsa
                  // avatar fotoğrafından ayrışır.
                  border: Border.all(color: DiziRenkler.siyah, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// İkili sohbet: metin + fotoğraf/GIF + dizi/film kartı. 3 sn'de yoklanır.
class SohbetEkrani extends StatefulWidget {
  final String kullaniciAdi;

  /// Enter mesajı gönderir mi? (Shift+Enter her zaman yeni satır.)
  ///
  /// Varsayılan `kIsWeb`: fiziksel klavyede Enter'dan gönderme beklentisi
  /// web'e ait (WhatsApp Web geleneği); mobilde Enter yeni satırdır.
  /// PARAMETRE olması test içindir — `flutter test` daima `kIsWeb == false`
  /// koşar ve gömülü bayrak bu davranışı testlerden tamamen gizlerdi
  /// (google_kapisi.dart'taki `web` parametresiyle aynı ders).
  final bool enterIleGonder;

  const SohbetEkrani({
    super.key,
    required this.kullaniciAdi,
    bool? enterIleGonder,
  }) : enterIleGonder = enterIleGonder ?? kIsWeb;

  @override
  State<SohbetEkrani> createState() => _SohbetEkraniState();
}

class _SohbetEkraniState extends State<SohbetEkrani>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  List<dynamic> _mesajlar = [];
  final Map<String, dynamic> _icerikler = {};
  final Map<String, dynamic> _gonderiler = {};
  bool _yuklendi = false;
  bool _gonderiliyor = false;
  bool _ekYukleniyor = false;

  /// Albüm yüklemesinde "3/5" göstergesi (sıralı yükleme, medya_yukle.dart).
  int _ekIlerleme = 0;
  int _ekToplam = 0;
  String? _karsiDurum; // karşı taraf: yaziyor | kayit
  String? _hata; // ilk yükleme hatası
  Map<String, dynamic>? _partner; // avatar + son_gorulme
  Map<String, dynamic>? _yanitlanan; // alıntılanan mesaj (yanıt modu)
  int? _duzenlenenId; // düzenlenen mesajın id'si (düzenleme modu)
  bool _cekiliyor = false;
  bool _bekleyenYukle = false;
  bool _bekleyenTam = false;
  int? _tepkiUcusId;

  /// Seçilmiş ama HENÜZ GÖNDERİLMEMİŞ dizi/film kartı (TMDB arama sonucu).
  ///
  /// KULLANICI İSTEĞİ (7 Ağu 2026): "sohbette dizi gönderince direk gidiyor
  /// onun yerine metin kısmının üstünde dizi kapak fotoğrafını koy, mesajı
  /// yazmaya devam etsin, mesaj ile aynı divde gitsin film dizi".
  ///
  /// Eskiden `_IcerikSecSheet`ten seçim yapılır yapılmaz mesaj gidiyordu; artık
  /// seçim burada BEKLER, giriş kutusunun üstünde şerit olarak görünür ve
  /// Gönder'e basılınca metinle **TEK** mesaj olarak gider.
  ///
  /// Sunucu değişikliği GEREKMEDİ: `POST /mesajlar` `metin` + `icerik_tur` +
  /// `icerik_id` alanlarını birlikte kabul edip tek satır INSERT ediyor
  /// (backend/server.js:4526-4607) — `if (!temiz && !medya && !icerikVar ...)`
  /// koşulu da yalnız üçü de boşsa 400 veriyor.
  Map<String, dynamic>? _bekleyenIcerik;
  final _metin = TextEditingController();

  /// Kutuda yazı var mı? VARSA foto/GIF/içerik/mikrofon ikonları GİZLENİR
  /// (31 Ağu 2026 isteği: "çok dar alana yazı yazılıyor") — metin silinince
  /// ya da mesaj gönderilince (kutu boşalınca) geri gelirler. Gönder kalır.
  bool _yaziVar = false;

  /// Sohbete özel tema (31 Ağu 2026): kendi balon rengi + zemin tonu.
  /// Tercih yerel ([SohbetTemalari]); detay ekranında değişince `nesil`
  /// yayını buradaki kopyayı tazeler.
  SohbetTema _sohbetTema = SohbetTemalari.listesi.first;

  /// Bu sohbet bekleyen bir MESAJ İSTEĞİ mi? Sunucudan gelir:
  /// 'bekliyor' | 'red' | null. Null değilse yanıt kutusu yerine
  /// Kabul et / Reddet çubuğu çizilir (24 Ağu 2026 kullanıcı isteği:
  /// "kabul etmeden yanıt veremez olmalı, düğmeler sohbetin içinde").
  String? _istek;

  /// Web'de Enter = gönder, Shift+Enter = yeni satır (WhatsApp Web geleneği).
  ///
  /// `onKeyEvent` TextField'a KARAKTER GİRİLMEDEN önce çalışır: handled
  /// dönülen Enter satır sonu olarak kutuya YAZILMAZ. KeyDown dışındaki
  /// (repeat/up) Enter olayları da yutulur — basılı tutulan Enter art arda
  /// boş satır basmasın.
  late final FocusNode _metinOdak = FocusNode(
    onKeyEvent: (node, olay) {
      if (!widget.enterIleGonder) return KeyEventResult.ignored;
      final enterMi =
          olay.logicalKey == LogicalKeyboardKey.enter ||
          olay.logicalKey == LogicalKeyboardKey.numpadEnter;
      if (!enterMi) return KeyEventResult.ignored;
      if (HardwareKeyboard.instance.isShiftPressed) {
        return KeyEventResult.ignored; // Shift+Enter → yeni satır
      }
      if (olay is KeyDownEvent) {
        final metin = _metin.text.trim();
        // Boş Enter gönderim DENEMEZ ama yine yutulur: boş mesaj kutusuna
        // salt satır sonu birikmesin.
        if (metin.isNotEmpty || _bekleyenIcerik != null) {
          _gonder(metin: metin);
        }
      }
      return KeyEventResult.handled;
    },
  );
  final _kaydirma = ScrollController();
  Timer? _sayac;

  GoRouter? _yonlendirici;

  /// Bu konuşma ekranı görünür mü? Kabuk sekmesi değişince StatefulShell
  /// State'i canlı tutar; yoklama durmazsa sunucu "bakıyor" sanır ve push
  /// kesilir. Yalnız rota + ön plan açıkken yokla.
  ///
  /// `false` ile başlar: ilk karede yığın henüz `/sohbetler` iken `true`
  /// varsaymak `POST bakiyor acik:false` yollardı (açılmadan kapanır).
  bool _sohbetGorunur = false;
  bool _bakisGonderildi = false;

  /// Saat sütununun açılma miktarı (0 = kapalı, tavan = tam görünür).
  /// Kalıcı bir mod DEĞİL: parmak kalkınca 0'a geri yaylanır.
  ///
  /// [initState]'te KURULUR, alan başlatıcısında DEĞİL (7 Ağu 2026): `late
  /// final X = ...` TEMBELDİR ve bu denetleyiciye yalnızca mesaj listesinin
  /// `itemBuilder`ı dokunuyor. HİÇ MESAJI OLMAYAN bir sohbette builder hiç
  /// çalışmaz, denetleyici doğmaz ve [dispose] içindeki `_saatKaydirici`
  /// erişimi onu ELEMENT SÖKÜLÜRKEN kurmaya kalkar:
  ///   "Looking up a deactivated widget's ancestor is unsafe"
  ///   (AnimationController → SingleTickerProviderStateMixin.createTicker →
  ///    TickerMode.getValuesNotifier(context))
  /// Yani "yeni açılan boş sohbetten geri çık" = hata ayıklama kipinde
  /// assertion. Erken kurulum hem onu bitirir hem de dispose'u dürüst yapar.
  // ---- Kaydırma durumu (2 Eyl 2026, Telegram düzeni) ----
  /// Yüzen tarih rozeti: görüş alanının üstündeki satırın günü. Yalnız
  /// kaydırma sırasında görünür, durunca 900 ms sonra söner.
  String? _yuzenGun;
  bool _yuzenGorunur = false;
  Timer? _yuzenZamanlayici;

  /// Kullanıcı dipten (en yeni mesajdan) uzak mı — "aşağı in" düğmesi.
  bool _dipten_uzak = false;

  /// Yukarıdayken gelen karşı taraf mesajı sayısı (düğme rozeti).
  int _asagidaYeni = 0;

  /// Satır anahtarları: yüzen tarih için satırların yerini ölçmekte kullanılır.
  /// Anahtar mesaj id'sine (yerel satırda `_yerel` anahtarına) bağlı.
  final Map<Object, GlobalKey> _satirAnahtarlari = {};

  GlobalKey _satirAnahtari(Map<String, dynamic> m, int i) {
    final k = m['id'] ?? m['_yerel'] ?? 'i$i';
    return _satirAnahtarlari.putIfAbsent(k, GlobalKey.new);
  }

  // Sesli mesaj kaydı
  // Web'de mikrofon gizli; kaydediciyi hiç kurma ki eklenti kanalı
  // MissingPluginException gürültüsü üretmesin (hata günlüğü #8-16).
  final AudioRecorder? _kaydedici = kIsWeb ? null : AudioRecorder();
  bool _kaydediyor = false;

  /// Basılı-tut kaydı yukarı kaydırarak KİLİTLENDİ: parmak çekilse de kayıt
  /// sürer, çubukta iptal/gönder düğmeleri çıkar (Telegram'ın kilidi).
  bool _kayitKilitli = false;
  int _kayitSn = 0;
  Timer? _kayitSayaci;
  String? _kayitYolu;
  // Kayıt sırasında mikrofon genliği (0..1) — hem canlı çubuklar hem de
  // mesajla gönderilen dalga formu bundan üretilir.
  final List<double> _seviyeler = [];
  StreamSubscription<Amplitude>? _seviyeAbonelik;
  Timer? _durumSayaci;
  String? _gonderilenDurum;

  /// Karşı tarafa canlı durum. Eskiden yalnız tuşa basılınca ve 3 sn
  /// kısırlığıyla gidiyordu: kısa yazışmada ping bir kez atılıp süre dolunca
  /// düşüyordu; yoklama kaçınca gösterge hiç yanmıyordu.
  void _durumGonder(String? tur) {
    Api.post('/yaziyor', {
      'kullanici_adi': widget.kullaniciAdi,
      'acik': tur != null,
      if (tur != null) 'tur': tur,
    }).catchError((_) => null);
  }

  void _durumHeartbeat(String tur) {
    if (_gonderilenDurum != tur || _durumSayaci == null) {
      _durumGonder(tur);
      _gonderilenDurum = tur;
      _durumSayaci?.cancel();
      _durumSayaci = Timer.periodic(const Duration(seconds: 2), (_) {
        if (!mounted) {
          _durumDurdur();
          return;
        }
        if (tur == 'yaziyor' && _metin.text.trim().isEmpty) {
          _durumDurdur();
          return;
        }
        if (tur == 'kayit' && !_kaydediyor) {
          _durumDurdur();
          return;
        }
        if (!sohbetDurumHeartbeatGonder(
          gorunur: _sohbetGorunur,
          tur: tur,
          kaydediyor: _kaydediyor,
          metinVar: _metin.text.trim().isNotEmpty,
        )) {
          return;
        }
        _durumGonder(tur);
      });
    }
  }

  void _durumDurdur() {
    _durumSayaci?.cancel();
    _durumSayaci = null;
    if (_gonderilenDurum != null) {
      _durumGonder(null);
      _gonderilenDurum = null;
    }
  }

  void _temaYukle() {
    SohbetTemalari.getir(widget.kullaniciAdi).then((t) {
      if (mounted && t.anahtar != _sohbetTema.anahtar) {
        setState(() => _sohbetTema = t);
      }
    });
  }

  /// Kutu doluluk bayrağını günceller (ikon gizleme — bkz. [_yaziVar]).
  void _yaziVarGuncelle() {
    final dolu = _metin.text.trim().isNotEmpty;
    if (dolu != _yaziVar && mounted) setState(() => _yaziVar = dolu);
  }

  /// Yazarken karşı tarafa "yazıyor" sinyali.
  void _yaziyorBildir() {
    if (_kaydediyor) return;
    if (_metin.text.trim().isEmpty) {
      if (_gonderilenDurum == 'yaziyor') _durumDurdur();
      return;
    }
    _durumHeartbeat('yaziyor');
  }

  @override
  void initState() {
    super.initState();
    _yukle(ilk: true);
    _metin.addListener(_yaziyorBildir);
    _metin.addListener(_yaziVarGuncelle);
    _temaYukle();
    SohbetTemalari.nesil.addListener(_temaYukle);
    WidgetsBinding.instance.addObserver(this);
    SohbetOlaylari.nesil.addListener(_sohbetOlayi);
    SohbetOlaylari.acikPartner = widget.kullaniciAdi;
    // Bu sohbetin biriken mesaj bildirimini kapat, geçmişini sıfırla
    mesajBildirimleriniTemizle(widget.kullaniciAdi);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final y = GoRouter.of(context);
    if (!identical(_yonlendirici, y)) {
      _yonlendirici?.routerDelegate.removeListener(_gorunurluk);
      _yonlendirici = y;
      _yonlendirici!.routerDelegate.addListener(_gorunurluk);
    }
    _gorunurluk();
  }

  /// Rota veya yaşam döngüsü değişince yoklamayı aç/kapa.
  void _gorunurluk() {
    if (!mounted) return;
    // `uri.path` değil: sohbet `push` ile açılır, uri tabanda kalır.
    final yol = sohbetUstKonum(_yonlendirici);
    // İlk karede yığın boş gelebilir; yoklamayı/bakıyor damgasını kesme.
    if (yol == null || yol.isEmpty) return;
    final yasam = WidgetsBinding.instance.lifecycleState;
    final acik =
        sohbetOnPlanda(yasam) && sohbetYoluBu(yol, widget.kullaniciAdi);
    final onceki = _sohbetGorunur;
    _sohbetGorunur = acik;
    if (acik) {
      SohbetOlaylari.acikPartner = widget.kullaniciAdi;
      _sayac ??= Timer.periodic(sohbetYoklamaAraligi, (_) => _yukle());
      if (!onceki || !_bakisGonderildi) {
        _sohbetBakisiniAyarla(true);
        _bakisGonderildi = true;
        // Damgayı GET ?bakiyor=1 ile de taze tut (POST zorla açar;
        // yoklama 1 sn sonra gelir, o ana kadar FCM kaçmasın).
        _yukle();
      }
    } else {
      _sayac?.cancel();
      _sayac = null;
      if (SohbetOlaylari.acikPartner == widget.kullaniciAdi) {
        SohbetOlaylari.acikPartner = null;
      }
      // Hiç `acik:true` gitmediyse kapatma da gitmesin (lütuf damgayı
      // 1,5 sn kilitler, uçuştaki GET bakıyor'u geri açamaz).
      if (onceki && _bakisGonderildi) {
        _sohbetBakisiniAyarla(false);
        _bakisGonderildi = false;
      }
      if (sohbetDurumKapatilmali(
        rotaBu: sohbetYoluBu(yol, widget.kullaniciAdi),
        kaydediyor: _kaydediyor,
      )) {
        _durumDurdur();
      }
    }
  }

  /// Sunucuya "bu konuşmaya bakıyorum / baktım" damgası.
  void _sohbetBakisiniAyarla(bool acik) {
    Api.post('/sohbet/bakiyor', {
      'kullanici_adi': widget.kullaniciAdi,
      'acik': acik,
    }).catchError((_) => null);
  }

  @override
  void dispose() {
    _yonlendirici?.routerDelegate.removeListener(_gorunurluk);
    _yonlendirici = null;
    _sayac?.cancel();
    SohbetOlaylari.nesil.removeListener(_sohbetOlayi);
    WidgetsBinding.instance.removeObserver(this);
    if (SohbetOlaylari.acikPartner == widget.kullaniciAdi) {
      SohbetOlaylari.acikPartner = null;
    }
    if (_bakisGonderildi) _sohbetBakisiniAyarla(false);
    _durumDurdur();
    _kayitSayaci?.cancel();
    _seviyeAbonelik?.cancel();
    _kaydedici?.dispose();
    _metin.removeListener(_yaziyorBildir);
    _metin.removeListener(_yaziVarGuncelle);
    SohbetTemalari.nesil.removeListener(_temaYukle);
    _metin.dispose();
    _metinOdak.dispose();
    _kaydirma.dispose();
    _yuzenZamanlayici?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState durum) {
    _gorunurluk();
    if (durum == AppLifecycleState.resumed && _sohbetGorunur) {
      _yukle(tam: true);
    }
  }

  /// FCM veya başka ekran yeni mesaj bildirdi: bu konuşmaysa hemen çek.
  /// Görünürlük bayrağı yanlış olsa bile (klavye/inactive) mesaj insin.
  void _sohbetOlayi() {
    final ad = SohbetOlaylari.partner;
    if (ad != null && ad != widget.kullaniciAdi) return;
    _yukle();
  }

  // ---- Kaydırma bildirimi: yüzen tarih + aşağı-in düğmesi ----
  /// Kaydırma bildirimi DÜZEN SIRASINDA gelebilir (viewport `setPixels`);
  /// o anda satırların bir kısmı henüz yerleşmemiştir. Burada ne `setState`
  /// ne ölçüm yapılır — iş kare sonrasına ertelenir. Ertelemeden ölçmek
  /// debug'da `RenderBox was not laid out` assert'i ile listeyi BOŞ
  /// bıraktı (2 Eyl 2026, emülatörde yakalandı, sunucu hata kaydı #3).
  bool _kareSonrasiBekliyor = false;

  bool _kaydirmaBildirimi(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final bitis = n is ScrollEndNotification;
    if (_kareSonrasiBekliyor && !bitis) return false;
    _kareSonrasiBekliyor = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _kareSonrasiBekliyor = false;
      if (!mounted || !_kaydirma.hasClients) return;
      // TERS listede pixels = dibe uzaklık.
      final uzak = _kaydirma.position.pixels > 300;
      if (uzak != _dipten_uzak) {
        setState(() {
          _dipten_uzak = uzak;
          if (!uzak) _asagidaYeni = 0;
        });
      }
      if (bitis) {
        _yuzenZamanlayici?.cancel();
        _yuzenZamanlayici = Timer(const Duration(milliseconds: 900), () {
          if (mounted && _yuzenGorunur) setState(() => _yuzenGorunur = false);
        });
      } else {
        _yuzenTarihiGuncelle();
      }
    });
    return false;
  }

  /// Görüş alanının ÜST kenarına en yakın satırın gününü bulur. Yalnız
  /// kurulu (ekrandaki/önbellekteki) satırlar ölçülür — üst kenar zaten
  /// kurulu bir satırın içindedir.
  void _yuzenTarihiGuncelle() {
    final listeKutu = context.findRenderObject();
    if (listeKutu is! RenderBox || !listeKutu.hasSize) return;
    final ust = listeKutu.localToGlobal(Offset.zero).dy + kToolbarHeight;
    double? enYakin;
    String? gun;
    for (final m in _mesajlar) {
      if (m is! Map<String, dynamic>) continue;
      final k = _satirAnahtarlari[m['id'] ?? m['_yerel']];
      final rb = k?.currentContext?.findRenderObject();
      if (rb is! RenderBox || !rb.attached || !rb.hasSize) continue;
      final double alt;
      try {
        alt = rb.localToGlobal(Offset(0, rb.size.height)).dy;
      } catch (_) {
        continue; // bir ata henüz yerleşmemiş: bu kareyi atla
      }
      if (alt < ust) continue; // tamamen üstte kalmış
      if (enYakin == null || alt < enYakin) {
        enYakin = alt;
        gun = (m['tarih'] as String? ?? '').split('T').first;
      }
    }
    if (gun == null || gun.isEmpty) return;
    if (gun != _yuzenGun || !_yuzenGorunur) {
      _yuzenZamanlayici?.cancel();
      setState(() {
        _yuzenGun = gun;
        _yuzenGorunur = true;
      });
    }
  }

  /// Üstte yüzen tarih rozeti (Telegram). Listedeki ayraçla aynı görünüm.
  Widget _yuzenTarih() {
    final g = _yuzenGun;
    final p = g?.split('-') ?? const [];
    final etiket = p.length == 3 ? '${p[2]}.${p[1]}.${p[0]}' : (g ?? '');
    return Positioned(
      top: 8,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _yuzenGorunur && g != null ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: Center(child: _TarihRozeti(etiket, golge: true)),
        ),
      ),
    );
  }

  /// Sağ altta "aşağı in" (Telegram): dipten uzaktayken görünür; yukarıdayken
  /// gelen mesaj sayısı rozet olarak biner.
  Widget _asagiInDugmesi() {
    return Positioned(
      right: 12,
      bottom: 12,
      child: AnimatedScale(
        scale: _dipten_uzak ? 1 : 0,
        duration: const Duration(milliseconds: 160),
        child: Semantics(
          button: true,
          label: 'En yeni mesaja in'.c,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: DiziRenkler.kart,
                shape: const CircleBorder(),
                elevation: 3,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    _kaydirma.animateTo(
                      0,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                    );
                    setState(() => _asagidaYeni = 0);
                  },
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: DiziRenkler.metin,
                    ),
                  ),
                ),
              ),
              if (_asagidaYeni > 0)
                Positioned(
                  top: -6,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: DiziRenkler.sari,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$_asagidaYeni',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
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

  // ---- Sesli mesaj kaydı ----
  Future<void> _kayitBasla() async {
    try {
      if (_kaydedici == null) return;
      // İzin diyaloğu `paused` basar. Damgayı ve `_kaydediyor`'u ÖNCE yak;
      // yoksa _gorunurluk acik:false atar, karşı taraf kaydı hiç görmez.
      if (mounted) {
        setState(() {
          _kaydediyor = true;
          _kayitSn = 0;
          _seviyeler.clear();
        });
      }
      _durumHeartbeat('kayit');
      if (!await _kaydedici.hasPermission()) {
        _durumDurdur();
        if (mounted) setState(() => _kaydediyor = false);
        return;
      }
      final dizin = await getTemporaryDirectory();
      final yol =
          '${dizin.path}/ses_${DateTime.now().millisecondsSinceEpoch}.ogg';
      await _kaydedici.start(
        const RecordConfig(encoder: AudioEncoder.opus),
        path: yol,
      );
      _kayitYolu = yol;
      if (!mounted) return;
      // Canlı ses şiddeti: 100 ms'de bir örnek (2 dk × 10 = en çok 1200 örnek)
      _seviyeAbonelik?.cancel();
      _seviyeAbonelik = _kaydedici
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((a) {
            if (!mounted) return;
            setState(() => _seviyeler.add(genlikNormalle(a.current)));
          });
      _kayitSayaci = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _kayitSn++);
        if (_kayitSn >= 120) _kayitGonder(); // 2 dk üst sınır
      });
    } catch (_) {
      _durumDurdur();
      if (mounted) setState(() => _kaydediyor = false);
    }
  }

  Future<void> _kayitIptal() async {
    _kayitSayaci?.cancel();
    _seviyeAbonelik?.cancel();
    try {
      await _kaydedici?.stop();
    } catch (_) {}
    _kayitYolu = null;
    _durumDurdur();
    if (mounted) {
      setState(() {
        _kaydediyor = false;
        _kayitKilitli = false;
        _kayitSn = 0;
      });
      if (_metin.text.trim().isNotEmpty) _yaziyorBildir();
    }
  }

  Future<void> _kayitGonder() async {
    _kayitSayaci?.cancel();
    _seviyeAbonelik?.cancel();
    _durumDurdur();
    final saniye = _kayitSn;
    final dalga = dalgaKodla(_seviyeler, saniye);
    String? yol;
    try {
      yol = await _kaydedici?.stop();
    } catch (_) {}
    yol ??= _kayitYolu;
    if (mounted) {
      setState(() {
        _kaydediyor = false;
        _kayitKilitli = false;
        _kayitSn = 0;
      });
    }
    if (yol == null || saniye < 1) return; // çok kısa → iptal
    if (mounted) setState(() => _ekYukleniyor = true);
    try {
      final bayt = await dosyaOku(yol);
      final sonuc = await Api.medyaYukle(bayt);
      await _gonder(
        medya: sonuc['yol'] as String,
        sesDalga: dalga.isEmpty ? null : dalga,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ses gönderilemedi'.c)));
      }
    } finally {
      if (mounted) setState(() => _ekYukleniyor = false);
    }
  }

  /// Mesaj isteği çubuğu: yanıt kutusunun YERİNE çizilir. Karar yalnız
  /// sohbetin İÇİNDE verilir — istek listesinde bu düğmeler yok.
  Widget _istekCubugu() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: () => _istekKarari('red'),
              child: Text('Reddet'.c, maxLines: 1),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 44,
            child: FilledButton(
              onPressed: () => _istekKarari('kabul'),
              child: Text('Kabul et'.c, maxLines: 1),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _istekKarari(String karar) async {
    final partnerId = (_partner?['id'] as num?)?.toInt();
    if (partnerId == null) return;
    try {
      await Api.post('/mesaj-istekleri/karar', {
        'partner_id': partnerId,
        'karar': karar,
      });
    } catch (_) {
      // Çubuk yerinde kalır; kullanıcı yeniden dokunabilir. Sessiz kayıp yok:
      // düğme etkisiz kalmış gibi görünür ve tekrar denenebilir.
      return;
    }
    if (!mounted) return;
    if (karar == 'kabul') {
      // Kutu anında açılır; sunucu da sonraki yoklamada istek=null döndürür.
      setState(() => _istek = null);
    } else {
      // Reddedilen sohbette kalınmaz: listeye dönülür (Instagram davranışı).
      context.pop();
    }
  }

  /// En yeni mesaja döner. TERS listede dip offset 0'dır → tek `jumpTo`.
  ///
  /// ESKİDEN: 0/120/400/900/1600/2400 ms'lik altı zamanlayıcı `maxScrollExtent`
  /// kovalıyordu, çünkü liste düz çiziliyor ve geç yüklenen görseller dibi
  /// kaçırıyordu. `reverse: true` ile o yarış tamamen ortadan kalktı:
  /// içerik yukarıda büyüse bile çapa dipte durur (bkz. ListView yorumu).
  void _sonaKaydir() {
    if (!_kaydirma.hasClients) return;
    _kaydirma.jumpTo(0);
  }

  int? _sonMesajId() {
    if (_mesajlar.isEmpty) return null;
    final id = (_mesajlar.last as Map)['id'];
    return id is num ? id.toInt() : null;
  }

  String _mesajParmakIzi(
    List<dynamic> mesajlar,
    String? durum,
    Map<String, dynamic>? partner,
  ) {
    final b = StringBuffer()
      ..write(durum ?? '0')
      ..write('|')
      ..write(partner?['son_gorulme'] ?? '');
    for (final ham in mesajlar) {
      final m = ham as Map;
      b
        ..write('|')
        ..write(m['id'])
        ..write(':')
        ..write(m['okundu'])
        ..write(':')
        ..write(m['iletildi'])
        ..write(':')
        ..write(m['duzenlendi'])
        ..write(':')
        ..write(m['metin'])
        ..write(':')
        ..write(m['tepkiler']);
    }
    return b.toString();
  }

  /// İlk yüklemede tam geçmiş; yoklamada `?sonra=` ile yalnız yeniler.
  /// Aynı anda tek istek; çakışan çağrılar bitince bir kez daha çekilir.
  Future<void> _yukle({bool ilk = false, bool tam = false}) async {
    if (_cekiliyor) {
      _bekleyenYukle = true;
      if (tam) _bekleyenTam = true;
      return;
    }
    _cekiliyor = true;
    try {
      final sonId = _sonMesajId();
      final artimli = !ilk && !tam && sonId != null;
      final parcalar = <String>[
        if (_sohbetGorunur) 'bakiyor=1',
        if (artimli) 'sonra=$sonId',
      ];
      final taban = '/mesajlar/${widget.kullaniciAdi}';
      final yol = parcalar.isEmpty ? taban : '$taban?${parcalar.join('&')}';
      final d = await Api.get(yol);
      if (!mounted) return;
      final gelen = d['mesajlar'] as List<dynamic>? ?? const [];
      final durum = sohbetDurumCoz(d);
      final istek = d['istek'] as String?;
      final partner = d['partner'] as Map<String, dynamic>?;
      final icerikler = d['icerikler'] as Map<String, dynamic>? ?? {};
      final gonderiler = d['gonderiler'] as Map<String, dynamic>? ?? {};
      final guncellemeler = d['guncellemeler'] as List<dynamic>? ?? const [];

      List<dynamic> birlesik;
      var yeniGeldi = false;
      if (artimli) {
        final mevcut = <int>{
          for (final m in _mesajlar)
            if ((m as Map)['id'] is num) (m['id'] as num).toInt(),
        };
        final ekler = [
          for (final m in gelen)
            if ((m as Map)['id'] is num &&
                !mevcut.contains((m['id'] as num).toInt()))
              m,
        ];
        yeniGeldi = ekler.isNotEmpty;
        birlesik = yeniGeldi ? [..._mesajlar, ...ekler] : _mesajlar;
        if (guncellemeler.isNotEmpty) {
          birlesik = _pencereyiUygula(birlesik, guncellemeler);
        }
      } else {
        // İyimser (yerel) satırlar TAM yüklemede kaybolmasın: sunucudan
        // gelmezler, bekleyen/hatalı gönderim ekranda kalmalı (2 Eyl 2026).
        birlesik = [
          ...gelen,
          for (final m in _mesajlar)
            if (m is Map<String, dynamic> && m['_yerel'] != null) m,
        ];
        yeniGeldi = gelen.length != _mesajlar.length;
      }

      final parmak = _mesajParmakIzi(birlesik, durum, partner);
      final eski = _mesajParmakIzi(_mesajlar, _karsiDurum, _partner);
      if (!ilk && parmak == eski && istek == _istek && _hata == null) return;

      // TERS listede dibe (en yeni mesaja) uzaklık doğrudan `pixels`tir.
      // Kullanıcı geçmişi okuyorsa (250 px'den uzaktaysa) gelen mesaj onu
      // aşağı ÇEKMEZ — sadece rozet/liste güncellenir.
      final altaYakinDi =
          !_kaydirma.hasClients || _kaydirma.position.pixels <= 250;
      setState(() {
        _mesajlar = birlesik;
        _icerikler.addAll(icerikler);
        _gonderiler.addAll(gonderiler);
        _karsiDurum = durum;
        _istek = istek;
        if (partner != null) _partner = partner;
        _yuklendi = true;
        _hata = null;
      });
      if (ilk || (yeniGeldi && altaYakinDi)) {
        _sonaKaydir();
      } else if (yeniGeldi && artimli) {
        // Kullanıcı geçmişi okuyor: gelen karşı taraf mesajlarını "aşağı in"
        // rozetinde say (Telegram).
        final benimId = context.read<Oturum>().kullanici?['id'];
        final yeniKarsi = birlesik
            .skip(_mesajlar.length)
            .where((m) => (m as Map)['gonderen_id'] != benimId)
            .length;
        if (yeniKarsi > 0) setState(() => _asagidaYeni += yeniKarsi);
      }
    } catch (e) {
      // İlk yüklemede hata → boş sohbet yerine hata + tekrar dene göster
      if (mounted && ilk) {
        setState(() {
          _yuklendi = true;
          _hata = e.toString();
        });
      }
    } finally {
      _cekiliyor = false;
      if (_bekleyenYukle && mounted && _sohbetGorunur) {
        _bekleyenYukle = false;
        final tekrarTam = _bekleyenTam;
        _bekleyenTam = false;
        _yukle(tam: tekrarTam);
      }
    }
  }

  /// Yoklama penceresindeki tepki/okundu damgalarını mevcut balonlara yazar.
  List<dynamic> _pencereyiUygula(
    List<dynamic> mevcut,
    List<dynamic> guncellemeler,
  ) {
    final harita = <int, Map<String, dynamic>>{};
    for (final ham in guncellemeler) {
      if (ham is! Map) continue;
      final id = (ham['id'] as num?)?.toInt();
      if (id == null) continue;
      harita[id] = Map<String, dynamic>.from(ham);
    }
    if (harita.isEmpty) return mevcut;
    return [
      for (final ham in mevcut)
        if (ham is Map<String, dynamic>)
          _mesajiPenceredenYaz(ham, harita[(ham['id'] as num?)?.toInt()])
        else
          ham,
    ];
  }

  Map<String, dynamic> _mesajiPenceredenYaz(
    Map<String, dynamic> ham,
    Map<String, dynamic>? g,
  ) {
    if (g == null) return ham;
    final id = (ham['id'] as num?)?.toInt();
    // Uçuştaki kendi tepkimiz bayat boş listeyle ezilmesin.
    if (id != null && id == _tepkiUcusId) {
      return {
        ...ham,
        'okundu': g['okundu'] ?? ham['okundu'],
        'iletildi': g['iletildi'] ?? ham['iletildi'],
        'duzenlendi': g['duzenlendi'] ?? ham['duzenlendi'],
      };
    }
    return {
      ...ham,
      'okundu': g['okundu'] ?? ham['okundu'],
      'iletildi': g['iletildi'] ?? ham['iletildi'],
      'duzenlendi': g['duzenlendi'] ?? ham['duzenlendi'],
      if (g['tepkiler'] is List) 'tepkiler': g['tepkiler'],
    };
  }

  /// Kendi mesajını sil: önce yerelde kaldır (iyimser), hata olursa geri getir.
  Future<void> _mesajSil(int id) async {
    final yedek = List<dynamic>.from(_mesajlar);
    setState(
      () => _mesajlar = _mesajlar
          .where((m) => (m as Map<String, dynamic>)['id'] != id)
          .toList(),
    );
    try {
      await Api.delete('/mesajlar/$id');
    } catch (e) {
      if (!mounted) return;
      setState(() => _mesajlar = yedek);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Mesaj silinemedi'.c)));
    }
  }

  /// Md. 43 — mesaja tepki ver / kaldır (`emoji: null` = kaldır).
  ///
  /// İYİMSER: rozet dokunur dokunmaz güncellenir, sunucu hata verirse liste
  /// eski hâline döner + SnackBar. Karşı tarafın tepkisi 3 sn'lik yoklama
  /// `guncellemeler` ile gelir; kendi tepkimiz uçuşta ezilmesin.
  Future<void> _tepkiVer(int mesajId, String? emoji) async {
    final yedek = List<dynamic>.from(_mesajlar);
    _tepkiUcusId = mesajId;
    setState(() {
      _mesajlar = [
        for (final ham in _mesajlar)
          if (ham is Map<String, dynamic> &&
              (ham['id'] as num?)?.toInt() == mesajId)
            {...ham, 'tepkiler': _tepkileriUygula(ham['tepkiler'], emoji)}
          else
            ham,
      ];
    });
    try {
      final d = await Api.post('/mesaj-tepki', {
        'mesaj_id': mesajId,
        'emoji': emoji,
      });
      // Sunucu KESİN listeyi döner (aynı biçim): karşı taraf aynı anda tepki
      // vermişse sayaç yoklamayı beklemeden düzelir. Alan yoksa
      // (eski sunucu) iyimser hâl korunur.
      final kesin = (d as Map<String, dynamic>?)?['tepkiler'];
      if (kesin is List && mounted) {
        setState(() {
          _mesajlar = [
            for (final ham in _mesajlar)
              if (ham is Map<String, dynamic> &&
                  (ham['id'] as num?)?.toInt() == mesajId)
                {...ham, 'tepkiler': kesin}
              else
                ham,
          ];
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _mesajlar = yedek);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (_tepkiUcusId == mesajId) _tepkiUcusId = null;
    }
  }

  /// İyimser tepki listesi: kendi tepkini kaldırır, yenisini ekler, sayaçları
  /// düzeltir. Sunucu yanıtıyla aynı biçimi üretir (`emoji`/`adet`/`benim`).
  List<Map<String, dynamic>> _tepkileriUygula(Object? ham, String? yeni) {
    final liste = <Map<String, dynamic>>[
      for (final t in (ham as List<dynamic>? ?? const []))
        if (t is Map<String, dynamic>) Map<String, dynamic>.from(t),
    ];
    // Önce eski tepkini düş
    for (final t in List<Map<String, dynamic>>.from(liste)) {
      if (t['benim'] != true) continue;
      final kalan = ((t['adet'] as num?)?.toInt() ?? 1) - 1;
      if (kalan <= 0) {
        liste.remove(t);
      } else {
        t['adet'] = kalan;
        t['benim'] = false;
      }
    }
    if (yeni == null) return liste;
    final mevcut = liste.where((t) => t['emoji'] == yeni).firstOrNull;
    if (mevcut == null) {
      liste.add({'emoji': yeni, 'adet': 1, 'benim': true});
    } else {
      mevcut['adet'] = ((mevcut['adet'] as num?)?.toInt() ?? 0) + 1;
      mevcut['benim'] = true;
    }
    return liste;
  }

  /// Yazma kutusunun içindeki kompakt eylem ikonu (foto / içerik / ses /
  /// gönder). IconButton'un 48px dokunma alanı kutuyu şişirdiği için
  /// InkWell + sıkı padding kullanılır; hedef yine ~36px kalır.
  Widget _kutuIkonu({
    required String ipucu,
    required IconData ikon,
    required VoidCallback onTap,
    bool kapali = false,
    bool yukleniyor = false,
    bool vurgulu = false,
  }) {
    return Tooltip(
      message: ipucu,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: kapali ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: yukleniyor
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: DiziRenkler.sari,
                  ),
                )
              : Icon(
                  ikon,
                  size: 22,
                  color: kapali
                      ? DiziRenkler.metin38
                      : (vurgulu ? DiziRenkler.sari : DiziRenkler.sariMetin),
                ),
        ),
      ),
    );
  }

  // ---- İYİMSER GÖNDERİM (2 Eyl 2026, Telegram düzeni) ----
  //
  // Mesaj dokunur dokunmaz listenin dibinde belirir (`_bekliyor` + saat
  // ikonu; medyada yerel önizleme + yükleme halkası). Sunucu onaylayınca
  // yerel satır düşer, yoklama gerçek satırı getirir. Hata olursa satır
  // KALIR, kırmızı "Gönderilemedi · tekrar dene" yazar; dokununca aynı
  // parametrelerle yeniden denenir. Üç hâl kuralı: yükleniyor/başarı/hata.
  int _yerelSayac = 0;

  /// Bekleyen satırın "tekrar dene" eylemi (anahtar → yeniden gönderim).
  final Map<String, Future<void> Function()?> _yerelTekrar = {};

  /// Listeye bekleyen satır ekler, anahtarını döner.
  String _yerelEkle(
    Map<String, dynamic> alanlar, {
    Future<void> Function()? tekrar,
  }) {
    final benimId = context.read<Oturum>().kullanici?['id'];
    final anahtar =
        'y${DateTime.now().microsecondsSinceEpoch}-${_yerelSayac++}';
    final satir = <String, dynamic>{
      ...alanlar,
      '_yerel': anahtar,
      '_bekliyor': true,
      '_ilerleme': 0.0,
      'gonderen_id': benimId,
      'tarih': DateTime.now().toUtc().toIso8601String(),
      'tepkiler': const [],
    };
    _yerelTekrar[anahtar] = tekrar;
    setState(() => _mesajlar = [..._mesajlar, satir]);
    _sonaKaydir();
    return anahtar;
  }

  void _yerelGuncelle(String anahtar, Map<String, dynamic> yama) {
    if (!mounted) return;
    setState(() {
      _mesajlar = [
        for (final m in _mesajlar)
          if (m is Map<String, dynamic> && m['_yerel'] == anahtar)
            {...m, ...yama}
          else
            m,
      ];
    });
  }

  void _yerelKaldir(String anahtar) {
    _yerelTekrar.remove(anahtar);
    if (!mounted) return;
    setState(() {
      _mesajlar = [
        for (final m in _mesajlar)
          if (!(m is Map<String, dynamic> && m['_yerel'] == anahtar)) m,
      ];
    });
  }

  Future<void> _yerelTekrarDene(Map<String, dynamic> m) async {
    final anahtar = m['_yerel'] as String?;
    if (anahtar == null) return;
    final tekrar = _yerelTekrar[anahtar];
    _yerelKaldir(anahtar);
    if (tekrar != null) await tekrar();
  }

  Future<void> _gonder({
    String? metin,
    String? medya,
    List<String>? medyalar,
    String? sesDalga,
    String? icerikTur,
    int? icerikId,
    String? dosya,
    String? dosyaAd,
    int? dosyaBoyut,
    String? dosyaTur,
    String? yerelAnahtar,
  }) async {
    if (_gonderiliyor) return;
    // Düzenleme modunda: metni PATCH ile güncelle, yeni mesaj atma
    if (_duzenlenenId != null) {
      await _duzenlemeyiKaydet(metin ?? '');
      return;
    }
    // Bekleyen dizi/film kartı varsa AYNI mesaja biner (kullanıcı isteği,
    // 7 Ağu). Çağıran açıkça bir içerik verdiyse o kazanır.
    final bekleyen = _bekleyenIcerik;
    final tur = icerikTur ?? (bekleyen?['media_type'] as String?) ?? 'tv';
    final kimlik = icerikId ?? (bekleyen?['id'] as num?)?.toInt();
    final icerikVar = icerikId != null || bekleyen != null;
    // ALBÜM: `medya` = ilk öğe (eski istemci/eski sunucu uyumu), `medyalar` =
    // hepsi. Tek dosyalık gönderimde de aynı yol: sunucu ikisini kabul ediyor.
    final ilkMedya =
        medya ??
        (medyalar != null && medyalar.isNotEmpty ? medyalar.first : null);
    // İYİMSER SATIR: çağıran (medya/belge akışı) kendi satırını verdiyse o
    // kullanılır; yoksa burada kurulur (metin, GIF, içerik kartı, ses).
    final yanitKopya = _yanitlanan;
    final anahtar =
        yerelAnahtar ??
        _yerelEkle(
          {
            if (metin != null && metin.isNotEmpty) 'metin': metin,
            if (ilkMedya != null) 'medya': ilkMedya,
            if (medyalar != null && medyalar.length > 1) 'medyalar': medyalar,
            if (dosyaAd != null) 'dosya_ad': dosyaAd,
            if (dosyaBoyut != null) 'dosya_boyut': dosyaBoyut,
            if (dosyaTur != null) 'dosya_tur': dosyaTur,
            if (sesDalga != null) 'ses_dalga': sesDalga,
            if (icerikVar) 'icerik_tur': tur,
            if (icerikVar && kimlik != null) 'icerik_id': kimlik,
            if (yanitKopya != null) ...{
              'yanit_id': yanitKopya['id'],
              'yanit_metin': yanitKopya['metin'],
              'yanit_medya': yanitKopya['medya'],
              'yanit_dosya_ad': yanitKopya['dosya_ad'],
            },
          },
          tekrar: () => _gonder(
            metin: metin,
            medya: medya,
            medyalar: medyalar,
            sesDalga: sesDalga,
            icerikTur: icerikTur,
            icerikId: icerikId,
            dosya: dosya,
            dosyaAd: dosyaAd,
            dosyaBoyut: dosyaBoyut,
            dosyaTur: dosyaTur,
          ),
        );
    // Kutu hemen boşalır (Telegram): yazı balonda görünüyor zaten.
    _metin.clear();
    setState(() {
      _gonderiliyor = true;
      _yanitlanan = null;
      _bekleyenIcerik = null;
    });
    try {
      await Api.post('/mesajlar', {
        'kullanici_adi': widget.kullaniciAdi,
        if (metin != null && metin.isNotEmpty) 'metin': metin,
        if (ilkMedya != null) 'medya': ilkMedya,
        if (medyalar != null && medyalar.length > 1) 'medyalar': medyalar,
        if (dosya != null) 'dosya': dosya,
        if (dosyaAd != null) 'dosya_ad': dosyaAd,
        if (dosyaBoyut != null) 'dosya_boyut': dosyaBoyut,
        if (dosyaTur != null) 'dosya_tur': dosyaTur,
        if (sesDalga != null) 'ses_dalga': sesDalga,
        if (icerikVar) 'icerik_tur': tur,
        if (icerikVar && kimlik != null) 'icerik_id': kimlik,
        if (yanitKopya != null) 'yanit_id': (yanitKopya['id'] as num).toInt(),
      });
      _durumDurdur();
      SohbetOlaylari.mesajGeldi(widget.kullaniciAdi);
      _yerelKaldir(anahtar);
      await _yukle();
      _sonaKaydir();
    } catch (e) {
      if (!mounted) return;
      // Satır kalır, kırmızı hata + dokununca tekrar (üç hâl kuralı).
      _yerelGuncelle(anahtar, {'_bekliyor': false, '_hata': true});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  /// Bir mesaja yanıt vermeye başla (alıntı kutusu belirir, klavye açılır).
  void _yanitBaslat(Map<String, dynamic> m) {
    setState(() {
      _duzenlenenId = null;
      _yanitlanan = m;
    });
  }

  /// Kendi metin mesajını düzenlemeye başla (metin kutusuna yüklenir).
  void _duzenlemeBaslat(Map<String, dynamic> m) {
    setState(() {
      _yanitlanan = null;
      _duzenlenenId = (m['id'] as num).toInt();
      _metin.text = (m['metin'] as String?) ?? '';
      _metin.selection = TextSelection.fromPosition(
        TextPosition(offset: _metin.text.length),
      );
    });
  }

  void _modIptal() {
    setState(() {
      _yanitlanan = null;
      _duzenlenenId = null;
      _metin.clear();
    });
  }

  Future<void> _duzenlemeyiKaydet(String metin) async {
    final id = _duzenlenenId;
    if (id == null) return;
    if (metin.trim().isEmpty) return;
    setState(() => _gonderiliyor = true);
    try {
      await Api.patch('/mesajlar/$id', {'metin': metin.trim()});
      _metin.clear();
      setState(() => _duzenlenenId = null);
      await _yukle(tam: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  /// Galeriden fotoğraf/GIF/video seç → **inceleme/düzenleme ekranı** →
  /// yükle → TEK mesaj olarak gönder (albüm).
  ///
  /// ÇOKLU SEÇİM (2 Eyl 2026, Telegram düzeni): eskiden `azami: 1` idi çünkü
  /// `mesajlar.medya` TEXT'ti. Artık sunucuda `mesajlar.medyalar TEXT[]` var
  /// (migrasyon-2026-09-02b.sql): `medya` = ilk öğe (ESKİ istemciler onu
  /// okumaya devam eder), `medyalar` = hepsi (yeni istemci albüm çizer).
  /// Tavan [albumAzami] — Telegram'ın da tavanı 10.
  ///
  /// Seçim sisteme (Android Fotoğraf Seçici) devredildiği için geniş galeri
  /// izni İSTENMEZ — `medya_inceleme.dart` başındaki Play reddi notu.
  Future<void> _fotoGonder() async {
    final secim = await medyaSec(context, azami: albumAzami);
    if (secim.isEmpty || !mounted) return;
    await _medyalariGonder(secim);
  }

  /// Seçilmiş dosyaları sırayla yükler ve tek mesaj (albüm) olarak gönderir.
  /// Kısmi başarıda yüklenenler gider, düşenler SnackBar ile söylenir —
  /// kullanıcı 5 seçip 3'ünü bulursa nedenini bilir.
  Future<void> _medyalariGonder(List<XFile> secim) async {
    // Yazılmış metin de gitsin: eskiden fotoğraf/video eklenince kutudaki
    // yazı sessizce kayboluyordu.
    final metin = _metin.text.trim();
    // İyimser satır: cihaz yolları önizlenir, yükleme halkası biner. Web'de
    // yol boş olabilir (bellek içi XFile) — o zaman halka tek başına durur.
    final anahtar = _yerelEkle({
      'medya_yerel': [for (final d in secim) d.path],
      if (metin.isNotEmpty) 'metin': metin,
    }, tekrar: () => _medyalariGonder(secim));
    _metin.clear();
    setState(() {
      _ekYukleniyor = true;
      _ekIlerleme = 0;
      _ekToplam = secim.length;
    });
    MedyaYuklemeSonuc sonuc;
    try {
      // Sınır ORTAK sabitten (100 MB = sunucunun `/medya` sınırı); 20 MB üstü
      // video inceleme ekranında cihazda zaten sıkıştırıldı (`videoHazirla`).
      sonuc = await medyalariYukle(
        secim,
        toplamAzamiBayt: null,
        adim: (biten) {
          if (!mounted) return;
          setState(() => _ekIlerleme = biten);
          _yerelGuncelle(anahtar, {'_ilerleme': biten / secim.length});
        },
      );
    } finally {
      if (mounted) setState(() => _ekYukleniyor = false);
    }
    if (!mounted) return;
    final bildirim = sonuc.bildirim;
    if (sonuc.yuklenen.isEmpty) {
      _yerelGuncelle(anahtar, {'_bekliyor': false, '_hata': true});
      _uyar(bildirim ?? 'Hiçbir medya yüklenemedi'.c);
      return;
    }
    if (bildirim != null) _uyar(bildirim);
    await _gonder(
      medyalar: [for (final y in sonuc.yuklenen) y['yol'] as String],
      metin: metin,
      yerelAnahtar: anahtar,
    );
  }

  /// Dizi/film arayıp kart olarak gönder.
  /// KENDİ GIF ARŞİVİMİZDEN seç ve TEK mesaj olarak gönder.
  ///
  /// TEK DOSYA SINIRI: `mesajlar.medya` TEXT'tir (TEXT[] DEĞİL, sema.sql),
  /// yani bir mesaj tam bir medya taşır — seçici de tek kayıt döndürür.
  /// YENİDEN YÜKLEME YOK: arşivdeki GIF sunucuda zaten duruyor, yolu doğrudan
  /// gider. Kendi bekleyen GIF'in de aynı `m<id>-<hex>.gif` adını taşır, yani
  /// `POST /mesajlar` sahiplik regexinden geçer.
  Future<void> _gifGonder() async {
    final gif = await gifSecAc(context);
    if (gif == null || !mounted) return;
    final yol = gif['yol'] as String?;
    if (yol == null) return;
    await _gonder(medya: yol, metin: _metin.text.trim());
  }

  Future<void> _icerikPaylas() async {
    final secilen = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DiziRenkler.koyuGri,
      // Sohbet kartı AFİŞ çiziyor: kişi/firma bağlanamaz.
      builder: (_) => const IcerikSecSheet(kisiVeFirma: false),
    );
    if (secilen == null) return;
    // GÖNDERMİYORUZ: seçim giriş kutusunun üstünde BEKLER, kullanıcı yazmaya
    // devam eder, Gönder'e basınca metinle tek mesaj olarak gider.
    if (!mounted) return;
    setState(() => _bekleyenIcerik = secilen);
  }

  /// Bekleyen dizi/film kartını kaldırır (şeritteki çarpı).
  void _bekleyenIcerikKaldir() => setState(() => _bekleyenIcerik = null);

  /// Giriş kutusunun üstünde duran "gönderilmeyi bekleyen dizi/film" şeridi.
  ///
  /// Kapak + ad + kaldırma çarpısı. Yanıt/düzenleme kutusuyla AYNI kalıbı
  /// izler (aynı zemin, aynı dolgu, sağda `Icons.close`) — kullanıcı iki
  /// şeridi de aynı şekilde iptal edebilsin diye.
  Widget _bekleyenIcerikSeridi() {
    final s = _bekleyenIcerik!;
    final ad = (s['name'] ?? s['title'] ?? '') as String;
    final poster = posterUrl(s['poster_path'] as String?, boyut: 'w154');
    final yil = ((s['first_air_date'] ?? s['release_date'] ?? '') as String);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      color: DiziRenkler.koyuGri,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 32,
              height: 48,
              child: poster == null
                  ? Container(
                      color: DiziRenkler.kart,
                      child: Icon(
                        Icons.movie_outlined,
                        size: 16,
                        color: DiziRenkler.metin54,
                      ),
                    )
                  : Image.network(poster, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mesaja eklenecek'.c,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: DiziRenkler.sariMetin,
                  ),
                ),
                Text(
                  yil.length >= 4 ? '$ad (${yil.substring(0, 4)})' : ad,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: DiziRenkler.metin54),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _bekleyenIcerikKaldir,
            icon: Icon(Icons.close, color: DiziRenkler.metin54),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final benimId = context.watch<Oturum>().kullanici?['id'];
    final karsiYazi = sohbetDurumYazi(_karsiDurum);
    // "Görüldü" satırının sahibi. LİSTE BAŞINA BİR KEZ hesaplanır: her
    // balonda yeniden aramak O(n²) olurdu ve uzun sohbette kaydırma takılırdı.
    final gorulduIndeksi = sonGorulenIndeks(_mesajlar, benimId);

    return Scaffold(
      // Sohbete özel tema zemini: uygulama zemininin üstüne balon renginin
      // çok hafif tonu; varsayılan temada null → hiçbir şey değişmez.
      backgroundColor: _sohbetTema.zemin(context),
      appBar: AppBar(
        // BAŞLIK YÜKSEKLİĞİ (1 Eyl 2026 isteği: "yukarıdaki kullanıcı adı
        // kısmını %35 daha küçük yap, sohbete alan açılsın"). 64 × 0.65 =
        // 41.6 dp ederdi ve bu, geri okunun dokunma hedefini [dokunmaAsgari]
        // (44 dp) ALTINA düşürürdü — alt çubukta 3 Ağu'da aynı %35 isteği
        // gelince de aynı yerde durulmuştu (bkz. kabuk.dart
        // masaustuCubukYuksekligi). Tavan 44'te kesildi: %31 kısalma, kazanç
        // 20 dp ve erişilebilirlik bozulmadı. Yazı ölçüleri de küçüldü
        // (17→15, 12→11) ki iki satır 44 dp'ye sığsın.
        toolbarHeight: 44,
        title: InkWell(
          // 31 Ağu 2026 isteği: ada dokunmak artık profile DEĞİL, WhatsApp
          // tarzı sohbet detayına (tema / arama / sessize al / medya) gider.
          // Profil kaybolmadı: detay ekranındaki "Profili gör" oraya götürür.
          onTap: () => context.push('/sohbet/${widget.kullaniciAdi}/detay'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '@${widget.kullaniciAdi}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: DiziRenkler.metin,
                ),
              ),
              if (karsiYazi != null)
                Text(
                  karsiYazi,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.1,
                    fontWeight: FontWeight.w500,
                    color: DiziRenkler.sariMetin,
                  ),
                )
              else
                _DurumSatiri(sonGorulme: _partner?['son_gorulme'] as String?),
            ],
          ),
        ),
        // Sesli/görüntülü arama. Yalnız karşılıklı takipleşmede ve arama
        // özelliği açıkken çizilir; web'de hiç görünmez (gerekçe:
        // lib/gorusme/arama_servisi.dart başlığı).
        actions: [
          AramaDugmeleri(
            kullaniciAdi: widget.kullaniciAdi,
            avatar: _partner?['avatar'] as String?,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          // Genis ekranda sohbet kolonu ortalanir (Telegram Web gibi)
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              Expanded(
                child: !_yuklendi
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: DiziRenkler.sari,
                        ),
                      )
                    : (_hata != null && _mesajlar.isEmpty)
                    ? HataGorunumu(
                        mesaj: _hata!,
                        tekrar: () => _yukle(ilk: true),
                      )
                    // Stack (2 Eyl 2026, Telegram düzeni): liste + üstte yüzen
                    // tarih rozeti + sağ altta "aşağı in" düğmesi. Eski saat-
                    // sürükleme jesti (RawGestureDetector) kalktı: saat artık
                    // balonun içinde, yatay sürükleme "kaydırarak yanıtla".
                    : Stack(
                        children: [
                          NotificationListener<ScrollNotification>(
                            onNotification: _kaydirmaBildirimi,
                            child: ListView.builder(
                              controller: _kaydirma,
                              // TERS LİSTE = ÇAPA DİPTE (28 Ağu 2026).
                              // Kullanıcı: "sohbet ekranı sürekli yukarı kayıyor,
                              // klavye aç/kapa yapıyorum, mesaj geliyor, mesaj
                              // atıyorum — sürekli kayıyor."
                              // SEBEP: liste düz çiziliyordu, dip ise `jumpTo(
                              // maxScrollExtent)` ile TAKLİT ediliyordu. Kaydırma
                              // uzaklığı listenin BAŞINDAN ölçülür; klavye açılıp
                              // viewport küçülünce, yeni mesaj eklenince ya da bir
                              // görsel geç yüklenip yüksekliği büyütünce
                              // `maxScrollExtent` değişiyor ama `pixels` sabit
                              // kalıyordu — görüntü dibe göre YUKARI kayıyordu.
                              // Zamanlayıcılı jumpTo'lar bunu kovalıyor, arada bir
                              // yetişemiyordu.
                              // `reverse: true` ile offset 0 = EN YENİ mesaj ve
                              // ölçüm dipten yapılır: içerik yukarıda büyüse de
                              // çapa oynamaz. Kullanıcı kaydırmadıkça ekran
                              // kıpırdamaz — istenen davranış BU.
                              reverse: true,
                              padding: const EdgeInsets.all(12),
                              itemCount: _mesajlar.length,
                              itemBuilder: (context, tersIndeks) {
                                // `_mesajlar` KRONOLOJİK kalır (eski→yeni); yalnız
                                // çizim sırası ters. Böylece "önceki gün" karşı-
                                // laştırması ve tarih ayracı aynen çalışır.
                                final i = _mesajlar.length - 1 - tersIndeks;
                                final m = _mesajlar[i] as Map<String, dynamic>;
                                final gun = (m['tarih'] as String? ?? '')
                                    .split('T')
                                    .first;
                                final oncekiGun = i > 0
                                    ? ((_mesajlar[i - 1]
                                                      as Map<
                                                        String,
                                                        dynamic
                                                      >)['tarih']
                                                  as String? ??
                                              '')
                                          .split('T')
                                          .first
                                    : null;
                                final benimMi = m['gonderen_id'] == benimId;
                                final metinMi =
                                    (m['metin'] as String?)?.isNotEmpty ==
                                        true &&
                                    m['medya'] == null &&
                                    m['icerik_tur'] == null;
                                final baloncuk = _MesajBaloncugu(
                                  // Yoklama listeyi yenilerken baloncuk id ile
                                  // eşleşsin: medya yeniden yüklenip kaymasın.
                                  key: ValueKey(
                                    m['id'] ?? m['_yerel'] ?? 'm$i',
                                  ),
                                  mesaj: m,
                                  benim: benimMi,
                                  icerikler: _icerikler,
                                  gonderiler: _gonderiler,
                                  // "Görüldü" YALNIZ son okunan kendi mesajımda.
                                  gorulduGoster: i == gorulduIndeksi,
                                  yanitla: m['id'] != null
                                      ? () => _yanitBaslat(m)
                                      : null,
                                  sil: benimMi && m['id'] != null
                                      ? () =>
                                            _mesajSil((m['id'] as num).toInt())
                                      : null,
                                  duzenle: benimMi && metinMi
                                      ? () => _duzenlemeBaslat(m)
                                      : null,
                                  sikayet: !benimMi && m['id'] != null
                                      ? () => sikayetEtSheet(
                                          context,
                                          'mesaj',
                                          (m['id'] as num).toInt(),
                                        )
                                      : null,
                                  // Henüz gönderilmemiş (id'siz) iyimser satıra
                                  // tepki verilemez: sunucuda karşılığı yok.
                                  tepkiVer: m['id'] == null
                                      ? null
                                      : (emoji) => _tepkiVer(
                                          (m['id'] as num).toInt(),
                                          emoji,
                                        ),
                                  balonRenk: _sohbetTema.balon,
                                  balonYazi: _sohbetTema.yazi,
                                  tekrarDene: m['_hata'] == true
                                      ? () => _yerelTekrarDene(m)
                                      : null,
                                );
                                // Kaydırarak yanıtla (Telegram): satır sola
                                // sürüklenince ok belirir, eşik geçilince yanıt.
                                final satir = _KaydirYanitla(
                                  key: _satirAnahtari(m, i),
                                  etkin: m['id'] != null && _istek == null,
                                  onYanitla: () => _yanitBaslat(m),
                                  child: baloncuk,
                                );
                                if (gun == oncekiGun || gun.isEmpty)
                                  return satir;
                                // Tarih ayracı: gün değişince ortada küçük rozet
                                final p = gun.split('-');
                                final etiket = p.length == 3
                                    ? '${p[2]}.${p[1]}.${p[0]}'
                                    : gun;
                                return Column(
                                  children: [
                                    Center(child: _TarihRozeti(etiket)),
                                    satir,
                                  ],
                                );
                              },
                            ),
                          ),
                          _yuzenTarih(),
                          _asagiInDugmesi(),
                        ],
                      ),
              ),
              // Başlıkta kaçarsa (kırpma / bakış) kutunun üstünde de dursun.
              if (karsiYazi != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      karsiYazi,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: DiziRenkler.sariMetin,
                      ),
                    ),
                  ),
                ),
              // Bekleyen dizi/film kartı: seçildi ama HENÜZ gönderilmedi.
              // Yanıt kutusuyla aynı kalıp (aynı yer, aynı zemin, aynı çarpı).
              if (_bekleyenIcerik != null) _bekleyenIcerikSeridi(),
              // Yanıt / düzenleme kutusu (giriş alanının hemen üstünde)
              if (_yanitlanan != null || _duzenlenenId != null)
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                  color: DiziRenkler.koyuGri,
                  child: Row(
                    children: [
                      Icon(
                        _duzenlenenId != null ? Icons.edit : Icons.reply,
                        size: 18,
                        color: DiziRenkler.sariMetin,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _duzenlenenId != null
                                  ? 'Mesajı düzenle'.c
                                  : 'Yanıtlanıyor'.c,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: DiziRenkler.sariMetin,
                              ),
                            ),
                            Text(
                              _duzenlenenId != null
                                  ? ((_metin.text).trim())
                                  : _yanitOnizleme(_yanitlanan!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: DiziRenkler.metin54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _modIptal,
                        icon: Icon(Icons.close, color: DiziRenkler.metin54),
                      ),
                    ],
                  ),
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                  // Bekleyen mesaj isteğinde yanıt kutusu HİÇ çizilmez:
                  // kabul edilmeden yanıt verilemez (24 Ağu 2026).
                  // Basılı-tut kaydı sürerken de [_yaziCubugu] çizilir: mikrofon
                  // düğmesi AYNI ağaç konumunda kalmalı, yoksa uzun basma jesti
                  // kopar. Tam çubuk yalnız kayıt KİLİTLENİNCE gelir.
                  child: _istek != null
                      ? _istekCubugu()
                      : (_kaydediyor && _kayitKilitli)
                      ? _kayitCubugu()
                      : _yaziCubugu(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Yazı çubuğu — Telegram düzeni (2 Eyl 2026): solda yuvarlak HAP (yazı
  /// alanı + ataç), sağda TEK yuvarlak eylem düğmesi (boşken mikrofon, yazı
  /// varken gönder). GIF / dizi-film / dosya / kamera ataç PANELİNE taşındı.
  ///
  /// NEDEN DÜĞMELER ARTIK `TextField.suffixIcon`'DA DEĞİL — ANR KÖK SEBEBİ:
  /// TextField kendi semantics düğümünü suffix'teki düğmelerin düğümleriyle
  /// "kardeş grubu" olarak birleştiriyor. Yükleme sırasında ikonlar değişince
  /// (ataç → spinner, yazı varken GIF/film/mikrofon gizlenince) Flutter'ın yeni
  /// semantics hattı (`_RenderObjectSemantics._mergeSiblingGroup`) önbellekteki
  /// düğümü hem GRUP hem ÇOCUK olarak kullanıyor → düğüm kendi çocuğu oluyor →
  /// `SemanticsNode.attach` sonsuz özyineleme. Sürüm derlemesinde `assert` yok,
  /// bu yüzden istisna değil %100 CPU + ANR; debug'da assert konuşuyor:
  /// `semantics.dart:2967 '!newChildren.any((child) => child == this)'`,
  /// yaratıcı `Semantics ← … ← TextField ← Expanded ← Row`. Semantics ağacı
  /// YALNIZ bir erişilebilirlik servisi açıkken kurulduğu için emülatörde hiç
  /// çıkmadı; Galaxy S24'te (Auto Clicker servisi açık) her video gönderiminde
  /// çıktı (Play 1.114.0, `dumpsys dropbox data_app_anr` + simpleperf ile
  /// sembollü libapp.so: `SemanticsNode.attach` + `_LinkedHashMapMixin`).
  /// Düğmeler TextField'ın DIŞINDA kardeş olunca grup birleşmesi hiç kurulmuyor.
  /// KURAL: `TextField.suffixIcon`/`prefixIcon` içine bir daha DÜĞME KOYMA
  /// (aynı desen Reels yanıt kutusundaydı, oraya da uygulandı: kesfet_akis).
  Widget _yaziCubugu() {
    final duzenleme = _duzenlenenId != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _kaydediyor
              ? _kayitHapi()
              : Container(
                  decoration: BoxDecoration(
                    color: DiziRenkler.kart,
                    borderRadius: BorderRadius.circular(24),
                    border: DiziRenkler.acik
                        ? Border.all(color: const Color(0xFFDADAE0))
                        : null,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _metin,
                          focusNode: _metinOdak,
                          minLines: 1,
                          maxLines: 5,
                          maxLength: 2000,
                          buildCounter:
                              (
                                _, {
                                required currentLength,
                                maxLength,
                                required isFocused,
                              }) => null,
                          onChanged: (_) => _yaziyorBildir(),
                          onSubmitted: (_) =>
                              _gonder(metin: _metin.text.trim()),
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Mesaj'.c,
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.fromLTRB(
                              18,
                              12,
                              4,
                              12,
                            ),
                          ),
                        ),
                      ),
                      // Ataç yazarken de KALIR: "medya + altyazı" akışı kutudaki
                      // yazıyla gider. Düzenleme kipinde kapalı: düzenlenen mesaja
                      // yeni ek bağlanamaz.
                      // Albüm yüklenirken "2/5": sıralı yükleme dakikalar sürebilir,
                      // dönen tek spinner "takıldı" dedirtir (üç hâl kuralı).
                      if (_ekYukleniyor && _ekToplam > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(
                            '$_ekIlerleme/$_ekToplam',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: DiziRenkler.sariMetin,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(right: 4, bottom: 2),
                        child: _kutuIkonu(
                          ipucu: 'Ekle'.c,
                          ikon: Icons.attach_file,
                          kapali: _ekYukleniyor || duzenleme,
                          yukleniyor: _ekYukleniyor,
                          onTap: _ekPaneliAc,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(width: 6),
        _eylemDugmesi(),
      ],
    );
  }

  /// Sağdaki yuvarlak düğme: yazı varsa GÖNDER, yoksa MİKROFON (basılı tut).
  ///
  /// Web'de mikrofon çizilmez (kayıt native), yerine gönder durur; düzenleme
  /// kipinde de gönder (kaydet) durur. Mikrofon jesti [_MikrofonDugmesi]'nde.
  Widget _eylemDugmesi() {
    // Bekleyen dizi/film kartı varken de GÖNDER: kartı yazısız yollamak
    // meşru (sunucu içerik varsa metin istemiyor), mikrofon orada anlamsız.
    final gonder =
        !_kaydediyor &&
        (_yaziVar ||
            _duzenlenenId != null ||
            _bekleyenIcerik != null ||
            kIsWeb);
    final kapali = _gonderiliyor || _ekYukleniyor;
    if (gonder) {
      return Semantics(
        button: true,
        enabled: !kapali,
        label: 'Gönder'.c,
        child: Tooltip(
          message: 'Gönder'.c,
          child: Material(
            color: kapali ? DiziRenkler.metin38 : DiziRenkler.sari,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: kapali ? null : () => _gonder(metin: _metin.text.trim()),
              child: const SizedBox(
                width: 46,
                height: 46,
                child: Icon(Icons.send_rounded, color: Colors.black, size: 22),
              ),
            ),
          ),
        ),
      );
    }
    return _MikrofonDugmesi(
      kapali: kapali,
      onBasla: _kayitBasla,
      onBirak: ({required bool iptal, required bool kilitli}) {
        if (iptal) {
          _kayitIptal();
        } else if (!kilitli) {
          _kayitGonder();
        } else {
          // Kilitlendi: kayıt sürer, [_kayitCubugu] iptal/gönder sunar.
          if (mounted) setState(() => _kayitKilitli = true);
        }
      },
    );
  }

  /// Ataç paneli — Telegram'ın "+" alt sayfası.
  ///
  /// Kutucuklar: Galeri (sistem Fotoğraf Seçici — panel içi ızgara YOK, Play
  /// 7 Ağu'da medya iznini reddetti, bkz. medya_inceleme.dart), Kamera, Dosya,
  /// GIF, Dizi/Film. Konum ve Kişi BİLEREK yok: konum izni Play incelemesi
  /// açar, kişi paylaşımı yeni bir mesaj türü ister — ayrı iş.
  Future<void> _ekPaneliAc() async {
    _metinOdak.unfocus();
    final secim = await showModalBottomSheet<_EkTuru>(
      context: context,
      backgroundColor: DiziRenkler.koyuGri,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _EkPaneli(),
    );
    if (secim == null || !mounted) return;
    switch (secim) {
      case _EkTuru.galeri:
        await _fotoGonder();
      case _EkTuru.kamera:
        await _kameraGonder();
      case _EkTuru.dosya:
        await _dosyaGonder();
      case _EkTuru.gif:
        await _gifGonder();
      case _EkTuru.icerik:
        await _icerikPaylas();
    }
  }

  /// Basılı-tut kaydı sürerken hapın yerine geçen şerit: nabız + süre +
  /// "kaydırarak iptal" ipucu + kilit ipucu. Parmak hâlâ mikrofonda.
  Widget _kayitHapi() {
    final dk = _kayitSn ~/ 60;
    final sn = (_kayitSn % 60).toString().padLeft(2, '0');
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: DiziRenkler.kart,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const _KayitNabzi(),
          const SizedBox(width: 10),
          Text(
            '$dk:$sn',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          Icon(Icons.chevron_left, size: 18, color: DiziRenkler.metin54),
          Text(
            'Kaydırarak iptal'.c,
            style: TextStyle(fontSize: 12, color: DiziRenkler.metin54),
          ),
          const SizedBox(width: 8),
          Icon(Icons.lock_open, size: 16, color: DiziRenkler.metin38),
        ],
      ),
    );
  }

  /// Kamera: fotoğraf çekip AYNI yükleme hattına verir. Video çekimi bilerek
  /// yok — galeri yolu videoyu kapsıyor, ikinci bir kamera kipi paneli
  /// kalabalıklaştırırdı.
  Future<void> _kameraGonder() async {
    final XFile? foto;
    try {
      foto = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
        maxWidth: 2560,
      );
    } catch (_) {
      if (mounted) _uyar('Kamera açılamadı'.c);
      return;
    }
    if (foto == null || !mounted) return;
    await _medyalariGonder([foto]);
  }

  /// Dosya (belge): sistem dosya seçici → `/dosya` yüklemesi → belge mesajı.
  /// Sunucu belgeyi `application/octet-stream` + `attachment` ile servis
  /// eder (yüklenen HTML/SVG asla sayfa olarak açılmaz); mesaj satırı adı,
  /// boyutu ve MIME'ı taşır.
  Future<void> _dosyaGonder() async {
    FilePickerResult? secim;
    try {
      secim = await FilePicker.platform.pickFiles(
        withData: kIsWeb,
        withReadStream: false,
      );
    } catch (_) {
      if (mounted) _uyar('Dosya seçilemedi'.c);
      return;
    }
    final d = secim?.files.single;
    if (d == null || !mounted) return;
    if (d.size > dosyaAzamiBayt) {
      _uyar(
        'Dosya en fazla {} MB olabilir'.cf([dosyaAzamiBayt ~/ (1024 * 1024)]),
      );
      return;
    }
    final metin = _metin.text.trim();
    final anahtar = _yerelEkle({
      'dosya_ad': d.name,
      'dosya_boyut': d.size,
      if (metin.isNotEmpty) 'metin': metin,
    }, tekrar: _dosyaGonder);
    _metin.clear();
    setState(() => _ekYukleniyor = true);
    try {
      final bayt = d.bytes ?? await dosyaOku(d.path!);
      final sonuc = await Api.dosyaYukle(bayt, ad: d.name);
      await _gonder(
        dosya: sonuc['yol'] as String,
        dosyaAd: d.name,
        dosyaBoyut: d.size,
        dosyaTur: sonuc['tur'] as String?,
        metin: metin,
        yerelAnahtar: anahtar,
      );
    } on ApiHata catch (e) {
      _yerelGuncelle(anahtar, {'_bekliyor': false, '_hata': true});
      if (mounted) _uyar(e.mesaj.c);
    } catch (_) {
      _yerelGuncelle(anahtar, {'_bekliyor': false, '_hata': true});
      if (mounted) _uyar('Dosya gönderilemedi'.c);
    } finally {
      if (mounted) setState(() => _ekYukleniyor = false);
    }
  }

  void _uyar(String mesaj) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(mesaj)));
  }

  /// Kayıt sırasında giriş çubuğu: iptal + nabız + canlı dalga + süre + gönder.
  Widget _kayitCubugu() {
    final dk = _kayitSn ~/ 60;
    final sn = (_kayitSn % 60).toString().padLeft(2, '0');
    // Son 40 örnek akar; başta soldan doldurmak için sıfırlarla tamamlanır.
    final son = _seviyeler.length > dalgaOrnekSayisi
        ? _seviyeler.sublist(_seviyeler.length - dalgaOrnekSayisi)
        : [
            ..._seviyeler,
            ...List.filled(dalgaOrnekSayisi - _seviyeler.length, 0.0),
          ];
    return Row(
      children: [
        IconButton(
          tooltip: 'İptal'.c,
          onPressed: _kayitIptal,
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
        ),
        const _KayitNabzi(),
        const SizedBox(width: 10),
        Text(
          '$dk:$sn',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SesDalga(
            seviyeler: son,
            renk: DiziRenkler.sari,
            yukseklik: 28,
          ),
        ),
        const SizedBox(width: 6),
        IconButton.filled(
          tooltip: 'Gönder'.c,
          onPressed: _kayitGonder,
          style: IconButton.styleFrom(
            backgroundColor: DiziRenkler.sari,
            foregroundColor: Colors.black,
          ),
          icon: const Icon(Icons.send),
        ),
      ],
    );
  }
}

/// Kayıt sırasında yanıp sönen kırmızı nokta.
class _KayitNabzi extends StatefulWidget {
  const _KayitNabzi();
  @override
  State<_KayitNabzi> createState() => _KayitNabziState();
}

class _KayitNabziState extends State<_KayitNabzi>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: 0.3, end: 1).animate(_c),
    child: Container(
      width: 12,
      height: 12,
      decoration: const BoxDecoration(
        color: Colors.redAccent,
        shape: BoxShape.circle,
      ),
    ),
  );
}

/// Basılı-tut mikrofon düğmesi (Telegram jesti).
///
/// * Basılı tut → kayıt başlar, düğme büyür.
/// * Sola kaydır (> [iptalEsigi] px) → bırakınca İPTAL.
/// * Yukarı kaydır (> [kilitEsigi] px) → KİLİT: parmak çekilse de kayıt sürer.
/// * Bırak → gönder (1 sn altı kayıtlar [_kayitGonder] içinde zaten iptal).
/// * Tek dokunuş → "basılı tut" ipucu (Telegram da öyle yapar; sessizce hiçbir
///   şey olmaması kullanıcıya düğme bozuk dedirtir).
///
/// Jest kesintisiz olsun diye bu widget kayıt boyunca AĞAÇTA AYNI YERDE kalır
/// (`_yaziCubugu` → `_eylemDugmesi`); üst çubuk yalnız kilitte değişir.
class _MikrofonDugmesi extends StatefulWidget {
  final bool kapali;
  final VoidCallback onBasla;
  final void Function({required bool iptal, required bool kilitli}) onBirak;

  const _MikrofonDugmesi({
    required this.kapali,
    required this.onBasla,
    required this.onBirak,
  });

  static const iptalEsigi = 90.0;
  static const kilitEsigi = 70.0;

  @override
  State<_MikrofonDugmesi> createState() => _MikrofonDugmesiState();
}

class _MikrofonDugmesiState extends State<_MikrofonDugmesi> {
  bool _basili = false;
  Offset _kayma = Offset.zero;

  bool get _iptalde => _kayma.dx < -_MikrofonDugmesi.iptalEsigi;
  bool get _kilitte => _kayma.dy < -_MikrofonDugmesi.kilitEsigi;

  @override
  Widget build(BuildContext context) {
    final etiket = 'Sesli mesaj (basılı tut)'.c;
    return Semantics(
      button: true,
      enabled: !widget.kapali,
      label: etiket,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.kapali
            ? null
            : () => ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(
                  SnackBar(content: Text('Kaydetmek için basılı tut'.c)),
                ),
        onLongPressStart: widget.kapali
            ? null
            : (_) {
                setState(() {
                  _basili = true;
                  _kayma = Offset.zero;
                });
                widget.onBasla();
              },
        onLongPressMoveUpdate: (d) {
          if (!_basili) return;
          setState(() => _kayma = d.offsetFromOrigin);
        },
        onLongPressEnd: (_) {
          if (!_basili) return;
          final iptal = _iptalde;
          final kilit = !iptal && _kilitte;
          setState(() {
            _basili = false;
            _kayma = Offset.zero;
          });
          widget.onBirak(iptal: iptal, kilitli: kilit);
        },
        onLongPressCancel: () {
          if (!_basili) return;
          setState(() {
            _basili = false;
            _kayma = Offset.zero;
          });
          widget.onBirak(iptal: true, kilitli: false);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: _basili ? 64 : 46,
          height: _basili ? 64 : 46,
          // Kayıt basılıyken düğme büyür ve sarıya döner; iptal eşiği
          // geçilince KIRMIZI (renk tek gösterge değil: ikon da değişir).
          decoration: BoxDecoration(
            color: widget.kapali
                ? DiziRenkler.metin38
                : (_basili
                      ? (_iptalde ? Colors.redAccent : DiziRenkler.sari)
                      : DiziRenkler.kart),
            shape: BoxShape.circle,
            border: DiziRenkler.acik && !_basili
                ? Border.all(color: const Color(0xFFDADAE0))
                : null,
          ),
          child: Icon(
            _basili
                ? (_iptalde
                      ? Icons.delete_outline
                      : (_kilitte ? Icons.lock : Icons.mic))
                : Icons.mic_none,
            size: _basili ? 28 : 22,
            color: _basili ? Colors.black : DiziRenkler.sariMetin,
          ),
        ),
      ),
    );
  }
}

/// Ataç panelindeki seçenekler.
enum _EkTuru { galeri, kamera, dosya, gif, icerik }

/// Ataç paneli — Telegram'ın "+" alt sayfası: renkli daire ikonlu kutucuklar.
///
/// Panel içi fotoğraf ızgarası BİLEREK yok (Play, 7 Ağu 2026: geniş medya
/// izni reddi). Galeri kutucuğu sistem seçicisini açar.
class _EkPaneli extends StatelessWidget {
  const _EkPaneli();

  @override
  Widget build(BuildContext context) {
    final secenekler = <({_EkTuru tur, IconData ikon, Color renk, String ad})>[
      (
        tur: _EkTuru.galeri,
        ikon: Icons.photo_library_outlined,
        renk: const Color(0xFF6C5CE7),
        ad: 'Galeri'.c,
      ),
      if (!kIsWeb)
        (
          tur: _EkTuru.kamera,
          ikon: Icons.photo_camera_outlined,
          renk: const Color(0xFFE17055),
          ad: 'Kamera'.c,
        ),
      (
        tur: _EkTuru.dosya,
        ikon: Icons.insert_drive_file_outlined,
        renk: const Color(0xFF0984E3),
        ad: 'Dosya'.c,
      ),
      (
        tur: _EkTuru.gif,
        ikon: Icons.gif_box_outlined,
        renk: const Color(0xFF00B894),
        ad: 'GIF'.c,
      ),
      (
        tur: _EkTuru.icerik,
        ikon: Icons.local_movies_outlined,
        renk: DiziRenkler.sari,
        ad: 'Dizi / Film'.c,
      ),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: DiziRenkler.metin38,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 16,
              children: [
                for (final s in secenekler)
                  _EkKutucugu(
                    ikon: s.ikon,
                    renk: s.renk,
                    ad: s.ad,
                    onTap: () => Navigator.of(context).pop(s.tur),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Panel kutucuğu: 56 dp renkli daire + altında ad. Dokunma hedefi 84×84.
class _EkKutucugu extends StatelessWidget {
  final IconData ikon;
  final Color renk;
  final String ad;
  final VoidCallback onTap;

  const _EkKutucugu({
    required this.ikon,
    required this.renk,
    required this.ad,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: ad,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 84,
          height: 92,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: renk, shape: BoxShape.circle),
                child: Icon(ikon, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 8),
              Text(
                ad,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: DiziRenkler.metin),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Başlıktaki durum satırı: son [cevrimiciEsikSn] sn içinde aktifse
/// "çevrimiçi", değilse "son görülme ...". son_gorulme ISO zaman damgası
/// (UTC) beklenir; kullanıcı çevrimiçi durumunu gizliyorsa sunucu bu alanı
/// NULL gönderir ve satır hiç çizilmez.
class _DurumSatiri extends StatelessWidget {
  final String? sonGorulme;
  const _DurumSatiri({this.sonGorulme});

  @override
  Widget build(BuildContext context) {
    if (sonGorulme == null) return const SizedBox.shrink();
    final an = DateTime.tryParse(sonGorulme!)?.toLocal();
    if (an == null) return const SizedBox.shrink();
    final fark = DateTime.now().difference(an);
    final cevrimici = fark.inSeconds < cevrimiciEsikSn;
    final String etiket;
    if (cevrimici) {
      etiket = 'çevrimiçi'.c;
    } else if (fark.inMinutes < 60) {
      etiket = 'son görülme {} dk önce'.cf([fark.inMinutes]);
    } else if (fark.inHours < 24) {
      etiket = 'son görülme {} saat önce'.cf([fark.inHours]);
    } else {
      etiket = 'son görülme {} gün önce'.cf([fark.inDays]);
    }
    return Text(
      etiket,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        // 11 px: küçülen 44 dp'lik başlığa iki satır sığsın (bkz. AppBar
        // toolbarHeight notu).
        fontSize: 11,
        height: 1.1,
        fontWeight: FontWeight.w500,
        color: cevrimici ? DiziRenkler.sariMetin : DiziRenkler.metin54,
      ),
    );
  }
}

bool sesDosyasi(String yol) =>
    yol.endsWith('.ogg') ||
    yol.endsWith('.m4a') ||
    yol.endsWith('.mp3') ||
    yol.endsWith('.aac');

/// Karşı tarafın okuduğu EN SON kendi mesajımın indeksi (yoksa -1).
///
/// NEDEN TEK BİR SATIR (1 Eyl 2026 isteği: "mesaj görüldüyse mesajın altında
/// görüldü yazsın"): okunmuş HER balonun altına "Görüldü" basmak, uzun bir
/// sohbette aynı kelimeyi onlarca kez tekrarlamak olurdu — Instagram DM de
/// yalnız sondakinde gösterir. Sondan başa taranır: okundu bayrağı zaman
/// içinde monoton değil (eski bir mesaj okunmamış kalabilir), o yüzden
/// "ilk okunmamışın bir öncesi" değil, GERÇEKTEN sondaki okunmuş aranır.
@visibleForTesting
int sonGorulenIndeks(List<dynamic> mesajlar, Object? benimId) {
  for (var i = mesajlar.length - 1; i >= 0; i--) {
    final m = mesajlar[i];
    if (m is! Map) continue;
    if (m['gonderen_id'] != benimId) continue;
    if (m['okundu'] == true) return i;
  }
  return -1;
}

/// Metinsiz mesajın (ses/foto/video/içerik) kısa özeti: ikon + söz.
/// Hem sohbet listesindeki son mesaj satırında hem alıntı kutusunda kullanılır.
({IconData? ikon, String metin}) mesajOzeti(Map<String, dynamic> m) {
  final metin = (m['metin'] as String?)?.trim();
  if (metin != null && metin.isNotEmpty) return (ikon: null, metin: metin);
  // BELGE (2 Eyl 2026): sohbet listesi/alıntı "Dosya: ad" der.
  final dosyaAd = m['dosya_ad'] as String? ?? m['yanit_dosya_ad'] as String?;
  if (dosyaAd != null && dosyaAd.isNotEmpty) {
    return (ikon: Icons.insert_drive_file_outlined, metin: dosyaAd);
  }
  final medya = m['medya'] as String? ?? m['yanit_medya'] as String?;
  if (medya != null) {
    if (sesDosyasi(medya)) {
      return (ikon: Icons.mic, metin: 'Sesli mesaj'.c);
    }
    if (medya.endsWith('.mp4') || medya.endsWith('.webm')) {
      return (ikon: Icons.videocam, metin: 'Video'.c);
    }
    return (ikon: Icons.photo, metin: 'Fotoğraf'.c);
  }
  if (m['icerik_tur'] != null || m['yanit_icerik_tur'] != null) {
    return (ikon: Icons.local_movies, metin: 'İçerik'.c);
  }
  // PAYLAŞILAN GÖNDERİ (1 Eyl 2026, kullanıcı: "bir postu birisine gönderince
  // o mesajlar kısmında BOŞ gözüküyor"). Gönderi mesajının metni de medyası
  // da yoktur — yalnız `yorum_id` taşır; buraya bakılmayınca satır bomboş
  // kalıyordu. Sunucu alanı /sohbetler yanıtına 1 Eyl'de eklendi.
  if (m['yorum_id'] != null || m['yanit_yorum_id'] != null) {
    return (ikon: Icons.dynamic_feed, metin: 'Gönderi'.c);
  }
  return (ikon: null, metin: '');
}

/// Alıntı/yanıt kutusu için kısa önizleme metni.
String _yanitOnizleme(Map<String, dynamic> m) => mesajOzeti(m).metin;

/// Tek mesaj baloncuğu: metin, medya (foto/GIF/video) ve içerik kartı.
class _MesajBaloncugu extends StatelessWidget {
  final Map<String, dynamic> mesaj;
  final bool benim;
  final Map<String, dynamic> icerikler;
  final Map<String, dynamic> gonderiler; // paylaşılan gönderi önizlemeleri
  final VoidCallback? sil;
  final VoidCallback? yanitla;
  final VoidCallback? duzenle;

  /// Karsi tarafin mesajini sikayet et. Kendi mesajimizda null olur —
  /// kendini sikayet etmek anlamsiz. Backend de yalniz ALICININ sikayet
  /// etmesine izin veriyor (POST /sikayet sahiplik kontrolu).
  final VoidCallback? sikayet;

  /// Md. 43 — mesaja emoji tepkisi. `null` emoji = tepkiyi kaldır.
  /// Mesajın id'si yoksa (henüz gönderilmemiş iyimser satır) null gelir.
  final void Function(String? emoji)? tepkiVer;

  /// Bu balonun altına "Görüldü" yazılsın mı (1 Eyl 2026 isteği).
  ///
  /// KİMDE TRUE: yalnız BENİM gönderdiğim, karşı tarafın okuduğu EN SON
  /// mesajda. Karar burada değil listede verilir ([_sonGorulenIndeks]):
  /// balon kendi başına "sonuncu muyum" sorusunu cevaplayamaz.
  final bool gorulduGoster;

  /// Sohbete özel tema (31 Ağu 2026): KENDİ balonunun zemin/yazı rengi.
  /// Varsayılanlar bugünkü görünümün aynısı (sarı balon, siyah yazı) —
  /// tema seçilmemiş sohbetlerde hiçbir şey değişmez. Bkz. [SohbetTemalari].
  final Color balonRenk;
  final Color balonYazi;

  /// Gönderilemeyen iyimser satırda "tekrar dene" (2 Eyl 2026, Telegram
  /// düzeni). Yalnız `_hata` bayraklı yerel satırda dolu.
  final VoidCallback? tekrarDene;

  const _MesajBaloncugu({
    super.key,
    required this.mesaj,
    required this.benim,
    required this.icerikler,
    this.sil,
    this.yanitla,
    this.duzenle,
    this.sikayet,
    this.tepkiVer,
    this.tekrarDene,
    this.gorulduGoster = false,
    this.gonderiler = const {},
    this.balonRenk = DiziRenkler.sari,
    this.balonYazi = Colors.black,
  });

  /// Kullanıcının bu mesaja verdiği tepki (yoksa null).
  String? get _benimTepkim {
    for (final t in (mesaj['tepkiler'] as List<dynamic>? ?? const [])) {
      if (t is Map && t['benim'] == true) return t['emoji'] as String?;
    }
    return null;
  }

  /// Çift tıklama: kalp. Zaten kalp verdiysen KALDIRIR (aynı jest geri alır —
  /// Instagram/WhatsApp davranışı; kullanıcı yanlışlıkla basınca kilitlenmesin).
  void _kalpDegistir() {
    if (tepkiVer == null) return;
    tepkiVer!(_benimTepkim == '❤️' ? null : '❤️');
  }

  /// Uzun basınca: TEPKİ ŞERİDİ + Yanıtla / Düzenle / Sil (uygun olanlar).
  /// Telegram tarzı menü.
  ///
  /// TEPKİ ŞERİDİ MENÜNÜN ÜSTÜNE EKLENDİ, basılı tutma İŞLEVİ DEĞİŞMEDİ:
  /// bu jest zaten Yanıtla/Düzenle/Sil menüsüne bağlıydı (md. 43'ün notu da
  /// "çakışma önce kontrol edilmeli" diyordu). Menüyü emoji seçiciyle
  /// değiştirmek üç eylemi erişilemez kılardı; WhatsApp/Telegram da tepkileri
  /// aynı menünün başında gösterir.
  void _menuAc(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DiziRenkler.koyuGri,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tepkiVer != null) ...[
              // YATAY KAYDIRILIR: 9 emoji 390 dp'de 27 px taşıyordu (testte
              // yakalandı) ve 320 dp telefonlar daha da dar. Küçültmek yerine
              // kaydırma: dokunma hedefi 44 dp'nin altına düşmesin.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                child: Row(
                  children: [
                    for (final e in mesajTepkiEmojileri)
                      InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          // Aynı emojiye tekrar basmak tepkiyi kaldırır.
                          tepkiVer!(_benimTepkim == e ? null : e);
                        },
                        child: Container(
                          // 44 dp dokunma hedefi: 26 + 2×9 dolgu.
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _benimTepkim == e
                                ? DiziRenkler.sari.withValues(alpha: 0.20)
                                : Colors.transparent,
                          ),
                          // Seçici açılınca hepsi BİR KEZ oynar (canlı durur,
                          // sonra dinlenir) — sonsuz döngü değil.
                          child: TepkiIkonu(e, boyut: 26, acilistaOynat: true),
                        ),
                      ),
                  ],
                ),
              ),
              Divider(color: DiziRenkler.metin12, height: 12),
            ],
            if (yanitla != null)
              ListTile(
                leading: Icon(Icons.reply, color: DiziRenkler.sariMetin),
                title: Text('Yanıtla'.c),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  yanitla!();
                },
              ),
            if (duzenle != null)
              ListTile(
                leading: Icon(Icons.edit, color: DiziRenkler.sariMetin),
                title: Text('Düzenle'.c),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  duzenle!();
                },
              ),
            if (sil != null)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                title: Text(
                  'Mesajı sil'.c,
                  style: const TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  sil!();
                },
              ),
            // DM sikayet yolu. Buraya kadar `sikayetEtSheet` 'mesaj' turunu
            // destekliyordu ama ISTEMCIDE CAGIRAN KOD YOKTU: kullanicinin
            // taciz mesajini bildirmesinin hicbir yolu yoktu, dolayisiyla
            // "sikayet et -> incele -> banla" zinciri kopuktu.
            if (sikayet != null)
              ListTile(
                leading: const Icon(
                  Icons.flag_outlined,
                  color: Colors.orangeAccent,
                ),
                title: Text('Şikayet et'.c),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  sikayet!();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = mesaj;
    final metin = m['metin'] as String?;
    final medya = m['medya'] as String?;
    final video =
        medya != null && (medya.endsWith('.mp4') || medya.endsWith('.webm'));
    final ses = medya != null && sesDosyasi(medya);
    // ALBÜM (2 Eyl 2026): sunucudan `medyalar` (≥2 öğe) ya da iyimser satırda
    // `medya_yerel` (cihaz yolları). Tek öğe eski tek-medya yolundan çizilir.
    final album = <String>[
      for (final y in (m['medyalar'] as List<dynamic>? ?? const []))
        if (y is String) y,
    ];
    final yerel = <String>[
      for (final y in (m['medya_yerel'] as List<dynamic>? ?? const []))
        if (y is String) y,
    ];
    final bekliyor = m['_bekliyor'] == true;
    final gonderimHatasi = m['_hata'] == true;
    final ilerleme = (m['_ilerleme'] as num?)?.toDouble();
    // BELGE (2 Eyl 2026): ayrı kolonlar; medya ile aynı mesajda olmaz.
    final dosya = m['dosya'] as String?;
    final dosyaAd = m['dosya_ad'] as String?;
    final icerikTur = m['icerik_tur'] as String?;
    final icerikId = (m['icerik_id'] as num?)?.toInt();
    final icerik = icerikTur != null
        ? icerikler['$icerikTur:$icerikId'] as Map<String, dynamic>?
        : null;
    // Paylaşılan dizi/film kartının posteri. Adres burada BİR KEZ kuruluyor:
    // WebP başlığı da aynı adrese göre seçildiği için (bkz.
    // `gorsel_basliklari.dart`) iki ayrı `posterUrl()` çağrısı tutmak gerekmez.
    final icerikPosteri = posterUrl(icerik?['poster'] as String?, boyut: 'w92');
    // Paylaşılan gönderi (link değil postun kendisi)
    final gonderiId = (m['yorum_id'] as num?)?.toInt();
    final gonderi = gonderiId != null
        ? gonderiler['$gonderiId'] as Map<String, dynamic>?
        : null;
    final saatKisa = mesajSaati(m);
    final yaziRengi = benim ? balonYazi : DiziRenkler.metin;

    final yanitId = m['yanit_id'];
    final duzenlendi = m['duzenlendi'] == true;
    // ÇIPLAK MESAJ (1 Eyl 2026 isteği: "öncelikle arka planı olmasın"):
    // yalnız paylaşılan bir gönderiden ibaret mesajın baloncuğu ÇİZİLMEZ —
    // kapak doğrudan sohbetin üstünde durur. Mesajda başka bir şey varsa
    // (yazı, medya, içerik kartı, alıntı) baloncuk gerekir: onlar zeminsiz
    // okunmaz.
    final ciplak =
        gonderiId != null &&
        (metin == null || metin.isEmpty) &&
        medya == null &&
        dosya == null &&
        yerel.isEmpty &&
        icerikTur == null &&
        yanitId == null;
    // Alt satır (2 Eyl 2026, Telegram düzeni): SAAT balonun içinde sağ altta,
    // yanında "düzenlendi" / "Görüldü" / bekleme saati / hata. Sürükleyerek
    // açılan saat sütunu kalktı; o jest artık "kaydırarak yanıtla".
    // Alt satırın ("düzenlendi" / "Görüldü") rengi: çıplak mesajda balon
    // yok, yani balonun yazı rengi (sarı üstü siyah) sohbet zemininde
    // kaybolurdu — orada tema metni kullanılır.
    final altYaziRengi = ciplak ? DiziRenkler.metin : yaziRengi;
    // Md. 43 — sunucudan mesajla BİRLİKTE gelen tepkiler (ayrı istek yok).
    final tepkiler = <Map<String, dynamic>>[
      for (final t in (m['tepkiler'] as List<dynamic>? ?? const []))
        if (t is Map<String, dynamic>) t,
    ];

    return Align(
      alignment: benim ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        // Uzun bas → tepki şeridi + Yanıtla / Düzenle / Sil menüsü
        onLongPress:
            (yanitla == null &&
                duzenle == null &&
                sil == null &&
                sikayet == null &&
                tepkiVer == null)
            ? null
            : () => _menuAc(context),
        // Çift tık → kalp (md. 43). Tek tık BOŞ bırakıldı: baloncuğun içinde
        // zaten tıklanabilir öğeler var (içerik kartı, medya, paylaşılan
        // gönderi) ve tek tıkı yakalamak onları çalışmaz hâle getirirdi.
        onDoubleTap: tepkiVer == null ? null : _kalpDegistir,
        // Gönderilemeyen satıra tek dokunuş = tekrar dene (Telegram).
        onTap: gonderimHatasi ? tekrarDene : null,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          // Alt bilgi satırı (düzenlendi/Görüldü) yoksa saatin bıraktığı
          // boşluk kapansın diye alt dolgu üstle eşitlenir. Çıplak mesajda
          // dolgu da YOK: zeminsiz bir kutuda dolgu, kapağı sohbetin
          // ortasından kaydırmaktan başka bir şey yapmaz.
          padding: ciplak
              ? EdgeInsets.zero
              : const EdgeInsets.fromLTRB(12, 8, 12, 6),
          constraints: BoxConstraints(
            // PC'de dev baloncuk olmasın: dar ekranda %75, genişte 420px tavan
            maxWidth: MediaQuery.of(context).size.width > 560
                ? 420
                : MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: ciplak
              ? null
              : BoxDecoration(
                  color: benim ? balonRenk : DiziRenkler.kart,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(14),
                    topRight: const Radius.circular(14),
                    bottomLeft: Radius.circular(benim ? 14 : 3),
                    bottomRight: Radius.circular(benim ? 3 : 14),
                  ),
                ),
          // IntrinsicWidth: baloncuk en geniş çocuğuna (metin/footer) göre küçülür;
          // kısa mesaj ("selam") artık tüm satırı kaplamaz (WhatsApp/Telegram gibi).
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Alıntılanan mesaj önizlemesi (yanıtsa)
                if (yanitId != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 5),
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                    decoration: BoxDecoration(
                      // Alıntı tonu balonun YAZI renginden türer: koyu balonlu
                      // temalarda (mor/pembe) siyah ton kaybolurdu.
                      color: (benim ? balonYazi : DiziRenkler.metin).withValues(
                        alpha: 0.08,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(
                          color: benim
                              ? balonYazi.withValues(alpha: 0.54)
                              : DiziRenkler.sari,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Text(
                      _yanitOnizleme({
                        'metin': m['yanit_metin'],
                        'yanit_medya': m['yanit_medya'],
                        'yanit_dosya_ad': m['yanit_dosya_ad'],
                        'yanit_icerik_tur': m['yanit_icerik_tur'],
                        'yanit_yorum_id': m['yanit_yorum_id'],
                      }),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: yaziRengi),
                    ),
                  ),
                // Sesli mesaj
                if (ses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    // SABİT GENİŞLİK (2 Eyl 2026): ses balonu Telegram'daki gibi
                    // hep aynı ende; dalga da sabit genişlikte çizilir.
                    // (LayoutBuilder tuzağı ses.dart'ta çözüldü.)
                    child: SizedBox(
                      width: 240,
                      child: SesOynatici(
                        key: ValueKey('ses-$medya'), // poll'da state korunsun
                        url: dosyaUrl(medya)!,
                        renk: yaziRengi,
                        dalga: m['ses_dalga'] as String?,
                      ),
                    ),
                  ),
                // ALBÜM (≥2) ya da iyimser yerel önizleme
                if (album.length > 1 || yerel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _AlbumIzgarasi(
                      // Sunucu yolları HAM verilir; ızgara adresi kendisi kurar.
                      urller: yerel.isNotEmpty ? yerel : album,
                      yerel: yerel.isNotEmpty,
                      ilerleme: bekliyor ? ilerleme : null,
                      onTap: yerel.isNotEmpty
                          ? null
                          : (i) => medyaGoster(context, [
                              for (final y in album) dosyaUrl(y)!,
                            ], baslangic: i),
                    ),
                  ),
                // BELGE
                if (dosya != null || m['dosya_ad'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _BelgeKutusu(
                      ad: dosyaAd ?? 'Dosya'.c,
                      boyut: (m['dosya_boyut'] as num?)?.toInt(),
                      tur: m['dosya_tur'] as String?,
                      url: dosya == null ? null : dosyaUrl(dosya),
                      yaziRengi: yaziRengi,
                      benim: benim,
                      ilerleme: bekliyor ? ilerleme : null,
                    ),
                  ),
                // Fotoğraf / GIF / video (tek)
                if (medya != null && !ses && album.length <= 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    // Foto/GIF ve video: dokununca tam ekran görüntüleyici
                    // (yakınlaştırma + video oynatma/sarma)
                    child: InkWell(
                      onTap: () => medyaGoster(context, [dosyaUrl(medya)!]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        // Yer tutucu SAYDAM siyahtı (black26): altındaki
                        // baloncuk sarı ya da açık temada beyaz olunca
                        // white70 ikon kayboluyordu. black54 + tam beyaz ikon
                        // her iki temada ve her iki baloncuk renginde okunur
                        // (beyaz kart üstünde ~4.6:1, sarı üstünde ~6.5:1).
                        child: video
                            ? Container(
                                width: 180,
                                height: 120,
                                color: Colors.black54,
                                child: const Icon(
                                  Icons.play_circle_outline,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: dosyaUrl(medya)!,
                                width: 200,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => Container(
                                  width: 200,
                                  height: 150,
                                  color: Colors.black54,
                                ),
                                errorWidget: (_, _, _) => Container(
                                  width: 200,
                                  height: 150,
                                  color: Colors.black54,
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                // Paylaşılan gönderi: ÇIPLAK önizleme (dokununca Reels'te açılır)
                if (gonderiId != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: PaylasilanGonderi(
                      gonderi: gonderi,
                      onTap: () => context.push('/gonderi/$gonderiId'),
                      yaziRengi: yaziRengi,
                    ),
                  ),
                // Dizi/film kartı
                if (icerikTur != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: InkWell(
                      onTap: () => context.push('/icerik/$icerikTur/$icerikId'),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                width: 38,
                                height: 56,
                                child: icerikPosteri != null
                                    ? CachedNetworkImage(
                                        imageUrl: icerikPosteri,
                                        httpHeaders: gorselBasliklari(
                                          icerikPosteri,
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        color: DiziRenkler.koyuGri,
                                        child: Icon(
                                          Icons.movie,
                                          size: 18,
                                          color: DiziRenkler.metin38,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                icerik?['ad'] as String? ?? '...',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: yaziRengi,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: yaziRengi,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (metin != null && metin.isNotEmpty)
                  Text(
                    metin,
                    style: TextStyle(
                      color: yaziRengi,
                      height: 1.35,
                      // Yalnız emojiden oluşan mesaj 2× boyut (24 Ağu 2026
                      // kullanıcı isteği; WhatsApp/Telegram geleneği).
                      fontSize: yalnizEmoji(metin) ? 28 : null,
                    ),
                  ),
                // Saat GÖRSEL OLARAK GİZLİ (sağdaki sürükleme sütununda).
                // Ekran okuyucu kullanan biri sürükleme yapamaz, o yüzden
                // balonun erişilebilirlik etiketinin SONUNA eklenir:
                // görsel kayıp var, BİLGİ kaybı yok.
                // Md. 43 — tepki rozetleri mesajın ALTINDA. Baloncuklu
                // mesajda baloncuğun içinde, çıplak gönderide kapağın hemen
                // altında kalır (1 Eyl 2026 isteği: "emoji bırakınca altında
                // göstersin emojiyi"). Balonun DIŞINA taşan bir pul olarak
                // denenmedi: baloncuk Align+IntrinsicWidth içinde, sınırı
                // aşan Positioned tıklanamaz olurdu (bilinen hit-test tuzağı).
                if (tepkiler.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final t in tepkiler)
                          _TepkiRozeti(
                            emoji: t['emoji'] as String? ?? '',
                            adet: (t['adet'] as num?)?.toInt() ?? 0,
                            benim: t['benim'] == true,
                            // Çıplak gönderide sarı balon YOK: rozet sohbet
                            // zemininin üstünde durur, kontrast oradan kurulur.
                            koyuZemin: benim && !ciplak,
                            // Kendi tepkine dokunmak kaldırır, başkasınınkine
                            // dokunmak seni de ekler (WhatsApp davranışı).
                            onTap: tepkiVer == null
                                ? null
                                : () => tepkiVer!(
                                    t['benim'] == true
                                        ? null
                                        : t['emoji'] as String?,
                                  ),
                          ),
                      ],
                    ),
                  ),
                // EN ALT SATIR: "düzenlendi" ve "Görüldü".
                //
                // TİK YOK (1 Eyl 2026 isteği: "görüldü işaretleri de olmasın,
                // mesaj görüldüyse mesajın altında görüldü yazsın"). Eskiden
                // WhatsApp tikleri vardı (✓ gönderildi, ✓✓ iletildi, mavi ✓✓
                // okundu); üçünün farkını simgeden okumak öğrenilmesi gereken
                // bir dildi. Yazı bunu kendi söylüyor.
                //
                // YALNIZ SON OKUNAN MESAJDA ([gorulduGoster]): her okunmuş
                // balonun altına "Görüldü" basmak, uzun bir sohbette aynı
                // kelimeyi onlarca kez tekrarlamak olurdu. Instagram DM de
                // yalnız sondakinde gösterir.
                Padding(
                  padding: EdgeInsets.only(top: ciplak ? 3 : 2),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (gonderimHatasi) ...[
                          Icon(
                            Icons.error_outline,
                            size: 13,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 3),
                          // Flexible: dar balonda (kısa metin) satır
                          // taşmasın — widget testi 24 px taşma yakaladı.
                          Flexible(
                            child: Text(
                              'Gönderilemedi · tekrar dene'.c,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ] else ...[
                          if (duzenlendi) ...[
                            Text(
                              'düzenlendi'.c,
                              style: TextStyle(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: altYaziRengi.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                          if (benim && gorulduGoster) ...[
                            Text(
                              'Görüldü'.c,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: altYaziRengi.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                          // Saat balonun İÇİNDE (Telegram). Bekleyen
                          // satırda saat yerine küçük saat ikonu.
                          if (bekliyor)
                            Icon(
                              Icons.schedule,
                              size: 11,
                              color: altYaziRengi.withValues(alpha: 0.55),
                            )
                          else
                            Text(
                              saatKisa,
                              style: TextStyle(
                                fontSize: 10,
                                color: altYaziRengi.withValues(alpha: 0.55),
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
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

/// Albüm ızgarası (2 Eyl 2026, Telegram düzeni): 2 → yan yana, 3 → üstte
/// geniş + altta iki, 4+ → 2 sütun. Genişlik SABİT 240 dp: balon
/// `IntrinsicWidth` içinde, `LayoutBuilder` orada 0 döner; 240, %75 ekran
/// tavanının altında kalır (≥ 320 dp ekran).
///
/// [yerel] true ise [urller] cihaz yollarıdır (iyimser gönderim önizlemesi),
/// değilse sunucu yollarıdır (`/medya/…`, adres ızgarada `dosyaUrl` ile kurulur);
/// [ilerleme] doluysa üstüne yükleme halkası biner. Dokunma yalnız sunucu
/// medyasında (tam ekran görüntüleyici); yerel önizlemede yok.
class _AlbumIzgarasi extends StatelessWidget {
  final List<String> urller;
  final bool yerel;
  final double? ilerleme;
  final void Function(int)? onTap;

  const _AlbumIzgarasi({
    required this.urller,
    required this.yerel,
    this.ilerleme,
    this.onTap,
  });

  static const _genislik = 240.0;
  static const _bosluk = 3.0;

  bool _videoMu(String y) {
    final k = y.split('?').first.toLowerCase();
    return k.endsWith('.mp4') || k.endsWith('.webm') || k.endsWith('.mov');
  }

  Widget _kare(BuildContext context, int i, double en, double boy) {
    final y = urller[i];
    final video = _videoMu(y);
    Widget govde;
    if (video) {
      govde = Container(
        color: Colors.black54,
        child: const Center(
          child: Icon(Icons.play_circle_outline, size: 36, color: Colors.white),
        ),
      );
    } else if (yerel) {
      govde = Image(
        image: yerelGorsel(y, genislik: 480),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => Container(color: Colors.black54),
      );
    } else {
      // Adres BURADA `dosyaUrl` ile kurulur (kendi sunucumuz) — WebP başlık
      // gerileme koruması (gorsel_webp_test) çağrı noktasında bunu arar.
      govde = CachedNetworkImage(
        imageUrl: dosyaUrl(y)!,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(color: Colors.black54),
        errorWidget: (_, _, _) => Container(
          color: Colors.black54,
          child: const Icon(Icons.broken_image_outlined, color: Colors.white),
        ),
      );
    }
    return SizedBox(
      width: en,
      height: boy,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap == null ? null : () => onTap!(i),
          child: govde,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = urller.length.clamp(0, albumAzami);
    final yarim = (_genislik - _bosluk) / 2;
    final satirlar = <Widget>[];
    var i = 0;
    if (n == 3) {
      satirlar.add(_kare(context, 0, _genislik, 150));
      i = 1;
    }
    while (i < n) {
      final sonTek = i == n - 1;
      satirlar.add(
        Row(
          children: [
            _kare(context, i, sonTek ? _genislik : yarim, sonTek ? 150 : yarim),
            if (!sonTek) ...[
              const SizedBox(width: _bosluk),
              _kare(context, i + 1, yarim, yarim),
            ],
          ],
        ),
      );
      i += 2;
    }
    final izgara = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var k = 0; k < satirlar.length; k++) ...[
          if (k > 0) const SizedBox(height: _bosluk),
          satirlar[k],
        ],
      ],
    );
    if (ilerleme == null) return izgara;
    return Stack(
      alignment: Alignment.center,
      children: [
        izgara,
        Positioned.fill(
          child: ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
        ),
        SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            value: ilerleme! <= 0 ? null : ilerleme,
            strokeWidth: 3,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Belge baloncuğu (2 Eyl 2026): renkli tür karosu + ad + boyut. Dokununca
/// imzalı bağlantı tarayıcıda/sistemde açılır — sunucu `attachment` verdiği
/// için indirme olarak gelir; uygulama içinde görüntüleme yok (her tür
/// olabilir, PDF görüntüleyici ayrı iş).
class _BelgeKutusu extends StatelessWidget {
  final String ad;
  final int? boyut;
  final String? tur;
  final String? url;
  final Color yaziRengi;
  final bool benim;
  final double? ilerleme;

  const _BelgeKutusu({
    required this.ad,
    required this.boyut,
    required this.tur,
    required this.url,
    required this.yaziRengi,
    required this.benim,
    this.ilerleme,
  });

  /// Uzantıdan kısa etiket + renk (Telegram'ın karosu). Bilinmeyen → 'DOSYA'.
  static ({String etiket, Color renk}) _karo(String ad) {
    final u = ad.contains('.') ? ad.split('.').last.toLowerCase() : '';
    return switch (u) {
      'pdf' => (etiket: 'PDF', renk: const Color(0xFFE53935)),
      'doc' ||
      'docx' ||
      'odt' ||
      'rtf' => (etiket: 'DOC', renk: const Color(0xFF1E88E5)),
      'xls' ||
      'xlsx' ||
      'csv' ||
      'ods' => (etiket: 'XLS', renk: const Color(0xFF43A047)),
      'ppt' ||
      'pptx' ||
      'odp' => (etiket: 'PPT', renk: const Color(0xFFFB8C00)),
      'zip' ||
      'rar' ||
      '7z' ||
      'gz' ||
      'tar' => (etiket: 'ZIP', renk: const Color(0xFF8E24AA)),
      'txt' ||
      'md' ||
      'srt' ||
      'json' => (etiket: 'TXT', renk: const Color(0xFF546E7A)),
      'apk' => (etiket: 'APK', renk: const Color(0xFF00897B)),
      'mp3' ||
      'wav' ||
      'flac' ||
      'm4a' ||
      'ogg' => (etiket: 'SES', renk: const Color(0xFF6D4C41)),
      _ => (
        etiket: u.isEmpty
            ? 'DOSYA'
            : u.toUpperCase().substring(0, u.length > 4 ? 4 : u.length),
        renk: const Color(0xFF5E6AD2),
      ),
    };
  }

  static String boyutMetni(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024)
      return '${(b / 1024).toStringAsFixed(b < 10240 ? 1 : 0)} KB';
    if (b < 1024 * 1024 * 1024)
      return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  Future<void> _ac(BuildContext context) async {
    final u = url;
    if (u == null) return;
    final ok = await launchUrl(
      Uri.parse(u),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Dosya açılamadı'.c)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = _karo(ad);
    return Semantics(
      button: url != null,
      label: '${'Dosya'.c}: $ad',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: url == null || ilerleme != null ? null : () => _ac(context),
        child: Container(
          width: 240,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (benim ? yaziRengi : DiziRenkler.metin).withValues(
              alpha: 0.08,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: k.renk,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: ilerleme != null
                          ? const SizedBox.shrink()
                          : Text(
                              k.etiket,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                    if (ilerleme != null)
                      SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          value: ilerleme! <= 0 ? null : ilerleme,
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ad,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: yaziRengi,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      boyut == null ? '' : boyutMetni(boyut!),
                      style: TextStyle(
                        fontSize: 11,
                        color: yaziRengi.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (url != null && ilerleme == null)
                Icon(
                  Icons.download_outlined,
                  size: 18,
                  color: yaziRengi.withValues(alpha: 0.6),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sohbette paylaşılan gönderinin ÇIPLAK önizlemesi.
///
/// KULLANICI İSTEĞİ (1 Eyl 2026): *"akışta gezerken sohbette gönderdiği
/// gönderiler güzel gözükmüyor tasarım olarak. Öncelikle arka planı olmasın
/// ve video/görsel yani içeriğin boyutunda olacak — tabii orijinal boyut
/// değil, sohbeti kapatmayacak şekilde. Videoysa kapak resmi gözükecek,
/// yoksa başlangıç sahnesi. Paylaşanın adı içeriğin İÇİNDE sol altta
/// gözükecek beyaz yazıyla."*
///
/// Eski kart üç yerde yanlıştı ve üçü de burada düzeltildi:
///   1. **Zemin**: kapağın altında `black18` bir kutu + 8 dp dolgulu yazı
///      şeridi vardı; medya bir kartın İÇİNDE duruyor gibi görünüyordu.
///      Artık zemin YOK — medya doğrudan sohbetin üstünde durur.
///   2. **Oran**: kapak `AspectRatio(1)` ile KARE'ye kırpılıyordu; dikey bir
///      Reels'in yarısı kesiliyordu. Artık gönderinin KENDİ oranı kullanılır
///      (sunucudan `medya_oran`, bkz. /sohbet yanıtı). Oran bilinmiyorsa
///      dikey varsayılır (4:5) — akış kartıyla aynı varsayım.
///   3. **Video kapağı**: siyah kutu + oynat ikonu çiziliyordu, yani
///      gönderinin neyi gösterdiği belli olmuyordu. Sunucu her videonun ilk
///      karesini `<dosya>.jpg` olarak üretiyor (backend/video_kare.js) ve
///      486/486 videoda dosya MEVCUT (1 Eyl 2026'da sayıldı); kapak artık o.
///      Kare yoksa eski siyah kutuya düşülür — akış hiç boş kalmaz.
class PaylasilanGonderi extends StatelessWidget {
  /// Sunucudan gelen önizleme (`gonderiler['<id>']`). Yoklama henüz
  /// dönmediyse null gelebilir — o zaman iskelet çizilir.
  final Map<String, dynamic>? gonderi;
  final VoidCallback onTap;

  /// Metin-only gönderide (kapağı olmayan post) kullanılacak yazı rengi:
  /// üstünde medya olmadığı için BEYAZ okunmaz, balonun yazı rengi gerekir.
  final Color yaziRengi;

  const PaylasilanGonderi({
    super.key,
    required this.gonderi,
    required this.onTap,
    required this.yaziRengi,
  });

  /// Önizlemenin azami genişliği (dp). Sohbeti "kapatmasın" diye baloncuk
  /// tavanının (420 / ekranın %75'i) belirgin şekilde altında tutulur.
  static const double azamiEn = 220;

  /// Azami yükseklik (dp). 9:16 bir Reels 220 dp genişlikte 391 dp olurdu —
  /// telefonda ekranın yarısı. Tavana çarpınca ORAN KORUNARAK küçültülür.
  static const double azamiBoy = 300;

  /// Oranı bilinmeyen gönderi için varsayım: akış kartıyla aynı 4:5 dikey.
  static const double varsayilanOran = 4 / 5;

  static bool videoMu(String yol) =>
      yol.endsWith('.mp4') || yol.endsWith('.webm');

  /// Video kapak karesinin adresi — `<video>.jpg` (backend/video_kare.js).
  static String kapakAdresi(String kapak) {
    final url = dosyaUrl(kapak)!;
    return videoMu(kapak) ? '$url.jpg' : url;
  }

  /// [azamiEn] × [azamiBoy] kutusuna ORAN BOZULMADAN sığan ölçü.
  @visibleForTesting
  static Size olcu(double? oran) {
    final o = (oran == null || oran <= 0) ? varsayilanOran : oran;
    var en = azamiEn;
    var boy = en / o;
    if (boy > azamiBoy) {
      boy = azamiBoy;
      en = boy * o;
    }
    return Size(en, boy);
  }

  @override
  Widget build(BuildContext context) {
    final kapak = gonderi?['kapak'] as String?;
    final ad = gonderi?['kullanici_adi'] as String?;
    // Kapaksız (yalnız metin) gönderi: üstüne beyaz yazı basacak bir medya
    // yok. Zemin yine YOK — yalnız ince bir çerçeve mesajın bir gönderi
    // olduğunu söyler.
    if (kapak == null) return _metinOnizleme(ad);
    final olculer = olcu((gonderi?['medya_oran'] as num?)?.toDouble());
    final kapakUrl = kapakAdresi(kapak);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: olculer.width,
          height: olculer.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: kapakUrl,
                // Karar TEK YERDE: adres KENDİ sunucumuz olduğu için başlık
                // `null` döner (bkz. gorsel_basliklari.dart) — çağrı noktası
                // yine de sormalı, yoksa TMDB adresi buraya düştüğü gün
                // pazarlık sessizce kaybolur.
                httpHeaders: gorselBasliklari(kapakUrl),
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: Colors.black26),
                // Kare üretilememiş eski video / silinmiş görsel: eski
                // davranışa düş (koyu kutu + oynat ikonu), boş kutu bırakma.
                errorWidget: (_, _, _) => Container(
                  color: Colors.black54,
                  child: Icon(
                    videoMu(kapak)
                        ? Icons.play_circle_outline
                        : Icons.broken_image_outlined,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ),
              // Videoyu KAPAKTAN ayıran tek işaret: küçük oynat pulu. Ortadaki
              // 40 dp'lik dev ikon kapağı kapatıyordu.
              if (videoMu(kapak))
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    Icons.play_circle_fill,
                    size: 22,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                  ),
                ),
              // Adın perdesi: kapağın alt kenarına siyah geçiş. Perdesiz beyaz
              // yazı, açık bir kapakta (kar, gökyüzü) okunmaz olurdu.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 7),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                  child: Text(
                    '@${ad ?? '...'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      // İSTEK: "paylaşanın adı içeriğin içinde sol altta
                      // BEYAZ yazıyla". Tema renginden türetilmez — kapak
                      // her iki temada da koyu bir görseldir.
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
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

  /// Kapaksız gönderi (yalnız yazı): zeminsiz, ince çerçeveli önizleme.
  Widget _metinOnizleme(String? ad) {
    final metin = (gonderi?['metin'] as String?)?.trim();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: azamiEn,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: yaziRengi.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '@${ad ?? '...'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: yaziRengi,
              ),
            ),
            if (metin != null && metin.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                metin,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: yaziRengi.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Baloncuğun altındaki tek tepki rozeti: hareketli emoji + sayı.
///
/// Sayı HER ZAMAN yazılı (yalnız emoji gösterip sayıyı gizlemek, iki kişinin
/// aynı tepkiyi vermesini görünmez kılardı). Kendi tepkin çerçeveli.
class _TepkiRozeti extends StatelessWidget {
  final String emoji;
  final int adet;
  final bool benim;

  /// Baloncuk sarı zeminli mi (kendi mesajın) — kontrast buna göre kurulur.
  final bool koyuZemin;
  final VoidCallback? onTap;

  const _TepkiRozeti({
    required this.emoji,
    required this.adet,
    required this.benim,
    required this.koyuZemin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final metinRengi = koyuZemin ? Colors.black : DiziRenkler.metin;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: (koyuZemin ? Colors.black : DiziRenkler.metin).withValues(
            alpha: 0.08,
          ),
          borderRadius: BorderRadius.circular(12),
          border: benim
              ? Border.all(
                  color: koyuZemin ? Colors.black54 : DiziRenkler.sari,
                  width: 1.2,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Rozet BELİRİNCE bir kez oynar (kullanıcı bildirimi 14 Ağu:
            // "mesaja bırakılan emojiler hareketli değil" — eskiden hiç
            // oynamıyordu). SÜREKLİ dönmez: bir sohbette onlarca rozet olur,
            // hepsi sonsuz dönseydi ekran titrer ve pil yanardı. KENDİ
            // tepkin döner: sohbette en çok birkaç tane olur.
            TepkiIkonu(emoji, boyut: 14, acilistaOynat: true, oynat: benim),
            if (adet > 1) ...[
              const SizedBox(width: 3),
              Text(
                '$adet',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: metinRengi,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sohbette paylaşmak için dizi/film arama sayfası.
