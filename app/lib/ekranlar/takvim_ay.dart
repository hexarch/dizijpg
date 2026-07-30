import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';

/// Ay-takvimi görünümü: bölümler yayın tarihlerine göre ay ızgarasında;
/// bir güne dokununca o günün bölümleri altta listelenir.
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

  @override
  Widget build(BuildContext context) {
    final yerel = MaterialLocalizations.of(context);
    final gunler = _gunlereBol();
    final ilkGun = DateTime(_ay.year, _ay.month, 1);
    final gunSayisi = DateTime(_ay.year, _ay.month + 1, 0).day;
    final haftaBasi = yerel.firstDayOfWeekIndex; // 0=Pazar
    final oncesi = (ilkGun.weekday % 7 - haftaBasi + 7) % 7;
    final bugun = DateTime.now();
    final narrow = yerel.narrowWeekdays; // 0=Pazar
    final basliklar = [for (var i = 0; i < 7; i++) narrow[(haftaBasi + i) % 7]];
    final seciliBolumler = gunler[_anahtar(_secili)] ?? [];

    // Diğer aylardaki bölüm sayıları (kullanıcı ileri/geri kaydırmayı görsün)
    final ayKey =
        '${_ay.year.toString().padLeft(4, '0')}-'
        '${_ay.month.toString().padLeft(2, '0')}';
    var oncekiSayi = 0, sonrakiSayi = 0;
    gunler.forEach((t, liste) {
      final mk = t.substring(0, 7);
      if (mk.compareTo(ayKey) < 0) {
        oncekiSayi += liste.length;
      } else if (mk.compareTo(ayKey) > 0) {
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

    return Column(
      children: [
        // Ay başlığı + gezinme (oklarda o yöndeki bölüm sayısı rozeti)
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
          child: Row(
            children: [
              _AyOku(
                ikon: Icons.chevron_left,
                sayi: oncekiSayi,
                tooltip: 'Önceki ay'.c,
                onTap: () =>
                    setState(() => _ay = DateTime(_ay.year, _ay.month - 1, 1)),
              ),
              Expanded(
                child: Text(
                  yerel.formatMonthYear(_ay),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: DiziRenkler.metin,
                  ),
                ),
              ),
              _AyOku(
                ikon: Icons.chevron_right,
                sayi: sonrakiSayi,
                tooltip: 'Sonraki ay'.c,
                onTap: () =>
                    setState(() => _ay = DateTime(_ay.year, _ay.month + 1, 1)),
              ),
            ],
          ),
        ),
        // Hafta başlıkları
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              for (final b in basliklar)
                Expanded(
                  child: Center(
                    child: Text(
                      b,
                      style: TextStyle(
                        fontSize: 12,
                        color: DiziRenkler.metin70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Gün ızgarası
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.82,
            ),
            itemCount: oncesi + gunSayisi,
            itemBuilder: (context, i) {
              if (i < oncesi) return const SizedBox();
              final gun = i - oncesi + 1;
              final tarih = DateTime(_ay.year, _ay.month, gun);
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
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: secili
                        ? DiziRenkler.sari.withValues(alpha: 0.18)
                        : null,
                    borderRadius: BorderRadius.circular(10),
                    border: buGun
                        ? Border.all(color: DiziRenkler.sari, width: 1.5)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$gun',
                        style: TextStyle(
                          fontWeight: secili
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: sayi > 0
                              ? DiziRenkler.metin
                              : DiziRenkler.metin54,
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (sayi > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: DiziRenkler.sari,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$sayi',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 13),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 20),
        // Seçili günün bölümleri (boşsa "sıradaki bölüm" gösterilir)
        Expanded(
          child: seciliBolumler.isEmpty
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  children: [
                    Text(
                      'Bu gün bölüm yok'.c,
                      style: TextStyle(color: DiziRenkler.metin54),
                    ),
                    if (sonrakiOlay != null) ...[
                      const SizedBox(height: 18),
                      Text(
                        'Sıradaki bölüm'.c,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: DiziRenkler.metin54,
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
                ),
        ),
      ],
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
                : CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover),
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
  const _AyOku({
    required this.ikon,
    required this.sayi,
    required this.tooltip,
    required this.onTap,
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
          icon: Icon(ikon, color: DiziRenkler.metin70),
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
