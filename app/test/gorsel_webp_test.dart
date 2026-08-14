// GÖRSEL İSTEKLERİNDE WEBP PAZARLIĞI (md. 50)
//
// --- NEYİ KANITLIYOR ---
// TMDB görselleri BunnyCDN arkasında ve isteğin `Accept` başlığına göre biçim
// seçiyor. CANLI ÖLÇÜM (14 Ağu 2026, `w342/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg`):
//   başlıksız / `Accept: */*` → image/jpeg, 45.777 bayt
//   `Accept: image/webp,*/*`  → image/webp, 33.082 bayt
// Yani poster başına %27,7 tasarruf (CDN'in kendi `x-bo-compressionratio`
// başlığı da aynı oranı yazıyor); 30 posterlik bir ızgarada ~450 KB.
//
// Bu dosya o başlığın gerçekten GÖRSEL WIDGET'INA kadar gittiğini ve KENDİ
// sunucumuzun adreslerine GİTMEDİĞİNİ kilitler.
//
// --- NEDEN WIDGET TESTİ ŞART (CLAUDE.md md. 7) ---
// "Kodu okudum, doğru görünüyor" yetmez: `httpHeaders` unutulsa ya da yanlış
// parametreye yazılsa derleyici uyarmaz, ekran da bozulmaz — yalnızca tasarruf
// sessizce kaybolur. Burada hem ağaçtan geçen GERÇEK widget'ın başlığı okunuyor
// hem de kaynak taramasıyla "yeni eklenen çağrı noktası başlıksız kalmasın"
// güvencesi veriliyor.
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/gorsel_basliklari.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ölçümde kullanılan gerçek TMDB poster adresi.
const String _tmdbPosteri =
    'https://image.tmdb.org/t/p/w342/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg';

/// Kendi sunucumuzdaki bir avatar adresi.
const String _kendiAvatarimiz = '$apiTaban/avatarlar/avatar3-1723400000000.jpg';

/// Kendi sunucumuzdaki bir yorum medyası adresi.
const String _kendiMedyamiz = '$apiTaban/medya/m3-8cd6a45c0c5e643f.jpg';

/// [PosterKarti]'nı tek başına ayağa kaldırır: TMDB posteri çizen en sade
/// yüzey. `poster_path` dolu olduğu için kart gerçek bir `image.tmdb.org`
/// adresi kurar (118 dp kart + test yüzeyinin piksel oranı → `w342`).
Widget _posterKarti() => MaterialApp(
  home: Scaffold(
    body: PosterKarti(
      icerik: const <String, dynamic>{
        'id': 550,
        'title': 'Fight Club',
        'poster_path': '/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg',
      },
      turZorla: 'movie',
    ),
  ),
);

