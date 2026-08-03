import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'ortak.dart';

/// Kullanıcı adı deseni (kayıt kuralıyla aynı): 3-20 küçük harf/rakam/nokta/tire/
/// alt çizgi; başta/sonda nokta-tire olmaz ki cümle sonu noktası ada yapışmasın.
final RegExp etiketDeseni = RegExp(r'@([a-z0-9_][a-z0-9_.-]{1,18}[a-z0-9_])');

/// Dizi/film/kişi etiketi: metinde "[[tv:1396|Breaking Bad]]" olarak saklanır;
/// ekranda yalnız ad görünür, dokununca içerik/kişi sayfasına gider.
/// Sunucu değişikliği gerektirmez (düz metin içinde yaşar).
final RegExp icerikEtiketDeseni = RegExp(
  r'\[\[(tv|movie|person):(\d{1,9})\|([^\]|]{1,80})\]\]',
);

/// Metindeki bağlantı deseni: http(s):// ya da www. ile başlayan adresler.
/// Instagram aktarımlarında gönderi metni bağlantı içeriyor ve düz yazı
/// olarak duruyordu; artık dokunulunca dış tarayıcıda açılır.
/// Büyük/küçük harf açık yazıldı: birleşik desen case-SENSITIVE kalmalı,
/// yoksa @Kullanici gibi geçersiz adlar da etiket sanılır.
final RegExp baglantiDeseni = RegExp(
  r'(?:[Hh][Tt][Tt][Pp][Ss]?://|[Ww][Ww][Ww]\.)[^\s<>"]+',
);

/// Adres sonuna yapışan noktalama (cümle sonu, parantez) bağlantıya dahil
/// edilmez: "bak www.a.com." → "www.a.com". Kapanan parantez ancak açılanı
/// yoksa atılır (Wikipedia tarzı adreslerde parantez adresin parçası).
String _baglantiyiKirp(String ham) {
  var s = ham;
  while (s.isNotEmpty) {
    final son = s[s.length - 1];
    if ('.,;:!?’\'"'.contains(son)) {
      s = s.substring(0, s.length - 1);
    } else if (son == ')' && !s.contains('(')) {
      s = s.substring(0, s.length - 1);
    } else {
      break;
    }
  }
  return s;
}

/// Tek geçişte bağlantı + @kullanıcı + [[tur:id|Ad]] etiketlerini yakalar.
/// Bağlantı ÖNCE gelir ki adres içindeki noktalar kullanıcı adı sanılmasın.
final RegExp _tumEtiketler = RegExp(
  '(?<baglanti>${baglantiDeseni.pattern})'
  r'|@(?<kadi>[a-z0-9_][a-z0-9_.-]{1,18}[a-z0-9_])'
  r'|\[\[(?<tur>tv|movie|person):(?<kimlik>\d{1,9})\|(?<ad>[^\]|]{1,80})\]\]',
);

/// Bağlantıyı dış tarayıcıda/uygulamada açar. Açılamazsa sessiz kalmaz.
Future<void> baglantiyiAc(BuildContext context, String ham) async {
  final adres = ham.startsWith('http') ? ham : 'https://$ham';
  try {
    final u = Uri.parse(adres);
    if (await launchUrl(
      u,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    )) {
      return;
    }
  } catch (_) {
    /* geçersiz adres ya da açacak uygulama yok */
  }
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Bağlantı açılamadı'.c)));
  }
}

IconData _turIkonu(String tur) => switch (tur) {
  'tv' => Icons.live_tv_outlined,
  'movie' => Icons.movie_outlined,
  _ => Icons.person_outline,
};

/// Metnin EKRANDA görünen hâli: `[[tv:1396|Breaking Bad]]` → `Breaking Bad`,
/// `www.a.com.` → `www.a.com.` (adres olduğu gibi görünür). Ölçüm için gerek:
/// akış kartı kaç satır sığdığını [TextPainter] ile hesaplarken ham metni
/// ölçseydi etiket işaretlemesi (görünmeyen 15+ karakter) satırları şişirirdi.
String duzMetin(String metin) {
  final tampon = StringBuffer();
  var i = 0;
  for (final m in _tumEtiketler.allMatches(metin)) {
    if (m.start > i) tampon.write(metin.substring(i, m.start));
    if (m.namedGroup('ad') != null) {
      // İçerik etiketi: ekranda ikon + ad görünür (ikon ~1 karakter genişlik)
      tampon.write(' ${m.namedGroup('ad')}');
    } else {
      tampon.write(m[0]);
    }
    i = m.end;
  }
  if (i < metin.length) tampon.write(metin.substring(i));
  return tampon.toString();
}

