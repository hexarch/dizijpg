import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../gorsel_basliklari.dart';
import '../kitaplik_durumu.dart';
import '../ceviri.dart';
import '../puan.dart';
import '../tema.dart';
import 'giris_istem.dart';
import 'medya_goster.dart';
import 'ortak.dart';
import 'puan_dagilimi.dart';
import 'puan_sheet.dart';
import 'sirket.dart';
import 'tepki.dart';
import 'yorumlar.dart';

const durumSecenekleri = [
  ('izleyecegim', 'İzleyeceğim', Icons.bookmark_add_outlined),
  ('izliyorum', 'İzliyorum', Icons.play_circle_outline),
  ('bitirdim', 'Bitirdim', Icons.check_circle_outline),
  ('biraktim', 'Bıraktım', Icons.cancel_outlined),
];

/// TEKİLLİK KURALI — "ya izleyecektir ya izlemiştir" (kullanıcı, 14 Ağu 2026).
///
/// İzleme kaydı varken "İzleyeceğim" seçilirse sunucu 409 + `IZLEME_KAYDI_VAR`
/// döner ve isteği REDDEDER. Kuralı SUNUCU koyar (eski sürümler ve doğrudan
/// API çağrıları da tutarlı kalsın diye); burada yalnız ONAY toplanır.
///
/// VERİ KAYBI SESSİZ OLAMAZ: dizide bu, onlarca bölümlük geçmiş demektir.
/// Bu yüzden silinecek KAYIT SAYISI metne yazılır ve onay düğmesi kırmızıdır
/// (`_sifirla`daki "Sil" ile aynı dil).
///
/// Dönüş: `true` = onaylandı, aksi hâlde vazgeçildi.
Future<bool?> izlemeSilmeOnayi(
  BuildContext context, {
  required String tur,
  required int adet,
}) => showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    backgroundColor: DiziRenkler.koyuGri,
    title: Text('İzleyeceklerine taşınsın mı?'.c),
    content: Text(
      tur == 'tv'
          ? 'Bir içerik ya izlenecektir ya izlenmiştir. Devam edersen bu dizideki {} izleme işaretin silinecek.'
                .cf([adet])
          : 'Bir içerik ya izlenecektir ya izlenmiştir. Devam edersen bu filmdeki "izledim" işaretin kaldırılacak.'
                .c,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text('İptal'.c),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
        ),
        onPressed: () => Navigator.pop(context, true),
        child: Text('Sil ve taşı'.c),
      ),
    ],
  ),
);

/// Detay başlığındaki kapak yolları: ANA kapak (backdrop_path) HER ZAMAN ilk
/// sırada, ardından TMDB'nin arka plan görselleri en çok oy alandan başlayarak.
/// Aynı yol iki kez girmez; en fazla [kapakTavani] tane.
///
/// Yalnız `backdrops` kullanılır, `posters` katılmaz: başlık geniş (16:9) bir
/// şerittir, 2:3 afişler orada ya kırpılıp tanınmaz olur ya da yanlarda kalın
/// siyah bantla durur. Afiş zaten arama/kitaplık kartlarında görünüyor.
///
/// TMDB'de 3'ten az görseli olan yapımlar var; görsel uyduramayız — kaç tane
/// varsa o gösterilir, tek görselde başlık eskisi gibi sabit kalır.
const kapakTavani = 10;

List<String> kapaklariCikar(Map<String, dynamic> icerik) {
  final yollar = <String>[];
  final ana = icerik['backdrop_path'] as String?;
  if (ana != null && ana.isNotEmpty) yollar.add(ana);
  final ham = icerik['images'];
  // Tip denetimi gevşek: TMDB alanı hiç göndermeyebilir, eski önbellekten
  // gelen yanıtta bulunmayabilir — kapak galerisi süs veridir, sayfayı
  // düşürmesin.
  final gelen = ham is Map ? ham['backdrops'] : null;
  final arkalar =
      <Map<String, dynamic>>[
        for (final g in gelen is List ? gelen : const [])
          if (g is Map<String, dynamic>) g,
      ]..sort(
        (a, b) => ((b['vote_count'] as num?) ?? 0).compareTo(
          (a['vote_count'] as num?) ?? 0,
        ),
      );
  for (final g in arkalar) {
    if (yollar.length >= kapakTavani) break;
    final y = g['file_path'] as String?;
    if (y != null && y.isNotEmpty && !yollar.contains(y)) yollar.add(y);
  }
  return yollar;
}

/// ---------------------------------------------------------------------------
/// EKİP (madde 49): yönetmen / senarist / yapımcı — TIKLANABİLİR, `/kisi/:id`.
///
/// KAYNAK İKİ AYRI ALAN:
///  * `credits.crew` — `append_to_response=credits` ile ana yanıtla gelir
///    (ek istek YOK). Her satırda `job` alanı vardır.
///  * `created_by` — DİZİLERDE gövdenin kendi alanı. ZORUNLU: TMDB'de dizi
///    kredisi BÖLÜM bazlıdır; dizi düzeyindeki `crew` listesinde çoğu zaman
///    HİÇ "Director"/"Writer" yoktur (canlı ölçüm 13 Ağu 2026 — Breaking Bad
///    /tv/1396: 27 kişilik ekipte tek bir Director/Writer satırı yok, ama
///    `created_by` Vince Gilligan'ı veriyor). `created_by` olmasaydı dizilerde
///    bölüm ekrandaki en önemli ismi kaçırırdı.
///
/// TMDB `job` değerleri İNGİLİZCE ve dile göre değişmez (department/job
/// sözlüğü çevrilmez) — bu yüzden eşleştirme sabit metinlerle güvenli.
const ekipRolleri = <(String, List<String>)>[
  // Sıra = ekrandaki öncelik sırası. Bir kişi birden çok rolde geçerse kartı
  // İLK (en yüksek öncelikli) rolünün yerinde durur.
  ('Yaratıcı', <String>[]), // yalnız `created_by`
  ('Yönetmen', ['Director']),
  // "Screenplay" ve "Writer" TMDB'de aynı işin iki adı; "Story" konuyu yazan,
  // "Teleplay" dizi bölümünün senaryosu. Dördü de kullanıcı için "senarist".
  // "Novel"/"Author" KASITLA DIŞARIDA: uyarlanan kitabın yazarı senarist değil.
  ('Senaryo', ['Screenplay', 'Writer', 'Story', 'Teleplay']),
  // TMDB'de bir düzine yapımcı türevi var (Co-Executive, Associate, Line,
  // Coordinating...). Yalnız iki ANA unvan alınır; gerisi jenerik gürültüsü.
  ('Yapımcı', ['Producer', 'Executive Producer']),
];

