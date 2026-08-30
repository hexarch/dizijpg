import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import '../google_kapisi.dart';
import '../tema.dart';
import 'iki_adim_sheet.dart' show ikiAdimSheetAc;

/// Ayarlar > E-posta adresini değiştir.
///
/// ---------------------------------------------------------------------------
/// NEDEN VAR (30 Ağu 2026)
/// ---------------------------------------------------------------------------
/// Bir kullanıcı hesabını `<10 hane>@_` adresiyle açmıştı — o tarihte kayıtta
/// tek koşul "içinde @ var mı" idi. Dışa aktarma ve iki adımlı giriş kodu
/// maillerinin hiçbiri ulaşmadı; kullanıcı suçu kendi posta sağlayıcısında
/// (QQ Mail) aradı ve geri bildirim yazdı. Kayıttaki biçim denetimi artık
/// kapalı, AMA BOZUK ADRESLE KAYITLI KULLANICI KENDİNİ KURTARAMIYORDU:
/// uygulamada kullanıcı adı değiştirme vardı, e-posta değiştirme YOKTU.
///
/// ---------------------------------------------------------------------------
/// İKİ ADIM — VE KOD NEDEN YENİ ADRESE GİDİYOR
/// ---------------------------------------------------------------------------
///   1. Şifre + yeni adres  → sunucu kodu YENİ adrese yollar
///   2. Kod ekranı          → kod doğrulanınca adres uygulanır
/// Şifre, çalınmış bir oturumun hesabı sessizce devralmasını engeller
/// (`IkiAdimAyariSheet` ile aynı gerekçe). Kodun YENİ adrese gitmesi ise
/// kullanıcının o kutuya gerçekten sahip olduğunu kanıtlar — kanıt
/// aranmasaydı bu ekran, hesabı erişilemez bir adrese kilitlemenin (yani
/// düzeltmeye çalıştığımız olayı tekrar etmenin) en kısa yolu olurdu.
///
/// ---------------------------------------------------------------------------
/// KİMLİK KANITI HERKESTE "ŞİFRE" DEĞİL
/// ---------------------------------------------------------------------------
/// Kullanıcı tespiti (30 Ağu 2026): *"google hesabı ile giriş yapanların
/// şifresi yok ki"*. Doğrusu: Google ile açılan hesabın `sifre_hash`i sunucuda
/// RASTGELEDİR, yani sahibi onu BİLEMEZ ve şifre sorulunca kaçınılmaz olarak
/// "Şifre hatalı" alırdı — çıkışsız bir döngü. Bu yüzden ekran İKİ kanıt
/// sunar: şifre alanı ve "Google ile doğrula".
///
/// HESABIN KÖKENİ SORULMUYOR, İKİSİ BİRDEN GÖSTERİLİYOR. İstemcinin "bu hesap
/// Google kökenli mi" diye ayrı bir uca sorması gerekirdi; kullanıcıya iki
/// seçeneği birden vermek hem bir istek eksiltiyor hem de ŞİFRESİNİ SONRADAN
/// BELİRLEMİŞ Google kullanıcısını (ikisi de geçerli) doğru yakalıyor.
///
/// ---------------------------------------------------------------------------
/// DOĞRULAMA HEM BURADA HEM SUNUCUDA
/// ---------------------------------------------------------------------------
/// Buradaki kalıp yalnız HIZLI GERİ BİLDİRİM için (`ui-ux-pro-max` *Inline
/// Validation*). Gerçek kural sunucuda `epostaGecerli`de; bu dosya silinse
/// bile uç 4xx döner. Kalıp sunucudakiyle aynı şeyi istiyor: alan adında en az
/// bir nokta ve harften oluşan bir uzantı — `@_` tam da buraya takılır.
class EpostaSheet extends StatefulWidget {
  const EpostaSheet({super.key, required this.mevcut});

  /// Hesapta ŞU AN kayıtlı adres. İpucu olarak gösterilir: kullanıcının
  /// adresinin bozuk olduğunu görebileceği tek yer burası.
  final String mevcut;

  @override
  State<EpostaSheet> createState() => _EpostaSheetState();
}

class _EpostaSheetState extends State<EpostaSheet> {
  final _eposta = TextEditingController();
  final _sifre = TextEditingController();
  bool _gonderiliyor = false;

