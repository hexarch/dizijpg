import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'ortak.dart';

/// HAREKETLERİM — Ayarlar > Hareketlerim (istek md. 20).
///
/// "Kullanıcı kendi hareketlerini görsün: beğenileri, yorumları, izlemeleri,
///  takipleri, izledikleri, gördükleri vb."
///
/// TEK ZAMAN AKIŞI, sekiz kaynak: yorum, beğeni, puan, tepki, izleme, durum,
/// liste, takip. Hepsi `GET /hareketlerim` ucundan TEK sorguyla, en yeni
/// üstte gelir; süzgeç çipleri aynı ucu `?tur=` ile daraltır.
///
/// NEDEN AYRI EKRAN (profil sekmesi değil): profil BAŞKALARINA gösterilen
/// vitrindir ve gizlilik tercihleriyle kısılabilir. Burası kişinin KENDİ
/// kaydı — uç `girisZorunlu` ve yalnız `req.kullanici.id` satırlarını döndürür,
/// başkasının hareketi hiçbir koşulda görünmez.
///
/// SÜZGEÇ URL'DE DE VAR: `/hareketlerim?tur=begeni` derin bağlantısı doğrudan
/// açılır (ui-ux-pro-max, Navigation/"Deep Linking"). Çipe dokunmak ise rota
/// değiştirmez — sayfayı baştan kurmak kaydırma konumunu ve yüklenmiş
/// sayfaları çöpe atardı.
class HareketlerimEkrani extends StatefulWidget {
  /// Açılıştaki süzgeç ('yorum', 'begeni', ...); null = hepsi.
  final String? tur;
  const HareketlerimEkrani({super.key, this.tur});

  @override
  State<HareketlerimEkrani> createState() => _HareketlerimEkraniState();
}

/// Süzgeç çipi: sunucu tür anahtarı + etiket + ikon.
/// `anahtar` null = "Hepsi" (uca `?tur=` gönderilmez).
class _Suzgec {
  final String? anahtar;
  final String etiket;
  final IconData ikon;
  const _Suzgec(this.anahtar, this.etiket, this.ikon);
}

/// Çip sırası KULLANIM SIKLIĞINA göre: en çok üretilen hareketler solda,
/// kullanıcı yatay kaydırmadan ulaşsın.
const List<_Suzgec> _suzgecler = [
  _Suzgec(null, 'Hepsi', Icons.all_inclusive),
  _Suzgec('yorum', 'Yorum', Icons.mode_comment_outlined),
  _Suzgec('begeni', 'Beğeni', Icons.favorite_border),
  _Suzgec('puan', 'Puan', Icons.star_border),
  _Suzgec('tepki', 'Tepki', Icons.emoji_emotions_outlined),
  _Suzgec('izleme', 'İzleme', Icons.visibility_outlined),
  _Suzgec('durum', 'Durum', Icons.bookmark_border),
  _Suzgec('liste', 'Liste', Icons.playlist_add_check),
  _Suzgec('takip', 'Takip', Icons.person_add_alt),
];

/// Tür → satır ikonu (boş durumda ve poster yoksa kullanılır).
const Map<String, IconData> _turIkonu = {
  'yorum': Icons.mode_comment_outlined,
  'begeni': Icons.favorite,
  'puan': Icons.star,
  'tepki': Icons.emoji_emotions_outlined,
  'izleme': Icons.visibility,
  'durum': Icons.bookmark,
  'liste': Icons.playlist_add_check,
  'takip': Icons.person_add_alt_1,
};

/// Durum kodu → "…işaretledin" cümlesi. Sunucu `deger` alanında ham kodu
/// yollar; metin BURADA seçilir ki dil değişince eski satırlar da çevrilsin.
const Map<String, String> _durumCumlesi = {
  'izleyecegim': '"İzleyeceğim" işaretledin',
  'izliyorum': '"İzliyorum" işaretledin',
  'bitirdim': '"Bitirdim" işaretledin',
  'biraktim': '"Bıraktım" işaretledin',
};

