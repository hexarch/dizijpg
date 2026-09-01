import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../ceviri.dart';
import '../gorsel_basliklari.dart';
import '../tema.dart';
import 'ortak.dart';

/// İLK AÇILIŞ KARŞILAMA AKIŞI (istek md. 25, 10 Ağu 2026)
///
/// Kullanıcı isteği birebir: girişten SONRA, uygulama ilk kez açıldığında
/// sırayla (1) doğum tarihi sorulsun, (2) dışarıdan veri aktarmayı
/// desteklediğimiz söylensin, (3) izlediği FİLMLER sorulsun — görünür bir
/// "seri filmler" düğmesiyle Harry Potter gibi serilerin TAMAMI tek dokunuşla
/// işaretlenebilsin, (4) DİZİLER sorulsun ve seçime göre ALAKALI diziler
/// öne çıksın, (5) uygulama tanıtılsın.
///
/// --- TASARIM KARARLARI ---
///
/// * **Her adım atlanabilir.** Alt çubukta "Şimdilik geç" adımı geçer, üst
///   sağdaki kapatma akışın tamamını bitirir. Hiçbir adım kilitli değil
///   (ui-ux-pro-max / Onboarding → "User Freedom": Skip ve Back şart).
/// * **Bir daha zorla açılmaz.** Akış bitince ya da atlanınca
///   `kullanicilar.karsilama_bitti` sunucuda işaretlenir + yerel bir kopya
///   yazılır. Bayrak SUNUCUDA çünkü akış HESABA aittir: doğum tarihi ve
///   işaretlenen yapımlar da orada. Yalnız cihazda tutulsaydı telefon
///   değiştiren kullanıcıya beş adım baştan sorulurdu. Yerel kopya yalnız
///   açılışta ağ beklememek için var (hızlandırma, doğruluk kaynağı değil).
/// * **Doğum tarihi hassas veridir**: profilde HERKESE AÇIK gösterilmez,
///   yalnız yaş doğrulama ve doğum günü kutlaması (md. 36) için tutulur.
///   Yıl İSTEĞE BAĞLI — kullanıcı yaşını vermeden gün+ay bırakabilir
///   (sunucu tarafı gerekçe: `backend/migrasyon-2026-08-13e.sql`).
/// * **Veri aktarma YENİDEN YAZILMAZ**: 2. adım MEVCUT ZIP içe aktarımını
///   (`Api.veriIceAktar` → `backend/veri_aktar.js`) doğrudan çağırır. Ayarlar
///   ekranına gidilmiyor çünkü `yonlendirme.dart`taki karşılama koruması akış
///   bitene kadar her rotayı `/karsilama`ya geri atar.
class KarsilamaEkrani extends StatefulWidget {
  const KarsilamaEkrani({super.key});

  @override
  State<KarsilamaEkrani> createState() => _KarsilamaEkraniState();
}

/// Akışın kalıcı bayrağının YEREL kopyası. Doğruluk kaynağı sunucudaki
/// `kullanicilar.karsilama_bitti`.
const String karsilamaBittiAnahtari = 'karsilama_bitti';

/// Toplam adım sayısı — göstergede ve testte kullanılır.
const int karsilamaAdimSayisi = 5;

/// Ay adları. `intl`in yerel ay adları KULLANILMADI: `DateFormat` yalnız
/// `initializeDateFormatting` çağrılmış dillerde çalışır ve uygulama onu hiç
/// çağırmıyor — testte de sahte dil verilebilsin diye anahtarlar çeviri
/// sistemine bağlandı.
const List<String> karsilamaAylar = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

/// [ay] ayının [yil] yılındaki gün sayısı. Yıl bilinmiyorsa ARTIK YIL
/// varsayılır ki 29 Şubat doğumlular listede 29'u bulabilsin.
int karsilamaAyGunSayisi(int ay, int? yil) {
  final artik = yil == null
      ? true
      : (yil % 4 == 0 && yil % 100 != 0) || yil % 400 == 0;
  return [31, artik ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][ay - 1];
}

class _KarsilamaEkraniState extends State<KarsilamaEkrani> {
  int _adim = 0;
  bool _kaydediyor = false;

  // --- 1. adım: doğum tarihi ---
  int? _gun;
  int? _ay;
  int? _yil;
  bool _yilGizli = false;

  // --- 3./4. adım seçimleri (tmdb id) ---
  final Set<int> _filmler = {};
  final Set<int> _diziler = {};

  /// Seri filmlerden ANINDA işaretlenenler — alt çubuktaki sayaca girer ama
  /// tekrar gönderilmez.
  final Set<int> _isaretliSeriFilmleri = {};

  @override
  void initState() {
    super.initState();
    _bittiMi();
  }