  /// Google kapısı: webde Google'ın KENDİ düğmesi + akış, mobilde `dokun()`.
  /// Giriş ekranıyla aynı bileşen — ikinci bir Google akışı yazmıyoruz.
  late final GoogleKapisi _kapi;
  StreamSubscription<GoogleKimligi>? _googleAbonesi;

  /// Alanın altında kırmızı duran hata. Sunucudan gelen mesaj da BURAYA
  /// yazılıyor, yalnız SnackBar'a değil: `ui-ux-pro-max` *Error Clarity* —
  /// kaybolan bir SnackBar kullanıcıyı "ne yazmıştım" diye geri döndürür.
  String? _hata;

  /// Sunucudaki `EPOSTA_KALIBI`nın istemci ikizi. TEK İŞİ hızlı uyarı vermek.
  // Üç tırnaklı HAM dize ŞART: kalıp hem `"` hem `'` içeriyor; tek tırnaklı
  // ham dizede ikisi de kaçırılamaz (ham dizede `\\` kaçış yoktur).
  static final _kalip = RegExp(
    r'''^[^\s@,;:<>"'\\()\[\]]{1,64}@(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$''',
    caseSensitive: false,
  );

  String get _aday => _eposta.text.trim().toLowerCase();

  /// ADRES tek başına geçerli mi. Şifre BURAYA girmez: Google yolunda şifre
  /// hiç yazılmaz. Şifre koşulu yalnız "Kod gönder" düğmesinde aranır.
  bool get _gecerli =>
      _kalip.hasMatch(_aday) &&
      _aday.length <= 254 &&
      _aday != widget.mevcut.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _kapi = googleKapisiOlustur(web: kIsWeb);
    // Webde akış Google'ın kendi düğmesinden gelir; mobilde akış boştur ve
    // kanıt `dokun()` ile alınır.
    _googleAbonesi = _kapi.akis.listen(
      (k) => _gonder(google: k),
      onError: (Object e) => setState(() => _hata = e.toString()),
    );
  }

  @override
  void dispose() {
    _googleAbonesi?.cancel();
    _kapi.birak();
    _eposta.dispose();
    _sifre.dispose();
    super.dispose();
  }

  Future<void> _gonder({GoogleKimligi? google}) async {
    if (!_gecerli || _gonderiliyor) return;
    if (google == null && _sifre.text.isEmpty) return;
    setState(() {
      _gonderiliyor = true;
      _hata = null;
    });
    final adres = _aday;
    final messenger = ScaffoldMessenger.of(context);
    String? ipucu;
    try {
      final d = await Api.epostaDegistirKodIste(
        adres,
        sifre: google == null ? _sifre.text : null,
        idToken: google?.idToken,
        erisimToken: google?.erisimToken,
      );
      ipucu = d['eposta_ipucu'] as String?;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gonderiliyor = false;
        _hata = e.toString();
      });
      return;
    }
    if (!mounted) return;
    setState(() => _gonderiliyor = false);
    // İKİNCİ ADIM: kod ekranı 2FA ile ORTAK. Ayrı yazsaydık "yeniden gönder",
    // 6 hane kontrolü ve kilit mesajı burada eksik kalırdı.
    final tamam = await ikiAdimSheetAc(
      context,
      baslik: 'E-posta adresini değiştir'.c,
      aciklama: 'Kod {} adresine gönderildi'.cf([ipucu ?? adres]),
      dogrula: (kod) => Api.epostaDegistirUygula(kod),
      // Yeniden gönderim aynı ucu, AYNI KANITLA çağırır. Google yolunda
      // şifre elimizde yok; jeton tekrar kullanılır (kısa ömürlüdür ama kod
      // ekranı da 10 dakikalıktır, pencereler örtüşür).
      yenidenGonder: () => Api.epostaDegistirKodIste(
        adres,
        sifre: google == null ? _sifre.text : null,
        idToken: google?.idToken,
        erisimToken: google?.erisimToken,
      ),
    );
    if (!tamam || !mounted) return;
    Navigator.pop(context, adres);
    messenger.showSnackBar(
      SnackBar(content: Text('E-posta adresin güncellendi'.c)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Boş alanda uyarı YOK: kullanıcı daha bir şey yazmadan hata görmemeli.
    final yaziliyor = _eposta.text.trim().isNotEmpty;
    final kalipHatasi = yaziliyor && !_kalip.hasMatch(_aday)
        ? 'Geçerli bir e-posta adresi yaz'.c
        : (yaziliyor && _aday == widget.mevcut.trim().toLowerCase()
              ? 'Bu zaten hesabının e-posta adresi'.c
              : null);
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.mail_outline,
                    size: 20,
                    color: DiziRenkler.sariMetin,
                  ),
                  const SizedBox(width: 8),
                  // Expanded: uzun çeviri dar ekranda taşmak yerine sarar.
                  Expanded(
                    child: Text(
                      'E-posta adresini değiştir'.c,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('eposta-alani'),
                controller: _eposta,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                onChanged: (_) => setState(() => _hata = null),
                decoration: InputDecoration(
                  hintText: widget.mevcut.isEmpty
                      ? 'ornek@posta.com'
                      : widget.mevcut,
                  errorText: kalipHatasi,
                  errorMaxLines: 3,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('eposta-sifre-alani'),
                controller: _sifre,
                obscureText: true,
                onChanged: (_) => setState(() => _hata = null),
                onSubmitted: (_) => _gonder(),
                decoration: InputDecoration(
                  hintText: 'Şifreni gir'.c,
                  errorText: _hata,
                  errorMaxLines: 3,
                ),
              ),
              // SONUÇLAR ÖNCEDEN: kodun NEREYE gideceği ve adresin ne işe
              // yaradığı, "Kod gönder"e basmadan ÖNCE okunuyor.
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 15,
                    color: DiziRenkler.metin38,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Doğrulama kodu YENİ adrese gönderilir; adres ancak kodu '
                              'girdikten sonra değişir. Şifre sıfırlama ve iki '
                              'adımlı giriş kodları bundan sonra yeni adrese gider.'
                          .c,
                      style: TextStyle(
                        color: DiziRenkler.metin54,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('eposta-kod-gonder'),
                onPressed:
                    (_gecerli && _sifre.text.isNotEmpty && !_gonderiliyor)
                    ? () => _gonder()
                    : null,
                child: _gonderiliyor
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Text('Kod gönder'.c),
              ),
              // GOOGLE YOLU — şifresini bilmeyen (Google ile açılmış) hesap
              // için TEK çıkış. Ayırıcı metin, iki kanıtın ALTERNATİF olduğunu
              // söyler: "ikisini de yap" değil, "hangisi varsa onu".
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: Divider(color: DiziRenkler.metin38)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'ya da'.c,
                      style: TextStyle(
                        color: DiziRenkler.metin54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: DiziRenkler.metin38)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Hesabını Google ile açtıysan şifren yoktur; kimliğini Google '
                        'ile doğrula.'
                    .c,
                style: TextStyle(
                  color: DiziRenkler.metin54,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              // WEB: Google'ın KENDİ düğmesi (GIS artık kendi düğmemizden
              // giriş başlatmamıza izin vermiyor) — sonuç `akis`tan gelir.
              // MOBİL: `dugme` null döner, kendi düğmemizi çizip `dokun()`
              // çağırırız. Giriş ekranıyla birebir aynı kalıp.
              if (_gecerli && !_gonderiliyor)
                _kapi.dugme(context) ??
                    OutlinedButton.icon(
                      key: const Key('eposta-google-dogrula'),
                      onPressed: () async {
                        try {
                          final k = await _kapi.dokun();
                          if (k == null || k.bos) return; // vazgeçti
                          await _gonder(google: k);
                        } catch (e) {
                          if (mounted) setState(() => _hata = e.toString());
                        }
                      },
                      icon: const Icon(Icons.account_circle_outlined, size: 18),
                      label: Text('Google ile doğrula'.c),
                    )
              else
                // Adres geçerli değilken düğme ÇİZİLMEZ: Google akışını
                // başlatıp sonunda "geçersiz adres" demek, kullanıcıyı hesap
                // seçtirdikten sonra geri çevirmek olurdu.
                Opacity(
                  opacity: 0.4,
                  child: OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.account_circle_outlined, size: 18),
                    label: Text('Google ile doğrula'.c),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
