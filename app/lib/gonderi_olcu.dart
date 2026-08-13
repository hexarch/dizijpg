import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'api.dart';

/// GÖNDERİ ÖLÇÜLERİ (md. 23) — istemcinin sunucuya bildirdiği kapalı sözlük.
///
/// ===========================================================================
/// NEDEN AYRI DOSYA
/// ===========================================================================
/// Etiketler DÖRT ekrana dağılmış durumda (akış, keşfet/Reels, yorumlar,
/// gönderi sayfası). Her birinde elle `'akis'` yazılsaydı bir yerde `'akış'`
/// (Türkçe ş ile) ya da `'feed'` yazılır, o görüntülenme sessizce "Diğer"
/// kovasına düşer ve kimse fark etmezdi. Sabitler tek yerde durunca yazım
/// hatası DERLEME hatası olur.
///
/// SUNUCUYLA AYNI SÖZLÜK: `backend/gonderi_istatistik.js` içindeki
/// `GONDERI_KAYNAKLARI` ve `GONDERI_ISTEMCI_OLCULERI` ile birebir. Sunucu
/// tanımadığı etiketi ATMAZ, 'diger' kovasına koyar — böylece kaynak toplamı
/// görüntülenme toplamını tutmaya devam eder.
///
/// ===========================================================================
/// GİZLİLİK
/// ===========================================================================
/// Burada gönderilen HİÇBİR ŞEY kişi bildirmez: sunucuya yalnız "şu gönderi,
/// şu ölçü, +1" gider ve tabloya (gönderi, ölçü) → adet yazılır. Kimin
/// paylaştığı/profile gittiği hiçbir yerde durmaz.
class GonderiOlcu {
  GonderiOlcu._();

  // --- Görüntülenme kaynakları (POST /akis/goruldu gövdesindeki `kaynak`) ---
  /// Sosyal akış kartı.
  static const kaynakAkis = 'akis';

  /// Bir kullanıcı profilindeki gönderi ızgarası.
  static const kaynakProfil = 'profil';

  /// Tam ekran dikey akış (Reels).
  static const kaynakReels = 'reels';

  /// Dizi/film/kişi sayfasındaki yorum listesi. (Sunucu bunu KENDİ yazar —
  /// istemcinin bildirmesine gerek yok; sabit yalnız bütünlük için burada.)
  static const kaynakDizi = 'dizi';

  /// Paylaşılan bağlantıdan açılan tek gönderi.
  static const kaynakPaylasim = 'paylasim';

  // --- İstemcinin bildirdiği dönüşümler (POST /gonderi/:id/olay) -----------
  /// Gönderi paylaşıldı (DM, sistem paylaşımı ya da bağlantı kopyalama).
  static const paylasim = 'paylasim';

  /// Gönderiden yazarın profiline gidildi.
  static const profilZiyaret = 'profil_ziyaret';

  /// Gönderiden dizinin/filmin sayfasına gidildi.
  static const icerikTikla = 'icerik_tikla';

  /// Spoiler perdesi açıldı.
  static const spoilerAcildi = 'spoiler_acildi';

  /// Tek bir ölçüyü ATEŞLE-UNUT bildirir.
  ///
  /// Hata YUTULUR ve kullanıcıya gösterilmez: bir istatistik sayacı yüzünden
  /// paylaşım sayfasında hata balonu çıkarmak, ölçünün değerinden pahalıdır.
  /// Girişsiz kullanıcıda uç 401 döner ve yine sessizce düşer.
  static void bildir(Object? gonderiId, String olcu) {
    final id = gonderiId is int ? gonderiId : int.tryParse('$gonderiId');
    if (id == null || id <= 0) return;
    Api.post('/gonderi/$id/olay', {'olcu': olcu}).catchError((_) => null);
  }
}

/// Gönderi kartından YAZARIN PROFİLİNE git ve atfı bildir.
///
/// ATIF NEDEN İSTEMCİDEN: sunucu profil isteğine bakıp "bu kişi hangi
/// gönderiden geldi" diyemez — Referer güvenilmez, oturumda gezinti geçmişi
/// tutulmuyor ve tutulsaydı KİŞİ BAZLI iz olurdu. İstemcinin tek bir sayaç
/// artırması hem ucuz hem agregat.
void gonderidenProfile(BuildContext context, Map<String, dynamic> yorum) {
  GonderiOlcu.bildir(yorum['id'], GonderiOlcu.profilZiyaret);
  GoRouter.of(context).push('/kullanici/${yorum['kullanici_adi']}');
}

/// Gönderi kartından DİZİ/FİLM sayfasına git ve atfı bildir.
/// (`yol` çağıranda hesaplanıyor: bölüm yorumunda bölüm sayfası, genel
/// yorumda içerik sayfası açılır.)
void gonderidenIcerige(
  BuildContext context,
  Map<String, dynamic> yorum,
  String yol,
) {
  GonderiOlcu.bildir(yorum['id'], GonderiOlcu.icerikTikla);
  GoRouter.of(context).push(yol);
}
