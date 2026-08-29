# Play mağaza ekran görüntüsü çekme tarifi (29 Ağu 2026, sürüm 1.100.2+156)

Hedef: her dil için **8 adet 1080×2160 (2:1) PNG**, dosya adları sabit:

```
1-ana-sayfa.png  2-dizi-sayfasi.png  3-bolum-isaretleme.png  4-takvim.png
5-bolum-isi-haritasi.png  6-istatistik-kutuphane.png  7-incelemeler.png  8-kesfet.png
```

Kaydedilecek yer: `projeler/dizijpg/magaza/<locale>/ekran-goruntuleri/`

## Ortam

- `adb` = `~/Library/Android/sdk/platform-tools/adb`, cihazı **her komutta `-s <seri>`** ile seç.
- Emülatör zaten ayarlı: `wm size 1080x2224`, `wm density 425`. **Değiştirme.**
- Uygulama zaten kurulu (1.100.2+156) ve **@melis.izler** hesabıyla açık.
  Düşerse giriş: kullanıcı adı `testkullanici`, şifre `test1234`.
- Yardımcı betik: `<scratchpad>/kare.sh`. Kullanımı (SER ve OUT ortam değişkeniyle):

```bash
K=<scratchpad>/kare.sh
export SER=emulator-XXXX
export OUT=<scratchpad>/<locale>      # kareler buraya düşer
$K tap <x> <y> [bekleme_sn]           # dokun
$K swipe <x1> <y1> <x2> <y2> [süre_ms] [bekleme_sn]
$K cap <dosya-adı>                    # ekranı al, üstten 64px durum çubuğunu kes, 1080x2160 kaydet
```

`cap` çıktısı `(1080, 2160)` yazmalı. Her kareyi **Read aracıyla aç ve gözle doğrula**
(yükleniyor iskeleti, yarım kesilmiş başlık, yanlış sayfa olmasın).

## Sabit koordinatlar (cihaz pikseli, 1080×2224)

| Öğe | Koordinat |
|---|---|
| Alt menü: Ana sayfa / Takvim / + / Keşif / Profil | (107,2111) (323,2111) (539,2111) (756,2102) (967,2111) |
| Ana sayfa sağ üst "Gözat" ızgara ikonu | (1004,138) |
| Sayfa içi geri oku (sol üst) | (76,137) |
| Profil sağ üst dişli (Ayarlar) | (1015,137) |
| Profil sekmeleri: "Dizi ve Filmler" / "Yorumlar" | (338,1452) / (805,1452) |
| Profil → İzliyorum ilk afiş (Silo) | (182,1859) |
| Dizi sayfası TMDB puanı yanındaki ok (ısı haritası) | (321,1309) |

⚠ Bu koordinatlar **profil en üstteyken** geçerli. Kaydırdıysan önce en üste dön
(`swipe 540 600 540 1900` ×4).

## 8 karenin çekilişi

1. **1-ana-sayfa** — Ana sayfa sekmesi, en üst. `tap 107 2111 4` → `cap 1-ana-sayfa`
2. **8-kesfet** — Ana sayfadayken sağ üst ızgara: `tap 1004 138 5` → `cap 8-kesfet`
   → `tap 76 137 3` (geri)
3. **6-istatistik-kutuphane** — `tap 967 2111 5` (profil, en üst) → `cap 6-...`
4. **7-incelemeler** — `tap 805 1452 4` (Yorumlar sekmesi) →
   `swipe 540 1700 540 1200 500 3` → `cap 7-incelemeler`
5. **2-dizi-sayfasi** — profili en üste al (`swipe 540 600 540 1900 500` ×4),
   `tap 338 1452 3` (Dizi ve Filmler sekmesi), `tap 182 1859 8` → Silo sayfası açılır
   → `cap 2-dizi-sayfasi`
   ⚠ Açılan sayfanın **Silo** olduğunu doğrula; başka içerik açıldıysa geri dön ve
   afiş koordinatını ekran görüntüsünden yeniden ölç.
