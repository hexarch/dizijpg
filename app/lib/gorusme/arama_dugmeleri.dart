import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'arama_servisi.dart';

/// Sohbet başlığındaki sesli/görüntülü arama düğmeleri.
///
/// ### Neden düğme "belki gösterilir" değil, "kesin gösterilir"
///
/// Sunucu karşılıklı takip kuralını zaten zorluyor (sözleşme §5.1) ve
/// `TAKIP_YOK` döndürüyor. Ama tıklanabilir görünüp reddedilen bir düğme,
/// kullanıcıya kendi hatasıymış gibi hissettirir. Bu yüzden düğme yalnız
/// karşılıklı takipleşmede çizilir.
///
/// Karşılıklı takibi TEK çağrıda veren bir uç yok; [AramaServisi.karsilikliTakipMi]
/// iki mevcut GET'i birleştiriyor ve **belirsizlikte düğmeyi GÖSTERİYOR**
/// (gerekçe orada). Yani hata yönü bilinçli seçildi: yanlışlıkla görünen bir
/// düğme çevrilmiş bir uyarı verir, yanlışlıkla gizlenen düğme SESSİZCE
/// özelliği yok eder.
class AramaDugmeleri extends StatefulWidget {
  const AramaDugmeleri({super.key, required this.kullaniciAdi, this.avatar});

  final String kullaniciAdi;
  final String? avatar;

  @override
  State<AramaDugmeleri> createState() => _AramaDugmeleriState();
}

class _AramaDugmeleriState extends State<AramaDugmeleri> {
  bool _karsilikli = false;
  bool _sorgulandi = false;

  @override
  void initState() {
    super.initState();
    _sor();
  }

  Future<void> _sor() async {
    if (!AramaServisi.kullanilabilir) return;
    final benimAd =
        context.read<Oturum>().kullanici?['kullanici_adi'] as String?;
    final sonuc = await AramaServisi.karsilikliTakipMi(
      widget.kullaniciAdi,
      benimAd,
    );
    if (!mounted) return;
    setState(() {
      _karsilikli = sonuc;
      _sorgulandi = true;
    });
  }

  void _ara(String tur) {
    context.push(
      '/gorusme/${widget.kullaniciAdi}?tur=$tur',
      extra: widget.avatar,
    );
  }

  /// Kendi tercihi kapalı olan düğmeye dokunulunca: NE OLDUĞUNU ve NEREDEN
  /// AÇILACAĞINI söyle, üstelik oraya götüren bir eylem sun.
  ///
  /// "Kapalı" deyip bırakmak, kurtarma yolu olmayan bir hata mesajıdır. Ayrıca
  /// varsayılan KAPALI olduğu için kullanıcıların ÇOĞU bu mesajı görecek —
  /// yani bu, özelliğin tanıtıldığı asıl yer.
  static String kapaliMetni(String tur) => tur == 'ses'
      ? 'Sesli arama kapalı. Ayarlar > Gizlilik bölümünden açabilirsin.'.c
      : 'Görüntülü arama kapalı. Ayarlar > Gizlilik bölümünden açabilirsin.'.c;

  void _kapaliAciklama(String tur) {
    final mesaj = kapaliMetni(tur);
    // `maybeOf`, `of` DEĞİL: `of` yönlendirici yoksa FIRLATIR ve o an asıl
    // iş olan AÇIKLAMA da gösterilemez. Kurtarma kısayolu kaybolabilir,
    // açıklama kaybolamaz — metin zaten nereye gidileceğini yazıyor.
    final yonlendirici = GoRouter.maybeOf(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        // 5 sn: iki satırlık bir açıklama + eylem düğmesi için varsayılan
        // 4 sn kısa kalıyor.
        duration: const Duration(seconds: 5),
        action: yonlendirici == null
            ? null
            : SnackBarAction(
                label: 'Ayarlar'.c,
                onPressed: () => yonlendirici.push('/ayarlar'),
              ),
      ),
    );
  }

  /// Sohbet başlığındaki tek arama düğmesi.
  ///
  /// [acik] false iken düğme **GİZLENMEZ, PASİF görünür** (md. 38) ve
  /// `onPressed` **null bırakılmaz**: `IconButton(onPressed: null)` dokunuşu
  /// hiç almaz, dolayısıyla "nereden açacağını söyle" isteği yerine getirilemez.
  /// Pasiflik yalnız GÖRSELDİR — renk `metin38`e düşer.
  Widget _dugme({
    required Key anahtar,
    required IconData ikon,
    required String etiket,
    required String tur,
    required bool acik,
  }) {
    return IconButton(
      key: anahtar,
      // IconButton'ın varsayılan dokunma hedefi 48x48 dp'dir (kIconButtonMinSize);
      // 44 dp asgarisinin üstünde. Pasif hâlde de aynı — küçültülmez, yoksa
      // açıklamayı okumak isteyen kullanıcı düğmeyi ıskalar.
      //
      // Pasif hâlde tooltip = açıklamanın kendisi. Ekran okuyucu için tek
      // erişilebilir ipucu budur: renk farkı (metin38) sesli okunmaz, "Sesli
      // ara" desek kullanıcı basar ve neden çalışmadığını anlamaz.
      tooltip: acik ? etiket : kapaliMetni(tur),
      icon: Icon(ikon, color: acik ? DiziRenkler.metin : DiziRenkler.metin38),
      onPressed: acik ? () => _ara(tur) : () => _kapaliAciklama(tur),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AramaServisi.surum,
      builder: (context, _, _) {
        if (!AramaServisi.kullanilabilir || !_sorgulandi || !_karsilikli) {
          return const SizedBox.shrink();
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dugme(
              anahtar: const Key('sohbet-sesli-ara'),
              ikon: Icons.call,
              etiket: 'Sesli ara'.c,
              tur: 'ses',
              // KENDİ tercihim kapalıysa PASİF — gizlenmez (md. 38).
              acik: AramaServisi.kendiSesliAcik,
            ),
            // Görüntülü SUNUCU bayrağı kapalıysa düğme HİÇ çizilmez (özellik
            // yok); kendi tercihim kapalıysa çizilir ama pasif (özellik var,
            // ben kapatmışım). İki durum farklı, gösterimi de farklı.
            // Asıl zorlama yine sunucuda: yayındaki eski bir APK bayrağı yok
            // sayarsa 503/403 alır.
            if (AramaServisi.goruntuluAcik)
              _dugme(
                anahtar: const Key('sohbet-goruntulu-ara'),
                ikon: Icons.videocam,
                etiket: 'Görüntülü ara'.c,
                tur: 'goruntu',
                acik: AramaServisi.kendiGoruntuluAcik,
              ),
          ],
        );
      },
    );
  }
}
