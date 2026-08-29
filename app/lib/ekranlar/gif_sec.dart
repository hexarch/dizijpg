import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../api.dart';
import '../ceviri.dart';
import '../medya_yukle.dart';
import '../tema.dart';
import 'giris_istem.dart';
import 'ortak.dart';

/// KENDİ GIF ARŞİVİMİZİN ORTAK SEÇİCİSİ — arama + ızgara + sonsuz kaydırma +
/// "GIF yükle".
///
/// ---------------------------------------------------------------------------
/// NEDEN DIŞ SERVİS YOK (29 Ağu 2026, üçü de doğrulandı)
/// ---------------------------------------------------------------------------
///   · Tenor 13 Ocak 2026'da yeni anahtarı kapattı, 30 Haziran 2026'da mevcut
///     entegrasyonları da durdurdu — ÖLÜ.
///   · Giphy beta anahtarı 100 istek/saat; üstü Enterprise (ücretli).
///   · Klipy'nin üretim şartları PROXY ve ÖNBELLEĞİ yasaklıyor.
/// Kullanıcı kararı: "tamamen ücretsiz ve saat sınırı olmayan bir şey yoksa
/// hiç kurmayalım" → arşiv bizim, kullanıcı yüklemesiyle büyüyor.
///
/// ---------------------------------------------------------------------------
/// MODERASYON — KULLANICININ SERT ŞARTI: "+18 KESİNLİKLE OLMAYACAK"
/// ---------------------------------------------------------------------------
/// Yüklenen GIF `bekliyor` durumunda kaydedilir:
///   · yükleyen onu HEMEN kendi seçicisinde görür ve kullanır,
///   · BAŞKA hiçbir kullanıcı göremez (sunucu tarafı: `backend/gif.js`
///     `gifSuzgec` — kilit `backend/test/gif_gorunurluk.test.js`),
///   · herkese açık arşive yalnız panelden onayla girer,
///   · reddedilen hem arşivden hem yükleyenin seçicisinden DÜŞER.
/// Bekleyen kayıtlar ızgarada "Onay bekliyor" rozetiyle işaretlenir ki kullanıcı
/// gönderdiği GIF'i başkasının görmediğini BİLSİN.
///
/// ---------------------------------------------------------------------------
/// DOSYADAN SEÇME YOLU KALDI
/// ---------------------------------------------------------------------------
/// "GIF yükle" düğmesi eski `FilePicker` yolunu kullanır; arşiv o yoldan
/// beslenir. Yani kullanıcı hiçbir zaman "arşivde yok" diye kilitlenmez.
class GifSecSheet extends StatefulWidget {
  const GifSecSheet({super.key});

  @override
  State<GifSecSheet> createState() => _GifSecSheetState();
}

/// Bir sayfada kaç GIF gelir (sunucudaki `SAYFA_BOYU` ile aynı).
const int gifSayfaBoyu = 30;

class _GifSecSheetState extends State<GifSecSheet> {
  final _arama = TextEditingController();
  final _kaydirici = ScrollController();
  Timer? _geciktirici;

  final List<Map<String, dynamic>> _gifler = [];
  String _sorgu = '';
  bool _benimkiler = false;
  int _sayfa = 0;
  bool _yukleniyor = false;
  bool _devamVar = true;
  bool _yukleniyorEk = false; // "GIF yükle" akışı
  String? _hata;

  @override
  void initState() {
    super.initState();
    _kaydirici.addListener(_kaydirildi);
    _sonrakiSayfa();
  }

  @override
  void dispose() {
    _arama.dispose();
    _kaydirici.dispose();
    _geciktirici?.cancel();
    super.dispose();
  }

  void _kaydirildi() {
    if (_kaydirici.position.pixels >
        _kaydirici.position.maxScrollExtent - 400) {
      _sonrakiSayfa();
    }
  }

