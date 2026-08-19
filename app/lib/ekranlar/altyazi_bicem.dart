import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../altyazi.dart';
import '../altyazi_font.dart';
import '../ceviri.dart';
import '../tema.dart';

/// Ayarlar > Video altyazıları > Altyazı görünümü.
///
/// Neden AYRI ekran: on denetim (renk/opaklık/font/ayrıt) ayarlar sayfasının
/// ortasına konsaydı sayfa boğulurdu.
///
/// EN ÜSTTE CANLI ÖNİZLEME var ve önizleme GERÇEK çizim koduyla ([AltyaziGovde])
/// çiziliyor — ayrı bir kopya yazılsaydı ayarlar "çalışıyor gibi" görünüp
/// videoda başka davranabilirdi.
class AltyaziBicemEkrani extends StatelessWidget {
  const AltyaziBicemEkrani({super.key});

  /// Önizlemedeki örnek cümle — gerçek bir çeviri altyazısı kadar uzun olsun
  /// ki kullanıcı sarma/zemin genişliğini de görsün.
  static String get ornekMetin => 'Bu bir örnek altyazıdır.'.c;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DiziRenkler.siyah,
      appBar: AppBar(
        backgroundColor: DiziRenkler.koyuGri,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: DiziRenkler.metin),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/ayarlar'),
        ),
        title: Text(
          'Altyazı görünümü'.c,
          style: TextStyle(color: DiziRenkler.metin),
        ),
      ),
      body: OrtaKolon(
        azami: masaustuKolonGenisligi,
        // Tüm sayfa TEK bildiriciden beslenir: bir denetim değişince hem
        // önizleme hem de o an oynayan videolar aynı karede güncellenir.
        cocuk: ValueListenableBuilder<AltyaziBicem>(
          valueListenable: AltyaziAyar.bicem,
          builder: (context, b, _) => ListView(
            padding: EdgeInsets.fromLTRB(
              14,
              14,
              14,
              24 + MediaQuery.of(context).padding.bottom,
            ),
            children: [
              _Onizleme(bicem: b),
              const SizedBox(height: 8),
              Text(
                'Ayar değiştikçe önizleme anında güncellenir.'.c,
                style: TextStyle(color: DiziRenkler.metin54, fontSize: 12),
              ),
              const SizedBox(height: 16),

              // ---------------- YAZI ----------------
              // Tek sözcüklük başlık ('Yazı') çeviride belirsiz kalırdı —
              // 45 dile giden anahtar bağlamı kendi içinde taşısın.
              _Baslik('Yazı biçimi'.c),
              _Kart(
                cocuklar: [
                  _RenkSatiri(
                    baslik: 'Yazı rengi'.c,
                    secili: b.yaziRengi,
                    onSec: (r) => AltyaziAyar.bicemSec(b.kopya(yaziRengi: r)),
                  ),
                  _OpaklikSatiri(
                    baslik: 'Yazı opaklığı'.c,
                    deger: b.yaziOpaklik,
                    onDegis: (d) =>
                        AltyaziAyar.bicemSec(b.kopya(yaziOpaklik: d)),
                  ),
                  _FontSatiri(bicem: b),
                  _BoyutSatiri(bicem: b),
                ],
              ),
              const SizedBox(height: 16),

              // ---------------- KENAR (AYRIT) ----------------
              _Baslik('Karakter ayrıtı'.c),
              _Kart(
                cocuklar: [
                  _AyritSatiri(bicem: b),
                  _RenkSatiri(
                    baslik: 'Ayrıt rengi'.c,
                    secili: b.ayritRengi,
                    onSec: (r) => AltyaziAyar.bicemSec(b.kopya(ayritRengi: r)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ---------------- ARKA PLAN ----------------
              _Baslik('Arka plan'.c),
              _Kart(
                cocuklar: [
                  _RenkSatiri(
                    baslik: 'Arka plan rengi'.c,
                    secili: b.zeminRengi,
                    onSec: (r) => AltyaziAyar.bicemSec(b.kopya(zeminRengi: r)),
                  ),
                  _OpaklikSatiri(
                    baslik: 'Arka plan opaklığı'.c,
                    deger: b.zeminOpaklik,
                    onDegis: (d) =>
                        AltyaziAyar.bicemSec(b.kopya(zeminOpaklik: d)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Text(
                      'Arka plan yazının hemen arkasındaki dolgudur; pencere ise tüm altyazı bloğunun arkasındaki daha geniş yüzey.'
                          .c,
                      style: TextStyle(
                        color: DiziRenkler.metin54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ---------------- PENCERE ----------------
              _Baslik('Pencere'.c),
              _Kart(
                cocuklar: [
                  _RenkSatiri(
                    baslik: 'Pencere rengi'.c,
                    secili: b.pencereRengi,
                    onSec: (r) =>
                        AltyaziAyar.bicemSec(b.kopya(pencereRengi: r)),
                  ),
                  _OpaklikSatiri(
                    baslik: 'Pencere opaklığı'.c,
                    deger: b.pencereOpaklik,
                    onDegis: (d) =>
                        AltyaziAyar.bicemSec(b.kopya(pencereOpaklik: d)),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ---------------- SIFIRLA ----------------
              OutlinedButton.icon(
                key: const ValueKey('altyazi-bicem-sifirla'),
                onPressed: () => _sifirlaSor(context),
                icon: Icon(Icons.restart_alt, color: DiziRenkler.metin),
                label: Text(
                  'Sıfırla'.c,
                  style: TextStyle(color: DiziRenkler.metin),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  side: BorderSide(color: DiziRenkler.metin38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Yanlışlıkla basılırsa TÜM ayar gider — onay şart.
  static Future<void> _sifirlaSor(BuildContext context) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: DiziRenkler.koyuGri,
        title: Text(
          'Altyazı görünümü sıfırlansın mı?'.c,
          style: TextStyle(color: DiziRenkler.metin),
        ),
        content: Text(
          'Renk, yazı tipi, boyut, ayrıt ve opaklık ayarları varsayılana döner.'
              .c,
          style: TextStyle(color: DiziRenkler.metin54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(
              'Vazgeç'.c,
              style: TextStyle(color: DiziRenkler.metin54),
            ),
          ),
          TextButton(
            key: const ValueKey('altyazi-bicem-sifirla-onay'),
            onPressed: () => Navigator.pop(d, true),
            child: Text(
              'Sıfırla'.c,
              style: TextStyle(color: DiziRenkler.sariMetin),
            ),
          ),
        ],
      ),
    );
    if (onay != true) return;
    await AltyaziAyar.bicemSifirla();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Altyazı görünümü varsayılana döndü'.c)),
    );
  }
}

// ===========================================================================
// Önizleme
// ===========================================================================

/// Sabit örnek altyazı, GERÇEK çizim koduyla ([AltyaziGovde]).
///
/// Zemin KASITLI olarak yarı koyu / yarı açık: opaklık kararı ancak iki
/// sahnede birden görülünce anlamlı olur (beyaz metin açık sahnede kaybolur).
class _Onizleme extends StatelessWidget {
  final AltyaziBicem bicem;
  const _Onizleme({required this.bicem});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 160,
        child: Stack(
          children: [
            const Positioned.fill(
              child: Row(
                children: [
                  Expanded(child: ColoredBox(color: Color(0xFF121216))),
                  Expanded(child: ColoredBox(color: Color(0xFFEDEDF1))),
                ],
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: AltyaziGovde(
                    metin: AltyaziBicemEkrani.ornekMetin,
                    bicem: bicem,
                    yaziBoyutu: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Ortak küçük parçalar
// ===========================================================================

class _Baslik extends StatelessWidget {
  final String metin;
  const _Baslik(this.metin);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      metin,
      style: TextStyle(fontWeight: FontWeight.w800, color: DiziRenkler.metin),
    ),
  );
}

class _Kart extends StatelessWidget {
  final List<Widget> cocuklar;
  const _Kart({required this.cocuklar});

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: cocuklar,
    ),
  );
}

/// Sekiz hazır renk. Seçili olan hem HALKA hem de TİK ikonu alır — bilgi
/// yalnız renkle taşınmasın (renk körü kullanıcı iki koyu tonu ayıramaz).
class _RenkSatiri extends StatelessWidget {
  final String baslik;
  final Color secili;
  final ValueChanged<Color> onSec;

  const _RenkSatiri({
    required this.baslik,
    required this.secili,
    required this.onSec,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(baslik, style: TextStyle(color: DiziRenkler.metin)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in altyaziRenkleri)
                Semantics(
                  label: '$baslik — ${altyaziRenkAdi(r)}',
                  selected: r.toARGB32() == secili.toARGB32(),
                  button: true,
                  child: InkWell(
                    key: ValueKey('renk-$baslik-${r.toARGB32()}'),
                    onTap: () => onSec(r),
                    borderRadius: BorderRadius.circular(22),
                    // Dokunma hedefi 44x44 (ui-ux kuralı); benek 32 px.
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: r,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: r.toARGB32() == secili.toARGB32()
                                  ? DiziRenkler.sari
                                  : DiziRenkler.metin38,
                              width: r.toARGB32() == secili.toARGB32() ? 3 : 1,
                            ),
                          ),
                          child: r.toARGB32() == secili.toARGB32()
                              ? Icon(
                                  Icons.check,
                                  size: 18,
                                  // Tik, beneğin KENDİ rengine göre kontrast
                                  // alır; sabit beyaz tik sarı benekte erirdi.
                                  color:
                                      ThemeData.estimateBrightnessForColor(r) ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kullanıcının "parlaklık" dediği denetim: teknik karşılığı OPAKLIK.
/// Etikette "opaklık" yazıyor çünkü kaydırıcı çekilince metin saydamlaşıyor —
/// "parlaklık" yazsaydık etiket yalan söylerdi.
class _OpaklikSatiri extends StatelessWidget {
  final String baslik;
  final double deger;
  final ValueChanged<double> onDegis;

  const _OpaklikSatiri({
    required this.baslik,
    required this.deger,
    required this.onDegis,
  });

  @override
  Widget build(BuildContext context) {
    final yuzde = (deger * 100).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(baslik, style: TextStyle(color: DiziRenkler.metin)),
              ),
              Text(
                '%$yuzde',
                style: TextStyle(color: DiziRenkler.metin54, fontSize: 13),
              ),
            ],
          ),
          Slider(
            key: ValueKey('opaklik-$baslik'),
            value: deger.clamp(0.0, 1.0),
            divisions: 20,
            activeColor: DiziRenkler.sari,
            label: '%$yuzde',
            onChanged: onDegis,
          ),
        ],
      ),
    );
  }
}

class _BoyutSatiri extends StatelessWidget {
  final AltyaziBicem bicem;
  const _BoyutSatiri({required this.bicem});

  @override
  Widget build(BuildContext context) {
    final yuzde = (bicem.boyutOlcek * 100).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Yazı boyutu'.c,
                  style: TextStyle(color: DiziRenkler.metin),
                ),
              ),
              Text(
                '%$yuzde',
                style: TextStyle(color: DiziRenkler.metin54, fontSize: 13),
              ),
            ],
          ),
          Slider(
            key: const ValueKey('altyazi-boyut'),
            value: bicem.boyutOlcek.clamp(
              AltyaziBicem.enKucukOlcek,
              AltyaziBicem.enBuyukOlcek,
            ),
            min: AltyaziBicem.enKucukOlcek,
            max: AltyaziBicem.enBuyukOlcek,
            divisions: 12,
            activeColor: DiziRenkler.sari,
            label: '%$yuzde',
            onChanged: (d) => AltyaziAyar.bicemSec(bicem.kopya(boyutOlcek: d)),
          ),
        ],
      ),
    );
  }
}

/// 30 yazı tipi. Açılır menü yerine tam sayfalık bir sheet: her ad KENDİ yazı
/// tipiyle çizilir, seçim körlemesine yapılmasın.
///
/// TEMBEL YÜKLEME: aileler `pubspec.yaml`da `assets:` altında; seçilmeden
/// bellekte YOKLAR. Seçim anında indirilir ve bu satır üç hâli de gösterir:
/// yükleniyor (spinner) → başarı (font inince önizleme kendiliğinden düzelir,
/// `AltyaziFont.surum`) → hata (SnackBar + varsayılan fontla çizmeye devam).
class _FontSatiri extends StatefulWidget {
  final AltyaziBicem bicem;
  const _FontSatiri({required this.bicem});

  @override
  State<_FontSatiri> createState() => _FontSatiriState();
}

class _FontSatiriState extends State<_FontSatiri> {
  /// İndirilmekte olan aile (null ise indirme yok).
  String? _inen;

  @override
  Widget build(BuildContext context) {
    final inen = _inen;
    return ListTile(
      key: const ValueKey('altyazi-font'),
      title: Text('Yazı tipi'.c, style: TextStyle(color: DiziRenkler.metin)),
      subtitle: Text(
        inen == null ? widget.bicem.font : '{} indiriliyor…'.cf([inen]),
        style: TextStyle(
          color: DiziRenkler.metin54,
          // İnerken adı KENDİ ailesiyle yazmayız: font henüz yok, sessizce
          // varsayılana düşerdi — kullanıcı "seçtim ama değişmedi" sanırdı.
          fontFamily: inen == null ? widget.bicem.font : null,
        ),
      ),
      trailing: inen != null
          ? const SizedBox(
              key: ValueKey('altyazi-font-yukleniyor'),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.chevron_right, color: DiziRenkler.metin38),
      // İndirme sürerken ikinci seçim kilitli: yarış durumunda hangi fontun
      // spinner'ı olduğu karışırdı.
      onTap: inen != null ? null : () => _sec(context),
    );
  }

  Future<void> _sec(BuildContext context) async {
    final secilen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: DiziRenkler.koyuGri,
      isScrollControlled: true,
      builder: (s) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(s).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Yazı tipi'.c,
                  style: TextStyle(
                    color: DiziRenkler.metin,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: AltyaziFont.aileler.length,
                  itemBuilder: (_, i) {
                    final f = AltyaziFont.aileler[i];
                    final secili = f == widget.bicem.font;
                    // Aile henüz inmediyse adını ONUN fontuyla yazamayız —
                    // Flutter sessizce varsayılana düşer ve liste "hepsi aynı
                    // font" gibi görünürdü. İndirilmiş olanlar örneklenir.
                    final hazir = AltyaziAyar.fontHazirMi(f);
                    return ListTile(
                      key: ValueKey('font-$f'),
                      title: Text(
                        f,
                        style: TextStyle(
                          color: DiziRenkler.metin,
                          fontFamily: hazir ? f : null,
                          fontSize: 17,
                        ),
                      ),
                      subtitle: hazir
                          ? null
                          : Text(
                              'Seçince indirilir'.c,
                              style: TextStyle(
                                color: DiziRenkler.metin38,
                                fontSize: 12,
                              ),
                            ),
                      trailing: secili
                          ? Icon(Icons.check, color: DiziRenkler.sariMetin)
                          : null,
                      onTap: () => Navigator.pop(s, f),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (secilen == null || !mounted) return;

    // Ayar ÖNCE kalıcı olur: kullanıcı indirme bitmeden ekrandan çıksa bile
    // seçimi kaybolmasın (font açılışta `AltyaziAyar.yukle` ile getirilir).
    final hazirdi = AltyaziAyar.fontHazirMi(secilen);
    await AltyaziAyar.bicemSec(widget.bicem.kopya(font: secilen));
    if (hazirdi || !mounted) return;

    setState(() => _inen = secilen);
    final oldu = await AltyaziAyar.fontHazirla(secilen);
    if (!mounted) return;
    setState(() => _inen = null);
    if (!oldu) {
      // Sessiz başarısızlık YASAK: seçim yerinde kalır ama çizim varsayılan
      // fontla sürer, kullanıcı NEDENİNİ bilir.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Yazı tipi indirilemedi. Varsayılan yazı tipiyle gösteriliyor.'.c,
          ),
        ),
      );
    }
  }
}

/// Kullanıcının "karakter ayrıtı" dediği denetim: harfin kenarına uygulanan
/// işlem (Android'in edgeType'ı).
class _AyritSatiri extends StatelessWidget {
  final AltyaziBicem bicem;
  const _AyritSatiri({required this.bicem});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ayrıt türü'.c, style: TextStyle(color: DiziRenkler.metin)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in AltyaziAyrit.values)
                ChoiceChip(
                  key: ValueKey('ayrit-${a.name}'),
                  label: Text(altyaziAyritAdi(a)),
                  selected: a == bicem.ayrit,
                  selectedColor: DiziRenkler.sari,
                  labelStyle: TextStyle(
                    color: a == bicem.ayrit ? Colors.black : DiziRenkler.metin,
                  ),
                  onSelected: (_) =>
                      AltyaziAyar.bicemSec(bicem.kopya(ayrit: a)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ayrıt türlerinin kullanıcıya görünen adları (çeviriye giren metinler).
String altyaziAyritAdi(AltyaziAyrit a) => switch (a) {
  AltyaziAyrit.yok => 'Yok'.c,
  AltyaziAyrit.disCizgi => 'Dış çizgi'.c,
  AltyaziAyrit.golge => 'Gölge'.c,
  AltyaziAyrit.kabartma => 'Kabartma'.c,
  AltyaziAyrit.oyma => 'Oyma'.c,
};

/// Renk beneklerinin ekran okuyucu adı. Sıra [altyaziRenkleri] ile AYNI.
String altyaziRenkAdi(Color r) {
  const adlar = [
    'Beyaz',
    'Siyah',
    'Kırmızı',
    'Yeşil',
    'Mavi',
    'Sarı',
    'Camgöbeği',
    'Macenta',
  ];
  final i = altyaziRenkleri.indexWhere((c) => c.toARGB32() == r.toARGB32());
  return i < 0 ? '' : adlar[i].c;
}
