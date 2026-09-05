/// dizi.jpg'nin MEDYA FİLTRELERİ — fotoğraf ve video için TEK kaynak
/// (MEDYA-EDITOR-PLANI §G2 + gönderi medya editörü, 5 Eyl 2026).
///
/// NEDEN KENDİ MATRİSLERİMİZ, PAKETİN 46 HAZIR FİLTRESİ DEĞİL:
/// 1. `pro_image_editor`ün Instagram taklidi 46 filtresi 46 çeviri anahtarı
///    × 45 dil demek (§3.4 "gizli en büyük maliyet"). Kullanıcının istediği
///    on kategori (Orijinal, Sıcak, Soğuk, Sinematik, Retro, Vintage, Siyah
///    Beyaz, Canlı, Soluk, Analog) onda birine iniyor.
/// 2. Aynı filtre VİDEOYA da uygulanıyor. `pro_video_editor` renk filtresini
///    yine 4×5 renk matrisi olarak alıyor (`ApplyColorMatrix.kt`: 20 eleman,
///    kaydırma sütunu 0-255 ölçeğinde, süresiz filtreler matris çarpımıyla
///    tek LUT'a indiriliyor). Yani foto ile video AYNI sayılarla aynı görünür.
/// 3. Bu dosya SAF DART: `pro_image_editor` import etmez. Etmesi, ertelenmiş
///    editör parçasını (`gorsel_duzenle_editor.dart`) `main.dart.js`e geri
///    çekerdi (oradaki "SINIRIN KURALI"). Video editörü ana pakette yaşıyor ve
///    filtre adlarına/matrislerine oradan erişiyor.
///
/// MATRİS BİÇİMİ: Flutter `ColorFilter.matrix` ile birebir aynı — 20 eleman,
/// satır satır `[R', G', B', A']`, her satır `[r, g, b, a, kaydırma]`;
/// kaydırma 0-255 ölçeğinde. Formüller `pro_image_editor`ün
/// `ColorFilterAddons` sınıfının aynısı (parlaklık/kontrast/doygunluk/
/// sıcaklık/sepya/gri/soluk) — böylece editörün ekranda gösterdiği önizleme
/// ile burada üretilen video matrisi arasında fark olmaz.
library;

import 'ceviri.dart';

/// 4×5 renk matrisi (20 eleman).
typedef RenkMatrisi = List<double>;

