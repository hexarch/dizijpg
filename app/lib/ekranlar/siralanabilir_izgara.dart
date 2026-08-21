import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../ceviri.dart';
import '../icerik_deposu.dart';
import '../tema.dart';
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

  /// 'tur:id' → küçük harfe indirgenmiş ad (süzgeç için).
  final Map<String, String> _adlar = {};

  final ScrollController _kaydirma = ScrollController();
  final GlobalKey _izgaraAnahtari = GlobalKey();
  Timer? _kaydirmaSaati;

  @override
  void initState() {
    super.initState();
    _ogeler = [...widget.ogeler];
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
          _suzgec.isEmpty
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

    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => surukleAcik && d.data != i,
      onAcceptWithDetails: (d) => _tasi(d.data, i),
      builder: (context, aday, _) {
        final hedefte = aday.isNotEmpty;
        final cerceve = DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: hedefte
                ? Border.all(color: DiziRenkler.sari, width: 2)
                : null,
          ),
          child: govde,
        );
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
            setState(() => _surukleniyor = true);
          },
          onDragEnd: (_) {
            _kaydirmayiDurdur();
            if (mounted) setState(() => _surukleniyor = false);
          },
          child: cerceve,
        );
      },
    );
  }
}
