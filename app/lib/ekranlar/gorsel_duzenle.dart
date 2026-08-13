import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import '../ceviri.dart';
import '../tema.dart';

/// Görsel düzenleme adımı (MEDYA-EDITOR-PLANI §G1).
///
/// TEK GİRİŞ NOKTASI: [gorselDuzenle] bayt alır, bayt döner; kullanıcı
/// vazgeçerse `null`. `gorsel_kirp.dart`'taki `gorselKirp` ile AYNI imza
/// felsefesi — çağıran taraf hiçbir editör tipini tanımak zorunda değil.
///
/// NEDEN AYRI DOSYA: avatar/kapak akışı (`gorsel_kirp.dart`, sabit oran +
/// dairesel maske + "yeniden konumlandır") çalışıyor ve sahada hata düzeltmesi
/// gördü; ona DOKUNULMADI. Bu dosya yorum/DM/Reels hattının editörüdür.
///
/// ÇIKTI SÖZLEŞMESİ (sunucuyla): `POST /medya` sihirli baytla tür doğruluyor
/// (`server.js:3096` RESIM_TURLERI → GIF8 / \x89PNG / FFD8FF / RIFF…WEBP).
/// Bu yüzden editörden dönen baytlar [gorselTuru] ile BURADA da doğrulanır;
/// tanınmayan bir bayt dizisi sunucuya hiç gönderilmez, kullanıcıya hata
/// gösterilir. "JPEG üretir herhâlde" varsayımı yasak — kontrol kodda.

/// Düzenlenmiş çıktının üst sınırı.
///
/// 13 Ağu 2026 — GEREKÇESİ DÜZELTİLDİ (madde 54). Eskiden burada "istemcinin
/// yorum eki sınırıyla (30 MB, `yorumlar.dart:_ekAzamiBayt`) AYNI" yazıyordu;
/// o sabit ARTIK YOK. 7 Ağu 2026'da yükleme hattı `medya_yukle.dart`'ta
/// birleştirildi ve sınırlar KODDAN doğrulandı:
/// * `medya_yukle.dart:medyaAzamiBayt` = `videoAzamiBayt` = **100 MB / dosya**
/// * `medya_yukle.dart:medyaToplamAzamiBayt` = **100 MB / gönderi**
/// * `server.js:5289` `express.raw({limit:'100mb'})`, nginx 105m
///
/// Yani gerçek tavan 30 değil 100 MB. Bu sabit yine de 30 MB'da duruyor ve
/// artık DÜRÜST bir gerekçesi var: burası tek bir DÜZENLENMİŞ görselin
/// tavanı. 30 MB'lık tek bir görsel gönderi başına 100 MB'lık toplam
/// bütçenin üçte birini yer ve mobil veriyle yüklenmesi dakikalar sürer;
/// editörden böyle bir dosya çıkıyorsa (yalnız saydam=PNG hattında mümkün)
/// doğru cevap onu göndermek değil, [pngSigdir] ile küçültmektir.
const gorselDuzenleAzamiBayt = 30 * 1024 * 1024;

/// Editörün üreteceği en büyük kenar.
///
/// 13 Ağu 2026 — **2000 → 4096** (madde 35a, "kendi bozduğumuzu bozmamak").
/// 2000 px `pro_image_editor`ün PAKET VARSAYILANIYDI; hiç gözden geçirilmemişti
/// ve yanındaki gerekçe ("30 MB sınırının çok altında kalsın") 12 kat fazla
/// tedbirliydi. Canlıdaki gerçek dosyalarla ölçüldü:
///
/// | kaynak | bugünkü çıktı (2000) | 4096 ile |
/// |---|---|---|
/// | 4000×3000 foto, 4078 KB | 2000×1500, **752 KB** | 4000×3000, 2472 KB |
/// | 1344×2392 ekran görüntüsü, 2537 KB | 1124×2000, **597 KB** | dokunulmaz |
///
/// Yani düzenlenen her 12 MP fotoğrafın **piksellerinin %75'i** atılıyordu;
/// en büyük 300 yüklemenin 263'ü 2000 px'i aşıyor (262'si ekran görüntüsü —
/// orada 2000'e düşürmek doğrudan METNİ bulanıklaştırır). En kötü hâlde bile
/// çıktı 2,5 MB: [gorselDuzenleAzamiBayt] sınırının 12 katı altında.
///
/// BELLEK İTİRAZINA CEVAP: editör "Tamam"a basılmadan ÖNCE zaten tam
/// çözünürlüklü görseli çözüp ekranda tutuyor (`decode_image.dart`), yani
/// tepe bellek çoktan ödenmiş. Çıktıyı kısmak o tepeyi düşürmüyor, yalnız
/// son adımda detayı çöpe atıyor. 4096, X/Twitter'ın yükleme tavanıyla aynı.
const _azamiCikti = Size(4096, 4096);

