import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'ortak.dart' show altGuvenli;

/// md. 52 — e-posta ile iki adımlı doğrulamanın ORTAK kod ekranı.
///
/// ÜÇ AKIŞ AYNI SAYFAYI KULLANIR:
///   1. giriş ikinci adımı  (giris.dart)
///   2. 2FA'yı açma onayı   (ayarlar.dart)
///   3. 2FA'yı kapatma onayı (ayarlar.dart)
/// Üçünü ayrı ayrı yazsaydık "yeniden gönder" düğmesi ya da odak/klavye
/// davranışı birinde eksik kalırdı; kural gereği her akışın üç hâli
/// (yükleniyor / başarı / hata) var ve tek yerde tutuluyor.
///
/// SUNUCU SÖZLEŞMESİ: kod 6 hanedir, 10 dakika yaşar, 5 yanlıştan sonra İPTAL
/// olur (yeniden gönderim gerekir). O yüzden "yeniden gönder" ikinci sınıf bir
/// düğme değil, akışın PARÇASIDIR.
class IkiAdimSheet extends StatefulWidget {
  const IkiAdimSheet({
    super.key,
    required this.baslik,
    required this.aciklama,
    required this.dogrula,
    required this.yenidenGonder,
  });

  final String baslik;

  /// Kodun nereye gittiğini anlatan satır (maskeli e-posta içerir).
  final String aciklama;

  /// Kodu sunucuya götürür. Hata fırlatırsa mesajı ekranda gösterilir.
  final Future<void> Function(String kod) dogrula;

  /// Kodu yeniden gönderir.
  final Future<void> Function() yenidenGonder;

  @override
  State<IkiAdimSheet> createState() => _IkiAdimSheetState();
}

class _IkiAdimSheetState extends State<IkiAdimSheet> {
  final _kod = TextEditingController();
  bool _isliyor = false;
  bool _gonderiliyor = false;
  String? _hata;

  @override
  void dispose() {
    _kod.dispose();
    super.dispose();
  }

