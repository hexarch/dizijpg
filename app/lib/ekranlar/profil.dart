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
import '../icerik_deposu.dart';
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
                    style: TextStyle(fontSize: 11, color: DiziRenkler.metin),
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

  /// Son tazelemede EN AZ BİR uç düştü ama ekranda (önbellekten ya da önceki
  /// turdan) veri var. Ekran boşaltılmaz, ama SESSİZ de kalınmaz: üstte
  /// "Bağlantı koptu — Yenile" şeridi çıkar (takvim.dart'taki `_durumSeridi`
  /// ile aynı disiplin).
  ///
  /// NEDEN VAR (21 Ağu 2026, canlıda ÖLÇÜLDÜ): emülatörde `/izlediklerim`
  /// 20 sn zaman aşımına düşünce `Future.wait` TÜM turu düşürüyordu; eski
  /// `catch` bloğu `_profil != null` diye hatayı YUTUYORDU. Ekran saatlerce
  /// bayat önbellekle duruyor, kullanıcı bunu bilmiyordu — "Toplam İzleme
  /// Süresi kartı açılmıyor" hatası tam olarak buydu (kırılım alanları TAZE
  /// yanıtta vardı, ekrana hiç ulaşmıyordu).
  bool _tazelemeHatasi = false;

  /// Bu turda sunucudan EN AZ BİR taze yanıt geldi mi? SWR önbelleği yalnız
  /// bu bayrak `false` iken ekrana basılabilir (bkz. [_onbellektenYukle]).
  bool _tazeVeri = false;
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
        trailing: Icon(Icons.chevron_right, color: DiziRenkler.metin),
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
  ///
  /// [_tazeVeri] KONTROLÜ ŞART: `_yukle` artık KISMİ başarıyla dönebiliyor
  /// (bkz. [_cek]). `_profil` bakmak yetmez — `/profilim` düşüp
  /// `/istatistiklerim` gelmiş olabilir; o durumda bayat kopya taze sayıların
  /// ÜSTÜNE yazardı.
  Future<void> _onbellektenYukle() async {
    final d = await Onbellek.oku('profil');
    if (d == null || !mounted || _tazeVeri) return;
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

  /// Tek ucu çeker; DÜŞERSE turu düşürmez, `null` döner ve hatayı [hatalar]
  /// listesine yazar.
  ///
  /// NEDEN (21 Ağu 2026, canlıda ölçülen hata): burada `Future.wait` vardı ve
  /// HEPSİ YA DA HİÇBİRİ çalışıyordu. Emülatörde `/izlediklerim` 20 sn zaman
  /// aşımına düştüğünde, ELDE OLAN `/istatistiklerim` yanıtı da çöpe gidiyor
  /// ve ekran bayat önbellekle kalıyordu. O bayat kopya 21 Ağu öncesinden
  /// kaldığı için `tahmini_dakika_dizi`/`_film` alanları YOKTU; sonuç:
  /// "Toplam İzleme Süresi" kartı ok bile çizmiyor, dokununca açılmıyordu.
  /// Bir ucun arızası, ilgisiz bir kartı sessizce sakat bırakamaz.
  Future<dynamic> _cek(String yol, List<Object> hatalar) async {
    try {
      return await Api.get(yol);
    } catch (e) {
      hatalar.add(e);
      return null;
    }
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    final hatalar = <Object>[];
    final sonuclar = await Future.wait([
      _cek('/istatistiklerim', hatalar),
      _cek('/kitapligim', hatalar),
      _cek('/listelerim', hatalar),
      _cek('/profilim', hatalar),
      _cek('/izlediklerim', hatalar),
      // Rozetler EN BAŞTAN beri hatasız yürüyordu (yoksa liste boş kalır).
      _cek('/rozetler', hatalar),
    ]);
    if (!mounted) return;
    setState(() {
      // GELEN NE VARSA YAZILIR; gelmeyen ESKİ hâliyle kalır. Alan başına
      // tip kontrolü: bozuk/eksik gövde tüm turu düşürmesin.
      final ist = sonuclar[0];
      if (ist is Map<String, dynamic>) _istatistik = ist;
      final kit = sonuclar[1];
      if (kit is Map<String, dynamic>) _kitaplik = kit;
      final lst = sonuclar[2];
      if (lst is Map && lst['listeler'] is List) {
        _listeler = lst['listeler'] as List<dynamic>;
      }
      final prf = sonuclar[3];
      if (prf is Map<String, dynamic>) _profil = prf;
      final izl = sonuclar[4];
      if (izl is Map && izl['ogeler'] is List) {
        _izlenenler = izl['ogeler'] as List<dynamic>;
      }
      final roz = sonuclar[5];
      if (roz is Map) {
        _rozetler = roz['rozetler'] as List<dynamic>? ?? [];
        _seviyeHam = roz['seviye'] as Map<String, dynamic>?;
      }
      if (sonuclar.any((s) => s != null)) _tazeVeri = true;
      // Elimizde HİÇ veri yoksa tam ekran hata; varsa şerit (aşağıda).
      _tazelemeHatasi = hatalar.isNotEmpty && _istatistik != null;
      if (_istatistik == null && hatalar.isNotEmpty) {
        _hata = hatalar.first.toString();
      }
    });
    if (_istatistik == null) return;
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

  /// Süre kırılımının alt listesi: "hangi diziyi/filmi kaç saat izledim".
  /// Modal (sayfa DEĞİL): kullanıcı profilden çıkmadan bakıp kapatıyor.
  void _sureDetayAc(String tur) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DiziRenkler.koyuGri,
      builder: (_) => SureDetaySheet(tur: tur),
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
      // Sayaçların TEK çözümleyicisi: alan adlarını `/istatistiklerim`
      // şemasından okur (açık profil `ProfilSayaclari.acik` kullanır).
      final sayaclar = ProfilSayaclari.kendi(st);
      final dakika = (st['tahmini_dakika'] as num?)?.toInt() ?? 0;
      // Avatar çapı: kimlik bloğunda üç yerde geçiyor (kutu, yükleme
      // göstergesi, yer tutucu) — tek yerde tanımlı olsun.
      final double avatarCap = genis ? 104 : 76;
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
            // TAZELEME DÜŞTÜ ŞERİDİ. Ekran boşaltılmaz (elde veri var) ama
            // sessiz de kalınmaz: kullanıcı EKRANDAKİNİN ESKİ olabileceğini
            // görür ve tek dokunuşla yeniden dener. Yeni metin ANAHTARI YOK —
            // `Bağlantı koptu` ve `Yenile` 45 dilde ZATEN var.
            if (_tazelemeHatasi) ProfilTazelemeSeridi(onYenile: _yukle),
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
                //
                // KULLANICI İSTEĞİ (21 Ağu 2026, birebir): "Profil resmini
                // yukarıya kullanıcı adı ile aynı hizaya taşı. Görüntülenme
                // sayısı da altında dursun."
                //
                // `crossAxisAlignment: start` TAM OLARAK BUNU YAPAR: Row'un
                // VARSAYILANI `center` ve sağdaki sütun (ad + seviye + bio +
                // ülke + sayaçlar) avatardan çok daha uzun olduğu için avatar
                // ortalanıyor, adın epey ALTINA düşüyordu. Şimdi ikisinin de
                // ÜST kenarı aynı çizgide.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
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
                            width: avatarCap,
                            height: avatarCap,
                            child: _gorselYukleniyor
                                ? CircleAvatar(
                                    radius: avatarCap / 2,
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
                                : dosyaUrl(_profil?['avatar'] as String?) !=
                                      null
                                ? DaireGorsel(
                                    url: dosyaUrl(
                                      _profil!['avatar'] as String,
                                    )!,
                                    cap: avatarCap,
                                    arkaplan: DiziRenkler.kart,
                                    ikonRenk: DiziRenkler.metin38,
                                  )
                                : CircleAvatar(
                                    radius: avatarCap / 2,
                                    backgroundColor: DiziRenkler.kart,
                                    child: Icon(
                                      Icons.person,
                                      size: 38,
                                      color: DiziRenkler.metin38,
                                    ),
                                  ),
                          ),
                        ),
                        // GÖRÜNTÜLENME AVATARIN ALTINDA (aynı istek).
                        //
                        // Neden hâlâ [TakipSayac]: yandaki üç sayaçla AYNI
                        // biçim ve AYNI 44 dp dokunma hedefi; ayrıca hedefi
                        // (yorum modali) da değişmedi. `ProfilTakipSatiri`
                        // ise `goruntulenmeGoster: false` ile çiziliyor —
                        // AÇIK PROFİL o bileşeni varsayılanıyla kullandığı
                        // için orada dördü de yerinde kalıyor.
                        //
                        // GENİŞLİK avatardan 24 dp geniş: "görüntülenme"
                        // (pl "wyświetlenia", de "Aufrufe") 76 dp'ye sığmayıp
                        // kırpılıyordu. Sınırsız bırakmak da olmazdı —
                        // Column mainAxisSize.min en geniş çocuğu alır ve
                        // kullanıcı adı sütununu daraltırdı.
                        SizedBox(
                          width: avatarCap + 24,
                          child: TakipSayac(
                            deger: ProfilSayaclari.yaz(sayaclar.goruntulenme),
                            etiket: 'görüntülenme'.c,
                            onTap: () => _yorumlarAc(kullaniciAdi),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Görünen ad (varsa) + kullanıcı adı + (testçiyse)
                          // altın onay tiki.
                          // KULLANICI İSTEĞİ (7 Ağu): tik adın hemen yanında;
                          // "Founding Member" yazısı + dizi.jpg logosu gitti.
                          // Bu ekran DAİMA kendi profilim (`/profilim` ile
                          // çizilir), o yüzden `benMi: true` — modal ikinci
                          // tekil şahıs varyantını gösterir.
                          //
                          // 21 Ağu 2026: blok ORTAK bileşene taşındı
                          // ([ProfilKimlikBasligi]) — görünen ad iki ekranda
                          // da AYNI kodla çiziliyor. KOPYALAMA YASAK: bu iki
                          // ekran bugün tam da kopyalama yüzünden ayrışmıştı.
                          ProfilKimlikBasligi(
                            ad: _profil?['ad'] as Object?,
                            kullaniciAdi: kullaniciAdi,
                            testci: _profil?['testci'] == true,
                            benMi: true,
                            genis: genis,
                          ),
                          // SEVİYE (md. 29): kullanıcı adının HEMEN ALTINDA.
                          // Bu ekran DAİMA kendi profilim — ilerleme çubuğu
                          // ve "Sonraki seviyeye …" satırı BURADA çizilir,
                          // açık profilde çizilmez (veri de oraya gitmez).
                          if (Seviye.ekranda(_seviyeHam) case final sv?)
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
                                  color: DiziRenkler.metin,
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
                          // Takipçi / takip / beğeni / görüntülenme.
                          //
                          // Beğeni ve görüntülenme 15 Ağu 2026'da buraya
                          // TAŞINDI (kullanıcı isteği): önceden aşağıda ayrı
                          // kutulu `EtkilesimSatiri` şeridiydi, şimdi takipçi
                          // ve takiple AYNI satır içi biçimde duruyor.
                          //
                          // 21 Ağu 2026: blok ORTAK bileşene taşındı
                          // ([ProfilTakipSatiri]) — açık profil de birebir
                          // aynısını çiziyor (kullanıcı isteği). Biçim
                          // kararları (Wrap, küçük harf etiket) orada yazılı.
                          //
                          // 21 Ağu 2026 (akşam): görüntülenme BURADAN çıktı,
                          // avatarın ALTINA taşındı (kullanıcı isteği). Bileşen
                          // bayrakla söndürülüyor, ÇATALLANMIYOR: açık profil
                          // aynı sınıfı VARSAYILANIYLA çağırdığı için orada
                          // dört sayaç yerinde duruyor.
                          ProfilTakipSatiri(
                            sayac: sayaclar,
                            goruntulenmeGoster: false,
                            takipciTap: () => _takipListe(kullaniciAdi, true),
                            takipTap: () => _takipListe(kullaniciAdi, false),
                            etkilesimTap: () => _yorumlarAc(kullaniciAdi),
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
                // Bölüm / film / dizi / yorum.
                //
                // 21 Ağu 2026 (kullanıcı isteği): yuvarlak [StatMadalyon]
                // düzeni BURADAN kalktı, yerine açık profildeki eşit sütunlu
                // [ProfilOlcumSatiri] geldi — "kendi profilimdeki bölüm, film,
                // dizi, yorum da başkasının profiline baktığımdaki gibi
                // gözüksün". Sayaçlar tıklanır kaldı: ilgili liste/modal açılır.
                ProfilOlcumSatiri(
                  sayac: sayaclar,
                  bolumTap: () => context.push('/izlediklerim?tur=tv'),
                  filmTap: () => context.push('/izlediklerim?tur=movie'),
                  diziTap: () => context.push('/izlediklerim?tur=tv'),
                  yorumTap: () => _yorumlarAc(kullaniciAdi),
                ),
                const SizedBox(height: 10),
                // Toplam ekran süresi (yıl/ay/gün) — DOKUNUNCA AÇILIR
                EkranSuresiKarti(
                  dakika: dakika,
                  diziDakika: (st['tahmini_dakika_dizi'] as num?)?.toInt(),
                  filmDakika: (st['tahmini_dakika_film'] as num?)?.toInt(),
                  bolumBirimDk: (st['sure_bolum_dk'] as num?)?.toInt(),
                  filmBirimDk: (st['sure_film_dk'] as num?)?.toInt(),
                  // Kaynak karışımı (21 Ağu 2026): süre artık TMDB'nin GERÇEK
                  // dakikasından çıkıyor, sabit yalnız yedek. Alanlar yoksa
                  // (eski sunucu/bayat kopya) kart eski davranışa düşer.
                  kaynak: SureKaynagi.oku(
                    st,
                    'sure_gercek_dk',
                    'sure_tahmini_dk',
                  ),
                  diziTahmini: (st['sure_tahmini_dk_dizi'] as num?)?.toInt(),
                  filmTahmini: (st['sure_tahmini_dk_film'] as num?)?.toInt(),
                  onTur: _sureDetayAc,
                ),
                // NOT: yorumların toplam beğeni/görüntülenmesi buradaki kutulu
                // `EtkilesimSatiri` şeridinden ÇIKARILDI (15 Ağu 2026); artık
                // yukarıda takipçi/takip ile aynı satır içi biçimde duruyor.
                // Sınıfın kendisi DURUYOR: açık profil (kullanici_profil.dart)
                // hâlâ o düzeni kullanıyor.
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

// ===========================================================================
// GÖRÜNEN AD + KULLANICI ADI — İKİ EKRAN, TEK BİLEŞEN (21 Ağu 2026)
// ===========================================================================

/// Profil başlığının kimlik satırı: **görünen ad ÜSTTE, kullanıcı adı ALTTA**.
///
/// Ayarlardaki alanın kendi açıklaması bunu vaat ediyor: "Profilinde kullanıcı
/// adının ÜSTÜNDE görünür. Boş bırakabilirsin." `kullanicilar.ad` sütunu,
/// ayarlar alanı ve iki uç (`GET /profilim`, `GET /profil/:kullaniciAdi`) aynı
/// gün eklendi ama HİÇBİR ekran çizmiyordu — kullanıcı adını kaydedip "neden
/// görünmüyor?" diye sordu. Bu sınıf o boşluğu kapatan TEK çizim yeridir.
///
/// --- AD BOŞKEN HİÇBİR ŞEY DEĞİŞMEZ ---
/// Ad `null`/boş ise ÜST satır yine kullanıcı adıdır ve ikinci satır HİÇ
/// çizilmez (boş `Text` bile değil — `SizedBox.shrink` de değil). Yani ad
/// koymayan kullanıcı için başlığın yüksekliği ve hizası BİREBİR eskisi gibi
/// kalır; altındaki seviye/bio/ülke/sayaç satırları kaymaz.
/// Kanıt: test/profil_gorunen_ad_test.dart → "ad boşken yerleşim BİREBİR aynı".
///
/// --- ROZET NEREDE (karar) ---
/// [AileRozeti] BİRİNCİL SATIRDA kalır: yani ad varsa ADIN yanında, yoksa
/// kullanıcı adının yanında. Gerekçe: tik bir KİMLİK DOĞRULAMA nişanı ve
/// doğruladığı şey ekranın en belirgin kimlik öğesidir (X, Instagram, TV Time
/// hepsinde tik görünen adın yanındadır). İkincil satıra bırakılsaydı 44 dp'lik
/// dokunma hedefi 13 px'lik bir satırı iki katına şişirir, ayrıca ad varken
/// yokken tikin dikey konumu oynardı.
///
/// --- NEDEN KULLANICI ADI GRİ DEĞİL ---
/// Görsel hiyerarşi PUNTO ve KALINLIKLA kuruluyor (17/21 w900 → 13/15 w600),
/// renkle DEĞİL. KULLANICI İSTEĞİ (16 Ağu 2026): gri yazı yalnız PASİF öğede
/// (kapalı düğme, ipucu, boş yer tutucu); kullanıcı adı pasif değil, profilin
/// adresidir. Kilit: test/gri_yazi_ikon_test.dart + bu dosyanın renk testi.
///
/// --- UZUN AD ---
/// Sunucu 40 KOD NOKTASINA kadar ad kabul ediyor (`AD_AZAMI`, server.js) ve
/// KIRPMIYOR — reddediyor. O yüzden taşmayı ekran karşılamak zorunda:
/// `Flexible` + `maxLines: 1` + `TextOverflow.ellipsis`. 320 dp'lik en dar
/// telefonda bile satır taşmaz, tik ekran dışına itilmez.
class ProfilKimlikBasligi extends StatelessWidget {
  /// Ham `ad` alanı. Tipi bilerek `Object?`: doğrudan JSON gövdesinden
  /// (`_profil['ad']`) geçiriliyor — `null`, `''`, yalnız boşluk, hatta bozuk
  /// bir gövdede sayı bile olabilir. Ayıklama tek yerde: [temiz].
  final Object? ad;
  final String kullaniciAdi;
  final bool testci;

  /// Rozet modalinin ikinci tekil şahıs varyantı için (sunucunun `ben_mi`si).
  final bool benMi;

  /// Masaüstü ölçüleri. İKİ EKRAN AYNI ÖLÇÜYÜ KULLANIR: açık profil eskiden
  /// sabit 18 px yazıyordu, kendi profilim 17/21 — kullanıcı 21 Ağu'da
  /// "kullanıcı adı ikisinde de kendi profilime baktığımdaki gibi gözüksün"
  /// dediği için ölçü de buraya taşındı.
  final bool genis;

  const ProfilKimlikBasligi({
    super.key,
    required this.ad,
    required this.kullaniciAdi,
    this.testci = false,
    this.benMi = false,
    this.genis = false,
  });

  /// Ekrana yazılacak görünen ad, yoksa `null`.
  ///
  /// Sunucu boş adı zaten NULL'a düşürüyor (`adDogrula`), ama istemci buna
  /// GÜVENMEZ: önbellekteki bayat profil kaydı eski bir sunucudan gelmiş
  /// olabilir ve `ad` alanı hiç bulunmayabilir ya da `''` olabilir. Tip de
  /// kontrol ediliyor — bozuk gövde `as String` ile çökmesin.
  static String? temiz(Object? ham) {
    if (ham is! String) return null;
    final t = ham.trim();
    return t.isEmpty ? null : t;
  }

  @override
  Widget build(BuildContext context) {
    final gorunenAd = temiz(ad);
    final etiket = '@$kullaniciAdi';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // BİRİNCİL SATIR: ad varsa ad, yoksa kullanıcı adı. Tik hep burada.
        Row(
          children: [
            Flexible(
              child: Text(
                gorunenAd ?? etiket,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: genis ? 21 : 17,
                  fontWeight: FontWeight.w900,
                  // Tema metni açıkça veriliyor: gövde stili web'de soluk
                  // görünebiliyor (kullanıcı: gri yazma).
                  color: DiziRenkler.metin,
                ),
              ),
            ),
            if (testci) AileRozeti(benMi: benMi, olcu: genis ? 22 : 19),
          ],
        ),
        // İKİNCİL SATIR YALNIZ AD VARKEN. Ad yoksa bu dal hiç çizilmez —
        // boş satır/kayma olmaz (bkz. sınıf yorumu).
        if (gorunenAd != null)
          Text(
            etiket,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: genis ? 15 : 13,
              fontWeight: FontWeight.w600,
              color: DiziRenkler.metin,
            ),
          ),
      ],
    );
  }
}

