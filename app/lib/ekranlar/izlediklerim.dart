import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import '../liste_gorunumu.dart';
import '../tema.dart';
import 'ortak.dart';
import 'siralanabilir_izgara.dart';

/// Otomatik "İzlediklerim": izlenen tüm film ve dizilerin ızgarası.
/// Kendi verisini çeker (reload'da doğrudan açılabilir).
/// [tur] verilirse yalnız o tür listelenir ('tv' | 'movie').
///
/// SIRALAMA (21 Ağu 2026): "İzlediğim Diziler" ve "İzlediğim Filmler" de elle
/// sıralanabilir altı listeden ikisi — afişi basılı tutup sürükle.
/// TÜRSÜZ görünümde (tümü bir arada) SÜRÜKLEME yok ama sunucu elle sırayı
/// 1 Eyl 2026'dan beri BURADA DA uygular (tür başına önek-güvenli kırpma):
/// profildeki kapak kolajı bu beslemeden çizildiği için sona taşınan yapım
/// kapakta öne çıkıyordu (bkz. server.js `/izlediklerim`).
class IzlenenlerEkrani extends StatefulWidget {
  final String? tur;
  const IzlenenlerEkrani({super.key, this.tur});

  @override
  State<IzlenenlerEkrani> createState() => _IzlenenlerEkraniState();
}

class _IzlenenlerEkraniState extends State<IzlenenlerEkrani> {
  List<dynamic>? _ogeler;
  String? _hata;

  /// Sıralama kipi (süzgeç + "en üste taşı"). Sürükle-bırak bu kipten
  /// bağımsız, her zaman açık.
  bool _siralama = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      // Tür filtresini SUNUCUYA gönder: yerelde kırpılmış listeyi filtrelemek
      // yanlış sayı verirdi (215 dizi → 3 görünüyordu).
      final yol = widget.tur == null
          ? '/izlediklerim'
          : '/izlediklerim?tur=${widget.tur}';
      final d = await Api.get(yol);
      if (mounted) setState(() => _ogeler = d['ogeler'] as List<dynamic>);
    } catch (e) {
      if (mounted) setState(() => _hata = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final ogeler = _ogeler;

    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (ogeler == null) {
      // İskelet ızgara: bekleme yerine içerik şekli belirir (premium his)
      govde = GridView.builder(
        padding: EdgeInsets.fromLTRB(16, 16, 16, altGuvenli(context)),
        gridDelegate: const PosterIzgarasi(satirBoslugu: 16, bosluk: 12),
        itemCount: 9,
        itemBuilder: (_, __) => const IskeletKutu(
          genislik: double.infinity,
          yukseklik: double.infinity,
        ),
      );
    } else if (ogeler.isEmpty) {
      govde = BosDurum(
        ikon: Icons.movie_outlined,
        baslik: 'Henüz izleme kaydın yok'.c,
        ipucu: 'İzlediğin dizi ve filmleri işaretledikçe burada toplanır.'.c,
      );
    } else if (widget.tur == null) {
      govde = GridView.builder(
        padding: EdgeInsets.fromLTRB(16, 16, 16, altGuvenli(context)),
        gridDelegate: const PosterIzgarasi(satirBoslugu: 16, bosluk: 12),
        itemCount: ogeler.length,
        itemBuilder: (context, i) {
          final o = ogeler[i] as Map<String, dynamic>;
          return MiniIcerik(
            key: ValueKey('${o['tur']}-${o['tmdb_id']}'),
            tmdbId: o['tmdb_id'] as int,
            tur: o['tur'] as String,
            genislik: double.infinity,
            izlenenSayi: (o['sayi'] as num?)?.toInt(),
          );
        },
      );
    } else {
      govde = SiralanabilirPosterIzgarasi(
        ogeler: ogeler,
        liste: 'izlenen_${widget.tur}',
        siralamaKipi: _siralama,
        izlenenSayi: (o) => (o['sayi'] as num?)?.toInt(),
        onYenile: _yukle,
      );
    }

    // BAŞLIKTA SAYI YOK (1 Eyl 2026, kullanıcı isteği birebir: "izlediğim
    // dizilerin yanında (... bir şey yazıyor gözükmüyor, kaldır onu, sadece
    // listenin adı olsun ve sol taraftaki oka yanaştır").
    //
    // NE OLUYORDU: "İzlediğim Diziler (215)" tek satırda, sağındaki eylem
    // ikonuyla birlikte dar telefona sığmıyor; ellipsis tam sayının üstüne
    // düşüp geriye "İzlediğim Diziler (…" bırakıyordu — yani ekranı kaplayan
    // tek fazlalık, okunamayan bir parantezdi. Sayı zaten listenin kendisinde
    // görünüyor; `titleSpacing: 0` ile de ad geri okuna yaslandı.
    final baslik = widget.tur == 'movie'
        ? 'İzlediğim Filmler'
        : widget.tur == 'tv'
        ? 'İzlediğim Diziler'
        : 'İzlediklerim';
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(baslik.c, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          // GÖRÜNÜM ANAHTARI ayar çarkının SOLUNDA, ayrı bir ikon (1 Eyl 2026
          // isteği). Yalnız satır görünümünü çizebilen ekranda, yani tür
          // süzülmüş listede: türsüz "İzlediklerim" düz ızgaradır, düğme orada
          // hiçbir şey yapmazdı.
          if (widget.tur != null && (ogeler?.isNotEmpty ?? false))
            const ListeGorunumuDugmesi(),
          // Yalnız tür süzülmüş (sıralanabilir) listede ve en az iki öğede.
          //
          // İKON AYAR ÇARKI (1 Eyl 2026 isteği: "sağ tarafta yukarı aşağı ok
          // yerine setting ikonu koy, tıklayınca aynı ekran açılsın").
          if (widget.tur != null && (ogeler?.length ?? 0) > 1)
            IconButton(
              key: const Key('izlenen-sirala'),
              tooltip: _siralama ? 'Bitti'.c : 'Sırala'.c,
              onPressed: () => setState(() => _siralama = !_siralama),
              icon: Icon(_siralama ? Icons.check : Icons.settings),
            ),
        ],
      ),
      // PC'de ızgara ekranın tamamına yayılmasın: ortalanmış ve [masaustuIcerik
      // Genisligi] (1080) ile sınırlı — okuma kolonundan (720) geniş, çünkü
      // poster ızgarası 2 boyutlu ve dar kolonda sıkışır (madde 26/9). Sütun
      // sayısı ölçülen genişlikten türer ([PosterIzgarasi]); mobilde kısıt
      // bağlamaz, tam genişlik korunur.
      body: OrtaKolon(azami: masaustuIcerikGenisligi, cocuk: govde),
    );
  }
}
