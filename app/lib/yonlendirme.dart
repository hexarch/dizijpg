import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'api.dart';
import 'ceviri.dart';
import 'tema.dart';
import 'gorusme/gelen_arama_ekrani.dart';
import 'gorusme/gorusme_ekrani.dart';
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
import 'ekranlar/engellenen_kullanicilar.dart';
import 'ekranlar/gizlenen_yorumlar.dart';
import 'ekranlar/gizlilik.dart';
import 'ekranlar/gonderi_istatistik.dart';
import 'ekranlar/gozat.dart';
import 'ekranlar/hareketlerim.dart';
import 'ekranlar/favori_oyuncular.dart';
import 'ekranlar/istatistiklerim.dart';
import 'ekranlar/izlediklerim.dart';
import 'ekranlar/kabuk.dart';
import 'ekranlar/karsilama.dart';
import 'ekranlar/kesfet.dart';
import 'ekranlar/kisi.dart';
import 'ekranlar/kisi_yapimlar.dart';
import 'ekranlar/sirket.dart';
import 'ekranlar/liste.dart';
import 'ekranlar/kitaplik_liste.dart';
import 'ekranlar/kullanici_profil.dart';
import 'ekranlar/ortak.dart' show kabugaDon, kabukIcindeMi;
import 'ekranlar/profil.dart';
import 'ekranlar/takvim.dart';

/// Son kurulan yönlendirici — push bildirimi dokunuşları buradan gezinir
/// (bildirim işleyicilerinin BuildContext'i yoktur).
GoRouter? sonYonlendirici;

/// Gelen arama ekranının yolu.
///
/// DİKKAT — bu `/arama` DEĞİL: `/arama` bu projede **dizi/film keşfi**
/// (Reels sekmesi) ve `tamAramaYolu` da tam ekran ARAMA KUTUSU. Sesli/görüntülü
/// arama başka bir şey; dosya adları `gorusme*`, yollar `arama-gelen` /
/// `gorusme`. Backend de aynı çarpışmayı yaşayıp hız limitine `gorusmeLimiti`
/// demişti (server.js:955 `aramaLimiti` = search).
const String gelenAramaYolu = '/arama-gelen';

