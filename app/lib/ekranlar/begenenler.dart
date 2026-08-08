import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'ortak.dart';
import 'takip_dugmesi.dart';

/// BEĞENENLER LİSTESİ — beğeni düğmesine BASILI TUTUNCA açılır.
///
/// Beğeni düğmesi dört ayrı yerde çiziliyor (akış kartı, Reels, yorum kartı,
/// yanıt satırları). Liste her birinde ayrı yazılsaydı birinde düzeltilen
/// (takip düğmesi, sayfalama, oturumsuz hâl) ötekilerde kalırdı — paylaş
/// sheet'inde (`gonderiPaylas`) öğrenilen ders. Tek giriş noktası burasıdır:
/// her çağıran `begenenleriAc(context, yorumId)` der.
///
/// UZUN BASMA / KISA DOKUNUŞ AYRIMI: çağıran taraflar `onTap` (beğen) ve
/// `onLongPress` (bu liste) verir. Flutter'da uzun basma tanınınca `onTap`
/// ATEŞLENMEZ, yani liste açmak yanlışlıkla beğeni atmaz.
Future<void> begenenleriAc(BuildContext context, int yorumId) {
  // Profil gezinmesi sheet'in DIŞ bağlamıyla yapılır: sheet önce kapanır,
  // sonra gidilir. Sheet açık kalsaydı kullanıcı profilden geri döndüğünde
  // üstüne yapışmış bir liste bulurdu (giris_istem.dart'taki kalıbın aynısı).
  final disBaglam = context;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DiziRenkler.koyuGri,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetBaglam) => BegenenlerSheet(
      yorumId: yorumId,
      onKullanici: (ad) {
        Navigator.pop(sheetBaglam);
        kullaniciyaGit(disBaglam, ad);
      },
    ),
  );
}

/// Beğenenler alt sayfası: solda avatar, yanında kullanıcı adı, en sağda
/// takip düğmesi ([TakipDugmesi]). Takip etmiyorsan "Takip Et", ediyorsan
/// "Takibi Bırak" çıkar; yalnız KENDİ satırında hiçbir şey olmaz.
///
/// (3 Ağu'da "takip ediyorsan hiçbir şey yazmasın" istenmişti; 8 Ağu'da
/// kullanıcı listelerinin tamamı için "takip ediyorsam takibi bırak butonu
/// olmalı" denince kural her listede aynı hâle getirildi.)
class BegenenlerSheet extends StatefulWidget {
  final int yorumId;

  /// Bir satıra dokununca çağrılır (sheet'i kapat + profile git). Verilmezse
  /// doğrudan profile gidilir — sheet dışında kullanıldığında da çalışsın.
  final void Function(String kullaniciAdi)? onKullanici;
  const BegenenlerSheet({super.key, required this.yorumId, this.onKullanici});

  @override
  State<BegenenlerSheet> createState() => _BegenenlerSheetState();
}

class _BegenenlerSheetState extends State<BegenenlerSheet> {
  final _kaydirma = ScrollController();
  final _liste = <Map<String, dynamic>>[];

