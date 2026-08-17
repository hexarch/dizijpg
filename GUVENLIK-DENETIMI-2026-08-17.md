# dizi.jpg — Güvenlik Denetimi (3. tur)

> ## ⟶ DURUM GÜNCELLEMESİ — 17 Ağustos 2026, aynı gün
>
> **İki KIRMIZI bulgunun ikisi de KAPATILDI ve canlıda doğrulandı.**
> Bu rapordaki geri kalan bulgular hâlâ açıktır.
>
> | # | Bulgu | Durum | Kanıt |
> |---|---|---|---|
> | 3.1 | Kotasız yükleme → disk doldurma DoS | **KAPANDI** | `backend/disk.js` + 23 test; canlı: eşik geçici 999 GB → `POST /medya` ve `/profilim/avatar` **507 `DEPO_DOLU`**, `GET /medya` + `/saglik` **200** (okuma etkilenmiyor); eşik geri alınınca yükleme yeniden **200**. Sürüm 1.76.0+124 |
> | 3.2 | 56 güvenlik yaması bekliyor, otomatik güncelleme yok | **KAPANDI** | `unattended-upgrade` çalıştırıldı → bekleyen güvenlik yaması **56 → 0**; `unattended-upgrades` kuruldu, **yalnız `-security`** deposuna daraltıldı (`52unattended-upgrades-dizijpg`, `#clear` ile), zamanlayıcı `20auto-upgrades` ile açıldı; çekirdek **6.1.0-45 → 6.1.0-52**, yeniden başlatıldı |
>
> **Yeniden başlatma:** makine 20 saniyede döndü. Reboot ÖNCESİ tüm çalışan
> servislerin `enabled` olduğu tek tek tarandı (paylaşımlı makine — başka
> projeler var). Sonrasında doğrulandı: nginx, postfix, dovecot, docker,
> fail2ban, coturn, postgresql, restaurant, dizijpg-frontend, brnmedia
> hepsi ayakta; üç konteyner ayakta; iptables kuralları (5432/6379 DROP +
> DOCKER-USER) korunmuş; https://dizijpg.com **200**.
>
> **Not:** `brnmedia.service` systemd'de "activating" görünüyor ama 8001'de
> yanıt veriyor (301). Sebep birimin `Type=forking` olması — gunicorn beklenen
> pidfile'ı yazmıyor. Bu durum reboot ÖNCESİNDE de aynıydı, başka bir projeye
> ait ve bu denetimde DEĞİŞTİRİLMEDİ.
>
> **Yan etki:** yalnız iki geçici test dosyası yüklendi ve silindi; `.env`e
> eklenen geçici `DISK_ESIK_GB=999` satırı kaldırıldı ve dosyanın yedekle
> **birebir aynı** olduğu `diff` ile doğrulandı.
>
> ### İkinci tur — aynı gün, kalan maddeler
>
> | # | Bulgu | Durum |
> |---|---|---|
> | 3.1 kalan | Kota/limit yok | **KAPANDI** — misafir yükleme 40→5/saat; IP başına 1 GB/saat bayt bütçesi; %82'de disk alarmı (10 dk cron) |
> | 4.1 | `/api/Admin` harf bypass'ı | **KAPANDI** — `location ~* ^/api/admin { return 404; }`; dört yazım da 404 |
> | 4.2 | Hesap ön-kaçırma | **KAPANDI** — `eposta_dogrulandi` kolonu; Google girişi doğrulanmamış hesaba düşerse şifre+oturum iptal + bilgilendirme postası |
> | 4.3 | DB süper kullanıcı | **KAPANDI** — `dizijpg_app` (yalnız CONNECT+DML); süper kullanıcı yalnız migrasyon |
> | 4.4 | Konteyner root | **KISMEN** — `no-new-privileges` + `cap_drop: ALL` uygulandı; `USER node` ertelendi (aşağıda) |
> | 4.5 | CSP yok | **KAPANDI (Report-Only)** — 8/8 blokta; `Permissions-Policy` deliği de kapatıldı (2/8 → 8/8) |
> | 4.8 | Lock yok, 2 yüksek npm açığı | **KAPANDI** — `npm ci` + lock; nodemailer 9, geoip-lite 2; **0 yüksek** (8 orta kaldı) |
> | 5.1 | Zip bombası | **KAPANDI** — beyan edilen boyut açmadan önce kontrol ediliyor |
> | 5.3 | `/altyazi` özel medya kapısı | **KAPANDI** — `OZEL_MEDYA` kontrolü eklendi |
>
> **İki hata yaşandı, ikisi de yakalandı ve belgelendi:** (1) rol geçişinde
> parola çift tırnaklandı, uygulama ~3 dakika 28P01 ile 500 döndü — SQL'in
> kendi kullanım notu tuzağı kuruyordu, düzeltildi; (2) `CONNECTION LIMIT 50`
> havuz tavanıyla (80) çelişiyordu, 90'a çıkarıldı. Ayrıca ilk bayt bütçesi
> işçi başına kurulmuştu ve canlı ölçümde tutmadı (4 kat gevşek); işçi
> sayısına bölündü ve yeniden ölçüldü.
>
> **firebase-admin 14.2.0 denendi ve GERİ ALINDI:** varsayılan dışa aktarımda
> `credential` ve `messaging` yok; server.js `initializeApp`i try/catch içinde
> çağırdığı için hata yutulur ve **push sessizce ölürdü**. Kalan 8 orta açık
> (uuid zinciri) bu yüzden bilerek duruyor — npm'in "düzeltmesi" zaten
> firebase-admin'i 10.3.0'a **düşürmek**.
>
> ### Hâlâ açık (ve neden)
>
> | # | Bulgu | Neden hâlâ açık |
> |---|---|---|
> | 4.4 | `USER node` | `/yedekler` 700 root:root ve gece cron'u root yazıyor. uid 1000'e almak §3.2'yi bozma riski taşır — ayrı, dikkatli bir tur işi |
> | 4.6 | Sunucu dışı yedek | **Hedef ve kimlik bilgisi kullanıcıdan gerekiyor** (B2 / S3 / 154.53.163.5) |
> | 4.7 | `MEDYA_IMZA_ZORUNLU` | `MEDYA_SAYAC.imzasiz_ozel` okunmalı; admin paneli IP kısıtlı, denetim makinesi listede değil |
> | 4.9 | Origin sertifikası | **Cloudflare paneli gerekiyor** — Origin Certificate üret + SSL modu Full (strict) |
> | 4.5 | CSP zorunlu kılma | Report-Only ölçümü birkaç gün beklemeli; `GET /api/admin/csp` `toplam: 0` ise zorunlu yapılır |
> | 5.4 | Anonim `/hata-bildir` şişmesi | Etki düşük (metin); saklama süresi/budama eklenebilir |
> | 5.5 | nginx.conf'ta TLS 1.0/1.1 | dizi.jpg vhost'u zaten 1.2/1.3 ile eziyor; genel satır **başka projelerin** vhost'larını da etkilediği için dokunulmadı |
> | 3.1 | Kullanıcı başına toplam kota | Bayt bütçesi + eşik kapısı riski pratikte kapattı; kalıcı kota muhasebesi (silmede azaltma) ayrı iş |
>
> Ayrıntı ve yeni bulgular (compose'un `DISK_ESIK_GB`/`IP_BAYT_SAAT_GB`'yi
> aktarmaması): `YAPILACAKLAR.md` → 17 Ağustos maddeleri.

