import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'api.dart';
import 'ceviri.dart';
import 'tema.dart';
import 'ekranlar/akis.dart';
import 'ekranlar/arama_cubugu.dart';
import 'ekranlar/kesfet_akis.dart';
import 'ekranlar/bildirimler.dart';
import 'ekranlar/ozet.dart';
import 'ekranlar/sohbet.dart';
import 'ekranlar/ayarlar.dart';
import 'ekranlar/bolum.dart';
import 'ekranlar/detay.dart';
import 'ekranlar/giris.dart';
import 'ekranlar/giris_istem.dart';
import 'ekranlar/gizlenen_yorumlar.dart';
import 'ekranlar/gizlilik.dart';
import 'ekranlar/gozat.dart';
import 'ekranlar/izlediklerim.dart';
import 'ekranlar/kabuk.dart';
import 'ekranlar/karsilama.dart';
import 'ekranlar/kesfet.dart';
import 'ekranlar/kisi.dart';
import 'ekranlar/kitaplik_liste.dart';
import 'ekranlar/kullanici_profil.dart';
import 'ekranlar/profil.dart';
import 'ekranlar/takvim.dart';

/// Son kurulan yönlendirici — push bildirimi dokunuşları buradan gezinir
/// (bildirim işleyicilerinin BuildContext'i yoktur).
GoRouter? sonYonlendirici;

/// Kabuk-güvenli gezinme: kabuk-içi rotaya kabuk DIŞINDAN push yapılırsa
/// kabuk ikinci kez kurulur (GlobalKey çakışması → beyaz ekran); o durumda go.
void rotayaGit(String hedef) {
  final y = sonYonlendirici;
  if (y == null) return;
  final yol = y.routerDelegate.currentConfiguration.uri.path;
  const kabukDisi = [
    '/icerik/',
    '/kisi/',
    '/dizi/',
    '/ozet/',
    '/izlediklerim',
    '/ayarlar',
    '/gizlilik',
    '/gizlenen-yorumlar',
    '/giris',
    '/karsilama',
    '/gonderi/',
  ];
  if (kabukDisi.any(yol.startsWith)) {
    y.go(hedef);
  } else {
    y.push(hedef);
  }
}

/// Oturum GEREKTİRMEYEN yol ön ekleri.
///
/// NEDEN: sunucu (nginx bot kuralı + `/og/...` uçları) arama motorlarına bu
/// yollar için GERÇEK içerikli HTML döndürüyor. Oturumsuz ziyaretçi aynı
/// adreste giriş formu görseydi bot ile kullanıcının gördüğü sayfa farklı
/// olurdu — Google bunu "cloaking" sayar ve elle ceza verir. SEO-PLANI.md
/// madde 0.1'in tek gerekçesi budur; liste bot kapsamıyla eşleşmelidir.
///
/// Kasıtlı olarak DIŞARIDA bırakılanlar:
/// - `/kullanici/...`: profil sayfası kabuk İÇİNDE ve gizlilik tercihleri
///   (izlenenler_gizli / yorumlar_gizli) varsayılan olarak KAPALI. Herkese
///   açmak, kimsenin onaylamadığı bir kararla tüm profilleri dünyaya (ve iç
///   bağlantılar üzerinden Google'a) açardı. Bot kapsamında da değil.
/// - `/kesfet`, `/takvim`, `/akis`, `/arama`, `/profil`: kişiye özel, botun
///   göremediği ekranlar; oturum gerektirmeleri cloaking yaratmaz.
const acikYolOnEkleri = <String>['/icerik/', '/kisi/', '/gonderi/', '/dizi/'];

/// Oturum gerektirmeyen tam yollar (ön ek DEĞİL: `/gizlilik-tercihleri` gibi
/// ileride eklenebilecek kişisel bir ekran yanlışlıkla açılmasın).
const acikTamYollar = <String>['/gizlilik'];

/// [yol] oturumsuz ziyaretçiye açık mı?
bool herkeseAcikMi(String yol) =>
    acikTamYollar.contains(yol) || acikYolOnEkleri.any(yol.startsWith);

