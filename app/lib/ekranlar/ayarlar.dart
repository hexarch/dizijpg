import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../altyazi.dart';
import '../api.dart';
import '../bayrak.dart' show ulkeAdi;
import '../ceviri.dart';
import '../gorusme/arama_servisi.dart';
// `misafirAramaSebebi`: kilitli anahtarın altında ve dokunma açıklamasında
// gösterilen sebep, sunucunun `MISAFIR_ARAMA_YOK` reddiyle AYNI cümle olsun.
import '../gorusme/gorusme_api.dart' show misafirAramaSebebi;
import '../push.dart';
import 'gorsel_kirp.dart';
import 'iki_adim_sheet.dart' show IkiAdimAyariSheet;
import 'ortak.dart' show AgGorsel, DaireGorsel, altGuvenli;
import 'sosyal.dart';
import '../tema.dart';
import '../veri_tasarrufu.dart';

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

/// Segment düğmesi etiketi: uzun çeviri dar hücrede satır KIRMAZ ("Syste/m"
/// hatası, Almanca tema seçici), sığmazsa yazı bir miktar küçülür. 45 dilin
/// en uzunu bile (fi "Järjestelmä") tek satırda kalır.
Widget _segmentEtiket(String metin) => FittedBox(
  fit: BoxFit.scaleDown,
  child: Text(metin, maxLines: 1, softWrap: false),
);

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
  List<Map<String, dynamic>> _sosyal = [];

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
        _sosyal = [
          for (final s in p['sosyal'] as List<dynamic>? ?? [])
            Map<String, dynamic>.from(s as Map),
        ];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
    }
  }

  /// GIF mi? (sihirli baytlar) — GIF'ler kırpılmaz, animasyon korunur.
  Future<void> _avatarSec() async {
    final secim = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (secim == null) return;
    var veri = await secim.readAsBytes();
    // GIF değilse önce konumlama/kırpma modalı (1:1 daire)
    if (!gifMi(veri)) {
      if (!mounted) return;
      final kirpik = await gorselKirp(
        context,
        veri,
        oran: 1,
        daire: true,
        azamiKenar: gorselKirpAvatarKenar,
      );
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
    if (!gifMi(veri)) {
      if (!mounted) return;
      final kirpik = await gorselKirp(
        context,
        veri,
        oran: 2.4,
        azamiKenar: gorselKirpKapakKenar,
      );
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

  /// Ülke seçici.
  ///
  /// SAKLANAN DEĞER TÜRKÇE KALIR: listede görünen ad seçili dile çevrilir
  /// ([ulkeAdi]) ama seçilince `_ulke`ye — ve oradan sunucuya — [ulkeler]
  /// listesindeki TÜRKÇE karşılık yazılır. `ulke` alanı serbest metindir;
  /// çevrilmişini saklamak hem mevcut kayıtlarla tutarsız olurdu hem de
  /// `bayrak.dart`ın ad→ISO eşlemesini kırıp bayrakları kaybettirirdi.
  Future<void> _ulkeSec() async {
    final secilen = await _aramaliSecim(
      secenekler: [for (final u in ulkeler) ulkeAdi(u)],
      degerler: ulkeler,
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
  ///
  /// [secenekler] EKRANDA GÖRÜNEN adlardır. [degerler] verilirse dönen (ve
  /// saklanan) değer oradan gelir — ülke seçicide görünen ad çevrilidir ama
  /// saklanan Türkçe kalır. Verilmezse görünen ad aynı zamanda değerdir
  /// (dil seçici: adlar zaten yerel, çevrilmiyor).
  Future<String?> _aramaliSecim({
    required List<String> secenekler,
    required String? secili,
    required String ipucu,
    List<String>? degerler,
  }) {
    assert(
      degerler == null || degerler.length == secenekler.length,
      'degerler ve secenekler aynı uzunlukta olmalı',
    );
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DiziRenkler.koyuGri,
      builder: (_) => _AramaliSecimSayfasi(
        secenekler: secenekler,
        degerler: degerler,
        secili: secili,
        ipucu: ipucu,
      ),
    );
  }

  /// Hesabı kalıcı siler: onay + (şifreli hesapta) şifre doğrulaması.
  Future<void> _hesabiSil() async {
    final misafir = context.read<Oturum>().kullanici?['misafir'] == true;
    final sifre = TextEditingController();
    var isliyor = false;
    final messenger = ScaffoldMessenger.of(context);
    final oturum = context.read<Oturum>();
    final silindi = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlg) => AlertDialog(
          backgroundColor: DiziRenkler.koyuGri,
          title: Text('Hesabımı Sil'.c),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hesabın ve tüm verin (izleme, puan, yorum, liste, mesaj) '
                        'kalıcı olarak silinecek. Bu işlem geri alınamaz.'
                    .c,
                style: TextStyle(color: DiziRenkler.metin70),
              ),
              if (!misafir) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: sifre,
                  obscureText: true,
                  decoration: InputDecoration(hintText: 'Şifreni gir'.c),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('İptal'.c),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: isliyor
                  ? null
                  : () async {
                      setDlg(() => isliyor = true);
                      try {
                        await Api.hesabiSil(sifre.text);
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (e) {
                        setDlg(() => isliyor = false);
                        messenger.showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    },
              child: isliyor
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('Hesabımı kalıcı sil'.c),
            ),
          ],
        ),
      ),
    );
    sifre.dispose();
    if (silindi == true) {
      await pushTokenSil();
      await oturum.cikis();
    }
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
        sosyal: _sosyal,
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
                          // Kapak GIF olabilir ve OYNAMALI: web'de
                          // CachedNetworkImage <img> yolundan tek kareye
                          // düşüyor (bkz. AgGorsel).
                          ? AgGorsel(
                              url: kapak,
                              yerTutucu: Container(color: DiziRenkler.kart),
                              hata: Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: DiziRenkler.metin38,
                                ),
                              ),
                            )
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
                            // GIF avatar burada da OYNAMALI (kullanıcı
                            // görselini tam burada seçiyor): DecorationImage
                            // yerine ClipOval + Image —
                            // kanıt: test/gif_animasyon_test.dart.
                            child: avatar != null
                                ? DaireGorsel(
                                    url: avatar,
                                    cap: 96,
                                    arkaplan: DiziRenkler.kart,
                                    ikonRenk: DiziRenkler.metin38,
                                  )
                                : CircleAvatar(
                                    radius: 48,
                                    backgroundColor: DiziRenkler.kart,
                                    child: Icon(
                                      Icons.person,
                                      size: 48,
                                      color: DiziRenkler.metin38,
                                    ),
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
                    leading: Icon(Icons.public, color: DiziRenkler.sariMetin),
                    title: Text(
                      // Saklanan değer Türkçe; satırda seçili dilde görünür.
                      _ulke == null ? 'Ülke seç'.c : ulkeAdi(_ulke),
                      style: TextStyle(
                        color: _ulke == null
                            ? DiziRenkler.metin38
                            : DiziRenkler.metin,
                      ),
                    ),
                    trailing: _ulke == null
                        ? Icon(Icons.chevron_right, color: DiziRenkler.metin)
                        : IconButton(
                            tooltip: 'Kapat'.c,
                            icon: Icon(Icons.close, color: DiziRenkler.metin),
                            onPressed: () => setState(() => _ulke = null),
                          ),
                    onTap: _ulkeSec,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sosyal Bağlantılar'.c,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Profilinde en fazla 3 bağlantı gösterilir.'.c,
                  style: TextStyle(color: DiziRenkler.metin38, fontSize: 12),
                ),
                const SizedBox(height: 4),
                SosyalDuzenleyici(
                  sosyal: _sosyal,
                  onDegisti: (yeni) => setState(() => _sosyal = yeni),
                ),
                const SizedBox(height: 12),
                Text(
                  'Dil'.c,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: Icon(Icons.language, color: DiziRenkler.sariMetin),
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
                        Icon(
                          Icons.brightness_6_outlined,
                          color: DiziRenkler.sariMetin,
                        ),
                        const SizedBox(width: 12),
                        // Seçimi ValueListenable'dan oku: "Koyu → Sistem"
                        // (cihaz zaten koyuysa) gibi RENGİ değiştirmeyen
                        // geçişlerde ağaç yeniden kurulmaz; doğrudan
                        // TemaAyar.mod.value okunsaydı düğme eski seçimde
                        // takılı kalırdı.
                        Expanded(
                          child: ValueListenableBuilder<String>(
                            valueListenable: TemaAyar.mod,
                            builder: (context, mod, _) =>
                                SegmentedButton<String>(
                                  // Etiketler [_segmentEtiket] ile sarılı:
                                  // uzun çeviriler ("System" → "Syste/m",
                                  // fi "Järjestelmä") dar hücrede satır
                                  // KIRMAZ, gerekirse küçülür.
                                  segments: [
                                    ButtonSegment(
                                      value: 'sistem',
                                      label: _segmentEtiket('Sistem'.c),
                                      icon: const Icon(
                                        Icons.settings_suggest_outlined,
                                      ),
                                    ),
                                    ButtonSegment(
                                      value: 'koyu',
                                      label: _segmentEtiket('Koyu'.c),
                                      icon: const Icon(
                                        Icons.dark_mode_outlined,
                                      ),
                                    ),
                                    ButtonSegment(
                                      value: 'acik',
                                      label: _segmentEtiket('Açık'.c),
                                      icon: const Icon(
                                        Icons.light_mode_outlined,
                                      ),
                                    ),
                                  ],
                                  selected: {mod},
                                  onSelectionChanged: (s) =>
                                      TemaAyar.sec(s.first),
                                  showSelectedIcon: false,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Veri tasarrufu'.c,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      // Bağlantı türüne göre AYRI ayarlar: varsayılan olarak
                      // Wi-Fi'da kapalı (önden indir), mobil veride açık.
                      ValueListenableBuilder<bool>(
                        valueListenable: VeriTasarrufu.wifi,
                        builder: (context, acik, _) => SwitchListTile(
                          value: acik,
                          activeColor: DiziRenkler.sari,
                          secondary: Icon(
                            Icons.wifi,
                            color: DiziRenkler.sariMetin,
                          ),
                          title: Text('Wi-Fi ağında veri tasarrufu'.c),
                          onChanged: VeriTasarrufu.wifiSec,
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: VeriTasarrufu.mobil,
                        builder: (context, acik, _) => SwitchListTile(
                          value: acik,
                          activeColor: DiziRenkler.sari,
                          secondary: Icon(
                            Icons.signal_cellular_alt,
                            color: DiziRenkler.sariMetin,
                          ),
                          title: Text('Mobil veride veri tasarrufu'.c),
                          onChanged: VeriTasarrufu.mobilSec,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Text(
                          'Açıkken fotoğraflar önceden indirilmez, yalnızca baktığın kare yüklenir.'
                              .c,
                          style: TextStyle(
                            color: DiziRenkler.metin54,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Video altyazıları'.c,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: AltyaziAyar.acik,
                        builder: (context, acik, _) => SwitchListTile(
                          value: acik,
                          activeColor: DiziRenkler.sari,
                          secondary: Icon(
                            Icons.subtitles_outlined,
                            color: DiziRenkler.sariMetin,
                          ),
                          title: Text('Videolarda altyazı göster'.c),
                          onChanged: AltyaziAyar.sec,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Text(
                          'Videoda konuşulan cümle ekranda yazılır. Metin çeviridir: Türkçe konuşmada İngilizce, diğer dillerde Türkçe.'
                              .c,
                          style: TextStyle(
                            color: DiziRenkler.metin54,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      // Görünüm ayarları AYRI ekranda: on denetim burada
                      // olsaydı ayarlar sayfası boğulurdu.
                      Divider(color: DiziRenkler.metin12, height: 1),
                      ListTile(
                        key: const ValueKey('altyazi-bicem-girisi'),
                        leading: Icon(
                          Icons.format_color_text,
                          color: DiziRenkler.sariMetin,
                        ),
                        title: Text('Altyazı görünümü'.c),
                        subtitle: Text(
                          'Renk, yazı tipi, boyut, ayrıt ve opaklık'.c,
                          style: TextStyle(
                            color: DiziRenkler.metin54,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: DiziRenkler.metin38,
                        ),
                        onTap: () => context.push('/altyazi-bicem'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Profil bölümlerinin sırası (sürükle-bırak)
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.swap_vert,
                      color: DiziRenkler.sariMetin,
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
                // HAREKETLERİM (md. 20): beğeni/yorum/izleme/takip/puan/liste
                // hareketlerinin TEK zaman akışı. Ayarların en üst tercih
                // kartlarının hemen üstünde: kişinin KENDİ kaydı, tercih değil.
                Card(
                  child: ListTile(
                    key: const Key('ayar-hareketlerim'),
                    leading: Icon(Icons.timeline, color: DiziRenkler.sariMetin),
                    title: Text(
                      'Hareketlerim'.c,
                      style: TextStyle(color: DiziRenkler.metin),
                    ),
                    subtitle: Text(
                      'Beğenilerin, yorumların, izlemelerin tek akışta'.c,
                      style: TextStyle(
                        color: DiziRenkler.metin54,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: DiziRenkler.metin38,
                    ),
                    onTap: () => GoRouter.of(context).push('/hareketlerim'),
                  ),
                ),
                const SizedBox(height: 8),
                // İSTATİSTİKLERİM (md. 24): kendi gönderilerinin görüntülenme
                // ve beğeni sayıları + 30/60/90/120 günlük kırılım.
                // Hareketlerim'in HEMEN ALTINDA çünkü ikisi de "tercih" değil
                // KİŞİNİN KENDİ KAYDI: biri ne yaptığını, öbürü ne kadar
                // ulaştığını gösteriyor.
                Card(
                  child: ListTile(
                    key: const Key('ayar-istatistiklerim'),
                    leading: Icon(
                      Icons.insights_outlined,
                      color: DiziRenkler.sariMetin,
                    ),
                    title: Text(
                      'İstatistiklerim'.c,
                      style: TextStyle(color: DiziRenkler.metin),
                    ),
                    subtitle: Text(
                      'Gönderilerinin görüntülenmesi ve beğenisi'.c,
                      style: TextStyle(
                        color: DiziRenkler.metin54,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: DiziRenkler.metin38,
                    ),
                    onTap: () => GoRouter.of(context).push('/istatistiklerim'),
                  ),
                ),
                const SizedBox(height: 8),
                // İZLEME İSTATİSTİKLERİM (19 Ağu isteği). İstatistiklerim'in
                // HEMEN ALTINDA: ikisi de "kendi kaydım" ama biri gönderinin
                // KİTLEYE ulaşmasını, bu ise kişinin KENDİ izlemesini ölçüyor.
                Card(
                  child: ListTile(
                    key: const Key('ayar-izleme-istatistik'),
                    leading: Icon(
                      Icons.query_stats_outlined,
                      color: DiziRenkler.sariMetin,
                    ),
                    title: Text(
                      'İzleme İstatistiklerim'.c,
                      style: TextStyle(color: DiziRenkler.metin),
                    ),
                    subtitle: Text(
                      'Ekran süren, serin ve en çok izlediklerin'.c,
                      style: TextStyle(
                        color: DiziRenkler.metin54,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: DiziRenkler.metin38,
                    ),
                    onTap: () =>
                        GoRouter.of(context).push('/izleme-istatistik'),
                  ),
                ),
                const SizedBox(height: 8),
                // SIRA (3 Ağu isteği): Bildirim Tercihleri · Gizlilik · Geri
                // Bildirim ARTIK "Verilerim"in ÜSTÜNDE. Günlük kullanılan üç
                // tercih kartı, nadiren açılan dışa/içe aktarımın altında
                // kalmıyor. Kartların içeriği/davranışı DEĞİŞMEDİ, yalnız yer.
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.notifications_none,
                      color: DiziRenkler.sariMetin,
                    ),
                    title: Text(
                      'Bildirim Tercihleri'.c,
                      style: TextStyle(color: DiziRenkler.metin),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: DiziRenkler.metin38,
                    ),
                    onTap: () => showModalBottomSheet(
                      context: context,
                      backgroundColor: DiziRenkler.koyuGri,
                      isScrollControlled: true,
                      builder: (_) => const _BildirimTercihleriSheet(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.visibility_off_outlined,
                      color: DiziRenkler.sariMetin,
                    ),
                    title: Text(
                      'Gizlilik'.c,
                      style: TextStyle(color: DiziRenkler.metin),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: DiziRenkler.metin38,
                    ),
                    onTap: () => showModalBottomSheet(
                      context: context,
                      backgroundColor: DiziRenkler.koyuGri,
                      isScrollControlled: true,
                      builder: (_) => const _GizlilikSheet(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // md. 52 — İki adımlı doğrulama (YALNIZ e-posta).
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.lock_outline,
                      color: DiziRenkler.sariMetin,
                    ),
                    title: Text(
                      'İki Adımlı Doğrulama'.c,
                      style: TextStyle(color: DiziRenkler.metin),
                    ),
                    subtitle: Text(
                      'Girişte e-postana kod gönderilir'.c,
                      style: TextStyle(
                        color: DiziRenkler.metin38,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: DiziRenkler.metin38,
                    ),
                    onTap: () => showModalBottomSheet(
                      context: context,
                      backgroundColor: DiziRenkler.koyuGri,
                      isScrollControlled: true,
                      builder: (_) => const IkiAdimAyariSheet(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.rate_review_outlined,
                      color: DiziRenkler.sariMetin,
                    ),
                    title: Text(
                      'Geri Bildirim'.c,
                      style: TextStyle(color: DiziRenkler.metin),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: DiziRenkler.metin38,
                    ),
                    onTap: () => showModalBottomSheet(
                      context: context,
                      backgroundColor: DiziRenkler.koyuGri,
                      isScrollControlled: true,
                      builder: (_) => const _GeriBildirimSheet(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
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
                  icon: Icon(Icons.upload_file, color: DiziRenkler.sariMetin),
                  label: Text(
                    'Verilerimi dışa aktar (e-posta)'.c,
                    style: TextStyle(color: DiziRenkler.metin),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _iceAktar,
                  icon: Icon(Icons.download, color: DiziRenkler.sariMetin),
                  label: Text(
                    'Veri içe aktar (.zip)'.c,
                    style: TextStyle(color: DiziRenkler.metin),
                  ),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () async {
                    final oturum = context.read<Oturum>();
                    await pushTokenSil(); // bu cihaza artık bildirim gitmesin
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    oturum.cikis();
                  },
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  label: Text(
                    'Çıkış Yap'.c,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.push('/gizlilik'),
                  child: Text(
                    'Gizlilik Politikası'.c,
                    style: TextStyle(
                      color: DiziRenkler.metin54,
                      decoration: TextDecoration.underline,
                      decorationColor: DiziRenkler.metin54,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _hesabiSil,
                  child: Text(
                    'Hesabımı Sil'.c,
                    style: TextStyle(
                      color: DiziRenkler.metin54,
                      decoration: TextDecoration.underline,
                      decorationColor: DiziRenkler.metin54,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Sürüm: hata bildiriminde kullanıcıdan istenen ilk bilgi. Ana sayfa
          // üst barı yer darlığından yapı numarasını atıyor; burada TAM sürüm
          // (1.19.0+61) gösteriliyor — aynı sürümün farklı derlemeleri ancak
          // yapı numarasıyla ayrılıyor. Çeviri gerekmez: salt sürüm dizesi.
          Center(
            child: Text(
              'v${Api.surum}',
              style: TextStyle(color: DiziRenkler.metin38, fontSize: 12),
            ),
          ),
          // NEDEN sabit 24 değil: ListView'e `padding: EdgeInsets.zero` verildiği
          // an Flutter'ın MediaQuery güvenli alanını kendiliğinden eklemesi
          // devre dışı kalır (BoxScrollView yalnız padding == null iken ekler).
          // Bu yüzden liste sonu telefonun sistem gezinme çubuğunun ALTINDA
          // kalıyor, "Hesabımı Sil" dokunulamıyordu. altGuvenli sistem alt
          // payını ekler: jest çubuğu olan ve olmayan cihazda da doğru.
          SizedBox(height: altGuvenli(context, ekstra: 24)),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Ayarlar'.c)),
      // PC'de akış ile AYNI ortalanmış okuma kolonu (madde 26); mobilde kısıt
      // bağlamaz.
      body: OrtaKolon(azami: masaustuKolonGenisligi, cocuk: govde),
    );
  }
}

/// Bildirim tercihleri: her bildirim türünü ayrı aç/kapat (beğeni, yanıt,
/// takip, mesaj, etiket). Kapalı tür ne uygulama-içi bildirim ne push üretir.
class _BildirimTercihleriSheet extends StatefulWidget {
  const _BildirimTercihleriSheet();

  @override
  State<_BildirimTercihleriSheet> createState() =>
      _BildirimTercihleriSheetState();
}

class _BildirimTercihleriSheetState extends State<_BildirimTercihleriSheet> {
  Map<String, dynamic>? _tercih;
  String? _hata;

  static const _alanlar = [
    ('bildir_begeni', 'Beğeniler'),
    ('bildir_yanit', 'Yanıtlar'),
    ('bildir_takip', 'Yeni takipçiler'),
    ('bildir_mesaj', 'Mesajlar'),
    ('bildir_etiket', 'Etiketlenmeler'),
    // Md. 27: izlediğin dizinin yeni bölümü (yalnız bir öncekini izlediysen).
    ('bildir_bolum', 'Yeni bölümler'),
    // Md. 28: favori kişinin (oyuncu/yönetmen) yeni dizi/filmi. Kişi BAZINDA
    // ayar kişinin kendi sayfasında (üç durumlu); bu satır GENEL anahtardır.
    ('bildir_kisi', 'Favori kişilerin yeni yapımları'),
  ];

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final d = await Api.get('/bildirim-tercihleri');
      if (mounted) setState(() => _tercih = Map<String, dynamic>.from(d));
    } catch (e) {
      if (mounted) setState(() => _hata = e.toString());
    }
  }

  Future<void> _degistir(String alan, bool deger) async {
    final eski = _tercih![alan];
    setState(() => _tercih![alan] = deger); // iyimser
    try {
      await Api.post('/bildirim-tercihleri', {alan: deger});
    } catch (e) {
      if (mounted) {
        setState(() => _tercih![alan] = eski); // geri al
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
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
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 20,
                    color: DiziRenkler.sariMetin,
                  ),
                  const SizedBox(width: 8),
                  // Expanded: uzun çeviri dar ekranda taşmak yerine sarar.
                  Expanded(
                    child: Text(
                      'Bildirim Tercihleri'.c,
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
            else if (_tercih == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: DiziRenkler.sari),
              )
            else
              for (final (alan, etiket) in _alanlar)
                SwitchListTile(
                  value: _tercih![alan] == true,
                  activeColor: DiziRenkler.sari,
                  title: Text(
                    etiket.c,
                    style: TextStyle(color: DiziRenkler.metin, fontSize: 15),
                  ),
                  onChanged: (v) => _degistir(alan, v),
                ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// Gizlilik tercihleri: izlenenleri ve yorumları açık profilde gizle.
/// Tek bir dizi/filmi gizlemek içerik sayfasındaki "Profilimde gizle" çipinde.
class _GizlilikSheet extends StatefulWidget {
  const _GizlilikSheet();

  @override
  State<_GizlilikSheet> createState() => _GizlilikSheetState();
}

class _GizlilikSheetState extends State<_GizlilikSheet> {
  Map<String, dynamic>? _tercih;
  String? _hata;

  static const _alanlar = [
    // Açıklama 14 Ağu'da GENİŞLETİLDİ çünkü ZORLAMA genişledi: şeritler zaten
    // gizleniyordu ama Bölüm/Film sayaçları, ekran süresi kartı, uyum kartı ve
    // "5.000 bölüm" rozeti açık kalıyordu — gizlenen şeyin BOYUTU
    // gizlenmiyordu. Artık hepsi düşüyor ve metin bunu söylüyor.
    (
      'izlenenler_gizli',
      'İzlediklerimi gizle',
      'Profilinde izlediğin dizi ve filmler, izleme sayaçların, ekran süren ve uyum kartın başkalarına görünmez',
    ),
    ('yorumlar_gizli', 'Yorumlarımı gizle', 'Profilinde yorumların görünmez'),
    // POLARİTE BİLEREK "gizle": kullanıcı isteği "yanıtlar görünsün" biçiminde
    // geldi ama bu listedeki öteki iki anahtar "gizle" yönünde. Aynı listede
    // ters yönlü bir anahtar (açık = görünür) olsaydı üç düğmenin hangisinin
    // ne yaptığı her okumada yeniden düşünülürdü.
    (
      'yanitlar_gizli',
      'Yanıtlarımı gizle',
      'Başkalarının gönderilerine yazdığın yanıtlar yalnız sana görünür',
    ),
    // --- Takip grafiği (14 Ağu 2026, md. 21) ---
    // İKİ AYRI ANAHTAR, tek "takip grafiğimi gizle" DEĞİL: "kimi takip
    // ediyorum" bir zevk beyanıdır, "kim beni takip ediyor" başkalarının
    // kararıdır — kişi birini saklarken ötekini açık bırakmak isteyebilir.
    //
    // Açıklamalarda SAYININ AÇIK KALDIĞI açıkça yazıyor: sunucu listeyi
    // süzer ama sayacı süzmez (`POST /takip` yanıtı zaten güncel sayıyı
    // döndürüyor). Yazılmasaydı kullanıcı anahtarı açar, profilinde "128
    // Takipçi" yazısını görür ve ayarın çalışmadığını sanırdı.
    (
      'takipciler_gizli',
      'Takipçi listemi gizle',
      'Seni kimlerin takip ettiğini başkaları göremez; takipçi sayın görünmeye devam eder',
    ),
    (
      'takip_edilenler_gizli',
      'Takip ettiklerimi gizle',
      'Kimleri takip ettiğini başkaları göremez; takip sayın görünmeye devam eder',
    ),
    // Kapatınca mesaj listesindeki yeşil nokta VE sohbet başlığındaki
    // "son görülme ..." satırı başkalarına görünmez. TEK YÖNLÜ: sen
    // başkalarının durumunu görmeye devam edersin (öteki anahtarlar gibi).
    (
      'cevrimici_gizli',
      'Çevrimiçi durumumu gizle',
      'Mesajlarda çevrimiçi olduğun ve son görülme zamanın başkalarına görünmez',
    ),
  ];

  /// Sesli/görüntülü arama izinleri (istek listesi md. 38).
  ///
  /// POLARİTE YUKARIDAKİLERİN TERSİ ve bu BİLİNÇLİ: yukarıdakiler "gizle"
  /// (true = kapat), bunlar "izin ver" (true = aç). Aynı listeye karıştırılıp
  /// tek `for` ile çizilmiyor, ayrı başlık altında duruyorlar — kullanıcı
  /// "izin ver"i kapalı görünce ne olduğunu düşünmek zorunda kalmasın.
  ///
  /// >>> İKİSİ DE VARSAYILAN KAPALI <<< (kullanıcı kararı, 10 Ağu). Yani bu
  /// ekranı hiç açmayan kimse aranamaz. Yan faydası: arama bayraklarını
  /// canlıda açmak riskisiz — kimse istemeden aranabilir hâle gelmiyor.
  ///
  /// Bedeli de gerçek: kimse bilmezse kimse açmaz. Bu yüzden sohbetteki pasif
  /// düğme tıklanınca buraya yönlendiren bir açıklama gösteriyor.
  static const _aramaAlanlari = [
    (
      'sesli_arama_acik',
      'Sesli aramalara izin ver',
      'Kapalıyken kimse seni sesli arayamaz; arayan "devre dışı" uyarısı görür',
    ),
    (
      'goruntulu_arama_acik',
      'Görüntülü aramalara izin ver',
      'Kapalıyken kimse seni görüntülü arayamaz; arayan "devre dışı" uyarısı görür',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final d = await Api.get('/gizlilik-tercihleri');
      if (mounted) setState(() => _tercih = Map<String, dynamic>.from(d));
    } catch (e) {
      if (mounted) setState(() => _hata = e.toString());
    }
  }

  Future<void> _degistir(String alan, bool deger) async {
    final eski = _tercih![alan];
    setState(() => _tercih![alan] = deger); // iyimser
    _aramaServisineYansit(alan, deger);
    try {
      await Api.post('/gizlilik-tercihleri', {alan: deger});
    } catch (e) {
      if (mounted) {
        setState(() => _tercih![alan] = eski); // geri al
        // Arama düğmeleri de geri alınmalı: yoksa sunucu "kapalı" bilirken
        // sohbette düğme AKTİF görünür ve kullanıcı 403 yer. Sessiz tutarsızlık.
        _aramaServisineYansit(alan, eski == true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  /// Bu hesap misafir mi. `GET /gizlilik-tercihleri` yanıtından gelir; AYRI
  /// BİR İSTEK ATILMAZ (sunucu bu alanı tam da bunun için ekledi).
  ///
  /// `Oturum.kullanici['misafir']` de okunabilirdi ama o değer GİRİŞ ANINDAKİ
  /// kopyadır: kullanıcı `/auth/bagla` ile hesabını bağladıktan sonra uygulama
  /// yeniden başlatılana kadar bayat kalabilir ve anahtarlar boşuna kilitli
  /// görünürdü. Sheet her açılışta tercihleri zaten çekiyor.
  bool get _misafir => _tercih?['misafir'] == true;

  /// MİSAFİR HESAPTA arama anahtarı: KİLİTLİ ve SEBEBİ YAZILI.
  ///
  /// Kullanıcı kararı (10 Ağu): "misafir hesaplar aranamasın ve bu ayarları
  /// açamasınlar, ***sebebini de onlara söyle***."
  ///
  /// NEDEN `SwitchListTile(onChanged: null)` DEĞİL: devre dışı bir
  /// `SwitchListTile` dokunuşu hiç almaz, dolayısıyla "kilitli anahtara
  /// dokununca da aynı açıklama görünsün" isteği yerine getirilemezdi.
  /// Buradaki `Switch` görsel olarak kilitli (`onChanged: null`), satırın
  /// KENDİSİ ise tıklanabilir ve açıklamayı tekrar gösteriyor.
  ///
  /// Sebep hem ALT SATIRDA sürekli duruyor (dokunmadan da okunur) hem de
  /// dokununca SnackBar'da tekrar ediyor + hesap oluşturmaya götürüyor:
  /// kurtarma yolu olmayan bir "kapalı" mesajı kötü mesajdır.
  /// `ui-ux-pro-max` sorgularından uygulananlar:
  ///   * *Disabled States* ("clearly indicate non-interactive elements"):
  ///     kilit ÜÇ ayrı sinyalle anlatılıyor — kilit ikonu, devre dışı `Switch`
  ///     ve soluk başlık. Tek sinyal (yalnız renk) yetmez.
  ///   * *Error Recovery* ("provide clear next steps"): açıklama yalnız
  ///     "yapamazsın" demiyor, hesap bağlamaya götüren bir eylem sunuyor.
  ///   * *Semantics* (Flutter yığın kuralı, önem: yüksek): [MergeSemantics]
  ///     olmadan ekran okuyucu "etiket", "sebep" ve "kapalı anahtar"ı ÜÇ AYRI
  ///     düğüm olarak okur ve aralarındaki bağ kaybolur. `SwitchListTile`
  ///     bunu kendi içinde yapıyor; elle kurulan bu satırda açıkça gerekiyor.
  ///
  /// **Başlık `metin38` DEĞİL `metin54`:** `metin38` (white38) koyu sheet
  /// zemininde (0xFF17171A) kontrastı 4,5:1'in altına düşürür ve buradaki
  /// metin okunması GEREKEN bir metin — dekoratif bir pasiflik göstergesi
  /// değil. Pasiflik hissini kilit ikonu ve devre dışı anahtar veriyor;
  /// okunabilirlikten ödün verilmiyor. (`sohbet` başlığındaki pasif ikon
  /// `metin38` kalabilir: orada metin değil, ikon var.)
  Widget _kilitliAramaSatiri(String alan, String etiket) => MergeSemantics(
    child: ListTile(
      key: Key('gizlilik-$alan'),
      leading: Icon(Icons.lock_outline, color: DiziRenkler.metin54, size: 20),
      title: Text(
        etiket.c,
        style: TextStyle(color: DiziRenkler.metin54, fontSize: 15),
      ),
      subtitle: Text(
        misafirAramaSebebi.c,
        style: TextStyle(color: DiziRenkler.metin54, fontSize: 12),
      ),
      // `Switch` kapalı ve devre dışı: kilit yalnız ikonla değil, anahtarın
      // kendi görünümüyle de anlatılıyor.
      trailing: const Switch(value: false, onChanged: null),
      onTap: _misafirAciklamasi,
    ),
  );

  void _misafirAciklamasi() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(misafirAramaSebebi.c),
        // 5 sn: iki satırlık açıklama + eylem düğmesi için 4 sn kısa kalıyor
        // (sohbetteki pasif düğme açıklamasıyla aynı ölçü).
        duration: const Duration(seconds: 5),
        // Kurtarma yolu: hesabı bağlama bandı PROFİL sayfasında duruyor
        // (`profil.dart`, "Misafir hesabındasın — e-postanla bağla"). Ayrı bir
        // "hesap oluştur" rotası YOK; olmayan bir yola göndermektense var olan
        // tek yere götürüyoruz. Sheet ÖNCE kapanır (projedeki kalıp), yoksa
        // kullanıcı geri döndüğünde üstüne yapışmış bir sheet bulur.
        action: SnackBarAction(
          label: 'Profil'.c,
          onPressed: () {
            final yonlendirici = GoRouter.of(context);
            Navigator.pop(context);
            yonlendirici.go('/profil');
          },
        ),
      ),
    );
  }

  /// Arama tercihi değiştiyse bellekteki kopyayı da güncelle — açık sohbet
  /// ekranlarındaki düğmeler anında pasif/aktif olsun. (Öteki `_gizli`
  /// alanlarında karşılığı yok; onlar sunucudan okunuyor.)
  void _aramaServisineYansit(String alan, bool deger) {
    if (alan == 'sesli_arama_acik') {
      AramaServisi.kendiTercihiKur(sesli: deger);
    } else if (alan == 'goruntulu_arama_acik') {
      AramaServisi.kendiTercihiKur(goruntulu: deger);
    }
  }

  @override
  Widget build(BuildContext context) {
    // KAYDIRILABİLİR OLMAK ZORUNDA. md. 38'in iki anahtarı eklenince bu sheet
    // 600 dp yükseklikte 50 px TAŞTI (sarı-siyah çizgili hata bandı) — kısa
    // ekranlarda ve büyük yazı tipi ölçeğinde son öğeler kesilirdi.
    // `mainAxisSize: min` içerik sığdığında sheet'i yine kısa tutuyor; taşınca
    // artık kırpmak yerine kayıyor. (`showModalBottomSheet` zaten
    // `isScrollControlled: true` ile açılıyor.)
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.visibility_off_outlined,
                    size: 20,
                    color: DiziRenkler.sariMetin,
                  ),
                  const SizedBox(width: 8),
                  // Expanded: uzun çeviri dar ekranda taşmak yerine sarar.
                  Expanded(
                    child: Text(
                      'Gizlilik'.c,
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
            else if (_tercih == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: DiziRenkler.sari),
              )
            else ...[
              for (final (alan, etiket, aciklama) in _alanlar)
                SwitchListTile(
                  // Anahtar, aşağıdaki arama satırlarıyla AYNI kalıpta
                  // (`gizlilik-<alan>`): widget testi altı anahtarı da adıyla
                  // bulabilsin, sıra değişince test kırılmasın.
                  key: Key('gizlilik-$alan'),
                  value: _tercih![alan] == true,
                  activeColor: DiziRenkler.sari,
                  title: Text(
                    etiket.c,
                    style: TextStyle(color: DiziRenkler.metin, fontSize: 15),
                  ),
                  subtitle: Text(
                    aciklama.c,
                    style: TextStyle(color: DiziRenkler.metin54, fontSize: 12),
                  ),
                  onChanged: (v) => _degistir(alan, v),
                ),
              // --- Aramalar (md. 38) ---
              // Ayrı başlık: bu iki anahtarın polaritesi yukarıdakilerin TERSİ
              // ("izin ver" / "gizle") ve ikisi de VARSAYILAN KAPALI. Aynı
              // öbekte, ayrımsız çizilselerdi kullanıcı hangi yönün ne demek
              // olduğunu her okuyuşta yeniden düşünürdü.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.call_outlined,
                      size: 18,
                      color: DiziRenkler.sariMetin,
                    ),
                    const SizedBox(width: 8),
                    // Expanded: uzun çeviri dar ekranda taşmak yerine sarar.
                    Expanded(
                      child: Text(
                        // "Aramalar" TEK BAŞINA KULLANILMADI: bu projede
                        // "arama" hem dizi araması hem telefon araması demek.
                        // Ayarlar ekranında kısa hâli okuyanı yanıltırdı.
                        'Sesli ve görüntülü arama'.c,
                        style: TextStyle(
                          color: DiziRenkler.metin,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              for (final (alan, etiket, aciklama) in _aramaAlanlari)
                if (_misafir)
                  _kilitliAramaSatiri(alan, etiket)
                else
                  SwitchListTile(
                    key: Key('gizlilik-$alan'),
                    value: _tercih![alan] == true,
                    activeColor: DiziRenkler.sari,
                    title: Text(
                      etiket.c,
                      style: TextStyle(color: DiziRenkler.metin, fontSize: 15),
                    ),
                    subtitle: Text(
                      aciklama.c,
                      style: TextStyle(
                        color: DiziRenkler.metin54,
                        fontSize: 12,
                      ),
                    ),
                    onChanged: (v) => _degistir(alan, v),
                  ),
              // Tek tek gizlenen yorumların yönetim yeri. Sheet ÖNCE kapanır,
              // sonra gidilir: kullanıcı geri döndüğünde üstüne yapışmış bir
              // sheet bulmasın (begenenler.dart'taki kalıbın aynısı).
              ListTile(
                leading: Icon(
                  Icons.speaker_notes_off_outlined,
                  color: DiziRenkler.sariMetin,
                ),
                title: Text(
                  'Gizlenen yorumlar'.c,
                  style: TextStyle(color: DiziRenkler.metin, fontSize: 15),
                ),
                subtitle: Text(
                  'Profilinde gizlediğin yorumları tekrar göster'.c,
                  style: TextStyle(color: DiziRenkler.metin54, fontSize: 12),
                ),
                trailing: Icon(Icons.chevron_right, color: DiziRenkler.metin),
                onTap: () {
                  final yonlendirici = GoRouter.of(context);
                  Navigator.pop(context);
                  yonlendirici.push('/gizlenen-yorumlar');
                },
              ),
              // Engellenen kullanıcıların TEK toplu yönetim yeri (md. 19).
              // Buradan girilmezse engel fiilen kalıcı olur: engellenen kişi
              // aramada/listelerde görünmediği için profiline ulaşılamaz.
              // Sheet ÖNCE kapanır, sonra gidilir (üstteki satırla aynı kalıp).
              ListTile(
                key: const Key('ayar-engellenenler'),
                leading: Icon(
                  Icons.block_outlined,
                  color: DiziRenkler.sariMetin,
                ),
                title: Text(
                  'Engellenen kullanıcılar'.c,
                  style: TextStyle(color: DiziRenkler.metin, fontSize: 15),
                ),
                subtitle: Text(
                  'Engellediğin kişileri gör, engeli kaldır'.c,
                  style: TextStyle(color: DiziRenkler.metin54, fontSize: 12),
                ),
                trailing: Icon(Icons.chevron_right, color: DiziRenkler.metin),
                onTap: () {
                  final yonlendirici = GoRouter.of(context);
                  Navigator.pop(context);
                  yonlendirici.push('/engellenenler');
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 15,
                      color: DiziRenkler.metin38,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tek bir dizi veya filmi, içeriğin sayfasındaki "Profilimde gizle" çipiyle gizleyebilirsin.'
                            .c,
                        style: TextStyle(
                          color: DiziRenkler.metin38,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Geri bildirim: kullanıcı görüş/önerisini yazar, sunucuya kaydedilir.
class _GeriBildirimSheet extends StatefulWidget {
  const _GeriBildirimSheet();

  @override
  State<_GeriBildirimSheet> createState() => _GeriBildirimSheetState();
}

class _GeriBildirimSheetState extends State<_GeriBildirimSheet> {
  final _metin = TextEditingController();
  bool _gonderiliyor = false;

  @override
  void dispose() {
    _metin.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    final metin = _metin.text.trim();
    if (metin.length < 3 || _gonderiliyor) return;
    setState(() => _gonderiliyor = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Sürüm/platform da gitsin: hangi derlemeden geldiğini bilmeden
      // "bende olmuyor" raporları kovalanamıyor.
      await Api.post('/geri-bildirim', {
        'metin': metin,
        'surum': Api.surum,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      });
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Teşekkürler! Geri bildirimin alındı.'.c)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _gonderiliyor = false);
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
                  Icons.rate_review_outlined,
                  size: 20,
                  color: DiziRenkler.sariMetin,
                ),
                const SizedBox(width: 8),
                // Expanded: uzun çeviri dar ekranda taşmak yerine sarar.
                Expanded(
                  child: Text(
                    'Geri Bildirim'.c,
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
              controller: _metin,
              maxLines: 5,
              maxLength: 2000,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Uygulama hakkında görüş ve önerini yaz...'.c,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _gonderiliyor ? null : _gonder,
              child: _gonderiliyor
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : Text('Gönder'.c),
            ),
          ],
        ),
      ),
    );
  }
}

/// Arama kutulu seçim sayfası (ülke ve dil seçicilerinin ortak gövdesi).
///
/// NEDEN AYRI WIDGET (ve `StatefulBuilder` + dışarıda tutulan denetleyici
/// DEĞİL): denetleyici sayfayı AÇAN metotta kurulup `finally`de atılıyordu.
/// `showModalBottomSheet`in future'ı sayfa POP edilir edilmez tamamlanır ama
/// KAPANMA ANİMASYONU sürer ve TextField o sırada hâlâ yeniden kurulur —
/// sonuç: "A TextEditingController was used after being disposed" (ülke/dil
/// seçilir seçilmez, her seferinde). Denetleyici artık kendi State'inde
/// yaşıyor: ömrü tam olarak widget'ın ömrü kadar.
///
/// [secenekler] EKRANDA GÖRÜNEN adlardır. [degerler] verilirse seçim sonucu
/// oradan döner — ülke seçicide görünen ad çevrilidir ama SAKLANAN DEĞER
/// TÜRKÇE kalır (bkz. `_ulkeSec`). Verilmezse görünen ad değerin kendisidir
/// (dil seçici: adlar zaten yerel, çevrilmez).
class _AramaliSecimSayfasi extends StatefulWidget {
  const _AramaliSecimSayfasi({
    required this.secenekler,
    required this.degerler,
    required this.secili,
    required this.ipucu,
  });

  final List<String> secenekler;
  final List<String>? degerler;
  final String? secili;
  final String ipucu;

  @override
  State<_AramaliSecimSayfasi> createState() => _AramaliSecimSayfasiState();
}

class _AramaliSecimSayfasiState extends State<_AramaliSecimSayfasi> {
  final _arama = TextEditingController();

  @override
  void dispose() {
    _arama.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secenekler = widget.secenekler;
    final degerler = widget.degerler;
    final sorgu = _arama.text.toLowerCase().trim();
    // DİZİN üzerinden süz: görünen ad ile saklanan değer ÇİFT kalsın
    // (ayrı ayrı süzülse ülke seçiminde eşleşme kayardı).
    // Arama ikisini de tarar — İspanyolca arayüzde "Alemania" yazan da,
    // ezberinden "Almanya" yazan da ülkeyi bulur.
    final filtreli = [
      for (var i = 0; i < secenekler.length; i++)
        if (sorgu.isEmpty ||
            secenekler[i].toLowerCase().contains(sorgu) ||
            (degerler?[i].toLowerCase().contains(sorgu) ?? false))
          i,
    ];
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: _arama,
              autofocus: false,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: widget.ipucu,
                prefixIcon: Icon(Icons.search, color: DiziRenkler.metin),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtreli.length,
              itemBuilder: (context, i) {
                final j = filtreli[i];
                // Ekranda görünen ad çevrili; geri dönen değer saklanan
                // (ülkede Türkçe) karşılık.
                final deger = degerler?[j] ?? secenekler[j];
                return ListTile(
                  title: Text(secenekler[j]),
                  trailing: deger == widget.secili
                      ? Icon(Icons.check, color: DiziRenkler.sariMetin)
                      : null,
                  onTap: () => Navigator.pop(context, deger),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