// ===========================================================================
// PROFİL SAYAÇLARI — İKİ EKRAN, TEK KAYNAK (21 Ağu 2026)
// ===========================================================================
// KULLANICI İSTEĞİ (birebir): "Kendi profilime baktığımda ve başkasının
// profiline baktığımda farklılıklar var, biraz mix yapacağız. Kullanıcı adı,
// Ülke, takipçi, takip, beğeni, görüntülenme İKİSİNDE DE kendi profilime
// baktığımdaki gibi gözüksün. Kendi profilimdeki bölüm, film, dizi, yorum da
// başkasının profiline baktığımdaki gibi gözüksün."
//
// Yani iki blok, iki farklı kaynaktan:
//  · takipçi/takip/beğeni/görüntülenme → kendi profilimin satır içi biçimi
//    ([ProfilTakipSatiri], `TakipSayac` + Wrap, küçük harf etiket)
//  · bölüm/film/dizi/yorum → açık profilin eşit sütunlu biçimi
//    ([ProfilOlcumSatiri], sarı 18 px sayı + altında etiket)
//
// BURADA DURUYORLAR ÇÜNKÜ KOPYALAMA YASAK: iki ekranın bugün ayrışmasının
// sebebi tam olarak bu blokların kopyalanmasıydı (kendi profilde 15 Ağu'da
// yapılan değişiklik açık profile hiç gitmedi). `ortak.dart` daha doğru bir ev
// olurdu ama açık profil zaten `profil.dart`tan widget alıyor (`RozetCipi`,
// `SeviyeSatiri`, `ProfilSekmeleri`…) — aynı yolu izliyoruz.

