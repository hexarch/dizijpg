import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show listEquals, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../altyazi.dart';
import '../api.dart';
import '../ceviri.dart';
import '../gonderi_olcu.dart';
import '../gorsel_basliklari.dart';
import '../medya_yukle.dart';
import '../reels_ceviri.dart';
import '../sira_tercihi.dart';
import '../spoiler_tercihi.dart';
import '../tarih.dart';
import '../tema.dart';
import '../veri_tasarrufu.dart';
import '../video_konum.dart';
import '../video_kova.dart';
import 'akis.dart' show AkisGorunumSecici, AkisGorunumu, AkisKarti;
import 'begenenler.dart';
import 'etiket.dart';
import 'gif_sec.dart';
import 'giris_istem.dart';
import 'medya_goster.dart';
import 'medya_inceleme.dart';
import 'ortak.dart';
import 'paylas.dart';

/// Keşfet sayfalama defteri (saf mantık — ekrandan ayrı ki test edilebilsin).
///
/// Sunucu iki tur döndürür: önce görülmemişler, havuz tükenince `tekrar: true`
/// ile baştan (görülenler dahil). Her yanıtta bir sonraki sayfanın `imlec`i
/// gelir; `imlec: null` → gerçekten bitti, bir daha istenmez. Sonsuz istek
/// döngüsü böyle engellenir.
class KesfetSayfalama {
  /// Emniyet tavanı: sunucu zaten bitişi bildiriyor, bu yalnız bellek sigortası.
  static const tavan = 2000;

  String? imlec;
  bool bitti = false;

  /// "Daha önce gördüklerin" turunun başladığı indeks (yoksa null).
  int? tekrarBasi;

  void sifirla() {
    imlec = null;
    bitti = false;
    tekrarBasi = null;
  }

  /// Sıradaki sayfa istenebilir mi? İlk sayfa (imlec null, bitti false) hariç.
  bool get devamVar => !bitti && imlec != null;

  /// Gelen sayfayı defterle: [oncekiUzunluk] sayfa eklenmeden önceki liste
  /// uzunluğu, [gelenAdet] bu sayfada eklenen gönderi sayısı.
  void yanitIsle(
    Map<String, dynamic> d, {
    required int oncekiUzunluk,
    required int gelenAdet,
  }) {
    if (d['tekrar'] == true && tekrarBasi == null && gelenAdet > 0) {
      tekrarBasi = oncekiUzunluk;
    }
    imlec = d['imlec'] as String?;
    bitti =
        imlec == null || gelenAdet == 0 || oncekiUzunluk + gelenAdet >= tavan;
  }
}

/// "Hepsini gördün" ayracı: buradan sonrası daha önce gösterilenlerin tekrarı.
class TekrarAyraci extends StatelessWidget {
  const TekrarAyraci({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
    child: Row(
      children: [
        // Bu ayraç TEMA zemininin üstünde durur (Reels değil) — sabit beyaz
        // tonlar açık temada beyaz-üstüne-beyaz olurdu. const de kaldırıldı:
        // const alt ağaç tema değişiminde eski rengi taşırdı.
        Expanded(child: Divider(color: DiziRenkler.metin24)),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'Hepsini gördün, baştan gösteriyoruz'.c,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: DiziRenkler.metin70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Expanded(child: Divider(color: DiziRenkler.metin24)),
      ],
    ),
  );
}

/// Keşfet (Reels tarzı): akış öncelikleriyle gelen postlar. YALNIZ MEDYALI
/// gönderiler gelir (video ya da fotoğraf) — yalnız-yazı gönderileri sunucuda
/// sert filtreyle elenir (server.js KESFET_MEDYALI, 3 Ağu 2026). Akışta ise
/// kalırlar; oradan Reels açılınca yazı gönderisi hâlâ çizilir, bu yüzden
/// _ReelSayfa'nın yazı yolu CANLI KOD'dur, silinmemelidir.
/// Izgaradan birine dokununca tam ekran dikey kaydırmalı görünüm açılır.
/// Keşfet karoları arasındaki boşluk (yatay = dikey) ve karo en/boy oranı.
/// Tek yerde: iskelet ızgara ile gerçek ızgara AYNI ölçüyü kullanmalı, yoksa
/// içerik gelince sayfa zıplar (`ui-ux-pro-max` → Layout / "Content Jumping",
/// severity High: *"Do: Reserve space for async content"*).
const double kesfetKaroBoslugu = 2;
const double kesfetKaroOrani = 0.66;

/// Keşfet ızgarasının sütun sayısı: ÖLÇÜLEN kolon genişliğinden türer.
///
/// Sabit "geniş ekranda 5 sütun" kuralı kaldırıldı: ızgara artık ekranın
/// tamamına değil [masaustuKolonGenisligi] kolonuna sığıyor ve 5 sütun orada
/// sıkışırdı. Hesap, poster ızgaralarının kanıtlanmış kalıbıyla AYNI
/// fonksiyondan gelir ([posterSutunlari], ortak.dart) — kalıp yeniden
/// icat edilmedi: hedef kart genişliği [posterKartHedefGenisligi] (168) ve
/// alt sınır 3, yani 360-430 dp telefonlarda sonuç bugünküyle BİREBİR aynı
/// (3 sütun).
int kesfetSutunlari(double kolonGenisligi) => posterSutunlari(
  // Izgaranın kendi dolgusu (her iki yandan) düşülür: karo genişliği
  // gerçekten kullanılabilir alandan hesaplansın.
  kolonGenisligi - kesfetKaroBoslugu * 2,
  bosluk: kesfetKaroBoslugu,
);

/// Ekranda görünen video karolarından hangilerinin oynayacağı.
///
/// KULLANICI İSTEĞİ (16 Ağu 2026): "her zaman ilk video oynuyor, ekrandaki
/// en çok izlenen video oynamalı". Eski kural görünürlük sırasının ilk
/// [esZamanli] elemanıydı — ızgara soldan sağa kurulduğu için bu daima
/// sol üstteki videoydu. Yeni kural: görünenler arasında izlenme sayısı
/// en yüksek olanlar. Eşitlikte küçük indeks (daha yukarıdaki) kazanır.
@visibleForTesting
List<int> kesfetOynayanlar({
  required Iterable<int> gorunur,
  required int Function(int i) izlenme,
  int esZamanli = 2,
}) {
  final adaylar = gorunur.toList();
  adaylar.sort((a, b) {
    final fark = izlenme(b).compareTo(izlenme(a));
    if (fark != 0) return fark;
    return a.compareTo(b);
  });
  if (adaylar.length <= esZamanli) return adaylar;
  return adaylar.sublist(0, esZamanli);
}

class KesfetAkisEkrani extends StatefulWidget {
  const KesfetAkisEkrani({super.key});

  @override
  State<KesfetAkisEkrani> createState() => _KesfetAkisEkraniState();
}

class _KesfetAkisEkraniState extends State<KesfetAkisEkrani>
    with AutomaticKeepAliveClientMixin {
  /// Gönderiler. Sayfalar SONUNA eklenir, asla araya girmez → indeksler
  /// kaymaz (Reels'in açık listesi ve video görünürlük indeksleri bozulmaz).
  List<dynamic>? _liste;
  Map<String, dynamic> _icerikler = {};
  String? _hata;

  final _kaydirma = ScrollController();
  final _sayfalama = KesfetSayfalama();
  bool _yukluyor = false;

  /// Ekranda görünen VİDEOLU karolar (küme; sıra oynatmayı belirlemez).
  final List<int> _gorunurVideolar = [];

  /// Aynı anda oynayan karo sayısı. İkiden fazlası hem veri hem pil yakar.
  static const _esZamanliOynatma = 2;

  @override
  bool get wantKeepAlive => true;

  bool _videoluMu(int i) =>
      (_liste?[i] as Map<String, dynamic>?)?['videolu'] == true;

  int _izlenme(int i) =>
      ((_liste?[i] as Map<String, dynamic>?)?['goruntulenme'] as num?)
          ?.toInt() ??
      0;

  /// Karo görünürlüğü değişince oynayacak ikiliyi yeniden belirler.
  void _gorunurlukDegisti(int i, bool gorunur) {
    if (!_videoluMu(i)) return;
    final vardi = _gorunurVideolar.contains(i);
    if (gorunur == vardi) return;
    final oncekiIkili = kesfetOynayanlar(
      gorunur: _gorunurVideolar,
      izlenme: _izlenme,
      esZamanli: _esZamanliOynatma,
    );
    if (gorunur) {
      _gorunurVideolar.add(i);
    } else {
      _gorunurVideolar.remove(i);
    }
    // Kaydırırken görünürlük sürekli değişir; YALNIZ oynayan ikili
    // değiştiyse yeniden çiz. Aksi halde her olayda tüm ızgara yeniden
    // kurulur ve kaydırma takılır.
    final yeniIkili = kesfetOynayanlar(
      gorunur: _gorunurVideolar,
      izlenme: _izlenme,
      esZamanli: _esZamanliOynatma,
    );
    if (!listEquals(oncekiIkili, yeniIkili)) setState(() {});
  }

  /// Ekranda görünenler içinde izlenmesi en yüksek videolar oynar.
  bool _oynasinMi(int i) => kesfetOynayanlar(
    gorunur: _gorunurVideolar,
    izlenme: _izlenme,
    esZamanli: _esZamanliOynatma,
  ).contains(i);

  @override
  void initState() {
    super.initState();
    _yukle();
    _kaydirma.addListener(() {
      // Dibe 600px kala sıradaki sayfayı çek: kullanıcı beklemesin.
      if (_kaydirma.hasClients &&
          _kaydirma.position.pixels >=
              _kaydirma.position.maxScrollExtent - 600) {
        _sonrakiSayfa();
      }
    });
  }

  @override
  void dispose() {
    _kaydirma.dispose();
    super.dispose();
  }

  /// İlk yükleme + aşağı çekince yenileme: her şey baştan kurulur.
  Future<void> _yukle() async {
    if (_yukluyor) return;
    setState(() {
      _hata = null;
      _yukluyor = true;
    });
    try {
      final sr = SiraTercihi.sorgu(SiraTercihi.anahtarKesfet);
      final d =
          await Api.get(sr.isEmpty ? '/kesfet-akis' : '/kesfet-akis?$sr')
              as Map<String, dynamic>;
      if (!mounted) return;
      final gelen = d['akis'] as List<dynamic>? ?? [];
      setState(() {
        // YENİ liste/harita nesnesi: açık duran Reels eski listesiyle
        // tutarlı kalsın (aynı nesneyi temizlemek onu bozardı).
        _liste = List<dynamic>.from(gelen);
        _icerikler = Map<String, dynamic>.from(
          d['icerikler'] as Map<String, dynamic>? ?? {},
        );
        _sayfalama.sifirla();
        _sayfalama.yanitIsle(d, oncekiUzunluk: 0, gelenAdet: gelen.length);
        _gorunurVideolar.clear();
        _yukluyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yukluyor = false;
        _hata = e.toString();
      });
    }
  }

  /// Sonraki sayfa. Sunucu `imlec: null` derse havuz gerçekten bitmiştir —
  /// bir daha istenmez (sonsuz istek döngüsü olmaz).
  Future<void> _sonrakiSayfa() async {
    if (_yukluyor || _liste == null || !_sayfalama.devamVar) return;
    setState(() => _yukluyor = true);
    try {
      final sr = SiraTercihi.sorgu(SiraTercihi.anahtarKesfet);
      final d =
          await Api.get(
                '/kesfet-akis?imlec='
                '${Uri.encodeQueryComponent(_sayfalama.imlec!)}'
                '${sr.isEmpty ? '' : '&$sr'}',
              )
              as Map<String, dynamic>;
      if (!mounted) return;
      final gelen = d['akis'] as List<dynamic>? ?? [];
      setState(() {
        _sayfalama.yanitIsle(
          d,
          oncekiUzunluk: _liste!.length,
          gelenAdet: gelen.length,
        );
        // Listeye YALNIZ EKLEME: açık Reels'in indeksleri ve ızgaranın video
        // görünürlük indeksleri kaymasın.
        _liste!.addAll(gelen);
        _icerikler.addAll(d['icerikler'] as Map<String, dynamic>? ?? {});
        _yukluyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Sonraki sayfa patlarsa sessizce dur: eldeki içerik kaybolmasın.
      setState(() {
        _yukluyor = false;
        _sayfalama.bitti = true;
      });
    }
  }

  /// Sıralama tercihi değişti: liste TAMAMEN baştan kurulur (iki sıralama
  /// birbirine karışmasın), kaydırma başa alınır.
  void _siraDegisti() {
    setState(() {
      _liste = null;
      _icerikler = {};
      _sayfalama.sifirla();
      _gorunurVideolar.clear();
      _yukluyor = false;
    });
    if (_kaydirma.hasClients) _kaydirma.jumpTo(0);
    _yukle();
  }

  void _ac(int i) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => ReelsGorunumu(
          liste: _liste!,
          icerikler: _icerikler,
          baslangic: i,
          // Reels sona yaklaşınca ızgarayla AYNI listeye sayfa ekler; ızgara
          // listeye yalnız EKLEME yaptığı için açık sayfanın indeksi kaymaz.
          dahaGetir: _sonrakiSayfa,
        ),
      ),
    );
  }