/// SAYDAM (PNG) hattının en büyük kenarı — JPEG hattından bilinçli olarak
/// daha küçük.
///
/// NEDEN 4096 DEĞİL (madde 54): [_azamiCikti]'nın 4096 olabilmesinin tek
/// sebebi JPEG'in KAYIPLI olması — 12 MP bir fotoğraf kalite 92'de 2,5 MB'a
/// iniyor. PNG KAYIPSIZ; dosya boyutunun üst sınırını sıkıştırma değil
/// PİKSEL SAYISI belirliyor. Ham RGBA hesabı (PNG bundan büyük olamaz,
/// deflate en kötü hâlde "stored" bloğa düşer):
///
/// | kenar | piksel | ham RGBA = PNG tavanı |
/// |---|---|---|
/// | 4096 | 16,8 MP | **67 MB** — 30 MB sınırının 2 katı üstü |
/// | 2896 | 8,4 MP | 33,5 MB — hâlâ üstünde |
/// | 2048 | 4,2 MP | **16,8 MB** — 1,8 kat pay |
///
/// 2048 kalite kaybı DEĞİL, saydam içeriğin doğasına uygun bir tavan:
/// saydamlık taşıyan görsel = çıkartma/logo/grafik (ölçüldü, aşağıya bak),
/// fotoğraf değil. Telefon ekranı 1080 px geniş; 2048 zaten iki katı.
/// Ayrıca dünkü (12 Ağu) sürüme kadar HER çıktı 2000 px'e iniyordu.
///
/// Bu bir GARANTİ değil, ucuz bir sigorta: paketin ölçek kısıtı ekran
/// kutusu üzerinden çalıştığı için (`image_render_service.dart:85`, `max`
/// ile) uç en-boy oranlarında tavanı aşabiliyor. Kesin güvence
/// [pngSigdir]'de.
const _azamiSaydamCikti = Size(2048, 2048);

/// Saydamlık taramasında kullanılan örnek kenarı (px).
///
/// Tam çözünürlükte çözmek gerekmiyor: 4096² bir görselin RGBA'sı 67 MB;
/// 512² yalnız 1 MB ve tarama <5 ms. Küçültme ORTALAMA aldığı için tek bir
/// saydam piksel bile kaybolmuyor — 4096'lık bir görselde 8×8'lik bir
/// bloğun tek pikseli saydamsa örnekteki alfa 255 değil 251 çıkar.
const _saydamlikOrnekBoyu = 512;

/// PNG üretim ayarları — hem editör hattı hem [pngSigdir] BURADAN okur ki
/// küçültme sonrası kodlama editörünkiyle birebir aynı olsun.
///
/// `rawStraightRgba` ŞART: paketin varsayılanı `rawRgba` (ÖN ÇARPIMLI alfa)
/// ve paketin kendi belgesi diyor ki ön çarpımlı alfa yarı saydam kenarlarda
/// KOYU HALE (dark fringing) bırakır. Saydamlığı koruyup kenarını
/// karartmak, düzeltmeye çalıştığımız hatanın daha sinsi bir sürümü olurdu.
///
/// `paeth` süzgeci: paketin varsayılanı `PngFilter.none`, yani satır süzgeci
/// hiç uygulanmıyor ve deflate'in işi zorlaşıyor. Paeth PNG'nin standart
/// süzgeci; dosya boyutunu düşürmek bu maddede birinci derece risk olduğu
/// için CPU'yu değil boyutu optimize ediyoruz.
const _saydamUretim = ImageGenerationConfigs(
  outputFormat: OutputFormat.png,
  captureImageByteFormat: ui.ImageByteFormat.rawStraightRgba,
  pngFilter: PngFilter.paeth,
  maxOutputSize: _azamiSaydamCikti,
);

/// Sunucunun kabul ettiği görsel türleri (istemci ikizi).
enum GorselTur {
  jpeg,
  png,
  gif,
  webp,

  /// Sunucunun `RESIM_TURLERI` listesinde karşılığı yok → yüklenemez.
  bilinmeyen,
}

/// Sihirli bayttan tür çıkarır. `server.js:3096-3105` ile BİREBİR aynı
/// kontroller; uzantıya değil içeriğe bakar.
GorselTur gorselTuru(Uint8List v) {
  if (v.length < 12) return GorselTur.bilinmeyen;
  if (v[0] == 0x47 && v[1] == 0x49 && v[2] == 0x46 && v[3] == 0x38) {
    return GorselTur.gif;
  }
  if (v[0] == 0x89 && v[1] == 0x50 && v[2] == 0x4E && v[3] == 0x47) {
    return GorselTur.png;
  }
  if (v[0] == 0xFF && v[1] == 0xD8 && v[2] == 0xFF) return GorselTur.jpeg;
  if (v[0] == 0x52 &&
      v[1] == 0x49 &&
      v[2] == 0x46 &&
      v[3] == 0x46 &&
      v[8] == 0x57 &&
      v[9] == 0x45 &&
      v[10] == 0x42 &&
      v[11] == 0x50) {
    return GorselTur.webp;
  }
  return GorselTur.bilinmeyen;
}

