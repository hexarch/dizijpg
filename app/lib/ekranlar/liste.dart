import 'package:flutter/material.dart';

import '../ceviri.dart';
import '../tema.dart';
import 'giris_istem.dart';
import 'izlem_carki.dart';
import 'ortak.dart';

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

  @override
  Widget build(BuildContext context) {
    final ad = (_liste?['ad'] as String?)?.trim() ?? '';
    final sahip = (_liste?['kullanici_adi'] as String?)?.trim() ?? '';
    return Scaffold(
      appBar: AppBar(
        // Başlık liste yüklenene kadar BOŞ kalır: yer tutucu bir metin
        // gösterip sonra değiştirmek "yanlış liste açıldı" hissi veriyordu.
        title: ad.isEmpty
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
          if (((_liste?['ogeler'] as List<dynamic>?) ?? const []).isNotEmpty)
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
          if (_sahibiyim)
            ListeDuzenleDugmesi(
              duzenleme: _duzenleme,
              onDegis: () => setState(() => _duzenleme = !_duzenleme),
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
