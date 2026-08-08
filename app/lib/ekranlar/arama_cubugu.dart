import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'ortak.dart';

/// Masaüstü üst barının yüksekliği.
const double masaustuUstBarYuksekligi = 64;

/// Masaüstü üst barında arama kutusunun İKİ YANINDA bırakılan pay: solda marka
/// bloğu, sağda eylem ikonları bu payın içinde durur. Kutu genişliği buna göre
/// hesaplandığı için kutu TAM ORTADA kalırken marka/eylemlerle ÇAKIŞMAZ.
const double masaustuUstBarKenarPayi = 230;

/// Masaüstünde arama kutusunun azami genişliği (720 masaüstünde şişkin duruyor).
const double masaustuAramaGenisligi = 560;

/// Mobilde tam ekran aramanın yolu.
///
/// KÖK seviyede bir rota (kabuğun İÇİNDE değil): böylece açılınca alt gezinme
/// çubuğunun ÜSTÜNE değil YERİNE gelir, tarayıcı geçmişine kendi adımını
/// bırakır ve Android geri tuşu/tarayıcı geri oku aramayı KAPATIR — sayfadan
/// çıkarmaz.
const String tamAramaYolu = '/tam-arama';

/// Arama mantığı (sorgu, gecikme, istek, sonuç kümeleri, dört hâl).
///
/// Masaüstünün satır-içi çubuğu ([AramaCubugu]) ile mobilin tam ekran araması
/// ([TamEkranAramaSayfasi]) AYNI mixin'i kullanır. Kopyalansaydı birinde
/// düzeltilen hata ötekinde kalırdı.
mixin AramaMantigi<T extends StatefulWidget> on State<T> {
  final TextEditingController aramaKutu = TextEditingController();
  Timer? _aramaGecikme;
  String sorgu = '';
  bool araniyor = false;
  String? aramaHatasi; // sessiz başarısızlık yok: hata hâli gösterilir
  List<dynamic> _aramaIcerik = []; // dizi + film
  List<dynamic> _aramaKisiler = []; // oyuncu/yönetmen (TMDB)
  List<dynamic> _aramaKullanicilar = []; // uygulama kullanıcıları
  String? _duzeltme; // "şunu mu demek istedin" — sunucu yazım düzeltmesi

  /// Sonuç göstermeye yetecek uzunlukta sorgu var mı?
  bool get sorguYeterli => sorgu.trim().length >= 2;

  bool get _sonucBos =>
      _aramaKullanicilar.isEmpty &&
      _aramaIcerik.isEmpty &&
      _aramaKisiler.isEmpty;

  @override
  void dispose() {
    _aramaGecikme?.cancel();
    aramaKutu.dispose();
    super.dispose();
  }

  void aramaDegisti(String s) {
    setState(() {
      sorgu = s;
      if (s.trim().length < 2) aramaHatasi = null;
    });
    _aramaGecikme?.cancel();
    if (s.trim().length < 2) return;
    _aramaGecikme = Timer(const Duration(milliseconds: 450), () => ara(s));
  }

  Future<void> ara(String sorgu) async {
    setState(() {
      araniyor = true;
      aramaHatasi = null;
    });
    try {
      final q = Uri.encodeComponent(sorgu.trim());
      final y = await Future.wait([
        Api.get('/ara?q=$q'),
        Api.get('/kullanici-ara?q=$q').catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted || this.sorgu.trim() != sorgu.trim()) return;
      final sonuclar = (y[0]['results'] as List<dynamic>? ?? []);
      // Sunucu yazım hatasını düzeltip "duzeltme" döndürdüyse başlıkta göster
      final d = y[0]['duzeltme'] as String?;
      setState(() {
        _duzeltme = (d != null && d.toLowerCase() != sorgu.trim().toLowerCase())
            ? d
            : null;
        _aramaIcerik = sonuclar
            .where(
              (r) => r['media_type'] != 'person' && r['poster_path'] != null,
            )
            .toList();
        _aramaKisiler = sonuclar
            .where(
              (r) => r['media_type'] == 'person' && r['profile_path'] != null,
            )
            .toList();
        _aramaKullanicilar = y[1]['kullanicilar'] as List<dynamic>? ?? [];
      });
    } catch (_) {
      if (mounted) setState(() => aramaHatasi = 'Arama başarısız'.c);
    } finally {
      if (mounted) setState(() => araniyor = false);
    }
  }

  /// Arama kutusunun kendisi (masaüstü çubuğu ve tam ekran AYNI kutuyu kullanır).
  Widget aramaKutusu({bool otomatikOdak = false}) => TextField(
    controller: aramaKutu,
    onChanged: aramaDegisti,
    autofocus: otomatikOdak,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: 'Dizi, film veya kişi ara...'.c,
      prefixIcon: Icon(Icons.search, color: DiziRenkler.metin54),
      suffixIcon: araniyor
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
          : (sorgu.isNotEmpty
                ? IconButton(
                    tooltip: 'Kapat'.c,
                    icon: Icon(Icons.close, color: DiziRenkler.metin54),
                    onPressed: () {
                      aramaKutu.clear();
                      setState(() {
                        sorgu = '';
                        aramaHatasi = null;
                      });
                    },
                  )
                : null),
    ),
  );

  /// Arama sonuçları: bölümlü, satır tabanlı liste.
  ///
  /// DÖRT HÂL burada toplanır: hata (tekrar dene) → yükleniyor (spinner) →
  /// sonuç yok (boş durum) → sonuç listesi. Boş sorgu hâli çağıranın işi
  /// (masaüstünde sayfa içeriği, tam ekranda başlangıç ipucu).
  Widget aramaSonuclari() {
    if (aramaHatasi != null && _sonucBos) {
      return HataGorunumu(mesaj: aramaHatasi!, tekrar: () => ara(sorgu));
    }
    if (araniyor && _sonucBos) {
      return const Center(
        child: CircularProgressIndicator(color: DiziRenkler.sari),
      );
    }
    if (_sonucBos) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 44, color: DiziRenkler.metin24),
            const SizedBox(height: 10),
            Text(
              'Sonuç bulunamadı'.c,
              style: TextStyle(color: DiziRenkler.metin54),
            ),
          ],
        ),
      );
    }
    Widget baslik(IconData ikon, String metin) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          Icon(ikon, size: 17, color: DiziRenkler.sariMetin),
          const SizedBox(width: 6),
          Text(
            metin,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
    return OrtaKolon(
      azami: masaustuKolonGenisligi,
      cocuk: ListView(
        // Klavye açıkken listeyi sürüklemek klavyeyi kapatsın.
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        // NEDEN altGuvenli, NEDEN sabit 24 değil: ListView'e AÇIK bir
        // `padding` verildiği an Flutter'ın MediaQuery alt güvenli alanını
        // kendiliğinden eklemesi devre dışı kalır (BoxScrollView yalnız
        // padding == null iken ekler). Bu yüzden tam ekran aramada son sonuç
        // satırı Android navi tuşlarının / iOS ana ekran çubuğunun ALTINDA
        // kalıyordu.
        //
        // ÇAĞIRAN-FARKINDALIĞI PARAMETRESİZ ÇÖZÜLÜR: aynı liste hem kabuk
        // DIŞINDAKİ [TamEkranAramaSayfasi]nda hem kabuk İÇİNDEKİ
        // [AramaCubugu]nda kullanılıyor; ayrımı MediaQuery zaten yapıyor.
        //  * Kabuk içinde: [AramaCubugu] kabuğun Scaffold gövdesinin
        //    İÇİNDEDİR; o Scaffold `bottomNavigationBar` taşıdığı için gövde
        //    MediaQuery'sinde alt payı 0'a çeker (body slotuna
        //    removeBottomPadding). altGuvenli 0 + 24 = 24 döner → FAZLADAN
        //    boşluk YOK; sistem payını Scaffold zaten alt çubuğa vermiştir.
        //  * Kabuk dışında: kök rota, üstünde alt payı yiyen kimse yok →
        //    24 + sistem payı. Yani parametre/bayrak gereksiz.
        //
        // KLAVYE ÇİFT SAYILMAZ: viewInsets burada TOPLANMAZ. (1) Scaffold
        // resizeToAvoidBottomInset ile gövdeyi zaten klavye kadar kısaltır,
        // liste klavyenin üstünde biter. (2) Klavye açıkken sistem çubuğu
        // klavyenin altında kaldığı için platform `padding.bottom`'ı 0 yapar
        // (`viewPadding` korunur, bkz. FlutterView dokümanı) — yani altGuvenli
        // o an sıfır ekler. Eski kod klavye payını AYRICA eklediği için,
        // Scaffold'un kısalttığı listenin altında bir klavye boyu daha boşluk
        // bırakıyordu.
        padding: EdgeInsets.only(bottom: altGuvenli(context, ekstra: 24)),
        children: [
          if (_duzeltme != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 13, color: DiziRenkler.metin54),
                  children: [
                    TextSpan(text: '${'Şunu mu demek istedin'.c}: '),
                    TextSpan(
                      text: _duzeltme,
                      style: TextStyle(
                        color: DiziRenkler.sariMetin,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_aramaKullanicilar.isNotEmpty) ...[
            baslik(Icons.people_outline, 'Kullanıcılar'.c),
            for (final k in _aramaKullanicilar.take(6))
              _AramaSatiri(
                gorselUrl: dosyaUrl(
                  (k as Map<String, dynamic>)['avatar'] as String?,
                ),
                yuvarlak: true,
                kullaniciAdi: k['kullanici_adi'] as String?,
                ad: '@${k['kullanici_adi']}',
                altYazi: (k['bio'] as String?) ?? '',
                onTap: () =>
                    kullaniciyaGit(context, k['kullanici_adi'] as String),
              ),
          ],
          if (_aramaIcerik.isNotEmpty) ...[
            baslik(Icons.local_movies_outlined, 'Dizi ve Filmler'.c),
            for (final r in _aramaIcerik.take(12))
              _AramaSatiri(
                gorselUrl: posterUrl(
                  (r as Map<String, dynamic>)['poster_path'] as String?,
                  boyut: 'w185',
                ),
                ad: (r['name'] ?? r['title'] ?? '?') as String,
                altYazi: [
                  ((r['first_air_date'] ?? r['release_date']) as String? ?? '')
                      .split('-')
                      .first,
                  r['media_type'] == 'tv' ? 'Dizi'.c : 'Film'.c,
                ].where((p) => p.isNotEmpty).join(' · '),
                onTap: () =>
                    context.push('/icerik/${r['media_type']}/${r['id']}'),
              ),
          ],
          if (_aramaKisiler.isNotEmpty) ...[
            baslik(Icons.person_outline, 'Kişiler'.c),
            for (final r in _aramaKisiler.take(8))
              _AramaSatiri(
                gorselUrl: posterUrl(
                  (r as Map<String, dynamic>)['profile_path'] as String?,
                  boyut: 'w185',
                ),
                yuvarlak: true,
                ad: (r['name'] ?? '?') as String,
                altYazi: '',
                onTap: () => context.push('/kisi/${r['id']}'),
              ),
          ],
        ],
      ),
    );
  }
}

/// MASAÜSTÜ (genişlik >= [masaustuEsigi]) üst barı + satır-içi arama.
///
/// Arama kutusu EKRANIN EN ÜSTÜNDE ve TAM ORTASINDA durur, [logo] solda,
/// [eylemler] sağda kalır; çağıran ekran masaüstünde kendi AppBar'ını kurmaz.
/// Sorgu 2 karakterden kısayken [cocuk], uzunsa sonuçlar gösterilir.
///
/// DAR EKRANDA arama artık burada DEĞİL: üst bara ([AramaAcmaKutusu]) taşındı
/// ve dokununca [TamEkranAramaSayfasi] açılıyor. Bu yüzden dar ekranda bu
/// sarmalayıcı yalnız [cocuk]'u geçirir — iki ayrı mobil arama kutusu olmasın.
class AramaCubugu extends StatefulWidget {
  final Widget cocuk;
  final Widget? logo;
  final List<Widget> eylemler;
  const AramaCubugu({
    super.key,
    required this.cocuk,
    this.logo,
    this.eylemler = const [],
  });

  @override
  State<AramaCubugu> createState() => _AramaCubuguState();
}

class _AramaCubuguState extends State<AramaCubugu> with AramaMantigi {
  /// Masaüstü üst barı: arama kutusu ekran genişliğinin TAM ORTASINDA
  /// (Stack + Center → sol boşluk = sağ boşluk), marka solda, eylemler sağda.
  /// Positioned'lar Stack SINIRI İÇİNDE — dışarı taşan Positioned tıklanamaz.
  Widget _masaustuUstBar(double ekranGenisligi) {
    final kutuGenisligi = (ekranGenisligi - masaustuUstBarKenarPayi * 2).clamp(
      320.0,
      masaustuAramaGenisligi,
    );
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: masaustuUstBarYuksekligi,
        child: Stack(
          children: [
            Center(
              child: SizedBox(width: kutuGenisligi, child: aramaKutusu()),
            ),
            if (widget.logo != null)
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(child: widget.logo!),
              ),
            if (widget.eylemler.isNotEmpty)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.eylemler,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ekranGenisligi = MediaQuery.sizeOf(context).width;
    // Dar ekranda arama üst bara taşındı (bkz. [AramaAcmaKutusu]); burada
    // ikinci bir kutu çizilmez, yalnız sayfa içeriği geçirilir.
    if (ekranGenisligi < masaustuEsigi) return widget.cocuk;
    return Column(
      children: [
        // Satır-içi arama: dizi/film/kişi + kullanıcılar; sonuçlar
        // modal yerine çubuğun hemen altında listelenir
        _masaustuUstBar(ekranGenisligi),
        Expanded(child: sorguYeterli ? aramaSonuclari() : widget.cocuk),
      ],
    );
  }
}

/// Dar ekranda ÜST BARDA duran kapalı arama kutusu.
///
/// Masaüstündeki "arama en üstte" düzeninin mobil karşılığı: kutu marka bloğu
/// ile eylem ikonlarının ARASINDA durur, dokununca [tamAramaYolu] açılıp EKRANI
/// KOMPLE KAPLAR. Üst bar dar olduğu için kapalı hâl kısadır (büyüteç + tek
/// kelimelik ipucu); gerçek yazma işi tam ekranda yapılır.
///
/// Dokunma alanı 48 dp — görünen kutu 36 dp olsa da InkWell tüm yüksekliği
/// kaplar (ui-ux-pro-max "Touch Target Size", asgari 44).
class AramaAcmaKutusu extends StatelessWidget {
  /// Kapalı kutunun dokunma yüksekliği (44 dp asgarisinin üstünde).
  static const double dokunmaYuksekligi = 48;

  /// Görünen hapın yüksekliği.
  static const double kutuYuksekligi = 36;

  const AramaAcmaKutusu({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Arama'.c,
      child: InkWell(
        key: const Key('arama-ac'),
        borderRadius: BorderRadius.circular(kutuYuksekligi / 2),
        onTap: () => context.push(tamAramaYolu),
        child: SizedBox(
          height: dokunmaYuksekligi,
          child: Center(
            child: Container(
              height: kutuYuksekligi,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: DiziRenkler.kart,
                borderRadius: BorderRadius.circular(kutuYuksekligi / 2),
                // Açık temada kart da üst bar da beyaza yakın: kutu ancak
                // çerçeveyle ayrışır. Renk gerçek arama alanının (input
                // teması) çerçevesiyle AYNI — iki kutu aynı aileden görünsün.
                border: Border.all(
                  color: DiziRenkler.acik
                      ? const Color(0xFFDADAE0)
                      : DiziRenkler.metin12,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: DiziRenkler.metin54),
                  const SizedBox(width: 6),
                  // Flexible + ellipsis: ipucu Türkçede kırpılmaz, çok uzun
                  // çevirilerde de TAŞMA yerine üç nokta olur.
                  Flexible(
                    child: Text(
                      'Arama'.c,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // metin70: açık temada kart üstünde ~4.6:1 kontrast
                      // (metin54 4.5 eşiğinin altında kalıyordu).
                      style: TextStyle(
                        fontSize: 13,
                        color: DiziRenkler.metin70,
                      ),
                    ),
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

/// Mobilde EKRANI KOMPLE KAPLAYAN arama.
///
/// Kök rota olduğu için alt gezinme çubuğu görünmez: arama odaklanmış bir mod,
/// klavye açıkken 52 dp'lik çubuk hem yer yer hem "buradan da çıkılır" diye
/// ikinci bir çıkış yolu sunardı. Çıkış TEK: geri oku / sistem geri tuşu.
///
/// Klavye açılınca Scaffold gövdeyi kısaltır (resizeToAvoidBottomInset) ve
/// sonuç listesi klavyenin ALTINDA kalmaz.
class TamEkranAramaSayfasi extends StatefulWidget {
  const TamEkranAramaSayfasi({super.key});

  @override
  State<TamEkranAramaSayfasi> createState() => _TamEkranAramaSayfasiState();
}

class _TamEkranAramaSayfasiState extends State<TamEkranAramaSayfasi>
    with AramaMantigi {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('tam-ekran-arama'),
      appBar: AppBar(
        // 64: kutu 56 dp yüksek, üstünde/altında 4'er dp nefes payı kalsın.
        toolbarHeight: 64,
        titleSpacing: 0,
        leading: IconButton(
          tooltip: 'Kapat'.c,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: aramaKutusu(otomatikOdak: true),
        ),
      ),
      body: sorguYeterli
          ? aramaSonuclari()
          : BosDurum(
              ikon: Icons.search,
              baslik: 'Dizi, film veya kişi ara...'.c,
            ),
    );
  }
}

/// Arama sonucu satırı: küçük görsel (poster ya da yuvarlak avatar) +
/// ad + alt bilgi. Tüm ekran boylarında aynı düzen.
class _AramaSatiri extends StatelessWidget {
  final String? gorselUrl;
  final bool yuvarlak;
  final String ad;
  final String altYazi;
  final VoidCallback onTap;
  final String? kullaniciAdi; // kullanıcı satırlarında AI rozeti için
  const _AramaSatiri({
    required this.gorselUrl,
    this.yuvarlak = false,
    required this.ad,
    required this.altYazi,
    required this.onTap,
    this.kullaniciAdi,
  });

  @override
  Widget build(BuildContext context) {
    final gorsel = gorselUrl == null
        ? Container(
            color: DiziRenkler.kart,
            child: Icon(
              yuvarlak ? Icons.person : Icons.movie_outlined,
              color: DiziRenkler.metin38,
              size: 20,
            ),
          )
        : CachedNetworkImage(imageUrl: gorselUrl!, fit: BoxFit.cover);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            yuvarlak
                ? KullaniciAvatari(
                    url: gorselUrl,
                    kullaniciAdi: kullaniciAdi,
                    yaricap: 22,
                    arkaplan: DiziRenkler.kart,
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(width: 40, height: 56, child: gorsel),
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ad,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (altYazi.isNotEmpty)
                    Text(
                      altYazi,
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
            Icon(Icons.chevron_right, size: 18, color: DiziRenkler.metin38),
          ],
        ),
      ),
    );
  }
}
