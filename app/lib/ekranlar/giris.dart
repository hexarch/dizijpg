import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';

class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key});

  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> {
  bool _kayitModu = false;
  bool _yukleniyor = false;
  final _email = TextEditingController();
  final _kullaniciAdi = TextEditingController();
  final _sifre = TextEditingController();

  @override
  void dispose() {
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  /// İki adımlı şifre sıfırlama: e-postaya kod → kod + yeni şifre.
  Future<void> _sifremiUnuttum() async {
    final email = TextEditingController(text: _email.text.trim());
    final kod = TextEditingController();
    final yeni = TextEditingController();
    var kodIstendi = false;
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: DiziRenkler.koyuGri,
        builder: (context) => StatefulBuilder(
          builder: (context, setSheet) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
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
                  decoration: InputDecoration(hintText: 'E-posta'.c),
                ),
                if (kodIstendi) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: kod,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(hintText: 'E-postadaki kod'.c),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: yeni,
                    obscureText: true,
                    decoration: InputDecoration(hintText: 'Yeni şifre'.c),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    try {
                      if (!kodIstendi) {
                        final d = await Api.post('/auth/sifre-sifirla-istek', {
                          'email': email.text.trim(),
                        });
                        setSheet(() => kodIstendi = true);
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
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    }
                  },
                  child: Text(kodIstendi ? 'Şifreyi Sıfırla'.c : 'Gönder'.c),
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
      final kullanici = _kayitModu
          ? await Api.kayit(
              _email.text.trim(),
              _kullaniciAdi.text.trim(),
              _sifre.text,
            )
          : await Api.giris(_email.text.trim(), _sifre.text);
      if (!mounted) return;
      await context.read<Oturum>().girisYapildi(kullanici);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Image.asset('assets/logo.png', height: 130),
                const SizedBox(height: 8),
                Text(
                  'Dizi ve filmlerini takip et'.c,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 36),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: _kayitModu
                        ? 'E-posta'.c
                        : 'E-posta veya kullanıcı adı'.c,
                  ),
                ),
                if (_kayitModu) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _kullaniciAdi,
                    decoration: InputDecoration(
                      hintText: 'Kullanıcı adı (küçük harf)'.c,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _sifre,
                  obscureText: true,
                  decoration: InputDecoration(hintText: 'Şifre'.c),
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
                if (!_kayitModu)
                  TextButton(
                    onPressed: _sifremiUnuttum,
                    child: Text(
                      'Şifreni mi unuttun?'.c,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ),
                TextButton(
                  onPressed: () => setState(() => _kayitModu = !_kayitModu),
                  child: Text(
                    _kayitModu
                        ? 'Zaten hesabın var mı? Giriş yap'.c
                        : 'Hesabın yok mu? Kayıt ol'.c,
                    style: const TextStyle(color: DiziRenkler.sari),
                  ),
                ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: _yukleniyor ? null : _misafirGiris,
                  icon: const Icon(Icons.person_outline, color: Colors.white70),
                  label: Text(
                    'Misafir olarak devam et'.c,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