class _HareketlerimEkraniState extends State<HareketlerimEkrani> {
  final _kaydirma = ScrollController();
  final _liste = <Map<String, dynamic>>[];
  Map<String, dynamic> _icerikler = {};

  String? _tur;

  /// Sonraki sayfanın imleci. null + [_ilkYuklendi] → akış gerçekten bitti.
  String? _imlec;
  bool _ilkYuklendi = false;
  bool _yukleniyor = false;
  String? _hata;

  /// Süzgeç değişince yolda olan eski isteğin yanıtı listeye KARIŞMASIN diye
  /// her yükleme turu numaralanır (hızlı çip dokunuşları karışık liste
  /// üretiyordu — begenenler.dart'ta olmayan ama burada gereken koruma).
  int _turNo = 0;

  @override
  void initState() {
    super.initState();
    _tur = widget.tur;
    _kaydirma.addListener(_kaydirdi);
    _yukle();
  }

  @override
  void dispose() {
    _kaydirma.dispose();
    super.dispose();
  }

  /// Dibe 400px kala sıradaki sayfa (katalog_liste/begenenler kalıbı).
  void _kaydirdi() {
    if (!_kaydirma.hasClients) return;
    // Sonraki sayfa PATLADIYSA kaydırma otomatik yeniden denemez: dipteki
    // "Tekrar Dene" düğmesi bekler. Yoksa kalıcı bir hata (ağ kopuk, 500)
    // her kaydırma karesinde yeni istek üretir ve hız limitini yakardı.
    if (_hata != null) return;
    final kalan =
        _kaydirma.position.maxScrollExtent - _kaydirma.position.pixels;
    if (kalan < 400) _yukle();
  }