/// Kabuk-güvenli gezinme: kabuk-içi rotaya kabuk DIŞINDAN push yapılırsa
/// kabuk ikinci kez kurulur (sayfa anahtarı/GlobalKey çakışması → boş, siyah
/// ekran); o durumda go. "Kabuk dışı" kararı elle tutulan yol listesiyle
/// DEĞİL, yönlendiricinin kendi eşleşme ağacıyla verilir — bkz.
/// [kabukIcindeMi]; eski kopyalanmış liste yeni kök rotalarda güncellenmeyip
/// siyah ekran üretiyordu.
void rotayaGit(String hedef) {
  final y = sonYonlendirici;
  if (y == null) return;
  if (kabukIcindeMi(y) || kabugaDon(y)) {
    y.push(hedef);
  } else {
    y.go(hedef);
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
///
/// `/listeler/` 7 Ağu 2026'da eklendi: nginx'in bot kuralı zaten
/// `^/(icerik|gonderi|kisi|dizi|listeler)/` idi ve `/og/listeler/:id`
/// indekslenebilir HTML basıyordu — yani bot içeriği, insan giriş formunu
/// görüyordu (tam tanımıyla cloaking). GİZLİLİK: sunucu `herkese_acik=false`
/// listeyi sahibi olmayana 404 verir, yani liste rotasının açık olması gizli
/// listeleri açmaz (bkz. server.js `GET /listeler/:id`).
const acikYolOnEkleri = <String>[
  '/icerik/',
  '/kisi/',
  '/gonderi/',
  '/dizi/',
  '/listeler/',
  // Md. 49 — yapım firması sayfası. İçeriğin firma şeridinden açılıyor ve
  // içerik sayfaları zaten oturumsuz açık; burada giriş duvarı zincirin
  // ortasında kopukluk yaratırdı. GİZLİLİK: sayfa yalnız TMDB katalog
  // verisi gösterir, kişiye özel hiçbir alan okumaz. CLOAKING RİSKİ YOK:
  // `/sirket/` nginx'in bot kuralında (`^/(icerik|gonderi|kisi|dizi|listeler)/`)
  // yok, yani bot da insan da AYNI uygulamayı görür.
  '/sirket/',
];

/// Oturum gerektirmeyen tam yollar (ön ek DEĞİL: `/gizlilik-tercihleri` gibi
/// ileride eklenebilecek kişisel bir ekran yanlışlıkla açılmasın).
const acikTamYollar = <String>['/gizlilik'];

/// Tek gönderi adresi. [yanit] TRUE ise `?yanit=1` eklenir.
///
/// NEDEN BAYRAK VAR (10 Ağu 2026, md.15): "yanıt" bildirimindeki `yorum_id`
/// yanıtın KENDİ id'sidir, üst gönderinin değil. `/gonderi/:id` ise gelen
/// yorumu tam ekran Reels sayfası olarak çizer; yanıtın medyası olmadığı için
/// ekranda dev puntolu tek bir yazı kalıyordu ("koca ekran"). Bayrak, ekrana
/// "bu id bir YANIT, üstünü çöz ve normal yorum ekranını aç" der.
/// Paylaşım bağlantıları (`/gonderi/123`) bu bayrağı taşımaz, davranışları
/// birebir aynıdır — ek istek de atılmaz.
String gonderiYolu(String yorumId, {bool yanit = false}) =>
    yanit ? '/gonderi/$yorumId?yanit=1' : '/gonderi/$yorumId';

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
                path: '/mesaj-istekleri',
                builder: (_, __) => const MesajIstekleriEkrani(),
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
              // Favori oyuncular: profil sekmesinin İÇİNDE (alt gezinme
              // çubuğu kaybolmasın, geri tuşu profile dönsün) —
              // `/kitaplik/:durum` ile aynı kalıp.
              GoRoute(
                path: '/favori-oyuncular',
                builder: (_, _) => const FavoriOyuncularEkrani(),
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
      // Yapım firması (md. 49) — detaydaki firma şeridinden açılır. `/kisi/:id`
      // ile aynı hizada: kabuğun DIŞINDA ve oturumsuz ziyaretçiye AÇIK
      // (bkz. [acikYolOnEkleri]) — içerik sayfasından buraya tıklayan
      // ziyaretçinin giriş duvarına çarpması kopukluk olurdu.
      GoRoute(
        path: '/sirket/:id',
        builder: (_, s) {
          final id = int.tryParse(s.pathParameters['id'] ?? '');
          return id == null
              ? const _GecersizBaglanti()
              : SirketEkrani(
                  sirketId: id,
                  sirketAdi: s.uri.queryParameters['ad'],
                  baslangicTuru: s.uri.queryParameters['tur'],
                );
        },
      ),
      // Paylaşılan liste — SSR sayfası (`/og/listeler/:id`) bu adrese
      // götürüyor. Kabuğun DIŞINDA: oturumsuz ziyaretçinin kabuğu yoktur.
      GoRoute(
        path: '/listeler/:id',
        builder: (_, s) {
          final id = int.tryParse(s.pathParameters['id'] ?? '');
          return id == null
              ? const _GecersizBaglanti()
              : ListeEkrani(listeId: id);
        },
      ),
      // Paylaşılan gönderi (reel/yorum) — tam ekran tek gönderi
      GoRoute(
        path: '/gonderi/:id',
        builder: (_, s) {
          final id = int.tryParse(s.pathParameters['id'] ?? '');
          return id == null
              ? const _GecersizBaglanti()
              : GonderiEkrani(
                  yorumId: id,
                  // Bildirimden gelen yanıt yolu — bkz. [gonderiYolu].
                  yanitBildirimi: s.uri.queryParameters['yanit'] == '1',
                );
        },
      ),
      // Kendi gönderinin istatistikleri (md. 23) — göz ikonunun yanındaki
      // "istatistikleri gör" girişi buraya gelir. Kabuğun DIŞINDA tam ekran,
      // geri tuşu gönderiye döner. Uç yalnız SAHİBİNE cevap verir; başkası
      // derin bağlantıyla girerse ekran "gönderi bulunamadı" der (404 —
      // 403 varlığı ele verirdi).
      //
      // NEDEN `/gonderi/:id/istatistik` DEĞİL: robots.txt ön ek kuralları
      // JOKER İÇERMİYOR (seo_gizlilik.test.js bunu kilitliyor) ve id ORTADA
      // olan bir yol ön ekle kapatılamaz — `Disallow: /gonderi/` yazsaydık
      // SSR ile indekslenen `/gonderi/123` sayfası da kapanırdı. Kök yol,
      // `/favori-oyuncular` ve `/yapimlar/` ile aynı gerekçe.
      GoRoute(
        path: '/gonderi-istatistik/:id',
        builder: (_, s) {
          final id = int.tryParse(s.pathParameters['id'] ?? '');
          return id == null
              ? const _GecersizBaglanti()
              : GonderiIstatistikEkrani(gonderiId: id);
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
      // --- Sesli/görüntülü arama (KABUĞUN DIŞINDA: tam ekran, alt menü yok) ---
      // Giden arama. `tur` sorgu parametresi ('ses' | 'goruntu'), `extra`
      // karşı tarafın avatar yolu (varsa; yoksa harf baş harfi çizilir).
      GoRoute(
        path: '/gorusme/:ad',
        builder: (_, s) => GidenAramaSayfasi(
          kullaniciAdi: s.pathParameters['ad']!,
          tur: s.uri.queryParameters['tur'] == 'goruntu' ? 'goruntu' : 'ses',
          avatar: s.extra as String?,
        ),
      ),
      // Gelen arama. Parametre YOK: teklif SDP'si bildirime sığmaz (FCM veri
      // sınırı 4 KB), ekran açılınca `GET /arama/gelen` ile çekilir. Böylece
      // bildirimden açılan yol ile ön plan yoklamasının açtığı yol AYNI.
      GoRoute(
        path: gelenAramaYolu,
        builder: (_, _) => const GelenAramaSayfasi(),
      ),
      GoRoute(path: '/ayarlar', builder: (_, __) => const AyarlarEkrani()),
      // Ayarlar > Gizlilik > Gizlenen yorumlar. Kabuğun DIŞINDA: ayarların
      // kendisi gibi tam ekran açılır, geri tuşu ayarlara döner.
      GoRoute(
        path: '/gizlenen-yorumlar',
        builder: (_, __) => const GizlenenYorumlarEkrani(),
      ),
      // Ayarlar > Gizlilik > Engellenen kullanıcılar. Gizlenen yorumlarla
      // AYNI kural: kabuğun DIŞINDA tam ekran, geri tuşu ayarlara döner.
      GoRoute(
        path: '/engellenenler',
        builder: (_, _) => const EngellenenKullanicilarEkrani(),
      ),
      // Ayarlar > İstatistiklerim (md. 24). Gizlenen yorumlar/engellenenler ile
      // AYNI kural: kabuğun DIŞINDA tam ekran, geri tuşu ayarlara döner.
      GoRoute(
        path: '/istatistiklerim',
        builder: (_, _) => const IstatistiklerimEkrani(),
      ),
      // Ayarlar > Hareketlerim (md. 20). Gizlenen yorumlar/engellenenler ile
      // AYNI kural: kabuğun DIŞINDA tam ekran, geri tuşu ayarlara döner.
      // `?tur=` süzgeci derin bağlantıyla açılabilir (/hareketlerim?tur=begeni).
      GoRoute(
        path: '/hareketlerim',
        builder: (_, s) =>
            HareketlerimEkrani(tur: s.uri.queryParameters['tur']),
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
      // Oyuncunun yapımları + izlendi/izlenmedi listesi.
      //
      // NEDEN `/kisi/:id/yapimlar` DEĞİL: liste KİŞİYE ÖZEL (kimin neyi
      // izlediği) ve oturum ister; robots.txt ile kapatılması gerekiyor.
      // `Disallow` kuralları bu projede joker İÇERMEZ (bkz.
      // backend/test/seo_gizlilik.test.js `kapali`), yani `/kisi/*/yapimlar`
      // yazılamaz; `/kisi/` ön ekini kapatmak ise SSR ile indekslenen oyuncu
      // sayfalarını kapatırdı. Kök yol olunca `Disallow: /yapimlar/` yetiyor
      // ve `/izlediklerim` ile aynı kalıba oturuyor.
      // Yan fayda: `acikYolOnEkleri` dışında kaldığı için oturumsuz ziyaretçi
      // `/giris?donus=/yapimlar/500`e gider, hedefini kaybetmez.
      // `extra`: oyuncunun adı (başlık için); yoksa "Yapımları" yazar.
      GoRoute(
        path: '/yapimlar/:id',
        builder: (_, s) {
          final id = int.tryParse(s.pathParameters['id'] ?? '');
          return id == null
              ? const _GecersizBaglanti()
              : KisiYapimlariEkrani(kisiId: id, kisiAdi: s.extra as String?);
        },
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
