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
  /// null = gidilecek geçerli bir yer yok (satır tıklanmaz).
  String? _hedef(Map<String, dynamic> b) {
    // Md. 27 — yeni bölüm bildiriminin AKTÖRÜ YOK (sistem üretir); hedefi
    // bölümün kendi sayfasıdır.
    if (b['tur'] == 'bolum') {
      return '/dizi/${b['tmdb_id']}/sezon/${b['sezon']}/bolum/${b['bolum']}';
    }
    // Md. 28 — favori kişinin yeni yapımı: hedef KİŞİ DEĞİL, YAPIMDIR.
    // Kullanıcı "yeni filmi çıkmış" diye dokunuyor; onu oyuncunun
    // filmografisine bırakmak bir adım fazladan iş demekti. (Kişinin id'si
    // satırda duruyor — ileride "kişiye git" eylemi eklenebilir.)
    if (b['tur'] == 'kisi') {
      // `icerik_tur` OLMADAN adres kurulamaz (TMDB'de dizi 1396 ≠ film 1396);
      // beklenmedik bir değerde yanlış sayfa açmaktansa bu satır tıklanınca
      // hiçbir yere gitmesin — push tarafındaki [bildirimHedefi] ile aynı kural.
      final t = b['icerik_tur'];
      if (t == 'tv' || t == 'movie') return '/icerik/$t/${b['tmdb_id']}';
      return null;
    }
    if (b['tur'] == 'mesaj') return '/sohbet/${b['aktor']}';
    final yorumId = b['yorum_id'];
    // yorum silinmişse (JOIN'de yorum_tur null) gönderi 404 verir → profile git
    final silinmis = b['yorum_tur'] == null;
    if (yorumId != null && !silinmis) {
      return gonderiYolu('$yorumId', yanit: b['tur'] == 'yanit');
    }
    return '/kullanici/${b['aktor']}';
  }

  /// "S5B3" etiketi — `S{}B{}` anahtarı ZATEN VAR (bölüm yorumlarında
  /// kullanılıyor), yeni çeviri anahtarı açılmadı.
  String _sezonBolum(Map<String, dynamic> b) =>
      'S{}B{}'.cf([b['sezon'], b['bolum']]);

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
      case 'bolum':
        // Aktörsüz bildirim: "@" ile başlayan kalıba GİRMEZ, dizi adını yazar.
        // Dizi adı sunucudan gelmezse (TMDB önbelleği ıskaladı) sayı biçimi
        // tek başına anlamlı kalsın diye ad yerine "Yeni bölüm" denir.
        return (
          Icons.new_releases_outlined,
          (b['dizi_adi'] as String?)?.isNotEmpty == true
              ? '{} {} yayınlandı'.cf([b['dizi_adi'], _sezonBolum(b)])
              : 'Yeni bölüm yayınlandı'.c,
        );
      case 'kisi':
        // Md. 28 — aktörsüz ikinci tür. Adlar TMDB'den gelir ve KULLANICI ADI
        // DEĞİLDİR: "@" kalıbına GİRMEZ. Sunucu TMDB'den ad çekemediyse
        // (önbellek ıskaladı) yarım cümle basmak yerine yedek metin yazılır.
        final kisiAdi = b['kisi_adi'] as String?;
        final yapimAdi = b['yapim_adi'] as String?;
        return (
          Icons.theaters_outlined,
          (kisiAdi?.isNotEmpty == true && yapimAdi?.isNotEmpty == true)
              ? '{} yeni bir yapımda: {}'.cf([kisiAdi, yapimAdi])
              : 'Favori kişinden yeni yapım'.c,
        );
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
            // AKTÖRSÜZ TÜRLERDE ('bolum' md.27, 'kisi' md.28) avatar yerine
            // YAPIMIN POSTERİ durur; kişi ikonu koymak "biri bir şey yaptı"
            // der ve yanıltıcı olurdu.
            final aktorsuz = b['tur'] == 'bolum' || b['tur'] == 'kisi';
            final avatar = aktorsuz
                ? posterUrl(b['poster'] as String?, boyut: 'w185')
                : dosyaUrl(b['aktor_avatar'] as String?);
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
                          ? Icon(switch (b['tur']) {
                              'bolum' => Icons.tv_outlined,
                              'kisi' => Icons.movie_outlined,
                              _ => Icons.person,
                            }, color: DiziRenkler.metin38)
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
                // Hedefi olmayan satır TIKLANMAZ (onTap null → dalga da yok):
                // "dokundum, hiçbir şey olmadı" hissi vermek yerine satır
                // baştan etkileşimsiz görünsün.
                onTap: switch (_hedef(b)) {
                  final String yol => () => context.push(yol),
                  _ => null,
                },
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