  Widget _izgara(int bas, int son, int sutun) => SliverGrid.builder(
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: sutun,
      mainAxisSpacing: kesfetKaroBoslugu,
      crossAxisSpacing: kesfetKaroBoslugu,
      childAspectRatio: kesfetKaroOrani,
    ),
    itemCount: son - bas,
    itemBuilder: (context, j) {
      final i = bas + j;
      return _KesfetKutusu(
        // Tekrar turunda AYNI gönderi listede iki kez bulunabilir; anahtar
        // yalnız id olursa görünürlük takibi karışır → indeks de girer.
        sira: i,
        yorum: _liste![i] as Map<String, dynamic>,
        icerikler: _icerikler,
        onTap: () => _ac(i),
        oynat: _oynasinMi(i),
        onGorunurluk: (gorunur) => _gorunurlukDegisti(i, gorunur),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_liste == null) {
      // İskelet de AYNI kolona ve AYNI sütun hesabına oturur: içerik gelince
      // karolar yerinden oynamasın.
      govde = OrtaKolon(
        azami: masaustuKolonGenisligi,
        cocuk: LayoutBuilder(
          builder: (context, kisit) => GridView.builder(
            padding: const EdgeInsets.all(kesfetKaroBoslugu),
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: kesfetSutunlari(kisit.maxWidth),
              mainAxisSpacing: kesfetKaroBoslugu,
              crossAxisSpacing: kesfetKaroBoslugu,
              childAspectRatio: kesfetKaroOrani,
            ),
            itemCount: 12,
            itemBuilder: (context, i) =>
                const IskeletKutu(genislik: 120, yukseklik: 180),
          ),
        ),
      );
    } else if (_liste!.isEmpty) {
      govde = BosDurum(
        ikon: Icons.explore_outlined,
        baslik: 'Sonuç bulunamadı'.c,
        ipucu:
            'Akışın boş.\nİzlediğin dizi ve filmlere yorum yapılınca burada görünecek.'
                .c,
      );
    } else {
      final tekrarBasi = _sayfalama.tekrarBasi;
      // PC'de ızgara ekranın iki ucuna dayanmasın: akış/takvim/profil ile AYNI
      // ortalanmış kolon ([masaustuKolonGenisligi], tema.dart). Kullanıcı
      // isteği (8 Ağu 2026): "reels videolarının bulunduğu ekranı da akış ve
      // takvim gibi ortaya alacaktın almamışsın".
      //
      // Sütun sayısı ARTIK SABİT DEĞİL: kolon daraldığı için 5 sütun sıkışırdı;
      // [kesfetSutunlari] ölçülen kolon genişliğinden türetir (LayoutBuilder —
      // `ui-ux-pro-max` flutter/Layout: *"LayoutBuilder for adaptive layouts —
      // Don't: fixed sizes for responsive"*). Telefonda sonuç değişmez (3).
      //
      // Görülmemişler → ayraç → tekrar gösterilenler. Tek ızgara yerine iki
      // sliver: ayraç tam genişlikte durur, indeksler global kalır.
      govde = RefreshIndicator(
        color: DiziRenkler.sari,
        onRefresh: _yukle,
        child: OrtaKolon(
          azami: masaustuKolonGenisligi,
          cocuk: LayoutBuilder(
            builder: (context, kisit) {
              final sutun = kesfetSutunlari(kisit.maxWidth);
              return CustomScrollView(
                controller: _kaydirma,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(kesfetKaroBoslugu),
                    sliver: _izgara(0, tekrarBasi ?? _liste!.length, sutun),
                  ),
                  if (tekrarBasi != null) ...[
                    const SliverToBoxAdapter(child: TekrarAyraci()),
                    SliverPadding(
                      padding: const EdgeInsets.all(kesfetKaroBoslugu),
                      sliver: _izgara(tekrarBasi, _liste!.length, sutun),
                    ),
                  ],
                  // Sonraki sayfa yüklenirken alt tarafta dönen gösterge
                  if (_yukluyor)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: DiziRenkler.sari,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        // Akış'takiyle AYNI seçici (21 Ağu 2026): Keşfet alt çubuktan çıkınca
        // buradan Akış'a dönebilmenin görünür bir yolu kalmalıydı. Alt
        // çubuktaki Akış hedefi de bu ekranda seçili görünüyor (kabuk.dart →
        // hedefIndeksi), yani iki yol da aynı yere çıkar.
        //
        // LOGO YOK (Akış'ta var): bu ekranın üst barı 3 Ağu'dan beri logosuz
        // ve `sira_secici_test` bu ekranı ÇIPLAK pump ediyor — `Image.asset`
        // testte varlık yükleyemeyip gürültü üretirdi.
        title: const AkisGorunumSecici(secili: AkisGorunumu.kesfet),
        // Kullanıcı isteği (3 Ağu 2026): "keşfet yazısının en sağına
        // koyabilirsin bu seçeneği". Bu ekranın kendi sıralamasını yönetir.
        actions: [
          SiraSecici(
            anahtar: SiraTercihi.anahtarKesfet,
            onDegisti: _siraDegisti,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: govde,
    );
  }
}

/// Izgara karosu.
///
/// Video gönderilerinde İÇERİK POSTERİ değil, videonun kendi karesi gösterilir
/// (sunucu yüklemede `<yol>.jpg` üretir). Böylece ızgara resim gösterir;
/// onlarca video çözücü açılmaz. [oynat] verilen karo — ekranda aynı anda en
/// fazla iki tanesi, izlenme sayısı en yüksek olanlar — sessiz ve döngüsel
/// olarak gerçekten oynar.
class _KesfetKutusu extends StatefulWidget {
  final Map<String, dynamic> yorum;
  final Map<String, dynamic> icerikler;
  final VoidCallback onTap;
  final bool oynat;

  /// Listedeki global indeks — görünürlük anahtarını benzersiz kılar (tekrar
  /// turunda aynı gönderi listede iki kez yer alabilir).
  final int sira;

  /// Karo ekranda görünür hale gelince/çıkınca haber verir (ebeveyn hangi
  /// videoların oynayacağını buna göre seçer).
  final void Function(bool gorunur) onGorunurluk;

  const _KesfetKutusu({
    required this.sira,
    required this.yorum,
    required this.icerikler,
    required this.onTap,
    required this.oynat,
    required this.onGorunurluk,
  });

  @override
  State<_KesfetKutusu> createState() => _KesfetKutusuState();
}

class _KesfetKutusuState extends State<_KesfetKutusu> {
  VideoPlayerController? _d;

  static bool _videoMu(String u) => u.endsWith('.mp4') || u.endsWith('.webm');

  List<String> get _medya =>
      (widget.yorum['medya'] as List<dynamic>? ?? []).cast<String>();

  String? get _ilkVideo {
    for (final m in _medya) {
      if (_videoMu(m)) return m;
    }
    return null;
  }

  @override
  void didUpdateWidget(_KesfetKutusu eski) {
    super.didUpdateWidget(eski);
    if (widget.oynat != eski.oynat) {
      widget.oynat ? _oynatmayiKur() : _oynatmayiBirak();
    }
  }

  Future<void> _oynatmayiKur() async {
    final v = _ilkVideo;
    if (v == null || _d != null) return;
    final u = dosyaUrl(v)!;
    final d = VideoPlayerController.networkUrl(Uri.parse(u));
    _d = d;
    try {
      await d.initialize();
      if (!mounted || !widget.oynat) return _oynatmayiBirak();
      // AKIŞ ↔ REELS SÜREKLİLİĞİ (video_konum.dart): bu video oturumda
      // izlenmişse karo da oradan sürer; karodan Reels'e geçiş de baştan
      // başlamaz (dinleyici konumu deftere yazar).
      final hedef = VideoKonumDefteri.devral(u, d.value.position);
      if (hedef != null) await d.seekTo(hedef);
      if (!mounted || !widget.oynat) return _oynatmayiBirak();
      await d.setVolume(0); // ızgarada ses ASLA çalmaz
      await d.setLooping(true);
      d.addListener(
        () => VideoKonumDefteri.yaz(u, d.value.position, d.value.duration),
      );
      await d.play();
      if (mounted) setState(() {});
    } catch (_) {
      _oynatmayiBirak(); // ağ/kodek hatası: sessizce kapağa düşer
    }
  }

  void _oynatmayiBirak() {
    final d = _d;
    _d = null;
    d?.dispose();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _d?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final medya = _medya;
    final videolu = widget.yorum['videolu'] == true;
    // Spoiler uyarısı Ayarlar'dan kapatıldıysa karo da örtüsüz çizilir.
    final spoiler = widget.yorum['spoiler'] == true && SpoilerTercihi.acik;
    final icerik =
        widget.icerikler['${widget.yorum['tur']}:${widget.yorum['tmdb_id']}']
            as Map<String, dynamic>? ??
        const {'ad': '?', 'poster': null};
    final goruntulenme = (widget.yorum['goruntulenme'] as num?)?.toInt() ?? 0;

    // Arka plan sırası: fotoğraf → video karesi → içerik posteri.
    final ilkFoto = medya.where((m) => !_videoMu(m)).toList();
    final video = _ilkVideo;
    final poster = posterUrl(icerik['poster'] as String?, boyut: 'w342');
    final arka = ilkFoto.isNotEmpty
        ? dosyaUrl(ilkFoto.first)
        : (video != null ? dosyaUrl('$video.jpg') : poster);

    final d = _d;
    final videoOynuyor = d != null && d.value.isInitialized;
    return VisibilityDetector(
      key: Key('kesfet-${widget.sira}-${widget.yorum['id']}'),
      onVisibilityChanged: (bilgi) =>
          widget.onGorunurluk(bilgi.visibleFraction > 0.6),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (d != null && d.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: d.value.size.width,
                height: d.value.size.height,
                child: VideoPlayer(d),
              ),
            )
          else if (arka != null)
            CachedNetworkImage(
              imageUrl: arka,
              httpHeaders: gorselBasliklari(arka),
              filterQuality: kullaniciGorselKalitesi,
              fit: BoxFit.cover,
              // Video karesi henüz üretilmemişse içerik posterine düş
              errorWidget: (context, url, hata) => poster != null
                  ? CachedNetworkImage(
                      imageUrl: poster,
                      httpHeaders: gorselBasliklari(poster),
                      filterQuality: kullaniciGorselKalitesi,
                      fit: BoxFit.cover,
                    )
                  : Container(color: DiziRenkler.kart),
            )
          else
            Container(color: DiziRenkler.kart),
          // Yazılı yorum: alt yarıda metin bandı. Sunucu artık Keşfet'e
          // medyasız gönderi DÜŞÜRMÜYOR (KESFET_MEDYALI); bu dal yalnız
          // yedek: eski sunucu/önbellekten gelen sayfa boş karo göstermesin.
          if (medya.isEmpty)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 22),
                color: Colors.black54,
                child: Text(
                  spoiler ? '•••' : (widget.yorum['metin'] as String? ?? ''),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          if (videolu)
            const Positioned(
              top: 6,
              right: 6,
              // Gölge şart: video karesi de poster de yüklenemezse karo
              // DiziRenkler.kart'a düşer (açık temada BEYAZ) ve gölgesiz
              // beyaz ok kaybolurdu. Göz ikonu da aynı kalıbı kullanıyor.
              child: Icon(
                Icons.play_arrow,
                size: 20,
                color: Colors.white,
                shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
              ),
            ),
          // Sol alt: göz + izlenme sayısı (okunurluk için gölgeli)
          Positioned(
            left: 6,
            bottom: 5,
            child: IgnorePointer(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.remove_red_eye_outlined,
                    size: 13,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$goruntulenme',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (spoiler)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Icon(Icons.visibility_off_outlined, color: Colors.white),
              ),
            ),
          // Dokunuş katmanı EN ÜSTTE. Web'de VideoPlayer HtmlElementView
          // tıklamayı DOM'da yutar; InkWell videonun ALTINDAYSA hiç
          // ateşlenmez (kullanıcı: "oynayan videoya tıklanmıyor"). Reels
          // sayfası aynı tuzağı PointerInterceptor ile aşıyor.
          Positioned.fill(
            child: PointerInterceptor(
              intercepting: videoOynuyor,
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: widget.onTap),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Medyası olmayan (yalnız yazı) gönderi. Reels bu durumda dizi posterini
/// tam ekran zemin yapıp metni dev punto basar; akış kartı doğru yüzeydir.
@visibleForTesting
bool gonderiYaziliMi(Map<String, dynamic>? y) {
  if (y == null) return false;
  final m = y['medya'];
  return m is! List || m.isEmpty;
}

/// Tek gönderi ekranı (paylaşılan link / bildirim → /gonderi/:id).
///
/// Medyalı gönderi Reels'te tam ekran açılır. Yalnız-yazı gönderi ise
/// [AkisKarti] ile çizilir — Reels yazılı yorumu dizi posteri üstüne dev
/// punto bastığı için beğeni bildiriminden gelince "yorum yazma" ekranı
/// gibi duruyordu; akıştaki kart doğru yüzeydir.
///
/// [yanitBildirimi] TRUE ise ([gonderiYolu] `?yanit=1`) gelen id bir YANITTIR:
/// ekran üst gönderiyi çözer, onu (medyasına göre Reels veya kart) gösterir
/// ve üstüne normal yorum ekranını ([yanitlariAc]) açar — akış kartındaki
/// konuşma balonuna basmakla AYNI yüzey. Bkz. [_ustuCoz].
class GonderiEkrani extends StatefulWidget {
  final int yorumId;
  final bool yanitBildirimi;
  const GonderiEkrani({
    super.key,
    required this.yorumId,
    this.yanitBildirimi = false,
  });

  @override
  State<GonderiEkrani> createState() => _GonderiEkraniState();
}

class _GonderiEkraniState extends State<GonderiEkrani> {
  Map<String, dynamic>? _yorum;
  Map<String, dynamic> _icerikler = {};
  String? _hata;

  /// Yanıt bildiriminden gelindi ve üst gönderi çözüldü: ilk karede yorum
  /// ekranı açılacak. Tek seferlik — sheet kapanınca yeniden açılmaz.
  bool _yorumlarAcilacak = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  // Paylaşılan gönderiden sonra kaydırma DEVAM etsin: bu gönderi başta,
  // ardından keşfet akışı gelir (mesajdan gelen kullanıcı tek postta kilitli
  // kalmasın).
  List<dynamic> _devam = [];

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      // KAYNAK: bu GET görüntülenmeyi de +1 yapıyor (sunucu tarafı), etiket
      // olmadan "Diğer" kovasına düşerdi.
      final d = await Api.get(
        '/yorum/${widget.yorumId}?kaynak=${GonderiOlcu.kaynakPaylasim}',
      );
      if (!mounted) return;
      var yorum = d['yorum'] as Map<String, dynamic>;
      var icerikler = d['icerikler'] as Map<String, dynamic>? ?? {};
      var yorumlarAc = false;
      if (widget.yanitBildirimi) {
        final ust = await _ustuCoz(yorum);
        if (!mounted) return;
        if (ust != null) {
          yorum = ust['yorum'] as Map<String, dynamic>;
          icerikler = {
            ...icerikler,
            ...(ust['icerikler'] as Map<String, dynamic>? ?? {}),
          };
          yorumlarAc = true;
        }
      }
      setState(() {
        _yorum = yorum;
        _icerikler = icerikler;
        _yorumlarAcilacak = yorumlarAc;
      });
      // Yazılı gönderi akış kartı olarak kalır; keşfet devam listesi
      // Reels kaydırması içindir, kartın altına medyalı Reels karışmasın.
      if (!gonderiYaziliMi(yorum)) _devamYukle();
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
    }
  }

  /// [y] bir YANITSA üst gönderisini (`{yorum, icerikler}`) döndürür; üst
  /// bulunamazsa `null` — o durumda ekran bugünkü davranışında kalır.
  ///
  /// NEDEN İKİ İSTEK: `GET /yorum/:id` `ust_id` alanını DÖNDÜRMÜYOR, yani
  /// yanıtın üstünü tek başına söyleyen bir uç yok. `GET /yorumlar/:tur/:tmdbId`
  /// hem `ust_id`yi hem de üst gönderiyi zaten taşıdığı için bağ oradan
  /// kurulur, sonra üst gönderi `GET /yorum/:ustId` ile TAM alanlarıyla
  /// (medya, sayaçlar, `icerikler` haritası — Reels'in beklediği biçim) çekilir.
  /// Sunucuya `ust_id` eklenirse ilk istek kendiliğinden atlanır (aşağıdaki
  /// `y['ust_id']` dalı) ve bu yol tek isteğe iner.
  ///
  /// MALİYET: yalnız `?yanit=1` yolunda çalışır. Paylaşım bağlantısıyla açılan
  /// gönderi hiç ek istek atmaz.
  Future<Map<String, dynamic>?> _ustuCoz(Map<String, dynamic> y) async {
    final tur = y['tur'], tmdb = y['tmdb_id'];
    if (tur == null || tmdb == null) return null;
    var ustId = y['ust_id'] as int?;
    if (ustId == null) {
      // Yanıt, üstüyle AYNI kapsamda listelenir: bölüm yanıtı bölüm
      // listesinde, dizi geneli yanıtı dizi listesinde.
      final sorgu = y['sezon'] != null
          ? '?sezon=${y['sezon']}&bolum=${y['bolum']}'
          : '';
      try {
        final d = await Api.get('/yorumlar/$tur/$tmdb$sorgu');
        for (final c in (d['yorumlar'] as List<dynamic>? ?? const [])) {
          if (c is Map && c['id'] == y['id']) {
            ustId = c['ust_id'] as int?;
            break;
          }
        }
      } catch (_) {
        return null; // liste gelmezse tek gönderi olarak kalır
      }
    }
    if (ustId == null) return null;
    try {
      final d = await Api.get('/yorum/$ustId');
      return d is Map<String, dynamic> && d['yorum'] is Map<String, dynamic>
          ? d
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _devamYukle() async {
    try {
      final d = await Api.get('/kesfet-akis');
      if (!mounted) return;
      final liste = (d['akis'] as List<dynamic>? ?? [])
          .where((y) => (y as Map<String, dynamic>)['id'] != widget.yorumId)
          .toList();
      setState(() {
        _devam = liste;
        _icerikler = {
          ..._icerikler,
          ...(d['icerikler'] as Map<String, dynamic>? ?? {}),
        };
      });
    } catch (_) {
      // devam listesi gelmezse tek gönderi olarak kalır
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hata != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.link_off, size: 48, color: DiziRenkler.metin38),
                const SizedBox(height: 12),
                Text(
                  'Gönderi bulunamadı'.c,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: DiziRenkler.metin54),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => GoRouter.of(context).go('/arama'),
                  child: Text('Keşfet\'e dön'.c),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_yorum == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: DiziRenkler.sari)),
      );
    }
    // Yanıt bildiriminden gelindiyse üst gönderinin yorum ekranı AÇILIR.
    // Kare içinde `showModalBottomSheet` çağrılamaz → kare sonrasına ertelenir.
    if (_yorumlarAcilacak) {
      _yorumlarAcilacak = false;
      final yorum = _yorum!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) yanitlariAc(context, yorum);
      });
    }
    if (gonderiYaziliMi(_yorum)) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Kapat'.c,
            // Doğrudan URL ile açıldıysa geri gidilecek yer yoktur →
            // Reels'tekiyle aynı yedek (Keşfet akışı).
            onPressed: () => Navigator.of(context).canPop()
                ? Navigator.pop(context)
                : GoRouter.of(context).go('/arama'),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: OrtaKolon(
          azami: masaustuKolonGenisligi,
          cocuk: ListView(
            padding: EdgeInsets.only(top: 8, bottom: altGuvenli(context)),
            children: [AkisKarti(yorum: _yorum!, icerikler: _icerikler)],
          ),
        ),
      );
    }
    return ReelsGorunumu(
      liste: [_yorum!, ..._devam],
      icerikler: _icerikler,
      baslangic: 0,
      // Bu ekran `/gonderi/:id` bağlantısının indiği yer: görüntülenme
      // "paylaşılan bağlantı" kovasına yazılır (md. 23).
      kaynak: GonderiOlcu.kaynakPaylasim,
    );
  }
}