/// İki ucun sayaçlarını TEK yerde eşleyen çözümleyici.
///
/// **TUZAK:** aynı sayılar iki uçta FARKLI adlarla dönüyor —
/// `/istatistiklerim` `takipci_sayisi`/`izlenen_bolum` derken
/// `GET /profil/:kullaniciAdi` `takipci`/`bolum` diyor. Ortak bileşene ham
/// Map verseydik biri unutulunca ekranda sessizce `0` yazardı; eşleme bu
/// yüzden fabrikalarda kilitli.
///
/// **EKSİK ANAHTAR `0` DEĞİL `—` BASAR.** Gerekçe: `0` gerçek bir değer —
/// "hiç takipçin yok" ile "sunucu bu alanı göndermedi" ayırt edilemez hâle
/// gelir ve sözleşme kırıldığında kimse fark etmez (bugünkü kod eksik anahtarda
/// ekrana `null` yazıyordu, kimse görmemiş). Tire ise hem kullanıcı için
/// zararsız bir "bilinmiyor", hem gözden geçirende soru işareti yaratır.
/// Çeviri gerektirmez (simge, sözcük değil).
class ProfilSayaclari {
  final int? takipci;
  final int? takip;
  final int? begeni;
  final int? goruntulenme;
  final int? bolum;
  final int? film;
  final int? dizi;
  final int? yorum;