  Future<void> _yukle() async {
    if (_yukleniyor) return;
    if (_ilkYuklendi && _imlec == null) return; // akış bitti
    final no = _turNo;
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final p = <String>[
        if (_tur != null) 'tur=$_tur',
        if (_imlec != null) 'imlec=${Uri.encodeQueryComponent(_imlec!)}',
      ];
      final d =
          await Api.get('/hareketlerim${p.isEmpty ? '' : '?${p.join('&')}'}')
              as Map<String, dynamic>;
      if (!mounted || no != _turNo) return;
      setState(() {
        _liste.addAll(
          (d['hareketler'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>(),
        );
        _icerikler = {
          ..._icerikler,
          ...(d['icerikler'] as Map<String, dynamic>? ?? {}),
        };
        _imlec = d['imlec'] as String?;
        _ilkYuklendi = true;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted || no != _turNo) return;
      setState(() {
        _hata = e.toString();
        _yukleniyor = false;
      });
    }
  }

  /// Süzgeci değiştir: liste sıfırlanır, ilk sayfa yeniden çekilir.
  void _suzgecSec(String? tur) {
    if (tur == _tur) return;
    setState(() {
      _tur = tur;
      _turNo++;
      _liste.clear();
      _imlec = null;
      _ilkYuklendi = false;
      _yukleniyor = false;
      _hata = null;
    });
    // Yeni süzgeç en baştan okunsun; kullanıcı yarım kaydırılmış listeye
    // düşmesin.
    if (_kaydirma.hasClients) _kaydirma.jumpTo(0);
    _yukle();
  }

  Future<void> _tazele() async {
    setState(() {
      _turNo++;
      _liste.clear();
      _imlec = null;
      _ilkYuklendi = false;
      _yukleniyor = false;
      _hata = null;
    });
    await _yukle();
  }

  // -------------------------------------------------------------------------
  // Satırdan metin/hedef üretimi
  // -------------------------------------------------------------------------

  /// `icerikler` haritasındaki TMDB kaydı (ad + poster) — yoksa null.
  Map<String, dynamic>? _icerik(Map<String, dynamic> h) {
    final tur = h['hedef_tur'] as String?;
    final id = h['tmdb_id'];
    if (tur == null || id == null) return null;
    return _icerikler['$tur:$id'] as Map<String, dynamic>?;
  }

  /// Üst satır: ne yaptım?
  String _baslik(Map<String, dynamic> h) {
    switch (h['tur'] as String? ?? '') {
      case 'yorum':
        return 'Yorum yaptın'.c;
      case 'begeni':
        return 'Yorumu beğendin'.c;
      case 'puan':
        return '{} puan verdin'.cf([h['deger'] ?? '?']);
      case 'tepki':
        return '${'Tepki verdin'.c}  ${h['deger'] ?? ''}'.trimRight();
      case 'izleme':
        return 'İzledin'.c;
      case 'durum':
        return (_durumCumlesi[h['deger'] as String? ?? ''] ?? 'Durum').c;
      case 'liste':
        return 'Listene ekledin'.c;
      case 'takip':
        return 'Takip etmeye başladın'.c;
    }
    return '';
  }

  /// Alt satır: hangi hedefe? Hedef silinmişse null döner (satır "Silinmiş
  /// içerik" yazar ve DOKUNULAMAZ olur — çökme yerine nazik bozulma).
  String? _hedefAdi(Map<String, dynamic> h) {
    final tur = h['tur'] as String? ?? '';
    if (tur == 'takip' || tur == 'begeni') {
      final ad = h['ad'] as String?;
      if (tur == 'takip') return ad == null ? null : '@$ad';
      // Beğenide hedef YORUMDUR: içerik adı varsa onu göster, yoksa yazarı.
      final i = _icerik(h);
      if (i != null) return i['ad'] as String?;
      return ad == null ? null : '@$ad';
    }
    if (tur == 'liste') return h['ad'] as String?;
    return _icerik(h)?['ad'] as String?;
  }

  /// "S3B7" rozeti (yalnız bölüm hedeflerinde).
  String? _bolumEtiketi(Map<String, dynamic> h) {
    final s = h['sezon'];
    final b = h['bolum'];
    if (s == null || b == null) return null;
    return 'S${s}B$b';
  }

  /// Satıra dokununca gidilecek rota; null = dokunulamaz (silinmiş hedef).
  String? _rota(Map<String, dynamic> h) {
    final tur = h['tur'] as String? ?? '';
    if (tur == 'takip') {
      final ad = h['ad'] as String?;
      return ad == null ? null : '/kullanici/$ad';
    }
    if (tur == 'yorum' || tur == 'begeni') {
      final id = h['yorum_id'];
      // Beğenilen yorum silinmişse `hedef_tur` de NULL gelir: sunucu satırı
      // düşürmüyor, biz dokunmayı kapatıyoruz.
      final silinmis = tur == 'begeni' && h['hedef_tur'] == null;
      if (id == null || silinmis) return null;
      return '/gonderi/$id';
    }
    if (tur == 'liste') {
      final id = h['liste_id'];
      return id == null ? null : '/listeler/$id';
    }
    final hedefTur = h['hedef_tur'] as String?;
    final id = h['tmdb_id'];
    if (hedefTur == null || id == null) return null;
    if (hedefTur == 'person') return '/kisi/$id';
    final s = h['sezon'];
    final b = h['bolum'];
    if (hedefTur == 'tv' && s != null && b != null) {
      return '/dizi/$id/sezon/$s/bolum/$b';
    }
    return '/icerik/$hedefTur/$id';
  }

  /// Kısa göreli zaman ("3 sa", "12 g"). Uzun tarih biçimi yerine: satır
  /// sonunda tek kelime kalsın, uzun çeviriler taşmasın.
  String _zaman(Map<String, dynamic> h) {
    final t = DateTime.tryParse(h['tarih'] as String? ?? '');
    if (t == null) return '';
    final fark = DateTime.now().difference(t.toLocal());
    if (fark.inMinutes < 1) return 'şimdi'.c;
    if (fark.inMinutes < 60) return '{} dk'.cf([fark.inMinutes]);
    if (fark.inHours < 24) return '{} sa'.cf([fark.inHours]);
    if (fark.inDays < 365) return '{} g'.cf([fark.inDays]);
    return '{} y'.cf([fark.inDays ~/ 365]);
  }

  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_hata != null && _liste.isEmpty) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (!_ilkYuklendi) {
      govde = const IskeletListe();
    } else if (_liste.isEmpty) {
      govde = BosDurum(
        ikon: _tur == null
            ? Icons.timeline
            : (_turIkonu[_tur] ?? Icons.timeline),
        baslik: _tur == null
            ? 'Henüz hareketin yok'.c
            : 'Bu süzgeçte hareket yok'.c,
        ipucu: _tur == null
            ? 'Beğendiğin, yorumladığın, izlediğin her şey burada birikir.'.c
            : 'Başka bir tür seç ya da "Hepsi"ne dön.'.c,
        aksiyon: _tur == null
            ? null
            : TextButton(
                onPressed: () => _suzgecSec(null),
                child: Text('Hepsi'.c),
              ),
      );
    } else {
      govde = RefreshIndicator(
        onRefresh: _tazele,
        color: DiziRenkler.sari,
        child: ListView.builder(
          controller: _kaydirma,
          padding: EdgeInsets.fromLTRB(12, 8, 12, altGuvenli(context)),
          // Son satır: devam varsa yükleniyor göstergesi — sonraki sayfa
          // PATLADIYSA "Tekrar Dene". Sessiz başarısızlık yasak: liste dolu
          // olduğu için tam ekran hata görünümü çizilmiyor, hata yalnız
          // burada görünebilir (ux-kontrol §3, "her eylemin üç hali").
          itemCount: _liste.length + (_imlec != null ? 1 : 0),
          itemBuilder: (context, i) {
            if (i >= _liste.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: _hata == null
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : TextButton.icon(
                          onPressed: _yukle,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text('Tekrar Dene'.c),
                        ),
                ),
              );
            }
            final h = _liste[i];
            return _HareketSatiri(
              key: ValueKey(h['anahtar'] ?? '$i'),
              baslik: _baslik(h),
              hedef: _hedefAdi(h),
              ozet: h['ozet'] as String?,
              bolum: _bolumEtiketi(h),
              zaman: _zaman(h),
              ikon: _turIkonu[h['tur']] ?? Icons.circle,
              poster: posterUrl(
                _icerik(h)?['poster'] as String?,
                boyut: 'w185',
              ),
              avatar: dosyaUrl(h['avatar'] as String?),
              kullaniciAdi: h['ad'] as String?,
              rota: _rota(h),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Hareketlerim'.c)),
      // PC'de tek sütunlu okuma kolonu (720) — satırlar 1440'lık ekranda
      // uçtan uca gerilmesin (tema.dart `masaustuKolonGenisligi` gerekçesi).
      body: OrtaKolon(
        azami: masaustuKolonGenisligi,
        cocuk: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SuzgecSeridi(secili: _tur, onSec: _suzgecSec),
            Divider(height: 1, color: DiziRenkler.metin12),
            Expanded(child: govde),
          ],
        ),
      ),
    );
  }
}

