import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../ceviri.dart';
import '../gonderi_olcu.dart';
import '../tema.dart';
import '../yonlendirme.dart' show gonderiYolu;
import 'giris_istem.dart';
import 'ortak.dart';

/// Gönderi paylaşma sayfası: üstte kişi arama kutusu ve kişiler
/// (mesajlaştıkların, takip ettiklerin, takipçilerin; aramada sunucudan
/// başkaları da) 4'lü ızgarada, dokununca DM ile gider; altta telefonun
/// kendi paylaşım sayfası (WhatsApp, e-posta, Instagram...) ve bağlantıyı
/// kopyala. Izgarayı aşağı kaydırdıkça sayfa yükselir (DraggableScrollableSheet).
Future<void> paylasSheet(
  BuildContext context, {
  required String url,
  String? metin,
  int? yorumId, // verilirse DM'e bağlantı değil GÖNDERİNİN KENDİSİ gider
}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  // Sayfa sürüklenince %95'e kadar çıkar; durum çubuğuna girmesin.
  useSafeArea: true,
  // 4 sütunlu kişi ızgarası masaüstünde tam genişlikte hücre başına
  // yüzlerce dp'ye yayılırdı — yorum/etiket sheet'leriyle aynı 720 kolon.
  constraints: const BoxConstraints(maxWidth: masaustuKolonGenisligi),
  backgroundColor: DiziRenkler.koyuGri,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (_) => _PaylasSheet(url: url, metin: metin, yorumId: yorumId),
);

/// Bir GÖNDERİYİ paylaş. Akış kartı ve Reels bunu çağırır — iki yerde ayrı
/// yazılsaydı birinde düzeltilen (bağlantı biçimi, DM'e giden kart) ötekinde
/// kalırdı. Bağlantı içeriğe değil gönderinin kendisine gider.
Future<void> gonderiPaylas(BuildContext context, Map<String, dynamic> yorum) =>
    paylasSheet(
      context,
      url: 'https://dizijpg.com/gonderi/${yorum['id']}',
      metin: yorum['metin'] as String?,
      yorumId: yorum['id'] as int,
    );

/// Bir YORUMU (gönderinin altındaki yanıtı) paylaş — 13 Eyl 2026 isteği:
/// *"gönderideki yorumlara basılı tutunca Instagram'daki gibi arkadaşlarıma
/// gönderebilmeliyim."*
///
/// Gönderi paylaşımından İKİ farkı var:
///  1. Bağlantı `?yanit=1` taşır ([gonderiYolu]): açan kişi yanıtı tek başına
///     tam ekranda değil, ÜST GÖNDERİNİN yorumlar yüzeyinde görür.
///  2. DM'e giden kartı sunucu üst gönderiyle birlikte döndürür (server.js
///     `/sohbet/:ad` → `gonderiler[id].yorum`), sohbette "gönderi + altında
///     yorum" olarak çizilir (bkz. [PaylasilanGonderi]).
Future<void> yorumPaylas(BuildContext context, Map<String, dynamic> yorum) {
  final id = (yorum['id'] as num).toInt();
  return paylasSheet(
    context,
    url: 'https://dizijpg.com${gonderiYolu('$id', yanit: true)}',
    metin: yorum['metin'] as String?,
    yorumId: id,
  );
}

/// Liste adının yanındaki paylaş düğmesi.
///
/// ORTAK: liste tam sayfası (`liste.dart`) ve onu kullanan her yer —
/// [ListeDuzenleDugmesi] ile aynı gerekçe. Bağlantı tam sayfa listeye
/// (`/listeler/:id`) gider: rota oturumsuz açılır ve `/og/listeler/:id`
/// SSR'ı sayesinde WhatsApp/Twitter önizleme kartı basar.
///
/// YALNIZ HERKESE AÇIK listede çizilmeli: gizli listenin bağlantısını alan
/// yabancı 404 görür, "paylaşılabilir ama açılmaz" bağlantı üretmeyiz —
/// karar çağıranda (`herkese_acik` sunucudan gelir).
class ListePaylasDugmesi extends StatelessWidget {
  final int listeId;
  final String ad;

  const ListePaylasDugmesi({
    super.key,
    required this.listeId,
    required this.ad,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('liste-paylas'),
    tooltip: 'Paylaş'.c,
    onPressed: () => paylasSheet(
      context,
      url: 'https://dizijpg.com/listeler/$listeId',
      metin: ad,
    ),
    icon: Icon(Icons.ios_share, color: DiziRenkler.sariMetin),
  );
}

class _PaylasSheet extends StatefulWidget {
  final String url;
  final String? metin;
  final int? yorumId;
  const _PaylasSheet({required this.url, this.metin, this.yorumId});