/// GIF sihirli baytı. `gorsel_kirp.dart:gifMi` ile aynı kural, tek kaynaktan:
/// GIF **düzenlenmez**, çünkü editör tuvali tek kare üretir ve animasyon ölür.
bool gifBaytlari(Uint8List v) => gorselTuru(v) == GorselTur.gif;

/// Bu baytlar editöre girebilir mi? Yalnız TEK KARELİ görseller girer.
///
/// * GIF → hayır (animasyon kaybolur).
/// * Video/ses/bilinmeyen → hayır (bu editör görsel editörüdür; video V1'de).
/// * JPEG / PNG / WebP → evet.
bool duzenlenebilirMi(Uint8List v) {
  final t = gorselTuru(v);
  return t == GorselTur.jpeg || t == GorselTur.png || t == GorselTur.webp;
}

// --- SAYDAMLIK (madde 54) ------------------------------------------------
//
// SORUN: saydam PNG editöre girip JPEG çıkıyordu ve saydam alanlar BEYAZ
// oluyordu (`pro_image_editor`ün `jpegBackgroundColor` varsayılanı beyaz).
// Kullanıcı bunu ancak yükledikten sonra görüyordu — sessiz bozulma.
//
// ÇÖZÜM: çıktı formatı GİRDİYE göre dallanıyor. Saydamlık VARSA çıktı PNG,
// yoksa (bugünkü gibi) JPEG kalite 92 / yuv444.

/// Bu baytlar saydamlık TAŞIYABİLİR mi? Ucuz, senkron, hiçbir şey çözmez —
/// yalnız başlık/yığın okur.
///
/// Bu bir ÖN ELEME: `false` dönerse görselde kesinlikle saydam piksel YOKTUR
/// (JPEG'de alfa kanalı diye bir şey yok, alfasız PNG'de de). `true` dönmesi
/// "olabilir" demektir; kesin cevabı [saydamlikVar] verir.
@visibleForTesting
bool saydamlikTasiyabilir(Uint8List v) {
  switch (gorselTuru(v)) {
    case GorselTur.png:
      return _pngSaydamlikTasiyabilir(v);
    case GorselTur.webp:
      return _webpSaydamlikTasiyabilir(v);
    case GorselTur.jpeg:
    case GorselTur.gif:
    case GorselTur.bilinmeyen:
      return false;
  }
}

/// PNG: IHDR renk tipi + `tRNS` yığını.
///
/// Renk tipi (IHDR gövdesinin 10. baytı = dosyanın 25. baytı):
/// 0 gri · 2 RGB · 3 palet · 4 gri+alfa · 6 RGBA.
///
/// 4 ve 6'nın alfa KANALI var. 0, 2 ve 3'ün yok ama `tRNS` yığını yine de
/// saydamlık taşır: palet PNG'de palet başına alfa, gri/RGB'de "şu renk
/// tamamen saydam" anahtarı. Ölçümde bu hiç de nadir değildi — taranan
/// 2934 PNG'nin 148'i palet+tRNS, 31'i RGB+tRNS, 4'ü gri+tRNS.
bool _pngSaydamlikTasiyabilir(Uint8List v) {
  if (v.length < 26) return false;
  // İlk yığın IHDR olmak ZORUNDA (PNG spec). Değilse dosya bozuk.
  if (v[12] != 0x49 || v[13] != 0x48 || v[14] != 0x44 || v[15] != 0x52) {
    return false;
  }
  final renkTipi = v[25];
  if (renkTipi == 4 || renkTipi == 6) return true; // gri+alfa / RGBA
  return _pngTrnsVar(v);
}

/// `tRNS` yığınını arar. IDAT'a ya da IEND'e gelince durur: spec `tRNS`in
/// IDAT'tan ÖNCE gelmesini şart koşuyor, sonrasını taramak boşuna.
bool _pngTrnsVar(Uint8List v) {
  var i = 8; // 8 baytlık imzadan sonra ilk yığın
  while (i + 8 <= v.length) {
    // 4 baytlık uzunluk BÜYÜK UÇLU. Kaydırma yerine çarpma: dart2js'te
    // `<<` 32 bit ve 0x80000000 sınırında işaret değiştirir.
    final uzunluk =
        v[i] * 16777216 + v[i + 1] * 65536 + v[i + 2] * 256 + v[i + 3];
    if (uzunluk < 0 || uzunluk > v.length) return false; // bozuk/kısa dosya
    final t0 = v[i + 4], t1 = v[i + 5], t2 = v[i + 6], t3 = v[i + 7];
    // 'tRNS'
    if (t0 == 0x74 && t1 == 0x52 && t2 == 0x4E && t3 == 0x53) return true;
    // 'IDAT' ya da 'IEND' → daha ileride tRNS olamaz.
    if (t0 == 0x49 && t1 == 0x44 && t2 == 0x41 && t3 == 0x54) return false;
    if (t0 == 0x49 && t1 == 0x45 && t2 == 0x4E && t3 == 0x44) return false;
    i += 12 + uzunluk; // uzunluk + tür + gövde + CRC
  }
  return false;
}

