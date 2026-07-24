import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// GIF mi? (sihirli baytlar) — GIF'ler kırpılmaz, animasyon korunur.
  bool _gifMi(Uint8List veri) =>
      veri.length > 3 && veri[0] == 0x47 && veri[1] == 0x49 && veri[2] == 0x46;

  /// Kırpma/konumlama modalı: kullanıcı kadrajı ayarlar, kırpılmış
  /// baytlar döner (vazgeçerse null).
  Future<Uint8List?> _kirp(
    Uint8List veri, {
    required double oran,
    bool daire = false,
  }) async {
    final kontrol = CropController();
    final sonuc = await showModalBottomSheet<Uint8List?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DiziRenkler.siyah,
      builder: (context) {
        var kirpiliyor = false;
        return StatefulBuilder(
          builder: (context, setSheet) => SizedBox(
            height: MediaQuery.of(context).size.height * 0.85,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Text(
                        'Konumla ve kırp'.c,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context, null),
                        child: Text(
                          'İptal'.c,
                          style: TextStyle(color: DiziRenkler.metin54),
                        ),
                      ),
                      const SizedBox(width: 6),
                      FilledButton(
                        onPressed: kirpiliyor
                            ? null
                            : () {
                                setSheet(() => kirpiliyor = true);
                                kontrol.crop();
                              },
                        child: kirpiliyor
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : Text('Tamam'.c),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Crop(
                    image: veri,
                    controller: kontrol,
                    aspectRatio: oran,
                    withCircleUi: daire,
                    baseColor: DiziRenkler.siyah,
                    maskColor: Colors.black54,
                    onCropped: (kirpik) => Navigator.pop(context, kirpik),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return sonuc;
  }

  Future<void> _avatarSec() async {
    final secim = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (secim == null) return;
    var veri = await secim.readAsBytes();
    // GIF değilse önce konumlama/kırpma modalı (1:1 daire)
    if (!_gifMi(veri)) {
      if (!mounted) return;
      final kirpik = await _kirp(veri, oran: 1, daire: true);
      if (kirpik == null) return;
      veri = kirpik;
    }
    setState(() => _avatarYukleniyor = true);
    try {
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
    var veri = await secim.readAsBytes();
    // GIF değilse önce konumlama/kırpma modalı (geniş kapak oranı)
    if (!_gifMi(veri)) {
      if (!mounted) return;
      final kirpik = await _kirp(veri, oran: 2.4);
      if (kirpik == null) return;
      veri = kirpik;
    }
    setState(() => _kapakYukleniyor = true);
    try {
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

  /// Profil bölümlerinin sırasını sürükle-bırakla düzenler.
  Future<void> _profilDuzeni() async {
    final p = await SharedPreferences.getInstance();
    const gecerli = ['seritler', 'ozet', 'listeler', 'rozetler'];
    final sira = [
      for (final b in p.getStringList('profil_sira') ?? gecerli)
        if (gecerli.contains(b)) b,
    ];
    for (final b in gecerli) {
      if (!sira.contains(b)) sira.add(b);
    }
    final etiketler = {
      'seritler': 'İzlediklerim'.c,
      'ozet': '{} özetin'.cf([DateTime.now().year]),
      'listeler': 'Listelerim'.c,
      'rozetler': 'Rozetler'.c,
    };
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: DiziRenkler.koyuGri,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Profil düzeni'.c,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: (eski, yeni) {
                  setSheet(() {
                    if (yeni > eski) yeni -= 1;
                    sira.insert(yeni, sira.removeAt(eski));
                  });
                  p.setStringList('profil_sira', sira);
                },
                children: [
                  for (final b in sira)
                    ListTile(
                      key: ValueKey(b),
                      leading: Icon(
                        Icons.drag_handle,
                        color: DiziRenkler.metin38,
                      ),
                      title: Text(etiketler[b] ?? b),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
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
                      prefixIcon: Icon(
                        Icons.search,
                        color: DiziRenkler.metin38,
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
            Text(_hata!, style: TextStyle(color: DiziRenkler.metin54)),
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
          // Kapak + avatar: HER ŞEY Stack sınırları İÇİNDE kalmalı —
          // sınır dışına taşan Positioned görünür ama TIKLANAMAZ (hit-test).
          SizedBox(
            height: 202,
            child: Stack(
              children: [
                // Kapak resmi (üst 150px)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 150,
                  child: GestureDetector(
                    onTap: _kapakYukleniyor ? null : _kapakSec,
                    child: Container(
                      color: DiziRenkler.kart,
                      child: kapak != null
                          ? Image.network(kapak, fit: BoxFit.cover)
                          : Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    color: DiziRenkler.metin38,
                                    size: 30,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Kapak resmi ekle'.c,
                                    style: TextStyle(
                                      color: DiziRenkler.metin38,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
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
                          : const Icon(
                              Icons.edit,
                              size: 15,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
                // Avatar (alt kenara hizalı, sınır İÇİNDE)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _avatarYukleniyor ? null : _avatarSec,
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
                                  ? Icon(
                                      Icons.person,
                                      size: 48,
                                      color: DiziRenkler.metin38,
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
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
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Fotoğraf veya GIF — profil ve kapak resmi'.c,
              style: TextStyle(color: DiziRenkler.metin38, fontSize: 12),
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
                        color: _ulke == null
                            ? DiziRenkler.metin38
                            : DiziRenkler.metin,
                      ),
                    ),
                    trailing: _ulke == null
                        ? Icon(Icons.chevron_right, color: DiziRenkler.metin38)
                        : IconButton(
                            tooltip: 'Kapat'.c,
                            icon: Icon(Icons.close, color: DiziRenkler.metin38),
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
                    trailing: Icon(
                      Icons.chevron_right,
                      color: DiziRenkler.metin38,
                    ),
                    onTap: _dilSec,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tema'.c,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.brightness_6_outlined,
                          color: DiziRenkler.sari,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SegmentedButton<String>(
                            segments: [
                              ButtonSegment(
                                value: 'sistem',
                                label: Text('Sistem'.c),
                                icon: const Icon(
                                  Icons.settings_suggest_outlined,
                                ),
                              ),
                              ButtonSegment(
                                value: 'koyu',
                                label: Text('Koyu'.c),
                                icon: const Icon(Icons.dark_mode_outlined),
                              ),
                              ButtonSegment(
                                value: 'acik',
                                label: Text('Açık'.c),
                                icon: const Icon(Icons.light_mode_outlined),
                              ),
                            ],
                            selected: {TemaAyar.mod.value},
                            onSelectionChanged: (s) => TemaAyar.sec(s.first),
                            showSelectedIcon: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Profil bölümlerinin sırası (sürükle-bırak)
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.swap_vert,
                      color: DiziRenkler.sari,
                    ),
                    title: Text('Profil düzeni'.c),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: DiziRenkler.metin38,
                    ),
                    onTap: _profilDuzeni,
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
                Divider(color: DiziRenkler.metin12),
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
                  style: TextStyle(color: DiziRenkler.metin38, fontSize: 12),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _disaAktar,
                  icon: const Icon(Icons.upload_file, color: DiziRenkler.sari),
                  label: Text(
                    'Verilerimi dışa aktar (e-posta)'.c,
                    style: TextStyle(color: DiziRenkler.metin),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _iceAktar,
                  icon: const Icon(Icons.download, color: DiziRenkler.sari),
                  label: Text(
                    'Veri içe aktar (.zip)'.c,
                    style: TextStyle(color: DiziRenkler.metin),
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
