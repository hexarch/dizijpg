import 'package:video_player/video_player.dart';

/// Ağdan oynatılan HER videonun ortak seçenekleri (10 Eyl 2026).
///
/// Şikâyet: "video komple yüklenmiş, alt barda gri görünüyor ama 1. saniyeye
/// alınca tekrar yükleniyor." Sebep Android'deki ExoPlayer'ın GERİ TAMPONU:
/// varsayılanı SIFIR, oynatılıp geçilen kısım bellekten anında atılıyor,
/// geri sarınca ağdan yeniden çekiliyor. Gri çubuk ise eklentinin tek sayı
/// ("şu saniyeye kadar") bildirimini 0'dan başlayan tek aralık olarak çizer;
/// yani "her şey yüklü" görüntüsü yanıltıcıydı. `backBufferDurationMs` ile
/// ExoPlayer geçilen kısmı anahtar kareden itibaren tutar; süre içinde geri
/// sarma ağa çıkmaz. iOS (AVPlayer) ve web zaten kendi tamponunu tutar,
/// seçenek orada yok sayılır.
///
/// Değerler bellek pahasına: geri tampon RAM'de durur. Kısa klipler (Reels,
/// akış kartı, yorum, tam ekran görüntüleyici) için 60 sn ≈ 15-30 MB; izleme
/// odasındaki uzun filmler için 120 sn. Daha uzunu birden çok önden kurulan
/// Reels sayfasında toplanıp düşük belleği zorlar.
VideoPlayerOptions videoSecenekleri({bool uzun = false}) =>
    VideoPlayerOptions(backBufferDurationMs: uzun ? 120000 : 60000);
