# Play mağaza girişi — yenileme paketi (16 Ağustos 2026)

Mağaza girişi **30 Temmuz 2026**'dan beri güncellenmemişti; görseller ~1.2x
sürümüne aitti ve giriş **yalnız en-US** dilindeydi. Bu klasör yenisini içerir.

## Ekran görüntüleri

`ekran-goruntuleri/tr-TR` ve `ekran-goruntuleri/en-US` — her biri **8 kare**,
hepsi **1080×1920 PNG (tam 9:16)**, en büyüğü 1,8 MB (Play sınırı 8 MB).

Nasıl üretildi: Android emülatörü (Medium_Phone_API_36.1), APK **1.67.0+115**,
`wm size 1080x1983` + `wm density 420` ile çekilip üstten 63 px durum çubuğu
kesildi — bu yüzden ölçek bozulmadan tam 9:16 çıkıyor. Hesap `@testkullanici`
(test hesabı; gerçek kullanıcı verisi yok).

| # | tr-TR | en-US | Ne gösteriyor |
|---|-------|-------|----------------|
| 1 | 1-ana-sayfa | 1-home | Sana Özel önerileri + haftanın dizileri |
| 2 | 2-dizi-sayfasi | 2-show-page | Fragman, TMDB + dizi.jpg puanı, izleme durumu çipleri |
| 3 | 3-bolum-isaretleme | 3-episode-tracking | Sezon ilerleme halkaları + bölüm işaretleme |
| 4 | 4-takvim | 4-calendar | Yaklaşan bölümler takvimi |
| 5 | 5-bolum-isi-haritasi | 5-episode-heatmap | TMDB bölüm ısı haritası (rakipsiz özellik) |
| 6 | 6-istatistik-kutuphane | 6-stats-library | Toplam izleme süresi, sayaçlar, kütüphane |
| 7 | 7-incelemeler | 7-reviews | İnceleme akışı (en-US'te otomatik çeviri + "Show original") |
| 8 | 8-kesfet | 8-discover | Keşfet ızgarası (spoiler gizli kare dahil) |

Yedekler (`tr-TR/yedek-*`): "Nerede İzlenir" (JustWatch) ve "Gözat" (türe göre).
İlk 8'den biri beğenilmezse bunlarla değiştirilebilir.

## Metinler

`metinler/` altında 10 dil: **tr-TR, en-US, de-DE, fr-FR, es-ES, it-IT, pt-BR,
ru-RU, ar, id**. Her dosyada uygulama adı + kısa açıklama + tam açıklama;
hepsi Play sınırlarının altında doğrulandı (betikle sayıldı, en uzun kısa
açıklama 77/80).

30 Temmuz metnine göre eklenenler: uygulama içi fragman, bölüm ısı haritası,
puan dağılımı, yapım ekibi/firma, hareketli emoji tepkileri, özel mesajlaşma,
otomatik yorum çevirisi, yeni bölüm bildirimi, iki adımlı doğrulama, seviye
ve rozetler.

**Sesli/görüntülü aramadan hiçbir dilde bahsedilmiyor** — özellik 13 Ağustos'ta
sunucudan kapatıldı, mağaza metniyle çelişki olmasın diye bilinçli olarak dışarıda.

## Play Console'a yükleme sırası

1. Test edin ve yayınlayın → Play Store'daki varlığı → Mağaza girişleri →
   Varsayılan mağaza girişi.
2. **Önce en-US**: kısa + tam açıklamayı `metinler/en-US.md`'den yapıştır,
   telefon ekran görüntülerinde eski 6 kareyi sil, `en-US/` klasöründeki 8'i yükle.
3. **Çevirileri yönet → Dilleri seçin** ile 9 dili ekle, her biri için o dilin
   dosyasındaki metni gir. Görsel yüklemezsen Play otomatik olarak varsayılan
   dilin (en-US) karelerini kullanır — **tr-TR için `tr-TR/` karelerini ayrıca
   yükle**, hedef kitle orası.
4. Tablet kareleri de eskidir; şimdilik dokunulmadı (Play zorunlu tutuyor,
   mevcutlar duruyor). Yenilemek için aynı yöntem `Pixel_Tablet` AVD'siyle.
5. **Kaydet yetmez**: Yayın özeti → "N değişikliği incelemeye gönder".

## Açık kalan işler

- Uygulama başlığındaki `v1.67.0` sürüm etiketi ana sayfa karesinde görünüyor.
  Mağaza için pek şık değil; sürüm etiketini yalnız hata ayıklama derlemesinde
  göstermek iyi olur.
- Tanıtım videosu alanı hâlâ boş (Play'de dönüşümü belirgin artırıyor).
- Uygulama adı 10 dilde de `Dizi JPG` bırakıldı. Play dil başına 30 karaktere
  izin veriyor; ASO için ör. tr-TR'de `dizi.jpg – Dizi ve Film Takip` (29)
  ciddi kazanç sağlar ama bu bir marka kararı, o yüzden değiştirilmedi.
