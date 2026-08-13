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

/// Düzenlenmiş çıktının üst sınırı. İstemcinin yorum eki sınırıyla (30 MB,
/// `yorumlar.dart:_ekAzamiBayt`) AYNI: editörden çıkan dosya da o kapıdan
/// geçecek, sınırı burada erken yakalayıp anlaşılır hata veriyoruz.
///
/// TESPİT (MEDYA-EDITOR-PLANI §3.5): sunucu 100 MB kabul ediyor, istemci
/// 30 MB'da kesiyor — bu uyumsuzluk G1 kapsamı DIŞINDA, burada yalnızca
/// istemci sınırına uyuluyor.
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
/// HATA: çıktı tanınmayan bir tür ya da 30 MB'ı aşıyorsa SnackBar ile
/// söylenir ve `null` dönülür — sessiz başarısızlık YOK.
Future<Uint8List?> gorselDuzenle(BuildContext context, Uint8List veri) async {
  if (gorselDuzenleSahte != null) return gorselDuzenleSahte!(context, veri);
  if (!duzenlenebilirMi(veri)) return null;

  final mesajci = ScaffoldMessenger.of(context);
  final sonuc = await Navigator.of(context, rootNavigator: true)
      .push<Uint8List?>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _GorselDuzenleEkrani(veri: veri),
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
  if (sonuc.length > gorselDuzenleAzamiBayt) {
    _uyar(mesajci, 'Düzenlenen görsel çok büyük'.c);
    return null;
  }
  return sonuc;
}

void _uyar(ScaffoldMessengerState mesajci, String metin) => mesajci
  ..clearSnackBars()
  ..showSnackBar(SnackBar(content: Text(metin)));

/// Editör ekranı. `pro_image_editor`ün kendi tam ekran widget'ını bizim
/// tema/dil/araç yapılandırmamızla sarar.
class _GorselDuzenleEkrani extends StatelessWidget {
  final Uint8List veri;
  const _GorselDuzenleEkrani({required this.veri});

  @override
  Widget build(BuildContext context) {
    Uint8List? cikti;
    return ProImageEditor.memory(
      veri,
      configs: duzenleyiciYapilandirma(),
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
ProImageEditorConfigs duzenleyiciYapilandirma() {
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
    imageGeneration: const ImageGenerationConfigs(
      // JPEG: sunucunun `RESIM_TURLERI` listesinde FFD8FF ile karşılığı var,
      // her cihazda aynı, PNG'den kat kat küçük. Kalite 92 → görsel farkı
      // yok, dosya ~%60 küçük.
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