/// URL tabanlı yönlendirme: web'de reload bulunulan sayfada kalır.
GoRouter yonlendiriciOlustur(Oturum oturum) {
  // F5 güvencesi: motor başlangıç rotasını URL stratejisi kurulmadan '/'
  // olarak yakalayabiliyor; o durumda derin bağlantı kaybolup keşfete
  // düşülüyordu. Başlangıcı doğrudan tarayıcı adresinden alıyoruz.
  var baslangic = '/kesfet';
  if (kIsWeb && Uri.base.path.length > 1) {
    baslangic = Uri.base.path + (Uri.base.hasQuery ? '?${Uri.base.query}' : '');
  }
  return sonYonlendirici = GoRouter(
    initialLocation: baslangic,
    refreshListenable: oturum,
    redirect: (context, state) {
      final girisli = oturum.girisli;
      final konum = state.matchedLocation;
      final giriste = konum == '/giris';
      if (!girisli) {
        if (giriste) return null;
        // İçerik sayfaları (ve gizlilik politikası) oturumsuz açılır.
        if (herkeseAcikMi(konum)) return null;
        // Korumalı yol: nereye gitmek istediğini SAKLA, giriş sonrası oraya
        // dönsün. Yoksa Google'dan gelip giriş yapan kullanıcı keşfette kalır
        // ve tıkladığı içeriği kaybeder.
        return girisYolu(state.uri.toString());
      }
      // Yeni kayıt sonrası bir kez karşılama ekranı.
      if (Oturum.karsilamaGerekli && konum != '/karsilama') {
        return '/karsilama';
      }
      if (giriste) {
        return donusHedefi(state.uri.queryParameters['donus']) ?? '/kesfet';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/giris', builder: (_, __) => const GirisEkrani()),
      GoRoute(path: '/gizlilik', builder: (_, __) => const GizlilikEkrani()),
      GoRoute(path: '/karsilama', builder: (_, __) => const KarsilamaEkrani()),
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
              // Reels tarzı Keşfet (eski Arama sekmesi; arama artık Akış'ta)
              GoRoute(
                path: '/arama',
                builder: (_, __) => const KesfetAkisEkrani(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profil',
                builder: (_, __) => const ProfilEkrani(),
              ),
              GoRoute(
                path: '/kitaplik/:durum',
                builder: (_, s) =>
                    KitaplikListesiEkrani(durum: s.pathParameters['durum']!),
              ),
            ],
          ),
        ],
      ),
      // Detay sayfaları (sekmelerin üstünde).
      // Sayısal parametreler güvenli parse edilir: bozuk/eski URL'de (web'de
      // elle yazılmış /icerik/tv/abc gibi) hata ekranı yerine "bulunamadı".
      GoRoute(
        path: '/icerik/:tur/:id',
        builder: (_, s) {
          final id = int.tryParse(s.pathParameters['id'] ?? '');
          final tur = s.pathParameters['tur'];
          if (id == null || (tur != 'tv' && tur != 'movie')) {
            return const _GecersizBaglanti();
          }
          return DetayEkrani(tmdbId: id, tur: tur!);
        },
      ),
      GoRoute(
        path: '/kisi/:id',
        builder: (_, s) {
          final id = int.tryParse(s.pathParameters['id'] ?? '');
          return id == null
              ? const _GecersizBaglanti()
              : KisiEkrani(kisiId: id);
        },
      ),
      // Paylaşılan gönderi (reel/yorum) — tam ekran tek gönderi
      GoRoute(
        path: '/gonderi/:id',
        builder: (_, s) {
          final id = int.tryParse(s.pathParameters['id'] ?? '');
          return id == null
              ? const _GecersizBaglanti()
              : GonderiEkrani(yorumId: id);
        },
      ),
      GoRoute(
        path: '/dizi/:id/sezon/:sezon/bolum/:bolum',
        builder: (_, s) {
          final id = int.tryParse(s.pathParameters['id'] ?? '');
          final sezon = int.tryParse(s.pathParameters['sezon'] ?? '');
          final bolum = int.tryParse(s.pathParameters['bolum'] ?? '');
          if (id == null || sezon == null || bolum == null) {
            return const _GecersizBaglanti();
          }
          return BolumEkrani(
            tmdbId: id,
            sezonNo: sezon,
            bolumNo: bolum,
            izlendi: (s.extra as bool?) ?? false,
          );
        },
      ),
      GoRoute(path: '/ayarlar', builder: (_, __) => const AyarlarEkrani()),
      // Ayarlar > Gizlilik > Gizlenen yorumlar. Kabuğun DIŞINDA: ayarların
      // kendisi gibi tam ekran açılır, geri tuşu ayarlara döner.
      GoRoute(
        path: '/gizlenen-yorumlar',
        builder: (_, __) => const GizlenenYorumlarEkrani(),
      ),
      GoRoute(path: '/gozat', builder: (_, __) => const GozatEkrani()),
      // Mobilde üst bardaki kapalı kutunun açtığı TAM EKRAN arama.
      // KABUĞUN DIŞINDA: alt gezinme çubuğu görünmez, geri tuşu (Android ve
      // tarayıcı) aramayı kapatıp geldiği sekmeye döner.
      GoRoute(
        path: tamAramaYolu,
        pageBuilder: (_, s) => CustomTransitionPage(
          key: s.pageKey,
          // Açılış 220 ms, kapanış 160 ms: çıkış girişten hızlı olur, "kutu
          // büyüyüp ekranı kaplıyor" hissi verir ama abartılı değildir.
          transitionDuration: const Duration(milliseconds: 220),
          reverseTransitionDuration: const Duration(milliseconds: 160),
          transitionsBuilder: (_, animasyon, __, cocuk) => FadeTransition(
            opacity: animasyon,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(
                CurvedAnimation(parent: animasyon, curve: Curves.easeOutCubic),
              ),
              child: cocuk,
            ),
          ),
          child: const TamEkranAramaSayfasi(),
        ),
      ),
      GoRoute(
        path: '/ozet/:yil',
        builder: (_, s) {
          final yil = int.tryParse(s.pathParameters['yil'] ?? '');
          return yil == null ? const _GecersizBaglanti() : OzetEkrani(yil: yil);
        },
      ),
      GoRoute(
        path: '/izlediklerim',
        builder: (_, s) => IzlenenlerEkrani(tur: s.uri.queryParameters['tur']),
      ),
    ],
    // Eşleşmeyen rota (bozuk/eski bağlantı): hata ekranı yerine nazik sayfa
    errorBuilder: (_, __) => const _GecersizBaglanti(),
  );
}

/// Bozuk/eski bağlantıda gösterilir (hata ekranı yerine nazik yönlendirme).
class _GecersizBaglanti extends StatelessWidget {
  const _GecersizBaglanti();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_off, size: 48, color: DiziRenkler.metin38),
            const SizedBox(height: 12),
            Text(
              'Bağlantı geçersiz veya sayfa bulunamadı'.c,
              textAlign: TextAlign.center,
              style: TextStyle(color: DiziRenkler.metin54),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/kesfet'),
              child: Text('Keşfet\'e dön'.c),
            ),
          ],
        ),
      ),
    );
  }
}
