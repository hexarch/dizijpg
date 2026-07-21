import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../tema.dart';

const List<String> ulkeler = [
  'Türkiye', 'Almanya', 'Amerika Birleşik Devletleri', 'Andorra', 'Angola',
  'Arjantin', 'Arnavutluk', 'Avustralya', 'Avusturya', 'Azerbaycan',
  'Bahreyn', 'Bangladeş', 'Belarus', 'Belçika', 'Birleşik Arap Emirlikleri',
  'Birleşik Krallık', 'Bolivya', 'Bosna-Hersek', 'Brezilya', 'Bulgaristan',
  'Cezayir', 'Çekya', 'Çin', 'Danimarka', 'Endonezya', 'Ermenistan',
  'Estonya', 'Etiyopya', 'Fas', 'Filipinler', 'Filistin', 'Finlandiya',
  'Fransa', 'Gana', 'Guatemala', 'Güney Afrika', 'Güney Kore', 'Gürcistan',
  'Hindistan', 'Hırvatistan', 'Hollanda', 'Honduras', 'Irak', 'İran',
  'İrlanda', 'İspanya', 'İsrail', 'İsveç', 'İsviçre', 'İtalya', 'İzlanda',
  'Jamaika', 'Japonya', 'Kamboçya', 'Kanada', 'Karadağ', 'Katar',
  'Kazakistan', 'Kenya', 'Kıbrıs', 'Kırgızistan', 'Kolombiya', 'Kosova',
  'Kosta Rika', 'Küba', 'Kuveyt', 'Letonya', 'Libya', 'Litvanya',
  'Lübnan', 'Lüksemburg', 'Macaristan', 'Makedonya', 'Malezya', 'Malta',
  'Meksika', 'Mısır', 'Moğolistan', 'Moldova', 'Monako', 'Nepal',
  'Nijerya', 'Norveç', 'Özbekistan', 'Pakistan', 'Panama', 'Paraguay',
  'Peru', 'Polonya', 'Portekiz', 'Romanya', 'Rusya', 'Senegal',
  'Sırbistan', 'Singapur', 'Slovakya', 'Slovenya', 'Somali',
  'Sri Lanka', 'Sudan', 'Suriye', 'Suudi Arabistan', 'Şili', 'Tayland',
  'Tayvan', 'Tunus', 'Türkmenistan', 'Ukrayna', 'Umman', 'Ürdün',
  'Uruguay', 'Venezuela', 'Vietnam', 'Yemen', 'Yeni Zelanda', 'Yunanistan',
];

class AyarlarEkrani extends StatefulWidget {
  const AyarlarEkrani({super.key});

  @override
  State<AyarlarEkrani> createState() => _AyarlarEkraniState();
}

class _AyarlarEkraniState extends State<AyarlarEkrani> {
  Map<String, dynamic>? _profil;
  String? _hata;
  bool _kaydediliyor = false;
  bool _avatarYukleniyor = false;
  final _bio = TextEditingController();
  String? _ulke;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _bio.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      final p = await Api.profilim();
      if (!mounted) return;
      setState(() {
        _profil = p;
        _bio.text = (p['bio'] as String?) ?? '';
        _ulke = p['ulke'] as String?;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
    }
  }

  Future<void> _avatarSec() async {
    final secim = await ImagePicker()
        .pickImage(source: ImageSource.gallery, requestFullMetadata: false);
    if (secim == null) return;
    setState(() => _avatarYukleniyor = true);
    try {
      final veri = await secim.readAsBytes();
      if (veri.length > 8 * 1024 * 1024) {
        throw ApiHata('Dosya en fazla 8MB olabilir');
      }
      final yol = await Api.avatarYukle(veri);
      if (!mounted) return;
      setState(() => _profil!['avatar'] = yol);
      final oturum = context.read<Oturum>();
      await oturum.girisYapildi({...?oturum.kullanici, 'avatar': yol});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _avatarYukleniyor = false);
    }
  }

  Future<void> _ulkeSec() async {
    final arama = TextEditingController();
    final secilen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DiziRenkler.koyuGri,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          final filtreli = ulkeler
              .where((u) =>
                  u.toLowerCase().contains(arama.text.toLowerCase().trim()))
              .toList();
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: TextField(
                    controller: arama,
                    autofocus: false,
                    onChanged: (_) => setSheet(() {}),
                    decoration: const InputDecoration(
                        hintText: 'Ülke ara...',
                        prefixIcon: Icon(Icons.search, color: Colors.white38)),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtreli.length,
                    itemBuilder: (context, i) => ListTile(
                      title: Text(filtreli[i]),
                      trailing: filtreli[i] == _ulke
                          ? const Icon(Icons.check, color: DiziRenkler.kirmizi)
                          : null,
                      onTap: () => Navigator.pop(context, filtreli[i]),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (secilen != null) setState(() => _ulke = secilen);
  }

  Future<void> _kaydet() async {
    setState(() => _kaydediliyor = true);
    try {
      final p = await Api.profilGuncelle(bio: _bio.text.trim(), ulke: _ulke ?? '');
      if (!mounted) return;
      final oturum = context.read<Oturum>();
      await oturum.girisYapildi({...?oturum.kullanici, ...p});
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profil kaydedildi ✅')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_hata != null) {
      govde = Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_hata!, style: const TextStyle(color: Colors.white54)),
        TextButton(onPressed: _yukle, child: const Text('Tekrar dene')),
      ]));
    } else if (_profil == null) {
      govde = const Center(
          child: CircularProgressIndicator(color: DiziRenkler.kirmizi));
    } else {
      final avatar = dosyaUrl(_profil!['avatar'] as String?);
      govde = ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: DiziRenkler.kart,
                  // NetworkImage GIF'i otomatik oynatır
                  backgroundImage:
                      avatar != null ? NetworkImage(avatar) : null,
                  child: avatar == null
                      ? const Icon(Icons.person,
                          size: 52, color: Colors.white38)
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: InkWell(
                    onTap: _avatarYukleniyor ? null : _avatarSec,
                    child: CircleAvatar(
                      radius: 17,
                      backgroundColor: DiziRenkler.kirmizi,
                      child: _avatarYukleniyor
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.edit,
                              size: 17, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text('Fotoğraf veya GIF seçebilirsin',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          const SizedBox(height: 24),
          const Text('Bio', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(
            controller: _bio,
            maxLines: 3,
            maxLength: 300,
            decoration:
                const InputDecoration(hintText: 'Kendinden bahset...'),
          ),
          const SizedBox(height: 12),
          const Text('Ülke', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading:
                  const Icon(Icons.public, color: DiziRenkler.kirmizi),
              title: Text(_ulke ?? 'Ülke seç',
                  style: TextStyle(
                      color: _ulke == null ? Colors.white38 : Colors.white)),
              trailing: _ulke == null
                  ? const Icon(Icons.chevron_right, color: Colors.white38)
                  : IconButton(
                      icon: const Icon(Icons.close, color: Colors.white38),
                      onPressed: () => setState(() => _ulke = null),
                    ),
              onTap: _ulkeSec,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _kaydediliyor ? null : _kaydet,
            child: _kaydediliyor
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Kaydet'),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.read<Oturum>().cikis();
            },
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            label: const Text('Çıkış Yap',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: govde,
    );
  }
}
