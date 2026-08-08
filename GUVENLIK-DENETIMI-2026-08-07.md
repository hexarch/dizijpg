# dizi.jpg — Güvenlik Denetimi (2. tur)

> ## ⟶ DURUM GÜNCELLEMESİ — 8 Ağustos 2026
>
> Beş SARI bulgunun **düzeltmesi yazıldı ve test edildi**; **hiçbiri henüz
> canlıya uygulanmadı.** Bu tur da salt-okuma sınırında kaldı: sunucuda
> yalnız okuma yapıldı, tek yan etki aşağıda not edildi.
>
> | # | Bulgu | Durum | Nerede |
> |---|---|---|---|
> | 2.1 | `/medya` kimlik doğrulamasız | **KOD HAZIR** — imzalı-süreli URL + `private/no-store`; göç bayrağı kapalı | `backend/medya_imza.js`, `server.js` |
> | 3.1 | DB rolü süper kullanıcı | **KOD HAZIR** — ayrı DML-only rol; canlıda doğrulandı | `backend/db-rol-en-az-yetki-20260808.sql` |
> | 3.2 | Yedekler şifresiz + dünyaya-okunur | **KOD HAZIR** — 700/600 + gpg AES-256 | `backend/yedek.sh`, `yedek-ac.sh` |
> | 4.3 | CSP başlığı yok | **KISMEN** — nginx yaması + ihlal toplayıcı yazıldı; token ömrü DOKUNULMADI | `backend/nginx-guvenlik-20260808.parca.conf` |
> | 4.4 | Sıfırlamada deneme kilidi yok | **KOD HAZIR** — hesap başına 5 deneme + kod iptali | `server.js`, `migrasyon-2026-08-08c.sql` |
>
> **Kapsam dışı bırakılanlar (bilinçli):** JWT ömrünün 90 günden kısaltılması
> ve yenileme (refresh) mimarisi — istemci değişikliği gerektirir, `app/**` bu
> turda dokunulmaz durumdaydı. Sunucu-dışı yedek kopyası — dayanıklılık kararı
> kullanıcıya ait. Halka açık yorum/akış medyası bilerek korunmadı (§2.1).
>
> **Bu turun tek yan etkisi:** gpg bayraklarını doğrularken sunucuda
> `/root/.gnupg` dizini oluştu (700 root:root, içinde yalnız boş bir
> `pubring.kbx`). Zararsızdır ve `yedek.sh` zaten bu dizini kullanacak.
>
> Ayrıntılı gerekçeler, göç yolu ve uygulama adımları: `YAPILACAKLAR.md`
> → "Güvenlik denetimi düzeltmeleri (8 Ağu)".

**Tarih:** 2026-08-07 · **Kapsam:** kullanıcının açıkça seçtiği üç alan —
(1) medya URL'leri, (2) yedekler + veritabanı erişimi, (3) token/oturum güvenliği.
Sunucu `154.53.163.3` (karanew), API `/opt/dizijpg` (docker-compose V1), site
https://dizijpg.com.
**Yöntem:** salt okuma. Kod okuması + kendi test hesabımızla (`testkullanici`,
id=1) canlı doğrulama. Hiçbir dosya/ayar değiştirilmedi, hiçbir servis yeniden
başlatılmadı, DB'ye yalnız `SELECT`/rol sorgusu çalıştırıldı. Yüklenen tek test
dosyası denetim sonunda silindi (aşağıda kanıt). Gerçek kullanıcı `alcelik`
(id=3) verisine dokunulmadı.

---

## 1. Yönetici özeti

> **Şu an canlıda sömürülebilir bir açık YOK.** Üç alanın hiçbirinde, bir
> saldırganın bugün kimlik doğrulamasını atlayıp başka kullanıcının verisini
> ele geçirebileceği bir yol bulunamadı. Bulgular "derinlemesine savunma" ve
> "gelecekteki bir hatanın etkisini büyütecek" nitelikte — hepsi ya bir URL
> sızıntısı, ya gelecekte oluşacak bir SQLi/XSS, ya da sunucunun ele geçmesi
> koşuluna bağlı.

**Bulgu sayısı:** KIRMIZI **0** · SARI **5** · YEŞİL/temiz doğrulanan alanlar aşağıda.

**En kritik üç bulgu:**

