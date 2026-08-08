import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import '../puan.dart';
import '../tema.dart';
import 'giris_istem.dart';

/// Sunucudaki CHECK ile aynı sırada: bayılmış, gülmüş, şaşırmış, üzgün,
/// korkmuş, sıkılmış, ağlamış, mutlu — dizi/film tepkileri.
const tepkiEmojileri = ['😍', '😂', '😮', '😢', '😱', '🥱', '😭', '😄'];

/// Tepki emojisini RENKLİ çizer (sistem emoji fontu; karanlık temada canlı durur).
class TepkiIkonu extends StatelessWidget {
  final String emoji;
  final double boyut;
  final Color? renk; // artık kullanılmıyor (emoji kendi renginde) — uyumluluk

  const TepkiIkonu(this.emoji, {super.key, this.boyut = 20, this.renk});

  @override
  Widget build(BuildContext context) {
    return Text(emoji, style: TextStyle(fontSize: boyut, height: 1.1));
  }
}

/// 8 ikonlu tepki satırı: dizi/film geneli (sezon=null) veya tek bölüm.
class TepkiSatiri extends StatefulWidget {
  final String tur;
  final int tmdbId;
  final int? sezon;
  final int? bolum;

  const TepkiSatiri({
    super.key,
    required this.tur,
    required this.tmdbId,
    this.sezon,
    this.bolum,
  });

  @override
  State<TepkiSatiri> createState() => _TepkiSatiriState();
}

class _TepkiSatiriState extends State<TepkiSatiri> {
  Map<String, int> _sayilar = {};
  String? _benim;
  bool _isleniyor = false;

