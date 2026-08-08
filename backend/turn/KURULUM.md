# coturn (TURN/STUN) — canlıya kurulum adımları

**Durum:** HİÇBİRİ UYGULANMADI. Bu dosya yalnız talimattır.
**Tarih:** 8 Ağu 2026 · **Faz:** F0 (`ARAMA-PLANI.md` §8)
**Sunucu:** `root@154.53.163.3` — Debian 12, coturn deposu sürümü **4.6.1-1**

Bu faz **uygulama değişikliği içermez** ve **hiçbir kullanıcıya görünmez**.
Tek başına dağıtılabilir, tek başına geri alınabilir.

---

## 0. Lisans künyesi (kapalı kaynak Play uygulaması — bulaşan lisans YASAK)

| Bileşen | Lisans | Nerede çalışır |
|---|---|---|
| **coturn** 4.6.1 | **BSD 3-Clause** | Sunucu (bizim makinemiz) |
| `flutter_webrtc` 1.6.0 | **MIT** | İstemci (APK/web) |
| `libwebrtc` (eklentinin taşıdığı) | **BSD 3-Clause** | İstemci |

Üçü de izin verici (permissive). **GPL/LGPL bulaşması yok** — `ffmpeg_kit`i
eleyen sorun burada yaşanmıyor. Kapalı kaynak dağıtımda tek yükümlülük telif
bildiriminin korunmasıdır; `flutter_webrtc` bunu paketin içinde taşır.

**Dışarıya ödeme yapılan hiçbir servis yok.** Twilio NTS, Xirsys, Metered,
Cloudflare Calls/Realtime, LiveKit Cloud ve "ücretsiz katmanlı" TURN SaaS'ları
**kapsam dışıdır** ve bu belgede seçenek olarak dahi tutulmamıştır.

---

## 1. Ölçüm kanıtı — port çakışması YOK

`ss -lntup` (8 Ağu 2026, salt okuma SSH). Sunucuda dinleyen **her şey**:

| Port | Süreç | Kapsam |
|---|---|---|
| 22 | sshd | genel |
| 25, 587 | postfix (`master`) | genel |
| 80, 443 | nginx | genel (dizijpg.com, monteqr.me, brnmedia) |
| 110, 143, 993, 995 | dovecot | genel |
| 5432 | postgres (host) | genel dinliyor, **iptables ile DROP** |
| 6379 | docker-proxy → dopamall-redis | genel dinliyor, **iptables ile DROP** |
| 3000 | next-server | **127.0.0.1** |
| 8000, 8001 | gunicorn | **127.0.0.1** |
| 8500 | docker-proxy → dizijpg-api | **127.0.0.1** |
| 8891 | opendkim | **127.0.0.1** |
| 39217 | containerd | **127.0.0.1** |
| 5353, 35956, 51666 (UDP) | avahi-daemon | genel |

**Sonuç:**

* **3478 ve 5349 BOŞ** — doğrudan doğrulandı (`ss -lntup | grep -E ':3478|:5349'` → boş).
* **20000–32767 aralığında hiçbir dinleyici yok** — tarandı, boş döndü.
  Seçilen röle aralığı **24000–24499** bu boşluğun içindedir.

### Neden 49152–65535 DEĞİL (ARAMA-PLANI §3.4'ün önerisi düzeltildi)

```
net.ipv4.ip_local_port_range = 32768   60999      ← bu sunucuda ölçüldü
```

Çekirdek, **giden** her bağlantı için (postfix'in SMTP çıkışı, Node'un TMDB
istekleri, `apt`, `curl`, docker) bu aralıktan rastgele bir kaynak portu seçer.
Planın önerdiği 49152–65535'in **49152–60999 kısmı bu pencerenin içinde**.
Somut kanıt: **`avahi-daemon` şu anda UDP 51666'da** — tam o aralıkta.

coturn bir röle portu ayırırken çekirdeğin başka bir sürece verdiği porta denk
gelebilir. Sonuç, yeniden üretilmesi çok zor, aralıklı **"arama bağlandı ama
ses yok"** hatasıdır. Aralığı efemeral pencerenin tamamen altına almak bunu
kökten keser.

### Neden 500 port yeter