  /// Akış zaten tamamlandıysa (başka cihazda/oturumda) hiç göstermeden geç.
  /// Ağ yoksa akış normal çalışır — kullanıcı ekransız kalmaz.
  Future<void> _bittiMi() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(karsilamaBittiAnahtari) == true) {
        _cik(kaydet: false);
        return;
      }
      final d = await Api.get('/karsilama') as Map<String, dynamic>;
      if (d['bitti'] == true) {
        _cik(kaydet: false);
        return;
      }
      final gun = (d['dogum_gun'] as num?)?.toInt();
      final ay = (d['dogum_ay'] as num?)?.toInt();
      final yil = (d['dogum_yil'] as num?)?.toInt();
      if (mounted && gun != null && ay != null) {
        setState(() {
          _gun = gun;
          _ay = ay;
          _yil = yil;
          _yilGizli = yil == null;
        });
      }
    } catch (_) {
      // Çevrimdışı/oturum hatası: akış olağan biçimde açılır.
    }
  }

  Future<void> _dogumKaydet() async {
    if (_gun == null || _ay == null) return;
    try {
      await Api.post('/karsilama', {
        'dogum_gun': _gun,
        'dogum_ay': _ay,
        'dogum_yil': _yilGizli ? null : _yil,
      });
    } catch (e) {
      if (mounted) _uyar(e.toString());
    }
  }

  /// Seçilenleri TEK istekte "bitirdim" yapar. 50'lik öbek: sunucu tavanı 100,
  /// dizilerde her kayıt bir TMDB çağrısı demek.
  Future<void> _durumKaydet(String tur, Set<int> idler) async {
    final liste = idler.toList();
    for (var i = 0; i < liste.length; i += 50) {
      final obek = liste.sublist(i, (i + 50).clamp(0, liste.length));
      await Api.post('/karsilama/toplu-durum', {
        'ogeler': [
          for (final id in obek)
            {'tur': tur, 'tmdb_id': id, 'durum': 'bitirdim'},
        ],
      });
    }
  }

  void _uyar(String mesaj) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(mesaj)));

  /// Sıradaki adıma geçer; [kaydet] false ise adımın verisi gönderilmez
  /// ("Şimdilik geç").
  Future<void> _ilerle({bool kaydet = true}) async {
    if (_kaydediyor) return;
    if (_adim >= karsilamaAdimSayisi - 1) {
      await _cik();
      return;
    }
    setState(() => _kaydediyor = true);
    try {
      if (kaydet) {
        if (_adim == 0) await _dogumKaydet();
        if (_adim == 2 && _filmler.isNotEmpty) {
          await _durumKaydet('movie', _filmler);
        }
        if (_adim == 3 && _diziler.isNotEmpty) {
          await _durumKaydet('tv', _diziler);
        }
      }
    } catch (e) {
      // Sessiz başarısızlık yok: kaydedilemedi ama akış tıkanmaz.
      if (mounted) _uyar(e.toString());
    }
    if (!mounted) return;
    setState(() {
      _kaydediyor = false;
      _adim += 1;
    });
  }

  void _geri() {
    if (_adim == 0 || _kaydediyor) return;
    setState(() => _adim -= 1);
  }

  /// Akıştan çıkar. [kaydet] true ise "bitti" bayrağı yazılır — akış bir daha
  /// AÇILMAZ (yarıda bırakılsa bile).
  Future<void> _cik({bool kaydet = true}) async {
    if (kaydet) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(karsilamaBittiAnahtari, true);
      } catch (_) {
        // yerel kopya yazılamadı: sunucudaki bayrak yeter
      }
      // Ateşle ve unut: kullanıcı bayrağın yazılmasını BEKLEMEZ.
      Api.post('/karsilama', {
        'bitti': true,
      }).catchError((_) => <String, dynamic>{});
    }
    Oturum.karsilamaGerekli = false;
    if (mounted) context.go('/kesfet');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ustCubuk(),
            Expanded(child: _icerik()),
            _altCubuk(),
          ],
        ),
      ),
    );
  }

  Widget _ustCubuk() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          // Dokunma hedefi 48 dp: ikonun kendisi değil, IconButton büyütülür.
          SizedBox(
            width: 48,
            height: 48,
            child: _adim == 0
                ? null
                : IconButton(
                    onPressed: _kaydediyor ? null : _geri,
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Geri'.c,
                  ),
          ),
          Expanded(child: _adimGostergesi()),
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              onPressed: _kaydediyor ? null : () => _cik(),
              icon: const Icon(Icons.close),
              tooltip: 'Karşılamayı kapat'.c,
            ),
          ),
        ],
      ),
    );
  }

  Widget _adimGostergesi() {
    return Semantics(
      label: 'Adım {} / {}'.cf([_adim + 1, karsilamaAdimSayisi]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (var i = 0; i < karsilamaAdimSayisi; i++)
                Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i <= _adim
                          ? DiziRenkler.sari
                          : DiziRenkler.metin12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Adım {} / {}'.cf([_adim + 1, karsilamaAdimSayisi]),
            style: TextStyle(fontSize: 11, color: DiziRenkler.metin54),
          ),
        ],
      ),
    );
  }

  Widget _icerik() {
    switch (_adim) {
      case 0:
        return _DogumAdimi(
          gun: _gun,
          ay: _ay,
          yil: _yil,
          yilGizli: _yilGizli,
          onDegisti: (gun, ay, yil, yilGizli) => setState(() {
            _gun = gun;
            _ay = ay;
            _yil = yil;
            _yilGizli = yilGizli;
          }),
        );
      case 1:
        return const _AktarmaAdimi();
      case 2:
        return _FilmAdimi(
          secili: _filmler,
          isaretliSeriFilmleri: _isaretliSeriFilmleri,
          onDegisti: () => setState(() {}),
        );
      case 3:
        return _DiziAdimi(secili: _diziler, onDegisti: () => setState(() {}));
      default:
        return const _TanitimAdimi();
    }
  }

  /// Birincil düğmenin metni adıma göre değişir; seçim varsa sayıyı gösterir.
  String _ilerleMetni() {
    if (_adim == karsilamaAdimSayisi - 1) return 'Hadi başlayalım'.c;
    if (_adim == 0 && _gun != null && _ay != null) return 'Kaydet ve devam'.c;
    final sayi = _adim == 2
        ? _filmler.length + _isaretliSeriFilmleri.length
        : _adim == 3
        ? _diziler.length
        : 0;
    if (sayi > 0) return '{} tanesini ekle'.cf([sayi]);
    return 'Devam et'.c;
  }

  Widget _altCubuk() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          TextButton(
            onPressed: _kaydediyor
                ? null
                : () => _adim >= karsilamaAdimSayisi - 1
                      ? _cik()
                      : _ilerle(kaydet: false),
            style: TextButton.styleFrom(
              minimumSize: const Size(64, 48),
              foregroundColor: DiziRenkler.metin70,
            ),
            child: Text('Şimdilik geç'.c),
          ),
          const Spacer(),
          FilledButton(
            onPressed: _kaydediyor ? null : () => _ilerle(),
            style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
            child: _kaydediyor
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : Text(
                    _ilerleMetni(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Adım başlığı: büyük başlık + açıklama. Beş adımda da aynı ritim.
class _AdimBasligi extends StatelessWidget {
  final String baslik;
  final String aciklama;
  const _AdimBasligi(this.baslik, this.aciklama);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            baslik,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            aciklama,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: DiziRenkler.metin70,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. ADIM — DOĞUM TARİHİ
// ---------------------------------------------------------------------------

class _DogumAdimi extends StatelessWidget {
  final int? gun;
  final int? ay;
  final int? yil;
  final bool yilGizli;
  final void Function(int? gun, int? ay, int? yil, bool yilGizli) onDegisti;

  const _DogumAdimi({
    required this.gun,
    required this.ay,
    required this.yil,
    required this.yilGizli,
    required this.onDegisti,
  });

  @override
  Widget build(BuildContext context) {
    final buYil = DateTime.now().year;
    final gunSayisi = ay == null
        ? 31
        : karsilamaAyGunSayisi(ay!, yilGizli ? null : yil);
    // Ay değişince 31 Şubat gibi imkânsız gün seçili kalmasın.
    final gecerliGun = (gun != null && gun! <= gunSayisi) ? gun : null;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _AdimBasligi(
          'Doğum tarihin ne zaman?'.c,
          'Yaşına uygun içerik göstermek ve doğum gününü kutlamak için soruyoruz.'
              .c,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _Secici<int>(
                  key: const Key('karsilama_gun'),
                  etiket: 'Gün'.c,
                  deger: gecerliGun,
                  ogeler: [
                    for (var g = 1; g <= gunSayisi; g++)
                      DropdownMenuItem(value: g, child: Text('$g')),
                  ],
                  onDegisti: (v) => onDegisti(v, ay, yil, yilGizli),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: _Secici<int>(
                  key: const Key('karsilama_ay'),
                  etiket: 'Ay'.c,
                  deger: ay,
                  ogeler: [
                    for (var a = 1; a <= 12; a++)
                      DropdownMenuItem(
                        value: a,
                        child: Text(
                          karsilamaAylar[a - 1].c,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onDegisti: (v) {
                    final yeniGun =
                        (gecerliGun != null &&
                            v != null &&
                            gecerliGun >
                                karsilamaAyGunSayisi(v, yilGizli ? null : yil))
                        ? null
                        : gecerliGun;
                    onDegisti(yeniGun, v, yil, yilGizli);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: yilGizli
                    ? const SizedBox.shrink()
                    : _Secici<int>(
                        key: const Key('karsilama_yil'),
                        etiket: 'Yıl'.c,
                        deger: yil,
                        ogeler: [
                          for (var y = buYil; y >= 1900; y--)
                            DropdownMenuItem(value: y, child: Text('$y')),
                        ],
                        onDegisti: (v) =>
                            onDegisti(gecerliGun, ay, v, yilGizli),
                      ),
              ),
            ],
          ),
        ),
        // Yıl İSTEĞE BAĞLI: doğum günü kutlaması gün+ay ile çalışır, yıl yalnız
        // yaş doğrulaması için gerekir. İstemeyen vermez.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: CheckboxListTile(
            value: yilGizli,
            onChanged: (v) =>
                onDegisti(gun, ay, v == true ? null : yil, v == true),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            title: Text(
              'Doğum yılımı paylaşmak istemiyorum'.c,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, size: 18, color: DiziRenkler.metin54),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Doğum tarihin profilinde herkese açık gösterilmez. Yalnız yaşa uygun içerik ve doğum günü kutlaması için kullanılır.'
                      .c,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: DiziRenkler.metin54,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Etiketli açılır seçici — üç tarih alanında da aynı yükseklik ve dolgu.
class _Secici<T> extends StatelessWidget {
  final String etiket;
  final T? deger;
  final List<DropdownMenuItem<T>> ogeler;
  final ValueChanged<T?> onDegisti;

  const _Secici({
    super.key,
    required this.etiket,
    required this.deger,
    required this.ogeler,
    required this.onDegisti,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: deger,
      isExpanded: true,
      items: ogeler,
      onChanged: onDegisti,
      decoration: InputDecoration(
        labelText: etiket,
        filled: true,
        fillColor: DiziRenkler.kart,
        // 14 dp dikey dolgu + metin ≈ 52 dp dokunma hedefi.
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. ADIM — DIŞARIDAN VERİ AKTARMA
// ---------------------------------------------------------------------------

class _AktarmaAdimi extends StatefulWidget {
  const _AktarmaAdimi();

  @override
  State<_AktarmaAdimi> createState() => _AktarmaAdimiState();
}

class _AktarmaAdimiState extends State<_AktarmaAdimi> {
  bool _calisiyor = false;

  /// MEVCUT içe aktarımı çağırır (`Api.veriIceAktar` → `backend/veri_aktar.js`).
  /// Yeni bir akış yazılmadı; Ayarlar > Verilerim ile AYNI uca gidiyor.
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
    setState(() => _calisiyor = true);
    try {
      final ozet = await Api.veriIceAktar(veri);
      if (!mounted) return;
      int say(String k) => (ozet[k] as num?)?.toInt() ?? 0;
      final satirlar = [
        if (say('durum') > 0) '• {} kitaplık kaydı'.cf([say('durum')]),
        if (say('izleme') > 0) '• {} izleme kaydı'.cf([say('izleme')]),
        if (say('puan') > 0) '• {} puan'.cf([say('puan')]),
        if (say('yorum') > 0) '• {} yorum'.cf([say('yorum')]),
        if (say('liste') > 0) '• {} liste'.cf([say('liste')]),
        if (say('favori') > 0) '• {} favori'.cf([say('favori')]),
      ];
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: DiziRenkler.koyuGri,
          title: Text('İçe aktarım tamamlandı'.c),
          content: Text(
            satirlar.isEmpty
                ? 'Aktarılacak tanınan veri bulunamadı.'.c
                : satirlar.join('\n'),
          ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _calisiyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _AdimBasligi(
          'Verilerini yanında getir'.c,
          'Başka bir uygulamada izlediklerini takip ediyorsan buraya taşıyabilirsin. Sıfırdan başlamana gerek yok.'
              .c,
        ),
        const _BilgiKarti(
          ikon: Icons.file_upload_outlined,
          // Marka adları çevrilmez; harita karşılığı yoksa anahtar aynen
          // basılır — tüm dillerde doğru görünür.
          baslik: 'TV Time / Letterboxd',
          metin:
              'Dışa aktardığın ZIP dosyasını seç; izlediklerin, puanların ve listelerin aktarılsın.',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: FilledButton.tonalIcon(
            onPressed: _calisiyor ? null : _iceAktar,
            icon: _calisiyor
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.folder_zip_outlined),
            label: Text(_calisiyor ? 'Aktarılıyor...'.c : 'ZIP dosyası seç'.c),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Text(
            'Aceleye gerek yok: bunu sonra Ayarlar > Verilerim bölümünden de yapabilirsin.'
                .c,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: DiziRenkler.metin54,
            ),
          ),
        ),
      ],
    );
  }
}

/// İkon + başlık + metin taşıyan bilgi kartı (2. ve 5. adım).
class _BilgiKarti extends StatelessWidget {
  final IconData ikon;
  final String baslik;
  final String metin;
  const _BilgiKarti({
    required this.ikon,
    required this.baslik,
    required this.metin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DiziRenkler.kart,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, color: DiziRenkler.sariMetin, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baslik.c,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  metin.c,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: DiziRenkler.metin70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ortak seçim ızgarası (3. ve 4. adım)
// ---------------------------------------------------------------------------

/// Seçilebilir poster karosu. Ad posterin altına DEĞİL üstüne yazılır: hücre
/// birebir 2:3 kalsın (poster kırpılmasın) ama tanımadığı yapımı kullanıcı
/// yine de okuyabilsin.
class _SecimKarosu extends StatelessWidget {
  final String ad;
  final String? posterYolu;
  final bool secili;
  final VoidCallback onDokun;

  const _SecimKarosu({
    required this.ad,
    required this.posterYolu,
    required this.secili,
    required this.onDokun,
  });

  @override
  Widget build(BuildContext context) {
    final poster = posterUrl(posterYolu, boyut: 'w342');
    return Semantics(
      label: ad,
      button: true,
      selected: secili,
      child: GestureDetector(
        onTap: onDokun,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: poster == null
                  ? Container(color: DiziRenkler.kart)
                  : CachedNetworkImage(
                      imageUrl: poster,
                      httpHeaders: gorselBasliklari(poster),
                      fit: BoxFit.cover,
                    ),
            ),
            // Ad şeridi: siyah degrade üstüne BEYAZ yazı — poster ne olursa
            // olsun kontrast korunur (metin rengi temadan gelmez).
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                  child: Text(
                    ad,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            if (secili)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DiziRenkler.sari, width: 3),
                  color: Colors.black38,
                ),
                alignment: Alignment.topRight,
                padding: const EdgeInsets.all(6),
                child: const CircleAvatar(
                  radius: 13,
                  backgroundColor: DiziRenkler.sari,
                  child: Icon(Icons.check, size: 18, color: Colors.black),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// TMDB listesinden seçim ızgarası (sliver).
SliverGrid _secimIzgarasi({
  required List<Map<String, dynamic>> ogeler,
  required Set<int> secili,
  required void Function(Map<String, dynamic>) onDokun,
}) {
  return SliverGrid(
    gridDelegate: const PosterIzgarasi(
      bosluk: 10,
      satirBoslugu: 10,
      baslikYuksekligi: 0,
    ),
    delegate: SliverChildBuilderDelegate((context, i) {
      final ic = ogeler[i];
      final id = (ic['id'] as num?)?.toInt() ?? 0;
      return _SecimKarosu(
        ad: (ic['name'] ?? ic['title'] ?? '') as String,
        posterYolu: ic['poster_path'] as String?,
        secili: secili.contains(id),
        onDokun: () => onDokun(ic),
      );
    }, childCount: ogeler.length),
  );
}

/// Posteri olmayan ve tekrar eden kayıtları atarak iki TMDB listesini harmanlar
/// (trend + en çok oylanan → hem güncel hem klasik yapımlar bir arada).
List<Map<String, dynamic>> _harmanla(
  List<dynamic> a,
  List<dynamic> b, {
  int tavan = 60,
}) {
  final cikti = <Map<String, dynamic>>[];
  final gorulen = <int>{};
  final aL = a.whereType<Map<String, dynamic>>().toList();
  final bL = b.whereType<Map<String, dynamic>>().toList();
  for (var i = 0; i < aL.length + bL.length && cikti.length < tavan; i++) {
    for (final liste in [aL, bL]) {
      if (i >= liste.length) continue;
      final e = liste[i];
      final id = (e['id'] as num?)?.toInt();
      if (id == null || e['poster_path'] == null || !gorulen.add(id)) continue;
      cikti.add(e);
      if (cikti.length >= tavan) break;
    }
  }
  return cikti;
}

// ---------------------------------------------------------------------------
// 3. ADIM — İZLENEN FİLMLER (+ SERİ FİLMLER)
// ---------------------------------------------------------------------------

class _FilmAdimi extends StatefulWidget {
  final Set<int> secili;
  final Set<int> isaretliSeriFilmleri;
  final VoidCallback onDegisti;

  const _FilmAdimi({
    required this.secili,
    required this.isaretliSeriFilmleri,
    required this.onDegisti,
  });

  @override
  State<_FilmAdimi> createState() => _FilmAdimiState();
}

class _FilmAdimiState extends State<_FilmAdimi> {
  List<Map<String, dynamic>> _filmler = [];
  bool _yukleniyor = true;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      // "En çok izlenenler": haftalık trend + TÜM ZAMANLARIN en çok oylananı.
      // `vote_count` izlenme sayısının en iyi kamuya açık vekilidir.
      final s = await Future.wait([
        Api.get('/tmdb/trending/movie/week'),
        Api.get('/tmdb/discover/movie?sort_by=vote_count.desc'),
      ]);
      final liste = _harmanla(
        (s[0]['results'] as List<dynamic>?) ?? const [],
        (s[1]['results'] as List<dynamic>?) ?? const [],
      );
      if (!mounted) return;
      setState(() {
        _filmler = liste;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _hata = e.toString();
      });
    }
  }

  Future<void> _serileriAc() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DiziRenkler.koyuGri,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _SeriSheet(isaretli: widget.isaretliSeriFilmleri),
    );
    if (mounted) widget.onDegisti();
  }

  @override
  Widget build(BuildContext context) {
    if (_hata != null) return HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _AdimBasligi(
            'Hangi filmleri izledin?'.c,
            'En çok izlenenler burada. Dokunduklarını izlediklerine ekleyelim.'
                .c,
          ),
        ),
        // "SERİ FİLMLER" görünür bir yerde: ızgaranın ÜSTÜNDE, tam genişlikte.
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: OutlinedButton.icon(
              onPressed: _serileriAc,
              icon: const Icon(Icons.collections_bookmark_outlined),
              label: Text('SERİ FİLMLER'.c),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: DiziRenkler.sariMetin,
                side: BorderSide(color: DiziRenkler.sariMetin, width: 1.5),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
        if (widget.isaretliSeriFilmleri.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color: DiziRenkler.sariMetin,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Serilerden {} film eklendi'.cf([
                        widget.isaretliSeriFilmleri.length,
                      ]),
                      style: TextStyle(
                        fontSize: 13,
                        color: DiziRenkler.metin70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_yukleniyor)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (_filmler.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 32),
              child: BosDurum(
                ikon: Icons.movie_outlined,
                baslik: 'Film listesi yüklenemedi'.c,
                ipucu:
                    'Bu adımı geçebilirsin, sonra istediğini ekleyebilirsin.'.c,
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: _secimIzgarasi(
              ogeler: _filmler,
              secili: widget.secili,
              onDokun: (ic) {
                final id = (ic['id'] as num?)?.toInt();
                if (id == null) return;
                setState(() {
                  if (!widget.secili.remove(id)) widget.secili.add(id);
                });
                widget.onDegisti();
              },
            ),
          ),
      ],
    );
  }
}

/// Film serileri sayfası: `GET /karsilama/seriler` (TMDB koleksiyonları).
class _SeriSheet extends StatefulWidget {
  final Set<int> isaretli;
  const _SeriSheet({required this.isaretli});

  @override
  State<_SeriSheet> createState() => _SeriSheetState();
}

class _SeriSheetState extends State<_SeriSheet> {
  List<Map<String, dynamic>> _seriler = [];
  bool _yukleniyor = true;
  String? _hata;
  final Set<int> _biten = {}; // koleksiyon id

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      // `dil` ADRESE ELLE konur: `Api._dilliYol` yalnız `/tmdb/` yollarına
      // ekliyor, bu uç ise Cloudflare kenarında önbellekleniyor ve kenarın
      // önbellek anahtarı YALNIZ URL'dir — dil adreste olmasaydı bir dilin
      // yanıtı başka dildeki kullanıcıya servis edilirdi.
      final d =
          await Api.get('/karsilama/seriler?dil=${Ceviri.dil.value}')
              as Map<String, dynamic>;
      final liste = ((d['seriler'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      if (!mounted) return;
      setState(() {
        _seriler = liste;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _hata = e.toString();
      });
    }
  }

  /// "Tümünü izledim": serinin TAMAMI tek istekte "bitirdim" olur.
  Future<void> _tumunuIsaretle(Map<String, dynamic> seri) async {
    final filmler = ((seri['filmler'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((f) => (f['id'] as num?)?.toInt())
        .whereType<int>()
        .toList();
    if (filmler.isEmpty) return;
    final seriId = (seri['id'] as num?)?.toInt() ?? 0;
    setState(() => _biten.add(-seriId)); // negatif = "işleniyor"
    try {
      await Api.post('/karsilama/toplu-durum', {
        'ogeler': [
          for (final id in filmler)
            {'tur': 'movie', 'tmdb_id': id, 'durum': 'bitirdim'},
        ],
      });
      widget.isaretli.addAll(filmler);
      if (!mounted) return;
      setState(() {
        _biten
          ..remove(-seriId)
          ..add(seriId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('{} film izlediklerine eklendi'.cf([filmler.length])),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _biten.remove(-seriId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final yukseklik = MediaQuery.sizeOf(context).height * 0.85;
    return SizedBox(
      height: yukseklik,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Film serileri'.c,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bir seriyi baştan sona izlediysen tek dokunuşla ekle.'
                            .c,
                        style: TextStyle(
                          fontSize: 12,
                          color: DiziRenkler.metin54,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'Kapat'.c,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _hata != null
                ? HataGorunumu(mesaj: _hata!, tekrar: _yukle)
                : _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : _seriler.isEmpty
                ? BosDurum(
                    ikon: Icons.collections_bookmark_outlined,
                    baslik: 'Seri bulunamadı'.c,
                    ipucu: 'Daha sonra tekrar deneyebilirsin.'.c,
                  )
                : ListView.builder(
                    // AÇIK `padding` verilen kaydırma listesine Flutter alt
                    // güvenli alanı KENDİLİĞİNDEN EKLEMEZ; son seri kartının
                    // düğmesi sistem gezinme çubuğunun altında kalırdı
                    // (bkz. test/modal_alt_guvenli_test.dart).
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      altGuvenli(context, ekstra: 24),
                    ),
                    itemCount: _seriler.length,
                    itemBuilder: (context, i) {
                      final s = _seriler[i];
                      final id = (s['id'] as num?)?.toInt() ?? 0;
                      return _SeriKarti(
                        seri: s,
                        bitti: _biten.contains(id),
                        isleniyor: _biten.contains(-id),
                        onTumunuIsaretle: () => _tumunuIsaretle(s),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SeriKarti extends StatefulWidget {
  final Map<String, dynamic> seri;
  final bool bitti;
  final bool isleniyor;
  final VoidCallback onTumunuIsaretle;

  const _SeriKarti({
    required this.seri,
    required this.bitti,
    required this.isleniyor,
    required this.onTumunuIsaretle,
  });

  @override
  State<_SeriKarti> createState() => _SeriKartiState();
}

class _SeriKartiState extends State<_SeriKarti> {
  bool _acik = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.seri;
    final filmler = ((s['filmler'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final poster = posterUrl(s['poster'] as String?, boyut: 'w342');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: DiziRenkler.kart,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _acik = !_acik),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 46,
                      height: 69,
                      child: poster == null
                          ? Container(color: DiziRenkler.koyuGri)
                          : CachedNetworkImage(
                              imageUrl: poster,
                              httpHeaders: gorselBasliklari(poster),
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (s['ad'] as String?) ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '{} film'.cf([filmler.length]),
                          style: TextStyle(
                            fontSize: 12,
                            color: DiziRenkler.metin54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _acik ? Icons.expand_less : Icons.expand_more,
                    color: DiziRenkler.metin54,
                  ),
                ],
              ),
            ),
          ),
          if (_acik)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final f in filmler)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        f['yil'] == null
                            ? '• ${f['ad']}'
                            : '• ${f['ad']} (${f['yil']})',
                        style: TextStyle(
                          fontSize: 13,
                          color: DiziRenkler.metin70,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: SizedBox(
              width: double.infinity,
              child: widget.bitti
                  ? FilledButton.tonalIcon(
                      onPressed: null,
                      icon: const Icon(Icons.check, size: 18),
                      label: Text('Eklendi'.c),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                    )
                  : FilledButton.tonalIcon(
                      onPressed: widget.isleniyor
                          ? null
                          : widget.onTumunuIsaretle,
                      icon: widget.isleniyor
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.done_all, size: 18),
                      label: Text('Tümünü izledim'.c),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. ADIM — İZLENEN DİZİLER (kümelenmiş öneri)
// ---------------------------------------------------------------------------

class _DiziAdimi extends StatefulWidget {
  final Set<int> secili;
  final VoidCallback onDegisti;

  const _DiziAdimi({required this.secili, required this.onDegisti});

  @override
  State<_DiziAdimi> createState() => _DiziAdimiState();
}

class _DiziAdimiState extends State<_DiziAdimi> {
  /// Kaç seçim için öneri çekilir. ÜST SINIR ŞART: her seçim bir TMDB isteği
  /// demek ve bu ekran uygulamanın İLK AÇILIŞINDA çalışıyor.
  static const _oneriTavani = 6;

  List<Map<String, dynamic>> _diziler = [];
  final List<Map<String, dynamic>> _benzerler = [];
  final Set<int> _oneriCekilen = {};
  bool _yukleniyor = true;
  bool _oneriYukleniyor = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      // Bilinen diziler: haftalık trend (Pluribus, House of the Dragon...) +
      // tüm zamanların en çok oylananı (Breaking Bad, Better Call Saul, GoT...).
      final s = await Future.wait([
        Api.get('/tmdb/trending/tv/week'),
        Api.get('/tmdb/discover/tv?sort_by=vote_count.desc'),
      ]);
      final liste = _harmanla(
        (s[0]['results'] as List<dynamic>?) ?? const [],
        (s[1]['results'] as List<dynamic>?) ?? const [],
      );
      if (!mounted) return;
      setState(() {
        _diziler = liste;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _hata = e.toString();
      });
    }
  }

  /// KÜMELENMİŞ ÖNERİ (düz popülerlik listesi DEĞİL): kullanıcı bir dizi
  /// seçtikçe TMDB'nin o diziye özel `recommendations` listesi ayrı bir
  /// bölümde toplanır. Böylece "Breaking Bad" seçen kullanıcıya "Better Call
  /// Saul / Ozark / Narcos" çıkar, herkese aynı ilk 20 dizi değil.
  ///
  /// MALİYET: seçim başına TEK istek, en çok [_oneriTavani] kez (yani en fazla
  /// 6 istek/oturum). Yanıt sunucuda 6 saat, Cloudflare kenarında 6 saat
  /// önbellekli ve kişiye özel alan taşımıyor → ikinci kullanıcıya bedava.
  Future<void> _oneriTopla(int diziId) async {
    if (_oneriCekilen.length >= _oneriTavani) return;
    if (!_oneriCekilen.add(diziId)) return;
    setState(() => _oneriYukleniyor = true);
    try {
      final d = await Api.get('/tmdb/tv/$diziId/recommendations');
      final gelen = ((d['results'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .where((e) => e['poster_path'] != null)
          .take(8);
      final varolan = {
        ..._diziler.map((e) => (e['id'] as num?)?.toInt()),
        ..._benzerler.map((e) => (e['id'] as num?)?.toInt()),
      };
      final yeni = gelen
          .where((e) => !varolan.contains((e['id'] as num?)?.toInt()))
          .toList();
      if (!mounted) return;
      setState(() {
        _benzerler.addAll(yeni);
        _oneriYukleniyor = false;
      });
    } catch (_) {
      // Öneri ikincil: gelmezse ana ızgara zaten dolu, kullanıcıyı rahatsız etme.
      if (mounted) setState(() => _oneriYukleniyor = false);
    }
  }

  void _sec(Map<String, dynamic> ic) {
    final id = (ic['id'] as num?)?.toInt();
    if (id == null) return;
    final eklendi = !widget.secili.remove(id);
    setState(() {
      if (eklendi) widget.secili.add(id);
    });
    widget.onDegisti();
    if (eklendi) _oneriTopla(id);
  }

  @override
  Widget build(BuildContext context) {
    if (_hata != null) return HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _AdimBasligi(
            'Peki ya diziler?'.c,
            'İzlediklerini işaretle; seçtikçe sana benzeyenleri getireceğiz.'.c,
          ),
        ),
        if (_yukleniyor)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (_diziler.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 32),
              child: BosDurum(
                ikon: Icons.live_tv_outlined,
                baslik: 'Dizi listesi yüklenemedi'.c,
                ipucu:
                    'Bu adımı geçebilirsin, sonra istediğini ekleyebilirsin.'.c,
              ),
            ),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: _secimIzgarasi(
              ogeler: _diziler,
              secili: widget.secili,
              onDokun: _sec,
            ),
          ),
          if (_benzerler.isNotEmpty || _oneriYukleniyor)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 18,
                      color: DiziRenkler.sariMetin,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Seçtiklerine benzeyenler'.c,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (_oneriYukleniyor)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
            ),
          if (_benzerler.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: _secimIzgarasi(
                ogeler: _benzerler,
                secili: widget.secili,
                onDokun: _sec,
              ),
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 5. ADIM — UYGULAMA TANITIMI
// ---------------------------------------------------------------------------

class _TanitimAdimi extends StatelessWidget {
  const _TanitimAdimi();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _AdimBasligi(
          'Her şey hazır'.c,
          'dizi.jpg\'de neler yapabileceğine hızlıca göz at.'.c,
        ),
        const _BilgiKarti(
          ikon: Icons.person_outline,
          baslik: 'Profilini tamamla',
          metin:
              'Ayarlar\'dan bir bio, profil fotoğrafı ve kapak ekleyebilirsin.',
        ),
        const _BilgiKarti(
          ikon: Icons.calendar_month_outlined,
          baslik: 'Takvimin seni bekliyor',
          metin:
              'İzlediğin dizilerin yeni bölümleri takvime düşer, bildirimle haber veririz.',
        ),
        const _BilgiKarti(
          ikon: Icons.star_outline,
          baslik: 'Puan ver, yorum yaz',
          metin:
              'Bölüm bölüm puanla, spoiler perdesiyle yorum yaz, listeler oluştur.',
        ),
        const _BilgiKarti(
          ikon: Icons.shield_outlined,
          baslik: 'Verilerin sende kalır',
          metin:
              'Verilerin yalnız hesabına bağlı tutulur, satılmaz. Ayarlar\'dan hepsini indirebilir ya da hesabını tamamen silebilirsin.',
        ),
      ],
    );
  }
}
