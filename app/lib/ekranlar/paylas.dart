import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'ortak.dart';

/// Gönderi paylaşma sayfası: üstte kişilere (mesajlaştıkların, takip
/// ettiklerin, takipçilerin) DM ile gönder, altta telefonun kendi paylaşım
/// sayfası (WhatsApp, e-posta, Instagram...) ve bağlantıyı kopyala.
Future<void> paylasSheet(
  BuildContext context, {
  required String url,
  String? metin,
  int? yorumId, // verilirse DM'e bağlantı değil GÖNDERİNİN KENDİSİ gider
}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: DiziRenkler.koyuGri,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (_) => _PaylasSheet(url: url, metin: metin, yorumId: yorumId),
);

class _PaylasSheet extends StatefulWidget {
  final String url;
  final String? metin;
  final int? yorumId;
  const _PaylasSheet({required this.url, this.metin, this.yorumId});

  @override
  State<_PaylasSheet> createState() => _PaylasSheetState();
}

class _PaylasSheetState extends State<_PaylasSheet> {
  List<dynamic>? _kisiler;
  String? _hata;
  final _gonderilen = <int>{}; // DM gönderilen kullanıcı id'leri
  final _gonderiliyor = <int>{};

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final d = await Api.get('/paylas-hedefler');
      if (mounted) {
        setState(() => _kisiler = d['kullanicilar'] as List<dynamic>? ?? []);
      }
    } catch (e) {
      if (mounted) setState(() => _hata = e.toString());
    }
  }

  Future<void> _dmGonder(Map<String, dynamic> k) async {
    final id = (k['id'] as num).toInt();
    if (_gonderilen.contains(id) || _gonderiliyor.contains(id)) return;
    setState(() => _gonderiliyor.add(id));
    try {
      await Api.post('/mesajlar', {
        'kullanici_adi': k['kullanici_adi'],
        // Gönderi paylaşımında link DEĞİL postun kendisi gider: sohbette
        // kart görünür, dokununca Reels'te açılır.
        if (widget.yorumId != null) 'yorum_id': widget.yorumId,
        if (widget.yorumId == null) 'metin': widget.url,
      });
      if (!mounted) return;
      setState(() {
        _gonderiliyor.remove(id);
        _gonderilen.add(id);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _gonderiliyor.remove(id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _kopyala() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Kopyalandı: {}'.cf([widget.url]))));
  }

  /// Telefonun paylaşım sayfası: WhatsApp, e-posta, Instagram, Facebook...
  Future<void> _sistemPaylas() async {
    final messenger = ScaffoldMessenger.of(context);
    final gonderi = widget.metin?.trim();
    final govde = (gonderi == null || gonderi.isEmpty)
        ? widget.url
        : '$gonderi\n\n${widget.url}';
    try {
      await Share.share(govde);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      // Paylaşım sayfası açılamadıysa (ör. masaüstü web) panoya kopyala
      await Clipboard.setData(ClipboardData(text: widget.url));
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Kopyalandı: {}'.cf([widget.url]))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: DiziRenkler.metin24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Row(
              children: [
                Icon(Icons.send_outlined, size: 20, color: DiziRenkler.sari),
                const SizedBox(width: 8),
                Text(
                  'Paylaş'.c,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          // Kişiler: dokununca DM olarak gönderilir
          SizedBox(
            height: 132,
            child: _hata != null
                ? Center(
                    child: Text(
                      _hata!,
                      style: TextStyle(color: DiziRenkler.metin54),
                    ),
                  )
                : _kisiler == null
                ? const Center(
                    child: CircularProgressIndicator(color: DiziRenkler.sari),
                  )
                : _kisiler!.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Henüz kimseyi takip etmiyorsun.'.c,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: DiziRenkler.metin54),
                      ),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: _kisiler!.length,
                    itemBuilder: (context, i) {
                      final k = _kisiler![i] as Map<String, dynamic>;
                      final id = (k['id'] as num).toInt();
                      final avatar = dosyaUrl(k['avatar'] as String?);
                      final gonderildi = _gonderilen.contains(id);
                      final gidiyor = _gonderiliyor.contains(id);
                      return SizedBox(
                        width: 84,
                        child: InkWell(
                          onTap: () => _dmGonder(k),
                          borderRadius: BorderRadius.circular(12),
                          child: Column(
                            children: [
                              const SizedBox(height: 8),
                              Stack(
                                children: [
                                  KullaniciAvatari(
                                    url: avatar,
                                    kullaniciAdi: k['kullanici_adi'] as String?,
                                    yaricap: 28,
                                    arkaplan: DiziRenkler.kart,
                                  ),
                                  if (gonderildi || gidiyor)
                                    Positioned.fill(
                                      child: DecoratedBox(
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: gidiyor
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: DiziRenkler.sari,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.check,
                                                  color: DiziRenkler.sari,
                                                ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '@${k['kullanici_adi']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                              if (gonderildi)
                                Text(
                                  'Gönderildi'.c,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: DiziRenkler.sariMetin,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Divider(color: DiziRenkler.metin12, height: 20),
          // Telefonun paylaşım sayfası + bağlantıyı kopyala
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (!kIsWeb)
                _PaylasDugme(
                  ikon: Icons.ios_share,
                  etiket: 'Diğer uygulamalar'.c,
                  onTap: _sistemPaylas,
                ),
              _PaylasDugme(
                ikon: Icons.link,
                etiket: 'Bağlantıyı kopyala'.c,
                onTap: _kopyala,
              ),
            ],
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _PaylasDugme extends StatelessWidget {
  final IconData ikon;
  final String etiket;
  final VoidCallback onTap;
  const _PaylasDugme({
    required this.ikon,
    required this.etiket,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: DiziRenkler.kart,
              child: Icon(ikon, color: DiziRenkler.sari),
            ),
            const SizedBox(height: 8),
            Text(etiket, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