  const ProfilSayaclari({
    this.takipci,
    this.takip,
    this.begeni,
    this.goruntulenme,
    this.bolum,
    this.film,
    this.dizi,
    this.yorum,
  });

  /// `GET /istatistiklerim` yanıtı (kendi profilim).
  factory ProfilSayaclari.kendi(Map<String, dynamic>? st) => ProfilSayaclari(
    takipci: _sayi(st, 'takipci_sayisi'),
    takip: _sayi(st, 'takip_sayisi'),
    begeni: _sayi(st, 'toplam_begeni'),
    goruntulenme: _sayi(st, 'toplam_goruntulenme'),
    bolum: _sayi(st, 'izlenen_bolum'),
    film: _sayi(st, 'izlenen_film'),
    dizi: _sayi(st, 'takip_edilen_dizi'),
    yorum: _sayi(st, 'yorum_sayisi'),
  );

  /// `GET /profil/:kullaniciAdi` yanıtının `istatistik` alanı (açık profil).
  factory ProfilSayaclari.acik(Map<String, dynamic>? st) => ProfilSayaclari(
    takipci: _sayi(st, 'takipci'),
    takip: _sayi(st, 'takip_edilen'),
    begeni: _sayi(st, 'toplam_begeni'),
    goruntulenme: _sayi(st, 'toplam_goruntulenme'),
    bolum: _sayi(st, 'bolum'),
    film: _sayi(st, 'film'),
    dizi: _sayi(st, 'dizi'),
    yorum: _sayi(st, 'yorum'),
  );

  static int? _sayi(Map<String, dynamic>? m, String anahtar) =>
      (m?[anahtar] as num?)?.toInt();

  /// Eksik değerin ekrandaki karşılığı (bkz. sınıf yorumu).
  static const String eksik = '—';

  static String yaz(int? deger) => deger == null ? eksik : '$deger';
}

/// takipçi · takip · beğeni · görüntülenme — KENDİ PROFİLİMİN biçimi.
///
/// Row DEĞİL Wrap: dört sayaç, uzun çevirilerle (pl "obserwujących",
/// de "Aufrufe") 360 dp'de tek satıra sığmaz — Row taşma çizgisi verirdi.
///
/// Dokunma eylemleri opsiyonel: açık profilde `takipciler_gizli` /
/// `takip_edilenler_gizli` / `yorumlar_gizli` açıkken ilgili sayaç YAZILIR ama
/// dokunma bağlanmaz (sayı süzülmez — sunucu da süzmüyor).
class ProfilTakipSatiri extends StatelessWidget {
  final ProfilSayaclari sayac;
  final VoidCallback? takipciTap;
  final VoidCallback? takipTap;

  /// Beğeni ve görüntülenme AYNI hedefe gider (ikisi de yorum istatistiği).
  final VoidCallback? etkilesimTap;

  /// Görüntülenme sayacı bu satırda çizilsin mi?
  ///
  /// VARSAYILAN `true` — AÇIK PROFİL (kullanici_profil.dart) bu bileşeni
  /// varsayılanıyla çağırıyor ve orada dört sayaç yan yana kalmalı. Kendi
  /// profilim 21 Ağu 2026 akşamı `false` geçmeye başladı: kullanıcı
  /// görüntülenmeyi AVATARIN ALTINDA istedi. Bileşeni kopyalamak yerine
  /// bayrak: kopya, 15 Ağu'da kendi profilde yapılan değişikliğin açık
  /// profile hiç gitmemesine yol açan hatanın ta kendisiydi.
  final bool goruntulenmeGoster;

  const ProfilTakipSatiri({
    super.key,
    required this.sayac,
    this.takipciTap,
    this.takipTap,
    this.etkilesimTap,
    this.goruntulenmeGoster = true,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 2,
      children: [
        TakipSayac(
          deger: ProfilSayaclari.yaz(sayac.takipci),
          etiket: 'takipçi'.c,
          onTap: takipciTap,
        ),
        TakipSayac(
          deger: ProfilSayaclari.yaz(sayac.takip),
          etiket: 'takip'.c,
          onTap: takipTap,
        ),
        TakipSayac(
          deger: ProfilSayaclari.yaz(sayac.begeni),
          etiket: 'beğeni'.c,
          onTap: etkilesimTap,
        ),
        if (goruntulenmeGoster)
          TakipSayac(
            deger: ProfilSayaclari.yaz(sayac.goruntulenme),
            etiket: 'görüntülenme'.c,
            onTap: etkilesimTap,
          ),
      ],
    );
  }
}

/// bölüm · film · dizi · yorum — AÇIK PROFİLİN biçimi: eşit dört sütun,
/// üstte sarı kalın sayı, altında etiket. (Kendi profilimdeki yuvarlak
/// [StatMadalyon] düzeninin yerini aldı — kullanıcı isteği, 21 Ağu 2026.)
class ProfilOlcumSatiri extends StatelessWidget {
  final ProfilSayaclari sayac;
  final VoidCallback? bolumTap;
  final VoidCallback? filmTap;
  final VoidCallback? diziTap;
  final VoidCallback? yorumTap;