/// WebP: kapsayıcının ilk yığını belirler.
///
/// * `VP8X` (genişletilmiş) → 20. bayttaki bayrakların ALPHA biti (0x10).
/// * `VP8L` (kayıpsız) → alfa taşıyabilir, piksel taramasına bırak.
/// * `VP8 ` (kayıplı, tek başına) → alfa kanalı YOKTUR.
bool _webpSaydamlikTasiyabilir(Uint8List v) {
  if (v.length < 16) return false;
  final c0 = v[12], c1 = v[13], c2 = v[14], c3 = v[15];
  if (c0 == 0x56 && c1 == 0x50 && c2 == 0x38) {
    if (c3 == 0x58) return v.length > 20 && (v[20] & 0x10) != 0; // VP8X
    if (c3 == 0x4C) return true; // VP8L
  }
  return false;
}

/// Görselde GERÇEKTEN saydam piksel var mı? Çıktı formatı kararı BUNA bakar.
///
/// NEDEN BAŞLIK YETMİYOR — ÖLÇÜLDÜ (13 Ağu 2026, madde 54): kullanıcı
/// içeriğine benzeyen 793 PNG'lik örnekte RGBA (renk tipi 6) olan 603
/// dosyanın **142'si (%23,5) tamamen OPAK**. Bunlar tam da PNG'de tutmanın
/// en pahalı olduğu dosyalar:
///
/// | dosya | PNG | JPEG k92 |
/// |---|---|---|
/// | 1529×881 arka plan (RGBA, opak) | **1419 KB** | 249 KB (**5,7 kat**) |
/// | macOS ekran görüntüsü (RGBA, opak) | 23 KB | 13 KB |
///
/// macOS ekran görüntüsü RGBA çıkıyor ve HİÇ saydam pikseli yok. Bu dosyanın
/// [_azamiCikti] gerekçesinde ölçülmüştü: en büyük 300 yüklemenin 262'si
/// ekran görüntüsü. Yani "başlıkta alfa var → PNG" kuralı, yüklemelerin en
/// kalabalık sınıfını kat kat şişirirdi. Gerçek piksel taraması ŞART.
///
/// TERS YÖNDE HATA YAPMAZ: çözülemeyen bayt dizisinde `true` döner —
/// saydamlığı korumak (büyük dosya) beyaza boyamaktan (bozuk görsel) iyidir.
Future<bool> saydamlikVar(Uint8List veri) async {
  if (!saydamlikTasiyabilir(veri)) return false;
  ui.Codec? kodek;
  ui.Image? gorsel;
  try {
    kodek = await ui.instantiateImageCodec(
      veri,
      targetWidth: _saydamlikOrnekBoyu,
      targetHeight: _saydamlikOrnekBoyu,
      // Küçük görseli BÜYÜTME (varsayılan `true`): 32×32 bir çıkartmayı
      // 512×512'ye çıkarmak 256 kat gereksiz iş demek.
      allowUpscaling: false,
    );
    gorsel = (await kodek.getNextFrame()).image;
    final bayt = await gorsel.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (bayt == null) return true;
    final p = bayt.buffer.asUint8List(bayt.offsetInBytes, bayt.lengthInBytes);
    for (var i = 3; i < p.length; i += 4) {
      if (p[i] != 255) return true;
    }
    return false;
  } catch (_) {
    return true; // çözemedik → saydamlığı VARSAY (güvenli taraf)
  } finally {
    gorsel?.dispose();
    kodek?.dispose();
  }
}

/// PNG'nin IHDR genişliği; PNG değilse/bozuksa `null`.
int? _pngGenislik(Uint8List v) {
  if (v.length < 24 || gorselTuru(v) != GorselTur.png) return null;
  if (v[12] != 0x49 || v[13] != 0x48 || v[14] != 0x44 || v[15] != 0x52) {
    return null;
  }
  return v[16] * 16777216 + v[17] * 65536 + v[18] * 256 + v[19];
}

