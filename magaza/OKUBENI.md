# dizi.jpg — Play Store Mağaza Varlıkları

Düzen (23 Ağu 2026'dan beri): **dil başına bir klasör**. Her `<locale>/`
klasöründe o dilin Play'e giren her şeyi bulunur:

```
magaza/
  <locale>/                 tr-TR, en-US, de-DE, el-GR, es-ES,
    metin.md                ar, fr-FR, id, it-IT, pt-BR, ru-RU
    ekran-goruntuleri/      (yalnız görseli üretilen dillerde)
    video/                  (üretilirse; henüz hiçbir dilde yok)
  ortak/                    dil bağımsız varlıklar
    arsiv/                  eski/yedek görseller (Play'e YÜKLENMEZ)
```

## Play'de nereye yüklenir?

Konsol yolu: **Büyüme > Mağaza girişleri > Varsayılan mağaza girişi** →
sağ üstten dil seçilir.

- `metin.md` → üç bölümü sırasıyla konsoldaki üç alana:
  **Uygulama adı** (≤30) · **Kısa açıklama** (≤80) · **Tam açıklama** (≤4000).
- `ekran-goruntuleri/1-*.png … 8-*.png` → **Telefon ekran görüntüleri**,
  dosya adındaki numara sırasıyla. 25 Ağu 2026'dan beri **1080×2160 (2:1)** —
  modern telefon ölçüsü (emülatör 1080×2224 + üstten 64 px durum çubuğu
  kesilir; Play telefon görselinde en fazla 2:1 kabul eder). Eski 1080×1920
  set `ortak/arsiv/1080x1920-20260822/` altında. Görseli olmayan diller
  Play'de varsayılan (en-US) görsellere düşer — bu normaldir.
- Tablet görselleri, uygulama simgesi (512×512) ve özellik grafiği
  (1024×500) yerelde YOK; yalnız Play'in kendi varlık kitaplığında
  duruyorlar (30 Tem 2026 yüklemeleri). Değiştirmek gerekirse yenisini üret.

## Yayın durumu

- **23 Ağu 2026: 11 dilin tamamı Play'de YAYINDA** (aynı gün incelemeden
  geçti). tr-TR adı: "dizi.jpg: Dizi ve Film Takibi", en-US adı:
  "dizi.jpg: TV & Movie Tracker".
- Görseli üretilen 5 dil: tr-TR, en-US, de-DE, el-GR, es-ES.
  Kalan 6 dil (ar, fr-FR, id, it-IT, pt-BR, ru-RU) şimdilik yalnız metin.
- **25 Ağu 2026: tr-TR + en-US telefon görselleri 1.93 arayüzüyle modern
  ölçüde (1080×2160) YENİLENDİ** (profil artık @melis.izler; 8. kare eski
  Keşfet yerine Gözat ızgarası). de-DE/el-GR/es-ES görselleri HÂLÂ eski
  1080×1920 setten — yenilenene kadar Play'de eski arayüzü gösterirler;
  istenirse silinip varsayılana (yeni en-US) düşürülebilir.
- Tanıtım videosu hiçbir dilde üretilmedi (alan Play'de boş).

## Ekran görüntüsü üretim tarifi

Emülatör tarifi ve dil değiştirme tuzakları için hafıza notu:
`dizijpg-magaza-girisi` (emülatör 1080×1983 + üstten 63 px durum çubuğu
kesilir = 1080×1920; uygulama dili Profil → Ayarlar → Dil'den değişir).
