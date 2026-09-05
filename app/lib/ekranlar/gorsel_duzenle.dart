import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../ceviri.dart';
// ERTELENEN PARÇA. `deferred` anahtar sözcüğü olmadan bu satır tüm
// `pro_image_editor` paketini `main.dart.js` içine geri çeker; oradaki dosya
// başındaki "SINIRIN KURALI" bölümünü okumadan buraya dokunma.
import 'gorsel_duzenle_editor.dart' deferred as editor;

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

/// Saydamlık taramasında kullanılan örnek kenarı (px).
///
/// Tam çözünürlükte çözmek gerekmiyor: 4096² bir görselin RGBA'sı 67 MB;
/// 512² yalnız 1 MB ve tarama <5 ms. Küçültme ORTALAMA aldığı için tek bir
/// saydam piksel bile kaybolmuyor — 4096'lık bir görselde 8×8'lik bir
/// bloğun tek pikseli saydamsa örnekteki alfa 255 değil 251 çıkar.
const _saydamlikOrnekBoyu = 512;

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

/// Editör parçasını (`.part.js`) yüklemenin test edilebilir hâli.
///
/// NEDEN KANCA VAR: `loadLibrary()` ağdan dosya çeker ve BAŞARISIZ OLABİLİR
/// (bağlantı koptu, parça sunucuda yok, eski servis çalışanı 404 döndü).
/// O durumda kullanıcının SnackBar görmesi bir DAVRANIŞ, davranışın da testi
/// olmalı (CLAUDE.md md.7). Gerçek bir ağ hatası `flutter test` içinde
/// üretilemez; bu kanca üretilebilir kılıyor.
@visibleForTesting
Future<void> Function()? editorYukleSahte;

Future<void> _editoruYukle() =>
    editorYukleSahte?.call() ?? editor.loadLibrary();

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
///
/// ERTELENMİŞ YÜKLEME (19 Ağu 2026): editörün kendisi artık `gorsel_duzenle_
/// editor.dart`ta ve web'de ayrı bir `.part.js` olarak duruyor. Bu fonksiyon
/// İNCE BİR SARMALAYICI: parçayı yükler, sonra gövdeyi çağırır. Çağıran taraf
/// (`medya_inceleme.dart`) bunun farkında bile değil — imza değişmedi.
///
/// KULLANICI NE GÖRÜR: parça yavaş bağlantıda saniyeler sürebilir; hiçbir şey
/// olmazsa kullanıcı bunu DONMA sanar. Gösterge çağıran tarafta zaten var ve
/// bu `await`in TAMAMINI kapsıyor: `medya_inceleme.dart:_duzenleyiAc` en başta
/// `_duzenleAciliyor = true` yapıyor, kalem düğmesi de o bayrakla spinner'a
/// dönüşüp kilitleniyor (`_DuzenleDugmesi.mesgul` → `CircularProgressIndicator
/// (color: DiziRenkler.sari)`). Yani "boşta → meşgul → sonuç" üçlüsü kuruluydu;
/// erteleme yalnız "meşgul" hâlini uzattı, yeni bir gösterge gerekmedi.
Future<Uint8List?> gorselDuzenle(BuildContext context, Uint8List veri) async {
  // SAHTE KANCA EN BAŞTA — bir satır bile aşağı kayarsa testler gerçek
  // editör parçasını yüklemeye kalkar ve `flutter test` ağa bağımlı olur.
  if (gorselDuzenleSahte != null) return gorselDuzenleSahte!(context, veri);
  // Ertelemenin ilk kazancı: GIF/video/tanınmayan baytta parça HİÇ İNMEZ.
  if (!duzenlenebilirMi(veri)) return null;

  // Gezinme kancaları await'TEN ÖNCE alınır: aşağısı baştan sona asenkron ve
  // arada widget sökülmüş olabilir (use_build_context_synchronously).
  final mesajci = ScaffoldMessenger.of(context);
  final gezgin = Navigator.of(context, rootNavigator: true);

  // ÖNCE PARÇA, SONRA SAYDAMLIK TARAMASI — sıra BİLİNÇLİ:
  // 1. Parça inemezse tarama boşuna yapılmış olurdu; `saydamlikVar` görseli
  //    gerçekten çözüyor (12 MP'de onlarca ms + bellek). Kesin başarısız
  //    olacak bir iş için bunu ödetmiyoruz.
  // 2. İkisini PARALEL başlatmak birkaç ms kazandırırdı ama hata dalını test
  //    EDİLEMEZ kılardı: `saydamlikVar` gerçek görsel çözücüye gittiği için
  //    widget testinde `runAsync` olmadan ilerlemiyor, dolayısıyla paralel
  //    kurguda "parça inemedi" SnackBar'ına hiç ulaşılamıyordu. Kanıtlanamayan
  //    hata yolu, olmayan hata yoludur (CLAUDE.md md.7).
  try {
    await _editoruYukle();
  } catch (_) {
    // ÜÇÜNCÜ HÂL: yükleniyor → başarı → HATA. Sessizce `null` dönmek düğmeyi
    // "bozuk" gösterirdi; kullanıcı neden bir şey olmadığını asla anlamazdı.
    // Aynı metni çıktı doğrulaması da kullanıyor: yeni çeviri borcu YOK.
    _uyar(mesajci, 'Düzenlenemedi'.c);
    return null;
  }

  final saydam = await saydamlikVar(veri);
  return editor.gorselDuzenleGovde(gezgin, mesajci, veri, saydam: saydam);
}

/// Testler için: JPEG kodlayıcı yerine geçer.
@visibleForTesting
Future<Uint8List?> Function(ui.Image)? jpegKodlaSahte;

/// `ui.Image` → JPEG baytları (kolaj çıktısı). Parça inemezse ya da kodlayıcı
/// patlarsa `null` — çağıran PNG'ye düşer (`kolaj.dart`).
Future<Uint8List?> gorseliJpegKodla(ui.Image gorsel) async {
  if (jpegKodlaSahte != null) return jpegKodlaSahte!(gorsel);
  try {
    await _editoruYukle();
    return await editor.gorseliJpegKodlaGovde(gorsel);
  } catch (_) {
    return null;
  }
}

void _uyar(ScaffoldMessengerState mesajci, String metin) => mesajci
  ..clearSnackBars()
  ..showSnackBar(SnackBar(content: Text(metin)));
