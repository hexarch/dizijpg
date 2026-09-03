/// İZLEME ODASI — Mesajlar başlığındaki "+" düğmesinin modalı.
///
/// Kullanıcı isteği (3 Eyl 2026, birebir): *"mesajlar kısmında isteklerin
/// yanına + iconu koy tıklayınca modal aç oda oluştur odaya katıl olsun"*.
///
/// ---------------------------------------------------------------------------
/// MODALIN ÜÇ BÖLÜMÜ ve SIRASI
/// ---------------------------------------------------------------------------
///   1. **Davetler ve açık odalarım** — en üstte, çünkü kullanıcı buraya çoğu
///      zaman "beni davet ettiler" ya da "odama dönüyorum" diye gelir. Bir
///      davet varken önce "Oda oluştur" düğmesini göstermek, kullanıcıyı
///      ikinci bir oda açmaya iterdi (ki sunucu buna zaten izin vermez).
///   2. **Odaya katıl** — 6 haneli kod alanı.
///   3. **Oda oluştur** — en altta: en az sık yapılan ama en "büyük" eylem.
///
/// Liste boşken sıra tersine döner: elde bir şey yokken önce ne
/// YAPABİLECEĞİNİ göstermek gerekir (ui-ux-pro-max, Feedback/Empty States —
/// "Show helpful message and action", boş beyaz alan DEĞİL).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../ekranlar/ortak.dart';
import '../tema.dart';
import 'oda_api.dart';

/// "+" düğmesinin modalını açar. Bir odaya girildiyse o odaya yönlendirir.
Future<void> odaSheetAc(BuildContext context) async {
  final id = await showModalBottomSheet<int>(
    context: context,
    backgroundColor: DiziRenkler.koyuGri,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const OdaSheetGovdesi(),
  );
  if (id == null || !context.mounted) return;
  context.push('/oda/$id');
}

/// Modalın GÖVDESİ — [odaSheetAc] bunu `showModalBottomSheet` içinde kurar.
///
/// HERKESE AÇIK, çünkü widget testi onu TEK BAŞINA kurmak zorunda:
/// [odaSheetAc] dönen id ile `context.push('/oda/<id>')` çağırıyor, yani
/// testte kullanmak GoRouter kurmayı gerektirirdi ve test asıl sınamak
/// istediğimiz şeyi (davet satırına dokununca ÖNCE katılım) gezinme
/// altyapısının arkasına saklardı.
class OdaSheetGovdesi extends StatefulWidget {
  const OdaSheetGovdesi({super.key});

  @override
  State<OdaSheetGovdesi> createState() => _OdaSheetState();
}

class _OdaSheetState extends State<OdaSheetGovdesi> {
  final _kod = TextEditingController();
  List<OdaOzet>? _odalar;
  String? _hata;
  bool _mesgul = false;

