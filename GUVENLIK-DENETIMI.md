# dizi.jpg — Güvenlik Denetimi

**Tarih:** 2026-08-03 · **Kapsam:** sunucu `154.53.163.3` (mail.dizijpg.com),
canlı uygulama `/opt/dizijpg`, web kökü `/var/www/dizijpg`, proje deposu.
**Yöntem:** salt okuma. Günlük analizi, süreç/port/dosya bütünlüğü, yapılandırma
incelemesi, kod okuması ve kendi sunucumuza karşı dışarıdan doğrulama testleri.
Hiçbir ayar değiştirilmedi, hiçbir servis durdurulmadı, veritabanına yalnızca
`SELECT` çalıştırıldı.

---

## 1. Kısa cevap

> **İçeri giren yok.** Sunucuya sızma, arka kapı, madenci, yetkisiz hesap veya
> kalıcılık izi bulunamadı. SSH'a yapılmış **3.609 başarılı girişin tamamı**
> bilinen 4 ed25519 anahtarıyla ve `root` olarak gerçekleşti; **parolayla
> başarılı tek bir giriş bile yok** (`Accepted password` sayısı = 0).
>
> **Saldıran var — sürekli, ama tamamı başarısız.** Sunucu günde ortalama
> **~1.450 başarısız SSH parola denemesi** (son 24 saatte 155 farklı IP) ve web
> tarafında **~16.000 WordPress/.env/PHP tarama isteği** alıyor. Bunların hiçbiri
> bir şey elde edemedi: fail2ban 432 IP yasakladı, admin uçları beyaz liste
> dışına 404 dönüyor, hız limiti devrede.
>
> **Ancak henüz istismar edilmemiş bir yüksek riskli açık buldum:** yönetim
> panelinin canlı istek akışı, isteklerin yolunu kaçırmadan (`innerHTML`)
> basıyor. Kimlik doğrulaması gerektirmeden, tek bir HTTP isteğiyle yönetici
> tarayıcısında JavaScript çalıştırılabilir. Günlüklerde **hiç deneme yok**
> (0 kayıt) — yani henüz kimse fark etmemiş. Bunun kapatılması 1 numaralı iştir.
>
> **[x] 3 Ağu 2026 akşamı KAPATILDI.** İki katman birden uygulandı (görüntüleme
> + sunucu), panelin TÜM kaçışsız noktaları tarandı ve düzeltildi, `esc()`/
> `escJs()` için `backend/test/admin_kacis.test.js` yazıldı. Ayrıntı: §2.1.

---

## 2. Bulgular

### 2.1 — [YÜKSEK] Yönetim panelinde kimlik doğrulamasız depolanmış XSS — [x] KAPATILDI (3 Ağu 2026)

> **DURUM: KAPATILDI.** Aşağıdaki bulgu aynı gün canlıda yeniden üretildi,
> iki katmanda kapatıldı ve kapandığı yine canlıda doğrulandı.
> Yapılanlar için bu bölümün sonundaki **"Ne yapıldı"** başlığına bakın.

**Ne:** Her isteğin ham yolu belleğe yazılıyor ve yönetim panelinde
kaçırılmadan `innerHTML` ile basılıyor.

**Kanıt (kod):**

`backend/server.js:193-196` — ham `req.path` doğrudan halkaya yazılıyor:

```js
ISTEK.son.unshift({
  ip,
  yol: req.path,      // <-- ham, temizlenmemiş
  method: req.method,
```

`backend/admin.html:758-766` — `esc()` çağrısı YOK:

```js
$('#akis').innerHTML = istekler.slice(0,60).map(i=>`
  <div class="istek">
    <span class="yontem ${i.method}">${i.method}</span>
    <span class="durum ${dCls(i.kod)}">${i.kod}</span>
    <span class="yol" title="${i.yol}">${i.yol}</span>
```

Dosyada `esc()` yardımcısı var (`admin.html:1752`) ve diğer 70+ yerde düzgün
kullanılıyor; yalnızca canlı akış bloğu atlanmış.

**Kanıt (canlı doğrulama, kendi sunucumuza):** Zararsız bir işaretle test
edildi. İstek 404 döndü ama yük halkaya **ham** olarak girdi:

```
$ curl --path-as-is "https://dizijpg.com/api/DENEME<b>XSSISARET</b>"   -> 404
$ curl "https://dizijpg.com/api/admin/istekler"
  yol = '/DENEME<b>XSSISARET</b>' | kod = 404      <-- HAM, kodlanmamış
  yol = '/x%3Cimg%20src=x%20onerror=XSSISARET2%3E' | kod = 404   <-- kodlanmış hâli zararsız
```

nginx erişim günlüğünde de ham olarak görünüyor:

```
188.119.45.48 - - [03/Aug/2026:15:10:42 -0400] "GET /api/DENEME<b>XSSISARET</b> HTTP/2.0" 404 169
```

**Etki:** Saldırganın hesabı, oturumu veya yönetici IP'si olmasına **gerek yok**.
`GET /api/<img src=x onerror=...>` biçiminde tek bir istek yeter. Yönetici paneli
açtığında kod, yöneticinin tarayıcısında ve `dizijpg.com` kökeninde,
**yöneticinin beyaz listedeki IP'sinden** çalışır. Yani XSS, admin IP kısıtını
tam olarak atlar: kod `fetch('/api/admin/kullanicilar')`, `/api/admin/mailler`
gibi çağrılarla tüm kullanıcı verisini, e-postaları ve posta kutusu içeriğini
dışarı sızdırabilir. Bu, panelin sahip olduğu her yetkinin devri demektir.

**İstismar edildi mi:** HAYIR. Tüm nginx arşivi (20 Tem – 3 Ağu, 125.615 istek)
tarandı; ham `<script`/`onerror=`/`onload=`/`<img`/`<svg` içeren istek sayısı
(kendi test isteklerim hariç) **0**.

**Öneri:** `admin.html:760-762`'de üç alanı da `esc()` ile sar
(`${esc(i.yol)}`, `${esc(i.method)}`, `title="${esc(i.yol)}"`). Ek olarak
`server.js:195`'te sunucu tarafında da kırp/temizle (ör. yalnız
`[A-Za-z0-9/._%-]` bırak, 200 karakterle sınırla) — iki katman.

#### Ne yapıldı (3 Ağu 2026, akşam)

**Önce açık canlıda yeniden üretildi** (düzeltmeden ÖNCE):

```
$ curl --path-as-is "https://dizijpg.com/api/DENEME1<b>XSSISARET</b>"        -> 404
$ (sunucuda) curl -H "x-admin-token: …" 127.0.0.1:8500/admin/istekler
  'GET' '/DENEME1<b>XSSISARET</b>' 404      <-- HAM, kaçırılmamış
```

**1) Görüntüleme katmanı (asıl düzeltme) — `backend/admin.html`.**
Panelin tamamı tarandı (79 `innerHTML` yazımı tek tek denetlendi, verisinin
nereden geldiği belirlendi). Kaçışsız bulunan ve düzeltilen noktalar:

| Yer | Alan | Verinin kaynağı |
|---|---|---|
| `akisGuncelle()` canlı akış | `i.yol` (metin **ve** `title=`), `i.method` (metin **ve** `class=`), `i.kod`, `i.sehir/i.ulke` | **kimliksiz saldırgan** — tek HTTP isteği |
| `surumleriYukle()` hata tablosu | `h.hata` | istemci çökme raporları (kullanıcı cihazı) |
| `satirSik()` şikayet tablosu | `s.tur` | DB enum |
| `ulkeler()` | `u.ulke` | geoip |
| `surumOnizle()` | `r.zorunlu/oneri/min_derleme/onerilen_derleme` | `ayarlar` tablosu (admin metni) |
| `mailListele()` `onclick="mailAc('…','…')"` | `m.yon`, `m.id` | Maildir dosya adı |
| 5 ayrı `onclick="kullaniciDetay('…')"` | kullanıcı adı | kullanıcı (§2.4 ile aynı kalıp) |

**Öznitelik bağlamı ayrı ele alındı.** İki farklı bağlam, iki farklı kaçış:

* `esc()` → metin + **tırnaklı öznitelik** (`title="…"`, `class="…"`).
  `'` de eklendi (§2.4 önerisi): artık `&<>"'` kaçırılıyor.
* `escJs()` (**yeni**) → `onclick="fn('…')"` gibi **öznitelik içinde JS dizesi**.
  Burada `esc()` YETMEZ, hatta yanıltıcıdır: tarayıcı önce HTML varlıklarını
  çözer, `&#39;` yeniden `'` olur ve dizeden çıkılır. Bu yüzden `escJs()` önce
  JS kaçışı (`\` ve `'`), **sonra** HTML kaçışı uygular — sıra önemli.
  Testte bu davranış "varlıkları çöz → JS dizesi olarak değerlendir" zinciriyle
  birebir doğrulanıyor.

`textContent` ile yazılan yerlerde kaçış YOK (orada `esc()` çift kaçış olur);
`ba-kuyruk-ozet`'te yanlışlıkla duran `esc()` kaldırıldı.

**2) Sunucu katmanı (derinlemesine savunma) — `backend/server.js`.**
`yolTemiz()` + `metotTemiz()` eklendi; halkaya yalnız temizlenmiş değer yazılır
(`yol: yolTemiz(req.path)`, `method: metotTemiz(req.method)`). Yol 200 karaktere
kırpılır ve `[A-Za-z0-9/._~%:@+,=-]` dışındaki her şey (`<`, `>`, `"`, `'`,
boşluk, ham UTF-8) düşürülür. Halka yalnız gösterim içindir; `/admin/kullanici/:ad`
oradan sadece IP okur, davranış değişmedi.

