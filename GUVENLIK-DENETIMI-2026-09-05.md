# dizi.jpg — Güvenlik Denetimi (4. tur)

**Tarih:** 2026-09-05 · **Kapsam:** `backend/` (server.js 24.057 satır + modüller),
`app/` (Flutter istemci, manifestler), nginx/compose yapılandırmaları, npm
bağımlılıkları, git geçmişi, canlı site başlıkları ve sunucu `154.53.163.3`
(salt okuma SSH). **Hiçbir ayar değiştirilmedi.**

Önceki turlar: `GUVENLIK-DENETIMI.md` (3 Ağu), `-2026-08-07.md`, `-2026-08-17.md`.

---

## 1. Kısa cevap

> **Kimlik doğrulamasını atlayan, başka kullanıcının verisini okuyan ya da
> sunucuda kod çalıştıran bir açık BULUNAMADI.** SQL enjeksiyonu yok (tüm
> sorgular parametreli; tek dize birleştirme kod sabiti kolon adı), komut
> enjeksiyonu yok (`execFile` dizi argümanlı; tek `sh -c` yalnız `.env`den
> beslenir), SSRF yok (dış `fetch` hedefleri sabit alan adı), yol geçişi yok,
> e-postalar düz metin, oda/yükleme uçlarında sahiplik kontrolü var.
>
> 17 Ağu turunun açık maddelerinin çoğu **kapanmış ve canlıda doğrulandı**
> (CSP zorunlu ve 0 ihlal, Cloudflare Origin CA sertifikası, admin harf
> baypası 404, `MEDYA_IMZA_ZORUNLU=1`, güvenlik yaması 0 bekleyen, DB rolü,
> package-lock, disk eşiği varsayılan 10 GB, şifreli 600 yedekler).
>
> Bu turda **KIRMIZI yok, SARI 9, DÜŞÜK 10.** En önemli üçü: admin panelinde
> CSRF (yedek-al ucu), admin panelinin `unpkg.com`dan SRI'siz betik yüklemesi
> ve posta sunucusunda düz-metin kimlik doğrulamasının açık olması.

---

## 2. SARI bulgular

### 2.1 — Admin panelinde CSRF: `POST /api/admin/yedek-al` gövdesiz ve yalnız IP ile korunuyor
`adminKisit` (server.js:20502) beyaz listedeki IP'den gelen isteği **başka hiçbir
şey istemeden** geçirir; token yalnız IP dışındakiler için. Yönetici, beyaz
listedeki IP'deyken herhangi bir kötü niyetli sayfayı açarsa, o sayfa
`fetch('https://dizijpg.com/api/admin/yedek-al', {method:'POST', mode:'no-cors'})`
ile yedek almayı tetikleyebilir (CORS yanıtı okumayı engeller, isteği değil).
Her tetik 7 GB `pg_dump | gzip | gpg` (240 sn zaman aşımı) = CPU/disk baskısı;
döngüye alınırsa DoS. Gövde isteyen admin uçları etkilenmez (`express.json`
yalnız `application/json` çözer, o da preflight ister).
**Öneri:** `adminKisit` içinde GET dışı isteklerde `Sec-Fetch-Site` başlığını
`same-origin` şartına bağla VEYA `X-Admin-Token`ı IP'ye ek olarak zorunlu kıl.
Tek satırlık değişiklik + `admin_ip_cidr.test.js`'e test.

### 2.2 — Admin paneli üçüncü parti CDN'den SRI'siz betik yüklüyor
`admin.html:966` → `https://unpkg.com/globe.gl@2.34.4/dist/globe.gl.min.js`,
`integrity` özniteliği yok; admin CSP'si de `script-src 'unsafe-inline' https://unpkg.com`.
unpkg ele geçirilir/paket zehirlenirse yönetici tarayıcısında keyfi JS =
panelin tüm yetkisi (3 Ağu §2.1 ile aynı etki). **Öneri:** dosyayı
`/var/www/dizijpg` altına indir, `integrity="sha384-…"` ekle, CSP'den unpkg'yi
düşür. `'unsafe-inline'` için paneldeki inline betikleri tek dosyaya taşı.

### 2.3 — Posta sunucusu düz-metin kimlik doğrulamayı kabul ediyor
Sunucuda: `doveconf disable_plaintext_auth = no`, `ssl = yes` (required
değil); `postconf smtpd_tls_auth_only = no`. Yani 110/143/25/587 üzerinde
TLS'siz PLAIN/LOGIN parola gönderilebilir. Son 24 saatte 48 kimlik doğrulama
saldırısı (fail2ban 39 IP yasaklı). Yanlış yapılandırılmış bir istemci parolayı
açık gönderir. **Öneri:** `disable_plaintext_auth = yes` (dovecot),
`smtpd_tls_auth_only = yes` (postfix); 2 satır, servis reload.

