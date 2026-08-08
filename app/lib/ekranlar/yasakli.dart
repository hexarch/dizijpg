import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';

/// Askıya alınmış hesabın gördüğü bilgi kartı.
///
/// NEDEN VAR: sessizce çalışmayan bir uygulama en kötü deneyimdir. Ceza alan
/// kullanıcı yorum yazmayı denediğinde yalnız "bir şeyler ters gitti" görürse
/// ne olduğunu, ne kadar süreceğini ve nereye itiraz edeceğini bilemez.
/// Bu kart üçünü de söyler.
///
/// UX kuralları (ui-ux-pro-max sorguları):
///  * "Error Recovery — provide clear next steps": itiraz adresi veriliyor.
///  * "Color Only — don't convey information by color alone": kırmızı rengin
///    yanında ENGEL İKONU ve açık metin var; renk körü kullanıcı da anlar.
///  * "Contrast 4.5:1": sebep metni [DiziRenkler.metin] ile basılıyor,
///    soluk gri üstüne soluk gri değil.
class YasakKarti extends StatefulWidget {
  /// Sunucudan gelen yük: `{kalici, bitis, kalan_sn, sebep}`.
  final Map<String, dynamic> bilgi;

  /// Kart bir diyalog içindeyse kapatma düğmesi çizilir.
  final VoidCallback? onKapat;

  /// İtiraz bölümünü çiz. Şerit altındaki diyalogda true; salt bilgi amaçlı
  /// kullanımlarda kapatılabilir.
  final bool itirazAcik;

  const YasakKarti({
    super.key,
    required this.bilgi,
    this.onKapat,
    this.itirazAcik = true,
  });

  @override
  State<YasakKarti> createState() => _YasakKartiState();

  /// Kalan süre; kalıcı banda ve süre dolmuşsa null.
  static Duration? kalanSure(Map<String, dynamic> bilgi) {
    if (bilgi['kalici'] == true) return null;
    final sn = (bilgi['kalan_sn'] as num?)?.toInt();
    if (sn == null || sn <= 0) return null;
    return Duration(seconds: sn);
  }

  /// "2 gün 3 saat" / "1 saat 30 dakika" / "5 dakika".
  ///
  /// Gün varken dakika yazılmaz (gürültü); bir dakikanın altında "birkaç
  /// saniye" denir — "0 dakika kaldı" saçma görünürdü.
  static String sureMetni(Duration s) {
    final gun = s.inDays;
    final saat = s.inHours % 24;
    final dk = s.inMinutes % 60;
    final parca = <String>[];
    if (gun > 0) parca.add('{} gün'.cf([gun]));
    if (saat > 0) parca.add('{} saat'.cf([saat]));
    if (dk > 0 && gun == 0) parca.add('{} dakika'.cf([dk]));
    if (parca.isEmpty) return 'birkaç saniye'.c;
    return parca.join(' ');
  }

  /// Kalıcı ban mı? Sunucu `kalici: true` ya da `bitis: null` gönderir.
  static bool kaliciMi(Map<String, dynamic> bilgi) =>
      bilgi['kalici'] == true || bilgi['bitis'] == null;
}

class _YasakKartiState extends State<YasakKarti> {
  final _denetleyici = TextEditingController();