  @override
  State<_PaylasSheet> createState() => _PaylasSheetState();
}

/// Sayfanın açılış / azami yüksekliği (ekran oranı). Kişi ızgarasını
/// aşağı kaydırdıkça sayfa önce [_azamiOran]a kadar yükselir, sonra ızgara
/// kendi içinde kayar (15 Eyl 2026 isteği: *"sola çekmeli yapacağına aşağı
/// doğru diz, 4'lü 4'lü iner; aşağı kaydırdıkça modal yukarı çıkar"*).
const double _acilisOran = 0.62;
const double _azamiOran = 0.95;

/// Izgara sütun sayısı — kullanıcı isteği "4'lü 4'lü".
const int _sutun = 4;

class _PaylasSheetState extends State<_PaylasSheet> {
  List<dynamic>? _kisiler;
  String? _hata;
  // Gönderim durumu KULLANICI ADIYLA tutulur, id ile değil: hedef listesi
  // (`/paylas-hedefler`) id taşır ama arama sonucu (`/kullanici-ara`) taşımaz;
  // ikisinin ortak anahtarı kullanıcı adı. DM ucu da adla çalışıyor.
  final _gonderilen = <String>{};
  final _gonderiliyor = <String>{};

  // Arama: hedef listesi anında yerel süzülür; 2+ karakterde 300 ms sonra
  // sunucu da sorulur ki listede olmayan (takip etmediğin) kişi bulunsun.
  final _aramaKontrol = TextEditingController();
  final _aramaOdak = FocusNode();
  final _sayfaKontrol = DraggableScrollableController();
  Timer? _gecikme;
  String _sorgu = '';
  List<dynamic>? _aramaSonucu;
  bool _araniyor = false;
  int _aramaSira = 0;

  @override
  void initState() {
    super.initState();
    _yukle();
    // Kutuya dokununca sayfa tam yüksekliğe çıkar: klavye açılınca kalan
    // alanda açılış oranı tek satır bile göstermiyordu.
    _aramaOdak.addListener(() {
      if (_aramaOdak.hasFocus) _tamAc();
    });
  }

  @override
  void dispose() {
    _gecikme?.cancel();
    _aramaKontrol.dispose();
    _aramaOdak.dispose();
    _sayfaKontrol.dispose();
    super.dispose();
  }

