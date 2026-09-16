import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'giris_istem.dart';
import 'izlem_carki.dart';
import 'ortak.dart';
import 'paylas.dart';

/// `/listeler/:id` — tek listenin TAM SAYFA hâli.
///
/// NEDEN VAR: sunucu `/og/listeler/:id` için indekslenebilir bir SSR sayfası
/// basıyor (paylaşım kartı ve arama sonucu bu adrese götürüyor). Rota
/// olmadığı sürece o bağlantıya tıklayan herkes — giriş yapmış kullanıcı
/// dahil — "Bağlantı geçersiz" görüyordu; oturumsuz ziyaretçi ise `/giris`e
/// atılıyordu. Bot içerik, insan giriş formu görünce Google buna CLOAKING der.
/// Bu yüzden rota `acikYolOnEkleri` içinde ve oturumsuz açılır
/// (bkz. yonlendirme.dart).
///
/// İçerik ızgarası [ListeIcerigi]'nden gelir — profil modalindeki
/// [ListeSheet] ile BİREBİR aynı kod; kopyalanmadı.
class ListeEkrani extends StatefulWidget {
  final int listeId;

  const ListeEkrani({super.key, required this.listeId});

  @override
  State<ListeEkrani> createState() => _ListeEkraniState();
}

class _ListeEkraniState extends State<ListeEkrani> {
  Map<String, dynamic>? _liste;

  /// Düzenleme kipi ve sahiplik — modal ([ListeSheet]) ile AYNI desen:
  /// bayrak burada durur çünkü düzenle düğmesi liste ADININ yanında, yani
  /// AppBar'da; sahiplik bilgisi sunucudan [ListeIcerigi] üzerinden gelir.
  bool _duzenleme = false;
  bool _sahibiyim = false;

  /// LİSTE ADI DÜZENLEME (16 Eyl 2026 isteği): "kullanıcı oluşturduğu
  /// listelerin ismini değiştiremiyor, edite tıklayınca değiştirebilmeli."
  ///
  /// Kalem 19 Ağu'dan beri vardı ama yalnız içeriği (sıra/gizle/kaldır)
  /// açıyordu; adın kendisi donuktu. Şimdi düzenleme kipinde AppBar başlığı
  /// bir metin alanına dönüşür, "Bitti" (onay ikonu) ya da klavyedeki
  /// tamam tuşu adı sunucuya yazar (`PUT /listeler/:id`) ve kipi kapatır.
  ///
  /// NEDEN AYRI DİYALOG DEĞİL: kullanıcı "edite tıklayınca" ad alanının
  /// açılmasını bekliyor; bir de "adı değiştir" düğmesi aramak fazladan
  /// adım olurdu. Ad zaten AppBar'da yaşıyor — yerinde düzenlenir.
  final _adDenetleyici = TextEditingController();
  bool _adYaziliyor = false;

  @override
  void dispose() {
    _adDenetleyici.dispose();
    super.dispose();
  }

  void _duzenlemeDegis() {
    if (_adYaziliyor) return;
    if (_duzenleme) {
      _bitir();
      return;
    }
    // Alan her açılışta SUNUCUDAKİ adla dolar: önceki kipte yazılıp
    // vazgeçilen (kaydedilemeyen) taslak bir sonraki açılışa sızmasın.
    _adDenetleyici.text = (_liste?['ad'] as String?)?.trim() ?? '';
    setState(() => _duzenleme = true);
  }

  /// "Bitti": ad değiştiyse sunucuya yazar, sonra kipi kapatır.
  ///
  /// ÜÇ HAL: yazılırken düğme spinner'a döner ve kilitlenir; başarıda
  /// başlık anında yeni adı gösterir; sunucu reddederse kip AÇIK KALIR ve
  /// uyarı çıkar — kullanıcı yazdığını kaybetmeden tekrar deneyebilir.
  /// Boş ad sunucuya hiç gitmez (sunucu da 400 verirdi ama gerekçeyi
  /// istemcide, kendi dilinde söylemek daha iyi).
  Future<void> _bitir() async {
    final yeni = _adDenetleyici.text.trim();
    final eski = (_liste?['ad'] as String?)?.trim() ?? '';
    if (yeni.isEmpty) {
      _uyar('Liste adı boş olamaz'.c);
      return;
    }
    if (yeni == eski) {
      setState(() => _duzenleme = false);
      return;
    }
    setState(() => _adYaziliyor = true);
    try {
      await Api.put('/listeler/${widget.listeId}', {'ad': yeni});
      if (!mounted) return;
      setState(() {
        _liste = {...?_liste, 'ad': yeni};
        _duzenleme = false;
      });
    } catch (_) {
      if (!mounted) return;
      _uyar('Liste adı kaydedilemedi'.c);
    } finally {
      if (mounted) setState(() => _adYaziliyor = false);
    }
  }

