import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import '../yonlendirme.dart';
import 'ortak.dart';

/// Bildirimler: yanıt, beğeni, takip, mesaj. Açılınca tümü okundu sayılır.
class BildirimlerEkrani extends StatefulWidget {
  const BildirimlerEkrani({super.key});

  @override
  State<BildirimlerEkrani> createState() => _BildirimlerEkraniState();
}

class _BildirimlerEkraniState extends State<BildirimlerEkrani> {
  List<dynamic>? _bildirimler;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      final d = await Api.get('/bildirimler');
      if (!mounted) return;
      // Hafif gruplama: aynı yoruma art arda gelen aynı tür bildirimler
      // tek satıra iner, "+N" eklenir.
      final ham = d['bildirimler'] as List<dynamic>;
      final grupsuz = <Map<String, dynamic>>[];
      for (final b in ham) {
        final m = Map<String, dynamic>.from(b as Map<String, dynamic>);
        final onceki = grupsuz.isNotEmpty ? grupsuz.last : null;
        if (onceki != null &&
            onceki['tur'] == m['tur'] &&
            m['yorum_id'] != null &&
            onceki['yorum_id'] == m['yorum_id']) {
          onceki['ek'] = ((onceki['ek'] as int?) ?? 0) + 1;
          if (m['okundu'] == false) onceki['okundu'] = false;
        } else {
          grupsuz.add(m);
        }
      }
      setState(() => _bildirimler = grupsuz);
      Api.post('/bildirimler/okundu', {}).catchError((_) => null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
    }
  }

  /// Bildirimin götüreceği yer:
  ///  - mesaj → sohbet
  ///  - beğeni/yanıt/etiket (yorum_id var) → doğrudan O GÖNDERİYE (/gonderi/:id)
  ///    (eskiden yalnız yorumun içeriğine/dizisine gidiyordu; hedef yorumu
  ///    bulmak zordu)
  ///  - yorumsuz (takip) → aktörün profili
  ///  - YANIT bildiriminde adrese `?yanit=1` eklenir; bkz. [gonderiYolu].
  String _hedef(Map<String, dynamic> b) {
    if (b['tur'] == 'mesaj') return '/sohbet/${b['aktor']}';
    final yorumId = b['yorum_id'];
    // yorum silinmişse (JOIN'de yorum_tur null) gönderi 404 verir → profile git
    final silinmis = b['yorum_tur'] == null;
    if (yorumId != null && !silinmis) {
      return gonderiYolu('$yorumId', yanit: b['tur'] == 'yanit');
    }
    return '/kullanici/${b['aktor']}';
  }

  (IconData, String) _gorunum(Map<String, dynamic> b) {
    switch (b['tur'] as String?) {
      case 'yanit':
        return (Icons.reply, '@{} yorumuna yanıt verdi'.cf([b['aktor']]));
      case 'etiket':
        return (
          Icons.alternate_email,
          '@{} bir yorumda seni etiketledi'.cf([b['aktor']]),
        );
      case 'begeni':
        return (Icons.favorite, '@{} yorumunu beğendi'.cf([b['aktor']]));
      case 'takip':
        return (Icons.person_add, '@{} seni takip etti'.cf([b['aktor']]));
      case 'mesaj':
        return (Icons.mail, '@{} sana mesaj gönderdi'.cf([b['aktor']]));
      default:
        return (Icons.notifications, '@${b['aktor']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_bildirimler == null) {
      govde = const IskeletListe();
    } else if (_bildirimler!.isEmpty) {
      govde = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none,
              size: 44,
              color: DiziRenkler.metin24,
            ),
            const SizedBox(height: 10),
            Text(
              'Henüz bildirim yok'.c,
              style: TextStyle(color: DiziRenkler.metin54),
            ),
          ],
        ),
      );
    } else {
      govde = RefreshIndicator(
        color: DiziRenkler.sari,
        onRefresh: _yukle,
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(12, 12, 12, altGuvenli(context)),
          itemCount: _bildirimler!.length,
          itemBuilder: (context, i) {
            final b = _bildirimler![i] as Map<String, dynamic>;
            final (ikon, metin) = _gorunum(b);
            final avatar = dosyaUrl(b['aktor_avatar'] as String?);
            final tarih = (b['tarih'] as String? ?? '').split('T').first;
            return Card(
              child: ListTile(
                leading: Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor: DiziRenkler.koyuGri,
                      backgroundImage: avatar != null
                          ? CachedNetworkImageProvider(avatar)
                          : null,
                      child: avatar == null
                          ? Icon(Icons.person, color: DiziRenkler.metin38)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 9,
                        backgroundColor: DiziRenkler.sari,
                        child: Icon(ikon, size: 11, color: Colors.black),
                      ),
                    ),
                  ],
                ),
                title: Text(
                  metin + (((b['ek'] as int?) ?? 0) > 0 ? '  +${b['ek']}' : ''),
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  tarih,
                  style: TextStyle(fontSize: 11, color: DiziRenkler.metin38),
                ),
                trailing: b['okundu'] == false
                    ? const CircleAvatar(
                        radius: 4,
                        backgroundColor: DiziRenkler.sari,
                      )
                    : null,
                onTap: () => context.push(_hedef(b)),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Bildirimler'.c)),
      // PC'de akış ile AYNI ortalanmış okuma kolonu (madde 26); mobilde kısıt
      // bağlamaz.
      body: OrtaKolon(azami: masaustuKolonGenisligi, cocuk: govde),
    );
  }
}
