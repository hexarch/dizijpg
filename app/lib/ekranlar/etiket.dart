import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../tema.dart';
import 'ortak.dart';

/// Kullanıcı adı deseni (kayıt kuralıyla aynı): 3-20 küçük harf/rakam/alt çizgi.
final RegExp etiketDeseni = RegExp(r'@([a-z0-9_]{3,20})');

/// Metindeki @kullanici_adi etiketlerini sarı, tıklanır bağlantı olarak gösterir.
/// Bağlantıya dokununca ilgili profile gider. Diğer metin verilen [stil]'i alır.
class EtiketliMetin extends StatefulWidget {
  final String metin;
  final TextStyle? stil;
  const EtiketliMetin(this.metin, {super.key, this.stil});

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
    final metin = widget.metin;
    final parcalar = <InlineSpan>[];
    var i = 0;
    for (final m in etiketDeseni.allMatches(metin)) {
      if (m.start > i) {
        parcalar.add(TextSpan(text: metin.substring(i, m.start)));
      }
      final ad = m.group(1)!;
      final taniyici = TapGestureRecognizer()
        ..onTap = () => kullaniciyaGit(context, ad);
      _taniyicilar.add(taniyici);
      parcalar.add(
        TextSpan(
          text: '@$ad',
          style: const TextStyle(
            color: DiziRenkler.sari,
            fontWeight: FontWeight.w700,
          ),
          recognizer: taniyici,
        ),
      );
      i = m.end;
    }
    if (i < metin.length) parcalar.add(TextSpan(text: metin.substring(i)));
    return Text.rich(TextSpan(style: taban, children: parcalar));
  }
}

/// @etiketleme otomatik-tamamlaması olan metin girişi.
/// Kullanıcı "@" yazıp sürdürünce eşleşen kullanıcılar alan ÜSTÜNDE listelenir
/// (yorum kutusu ekranın altında olduğundan öneriler yukarı açılır).
/// Seçilince aktif "@kelime" -> "@kullanici_adi " ile değiştirilir.
class EtiketliGirdi extends StatefulWidget {
  final TextEditingController controller;
  final InputDecoration? decoration;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final Function(String)? onChanged;

  const EtiketliGirdi({
    super.key,
    required this.controller,
    this.decoration,
    this.maxLines,
    this.minLines,
    this.maxLength,
    this.onChanged,
  });

  @override
  State<EtiketliGirdi> createState() => _EtiketliGirdiState();
}

class _EtiketliGirdiState extends State<EtiketliGirdi> {
  List<dynamic> _oneriler = [];
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
  RegExpMatch? _aktifEtiket() {
    final secim = widget.controller.selection;
    if (!secim.isValid || !secim.isCollapsed) return null;
    final metin = widget.controller.text;
    final imlec = secim.baseOffset.clamp(0, metin.length);
    final onces = metin.substring(0, imlec);
    return RegExp(r'@([a-z0-9_]{0,20})$').firstMatch(onces);
  }

  void _dinle() {
    final eslesme = _aktifEtiket();
    final q = eslesme?.group(1) ?? '';
    if (eslesme == null || q.length < 2) {
      if (_oneriler.isNotEmpty) setState(() => _oneriler = []);
      return;
    }
    _zaman?.cancel();
    _zaman = Timer(const Duration(milliseconds: 220), () => _ara(q));
  }

  Future<void> _ara(String q) async {
    final benim = ++_istek;
    try {
      final sonuc = await Api.kullaniciAra(q);
      if (!mounted || benim != _istek) return;
      // Kutu hâlâ aynı "@kelime"de mi? (kullanıcı bu arada devam etmiş olabilir)
      final hala = _aktifEtiket();
      if (hala == null) return;
      setState(() => _oneriler = sonuc.take(6).toList());
    } catch (_) {
      /* öneri getirilemezse sessizce boş kalır */
    }
  }

  void _sec(String kullaniciAdi) {
    final eslesme = _aktifEtiket();
    if (eslesme == null) return;
    final metin = widget.controller.text;
    final secim = widget.controller.selection;
    final imlec = secim.baseOffset.clamp(0, metin.length);
    final yeni =
        '${metin.substring(0, eslesme.start)}@$kullaniciAdi ${metin.substring(imlec)}';
    final imlecYeni =
        eslesme.start + kullaniciAdi.length + 2; // @ + ad + boşluk
    widget.controller.value = TextEditingValue(
      text: yeni,
      selection: TextSelection.collapsed(offset: imlecYeni),
    );
    setState(() => _oneriler = []);
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
            constraints: const BoxConstraints(maxHeight: 210),
            decoration: BoxDecoration(
              color: DiziRenkler.kart,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DiziRenkler.metin12),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _oneriler.length,
              itemBuilder: (context, i) {
                final k = _oneriler[i] as Map<String, dynamic>;
                final av = dosyaUrl(k['avatar'] as String?);
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: DiziRenkler.koyuGri,
                    backgroundImage: av != null
                        ? CachedNetworkImageProvider(av)
                        : null,
                    child: av == null
                        ? Icon(
                            Icons.person,
                            size: 16,
                            color: DiziRenkler.metin38,
                          )
                        : null,
                  ),
                  title: Text(
                    '@${k['kullanici_adi']}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () => _sec(k['kullanici_adi'] as String),
                );
              },
            ),
          ),
        TextField(
          controller: widget.controller,
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
