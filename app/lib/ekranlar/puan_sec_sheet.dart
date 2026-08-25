/// GENİŞ ÖLÇEK PUAN SEÇİCİ (kullanıcı isteği, 26 Ağu 2026).
///
/// ---------------------------------------------------------------------------
/// NEDEN VAR
/// ---------------------------------------------------------------------------
/// Kullanıcı puan ölçeğini 5-100 arasında seçebiliyor. 50 ya da 100 yıldızı
/// satır hâlinde çizmek fiziksel olarak mümkün değil: 100 dokunma hedefi
/// 360 dp'ye sığmaz, sığdırılsa her biri ~3 dp olur ve hiçbiri isabetle
/// dokunulamaz. Kullanıcının kendi çözümü de buydu — *"100 yıldızda ux
/// bozulacağı alanlar olacak, o yüzden 10 üzerine tıklayınca açılan divde
/// gösterirsin"*.
///
/// Eşik `yildizSatiriOlur()` ile TEK YERDE tanımlı (lib/puan.dart): 10 ve altı
/// satır, üstü bu sayfa.
///
/// ---------------------------------------------------------------------------
/// TASARIM KARARLARI (ui-ux-pro-max: Forms & Input + Touch & Interaction)
/// ---------------------------------------------------------------------------
///  * BİRİNCİL GİRDİ KAYDIRICI (Slider), yıldız ızgarası değil. 100 hedefli bir
///    ızgarada isabet oranı düşük; kaydırıcı tek parmakla tüm aralığı gezer ve
///    Flutter'ın kendi dokunma hedefi zaten ≥44 dp.
///  * ±1 DÜĞMELERİ: kaydırıcı son bir birimi tutturmakta zorlar ("73 mü 74 mü").
///    İnce ayar için iki büyük düğme; ikisi de 44 dp.
///  * DEV SAYI: seçimin kendisi ekranın en büyük öğesi. Kaydırırken canlı
///    değişir, kullanıcı parmağının altındaki küçük tırnağa bakmak zorunda
///    kalmaz.
///  * YILDIZ ÖNİZLEMESİ: 5 yıldızlık evrensel karşılık (73/100 ≈ 3,7 yıldız)
///    altta gösterilir — sayı tek başına "iyi mi kötü mü" hissi vermiyor.
///  * SIL AYRI VE KIRMIZI: yıkıcı eylem birincil eylemin yanında ama farklı
///    ağırlıkta. Puanı olmayan kullanıcıya HİÇ gösterilmez.
///  * Kaydetme üç halli: kilit + spinner → kapanış / SnackBar (skill md. 3).
library;

import 'package:flutter/material.dart';

import '../ceviri.dart';
import '../tema.dart';
import 'ortak.dart' show altGuvenli;

/// Geniş ölçekte puan seçtirir.
///
/// [mevcut] ve dönüş değeri GÖRÜNÜM ölçeğindedir (0..N); 0 = puan yok/silindi.
/// `null` döner = kullanıcı vazgeçti (hiçbir şey yazılmamalı).
Future<int?> puanSecSheet(
  BuildContext context, {
  required int olcek,
  int mevcut = 0,
  String? baslik,
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: DiziRenkler.koyuGri,
    // İçerik sabit ve kısa; tavanı kaldırmak yeterli (puan_dagilimi.dart'taki
    // aynı gerekçe: 9/16 varsayılanı büyük yazı ölçeğinde alttan keserdi).
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) =>
        _PuanSecGovde(olcek: olcek, mevcut: mevcut, baslik: baslik),
  );
}

class _PuanSecGovde extends StatefulWidget {
  final int olcek;
  final int mevcut;
  final String? baslik;
  const _PuanSecGovde({required this.olcek, required this.mevcut, this.baslik});

  @override
  State<_PuanSecGovde> createState() => _PuanSecGovdeState();
}

