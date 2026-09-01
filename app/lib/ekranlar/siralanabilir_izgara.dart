import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../ceviri.dart';
import '../icerik_deposu.dart';
import '../liste_gorunumu.dart';
import '../puan_favori_deposu.dart';
import '../tema.dart';
import 'icerik_satiri.dart';
import 'ortak.dart';

/// Kitaplık listelerinin (İzliyorum, İzleyeceğim, Bitirdim, Bıraktım,
/// İzlediğim Diziler, İzlediğim Filmler) ELLE SIRALANABİLİR afiş ızgarası.
///
/// ---------------------------------------------------------------------------
/// NEDEN IZGARA, `ReorderableListView` DEĞİL
/// ---------------------------------------------------------------------------
/// Kullanıcı birebir şunu istedi: "İzliyorum listesine girdiğimde basılı tutup
/// sürükle bırak ile dizi film AFİŞLERİNİN konumunu değiştirebilmeliyim."
/// `ReorderableListView` birinci partidir ama LİSTE içindir; ızgaraya
/// uygulanamaz ve satır düzenine geçmek istenen şeyi (afişi tutup taşımak)
/// vermezdi. Flutter'da hazır "sürüklenebilir ızgara" YOK, paket de eklemedik:
/// her hücre bir [LongPressDraggable] + [DragTarget] çifti. Bırakılan afiş
/// hedef hücrenin YERİNİ alır, aradakiler kayar.
///
/// ---------------------------------------------------------------------------
/// UZUN LİSTE (ölçüm: Bitirdim 578, İzlediğim Filmler 429 öğe)
/// ---------------------------------------------------------------------------
/// 578 öğelik listede 400. sırayı basılı tutup 2. sıraya SÜRÜKLEMEK pratikte
/// imkânsız — sürükle-bırak tek başına bu listeleri kullanılamaz bırakırdı.
/// Yanına iki şey kondu ve ikisi de aynı kipte:
///   1) HER AFİŞTE "EN ÜSTE TAŞI" — tek dokunuşla 400. sıradan 1. sıraya.
///      Mesafe ne olursa olsun maliyeti sabit.
///   2) SÜZGEÇ (ad ile ara) — 578 afişi gözle taramak yerine "brea" yazıp
///      bulunanı en üste al. Süzgeç açıkken SÜRÜKLEME KAPALI: ekrandaki
///      indeksler tam listenin indeksleri değildir, sürüklemek yanlış konuma
///      yazardı. Süzgeçte yalnız "en üste taşı" çalışır (indeksten bağımsız).
///   3) SIRAYI SIFIRLA — elle sıra bozulursa listeyi varsayılana döndürür.
/// Sürükleme ekranın alt/üst kenarına yaklaşınca liste kendiliğinden kayar,
/// yoksa bir ekrandan uzağa taşımak mümkün olmazdı.
///
/// ---------------------------------------------------------------------------
/// UZUN BASMA ≠ SÜRÜKLEME (kullanıcı isteği, 26 Ağu 2026)
/// ---------------------------------------------------------------------------
/// Kullanıcı: *"sadece basılı tutarsam afişin çapraz yukarısında en aşağıya
/// gönder olsun, elimi çekip ona tıklayabileyim; ama sürüklersem onu kaldır,
/// bıraktığım yere gitsin"*.
///
/// Tek jest iki işe hizmet ediyor, ayrım PARMAK HAREKETİ:
///   * basılı tut + KIMILDAMA → afişin sağ üstünde "En aşağıya gönder"
///     düğmesi belirir ve parmak kalkınca EKRANDA KALIR (tıklanabilir).
///   * basılı tut + SÜRÜKLE   → düğme anında kaybolur, klasik taşıma çalışır.
/// Eşik [_surukleEsigi]: bu kadar pikselden az hareket "titreme" sayılır,
/// düğme kaybolmaz — yoksa parmağın doğal oynaması düğmeyi söndürürdü.
///
/// ---------------------------------------------------------------------------
/// BIRAKMA TOLERANSI — "ARAYA" BIRAKMA
/// ---------------------------------------------------------------------------
/// Kullanıcı: *"bırakırken tam başka afişin üzerine bırakmamı istiyor, onu
/// biraz tolere et; iki dizinin ortasında bırakırsam ortasına yerleşsin"*.
///
/// Eski davranış "hedefin YERİNİ al" idi: nişan hedefin gövdesine tutmazsa
/// hiçbir şey olmuyordu. Artık hedefin HANGİ YARISINA bırakıldığına bakılır —
/// sol yarı "bunun ÖNÜNE", sağ yarı "bunun ARKASINA". İki afişin arasını
/// nişanlayan parmak ya soldakinin sağ yarısına ya sağdakinin sol yarısına
/// düşer; İKİSİ DE AYNI SONUCU verir. Tolerans budur: isabet etmesi gereken
/// nokta değil, doğru tarafa düşmesi gereken bir sınır var.
/// (RTL'de "sol yarı = önce" tersine döner; yön [Directionality]'den okunur.)
///
/// ---------------------------------------------------------------------------
/// SUNUCUYA YAZMA
/// ---------------------------------------------------------------------------
/// İYİMSER: sıra önce EKRANDA uygulanır, sonra `PUT /kitaplik/sira/<liste>`
/// ile TAM liste yazılır. Sunucu reddederse ESKİ SIRA GERİ ALINIR ve SnackBar
/// çıkar — kaydedilmemiş bir sırayı doğruymuş gibi göstermek yalan olurdu.
class SiralanabilirPosterIzgarasi extends StatefulWidget {
  /// Ekrandaki öğeler; her biri en az `tur` ve `tmdb_id` taşır.
  final List<dynamic> ogeler;

