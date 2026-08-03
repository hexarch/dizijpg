# dizi.jpg — Akış ve Keşfet Sıralama Algoritması Planı

**Tarih:** 3 Ağustos 2026
**Kapsam:** `GET /akis`, `GET /kesfet-akis` sıralaması; admin panelinden ayarlanabilir ağırlıklar
**Yöntem:** `backend/server.js` kaynak okuması, canlı PostgreSQL üzerinde **yalnız SELECT/EXPLAIN**, canlı uçlarda `curl` zamanlaması, `app/lib/ekranlar/akis.dart` + `kesfet_akis.dart` + `backend/admin.html` incelemesi.

> Bu belgedeki her sayı ölçülmüştür; ölçüm komutu ya da kaynak satırı ilgili başlığın altındadır. Ölçemediğim, ürün kararı ya da ek doğrulama gerektiren maddeler **[DOĞRULANMALI: …]** ile işaretlidir. Tahmin edilmiş tek bir sayı yoktur.

---

## 0. UYGULAMA DURUMU (3 Ağustos 2026 — canlıda)

Motor `backend/siralama.js` (saf mantık, 51 birim testi), uçlar `server.js`,
panel `admin.html` → **Algoritma** sekmesi, istemci `app/lib/sira_tercihi.dart`.

| # | İş | Durum |
|---|---|---|
| 1.1 | `akis_olay` + temel çizgi ölçümü | ⬜ **YAPILMADI** — davranışsal telemetri (dwell/izlenme) hâlâ yok. Faz 2'ye kaldı; gizlilik metni gözden geçirilmeli. |
| 1.2 | Ağırlık motoru + admin sekmesi | ✅ **BİTTİ** — formül §4.1, normalizasyon §4.2, hacim eşiği §4.3, tur tohumu §4.5, uçlar §5.2, panel §5.3, emniyet §5.4. |
| 1.3 | Çeşitlilik + AI dengesi (Keşfet) | ✅ **BİTTİ** — yazar/içerik doygunluğu + AI payı kotası. Ölçüldü: Keşfet ilk 20 kartta **farklı yazar 1–2 → 8** (kabul kriteri ≥ 4). |
| 1.4 | `icerik_dizini` kapsaması %16,4 → %100 | ⬜ **YAPILMADI** — 407/2.479 yapım dizinde. `icerik_pop` sinyali bugün gönderilerin yalnız %16,4'ünde çalışıyor; panelde bu oran canlı gösteriliyor. |
| 1.5 | Akış şalterini aç | ✅ **BİTTİ** — `algoritma_akis_acik=1`; sayfalama 8 sayfa uçtan uca curl ile doğrulandı (tekrar/atlama yok). |
| — | **Kullanıcı seçeneği: Kronolojik / Önerilen** | ✅ **BİTTİ** (planda yoktu, §9.1-1 açık sorusunun cevabı) — varsayılan Önerilen, tercih cihazda saklanıyor, 45 dile çevrildi. |
| — | **AI oranı ve arşiv dengesi yüzdelik panel düğmesi** | ✅ **BİTTİ** (§9.1-2 ve §9.1-3'ün cevabı) — ikisi de **kota (tavan)** olarak, çarpan olarak değil. Gerekçe: kullanıcı "yüzdelik" istedi; çarpanın paya etkisi öngörülemez. |
| 2.x / 3.x | Faz 2 ve Faz 3 | ⬜ **YAPILMADI** — tetikleyici eşikler §8.1'de duruyor. |

**Plandan bilinçli sapmalar** (gerekçeleri ilgili bölümlerde):
1. **Aday havuzu 400 değil, TÜM havuz** (§4.5 → bkz. `ADAY_AZAMI` yorumu). Ölçüm: arşiv gönderileri id 86–2280 aralığında; `id DESC LIMIT 1500` penceresinde arşivden **0**, 460 videonun yalnız **33'ü** vardı. Dar pencere hem arşiv/tazelik düğmesini anlamsız kılıyor hem Keşfet videolarının %93'ünü siliyordu.
2. **Tur tohumu rastgele değil, kullanıcı+2 dakikalık pencere hash'i** (§4.5 zaten iki seçeneği de öneriyordu). Rastgele tohumda her ilk-sayfa isteği havuzu baştan skorluyordu (/kesfet-akis 0,65 s → 1,05 s).
3. **`ai_carpani` ve `taban_tazelik` yerine `ai_payi` / `arsiv_payi` yüzdelik KOTA + `tazelik_gucu` yüzdesi** — kullanıcının açık isteği ("yüzdelik oranını ben oynarım").
4. **`goruntulenme` formüle HİÇ konmadı** (§6.1 kararı aynen uygulandı) — sayaç `POST /akis/goruldu`'dan artıyor, kapalı geri besleme kurardı.
5. **Sayım sinyallerinin alt sorguları, hacim eşiği onları susturduğunda SORGUYA HİÇ KONMUYOR** — eşik aynı zamanda bir performans koruması.
6. **Ana şalterler `1` (açık) dağıtıldı**, plandaki "kapalı şalterle çık" adımı atlandı: kullanıcının ürün kararı varsayılanın "Önerilen" olmasıydı; şalter kapalıyken Önerilen = kronolojik olurdu. Geri alma yolu duruyor (`algoritma_acik=0`, dağıtımsız, anında).

---

## 1. Yönetici Özeti

Kullanıcının isteği net: *"beğeni sayısına göre şu kadar, dizi-film popülerliğine göre şu kadar, takip ettiklerinin beğendiklerine göre şu kadar öne çıksın."* Bu, standart bir ağırlıklı sıralama motorudur ve teknik olarak tamamen yapılabilir. Ama ölçüm, planı bir yerinden sertçe kırıyor:

**Bugün bu sinyallerin çoğunun matematiksel varyansı yok.**

| Ölçüm | Değer |
|---|---|
| Toplam gönderi (`ust_id IS NULL`) | **4.843** |
| Bu gönderilerin aldığı **toplam** beğeni | **139** |
| Hiç beğeni almamış gönderi | **4.736 (%97,8)** |
| Bir gönderinin aldığı **en yüksek** beğeni | **4** |
| Beğeni sayısının **95. yüzdeliği** | **0,00** |
| Toplam takip ilişkisi | **20** |
| Kayıtlı (misafir olmayan) kullanıcı | **18** (85 hesabın 67'si misafir) |
| Gönderilerin %96,9'unun sahibi | **2 hesap** (`dizi.jpg.ai` 2.410, `dizi.jpg` 2.281) |

"Beğeniye göre öne çıkar" kuralı, 4.736 gönderinin skoruna **aynı sayıyı** (sıfır) ekler. Sıralamayı belirleyen şey ağırlık değil, 86 gönderideki 1'er beğeni olur. Bu bir algoritma değil, gürültü yükselticisidir. Aynı şekilde "takip ettiklerinin beğendikleri" sinyali, 20 takip ilişkisi ve 15 farklı beğenen hesap üzerinde çalışacaktır — ortalama kullanıcının bu sinyalden alacağı sonuç boş kümedir.

Buna karşılık **varyansı olan ve bugün kullanılmayan üç güçlü sinyal var**:

1. **Kullanıcının kitaplığı — 43.542 izleme kaydı, 932 durum kaydı.** Bu, uygulamanın en zengin verisi ve şu anda sıralamada *hiç* kullanılmıyor; yalnız spoiler perdesi (`guvenli`) için okunuyor. "Kitaplığındaki dizinin gönderisi öne çıksın" kuralı bugün bile anlamlı bir sıralama üretir.
2. **İçerik popülerliği — `icerik_dizini.populerlik` tablosu zaten var** (1.761 satır, TMDB popülerlik değeri, ortalama 19,03 / en yüksek 2.054,32). Ek API maliyeti sıfır. Ancak gönderilerdeki 2.479 farklı yapımın yalnız **407'si (%16,4)** bu dizinde — geri kalanı doldurulmalı.
3. **Çeşitlilik.** Keşfet'te art arda 419 video gönderisinin 419'u tek hesabın (`dizi.jpg`). Bugün sıralama `kat, id DESC` olduğu için kullanıcı Reels'te **yalnız tek bir hesabın arşivini** kaydırıyor. Buradaki en büyük kazanç ağırlık ayarı değil, yazar/içerik doygunluk cezasıdır.

Performans tarafında iyi haber var: sıralama bugün darboğaz **değil**. Ölçüm:

| | Veritabanı süresi | Uçtan uca (HTTPS) |
|---|---|---|
| `/akis` | **5,5 ms** | 0,64–1,49 s |
| `/kesfet-akis` | **51,5 ms** | 0,65–0,79 s |

Yani isteğin ~%95'i TMDB zenginleştirmesinde (`kadroKisileri` + `icerikBilgileri`) ve ağda geçiyor. Skorlama için bol yer var. Ama bir tuzak ölçüldü: `/akis` bugün 5,5 ms'de bitiyor çünkü `ORDER BY y.id DESC` kısmi indeksten (`yorumlar_ust_null_id`) **erken çıkabiliyor** — 4.843 satırın yalnız 93'ünü okuyor. Skorla sıralamaya geçince bu erken çıkış kaybolur ve `/akis` da `/kesfet-akis` gibi tüm havuzu tarar. Bugünkü hacimde bu 5 ms → 50 ms demektir, sorun değil; ama tasarım bunu bilinçli yapmalı ve hangi hacimde bozulacağını yazmalı (bkz. 6.5).

**Önerilen yaklaşım:** algoritmayı üç fazda kur, **ölçüm altyapısıyla başla.** Faz 1'de ağırlık motorunu kur ama ağırlıkların **beğeni bacağını sıfırda başlat**; kitaplık ilgisi, içerik popülerliği ve çeşitlilikle sırala. Beğeni/etkileşim ağırlığı, hacim eşiği aşıldığında (P95 beğeni ≥ 3) otomatik devreye girsin. Böylece kullanıcı bugünden ayar panelini alır, algoritma bugünden düzelir, ve topluluk büyüdükçe formül kendiliğinden "sosyalleşir".

---

## 2. Bölüm 1 — Mevcut Durumun Ölçümü

### 2.1. Bugün `/akis` neye göre sıralıyor?

`backend/server.js:2945`:

```
ORDER BY y.id DESC LIMIT 30
```

**Saf kronolojik (id azalan).** Hiçbir puanlama, hiçbir kişiselleştirme yok. Kişiselleştirme yalnız **filtrede** var, sıralamada değil:

- `AKIS_GOVDE` (`server.js:2721`) — engellenen/engelleyen kullanıcılar, yasaklı hesaplar, yanıtlar (`ust_id IS NULL`) dışlanır. Ayrıca `CROSS JOIN LATERAL` ile `guvenli` bayrağı hesaplanır: gönderinin konusu kullanıcının kitaplığında mı (`izlemeler` / `durumlar`).
- `AKIS_KURAL` (`server.js:2766`) — uygunluk: bölüm yorumu **yalnız** o bölüm izlendiyse; dizi/film geneli yorumlar herkesten; kişi yorumları takip edilenlerden veya izlenen yapımların kadrosundan.
- `akis_goruldu` — daha önce ekranda görülen gönderiler elenir.

**Yedek (fallback) mekanizması var ve tek "popülerlik" izi burada:** ilk sayfa boş dönerse (`server.js:2960`) sırayla günün → ayın en beğenilenleri denenir:

```
ORDER BY begeni DESC, y.id DESC LIMIT 30
```

Yanıtta `kaynak: 'akis' | 'populer'` alanı döner. Ölçüm: **istemci bu alanı hiç okumuyor** (`akis.dart` içinde `kaynak` geçmiyor) — yani kullanıcı ne zaman gerçek akışı, ne zaman popüler yedeği gördüğünü bilmiyor.

### 2.2. Bugün `/kesfet-akis` neye göre sıralıyor?

`server.js:3006`. Sıralama iki anahtarlı:

```
ORDER BY <KESFET_KAT>, y.id DESC
```

`KESFET_KAT` (`server.js:2998`) sabit bir **medya türü kategorisi**:

| kat | Anlam | Ölçülen adet | Ortalama görüntülenme |
|---|---|---|---|
| 0 | Videolu (`.mp4` / `.webm`) | **458** | 6,2 |
| 1 | Fotoğraflı | **4.364** | 1,4 |
| 2 | Yazılı (medyasız) | **21** | 6,9 |

Yani Keşfet önce **bütün** videoları (458 adet), sonra **bütün** fotoğrafları, en sonda yazıları gösterir. Bu bir sıralama değil, katı bir bölümlemedir; ağırlıklandırılamaz — bir gönderi videolu olduğu için, ne kadar kötü olursa olsun, 4.364 fotoğrafın tamamının önündedir.

Videoların sahipliği ölçüldü:

| Hesap | Video | Foto | Yazı |
|---|---|---|---|
| `dizi.jpg` | **419** | 1.862 | 0 |
| `imax_archives` | 24 | 0 | 0 |
| `dizi.jpg.ai` | 8 | 2.402 | 0 |
| `thelostvibe0` | 7 | 96 | 0 |
| `alcelik` | 2 | 3 | 7 |

**419/458 = %91,5** video tek hesaba ait. Kullanıcı Keşfet'i açtığında pratikte tek bir hesabın Instagram arşivini kaydırıyor. Bu, ağırlık ayarıyla değil, çeşitlilik kuralıyla çözülür.

### 2.3. Sayfalama nasıl çalışıyor — sıralama değişirse bozulur mu? **Evet, bozulur.**

**`/akis`:** imleç `?once=<id>` (`server.js:2946`), koşul `y.id < $2`. İstemci son kartın id'sini gönderiyor (`akis.dart:132`, `Api.get('/akis?once=$sonId')`). Bu imleç **yalnızca `ORDER BY id DESC` ile doğrudur.** Skorla sıralarsak `id` monoton azalan olmaktan çıkar; `id < son` filtresi hem atlamaya (skoru yüksek ama id'si büyük gönderiler bir daha gelmez) hem tekrara yol açar.

**`/kesfet-akis`:** imleç `"<tur>:<kat>:<id>"` (`server.js:3010`), koşul:

```
(KESFET_KAT, -y.id) > ($5::int, -$2::int)
```

Bu bileşik imleç `(kat, id DESC)` sıralamasının tam karşılığı ve doğru kurulmuş — kod yorumunda gerekçesi de yazılı (`server.js:2996`: *"yalnız id ile sayfalamak sıralamayı bozardı"*). Ama sürekli bir skor eklendiğinde bu da yetmez: skor kayan noktalıdır, eşitlikler olur, ve **skorun kendisi zaman geçtikçe değişir** (tazelik azalması, yeni beğeni). Kullanıcı 3. sayfayı isterken 1. sayfadaki gönderilerin skoru değişmiş olabilir.

**Sonuç:** skor tabanlı sıralamaya geçiş, sayfalamayı **zorunlu olarak** değiştirir. Çözüm bölüm 4.5'te: **tur tohumu** (dondurulmuş sıralı id listesi).

### 2.4. Bugün elde hangi sinyaller var? (tablo envanteri)

Canlı veritabanında 31 tablo var. Sıralamayı ilgilendirenler ve **ölçülen satır sayıları**:

| Tablo | Satır | Sıralama için ne verir | Bugün kullanılıyor mu |
|---|---|---|---|
| `yorumlar` | 4.850 (4.843 gönderi + 7 yanıt) | metin, medya, tarih, `goruntulenme`, `spoiler`, `kaynak_dil` | sıralama: yalnız `id` |
| `yorum_begeniler` | **139** | beğeni sayısı, kim beğendi | yalnız yedek sorguda |
| `takipler` | **20** | sosyal graf | yalnız filtrede (uygunluk) |
| `izlemeler` | **43.542** | bölüm/film izleme geçmişi | yalnız `guvenli` (spoiler) |
| `durumlar` | **932** | izliyorum / izleyeceğim / bitirdim / bıraktım | yalnız `guvenli` |
| `puanlar` | **37** | kullanıcının verdiği puan | ❌ hiç |
| `favoriler` | **21** | favori içerik | ❌ hiç |
| `tepkiler` | **53** | 8 emojili içerik tepkisi | ❌ hiç |
| `akis_goruldu` | **695** (36 kullanıcı) | görülmüşü eleme | ✅ filtrede |
| `engellemeler` | **0** | engelleme | ✅ filtrede |
| `gizli_icerikler` | **3** | kullanıcının gizlediği yapım | ❌ akışta hiç |
| `sikayetler` | **1** | şikayet | ❌ hiç |
| `icerik_dizini` | **1.761** (1.758'i `populerlik>0`) | **TMDB popülerlik**, yerel ayna | ❌ yalnız aramada |
| `listeler` / `liste_ogeleri` | 2 / 1 | "kaydetme" muadili | ❌ hiç |
| `yorum_goruntuleyen` | **1.317** | tekil görüntüleyen | ❌ **ÖLÜ TABLO** |
| `ayarlar` | **4** | admin ayar altyapısı | ✅ `/surum-kontrol` |
| `kullanicilar` | 85 (67'si `misafir`) | hesap yaşı, `yasakli`, `misafir` | yalnız `yasakli` filtrede |

**Ölü tablo bulgusu:** `yorum_goruntuleyen` (tekil görüntüleyen kaydı) şemada ve veritabanında var, 1.317 satır tutuyor, ama `server.js` içinde **yalnız `DELETE` ile geçiyor** (`server.js:1467`, 90 günlük temizlik). Hiçbir yerde `INSERT` yok. Yani "tekil görüntülenme" sinyali için hazır tablo var ama beslenmiyor.

**`goruntulenme` alanı hakkında kritik uyarı:** bu sayaç iki yerden artıyor — yorum listelemede (`server.js:2710`) ve **`POST /akis/goruldu`'da** (`server.js:3060`). Yani **akış bir gönderiyi gösterdiği için o gönderinin görüntülenmesi artıyor.** Bu değeri sıralamaya sokmak, kapalı bir geri besleme döngüsü kurar: algoritmanın öne çıkardığı şey "popüler" olur, popüler olduğu için daha çok öne çıkar. Ayrıca aynı kişinin tekrarları da sayılıyor. Ölçüm: toplam 9.187 görüntülenme, en yüksek 37, 3.463 gönderi 0. **Faz 1'de `goruntulenme` formüle GİRMEMELİ** (gerekçe 6.1).

### 2.5. Veri hacmi ve büyüme hızı

```
kullanicilar        85   (67 misafir → 18 kayıtlı)
7 gün içinde görülen 67
yorumlar         4.850   (gönderi 4.843 / yanıt 7)
yorum_begeniler    139   (2'si kendi gönderisine, 29'u misafir hesaptan)
takipler            20   (en çok takip eden: alcelik, 7 kişi)
izlemeler       43.542   (20 farklı kullanıcı)
akis_goruldu       695   (36 kullanıcı)
veritabanı        86 MB  (yorumlar tablosu 5 MB)
```

**Günlük yeni gönderi** (son 20 gün, `date_trunc('day', tarih)`): 71 – 111 arası, ortalama ≈ **85/gün**. Bunun ezici çoğunluğu `dizi.jpg.ai` üretimi.

**Gönderi tarihlerinin yıl dağılımı — tasarımı doğrudan etkiliyor:**

| Yıl | Gönderi |
|---|---|
| 2017 | 6 |
| **2018** | **1.367** |
| 2019 | 611 |
| 2020 | 173 |
| 2021 | 27 |
| 2022–2024 | 13 |
| 2025 | 113 |
| **2026** | **2.533** |

2017–2021 arasındaki **2.184 gönderi (%45,1)**, `dizi.jpg` hesabının Instagram arşiv aktarımıdır (`min(tarih) = 2017-12-31`, `max = 2026-06-18`). Bu gönderiler *bugün* akışa girmiş içeriktir ama *tarihleri* 8 yıl eskidir. **Naif bir üstel tazelik azalması bu içeriğin %45'ini anında sıfıra gömer** ve Keşfet'in video havuzunun neredeyse tamamı (419/458) bu hesaba ait olduğu için Reels boşalır. Bu, planın en somut tuzağıdır (çözüm: 4.2'de `eklenme` ayrımı + tazelik tabanı).

### 2.6. Sorgu maliyetinin ölçümü (`EXPLAIN ANALYZE`)

Canlı veritabanında, gerçek kullanıcı `alcelik` (id=3) parametreleriyle, **yalnız EXPLAIN** çalıştırıldı:

**`/akis` ilk sayfa (LIMIT 30):**
```
Limit  (cost=60.16..2613.10 rows=30) (actual time=1.820..4.329 rows=30 loops=1)
  -> Index Scan using yorumlar_ust_null_id on yorumlar y
       (actual time=0.305..0.950 rows=93 loops=1)
Planning Time: 15.727 ms
Execution Time: 5.547 ms
```

Kritik detay: `yorumlar_ust_null_id` = `btree (id DESC) WHERE ust_id IS NULL` kısmi indeksi. `ORDER BY id DESC` bu indeksin doğal sırası olduğu için sorgu **93 satır okuyup duruyor** (4.843'ün %1,9'u). Bu hız tamamen sıralama-indeks uyumundan geliyor.

**`/kesfet-akis` ilk sayfa (LIMIT 60):**
```
Limit  (cost=84709.45..87577.30 rows=60) (actual time=47.228..50.392 rows=60 loops=1)
  -> Sort  (Sort Method: top-N heapsort  Memory: 42kB)
       -> Index Scan using yorumlar_ust_null_id
            (actual time=0.333..19.156 rows=4830 loops=1)
Execution Time: 51.458 ms
```

Keşfet **zaten** tüm havuzu (4.830 aday) tarıyor ve top-N heapsort yapıyor. Yani Keşfet için skor eklemek **karmaşıklığı değiştirmez** — bugün de O(n) tarama var. Akış için ise erken çıkışın kaybı gerçek bir maliyet artışıdır (5,5 ms → ~50 ms mertebesi).

Planda öne çıkan alt maliyetler (aynı `EXPLAIN` çıktısından):
- `SubPlan 8` — beğeni sayımı: `Seq Scan on yorum_begeniler` **her satır için** (139 satırlık tablo, 60 döngü). Tablo büyüdüğünde bu indeks ister; `yorum_begeniler_pkey (yorum_id, kullanici_id)` var ama planlayıcı 139 satırda seq scan seçiyor — büyüyünce kendiliğinden indekse döner.
- `SubPlan 15` — `unnest(y.medya)` + `LIKE '%.mp4'` **4.511 kez** çalışıyor (kategori hesabı için). Bu, `KESFET_KAT`'ın her satırda yeniden hesaplanmasından kaynaklanıyor ve skorlu modelde **kalıcı bir maliyet** olur → gönderi yazılırken hesaplanıp saklanmalı (bkz. Faz 2).

### 2.7. Uçtan uca gerçek gecikme (canlı, HTTPS, `curl`)

```
/akis        : 0,639 s  0,667 s  1,493 s   (51.053 bayt)
/kesfet-akis : 0,793 s  0,684 s  0,654 s   (91.299 bayt)
/takvim      : 1,673 s
```

Veritabanı payı `/akis`'te **5,5 ms / ~640 ms = %0,9**. Geri kalanı:
- `kadroKisileri()` (`server.js:2782`) — son 20 yapım için TMDB `/credits` çağrısı (önbellekli).
- `icerikBilgileri()` (`server.js:2810`) — dönen 30–60 gönderinin yapım adı/posteri için toplu TMDB çağrısı, gerekirse ikinci bir İngilizce turu.
- Cloudflare + TLS + nginx.

**Sonuç:** skorlama bütçesi rahat. 50 ms'lik bir skor hesabı, kullanıcının gördüğü sürenin %8'idir. Tehlike sıralamada değil, TMDB tarafındadır — ve mevcut `/takvim` 1,67 s ölçüldü (görev tanımındaki "15 sn" durumu bugün geçerli değil; muhtemelen daha önce düzeltilmiş). **[DOĞRULANMALI: /takvim'in 15 sn'lik ölçümü hangi tarihte ve hangi kullanıcıyla alınmıştı; bugünkü 1,67 s soğuk önbellekte de geçerli mi?]**

### 2.8. İstemci tarafı

**`app/lib/ekranlar/akis.dart`:**
- `Api.get('/akis')` (satır 112), sonraki sayfa `Api.get('/akis?once=$sonId')` (satır 132) — **son kartın id'si** imleç olarak gönderiliyor.
- Sunucudan gelen sıra **olduğu gibi** kullanılıyor; istemcide yeniden sıralama ya da karıştırma **yok**.
- `_goruldu` kümesi + 1 saniyelik debounce ile `POST /akis/goruldu` (satır 63–72). Yani "görüldü" bildirimi **zaten toplu ve zamanlayıcılı** — yeni telemetri buraya bedavaya binebilir (bkz. 6.2 / Faz 1.1).
- Yanıttaki `kaynak` alanı (`akis` / `populer`) **hiç okunmuyor**.
- "Kronolojik / Önerilen" gibi bir kullanıcı seçeneği **yok**.

**`app/lib/ekranlar/kesfet_akis.dart`:**
- `imlec` sunucudan geldiği gibi geri gönderiliyor (satır 213); `tekrar: true` geldiğinde listede **"hepsini gördün" ayracı** çiziliyor ve ızgara ikiye bölünüyor (satır 309–326). Bu, tur kavramının istemcide zaten görsel bir karşılığı olduğu anlamına gelir — tur tohumu modeline uyar.
- Sıralama/karıştırma yok; medya ön yüklemesi var (`_onbellekBasladi`, satır 885–898).
- **İzleme süresi / hızlı geçilme ölçülmüyor.** Reels'te bir videonun ne kadar izlendiği hiçbir yere gitmiyor — yalnız `POST /akis/goruldu` (satır 849) gidiyor, o da süresiz.

**[DOĞRULANMALI: `akis.dart` üzerinde bu oturumda iki ajan daha çalışıyor; yukarıdaki satır numaraları onların değişikliklerinden sonra kayabilir. Uygulama anında yeniden doğrulanmalı.]**

### 2.9. Admin paneli ve ayar saklama altyapısı — **hazır, yeniden kullanılabilir**

`backend/admin.html` bugün 11 sekme: Genel, Hareketler, Kullanıcılar, Yorumlar, Mailler, Geri Bildirim, Duyuru, Büyüme, Depolama, Bakım, Hatalar, Şikayetler.

Ayar mekanizması **zaten var ve tam olarak istenen şeklin prototipidir**:

- **Tablo:** `ayarlar (anahtar text PK, deger text, guncelleme timestamptz)` — bugün 4 satır: `min_derleme`, `onerilen_derleme`, `guncelleme_url`, `guncelleme_notu`.
- **Okuma + önbellek:** `ayarlariGetir()` (`server.js:797`), **60 saniyelik** bellek önbelleği (`AYAR_ONBELLEK`).
- **Yazma:** `POST /admin/ayar` (`server.js:4885`) — **beyaz liste** (`AYAR_ANAHTARLARI`, satır 4884), tip doğrulaması (`min_derleme` için `/^\d{1,6}$/`), 500 karakter kırpma, ve kaydettikten sonra `AYAR_ONBELLEK = { ts: 0 }` → **değişiklik anında etkili**.
- **Panel:** Bakım sekmesi (`admin.html:328–348`), `ayarKaydet()` (satır 992) alanları tek tek POST ediyor, `surumOnizle()` (satır 983) ise **ayarın etkisini kaydetmeden önizliyor** — istenen "önizleme" desenin çalışan örneği zaten burada.
- **Güvenlik:** `adminKisit` (`server.js:4347`) → nginx'te `geo $dizijpg_admin_izinli` + `location ^~ /api/admin { if (...) { return 404; } }`. Yani **`/api/admin` ile başlayan HER yol** otomatik korunuyor (`^~` prefix eşleşmesi). Yeni algoritma uçları `/admin/…` altına konursa **ek nginx işi gerekmez.** İkinci kapı: `X-Admin-Token` başlığı (`esitGizli` ile sabit-zamanlı karşılaştırma).

**Sonuç:** algoritma ayarları için sıfırdan altyapı kurmaya gerek yok. Faz 1'de tek yapılacak, `AYAR_ANAHTARLARI` beyaz listesine anahtar eklemek ve panelde bir sekme açmaktır.

---

## 3. Bölüm 2 — Sinyal Envanteri

Her sinyal için: **kaynak · bugün var mı · hesaplama maliyeti · manipülasyona açıklık · bugünkü ölçülen değeri.**

Maliyet ölçeği: **U** = ücretsiz (aynı satırda hazır), **D** = tek DB alt sorgusu, **DD** = ek tablo/JOIN, **A** = arka plan işi gerekir, **Y** = yeni veri toplanmalı.

### 3.1. Etkileşim sinyalleri

| Sinyal | Kaynak | Bugün | Maliyet | Manipülasyon | Ölçülen |
|---|---|---|---|---|---|
| Beğeni sayısı | `yorum_begeniler` | ✅ | D (alt sorgu, zaten `AKIS_ALANLAR`'da) | 🔴 **Yüksek** — kendi gönderisini beğenmek serbest (`server.js:3678`'de sahip kontrolü yok), misafir hesap açmak bedava | Toplam 139; %97,8 gönderi 0; max 4; **P95 = 0** |
| Yanıt sayısı | `yorumlar (ust_id)` | ✅ | D (zaten hesaplanıyor) | 🔴 Yüksek — yorum yazmak bedava | Toplam **7** yanıt |
| Görüntülenme | `yorumlar.goruntulenme` | ✅ | U | 🔴 **Kırmızı — kendi kendini besliyor** (bkz. 2.4) | Toplam 9.187, max 37, 3.463 gönderi 0 |
| Tekil görüntüleyen | `yorum_goruntuleyen` | ⚠️ tablo var, **beslenmiyor** | DD | 🟡 Orta | 1.317 eski satır |
| Beğeni/görüntülenme oranı | türetilmiş | ✅ hesaplanabilir | U | 🔴 Payda algoritmanın kendi gösterimi | Anlamsız (payda kirli) |
| Paylaşım | — | ❌ | Y | 🟢 Düşük | `gonderiPaylas` istemcide var, sunucuya **bildirilmiyor** |
| Kaydetme | `listeler` / `liste_ogeleri` | ⚠️ yapım için var, **gönderi için yok** | Y | 🟢 Düşük | 2 liste / 1 öğe |
| İçerik emoji tepkisi | `tepkiler` | ✅ | DD | 🟡 Orta | 53 satır |

**Yorum:** bu blok bugün neredeyse tamamen ölü. Ağırlık verilebilir ama etkisi ölçülemez. **Faz 1'de bu bloğun toplam ağırlığı 0 olmalı**, hacim eşiği aşılınca (4.3) otomatik açılmalı.

### 3.2. Sosyal sinyaller

| Sinyal | Kaynak | Bugün | Maliyet | Manipülasyon | Ölçülen |
|---|---|---|---|---|---|
| Takip ettiğim kişinin gönderisi | `takipler` | ✅ (yalnız filtrede) | D — `takip_ediyorum` **zaten** `AKIS_ALANLAR`'da hesaplanıyor | 🟢 Düşük | 20 ilişki; en aktif kullanıcı 7 kişi takip ediyor |
| Takip ettiklerimin **beğendiği** gönderi | `takipler ⋈ yorum_begeniler` | ❌ | DD (`EXISTS` iki tablo) | 🔴 Yüksek — takip + beğeni birlikte sahte hesapla üretilebilir | Bugün ortalama kullanıcı için **boş küme**: 20 takip × 139 beğeni |
| Takip ettiklerimin yorum yaptığı | `takipler ⋈ yorumlar(ust_id)` | ❌ | DD | 🔴 Yüksek | 7 yanıt var; pratikte boş |
| Karşılıklı takip | `takipler` (iki yönlü) | ❌ | DD | 🟡 Orta | **[DOĞRULANMALI: karşılıklı takip çifti sayısı ölçülmedi]** |
| İkinci derece bağlantı (takip ettiğimin takip ettiği) | `takipler` self-join | ❌ | A (graf, kullanıcı başına önbellek) | 🟡 Orta | 20 kenarlı grafta anlamsız |
| Yazar aynı ülkeden | `kullanicilar.ulke` | ⚠️ alan var | D | 🟢 Düşük | Dolulukolçülmedi **[DOĞRULANMALI]** |

**Yorum:** 20 kenarlı bir sosyal grafta "takip ettiklerinin beğendikleri" kuralı, kullanıcının talebinin tam merkezinde ama **bugün hiçbir sonuç üretmez**. Motora konmalı (ağırlık slider'ı olmalı, kullanıcı istedi), varsayılanı düşük olmalı, ve panelde "bu sinyal şu an X gönderiyi etkiliyor" diye canlı sayaç gösterilmeli — böylece kullanıcı ağırlığı yükseltip hiçbir şey değişmediğinde şaşırmaz.

### 3.3. İçerik ilgisi (kullanıcı ↔ yapım)

| Sinyal | Kaynak | Bugün | Maliyet | Manipülasyon | Ölçülen |
|---|---|---|---|---|---|
| Yapım kitaplığımda | `izlemeler` + `durumlar` | ✅ **`guvenli` olarak zaten hesaplanıyor** (`AKIS_GOVDE`) | **U — bedava**, LATERAL sonucu skorda yeniden kullanılabilir | 🟢 **Yok** (kendi verisi) | 43.542 izleme + 932 durum |
| İzleme durumu (izliyorum > bitirdim > izleyeceğim) | `durumlar.durum` | ⚠️ `izliyorum/bitirdim` ayrımı var, skorlanmıyor | D | 🟢 Yok | 932 satır, 4 durum değeri |
| Puan verdiğim yapım | `puanlar` | ❌ | DD | 🟢 Yok | **37** satır |
| Favorilerim | `favoriler` | ❌ | DD | 🟢 Yok | **21** satır |
| Gizlediğim yapım | `gizli_icerikler` | ❌ **akışta hiç kullanılmıyor** | D | 🟢 Yok | 3 satır |
| Sevdiğim tür (genre) | TMDB detayları | ❌ | A — kullanıcı tür profili gecelik hesaplanmalı | 🟢 Yok | Yok |
| Yapımın kadrosu ilgimi çekiyor | `kadroKisileri()` | ✅ (uygunluk filtresinde) | **Pahalı** — 20 TMDB `/credits` çağrısı, her istekte | 🟢 Yok | Her `/akis` isteğinde çalışıyor |

**Bu blok planın omurgasıdır.** Manipülasyona kapalı (kullanıcının kendi verisi), hacmi bugün bile büyük (43.542 izleme), ve `guvenli` bayrağı zaten hesaplandığı için **ek maliyeti sıfırdır**. Bugün yalnız spoiler perdesi için okunan bir değer, doğrudan skora çevrilebilir.

### 3.4. İçerik popülerliği (yapımın kendisi)

| Sinyal | Kaynak | Bugün | Maliyet | Manipülasyon | Ölçülen |
|---|---|---|---|---|---|
| **TMDB popülerlik** | `icerik_dizini.populerlik` | ✅ tablo var | **D — yerel JOIN, API çağrısı yok** | 🟢 Yok (dış kaynak) | 1.761 satır; ort **19,03**, max **2.054,32**, **P95 = 76,28** |
| TMDB oy sayısı / oy ortalaması | TMDB `vote_count` | ⚠️ `icerikKartlari` içinde geçici | D→A | 🟢 Yok | Saklanmıyor |
| Kapsama | `icerik_dizini` ∩ gönderiler | ⚠️ | — | — | Gönderilerdeki **2.479** farklı yapımdan yalnız **407'si (%16,4)** dizinde |
| Uygulama içi popülerlik (yapıma yazılan gönderi sayısı) | `yorumlar GROUP BY (tur,tmdb_id)` | ❌ | A (gecelik materyalize) | 🟡 Orta | Hesaplanabilir; 2.479 yapım |
| Uygulama içi izlenme (yapımı kaç kişi izliyor) | `durumlar` / `izlemeler` | ⚠️ `/admin/buyume` içinde var | A | 🟢 Düşük | `top_icerik` sorgusu zaten mevcut |
| Yeni sezon/bölüm çıkmış olması | TMDB `next_episode_to_air` | ❌ | A + TMDB | 🟢 Yok | Yok |
| Gündemdelik (trend) | TMDB `/trending` | ❌ | A + TMDB | 🟢 Yok | Yok |

**Kritik:** `populerlik` dağılımı çok çarpık (ort 19, P95 76, max 2.054 → **27× P95**). Ham değerle çarpmak, tek bir gündemdeki dizinin tüm akışı ele geçirmesi demektir. **Logaritmik dönüşüm zorunludur** (4.2).

**Kapsama sorunu**: %16,4. `icerik_dizini`'ni gönderilerdeki tüm `(tur, tmdb_id)` çiftleriyle doldurmak gecelik bir işle mümkün — 2.072 eksik yapım, 8'li paralel öbeklerle TMDB'den çekilir (`server.js:3882`'deki `INSERT ... ON CONFLICT` zaten yazılmış).

### 3.5. Tazelik (zaman)

| Eğri | Formül | Ayarlanabilirlik | Bu veri kümesinde davranışı |
|---|---|---|---|
| **Üstel yarı ömür** | `0.5 ^ (yaş / yarıÖmür)` | ⭐ **Tek, anlaşılır knob:** "yarı ömür = 48 saat" | Toplamdan **ayrılabilir** → ağırlıklarla çarpım olarak birleşir. Admin'e açıklaması kolay. |
| Hacker News | `(P-1) / (T+2)^G` | Puan ve zaman **tek kesirde**; ağırlıkları ayrıştırmak imkânsız | P = beğeni; burada P≈0 → tüm gönderiler eşit. **Kullanılamaz.** |
| Reddit "hot" | `log10(max(|s|,1)) + sign(s)·t/45000` | Zaman **toplamsal**; 12,5 saat ≈ ×10 oy | Oy hacmi gerektirir; 139 oyluk sistemde skor tamamen `t`'ye indirgenir → **kronolojiye eşdeğer**. |
| Wilson alt sınırı | `p̂` güven aralığı alt sınırı | Az veride muhafazakâr | 🟢 Doğru araç ama **payda gerekiyor** (tekil görüntülenme) — bugün yok |

**Öneri: üstel yarı ömür**, çünkü (a) çarpımsal olduğu için ağırlıklı toplamdan bağımsız ayarlanır, (b) tek sayı ile anlatılır, (c) admin panelinde "yarı ömür (saat)" alanı olarak doğrudan sunulur.

**Ama arşiv tuzağı var** (2.5): 2.184 gönderi (%45,1) 5–8 yıl eski tarihli. İki önlem birlikte:
1. **Tazelik tabanı** (`taban_tazelik`, varsayılan 0,15): `T = max(taban, 0.5^(yaş/yarıÖmür))`. Arşiv içerik sıfırlanmaz, yalnız güncel içeriğin gerisine düşer.
2. **`eklenme` ≠ `tarih` ayrımı** (Faz 2): `yorumlar` tablosunda gönderinin *sisteme giriş* zamanını tutan yeni bir kolon. Bugün böyle bir kolon **yok** — `tarih` hem yayın hem giriş zamanı olarak kullanılıyor. Arşiv aktarımında `tarih` orijinal Instagram tarihine set edilmiş.

### 3.6. Medya türü ve kalitesi

| Sinyal | Kaynak | Bugün | Maliyet | Ölçülen |
|---|---|---|---|---|
| Video / foto / yazı | `medya[]` + `LIKE '%.mp4'` | ✅ `KESFET_KAT` olarak (katı bölümleme) | **DD — pahalı**: `unnest` her satırda, `EXPLAIN`'de **4.511 kez** çalıştı | 458 / 4.364 / 21 |
| Medya adedi (karusel) | `cardinality(medya)` | ⚠️ | U | Ölçülmedi **[DOĞRULANMALI]** |
| Video süresi | — | ❌ | Y | Yok |
| Metin uzunluğu | `length(metin)` | ❌ | U | Ölçülmedi **[DOĞRULANMALI]** |
| Altyazısı var mı | `video_altyazilar` | ⚠️ tablo var | DD | Ölçülmedi |

**Öneri:** katı `kat` bölümlemesini **ağırlıklı bir katkıya çevir**. Yani "video +40 puan, foto +20, yazı +10" gibi; böylece çok iyi bir fotoğraf gönderisi vasat bir videonun önüne geçebilir. Ayrıca `kat` **satır yazılırken hesaplanıp saklanmalı** (`yorumlar.medya_kat smallint`) — bu tek başına `/kesfet-akis`'in 51 ms'sinden ciddi pay siler.

### 3.7. Yazar kalitesi

| Sinyal | Kaynak | Bugün | Maliyet | Manipülasyon | Ölçülen |
|---|---|---|---|---|---|
| Yazarın geçmiş etkileşim oranı | `yorum_begeniler / yorumlar` yazar bazında | ❌ | A (gecelik) | 🔴 Yüksek | `dizi.jpg.ai`: 43 beğeni / 2.410 gönderi = **0,018**; `alcelik`: 15/12 = **1,25**; `imax_archives`: 18/24 = **0,75** |
| Hesap yaşı | `kullanicilar.olusturma` | ⚠️ alan var | U | 🟢 Yok | Ölçülmedi **[DOĞRULANMALI]** |
| Misafir hesap mı | `kullanicilar.misafir` | ⚠️ alan var | U | 🟢 Yok | **67/85 misafir** |
| Yasaklı | `kullanicilar.yasakli` | ✅ filtrede | U | 🟢 Yok | Filtrede |
| Doğrulanmışlık | — | ❌ | Y | — | Böyle bir alan yok |
| **AI hesabı** | `kullanici_adi = 'dizi.jpg.ai'` | ✅ **sabit olarak var** (`AI_KULLANICI`, `server.js:2891`) | U | 🟢 Yok | 2.410 gönderi = **gönderilerin %49,8'i** |

**Ölçüm çarpıcı:** `alcelik`'in gönderi başına beğenisi (1,25), `dizi.jpg.ai`'ninkinin (0,018) **69 katı**. Yazar kalitesi, bu veri kümesinde beğeni sayısından **çok daha yüksek varyanslı** bir sinyaldir — çünkü paydası (gönderi sayısı) büyük. Bu, Faz 1'de kullanılabilecek nadir etkileşim türevi sinyaldir.

**AI hesabı ayrı ağırlık almalı mı? Evet, mutlaka.** Gönderilerin yarısı tek AI hesabından geliyor. Tek bir `ai_carpani` (0,0–1,0) ile kullanıcı, akışın ne kadarının AI incelemesi olacağını doğrudan ayarlayabilir. Bu tek slider, muhtemelen tüm panelin en etkili düğmesidir.

### 3.8. Dil ve yerellik

| Sinyal | Kaynak | Bugün | Maliyet | Ölçülen |
|---|---|---|---|---|
| Gönderinin kaynak dili | `yorumlar.kaynak_dil` (indeksli) | ✅ alanda var, sıralamada yok | U | **6** farklı dil; 4.843 gönderinin **159'u** `tr` dışı |
| Kullanıcının dili | `istekBaglam.getStore()?.dil` | ✅ zaten `$4` parametresi | U | 45 dil destekleniyor |
| Hazır çevirisi var mı | `metin_cevirileri` | ✅ `ceviri_metin` alt sorgusu | D (zaten var) | — |
| Kullanıcının ülkesi | `kullanicilar.ulke` | ⚠️ alan var | U | **[DOĞRULANMALI: doluluk oranı]** |

**Yorum:** 159/4.843 = %3,3. Bugün küçük ama uygulama 45 dilde ve büyüme uluslararası olursa bu sinyal hızla önem kazanır. Çeviri altyapısı hazır olduğu için (`/ceviri` ucu anında çeviri üretiyor) yabancı içeriği **cezalandırmak yerine**, "çevirisi hazır olan" gönderilere küçük bir artı vermek daha doğrudur.

### 3.9. Negatif sinyaller

| Sinyal | Kaynak | Bugün | Nasıl uygulanmalı |
|---|---|---|---|
| Görülmüş | `akis_goruldu` | ✅ **filtre** (tamamen eleniyor) | Keşfet'te 2. turda geri geliyor; skorlu modelde **çarpan** olarak da uygulanabilir (0,1) — ama filtre daha basit, korunmalı |
| Engellenen kullanıcı | `engellemeler` | ✅ **filtre** | 🔴 **ASLA skora çevrilmemeli** — filtrede kalmalı (6.3) |
| Yasaklı hesap | `kullanicilar.yasakli` | ✅ filtre | Filtrede kalmalı |
| Spoiler işareti + izlememiş | `yorumlar.spoiler` + `guvenli` | ✅ **perde** (`akisSatiri`, `server.js:2894`) | 🔴 Perde korunmalı; skorda **ayrıca** küçük ceza olabilir |
| Gizlenen yapım | `gizli_icerikler` | ❌ akışta yok | **Filtre olmalı** — kullanıcı bir yapımı gizlediyse gönderisi de gelmemeli. Bugün gelmesi bir hata sayılabilir |
| Şikayet edilmiş | `sikayetler` | ❌ | Skorda güçlü ceza + eşik üstünde filtre |
| Hızlı geçilen (Reels izleme süresi) | — | ❌ | Y — istemci ölçümü gerekir (Faz 2) |
| "İlgilenmiyorum" | — | ❌ | Y — yeni UI + tablo (Faz 3) |

### 3.10. Çeşitlilik ve doygunluk

| Sinyal | Bugün | Ölçülen gerekçe |
|---|---|---|
| Aynı yazardan art arda gönderi | ❌ hiç sınır yok | Keşfet'in ilk 458 kartının **419'u tek hesaptan** |
| Aynı yapım hakkında art arda gönderi | ❌ | 4.843 gönderi / 2.479 yapım = yapım başına ort. 1,95 gönderi |
| Aynı medya türünden art arda | ⚠️ tam tersi — `kat` bunu **zorluyor** | 458 video → 4.364 foto blok blok |
| Filtre balonu | ❌ | Kitaplık ağırlığı yükseltilirse ortaya çıkar; `kesif_payi` ile karşılanmalı |

**Bu blok, bugünkü veride en yüksek getirili müdahaledir.** Tek bir "aynı yazardan son N kart içinde en fazla M" kuralı, kullanıcının Keşfet deneyimini herhangi bir ağırlık ayarından daha fazla değiştirir.

### 3.11. Soğuk başlangıç

| Durum | Bugün ne oluyor | Ölçüm |
|---|---|---|
| **Yeni kullanıcı** (takip yok, kitaplık yok) | `AKIS_KURAL`'ın son dalı (`y.sezon IS NULL AND y.tur <> 'person'`) sayesinde akış boş kalmıyor — tüm genel gönderiler gelir, kronolojik | 85 kullanıcının 67'si misafir; bu yol **ana yol** |
| İlk sayfa yine de boşsa | Popüler yedek devreye giriyor (`kaynak: 'populer'`) | `ORDER BY begeni DESC` — 139 beğeni üzerinden |
| **Yeni gönderi** (etkileşim yok) | Kronolojik sırada en üstte | Skorlu modelde: tazelik çarpanı 1,0 → doğal koruma |

**Yeni gönderi için ek koruma gerekli mi?** Üstel tazelik + sıfır ağırlıklı beğeni bacağı bunu zaten sağlıyor. Beğeni ağırlığı açıldığında (hacim eşiği) "keşif kotası" gerekecek: her sayfada en az `%N` yeni/az görülmüş gönderi. Faz 3.

---

## 4. Bölüm 3 — Puanlama Modeli

### 4.1. Formülün şekli: neden **katmanlı hibrit**?

Üç aday:

| Model | Artı | Eksi |
|---|---|---|
| Saf ağırlıklı toplam `Σ aᵢ·nᵢ` | Admin'e "oran" olarak anlatılabilir (kullanıcının istediği zihinsel model) | "Bastır" semantiği yok — bir sinyali sıfırlamak için negatif ağırlık gerekir, o da toplamı bozar |
| Saf çarpımsal `Π nᵢ^aᵢ` | Bastırma doğal | Tek sıfır her şeyi sıfırlar; oran algısı yok; ayarlaması sezgisel değil |
| **Katmanlı hibrit** ⭐ | Oran algısı (toplam) + bastırma (çarpan) bir arada | Biraz daha çok kavram |

**Önerilen:**

```
Skor(g, k) = [ Σᵢ  aᵢ · nᵢ(g, k) ]  ×  T(yaş)  ×  Πⱼ cⱼ(g, k)
             └──── ilgi toplamı ────┘   └tazelik┘  └──cezalar──┘
                    aᵢ toplamı = 100
```

- **İlgi toplamı** — kullanıcının ayarladığı **yüzde** ağırlıklar. Bu kısım tam olarak "beğeniye göre şu kadar, popülerliğe göre şu kadar" ifadesinin karşılığıdır.
- **Tazelik `T`** — 0–1 arası çarpan, ayrı bir "yarı ömür" knob'u.
- **Cezalar `cⱼ`** — 0–1 arası çarpanlar: yazar doygunluğu, içerik doygunluğu, AI çarpanı, spoiler cezası, şikayet cezası. Her biri ayrı alan; "toplamı 100" kuralına dahil **değil** (aksi halde bir cezayı açmak bir ilgi sinyalini kısardı — anlamsız).

**Sert filtreler formüle GİRMEZ.** Engelleme, yasaklı hesap, bölüm-spoiler uygunluğu, gizlenen yapım: bunlar SQL `WHERE`'de kalır ve skorlamadan **önce** uygulanır (gerekçe 6.3).

### 4.2. Normalizasyon — her sinyal 0–1 aralığına nasıl iner

Beğeni sayısı (0–4) ile TMDB popülerliği (0–2.054) aynı skalada değil. Üç yöntem, sinyal tipine göre:

**(a) Sayım tipi sinyaller → log + P95 kırpma**

```
n(x) = min( 1, log(1 + x) / log(1 + P95) )
```

- `P95` gecelik hesaplanır ve `ayarlar`'a yazılır (canlı sorguda alt sorgu yok, sabit sayı).
- Ölçülen P95 değerleri: **beğeni = 0,00**, görüntülenme = 12,00, **TMDB popülerlik = 76,28**.
- Log dönüşümü zorunlu: popülerlik max/P95 = 2.054/76,3 = **26,9×**. Log'suz tek bir dizi tüm akışı ezer.
- **Emniyet:** `P95 < 1` ise bölme tanımsız → o sinyal **otomatik devre dışı** ve ağırlığı diğerlerine orantılı dağıtılır. Bugün beğeni sinyali tam bu duruma düşer, ve bu **istenen davranıştır** (bkz. 4.3).

**(b) Boolean sinyaller → 0 / 1**

`takip_ediyorum`, `kitapligimda` (=`guvenli`), `dil_esleşiyor`, `favori`, `takip_ettigim_begendi`. Bunlar zaten 0/1; normalizasyon gerekmez.

**(c) Sıralı (ordinal) sinyaller → sabit merdiven**

```
durum:  izliyorum 1,00 | bitirdim 0,70 | izleyecegim 0,50 | biraktim 0,00 | (yok) 0,00
medya:  video 1,00 | foto 0,55 | yazi 0,30       ← bugünkü katı `kat`ın yumuşatılmışı
```

Merdiven değerleri **kodda sabit**, ağırlıkları panelde ayarlanır. Aksi halde panel 30 alanlık bir tabloya döner.

**Neden z-skor değil?** Z-skor merkezî eğilim varsayar; ölçülen dağılımlar tek kuyruklu ve %97,8'i sıfır. Z-skor bu veride sıfırların hepsine aynı negatif değeri verir ve kırpma yine gerekir. Log+P95 hem daha basit hem daha dayanıklı.

**Tazelik:**

```
T(yaş) = max( taban_tazelik , 0.5 ^ (yaş_saat / yari_omur_saat) )
```
- `yari_omur_saat` varsayılan: **Akış 36**, **Keşfet 168** (Keşfet keşif odaklı, eski içerik değerli).
- `taban_tazelik` varsayılan **0,15** — 2.184 arşiv gönderisinin sıfırlanmasını engeller (2.5).

**Cezalar:**

```
c_yazar   = yazar_doygunluk ^ (aynı yazardan önceki kart sayısı, pencere içinde)
c_icerik  = icerik_doygunluk ^ (aynı yapımdan önceki kart sayısı)
c_ai      = ai_carpani                (yalnız kullanici_adi = 'dizi.jpg.ai' ise)
c_spoiler = spoiler_ceza              (spoiler işaretli VE guvenli değilse)
c_sikayet = sikayet_ceza ^ (açık şikayet sayısı)
```
Varsayılanlar: `yazar_doygunluk = 0,70`, `icerik_doygunluk = 0,80`, `ai_carpani = 0,60`, `spoiler_ceza = 0,85`, `sikayet_ceza = 0,50`.

Doygunluk cezası **sıralama sırasında ardışık** uygulanır (greedy yeniden sıralama): liste skora göre sıralanır, sonra baştan geçilirken her seçilen kart, aynı yazarın/yapımın kalan kartlarının skorunu çarpanla düşürür. Bu, tek geçişte O(n) çalışır.

### 4.3. **Hacim eşiği** — az veride sinyalin otomatik susması

Ölçülen gerçek: P95(beğeni) = 0. Bir sinyalin ayırt edici olması için varyansı olmalı.

```
Kural: bir sayım sinyali için P95 < hacim_esigi (varsayılan 3) ise
       → o sinyalin ağırlığı 0 kabul edilir,
       → kalan ağırlıklar oranlarını koruyarak 100'e yeniden ölçeklenir,
       → admin panelinde slider'ın yanında "🔇 hacim yetersiz (P95=0,0)" rozeti çıkar.
```

Bu, planın en önemli tek kuralıdır. Kullanıcı "beğeniye %40 ver" der, sistem kabul eder, ama **bugün** o %40'ı sessizce diğer sinyallere dağıtır ve **bunu panelde açıkça söyler**. Topluluk büyüyüp P95 3'ü geçtiğinde slider kendiliğinden canlanır — kod değişikliği, dağıtım, hatırlama gerekmez.

### 4.4. Ağırlıkların birimi ve varsayılan setler

**Birim: 0–100 tam sayı slider, panelde anlık yüzde gösterimi.** Kullanıcı "şu kadar oranda" dediği için oran algısı korunmalı. Slider'lar serbest girilir (toplamları 100 olmak zorunda değil), sunucu normalize eder: `aᵢ = sliderᵢ / Σslider × 100`. Panelde her slider'ın yanında hesaplanan gerçek yüzde yazar ("Beğeni: 40 → **%22,2**"). Bu, "toplamı 100 yapmak" zorunluluğunun kullanıcıyı sinir eden yanını ortadan kaldırır ama oran algısını korur.

**Ayrı ağırlık setleri: Akış ve Keşfet için EVET.** Gerekçeler ölçülmüş:

1. **Sosyal graf Keşfet'i besleyemez.** 20 takip ilişkisi var; Keşfet 60 kart döndürüyor. Sosyal ağırlık Keşfet'te matematiksel olarak boş.
2. **Medya türü Akış'ta anlamsız, Keşfet'te belirleyici.** Keşfet bir Reels arayüzü; `kat` orada zaten birincil anahtar. Akış'ta ise 21 yazılı gönderi de birinci sınıf vatandaş.
3. **Sayfalama mimarisi farklı.** Akış tek anahtarlı (`once=id`), Keşfet bileşik + iki turlu (`tur:kat:id`). Tek bir ayar seti iki farklı imleç davranışını yönetemez.
4. **Tazelik beklentisi farklı.** Akış "ne oldu"; Keşfet "ne varmış". Yarı ömür 36 sa vs 168 sa.

**Önerilen varsayılanlar (bugünkü ölçümlere göre kalibre edilmiş):**

| Ağırlık | Akış | Keşfet | Gerekçe (ölçüm) |
|---|---|---|---|
| `kitaplik` — yapım kitaplığımda | **35** | **30** | 43.542 izleme; bedava (`guvenli` hazır); manipüle edilemez |
| `takip_ettigim` — yazarı takip ediyorum | **30** | **5** | `takip_ediyorum` zaten hesaplanıyor; Keşfet'te 20 kenar → etkisiz |
| `icerik_pop` — TMDB popülerliği | **15** | **30** | 1.758 satır hazır; kapsama %16,4 → Faz 1'de doldurulacak |
| `medya` — video/foto/yazı | **0** | **25** | Keşfet'in bugünkü `kat`ının yumuşatılmışı |
| `yazar_kalite` — yazarın gönderi başına beğenisi | **10** | **10** | Varyansı ölçüldü: 0,018 – 1,25 (**69×**) |
| `dil` — dilimle eşleşme / çevirisi hazır | **10** | **0** | 159 yabancı gönderi (%3,3) |
| `begeni` — gönderi beğeni sayısı | **0** ⚠️ | **0** ⚠️ | **P95 = 0 → hacim eşiğinin altında, otomatik susar** |
| `yanit` — yanıt sayısı | **0** ⚠️ | **0** ⚠️ | Toplam **7** yanıt |
| `takip_begendi` — takip ettiğimin beğendiği | **0** ⚠️ | **0** | 20 takip × 139 beğeni → boş küme |
| `goruntulenme` | **YOK** | **YOK** | 🔴 Kendi kendini besleyen sayaç — formüle hiç konmayacak (6.1) |

⚠️ ile işaretliler **panelde görünür ve ayarlanabilir**, ama hacim eşiği nedeniyle bugün susturulmuş; rozetleri bunu söyler. Kullanıcının açıkça istediği üç sinyal (beğeni, içerik popülerliği, takip ettiklerinin beğendikleri) **üçü de motorda vardır** — ikisi bugün susmaktadır ve bu durum panelde şeffaftır.

Çarpanlar (ayrı alanlar, yüzde toplamına dahil değil):

| Alan | Akış | Keşfet | Aralık |
|---|---|---|---|
| `yari_omur_saat` | 36 | 168 | 1 – 8760 |
| `taban_tazelik` | 0,15 | 0,15 | 0 – 0,50 |
| `yazar_doygunluk` | 0,70 | **0,50** | 0,10 – 1,00 |
| `icerik_doygunluk` | 0,80 | 0,80 | 0,10 – 1,00 |
| `ai_carpani` | 0,60 | 0,60 | 0,00 – 1,00 |
| `spoiler_ceza` | 0,85 | 0,85 | 0,10 – 1,00 |
| `kesif_payi` (rastgele/keşif kotası) | 0,10 | 0,20 | 0,00 – 0,50 |

Keşfet'te `yazar_doygunluk` daha sert (0,50) çünkü ölçüm: videoların %91,5'i tek hesapta.

### 4.5. Sıralama nerede yapılacak ve sayfalama nasıl korunacak

**Öneri: iki aşamalı — aday SQL'de, skor Node'da.**

```
AŞAMA 1 (SQL)  : bugünkü AKIS_GOVDE + AKIS_KURAL + görülmüş filtresi
                 + ucuz ön-sıralama (id DESC)  → LIMIT 400 aday
AŞAMA 2 (Node) : ağırlıklarla skorla → sırala → doygunluk cezasıyla
                 tek geçişte yeniden sırala → sıralı id listesi
```

**Neden Node?**
- Ağırlıklar **anında** değişir; SQL şablonunu yeniden yazmak gerekmez (bugünkü `AYAR_ONBELLEK` deseni doğrudan çalışır).
- Admin panelindeki **önizleme** aynı fonksiyonu kaydetmeden çağırabilir — `surumOnizle()` deseninin birebir eşi.
- Doygunluk cezası ardışık bir işlemdir; SQL'de pencere fonksiyonlarıyla yapılabilir ama okunması ve ayarlanması zorlaşır.
- Maliyet ölçüldü: SQL bugün 4.830 satırı 51 ms'de zaten tarıyor; 400 adayın Node'da skorlanması **1 ms altı**.

**Neden 400?** Bugünkü havuz 4.843. 400 aday, doygunluk cezasından sonra 60 kartlık bir Keşfet sayfasını rahat doldurur ve `LIMIT` sayesinde SQL'in erken çıkışı kısmen korunur. Faz 2'de bu sayı ayarlanabilir hale gelir.

**Sayfalama: tur tohumu (round seed).**

```
İlk sayfa isteği:
  1. tohum s = rastgele 32-bit (ya da kullanıcı+dakika hash'i)
  2. adaylar SQL'den → Node'da skorla → sıralı id dizisi L
  3. L bellekte saklanır: anahtar "k:<kullanici_id>:<s>", TTL 10 dk, LRU
  4. ilk 30/60 döner, imleç = "<s>:<offset>"
Sonraki sayfa:
  1. imleçten s ve offset çözülür
  2. L bellekten okunur → dilim alınır
  3. L düşmüşse (TTL/yeniden başlatma) → yeniden hesaplanır, aynı s ile
     (skorlama deterministik olduğu için sonuç neredeyse aynıdır; tek
      fark bu arada eklenen gönderilerdir, onlar da listenin başına düşer)
```

Bu tasarım:
- **Tekrar/atlama olmaz** — liste dondurulmuştur.
- **Ağırlık değişikliği devam eden kaydırmayı bozmaz** — kullanıcı turu bitirdiğinde yeni ağırlıklara geçer. Bu bir kusur değil, istenen davranıştır (ekran ortasında sıra değiştirmek kötü UX'tir).
- **Bellek maliyeti ölçülebilir:** 4.843 id × 8 bayt ≈ 39 KB / oturum. 100 eşzamanlı oturum ≈ **3,9 MB**. Bugün 7 günde aktif 67 hesap var — sorun yok.
- **Geriye uyum:** eski istemciler `?once=<id>` göndermeye devam edecek. Sunucu, imleçte `:` yoksa **bugünkü davranışa** (id azalan) düşmelidir. Keşfet'te de `<tur>:<kat>:<id>` biçimi tanınmaya devam etmeli. Aksi halde güncellenmemiş uygulamalarda akış kırılır. **Bu bir zorunluluktur, seçenek değil.**

**Alternatif (daha ucuz ama daha zayıf):** skoru SQL'de `ORDER BY` ifadesine gömüp imleci `(skor, id)` bileşiği yapmak. Reddedilme gerekçesi: skor zamana bağlıdır (`T(yaş)`), yani iki sayfa arasında değişir; bileşik imleç kayar. Ayrıca doygunluk cezası ifade edilemez.

### 4.6. Kişiselleştirme maliyeti ve önbellek stratejisi

| Katman | Ne | Ne zaman hesaplanır | Nerede durur |
|---|---|---|---|
| **Kullanıcıdan bağımsız taban** | yazar kalitesi, içerik popülerliği (log), P95 değerleri, medya kategorisi | **Gecelik** (`server.js:1465` civarındaki mevcut temizlik işine eklenebilir) | `ayarlar` + `icerik_dizini` + (Faz 2) `yorumlar.medya_kat` |
| **Kullanıcıya özel** | kitaplık eşleşmesi, takip, dil, görülmüş | **İstek anında** | `AKIS_GOVDE`'nin zaten hesapladığı `guvenli` + `takip_ediyorum` yeniden kullanılır → **ek maliyet ≈ 0** |
| **Sıralı liste** | skorlanmış id dizisi | İlk sayfa isteğinde | Node LRU, TTL 10 dk |

**Kritik tasarruf:** kişisel sinyallerin ikisi (`guvenli`, `takip_ediyorum`) **bugün zaten** her satır için hesaplanıyor ve yanıtla dönüyor. Skorda yeniden kullanılırlar, ek sorgu yok. Bu, "kişiselleştirme pahalıdır" varsayımını bu projede geçersiz kılar.

`kadroKisileri()` ise gerçekten pahalıdır (20 TMDB `/credits`) ve **her `/akis` ve `/kesfet-akis` isteğinde** çalışıyor. Skorlamayla ilgisi yok ama aynı dosyada duruyor — kullanıcı başına 10 dakikalık bir bellek önbelleği bu iki ucun gecikmesini kayda değer düşürür. Faz 2'ye ayrı madde olarak konmalı.

---

## 5. Bölüm 4 — Admin Paneli

### 5.1. Ayarlar nerede saklanacak

**Faz 1 önerisi: mevcut `ayarlar` tablosunu kullan, iki JSON anahtarıyla.** Yeni tablo yok, yeni migrasyon yok, yeni önbellek yok.

```
ayarlar['algoritma_akis']   = '{"kitaplik":35,"takip_ettigim":30,...,"yari_omur_saat":36,...}'
ayarlar['algoritma_kesfet'] = '{...}'
ayarlar['algoritma_acik']   = '1' | '0'          ← ana şalter
```

Gerekçe: `ayarlariGetir()` zaten var, 60 sn önbellekli, `POST /admin/ayar` kaydettikten sonra önbelleği sıfırlıyor → **değişiklik anında etkili**. `deger` alanı `text` ve POST 500 karakterde kırpıyor — **JSON 500 karakteri aşabilir, bu sınır yükseltilmeli** (algoritma anahtarları için ayrı bir üst sınır, ör. 4.000).

**Faz 2'de eklenecek geçmiş tablosu** (kullanıcı "kim ne zaman değiştirdi" istedi):

```sql
CREATE TABLE IF NOT EXISTS algoritma_gecmis (
  id         serial PRIMARY KEY,
  yuzey      text NOT NULL,          -- 'akis' | 'kesfet' | 'genel'
  eski       jsonb,
  yeni       jsonb NOT NULL,
  kim        text NOT NULL,          -- admin IP veya 'token'
  tarih      timestamptz DEFAULT now()
);
CREATE INDEX ON algoritma_gecmis (tarih DESC);
```

Neden ayrı tablo, neden `ayarlar`'a sığdırmıyoruz: `ayarlar` anahtar başına tek satır tutuyor (`PRIMARY KEY (anahtar)`), geçmiş tutamaz. `kim` alanı `gercekIp(req)` ile doldurulur — `adminKisit` zaten bu IP'yi hesaplıyor.

**Neden baştan tam ilişkisel bir `algoritma_ayar (yuzey, anahtar, deger)` tablosu değil?** Çünkü ağırlıklar **atomik bir set olarak** anlam taşır — tek tek kaydedilirse yarı-uygulanmış bir set canlıya çıkar (bir slider kaydedildi, diğeri kaydedilmedi → akış bozuk). JSON tek satırda tek transaction'da yazılır. Ayrıca bugünkü panel `ayarKaydet()` alanları **tek tek POST ediyor** (`admin.html:996`) — algoritma için bu desen tekrarlanmamalı, tek POST ile tüm set gitmeli.

### 5.2. Yeni uçlar

| Uç | İş | Koruma |
|---|---|---|
| `GET /admin/algoritma` | mevcut ağırlıklar + varsayılanlar + her sinyalin **canlı hacim ölçümü** (P95, kaç gönderiyi etkiliyor, susmuş mu) | nginx `^~ /api/admin` |
| `POST /admin/algoritma` | tüm seti tek seferde kaydet, doğrula, `AYAR_ONBELLEK` sıfırla, `algoritma_gecmis`'e yaz | aynı |
| `GET /admin/algoritma-onizleme?yuzey=kesfet&kullanici=<id>&agirliklar=<json>` | **kaydetmeden** ilk 20 gönderiyi ve her birinin sinyal kırılımını döndür | aynı |
| `POST /admin/algoritma-varsayilan` | fabrika ayarlarına dön | aynı |

**Güvenlik doğrulaması (ölçüldü):** nginx'te blok `location ^~ /api/admin { if ($dizijpg_admin_izinli = 0) { return 404; } ... }`. `^~` **önek** eşleşmesidir — `/api/admin/algoritma`, `/api/admin/algoritma-onizleme` dahil `/api/admin` ile başlayan her yol otomatik kapsanır. `geo $dizijpg_admin_izinli` bugün `127.0.0.1`, `::1` ve `188.119.45.48` izinli. **Yeni uçlar için nginx değişikliği gerekmez.** İkinci kapı `X-Admin-Token` (`server.js:4351`) da otomatik geçerlidir.

⚠️ **Ama dikkat:** önizleme ucu `kullanici=<id>` parametresi alıyor ve bir kullanıcının akışını dışarı veriyor. `alcelik` (id=3) gerçek kullanıcıdır. Bu uç yalnız **id ve skor kırılımı** dönmeli, gönderi metni/medya döndürmemeli — ya da yalnız test hesapları (`testkullanici`, id=1) için çalışmalı. Bu bir mahremiyet kararıdır, kullanıcıya sorulmalı (bkz. 9).

### 5.3. Panelde nasıl görünecek

Yeni sekme: **Algoritma** (Bakım'ın yanına). İki alt sekme: *Akış* / *Keşfet*.

```
┌─ AKIŞ ─────────────────────────────────────────────────────────┐
│  Ana şalter: [●] Algoritma açık    ( kapalıysa: kronolojik )   │
│                                                                 │
│  İLGİ AĞIRLIKLARI                    (toplam 100'e normalize)  │
│  Kitaplığımdaki yapım     [====|-----]  35  →  %35,0           │
│  Takip ettiğim yazar      [===|------]  30  →  %30,0           │
│  Dizi/film popülerliği    [=|--------]  15  →  %15,0           │
│  Yazar kalitesi           [|---------]  10  →  %10,0           │
│  Dilim ile eşleşme        [|---------]  10  →  %10,0           │
│  Beğeni sayısı            [----------]   0  →   %0,0           │
│      🔇 Hacim yetersiz (P95 = 0,0 · 4.736/4.843 gönderi        │
│         hiç beğeni almamış). Eşik: P95 ≥ 3.                    │
│  Yanıt sayısı             [----------]   0  🔇 (7 yanıt var)   │
│  Takip ettiğimin beğendiği[----------]   0  🔇 (20 takip)      │
│                                                                 │
│  ZAMAN VE ÇEŞİTLİLİK                                            │
│  Tazelik yarı ömrü         36 saat     (1 – 8760)              │
│  Tazelik tabanı            0,15        (0 – 0,50)              │
│  Aynı yazar cezası         0,70        (0,10 – 1,00)           │
│  Aynı yapım cezası         0,80                                 │
│  AI hesabı çarpanı         0,60   ← gönderilerin %49,8'i AI    │
│  Spoiler cezası            0,85                                 │
│  Keşif payı                0,10                                 │
│                                                                 │
│  [Kaydet]  [Önizle]  [Varsayılana dön]        Son değişiklik:  │
│                                                3 Ağu 14:02 · IP │
└─────────────────────────────────────────────────────────────────┘

┌─ ÖNİZLEME (kaydedilmedi) ──────────────────────────────────────┐
│ #  Gönderi          Yazar        Skor  Kitaplık Takip Pop Taze │
│ 1  Silo · "..."     alcelik      72,4    35,0   30,0  4,1 0,98 │
│ 2  Dark · "..."     thelostvibe   61,0    35,0    0,0 11,2 0,91 │
│ ...                                                             │
│ Yazar dağılımı: alcelik 4 · dizi.jpg.ai 9 · dizi.jpg 7         │
└─────────────────────────────────────────────────────────────────┘
```

Tasarım kararları ve gerekçeleri:

- **Yanındaki yüzde canlı hesaplanır** — kullanıcı "oran" istedi; slider ham sayı, yüzde gerçek etki.
- **🔇 rozeti ve altındaki ölçülen sayı** — kullanıcının bir slider'ı yükseltip hiçbir şey değişmediğinde kaybolmasını engeller. Rozet, bugünkü canlı P95'i gösterir; eşik aşıldığında kendiliğinden kaybolur.
- **Önizleme kaydetmeden çalışır** — `surumOnizle()` (`admin.html:983`) deseninin aynısı, o desen zaten test edilmiş.
- **Yazar dağılımı satırı** — çeşitlilik ayarının etkisini tek bakışta gösterir; ölçüm (419/458 tek hesap) bunun en kritik gösterge olduğunu söylüyor.
- **Son değişiklik damgası** — `algoritma_gecmis`'ten; Faz 2'de tam geçmiş tablosuna tıklanır.
- Emoji kullanılmayacak, Material ikon (`volume_off`, `history`, `restore`) — proje kuralı (`dizijpg-ux-kontrol` §5). Yukarıdaki 🔇 yalnız bu belgedeki taslak gösterimidir.

**Etkiye geçme süresi:** `POST /admin/algoritma` → `AYAR_ONBELLEK` sıfırlanır → **sonraki istek yeni ağırlıklarla**. Ama devam eden kaydırma oturumları tur tohumu nedeniyle turlarını eski ağırlıkla bitirir (en fazla 10 dk). Panelde bu açıkça yazmalı: *"Yeni ayar hemen geçerli; kaydırmayı sürdüren kullanıcılar en geç 10 dakika içinde görecek."*

### 5.4. Yanlış ayara karşı emniyet

| Risk | Önlem |
|---|---|
| Tüm ağırlıklar 0 | Sunucu reddeder (`400`): "en az bir ağırlık > 0". Ayrıca çalışma anında `Σ = 0` ise varsayılan sete düşülür |
| Yarı ömür 0 veya negatif | Sunucu sınırı `[1, 8760]`; panel `min`/`max` |
| Ceza çarpanı 0 | Sınır `[0,10 , 1,00]` — 0 verilirse o yazarın/yapımın **her** kartı sıfırlanır ve havuz boşalabilir. `ai_carpani` istisna: `[0,00 , 1,00]` (AI'ı tamamen kapatmak meşru bir istek) |
| Aşırı doygunluk cezası havuzu boşaltır | **Güvenli mod:** son sıralı liste 20 karttan azsa ya da ilk 20'de 3'ten az farklı yazar varsa, o istek için bugünkü sıralamaya düşülür ve `/admin/hatalar`'a bir uyarı yazılır |
| Panel dışından ayar yazılması | `AYAR_ANAHTARLARI` beyaz listesi (`server.js:4884`) + nginx IP + `X-Admin-Token` |
| JSON bozuk / bilinmeyen anahtar | Sunucu şemaya göre doğrular; bilinmeyen anahtar **yok sayılır**, eksik anahtar varsayılanla doldurulur |
| Yanlışlıkla kaydetme | "Varsayılana dön" tek tık; `algoritma_gecmis`'ten önceki sete dönüş (Faz 2) |
| **Toptan geri alma** | `algoritma_acik = 0` → **birebir bugünkü kod yolu** (`ORDER BY id DESC` / `kat, id DESC`). 60 sn'lik önbellek sıfırlandığı için etkisi anında. **Dağıtım gerektirmez.** |

---

## 6. Bölüm 5 — Ölçüm ve Doğrulama

### 6.1. Bugün neyi ölçebiliyoruz, neyi ölçemiyoruz

**Ölçebildiklerimiz (altyapı hazır):**

| Metrik | Kaynak | Bugünkü değer |
|---|---|---|
| Kaydırma derinliği (vekil) | `akis_goruldu` satır sayısı / kullanıcı | 695 satır / 36 kullanıcı = **19,3 kart/kullanıcı** |
| Etkileşim oranı (vekil) | `yorum_begeniler` / `akis_goruldu` | 139 / 695 = **%20,0** ⚠️ paydalar farklı dönemleri kapsıyor |
| D1 / D7 tutundurma | `/admin/buyume` (`server.js:4803`) — izleme+yorum+mesaj birleşimi | Panel hazır |
| Günlük aktif (eylem yapan) | `/admin/buyume` `aktifler` | Panel hazır |
| Gönderi başına beğeni (yazar bazında) | `yorum_begeniler ⋈ yorumlar` | 0,018 – 1,25 |
| Push kapsaması | `/admin/buyume` `push` | Panel hazır |

**Ölçemediklerimiz (eklenmesi gerekenler):**

| Metrik | Neden yok |
|---|---|
| Oturum süresi | `kullanicilar.son_gorulme` tek damga; oturum başlangıcı tutulmuyor |
| Kart başına kalış süresi (dwell) | İstemci ölçmüyor |
| Video izlenme oranı (Reels) | İstemci ölçmüyor — Keşfet'in en önemli kalite sinyali |
| Gönderi tıklama oranı | Kayıt yok |
| Paylaşım | `gonderiPaylas` istemcide var, sunucuya gitmiyor |
| Geri dönüş oranı | `son_gorulme` üzerinden kaba tahmin dışında yok |

### 6.2. Önerilen tek ekleme: `akis_olay` tablosu

```sql
CREATE TABLE IF NOT EXISTS akis_olay (
  id           bigserial PRIMARY KEY,
  kullanici_id integer NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  yorum_id     integer REFERENCES yorumlar(id) ON DELETE CASCADE,
  yuzey        text NOT NULL,        -- 'akis' | 'kesfet'
  olay         text NOT NULL,        -- 'goruldu'|'begeni'|'ac'|'paylas'|'gec'|'video_bitti'
  sure_ms      integer,              -- kartta kalış / video izleme süresi
  varyant      text,                 -- A/B grubu
  tarih        timestamptz DEFAULT now()
);
CREATE INDEX ON akis_olay (kullanici_id, tarih DESC);
CREATE INDEX ON akis_olay (tarih);
```

**Ağ maliyeti sıfır:** istemci zaten `POST /akis/goruldu`'yu 1 saniyelik debounce ile toplu gönderiyor (`akis.dart:63–72`). Payload'a `sure_ms` ve `olay` eklenir; yeni istek açılmaz.

**Saklama:** mevcut gecelik temizlik işine (`server.js:1465`) bir satır — 90 gün. Hacim tahmini: 85 aktif kullanıcı × 20 kart/gün ≈ 1.700 satır/gün → 90 günde ~153 bin satır, ~15 MB. Bugünkü 86 MB'lık veritabanı için kabul edilebilir.

**Gizlilik:** kullanıcı bazında davranış kaydı tutuyor. Gizlilik metni gözden geçirilmeli ve gerekirse kullanıcıya kapatma seçeneği sunulmalı. **[DOĞRULANMALI: mevcut gizlilik politikası davranışsal ölçümü kapsıyor mu?]**

### 6.3. A/B testi — dürüst değerlendirme

**Kurulum kolay:** `varyant = (kullanici_id * 2654435761) % 100 < yuzde ? 'B' : 'A'` — deterministik, sunucuda tek satır, `akis_olay.varyant`'a yazılır, panelde `ab_yuzde` ayarı.

**Ama bugün istatistiksel olarak anlamsız.** Ölçüm: 18 kayıtlı kullanıcı, 7 günde aktif 67 hesap (çoğu misafir), toplam 139 beğeni. Etkileşim oranında %20'lik göreli bir farkı %95 güvenle saptamak için yüzey başına binlerce gösterim/kullanıcı gerekir. 18 kullanıcıyı ikiye bölmek 9'a 9 demektir.

**Bu yüzden A/B, Faz 1–2'de bir *ölçüm aracı* değil, bir *emniyet valfi* olarak kurulmalı:** yeni sıralamayı önce %25 kullanıcıya aç, hata oranını (`hatalar` tablosu) ve şikayetleri izle, sorun yoksa %100'e çık. Gerçek karşılaştırma için **öncesi/sonrası aynı kullanıcı** yöntemi (7 gün eski sıralama → 7 gün yeni sıralama, aynı 18 kişi) daha bilgilendiricidir; ve **niteliksel geri bildirim** (`geri_bildirimler` tablosu ve paneli zaten var) bu ölçekte en değerli sinyaldir.

**Ne zaman gerçek A/B?** Haftalık aktif kayıtlı kullanıcı ~500'ü geçince. Bugün 18.

### 6.4. Faz sonu kabul kriterleri

| Faz | Ölçülecek | Kabul |
|---|---|---|
| Faz 1 | `/akis` ve `/kesfet-akis` p95 gecikmesi | Bugünkü değerin (0,79 s / 1,49 s) **üstüne çıkmamalı** |
| Faz 1 | İlk 20 karttaki farklı yazar sayısı (Keşfet) | Bugün 1–2 → hedef **≥ 4** |
| Faz 1 | `akis_olay` satırları akıyor mu | 7 gün sonra > 0, temel çizgi (baseline) kaydedildi |
| Faz 2 | Kart başına ortalama kalış süresi | Faz 1 temel çizgisine göre **artmış** olmalı |
| Faz 2 | Kaydırma derinliği (kart/oturum) | Temel çizgiye göre artmış |
| Faz 3 | Beğeni P95 | ≥ 3 olduğunda etkileşim ağırlıkları otomatik açıldı mı |

**Temel çizgi (baseline) FAZ 1'DEN ÖNCE alınmalı.** Aksi halde algoritmanın işe yarayıp yaramadığı asla bilinemez. Bu, planın en kolay atlanan ve en pahalıya patlayan adımıdır.

### 6.5. Geri alma planı

Üç kademe, hepsi **dağıtımsız**:

1. **Ağırlık geri alma** — panelde "Varsayılana dön" (anında).
2. **Yüzey kapatma** — `algoritma_akis_acik = 0` → o yüzey bugünkü kod yoluna döner, diğeri çalışmaya devam eder.
3. **Toptan kapatma** — `algoritma_acik = 0` → her iki yüzey de bugünkü davranış.

Kod yolu şartı: yeni sıralama, **eski sorguyu silmeden**, `if (!ayar.acik) return eskiSorgu()` biçiminde eklenmelidir. Eski sorgu en az bir faz boyunca kodda kalmalıdır.

---

## 7. Bölüm 6 — Riskler ve İstismar

### 7.1. Beğeni ve görüntülenme şişirme

**Ölçülen açıklar:**

- **Kendi gönderisini beğenme serbest.** `POST /yorumlar/:id/begen` (`server.js:3678`) sahip kontrolü yapmıyor. Bugün **2 kendi-beğenisi** var (139 içinde). Zararsız görünüyor ama beğeni ağırlığı açıldığında tek satırlık bir istismar yolu olur.
- **Misafir hesaplar beğenebiliyor.** 139 beğeninin **29'u** misafir hesaptan. 67/85 hesap misafir; misafir hesap açmak bedava.
- **`goruntulenme` kendi kendini besliyor** — `POST /akis/goruldu` (`server.js:3060`) her gösterimde artırıyor. Sıralamada kullanılırsa algoritmanın gösterdiği şey popülerleşir.

**Önlemler (öncelik sırasıyla):**

| Önlem | Faz |
|---|---|
| `goruntulenme` formüle **hiç** girmesin | Faz 1 (karar) |
| Kendi gönderisine verilen beğeni **skorda sayılmasın** (veri silinmez, sadece skorda hariç) | Faz 1 |
| Misafir hesapların beğenisi **yarı ağırlıkla** sayılsın (`kullanicilar.misafir`) | Faz 2 |
| Beğeni ağırlığı, **tekil beğenen sayısına** göre çalışsın (aynı zaten `COUNT` ile öyle) ve hesap yaşı < 24 saat olanlar sayılmasın | Faz 2 |
| Tek yazarın kendi ağına verdiği beğeniler için tavan | Faz 3 |
| `POST /yorumlar/:id/begen` ucuna sahip kontrolü | Ayrı iş — algoritma dışı ama önerilir |

### 7.2. Küçük topluluk gürültüsü

Bu, bu projedeki **birinci risk**. 139 beğeni, 20 takip, 7 yanıt. Popülerlik sinyali burada bilgi değil, gürültüdür — üstelik zararlı gürültüdür, çünkü 1 beğeni alan bir gönderiyi 0 alan 4.736 gönderinin tamamının önüne koyar.

**Çözüm: hacim eşiği (4.3)** — P95 < 3 ise sinyal susar ve panelde bunu söyler. Bu kural, "kullanıcı istediği için sinyali koyduk ama zarar vermiyor" dengesini kuran mekanizmadır.

**İkinci koruma:** eşik aşıldığında bile ham sayı yerine **oransal** ölçüt kullanılmalı (Wilson alt sınırı ya da beğeni/tekil-görüntüleyen). Bunun için `yorum_goruntuleyen` tablosunun **yeniden beslenmesi** gerekir (bugün ölü, 2.4).

### 7.3. Spoiler ve engelleme kurallarının sırası — **sıralamadan ÖNCE**

Bugünkü mimari doğru kurulmuş ve **bozulmamalı**:

```
1. AKIS_GOVDE   → engelleme (iki yönlü), yasaklı hesap, yanıt elemesi   [SQL WHERE]
2. AKIS_KURAL   → bölüm yorumu uygunluğu (izlenmemiş bölüm HİÇ gelmez)  [SQL WHERE]
3. akis_goruldu → görülmüş elemesi                                       [SQL WHERE]
4. ——— buradan sonrası SIRALAMA ———
5. akisSatiri   → spoiler PERDESİ (istemci bulanıklaştırır)              [yanıt alanı]
```

**Neden skora çevrilmemeli:** engelleme bir tercih değil, bir sınırdır. Skora çevrilirse engellenen kullanıcının gönderisi 50. sırada yine görünür. Aynısı bölüm-spoiler uygunluğu için geçerli: `AKIS_KURAL`'ın ilk dalı, izlenmemiş bölümün yorumunu **tamamen** dışarıda tutuyor — bu bir ceza değil, bir yasaktır.

**Skorda ceza olabilecekler:** `spoiler` işaretli + `guvenli` değil (perde zaten var, ayrıca sıralamada geri düşsün), şikayet edilmiş gönderiler, görülmüş gönderiler (Keşfet 2. turunda).

**Yeni filtre eklenmeli:** `gizli_icerikler` (3 satır) bugün akışta hiç kullanılmıyor. Kullanıcı bir yapımı gizlemişse o yapımın gönderileri de gelmemeli. Bu, algoritmadan bağımsız bir tutarlılık hatasıdır.

### 7.4. Performans riski

**Ölçülen mevcut durum:** `/akis` DB 5,5 ms (uçtan uca 0,64–1,49 s), `/kesfet-akis` DB 51,5 ms (uçtan uca 0,65–0,79 s), `/takvim` 1,67 s.

**Skorlamanın getireceği maliyetler:**

| Değişiklik | Bugünkü etkisi | Ölçek riski |
|---|---|---|
| `/akis`'te `ORDER BY id DESC` erken çıkışının kaybı | 93 satır → 4.843 satır tarama. 5,5 ms → **~50 ms** (Keşfet'in ölçülen değeri, aynı tarama) | Doğrusal. 50 bin gönderide ~500 ms → **kabul edilemez** |
| Node'da 400 adayın skorlanması | < 1 ms | Doğrusal ve ucuz |
| Tur tohumu listesinin bellekte tutulması | ~39 KB/oturum | 100 oturum ≈ 3,9 MB |
| `unnest(medya)` kategori hesabı | `EXPLAIN`'de **4.511 çağrı** | Kalıcı; `medya_kat` kolonu ile çözülür |

**Eşik ve tetikleyici — açıkça yazılıyor:**

> Gönderi sayısı **25.000'i** geçtiğinde (bugün 4.843; günde ~85 → yaklaşık **8 ay**), aday havuzu tarihe göre pencerelenmeli (`tarih > now() - interval '90 days'` + arşiv için ayrı kota) ve kullanıcıdan bağımsız taban skor gecelik bir tabloya (`gonderi_skor`) materyalize edilmelidir. Bu iş **Faz 3'e planlanmalı, hacim gelince acele edilmemelidir.**

**`/takvim` dersi:** görev tanımında `/takvim`'in 15 sn sürüp bir hataya yol açtığı belirtilmiş; bugünkü ölçüm 1,67 s. Ders şu: **yeni uç, dağıtımdan önce `curl` ile ölçülmeden canlıya çıkmamalı.** Faz 1'in dağıtım adımına zorunlu bir gecikme ölçümü konulmalıdır (kabul kriteri 6.4).

### 7.5. Diğer riskler

| Risk | Etki | Önlem |
|---|---|---|
| Sayfalama regresyonu (eski istemciler) | 🔴 Akış tamamen kırılır | Eski imleç biçimleri (`?once=<id>`, `<tur>:<kat>:<id>`) tanınmaya devam etmeli — **zorunlu** |
| Arşiv içeriğin gömülmesi | 🔴 Keşfet'in %45'i ve videoların %91,5'i kaybolur | `taban_tazelik` + `eklenme` kolonu (4.2) |
| AI hesabının akışı ele geçirmesi | 🟡 Gönderilerin %49,8'i | `ai_carpani` slider'ı |
| Filtre balonu (kitaplık ağırlığı yüksek) | 🟡 Kullanıcı hep aynı 5 diziyi görür | `kesif_payi` kotası |
| Ölçüm olmadan ayar yapmak | 🔴 "Daha iyi mi oldu?" sorusu cevapsız kalır | `akis_olay` + temel çizgi, Faz 1'in **ilk** maddesi |
| Skorun istemci önbelleğiyle çelişmesi | 🟡 Kullanıcı eski sırayı görüp yenilenince zıplama yaşar | İstemcide "yenilendi" göstergesi; tur tohumu zaten yumuşatır |

---

## 8. Bölüm 7 — Fazlı Yol Haritası

Her madde: **(a) beklenen etki · (b) iş yükü · (c) risk · (d) uygulama adımı.**

### FAZ 1 — Temel: ölç, motoru kur, çeşitliliği düzelt (≈ 4–6 gün)

#### 1.1. Ölçüm altyapısı ve temel çizgi 🔴 **İLK İŞ**

- **(a) Etki:** Kritik ve dolaylı. Bu olmadan sonraki hiçbir maddenin işe yarayıp yaramadığı bilinemez. Bugün elde kart başına kalış süresi, video izlenme oranı, oturum derinliği **yok**.
- **(b) İş yükü:** 1 gün (migrasyon + uç + istemcide mevcut debounce'a alan ekleme + gecelik temizliğe satır).
- **(c) Risk:** Düşük. Yeni tablo, mevcut akışa dokunmuyor. Tek dikkat: gizlilik metni.
- **(d) Adım:**
  1. `akis_olay` tablosu (6.2) — migrasyon dosyası + `sema.sql` + canlıya uygulama (proje kuralı: migrasyonsuz `server.js` başlatılmaz).
  2. `POST /akis/goruldu` gövdesine `sure_ms` ve `yuzey` alanları; uç geriye uyumlu kalmalı (eski istemciler sadece `idler` gönderir).
  3. `akis.dart` ve `kesfet_akis.dart`'ta kart görünürlük süresi ölçümü — mevcut `_goruldu` debounce'una biner, **yeni ağ isteği açılmaz**.
  4. Gecelik temizlik: `DELETE FROM akis_olay WHERE tarih < now() - interval '90 days'`.
  5. **7 gün veri topla, temel çizgiyi kaydet.** Faz 1.2 bundan önce canlıya çıkmamalı.

#### 1.2. Ağırlık motoru + admin sekmesi (kapalı şalterle) 🔴

- **(a) Etki:** Kullanıcının doğrudan istediği şey. Motor kurulur, panel gelir, ama `algoritma_acik = 0` ile canlıya çıkar → davranış değişmez, risk sıfır.
- **(b) İş yükü:** 2–3 gün.
- **(c) Risk:** Düşük (şalter kapalı). Asıl risk sayfalama refactor'ünde; şalter kapalıyken eski yol birebir korunur.
- **(d) Adım:**
  1. `server.js`'e `algoritmaAyarlari()` — `ayarlariGetir()` üzerine JSON çözümleyici + şema doğrulama + varsayılan birleştirme.
  2. `AYAR_ANAHTARLARI`'na `algoritma_acik`, `algoritma_akis`, `algoritma_kesfet` ekle; `POST /admin/ayar`'daki 500 karakter sınırını algoritma anahtarları için yükselt.
  3. `skorla(gonderi, kullanici, ayar)` saf fonksiyon (4.1 formülü) — **yan etkisiz**, çünkü hem uç hem önizleme aynı fonksiyonu çağıracak.
  4. Tur tohumu + LRU önbellek + **iki yönlü imleç uyumu** (yeni `<tohum>:<offset>`, eski `?once=<id>` ve `<tur>:<kat>:<id>`).
  5. `GET/POST /admin/algoritma`, `GET /admin/algoritma-onizleme` (5.2). nginx değişikliği **gerekmiyor** (`^~ /api/admin` doğrulandı).
  6. `admin.html`'e Algoritma sekmesi (5.3) — Bakım sekmesindeki `ayarKaydet`/`surumOnizle` deseni.
  7. Ölçüm: dağıtım sonrası `curl` ile her iki uç, **şalter açıkken ve kapalıyken** — p95 bugünkü değeri geçmemeli.

#### 1.3. Çeşitlilik ve AI dengesi — şalteri Keşfet'te aç 🔴

- **(a) Etki:** **Bu fazın en görünür kazancı.** Ölçüm: Keşfet'in ilk 458 kartının 419'u tek hesaptan (%91,5), gönderilerin %49,8'i AI. Yazar doygunluk cezası + AI çarpanı, ilk 20 karttaki farklı yazar sayısını 1–2'den ≥ 4'e çıkarır.
- **(b) İş yükü:** 0,5 gün (motor 1.2'de kuruldu; burada yalnız Keşfet şalteri + varsayılan ayarlar).
- **(c) Risk:** Orta. Havuz boşalabilir → **güvenli mod** (5.4) şart. Arşiv içerik gömülebilir → `taban_tazelik = 0,15`.
- **(d) Adım:** `algoritma_kesfet_acik = 1`, 4.4'teki Keşfet varsayılanları, `yazar_doygunluk = 0,50`. 48 saat izle: `hatalar` tablosu, `akis_olay` kalış süresi, geri bildirimler.

#### 1.4. `icerik_dizini` kapsamasını tamamla 🟡

- **(a) Etki:** Yüksek. "Dizi/film popülerliğine göre öne çıksın" isteği bugün gönderilerin yalnız **%16,4'ünde** çalışabilir (407/2.479 yapım). Doldurulunca %100 olur.
- **(b) İş yükü:** 0,5 gün.
- **(c) Risk:** Düşük. 2.072 eksik yapım × 1 TMDB çağrısı; 8'li paralel öbekler (proje kuralı) → birkaç dakika.
- **(d) Adım:** Gecelik iş: gönderilerdeki `DISTINCT (tur, tmdb_id)` çiftlerinden dizinde olmayanları TMDB'den çek, `server.js:3882`'deki mevcut `INSERT ... ON CONFLICT` ile yaz. Aynı iş `populerlik` değerlerini de tazeler.

#### 1.5. Akış şalterini aç 🟡

- **(a) Etki:** Orta–yüksek. Kitaplık + takip ağırlıklarıyla akış kişiselleşir.
- **(b) İş yükü:** 0,5 gün.
- **(c) Risk:** Orta. `/akis`'in erken çıkışı kaybolur (5,5 ms → ~50 ms; ölçülü ve kabul edilebilir). Sayfalama en kritik nokta — 1.2'deki imleç uyumu burada sınanır.
- **(d) Adım:** `algoritma_akis_acik = 1`. **Zorunlu kanıt:** test hesabıyla 5 sayfa uçtan uca `curl`, dönen id'lerde tekrar/atlama olmadığı doğrulanacak. Eski sürüm uygulamayla (imleçsiz istemci) da denenecek.

**Faz 1 sonunda ölçülecek:** ilk 20 karttaki farklı yazar sayısı; `/akis` ve `/kesfet-akis` p95 gecikmesi; kart başına kalış süresi (temel çizgiye göre); `hatalar` tablosunda yeni hata var mı.

---

### FAZ 2 — Zenginleştirme ve dürüstlük (≈ 4–5 gün)

#### 2.1. `eklenme` kolonu ve gerçek tazelik 🟡

- **(a) Etki:** Yüksek. Arşiv gönderileri (2.184 adet, %45,1) bugün 5–8 yıl eski tarihli görünüyor; `eklenme` ayrımı olmadan tazelik knob'u yalan söylüyor.
- **(b) İş yükü:** 0,5 gün.
- **(c) Risk:** Düşük. Yeni kolon, `DEFAULT now()`; geçmiş satırlar için `eklenme = tarih` (ya da aktarım tarihine set) — **[DOĞRULANMALI: aktarımın gerçek tarihi hangi kaynaktan alınabilir?]**
- **(d) Adım:** Migrasyon + `sema.sql`; skorda `T(now() - eklenme)`, gösterimde `tarih` kalır.

#### 2.2. Materyalize taban skor + `medya_kat` kolonu 🟡

- **(a) Etki:** Orta bugün, kritik 8 ay sonra. Ölçüm: `unnest(medya)` `EXPLAIN`'de **4.511 kez** çalışıyor.
- **(b) İş yükü:** 1 gün.
- **(c) Risk:** Düşük–orta (gecelik iş başarısız olursa skorlar bayatlar → son başarılı zamanı panelde göster).
- **(d) Adım:** `yorumlar.medya_kat smallint` (yazarken doldurulur, geçmiş satırlar tek seferde) + gecelik `gonderi_taban_skor` (yazar kalitesi, içerik popülerliği, P95 değerleri).

#### 2.3. Değişiklik geçmişi + güvenli mod göstergeleri 🟢

- **(a) Etki:** Orta. Kullanıcı "kim ne zaman değiştirdi" istedi.
- **(b) İş yükü:** 0,5 gün.
- **(c) Risk:** Düşük.
- **(d) Adım:** `algoritma_gecmis` tablosu (5.1); panelde geçmiş listesi + "bu sürüme dön"; güvenli moda düşen istek sayısı paneldeki bir sayaçta.

#### 2.4. `gizli_icerikler` filtresi ve `yorum_goruntuleyen`'i canlandır 🟢

- **(a) Etki:** Orta. Biri tutarlılık hatası düzeltmesi, diğeri oransal etkileşim ölçütünün ön koşulu.
- **(b) İş yükü:** 0,5 gün.
- **(c) Risk:** Düşük.
- **(d) Adım:** `AKIS_GOVDE`'ye `NOT EXISTS (gizli_icerikler)`; `POST /akis/goruldu` içinde `yorum_goruntuleyen`'e `ON CONFLICT DO NOTHING` yazımı (ölü tablo tekrar beslenir).

#### 2.5. `kadroKisileri()` önbelleği 🟢

- **(a) Etki:** Orta–yüksek gecikmede. Her `/akis` ve `/kesfet-akis` isteğinde 20 TMDB `/credits` çağrısı yapılıyor.
- **(b) İş yükü:** 0,5 gün.
- **(c) Risk:** Düşük (kullanıcı yeni bir şey izleyince 10 dk gecikmeyle yansır).
- **(d) Adım:** Kullanıcı başına 10 dakikalık bellek önbelleği; `emojiBenimOnbellek` (`server.js:2929`) deseninin aynısı.

#### 2.6. Etkileşim sinyallerini hazır et (susmuş halde) 🟢

- **(a) Etki:** Bugün sıfır, yarın yüksek.
- **(b) İş yükü:** 0,5 gün.
- **(c) Risk:** Düşük.
- **(d) Adım:** `begeni`, `yanit`, `takip_begendi` hesapları koda girsin; hacim eşiği (4.3) onları otomatik sustursun; panelde canlı P95 rozeti göstersin. Kendi-beğenisi ve misafir beğenisi ağırlıkları burada uygulanır (7.1).

**Faz 2 sonunda ölçülecek:** `/akis` p95 gecikmesi (2.5 sonrası **düşmüş** olmalı); tazelik knob'unun gerçekten arşivi ayırt ettiği (Keşfet ilk 20'de 2026 gönderi oranı); geçmişten geri dönüşün çalıştığı.

---

### FAZ 3 — Ölçekleme ve gerçek kişiselleştirme (hacim geldiğinde)

**Tetikleyici eşikler — tarih değil, sayı:**

| İş | Tetikleyici |
|---|---|
| 3.1. Etkileşim ağırlıklarını aç | Beğeni **P95 ≥ 3** |
| 3.2. Gerçek A/B testi | Haftalık aktif kayıtlı kullanıcı **≥ 500** (bugün 18) |
| 3.3. Aday havuzu pencereleme + `gonderi_skor` materyalizasyonu | Gönderi **≥ 25.000** (bugün 4.843, ~8 ay) |
| 3.4. Sosyal graf sinyalleri (takip ettiğinin beğendiği, 2. derece) | Takip ilişkisi **≥ 500** (bugün 20) |
| 3.5. Tür (genre) profili ve içerik benzerliği | Puan **≥ 1.000** (bugün 37) |
| 3.6. "İlgilenmiyorum" düğmesi + negatif geri bildirim | Kullanıcı talebi ya da şikayet hacmi |

Her biri: (b) 1–2 gün, (c) düşük–orta, (d) motor zaten kurulu olduğu için yalnız sinyal ekleme + panele slider.

---

### 8.1. Özet Tablo — Ne, Ne Zaman, Ne Kadar

| # | İş | Faz | Etki | İş yükü | Risk |
|---|---|---|---|---|---|
| 1.1 | `akis_olay` + temel çizgi ölçümü | Faz 1 | 🔴 Kritik (ön koşul) | 1 gün | Düşük |
| 1.2 | Ağırlık motoru + admin sekmesi (şalter kapalı) | Faz 1 | 🔴 Kritik | 2–3 gün | Düşük |
| 1.3 | Çeşitlilik + AI çarpanı — Keşfet şalteri | Faz 1 | 🔴 **En görünür kazanç** | 0,5 gün | Orta |
| 1.4 | `icerik_dizini` kapsamasını %16,4 → %100 | Faz 1 | 🟡 Yüksek | 0,5 gün | Düşük |
| 1.5 | Akış şalterini aç | Faz 1 | 🟡 Orta–yüksek | 0,5 gün | Orta |
| 2.1 | `eklenme` kolonu — gerçek tazelik | Faz 2 | 🟡 Yüksek | 0,5 gün | Düşük |
| 2.2 | `medya_kat` + gecelik taban skor | Faz 2 | 🟡 Orta (ölçekte kritik) | 1 gün | Düşük–orta |
| 2.3 | Değişiklik geçmişi + güvenli mod sayacı | Faz 2 | 🟢 Orta | 0,5 gün | Düşük |
| 2.4 | `gizli_icerikler` filtresi + `yorum_goruntuleyen` | Faz 2 | 🟢 Orta | 0,5 gün | Düşük |
| 2.5 | `kadroKisileri()` önbelleği | Faz 2 | 🟡 Orta–yüksek (gecikme) | 0,5 gün | Düşük |
| 2.6 | Etkileşim sinyalleri (susmuş, hazır) | Faz 2 | 🟢 Bugün 0, yarın yüksek | 0,5 gün | Düşük |
| 3.1 | Etkileşim ağırlıklarını aç | P95 ≥ 3 | 🔴 Yüksek | 0 (otomatik) | Orta |
| 3.2 | Gerçek A/B | HAK ≥ 500 | 🟡 Orta | 1 gün | Düşük |
| 3.3 | Havuz pencereleme + materyalizasyon | ≥ 25k gönderi | 🔴 Kritik (o zaman) | 2 gün | Orta |
| 3.4 | Sosyal graf sinyalleri | ≥ 500 takip | 🟡 Yüksek | 1–2 gün | Orta |
| 3.5 | Tür profili / içerik benzerliği | ≥ 1.000 puan | 🟢 Orta | 2 gün | Orta |

**Faz 1 toplam ≈ 4,5–5,5 adam-günü. Faz 2 ≈ 3,5 adam-günü.**

---

## 9. Bölüm 8 — Açık Sorular

### 9.1. Ürün kararları (kullanıcının vermesi gereken)

1. **Akış kronolojik mi kalsın, tamamen algoritmik mi olsun, yoksa kullanıcıya seçenek mi sunulsun?**
   Bugün akış saf kronolojik ve istemcide "Kronolojik / Önerilen" seçeneği yok. Üç yol var: (a) tamamen algoritmik — en basit, en güçlü, ama "yeni gönderiyi kaçırdım" şikayeti gelir; (b) kullanıcıya sekme — dürüst, ama 45 dile 2 yeni metin ve iki ayrı önbellek yolu demek; (c) karma — ilk N kart kronolojik, sonrası algoritmik. **Bu karar planın geri kalanını en çok etkileyen tek karardır.**

2. **AI hesabı (`dizi.jpg.ai`, gönderilerin %49,8'i) akışta ne kadar yer almalı?**
   Varsayılan olarak `ai_carpani = 0,60` önerildi ama bu tamamen ürün kararı. 0'a çekilirse akış %50 küçülür; 1,0'da bugünkü haliyle kalır. **Bu tek slider muhtemelen panelin en etkili düğmesidir.**

3. **Arşiv içerik (2.184 gönderi, %45,1, 2017–2021 tarihli, videoların %91,5'i) akışta birinci sınıf mı, arka plan mı?**
   Tazelik tabanı 0,15 önerildi — arşiv görünür kalır ama geri düşer. 0 seçilirse Keşfet'in video havuzu neredeyse boşalır. 0,5 seçilirse arşiv güncel içerikle yarışır. Bu, "dizi.jpg bir arşiv hesabı mı, güncel bir topluluk mu" sorusunun teknik karşılığıdır.

4. **Beğeni sinyali bugün hiç varyansı olmamasına rağmen (P95 = 0) yine de açılsın mı?**
   Öneri: motorda olsun, hacim eşiğiyle sussun, panelde nedeni yazsın. Kullanıcı "hayır, ben yine de açık istiyorum" derse eşik kapatılabilir — ama sonuç, 86 gönderinin 4.757'nin önüne geçmesidir.

5. **Ağırlıklar tüm kullanıcılar için tek mi, kullanıcı başına özelleştirilebilir mi?**
   Bu plan tek global set varsayıyor (istek buydu). İleride kullanıcıya "daha çok takip ettiklerim / daha çok keşif" gibi bir tercih verilecek mi?

6. **Önizleme ucu gerçek kullanıcıların akışını gösterebilir mi?**
   `/admin/algoritma-onizleme?kullanici=<id>` mahremiyet sınırında. Yalnız test hesapları mı, yoksa id + skor kırılımı (metin/medya yok) mı dönmeli?

7. **Davranışsal ölçüm (`akis_olay`: hangi kart kaç saniye izlendi) gizlilik politikasına uygun mu, kullanıcıya kapatma seçeneği sunulmalı mı?**

### 9.2. Doğrulanamayanlar

- **[DOĞRULANMALI: `/takvim`'in 15 sn'lik ölçümü hangi koşulda alınmıştı?]** Bugün 1,67 s ölçüldü; soğuk TMDB önbelleğinde farklı olabilir.
- **[DOĞRULANMALI: `akis.dart` satır numaraları]** — bu oturumda iki ajan daha aynı dosyada çalışıyor; uygulama anında yeniden doğrulanmalı.
- **[DOĞRULANMALI: `kullanicilar.ulke` ve `olusturma` doluluk oranları]** — yerellik ve hesap yaşı sinyalleri için ölçülmedi.
- **[DOĞRULANMALI: karşılıklı takip çifti sayısı]** — 20 kenarlı grafta ölçülmedi.
- **[DOĞRULANMALI: gönderi metin uzunluğu ve medya adedi dağılımı]** — medya kalitesi sinyalleri için ölçülmedi.
- **[DOĞRULANMALI: arşiv aktarımının gerçek tarihi]** — `eklenme` kolonunun geçmiş satırları için hangi değer kullanılacak?
- **[DOĞRULANMALI: `POST /admin/ayar`'daki 500 karakter sınırı JSON ağırlık setini kesecek mi]** — set büyüklüğü ~400–600 karakter arası; sınır yükseltilmeli.
- **[DOĞRULANMALI: eski sürüm uygulamaların dağılımı]** — `/admin/surumler` cihaz dağılımını veriyor; imleç geriye uyumunun ne kadar süre korunması gerektiği buna bağlı.

---

## 10. Ölçüm Komutlarının Özeti (yeniden üretilebilirlik)

Bu belgedeki tüm sayılar aşağıdaki yolla alındı; hepsi **salt okunur**:

```bash
# Veri hacmi
ssh root@154.53.163.3 "cd /opt/dizijpg && docker-compose exec -T db \
  psql -U dizijpg -d dizijpg -c \"SELECT count(*) FROM yorumlar WHERE ust_id IS NULL;\""

# Sorgu maliyeti (EXPLAIN ANALYZE — /akis ve /kesfet-akis gövdeleri, kullanici 3)
... | psql -U dizijpg -d dizijpg   < alg_explain.sql

# Uçtan uca gecikme
curl -s -o /dev/null -w "%{time_total}s %{size_download}b\n" \
  https://dizijpg.com/api/akis -H "Authorization: Bearer <token>"
```

Canlı veritabanına **hiçbir yazma yapılmamıştır**; kullanılan tek DDL/DML `EXPLAIN` ve `SELECT`'tir.