/// Her rolün şeride koyabileceği EN FAZLA kişi.
///
/// NEDEN TAVAN VAR: yapım ekibi listeleri uçsuz. Canlı ölçüm (13 Ağu 2026):
/// Inception (/movie/27205) 736 kişilik ekip, bunun 4'ü "Producer" + 3'ü
/// "Executive Producer". Tavansız bırakılsaydı bölüm bir jenerik dökümüne
/// dönerdi ve asıl bilgi (yönetmen/senarist) yapımcı kalabalığında kaybolurdu.
///
/// Sayıların gerekçesi:
///  * Yaratıcı 4 — `created_by` neredeyse hiç 2-3'ü geçmez (Game of Thrones 2).
///  * Yönetmen 3 — filmde tipik olarak 1, kardeş/ikili yönetmenlerde 2;
///    3 kolektifleri de karşılar.
///  * Senaryo 4 — Screenplay + Writer + Story çoğu zaman AYNI 2-3 kişidir.
///  * Yapımcı 4 — bu bölümün "şişme" riski buradan gelir, en sıkı tavan burada.
///
/// Üst sınır 15 kart; yatay şeritte ~3 ekran genişliği, kaydırılabilir.
const ekipRolTavani = <String, int>{
  'Yaratıcı': 4,
  'Yönetmen': 3,
  'Senaryo': 4,
  'Yapımcı': 4,
};

/// Şeritteki tek ekip üyesi: kişi + o yapımda üstlendiği İŞLER.
class EkipUyesi {
  final int id;
  final String ad;
  final String? foto;

  /// Türkçe rol anahtarları ("Senaryo", "Yapımcı"). Ekranda `.c` ile çevrilip
  /// virgülle birleştirilir — aynı kişi iki kez listelenmez.
  final List<String> isler;

  EkipUyesi({
    required this.id,
    required this.ad,
    required this.foto,
    required this.isler,
  });
}

/// Detay yanıtından ekip şeridini üretir. TEKİLLEŞTİRİR: bir kişi hem
/// "Writer" hem "Producer" ise TEK kart alır, işleri birleşir ("Senaryo,
/// Yapımcı").
///
/// TAVAN MUHASEBESİ: zaten kartı olan kişi bir sonraki rolün tavanını
/// HARCAMAZ — yalnız etiketine o rol eklenir. Aksi hâlde senaryoyu da yazan
/// yapımcılar, kendilerinden başka yapımcı gösterilmesini engellerdi.
///
/// Alanlar EKSİK gelirse (TMDB'de `credits` ya da `created_by` olmayabilir,
/// eski önbellek yanıtında bulunmayabilir) boş liste döner → bölüm HİÇ
/// çizilmez, hata/boş kutu görünmez.
List<EkipUyesi> ekibiCikar(Map<String, dynamic> icerik) {
  final ham = icerik['credits'];
  final ekipHam = ham is Map ? ham['crew'] : null;
  final ekip = <Map<String, dynamic>>[
    for (final e in ekipHam is List ? ekipHam : const [])
      if (e is Map<String, dynamic>) e,
  ];
  final yaratanHam = icerik['created_by'];
  final yaratanlar = <Map<String, dynamic>>[
    for (final k in yaratanHam is List ? yaratanHam : const [])
      if (k is Map<String, dynamic>) k,
  ];

  // LinkedHashMap: ekleme sırası korunur → ekrandaki sıra rol önceliğidir.
  final sonuc = <int, EkipUyesi>{};
  for (final (rol, isler) in ekipRolleri) {
    final adaylar = isler.isEmpty
        ? yaratanlar
        : [
            for (final e in ekip)
              if (isler.contains(e['job'])) e,
          ];
    var eklenen = 0;
    for (final k in adaylar) {
      final id = (k['id'] as num?)?.toInt();
      final ad = (k['name'] as String?)?.trim();
      if (id == null || ad == null || ad.isEmpty) continue;
      final varOlan = sonuc[id];
      if (varOlan != null) {
        if (!varOlan.isler.contains(rol)) varOlan.isler.add(rol);
        continue; // tavanı harcamaz
      }
      if (eklenen >= (ekipRolTavani[rol] ?? 0)) continue;
      sonuc[id] = EkipUyesi(
        id: id,
        ad: ad,
        foto: k['profile_path'] as String?,
        isler: [rol],
      );
      eklenen++;
    }
  }
  return sonuc.values.toList();
}

/// Yapım firması şeridinde gösterilecek en fazla firma. TMDB'de tek filme
/// 20'den fazla ortak yapımcı iliştirilmiş örnekler var; şerit bir firma
/// rehberine dönüşmesin.
const firmaTavani = 10;

/// `production_companies` → tıklanabilir firma kayıtları.
///
/// SÜZGEÇ: `id` ve `name` OLMAYAN kayıt atılır — tıklanınca gidilecek bir
/// sayfası (ya da yazılacak bir adı) yoksa kartın anlamı yok. Aynı id iki kez
/// gelirse bir kez gösterilir.
List<Map<String, dynamic>> yapimFirmalari(Map<String, dynamic> icerik) {
  final ham = icerik['production_companies'];
  final sonuc = <int, Map<String, dynamic>>{};
  for (final f in ham is List ? ham : const []) {
    if (f is! Map<String, dynamic>) continue;
    final id = (f['id'] as num?)?.toInt();
    final ad = (f['name'] as String?)?.trim();
    if (id == null || ad == null || ad.isEmpty) continue;
    if (sonuc.length >= firmaTavani) break;
    sonuc.putIfAbsent(id, () => f);
  }
  return sonuc.values.toList();
}

class DetayEkrani extends StatefulWidget {
  final int tmdbId;
  final String tur; // 'tv' | 'movie'

  const DetayEkrani({super.key, required this.tmdbId, required this.tur});

  @override
  State<DetayEkrani> createState() => _DetayEkraniState();
}

class _DetayEkraniState extends State<DetayEkrani> {
  Map<String, dynamic>? _icerik;
  Map<String, dynamic>? _benim;
  Map<String, dynamic>? _incelemeler;
  Map<String, dynamic>? _izleyenler;

  /// Başlıktaki kapak görselleri; ilki yapımın ANA kapağıdır (backdrop_path).
  List<String> _kapaklar = const [];
  String? _hata;

  /// Detay ucuna eklenen alt kaynaklar. `images` LİSTEYE SONRADAN EKLENDİ:
  /// sunucu bu parametre verilmezse kendi varsayılanını koyar, verilirse
  /// olduğu gibi kullanır — bu yüzden liste sunucudakiyle birebir aynı
  /// olmalı, yoksa kadro/fragman gelmez.
  static const _ekVeri =
      'credits,videos,recommendations,external_ids,watch/providers,images';

  /// Görseller ayrı bir istekle DEĞİL ana veriyle birlikte gelir: sonradan
  /// gelseydi başlık tek kapakla çizilir, kaydırıcı ve sayaç sonradan belirirdi.
  /// `include_image_language=null` = YAZISIZ kapaklar (üstüne dizi adı basılmış
  /// afiş değil); TMDB ana kapağı da bunlardan seçer ve yük ~4 KB artar.
  String get _icerikYolu =>
      '/tmdb/${widget.tur}/${widget.tmdbId}'
      '?append_to_response=$_ekVeri&include_image_language=null';

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      // `/benim/...` girisZorunlu bir uçtur ve oturumsuzda 401 döner. Listeye
      // koşulsuz konsaydı Future.wait tümünü düşürür, aramadan gelen
      // ziyaretçi içerik yerine kırmızı hata ekranı görürdü. Diğer iki uç
      // (tmdb, incelemeler) oturum istemez.
      final sonuclar = await Future.wait([
        Api.get(_icerikYolu),
        Api.get('/incelemeler/${widget.tur}/${widget.tmdbId}'),
        if (Api.girisli) Api.get('/benim/${widget.tur}/${widget.tmdbId}'),
      ]);
      if (!mounted) return;
      setState(() {
        _icerik = sonuclar[0] as Map<String, dynamic>;
        _kapaklar = kapaklariCikar(_icerik!);
        _incelemeler = sonuclar[1] as Map<String, dynamic>;
        _benim = sonuclar.length > 2
            ? sonuclar[2] as Map<String, dynamic>
            : null;
      });
      // İzleyen sayısı sayfayı bloke etmesin: ayrı ve sessizce yüklenir
      Api.get('/izleyenler/${widget.tur}/${widget.tmdbId}')
          .then((d) {
            if (mounted) {
              setState(() => _izleyenler = d as Map<String, dynamic>);
            }
          })
          .catchError((_) {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
    }
  }