### 2.4 — Güvenlik duvarı varsayılanı `ACCEPT`; avahi (mDNS) dışarı açık
`iptables -P INPUT ACCEPT` (17 Ağu raporu DROP diyordu; `rules.v4` 1 Ağu'dan
beri ACCEPT). Koruma yalnız 5432/6379 için açık DROP kurallarına dayanıyor;
`dopamine-firewall.service` kalıcılaştırıyor. Bu yüzden `avahi-daemon`
`0.0.0.0:5353/udp` üzerinden internete açık — sunucuda gereksiz, mDNS
yansıtma/yükseltme için kullanılabilir. Küresel IPv6 adresi yok (ip6tables
sorunu yok). **Öneri:** `systemctl disable --now avahi-daemon`; fırsat olunca
INPUT'u DROP + açık ACCEPT listesine çevir (22/25/80/443/110/143/587/993/995).

### 2.5 — Aynı makinedeki Redis parolasız ve `protected-mode no`
`dopamall-redis` (başka proje) `0.0.0.0:6379` dinliyor, `requirepass` boş,
`protected-mode no`. Tek koruma iptables (INPUT DROP + DOCKER-USER DROP).
Kurallar bir kez boşalırsa (2.4'teki ACCEPT varsayılanıyla birlikte) dünyaya
açık, kimliksiz Redis = konteyner içinde dosya yazma, tüm makinede kaynak
tüketimi. **Öneri:** o projenin compose'unda `127.0.0.1:6379:6379` +
`--requirepass`. dizi.jpg Redis kullanmıyor; iş sahibine iletilmeli.

### 2.6 — npm: 3 yüksek + 11 orta bilinen açık
`npm audit`: **high** `deepmerge-ts` (html-to-text → mailparser 3.9.14): özyinelemeli
nesnede yığın tükenmesi — admin posta kutusu HTML'i ayrıştırılırken; saldırgan
`admin@`'a mail atan herkes. **moderate** `qs` ×2 (express 4.22.2/body-parser
1.20.6, DoS), `uuid`, `gaxios`, `firebase-admin` zinciri. `mailparser`, `express`
için `npm audit fix` yeter; `firebase-admin@14` 17 Ağu'da denenip geri alındı
(varsayılan dışa aktarım tuzağı — `bagimlilik.test.js`). **Öneri:**
`npm audit fix` (firebase-admin hariç), test koş, dağıt.

### 2.7 — Sunucu dışı yedek HÂLÂ yok (17 Ağu §4.6)
`/opt/dizijpg/yedekler` 3 × ~7 GB şifreli, aynı diskte; `yedek.sh`'de uzak
kopya yok, rclone yapılandırması yok. Disk/sunucu kaybı = tüm veri. **Hedef ve
kimlik bilgisi kullanıcıdan gerekiyor** (B2/S3/154.53.163.5).

### 2.8 — API konteyneri hâlâ `root` + `DAC_READ_SEARCH` (17 Ağu §4.4)
`user=` boş, `cap_drop ALL` + `cap_add DAC_READ_SEARCH`, `no-new-privileges`.
ffmpeg/ffprobe saldırganın verdiği medyayı root olarak işliyor. Erteleme sebebi
belgeli (`/yedekler` 700 root). Kabul edilmiş risk; not olarak duruyor.

### 2.9 — Genel hız limitleri işçi başına; etkili limit ×4
`hizLimiti` süreç-içi `Map`; küme 4 işçi → IP/kullanıcı başına limit fiilen
4 katı (giriş/kayıt `hizLimitiMerkezi` ile küme geneli, onlar etkilenmez).
Misafir yükleme 5→20 × 100 MB/saat; bayt bütçesi (`IP_BAYT_BUTCE`) ve disk
eşiği pratikte tutuyor. **Öneri:** yükleme/oda/efekt limitlerini de
`hizLimitiMerkezi`ye taşı.

---

## 3. DÜŞÜK / bilgi

