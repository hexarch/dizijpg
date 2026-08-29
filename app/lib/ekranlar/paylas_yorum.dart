import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../ceviri.dart';
import '../gorsel_basliklari.dart';
import '../tema.dart';
import 'bolum_sec.dart';
import 'giris_istem.dart';
import 'gif_sec.dart';
import 'icerik_sec.dart';
import 'medya_inceleme.dart';
import '../medya_yukle.dart';

/// AKIŞTAN PAYLAŞIM — TAM EKRAN yazma ekranı.
///
/// KULLANICI İSTEĞİ (30 Ağu 2026, birebir): "Akışta gönderi paylaşırken yapım
/// seçme zorunlu olmasın, 'yapım seç' yazısındaki zorunluyu kaldır. Oraya da
/// yapım/yönetmen/oyuncu ekle olsun ve 1'den fazla eklenebilsin, ve
/// eklenenlerin profilinde de paylaşılacak — yani mesela Silo ve Breaking
/// Bad'i seçersem ikisinin de profilinde paylaşılacak. Ve dizilerde bölüm,
/// sezon veya dizinin kendisini de seçme olacak. Ve akıştaki 'yorum yap'a
/// tıklandığında yarım modal açma, tam ekranda aç, ve daha güzelini
/// yapabilirsin."
///
/// ---------------------------------------------------------------------------
/// NEDEN TAM EKRAN (yarım modal değil)
/// ---------------------------------------------------------------------------
/// 28 Ağu'daki alt sayfa tek bir iş için tasarlanmıştı: bir yapım seç, iki
/// satır yaz. Bugünkü ekranda dört iş var (metin · 0-6 etiket · ekler · spoiler)
/// ve telefonda klavye açıkken alt sayfanın geriye kalan yüksekliği ~%35'ti:
/// etiket rozetleri ile metin alanı aynı anda GÖRÜNMÜYORDU. Tam ekran ayrıca
/// tek bir birincil eylem (sağ üstteki Paylaş) ve tek bir çıkış (sol üstteki
/// çarpı) sözü verir — alt sayfada "aşağı sürükle" ile "çarpı" iki ayrı çıkış
/// yolu olarak yarışıyordu.
///
/// ---------------------------------------------------------------------------
/// VERİ SÖZLEŞMESİ
/// ---------------------------------------------------------------------------
/// Gönderilen şey hâlâ YENİ bir "gönderi" türü DEĞİL, sıradan bir YORUM
/// (`POST /yorumlar`). Yeni olan tek şey `etiketler` dizisi:
///   `[{tur, tmdb_id, sezon?, bolum?}, ...]`  (0..6)
/// Sunucu bu diziyi `yorum_etiketleri` bağ tablosuna yazıyor ve gönderi
/// LİSTEDEKİ HER VARLIĞIN sayfasında görünüyor.
///
/// ESKİ ALANLAR DA GÖNDERİLİYOR (`tur`/`tmdb_id`/`sezon`/`bolum`): yük hem yeni
/// hem eski sunucuda çalışsın diye. Sunucu `etiketler` varsa onu kullanır,
/// eskileri yok sayar. Dağıtım sırası sunucu → istemci olsa bile, kullanıcının
/// telefonundaki ESKİ uygulama yeni sunucuya yazmaya devam eder; tersi durum
/// (yeni web, eski sunucu) yalnız dağıtım penceresinde birkaç saniyedir ve bu
/// alanlar onu da kapatır.
class PaylasimEtiketi {
  final String tur; // tv · movie · person · company
  final int tmdbId;
  final String ad;

  /// TMDB görsel yolu (afiş / profil / logo) — tür başına ayrı alandan gelir.
  final String? gorsel;

  /// Dizide düzey: ikisi de null → dizinin kendisi, yalnız [sezon] → sezon,
  /// ikisi de dolu → bölüm.
  final int? sezon;
  final int? bolum;

  const PaylasimEtiketi({
    required this.tur,
    required this.tmdbId,
    required this.ad,
    this.gorsel,
    this.sezon,
    this.bolum,
  });

  factory PaylasimEtiketi.tmdb(Map<String, dynamic> r) => PaylasimEtiketi(
    tur: r['media_type'] as String,
    tmdbId: r['id'] as int,
    ad: (r['name'] ?? r['title'] ?? '?') as String,
    gorsel: tmdbGorselYolu(r),
  );

