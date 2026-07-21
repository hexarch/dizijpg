import 'package:go_router/go_router.dart';

import 'api.dart';
import 'ekranlar/akis.dart';
import 'ekranlar/arama.dart';
import 'ekranlar/bildirimler.dart';
import 'ekranlar/ozet.dart';
import 'ekranlar/sohbet.dart';
import 'ekranlar/ayarlar.dart';
import 'ekranlar/bolum.dart';
import 'ekranlar/detay.dart';
import 'ekranlar/giris.dart';
import 'ekranlar/izlediklerim.dart';
import 'ekranlar/kabuk.dart';
import 'ekranlar/kesfet.dart';
import 'ekranlar/kisi.dart';
import 'ekranlar/kullanici_profil.dart';
import 'ekranlar/profil.dart';
import 'ekranlar/takvim.dart';

/// URL tabanlı yönlendirme: web'de reload bulunulan sayfada kalır.
GoRouter yonlendiriciOlustur(Oturum oturum) {
  return GoRouter(
    initialLocation: '/kesfet',
    refreshListenable: oturum,
    redirect: (context, state) {
      final girisli = oturum.girisli;
      final giriste = state.matchedLocation == '/giris';
      if (!girisli) return giriste ? null : '/giris';
      if (giriste) return '/kesfet';
      return null;
    },
    routes: [
      GoRoute(path: '/giris', builder: (_, __) => const GirisEkrani()),
      // Alt sekmeler — durum korunur, URL sekmeyi yansıtır
      StatefulShellRoute.indexedStack(
        builder: (_, __, navigationShell) =>
            KabukEkrani(shell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/kesfet',
                builder: (_, __) => const KesfetEkrani(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/takvim',
                builder: (_, __) => const TakvimEkrani(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/akis', builder: (_, __) => const AkisEkrani()),
              // Kullanıcı sayfaları kabuk içinde: alt menü kaybolmaz
              GoRoute(
                path: '/kullanici/:ad',
                builder: (_, s) => KullaniciProfilEkrani(
                  kullaniciAdi: s.pathParameters['ad']!,
                ),
                routes: [
                  GoRoute(
                    path: 'takipciler',
                    builder: (_, s) => KullaniciListesiEkrani(
                      kullaniciAdi: s.pathParameters['ad']!,
                      takipciler: true,
                    ),
                  ),
                  GoRoute(
                    path: 'takip',
                    builder: (_, s) => KullaniciListesiEkrani(
                      kullaniciAdi: s.pathParameters['ad']!,
                      takipciler: false,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/kisi-ara',
                builder: (_, __) => const KullaniciAramaEkrani(),
              ),
              GoRoute(
                path: '/bildirimler',
                builder: (_, __) => const BildirimlerEkrani(),
              ),
              GoRoute(
                path: '/sohbetler',
                builder: (_, __) => const SohbetlerEkrani(),
              ),
              GoRoute(
                path: '/sohbet/:ad',
                builder: (_, s) =>
                    SohbetEkrani(kullaniciAdi: s.pathParameters['ad']!),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/arama', builder: (_, __) => const AramaEkrani()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profil',
                builder: (_, __) => const ProfilEkrani(),
              ),
            ],
          ),
        ],
      ),
      // Detay sayfaları (sekmelerin üstünde)
      GoRoute(
        path: '/icerik/:tur/:id',
        builder: (_, s) => DetayEkrani(
          tmdbId: int.parse(s.pathParameters['id']!),
          tur: s.pathParameters['tur']!,
        ),
      ),
      GoRoute(
        path: '/kisi/:id',
        builder: (_, s) =>
            KisiEkrani(kisiId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/dizi/:id/sezon/:sezon/bolum/:bolum',
        builder: (_, s) => BolumEkrani(
          tmdbId: int.parse(s.pathParameters['id']!),
          sezonNo: int.parse(s.pathParameters['sezon']!),
          bolumNo: int.parse(s.pathParameters['bolum']!),
          izlendi: (s.extra as bool?) ?? false,
        ),
      ),
      GoRoute(path: '/ayarlar', builder: (_, __) => const AyarlarEkrani()),
      GoRoute(
        path: '/ozet/:yil',
        builder: (_, s) => OzetEkrani(yil: int.parse(s.pathParameters['yil']!)),
      ),
      GoRoute(
        path: '/izlediklerim',
        builder: (_, __) => const IzlenenlerEkrani(),
      ),
    ],
  );
}
