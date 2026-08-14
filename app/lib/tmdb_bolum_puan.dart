import 'package:flutter/material.dart';

import 'tema.dart';

/// Bir bölümün TMDB puanı. [puan] null ise BÖLÜM VAR ama oyu yok — kutuda
/// "—" durur, 0.0 uydurulmaz. (Bölümün hiç olmaması ayrı durumdur: sezon
/// haritasında o numarada KAYIT bulunmaz ve hücre bomboş çizilir.)
class TmdbBolumPuani {
  final int bolumNo;
  final double? puan;
  final int oy;

  const TmdbBolumPuani({
    required this.bolumNo,
    required this.puan,
    required this.oy,
  });
}

/// Bir sezonun bölüm puanları (bölüm numarası → kayıt).
class TmdbSezonPuani {
  final int sezonNo;
  final Map<int, TmdbBolumPuani> bolumler;

  const TmdbSezonPuani({required this.sezonNo, required this.bolumler});
}

/// TMDB `seasons` listesinden özel sezonu (0) atarak sezon numaralarını üretir.
/// Liste boşsa `number_of_seasons` kadar 1…N döner.
List<int> tmdbSezonNolari(Map<String, dynamic> icerik) {
  final ham = icerik['seasons'];
  final nolar = <int>[];
  if (ham is List) {
    for (final s in ham) {
      if (s is! Map) continue;
      final n = s['season_number'];
      if (n is num && n.toInt() > 0) nolar.add(n.toInt());
    }
  }
  nolar.sort();
  if (nolar.isNotEmpty) return nolar;
  final adet = (icerik['number_of_seasons'] as num?)?.toInt() ?? 0;
  return [for (var i = 1; i <= adet; i++) i];
}

/// TMDB sezon yanıtındaki `episodes` dizisini haritaya çevirir.
Map<int, TmdbBolumPuani> tmdbBolumleriOku(Object? episodes) {
  final out = <int, TmdbBolumPuani>{};
  if (episodes is! List) return out;
  for (final e in episodes) {
    if (e is! Map) continue;
    final no = e['episode_number'];
    if (no is! num) continue;
    final oy = (e['vote_count'] as num?)?.toInt() ?? 0;
    final ortalama = (e['vote_average'] as num?)?.toDouble();
    out[no.toInt()] = TmdbBolumPuani(
      bolumNo: no.toInt(),
      puan: oy > 0 && ortalama != null ? ortalama : null,
      oy: oy,
    );
  }
  return out;
}

/// Izgaradaki en yüksek bölüm numarası (eksik bölümler boş hücre olur).
int tmdbMaxBolum(Iterable<TmdbSezonPuani> sezonlar) {
  var max = 0;
  for (final s in sezonlar) {
    for (final n in s.bolumler.keys) {
      if (n > max) max = n;
    }
  }
  return max;
}

/// Puan kutusunun zemini — ISI HARİTASI RAMPASI (6 kova + "oy yok" grisi).
///
/// KULLANICI (14 Ağu): *"daha CANLI renkler kullan"*. Eski palet (hardal
/// `#C9A227`, kiremit `#C2410C`) donuktu ÇÜNKÜ kutunun üstüne puan yazılıyordu
/// ve her kova 4,5:1 yazı kontrastı taşımak zorundaydı — bu, doygunluğu
/// kırpıyordu. Yazı kutudan çıkınca (bkz. `tmdb_puan_izgara.dart`, okuma
/// balonu) rampa serbest kaldı ve tam doygun tonlara geçildi.
///
/// KOVA SAYISI 4 → 6. Eski ≥7 TEK kovaydı; oysa dizilerin bölüm puanları
/// 7–9 arasında kümelenir, yani tipik bir dizinin ızgarası baştan aşağı TEK
/// renkti — hem donuk hem bilgisiz. 8 ve 9 eşikleri eklenince aynı dizide
/// üç ton birden görünür.
///
/// ÖLÇÜLEN PARLAKLIKLAR (WCAG relative luminance) — kova boyunca MONOTON
/// artar, yani gri tonlamada ve kırmızı-yeşil renk körlüğünde de sıralanır:
///   &lt;5 `#BE123C` 0,117 → 5 `#DC2626` 0,167 → 6 `#F97316` 0,325
///   → 7 `#F59E0B` 0,439 → 8 `#F5C518` 0,594 → 9+ `#D4F53B` 0,796
/// Komşu kovalar arası parlaklık oranı 1,30–1,72; ayrım yalnız RENGE değil
/// açıklığa da yaslanır.
///
/// 8–9 kovası bilerek marka sarısıdır (`DiziRenkler.sari`): rampa kimlikle
/// kavga etmesin, tersine onu içine alsın.
Color tmdbPuanKutuRengi(double? puan) {
  // OY YOK: rampanın dışında, NÖTR gri. Tema-duyarlı olmak ZORUNDA — eski
  // `koyuGri` (#17171A) koyu temada zeminle 1,4:1'di, yani "oyu yok" kutusu
  // "bölüm yok" boşluğundan ayırt edilemiyordu. Yeni tonlar zeminle 3:1 üstü:
  // koyu #5F5F69 → 3,12:1, açık #8C8C96 → 3,09:1.
  if (puan == null) {
    return DiziRenkler.acik ? const Color(0xFF8C8C96) : const Color(0xFF5F5F69);
  }
  if (puan >= 9) return const Color(0xFFD4F53B);
  if (puan >= 8) return const Color(0xFFF5C518);
  if (puan >= 7) return const Color(0xFFF59E0B);
  if (puan >= 6) return const Color(0xFFF97316);
  if (puan >= 5) return const Color(0xFFDC2626);
  return const Color(0xFFBE123C);
}