  void _tamAc() {
    if (!_sayfaKontrol.isAttached || _sayfaKontrol.size >= _azamiOran) return;
    _sayfaKontrol.animateTo(
      _azamiOran,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _yukle() async {
    // `/paylas-hedefler` girisZorunlu. Oturumsuzda DM listesi yerine giriş
    // istemi gösterilir; sistem paylaşımı ve bağlantı kopyalama ÇALIŞMAYA
    // devam eder (paylaşım SEO'nun lehine, kısıtlamanın anlamı yok).
    if (!Api.girisli) return;
    try {
      final d = await Api.get('/paylas-hedefler');
      if (mounted) {
        setState(() => _kisiler = d['kullanicilar'] as List<dynamic>? ?? []);
      }
    } catch (e) {
      if (mounted) setState(() => _hata = e.toString());
    }
  }

  void _aramaDegisti(String v) {
    final q = v.trim();
    _gecikme?.cancel();
    setState(() {
      _sorgu = q;
      _aramaSonucu = null;
      _araniyor = q.length >= 2;
    });
    if (q.length < 2) return;
    _gecikme = Timer(const Duration(milliseconds: 300), () => _sunucudaAra(q));
  }

  Future<void> _sunucudaAra(String q) async {
    final sira = ++_aramaSira;
    List<dynamic> sonuc;
    try {
      final d = await Api.get(
        '/kullanici-ara?q=${Uri.encodeQueryComponent(q)}',
      );
      sonuc = d['kullanicilar'] as List<dynamic>? ?? const [];
    } catch (_) {
      // Sunucu araması her tuş vuruşunda koşar; hatada SnackBar seli
      // olmasın. Yerel süzgeç zaten ekranda, yalnız "listede olmayan
      // kişiler" eksik kalır.
      sonuc = const [];
    }
    if (!mounted || sira != _aramaSira) return; // eski yanıt yenisini ezmesin
    setState(() {
      _aramaSonucu = sonuc;
      _araniyor = false;
    });
  }

  void _aramaTemizle() {
    _aramaKontrol.clear();
    _aramaDegisti('');
  }

  /// Ekranda çizilecek kişiler: sorgu boşsa hedef listesi; doluysa yerel
  /// eşleşenler ÖNCE (mesajlaştıkların/takip ettiklerin), ardından sunucu
  /// sonuçlarından listede olmayanlar. Kendin hiç girmez.
  List<Map<String, dynamic>> get _gosterilen {
    final hedefler = (_kisiler ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    if (_sorgu.isEmpty) return hedefler;
    final q = _sorgu.toLowerCase();
    bool uyar(Map<String, dynamic> k) =>
        (k['kullanici_adi'] as String? ?? '').toLowerCase().contains(q) ||
        (k['ad'] as String? ?? '').toLowerCase().contains(q);
    final liste = hedefler.where(uyar).toList();
    final adlar = liste.map((k) => k['kullanici_adi'] as String?).toSet();
    for (final s in _aramaSonucu ?? const <dynamic>[]) {
      final k = s as Map<String, dynamic>;
      if (k['ben_mi'] == true) continue;
      if (adlar.add(k['kullanici_adi'] as String?)) liste.add(k);
    }
    return liste;
  }

  Future<void> _dmGonder(Map<String, dynamic> k) async {
    final ad = k['kullanici_adi'] as String;
    if (_gonderilen.contains(ad) || _gonderiliyor.contains(ad)) return;
    setState(() => _gonderiliyor.add(ad));
    try {
      await Api.post('/mesajlar', {
        'kullanici_adi': ad,
        // Gönderi paylaşımında link DEĞİL postun kendisi gider: sohbette
        // kart görünür, dokununca Reels'te açılır.
        if (widget.yorumId != null) 'yorum_id': widget.yorumId,
        if (widget.yorumId == null) 'metin': widget.url,
      });
      // md. 23 paylaşım sayacı — YALNIZ mesaj GERÇEKTEN gittiyse. Sheet
      // açılınca saymak, vazgeçen kullanıcıyı da paylaşmış gösterirdi.
      GonderiOlcu.bildir(widget.yorumId, GonderiOlcu.paylasim);
      if (!mounted) return;
      setState(() {
        _gonderiliyor.remove(ad);
        _gonderilen.add(ad);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _gonderiliyor.remove(ad));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _kopyala() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    GonderiOlcu.bildir(widget.yorumId, GonderiOlcu.paylasim);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Kopyalandı: {}'.cf([widget.url]))));
  }

  /// Telefonun paylaşım sayfası: WhatsApp, e-posta, Instagram, Facebook...
  Future<void> _sistemPaylas() async {
    final messenger = ScaffoldMessenger.of(context);
    final gonderi = widget.metin?.trim();
    final govde = (gonderi == null || gonderi.isEmpty)
        ? widget.url
        : '$gonderi\n\n${widget.url}';
    try {
      await Share.share(govde);
      GonderiOlcu.bildir(widget.yorumId, GonderiOlcu.paylasim);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      // Paylaşım sayfası açılamadıysa (ör. masaüstü web) panoya kopyala
      await Clipboard.setData(ClipboardData(text: widget.url));
      GonderiOlcu.bildir(widget.yorumId, GonderiOlcu.paylasim);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Kopyalandı: {}'.cf([widget.url]))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // showModalBottomSheet klavye payı EKLEMEZ: alt pay klavye kadar ki
    // arama kutusu ve ızgara klavyenin ÜSTÜNDE kalsın.
    final klavye = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: klavye),
      child: DraggableScrollableSheet(
        key: const Key('paylas-sayfa'),
        controller: _sayfaKontrol,
        expand: false,
        initialChildSize: _acilisOran,
        minChildSize: 0.35,
        maxChildSize: _azamiOran,
        builder: (context, kontrol) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: DiziRenkler.metin24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: [
                  Icon(Icons.send_outlined, size: 20, color: DiziRenkler.sari),
                  const SizedBox(width: 8),
                  Text(
                    'Paylaş'.c,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (Api.girisli) _aramaKutusu(),
            // Kişiler: dokununca DM olarak gönderilir
            Expanded(child: _govde(kontrol)),
            Divider(color: DiziRenkler.metin12, height: 12),
            // Telefonun paylaşım sayfası + bağlantıyı kopyala
            // Düğmeler Flexible: uzun çevirili dilde (Almanca vb.) dar
            // telefonda etiketler satırı taşırıyordu — etiket kısalır, taşmaz.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (!kIsWeb)
                  Flexible(
                    child: _PaylasDugme(
                      ikon: Icons.ios_share,
                      etiket: 'Diğer uygulamalar'.c,
                      onTap: _sistemPaylas,
                    ),
                  ),
                Flexible(
                  child: _PaylasDugme(
                    ikon: Icons.link,
                    etiket: 'Bağlantıyı kopyala'.c,
                    onTap: _kopyala,
                  ),
                ),
              ],
            ),
            SizedBox(height: altGuvenli(context, ekstra: 8)),
          ],
        ),
      ),
    );
  }

  Widget _aramaKutusu() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 2, 8, 6),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            key: const Key('paylas-kisi-ara'),
            controller: _aramaKontrol,
            focusNode: _aramaOdak,
            onChanged: _aramaDegisti,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Kişi ara'.c,
              isDense: true,
              prefixIcon: Icon(
                Icons.search,
                size: 20,
                color: DiziRenkler.metin54,
              ),
            ),
          ),
        ),
        // Temizle düğmesi suffixIcon'da DEĞİL, satır kardeşi: suffixIcon
        // içindeki düğme erişilebilirlik ağacında sonsuz özyinelemeyle ANR
        // yaptı (sohbet video arızası, 1.115.0) — kural: suffixIcon'a düğme
        // koyma.
        SizedBox(
          width: dokunmaHedefi,
          child: _sorgu.isEmpty
              ? null
              : IconButton(
                  key: const Key('paylas-ara-temizle'),
                  tooltip: 'Temizle'.c,
                  onPressed: _aramaTemizle,
                  icon: Icon(Icons.close, size: 20, color: DiziRenkler.metin54),
                ),
        ),
      ],
    ),
  );

  Widget _govde(ScrollController kontrol) {
    // Boş/yükleniyor/hata durumları da AYNI kaydırma denetleyicisine bağlı:
    // sayfa yalnız ızgara varken değil, her durumda parmakla büyütülebilir.
    Widget mesaj(Widget cocuk) => CustomScrollView(
      controller: kontrol,
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: cocuk,
            ),
          ),
        ),
      ],
    );
    Widget sonukMetni(String metin) => Text(
      metin,
      textAlign: TextAlign.center,
      style: TextStyle(color: DiziRenkler.metin54),
    );
    const spinner = SizedBox(
      width: 28,
      height: 28,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: DiziRenkler.sari,
      ),
    );

    if (!Api.girisli) {
      return mesaj(
        GirisIstemiKarti(metin: 'Kişilere göndermek için giriş yap'.c),
      );
    }
    if (_hata != null) return mesaj(sonukMetni(_hata!));
    if (_kisiler == null) return mesaj(spinner);
    final liste = _gosterilen;
    if (liste.isEmpty) {
      if (_araniyor) return mesaj(spinner);
      return mesaj(
        sonukMetni(
          _sorgu.isEmpty
              ? 'Henüz kimseyi takip etmiyorsun.'.c
              : 'Sonuç bulunamadı'.c,
        ),
      );
    }
    return CustomScrollView(
      key: const Key('paylas-kisi-izgara'),
      controller: kontrol,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _sutun,
              mainAxisExtent: _KisiHucresi.boy,
            ),
            delegate: SliverChildBuilderDelegate((context, i) {
              final k = liste[i];
              final ad = k['kullanici_adi'] as String? ?? '';
              return _KisiHucresi(
                kisi: k,
                gonderildi: _gonderilen.contains(ad),
                gidiyor: _gonderiliyor.contains(ad),
                onTap: () => _dmGonder(k),
              );
            }, childCount: liste.length),
          ),
        ),
        // Yerel eşleşmeler çizilmişken sunucu hâlâ aranıyor: altta ince ilerleme
        if (_araniyor)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          ),
      ],
    );
  }
}