  /// Sunucudaki liste anahtarı: izliyorum | izleyecegim | bitirdim | biraktim |
  /// izlenen_tv | izlenen_movie.
  final String liste;

  /// Sıralama kipi: "en üste taşı" düğmeleri, süzgeç ve sıfırlama görünür.
  /// Sürükle-bırak bu kipten BAĞIMSIZ, her zaman açıktır (kullanıcı "listeye
  /// girdiğimde basılı tutup sürükleyebilmeliyim" dedi; önce bir kip açmak
  /// istediği şey değildi).
  final bool siralamaKipi;

  /// Dizi ilerleme rozeti için izlenen bölüm sayısı.
  final int? Function(Map<String, dynamic> oge)? izlenenSayi;

  /// Sıra sıfırlandıktan sonra listeyi yeniden çeker (varsayılan sırayı
  /// yalnız sunucu bilir).
  final Future<void> Function()? onYenile;

  final EdgeInsets? dolgu;

  const SiralanabilirPosterIzgarasi({
    super.key,
    required this.ogeler,
    required this.liste,
    this.siralamaKipi = false,
    this.izlenenSayi,
    this.onYenile,
    this.dolgu,
  });

  @override
  State<SiralanabilirPosterIzgarasi> createState() =>
      _SiralanabilirPosterIzgarasiState();
}

