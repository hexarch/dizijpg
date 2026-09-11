# Apple 4.8 (Login Services) reddine cevap — 11 Eyl 2026 (build 1.148.2 / 227)

Ret (10 Eyl 13:31): Guideline 4.8 — Google ile giriş varken "eşdeğer" giriş
(Sign in with Apple) yoktu. 11 Eyl taraması ek riskleri kapattı (aşağıda).
Cevap Resolution Center'a İngilizce yazılır (kullanıcı, tarayıcıdan);
Review Notes ASC API ile güncellenir; build 227 sürüme bağlanıp yeniden
gönderilir.

## 11 Eyl taramasında bulunup kapatılan ek ret riskleri

| Kılavuz | Bulgu | Yapılan |
|---|---|---|
| 2.1 (çalışmayan özellik) | iOS'ta "Google ile devam et" hiç çalışmıyordu: Info.plist'te `GIDClientID`/URL şeması yok, Firebase'de iOS uygulaması kayıtlı değildi | Firebase iOS uygulaması (Management API), `GoogleService-Info.plist` Runner kaynağına, `GIDClientID`+`GIDServerClientID`+`CFBundleURLTypes` |
| 2.1 | flutter_local_notifications iOS ayarı boş → izin sonrası kurulum hata fırlatıyordu | `DarwinInitializationSettings` eklendi |
| 5.2.3 (telif) | İzleme odasına 5 GB'a kadar dosya yüklenip başkalarına akıtılıyor; inceleme notu "uygulama bölüm barındırmaz" diyordu | Her yüklemeden önce telif onayı diyaloğu; notlar dürüstçe güncellendi (özel oda, davet/kod, 12 saat, yalnız sahibinin dosyası) |
| 1.2 (UGC) | Sıfır tolerans + şikâyet/engelleme + 24 saat taahhüdü yazılı değildi | Gizlilik politikasına "Topluluk Kuralları" bölümü (uygulama + web, 46 dil); kayıt formu bu sayfayı "kabul etmiş olursun" ile bağlıyor |

## Resolution Center mesajı (İngilizce, ≤ 4000 karakter)

Hello,

Thank you for the review. We have addressed Guideline 4.8 by adding Sign in
with Apple as an equivalent login option and are resubmitting with build
1.148.2 (227).

What changed:

1. Sign in with Apple is offered on the login screen directly below "Continue
with Google", using Apple's standard button. It is available on every entry
point where Google sign-in is available on iOS.

2. The Apple sign-in flow requests only name and email. "Hide My Email" is
supported; private relay addresses work because the account is linked by the
stable Apple user identifier, not by the email address. No interaction data is
collected for advertising; the app contains no advertising or analytics SDKs.

3. Accounts created with Sign in with Apple can be deleted in-app (Settings >
Delete My Account) without a password, and the app's authorization is revoked
through Apple's token revocation endpoint on deletion (Guideline 5.1.1(v)).

4. The identity token is verified server-side against Apple's public keys
(issuer, audience, expiry and nonce).

While preparing this build we also fixed the iOS configuration of "Continue
with Google" (it now completes on iOS) and added a written Community
Guidelines section (zero tolerance for objectionable content, in-app
reporting and blocking, 24-hour review) to the privacy policy that users
accept at registration.

Metadata: the App Store screenshots do not show the login screen, so no
screenshot changes were required. The demo account and all other information
from our previous reply are unchanged.

Thank you.

## App Review Notes (ASC API ile yazılacak tam metin)

WHAT THE APP IS (Guideline 2.1 info): Dizi JPG is a TV-show and movie TRACKING and journaling social app (a Turkish-first alternative to TV Time / Letterboxd, localized into 45 languages). Users keep a diary of episodes and films they watched, rate and review them, build lists, follow friends, see statistics and get new-episode notifications. Target audience: general TV/film enthusiasts (12+). The app does NOT host, stream, or link to episodes or films of the shows in its catalog; catalog metadata and artwork come from the TMDB API under TMDB's terms (with attribution in-app), streaming availability info from JustWatch via TMDB, and trailers play only through YouTube's official embedded player.

ACCESS: The app can be browsed without an account (discover, title/person/company pages, search, calendar). An account is needed for marking, rating, commenting, DMs and stats. Demo account (pre-populated library: 5552 episodes, 417 movies, 113 shows): import-test-2226@dizijpg.com / test1234. Sign-in options: email + password, Continue with Google, and Sign in with Apple (Guideline 4.8, added in 1.148.0). Sign in with Apple requests name and email only, supports Hide My Email, and accounts created with it can be deleted in Settings > Delete My Account without a password; the Apple authorization is revoked via Apple's token revocation API on deletion. No special setup or hardware required.

USER-GENERATED CONTENT (Guideline 1.2): comments, photos, videos and GIFs. Users accept the privacy policy and Community Guidelines at registration (zero tolerance for objectionable content and abusive users). Moderation: (1) every comment, post, message, user, list and GIF has an in-app report option (... menu) feeding a moderation queue reviewed within 24 hours; (2) user blocking (Settings > Blocked users); (3) comment hiding; (4) accounts that break the rules are closed. Spoiler protection hides comments for unwatched episodes by default. Account deletion is available in-app (Settings).

WATCH ROOMS: a private "watch together" room (invite or room code only, max. a few members, closes automatically after 12 hours). The host can paste a YouTube/Vimeo link or a direct video URL, or upload a video file they own; every upload requires an explicit copyright confirmation, the file is visible only to invited members and is deleted when the room closes. Rooms have in-app reporting like all other content.

EXTERNAL SERVICES: TMDB API (metadata/artwork), our own backend REST API at dizijpg.com (accounts, diary, social), Firebase Cloud Messaging (push), YouTube embedded player (trailers only). No payment processors, no ads SDKs, no AI services. Third-party sign-in: Google Sign-In and Sign in with Apple (both used only for authentication).

REGIONAL DIFFERENCES: none - the app functions identically in all regions; only UI language and metadata localization follow the device locale.

TESTED ON: physical iPhone via TestFlight and Xcode Simulators (iPad Air 13-inch, iPhone 17 Pro); the same Flutter codebase has been in production on Google Play since July 2026.