/// Yatay süzgeç çipleri. Seçili çip SARI zeminli + kalın: aktif durum yalnız
/// renk tonuyla değil kontrastla da belli olur (ui-ux-pro-max,
/// Navigation/"Active State" + Accessibility kontrast kuralı).
class _SuzgecSeridi extends StatelessWidget {
  final String? secili;
  final void Function(String?) onSec;
  const _SuzgecSeridi({required this.secili, required this.onSec});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // 44 dp çip + 2×8 dolgu: dokunma hedefi kuralı (min 44×44) serit
      // yüksekliğiyle GARANTİ altına alınır.
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _suzgecler.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = _suzgecler[i];
          final aktif = s.anahtar == secili;
          return ChoiceChip(
            key: ValueKey('hareket-cip-${s.anahtar ?? 'hepsi'}'),
            selected: aktif,
            onSelected: (_) => onSec(s.anahtar),
            showCheckmark: false,
            avatar: Icon(
              s.ikon,
              size: 18,
              color: aktif ? Colors.black : DiziRenkler.metin54,
            ),
            label: Text(s.etiket.c),
            labelStyle: TextStyle(
              color: aktif ? Colors.black : DiziRenkler.metin,
              fontWeight: aktif ? FontWeight.w800 : FontWeight.w500,
            ),
            selectedColor: DiziRenkler.sari,
            backgroundColor: DiziRenkler.kart,
            side: BorderSide(
              color: aktif ? DiziRenkler.sari : DiziRenkler.metin12,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          );
        },
      ),
    );
  }
}

