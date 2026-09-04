import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../ceviri.dart';
import '../gorsel_basliklari.dart';
import '../sohbet_tema.dart';
import '../tarih.dart';
import '../tema.dart';
import 'medya_goster.dart';
import 'ortak.dart';

/// `/sohbet/:ad/detay` — WhatsApp'ın "kişi bilgisi" ekranı (31 Ağu 2026
/// isteği: "adına tıkladığımda sayfasına yönlendirmek yerine ekran açılmalı:
/// tema özelleştir, arama, sessize al; altında gönderilen dosyaların hepsi").
///
/// Üç eylem + medya arşivi:
///  * TEMA: sohbete özel balon/zemin rengi — YEREL tercih ([SohbetTemalari]),
///    karşı taraf görmez.
///  * ARA: bu sohbetin geçmişinde metin arar (sunucu çözer — mesajlar DB'de
///    şifreli, bkz. server.js /sohbet-ara).
///  * SESSİZE AL: bildirim (zil + FCM) kesilir, mesajlar normal iner
///    (dm_sessiz tablosu). Tek yönlü; karşı tarafa gösterilmez.
/// Profil sayfası kaybolmadı: başlıktaki "Profili gör" oraya götürür.
class SohbetDetayEkrani extends StatefulWidget {
  final String kullaniciAdi;

  const SohbetDetayEkrani({super.key, required this.kullaniciAdi});

  @override
  State<SohbetDetayEkrani> createState() => _SohbetDetayEkraniState();
}

class _SohbetDetayEkraniState extends State<SohbetDetayEkrani> {
  Map<String, dynamic>? _partner;
  List<dynamic> _medya = const [];
  bool _sessiz = false;
  bool _yuklendi = false;
  String? _hata;

  // Sohbette arama
  bool _aramaAcik = false;
  final _aramaKutu = TextEditingController();
  List<dynamic>? _sonuclar; // null = henüz aranmadı
  bool _araniyor = false;

  SohbetTema _tema = SohbetTemalari.listesi.first;

  @override
  void initState() {
    super.initState();
    _yukle();
    SohbetTemalari.getir(widget.kullaniciAdi).then((t) {
      if (mounted) setState(() => _tema = t);
    });
  }