  Future<void> _dogrula() async {
    final kod = _kod.text.trim();
    // Sunucuya gitmeden önceki tek kontrol BİÇİM: 6 hane değilse istek bile
    // atılmaz (sunucu da bu girdide deneme hakkı harcamıyor).
    if (kod.length != 6) {
      setState(() => _hata = '6 haneli kod'.c);
      return;
    }
    setState(() {
      _isliyor = true;
      _hata = null;
    });
    try {
      await widget.dogrula(kod);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      // Hata İKİ YERDE birden: alan altında kalıcı metin (kullanıcı kodu
      // düzeltirken görmeye devam etsin) + SnackBar (dikkat çeksin).
      setState(() {
        _isliyor = false;
        _hata = e.toString();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _yeniden() async {
    setState(() {
      _gonderiliyor = true;
      _hata = null;
    });
    try {
      await widget.yenidenGonder();
      if (!mounted) return;
      // Yeni kod = temiz alan. Eski kod artık geçersiz; ekranda kalması
      // kullanıcıyı "gönderdim ama olmuyor" döngüsüne sokardı.
      _kod.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Yeni kod gönderildi'.c)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mesgul = _isliyor || _gonderiliyor;
    return Padding(
      // Alt pay: klavye + sistem çubuğu (giris.dart'taki sıfırlama sayfasıyla
      // aynı hesap; klavye açıkken platform padding.bottom 0'a düşer).
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom +
            altGuvenli(context, ekstra: 20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.baslik,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            widget.aciklama,
            textAlign: TextAlign.center,
            style: TextStyle(color: DiziRenkler.metin54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('iki-adim-kod'),
            controller: _kod,
            // Kod alanı ODAKLI açılır ve SAYISAL klavye gelir: kullanıcı
            // e-postadan kodu okuyup doğrudan yazabilsin.
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, letterSpacing: 6),
            enabled: !_isliyor,
            onSubmitted: (_) => mesgul ? null : _dogrula(),
            decoration: InputDecoration(
              labelText: '6 haneli kod'.c,
              counterText: '',
              errorText: _hata,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('iki-adim-dogrula'),
            // Dokunma hedefi: 48 dp (>= 44 kuralı).
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: mesgul ? null : _dogrula,
            child: _isliyor
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : Text('Doğrula'.c),
          ),
          const SizedBox(height: 4),
          TextButton(
            key: const Key('iki-adim-yeniden'),
            style: TextButton.styleFrom(minimumSize: const Size(88, 44)),
            onPressed: mesgul ? null : _yeniden,
            child: _gonderiliyor
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: DiziRenkler.sari,
                    ),
                  )
                : Text(
                    'Yeniden gönder'.c,
                    style: TextStyle(color: DiziRenkler.sariMetin),
                  ),
          ),
          TextButton(
            key: const Key('iki-adim-vazgec'),
            style: TextButton.styleFrom(minimumSize: const Size(88, 44)),
            // Vazgeçmek YÜKLEME SIRASINDA da kapalı: yarıda kesilen bir
            // doğrulama isteği sunucuda denemeyi yine de harcar.
            onPressed: mesgul ? null : () => Navigator.pop(context, false),
            child: Text(
              'Vazgeç'.c,
              style: TextStyle(color: DiziRenkler.metin54),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kod sayfasını açar; kod doğrulandıysa `true` döner.
Future<bool> ikiAdimSheetAc(
  BuildContext context, {
  required String baslik,
  required String aciklama,
  required Future<void> Function(String kod) dogrula,
  required Future<void> Function() yenidenGonder,
}) async {
  final sonuc = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DiziRenkler.koyuGri,
    // Dışarı dokunup kaçmak SERBEST (vazgeçmekle aynı sonuç), ama kod
    // doğrulanmadan hiçbir şey değişmez — sunucu tarafı bunu garanti ediyor.
    builder: (_) => IkiAdimSheet(
      baslik: baslik,
      aciklama: aciklama,
      dogrula: dogrula,
      yenidenGonder: yenidenGonder,
    ),
  );
  return sonuc == true;
}

/// Ayarlar > İki Adımlı Doğrulama: aç/kapat anahtarı.
///
/// AÇMAK DA KAPATMAK DA E-POSTA KODU İSTER. Gerekçeler:
///  * AÇARKEN kod istemek, kilidi takmadan önce kutunun ÇALIŞTIĞINI kanıtlar.
///    Yanlış/ölü adrese kilit takan kullanıcı hesabına bir daha giremezdi.
///  * KAPATIRKEN kod istemek, çalınmış bir oturumun kilidi sessizce
///    açmasını engeller. Açabilen ama kapatamayan bir kilit işe yaramaz;
///    token'la sessizce kapatılabilen bir kilit de.
class IkiAdimAyariSheet extends StatefulWidget {
  const IkiAdimAyariSheet({super.key});

  @override
  State<IkiAdimAyariSheet> createState() => _IkiAdimAyariSheetState();
}

class _IkiAdimAyariSheetState extends State<IkiAdimAyariSheet> {
  Map<String, dynamic>? _durum;
  String? _hata;
  bool _isliyor = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final d = await Api.ikiAdimDurumu();
      if (mounted) setState(() => _durum = d);
    } catch (e) {
      if (mounted) setState(() => _hata = e.toString());
    }
  }

  /// Anahtara dokunuldu: önce kod iste, sonra kod sayfasını aç.
  ///
  /// İYİMSER GÜNCELLEME YOK — bilerek. Bu anahtar ancak sunucu kodu kabul
  /// edince değişir; erkenden çevirseydik kullanıcı vazgeçtiğinde ya da kod
  /// yanlış girildiğinde ekran gerçeği YANLIŞ gösterirdi.
  Future<void> _degistir(bool acilsin) async {
    final amac = acilsin ? 'ac' : 'kapat';
    setState(() => _isliyor = true);
    String? ipucu;
    try {
      final d = await Api.ikiAdimKodIste(amac);
      ipucu = d['eposta_ipucu'] as String?;
    } catch (e) {
      if (!mounted) return;
      setState(() => _isliyor = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
    if (!mounted) return;
    setState(() => _isliyor = false);
    final tamam = await ikiAdimSheetAc(
      context,
      baslik: 'İki Adımlı Doğrulama'.c,
      aciklama: 'Kod {} adresine gönderildi'.cf([ipucu ?? '•••']),
      dogrula: (kod) => Api.ikiAdimDogrula(amac, kod),
      yenidenGonder: () => Api.ikiAdimKodIste(amac),
    );
    if (!tamam || !mounted) return;
    setState(() => _durum = {...?_durum, 'acik': acilsin});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          acilsin
              ? 'İki adımlı doğrulama açıldı'.c
              : 'İki adımlı doğrulama kapatıldı'.c,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 20,
                    color: DiziRenkler.sariMetin,
                  ),
                  const SizedBox(width: 8),
                  // Expanded: uzun çeviri dar ekranda taşmak yerine sarar.
                  Expanded(
                    child: Text(
                      'İki Adımlı Doğrulama'.c,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_hata != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _hata!,
                  style: TextStyle(color: DiziRenkler.metin54),
                ),
              )
            else if (_durum == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: DiziRenkler.sari),
              )
            else ...[
              SwitchListTile(
                key: const Key('iki-adim-anahtar'),
                value: _durum!['acik'] == true,
                activeColor: DiziRenkler.sari,
                title: Text(
                  'Girişte e-postana kod gönderilir'.c,
                  style: TextStyle(color: DiziRenkler.metin, fontSize: 15),
                ),
                // E-postası olmayan (misafir) hesapta kod gönderilecek yer
                // yok; istek sunucuda da reddedilirdi.
                onChanged: _isliyor || _durum!['kullanilabilir'] != true
                    ? null
                    : _degistir,
              ),
              if (_isliyor)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: DiziRenkler.sari,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // GOOGLE İSTİSNASI KULLANICIYA AÇIKÇA ANLATILIYOR.
                    //
                    // Seçenek GİZLENMEDİ, AÇIKLANDI — çünkü "yalnız Google ile
                    // giren kullanıcı" güvenilir biçimde ayırt EDİLEMİYOR:
                    // Google ile açılan hesaba da rastgele bir şifre hash'i
                    // yazılıyor (backend `/auth/google`), yani "şifresi yok"
                    // diye bir işaret yok. Seçeneği yanlış tahminle gizleseydik
                    // şifresini sonradan belirlemiş kullanıcıdan gerçek bir
                    // güvenlik ayarını saklamış olurduk. Ayrıca ikisini birden
                    // kullanan kişi için ayar YİNE anlamlı: şifreli giriş
                    // korunur, Google girişi Google'ın kendi doğrulamasına
                    // güvenir.
                    _not(
                      'Google ile girişte kod sorulmaz; Google kendi doğrulamasını yapar.'
                          .c,
                    ),
                    const SizedBox(height: 6),
                    _not('Kapatmak için de kod gerekir.'.c),
                    const SizedBox(height: 6),
                    // Kurtarma kodu ÜRETİLMİYOR (gerekçe backend
                    // migrasyon-2026-08-14f.sql). O yüzden risk burada AÇIKÇA
                    // yazılıyor: kullanıcı ne kabul ettiğini bilerek açsın.
                    _not(
                      'E-postana erişemezsen hesabına giremezsin.'.c,
                      uyari: true,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _not(String metin, {bool uyari = false}) => Text(
    metin,
    style: TextStyle(
      color: uyari ? DiziRenkler.metin70 : DiziRenkler.metin38,
      fontSize: 12,
    ),
  );
}
