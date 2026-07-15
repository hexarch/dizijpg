import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
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

  Future<void> _gonder() async {
    setState(() => _yukleniyor = true);
    try {
      final kullanici = _kayitModu
          ? await Api.kayit(
              _email.text.trim(), _kullaniciAdi.text.trim(), _sifre.text)
          : await Api.giris(_email.text.trim(), _sifre.text);
      if (!mounted) return;
      await context.read<Oturum>().girisYapildi(kullanici);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
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
                const Text(
                  'Dizi ve filmlerini takip et',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 36),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                      hintText:
                          _kayitModu ? 'E-posta' : 'E-posta veya kullanıcı adı'),
                ),
                if (_kayitModu) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _kullaniciAdi,
                    decoration: const InputDecoration(
                        hintText: 'Kullanıcı adı (küçük harf)'),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _sifre,
                  obscureText: true,
                  decoration: const InputDecoration(hintText: 'Şifre'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _yukleniyor ? null : _gonder,
                  child: _yukleniyor
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(_kayitModu ? 'Hesap Oluştur' : 'Giriş Yap',
                          style: const TextStyle(fontSize: 16)),
                ),
                TextButton(
                  onPressed: () => setState(() => _kayitModu = !_kayitModu),
                  child: Text(
                    _kayitModu
                        ? 'Zaten hesabın var mı? Giriş yap'
                        : 'Hesabın yok mu? Kayıt ol',
                    style: const TextStyle(color: DiziRenkler.kirmizi),
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