| # | Bulgu | Not |
|---|---|---|
| 3.1 | `x-powered-by: Express` `/api/*` yanıtlarında | `app.disable('x-powered-by')` |
| 3.2 | HSTS `preload` yok (max-age 180 gün, includeSubDomains var) | hstspreload.org için 1 yıl + preload |
| 3.3 | `nginx.conf` genel `ssl_protocols TLSv1 TLSv1.1` | 4 vhost da 1.2/1.3 ile eziyor; başka projelerin vhost'u için dokunulmadı |
| 3.4 | `kara` kullanıcısı: kabuk + sudo + parola tanımlı | SSH parola girişi kapalı; yine de parolayı kilitle (`passwd -l`) |
| 3.5 | root `authorized_keys` 5 anahtar (`k1m03s02@cursor`, 2× alicihanceliktht, alicihancelik@magnumoto, bilalcayir@magnumoto) | 3 Ağu "kullanılmayan 1 anahtar" hâlâ duruyor; kullanılmayanı sil |
| 3.6 | `firebase-gizli/*.json` Mac'te 644 | `chmod 600`; git'te yok, doğrulandı |
| 3.7 | Şifre en az 6 karakter, üst sınır yok | bcrypt 72 bayt keser; 8+ ve 128 üst sınır öner |
| 3.8 | DM ek yükleme `.apk/.exe` kabul ediyor (octet-stream, imzalı bağlantı) | kullanıcılar arası zararlı dosya taşıma; uzantı kara listesi düşün |
| 3.9 | `/sohbet-efekt` engelsiz herkese gönderilebiliyor (konuşma şartı yok) | 600/saat limitli spam vektörü; mesaj isteği kabulü şartı ekle |
| 3.10 | Web'de JWT 90 gün `localStorage` | 7 Ağu §4.3; CSP artık zorunlu, XSS yüzeyi daraldı |

---

## 4. Doğrulanan korumalar (bu turda kanıtlı)

| Alan | Durum | Kanıt |
|---|---|---|
| SQL enjeksiyonu | TEMİZ | `query(\`…${` yalnız 2 yerde: `BILDIRIM_TERCIH_KOLON` sabiti ve `statement_timeout` sayısı |
| Komut enjeksiyonu | TEMİZ | `execFile` dizi argümanı (ffmpeg/ffprobe); `sh -c` yalnız `/admin/yedek-al`, girdi `DATABASE_URL` |
| SSRF | TEMİZ | `fetch` hedefleri: TMDB (yol beyaz listesi `TMDB_IZINLI`), Google tokeninfo, translate, IndexNow |
| Yol geçişi | TEMİZ | `path.join(req…)` yok; `/dosya/*` imza zorunlu; `ekBasligi` CRLF/tırnak temizliyor |
| Kimlik | SAĞLAM | HS256 sabit, `sv` şifre sürümü, yasak kontrolü; Google `aud`+`email_verified` |
| Admin XSS | KAPALI | `esc()/escJs()`, posta HTML'i `<iframe sandbox srcdoc>` |
| CSP | ZORUNLU | canlı başlıkta `Content-Security-Policy` (Report-Only değil), `/admin/csp` toplam 0 |
| Origin sertifikası | Cloudflare Origin CA | `issuer=CloudFlare Origin SSL CA`, 2041'e kadar |
| Admin harf baypası | KAPALI | `/api/ADMIN/ozet` → 404 |
| İmzalı medya | ZORUNLU | konteyner `MEDYA_IMZA_ZORUNLU=1`, `MEDYA_XACCEL=1` |
| Disk eşiği | AÇIK | `DISK_ESIK_GB` boş → varsayılan 10 GB (`disk.js:239`); disk %19 dolu, 456 GB boş |
| OS yamaları | GÜNCEL | bekleyen güvenlik yaması 0; unattended-upgrades 4 Eyl koşmuş |
| SSH | SAĞLAM | parola kapalı, yalnız anahtar; 24 saatte 178 başarılı anahtar girişi (3 IP), 0 parola |
| fail2ban | AKTİF | sshd 24, dovecot 20, postfix-sasl 19 yasaklı |
| Sırlar | SAĞLAM | git'te `.env/.jks/.p8/adminsdk` yok (geçmiş dahil); sunucuda 600 root |
| Yedekler | ŞİFRELİ | `.sql.gz.gpg`, 600, dizin 700; gece 04:00 çalışıyor |
| Mobil | SAĞLAM | `allowBackup=false`, ATS varsayılan, WebView yalnız YouTube (gezinme beyaz listesi) |
| Postgres | KISITLI | 5432 yalnız 127.0.0.1 + 2 sabit IP; scram-sha-256 |
| E-posta | DÜZ METİN | 6 `mailGonder` çağrısının hepsi `text:`; HTML enjeksiyonu yüzeyi yok |

---

## 5. Önerilen sıra (etki / maliyet)

