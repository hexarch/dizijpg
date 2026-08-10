import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'ortak.dart';

/// GİZLENEN YORUMLAR — Ayarlar > Gizlilik > Gizlenen yorumlar.
///
/// Profil vitrininden çıkarılmış ("Bu yorumu profilimde gizle") yorumların
/// tek yönetim yeri. Yorumlar SİLİNMİŞ DEĞİLDİR: dizi/film/bölüm sayfasında,
/// akışta ve doğrudan bağlantıyla açıldıklarında hâlâ oradalar — burada
/// yalnızca "profilimde de görünsün" düğmesi var.
///
/// Liste tam kart çizmez: gizlenmiş bir gönderinin medyasını bu ekranda
/// otomatik oynatmak (ve beğeni/paylaş satırı sunmak) amacın tersi olurdu.
/// Satır = içerik adı + iki satır metin + tarih + "Tekrar göster".
class GizlenenYorumlarEkrani extends StatefulWidget {
  const GizlenenYorumlarEkrani({super.key});

  @override
  State<GizlenenYorumlarEkrani> createState() => _GizlenenYorumlarEkraniState();
}

class _GizlenenYorumlarEkraniState extends State<GizlenenYorumlarEkrani> {
  List<dynamic>? _yorumlar;
  Map<String, dynamic> _icerikler = {};
  String? _hata;

  /// Sunucu isteği süren yorumlar: çift dokunuş çift istek atmasın.
  final _isleniyor = <int>{};

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      final d = await Api.get('/gizlenen-yorumlar');
      if (!mounted) return;
      setState(() {
        _yorumlar = d['yorumlar'] as List<dynamic>? ?? [];
        _icerikler = d['icerikler'] as Map<String, dynamic>? ?? {};
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
    }
  }

  /// Tekrar göster: iyimser olarak listeden düşer, hata olursa GERİ GELİR.
  Future<void> _gosterr(Map<String, dynamic> y) async {
    final id = y['id'] as int;
    if (!_isleniyor.add(id)) return;
    final sira = _yorumlar!.indexOf(y);
    setState(() => _yorumlar!.remove(y));
    try {
      await Api.post('/yorumlar/$id/profilde-gizle', {'gizli': false});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yorum profilinde tekrar görünüyor'.c)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _yorumlar!.insert(sira, y),
      ); // iyimser güncellemeyi geri al
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      _isleniyor.remove(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_yorumlar == null) {
      govde = const Center(
        child: CircularProgressIndicator(color: DiziRenkler.sari),
      );
    } else if (_yorumlar!.isEmpty) {
      govde = BosDurum(
        ikon: Icons.visibility_off_outlined,
        baslik: 'Gizlenen yorumun yok'.c,
        ipucu:
            'Profilindeki Yorumlar sekmesinde bir gönderiye basılı tutup gizlediklerin burada birikir.'
                .c,
      );
    } else {
      govde = RefreshIndicator(
        color: DiziRenkler.sari,
        onRefresh: _yukle,
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(
            12,
            12,
            12,
            altGuvenli(context, ekstra: 24),
          ),
          itemCount: _yorumlar!.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final y = _yorumlar![i] as Map<String, dynamic>;
            return _GizliYorumSatiri(
              yorum: y,
              icerik:
                  _icerikler['${y['tur']}:${y['tmdb_id']}']
                      as Map<String, dynamic>?,
              isleniyor: _isleniyor.contains(y['id']),
              onGoster: () => _gosterr(y),
            );
          },
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('Gizlenen yorumlar'.c)),
      // PC'de akış ile AYNI ortalanmış okuma kolonu (madde 26); mobilde kısıt
      // bağlamaz.
      body: OrtaKolon(azami: masaustuKolonGenisligi, cocuk: govde),
    );
  }
}

class _GizliYorumSatiri extends StatelessWidget {
  final Map<String, dynamic> yorum;
  final Map<String, dynamic>? icerik;
  final bool isleniyor;
  final VoidCallback onGoster;

  const _GizliYorumSatiri({
    required this.yorum,
    required this.icerik,
    required this.isleniyor,
    required this.onGoster,
  });

  @override
  Widget build(BuildContext context) {
    final poster = posterUrl(icerik?['poster'] as String?, boyut: 'w185');
    final metin = (yorum['metin'] as String?) ?? '';
    final tarih = (yorum['tarih'] as String? ?? '').split('T').first;
    final spoiler = yorum['spoiler'] == true;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (poster != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 34,
                      height: 50,
                      child: CachedNetworkImage(
                        imageUrl: poster,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(color: DiziRenkler.kart),
                        errorWidget: (_, _, _) =>
                            Container(color: DiziRenkler.kart),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${icerik?['ad'] ?? '?'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: DiziRenkler.sariMetin,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        spoiler ? 'Spoiler içeren gönderi'.c : metin,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.35,
                          color: DiziRenkler.metin70,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tarih,
                        style: TextStyle(
                          fontSize: 11,
                          color: DiziRenkler.metin38,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              children: [
                // Gönderiye git: gizlenen yorum SİLİNMEDİ, hâlâ açılabiliyor —
                // kullanıcı neyi geri getireceğini görebilmeli.
                TextButton.icon(
                  onPressed: () => context.push('/gonderi/${yorum['id']}'),
                  icon: Icon(
                    Icons.open_in_new,
                    size: 16,
                    color: DiziRenkler.metin54,
                  ),
                  label: Text(
                    'Gönderiye git'.c,
                    style: TextStyle(
                      color: DiziRenkler.metin54,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: isleniyor ? null : onGoster,
                  icon: isleniyor
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.visibility_outlined,
                          size: 17,
                          color: DiziRenkler.sariMetin,
                        ),
                  label: Text(
                    'Tekrar göster'.c,
                    style: TextStyle(
                      color: DiziRenkler.sariMetin,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
