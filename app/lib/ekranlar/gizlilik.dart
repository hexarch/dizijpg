import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ceviri.dart';
import '../tema.dart';

/// Politika sabitleri: statik sayfa (web/gizlilik.html) ile aynı kalmalı.
const gizlilikGuncelleme = '27.07.2026';
const gizlilikIletisim = 'iletisim@dizijpg.com';

/// Gizlilik politikası — girişsiz de erişilebilir (yonlendirme beyaz listesi).
class GizlilikEkrani extends StatelessWidget {
  const GizlilikEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DiziRenkler.siyah,
      appBar: AppBar(
        backgroundColor: DiziRenkler.koyuGri,
        // Doğrudan URL ile gelindiğinde yığın boş olur; girişe dön.
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: DiziRenkler.metin),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/giris'),
        ),
        title: Text(
          'Gizlilik Politikası'.c,
          style: TextStyle(color: DiziRenkler.metin),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              24 + MediaQuery.of(context).padding.bottom,
            ),
            children: [
              Text(
                'Son güncelleme: {}'.cf([gizlilikGuncelleme]),
                style: TextStyle(color: DiziRenkler.metin54, fontSize: 13),
              ),
              const SizedBox(height: 12),
              _Govde(
                'Bu politika, dizi.jpg uygulamasını ve dizijpg.com sitesini '
                'kullandığında hangi verilerin toplandığını, nasıl '
                'kullanıldığını ve haklarının neler olduğunu açıklar.',
              ),
              _Baslik('Topladığımız Veriler'),
              _Madde(
                'Hesap: e-posta adresi, kullanıcı adı ve şifre. Şifreler geri '
                'döndürülemez şekilde özetlenerek saklanır; misafir hesaplar '
                'e-postasız kullanılabilir.',
              ),
              _Madde(
                'Profil: avatar, kapak görseli, bio ve ülke gibi eklemeyi '
                'seçtiğin bilgiler.',
              ),
              _Madde(
                'Kullanım: izleme geçmişin, puanların, yorumların, '
                'listelerin, tepkilerin ve favorilerin.',
              ),
              _Madde(
                'Mesajlar: yazılı, görselli ve sesli mesajların '
                'sunucularımızda saklanır. Mesajlar uçtan uca şifreli '
                'değildir; yalnızca şikayet edilirse moderasyon amacıyla '
                'incelenir.',
              ),
              _Madde(
                'Yüklenen medya: profiline, yorumlarına ve mesajlarına '
                'eklediğin fotoğraf, GIF, video ve ses kayıtları.',
              ),
              _Madde(
                'Teknik: IP adresi, yaklaşık konum (ülke/şehir düzeyi), cihaz '
                'platformu, uygulama sürümü ve hata kayıtları. Bunlar '
                'güvenlik ve hata ayıklama için tutulur.',
              ),
              _Madde(
                'Bildirimler: push bildirimleri için cihaz token\'ı ve dil '
                'tercihin saklanır. Bildirimleri cihazının ayarlarından '
                'istediğin zaman kapatabilirsin.',
              ),
              _Baslik('Verileri Nasıl Kullanırız'),
              _Govde(
                'Verilerini yalnızca hizmeti sunmak, hesabını korumak, '
                'bildirim göndermek, hataları gidermek ve kötüye kullanımı '
                'önlemek için kullanırız. Verilerini satmayız, reklam '
                'amacıyla kimseyle paylaşmayız.',
              ),
              _Baslik('Çerezler ve Yerel Depolama'),
              _Govde(
                'Yalnızca oturumunu açık tutmak ve dil/tema gibi tercihlerini '
                'hatırlamak için yerel depolama kullanırız. Reklam veya '
                'izleme çerezi yoktur.',
              ),
              _Baslik('Üçüncü Taraf Hizmetler'),
              _Govde(
                'Dizi ve film bilgileri TMDB\'den, izleme sağlayıcı bilgisi '
                'JustWatch\'tan alınır. Push bildirimleri Google Firebase '
                'üzerinden iletilir, site trafiği Cloudflare tarafından '
                'korunur. Bu hizmetler kendi gizlilik politikalarına '
                'tabidir.',
              ),
              _Baslik('Saklama ve Silme'),
              _Govde(
                'Verilerin hesabın açık olduğu sürece saklanır. Ayarlar\'daki '
                '"Hesabımı Sil" ile hesabını kalıcı olarak silebilirsin; '
                'verilerin anında, yedeklerdeki kopyaları en geç 14 gün '
                'içinde silinir. Hata kayıtları 30 gün sonra otomatik '
                'silinir.',
              ),
              _Govde(
                'Verilerini Ayarlar\'dan ZIP olarak dışa aktarabilirsin; '
                'arşiv e-posta adresine gönderilir.',
              ),
              _Baslik('Güvenlik'),
              _Govde(
                'Veriler şifreli bağlantı (HTTPS) üzerinden taşınır ve '
                'erişimi sınırlı sunucularda saklanır.',
              ),
              _Baslik('Çocukların Gizliliği'),
              _Govde('dizi.jpg 13 yaşından küçük çocuklara yönelik değildir.'),
              _Baslik('Hakların'),
              _Govde(
                'KVKK ve GDPR kapsamında verilerine erişme, düzeltme, silme '
                've taşıma hakkına sahipsin. Bu haklar için bize '
                'yazabilirsin: {}',
                args: [gizlilikIletisim],
              ),
              _Baslik('Değişiklikler'),
              _Govde(
                'Bu politika değişirse yeni sürümü bu sayfada yayımlanır ve '
                'güncelleme tarihi yenilenir.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Baslik extends StatelessWidget {
  const _Baslik(this.metin);
  final String metin;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 6),
    child: Text(
      metin.c,
      style: const TextStyle(
        color: DiziRenkler.sari,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Govde extends StatelessWidget {
  const _Govde(this.metin, {this.args});
  final String metin;
  final List<Object?>? args;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      args == null ? metin.c : metin.cf(args!),
      style: TextStyle(
        color: DiziRenkler.metin70,
        fontSize: 14.5,
        height: 1.45,
      ),
    ),
  );
}

class _Madde extends StatelessWidget {
  const _Madde(this.metin);
  final String metin;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // RTL dillerde işaret doğru tarafta kalsın diye yön duyarlı dolgu.
        const Padding(
          padding: EdgeInsetsDirectional.only(top: 6, end: 8),
          child: Icon(Icons.circle, size: 6, color: DiziRenkler.sari),
        ),
        Expanded(
          child: Text(
            metin.c,
            style: TextStyle(
              color: DiziRenkler.metin70,
              fontSize: 14.5,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );
}
