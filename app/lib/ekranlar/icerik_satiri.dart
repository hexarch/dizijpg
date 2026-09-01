import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../gorsel_basliklari.dart';
import '../icerik_deposu.dart';
import '../puan.dart';
import '../puan_favori_deposu.dart';
import '../tarih.dart';
import '../tema.dart';
import 'tepki.dart';

/// Kitaplık listelerinin SATIR görünümündeki tek satır (1 Eyl 2026 isteği).
///
/// Kullanıcı isteği birebir: *"satır satır görünüme geçecek ve sol tarafta
/// dizi afişi, yanında adı, adın yanında yılı, yıl ve adın altında kullanıcının
/// verdiği puan ve favori dizi veya filmi ise kırmızı kalp"* — ardından
/// *"izlenme tarihini de göster, dizilerde en son izlenen bölümün izlenme
/// tarihi olsun; verdiğim emojiyi de göster, dizilerde en çok kullandığım
/// 1 tane emojiyi göster"*.
///
/// Ad/yıl [IcerikDeposu]'ndan (toplu `POST /icerikler`); puan, kalp, son
/// izleme ve emoji [PuanFavoriDeposu]'ndan gelir — satır başına AĞ İSTEĞİ
/// YOKTUR.
///
/// İKİNCİ SATIR NEDEN [Wrap]: dört süs (puan · emoji · kalp · tarih) 360 dp
/// telefonda sağdaki "En üste taşı" düğmesiyle birlikte tek satıra
/// SIĞMAYABİLİR. Row olsaydı taşma çizgisi çıkardı; Wrap alta sarar ve hiçbir
/// bilgi kırpılmaz.
///
/// İLERLEME ÇUBUĞU YALNIZ DİZİDE (kullanıcı isteği: *"liste görünümünde de
/// bar koy, izleme yüzdesine göre dolsun ve altında yüzdeyi göster; tabii
/// filmlerde olmayacak ama dizilerde olacak"*). Filmde "izlenen/toplam" diye
/// bir oran yok — tek bölümlük bir şeyin çubuğu ya boş ya dolu olurdu, bilgi
/// taşımazdı. Kaynak afiş kartındakiyle ([MiniIcerik]) AYNI
/// (`izlenenSayi` / `number_of_episodes`); RENK KURALI ise burada farklı —
/// [DiziRenkler.ilerlemeRengi] rampası: az izlenen kırmızı, yarılanan sarı,
/// biten yeşil (kullanıcı isteği: "kırmızıdan yeşile gitsin, yeşilden
/// kırmızıya değil").
///
/// YIL ESKİ SUNUCUDA YOK: `yil` alanı 1 Eyl 2026'da eklendi. Gelmezse satır
/// yılsız çizilir; boş parantez ya da "(...)" BASILMAZ — kullanıcının
/// başlıklarda şikâyet ettiği tam olarak buydu.
class IcerikSatiri extends StatefulWidget {
  final String tur;
  final int tmdbId;

  /// Dizide izlenen bölüm sayısı — ilerleme çubuğunun payı. Filmde ANLAMSIZ
  /// olduğu için verilse bile çizilmez.
  final int? izlenenSayi;

  /// Sağ uçta çizilecek ek eylem (sıralama kipinde "en üste taşı").
  final Widget? sonEk;

