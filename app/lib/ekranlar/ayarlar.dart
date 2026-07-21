import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';

const List<String> ulkeler = [
  'Türkiye',
  'Almanya',
  'Amerika Birleşik Devletleri',
  'Andorra',
  'Angola',
  'Arjantin',
  'Arnavutluk',
  'Avustralya',
  'Avusturya',
  'Azerbaycan',
  'Bahreyn',
  'Bangladeş',
  'Belarus',
  'Belçika',
  'Birleşik Arap Emirlikleri',
  'Birleşik Krallık',
  'Bolivya',
  'Bosna-Hersek',
  'Brezilya',
  'Bulgaristan',
  'Cezayir',
  'Çekya',
  'Çin',
  'Danimarka',
  'Endonezya',
  'Ermenistan',
  'Estonya',
  'Etiyopya',
  'Fas',
  'Filipinler',
  'Filistin',
  'Finlandiya',
  'Fransa',
  'Gana',
  'Guatemala',
  'Güney Afrika',
  'Güney Kore',
  'Gürcistan',
  'Hindistan',
  'Hırvatistan',
  'Hollanda',
  'Honduras',
  'Irak',
  'İran',
  'İrlanda',
  'İspanya',
  'İsrail',
  'İsveç',
  'İsviçre',
  'İtalya',
  'İzlanda',
  'Jamaika',
  'Japonya',
  'Kamboçya',
  'Kanada',
  'Karadağ',
  'Katar',
  'Kazakistan',
  'Kenya',
  'Kıbrıs',
  'Kırgızistan',
  'Kolombiya',
  'Kosova',
  'Kosta Rika',
  'Küba',
  'Kuveyt',
  'Letonya',
  'Libya',
  'Litvanya',
  'Lübnan',
  'Lüksemburg',
  'Macaristan',
  'Makedonya',
  'Malezya',
  'Malta',
  'Meksika',
  'Mısır',
  'Moğolistan',
  'Moldova',
  'Monako',
  'Nepal',
  'Nijerya',
  'Norveç',
  'Özbekistan',
  'Pakistan',
  'Panama',
  'Paraguay',
  'Peru',
  'Polonya',
  'Portekiz',
  'Romanya',
  'Rusya',
  'Senegal',
  'Sırbistan',
  'Singapur',
  'Slovakya',
  'Slovenya',
  'Somali',
  'Sri Lanka',
  'Sudan',
  'Suriye',
  'Suudi Arabistan',
  'Şili',
  'Tayland',
  'Tayvan',
  'Tunus',
  'Türkmenistan',
  'Ukrayna',
  'Umman',
  'Ürdün',
  'Uruguay',
  'Venezuela',
  'Vietnam',
  'Yemen',
  'Yeni Zelanda',
  'Yunanistan',
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
  bool _kapakYukleniyor = false;
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
    final secim = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (secim == null) return;
    setState(() => _avatarYukleniyor = true);
    try {
      final veri = await secim.readAsBytes();
      if (veri.length > 8 * 1024 * 1024) {
        throw ApiHata('Dosya en fazla {}MB olabilir'.cf([8]));
      }
      final yol = await Api.avatarYukle(veri);
      if (!mounted) return;
      setState(() => _profil!['avatar'] = yol);
      final oturum = context.read<Oturum>();
      await oturum.girisYapildi({...?oturum.kullanici, 'avatar': yol});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _avatarYukleniyor = false);
    }
  }

  Future<void> _kapakSec() async {
    final secim = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (secim == null) return;
    setState(() => _kapakYukleniyor = true);
    try {
      final veri = await secim.readAsBytes();
      if (veri.length > 10 * 1024 * 1024) {
        throw ApiHata('Dosya en fazla {}MB olabilir'.cf([10]));
      }
      final yol = await Api.kapakYukle(veri);
      if (!mounted) return;
      setState(() => _profil!['kapak'] = yol);
      final oturum = context.read<Oturum>();
      await oturum.girisYapildi({...?oturum.kullanici, 'kapak': yol});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _kapakYukleniyor = false);
    }
  }

  Future<void> _ulkeSec() async {
    final secilen = await _aramaliSecim(
      secenekler: ulkeler,
      secili: _ulke,
      ipucu: 'Ülke ara...'.c,
    );
    if (secilen != null) setState(() => _ulke = secilen);
  }

  Future<void> _dilSec() async {
    final kodlar = Ceviri.diller.keys.toList();
    final adlar = kodlar.map((k) => Ceviri.diller[k]!).toList();
    final secilen = await _aramaliSecim(
      secenekler: adlar,
      secili: Ceviri.diller[Ceviri.dil.value],
      ipucu: 'Dil ara...'.c,
    );
    if (secilen == null) return;
    await Ceviri.sec(kodlar[adlar.indexOf(secilen)]);
    if (mounted) setState(() {});
  }

  /// Arama kutulu seçim sayfası (ülke ve dil için ortak).
  Future<String?> _aramaliSecim({
    required List<String> secenekler,
    required String? secili,
    required String ipucu,
  }) async {
    final arama = TextEditingController();
    try {
      return await _aramaliSecimGoster(arama, secenekler, secili, ipucu);
    } finally {
      arama.dispose();
    }
  }

  Future<String?> _aramaliSecimGoster(
    TextEditingController arama,
    List<String> secenekler,
    String? secili,
    String ipucu,
  ) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DiziRenkler.koyuGri,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          final filtreli = secenekler
              .where(
                (u) =>
                    u.toLowerCase().contains(arama.text.toLowerCase().trim()),
              )
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
                    decoration: InputDecoration(
                      hintText: ipucu,
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtreli.length,
                    itemBuilder: (context, i) => ListTile(
                      title: Text(filtreli[i]),
                      trailing: filtreli[i] == secili
                          ? const Icon(Icons.check, color: DiziRenkler.sari)
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
  }

  Future<void> _disaAktar() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DiziRenkler.koyuGri,
        title: Text('Verilerini dışa aktar'.c),
        content: Text(
          'İzleme geçmişin, puanların, yorumların ve listelerin ZIP olarak '
                  'kayıtlı e-posta adresine gönderilecektir.'
              .c,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal'.c),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Gönder'.c),
          ),
        ],
      ),
    );
    if (onay != true) return;
    try {
      final mesaj = await Api.veriDisaAktar();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mesaj)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _iceAktar() async {
    final secim = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
    );
    final veri = secim?.files.single.bytes;
    if (veri == null) return;
    if (veri.length > 50 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dosya en fazla {}MB olabilir'.cf([50]))),
      );
      return;
    }
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: DiziRenkler.sari),
      ),
    );
    try {
      final ozet = await Api.veriIceAktar(veri);
      if (!mounted) return;
      Navigator.pop(context); // yükleniyor kapat
      int say(String k) => (ozet[k] as num?)?.toInt() ?? 0;
      final satirlar = [
        if (say('durum') > 0) '• {} dizi durumu'.cf([say('durum')]),
        if (say('izleme') > 0) '• {} izleme kaydı'.cf([say('izleme')]),
        if (say('puan') > 0) '• {} puan'.cf([say('puan')]),
        if (say('yorum') > 0) '• {} yorum'.cf([say('yorum')]),
        if (say('liste') > 0) '• {} liste'.cf([say('liste')]),
        if (say('profil') > 0) '• profil bilgisi'.c,
      ];
      final metin = satirlar.isEmpty
          ? 'Aktarılacak tanınan veri bulunamadı.'.c
          : '${satirlar.join('\n')}'
                '${say('atlanan') > 0 ? '\n\n${'{} kayıt atlandı (eşleşmedi).'.cf([say('atlanan')])}' : ''}';
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: DiziRenkler.koyuGri,
          title: Text('İçe aktarım tamamlandı'.c),
          content: Text(metin),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Tamam'.c),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _kaydet() async {
    setState(() => _kaydediliyor = true);
    try {
      final p = await Api.profilGuncelle(
        bio: _bio.text.trim(),
        ulke: _ulke ?? '',
      );
      if (!mounted) return;
      final oturum = context.read<Oturum>();
      await oturum.girisYapildi({...?oturum.kullanici, ...p});
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Profil kaydedildi'.c)));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_hata != null) {
      govde = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_hata!, style: const TextStyle(color: Colors.white54)),
            TextButton(onPressed: _yukle, child: Text('Tekrar dene'.c)),
          ],
        ),
      );
    } else if (_profil == null) {
      govde = const Center(
        child: CircularProgressIndicator(color: DiziRenkler.sari),
      );
    } else {
      final avatar = dosyaUrl(_profil!['avatar'] as String?);
      final kapak = dosyaUrl(_profil!['kapak'] as String?);
      govde = ListView(
        padding: EdgeInsets.zero,
        children: [
          // Kapak (arka plan) + üstüne binen avatar
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // Kapak resmi
              GestureDetector(
                onTap: _kapakYukleniyor ? null : _kapakSec,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  color: DiziRenkler.kart,
                  child: kapak != null
                      ? Image.network(kapak, fit: BoxFit.cover)
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.add_photo_alternate_outlined,
                                color: Colors.white38,
                                size: 30,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Kapak resmi ekle'.c,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              // Kapak düzenle rozeti
              Positioned(
                right: 12,
                top: 12,
                child: InkWell(
                  onTap: _kapakYukleniyor ? null : _kapakSec,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.black54,
                    child: _kapakYukleniyor
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.edit, size: 15, color: Colors.white),
                  ),
                ),
              ),
              // Avatar (kapağın altına taşar)
              Positioned(
                bottom: -46,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: DiziRenkler.siyah,
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: DiziRenkler.kart,
                        backgroundImage: avatar != null
                            ? NetworkImage(avatar)
                            : null,
                        child: avatar == null
                            ? const Icon(
                                Icons.person,
                                size: 48,
                                color: Colors.white38,
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: InkWell(
                        onTap: _avatarYukleniyor ? null : _avatarSec,
                        child: CircleAvatar(
                          radius: 17,
                          backgroundColor: DiziRenkler.sari,
                          child: _avatarYukleniyor
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(
                                  Icons.edit,
                                  size: 17,
                                  color: Colors.black,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 56),
          Center(
            child: Text(
              'Fotoğraf veya GIF — profil ve kapak resmi'.c,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Bio'.c,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bio,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: InputDecoration(
                    hintText: 'Kendinden bahset...'.c,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ülke'.c,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.public, color: DiziRenkler.sari),
                    title: Text(
                      _ulke ?? 'Ülke seç'.c,
                      style: TextStyle(
                        color: _ulke == null ? Colors.white38 : Colors.white,
                      ),
                    ),
                    trailing: _ulke == null
                        ? const Icon(Icons.chevron_right, color: Colors.white38)
                        : IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white38,
                            ),
                            onPressed: () => setState(() => _ulke = null),
                          ),
                    onTap: _ulkeSec,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Dil'.c,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.language,
                      color: DiziRenkler.sari,
                    ),
                    title: Text(Ceviri.diller[Ceviri.dil.value] ?? 'Türkçe'),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white38,
                    ),
                    onTap: _dilSec,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _kaydediliyor ? null : _kaydet,
                  child: _kaydediliyor
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text('Kaydet'.c),
                ),
                const SizedBox(height: 32),
                const Divider(color: Colors.white12),
                const SizedBox(height: 8),
                Text(
                  'Verilerim'.c,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tüm verini (izleme, puan, yorum, liste) TV Time uyumlu ZIP olarak '
                          'al ya da başka uygulamadan gelen ZIP\'i içe aktar.'
                      .c,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _disaAktar,
                  icon: const Icon(Icons.upload_file, color: DiziRenkler.sari),
                  label: Text(
                    'Verilerimi dışa aktar (e-posta)'.c,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _iceAktar,
                  icon: const Icon(Icons.download, color: DiziRenkler.sari),
                  label: Text(
                    'Veri içe aktar (.zip)'.c,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.read<Oturum>().cikis();
                  },
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  label: Text(
                    'Çıkış Yap'.c,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Ayarlar'.c)),
      body: govde,
    );
  }
}
