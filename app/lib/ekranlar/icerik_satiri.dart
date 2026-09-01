import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../gorsel_basliklari.dart';
import '../icerik_deposu.dart';
import '../puan.dart';
import '../puan_favori_deposu.dart';
import '../tema.dart';

/// Kitaplık listelerinin SATIR görünümündeki tek satır (1 Eyl 2026 isteği).
///
/// Kullanıcı isteği birebir: *"satır satır görünüme geçecek ve sol tarafta
/// dizi afişi, yanında adı, adın yanında yılı, yıl ve adın altında kullanıcının
/// verdiği puan ve favori dizi veya filmi ise kırmızı kalp"*.
///
/// Ad/yıl [IcerikDeposu]'ndan (toplu `POST /icerikler`), puan ve kalp
/// [PuanFavoriDeposu]'ndan gelir — satır başına AĞ İSTEĞİ YOKTUR.
///
/// YIL ESKİ SUNUCUDA YOK: `yil` alanı 1 Eyl 2026'da eklendi. Gelmezse satır
/// yılsız çizilir; boş parantez ya da "(...)" BASILMAZ — kullanıcının
/// başlıklarda şikâyet ettiği tam olarak buydu.
class IcerikSatiri extends StatefulWidget {
  final String tur;
  final int tmdbId;

  /// Sağ uçta çizilecek ek eylem (sıralama kipinde "en üste taşı").
  final Widget? sonEk;

  const IcerikSatiri({
    super.key,
    required this.tur,
    required this.tmdbId,
    this.sonEk,
  });

  @override
  State<IcerikSatiri> createState() => _IcerikSatiriState();
}

class _IcerikSatiriState extends State<IcerikSatiri> {
  Map<String, dynamic>? _icerik;
  bool _hata = false;

  @override
  void initState() {
    super.initState();
    _getir();
  }

  @override
  void didUpdateWidget(IcerikSatiri eski) {
    super.didUpdateWidget(eski);
    // Liste kısalınca eleman geri dönüşümü eski içeriği taşır (MiniIcerik'te
    // yaşanan md. 47 hatasının aynısı) — kimlik değiştiyse yeniden çek.
    if (eski.tur != widget.tur || eski.tmdbId != widget.tmdbId) {
      setState(() {
        _icerik = null;
        _hata = false;
      });
      _getir();
    }
  }

  void _getir() {
    final tur = widget.tur;
    final id = widget.tmdbId;
    IcerikDeposu.getir(tur, id).then((d) {
      if (!mounted || tur != widget.tur || id != widget.tmdbId) return;
      setState(() => d == null ? _hata = true : _icerik = d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ad = (_icerik?['name'] ?? _icerik?['title']) as String?;
    final yil = (_icerik?['yil'] as String?)?.trim();
    final poster = posterUrl(_icerik?['poster_path'] as String?, boyut: 'w185');

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => context.push('/icerik/${widget.tur}/${widget.tmdbId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 46,
                height: 69, // 2:3 afiş oranı
                child: poster == null
                    ? ColoredBox(
                        color: DiziRenkler.kart,
                        child: Icon(
                          _hata ? Icons.broken_image_outlined : Icons.movie,
                          size: 20,
                          color: DiziRenkler.metin24,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: poster,
                        httpHeaders: gorselBasliklari(poster),
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            ColoredBox(color: DiziRenkler.kart),
                        errorWidget: (_, _, _) =>
                            ColoredBox(color: DiziRenkler.kart),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // AD + YIL aynı satırda. Ad uzunsa YIL DEĞİL AD kırpılır:
                  // yıl iki-üç karakter, kırpılınca hiçbir şey anlatmaz.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          ad ?? '…',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: ad == null
                                ? DiziRenkler.metin38
                                : DiziRenkler.metin,
                          ),
                        ),
                      ),
                      if (yil != null && yil.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          yil,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: DiziRenkler.metin38,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // PUAN + KALP. Depo değişince (satır görünümü açılırken
                  // tazelenir) kendini yeniler; ölçek değişirse de doğru
                  // yazsın diye [PuanOlcegi] ayrıca dinlenir.
                  ValueListenableBuilder<int>(
                    valueListenable: PuanFavoriDeposu.surum,
                    builder: (context, _, _) => ValueListenableBuilder<int>(
                      valueListenable: PuanOlcegi.deger,
                      builder: (context, olcek, _) {
                        final dbPuan = PuanFavoriDeposu.puan(
                          widget.tur,
                          widget.tmdbId,
                        );
                        final favori = PuanFavoriDeposu.favoriMi(
                          widget.tur,
                          widget.tmdbId,
                        );
                        // Ne puan ne favori: ikinci satır HİÇ çizilmez.
                        // (Satır yüksekliğini afiş belirlediği için liste
                        // düzeni bozulmaz — yalnız boş bir şerit basılmaz.)
                        if (dbPuan == null && !favori) {
                          return const SizedBox.shrink();
                        }
                        return Row(
                          children: [
                            if (dbPuan != null) ...[
                              Icon(
                                Icons.star,
                                size: 15,
                                color: DiziRenkler.sariMetin,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${yildiza(dbPuan, olcek: olcek)}/$olcek',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: DiziRenkler.sariMetin,
                                ),
                              ),
                            ],
                            if (favori) ...[
                              if (dbPuan != null) const SizedBox(width: 8),
                              Semantics(
                                label: 'Favori'.c,
                                child: const Icon(
                                  Icons.favorite,
                                  size: 15,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (widget.sonEk != null) widget.sonEk!,
          ],
        ),
      ),
    );
  }
}