**Tarih:** 2026-08-17 · **Kapsam:** tüm uygulama + sunucu (`154.53.163.3` / karanew,
`/opt/dizijpg`, https://dizijpg.com) · **Yöntem:** SALT OKUMA.
Kod okuması (`backend/**`, `admin.html`, nginx/compose/Dockerfile) + sunucuda
yalnız okuma komutları + dışarıdan kimliksiz HTTP yoklaması.
Hiçbir dosya/ayar değiştirilmedi, hiçbir servis yeniden başlatılmadı, DB'ye
yalnız `SELECT`/rol sorgusu çalıştırıldı, hesap oluşturulmadı, dosya yüklenmedi.
Gerçek kullanıcı `alcelik` (id=3) verisine dokunulmadı. Sır DEĞERİ bu rapora
yazılmadı (yalnız uzunlukları).

---

## 1. Yönetici özeti

> **Kimlik doğrulamasını atlayıp başka kullanıcının verisini ele geçiren bir
> açık YİNE BULUNAMADI.** Uygulama katmanı (SQL, yetkilendirme, oturum,
> şifreleme) bu turda da temiz çıktı. Bu turun iki ciddi bulgusu **erişilebilirlik**
> (servisi çökertme) ve **yama yönetimi** tarafında; bir bulgu ise hesap devralma
> senaryosu.
>
> Ayrıca: **7 Ağustos denetiminde "KOD HAZIR" denen düzeltmelerin ikisi hâlâ
> canlıya uygulanmamış** (DB rolü, medya imza zorunluluğu) ve **CSP üçüncü
> denetimdir açık**.

**Bulgu sayısı:** KIRMIZI **2** · SARI **9** · Düşük/bilgi **7**

**En acil üçü:**

1. **[KIRMIZI] Diski doldurup tüm sunucuyu durdurma — 10 dakikada, bedava.**
   Misafir hesap anında açılıyor (IP başına 30/saat), her hesap 40×100 MB
   yükleyebiliyor. Tek IP'den saatte ~120 GB. Diskte **21 GB boş** var ve
   kota/disk alarmı YOK. Disk dolunca dizi.jpg, veritabanı, gece yedeği ve
   **aynı makinedeki diğer projeler + posta sunucusu** birlikte durur.
2. **[KIRMIZI] 146 bekleyen paket güncellemesi, 56 tanesi güvenlik yaması;
   otomatik güncelleme kurulu değil.** Aralarında `openssl`, `libgnutls30`,
   `libkrb5`, `libnss3`, `bind9` ve **doğrudan internete açık `dovecot`**
   (110/143/993/995) var. Cloudflare bu servisleri korumuyor — saldırgan
   origin IP'ye doğrudan bağlanıyor.
3. **[SARI] `/api/Admin/...` nginx IP kapısını BÜYÜK HARFLE atlıyor.**
   `/api/admin/ozet` → 404 (nginx keser), `/api/Admin/ozet` → **403 (Express'e
   ulaştı)**. Bugün sömürülemiyor çünkü ikinci kapı (`adminKisit`) tutuyor;
   ama iki katmandan biri düştü ve `ADMIN_TOKEN` sızarsa panel artık
   **dünyanın her yerinden** açılır (IP kapısı devrede olmadığı için).

---

## 2. Doğrulanmış olarak KAPALI / SAĞLAM olanlar

Önce iyi haber — bu turda tek tek kanıtlandı:

| Alan | Durum | Kanıt |
|---|---|---|
| SQL enjeksiyonu | **TEMİZ** | Tüm sorgular parametreli. Dize birleştirilen tek şey KOD SABİTİ tanımlayıcılar (`TERCIH_ALANLARI`, `BILDIRIM_TERCIH_KOLON`, `engelSuzgec`'in `$N` yer tutucusu). Kullanıcı girdisi hiçbir SQL'e metin olarak girmiyor. |
| Yedekler | **DÜZELDİ** | `/opt/dizijpg/yedekler` → `700 root:root`, dosyalar `600` ve `.gpg` (AES). Gece 04:00 cron çalışıyor: `dizijpg-20260817-0400.sql.gz.gpg` (165 MB) bugün alınmış. |
| CF atlanarak origin'e bağlanma | **KAPALI** | `curl -H "Host: dizijpg.com" https://154.53.163.3/...` → bağlantı kapatıldı (444). |
| SSH | **SAĞLAM** | `passwordauthentication no`, `permitrootlogin without-password`, `kbdinteractive no`. fail2ban aktif (sshd/dovecot/postfix-sasl). Kabuklu tek kullanıcı `kara`; `admin`/`noreply` → `nologin`. |
| Güvenlik duvarı | **SAĞLAM** | `INPUT` politikası `DROP`. 5432 yalnız 3 IP'ye, 6379 yalnız yerele/docker ağına; `DOCKER-USER` zincirinde de `--dport 6379 -j DROP` var (docker-proxy'nin INPUT'u atlaması kapatılmış). |
| Admin paneli XSS | **KAPALI** | `esc()`/`escJs()` tüm kullanıcı içerikli alanlarda; `kAd()`, `ic()`, `ciAd()` yardımcıları da kaçırıyor. Gelen posta HTML'i `<iframe sandbox srcdoc>` içinde (script çalışmaz). |
| DM şifrelemesi | **AÇIK** | AES-256-GCM zarf (`v1.k1.iv.tag.ct`), anahtar kimliği + AAD, her mesajda taze IV. Anahtar yoksa süreç açılmıyor. `MESAJ_ANAHTARI` 43 karakter (=32 bayt). |
| İmzalı medya URL'si | **KOD CANLIDA** | `medya_imza.js` (HMAC-SHA256/128 bit, 12 saatlik kova, sabit-zamanlı karşılaştırma, yol-geçişi kalıbı). DM medyası `private, no-store` ile dönüyor → CF edge'de public kopya birikmiyor. *(Ama zorunluluk kapalı — §4.7)* |
| X-Accel-Redirect (D2) | **SAĞLAM** | `GUVENLI_AD` kalıbı `/`, `..` ve nokta-başı adı reddediyor; nginx `/ic-dosya/`, `/ic-ozel/` `internal` (dışarıdan istenirse 404). |
| TURN (coturn) | **SERTLEŞTİRİLMİŞ** | `use-auth-secret` (açık röle yok), `denied-peer-ip` RFC1918 + loopback + link-local + kendi /29'u, `user-quota=4`, `max-bps`, `proc-user=turnserver`, `no-cli`. |
| Sır yönetimi | **SAĞLAM** | `.env` ve `firebase-admin.json` → `600 root:root`. Git geçmişinde `.env/.jks/key.properties/adminsdk` **hiç** eklenmemiş. İstemci kodunda gömülü API anahtarı yok. JWT_SECRET 64, ADMIN_TOKEN 48 karakter. |
| Şifre sıfırlama | **DÜZELDİ** | Hesap başına 5 deneme + sınıra ulaşınca kodu anında iptal; tek mesaj/tek durum kodu (sızıntı yok); istek limiti e-posta başına 5/saat. |
| Giriş | **SAĞLAM** | Kullanıcı sayımına karşı zamanlama eşitlemesi (sahte bcrypt hash'i), tek hata mesajı, IP başına 30/saat (küme geneli sayaçla). |

---

## 3. KIRMIZI bulgular

### 3.1 — [KIRMIZI] Kotasız yükleme → diski doldurup tüm makineyi durdurma

**Ne:**

| Kapı | Sınır | Kod |
|---|---|---|
| Misafir hesap açma | IP başına **30/saat**, e-posta/doğrulama yok | `server.js:3867` `/auth/misafir` + `authLimiti` |
| Medya yükleme | Kullanıcı başına **40/saat**, dosya başına **100 MB** | `server.js:6600` `/medya` + `yuklemeLimiti` |
| Toplam kota | **YOK** — ne kullanıcı başına, ne genel | — |
| Disk alarmı | **YOK** | `/usr/local/bin/dizijpg-saglik.sh` yalnız HTTP kodu bakıyor |

Tek IP'den saatlik tavan: `30 hesap × 40 yükleme × 100 MB` = **~120 GB/saat**.

**KANIT (sunucudan):**
```
df -h /   ->  80G toplam, 56G dolu, 21G BOŞ (%73)
du -sh /srv/dizijpg-veri/medya  ->  5.6G
crontab -l | grep saglik  ->  * * * * * dizijpg-saglik.sh   (yalnız HTTP yoklaması)
```
21 GB'ı doldurmak yukarıdaki hızda **~10 dakika** sürer.

**Etki — dizi.jpg'den çok daha geniş:** disk `/` üzerinde ve makine paylaşımlı.
Disk dolunca aynı anda: Postgres yazamaz (dizi.jpg **ve** host PG'deki
`dizipal`, `dopamall`, `dopamine_db`, `restaurant_db`), gece yedeği alınamaz,
Postfix/Dovecot posta kabul edemez, nginx log yazamaz, docker konteynerleri
çöker. Geri dönüş elle temizlik gerektirir.

**Not:** Bu senaryo **canlıda denenmedi** (denemek servisi durdurmak olurdu).
Kanıt kod + yapılandırma + boş disk ölçümüdür; matematik tek başına yeterince açık.

**Öneri (etkiye göre sıralı):**
1. **Disk eşiği kapısı (30 dk):** `POST /medya` ve `POST /veri/ice-aktar`
   başında `statfs` ile boş alan < 10 GB ise `507` dön. Tek satırlık savunma,
   en kötü senaryoyu tamamen kapatır.
2. **Kullanıcı başına toplam kota (2-3 saat):** `kullanicilar.medya_bayt`
   sütunu + yüklemede `UPDATE ... RETURNING` ile eşik kontrolü. Misafir için
   düşük (ör. 200 MB), bağlı hesap için yüksek (ör. 5 GB).
3. **Misafir hesap için ayrı, sıkı yükleme limiti** (ör. 40 yerine 5/saat) —
   maliyet/kazanç oranı en iyi tek satır.
4. **Disk alarmı** `dizijpg-saglik.sh`'a: `%85` üstünde uyarı maili.

---

### 3.2 — [KIRMIZI] İşletim sistemi güvenlik yamaları uygulanmamış; otomatik güncelleme yok

**KANIT:**
```
apt-get -s upgrade | grep -c "^Inst"                    ->  146
apt-get -s upgrade | grep "^Inst" | grep -ci security   ->   56
systemctl is-enabled unattended-upgrades  ->  yok (paket kurulu değil)
uname -r  ->  6.1.0-45  (çekirdek 6.1.170; güvenlik deposunda 6.1.180)
uptime    ->  17 gün
```

Bekleyen güvenlik yamalarından bazıları:

| Paket | Kurulu | Güvenlik sürümü | Neden önemli |
|---|---|---|---|
| `dovecot-core/imapd/pop3d` | `2.3.19.1...deb12u4` | `...deb12u6` | **110/143/993/995 doğrudan internete açık** — CF arkasında DEĞİL |
| `openssl` / `libssl3` | `3.0.19-1~deb12u2` | `3.0.20-1~deb12u2` | nginx, postfix, dovecot hepsi kullanıyor |
| `libgnutls30` | `3.7.9-2+deb12u6` | `...u7` | posta yığını |
| `libkrb5-3` + krb5 ailesi | `1.20.1-2+deb12u4` | `...u5` | |
| `libnss3` | `3.87.1-1+deb12u2` | `...u3` | |
| `bind9-dnsutils/host` | `9.18.47` | `9.18.49` | |
| `libnghttp2-14` | `1.52.0-1+deb12u2` | `...u3` | nginx HTTP/2 |
| `linux-libc-dev` | `6.1.170-1` | `6.1.180-1` | çekirdek de eski (yeniden başlatma gerekir) |

**Etki:** Uygulama katmanı ne kadar temiz olursa olsun, doğrudan internete açık
`dovecot` (ve 25/587'de Postfix) yamasız çalışıyor. Bu servisler Cloudflare'in
arkasında değil — `mail.dizijpg.com` zaten origin IP'yi ifşa ediyor (önceki
denetimde bilinçli kabul edilmişti, ama o kabul "yamalar günceldir" varsayımına
dayanıyordu).

**Öneri:**
1. `apt update && apt upgrade` + çekirdek için planlı yeniden başlatma
   (yeniden başlatma dizi.jpg dahil tüm servisleri ~1 dk keser; gece yapılmalı).
2. `unattended-upgrades` kur ve **yalnız güvenlik deposunu** otomatik uygula
   (`Unattended-Upgrade::Origins-Pattern` → `origin=Debian,codename=${distro_codename}-security`).
   Böylece rutin paketler kendiliğinden değişmez, yalnız yamalar iner.
3. Debian 12 artık **oldstable**. 2026 içinde Debian 13'e geçiş planı yapılmalı;
   oldstable güvenlik desteği süresizdir değil.

---

## 4. SARI bulgular

### 4.1 — [SARI] Admin paneli nginx IP kapısı BÜYÜK/küçük harfle atlanıyor

**KANIT (dışarıdan, kimliksiz, izinli olmayan IP'den):**
```
GET /api/admin/ozet    -> 404   (nginx `^~ /api/admin` bloğu kesti)
GET /api//admin/ozet   -> 404
GET /api/%61dmin/ozet  -> 404
GET /api/x/../admin/…  -> 404
GET /api/Admin/ozet    -> 403   {"hata":"Erişim reddedildi"}   <-- EXPRESS'E ULAŞTI
GET /api/ADMIN         -> 403
```
Sebep: nginx'te önek (`^~`) location eşlemesi **harf duyarlıdır**, Express'in
yönlendirmesi ise **varsayılan olarak harf duyarsızdır**. `/api/Admin/...`
nginx'in admin bloğuna değil genel `/api/` bloğuna düşüyor, oradan Express'e
gidiyor ve Express onu `/admin/ozet` rotasıyla eşliyor.

**Bugünkü etki: veri sızmıyor.** İkinci kapı (`adminKisit`) tutuyor ve
`X-Real-IP` her iki nginx bloğunda da `$remote_addr` ile eziliyor, yani IP
sahteciliği yine mümkün değil. Bulgunun değeri iki noktada:
- Panelin **varlığı ifşa oluyor** — 404 tasarımının açık amacı buydu.
- `adminKisit` **`X-Admin-Token` başlığını HER IP'den kabul eder**
  (`server.js:10633`). Normal yolda nginx IP kapısı ikinci bir engel; bu yolda
  o engel YOK. Yani `ADMIN_TOKEN` sızarsa (48 karakter, `.env`'de, kaba kuvvet
  imkânsız) panel dünyanın her yerinden açılır — ban, yorum silme, duyuru push'u,
  yedek alma dahil 20 yazma ucuyla.

**Öneri (10 dk):** nginx'te bloğu harf duyarsız regex'e çevir —
`location ~* ^/api/admin` (regex, `/api/` önekinden ÖNCE değerlendirilir, davranış aynı kalır).
Kemer+askı olarak `server.js`'e `app.set('case sensitive routing', true)`.
Ayrıca `adminKisit`'te token yolunu "IP izinli VE token doğru" ya da en azından
ayrı bir sıkı hız limitine bağlamayı değerlendir.

### 4.2 — [SARI] Hesap ön-kaçırma: doğrulanmamış e-posta + Google ile giriş birleşmesi

**Ne:** `/auth/kayit` e-posta sahipliğini **hiç doğrulamıyor** (kodda
`email_verified`/doğrulama tablosu yok — yalnız Google akışında var).
`/auth/google` ise var olan hesabı **e-postaya göre eşleştirip şifresiz token
veriyor** (`server.js:4046`).

**Senaryo:**
1. Saldırgan `kurban@gmail.com` ile kayıt olur, şifreyi kendi belirler.
2. Kurban aylar sonra "Google ile giriş"e basar → Google `email_verified: true`
   döner → sunucu **saldırganın açtığı hesaba** oturum açar.
3. Kurban o hesabı kullanmaya başlar (DM, izleme geçmişi, liste).
4. Saldırgan kendi şifresiyle aynı hesaba girip her şeyi okur.

Şifre sürümü (`sifre_surumu`) bu akışta artmıyor, yani saldırganın oturumu da
canlı kalır.

**Etki:** Hedefli, önceden e-postayı bilmeyi gerektiren ama tamamen sessiz bir
hesap paylaşımı/devralma. Kayıt ucu 30/saat/IP dışında engelsiz.

**Öneri (seçenekli):**
- **En ucuz (30 dk):** `/auth/google` var olan bir hesapla eşleştiğinde ve o
  hesap **doğrulanmamış şifreyle** açılmışsa `sifre_surumu`'nu artır + şifre
  hash'ini geçersiz kıl → saldırganın şifresi ve token'ı ölür, kurban "şifre
  belirle" akışına düşer.
- **Kalıcı (2-3 saat):** kayıtta e-posta doğrulama kodu (sıfırlama akışının
  aynısı; `sifirlama_kodlari` deseni hazır). Doğrulanana kadar hesap yazma
  yapamaz.

### 4.3 — [SARI] Uygulamanın DB rolü HÂLÂ süper kullanıcı (7 Ağu §3.1 uygulanmadı)

**KANIT:**
```
docker exec dizijpg-db psql -U dizijpg -tAc "SELECT rolname,rolsuper,… FROM pg_roles"
-> dizijpg | t | t | t | t
docker exec dizijpg-api printenv DATABASE_URL
-> postgres://dizijpg:<gizli>@db:5432/dizijpg
```
`backend/db-rol-en-az-yetki-20260808.sql` **9 gün önce yazıldı, hiç uygulanmadı.**
Rol listesinde `dizijpg` dışında uygulama rolü yok.

**Etki:** Bugün SQLi yok, ama çıkarsa etki "veri okuma"dan
`COPY … TO PROGRAM` ile **DB konteynerinde komut çalıştırma**ya sıçrar;
`rolbypassrls=t` satır düzeyi güvenliği de anlamsız kılar.

**Öneri:** Hazır SQL'i uygula, `.env`'de `DATABASE_URL`'i yeni role çevir,
süper kullanıcıyı yalnız migrasyona bırak. (1-2 saat, hazır dosya var.)

### 4.4 — [SARI] API konteyneri `root` olarak çalışıyor ve saldırganın verdiği medyayı ffmpeg'e veriyor

**KANIT:** `docker exec dizijpg-api id` → `uid=0(root) gid=0(root)`.
`Dockerfile`'da `USER` satırı yok (`node:22-alpine` varsayılanı root).

Bu tek başına orta risk; **birleştirici** olan şu: `POST /medya` ile yüklenen
her video, sihirli bayt kontrolünden sonra doğrudan `ffmpeg`'e veriliyor
(`server.js:326 videoKaresiCikar`). ffmpeg, kötü niyetli çerçeve verisine karşı
tarihsel olarak en çok CVE alan bileşenlerden biridir. Bir ffmpeg açığı
tetiklenirse elde edilen kod çalıştırma **konteynerde root** olur — ve o
konteynerde `.env` (JWT sırrı, mesaj şifreleme anahtarı, DB süper kullanıcı
şifresi), `firebase-admin.json`, medya volume'ü ve `/yedekler` bağlı.

**Öneri:**
1. `Dockerfile`'a `USER node` (imajda hazır uid 1000). `/veri` ve `/yedekler`
   bind mount izinlerinin ayarlanması gerekir — dağıtımda bir kerelik iş.
2. `docker-compose.yml`'a `security_opt: [no-new-privileges:true]` ve
   `cap_drop: [ALL]`.
3. ffmpeg çağrısına zaten `timeout: 20000` var; ek olarak `-nostdin`,
   `-f` ile giriş formatını sabitleme ve düşük `-threads` değerlendirilebilir.

### 4.5 — [SARI] `Content-Security-Policy` hâlâ YOK (üçüncü denetim)

**KANIT (canlı):**
```
curl -I https://dizijpg.com/
-> strict-transport-security, x-content-type-options, x-frame-options,
   referrer-policy VAR;  content-security-policy YOK
```
`grep -i "content-security" /etc/nginx/sites-available/dizijpg.com` → **0 eşleşme**.
Hazırlanan `backend/nginx-guvenlik-20260808.parca.conf` uygulanmamış.

Sunucudaki toplayıcı (`POST /csp-rapor` + `GET /admin/csp`) canlıda **çalışıyor
ama hiç rapor alamaz**, çünkü başlık yok — yani "önce Report-Only ile ölç"
planının ilk adımı hiç başlamamış.

**Etki:** Token web'de `SharedPreferences` → localStorage'ta ve **90 gün**
geçerli (`jwtUret`, `server.js:1014`). Bir XSS çıkarsa çalınan oturum şifre
değişene kadar yaşar.

**Öneri:** `Content-Security-Policy-Report-Only` başlığını `report-uri /api/csp-rapor`
ile ekle, birkaç gün `GET /admin/csp` sayacını izle, `toplam: 0` olunca zorunlu
başlığa çevir. (1-2 saat + bekleme.)

**Ek (küçük ama gerçek):** `Permissions-Policy` sunucu düzeyinde tanımlı
(satır 129) ama `location = /` ve diğer alt bloklardaki `add_header` setleri onu
tekrarlamadığı için **ana sayfada düşüyor** — yukarıdaki `curl -I` çıktısında yok.
nginx'te `add_header` mirası bu şekilde çalışır; hazırdaki setlere bir satır eklemek yeterli.

### 4.6 — [SARI] Sunucu dışı yedek kopyası hâlâ yok (7 Ağu §3.2'nin dayanıklılık yarısı)

**KANIT:**
```
crontab -l  ->  0 4 * * * /opt/dizijpg/yedek.sh      (yalnız yerele yazıyor)
             (rsync/scp/rclone/s3/b2 girdisi YOK)
ls /opt/dizijpg/yedekler  ->  hepsi aynı diskte
```
Gizlilik yarısı düzeldi (700 + gpg), **dayanıklılık yarısı düzelmedi**: disk ya
da sunucu kaybı = 14 günlük tüm yedeklerin kaybı. §3.1'deki disk dolma senaryosu
ile birleşince ayrıca kötü: disk dolduğu gece yedek de alınamaz.

**Öneri:** Gece `yedek.sh` sonuna şifreli dosyayı ikinci sunucuya
(`154.53.163.5`) ya da B2/S3'e kopyalayan tek satır. Zaten gpg'li olduğu için
hedefte ek gizlilik önlemi gerekmez.

### 4.7 — [SARI] `MEDYA_IMZA_ZORUNLU` 9 gündür kapalı — imzasız özel medya hâlâ servis ediliyor

**KANIT:** `docker exec dizijpg-api printenv | grep MEDYA_IMZA` → **hiçbir şey**
(değişken tanımsız → `server.js:...` `MEDYA_IMZA_ZORUNLU = false`).

Yani göç dönemi hâlâ sürüyor: imzasız bir DM medya URL'si **hâlâ 200 dönüyor**
(yalnız `private, no-store` başlığıyla). Kazancın yarısı (CF edge'de public kopya
birikmemesi) alınmış, diğer yarısı (sızan URL'nin 24 saatte ölmesi) alınmamış.

**Öneri:** Sunucuda sayaç zaten tutuluyor (`MEDYA_SAYAC.imzasiz_ozel`).
Bu sayacı bir kez oku; `imzasiz_ozel` sıfıra yakınsa (yayındaki istemciler
güncellenmiş demektir) `.env`'e `MEDYA_IMZA_ZORUNLU=1` ekle ve dağıt.
Sayaç yüksekse istemci güncelleme oranını bekle — ama karar **bilinçli**
verilmeli, unutulmuş bir bayrak olarak kalmamalı.

### 4.8 — [SARI] `package-lock.json` yok → derleme yeniden üretilebilir değil, tedarik zinciri açık

**KANIT:** `backend/` içinde lock dosyası yok; `Dockerfile` → `RUN npm install --omit=dev`.
`npm audit` bile çalışmıyor (`ENOLOCK`).

**Etki:** Her `docker compose build` bağımlılıkları **semver aralığından yeniden
çözer**. Bir bağımlılığın ele geçirilmiş bir yama sürümü yayınlanırsa, bir
sonraki derlemede sessizce imaja girer. Ayrıca "dün çalışan imaj bugün neden
farklı" sorusunun cevabı yok.

Lock dosyası üretip denetlediğimde çıkan tablo (`npm audit --omit=dev`,
üretim bağımlılıkları):

| Paket | Şiddet | Not |
|---|---|---|
| `nodemailer` | **YÜKSEK ×2** | `raw`/`jsonTransport` ile `disableFileAccess`/`disableUrlAccess` atlatma (keyfi dosya okuma + SSRF); OAuth2 token çekiminde hatalı TLS doğrulaması |
| `nodemailer` (addressparser) | orta | özyinelemeli çağrıyla DoS |
| `firebase-admin` → `uuid`, `gaxios`, `google-gax`, `teeny-request`, `retry-request`, `@google-cloud/*` | orta ×8 | zincirleme |
| **Toplam** | **11 açık (2 yüksek, 9 orta)** | |

**Sömürülebilirlik değerlendirmesi:** nodemailer'ın yüksek şiddetli ikisi
**bugün tetiklenemiyor** — `mailGonder` yalnız `to/subject/text/attachments`
geçiyor, `raw` hiç kullanılmıyor ve ek dosya yolları sunucu üretimi.
`addressparser` DoS'u ise **dışarıdan gelen postayı ayrıştıran** yolda
(`mail_kutu.js` → admin paneli "Mailler" sekmesi) teorik olarak tetiklenebilir;
etkisi admin panelinin o sekmesinin takılmasıdır.

**Öneri:**
1. `npm install --package-lock-only` ile lock üret, depoya ekle,
   `Dockerfile`'da `npm ci --omit=dev` kullan.
2. `nodemailer`'ı 7.x/9.x'e yükselt (kırıcı değişiklik var; `sendMail`
   çağrımız basit olduğu için düşük riskli). `firebase-admin` yükseltmesi
   ayrı bir iş — orta şiddetli ve dolaylı, acele değil.

### 4.9 — [SARI] Origin sertifikası kendinden imzalı → Cloudflare "Full (strict)" olamaz

**KANIT:**
```
openssl x509 -in /etc/nginx/ssl/dizijpg.crt -noout -subject -issuer
subject = CN=dizijpg.com, O=Dizijpg
issuer  = CN=dizijpg.com, O=Dizijpg      <-- kendinden imzalı
notAfter= Apr 13 2036
```
Kendinden imzalı sertifikayı Cloudflare doğrulayamaz; demek ki SSL modu
**"Full" (strict değil)**. Bu, CF↔origin bacağının **şifreli ama kimliği
doğrulanmamış** olması demektir — yol üzerindeki bir saldırgan (BGP kaçırma,
veri merkezi içi) origin gibi davranıp trafiği okuyabilir/değiştirebilir.

Önceki iki denetimde de açıktı.

**Öneri:** Cloudflare panelinden **Origin Certificate** üret (ücretsiz, 15 yıl),
`/etc/nginx/ssl/`'e koy, SSL modunu **Full (strict)** yap. Yalnız panel + iki
dosya kopyası; ~20 dakika.

---

## 5. Düşük / bilgi

| # | Bulgu | Not |
|---|---|---|
| 5.1 | **Zip bombası:** `veri_aktar.js:227` açılmış boyutu **tam açtıktan SONRA** kontrol ediyor (`veri.length > MAX_DOSYA_ACIK`). 60 MB sınırının üstünde bir giriş, sınıra takılmadan önce belleğe tamamen açılır → işçi OOM. Limit: 6/saat/kullanıcı, ama misafir hesap bedava. | JSZip'in `_data.uncompressedSize`'ını açmadan önce kontrol et. |
| 5.2 | **Gelen posta HTML süzgeci regex tabanlı** (`mail_kutu.js:137`) ve kolayca atlanır (`<img/onerror=…>` — regex `\son…` bekliyor, `/` boşluk değil). | Bugün ZARARSIZ: panel `<iframe sandbox srcdoc>` kullanıyor, script çalışmaz. Ama `sandbox`'a bir gün `allow-scripts` eklenirse anında XSS olur. `sandbox` özniteliğinin yanına yorum düşülmeli. |
| 5.3 | `GET /altyazi/:dosya` **kimlik doğrulaması istemiyor** (`girisIsteğeBagli`) ve özel medya kontrolü YOK. Bugün sızıntı yok çünkü kuyruk yalnız `yorumlar` tablosundan besleniyor (`araclar/altyazi_uret.js:366`) — DM videoları hiç deşifre edilmiyor. | Kuyruğa bir gün `mesajlar` eklenirse DM videosunun **metni** imzasız/oturumsuz okunur. Uca `OZEL_MEDYA` kontrolü eklemek 5 dakikalık sigorta. |
| 5.4 | `POST /hata-bildir` **anonim** (60/saat/IP), kayıt başına 2 KB mesaj + 8 KB yığın. Dağıtık istekle `hatalar` tablosu şişirilebilir. | Etki düşük (metin), ama §3.1'deki disk senaryosunun küçük bir yardımcısı. Saklama süresi/budama eklenebilir. |
| 5.5 | `/etc/nginx/nginx.conf:33` genelde `ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3`. dizijpg vhost'u bunu `TLSv1.2 TLSv1.3` ile eziyor, ama **aynı makinedeki diğer vhost'lar** TLS 1.0/1.1 kabul ediyor olabilir. | dizi.jpg'yi etkilemiyor; makine genelinde temizlik. |
| 5.6 | Yükleme sonrası dosya, mesaja iliştirilene kadar `OZEL_MEDYA` kümesine girmiyor → o pencerede "genel" sayılıyor. | Pencere saniyeler; ad 64 bit rastgele. Gerçek risk yok, bilgi amaçlı. |
| 5.7 | JWT **90 gün** + web'de localStorage; oturum/cihaz başına iptal yok ("tüm oturumları kapat" yalnız şifre değişimiyle). | Önceki denetimde de vardı; yenileme (refresh) mimarisi istemci değişikliği ister. §4.5 (CSP) ile birlikte değerlendirilmeli. |

---

## 6. 7 Ağustos denetiminin takibi

| # | Bulgu | 8 Ağu durumu | **17 Ağu GERÇEK durum** |
|---|---|---|---|
| 2.1 | `/medya` kimliksiz | KOD HAZIR | **KISMEN CANLIDA** — imza kodu çalışıyor, `private/no-store` uygulanıyor; **zorunluluk bayrağı hâlâ kapalı** (§4.7) |
| 3.1 | DB rolü süper kullanıcı | KOD HAZIR | **UYGULANMADI** (§4.3) |
| 3.2 | Yedekler şifresiz + 755 | KOD HAZIR | **GİZLİLİK UYGULANDI** (700 + gpg, gece cron çalışıyor); **sunucu dışı kopya hâlâ yok** (§4.6) |
| 4.3 | CSP yok | KISMEN | **UYGULANMADI** — başlık hâlâ yok (§4.5) |
| 4.4 | Sıfırlamada deneme kilidi yok | KOD HAZIR | **UYGULANDI** — kod canlıda, 5 deneme + iptal |

---

## 7. Kullanıcının kendi yapması gerekenler (panel/işletim)

- **Cloudflare paneli:** Origin Certificate üret + SSL modunu **Full (strict)** yap (§4.9).
- **Sunucu dışı yedek hedefi seç** (B2 / S3 / `154.53.163.5`) ve kimlik bilgisi üret (§4.6).
- **Planlı bakım penceresi belirle:** `apt upgrade` + çekirdek için yeniden başlatma (§3.2).
  Bu, aynı makinedeki diğer projeleri de ~1 dk keser.
- **`MEDYA_IMZA_ZORUNLU=1` kararı:** yayındaki eski istemci oranını görüp
  bayrağı aç ya da bilinçli olarak ertele (§4.7).

---

## 8. Önerilen sıra (etki / maliyet)

1. Disk eşiği kapısı + misafir yükleme limiti — **30 dk**, en büyük riski kapatır (§3.1)
2. `apt upgrade` + `unattended-upgrades` — **1 saat + bakım penceresi** (§3.2)
3. nginx admin location'ını harf duyarsız yap — **10 dk** (§4.1)
4. Google giriş → eski şifre/oturum iptali — **30 dk** (§4.2)
5. `package-lock.json` + `npm ci` + nodemailer yükseltmesi — **1-2 saat** (§4.8)
6. DB en-az-yetki rolü (SQL hazır) — **1-2 saat** (§4.3)
7. Cloudflare Origin Cert + Full (strict) — **20 dk** (§4.9)
8. CSP Report-Only → zorunlu — **1-2 saat + ölçüm** (§4.5)
9. Sunucu dışı yedek — **1 saat** (§4.6)
10. Konteyneri `USER node` ile çalıştır — **1-2 saat, dikkatli dağıtım** (§4.4)

---

## 9. Denetim izi

- Sunucuda çalıştırılan komutlar: `uname/uptime/df/du/ls/stat/grep/sed/awk`,
  `docker ps`, `docker exec … id`, `docker exec … printenv`,
  `docker exec dizijpg-db psql -tAc "SELECT … FROM pg_roles"`, `ss -tlnp`,
  `iptables -S`, `sshd -T`, `fail2ban-client status`, `crontab -l`,
  `apt-get -s upgrade` (**-s = simülasyon, hiçbir paket kurulmadı**),
  `openssl x509 -noout`.
- Dışarıdan: `curl -I` ve `curl -o /dev/null -w %{http_code}` ile herkese açık
  uçlar + admin yol varyantları. Hiçbir yazma isteği gönderilmedi.
- Yerelde: `npm i --package-lock-only` **yalnız geçici bir kopya dizininde**
  (`scratchpad/audit/`) çalıştırıldı; `backend/` dokunulmadı.
- Hesap oluşturulmadı, dosya yüklenmedi, mesaj gönderilmedi, hiçbir ayar
  değiştirilmedi, hiçbir servis yeniden başlatılmadı.
- Sır DEĞERLERİ okunmadı/yazılmadı; yalnız uzunlukları raporlandı.

*Bu denetim salt okumadır. §3.1 (disk doldurma) canlıda DENENMEDİ — denemek
servisi durdurmak olurdu; kanıt kod + yapılandırma + boş disk ölçümüdür.*
