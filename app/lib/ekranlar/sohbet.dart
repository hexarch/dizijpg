import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart'
    show DragStartBehavior, HorizontalDragGestureRecognizer, PointerEvent;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../api.dart';
import '../ceviri.dart';
import '../dosya_oku.dart';
import '../gorsel_basliklari.dart';
import '../gorusme/arama_dugmeleri.dart';
import '../medya_yukle.dart';
import '../push.dart';
import '../sohbet_olay.dart';
import '../tema.dart';
import 'tepki.dart';
import 'medya_goster.dart';
import 'medya_inceleme.dart';
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

/// Gizli saat sütununun genişliği (dp) = SÜRÜKLEME TAVANI.
///
/// KULLANICI İSTEĞİ (5 Ağu 2026): "mesajın dakikası saati mesajın altında
/// yazmasın. ekranı sağa kaydırınca sağ tarafta göster. ama kullanıcı sağa
/// kaydırarak tutmak zorunda olsun, mesaj başına kaydırmayacak."
///
/// Yani WhatsApp/Telegram jesti: SOHBETİN TAMAMI sola ötelenir (görüş alanı
/// sağa kayar), sağ kenarda o mesajın saati belirir; parmak kalkınca yaylanıp
/// geri döner. 64 dp "14:32" (~30 dp) + nefes payı için yeter ve balonun
/// kırpılan sol kenarını en aza indirir.
const double saatSutunuGenisligi = 64;

/// Sol kenarın bu şeridinde BAŞLAYAN sürüklemeler yok sayılır.
///
/// iOS'ta "geri" kenar jesti (CupertinoPageRoute) tam orada yaşıyor ve aynı
/// parmağı iki tanıcı paylaşamaz: kenardan başlayan sürüklemeye hiç girmezsek
/// jest arenasına da katılmayız, geri gitme bozulmaz. Android'de kenar
/// jestini zaten sistem yutar; bu pay orada da zararsız.
const double saatJestKenarPayi = 24;

/// Yalnız EKRANIN İÇİNDEN başlayan yatay sürüklemeleri dinleyen tanıcı.
///
/// [isPointerAllowed] false dönerse tanıcı o parmak için jest arenasına HİÇ
/// katılmaz — kenar jesti (geri) rakipsiz kalır.
class _SaatSuruklemeTanicisi extends HorizontalDragGestureRecognizer {
  _SaatSuruklemeTanicisi({super.debugOwner});

  @override
  bool isPointerAllowed(PointerEvent event) =>
      event.position.dx > saatJestKenarPayi && super.isPointerAllowed(event);
}

/// Mesaj satırı + sağında normalde GÖRÜNMEYEN saat sütunu.
///
/// [kaydirma] 0..[saatSutunuGenisligi]: 0'da saat kırpma dikdörtgeninin
/// DIŞINDA kalır (ağaca hiç eklenmez), tavanda sağ kenara oturur.
///
/// Balon yeniden ÖLÇÜLMEZ, yalnız `Transform` ile ötelenir: saat sütunu
/// yüzünden balonun genişliği/satır kırılımı değişmez, sürükleme boyunca
/// metin yeniden akmaz.
class _ZamanliSatir extends StatelessWidget {
  final Animation<double> kaydirma;
  final String? saat;
  final String? saatAnahtari;
  final Widget child;

