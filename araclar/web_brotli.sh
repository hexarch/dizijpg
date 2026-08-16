#!/usr/bin/env bash
# dizi.jpg — dağıtım sonrası statik brotli üretici (14 Ağustos 2026)
#
# NEREDE ÇALIŞIR: SUNUCUDA (root@154.53.163.3), `scp build/web/* ...` ADIMINDAN
# SONRA. nginx'teki `brotli_static on` yalnızca yanı başında `<dosya>.br` varsa
# devreye girer; bu betik o dosyaları üretir.
#
#   scp araclar/web_brotli.sh root@154.53.163.3:/opt/dizijpg/
#   ssh root@154.53.163.3 'bash /opt/dizijpg/web_brotli.sh'
#
# NEDEN q11 VE NEDEN DAĞITIMDA: brotli 11 anlık istekte çok pahalı, ama dosya
# başına BİR KEZ ödendiğinde main.dart.js'te 845 KB, canvaskit.wasm'da 603 KB
# kazandırıyor (ölçüm: backend/nginx-sikistirma-20260814.parca.conf başlığı).
#
# ATLANMAMASI GEREKEN NOKTA: .br dosyası kaynağından ESKİ kalırsa nginx eski
# içeriği yollar ve hata teşhis edilemez hale gelir. Betik bu yüzden HER
# çalıştırmada `-f` ile yeniden üretir ve kaynağı silinmiş .br'leri temizler.
#
# ATOMİK YAZMA — ÖĞRENİLMİŞ DERS (14 Ağu 2026, canlıda yakalandı):
# İlk sürüm doğrudan `<dosya>.br` üzerine yazıyordu. main.dart.js'in 11,8 MB'ını
# q11 ile sıkıştırmak ~2 dakika sürüyor ve o iki dakika boyunca dosya YARIM
# duruyor; `brotli_static on` olduğu için nginx o yarım gövdeyi 200 ile
# servis etti (ölçüldü: `content-length: 0`, `content-encoding: br`).
# Yani dağıtım anında sitedeki JS bozuk gidiyordu. Çözüm: geçici dosyaya
# sıkıştır, bitince `mv` ile yerine geçir — `mv` aynı dosya sisteminde atomik,
# nginx ya tam eski ya tam yeni dosyayı görür.

set -euo pipefail

KOK="${1:-/var/www/dizijpg}"

# Betik yarıda kesilirse (Ctrl-C, ssh kopması) yazılmakta olan geçici dosyayı
# geride bırakmasın. Yerine geçmiş .br'ler zaten tam, onlara dokunulmaz.
temizle() {
  find "$KOK" -type f -name '*.br.gecici' -delete 2>/dev/null || true
}
trap temizle EXIT INT TERM

if [ ! -d "$KOK" ]; then
  echo "HATA: dizin yok: $KOK" >&2
  exit 1
fi

if ! command -v brotli >/dev/null 2>&1; then
  echo "HATA: brotli komutu yok. Kur: apt-get install -y brotli" >&2
  exit 1
fi

# macOS'tan scp ile gelen AppleDouble artıkları (`._dosya`). İçerik değil,
# kaynak çatalı meta verisi; sunucuda hiçbir işe yaramaz ve dizin listelerini
# kirletir. 14 Ağu 2026'da canlıda 8 tanesi duruyordu.
artik_sayisi=$(find "$KOK" -type f -name '._*' | wc -l | tr -d ' ')
if [ "$artik_sayisi" -gt 0 ]; then
  find "$KOK" -type f -name '._*' -delete
  echo "macOS artığı silindi: $artik_sayisi dosya"
fi

# Önceki çalıştırma yarıda kesildiyse geride kalan geçici dosyalar. nginx bunları
# servis etmez (adı `.br` değil), ama diski şişirmesin.
find "$KOK" -type f -name '*.br.gecici' -delete

# Kaynağı ortadan kalkmış .br dosyalarını sil (içerik hash'li adlar yüzünden
# her dağıtımda eski JS'in .br'si sahipsiz kalır).
sahipsiz=0
while IFS= read -r br; do
  if [ ! -f "${br%.br}" ]; then
    rm -f "$br"
    sahipsiz=$((sahipsiz + 1))
  fi
done < <(find "$KOK" -type f -name '*.br')
[ "$sahipsiz" -gt 0 ] && echo "sahipsiz .br silindi: $sahipsiz dosya"

# Sıkıştırılacak türler. Görsel/video (jpg, png, webp, mp4) BİLEREK YOK:
# zaten sıkıştırılmış, brotli kazancı sıfıra yakın, CPU boşa gider.
UZANTILAR=(js json css html xml svg wasm ttf otf txt map)

# 1 KB altındaki dosyaya dokunma: nginx'teki `brotli_min_length 1024` ile aynı
# eşik; küçük dosyada brotli başlığı kazancı yiyor.
ASGARI_BAYT=1024

toplam_ham=0
toplam_br=0
sayi=0

for uzanti in "${UZANTILAR[@]}"; do
  while IFS= read -r dosya; do
    ham=$(stat -c%s "$dosya")
    # Eşik altındaki kaynakta ESKİ .br kalırsa nginx `brotli_static` onu
    # yollar — 16 Ağu: SW sökücü 615 B, eşik 1024, eski .br CF'ye eski
    # gövde servis etti (no-store BYPASS bile br'yi origin'den çekti).
    if [ "$ham" -lt "$ASGARI_BAYT" ]; then
      rm -f "${dosya}.br"
      continue
    fi
    gecici="${dosya}.br.gecici"
    brotli -f -q 11 -o "$gecici" "$dosya"
    br=$(stat -c%s "$gecici")
    # Sıkışmayan dosya için .br tutmak anlamsız (nginx büyük olanı yollar).
    if [ "$br" -ge "$ham" ]; then
      rm -f "$gecici" "${dosya}.br"
      continue
    fi
    # Atomik geçiş: nginx ya tam eski ya tam yeni gövdeyi görür.
    mv -f "$gecici" "${dosya}.br"
    toplam_ham=$((toplam_ham + ham))
    toplam_br=$((toplam_br + br))
    sayi=$((sayi + 1))
  done < <(find "$KOK" -type f -name "*.${uzanti}" ! -name '*.br')
done

if [ "$sayi" -eq 0 ]; then
  echo "UYARI: sıkıştırılacak dosya bulunamadı — yol doğru mu? ($KOK)" >&2
  exit 1
fi

kazanc=$((toplam_ham - toplam_br))
yuzde=$((kazanc * 100 / toplam_ham))
printf 'brotli q11: %d dosya · ham %d B → br %d B · kazanç %d B (%%%d)\n' \
  "$sayi" "$toplam_ham" "$toplam_br" "$kazanc" "$yuzde"
