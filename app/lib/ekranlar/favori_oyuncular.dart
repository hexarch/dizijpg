import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'ortak.dart';

/// ---------------------------------------------------------------------------
/// Favori oyuncular.
///
/// İSTEK (8 Ağu 2026): "Favori oyuncu listesi de olmalı, oraya favorilere
/// eklediği oyuncular olmalı."
///
/// NEDEN AYRI ROTA (profilde şerit değil):
///  * Profil ekranı zaten uzun (özet, kitaplık sekmeleri, rozetler, yorumlar);
///    her ziyarette favori oyuncuların TMDB'den çekilmesi profili yavaşlatırdı.
///    Ayrı rotada istek YALNIZ kullanıcı girince atılır.
///  * `/kitaplik/:durum` da tam olarak böyle çalışıyor (profilde giriş kartı,
///    liste ayrı sayfada) — kalıp tutarlı.
///  * Profil sekmesinin İÇİNDE (kabuk dalında): alt gezinme çubuğu kaybolmaz,
///    geri tuşu profile döner (dizijpg-ux-kontrol md.4).
///
/// YERLEŞİM: yuvarlak fotoğraf + altında ad ızgarası. `detay.dart` kadro
/// şeridiyle AYNI görsel dil (CircleAvatar + ad) — kullanıcı aynı nesneyi
/// iki ekranda aynı biçimde görür.
/// ---------------------------------------------------------------------------
class FavoriOyuncularEkrani extends StatefulWidget {
  const FavoriOyuncularEkrani({super.key});

  @override
  State<FavoriOyuncularEkrani> createState() => _FavoriOyuncularEkraniState();
}

class _FavoriOyuncularEkraniState extends State<FavoriOyuncularEkrani> {
  List<dynamic>? _kisiler;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() {
      _hata = null;
      _kisiler = null;
    });
    try {
      final d = await Api.get('/favori-kisiler');
      if (!mounted) return;
      setState(() => _kisiler = (d['kisiler'] as List<dynamic>?) ?? const []);
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
    } else if (_kisiler == null) {
      govde = GridView.builder(
        padding: EdgeInsets.fromLTRB(16, 16, 16, altGuvenli(context)),
        gridDelegate: _izgara,
        itemCount: 9,
        // Yuvarlak iskelet: gerçek kartta avatar daire, iskelet kare olsaydı
        // yükleme bitince şekil ZIPLARDI (yerleşim kayması hissi).
        itemBuilder: (_, _) => const Column(
          children: [
            ClipOval(child: IskeletKutu(genislik: 76, yukseklik: 76)),
            SizedBox(height: 8),
            IskeletKutu(genislik: 60, yukseklik: 10),
          ],
        ),
      );
    } else if (_kisiler!.isEmpty) {
      // Boş durum ASLA boş ekran değil: ne olduğu + NASIL doldurulacağı +
      // oraya götüren bir düğme (ui-ux-pro-max, Feedback/Empty States).
      govde = BosDurum(
        ikon: Icons.person_add_alt_1_outlined,
        baslik: 'Henüz favori oyuncun yok'.c,
        ipucu:
            'Bir oyuncunun sayfasını aç ve sağ üstteki kalbe dokun; buraya eklensin.'
                .c,
        aksiyon: FilledButton.icon(
          onPressed: () => context.push('/gozat'),
          icon: const Icon(Icons.explore_outlined, size: 18),
          label: Text('Gözat'.c),
        ),
      );
    } else {
      govde = GridView.builder(
        padding: EdgeInsets.fromLTRB(16, 16, 16, altGuvenli(context)),
        gridDelegate: _izgara,
        itemCount: _kisiler!.length,
        itemBuilder: (context, i) {
          final k = _kisiler![i] as Map<String, dynamic>;
          return FavoriOyuncuKarti(key: ValueKey(k['tmdb_id']), kisi: k);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Favori oyuncular'.c +
              (_kisiler != null ? ' (${_kisiler!.length})' : ''),
        ),
      ),
      // PC'de ızgara ortalanmış ve [masaustuIcerikGenisligi] (1080) ile sınırlı
      // (madde 26); mobilde kısıt bağlamaz.
      body: OrtaKolon(azami: masaustuIcerikGenisligi, cocuk: govde),
    );
  }

  /// 108 dp hedef genişlik: 76 dp avatar + iki satır ad rahat sığar; dar
  /// telefonda 3, geniş ekranda daha çok sütun çıkar (sabit sütun sayısı yok).
  static const _izgara = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 108,
    // 76 avatar + 8 boşluk + 40 ad (iki satır 12 px + pay). Ad `Expanded`
    // içinde: sistem yazı tipi büyütülse bile taşma yerine kırpma olur —
    // sarı-siyah taşma şeridi ASLA çıkmaz.
    mainAxisExtent: 76 + 8 + 40,
    crossAxisSpacing: 12,
    mainAxisSpacing: 16,
  );
}

/// Tek favori oyuncu: yuvarlak fotoğraf + ad.
class FavoriOyuncuKarti extends StatelessWidget {
  final Map<String, dynamic> kisi;

  const FavoriOyuncuKarti({super.key, required this.kisi});

  @override
  Widget build(BuildContext context) {
    final id = (kisi['tmdb_id'] as num?)?.toInt();
    final ad = (kisi['ad'] as String?)?.trim();
    final foto = posterUrl(kisi['poster'] as String?, boyut: 'w185');

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: id == null ? null : () => context.push('/kisi/$id'),
      child: Column(
        children: [
          CircleAvatar(
            radius: 38, // 76 dp — dokunma hedefi asgarisi 44'ün üstünde
            backgroundColor: DiziRenkler.kart,
            backgroundImage: foto == null
                ? null
                : CachedNetworkImageProvider(foto),
            child: foto == null
                ? Icon(Icons.person, color: DiziRenkler.metin24, size: 30)
                : null,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              ad?.isNotEmpty == true ? ad! : '#$id',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