/// PNG çıktısını [gorselDuzenleAzamiBayt]'a SIĞDIRIR — saydamlığı KORUYARAK.
///
/// NEDEN JPEG'E DÜŞMÜYORUZ: JPEG'e düşmek saydam alanları beyaza boyamak,
/// yani maddenin tarif ettiği hatayı geri getirmek demek. Kullanıcının
/// kaybetmeyi göze alabileceği şey ÇÖZÜNÜRLÜK; alfa kanalı içeriğin
/// kendisi (çevresinde beyaz kutu olan bir çıkartma bozuk bir çıkartmadır).
/// Bu yüzden sıkışınca piksel atıyoruz, saydamlığı değil.
///
/// PNG boyutu piksel sayısıyla kabaca doğru orantılı; hedef kenarı
/// `sqrt(bütçe/boyut)` ile bir hamlede hesaplıyoruz (körlemesine yarıya
/// bölmek yerine), %15 emniyet payıyla. Tek küçültme yetmezse bir kez daha
/// denenir — her deneme yeniden kodlama demek ve saniyeler sürebilir.
///
/// HER KÜÇÜLTME ORİJİNALDEN yapılır (`png`, `sonuc` değil): arka arkaya
/// küçültmek yeniden örneklemeyi üst üste bindirip görüntüyü yumuşatırdı.
///
/// [butce] yalnız TEST için ayrı: üretimde 30 MB'lık bir PNG üretmek
/// gerekmesin diye. Testte küçük bir bütçeyle aynı kod yolu koşuluyor.
@visibleForTesting
Future<Uint8List> pngSigdir(
  Uint8List png, {
  int butce = gorselDuzenleAzamiBayt,
  int enKucukKenar = 256,
}) async {
  final asilGenislik = _pngGenislik(png);
  if (asilGenislik == null) return png;
  var sonuc = png;
  var genislik = asilGenislik;
  for (var deneme = 0; deneme < 2; deneme++) {
    if (sonuc.length <= butce || genislik <= enKucukKenar) break;
    final oran = math.sqrt(butce * 0.85 / sonuc.length);
    final hedef = (genislik * oran)
        .floor()
        .clamp(enKucukKenar, genislik - 1)
        .toInt();
    final kucuk = await _pngKucult(png, hedef);
    // Küçültme başarısız ya da işe yaramadıysa DÖNGÜYÜ BIRAK: elimizdeki
    // en iyi sonucu koru, sonsuza kadar yeniden kodlama.
    if (kucuk == null ||
        gorselTuru(kucuk) != GorselTur.png ||
        kucuk.length >= sonuc.length) {
      break;
    }
    sonuc = kucuk;
    genislik = hedef;
  }
  return sonuc;
}

/// [png]'yi [hedefGenislik] pikselde yeniden kodlar; alfa kanalı korunur.
///
/// Yeni eklenti YOK: çözme `dart:ui`, kodlama editörün zaten kullandığı
/// `ImageConverter`. `cropToDrawingBounds: false` ŞART — açıkken paket
/// saydam kenarları KIRPIYOR (`dart_ui_remove_transparent_image_areas.dart`)
/// ve çıkartmanın çerçevesi kayardı.
Future<Uint8List?> _pngKucult(Uint8List png, int hedefGenislik) async {
  ui.Codec? kodek;
  ui.Image? gorsel;
  try {
    kodek = await ui.instantiateImageCodec(
      png,
      targetWidth: hedefGenislik,
      allowUpscaling: false,
    );
    gorsel = (await kodek.getNextFrame()).image;
    return await ImageConverter.instance.uiImageToImageBytes(
      gorsel,
      configs: _saydamUretim.copyWith(
        maxOutputSize: Size.infinite, // ölçeği zaten çözerken verdik
        cropToDrawingBounds: false,
      ),
    );
  } catch (_) {
    return null;
  } finally {
    gorsel?.dispose();
    kodek?.dispose();
  }
}

