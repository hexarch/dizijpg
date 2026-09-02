import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import '../etiket_gecmisi.dart';
import '../gorsel_basliklari.dart';
import '../tema.dart';

/// Yorum bağlanabilecek TMDB kaydını seçme sayfası — ARAMA + LİSTE.
/// Seçince `Navigator.pop` ile kaydı döndürür; `media_type` alanı
/// `yorumlar.tur` ile BİREBİR aynı değeri taşır.
///
/// DÖRT TÜR (28 Ağu 2026, kullanıcı isteği: "sadece dizi film değil oyuncu
/// yönetmen yapım firması vb de seçebilir"):
///   tv · movie · person · company
/// Bu liste keyfi değil, sunucunun `YORUM_TURLERI` sabitiyle AYNI. Sunucu
/// `person` ve `company`yi 19 Ağu'dan beri kabul ediyordu; eksik olan tek şey
/// istemcinin onları seçtirmemesiydi. Beşinci bir tür eklenecekse ÖNCE
/// `YORUM_TURLERI`ne eklenmeli, yoksa gönderim 400 döner.
///
/// İKİ AYRI ARAMA UCU, TEK LİSTE: `search/multi` tv/movie/person döndürür ama
/// FİRMA DÖNDÜRMEZ — TMDB'de firma ayrı uçtadır (`search/company`). İkisi
/// paralel çağrılır; biri düşerse öteki yine sonuç verir.
///
/// GEÇMİŞ (3 Eyl 2026): arama kutusu boşken son seçilen kayıtlar ve
/// onların ilgilileri (firma / yaratıcı / oyuncular) listelenir — bkz.
/// [EtiketGecmisi]. Kullanıcı: *"en son aradığım yapımlar listelensin arama
/// yapmadan; Breaking Bad seçtim, tekrar etiket ekle deyince geçmişte
/// Breaking Bad'in firması, yönetmeni, oyuncuları olsun."*
///
/// NEDEN ORTAK BİLEŞEN: bu sayfa 2 Ağu'dan beri `sohbet.dart` içinde
/// `_IcerikSecSheet` adıyla ÖZELDİ. Akıştaki paylaşım kutusu da aynı seçiciye
/// ihtiyaç duyunca kopyalamak yerine buraya taşındı — bu depoda kopyalanan iki
/// ekran (kendi profilim / açık profil) tam da bu yüzden ayrışmıştı.
class IcerikSecSheet extends StatefulWidget {
  /// Sohbette içerik paylaşımı yalnız dizi/film bağlayabiliyor (mesaj kartı
  /// afiş çiziyor). `false` iken kişi ve firma listelenmez.
  final bool kisiVeFirma;

  const IcerikSecSheet({super.key, this.kisiVeFirma = true});

  @override
  State<IcerikSecSheet> createState() => _IcerikSecSheetState();
}

/// TMDB kaydının görsel yolu — tür başına ayrı alan.
String? tmdbGorselYolu(Map<String, dynamic> r) =>
    (r['poster_path'] ?? r['profile_path'] ?? r['logo_path']) as String?;

/// Listede görünen tür etiketi.
String tmdbTurEtiketi(String? tur) => switch (tur) {
  'tv' => 'Dizi'.c,
  'movie' => 'Film'.c,
  'person' => 'Kişi'.c,
  'company' => 'Yapım firması'.c,
  _ => '',
};

IconData _turIkonu(String? tur) => switch (tur) {
  'person' => Icons.person,
  'company' => Icons.business,
  _ => Icons.movie_outlined,
};

class _IcerikSecSheetState extends State<IcerikSecSheet> {
  final _arama = TextEditingController();
  Timer? _geciktirici;
  List<dynamic> _sonuclar = [];
  bool _araniyor = false;

  /// En az bir arama TAMAMLANDI mı. Boş liste iki ayrı şey demek olabilir —
  /// "henüz aramadın" ve "aradın, bulunamadı" — ve ikisi aynı boş ekrana
  /// düşerse kullanıcı seçicinin bozuk olduğunu sanır (ux: no-results).
  bool _arandi = false;

  /// Son seçilenler + ilgilileri (tür süzgeci uygulanmış).
  List<Map<String, dynamic>> _gecmis = const [];

  @override
  void initState() {
    super.initState();
    _gecmisiYukle();
  }

  Future<void> _gecmisiYukle() async {
    final liste = await EtiketGecmisi.oku();
    if (!mounted) return;
    setState(() {
      _gecmis = widget.kisiVeFirma
          ? liste
          : liste
                .where(
                  (r) => r['media_type'] == 'tv' || r['media_type'] == 'movie',
                )
                .toList();
    });
  }