  const ProfilOlcumSatiri({
    super.key,
    required this.sayac,
    this.bolumTap,
    this.filmTap,
    this.diziTap,
    this.yorumTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProfilSayacSutunu(
          deger: ProfilSayaclari.yaz(sayac.bolum),
          etiket: 'Bölüm'.c,
          onTap: bolumTap,
        ),
        ProfilSayacSutunu(
          deger: ProfilSayaclari.yaz(sayac.film),
          etiket: 'Film'.c,
          onTap: filmTap,
        ),
        ProfilSayacSutunu(
          deger: ProfilSayaclari.yaz(sayac.dizi),
          etiket: 'Dizi'.c,
          onTap: diziTap,
        ),
        ProfilSayacSutunu(
          deger: ProfilSayaclari.yaz(sayac.yorum),
          etiket: 'Yorum'.c,
          onTap: yorumTap,
        ),
      ],
    );
  }
}

/// [ProfilOlcumSatiri]'nın tek sütunu. Açık profildeki `_Sayac`tan geldi;
/// ortak kullanım için buraya taşındı ve herkese açıldı.
///
/// `Expanded`: sütunlar EŞİT genişlikte. Etiket tek satır + ellipsis, uzun
/// çeviride ("Episodes"/"Kommentare") satır taşırmaz.
class ProfilSayacSutunu extends StatelessWidget {
  final String deger;
  final String etiket;
  final VoidCallback? onTap;
  const ProfilSayacSutunu({
    super.key,
    required this.deger,
    required this.etiket,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          // Dokunma hedefi ≥44 dp (skill md. 2). İçerik zaten ~53 dp tutuyor
          // ama kısıt AÇIKÇA yazılı olsun: yazı boyu küçülünce sessizce
          // eşiğin altına düşmesin.
          constraints: const BoxConstraints(minHeight: TakipSayac.enAzHedef),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                deger,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: DiziRenkler.sariMetin,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                etiket,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: DiziRenkler.metin),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TakipSayac extends StatelessWidget {
  final String deger;
  final String etiket;

  /// null = dokunulamaz. Açık profilde gizlilik tercihleri (`takipciler_gizli`
  /// vb.) sayacı LİSTEYE GÖTÜRMEYEN bir hâle düşürüyor; sayı yine yazılır ama
  /// dokunma bağlanmaz. Bu yüzden zorunlu değil, opsiyonel.
  final VoidCallback? onTap;
  const TakipSayac({
    super.key,
    required this.deger,
    required this.etiket,
    this.onTap,
  });

  /// Dokunma hedefi en az bu kadar yüksek (skill md. 2: ≥44 dp). 13 px'lik
  /// tek satır + 8'er dolgu yalnız ~31 dp veriyordu.
  static const double enAzHedef = 44;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      // ConstrainedBox + Center(widthFactor: 1) — Container DEĞİL.
      // 21 Ağu 2026 GERİLEME: dokunma hedefi için `Container`a
      // `alignment` verilmişti; Flutter'da alignment'lı Container
      // mümkün olduğunca GENİŞLER. `Wrap` içinde her sayaç tüm satırı
      // kapladı ve dördü ALT ALTA dizildi (kullanıcı bildirdi).
      // `widthFactor: 1` çocuk genişliğinde kalır, yalnız dikeyde ortalar.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: enAzHedef),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Center(
            widthFactor: 1,
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
                    style: TextStyle(color: DiziRenkler.metin),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Profil sayacı: YUVARLAK madalyon + ALTINDA etiket (kullanıcı isteği,
/// 15 Ağu 2026). Öncesi: köşeleri yuvarlatılmış dikdörtgen kutu, İÇİNDE sarı
/// sayı ve etiket.
///
/// RENK KARARLARI:
/// * Madalyon zemini `koyuGri` — `kart`tan BİR TIK daha koyu (koyu temada
///   #17171A vs #1F1F23; açık temada #ECECEF vs beyaz). İki temada da "bir tık
///   daha koyu" anlamını korur.
/// * Sayı MARKA SARISI. Kısa bir beyaz denemesinden sonra kullanıcı sarıya
///   dönülmesini istedi (16 Ağu 2026): "beyazı beğenmedim, aynı stil kalsın,
///   bizim sarımıza dön". Yani rahatsız eden şey sarının kendisi değil, ESKİ
///   DÜZENDİ (dikdörtgen kutu + içeride etiket).
///
///   KOYU temada `sariMetin` (#F5C518) doğrudan kullanılır.
///   AÇIK temada KULLANILAMAZ: `sariMetin`in açık karşılığı #8A6D00 ve bu,
///   bir tık koyulaştırılmış madalyon zemininde (#ECECEF) yalnız **4,17:1**
///   veriyor — eşiğin altında (ölçüldü, test yakaladı). Eskiden zemin BEYAZDI,
///   o yüzden sorun görünmüyordu; "bir tık daha koyu" isteği sınırı deldi.
///   Bu yüzden açık temada bir tık koyu altın (#7A6000, 5,09:1) kullanılır.
///   Not: FittedBox beş haneli sayıyı küçültebildiği için "büyük yazı"
///   istisnasına (3:1) GÜVENİLMEDİ — küçülünce o istisna düşerdi.
/// * Etiket (dairenin ALTI) `DiziRenkler.metin`. 16 Ağu 2026: kullanıcı
///   madalyon altındaki gri yazıları da beyaz istedi.
///
/// ÖLÇÜ: madalyon çapı hücre genişliğinden türetilir, [_enAzCap] altına
/// düşmez (44 dp dokunma hedefi + görsel denge) ve [_enCokCap] üstüne çıkmaz
/// (masaüstünde dev daireler oluşurdu). Dokunma hedefi madalyon DEĞİL, tüm
/// sütun (madalyon + etiket) — yani her zaman 44 dp'nin üstünde.
///
/// **21 AĞU 2026'DAN BERİ EKRANDA ÇİZİLMİYOR.** Kullanıcı bölüm/film/dizi/
/// yorum bloğunun açık profildeki gibi ([ProfilOlcumSatiri]) görünmesini
/// istedi. Sınıf, renk/kontrast kararlarıyla birlikte (ve onları kilitleyen
/// `profil_stat_madalyon_test.dart` ile) DURUYOR: karar geri alınırsa
/// yeniden bağlanacak tek yer burasıdır.
class StatMadalyon extends StatelessWidget {
  final String deger;
  final String etiket;
  final double genislik;
  final VoidCallback? onTap;

  static const double _enAzCap = 56;
  static const double _enCokCap = 88;

  /// Açık temada madalyon zemininde okunan altın (bkz. sınıf yorumu).
  static const _acikTemaAltin = Color(0xFF7A6000);

  /// Madalyon içindeki sayının rengi.
  static Color get sayiRengi =>
      DiziRenkler.acik ? _acikTemaAltin : DiziRenkler.sariMetin;

  const StatMadalyon({
    super.key,
    required this.deger,
    required this.etiket,
    required this.genislik,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cap = genislik.clamp(_enAzCap, _enCokCap).toDouble();
    return SizedBox(
      // Hücre, daireden DAR olamaz: olsaydı dış SizedBox daireyi ezer ve
      // `_enAzCap` garantisi kâğıt üstünde kalırdı (test bunu yakaladı).
      // Çok dar ekranda Wrap satır başına daha az madalyon alır — doğru
      // duyarlı davranış budur.
      width: cap > genislik ? cap : genislik,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: cap,
              height: cap,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: DiziRenkler.koyuGri,
                shape: BoxShape.circle,
                border: Border.all(color: DiziRenkler.metin12),
              ),
              // FittedBox: 14.478 gibi beş haneli sayı dairede taşmasın —
              // kırpmak yerine küçülür (ellipsis sayıyı YANLIŞ gösterirdi).
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  deger,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: sayiRengi,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Etiket madalyonun ALTINDA. 45 dilde uzunluk değişiyor
            // (tr "Bölüm", pl "Odcinki", de "Folgen") → iki satıra izin var.
            Text(
              etiket,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: DiziRenkler.metin),
            ),
          ],
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
                        const Icon(Icons.chevron_right, color: Colors.white),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '{} içerik · otomatik'.cf([widget.ogeler.length]),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
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
                    color: DiziRenkler.metin,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    alt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: DiziRenkler.metin),
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

// ===========================================================================
// EKRAN SÜRESİ KIRILIMI (21 Ağu 2026 isteği)
// ===========================================================================
// KULLANICI İSTEĞİ (birebir): "Profildeki Toplam izleme süresine tıklayınca
// onu uzat: Diziler: / Filmler: olarak süreleri ver. Dizilere tıklarsa
// detaylıca hangi diziyi kaç saat izlediğini söyle, filmlere tıklarsa
// detaylıca hangi filmi kaç saat izlediğini söyle."
//
// *** SÜRE ARTIK ÇOĞUNLUKLA GERÇEK (21 Ağu 2026). *** Sunucu bölüm/film
// süresini TMDB'den bir kez türetip `yapim_sureleri` tablosuna yazıyor
// (backend/sure_doldur.js, migrasyon-2026-08-21e.sql). Sabitler (bölüm 42,
// film 110) KALDIRILMADI ama artık YEDEK: yalnız süresi bilinmeyen satırlar
// oraya düşüyor (ölçülen kapsam %92,6).
//
// EKRANIN İŞİ: sayıyı gizlemek değil, KAYNAĞINI SÖYLEMEK. Sunucu her yanıtta
// `sure_gercek_dk` + `sure_tahmini_dk` gönderiyor (toplamları tam olarak
// gösterilen sayı) ve ekran üç hâlden birini yazıyor:
//   · hepsi gerçek  → "~" YOK, "gerçek süreler" notu
//   · karışık       → "~" VAR, "%93'ü gerçek" notu
//   · hiç gerçek yok→ "~" VAR, eski sabit notu (süre tablosu henüz boş)
// Eski hâlde her sayının başında koşulsuz "~" vardı; gerçek süreyi bildiğimiz
// hâlde tahmin gibi sunmak da en az tersi kadar yanlış olurdu.
//
// Sayıların başındaki yaklaşıklık işareti. Sözcük değil simge olduğu için
// çeviri gerektirmez (`ProfilSayaclari.eksik` ile aynı gerekçe).
const String _yaklasik = '~';

/// Bir süre sayısının KAYNAK KARIŞIMI: kaç dakikası TMDB'nin gerçek
/// süresinden, kaç dakikası sabit yedeğinden geliyor.
///
/// SUNUCUDAN OKUNUR, İSTEMCİDE TÜRETİLMEZ: yüzdeyi burada yeniden hesaplamak
/// (ör. "yapımların kaçında süre var") sunucunun DAKİKA üzerinden yaptığı
/// hesapla ayrışırdı — 8 bölümlük süresiz bir dizi ile 236 bölümlük Friends
/// yapım sayısında eşit, dakikada değil.
///
/// Alanlar YOKSA `oku` `null` döner: eski sunucu ya da bayat önbellek kopyası
/// demektir ve ekran o zaman ESKİ davranışa (koşulsuz "~") düşer. 0 yazmak
/// "hiçbiri gerçek değil" iddiası olurdu.
class SureKaynagi {
  final int gercek;
  final int tahmini;

  const SureKaynagi(this.gercek, this.tahmini);

  static SureKaynagi? oku(
    Map<String, dynamic>? m,
    String gercekAd,
    String tahminiAd,
  ) {
    if (m == null) return null;
    final g = (m[gercekAd] as num?)?.toInt();
    final t = (m[tahminiAd] as num?)?.toInt();
    if (g == null || t == null) return null;
    return SureKaynagi(g < 0 ? 0 : g, t < 0 ? 0 : t);
  }

  int get toplam => gercek + tahmini;

  /// Hiç izleme yoksa (0 dakika) "hepsi gerçek" DEĞİLDİR — 0'ı kesin bir
  /// ölçüm gibi sunmanın anlamı yok, ama kart zaten görünmüyor.
  bool get hepsiGercek => tahmini == 0 && gercek > 0;

  bool get hicGercekYok => gercek == 0;

  /// Gerçek sürenin yüzdesi — AŞAĞI yuvarlanır. Yukarı yuvarlansaydı %99,6
  /// "%100 gerçek" diye yazılır ve ekran olmayan bir kesinlik iddia ederdi.
  int get yuzde => toplam <= 0 ? 0 : (gercek * 100) ~/ toplam;

  /// Sayının önüne konacak işaret: hepsi gerçekse BOŞ.
  String get isaret => hepsiGercek ? '' : _yaklasik;
}

/// "Bağlantı koptu — Yenile" şeridi: profil TAZELENEMEDİĞİNDE listenin en
/// üstünde durur.
///
/// NEDEN AYRI BİR ŞERİT, NEDEN SnackBar DEĞİL: SnackBar 4 saniyede kaybolur;
/// bayat veri ekranda KALIR. Kullanıcı iki dakika sonra baktığında ekranın
/// eski olduğunu gösteren hiçbir iz kalmazdı — 21 Ağu 2026'da tam olarak bu
/// oldu: `/izlediklerim` zaman aşımına düştü, profil önbellekten çizildi,
/// "Toplam İzleme Süresi" kartı (kırılım alanları o bayat kopyada yok diye)
/// açılmaz hâlde kaldı ve hiçbir şey sebebini söylemedi.
///
/// Metinler MEVCUT anahtarlar (`Bağlantı koptu`, `Yenile`) — 45 dilde var.
class ProfilTazelemeSeridi extends StatelessWidget {
  final Future<void> Function() onYenile;

  const ProfilTazelemeSeridi({super.key, required this.onYenile});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.redAccent.withValues(alpha: 0.14),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 17, color: Colors.redAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Bağlantı koptu'.c,
              style: TextStyle(fontSize: 12.5, color: DiziRenkler.metin),
            ),
          ),
          TextButton(
            onPressed: onYenile,
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
              // Dokunma hedefi ≥44 dp (skill md. 2).
              minimumSize: const Size(64, TakipSayac.enAzHedef),
            ),
            child: Text('Yenile'.c),
          ),
        ],
      ),
    ),
  );
}

