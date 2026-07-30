import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_icons/simple_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ceviri.dart';
import '../tema.dart';

/// Desteklenen sosyal platformlar (backend SOSYAL_PLATFORMLAR ile aynı).
/// url null ise profil bağlantısı yoktur; dokununca kullanıcı adı kopyalanır.
/// uygulamaUrl: Android'de yüklü uygulamayı doğrudan açan derin bağlantı
/// (şemaları AndroidManifest <queries> içinde bildirilmiş olmalı).
class SosyalPlatform {
  final String kod;
  final String ad;
  final IconData ikon;
  final String? url; // {} → kullanıcı adı
  final String? uygulamaUrl;

  const SosyalPlatform(
    this.kod,
    this.ad,
    this.ikon,
    this.url, {
    this.uygulamaUrl,
  });
}

const sosyalPlatformlar = [
  SosyalPlatform(
    'instagram',
    'Instagram',
    SimpleIcons.instagram,
    'https://instagram.com/{}',
    uygulamaUrl: 'instagram://user?username={}',
  ),
  SosyalPlatform(
    'facebook',
    'Facebook',
    SimpleIcons.facebook,
    'https://facebook.com/{}',
  ),
  SosyalPlatform(
    'x',
    'X',
    SimpleIcons.x,
    'https://x.com/{}',
    uygulamaUrl: 'twitter://user?screen_name={}',
  ),
  SosyalPlatform(
    'tiktok',
    'TikTok',
    SimpleIcons.tiktok,
    'https://tiktok.com/@{}',
  ),
  SosyalPlatform('discord', 'Discord', SimpleIcons.discord, null),
  SosyalPlatform(
    'steam',
    'Steam',
    SimpleIcons.steam,
    'https://steamcommunity.com/id/{}',
  ),
  // Simple Icons'ta xbox/epic yok (marka politikası) — yakın ikonlarla.
  SosyalPlatform('xbox', 'Xbox', Icons.sports_esports, null),
  SosyalPlatform('epicgames', 'Epic Games', SimpleIcons.epicgames, null),
  SosyalPlatform(
    'imdb',
    'IMDb',
    SimpleIcons.imdb,
    'https://www.imdb.com/user/{}',
  ),
  SosyalPlatform('vk', 'VK', SimpleIcons.vk, 'https://vk.com/{}'),
  SosyalPlatform(
    'youtube',
    'YouTube',
    SimpleIcons.youtube,
    'https://youtube.com/@{}',
  ),
  SosyalPlatform(
    'twitch',
    'Twitch',
    SimpleIcons.twitch,
    'https://twitch.tv/{}',
  ),
  SosyalPlatform(
    'spotify',
    'Spotify',
    SimpleIcons.spotify,
    'https://open.spotify.com/user/{}',
  ),
  SosyalPlatform(
    'github',
    'GitHub',
    SimpleIcons.github,
    'https://github.com/{}',
  ),
  SosyalPlatform(
    'reddit',
    'Reddit',
    SimpleIcons.reddit,
    'https://reddit.com/u/{}',
  ),
  SosyalPlatform(
    'telegram',
    'Telegram',
    SimpleIcons.telegram,
    'https://t.me/{}',
    uygulamaUrl: 'tg://resolve?domain={}',
  ),
  SosyalPlatform(
    'snapchat',
    'Snapchat',
    SimpleIcons.snapchat,
    'https://snapchat.com/add/{}',
  ),
  SosyalPlatform(
    'pinterest',
    'Pinterest',
    SimpleIcons.pinterest,
    'https://pinterest.com/{}',
  ),
  SosyalPlatform(
    'letterboxd',
    'Letterboxd',
    SimpleIcons.letterboxd,
    'https://letterboxd.com/{}',
  ),
  // Genel web sitesi: değer alan adıdır (ör. ornek.com/sayfa)
  SosyalPlatform('website', 'Web Sitesi', Icons.language, 'https://{}'),
];

SosyalPlatform? sosyalBul(String kod) {
  for (final p in sosyalPlatformlar) {
    if (p.kod == kod) return p;
  }
  return null;
}

/// Profilde görünen sosyal ikon sırası (en fazla 3 kayıt zaten).
/// Dokununca profil bağlantısı açılır; bağlantısı olmayan platformlarda
/// kullanıcı adı panoya kopyalanır.
class SosyalSatiri extends StatelessWidget {
  final List<dynamic> sosyal; // [{platform, deger}]
  const SosyalSatiri({super.key, required this.sosyal});