  /// Şu an katılım isteği uçan DAVET satırının oda id'si (yoksa null).
  /// Satırda spinner çizmek ve çift dokunuşu engellemek için.
  int? _katilanOda;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _kod.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    try {
      final l = await OdaApi.listem();
      if (mounted) setState(() => _odalar = l);
    } on ApiHata catch (e) {
      if (mounted) setState(() => _hata = e.mesaj.c);
    }
  }

  void _uyar(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _katil() async {
    final kod = _kod.text.trim();
    if (kod.length < 6) {
      _uyar('Oda kodu 6 karakter olmalı'.c);
      return;
    }
    setState(() => _mesgul = true);
    try {
      final oda = await OdaApi.katil(kod);
      if (mounted) Navigator.pop(context, oda.id);
    } on ApiHata catch (e) {
      if (mounted) {
        setState(() => _mesgul = false);
        _uyar(odaHataMetni(e));
      }
    }
  }

  /// Listedeki bir satıra dokunulduğunda.
  ///
  /// ===========================================================================
  /// NEDEN DAVET SATIRI DOĞRUDAN AÇILAMAZ (4 Eyl 2026, canlıda yakalandı)
  /// ===========================================================================
  /// Kullanıcı bildirdi: *"+ tıklayıp odaya katıl dediğimde bu odanın üyesi
  /// değilsin diyor"*. Satır doğrudan `/oda/:id`e gidiyordu; ama BEKLEYEN
  /// DAVETTE kişi henüz üye DEĞİL (`oda_uyeler.katildi IS NULL`) ve sunucudaki
  /// `odaKapisi` haklı olarak 403 `UYE_DEGIL` döndürüyordu. Sunucu doğruydu,
  /// eksik olan istemciydi: davet bir ÇAĞRIDIR, kabul edilmeden üyelik olmaz.
  ///
  /// Artık davet satırı ÖNCE `POST /odalar/katil` ile kabul edilir (satırda
  /// oda kodu zaten var), sonra oda açılır. Zaten üye olunan satırlarda
  /// davranış AYNEN eskisi gibi: tek dokunuş, doğrudan açılır.
  Future<void> _satiraDokun(OdaOzet o) async {
    if (!o.davet) {
      Navigator.pop(context, o.id);
      return;
    }
    if (_katilanOda != null) return; // çift dokunuş
    setState(() => _katilanOda = o.id);
    try {
      final oda = await OdaApi.katil(o.kod);
      if (mounted) Navigator.pop(context, oda.id);
    } on ApiHata catch (e) {
      if (!mounted) return;
      setState(() => _katilanOda = null);
      // Oda dolu / kapandı / engelli hâlleri buradan geçer; modal AÇIK kalır
      // ki kullanıcı öteki odalarına ya da kod alanına dönebilsin.
      _uyar(odaHataMetni(e));
      _yukle(); // liste bayatlamış olabilir (oda kapanmış olabilir)
    }
  }

  Future<void> _olustur() async {
    setState(() => _mesgul = true);
    try {
      final oda = await OdaApi.olustur();
      if (mounted) Navigator.pop(context, oda.id);
    } on ApiHata catch (e) {
      if (!mounted) return;
      setState(() => _mesgul = false);
      // ZATEN AÇIK ODA VAR: hata basıp bırakmak çıkışsız olurdu — kullanıcı
      // odasının nerede olduğunu bilmiyor. Sunucu odanın id'sini yanıtta
      // veriyor, doğrudan oraya götürüyoruz.
      final mevcut = (e.govde?['oda'] as num?)?.toInt();
      if (e.makineKodu == OdaKod.odaZatenVar && mevcut != null) {
        Navigator.pop(context, mevcut);
        return;
      }
      _uyar(odaHataMetni(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final liste = _odalar ?? const <OdaOzet>[];
    final bosMu = _odalar != null && liste.isEmpty;
    return SafeArea(
      // `bottom: false` DEĞİL: modal ekranın altına oturuyor ve klavye
      // kapalıyken çentik/gezinme çubuğu düğmeyi yutabilir.
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.groups_2_outlined,
                    color: DiziRenkler.sariMetin,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Birlikte izle'.c,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Bir video yükle, arkadaşlarını davet et, aynı anda izleyin.'.c,
                style: TextStyle(fontSize: 13, color: DiziRenkler.metin54),
              ),
              const SizedBox(height: 16),
              if (_hata != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _hata!,
                    style: TextStyle(color: DiziRenkler.ilerlemeKirmizi),
                  ),
                ),
              if (_odalar == null && _hata == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: IskeletSatir(),
                ),
              if (liste.isNotEmpty) ...[
                for (final o in liste)
                  _OdaSatiri(
                    key: ValueKey(o.id),
                    oda: o,
                    katiliyor: _katilanOda == o.id,
                    onTap: () => _satiraDokun(o),
                  ),
                const SizedBox(height: 8),
                Divider(color: DiziRenkler.metin38.withValues(alpha: 0.25)),
                const SizedBox(height: 8),
              ],
              if (bosMu)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Henüz bir odan ya da davetin yok.'.c,
                    style: TextStyle(fontSize: 13, color: DiziRenkler.metin54),
                  ),
                ),
              // ---- Odaya katıl ----
              Text(
                'Odaya katıl'.c,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _kod,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 6,
                      // Kod alfabesinde I, O, 0, 1 YOK (karışmasınlar diye);
                      // süzgeç de onları almaz, kullanıcı yazarken anlar.
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp('[A-HJ-NP-Za-hj-np-z2-9]'),
                        ),
                      ],
                      decoration: InputDecoration(
                        hintText: 'Oda kodu'.c,
                        counterText: '',
                        prefixIcon: const Icon(
                          Icons.vpn_key_outlined,
                          size: 20,
                        ),
                      ),
                      onSubmitted: (_) => _mesgul ? null : _katil(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _mesgul ? null : _katil,
                      child: Text('Katıl'.c),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // ---- Oda oluştur ----
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _mesgul ? null : _olustur,
                  icon: _mesgul
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_circle_outline, size: 20),
                  label: Text('Oda oluştur'.c),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Odalar 12 saat sonra kendiliğinden kapanır ve video silinir.'
                    .c,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: DiziRenkler.metin38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Liste satırı: bir davet ya da içinde olduğum bir oda.
class _OdaSatiri extends StatelessWidget {
  final OdaOzet oda;
  final VoidCallback onTap;

  /// Bu satır için katılım isteği uçuyor: spinner çizilir ve dokunma kapanır
  /// (üç hal kuralı — yükleniyor / başarı / hata; sessiz bekleme yasak).
  final bool katiliyor;

  const _OdaSatiri({
    super.key,
    required this.oda,
    required this.onTap,
    this.katiliyor = false,
  });

  @override
  Widget build(BuildContext context) {
    final kalan = oda.biter - DateTime.now().millisecondsSinceEpoch;
    return InkWell(
      onTap: katiliyor ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        // Dokunma alanı 44 dp'nin altına düşmesin (ui-ux-pro-max, Touch Target).
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            KullaniciAvatari(
              url: dosyaUrl(oda.sahipAvatar),
              kullaniciAdi: oda.sahip,
              yaricap: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    oda.baslik?.isNotEmpty == true
                        ? oda.baslik!
                        : (oda.sahibiMiyim
                              ? 'Odam'.c
                              : '@{} odası'.cf([oda.sahip])),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (oda.davet) 'Seni davet etti'.c,
                      '{} kişi'.cf([oda.uyeSayisi]),
                      if (!oda.videoVar) 'Video yok'.c,
                      if (kalan > 0) '{} kaldı'.cf([odaSureKisa(kalan)]),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: DiziRenkler.metin54),
                  ),
                ],
              ),
            ),
            if (oda.davet)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  // Marka sarısı, kırmızı DEĞİL: davet bir alarm değil,
                  // düşük öncelikli bir çağrı (istek rozetiyle aynı gerekçe).
                  color: DiziRenkler.sari.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Davet'.c,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: DiziRenkler.sariMetin,
                  ),
                ),
              ),
            if (katiliyor)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Icon(Icons.chevron_right, color: DiziRenkler.metin38),
          ],
        ),
      ),
    );
  }
}