1. **[SARI] `/medya` kimlik doğrulamasız servis ediliyor** — DM fotoğrafı/sesi
   dahil her dosya, oturumsuz `curl` ile açılıyor (200 döndü). Tek koruma:
   dosya adındaki 64 bit rastgelelik. Numaralandırma matematiksel olarak imkânsız
   ama URL bir kez sızarsa (Cloudflare edge önbelleği dosyaları **public** tutuyor)
   içerik kalıcı ve iptalsiz açığa çıkar.
2. **[SARI] Uygulamanın DB rolü `dizijpg` SÜPER KULLANICI** (`rolsuper=t`,
   `bypassrls=t`). En küçük yetki ilkesi ihlali; gelecekte bir SQLi çıkarsa etki
   "veri okuma"dan "DB konteynerinde komut çalıştırma"ya (COPY … TO PROGRAM) sıçrar.
3. **[SARI] Yedekler yalnız yerelde, şifresiz ve dünyaya-okunur dizinde** — sunucu
   kaybı = tüm yedeklerin kaybı (dayanıklılık); dizin `755` olduğu için kabuklu
   `kara` hesabı tüm DB dökümünü okuyabilir.

**En acil kapatılması gereken:** Medya için ya Cloudflare edge önbelleğini DM/özel
medyada kapatmak ya da erişimi imzalı/süreli URL'ye bağlamak (Bulgu 1); ardından
DB rolünü süper kullanıcıdan indirmek (Bulgu 2). İkisi de bugün istismar edilmiyor
ama kullanıcı verisinin en değerli görüldüğü bu projede öncelik.