class _PuanSecGovdeState extends State<_PuanSecGovde> {
  /// Puansız açılışta 1'den başlar, 0'dan DEĞİL: 0 "puan yok" demek ve
  /// kaydırıcının alt ucu da 1. İkisi ayrışırsa dev sayı "0" yazarken
  /// kaydırıcı 1'i gösterirdi (26 Ağu 2026 testinde yakalandı).
  late int _secim = widget.mevcut < 1
      ? 1
      : widget.mevcut.clamp(1, widget.olcek);

  /// Kaydırıcının alt ucu 1'dir, 0 DEĞİL: 0 "puan yok" demek ve onun eylemi
  /// ayrı bir düğme (Sil). Kaydırıcıyı sola sonuna kadar çekmek puanı silmiş
  /// gibi görünürdü ama silmezdi — kullanıcıya yalan söyleyen bir kontrol.
  double get _kaydiriciDeger => _secim.toDouble();

  void _degistir(int yeni) {
    final k = yeni.clamp(1, widget.olcek);
    if (k != _secim) setState(() => _secim = k);
  }

  @override
  Widget build(BuildContext context) {
    // 5 yıldızlık evrensel karşılık: seçim ölçekten bağımsız "kaç yıldız".
    final besOran = _secim / widget.olcek * 5;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, altGuvenli(context, ekstra: 20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.baslik ?? 'Puanın'.c,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          // ---- Dev sayı + ölçek paydası ----
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Icon(Icons.star_rounded, color: DiziRenkler.sari, size: 34),
              const SizedBox(width: 8),
              Text(
                '$_secim',
                style: TextStyle(
                  fontSize: 46,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: DiziRenkler.sariMetin,
                ),
              ),
              Text(
                ' / ${widget.olcek}',
                style: TextStyle(fontSize: 20, color: DiziRenkler.metin54),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // ---- 5'lik karşılık: sayı tek başına his vermiyor ----
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var y = 1; y <= 5; y++)
                Icon(
                  besOran >= y
                      ? Icons.star_rounded
                      : (besOran >= y - 0.5
                            ? Icons.star_half_rounded
                            : Icons.star_outline_rounded),
                  size: 18,
                  color: DiziRenkler.sari,
                ),
            ],
          ),
          const SizedBox(height: 10),
          // ---- Kaydırıcı + ince ayar ----
          Row(
            children: [
              _AyarDugmesi(
                ikon: Icons.remove,
                etiket: 'Bir azalt'.c,
                onTap: _secim > 1 ? () => _degistir(_secim - 1) : null,
              ),
              Expanded(
                child: Slider(
                  value: _kaydiriciDeger,
                  min: 1,
                  max: widget.olcek.toDouble(),
                  // Bölüm sayısı = adım sayısı: her tam sayı bir durak.
                  divisions: widget.olcek - 1,
                  activeColor: DiziRenkler.sari,
                  label: '$_secim',
                  onChanged: (v) => _degistir(v.round()),
                ),
              ),
              _AyarDugmesi(
                ikon: Icons.add,
                etiket: 'Bir artır'.c,
                onTap: _secim < widget.olcek
                    ? () => _degistir(_secim + 1)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (widget.mevcut > 0)
                TextButton(
                  // 0 döner: çağıran taraf bunu "puanı sil" olarak yazar.
                  onPressed: () => Navigator.pop(context, 0),
                  child: Text(
                    'Puanı Sil'.c,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.pop(context, _secim),
                child: Text('Kaydet'.c),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kaydırıcının iki yanındaki ±1 düğmesi. Dokunma hedefi 44 dp
/// (skill md. 2); pasifken ikon soluk, `onTap` null.
class _AyarDugmesi extends StatelessWidget {
  final IconData ikon;
  final String etiket;
  final VoidCallback? onTap;
  const _AyarDugmesi({required this.ikon, required this.etiket, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: etiket,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            ikon,
            color: onTap == null ? DiziRenkler.metin38 : DiziRenkler.sariMetin,
          ),
        ),
      ),
    );
  }
}
