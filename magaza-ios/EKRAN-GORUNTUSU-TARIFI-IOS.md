# iOS App Store ekran görüntüsü tarifi (31 Ağustos 2026)

Apple'ın istediği ölçüler (konsoldan okundu):
- **iPhone 6.5"**: `1242×2688` veya `1284×2778`
- **iPad 13"**: `2064×2752` veya `2048×2732`

Simülatör çıktıları:
- iPhone 17 Pro Max → **1320×2868** (1284×2778'e ölçeklenmeli)
- iPad Pro 13" (M5) → **2064×2752** (TAM ÖLÇÜ, dokunma)

## Ortam

Android'deki `adb tap` karşılığı iOS'ta YOK, derin bağlantı da yok
(Info.plist'te URL şeması tanımsız). Çözüm: Simulator penceresine
**AppleScript ile tıklamak**. Erişilebilirlik izni gerekli (`System Events`).

`dokun.sh` — cihaz NOKTA koordinatını ekran pikseline çevirir:

```bash
DEV_W=440; DEV_H=956   # iPhone 17 Pro Max mantıksal ölçü
read WX WY WW WH < <(osascript -e 'tell application "System Events" to tell process "Simulator" to get {position, size} of window 1' | tr ',' ' ')
SX = WX + (nokta_x/DEV_W)*WW
SY = WY + (nokta_y/DEV_H)*WH
osascript -e 'tell application "Simulator" to activate' \
          -e "tell application \"System Events\" to click at {$SX, $SY}"
```

Pencere konumu her çağrıda YENİDEN okunur (pencere taşınabilir).
Cihaz PİKSELİNDEN noktaya çevirmek için 3'e böl (@3x).

## Giriş: UI'dan DEĞİL, jetonu enjekte ederek

UI'dan giriş yapmaya çalışma (yazı yazmak kırılgan). Bunun yerine:

1. Jetonu backend'den al:
   `curl -X POST https://dizijpg.com/api/auth/giris -H 'Content-Type: application/json' -d '{"email":"import-test-2226@dizijpg.com","sifre":"test1234"}'`
   → JSON'daki `token` alanı (JWT, ~189 karakter).
2. **UYGULAMAYI KAPAT** (`xcrun simctl terminate`). Açıkken yazarsan
   uygulama plist'in tamamını kendi belleğinden geri yazıp jetonu SİLER.
3. Plist'e yaz — `simctl spawn ... defaults write` İŞE YARAMADI, doğrudan
   dosyayı düzenle:
   ```bash
   C=$(xcrun simctl get_app_container <UDID> com.dizijpg.dizijpg data)
   P="$C/Library/Preferences/com.dizijpg.dizijpg.plist"
   /usr/libexec/PlistBuddy -c "Add :flutter.token string <JWT>" "$P"
   ```
   Anahtar `flutter.token` (Flutter shared_preferences `flutter.` öneki kullanır).
4. Uygulamayı başlat, ~15 sn bekle. Profil sekmesi `@emma.watches` göstermeli
   (5552 bölüm / 417 film / 113 dizi — dolu hesap).

## Doğrulama

Kareyi **gözle** açıp bak (yükleniyor iskeleti, yarım başlık, yanlış sayfa olmasın).
Bir şeyin çizilip çizilmediğini ölçmek için piksel say:

```python
box = im.crop((w//2-350, h//2-350, w//2+350, h//2+350))
farkli = sum(1 for r,g,b in box.getdata() if abs(r-11)>25 or abs(g-11)>25 or abs(b-13)>25)
```
%0 = hiçbir şey yok, %8+ = içerik var.

## ⚠ TUZAK: iOS açılış ekranını ÖNBELLEĞE ALIYOR

`simctl uninstall` bunu TEMİZLEMEZ. Açılış ekranı değişikliğini sınamak için
**`xcrun simctl erase <UDID>`** şart. Yoksa eski açılış ekranını görüp
"değişiklik geçmedi" sanırsın.