Port başına **bir röle ayırması**. `ARAMA-PLANI` §3.3: tepe saatte ~35
eşzamanlı arama, ~%20'si röleye düşüyor → ~7 röleli arama. Her iki uç da
simetrik NAT arkasındaysa arama başına **iki** ayırma (en kötü hal) → **~14
port**. 500 port, bu tepe değerin **~35 katına** kadar yeter. Aynı zamanda
güvenlik duvarında açılan delik 16.384 yerine 500 port olur.

İzleme: `ss -anu | grep -c ':24[0-4][0-9][0-9]'` — %50'yi (250) aşarsa aralık
genişletilir.

---

## 2. Sıralı kurulum adımları

> Her adımdan sonra **doğrulama** satırı var. Doğrulama geçmeden sonrakine
> geçilmez. Adım 6'ya kadar hiçbir kullanıcı etkilenmez.

### Adım 1 — DNS: `turn.dizijpg.com` → 154.53.163.3, **GRİ BULUT**

Cloudflare panelinde `dizijpg.com` bölgesine **A kaydı**:

```
Ad:     turn
İçerik: 154.53.163.3
Proxy:  KAPALI  (gri bulut)   ← ZORUNLU
TTL:    Auto
```

**Proxy KAPALI olmak zorunda**, çünkü Cloudflare yalnız HTTP(S) proxy'ler;
TURN protokolü HTTP değildir. Turuncu bulut bırakılırsa TURN **hiç çalışmaz**
ve hata mesajı bunu söylemez.

> **KABUL EDİLMİŞ BEDEL:** bu kayıt, origin IP'sini (154.53.163.3) halka açık
> DNS'te ifşa eder. Bugüne dek `dizijpg.com` CF arkasındaydı. Kullanıcı bunu
> açıkça kabul etti. nginx tarafında `CF-Connecting-IP`/`X-Forwarded-For`
> zaten `$remote_addr` ile eziliyor (site conf satır 342-344), yani **admin IP
> kontrolü atlatılamaz**; kaybedilen şey CF'in DDoS emmesidir.
> `GUVENLIK-DENETIMI-2026-08-07.md` sahibiyle paylaşılmalı.

**Doğrulama:** `dig +short turn.dizijpg.com` → **154.53.163.3** (Cloudflare'in
104.x/172.67.x aralığı DEĞİL).

### Adım 2 — Paketi kur (henüz başlatmadan)

```sh
apt update
apt install -y coturn
```

Debian paketi kurulumda servisi **devre dışı** bırakır (`/etc/default/coturn`
içinde `TURNSERVER_ENABLED` yorumdadır). Bu bize yapılandırmayı önce yerine
koyma fırsatı verir.

**Doğrulama:** `dpkg -l coturn | tail -1` → `ii  coturn  4.6.1-1`

### Adım 3 — Yapılandırmayı yerine koy

```sh
cp /etc/turnserver.conf /etc/turnserver.conf.paket-yedegi
scp backend/turn/turnserver.conf root@154.53.163.3:/etc/turnserver.conf
chmod 0640 /etc/turnserver.conf
chown root:turnserver /etc/turnserver.conf     # sır içerir; dünyaya okunmaz
```

TLS satırları (`cert=`, `pkey=`) dosyada **yorumda** — sertifika adım 7'de
üretilecek. Var olmayan bir dosya gösterilirse coturn açılışta ölür ve 3478 de
gitmiş olur.

### Adım 4 — Sırrı üret ve **iki yere** yaz

```sh
TURN_SIR=$(openssl rand -hex 32)      # 256 bit
```

1. `/etc/turnserver.conf` içindeki `static-auth-secret=DEGISTIR-...` satırı
2. `/opt/dizijpg/.env` içine yeni satır: `TURN_SIR=<aynı değer>`

**Sır bu depoya, bu belgeye ve rapora YAZILMAZ.** Parola yöneticisine kaydet.