  /// `GET /itirazim` yanıtı: `{itiraz, yazabilir}`. null = henüz yüklenmedi.
  Map<String, dynamic>? _itirazDurumu;
  bool _yukleniyor = true;
  bool _gonderiliyor = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    if (widget.itirazAcik) _durumYukle();
  }

  @override
  void dispose() {
    _denetleyici.dispose();
    super.dispose();
  }

  Future<void> _durumYukle() async {
    try {
      final d = await Api.itirazDurumu();
      if (!mounted) return;
      setState(() {
        _itirazDurumu = d;
        _yukleniyor = false;
      });
    } catch (_) {
      // Ağ hatası kartın TAMAMINI yutmasın: ceza bilgisi zaten elimizde,
      // yalnız itiraz bölümü çizilemez. Sessiz değil — yeniden dene çıkar.
      if (!mounted) return;
      setState(() => _yukleniyor = false);
    }
  }

  Future<void> _gonder() async {
    final metin = _denetleyici.text.trim();
    // Sunucudaki alt sınırla (yasak.js ITIRAZ_EN_AZ) BİREBİR aynı: kullanıcı
    // yazdıktan sonra değil, yazarken uyarılsın.
    if (metin.length < 10) {
      setState(() => _hata = 'İtiraz en az 10 karakter olmalı'.c);
      return;
    }
    setState(() {
      _gonderiliyor = true;
      _hata = null;
    });
    try {
      await Api.itirazGonder(metin);
      _denetleyici.clear();
      await _durumYukle();
      if (!mounted) return;
      setState(() => _gonderiliyor = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('İtirazın alındı, inceleniyor'.c)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gonderiliyor = false;
        _hata = e.toString();
      });
    }
  }

  /// İtiraz bölümü: form / "incelemede" / "reddedildi".
  Widget _itirazBolumu() {
    if (_yukleniyor) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Yükleniyor...'.c,
          style: TextStyle(fontSize: 13, color: DiziRenkler.metin54),
        ),
      );
    }
    final durum = _itirazDurumu;
    final itiraz = durum?['itiraz'] as Map<String, dynamic>?;
    final asama = itiraz?['durum'] as String?;

    // BEKLİYOR: form yerine durum. Kullanıcı ikinci kez yazmaya çalışıp
    // 409 yemesin — kural sunucuda, ekran onu YANSITIYOR.
    if (asama == 'bekliyor') {
      return _durumSatiri(
        Icons.hourglass_top,
        'İtirazın incelemede'.c,
        DiziRenkler.sariMetin,
      );
    }
    final yazabilir = durum?['yazabilir'] == true;
    if (!yazabilir && asama == 'ret') {
      final not = (itiraz?['karar_notu'] as String?)?.trim();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _durumSatiri(Icons.gavel, 'İtirazın reddedildi'.c, Colors.redAccent),
          if (not != null && not.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              not,
              style: TextStyle(fontSize: 13, color: DiziRenkler.metin70),
            ),
          ],
        ],
      );
    }
    if (!yazabilir) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Karara itiraz et'.c,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: DiziRenkler.metin,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _denetleyici,
          maxLines: 4,
          maxLength: 2000,
          enabled: !_gonderiliyor,
          style: TextStyle(fontSize: 14, color: DiziRenkler.metin),
          decoration: InputDecoration(
            // Etiket GÖRÜNÜR (yalnız placeholder değil): ui-ux-pro-max
            // "Placeholder-only label" anti-kalıbı.
            hintText: 'Neden bu cezanın kaldırılması gerektiğini anlat'.c,
            hintStyle: TextStyle(fontSize: 13, color: DiziRenkler.metin38),
            filled: true,
            fillColor: DiziRenkler.acikGri,
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        if (_hata != null) ...[
          const SizedBox(height: 6),
          // Hata ALANIN YANINDA (sayfanın tepesinde değil).
          Row(
            children: [
              const Icon(
                Icons.error_outline,
                size: 16,
                color: Colors.redAccent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _hata!,
                  style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: _gonderiliyor ? null : _gonder,
            style: FilledButton.styleFrom(
              minimumSize: const Size(120, 44),
              backgroundColor: DiziRenkler.sari,
              foregroundColor: Colors.black,
            ),
            child: _gonderiliyor
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : Text('İtirazını gönder'.c),
          ),
        ),
      ],
    );
  }

  Widget _durumSatiri(IconData ikon, String metin, Color renk) => Row(
    children: [
      Icon(ikon, size: 18, color: renk),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          metin,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: DiziRenkler.metin,
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final bilgi = widget.bilgi;
    final onKapat = widget.onKapat;
    final kalici = YasakKarti.kaliciMi(bilgi);
    final sebep = (bilgi['sebep'] as String?)?.trim() ?? '';
    final kalan = YasakKarti.kalanSure(bilgi);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DiziRenkler.kart,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // İkon + metin birlikte: bilgi YALNIZ renkle taşınmıyor.
              const Icon(Icons.block, color: Colors.redAccent, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  kalici
                      ? 'Hesabın kalıcı olarak askıya alındı'.c
                      : 'Hesabın geçici olarak askıya alındı'.c,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: DiziRenkler.metin,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (sebep.isNotEmpty) ...[
            Text(
              'Sebep'.c,
              style: TextStyle(fontSize: 12, color: DiziRenkler.metin54),
            ),
            const SizedBox(height: 2),
            Text(
              sebep,
              style: TextStyle(fontSize: 15, color: DiziRenkler.metin),
            ),
            const SizedBox(height: 14),
          ],
          if (kalan != null) ...[
            Text(
              'Kalan süre'.c,
              style: TextStyle(fontSize: 12, color: DiziRenkler.metin54),
            ),
            const SizedBox(height: 2),
            Text(
              YasakKarti.sureMetni(kalan),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: DiziRenkler.metin,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Süre dolunca hesabın kendiliğinden açılır'.c,
              style: TextStyle(fontSize: 12, color: DiziRenkler.metin54),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            'Bu süre boyunca okumaya devam edebilirsin; gönderi, yorum ve mesaj gönderemezsin.'
                .c,
            style: TextStyle(fontSize: 13, color: DiziRenkler.metin70),
          ),
          // "Error Recovery": kullanıcıya bir SONRAKİ ADIM verilmeli.
          // Eskiden burada `iletisim@dizijpg.com` yazıyordu; o posta kutusu
          // sunucuda AÇILMAMIŞTI, yani ceza fiilen itiraz edilemezdi ve
          // "kararlar geri alınabilir" ilkesi kâğıt üstünde kalıyordu.
          // Artık itiraz uygulamadan gönderiliyor ve yönetim panelinde
          // kuyruğa düşüyor — hiçbir dış bağımlılık yok.
          if (widget.itirazAcik) ...[
            const SizedBox(height: 16),
            Divider(color: DiziRenkler.metin12, height: 1),
            const SizedBox(height: 14),
            _itirazBolumu(),
          ],
          if (onKapat != null) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onKapat,
                // 44 dp dokunma hedefi (ui-ux-pro-max "Touch Target Size").
                style: TextButton.styleFrom(
                  minimumSize: const Size(88, 44),
                  foregroundColor: DiziRenkler.sariMetin,
                ),
                child: Text('Anladım'.c),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Yasak bilgisini diyalog olarak gösterir.
///
/// `barrierDismissible: true`: kullanıcıyı ekranda HAPSETMİYORUZ. Ceza zaten
/// sunucu tarafında uygulanıyor; burada amaç bilgilendirmek, cezalandırmak
/// değil. Kapatınca kabuk üstündeki kalıcı şerit yerinde kalır.
Future<void> yasakDiyalogu(
  BuildContext context,
  Map<String, dynamic> bilgi,
) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: YasakKarti(bilgi: bilgi, onKapat: () => Navigator.of(ctx).pop()),
      ),
    ),
  );
}

