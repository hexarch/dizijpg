# Apple 4.8 (Login Services) reddine cevap — 10 Eyl 2026

Ret: Guideline 4.8 — Google ile giriş varken "eşdeğer" giriş (Sign in with
Apple) yoktu. Cevap Resolution Center'a İngilizce yazılır, ardından yeni
build (1.148.0 / 225) bağlanıp "Resubmit to App Review" basılır.

## Resolution Center mesajı (İngilizce, ≤ 4000 karakter)

Hello,

Thank you for the review. We have addressed Guideline 4.8 by adding Sign in
with Apple as an equivalent login option and are resubmitting with build
1.148.0 (225).

What changed in this build:

1. Sign in with Apple is offered on the login screen directly below "Continue
with Google", using Apple's standard button ("Continue with Apple"). It is
available on every entry point where Google sign-in is available on iOS.

2. The Apple sign-in flow requests only name and email. Users can choose
"Hide My Email"; private relay addresses are fully supported (the account is
linked by the stable Apple user identifier, not by the email address). No
interaction data is collected for advertising — the app contains no
advertising or analytics SDKs.

3. Accounts created with Sign in with Apple can be deleted in-app
(Settings → Delete My Account) without a password, and on deletion the app's
authorization is revoked through Apple's token revocation endpoint, in line
with Guideline 5.1.1(v).

4. The identity token is verified server-side against Apple's public keys
(issuer, audience, expiry and nonce are checked).

Metadata: the App Store screenshots do not show the login screen, so no
screenshot changes were required.

The demo account and all other information from our previous reply are
unchanged.

Thank you.

## App Review Notes'a eklenecek paragraf

Sign in with Apple (Guideline 4.8) is available on the login screen below
"Continue with Google". It requests name and email only, supports Hide My
Email, and accounts created this way can be deleted in Settings → Delete My
Account without a password (the Apple authorization is revoked via the token
revocation API on deletion).