  const _ZamanliSatir({
    required this.kaydirma,
    required this.child,
    this.saat,
    this.saatAnahtari,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: kaydirma,
        child: child,
        builder: (context, cocuk) {
          final k = kaydirma.value;
          return Stack(
            children: [
              // Ölçüyü bu çocuk belirler: Stack satır boyu kadar olur.
              Transform.translate(offset: Offset(-k, 0), child: cocuk),
              if (saat != null && saat!.isNotEmpty && k > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Transform.translate(
                        // k=0'da sütun genişliği kadar sağda (kırpılır),
                        // tavanda tam sağ kenarda.
                        offset: Offset(saatSutunuGenisligi - k, 0),
                        child: Opacity(
                          opacity: (k / saatSutunuGenisligi).clamp(0.0, 1.0),
                          child: Text(
                            saat!,
                            key: saatAnahtari == null
                                ? null
                                : Key(saatAnahtari!),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              // Sabit beyaz/siyah DEĞİL: iki temada da okunur.
                              color: DiziRenkler.metin70,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
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

/// Sağ üstteki "Gelen mesaj istekleri" girişi (kullanıcı isteği: yazı olsun).
///
/// Neden ikon değil de YAZI + ikon: kullanıcı açıkça "yazısı olsun" dedi.
/// Genişlik 168 dp ile sınırlı ve metin İKİ SATIRA sarabiliyor — Almanca
/// "Eingegangene Nachrichtenanfragen" gibi uzun çeviriler 360 dp'de başlığı
/// taşırmasın diye. Dokunma alanı en az 44 dp yüksekliğinde.
class MesajIstekleriDugmesi extends StatelessWidget {
  final int okunmamisIstek;
  final VoidCallback onTap;
  const MesajIstekleriDugmesi({
    super.key,
    required this.okunmamisIstek,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, maxWidth: 168),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mark_email_unread_outlined,
                size: 18,
                color: DiziRenkler.sariMetin,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Gelen mesaj istekleri'.c,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: DiziRenkler.sariMetin,
                  ),
                ),
              ),
              // Rozet KIRMIZI değil marka sarısı: istek kutusu düşük öncelikli,
              // alarm değil. Rozet olmasaydı yeni istek hiçbir yerde
              // görünmezdi (istekler ana listeden çıkarıldı).
              if (okunmamisIstek > 0) ...[
                const SizedBox(width: 6),
                OkunmamisRozeti(adet: okunmamisIstek),
              ],
            ],
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
      if (sessiz &&
          _hata == null &&
          _sohbetSatirlariAyni(_istekler, istekler)) {
        return;
      }
      setState(() {
        _istekler = istekler;
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
    } else if (_istekler!.isEmpty) {
      govde = BosDurum(
        ikon: Icons.mark_email_unread_outlined,
        baslik: 'Mesaj isteğin yok'.c,
        ipucu: 'Takip etmediğin kişilerden gelen mesajlar burada görünür.'.c,
      );
    } else {
      govde = RefreshIndicator(
        color: DiziRenkler.sari,
        onRefresh: () => _yukle(),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: _istekler!.length,
          itemBuilder: (context, i) => SohbetSatiri(
            sohbet: _istekler![i] as Map<String, dynamic>,
            onTap: () async {
              await context.push('/sohbet/${_istekler![i]['partner']}');
              // Cevap verildiyse ya da kişi takip edildiyse sohbet ana listeye
              // geçer ve buradan DÜŞER — o yüzden dönüşte yeniden çekilir.
              _yukle();
            },
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Gelen mesaj istekleri'.c)),
      // Sohbet listesiyle aynı kolon: masaüstünde kullanıcılar sola yapışmasın.
      body: OrtaKolon(azami: masaustuKolonGenisligi, cocuk: govde),
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

  const SohbetEkrani({super.key, required this.kullaniciAdi});

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
  late final AnimationController _saatKaydirici;
  // Sesli mesaj kaydı
  // Web'de mikrofon gizli; kaydediciyi hiç kurma ki eklenti kanalı
  // MissingPluginException gürültüsü üretmesin (hata günlüğü #8-16).
  final AudioRecorder? _kaydedici = kIsWeb ? null : AudioRecorder();
  bool _kaydediyor = false;
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
        // Görünürlük bayrağı yanlış olsa bile damgayı silme — klavye
        // inactive / push yığını 2 sn sonra acik:false atıyordu.
        if (!_sohbetGorunur) return;
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
    _saatKaydirici = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      lowerBound: 0,
      upperBound: saatSutunuGenisligi,
    );
    _yukle(ilk: true);
    _metin.addListener(_yaziyorBildir);
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
    _metin.dispose();
    _kaydirma.dispose();
    _saatKaydirici.dispose();
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

  // ---- Saat sütunu jesti ----
  // Yatay tanıcı DİKEY kaydırmayı yutmaz: `HorizontalDragGestureRecognizer`
  // yalnız yatay eşiği aşan parmakta arenayı kazanır, dikey harekette
  // ListView'in dikey tanıcısı kazanır (jest arenası ekseni ayırır).

  void _saatSuruklemeBasla(DragStartDetails _) => _saatKaydirici.stop();

  void _saatSurukle(DragUpdateDetails d) {
    // Parmak SOLA gidince (dx < 0) görüş alanı SAĞA kayar ve saat sütunu
    // açılır. clamp: kullanıcı ekranı sütun genişliğinden fazla çekemez.
    final yeni = (_saatKaydirici.value - d.delta.dx).clamp(
      0.0,
      saatSutunuGenisligi,
    );
    if (yeni != _saatKaydirici.value) _saatKaydirici.value = yeni;
  }

  void _saatBirak([DragEndDetails? _]) {
    if (_saatKaydirici.value == 0) return;
    _saatKaydirici.animateBack(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  // ---- Sesli mesaj kaydı ----
  Future<void> _kayitBasla() async {
    try {
      if (_kaydedici == null) return;
      if (!await _kaydedici.hasPermission()) return;
      final dizin = await getTemporaryDirectory();
      final yol =
          '${dizin.path}/ses_${DateTime.now().millisecondsSinceEpoch}.ogg';
      await _kaydedici.start(
        const RecordConfig(encoder: AudioEncoder.opus),
        path: yol,
      );
      _kayitYolu = yol;
      if (!mounted) return;
      setState(() {
        _kaydediyor = true;
        _kayitSn = 0;
        _seviyeler.clear();
      });
      _durumHeartbeat('kayit');
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

  void _sonaKaydir() {
    // Görsel/video baloncukları sonradan yüklenip yüksekliği değiştirdiğinden
    // birkaç kez dener; her seferinde gerçek en-alta sabitler.
    for (final ms in const [0, 120, 400]) {
      Future.delayed(Duration(milliseconds: ms), () {
        if (mounted && _kaydirma.hasClients) {
          _kaydirma.jumpTo(_kaydirma.position.maxScrollExtent);
        }
      });
    }
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
        birlesik = gelen;
        yeniGeldi = gelen.length != _mesajlar.length;
      }

      final parmak = _mesajParmakIzi(birlesik, durum, partner);
      final eski = _mesajParmakIzi(_mesajlar, _karsiDurum, _partner);
      if (!ilk && parmak == eski && _hata == null) return;

      final altaYakinDi =
          !_kaydirma.hasClients ||
          _kaydirma.position.pixels >= _kaydirma.position.maxScrollExtent - 250;
      setState(() {
        _mesajlar = birlesik;
        _icerikler.addAll(icerikler);
        _gonderiler.addAll(gonderiler);
        _karsiDurum = durum;
        if (partner != null) _partner = partner;
        _yuklendi = true;
        _hata = null;
      });
      if (ilk || (yeniGeldi && altaYakinDi)) _sonaKaydir();
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

  Future<void> _gonder({
    String? metin,
    String? medya,
    String? sesDalga,
    String? icerikTur,
    int? icerikId,
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
    setState(() => _gonderiliyor = true);
    try {
      await Api.post('/mesajlar', {
        'kullanici_adi': widget.kullaniciAdi,
        if (metin != null && metin.isNotEmpty) 'metin': metin,
        if (medya != null) 'medya': medya,
        if (sesDalga != null) 'ses_dalga': sesDalga,
        if (icerikVar) 'icerik_tur': tur,
        if (icerikVar && kimlik != null) 'icerik_id': kimlik,
        if (_yanitlanan != null)
          'yanit_id': (_yanitlanan!['id'] as num).toInt(),
      });
      _metin.clear();
      _durumDurdur();
      setState(() {
        _yanitlanan = null;
        _bekleyenIcerik = null;
      });
      SohbetOlaylari.mesajGeldi(widget.kullaniciAdi);
      await _yukle();
      _sonaKaydir();
    } catch (e) {
      if (!mounted) return;
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
  /// yükle → mesaj olarak gönder.
  ///
  /// TEK DOSYA (`azami: 1`) — KEYFİ DEĞİL, VERİ MODELİ BÖYLE: `mesajlar.medya`
  /// kolonu **TEXT**'tir (`backend/sema.sql:209`), `yorumlar.medya` gibi
  /// `TEXT[]` değil; `POST /mesajlar` gövdesinde `medya` tek bir string bekler
  /// ve tek satır INSERT eder (`server.js:4528, 4539, 4596`). Çoklu seçim
  /// açmak kullanıcıya 5 fotoğraf seçtirip 4'ünü sessizce çöpe atmak olurdu.
  /// (Sunucuyu diziye çevirmek ayrı bir iş: kolon + okuma uçları + baloncuk
  /// çizimi + eski mesajların göçü.)
  ///
  /// Seçim sisteme (Android Fotoğraf Seçici) devredildiği için geniş galeri
  /// izni İSTENMEZ — `medya_inceleme.dart` başındaki Play reddi notu.
  Future<void> _fotoGonder() async {
    final secim = await medyaSec(context, azami: 1);
    if (secim.isEmpty || !mounted) return;
    setState(() => _ekYukleniyor = true);
    MedyaYuklemeSonuc sonuc;
    try {
      // Sınır ARTIK ORTAK sabitten (100 MB = sunucunun `/medya` sınırı).
      // Buradaki eski 30 MB, sunucu kabul edecekken 40-70 MB'lık videoları
      // istemcide sebepsiz reddediyordu; 20 MB üstü video zaten inceleme
      // ekranında cihazda sıkıştırılıyor (`videoHazirla`).
      sonuc = await medyalariYukle(secim, toplamAzamiBayt: null);
    } finally {
      if (mounted) setState(() => _ekYukleniyor = false);
    }
    if (!mounted) return;
    final bildirim = sonuc.bildirim;
    if (bildirim != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(bildirim)));
      return; // yüklenmeyen medyayla mesaj göndermeyiz
    }
    // Yazılmış metin de gitsin: eskiden fotoğraf/video eklenince
    // kutudaki yazı sessizce kayboluyordu.
    await _gonder(
      medya: sonuc.yuklenen.first['yol'] as String,
      metin: _metin.text.trim(),
    );
  }

  /// Dizi/film arayıp kart olarak gönder.
  Future<void> _icerikPaylas() async {
    final secilen = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DiziRenkler.koyuGri,
      builder: (_) => const _IcerikSecSheet(),
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

    return Scaffold(
      appBar: AppBar(
        // Tema title 22 px; alt satır (yazıyor) 56 px araç çubuğunda
        // kırpılıyordu. 17+12 bu yükseklikte sığar, büyük yazı ölçeğinde de.
        toolbarHeight: 64,
        title: InkWell(
          onTap: () => context.push('/kullanici/${widget.kullaniciAdi}'),
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
                  fontSize: 17,
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
                    fontSize: 12,
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
                    : RawGestureDetector(
                        // Saat sütunu jesti: LİSTENİN TAMAMI kayar (mesaj
                        // başına ayrı sürükleme YOK). Kenar payı geri
                        // jestini korur, dikey kaydırma arenada kazanır.
                        gestures: {
                          _SaatSuruklemeTanicisi:
                              GestureRecognizerFactoryWithHandlers<
                                _SaatSuruklemeTanicisi
                              >(
                                () => _SaatSuruklemeTanicisi(debugOwner: this),
                                (t) => t
                                  // .down: jesti kazandiran ilk hareket de
                                  // rapor edilir. Varsayilan .start'ta o
                                  // hareket YUTULUYOR ve balonun ustunde
                                  // baslayan surukleme hic acilmiyordu.
                                  ..dragStartBehavior = DragStartBehavior.down
                                  ..onStart = _saatSuruklemeBasla
                                  ..onUpdate = _saatSurukle
                                  ..onEnd = _saatBirak
                                  ..onCancel = _saatBirak,
                              ),
                        },
                        child: ListView.builder(
                          controller: _kaydirma,
                          padding: const EdgeInsets.all(12),
                          itemCount: _mesajlar.length,
                          itemBuilder: (context, i) {
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
                                (m['metin'] as String?)?.isNotEmpty == true &&
                                m['medya'] == null &&
                                m['icerik_tur'] == null;
                            final baloncuk = _MesajBaloncugu(
                              // Yoklama listeyi yenilerken baloncuk id ile
                              // eşleşsin: medya yeniden yüklenip kaymasın.
                              key: ValueKey(m['id'] ?? 'm$i'),
                              mesaj: m,
                              benim: benimMi,
                              icerikler: _icerikler,
                              gonderiler: _gonderiler,
                              yanitla: m['id'] != null
                                  ? () => _yanitBaslat(m)
                                  : null,
                              sil: benimMi && m['id'] != null
                                  ? () => _mesajSil((m['id'] as num).toInt())
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
                            );
                            // Saat balonun ALTINDA değil, satırın SAĞINDAKİ
                            // gizli sütunda; sürükleme boyunca açılır.
                            final satir = _ZamanliSatir(
                              kaydirma: _saatKaydirici,
                              saat: mesajSaati(m),
                              saatAnahtari: 'mesaj-saat-${m['id'] ?? i}',
                              child: baloncuk,
                            );
                            if (gun == oncekiGun || gun.isEmpty) return satir;
                            // Tarih ayracı: gün değişince ortada küçük rozet
                            final p = gun.split('-');
                            final etiket = p.length == 3
                                ? '${p[2]}.${p[1]}.${p[0]}'
                                : gun;
                            return Column(
                              children: [
                                // Ayraç da SATIRLARLA BİRLİKTE kayar (saatsiz),
                                // yoksa sürüklemede yerinde çakılı kalırdı.
                                _ZamanliSatir(
                                  kaydirma: _saatKaydirici,
                                  child: Center(
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: DiziRenkler.koyuGri,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        etiket,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: DiziRenkler.metin54,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                satir,
                              ],
                            );
                          },
                        ),
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
                  child: _kaydediyor
                      ? _kayitCubugu()
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Dört eylem de kutunun İÇİNDE (suffixIcon):
                            // metin alanı boydan boya, ikonlar küçük.
                            Expanded(
                              child: TextField(
                                controller: _metin,
                                minLines: 1,
                                maxLines: 4,
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
                                decoration: InputDecoration(
                                  hintText: 'Mesajını yaz...'.c,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.fromLTRB(
                                    14,
                                    10,
                                    4,
                                    10,
                                  ),
                                  suffixIconConstraints: const BoxConstraints(
                                    minWidth: 0,
                                    minHeight: 0,
                                  ),
                                  suffixIcon: Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _kutuIkonu(
                                          ipucu: 'Fotoğraf / video ekle'.c,
                                          ikon: Icons
                                              .add_photo_alternate_outlined,
                                          kapali:
                                              _ekYukleniyor ||
                                              _duzenlenenId != null,
                                          yukleniyor: _ekYukleniyor,
                                          onTap: _fotoGonder,
                                        ),
                                        _kutuIkonu(
                                          ipucu: 'İçerik paylaş'.c,
                                          ikon: Icons.local_movies_outlined,
                                          kapali: _duzenlenenId != null,
                                          onTap: _icerikPaylas,
                                        ),
                                        if (!kIsWeb)
                                          _kutuIkonu(
                                            ipucu: 'Sesli mesaj'.c,
                                            ikon: Icons.mic_none,
                                            kapali:
                                                _ekYukleniyor ||
                                                _duzenlenenId != null,
                                            onTap: _kayitBasla,
                                          ),
                                        _kutuIkonu(
                                          ipucu: 'Gönder'.c,
                                          ikon: Icons.send,
                                          kapali:
                                              _gonderiliyor || _ekYukleniyor,
                                          vurgulu: true,
                                          onTap: () => _gonder(
                                            metin: _metin.text.trim(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
      ),
    );
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
      style: TextStyle(
        fontSize: 12,
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

/// Metinsiz mesajın (ses/foto/video/içerik) kısa özeti: ikon + söz.
/// Hem sohbet listesindeki son mesaj satırında hem alıntı kutusunda kullanılır.
({IconData? ikon, String metin}) mesajOzeti(Map<String, dynamic> m) {
  final metin = (m['metin'] as String?)?.trim();
  if (metin != null && metin.isNotEmpty) return (ikon: null, metin: metin);
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
    this.gonderiler = const {},
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
    final yaziRengi = benim ? Colors.black : DiziRenkler.metin;

    final yanitId = m['yanit_id'];
    final duzenlendi = m['duzenlendi'] == true;
    // Balonun altında yalnız "düzenlendi" + okundu tiki kalır; saat gitti.
    final altBilgi = duzenlendi || benim;
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
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          // Alt bilgi satırı (düzenlendi/tik) yoksa saatin bıraktığı boşluk
          // kapansın diye alt dolgu üstle eşitlenir.
          padding: EdgeInsets.fromLTRB(12, 8, 12, altBilgi ? 6 : 8),
          constraints: BoxConstraints(
            // PC'de dev baloncuk olmasın: dar ekranda %75, genişte 420px tavan
            maxWidth: MediaQuery.of(context).size.width > 560
                ? 420
                : MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: benim ? DiziRenkler.sari : DiziRenkler.kart,
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
                      color: (benim ? Colors.black : DiziRenkler.metin)
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(
                          color: benim ? Colors.black54 : DiziRenkler.sari,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Text(
                      _yanitOnizleme({
                        'metin': m['yanit_metin'],
                        'yanit_medya': m['yanit_medya'],
                        'yanit_icerik_tur': m['yanit_icerik_tur'],
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
                    child: SesOynatici(
                      key: ValueKey('ses-$medya'), // poll'da state korunsun
                      url: dosyaUrl(medya)!,
                      renk: yaziRengi,
                      dalga: m['ses_dalga'] as String?,
                    ),
                  ),
                // Fotoğraf / GIF / video
                if (medya != null && !ses)
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
                // Paylaşılan gönderi kartı: dokununca Reels'te açılır
                if (gonderiId != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: InkWell(
                      onTap: () => context.push('/gonderi/$gonderiId'),
                      child: Container(
                        width: 210,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (gonderi?['kapak'] != null)
                              AspectRatio(
                                aspectRatio: 1,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl: dosyaUrl(
                                        gonderi!['kapak'] as String?,
                                      )!,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, _, _) =>
                                          Container(color: Colors.black26),
                                    ),
                                    if ((gonderi['kapak'] as String).endsWith(
                                          '.mp4',
                                        ) ||
                                        (gonderi['kapak'] as String).endsWith(
                                          '.webm',
                                        ))
                                      const Center(
                                        child: Icon(
                                          Icons.play_circle_outline,
                                          size: 40,
                                          color: Colors.white,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '@${gonderi?['kullanici_adi'] ?? '...'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: yaziRengi,
                                    ),
                                  ),
                                  if ((gonderi?['metin'] as String?)
                                          ?.isNotEmpty ==
                                      true) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      gonderi!['metin'] as String,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: yaziRengi,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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
                  Text(metin, style: TextStyle(color: yaziRengi, height: 1.35)),
                // Saat GÖRSEL OLARAK GİZLİ (sağdaki sürükleme sütununda).
                // Ekran okuyucu kullanan biri sürükleme yapamaz, o yüzden
                // balonun erişilebilirlik etiketinin SONUNA eklenir:
                // görsel kayıp var, BİLGİ kaybı yok.
                Semantics(label: saatKisa, child: const SizedBox.shrink()),
                if (altBilgi)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (duzenlendi) ...[
                          Text(
                            'düzenlendi'.c,
                            style: TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: yaziRengi.withValues(alpha: 0.5),
                            ),
                          ),
                          if (benim) const SizedBox(width: 5),
                        ],
                        if (benim)
                          // WhatsApp geleneği: ✓ gönderildi, ✓✓ soluk
                          // iletildi (push cihaza ulaştı), ✓✓ MAVİ okundu.
                          Icon(
                            m['okundu'] == true || m['iletildi'] == true
                                ? Icons.done_all
                                : Icons.done,
                            size: 13,
                            color: m['okundu'] == true
                                ? const Color(0xFF1976D2)
                                : yaziRengi.withValues(alpha: 0.55),
                          ),
                      ],
                    ),
                  ),
                // Md. 43 — tepki rozetleri baloncuğun İÇİNDE, en altta.
                // Dışında (üste taşan bir pul olarak) denenmedi: baloncuk
                // Align+IntrinsicWidth içinde, taşan Positioned tıklanamaz
                // olurdu (projedeki bilinen hit-test tuzağı).
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
                            koyuZemin: benim,
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
              ],
            ),
          ),
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
class _IcerikSecSheet extends StatefulWidget {
  const _IcerikSecSheet();

  @override
  State<_IcerikSecSheet> createState() => _IcerikSecSheetState();
}

class _IcerikSecSheetState extends State<_IcerikSecSheet> {
  final _arama = TextEditingController();
  Timer? _geciktirici;
  List<dynamic> _sonuclar = [];

  @override
  void dispose() {
    _arama.dispose();
    _geciktirici?.cancel();
    super.dispose();
  }

  void _degisti(String q) {
    _geciktirici?.cancel();
    _geciktirici = Timer(const Duration(milliseconds: 400), () => _ara(q));
  }

  Future<void> _ara(String q) async {
    if (q.trim().length < 2) return;
    try {
      final d = await Api.get(
        '/tmdb/search/multi?query=${Uri.encodeComponent(q.trim())}',
      );
      if (!mounted) return;
      setState(() {
        _sonuclar = (d['results'] as List<dynamic>)
            .where(
              (r) =>
                  (r['media_type'] == 'tv' || r['media_type'] == 'movie') &&
                  r['poster_path'] != null,
            )
            .toList();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: _arama,
              autofocus: true,
              onChanged: _degisti,
              decoration: InputDecoration(
                hintText: 'Dizi, film veya kişi ara...'.c,
                prefixIcon: Icon(Icons.search, color: DiziRenkler.metin),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _sonuclar.length,
              itemBuilder: (context, i) {
                final r = _sonuclar[i] as Map<String, dynamic>;
                final poster = posterUrl(
                  r['poster_path'] as String?,
                  boyut: 'w92',
                );
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 34,
                      height: 50,
                      child: poster != null
                          ? CachedNetworkImage(
                              imageUrl: poster,
                              httpHeaders: gorselBasliklari(poster),
                              fit: BoxFit.cover,
                            )
                          : Container(color: DiziRenkler.kart),
                    ),
                  ),
                  title: Text(
                    (r['name'] ?? r['title'] ?? '?') as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    r['media_type'] == 'tv' ? 'Dizi'.c : 'Film'.c,
                    style: TextStyle(fontSize: 11, color: DiziRenkler.metin38),
                  ),
                  onTap: () => Navigator.pop(context, r),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