  PaylasimEtiketi duzeyle({int? sezon, int? bolum}) => PaylasimEtiketi(
    tur: tur,
    tmdbId: tmdbId,
    ad: ad,
    gorsel: gorsel,
    sezon: sezon,
    bolum: bolum,
  );

  bool get dizi => tur == 'tv';

  /// Aynı varlığın aynı DÜZEYİ iki kez eklenmesin diye tekillik anahtarı.
  /// Düzey anahtara DAHİL: "Silo" ile "Silo 2. sezon" ayrı etiketlerdir ve
  /// kullanıcı ikisini birden isteyebilir.
  String get anahtar => '$tur:$tmdbId:${sezon ?? ''}:${bolum ?? ''}';

  /// Rozetin altındaki küçük satır: tür ya da seçilen düzey.
  String get altYazi {
    if (bolum != null) return '{}. sezon {}. bölüm'.cf(['$sezon', '$bolum']);
    if (sezon != null) return '{}. sezon'.cf(['$sezon']);
    return tmdbTurEtiketi(tur);
  }

  Map<String, dynamic> get json => {
    'tur': tur,
    'tmdb_id': tmdbId,
    if (sezon != null) 'sezon': sezon,
    if (bolum != null) 'bolum': bolum,
  };
}

class PaylasYorumEkrani extends StatefulWidget {
  const PaylasYorumEkrani({super.key});

  @override
  State<PaylasYorumEkrani> createState() => _PaylasYorumEkraniState();
}

class _PaylasYorumEkraniState extends State<PaylasYorumEkrani> {
  /// Etiket tavanı SUNUCUYLA AYNI (`YORUM_ETIKET_AZAMI`). Burada da durması
  /// gerekiyor ki kullanıcı 7. rozeti ekleyip 400 yemesin.
  static const etiketAzami = 6;

  final _metin = TextEditingController();
  final _odak = FocusNode();

  final List<PaylasimEtiketi> _etiketler = [];
  final List<Map<String, dynamic>> _ekler = []; // {yol, video}
  bool _ekYukleniyor = false;
  int _ekToplam = 0;
  int _ekBiten = 0;
  bool _spoiler = false;
  bool _gonderiliyor = false;

  @override
  void initState() {
    super.initState();
    _metin.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _metin.dispose();
    _odak.dispose();
    super.dispose();
  }

  /// ETİKET ARTIK KAPI DEĞİL — tek koşul metin (sunucu da boş metni reddediyor).
  bool get _gonderilebilir =>
      _metin.text.trim().isNotEmpty && !_gonderiliyor && !_ekYukleniyor;

  // ------------------------------------------------------------------ etiket
  Future<void> _etiketEkle() async {
    if (_etiketler.length >= etiketAzami) {
      _uyar('En fazla {} yapım ekleyebilirsin.'.cf(['$etiketAzami']));
      return;
    }
    final secim = await icerikSecAc(context);
    if (secim == null || !mounted) return;
    var etiket = PaylasimEtiketi.tmdb(secim);
    // DİZİDE DÜZEY HEMEN SORULUR: seçici kapanır kapanmaz üç düzey açılır.
    // Ayrı bir "bölüm seç" satırı bırakmak, çoklu etikette hangi rozete ait
    // olduğunu belirsizleştirirdi (tek etiketliyken sorun değildi).
    if (etiket.dizi) {
      final duzey = await _duzeySec(etiket);
      if (!mounted) return;
      if (duzey == null) return; // vazgeçti → etiket HİÇ eklenmez
      etiket = duzey;
    }
    if (_etiketler.any((e) => e.anahtar == etiket.anahtar)) {
      _uyar('Bu zaten ekli.'.c);
      return;
    }
    setState(() => _etiketler.add(etiket));
  }

  /// Dizinin kendisi / sezon / bölüm. `null` = vazgeçildi.
  Future<PaylasimEtiketi?> _duzeySec(PaylasimEtiketi etiket) async {
    final secim = await bolumSecAc(
      context,
      diziId: etiket.tmdbId,
      diziAd: etiket.ad,
    );
    if (secim == null) return null;
    // Sözleşme (bolum_sec.dart): `{}` dizinin kendisi, `{sezon}` sezon,
    // `{sezon, bolum}` bölüm.
    return etiket.duzeyle(
      sezon: secim['sezon'] as int?,
      bolum: secim['bolum'] as int?,
    );
  }