  void _uyar(String mesaj) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mesaj)));
  }

  /// Düzenleme kipindeki başlık: liste adı metin alanı.
  ///
  /// Sınır sunucuyla aynı (60); sayaç gizli — AppBar'da yer yok ve kullanıcı
  /// tavana nadiren yaklaşır. Stil AppBar başlığınınki: alan açılınca
  /// yazının boyutu/kalınlığı değişmesin, "başlık yerinde düzenleniyor"
  /// hissi kalsın.
  Widget _adAlani(BuildContext context) => TextField(
    key: const Key('liste-ad-alani'),
    controller: _adDenetleyici,
    autofocus: true,
    maxLength: 60,
    textInputAction: TextInputAction.done,
    onSubmitted: (_) => _bitir(),
    style:
        Theme.of(context).appBarTheme.titleTextStyle ??
        Theme.of(context).textTheme.titleLarge,
    decoration: InputDecoration(
      hintText: 'Liste adı'.c,
      counterText: '',
      isDense: true,
      border: const UnderlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final ad = (_liste?['ad'] as String?)?.trim() ?? '';
    final sahip = (_liste?['kullanici_adi'] as String?)?.trim() ?? '';
    return Scaffold(
      appBar: AppBar(
        // Başlık liste yüklenene kadar BOŞ kalır: yer tutucu bir metin
        // gösterip sonra değiştirmek "yanlış liste açıldı" hissi veriyordu.
        title: _duzenleme && _sahibiyim
            ? _adAlani(context)
            : ad.isEmpty
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(ad, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (sahip.isNotEmpty)
                    Text(
                      '@$sahip',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: DiziRenkler.metin54,
                      ),
                    ),
                ],
              ),
        actions: [
          // "Ne izlesem çarkı" kendi listelerde de (24 Ağu 2026 isteği: çark
          // yalnız kitaplık İzleyeceğim'indeydi, kullanıcı web'de kendi
          // listesinde arayıp bulamadı). Sahiplik ŞART DEĞİL: başkasının
          // listesinden de "ne izlesem" çevrilebilir. Boş listede çizilmez.
          //
          // Düzenleme kipinde çark ve paylaş ÇİZİLMEZ: ad alanına yer açmak
          // için (dar telefonda üç ikon alanı 120 px'e sıkıştırıyordu) ve
          // kip zaten "listeyi değiştir" işi — çevirme/paylaşma burada değil.
          if (!_duzenleme &&
              ((_liste?['ogeler'] as List<dynamic>?) ?? const []).isNotEmpty)
            IconButton(
              key: const Key('liste-izlem-carki'),
              tooltip: 'Ne izlesem?'.c,
              onPressed: () => izlemCarkiniAc(
                context,
                (_liste!['ogeler'] as List<dynamic>)
                    .cast<Map<String, dynamic>>(),
              ),
              icon: const Icon(Icons.attractions),
            ),
          // Paylaş yalnız HERKESE AÇIK listede (gizli listenin bağlantısı
          // yabancıya 404 verir) ve liste yüklenince — modal ([ListeSheet])
          // ile aynı davranış.
          if (!_duzenleme && _liste != null && _liste!['herkese_acik'] != false)
            ListePaylasDugmesi(listeId: widget.listeId, ad: ad),
          if (_sahibiyim)
            ListeDuzenleDugmesi(
              duzenleme: _duzenleme,
              yaziliyor: _adYaziliyor,
              onDegis: _duzenlemeDegis,
            ),
          // Oturumsuz ziyaretçinin alt gezinme çubuğu yoktur; bu buton olmasa
          // sayfada çıkışsız kalırdı (içerik sayfalarındaki kalıbın aynısı).
          const GirisEylemi(),
        ],
      ),
      // PC'de ızgara ortalanmış ve [masaustuIcerikGenisligi] (1080) ile sınırlı
      // (madde 26); mobilde kısıt bağlamaz. Profildeki [ListeSheet] kendi
      // genişliğini modal olarak yönetir, o yüzden kısıt yalnız TAM SAYFADA.
      body: OrtaKolon(
        azami: masaustuIcerikGenisligi,
        cocuk: ListeIcerigi(
          listeId: widget.listeId,
          duzenleme: _duzenleme,
          onListe: (l) {
            if (mounted) setState(() => _liste = l);
          },
          onSahiplik: (v) {
            if (mounted && v != _sahibiyim) setState(() => _sahibiyim = v);
          },
        ),
      ),
    );
  }
}