  String get _sorgu => widget.sezon != null
      ? '?sezon=${widget.sezon}&bolum=${widget.bolum}'
      : '';

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final d = await Api.get(
        '/tepkiler/${widget.tur}/${widget.tmdbId}$_sorgu',
      );
      if (!mounted) return;
      _uygula(d as Map<String, dynamic>);
    } catch (_) {}
  }

  void _uygula(Map<String, dynamic> d) {
    setState(() {
      _sayilar = ((d['sayilar'] as Map<String, dynamic>? ?? {})).map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      );
      _benim = d['benim'] as String?;
    });
  }

  Future<void> _sec(String emoji) async {
    // `/tepki` girisZorunlu: oturumsuzda iyimser güncelleme yapıp 401 ile geri
    // almak yerine hiç başlamayız; kullanıcı doğrudan giriş istemini görür.
    if (!girisGerekli(context)) return;
    if (_isleniyor) return;
    setState(() => _isleniyor = true);
    final yeni = _benim == emoji ? null : emoji;
    // İyimser güncelleme
    setState(() {
      if (_benim != null) {
        _sayilar[_benim!] = (_sayilar[_benim!] ?? 1) - 1;
      }
      if (yeni != null) _sayilar[yeni] = (_sayilar[yeni] ?? 0) + 1;
      _benim = yeni;
    });
    try {
      final d = await Api.post('/tepki', {
        'tmdb_id': widget.tmdbId,
        'tur': widget.tur,
        if (widget.sezon != null) 'sezon': widget.sezon,
        if (widget.sezon != null) 'bolum': widget.bolum,
        'emoji': yeni,
      });
      if (!mounted) return;
      _uygula(d as Map<String, dynamic>);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
      _yukle();
    } finally {
      if (mounted) setState(() => _isleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final e in tepkiEmojileri)
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _sec(e),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                // Seçili: sarı-tint dolgu + sarı kenar (renkli emoji kaybolmasın)
                color: _benim == e
                    ? DiziRenkler.sari.withValues(alpha: 0.20)
                    : DiziRenkler.kart,
                borderRadius: BorderRadius.circular(20),
                border: _benim == e
                    ? Border.all(color: DiziRenkler.sari, width: 1.5)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TepkiIkonu(e, boyut: 20),
                  if ((_sayilar[e] ?? 0) > 0) ...[
                    const SizedBox(width: 5),
                    Text(
                      '${_sayilar[e]}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _benim == e
                            ? DiziRenkler.sariMetin
                            : DiziRenkler.metin70,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Doğrudan tıklanan 5 yıldızlık puan satırı (sheet açmadan kaydeder).
///
/// ÖLÇEK: sunucuda puan 1-10 tutulur, kullanıcı 5 yıldız görür. Dönüşüm
/// BURADA YAPILMAZ — `lib/puan.dart`taki `yildiza()`/`dbPuani()` TEK KAYNAKTIR
/// (7 Ağu 2026 SEO denetimi: altı dosyada kopyalanan `/2` hesabı sunucu
/// çıktısıyla uygulamayı ayrıştırmıştı).
///
/// HEDEF (8 Ağu 2026-d): `sezon`+`bolum` verilirse puan O BÖLÜME, verilmezse
/// dizi/film/kişi GENELİNE yazılır — `TepkiSatiri` ve yorumlarla aynı
/// sözleşme. İkisi sunucuda AYRI satırdır, birbirine karışmaz.
class YildizPuan extends StatefulWidget {
  final String tur;
  final int tmdbId;
  final int? sezon;
  final int? bolum;
  final int? baslangicPuan; // sunucu ölçeği (1-10)
  final double boyut;

  /// Kaydetme BAŞARILI olduğunda çağrılır: (yıldız 0-5, sunucu yanıtı).
  /// 0 = puan silindi. Üst blok ortalamayı tazelemek ve sunucunun bildirdiği
  /// yan etkiyi (bölüm "izlendi" işaretlendi) göstermek için kullanır.
  final void Function(int yildiz, Map<String, dynamic> yanit)? kaydedildi;

  const YildizPuan({
    super.key,
    required this.tur,
    required this.tmdbId,
    this.sezon,
    this.bolum,
    this.baslangicPuan,
    this.boyut = 30,
    this.kaydedildi,
  });

  @override
  State<YildizPuan> createState() => _YildizPuanState();
}

class _YildizPuanState extends State<YildizPuan> {
  late int _yildiz = yildiza(widget.baslangicPuan);
  bool _isleniyor = false;

  @override
  void didUpdateWidget(YildizPuan eski) {
    super.didUpdateWidget(eski);
    if (eski.baslangicPuan != widget.baslangicPuan && !_isleniyor) {
      _yildiz = yildiza(widget.baslangicPuan);
    }
  }

  Future<void> _sec(int yildiz) async {
    // `/puan` girisZorunlu: oturumsuzda iyimser güncelleme yapıp 401 ile geri
    // almak yerine hiç başlamayız — kullanıcı doğrudan giriş istemini görür
    // (`TepkiSatiri._sec` ile aynı kural; burada 8 Ağu 2026'ya kadar eksikti).
    if (!girisGerekli(context)) return;
    if (_isleniyor) return;
    final eski = _yildiz;
    final yeni = yildiz == _yildiz ? 0 : yildiz; // aynı yıldıza basınca sil
    setState(() {
      _yildiz = yeni;
      _isleniyor = true;
    });
    try {
      final d = await Api.post('/puan', {
        'tmdb_id': widget.tmdbId,
        'tur': widget.tur,
        // Bölüm hedefi ikisi birden gider ya da hiç gitmez (sunucu sözleşmesi).
        if (widget.sezon != null) 'sezon': widget.sezon,
        if (widget.sezon != null) 'bolum': widget.bolum,
        'puan': yeni == 0 ? null : dbPuani(yeni),
      });
      if (!mounted) return;
      widget.kaydedildi?.call(
        yeni,
        d is Map<String, dynamic> ? d : const <String, dynamic>{},
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _yildiz = eski);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var y = 1; y <= 5; y++)
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _sec(y),
            // DOKUNMA HEDEFİ: 30 dp ikon + 2x7 dp yatay pay = 44 dp; dikeyde
            // 30 + 2x8 = 46 dp. Eski 2x4 pay 38 dp veriyordu, yani asgari
            // 44x44'ün ALTINDA (ui-ux-pro-max "Touch Target Size", High).
            // Yıldızlar arasında BİLEREK boşluk yok: puan şeridi tek bir
            // ölçektir, komşu hedefler arası 8 dp kuralı ayrı EYLEMLERİ olan
            // butonlar içindir; boşluk bırakmak ölçeği kesikli gösterirdi.
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
              child: Icon(
                y <= _yildiz ? Icons.star_rounded : Icons.star_outline_rounded,
                size: widget.boyut,
                color: y <= _yildiz ? DiziRenkler.sari : DiziRenkler.metin38,
              ),
            ),
          ),
      ],
    );
  }
}