/// Kutunun 1 dp konturu: dolgunun %45'i tema metin rengine karıştırılır.
///
/// NEDEN GEREKLİ: dolgu tek başına İKİ temada birden 3:1 veremez. Parlak
/// tonlar (9+ `#D4F53B`) açık temada zeminle 1,15:1, koyu tonlar koyu temada
/// zayıf kalır — matematiksel olarak imkânsız: hem `#0B0B0D` hem `#F6F6F8`
/// karşısında 3:1 isteyen renk 0,11–0,28 parlaklık bandına sıkışır, o bant da
/// 6 kovalık monoton rampayı taşımaz. Çözüm WCAG 1.4.11'in kendi yolu:
/// nesnenin SINIRI kontrastlı olsun. Ölçülen kontur kontrastları — koyu
/// temada 6,59–17,32:1, açık temada 3,71–11,76:1 (en zayıfı 9+ kovası).
Color tmdbPuanKenarRengi(double? puan) => Color.lerp(
  tmdbPuanKutuRengi(puan),
  DiziRenkler.acik ? Colors.black : Colors.white,
  0.45,
)!;

/// Okuma balonundaki puan çipinin yazı rengi (çip zemini kova rengidir).
///
/// Izgara kutularında ARTIK YAZI YOK; bu renk yalnız bir hücre seçilince
/// açılan balonun içindeki puan çipinde kullanılır. Ölçülen kontrastlar:
/// 9+ 14,42:1 · 8 10,97:1 · 7 8,33:1 · 6 6,38:1 · 5 4,83:1 · &lt;5 6,29:1 ·
/// oy yok 6,31:1 (koyu) / 5,37:1 (açık) — hepsi 4,5:1 üstü.
Color tmdbPuanYaziRengi(double? puan) {
  if (puan == null) {
    return DiziRenkler.acik ? const Color(0xFF17171A) : Colors.white;
  }
  if (puan >= 6) return const Color(0xFF17171A);
  return Colors.white;
}

/// Gösterge (legend) satırının kovaları — yüksekten alçağa, sonda "oy yok".
///
/// ZORUNLU: ızgarada artık sayı yazmıyor, yani renk TEK BAŞINA anlam taşıyor
/// gibi görünür. Gösterge + hücreye dokununca açılan puan balonu + `Semantics`
/// etiketi, o anlamı renkten bağımsız üç ayrı kanaldan verir.
///
/// Etiketler sayı ya da simgedir (`9+`, `8`, `<5`, `—`) — çeviri anahtarı yok,
/// 45 dilde aynı okunur.
class TmdbPuanKovasi {
  final String etiket;

  /// Kovanın rengini üretmek için temsilci puan (`null` = oy yok).
  final double? ornek;

  const TmdbPuanKovasi(this.etiket, this.ornek);
}

const tmdbPuanKovalari = <TmdbPuanKovasi>[
  TmdbPuanKovasi('9+', 9.5),
  TmdbPuanKovasi('8', 8.5),
  TmdbPuanKovasi('7', 7.5),
  TmdbPuanKovasi('6', 6.5),
  TmdbPuanKovasi('5', 5.5),
  TmdbPuanKovasi('<5', 3.0),
  TmdbPuanKovasi('—', null),
];

/// Hücrede gösterilecek metin: `7.6` ya da (bölüm VAR, oyu yok) `—`.
///
/// HİÇ OLMAYAN bölüm buraya gelmez: ızgara o hücreyi tamamen boş çizer
/// (`tmdb_puan_izgara.dart`, `kayit == null` dalı). Ayrım bilinçli — "bölüm
/// yok" hiçbir şey, "puan yok" ise gri kutu içinde tire.
String tmdbPuanMetni(double? puan) =>
    puan == null ? '—' : puan.toStringAsFixed(1);