/// Toplam ekran süresi kartı: dokununca Diziler/Filmler kırılımına açılır,
/// oradan da yapım başına listeye ([SureDetaySheet]) gider.
///
/// [diziDakika] ya da [filmDakika] null ise kart AÇILMAZ (ok da çizilmez):
/// sunucu kırılımı göndermiyor demektir (eski sürüm). Eksik veriyi 0 diye
/// göstermek "hiç dizi izlememişsin" yalanı olurdu — `ProfilSayaclari`nın
/// "eksik anahtar 0 basmaz" kuralının aynısı.
class EkranSuresiKarti extends StatefulWidget {
  final int dakika;
  final int? diziDakika;
  final int? filmDakika;

  /// Notta yazılan sabitler SUNUCUDAN gelir; istemci kendi kopyasını
  /// tutsaydı sabit değişince ekran yalan söylerdi.
  final int? bolumBirimDk;
  final int? filmBirimDk;

  /// Kaynak karışımı (gerçek/tahmini dakika). `null` = eski sunucu → ekran
  /// koşulsuz "~" gösterir (eski davranış).
  final SureKaynagi? kaynak;

  /// Tür başına TAHMİNİ dakika — "Diziler"/"Filmler" satırlarının kendi "~"
  /// işareti için. `null` = eski sunucu → satır "~" gösterir.
  final int? diziTahmini;
  final int? filmTahmini;