  /// Kapakların tam adresleri. w780 idi: 3x yoğunluklu telefonda bu alan ~1290
  /// fiziksel piksel, görsel büyütülüp gözle görülür bulanıklaşıyordu; tam
  /// ekranda daha da belliydi. w1280 tam oturuyor ("original" birkaç MB
  /// olabildiği için tercih edilmedi). Şeritte ve tam ekranda AYNI adres
  /// kullanılır: ikincisi zaten önbellekten gelir, yeniden indirilmez.
  List<String> get kapakUrlleri => [
    for (final y in _kapaklar) posterUrl(y, boyut: 'w1280')!,
  ];

  /// Görselin altını sayfanın zeminine bağlayan karartma.
  Widget get _karartma => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, DiziRenkler.siyah],
      ),
    ),
  );

  Future<void> _benimYenile() async {
    if (!Api.girisli) return; // uç 401 döner; oturumsuzda kişisel veri yok
    try {
      final b = await Api.get('/benim/${widget.tur}/${widget.tmdbId}');
      if (mounted) setState(() => _benim = b as Map<String, dynamic>);
    } catch (_) {}
  }

  /// Mutasyonu çalıştırır; hata olursa SnackBar gösterir.
  /// Oturumsuzda istek HİÇ atılmaz: 401 SnackBar'ı yerine giriş istemi çıkar.
  Future<void> _mutasyon(Future<void> Function() istek) async {
    if (!girisGerekli(context)) return;
    try {
      await istek();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
    _benimYenile();
  }

  /// Durum çipi. "İzleyeceğim"de sunucu izleme kaydı görürse 409 +
  /// `IZLEME_KAYDI_VAR` döner; o zaman onay alınıp istek `izlemeleri_sil: true`
  /// ile BİR KEZ tekrarlanır (bkz. [izlemeSilmeOnayi]).
  ///
  /// ELDEKİ `_benim['izlenenler']` ile ÖN KONTROL YAPILMAZ: sayı sunucudan
  /// gelirse başka cihazda az önce işaretlenen bölümler de doğru sayılır ve
  /// kural tek yerde (sunucuda) yaşar. İstemci burada yalnızca onay toplar.
  Future<void> _durumSec(String? durum) => _mutasyon(() async {
    var izlemeleriSil = false;
    while (true) {
      try {
        await Api.post('/durum', {
          'tmdb_id': widget.tmdbId,
          'tur': widget.tur,
          'durum': durum ?? '',
          if (izlemeleriSil) 'izlemeleri_sil': true,
        });
        break;
      } on ApiHata catch (h) {
        // Onaydan SONRA yine gelirse (olmamalı) SnackBar'a düşsün: sonsuz
        // döngüde kullanıcıya aynı diyaloğu tekrar tekrar sormayız.
        if (h.makineKodu != 'IZLEME_KAYDI_VAR' || izlemeleriSil) rethrow;
        if (!mounted) return;
        final onay = await izlemeSilmeOnayi(
          context,
          tur: widget.tur,
          adet: (h.govde?['izleme_sayisi'] as num?)?.toInt() ?? 0,
        );
        // Vazgeçti: durum DEĞİŞMEZ, izleme kayıtları DURUR, hata da gösterilmez.
        if (onay != true) return;
        izlemeleriSil = true;
      }
    }
    // Poster kartlarındaki "izledin" rozeti anında doğru olsun.
    KitaplikDurumu.isaretle(
      widget.tur,
      widget.tmdbId,
      durum == 'izliyorum' || durum == 'bitirdim' || durum == 'biraktim',
    );
    // Sunucu "izleyeceğim"de `tekrar`ı sıfırlar (bkz. POST /durum); rozetin
    // yanındaki "×2" burada da düşsün, yoksa "izleyeceğim ama 2 kez izledim"
    // çelişkisi poster kartında yaşamaya devam ederdi.
    if (durum == 'izleyecegim') {
      KitaplikDurumu.tekrarAyarla(widget.tur, widget.tmdbId, 0);
    }
  });

  /// Yeniden izleme sayacı (+1 / -1); yalnız "bitirdim" durumunda çalışır.
  Future<void> _rewatch(int deger) => _mutasyon(() async {
    final c = await Api.post('/rewatch', {
      'tmdb_id': widget.tmdbId,
      'tur': widget.tur,
      'deger': deger,
    });
    // Poster kartlarındaki göz rozetinin yanındaki sayı (×2) anında
    // güncellensin — sunucunun döndürdüğü değerle, iyimser tahminle DEĞİL.
    final t = c is Map ? (c['tekrar'] as num?)?.toInt() : null;
    if (t != null) KitaplikDurumu.tekrarAyarla(widget.tur, widget.tmdbId, t);
  });

  /// İzleyenler listesi: avatar + kullanıcı adı, dokununca profile gider.
  void _izleyenlerAc() {
    final liste = (_izleyenler?['kullanicilar'] as List<dynamic>? ?? []);
    if (liste.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DiziRenkler.koyuGri,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.visibility_outlined, color: DiziRenkler.sariMetin),
                  const SizedBox(width: 8),
                  Text(
                    'İzleyenler'.c,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_izleyenler?['sayi'] ?? liste.length}',
                    style: TextStyle(color: DiziRenkler.metin54),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: liste.length,
                itemBuilder: (context, i) {
                  final k = liste[i] as Map<String, dynamic>;
                  final av = dosyaUrl(k['avatar'] as String?);
                  final ad = k['kullanici_adi'] as String;
                  return ListTile(
                    leading: KullaniciAvatari(
                      url: av,
                      kullaniciAdi: ad,
                      arkaplan: DiziRenkler.kart,
                    ),
                    title: Text('@$ad'),
                    onTap: () {
                      // Dış context: kapanan modalın context'i ölür.
                      final dis = this.context;
                      Navigator.pop(context);
                      kullaniciyaGit(dis, ad);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _favoriToggle() => _mutasyon(
    () => Api.post('/favori/toggle', {
      'tmdb_id': widget.tmdbId,
      'tur': widget.tur,
    }),
  );

  /// Film "İzledim" düğmesi. Sunucu izleme kaydını yazar VE durumu
  /// "bitirdim" yapar (bkz. server.js filmDurumunuGuncelle) — poster
  /// kartlarındaki göz rozeti tek kaynaktan, `durumlar`dan okunur.
  /// Rozet cevabı BEKLEDİKTEN sonra güncellenir: istek başarısızsa
  /// (SnackBar) yanlış rozet yanıp sönmez, geri alma da gerekmez.
  Future<void> _filmIzlendiToggle() => _mutasyon(() async {
    final c = await Api.post('/izleme/toggle', {
      'tmdb_id': widget.tmdbId,
      'tur': 'movie',
      'sezon': 0,
      'bolum': 0,
    });
    KitaplikDurumu.isaretle(
      'movie',
      widget.tmdbId,
      (c is Map && c['izlendi'] == true),
    );
  });

  Future<void> _puanla() async {
    if (!girisGerekli(context)) return;
    final kaydedildi = await puanlaVeKaydet(
      context,
      tur: widget.tur,
      tmdbId: widget.tmdbId,
      mevcutPuan: _benim?['puan']?['puan'] as int?,
      mevcutYorum: _benim?['puan']?['yorum'] as String?,
    );
    if (kaydedildi) {
      _benimYenile();
      try {
        final inc = await Api.get(
          '/incelemeler/${widget.tur}/${widget.tmdbId}',
        );
        if (mounted) setState(() => _incelemeler = inc as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  /// Tüm izleme izlerini siler: hiç izlenmemiş sayılır + listelerden kalkar.
  Future<void> _sifirla() async {
    if (!girisGerekli(context)) return;
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DiziRenkler.koyuGri,
        title: Text('Sil'.c),
        content: Text(
          'Bu içerik hiç izlenmemiş olarak işaretlenecek ve listelerinden kaldırılacak.'
              .c,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal'.c),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sil'.c),
          ),
        ],
      ),
    );
    if (onay != true) return;
    try {
      await Api.post('/icerik/sifirla', {
        'tmdb_id': widget.tmdbId,
        'tur': widget.tur,
      });
      if (!mounted) return;
      _yukle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  /// Bu içeriği açık profilden gizler/gösterir (iyimser, hatada geri alınır).
  Future<void> _gizleToggle() async {
    if (!girisGerekli(context)) return;
    final eski = _benim?['gizli'] == true;
    setState(() => _benim?['gizli'] = !eski);
    try {
      await Api.post('/gizle', {
        'tmdb_id': widget.tmdbId,
        'tur': widget.tur,
        'gizli': !eski,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _benim?['gizli'] = eski);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _listeyeEkle() async {
    if (!girisGerekli(context)) return;
    try {
      final d = await Api.get('/listelerim');
      if (!mounted) return;
      final listeler = d['listeler'] as List<dynamic>;
      await showModalBottomSheet(
        context: context,
        backgroundColor: DiziRenkler.koyuGri,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Listeye Ekle'.c,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (listeler.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Henüz listen yok — Profil sekmesinden oluştur.'.c,
                  ),
                ),
              for (final l in listeler)
                ListTile(
                  leading: Icon(
                    Icons.playlist_add,
                    color: DiziRenkler.sariMetin,
                  ),
                  title: Text(l['ad'] as String),
                  subtitle: Text('{} içerik'.cf([l['oge_sayisi']])),
                  onTap: () async {
                    // Messenger'ı pop'tan ÖNCE al: modal kapanınca context ölür,
                    // onunla SnackBar aramak "deactivated widget" hatası verir.
                    final messenger = ScaffoldMessenger.of(context);
                    final sayfa = Navigator.of(context);
                    try {
                      await Api.post('/listeler/${l['id']}/oge', {
                        'tmdb_id': widget.tmdbId,
                        'tur': widget.tur,
                      });
                      sayfa.pop();
                      messenger.showSnackBar(
                        SnackBar(content: Text('Listeye eklendi'.c)),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hata != null) {
      return Scaffold(
        appBar: AppBar(),
        body: HataGorunumu(mesaj: _hata!, tekrar: _yukle),
      );
    }
    if (_icerik == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: DiziRenkler.sari)),
      );
    }

    final c = _icerik!;
    final tv = widget.tur == 'tv';
    final ad = (c['name'] ?? c['title'] ?? '?') as String;
    final yil = ((c['first_air_date'] ?? c['release_date'] ?? '') as String)
        .split('-')
        .first;
    final turler = ((c['genres'] as List<dynamic>?) ?? [])
        .map((g) => g['name'])
        .take(3)
        .join(' · ');
    // w780 idi: 3x yoğunluklu telefonda bu alan ~1290 fiziksel piksel,
    // görsel büyütülüp gözle görülür bulanıklaşıyordu. w1280 tam oturuyor;
    // "original" birkaç MB olabildiği için tercih edilmedi.
    final arka = posterUrl(c['backdrop_path'] as String?, boyut: 'w1280');
    final kadro = ((c['credits']?['cast'] as List<dynamic>?) ?? []);
    // Md. 49 — ekip ve yapım firmaları. İkisi de EKSİK gelebilir (TMDB'de
    // olmayan alanlar); boş dönerse aşağıdaki bölümler hiç çizilmez.
    final ekip = ekibiCikar(c);
    final firmalar = yapimFirmalari(c);
    final oneriler =
        ((c['recommendations']?['results'] as List<dynamic>?) ?? []);
    final sezonlar = ((c['seasons'] as List<dynamic>?) ?? [])
        .where((s) => (s['season_number'] as int) > 0)
        .toList();
    final izlenenSet = {
      for (final r in (_benim?['izlenenler'] as List<dynamic>? ?? []))
        '${r['sezon']}:${r['bolum']}',
    };
    final filmIzlendi = !tv && izlenenSet.contains('0:0');
    final favori = _benim?['favori'] == true;
    final benimDurum = _benim?['durum'] as String?;
    final tekrar = (_benim?['tekrar'] as int?) ?? 0; // yeniden izleme sayısı
    final benimPuan = _benim?['puan']?['puan'] as int?;
    // Gelecek bölüm: tarih belliyse kaç gün kaldığını göster
    final sonrakiTarih = tv
        ? ((c['next_episode_to_air'] as Map<String, dynamic>?)?['air_date']
              as String?)
        : null;
    int? kalanGun;
    if (sonrakiTarih != null) {
      final simdi = DateTime.now();
      kalanGun = DateTime.parse(
        sonrakiTarih,
      ).difference(DateTime(simdi.year, simdi.month, simdi.day)).inDays;
    }

    return Scaffold(
      // PC'de içerik tüm genişliğe yayılmasın: akış/Reels ile AYNI ortalanmış
      // okuma kolonu ([masaustuKolonGenisligi], tema.dart). Kullanıcı isteği
      // (madde 26): "genişliklerini akış ve reelsdeki gibi yap". Arka kapak
      // şeridi de bu kolona sığar; mobilde ([masaustuMu] false) kısıt hiç
      // bağlamaz, sayfa eskisi gibi tam genişlik kalır.
      body: OrtaKolon(
        azami: masaustuKolonGenisligi,
        cocuk: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              // Oturumsuz ziyaretçinin alt gezinme çubuğu yoktur (kabuk giriş
              // ister); bu buton olmasa sayfada çıkışsız kalırdı.
              actions: const [GirisEylemi()],
              flexibleSpace: FlexibleSpaceBar(
                // Kaydırma yana; şerit yukarı kayarken ölçeklenseydi kaydırıcının
                // noktaları da kayar, parmağın altındaki kare oynardı.
                collapseMode: CollapseMode.none,
                // Birden çok kapak varsa yana kaydırmalı görünüm (nokta + sayaç);
                // tek kapakta ESKİ sabit görsel, hiç kapak yoksa boş zemin —
                // hiçbirinde boş kutu ya da hata metni çıkmaz.
                background: _kapaklar.length > 1
                    ? AkisMedya(
                        urller: kapakUrlleri,
                        tumunuKapla: true,
                        // Rozet üst çubuğun altına insin (üstteki düğmelerle
                        // çakışmasın); çentik/durum çubuğu da hesaba katılır.
                        sayacUstBosluk:
                            MediaQuery.paddingOf(context).top + kToolbarHeight,
                        // Karartma göstergelerin ALTINA çizilir; en üste konsaydı
                        // opak alt ucu noktaları yutardı.
                        gorselUstu: _karartma,
                        // DOKUNULAN kapak açılır: sabit 0 verilseydi kaydırıp
                        // üçüncü kapağa dokunan kullanıcı birinciyi görürdü.
                        onAc: (i) =>
                            medyaGoster(context, kapakUrlleri, baslangic: i),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          if (arka != null)
                            GestureDetector(
                              onTap: () => medyaGoster(context, [arka]),
                              child: CachedNetworkImage(
                                imageUrl: arka,
                                httpHeaders: gorselBasliklari(arka),
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Container(color: DiziRenkler.kart),
                          // Karartma yalnız SÜStür; dokunuşu yutup görseli
                          // açılmaz yapmasın diye tıklamaya kapalı.
                          IgnorePointer(child: _karartma),
                        ],
                      ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ad,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (yil.isNotEmpty) yil,
                        if (tv) '{} sezon'.cf([c['number_of_seasons']]),
                        if (turler.isNotEmpty) turler,
                      ].join(' · '),
                      style: TextStyle(color: DiziRenkler.metin54),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 6,
                      children: [
                        const Icon(
                          Icons.star,
                          color: DiziRenkler.sari,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '{} TMDB'.cf([
                            ((c['vote_average'] as num?) ?? 0).toStringAsFixed(
                              1,
                            ),
                          ]),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (_incelemeler?['ortalama'] != null) ...[
                          const SizedBox(width: 12),
                          // Madde 17: rozete dokununca puan dağılımı açılır
                          // (IMDb'de de puan grafiğe kapı olur). Rozetin
                          // KENDİSİ 21 dp; dokunma hedefi [dokunmaHedefi] ile
                          // 44 dp'ye çıkarılır — rozet ortalanır, görünümü
                          // değişmez. Yanındaki izleyen sayacı da aynı
                          // yüksekliği alır ki satır tırtıklı görünmesin.
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => puanDagilimiAc(
                              context,
                              dagilim: _incelemeler?['dagilim'],
                              ortalama: _incelemeler?['ortalama'],
                              benimDbPuani: _benim?['puan']?['puan'] as int?,
                            ),
                            child: SizedBox(
                              height: dokunmaHedefi,
                              child: Center(
                                widthFactor: 1,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: DiziRenkler.sari,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '{} dizi.jpg'.cf([
                                          yildizOrtalamaMetni(
                                            _incelemeler!['ortalama'],
                                          ),
                                        ]),
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                      // Dokunulabilirliğin görünür ipucu.
                                      const SizedBox(width: 3),
                                      const Icon(
                                        Icons.bar_chart,
                                        size: 13,
                                        color: Colors.black,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        // Uygulamada kaç kişi izledi — dokununca liste açılır
                        if ((_izleyenler?['sayi'] as num? ?? 0) > 0) ...[
                          const SizedBox(width: 12),
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: _izleyenlerAc,
                            // 22 dp'lik dokunma hedefi vardı (44 asgarisinin
                            // yarısı) — puan rozetiyle aynı yüksekliğe alındı.
                            child: SizedBox(
                              height: dokunmaHedefi,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.visibility_outlined,
                                      size: 18,
                                      color: DiziRenkler.metin70,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_izleyenler!['sayi']}',
                                      style: TextStyle(
                                        color: DiziRenkler.metin70,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Sosyal kanıt: takip ettiklerin arasında kim izlemiş
                    if ((_izleyenler?['takip_sayi'] as num? ?? 0) > 0) ...[
                      const SizedBox(height: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _izleyenlerAc,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              // Takip edilen izleyenlerin üst üste binen avatarları
                              Builder(
                                builder: (context) {
                                  final takipliler =
                                      (_izleyenler?['kullanicilar']
                                                  as List<dynamic>? ??
                                              [])
                                          .where(
                                            (k) => k['takip_ediyorum'] == true,
                                          )
                                          .take(4)
                                          .toList();
                                  if (takipliler.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return SizedBox(
                                    width: 24.0 + (takipliler.length - 1) * 16,
                                    height: 28,
                                    child: Stack(
                                      children: [
                                        for (
                                          var i = 0;
                                          i < takipliler.length;
                                          i++
                                        )
                                          Positioned(
                                            left: i * 16.0,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: DiziRenkler.siyah,
                                                  width: 2,
                                                ),
                                              ),
                                              child: CircleAvatar(
                                                radius: 12,
                                                backgroundColor:
                                                    DiziRenkler.koyuGri,
                                                backgroundImage:
                                                    dosyaUrl(
                                                          takipliler[i]['avatar']
                                                              as String?,
                                                        ) !=
                                                        null
                                                    ? NetworkImage(
                                                        dosyaUrl(
                                                          takipliler[i]['avatar']
                                                              as String?,
                                                        )!,
                                                      )
                                                    : null,
                                                child:
                                                    takipliler[i]['avatar'] ==
                                                        null
                                                    ? Icon(
                                                        Icons.person,
                                                        size: 13,
                                                        color:
                                                            DiziRenkler.metin38,
                                                      )
                                                    : null,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Takip ettiğin {} kişi izledi'.cf([
                                    (_izleyenler?['takip_sayi'] as num).toInt(),
                                  ]),
                                  style: TextStyle(
                                    color: DiziRenkler.metin70,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: DiziRenkler.metin38,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    // Durum çipleri: dar ekranda sağa taşmak yerine alt satıra sarar
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (kod, etiket, ikon) in durumSecenekleri)
                          FilterChip(
                            avatar: Icon(
                              ikon,
                              size: 16,
                              color: benimDurum == kod
                                  ? Colors.black
                                  : DiziRenkler.metin70,
                            ),
                            label: Text(
                              etiket.c,
                              style: TextStyle(
                                color: benimDurum == kod
                                    ? Colors.black
                                    : DiziRenkler.metin,
                              ),
                            ),
                            selected: benimDurum == kod,
                            onSelected: (s) => _durumSec(s ? kod : null),
                          ),
                        // Profilimde gizle: içerik açık profilde ve izleyenler
                        // listesinde görünmez (durum/izleme varsa anlamlı)
                        if (benimDurum != null || izlenenSet.isNotEmpty)
                          FilterChip(
                            avatar: Icon(
                              Icons.visibility_off_outlined,
                              size: 16,
                              color: _benim?['gizli'] == true
                                  ? Colors.black
                                  : DiziRenkler.metin70,
                            ),
                            label: Text(
                              'Profilimde gizle'.c,
                              style: TextStyle(
                                color: _benim?['gizli'] == true
                                    ? Colors.black
                                    : DiziRenkler.metin,
                              ),
                            ),
                            selected: _benim?['gizli'] == true,
                            onSelected: (_) => _gizleToggle(),
                          ),
                        // Sil: tüm izleme izini kaldırır (uyarılı)
                        if (benimDurum != null || izlenenSet.isNotEmpty)
                          ActionChip(
                            avatar: const Icon(
                              Icons.delete_outline,
                              size: 16,
                              color: Colors.redAccent,
                            ),
                            label: Text(
                              'Sil'.c,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                            onPressed: _sifirla,
                          ),
                      ],
                    ),
                    // Yeniden izleme (yalnız "bitirdim" durumunda): Letterboxd tarzı
                    if (benimDurum == 'bitirdim') ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ActionChip(
                            avatar: Icon(
                              Icons.replay,
                              size: 16,
                              color: DiziRenkler.sariMetin,
                            ),
                            label: Text('Yeniden izledim'.c),
                            onPressed: () => _rewatch(1),
                          ),
                          if (tekrar > 0) ...[
                            const SizedBox(width: 10),
                            Text(
                              // tekrar=1 → toplam 2. izleme
                              '{}. kez izlendi'.cf([tekrar + 1]),
                              style: TextStyle(
                                color: DiziRenkler.metin54,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            // Geri alma. İkon 16 px kalır ama dokunma hedefi
                            // 44 px'e çıkar (16 + 2×14) — ikonu büyütmeden
                            // padding'le, UX kuralı gereği. Tooltip/Semantics
                            // olmadan ikon tek başına ne yaptığını söylemiyordu.
                            Tooltip(
                              message: 'Geri al'.c,
                              child: InkWell(
                                onTap: () => _rewatch(-1),
                                borderRadius: BorderRadius.circular(22),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Icon(
                                    Icons.remove_circle_outline,
                                    size: 16,
                                    color: DiziRenkler.metin38,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    // Gelecek bölüm geri sayımı
                    if (kalanGun != null && kalanGun >= 0) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 16,
                            color: DiziRenkler.sariMetin,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            kalanGun == 0
                                ? 'Gelecek bölüm bugün'.c
                                : 'Gelecek bölüm {} gün sonra'.cf([kalanGun]),
                            style: TextStyle(
                              color: DiziRenkler.sariMetin,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            sonrakiTarih!,
                            style: TextStyle(
                              color: DiziRenkler.metin38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    // Aksiyon satırı
                    Row(
                      children: [
                        if (!tv)
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _filmIzlendiToggle,
                              style: filmIzlendi
                                  ? FilledButton.styleFrom(
                                      backgroundColor: DiziRenkler.kart,
                                      foregroundColor: DiziRenkler.sariMetin,
                                    )
                                  : null,
                              icon: Icon(
                                filmIzlendi
                                    ? Icons.check_circle
                                    : Icons.visibility,
                              ),
                              label: Text(
                                filmIzlendi ? 'İzledin'.c : 'İzledim'.c,
                              ),
                            ),
                          ),
                        if (!tv) const SizedBox(width: 8),
                        IconButton(
                          onPressed: _favoriToggle,
                          tooltip: 'Favori'.c,
                          icon: Icon(
                            favori ? Icons.favorite : Icons.favorite_border,
                            color: favori
                                ? Colors.redAccent
                                : DiziRenkler.metin,
                          ),
                        ),
                        IconButton(
                          onPressed: _puanla,
                          tooltip: 'Puanla'.c,
                          icon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                benimPuan != null
                                    ? Icons.star
                                    : Icons.star_border,
                                color: DiziRenkler.sari,
                              ),
                              if (benimPuan != null)
                                Text(
                                  ' ${yildiza(benimPuan)}',
                                  style: TextStyle(
                                    color: DiziRenkler.sariMetin,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _listeyeEkle,
                          tooltip: 'Listeye ekle'.c,
                          icon: Icon(
                            Icons.playlist_add,
                            color: DiziRenkler.metin,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Tepki ikonları
                    TepkiSatiri(tur: widget.tur, tmdbId: widget.tmdbId),
                    const SizedBox(height: 12),
                    if ((c['overview'] as String?)?.isNotEmpty == true)
                      Text(
                        c['overview'] as String,
                        style: const TextStyle(height: 1.5),
                      ),
                  ],
                ),
              ),
            ),
            // Nerede izlenir (TMDB / JustWatch)
            SliverToBoxAdapter(
              child: _NeredeIzlenir(saglayicilar: c['watch/providers']),
            ),
            // Sezonlar (dizi)
            if (tv)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        'Sezonlar'.c,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    for (final s in sezonlar)
                      _SezonSatiri(
                        tmdbId: widget.tmdbId,
                        sezon: s as Map<String, dynamic>,
                        izlenenSet: izlenenSet,
                        degisti: _benimYenile,
                      ),
                  ],
                ),
              ),
            // Oyuncular
            if (kadro.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Başlık tıklanabilir: yatay şerit yalnız ilk 20 kişiyi
                    // gösteriyor, dokununca TÜM kadro listelenir.
                    SeritBasligi(
                      baslik: 'Oyuncular'.c,
                      ek: '(${kadro.length})',
                      onTap: () => tumOyuncularAc(context, kadro),
                    ),
                    SizedBox(
                      height: 150,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: kadro.length.clamp(0, 20),
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final o = kadro[i] as Map<String, dynamic>;
                          final foto = posterUrl(
                            o['profile_path'] as String?,
                            boyut: 'w185',
                          );
                          return InkWell(
                            onTap: () => context.push('/kisi/${o['id']}'),
                            child: SizedBox(
                              width: 76,
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 34,
                                    backgroundColor: DiziRenkler.kart,
                                    backgroundImage: foto == null
                                        ? null
                                        : CachedNetworkImageProvider(
                                            foto,
                                            headers: gorselBasliklari(foto),
                                          ),
                                    child: foto == null
                                        ? Icon(
                                            Icons.person,
                                            color: DiziRenkler.metin24,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    o['name'] as String? ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            // Yapım ekibi (md. 49) — yönetmen/senarist/yapımcı, tıklanabilir.
            // Kadro şeridiyle AYNI kart kalıbı: yeni bir tasarım dili yok,
            // tek fark adın altındaki iş satırı.
            if (ekip.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // "Tümünü gör" YOK: liste zaten tavanlı ve kısa
                    // ([ekipRolTavani]), açılacak ikinci bir ekran olmazdı.
                    SeritBasligi(baslik: 'Yapım Ekibi'.c),
                    SizedBox(
                      // Kadro şeridi 150: 68 (avatar) + 6 + 2 satır ad.
                      // Burada bir de iş satırı var (2 satıra kadar) → 164.
                      // Ölçülen içerik ~127 dp; kalan pay yazı ölçeği
                      // büyütülmüş cihazlar için.
                      height: 164,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: ekip.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final u = ekip[i];
                          final foto = posterUrl(u.foto, boyut: 'w185');
                          return InkWell(
                            // Kart 76x~127 dp — 44 dp dokunma asgarisinin
                            // çok üstünde.
                            onTap: () => context.push('/kisi/${u.id}'),
                            child: SizedBox(
                              width: 76,
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 34,
                                    backgroundColor: DiziRenkler.kart,
                                    backgroundImage: foto == null
                                        ? null
                                        : CachedNetworkImageProvider(
                                            foto,
                                            headers: gorselBasliklari(foto),
                                          ),
                                    child: foto == null
                                        ? Icon(
                                            Icons.person,
                                            color: DiziRenkler.metin24,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    u.ad,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    // Tekilleştirilmiş işler: "Senaryo, Yapımcı"
                                    u.isler.map((i) => i.c).join(', '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: DiziRenkler.metin54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            // Yapım firmaları (md. 49) — dokununca firma sayfası açılır.
            if (firmalar.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SeritBasligi(baslik: 'Yapım Firmaları'.c),
                    SizedBox(
                      // 56 (logo) + 6 + 2 satır ad (~26) = 88; pay bırakıldı.
                      height: 108,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: firmalar.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final f = firmalar[i];
                          final ad = f['name'] as String;
                          return InkWell(
                            // Kart 112x~88 dp — dokunma asgarisinin üstünde.
                            onTap: () => context.push(
                              sirketYolu(
                                (f['id'] as num).toInt(),
                                ad: ad,
                                tur: widget.tur,
                              ),
                            ),
                            child: SizedBox(
                              width: 112,
                              child: Column(
                                children: [
                                  FirmaLogosu(
                                    logoYolu: f['logo_path'] as String?,
                                    genislik: 112,
                                    yukseklik: 56,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    ad,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            // İncelemeler
            if ((_incelemeler?['incelemeler'] as List<dynamic>? ?? [])
                .isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        'İncelemeler'.c,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    for (final inc
                        in (_incelemeler!['incelemeler'] as List<dynamic>).take(
                          10,
                        ))
                      Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () => kullaniciyaGit(
                                      context,
                                      inc['kullanici_adi'] as String,
                                    ),
                                    child: Text(
                                      '@${inc['kullanici_adi']}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: DiziRenkler.sariMetin,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(
                                    Icons.star,
                                    color: DiziRenkler.sari,
                                    size: 14,
                                  ),
                                  Text(
                                    ' ${yildiza(inc['puan'])}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                inc['yorum'] as String,
                                style: const TextStyle(height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            // Yorumlar (fotoğraf/video destekli)
            SliverToBoxAdapter(
              child: YorumBolumu(tur: widget.tur, tmdbId: widget.tmdbId),
            ),
            // Öneriler
            if (oneriler.isNotEmpty)
              SliverToBoxAdapter(
                child: PosterSeridi(
                  baslik: 'Bunları da Beğenebilirsin'.c,
                  icerikler: oneriler,
                  turZorla: widget.tur,
                ),
              ),
            SliverToBoxAdapter(
              child: SizedBox(height: altGuvenli(context, ekstra: 32)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tıklayınca yeni sayfa açmaz; kartın altında bölüm listesi açılır.
/// Bölüme tıklamak bölüm sayfasını açar, sağdaki halka izleme işaretidir.
class _SezonSatiri extends StatefulWidget {
  final int tmdbId;
  final Map<String, dynamic> sezon;
  final Set<String> izlenenSet;
  final VoidCallback degisti;

  const _SezonSatiri({
    required this.tmdbId,
    required this.sezon,
    required this.izlenenSet,
    required this.degisti,
  });

  @override
  State<_SezonSatiri> createState() => _SezonSatiriState();
}

class _SezonSatiriState extends State<_SezonSatiri> {
  bool _acik = false;
  List<dynamic>? _bolumler;
  String? _hata;

  int get _no => widget.sezon['season_number'] as int;

  Future<void> _bolumleriYukle() async {
    setState(() => _hata = null);
    try {
      final d = await Api.get('/tmdb/tv/${widget.tmdbId}/season/$_no');
      if (mounted) {
        setState(() => _bolumler = d['episodes'] as List<dynamic>);
      }
    } catch (e) {
      if (mounted) setState(() => _hata = e.toString());
    }
  }

  Future<void> _toggle(int bolumNo) async {
    if (!girisGerekli(context)) return;
    try {
      final c = await Api.post('/izleme/toggle', {
        'tmdb_id': widget.tmdbId,
        'tur': 'tv',
        'sezon': _no,
        'bolum': bolumNo,
      });
      // Bölüm işaretlendiyse sunucu diziyi izliyorum/bitirdim yapar → poster
      // rozeti anında çıksın. Kaldırmada rozet BIRAKILIR: başka bölümler hâlâ
      // izlenmiş olabilir, sunucuya sormadan silmek yanlış olurdu.
      if (c is Map && c['izlendi'] == true) {
        KitaplikDurumu.isaretle('tv', widget.tmdbId, true);
      }
      widget.degisti();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _tumu(bool isaretle, int toplam) async {
    if (!girisGerekli(context)) return;
    try {
      await Api.post('/izleme/sezon', {
        'tmdb_id': widget.tmdbId,
        'sezon': _no,
        'bolum_sayisi': toplam,
        'isaretle': isaretle,
      });
      if (isaretle) KitaplikDurumu.isaretle('tv', widget.tmdbId, true);
      widget.degisti();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final toplam = (widget.sezon['episode_count'] as int?) ?? 0;
    final izlenen = widget.izlenenSet
        .where((k) => k.startsWith('$_no:'))
        .length
        .clamp(0, toplam);
    final tamam = toplam > 0 && izlenen >= toplam;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: toplam == 0 ? 0 : izlenen / toplam,
                    strokeWidth: 4,
                    color: DiziRenkler.sari,
                    backgroundColor: DiziRenkler.metin12,
                  ),
                  Text(
                    '$_no',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            title: Text(
              widget.sezon['name'] as String? ?? '{}. Sezon'.cf([_no]),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('{} / {} bölüm'.cf([izlenen, toplam])),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tamam)
                  Icon(Icons.check_circle, color: DiziRenkler.sariMetin),
                Icon(
                  _acik ? Icons.expand_less : Icons.expand_more,
                  color: DiziRenkler.metin38,
                ),
              ],
            ),
            onTap: () {
              setState(() => _acik = !_acik);
              if (_acik && _bolumler == null) _bolumleriYukle();
            },
          ),
          if (_acik) ...[
            if (_hata != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(_hata!, style: TextStyle(color: DiziRenkler.metin54)),
                    TextButton(
                      onPressed: _bolumleriYukle,
                      child: Text('Tekrar dene'.c),
                    ),
                  ],
                ),
              )
            else if (_bolumler == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(color: DiziRenkler.sari),
                ),
              )
            else ...[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _tumu(!tamam, toplam),
                  icon: Icon(
                    tamam ? Icons.remove_done : Icons.done_all,
                    size: 18,
                    color: DiziRenkler.sariMetin,
                  ),
                  label: Text(
                    tamam ? 'Tümünü Kaldır'.c : 'Tümünü İzledim'.c,
                    style: TextStyle(
                      color: DiziRenkler.sariMetin,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              for (final b in _bolumler!)
                _BolumSatiri(
                  tmdbId: widget.tmdbId,
                  sezonNo: _no,
                  bolum: b as Map<String, dynamic>,
                  izlendi: widget.izlenenSet.contains(
                    '$_no:${b['episode_number']}',
                  ),
                  izlendiToggle: () => _toggle(b['episode_number'] as int),
                  degisti: widget.degisti,
                ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _BolumSatiri extends StatelessWidget {
  final int tmdbId;
  final int sezonNo;
  final Map<String, dynamic> bolum;
  final bool izlendi;
  final VoidCallback izlendiToggle;
  final VoidCallback degisti;

  const _BolumSatiri({
    required this.tmdbId,
    required this.sezonNo,
    required this.bolum,
    required this.izlendi,
    required this.izlendiToggle,
    required this.degisti,
  });

  @override
  Widget build(BuildContext context) {
    final no = bolum['episode_number'] as int;
    final gorsel = posterUrl(bolum['still_path'] as String?, boyut: 'w300');
    final tarih = bolum['air_date'] as String? ?? '';

    return InkWell(
      onTap: () async {
        await context.push(
          '/dizi/$tmdbId/sezon/$sezonNo/bolum/$no',
          extra: izlendi,
        );
        degisti();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 88,
                height: 50,
                child: gorsel == null
                    ? Container(
                        color: DiziRenkler.koyuGri,
                        child: Icon(Icons.tv, color: DiziRenkler.metin24),
                      )
                    : CachedNetworkImage(
                        imageUrl: gorsel,
                        httpHeaders: gorselBasliklari(gorsel),
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$no. ${bolum['name'] ?? 'Bölüm'.c}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  if (tarih.isNotEmpty)
                    Text(
                      tarih,
                      style: TextStyle(
                        fontSize: 11,
                        color: DiziRenkler.metin38,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: izlendiToggle,
              icon: Icon(
                izlendi ? Icons.check_circle : Icons.radio_button_unchecked,
                color: izlendi ? DiziRenkler.sariMetin : DiziRenkler.metin24,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// TMDB "watch/providers" verisinden içeriğin hangi platformlarda
/// (abonelik/kirala/satın al) olduğunu bölgeye göre gösterir.
class _NeredeIzlenir extends StatelessWidget {
  final dynamic saglayicilar; // c['watch/providers']
  const _NeredeIzlenir({required this.saglayicilar});

  /// Uygulama diline göre öncelikli bölge (ISO ülke kodu).
  static const _bolgeler = {
    'tr': 'TR',
    'en': 'US',
    'zh': 'CN',
    'hi': 'IN',
    'es': 'ES',
    'fr': 'FR',
    'ar': 'SA',
    'bn': 'BD',
    'pt': 'BR',
    'ru': 'RU',
    'ur': 'PK',
    'id': 'ID',
    'de': 'DE',
    'ja': 'JP',
    'sw': 'TZ',
    'mr': 'IN',
    'te': 'IN',
    'vi': 'VN',
    'ko': 'KR',
    'ta': 'IN',
    'it': 'IT',
    'fa': 'IR',
    'pl': 'PL',
    'uk': 'UA',
    'ro': 'RO',
    'nl': 'NL',
    'th': 'TH',
    'gu': 'IN',
    'kn': 'IN',
    'ml': 'IN',
    'pa': 'IN',
    'ms': 'MY',
    'my': 'MM',
    'am': 'ET',
    'az': 'AZ',
    'el': 'GR',
    'hu': 'HU',
    'cs': 'CZ',
    'sv': 'SE',
    'he': 'IL',
    'fil': 'PH',
    'sr': 'RS',
    'bg': 'BG',
    'da': 'DK',
    'fi': 'FI',
    'nb': 'NO',
  };

  @override
  Widget build(BuildContext context) {
    final sonuclar = (saglayicilar is Map)
        ? (saglayicilar['results'] as Map<String, dynamic>?)
        : null;
    if (sonuclar == null || sonuclar.isEmpty) return const SizedBox.shrink();

    // Tercih bölgesi → ABD → İngiltere → mevcut ilk bölge
    final tercih = _bolgeler[Ceviri.dil.value] ?? 'US';
    final bolgeKod = sonuclar.containsKey(tercih)
        ? tercih
        : sonuclar.containsKey('US')
        ? 'US'
        : sonuclar.containsKey('GB')
        ? 'GB'
        : sonuclar.keys.first;
    final bolge = sonuclar[bolgeKod] as Map<String, dynamic>;

    final gruplar = <(String, List<dynamic>)>[
      ('Abonelik'.c, (bolge['flatrate'] as List<dynamic>?) ?? const []),
      ('Kirala'.c, (bolge['rent'] as List<dynamic>?) ?? const []),
      ('Satın al'.c, (bolge['buy'] as List<dynamic>?) ?? const []),
    ].where((g) => g.$2.isNotEmpty).toList();
    if (gruplar.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Text(
            'Nerede İzlenir'.c,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
        for (final g in gruplar)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  g.$1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: DiziRenkler.metin54,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final s in g.$2)
                      _saglayiciRozet(s as Map<String, dynamic>),
                  ],
                ),
              ],
            ),
          ),
        // JustWatch atıfı (TMDB kullanım koşulu)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            'Veri: JustWatch'.c,
            style: TextStyle(fontSize: 11, color: DiziRenkler.metin38),
          ),
        ),
      ],
    );
  }

  Widget _saglayiciRozet(Map<String, dynamic> s) {
    final logo = posterUrl(s['logo_path'] as String?, boyut: 'w92');
    final ad = (s['provider_name'] as String?) ?? '';
    return Tooltip(
      message: ad,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: logo == null
            ? Container(
                width: 48,
                height: 48,
                color: DiziRenkler.metin12,
                alignment: Alignment.center,
                child: Text(
                  ad.isNotEmpty ? ad[0] : '?',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              )
            : CachedNetworkImage(
                imageUrl: logo,
                httpHeaders: gorselBasliklari(logo),
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
      ),
    );
  }
}

/// Dizinin/filmin TÜM oyuncu kadrosunu alt sayfada listeler.
///
/// Detaydaki yatay şerit yalnız ilk 20 kişiyi gösteriyor; kalabalık
/// kadrolarda (Kurtlar Vadisi gibi) geri kalanına ulaşmanın yolu yoktu.
Future<void> tumOyuncularAc(
  BuildContext context,
  List<dynamic> kadro,
) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: DiziRenkler.koyuGri,
  isScrollControlled: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (sheetContext) => DraggableScrollableSheet(
    initialChildSize: 0.75,
    minChildSize: 0.4,
    maxChildSize: 0.95,
    expand: false,
    builder: (context, kaydirma) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(
            children: [
              Icon(Icons.people_outline, color: DiziRenkler.sari),
              const SizedBox(width: 10),
              // Flexible: my/ar çevirileri uzun; sığmazsa sarsın, kesilmesin.
              Flexible(
                child: Text(
                  'Oyuncular'.c,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(${kadro.length})',
                style: TextStyle(color: DiziRenkler.metin54, fontSize: 14),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: kaydirma,
            itemCount: kadro.length,
            itemBuilder: (context, i) {
              final o = kadro[i] as Map<String, dynamic>;
              final foto = posterUrl(
                o['profile_path'] as String?,
                boyut: 'w185',
              );
              final rol = o['character'] as String?;
              return ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: DiziRenkler.kart,
                  backgroundImage: foto != null
                      ? CachedNetworkImageProvider(
                          foto,
                          headers: gorselBasliklari(foto),
                        )
                      : null,
                  child: foto == null
                      ? Icon(Icons.person, color: DiziRenkler.metin38)
                      : null,
                ),
                title: Text(
                  '${o['name']}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: rol != null && rol.isNotEmpty
                    ? Text(
                        rol,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: DiziRenkler.metin54),
                      )
                    : null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push('/kisi/${o['id']}');
                },
              );
            },
          ),
        ),
      ],
    ),
  ),
);