  @override
  void dispose() {
    _aramaKutu.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      final d = await Api.get(
        '/sohbet-detay/${Uri.encodeComponent(widget.kullaniciAdi)}',
      );
      if (!mounted) return;
      setState(() {
        _partner = d['partner'] as Map<String, dynamic>?;
        _medya = d['medya'] as List<dynamic>? ?? const [];
        _sessiz = d['sessiz'] == true;
        _yuklendi = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = e.toString();
        _yuklendi = true;
      });
    }
  }

  /// Sessize al / sesi aç — İYİMSER: anahtar önce döner, sunucu reddederse
  /// geri alınır ve hata SnackBar'ı çıkar (sessiz başarısızlık yok).
  Future<void> _sessizDegistir() async {
    final yeni = !_sessiz;
    setState(() => _sessiz = yeni);
    try {
      await Api.post(
        '/sohbet-sessiz/${Uri.encodeComponent(widget.kullaniciAdi)}',
        {'sessiz': yeni},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            yeni ? 'Sohbet sessize alındı'.c : 'Sessize alma kaldırıldı'.c,
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sessiz = !yeni);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _ara(String q) async {
    final temiz = q.trim();
    if (temiz.length < 2) {
      setState(() => _sonuclar = null);
      return;
    }
    setState(() => _araniyor = true);
    try {
      final d = await Api.get(
        '/sohbet-ara/${Uri.encodeComponent(widget.kullaniciAdi)}'
        '?q=${Uri.encodeQueryComponent(temiz)}',
      );
      if (!mounted) return;
      setState(() {
        _araniyor = false;
        _sonuclar = d['sonuclar'] as List<dynamic>? ?? const [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _araniyor = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  /// Tema seçici: balon rengi yuvarlakları — seçilen anında kaydedilir,
  /// açık sohbet ekranı [SohbetTemalari.nesil] üzerinden yeniden okur.
  /// Tema seçici (5 Eyl 2026 yenilemesi): üstte TAM TEMALAR (gradyan zemin +
  /// iki balonlu mini önizleme, Telegram'ın tema kartları), altta DÜZ RENKLER
  /// (31 Ağu'nun daireleri). Seçince anında uygulanır ve kapanır.
  Future<void> _temaSec() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: DiziRenkler.koyuGri,
    showDragHandle: true,
    // Küçük ekranda (320×568) içerik sayfayı aşar: kaydırılır, tavan %85.
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) {
      Future<void> sec(SohbetTema t) async {
        await SohbetTemalari.sec(widget.kullaniciAdi, t);
        if (mounted) setState(() => _tema = t);
        if (sheetContext.mounted) Navigator.pop(sheetContext);
      }

      Widget baslik(String metin) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
        child: Text(
          metin,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: DiziRenkler.metin54,
          ),
        ),
      );

      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Row(
                  children: [
                    Icon(
                      Icons.palette_outlined,
                      size: 20,
                      color: DiziRenkler.sari,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tema özelleştir'.c,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              baslik('Temalar'.c),
              SizedBox(
                height: 168,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final t in SohbetTemalari.tamTemalar)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: _TemaKarti(
                          key: Key('tema-${t.anahtar}'),
                          tema: t,
                          secili: t.anahtar == _tema.anahtar,
                          onTap: () => sec(t),
                        ),
                      ),
                  ],
                ),
              ),
              baslik('Renkler'.c),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final t in SohbetTemalari.duzRenkler)
                      InkWell(
                        key: Key('tema-${t.anahtar}'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => sec(t),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              // 6 daire × (44 + 12) = 336 dp: 390 dp'de tek satır.
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: t.balon,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: t.anahtar == _tema.anahtar
                                      ? DiziRenkler.metin
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: t.anahtar == _tema.anahtar
                                  ? Icon(Icons.check, color: t.yazi)
                                  : null,
                            ),
                            const SizedBox(height: 6),
                            Text(t.ad.c, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _eylem({
    required Key key,
    required IconData ikon,
    required String etiket,
    required VoidCallback onTap,
    bool vurgulu = false,
  }) => Expanded(
    child: InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: DiziRenkler.kart,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ikon,
              color: vurgulu ? DiziRenkler.sariMetin : DiziRenkler.metin70,
            ),
            const SizedBox(height: 6),
            Text(
              etiket,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: vurgulu ? DiziRenkler.sariMetin : DiziRenkler.metin70,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _medyaKaresi(Map<String, dynamic> m) {
    final yol = m['medya'] as String?;
    final url = dosyaUrl(yol);
    if (url == null) return const SizedBox.shrink();
    final video = url.endsWith('.mp4') || url.endsWith('.webm');
    final ses = RegExp(r'\.(ogg|m4a|mp3|aac)$').hasMatch(url);
    return InkWell(
      onTap: ses ? null : () => medyaGoster(context, [url]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: DiziRenkler.kart,
          child: video || ses
              ? Center(
                  child: Icon(
                    ses ? Icons.mic : Icons.play_circle_outline,
                    size: 30,
                    color: DiziRenkler.metin54,
                  ),
                )
              // Adres YERİNDE dosyaUrl() ile kurulur: kendi sunucumuz —
              // WebP başlık pazarlığı bilinçli atlanır (gorsel_webp_test
              // taraması bu kalıbı tanır).
              : CachedNetworkImage(
                  imageUrl: dosyaUrl(yol)!,
                  fit: BoxFit.cover,
                  filterQuality: kullaniciGorselKalitesi,
                  errorWidget: (_, __, ___) => Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: DiziRenkler.metin38,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatar = dosyaUrl(_partner?['avatar'] as String?);
    final gorunenAd = (_partner?['ad'] as String?)?.trim() ?? '';
    final benId = context.watch<Oturum>().kullanici?['id'];
    return Scaffold(
      appBar: AppBar(title: Text('@${widget.kullaniciAdi}')),
      body: !_yuklendi
          ? const Center(
              child: CircularProgressIndicator(color: DiziRenkler.sari),
            )
          : _hata != null && _partner == null
          ? HataGorunumu(mesaj: _hata!, tekrar: _yukle)
          : OrtaKolon(
              azami: 800,
              cocuk: ListView(
                padding: EdgeInsets.fromLTRB(16, 18, 16, altGuvenli(context)),
                children: [
                  // Başlık: büyük avatar + ad; profil bağlantısı ayrıca durur
                  // (isteğe göre ada dokunmak artık profile GİTMİYOR).
                  Center(
                    child: Column(
                      children: [
                        KullaniciAvatari(
                          url: avatar,
                          kullaniciAdi: widget.kullaniciAdi,
                          yaricap: 44,
                          arkaplan: DiziRenkler.kart,
                          ikonRenk: DiziRenkler.metin54,
                        ),
                        const SizedBox(height: 10),
                        if (gorunenAd.isNotEmpty)
                          Text(
                            gorunenAd,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        Text(
                          '@${widget.kullaniciAdi}',
                          style: TextStyle(
                            fontSize: 13,
                            color: DiziRenkler.metin54,
                          ),
                        ),
                        TextButton(
                          key: const Key('detay-profil'),
                          onPressed: () =>
                              context.push('/kullanici/${widget.kullaniciAdi}'),
                          child: Text(
                            'Profili gör'.c,
                            style: TextStyle(color: DiziRenkler.sariMetin),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _eylem(
                        key: const Key('detay-tema'),
                        ikon: Icons.palette_outlined,
                        etiket: 'Tema özelleştir'.c,
                        onTap: _temaSec,
                      ),
                      const SizedBox(width: 10),
                      _eylem(
                        key: const Key('detay-ara'),
                        ikon: Icons.search,
                        etiket: 'Sohbette ara'.c,
                        vurgulu: _aramaAcik,
                        onTap: () => setState(() {
                          _aramaAcik = !_aramaAcik;
                          if (!_aramaAcik) {
                            _aramaKutu.clear();
                            _sonuclar = null;
                          }
                        }),
                      ),
                      const SizedBox(width: 10),
                      _eylem(
                        key: const Key('detay-sessiz'),
                        ikon: _sessiz
                            ? Icons.notifications_off
                            : Icons.notifications_off_outlined,
                        etiket: _sessiz ? 'Sesi aç'.c : 'Sessize al'.c,
                        vurgulu: _sessiz,
                        onTap: _sessizDegistir,
                      ),
                    ],
                  ),
                  if (_aramaAcik) ...[
                    const SizedBox(height: 14),
                    TextField(
                      key: const Key('detay-arama-kutu'),
                      controller: _aramaKutu,
                      autofocus: true,
                      onSubmitted: _ara,
                      onChanged: (v) {
                        // Kutu boşalınca sonuçlar da temizlenir; arama Enter /
                        // klavye "ara" ile tetiklenir (her tuşta sunucuya
                        // gitmek hız limitini boşa yerdi).
                        if (v.trim().length < 2 && _sonuclar != null) {
                          setState(() => _sonuclar = null);
                        }
                      },
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Mesajlarda ara...'.c,
                        isDense: true,
                        prefixIcon: _araniyor
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: DiziRenkler.sari,
                                  ),
                                ),
                              )
                            : const Icon(Icons.search),
                      ),
                    ),
                    if (_sonuclar != null) ...[
                      const SizedBox(height: 8),
                      if (_sonuclar!.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Center(
                            child: Text(
                              'Sonuç yok'.c,
                              style: TextStyle(color: DiziRenkler.metin54),
                            ),
                          ),
                        )
                      else
                        for (final s in _sonuclar!.cast<Map<String, dynamic>>())
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        s['gonderen_id'] == benId
                                            ? 'Sen'.c
                                            : '@${widget.kullaniciAdi}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: DiziRenkler.sariMetin,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      tarihBicimle(s['tarih']),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: DiziRenkler.metin38,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  s['metin'] as String? ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Divider(color: DiziRenkler.metin12, height: 1),
                              ],
                            ),
                          ),
                    ],
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 18,
                        color: DiziRenkler.sari,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Medya ve dosyalar'.c,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_medya.length}',
                        style: TextStyle(color: DiziRenkler.metin54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_medya.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 26),
                      child: Center(
                        child: Text(
                          'Henüz medya yok'.c,
                          style: TextStyle(color: DiziRenkler.metin54),
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                          ),
                      itemCount: _medya.length,
                      itemBuilder: (context, i) =>
                          _medyaKaresi(_medya[i] as Map<String, dynamic>),
                    ),
                ],
              ),
            ),
    );
  }
}

/// Tam tema kartı: gradyan zemin + silik desen + iki mini balon + ad.
/// Seçili kart marka sarısıyla çerçevelenir ve onay rozeti taşır.
class _TemaKarti extends StatelessWidget {
  final SohbetTema tema;
  final bool secili;
  final VoidCallback onTap;

  const _TemaKarti({
    super.key,
    required this.tema,
    required this.secili,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final acik = DiziRenkler.acik;
    final renkler = tema.zeminRenkleri(acik)!;
    Widget balon(Color renk, bool sag) => Align(
      alignment: sag ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 46,
        height: 16,
        decoration: BoxDecoration(
          color: renk,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(8),
            topRight: const Radius.circular(8),
            bottomLeft: Radius.circular(sag ? 8 : 2),
            bottomRight: Radius.circular(sag ? 2 : 8),
          ),
        ),
      ),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 104,
            height: 138,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: secili ? DiziRenkler.sari : DiziRenkler.metin12,
                width: secili ? 3 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: renkler,
                      ),
                    ),
                  ),
                  if (tema.desen != null)
                    CustomPaint(
                      painter: SohbetDeseni(
                        ikon: tema.desen!,
                        renk: (acik ? Colors.black : Colors.white).withValues(
                          alpha: 0.10,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 22, 10, 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        balon(tema.karsiBalon(acik), false),
                        const SizedBox(height: 6),
                        balon(tema.balon, true),
                        const SizedBox(height: 6),
                        balon(tema.karsiBalon(acik), false),
                      ],
                    ),
                  ),
                  if (secili)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: DiziRenkler.sari,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 15,
                          color: Colors.black,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tema.ad.c,
            style: TextStyle(
              fontSize: 12,
              fontWeight: secili ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