  /// Sonraki sayfanın imleci. null + [_ilkYuklendi] → liste gerçekten bitti.
  String? _imlec;
  int? _toplam;
  bool _ilkYuklendi = false;
  bool _yukleniyor = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _kaydirma.addListener(_kaydirdi);
    _yukle();
  }

  @override
  void dispose() {
    _kaydirma.dispose();
    super.dispose();
  }

  /// Dibe 400px kala sıradaki sayfa (katalog_liste.dart kalıbı).
  void _kaydirdi() {
    if (!_kaydirma.hasClients) return;
    final kalan =
        _kaydirma.position.maxScrollExtent - _kaydirma.position.pixels;
    if (kalan < 400) _yukle();
  }

  Future<void> _yukle() async {
    if (_yukleniyor) return;
    if (_ilkYuklendi && _imlec == null) return; // havuz bitti
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final imlec = _imlec == null
          ? ''
          : '?imlec=${Uri.encodeQueryComponent(_imlec!)}';
      final d =
          await Api.get('/yorumlar/${widget.yorumId}/begenenler$imlec')
              as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _liste.addAll(
          (d['begenenler'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>(),
        );
        _imlec = d['imlec'] as String?;
        _toplam ??= (d['toplam'] as num?)?.toInt();
        _ilkYuklendi = true;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = e.toString();
        _yukleniyor = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.62,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Sürükleme tutamağı (paylaş sheet'iyle aynı)
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
                  Icon(Icons.favorite, size: 20, color: DiziRenkler.sariMetin),
                  const SizedBox(width: 8),
                  // Flexible + ellipsis: Tamilce "விரும்பியவர்கள்" gibi uzun
                  // çeviriler 320dp telefonda başlığı taşırıyordu
                  // (RenderFlex overflow, 8 Ağu'da takip düğmesi testleri
                  // yakaladı).
                  Flexible(
                    child: Text(
                      'Beğenenler'.c,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_toplam != null && _toplam! > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '$_toplam',
                      style: TextStyle(
                        fontSize: 14,
                        color: DiziRenkler.metin54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Divider(color: DiziRenkler.metin12, height: 12),
            Expanded(child: _govde()),
          ],
        ),
      ),
    );
  }

  Widget _govde() {
    // Hata: yalnızca hiç satır yokken tam ekran hata (sayfalama hatası listeyi
    // silmez, altta yeniden denenir).
    if (_hata != null && _liste.isEmpty) {
      return HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    }
    if (!_ilkYuklendi) {
      return const Center(
        child: CircularProgressIndicator(color: DiziRenkler.sari),
      );
    }
    if (_liste.isEmpty) {
      return BosDurum(
        ikon: Icons.favorite_border,
        baslik: 'Henüz beğeni yok'.c,
        ipucu: 'Bu gönderiyi ilk beğenen sen ol'.c,
      );
    }
    return ListView.builder(
      controller: _kaydirma,
      padding: const EdgeInsets.only(bottom: 12),
      // Son satır: sayfalama göstergesi
      itemCount: _liste.length + (_imlec != null ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _liste.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: DiziRenkler.sari,
                ),
              ),
            ),
          );
        }
        final k = _liste[i];
        final id = (k['kullanici_id'] as num?)?.toInt() ?? 0;
        return _BegenenSatiri(
          key: ValueKey(id),
          kullanici: k,
          onKullanici: widget.onKullanici,
        );
      },
    );
  }
}

/// Tek satır: [avatar] [kullanıcı adı] .......... [Takip Et / Takibi Bırak]
///
/// Avatara ya da ada dokununca o kişinin profiline gider. Satır yüksekliği
/// 56px — dokunma hedefi 44px asgarisinin üstünde.
class _BegenenSatiri extends StatelessWidget {
  final Map<String, dynamic> kullanici;
  final void Function(String kullaniciAdi)? onKullanici;
  const _BegenenSatiri({super.key, required this.kullanici, this.onKullanici});

  @override
  Widget build(BuildContext context) {
    final ad = kullanici['kullanici_adi'] as String? ?? '';
    // Kendi satırında düğme HİÇ çizilmez (kendini takip edemezsin).
    final benMi = kullanici['ben_mi'] == true;
    return InkWell(
      onTap: () =>
          onKullanici == null ? kullaniciyaGit(context, ad) : onKullanici!(ad),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            KullaniciAvatari(
              url: dosyaUrl(kullanici['avatar'] as String?),
              kullaniciAdi: ad,
              yaricap: 20,
              arkaplan: DiziRenkler.kart,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '@$ad',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // Dokunma hedefleri arası boşluk (>=8px): satırın kendisi de
            // tıklanabilir olduğu için yanlışlıkla basmayı zorlaştırır.
            if (!benMi) ...[
              const SizedBox(width: 12),
              TakipDugmesi(
                kullaniciAdi: ad,
                takipEdiyorum: kullanici['takip_ediyorum'] == true,
                // Sonuç paylaşılan haritaya yazılır: sayfalama satırı yeniden
                // kurarsa (ya da liste tazelenirse) doğru hâlde açılır.
                onDegisti: (v) => kullanici['takip_ediyorum'] = v,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
