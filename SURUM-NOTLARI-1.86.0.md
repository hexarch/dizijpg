# dizi.jpg 1.86.0 (136) — Play Console sürüm notları

Canlıdaki sürüm **1.51.0 (99)**, 15 Ağu 2026. Aradaki fark **74 commit / 5 gün**.
Play sürüm notu alanı dil başına **500 karakter** ile sınırlı; aşağıdakiler
sınırın altında.

> Mağaza girişi şu an yalnız **en-US** dilinde. Türkçe metni de ekledim; Play
> Console'da Türkçe yerelleştirme açılırsa doğrudan kullanılabilir.

---

## en-US (zorunlu — mağaza girişinin tek dili)

```
• Trailers now play inside the app — subtitles, 2x speed, ±10s skip
• Style video subtitles yourself: color, 30 fonts, edge and opacity
• New Watch Statistics screen
• Ratings, comments and sorting on production company pages
• Drag to reorder, hide or remove items in your lists
• Reliable "typing" and "recording" indicators in chat
• Noticeably faster startup
• Encrypted manual backup you can download
• Many color and readability fixes
```

(437 karakter)

---

## tr-TR (Türkçe yerelleştirme açılırsa)

```
• Fragmanlar artık uygulama içinde oynuyor: altyazı, 2× hız, ±10 sn atlama
• Video altyazılarını kendiniz biçimlendirin: renk, 30 yazı tipi, kenar, opaklık
• İzleme İstatistiklerim ekranı
• Yapım şirketi sayfalarına puan, yorum ve sıralama
• Listelerinizi sürükleyip sıralayın, gizleyin, kaldırın
• Sohbette "yazıyor" ve "ses kaydediyor" artık güvenilir
• Açılış belirgin şekilde hızlandı
• Şifreli elle yedek alma ve indirme
• Çok sayıda renk ve okunurluk düzeltmesi
```

(438 karakter)

---

## Yükleme öncesi kontrol listesi

Paket doğrulaması derleme ajanı tarafından yapıldı (1.86.0+136 için tekrarlanacak):

- [ ] İmza sahibi `CN=dizi.jpg` — parmak izi önceki sürümle **aynı**
      (farklıysa Play reddeder; mevcut kurulumlar güncellenemez)
- [ ] `versionCode` = 136 — canlıdaki 99'dan büyük
- [ ] `versionName` = 1.86.0
- [ ] Birleştirilmiş manifestte `allowBackup=false`
- [ ] AAB'de `lib/x86_64/` **var** (emülatör kullanıcıları için)
- [ ] `pro_image_editor` kodu pakette

## Yükleme sırasında dikkat

1. **İzleme (track) seçimi** — Üretim mi, kapalı test "Alpha" mı? Üretim tüm
   kullanıcılara gider; kapalı test 27 testçiye.
2. **Aşamalı yayın (staged rollout)** — 74 commit'lik bir sıçrama. %100 yerine
   %20 ile başlayıp çökme oranına bakmak, sorun çıkarsa yayını durdurma
   imkânı verir. Yayına başladıktan sonra durdurulabilir ama **güncellemeyi
   almış kullanıcılardan geri alınamaz.**
3. **Google incelemesi** — üretim sürümleri incelemeden geçer. Süre saatlerle
   birkaç gün arasında değişir ve **bizim kontrolümüzde değildir**; "bu gece
   gönder, sabah yayında" garanti edilemez.
4. **Veri güvenliği formu** — yeni izin/veri toplama eklenmedi, formda
   değişiklik gerekmemeli. Yine de Console uyarı verirse yüklemeden önce bak.

## Bu sürümde yeni olan ve mağaza girişinde GÖRÜNMEYEN şey

Altyazı biçimlendirme ekranı yeni bir özellik. Mağaza görselleri **30 Tem'den
beri güncellenmedi** ve eski sürüme ait — ekran görüntüsü eklemek bu sürüm
için zorunlu değil ama listelemede eksik kalıyor. Ayrı bir iş olarak duruyor.