/// Tam ekran dikey kaydırmalı Reels görünümü.
/// Masaüstünde Reels sahnesinin ORANI: dikey video çerçevesi (9:16).
///
/// NEDEN ORAN, NEDEN SABİT PİKSEL DEĞİL: Reels bir metin kolonu değil, tam
/// ekran DİKEY VİDEO. Ona 720 dp'lik okuma kolonunu vermek 1080 dp yüksekliğe
/// 720 dp genişlik demek olurdu (2:3) — video yine ortada durur ama üst/alt
/// katmanlar (kullanıcı adı, eylem sütunu, ilerleme çubuğu) videonun siyah
/// kenarlarına taşardı. Genişliği YÜKSEKLİKTEN türetince tuval telefondaki
/// çerçevenin aynısı olur: bindirmeler videonun kenarına oturur.
/// (`ui-ux-pro-max` → flutter/Layout: *"LayoutBuilder for adaptive layouts —
/// Don't: fixed sizes for responsive"*.)
const double reelsTuvalOrani = 9 / 16;

/// Tuvalin genişleyebileceği EN YATAY oran (16:9).
///
/// NEDEN GENİŞLEYEBİLİYOR (8 Ağu 2026 ölçümü): 9:16 tuval yalnız DİKEY medya
/// için doğru. 1568×764'lük pencerede tuval 430 dp; içine 16:9 bir kare
/// (dizi/film ekran görüntüsü — Keşfet'in en sık içeriği) `BoxFit.contain` ile
/// oturunca yüksekliğin ancak **%31,6**'sını dolduruyordu: üstte ve altta
/// ~261 dp siyah boşluk, metin ve eylem sütunu medyanın çok altında.
///
/// Çözüm: tuvalin ORANI ekrandaki medyanın oranını izler (alt sınır 9:16 —
/// dikey videoda bugünkü çerçeve birebir korunur, üst sınır 16:9). Kırpma YOK
/// (`BoxFit.cover` seçilseydi 16:9 bir karenin genişliğinin ~%68'i kesilirdi),
/// medya küçültülmez; yalnız çerçeve içeriğe uyar.
const double reelsAzamiTuvalOrani = 16 / 9;

/// Reels'te medyayı dikeyde ortalamak yerine biraz YUKARI çeker.
///
/// NEDEN (29 Ağu 2026, kullanıcı isteği): "dikdörtgen yatay videoları biraz
/// yukarı çek, aşağıda kalıyor". Geometrik olarak ortalanmış olsalar da
/// GÖRSEL olarak aşağıda duruyorlar, çünkü ekranın alt şeridini kullanıcı
/// adı, açıklama, ilerleme çubuğu ve eylem sütunu kaplıyor.
///
/// ÖLÇÜ BOŞ ALANIN ORANI, ekran yüksekliğinin değil. `Alignment.y` boş alanın
/// YARISI üzerinden çalışır (y=-1 → üst kenara yaslar), yani "boş alanın
/// %17,5'i kadar yukarı" = y -0.35.
///
/// KOŞULSUZ UYGULANIR ve bu GÜVENLİDİR: medya ekranı dikeyde dolduruyorsa
/// boş alan yoktur, hizalama kendiliğinden etkisizdir; boşluk büyüdükçe kayma
/// büyür, hiçbir oranda ekran dışına taşamaz.
///
/// ⚠ İLK SÜRÜM `oran > 1` KOŞULU KOYUYORDU VE YANLIŞTI (aynı gün, kullanıcı
/// bildirdi: "fotoğrafları yukarı çekmişsin ama videolar hâlâ aşağıda").
/// Instagram'ın kendi formatları 4:5 (0,8) ve 1:1 — ikisi de "kareden geniş"
/// DEĞİL, ama telefon ekranı ~0,486 oranında olduğu için ikisi de üstte ve
/// altta koca boşluk bırakıyor. Koşul onları "dikey" sayıp ortalıyordu, yani
/// şikâyet edilen videolar tam da kuralın DIŞINDA kalıyordu. Doğru soru
/// "kareden geniş mi" değil "EKRANDAN geniş mi" — ve onu hesaplamaya gerek
/// yok, boş alanın kendisi zaten cevap.
const double reelsMedyaYukariHizasi = -0.35;

/// Reels medyasının dikey hizası — video ve fotoğraf için AYNI.
const Alignment reelsMedyaHizasi = Alignment(0, reelsMedyaYukariHizasi);

/// Tuvalin masaüstünde alabileceği EN BÜYÜK genişlik.
///
/// Oran serbest bırakılırsa 16:9 medyada tuval 1358 dp'ye çıkar ve 7 Ağu'da
/// düzeltilen sorun geri gelir (kullanıcı adı solda, eylem sütunu çok uzakta).
/// Sitenin kendi içerik genişliği ([masaustuIcerikGenisligi], 1080) tavan
/// olarak kullanılır: bindirmeler hiçbir zaman içerik kolonundan geniş yayılmaz.
const double reelsAzamiTuvalGenisligi = masaustuIcerikGenisligi;

/// Verilen sahne ölçüsünde Reels tuvalinin genişliği.
/// Yüksekliğe sığan [oran] çerçevesi; ekran ondan darsa (mobil) tam genişlik.
///
/// [oran] verilmezse 9:16 — yani ÖLÇÜLMEMİŞ/dikey medyada davranış eskisiyle
/// birebir aynıdır (telefon düzeni bu yoldan hiç etkilenmez).
double reelsTuvalGenisligi(
  double genislik,
  double yukseklik, {
  double oran = reelsTuvalOrani,
}) {
  if (!genislik.isFinite || genislik <= 0) return genislik;
  if (!yukseklik.isFinite || yukseklik <= 0) return genislik;
  final o = (oran.isFinite && oran > 0 ? oran : reelsTuvalOrani).clamp(
    reelsTuvalOrani,
    reelsAzamiTuvalOrani,
  );
  final oranli = yukseklik * o;
  final sigan = oranli < genislik ? oranli : genislik;
  return sigan < reelsAzamiTuvalGenisligi ? sigan : reelsAzamiTuvalGenisligi;
}

/// Bir fotoğrafın GERÇEK en/boy oranını ölçer (görsel zaten önbellekte;
/// ölçüm ek indirme yapmaz). Testlerde değiştirilebilsin diye değişken.
@visibleForTesting
Future<double?> Function(String url) reelsFotoOraniOlcer = _fotoOraniniOlc;

Future<double?> _fotoOraniniOlc(String url) {
  final tamam = Completer<double?>();
  final akis = CachedNetworkImageProvider(
    url,
    headers: gorselBasliklari(url),
  ).resolve(ImageConfiguration.empty);
  late final ImageStreamListener dinleyici;
  void bitir(double? o) {
    if (tamam.isCompleted) return;
    akis.removeListener(dinleyici);
    tamam.complete(o);
  }

  dinleyici = ImageStreamListener(
    (bilgi, _) => bitir(
      bilgi.image.height == 0
          ? null
          : bilgi.image.width / bilgi.image.height.toDouble(),
    ),
    // Görsel inmezse ölçüm de yoktur: tuval 9:16 kalır (bugünkü davranış).
    onError: (_, _) => bitir(null),
  );
  akis.addListener(dinleyici);
  return tamam.future;
}

class ReelsGorunumu extends StatefulWidget {
  final List<dynamic> liste;
  final Map<String, dynamic> icerikler;
  final int baslangic;

  /// Açılış gönderisinde KAÇINCI medyadan başlanacağı. Akışta 5. fotoğrafa
  /// dokunan kullanıcı Reels'te de 5. fotoğrafı görmeli (eskiden hep 1.
  /// açılıyordu; kullanıcı "sonraki resim gelmiyor" diye bildirdi).
  final int medyaBaslangic;

  /// Sona yaklaşınca çağrılır: ızgarayla AYNI listeye sayfa ekler. Liste
  /// yalnız büyüdüğü için açık sayfanın indeksi kaymaz. Null → sayfalama yok
  /// (tek gönderi ekranı).
  final Future<void> Function()? dahaGetir;

  /// Görüntülenme KAYNAK etiketi (md. 23). Reels aynı bileşenle akıştan,
  /// keşfetten, PROFİLDEN ve dizi sayfasından açılıyor; kaynağı yalnız
  /// çağıran bilir. Varsayılan 'reels' — açan yer söylemezse görüntülenme
  /// yine de doğru kovaya (tam ekran akış) düşer.
  final String kaynak;

  const ReelsGorunumu({
    super.key,
    required this.liste,
    required this.icerikler,
    required this.baslangic,
    this.medyaBaslangic = 0,
    this.dahaGetir,
    this.kaynak = GonderiOlcu.kaynakReels,
  });

  @override
  State<ReelsGorunumu> createState() => _ReelsGorunumuState();
}

class _ReelsGorunumuState extends State<ReelsGorunumu> {
  late final PageController _sayfa = PageController(
    initialPage: widget.baslangic,
  );
  late int _aktif = widget.baslangic; // yalnız aktif sayfa oynar/işaretlenir
  bool _getiriyor = false;

  /// Ekrandaki Reels sayfası — ok/tuş önce onun medyasına, sonra gönderiye.
  _ReelSayfaState? _aktifSayfa;

  /// Masaüstü tuvalinin oranı: EKRANDAKİ medyanın ölçülen oranı (bilinmiyorsa
  /// 9:16). Yalnız aktif sayfa bildirir.
  double _oran = reelsTuvalOrani;