/// Tek hareket satırı: [poster] ya da [avatar] + eylem cümlesi + hedef + zaman.
///
/// [rota] null ise (silinmiş hedef) satır soluk çizilir ve DOKUNMAZ — hem
/// çökme hem "hiçbir şey olmadı" hissi engellenir.
class _HareketSatiri extends StatelessWidget {
  final String baslik;
  final String? hedef;
  final String? ozet;
  final String? bolum;
  final String zaman;
  final IconData ikon;
  final String? poster;
  final String? avatar;
  final String? kullaniciAdi;
  final String? rota;

  const _HareketSatiri({
    super.key,
    required this.baslik,
    required this.hedef,
    required this.ozet,
    required this.bolum,
    required this.zaman,
    required this.ikon,
    required this.poster,
    required this.avatar,
    required this.kullaniciAdi,
    required this.rota,
  });

  /// KULLANICI ROTASI AYRI YOLDAN GİDER — `/kullanici/:ad` kabuğun İÇİNDE
  /// yaşıyor; bu ekran kabuğun DIŞINDA. Düz `push` kabuğu ikinci kez kurar,
  /// dal GlobalKey'leri çakışır ve SİYAH EKRAN çıkar (ortak.dart
  /// [kullaniciyaGit] başlığındaki 6 Ağu hatası). Diğer hedefler
  /// (/gonderi, /icerik, /dizi, /kisi, /listeler) zaten kök rotadır.
  void _git(BuildContext context) {
    final r = rota!;
    if (r.startsWith('/kullanici/')) {
      kullaniciyaGit(context, r.substring('/kullanici/'.length));
    } else {
      rotayaGitGuvenli(context, r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final silinmis = hedef == null;
    final metin = silinmis ? DiziRenkler.metin38 : DiziRenkler.metin;

    Widget gorsel;
    if (poster != null) {
      gorsel = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 34,
          height: 48,
          child: AgGorsel(
            url: poster!,
            yerTutucu: Container(color: DiziRenkler.koyuGri),
            hata: Container(
              color: DiziRenkler.koyuGri,
              child: Icon(ikon, size: 16, color: DiziRenkler.metin38),
            ),
          ),
        ),
      );
    } else if (avatar != null || kullaniciAdi != null) {
      gorsel = KullaniciAvatari(
        url: avatar,
        kullaniciAdi: kullaniciAdi,
        yaricap: 20,
      );
    } else {
      gorsel = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: DiziRenkler.koyuGri,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(ikon, size: 20, color: DiziRenkler.metin38),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: rota == null ? null : () => _git(context),
        child: Padding(
          // Dikey 12 + 48'lik görsel = 72 dp satır: dokunma hedefi 44 dp'nin
          // rahatça üstünde (ui-ux-pro-max, Touch & Interaction).
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 40, child: Center(child: gorsel)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(ikon, size: 14, color: DiziRenkler.sariMetin),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            baslik,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: DiziRenkler.metin70,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          zaman,
                          style: TextStyle(
                            fontSize: 12,
                            color: DiziRenkler.metin38,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            hedef ?? 'Silinmiş içerik'.c,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              fontStyle: silinmis
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              color: metin,
                            ),
                          ),
                        ),
                        if (bolum != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: DiziRenkler.metin12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              bolum!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: DiziRenkler.metin70,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if ((ozet ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        ozet!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color: DiziRenkler.metin54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
