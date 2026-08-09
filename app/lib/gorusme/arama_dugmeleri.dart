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
            IconButton(
              key: const Key('sohbet-sesli-ara'),
              // IconButton'ın varsayılan dokunma hedefi 48x48 dp'dir
              // (kIconButtonMinSize); 44 dp asgarisinin üstünde.
              tooltip: 'Sesli ara'.c,
              icon: Icon(Icons.call, color: DiziRenkler.metin),
              onPressed: () => _ara('ses'),
            ),
            // Görüntülü kill switch'i kapalıysa düğme HİÇ çizilmez; asıl
            // zorlama yine sunucuda (yayındaki eski APK bayrağı yok sayarsa
            // 503 alır).
            if (AramaServisi.goruntuluAcik)
              IconButton(
                key: const Key('sohbet-goruntulu-ara'),
                tooltip: 'Görüntülü ara'.c,
                icon: Icon(Icons.videocam, color: DiziRenkler.metin),
                onPressed: () => _ara('goruntu'),
              ),
          ],
        );
      },
    );
  }
}
