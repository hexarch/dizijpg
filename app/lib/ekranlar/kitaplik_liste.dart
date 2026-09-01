import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../ceviri.dart';
import '../liste_gorunumu.dart';
import '../tema.dart';
import 'izlem_carki.dart';
import 'ortak.dart';
import 'paylas.dart';
import 'siralanabilir_izgara.dart';

/// Bir kitaplık durumunun (izliyorum/bitirdim/...) TAM listesi, dikey ızgara.
///
/// SIRALAMA (21 Ağu 2026): afişler basılı tutulup sürüklenerek yeniden
/// dizilebilir; sıra sunucuda `kitaplik_sirasi` tablosunda tutulur. Durum
/// anahtarı ([widget.durum]) sunucudaki liste anahtarıyla AYNI dizgedir
/// (izliyorum/izleyecegim/bitirdim/biraktim) — ayrı eşleme tablosu yok.
class KitaplikListesiEkrani extends StatefulWidget {
  final String durum;

  const KitaplikListesiEkrani({super.key, required this.durum});

  @override
  State<KitaplikListesiEkrani> createState() => _KitaplikListesiEkraniState();
}

class _KitaplikListesiEkraniState extends State<KitaplikListesiEkrani> {
  List<dynamic>? _ogeler;
  Map<String, int> _sayilar = {}; // 'tur:id' → izlenen bölüm
  String? _hata;

  /// Sıralama kipi: süzgeç + "en üste taşı" düğmeleri. Sürükle-bırak bu
  /// kipten BAĞIMSIZ, her zaman açık (kullanıcı "listeye girdiğimde basılı
  /// tutup sürükleyebilmeliyim" dedi).
  bool _siralama = false;

