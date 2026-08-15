import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../aile_rozeti.dart';
import '../api.dart';
import '../bayrak.dart';
import '../ceviri.dart';
import '../gonderi_olcu.dart';
import '../gorsel_basliklari.dart';
import '../onbellek.dart';
import '../seviye.dart';
import '../tema.dart';
import 'etiket.dart' show duzMetin;
import 'favori_oyuncular.dart' show FavoriOyuncuKarti;
import 'gorsel_kirp.dart';
import 'kullanici_profil.dart' show ProfilYorumKarti;
import 'akis.dart';
import 'kesfet_akis.dart';
import 'ortak.dart';
import 'sosyal.dart';

/// Dakikayı insancıl süreye çevirir: "1 yıl 2 ay 3 gün" (en anlamlı 3 birim).
/// Küçük süreler için saat/dakika gösterir. Yaklaşık: yıl=365g, ay=30g.
///
/// Birimler `.cs(n)` ile basılır: sayı 1 ise dilin TEKİL biçimi seçilir.
/// `.cf([n])` kullanılırsa İngilizce'de "1 years" çıkar (8 Ağu 2026 hatası) —
/// kanıt ve kapsam sınırı: test/sure_cogul_test.dart, [Ceviri.cogul].
String sureBicimle(int dakika) {
  if (dakika <= 0) return '{} dk'.cs(0);
  var kalan = dakika;
  final yil = kalan ~/ 525600;
  kalan %= 525600; // 365*24*60
  final ay = kalan ~/ 43200;
  kalan %= 43200; // 30*24*60
  final gun = kalan ~/ 1440;
  kalan %= 1440;
  final saat = kalan ~/ 60;
  final dk = kalan % 60;
  final parcalar = <String>[];
  if (yil > 0) parcalar.add('{} yıl'.cs(yil));
  if (ay > 0) parcalar.add('{} ay'.cs(ay));
  if (gun > 0) parcalar.add('{} gün'.cs(gun));
  // Yıl/ay yoksa daha küçük birimleri de göster
  if (yil == 0 && ay == 0) {
    if (saat > 0) parcalar.add('{} saat'.cs(saat));
    if (gun == 0 && dk > 0) parcalar.add('{} dk'.cs(dk));
  }
  return parcalar.isEmpty ? '{} dk'.cs(dk) : parcalar.take(3).join(' ');
}

/// Yorumların toplam beğeni + görüntülenme şeridi. Görüntülenme, foto/video
/// ekli yorumları da kapsar (medya izlenmesi yorum görüntülenmesiyle aynı
/// sayaçtır). Kendi profil ve açık profil ortak kullanır.
class EtkilesimSatiri extends StatelessWidget {
  final int begeni;
  final int goruntulenme;
  const EtkilesimSatiri({
    super.key,
    required this.begeni,
    required this.goruntulenme,
  });

  @override
  Widget build(BuildContext context) {
    Widget kutu(IconData ikon, String etiket, int deger) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: DiziRenkler.kart,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(ikon, size: 17, color: DiziRenkler.sariMetin),
            const SizedBox(width: 7),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$deger',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    etiket,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: DiziRenkler.metin54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Row(
      children: [
        kutu(Icons.favorite_border, 'Beğeni'.c, begeni),
        const SizedBox(width: 10),
        kutu(Icons.visibility_outlined, 'Görüntülenme'.c, goruntulenme),
      ],
    );
  }
}

/// Profil sekmesi seçildiğinde tazeleme tetiği (kabuk artırır).
final ValueNotifier<int> profilYenileTetik = ValueNotifier(0);

class ProfilEkrani extends StatefulWidget {
  const ProfilEkrani({super.key});

  @override
  State<ProfilEkrani> createState() => _ProfilEkraniState();
}