  /// 'tv' | 'movie' — yapım başına listeyi açar.
  final void Function(String tur) onTur;

  const EkranSuresiKarti({
    super.key,
    required this.dakika,
    required this.onTur,
    this.diziDakika,
    this.filmDakika,
    this.bolumBirimDk,
    this.filmBirimDk,
    this.kaynak,
    this.diziTahmini,
    this.filmTahmini,
  });

  @override
  State<EkranSuresiKarti> createState() => _EkranSuresiKartiState();
}

class _EkranSuresiKartiState extends State<EkranSuresiKarti> {
  bool _acik = false;

  /// SIFIR GEÇERLİ BİR DEĞERDİR, EKSİK DEĞİL (21 Ağu 2026 kararı).
  ///
  /// Hiç film izlememiş bir kullanıcıda `tahmini_dakika_film` sunucudan `0`
  /// gelir — `null` DEĞİL (`izlemeKirilimi` sayacı 0'dan başlatır). "62 bölüm
  /// izledim ama kırılımı göremiyorum" olmaz: dizi kırılımı o hesapta tam
  /// anlamlıdır ve "Filmler 0 dakika" DOĞRU bir cümledir. Kartı yalnız
  /// alanın YOKLUĞU (eski sunucu / eski önbellek kopyası) kapatır.
  bool get _acilabilir =>
      widget.diziDakika != null && widget.filmDakika != null;

  /// Kırılımın altındaki kaynak notu. ÜÇ HÂL — hangisi yazılırsa yazılsın
  /// GÖSTERİLEN SAYI DEĞİŞMEZ; değişen tek şey sayının nereden geldiğini
  /// söylemek.
  String _kaynakNotu() {
    final k = widget.kaynak;
    // Eski sunucu / bayat önbellek: kaynak bilinmiyor → eski cümle. (Bu
    // cümle 45 dilde ZATEN var, yeni anahtar değil.)
    if (k == null || k.hicGercekYok) {
      return 'Süreler tahmindir: bölüm ~{} dk, film ~{} dk sayılır'.cf([
        widget.bolumBirimDk,
        widget.filmBirimDk,
      ]);
    }
    if (k.hepsiGercek) {
      return 'Süreler TMDB\'deki gerçek bölüm ve film süreleridir'.c;
    }
    // KARIŞIK: yüzde AŞAĞI yuvarlanır ve hangi sabite düşüldüğü de yazar —
    // "%93'ü gerçek" tek başına, kalan %7'nin ne olduğunu söylemez.
    return 'Sürelerin %{} kadarı gerçek; kalanı bölüm ~{} dk, film ~{} dk sayılıyor'
        .cf([k.yuzde, widget.bolumBirimDk, widget.filmBirimDk]);
  }