  /// Ekli bir dizi rozetine dokunuş: düzeyini DEĞİŞTİR.
  Future<void> _duzeyDegistir(int i) async {
    final yeni = await _duzeySec(_etiketler[i]);
    if (yeni == null || !mounted) return;
    // Düzey değişince başka bir rozetle çakışabilir (Silo 2. sezon zaten
    // ekliyken Silo'yu 2. sezona çevirmek gibi) — çakışırsa yenisi düşer.
    if (_etiketler.asMap().entries.any(
      (g) => g.key != i && g.value.anahtar == yeni.anahtar,
    )) {
      _uyar('Bu zaten ekli.'.c);
      return;
    }
    setState(() => _etiketler[i] = yeni);
  }

  // -------------------------------------------------------------------- ekler
  Future<void> _gifSec() async {
    if (!girisGerekli(context)) return;
    if (_ekler.length >= 10 || _ekYukleniyor) return;
    final gif = await gifSecAc(context);
    if (gif == null || !mounted) return;
    final yol = gif['yol'] as String?;
    if (yol == null) return;
    setState(() => _ekler.add({'yol': yol, 'video': false}));
  }

  Future<void> _ekSec() async {
    if (!girisGerekli(context)) return;
    final kalan = 10 - _ekler.length;
    if (kalan <= 0 || _ekYukleniyor) return;
    final secim = await medyaSec(context, azami: kalan);
    if (secim.isEmpty || !mounted) return;
    setState(() {
      _ekYukleniyor = true;
      _ekToplam = secim.length;
      _ekBiten = 0;
    });
    final sonuc = await medyalariYukle(
      secim,
      adim: (biten) {
        if (mounted) setState(() => _ekBiten = biten);
      },
    );
    if (!mounted) return;
    setState(() {
      _ekler.addAll(sonuc.yuklenen);
      _ekYukleniyor = false;
    });
    if (sonuc.hata != null) _uyar(sonuc.hata!);
  }