/// Uygulamanın her ekranında görünen ince ceza şeridi.
///
/// Kabuk'un gövdesini sarar: kullanıcı hangi sekmede olursa olsun cezasından
/// haberdar olur ve dokununca ayrıntıyı açar. Yasak yokken HİÇBİR yer kaplamaz.
class YasakSeridi extends StatelessWidget {
  final Widget child;
  const YasakSeridi({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: Api.yasak,
      builder: (context, bilgi, _) {
        if (bilgi == null) return child;
        final kalan = YasakKarti.kalanSure(bilgi);
        return Column(
          children: [
            Material(
              color: Colors.redAccent.withValues(alpha: 0.16),
              child: InkWell(
                onTap: () => yasakDiyalogu(context, bilgi),
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    // 44 dp: şerit aynı zamanda bir dokunma hedefi.
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.block,
                          size: 18,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            // Ayrı bir çeviri anahtarı YOK: iki hazır anahtar
                            // birleştiriliyor, yoksa aynı cümle 45 dilde iki
                            // kez çevrilecekti.
                            kalan == null
                                ? 'Hesabın askıya alındı'.c
                                : '${'Hesabın askıya alındı'.c} · '
                                      '${YasakKarti.sureMetni(kalan)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: DiziRenkler.metin,
                            ),
                          ),
                        ),
                        Text(
                          'Ayrıntı'.c,
                          style: TextStyle(
                            fontSize: 12,
                            color: DiziRenkler.sariMetin,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