  static const _adlar = {
    'izliyorum': 'İzliyorum',
    'izleyecegim': 'İzleyeceğim',
    'bitirdim': 'Bitirdim',
    'biraktim': 'Bıraktım',
  };

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      final sonuclar = await Future.wait([
        Api.get('/kitapligim'),
        Api.get('/izlediklerim'),
      ]);
      if (!mounted) return;
      setState(() {
        _ogeler = (sonuclar[0]['durumlar'] as List<dynamic>)
            .where((d) => d['durum'] == widget.durum)
            .toList();
        _sayilar = {
          for (final o in (sonuclar[1]['ogeler'] as List<dynamic>))
            '${o['tur']}:${o['tmdb_id']}': (o['sayi'] as num?)?.toInt() ?? 0,
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_ogeler == null) {
      govde = GridView.builder(
        padding: EdgeInsets.fromLTRB(16, 16, 16, altGuvenli(context)),
        gridDelegate: const PosterIzgarasi(satirBoslugu: 14, bosluk: 10),
        itemCount: 9,
        itemBuilder: (_, __) => const IskeletKutu(genislik: double.infinity),
      );
    } else if (_ogeler!.isEmpty) {
      govde = BosDurum(
        ikon: Icons.video_library_outlined,
        baslik: 'Henüz izleme kaydın yok'.c,
        ipucu: 'İzlediğin dizi ve filmleri işaretledikçe burada toplanır.'.c,
      );
    } else {
      govde = SiralanabilirPosterIzgarasi(
        // Liste kimliği DEĞİŞİRSE (yenileme, sıfırlama) alt widget taze
        // listeyi alsın diye `ogeler` doğrudan geçiliyor.
        ogeler: _ogeler!,
        liste: widget.durum,
        siralamaKipi: _siralama,
        izlenenSayi: (o) => _sayilar['${o['tur']}:${o['tmdb_id']}'],
        onYenile: _yukle,
      );
    }

    final ben = context.watch<Oturum>().kullanici;
    final benimAd = ben?['kullanici_adi'] as String?;
    return Scaffold(
      appBar: AppBar(
        // Ad geri okuna yaslanır (1 Eyl 2026 isteği: "sol taraftaki oka
        // yanaştır") — [IzlenenlerEkrani] ile aynı hizalama.
        titleSpacing: 0,
        // Sayı İKİNCİ SATIRDA (31 Ağu 2026): "İzleyeceğim (182)" tek satırda
        // yanındaki 2-3 eylem ikonuyla dar telefonda sığmıyor, ellipsis sayıyı
        // yutup "İzleyeceğim (…" bırakıyordu — kullanıcı "(.. neyin nesi" dedi.
        // Liste tam sayfasındaki (liste.dart) ad + @sahip kalıbının aynısı.
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              (_adlar[widget.durum] ?? widget.durum).c,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_ogeler != null)
              Text(
                '{} içerik'.cf([_ogeler!.length]),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: DiziRenkler.metin54,
                ),
              ),
          ],
        ),
        actions: [
          // "Ne izlesem çarkı" — yalnız İzleyeceğim'de (23 Ağu 2026 isteği:
          // "İzleyeceğim yazısının yanında çark olsun"). Boş listede çizilmez:
          // ekran zaten BosDurum gösterir, boş çark çevirmek anlamsız.
          if (widget.durum == 'izleyecegim' && (_ogeler?.isNotEmpty ?? false))
            IconButton(
              key: const Key('izlem-carki'),
              tooltip: 'Ne izlesem?'.c,
              onPressed: () => izlemCarkiniAc(
                context,
                _ogeler!.cast<Map<String, dynamic>>(),
              ),
              icon: const Icon(Icons.attractions),
            ),
          // Paylaş (31 Ağu 2026 isteği: "otomatik listelerde paylaşma özelliği
          // yok, ekler misin"): bağlantı salt-okunur /kullanici/:ad/kitaplik/
          // :durum sayfasına gider. İzlenenler GİZLİYSE çizilmez — gizli özel
          // listedeki kuralın aynısı (paylas.dart): açılmayacak bağlantı
          // üretilmez. Boş listeyi paylaşmanın da anlamı yok.
          if (benimAd != null &&
              ben?['izlenenler_gizli'] != true &&
              (_ogeler?.isNotEmpty ?? false))
            IconButton(
              key: const Key('kitaplik-paylas'),
              tooltip: 'Paylaş'.c,
              onPressed: () => paylasSheet(
                context,
                url:
                    'https://dizijpg.com/kullanici/$benimAd'
                    '/kitaplik/${widget.durum}',
                metin: (_adlar[widget.durum] ?? widget.durum).c,
              ),
              icon: Icon(Icons.ios_share, color: DiziRenkler.sariMetin),
            ),
          // GÖRÜNÜM ANAHTARI ayar çarkının SOLUNDA, ayrı bir ikon (1 Eyl 2026
          // isteği). Tek öğelik listede de anlamlı: görünüm bir tercih,
          // sıralama gibi "yeterince öğe olunca" açılan bir iş değil.
          if (_ogeler?.isNotEmpty ?? false) const ListeGorunumuDugmesi(),
          // Tek öğelik listede sıralamanın anlamı yok.
          //
          // İKON AYAR ÇARKI (1 Eyl 2026 isteği): çift yönlü ok, şeridin
          // yaptığı işi (süzgeç + sıfırlama) eksik anlatıyordu.
          if ((_ogeler?.length ?? 0) > 1)
            IconButton(
              key: const Key('kitaplik-sirala'),
              tooltip: _siralama ? 'Bitti'.c : 'Sırala'.c,
              onPressed: () => setState(() => _siralama = !_siralama),
              icon: Icon(_siralama ? Icons.check : Icons.settings),
            ),
        ],
      ),
      // PC'de ızgara ortalanmış ve [masaustuIcerikGenisligi] (1080) ile sınırlı
      // (madde 26); mobilde kısıt bağlamaz.
      body: OrtaKolon(azami: masaustuIcerikGenisligi, cocuk: govde),
    );
  }
}
