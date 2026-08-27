import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../gorsel_basliklari.dart';
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
      // 28 Ağu 2026 — GERİ BİLDİRİM YANITI. Üçüncü aktörsüz tür: gönderen
      // SİTEDİR, bir kullanıcı değil; '@' kalıbına GİRMEZ.
      //
      // NEDEN VAR: yanıt bugüne kadar YALNIZ e-postayla gidiyordu, kullanıcı
      // mailini açmazsa haberi olmuyordu (üstelik mail hattında ölçülmüş
      // hatalar var). Artık zil de haber veriyor ve metin burada okunuyor.
      case 'geri_bildirim':
        return (
          Icons.mark_email_read_outlined,
          'Geri bildirimine yanıt verdik'.c,
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
            final aktorsuz =
                b['tur'] == 'bolum' ||
                b['tur'] == 'kisi' ||
                b['tur'] == 'geri_bildirim';
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
                      // Aynı yuvarlak ya TMDB posteri ya kendi sunucumuzdaki
                      // avatarı gösteriyor; WebP başlığının gerekip
                      // gerekmediğine ADRESE bakarak tek yerde karar veriliyor.
                      backgroundImage: avatar != null
                          ? CachedNetworkImageProvider(
                              avatar,
                              headers: gorselBasliklari(avatar),
                            )
                          : null,
                      child: avatar == null
                          ? Icon(switch (b['tur']) {
                              'bolum' => Icons.tv_outlined,
                              'kisi' => Icons.movie_outlined,
                              // Geri bildirim yanıtının posteri/avatarı YOK;
                              // kişi ikonu "biri bir şey yaptı" der ve
                              // yanıltırdı.
                              'geri_bildirim' => Icons.support_agent,
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
                // GERİ BİLDİRİM YANITI GİDİLECEK BİR SAYFA DEĞİL, OKUNACAK
                // BİR METİNDİR: rota yerine modal açılır (gönderi detayıyla
                // aynı kalıp). Ayrı bir ekran/rota açmak robots.txt ve derin
                // bağlantı tarafında bedel getirirdi; metin tek yerde yaşıyor.
                onTap: b['tur'] == 'geri_bildirim'
                    ? () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: DiziRenkler.koyuGri,
                        builder: (_) => _GeriBildirimYanitSheet(bildirim: b),
                      )
                    : switch (_hedef(b)) {
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

/// Geri bildirim yanıtının okunduğu modal (28 Ağu 2026).
///
/// NEDEN MODAL, NEDEN AYRI EKRAN DEĞİL: bu bir gezinilecek yüzey değil, tek
/// seferlik okunacak bir metin. Ayrı rota açmak robots.txt kuralı, derin
/// bağlantı ve `yonlendirme.dart` tablosu (SEO soft-404 testi bu tabloyu
/// kilitliyor) demek olurdu — hepsi okunacak iki paragraf için.
///
/// KULLANICININ KENDİ YAZDIĞI DA GÖSTERİLİR: yanıt aylar sonra gelebiliyor,
/// "neye cevap bu?" sorusu kalmasın. Mail gövdesinde de aynı disiplin var
/// (server.js, `/admin/geri-bildirim-yanit` alıntı bloğu).
class _GeriBildirimYanitSheet extends StatelessWidget {
  final Map<String, dynamic> bildirim;
  const _GeriBildirimYanitSheet({required this.bildirim});

  @override
  Widget build(BuildContext context) {
    final yanit = (bildirim['geri_bildirim_yanit'] as String? ?? '').trim();
    final soru = (bildirim['geri_bildirim_metin'] as String? ?? '').trim();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, kontrol) => ListView(
        controller: kontrol,
        padding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          altGuvenli(context, ekstra: 20),
        ),
        children: [
          Row(
            children: [
              const Icon(Icons.support_agent, color: DiziRenkler.sari),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Geri bildirimine yanıt verdik'.c,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Yanıt sunucudan gelmezse (geri bildirim silinmiş) boş bir kutu
          // göstermek yerine sebebi söylenir — sessiz boşluk yasak.
          Text(
            yanit.isNotEmpty ? yanit : 'Bu yanıt artık görüntülenemiyor.'.c,
            style: const TextStyle(height: 1.55, fontSize: 14),
          ),
          if (soru.isNotEmpty) ...[
            const SizedBox(height: 20),
            Divider(color: DiziRenkler.metin38.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              'Gönderdiğin geri bildirim'.c,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: DiziRenkler.metin54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              soru,
              style: TextStyle(
                height: 1.5,
                fontSize: 13,
                color: DiziRenkler.metin54,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