6. **5-bolum-isi-haritasi** — Silo sayfasında `tap 321 1309 3` (TMDB oku açılır,
   S1..S4 × E1..E9 puan ızgarası görünür) → `cap 5-...` → `tap 321 1309 2` (kapat)
7. **3-bolum-isaretleme** — Silo sayfasında aşağı in:
   `swipe 540 1800 540 600 400 2` ×2 → `swipe 540 600 540 1750 400 3`
   (Sezonlar listesi görünene kadar; ekran görüntüsüyle kontrol et)
   → "3. Sezon" satırına dokun (genişler, bölümler + tikler çıkar)
   → `swipe 540 1500 540 820 800 3` ile "Sezonlar" başlığı en üste gelecek şekilde
   çerçevele → `cap 3-bolum-isaretleme`
   Hedef kadraj: üstte "Sezonlar" başlığı, 1./2. sezon kartları, açılmış 3. sezon
   ve ilk 7 bölüm (5'i tikli).
8. **4-takvim** — `keyevent 4` ile dizi sayfasından çık → `tap 323 2111 12` →
   **"Takvim güncelleniyor" şeridi ve iskelet kartlar kaybolana kadar bekle**
   (20-30 sn, gerekirse tekrar `cap`) → `cap 4-takvim`

## Dil değiştirme

1. Profil sekmesi → dişli `tap 1015 137 5` (Ayarlar açılır, en üstte).
2. Aşağı kaydır (`swipe 540 1800 540 700 800`, ekran görüntüsüyle kontrol ederek)
   ve **"Tercihler → Dil"** satırını bul (küre ikonu + o anki dilin adı).
   ⚠ Ayarlar sayfasındaki **"Kaydet" düğmesine ASLA dokunma**, profil alanlarını
   değiştirme, "Profil düzeni" satırına girme.
3. Dil satırına dokun → alttan liste açılır. Üstte arama kutusu (~y=779),
   ilk sonuç ~y=965.
4. **ASCII yazılabilen diller:** arama kutusuna dokun, `adb -s $SER shell input text "..."`:
   `Deutsch`, `English`, `Espa` (Español), `Fran` (Français), `Italiano`,
   `Portug` (Português), `Bahasa` (Bahasa Indonesia). Sonra ilk sonuca dokun.
   ⚠ Arama **yalnız yerel adla** eşleşiyor ("rus", "greek", "arabic" SONUÇ VERMEZ).
5. **ASCII yazılamayan diller (Русский, Ελληνικά, العربية):** arama kutusuna
   dokunma; listeyi `swipe 540 1900 540 1000 400 2` ile kaydır, ekran görüntüsünde
   ilgili satırı gör, oraya dokun.
   Liste sırası (baştan): Türkçe, English, 中文, हिन्दी, Español, Français,
   العربية, বাংলা, Português, ...
6. Dil seçilir seçilmez arayüz değişir. **TMDB içeriği (afiş/başlık) için
   uygulamayı yeniden başlat:**
   `adb -s $SER shell am force-stop com.dizijpg.dizijpg` →
   `adb -s $SER shell monkey -p com.dizijpg.dizijpg -c android.intent.category.LAUNCHER 1`
   → 15 sn bekle. Yeniden başlatmazsan ilk karelerde eski dil kalır.
7. Ana sayfada başlıkların yeni dilde olduğunu doğrula, sonra 8 kareyi çek.

## Yasaklar

- Bölüm tiki, "İzledim", beğeni, yorum gönderme gibi **veri değiştiren hiçbir şeye
  dokunma** (hesap gerçek test verisi taşıyor). Yanlışlıkla bir bölüm sayfası
  açtıysan sadece geri dön.
- Emülatörün ekran boyutunu/yoğunluğunu değiştirme, uygulamayı kaldırma.
- `input text` ile Türkçe/Yunanca/Rusça/Arapça karakter yazmaya çalışma (ADB ASCII dışını basmaz).
