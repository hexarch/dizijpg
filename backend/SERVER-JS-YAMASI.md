# `backend/server.js` yaması — özel mesajlarda durağan şifreleme

**Neden ayrı dosya:** bu tur yazılırken `server.js` üzerinde başka bir ajan
(SEO işi) çalışıyordu. Aşağıdaki değişiklikler dosya boşalınca ANA OTURUM
tarafından uygulanacak.

**Satır numaraları güvenilmez** (SEO değişiklikleri dosyayı kaydırır). Her
dokunuş için ARANACAK METİN verildi; her biri dosyada **tam 1 kez** geçiyor
(7 Ağu 2026'da `grep -cF` ile doğrulandı).

**Toplam 6 dokunuş noktası.** Beşi tek satır, biri (açılış kontrolü) yeni blok.

---

## 0. Ön koşullar (yamadan ÖNCE)

| # | İş | Durum |
|---|---|---|
| a | `backend/kripto.js` | ✅ bu turda yazıldı |
| b | `backend/migrasyon-2026-08-07.sql` + `sema.sql` | ✅ yazıldı, **canlıya UYGULANMADI** |
| c | `Dockerfile` COPY satırına `kripto.js` eklendi | ✅ yapıldı — **atlanırsa konteyner `Cannot find module './kripto.js'` ile açılmaz** |
| d | `docker-compose.yml` → `MESAJ_ANAHTARI` aktarımı | ✅ yapıldı |
| e | `/opt/dizijpg/.env` → `MESAJ_ANAHTARI=` | ⛔ **dağıtımda yapılacak** |

---

## Dokunuş 1 — `kripto.js` içe aktarımı

**ARA:**
```js
import {
  CEVRIMICI_ESIK_SN, sonGorulmeYazilmali, sohbetleriAyir, istekRozeti,
} from './cevrimici.js';
```

**SONRASI:**
```js
import {
  CEVRIMICI_ESIK_SN, sonGorulmeYazilmali, sohbetleriAyir, istekRozeti,
} from './cevrimici.js';
// Özel mesajların durağan şifrelemesi (AES-256-GCM). `cozGoster` ASLA
// fırlatmaz: tek bozuk satır yüzünden sohbetin tamamı 500 dönmesin.
import { baslat as kriptoBaslat, sifrele, cozGoster } from './kripto.js';
```

> ⚠ **`anahtarlar`ı İÇE AKTARMA.** `kripto.js` `anahtarlar()` diye bir
> fonksiyon dışa veriyor, ama `GET /mesajlar/:kullaniciAdi` içinde ZATEN
> `const anahtarlar = [...new Set(rows…)]` adında yerel bir değişken var
> (TMDB içerik anahtarları). İçe aktarılırsa `SyntaxError: Identifier
> 'anahtarlar' has already been declared` ile **süreç hiç açılmaz.**

---

## Dokunuş 2 — Açılışta anahtar kontrolü (fail-fast)

**ARA:**
```js
if (!DATABASE_URL || !JWT_SECRET || !TMDB_TOKEN) {
  console.error('Eksik ortam değişkeni (DATABASE_URL / JWT_SECRET / TMDB_TOKEN)');
  process.exit(1);
}
```

**SONRASI (bloğun hemen ALTINA ekle):**
```js
if (!DATABASE_URL || !JWT_SECRET || !TMDB_TOKEN) {
  console.error('Eksik ortam değişkeni (DATABASE_URL / JWT_SECRET / TMDB_TOKEN)');
  process.exit(1);
}

// Özel mesajların durağan şifrelemesi. ANAHTAR YOKSA AÇILMIYORUZ.
// Gerekçe: sessizce düz metne düşmek en tehlikeli sonuçtur — şifreleme
// kapanır, hiçbir uç hata vermez, gece yedeği yine düz metin dolar ve aylarca
// kimse fark etmez. Yüksek sesle ölmek, sessizce korumasız kalmaktan iyidir.
// Bilinçli kaçış yolu var: .env'e `MESAJ_SIFRELEME=kapali`.
try {
  const kriptoTakim = kriptoBaslat(process.env);
  console.log(kriptoTakim.acik
    ? `Mesaj şifreleme AÇIK — aktif anahtar ${kriptoTakim.aktif.kimlik}, ` +
      `okunabilir: ${[...kriptoTakim.hepsi.keys()].join(',')}`
    : 'UYARI: Mesaj şifreleme KAPALI (MESAJ_SIFRELEME=kapali) — ' +
      'DM metinleri veritabanına DÜZ yazılıyor.');
} catch (e) {
  console.error('Mesaj şifreleme kurulamadı, açılış durduruldu:\n' + e.message);
  process.exit(1);
}
```

*Not:* mevcut `DATABASE_URL` kontrolüyle aynı kalıp — yeni bir disiplin
getirmiyor, var olanı izliyor.

---

## Dokunuş 3 — `GET /sohbetler` (sohbet listesi ÖNİZLEMESİ) — **OKUMA**

Bu uç partner başına son mesajın `metin`ini döndürüyor; istemci
`mesajOzeti()` (`app/lib/ekranlar/sohbet.dart:1391`) ile önizlemeyi çiziyor.
**Atlanırsa mesajlar listesinde her satırda `v1.k1.…` görünür.**

**ARA:**
```js
  rows.sort((a, b) => b.id - a.id);
  const { sohbetler, istekler } = sohbetleriAyir(rows);
```

**SONRASI:**
```js
  rows.sort((a, b) => b.id - a.id);
  // Önizleme metni DB'den ŞİFRELİ gelir; istemciye çözülmüş gider.
  // (sohbetleriAyir aynı nesnelere referans verir, sıralamadan sonra
  //  çözmek yeterli.)
  for (const r of rows) r.metin = cozGoster(r.metin);
  const { sohbetler, istekler } = sohbetleriAyir(rows);
```

---

## Dokunuş 4 — `GET /mesajlar/:kullaniciAdi` (sohbet geçmişi) — **OKUMA**

**İKİ alan çözülmeli.** `m.metin` asıl mesaj, `y.metin AS yanit_metin`
alıntılanan mesajın önizlemesi (`LEFT JOIN mesajlar y`). İstemci
`sohbet.dart:1560`'ta `m['yanit_metin']`i okuyup alıntı baloncuğuna basıyor —
**bu ikinciyi atlamak en kolay yapılacak hata.**

**ARA:** (SELECT'in hemen ardındaki kapanış — TMDB anahtarları satırından önce)
```js
  // Paylaşılan içerik kartları için ad + poster (önbellekli TMDB)
  const anahtarlar = [...new Set(rows
```

**SONRASI:**
```js
  // Mesaj metni VE alıntılanan mesajın metni şifreli gelir; ikisi de çözülür.
  // yanit_metin atlanırsa alıntı baloncuğunda ham zarf görünür.
  for (const r of rows) {
    r.metin = cozGoster(r.metin);
    r.yanit_metin = cozGoster(r.yanit_metin);
  }
  // Paylaşılan içerik kartları için ad + poster (önbellekli TMDB)
  const anahtarlar = [...new Set(rows
```

*Dokunulmayanlar (aynı uçta):* `gonderiler` önizlemesi `yorumlar.metin`den
gelir — **halka açık içerik, şifrelenmiyor**. `icerikler` TMDB'den gelir.
`okundu`/`iletildi` UPDATE'leri ve bildirim düşürme metne dokunmaz.

---

## Dokunuş 5 — `POST /mesajlar` (yeni mesaj) — **YAZMA**

**ARA:**
```js
    [req.kullanici.id, aliciId, temiz || null, medya, sesMi ? ses_dalga : null,
```

**SONRASI:**
```js
    [req.kullanici.id, aliciId, sifrele(temiz || null), medya, sesMi ? ses_dalga : null,
```

**Bu uçta DEĞİŞMEYECEKLER — bilerek:**

* `temiz.length > 2000` doğrulaması **şifrelemeden ÖNCE, kullanıcının yazdığı
  metin üzerinde** kalır. DB'deki CHECK kısıtı kalktığı için tek uzunluk
  savunması budur; kaldırılırsa 10 KB'lik mesajlar yazılabilir hâle gelir.
* `bildirimEkle(aliciId, 'mesaj', req.kullanici.id, null, temiz ? { metin: temiz } : null)`
  **DÜZ METİN kalır.** Push önizlemesinin kaynağı budur ve kararımız gereği
  push aynen çalışmaya devam ediyor. (Not: bu kopya Google FCM'den geçiyor —
  at-rest şifrelemenin kapsamı DEĞİL, E2E'nin işiydi. `bildirimler` TABLOSUNA
  metin YAZILMIYOR; tablo şeması doğrulandı.)
* `medya`, `ses_dalga`, `icerik_tur`, `icerik_id`, `yanit_id`, `yorum_id`
  şifrelenmez — gerekçeleri `migrasyon-2026-08-07.sql` §3'te.

---

## Dokunuş 6 — `PATCH /mesajlar/:id` (mesaj düzenleme) — **YAZMA**

**ARA:**
```js
    [temiz, id, req.kullanici.id],
```

**SONRASI:**
```js
    [sifrele(temiz), id, req.kullanici.id],
```

Bu uçtaki `!temiz || temiz.length > 2000` kontrolü de **şifrelemeden önce,
düz metin üzerinde** kalır.

---

## DEĞİŞMEYEN uçlar — envanter (her biri tek tek denetlendi)

| Uç / fonksiyon | Neden dokunulmuyor |
|---|---|
| `DELETE /mesajlar/:id` | `RETURNING medya` — metni hiç okumuyor |
| `POST /mesajlar/iletildi` | yalnız `iletildi` bayrağı |
| `POST /yaziyor` | bellek içi `Map`, metin yok |
| `GET /paylas-hedefler` | `mesajlar`dan yalnız kimlikleri okur |
| `bildirimEkle()` | `INSERT INTO bildirimler (kullanici_id, tur, aktor_id, yorum_id)` — **metin kolonu YOK** |
| `pushBildirim()` | `ekstra.metin` çağırandan DÜZ gelir, DB'den okunmaz |
| `POST /sikayet` | yalnız `{tur, hedef_id, sebep}`; **mesaj içeriği kopyası saklamıyor** (bugün de saklamıyordu) |
| `DELETE /hesabim` | `DELETE FROM kullanicilar` → CASCADE; metin okumaz |
| `backend/veri_aktar.js` (GDPR dışa aktarım) | **`mesajlar` tablosuna hiç dokunmuyor** — DM'ler zaten dışa aktarılmıyor (`grep mesajlar veri_aktar.js` → 0). Ayrı bir eksik, bu işin kapsamı dışında |
| Admin `GET /admin/kullanici/:ad` | `(SELECT count(*) FROM mesajlar …)` — yalnız sayaç |
| Admin istatistik/tutundurma sorguları | `gonderen_id, tarih` — metin yok |
| `medyaReferanslari()` (yetim medya temizliği) | `SELECT medya` — medya yolu şifrelenmediği için ÇALIŞMAYA DEVAM EDER |
| `backend/admin.html` | şikayet tablosunda `tur='mesaj'` için zaten `hedef_ozet` doldurulmuyor |

**`mesajlar.metin` üzerinde `LIKE`/arama/sıralama YOK.** `server.js` içindeki
tüm `LIKE`ler `yorumlar.metin`, `kullanicilar.kullanici_adi/email`,
`unnest(y.medya)` ve `tmdb_onbellek.anahtar` üzerinde. İstemcide de DM araması
yok (`sohbet.dart` içindeki arama TMDB içerik araması). Yani "şifreli veride
arama yapılamaz" kısıtı **bu projede hiçbir özelliği bozmuyor** — ve
`test/kripto.test.js` içindeki
*"mesajlar.metin üzerinde arama/LIKE YOK"* testi, ileride biri DM araması
eklerse kırmızıya dönerek uyarır.

---

## Yamadan sonra ZORUNLU kanıt

1. `node --check backend/server.js`
2. `cd backend && node --test test/*.test.js` → **199/199 yeşil** olmalı
   (dizin argümanı bu Node sürümünde çalışmıyor, glob şart).
3. Uçtan uca curl (test hesabıyla, `testkullanici` / `test1234`):
   ```
   POST /mesajlar   → 200 {id,tarih}
   GET  /mesajlar/<partner>  → gövdedeki "metin" DÜZ okunabilir olmalı,
                               "v1.k1." ile BAŞLAMAMALI
   GET  /sohbetler  → önizleme "metin" düz olmalı
   PATCH /mesajlar/<id> → sonra GET ile düzenlenmiş metin düz görünmeli
   ```
   Ve aynı anda sunucuda:
   ```
   docker exec dizijpg-db psql -U dizijpg -d dizijpg -tAc \
     "SELECT left(metin,12) FROM mesajlar ORDER BY id DESC LIMIT 1"
   → "v1.k1." ile BAŞLAMALI   ← şifrelemenin gerçekten çalıştığının kanıtı
   ```
4. Sohbet ekranında bir mesajı **alıntılayıp** yanıtla, sonra sohbeti yenile:
   alıntı baloncuğunda düz metin görünmeli (Dokunuş 4'ün ikinci yarısının testi).