class _SiralanabilirPosterIzgarasiState
    extends State<SiralanabilirPosterIzgarasi> {
  late List<dynamic> _ogeler;

  /// Yazma sürerken yeni sürükleme kabul edilmez: art arda iki bırakmada
  /// ikinci istek birincinin yazdığından ESKİ bir sıra gönderip onu geri
  /// alabilirdi.
  bool _yaziliyor = false;

  bool _surukleniyor = false;
  String _suzgec = '';
  bool _adlarYukleniyor = false;

  /// SATIR GÖRÜNÜMÜ (1 Eyl 2026 isteği): afiş ızgarası yerine satır satır
  /// liste — afiş + ad + yıl + kendi puanın + favoriyse kırmızı kalp + son
  /// izleme + emoji + dizide ilerleme çubuğu (bkz. [IcerikSatiri]). Anahtarı
  /// süzgecin YANINDAKİ liste ikonudur.
  ///
  /// TERCİH BURADA DEĞİL [ListeGorunumu]'NDE TUTULUR: State'te tutulduğu ilk
  /// sürümde ekran kapanınca seçim ölüyordu ("uygulamayı yeniden başlatıp
  /// listelere girdiğimde yine eski görünüşte oluyor"). Artık disketen okunur
  /// ve altı kitaplık listesi aynı tercihi paylaşır.
  bool get _satirKipi => ListeGorunumu.satir.value;

  /// 'tur:id' → küçük harfe indirgenmiş ad (süzgeç için).
  final Map<String, String> _adlar = {};

  final ScrollController _kaydirma = ScrollController();
  final GlobalKey _izgaraAnahtari = GlobalKey();
  Timer? _kaydirmaSaati;

  @override
  void initState() {
    super.initState();
    _ogeler = [...widget.ogeler];
    ListeGorunumu.satir.addListener(_gorunumDegisti);
    // Tercih SATIR olarak kayıtlıysa ekran daha ilk karede puan/kalp/tarih/
    // emoji ile açılmalı; veri yalnız kullanıcı ikona bastığında çekilseydi
    // yeniden başlatmadan sonraki ilk açılış süssüz kalırdı.
    if (_satirKipi) PuanFavoriDeposu.yukle();
  }

  /// Görünüm tercihi (bu ekrandan ya da başka bir listeden) değişti.
  void _gorunumDegisti() {
    if (!mounted) return;
    if (_satirKipi) PuanFavoriDeposu.yukle();
    setState(() {});
  }

  @override
  void didUpdateWidget(SiralanabilirPosterIzgarasi eski) {
    super.didUpdateWidget(eski);
    // Üst ekran yeniden yüklediyse (yenileme, sıfırlama) taze listeyi al.
    if (!identical(eski.ogeler, widget.ogeler)) _ogeler = [...widget.ogeler];
    // Sıralama kipi kapanınca süzgeç de kapanmalı, yoksa normal ızgara
    // süzülmüş kalırdı ve kullanıcı yapımların kaybolduğunu sanardı.
    if (eski.siralamaKipi && !widget.siralamaKipi && _suzgec.isNotEmpty) {
      _suzgec = '';
    }
  }

  @override
  void dispose() {
    ListeGorunumu.satir.removeListener(_gorunumDegisti);
    _kaydirmaSaati?.cancel();
    _kaydirma.dispose();
    super.dispose();
  }

  String _anahtar(Map<String, dynamic> o) => '${o['tur']}-${o['tmdb_id']}';

  /// Elle sıralanmış mı? (sunucu her öğeye `sira` gönderiyor; hiç
  /// düzenlenmemiş listede hepsi null'dır)
  bool get _elleSirali => _ogeler.any((o) => o['sira'] != null);

  List<dynamic> get _gorunenler {
    if (_suzgec.isEmpty) return _ogeler;
    final arana = _suzgec.toLowerCase();
    return _ogeler.where((o) {
      final ad = _adlar[_anahtar(o as Map<String, dynamic>)];
      return ad != null && ad.contains(arana);
    }).toList();
  }

  // -------------------------------------------------------------------------
  // SIRA DEĞİŞTİRME
  // -------------------------------------------------------------------------

  /// [kaynak] öğesini [hedef] konumuna taşır (bırakılan afiş hedefin YERİNİ
  /// alır). İndeksler TAM listeye göredir — süzgeç açıkken sürükleme kapalı
  /// olduğu için burada karışma olamaz.
  /// Uzun basılan afişin anahtarı — "En aşağıya gönder" düğmesi bunun
  /// üstünde çizilir. Parmak kalkınca SİLİNMEZ: kullanıcı düğmeye
  /// tıklayabilsin diye ekranda kalır, başka bir yere dokununca kapanır.
  String? _uzunBasilan;

  /// Bu basmada parmak gerçekten sürüklendi mi (eşiği aştı mı)?
  bool _suruklendi = false;

  /// Bu basmada biriken toplam hareket (px). `delta` toplanır, ham konum
  /// farkı değil: ileri-geri gidip başladığı yere dönen parmak da
  /// "sürükledi" sayılmalı.
  double _toplamKayma = 0;

  /// Titreme ile sürükleme ayrımı. 12 dp: Flutter'ın kendi `kTouchSlop`u
  /// (18) sürükleme JESTİNİ başlatmak için; burada jest zaten başlamış,
  /// yalnız "niyet kaydırmak mıydı" sorusunu yanıtlıyoruz.
  static const double _surukleEsigi = 12;

  /// Hücrelerin GlobalKey'leri — bırakma noktasının HANGİ HÜCREnin hangi
  /// yarısına düştüğünü ölçmek için gerekli.
  ///
  /// NEDEN GlobalKey: `_hucre` bir METOT, içindeki `context` State'in
  /// context'idir ve `findRenderObject()` TÜM IZGARANIN kutusunu döndürür.
  /// İlk sürümde ölçüm bu yüzden hep "ekranın sol yarısı" diyordu ve her
  /// bırakma öğeyi listenin başına atıyordu (26 Ağu 2026 testinde yakalandı).
  final Map<String, GlobalKey> _hucreAnahtarlari = {};

  GlobalKey _hucreAnahtari(String anahtar) =>
      _hucreAnahtarlari.putIfAbsent(anahtar, GlobalKey.new);

  /// Hedefin hangi bölgesine düşülüyor: -1 önüne · 0 yerini al · +1 arkasına.
  /// Sürükleme sırasında canlı güncellenir ki kılavuz doğru kenarda görünsün
  /// (kullanıcı nereye düşeceğini bırakmadan görür).
  final Map<int, int> _oncesineDusuyor = {};

  Future<void> _tasi(int kaynak, int hedef) async {
    if (_yaziliyor || kaynak == hedef) return;
    if (kaynak < 0 || kaynak >= _ogeler.length) return;
    if (hedef < 0 || hedef >= _ogeler.length) return;
    final yedek = [..._ogeler];
    setState(() {
      final o = _ogeler.removeAt(kaynak);
      _ogeler.insert(hedef, o);
    });
    await _kaydet(yedek);
  }

  /// ARAYA EKLE — sürükle-bırakın asıl yolu (bkz. sınıf başlığı "BIRAKMA
  /// TOLERANSI"). [ekleNoktasi] ORİJİNAL liste indekslerinde "şu öğeden
  /// önce" demektir ve `0.._ogeler.length` aralığındadır.
  ///
  /// İNDEKS KAYMASI: kaynak, ekleme noktasının SOLUNDAYSA öğe listeden
  /// çıkarılınca hedef bir sola kayar. Bu düzeltme yapılmazsa afiş her
  /// seferinde istenen yerin bir sağına düşer.
  Future<void> _tasiAraya(int kaynak, int ekleNoktasi) async {
    if (_yaziliyor) return;
    if (kaynak < 0 || kaynak >= _ogeler.length) return;
    if (ekleNoktasi < 0 || ekleNoktasi > _ogeler.length) return;
    // Kendi yerine bırakmak (önüne ya da arkasına) sıfır iş: yazma yapma.
    if (ekleNoktasi == kaynak || ekleNoktasi == kaynak + 1) return;
    final yedek = [..._ogeler];
    setState(() {
      final o = _ogeler.removeAt(kaynak);
      final hedef = kaynak < ekleNoktasi ? ekleNoktasi - 1 : ekleNoktasi;
      _ogeler.insert(hedef.clamp(0, _ogeler.length), o);
    });
    await _kaydet(yedek);
  }

  /// EN AŞAĞIYA GÖNDER — uzun basma düğmesinin eylemi. "En üste taşı"nın
  /// simetriği: 3. sıradaki afişi 578. sıraya sürüklemek de imkânsızdı.
  Future<void> _altaTasi(Map<String, dynamic> oge) async {
    final i = _ogeler.indexWhere(
      (o) => _anahtar(o as Map<String, dynamic>) == _anahtar(oge),
    );
    if (i < 0 || i == _ogeler.length - 1) return;
    setState(() => _uzunBasilan = null);
    await _tasiAraya(i, _ogeler.length);
    if (mounted) _uyar('Listenin en altına taşındı'.c);
  }

  /// EN ÜSTE TAŞI — uzun listenin asıl çözümü. 400. sıradaki afişi 1. sıraya
  /// almak için 400 hücre boyunca sürüklemek gerekmez.
  Future<void> _usteTasi(Map<String, dynamic> oge) async {
    final i = _ogeler.indexWhere(
      (o) => _anahtar(o as Map<String, dynamic>) == _anahtar(oge),
    );
    if (i <= 0) return;
    await _tasi(i, 0);
    if (mounted) {
      _kaydirma.jumpTo(0);
      // Süzgeç açıkken taşınan afiş ekranda kalır ama listenin başına
      // gittiğini kullanıcı GÖRMEZ — söyle.
      if (_suzgec.isNotEmpty) _uyar('Listenin en üstüne taşındı'.c);
    }
  }

  Future<void> _kaydet(List<dynamic> yedek) async {
    setState(() => _yaziliyor = true);
    try {
      await Api.put('/kitaplik/sira/${widget.liste}', {
        'ogeler': [
          for (final o in _ogeler)
            {'tur': o['tur'], 'tmdb_id': (o['tmdb_id'] as num).toInt()},
        ],
      });
      // Artık liste elle sıralı: "Sırayı sıfırla" görünür olsun.
      for (var i = 0; i < _ogeler.length; i++) {
        (_ogeler[i] as Map<String, dynamic>)['sira'] = i;
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _ogeler = yedek);
      _uyar('Sıralama kaydedilemedi'.c);
    } finally {
      if (mounted) setState(() => _yaziliyor = false);
    }
  }

  Future<void> _sifirla() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Elle sıra sıfırlansın mı?'.c),
        content: Text(
          'Liste varsayılan sırasına (en son işaretlediğin önce) döner.'.c,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Vazgeç'.c),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Sıfırla'.c),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    try {
      await Api.delete('/kitaplik/sira/${widget.liste}');
      // Varsayılan sırayı yalnız sunucu bilir; yerelde tahmin etmiyoruz.
      await widget.onYenile?.call();
    } catch (_) {
      _uyar('Sıra sıfırlanamadı'.c);
    }
  }

  void _uyar(String mesaj) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mesaj)));
  }

  // -------------------------------------------------------------------------
  // SÜZGEÇ — adlar toplu uçtan gelir (afiş ızgarası da aynı depoyu kullanıyor)
  // -------------------------------------------------------------------------
  Future<void> _adlariYukle() async {
    if (_adlarYukleniyor || _adlar.length == _ogeler.length) return;
    setState(() => _adlarYukleniyor = true);
    // [IcerikDeposu] aynı karedeki istekleri 120'lik partilere topluyor:
    // 578 öğe = 5 istek, afiş başına bir istek DEĞİL.
    await Future.wait([
      for (final o in _ogeler)
        IcerikDeposu.getir(
          o['tur'] as String,
          (o['tmdb_id'] as num).toInt(),
        ).then((d) {
          final ad = (d?['name'] ?? d?['title']) as String?;
          if (ad != null) {
            _adlar[_anahtar(o as Map<String, dynamic>)] = ad.toLowerCase();
          }
        }),
    ]);
    if (mounted) setState(() => _adlarYukleniyor = false);
  }

  // -------------------------------------------------------------------------
  // KENAR KAYDIRMA — sürüklerken listenin ucuna gelince kendiliğinden kaydır
  // -------------------------------------------------------------------------
  void _isaretciHareket(Offset kuresel) {
    if (!_surukleniyor) return;
    final kutu = _izgaraAnahtari.currentContext?.findRenderObject();
    if (kutu is! RenderBox || !kutu.hasSize) return;
    final ust = kutu.localToGlobal(Offset.zero).dy;
    final alt = ust + kutu.size.height;
    const esik = 90.0;
    if (kuresel.dy < ust + esik) {
      _kaydirmayaBasla(-1);
    } else if (kuresel.dy > alt - esik) {
      _kaydirmayaBasla(1);
    } else {
      _kaydirmayiDurdur();
    }
  }

  void _kaydirmayaBasla(int yon) {
    if (_kaydirmaSaati != null) return;
    _kaydirmaSaati = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_kaydirma.hasClients) return;
      final hedef = (_kaydirma.offset + yon * 14).clamp(
        0.0,
        _kaydirma.position.maxScrollExtent,
      );
      _kaydirma.jumpTo(hedef);
    });
  }

  void _kaydirmayiDurdur() {
    _kaydirmaSaati?.cancel();
    _kaydirmaSaati = null;
  }

  // -------------------------------------------------------------------------
  // ÇİZİM
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final gorunen = _gorunenler;
    if (_satirKipi) {
      final liste = _satirListesi(gorunen);
      if (!widget.siralamaKipi) return liste;
      return Column(
        children: [
          _araclar(gorunen.length),
          Expanded(child: liste),
        ],
      );
    }
    final izgara = Listener(
      onPointerMove: (e) => _isaretciHareket(e.position),
      onPointerUp: (_) => _kaydirmayiDurdur(),
      onPointerCancel: (_) => _kaydirmayiDurdur(),
      child: LayoutBuilder(
        key: _izgaraAnahtari,
        builder: (context, kisit) {
          // Sürükleme hayaletinin (feedback) boyutu hücreyle aynı olmalı;
          // hücre genişliğini yalnız ölçülen genişlik verir.
          final sutun = posterSutunlari(kisit.maxWidth, bosluk: 10);
          final hucre = (kisit.maxWidth - 10 * (sutun - 1)) / sutun;
          return GridView.builder(
            controller: _kaydirma,
            padding:
                widget.dolgu ??
                EdgeInsets.fromLTRB(16, 16, 16, altGuvenli(context)),
            gridDelegate: const PosterIzgarasi(satirBoslugu: 14, bosluk: 10),
            itemCount: gorunen.length,
            itemBuilder: (context, i) =>
                _hucre(gorunen[i] as Map<String, dynamic>, hucre),
          );
        },
      ),
    );

    if (!widget.siralamaKipi) return izgara;
    return Column(
      children: [
        _araclar(gorunen.length),
        Expanded(child: izgara),
      ],
    );
  }

  /// SATIR GÖRÜNÜMÜ. Sürükle-bırak burada KAPALI: satır düzeninde afişi
  /// tutup taşımak ızgaradaki jest değil ve iki ayrı sürükleme semantiğini
  /// aynı ekranda taşımak, kullanıcının 26 Ağu'da düzelttiğimiz "basılı tutma
  /// ≠ sürükleme" ayrımını yeniden bulanıklaştırırdı. Sıralama kipinde her
  /// satırın sağında "En üste taşı" durur — uzun listenin asıl çözümü zaten
  /// oydu (bkz. sınıf başlığı).
  Widget _satirListesi(List<dynamic> gorunen) => ListView.separated(
    controller: _kaydirma,
    padding:
        widget.dolgu ?? EdgeInsets.fromLTRB(12, 4, 12, altGuvenli(context)),
    itemCount: gorunen.length,
    separatorBuilder: (_, _) =>
        Divider(height: 1, thickness: 1, color: DiziRenkler.metin12),
    itemBuilder: (context, i) {
      final o = gorunen[i] as Map<String, dynamic>;
      final anahtar = _anahtar(o);
      // Zaten en üstteki öğeye "en üste taşı" çizilmez (işlevsiz düğme).
      final ustteDegil = _ogeler.indexOf(o) > 0;
      return IcerikSatiri(
        key: ValueKey(anahtar),
        tur: o['tur'] as String,
        tmdbId: (o['tmdb_id'] as num).toInt(),
        // İlerleme çubuğunun payı — afiş ızgarasındaki çubukla AYNI kaynak.
        izlenenSayi: widget.izlenenSayi?.call(o),
        sonEk: widget.siralamaKipi && ustteDegil
            ? IconButton(
                key: Key('sira-uste-satir-$anahtar'),
                tooltip: 'En üste taşı'.c,
                onPressed: _yaziliyor ? null : () => _usteTasi(o),
                icon: Icon(
                  Icons.vertical_align_top,
                  size: 20,
                  color: DiziRenkler.sariMetin,
                ),
              )
            : null,
      );
    },
  );

  Widget _araclar(int bulunan) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('sira-suzgec'),
                onChanged: (d) {
                  setState(() => _suzgec = d);
                  if (d.isNotEmpty) _adlariYukle();
                },
                style: TextStyle(color: DiziRenkler.metin),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: 'Listede ara'.c,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            // GÖRÜNÜM ANAHTARI BURADA DEĞİL, AppBar'da (1 Eyl 2026 isteği:
            // "görünüm değiştirmeyi ayarlar butonunun içine aldık ya, onu
            // kaldır, ayarların yanına ikon olarak koy") — [ListeGorunumuDugmesi].
            // Görünüm sıralamanın alt başlığı değil: buradayken görünümü
            // değiştirmek için önce sıralama kipini açmak gerekiyordu.
            if (_elleSirali)
              IconButton(
                key: const Key('sira-sifirla'),
                tooltip: 'Sırayı sıfırla'.c,
                onPressed: _sifirla,
                icon: Icon(Icons.restart_alt, color: DiziRenkler.metin54),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _satirKipi
              ? 'Satır görünümünde sürükleme kapalı; "En üste taşı" ile öne al.'
                    .c
              : _suzgec.isEmpty
              ? 'Afişe basılı tutup sürükle. Uzaktaki bir yapımı öne almak için "En üste taşı"yı kullan.'
                    .c
              : (_adlarYukleniyor
                    ? 'Adlar yükleniyor…'.c
                    : 'Aramada sürükleme kapalı; "En üste taşı" ile öne al ({} sonuç).'
                          .cf([bulunan])),
          style: TextStyle(fontSize: 12, color: DiziRenkler.metin54),
        ),
      ],
    ),
  );

  Widget _hucre(Map<String, dynamic> oge, double hucreGenisligi) {
    final anahtar = _anahtar(oge);
    // Sürükleme indeksleri TAM listeye göre; süzgeçliyken sürükleme kapalı.
    final i = _ogeler.indexOf(oge);
    final kart = MiniIcerik(
      key: ValueKey(anahtar),
      tmdbId: (oge['tmdb_id'] as num).toInt(),
      tur: oge['tur'] as String,
      genislik: double.infinity,
      izlenenSayi: widget.izlenenSayi?.call(oge),
    );
    final surukleAcik =
        _suzgec.isEmpty && !_yaziliyor && _ogeler.length > 1 && i >= 0;

    Widget govde = kart;
    if (widget.siralamaKipi) {
      govde = Stack(
        fit: StackFit.expand,
        children: [
          kart,
          Positioned(
            top: 0,
            left: 0,
            child: Material(
              color: DiziRenkler.siyah.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                key: Key('sira-uste-$anahtar'),
                borderRadius: BorderRadius.circular(10),
                onTap: () => _usteTasi(oge),
                // Dokunma hedefi 44 px: ikon 20, gerisi dolgu.
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Tooltip(
                    message: 'En üste taşı'.c,
                    child: Icon(
                      Icons.vertical_align_top,
                      size: 20,
                      color: DiziRenkler.metin,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Bırakma noktası hücrenin hangi yarısında? Global koordinat hücrenin
    // yerel koordinatına çevrilir; RenderBox henüz yoksa (ilk kare) ortadan
    // böleriz — yanlış tarafa düşmektense eski davranışa dönmek yeğdir.
    /// Bırakma noktası hedefin neresine düştü?
    ///   -1 → ÖNÜNE ekle · 0 → YERİNİ AL · +1 → ARKASINA ekle
    ///
    /// ÜÇ BÖLGE, İKİ DEĞİL: orta şerit bilerek korundu. Afişin tam üstüne
    /// bırakmak 21 Ağu'dan beri "onun yerine geç" demekti ve sezgisel olan
    /// bu; ikiye bölseydik hedefin ortasına nişan alan her bırakma, pikselin
    /// hangi tarafa düştüğüne göre rastgele önüne ya da arkasına giderdi.
    /// Kenar şeritleri (%30) ARAYA bırakma içindir — kullanıcının istediği
    /// tolerans orada yaşıyor.
    int hedefBolge(Offset kuresel) {
      final kutu = _hucreAnahtari(anahtar).currentContext?.findRenderObject();
      if (kutu is! RenderBox || !kutu.hasSize) return 0;
      final oran = kutu.globalToLocal(kuresel).dx / kutu.size.width;
      // RTL'de görsel "sol", listenin SONRAKİ öğesidir.
      final rtl = Directionality.of(context) == TextDirection.rtl;
      if (oran < 0.3) return rtl ? 1 : -1;
      if (oran > 0.7) return rtl ? -1 : 1;
      return 0;
    }

    return DragTarget<int>(
      onWillAcceptWithDetails: (d) {
        if (!surukleAcik || d.data == i) return false;
        // `d.offset` sürüklenen hayaletin SOL ÜST köşesi; nişan noktası
        // olarak merkezi kullanmak parmağın hissettiği yere daha yakın.
        final yeni = hedefBolge(d.offset + Offset(hucreGenisligi / 2, 0));
        if (_oncesineDusuyor[i] != yeni) {
          // Kılavuz çizgisini taşımak için kare sonunda yeniden çiz;
          // build içinde setState çağırmak yasak olduğundan ertelenir.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _oncesineDusuyor[i] = yeni);
          });
        }
        return true;
      },
      onLeave: (_) => _oncesineDusuyor.remove(i),
      onAcceptWithDetails: (d) {
        final bolge = hedefBolge(d.offset + Offset(hucreGenisligi / 2, 0));
        _oncesineDusuyor.remove(i);
        // Orta şerit: eski "yerini al" yolu (indeks kaydırma semantiği ORADA,
        // `_tasi` içinde). Kenarlar: ekleme noktası semantiği.
        if (bolge == 0) {
          _tasi(d.data, i);
        } else {
          _tasiAraya(d.data, bolge < 0 ? i : i + 1);
        }
      },
      builder: (context, aday, _) {
        final hedefte = aday.isNotEmpty;
        final bolge = _oncesineDusuyor[i] ?? 0;
        Widget cerceve = DecoratedBox(
          key: _hucreAnahtari(anahtar),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            // Kılavuz: kutuyu tümden çevrelemek yerine DÜŞECEĞİ KENARA kalın
            // sarı çizgi — kullanıcı "yerini mi alacak, yanına mı girecek"
            // sorusunu bırakmadan yanıtlar.
            // Kılavuz: ARAYA girecekse düşeceği KENARDA kalın çizgi,
            // YERİNİ ALACAKSA kutuyu çevreleyen çerçeve — kullanıcı
            // bırakmadan önce hangisinin olacağını görür.
            border: !hedefte
                ? null
                : bolge == 0
                ? Border.all(color: DiziRenkler.sari, width: 2)
                : Border(
                    left: bolge < 0
                        ? BorderSide(color: DiziRenkler.sari, width: 4)
                        : BorderSide.none,
                    right: bolge > 0
                        ? BorderSide(color: DiziRenkler.sari, width: 4)
                        : BorderSide.none,
                  ),
          ),
          child: govde,
        );
        // Uzun basıldı ve parmak kımıldamadı → "En aşağıya gönder".
        // Sürükleme başlarsa (`_suruklendi`) düğme çizilmez.
        if (_uzunBasilan == anahtar && !_suruklendi && i < _ogeler.length - 1) {
          cerceve = Stack(
            fit: StackFit.expand,
            children: [
              cerceve,
              Positioned(
                // SINIR İÇİNDE: Stack'in dışına taşan Positioned Flutter'da
                // görünür ama TIKLANAMAZ (skill md. 2 tuzağı, 22 Tem 2026'da
                // avatar seçicide yaşandı). "Çapraz yukarı" isteği köşeye
                // yaslayarak karşılanıyor, dışarı taşırarak değil.
                top: 0,
                right: 0,
                child: Material(
                  color: DiziRenkler.sari,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    key: Key('sira-alta-$anahtar'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _altaTasi(oge),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Tooltip(
                        message: 'En aşağıya gönder'.c,
                        child: Icon(
                          Icons.vertical_align_bottom,
                          size: 20,
                          color: DiziRenkler.siyah,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        if (!surukleAcik) return cerceve;
        return LongPressDraggable<int>(
          data: i,
          // Hayalet hücreyle AYNI boyutta; küçültülmüş bir kopya "başka bir
          // şey sürüklüyorum" hissi verirdi.
          feedback: SizedBox(
            width: hucreGenisligi,
            // Hücre yüksekliği = 2:3 poster + başlık şeridi ([PosterIzgarasi]
            // ile AYNI hesap). Yalnız 1.5 katı verilseydi hayalet taşardı.
            height: hucreGenisligi * 1.5 + posterBaslikYuksekligi,
            child: Opacity(
              opacity: 0.92,
              child: Material(
                color: Colors.transparent,
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: MiniIcerik(
                  tmdbId: (oge['tmdb_id'] as num).toInt(),
                  tur: oge['tur'] as String,
                  genislik: double.infinity,
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.25, child: cerceve),
          onDragStarted: () {
            HapticFeedback.selectionClick();
            setState(() {
              _surukleniyor = true;
              _suruklendi = false;
              // Bu afişin düğmesi belirir; başka afişinki varsa kapanır.
              _uzunBasilan = anahtar;
            });
          },
          onDragUpdate: (d) {
            // Eşiği BİR KEZ aşmak yeter: parmak sonra geri gelse bile bu
            // jest artık "sürükleme"dir, düğme geri gelmemeli.
            if (_suruklendi) return;
            if (d.localPosition.distance == 0) return;
            _toplamKayma += d.delta.distance;
            if (_toplamKayma >= _surukleEsigi && mounted) {
              setState(() {
                _suruklendi = true;
                _uzunBasilan = null; // sürüklüyor → düğmeyi KALDIR
              });
            }
          },
          onDragEnd: (_) {
            _kaydirmayiDurdur();
            _toplamKayma = 0;
            if (mounted) setState(() => _surukleniyor = false);
          },
          child: cerceve,
        );
      },
    );
  }
}