void main() {
  group('gorselBasliklari: kararı ADRES veriyor', () {
    test('TMDB adresi WebP başlığı ALIR', () {
      final b = gorselBasliklari(_tmdbPosteri);
      expect(b, isNotNull, reason: 'TMDB adresinde başlık null kalmamalı');
      expect(
        b!.containsKey('Accept'),
        isTrue,
        reason: 'Pazarlığı yapan başlık `Accept`tir',
      );
      expect(
        b['Accept'],
        contains('image/webp'),
        reason: 'CDN yalnız `image/webp` listedeyken WebP üretiyor',
      );
      expect(
        b['Accept'],
        contains('*/*'),
        reason:
            'WebP üretilemeyen görselde özgün biçime dönüş serbest kalmalı; '
            'aksi hâlde görsel boş kalabilirdi',
      );
    });

    test('KENDİ sunucumuzun adresleri başlık ALMAZ', () {
      // Gerekçe `gorsel_basliklari.dart` başlığında: backend yüklenen baytları
      // aynen servis ediyor (dönüştürme YOK), pazarlığın karşılığı yok.
      expect(gorselBasliklari(_kendiAvatarimiz), isNull);
      expect(gorselBasliklari(_kendiMedyamiz), isNull);
    });

    test('null adres başlık üretmez', () {
      // Çağıran yerlerde adres çoğu zaman `String?`; null kontrolünü burası
      // devraldığı için çağrı noktaları tek satırda kalıyor.
      expect(gorselBasliklari(null), isNull);
    });

    test('BENZER alan adı kanmaz (güvenlik)', () {
      // Ön ek karşılaştırması adresin BAŞINA bakar: "image.tmdb.org" ifadesini
      // içinde geçiren yabancı sunuculara başlık gitmez.
      expect(
        gorselBasliklari('https://image.tmdb.org.kotu.example/t/p/w342/a.jpg'),
        isNull,
      );
      expect(
        gorselBasliklari('https://kotu.example/image.tmdb.org/a.jpg'),
        isNull,
      );
      expect(
        gorselBasliklari('http://image.tmdb.org/t/p/w342/a.jpg'),
        isNull,
        reason: 'Projede düz HTTP yok; HTTP adresi pazarlık almaz',
      );
    });

    test('başlık DEĞERİ sabit ve enjeksiyona kapalı', () {
      // Aynı sabit örneğin dönmesi, değerin kullanıcı girdisinden
      // TÜRETİLMEDİĞİNİN kanıtı: her çağrıda yeniden kurulan bir harita değil.
      expect(gorselBasliklari(_tmdbPosteri), same(webpKabulBasliklari));
      for (final g in webpKabulBasliklari.entries) {
        expect(
          RegExp(r'[\r\n\x00]').hasMatch('${g.key}${g.value}'),
          isFalse,
          reason: 'Satır sonu taşıyan başlık = başlık enjeksiyonu',
        );
      }
    });
  });

  group('WIDGET KANITI: başlık gerçekten ağaçtan geçiyor', () {
    testWidgets('PosterKarti posteri `Accept: image/webp` ile istiyor', (
      tester,
    ) async {
      await tester.pumpWidget(_posterKarti());
      final gorsel = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(
        gorsel.httpHeaders?['Accept'],
        contains('image/webp'),
        reason:
            'Izgaradaki posterler başlıksız gidiyorsa JPEG iniyor demektir — '
            'poster başına ~%28 boşa gider',
      );
      // KISIT: başlık eklemek yer tutucu/hata yüzeylerini BOZMAMALI.
      expect(
        gorsel.placeholder,
        isNotNull,
        reason: 'Poster inerken kart boş/atlamalı kalmamalı',
      );
      expect(
        gorsel.errorWidget,
        isNotNull,
        reason: 'İnmeyen posterde kırık görsel ikonu çizilmeli',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('ADRES (önbellek anahtarı) değişmedi: boyut seçimi duruyor', (
      tester,
    ) async {
      // md. 50 YALNIZ başlık ekliyor. Adres değişseydi `cacheKey` de değişir ve
      // kullanıcının diskindeki bütün posterler yeniden inerdi.
      await tester.pumpWidget(_posterKarti());
      final gorsel = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(
        gorsel.imageUrl,
        _tmdbPosteri,
        reason:
            '118 dp kart `posterBoyutu()` ile w342 seçmeli; adres birebir '
            'eskisi kalmalı',
      );
    });

    testWidgets('KENDİ sunucumuzun avatarına başlık GÖNDERİLMİYOR', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KullaniciAvatari(
              url: _kendiAvatarimiz,
              kullaniciAdi: 'birisi',
            ),
          ),
        ),
      );
      final saglayici = tester
          .widget<CircleAvatar>(find.byType(CircleAvatar))
          .backgroundImage;
      expect(saglayici, isA<CachedNetworkImageProvider>());
      expect(
        (saglayici as CachedNetworkImageProvider).headers,
        isNull,
        reason:
            'Sunucumuz içerik pazarlığı yapmıyor: başlık tek bayt kazandırmaz, '
            'ama `Vary: Accept` taşımayan yanıt paylaşımlı önbellekte yanlış '
            'varyantı dolaştırabilir.',
      );
    });
  });

  group('KISIT: görsel önbelleği bozulmadı', () {
    test('başlık önbellek anahtarını DEĞİŞTİRMİYOR', () {
      // `CachedNetworkImageProvider` eşitliği yalnız (cacheKey ?? url), scale
      // ve maxWidth/maxHeight'e bakıyor — `headers` anahtarın parçası DEĞİL.
      // Paket bunu değiştirirse bu test kırmızıya döner ve haber verir.
      const eski = CachedNetworkImageProvider(_tmdbPosteri);
      final yeni = CachedNetworkImageProvider(
        _tmdbPosteri,
        headers: gorselBasliklari(_tmdbPosteri),
      );
      expect(yeni, eski);
      expect(yeni.hashCode, eski.hashCode);
      expect(yeni.url, eski.url);
      expect(yeni.cacheKey, isNull);
    });
  });

  group('GERİLEME KORUMASI: hiçbir çağrı noktası başlıksız kalmadı', () {
    /// `lib/` altındaki tüm Dart kaynakları.
    List<File> kaynaklar() => Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    test('her görsel çağrısı ya başlık taşır ya KENDİ medyamız', () {
      // KURAL (tek cümle): adresi bir DEĞİŞKENDEN gelen her görsel çağrısı
      // başlığı `gorselBasliklari()` ile alır; adresini yerinde `dosyaUrl()`
      // ile kuran noktalar KESİN olarak kendi sunucumuzdur ve bilinçli
      // atlanmıştır (pazarlık karşılıksız).
      final eksikler = <String>[];
      var baslikliNoktalar = 0;
      for (final dosya in kaynaklar()) {
        final kod = dosya.readAsStringSync();
        final desen = RegExp(r'CachedNetworkImage(Provider)?\(');
        for (final eslesme in desen.allMatches(kod)) {
          final son = eslesme.start + 500;
          final pencere = kod.substring(
            eslesme.start,
            son > kod.length ? kod.length : son,
          );
          if (pencere.contains('gorselBasliklari')) {
            baslikliNoktalar++;
          } else if (!pencere.contains('dosyaUrl(')) {
            final satir = kod.substring(0, eslesme.start).split('\n').length;
            eksikler.add('${dosya.path}:$satir');
          }
        }
      }
      expect(
        eksikler,
        isEmpty,
        reason:
            'Şu çağrı noktaları TMDB adresi alabilir ama başlık vermiyor; WebP '
            'tasarrufu oralarda kayboluyor:\n${eksikler.join('\n')}',
      );
      // Test BOŞA geçmesin: tarama gerçekten çağrı noktası görmüş olmalı.
      expect(
        baslikliNoktalar,
        greaterThanOrEqualTo(40),
        reason:
            'Beklenen ~46 başlıklı çağrı noktası bulunamadı — tarama yanlış '
            'dizinde koşuyor ya da başlıklar toptan kaldırılmış.',
      );
    });

    test('başlık haritası TEK yerde tanımlı (kopyalanmamış)', () {
      // Aynı `Accept` değerinin ikinci bir yerde elle yazılması, yarın değeri
      // güncellerken bir kopyanın geride kalması demektir.
      final kopyalar = <String>[];
      for (final dosya in kaynaklar()) {
        if (dosya.path.endsWith('gorsel_basliklari.dart')) continue;
        // Yorum satırları sayılmaz: gerekçe metinlerinde `image/webp` geçebilir.
        final kodSatirlari = dosya
            .readAsLinesSync()
            .where((s) => !s.trimLeft().startsWith('//'))
            .join('\n');
        if (kodSatirlari.contains("'Accept'") ||
            kodSatirlari.contains('image/webp,')) {
          kopyalar.add(dosya.path);
        }
      }
      expect(
        kopyalar,
        isEmpty,
        reason:
            '`Accept` başlığı `gorsel_basliklari.dart` DIŞINDA da yazılmış: '
            '${kopyalar.join(', ')}',
      );
    });
  });
}
