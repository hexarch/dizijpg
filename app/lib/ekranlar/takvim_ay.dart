import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import '../gorsel_basliklari.dart';
import '../tema.dart';

/// Masaüstünde aynı anda gösterilen ay sayısı. Dar ekranda DAİMA 1 ay.
const int masaustuAySayisi = 6;

/// Masaüstünde bir ay panelinin hedef genişliği; sütun sayısı buna göre çıkar.
/// 340 dp panelde gün hücresi ~45 dp kalır (44 dp dokunma alanının üstünde).
const double masaustuAyPaneliGenisligi = 340;

/// Masaüstünde sağdaki "seçili günün bölümleri" sütununun genişliği.
const double masaustuGunSutunu = 360;

/// Masaüstünde ay ızgarası + gün sütununun ORTALANDIĞI azami genişlik.
///
/// Takvim tek sütunlu bir OKUMA kolonu değil, iki bölmeli bir araç: solda
/// [masaustuAySayisi] aylık ızgara, sağda seçili günün listesi. Bu yüzden
/// akış/profilin [masaustuKolonGenisligi] (720) kolonuna sığmaz; sınır
/// "3 sütun × [masaustuAyPaneliGenisligi] + boşluklar + ayırıcı + gün sütunu"
/// toplamıdır (1417 dp).
///
/// NEDEN GEREKLİ (ölçüldü): sınırsızken panel genişliği ekranla birlikte
/// büyüyordu — 1440 dp'de 347,7 dp, **1920 dp'de 507,7 dp**; gün hücresi 72
/// dp'ye çıkıp ızgara sağa-sola yayılıyordu. Sınırla panel her iki ekranda da
/// 340 dp'de kalır (gün hücresi 48,6 dp — `dokunmaAsgari` 44'ün üstünde) ve
/// blok ekranda ortalanır.
///
/// 1440 dp'de kısıt neredeyse hiç bağlamaz (1417 ≈ 1440): "altı ay birden
/// ekrana sığar" garantisi (3 Ağu isteği) korunur.
const double masaustuTakvimGenisligi =
    masaustuAyPaneliGenisligi * 3 + // üç panel
    12 * 2 + // panel araları
    12 + // ızgaranın yatay dolgusu (6+6)
    1 + // dikey ayırıcı
    masaustuGunSutunu;

/// Gün hücresinin altındaki "o gün kaç bölüm var" sayısının punto'su.
/// 16 Ağu: sarı rozet kalktı; sayı tema renginde (koyu=beyaz, açık=siyah)
/// ve bir tık daha küçük. Dolu günün VURGUSU üstteki gün rakamının sarı
/// dairesi. Tek bölümde alt sayı YAZILMAZ (sarı daire yeter); 2+ yazılır.
/// Dokunma alanı (hücre ≥44 dp) bundan etkilenmiyor.
const double takvimSayiPunto = 8;
const double takvimSayiPuntoKompakt = 7;

/// Boş günün yer tutucusu — sayı satırıyla aynı hizada kalsın.
const double takvimSayiYerTutucu = 10;
const double takvimSayiYerTutucuKompakt = 8;

/// Dolu günde gün rakamının sarı daire çapı (44 dp hücreye sığar).
const double takvimGunDaire = 20;
const double takvimGunDaireKompakt = 20;

/// Masaüstü sağ sütunda sonraki gün başlığının dikey dolgusu.
/// Eski 16/8; dilimler arası boşluk %50 kısaldı.
const double takvimDevamBaslikUst = 8;
const double takvimDevamBaslikAlt = 4;

