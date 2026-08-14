import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../api.dart';
import '../ceviri.dart';
import '../gonderi_olcu.dart';
import '../gorsel_basliklari.dart';
import '../onbellek.dart';
import '../sira_tercihi.dart';
import '../tema.dart';
import 'begenenler.dart';
import 'etiket.dart';
import 'gonderi_istatistik.dart' show gonderiIstatistikAc;
import 'kesfet_akis.dart' show ReelsGorunumu, yanitlariAc;
import 'ortak.dart';
import 'paylas.dart' show gonderiPaylas;
import 'yorumlar.dart' show BolumRozeti;

/// Sosyal akış: kitaplığındaki içeriklere başkalarının yorumları.
/// Spoiler emniyeti sunucuda: izlemediğin bölümün/filmin yorumu gelmez.
class AkisEkrani extends StatefulWidget {
  const AkisEkrani({super.key});

  @override
  State<AkisEkrani> createState() => _AkisEkraniState();
}

class _AkisEkraniState extends State<AkisEkrani>
    with AutomaticKeepAliveClientMixin {
  List<dynamic>? _akis;
  Map<String, dynamic> _icerikler = {};
  String? _hata;
  int _bildirimSayi = 0;
  int _mesajSayi = 0;
  bool _dahaVar = true;
  bool _yukluyor = false;
  final _kaydirma = ScrollController();

  // "Görüldü" biriktirme: ekranda beliren kartlar toplanıp toplu bildirilir;
  // bir daha akışta gösterilmezler.
  final Set<int> _goruldu = {};
  Timer? _gorulduZaman;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _onbellektenYukle();
    _yukle();
    _kaydirma.addListener(() {
      if (_kaydirma.position.pixels >
          _kaydirma.position.maxScrollExtent - 400) {
        _devamYukle();
      }
    });
  }

  /// Bir kart ekranda belirdi: id'yi biriktir, kısa gecikmeyle toplu bildir.
  void _kartGorundu(int id) {
    if (!_goruldu.add(id)) return;
    _gorulduZaman?.cancel();
    _gorulduZaman = Timer(const Duration(seconds: 1), _gorulduGonder);
  }

  void _gorulduGonder() {
    if (_goruldu.isEmpty) return;
    final idler = _goruldu.toList();
    _goruldu.clear();
    // KAYNAK (md. 23): bu uç akış/keşfet/profil/Reels tarafından ORTAK
    // kullanılıyor; hangisi olduğunu yalnız istemci bilir. Etiketsiz
    // gönderilirse sunucu "Diğer" kovasına koyar ve kırılım işe yaramaz.
    Api.post('/akis/goruldu', {
      'idler': idler,
      'kaynak': GonderiOlcu.kaynakAkis,
    }).catchError((_) => null);
  }

  @override
  void dispose() {
    _gorulduGonder(); // kalan id'leri gönder
    _gorulduZaman?.cancel();
    _kaydirma.dispose();
    super.dispose();
  }

  Future<void> _rozetleriYukle() async {
    try {
      final sonuclar = await Future.wait([
        Api.get('/bildirimler'),
        Api.get('/sohbetler'),
      ]);
      if (!mounted) return;
      setState(() {
        _bildirimSayi = (sonuclar[0]['okunmamis'] as int?) ?? 0;
        _mesajSayi = (sonuclar[1]['okunmamis'] as int?) ?? 0;
      });
    } catch (_) {}
  }

  /// Son başarılı akış anında gösterilir (SWR); taze veri arkadan gelir.
  Future<void> _onbellektenYukle() async {
    final d = await Onbellek.oku('akis');
    if (d == null || !mounted || _akis != null) return;
    setState(() {
      _akis = d['akis'] as List<dynamic>;
      _icerikler = (d['icerikler'] as Map<String, dynamic>? ?? {});
      _dahaVar = (_akis!.length) >= 30;
    });
  }

  /// Sunucudan gelen opak sayfalama imleci (Önerilen sırada). Kronolojik
  /// sırada null kalır ve eski `?once=<id>` imleci kullanılır.
  String? _imlec;

  Future<void> _yukle() async {
    setState(() => _hata = null);
    _rozetleriYukle();
    try {
      final s = SiraTercihi.sorgu(SiraTercihi.anahtarAkis);
      final d = await Api.get(s.isEmpty ? '/akis' : '/akis?$s');
      if (!mounted) return;
      setState(() {
        _akis = d['akis'] as List<dynamic>;
        _icerikler = (d['icerikler'] as Map<String, dynamic>? ?? {});
        _imlec = d['imlec'] as String?;
        _dahaVar = (_akis!.length) >= 30;
      });
      Onbellek.yaz('akis', {'akis': _akis, 'icerikler': _icerikler});
    } catch (e) {
      if (!mounted) return;
      // Önbellekten gösteriliyorsa ağ hatasını yut
      if (_akis == null) setState(() => _hata = e.toString());
    }
  }

  /// Sıralama tercihi değişti: listeyi TAMAMEN baştan kur. Eski kartların
  /// üstüne eklemek iki sıralamayı karıştırırdı; iskelet gösterilip yeniden
  /// yüklenir ve kaydırma başa alınır.
  void _siraDegisti() {
    setState(() {
      _akis = null;
      _icerikler = {};
      _imlec = null;
      _dahaVar = true;
    });
    if (_kaydirma.hasClients) _kaydirma.jumpTo(0);
    _yukle();
  }

  Future<void> _devamYukle() async {
    if (_yukluyor || !_dahaVar || _akis == null || _akis!.isEmpty) return;
    _yukluyor = true;
    try {
      // Önerilen sırada sunucunun opak imleci kullanılır (tur tohumu:
      // sayfalar arası tekrar/atlama olmaz). Kronolojikte ya da sunucu imleç
      // vermediyse bugünkü `?once=<son id>` imleci — eski sürümlerle aynı yol.
      final s = SiraTercihi.sorgu(SiraTercihi.anahtarAkis);
      final String yol;
      if (_imlec != null && s.isEmpty) {
        yol = '/akis?imlec=${Uri.encodeQueryComponent(_imlec!)}';
      } else {
        final sonId = (_akis!.last as Map<String, dynamic>)['id'];
        yol = '/akis?once=$sonId${s.isEmpty ? '' : '&$s'}';
      }
      final d = await Api.get(yol);
      if (!mounted) return;
      final yeni = d['akis'] as List<dynamic>;
      setState(() {
        _akis!.addAll(yeni);
        _icerikler.addAll(d['icerikler'] as Map<String, dynamic>? ?? {});
        _imlec = d['imlec'] as String?;
        // Önerilen sırada sunucu imleci null verirse havuz gerçekten bitti.
        _dahaVar = yeni.length >= 30 && (s.isNotEmpty || _imlec != null);
      });
    } catch (_) {
    } finally {
      _yukluyor = false;
    }
  }

  /// Akıştaki medyaya dokununca: o gönderiden başlayıp tüm akışı Reels
  /// (dikey kaydırmalı, çift-dokunuş beğeni, sola kaydırma profil) modunda açar.
  Future<void> _reelsAc(int i, int medyaIndeks) async {
    if (_akis == null) return;
    // Push'un Future'ı DÖNDÜRÜLÜR: kart Reels kapanınca beğeni/takip
    // durumunu paylaşılan haritadan tazeler (Reels aynı haritalara yazar).
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => ReelsGorunumu(
          liste: _akis!,
          icerikler: _icerikler,
          baslangic: i,
          // Dokunulan fotoğraftan devam et (eskiden hep ilkinden açılıyordu).
          medyaBaslangic: medyaIndeks,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_akis == null) {
      // İskelet kartlar
      govde = ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < 3; i++)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        IskeletKutu(genislik: 36, yukseklik: 36),
                        SizedBox(width: 10),
                        IskeletKutu(genislik: 130, yukseklik: 14),
                      ],
                    ),
                    SizedBox(height: 12),
                    IskeletKutu(genislik: 280, yukseklik: 12),
                    SizedBox(height: 6),
                    IskeletKutu(genislik: 190, yukseklik: 12),
                  ],
                ),
              ),
            ),
        ],
      );
    } else if (_akis!.isEmpty) {
      govde = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.dynamic_feed, size: 44, color: DiziRenkler.metin24),
              const SizedBox(height: 10),
              Text(
                'Akışın boş.\nİzlediğin dizi ve filmlere yorum yapılınca burada görünecek.'
                    .c,
                textAlign: TextAlign.center,
                style: TextStyle(color: DiziRenkler.metin54, height: 1.6),
              ),
            ],
          ),
        ),
      );
    } else {
      // PC'de kartlar tüm genişliğe yayılmasın: ortalanmış okuma kolonu
      // ([masaustuKolonGenisligi], tema.dart — takvim/Reels/profil de aynı
      // kalıbı kullanır).
      govde = RefreshIndicator(
        color: DiziRenkler.sari,
        onRefresh: _yukle,
        child: OrtaKolon(
          azami: masaustuKolonGenisligi,
          cocuk: ListView.builder(
            controller: _kaydirma,
            // Yatay dolgu YOK: medya sağa-sola tam dayanır (kart kenarları
            // ekrana yaslı; başlık/metin kendi iç dolgusunu alır).
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            // İlerideki kartlar önden kurulur → videoları erkenden yüklenir
            cacheExtent: 4000,
            itemCount: _akis!.length,
            itemBuilder: (context, i) {
              final y = _akis![i] as Map<String, dynamic>;
              // "Görüldü": kart GERÇEKTEN ekranda (>%60) belirince işaretle —
              // build ≈ görüldü DEĞİL (ListView ekran dışı kartları da kurar).
              return VisibilityDetector(
                key: ValueKey('gor-${y['id']}'),
                onVisibilityChanged: (info) {
                  if (info.visibleFraction > 0.6) {
                    _kartGorundu(y['id'] as int);
                  }
                },
                child: AkisKarti(
                  key: ValueKey(y['id']),
                  yorum: y,
                  icerikler: _icerikler,
                  onMedyaAc: (mi) => _reelsAc(i, mi),
                ),
              );
            },
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 34),
            const SizedBox(width: 10),
            Text('Akış'.c),
          ],
        ),
        actions: [
          // Kronolojik / Önerilen — bu ekranın KENDİ sıralamasını yönetir.
          SiraSecici(anahtar: SiraTercihi.anahtarAkis, onDegisti: _siraDegisti),
          RozetliIkon(
            ikon: Icons.notifications_none,
            sayi: _bildirimSayi,
            etiket: 'Bildirimler'.c,
            onTap: () async {
              await context.push('/bildirimler');
              _rozetleriYukle();
            },
          ),
          RozetliIkon(
            ikon: Icons.mail_outline,
            sayi: _mesajSayi,
            etiket: 'Mesajlar'.c,
            onTap: () async {
              await context.push('/sohbetler');
              _rozetleriYukle();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      // Arama çubuğu akıştan KALDIRILDI (kullanıcı isteği): arama Ana
      // Sayfa'da (AramaCubugu) duruyor, akış yalnız gönderilere ayrıldı.
      body: govde,
    );
  }
}

/// Akış kartı başlığının DÜZENİ (kullanıcı isteği, 3 Ağu 2026):
/// "kullanıcı profil resminin hemen ortasında kullanıcı adı, resmin altından
/// başlayacak şekilde de dizi filmin adı olmalı".
///
///   [avatar] @kullaniciadi  [Takip Et]        [···] [kapak]
///   Dizi Adı  S4B6
///
/// ÖNCEDEN avatar dış satırdaydı; kullanıcı adı + içerik adı avatarın SAĞINDA
/// alt alta iki satır olarak duruyordu. Sonuç: ad avatarın ortasında değil üst
/// kenarına yakın çıkıyor, içerik adı da avatarın sağına GİRİNTİLİ başlıyordu.
///
/// ŞİMDİ avatar, kullanıcı adıyla AYNI Row'un içinde (Row'un varsayılan
/// `CrossAxisAlignment.center`'ı ikisinin dikey merkezini birebir eşitler);
/// içerik adı bu satırın ALTINDA, sol kenarı avatarın sol kenarıyla aynı
/// hizada duran ayrı bir satırdır.
///
/// Kullanıcı adının dokunma kutusu bu yüzden dolguyla değil
/// `_adDokunmaYuksekligi` ile veriliyor: dolgu yazı tipine göre değişir
/// (deneme yazı tipinde 44, gerçek yazı tipinde 40 çıkardı), sabit kutu
/// değişmez — her yazı tipinde 44 dp.
const double _adDokunmaYuksekligi = 44;

/// Kullanıcı adı ile içerik adı arasındaki dikey boşluk ARTIK bu düzenin
/// GEOMETRİSİNDEN doğuyor: ad 44 dp'lik satırın ortasında, içerik adı satırın
/// hemen altında → boşluk (44 - yazıYüksekliği) / 2. Deneme yazı tipinde
/// 11,5 dp (takip düğmeli kartta düğmenin 48 dp'si yüzünden 13,5 dp).
/// Kullanıcının bir önceki isteğiyle (boşluk %50 azalsın: 16,5 → 8,25)
/// çelişmiyor: 16,5'in altında kalıyor, üstelik ad artık avatarın tam
/// ortasında. Daha da azaltmak avatarı (40 dp) veya adın dokunma kutusunu
/// (44 dp) küçültmeyi gerektirirdi — erişilebilirlik feda edilmedi.
const double _kartUstDolgusu = 8;

/// Başlığın sağ ucundaki içerik kapağı (2:3'e yakın minik poster).
/// Satırın İÇİNDE durur ve Row tarafından DİKEY ORTALANIR (kullanıcı isteği,
/// 5 Ağu 2026: "sen gidip dizi film kapağını aşağı çekmişsin, tam tersi
/// olmalıydı"). 4 Ağu'da kapak `Stack` + `Positioned(bottom: 0)` ile satırın
/// alt kenarına yaslanmıştı; o düzeltme YANLIŞ ANLAŞILMIŞTI ve geri alındı.
const double _kapakGenisligi = 42;
const double _kapakYuksekligi = 60;

/// İÇERİK ADININ DOKUNMA KUTUSU — 44 dp DEĞİL, 24 dp. Bilerek, ölçerek.
///
/// Kullanıcının isteği (5 Ağu 2026): "görsel veya videoyu yukarı çekip dizi
/// adına dayaman gerekiyordu". Ölçüm, adın altındaki 29 dp'nin yalnız 4'ünün
/// gerçek boşluk olduğunu gösterdi; 25 dp'si adın 44 dp'lik dokunma
/// kutusunun metin ALTINDA kalan payıydı (metin 19 dp, kutu üste yaslı).
///
/// ÜÇ İSTEK AYNI ANDA SAĞLANAMIYOR — kanıtı basit bir toplama:
/// başlık = kullanıcı adı satırı (44/48 dp) + içerik adı satırı. Medyanın
/// adın dibine gelmesi için ikinci satırın ~19 dp'ye inmesi gerekir. Kutuyu
/// 44'te tutup boşluğu YUKARI itmek (metni kutunun altına yaslamak) kullanıcı
/// adı ↔ içerik adı arasını 11,5'ten 36,5 dp'ye çıkarırdı — kullanıcının
/// 3 Ağu'daki "bu boşluk yarıya insin" isteğini bozardı. Kutuyu 44'te tutup
/// medyanın üstüne BİNDİRMEK ise medyanın sol üst şeridindeki dokunuşu yutar
/// (Reels yerine içerik sayfası açılır) — hit-test tuzağı, yapılmadı.
/// Geriye tek seçenek kutuyu kısaltmak kaldı.
///
/// NEDEN TAM 24: WCAG 2.2 SC 2.5.8 "Target Size (Minimum)" AA düzeyinin
/// normatif tabanı 24x24 CSS px'tir; 44x44 ise AAA (SC 2.5.5) ve
/// ui-ux-pro-max Touch/Touch Target Size kuralıdır. Yani AAA'dan AA'ya
/// inildi, standart DIŞINA çıkılmadı. Kutu 24 dp YÜKSEK ama metin kadar
/// GENİŞ: "Posterli Dizi" için 91x24 = 2184 dp², 44x44'ün (1936 dp²)
/// ÜSTÜNDE — daralan tek şey yükseklik.
///
/// TELAFİ (SC 2.5.8'in "Equivalent" istisnası): aynı başlıkta, aynı sayfaya
/// giden 50x60 dp'lik kapak posteri duruyor (dolgusu InkWell'in İÇİNDE, bu
/// yüzden dokunma alanı 42 değil 50 dp geniş). Dizi/film gönderisinde kapak
/// da içerik sayfasına gider; bölüm gönderisinde bölüm sayfasına, yani
/// rozetin eşdeğeri olur. Her iki hedefin de 44 dp'lik bir karşılığı var.
const double _icerikAdiDokunmaYuksekligi = 24;

/// Başlık bloğu ile medyanın ARASINDAKİ nefes payı.
///
/// NEDEN 0 DEĞİL: kapağın köşesi 6 dp yuvarlatılmış; sıfır boşlukta poster ile
/// tam genişlikteki medya tek bir görsele karışır, kullanıcı hangisinin kapak
/// hangisinin gönderi olduğunu ayırt edemez. 4 dp Material'in 4 dp'lik boşluk
/// ızgarasının en küçük adımıdır: çizgi gibi incedir ama iki görselin kenarı
/// ayrı ayrı okunur.
///
/// NEDEN 8 DEĞİL: kapak da medya da DOKUNULABİLİR; "komşu dokunma hedefleri
/// arasında en az 8 dp" kuralı (ui-ux-pro-max, Touch/Touch Spacing, orta
/// önem) burada yumuşatıldı — iki hedef de büyük (50x60 ve tam genişlik x
/// yüzlerce dp), kutuları ÇAKIŞMIYOR ve yanlış dokunuşun bedeli geri
/// dönülebilir (Reels yerine içerik sayfası). Kullanıcının isteği ise
/// açıkça "dayasın"; aynı kartın örneği olan Instagram'da başlık ile
/// fotoğraf arasında boşluk hiç yoktur.
const double _kapakMedyaBoslugu = 4;

class AkisKarti extends StatefulWidget {
  final Map<String, dynamic> yorum;
  final Map<String, dynamic> icerikler;

  /// Medyaya dokununca Reels aç — parametre DOKUNULAN medyanın sırası.
  /// Dönen Future Reels KAPANINCA tamamlanır: kart o an paylaşılan haritadan
  /// tazelenir (Reels'te beğenilen gönderi kartta da beğenili görünür).
  final Future<void> Function(int medyaIndeks)? onMedyaAc;

  /// Karta BASILI TUTUNCA çalışır. Verilmezse uzun basma tanıyıcısı HİÇ
  /// kurulmaz — kart akışta, keşfette, başkasının profilinde ve
  /// `/gonderi/:id` ekranında bugünkü gibi davranır.
  ///
  /// NEDEN PARAMETRE: menüyü kartın içine gömmek onu AkisKarti'nın kullanıldığı
  /// HER YERDE açardı (akış, Reels listesi, başkasının profili). Yetkiyi
  /// çağırana bırakmak, "yalnız kendi profilimde" kuralını tek bir yerde
  /// (ProfilYorumAkisi.benimProfilim) tutar.
  ///
  /// BEĞENİ DÜĞMESİYLE ÇAKIŞMAZ: beğeni düğmesindeki uzun basma (beğenenler
  /// listesi) ağaçta DAHA DERİNDE bir InkWell'dedir. Flutter'ın jest arenasında
  /// isabet testi içten dışa yürüdüğü için içteki tanıyıcı arenaya önce girer
  /// ve süpürmede kazanır: beğeniye basılı tutmak beğenenleri, kartın
  /// herhangi bir yerine basılı tutmak bu menüyü açar.
  final VoidCallback? onUzunBas;

  const AkisKarti({
    super.key,
    required this.yorum,
    required this.icerikler,
    this.onMedyaAc,
    this.onUzunBas,
  });

  @override
  State<AkisKarti> createState() => _AkisKartiState();
}

class _AkisKartiState extends State<AkisKarti> {
  late bool _begendim = widget.yorum['begendim'] == true;
  // spoiler=true gelen kart dokunulana dek bulanık başlar
  late bool _spoilerAcik = widget.yorum['spoiler'] != true;
  late int _begeni = (widget.yorum['begeni'] as int?) ?? 0;
  late int _yanit = (widget.yorum['yanit'] as int?) ?? 0;

  /// Takip durumu. null = SUNUCU BİLDİRMEDİ (ör. profil ekranındaki liste) →
  /// düğme hiç çizilmez. false → "Takip Et" görünür. true → düğme YOK.
  late bool? _takipEdiyorum = widget.yorum['takip_ediyorum'] as bool?;
  bool _takipIsleniyor = false;
  bool _isleniyor = false;

  @override
  void didUpdateWidget(AkisKarti eski) {
    super.didUpdateWidget(eski);
    // Yenilemeden sonra (ValueKey ile State yeniden kullanılır) beğeni
    // durumunu taze veriyle eşitle — işlem sürerken dokunma.
    // DİKKAT: harita KİMLİĞİ karşılaştırılmaz. Reels/başka bir kart AYNI
    // harita nesnesini güncellemiş olabilir (`eski.yorum == widget.yorum`
    // olduğu hâlde içerik değişmiştir); eskiden bu yüzden Reels'te atılan
    // beğeni akış kartına yansımıyordu.
    if (!_isleniyor) _haritadanTazele(kur: true);
    if (!_takipIsleniyor) {
      _takipEdiyorum = widget.yorum['takip_ediyorum'] as bool?;
    }
  }

  /// Yerel durumu PAYLAŞILAN haritaya yazar. Reels, profil ve detay ekranları
  /// aynı `Map` nesnesini okuduğu için tek doğru kaynak budur.
  void _haritayaYaz() {
    widget.yorum['begendim'] = _begendim;
    widget.yorum['begeni'] = _begeni;
  }

  /// Haritadan yerel duruma okur. [kur] true ise setState çağrılmaz
  /// (didUpdateWidget zaten yeniden çizim içinde).
  void _haritadanTazele({bool kur = false}) {
    final begendim = widget.yorum['begendim'] == true;
    final begeni = (widget.yorum['begeni'] as num?)?.toInt() ?? 0;
    final yanit = (widget.yorum['yanit'] as num?)?.toInt() ?? 0;
    if (begendim == _begendim && begeni == _begeni && yanit == _yanit) return;
    void ata() {
      _begendim = begendim;
      _begeni = begeni;
      _yanit = yanit;
    }

    kur ? ata() : setState(ata);
  }

  /// Ortak yanıt sheet'i (Reels/profil ile AYNI). Kapanınca sayı tazelenir ki
  /// kullanıcı yazdığı yorumun sayıya yansıdığını görsün.
  Future<void> _yanitlariAc() async {
    await yanitlariAc(context, widget.yorum);
    if (!mounted) return;
    try {
      final y = widget.yorum;
      final sorgu = y['sezon'] != null
          ? '?sezon=${y['sezon']}&bolum=${y['bolum']}'
          : '';
      final d = await Api.get('/yorumlar/${y['tur']}/${y['tmdb_id']}$sorgu');
      if (!mounted) return;
      final sayi = (d['yorumlar'] as List<dynamic>)
          .where((c) => c['ust_id'] == y['id'])
          .length;
      widget.yorum['yanit'] = sayi; // paylaşılan harita da tazelensin
      setState(() => _yanit = sayi);
    } catch (_) {
      /* sayı eski kalır; yanıt sheet'inde doğrusu zaten görüldü */
    }
  }

  /// Paylaş: Reels ile BİREBİR aynı sheet (gonderiPaylas) — kişilere DM,
  /// telefonun paylaşım sayfası, bağlantıyı kopyala.
  Future<void> _paylas() => gonderiPaylas(context, widget.yorum);

  Future<void> _takipEt() async {
    if (_takipIsleniyor) return;
    // İyimser: düğme hemen kaybolur. Hata olursa geri gelir + SnackBar.
    setState(() {
      _takipIsleniyor = true;
      _takipEdiyorum = true;
    });
    widget.yorum['takip_ediyorum'] = true;
    try {
      final d = await Api.takipToggle(
        widget.yorum['kullanici_adi'] as String,
        // md. 23 atfı: bu takip AKIŞ KARTINDAN geldi.
        kaynakGonderi: widget.yorum['id'] as int?,
      );
      widget.yorum['takip_ediyorum'] = d['takip'] == true;
      if (!mounted) return;
      setState(() => _takipEdiyorum = d['takip'] == true);
    } catch (e) {
      widget.yorum['takip_ediyorum'] = false;
      if (!mounted) return;
      setState(() => _takipEdiyorum = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _takipIsleniyor = false);
    }
  }

  /// Beğeni: iyimser güncelleme + sunucu doğrulaması. HER adımda sonuç
  /// paylaşılan haritaya yazılır — Reels ve profil aynı haritayı okuduğu için
  /// akışta beğenilen gönderi orada da beğenili açılır.
  Future<void> _begen() async {
    if (_isleniyor) return;
    setState(() {
      _isleniyor = true;
      _begendim = !_begendim;
      _begeni += _begendim ? 1 : -1;
    });
    _haritayaYaz();
    try {
      final d = await Api.yorumBegen(widget.yorum['id'] as int);
      _begendim = d['begendim'] == true;
      _begeni = (d['begeni'] as num?)?.toInt() ?? _begeni;
      _haritayaYaz();
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      // Hata: iyimser güncelleme hem yerelde hem haritada geri alınır.
      _begendim = !_begendim;
      _begeni += _begendim ? 1 : -1;
      _haritayaYaz();
      if (!mounted) return;
      setState(() {});
    } finally {
      if (mounted) _isleniyor = false;
    }
  }

  /// Medyaya dokunuş: Reels açılır, KAPANINCA kart haritadan tazelenir
  /// (Reels'te atılan beğeni/geri alma karta yansır).
  Future<void> _medyaAc(int medyaIndeks) async {
    await widget.onMedyaAc?.call(medyaIndeks);
    if (!mounted || _isleniyor) return;
    _haritadanTazele();
  }

  @override
  Widget build(BuildContext context) {
    final y = widget.yorum;
    final icerik =
        widget.icerikler['${y['tur']}:${y['tmdb_id']}']
            as Map<String, dynamic>? ??
        const {'ad': '?', 'poster': null};
    final poster = posterUrl(icerik['poster'] as String?, boyut: 'w185');
    final avatar = dosyaUrl(y['avatar'] as String?);
    final medya = (y['medya'] as List<dynamic>? ?? []);
    final bolumlu = y['sezon'] != null;
    // İçerik adı DAİMA içeriğin kendi sayfasına gider; bölüm rozeti ise o
    // bölüme. İkisi ayrı dokunma hedefi (kullanıcı isteği).
    final icerikYolu = y['tur'] == 'person'
        ? '/kisi/${y['tmdb_id']}'
        : '/icerik/${y['tur']}/${y['tmdb_id']}';
    final posterYolu = bolumlu
        ? '/dizi/${y['tmdb_id']}/sezon/${y['sezon']}/bolum/${y['bolum']}'
        : icerikYolu;
    final tarih = (y['tarih'] as String? ?? '').split('T').first;
    final metin = (y['metin'] as String?) ?? '';
    final benim = y['kullanici_id'] == context.read<Oturum>().kullanici?['id'];
    // Takip düğmesi: sunucu durumu bildirdiyse, takip ETMİYORSAN ve gönderi
    // senin değilse çıkar. Takip ediyorsan düğme hiç çizilmez.
    final takipGoster = _takipEdiyorum == false && !benim;

    // Kart ekran kenarlarına dayanır (yatay kenar boşluğu yok) ki medya
    // sağa-sola TAM otursun; köşe yuvarlaması da bu yüzden kapalı.
    // Zemin ana renkle birleşir (gri kutu yok); ayırıcı ince çizgi.
    final kart = Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: DiziRenkler.gonderiZemin,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- 1. Üst satır: avatar + ad + Takip Et / içerik adı + S4B6
          //      ve EN SAĞDA içeriğin kapak görseli.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, _kartUstDolgusu, 6, 0),
            // Kapak satırın İÇİNDEDİR: Row'un varsayılan
            // `CrossAxisAlignment.center`'ı onu ve ··· menüsünü başlığın dikey
            // ORTASINA oturtur. (4 Ağu'da kapak Stack + `Positioned(bottom: 0)`
            // ile alta yaslanmıştı; kullanıcı "tam tersi olmalıydı" dedi, geri
            // alındı. Medyayı yukarı çeken şey artık içerik adı satırının
            // kısalması — bkz. _icerikAdiDokunmaYuksekligi.)
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1a. Avatar + kullanıcı adı (+ Takip Et). Avatar bu
                      //     satırın İÇİNDE olduğu için Row'un varsayılan
                      //     dikey ORTALAMASI adı avatarın tam ortasına
                      //     oturtur (kullanıcı isteği).
                      Row(
                        children: [
                          InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => gonderidenProfile(context, y),
                            child: KullaniciAvatari(
                              url: avatar,
                              kullaniciAdi: y['kullanici_adi'] as String?,
                              yaricap: 20,
                              // GIF avatar akışta da OYNAR (md.13, 10 Ağu):
                              // eskiden yalnız profil başlığında oynuyordu.
                              hareketli: true,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () => gonderidenProfile(context, y),
                              child: ConstrainedBox(
                                // Dokunma hedefi 44 dp: yazı tipinden
                                // bağımsız sabit kutu (bkz.
                                // _adDokunmaYuksekligi).
                                constraints: const BoxConstraints(
                                  minHeight: _adDokunmaYuksekligi,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  // widthFactor: kutu yazı kadar GENİŞ kalsın,
                                  // yoksa "Takip Et" satırın sonuna savrulur.
                                  widthFactor: 1,
                                  child: Text(
                                    '@${y['kullanici_adi']}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (takipGoster) ...[
                            const SizedBox(width: 8),
                            _TakipDugmesi(
                              isleniyor: _takipIsleniyor,
                              onTap: _takipEt,
                            ),
                          ],
                        ],
                      ),
                      // 1b. İçerik adı: AVATARIN ALTINDAN başlar, sol kenarı
                      //     avatarın sol kenarıyla aynı hizadadır (kullanıcı
                      //     isteği). Film yorumu → film adı, dizi yorumu →
                      //     dizi adı, bölüm yorumu → dizi adı + S4B6 rozeti.
                      //     BAŞLIĞIN SON SATIRIDIR: yüksekliği doğrudan
                      //     medyanın nereden başlayacağını belirler.
                      Row(
                        children: [
                          Flexible(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () =>
                                  gonderidenIcerige(context, y, icerikYolu),
                              child: ConstrainedBox(
                                // Dokunma kutusu 24 dp — NEDEN 44 DEĞİL,
                                // hangi standarda dayandığı ve telafisi:
                                // bkz. _icerikAdiDokunmaYuksekligi.
                                constraints: const BoxConstraints(
                                  minHeight: _icerikAdiDokunmaYuksekligi,
                                ),
                                child: Align(
                                  // ÜSTE dayalı: kutunun metinden ARTAN payı
                                  // kullanıcı adıyla ARAYA değil ALTA yazılır
                                  // (üstteki 11,5/13,5 dp'lik boşluk korunur).
                                  alignment: Alignment.topLeft,
                                  // widthFactor: kutu yazı kadar geniş kalsın
                                  // ki S4B6 rozeti adın HEMEN yanında dursun
                                  // (yoksa satırın sonuna savrulur).
                                  widthFactor: 1,
                                  child: Text(
                                    '${icerik['ad']}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: DiziRenkler.sariMetin,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (bolumlu) ...[
                            const SizedBox(width: 6),
                            BolumRozeti(
                              diziId: y['tmdb_id'] as int,
                              sezon: y['sezon'] as int,
                              bolum: y['bolum'] as int,
                              // İçerik adıyla aynı hizada dursun
                              hizalama: Alignment.topCenter,
                              // Rozet 44 dp kalsaydı satırı O şişirirdi ve
                              // medya yukarı gelemezdi; adla aynı kutuya
                              // indirildi (genişliği 44+ dp kalır).
                              yukseklik: _icerikAdiDokunmaYuksekligi,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                UcNoktaMenu(
                  tur: 'yorum',
                  hedefId: y['id'] as int,
                  benimMi: benim,
                  renk: DiziRenkler.metin54,
                ),
                if (poster != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => gonderidenIcerige(context, y, posterYolu),
                    // Dolgu InkWell'in İÇİNDE: dokunma alanı 42 değil 50 dp
                    // geniş olur (44 dp kuralı) — içerik adının kısalan
                    // kutusunun "eşdeğer hedef" telafisi budur.
                    child: Padding(
                      padding: const EdgeInsets.only(left: 2, right: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: _kapakGenisligi,
                          height: _kapakYuksekligi,
                          child: CachedNetworkImage(
                            imageUrl: poster,
                            httpHeaders: gorselBasliklari(poster),
                            fit: BoxFit.cover,
                            placeholder: (_, _) =>
                                Container(color: DiziRenkler.kart),
                            errorWidget: (_, _, _) =>
                                Container(color: DiziRenkler.kart),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // ---- 2. Spoiler perdesi: açılana dek MEDYA DA METİN DE çizilmez
          if (!_spoilerAcik)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  setState(() => _spoilerAcik = true);
                  // md. 23: "spoiler perdesini kaç kişi açtı" AGREGAT sayacı.
                  // Kim açtı YAZILMAZ; sunucuya yalnız (gönderi, ölçü) +1 gider.
                  GonderiOlcu.bildir(
                    widget.yorum['id'],
                    GonderiOlcu.spoilerAcildi,
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: DiziRenkler.koyuGri,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.visibility_off_outlined,
                        size: 18,
                        color: DiziRenkler.metin54,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Spoiler olabilir — dokun ve gör'.c,
                          style: TextStyle(color: DiziRenkler.metin54),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // ---- 3. Medya: sağa-sola TAM dayalı, kaydırmalı. Sayaç medyanın
          //      sağ üstünde ve 3 sn sonra söner (AkisMedya).
          if (_spoilerAcik && medya.isNotEmpty) ...[
            const SizedBox(height: _kapakMedyaBoslugu),
            MedyaGaleri(
              yollar: medya.cast<String>(),
              onAc: _medyaAc,
              // Çift dokunuş beğenir; tek dokunuş DOKUNULAN kareden
              // Reels açar (indeks düşerse ilk kareden başlardı).
              onCiftDokunus: _begen,
              otomatikOynat: true,
              // md. 23 — videolu gönderide elde tutma eğrisinin verisi.
              gonderiId: y['id'],
            ),
          ],
          // ---- 4. Gönderi metni: kullanıcı adı + yazılan yorum. MEDYANIN
          //      ALTINDA, EYLEM SATIRININ ÜSTÜNDE durur (kullanıcı isteği,
          //      2026-08-03): önce görsel, sonra ne dediği, sonra eylemler.
          //      SABİT 3 satır; taşarsa sonuna `…` düşer, dokununca açılır.
          if (_spoilerAcik && metin.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: CeviriliMetin(
                yorumId: y['id'] as int,
                metin: metin,
                kaynakDil: y['kaynak_dil'] as String?,
                ceviriVar: y['ceviri_var'] == true,
                cevrildi: y['cevrildi'] == true,
                orijinalMetin: y['orijinal_metin'] as String?,
                yapici: (m) => KisaltilmisYorum(
                  metin: m,
                  kullaniciAdi: y['kullanici_adi'] as String? ?? '',
                ),
              ),
            ),
          // ---- 5. Eylem satırı: beğeni, yorum, görüntülenme, paylaş
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                _EylemDugmesi(
                  ikon: _begendim ? Icons.favorite : Icons.favorite_border,
                  etiket: _begeni > 0 ? '$_begeni' : null,
                  renk: _begendim
                      ? DiziRenkler.sariMetin
                      : DiziRenkler.gonderiEylem,
                  ipucu: 'Beğen'.c,
                  onTap: _begen,
                  // Basılı tut → beğenenler listesi (her yerde aynı sheet)
                  onUzunBas: () =>
                      begenenleriAc(context, widget.yorum['id'] as int),
                ),
                _EylemDugmesi(
                  ikon: Icons.mode_comment_outlined,
                  etiket: _yanit > 0 ? '$_yanit' : 'Yorum yap'.c,
                  renk: DiziRenkler.gonderiEylem,
                  ipucu: 'Yorum yap'.c,
                  onTap: _yanitlariAc,
                ),
                // GÖZ İKONU — KENDİ gönderinde "istatistikleri gör" girişi
                // (md. 23). Başkasının gönderisinde salt bilgi olarak kalır:
                // uç zaten yalnız sahibine cevap veriyor, dokunulabilir
                // görünüp 404 almak kullanıcıyı yanıltırdı.
                //
                // *** MODAL AÇAR, SAYFAYA GİTMEZ *** (13 Ağu değişikliği):
                // eskiden `/gonderi-istatistik/:id` rotasına push ediyordu,
                // yani aynı giriş yorum kartında modal, akış kartında tam
                // ekran açılıyordu. Akış kartı profilde de kullanılıyor
                // (`ProfilYorumAkisi`) ve sayfaya gidip geri gelmek listeyi
                // baştan kurup kaydırma konumunu kaybettiriyordu. Rota
                // SİLİNMEDİ — paylaşılan bağlantı ve tarayıcı geçmişi hâlâ
                // oradan geliyor (`backend/test/seo_gizlilik.test.js`).
                _EylemDugmesi(
                  ikon: Icons.visibility_outlined,
                  etiket: '${y['goruntulenme'] ?? 0}',
                  renk: DiziRenkler.gonderiEylem,
                  ipucu: benim ? 'İstatistikleri gör'.c : 'Görüntülenme'.c,
                  onTap: benim
                      ? () => gonderiIstatistikAc(context, y['id'] as int)
                      : null,
                ),
                const Spacer(),
                Text(
                  tarih,
                  style: TextStyle(
                    fontSize: 11,
                    color: DiziRenkler.gonderiEylem,
                  ),
                ),
                _EylemDugmesi(
                  ikon: Icons.send_outlined,
                  renk: DiziRenkler.gonderiEylem,
                  ipucu: 'Paylaş'.c,
                  onTap: _paylas,
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: DiziRenkler.metin12),
        ],
      ),
    );
    if (widget.onUzunBas == null) return kart;
    // Yalnız uzun basma dinlenir: kartın tek dokunuşu (medyada Reels) ve çift
    // dokunuşu (beğeni) MedyaGaleri'nin kendi tanıyıcılarında kalır, buraya
    // hiç uğramaz. deferToChild: boş piksel değil, gerçekten karta basılması
    // gerekir.
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onLongPress: widget.onUzunBas,
      child: kart,
    );
  }
}

/// Akış kartındaki "Takip Et" düğmesi. Görsel yüksekliği 30px ama dokunma
/// alanı 48px'tir (tapTargetSize.padded) — parmakla ıskalanmaz.
class _TakipDugmesi extends StatelessWidget {
  final bool isleniyor;
  final VoidCallback onTap;
  const _TakipDugmesi({required this.isleniyor, required this.onTap});

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: isleniyor ? null : onTap,
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 30),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
    ),
    child: isleniyor
        // Yükleniyor hâli: düğme kilitli + spinner (sessiz bekleme yok)
        ? const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text('Takip Et'.c),
  );
}

/// Eylem satırı düğmesi: ikon + isteğe bağlı sayı. Dokunma hedefi 44px.
/// [onTap] yoksa (görüntülenme) yalnız gösterge olur.
/// [onUzunBas] verilirse basılı tutmak ayrı bir eylemdir (beğenenler listesi);
/// uzun basma tanınınca [onTap] ATEŞLENMEZ, yani kazara beğeni atılmaz.
class _EylemDugmesi extends StatelessWidget {
  final IconData ikon;
  final String? etiket;
  final Color renk;
  final String ipucu;
  final VoidCallback? onTap;
  final VoidCallback? onUzunBas;
  const _EylemDugmesi({
    required this.ikon,
    this.etiket,
    required this.renk,
    required this.ipucu,
    this.onTap,
    this.onUzunBas,
  });

  @override
  Widget build(BuildContext context) {
    final govde = Container(
      constraints: const BoxConstraints(minHeight: 44),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 19, color: renk),
          if (etiket != null) ...[
            const SizedBox(width: 5),
            Text(etiket!, style: TextStyle(fontSize: 12.5, color: renk)),
          ],
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label: etiket == null ? ipucu : '$ipucu ${etiket!}',
      child: onTap == null
          ? govde
          : InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              onLongPress: onUzunBas,
              child: govde,
            ),
    );
  }
}

/// Gönderi açıklaması: `@kullanici metin` tek paragraf hâlinde SABİT
/// [satirSiniri] (3) satır gösterilir; taşan metnin sonuna `…` düşer ve
/// dokununca metnin tamamı açılır (kullanıcı isteği, 2026-08-03).
///
/// Kırpma işaretini Flutter'ın kendi [TextOverflow.ellipsis]'i basar: tek
/// karakterlik `…` (U+2026). Elle yazılan `...` üç ayrı nokta olduğundan
/// satır sonunda bölünebilir ve dar ekranda alt satıra düşerdi.
///
/// DOKUNMA HEDEFİ: üç noktanın kendisi ~8 px, parmakla vurulamaz. Bu yüzden
/// dokunma alanı KIRPILMIŞ METNİN TAMAMIDIR (3 satır ≈ 60 px, 44 px kuralının
/// çok üstünde) — Instagram'daki gibi. Metin içindeki `@etiket` ve bağlantılar
/// tıklanabilir KALIR: [RichText]'in kendi tanıyıcıları hit-test'te daha
/// derinde olduğundan dokunma arenasına önce girer ve üstteki genişletme
/// dokunuşunu yener. Kartın Reels'e geçen tek-dokunuşu YALNIZ medyada
/// olduğundan bu alan onunla çakışmaz.
///
/// Açılan metin geri KAPANMAZ: kullanıcı "büyüt / açılacak" dedi, kapatma
/// istemedi; ayrıca kapatma da gizli bir dokunma hedefi olurdu (Instagram da
/// kapatmaz). Metin değişirse (Çevir / Orijinali göster) kırpma sıfırlanır.
class KisaltilmisYorum extends StatefulWidget {
  /// Kırpma sınırı: ekran boyutundan BAĞIMSIZ, her yerde aynı.
  static const satirSiniri = 3;

  final String metin;
  final String kullaniciAdi;
  const KisaltilmisYorum({
    super.key,
    required this.metin,
    required this.kullaniciAdi,
  });

  @override
  State<KisaltilmisYorum> createState() => _KisaltilmisYorumState();
}

class _KisaltilmisYorumState extends State<KisaltilmisYorum> {
  bool _acik = false;

  @override
  void didUpdateWidget(KisaltilmisYorum eski) {
    super.didUpdateWidget(eski);
    // Metin değiştiyse (Çevir/Orijinali göster) kırpma yeniden hesaplanır.
    if (eski.metin != widget.metin) _acik = false;
  }

  @override
  Widget build(BuildContext context) {
    final stil = TextStyle(
      fontSize: 14,
      height: 1.45,
      color: DiziRenkler.metin,
    );
    // Açıldıktan sonra kırpma da genişletme dokunuşu da yok: düz metin.
    if (_acik) {
      return EtiketliMetin(
        widget.metin,
        stil: stil,
        onekKullanici: widget.kullaniciAdi,
      );
    }
    return LayoutBuilder(
      builder: (context, kisit) {
        // Taşıyor mu? Ölçüm EKRANDA GÖRÜNEN metinle yapılır: [[tv:1|Ad]]
        // işaretlemesi ham hâliyle ölçülseydi 2 satırlık metin 3 satırı
        // aşmış sanılır, kısa gönderilerde bile üç nokta çıkardı.
        final olcer = TextPainter(
          text: TextSpan(
            style: stil,
            children: [
              TextSpan(
                text: '@${widget.kullaniciAdi}  ',
                style: stil.copyWith(fontWeight: FontWeight.w800),
              ),
              TextSpan(text: duzMetin(widget.metin)),
            ],
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: KisaltilmisYorum.satirSiniri,
        )..layout(maxWidth: kisit.maxWidth);
        final tasiyor = olcer.didExceedMaxLines;

        final govde = EtiketliMetin(
          widget.metin,
          stil: stil,
          onekKullanici: widget.kullaniciAdi,
          // 3 satırdan KISA metinde sınır konmaz → üç nokta da çıkmaz.
          maxLines: tasiyor ? KisaltilmisYorum.satirSiniri : null,
        );
        if (!tasiyor) return govde;
        return Semantics(
          button: true,
          // Ekran okuyucuya "üç nokta" değil ne işe yaradığı söylenir.
          label: 'Devam et'.c,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _acik = true),
            child: govde,
          ),
        );
      },
    );
  }
}