/// Birim matris — hiçbir şey değiştirmez.
const RenkMatrisi birimMatris = [
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0, //
  0, 0, 1, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// Parlaklık. Aralık -1..1; pozitifte 0-100, negatifte 0-255 kaydırma
/// (paketle aynı asimetri: karartma daha geniş adımla çalışır).
RenkMatrisi parlaklikMatrisi(double deger) {
  final k = deger <= 0 ? deger * 255 : deger * 100;
  if (k == 0) return birimMatris;
  return [
    1, 0, 0, 0, k, //
    0, 1, 0, 0, k, //
    0, 0, 1, 0, k, //
    0, 0, 0, 1, 0, //
  ];
}

/// Kontrast. Aralık -1..1.
RenkMatrisi kontrastMatrisi(double deger) {
  final ayar = deger * 255;
  final carpan = (259 * (ayar + 255)) / (255 * (259 - ayar));
  final kaydirma = 128 * (1 - carpan);
  return [
    carpan, 0, 0, 0, kaydirma, //
    0, carpan, 0, 0, kaydirma, //
    0, 0, carpan, 0, kaydirma, //
    0, 0, 0, 1, 0, //
  ];
}

/// Doygunluk. Aralık -1..1 (pozitif tarafta 3 kat dik — paketle aynı).
RenkMatrisi doygunlukMatrisi(double deger) {
  if (deger == 0) return birimMatris;
  final x = 1 + (deger > 0 ? 3 * deger : deger);
  final t = 1 - x;
  const lr = 0.3086, lg = 0.6094, lb = 0.082;
  return [
    lr * t + x, lg * t, lb * t, 0, 0, //
    lr * t, lg * t + x, lb * t, 0, 0, //
    lr * t, lg * t, lb * t + x, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

/// Sıcaklık. Pozitif ısıtır (kırmızı+yeşil), negatif soğutur (mavi).
RenkMatrisi sicaklikMatrisi(double deger) {
  final r = deger > 0 ? deger : 0.0;
  final b = deger < 0 ? -deger : 0.0;
  return [
    1 + r, 0, 0, 0, 0, //
    0, 1 + r * 0.5, 0, 0, 0, //
    0, 0, 1 + b, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

/// Sepya. Aralık 0..1.
RenkMatrisi sepyaMatrisi(double deger) => [
  1 - 0.607 * deger, 0.769 * deger, 0.189 * deger, 0, 0, //
  0.349 * deger, 1 - 0.314 * deger, 0.168 * deger, 0, 0, //
  0.272 * deger, 0.534 * deger, 1 - 0.869 * deger, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// Gri tonlama (Rec. 709 parlaklık ağırlıkları).
const RenkMatrisi griMatris = [
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// Soluk (fade): kontrastı düşürür, siyah noktayı yükseltir. Aralık 0..1.
RenkMatrisi solukMatrisi(double deger) {
  if (deger == 0) return birimMatris;
  final carpan = 1 - 0.2 * deger;
  final kaldirma = 30 * deger;
  return [
    carpan, 0, 0, 0, kaldirma, //
    0, carpan, 0, 0, kaldirma, //
    0, 0, carpan, 0, kaldirma, //
    0, 0, 0, 1, 0, //
  ];
}

/// İki matrisi BİRLEŞTİRİR: [sonra] ∘ [once] (önce [once] uygulanır).
///
/// 4×5 matris, son satırı `[0 0 0 0 1]` olan 5×5 afin dönüşümdür; çarpım
/// standart. Video motoru zaten böyle birleştiriyor
/// (`ApplyColorMatrix.kt: combineMatrices`); önizlemede `ColorFiltered`
/// katmanlarını iç içe yerleştirmek yerine tek matris vermek için burada da
/// aynı işlem var.
RenkMatrisi matrisBirlestir(RenkMatrisi once, RenkMatrisi sonra) {
  assert(once.length == 20 && sonra.length == 20);
  final sonuc = List<double>.filled(20, 0);
  for (var satir = 0; satir < 4; satir++) {
    for (var sutun = 0; sutun < 5; sutun++) {
      var toplam = 0.0;
      for (var k = 0; k < 4; k++) {
        toplam += sonra[satir * 5 + k] * once[k * 5 + sutun];
      }
      // Kaydırma sütununda [once]nin 5. satırı 1'dir → [sonra]nın
      // kaydırması olduğu gibi eklenir.
      if (sutun == 4) toplam += sonra[satir * 5 + 4];
      sonuc[satir * 5 + sutun] = toplam;
    }
  }
  return sonuc;
}

/// Bir matris listesini SIRAYLA uygulayan tek matris. Boş liste → birim.
RenkMatrisi matrisleriBirlestir(List<RenkMatrisi> matrisler) {
  var sonuc = birimMatris;
  for (final m in matrisler) {
    sonuc = matrisBirlestir(sonuc, m);
  }
  return sonuc;
}

/// Bir filtre: kalıcı kimlik + görünen ad anahtarı + sırayla uygulanan
/// matrisler.
///
/// [kimlik] ASLA çevrilmez ve ASLA değişmez — kullanıcının kararı
/// (`VideoKirpma.filtre`) bu kimlikle saklanır; ad değişse de karar geçerli
/// kalır. [ad] Türkçe çeviri anahtarıdır (`'Sıcak'.c`).
class MedyaFiltresi {
  final String kimlik;
  final String ad;
  final List<RenkMatrisi> matrisler;

  const MedyaFiltresi({
    required this.kimlik,
    required this.ad,
    required this.matrisler,
  });

  /// Görünen ad (çevrili).
  String get etiket => ad.c;

  /// Hiçbir şey değiştirmeyen "Orijinal" mi?
  bool get orijinal => matrisler.isEmpty;

  /// Tüm adımlar tek matriste — video motoru ve `ColorFiltered` önizlemesi
  /// için.
  RenkMatrisi get matris => matrisleriBirlestir(matrisler);
}

/// "Orijinal" filtresinin kimliği. `VideoKirpma.filtre == null` ile eş
/// anlamlı; kullanıcı arayüzünde ilk sırada.
const orijinalFiltreKimligi = 'orijinal';

/// Uygulamanın filtre seti — SIRA ARAYÜZ SIRASIDIR.
///
/// Değerler gözle kalibre edildi: her filtre tanınabilir ama fotoğrafı
/// "yıkamayacak" kadar ölçülü. Yoğunluğu kullanıcı ayarlıyor (foto editörde
/// kaydırıcı; videoda önizleme zaten tam yoğunluk).
final List<MedyaFiltresi> medyaFiltreleri = [
  const MedyaFiltresi(
    kimlik: orijinalFiltreKimligi,
    ad: 'Orijinal',
    matrisler: [],
  ),
  MedyaFiltresi(
    kimlik: 'sicak',
    ad: 'Sıcak',
    matrisler: [sicaklikMatrisi(0.14), doygunlukMatrisi(0.08)],
  ),
  MedyaFiltresi(
    kimlik: 'soguk',
    ad: 'Soğuk',
    matrisler: [sicaklikMatrisi(-0.16), parlaklikMatrisi(0.03)],
  ),
  MedyaFiltresi(
    kimlik: 'sinematik',
    ad: 'Sinematik',
    matrisler: [
      kontrastMatrisi(0.16),
      doygunlukMatrisi(-0.18),
      sicaklikMatrisi(-0.06),
    ],
  ),
  MedyaFiltresi(
    kimlik: 'retro',
    ad: 'Retro',
    matrisler: [
      sepyaMatrisi(0.35),
      kontrastMatrisi(0.08),
      parlaklikMatrisi(0.03),
    ],
  ),
  MedyaFiltresi(
    kimlik: 'vintage',
    ad: 'Vintage',
    matrisler: [sepyaMatrisi(0.5), solukMatrisi(0.4), doygunlukMatrisi(-0.1)],
  ),
  MedyaFiltresi(
    kimlik: 'siyahbeyaz',
    ad: 'Siyah Beyaz',
    matrisler: [griMatris, kontrastMatrisi(0.08)],
  ),
  MedyaFiltresi(
    kimlik: 'canli',
    ad: 'Canlı',
    matrisler: [doygunlukMatrisi(0.3), kontrastMatrisi(0.1)],
  ),
  MedyaFiltresi(
    kimlik: 'soluk',
    ad: 'Soluk',
    matrisler: [solukMatrisi(0.6), doygunlukMatrisi(-0.2)],
  ),
  MedyaFiltresi(
    kimlik: 'analog',
    ad: 'Analog',
    matrisler: [
      kontrastMatrisi(0.12),
      solukMatrisi(0.25),
      sicaklikMatrisi(0.06),
      doygunlukMatrisi(-0.05),
    ],
  ),
];

/// Kimlikten filtre; tanınmayan ya da `null` kimlikte `null` (= Orijinal).
///
/// Tanınmayan kimlik SESSİZCE Orijinal sayılır: eski bir taslakta artık var
/// olmayan bir filtre kalsa bile kullanıcının videosu yüklenir, hata vermez.
MedyaFiltresi? medyaFiltresi(String? kimlik) {
  if (kimlik == null || kimlik == orijinalFiltreKimligi) return null;
  for (final f in medyaFiltreleri) {
    if (f.kimlik == kimlik) return f.orijinal ? null : f;
  }
  return null;
}
