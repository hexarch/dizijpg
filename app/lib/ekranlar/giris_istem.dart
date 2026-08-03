import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';

/// Giriş ekranına, dönüş adresini taşıyarak giden yol.
///
/// Google'dan `/icerik/tv/1396` sayfasına gelen ziyaretçi giriş yaptıktan
/// sonra ana sayfada kalmasın diye hedef `donus` sorgu parametresinde
/// saklanır; [donusHedefi] onu geri çözer.
String girisYolu([String? donus]) {
  if (donus == null || donus.isEmpty || donus.startsWith('/giris')) {
    return '/giris';
  }
  return '/giris?donus=${Uri.encodeComponent(donus)}';
}

/// `/giris?donus=...` içindeki dönüş adresini güvenli biçimde çözer.
///
/// GÜVENLİK: yalnız TEK eğik çizgiyle başlayan uygulama içi yollar kabul
/// edilir. `//baskasite.com` ya da `https://...` kabul edilseydi giriş
/// ekranı açık yönlendirme (open redirect) aracına dönerdi.
String? donusHedefi(String? ham) {
  if (ham == null || ham.isEmpty) return null;
  final coz = Uri.decodeComponent(ham);
  if (!coz.startsWith('/') || coz.startsWith('//')) return null;
  if (coz.startsWith('/giris')) return null;
  return coz;
}

/// Oturumsuz ziyaretçi giriş gerektiren bir EYLEME dokunduğunda çağrılır.
///
/// `true` dönerse çağıran eylemine devam edebilir. `false` dönerse ziyaretçi
/// oturumsuzdur ve nazik bir giriş istemi gösterilmiştir — yani eylem sessizce
/// başarısız olmaz, kullanıcı ne olduğunu ve ne yapması gerektiğini görür.
///
/// Kullanım: `if (!girisGerekli(context)) return;`
bool girisGerekli(BuildContext context) {
  if (Api.girisli) return true;
  girisIstemiGoster(context);
  return false;
}

/// Giriş istemi alt sayfası.
///
/// Bilinçli olarak DUVAR DEĞİL: içerik arkada açık kalır ve istem
/// kapatılabilir. Amaç aramadan gelen ziyaretçiyi kaydolmaya zorlamak değil,
/// dokunduğu eylemin neden çalışmadığını dürüstçe söylemek.
void girisIstemiGoster(BuildContext context) {
  final yol = GoRouter.of(
    context,
  ).routerDelegate.currentConfiguration.uri.toString();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: DiziRenkler.koyuGri,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.lock_outline, size: 40, color: DiziRenkler.sariMetin),
            const SizedBox(height: 14),
            Text(
              'Devam etmek için giriş yap'.c,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Puan vermek, yorum yazmak ve kitaplığını oluşturmak için ücretsiz bir hesap yeterli.'
                  .c,
              textAlign: TextAlign.center,
              style: TextStyle(color: DiziRenkler.metin70, height: 1.4),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('giris-istemi-giris'),
              onPressed: () {
                Navigator.pop(sheetContext);
                GoRouter.of(context).go(girisYolu(yol));
              },
              child: Text('Giriş Yap'.c),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: Text(
                'Şimdi değil'.c,
                style: TextStyle(color: DiziRenkler.metin70),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Oturumsuzken yazma kutusunun YERİNE geçen istem kartı.
///
/// Boş bir metin kutusu bırakıp gönderide 401 SnackBar basmak yerine, ne
/// gerektiğini önden söyler (skill madde 3: sessiz başarısızlık yasak).
class GirisIstemiKarti extends StatelessWidget {
  final String metin;
  const GirisIstemiKarti({super.key, required this.metin});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => girisIstemiGoster(context),
        child: Padding(
          // Dikey 16 + metin satırı: dokunma hedefi 44 dp asgarisinin üstünde.
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 20, color: DiziRenkler.sariMetin),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  metin,
                  style: TextStyle(
                    color: DiziRenkler.metin70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: DiziRenkler.metin38),
            ],
          ),
        ),
      ),
    );
  }
}

/// Oturumsuzken içerik sayfalarının üst çubuğunda görünen küçük giriş çıkışı.
///
/// Aramadan gelen ziyaretçinin alt gezinme çubuğu yoktur (kabuk giriş
/// gerektirir); bu buton olmasa sayfada çıkışsız kalırdı. Oturumluysa hiç
/// çizilmez.
class GirisEylemi extends StatelessWidget {
  const GirisEylemi({super.key});

  @override
  Widget build(BuildContext context) {
    if (Api.girisli) return const SizedBox.shrink();
    final yol = GoRouter.of(
      context,
    ).routerDelegate.currentConfiguration.uri.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton(
        key: const Key('ustcubuk-giris'),
        onPressed: () => GoRouter.of(context).go(girisYolu(yol)),
        child: Text(
          'Giriş Yap'.c,
          style: TextStyle(
            color: DiziRenkler.sariMetin,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