  /// Aktif sayfa medyasının oranını bildirdi.
  ///
  /// Kare sırasında `setState` çağrılmaz (çocuk `initState`/`didUpdateWidget`
  /// içinden bildirebilir) → kare sonrasına ertelenir.
  void _oranGeldi(int sayfa, double o) {
    if (sayfa != _aktif || !o.isFinite || o <= 0) return;
    if ((o - _oran).abs() < 0.001) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || sayfa != _aktif || (o - _oran).abs() < 0.001) return;
      setState(() => _oran = o);
    });
  }

  @override
  void dispose() {
    _sayfa.dispose();
    super.dispose();
  }

  /// Gönderideki medya adedi (okların ilk karede de doğru çizilmesi için).
  int _medyaAdedi(int i) {
    if (i < 0 || i >= widget.liste.length) return 0;
    final m = (widget.liste[i] as Map)['medya'];
    return m is List ? m.length : 0;
  }

  int get _sayfaNo =>
      _sayfa.hasClients ? (_sayfa.page?.round() ?? _aktif) : _aktif;

  int get _medyaToplam => _aktifSayfa?.medyaToplam ?? _medyaAdedi(_aktif);

  /// Aktif sayfa kendisini kaydeder (initState'te setState yok).
  void _sayfaKaydet(_ReelSayfaState s) {
    if (_aktifSayfa == s) return;
    _aktifSayfa = s;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _sayfaBirak(_ReelSayfaState s) {
    if (_aktifSayfa == s) _aktifSayfa = null;
  }

  /// Ok/tuş sonrası ok görünürlüğü güncellenir.
  void _medyaDegisti() {
    if (mounted) setState(() {});
  }

  /// Sol: önceki fotoğraf, yoksa önceki gönderi.
  void _sol() {
    if (_aktifSayfa != null) {
      if (_aktifSayfa!.geriMedya()) {
        setState(() {});
        return;
      }
    } else if (_medyaAdedi(_aktif) > 1) {
      return; // çocuk henüz bağlanmadı, gönderi atlanmasın
    }
    _postGit(_sayfaNo - 1);
  }

  /// Sağ: sonraki fotoğraf, yoksa sonraki gönderi.
  void _sag() {
    if (_aktifSayfa != null) {
      if (_aktifSayfa!.ileriMedya()) {
        setState(() {});
        return;
      }
    } else if (_medyaAdedi(_aktif) > 1) {
      return;
    }
    _postGit(_sayfaNo + 1);
  }

  void _postGit(int i) {
    if (!_sayfa.hasClients) return;
    if (i < 0 || i >= widget.liste.length) return;
    if (i == _sayfaNo) return;
    _sayfa.animateToPage(
      i,
      duration: tamEkranGecisSuresi,
      curve: Curves.easeOut,
    );
  }

  /// Son 3 sayfaya girince sıradaki sayfayı ızgaraya çektir; gelen gönderiler
  /// aynı liste nesnesine eklendiği için burada tek setState yeter.
  Future<void> _dahaGetir() async {
    final f = widget.dahaGetir;
    if (f == null || _getiriyor) return;
    _getiriyor = true;
    try {
      await f();
    } finally {
      _getiriyor = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final sayfalar = PageView.builder(
      controller: _sayfa,
      scrollDirection: Axis.vertical,
      itemCount: widget.liste.length,
      // Komşu sayfalar ÖNDEN kurulur → sıradaki video kaydırmadan önce
      // yüklenmeye başlar (bunsuz her kaydırışta bekleniyordu).
      allowImplicitScrolling: true,
      // Aktif sayfa değişince: yalnız görünen sayfa video oynatır ve
      // "görüldü" işaretlenir (komşu sayfalar önden kurulsa da sessiz).
      onPageChanged: (i) {
        setState(() => _aktif = i);
        if (i >= widget.liste.length - 3) _dahaGetir();
      },
      itemBuilder: (context, i) => _ReelSayfa(
        // Tekrar turunda aynı id iki kez bulunabilir → indeks de girer.
        key: ValueKey('$i-${(widget.liste[i] as Map)['id']}'),
        yorum: widget.liste[i] as Map<String, dynamic>,
        icerikler: widget.icerikler,
        aktif: i == _aktif,
        onOran: (o) => _oranGeldi(i, o),
        // Yalnız açılış gönderisi dokunulan medyadan başlar; diğerleri
        // her zaman baştan.
        medyaBaslangic: i == widget.baslangic ? widget.medyaBaslangic : 0,
        kaynak: widget.kaynak,
        onKayit: i == _aktif ? _sayfaKaydet : null,
        onBirak: _sayfaBirak,
        onMedyaDegisti: i == _aktif ? _medyaDegisti : null,
      ),
    );

    // NOT: `MediaQuery.paddingOf` YALNIZ yan okların kenar boşluğu içindi;
    // oklar kaldırılınca (19 Ağu) gerek kalmadı. Kapatma düğmesi kendi
    // `SafeArea`sını kullanıyor.
    final coklu = widget.liste.length > 1 || _medyaToplam > 1;

    return TamEkranKlavye(
      sola: coklu ? _sol : null,
      saga: coklu ? _sag : null,
      yukari: widget.liste.length > 1 ? () => _postGit(_sayfaNo - 1) : null,
      asagi: widget.liste.length > 1 ? () => _postGit(_sayfaNo + 1) : null,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // MASAÜSTÜ: sahne dikey tuvale sığdırılıp ORTALANIR — 1920 dp'lik
            // ekranda kullanıcı adı solda, eylem sütunu 1900 dp ötede sağdaydı.
            // Tuvalin İÇİ değişmez: video oranı, `PointerInterceptor`lu dokunuş
            // katmanı ve sağdaki eylem sütunu sayfanın kendi Stack'inde kalır,
            // yalnız sayfanın genişliği değişir.
            //
            // Tuvalin ORANI ekrandaki medyayı izler ([reelsAzamiTuvalOrani]):
            // dikey videoda 9:16 (değişiklik yok), YATAY medyada çerçeve genişler
            // ve siyah boşluk kapanır. Geçiş 200 ms yumuşatılır — anlık zıplama
            // `ui-ux-pro-max` → Animation/"Instant state changes (0ms)" karşıtı.
            // MOBİL: [masaustuMu] false → sayfa doğrudan çizilir, hiçbir
            // sarmalayıcı eklenmez (bugünkü ağaç birebir aynı).
            if (masaustuMu(context))
              Center(
                child: LayoutBuilder(
                  builder: (context, kisit) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    width: reelsTuvalGenisligi(
                      kisit.maxWidth,
                      kisit.maxHeight,
                      oran: _oran,
                    ),
                    child: sayfalar,
                  ),
                ),
              )
            else
              sayfalar,
            // YAN OK YOK — bilinçli (19 Ağu 2026, kullanıcı isteği).
            // Reels dikey kaydırma/dokunma ile gezilir; ekranın iki yanında
            // duran chevron'lar hem videonun üstünü kapatıyordu hem de
            // Instagram/TikTok'ta olmayan bir öğe olarak yabancı duruyordu.
            // MASAÜSTÜNDE DE KALDIRILDI: yön TUŞLARI (TamEkranKlavye, yukarıda
            // `sola:`/`saga:`) çalışmaya devam ediyor, yani klavyeyle gezinme
            // kaybolmadı — yalnız görsel buton gitti.
            // Tam ekran FOTOĞRAF görüntüleyicideki oklar (medya_goster.dart)
            // AYRI ve DURUYOR: orası kaydırmayla değil, tek tek karelerle gezilen
            // bir galeri.
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  tooltip: 'Kapat'.c,
                  // Doğrudan URL ile açıldıysa (paylaşılan gönderi linki) geri
                  // gidilecek yer yoktur → Keşfet'e dön.
                  onPressed: () => Navigator.of(context).canPop()
                      ? Navigator.pop(context)
                      : GoRouter.of(context).go('/arama'),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.black38),
                ),
              ),
            ),
            // Otomatik çeviri anahtarı (31 Ağu 2026 isteği): sağ üstte,
            // DOKUNULMADIĞINDA YARI SAYDAM — videonun üstünde durduğu için
            // tam opak bir düğme rahatsız ederdi ("tıklanmayınca transparan
            // olsun"). ÜÇ KİP (aynı gün netleşti): SARI = okuyanın dili,
            // BEYAZ = orijinal metin, GRİ = kapalı (altyazı hiç çizilmez).
            // Dokunma sırası sarı→beyaz→gri→SARI: kapalıdan sonra bilerek
            // çeviriye dönülür ("sarı kapalıdan sonra gelsin ki kullanıcı
            // şaşırmasın"). Tercih kalıcı; ekrandaki gönderiler ve açık
            // videonun altyazısı ANINDA uyar ([ReelsCeviri.kip] dinleniyor).
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: ValueListenableBuilder<ReelsCeviriKip>(
                  valueListenable: ReelsCeviri.kip,
                  builder: (context, kip, _) => Opacity(
                    opacity: 0.45,
                    child: IconButton(
                      key: const Key('reels-ceviri'),
                      tooltip: 'Otomatik çeviri'.c,
                      onPressed: () {
                        final yeni = ReelsCeviri.sonraki(kip);
                        ReelsCeviri.sec(yeni);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(switch (yeni) {
                              ReelsCeviriKip.ceviri =>
                                'Otomatik çeviri açıldı'.c,
                              ReelsCeviriKip.orijinal =>
                                'Orijinal metin gösteriliyor'.c,
                              ReelsCeviriKip.kapali =>
                                'Otomatik çeviri kapatıldı'.c,
                            }),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.translate,
                        color: switch (kip) {
                          ReelsCeviriKip.ceviri => DiziRenkler.sari,
                          ReelsCeviriKip.orijinal => Colors.white,
                          ReelsCeviriKip.kapali => Colors.grey,
                        },
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black38,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReelSayfa extends StatefulWidget {
  final Map<String, dynamic> yorum;
  final Map<String, dynamic> icerikler;
  final bool aktif; // ekranda görünen sayfa mı (yalnız o oynar/işaretlenir)
  final int medyaBaslangic; // açılışta gösterilecek medyanın sırası

  /// Ekrandaki medyanın en/boy oranı bilinince çağrılır (masaüstü tuvali
  /// çerçeveyi buna göre kurar). Yalnız AKTİF sayfa bildirir.
  final ValueChanged<double>? onOran;

  /// Görüntülenme kaynak etiketi — `ReelsGorunumu.kaynak`tan gelir.
  final String kaynak;

  /// Aktif olunca üst görünüme kaydolur (ok/tuş bu state üzerinden medya
  /// değiştirir). `onKayit` yalnız aktif sayfaya verilir.
  final ValueChanged<_ReelSayfaState>? onKayit;
  final ValueChanged<_ReelSayfaState>? onBirak;
  final VoidCallback? onMedyaDegisti;

  const _ReelSayfa({
    super.key,
    required this.yorum,
    required this.icerikler,
    this.aktif = true,
    this.medyaBaslangic = 0,
    this.onOran,
    this.kaynak = GonderiOlcu.kaynakReels,
    this.onKayit,
    this.onBirak,
    this.onMedyaDegisti,
  });

  @override
  State<_ReelSayfa> createState() => _ReelSayfaState();
}

class _ReelSayfaState extends State<_ReelSayfa>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _d;
  late bool _begendim = widget.yorum['begendim'] == true;
  late int _begeni = (widget.yorum['begeni'] as num?)?.toInt() ?? 0;
  late bool _takipte = widget.yorum['takip_ediyorum'] == true;
  // Takip durumu HER kaynakta gelmez (profilden açılan Reels'te yok). Bilinmiyorsa
  // düğme hiç çizilmez: kendi gönderinde "Takip Et" göstermek ya da zaten takip
  // ettiğin kişiye yeniden sormak yanlış olur; profil sayfasının kendi düğmesi var.
  //
  // 19 Ağu 2026: akış artık KENDİ gönderilerimizi de getiriyor. Sunucu bu
  // satırlarda `benim: true` gönderir; olmasaydı kendi gönderimizin üstünde
  // kendimizi takip etmeye çağıran bir düğme çıkardı.
  late final bool _takipBilinir =
      widget.yorum.containsKey('takip_ediyorum') &&
      widget.yorum['benim'] != true;
  // Ayarlar'dan spoiler uyarısı kapatıldıysa örtü HİÇ kurulmaz.
  late bool _spoilerAcik =
      widget.yorum['spoiler'] != true || !SpoilerTercihi.acik;
  // Çift dokunuş kalbi: dokunulan KONUMDA belirir, yükselip solar.
  // DİKKAT: `late final` ile TEMBEL kurulmamalı — kullanıcı hiç çift
  // dokunmadan sayfadan çıkarsa ilk erişim dispose() içinde olur ve vsync
  // araması koparılmış widget üzerinde patlar. initState'te kurulur.
  late final AnimationController _kalpAnim;
  Offset? _kalpKonum;

  /// Gönderinin TÜM medyası (sırayla) — çoklu gönderide yana kaydırılır.
  late final List<String> _medya = [
    for (final m in (widget.yorum['medya'] as List<dynamic>? ?? []))
      dosyaUrl(m as String)!,
  ];
  late int _medyaSayfa = widget.medyaBaslangic.clamp(
    0,
    _medya.isEmpty ? 0 : _medya.length - 1,
  );
  String? _kuruluUrl; // oynatıcının kurulu olduğu video adresi

  /// md. 23 — bu izlemenin elde tutma ölçüsü. Sayfa bırakılınca TEK istek
  /// gider; video hiç oynamadıysa (komşu sayfa hazırlandı ama görülmedi) hiç
  /// gitmez.
  late final _kova = VideoKovaIzleyici(widget.yorum['id']);

  static bool _videoMu(String u) => u.endsWith('.mp4') || u.endsWith('.webm');

  /// Ekranda duran medya (çoklu gönderide kaydırmayla değişir)
  String? get _aktifMedya =>
      _medya.isEmpty ? null : _medya[_medyaSayfa.clamp(0, _medya.length - 1)];

  int get medyaSayfa => _medyaSayfa;
  int get medyaToplam => _medya.length;

  /// Üst ok/tuş: önceki kare. İlk karede false → gönderi geri gider.
  bool geriMedya() {
    if (_medyaSayfa <= 0) return false;
    setState(() => _medyaSayfa--);
    _medyaDegisti();
    return true;
  }

  /// Üst ok/tuş: sonraki kare. Son karede false → sonraki gönderi.
  bool ileriMedya() {
    if (_medyaSayfa >= _medya.length - 1) return false;
    setState(() => _medyaSayfa++);
    _medyaDegisti();
    return true;
  }

  String? get _videoUrl {
    final m = _aktifMedya;
    return (m != null && _videoMu(m)) ? m : null;
  }

  String? get _fotoUrl {
    final m = _aktifMedya;
    return (m != null && !_videoMu(m)) ? m : null;
  }

  /// Ekrandaki medyanın ÖLÇÜLEN en/boy oranı (video: oynatıcıdan, fotoğraf:
  /// görselin kendi ölçüsünden). Bilinmiyorsa null → tuval 9:16 kalır.
  double? _medyaOrani;

  /// Fotoğraf ölçüm sırası: yana kaydırılınca eski ölçüm geç gelirse yanlış
  /// orana düşülmesin.
  int _olcumSirasi = 0;

  /// Oranı üst görünüme bildirir. Medyalı gönderide ÖLÇÜM GELMEDEN bildirim
  /// yapılmaz: aksi halde tuval önce 9:16'ya daralır, ölçüm gelince genişler
  /// (iki zıplama). Medyasız (yazılı) gönderide oran doğrudan 9:16'dır.
  void _oranBildir() {
    if (!widget.aktif) return;
    final o = _medyaOrani ?? (_medya.isEmpty ? reelsTuvalOrani : null);
    if (o != null) widget.onOran?.call(o);
  }

  /// Ekrandaki medya fotoğrafsa oranını ölçtürür (video oranı oynatıcı
  /// kurulunca gelir).
  Future<void> _oraniOlc() async {
    final f = _fotoUrl;
    if (f == null) return;
    final sira = ++_olcumSirasi;
    final o = await reelsFotoOraniOlcer(f);
    if (!mounted || sira != _olcumSirasi || o == null || o <= 0) return;
    _medyaOrani = o;
    _oranBildir();
  }

  bool _isaretlendi = false;

  /// Bu gönderiyi gördü → bir daha akış/keşfette gösterilmesin (yalnız bir kez,
  /// ve YALNIZ sayfa gerçekten aktifleşince — komşu sayfalar sayılmaz).
  void _isaretle() {
    if (_isaretlendi) return;
    _isaretlendi = true;
    // KAYNAK (md. 23): tam ekran dikey akış = 'reels'. Etiketsiz gitseydi
    // Reels'ten gelen görüntülenmeler "Diğer" kovasına düşerdi.
    Api.post('/akis/goruldu', {
      'idler': [widget.yorum['id']],
      'kaynak': widget.kaynak,
    }).catchError((_) => null);
  }

  /// Yalnız aktif (ekranda görünen) sayfa oynar → çift ses olmaz.
  void _videoDurumGuncelle() {
    final d = _d;
    if (d == null || !d.value.isInitialized) return;
    if (widget.aktif && _spoilerAcik) {
      d.play();
    } else {
      d.pause();
    }
  }

  @override
  void didUpdateWidget(_ReelSayfa eski) {
    super.didUpdateWidget(eski);
    if (widget.aktif && !eski.aktif) _isaretle();
    if (widget.aktif != eski.aktif) _videoDurumGuncelle();
    if (widget.aktif && !eski.aktif) {
      _medyaOnbellekle();
      // Bu sayfa aktif oldu: tuval oranını (biliniyorsa) hemen bildir.
      _oranBildir();
    }
    if (widget.aktif) {
      widget.onKayit?.call(this);
    } else if (eski.aktif) {
      widget.onBirak?.call(this);
    }
  }

  @override
  void initState() {
    super.initState();
    _kalpAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.aktif) _isaretle();
    _videoKur();
    _oraniOlc();
    _oranBildir();
    if (widget.aktif) _medyaOnbellekle();
    // Referans; üst setState yok (initState sırasında yasak).
    if (widget.aktif) widget.onKayit?.call(this);
  }

  bool _onbellekBasladi = false;

  /// Aktif gönderinin TÜM fotoğraflarını önden indirir. Eskiden yalnız ekranda
  /// duran kare iniyordu; kullanıcı yana kaydırdıkça her seferinde indirmeyi
  /// bekliyordu. Kareler ~180 KB, 10'luk gönderi ~1,8 MB → önden almak ucuz.
  /// Yalnız AKTİF sayfa için çalışır (komşu gönderiler kendi ilk karesini
  /// zaten PageView'ın önden kurmasıyla yüklüyor).
  ///
  /// Veri tasarrufu o bağlantı için AÇIKSA hiç indirmez (varsayılan: mobil
  /// veride açık, Wi-Fi'da kapalı) — Ayarlar > Veri tasarrufu.
  void _medyaOnbellekle() {
    if (!VeriTasarrufu.onYuklemeSerbest) return;
    if (_onbellekBasladi || _medya.length < 2) return;
    _onbellekBasladi = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final u in _medya) {
        if (_videoMu(u)) continue; // videolar akışla gelir, önbelleğe alınmaz
        precacheImage(
          // Ön yükleme ile GÖSTERİM aynı başlıkları kullanmalı: aksi hâlde
          // (kuramsal olarak) iki farklı biçim inebilirdi. Önbellek anahtarı
          // yalnız URL'dir, başlık anahtarı etkilemez.
          CachedNetworkImageProvider(u, headers: gorselBasliklari(u)),
          context,
          onError: (_, _) {}, // ağ hatası sessiz geçilir, gösterim etkilenmez
        );
      }
    });
  }

  /// Ekrandaki medya videoysa oynatıcıyı kurar (kaydırınca yenisine geçilir).
  void _videoKur() {
    final v = _videoUrl;
    if (v == null || v == _kuruluUrl) return;
    _kuruluUrl = v;
    final eski = _d;
    setState(() => _d = null);
    eski?.dispose();
    final d = VideoPlayerController.networkUrl(Uri.parse(v));
    d
        .initialize()
        .then((_) async {
          if (!mounted || _kuruluUrl != v) {
            d.dispose();
            return;
          }
          setState(() => _d = d);
          // Videonun GERÇEK oranı: masaüstü tuvali çerçeveyi buna göre kurar.
          final vo = d.value.aspectRatio;
          if (vo.isFinite && vo > 0) {
            _medyaOrani = vo;
            _oranBildir();
          }
          d.setLooping(true);
          // AKIŞ → REELS SÜREKLİLİĞİ (video_konum.dart): akış kartında (ya
          // da bu oturumda başka yerde) izlenen video kaldığı yerden sürer.
          final hedef = VideoKonumDefteri.devral(v, d.value.position);
          if (hedef != null) await d.seekTo(hedef);
          // Sarma beklerken kullanıcı yana kaydırmış olabilir: `_videoKur`
          // yeni URL için `_d`yi (yani bu d'yi) DISPOSE etmiştir — dinleyici
          // takmak/oynatmak patlardı.
          if (!mounted || _kuruluUrl != v) return;
          _videoDurumGuncelle(); // yalnız aktifse oynar
          d.addListener(() {
            // md. 23 ÖLÇÜSÜ ÇİZİMDEN ÖNCE: `setState` kart koparıldıysa
            // atlanır, ölçü ise her konum değişiminde güncellenmeli.
            VideoKonumDefteri.yaz(v, d.value.position, d.value.duration);
            _kova.guncelle(
              url: v,
              konum: d.value.position,
              sure: d.value.duration,
            );
            if (mounted) setState(() {});
          });
        })
        .catchError((_) {});
  }

  /// Yana kaydırma: sonraki/önceki medya; SON medyadan sonra sola kaydırınca
  /// paylaşan kişinin profiline gidilir (TikTok davranışı).
  void _yanaKaydir(double hiz) {
    final y = widget.yorum;
    if (hiz < 0) {
      if (_medyaSayfa < _medya.length - 1) {
        setState(() => _medyaSayfa++);
        _medyaDegisti();
      } else {
        kullaniciyaGit(context, y['kullanici_adi'] as String);
      }
    } else if (hiz > 0 && _medyaSayfa > 0) {
      setState(() => _medyaSayfa--);
      _medyaDegisti();
    }
  }

  /// Çoklu gönderide ekrandaki medya değişti: oynatıcı yenilenir ve tuval
  /// oranı yeni medyaya göre baştan ölçülür.
  void _medyaDegisti() {
    _videoKur();
    _medyaOrani = null;
    _oraniOlc();
    widget.onMedyaDegisti?.call();
  }

  @override
  void dispose() {
    widget.onBirak?.call(this);
    _kalpAnim.dispose();
    // ÖLÇÜ ÖNCE GİDER: `dispose()` sonrası denetleyici okunamaz. Tek gönderim
    // güvencesi izleyicinin kendisinde (ikinci çağrı istek çıkarmaz).
    _kova.gonder();
    _d?.dispose();
    super.dispose();
  }

  /// Yerel beğeni durumunu PAYLAŞILAN haritaya yazar: akış/profil kartları
  /// aynı `Map` nesnesini okur, Reels'te atılan beğeni onlara da geçer.
  void _haritayaYaz() {
    widget.yorum['begendim'] = _begendim;
    widget.yorum['begeni'] = _begeni;
  }

  Future<void> _begenToggle({bool sadeceBegen = false}) async {
    // Çift dokunuş da buraya düşer: oturumsuzda kalp uçuşup geri alınmasın,
    // doğrudan giriş istemi çıksın.
    if (!girisGerekli(context)) return;
    if (sadeceBegen && _begendim) return;
    setState(() {
      _begendim = sadeceBegen ? true : !_begendim;
      _begeni += _begendim ? 1 : -1;
    });
    _haritayaYaz();
    try {
      final d = await Api.yorumBegen(widget.yorum['id'] as int);
      // Sunucunun doğrusu yerel sayımı ezer (başkasının beğenisi arada gelmiş
      // olabilir); sonuç yine haritaya yazılır.
      _begendim = d['begendim'] == true;
      _begeni = (d['begeni'] as num?)?.toInt() ?? _begeni;
      _haritayaYaz();
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      // geri al — harita da eski hâline döner
      _begendim = !_begendim;
      _begeni += _begendim ? 1 : -1;
      _haritayaYaz();
      if (!mounted) return;
      setState(() {});
    }
  }

  void _ciftDokunus(Offset konum) {
    _begenToggle(sadeceBegen: true);
    setState(() => _kalpKonum = konum);
    _kalpAnim.forward(from: 0);
  }

  /// Tek dokunuş: video varsa durdur/oynat (TikTok davranışı).
  void _dokunus() {
    final d = _d;
    if (d == null || !d.value.isInitialized) return;
    d.value.isPlaying ? d.pause() : d.play();
  }

  Future<void> _takipToggle() async {
    if (!girisGerekli(context)) return;
    final ad = widget.yorum['kullanici_adi'] as String;
    setState(() => _takipte = !_takipte);
    // Takip durumu da paylaşılan haritada tutulur (akış kartındaki "Takip Et"
    // düğmesi aynı alanı okur).
    if (_takipBilinir) widget.yorum['takip_ediyorum'] = _takipte;
    try {
      final d = await Api.takipToggle(
        ad,
        // md. 23 atfı: bu takip TAM EKRAN GÖNDERİDEN geldi.
        kaynakGonderi: widget.yorum['id'] as int?,
      );
      final takip = d['takip'] == true;
      if (_takipBilinir) widget.yorum['takip_ediyorum'] = takip;
      if (mounted) setState(() => _takipte = takip);
    } catch (_) {
      if (_takipBilinir) widget.yorum['takip_ediyorum'] = !_takipte;
      if (mounted) setState(() => _takipte = !_takipte);
    }
  }

  String get _icerikYolu {
    final y = widget.yorum;
    if (y['sezon'] != null) {
      return '/dizi/${y['tmdb_id']}/sezon/${y['sezon']}/bolum/${y['bolum']}';
    }
    if (y['tur'] == 'person') return '/kisi/${y['tmdb_id']}';
    return '/icerik/${y['tur']}/${y['tmdb_id']}';
  }

  /// GÖNDERİNİN EK ETİKETLERİ (1 Eyl 2026): birincisi rozet satırının başında
  /// (yukarıdaki `_icerikYolu`/`icerik`), KALANLARI — oyuncular dahil —
  /// yanına dizilir. Akış kartındaki `EkEtiketSeridi` ile aynı veri: sunucu
  /// `etiketler` listesinde tümünü gönderir, ilki başlıktaki içerikle aynıdır.
  List<Map<String, dynamic>> get _ekEtiketler {
    final e = widget.yorum['etiketler'] as List<dynamic>? ?? const [];
    return e.length > 1
        ? e.sublist(1).cast<Map<String, dynamic>>()
        : const <Map<String, dynamic>>[];
  }

  /// Etiket türüne göre rozet ikonu (EkEtiketSeridi'nin daire-poster'ı yerine
  /// Reels'in ince satırına uyan küçük ikon).
  static IconData _etiketIkonu(String? tur) => tur == 'person'
      ? Icons.person_outline
      : tur == 'company'
      ? Icons.business
      : Icons.local_movies_outlined;

  // Paylaşım sayfası: kişilere DM olarak gönder + telefonun kendi paylaşım
  // sayfası (WhatsApp/e-posta/Instagram...) + bağlantıyı kopyala.
  // Akış kartı da AYNI çağrıyı yapar (gonderiPaylas).
  Future<void> _paylas() => gonderiPaylas(context, widget.yorum);

  // Reels de akış kartıyla AYNI sheet'i açar (tek açılış ayarı: yanitlariAc)
  void _yanitlarAc() => yanitlariAc(context, widget.yorum);

  /// "devamı" → Instagram altyazı sayfası gibi: aynı yorum sheet'i ama en
  /// üstte gönderi başlığı (avatar + ad + Takip Et, tam metin, tarih) ve
  /// hemen devamında yorumlar (31 Ağu 2026 isteği).
  void _metniAc() =>
      yanitlariAc(context, widget.yorum, gonderiBasligi: true).then((_) {
        // Sheet içinde takip edilmiş olabilir; durum paylaşılan haritada
        // (`takip_ediyorum`) — sheet kapanınca buradaki düğme de tazelenir.
        if (mounted) {
          setState(() => _takipte = widget.yorum['takip_ediyorum'] == true);
        }
      });

  String _sure(Duration s) {
    final dk = s.inMinutes, sn = s.inSeconds % 60;
    return '$dk:${sn.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final y = widget.yorum;
    final icerik =
        widget.icerikler['${y['tur']}:${y['tmdb_id']}']
            as Map<String, dynamic>? ??
        const {'ad': '?', 'poster': null};
    final avatar = dosyaUrl(y['avatar'] as String?);
    final d = _d;
    final foto = _fotoUrl;
    final poster = posterUrl(icerik['poster'] as String?, boyut: 'w500');
    // Android'in alt sistem çubuğu (geri/ana/menü tuşları) sabit olduğundan
    // alt bilgiler (kullanıcı/süre) ve ilerleme çubuğu onun ALTINDA kalmasın.
    final altInset = MediaQuery.of(context).padding.bottom;
    // Gönderi benim mi? İKİ yer kullanıyor: göz ikonunun "istatistikleri gör"
    // girişi (md. 23) ve üç nokta menüsünün şikâyet/sil ayrımı.
    final benimGonderi =
        y['kullanici_id'] == context.read<Oturum>().kullanici?['id'];

    Widget zemin;
    if (d != null && d.value.isInitialized) {
      final videoOrani = d.value.aspectRatio == 0
          ? 9 / 16
          : d.value.aspectRatio;
      zemin = Align(
        // Fotoğrafla AYNI hiza. Koşul YOK: ekranı dolduran videoda boş alan
        // olmadığı için hizalama kendiliğinden etkisiz kalır.
        alignment: reelsMedyaHizasi,
        child: AspectRatio(aspectRatio: videoOrani, child: VideoPlayer(d)),
      );
    } else if (_videoUrl != null) {
      zemin = const Center(
        child: CircularProgressIndicator(color: DiziRenkler.sari),
      );
    } else if (foto != null) {
      // `Center` DEĞİL `SizedBox.expand`: `Center` içinde resim KENDİ doğal
      // boyutunu alır, `alignment`ın oynayacağı boş alan kalmaz ve hizalama
      // sessizce etkisiz olur (29 Ağu 2026 emülatörde ölçüldü: üst 722 px /
      // alt 710 px — hiç kaymamış). Kutu genişleyince `contain` sığdırır,
      // `alignment` de kutunun içinde konumlandırır.
      zemin = SizedBox.expand(
        child: CachedNetworkImage(
          imageUrl: foto,
          httpHeaders: gorselBasliklari(foto),
          filterQuality: kullaniciGorselKalitesi,
          fit: BoxFit.contain,
          // Videodaki ile AYNI düzeltme (bkz. `reelsMedyaHizasi`):
          // yatay medya geometrik ortada dursa da GÖRSEL olarak aşağıda
          // kalıyor, çünkü alt şeridi kullanıcı adı/açıklama/eylem sütunu
          // kaplıyor. Emülatörde ölçüldü: yatay fotoğrafta üst boşluk 665 px,
          // alt boşluk 670 px — tam ortada.
          //
          // ORAN HESABI GEREKMEZ: `BoxFit.contain` medyayı kutuya sığdırır,
          // `alignment` de onu kutunun İÇİNDE konumlandırır. Dikey medyada
          // yüksekliğe sığdığı için dikey boş alan KALMAZ ve hizalama
          // kendiliğinden etkisizdir — ayrı bir "yatay mı" kontrolü
          // gereksiz, dolayısıyla ölçülmemiş oranla iş yapılmıyor.
          alignment: reelsMedyaHizasi,
        ),
      );
    } else {
      // Yazılı yorum: yalnız soluk poster arka planı. METİN ortada, ayrı
      // katmanda çizilir (aşağıda) — burada kalsaydı tam ekran opak dokunuş
      // katmanı etiketlerini yutardı.
      zemin = poster != null
          ? Opacity(
              opacity: 0.25,
              child: CachedNetworkImage(
                imageUrl: poster,
                httpHeaders: gorselBasliklari(poster),
                fit: BoxFit.cover,
              ),
            )
          : const SizedBox.expand();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        zemin,
        // Dokunuş katmanı: web'de video bir platform görünümüdür ve
        // dokunuşları DOM'da yutar — PointerInterceptor olayları Flutter'a
        // geri taşır. Videonun ÜSTÜNDE durmalı, diğer kontrollerin altında.
        Positioned.fill(
          child: PointerInterceptor(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dokunus,
              // Konumlu: kalp tam dokunulan yerde belirir
              onDoubleTapDown: (d) => _ciftDokunus(d.localPosition),
              onDoubleTap: () {},
              // Yana kaydırma: sonraki/önceki medya; son medyadan sonra
              // sola kaydırınca paylaşanın profili açılır.
              onHorizontalDragEnd: (detay) {
                final hiz = detay.primaryVelocity ?? 0;
                if (hiz.abs() > 250) _yanaKaydir(hiz);
              },
            ),
          ),
        ),
        // YAZILI GÖNDERİ: metin EKRANIN ORTASINDA, yumuşak köşeli koyu bir
        // blok içinde (1 Eyl 2026, 3. istek: "beğeni/kullanıcı adı Reels'teki
        // yerlerinde kalsın, yazı ortada olsun" — akış kartı kopyası GERİ
        // ALINDI, eylem sütunu ve alt blok standart Reels düzeninde).
        // Dokunuş katmanının ÜSTÜNDE ayrı katman: içindeki @kullanıcı ve
        // dizi/film etiketleri dokunulabilir kalır. deferToChild: yalnız
        // bloğun kendisi bu katmana düşer, boş alan alttaki opak katmana
        // geçer — çift dokunuş/kaydırma her yerde sürsün diye aynı eylemler
        // burada da bağlı. Alt kenar payı bloğu alt bilgi şeridinden uzak
        // tutar ama ortalamayı bozacak kadar itmez.
        if (_medya.isEmpty)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.deferToChild,
              onDoubleTapDown: (d) => _ciftDokunus(d.localPosition),
              onDoubleTap: () {},
              onHorizontalDragEnd: (detay) {
                final hiz = detay.primaryVelocity ?? 0;
                if (hiz.abs() > 250) _yanaKaydir(hiz);
              },
              child: Center(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(24, 24, 24, 140),
                  constraints: const BoxConstraints(maxWidth: 520),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  // Otomatik çeviri anahtarına UYAR (alt bloktaki ReelsMetni
                  // gibi): kapalıyken orijinal metin — yazılı gönderinin
                  // "medyası" metnin kendisi, anahtar onu da kapsamalı.
                  child: ValueListenableBuilder<ReelsCeviriKip>(
                    valueListenable: ReelsCeviri.kip,
                    builder: (context, kip, _) => EtiketliMetin(
                      reelsGosterMetni(y, kip),
                      // Reels daima koyu zemin → parlak sarı etiket
                      koyuZemin: true,
                      stil: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        // Çoklu medya sayacı sağ üstte ("3/10") — noktalar altta, alt blokta.
        if (_medya.length > 1)
          Positioned(
            top: MediaQuery.of(context).padding.top + 14,
            right: 14,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_medyaSayfa + 1}/${_medya.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        // Duraklatıldığında ortada oynat ikonu (dokunuşun görünür sonucu)
        if (d != null &&
            d.value.isInitialized &&
            !d.value.isPlaying &&
            _spoilerAcik)
          const IgnorePointer(
            child: Center(
              child: Icon(
                Icons.play_arrow_rounded,
                size: 88,
                color: Colors.white,
              ),
            ),
          ),
        // Spoiler örtüsü
        if (!_spoilerAcik)
          GestureDetector(
            onTap: () {
              setState(() => _spoilerAcik = true);
              _d?.play();
              // md. 23 agregat spoiler sayacı (kim açtı YAZILMAZ).
              GonderiOlcu.bildir(widget.yorum['id'], GonderiOlcu.spoilerAcildi);
            },
            child: Container(
              color: Colors.black.withValues(alpha: 0.85),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.visibility_off_outlined,
                      size: 44,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Spoiler olabilir — dokun ve gör'.c,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Alt karartma
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 220,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Çift dokunuş kalbi: dokunulan KONUMDA belirir, hafifçe yükselip solar
        if (_kalpKonum != null)
          AnimatedBuilder(
            animation: _kalpAnim,
            builder: (context, _) {
              final t = _kalpAnim.value; // 0→1
              if (t == 0 || t == 1) return const SizedBox.shrink();
              // Ölçek: hızlı büyür sonra sabit; opaklık: sonlara doğru solar;
              // konum: 40px yukarı kayar
              final olcek = t < 0.3 ? (0.4 + t / 0.3 * 0.9) : 1.3;
              final opaklik = t < 0.6 ? 1.0 : (1 - (t - 0.6) / 0.4);
              return Positioned(
                left: _kalpKonum!.dx - 55,
                top: _kalpKonum!.dy - 55 - t * 40,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: opaklik.clamp(0, 1),
                    child: Transform.scale(
                      scale: olcek,
                      child: const Icon(
                        Icons.favorite,
                        size: 110,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        // Alt blok: solda kullanıcı/metin/içerik, EN ALTTA ORTADA medya
        // noktaları (kullanıcılar taşıyıcı göstergesini altta arıyor).
        Positioned(
          left: 0,
          right: 0,
          bottom: 18 + altInset,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 14, right: 86),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Altyazı: profil fotoğrafı ve kullanıcı adının ÜSTÜNDE,
                    // sol altta. Cümle bitince kendini siler ve buradan hiç
                    // yer kaplamaz (altındaki blok yukarı kaymaz — yalnız
                    // altyazı katmanı çizilir, sayfa yeniden kurulmaz).
                    // Alt boşluk katmanın KENDİ kenar boşluğudur: altyazı
                    // yokken hiç çizilmez, yer tutan boşluk kalmaz.
                    if (_videoUrl != null)
                      AltyaziKatmani(
                        denetleyici: d,
                        url: _videoUrl,
                        // Sol 14 + sağ 86 dolgusu zaten eylem sütununu
                        // dışarıda bırakıyor; kalan alanın tamamı kullanılır.
                        genislikOrani: 1,
                        yaziBoyutu: 15,
                        kenarBosluk: const EdgeInsets.only(bottom: 8),
                      ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => kullaniciyaGit(
                            context,
                            y['kullanici_adi'] as String,
                          ),
                          child: KullaniciAvatari(
                            url: avatar,
                            kullaniciAdi: y['kullanici_adi'] as String?,
                            yaricap: 19,
                            // Arkaplan tema kartı (açık temada BEYAZ) olduğu
                            // için ikon da tema tonu olmalı; sabit white54
                            // açık temada beyaz üstünde kayboluyordu.
                            arkaplan: DiziRenkler.kart,
                            ikonRenk: DiziRenkler.metin54,
                            // GIF avatar Reels'te de OYNAR (md.13, 10 Ağu).
                            hareketli: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: GestureDetector(
                            onTap: () => kullaniciyaGit(
                              context,
                              y['kullanici_adi'] as String,
                            ),
                            child: Text.rich(
                              TextSpan(
                                text: '@${y['kullanici_adi']}',
                                children: [
                                  // Aile rozeti (1 Eyl 2026). MiniRozet
                                  // DEĞİL: o tema-duyarlı sariMetin kullanır;
                                  // Reels katmanı temadan bağımsız hep koyu
                                  // (beyaz yazı gibi), marka sarısı koyuda
                                  // 12:1 ile geçer.
                                  if (y['testci'] == true)
                                    const WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: Padding(
                                        padding: EdgeInsets.only(left: 3),
                                        child: Icon(
                                          Icons.verified,
                                          size: 14,
                                          color: DiziRenkler.sari,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (_takipBilinir && !_takipte)
                          SizedBox(
                            height: 30,
                            child: OutlinedButton(
                              onPressed: _takipToggle,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                side: const BorderSide(color: Colors.white),
                              ),
                              child: Text(
                                'Takip Et'.c,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    // Yorum metni: uzunsa İKİ SATIR + "devamı"; dokununca
                    // gönderi başlıklı yorum sheet'i açılır ([_metniAc]).
                    // Kırpma kararı ÖLÇÜLÜR — bkz. [ReelsMetni]. Otomatik
                    // çeviri kapalıysa orijinal metin çizilir; anahtar sağ
                    // üstte ([ReelsCeviri]).
                    if ((y['metin'] as String?)?.trim().isNotEmpty == true &&
                        (foto != null || _videoUrl != null)) ...[
                      const SizedBox(height: 8),
                      ValueListenableBuilder<ReelsCeviriKip>(
                        valueListenable: ReelsCeviri.kip,
                        builder: (context, kip, _) => ReelsMetni(
                          reelsGosterMetni(y, kip),
                          onDevami: _metniAc,
                        ),
                      ),
                    ],
                    // İçerik rozeti + EK ETİKETLER (1 Eyl 2026 isteği:
                    // "oyuncu etiketli paylaşımlarda oyuncuların etiketi
                    // gözükmüyor"). Birincil etiket akıştaki gibi başta;
                    // kalan etiketler (oyuncu/ikinci içerik) yanına dizilir.
                    // YATAY KAYDIRILIR, sarmalanmaz — alt blok yükselip
                    // medyayı boğmasın (EkEtiketSeridi ile aynı gerekçe).
                    // Etiketsiz gönderide satır HİÇ çizilmez: sarı "?" yazıp
                    // /icerik/null/null adresine götürürdü.
                    if (y['tur'] != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Flexible(
                            child: _ReelsEtiket(
                              ikon: _etiketIkonu(y['tur'] as String?),
                              metin:
                                  '${icerik['ad']}'
                                  '${y['sezon'] != null ? ' · ${'S{}B{}'.cf([y['sezon'], y['bolum']])}' : ''}',
                              onTap: () =>
                                  rotayaGitGuvenli(context, _icerikYolu),
                            ),
                          ),
                          // EK ETİKETLER SATIRA DİZİLMEZ (1 Eyl 2026, 2.
                          // istek: "isimleri tam ekrana sığmıyor"): birincil
                          // içeriğin yanında yalnız "+N" çipi durur; dokununca
                          // TÜM etiketler alttan yarım modalda listelenir —
                          // video üstte oynamaya devam eder ([etiketleriAc]).
                          if (_ekEtiketler.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => etiketleriAc(
                                context,
                                widget.yorum,
                                widget.icerikler,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.person_outline,
                                      size: 13,
                                      color: DiziRenkler.sari,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '+${_ekEtiketler.length}',
                                      style: const TextStyle(
                                        color: DiziRenkler.sari,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    if (d != null && d.value.isInitialized) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${_sure(d.value.position)} / ${_sure(d.value.duration)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Çoklu medya nokta göstergesi: ekranın tam altında, ortada.
              if (_medya.length > 1) ...[
                const SizedBox(height: 12),
                IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _medya.length; i++)
                        Container(
                          width: i == _medyaSayfa ? 8 : 5,
                          height: i == _medyaSayfa ? 8 : 5,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _medyaSayfa
                                ? Colors.white
                                : Colors.white38,
                            boxShadow: const [
                              BoxShadow(color: Colors.black45, blurRadius: 3),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        // Sağ alt: görüntülenme / beğeni / yorum / paylaş / üç nokta.
        // (`benimGonderi` yukarıda hesaplandı: hem istatistik girişi hem üç
        // nokta menüsü aynı kararı kullanır.)
        // 1 Eyl 2026 isteği: ikonlar %35 küçük (30→20, _ReelsDugme), sütun
        // sağa yaslı (right 10→4) ve üç nokta menüsü Paylaş'ın ALTINDA.
        Positioned(
          right: 4,
          bottom: 30 + altInset,
          child: Column(
            children: [
              // Görüntülenme. KENDİ gönderinde "istatistikleri gör" düğmesi
              // olur (md. 23), başkasınınkinde salt bilgi kalır — uç zaten
              // yalnız sahibine cevap veriyor, dokunulur görünüp 404 almak
              // kullanıcıyı yanıltırdı.
              _ReelsDugme(
                ikon: Icons.remove_red_eye_outlined,
                renk: benimGonderi ? DiziRenkler.sari : Colors.white,
                etiketRenk: Colors.white,
                etiket: '${(y['goruntulenme'] as num?)?.toInt() ?? 0}',
                onTap: benimGonderi
                    ? () => GoRouter.of(
                        context,
                      ).push('/gonderi-istatistik/${y['id']}')
                    : null,
              ),
              const SizedBox(height: 10),
              _ReelsDugme(
                ikon: _begendim ? Icons.favorite : Icons.favorite_border,
                renk: _begendim ? Colors.redAccent : Colors.white,
                etiket: '$_begeni',
                onTap: _begenToggle,
                onUzunBas: () => begenenleriAc(context, y['id'] as int),
              ),
              const SizedBox(height: 10),
              _ReelsDugme(
                ikon: Icons.mode_comment_outlined,
                etiket: 'Yanıtlar'.c,
                onTap: _yanitlarAc,
              ),
              const SizedBox(height: 10),
              _ReelsDugme(
                // Sohbete gönder: alt sayfada kişiler listelenir, dokunulan
                // kişiye gönderinin KENDİSİ gider (kart olarak).
                ikon: Icons.send_outlined,
                etiket: 'Paylaş'.c,
                onTap: _paylas,
              ),
              // Şikayet menüsü (kendi gönderinde ve misafirde gizli) —
              // eylemlerin EN ALTINDA durur, kendi iç dolgusu boşluğu verir.
              UcNoktaMenu(
                tur: 'yorum',
                hedefId: y['id'] as int,
                benimMi: benimGonderi,
              ),
            ],
          ),
        ),
        // En altta ince ilerleme çubuğu (IG/TikTok): dokunarak/sürükleyerek
        // sarılır; üst padding dokunma hedefini büyütür.
        if (d != null && d.value.isInitialized)
          Positioned(
            left: 0,
            right: 0,
            bottom: altInset,
            child: VideoProgressIndicator(
              d,
              allowScrubbing: true,
              padding: const EdgeInsets.only(top: 14, bottom: 2),
              colors: const VideoProgressColors(
                playedColor: DiziRenkler.sari,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
      ],
    );
  }
}

/// Reels / tek gönderi ekranındaki altyazı (gönderi metni).
///
/// En çok [satirSiniri] satır çizilir. Metin GERÇEKTEN kesiliyorsa altına
/// "devamı" bağlantısı düşer ve dokununca metnin tamamı (kendi içinde
/// kaydırılan bir kutuda) açılır; tekrar dokunulunca kapanır.
///
/// KÖK NEDEN (10 Ağu 2026, kullanıcı isteği md.14 — "içerik '.' bile olsa
/// devamı çıkıyor"): eski kod kırpma kararını HİÇBİR ŞEYE bakmadan veriyordu.
/// "devamı" metnin sonuna KOŞULSUZ eklenen bir [TextSpan]'dı ve bütün span
/// `maxLines: 2 + TextOverflow.ellipsis` ile çiziliyordu. Bunun sonucu tam
/// TERSİNEydi:
///   · metin KISAYSA ("." gibi) span iki satıra rahat sığar → "devamı" görünür,
///     oysa gösterilecek devamı YOKTUR;
///   · metin UZUNSA ellipsis ikinci satırın sonunda keser ve "devamı"nın
///     kendisi de kesilir → gerçekten devamı olan gönderide ipucu GÖRÜNMEZ.
/// Yani etiket, doğru olduğu her durumda gizleniyor, yanlış olduğu her durumda
/// gösteriliyordu. Düzeltme: kırpma [TextPainter] ile ÖLÇÜLÜR
/// (`didExceedMaxLines`) — akıştaki [KisaltilmisYorum] ve [AcilirMetin] ile
/// aynı kalıp — ve "devamı" kırpılmış gövdenin ALTINA, ayrı bir satıra konur;
/// böylece ellipsis onu yiyemez.
///
/// SINIR DURUMLARI (test/reels_devami_test.dart):
///   · tek nokta / tek emoji / yalnız boşluk → "devamı" YOK
///   · tam iki satır dolduran metin → "devamı" YOK (kesilmiyor)
///   · iki satıra sığan ama satır sonu (\n) içeren metin → "devamı" YOK
///   · üç satıra taşan metin (\n ile ya da uzunlukla) → "devamı" VAR
class ReelsMetni extends StatefulWidget {
  /// Kırpma sınırı: Reels'te altyazı medyayı boğmasın diye iki satır.
  static const satirSiniri = 2;

  final String metin;

  /// Verilirse "devamı"na (ve kırpılmış metne) dokunmak metni SATIR İÇİNDE
  /// açmak yerine bunu çağırır — Reels bununla Instagram tarzı altyazı
  /// sayfasını (gönderi başlıklı yorum sheet'i) açar (31 Ağu 2026 isteği).
  final VoidCallback? onDevami;

  const ReelsMetni(this.metin, {super.key, this.onDevami});

  @override
  State<ReelsMetni> createState() => _ReelsMetniState();
}

class _ReelsMetniState extends State<ReelsMetni> {
  static const _stil = TextStyle(color: Colors.white, height: 1.35);

  bool _acik = false;

  /// EKRANDA GERÇEKTEN kullanılacak stil. [Text] verilen stili ortamdaki
  /// [DefaultTextStyle] üstüne bindirir; ölçüm de AYNI bindirmeyi yapmalı,
  /// yoksa (ör. yazı boyutu ortamdan geliyorsa) taşma yanlış hesaplanır.
  TextStyle _cizimStili(BuildContext context) =>
      DefaultTextStyle.of(context).style.merge(_stil);

  @override
  void didUpdateWidget(ReelsMetni eski) {
    super.didUpdateWidget(eski);
    // PageView sayfa öğelerini geri dönüştürebilir: başka gönderinin metni
    // geldiyse açık/kapalı durum devralınmamalı.
    if (eski.metin != widget.metin) _acik = false;
  }

  @override
  Widget build(BuildContext context) {
    // Yalnız boşluktan ibaret metin hiç çizilmez (boş kutu / yer tutucu yok).
    if (widget.metin.trim().isEmpty) return const SizedBox.shrink();
    final stil = _cizimStili(context);

    if (_acik) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _acik = false),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.42,
          ),
          child: SingleChildScrollView(child: Text(widget.metin, style: stil)),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, kisit) {
        // Ölçüm ile çizim AYNI stil, AYNI genişlik ve AYNI metin scaler'ıyla
        // yapılmalı; yoksa taşma yanlış hesaplanır.
        final olcer = TextPainter(
          text: TextSpan(text: widget.metin, style: stil),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: ReelsMetni.satirSiniri,
        )..layout(maxWidth: kisit.maxWidth);
        final tasiyor = olcer.didExceedMaxLines;
        olcer.dispose();

        final govde = Text(
          widget.metin,
          style: stil,
          maxLines: ReelsMetni.satirSiniri,
          // Sınırdan KISA metinde ellipsis konmaz → üç nokta da çıkmaz.
          overflow: tasiyor ? TextOverflow.ellipsis : TextOverflow.clip,
        );
        if (!tasiyor) return govde;

        return Semantics(
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDevami ?? () => setState(() => _acik = true),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                govde,
                Text(
                  'devamı'.c,
                  style: stil.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Reels alt rozet satırındaki birincil içerik etiketi: sarı ikon + ad.
/// (1 Eyl 2026, 2. istek: ek etiketler artık satıra dizilmiyor — "+N" çipi
/// [etiketleriAc] modalını açıyor; bu widget yalnız birincil rozeti çizer.)
class _ReelsEtiket extends StatelessWidget {
  final IconData ikon;
  final String metin;
  final VoidCallback onTap;

  const _ReelsEtiket({
    required this.ikon,
    required this.metin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 15, color: DiziRenkler.sari),
          const SizedBox(width: 5),
          // Uzun ad kendi içinde kırpılır (üst Row'daki Flexible daraltır).
          Flexible(
            child: Text(
              metin,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: DiziRenkler.sari,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// GÖNDERİNİN TÜM ETİKETLERİNİ (birincil içerik + oyuncular/ikinci içerikler)
/// alttan açılan YARIM modalda listeler (1 Eyl 2026, 2. istek: "isimleri tam
/// ekrana sığmıyor... yorumlardaki gibi modal aç, tam ekran olmasın, %60-70
/// kaplasın, video yukarıda oynamaya devam etsin").
///
/// TAM EKRAN DEĞİL: yükseklik tavanı ekranın %65'i ([_EtiketlerSheet]);
/// yorum sheet'inin aksine `isScrollControlled` yine true — yükseklik
/// denetimi çocuktaki ConstrainedBox'ta, yoksa varsayılan tavan %56'ya
/// (9/16) kilitliyordu. Reels sayfası sökülmediği için VİDEO DURMAZ:
/// `_videoDurumGuncelle` yalnız sayfa aktifliğine bakar, modal onu değiştirmez.
///
/// Satıra dokununca [rotayaGitGuvenli] hem modalı hem Reels katmanını
/// kapatıp hedef sayfayı açar (yoksa sayfa Reels'in altında kalırdı).
Future<void> etiketleriAc(
  BuildContext context,
  Map<String, dynamic> yorum,
  Map<String, dynamic> icerikler,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  // Yorum sheet'iyle aynı genişlik disiplini: masaüstünde 720 kolonda,
  // mobilde tam genişlik.
  constraints: const BoxConstraints(maxWidth: masaustuKolonGenisligi),
  backgroundColor: DiziRenkler.koyuGri,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
  ),
  builder: (_) => _EtiketlerSheet(yorum: yorum, icerikler: icerikler),
);

class _EtiketlerSheet extends StatelessWidget {
  final Map<String, dynamic> yorum;
  final Map<String, dynamic> icerikler;

  const _EtiketlerSheet({required this.yorum, required this.icerikler});

  @override
  Widget build(BuildContext context) {
    final etiketler = (yorum['etiketler'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return ConstrainedBox(
      // %65: istenen %60-70 bandının ortası — üstte video görünür kalır.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          // Tutamaç: alttan sürüklenip kapanabildiğinin görsel ipucu.
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              'Etiketler'.c,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.only(
                bottom: 12 + MediaQuery.of(context).padding.bottom,
              ),
              itemCount: etiketler.length,
              itemBuilder: (context, i) {
                final e = etiketler[i];
                final tur = e['tur'] as String?;
                final bilgi =
                    icerikler['$tur:${e['tmdb_id']}']
                        as Map<String, dynamic>? ??
                    const {'ad': '?', 'poster': null};
                final sezon = e['sezon'] as int?;
                final bolum = e['bolum'] as int?;
                final poster = posterUrl(
                  bilgi['poster'] as String?,
                  boyut: 'w92',
                );
                final yol = tur == 'person'
                    ? '/kisi/${e['tmdb_id']}'
                    : bolum != null
                    ? '/dizi/${e['tmdb_id']}/sezon/$sezon/bolum/$bolum'
                    : '/icerik/$tur/${e['tmdb_id']}';
                return ListTile(
                  onTap: () => rotayaGitGuvenli(context, yol),
                  leading: ClipOval(
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: poster == null
                          ? Container(
                              color: DiziRenkler.acikGri,
                              child: Icon(
                                tur == 'person'
                                    ? Icons.person
                                    : tur == 'company'
                                    ? Icons.business
                                    : Icons.movie_outlined,
                                size: 18,
                                color: DiziRenkler.metin38,
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: poster,
                              httpHeaders: gorselBasliklari(poster),
                              fit: tur == 'company'
                                  ? BoxFit.contain
                                  : BoxFit.cover,
                            ),
                    ),
                  ),
                  title: Text(
                    '${bilgi['ad']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: bolum != null
                      ? Text(
                          'S{}B{}'.cf([sezon, bolum]),
                          style: const TextStyle(color: Colors.white54),
                        )
                      : null,
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white38,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelsDugme extends StatelessWidget {
  final IconData ikon;
  final Color renk;

  /// Etiket rengi ikondan AYRI: beğenilen kalp kırmızı olurken sayısı beyaz
  /// kalır. Görüntülenme sayacı ise geri planda durmalı (white70).
  final Color etiketRenk;
  final String etiket;

  /// null → düğme SALT BİLGİDİR (dokunulamaz). Başkasının gönderisindeki
  /// görüntülenme sayısı böyle çizilir: dokunulur görünüp 404 almak
  /// kullanıcıyı yanıltırdı.
  final VoidCallback? onTap;

  /// Basılı tutma eylemi (beğeni düğmesinde: beğenenler listesi). Uzun basma
  /// tanınınca [onTap] ateşlenmez — liste açmak beğeni atmaz.
  final VoidCallback? onUzunBas;
  const _ReelsDugme({
    required this.ikon,
    required this.etiket,
    this.onTap,
    this.onUzunBas,
    this.renk = Colors.white,
    this.etiketRenk = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      onLongPress: onUzunBas,
      child: Padding(
        // İkon %35 küçüldü (1 Eyl 2026: 30→20); dolgu BÜYÜDÜ ki dokunma
        // hedefi 44px'e yakın kalsın (ux md.2 — ikonu değil dolguyu büyüt).
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          children: [
            Icon(ikon, size: 20, color: renk),
            const SizedBox(height: 2),
            Text(etiket, style: TextStyle(color: etiketRenk, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

/// Yanıtlar alt sayfası: bu yoruma verilen yanıtlar + yanıt yazma.

/// Gönderinin yanıt sheet'ini açar (Reels, profil yorum akışı vb.).
/// TAM AÇILIR: sheet ekranın tamamını (durum çubuğu hariç) kaplar; eskiden
/// ekranın %60'ında takılıydı ve klavye açılınca yazma kutusu ortada kalıyordu.
///
/// [ilkYanitlanan]: sheet açılır açılmaz hedeflenecek YANIT satırı (yanıtın
/// yanıtı). İçerik sayfasının yorum bölümü bunu kullanır: kullanıcı bir
/// yanıta "Yanıtla" dediğinde sheet ÜST yorumla açılır ama hedef kaybolmaz.
/// Reels'te gösterilecek gönderi metni. SARI kipte sunucunun verdiği (gerekirse
/// çevrilmiş) metin; BEYAZ ve GRİ kipte orijinal metin — gri "çeviri yok"
/// demek, gönderinin KENDİ yazısı gizlenmez (yazılı gönderide bomboş ekran
/// olurdu); gri yalnız video ALTYAZISINI tamamen kapatır (bkz. [ReelsCeviri]).
String reelsGosterMetni(Map<String, dynamic> y, ReelsCeviriKip kip) {
  final m = y['metin'] as String? ?? '';
  if (kip == ReelsCeviriKip.ceviri) return m;
  return (y['orijinal_metin'] as String?) ?? m;
}

Future<void> yanitlariAc(
  BuildContext context,
  Map<String, dynamic> yorum, {
  Map<String, dynamic>? ilkYanitlanan,
  bool gonderiBasligi = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  // Yorumlar da bir OKUMA kolonu: masaüstünde sheet 1920 dp'ye yayılınca
  // avatar solda, saat sağda, arası bomboş kalıyordu. Akışla AYNI genişlik
  // ([masaustuKolonGenisligi]) — sheet o zaman yatayda ortalanır.
  // MOBİLDE ETKİSİZ: 360-430 dp ekranda kısıt bağlamaz, sheet tam genişlik.
  constraints: const BoxConstraints(maxWidth: masaustuKolonGenisligi),
  backgroundColor: DiziRenkler.koyuGri,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
  ),
  builder: (_) => YanitlarSheet(
    yorum: yorum,
    ilkYanitlanan: ilkYanitlanan,
    gonderiBasligi: gonderiBasligi,
  ),
);

/// Yorum kutusunun üstündeki 8'li hızlı emoji satırının kaynağı.
///
/// Sunucu `/emojiler/sik` ucundan KENDİ yorumlarındaki emojileri (`benim`) ve
/// uygulama genelindekileri (`genel`) döndürür — ayrı bir takip tablosu yok,
/// mevcut yorum metinleri sayılır. Kendi listen kısa kalırsa genel liste,
/// ikisi de boşsa [yedek] tamamlar; satır asla boş görünmez.
/// Sonuç oturum boyunca istemcide tutulur (her sheet açılışında istek atılmaz).
class SikEmojiler {
  static const int adet = 8;

  /// Yeni kurulumda (hiç yorum yokken) gösterilen sabit liste.
  static const List<String> yedek = [
    '😂',
    '❤️',
    '🔥',
    '👏',
    '😍',
    '😮',
    '😢',
    '👍',
  ];

  /// Oturum önbelleği. Testler doğrudan yazabilir (ağ isteği atılmaz).
  static List<String>? onbellek;

  /// Sıralı birleştirme: önce kişinin kendi emojileri, sonra uygulama geneli,
  /// eksik kalırsa yedek. Tekrar eden emoji bir kez yazılır.
  static List<String> birlestir(List<String> benim, List<String> genel) {
    final liste = <String>[];
    for (final e in [...benim, ...genel, ...yedek]) {
      if (e.trim().isEmpty || liste.contains(e)) continue;
      liste.add(e);
      if (liste.length == adet) break;
    }
    return liste;
  }

  static Future<List<String>> getir() async {
    if (onbellek != null) return onbellek!;
    // `/emojiler/sik` girisZorunlu: oturumsuzda 401 yerine sabit liste.
    if (!Api.girisli) return yedek;
    try {
      final d = await Api.get('/emojiler/sik') as Map<String, dynamic>;
      final liste = birlestir(
        (d['benim'] as List<dynamic>? ?? []).cast<String>(),
        (d['genel'] as List<dynamic>? ?? []).cast<String>(),
      );
      onbellek = liste;
      return liste;
    } catch (_) {
      // Önbelleğe YAZMA: bir sonraki açılışta tekrar denensin.
      return yedek;
    }
  }
}

/// Metnin [secim] konumuna emoji ekler, imleci emojinin sonuna taşır.
/// Seçim yoksa (imleç kaybolmuşsa) metnin sonuna eklenir.
TextEditingValue emojiEkle(TextEditingValue deger, String emoji) {
  final metin = deger.text;
  final secim = deger.selection;
  final bas = secim.isValid ? secim.start.clamp(0, metin.length) : metin.length;
  final son = secim.isValid ? secim.end.clamp(0, metin.length) : metin.length;
  return TextEditingValue(
    text: metin.replaceRange(bas, son, emoji),
    selection: TextSelection.collapsed(offset: bas + emoji.length),
  );
}

/// Bir Reels yanıtına eklenebilecek en çok medya.
///
/// SUNUCU TAVANI 10 (`POST /yorumlar`, `medya.length > 10` → 400); buradaki 4
/// bilinçli olarak daha düşük: yanıt kutusu klavyenin üstünde dar bir sheet'in
/// dibinde duruyor ve 60 dp'lik ek karoları 360 dp genişlikte tek satıra ancak
/// 4 tane sığıyor. Ana yorum kutusunda (tam sayfa) tavan `enCokEk` = 10.
const enCokYanitEk = 4;

/// Bir gönderinin yanıtları + yazma kutusu. Reels ve profil yorum akışı
/// AYNI sheet'i kullanır: beğeni ve yanıtlar tek veri kaynağından geldiği için
/// nerede atılırsa atılsın her iki tarafta da görünür.
class YanitlarSheet extends StatefulWidget {
  final Map<String, dynamic> yorum;

  /// Açılışta hedeflenecek yanıt satırı (bkz. [yanitlariAc]).
  final Map<String, dynamic>? ilkYanitlanan;

  /// TRUE ise listenin başında GÖNDERİ BAŞLIĞI çizilir: avatar + ad + Takip
  /// Et, gönderinin TAM metni ve paylaşım tarihi; yorumlar hemen devamında
  /// akar — Instagram'ın altyazı sayfası kalıbı. Reels'te "devamı" bununla
  /// açar (31 Ağu 2026 isteği); yorum düğmesi eskisi gibi başlıksız açar.
  final bool gonderiBasligi;

  const YanitlarSheet({
    super.key,
    required this.yorum,
    this.ilkYanitlanan,
    this.gonderiBasligi = false,
  });

  @override
  State<YanitlarSheet> createState() => _YanitlarSheetState();
}

class _YanitlarSheetState extends State<YanitlarSheet> {
  List<dynamic>? _yanitlar;
  final _kutu = TextEditingController();
  final _liste = ScrollController();
  // Sheet ekranı kapladığı için kök ScaffoldMessenger'ın SnackBar'ı ARKADA
  // kalır; sheet kendi messenger'ını taşır, hatalar burada görünür.
  final _mesajci = GlobalKey<ScaffoldMessengerState>();
  bool _gonderiliyor = false;
  final List<Map<String, dynamic>> _ekler = []; // {yol, video}
  bool _ekYukleniyor = false;
  // Çoklu yüklemede ilerleme ("3/5"): kullanıcı takıldı sanmasın
  // (ui-ux-pro-max, Feedback/Progress Indicators).
  int _ekToplam = 0;
  int _ekBiten = 0;
  // Medya yüklenirken gönder'e basıldı: yükleme bitince metin+medya BİRLİKTE
  // gider (sohbet ekranında medyasız gönderim hatası buradan çıkmıştı).
  bool _gonderBekliyor = false;
  bool _yaziVar = false; // gönder düğmesi bu bayrakla belirir
  late Map<String, dynamic>? _yanitlanan = // yanıtın yanıtı: hedeflenen satır
      widget.ilkYanitlanan;
  List<String> _emojiler = SikEmojiler.onbellek ?? SikEmojiler.yedek;

  // Gönderi başlığındaki Takip Et — [_ReelSayfaState._takipToggle] ile aynı
  // mantık; durum PAYLAŞILAN haritaya da yazılır ki sheet kapanınca Reels
  // sayfasındaki düğme tutarlı kalsın (orası kapanışta haritadan okur).
  late bool _takipte = widget.yorum['takip_ediyorum'] == true;
  late final bool _takipBilinir =
      widget.yorum.containsKey('takip_ediyorum') &&
      widget.yorum['benim'] != true;

  @override
  void initState() {
    super.initState();
    _kutu.addListener(_metinDegisti);
    _yukle();
    _emojileriYukle();
  }

  @override
  void dispose() {
    _kutu.removeListener(_metinDegisti);
    _kutu.dispose();
    _liste.dispose();
    super.dispose();
  }

  void _metinDegisti() {
    final dolu = _kutu.text.trim().isNotEmpty;
    if (dolu != _yaziVar) setState(() => _yaziVar = dolu);
  }

  Future<void> _emojileriYukle() async {
    final liste = await SikEmojiler.getir();
    if (mounted && !listEquals(liste, _emojiler)) {
      setState(() => _emojiler = liste);
    }
  }

  void _uyar(String mesaj) =>
      _mesajci.currentState?.showSnackBar(SnackBar(content: Text(mesaj)));

  Future<void> _takipToggle() async {
    if (!girisGerekli(context)) return;
    final ad = widget.yorum['kullanici_adi'] as String;
    setState(() => _takipte = !_takipte);
    if (_takipBilinir) widget.yorum['takip_ediyorum'] = _takipte;
    try {
      final d = await Api.takipToggle(
        ad,
        kaynakGonderi: widget.yorum['id'] as int?,
      );
      final takip = d['takip'] == true;
      if (_takipBilinir) widget.yorum['takip_ediyorum'] = takip;
      if (mounted) setState(() => _takipte = takip);
    } catch (_) {
      if (_takipBilinir) widget.yorum['takip_ediyorum'] = !_takipte;
      if (mounted) setState(() => _takipte = !_takipte);
    }
  }

  /// Listenin 0. satırı ([YanitlarSheet.gonderiBasligi] kipinde): solda
  /// avatar + ad (profile götürür), sağda Takip Et; altında gönderinin TAM
  /// metni (otomatik çeviri tercihine uyar) ve paylaşım tarihi. Instagram'ın
  /// altyazı sayfası kalıbı — yorumlar hemen devamında.
  Widget _gonderiBaslik() {
    final y = widget.yorum;
    final ad = y['kullanici_adi'] as String? ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Row(
          children: [
            GestureDetector(
              onTap: ad.isEmpty ? null : () => kullaniciyaGit(context, ad),
              child: KullaniciAvatari(
                url: dosyaUrl(y['avatar'] as String?),
                kullaniciAdi: ad,
                yaricap: 18,
                arkaplan: DiziRenkler.kart,
                ikonRenk: DiziRenkler.metin54,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: ad.isEmpty ? null : () => kullaniciyaGit(context, ad),
                child: Text(
                  '@$ad',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            if (_takipBilinir && !_takipte) ...[
              const SizedBox(width: 10),
              SizedBox(
                height: 30,
                child: OutlinedButton(
                  key: const Key('baslik-takip'),
                  onPressed: _takipToggle,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    side: BorderSide(color: DiziRenkler.sariMetin),
                  ),
                  child: Text(
                    'Takip Et'.c,
                    style: TextStyle(
                      color: DiziRenkler.sariMetin,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        ValueListenableBuilder<ReelsCeviriKip>(
          valueListenable: ReelsCeviri.kip,
          builder: (context, kip, _) => Text(
            reelsGosterMetni(y, kip),
            style: const TextStyle(height: 1.4),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          tarihBicimle(y['tarih']),
          style: TextStyle(fontSize: 12, color: DiziRenkler.metin54),
        ),
        const SizedBox(height: 10),
        Divider(color: DiziRenkler.metin12, height: 1),
        const SizedBox(height: 8),
      ],
    );
  }

  void _emojiSec(String emoji) {
    _kutu.value = emojiEkle(_kutu.value, emoji);
  }

  /// Boş yorum listesi göstergesi (hem ortalanmış hem başlık-altı kipte).
  Widget _bosDurum() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.forum_outlined, size: 34, color: DiziRenkler.metin24),
      const SizedBox(height: 8),
      Text('Henüz yorum yok.'.c, style: TextStyle(color: DiziRenkler.metin54)),
      const SizedBox(height: 4),
      Text(
        'İlk yorumu sen yaz'.c,
        style: TextStyle(fontSize: 12, color: DiziRenkler.metin38),
      ),
    ],
  );

  String get _sorgu => widget.yorum['sezon'] != null
      ? '?sezon=${widget.yorum['sezon']}&bolum=${widget.yorum['bolum']}'
      : '';

  Future<void> _yukle() async {
    try {
      final d = await Api.get(
        '/yorumlar/${widget.yorum['tur']}/${widget.yorum['tmdb_id']}$_sorgu',
      );
      if (!mounted) return;
      setState(() {
        _yanitlar =
            (d['yorumlar'] as List<dynamic>)
                .where((c) => c['ust_id'] == widget.yorum['id'])
                .toList()
              // Sohbet akışı gibi eskiden yeniye
              ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
      });
    } catch (_) {
      if (mounted) setState(() => _yanitlar = []);
    }
  }

  Future<void> _sil(int id) async {
    try {
      await Api.delete('/yorumlar/$id');
      await _yukle();
    } catch (e) {
      if (mounted) _uyar(e.toString());
    }
  }

  /// Fotoğraf / video eki: sistem Fotoğraf Seçici → **inceleme/düzenleme
  /// ekranı** (kalem = görsel editörü, makas = video trim) → yükleme.
  ///
  /// ÇOKLU SEÇİM AÇIK — veri modeli destekliyor: Reels yanıtı da bir
  /// YORUMDUR, `POST /yorumlar`a gider (aşağıdaki [_gonder]) ve
  /// `yorumlar.medya` kolonu **TEXT[]**'tir (`backend/sema.sql:68`); sunucu
  /// tek istekte 10 medyaya kadar kabul eder (`server.js:4884`). Sohbetteki
  /// tek dosya sınırı buraya UYGULANMAZ, çünkü orada kolon TEXT.
  ///
  /// Buradaki tavan [enCokYanitEk] (4), sunucununkinden (10) bilerek düşük:
  /// yanıt kutusu dar bir sheet'in dibinde ve karolar tek satıra sığmalı.
  Future<void> _ekSec() async {
    if (!girisGerekli(context)) return;
    final kalan = enCokYanitEk - _ekler.length;
    if (kalan <= 0 || _ekYukleniyor) return;
    final secim = await medyaSec(context, azami: kalan);
    if (secim.isEmpty || !mounted) return;
    await _ekYukle(secim);
  }

  /// GIF eki. Dış GIF servisi (Giphy/Tenor) YOK — anahtar/gizli bilgi
  /// gerektirir; kullanıcının kendi dosyalarından .gif seçilir. Sunucu GIF'i
  /// sihirli baytla doğrular ve kırpmadan geçirir (animasyon bozulmaz).
  ///
  /// NEDEN HÂLÂ `FilePicker`, NEDEN [medyaSec] DEĞİL (7 Ağu 2026 kararı):
  /// [medyaSec] GIF'i *kapsıyor* (Fotoğraf Seçici GIF'leri görsel olarak
  /// listeler, inceleme ekranı GIF'i sihirli bayttan tanıyıp editörü hiç
  /// açmaz), ama iki şeyi KAPSAMIYOR:
  ///   1. **Uzantıya göre filtre.** Android Fotoğraf Seçici yalnız
  ///      "görsel/video" ayrımı yapar; "yalnız GIF göster" diye bir kip yok.
  ///      Bu düğmenin tek varlık nedeni o filtre.
  ///   2. **MediaStore dışındaki dosyalar.** Tarayıcıdan indirilen GIF'ler
  ///      çoğu cihazda galeriye değil `Downloads`a düşer; Fotoğraf Seçici
  ///      onları göstermez, SAF (`ACTION_GET_CONTENT`) gösterir.
  /// İzin açısından risk yok: `file_picker` de SAF kullanır, `READ_MEDIA_*`
  /// istemez — Play reddine yol açan şey uygulama içi galeri ızgarasıydı.
  /// Yükleme/sınır/hata yolu ise artık ORTAK ([medyalariYukle]).
  /// 29 AĞU 2026 — ARTIK ÖNCE KENDİ ARŞİVİMİZ AÇILIR.
  /// Dış GIF servisi kurmadık (Tenor kapandı, Giphy saatlik sınırlı ve ücretli,
  /// Klipy proxy/önbelleği yasaklıyor). [gifSecAc] arşivi gösterir; oradaki
  /// "GIF yükle" düğmesi ise yukarıda anlatılan `file_picker` yolunun TA
  /// KENDİSİDİR — yani dosyadan seçme yolu KAYBOLMADI, arşivin içine taşındı.
  Future<void> _gifSec() async {
    if (!girisGerekli(context)) return;
    if (_ekler.length >= enCokYanitEk || _ekYukleniyor) return;
    final gif = await gifSecAc(context);
    if (gif == null || !mounted) return;
    final yol = gif['yol'] as String?;
    if (yol == null) return;
    // GIF sunucuda ZATEN duruyor: yeniden yüklemeye gerek yok, doğrudan ek olur.
    setState(() => _ekler.add({'yol': yol, 'video': false}));
    // Yükleme sürerken gönder'e basılmışsa aynı kural: bekleyen gönderimi sür.
    if (_gonderBekliyor && !_ekYukleniyor) {
      _gonderBekliyor = false;
      await _gonder();
    }
  }

  /// Seçilen dosyaları SIRAYLA yükler ve ek karolarına ekler.
  ///
  /// KISMİ BAŞARI: bir dosya patlarsa geri kalanı yüklenmeye devam eder ve
  /// sonunda kaçının yüklendiği/yüklenemediği söylenir — sessiz kayıp YOK
  /// (`yorumlar.dart` ile aynı kalıp, kod ORTAK: [medyalariYukle]).
  Future<void> _ekYukle(List<XFile> dosyalar) async {
    setState(() {
      _ekYukleniyor = true;
      _ekToplam = dosyalar.length;
      _ekBiten = 0;
    });
    MedyaYuklemeSonuc sonuc;
    try {
      sonuc = await medyalariYukle(
        dosyalar,
        adim: (biten) {
          if (mounted) setState(() => _ekBiten = biten);
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _ekYukleniyor = false;
          _ekToplam = 0;
          _ekBiten = 0;
        });
      }
    }
    if (!mounted) return;
    setState(() => _ekler.addAll(sonuc.yuklenen));
    final bildirim = sonuc.bildirim;
    if (bildirim != null) {
      _gonderBekliyor = false; // yükleme aksadı: bekleyen gönderim iptal
      _uyar(bildirim);
    }
    // Yükleme sürerken gönder'e basılmışsa şimdi gönder: metin de medya da
    // kaybolmaz.
    if (_gonderBekliyor) {
      _gonderBekliyor = false;
      await _gonder();
    }
  }

  Future<void> _gonder() async {
    if (!girisGerekli(context)) return;
    final metin = _kutu.text.trim();
    if (metin.isEmpty || _gonderiliyor) return;
    if (_ekYukleniyor) {
      // Yükleme bitmeden gönderilirse medya eksik giderdi; sıraya al.
      setState(() => _gonderBekliyor = true);
      return;
    }
    setState(() => _gonderiliyor = true);
    try {
      final y = widget.yorum;
      await Api.post('/yorumlar', {
        'tur': y['tur'],
        'tmdb_id': y['tmdb_id'],
        if (y['sezon'] != null) 'sezon': y['sezon'],
        if (y['sezon'] != null) 'bolum': y['bolum'],
        'metin': metin,
        'medya': _ekler.map((e) => e['yol']).toList(),
        // Bir yanıta yanıt veriliyorsa onun id'si gider; sunucu üst yoruma
        // bağlar ve yanıtlanan kişiye bildirim düşer.
        'ust_id': _yanitlanan?['id'] ?? y['id'],
      });
      _kutu.clear();
      _ekler.clear();
      _yanitlanan = null;
      await _yukle();
      // Başarı görünür olsun: yeni yanıt listenin sonunda, oraya kaydır.
      if (mounted && _liste.hasClients) {
        await _liste.animateTo(
          _liste.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) _uyar(e.toString());
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  /// Yazma kutusunun içindeki kompakt eylem ikonu (dosya / GIF / gönder).
  /// Dokunma hedefi 44x44: ikon 22 px kalır, PADDING büyütülür.
  Widget _kutuIkonu({
    required String ipucu,
    required IconData ikon,
    required VoidCallback onTap,
    bool kapali = false,
    bool yukleniyor = false,
  }) {
    return Tooltip(
      message: ipucu,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: kapali ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: yukleniyor
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: DiziRenkler.sari,
                  ),
                )
              : Icon(
                  ikon,
                  size: 22,
                  color: kapali ? DiziRenkler.metin38 : DiziRenkler.sari,
                ),
        ),
      ),
    );
  }

  /// Sık kullanılan 8 emoji, yazma satırının ÜSTÜNDE yan yana. Dar ekranda
  /// (360 dp) sığmazsa yatay kaydırılır — taşma çizgisi çıkmaz, hepsi
  /// erişilebilir kalır.
  Widget _emojiSatiri() {
    const olcu = 44.0; // dokunma hedefi
    final dugmeler = [
      for (final e in _emojiler)
        InkWell(
          key: ValueKey('emoji-$e'),
          borderRadius: BorderRadius.circular(22),
          onTap: () => _emojiSec(e),
          child: SizedBox(
            width: olcu,
            height: olcu,
            child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
          ),
        ),
    ];
    return SizedBox(
      height: olcu,
      child: LayoutBuilder(
        builder: (_, kisit) => olcu * dugmeler.length <= kisit.maxWidth
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: dugmeler,
              )
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: dugmeler),
              ),
      ),
    );
  }

  /// Yazma satırı: SOLDA profil fotoğrafı, ortada metin alanı, SAĞDA
  /// (dosya + GIF) ya da yazı yazılmışsa (gönder).
  Widget _girisSatiri(Map<String, dynamic>? ben) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: KullaniciAvatari(
            url: dosyaUrl(ben?['avatar'] as String?),
            kullaniciAdi: ben?['kullanici_adi'] as String?,
            yaricap: 16,
            arkaplan: DiziRenkler.kart,
            // Yanıt yazma satırı Reels yüzeyinin parçası (md.13).
            hareketli: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: EtiketliGirdi(
            controller: _kutu,
            maxLength: 1000,
            maxLines: 4,
            minLines: 1,
            decoration: InputDecoration(
              // KULLANICI İSTEĞİ (7 Ağu): "(@ ile etiketle)" ipucundan çıktı.
              hintText: 'Yorum yaz...'.c,
              isDense: true,
              contentPadding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _yaziVar
                      // Yazı yazılınca yalnız GÖNDER kalır
                      ? [
                          _kutuIkonu(
                            ipucu: 'Gönder'.c,
                            ikon: Icons.send,
                            kapali: _gonderiliyor || _gonderBekliyor,
                            yukleniyor: _gonderiliyor || _gonderBekliyor,
                            onTap: _gonder,
                          ),
                        ]
                      // Boşken dosya ve GIF ekleme
                      : [
                          _kutuIkonu(
                            ipucu: 'Fotoğraf / video ekle'.c,
                            ikon: Icons.attach_file,
                            kapali:
                                _ekYukleniyor || _ekler.length >= enCokYanitEk,
                            yukleniyor: _ekYukleniyor,
                            onTap: _ekSec,
                          ),
                          _kutuIkonu(
                            ipucu: 'GIF ekle'.c,
                            ikon: Icons.gif_box_outlined,
                            kapali:
                                _ekYukleniyor || _ekler.length >= enCokYanitEk,
                            onTap: _gifSec,
                          ),
                        ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final olcum = MediaQuery.of(context);
    final klavye = olcum.viewInsets.bottom;
    // TAM AÇILIŞ: kullanılabilir yüksekliğin tamamı (eskiden ekranın %60'ı).
    // Klavye açılınca sheet kısalır, yazma kutusu klavyenin ÜSTÜNDE kalır.
    final yukseklik = (olcum.size.height - olcum.padding.top - klavye).clamp(
      200.0,
      olcum.size.height,
    );
    final ben = context.watch<Oturum>().kullanici;
    return Padding(
      padding: EdgeInsets.only(bottom: klavye),
      child: SizedBox(
        height: yukseklik,
        // Sheet ekranı kapladığı için kök SnackBar arkada kalırdı; sheet kendi
        // messenger'ını taşıyor (hata mesajları görünür).
        child: ScaffoldMessenger(
          key: _mesajci,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            resizeToAvoidBottomInset: false, // klavye payı zaten yukarıda
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 2),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: DiziRenkler.metin24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.mode_comment_outlined,
                        size: 18,
                        color: DiziRenkler.sari,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Yanıtlar'.c,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_yanitlar?.length ?? ''}',
                        style: TextStyle(color: DiziRenkler.metin54),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Kapat'.c,
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(Icons.close, color: DiziRenkler.metin54),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _yanitlar == null
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: DiziRenkler.sari,
                          ),
                        )
                      // Başlık kipinde boş liste ORTALANMAZ: gönderi başlığı
                      // her zaman üstte durur, boş durum onun altına yazılır.
                      : (_yanitlar!.isEmpty && !widget.gonderiBasligi
                            ? Center(child: _bosDurum())
                            : ListView.builder(
                                controller: _liste,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                itemCount:
                                    (widget.gonderiBasligi ? 1 : 0) +
                                    (_yanitlar!.isEmpty
                                        ? 1
                                        : _yanitlar!.length),
                                itemBuilder: (context, i) {
                                  if (widget.gonderiBasligi) {
                                    if (i == 0) return _gonderiBaslik();
                                    i -= 1;
                                  }
                                  if (_yanitlar!.isEmpty) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 28,
                                      ),
                                      child: _bosDurum(),
                                    );
                                  }
                                  final c =
                                      _yanitlar![i] as Map<String, dynamic>;
                                  return _KesfetYanitSatiri(
                                    key: ValueKey(c['id']),
                                    yanit: c,
                                    benim: c['kullanici_id'] == ben?['id'],
                                    sil: () => _sil(c['id'] as int),
                                    yanitla: () =>
                                        setState(() => _yanitlanan = c),
                                  );
                                },
                              )),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: DiziRenkler.metin12)),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_yanitlanan != null)
                          Row(
                            children: [
                              const Icon(
                                Icons.reply,
                                size: 16,
                                color: DiziRenkler.sari,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '@{} kullanıcısına yanıt veriyorsun'.cf([
                                    _yanitlanan!['kullanici_adi'],
                                  ]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: DiziRenkler.sari,
                                  ),
                                ),
                              ),
                              InkWell(
                                borderRadius: BorderRadius.circular(22),
                                onTap: () => setState(() => _yanitlanan = null),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: DiziRenkler.metin38,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        // Çok dosya yüklenirken BELİRLİ ilerleme çubuğu +
                        // "3/5" (ui-ux-pro-max, Feedback/Progress Indicators:
                        // "Step 2 of 4 indicator" / "Don't: No indication of
                        // progress"). Tek dosyada çıkmaz: ataç ikonundaki
                        // spinner zaten yeterli, dar sheet'te fazlalık olur.
                        if (_ekYukleniyor && _ekToplam > 1)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: _ekBiten / _ekToplam,
                                      minHeight: 4,
                                      backgroundColor: DiziRenkler.metin12,
                                      color: DiziRenkler.sari,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$_ekBiten/$_ekToplam',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: DiziRenkler.metin70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_ekler.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Wrap(
                              spacing: 8,
                              children: [
                                for (var i = 0; i < _ekler.length; i++)
                                  Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: SizedBox(
                                          width: 60,
                                          height: 60,
                                          child: _ekler[i]['video'] == true
                                              ? Container(
                                                  color: DiziRenkler.kart,
                                                  child: Icon(
                                                    Icons.videocam,
                                                    color: DiziRenkler.metin54,
                                                  ),
                                                )
                                              : CachedNetworkImage(
                                                  imageUrl: dosyaUrl(
                                                    _ekler[i]['yol'] as String,
                                                  )!,
                                                  filterQuality:
                                                      kullaniciGorselKalitesi,
                                                  fit: BoxFit.cover,
                                                ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: InkWell(
                                          onTap: () => setState(
                                            () => _ekler.removeAt(i),
                                          ),
                                          child: const CircleAvatar(
                                            radius: 9,
                                            backgroundColor: Colors.black87,
                                            child: Icon(
                                              Icons.close,
                                              size: 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        _emojiSatiri(),
                        const SizedBox(height: 2),
                        _girisSatiri(ben),
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

/// Yanıtlar sayfasındaki tek satır: avatar + @ad (profil), tarih,
/// görüntülenme, beğeni (iyimser), yanıtla ve kendi yanıtını silme.
class _KesfetYanitSatiri extends StatefulWidget {
  final Map<String, dynamic> yanit;
  final bool benim;
  final VoidCallback sil;
  final VoidCallback yanitla;

  const _KesfetYanitSatiri({
    super.key,
    required this.yanit,
    required this.benim,
    required this.sil,
    required this.yanitla,
  });

  @override
  State<_KesfetYanitSatiri> createState() => _KesfetYanitSatiriState();
}

class _KesfetYanitSatiriState extends State<_KesfetYanitSatiri> {
  late bool _begendim = widget.yanit['begendim'] == true;
  late int _begeni = (widget.yanit['begeni'] as int?) ?? 0;
  bool _isleniyor = false;

  @override
  void didUpdateWidget(_KesfetYanitSatiri eski) {
    super.didUpdateWidget(eski);
    if (eski.yanit != widget.yanit) {
      _begendim = widget.yanit['begendim'] == true;
      _begeni = (widget.yanit['begeni'] as int?) ?? 0;
    }
  }

  Future<void> _begen() async {
    if (!girisGerekli(context)) return;
    if (_isleniyor) return;
    setState(() {
      _isleniyor = true;
      // iyimser güncelleme
      _begendim = !_begendim;
      _begeni += _begendim ? 1 : -1;
    });
    try {
      final d = await Api.yorumBegen(widget.yanit['id'] as int);
      if (mounted) {
        setState(() {
          _begendim = d['begendim'] as bool;
          _begeni = d['begeni'] as int;
        });
      }
    } catch (_) {
      // geri al
      if (mounted) {
        setState(() {
          _begendim = !_begendim;
          _begeni += _begendim ? 1 : -1;
        });
      }
    } finally {
      if (mounted) setState(() => _isleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.yanit;
    final av = dosyaUrl(c['avatar'] as String?);
    final tarih = (c['tarih'] as String? ?? '').split('T').first;
    final goruntulenme = (c['goruntulenme'] as int?) ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => kullaniciyaGit(context, c['kullanici_adi'] as String),
            child: KullaniciAvatari(
              url: av,
              kullaniciAdi: c['kullanici_adi'] as String?,
              yaricap: 14,
              arkaplan: DiziRenkler.kart,
              // Reels yanıt satırı (md.13).
              hareketli: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () =>
                          kullaniciyaGit(context, c['kullanici_adi'] as String),
                      child: Text(
                        '@${c['kullanici_adi']}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          // Yanıtlar sheet'i açık temada açık zemin → sariMetin
                          color: DiziRenkler.sariMetin,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tarih,
                      style: TextStyle(
                        fontSize: 10,
                        color: DiziRenkler.metin38,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                EtiketliMetin(
                  c['metin'] as String? ?? '',
                  stil: TextStyle(color: DiziRenkler.metin70, fontSize: 13),
                ),
                if ((c['medya'] as List<dynamic>? ?? []).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: MedyaGaleri(
                      yollar: (c['medya'] as List<dynamic>).cast<String>(),
                    ),
                  ),
                Row(
                  children: [
                    Icon(
                      Icons.remove_red_eye,
                      size: 13,
                      color: DiziRenkler.metin38,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$goruntulenme',
                      style: TextStyle(
                        fontSize: 11,
                        color: DiziRenkler.metin38,
                      ),
                    ),
                    // Dokunma hedefleri geniş padding ile ~44px
                    InkWell(
                      onTap: _begen,
                      onLongPress: () =>
                          begenenleriAc(context, widget.yanit['id'] as int),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _begendim
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 15,
                              color: _begendim
                                  ? DiziRenkler.sari
                                  : DiziRenkler.metin38,
                            ),
                            if (_begeni > 0) ...[
                              const SizedBox(width: 3),
                              Text(
                                '$_begeni',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _begendim
                                      ? DiziRenkler.sari
                                      : DiziRenkler.metin38,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: widget.yanitla,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        child: Icon(
                          Icons.reply,
                          size: 15,
                          color: DiziRenkler.metin38,
                        ),
                      ),
                    ),
                    if (widget.benim)
                      InkWell(
                        onTap: widget.sil,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          child: Icon(
                            Icons.delete_outline,
                            size: 15,
                            color: DiziRenkler.metin38,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