  void _uyar(String mesaj) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(mesaj)));

  Future<void> _gonder() async {
    if (!_gonderilebilir) return;
    if (!girisGerekli(context)) return;
    setState(() => _gonderiliyor = true);
    try {
      final birincil = _etiketler.isEmpty ? null : _etiketler.first;
      await Api.post('/yorumlar', {
        'etiketler': _etiketler.map((e) => e.json).toList(),
        // ---- ESKİ SUNUCU İÇİN YEDEK ALANLAR ----
        // Yalnız BÖLÜM düzeyinde sezon/bolum konur: eski sunucu "sezon ve
        // bolum birlikte" şartını uyguluyor ve sezon-düzeyi bir yükü 400
        // ile reddederdi.
        if (birincil != null) 'tur': birincil.tur,
        if (birincil != null) 'tmdb_id': birincil.tmdbId,
        if (birincil?.bolum != null) 'sezon': birincil!.sezon,
        if (birincil?.bolum != null) 'bolum': birincil!.bolum,
        'metin': _metin.text.trim(),
        'medya': _ekler.map((e) => e['yol']).toList(),
        'spoiler': _spoiler,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _gonderiliyor = false);
        _uyar(e.toString());
      }
    }
  }

  // ------------------------------------------------------------------- çıkış
  /// Yazılmış bir şey var mı — kapatma onayı buna bakar.
  bool get _dolu =>
      _metin.text.trim().isNotEmpty ||
      _ekler.isNotEmpty ||
      _etiketler.isNotEmpty;

  /// Kapatmadan önce onay. `true` dönerse ekran kapanır.
  ///
  /// ux md.4 + `sheet-dismiss-confirm` (Apple HIG, ui-ux-pro-max veritabanı):
  /// "Kaydedilmemiş değişiklik varken kapatmadan önce onay iste." Tam ekranda
  /// bu kural alt sayfadakinden DAHA önemli: kullanıcı burada uzun metin
  /// yazıyor ve Android'in geri hareketi tek parmak kaydırmasıyla geliyor.
  Future<bool> _cikilsinMi() async {
    if (!_dolu || _gonderiliyor) return true;
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: DiziRenkler.koyuGri,
        title: Text(
          'Gönderiden vazgeç'.c,
          style: TextStyle(color: DiziRenkler.metin),
        ),
        content: Text(
          'Yazdıkların kaydedilmeyecek.'.c,
          style: TextStyle(color: DiziRenkler.metin54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Yazmaya devam et'.c),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Vazgeç'.c, style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    return onay == true;
  }

  // -------------------------------------------------------------------- çizim
  @override
  Widget build(BuildContext context) {
    final kalan = 1000 - _metin.text.characters.length;
    return PopScope(
      // ANDROID GERİ HAREKETİ de onaydan geçsin. `WillPopScope` kullanılmadı:
      // Flutter'da kullanımdan kaldırıldı (Flutter yığını kuralı #21).
      //
      // ⚠ `canPop` SABİT `false` OLAMAZ. PopScope PROGRAMLI `Navigator.pop`u
      // da yakalıyor: paylaşım bittikten sonraki `Navigator.pop(context, true)`
      // engellenir, yerine `onPopInvokedWithResult` çalışır ve o dal SONUÇ
      // TAŞIMADAN kapatırdı. Çağıran `true` yerine `null` alır, akış
      // TAZELENMEZ — yani kullanıcı paylaştığı gönderiyi göremezdi.
      // Onay yalnız GERÇEKTEN kaybedilecek bir şey varken devreye girer.
      canPop: !_dolu || _gonderiliyor,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _cikilsinMi() && mounted) {
          if (!context.mounted) return;
          Navigator.pop(context);
        }
      },
      child: _govde(kalan),
    );
  }

  Widget _govde(int kalan) {
    return Scaffold(
      backgroundColor: DiziRenkler.siyah,
      appBar: AppBar(
        // TEK ÇIKIŞ: sol üstte çarpı. Alt sayfadaki "aşağı sürükle" yolu
        // bilerek kalktı — iki çıkış, yazılmış metni kazayla atma riskini
        // ikiye katlıyordu.
        leading: IconButton(
          tooltip: 'Kapat'.c,
          icon: Icon(Icons.close, color: DiziRenkler.metin),
          onPressed: () async {
            if (await _cikilsinMi() && mounted) {
              if (!context.mounted) return;
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          'Paylaş'.c,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: DiziRenkler.metin,
          ),
        ),
        actions: [
          // BİRİNCİL EYLEM SAĞ ÜSTTE: tam ekran yazma ekranının standart yeri;
          // klavye açıkken de her zaman görünür kalır (alt bara konsaydı
          // klavyenin üstünde sıkışırdı).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: FilledButton(
              onPressed: _gonderilebilir ? _gonder : null,
              child: _gonderiliyor
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Paylaş'.c),
            ),
          ),
        ],
      ),
      // MASAÜSTÜNDE ORTALANMIŞ KOLON — akış, takvim, Reels ve profil ile AYNI
      // kalıp ([OrtaKolon], tema.dart). Emülatör yerine gerçek tarayıcıda
      // (1383 dp) bakınca görüldü: kolon kısıtı olmadan metin alanı 1.300 dp
      // genişliğe yayılıyor ve satır uzunluğu okunabilir aralığın (35-60
      // karakter) çok üstüne çıkıyordu — üstelik yazılan gönderi akışta 720
      // dp'lik kolonda görüneceği için önizleme de yanıltıcıydı.
      //
      // TELEFON BOZULMAZ: [OrtaKolon] sabit genişlik değil ÜST SINIR verir.
      body: SafeArea(
        child: OrtaKolon(
          azami: masaustuKolonGenisligi,
          cocuk: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                  children: [
                    _yazmaSatiri(),
                    if (_ekler.isNotEmpty) _ekSeridi(),
                    const SizedBox(height: 6),
                    _etiketBolumu(),
                  ],
                ),
              ),
              _altCubuk(kalan),
            ],
          ),
        ),
      ),
    );
  }

  /// Avatar + metin alanı: gönderinin akışta görüneceği hâle yakın dursun.
  Widget _yazmaSatiri() {
    Object? ham;
    try {
      ham = context.watch<Oturum>().kullanici?['avatar'];
    } on ProviderNotFoundException {
      // Widget testlerinde sağlayıcı olmadan da kurulabilsin (kabuk.dart ve
      // akış kutusuyla aynı savunma).
      ham = null;
    }
    final avatar = ham is String && ham.trim().isNotEmpty
        ? dosyaUrl(ham)
        : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: DiziRenkler.kart,
          backgroundImage: avatar == null
              ? null
              : CachedNetworkImageProvider(
                  avatar,
                  headers: gorselBasliklari(avatar),
                ),
          child: avatar == null
              ? Icon(Icons.person, size: 22, color: DiziRenkler.metin38)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _metin,
            focusNode: _odak,
            autofocus: true,
            minLines: 5,
            maxLines: null,
            maxLength: 1000,
            // Sayaç alt çubukta; buradaki yerleşik sayaç ikinci kez yazardı.
            buildCounter:
                (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
            style: TextStyle(
              color: DiziRenkler.metin,
              fontSize: 17,
              height: 1.45,
            ),
            decoration: InputDecoration(
              hintText: 'Ne düşünüyorsun?'.c,
              hintStyle: TextStyle(color: DiziRenkler.metin38, fontSize: 17),
              // Çerçeve YOK: tam ekranda kutu çizmek alanı daraltıyor ve
              // "form" hissi veriyordu; burada yazılan şey bir gönderi.
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  /// Yüklenen eklerin küçük şeridi — her karede kaldırma düğmesi.
  /// Eski kutu yalnız "3" yazıyordu; hangi dosyanın eklendiği görünmüyordu.
  Widget _ekSeridi() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 52),
      child: SizedBox(
        height: 84,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _ekler.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final ek = _ekler[i];
            final video = ek['video'] == true;
            final url = dosyaUrl(ek['yol'] as String?);
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 84,
                    height: 84,
                    color: DiziRenkler.kart,
                    child: video || url == null
                        ? Icon(
                            video
                                ? Icons.play_circle_outline
                                : Icons.image_outlined,
                            color: DiziRenkler.metin38,
                          )
                        : CachedNetworkImage(
                            imageUrl: url,
                            httpHeaders: gorselBasliklari(url),
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                // Kaldırma düğmesi KARENİN İÇİNDE: `Positioned`ı Stack
                // sınırının dışına taşırmak (negatif offset) onu Flutter'da
                // TIKLANAMAZ yapar (ux md.2).
                //
                // DOKUNMA HEDEFİ 36 dp (ikon 16 + 10'ar dolgu): 84 dp'lik
                // karenin üstünde 44 dp'lik bir hedef karenin yarısını
                // kaplardı ve önizlemeyi görünmez ederdi. `no-precision-required`
                // kuralının derdi "ince kenar/8 dp ikon"; buradaki daire
                // parmakla rahat vurulur ve komşu kareyle arasında 8 dp var.
                Positioned(
                  top: 0,
                  right: 0,
                  child: Semantics(
                    button: true,
                    label: 'Kaldır'.c,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => _ekler.removeAt(i)),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Etiket rozetleri + "ekle" rozeti.
  Widget _etiketBolumu() {
    return Padding(
      padding: const EdgeInsets.only(left: 52, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _etiketler.length; i++)
                _EtiketRozeti(
                  etiket: _etiketler[i],
                  // Dizide rozete dokunmak DÜZEYİ değiştirir; film/kişi/firmada
                  // değiştirilecek bir düzey yok, o yüzden dokunma da yok
                  // (tıklanınca hiçbir şey olmayan hedef bırakmıyoruz).
                  onDuzey: _etiketler[i].dizi ? () => _duzeyDegistir(i) : null,
                  onKaldir: () => setState(() => _etiketler.removeAt(i)),
                ),
              if (_etiketler.length < etiketAzami) _ekleRozeti(),
            ],
          ),
          if (_etiketler.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                // "(zorunlu)" GİTTİ — kullanıcı isteği. Yerine ne işe
                // yaradığını söyleyen bir ipucu kondu; boş bırakmak da geçerli
                // bir seçim olduğu için uyarı tonunda DEĞİL.
                //
                // AÇIKLAMA ROZETTE DEĞİL BURADA: uzun etiket ("Yapım, oyuncu,
                // yönetmen ekle") 420 dp'lik ekranda rozeti taşırıyordu ve
                // Almanca/Fince gibi uzun dillerde daha da kötüydü. Rozet
                // kısa kaldı, açıklama sarmalanabilen bu satıra indi.
                'Dizi, film, oyuncu ya da yönetmen etiketle — gönderin onların sayfasında da görünür.'
                    .c,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: DiziRenkler.metin38,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ekleRozeti() {
    return Semantics(
      button: true,
      label: 'Dizi, film, oyuncu ya da yönetmen etiketle'.c,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: _etiketEkle,
        child: Container(
          // Dokunma hedefi 44 dp (ux md.2); genişlik tavanı taşmayı önler.
          constraints: const BoxConstraints(minHeight: 44, maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: DiziRenkler.sariMetin.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 18, color: DiziRenkler.sariMetin),
              const SizedBox(width: 6),
              // Flexible + ellipsis: çeviri uzarsa rozet taşmaz, kısalır.
              Flexible(
                child: Text(
                  'Etiket ekle'.c,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: DiziRenkler.sariMetin,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Klavyenin üstünde duran eylem çubuğu: ekler · GIF · spoiler · sayaç.
  Widget _altCubuk(int kalan) {
    return Container(
      decoration: BoxDecoration(
        color: DiziRenkler.siyah,
        border: Border(top: BorderSide(color: DiziRenkler.metin12)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Fotoğraf/video ekle'.c,
            onPressed: _ekYukleniyor ? null : _ekSec,
            icon: Icon(
              Icons.add_photo_alternate_outlined,
              color: DiziRenkler.sariMetin,
            ),
          ),
          IconButton(
            tooltip: 'GIF ekle'.c,
            onPressed: _ekYukleniyor ? null : _gifSec,
            icon: Icon(Icons.gif_box_outlined, color: DiziRenkler.sariMetin),
          ),
          // Spoiler: içerik sayfasındaki yorum kutusuyla aynı sözleşme.
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => _spoiler = !_spoiler),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _spoiler ? Icons.check_box : Icons.check_box_outline_blank,
                    size: 18,
                    color: _spoiler
                        ? DiziRenkler.sariMetin
                        : DiziRenkler.metin38,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Spoiler'.c,
                    style: TextStyle(fontSize: 12, color: DiziRenkler.metin54),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (_ekYukleniyor)
            Text(
              '{}/{} yükleniyor'.cf(['$_ekBiten', '$_ekToplam']),
              style: TextStyle(fontSize: 12, color: DiziRenkler.metin54),
            )
          // Sayaç yalnız SON 100 KARAKTERDE çıkar: sürekli görünen bir sayaç
          // kısa gönderilerde gereksiz baskı kuruyor.
          else if (kalan <= 100)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                '$kalan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kalan < 0 ? Colors.redAccent : DiziRenkler.metin54,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tek bir etiket rozeti: görsel + ad + düzey + kaldırma.
class _EtiketRozeti extends StatelessWidget {
  final PaylasimEtiketi etiket;
  final VoidCallback? onDuzey;
  final VoidCallback onKaldir;

  const _EtiketRozeti({
    required this.etiket,
    required this.onDuzey,
    required this.onKaldir,
  });

  @override
  Widget build(BuildContext context) {
    final gorsel = posterUrl(etiket.gorsel, boyut: 'w92');
    return Container(
      constraints: const BoxConstraints(minHeight: 44, maxWidth: 260),
      decoration: BoxDecoration(
        color: DiziRenkler.kart,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: DiziRenkler.metin12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(4),
            child: ClipOval(
              child: SizedBox(
                width: 32,
                height: 32,
                child: gorsel == null
                    ? Container(
                        color: DiziRenkler.acikGri,
                        child: Icon(
                          etiket.tur == 'person'
                              ? Icons.person
                              : etiket.tur == 'company'
                              ? Icons.business
                              : Icons.movie_outlined,
                          size: 16,
                          color: DiziRenkler.metin38,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: gorsel,
                        httpHeaders: gorselBasliklari(gorsel),
                        // Firma logosu şeffaf ve GENİŞ: `cover` onu kırpıp
                        // tanınmaz hâle getirir.
                        fit: etiket.tur == 'company'
                            ? BoxFit.contain
                            : BoxFit.cover,
                      ),
              ),
            ),
          ),
          Flexible(
            child: InkWell(
              onTap: onDuzey,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      etiket.ad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: DiziRenkler.metin,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            etiket.altYazi,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: DiziRenkler.metin38,
                            ),
                          ),
                        ),
                        // Düzey DEĞİŞTİRİLEBİLİR olduğunu gösteren tek işaret;
                        // yalnız dizide çizilir.
                        if (onDuzey != null)
                          Icon(
                            Icons.expand_more,
                            size: 14,
                            color: DiziRenkler.metin38,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 44 dp'lik ayrı dokunma hedefi: rozetin gövdesi düzeyi açar,
          // buradaki çarpı rozeti KALDIRIR. İkisi karışmasın diye ayrık.
          Semantics(
            button: true,
            label: 'Kaldır'.c,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onKaldir,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.close, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paylaşım ekranını TAM EKRAN açar. Paylaşım yapıldıysa `true` döner
/// (çağıran akışı tazelesin diye).
///
/// `fullscreenDialog: true`: iOS'ta aşağıdan yukarı geçiş + çarpı ikonu,
/// Android'de de "bu bir görev, bir sayfa değil" davranışı.
Future<bool> paylasYorumAc(BuildContext context) async {
  final sonuc = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const PaylasYorumEkrani(),
    ),
  );
  return sonuc == true;
}
