# dizi.jpg — LLM Fırsatları

> Tarih: 2026-08-07 · Kaynak depo: [Shubhamsaboo/awesome-llm-apps](https://github.com/Shubhamsaboo/awesome-llm-apps) (Apache-2.0)
> Yöntem: önce proje kodu + canlı veritabanı ölçüldü, sonra depo tarandı. Model
> kimlikleri ve fiyatlar `claude-api` skill'inden alındı (2026-06-24 önbelleği),
> hafızadan yazılmadı.

---

## 0. Ölçüm — bu belgenin dayandığı gerçekler

Canlı sunucuda (`154.53.163.3`, `dizijpg-db`) ölçüldü, 2026-08-07:

| Şey | Değer |
|---|---|
| Kullanıcı | **94** |
| Gönderi (`yorumlar`) | **4.858** — bunun **2.411**'i AI hesabı (id=51), 2.447'si gerçek kullanıcı |
| AI metin hacmi | **1.533.617 karakter** TR (ortalama 636 kr/inceleme) |
| Kullanıcı metin hacmi | **121.140 karakter** (AI'ın %8'i) |
| Yazılı inceleme (`puanlar.yorum`) | **11** |
| Bölüm izleme kaydı | **44.372** |
| Durum kaydı (`durumlar`) | **2.451** |
| Liste | **2** |
| Mesaj (`mesajlar`) | **87** |
| `icerik_dizini` | **2.024** başlık (ad, orijinal_ad, populerlik — tür/özet YOK) |
| `tmdb_onbellek` | **5.978 satır / 76 MB** — 1.776 dizi + 1.180 film TAM detay (`?language=tr-TR&append_to_response=credits,videos,recommendations,external_ids,watch/providers`) |
| `metin_cevirileri` | 7.836 satır (en=4.721, tr=3.114, es=1) |
| DB boyutu | 103 MB |

**pgvector: KURULU DEĞİL — hatta *kurulabilir* de değil.**
```
$ docker exec dizijpg-db psql -U dizijpg -d dizijpg -tAc \
    "SELECT name,default_version,installed_version FROM pg_available_extensions
     WHERE name IN ('vector','pg_trgm','unaccent','pg_bigm');"
pg_trgm  | 1.6 | 1.6
unaccent | 1.1 | -
```
`vector` `pg_available_extensions`'ta hiç görünmüyor. Sebep: imaj
`postgres:16-alpine` (`docker-compose.yml:4`), pgvector içermiyor.
`pgvector/pgvector:pg16`'ya geçmek gerekirdi ve bu **bedava değil**: alpine
(musl) → debian (glibc) geçişinde `collation` değişir, metin indeksleri (senin
`icerik_dizini_trgm` GIN'in dahil) sessizce bozulabilir.
**[DOĞRULANMALI: aynı PGDATA hacmiyle imaj değiştirildiğinde `REINDEX`
gerekip gerekmediği — yedekten dönüşlü bir stajda denenmeli.]**
Aşağıdaki önerilerin **hiçbiri pgvector gerektirmiyor**; §6 (Öneri 5) bunu neden
gerektirmediğini sayıyla gösteriyor.

**Donanım (ölçüldü, kullanıcının hatırladığından farklı):** `free -g` → **131 GB
RAM**, `nproc` → **16 çekirdek**. Kullanıcı 35 GB sanıyordu. Yerel model
çalıştırmak için bol yer var; `whisper.cpp` zaten host'ta CPU'da koşuyor
(`backend/araclar/altyazi_uret.js`), yani "sunucuda ML" bu projede yeni bir şey değil.

**Kodda bugün HİÇ LLM sağlayıcısı yok.** `grep -rniE 'anthropic|openai|claude|gemini|
langchain|ollama|mistral|cohere'` → yalnız `whisper` (altyazı) ve `CLAUDE.md`
referansları çıkıyor. Çeviri bile ücretsiz/gayriresmi
`translate.googleapis.com/translate_a/single` ucundan yapılıyor
(`araclar/altyazi_uret.js:213`, `server.js` `metniCevir`). Yani bu belgedeki her
öneri **yeni bir bağımlılık** demek.

---

## 1. Depo hakkında dürüst çerçeve

Depodaki **her örnek Python + Streamlit**. Hiçbiri Node/Express değil, hiçbiri
`pg_trgm` kullanmıyor, Postgres'e dokunan iki örnek de pgvector kullanıyor.
Yani buradan **kod taşınmıyor, kalıp taşınıyor.** Ayrıca:

- Depoda **hiç öneri motoru / sıralama-akış örneği yok.** `siralama.js`'e
  buradan gelecek yardım yok (aramada "recommendation" geçen tek şey
  `ai_movie_production_agent` — o da bir film *yapım* ajanı, katalog önerisi değil).
- Depoda dizi/film/medya **katalog** örneği yok.

Aşağıdaki 5 öneri, depodan **dört kalıp** alıyor: hibrit getirme→yeniden sıralama,
güven-kademeli yönlendirme, LLM-hakem kapısı, ve aramanın kendisini kişiselleştirme
sinyaline çevirme.

---

## 2. ÖNERİ 1 — Doğal dil arama ("karanlık atmosferli, kısa bölümlü Nordic dizi")

### 1. Ne
Arama kutusuna başlık değil **tarif** yazılabilsin. `/ara` bugün üç aşamalı:
TMDB `search/multi` varyantları → sonuç yoksa `pg_trgm` yazım toleransı → boş.
Dördüncü aşama eklenir: sorgu bir başlık gibi durmuyorsa (kelime sayısı ≥ 3,
TMDB sonucu 0, trigram benzerliği düşük) **Claude sorguyu TMDB `/discover`
parametrelerine çevirir** — `with_genres`, `with_origin_country`,
`with_runtime.lte`, `first_air_date.gte`, `vote_average.gte`, `with_keywords`.

**Kritik tasarım kararı: model ASLA başlık üretmez, yalnız SÜZGEÇ üretir.**
Sonuçlar TMDB'den gelir. Bu, halüsinasyon riskini yapısal olarak sıfırlar —
model uydurma bir dizi adı döndüremez, çünkü çıktısı bir dizi adı değil.

### 2. Depodaki karşılığı
- **[`rag_tutorials/rag_database_routing`](https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/rag_tutorials/rag_database_routing)** — *güven kademesi*: önce ucuz/deterministik yol, ambiguity varsa LLM yönlendirici, o da yetmezse dış arama. **Alınan:** kademe mantığı. **Alınmayan:** Qdrant, LangGraph, üç ayrı koleksiyon.
- **[`rag_tutorials/hybrid_search_rag`](https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/rag_tutorials/hybrid_search_rag)** — *geniş getir → yeniden sırala → üret* ve **zarif düşüş** (hiçbir belge çıtayı geçmezse boş dönmek yerine genel bilgiyle cevapla). **Alınan:** düşüş davranışı — LLM aşaması hata verirse `/ara` bugünkü davranışına döner. **Alınmayan:** RAGLite, Cohere reranker, OpenAI embedding.

### 3. Bizim koda nasıl oturur
- **Değişen dosya:** `backend/server.js` → `app.get('/ara', ...)` (satır ~5010). Mevcut `duzeltme` dalının yanına `if (!results.length && dogalDilGibi(q))` dalı.
- **Yeni yardımcı:** `backend/dogal_dil_ara.js` — saf fonksiyon (siralama.js gibi test edilebilir): sorgu → tool-use şeması → `/discover` sorgu dizesi. `node --test` ile birim testi yazılabilir.
- **Yeni tablo:** `dogal_dil_onbellek (sorgu_ozet TEXT PRIMARY KEY, parametreler JSONB, guncelleme TIMESTAMPTZ)` — `md5(lower(btrim(sorgu)))`. `metin_cevirileri`'nin birebir aynı kalıbı (özet→sonuç), maliyeti ezen şey bu.
- **Yeniden kullanılan:** `tmdbGetir()` + `tmdb_onbellek` (discover sonuçları da önbelleğe düşer), `icerikDizineEkle()` (sonuçlar dizini besler), `aramaLimiti` (hız sınırı zaten var), `X-Dil` başlığı.
- **Gerekmeyen:** pgvector, embedding, vektör deposu, yeni servis.

### 4. Maliyet
- **İş yükü:** ~2 adam-günü (uç + şema + önbellek tablosu + birim testleri + `dizijpg-ux-kontrol` listesi + 45 dil çevirisi: "Aramanı anladım: …" satırı).
- **Model:** **`claude-haiku-4-5`** ($1 / $5 per MTok). Gerekçe: iş bir *sınıflandırma + şema doldurma*, akıl yürütme değil; `strict: true` tool-use ile şema garantili. Opus 5 ($5/$25) burada 5 kat pahalıya aynı işi yapar.
- **İstek başı:** ~2K girdi (tür kimlik listesi + şema + sorgu) + ~150 çıktı ≈ **$0,0028**.
  ⚠️ **Prompt caching bu modelde İŞE YARAMAZ:** Haiku 4.5'in asgari önbelleklenebilir öneki **4.096 token**; 2K'lık istem bunun altında kalır ve sessizce önbelleğe girmez. Önbellek istiyorsan `claude-sonnet-5` (asgari 1.024 token) gerekir — ama o zaman istek başı ~$0,0055 (giriş fiyatı $2/$10 **31 Ağu 2026'ya kadar**, sonra $3/$15).
- **Bugünkü ölçek:** 94 kullanıcı, arama çoğunlukla başlıkla yapılıyor → LLM dalı belki günde 20-30 kez tetiklenir → **ayda < $3**.
- **Ölçekle nasıl büyür:** 10.000 kullanıcı × günde 3 doğal dil araması = 30.000 çağrı/gün = **$84/gün**. Bu duvarı yıkan tek şey `dogal_dil_onbellek`: doğal dil sorguları uzun kuyruklu ama tekrarlıdır ("korku dizisi", "kısa bölümlü komedi"). **[DOĞRULANMALI: gerçek tekrar oranı — canlıya çıkınca ilk 1.000 sorgunun benzersizlik oranı ölçülmeli.]** Kabaca %60 önbellek isabetiyle $34/gün.

### 5. Risk
- **Halüsinasyon: yapısal olarak yok.** Model başlık üretmiyor. En kötü senaryo yanlış tür süzgeci → alakasız ama *gerçek* sonuçlar.
- **Gecikme:** +0,8-1,5 sn. Ama **yalnız bugün boş dönen sorgularda** çalışır; normal başlık araması hiç dokunulmadan kalır. Bu, `dizijpg-ux-kontrol`'ün "regresyon yaratma" kuralına uyar.
- **Kişisel veri: YOK.** Modele giden tek şey sorgu metni. İzleme geçmişi, kullanıcı adı, DM — hiçbiri gitmiyor. Bu öneri kişisel veri sınırının **dışında** kalır; §5'teki öneri kalmaz.
- **Google ölçekli içerik:** ilgisiz — bu bir arama davranışı, üretilen sayfa yok.
- **Yeni bağımlılık:** `@anthropic-ai/sdk` (`backend/package.json`), `ANTHROPIC_API_KEY` (`.env`, depoya girmemeli — CLAUDE.md kural 9). API anahtarı düşerse uç sessizce bugünkü davranışa düşmeli, 500 dönmemeli.

### 6. Neden şimdi / neden şimdi değil
**Şimdi değil.** 94 kullanıcıyla doğal dil arama yapan kişi sayısı muhtemelen sıfıra
yakın. `YAPILACAKLAR.md`'nin kendi tespiti: en büyük ürün boşluğu *katalog gözat*
(bu yapıldı), arama değil. Bu öneri "kullanıcı sayısı üç haneye çıkınca" işidir.
Yine de **maliyeti en düşük, riski en düşük** öneri — bir hafta sonu işi olarak
istendiği anda yapılabilir.

---

## 3. ÖNERİ 2 — İnceleme korpusunun LLM-hakem denetimi + bölüm bazlı genişletme

### 1. Ne
İki parça, birincisi ikincisinin ön koşulu:

**(a) Mevcut 2.400 incelemenin denetimi.** Bu metinler 40 paralel Claude Code
ajanıyla yazıldı (`YAPILACAKLAR.md`, Parti 1-5) ve **hiç sistematik olarak
denetlenmediler**. Her biri için bir hakem çağrısı: *spoiler var mı? TMDB özetinin
yeniden yazımı mı? Tanınmayan yapımda uydurma oyuncu/ödül iddiası var mı?*
Çıktı: `{spoiler: bool, ozgunluk: 1-5, uydurma_iddia: bool, gerekce: string}`.
Başarısızlar bir listeye düşer, elle bakılır ya da yeniden üretilir.

**(b) Bölüm bazlı incelemeler.** `SEO-PLANI.md` §2.3.2'nin kendi maddesi:
"Bölüm bazlı incelemeler ekle (1.3'teki bölüm sayfalarını besler ve uzun kuyruğu
doldurur)." `yorumlar` tablosunda `sezon`/`bolum` kolonları **zaten var** ve
`/og/dizi/:id/sezon/:sezon/bolum/:bolum` SSR ucu **zaten yazılmış**. Yani altyapı
hazır, içerik yok.

### 2. Depodaki karşılığı
- **[`rag_tutorials/corrective_rag`](https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/rag_tutorials/corrective_rag)** — *LLM-hakem üretimden önce kapı*: getir → alaka notu ver → zayıfsa sorguyu yeniden yaz → yine olmazsa dış aramaya düş. **Alınan:** grafiğin şekli — hakem "alakalı mı" yerine "spoiler içeriyor mu" puanlar, başarısız not yeniden *üretimi* tetikler. **Alınmayan:** LangGraph, Qdrant, Tavily.
- **[`advanced_ai_agents/single_agent_apps/ai_customer_support_agent`](https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/advanced_ai_agents/single_agent_apps/ai_customer_support_agent)** — içindeki **sentetik veri üreteci**, ajanın kendisinden daha değerli: şablonlu üretim → tekilleştirme → sakla. `ai_tohum.js` zaten bu boruhattının son iki adımı. **Alınmayan:** Mem0, Qdrant, müşteri destek senaryosu.

### 3. Bizim koda nasıl oturur
- **Değişmeyen:** `ai_tohum.js` — girdi biçimi (`{tur, tmdb_id, ad, tr, en}`) aynı kalır, dHash tekrar süzgeci ve kare indirme aynen çalışır. Bu önemli: o dosya acı çekilerek doğru hale getirildi, dokunulmamalı.
- **Yeni dosya:** `backend/araclar/ai_metin_denetle.js` — `ai_yorumlar.json` + `tmdb_onbellek`'ten okur, Batch API'ye N istek atar, sonucu `ai_denetim.json`'a yazar. Uçta değil, elle çalıştırılan bir araç (aynen `ai_kare_tazele.js` gibi).
- **Yeni dosya:** `backend/araclar/ai_metin_uret.js` — bölüm bazlı üretim, çıktısı yine `ai_yorumlar.json` biçiminde.
- **Yeniden kullanılan:** `tmdb_onbellek` (76 MB, tr-TR, `credits`+`overview` dahil — istemin bağlamı buradan gelir, TMDB'ye yeni istek atmadan), `metin_cevirileri` (EN çeviri aynı yoldan), `ai_tohum.js`, `/og/dizi/.../bolum/...` SSR ucu, `sitemap-icerik-N.xml`.
- **Gerekmeyen:** yeni tablo, yeni uç, şema değişikliği.

### 4. Maliyet
Token sayıları **[DOĞRULANMALI: Türkçe token oranı `messages.count_tokens` ile
ölçülmeli — Türkçe sondan eklemeli, İngilizceden belirgin daha çok token
üretir; aşağıdakiler 636 karakter ≈ 450 token varsayımıdır.]**

**(a) Denetim — tek seferlik, ucuz:**
- Girdi ~1.100 token (inceleme + kısa istem), çıktı ~80 token.
- `claude-haiku-4-5` + **Batch API (%50 indirim)**:
  `(1.100 × $1 + 80 × $5) / 1M × 0,5` = **$0,00075/inceleme** → 2.400 için **≈ $1,80**.
- **İş yükü: 0,5 adam-günü.** Bu, belgedeki en yüksek fayda/maliyet oranlı iş.

**(b) Bölüm bazlı üretim:**
- Girdi ~2.500 token (TMDB bölüm özeti + dizi bağlamı + üslup talimatı), çıktı ~500 token.
- `claude-sonnet-5` + Batch: `(2.500 × $2 + 500 × $10) / 1M × 0,5` = **$0,005/bölüm**
  (giriş fiyatıyla; 31 Ağu'dan sonra $3/$15 → $0,0075).
- `claude-opus-5` + Batch: `(2.500 × $5 + 500 × $25) / 1M × 0,5` = **$0,0125/bölüm**.
- **Hangi model?** Buradaki iş *yaratıcı Türkçe yazı + spoiler disiplini*, yani
  belgedeki en zor iş. Ama Batch API'de bile 50 dizi × 10 sezon × 10 bölüm = 5.000
  bölüm → Opus 5 ile $63, Sonnet 5 ile $25. **Fark 40 dolar; kalite farkı bu
  projenin tek SEO sermayesinde. Opus 5.**
- **İş yükü: 2-3 adam-günü** (istem tasarımı + üslup kalibrasyonu + hakem döngüsü
  + elle örnekleme).
- ⚠️ **Uyarı:** 40 paralel Claude Code ajanıyla üretilen mevcut metinlerin
  kalitesi (`SEO-PLANI.md`: "Mevcut Breaking Bad örneği bu çıtayı karşılıyor")
  API çağrısıyla **birebir tekrarlanmayabilir** — ajan oturumunda model TMDB'ye
  bakabiliyor, araç kullanabiliyor, kendi çıktısını gözden geçirebiliyordu. Tek
  atışlık API çağrısı daha zayıf çıkabilir. Bunu bir **20 başlıklık pilot** ile
  ölçmeden 5.000 bölüme yatırım yapma.

### 5. Risk
- **Spoiler sızdırma: buradaki ANA risk ve aynı zamanda (a)'nın varlık sebebi.**
  Bölüm incelemesi doğası gereği spoiler'a en yakın içerik türü. İki katmanlı
  savunma: (i) üretim isteminde açık kural, (ii) ayrı bir hakem çağrısı — üreten
  model kendi çıktısını yargılamaz. Ek olarak `yorumlar.spoiler` bayrağı ve
  "bölüm yorumu yalnız o bölüm izlendiyse görünür" kuralı (`server.js:3476`)
  zaten ikinci bir ağ.
- **Google "ölçekli içerik kötüye kullanımı" — GERÇEK ve CİDDİ.**
  `SEO-PLANI.md` §2.3(c) bunu zaten yazmış. 5.000 bölüm metnini tek seferde basmak
  tam olarak politikanın tarif ettiği şey. Bu yüzden öneri **blanket genişletme
  DEĞİL**: (i) yalnız **Türkiye'de izlenme oranı yüksek ~50 dizi** için,
  (ii) haftalara yayılmış partiler halinde, (iii) her partiden **rastgele 20
  metin elle okunmadan** bir sonraki parti başlamaz, (iv) TMDB özetini yeniden
  yazan metin hakemden geçemez.
  **[DOĞRULANMALI: Google'ın politikasının bugünkü metni — 2026-08 itibarıyla
  Search Console yardım sayfasından teyit edilmeli.]**
- **Uydurma iddia:** `YAPILACAKLAR.md`, Parti 3'te bu sorunu zaten yaşamış ve
  isteme "tanımadığın yapımda oyuncu/ödül/eleştiri iddiası UYDURMA" kuralını
  eklemiş. Aynı kural + hakemin `uydurma_iddia` alanı.
- **Kişisel veri: YOK.** Modele giden şey TMDB metaverisi ve AI hesabının kendi
  metinleri. Kullanıcı verisi yok.
- **Ölçekle:** maliyet başlık sayısıyla büyür, kullanıcı sayısıyla değil — yani
  **öngörülebilir ve sınırlı**. Belgedeki tek "sabit maliyet" önerisi bu.

### 6. Neden şimdi / neden şimdi değil
**(a) ŞİMDİ.** 2.400 metin canlıda, indeksleniyor, sitemap'te, SSR bot
sayfalarında ve akışta. Hiç denetlenmediler. $1,80 ve yarım gün karşılığında
"acaba içlerinde spoiler var mı?" sorusu kapanıyor. Ürünün en katı kuralı bu.

**(b) ŞİMDİ, ama dar.** SEO Faz 2'nin asıl kaldıracı bu ve site 6 Ağustos'ta
sitemap gönderdi — uzun kuyruk içeriği ekmek için doğru an. Ama önce 20
başlıklık pilot.

---

## 4. ÖNERİ 3 — Yazma anında spoiler / uygunsuzluk sınıflandırıcısı

### 1. Ne
`POST /yorumlar` bugün `spoiler` bayrağını **kullanıcıdan** alıyor
(`server.js:4808`). Kullanıcı işaretlemeyi unutursa spoiler perdesiz yayılır ve
`siralama.js`'in `spoiler_ceza` çarpanı devreye girmez. Öneri: gönderi
kaydedildikten **sonra** (yanıt zaten dönmüştür) asenkron bir sınıflandırıcı
çalışsın, `spoiler=true` ise satırı güncellesin; nefret söylemi/taciz tespitinde
`sikayetler` tablosuna otomatik kayıt düşsün.

Kullanıcı deneyimi: engelleyici değil, **düzeltici**. "Bu gönderi spoiler
içeriyor gibi göründü, perdeledik — hatalıysa kaldır" + tek dokunuşla geri alma.
Yanlış pozitif kullanıcıyı bloke etmez.

### 2. Depodaki karşılığı
- **[`rag_tutorials/corrective_rag`](https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/rag_tutorials/corrective_rag)** — yine LLM-hakem kalıbı, ama bu sefer üretimden önce değil, **yayından sonra** kapı. **Alınan:** yapılandırılmış not + eşik. **Alınmayan:** grafiğin geri kalanı (yeniden yazma döngüsü burada anlamsız — kullanıcının metnini biz yeniden yazamayız).
- **[`advanced_ai_agents/multi_agent_apps/multi_agent_trust_layer`](https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/advanced_ai_agents/multi_agent_apps/multi_agent_trust_layer)** / `trust_gated_agent_team` — güven kapısı fikri. **Alınmayan:** çok ajanlı yapı; burada tek çağrı yeter.

### 3. Bizim koda nasıl oturur
- **Değişen dosya:** `backend/server.js` → `app.post('/yorumlar', ...)` (satır ~4805) — INSERT'ten sonra `setImmediate(() => denetle(id))`, yanıt beklemez.
- **Yeni yardımcı:** `backend/icerik_denetim.js` (saf fonksiyon + tek DB yazımı).
- **Yeni sütun:** `ALTER TABLE yorumlar ADD COLUMN spoiler_otomatik BOOLEAN DEFAULT false` — kullanıcının kendi işaretiyle otomatik işareti ayırt etmek için. `siralama.js`'e dokunmaz (`spoiler_isaret` zaten `y.spoiler`'dan geliyor; OR eklemek yeter).
- **Yeniden kullanılan:** `sikayetler` tablosu + admin paneli `/admin/sikayetler` sekmesi (zaten var), `hatalar` tablosu (çağrı hatası oraya düşer).
- **İstemin bağlamı:** o yapımın `tmdb_onbellek`'teki özeti + sezon/bölüm bilgisi — model neyin spoiler sayılacağını bilmek için buna ihtiyaç duyar.

### 4. Maliyet
- **İş yükü:** ~1,5 adam-günü.
- **Model:** **`claude-haiku-4-5`** ($1/$5). İkili sınıflandırma; Opus/Sonnet israf.
- **Gönderi başı:** ~400 girdi + 30 çıktı ≈ **$0,00055**.
- **Bugünkü ölçek:** 2.447 kullanıcı gönderisi *tüm proje ömrü boyunca* → geriye
  dönük tarama **$1,35**. İleriye dönük: neredeyse ölçülemez.
- **Ölçekle:** maliyet **kullanıcı üretimi içerikle** doğrusal büyür — ki ürünün
  bütün stratejisi bunu büyütmek üzerine. 10.000 kullanıcı × günde 0,5 gönderi =
  5.000/gün = **$2,75/gün**. Bu, moderasyon için ucuz bir rakam.

### 5. Risk
- **Yanlış pozitif** ana risk: temiz bir yorumu perdelemek kullanıcıyı kızdırır.
  Çözüm: asla sert engelleme, her zaman tek dokunuşla geri alma, ve eşiği
  **muhafazakâr** tutmak (emin değilse işaretleme).
- **Gecikme: yok** — asenkron, gönderi anında dönüyor.
- **Kişisel veri:** kullanıcının **yorum metni** modele gider. Bu metin zaten
  herkese açık (`/yorumlar/:tur/:tmdbId` kimlik doğrulamasız erişilebilir,
  `SEO-PLANI.md:302`), yani "gizli veri sızıyor" durumu yok — **ama yine de
  açıkça yazılmalı:** kullanıcı adı, e-posta, IP, DM'ler ve izleme geçmişi
  gönderilmez; yalnız gönderi metni + o yapımın TMDB özeti gider. Gizlilik
  metnine bir satır eklenmeli. **DM'lere (`mesajlar`) asla dokunulmaz** —
  `E2E-SIFRELEME-PLANI.md` zaten onları uçtan uca şifrelemeye götürüyor.
- **Google:** ilgisiz.

### 6. Neden şimdi / neden şimdi değil
**Şimdi değil.** 2.447 gönderi *toplam*, 94 kullanıcı, günlük UGC neredeyse yok.
Bugün elle bakmak daha ucuz. Bu, "gerçek kullanıcı yorumları akmaya başladığında"
(SEO planının 2.3.3 hedefi tuttuğunda) açılacak bir madde. **Tetikleyici eşik
öner:** günlük kullanıcı gönderisi ≥ 20.

---

## 5. ÖNERİ 4 — Zevk profili + gerekçeli öneri ("Sana Özel"in içi dolar)

### 1. Ne
`/onerilen` bugün sığ: son 6 izlenen yapımın TMDB `/recommendations` listelerini
birleştirip `vote_count`'a göre sıralıyor (`server.js:4661`). Yani "bunu izleyenler
şunu da izledi" — kullanıcının *neyi neden* sevdiğine dair hiçbir şey bilmiyor.

Öneri iki katmanlı:
1. **Sunucuda, LLM'siz:** kullanıcının kitaplığından `tmdb_onbellek` üzerinden
   toplu bir profil çıkar — tür dağılımı, on yıl dağılımı, menşe ülke, ortalama
   bölüm süresi, bitirme/bırakma oranı, tekrar izleme. Bu **saf SQL + JSONB**,
   maliyeti sıfır.
2. **LLM:** bu **toplu** profili + `/onerilen`'in ürettiği ~20 adaylık listeyi alır,
   (a) 2-3 cümlelik Türkçe zevk özeti yazar, (b) adayları yeniden sıralar ve her
   biri için tek satırlık **gerekçe** üretir ("Dark'ı bitirdiğin ve yavaş yanan
   Avrupa yapımlarını bıraktığın için değil bitirdiğin için").

**Yine kritik: model aday listesini ÜRETMEZ, yalnız sıralar ve açıklar.**
Uydurma başlık imkânsız.

### 2. Depodaki karşılığı
- **[`advanced_llm_apps/llm_apps_with_memory_tutorials/llm_app_personalized_memory`](https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/advanced_llm_apps/llm_apps_with_memory_tutorials/llm_app_personalized_memory)** — kalıcı, kullanıcı-başına **zevk profili**nin öğe indeksinden ayrı tutulması (Mem0 + Qdrant). **Alınan:** ham olay günlüğü yerine **sıkıştırılmış doğal dil zevk özeti** fikri. **Alınmayan:** Mem0, Qdrant — bizde bu sinyal zaten `izlemeler`/`durumlar`/`puanlar`'da yapılandırılmış halde duruyor, bir bellek katmanına ihtiyaç yok.
- **[`advanced_llm_apps/llm_apps_with_memory_tutorials/ai_arxiv_agent_memory`](https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/advanced_llm_apps/llm_apps_with_memory_tutorials/ai_arxiv_agent_memory)** — *arama kutusunun kendisi profilleyicidir*. **Alınan:** her arama/izleme kaydının profili örtük güncellemesi — bizde `arama geçmişi` zaten tutuluyor (SPRINT 8).

### 3. Bizim koda nasıl oturur
- **Değişen dosya:** `backend/server.js` → `/onerilen` (satır 4661) yanına `/onerilen/ozet` ya da `?gerekce=1`.
- **Yeni tablo:** `kullanici_zevk (kullanici_id INT PK REFERENCES kullanicilar, ozet TEXT, etiketler JSONB, guncelleme TIMESTAMPTZ)`. Gecelik tazelenir — **istek anında LLM çağrısı YOK**.
- **Yeniden kullanılan:** `tmdb_onbellek` (tür/ülke/süre buradan; TMDB'ye ek istek yok), `izlemeler` + `durumlar` + `puanlar`, `/onerilen`'in mevcut aday üretimi, `DURUM_MERDIVEN` (`siralama.js:49` — izliyorum/bitirdim/izleyeceğim/bıraktım ağırlıkları zaten kalibre edilmiş, profil hesabı aynısını kullanmalı).
- **`siralama.js`'e dokunmaz.** Bu bir yan yüzey; akış motoru bağımsız kalır.
- **Nerede işe yarar:** `ALGORITMA-PLANI.md` Faz 3.5 ("tür profili ve içerik benzerliği") tetikleyicisi **puan ≥ 1.000** — bugün **37**. Yani plan bu sinyali istiyor ama veri yok. LLM zevk profili, puan hacmi gelene kadarki **soğuk başlangıç köprüsü**.

### 4. Maliyet
- **İş yükü:** ~2,5 adam-günü (SQL profil + tablo + gecelik iş + uç + 45 dil + gizlilik ayarı + gizlilik metni).
- **Model:** **`claude-sonnet-5`**. Gerekçe: çıktı kullanıcıya doğrudan gösterilen **Türkçe yaratıcı metin**; Haiku'nun üslubu bu yüzeyde yetmez, Opus 5 gereksiz. (Giriş fiyatı $2/$10, 31 Ağu 2026'ya kadar; sonra $3/$15.)
- **Kullanıcı başı:** ~1.600 girdi (profil + 20 aday × ~60 token) + ~400 çıktı ≈ **$0,0072**.
- **Bugünkü ölçek:** 94 kullanıcı, yalnız kitaplığı değişenler tazelenir →
  **ayda ~$5**. Batch API ile (gecelik iş, gecikmesi önemsiz) **~$2,50**.
- **Ölçekle:** 10.000 kullanıcı × haftalık tazeleme = 10.000 × $0,0072 / hafta ≈
  **$310/ay** (Batch ile $155). Burası dikkat isteyen yer: maliyet **kullanıcı
  sayısıyla doğrusal**. Sınırlama: yalnız **aktif** kullanıcılar (son 30 günde
  giriş yapmış) tazelenir, misafirler hiç tazelenmez (bugün 94'ün çoğu misafir).

### 5. Risk
- **KİŞİSEL VERİ — belgedeki en yüksek risk, ve bu yüzden en katı kuralları var.**
  Modele giden şey **açıkça sayılmalı ve sınırlanmalı**:
  - ✅ **Gider:** toplu/türetilmiş profil (tür sayaçları, on yıl dağılımı, ülke
    dağılımı, ortalama süre, bitirme oranı) + 20 aday başlığın TMDB adı ve türü.
  - ❌ **GİTMEZ:** kullanıcı adı, e-posta, IP, **DM'ler (`mesajlar`)**, yorum
    metinleri, bölüm bazlı izleme zaman damgaları, takip grafiği, ham izleme listesi.
  - Bu ayrım kodda **beyaz liste** olarak yazılmalı (kara liste değil) — profil
    fonksiyonu yalnız izin verilen alanları döndürmeli.
- **Rıza:** `kullanicilar` tablosunda zaten `izlenenler_gizli` / `yorumlar_gizli`
  gizlilik tercihleri var. Aynı kalıpta **`oneri_kisisel BOOLEAN DEFAULT false`**
  — **varsayılan KAPALI**, kullanıcı Ayarlar'dan açar. GDPR dışa aktarma
  (`/veri/disa-aktar`) `kullanici_zevk` satırını da içermeli, hesap silme
  (`/hesabim` DELETE) `ON DELETE CASCADE` ile temizlemeli.
- **Halüsinasyon:** başlık uydurma imkânsız (aday listesi verilir), ama **gerekçe
  uydurabilir** — "Nordic noir sevdiğin için" derken kullanıcı hiç Nordic noir
  izlememiş olabilir. Azaltma: profil etiketlerini isteme **açık liste** olarak
  ver ve "yalnız bu listedeki etiketlere atıf yap" kuralı koy.
- **Spoiler:** gerekçe metni bir yapımın konusunu ele verebilir. İstem kuralı +
  §4'teki hakemin aynısı (ucuz, Haiku).
- **Gecikme: yok** — gecelik hesaplanır, uç önbellekten okur.
- **Google:** bu içerik `noindex` yüzeyde (girişli kullanıcıya özel), ölçekli
  içerik politikasıyla ilgisi yok.

### 6. Neden şimdi / neden şimdi değil
**Şimdi değil.** İki sebep: (i) 94 kullanıcının 67'si misafir
(`ALGORITMA-PLANI.md` §3.11) — kişiselleştirilecek profil yok; (ii) proje şu anda
**E2E şifreleme ve güvenlik denetimi** turundan geçiyor (`E2E-SIFRELEME-PLANI.md`,
`GUVENLIK-DENETIMI-2026-08-07.md`). Kullanıcı verisini üçüncü tarafa gönderen bir
özelliği tam da gizliliği sıkılaştırırken açmak yanlış sıralama. **Tetikleyici:
E2E turu bitsin + kayıtlı (misafir olmayan) aktif kullanıcı ≥ 200.**

---

## 6. ÖNERİ 5 — Yerel gömme ile içerik benzerliği (LLM değil, RAG'ın diğer yarısı)

### 1. Ne
`/onerilen` TMDB'nin "bunu izleyenler şunu izledi" verisine bağımlı — Türkiye'de
az izlenen ya da yeni yapımlarda bu veri zayıf. Alternatif sinyal: **2.400 AI
incelemesi + 2.956 TMDB tr-TR özetini** çok dilli bir gömme modeliyle vektöre
çevir, kosinüs benzerliğiyle "buna benzeyen" üret. Bu, `ALGORITMA-PLANI.md`
Faz 3.5'in ("içerik benzerliği") tam olarak istediği şey.

**Anahtar ölçüm — bu yüzden pgvector GEREKMİYOR:**
5.356 öğe × 384 boyut × 4 bayt = **8,2 MB**. Node belleğinde tek bir
`Float32Array`. Kaba kuvvet kosinüs: 5.356 × 384 = 2 milyon çarpma → **~2 ms**.
Bir ANN indeksine, bir uzantıya, bir imaj değişimine ihtiyaç **yok**. pgvector
bu ölçekte mühendislik değil, ritüel olur. (Karşılaştırma: `siralama.js` zaten
her istekte 4.845 adayı skorluyor ve 40 ms'de bitiriyor.)

### 2. Depodaki karşılığı
- **[`rag_tutorials/local_hybrid_search_rag`](https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/rag_tutorials/local_hybrid_search_rag)** — tamamen yerel hibrit hattı: BGE-M3 gömme + FlashRank yeniden sıralayıcı, dış API yok. **Alınan:** "gömme + yeniden sıralama tek makinede, sorgu başına vendor maliyeti sıfır" ispatı. **Alınmayan:** RAGLite, Llama-3.2, Streamlit, pgvector.
- **[`rag_tutorials/hybrid_search_rag`](https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/rag_tutorials/hybrid_search_rag)** — anlamsal + anahtar kelime birleşimi. Bizde anahtar kelime bacağı **zaten var** (`pg_trgm`); eksik olan anlamsal bacak. **Alınmayan:** Cohere reranker (ücretli), OpenAI embedding.

### 3. Bizim koda nasıl oturur
- **Yeni araç:** `backend/araclar/gomme_uret.py` (ya da ONNX ile `.js`) — host'ta,
  konteynerin dışında, tek seferlik + gecelik artımlı. `whisper.cpp` ile birebir
  aynı desen (`altyazi_uret.js`: "SUNUCUDA, HOST üzerinde çalışır, Docker'ın
  İÇİNDE değil"). Bu desen projede kanıtlanmış.
- **Yeni tablo:** `icerik_gomme (tur TEXT, tmdb_id INT, vektor BYTEA, guncelleme TIMESTAMPTZ, PRIMARY KEY (tur, tmdb_id))` — `BYTEA`, `vector` değil. `Float32Array` doğrudan buffer olarak saklanır.
- **Değişen dosya:** `backend/server.js` → `/onerilen`'e üçüncü aday kaynağı; ileride `/kesfet-akis`'e sinyal.
- **Yeniden kullanılan:** AI inceleme korpusu (2.400 uzun, özgün Türkçe metin — bu bir *ürün* veri varlığı, TMDB özetinden çok daha zengin), `tmdb_onbellek` özetleri, `icerik_dizini`.
- **Model:** `multilingual-e5-small` ya da `bge-m3` sınıfı çok dilli bir gömme
  modeli, CPU'da. 16 çekirdek + 131 GB RAM buna fazlasıyla yeter.
  **[DOĞRULANMALI: Anthropic'in birinci-parti gömme (embeddings) ucu — `claude-api`
  skill'inin model kataloğunda gömme modeli listelenmiyor; Models API ile teyit
  edilmeli. Bugünkü bilgiyle gömme için üçüncü taraf ya da yerel model şart.]**

### 4. Maliyet
- **İş yükü:** ~2 adam-günü (üretim betiği + tablo + kosinüs yardımcısı + gecelik iş + testler).
- **Çalışma maliyeti: sorgu başına $0.** Model çağrısı yok. Tek maliyet CPU:
  5.356 metnin ilk gömülmesi CPU'da tahminen 10-30 dakika, sonrası artımlı
  (günde birkaç yeni başlık). **[DOĞRULANMALI: gerçek CPU süresi ölçülmeli.]**
- **Ölçekle:** başlık sayısıyla büyür, kullanıcı sayısıyla **hiç büyümez**.
  100.000 başlıkta bile 153 MB bellek ve ~40 ms kaba kuvvet — hâlâ ANN gerekmez.
  **Belgedeki tek sıfır-marjinal-maliyet önerisi.**

### 5. Risk
- **Halüsinasyon: yok** (LLM yok).
- **Kişisel veri: yok** — hiçbir şey sunucudan çıkmıyor. Vendor bağımlılığı sıfır.
- **Gecikme:** +2 ms, ihmal edilebilir.
- **Google:** ilgisiz.
- **Asıl risk teknik:** Türkçe gömme kalitesi. Çok dilli küçük modeller Türkçe'de
  İngilizce'dekinden zayıftır; "benzer" sonuçlar saçma çıkabilir.
  **Azaltma:** canlıya çıkmadan önce elle 30 başlık için ilk 5 komşuya bakılmalı
  (aynen dHash eşiğinin gözle kalibre edildiği gibi — `ai_tohum.js:96`, bu
  projede kanıtlanmış bir doğrulama alışkanlığı).
- **Yeni bir dil/çalışma zamanı** (Python/ONNX) host'a girer. Ama `whisper.cpp`
  zaten orada; `saglik_izle.sh` ve deploy ritüeli genişletilmeli.

### 6. Neden şimdi / neden şimdi değil
**Şimdi değil, ama en dayanıklısı.** Faydası içerik hacmiyle artar; 2.400
incelemeyle bugün de çalışır ama `/onerilen` bugün kimseyi rahatsız etmiyor.
**Tetikleyici:** Öneri 2(b) ile korpus büyüdükten sonra — daha çok özgün metin,
daha iyi gömme. Sıralaması: 2 → 5.

---

## 7. "Bakma, uymaz" — cazip görünen ama bu ürüne oturmayan kalıplar

| Depodaki alan | Neden uymaz |
|---|---|
| **`voice_ai_agents/`** (4 örnek: `voice_rag_openaisdk`, `customer_support_voice_agent`…) | dizi.jpg bir **görsel** ürün: poster ızgaraları, Reels tarzı kare akışı, 10 sahne karesi/gönderi. Sesli arayüz bu etkileşimin hiçbirine dokunmuyor. Ayrıca ses ucu istek başı en pahalı LLM yüzeyi; 94 kullanıcı için gerekçesi yok. |
| **`mcp_ai_agents/`** (6 örnek) | MCP, bir ajanın **dış servislere** bağlanma protokolü (GitHub, Notion, Slack). dizi.jpg'nin dış servisi TMDB — ve TMDB'ye erişim zaten `tmdbGetir()` + `tmdb_onbellek` ile çözülmüş, üstelik önbellekli. MCP araya bir katman daha koyar, hiçbir şey kazandırmaz. |
| **`generative_ui_agents/`** (7 örnek, shadcn/React) | Uygulama **Flutter**. Bu örneklerin tamamı React/shadcn bileşeni üretiyor. Flutter web tuvali erişilebilirlik ağacı bile vermiyor (`CLAUDE.md` kural 7) — çalışma zamanı bileşen üretimi bu yığında karşılığı olmayan bir fikir. |
| **`advanced_ai_agents/multi_agent_apps/agent_teams/`** (16 örnek) | Çok ajanlı takımlar **açık uçlu, uzun ufuklu** işler için (hukuk analizi, VC due diligence). dizi.jpg'nin LLM işleri dar ve iyi tanımlı: sınıflandır, şema doldur, kısa metin yaz. Bunların hepsi **tek çağrı**. Çok ajanlı yapı buraya gecikme, maliyet ve hata yüzeyi ekler, kalite eklemez. Tek istisna Öneri 2'deki **üreten ≠ yargılayan** ayrımı — o da iki çağrı, "takım" değil. |
| **`rag_tutorials/knowledge_graph_rag_citations`** | Bilgi grafiği + alıntı temelli cevap. Cazip ("inceleme hangi bölüme dayanıyor?") ama dizi/film alanında ilişkiler **zaten yapılandırılmış** (TMDB: cast, crew, sezon, bölüm). Grafiği LLM'le çıkarmak, elde JSON olarak duran veriyi yeniden keşfetmek olur. |
| **`rag_tutorials/vision_rag`** (Cohere embed-v4.0, görseli doğrudan gömer) | En cazip görünen ama uymayan. Elde 16.580 sahne karesi var; "Türkçe tarifle sahne ara" kulağa harika geliyor. Gerçek: kareler TMDB backdrop'ları, yani zaten o yapımın karesi — arama zaten yapım düzeyinde çözülmüş. Kare içi arama, olmayan bir sorunu çözer. Ayrıca ücretli çok modlu gömme, sıfır marjinal maliyetli Öneri 5'in tersi. |
| **`agent_skills/`** (8 skill: `commit-archaeologist`, `scope-creep-detector`…) | Bunlar **geliştirici araçları**, ürün özelliği değil. Belki `evals` ilginç, ama proje `node --test` + `flutter test` ile kendi kanıt disiplinini zaten kurmuş (`CLAUDE.md` kural 7) — yeni bir çerçeve öğrenmenin karşılığı yok. |
| **`always_on_agents/`, `autonomous_game_playing_agent_apps/`** | Kapsam dışı. |
| **Kurumsal RAG genelinde** (`chat_with_pdf`, `chat_with_github`, `rag-as-a-service`) | Kullanıcı yüklediği belgeyle sohbet — dizi.jpg'de böyle bir belge yok. Korpus **bizim** ürettiğimiz içerik; onu "sohbet" arayüzüne koymak, katalog gezinmesinden daha kötü bir arayüz olur. |
| **Mem0 / Qdrant bellek katmanı** (Öneri 4'te fikri alındı ama aracı alınmadı) | Mem0 etkileşimlerden "hatırlanacak gerçekler" çıkarır. Bizde o gerçekler **zaten yapılandırılmış**: `izlemeler` (44.372 satır), `durumlar`, `puanlar`, `favoriler`. Bunları LLM'e çıkarttırmak, elde SQL'le duran veriyi kaybetmek olur. |

---

## 8. Tek tavsiye

### Sıradaki iş: **Öneri 2(a) — mevcut 2.400 AI incelemesinin LLM-hakem denetimi.**

**İlk adım (bugün yapılabilir, yarım gün):**
1. `backend/araclar/ai_metin_denetle.js` yaz: `ai_yorumlar.json`'ı okur, her kayıt
   için `tmdb_onbellek`'ten o yapımın `overview`'ını çeker, **Batch API**'ye
   `claude-haiku-4-5` isteği atar. Çıktı şeması `strict: true` tool-use ile:
   `{spoiler: bool, ozgunluk: 1-5, uydurma_iddia: bool, gerekce: string}`.
2. `messages.count_tokens` ile **önce 20 kayıtta** gerçek Türkçe token maliyetini
   ölç, sonra 2.400'ü gönder (tahmini toplam ~$1,80).
3. `ozgunluk ≤ 2` ya da `spoiler` ya da `uydurma_iddia` olanları
   `ai_denetim_basarisiz.json`'a yaz ve **elle oku**.

**Neden bu:**
- **Ürünün en katı kuralını koruyor.** Spoiler bu üründe bir kural, tercih değil —
  `siralama.js`'de ceza çarpanı var, SSR bot sayfaları spoiler'lı gönderiyi
  basmıyor, bölüm yorumları izleme durumuna göre kapılı. Buna rağmen canlıdaki
  2.411 AI gönderisi **hiç denetlenmedi**.
- **SEO sermayesini koruyor.** `SEO-PLANI.md`'nin kendi tespiti: sitenin gerçek
  varlığı bu 2.400 metin. Sitemap 6 Ağustos'ta gönderildi; Google indekslemeye
  başlamadan önce içeriğin temiz olduğunu bilmek, sonra öğrenmekten ucuz.
- **Hiçbir kullanıcı verisine dokunmuyor.** E2E şifreleme ve güvenlik denetimi
  turu sürerken, kişisel veri sınırının tamamen dışında kalan tek anlamlı LLM işi bu.
- **Kullanıcı sayısından bağımsız.** 94 kullanıcı diğer dört öneriyi "erken"
  yapıyor; bu öneri 94 kullanıcıyla da 94.000 kullanıcıyla da aynı derecede gerekli.
- **Ucuz ve geri alınabilir.** $2 ve yarım gün. Çıktı yalnız bir JSON raporu —
  canlıya hiçbir şey dokunmuyor, geri alınacak bir şey yok.
- **Boru hattını kanıtlıyor.** Aynı betik, Öneri 2(b)'nin (bölüm bazlı üretim)
  hakem yarısıdır. Denetim çalışırsa üretime geçmek risksizleşir; denetim
  mevcut korpusta sorun bulursa, **5.000 bölüm daha üretmeden önce** öğrenilmiş olur.

**Bunu takip edecek iş:** Öneri 2(b)'nin 20 başlıklık pilotu (Opus 5, Batch API,
~$0,25) — pilot metinler mevcut Breaking Bad örneğinin kalitesini tutturuyor mu,
gözle karşılaştır. Tutturamıyorsa 40 paralel ajan yöntemi kalır, API üretimi
rafa girer.

---

## 9. Doğrulanması gerekenler (özet)

| # | Konu |
|---|---|
| 1 | Türkçe token oranı — tüm maliyet hesapları 636 kr ≈ 450 token varsayımına dayanıyor; `messages.count_tokens` ile ölçülmeli. |
| 2 | Anthropic'in birinci-parti gömme (embeddings) ucu var mı — `claude-api` skill kataloğunda listelenmiyor; Models API ile teyit. |
| 3 | Google "ölçekli içerik kötüye kullanımı" politikasının 2026-08 itibarıyla güncel metni. |
| 4 | `postgres:16-alpine` → `pgvector/pgvector:pg16` geçişinde collation/REINDEX gereksinimi (§5 bunu gereksiz kılıyor ama ileride sorulursa). |
| 5 | Doğal dil arama sorgularının gerçek tekrar oranı (önbellek isabetini, dolayısıyla ölçek maliyetini belirler). |
| 6 | Çok dilli gömme modelinin Türkçe komşuluk kalitesi — 30 başlıkta gözle. |
| 7 | Yerel gömme üretiminin gerçek CPU süresi (16 çekirdek). |
| 8 | Batch API'nin `strict: true` tool-use ile birlikte davranışı — skill Batches'te `fallbacks` parametresinin reddedildiğini söylüyor, tool-use için böyle bir kısıt görünmüyor ama pilotla teyit edilmeli. |
