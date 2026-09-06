/// İZLEME ODASI — "Bağlantı yapıştır" modalı.
///
/// Kullanıcı isteği (7 Eyl 2026): *"youtube gibi tüm platformların url'ini
/// destekleyecek şekilde yapsak ve altına desteklenen siteler yazsak"*.
///
/// ===========================================================================
/// DOĞRULAMA YAZARKEN, GÖNDERİRKEN DEĞİL
/// ===========================================================================
/// Adres, kullanıcı yazarken çözümleniyor ve kutunun altında ya "YouTube
/// videosu" ya da neyin desteklendiği yazıyor. Doğrulamayı gönderime
/// bırakmak, kullanıcıyı "yapıştır → gönder → hata → yapıştır" turuna sokardı;
/// üstelik hata SnackBar'da çıkıp kaybolurdu (ui-ux-pro-max, Forms —
/// "validate inline, at the point of entry").
///
/// Çözümleme burada YALNIZ deneyim içindir: kaydedilen şey sunucunun kendi
/// çözümlemesidir (`backend/oda.js#baglantiCoz`). İkisi ayrışırsa sunucu
/// reddeder ve `BAGLANTI_DESTEKSIZ` metni basılır.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard;

import '../ceviri.dart';
import '../tema.dart';
import 'oda_baglanti.dart';

/// Modalı açar; kullanıcı geçerli bir adres onayladıysa HAM adresi döndürür.
Future<String?> odaBaglantiSheetAc(BuildContext context, {String? mevcut}) =>
    showModalBottomSheet<String>(
      context: context,
      backgroundColor: DiziRenkler.koyuGri,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        // Klavye açılınca kutu KLAVYENİN ALTINDA kalmasın.
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: OdaBaglantiGovdesi(mevcut: mevcut),
      ),
    );

/// Modalın gövdesi — testin GoRouter/modal kurmadan kurabilmesi için açık.
class OdaBaglantiGovdesi extends StatefulWidget {
  final String? mevcut;

  const OdaBaglantiGovdesi({super.key, this.mevcut});

  @override
  State<OdaBaglantiGovdesi> createState() => _OdaBaglantiGovdesiState();
}

class _OdaBaglantiGovdesiState extends State<OdaBaglantiGovdesi> {
  late final TextEditingController _alan;
  OdaBaglanti? _cozum;

  @override
  void initState() {
    super.initState();
    _alan = TextEditingController(text: widget.mevcut ?? '');
    _cozum = odaBaglantiCoz(_alan.text);
  }

  @override
  void dispose() {
    _alan.dispose();
    super.dispose();
  }

  void _degisti(String v) {
    // HER TUŞTA setState — "çözüm değişmediyse atla" kestirmesi 7 Eyl 2026'da
    // widget testinde yakalanan bir hataya yol açıyordu: kutu BOŞken de
    // GEÇERSİZ adres yazılıyken de çözüm null olduğu için erken dönülüyor,
    // ekran "Desteklenen siteler…" bilgisinde kalıyor ve kullanıcı "Bu adres
    // desteklenmiyor" uyarısını HİÇ görmüyordu. Alt satır yalnız çözüme değil
    // kutunun BOŞ olup olmadığına da bakıyor; yani girdi değişimi tek başına
    // yeniden çizim sebebi.
    setState(() => _cozum = odaBaglantiCoz(v));
  }

  Future<void> _panodanAl() async {
    final v = await Clipboard.getData('text/plain');
    final metin = v?.text?.trim();
    if (metin == null || metin.isEmpty || !mounted) return;
    _alan.text = metin;
    _degisti(metin);
  }

  @override
  Widget build(BuildContext context) {
    final c = _cozum;
    final bos = _alan.text.trim().isEmpty;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Video bağlantısı'.c,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _alan,
              autofocus: true,
              maxLines: 1,
              keyboardType: TextInputType.url,
              onChanged: _degisti,
              onSubmitted: (_) => _onayla(),
              decoration: InputDecoration(
                hintText: 'https://youtu.be/...',
                filled: true,
                fillColor: DiziRenkler.kart,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  tooltip: 'Yapıştır'.c,
                  onPressed: _panodanAl,
                  icon: const Icon(Icons.content_paste, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _durumSatiri(c, bos),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                // Geçersizken KAPALI: basılabilir bir düğme "belki çalışır"
                // diye umut verir, oysa cevabı zaten biliyoruz.
                onPressed: c == null ? null : _onayla,
                child: Text('Odada aç'.c),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Kutunun altındaki tek satır: ya tanınan platform ya desteklenenler.
  Widget _durumSatiri(OdaBaglanti? c, bool bos) {
    if (c != null) {
      final uyari = odaBaglantiUyumsuzlugu(c, web: _webMi);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, size: 16, color: DiziRenkler.sariMetin),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  c.dosyaMi
                      ? 'Doğrudan video adresi'.c
                      : '{} videosu'.cf([c.saglayiciAdi]),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          if (uyari == 'HLS_WEB') ...[
            const SizedBox(height: 6),
            Text(
              // ÇIKIŞ YOLU ver: "oynatılamıyor" tek başına çıkmaz.
              'Bu canlı yayın biçimini (m3u8) tarayıcı oynatamaz; telefon uygulamasında açılır.'
                  .c,
              style: TextStyle(fontSize: 11, color: DiziRenkler.metin54),
            ),
          ],
        ],
      );
    }
    return Text(
      bos
          ? 'Desteklenen siteler: {} · doğrudan video adresi (.mp4, .webm)'.cf([
              odaDesteklenenPlatformlar.join(', '),
            ])
          : 'Bu adres desteklenmiyor. Desteklenen siteler: {} · doğrudan video adresi (.mp4, .webm)'
                .cf([odaDesteklenenPlatformlar.join(', ')]),
      style: TextStyle(
        fontSize: 11,
        // Geçersiz adres HATA rengiyle: gri bir satır "bilgi" gibi okunur ve
        // kullanıcı düğmenin neden kapalı olduğunu anlamaz.
        color: bos ? DiziRenkler.metin38 : Theme.of(context).colorScheme.error,
      ),
    );
  }

  /// `kIsWeb`in kendisi değil ondan BAŞLATILAN alan: `flutter test` daima
  /// VM'de koşar, yani web dalı koda gömülü olsaydı hiçbir testte
  /// çalışmazdı (aynı gerekçe `AramaServisi.webMi`de yazılı).
  @visibleForTesting
  static bool webMi = identical(0, 0.0);
  bool get _webMi => webMi;

  void _onayla() {
    final c = _cozum;
    if (c == null) return;
    // HAM adres gönderiliyor, çözümlenmiş hâli değil: kaydeden sunucudur.
    Navigator.of(context).pop(_alan.text.trim());
  }
}