**Önceki denetimin (2026-08-03) kapattığı 5 bulgu hâlâ kapalı** (§5'te kanıtlı).

---

## 2. Alan 1 — Medya URL'leri

### 2.1 — [SARI] `/medya` kimlik doğrulamasız (capability-URL modeli)

**Ne:** `/medya` ve `/avatarlar` statik `express.static` ile servis ediliyor,
route'ta `girisZorunlu` YOK (`server.js:132-133`). Yani "URL'yi bilen görür";
DM'e yüklenmiş özel bir fotoğraf da dahil, hiçbir dosyada sahiplik/erişim kontrolü
istek anında yapılmıyor.

**KANIT (canlı, kendi test hesabımızla):**
```
# testkullanici olarak yükle:
POST /api/medya  ->  {"yol":"/medya/m1-8cd6a45c0c5e643f.png", ...}
# aynı URL'yi OTURUMSUZ (Authorization başlığı yok) iste:
GET /api/medya/m1-8cd6a45c0c5e643f.png
   HTTP=200  content-type=image/png  bytes=69
   cache-control: public, max-age=31536000, immutable
   cf-cache-status: HIT
```
Kimlik doğrulaması olmadan içerik döndü **ve** Cloudflare onu `public` olarak
edge'de önbelleğe aldı (`cf-cache-status: HIT`).

**Dosya adı entropisi — numaralandırma İMKÂNSIZ:** Ad şeması
`m<kullanıcı_id>-<16 hex>.<uzantı>` (`server.js:2951`):
```js
const dosya = `m${req.kullanici.id}-${crypto.randomBytes(8).toString('hex')}.${tur.uzanti}`;
```
`crypto.randomBytes(8)` = **64 bit** kriptografik rastgelelik (zaman damgası ya da
artan sayaç DEĞİL). 2^64 aday uzayında kaba kuvvet pratikte imkânsız — bu bölümde
**canlıda kaba kuvvet denenmedi**, şema koddan çıkarıldı. Sahibin id'si adın
önündedir ama bu yalnız sahiplik doğrulaması için (aşağıda); tahmini kolaylaştırmaz.

**Gerçek dünya etkisi:** Enumerasyon dışı iki yol açık kalıyor: (a) URL bir kez
sızarsa (üçüncü taraf loglar, ekran görüntüsü, ileti, tarayıcı geçmişi, CF önbellek)
DM medyası **kalıcı ve iptalsiz** görüntülenir — dosyanın son kullanma tarihi yok,
`immutable, max-age=1yıl`; (b) CF public önbelleği aynı URL'yi bilen herkese
origin'e gitmeden servis eder. Bir saldırgan başka kullanıcının DM fotoğrafını
**tahminle** ele geçiremez; yalnız URL'yi ele geçirmişse görebilir.

**Hafifletici (mevcut):** `referrer-policy: strict-origin-when-cross-origin`
(canlıda doğrulandı) — dosya URL'si başka sitelere Referer ile tam yol olarak
sızmaz. Yazma tarafında sahiplik SIKI (bkz. §2.2). SVG/HTML kabul edilmiyor (§2.3).

**Önerilen düzeltme (seçenekli, işletim/kod):**
- **En düşük maliyet:** Cloudflare'de `/medya/*` için "özel/DM" medyayı önbelleğe
  almayı kapat (Cache Rule: bypass), avatar/kapak gibi zaten-genel içerik
  önbellekte kalsın. Böylece en azından edge'de kopya birikmez.
- **Kalıcı çözüm:** DM/özel medyayı imzalı-süreli URL (HMAC + `exp`) veya
  `girisZorunlu` + "gönderen ya da alıcı mı" kontrolüyle proxy'leyen bir uç
  arkasına al. İş yükü: 3-5 saat (yeni uç + istemci tarafı URL üretimi).
- Not: Avatar/yorum medyası zaten kamuya açık tasarımdadır; bu değişiklik
  yalnız DM ve (isteğe bağlı) sesli mesajları hedeflemeli.

### 2.2 — [YEŞİL] Yazma tarafı sahiplik kontrolü ÇALIŞIYOR
Başka kullanıcının id'sini taşıyan dosya adını kendi mesajına iliştirmeye çalıştık:
```
POST /api/mesajlar  medya="/medya/m3-00112233445566778899aabbccddeeff.jpg"
   -> 400 {"hata":"Geçersiz medya"}
```
Regex `^/medya/m<kendi_id>-[0-9a-f]{16}\.(…)$` + `fs.existsSync` ile korunuyor
(`server.js:4307`, yorumlarda `4627`). Başkasının medyası iliştirilemiyor.

### 2.3 — [YEŞİL] Polyglot / SVG / dizin listeleme / MIME
- HTML gövdesini `application/octet-stream` olarak yüklemeyi denedik →
  `400 "Desteklenen türler: …"`. Tür **sihirli baytlardan** doğrulanıyor
  (`RESIM/SES/VIDEO_TURLERI`, `server.js:2863-2932`); SVG hiç kabul edilmiyor.
- `GET /api/medya/` → **404** (dizin listeleme yok).
- Yanıtta `x-content-type-options: nosniff` + doğru `content-type`; tarayıcıda
  içerik-koklamayla çalıştırma riski yok. `Content-Disposition` gereksiz (resim/video).
- Yol geçişi: önceki denetim §4.6'da kanıtlıydı, `/medya/` altında dizin listeleme
  kapalı olduğundan ve statik kök sabit olduğundan değişmedi.

### 2.4 — [YEŞİL/BİLGİ] Avatar/kapak adı zaman damgalı ama içerik zaten genel
`${sutun}${id}-${Date.now()}.ext` (`server.js:2889`) — tahmin edilebilir. Ancak
avatar/kapak profilde herkese açık; gizlilik beklentisi yok. Risk yok.

---

## 3. Alan 2 — Yedekler ve veritabanı erişimi

### 3.1 — [SARI] Uygulama DB rolü SÜPER KULLANICI
**KANIT:**
```
docker exec dizijpg-db psql -U dizijpg -tAc \
  "SELECT rolname,rolsuper,rolcreatedb,rolcreaterole,rolbypassrls
   FROM pg_roles WHERE rolname=current_user"
-> dizijpg | t | t | t | t
```
**Etki:** Uygulama, DB'ye süper kullanıcı olarak bağlanıyor. Bugün SQLi yok
(önceki §4.4 + bu turda parametreli sorgu teyidi) ama çıkarsa, süper kullanıcı
`COPY (…) TO PROGRAM '…'` ile **db konteynerinde komut çalıştırma**ya, `bypassrls`
ile satır düzeyi güvenliği aşmaya izin verir. En küçük yetki ilkesi ihlali.
**Öneri:** Uygulamaya yalnız `CONNECT + DML` (SELECT/INSERT/UPDATE/DELETE) yetkili
ayrı bir rol aç, şemayı bu role `GRANT`la; süper kullanıcıyı yalnız migrasyon için
kullan. İş yükü: 1-2 saat (rol + grant + `.env`'de DATABASE_URL güncelle + test).

### 3.2 — [SARI] Yedekler: yerel-tek, şifresiz, dünyaya-okunur dizin
**KANIT:**
```
stat -c "%a %n" /opt/dizijpg/yedekler  -> 755
ls -la /opt/dizijpg/yedekler           -> -rw-r--r-- root root  dizijpg-YYYYMMDD-HHMM.sql.gz (14 gün)
crontab -l | grep -iE "rsync|scp|rclone|s3|b2"  -> (yok)
0 4 * * * /opt/dizijpg/yedek.sh                 -> yalnız yerele yazıyor
```
**Etki:** (a) **Dayanıklılık:** tek sunucu; disk/sunucu kaybı = 14 günlük tüm
yedeklerin kaybı, sunucu-dışı kopya yok. (b) **Gizlilik:** dizin `755` + dosyalar
`644` ve gzip şifresiz → sunucuda root-dışı kabuğu olan biri (`kara`) tüm DB
dökümünü (tüm kullanıcı e-postaları, bcrypt hash'ler, DM'ler) okuyabilir.
`admin` hesabı önceki turda `nologin` yapıldığı için o vektör kapalı; `kara` açık.
**Öneri:** `chmod 700 /opt/dizijpg/yedekler` (önceki denetim #13 — hâlâ uygulanmadı);
dökümü `age`/`gpg` ile şifreleyip gece bir sunucu-dışı hedefe (Backblaze B2/S3/
ikinci sunucu 154.53.163.5) kopyala. İş yükü: 1-2 saat.

### 3.3 — [YEŞİL] dizi.jpg DB'si diğer servislerden İZOLE
- `dizijpg-db` konteynerinin **host portu YOK** (`docker ps` → `5432/tcp`,
  eşleme yok). Yalnız `dizijpg_default` ağında ve o ağda **sadece** `dizijpg-api`
  ile `dizijpg-db` var (docker network inspect ile doğrulandı). `dopamall-redis`,
  `monteqr`, host PG vb. bu ağda değil — dizi.jpg verisine docker ağından erişemezler.
- **Host PostgreSQL** (5432, `0.0.0.0`, pid 832) ayrı bir örnek; veritabanları:
  `postgres, miamitron, restaurant_db, dizipal, dopamall, dopamine_db` —
  **dizijpg YOK**. `pg_hba.conf`: dışarıdan (188.119.45.48, 154.53.163.5) yalnız
  `dopamine_db`'ye, `127.0.0.1`'e tümüne `scram-sha-256`. dizi.jpg verisi burada
  bulunmadığı için bu örnek dizi.jpg'ye yol açmıyor. **Dokunulmadı.**
- Host 5432 TCP olarak dışarıdan erişilebilir ama iptables yalnız 3 IP'ye açık
  (`127.0.0.1`, `188.119.45.48`, `154.53.163.5`), gerisi `DROP`. Denetim
  makinesinden bağlantının "OPEN" görünmesinin nedeni egress IP'mizin
  (`188.119.45.48`) beyaz listede olması — genel açıklık değil.

### 3.4 — [YEŞİL] Redis dış erişimi kapalı
`nc 154.53.163.3 6379` (beyaz-liste-dışı egress) → **closed/filtered**. iptables
`--dport 6379 -j DROP` + `DOCKER-USER ! -s 127.0.0.1 … DROP` çalışıyor. (dopamall'a
ait, önceki §2.6; değişmedi, dokunulmadı.)

### 3.5 — [YEŞİL] Sırlar ve loglar
- `/opt/dizijpg/.env` ve `firebase-admin.json` → `-rw------- root root` (600).
- `docker logs dizijpg-api` (son 8000 satır) token/şifre/`Authorization: Bearer`/
  `PRIVATE KEY` taraması → **0 eşleşme**.
- JWT sırrı `.env`'de 64 karakter (yeterli entropi). DB şifresi 32 karakterlik
  hex (128 bit). *(Değerler bu rapora yazılmadı.)*

---

## 4. Alan 3 — Token ve oturum güvenliği

### 4.1 — [YEŞİL] JWT yapısı ve sürüm-tabanlı iptal
- **KANIT (canlı):** `testkullanici` token'ı çözüldü → header `{"alg":"HS256"}`,
  gövde `{"id":1,"sv":0,"iat":…,"exp":…}`; `exp − iat = 7 776 000 sn = 90 gün`.
- `jwt.verify(…, { algorithms: ['HS256'] })` 3 yerde sabit → `alg:none` mümkün değil.
- **Sürüm bağı DOĞRULANDI:** token `sv=0`; DB'de aynı kullanıcının
  `sifre_surumu = 0` (`SELECT … WHERE id=1` → `1|0|f|f`). Şifre değişince ve
  **ban** olunca `sifre_surumu++` (`server.js:4454`, `6265`), 30 sn önbellekle
  eski token'lar reddediliyor. `girisZorunlu` **ve** `girisIsteğeBagli` ikisi de
  `sifreSurumuGecerli` çağırıyor (`server.js:602, 622`) — banlı kullanıcının
  token'ı okuma uçlarında da geçersiz.
- Şifre sıfırlama akışında `sifreSurumOnbellekSil` ile önbellek hemen düşürülüyor.

**[DOĞRULANMALI] — "şifre değiştir → eski token reddedilir" uçtan uca canlı testi
YAPILMADI.** `sifre_surumu`'nu artıran tek iki yol: (a) şifre sıfırlama —
6 haneli kod harici bir Gmail'e (`cinark0183@gmail.com`) gidiyor ve `mailler`
tablosunda `••••••` ile **maskeleniyor** (tasarım gereği; DB'den kod kurtarılamıyor
— bunu ayrıca doğruladık, iyi bir özellik), (b) admin ban — admin-IP kısıtlı.
İkisi de salt-okuma sınırında güvenle tetiklenemedi. Mekanizma kod + token↔DB
`sv` bağıyla kanıtlandı; yıkıcı adım bilinçli atlanmadı. Kullanıcı isterse tek
seferlik gözetimli bir testle (bir test hesabının şifresini sıfırlayıp eski
token'la istek atarak) 5 dakikada doğrulanabilir.

### 4.2 — [YEŞİL] Hız limiti IP bütünlüğü SAĞLAM
Hız limitleri `req.ip` ile anahtarlanıyor (`gercekIp` değil). Bu sağlam, çünkü
nginx `/api/` bloğunda istemcinin gönderdiği başlıkları **eziyor**:
```
# /etc/nginx/sites-available/dizijpg.com:254-265
location /api/ {
  proxy_set_header X-Real-IP        $remote_addr;
  proxy_set_header X-Forwarded-For  $remote_addr;   # <-- istemci XFF'i EZİLİYOR
}
real_ip_header CF-Connecting-IP;                     # (satır 114)
```
`$remote_addr` real_ip modülü sonrası gerçek istemcidir; `trust proxy: 1` ile
Express bunu tek XFF girdisi olarak okur → `req.ip` = gerçek istemci. İstemci
`X-Forwarded-For`/`X-Real-IP` enjekte edip limiti (veya admin kısıtını) atlatamaz.
CF atlanıp doğrudan origin'e gitme yolu da §5'te kanıtlı biçimde 444 ile kapalı.
Admin ucuna gönderdiğimiz XFF/X-Real-IP sahtecilik denemeleri 200 döndü **çünkü
egress IP'miz zaten beyaz listedeki 188.119.45.48** — sahtecilik değil.

### 4.3 — [SARI] 90 günlük token + web'de `SharedPreferences` (localStorage) + CSP yok
Token istemcide `SharedPreferences`'ta (`app/lib/api.dart:42-55`). Flutter web'de
bu **localStorage**'a düşer → JavaScript'ten okunabilir. Canlı sitede
**`Content-Security-Policy` başlığı hâlâ YOK** (önceki #6 açık; doğrulandı).
**Etki:** Gelecekte bir XSS çıkarsa (önceki tur admin panelindekini kapattı ama
uygulama yüzeyi büyük), çalınan token **90 güne kadar** geçerli kalır (şifre
değişene dek). Oturum başına/cihaz başına iptal yok; "tüm oturumları kapat" ancak
şifre değişimiyle oluyor. **Öneri:** (1) CSP başlığı ekle (Flutter inline script
kullandığı için önce `Report-Only`); (2) token ömrünü kısalt + sessiz yenileme
(refresh) düşün; en azından web'de token'ı `sessionStorage`/bellekte tut.
İş yükü: CSP 1-2 saat; refresh mimarisi ayrı ve büyük iş.

### 4.4 — [SARI-düşük] Şifre sıfırlama kodunda hesap-başına deneme kilidi yok
Kod: `crypto.randomInt(100000,1000000)` (6 hane, kripto-güvenli), 15 dk geçerli,
DB'de bcrypt hash'li (`server.js:4420-4425`). Doğrulama ucu (`/auth/sifre-sifirla`)
yalnız `authLimiti` (IP başına 30/saat) ile korunuyor; **yanlış kod sayısına göre
hesabı kilitleyen / kodu iptal eden sayaç yok**. 10^6 uzay + 15 dk pencere + IP
limiti + her denemede bcrypt maliyeti pratikte kaba kuvveti engelliyor, ama tek
katman IP limiti dağıtık (botnet) saldırıda teorik olarak aşılabilir.
**Öneri:** Hesap başına deneme sayacı; 5 yanlış denemede kodu iptal et. İş yükü: 30 dk.

### 4.5 — [YEŞİL] Giriş, kayıt, bağla
- `/auth/giris`: bcrypt karşılaştırma, ban kontrolü, jenerik hata mesajı,
  IP başına 30/saat. Hesap kilidi yok ama IP limiti + bcrypt yeterli.
- `/auth/sifre-sifirla-istek`: hesap var/yok sızdırmıyor (her durumda aynı yanıt).
- `/auth/bagla`: misafir→bağlı geçişte şifre koyuyor ama `sifre_surumu`'nu
  **artırmıyor** — doğru davranış (aynı kullanıcı, eski misafir token'ı bilinçli
  geçerli kalır). Bulgu değil.

---

## 5. Önceki denetimin (2026-08-03) kapattığı bulgular — hâlâ kapalı mı?

| Bulgu | Durum (2026-08-07 doğrulaması) |
|---|---|
| §2.1 Admin panelinde kimliksiz XSS | **KAPALI** — `server.js`'te `yolTemiz`/`metotTemiz` mevcut (2 çağrı); admin.html iki-katman kaçış korunuyor |
| §2.2 Cloudflare atlanabiliyor | **KAPALI** — doğrudan origin `curl -H "Host: dizijpg.com" https://154.53.163.3/api/saglik` → **000** (444 bağlantı kapatma); nginx'te 444/`realip_remote_addr` bloğu (12 eşleşme) |
| §2.3 SSH parola girişi + parolalı admin | **KAPALI** — `sshd -T`: `passwordauthentication no`; `admin` kabuğu `/usr/sbin/nologin` |
| §2.4 `esc()` tek tırnak | **KAPALI** — önceki turda `escJs()` eklendi (kod okumasıyla teyit) |
| §2.6 Redis dışa açık | **KAPALI (dizi.jpg açısından)** — 6379 dışarıdan closed/filtered |

**Hâlâ AÇIK (önceki denetimde de açık bırakılmıştı):**
- §2.8 **CSP başlığı yok** — canlıda doğrulandı (yalnız HSTS/nosniff/x-frame/
  referrer-policy var). Bu turda Bulgu 4.3 ile ilişkili; medya URL sızıntısını da
  dolaylı etkiler.
- #13 Yedek dizini `755` — hâlâ 700 yapılmadı (Bulgu 3.2).
- §2.5 npm açıkları (nodemailer YÜKSEK + firebase-admin) — bu denetimin kapsamı
  dışında; önceki durum geçerli.

---

## 6. Kullanıcının kendi yapması gerekenler (panel/DNS/hosting)

- **Cloudflare paneli:** `/medya/*` (özellikle DM/özel medya) için Cache Rule ile
  edge önbelleğini **bypass** et — Bulgu 2.1'in en ucuz hafifletmesi. Ayrıca
  önceki denetimdeki SSL modu "Full (strict)" + Origin Certificate işi hâlâ açık.
- **Sunucu-dışı yedek hedefi:** Backblaze B2 / S3 / ikinci sunucu (154.53.163.5)
  seç; gece şifreli kopya için kimlik bilgisi üret (Bulgu 3.2).
- **DNS/hosting:** ek işlem yok; `mail.dizijpg.com` origin ifşası önceki turda
  değerlendirildi, posta zorunluluğu nedeniyle kabul edildi.

---

## 7. Denetim izi ve temizlik

- Yüklenen tek test dosyası (`/medya/m1-8cd6a45c0c5e643f.png`) silindi:
  `REMOVED_host:/var/lib/docker/volumes/dizijpg_dizijpg_dosyalar/_data/medya/…`;
  origin doğrulaması (önbellek deldirilerek) → **404**. Konteynerde de `GONE`.
- Yerel geçici dosyalar silindi. Sunucuda hiçbir yapılandırma/servis değiştirilmedi;
  DB'ye yalnız salt-okuma sorgu çalıştırıldı. Sırların hiçbir değeri bu rapora yazılmadı.

*Bu denetim salt okumadır. Bulunan hiçbir açık bugün canlıda sömürülebilir değildir;
tüm bulgular derinlemesine-savunma/dayanıklılık niteliğindedir.*
