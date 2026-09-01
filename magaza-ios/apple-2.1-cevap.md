# Apple Guideline 2.1 "Information Needed" — cevap taslağı (1 Eyl 2026)

Ret: iOS 1.103.2 (165), "2.1.0 Performance: App Completeness". İçerik reddi
değil, bilgi talebi. Cevap App Store Connect → App Review → iOS Submission
sayfasındaki mesaja **Reply** ile verilir; video da oraya eklenir.

## 1) EKRAN KAYDI — kullanıcı çekmeli (fiziksel iPhone şart)

Apple açıkça "fiziksel cihazda, güncel OS'te" diyor; simülatör kaydı kabul
edilmez. Yol: iPhone'a **TestFlight**'tan build 165'i kur → Ayarlar > Kontrol
Merkezi'ne "Ekran Kaydı"nı ekle → kaydı başlat → aşağıdaki akışı tek seferde
gez (3-5 dk yeter):

1. Uygulamayı AÇILIŞTAN başlat (kayıt uygulama açılmadan önce başlamalı).
2. **Hesap aç** (yeni bir e-postayla) → bildirim izni istemi görünsün.
3. Ana akışı gez: arama → bir dizi aç → bölüm işaretle → puan ver.
4. **UGC mekanizmaları** (Apple özellikle istiyor):
   - bir yoruma **şikâyet** (report) ver,
   - bir kullanıcıyı **engelle**,
   - kendi yorumunu yaz ve sil.
5. Profil fotoğrafı değiştir → **foto/kamera izni istemi** görünsün.
6. Ayarlar → **hesabı sil** akışını sonuna kadar göster (2. adımda açılan
   çöp hesapla — gerçek hesap silinmesin).
7. Kaydı bitir; dosyayı Mac'e AirDrop'la.

## 2-7) YAZILI CEVAP (İngilizce, Reply kutusuna yapıştırılacak)

> Hello, thank you for the review. Here is the requested information:
>
> **1. Screen recording:** Attached. It was captured on a physical iPhone
> [MODEL, iOS SÜRÜMÜ — kullanıcı dolduracak] and shows launch, account
> registration, the notification permission prompt, core tracking flows
> (search, marking episodes watched, rating), user-generated content with
> reporting and blocking, the photo-library permission prompt, and the
> in-app account deletion flow.
>
> **2. Devices tested:** iPhone [MODEL] (iOS [SÜRÜM], physical device) and
> Xcode Simulators (iPhone 17 Pro Max, iPad Pro 13-inch) during development.
> The same codebase (Flutter) has been in production on Google Play since
> July 2026 and is tested on physical Android devices as well.
>
> **3. What the app is:** Dizi JPG is a TV-show and movie **tracking and
> journaling** social app (a Turkish-first alternative to apps like TV Time /
> Letterboxd, localized into 45 languages). Users keep a diary of episodes
> and films they watched, rate and review them, build lists, follow friends,
> see watching statistics and get new-episode notifications. Target audience:
> general TV/film enthusiasts (rated 12+). The problem it solves: keeping
> track of what you watched, where you left off, and what your friends think.
>
> **4. Setup / access:** No special setup or hardware is required. Sign-in
> is email + password only. A demo account with pre-populated data is
> provided in App Review Information: import-test-2226@dizijpg.com /
> test1234. Registration is also open and free.
>
> **5. External services:** TMDB (The Movie Database) API for catalog
> metadata and artwork; our own backend REST API at dizijpg.com (accounts,
> diary, social features); Firebase Cloud Messaging for push notifications;
> YouTube's official embedded player for trailers only. No payment
> processors, no ads SDKs, no AI services, no third-party sign-in.
>
> **6. Regional differences:** None. The app functions identically in all
> regions; only the interface language and catalog metadata localization
> change with the device locale.
>
> **7. Third-party content:** The app does **not** host, stream, or link to
> any episodes or films and offers no playback of protected video content.
> It is a tracking/journal app. Catalog metadata and artwork are obtained
> from the TMDB API in accordance with TMDB's API Terms of Use, with TMDB
> attribution in the app; trailers are played only through YouTube's
> official embedded player. This is also declared under Content Rights in
> App Information.

## Ayrıca yapılacak

- Aynı bilgileri **App Review Information → Notes** alanına da yaz (Apple
  "future submissions" için bunu istedi) — API'den PATCH edilebilir.
- Cevap + video gönderildikten sonra **Resubmit to App Review**.
- [MODEL] / [SÜRÜM] boşluklarını kullanıcının iPhone bilgisiyle doldur.