/// İki bayt dizisi birebir aynı mı (kullanıcı gerçekten bir şey değiştirdi mi).
///
/// Editör `enableUseOriginalBytes` ile hiç değişiklik yapılmadıysa ORİJİNAL
/// baytları geri verir; o durumda "düzenlendi" rozeti göstermek yalan olur.
bool ayniBaytlar(Uint8List a, Uint8List b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Testler için: gerçek editörü açmadan akışı sürmeye yarar.
/// `null` döndüren bir sahte "kullanıcı vazgeçti" demektir.
@visibleForTesting
Future<Uint8List?> Function(BuildContext, Uint8List)? gorselDuzenleSahte;

/// Görsel düzenleme ekranını açar; **düzenlenmiş baytları** döner.
///
/// `null` dönüşün üç anlamı var, üçü de çağıran için aynı: **orijinali kullan**.
/// 1. Kullanıcı vazgeçti (X / geri).
/// 2. Kullanıcı hiçbir şey değiştirmeden "bitti"ye bastı.
/// 3. Girdi düzenlenemez (GIF, video, tanınmayan bayt) — bu durumda çağıran
///    zaten [duzenlenebilirMi] ile önceden eleyip kullanıcıyı bilgilendirmeli;
///    burada ikinci emniyet kemeri olarak sessizce `null` dönülür.
///
/// HATA: çıktı tanınmayan bir tür ya da [gorselDuzenleAzamiBayt]'ı aşıyorsa
/// SnackBar ile söylenir ve `null` dönülür — sessiz başarısızlık YOK.
///
/// ÇIKTI FORMATI GİRDİYE GÖRE (madde 54): girdide gerçekten saydam piksel
/// varsa çıktı PNG (saydamlık korunur), yoksa JPEG.
Future<Uint8List?> gorselDuzenle(BuildContext context, Uint8List veri) async {
  if (gorselDuzenleSahte != null) return gorselDuzenleSahte!(context, veri);
  if (!duzenlenebilirMi(veri)) return null;

  // Gezinme kancaları await'TEN ÖNCE alınır: `saydamlikVar` asenkron ve
  // arada widget sökülmüş olabilir (use_build_context_synchronously).
  final mesajci = ScaffoldMessenger.of(context);
  final gezgin = Navigator.of(context, rootNavigator: true);
  final saydam = await saydamlikVar(veri);

  final sonuc = await gezgin.push<Uint8List?>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _GorselDuzenleEkrani(veri: veri, saydam: saydam),
    ),
  );

  if (sonuc == null) return null;
  if (ayniBaytlar(sonuc, veri)) return null; // "bitti" dedi ama değiştirmedi

  // Sunucudaki sihirli bayt kapısının istemci ikizi: burada yakalanmayan
  // bozuk çıktı orada 400 olur ve kullanıcı nedenini asla öğrenemez.
  if (!duzenlenebilirMi(sonuc)) {
    _uyar(mesajci, 'Düzenlenemedi'.c);
    return null;
  }
  // PNG kayıpsız: sınırı yalnız bu hat zorlayabilir. Zorladıysa saydamlığı
  // koruyarak küçült — beyaza boyayıp göndermek YASAK (madde 54).
  var cikti = sonuc;
  if (cikti.length > gorselDuzenleAzamiBayt &&
      gorselTuru(cikti) == GorselTur.png) {
    cikti = await pngSigdir(cikti);
  }
  if (cikti.length > gorselDuzenleAzamiBayt) {
    _uyar(mesajci, 'Düzenlenen görsel çok büyük'.c);
    return null;
  }
  return cikti;
}

void _uyar(ScaffoldMessengerState mesajci, String metin) => mesajci
  ..clearSnackBars()
  ..showSnackBar(SnackBar(content: Text(metin)));

/// Editör ekranı. `pro_image_editor`ün kendi tam ekran widget'ını bizim
/// tema/dil/araç yapılandırmamızla sarar.
class _GorselDuzenleEkrani extends StatelessWidget {
  final Uint8List veri;

  /// Girdide gerçekten saydam piksel var mı ([saydamlikVar]).
  final bool saydam;

  const _GorselDuzenleEkrani({required this.veri, required this.saydam});

  @override
  Widget build(BuildContext context) {
    Uint8List? cikti;
    return ProImageEditor.memory(
      veri,
      configs: duzenleyiciYapilandirma(saydam: saydam),
      callbacks: ProImageEditorCallbacks(
        onImageEditingComplete: (bytes) async => cikti = bytes,
        // Tek çıkış kapısı: "bitti" de, "vazgeç" de buradan geçer. `cikti`
        // yalnız "bitti"de dolar → vazgeçince null döner ve ORİJİNAL korunur.
        onCloseEditor: (_) => Navigator.of(context).pop(cikti),
      ),
    );
  }
}