  void _degisti(String q) {
    _geciktirici?.cancel();
    _geciktirici = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _sifirla(q.trim());
    });
  }

  /// Sorgu ya da sekme değişti: listeyi baştan kur.
  void _sifirla(String sorgu) {
    setState(() {
      _sorgu = sorgu;
      _gifler.clear();
      _sayfa = 0;
      _devamVar = true;
      _hata = null;
    });
    _sonrakiSayfa();
  }

  Future<void> _sonrakiSayfa() async {
    if (_yukleniyor || !_devamVar) return;
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    final sayfa = _sayfa + 1;
    try {
      final yol = _benimkiler ? '/gif/benim' : '/gif';
      final q = _sorgu.isEmpty ? '' : '&q=${Uri.encodeQueryComponent(_sorgu)}';
      final cevap =
          await Api.get('$yol?sayfa=$sayfa$q') as Map<String, dynamic>;
      if (!mounted) return;
      final gelen = (cevap['gifler'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      setState(() {
        _gifler.addAll(gelen);
        _sayfa = sayfa;
        _devamVar = cevap['devam_var'] == true;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _hata = e is ApiHata ? e.mesaj : 'GIF listesi yüklenemedi'.c;
      });
    }
  }

  /// Kullanıcı bir GIF seçti: sayacı artır (ATEŞLE-UNUT — sayaç hatası seçimi
  /// bozmaz) ve yolu döndür.
  void _sec(Map<String, dynamic> g) {
    final id = g['id'];
    if (id is int) {
      Api.post(
        '/gif/$id/kullanildi',
        const {},
      ).catchError((_) => <String, dynamic>{});
    }
    Navigator.pop(context, g);
  }

  /// Dosyadan GIF seç → yükle → etiket sor → arşive kaydet.
  ///
  /// ÜÇ HAL: yükleniyor (düğme kilitli + spinner) · başarı (GIF listenin başına
  /// düşer + bilgilendirme) · hata (SnackBar). Sessiz başarısızlık YOK.
  Future<void> _gifYukle() async {
    if (!girisGerekli(context)) return;
    if (_yukleniyorEk) return;
    final secim = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gif'],
      withData: true,
    );
    final veri = secim?.files.single.bytes;
    if (veri == null || !mounted) return;

    final etiketler = await _etiketSor();
    if (etiketler == null || !mounted) return; // kullanıcı vazgeçti

    setState(() => _yukleniyorEk = true);
    try {
      final sonuc = await medyalariYukle([
        XFile.fromData(
          veri,
          mimeType: 'image/gif',
          name: secim!.files.single.name,
          length: veri.length,
        ),
      ], toplamAzamiBayt: null);
      if (!mounted) return;
      final bildirim = sonuc.bildirim;
      if (sonuc.yuklenen.isEmpty) {
        _uyar(bildirim ?? 'GIF yüklenemedi'.c);
        return;
      }
      final cevap =
          await Api.post('/gif', {
                'yol': sonuc.yuklenen.first['yol'],
                'etiketler': etiketler,
              })
              as Map<String, dynamic>;
      if (!mounted) return;
      final gif = cevap['gif'] as Map<String, dynamic>;
      setState(() => _gifler.insert(0, gif));
      _uyar(
        'GIF yüklendi. Sen hemen kullanabilirsin; herkese açık arşive '
                'onaydan sonra girer.'
            .c,
      );
    } catch (e) {
      if (!mounted) return;
      _uyar(e is ApiHata ? e.mesaj : 'GIF yüklenemedi'.c);
    } finally {
      if (mounted) setState(() => _yukleniyorEk = false);
    }
  }

  /// Etiket olmadan arşiv aranamaz; bu yüzden yükleme öncesi SORULUR.
  Future<List<String>?> _etiketSor() async {
    final kutu = TextEditingController();
    final sonuc = await showDialog<List<String>>(
      context: context,
      builder: (ic) => AlertDialog(
        backgroundColor: DiziRenkler.koyuGri,
        title: Text('GIF etiketleri'.c),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Virgülle ayır. Aramada bu kelimelerle bulunur.'.c,
              style: TextStyle(fontSize: 13, color: DiziRenkler.metin54),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: kutu,
              autofocus: true,
              maxLength: 120,
              decoration: InputDecoration(hintText: 'gülme, alkış, şaşkın'.c),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ic),
            child: Text('Vazgeç'.c),
          ),
          FilledButton(
            onPressed: () {
              final e = kutu.text
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.length >= 2)
                  .toList();
              if (e.isEmpty) return; // etiketsiz kayıt sunucuda 400 döner
              Navigator.pop(ic, e);
            },
            child: Text('Yükle'.c),
          ),
        ],
      ),
    );
    kutu.dispose();
    return sonuc;
  }

  /// Uygunsuz GIF şikayeti — YENİ altyapı yok, mevcut şikayet kuyruğu.
  Future<void> _sikayetEt(Map<String, dynamic> g) async {
    if (!girisGerekli(context)) return;
    final id = g['id'];
    if (id is! int) return;
    final onay = await showDialog<bool>(
      context: context,
      builder: (ic) => AlertDialog(
        backgroundColor: DiziRenkler.koyuGri,
        title: Text('Bu GIF i şikayet et'.c),
        content: Text(
          'Uygunsuz içerik yöneticiye bildirilir ve arşivden kaldırılabilir.'.c,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ic, false),
            child: Text('Vazgeç'.c),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ic, true),
            child: Text('Şikayet et'.c),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    try {
      await Api.sikayetEt('gif', id, 'Uygunsuz GIF');
      if (mounted) _uyar('Şikayetin alındı'.c);
    } catch (e) {
      if (mounted) _uyar(e is ApiHata ? e.mesaj : 'Şikayet gönderilemedi'.c);
    }
  }

  void _uyar(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _arama,
                    autofocus: false,
                    onChanged: _degisti,
                    decoration: InputDecoration(
                      hintText: 'GIF ara...'.c,
                      prefixIcon: Icon(Icons.search, color: DiziRenkler.metin),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Dokunma hedefi 44: ikonu değil, kutuyu büyütüyoruz.
                SizedBox(
                  width: dokunmaHedefi,
                  height: dokunmaHedefi,
                  child: IconButton(
                    tooltip: 'GIF yükle'.c,
                    onPressed: _yukleniyorEk ? null : _gifYukle,
                    icon: _yukleniyorEk
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.file_upload_outlined),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                _sekme('Arşiv'.c, !_benimkiler, () {
                  if (!_benimkiler) return;
                  setState(() => _benimkiler = false);
                  _sifirla(_sorgu);
                }),
                const SizedBox(width: 8),
                _sekme('Yüklediklerim'.c, _benimkiler, () {
                  if (_benimkiler) return;
                  if (!girisGerekli(context)) return;
                  setState(() => _benimkiler = true);
                  _sifirla(_sorgu);
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _govde()),
        ],
      ),
    );
  }

  Widget _sekme(String ad, bool secili, VoidCallback bas) => SizedBox(
    height: dokunmaHedefi,
    child: TextButton(
      onPressed: bas,
      style: TextButton.styleFrom(
        backgroundColor: secili
            ? DiziRenkler.sari.withValues(alpha: 0.15)
            : DiziRenkler.kart,
        foregroundColor: secili ? DiziRenkler.sari : DiziRenkler.metin54,
      ),
      child: Text(ad),
    ),
  );

  Widget _govde() {
    if (_gifler.isEmpty && _yukleniyor) {
      return const Center(
        child: CircularProgressIndicator(color: DiziRenkler.sari),
      );
    }
    if (_gifler.isEmpty && _hata != null) {
      return HataGorunumu(mesaj: _hata!, tekrar: _sonrakiSayfa);
    }
    if (_gifler.isEmpty) {
      // BOŞ DURUM EYLEME ÇAĞIRIR (ui-ux-pro-max "Empty States": helpful message
      // AND an action). Arşiv yeni; ilk kullanıcılar onu kendileri dolduracak.
      return BosDurum(
        ikon: Icons.gif_box_outlined,
        baslik: _sorgu.isEmpty
            ? 'Henüz GIF yok'.c
            : 'Bu aramaya uyan GIF yok'.c,
        ipucu:
            'Arşiv yeni. İlk GIF i sen yükle — sen hemen kullanırsın, '
                    'onaydan sonra herkes görür.'
                .c,
        aksiyon: FilledButton.icon(
          onPressed: _yukleniyorEk ? null : _gifYukle,
          icon: const Icon(Icons.file_upload_outlined),
          label: Text('GIF yükle'.c),
        ),
      );
    }
    return GridView.builder(
      controller: _kaydirici,
      padding: EdgeInsets.fromLTRB(12, 0, 12, altGuvenli(context, ekstra: 24)),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      // +1: kuyruk hücresi — spinner, hata + tekrar dene ya da hiçbir şey.
      itemCount: _gifler.length + 1,
      itemBuilder: (context, i) {
        if (i == _gifler.length) return _kuyruk();
        return _hucre(_gifler[i]);
      },
    );
  }

  Widget _kuyruk() {
    if (_yukleniyor) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_hata != null) {
      return Center(
        child: TextButton(
          onPressed: _sonrakiSayfa,
          child: Text('Tekrar Dene'.c),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _hucre(Map<String, dynamic> g) {
    final yol = g['yol'] as String? ?? '';
    final bekliyor = g['durum'] == 'bekliyor';
    final etiket = (g['etiketler'] as List<dynamic>? ?? []).join(', ');
    // Ekran okuyucu için hücrenin tek anlamı etiketidir (ızgarada metin yok).
    return Semantics(
      // 'GIF' 45 dilde de 'GIF' — çeviri anahtarı yapmıyoruz (test
      // çevirinin Türkçesinden FARKLI olmasını şart koşar, haklı olarak).
      label: etiket.isEmpty ? 'GIF' : etiket,
      button: true,
      child: InkWell(
        onTap: () => _sec(g),
        onLongPress: () => _sikayetEt(g),
        borderRadius: BorderRadius.circular(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: DiziRenkler.kart),
              // GIF ANİMASYONU: `AgGorsel` web'de `Image.network` dalına düşer.
              // `CachedNetworkImage` GIF'in yalnız İLK KARESİNİ çizer (8/9 Ağu
              // 2026 piksel kanıtı, test/gif_animasyon_test.dart) — burada da
              // aynı tuzak geçerli, widget'ı değiştirme.
              AgGorsel(
                url: dosyaUrl(yol) ?? '',
                fit: BoxFit.cover,
                hata: Center(
                  child: Icon(Icons.broken_image, color: DiziRenkler.metin38),
                ),
              ),
              // Bekleyen kaydın rozeti: kullanıcı GIF'ini BAŞKASININ görmediğini
              // bilmeli, yoksa "yükledim ama arkadaşım bulamıyor" sanır.
              if (bekliyor)
                Positioned(
                  left: 4,
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Onay bekliyor'.c,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // RichText/TextSpan tema rengini devralmaz; renk AÇIKÇA.
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ortak açıcı — dört yüzey de bunu çağırır (Reels yanıtı, DM, yorum kutusu,
/// akış paylaşım kutusu). Seçilen GIF kaydını döndürür (`yol`, `id`, ...);
/// kullanıcı kapatırsa `null`.
Future<Map<String, dynamic>?> gifSecAc(BuildContext context) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DiziRenkler.koyuGri,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => const GifSecSheet(),
  );
}