  Future<void> _ac(BuildContext context, SosyalPlatform p, String deger) async {
    // URL'de baştaki @ sorun çıkarır (instagram.com/@ad gibi) — soy
    final temiz = deger.startsWith('@') ? deger.substring(1) : deger;
    // 1) Android/iOS: yüklü uygulamayı doğrudan aç (instagram:// vb.)
    if (!kIsWeb && p.uygulamaUrl != null) {
      try {
        if (await launchUrl(
          Uri.parse(p.uygulamaUrl!.replaceFirst('{}', temiz)),
          mode: LaunchMode.externalNonBrowserApplication,
        )) {
          return;
        }
      } catch (_) {
        /* uygulama yüklü değil → tarayıcıya düş */
      }
    }
    // 2) Tarayıcı: web'de YENİ SEKME (_blank), mobilde dış tarayıcı/app link
    if (p.url != null) {
      try {
        if (await launchUrl(
          Uri.parse(p.url!.replaceFirst('{}', temiz)),
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        )) {
          return;
        }
      } catch (_) {
        /* açılamadı → kopyalamaya düş */
      }
    }
    // 3) Son çare: kullanıcı adını panoya kopyala
    await Clipboard.setData(ClipboardData(text: deger));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kopyalandı: {}'.cf([deger]))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final gecerli = [
      for (final s in sosyal.take(3))
        if (sosyalBul(
              (s as Map<String, dynamic>)['platform'] as String? ?? '',
            ) !=
            null)
          s,
    ];
    if (gecerli.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      children: [
        for (final s in gecerli)
          Builder(
            builder: (context) {
              final p = sosyalBul(s['platform'] as String)!;
              final deger = s['deger'] as String? ?? '';
              return Tooltip(
                message: '${p.ad.c}: $deger',
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => _ac(context, p, deger),
                  child: Padding(
                    // Dokunma hedefi ≥44px: 20px ikon + 12px dolgu
                    padding: const EdgeInsets.all(12),
                    child: Icon(p.ikon, size: 20, color: DiziRenkler.sari),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Ayarlar'daki sosyal bağlantı düzenleyici: mevcutlar + ekle (en fazla 3).
class SosyalDuzenleyici extends StatelessWidget {
  final List<Map<String, dynamic>> sosyal;
  final void Function(List<Map<String, dynamic>>) onDegisti;
  const SosyalDuzenleyici({
    super.key,
    required this.sosyal,
    required this.onDegisti,
  });

  Future<void> _ekle(BuildContext context) async {
    final kalan = [
      for (final p in sosyalPlatformlar)
        if (!sosyal.any((s) => s['platform'] == p.kod)) p,
    ];
    final platform = await showModalBottomSheet<SosyalPlatform>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DiziRenkler.koyuGri,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Platform seç'.c,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: kalan.length,
                  itemBuilder: (context, i) => InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(context, kalan[i]),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(kalan[i].ikon, size: 26, color: DiziRenkler.sari),
                        const SizedBox(height: 6),
                        Text(
                          kalan[i].ad.c,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: DiziRenkler.metin70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (platform == null || !context.mounted) return;

    final kutu = TextEditingController();
    final deger = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DiziRenkler.koyuGri,
        title: Row(
          children: [
            Icon(platform.ikon, size: 20, color: DiziRenkler.sari),
            const SizedBox(width: 8),
            Expanded(child: Text(platform.ad.c)),
          ],
        ),
        content: TextField(
          controller: kutu,
          autofocus: true,
          maxLength: 100,
          decoration: InputDecoration(hintText: 'Kullanıcı adın'.c),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'İptal'.c,
              style: TextStyle(color: DiziRenkler.metin54),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, kutu.text.trim()),
            child: Text('Ekle'.c),
          ),
        ],
      ),
    );
    if (deger == null || deger.isEmpty) return;
    // Backend'le aynı desen; kaydetmeden önce yerelde de ele
    if (!RegExp(r'^[A-Za-z0-9._@/-]{1,100}$').hasMatch(deger)) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Geçersiz kullanıcı adı'.c)));
      }
      return;
    }
    onDegisti([
      ...sosyal,
      {'platform': platform.kod, 'deger': deger},
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in sosyal)
          Builder(
            builder: (context) {
              final p = sosyalBul(s['platform'] as String);
              if (p == null) return const SizedBox.shrink();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(p.ikon, size: 22, color: DiziRenkler.sari),
                title: Text(p.ad.c),
                subtitle: Text(
                  s['deger'] as String? ?? '',
                  style: TextStyle(color: DiziRenkler.metin54),
                ),
                trailing: IconButton(
                  tooltip: 'Kaldır'.c,
                  onPressed: () =>
                      onDegisti([...sosyal]..removeWhere((e) => e == s)),
                  icon: Icon(Icons.close, size: 18, color: DiziRenkler.metin54),
                ),
              );
            },
          ),
        if (sosyal.length < 3)
          OutlinedButton.icon(
            onPressed: () => _ekle(context),
            icon: const Icon(Icons.add, size: 18, color: DiziRenkler.sari),
            label: Text(
              'Bağlantı ekle'.c,
              style: TextStyle(color: DiziRenkler.metin),
            ),
          ),
      ],
    );
  }
}
