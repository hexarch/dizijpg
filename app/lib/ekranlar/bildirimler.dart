import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../aile_rozeti.dart';
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
      final ham = d['bildirimler'] as List<dynamic>;
      final grupsuz = <Map<String, dynamic>>[];
      // BEĞENİLER GÖNDERİ BAŞINA TEK SATIRA İNER (1 Eyl 2026 isteği: "her
      // gönderinin beğenisi ayrı satırda gözükmesin, son beğenenleri göster —
      // alcelik, melisa ve 10 kişi yorumunu beğendi gibi"). Ardışıklık ŞARTI
      // YOK: listenin neresinde olursa olsun aynı gönderinin beğenileri EN
      // YENİSİNİN yerinde toplanır. `begenenler` = [{ad, testci}] — sırası
      // yeniden eskiye; metinde ilk ikisi ad olarak yazılır.
      //
      // AYNI KİŞİ TEKRAR SAYILMAZ: beğen-vazgeç-beğen üç satır üretebiliyor;
      // adlar kümeyle teklenir, sayı GERÇEK kişi sayısıdır.
      final begeniGruplari = <Object, Map<String, dynamic>>{};
      final begenenAdlari = <Object, Set<String>>{};
      for (final b in ham) {
        final m = Map<String, dynamic>.from(b as Map<String, dynamic>);
        final yorumId = m['yorum_id'];
        if (m['tur'] == 'begeni' && yorumId != null) {
          final ad = m['aktor'] as String? ?? '';
          final grup = begeniGruplari[yorumId];
          if (grup != null) {
            if (begenenAdlari[yorumId]!.add(ad)) {
              (grup['begenenler'] as List).add({
                'ad': ad,
                'testci': m['aktor_testci'] == true,
              });
            }
            if (m['okundu'] == false) grup['okundu'] = false;
            continue;
          }
          m['begenenler'] = [
            {'ad': ad, 'testci': m['aktor_testci'] == true},
          ];
          begeniGruplari[yorumId] = m;
          begenenAdlari[yorumId] = {ad};
          grupsuz.add(m);
          continue;
        }
        // Diğer türlerde eski hafif gruplama sürer: aynı yoruma art arda
        // gelen aynı tür bildirimler tek satıra iner, "+N" eklenir.
        final onceki = grupsuz.isNotEmpty ? grupsuz.last : null;
        if (onceki != null &&
            onceki['tur'] == m['tur'] &&
            yorumId != null &&
            onceki['yorum_id'] == yorumId) {
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
    // Sürüm duyurusu (2 Eyl 2026): aktörsüz dördüncü tür, hedefi tanıtım
    // sayfası. Sürüm bozuksa satır tıklanmaz (yanlış rota açmaktansa).
    if (b['tur'] == 'surum') {
      final s = b['surum'] as String? ?? '';
      return RegExp(r'^\d+\.\d+\.\d+$').hasMatch(s) ? '/yenilikler/$s' : null;
    }
    // İzleme odası daveti (4 Eyl 2026): hedef ODANIN KENDİSİ. Aktörü var
    // (davet eden) ama profiline gitmek yanlış olurdu — kullanıcı "davet
    // edildim" diye dokunuyor, gitmek istediği yer oda.
    if (b['tur'] == 'oda_davet') {
      final id = b['oda_id'];
      // Oda 12 saat sonra siliniyor; id yoksa satır tıklanmaz. id varsa oda
      // kapanmış olsa bile açılır: ekran "Bu oda kapandı" boş durumunu çizer,
      // bu sessiz bir tıklamamadan daha dürüst.
      return id == null ? null : '/oda/$id';
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
        // Gruplu satır: son iki beğenen adla, kalanı sayıyla yazılır
        // ("@alcelik ve @melisa" / "@alcelik, @melisa ve 10 kişi").
        final grup = (b['begenenler'] as List?)?.cast<Map<String, dynamic>>();
        if (grup != null && grup.length == 2) {
          return (
            Icons.favorite,
            '{} ve {} yorumunu beğendi'.cf([
              '@${grup[0]['ad']}',
              '@${grup[1]['ad']}',
            ]),
          );
        }
        if (grup != null && grup.length > 2) {
          return (
            Icons.favorite,
            '{} ve {} kişi yorumunu beğendi'.cf([
              '@${grup[0]['ad']}, @${grup[1]['ad']}',
              grup.length - 2,
            ]),
          );
        }
        return (Icons.favorite, '@{} yorumunu beğendi'.cf([b['aktor']]));
      case 'takip':
        return (Icons.person_add, '@{} seni takip etti'.cf([b['aktor']]));
      case 'mesaj':
        return (Icons.mail, '@{} sana mesaj gönderdi'.cf([b['aktor']]));
      // 4 Eyl 2026 — İZLEME ODASI DAVETİ. Aktörlü tür: davet edenin avatarı
      // solda durur, köşedeki mini ikon eylemi anlatır.
      case 'oda_davet':
        return (
          Icons.groups_2_outlined,
          '@{} seni izleme odasına davet etti'.cf([b['aktor']]),
        );
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
      // 2 Eyl 2026 — SÜRÜM DUYURUSU. Aktörsüz dördüncü tür: gönderen SİTEDİR,
      // '@' kalıbına GİRMEZ. Dokununca /yenilikler/<surum> tanıtım sayfası.
      case 'surum':
        return (
          Icons.auto_awesome,
          'dizi.jpg {} yayında'.cf([b['surum'] ?? '']),
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

  /// Satırdaki aktör adları → aile rozeti var mı? Metin içindeki `@ad`
  /// geçişlerinin ardına mini tik konacak adların haritası.
  Map<String, bool> _rozetliAdlar(Map<String, dynamic> b) {
    final grup = (b['begenenler'] as List?)?.cast<Map<String, dynamic>>();
    if (grup != null) {
      return {
        for (final u in grup)
          if ((u['ad'] as String?)?.isNotEmpty == true)
            u['ad'] as String: u['testci'] == true,
      };
    }
    final ad = b['aktor'] as String?;
    if (ad == null || ad.isEmpty) return const {};
    return {ad: b['aktor_testci'] == true};
  }

  /// Bildirim metnini, rozetli aktör adlarının HEMEN ARDINA [MiniRozet]
  /// yerleştirerek çizer.
  ///
  /// AD ÇEVİRİDEN SONRA ARANIR, kalıptan önce değil: bazı dillerde ad cümlenin
  /// sonunda (ör. Arapça "…: @{}"), o yüzden "@ ile başlar" varsayımı YOK.
  /// Sınır kontrolü şart: aktör "ali" iken metindeki "@alican"a tik konmasın
  /// diye adın bittiği yerde kullanıcı adı karakteri (harf/rakam/._) devam
  /// ediyorsa eşleşme sayılmaz. Uzun ad önce denenir (@ali / @alican ikisi de
  /// satırdaysa doğru olanı kazansın).
  Widget _rozetliBaslik(String metin, Map<String, bool> rozetler) {
    final stil = TextStyle(fontSize: 14, color: DiziRenkler.metin);
    final adlar = rozetler.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final spans = <InlineSpan>[];
    var kalan = metin;
    while (adlar.isNotEmpty) {
      var enErken = -1;
      String? bulunan;
      for (final ad in adlar) {
        var i = kalan.indexOf('@$ad');
        while (i >= 0) {
          final son = i + 1 + ad.length;
          final devam = son < kalan.length ? kalan[son] : '';
          if (!RegExp(r'[A-Za-z0-9._]').hasMatch(devam)) break;
          i = kalan.indexOf('@$ad', i + 1);
        }
        if (i >= 0 && (enErken < 0 || i < enErken)) {
          enErken = i;
          bulunan = ad;
        }
      }
      if (bulunan == null) break;
      final son = enErken + 1 + bulunan.length;
      spans.add(TextSpan(text: kalan.substring(0, son)));
      if (rozetler[bulunan] == true) {
        spans.add(
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.only(left: 3),
              child: MiniRozet(),
            ),
          ),
        );
      }
      kalan = kalan.substring(son);
    }
    if (kalan.isNotEmpty) spans.add(TextSpan(text: kalan));
    // RichText tema rengini DEVRALMAZ (skill md. 2) — renk açıkça verilir.
    return Text.rich(TextSpan(style: stil, children: spans));
  }

  /// Satırın sağ ucu: okunmamış noktası + ilgili gönderinin mini görseli.
  /// İkisi de yoksa null (ListTile hiç yer ayırmaz).
  Widget? _sagUc(Map<String, dynamic> b) {
    final okunmamis = b['okundu'] == false;
    final medya = b['yorum_medya'] as String?;
    // Yorum silinmişse görsel de anlamsız (hedef zaten profile düşüyor).
    final silinmis = b['yorum_tur'] == null;
    String? url;
    if (medya != null && medya.isNotEmpty && !silinmis) {
      // Video kapağı sunucuda `<yol>.jpg` olarak hazır (video_kare.js);
      // fotoğraf olduğu gibi gösterilir.
      final video = medya.endsWith('.mp4') || medya.endsWith('.webm');
      url = dosyaUrl(video ? '$medya.jpg' : medya);
    }
    if (!okunmamis && url == null) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (okunmamis)
          const CircleAvatar(radius: 4, backgroundColor: DiziRenkler.sari),
        if (url != null) ...[
          if (okunmamis) const SizedBox(width: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CachedNetworkImage(
              imageUrl: url,
              httpHeaders: gorselBasliklari(url),
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              placeholder: (_, _) =>
                  Container(width: 44, height: 44, color: DiziRenkler.kart),
              // Kapak karesi henüz üretilmemiş eski bir video olabilir —
              // kırık görsel ikonu yerine sessizce boş kutu.
              errorWidget: (_, _, _) =>
                  Container(width: 44, height: 44, color: DiziRenkler.kart),
            ),
          ),
        ],
      ],
    );
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
                b['tur'] == 'geri_bildirim' ||
                b['tur'] == 'surum';
            final avatar = aktorsuz
                ? posterUrl(b['poster'] as String?, boyut: 'w185')
                : dosyaUrl(b['aktor_avatar'] as String?);
            final tarih = (b['tarih'] as String? ?? '').split('T').first;
            // KART YOK (1 Eyl 2026 isteği: "arka planla aynı renkte olsunlar,
            // tek parça olacak"): satır doğrudan sayfa zemininde durur.
            return ListTile(
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
              // Aile rozetli aktörlerin adının hemen ardına mini tik girer
              // (WidgetSpan) — metin akışı bozulmaz, satır kaydırmada tik
              // adıyla birlikte taşınır.
              title: _rozetliBaslik(
                metin + (((b['ek'] as int?) ?? 0) > 0 ? '  +${b['ek']}' : ''),
                _rozetliAdlar(b),
              ),
              subtitle: Text(
                tarih,
                style: TextStyle(fontSize: 11, color: DiziRenkler.metin38),
              ),
              // Sağ uç: okunmamış noktası + ilgili gönderinin mini görseli
              // (1 Eyl 2026 isteği: "en sağda hangi gönderiyi beğendiğinin
              // minik bir görseli olsun; video ise videodan, fotoğraf ise
              // fotoğraftan"). Medyasız gönderide görsel çizilmez.
              trailing: _sagUc(b),
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
