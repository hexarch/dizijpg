import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'giris_istem.dart';
import 'ortak.dart';

/// ---------------------------------------------------------------------------
/// Bir oyuncunun yapımları + kullanıcının hangilerini izlediği.
///
/// İSTEK (8 Ağu 2026): "Tıklayınca da list view halinde solda dizi filmin
/// kapak resmi, yanında ismi ve en sağında tik işareti olmalı; izlemediklerinde
/// de çarpı."
///
/// NEDEN MODAL DEĞİL TAM SAYFA:
///  * Liste UZUN — popüler bir oyuncuda 100+ satır. Alt sayfada (bottom sheet)
///    o kadar içerik ya ekranın %90'ını kaplar (zaten tam sayfa) ya da iç
///    kaydırma dış kaydırmayla boğuşur.
///  * Satıra dokununca /icerik/... açılıyor. Modalden push edilen sayfadan geri
///    dönünce modal kapanmış olur, kullanıcı bağlamı kaybeder; tam sayfadan
///    geri dönüş listeye, oradan geri oyuncuya çıkar — yığın anlaşılır.
///  * DERİN BAĞLANTI (ui-ux-pro-max, Navigation/Deep Linking): kendi adresi
///    olan bir ekran web'de paylaşılabilir ve F5'te yerinde kalır. Modalın
///    adresi yoktur.
/// Projede ikisinin de örneği var (`ListeSheet` modal, `liste.dart` tam sayfa);
/// burada tam sayfa kalıbı seçildi.
/// ---------------------------------------------------------------------------
class KisiYapimlariEkrani extends StatefulWidget {
  final int kisiId;
  final String? kisiAdi;

  const KisiYapimlariEkrani({super.key, required this.kisiId, this.kisiAdi});

  @override
  State<KisiYapimlariEkrani> createState() => _KisiYapimlariEkraniState();
}

class _KisiYapimlariEkraniState extends State<KisiYapimlariEkrani> {
  List<dynamic>? _yapimlar;
  int _izlenen = 0;
  int _toplam = 0;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    if (!Api.girisli) return; // uç girisZorunlu; 401 istemeye gerek yok
    setState(() {
      _hata = null;
      _yapimlar = null;
    });
    try {
      final d = await Api.get('/kisi/${widget.kisiId}/izlenme');
      if (!mounted) return;
      setState(() {
        _yapimlar = (d['yapimlar'] as List<dynamic>?) ?? const [];
        _izlenen = (d['izlenen'] as num?)?.toInt() ?? 0;
        _toplam = (d['toplam'] as num?)?.toInt() ?? 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (!Api.girisli) {
      // KEMER VE ASKI: `/yapimlar/` korumalı bir kök yol olduğu için
      // yönlendirici oturumsuz ziyaretçiyi zaten `/giris`e atıyor. Bu dal,
      // `acikYolOnEkleri` ileride değişirse ekranın 401 hata görünümü değil
      // ne yapılacağını söyleyen bir hâl çizmesini garantiler.
      govde = BosDurum(
        ikon: Icons.lock_outline,
        // Mevcut anahtarlar kullanıldı ('Devam etmek için giriş yap',
        // 'Giriş Yap') — 45 dile yeni çeviri açmadan aynı cümleler.
        baslik: 'Devam etmek için giriş yap'.c,
        ipucu: 'İzlediklerin hesabına bağlı; bu liste yalnız sana özel.'.c,
        aksiyon: FilledButton(
          onPressed: () =>
              context.push(girisYolu('/yapimlar/${widget.kisiId}')),
          child: Text('Giriş Yap'.c),
        ),
      );
    } else if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_yapimlar == null) {
      govde = const IskeletListe(adet: 8);
    } else if (_yapimlar!.isEmpty) {
      govde = BosDurum(
        ikon: Icons.movie_outlined,
        baslik: 'Yapım bulunamadı'.c,
        ipucu: 'Bu kişinin listelenecek dizi veya filmi yok.'.c,
      );
    } else {
      govde = ListView.builder(
        padding: EdgeInsets.fromLTRB(12, 0, 12, altGuvenli(context)),
        // itemCount = başlık (1) + satırlar. Başlık listenin İÇİNDE: uzun
        // listede yukarı kaydırınca oranı da bırakır, ekran metrekaresini
        // sabit bir şeride vermez.
        itemCount: _yapimlar!.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return IzlenmeOzetSeridi(izlenen: _izlenen, toplam: _toplam);
          }
          final y = _yapimlar![i - 1] as Map<String, dynamic>;
          return YapimSatiri(
            // Kararlı anahtar: liste yeniden kurulunca satır durumu karışmasın.
            key: ValueKey('${y['tur']}:${y['tmdb_id']}'),
            yapim: y,
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.kisiAdi?.isNotEmpty == true ? widget.kisiAdi! : 'Yapımları'.c,
        ),
      ),
      // PC'de akış ile AYNI ortalanmış okuma kolonu (madde 26); mobilde kısıt
      // bağlamaz.
      body: OrtaKolon(azami: masaustuKolonGenisligi, cocuk: govde),
    );
  }
}