/// Metindeki @kullanici_adi ve [[tur:id|Ad]] etiketlerini sarı, tıklanır
/// bağlantı olarak gösterir. Kullanıcı etiketi profile, içerik etiketi
/// dizi/film sayfasına, kişi etiketi oyuncu sayfasına gider.
class EtiketliMetin extends StatefulWidget {
  final String metin;
  final TextStyle? stil;

  /// Daima-siyah zeminde mi (Reels)? true → parlak sarı; false → tema-duyarlı
  /// sariMetin (açık temada koyu, kart zemininde okunur).
  final bool koyuZemin;

  /// Verilirse metnin BAŞINA kalın, tıklanır `@kullanici_adi` eklenir
  /// (akış kartının alt bloğu: "kullanıcı adı + yazdığı yorum" tek paragraf).
  final String? onekKullanici;

  /// Satır sınırı: aşan metin `...` ile kırpılır. Akış kartı bunu ekrana
  /// SIĞAN satır sayısıyla doldurur (sabit değer YOK).
  final int? maxLines;
  const EtiketliMetin(
    this.metin, {
    super.key,
    this.stil,
    this.koyuZemin = false,
    this.onekKullanici,
    this.maxLines,
  });

  @override
  State<EtiketliMetin> createState() => _EtiketliMetinState();
}

class _EtiketliMetinState extends State<EtiketliMetin> {
  final List<TapGestureRecognizer> _taniyicilar = [];

  @override
  void dispose() {
    for (final t in _taniyicilar) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final t in _taniyicilar) {
      t.dispose();
    }
    _taniyicilar.clear();

    final taban =
        widget.stil ??
        DefaultTextStyle.of(context).style.copyWith(color: DiziRenkler.metin);
    // TextSpan tema rengini DEVRALMAZ — renkler burada AÇIKÇA verilir.
    final etiketStili = TextStyle(
      color: widget.koyuZemin ? DiziRenkler.sari : DiziRenkler.sariMetin,
      fontWeight: FontWeight.w700,
    );
    final baglantiStili = etiketStili.copyWith(
      decoration: TextDecoration.underline,
      decorationColor: etiketStili.color,
    );
    final metin = widget.metin;
    final parcalar = <InlineSpan>[];
    if (widget.onekKullanici != null) {
      final taniyici = TapGestureRecognizer()
        ..onTap = () => kullaniciyaGit(context, widget.onekKullanici!);
      _taniyicilar.add(taniyici);
      parcalar.add(
        TextSpan(
          text: '@${widget.onekKullanici}  ',
          // Renk AÇIKÇA verilir: TextSpan tema rengini devralmaz.
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: taban.color ?? DiziRenkler.metin,
          ),
          recognizer: taniyici,
        ),
      );
    }
    var i = 0;
    for (final m in _tumEtiketler.allMatches(metin)) {
      if (m.start > i) {
        parcalar.add(TextSpan(text: metin.substring(i, m.start)));
      }
      if (m.namedGroup('baglanti') != null) {
        // http(s)://… veya www.… bağlantısı → dış tarayıcı
        final adres = _baglantiyiKirp(m.namedGroup('baglanti')!);
        if (adres.isEmpty) {
          parcalar.add(TextSpan(text: m[0]));
          i = m.end;
          continue;
        }
        final taniyici = TapGestureRecognizer()
          ..onTap = () => baglantiyiAc(context, adres);
        _taniyicilar.add(taniyici);
        parcalar.add(
          TextSpan(text: adres, style: baglantiStili, recognizer: taniyici),
        );
        // Adrese yapışan noktalama düz metin olarak kalsın
        i = m.start + adres.length;
        continue;
      }
      if (m.namedGroup('kadi') != null) {
        // @kullanıcı etiketi
        final ad = m.namedGroup('kadi')!;
        final taniyici = TapGestureRecognizer()
          ..onTap = () => kullaniciyaGit(context, ad);
        _taniyicilar.add(taniyici);
        parcalar.add(
          TextSpan(text: '@$ad', style: etiketStili, recognizer: taniyici),
        );
      } else {
        // [[tur:id|Ad]] içerik/kişi etiketi
        final tur = m.namedGroup('tur')!;
        final id = m.namedGroup('kimlik')!;
        final ad = m.namedGroup('ad')!;
        final yol = tur == 'person' ? '/kisi/$id' : '/icerik/$tur/$id';
        // Reels/alt sayfa açıkken hedef katmanın ALTINDA kalmasın.
        final taniyici = TapGestureRecognizer()
          ..onTap = () => rotayaGitGuvenli(context, yol);
        _taniyicilar.add(taniyici);
        parcalar.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Icon(
                _turIkonu(tur),
                size: (taban.fontSize ?? 14) + 2,
                color: etiketStili.color,
              ),
            ),
          ),
        );
        parcalar.add(
          TextSpan(text: ad, style: etiketStili, recognizer: taniyici),
        );
      }
      i = m.end;
    }
    if (i < metin.length) parcalar.add(TextSpan(text: metin.substring(i)));
    return Text.rich(
      TextSpan(style: taban, children: parcalar),
      maxLines: widget.maxLines,
      overflow: widget.maxLines == null
          ? TextOverflow.clip
          : TextOverflow.ellipsis,
    );
  }
}