  @override
  Widget build(BuildContext context) {
    final baslik = Row(
      children: [
        Icon(Icons.schedule, color: DiziRenkler.sariMetin, size: 22),
        const SizedBox(width: 12),
        // Expanded: pl "Łączny czas przed ekranem" (25 harf)
        // Spacer'lı halde 360 dp altında satırı taşırıyordu.
        Expanded(
          child: Text(
            'Toplam İzleme Süresi'.c,
            style: TextStyle(color: DiziRenkler.metin, fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          // İŞARET KAYNAĞA BAĞLI: hepsi gerçekse "~" YOK. Kaynak alanı hiç
          // gelmediyse (eski sunucu) eski davranış — koşulsuz "~".
          '${widget.kaynak?.isaret ?? _yaklasik}${sureBicimle(widget.dakika)}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: DiziRenkler.sariMetin,
          ),
        ),
        if (_acilabilir)
          Icon(
            _acik ? Icons.expand_less : Icons.expand_more,
            size: 20,
            color: DiziRenkler.metin54,
          ),
      ],
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: DiziRenkler.kart,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DiziRenkler.metin12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            // Kapalıyken tüm kart yuvarlak; açıkken yalnız ÜST köşeler —
            // yoksa dalga efekti alt satırların üstüne taşıyor.
            borderRadius: _acik
                ? const BorderRadius.vertical(top: Radius.circular(14))
                : BorderRadius.circular(14),
            onTap: _acilabilir ? () => setState(() => _acik = !_acik) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: baslik,
            ),
          ),
          if (_acik && _acilabilir) ...[
            Divider(height: 1, color: DiziRenkler.metin12),
            _SureTurSatiri(
              ikon: Icons.tv_outlined,
              etiket: 'Diziler'.c,
              dakika: widget.diziDakika!,
              // Satırın kendi "~"si: filmler tam gerçekken dizilerdeki eksik
              // yüzünden film satırına da işaret koymak yanlış uyarı olurdu.
              yaklasik: widget.diziTahmini == null
                  ? true
                  : widget.diziTahmini! > 0,
              onTap: () => widget.onTur('tv'),
            ),
            _SureTurSatiri(
              ikon: Icons.movie_outlined,
              etiket: 'Filmler'.c,
              dakika: widget.filmDakika!,
              yaklasik: widget.filmTahmini == null
                  ? true
                  : widget.filmTahmini! > 0,
              onTap: () => widget.onTur('movie'),
            ),
            // KAYNAK BURADA YAZIYOR — ÜÇ HÂL (bkz. dosya başındaki not):
            //   hepsi gerçek → sabitten hiç söz edilmez, "~" da yok
            //   karışık      → yüzde + hangi sabite düşüldüğü
            //   hiç yok      → eski cümle (süre tablosu henüz boş)
            // Sabitler sunucudan gelmediyse (eski sürüm) not HİÇ çizilmez —
            // uydurma sayı yazmaktansa susmak doğru (bkz. sınıf yorumu).
            if (widget.bolumBirimDk != null && widget.filmBirimDk != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                child: Text(
                  _kaynakNotu(),
                  style: TextStyle(fontSize: 11, color: DiziRenkler.metin54),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Kırılımın tek satırı: "Diziler … ~3 ay 4 gün ›".
class _SureTurSatiri extends StatelessWidget {
  final IconData ikon;
  final String etiket;
  final int dakika;

  /// Bu satırın sayısı tahmini içeriyor mu? Tür başına ayrı: filmlerin süre
  /// kapsamı (%96,6) dizilerinkinden (%92,6) yüksek.
  final bool yaklasik;
  final VoidCallback onTap;

  const _SureTurSatiri({
    required this.ikon,
    required this.etiket,
    required this.dakika,
    required this.yaklasik,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      // Dokunma hedefi ≥44 dp (skill md. 2). `alignment` VERİLMEDİ:
      // 21 Ağu 2026 gerilemesi tam olarak oydu (bkz. [TakipSayac]).
      constraints: const BoxConstraints(minHeight: TakipSayac.enAzHedef),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          Icon(ikon, size: 18, color: DiziRenkler.metin54),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              etiket,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: DiziRenkler.metin, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${yaklasik ? _yaklasik : ''}${sureBicimle(dakika)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: DiziRenkler.sariMetin,
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: DiziRenkler.metin38),
        ],
      ),
    ),
  );
}

/// "Hangi diziyi/filmi kaç saat izledim" listesi.
///
/// SAYFALAMA: sunucu 50'şer veriyor (`alcelik` 406 film + 237 dizi izlemiş).
/// "Daha fazla" düğmesi yalnız gerçekten devamı varken çıkar — `toplam`
/// her yanıtta dönüyor.
///
/// İÇERİK ADI/POSTERİ İSTEMCİDE ÇÖZÜLÜR ([IcerikDeposu]): süre ucu yalnız
/// kimlik + sayı döner. Sunucunun her satır için TMDB belgesini açması
/// gerekseydi (ölçüm: film detayı 191-342 KB) 50 satırlık bir sayfa on
/// megabaytlarca jsonb detoast ederdi.
class SureDetaySheet extends StatefulWidget {
  final String tur;
  const SureDetaySheet({super.key, required this.tur});

  @override
  State<SureDetaySheet> createState() => _SureDetaySheetState();
}

class _SureDetaySheetState extends State<SureDetaySheet> {
  final List<dynamic> _ogeler = [];
  int _sayfa = 0;
  int _toplam = 0;
  bool _yukleniyor = true;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final d = await Api.get(
        '/istatistiklerim/sure?tur=${widget.tur}&sayfa=$_sayfa',
      );
      if (!mounted) return;
      setState(() {
        _ogeler.addAll(d['ogeler'] as List<dynamic>? ?? const []);
        _toplam = (d['toplam'] as num?)?.toInt() ?? _ogeler.length;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Hata SESSİZ DEĞİL: kullanıcı mesajı görür ve tekrar deneyebilir.
      setState(() {
        _hata = e.toString();
        _yukleniyor = false;
      });
    }
  }

  void _dahaFazla() {
    _sayfa++;
    _yukle();
  }

  @override
  Widget build(BuildContext context) {
    final dizi = widget.tur == 'tv';
    Widget govde;
    if (_hata != null && _ogeler.isEmpty) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_yukleniyor && _ogeler.isEmpty) {
      govde = const Center(
        child: CircularProgressIndicator(color: DiziRenkler.sari),
      );
    } else if (_ogeler.isEmpty) {
      govde = BosDurum(
        ikon: dizi ? Icons.tv_outlined : Icons.movie_outlined,
        baslik: 'Henüz izleme kaydın yok'.c,
        ipucu: 'İzlediğin dizi ve filmleri işaretledikçe burada toplanır.'.c,
      );
    } else {
      govde = ListView.builder(
        padding: EdgeInsets.fromLTRB(
          14,
          0,
          14,
          altGuvenli(context, ekstra: 20),
        ),
        itemCount: _ogeler.length + 1,
        itemBuilder: (context, i) {
          if (i == _ogeler.length) {
            if (_ogeler.length >= _toplam) return const SizedBox(height: 8);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: _yukleniyor
                    ? const CircularProgressIndicator(color: DiziRenkler.sari)
                    : TextButton(
                        onPressed: _dahaFazla,
                        child: Text('Daha fazla'.c),
                      ),
              ),
            );
          }
          final o = _ogeler[i] as Map<String, dynamic>;
          return SureYapimSatiri(
            key: ValueKey('${o['tur']}-${o['tmdb_id']}'),
            tur: o['tur'] as String,
            tmdbId: (o['tmdb_id'] as num).toInt(),
            adet: (o['adet'] as num?)?.toInt() ?? 0,
            tekrar: (o['tekrar'] as num?)?.toInt() ?? 0,
            dakika: (o['dakika'] as num?)?.toInt() ?? 0,
            eksik: (o['eksik'] as num?)?.toInt(),
          );
        },
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
                Icon(
                  dizi ? Icons.tv_outlined : Icons.movie_outlined,
                  color: DiziRenkler.sariMetin,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (dizi
                            ? 'En çok izlediğin diziler'
                            : 'En çok izlediğin filmler')
                        .c,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_toplam > 0)
                  Text(
                    '$_toplam',
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

/// Yapım başına tek satır: poster + ad + "128 bölüm · 2 kez" + ~süre.
///
/// Adı ve posteri [IcerikDeposu] çözer (toplu `POST /icerikler`); gelmezse
/// satır `#kimlik` yazar ama SÜREYİ yine gösterir — süre TMDB'ye bağlı
/// değil, bizim izleme kayıtlarımızdan çıkıyor.
class SureYapimSatiri extends StatefulWidget {
  final String tur;
  final int tmdbId;
  final int adet;
  final int tekrar;
  final int dakika;

  /// Süresi BİLİNMEYEN bölüm/film sayısı (sunucudan `eksik`). SATIR DÜZEYİNDE
  /// dürüstlük: toplamda %93 gerçek olsa bile TEK BİR yapımın tamamı tahmini
  /// olabilir (ör. daha sezon belgesi önbelleğe girmemiş yeni dizi). Satır
  /// üstteki yüzdeye bakıp genelleme yapmaz, kendi durumunu söyler.
  /// `null` = eski sunucu → satır "~" gösterir (eski davranış).
  final int? eksik;

  const SureYapimSatiri({
    super.key,
    required this.tur,
    required this.tmdbId,
    required this.adet,
    required this.tekrar,
    required this.dakika,
    this.eksik,
  });

  @override
  State<SureYapimSatiri> createState() => _SureYapimSatiriState();
}

class _SureYapimSatiriState extends State<SureYapimSatiri> {
  Map<String, dynamic>? _icerik;

  @override
  void initState() {
    super.initState();
    IcerikDeposu.getir(widget.tur, widget.tmdbId).then((d) {
      if (mounted && d != null) setState(() => _icerik = d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final poster = posterUrl(_icerik?['poster_path'] as String?, boyut: 'w185');
    final ad = (_icerik?['name'] ?? _icerik?['title'] ?? '') as String;
    // Tekrar izleme süreyi katladığı için ALTBAŞLIKTA görünür: yoksa
    // "12 bölüm" yazan bir satırın niye iki katı süre gösterdiği anlaşılmaz.
    final alt = [
      widget.tur == 'tv'
          ? '{} bölüm'.cs(widget.adet)
          : '{} kez'.cs(widget.adet),
      if (widget.tekrar > 0) '{} kez'.cs(widget.tekrar + 1),
    ].join(' · ');
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => context.push('/icerik/${widget.tur}/${widget.tmdbId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 36,
                height: 54,
                child: poster == null
                    ? ColoredBox(color: DiziRenkler.kart)
                    : CachedNetworkImage(
                        imageUrl: poster,
                        httpHeaders: gorselBasliklari(poster),
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) =>
                            ColoredBox(color: DiziRenkler.kart),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ad.isEmpty ? '#${widget.tmdbId}' : ad,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: DiziRenkler.metin,
                    ),
                  ),
                  Text(
                    alt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: DiziRenkler.metin54),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              // "~" YALNIZ bu satırda tahmin varsa.
              '${(widget.eksik ?? 1) > 0 ? _yaklasik : ''}'
              '${sureBicimle(widget.dakika)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: DiziRenkler.sariMetin,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
