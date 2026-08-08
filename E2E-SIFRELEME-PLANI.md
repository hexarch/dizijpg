# dizi.jpg — Özel Mesajlarda Uçtan Uca Şifreleme (E2E) Tasarım Belgesi

**Tarih:** 7 Ağustos 2026
**Kapsam:** Yalnız özel mesajlar (DM). Yorumlar, listeler, izleme geçmişi kapsam dışı.
**Yöntem:** `backend/server.js` + `app/lib/**` kaynak okuması, canlı sunucuda (`154.53.163.3`) **yalnız SELECT ve `ls`** düzeyinde ölçüm, dışarıdan kimliksiz `curl` doğrulaması, pub.dev / npm registry / MDN browser-compat-data üzerinden canlı sürüm doğrulaması.
**Bu turda kod yazılmadı, hiçbir dosya değiştirilmedi, sunucuya hiçbir şey yazılmadı.**

> Bu belgedeki her sayı ölçülmüştür; komut ve çıktı özetleri ilgili başlığın altındadır.
> Ölçemediğim, dışarıdan doğrulama gerektiren maddeler **[DOĞRULANMALI]** ile işaretlidir.
> Adam-gün tahminleri ölçüm değildir; açıkça "tahmin" olarak etiketlenmiştir.
>
> **Satır numarası uyarısı:** bu belge yazılırken `backend/server.js` ve `app/lib/api.dart`
> başka bir çalışmanın altındaydı. Bu yüzden kod referansları **fonksiyon/uç adıyla**
> verilmiştir, satır numarasıyla değil.

---

## 0. KARAR — E2E İPTAL, yerine DURAĞAN (at-rest) ŞİFRELEME (7 Ağu 2026, aynı gün)

> **Bu belgenin geri kalanı ARTIK UYGULANMIYOR.** Kullanıcı bu belgeyi okuduktan
> sonra kararını verdi: *"bizim tarafta şifrele."* E2E rafa kaldırıldı; yerine
> `mesajlar.metin` alanının **AES-256-GCM ile veritabanında şifreli saklanması**
> uygulandı. Belgenin ölçüm bölümleri (§2 veri modeli, §2.2 uç envanteri, §2.4
> "verinin durduğu 5 yer", §2.6 moderasyon bulgusu) **geçerliliğini koruyor** ve
> at-rest tasarımının dayanağıdır; §4-§8 arasındaki protokol/anahtar dağıtımı/
> faz planı bölümleri **uygulanmadı**.

**Ne değişti — tek cümleyle:** Anahtar sunucuda (`/opt/dizijpg/.env` →
`MESAJ_ANAHTARI`), sunucu içeriği çözebiliyor.

**Bunun sonucu olarak HİÇBİR ŞEY KIRILMADI.** §6'daki "kırılacak özellikler
envanteri" at-rest'te boştur:

| §6'daki endişe | At-rest'te durumu |
|---|---|
| Moderasyon / şikayet (§6.1) | Sunucu çözebiliyor → etkilenmedi (zaten §2.6'da fiilen çalışmadığı ölçüldü; ayrı iş) |
| Push bildirimi içeriği (§6.2) | Aynen çalışıyor: `bildirimEkle(..., {metin})` düz metni çağırandan alıyor, DB'den okumuyor |
| `GET /sohbetler` önizlemesi (§6.3) | Sunucu çözüp gönderiyor → `mesajOzeti()` aynen çalışıyor |
| İçerik/gönderi kartları (§6.4) | `icerik_tur/icerik_id/yorum_id` şifrelenmedi → TMDB poster çözümü yerinde |
| Medya ve sesli mesaj (§6.5) | Dosya yolu şifrelenmedi → yükleme, sihirli bayt doğrulaması, yetim temizliği aynen |
| Dışa aktarma / hesap silme / admin (§6.6) | Etkilenmedi |
| Web istemcisi (§6.7) | **Hiç etkilenmedi** — istemcide tek satır değişiklik yok |

### KAPSAM DIŞI KALAN TEHDİTLER — açıkça yazıyoruz, fazla güven vermiyoruz

At-rest şifreleme **şunları KORUR:**

* Çalınmış veritabanı dökümü (`pg_dump` çıktısı).
* Çalınmış gece yedeği — `/opt/dizijpg/yedekler/*.sql.gz`, bugün `755` dizin +
  `644` dosya, yani sunucuda kabuğu olan root-dışı hesaplar okuyabiliyor
  (`GUVENLIK-DENETIMI-2026-08-07.md` §3.2). `yedek.sh` **yalnız `pg_dump`**
  alıyor (7 Ağu'da okundu), yani **anahtar yedeğin içine girmiyor**: döküm tek
  başına işe yaramaz. Bu, at-rest'in en somut kazancıdır.
* Disk/volume snapshot'ına erişen ama uygulama sırlarına erişemeyen saldırgan.

**KORUMADIKLARI — iddia etmiyoruz:**

1. **Sunucunun tamamen ele geçirilmesi.** root olan biri `/opt/dizijpg/.env`'i
   de okur, `docker exec`le DB'ye de girer. Anahtar API sürecinin belleğinde.
2. **Uygulama düzeyinde yetki açığı.** Kimlik doğrulamayı aşan bir hata bulan
   saldırgan uçlardan ÇÖZÜLMÜŞ metin alır — şifreleme bu yolu kapatmaz.
3. **Google FCM'den geçen kopya** (§2.4 madde 5). Push gövdesindeki
   `data.metin` bugün de düz gidiyor; bunu ortadan kaldırmak E2E'nin işiydi.
4. **Telefondaki `SharedPreferences` push geçmişi** (§2.4 madde 4) — cihazda
   düz metin.
5. **DM medyası** (fotoğraf, sesli mesaj). Dosyanın KENDİSİ diskte şifresiz ve
   HTTP'den kimliksiz indirilebiliyor (§2.5). Şifrelenen yalnız METİNDİR;
   `mesajlar.medya` kolonundaki YOL bilerek şifrelenmedi (gerekçe:
   `backend/migrasyon-2026-08-07.sql` §3). **Medya güvenliği ayrı ve hâlâ
   AÇIK bir iş.**
6. **Üstveri.** Kimin kiminle, ne zaman, kaç kez mesajlaştığı; sesli mesajın
   uzunluğu (`ses_dalga`); paylaşılan dizi/film. Hepsi düz.

### Anahtar kaybı = kalıcı veri kaybı

`MESAJ_ANAHTARI` kaybolursa **tüm şifreli mesajlar kalıcı olarak okunamaz**
hâle gelir; kurtarma yolu yoktur. Anahtar parola yöneticisinde saklanmalıdır.
Ayrıntı ve dağıtım sırası: `backend/SERVER-JS-YAMASI.md`.

**Uygulanan dosyalar:** `backend/kripto.js`, `backend/test/kripto.test.js`,
`backend/migrasyon-2026-08-07.sql`, `backend/sema.sql`,
`backend/mesaj_sifrele_geri_doldur.js`, `backend/SERVER-JS-YAMASI.md`,
`backend/Dockerfile`, `backend/docker-compose.yml`, `backend/.env.example`.

---

## 1. Yönetici özeti

**Yapılabilir mi?** Evet. 2026 Ağustos itibarıyla Flutter + Node gerçeğinde E2E için
gereken her parça mevcut ve doğrulandı: saf Dart, web dahil her platformda çalışan,
Android'e **hiç native kod getirmeyen** bir kripto kütüphanesi var
(`cryptography_plus` 3.0.0) ve sunucu tarafında **hiçbir yeni npm bağımlılığına
gerek yok** (Node'un yerleşik `crypto`'su X25519/Ed25519 veriyor — yerelde
çalıştırılarak doğrulandı). Yani projenin bilinen AGP 9 / Kotlin 2.3.20 tuzağına
girmeden ve `flutter build web`'i bozmadan yapılabilir.

**Ama üç sert duvar var ve ikisi kriptografik değil, ürünsel:**

1. **Hesapların %81'i şifresiz ve e-postasız.** Canlıda 94 hesabın **76'sı misafir**
   (`sifre_hash IS NULL`, `email IS NULL`) ve bunların 4'ü zaten DM göndermiş.
   Parola türevli anahtar yedeği bu hesaplar için **matematiksel olarak imkânsız**.
   Bu kullanıcılar için E2E "uygulamayı silersen mesajların gider" demektir, başka
   seçenek yok.
2. **Flutter web'de güvenli anahtar deposu yok.** `flutter_secure_storage`'ın web
   uygulaması, AES anahtarını `extractable: true` üretip **şifreli veriyle aynı
   localStorage'a** yazıyor (kaynak koddan doğrulandı). Yani web'de "güvenli
   depolama" diye bir şey yok; sadece obfuscation var. Gerçek çözüm
   (`extractable:false` CryptoKey + IndexedDB) mümkün ama tüm kriptoyu
   `crypto.subtle`'a taşımayı zorunlu kılar — mobil ile web **iki ayrı kripto
   yolu** demektir.
3. **Signal kütüphanelerinin lisansı kapalı kaynak bir uygulamaya uymuyor.**
   `libsignal_protocol_dart` **GPL-3.0**, `@signalapp/libsignal-client` **AGPL-3.0**.
   İkisi de Play Store'da dağıtılan kapalı kaynak bir uygulama için hukuki risktir.
   Yani "hazır Signal kullanırız" seçeneği pratikte yok.

**En önemli tespit — E2E'nin çözeceğini sandığınız sorun, bugünkü asıl sorun değil.**
Bugün DM verisinin en açık iki kapısı veritabanı değil:

* Gece yedeği `/opt/dizijpg/yedekler/dizijpg-20260806-0400.sql.gz`, **35 MB, şifresiz,
  izin 644, dizin izni 755** — sunucuda root olmayan kabuk erişimi olan biri (bugün
  `kara` hesabı) tüm DM'leri düz metin okuyabilir.
* DM'e eklenen fotoğraf/ses **kimlik doğrulaması olmadan** internetten indirilebiliyor.
  Canlıda doğrulandı: `GET https://dizijpg.com/api/medya/m1-2f2dfa78379e570c.png` →
  **HTTP 200**, token yok, oturum yok. Tek koruma URL'in tahmin edilemezliği — ve o
  URL zaten çalınan yedeğin içinde düz metin olarak duruyor.

E2E ikisini de kökten çözer. Ama **at-rest şifreleme + yedek şifreleme + medyaya
erişim kontrolü de çözer ve tahminen 2-3 adam-gün sürer**; E2E'nin tam hâli 31-44
adam-gün. Aradaki fark, "sunucuyu ele geçiren *aktif* saldırgana ve kötü niyetli
operatöre karşı koruma" — yani sizin kendi sunucunuza güvenmemek. Bu meşru bir
tercih, ama bedeli aşağıdaki 6. bölümdeki özellik envanteridir.

**Tavsiyem (kararı siz vereceksiniz, bilgiyle):**
Faz 0'ı (bugünkü üç somut açık) **E2E kararından bağımsız olarak hemen** yapın —
1-2 gün, geri alınabilir, hiçbir özelliği bozmaz. E2E'yi istiyorsanız Faz 1-3 ile
**tek cihaz, yalnız yeni mesajlar, mobil-öncelikli** olarak başlayın ve çoklu cihaz
ile web E2E'sini bilinçli olarak erteleyin. "Tam Signal paritesi" bu ürün ve bu
kullanıcı sayısı için bugün gerekçelendirilemez; 8. ve 11. bölümde nedenini
ölçülerle yazdım.

---

## 2. Ölçülen mevcut durum

### 2.1 Veri modeli

`mesajlar` tablosu (14 kolon; `backend/sema.sql` + `migrasyon-2026-07-21c/22/24b/26/29/30b/31`):

| Kolon | Tür | E2E'de ne olacak |
|---|---|---|
| `id` | SERIAL | değişmez |
| `gonderen_id`, `alici_id` | INT FK | **değişmez — üstveri, şifrelenemez** |
| `metin` | TEXT, `CHECK (char_length BETWEEN 1 AND 2000)` | **şifreli gövdeye taşınır; CHECK kısıtı kalkmalı** (şifreli metin 2000'i aşar) |
| `medya` | TEXT (`/medya/mN-<16hex>.<uzantı>`) | yol kalır, **dosya içeriği şifrelenir** |
| `ses_dalga` | TEXT (`"<saniye>:<40 örnek>"`) | **üstveri — şifrelenmezse ses uzunluğu ve genlik profili sızar** |
| `icerik_tur`, `icerik_id` | TEXT/INT (`tv`/`movie` + TMDB id) | **sunucu bugün bunu okuyup TMDB'den poster çözüyor** — şifrelenirse bu iş istemciye geçer |
| `yorum_id` | INT FK → `yorumlar` | aynı sorun; ayrıca FK olduğu için şifrelenemez |
| `yanit_id` | INT FK → `mesajlar` | kalabilir (yalnız id) |
| `okundu`, `iletildi`, `duzenlendi` | BOOLEAN | değişmez |
| `tarih` | TIMESTAMPTZ | **değişmez — üstveri** |

### 2.2 DM ile ilgili uçlar (`backend/server.js`)

| Uç | Bugün ne yapıyor | E2E'de kırılan yön |
|---|---|---|
| `GET /sohbetler` | Partner başına **son mesajın `metin`/`medya`/`icerik_tur`'ünü** döndürüyor + okunmamış sayısı + çevrimiçi + `sohbetleriAyir()` | Önizleme metni sunucuda çözülemez |
| `GET /mesajlar/:kullaniciAdi` | Son 50 mesaj + `LEFT JOIN` ile **alıntılanan mesajın metnini**, `icerikBilgileri()` ile TMDB posterlerini, `gonderiler` önizlemesini çözüyor; ayrıca `okundu`/`iletildi` yazıyor ve zil bildirimini düşürüyor | Alıntı önizlemesi ve içerik kartı çözümü istemciye geçmeli |
| `POST /mesajlar` | Doğrulama (2000 karakter, medya sahipliği regex'i, `ses_dalga` biçimi, engelleme, `yanit_id` sahipliği) + `bildirimEkle(..., {metin})` | Sunucu içeriği doğrulayamaz; **push gövdesindeki `metin` kaynağı kurur** |
| `PATCH /mesajlar/:id` | Yalnız kendi **saf metin** mesajını düzenler | Şifreli gövde yeniden şifrelenip gönderilmeli |
| `DELETE /mesajlar/:id` | Siler + medyayı diskten kaldırır | değişmez |
| `POST /yaziyor` | Bellek içi `Map`, 6 sn pencere | değişmez (üstveri) |
| `POST /mesajlar/iletildi` | Push işlenince çift tik | değişmez |
| `POST /medya` | Sihirli bayttan tür doğrulama, `m<id>-<16hex>.<uzantı>`, videoda ffmpeg ile kapak karesi | **Şifreli bayt sihirli bayt doğrulamasını geçemez** |
| `GET /medya/*` | `express.static`, `yalnizGet` sarmalayıcı, **kimlik doğrulaması YOK** | Şifreli bayt servis edilirse sorun kalmaz |
| `POST /sikayet` | Yalnız `{tur, hedef_id, sebep}` saklar — **içerik kopyası saklamaz** | Aşağıya bakın: bu zaten bugün de eksik |

### 2.3 Canlı ölçekler (7 Ağu 2026, salt okuma SELECT)

```
mesajlar: toplam 87 | metinli 68 | medyalı 9 | sesli 1 | içerik kartlı 20
          farklı gönderen 9 | ilk 2026-07-21 | son 2026-08-03

gönderen dağılımı: gerçek hesap 5 kişi / 82 mesaj
                   MİSAFİR hesap 4 kişi /  5 mesaj

kullanicilar: 94 toplam | 18 gerçek | 76 misafir
              76 hesapta email NULL, 76 hesapta sifre_hash NULL   (aynı 76)

cihaz_tokenlari: 30 token, 30 farklı kullanıcı, platform dağılımı: android 30, ios 0
                 (web'de push kodu zaten hiç çalışmıyor — push.dart'ta 4 ayrı `if (kIsWeb) return`)

sikayetler: toplam 1 kayıt, türü 'yorum'.   DM şikayeti: 0 (hiç olmamış)

ayarlar: min_derleme = ''   onerilen_derleme = ''   (İKİSİ DE BOŞ)
```

**Bu sayıların üç sonucu var** ve belgenin geri kalanı bunlara dayanıyor:

* E2E, bugün **87 mesajı ve fiilen 9 kişiyi** koruyacak. Yatırım kararı buna göre verilmeli.
* **iOS ve web'de tek bir push cihazı yok.** Yani "arka planda çekip yerelde çöz"
  tasarımının iOS kısıtları bugün *teorik* bir sorun. Android'e odaklanmak meşru.
* **Sürüm kapısı hiç kurulmamış.** `min_derleme` boş olduğu için `/surum-kontrol`
  bugün her zaman `zorunlu:false` dönüyor. Kapı kodda var (`app/lib/surum_kapisi.dart`,
  testi de var) ama **canlıda bir kez bile ateşlenmemiş.** E2E geçişinin bel bağladığı
  mekanizma, prova edilmemiş bir mekanizmadır.

### 2.4 DM verisi bugün kaç yerde duruyor

| # | Yer | Şifreli mi | Erişim |
|---|---|---|---|
| 1 | PostgreSQL `mesajlar.metin` | Hayır | Docker içinde, host portu yok, yalnız `dizijpg` rolü |
| 2 | **Gece yedeği** `/opt/dizijpg/yedekler/*.sql.gz` | **Hayır** | **izin 644, dizin 755** → sunucuda kabuğu olan herkes |
| 3 | Medya birimi (`dizijpg_dosyalar` volume, `/veri/medya`) | Hayır | **HTTP'den kimliksiz** (aşağıda kanıt) |
| 4 | Telefonda `SharedPreferences` push geçmişi (`bildirim_mesajlari_<ad>`, kişi başına son 10 mesaj, düz metin) | Hayır | Cihazın uygulama sanal alanı |
| 5 | Firebase FCM sunucuları (push `data.metin`, 500 karaktere kadar) | Taşımada evet, Google tarafında düz | Google |

5 numaralı madde önemli: **bugün mesaj metninin bir kopyası Google'ın FCM
altyapısından geçiyor.** Gizlilik politikası "Push bildirimleri Google Firebase
üzerinden iletilir" diyor ama mesaj *içeriğinin* de gittiğini söylemiyor.
E2E'nin en net ve en ucuz kazançlarından biri bu kopyayı ortadan kaldırmaktır.

### 2.5 Kanıt: DM medyası kimliksiz indirilebiliyor

```
$ (sunucuda, salt okuma) SELECT medya FROM mesajlar WHERE medya IS NOT NULL LIMIT 1;
  /medya/m1-2f2dfa78379e570c.png

$ (dışarıdan, oturum/token YOK)
  curl -s -o /dev/null -w "%{http_code} %{size_download} %{content_type}" \
       https://dizijpg.com/api/medya/m1-2f2dfa78379e570c.png
  200 69 image/png
```

Bu tasarım gereğidir (`app.use('/medya', yalnizGet(medyaStatik))`), kaza değil ve
avatar/yorum medyası için mantıklı. Ama **DM medyası da aynı dizinde ve aynı
kurallarla servis ediliyor.** Dosya adındaki 16 hex = 64 bit rastgelelik URL'i
tahmin edilemez yapar; fakat URL'in kendisi veritabanında ve yedekte düz metin
duruyor. Yani yedek sızarsa **fotoğraf ve sesli mesajlar tek `curl` ile indirilir**.

### 2.6 Bugün DM moderasyonu fiilen ÇALIŞMIYOR

Bu, belgenin en beklenmedik bulgusu ve 6.1'in tamamını değiştiriyor:

* **İstemcide DM mesajını şikayet etme yolu yok.** `sikayetEtSheet(context, tur, hedefId)`
  (`app/lib/ekranlar/ortak.dart`) `'mesaj'` türünü destekliyormuş gibi belgelenmiş,
  ama **`tur:'mesaj'` ile çağıran tek bir yer yok**. `sohbet.dart` içinde `sikayet`
  kelimesi hiç geçmiyor; baloncuk uzun-bas menüsünde yalnız Yanıtla / Düzenle / Sil var.
  Gerçek çağıranlar: `'yorum'` (akış, yorumlar, keşfet) ve `'kullanici'` (profil).
* **Yönetim paneli şikayet edilen mesajın metnini çözmüyor.** `GET /admin/sikayetler`
  yalnız `tur === 'yorum'` ve `tur === 'kullanici'` için `hedef_ozet` dolduruyor;
  `'mesaj'` için tabloda sadece `#<hedef_id>` görünür ve **hiçbir aksiyon butonu çizilmez**
  (`backend/admin.html` → `satirSik()`).
* `backend/server.js`'te **`mesajlar` tablosundan `metin` okuyan tek bir admin ucu yok**
  (`grep "FROM mesajlar"` → hepsi sayaç, sahiplik kontrolü veya yetim medya temizliği).
* Canlıda **hiç DM şikayeti olmamış** (toplam 1 şikayet, o da yorum).

**Sonuç:** "E2E moderasyonu bozar" cümlesi bu proje için yanlış. E2E, **bugün zaten
olmayan bir yeteneği** bozmuyor; onu ilk kez inşa etmeye zorluyor. Ve bu, Play
Store'un UGC politikası açısından **bugün de var olan bir açıktır** — E2E'den bağımsız
olarak kapatılmalı.

---

## 3. Tehdit modeli — neyi çözer, neyi çözmez

Üç sütun karşılaştırması. **At-rest** = mesaj metni DB'ye sunucudaki bir anahtarla
şifreli yazılır (anahtar `.env`'de veya KMS'te), sunucu okurken çözer.

| # | Senaryo | Bugün | At-rest şifreleme | **E2E** |
|---|---|---|---|---|
| 1 | Gece yedeği (`.sql.gz`) çalınır | ❌ Tüm DM düz metin | ✅ Korur (anahtar yedekte değilse) | ✅ Korur |
| 2 | Canlı DB dosyaları/volume çalınır | ❌ Korumaz | ✅ Korur (anahtar ayrı yerdeyse) | ✅ Korur |
| 3 | DB'ye salt-okuma erişimi (SQLi, sızan parola) | ❌ Korumaz | ✅ Korur | ✅ Korur |
| 4 | **DM medyası URL'i sızar** | ❌ Korumaz (2.5) | ⚠️ Kısmen — DB şifrelense de dosya düz | ✅ Korur (dosya da şifreli) |
| 5 | Sunucu tamamen ele geçirilir, saldırgan **pasif** (o anki durumu okur) | ❌ | ❌ **Korumaz** — anahtar sunucuda | ✅ **Korur** |
| 6 | Sunucu ele geçirilir, saldırgan **aktif ve kalıcı** (kod değiştirir) | ❌ | ❌ | ⚠️ Geçmişi korur, **geleceği korumaz**: sahte anahtar dağıtıp MITM yapabilir (bkz. aşağıda) |
| 7 | Kötü niyetli/meraklı operatör (siz, ileride bir çalışan) | ❌ | ❌ **Korumaz** | ✅ **Korur** — E2E'nin asıl gerekçesi |
| 8 | Yasal talep / mahkeme kararıyla içerik istenmesi | ❌ Verilebilir | ❌ Verilebilir | ✅ Veremezsiniz (üstveri hariç) |
| 9 | Çalınan JWT (90 gün ömürlü, `SharedPreferences`'ta düz) | ❌ Tüm sohbeti okur | ❌ Tüm sohbeti okur | ✅ **Korur** — token şifreli baytı getirir, çözemez |
| 10 | Ele geçirilmiş/çalınmış cihaz, ekranı açık | ❌ | ❌ | ❌ **Korumaz** — E2E'nin sınırı burasıdır |
| 11 | Cihaz çalınır, kilitli (Android Keystore) | ❌ | ❌ | ⚠️ Anahtar Keystore'daysa korur; yerel mesaj kopyası varsa o ayrı korunmalı |
| 12 | **Üstveri**: kim kiminle, ne zaman, ne sıklıkla, kaç mesaj, mesaj boyutu, sesin uzunluğu | ❌ | ❌ | ❌ **KORUMAZ.** `gonderen_id`, `alici_id`, `tarih`, `ses_dalga` ve şifreli metnin uzunluğu sunucuda kalır |
| 13 | Push içeriğinin Google'dan geçmesi | ❌ | ❌ (sunucu çözüp gönderiyor) | ✅ Korur |
| 14 | Ağı dinleyen (kafe Wi-Fi, ISP) | ✅ TLS zaten korur | ✅ | ✅ |
| 15 | Cloudflare'ın TLS'i sonlandırması (trafiği görebilmesi) | ❌ Görebilir | ❌ Görebilir | ✅ Korur |

**5 ve 7 numaralı satırlar E2E'nin tek gerçek farkıdır.** Diğer her satırda
at-rest şifreleme aynı sonucu verir ve 2-3 günde biter. Kararınızı bu iki satırın
sizin için ne kadar önemli olduğuna göre verin:

* **5 (ele geçirilmiş sunucu, pasif okuma):** dizi.jpg günde ~1.450 başarısız SSH
  denemesi ve ~16.000 tarama isteği alıyor (`GUVENLIK-DENETIMI.md` §3). Bugüne kadar
  hiçbiri girmedi, ama sunucuda dizi.jpg'nin dışında **root olarak çalışan başka
  projeler var** (`brnmedia`, `restaurant`, `monteqr`) ve onların kodu hiç
  denetlenmedi (aynı belge §6). O projelerden birinde uzaktan kod çalıştırma açığı
  varsa dizi.jpg'nin DB'si de düşer. **Bu senaryo teorik değil.**
* **7 (operatör):** bugün tek operatör sizsiniz. İleride ikinci bir kişi olursa
  ya da projeyi devrederseniz E2E'nin değeri artar.

### 3.1 E2E'nin kırılmayan sınırı: anahtarı sunucu dağıtıyor

Bunu belgede net yazmak zorundayım, çünkü E2E'ye dair en yaygın yanılgı budur.

Alıcının açık anahtarını istemciye **sunucu** verir. Sunucuyu ele geçiren *aktif*
saldırgan, alıcının açık anahtarı yerine **kendi ürettiği bir anahtarı** gönderebilir;
gönderen farkında olmadan saldırgana şifreler, saldırgan okur ve gerçek alıcıya yeniden
şifreleyip iletir. Bu, WhatsApp/Signal dahil **her** E2E sistemi için geçerlidir.

Tek savunma **güvenlik numarası / parmak izi doğrulama**: iki kullanıcı sohbet
ekranında birbirinin anahtar özetini (60 haneli sayı veya QR) karşılaştırır ve
"anahtar değişti" uyarısı görür. Bunu eklemezseniz E2E, "sunucuya güvenmiyorum"
iddiasını **tam olarak** karşılamaz — yalnızca 1-4, 8, 9, 13, 15 numaralı satırları
karşılar (ki bunlar zaten değerli).

**Tavsiyem:** Faz 2'de en azından "anahtar değişti" uyarısını (TOFU — ilk gördüğüne
güven) ekleyin; tam parmak izi karşılaştırma ekranını Faz 5'e bırakın. TOFU uyarısı
ucuzdur (yerelde partner anahtarının hash'ini tutmak) ve sessiz MITM'i gürültülü hâle
getirir.

---

## 4. Protokol seçimi

### 4.1 Doğrulanmış kütüphane manzarası (7 Ağu 2026, pub.dev/npm/GitHub API'lerinden canlı)

| Paket | Sürüm | Son yayın | Web | Native kod | Durum |
|---|---|---|---|---|---|
| `cryptography` (dint.dev) | 2.9.0 | 2025-11-21 | ✅ | Yok (saf Dart) | Durgun — 26 ay ölü kaldı, Kas 2025'te canlandı, o günden beri commit yok |
| **`cryptography_plus`** (fork) | **3.0.0** | **2026-03-02** | ✅ | **Yok** | **Aktif** — repo son push 2026-07-22 |
| `cryptography_flutter(_plus)` | 2.3.4 / 3.0.2 | — | ❌ | Kotlin + Swift | 🔴 **AGP 9 ile KIRILIYOR** |
| `libsignal_protocol_dart` | 0.8.2 | 2026-06-20 | ✅ | Yok | Aktif ama 🔴 **GPL-3.0** |
| `sodium` | 4.0.4 | 2026-08-04 | ✅ (JS) | Build hooks ile derleniyor | Aktif; `sodium_libs` ve `flutter_sodium` **terk edildi** |
| `webcrypto` (google.dev) | 0.6.1 | 2026-05-22 | ✅ | BoringSSL FFI | Çok aktif ama 🔴 **X25519/Ed25519 YOK** (yalnız P-256/384/521 ECDH) |
| `flutter_secure_storage` | 11.0.0 | 2026-08-06 | ✅ | Kotlin — ama `is:built-in-kotlin` etiketi **VAR** → AGP 9 güvenli | Çok aktif |
| `pointycastle` | 4.0.0 | 2025-02-19 | ✅ | Yok | Durgun; düşük seviyeli, doğrudan kullanmayın |
| `@signalapp/libsignal-client` (npm) | 0.99.4 | 2026-08-04 | ❌ (Node) | Prebuilt addon | Çok aktif ama 🔴 **AGPL-3.0** |
| Node yerleşik `crypto` | — | — | — | — | ✅ X25519 + Ed25519 + HKDF **yerelde çalıştırılarak doğrulandı** |

**AGP 9 tuzağı doğrulandı ve açık bir issue'su var:** `dint-dev/cryptography#229`
(27 Tem 2026, **OPEN**) — `cryptography_flutter`'ın `android/build.gradle`'ı Kotlin
Gradle Plugin'i koşulsuz uyguluyor, `android.builtInKotlin=true` ile derleme sert
hata veriyor. Projenizin `app/android/gradle.properties`'inde bugün
`android.builtInKotlin=false` yazıyor (bu yüzden `photo_manager 3.11.0` ve
`file_picker 10.3.10` sabitlenmiş). **Kural: `cryptography_flutter*` paketlerini
projeye SOKMAYIN.** Saf Dart sürüm zaten yeterli ve hiç Android kodu getirmiyor.

**Tarayıcı desteği (MDN browser-compat-data'dan ham JSON ayrıştırılarak):**

| | Chrome | Firefox | Safari |
|---|---|---|---|
| `crypto.subtle` **X25519** | 133 | 130 | 17 |
| `crypto.subtle` **Ed25519** | 137 | 129 | 17 |

Bayrak yok, üç motorda da yaygın. Yani web'de native WebCrypto ile X25519 artık
gerçek bir seçenek.

### 4.2 Seçenek A — Signal tarzı: X3DH + Double Ratchet

**Ne verir:** İleri gizlilik (forward secrecy) + ele geçirme sonrası güvenlik
(post-compromise security). Bir mesajın anahtarı çözüldüğünde önceki ve sonraki
mesajlar korunur; cihaz anahtarı çalınsa bile saldırgan bir süre sonra dışarıda kalır.

**Bu projede maliyeti:**
* Hazır kütüphane **lisans nedeniyle kullanılamaz** (GPL-3.0 / AGPL-3.0).
* Double Ratchet'i elle yazmak **kötü fikir**: sıra dışı mesaj sırası, atlanan mesaj
  anahtarlarının saklanması, oturum durumunun atomik kalıcılığı, çoklu cihazda
  oturum çoğaltma — bunların her biri sessizce "mesaj çözülemedi" üreten sınıf
  hatalarıdır. Bu projede DM ekranı **5 saniyede bir tüm listeyi yeniden çekiyor**
  (`sohbet.dart`, `Timer.periodic(5 sn)`), yani her poll ratchet durumuyla
  etkileşen bir kod yolu demek.
* Ratchet durumu **cihaza bağlıdır**. Uygulama yeniden kurulunca oturum sıfırlanır,
  karşı tarafın "anahtar değişti" görmesi gerekir. Çoklu cihaz, cihaz başına ayrı
  oturum demektir (Signal bunu böyle yapar).

**Tahmini maliyet:** 15-20 adam-gün, sadece protokol katmanı. Tahmindir.

### 4.3 Seçenek B — Mesaj başına tek seferlik sarmalama (HPKE tarzı)

Her mesaj için gönderen bir **efemer X25519** çifti üretir, alıcının uzun ömürlü açık
anahtarıyla ECDH yapar, HKDF ile mesaj anahtarı türetir, AES-GCM ile şifreler.
Efemer açık anahtar mesajla birlikte gider. Aynı gövde **gönderenin kendi açık
anahtarına da** sarmalanır (kendi mesajını kendi başka cihazında okuyabilsin).

```
gövde = { v:1, ct:<AES-GCM>, n:<nonce>,
          k: { "<aliciCihazId>": <efemerPub + sarmalı>,
               "<gonderenCihazId>": <efemerPub + sarmalı> } }
```

**Artı:** ~200-300 satır, durum yok, sıra bağımsız, 5 sn poll ile sorunsuz, çoklu cihaz
doğal olarak destekleniyor (alıcının her cihazı için bir sarmal), tek kütüphane
çağrısıyla web'de de aynı.
**Eksi:** **İleri gizlilik yok.** Alıcının uzun ömürlü özel anahtarı ele geçen bir
saldırgan, elindeki *tüm* eski şifreli mesajları çözer.

**Tahmini maliyet:** 3-5 adam-gün.

### 4.4 Seçenek C — B + döner ön anahtarlar (önerilen)

B'nin üzerine, X3DH'nin ileri gizlilik mekanizmasını **Double Ratchet olmadan** ekler:

* Her cihaz, uzun ömürlü kimlik anahtarına ek olarak **imzalı bir ön anahtar**
  (signed prekey) yayınlar ve bunu **N günde bir** (örn. 7 gün) döndürür.
* Gönderen, mesajı `ECDH(efemer, kimlik) ‖ ECDH(efemer, önAnahtar)` karışımıyla şifreler.
* Alıcı, **süresi geçmiş ön anahtarın özel kısmını cihazdan siler**.

Sonuç: 7 günden eski mesajlar, cihaz bugün ele geçse bile çözülemez — çünkü onları
çözecek özel ön anahtar artık yok. Yani "kayan pencereli ileri gizlilik". Signal'in
mesaj-başına FS'i kadar güçlü değil, ama **maliyetin onda birine** riskin büyük
kısmını kapatır.

**Tahmini maliyet:** B + 2-3 adam-gün.

### 4.5 İleri gizlilik gerçekten gerekli mi? — gerekçeli öneri

**Hayır, tam Double Ratchet bu ürün için gerekli değil. Evet, C'deki kayan pencere
gerekli.** Gerekçe:

* FS'in koruduğu senaryo şudur: saldırgan **hem** eski şifreli mesajları
  (yedek/DB dökümü) **hem de** cihaz anahtarını ele geçirir. Cihaz anahtarını ele
  geçirmişse zaten cihazdadır ve 3. bölümün 10. satırındayız — FS orada da fayda
  vermiyor, çünkü ekran zaten açık.
* FS'in gerçekten fark yarattığı yer, **anahtarın cihazdan değil, yedekten** ele
  geçmesidir: örneğin kullanıcı anahtar yedeğini bir kurtarma koduyla sunucuya
  koyarsa (5. bölüm) ve o yedek sızarsa. **Anahtar yedeği kullanacaksanız FS'in
  değeri ciddi biçimde artar** — çünkü yedek, uzun ömürlü anahtarı yeniden
  canlandırılabilir hâle getirir. Bu ikisi birbirine bağlı karardır.
* C seçeneği, ön anahtar rotasyonunu bir `Timer` ve bir `DELETE`'e indirger; ratchet
  durumu tutmaz, mesaj sırasına duyarsızdır, 5 sn poll'u bozmaz.

**Kütüphane kararı:** `cryptography_plus` 3.0.0 (X25519, Ed25519, AES-GCM, HKDF,
ChaCha20-Poly1305 — hepsi doğrulandı; saf Dart, web dahil, sıfır native kod).
Sunucuda **hiçbir yeni paket yok** — Node'un yerleşik `crypto`'su yeterli
(`generateKeyPairSync('x25519'|'ed25519')`, `diffieHellman`, `hkdfSync`, `sign/verify`
yerelde çalıştırılarak doğrulandı). Sunucunun kriptoya ihtiyacı zaten yalnız
**imza doğrulaması** için olacak; şifre çözme hiç yapmayacak.

---

## 5. Anahtar yönetimi ve kurtarma — en kritik bölüm

### 5.1 Anahtar nerede durur

| Platform | Depo | Doğrulanmış durum |
|---|---|---|
| Android | `flutter_secure_storage` 11.0.0 → Android Keystore (RSA-OAEP sarmalı + AES-GCM), minSdk 23 | ✅ Uygun. `is:built-in-kotlin` etiketi var → **AGP 9 güvenli** |
| iOS | Aynı paket → Keychain | ✅ Uygun ama **canlıda 0 iOS cihazı var** — öncelik değil |
| **Web** | `flutter_secure_storage_web` | 🔴 **UYGUN DEĞİL** (aşağıda) |

**Web'in kaynak kodundan doğrulanan gerçek:** `flutter_secure_storage_web`, veriyi
AES-GCM ile şifreliyor **ama** AES anahtarını `generateKey(..., extractable: true, ...)`
ile üretip `exportKey('raw')` ile dışa aktarıp **aynı `localStorage`'a** yazıyor.
Yani kilit ve anahtar aynı çekmecede. Tek bir XSS her ikisini de okur. `webOptions.wrapKey`
seçeneği bir sarmalama anahtarı ekler ama o da JS paketinizin içinde, yani istemcide
okunabilir — **güvenlik kazancı marjinal**.

**Web'de tek gerçek seçenek:** `extractable: false` ile üretilmiş `CryptoKey`'i
IndexedDB'de saklamak. IndexedDB'nin structured-clone algoritması `CryptoKey`
nesnelerini native olarak saklar; `extractable:false` anahtarın ham baytları JS'e
**hiçbir zaman** çıkmaz. XSS saldırganı anahtarı **çalamaz**, yalnız sayfa açıkken
**kullanabilir** — bu, "kalıcı sızıntı" ile "geçici kötüye kullanım" arasındaki farktır.

🔴 **Ama bu bir mimari çatal:** `extractable:false` anahtar Dart'a bayt olarak
geçemez, dolayısıyla `cryptography_plus` ile kullanılamaz. Yani web'de kriptonun
**tamamı** `dart:js_interop` üzerinden `crypto.subtle`'a taşınmalıdır. Mobil ve web
**iki ayrı kripto uygulaması** demektir — ve iki uygulamanın bayt bayt aynı sonucu
üretmesi test edilmelidir. Bu, 10. bölümdeki "web'de DM E2E olacak mı" sorusunun
asıl maliyetidir.

### 5.2 Yerel mesaj kopyası — bugün YOK, ve bu bir sorun

`sohbet.dart` mesajları **diske hiç yazmıyor**; `SharedPreferences`/Hive/sqflite
kullanmıyor. Uygulama kapanınca liste sıfırlanır, her açılışta sunucudan çekilir.
Diske yazılan tek DM verisi push bildirim geçmişidir (`push.dart`, kişi başına son 10).

E2E'de bu şu anlama gelir: **anahtar giderse mesaj gerçekten gider** — çünkü
okunabilir tek kopya sunucudaki şifreli gövdedir ve onu çözecek anahtar yoktu.
Eğer kullanıcıya "geçmişini kaybedebilirsin" demeyeceksek, **yerel şifreli bir mesaj
deposu şart**: `drift` 2.34.3 + `sqlite3` 3.5.1 (native SQLCipher, web'de
`sqlite3mc.wasm` — sürümler doğrulandı). Bu, planın gizli maliyet kalemidir; kimse
"E2E" derken bunu hesaba katmaz.

> Not: `sqflite` web'i desteklemiyor; `hive` terk edilmiş (son sürüm 2022), yerine
> `hive_ce` aktif. Şifreli SQLite yolu `drift` + `sqlite3` 3.x'tir; eski
> `sqlcipher_flutter_libs` **EOL** ilan edilmiş.

### 5.3 Çoklu cihaz

Bugün her kullanıcının **tam olarak 1 cihaz token'ı var** (30 token / 30 kullanıcı),
yani çoklu cihaz henüz gerçek bir kullanım değil. Yine de tasarım şimdi seçilmeli,
çünkü şema kararı geriye dönük değiştirilemez.

Seçenek B/C zaten cihaz-başına sarmalamayı doğal destekliyor:
`cihazlar(id, kullanici_id, kimlik_pub, imza_pub, on_anahtar_pub, on_anahtar_imza,
olusturma, son_gorulme)`. Gönderen, alıcının **tüm aktif cihazlarına** ayrı sarmal
üretir. Sunucu hiçbir şey çözmez, yalnız açık anahtarları dağıtır.

**Yeni cihaz eski mesajları görebilir mi?** Hayır — ve bu kaçınılmazdır. Yeni cihaz
eklendiğinde eski mesajlar onun anahtarına sarmalanmamıştır. İki seçenek:

* **(a) Görmesin.** "Bu cihazda 12 Ağustos'tan önceki mesajlar yok." Signal'in yaptığı.
  Basit, dürüst, sıfır kripto riski.
* **(b) Eski cihaz yeniden sarmalasın.** Eski cihaz çevrimiçi olduğunda geçmişi
  çözüp yeni cihazın anahtarına yeniden şifreler. Eski cihaz kaybolmuşsa çalışmaz;
  ayrıca 87 mesaj için bile "geçmişi yeniden şifreleme" bir arka plan işi demektir.

**Öneri:** (a). Çoklu cihaz zaten bugün kullanılmıyor.

### 5.4 Şifre unutulunca / hesap kurtarınca ne olur

Bugünkü akış: `POST /auth/sifre-sifirla` → yeni bcrypt hash + **`sifre_surumu++`** →
tüm eski JWT'ler geçersiz olur → yeni token verilir. Kullanıcı yeni cihazda giriş
yapar ve **tüm mesaj geçmişini görür**.

E2E'de bu akış **sessizce anlamını değiştirir**: kullanıcı şifresini sıfırlar, giriş
yapar, sohbeti açar ve **boş bir ekran** ya da "bu mesajlar çözülemiyor" görür.
Kullanıcının beklentisi ile gerçek arasındaki bu uçurum, E2E'nin en büyük destek yükü
kaynağıdır. **Uyarı, şifre sıfırlama ekranında, sıfırlamadan ÖNCE gösterilmelidir.**

### 5.5 Anahtar yedeği seçenekleri ve her birinin E2E'yi ne kadar zayıflattığı

| Seçenek | Nasıl | Kurtarma | E2E garantisine etkisi |
|---|---|---|---|
| **1. Yedek yok** | Anahtar yalnız Keystore/Keychain'de | Yok. Cihaz giderse geçmiş gider | ✅ **Tam E2E.** Sunucu hiçbir koşulda çözemez |
| **2. Kurtarma kodu** | Kayıtta 12 kelime / 32 hane üretilir, kullanıcı **kendisi** saklar. Anahtar bu koddan türetilen bir anahtarla sarmalanıp sunucuda tutulur | Kodu giren geçmişi kurtarır | ⚠️ **Küçük zayıflama.** Sunucu sarmalı görür ama açamaz. Risk: kullanıcı kodu kaybeder (çoğu kaybeder) veya ekran görüntüsü alıp buluta atar |
| **3. Parola türevli yedek** | Anahtar, kullanıcının **giriş parolasından** Argon2id/scrypt ile türetilen anahtarla sarmalanıp sunucuda tutulur | Doğru parolayla giriş yapan otomatik kurtarır — **kullanıcı hiçbir şey öğrenmez** | 🔴 **Ciddi zayıflama.** Sunucu, giriş anında parolayı zaten görüyor (bcrypt'e vermek için). Kötü niyetli sunucu bir kez parolayı yakalarsa yedeği açar. Ayrıca **şifre sıfırlama = geçmiş kaybı** olmaya devam eder (yeni parola eski sarmalı açmaz) |
| **4. Sunucuda düz anahtar** | — | — | ❌ **E2E değildir.** Adı at-rest şifrelemedir |

🔴 **76 misafir hesap için 2 ve 3 uygulanamaz.** Misafirin parolası ve e-postası yok;
kurtarma kodu verilse bile onu koruyacak bir hesap yok. Misafirler için tek gerçek
seçenek 1'dir: "misafir hesapta mesaj geçmişi cihaza bağlıdır." Bu, ürün metninde
açıkça yazılmalı; misafir → e-posta bağlama akışında (`POST /misafir-baglat`) da
anahtarın taşındığından emin olunmalı.

**Önerim:** Seçenek **2 (kurtarma kodu), varsayılan KAPALI**. Kayıtta zorlamayın;
ayarlarda "Mesaj geçmişi yedeği" olarak sunun, açıklamasında "bu kodu kaybedersen
geçmişin kurtarılamaz, bu kodu başkası ele geçirirse geçmişini okuyabilir" desin.
Seçenek 3'ü önermiyorum çünkü sunucunun parolayı giriş anında görmesi, E2E'nin
korumaya çalıştığı 7. tehdit satırını (kötü niyetli operatör) doğrudan geçersiz kılar
ve buna rağmen şifre sıfırlamada geçmişi kurtarmaz — yani en kötü ikisi bir arada.

---

## 6. Kırılacak özelliklerin envanteri

| # | Özellik | Bugünkü mekanizma | E2E'de durumu | Önerilen çözüm |
|---|---|---|---|---|
| 1 | Şikayet / moderasyon | `POST /sikayet` yalnız id+sebep saklar; **DM için istemci akışı yok**, panel metni çözmüyor | Zaten yok | İstemci taraflı kanıt paketi (6.1) |
| 2 | Push içeriği | `pushBildirim` → FCM `data.metin` (500 kr) → `MessagingStyle` + satır içi yanıt | 🔴 Sunucu metni bilmez | Sessiz veri-push + yerel çözme (6.2) |
| 3 | `GET /sohbetler` önizlemesi | SQL `DISTINCT ON` ile son mesajın `metin`'i | 🔴 Çözülemez | Şifreli önizleme + istemci çözme (6.3) |
| 4 | Okunmamış sayacı + istek rozeti | `count(*) WHERE NOT okundu` | ✅ Etkilenmez (üstveri) | — |
| 5 | Mesaj isteği ayrımı | `cevrimici.js` → `sohbetIstekMi()`: takip + `ben_yazdim` | ✅ **Etkilenmez** — içerik okumuyor | — |
| 6 | Alıntı/yanıt önizlemesi | Sunucuda `LEFT JOIN mesajlar y` ile alıntının metni | 🔴 Çözülemez | İstemci zaten alıntılanan mesaja sahip (aynı sohbette) → yerel çöz |
| 7 | İçerik kartı (dizi/film) | `icerik_tur/icerik_id` → sunucu `icerikBilgileri()` ile TMDB'den poster çeker | ⚠️ Şifrelenirse sunucu çözemez | 6.4 |
| 8 | Gönderi kartı (`yorum_id`) | Sunucu yorumdan kapak+metin çekiyor | ⚠️ Aynı | 6.4 |
| 9 | Medya (foto/GIF/video) | Sihirli bayt doğrulaması, ffmpeg kapak karesi, `CachedNetworkImage`, `VideoPlayerController.networkUrl` | 🔴 **Kırılır** — şifreli bayt sihirli bayt geçmez, oynatıcılar URL'den çalışır | 6.5 |
| 10 | Sesli mesaj | `record` → ogg/opus → `POST /medya` → `audioplayers` `UrlSource(url)` | 🔴 **Kırılır** — aynı sebep | 6.5 |
| 11 | `ses_dalga` üstverisi | `"<saniye>:<40 örnek>"` DB'de düz | ⚠️ Sızıntı: süre + genlik profili | Gövdeye taşı (ucuz) |
| 12 | Veri dışa aktarma (GDPR) | `veri_aktar.js` → **DM'ler ZIP'e HİÇ girmiyor** | ✅ Etkilenmez | 6.6 — ama bu bugün bir GDPR eksiği |
| 13 | Hesap silme | `DELETE FROM kullanicilar` → FK CASCADE | ✅ Etkilenmez | Cihaz anahtarlarını da CASCADE'e bağla |
| 14 | Yönetim paneli | Mesaj metnini hiç okumuyor | ✅ Etkilenmez | — |
| 15 | Mesaj düzenleme | `PATCH` yalnız `metin` yazıyor | ⚠️ Yeniden şifreleme gerekir | İstemci yeni gövdeyi üretir |
| 16 | 2000 karakter kısıtı | DB `CHECK` + sunucu doğrulaması | 🔴 Şifreli metin 2000'i aşar | `CHECK` kaldır, uzunluk istemcide + şifreli baytta üst sınır |
| 17 | Web istemcisi | Aynı Flutter kodu, `localStorage`'da token | 🔴 Güvenli anahtar deposu yok | 6.7 |
| 18 | Sayfalama | Sunucu `?once=` destekliyor, **istemci kullanmıyor** → 50'den eskisi görünmüyor | ✅ Etkilenmez | — |

### 6.1 Şikayet / moderasyon (Play Store UGC)

Play'in UGC politikası, kullanıcının içeriği şikayet edebilmesini ve şikayetin
incelenebilmesini bekler. **Bugün DM için ikisi de yok** (2.6). Yani E2E bir yeteneği
yok etmiyor; eksik yeteneği inşa etme fırsatı yaratıyor.

**Standart çözüm (WhatsApp/Signal'in yaptığı):** şikayet eden kişinin **istemcisi**,
şifresi çözülmüş mesajı + bağlamı (önceki/sonraki birkaç mesaj) şikayetle birlikte
gönderir. Sunucu bu paketi `sikayet_kanit` alanında saklar; panel görüntüler.

**Kanıt değeri — dürüst değerlendirme:**
* Bu paket **kriptografik kanıt değildir.** Şikayet eden istemci metni istediği gibi
  yazabilir; "X bana şunu yazdı" iddiası doğrulanamaz. Sahte şikayet mümkündür.
* Kanıtı gerçek yapmanın yolu **gönderenin imzasıdır**: her mesaj gönderenin
  Ed25519 kimlik anahtarıyla imzalanırsa, şikayet paketindeki `(düz metin, imza)`
  ikilisi sunucuda **doğrulanabilir**. İmza tutuyorsa mesaj gerçekten o kişiden
  gelmiştir. Bu, WhatsApp'ın yapmadığı ama yapılabilir bir şeydir ve maliyeti
  düşüktür (imza zaten kimlik anahtarını doğrulamak için gerekiyor).
  🔴 **Yan etkisi var ve yazılmalı:** imza, mesajın inkâr edilemez (non-repudiable)
  olmasını sağlar. Signal bunu **bilerek istemez** ("deniable authentication").
  Sizin ürününüz için moderasyon > inkâr edilebilirlik ise imza doğru tercihtir.
* Kötüye kullanım: şikayet eden, karşı tarafın **kendisine gönderdiği** mesajları
  ifşa edebilir. Bu kaçınılmazdır (alıcı zaten okuyabiliyor) ve E2E'ye özgü değildir.
  Hız limiti (`sikayetLimiti` bugün 20/pencere) ve şikayet edenin geçmişi tutulmalı.

**Öneri:** `sikayetler` tablosuna `kanit JSONB` ekleyin; DM şikayetinde istemci
`{mesajlar:[{id, gonderen, tarih, metin, imza}], baglam_sayisi:N}` göndersin; sunucu
imzaları **doğrulayıp** `imza_gecerli` bayrağını yazsın; panel `satirSik()`'te
`tur==='mesaj'` dalını doldurun ve "Kullanıcıyı banla" butonunu ekleyin.
**Bunu Faz 0'da, E2E'den önce yapın** — imza kısmı olmadan, düz metin kopyayla.

### 6.2 Push bildirimi içeriği

Bugün: `pushBildirim(aliciId,'mesaj',...)` → FCM `data.metin` (mesajın kendisi,
500 karaktere kırpılmış) → `pushArkaplan` izolatı → `mesajBildirimiGoster` →
`SharedPreferences`'a düz metin geçmiş → `MessagingStyle` bildirim + satır içi
"Yanıtla" + `POST /mesajlar/iletildi` (çift tik).

E2E'de sunucu `metin`'i bilmez. Üç seçenek:

| Seçenek | Kullanıcı deneyimi | Maliyet | Risk |
|---|---|---|---|
| **(a) Önizlemesiz** — push gövdesi sabit: "@ad sana mesaj gönderdi" | 🔴 Ciddi gerileme. `MessagingStyle` demeti, satır içi yanıt ve konuşma birikimi anlamsızlaşır | En düşük (~0,5 gün) | Yok |
| **(b) Sessiz veri-push + istemci çeker ve yerelde çözer** | Bugünküyle **aynı** | Orta (2-3 gün) | Android'de yüksek öncelikli data mesajı Doze'da bile teslim edilir; ama uygulama "durdurulmuş" durumdaysa hiç gelmez |
| **(c) Şifreli önizleme push içinde** — sunucu şifreli önizleme baytını `data`'da taşır, istemci çözer | (b) ile aynı, ağ turu yok | Orta | FCM `data` boyut sınırı 4 KB — kısa önizleme sığar |

**Öneri: (c), (b)'ye geri düşerek.** Sunucu zaten şifreli gövdeyi elinde tutuyor;
kısa bir "önizleme gövdesi"ni (ilk ~120 karakterin ayrı şifrelenmiş hâli) `data`
alanında taşımak ek ağ turu gerektirmez ve arka plan izolatı onu Keystore'daki
anahtarla çözebilir. Çözemezse (anahtar yok, cihaz yeni) **(a)'ya düşer** — yani
"Yeni mesaj" gösterir. Bu geri düşüş şart, çünkü sessiz başarısızlık yasaktır.

🔴 **İki tuzak:**
1. **Arka plan izolatı Keystore'a erişebilmeli.** `flutter_secure_storage`
   `@pragma('vm:entry-point')` izolatından çalışır mı, **canlı cihazda kanıtlanmalı**.
   `push.dart` zaten `DartPluginRegistrant.ensureInitialized()` çağırıyor, umut verici.
   **[DOĞRULANMALI: gerçek cihazda, uygulama kapalıyken arka plan izolatından
   `flutter_secure_storage` okuması.]**
2. **`SharedPreferences`'taki bildirim geçmişi düz metin.** `bildirim_mesajlari_<ad>`
   kişi başına son 10 mesajı **düz** tutuyor. E2E'de bunun da şifreli tutulması ya da
   hiç tutulmaması gerekir; yoksa "E2E" etiketli uygulama, mesajları telefonda düz
   metin bırakır.
3. **iOS'ta (b)/(c) kısıtlıdır.** `content-available` sessiz push'ları iOS
   kısıtlar/geciktirir; `mutable-content` + Notification Service Extension gerekir ve
   o extension'ın Keychain'e erişimi için App Group paylaşımı şart. **Bugün 0 iOS
   cihazı var** — bu işi iOS yayınına kadar erteleyin.

### 6.3 `GET /sohbetler` önizlemesi ve `mesajOzeti()`

`mesajOzeti()` (`sohbet.dart`) zaten akıllı: metin yoksa medyanın uzantısına bakıp
"Sesli mesaj" / "Video" / "Fotoğraf" / "İçerik" diyor. **Yani metinsiz mesajlar için
E2E hiçbir şeyi bozmuyor** — yeter ki mesajın *türü* düz kalsın.

Metinli mesajlar için önerilen: `mesajlar` tablosuna `onizleme_gövde` (şifreli, ~120
karakter) ekleyin ve `GET /sohbetler` onu döndürsün; istemci listeyi çizerken çözer.
Çözemezse `mesajOzeti()` "Mesaj" der. Liste ekranı zaten `RefreshIndicator` ile
yenileniyor, ekstra ağ turu yok.

Alternatif (daha ucuz): önizlemeyi hiç göstermeyin, listede yalnız "Fotoğraf",
"Sesli mesaj", "Mesaj" yazsın. 45 dile 1 anahtar eklemekle biter. Kullanıcı deneyimi
gerilemesi gerçek ama küçüktür — ve bu, **10. bölümde sorulacak bir karardır**.

### 6.4 İçerik ve gönderi kartları

`icerik_tur/icerik_id` düz kalırsa sunucu poster/ad çözmeye devam eder ve kart
bugünkü gibi çalışır. **Ama bu, "hangi diziyi/filmi paylaştım" bilgisinin sunucuda
düz kalması demektir** — DM içeriğinin anlamlı bir parçası.

Öneri: `icerik_tur/icerik_id`'yi **gövdeye taşıyın**, kolonları NULL bırakın. İstemci
kartı çizerken TMDB bilgisini `icerikBilgileri`'nin istemci karşılığıyla (mevcut
`Onbellek` SWR yardımcısı) çeker. Aynı şey `yorum_id` için de geçerli, fakat orada
FK var; FK'yı düşürmek "paylaşılan gönderi silinince kart bozulur" davranışını
değiştirir — bilinçli kabul edilmeli.

### 6.5 Medya ve sesli mesaj

Bugünkü boru hattı **tamamen URL tabanlıdır** ve E2E ile bağdaşmaz:
`CachedNetworkImage(url)`, `VideoPlayerController.networkUrl(url)`,
`audioplayers` `UrlSource(url)`. Hiçbiri "önce indir, çöz, sonra oynat" yapmıyor.

Önerilen tasarım:
* İstemci dosyayı **yüklemeden önce** rastgele bir dosya anahtarıyla (AES-GCM)
  şifreler; şifreli baytı `POST /medya`'ya gönderir; **dosya anahtarı mesaj
  gövdesinin içinde** taşınır (yani alıcının anahtarına sarmalanır).
* `POST /medya`'daki **sihirli bayt doğrulaması şifreli bayt için çalışmaz.**
  Bunun yerine istemci `içerik_türü` bilgisini gövdeye koyar; sunucu yalnız boyut
  sınırı ve sahiplik uygular. 🔴 **Güvenlik kaybı gerçek:** bugün sunucu "yüklenen
  şey gerçekten resim mi" diye bakıyor ve `GUVENLIK-DENETIMI.md` §4.9'a göre 30.958
  dosyanın tamamının zararsız olmasının sebebi bu. Şifreli yüklemede bu kontrol
  imkânsızdır. Telafi: uzantıyı `.bin` yapın, `Content-Type: application/octet-stream`
  ile servis edin, `Content-Disposition: attachment` ekleyin — tarayıcı hiçbir
  koşulda çalıştırmasın.
* **ffmpeg kapak karesi çıkarma çalışmaz** (`videoKaresiCikar`). Kapak karesini
  istemci üretip ayrı şifreli bir dosya olarak yüklemeli. Video altyazı kuyruğu
  (`video_altyazi_durum`) DM videoları için tamamen devre dışı kalır — bugün DM'de
  video altyazısı kullanılıyorsa bu bir gerileme. **[DOĞRULANMALI: altyazı kuyruğu
  DM videolarını da işliyor mu, yoksa yalnız gönderi videolarını mı.]**
* **Oynatıcı katmanı yeniden yazılır:** şifreli baytı indir → geçici dosyaya çöz →
  `DeviceFileSource`/`VideoPlayerController.file` ile oynat → çıkışta sil. Bu, 4-5
  günün büyük kısmıdır ve `medya_goster.dart` ile `ses.dart`'ın oynatma yollarını
  etkiler.
* `ses_dalga` gövdeye taşınır (kolon NULL kalır). Dalga formu bugün zaten istemcide
  üretiliyor (`dalgaKodla`), sunucu yalnız biçim doğruluyor.

### 6.6 Veri dışa aktarma, hesap silme, admin paneli

* **Dışa aktarma:** `veri_aktar.js` → `disaAktar()` bugün `user.csv`,
  `followed_tv_show.csv`, `seen_episode_latest.csv`, `seen_movie.csv`, `ratings.csv`,
  `comments.csv`, `lists.csv`, `dizijpg.json` üretiyor. **DM'ler hiç yok.**
  Bu, E2E'den bağımsız olarak bir GDPR/Play "veri taşınabilirliği" eksiğidir.
  E2E'den sonra doğru çözüm: ZIP'i **istemci** tamamlar — sunucu şifreli gövdeleri
  verir, istemci çözüp `messages.csv` ekler. Ya da daha basiti: "Sohbeti dışa aktar"
  düğmesini sohbet ekranına koyun.
* **Hesap silme:** `DELETE FROM kullanicilar` → FK CASCADE. Yeni `cihazlar` ve
  `on_anahtarlar` tabloları da `ON DELETE CASCADE` olmalı. Ayrıca **cihazdaki
  anahtar da silinmeli** (bugün `Onbellek.temizle()` çağrılıyor, oraya eklenir).
* **Admin paneli:** DM metnini zaten okumuyor; değişiklik yalnız 6.1'deki şikayet
  kanıtı görüntüleme. Yeni bir sızıntı yüzeyi yaratmamak için kanıt paketi
  `esc()`/`escJs()` ile kaçırılmalı (`GUVENLIK-DENETIMI.md` §2.1 dersi).

### 6.7 Web istemcisi

* **Anahtar nerede durur:** 5.1'e göre tek kabul edilebilir cevap
  `extractable:false` CryptoKey + IndexedDB. Bu, web'de kriptoyu Dart'tan
  `crypto.subtle`'a taşır → **iki ayrı uygulama**.
* **XSS riski:** projede bugün **CSP başlığı yok** (`GUVENLIK-DENETIMI.md` §2.8,
  madde 6 hâlâ açık). E2E anahtarını tarayıcıya koymadan önce CSP eklenmelidir;
  aksi halde "web'de E2E" iddiası XSS ile çürür. Non-extractable anahtar bu riski
  azaltır ama sıfırlamaz (saldırgan sayfa açıkken mesaj çözdürebilir).
* **Uygulama güncellemesinde anahtar kaybı:** IndexedDB, `localStorage`'ın aksine
  origin bazlıdır ve dağıtımdan etkilenmez. **Ama** tarayıcı depolamayı kendiliğinden
  temizleyebilir (Safari ITP: 7 gün kullanılmayan site verisini siler; "Site
  verilerini temizle" tek tıktır). Yani **web'de anahtar kaybı normal bir olaydır,
  istisna değil.** Kurtarma kodu olmadan web'de E2E, "tarayıcı önbelleğini temizleyince
  tüm mesaj geçmişin gitti" demektir.
* Bugün web'de push zaten yok, `record` paketi web'de kurulmuyor (mikrofon ikonu
  gizli), `photo_manager` web'i desteklemiyor. Yani web DM'i bugün de kısıtlı bir
  deneyim.

**Bu yüzden 10. bölümdeki soru gerçektir:** web'de DM E2E mi, yoksa web'de DM'i
kapatmak mı? Üçüncü bir seçenek daha var: **web'de DM'i salt-okunur bırakmamak,
ama "bu tarayıcıda mesajlaşma kapalı, uygulamayı kullan" demek.** 30 cihazın 30'u
Android olduğuna göre, web DM'inin bugünkü gerçek kullanımı muhtemelen sıfıra yakın.
**[DOĞRULANMALI: web'den gelen `POST /mesajlar` isteklerinin oranı — nginx erişim
günlüğünden User-Agent'a bakılarak ölçülebilir.]**

---

## 7. Mevcut düz metin mesajlar (87 adet)

**Retro-şifreleme gerçek bir güvenlik kazancı sağlar mı?** Kısmen — ve soruyu iki
ayrı soruya bölmek gerekiyor:

* **"Sunucu zaten okudu" argümanı doğru mu?** Evet, ama eksik. Sunucunun *geçmişte*
  okumuş olması, o mesajların *gelecekte* çalınmasını engellemiyor. Bugünkü gece
  yedeği (35 MB, 644, şifresiz) yarın sızarsa 87 mesajın 68'i düz metin olarak
  çıkar. Yani retro-koruma **gelecekteki sızıntıya karşı** gerçek bir kazançtır.
* **"E2E ile retro-şifrele" mümkün mü?** Hayır. Sunucu, geçmiş mesajları kullanıcının
  cihaz anahtarına sarmalayamaz — sarmalayabilseydi zaten E2E olmazdı. Retro-E2E
  ancak **istemci** tarafından yapılabilir: kullanıcının cihazı geçmişi çeker, kendi
  anahtarına şifreler, geri yazar. Ama karşı tarafın cihazı da aynısını yapmalı ve
  ikisi aynı şifreli gövdede uzlaşmalı — bu, 87 mesaj için absürt bir mühendisliktir.

**Üç gerçekçi seçenek:**

| Seçenek | Ne olur | Maliyet | Değerlendirme |
|---|---|---|---|
| **(a) Eski mesajları at-rest şifrele** | Sunucu anahtarıyla `metin` şifrelenir; sunucu okuyabilir ama yedek/DB dökümü koruma altına girer | ~1 gün | ✅ **Önerilen.** Kazanç gerçek, risk düşük, geri alınabilir |
| **(b) Olduğu gibi bırak, "12 Ağustos'tan sonrası E2E" de** | Karma sohbet | 0 | ⚠️ Yedek sızıntısına açık kalır |
| **(c) Eski geçmişi sil** | 87 mesaj gider | ~0 | 🔴 5 gerçek kullanıcının verisi. `alcelik` (id=3) gerçek kullanıcıdır — CLAUDE.md kural 6 |

**Öneri: (a) + (b).** Eskiyi at-rest şifreleyin (sunucu okumaya devam eder, listede
önizleme çalışır), yeniyi E2E yapın. Böylece **hiç veri kaybı olmaz**.

**Karma sohbetin arayüzde görünümü:** Sohbette, E2E'ye geçiş anında tek satırlık,
ortalanmış, gri bir sistem şeridi çizin — tıpkı bugün `oncekiGun` tarih ayracının
çizildiği gibi (`sohbet.dart` zaten böyle bir ayraç çiziyor, kalıp hazır):

> 🔒 *Bu noktadan sonraki mesajlar uçtan uca şifreli.*

Eski mesajlar normal görünür (istemci onları düz alır). Yeni mesajlarda baloncuğun
yanında ayrı bir kilit ikonu **koymayın** — WhatsApp da koymaz; ikon gürültüsü
kullanıcıya "bazıları güvenli değil" hissi verir. Tek ayraç yeter. 45 dile
1 yeni anahtar.

---

## 8. Geçiş planı (fazlar)

Her faz **tek başına dağıtılabilir**, **tek başına geri alınabilir** ve kendinden
sonrakini beklemez.

### Faz 0 — E2E'den bağımsız, bugün kapatılabilir üç açık (tahmin: 1-2 gün)

1. Gece yedeklerini şifreleyin (`gpg --symmetric` veya `age`) ve
   `/opt/dizijpg/yedekler` iznini `700`, dosyaları `600` yapın.
2. **DM medyasını erişim kontrolüne alın.** İki yol: (i) DM medyasını ayrı bir dizine
   yazıp `/medya-dm/*` için JWT + taraf kontrolü yapan bir Express rotası koymak,
   (ii) imzalı süreli URL. (i) daha basit; `yalnizGet` kalıbı bozulmaz.
3. **DM şikayeti akışını ekleyin** (istemcide baloncuk menüsüne "Şikayet et",
   sunucuda `sikayetler.kanit`, panelde `satirSik()`'in `'mesaj'` dalı).
   Bu, Play UGC uyumu için E2E'den bağımsız olarak gereklidir.

Bu faz E2E kararı ne olursa olsun yapılmalı ve tehdit tablosunun 1, 2, 3, 4
satırlarını kapatır.

### Faz 1 — Anahtar altyapısı, davranış değişmez (tahmin: 3-4 gün)

Yeni tablolar (`migrasyon-2026-08-XX.sql` + `sema.sql`, CLAUDE.md/skill kural 6):
```
cihazlar(id, kullanici_id FK CASCADE, kimlik_pub, imza_pub, etiket, olusturma, son_gorulme)
on_anahtarlar(id, cihaz_id FK CASCADE, pub, imza, bitis)
```
Yeni uçlar: `POST /cihaz-anahtar` (kayıt), `GET /anahtarlar/:kullaniciAdi` (dağıtım).
Sunucu imzayı **doğrular** (Node yerleşik `crypto.verify`), hiçbir şeyi çözmez.
İstemci anahtarı üretip Keystore'a yazar. **Hiçbir mesaj şifrelenmez.** Geri alma:
uçları kaldır, tablolar boş kalır.

### Faz 2 — E2E gönderim, bayrak arkasında (tahmin: 5-7 gün)

`mesajlar`'a `sifreli JSONB` + `sema INT` kolonları. `POST /mesajlar` `sifreli`
geldiyse `metin`'i NULL bırakır. `metin` üzerindeki `CHECK` kısıtı kaldırılır.
İstemci, **karşı tarafın anahtarı varsa** şifreli gönderir, yoksa düz gönderir.

🔴 **Düşürme (downgrade) saldırısı riski:** "anahtarı yoksa düz gönder" kuralı,
sunucunun anahtar listesini boş döndürerek şifrelemeyi kapatmasına izin verir.
Telafi: istemci bir partnerle **bir kez** şifreli konuştuysa, o partner için düz
metne dönmeyi **reddeder** ve "bu kişinin cihaz anahtarı kayboldu, mesaj
gönderilemiyor" der. Bu TOFU kuralı ucuzdur ve düşürmeyi gürültülü yapar.

### Faz 3 — Push ve liste önizlemesi (tahmin: 3-4 gün)

6.2 (c) + geri düşüş, 6.3 şifreli önizleme, `SharedPreferences` bildirim geçmişinin
şifrelenmesi/kaldırılması, arka plan izolatı Keystore testi.

### Faz 4 — Medya ve sesli mesaj (tahmin: 4-5 gün)

6.5'in tamamı. En riskli faz; oynatıcı yolları yeniden yazılıyor. Kanıt zorunlu
(CLAUDE.md kural 7): widget testi + gerçek cihazda foto/video/ses gönder-al turu.

### Faz 5 — Kurtarma kodu + çoklu cihaz + parmak izi ekranı (tahmin: 6-8 gün)

5.5 seçenek 2, 5.3 (a), 3.1 parmak izi doğrulama.

### Faz 6 — Web kararı (tahmin: 5-8 gün, ya da 0,5 gün)

10. bölümdeki cevaba göre: ya `crypto.subtle` + IndexedDB yolu (5-8 gün), ya da
"web'de DM kapalı" mesajı (0,5 gün + 45 dil).

### 8.1 Eski istemcilerle uyumluluk — sürüm kapısı değerlendirmesi

**Kapı var:** `app/lib/surum_kapisi.dart`. `MaterialApp.builder` içinde `Stack`
katmanı olarak çiziliyor (dialog değil — geri tuşuyla kapatılamıyor),
`GET /surum-kontrol?derleme=<pubspec build>` ile besleniyor, `zorunlu:true` ise
"Daha sonra" düğmesi hiç çizilmiyor. Testi de var (`app/test/surum_kapisi_test.dart`).

**Ama üç sorun var:**

1. 🔴 **Canlıda hiç kurulmamış.** `ayarlar` tablosunda `min_derleme` ve
   `onerilen_derleme` **boş** — yani kapı bugüne kadar bir kez bile ateşlenmedi.
   E2E geçişinde ona bel bağlamadan önce **düşük bir `onerilen_derleme` ile prova
   edilmeli** (öneri modu ertelenebilir olduğu için zararsızdır).
2. 🔴 **Web'de de çalışıyor ve `kIsWeb` muafiyeti yok.** `zorunlu` moda geçtiğinizde
   web derlemesi de aynı `+67` derleme numarasını gönderdiği için **tarayıcı
   kullanıcıları da kilitlenir** ve "Güncelle" düğmesi onları mağazaya götürür — web
   için anlamsız bir çıkış. Zorunlu moda geçmeden önce ya web muafiyeti eklenmeli ya
   da web derlemesi aynı anda dağıtılmalı.
3. **Yayında APK'lar var.** Zorunlu güncelleme, kullanıcıyı Play'den indirmeye
   zorlar; Play incelemesi 1-3 gün sürebilir, bu sürede eski sürüm kullanıcıları
   kilitli kalır. Bu yüzden **Faz 2 zorunlu kapı gerektirmemeli**: eski istemci
   `sifreli` kolonunu bilmez, `metin` NULL gelir ve **boş baloncuk** görür — kabul
   edilemez. Çözüm: sunucu, istemci sürümünü (`X-Surum` başlığı veya `?derleme=`)
   bilmiyorsa/eskiyse `metin` alanına **çevrilmiş bir yer tutucu** koysun:
   *"Bu mesaj şifreli. Görmek için uygulamayı güncelle."* Böylece zorunlu kapı
   gerekmeden eski istemci anlamlı bir şey gösterir; kapıyı yalnız Faz 4'ten sonra,
   isteğe bağlı olarak çekersiniz.

---

## 9. Gizlilik politikası ve mağaza etkisi

### 9.1 Değişecek cümle — bugün tam tersini söylüyor

Metin **üç ayrı yerde** duruyor ve üçü de elle senkronlanıyor:

1. `app/lib/ekranlar/gizlilik.dart` — Türkçe kaynak (aynı zamanda çeviri anahtarı):
   > "Mesajlar: yazılı, görselli ve sesli mesajların sunucularımızda saklanır.
   > **Mesajlar uçtan uca şifreli değildir**; yalnızca şikayet edilirse moderasyon
   > amacıyla incelenir."
2. `app/lib/diller/dil_*.dart` — **45 dosyanın 45'inde** bu cümle anahtar olarak var
   (`grep -c` ile doğrulandı).
3. `app/web/gizlilik.html` — `var VERI={...}` içinde **46 dil için** önceden
   çevrilmiş ikinci kopya (29 maddelik dizinin 7. elemanı).

**Çeviri yükü (ölçüldü):** 1 anahtar değişikliği = 45 Dart dosyasında satır + 46
dilde HTML dizisi girdisi. Ayrıca dil dosyalarında anahtar **Türkçe cümlenin
kendisi** olduğu için cümleyi değiştirmek eski anahtarı geçersiz kılar — eski satır
silinmezse ölü kalır. `araclar/` altında bunu yapan bir betik **yok**;
skill'in dediği gibi Python betiği Write ile dosyaya yazılıp çalıştırılmalı.

**Yeni metin önerisi (Faz 2 sonrası):**
> "Mesajlar: yazılı, görselli ve sesli mesajların uçtan uca şifrelenir; şifre çözme
> anahtarı yalnız senin cihazındadır, biz içeriği okuyamayız. Kimin kiminle ve ne
> zaman yazıştığı bilgisi sunucularımızda tutulur. Bir mesajı şikayet edersen, o
> mesajın bir kopyası inceleme için tarafımıza iletilir."

🔴 **Bu cümle, Faz 2 canlıya çıkmadan ÖNCE yazılmamalı.** Politika, gerçekte
olandan ileride olursa yanıltıcı beyan olur — ve bu, mağaza politikası açısından
şifrelemenin olmamasından daha risklidir.

### 9.2 Play Data Safety formu

| Alan | Bugün | E2E sonrası |
|---|---|---|
| "Messages → Other in-app messages" toplanıyor mu | Evet | **Evet, değişmez** — şifreli de olsa mesaj sunucuda saklanıyor |
| "Data is encrypted in transit" | Evet (TLS) | Evet |
| "Data can't be deleted" / silme talebi | Silinebilir | Silinebilir |
| **"Is all of the user data collected by your app encrypted in transit?"** | Evet | Evet |
| Ek açıklama alanı | — | E2E burada beyan edilir |

**[DOĞRULANMALI:** Play Data Safety formunda "end-to-end encrypted" için bugün ayrı
bir kutucuk var mı, yoksa yalnız açıklama metniyle mi belirtiliyor. Play Console
formunun güncel hâli konsoldan kontrol edilmeli.**]**

**[DOĞRULANMALI:** Play'in **Child Safety Standards** politikası (CSAE) kapsamında,
E2E mesajlaşan uygulamalardan ne bekleniyor. `app/web/cocuk-guvenligi.html` mevcut;
E2E ile sunucu tarafı içerik taraması imkânsız hâle geldiği için beyan güncellenmeli.
Bu, uygulamanın kaldırılmasına yol açabilecek tek politika kalemidir ve **karar
vermeden önce netleştirilmelidir.**]

**[DOĞRULANMALI:** Türkiye'de 5651 sayılı kanun ve KVKK açısından, mesaj içeriğine
erişememenin bir yükümlülük ihlali oluşturup oluşturmadığı. Bu hukuki bir sorudur,
kod okumasıyla cevaplanamaz.]

---

## 10. Kararsız bırakılamayacak sorular

Bunlar teknik değil ürün kararlarıdır; cevapları olmadan Faz 2'ye başlanamaz.

1. **Mesaj geçmişinin kaybı kabul mü?**
   Kullanıcı telefonunu değiştirir / uygulamayı siler / şifresini sıfırlarsa
   **tüm DM geçmişi kalıcı olarak gider**. Kabul mü, yoksa kurtarma kodu (5.5 §2)
   şart mı? *(76 misafir hesap için kurtarma zaten imkânsız — bu grup için cevap
   kaçınılmaz olarak "kabul".)*

2. **Çoklu cihaz şart mı?**
   Bugün 30 cihaz / 30 kullanıcı, yani kimse iki cihaz kullanmıyor. Faz 5'i erteleyip
   "bir hesap, bir cihaz" ile başlayalım mı?

3. **Web'de DM E2E olacak mı, yoksa web'de DM kapansın mı?**
   Web'de güvenli anahtar deposu için `crypto.subtle` + IndexedDB yolu gerekiyor
   (mobil ile ayrı kripto uygulaması, +5-8 gün) ve tarayıcı depolamayı silince
   geçmiş gidiyor. Alternatif: web'de DM'i kapatıp "mesajlaşma için uygulamayı
   kullan" demek (0,5 gün).

4. **Push önizlemesi feda edilir mi?**
   6.2'de (c) seçeneği bugünkü deneyimi korur ama 3 gün ve arka plan izolatı riski
   taşır. (a) seçeneği yarım gün sürer ama bildirim "Yeni mesaj" der ve WhatsApp
   tarzı konuşma birikimi ile satır içi yanıt anlamsızlaşır.

5. **Sohbet listesindeki önizleme feda edilir mi?**
   Şifreli önizleme (+istemci çözme) mi, yoksa listede sadece "Mesaj / Fotoğraf /
   Sesli mesaj" mı?

6. **Mesajlar imzalansın mı?**
   İmza, şikayet kanıtını doğrulanabilir yapar (moderasyon için değerli) ama
   mesajı **inkâr edilemez** hâle getirir (Signal bunu bilerek istemez). Hangisi
   sizin için daha önemli?

7. **Faz 0 hemen yapılsın mı?**
   Yedek şifreleme + DM medyasına erişim kontrolü + DM şikayeti akışı; E2E kararından
   bağımsız, 1-2 gün, geri alınabilir. Bunu E2E'yi beklemeden yapmak istiyor musunuz?

---

## 11. Maliyet ve tavsiye

### 11.1 Tahmini iş yükü (ölçüm değil, tahmin)

| Faz | İş | Adam-gün |
|---|---|---|
| 0 | Yedek şifreleme + medya erişim kontrolü + DM şikayeti | 1-2 |
| 1 | Anahtar altyapısı (tablolar, uçlar, istemci üretimi) | 3-4 |
| 2 | E2E metin gönderimi + TOFU + eski istemci yer tutucusu | 5-7 |
| 3 | Push + liste önizlemesi + yerel bildirim geçmişi | 3-4 |
| 4 | Medya + sesli mesaj (oynatıcı yolları yeniden) | 4-5 |
| 5 | Kurtarma kodu + çoklu cihaz + parmak izi | 6-8 |
| 6 | Web (crypto.subtle + IndexedDB) | 5-8 |
| — | Gizlilik politikası + 45 dil + Data Safety | 1-2 |
| — | Test, uçtan uca curl, dağıtım ritüeli, geri alma provaları | 3-4 |
| **Toplam (tam)** | | **31-44** |
| **Asgari (Faz 0-3 + politika)** | | **13-19** |
| **Karşılaştırma: at-rest şifreleme + erişim sıkılaştırma** | | **2-3** |

### 11.2 Tavsiye

**Kullanıcı E2E'yi seçti; bu belge onu değiştirmeye çalışmıyor, kararı bilgilendirmeye
çalışıyor. Söylemem gerekenler:**

**Önerdiklerim:**

* **Faz 0'ı bu hafta yapın, E2E kararından bağımsız olarak.** Ölçülen üç somut açık
  (şifresiz 644 yedek, kimliksiz DM medyası, olmayan DM moderasyonu) 1-2 günde
  kapanıyor ve tehdit tablosunun en olası satırlarını kapatıyor. E2E bunlardan
  hiçbirini "daha hızlı" kapatmıyor — sadece daha geç.
* **Eski 87 mesajı at-rest şifreleyin** (7. bölüm seçenek a). Veri kaybı yok, kazanç
  gerçek, 1 gün.
* **E2E'yi Faz 1-3 ile, tek cihaz, mobil-öncelikli yapın.** Bu, "sunucu ve operatör
  mesajları okuyamaz" iddiasını gerçekten karşılar ve 13-19 günde biter.
* **Protokol: seçenek C** (efemer X25519 + döner ön anahtar), **kütüphane:
  `cryptography_plus` 3.0.0**, sunucuda **hiç yeni npm paketi yok**.
  `cryptography_flutter*` paketlerini **projeye sokmayın** (AGP 9 ile kırılıyor,
  açık issue #229).
* **TOFU + "anahtar değişti" uyarısını Faz 2'ye koyun.** Onsuz E2E, aktif kötü
  niyetli sunucuya karşı iddia edildiği kadar güçlü değildir ve maliyeti düşüktür.

**Önermediklerim ve nedenleri:**

* **Tam Signal paritesi (X3DH + Double Ratchet) önermiyorum.** Hazır kütüphaneler
  lisans nedeniyle kullanılamıyor (GPL/AGPL), elle yazmak sessiz "çözülemedi"
  hataları üretme riski taşıyor ve 5 saniyelik poll mimarisiyle etkileşimi
  karmaşık. Seçenek C, maliyetin ~%20'siyle riskin büyük kısmını kapatıyor.
* **Parola türevli anahtar yedeğini (5.5 §3) önermiyorum.** Sunucu giriş anında
  parolayı zaten görüyor; bu yedek, E2E'nin var oluş sebebi olan "kötü niyetli
  operatör" korumasını geçersiz kılar ve buna karşılık şifre sıfırlamada geçmişi
  yine kurtarmaz.
* **Web'de E2E'yi ilk turda önermiyorum.** Ayrı kripto uygulaması + CSP'nin
  bugün olmaması + tarayıcının depolamayı kendiliğinden silmesi üçlüsü, kazançtan
  büyük bir bakım yükü demek. 30 aktif cihazın 30'u Android.
* **Zorunlu sürüm kapısını Faz 2'de kullanmayı önermiyorum.** Kapı canlıda hiç
  ateşlenmemiş, web'de muafiyeti yok ve Play inceleme süresi boyunca kullanıcıları
  kilitler. Bunun yerine sunucu tarafı yer tutucu metni (8.1 madde 3) kullanın.

**Dürüst özet:** E2E, bu ürünün bugünkü ölçeğinde (87 mesaj, 9 gönderen, 18 gerçek
kullanıcı) **teknik olarak yapılabilir ama ekonomik olarak erken** bir yatırımdır.
Değeri, kullanıcı sayısı büyüdükçe ve ekibe ikinci bir kişi katıldıkça artar.
Buna karşılık **"kullanıcı verileri bizim için en önemlisi" ilkesinin bugünkü
karşılığı Faz 0'dır** — ve o, E2E'nin yanında ölçülemeyecek kadar ucuzdur.
İkisini birbirinin alternatifi değil, sırası olarak görün.

---

## 12. Emin olamadıklarım

* **[DOĞRULANMALI: arka plan izolatı + Keystore.]** `flutter_secure_storage`'ın
  `@pragma('vm:entry-point')` arka plan izolatından (uygulama tamamen kapalıyken)
  okuma yapabildiği **gerçek cihazda** kanıtlanmalı. 6.2 (c) seçeneğinin tamamı buna
  bağlı. Çalışmıyorsa push önizlemesi kaçınılmaz olarak (a)'ya düşer.
* **[DOĞRULANMALI: Play Child Safety Standards + E2E.]** E2E mesajlaşmanın CSAE
  beyanını nasıl etkilediği. Bu, uygulamanın mağazadan kaldırılmasına yol
  açabilecek tek kalem; **Faz 2'ye başlamadan önce** Play Console'dan ve politika
  metninden netleştirilmeli.
* **[DOĞRULANMALI: Play Data Safety formunun güncel alanları.]** "End-to-end
  encrypted" için ayrı kutucuk var mı.
* **[DOĞRULANMALI: web'den DM kullanımı.]** `POST /api/mesajlar` isteklerinin kaçı
  tarayıcıdan geliyor? nginx erişim günlüğünde User-Agent'a bakılarak ölçülebilir;
  bu ölçüm 10. sorunun (web'de DM) cevabını büyük ölçüde verir.
* **[DOĞRULANMALI: video altyazı kuyruğu DM'i kapsıyor mu.]** `video_altyazi_durum`
  kuyruğuna `POST /medya` her video için yazıyor — DM videoları da işleniyorsa, E2E
  ile bu yetenek DM'de kaybolur ve bu bir gerileme olarak duyurulmalı.
* **[DOĞRULANMALI: iOS durumu.]** Canlıda 0 iOS cihaz token'ı var. Uygulama App
  Store'da yayında mı, yoksa yalnız Android mi? Cevap, 6.2'deki iOS kısıtlarının
  bugün önemli olup olmadığını belirler.
* **[DOĞRULANMALI: `sqlite3mc.wasm` Flutter web'de uçtan uca.]** Şifreli yerel
  mesaj deposu için önerilen yol; asset'in yayınlandığı ve resmî README'nin kullanımı
  belgelediği doğrulandı, ama fiilen derlenip çalıştırılmadı.
* **Tarayıcı sürüm tarihleri.** MDN BCD yalnız sürüm numarası verir (X25519:
  Chrome 133 / Firefox 130 / Safari 17). Takvim tarihleri eşlemedir, sürüm
  numaraları kesindir.
* **Adam-gün tahminleri ölçüm değildir.** Faz 4 (medya/ses oynatıcı yolları) en
  belirsiz kalem; gerçek maliyeti tahmininin iki katı çıkabilir.