1. `adminKisit`e `Sec-Fetch-Site`/token şartı — **15 dk** (§2.1)
2. dovecot + postfix düz-metin kapatma — **10 dk** (§2.3)
3. `avahi` kapat — **2 dk** (§2.4)
4. globe.gl'yi yerelde barındır + SRI — **20 dk** (§2.2)
5. `npm audit fix` (firebase-admin hariç) + test + dağıtım — **30 dk** (§2.6)
6. Redis bind/parola (başka proje sahibi) — **10 dk** (§2.5)
7. Sunucu dışı yedek — **kullanıcıdan hedef gerekiyor** (§2.7)
8. Yükleme limitlerini küme geneli sayaca taşı — **1 saat** (§2.9)
9. Düşük maddeler (§3)

## 7. Uygulanan düzeltmeler — 5 Eylül 2026 (aynı gün)

| Bulgu | Durum | Ne yapıldı / kanıt |
|---|---|---|
| §2.1 Admin CSRF | **KAPATILDI, canlıda doğrulandı** | `fetchSiteIzinli()` + `adminKisit` (yazma isteğinde `Sec-Fetch-Site` cross-site/same-site → 403; token'lı istek muaf). Canlı: `POST /api/admin/csp/sifirla` cross-site 403, same-site 403, same-origin 200, başlıksız 200, GET cross-site 200. `test/admin_csrf.test.js` (5 test). |
| §2.2 unpkg SRI'siz | **KAPATILDI (kod)**, nginx CSP daraltması betikte | globe.gl 2.34.4 + earth-night.jpg `backend/admin-varlik/` altında, `GET /api/admin/varlik/:ad` (adminKisit, sabit beyaz liste, traversal 404). `admin.html` `integrity="sha384-boR1…"`. Canlı: 200 / 1.477.745 B / 715.000 B; panel HTML'inde yeni etiket. CSP'den unpkg'nin düşürülmesi `guvenlik-sertlestir-20260905.sh` §4'te. |
| §2.3 Posta düz-metin | **BETİKTE** (SSH yazma izni sınıflandırıcı tarafından engellendi) | `guvenlik-sertlestir-20260905.sh` §1-2: `smtpd_tls_auth_only=yes`, `disable_plaintext_auth=yes`. Node relay mynetworks'ten kimliksiz gider, etkilenmez. |
| §2.4 avahi | **BETİKTE** | betik §3 `systemctl disable --now avahi-daemon`. INPUT DROP politikasına DOKUNULMADI (paylaşımlı makine, diğer projeler). |
| §2.5 Redis | **AÇIK — başka proje** | dopamall compose'unda `127.0.0.1:6379:6379` + `requirepass` gerekiyor; o projenin uygulaması da parola ister. Sahibine bırakıldı. |
| §2.6 npm | **KAPATILDI** | `npm audit fix` → mailparser 3.9.20, html-to-text 10.0.1, deepmerge-ts 8.0.2; `overrides.qs ^6.16.0` → qs 6.16.0. Sonuç: **0 yüksek, 8 orta** (hepsi firebase-admin@12 zinciri; 14 bilinçli ertelendi). 2365/2365 test yeşil. |
| §2.7 Dış yedek | **AÇIK** | hedef + kimlik bilgisi kullanıcıdan. |
| §2.8 Konteyner root | **AÇIK (kabul edilmiş)** | değişiklik yok. |
| §2.9 İşçi-başına limit | **KAPATILDI** | `yuklemeLimitiUye/Misafir`, `veriLimiti`, `odaLimiti`, `odaRolLimiti`, `sohbetEfektLimiti` → `hizLimitiMerkezi`. Parça/yoklama limitleri bilerek yerel kaldı (IPC turu). |
| §3.1 x-powered-by | **KAPATILDI** | `app.disable('x-powered-by')`; canlı `/api/saglik` başlıkta yok. |
| §3.6 firebase-gizli 644 | **KAPATILDI** | Mac'te `chmod 600`. |

Dağıtım: `docker-compose build api && up -d` (5 Eyl), `/api/saglik` 200, giriş
(testuser123) 200, `/medya` ve `/sohbet-efekt` hatalı gövdeye 400 (uçlar ayakta).

## 6. Denetim izi
Salt okuma: `grep/sed` kod okuması, `npm audit`, `git log/ls-files`, canlıya
`curl -I` (denetim makinesi admin beyaz listesindeydi; `/api/admin/*` 200'leri
bu yüzdendir), sunucuda `ss/iptables/apt/fail2ban/sshd -T/docker inspect/
doveconf/postconf/openssl x509`. Veritabanına dokunulmadı.