/// Izgaradaki tek kişi: avatar + `@ad`, gönderilince avatar üstünde tik ve
/// altında "Gönderildi". Hücrenin tamamı dokunma hedefi (≥44 dp).
class _KisiHucresi extends StatelessWidget {
  static const double boy = 104;
  final Map<String, dynamic> kisi;
  final bool gonderildi;
  final bool gidiyor;
  final VoidCallback onTap;
  const _KisiHucresi({
    required this.kisi,
    required this.gonderildi,
    required this.gidiyor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = dosyaUrl(kisi['avatar'] as String?);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Stack(
            children: [
              KullaniciAvatari(
                url: avatar,
                kullaniciAdi: kisi['kullanici_adi'] as String?,
                yaricap: 28,
                arkaplan: DiziRenkler.kart,
              ),
              if (gonderildi || gidiyor)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: gidiyor
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: DiziRenkler.sari,
                              ),
                            )
                          : const Icon(Icons.check, color: DiziRenkler.sari),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '@${kisi['kullanici_adi']}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          if (gonderildi)
            Text(
              'Gönderildi'.c,
              maxLines: 1,
              style: TextStyle(fontSize: 10, color: DiziRenkler.sariMetin),
            ),
        ],
      ),
    );
  }
}

class _PaylasDugme extends StatelessWidget {
  final IconData ikon;
  final String etiket;
  final VoidCallback onTap;
  const _PaylasDugme({
    required this.ikon,
    required this.etiket,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: DiziRenkler.kart,
              child: Icon(ikon, color: DiziRenkler.sari),
            ),
            const SizedBox(height: 8),
            Text(
              etiket,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