  const IcerikSatiri({
    super.key,
    required this.tur,
    required this.tmdbId,
    this.izlenenSayi,
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
                        final emoji = PuanFavoriDeposu.emoji(
                          widget.tur,
                          widget.tmdbId,
                        );
                        final izleme = PuanFavoriDeposu.sonIzleme(
                          widget.tur,
                          widget.tmdbId,
                        );
                        // Hiçbiri yoksa ikinci satır HİÇ çizilmez.
                        // (Satır yüksekliğini afiş belirlediği için liste
                        // düzeni bozulmaz — yalnız boş bir şerit basılmaz.)
                        if (dbPuan == null &&
                            !favori &&
                            emoji == null &&
                            izleme == null) {
                          return const SizedBox.shrink();
                        }
                        return Wrap(
                          spacing: 8,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (dbPuan != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
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
                              ),
                            // EN ÇOK VERDİĞİN EMOJİ — projedeki tek tepki
                            // çizeri [TepkiIkonu] (Lottie, VARSAYILAN DURAĞAN:
                            // uzun listede 578 animasyon dönmez).
                            if (emoji != null)
                              Semantics(
                                // Yeni metin anahtarı AÇMADAN: 'Tepki verdin'
                                // 45 dilde ZATEN var ve etiket olarak birebir
                                // bunu anlatıyor.
                                label: 'Tepki verdin'.c,
                                child: TepkiIkonu(emoji, boyut: 15),
                              ),
                            if (favori)
                              Semantics(
                                label: 'Favori'.c,
                                child: const Icon(
                                  Icons.favorite,
                                  size: 15,
                                  color: Colors.redAccent,
                                ),
                              ),
                            // SON İZLEME. Sayısal biçim ([tarihSayi]) ve YIL
                            // DAİMA: dar satırda "20 Ocak 2008" yer yer, yıl
                            // ise yıllara yayılmış bir kitaplıkta ayırt edici.
                            if (izleme != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.event_available_outlined,
                                    size: 14,
                                    color: DiziRenkler.metin38,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    tarihSayi(izleme, hepYil: true),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: DiziRenkler.metin38,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  ..._ilerleme(),
                ],
              ),
            ),
            if (widget.sonEk != null) widget.sonEk!,
          ],
        ),
      ),
    );
  }

  /// DİZİ İLERLEMESİ: dolan çubuk + ALTINDA yüzde.
  ///
  /// Film: boş liste — filmde "kaç bölümünü izledin" diye bir soru yok.
  /// İzlenen 0 iken de çizilmez: "İzleyeceğim" listesinin TAMAMI %0 olurdu ve
  /// aynı sıfır her satırda tekrarlanınca bilgi değil gürültü olur (afiş
  /// kartındaki çubukta da 21 Ağu'dan beri aynı kural var).
  /// Toplam bölüm sayısı TMDB'den gelmezse (eski önbellek) de çizilmez —
  /// paydası olmayan bir yüzde uydurmak yalan olurdu.
  List<Widget> _ilerleme() {
    if (widget.tur != 'tv') return const [];
    final toplam = (_icerik?['number_of_episodes'] as num?)?.toInt() ?? 0;
    final izlenen = widget.izlenenSayi ?? 0;
    if (toplam <= 0 || izlenen <= 0) return const [];
    // TMDB'nin bölüm sayısı geriden gelebiliyor (yeni sezon henüz işlenmemiş):
    // izlenen > toplam olduğunda oran 1'i aşmasın, yüzde 100'ü geçmesin.
    final oran = (izlenen / toplam).clamp(0.0, 1.0).toDouble();
    // Görünür taban: %1'lik ilerleme bile bir çizgi bıraksın, "hiç
    // izlememişim" gibi durmasın. Yüzde YAZISI ham orandan gelir — çizgiyi
    // büyütmek sayıyı da büyütseydi ekranda yalan olurdu.
    final dolu = oran.clamp(0.03, 1.0);
    final ucRengi = DiziRenkler.ilerlemeRengi(oran);
    return [
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 5,
          width: double.infinity,
          child: ColoredBox(
            color: DiziRenkler.metin12,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: dolu,
                heightFactor: 1,
                child: DecoratedBox(
                  // RAMPANIN [0, oran] DİLİMİ — geçişin TAMAMI dolu kısma
                  // sıkıştırılmaz. Ayrım görünür: %20'lik bir çubuk baştan
                  // sona kırmızı olmalı, kendi içinde kırmızıdan yeşile
                  // geçmemeli. Ara durak (sarı) yalnız oran onu GEÇTİYSE
                  // eklenir ve durağı orana göre normalize edilir.
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                      colors: [
                        DiziRenkler.ilerlemeKirmizi,
                        if (oran > 0.5) DiziRenkler.ilerlemeSari,
                        ucRengi,
                      ],
                      stops: [0, if (oran > 0.5) 0.5 / oran, 1],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 2),
      Text(
        // '%{}' anahtarı CLDR'den çıkarıldı (tool/yuzde_kalibi.dart): de/fr/ru
        // "42 %", fa "٪42" — elle "%$n" yazmak 45 dilde yanlış olurdu.
        '%{}'.cf([(oran * 100).round()]),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          // Yazı çubuğun UCUYLA aynı renk: sayı ile çizgi aynı şeyi söyler.
          color: ucRengi,
        ),
      ),
    ];
  }
}