/// Bölüm puanı bloğu: etiket + 5 yıldız + topluluk ortalaması.
///
/// NEDEN AYRI WIDGET: bölüm sayfası (`bolum.dart`) ve takvimin bölüm modalı
/// (`takvim.dart/BolumModali`) AYNI şeyi göstermeli. İki yerde iki kopya
/// olsaydı biri sezon/bolum göndermeyi unutup puanı sessizce DİZİ GENELİNE
/// yazardı — takvim modalında 8 Ağu 2026'ya kadar tam olarak bu oluyordu
/// (modaldaki yıldızlar bölüme değil dizinin tamamına puan veriyordu).
class BolumPuani extends StatefulWidget {
  final int tmdbId;
  final int sezon;
  final int bolum;

  /// Sunucu "bölümü izledim olarak işaretledim" dediğinde çağrılır.
  /// Yan etki SESSİZ kalmamalı: üst ekran "İzledin" butonunu günceller.
  final VoidCallback? izlendiIsaretlendi;

  const BolumPuani({
    super.key,
    required this.tmdbId,
    required this.sezon,
    required this.bolum,
    this.izlendiIsaretlendi,
  });

  @override
  State<BolumPuani> createState() => _BolumPuaniState();
}

class _BolumPuaniState extends State<BolumPuani> {
  int? _benim; // sunucu ölçeği (1-10)
  num? _ortalama; // sunucu ölçeği (1-10)
  int _adet = 0;
  bool _yuklendi = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final d = await Api.get(
        '/bolum-puanlari/${widget.tmdbId}/${widget.sezon}',
      );
      if (!mounted) return;
      final b = (d is Map ? d['bolumler'] : null) as Map<String, dynamic>?;
      final bu = b?['${widget.bolum}'] as Map<String, dynamic>?;
      setState(() {
        _benim = (bu?['benim'] as num?)?.toInt();
        _ortalama = puanSayisi(bu?['ortalama']);
        _adet = (bu?['adet'] as num?)?.toInt() ?? 0;
        _yuklendi = true;
      });
    } catch (_) {
      // Ortalama süs veridir; gelmezse yıldızlar yine de çalışsın.
      if (mounted) setState(() => _yuklendi = true);
    }
  }

  void _kaydedildi(int yildiz, Map<String, dynamic> yanit) {
    setState(() => _benim = yildiz == 0 ? null : dbPuani(yildiz));
    if (yanit['izlendi'] == true) widget.izlendiIsaretlendi?.call();
    _yukle(); // ortalama + sayaç tazelensin
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          _benim == null ? 'Bu bölüme puan ver'.c : 'Puanın'.c,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: DiziRenkler.metin70,
          ),
        ),
        // YÜKSEKLİK REZERVASYONU: yıldızlar veri gelmeden de çizilir, yalnız
        // başlangıç puanı sonradan dolar. Blok hiç yer değiştirmez (CLS yok).
        YildizPuan(
          tur: 'tv',
          tmdbId: widget.tmdbId,
          sezon: widget.sezon,
          bolum: widget.bolum,
          baslangicPuan: _benim,
          kaydedildi: _kaydedildi,
        ),
        // Sabit yükseklik: ortalama satırı sonradan gelince blok zıplamasın.
        SizedBox(
          height: 22,
          child: _yuklendi && _adet > 0
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: DiziRenkler.sari,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        // Dizi kartındaki rozetle AYNI biçim ve AYNI ölçek
                        // dönüşümü (puan.dart) — 10'luk değer BASILMAZ.
                        '{} dizi.jpg'.cf([yildizOrtalamaMetni(_ortalama)]),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '{} kişi puanladı'.cf([_adet]),
                      style: TextStyle(
                        fontSize: 12,
                        color: DiziRenkler.metin54,
                      ),
                    ),
                  ],
                )
              : null,
        ),
      ],
    );
  }
}