/// DAR EKRAN (mobil) tek-ay ızgarasında gün hücresinin SABİT yüksekliği.
///
/// 3 Ağu isteği: "mobilde takvim çok büyük duruyor, yükseklik olarak %35
/// azaltabiliriz". Eskiden yükseklik `childAspectRatio: 0.82` ile GENİŞLİKTEN
/// türüyordu: 360 dp telefonda hücre 49.1 x 59.9, 430 dp'de 59.1 x 72.1 —
/// yani ekran büyüdükçe takvim orantısız uzuyordu. Artık satır yüksekliği
/// ekrandan bağımsız sabit.
///
/// NEDEN TAM 44: dokunma hedefi asgarisi (kabuk.dart `dokunmaAsgari`). İstenen
/// %35, ızgarayı 360 dp'de 38.9 dp hücreye düşürürdü — takvim kullanılamaz
/// olurdu. Bu yüzden hücre 44'te DURDURULDU, kalan kısaltma başlık satırı,
/// hafta başlıkları, yatay dolgu ve ayırıcıdan çıkarıldı.
/// Ölçüler [takvimGunYuksekligiDar] ve kardeşleri üzerinden testlerle kilitli.
const double takvimGunYuksekligiDar = 44;

/// Dar ekranda ızgaranın yatay dolgusu (eski 8).
/// 4'e indi ki 320 dp telefonda hücre GENİŞLİĞİ de 44'ün altına düşmesin:
/// eskiden (320-16)/7 = 43.4 dp ile dokunma asgarisi ZATEN ihlal ediliyordu,
/// şimdi (320-8)/7 = 44.6 dp.
const double takvimYatayDolguDar = 4;

/// Dar ekranda ay başlığı/ok satırının yüksekliği (eski 58 = 48 ikon + 10 dolgu).
/// Oklar da birer dokunma hedefi, o yüzden burada da taban 44.
const double takvimGezinmeYuksekligiDar = 44;

/// Dar ekranda ızgara ile alttaki bölüm listesi arasındaki ayırıcı (eski 20).
const double takvimAyiriciYuksekligiDar = 10;

/// Masaüstü sağ sütunda bir günün başlığı + o günün bölümleri.
/// [tarih] `YYYY-MM-DD`. Seçili günün kendisi de (boş olsa bile) ilk sıradadır.
@immutable
class TakvimGunGrubu {
  final String tarih;
  final List<Map<String, dynamic>> bolumler;
  const TakvimGunGrubu(this.tarih, this.bolumler);
}

/// Seçili günden ileri: önce seçili gün (bölüm olmasa da), sonra yalnızca
/// DOLU günler. Boş günler atlanır — 16 Ağustos'un altında 18 Ağustos gelir.
@visibleForTesting
List<TakvimGunGrubu> takvimGunDevami(
  Map<String, List<Map<String, dynamic>>> gunler,
  String seciliKey,
) {
  final sonuc = <TakvimGunGrubu>[
    TakvimGunGrubu(seciliKey, gunler[seciliKey] ?? const []),
  ];
  final sonrakiler =
      gunler.keys.where((t) => t.compareTo(seciliKey) > 0).toList()..sort();
  for (final t in sonrakiler) {
    final liste = gunler[t];
    if (liste == null || liste.isEmpty) continue;
    sonuc.add(TakvimGunGrubu(t, liste));
  }
  return sonuc;
}

