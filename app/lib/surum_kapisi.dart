// Sürüm kapısı — sunucudaki eşiklere göre güncelleme uyarısı.
//
// Admin panelindeki "Bakım" sekmesinden `min_derleme` (zorunlu) ve
// `onerilen_derleme` (öneri) ayarlanır; uygulama açılışta /surum-kontrol'e
// kendi derleme numarasını sorar.
//
// TASARIM: Dialog DEĞİL, MaterialApp.builder içindeki bir Stack katmanı.
// Dialog için Navigator gerekir; MaterialApp.builder'ın context'i Navigator'ın
// ÜSTÜNDEDİR, showDialog orada patlar. Katman olarak çizince hem bu sorun
// yok, hem de zorunlu güncelleme gerçekten kapatılamaz (geri tuşu da dahil).
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'ceviri.dart';
import 'tema.dart';

class SurumKapisi extends StatefulWidget {
  const SurumKapisi({super.key, required this.cocuk});

  final Widget cocuk;

  @override
  State<SurumKapisi> createState() => _SurumKapisiState();
}

class _SurumKapisiState extends State<SurumKapisi> {
  // Uygulama ömrü boyunca TEK sorgu: dil/tema değişiminde ağaç baştan
  // kurulduğu için initState tekrar çalışır, ağı her seferinde yormayalım.
  static Map<String, dynamic>? _sonuc;
  static bool _bakildi = false;
  static bool _ertelendi = false;

  @override
  void initState() {
    super.initState();
    if (!_bakildi) {
      _bakildi = true;
      _kontrol();
    }
  }

  Future<void> _kontrol() async {
    final s = await Api.surumKontrol();
    if (s == null || !mounted) return;
    if (s['zorunlu'] != true && s['oneri'] != true) return;
    setState(() => _sonuc = s);
  }

  Future<void> _guncelle() async {
    final url = _sonuc?['url'] as String?;
    if (url == null || url.isEmpty) return;
    final u = Uri.tryParse(url);
    if (u == null) return;
    await launchUrl(u, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final s = _sonuc;
    final zorunlu = s?['zorunlu'] == true;
    // Öneri ertelendiyse bu oturumda bir daha gösterme; zorunlu ertelenemez.
    final goster = s != null && (zorunlu || !_ertelendi);
    return Stack(
      children: [
        widget.cocuk,
        if (goster)
          Positioned.fill(
            child: SurumKapisiKatmani(
              zorunlu: zorunlu,
              not: s['not'] as String?,
              urlVar: (s['url'] as String?)?.isNotEmpty ?? false,
              onGuncelle: _guncelle,
              onErtele: zorunlu
                  ? null
                  : () => setState(() {
                      _ertelendi = true;
                      _sonuc = null;
                    }),
            ),
          ),
      ],
    );
  }
}

/// Kapı ekranının kendisi — [SurumKapisi] ağdan gelen yanıta göre kurar.
/// Testten doğrudan kurulabilsin diye public (bkz. test/surum_kapisi_test.dart).
class SurumKapisiKatmani extends StatelessWidget {
  const SurumKapisiKatmani({
    super.key,
    required this.zorunlu,
    required this.not,
    required this.urlVar,
    required this.onGuncelle,
    required this.onErtele,
  });

  final bool zorunlu;
  final String? not;
  final bool urlVar;
  final VoidCallback onGuncelle;
  final VoidCallback? onErtele;

  @override
  Widget build(BuildContext context) {
    final metin = Theme.of(context).textTheme;
    return Material(
      color: Colors.black.withValues(alpha: zorunlu ? 0.92 : 0.72),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    zorunlu ? Icons.system_update : Icons.new_releases_outlined,
                    size: 56,
                    color: DiziRenkler.sari,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    (zorunlu ? 'Güncelleme gerekli' : 'Yeni sürüm var').c,
                    style: metin.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Devam etmek için dizi.jpg\'in yeni sürümünü yükle.'.c,
                    style: metin.bodyMedium?.copyWith(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  // Yöneticinin panelden yazdığı not — çeviriden geçmez,
                  // olduğu gibi gösterilir.
                  if (not != null && not!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        not!,
                        style: metin.bodySmall?.copyWith(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  if (urlVar)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onGuncelle,
                        style: FilledButton.styleFrom(
                          backgroundColor: DiziRenkler.sari,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text('Güncelle'.c),
                      ),
                    ),
                  if (onErtele != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: onErtele,
                      child: Text(
                        'Daha sonra'.c,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