/// "10/20 izledin" özeti + ilerleme çubuğu.
///
/// ui-ux-pro-max (Feedback/Progress Indicators): ilerleme yalnız sayıyla değil
/// görsel bir çubukla da anlatılır — "10/20" okunmadan da doluluk görülür.
class IzlenmeOzetSeridi extends StatelessWidget {
  final int izlenen;
  final int toplam;

  const IzlenmeOzetSeridi({
    super.key,
    required this.izlenen,
    required this.toplam,
  });

  @override
  Widget build(BuildContext context) {
    final oran = toplam > 0 ? izlenen / toplam : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, size: 18, color: DiziRenkler.sariMetin),
              const SizedBox(width: 6),
              // Expanded: uzun çeviri + çok haneli sayılar dar ekranda
              // taşmak yerine ikinci satıra sarar.
              Expanded(
                child: Text(
                  '{} yapımdan {} tanesini izledin'.cf([toplam, izlenen]),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: oran,
              minHeight: 6,
              backgroundColor: DiziRenkler.metin12,
              valueColor: AlwaysStoppedAnimation(DiziRenkler.sari),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tek yapım satırı: solda kapak, ortada ad (+yıl), sağda tik/çarpı.
class YapimSatiri extends StatelessWidget {
  final Map<String, dynamic> yapim;

  const YapimSatiri({super.key, required this.yapim});

  @override
  Widget build(BuildContext context) {
    final izlendi = yapim['izlendi'] == true;
    final tur = yapim['tur'] as String? ?? 'tv';
    final tmdbId = (yapim['tmdb_id'] as num?)?.toInt();
    final ad = (yapim['ad'] as String?)?.trim();
    final yil = yapim['yil'] as String?;
    final kapak = posterUrl(yapim['poster'] as String?, boyut: 'w185');

    // İKİ SİNYAL, TEK RENK DEĞİL (ui-ux-pro-max, "asla yalnız renkle anlatma"):
    // izlendi ↔ dolu onay dairesi, izlenmedi ↔ çarpı. Renk körlüğünde de
    // ikonun ŞEKLİ ayırt ediyor; renk sadece pekiştiriyor.
    final durumIkonu = izlendi ? Icons.check_circle : Icons.close;
    // KONTRAST: çarpı ANLAM taşıyan bir grafik nesne, WCAG eşiği 3:1.
    // `metin38` (black38 → #9E9E9E beyaz üstünde 3,2:1) sınırı ancak geçiyordu;
    // `metin54` iki temada da ~3,9:1 verir. İzlenmemiş yine de sönük kalıyor,
    // görsel hiyerarşi bozulmuyor.
    final durumRengi = izlendi ? DiziRenkler.sariMetin : DiziRenkler.metin54;
    final durumEtiketi = izlendi ? 'İzledin'.c : 'İzlemedin'.c;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: tmdbId == null ? null : () => context.push('/icerik/$tur/$tmdbId'),
      child: Padding(
        // Satır yüksekliği = 66 (kapak) + 2x8 = 82 dp; dokunma hedefi
        // 44 dp'lik asgarinin çok üstünde.
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 66, // 2:3 poster oranı
                child: kapak == null
                    ? Container(
                        color: DiziRenkler.kart,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 18,
                          color: DiziRenkler.metin24,
                        ),
                      )
                    : CachedNetworkImage(imageUrl: kapak, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ad?.isNotEmpty == true ? ad! : '?',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      tur == 'tv' ? 'Dizi'.c : 'Film'.c,
                      if (yil != null && yil.isNotEmpty) yil,
                    ].join(' · '),
                    style: TextStyle(fontSize: 12, color: DiziRenkler.metin54),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Ekran okuyucu ikonu okuyamaz; durum metinle de söylenir.
            Semantics(
              label: durumEtiketi,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(durumIkonu, size: 22, color: durumRengi),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