/// @etiketleme otomatik-tamamlaması olan metin girişi.
/// "@" yazıp sürdürünce KULLANICILAR + DİZİ/FİLMLER + KİŞİLER birlikte
/// aranır ve alan ÜSTÜNDE listelenir (yorum kutusu ekranın altında
/// olduğundan öneriler yukarı açılır). Kullanıcı seçilince "@ad ",
/// içerik/kişi seçilince "[[tur:id|Ad]] " eklenir.
class EtiketliGirdi extends StatefulWidget {
  final TextEditingController controller;
  final InputDecoration? decoration;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final Function(String)? onChanged;
  final FocusNode? focusNode;

  const EtiketliGirdi({
    super.key,
    required this.controller,
    this.decoration,
    this.maxLines,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.focusNode,
  });

  @override
  State<EtiketliGirdi> createState() => _EtiketliGirdiState();
}

class _EtiketliGirdiState extends State<EtiketliGirdi> {
  List<Map<String, dynamic>> _oneriler = [];
  Timer? _zaman;
  int _istek = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_dinle);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_dinle);
    _zaman?.cancel();
    super.dispose();
  }

  /// İmlecin hemen solundaki aktif "@kelime"yi döndürür (yoksa null).
  /// Dizi/film adları için boşluk ve büyük harf de kabul edilir
  /// ("@breaking bad" gibi); @ veya satır sonu aramayı bitirir.
  RegExpMatch? _aktifEtiket() {
    final secim = widget.controller.selection;
    if (!secim.isValid || !secim.isCollapsed) return null;
    final metin = widget.controller.text;
    final imlec = secim.baseOffset.clamp(0, metin.length);
    final onces = metin.substring(0, imlec);
    return RegExp(r'@(\S[^@\n\[\]]{0,39})$').firstMatch(onces);
  }

  void _dinle() {
    final eslesme = _aktifEtiket();
    final q = eslesme?.group(1) ?? '';
    if (eslesme == null || q.length < 2) {
      if (_oneriler.isNotEmpty) setState(() => _oneriler = []);
      return;
    }
    _zaman?.cancel();
    _zaman = Timer(const Duration(milliseconds: 250), () => _ara(q));
  }

  Future<List<dynamic>> _kullanicilarGetir(String q) async {
    // Kullanıcı adları küçük harf/rakam/nokta/tire/alt çizgi; boşluklu sorgu kullanıcı olamaz
    final kq = q.toLowerCase().trim();
    if (!RegExp(r'^[a-z0-9_.-]{2,20}$').hasMatch(kq)) return [];
    try {
      return await Api.kullaniciAra(kq);
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> _iceriklerGetir(String q) async {
    try {
      final d = await Api.get('/ara?q=${Uri.encodeQueryComponent(q.trim())}');
      return (d['results'] as List<dynamic>? ?? []);
    } catch (_) {
      return [];
    }
  }

  Future<void> _ara(String q) async {
    final benim = ++_istek;
    final sonuc = await Future.wait([
      _kullanicilarGetir(q),
      _iceriklerGetir(q),
    ]);
    if (!mounted || benim != _istek) return;
    // Kutu hâlâ aynı "@kelime"de mi? (kullanıcı bu arada devam etmiş olabilir)
    if (_aktifEtiket() == null) return;
    final oneriler = <Map<String, dynamic>>[
      for (final k in sonuc[0].take(4))
        {'_tip': 'kullanici', ...(k as Map<String, dynamic>)},
    ];
    var icerikSayi = 0, kisiSayi = 0;
    for (final ham in sonuc[1]) {
      final r = ham as Map<String, dynamic>;
      final mt = r['media_type'] as String?;
      if (mt == 'person' && kisiSayi < 3) {
        final ad = r['name'] as String?;
        if (ad == null || ad.isEmpty) continue;
        kisiSayi++;
        oneriler.add({
          '_tip': 'icerik',
          'tur': 'person',
          'id': r['id'],
          'ad': ad,
          'gorsel': r['profile_path'],
        });
      } else if ((mt == 'tv' || mt == 'movie') && icerikSayi < 4) {
        final ad = (r['name'] ?? r['title']) as String?;
        if (ad == null || ad.isEmpty) continue;
        icerikSayi++;
        final tarih = (r['first_air_date'] ?? r['release_date']) as String?;
        oneriler.add({
          '_tip': 'icerik',
          'tur': mt,
          'id': r['id'],
          'ad': ad,
          'gorsel': r['poster_path'],
          'yil': (tarih != null && tarih.length >= 4)
              ? tarih.substring(0, 4)
              : null,
        });
      }
    }
    setState(() => _oneriler = oneriler);
  }

  /// Aktif "@kelime"yi verilen metinle değiştirir, imleci sonuna taşır.
  void _degistir(String yerine) {
    final eslesme = _aktifEtiket();
    if (eslesme == null) return;
    final metin = widget.controller.text;
    final secim = widget.controller.selection;
    final imlec = secim.baseOffset.clamp(0, metin.length);
    final yeni =
        '${metin.substring(0, eslesme.start)}$yerine ${metin.substring(imlec)}';
    widget.controller.value = TextEditingValue(
      text: yeni,
      selection: TextSelection.collapsed(
        offset: eslesme.start + yerine.length + 1,
      ),
    );
    setState(() => _oneriler = []);
  }

  void _secKullanici(String kullaniciAdi) => _degistir('@$kullaniciAdi');

  void _secIcerik(Map<String, dynamic> o) {
    // Belirteci bozacak karakterleri addan ayıkla
    final ad = (o['ad'] as String).replaceAll(RegExp(r'[\[\]|]'), '').trim();
    if (ad.isEmpty) return;
    _degistir('[[${o['tur']}:${o['id']}|$ad]]');
  }

  Widget _oneriSatiri(Map<String, dynamic> o) {
    if (o['_tip'] == 'kullanici') {
      final av = dosyaUrl(o['avatar'] as String?);
      return ListTile(
        dense: true,
        leading: KullaniciAvatari(
          url: av,
          kullaniciAdi: o['kullanici_adi'] as String?,
          yaricap: 16,
        ),
        title: Text(
          '@${o['kullanici_adi']}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        onTap: () => _secKullanici(o['kullanici_adi'] as String),
      );
    }
    final tur = o['tur'] as String;
    final gorsel = posterUrl(o['gorsel'] as String?, boyut: 'w92');
    final yil = o['yil'] as String?;
    return ListTile(
      dense: true,
      leading: tur == 'person'
          ? CircleAvatar(
              radius: 16,
              backgroundColor: DiziRenkler.koyuGri,
              backgroundImage: gorsel != null
                  ? CachedNetworkImageProvider(gorsel)
                  : null,
              child: gorsel == null
                  ? Icon(Icons.person, size: 16, color: DiziRenkler.metin38)
                  : null,
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 27,
                height: 40,
                child: gorsel != null
                    ? CachedNetworkImage(imageUrl: gorsel, fit: BoxFit.cover)
                    : Container(
                        color: DiziRenkler.koyuGri,
                        child: Icon(
                          _turIkonu(tur),
                          size: 14,
                          color: DiziRenkler.metin38,
                        ),
                      ),
              ),
            ),
      title: Text(
        yil != null ? '${o['ad']} ($yil)' : o['ad'] as String,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      trailing: Icon(_turIkonu(tur), size: 16, color: DiziRenkler.sari),
      onTap: () => _secIcerik(o),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_oneriler.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            constraints: const BoxConstraints(maxHeight: 264),
            decoration: BoxDecoration(
              color: DiziRenkler.kart,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DiziRenkler.metin12),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _oneriler.length,
              itemBuilder: (context, i) => _oneriSatiri(_oneriler[i]),
            ),
          ),
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          maxLength: widget.maxLength,
          onChanged: widget.onChanged,
          buildCounter:
              (_, {required currentLength, maxLength, required isFocused}) =>
                  null,
          decoration: widget.decoration,
        ),
      ],
    );
  }
}