  Future<void> _gecmisiTemizle() async {
    await EtiketGecmisi.temizle();
    if (mounted) setState(() => _gecmis = const []);
  }

  /// Kaydı seçer: geçmişe yazar (ilgilileri arka planda gelir) ve döner.
  void _sec(Map<String, dynamic> r) {
    unawaited(EtiketGecmisi.kaydet(r));
    Navigator.pop(context, r);
  }

  /// Arama kutusu boşken geçmiş gösterilir.
  bool get _gecmisKipi => _arama.text.trim().isEmpty;

  @override
  void dispose() {
    _arama.dispose();
    _geciktirici?.cancel();
    super.dispose();
  }

  void _degisti(String q) {
    _geciktirici?.cancel();
    if (q.trim().isEmpty) {
      // Kutu silindi: sonuçlar düşer, geçmiş geri gelir.
      setState(() {
        _sonuclar = [];
        _arandi = false;
        _araniyor = false;
      });
      return;
    }
    _geciktirici = Timer(const Duration(milliseconds: 400), () => _ara(q));
  }

  Future<void> _ara(String q) async {
    final sorgu = q.trim();
    if (sorgu.length < 2) return;
    if (mounted) setState(() => _araniyor = true);
    final k = Uri.encodeComponent(sorgu);
    // PARALEL ve BAĞIMSIZ: biri patlarsa öteki yine sonuç versin.
    final sonuc = await Future.wait([
      Api.get(
        '/tmdb/search/multi?query=$k',
      ).catchError((_) => <String, dynamic>{}),
      if (widget.kisiVeFirma)
        Api.get(
          '/tmdb/search/company?query=$k',
        ).catchError((_) => <String, dynamic>{}),
    ]);
    if (!mounted) return;

    final liste = <dynamic>[];
    for (final r in (sonuc[0]['results'] as List<dynamic>? ?? [])) {
      final tur = (r as Map<String, dynamic>)['media_type'];
      final izinli =
          tur == 'tv' ||
          tur == 'movie' ||
          (widget.kisiVeFirma && tur == 'person');
      // Adsız kayıt seçilemez: `tmdb_id` doğru olsa bile kullanıcı neyi
      // bağladığını göremez.
      if (izinli && ((r['name'] ?? r['title']) != null)) liste.add(r);
    }
    if (sonuc.length > 1) {
      for (final r in (sonuc[1]['results'] as List<dynamic>? ?? [])) {
        final m = Map<String, dynamic>.from(r as Map);
        // `search/company` `media_type` DÖNDÜRMEZ; sözleşmeyi biz kuruyoruz.
        m['media_type'] = 'company';
        if (m['name'] != null) liste.add(m);
      }
    }
    // TAM AD EŞLEŞMESİ ÖNE ALINIR — kararlı sıralama, gerisi bozulmaz.
    //
    // NEDEN (28 Ağu, emülatörde görüldü): `search/multi` sonuçları önce,
    // firmalar SONRA ekleniyor. "netflix" arayan kullanıcı Netflix'i (firma)
    // 20 filmin altında göremiyordu — firma seçilebilir olsa da pratikte
    // ULAŞILAMAZDI. Ad birebir eşleşiyorsa tür ne olursa olsun başa gelir.
    final kucuk = sorgu.toLowerCase();
    liste.sort((a, b) {
      int puan(dynamic r) {
        final ad = ((r['name'] ?? r['title']) as String? ?? '').toLowerCase();
        return ad == kucuk ? 0 : 1;
      }

      return puan(a) - puan(b);
    });
    setState(() {
      _sonuclar = liste;
      _arandi = true;
      _araniyor = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final olcum = MediaQuery.of(context);
    final klavye = olcum.viewInsets.bottom;
    // YÜKSEKLİK: ekranın %75'i AMA durum çubuğu + klavye düşüldükten sonra
    // kalan alanı ASLA aşmaz. Eskiden düz `size.height * 0.75` idi ve
    // klavye açıkken (kutu autofocus) sheet yukarı itilip telefonun üst
    // çubuğunun İÇİNE giriyordu (kullanıcı, 3 Eyl 2026: *"yapım ara çok
    // yukarıya çıkıyor, telefonun üstündeki barın içine kadar gidiyor"*).
    // Alt pay klavye kadar: liste klavyenin ÜSTÜNDE kalır.
    final kullanilabilir = olcum.size.height - olcum.padding.top - klavye - 12;
    final yukseklik = (olcum.size.height * 0.75).clamp(
      0.0,
      kullanilabilir.clamp(200.0, double.infinity),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: klavye),
      child: SizedBox(
        key: const Key('icerik-sec-govde'),
        height: yukseklik,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _arama,
                autofocus: true,
                onChanged: _degisti,
                decoration: InputDecoration(
                  hintText: widget.kisiVeFirma
                      ? 'Yapım ara...'.c
                      : 'Dizi veya film ara...'.c,
                  prefixIcon: Icon(Icons.search, color: DiziRenkler.metin),
                ),
              ),
            ),
            if (_araniyor)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (_gecmisKipi && _gecmis.isNotEmpty)
              Expanded(child: _gecmisListesi())
            else if (_sonuclar.isEmpty && !_araniyor)
              Expanded(child: _bosDurum())
            else
              Expanded(
                child: ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: _sonuclar.length,
                  itemBuilder: (context, i) =>
                      _satir(_sonuclar[i] as Map<String, dynamic>),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bosDurum() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _arandi ? Icons.search_off : Icons.search,
              size: 38,
              color: DiziRenkler.metin24,
            ),
            const SizedBox(height: 10),
            Text(
              _arandi
                  ? 'Bulunamadı. Adın yazılışını değiştirip dene.'.c
                  : 'Dizi, film, oyuncu, yönetmen ya da yapım firması ara.'.c,
              textAlign: TextAlign.center,
              style: TextStyle(color: DiziRenkler.metin54, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  /// "Son aradıkların" başlığı + temizle + kayıtlar.
  Widget _gecmisListesi() {
    return ListView.builder(
      key: const Key('etiket-gecmisi'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _gecmis.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Son aramalar'.c,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: DiziRenkler.metin54,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('etiket-gecmisi-temizle'),
                  onPressed: _gecmisiTemizle,
                  child: Text(
                    'Temizle'.c,
                    style: TextStyle(fontSize: 12, color: DiziRenkler.metin54),
                  ),
                ),
              ],
            ),
          );
        }
        return _satir(_gecmis[i - 1]);
      },
    );
  }

  /// Tek kayıt satırı — arama sonucu ve geçmiş AYNI çizimi kullanır.
  Widget _satir(Map<String, dynamic> r) {
    final tur = r['media_type'] as String?;
    final gorsel = posterUrl(tmdbGorselYolu(r), boyut: 'w92');
    final ilgili = r['ilgili'] as String?;
    // Geçmişteki ilgili kayıt: "Breaking Bad · Oyuncu" — neyin parçası
    // olduğu görünsün, yoksa liste rastgele adlarla dolu sanılır.
    final altYazi = ilgili == null
        ? tmdbTurEtiketi(tur)
        : '$ilgili · ${_rolEtiketi(r['rol'] as String?) ?? tmdbTurEtiketi(tur)}';
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 34,
          height: 50,
          color: DiziRenkler.kart,
          child: gorsel == null
              ? Icon(_turIkonu(tur), size: 18, color: DiziRenkler.metin38)
              : CachedNetworkImage(
                  imageUrl: gorsel,
                  httpHeaders: gorselBasliklari(gorsel),
                  // Firma logosu şeffaf ve GENİŞ: `cover` onu kırpıp
                  // tanınmaz hâle getirirdi.
                  fit: tur == 'company' ? BoxFit.contain : BoxFit.cover,
                ),
        ),
      ),
      title: Text(
        (r['name'] ?? r['title'] ?? '?') as String,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        altYazi,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: DiziRenkler.metin38),
      ),
      onTap: () => _sec(r),
    );
  }

  static String? _rolEtiketi(String? rol) => switch (rol) {
    'firma' => 'Yapım firması'.c,
    'yaratici' => 'Yaratıcı'.c,
    'yonetmen' => 'Yönetmen'.c,
    'oyuncu' => 'Oyuncu'.c,
    _ => null,
  };
}

/// Seçiciyi alt sayfada açar; seçilen TMDB kaydını döndürür.
///
/// [kisiVeFirma] `false` iken yalnız dizi/film listelenir (sohbette içerik
/// paylaşımı böyle çağırır).
Future<Map<String, dynamic>?> icerikSecAc(
  BuildContext context, {
  bool kisiVeFirma = true,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    // Üst güvenli alan: sheet ne olursa olsun durum çubuğuna girmez
    // (yükseklik hesabı zaten düşüyor; bu ikinci emniyet).
    useSafeArea: true,
    backgroundColor: DiziRenkler.koyuGri,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => IcerikSecSheet(kisiVeFirma: kisiVeFirma),
  );
}