/// Editör yapılandırması. **Testler de bunu kullanır** — ekranda gördüğümüz
/// araçlarla test ettiğimiz araçlar ayrışmasın.
///
/// ÇEVİRİ MALİYETİ (MEDYA-EDITOR-PLANI §3.4, "gizli en büyük maliyet"):
/// paketin i18n yüzeyi 145 dize. Burada yalnız EKRANDA GÖRÜNEN dizeler
/// çevriliyor; görünmeyen her şey kapatılıyor:
/// * filtre + ton + bağımsız bulanıklık + sticker + ses + klip editörleri
///   `tools` listesine hiç alınmadı → 63 dize düştü (filtre ADLARI 46'sı).
/// * çizim araçlarından yalnız 7'si açık (nokta-çizgi, altıgen, çokgen,
///   çift-uçlu ok… kapalı) → 8 dize daha düştü.
/// * kırpma araçlarından `tilt` kapalı (perspektif düzeltme bir dizi
///   uygulamasında kullanılmaz) → 1 dize.
/// * yazı boyutu düğmesi kapalı; ölçek zaten katmanı iki parmakla
///   büyüterek yapılıyor → 1 dize.
/// Kalan dizelerin bir kısmı da uygulamada ZATEN VAR olan anahtarlara
/// bağlandı (İptal, Tamam, Geri al, Kaldır, Düzenle, Devam et).
///
/// [saydam] — girdide gerçekten saydam piksel var mı ([saydamlikVar])?
/// Yalnız çıktı formatını etkiler; araçlar/çeviri/tema aynıdır.
ProImageEditorConfigs duzenleyiciYapilandirma({bool saydam = false}) {
  const sari = DiziRenkler.sari;
  return ProImageEditorConfigs(
    // Editör tuvali DAİMA KOYU — açık temada da. Fotoğrafın algılanan
    // parlaklığı/rengi çevresindeki yüzeye göre kayar (simultane kontrast);
    // beyaz bir kabuk altında yapılan kırpma/çizim kararları yanlış olur.
    // Instagram, Snapseed, Lightroom: hepsi koyu tuval.
    theme: ThemeData.dark().copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: sari,
        brightness: Brightness.dark,
        primary: sari,
        // Sarı üstüne DAİMA siyah (11:1, WCAG AAA) — tema.dart kuralı.
        onPrimary: Colors.black,
      ),
    ),
    i18n: _i18n(),
    mainEditor: const MainEditorConfigs(
      // G1 kapsamı: kırp/döndür/çevir, çizim (bulanıklaştır/pikselleştir
      // dahil), metin, emoji. Filtre/ton (G2) ve sticker (G3) SONRA.
      // Sıra bilinçli: kırpma en sık kullanılan iş, ilk sırada.
      tools: [
        SubEditorMode.cropRotate,
        SubEditorMode.paint,
        SubEditorMode.text,
        SubEditorMode.emoji,
      ],
    ),
    paintEditor: const PaintEditorConfigs(
      // SPOILER VE YÜZ GİZLEME bu üründe en katı kural — bulanıklaştır ve
      // pikselleştir bu yüzden birinci sınıf araç, listenin başında.
      tools: [
        PaintMode.blur,
        PaintMode.pixelate,
        PaintMode.freeStyle,
        PaintMode.arrow,
        PaintMode.rect,
        PaintMode.circle,
        PaintMode.eraser,
      ],
      initialPaintMode: PaintMode.blur,
      style: PaintEditorStyle(bottomBarActiveItemColor: sari),
    ),
    textEditor: const TextEditorConfigs(
      // Ölçek düğmesi kapalı: katman iki parmakla zaten büyütülüyor,
      // düğme hem yer kaplıyor hem 45 dilde bir dize daha demek.
      showFontScaleButton: false,
      style: TextEditorStyle(inputCursorColor: sari),
    ),
    cropRotateEditor: CropRotateEditorConfigs(
      tools: const [
        CropRotateTool.aspectRatio,
        CropRotateTool.rotate,
        CropRotateTool.flip,
        CropRotateTool.reset,
      ],
      // dizi.jpg içeriği dikey Reels ağırlıklı → 9:16 serbestin hemen ardından.
      // Oran etiketleri SAYI olduğu için çeviri gerektirmiyor (sektör
      // standardı); yalnız "Serbest" bir dize.
      aspectRatios: [
        AspectRatioItem(text: 'Serbest'.c, value: -1),
        const AspectRatioItem(text: '9:16', value: 9 / 16),
        const AspectRatioItem(text: '1:1', value: 1),
        const AspectRatioItem(text: '4:5', value: 4 / 5),
        const AspectRatioItem(text: '16:9', value: 16 / 9),
      ],
      style: const CropRotateEditorStyle(cropCornerColor: sari),
    ),
    // ÇIKTI FORMATI GİRDİYE GÖRE DALLANIR (madde 54, 13 Ağu 2026).
    //
    // Eskiden koşulsuz JPEG'di. JPEG'de alfa kanalı YOK; paket saydam
    // alanları `jpegBackgroundColor` ile dolduruyor ve varsayılanı BEYAZ.
    // Sonuç: editöre giren her çıkartma/logo beyaz kutuyla çıkıyordu ve
    // kullanıcı bunu ancak yükledikten sonra fark ediyordu.
    imageGeneration: saydam
        ? _saydamUretim
        // JPEG: sunucunun `RESIM_TURLERI` listesinde FFD8FF ile karşılığı
        // var, her cihazda aynı, PNG'den kat kat küçük. Kalite 92 → görsel
        // farkı yok, dosya ~%60 küçük. SAYDAMLIK YOKSA hâlâ doğru seçim:
        // ölçüldü, RGBA ama opak bir 1529×881 arka plan PNG'de 1419 KB,
        // JPEG k92'de 249 KB.
        : const ImageGenerationConfigs(
            outputFormat: OutputFormat.jpg,
            jpegQuality: 92,
            maxOutputSize: _azamiCikti,
          ),
  );
}

