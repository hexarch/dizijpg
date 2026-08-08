import 'package:flutter/material.dart';

import '../tema.dart';
import 'giris_istem.dart';
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
        // Oturumsuz ziyaretçinin alt gezinme çubuğu yoktur; bu buton olmasa
        // sayfada çıkışsız kalırdı (içerik sayfalarındaki kalıbın aynısı).
        actions: const [GirisEylemi()],
      ),
      body: ListeIcerigi(
        listeId: widget.listeId,
        onListe: (l) {
          if (mounted) setState(() => _liste = l);
        },
      ),
    );
  }
}