Neden ayrı bir `.env` değişkeni (JWT_SECRET'ten türetme DEĞİL) — gerekçe
`ARAMA-API-SOZLESMESI.md` §3'te.

**Doğrulama:** `grep -c '^static-auth-secret=DEGISTIR' /etc/turnserver.conf` → **0**

### Adım 5 — systemd

```sh
# Debian paketinin açma anahtarı:
sed -i 's/^#*TURNSERVER_ENABLED=.*/TURNSERVER_ENABLED=1/' /etc/default/coturn
grep -q '^TURNSERVER_ENABLED=1' /etc/default/coturn || echo 'TURNSERVER_ENABLED=1' >> /etc/default/coturn

# Sertleştirme eklentisi:
mkdir -p /etc/systemd/system/coturn.service.d
scp backend/turn/coturn-systemd-override.conf \
    root@154.53.163.3:/etc/systemd/system/coturn.service.d/dizijpg.conf

systemctl daemon-reload
systemctl enable --now coturn
```

**Doğrulama:**
```sh
systemctl is-active coturn                       # → active
ss -lnup | grep 3478                             # → 154.53.163.3:3478 (0.0.0.0 DEĞİL)
ss -lntp | grep 3478                             # → 154.53.163.3:3478
journalctl -u coturn -n 50 --no-pager            # hata/uyarı yok
```

`listening-ip` doğru çalıştıysa **`0.0.0.0:3478` GÖRÜNMEZ**; yalnız
`154.53.163.3:3478` görünür. Görünüyorsa yapılandırma okunmamıştır.

### Adım 6 — Güvenlik duvarı (aşağıdaki §3'e bak) — **UFW AÇILMAZ**

### Adım 7 — Let's Encrypt (TURNS için)

certbot **zaten kurulu** (`/usr/bin/certbot`, doğrulandı) ve
`/etc/letsencrypt/live` **boş** — bu sunucunun ilk LE sertifikası olacak,
mevcut hiçbir şeyi bozma riski yok.

**7a.** `turn.dizijpg.com` için ACME meydan okumasını karşılayacak minik bir
nginx bloğu gerekir. Gri bulut olduğu için istek doğrudan origin'e gelir;
mevcut `dizijpg.com` bloğu bu ana bilgisayar adını tanımadığı için istek
nginx'in ilk (varsayılan) sunucusuna düşer ve `.well-known` yolu güvenilir
biçimde servis edilmez. Yeni dosya —
`/etc/nginx/sites-available/turn.dizijpg.com`:

```nginx
# YALNIZ ACME. Başka hiçbir şey servis etmez; TURN'ün kendisi nginx'ten
# GEÇMEZ (farklı protokol, farklı port).
server {
    listen 80;
    listen [::]:80;
    server_name turn.dizijpg.com;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    location / { return 404; }
}
```

```sh
mkdir -p /var/www/certbot
ln -s /etc/nginx/sites-available/turn.dizijpg.com /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
```

> **`sites-available/dizijpg` (uzantısız) dosyasına DOKUNULMAZ** — o AYRI ve
> TERK EDİLMİŞ; `sites-enabled` yalnız `dizijpg.com`u bağlıyor.

**7b.** Sertifikayı al:

```sh
certbot certonly --webroot -w /var/www/certbot \
  -d turn.dizijpg.com \
  --agree-tos -m alcelikbcayir@gmail.com --no-eff-email
```

**7c.** Yenileme kancasını yerleştir:

```sh
scp backend/turn/coturn-sertifika-kancasi.sh \
    root@154.53.163.3:/etc/letsencrypt/renewal-hooks/deploy/coturn.sh
chmod 0755 /etc/letsencrypt/renewal-hooks/deploy/coturn.sh
```

**7d.** Kancayı **elle bir kez** çalıştır (ilk kopyalama için):

```sh
RENEWED_LINEAGE=/etc/letsencrypt/live/turn.dizijpg.com \
  /etc/letsencrypt/renewal-hooks/deploy/coturn.sh
```

**7e.** `turnserver.conf` içindeki `cert=`, `pkey=`, `cipher-list=`
satırlarının başındaki `#` kaldırılır → `systemctl restart coturn`.

**Doğrulama:**
```sh
ss -lntp | grep 5349                                    # dinliyor
openssl s_client -connect turn.dizijpg.com:5349 </dev/null 2>&1 | grep -E 'issuer|Verify'
#   issuer=C=US, O=Let's Encrypt, ...   ve   Verify return code: 0 (ok)
certbot renew --dry-run                                 # kanca hatasız
```

### Adım 8 — Uçtan uca TURN doğrulaması (kod yazmadan)

```sh
# Sunucuda, .env'deki sırla:
SIR=$(grep '^TURN_SIR=' /opt/dizijpg/.env | cut -d= -f2)
KUL="$(( $(date +%s) + 3600 )):1"
PAROLA=$(printf '%s' "$KUL" | openssl dgst -binary -sha1 -hmac "$SIR" | base64)

turnutils_uclient -T -u "$KUL" -w "$PAROLA" -p 3478 154.53.163.3
```

Beklenen: ayırma başarılı, paket kaybı yok. `401`/`403` alınırsa sır iki yerde
eşleşmiyordur (adım 4).

**Tarayıcı tarafı bağımsız doğrulama:** `https://icetest.info/` ya da
`webrtc.github.io/samples/src/content/peerconnection/trickle-ice/` sayfasına
`turn:turn.dizijpg.com:3478` + üretilen kimlik bilgisi girilir; **`relay`**
türünde bir aday gelmelidir. Yalnız `srflx` geliyorsa TURN çalışmıyordur.

### Adım 9 — SSRF savunmasının **kanıtlanması** (atlanmaz)

Yapılandırmayı yazmak yetmez; engellemenin gerçekten uygulandığı görülmeli.
Adım 8'deki kimlik bilgisiyle **iç bir hedefe** röle istenir:

```sh
turnutils_uclient -T -u "$KUL" -w "$PAROLA" -p 3478 -e 127.0.0.1 154.53.163.3
turnutils_uclient -T -u "$KUL" -w "$PAROLA" -p 3478 -e 172.17.0.1 154.53.163.3
```

**Beklenen: 403 Forbidden IP (iki denemede de).** Başarılı olursa
`denied-peer-ip` satırları okunmamıştır — **o durumda coturn DERHAL
durdurulur** (`systemctl stop coturn`), çünkü çalışır durumda bırakmak
127.0.0.1:8500'deki API'yi ve docker ağındaki Redis'i internete açar.

---

## 3. Güvenlik duvarı

**UFW şu anda `inactive`** (doğrulandı). Aktif olan tek şey `iptables` INPUT
zincirinde fail2ban zincirleri + PostgreSQL/Redis için elle konmuş
ACCEPT/DROP kuralları.

### KARAR: UFW **AÇILMAZ**

Gerekçe: `ufw enable` varsayılan olarak `INPUT DROP` politikası kurar ve kendi
zincirlerini INPUT'un başına ekler. Bu sunucuda **elle yazılmış 10 iptables
kuralı** (fail2ban zincirleri dahil) ve **canlı posta, web, veritabanı
trafiği** var. UFW'yi TURN kurulumu vesilesiyle açmak, ilgisiz servisleri
kesme riski taşır ve geri alması zordur. **TURN, UFW'yi açmak için sebep
değildir.**

### Şu an açılması gereken: **HİÇBİR ŞEY**

`INPUT` politikası **ACCEPT** ve 3478/5349/24000-24499 için **DROP kuralı
yok**. Yani coturn başlar başlamaz dışarıdan erişilebilir olur. Ek kural
gerekmiyor.

**Doğrulama:** başka bir makineden
`nc -zvu 154.53.163.3 3478` ve `nc -zv 154.53.163.3 5349`.

### Eğer ileride UFW/iptables sıkılaştırılırsa — AÇILACAKLAR

| Port | Protokol | Ne için |
|---|---|---|
| 3478 | **UDP** | TURN/STUN — birincil yol |
| 3478 | **TCP** | TURN, UDP'si engellenmiş ağlar için |
| 5349 | **TCP** | TURNS (TLS) |
| 5349 | UDP | DTLS — *isteğe bağlı*, coturn dinler ama WebRTC istemcileri pratikte TCP kullanır |
| **24000–24499** | **UDP** | **RÖLE ARALIĞI — EN SIK UNUTULAN** |

> **24000–24499/UDP atlanırsa** belirti şudur: kimlik doğrulama geçer, ICE
> adayı toplanır, arama "bağlandı" görünür, **ses/görüntü hiç gelmez**.
> coturn dağıtımlarının bir numaralı arıza sebebi budur.

### AÇILMAYACAKLAR (açıkça)

| Port | Neden |
|---|---|
| **5766** | coturn CLI. `no-cli` ile kapalı; dışarı açmak parolasız yönetim arayüzü demektir. |
| **9641** | Prometheus. Kullanmıyoruz, dinlemiyor. |
| **443 (TURNS)** | nginx tutuyor; aynı IP'de ikisi olmaz. |
| 5432 / 6379 | **Mevcut DROP kuralları KORUNUR.** TURN kurulumu bunlara dokunmaz. |

### iptables'a dokunulacaksa (yalnızca sıkılaştırma senaryosunda)

```sh
# TURN sinyal
iptables -I INPUT -p udp --dport 3478 -j ACCEPT
iptables -I INPUT -p tcp --dport 3478 -j ACCEPT
iptables -I INPUT -p tcp --dport 5349 -j ACCEPT
# Röle aralığı
iptables -I INPUT -p udp --dport 24000:24499 -j ACCEPT
```

Kalıcılık için `iptables-persistent`. **Bu turda uygulanmadı.**

---

## 4. Geri alma

```sh
systemctl disable --now coturn
# DNS: turn.dizijpg.com A kaydını sil  → origin IP tekrar gizlenir
apt purge -y coturn          # (isteğe bağlı)
rm -f /etc/nginx/sites-enabled/turn.dizijpg.com && nginx -t && systemctl reload nginx
```

Uygulama tarafı hiç değişmediği için geri alma **hiçbir kullanıcıyı
etkilemez**. `GET /arama/buz-sunuculari` (henüz yazılmadı) TURN erişilemezse
yalnız STUN döndürecek biçimde tasarlandı — aramaların ~%80'i yine çalışır.

---

## 5. STUN kaynağı kararı: **kendi coturn'ümüz birincil, Google yedek**

`GET /arama/buz-sunuculari` şu sırayla döndürür:

1. `stun:turn.dizijpg.com:3478` — **kendi sunucumuz**
2. `turn:turn.dizijpg.com:3478?transport=udp` — kısa ömürlü kimlikle
3. `turn:turn.dizijpg.com:3478?transport=tcp`
4. `turns:turn.dizijpg.com:5349?transport=tcp`
5. `stun:stun.l.google.com:19302` — **yedek**

**Neden kendi STUN'umuz birincil:** coturn **aynı süreçte** hem STUN hem TURN
sunar; ek kurulum, ek port, ek maliyet yok. Birincil yapmak dışarıya olan
bağımlılığı sıfırlar ve gizlilik açısından da doğrudur — Google, kullanıcının
IP'sini her arama kurulumunda görmez.

**Neden Google yine de listede:** tek bir kesinti tüm aramaları düşürmesin.
coturn çökerse ya da `turn.dizijpg.com` DNS'i bozulursa, Google STUN'u olan
istemci en azından **P2P bağlanabilen ~%80'lik dilimde** arama kurmaya devam
eder. STUN yalnız "dış IP'm ne" sorusunu cevaplar; medya oradan **geçmez**,
yani Google'a içerik gitmez ve bant genişliği maliyeti yoktur. Ücretsizdir ve
API anahtarı istemez.

**Kabul edilen bedel:** yedek kullanıldığı anda kullanıcının genel IP'si
Google'a görünür. Birincil sıralamada bu neredeyse hiç gerçekleşmez; gizlilik
politikasına Google Firebase zaten üçüncü taraf olarak yazılı.

---

## 6. Kurulumdan sonra ölçülecekler

| Ne | Nasıl | Niçin |
|---|---|---|
| Röle port kullanımı | `ss -anu \| grep -c ':24[0-4][0-9][0-9]'` | %50'yi aşarsa aralık dar |
| Giden trafik | `/proc/net/dev` ens18 TX — bkz. `ARAMA-API-SOZLESMESI.md` §6 | Fatura |
| coturn hataları | `journalctl -u coturn -p warning` | Sessiz arıza avı |
| Sertifika ömrü | `certbot certificates` | 90 günlük döngü |
