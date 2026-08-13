import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../ceviri.dart';
import '../google_kapisi.dart';
import '../push.dart';
import '../tema.dart';
import 'iki_adim_sheet.dart';
import 'ortak.dart' show altGuvenli;

/// Formun azami genişliği. Google'ın kendi düğmesi 400 px'ten geniş
/// ÇİZİLMEZ (marka kuralı); form masaüstünde tüm ekranı kaplasaydı Google
/// düğmesi diğerlerinden dar kalır, ekran iki farklı düğme genişliği
/// gösterirdi. Aynı sınır giriş formunu masaüstünde de okunur tutuyor.
const double _formGenisligi = 400;

class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key, bool? web, this.googleKapisi})
    : web = web ?? kIsWeb;

  /// Web dalı mı? PARAMETRE: `flutter test` daima `kIsWeb == false` ile koşar;
  /// bayrak gömülü olsaydı testler web dalını hiç gezemezdi.
  final bool web;

  /// YALNIZ TEST: sahte Google kapısı. Null ise [web] değerine göre kurulur.
  final GoogleKapisi? googleKapisi;

  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> {
  bool _kayitModu = false;
  bool _yukleniyor = false;
  final _email = TextEditingController();
  final _kullaniciAdi = TextEditingController();
  final _sifre = TextEditingController();

  late final GoogleKapisi _kapi;
  StreamSubscription<GoogleKimligi>? _googleAbonesi;

  @override
  void initState() {
    super.initState();
    _kapi = widget.googleKapisi ?? googleKapisiOlustur(web: widget.web);
    // Web'de giriş Google'ın kendi düğmesinden başlar ve sonuç BU AKIŞTAN
    // gelir; mobilde akış boştur (giriş `_googleGiris` ile başlar).
    _googleAbonesi = _kapi.akis.listen(_googleSunucuya, onError: _googleHatasi);
  }

  @override
  void dispose() {
    _googleAbonesi?.cancel();
    _kapi.birak();
    _email.dispose();
    _kullaniciAdi.dispose();
    _sifre.dispose();
    super.dispose();
  }

  Future<void> _misafirGiris() async {
    setState(() => _yukleniyor = true);
    try {
      final kullanici = await Api.misafirGiris();
      if (!mounted) return;
      await context.read<Oturum>().girisYapildi(kullanici);
      pushBaslat(); // push izni + token kaydı
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  /// MOBİL dal: kendi düğmemiz Google hesap seçicisini açar.
  /// (Webde bu yol KULLANILMAZ — bkz. google_kapisi_web.dart'taki not.)
  Future<void> _googleGiris() async {
    setState(() => _yukleniyor = true);
    try {
      final kimlik = await _kapi.dokun();
      if (kimlik == null || kimlik.bos) return; // kullanıcı vazgeçti
      await _girisiTamamla(kimlik);
    } catch (e) {
      _googleHatasi(e);
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  /// WEB dalı: Google'ın düğmesinden kimlik gelince sunucuya götürür.
  Future<void> _googleSunucuya(GoogleKimligi kimlik) async {
    if (kimlik.bos) {
      _googleHatasi(null);
      return;
    }
    setState(() => _yukleniyor = true);
    try {
      await _girisiTamamla(kimlik);
    } catch (e) {
      _googleHatasi(e);
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  /// İki dalın ORTAK son adımı: hesap yoksa oluşturulur (yeni → karşılama).
  Future<void> _girisiTamamla(GoogleKimligi kimlik) async {
    // Android id_token verir; webde GIS düğmesi de id_token verir. Sunucu
    // ikisini de kabul ediyor (`kimlik` / `erisim`, backend/server.js).
    final d = kimlik.idToken != null
        ? await Api.googleGiris(kimlik: kimlik.idToken)
        : await Api.googleGiris(erisim: kimlik.erisimToken);
    if (!mounted) return;
    if (d['yeni'] == true) Oturum.karsilamaGerekli = true;
    await context.read<Oturum>().girisYapildi(
      d['kullanici'] as Map<String, dynamic>,
    );
    pushBaslat(); // push izni + token kaydı
  }

  /// Google girişinin HER başarısızlığı kullanıcıya söylenir: sessiz
  /// başarısızlık (hiçbir şey olmaması) bu hatanın ta kendisiydi.
  ///
  /// Sunucu hatası kendi metnini gösterir. Google/Play Services hatasında
  /// çeviri anahtarının SONUNA ham kod eklenir (`… (10)`) — 13 Ağu'da
  /// "giriş başarısız" bildirimi geldi ve ekranda kod olmadığı için
  /// yapılandırma hatası (10) ile hesabın yeniden doğrulanması (16)
  /// birbirinden AYIRT EDİLEMEDİ; sunucuya istek hiç ulaşmadığı için
  /// kayıtlarda da iz yoktu. Kod YENİ ANAHTAR AÇMADAN eklenir.
  void _googleHatasi(Object? e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e is ApiHata
              ? e.toString()
              : '${'Google girişi başarısız'.c}${googleHataKodu(e)}',
        ),
      ),
    );
  }

  /// İki adımlı şifre sıfırlama: e-postaya kod → kod + yeni şifre.
  Future<void> _sifremiUnuttum() async {
    final email = TextEditingController(text: _email.text.trim());
    final kod = TextEditingController();
    final yeni = TextEditingController();
    var kodIstendi = false;
    var isliyor = false;
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: DiziRenkler.koyuGri,
        builder: (context) => StatefulBuilder(
          // Alt pay: klavye + sistem çubuğu. Çift saymaz — klavye açıkken
          // platform padding.bottom'ı 0'a çeker (bkz. puan_sheet.dart).
          builder: (context, setSheet) => Padding(
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
                  'Şifreyi Sıfırla'.c,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: email,
                  enabled: !kodIstendi,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: 'E-posta'.c),
                ),
                if (kodIstendi) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: kod,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'E-postadaki kod'.c),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: yeni,
                    obscureText: true,
                    decoration: InputDecoration(labelText: 'Yeni şifre'.c),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  // İşlem sürerken kilitli + spinner (çift dokunma / çift kod engellenir)
                  onPressed: isliyor
                      ? null
                      : () async {
                          setSheet(() => isliyor = true);
                          try {
                            if (!kodIstendi) {
                              final d = await Api.post(
                                '/auth/sifre-sifirla-istek',
                                {'email': email.text.trim()},
                              );
                              setSheet(() {
                                kodIstendi = true;
                                isliyor = false;
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(d['mesaj'] as String? ?? ''),
                                  ),
                                );
                              }
                            } else {
                              final d = await Api.post('/auth/sifre-sifirla', {
                                'email': email.text.trim(),
                                'kod': kod.text.trim(),
                                'sifre': yeni.text,
                              });
                              await Api.tokenKaydet(d['token'] as String);
                              if (context.mounted) Navigator.pop(context);
                              if (!mounted) return;
                              await this.context.read<Oturum>().girisYapildi(
                                d['kullanici'] as Map<String, dynamic>,
                              );
                            }
                          } catch (e) {
                            setSheet(() => isliyor = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          }
                        },
                  child: isliyor
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(kodIstendi ? 'Şifreyi Sıfırla'.c : 'Gönder'.c),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      email.dispose();
      kod.dispose();
      yeni.dispose();
    }
  }

  Future<void> _gonder() async {
    setState(() => _yukleniyor = true);
    try {
      if (_kayitModu) {
        final kullanici = await Api.kayit(
          _email.text.trim(),
          _kullaniciAdi.text.trim(),
          _sifre.text,
        );
        if (!mounted) return;
        // Yeni kayıt → karşılama akışı (router yönlendirir).
        Oturum.karsilamaGerekli = true;
        await context.read<Oturum>().girisYapildi(kullanici);
        pushBaslat(); // push izni + token kaydı
        return;
      }
      final d = await Api.giris(_email.text.trim(), _sifre.text);
      if (!mounted) return;
      // md. 52 — İKİ ADIMLI DOĞRULAMA: şifre doğru ama OTURUM AÇILMADI.
      // Yanıtta token yok; elimizde yalnız kısa ömürlü bir bilet var. Şifreyi
      // ikinci adım için saklamıyoruz (yasak) — bilet onun yerine geçiyor.
      if (d['iki_adim'] == true) {
        // Giriş düğmesinin spinner'ı BURADA kapanır. Kapatmasaydık kod
        // sayfası açıkken alttaki düğme sonsuza kadar dönerdi (istek bitti,
        // sıra kullanıcıda) — `finally` ancak sayfa kapanınca çalışıyor.
        setState(() => _yukleniyor = false);
        await _ikiAdim(d['bilet'] as String, d['eposta_ipucu'] as String?);
        return;
      }
      await context.read<Oturum>().girisYapildi(
        d['kullanici'] as Map<String, dynamic>,
      );
      pushBaslat(); // push izni + token kaydı
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  /// Girişin ikinci adımı: e-postadaki kod. Vazgeçilirse hiçbir şey olmaz —
  /// kullanıcı giriş formunda kalır (şifre alanı doludur, yeniden dener).
  Future<void> _ikiAdim(String bilet, String? epostaIpucu) => ikiAdimSheetAc(
    context,
    baslik: 'İki Adımlı Doğrulama'.c,
    aciklama: 'Kod {} adresine gönderildi'.cf([epostaIpucu ?? '•••']),
    dogrula: (kod) async {
      final kullanici = await Api.girisKodu(bilet, kod);
      if (!mounted) return;
      await context.read<Oturum>().girisYapildi(kullanici);
      pushBaslat(); // push izni + token kaydı
    },
    yenidenGonder: () => Api.girisKoduYenile(bilet),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _formGenisligi),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Image.asset('assets/logo.png', height: 130),
                    const SizedBox(height: 8),
                    Text(
                      'Dizi ve filmlerini takip et'.c,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: DiziRenkler.metin54),
                    ),
                    const SizedBox(height: 36),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: _kayitModu
                            ? 'E-posta'.c
                            : 'E-posta veya kullanıcı adı'.c,
                      ),
                    ),
                    if (_kayitModu) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _kullaniciAdi,
                        decoration: InputDecoration(
                          labelText: 'Kullanıcı adı (küçük harf)'.c,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _sifre,
                      obscureText: true,
                      decoration: InputDecoration(labelText: 'Şifre'.c),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _yukleniyor ? null : _gonder,
                      child: _yukleniyor
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Text(
                              _kayitModu ? 'Hesap Oluştur'.c : 'Giriş Yap'.c,
                              style: const TextStyle(fontSize: 16),
                            ),
                    ),
                    if (_kayitModu) _gizlilikSatiri(),
                    if (!_kayitModu)
                      TextButton(
                        onPressed: _sifremiUnuttum,
                        child: Text(
                          'Şifreni mi unuttun?'.c,
                          style: TextStyle(color: DiziRenkler.metin54),
                        ),
                      ),
                    TextButton(
                      onPressed: () => setState(() => _kayitModu = !_kayitModu),
                      child: Text(
                        _kayitModu
                            ? 'Zaten hesabın var mı? Giriş yap'.c
                            : 'Hesabın yok mu? Kayıt ol'.c,
                        style: TextStyle(color: DiziRenkler.sariMetin),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // WEB: Google'ın KENDİ düğmesi. Google, web'de uygulamanın
                    // kendi düğmesinden giriş başlatmasına izin vermiyor; eski
                    // `signIn()` yolu açılır pencereyi açıp sonsuza kadar
                    // bekliyordu. Düğmenin görünümünü Google belirler.
                    // MOBİL: kendi düğmemiz (Android yolu değişmedi).
                    _googleDugmesi(),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _yukleniyor ? null : _misafirGiris,
                      icon: Icon(
                        Icons.person_outline,
                        color: DiziRenkler.metin70,
                      ),
                      label: Text(
                        'Misafir olarak devam et'.c,
                        style: TextStyle(color: DiziRenkler.metin70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Google düğmesi: webde Google'ın kendisi, mobilde bizimki.
  ///
  /// İstek sürerken Google'ın düğmesi YERİNE kilitli eşdeğeri çizilir —
  /// HtmlElementView tıklamaları DOM'da alır, üstüne perde koymak onu
  /// durdurmaz; tek güvenilir kilit düğmeyi kaldırmaktır.
  Widget _googleDugmesi() {
    final googleninki = _yukleniyor ? null : _kapi.dugme(context);
    if (googleninki != null) return googleninki;
    final dugme = OutlinedButton.icon(
      // Webde bu düğme yalnız yükleme sırasında görünür ve KİLİTLİDİR:
      // giriş Google'ın düğmesinden başlar.
      onPressed: _yukleniyor || widget.web ? null : _googleGiris,
      icon: SvgPicture.asset('assets/google_g.svg', width: 18, height: 18),
      label: Text(
        'Google ile devam et'.c,
        style: TextStyle(
          color: _yukleniyor ? DiziRenkler.metin54 : DiziRenkler.metin70,
        ),
      ),
    );
    // Webde Google'ın düğmesiyle aynı yüksekliği tutar → yer değişmez.
    return widget.web
        ? SizedBox(height: googleDugmeYuksekligi, child: dugme)
        : dugme;
  }

  /// Kayıt modunda gizlilik onay satırı; tamamı dokunulabilir.
  /// DİKKAT: TextSpan tema rengini devralmaz — renkler açıkça verilir.
  Widget _gizlilikSatiri() {
    final parcalar = 'Kayıt olarak {} kabul etmiş olursun.'.c.split('{}');
    return TextButton(
      onPressed: () => context.push('/gizlilik'),
      child: Text.rich(
        TextSpan(
          style: TextStyle(color: DiziRenkler.metin54, fontSize: 12),
          children: [
            TextSpan(text: parcalar.first),
            TextSpan(
              text: 'Gizlilik Politikası'.c,
              style: TextStyle(
                color: DiziRenkler.sariMetin,
                decoration: TextDecoration.underline,
                decorationColor: DiziRenkler.sariMetin,
              ),
            ),
            if (parcalar.length > 1) TextSpan(text: parcalar.last),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
