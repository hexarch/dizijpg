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

- **29 Ağu 2026: 11 DİLİN TAMAMINDA TELEFON EKRAN GÖRÜNTÜLERİ YENİLENDİ ve
  incelemeye gönderildi** (Yayın özeti → "11 değişikliği incelemeye gönder").
  Kareler 1.100.2+156 arayüzünden, hepsi 1080×2160, profil @melis.izler.
  Diller: en-US, tr-TR, de-DE, el-GR, es-ES, fr-FR, id, it-IT, pt-BR, ru-RU, ar.
  Artık hiçbir dil varsayılana düşmüyor; her dilin kendi görselleri var.
- Eski setler `ortak/arsiv/2026-08-25-1.93/` (tr+en) ve
  `ortak/arsiv/2026-08-22-1080x1920/` (de/el/es) altında.
- **EKSİK KALAN:** 7"/10" tablet ekran görüntüleri hâlâ eski (@testkullanici,
  yalnız en-US'te var; diğer diller ona düşüyor). Tanıtım videosu hiçbir dilde yok.

## Ekran görüntüsü üretim tarifi

Tam tarif: `magaza/EKRAN-GORUNTUSU-TARIFI.md` (29 Ağu 2026, emülatör
1080×2224 + üstten 64 px kesme = 1080×2160, koordinatlar ve dil değiştirme).
Eski not:
`dizijpg-magaza-girisi` (emülatör 1080×1983 + üstten 63 px durum çubuğu
kesilir = 1080×1920; uygulama dili Profil → Ayarlar → Dil'den değişir).
