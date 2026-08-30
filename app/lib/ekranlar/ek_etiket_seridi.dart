import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart' show posterUrl;
import '../ceviri.dart';
import '../gorsel_basliklari.dart';
import '../tema.dart';

// PAYLAŞILAN BİLEŞEN (30 Ağu 2026). Önce `akis.dart` içinde özeldi; gönderi
// kartının ek etiket şeridi YALNIZ akışta çiziliyordu. Kullanıcı bildirimi:
// "oyuncu etiketli yorum paylaştım ama profilimdeki yorumlar kısmında ve
// dizinin sayfasında oyuncunun etiketini göremiyorum." Profil `AkisKarti`
// kullandığı için oradaki eksik SUNUCU tarafındaydı; içerik sayfasının kendi
// kartı (`YorumKarti`) ise şeridi hiç çizmiyordu. Kopyalamak yerine buraya
// taşındı — iki kopya, ilk düzeltmede tek yerde kalırdı.

/// GÖNDERİNİN EK ETİKETLERİ — birincisi başlıkta, kalanları burada.
///
/// KULLANICI İSTEĞİ (30 Ağu 2026): "mesela Silo ve Breaking Bad'i seçersem
/// ikisinin de profilinde paylaşılacak". Gönderi sunucuda ikisinin de
/// sayfasında listeleniyor; KARTTA da ikisinin görünmesi gerekiyor, yoksa
/// kullanıcı ikinci etiketi ekledikten sonra hiçbir yerde göremez ve
/// "eklenmedi mi?" diye tekrar dener.
///
/// YATAY KAYDIRILIR, sarmalanmaz: kart yüksekliği etiket sayısıyla
/// zıplamasın (akışta kaydırma sırasında en rahatsız edici şey budur).
/// Web'de fare ile sürüklenebilir — [FareKaydirma] MaterialApp seviyesinde.
class EkEtiketSeridi extends StatelessWidget {
  final List<Map<String, dynamic>> etiketler;
  final Map<String, dynamic> icerikler;

  const EkEtiketSeridi({
    super.key,
    required this.etiketler,
    required this.icerikler,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
        itemCount: etiketler.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final e = etiketler[i];
          final tur = e['tur'] as String?;
          final id = e['tmdb_id'];
          final bilgi =
              icerikler['$tur:$id'] as Map<String, dynamic>? ??
              const {'ad': '?', 'poster': null};
          final sezon = e['sezon'] as int?;
          final bolum = e['bolum'] as int?;
          // Düzey soneki: bölüm > sezon > yok. Sezonun kendi sayfası YOK,
          // o yüzden sezon etiketi de dizi sayfasına gider (rozet yalnız
          // NEYİN etiketlendiğini söyler).
          final duzey = bolum != null
              ? '{}. sezon {}. bölüm'.cf(['$sezon', '$bolum'])
              : sezon != null
              ? '{}. sezon'.cf(['$sezon'])
              : '';
          final sonek = duzey.isEmpty ? '' : ' · $duzey';
          final yol = tur == 'person'
              ? '/kisi/$id'
              : bolum != null
              ? '/dizi/$id/sezon/$sezon/bolum/$bolum'
              : '/icerik/$tur/$id';
          final poster = posterUrl(bilgi['poster'] as String?, boyut: 'w92');
          return InkWell(
            borderRadius: BorderRadius.circular(17),
            onTap: () => GoRouter.of(context).push(yol),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 230),
              padding: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: DiziRenkler.kart,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(3),
                    child: ClipOval(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: poster == null
                            ? Container(
                                color: DiziRenkler.acikGri,
                                child: Icon(
                                  tur == 'person'
                                      ? Icons.person
                                      : tur == 'company'
                                      ? Icons.business
                                      : Icons.movie_outlined,
                                  size: 14,
                                  color: DiziRenkler.metin38,
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: poster,
                                httpHeaders: gorselBasliklari(poster),
                                fit: tur == 'company'
                                    ? BoxFit.contain
                                    : BoxFit.cover,
                              ),
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      '${bilgi['ad']}$sonek',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // Renk AÇIKÇA veriliyor: tema devralması yok (ux md.2).
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: DiziRenkler.sariMetin,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
