import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'ortak.dart';

/// ENGELLENEN KULLANICILAR — Ayarlar > Gizlilik > Engellenen kullanıcılar.
///
/// Engellemenin TEK toplu yönetim yeri. Profilden de engel kaldırılabilir ama
/// oraya gitmek için önce kişiyi BULMAK gerekir — engellenen kişi ise arama
/// sonuçlarında, takipçi listelerinde ve akışta artık GÖRÜNMÜYOR
/// (`GET /kullanici-ara` ve kardeşleri çift yönlü süzüyor). Bu ekran olmasaydı
/// engel fiilen KALICI olurdu: kullanıcı kararını geri alacak yolu bulamazdı.
///
/// Satır = avatar + kullanıcı adı + "Engeli kaldır". Profil ÖNİZLEMESİ YOK
/// (bio/gönderi çekilmez): amaç engellenen kişinin içeriğini göstermemek.
class EngellenenKullanicilarEkrani extends StatefulWidget {
  const EngellenenKullanicilarEkrani({super.key});

  @override
  State<EngellenenKullanicilarEkrani> createState() =>
      _EngellenenKullanicilarEkraniState();
}

class _EngellenenKullanicilarEkraniState
    extends State<EngellenenKullanicilarEkrani> {
  List<dynamic>? _kullanicilar;
  String? _hata;

  /// Sunucu isteği süren kullanıcı adları: çift dokunuş çift toggle atarsa
  /// engel kaldırılıp ANINDA geri kurulurdu (uç bir toggle).
  final _isleniyor = <String>{};

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      final liste = await Api.engellenenler();
      if (!mounted) return;
      setState(() => _kullanicilar = liste);
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
    }
  }

  /// Engeli kaldır: iyimser olarak listeden düşer, hata olursa GERİ GELİR.
  Future<void> _kaldir(Map<String, dynamic> k) async {
    final ad = k['kullanici_adi'] as String;
    if (!_isleniyor.add(ad)) return;
    final sira = _kullanicilar!.indexOf(k);
    setState(() => _kullanicilar!.remove(k));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Api.engelleToggle(ad);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Engel kaldırıldı'.c)));
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _kullanicilar!.insert(sira, k),
      ); // iyimser güncellemeyi geri al
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      _isleniyor.remove(ad);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_kullanicilar == null) {
      govde = const Center(
        child: CircularProgressIndicator(color: DiziRenkler.sari),
      );
    } else if (_kullanicilar!.isEmpty) {
      govde = BosDurum(
        ikon: Icons.block_outlined,
        baslik: 'Engellediğin kimse yok'.c,
        ipucu:
            'Bir kullanıcıyı profilindeki üç nokta menüsünden engelleyebilirsin.'
                .c,
      );
    } else {
      govde = RefreshIndicator(
        color: DiziRenkler.sari,
        onRefresh: _yukle,
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(
            12,
            12,
            12,
            altGuvenli(context, ekstra: 24),
          ),
          itemCount: _kullanicilar!.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final k = _kullanicilar![i] as Map<String, dynamic>;
            final ad = k['kullanici_adi'] as String;
            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                key: Key('engelli-$ad'),
                leading: KullaniciAvatari(
                  url: dosyaUrl(k['avatar'] as String?),
                  kullaniciAdi: ad,
                  yaricap: 20,
                  arkaplan: DiziRenkler.koyuGri,
                ),
                title: Text(
                  '@$ad',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                // Profile gitmek SERBEST: engelli profil zaten boş gelir ve
                // orada da "Engeli kaldır" düğmesi vardır. Kilitlemek,
                // kullanıcıyı kendi kararının ayrıntısından mahrum ederdi.
                onTap: () => context.push('/kullanici/$ad'),
                trailing: TextButton(
                  onPressed: _isleniyor.contains(ad) ? null : () => _kaldir(k),
                  child: _isleniyor.contains(ad)
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Engeli kaldır'.c,
                          style: TextStyle(
                            color: DiziRenkler.sariMetin,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            );
          },
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('Engellenen kullanıcılar'.c)),
      // PC'de gizlenen yorumlar ekranıyla AYNI ortalanmış okuma kolonu (md. 26).
      body: OrtaKolon(azami: masaustuKolonGenisligi, cocuk: govde),
    );
  }
}
