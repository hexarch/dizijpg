import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'ortak.dart';

/// `/kullanici/:ad/kitaplik/:durum` — bir kullanıcının kitaplık listesinin
/// (İzliyorum / İzleyeceğim / Bitirdim / Bıraktım) SALT OKUNUR sayfası.
///
/// NEDEN VAR (31 Ağu 2026): özel listeler paylaşılabiliyordu ama otomatik
/// kitaplık listelerinin paylaşılabilir bir sayfası hiç yoktu; kitaplık
/// ekranındaki paylaş düğmesi buraya bağlantı üretir. Rota bilerek OTURUM
/// İSTER: `/kullanici/...` yolları gizlilik tercihleri yüzünden herkese açık
/// değil (bkz. yonlendirme.dart `acikYolOnEkleri` açıklaması) — bu sayfa da
/// aynı çatının altında kalır. Sunucu `izlenenler_gizli` ve engellemeye göre
/// `gizli: true` döndürür; o durumda içerik değil kilit ekranı çizilir.
class KullaniciKitaplikEkrani extends StatefulWidget {
  final String kullaniciAdi;
  final String durum;

  const KullaniciKitaplikEkrani({
    super.key,
    required this.kullaniciAdi,
    required this.durum,
  });

  @override
  State<KullaniciKitaplikEkrani> createState() =>
      _KullaniciKitaplikEkraniState();
}

class _KullaniciKitaplikEkraniState extends State<KullaniciKitaplikEkrani> {
  List<dynamic>? _ogeler;
  bool _gizli = false;
  String? _hata;

  // Kitaplık ekranıyla (kitaplik_liste.dart) AYNI adlar — durum anahtarı
  // sunucudaki liste anahtarıyla birebir.
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
      final d = await Api.get(
        '/profil/${Uri.encodeComponent(widget.kullaniciAdi)}'
        '/kitaplik/${widget.durum}',
      );
      if (!mounted) return;
      setState(() {
        _gizli = d['gizli'] == true;
        _ogeler = (d['ogeler'] as List<dynamic>?) ?? [];
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
    } else if (_gizli) {
      govde = BosDurum(
        ikon: Icons.lock_outline,
        baslik: 'Bu liste gizli'.c,
        ipucu: 'Bu kullanıcı izleme listelerini gizli tutmayı tercih ediyor.'.c,
      );
    } else if (_ogeler!.isEmpty) {
      govde = BosDurum(
        ikon: Icons.video_library_outlined,
        baslik: 'Bu listede henüz içerik yok'.c,
      );
    } else {
      govde = GridView.builder(
        padding: EdgeInsets.fromLTRB(16, 16, 16, altGuvenli(context)),
        gridDelegate: const PosterIzgarasi(satirBoslugu: 14, bosluk: 10),
        itemCount: _ogeler!.length,
        itemBuilder: (context, i) {
          final o = _ogeler![i] as Map<String, dynamic>;
          return MiniIcerik(
            key: ValueKey('${o['tur']}:${o['tmdb_id']}'),
            tmdbId: (o['tmdb_id'] as num).toInt(),
            tur: o['tur'] as String,
            genislik: double.infinity,
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        // Kitaplık ekranıyla aynı başlık kalıbı: ad üstte, alt satırda sahibi.
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              (_adlar[widget.durum] ?? widget.durum).c,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '@${widget.kullaniciAdi}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: DiziRenkler.metin54,
              ),
            ),
          ],
        ),
      ),
      // PC'de ızgara ortalanmış ve [masaustuIcerikGenisligi] ile sınırlı —
      // kitaplık ekranıyla aynı (madde 26); mobilde kısıt bağlamaz.
      body: OrtaKolon(azami: masaustuIcerikGenisligi, cocuk: govde),
    );
  }
}