/// `YYYY-MM-DD` → yerel DateTime (saat yok; parse UTC kayması yapmasın).
@visibleForTesting
DateTime takvimTarihCoz(String anahtar) {
  final p = anahtar.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// Ay-takvimi görünümü: bölümler yayın tarihlerine göre ay ızgarasında;
/// bir güne dokununca o günün bölümleri altta listelenir.
///
/// MASAÜSTÜNDE (genişlik >= [masaustuEsigi]) tek dev ay yerine [masaustuAySayisi]
/// ay yan yana/alt alta küçük paneller hâlinde, bölüm listesi sağda ayrı
/// sütunda gösterilir ve seçili günden SONRAKİ dolu günlerle devam eder
/// (sütun boş kalmasın). Dar ekranda düzen birebir eskisi gibidir.
class AyTakvimi extends StatefulWidget {
  final List<dynamic> olaylar;
  final Future<void> Function(Map<String, dynamic>) onAc;

  const AyTakvimi({super.key, required this.olaylar, required this.onAc});

  @override
  State<AyTakvimi> createState() => _AyTakvimiState();
}

class _AyTakvimiState extends State<AyTakvimi> {
  late DateTime _ay; // gösterilen ayın 1'i
  late DateTime _secili; // seçili gün

  @override
  void initState() {
    super.initState();
    final s = DateTime.now();
    _secili = DateTime(s.year, s.month, s.day);
    _ay = DateTime(s.year, s.month, 1);
  }

  /// Ayı değiştirir ve seçimi o ayın ilk DOLU gününe taşır (yoksa ayın 1'i).
  /// Eskiden seçim bugünde kalıyordu; başka aya geçince alttaki liste hep
  /// boş görünüyor, kullanıcı "veri yok mu, yüklenmedi mi" diye kalıyordu.
  void _ayaGit(DateTime yeniAy) {
    final gunler = _gunlereBol();
    final onEk =
        '${yeniAy.year.toString().padLeft(4, '0')}-'
        '${yeniAy.month.toString().padLeft(2, '0')}';
    final doluGunler = gunler.keys.where((t) => t.startsWith(onEk)).toList()
      ..sort();
    setState(() {
      _ay = yeniAy;
      _secili = doluGunler.isEmpty
          ? DateTime(yeniAy.year, yeniAy.month, 1)
          : DateTime.parse(doluGunler.first);
    });
  }

  String _anahtar(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Map<String, List<Map<String, dynamic>>> _gunlereBol() {
    final m = <String, List<Map<String, dynamic>>>{};
    for (final o in widget.olaylar) {
      final e = o as Map<String, dynamic>;
      final t = e['tarih'] as String?;
      if (t == null || t.length < 10) continue;
      m.putIfAbsent(t.substring(0, 10), () => []).add(e);
    }
    return m;
  }

  /// Gün rakamı: o gün dizi gelecekse sarı daire + siyah yazı (sarı üstü
  /// daima koyu). Boş günde daire yok, tema metni (koyu temada beyaz).
  Widget _gunRakami({
    required int gun,
    required String anahtar,
    required int sayi,
    required bool secili,
    required bool kompakt,
  }) {
    final yazi = Text(
      '$gun',
      style: TextStyle(
        fontSize: kompakt ? (sayi > 0 ? 11.0 : 12.5) : (sayi > 0 ? 12.0 : null),
        fontWeight: secili || sayi > 0 ? FontWeight.w800 : FontWeight.w500,
        height: 1,
        color: sayi > 0 ? Colors.black : DiziRenkler.metin,
      ),
    );
    if (sayi <= 0) return yazi;
    final cap = kompakt ? takvimGunDaireKompakt : takvimGunDaire;
    return Container(
      key: ValueKey('takvim-gun-$anahtar'),
      width: cap,
      height: cap,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: DiziRenkler.sari,
        shape: BoxShape.circle,
      ),
      // Çift haneli gün (31) 20 dp daireye sığsın.
      child: FittedBox(fit: BoxFit.scaleDown, child: yazi),
    );
  }

  /// Bir ay paneli: [baslik] + hafta başlıkları + gün ızgarası.
  /// [kompakt] masaüstünde birden çok ay sığsın diye ölçüleri küçültür.
  Widget _ayPaneli(
    DateTime ay,
    Map<String, List<Map<String, dynamic>>> gunler, {
    required Widget baslik,
    required bool kompakt,
  }) {
    final yerel = MaterialLocalizations.of(context);
    final ilkGun = DateTime(ay.year, ay.month, 1);
    final gunSayisi = DateTime(ay.year, ay.month + 1, 0).day;
    final haftaBasi = yerel.firstDayOfWeekIndex; // 0=Pazar
    final oncesi = (ilkGun.weekday % 7 - haftaBasi + 7) % 7;
    final bugun = DateTime.now();
    final narrow = yerel.narrowWeekdays; // 0=Pazar
    final basliklar = [for (var i = 0; i < 7; i++) narrow[(haftaBasi + i) % 7]];
    final yatay = kompakt ? 2.0 : takvimYatayDolguDar;
    return Column(
      key: ValueKey(
        'takvim-ay-${ay.year.toString().padLeft(4, '0')}-'
        '${ay.month.toString().padLeft(2, '0')}',
      ),
      mainAxisSize: MainAxisSize.min,
      children: [
        baslik,
        // Hafta başlıkları
        Padding(
          padding: EdgeInsets.symmetric(horizontal: yatay),
          child: Row(
            children: [
              for (final b in basliklar)
                Expanded(
                  child: Center(
                    child: Text(
                      b,
                      style: TextStyle(
                        fontSize: kompakt ? 10 : 11,
                        color: DiziRenkler.metin,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        // Gün ızgarası
        Padding(
          padding: EdgeInsets.symmetric(horizontal: yatay),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              // Masaüstü kompakt ızgara: kare hücre (DEĞİŞMEDİ).
              // Dar ekran: satır yüksekliği artık genişlikten türemiyor,
              // sabit [takvimGunYuksekligiDar]. mainAxisExtent verildiğinde
              // childAspectRatio yok sayılır, o yüzden kompaktta null.
              childAspectRatio: 1,
              mainAxisExtent: kompakt ? null : takvimGunYuksekligiDar,
            ),
            itemCount: oncesi + gunSayisi,
            itemBuilder: (context, i) {
              if (i < oncesi) return const SizedBox();
              final gun = i - oncesi + 1;
              final tarih = DateTime(ay.year, ay.month, gun);
              final anahtar = _anahtar(tarih);
              final sayi = gunler[anahtar]?.length ?? 0;
              final secili = _anahtar(_secili) == anahtar;
              final buGun =
                  tarih.year == bugun.year &&
                  tarih.month == bugun.month &&
                  tarih.day == bugun.day;
              return GestureDetector(
                onTap: () => setState(() => _secili = tarih),
                child: Container(
                  margin: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    color: secili
                        ? DiziRenkler.sari.withValues(alpha: 0.18)
                        : null,
                    borderRadius: BorderRadius.circular(kompakt ? 8 : 10),
                    border: buGun
                        ? Border.all(color: DiziRenkler.sari, width: 1.5)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _gunRakami(
                        gun: gun,
                        anahtar: anahtar,
                        sayi: sayi,
                        secili: secili,
                        kompakt: kompakt,
                      ),
                      const SizedBox(height: 1),
                      if (sayi > 1)
                        Container(
                          key: ValueKey('takvim-sayi-$anahtar'),
                          child: Text(
                            '$sayi',
                            style: TextStyle(
                              fontSize: kompakt
                                  ? takvimSayiPuntoKompakt
                                  : takvimSayiPunto,
                              fontWeight: FontWeight.w700,
                              height: 1,
                              // Sarı zemin yok: koyu temada beyaz, açıkta siyah.
                              color: DiziRenkler.metin,
                            ),
                          ),
                        )
                      else
                        // Tek bölümde "1" yazılmaz (sarı daire yeter).
                        // Yer tutucu: dolu/boş gün rakamları hizada kalsın.
                        SizedBox(
                          height: kompakt
                              ? takvimSayiYerTutucuKompakt
                              : takvimSayiYerTutucu,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final yerel = MaterialLocalizations.of(context);
    final gunler = _gunlereBol();
    final genis = masaustuMu(context);
    // Masaüstünde gösterilen pencere: _ay'dan başlayan [masaustuAySayisi] ay.
    final aylar = [
      for (var i = 0; i < (genis ? masaustuAySayisi : 1); i++)
        DateTime(_ay.year, _ay.month + i, 1),
    ];
    final seciliBolumler = gunler[_anahtar(_secili)] ?? [];

    String ayAnahtari(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}';
    // Görünen pencerenin DIŞINDAki bölüm sayıları (ok rozetleri): masaüstünde
    // altı ayın tamamı görünüyorsa rozet o pencerenin dışını sayar.
    final ilkKey = ayAnahtari(aylar.first);
    final sonKey = ayAnahtari(aylar.last);
    final ayKey = ilkKey;
    var oncekiSayi = 0, sonrakiSayi = 0;
    gunler.forEach((t, liste) {
      final mk = t.substring(0, 7);
      if (mk.compareTo(ilkKey) < 0) {
        oncekiSayi += liste.length;
      } else if (mk.compareTo(sonKey) > 0) {
        sonrakiSayi += liste.length;
      }
    });

    // Seçili günden SONRAKİ ilk bölüm (boş günde "sıradaki"yi göstermek için).
    Map<String, dynamic>? sonrakiOlay;
    final siraliTarihler = gunler.keys.toList()..sort();
    final seciliKey = _anahtar(_secili);
    for (final t in siraliTarihler) {
      if (t.compareTo(seciliKey) > 0) {
        sonrakiOlay = gunler[t]!.first;
        break;
      }
    }

    // Ay başlığı + gezinme (oklarda o yöndeki bölüm sayısı rozeti).
    // Masaüstünde başlık AY ARALIĞI gösterir ve oklar pencereyi bir ay kaydırır
    // (seçim yerinde kalır — altı ayın hepsi zaten ekranda). Dar ekranda eski
    // davranış: ayı değiştirir, seçimi o ayın ilk dolu gününe taşır.
    //
    // DAR EKRANDA SIKIŞIK: dolgular sıfırlanır, ok düğmeleri 48 yerine
    // [takvimGezinmeYuksekligiDar] (44 = dokunma asgarisi) olur; satır 58 →
    // 44 dp'ye iner. Masaüstünde ölçüler AYNEN kalır.
    final gezinme = Padding(
      padding: genis
          ? const EdgeInsets.fromLTRB(8, 8, 8, 2)
          : const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _AyOku(
            sikisik: !genis,
            ikon: Icons.chevron_left,
            sayi: oncekiSayi,
            tooltip: 'Önceki ay'.c,
            onTap: () {
              final yeni = DateTime(_ay.year, _ay.month - 1, 1);
              if (genis) {
                setState(() => _ay = yeni);
              } else {
                _ayaGit(yeni);
              }
            },
          ),
          Expanded(
            child: Builder(
              builder: (_) {
                final metin = Text(
                  genis
                      ? '${yerel.formatMonthYear(aylar.first)} - '
                            '${yerel.formatMonthYear(aylar.last)}'
                      : yerel.formatMonthYear(_ay),
                  textAlign: TextAlign.center,
                  maxLines: genis ? null : 1,
                  softWrap: genis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: DiziRenkler.metin,
                  ),
                );
                // Dar ekranda satır yüksekliği 44'e KİLİTLİ: uzun bir ay adı
                // (320 dp telefon, uzun yerelleştirme) iki satıra kaymamalı.
                // Kırpmak yerine küçültüyoruz — ay adı okunur kalsın.
                return genis
                    ? metin
                    : FittedBox(fit: BoxFit.scaleDown, child: metin);
              },
            ),
          ),
          _AyOku(
            sikisik: !genis,
            ikon: Icons.chevron_right,
            sayi: sonrakiSayi,
            tooltip: 'Sonraki ay'.c,
            onTap: () {
              final yeni = DateTime(_ay.year, _ay.month + 1, 1);
              if (genis) {
                setState(() => _ay = yeni);
              } else {
                _ayaGit(yeni);
              }
            },
          ),
        ],
      ),
    );

    // Seçili günün bölümleri.
    // Masaüstü: sütun boş kalmasın diye sonraki DOLU günler de eklenir.
    // Mobil: boş günde tek "sıradaki bölüm" kartı (eski davranış).
    final gunListesi = genis
        ? _masaustuGunListesi(gunler, yerel)
        : seciliBolumler.isEmpty
        ? ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            children: [
              ..._gunBosUyarisi(gunler, ayKey),
              if (sonrakiOlay != null) ...[
                const SizedBox(height: 18),
                Text(
                  'Sıradaki bölüm'.c,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: DiziRenkler.metin,
                  ),
                ),
                const SizedBox(height: 8),
                _bolumKarti(sonrakiOlay, tarihGoster: true),
              ],
            ],
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            itemCount: seciliBolumler.length,
            itemBuilder: (context, i) => _bolumKarti(seciliBolumler[i]),
          );

    // DAR EKRAN: eskisi gibi tek ay, altında seçili günün listesi.
    if (!genis) {
      return Column(
        children: [
          gezinme,
          _ayPaneli(
            aylar.first,
            gunler,
            baslik: const SizedBox.shrink(),
            kompakt: false,
          ),
          const Divider(height: takvimAyiriciYuksekligiDar),
          Expanded(child: gunListesi),
        ],
      );
    }

    // MASAÜSTÜ: solda altı aylık küçük panel ızgarası, sağda seçili günün
    // bölümleri. Tek dev ay 1440'lık ekranda 1200 dp yükseklik kaplıyordu;
    // aynı yerde artık altı ay birden duruyor.
    //
    // Blok ORTALANIR ve [masaustuTakvimGenisligi] ile sınırlanır (akış/profil
    // ile aynı `OrtaKolon` kalıbı, yalnız azami değeri takvime özgü).
    return OrtaKolon(
      azami: masaustuTakvimGenisligi,
      cocuk: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                gezinme,
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, kutu) {
                      // Panel hedefi 340 dp: gün hücresi 44 dp altına düşmesin.
                      final sutun = (kutu.maxWidth / masaustuAyPaneliGenisligi)
                          .floor()
                          .clamp(1, 3);
                      final panelGenislik =
                          (kutu.maxWidth - 12 * (sutun - 1) - 12) / sutun;
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(6, 4, 6, 16),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final ay in aylar)
                              SizedBox(
                                width: panelGenislik,
                                child: _ayPaneli(
                                  ay,
                                  gunler,
                                  kompakt: true,
                                  baslik: Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      yerel.formatMonthYear(ay),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: DiziRenkler.metin,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          SizedBox(
            width: masaustuGunSutunu,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hangi günün listesi olduğu masaüstünde şart: seçili hücre altı
                // ayın içinde kaybolabiliyor. Yerelleştirilmiş tam tarih.
                // Altındaki liste seçili günden SONRAKİ dolu günlerle devam eder.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Text(
                    yerel.formatFullDate(_secili),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: DiziRenkler.metin,
                    ),
                  ),
                ),
                Expanded(child: gunListesi),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Seçili gün boşken gösterilen metin (ayın tamamı boşsa sebebini de söyler).
  List<Widget> _gunBosUyarisi(
    Map<String, List<Map<String, dynamic>>> gunler,
    String ayKey,
  ) => [
    Text('Bu gün bölüm yok'.c, style: TextStyle(color: DiziRenkler.metin)),
    // Ayın TAMAMI boşsa sebebini söyle: kullanıcı "uygulama mı
    // yüklemedi" diye tereddüt etmesin.
    if (!gunler.keys.any((t) => t.startsWith(ayKey))) ...[
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 15, color: DiziRenkler.metin),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Bu ay için yayın tarihi açıklanmış bölüm yok. Tarihler genelde birkaç hafta önceden duyurulur; açıklandıkça burada görünür.'
                  .c,
              style: TextStyle(
                color: DiziRenkler.metin,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    ],
  ];

  /// Masaüstü sağ sütun: seçili gün + sonraki dolu günler (boş gün atlanır).
  Widget _masaustuGunListesi(
    Map<String, List<Map<String, dynamic>>> gunler,
    MaterialLocalizations yerel,
  ) {
    final gruplar = takvimGunDevami(gunler, _anahtar(_secili));
    final cocuklar = <Widget>[];
    final ilk = gruplar.first;
    if (ilk.bolumler.isEmpty) {
      cocuklar.addAll(_gunBosUyarisi(gunler, ilk.tarih.substring(0, 7)));
    } else {
      for (final b in ilk.bolumler) {
        cocuklar.add(_bolumKarti(b));
      }
    }
    for (final g in gruplar.skip(1)) {
      final tarih = takvimTarihCoz(g.tarih);
      cocuklar.add(
        Padding(
          key: ValueKey('takvim-devam-${g.tarih}'),
          padding: const EdgeInsets.fromLTRB(
            4,
            takvimDevamBaslikUst,
            4,
            takvimDevamBaslikAlt,
          ),
          child: InkWell(
            onTap: () => setState(() => _secili = tarih),
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  yerel.formatFullDate(tarih),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: DiziRenkler.metin,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      for (final b in g.bolumler) {
        cocuklar.add(_bolumKarti(b));
      }
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      children: cocuklar,
    );
  }

  /// Bir bölüm kartı (seçili gün listesi + "sıradaki bölüm" için ortak).
  Widget _bolumKarti(Map<String, dynamic> b, {bool tarihGoster = false}) {
    final poster = posterUrl(b['poster'] as String?, boyut: 'w185');
    final t = (b['tarih'] as String? ?? '');
    final tarih = t.length >= 10
        ? '${t.substring(8, 10)}.${t.substring(5, 7)}.${t.substring(0, 4)}'
        : '';
    return Card(
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 42,
            height: 62,
            child: poster == null
                ? Container(color: DiziRenkler.koyuGri)
                : CachedNetworkImage(
                    imageUrl: poster,
                    httpHeaders: gorselBasliklari(poster),
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        title: Text(
          b['dizi_adi'] as String? ?? '',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${'S{}B{}'.cf([b['sezon'], b['bolum']])}'
          '${b['bolum_adi'] != null ? ' · ${b['bolum_adi']}' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tarihGoster && tarih.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: DiziRenkler.sari,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tarih,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            // İzlenmiş bölüm: yeşil onay (geçmiş günler artık takvimde)
            if (b['izlendi'] == true) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle, size: 18, color: Colors.green),
            ],
          ],
        ),
        onTap: () => widget.onAc(b),
      ),
    );
  }
}

/// Ay gezinme oku + o yöndeki bölüm sayısı rozeti.
class _AyOku extends StatelessWidget {
  final IconData ikon;
  final int sayi;
  final String tooltip;
  final VoidCallback onTap;

  /// Dar ekranda satır yüksekliğini kısaltmak için düğme 48 → 44 dp
  /// ([takvimGezinmeYuksekligiDar]). 44 dokunma asgarisi; altına İNMEZ.
  final bool sikisik;
  const _AyOku({
    required this.ikon,
    required this.sayi,
    required this.tooltip,
    required this.onTap,
    this.sikisik = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          padding: sikisik ? EdgeInsets.zero : null,
          constraints: sikisik
              ? const BoxConstraints.tightFor(
                  width: takvimGezinmeYuksekligiDar,
                  height: takvimGezinmeYuksekligiDar,
                )
              : null,
          // IconButton varsayılanı tap hedefini 48'e YASTIKLAR; constraints
          // tek başına satırı 44'e indirmiyor. shrinkWrap ile yastık kalkar,
          // dokunma alanını yukarıdaki 44x44 constraints garanti eder.
          style: sikisik
              ? IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )
              : null,
          icon: Icon(ikon, color: DiziRenkler.metin),
        ),
        if (sayi > 0)
          Positioned(
            right: 2,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: DiziRenkler.sari,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                '$sayi',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