**3) Kapandığı canlıda doğrulandı** (düzeltmeden SONRA, aynı istek):

```
$ curl --path-as-is "https://dizijpg.com/api/DENEME2<b>XSSISARET</b>"       -> 404
$ curl --path-as-is "https://dizijpg.com/api/z<img/src=x/onerror=XSSISARET3>" -> 404
$ (sunucuda) curl -H "x-admin-token: …" 127.0.0.1:8500/admin/istekler
  'GET' '/DENEME2bXSSISARET/b'            404   <-- < > düşürüldü
  'GET' '/zimg/src=x/onerror=XSSISARET3'  404
```

Görüntüleme katmanı ayrıca **gerçek tarayıcıda**, sunucu temizliği baypas
edilerek sınandı (panele doğrudan ham yük verildi):
`akisGuncelle([{yol:'/DENEME<b>XSSISARET</b><img src=x onerror="…">', …}])`
→ `window.__XSS_CALISTI = 0`, `#akis img` = 0, `#akis b` = 0, yük düz metin
olarak göründü. Yani sunucu temizliği olmasa bile panel artık güvenli.

**4) Panel bozulmadı.** Canlı panelde 8 sekmenin hepsi hatasız yüklendi
(konsolda 0 hata): 120 yorum, 88 kullanıcı, 95 hata kaydı, 10 mail, 9 algoritma
ağırlığı, büyüme/depolama kartları. Türkçe kesme işareti içeren gerçek yorumlar
(`Clementine'in`, `Salāh ad-Dīn's`, `Pictures'`) ve `<3` yorumu doğru göründü;
`&amp;`/`&#39;` gibi **çift kaçış izi yok**. `onclick` yolları hâlâ çalışıyor:
kullanıcı satırına tıklayınca detay modalı, mail satırına tıklayınca mail modalı
açıldı.

**5) Test.** `backend/test/admin_kacis.test.js` (13 test) — `esc()`/`escJs()`
davranışı, "tarayıcı çözünce orijinal metin geri gelir" (çift kaçış yok) özelliği,
kritik şablon satırlarının kaçışı çağırdığı ve sunucu halkasına ham `req.path`
yazılmadığı. Testin gerçekten koruduğu, kaçışı üç ayrı yerden geçici kaldırıp
KIRMIZIYA döndürerek kanıtlandı (akış şablonu → 2 test kırmızı, `escJs`'in tek
tırnak kaçışı → 2 test kırmızı, `yolTemiz` → 1 test kırmızı); hepsi geri alındı,
73/73 test yeşil.

**Kapsam notu:** `backend/` altında HTML üreten tek diğer yer `ogSayfa()` (bot/
paylaşım kartı sayfaları). Orada zaten `htmlKacir()` var ve `&<>"'` hepsini
kaçırıyor; canlıda hem ham yol parçasıyla (`x"><script>…` → `content="…&quot;&gt;&lt;script&gt;…"`)
hem de `<` içeren gerçek bir kullanıcı yorumuyla (`<3` → `&lt;3`) doğrulandı.
Değişiklik gerekmedi.

---

### 2.2 — [YÜKSEK] Cloudflare tamamen atlanabiliyor (origin IP açıkta) — [x] KAPATILDI (3 Ağu 2026)

> **DURUM: KAPATILDI.** `dizijpg.com` ve `www.dizijpg.com`'un 80/443 trafiği
> artık yalnız Cloudflare edge aralıklarından kabul ediliyor; dışarıdan doğrudan
> origin'e gelen istek `444` (bağlantı kapatma) alıyor. Uygulama yeri: nginx,
> `geo $realip_remote_addr $dizijpg_cf_disi` + `if (...) { return 444; }`.
> Ayrıntı ve gerekçeler için §7'ye bakın.

**Ne:** Origin sunucunun 80/443 portları herkese açık ve `Host` başlığıyla tüm
siteyi servis ediyor. Origin IP'yi bulmak da önemsiz.

**Kanıt (origin keşfi):**

```
dizijpg.com       -> 104.21.23.10, 172.67.208.68   (Cloudflare, proxy'li)
mail.dizijpg.com  -> 154.53.163.3                  (PROXY'SİZ — origin ifşa)
dizijpg.com TXT   -> "v=spf1 ip4:154.53.163.3 a mx ~all"   (origin ikinci kez ifşa)
```

**Kanıt (doğrudan erişim çalışıyor):**

```
$ curl -k -H "Host: dizijpg.com" https://154.53.163.3/api/saglik
{"durum":"ok","servis":"dizi.jpg API"}

$ curl -k -H "Host: dizijpg.com" https://154.53.163.3/     -> 200 (tam site)
```

**Etki:** Cloudflare'in DDoS koruması, WAF kuralları, bot yönetimi, ülke/oran
kuralları ve önbelleği **tamamen devre dışı bırakılabiliyor**. Saldırgan
doğrudan origin'i hedefleyerek sunucuyu yorabilir. Ayrıca posta sunucusu aynı
makinede olduğu için `mail.dizijpg.com` kaydı zorunlu — yani bu ifşa kendiliğinden
düzelmez.

**İyi haber:** Bu yolla admin kısıtı atlatılamıyor (bkz. §4.1) ve açık röle yok
(§4.7).

**Öneri:** 80/443'ü iptables veya nginx `allow`/`deny` ile yalnız Cloudflare IP
aralıklarına aç (aralıklar zaten `set_real_ip_from` bloğunda hazır listeli,
`/etc/nginx/sites-available/dizijpg.com:63-84`). Origin'e doğrudan gelen isteğe
444 dön. Bu, tek satırlık bir `geo` bloğu + `if` ile yapılabilir ve geri
alınabilir bir değişikliktir.

---

### 2.3 — [ORTA-YÜKSEK] SSH parola girişi açık + parolalı `admin` hesabı — [x] KAPATILDI (3 Ağu 2026)