/// Ekranda GÖRÜNEN her dize buradan geçer; görünmeyen hiçbir dize
/// çevrilmedi (bkz. [duzenleyiciYapilandirma] açıklaması).
///
/// İKON-ONLY DÜĞMELERİN ERİŞİLEBİLİR ADI: paketin üst çubuğundaki geri/geri
/// al/yinele/bitti düğmeleri yalnız ikon; `tooltip` hem uzun basınca görünür
/// hem de ekran okuyucuya ad olur (ui-ux-pro-max, Accessibility/ARIA Labels —
/// severity HIGH: "Add aria-label for icon-only buttons"). Bu yüzden
/// tooltip'ler İngilizce bırakılmadı.
I18n _i18n() => I18n(
  cancel: 'İptal'.c,
  undo: 'Geri al'.c,
  redo: 'Yinele'.c,
  done: 'Tamam'.c,
  remove: 'Kaldır'.c,
  doneLoadingMsg: 'Hazırlanıyor…'.c,
  // Durum geçmişi içe aktarmıyoruz; boş dize paketin o diyaloğunu HİÇ
  // göstermemesini sağlar (`main_editor.dart:1252`).
  importStateHistoryMsg: '',
  various: I18nVarious(
    loadingDialogMsg: 'Hazırlanıyor…'.c,
    // Kapatma uyarısı: kullanıcı 10 dakikalık çizimi yanlışlıkla
    // kaybetmesin. Onay düğmesi YIKICI eylem, iptal düğmesi güvenli olan —
    // güvenli olan sağda değil solda değil, metinle ayrışıyor.
    closeEditorWarningTitle: 'Düzenlemeden çık?'.c,
    closeEditorWarningMessage: 'Yaptığın değişiklikler kaybolacak.'.c,
    closeEditorWarningConfirmBtn: 'Çık'.c,
    closeEditorWarningCancelBtn: 'Devam et'.c,
  ),
  layerInteraction: I18nLayerInteraction(
    remove: 'Kaldır'.c,
    edit: 'Düzenle'.c,
    rotateScale: 'Döndür'.c,
  ),
  cropRotateEditor: I18nCropRotateEditor(
    bottomNavigationBarText: 'Kırp'.c,
    rotate: 'Döndür'.c,
    flip: 'Yansıt'.c,
    ratio: 'Oran'.c,
    reset: 'Sıfırla'.c,
    back: 'İptal'.c,
    cancel: 'İptal'.c,
    done: 'Tamam'.c,
    undo: 'Geri al'.c,
    redo: 'Yinele'.c,
  ),
  paintEditor: I18nPaintEditor(
    bottomNavigationBarText: 'Çiz'.c,
    blur: 'Bulanıklaştır'.c,
    pixelate: 'Pikselleştir'.c,
    freestyle: 'Serbest çizim'.c,
    arrow: 'Ok'.c,
    rectangle: 'Dikdörtgen'.c,
    circle: 'Daire'.c,
    eraser: 'Silgi'.c,
    lineWidth: 'Çizgi kalınlığı'.c,
    strokeWidth: 'Çizgi kalınlığı'.c,
    changeOpacity: 'Saydamlık'.c,
    opacity: 'Saydamlık'.c,
    toggleFill: 'Dolgu'.c,
    fill: 'Dolgu'.c,
    color: 'Renk'.c,
    smallScreenMoreTooltip: 'Daha fazla'.c,
    back: 'İptal'.c,
    cancel: 'İptal'.c,
    done: 'Tamam'.c,
    undo: 'Geri al'.c,
    redo: 'Yinele'.c,
  ),
  textEditor: I18nTextEditor(
    bottomNavigationBarText: 'Metin'.c,
    inputHintText: 'Metin yaz...'.c,
    textAlign: 'Hizala'.c,
    backgroundMode: 'Arka plan'.c,
    smallScreenMoreTooltip: 'Daha fazla'.c,
    back: 'İptal'.c,
    done: 'Tamam'.c,
  ),
  emojiEditor: I18nEmojiEditor(
    bottomNavigationBarText: 'Emoji'.c,
    search: 'Emoji ara...'.c,
    categoryRecent: 'Son kullanılanlar'.c,
    categorySmileys: 'İfadeler ve insanlar'.c,
    categoryAnimals: 'Hayvanlar ve doğa'.c,
    categoryFood: 'Yiyecek ve içecek'.c,
    categoryActivities: 'Etkinlikler'.c,
    categoryTravel: 'Seyahat ve yerler'.c,
    categoryObjects: 'Nesneler'.c,
    categorySymbols: 'Semboller'.c,
    categoryFlags: 'Bayraklar'.c,
  ),
);