class _ProfilEkraniState extends State<ProfilEkrani>
    with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _istatistik;
  Map<String, dynamic>? _kitaplik;
  Map<String, dynamic>? _profil;

  /// Yorumlar sekmesi için: açık profil yanıtı (yorumlar + icerikler)
  Map<String, dynamic>? _yorumVeri;
  List<dynamic> _listeler = [];
  List<dynamic> _izlenenler = [];

  /// Favori oyuncular (madde 16). null = henüz gelmedi (kompakt satır
  /// gösterilir); boş liste = favori yok (yine kompakt satır); dolu = şerit.
  List<dynamic>? _favoriKisiler;
  List<dynamic> _rozetler = [];

  /// Seviye/unvan (md. 29) — `/rozetler` ucundan, rozetlerle AYNI yanıtta
  /// gelir (ikinci sayaç sistemi yok). Ham hâlde tutulur ki SWR önbelleğine
  /// JSON olarak yazılabilsin; çözümleme çizim anında yapılır.
  Map<String, dynamic>? _seviyeHam;
  String? _hata;
  bool _gorselYukleniyor = false;
  // Varsayılan: rozetler en altta
  List<String> _bolumSirasi = const [
    'seritler',
    'ozet',
    'listeler',
    'rozetler',
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _onbellektenYukle();
    _yukle();
    _siraYukle();
    // Sekmeye her dönüşte veriyi tazele (izlenenler sırası güncel kalsın)
    profilYenileTetik.addListener(_tetikle);
  }

  /// Avatar (kapak=false) veya kapak (kapak=true) düzenleme akışı.
  Future<void> _gorselDuzenle(bool kapak) async {
    final alan = kapak ? 'kapak' : 'avatar';
    await profilGorseliDuzenle(
      context,
      kapak: kapak,
      mevcutUrl: dosyaUrl(_profil?[alan] as String?),
      onYuklendi: (yol) => setState(() => _profil![alan] = yol),
      yukleniyor: (v) {
        if (mounted) setState(() => _gorselYukleniyor = v);
      },
    );
  }

  void _tetikle() {
    _yukle();
    _siraYukle();
  }

  @override
  void dispose() {
    profilYenileTetik.removeListener(_tetikle);
    super.dispose();
  }

  Future<void> _siraYukle() async {
    final p = await SharedPreferences.getInstance();
    final kayitli = p.getStringList('profil_sira');
    if (kayitli == null || !mounted) return;
    const gecerli = ['seritler', 'ozet', 'listeler', 'rozetler'];
    final sira = [
      for (final b in kayitli)
        if (gecerli.contains(b)) b,
    ];
    for (final b in gecerli) {
      if (!sira.contains(b)) sira.add(b);
    }
    setState(() => _bolumSirasi = sira);
  }

  /// Profil bölümleri: kullanıcı Ayarlar'dan sıralarını değiştirebilir.
  /// 0 = Dizi ve Filmler (kitaplık), 1 = Yorumlar (Twitter tarzı akış)
  int _sekme = 0;

  List<Widget> _bolumUret(String ad) {
    switch (ad) {
      case 'seritler':
        return _seritlerBolumu();
      case 'ozet':
        return _ozetBolumu();
      case 'rozetler':
        return _rozetlerBolumu();
      case 'listeler':
        return _listelerBolumu();
      default:
        return const [];
    }
  }

  List<Widget> _seritlerBolumu() {
    // Başlıktaki sayı GERÇEK toplamdır (istatistikten); şerit yalnız son N'i
    // önizler. Aksi halde son-200 penceresi bir türü aç bırakıp yanlış
    // sayı gösteriyordu (215 dizi → 3).
    final diziToplam = (_istatistik?['takip_edilen_dizi'] as num?)?.toInt();
    final filmToplam = (_istatistik?['izlenen_film'] as num?)?.toInt();
    return [
      for (final grup in [
        (
          Icons.tv_outlined,
          'İzlediğim Diziler ({})',
          _izlenenler.where((o) => o['tur'] == 'tv').toList(),
          'tv',
          diziToplam,
        ),
        (
          Icons.movie_outlined,
          'İzlediğim Filmler ({})',
          _izlenenler.where((o) => o['tur'] == 'movie').toList(),
          'movie',
          filmToplam,
        ),
      ])
        if (grup.$3.isNotEmpty) ...[
          Row(
            children: [
              Icon(grup.$1, size: 19, color: DiziRenkler.sariMetin),
              const SizedBox(width: 6),
              // Expanded (Flexible+Spacer değil): "İzlediğim Diziler (215)"
              // uzun çevirilerde (fil/my/ta) taşıyordu. maxLines yok → sarar.
              Expanded(
                child: Text(
                  grup.$2.cf([grup.$5 ?? grup.$3.length]),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/izlediklerim?tur=${grup.$4}'),
                child: Text(
                  'Tümünü gör'.c,
                  style: TextStyle(color: DiziRenkler.sariMetin, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 208,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: grup.$3.length > 30 ? 30 : grup.$3.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final o = grup.$3[i] as Map<String, dynamic>;
                return MiniIcerik(
                  key: ValueKey('${o['tur']}-${o['tmdb_id']}'),
                  tmdbId: o['tmdb_id'] as int,
                  tur: o['tur'] as String,
                  izlenenSayi: (o['sayi'] as num?)?.toInt(),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
    ];
  }

  List<Widget> _ozetBolumu() => [
    Card(
      child: ListTile(
        leading: Icon(Icons.auto_awesome, color: DiziRenkler.sariMetin),
        title: Text(
          '{} özetin'.cf([DateTime.now().year]),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'Yıllık izleme istatistiklerin'.c,
          style: TextStyle(color: DiziRenkler.metin38, fontSize: 12),
        ),
        trailing: Icon(Icons.chevron_right, color: DiziRenkler.metin38),
        onTap: () => context.push('/ozet/${DateTime.now().year}'),
      ),
    ),
    const SizedBox(height: 16),
  ];

  List<Widget> _rozetlerBolumu() => [
    if (_rozetler.isNotEmpty) ...[
      Row(
        children: [
          Icon(
            Icons.military_tech_outlined,
            size: 20,
            color: DiziRenkler.sariMetin,
          ),
          const SizedBox(width: 6),
          Text(
            'Rozetler'.c,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final r in _rozetler)
            RozetCipi(rozet: r as Map<String, dynamic>),
        ],
      ),
      const SizedBox(height: 16),
    ],
  ];

  List<Widget> _listelerBolumu() => [
    Row(
      children: [
        Icon(Icons.playlist_play, size: 20, color: DiziRenkler.sariMetin),
        const SizedBox(width: 6),
        Text(
          'Listelerim'.c,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        IconButton(
          onPressed: _yeniListe,
          tooltip: 'Yeni Liste'.c,
          icon: Icon(Icons.add, color: DiziRenkler.sariMetin),
        ),
      ],
    ),
    // Otomatik izlenenler listesi (silinemez, kapak kolajı arka planlı)
    if (_izlenenler.isNotEmpty)
      _IzlenenlerKarti(
        ogeler: _izlenenler,
        onTap: () => context.push('/izlediklerim'),
      ),
    for (final l in _listeler)
      Card(
        child: ListTile(
          // Dokununca liste içeriği modalda açılır (başkasının profilindekiyle aynı)
          onTap: () => ListeSheet.ac(
            context,
            listeId: (l['id'] as num).toInt(),
            ad: l['ad'] as String,
          ),
          leading: Icon(Icons.list, color: DiziRenkler.sariMetin),
          title: Text(l['ad'] as String),
          subtitle: Text('{} içerik'.cf([l['oge_sayisi']])),
          trailing: IconButton(
            tooltip: 'Listeyi sil'.c,
            icon: Icon(Icons.delete_outline, color: DiziRenkler.metin38),
            onPressed: () async {
              // Silmeden önce onay iste; hatayı kullanıcıya göster
              final onay = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: DiziRenkler.koyuGri,
                  title: Text('Listeyi sil?'.c),
                  content: Text(l['ad'] as String),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('İptal'.c),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('Tamam'.c),
                    ),
                  ],
                ),
              );
              if (onay != true) return;
              try {
                await Api.delete('/listeler/${l['id']}');
                _yukle();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
          ),
        ),
      ),
    const SizedBox(height: 16),
  ];

  /// Son başarılı profil anında gösterilir (SWR); taze veri arkadan gelir.
  Future<void> _onbellektenYukle() async {
    final d = await Onbellek.oku('profil');
    if (d == null || !mounted || _profil != null) return;
    setState(() {
      _istatistik = d['istatistik'] as Map<String, dynamic>?;
      _kitaplik = d['kitaplik'] as Map<String, dynamic>?;
      _listeler = (d['listeler'] as List<dynamic>?) ?? _listeler;
      _profil = d['profil'] as Map<String, dynamic>?;
      _izlenenler = (d['izlenenler'] as List<dynamic>?) ?? _izlenenler;
      _rozetler = (d['rozetler'] as List<dynamic>?) ?? _rozetler;
      _seviyeHam = (d['seviye'] as Map<String, dynamic>?) ?? _seviyeHam;
      // Favoriler de aynı kayıttan: şerit ikinci açılışta ANINDA çizilir,
      // kompakt satır → şerit zıplaması yalnız ilk ziyarette olur.
      _favoriKisiler =
          (d['favori_kisiler'] as List<dynamic>?) ?? _favoriKisiler;
    });
  }

  /// Favori oyuncuları çeker (madde 16 şeridi). Ana `_yukle`den AYRI ve
  /// beklenmeden koşar: uç, soğuk TMDB önbelleğinde 200 kişiye kadar dış
  /// istek zinciri yürütebilir — profil açılışını buna bekletmek olmaz.
  /// Hata sessiz yutulur: şerit yerine kompakt satır kalır, o da çalışır.
  Future<void> _favorileriTazele() async {
    try {
      final d = await Api.get('/favori-kisiler');
      if (!mounted) return;
      setState(
        () => _favoriKisiler = (d['kisiler'] as List<dynamic>?) ?? const [],
      );
      // Ana kayıt az önce yazıldı; favoriler gelince üstüne tam haliyle
      // yeniden yazılır ki SWR açılışı şeridi de kapsasın.
      Onbellek.yaz('profil', {
        'istatistik': _istatistik,
        'kitaplik': _kitaplik,
        'listeler': _listeler,
        'profil': _profil,
        'izlenenler': _izlenenler,
        'rozetler': _rozetler,
        'seviye': _seviyeHam,
        'favori_kisiler': _favoriKisiler,
      });
    } catch (_) {
      /* kompakt satır davranışı korunur */
    }
  }

  /// Yalnız "Yorumlar" sekmesinin verisini tazeler. Bir yorum silindiğinde ya
  /// da profilde gizlendiğinde tüm profili (kitaplık, rozetler, izlenenler)
  /// yeniden çekmeye gerek yok; ayrıca bu Future GERÇEKTEN yeni listeyi
  /// bekler — `_yukle`de bu çağrı bilerek beklenmeden başlatılır.
  Future<void> _yorumlariTazele() async {
    final kadi = (_profil?['kullanici_adi'] as String?) ?? '';
    if (kadi.isEmpty) return;
    try {
      final d = await Api.acikProfil(kadi);
      if (mounted) setState(() => _yorumVeri = d);
    } catch (_) {
      /* liste eski hâliyle kalır; kullanıcı aşağı çekip yenileyebilir */
    }
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      final sonuclar = await Future.wait([
        Api.get('/istatistiklerim'),
        Api.get('/kitapligim'),
        Api.get('/listelerim'),
        Api.get('/profilim'),
        Api.get('/izlediklerim'),
        Api.get(
          '/rozetler',
        ).catchError((_) => <String, dynamic>{'rozetler': <dynamic>[]}),
      ]);
      if (!mounted) return;
      setState(() {
        _istatistik = sonuclar[0] as Map<String, dynamic>;
        _kitaplik = sonuclar[1] as Map<String, dynamic>;
        _listeler = sonuclar[2]['listeler'] as List<dynamic>;
        _profil = sonuclar[3] as Map<String, dynamic>;
        _izlenenler = sonuclar[4]['ogeler'] as List<dynamic>;
        _rozetler = sonuclar[5]['rozetler'] as List<dynamic>? ?? [];
        _seviyeHam = sonuclar[5]['seviye'] as Map<String, dynamic>?;
      });
      // Yorumlar sekmesi: kendi yorumların + içerik adları (açık profil ucu).
      // Kitaplık yüklemesini bekletmesin diye ayrı ve hatasız yürür.
      final kadi = (_profil?['kullanici_adi'] as String?) ?? '';
      if (kadi.isNotEmpty) _yorumlariTazele();
      // Favori oyuncu şeridi de ayrı yürür (gerekçe metodun başında).
      _favorileriTazele();
      Onbellek.yaz('profil', {
        'istatistik': _istatistik,
        'kitaplik': _kitaplik,
        'listeler': _listeler,
        'profil': _profil,
        'izlenenler': _izlenenler,
        'rozetler': _rozetler,
        'seviye': _seviyeHam,
        'favori_kisiler': _favoriKisiler,
      });
    } catch (e) {
      if (!mounted) return;
      if (_profil == null) setState(() => _hata = e.toString());
    }
  }

  Future<void> _hesabiBagla() async {
    final email = TextEditingController();
    final kullaniciAdi = TextEditingController();
    final sifre = TextEditingController();
    try {
      final bagla = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: DiziRenkler.koyuGri,
        // Alt pay: klavye + sistem çubuğu. Çift saymaz — klavye açıkken
        // platform padding.bottom'ı 0'a çeker (bkz. puan_sheet.dart).
        builder: (context) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom +
                altGuvenli(context, ekstra: 20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Hesabını Bağla'.c,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'İzleme geçmişin ve listelerin korunur; artık her cihazdan girebilirsin.'
                    .c,
                textAlign: TextAlign.center,
                style: TextStyle(color: DiziRenkler.metin54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(hintText: 'E-posta'.c),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: kullaniciAdi,
                decoration: InputDecoration(
                  hintText: 'Yeni kullanıcı adı (isteğe bağlı)'.c,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: sifre,
                obscureText: true,
                decoration: InputDecoration(hintText: 'Şifre'.c),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Bağla'.c),
              ),
            ],
          ),
        ),
      );

      if (bagla == true) {
        try {
          final kullanici = await Api.hesabiBagla(
            email.text.trim(),
            kullaniciAdi.text.trim().isEmpty ? null : kullaniciAdi.text.trim(),
            sifre.text,
          );
          if (!mounted) return;
          await context.read<Oturum>().girisYapildi(kullanici);
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Hesabın bağlandı!'.c)));
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    } finally {
      email.dispose();
      kullaniciAdi.dispose();
      sifre.dispose();
    }
  }

  /// Yorum sayacına dokununca: kendi yorumların, dokununca tam hedefe gider.
  void _yorumlarAc(String kullaniciAdi) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DiziRenkler.koyuGri,
      builder: (_) => _YorumlarSheet(kullaniciAdi: kullaniciAdi),
    );
  }

  void _takipListe(String kullaniciAdi, bool takipciler) {
    context.push(
      '/kullanici/$kullaniciAdi/${takipciler ? 'takipciler' : 'takip'}',
    );
  }

  Future<void> _yeniListe() async {
    final ad = TextEditingController();
    try {
      final olustur = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: DiziRenkler.koyuGri,
          title: Text('Yeni Liste'.c),
          content: TextField(
            controller: ad,
            autofocus: true,
            decoration: InputDecoration(hintText: 'Liste adı'.c),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('İptal'.c),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Oluştur'.c),
            ),
          ],
        ),
      );
      if (olustur == true && ad.text.trim().isNotEmpty) {
        try {
          await Api.post('/listeler', {'ad': ad.text.trim()});
          _yukle();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }
      }
    } finally {
      ad.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final oturum = context.watch<Oturum>();
    final kullaniciAdi =
        oturum.kullanici?['kullanici_adi'] as String? ?? 'kullanıcı';
    final genis = masaustuMu(context);

    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_istatistik == null) {
      govde = const Center(
        child: CircularProgressIndicator(color: DiziRenkler.sari),
      );
    } else {
      final st = _istatistik!;
      final dakika = (st['tahmini_dakika'] as num?)?.toInt() ?? 0;
      final durumlar = (_kitaplik?['durumlar'] as List<dynamic>? ?? []);
      final gruplar = <String, List<dynamic>>{};
      for (final d in durumlar) {
        gruplar.putIfAbsent(d['durum'] as String, () => []).add(d);
      }
      const durumAdlari = {
        'izliyorum': (Icons.play_circle_outline, 'İzliyorum'),
        'izleyecegim': (Icons.bookmark_add_outlined, 'İzleyeceğim'),
        'bitirdim': (Icons.check_circle_outline, 'Bitirdim'),
        'biraktim': (Icons.cancel_outlined, 'Bıraktım'),
      };

      govde = RefreshIndicator(
        color: DiziRenkler.sari,
        onRefresh: _yukle,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Kapak resmi (varsa) — dokununca değiştir/yeniden konumlandır
            if (dosyaUrl(_profil?['kapak'] as String?) != null)
              GestureDetector(
                onTap: _gorselYukleniyor ? null : () => _gorselDuzenle(true),
                child: SizedBox(
                  height: 130,
                  width: double.infinity,
                  // Kapak GIF olabilir ve OYNAMALI: web'de CachedNetworkImage
                  // <img> yolundan tek kareye düşüyor (bkz. AgGorsel).
                  child: AgGorsel(
                    url: dosyaUrl(_profil!['kapak'] as String)!,
                    yerTutucu: Container(color: DiziRenkler.koyuGri),
                    hata: Container(color: DiziRenkler.koyuGri),
                  ),
                ),
              ),
            ProfilUstBolum(
              genis: genis,
              kimlik: [
                // Profil başlığı: avatar (GIF olabilir), bio, ülke
                Row(
                  children: [
                    GestureDetector(
                      onTap: _gorselYukleniyor
                          ? null
                          : () => _gorselDuzenle(false),
                      // GIF avatar profil başlığında OYNAMALI: bu yüzden
                      // CircleAvatar(backgroundImage:) DEĞİL, ClipOval +
                      // Image (DaireGorsel). DecorationImage animasyonlu
                      // görselin ilk karesinde donar —
                      // kanıt: test/gif_animasyon_test.dart.
                      child: SizedBox(
                        width: (genis ? 52 : 38) * 2,
                        height: (genis ? 52 : 38) * 2,
                        child: _gorselYukleniyor
                            ? CircleAvatar(
                                radius: genis ? 52 : 38,
                                backgroundColor: DiziRenkler.kart,
                                child: const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: DiziRenkler.sari,
                                  ),
                                ),
                              )
                            : dosyaUrl(_profil?['avatar'] as String?) != null
                            ? DaireGorsel(
                                url: dosyaUrl(_profil!['avatar'] as String)!,
                                cap: (genis ? 52 : 38) * 2,
                                arkaplan: DiziRenkler.kart,
                                ikonRenk: DiziRenkler.metin38,
                              )
                            : CircleAvatar(
                                radius: genis ? 52 : 38,
                                backgroundColor: DiziRenkler.kart,
                                child: Icon(
                                  Icons.person,
                                  size: 38,
                                  color: DiziRenkler.metin38,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Kullanıcı adı + (testçiyse) altın onay tiki.
                          // KULLANICI İSTEĞİ (7 Ağu): tik adın hemen yanında;
                          // "Founding Member" yazısı + dizi.jpg logosu gitti.
                          // Bu ekran DAİMA kendi profilim (`/profilim` ile
                          // çizilir), o yüzden modal ikinci tekil şahıs
                          // varyantını gösterir.
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '@$kullaniciAdi',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: genis ? 21 : 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (_profil?['testci'] == true)
                                AileRozeti(benMi: true, olcu: genis ? 22 : 19),
                            ],
                          ),
                          // SEVİYE (md. 29): kullanıcı adının HEMEN ALTINDA.
                          // Bu ekran DAİMA kendi profilim — ilerleme çubuğu
                          // ve "Sonraki seviyeye …" satırı BURADA çizilir,
                          // açık profilde çizilmez (veri de oraya gitmez).
                          if (Seviye.cozumle(_seviyeHam) case final sv?)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: SeviyeSatiri(
                                seviye: sv,
                                ilerlemeGoster: true,
                                yaziBoyu: genis ? 14 : 13,
                              ),
                            ),
                          if ((_profil?['bio'] as String?)?.isNotEmpty == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                _profil!['bio'] as String,
                                style: TextStyle(
                                  color: DiziRenkler.metin70,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          // Ülke satırı. Rozet buradan ÇIKTI (artık kullanıcı
                          // adının yanında) — ülke tek başına kaldı.
                          if ((_profil?['ulke'] as String?)?.isNotEmpty == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: UlkeSatiri(
                                ulke: _profil!['ulke'] as String,
                              ),
                            ),
                          const SizedBox(height: 6),
                          // Takipçi / takip (kendi listelerine gider)
                          Row(
                            children: [
                              _TakipSayac(
                                deger: '${st['takipci_sayisi'] ?? 0}',
                                etiket: 'takipçi'.c,
                                onTap: () => _takipListe(kullaniciAdi, true),
                              ),
                              const SizedBox(width: 16),
                              _TakipSayac(
                                deger: '${st['takip_sayisi'] ?? 0}',
                                etiket: 'takip'.c,
                                onTap: () => _takipListe(kullaniciAdi, false),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Sosyal bağlantılar (Ayarlar'dan eklenir, en fazla 3)
                SosyalSatiri(
                  sosyal: _profil?['sosyal'] as List<dynamic>? ?? [],
                ),
                const SizedBox(height: 18),
              ],
              olcumler: [
                // Misafir hesabı bağlama bandı
                if (oturum.kullanici?['misafir'] == true) ...[
                  Card(
                    color: DiziRenkler.sari,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _hesabiBagla,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(Icons.link, color: Colors.black),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Misafir hesabındasın — e-postanla bağla, verilerini kaybetme!'
                                    .c,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Colors.black,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                // İstatistik kartları (dar ekranda alt satıra kayar)
                LayoutBuilder(
                  builder: (context, kutu) {
                    const bosluk = 10.0;
                    final genislik = (kutu.maxWidth - bosluk * 3) / 4;
                    return Wrap(
                      spacing: bosluk,
                      runSpacing: bosluk,
                      children: [
                        // Sayaçlar tıklanır: ilgili liste/modal açılır
                        _StatKarti(
                          genislik: genislik,
                          deger: '${st['izlenen_bolum']}',
                          etiket: 'Bölüm'.c,
                          onTap: () => context.push('/izlediklerim?tur=tv'),
                        ),
                        _StatKarti(
                          genislik: genislik,
                          deger: '${st['izlenen_film']}',
                          etiket: 'Film'.c,
                          onTap: () => context.push('/izlediklerim?tur=movie'),
                        ),
                        _StatKarti(
                          genislik: genislik,
                          deger: '${st['takip_edilen_dizi']}',
                          etiket: 'Dizi'.c,
                          onTap: () => context.push('/izlediklerim?tur=tv'),
                        ),
                        _StatKarti(
                          genislik: genislik,
                          deger: '${st['yorum_sayisi'] ?? 0}',
                          etiket: 'Yorum'.c,
                          onTap: () => _yorumlarAc(kullaniciAdi),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                // Toplam ekran süresi (yıl/ay/gün)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: DiziRenkler.kart,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: DiziRenkler.metin12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: DiziRenkler.sariMetin,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      // Expanded: pl "Łączny czas przed ekranem" (25 harf)
                      // Spacer'lı halde 360 dp altında satırı taşırıyordu.
                      Expanded(
                        child: Text(
                          'Toplam İzleme Süresi'.c,
                          style: TextStyle(
                            color: DiziRenkler.metin,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        sureBicimle(dakika),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: DiziRenkler.sariMetin,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Yorumlarının toplam etkileşimi (görüntülenme: foto/video
                // ekli yorumlar dahil — aynı sayaç)
                EtkilesimSatiri(
                  begeni: (st['toplam_begeni'] as num?)?.toInt() ?? 0,
                  goruntulenme:
                      (st['toplam_goruntulenme'] as num?)?.toInt() ?? 0,
                ),
              ],
              altBolum: [
                const SizedBox(height: 20),
                // İki sekme: boydan boya, ekranı ikiye bölen butonlar.
                // Kitaplık grupları ve yorum akışı aynı profilde ayrı
                // sekmelerde durur (kullanıcı isteği).
                ProfilSekmeleri(
                  secili: _sekme,
                  onSec: (i) => setState(() => _sekme = i),
                ),
                const SizedBox(height: 12),
              ],
            ),
            // Sekme içeriği gövdenin 16px yatay dolgusunun DIŞINDA durur:
            // yorum kartı akıştaki gibi ekranı sağdan sola TAM kaplasın,
            // içindeki fotoğraf/video da öyle. Kitaplık sekmesi eski
            // dolgusunu kendi içinde korur.
            if (_sekme == 1) ...[
              ProfilYorumAkisi(
                yorumlar: (_yorumVeri?['yorumlar'] as List<dynamic>? ?? []),
                icerikler:
                    (_yorumVeri?['icerikler'] as Map<String, dynamic>? ?? {}),
                ipucu: 'Dizi ve filmlere yazdığın yorumlar burada toplanır.'.c,
                // Kendi profilim: karta basılı tutunca sil/gizle menüsü açılır.
                benimProfilim: true,
                onDegisti: _yorumlariTazele,
              ),
              const SizedBox(height: 24),
            ] else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kitaplık grupları
                    // Sabit sıra: İzliyorum → İzleyeceğim → Bitirdim.
                    // Bıraktım poster şeridi olarak GÖSTERİLMEZ (kullanıcı isteği);
                    // aşağıda yalnız soluk bir satır olarak durur.
                    for (final e in [
                      for (final durum in durumAdlari.keys)
                        if (durum != 'biraktim' &&
                            gruplar[durum]?.isNotEmpty == true)
                          MapEntry(durum, gruplar[durum]!),
                    ]) ...[
                      // Başlığa tıklayınca o durumun tam listesi açılır
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => context.push('/kitaplik/${e.key}'),
                        child: Row(
                          children: [
                            Icon(
                              durumAdlari[e.key]?.$1 ?? Icons.tv,
                              size: 19,
                              color: DiziRenkler.sariMetin,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              (durumAdlari[e.key]?.$2 ?? e.key).c,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: DiziRenkler.metin38,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 208,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: e.value.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, i) {
                            final d = e.value[i] as Map<String, dynamic>;
                            return MiniIcerik(
                              key: ValueKey('${d['tur']}-${d['tmdb_id']}'),
                              tmdbId: d['tmdb_id'] as int,
                              tur: d['tur'] as String,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Bıraktım: şerit yok, tam listeye giden soluk bir satır
                    if (gruplar['biraktim']?.isNotEmpty == true) ...[
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => context.push('/kitaplik/biraktim'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                Icons.cancel_outlined,
                                size: 17,
                                color: DiziRenkler.metin38,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Bıraktım'.c,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: DiziRenkler.metin54,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${gruplar['biraktim']!.length}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: DiziRenkler.metin38,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: DiziRenkler.metin38,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Favori oyuncular (madde 16) — dolu ise "İzlediğim
                    // Diziler/Filmler" gibi yatay şerit (fotoğraf + ad),
                    // boş/yüklenmemişse eski kompakt satır KALIR: özellik
                    // keşfedilebilir olmalı ve boş liste ekranı ne yapılacağını
                    // anlatan boş durumu gösterir.
                    if (_favoriKisiler == null || _favoriKisiler!.isEmpty)
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => context.push('/favori-oyuncular'),
                        child: Padding(
                          // 10+10+~22 = 42 → satır 44 dp'lik dokunma hedefini
                          // metin yüksekliğiyle birlikte karşılar.
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.favorite,
                                size: 17,
                                color: Colors.redAccent,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Favori oyuncular'.c,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: DiziRenkler.metin38,
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.favorite,
                            size: 19,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 6),
                          // Expanded (Flexible+Spacer değil): uzun çevirilerde
                          // taşma yerine sarma — İzlediğim başlıklarıyla aynı.
                          Expanded(
                            child: Text(
                              '${'Favori oyuncular'.c} (${_favoriKisiler!.length})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/favori-oyuncular'),
                            child: Text(
                              'Tümünü gör'.c,
                              style: TextStyle(
                                color: DiziRenkler.sariMetin,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        // 76 avatar + 8 boşluk + 40 ad — favori_oyuncular.dart
                        // ızgarasının mainAxisExtent'iyle AYNI, kart iki yerde
                        // aynı boyda görünür.
                        height: 124,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          // İzlediğim şeritleriyle aynı önizleme tavanı (30);
                          // tamamı "Tümünü gör" ekranında.
                          itemCount: _favoriKisiler!.length > 30
                              ? 30
                              : _favoriKisiler!.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, i) {
                            final k =
                                _favoriKisiler![i] as Map<String, dynamic>;
                            return SizedBox(
                              width: 96,
                              child: FavoriOyuncuKarti(
                                key: ValueKey(k['tmdb_id']),
                                kisi: k,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Bölümler kullanıcı sırasına göre (Ayarlar > Profil düzeni)
                    for (final bolum in _bolumSirasi) ..._bolumUret(bolum),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('@$kullaniciAdi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_search),
            tooltip: 'Kişi ara'.c,
            onPressed: () => context.push('/kisi-ara'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ayarlar'.c,
            onPressed: () async {
              await context.push('/ayarlar');
              _yukle();
              _siraYukle();
            },
          ),
        ],
      ),
      // Masaüstünde gövde ortalanır ve azami genişlikte tutulur: 1440'lık
      // ekranda mobil düzenin gerilip poster şeritlerinin dağılmasını önler.
      body: genis
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: masaustuIcerikGenisligi,
                ),
                child: govde,
              ),
            )
          : govde,
    );
  }
}

/// Masaüstünde profilin kimlik sütunu genişliği (avatar + ad + bio + takip).
const double masaustuKimlikSutunu = 380;

/// Profilin üst bölümü. Dar ekranda [kimlik] → [olcumler] → [altBolum] ALT
/// ALTA dizilir (bugünkü mobil düzenin birebir aynısı). Masaüstünde kimlik
/// solda dar sütunda, ölçüm kartları sağda geniş sütunda YAN YANA durur;
/// sekmeler ikisinin altında tam genişlikte kalır.
class ProfilUstBolum extends StatelessWidget {
  final bool genis;
  final List<Widget> kimlik;
  final List<Widget> olcumler;
  final List<Widget> altBolum;
  const ProfilUstBolum({
    super.key,
    required this.genis,
    required this.kimlik,
    required this.olcumler,
    required this.altBolum,
  });

  Widget _sutun(List<Widget> cocuklar) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: cocuklar,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: genis
            ? [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: masaustuKimlikSutunu,
                      child: _sutun(kimlik),
                    ),
                    const SizedBox(width: 28),
                    Expanded(child: _sutun(olcumler)),
                  ],
                ),
                ...altBolum,
              ]
            : [...kimlik, ...olcumler, ...altBolum],
      ),
    );
  }
}

class _TakipSayac extends StatelessWidget {
  final String deger;
  final String etiket;
  final VoidCallback onTap;
  const _TakipSayac({
    required this.deger,
    required this.etiket,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: RichText(
          // RichText tema rengini devralmaz; renk açıkça verilmeli
          text: TextSpan(
            style: TextStyle(fontSize: 13, color: DiziRenkler.metin),
            children: [
              TextSpan(
                text: deger,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: DiziRenkler.metin,
                ),
              ),
              TextSpan(
                text: ' $etiket',
                style: TextStyle(color: DiziRenkler.metin54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatKarti extends StatelessWidget {
  final String deger;
  final String etiket;
  final double genislik;
  final VoidCallback? onTap;
  const _StatKarti({
    required this.deger,
    required this.etiket,
    required this.genislik,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: genislik,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
          decoration: BoxDecoration(
            color: DiziRenkler.kart,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: DiziRenkler.metin12),
          ),
          child: Column(
            children: [
              Text(
                deger,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: DiziRenkler.sariMetin,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                etiket,
                style: TextStyle(fontSize: 11, color: DiziRenkler.metin54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// İzlediklerim kartı: son izlenen 5 içeriğin kapağı arka plan kolajı,
/// üstünde başlık ve sayı. Tıklayınca tüm ızgara açılır.
class _IzlenenlerKarti extends StatefulWidget {
  final List<dynamic> ogeler;
  final VoidCallback onTap;
  const _IzlenenlerKarti({required this.ogeler, required this.onTap});

  @override
  State<_IzlenenlerKarti> createState() => _IzlenenlerKartiState();
}

class _IzlenenlerKartiState extends State<_IzlenenlerKarti> {
  List<String> _kapaklar = [];

  @override
  void initState() {
    super.initState();
    _kapaklariYukle();
  }

  Future<void> _kapaklariYukle() async {
    final ilk5 = widget.ogeler.take(5).toList();
    final sonuc = await Future.wait(
      ilk5.map((o) async {
        try {
          final d = await Api.get('/tmdb/${o['tur']}/${o['tmdb_id']}');
          final yol = (d['backdrop_path'] ?? d['poster_path']) as String?;
          return posterUrl(yol, boyut: 'w500');
        } catch (_) {
          return null;
        }
      }),
    );
    if (mounted) {
      setState(() => _kapaklar = sonuc.whereType<String>().toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: SizedBox(
          height: 116,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Kapak kolajı
              if (_kapaklar.isNotEmpty)
                Row(
                  children: [
                    for (final k in _kapaklar)
                      Expanded(
                        child: CachedNetworkImage(
                          imageUrl: k,
                          httpHeaders: gorselBasliklari(k),
                          fit: BoxFit.cover,
                        ),
                      ),
                  ],
                )
              else
                Container(color: DiziRenkler.kart),
              // Karartma
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      // Sabit siyah (tema-bağımsız): üstteki beyaz metin açık
                      // temada da okunsun — DiziRenkler.siyah açık temada beyaza
                      // döner ve beyaz-üstü-beyaz olurdu.
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
              // Başlık
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.visibility,
                          color: DiziRenkler.sari,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'İzlediklerim'.c,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right, color: Colors.white70),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '{} içerik · otomatik'.cf([widget.ogeler.length]),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// PROFİL UNVANI (istek md. 29) — kullanıcı adının ALTINDAKİ küçük satır.
///
/// İki profil ekranı da bunu kullanır (`RozetCipi` ile aynı kalıp: burada
/// tanımlanır, `kullanici_profil.dart` içe aktarır) — tek kopya, iki ekranda
/// aynı görünüm.
///
/// [ilerlemeGoster] YALNIZ KENDİ PROFİLİNDE true verilir. Ama tek başına da
/// yeterli değil: ilerleme verisi (puan/eşik) SUNUCUDAN ziyaretçiye hiç
/// gelmediği için [Seviye.ilerleme] orada zaten null olur. İki kilit
/// bilerek: istemcideki bir "ben miyim?" hatası veriyi sızdıramaz.
///
/// TASARIM KARARLARI (ui-ux-pro-max danışması, 15 Ağu — 14 Ağu'da güncellendi):
///  · RENK: sarı METİN tonu (`sariMetin`) — koyu temada marka sarısı kart
///    üstünde 10:1, AÇIK temada hardal (#8A6D00) beyaz üstünde ~4.9:1.
///    Ham `sari` açık temada beyaz zeminde 1.63:1 ile hem metin hem grafik
///    eşiğinin altında kalırdı. RENK TEK BAŞINA ANLAM TAŞIMIYOR: sayı da
///    çubuğun altındaki cümle de metin.
///  · TAŞMA: `FittedBox(scaleDown)` KULLANILMADI — 45 dilde metni 12 pt
///    tabanının altına indirir ve kullanıcının sistem yazı ölçeğini iptal
///    eder. Yerine "önce sar, sonra üç nokta": iki satıra kadar sarılır.
///    Tam metin erişilebilirlik ağacına yine tam hâliyle gider.
///  · İKON YOK (üst satırda): "Seviye 7" metni zaten anlamı taşıyor; rozet
///    şeridinde altı ayrı ödül ikonu var, yedincisi ayırt edici olmazdı.
///    İlerleme satırında küçük bir `trending_up` var — o satır YALNIZ kendi
///    profilinde çizildiği için dar ekranda yarışmıyor.
///  · EKRAN OKUYUCU: etiketsiz `LinearProgressIndicator` erişilebilirlik
///    ağacında HİÇ görünmez (dolgu yalnız görene bilgi olurdu). Çubuğa
///    `semanticsLabel` ("Seviye 7") + `semanticsValue` (SALT SAYI: "40")
///    verildi; alttaki iki metin zaten okunduğu için sarmalayıcı bir
///    `Semantics` düğümü EKLENMEDİ (aynı cümleyi üçüncü kez söylerdi).
///  · TIKLANABİLİR DEĞİL: dokunma hedefi (44 dp) sorunu doğmasın ve
///    kullanıcı adının hemen altındaki alan kaza dokunuşu yutmasın diye
///    salt bilgi satırı bırakıldı.
class SeviyeSatiri extends StatelessWidget {
  final Seviye seviye;

  /// Kendi profilinde true: ilerleme çubuğu + "Sonraki seviyeye … kaldı".
  final bool ilerlemeGoster;

  /// "Seviye 7" yazı boyu (masaüstü profilinde biraz büyür).
  final double yaziBoyu;

  const SeviyeSatiri({
    super.key,
    required this.seviye,
    this.ilerlemeGoster = false,
    this.yaziBoyu = 13,
  });

  @override
  Widget build(BuildContext context) {
    final oran = seviye.ilerleme;
    final alt = seviye.altSatir;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          seviye.etiket,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: yaziBoyu,
            fontWeight: FontWeight.w700,
            color: DiziRenkler.sariMetin,
          ),
        ),
        if (ilerlemeGoster) ...[
          if (oran != null) ...[
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: oran,
                minHeight: 5,
                backgroundColor: DiziRenkler.metin12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  DiziRenkler.sariMetin,
                ),
                // Etiketsiz bir çubuk ekran okuyucuda HİÇ düğüm üretmez:
                // dolgunun ne kadar dolu olduğu yalnız GÖRENE bilgi olurdu.
                // Sarmalayıcı `Semantics` KULLANILMADI — alttaki iki metin
                // zaten okunuyor, üçüncü bir düğüm hepsini tekrarlardı.
                //
                // DEĞER SALT SAYI: bu widget erişilebilirlik ağacında bir
                // "progress bar" düğümü (min 0, max 100) kurar ve Flutter
                // `value`nun SAYIYA ÇEVRİLEBİLMESİNİ doğruluyor —
                // yüzde işareti konursa ("%40") çerçeve assert'e düşüyor
                // (denendi: "Progress bar value … must be valid numbers").
                // Yüzde işaretini ekran okuyucunun kendisi ekler; bu yüzden
                // burada `'%{}'` anahtarı KULLANILAMAZ, kullanılmadı.
                semanticsLabel: seviye.etiket,
                semanticsValue: '${(oran * 100).round()}',
              ),
            ),
          ],
          if (alt != null) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.trending_up,
                    size: 13,
                    color: DiziRenkler.metin54,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    alt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: DiziRenkler.metin54),
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

/// Rozet çipi: kazanılanlar sarı, kalanlar soluk + ilerleme.
class RozetCipi extends StatelessWidget {
  final Map<String, dynamic> rozet;

  const RozetCipi({super.key, required this.rozet});

  static const _bilgi = {
    'ilk_bolum': (Icons.play_arrow_rounded, 'İlk Bölüm'),
    'bolum_100': (Icons.local_fire_department_outlined, '100 Bölüm'),
    'bolum_500': (Icons.bolt_outlined, '500 Bölüm'),
    'bolum_1000': (Icons.workspace_premium_outlined, '1000 Bölüm'),
    'bolum_5000': (Icons.diamond_outlined, '5000 Bölüm'),
    'ilk_film': (Icons.movie_outlined, 'İlk Film'),
    'film_10': (Icons.movie_filter_outlined, '10 Film'),
    'film_50': (Icons.theaters_outlined, '50 Film'),
    'film_100': (Icons.camera_roll_outlined, '100 Film'),
    'ilk_yorum': (Icons.chat_bubble_outline, 'İlk Yorum'),
    'yorum_25': (Icons.forum_outlined, '25 Yorum'),
    'yorum_100': (Icons.campaign_outlined, '100 Yorum'),
    'puan_10': (Icons.star_outline_rounded, '10 Puan'),
    'puan_50': (Icons.star_half_rounded, '50 Puan'),
    'puan_100': (Icons.stars_outlined, '100 Puan'),
    'ilk_takipci': (Icons.person_add_alt, 'İlk Takipçi'),
    'takipci_10': (Icons.group_outlined, '10 Takipçi'),
    'takipci_50': (Icons.groups_outlined, '50 Takipçi'),
    'bitiren_10': (Icons.emoji_events_outlined, '10 Dizi Bitirdin'),
    'bitiren_25': (Icons.military_tech_outlined, '25 Dizi Bitirdin'),
    'bitiren_50': (Icons.workspace_premium, '50 Dizi Bitirdin'),
    'begeni_10': (Icons.favorite_border, '10 Beğeni'),
    'begeni_100': (Icons.volunteer_activism_outlined, '100 Beğeni'),
  };

  @override
  Widget build(BuildContext context) {
    final kod = rozet['kod'] as String? ?? '';
    final kazanildi = rozet['kazanildi'] == true;
    final (ikon, ad) = _bilgi[kod] ?? (Icons.military_tech_outlined, kod);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: kazanildi ? DiziRenkler.sari : DiziRenkler.kart,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ikon,
            size: 15,
            color: kazanildi ? Colors.black : DiziRenkler.metin38,
          ),
          const SizedBox(width: 5),
          Text(
            ad.c,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kazanildi ? Colors.black : DiziRenkler.metin38,
            ),
          ),
          if (!kazanildi) ...[
            const SizedBox(width: 4),
            Text(
              '${rozet['deger']}/${rozet['esik']}',
              style: TextStyle(fontSize: 12, color: DiziRenkler.metin54),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kendi yorumların modalı: içerik adı + bölüm bilgisiyle listeler;
/// karta dokununca ilgili sayfaya (bölüm/dizi/film) tam hedefle gider.
class _YorumlarSheet extends StatefulWidget {
  final String kullaniciAdi;
  const _YorumlarSheet({required this.kullaniciAdi});

  @override
  State<_YorumlarSheet> createState() => _YorumlarSheetState();
}

class _YorumlarSheetState extends State<_YorumlarSheet> {
  Map<String, dynamic>? _veri;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final d = await Api.acikProfil(widget.kullaniciAdi);
      if (mounted) setState(() => _veri = d);
    } catch (e) {
      if (mounted) setState(() => _hata = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final yorumlar = (_veri?['yorumlar'] as List<dynamic>? ?? []);
    final icerikler = _veri?['icerikler'] as Map<String, dynamic>? ?? {};

    Widget govde;
    if (_hata != null) {
      govde = Center(
        child: Text(_hata!, style: TextStyle(color: DiziRenkler.metin54)),
      );
    } else if (_veri == null) {
      govde = const Center(
        child: CircularProgressIndicator(color: DiziRenkler.sari),
      );
    } else if (yorumlar.isEmpty) {
      govde = Center(
        child: Text(
          'Henüz yorum yok.'.c,
          style: TextStyle(color: DiziRenkler.metin38),
        ),
      );
    } else {
      govde = ListView(
        // ALT GÜVENLİ ALAN: ListeSheet ile aynı hata — açık `padding` verilince
        // Flutter alt sistem payını kendiliğinden eklemez, son yorum kartı
        // navi çubuğunun altında kalıyordu.
        padding: EdgeInsets.fromLTRB(
          14,
          0,
          14,
          altGuvenli(context, ekstra: 20),
        ),
        children: [
          for (final y in yorumlar)
            ProfilYorumKarti(
              yorum: y as Map<String, dynamic>,
              icerikler: icerikler,
            ),
        ],
      );
    }

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline, color: DiziRenkler.sariMetin),
                const SizedBox(width: 8),
                Text(
                  'Yorumlar'.c,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (yorumlar.isNotEmpty)
                  Text(
                    '${yorumlar.length}',
                    style: TextStyle(color: DiziRenkler.metin54),
                  ),
              ],
            ),
          ),
          Expanded(child: govde),
        ],
      ),
    );
  }
}

/// Profil ekranlarının boydan boya iki sekmesi: "Dizi ve Filmler" / "Yorumlar".
///
/// Kendi profilimiz (profil.dart) ve başkasının profili (kullanici_profil.dart)
/// AYNI widget'ı kullanır; görsel dil ayrışmasın diye kopyalanmadı.
class ProfilSekmeleri extends StatelessWidget {
  /// Seçili sekme: 0 = Dizi ve Filmler, 1 = Yorumlar.
  final int secili;
  final ValueChanged<int> onSec;

  const ProfilSekmeleri({super.key, required this.secili, required this.onSec});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final (i, ikon, etiket) in const [
            (0, Icons.movie_outlined, 'Dizi ve Filmler'),
            (1, Icons.mode_comment_outlined, 'Yorumlar'),
          ])
            Expanded(
              child: InkWell(
                onTap: () => onSec(i),
                child: Container(
                  // Dokunma hedefi: 12+12 dikey dolgu + metin ≈ 45px
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: secili == i ? 2.5 : 1,
                        color: secili == i
                            ? DiziRenkler.sari
                            : DiziRenkler.metin12,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        ikon,
                        size: 18,
                        color: secili == i
                            ? DiziRenkler.sariMetin
                            // Seçili değil: gri değil, tema metni (koyu=beyaz).
                            : DiziRenkler.metin,
                      ),
                      const SizedBox(width: 6),
                      // Flexible + FittedBox: uzun çeviri (hu "Sorozatok és
                      // filmek", fi "Sarjat ja elokuvat") dar telefonda yarım
                      // sekmeye sığmayınca taşmak yerine bir miktar küçülür;
                      // etiket tek satırda TAM okunur kalır.
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            etiket.c,
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: secili == i
                                  ? DiziRenkler.sariMetin
                                  : DiziRenkler.metin,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Profilin "Yorumlar" sekmesi: kullanıcının dizi/filmlere yazdığı yorumlar,
/// Twitter profili gibi tek akışta.
///
/// Beğeni ve yanıtlar İÇERİK SAYFASIYLA AYNI kayıtlar üzerinde çalışır
/// (POST /yorumlar/:id/begen ve YanitlarSheet). Yani buradan atılan beğeni
/// Breaking Bad sayfasındaki yorumda da görünür, tersi de geçerli.
class ProfilYorumAkisi extends StatelessWidget {
  final List<dynamic> yorumlar;
  final Map<String, dynamic> icerikler;

  /// Boş durumun alt satırı. Kendi profilinde "yazdığın yorumlar..." denir,
  /// başkasının profilinde ikinci tekil şahıs yanlış olur → verilmez.
  final String? ipucu;

  /// Bu liste OTURUM SAHİBİNİN profilinde mi çiziliyor? Yalnız true iken
  /// karta basılı tutulunca "sil / profilimde gizle" menüsü açılır. Başkasının
  /// profilinde (ve kartın kullanıldığı akış, Reels, /gonderi ekranlarında)
  /// uzun basma tanıyıcısı HİÇ kurulmaz.
  final bool benimProfilim;

  /// Sil/gizle sonrası listeyi tazelemek için çağrılır (profil ekranı `_yukle`).
  final Future<void> Function()? onDegisti;

  const ProfilYorumAkisi({
    super.key,
    required this.yorumlar,
    required this.icerikler,
    this.ipucu,
    this.benimProfilim = false,
    this.onDegisti,
  });

  @override
  Widget build(BuildContext context) {
    if (yorumlar.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: BosDurum(
          ikon: Icons.mode_comment_outlined,
          baslik: 'Henüz yorum yok'.c,
          ipucu: ipucu,
        ),
      );
    }
    // EKRANDA ÇİZİLEN gönderiler: yanıt satırlarında tam kart ASIL gönderiyi
    // çizer, üst seviye satırlarda satırın kendisini. Reels de BU listeyi alır
    // — yoksa medyaya dokununca kartta görülenden başka bir gönderi açılırdı.
    final gorunenler = [
      for (final ham in yorumlar) kartGonderisi(ham as Map<String, dynamic>),
    ];
    // Kartlar akıştakiyle BİREBİR aynı geometride durur: yatay dolgu YOK
    // (kart ekranın sağına-soluna dayanır, medya da tam yayılır), geniş
    // ekranda ise akış ile AYNI okuma kolonu ([masaustuKolonGenisligi]).
    return OrtaKolon(
      azami: masaustuKolonGenisligi,
      cocuk: Column(
        children: [
          for (var i = 0; i < yorumlar.length; i++)
            Builder(
              builder: (context) {
                final y = yorumlar[i] as Map<String, dynamic>;
                final ust = y['ust'] as Map<String, dynamic>?;
                final yanit = tamKartlikUst(ust);
                // Basılı tutma DAİMA SENİN yorumunu (y) hedefler — kart
                // yanıtta ASIL gönderiyi çizse bile. Bu satır yanlış
                // olursa menü başkasının gönderisini silmeye çalışır.
                final uzunBas = benimProfilim
                    ? () => yorumEylemleriAc(context, y, onDegisti)
                    : null;
                final kart = AkisKarti(
                  // Anahtar SATIRIN kimliğinden üretilir: iki ayrı yanıtın
                  // üstü AYNI gönderi olabilir, üst kimliği kullanılsaydı
                  // aynı Column'da çakışan anahtarlar oluşurdu.
                  key: ValueKey(y['id']),
                  yorum: gorunenler[i],
                  icerikler: icerikler,
                  // Medyaya dokununca Reels: akışta olduğu gibi, dokunulan
                  // kareden başlar ve listede kaydırmaya devam edilir.
                  onMedyaAc: (mi) =>
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                          builder: (_) => ReelsGorunumu(
                            liste: gorunenler,
                            icerikler: icerikler,
                            baslangic: i,
                            medyaBaslangic: mi,
                            // md. 23: profil ızgarasından açılan görüntülenme
                            // "profil" kovasına yazılır.
                            kaynak: GonderiOlcu.kaynakProfil,
                          ),
                        ),
                      ),
                  onUzunBas: uzunBas,
                );
                // Yanıt DEĞİLSE (dizi/filme yazılmış üst seviye gönderi)
                // hiçbir şey eklenmez: bugünkü görünüm birebir korunur.
                if (!yanit) return kart;
                return RepaintBoundary(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Kart ASIL gönderiyi çiziyor → kartın boş bir yerine
                      // dokunmak o gönderiyi açar. Kartın kendi bağlantıları
                      // (avatar, kullanıcı adı, içerik adı, medya) ağaçta
                      // DAHA DERİN olduğu için dokunma arenasını onlar
                      // kazanır; bu sarmalayıcı yalnız artan alanı toplar.
                      GestureDetector(
                        behavior: HitTestBehavior.deferToChild,
                        onTap: () => context.push('/gonderi/${ust!['id']}'),
                        child: kart,
                      ),
                      YanitBlogu(yorum: y, onUzunBas: uzunBas),
                      // Grup içi boşluk 8 (kartın alt kenar boşluğu), gruplar
                      // arası 24 → yakınlık ilkesi blokla üstündeki kartın
                      // TEK öge olduğunu söyler.
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// `ust` alanı TAM KART çizmeye yetiyor mu?
///
/// Eski sunucu sürümü yalnız alıntı özeti döndürüyordu (kullanıcı adı + kısa
/// metin + medya bayrağı); `tur` alanı o sürümde YOKTU. Web istemcisi sunucudan
/// önce güncellenirse yanıt satırı sessizce eski görünüme (senin yorumun tam
/// kart, bağlam bloğu yok) düşer — boş/`?` içerikli kart çizilmez.
bool tamKartlikUst(Map<String, dynamic>? ust) =>
    ust != null && ust['tur'] != null;

/// Profil satırında EKRANDA tam kart olarak çizilecek gönderi: yanıtlarda
/// yanıtlanan ASIL gönderi, üst seviye yorumlarda satırın kendisi.
Map<String, dynamic> kartGonderisi(Map<String, dynamic> y) {
  final ust = y['ust'] as Map<String, dynamic>?;
  return tamKartlikUst(ust) ? ust! : y;
}

/// YANIT BLOĞU — profildeki satır bir başka gönderiye yanıtsa, ÜSTTEKİ tam
/// kartın (yanıtlanan ASIL gönderi) altında duran sarı sol şeritli blok.
/// İçinde profil sahibinin YANITI yazar.
///
/// Düzen 3 Ağu 2026'da kullanıcı isteğiyle TERSİNE çevrildi: eskiden üstte
/// asıl gönderinin alıntısı, altında senin yorumun tam kart olarak duruyordu.
///
/// TAM KART TEK: yanıt burada alıntı biçiminde kalır, KENDİ EYLEM SATIRI
/// (kalp/yorum/paylaş) YOKTUR. Böylece bir ögede tek kart, tek eylem satırı,
/// tek kalp bulunur — kullanıcı hangisini beğendiğini bilir (kalp üstteki
/// ASIL gönderinindir, akıştaki gibi). Aynı sebeple yanıtın medyası da burada
/// galeri olarak açılmaz, yalnız küçük bir ikonla belirtilir: aksi hâlde her
/// yanıt satırında İKİNCİ bir otomatik oynayan video olurdu.
///
/// Dokununca yanıtın kendi sayfasına (`/gonderi/:id`) gidilir; tam metin,
/// medyası ve ona gelen yanıtlar orada görülür.
class YanitBlogu extends StatelessWidget {
  /// Profil sahibinin yorumu (yanıt satırının KENDİSİ, üstü değil).
  final Map<String, dynamic> yorum;

  /// Kendi profilinde basılı tutunca sil/gizle menüsü. Üstteki kartla AYNI
  /// geri çağırma verilir ki grubun neresine basılırsa basılsın menü SENİN
  /// yorumunu hedeflesin.
  final VoidCallback? onUzunBas;

  const YanitBlogu({super.key, required this.yorum, this.onUzunBas});

  @override
  Widget build(BuildContext context) {
    final ust = yorum;
    final spoiler = ust['spoiler'] == true;
    final metin = (ust['metin'] as String?) ?? '';
    final medyaVar = (ust['medya'] as List<dynamic>? ?? const []).isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.push('/gonderi/${ust['id']}'),
        onLongPress: onUzunBas,
        child: Container(
          // Dokunma hedefi: blok zaten iki satır metin + başlık ile 44px'in
          // çok üstünde; yine de alt sınır konur (tek kelimelik gönderi).
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: DiziRenkler.koyuGri,
            borderRadius: BorderRadius.circular(10),
            // Sol şerit: klasik "alıntı" işareti — bu blok yorumun DEĞİL,
            // yanıt verilen gönderinin.
            border: Border(
              left: BorderSide(color: DiziRenkler.sariMetin, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Aşağı-sağa kıvrılan ok: blok üstteki gönderinin ALTINA
                  // bağlıdır. Metin ikinci tekil şahıs DEĞİL — aynı widget
                  // başkasının profilinde de çiziliyor, "yanıtın" orada
                  // yanlış olurdu; kimin yanıtı olduğunu alttaki avatar ve
                  // @kullanıcı adı zaten söylüyor.
                  Icon(
                    Icons.subdirectory_arrow_right,
                    size: 13,
                    color: DiziRenkler.metin38,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Bu gönderiye yanıt'.c,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: DiziRenkler.metin38,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KullaniciAvatari(
                    url: dosyaUrl(ust['avatar'] as String?),
                    kullaniciAdi: ust['kullanici_adi'] as String?,
                    yaricap: 10,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@${ust['kullanici_adi']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: DiziRenkler.metin,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Spoiler işaretli gönderinin metni alıntıda AÇILMAZ:
                        // akış kartındaki perdeyi burada delmek olurdu.
                        // 6 satır: blok artık ASIL içeriği (yanıtın kendisi)
                        // taşıyor, iki satır onu kırpardı; taşarsa dokununca
                        // gönderi sayfasında tamamı okunur.
                        Text(
                          spoiler
                              ? 'Spoiler içeren gönderi'.c
                              : (metin.isEmpty && medyaVar
                                    ? 'Görsel gönderi'.c
                                    : metin),
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            fontStyle: spoiler ? FontStyle.italic : null,
                            color: spoiler
                                ? DiziRenkler.metin38
                                : DiziRenkler.metin70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (medyaVar && !spoiler) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.image_outlined,
                      size: 15,
                      color: DiziRenkler.metin38,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// KENDİ PROFİLİNDE karta basılı tutunca açılan menü: yorumu sil / profilde
/// gizle. Yalnız [ProfilYorumAkisi.benimProfilim] true iken bağlanır.
///
/// Silme YIKICI ve geri alınamaz → ayrıca onay istenir.
/// Gizleme geri alınabilir → onay yok, SnackBar + "Geri al".
///
/// [yorum] DAİMA kullanıcının kendi yorumudur. Yanıt satırlarında ekrandaki
/// tam kart yanıtlanan ASIL gönderiyi çizdiği için hangi ögenin silineceği
/// göz kararı belli olmaz — bu yüzden sheet'in tepesinde hedef yorumun metni
/// tek satır önizlenir.
Future<void> yorumEylemleriAc(
  BuildContext context,
  Map<String, dynamic> yorum,
  Future<void> Function()? onDegisti,
) async {
  final disBaglam = context;
  final onizleme = duzMetin((yorum['metin'] as String?) ?? '').trim();
  final secim = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: DiziRenkler.koyuGri,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(
              color: DiziRenkler.metin24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Hedefin kanıtı: aşağıdaki iki eylem BU yorumu etkiler.
          if (onizleme.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
              child: Text(
                onizleme,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: DiziRenkler.metin54, fontSize: 12.5),
              ),
            ),
          ListTile(
            leading: Icon(
              Icons.visibility_off_outlined,
              color: DiziRenkler.sariMetin,
            ),
            title: Text(
              'Bu yorumu profilimde gizle'.c,
              style: TextStyle(color: DiziRenkler.metin),
            ),
            subtitle: Text(
              'Yorum dizi ve film sayfasında durmaya devam eder'.c,
              style: TextStyle(color: DiziRenkler.metin54, fontSize: 12),
            ),
            onTap: () => Navigator.pop(sheet, 'gizle'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title: Text(
              'Bu yorumu sil'.c,
              style: const TextStyle(color: Colors.redAccent),
            ),
            onTap: () => Navigator.pop(sheet, 'sil'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (secim == null || !disBaglam.mounted) return;
  final id = yorum['id'] as int;
  if (secim == 'gizle') {
    try {
      await Api.post('/yorumlar/$id/profilde-gizle', {'gizli': true});
      await onDegisti?.call();
      if (!disBaglam.mounted) return;
      ScaffoldMessenger.of(disBaglam).showSnackBar(
        SnackBar(
          content: Text('Yorum profilinde gizlendi'.c),
          action: SnackBarAction(
            label: 'Geri al'.c,
            onPressed: () async {
              try {
                await Api.post('/yorumlar/$id/profilde-gizle', {
                  'gizli': false,
                });
                await onDegisti?.call();
              } catch (_) {
                /* geri alma başarısızsa yorum Ayarlar > Gizlenen
                   yorumlar ekranından geri getirilebilir */
              }
            },
          ),
        ),
      );
    } catch (e) {
      if (!disBaglam.mounted) return;
      ScaffoldMessenger.of(
        disBaglam,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    return;
  }
  // ---- Silme: geri alınamaz, önce onay.
  final onay = await showDialog<bool>(
    context: disBaglam,
    builder: (dlg) => AlertDialog(
      backgroundColor: DiziRenkler.koyuGri,
      title: Text('Yorum silinsin mi?'.c),
      content: Text(
        'Bu yorum her yerden kalıcı olarak silinir. Geri alınamaz.'.c,
        style: TextStyle(color: DiziRenkler.metin70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dlg, false),
          child: Text('İptal'.c),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () => Navigator.pop(dlg, true),
          child: Text('Sil'.c),
        ),
      ],
    ),
  );
  if (onay != true || !disBaglam.mounted) return;
  try {
    await Api.delete('/yorumlar/$id');
    await onDegisti?.call();
    if (!disBaglam.mounted) return;
    ScaffoldMessenger.of(
      disBaglam,
    ).showSnackBar(SnackBar(content: Text('Yorum silindi'.c)));
  } catch (e) {
    if (!disBaglam.mounted) return;
    ScaffoldMessenger.of(
      disBaglam,
    ).showSnackBar(SnackBar(content: Text(e.toString())));
  }
}
