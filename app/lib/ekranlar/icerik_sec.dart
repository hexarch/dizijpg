import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
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

  @override
  void dispose() {
    _arama.dispose();
    _geciktirici?.cancel();
    super.dispose();
  }

  void _degisti(String q) {
    _geciktirici?.cancel();
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
      _araniyor = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
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
          Expanded(
            child: ListView.builder(
              itemCount: _sonuclar.length,
              itemBuilder: (context, i) {
                final r = _sonuclar[i] as Map<String, dynamic>;
                final tur = r['media_type'] as String?;
                final gorsel = posterUrl(tmdbGorselYolu(r), boyut: 'w92');
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 34,
                      height: 50,
                      color: DiziRenkler.kart,
                      child: gorsel == null
                          ? Icon(
                              _turIkonu(tur),
                              size: 18,
                              color: DiziRenkler.metin38,
                            )
                          : CachedNetworkImage(
                              imageUrl: gorsel,
                              httpHeaders: gorselBasliklari(gorsel),
                              // Firma logosu şeffaf ve GENİŞ: `cover` onu
                              // kırpıp tanınmaz hâle getirirdi.
                              fit: tur == 'company'
                                  ? BoxFit.contain
                                  : BoxFit.cover,
                            ),
                    ),
                  ),
                  title: Text(
                    (r['name'] ?? r['title'] ?? '?') as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    tmdbTurEtiketi(tur),
                    style: TextStyle(fontSize: 11, color: DiziRenkler.metin38),
                  ),
                  onTap: () => Navigator.pop(context, r),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
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
    backgroundColor: DiziRenkler.koyuGri,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => IcerikSecSheet(kisiVeFirma: kisiVeFirma),
  );
}