> **DURUM: KAPATILDI.** `PasswordAuthentication no` uygulandı, `admin` hesabının
> kabuğu `/usr/sbin/nologin` yapıldı (parola hash'i mail için KORUNDU),
> fail2ban `bantime` 1 saat → 24 saate çıkarıldı. Ayrıntı için §7'ye bakın.

**Kanıt:**

```
$ sshd -T | grep -iE "passwordauthentication|permitrootlogin|port|maxauthtries"
port 22
maxauthtries 6
permitrootlogin without-password     <-- root için yalnız anahtar (İYİ)
passwordauthentication yes           <-- diğer hesaplar için parola AÇIK

$ awk -F: '$7 !~ /nologin|false|sync/ {print $1, $3, $7}' /etc/passwd
root 0 /bin/bash
kara 1000 /bin/bash
postgres 104 /bin/bash
admin 1001 /bin/bash                 <-- kabuklu

$ passwd -S admin
admin P 2026-04-17 0 99999 7 -1      <-- P = kullanılabilir parola VAR
```

`admin` (17 Nis'te açılmış, `/home/admin/Maildir` var) bir posta hesabı ama
`/bin/bash` kabuğu ve parolası olduğu için SSH ile de girilebilir.

**Saldırı hacmi (son 24 saat):**

```
Başarısız parola denemesi : 1454
"Invalid user" denemesi   :  588
Benzersiz saldırgan IP    :  155
root parolası denemesi (7 gün): 5886
```

**Etki:** `admin` hesabının parolası zayıfsa, kabuk erişimi elde edilebilir.
UID 0 olmadığı ve `sudo` grubunda bulunmadığı için doğrudan root olmaz, ama
yerel yetki yükseltmeye zemin hazırlar.

**Hafifletici:** fail2ban aktif ve çalışıyor (`bantime 1h`, `maxretry 5`);
şu an 8 IP yasaklı, toplamda **432 IP yasaklanmış**, 4.208 tespit.
`ignoreip` listesinde kendi IP'lerimiz var, kendimizi kilitleme riski yok.

**Öneri:** `PasswordAuthentication no` (posta istemcileri SSH kullanmaz, IMAP/SMTP
etkilenmez) veya en azından `admin` hesabına `usermod -s /usr/sbin/nologin`.
Ayrıca fail2ban `bantime`'ı 1 saatten 24 saate çıkarmak gürültüyü ciddi azaltır.

---

### 2.4 — [DÜŞÜK] `esc()` tek tırnağı kaçırmıyor (şu an istismar edilemez) — [x] KAPATILDI (3 Ağu 2026)

> **DURUM: KAPATILDI.** `esc()`'ye `'` → `&#39;` eklendi. Ayrıca denetimin
> işaret ettiği `onclick="kullaniciDetay('${esc(…)}')"` kalıbının **kökten
> yanlış** olduğu görüldü: `&#39;` tarayıcıda tekrar `'`e çözülür, yani `esc()`
> o bağlamda korumaz. Bu yüzden ayrı bir `escJs()` yardımcısı eklendi ve 5
> `onclick` çağrısının hepsi ona geçirildi (bkz. §2.1 "Ne yapıldı").

**Kanıt** (`backend/admin.html:1752`):

```js
function esc(s){ return String(s==null?'':s).replace(/[&<>"]/g, ...); }
```

`'` listede yok. Buna karşın şu kalıp tek tırnaklı JS dizesi içinde kullanılıyor
(`admin.html:840, 1432, 1488`):

```js
onclick="kullaniciDetay('${esc(u.kullanici_adi)}')"
```

**Etki:** Kullanıcı adında `'` karakterine izin verilseydi, `x');alert(1);//`
gibi bir ad JS dizesinden çıkıp panelde kod çalıştırırdı.

**Neden şu an güvenli:** Kullanıcı adı düzeni tek tırnağa izin vermiyor
(`server.js:1111` ve `1157`, hem kayıt hem güncelleme ucunda aynı düzen):

```js
/^(?!.*\.\.)[a-z0-9_][a-z0-9_.-]{1,18}[a-z0-9_]$/
```

Yalnız küçük harf, rakam, `_`, `.`, `-` kabul ediliyor. Yani bu kalıp
**bugün istismar edilemez** — ama kırılgan: düzen ileride gevşetilirse
(ör. Unicode kullanıcı adı desteği) sessizce XSS'e dönüşür.

**Öneri:** `esc()`'ye `'` → `&#39;` ekle (tek satır, derinlemesine savunma).

---

### 2.5 — [ORTA] Bağımlılıklarda 11 bilinen açık (1 yüksek)

**Kanıt** (canlı kapsayıcının içinde):

```
$ docker exec dizijpg-api npm audit
11 vulnerabilities (10 moderate, 1 high)
firebase-admin -> uuid, gaxios, google-gax, teeny-request, retry-request,
                  @google-cloud/firestore, @google-cloud/storage
```

**DÜZELTME (3 Ağu 2026):** Yukarıdaki "tamamı `firebase-admin` zincirinden
geliyor" tespiti **YANLIŞTI**. `npm audit --json` ile paket paket bakıldığında
11 açık üç ayrı kaynaktan geliyor ve **tek YÜKSEK olan `firebase-admin` değil,
`nodemailer`**:

| Kaynak | Açık | Şiddet | Kurulu | Önerilen | Not |
|---|---|---|---|---|---|
| `nodemailer` (doğrudan) | 1 | **YÜKSEK** | 6.10.1 | 9.0.3 | 3 ana sürüm atlar, KIRICI |
| `firebase-admin` zinciri | 8 | orta | 12.7.0 | 14.2.0 | `uuid`, `gaxios`, `google-gax`, `teeny-request`, `retry-request`, `@google-cloud/firestore`, `@google-cloud/storage` |
| `geoip-lite` → `ip-address` | 2 | orta | 1.4.10 | 1.2.2 | npm'in "düzeltmesi" aslında SÜRÜM DÜŞÜRME — uygulanmamalı |

`nodemailer` açıklarının çoğu kullanılmayan özelliklerde: kodda tek bir
`createTransport` var (`server.js:224`); `jsonTransport`, `raw:`, `envelope`
ve `List-*` başlıkları **hiç kullanılmıyor**. Yani CRLF/komut enjeksiyonu
maddelerinin pratik karşılığı yok. Kalan gerçek risk, adres ayrıştırıcısındaki
"beklenmedik alan adına mail" ve özyinelemeli DoS maddeleridir.

**Öneri (3 Ağu itibarıyla UYGULANMADI, karar ana oturuma bırakıldı):**
Üç güncelleme de **ana sürüm atlayan kırıcı** değişiklik; ayrıca `nodemailer`
tüm giden postayı (şifre sıfırlama, bildirim), `firebase-admin` push
bildirimlerini besliyor. Güncelleme ayrı ve tek başına bir iş olarak, test
hesabıyla uçtan uca doğrulanarak yapılmalı. `geoip-lite` için `npm audit fix`
ÇALIŞTIRILMAMALI (sürümü düşürür).

---

### 2.6 — [ORTA] Redis dış arayüzde dinliyor (tek katman koruma)

**Kanıt:**

```
$ ss -tulpn | grep 6379
tcp LISTEN 0 4096 0.0.0.0:6379 users:(("docker-proxy",pid=1578,fd=4))
tcp LISTEN 0 4096    [::]:6379 users:(("docker-proxy",pid=1588,fd=4))
```

`dopamall-redis` kapsayıcısı portu `0.0.0.0`'a bağlıyor. Erişim yalnızca
iptables ile kapatılmış:

```
-A INPUT -s 172.16.0.0/12 -p tcp --dport 6379 -j ACCEPT
-A INPUT -s 127.0.0.1/32  -p tcp --dport 6379 -j ACCEPT
-A INPUT -p tcp --dport 6379 -j DROP
-A DOCKER-USER ! -s 127.0.0.1/32 -p tcp --dport 6379 -j DROP
```

**Etki:** Şu an dışarıdan erişilemiyor (iki iptables katmanı var). Ancak
kural yanlışlıkla silinirse veya Docker kuralları yeniden yazarsa Redis anında
kimlik doğrulamasız olarak internete açılır. **Bu dizi.jpg'nin servisi değil**
(dopamall'a ait) — dokunulmadı.

**Öneri:** dopamall `docker-compose.yml`'de port eşlemesini
`127.0.0.1:6379:6379` yap. Sahibi başkasıysa bildir.

---

### 2.7 — [DÜŞÜK] Otomatik güvenlik güncellemesi kapalı

```
$ systemctl is-enabled unattended-upgrades   -> kurulu değil/kapalı
$ apt-get -s upgrade | grep -c "^Inst"       -> 0   (şu an güncel)
$ cat /etc/os-release                        -> Debian 12 (bookworm), çekirdek 6.1.0-45
$ ls /var/run/reboot-required                -> Gerekmiyor
```

Sistem şu an tamamen güncel; risk sadece "bir dahaki kritik yamayı kaçırma"
riski.

---

### 2.8 — [DÜŞÜK] Origin sertifikası kendinden imzalı, CSP başlığı yok

```
$ openssl s_client -connect 154.53.163.3:443 ...
subject=CN=dizijpg.com, O=Dizijpg
issuer =CN=dizijpg.com, O=Dizijpg          <-- kendinden imzalı, 10 yıllık
```

Kullanıcıya giden sertifika sağlam (Let's Encrypt, `notAfter=Sep 12 2026`,
certbot timer aktif — 39 gün kaldı, otomatik yenilenecek). Ama origin
sertifikası kendinden imzalı olduğundan Cloudflare SSL modu büyük olasılıkla
"Full" — "Full (strict)" değil. Bu, CF ile origin arasında araya girme
saldırısına teorik açık bırakır.

Güvenlik başlıkları iyi ama `Content-Security-Policy` yok:

```
strict-transport-security: max-age=15552000; includeSubDomains
x-content-type-options: nosniff
x-frame-options: SAMEORIGIN
referrer-policy: strict-origin-when-cross-origin
(Content-Security-Policy YOK)
```

CSP olsaydı §2.1'deki XSS'in etkisi büyük ölçüde sınırlanırdı.

---

### 2.9 — [BİLGİ] Kullanılmamış bir SSH anahtarı var

`/root/.ssh/authorized_keys` içinde 5 anahtar var, 4'ü kullanılmış:

| # | Etiket | Kullanım |
|---|--------|----------|
| 1 | `k1m03s02@cursor` | 4 giriş |
| 2 | `alicihanceliktht@gmail.com` | 24 giriş |
| 3 | `bilalcayir@magnumoto.com` | 1 giriş |
| 4 | `alicihancelik@magnumoto.com` | 3.580 giriş (ana anahtar) |
| 5 | `alicihanceliktht@gmail.com` | **hiç kullanılmamış** |

Dosya 19 Nis 2026'dan beri **değiştirilmemiş** (`stat` ile doğrulandı) — yani
saldırgan tarafından eklenmiş bir anahtar değil, hepsi eskiden beri orada.

`[DOĞRULANMALI: 5. anahtar ve 3. anahtar (bilalcayir@magnumoto.com) hâlâ gerekli
mi? Gerekmiyorsa silinmeli — kullanılmayan anahtar gereksiz saldırı yüzeyi.]`

---

### 2.10 — [BİLGİ] Kendi izleme betiğimiz hız limitine takılıyor

Giriş ucundaki 429'ların **tamamı** bize ait:

```
POST /api/auth/giris  -> 429 : 314 istek
  175 x 188.119.45.48  (user-agent: "node")
  139 x 176.88.21.131  (user-agent: "node")
```

Bu bir saldırı değil; hız limitinin **çalıştığının kanıtı**. Ama izleme betiği
gereksiz yere giriş ucunu dövüyor ve gerçek bir saldırıyı günlükte gizleyebilir.

`[DOĞRULANMALI: 176.88.21.131 sizin ikinci makineniz/dinamik IP'niz mi?
Ana SSH anahtarınızla (alicihancelik@magnumoto.com) 31 Tem'den beri her 60
saniyede bir giriş yapıyor — otomatik bir izleme döngüsü gibi görünüyor.
Sizin değilse bu KRİTİK'tir ve anahtar hemen değiştirilmelidir.]`

---

## 3. Saldırı trafiği özeti

**Dönem:** 20 Tem – 3 Ağu 2026 (nginx), tüm journal geçmişi (SSH).

### SSH

| Ölçüm | Değer |
|---|---|
| Toplam başarılı giriş | 3.609 — **hepsi publickey, hepsi root** |
| Parolayla başarılı giriş | **0** |
| Başarısız parola denemesi (24 saat) | 1.454 |
| "Invalid user" denemesi (24 saat) | 588 |
| Benzersiz saldırgan IP (24 saat) | 155 |
| fail2ban toplam yasaklama | 432 |
| Şu an yasaklı | 8 |

En aktif SSH saldırganları (24 saat): `195.178.110.26` (51), `2.57.121.112` (25),
`160.251.206.106` (21), `195.178.110.137` (18), `50.255.62.89` (12).
Denenen kullanıcı adları kripto-madenci botlarına özgü: `solana`, `sol`, `solv`.

### Web (125.615 istek)

| Kalıp | İstek sayısı |
|---|---|
| `.php` taraması (WordPress vb.) | 15.914 |
| `/wp-*` yolları | 4.397 |
| `/.env` denemesi | **1.224** (69 farklı IP) |
| `/cgi-bin/...` (shell enjeksiyonu) | 178 |
| `/.git/*` | 94 |
| `/vendor/*` | 88 |
| `/.aws/*` | 64 |
| `/actuator` | 32 |
| `/xmlrpc.php` | 26 |
| `/boaform`, `/HNAP1` (yönlendirici açıkları) | 21 |
| Dizin geçişi (`../`, `%2e%2e`) | 8 |
| SQLi/XSS kalıbı | 5 (**3'ü bizim eski test isteğimiz**) |

`.env` avcıları: `213.209.159.154` (504), `213.209.159.114` (158),
`45.148.10.200` (75), `129.212.227.100` (69).

Gerçek dışarıdan gelen tek "ciddi" yük, Mozi IoT botnet'inin indirme komutu
(`202.47.56.96`, `223.123.43.34`) — nginx her ikisine de **400** döndü, Node'a
hiç ulaşmadı.

### Uygulama kimlik doğrulama

| Ölçüm | Değer |
|---|---|
| `POST /api/auth/giris` başarılı (200) | 856 |
| Başarısız (401) | 45 — bunun 22'si kendi testlerimiz |
| Hız limitine takılan (429) | 314 — **tamamı kendi izleme betiğimiz** |

Dışarıdan gelen en yüksek başarısız giriş kümesi: `176.219.8.20` (7 deneme).
**Kaba kuvvet saldırısı izi yok.**

---

## 4. Doğrulanan korumalar

### 4.1 Admin IP kısıtı — ÇALIŞIYOR (kanıtlı)

Beyaz liste dışı bir kaynaktan (sunucunun kendi IP'si) tüm admin uçları:

```
/api/admin              -> 404
/api/admin/ozet         -> 404
/api/admin/istekler     -> 404
/api/admin/kullanicilar -> 404
```

Başlık sahteciliğiyle atlatma denemesi, Cloudflare atlanıp doğrudan origin'e
bağlanılarak yapıldı — **yine 404**:

```
$ curl -k -H "Host: dizijpg.com" -H "CF-Connecting-IP: 188.119.45.48" \
       https://154.53.163.3/api/admin/ozet          -> 404
$ curl -k -H "Host: dizijpg.com" -H "X-Forwarded-For: 188.119.45.48" \
       https://154.53.163.3/api/admin/ozet          -> 404
```

Neden çalışıyor: nginx istemcinin gönderdiği IP başlıklarını güvenilir
`$remote_addr` ile eziyor (`sites-available/dizijpg.com:163-165, 179-181`) ve
`geo` bloğu real_ip çözümlemesinden **sonraki** adrese bakıyor.

**Günlüklerden kanıt** — admin uçlarına 200 dönen tüm IP'ler:

```
6971 x 188.119.45.48   (yönetici, beyaz listede)
  11 x 154.53.163.3    (sunucunun kendisi, iç çağrı)
   5 x 127.0.0.1       (yerel)
```

Beyaz liste dışından **tek bir başarılı admin isteği yok**. Dışarıdan gelen
denemeler 403/404 aldı (`46.154.5.33`'ten 92 x 403 — bu da yöneticinin mobil
IP'sinden gelen kendi istekleri, kısıt onu da düzgün engellemiş).

### 4.2 Sunucu tarafında ikinci katman

nginx'e ek olarak Node de kendi kontrolünü yapıyor
(`backend/server.js:4693-4700`) — nginx kuralı kazara silinse bile uçlar açık
kalmaz:

```js
function adminKisit(req, res, next) {
  const ip = gercekIp(req);
  const izinli = ADMIN_IPLER.split(',')...;
  const tokenGecerli = !!ADMIN_TOKEN && esitGizli(req.headers['x-admin-token'] || '', ADMIN_TOKEN);
  if (izinli.includes(ip) || tokenGecerli) return next();
  return res.status(403).json({ hata: 'Erişim reddedildi' });
}
```

Token yalnız başlıktan okunuyor (adres çubuğundan değil) ve `timingSafeEqual`
ile sabit zamanda karşılaştırılıyor. Tüm `/admin/*` rotalarında `adminKisit`
var (kontrol edildi: 12+ rota, istisnasız).

`/var/www/dizijpg/admin.html` **yok** — panel HTML'i yalnız korumalı uçtan
servis ediliyor. `https://dizijpg.com/admin.html` isteği Flutter kabuğunu
(index.html) döndürüyor, paneli değil.

### 4.3 Hız limitleri — ÇALIŞIYOR

18 ayrı hız limiti tanımlı (`server.js:643-655` ve dağınık), kullanıcı kimliği
veya IP ile anahtarlanmış. Devreye girdiğinin kanıtı: 314 x 429 (giriş),
6 x 429 (yorum), TMDB uçlarında da tetiklenmiş.

### 4.4 SQL enjeksiyonu — BULUNAMADI

`backend/server.js` (256 KB) tarandı. String birleştirmeyle kurulan **hiçbir**
SQL yok. Tek dinamik SQL:

```js
// server.js:756
const kolon = BILDIRIM_TERCIH_KOLON[tur];    // sabit eşleme tablosu
if (kolon) {
  await havuz.query(`SELECT ${kolon} AS ac FROM kullanicilar WHERE id=$1`, [aliciId])
```

`kolon` kullanıcı girdisinden değil, kodda sabit tanımlı bir sözlükten geliyor
(`bildir_begeni`/`bildir_yanit`/`bildir_takip`/`bildir_mesaj`/`bildir_etiket`)
ve `if (kolon)` ile korunuyor — **istismar edilemez**. Diğer tüm sorgular
`$1, $2...` parametreli.

### 4.5 Komut enjeksiyonu — BULUNAMADI

Kod tabanında yalnız 2 dış komut çağrısı var, ikisi de güvenli:

- `server.js:107` — `execFile('ffmpeg', [...])` dizi biçiminde argüman
  (kabuk yok), dosya yolu sunucu tarafında üretiliyor.
- `server.js:5074` — `execFile('/bin/sh', ['-c', ...])` kabuk kullanıyor **ama**
  içine giren tüm değerler `DATABASE_URL` ortam değişkeninden ve sunucunun
  ürettiği zaman damgasından geliyor; kullanıcı girdisi yok. Ayrıca
  `adminKisit` arkasında.

`shell: true` kullanımı **hiç yok**. Kullanıcı girdisini `path.join`'e veya
dosya okuma/yazma çağrılarına doğrudan geçiren yer **yok**.

### 4.6 Yol geçişi / dosya sızıntısı — YOK

Canlı test, hiçbiri sızdırmıyor (hepsi Flutter kabuğuna veya 404'e düşüyor):

```
/api/medya/%2e%2e%2f%2e%2e%2fserver.js  -> 200, 2783 bayt (index.html)
/api/medya/../../server.js              -> 200, 2783 bayt (index.html)
/api/medya/....//server.js              -> 404
/.env                                   -> 200, 2783 bayt (index.html)
/api/../.env                            -> 200, 2783 bayt (index.html)
/.git/config                            -> 200, index.html (gerçek .git YOK)
/main.dart.js.map                        -> 200, index.html (kaynak haritası YOK)
```

`JWT_SECRET`, `DB_SIFRE`, `TMDB_TOKEN` hiçbir yanıtta geçmiyor.

### 4.7 Posta sunucusu — AÇIK RÖLE DEĞİL

```
MAIL FROM: disarikaynak@example.org  -> 250 2.1.0 Ok
RCPT TO:   hedefdisari@example.net   -> 454 4.7.1 Relay access denied
```

Spam rölesi olarak kötüye kullanılamıyor.

### 4.8 CORS — kısıtlı

```
$ curl -H "Origin: https://evil.example.com" https://dizijpg.com/api/saglik
(Access-Control-Allow-Origin başlığı DÖNMEDİ)
```

`server.js:133-136` yalnız `https://dizijpg.com` ve `https://www.dizijpg.com`'a
izin veriyor.

### 4.9 Yükleme güvenliği

Medya birimindeki **30.958 dosyanın tamamı** zararsız:

```
30016 jpg · 923 mp4 · 14 png · 5 ogg · 3 log · 1 txt · 1 gif
Çalıştırılabilir/tehlikeli dosya (.php/.sh/.svg/.html/.js/.py): 0
```

SVG **hiç yok** — polyglot/SVG-XSS riski gerçekleşmemiş. Tür sihirli baytlardan
doğrulanıyor (`server.js:2355`). Sahiplik kontrolü de var: medya yolu
`^/medya/m<kullanıcı_id>-[0-9a-f]{16}\.(gif|png|jpg|webp|mp4|webm|ogg|m4a|mp3|aac)$`
düzeniyle sınırlanmış (`server.js:3748, 4094`) — başkasının medyası
iliştirilemiyor. Statikler yalnız GET/HEAD alıyor (`yalnizGet`, `server.js:122`)
ve `X-Content-Type-Options: nosniff` gönderiliyor.

Canlı doğrulama: `POST /medya/` -> 405, `PUT /` -> 405, `TRACE /` -> 405.

### 4.10 Kimlik doğrulama ve şifreler

- JWT algoritması sabitlenmiş: `jwt.verify(token, JWT_SECRET, { algorithms: ['HS256'] })`
  (3 yerde, istisnasız) — `alg:none` saldırısı mümkün değil.
- Sır ortam değişkeninden geliyor, kodda sabit sır yok; eksikse süreç açılmıyor
  (`server.js:58`).
- Parolalar bcrypt ile: 18 gerçek hesabın hepsi `$2a$10$` (maliyet 10).

### 4.11 Sunucu bütünlüğü — TEMİZ

| Kontrol | Sonuç |
|---|---|
| `/tmp`, `/var/tmp`, `/dev/shm`'den çalışan süreç | **yok** |
| Silinmiş ikiliden çalışan süreç | **yok** |
| Madenci / ters kabuk / şüpheli süreç | **yok** |
| `/etc/ld.so.preload` | **yok** |
| `/etc/rc.local` | **yok** |
| SUID/SGID ikilileri | 28 adet, **hepsi standart Debian** |
| Son 3 günde `/usr/bin`, `/sbin` vb. değişiklik | **yok** |
| UID 0 olan başka hesap | **yok** (yalnız root) |
| `sudo` grubu | yalnız `kara` |
| `/etc/sudoers.d/` | yalnız `README` |
| Beklenmedik cron işi | **yok** (yalnız yedek + sağlık betiği) |
| Beklenmedik systemd birimi/timer | **yok** |
| `~/.bashrc` / `~/.profile` eklentisi | **yok** (2019–2024 tarihli, dokunulmamış) |
| Docker API TCP'de | **kapalı** (yalnız unix soketi) |

### 4.12 Sırlar ve veritabanı

```
$ ls -la /opt/dizijpg/.env /opt/dizijpg/firebase-admin.json
-rw------- 1 root root  457 .env               (yalnız root okuyabilir)
-rw------- 1 root root 2382 firebase-admin.json
$ ls /var/www/dizijpg/.env  -> YOK (web kökünde sır yok)
```

Depoda sır sızıntısı yok: takip edilen tek hassas isim `backend/.env.example`;
144 commit'lik geçmişte hiç `.env`/`.jks`/`adminsdk`/`.pem` eklenmemiş.
`firebase-gizli/` ve `backend/.env` `.gitignore`'da (doğrulandı).

Veritabanı (Docker'da izole, host portu **yok**):

| Kontrol | Sonuç |
|---|---|
| Toplam kullanıcı | 88 (18 gerçek + 70 misafir) |
| Yetkisiz/şüpheli hesap | yok, yasaklı hesap yok |
| Kullanıcı adı/bio içinde XSS yükü | **0 kayıt** |
| Yorumlarda XSS yükü (4.851 yorum tarandı) | **0 kayıt** |
| Kayıt eğrisi | normal (günde 1–19), ani sıçrama yok |
| Toplu silinme izi | yok |
| Giriş yapabilen DB rolü | yalnız `dizijpg` |

Host üzerindeki ayrı PostgreSQL (diğer projeler) dizi.jpg'ye yol açmıyor:
`listen_addresses='*'` ama iptables 5432'yi yalnız localhost + 2 bilinen IP'ye
açıyor, `pg_hba.conf` dışarıdan yalnız `dopamine_db`'ye izin veriyor.
**Dokunulmadı.**

### 4.13 Yedekler

7 günlük gece yedeği düzenli alınıyor (`/opt/dizijpg/yedekler/`, en yenisi
3 Ağu 04:00, 26 MB). Dosya sahibi root. Web kökünde değil, dışarıdan erişilemez.
Not: dizin izni `755` — sunucuda root dışı kabuk erişimi olan biri okuyabilir
(`admin`, `kara` hesapları). Küçük bir sıkılaştırma fırsatı (§5).

---

## 5. Yapılacaklar listesi (öncelik sırasıyla)

| # | İş | Öncelik | İş yükü | Risk |
|---|---|---|---|---|
| ~~1~~ | ~~`admin.html:760-762`'de `i.yol`, `i.method`, `title` alanlarını `esc()` ile sar (§2.1)~~ | **[x] BİTTİ 3 Ağu** — panelin TAMAMI tarandı, 7 kaçışsız nokta düzeltildi, `escJs()` eklendi, test yazıldı | — | — |
| ~~2~~ | ~~`server.js:195`'te `req.path`'i sunucu tarafında da kırp/temizle (ikinci katman)~~ | **[x] BİTTİ 3 Ağu** (`yolTemiz`/`metotTemiz`) | — | — |
| ~~3~~ | ~~80/443'ü Cloudflare IP aralıklarına kilitle, diğerine 444 dön (§2.2)~~ | **[x] BİTTİ 3 Ağu** | — | — |
| ~~4~~ | ~~`PasswordAuthentication no` **veya** `admin` hesabına `nologin` kabuk (§2.3)~~ | **[x] BİTTİ 3 Ağu** (ikisi de yapıldı) | — | — |
| ~~5~~ | ~~`esc()`'ye `'` → `&#39;` ekle (§2.4)~~ | **[x] BİTTİ 3 Ağu** (+ `escJs()`) | — | — |
| 6 | `Content-Security-Policy` başlığı ekle (§2.8) — XSS etkisini kökten sınırlar | Orta | 1-2 saat | Orta — Flutter web inline script kullanır, dikkatli ayarlanmalı, önce `Report-Only` ile dene |
| 7 | `nodemailer` (YÜKSEK) + `firebase-admin` güncelle (§2.5) — `geoip-lite`'a DOKUNMA | Orta | 1-2 saat | **Orta-Yüksek** — üçü de kırıcı ana sürüm; posta ve push'u uçtan uca test et |
| ~~8~~ | ~~fail2ban `bantime`'ı 1 saat → 24 saat~~ | **[x] BİTTİ 3 Ağu** | — | `maxretry` BİLEREK 5'te bırakıldı (§7) |
| 9 | Cloudflare SSL modunu "Full (strict)" yap + CF Origin Certificate kur (§2.8) | Düşük | 30 dk | Orta — yanlış sırayla yapılırsa 526 hatası |
| 10 | Kullanılmayan SSH anahtarlarını sil (§2.9) | Düşük | 5 dk | Düşük — silmeden önce sahiplerini teyit et |
| 11 | `unattended-upgrades` kur ve aç (§2.7) | Düşük | 10 dk | Düşük |
| 12 | dopamall Redis'i `127.0.0.1:6379:6379`'a bağla (§2.6) | Düşük | 5 dk | Düşük — **başka projeye ait, sahibiyle konuş** |
| 13 | `/opt/dizijpg/yedekler` iznini `700` yap | Düşük | 1 dk | Yok |
| 14 | İzleme betiğini `/api/auth/giris` yerine `/api/saglik`'a yönlendir (§2.10) | Düşük | 5 dk | Yok — günlük gürültüsünü azaltır |
| 15 | bcrypt maliyetini 10 → 12'ye çıkar (yalnız yeni/değişen parolalar için) | Düşük | 20 dk | Düşük |

---

## 6. Emin olamadıklarım

- `[DOĞRULANMALI: 176.88.21.131]` — Bu IP 31 Tem'den beri ana SSH anahtarınızla
  (`alicihancelik@magnumoto.com`) **her 60 saniyede bir** giriş yapıyor (toplam
  968 giriş) ve uygulamada da izleme trafiği üretiyor. Bir Türk Telekom
  adresi ve davranışı otomatik izleme döngüsüne benziyor — büyük olasılıkla
  sizin ikinci makineniz veya dinamik IP'niz. **Sizin değilse bu kritiktir:
  o anahtar başkasının elinde demektir ve derhal `authorized_keys`'ten
  çıkarılmalıdır.** Lütfen teyit edin.
- `[DOĞRULANMALI: 5. SSH anahtarı]` — `alicihanceliktht@gmail.com` etiketli
  ikinci anahtar hiç kullanılmamış. Ayrıca `bilalcayir@magnumoto.com` yalnız
  1 kez kullanılmış. İkisi de hâlâ gerekli mi?
- `[DOĞRULANMALI: Cloudflare panel ayarları]` — WAF kuralları, bot yönetimi ve
  SSL modu (Full mü Full-strict mi) sunucudan görülemiyor; CF panelinden
  bakılmalı. §2.2'deki risk, CF'de ne kadar koruma açık olduğuna göre büyür.
- `[DOĞRULANMALI: journal saklama süresi]` — SSH günlüğü journald'da tutuluyor
  (`/var/log/auth.log` yok). Geçmiş 2025'e kadar uzanıyor ama döngüsel dosya
  taşması nedeniyle bazı eski kayıtlar düşmüş olabilir. Bu denetim eldeki
  kayıtlara dayanıyor; teorik olarak silinmiş bir pencere olabilir — ancak
  `wtmp` (Tem 2025'ten beri, ayrı dosya) ile çapraz kontrol edildi ve **iki
  kaynak da aynı sonucu veriyor**: yalnız bilinen IP'lerden root girişleri.
- `[DOĞRULANMALI: diğer servisler]` — `brnmedia`, `restaurant`, `monteqr`
  (gunicorn 8000/8001) ve host PostgreSQL incelendi; dizi.jpg'ye açılan bir yol
  bulunamadı (hepsi `127.0.0.1`'e bağlı, ayrı süreçler, ayrı veritabanları).
  Ancak bu servislerin **kendi kod güvenlikleri denetlenmedi** — hepsi root
  olarak çalışıyor, birinde uzaktan kod çalıştırma açığı olsa tüm makine
  (dizi.jpg dahil) düşer. Ayrı bir denetim konusu.

---

*Bu denetim sırasında sunucuda hiçbir değişiklik yapılmadı. Bulunan tek yüksek
riskli açık (§2.1) istismar edilmemiş durumda ve düzeltmesi tek satırlık.*

---

## 7. Uygulanan düzeltmeler — 3 Ağustos 2026

### 7.1 §2.2 Cloudflare atlatması — KAPATILDI

**Ne yapıldı:** `dizijpg.com` ve `www.dizijpg.com` vhost'larının 80/443 trafiği
yalnız Cloudflare edge aralıklarından (+ `127.0.0.1`, `::1`, sunucunun kendi
IP'si `154.53.163.3`) kabul ediliyor. Dışarıdan doğrudan origin'e gelen istek
`444` alıyor (yanıtsız bağlantı kapatma).

**Neden nginx, güvenlik duvarı değil:** 80/443 portlarını `brnmedia.me` ve
`monteqr.me` vhost'ları da paylaşıyor. `ufw`/`iptables` kuralı port bazlıdır ve
o iki siteyi de keserdi. nginx'te vhost bazında kısıtlamak cerrahi oluyor;
posta (25/587/993) ve PostgreSQL (5432) hiç etkilenmiyor. **Kanıt:** değişiklik
sonrası `monteqr.me` origin'e doğrudan istekte hâlâ 200 dönüyor, `dizijpg.com`
dönmüyor.

**Neden `geo $realip_remote_addr`, `allow`/`deny` değil (ÖNEMLİ TUZAK):**
`allow`/`deny` (access modülü) ACCESS fazında çalışır — yani realip modülü
`CF-Connecting-IP`'yi uyguladıktan **sonraki** `$remote_addr`'a bakar. Oraya CF
aralıklarını yazmak, gerçek ziyaretçilerin IP'siyle karşılaştırma yapar ve
**herkesi engellerdi**. `$realip_remote_addr` ise değiştirilmeden önceki, yani
gerçekten TCP bağlantısını kuran tarafın (CF edge) adresidir.

**Kademeli uygulama:** Önce yalnız *günlükleme* açıldı (engelleme yok) ve 8
dakika izlendi: 2.322 meşru istek CF üzerinden akarken engellenecek istek
sayısı **yalnız 3**'tü ve üçü de doğrulama amaçlı kendi `curl`'lerimizdi.
Dakikada bir çalışan sağlık cron'u (`/usr/local/bin/dizijpg-saglik.sh`)
`https://dizijpg.com` adresine gittiği için CF üzerinden dönüyor ve
**engellenmiyor** (log ile doğrulandı). Ancak yine de sunucunun kendi IP'si
beyaz listeye alındı.

**Aralık listesi tazeleme:** `set_real_ip_from` ve `geo` girdileri artık tek
kaynaktan üretiliyor (`/etc/nginx/cloudflare/realip.conf` +
`geo-izin.conf`) — böylece ikisi asla birbirinden kayamaz.
`backend/araclar/cf_ip_tazele.sh` (sunucuda `/usr/local/bin/cf-ip-tazele.sh`,
her gün 04:30 cron) listeyi tazeler. **Siteyi kapatamaz:** biçim + asgari sayı
doğrulaması, değişiklik yoksa dokunmama, `nginx -t` başarısızsa otomatik geri
yükleme ve her değişiklikte mail. Bozuk/kısa yanıt senaryoları canlıda test
edildi; her ikisinde de hiçbir dosya değişmedi.

**Engellenen istek günlüğü:** `/var/log/nginx/dizijpg-cf-disi.log`
(logrotate `nginx` kuralı kapsıyor: günlük, 14 kopya). Bir şey yanlış giderse
ilk bakılacak yer burasıdır.

**TUZAK — `access_log` mirası (bu turda yaşandı ve düzeltildi):** nginx bir
seviyeden `access_log` mirasını **yalnızca o seviyede hiç `access_log`
tanımlanmamışsa** alır. Engellenen istek günlüğünü `server` bloğuna eklemek,
`http` seviyesindeki `access_log /var/log/nginx/access.log;` satırını o vhost
için **sessizce devre dışı bıraktı** — `dizijpg.com` trafiği 16 dakika boyunca
ana erişim günlüğüne hiç yazılmadı. Site çalışmaya devam ettiği için dışarıdan
belli olmuyordu; yalnız "sağlık cron'unun kayıtları neden durdu?" sorusu
kovalanınca ortaya çıktı. Çözüm: her üç `dizijpg.com` bloğunda ana günlük
satırı **açıkça tekrarlandı**. Bir vhost'a `access_log` eklerken bunu unutmayın.

**Doğrulama yöntemi notu:** "Site 200 dönüyor" bu tür bir hatayı yakalamaz.
Cloudflare arkasında origin'in gerçekten istek aldığını kanıtlamak için
önbelleği delen benzersiz bir sorgu dizesi (`?nocache=<zaman>`) gönderip
yanıttaki `cf-cache-status: DYNAMIC` başlığına ve **origin erişim günlüğünde o
satırın belirdiğine** bakın.

### 7.2 §2.3 SSH sıkılaştırma — KAPATILDI

- `/etc/ssh/sshd_config.d/10-dizijpg-guvenlik.conf` eklendi:
  `PasswordAuthentication no`, `KbdInteractiveAuthentication no`,
  `PermitRootLogin prohibit-password`. (Ana `sshd_config`'in ilk satırı
  `Include sshd_config.d/*.conf` olduğu ve sshd "ilk okunan değer kazanır"
  mantığıyla çalıştığı için bu dosya ana dosyayı ezer.)
- `admin` hesabının kabuğu `/usr/sbin/nologin` yapıldı.
- fail2ban `bantime` 1 saat → **24 saat**.

**Neden `nologin`, `passwd -l` değil (ÖNEMLİ TUZAK):** `admin`, `/home/admin/Maildir`
sahibi bir **posta hesabı** (30 günde 6 teslimat). Dovecot `passdb { driver = pam }`
kullanıyor, yani parolayı `/etc/shadow`'dan doğruluyor. `passwd -l` hash'in
başına `!` koyar ve **IMAP/SMTP girişini sessizce kırardı**. `nologin` ise
kabuğu kaldırır, hash'e dokunmaz; `pam_shells` Dovecot'un PAM yığınında **yok**
(yalnız `/etc/pam.d/chsh`'de), dolayısıyla posta kimlik doğrulaması etkilenmez.
**Kanıt:** değişiklik sonrası `admin@dizijpg.com`'a gönderilen test maili
Maildir'e düştü (5 → 6 dosya), shadow hash'in md5'i aynı kaldı.

`admin`'in bağımlılığı yok: `.ssh` dizini yok, `authorized_keys` yok, cron'u
yok, adına çalışan süreç yok, 30 günde tek bir IMAP girişi ve tüm geçmişte tek
bir SSH girişi yok. Hesap **silinmedi**.

**Neden `maxretry` 5'te bırakıldı (3'e düşürülmedi):** sshd filtresinde
`publickey = nofail` olduğu için tek tek "Failed publickey" sayılmıyor; ancak
`Disconnecting: Too many authentication failures` koşulsuz sayılıyor. Ajanında
çok anahtar bulunan meşru bir kullanıcı `ignoreip` dışı bir IP'den (örneğin
mobil) bağlanırsa `MaxAuthTries=6` aşılır ve 3 denemede kendini kilitleyebilirdi.
Gürültüyü asıl kesen `bantime`; 1h → 24h ile aynı saldırgan günde 24 kat daha
az deneme yapabiliyor.

### 7.3 §2.5 npm açıkları — UYGULANMADI (bilinçli)

Durum ve önerilen sürümler §2.5'te güncellendi. Güncelleme **yapılmadı** çünkü:
üç düzeltme de kırıcı ana sürüm atlıyor, `nodemailer` tüm giden postayı ve
`firebase-admin` push bildirimlerini besliyor, ayrıca o sırada `backend/Dockerfile`
ve `backend/server.js` başka bir çalışmanın altındaydı — konteyner yeniden
derlemek yarım kalmış değişiklikleri canlıya taşırdı. Ayrı bir iş olarak
yapılmalı.

### 7.4 Yedekler ve geri alma

Tüm yedekler `/root/guvenlik-yedek-20260803/` altında
(`sites-enabled/` içine **hiçbir** yedek dosya bırakılmadı):

| Dosya | İçerik |
|---|---|
| `dizijpg.com.nginx.orig` | nginx vhost'unun değişiklik öncesi hâli |
| `sshd_config.orig` | ana sshd yapılandırması (bu dosya değiştirilmedi) |
| `jail.local.orig` | fail2ban ayarları (SSH turundan önce) |
| `jail.local.posta-oncesi` | fail2ban ayarları (posta jail'lerinden önce, §7.6) |
| `crontab.orig` | root crontab |
| `admin.passwd.orig`, `admin.shadow.orig` | `admin` hesabının önceki kaydı |

**Geri alma (bir şey ters giderse):**

```bash
# 1) Cloudflare kilidini kaldır (site yine herkese açılır)
cp -a /root/guvenlik-yedek-20260803/dizijpg.com.nginx.orig \
      /etc/nginx/sites-available/dizijpg.com
nginx -t && systemctl reload nginx

# 2) SSH parola girişini geri aç
rm -f /etc/ssh/sshd_config.d/10-dizijpg-guvenlik.conf
sshd -t && systemctl reload ssh

# 3) admin kabuğunu geri ver
usermod -s /bin/bash admin

# 4) fail2ban bantime'ı geri al
cp -a /root/guvenlik-yedek-20260803/jail.local.orig /etc/fail2ban/jail.local
fail2ban-client -t && systemctl reload fail2ban

# 5) CF IP tazeleme cron'unu kaldır
crontab -l | grep -v cf-ip-tazele | crontab -
```

Yalnız Cloudflare kilidini geçici olarak gevşetmek için (nginx'i tamamen geri
almadan): `geo` bloğuna kendi IP'nizi `<IP>/32 0;` satırıyla ekleyip
`nginx -t && systemctl reload nginx`.

### 7.5 Bu turda çıkan yeni bulgular

- **[ORTA] Posta kimlik doğrulamasında fail2ban jail'i YOK.** — [x] KAPATILDI
  (3 Ağu 2026, bkz. §7.6). Yalnız `sshd` jail'i etkindi. Dovecot (993) ve
  Postfix SASL (587) internete açık ve **parola tabanlı**; SSH parola girişi
  kapatıldığı için `admin` hesabının parolası artık yalnız buradan denenebilir.
  `dovecot` ve `postfix-sasl` jail'leri eklendi.
- **[BİLGİ] `brnmedia.me` Cloudflare üzerinden 523 veriyor.** Origin sağlıklı
  (yerelde 200) ama nginx erişim günlüğünde bu alan adına ait **tek bir istek
  bile yok** — yani CF uzun süredir bu origin'e ulaşmıyor ve `/var/www/brnmedia-next`
  boş. Bizim değişikliğimizden önce de böyleydi; dizi.jpg ile ilgisi yok.
- **[BİLGİ] `/etc/letsencrypt/renewal/` boş.** Bu makinede certbot ile yönetilen
  sertifika yok; §2.8'deki "certbot timer aktif" notu yanıltıcı. Kullanıcının
  gördüğü Let's Encrypt sertifikası Cloudflare'in edge sertifikasıdır. Origin
  sertifikası hâlâ kendinden imzalı (§2.8, madde 9 geçerliliğini koruyor).

---

## 8. Posta kimlik doğrulaması için fail2ban — 3 Ağustos 2026

§7.5'te bulunan açık kapatıldı. `dovecot` ve `postfix-sasl` jail'leri etkin.
Değiştirilen tek dosya: `/etc/fail2ban/jail.local`. Dovecot, Postfix, nginx, SSH
ve uygulama yapılandırmalarına **dokunulmadı**; servisler **yeniden
başlatılmadı** (`fail2ban-client reload` kullanıldı).

### 8.1 Neden gerekliydi (canlı saldırı var)

SSH parola girişi 3 Ağu'da kapatıldığı için `admin` hesabının parolası artık
yalnız Dovecot (993/995/143/110) ve Postfix SASL (587) üzerinden denenebiliyordu
ve **denenmişti de** — 14 günlük günlükte `sasl_username=admin@dizijpg.com`
hedefli SASL denemeleri var (`185.93.89.36`).

### 8.2 İki tuzak (ikisi de sessiz başarısızlığa yol açardı)

**1) `logpath` çalışmaz — bu makinede rsyslog KAPALI.** `/var/log/mail.log`,
`/var/log/mail.err`, `/var/log/auth.log`, `/var/log/syslog` **yok**; her şey
journald'da. Stok `jail.conf` bu jail'ler için `logpath = %(dovecot_log)s`
bekliyor. Öylece `enabled = true` yazılsaydı jail açılır ama **hiçbir satır
okumazdı**. Her iki jail de `backend = systemd` kullanıyor.

**2) Postfix `postfix@-.service` örneği olarak çalışıyor.** `postfix.service`
yalnızca `exited` durumda bir sarmalayıcı; tüm SASL kayıtları
`postfix@-.service` altında (14 günde **40/40** satır, `journalctl -o json` ile
`_SYSTEMD_UNIT` sayılarak doğrulandı). Stok `filter.d/postfix.conf` ise
`journalmatch = _SYSTEMD_UNIT=postfix.service` diyor → **sıfır eşleşme** olurdu.
Jail'de `journalmatch` ezildi; fail2ban ikisini OR'layarak kullanıyor:
`_SYSTEMD_UNIT=postfix.service + _SYSTEMD_UNIT=postfix@-.service`.

### 8.3 Asıl karar: `findtime` 10 dk → **1 gün** (`maxretry` 5'te KALDI)

14 günlük gerçek günlükte, filtrenin **eşleştiği** satırların IP başına en yoğun
penceresi ölçüldü:

| IP | eşleşen | max/10dk | max/1sa | max/24sa |
|---|---|---|---|---|
| `185.93.89.36` | 35 | **14** | 14 | 24 |
| `141.147.182.224` | 20 | 2 | 2 | 20 |
| `104.251.181.131` | 10 | 2 | 2 | 8 |
| `104.251.181.132` | 10 | 2 | 2 | 8 |

Sonuç: yavaş yayılım yapan üç IP 10 dakikada en fazla **2** vuruş yapıyor —
yani `findtime = 10m` ile `maxretry` **5 de olsa 3 de olsa asla yakalanmazlar**.
`maxretry`'yi düşürmenin saldırıya karşı ek faydası **sıfır**; kazandıran
`findtime`'ı uzatmaktır. `findtime = 1d` + `maxretry = 5` ile dördü de yakalanır.

**`maxretry` neden 5'te bırakıldı (3 yapılmadı):** SSH ile tutarlı olsun diye ve
posta istemcileri (telefondaki posta uygulaması gibi) yanlış parolayı otomatik
olarak tekrar tekrar denediği için — 3 eşiği gerçek kullanıcıyı 24 saatliğine
kilitlerdi. Yukarıdaki ölçüme göre bunun karşılığında hiçbir güvenlik kazancı
da yok. Ek güvence: bu sunucuda **tüm journald geçmişinde (Kas 2025'ten beri)
tek bir başarılı IMAP/POP3 girişi yok** — yani şu an sunucuya bağlı yapılandırılmış
bir posta istemcisi bulunmuyor, kilitlenme riski bugün zaten teorik.

Yanlışlıkla kilitlenirsen: `fail2ban-client set <jail> unbanip <IP>`

### 8.4 `ignoreip` kararı

```
ignoreip = 127.0.0.1/8 ::1 172.19.0.0/16 154.53.163.3 154.53.163.5
           188.119.45.48 176.88.21.131
```

| Girdi | Neden |
|---|---|
| `127.0.0.1/8` | zaten vardı |
| `::1` | **yeni** — Dovecot IPv6'da da dinliyor (`[::]:993/995/143/110`), IPv4 loopback beyaz listedeyken IPv6 loopback değildi |
| `172.19.0.0/16` | **yeni** — `dizijpg-api` konteynerinin ağı. Uygulama postayı `host.docker.internal:25` üzerinden **SASL'sız** röle ediyor (Postfix `mynetworks` içinde). `postfix-sasl` bugün SASL hatası saymadığı için bu ağı banlayamaz; yine de "uygulamanın postası kesilir" senaryosuna karşı emniyet kemeri |
| `154.53.163.3` | **yeni** — sunucunun kendi genel IP'si; kendi kendini banlamasın |
| `154.53.163.5` | zaten vardı (ikinci sunucu) |
| `188.119.45.48` | zaten vardı (Rize) |
| `176.88.21.131` | **yeni** — Antalya/ofis; §2.10 ve §6'da "doğrulanmalı" diye işaretlenmişti, kullanıcı teyit etti |

**Dinamik IP riski ve neden yine de eklendi:** 176.88.21.131 ve 188.119.45.48
Türk Telekom dinamik adresleri olabilir, zamanla değişir. Ancak `ignoreip` bir
**erişim izni değil**, yalnızca "otomatik banlama muafiyeti"dir — adres el
değiştirse bile yabancının hâlâ geçerli parolaya/anahtara ihtiyacı olur. Buna
karşılık dışarıda bırakmanın bedeli, kullanıcının kendini 24 saatliğine posta ve
SSH dışında bırakması. Risk asimetrisi eklemekten yana. **6 ayda bir gözden
geçirin.** (`ignoreip` `[DEFAULT]`'ta olduğu için `sshd` jail'ini de kapsar.)

### 8.5 Kanıtlar

**Jail'ler aktif:**

```
$ fail2ban-client status
`- Jail list:   dovecot, postfix-sasl, sshd
```

**`fail2ban-regex` — 14 günlük gerçek günlüğe karşı (sıfır değil):**

```
dovecot        : 851 satır, 79 eşleşti   (57 pam_unix + 22 "auth failed")
postfix[auth]  : 3929 satır, 15 eşleşti
```

`postfix-sasl` az görünüyor çünkü stok `mode=auth`, parola tahmini olmayan
`Connection lost to authentication server` ve `Invalid authentication mechanism`
satırlarını **bilerek** dışlıyor. Bu doğru davranış, daha az yanlış pozitif.

**`fail2ban-regex` — testle üretilen TAZE günlüğe karşı (biçim gerçekten uyuyor):**

```
dovecot        : 18 satır, 18 eşleşti, 0 kaçtı
postfix[auth]  : 18 satır,  6 eşleşti  (6 SASL hatasının 6'sı; kalan 12 satır
                 alakasız connect/disconnect kayıtları)
```

**Devreye girdiğinin canlı kanıtı:** reload'dan hemen sonra `dovecot` jail'i,
`findtime = 10m` ile **asla yakalanamayacak olan** üç yavaş yayılımcıyı banladı:

```
Banned IP list: 141.147.182.224 104.251.181.132 104.251.181.131
```

**Ban boru hattı `postfix-sasl` için de çalışıyor** (son 24 saatte SASL saldırısı
olmadığı için doğal ban yoktu; rezerve TEST-NET-3 adresiyle doğrulandı):

```
$ fail2ban-client set postfix-sasl banip 203.0.113.7
-A f2b-postfix-sasl -s 203.0.113.7/32 -j REJECT --reject-with icmp-port-unreachable
$ fail2ban-client set postfix-sasl unbanip 203.0.113.7   # geri alındı
```

**POSTA HÂLÂ ÇALIŞIYOR (en önemli kanıt).** Geçici bir sistem hesabıyla test
edildi; `admin` hesabının parolası **bilinçli olarak aranmadı ve kullanılmadı**.
Hesap test biter bitmez `userdel -r` ile silindi.

```
IMAPS 993 (geçerli kimlikle):
  a1 OK [CAPABILITY ...] Logged in
  * LIST (\HasNoChildren) "." INBOX

Submission 587 (SASL + gerçek mail):
  235 2.7.0 Authentication successful
  250 2.0.0 Ok: queued as AD87EA0F35

Teslimat: /home/admin/Maildir/new/  6 dosya -> 7 dosya
  Subject: fail2ban posta jail dogrulama
  To: admin@dizijpg.com
```

**`ignoreip` çalışıyor:** localhost'tan bilerek 12 başarısız giriş yapıldı
(6 IMAP + 6 SASL). Filtreler bunları eşleştirdi ama **hiçbir ban oluşmadı**;
`f2b-*` zincirlerinde tek bir meşru IP yok.

**Hiçbir şey bozulmadı:**

| Kontrol | Sonuç |
|---|---|
| `/etc/shadow` md5 | değişiklik öncesi = sonrası (`98e26e16…`) — `admin` hash'ine dokunulmadı |
| `admin` hesabı | `passwd -S admin` → `P` (parola kullanılabilir), kabuk `nologin` |
| Dovecot / Postfix yeniden başlatıldı mı | **hayır** (`ActiveEnterTimestamp` = 30 Tem 20:09) |
| fail2ban | `reload` (restart değil) |
| f2b zincirlerinin dokunduğu portlar | yalnız `22` · `25,465,587,143,993,110,995` · `110,995,143,993,587,465,4190` — **8000/5432/6379/80/443 YOK** |
| `dizijpg.com/api/saglik` | `200 {"durum":"ok"}` |
| monteqr.me (8000) | origin `200` (dışarıdan `000` görünmesi sunucunun IPv6 çıkışı olmamasından; **önceden de öyleydi**) |
| dopamall-redis / dizijpg-db / PostgreSQL 5432 | çalışıyor, dokunulmadı |
| IPv6 IMAPS (`[::1]:993`) | banner dönüyor, sağlam |

> **Not:** İnceleme sırasında `dizijpg-api` konteynerinin 16:09'da yeniden
> başladığı görüldü. Bu **bu çalışmanın sonucu değildir** — `/opt/dizijpg/server.js`
> aynı dakikada başka bir ajan tarafından güncellenmiş (`RestartCount=0`, yani
> Docker'ın kendi yeniden başlatması değil, yeni dağıtım). fail2ban reload'ı bir
> konteyneri yeniden başlatamaz.

### 8.6 Geri alma

```bash
# Posta jail'lerini tamamen kaldır (SSH jail'i ve 24h bantime korunur)
cp -a /root/guvenlik-yedek-20260803/jail.local.posta-oncesi /etc/fail2ban/jail.local
fail2ban-client -t && fail2ban-client reload

# Yalnız bir IP'yi serbest bırak (jail'i kaldırmadan) — kilitlenirsen bunu kullan
fail2ban-client set dovecot      unbanip <IP>
fail2ban-client set postfix-sasl unbanip <IP>

# Yalnız bir jail'i geçici durdur
fail2ban-client stop dovecot
```

Bir şey ters giderse ilk bakılacak yer: `/var/log/fail2ban.log` ve
`fail2ban-client status dovecot|postfix-sasl`.
