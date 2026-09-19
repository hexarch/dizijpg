#!/bin/bash
# dizi.jpg — Google Analytics 4 (G-9P6MTX343J) canlı dağıtımı, 1.178.0+267
#
# NEDEN AYRI BETİK: nginx CSP yaması ile web dağıtımı BİRLİKTE yapılmak
# zorunda. CSP satır içi betiğe yalnız sha256 hash'iyle izin veriyor; etiketi
# eklerken o betik değişti, yani hash de değişti. Yalnız biri yapılırsa:
#   * yalnız nginx  -> CANLIDAKİ eski betik engellenir, açılış katmanı hiç
#                      kalkmaz (kullanıcı sarı çubukta kilitli kalır),
#   * yalnız dağıtım-> YENİ betik engellenir, aynı arıza.
# Bu yüzden 1. adımda nginx'e İKİ hash birlikte yazılır (eski + yeni); dağıtım
# doğrulandıktan SONRA 7. adımda eski hash düşürülür. Böylece aradaki hiçbir
# anda kırık bir kombinasyon servis edilmiyor.
#
# Betik IDEMPOTENT: yarıda kalırsa tekrar koşturulabilir.
set -euo pipefail

S=keyubu                       # 87.248.157.114 (~/.ssh/config)
YEREL=/Users/wolf/Desktop/masaustuyedek/projeler/dizijpg/app/build/web
UZAK=/var/www/dizijpg

ESKI_HASH="sha256-RJ/D5BTfkRmRMxMKCW/0OVhx1yUCR3lJaAw9RjfZi+E="
YENI_HASH="sha256-p/xJp3p6Le6vk1RK2BbFTfd80YTI7kLSRICxU8kBtrU="
OLCUM_ID="G-9P6MTX343J"

YENI_PAKET="main.e83027c76b05.dart.js"
YENI_PARCA="main.dart.js_1.03742cc4cbf6.part.js"
ESKI_PAKET="main.bdefb51d2134.dart.js"
ESKI_PARCA="main.dart.js_1.e0f5929b5fde.part.js"

echo "### 1/7  nginx CSP: yeni hash + GA hostları (eski hash KALIYOR)"
ssh "$S" 'bash -s' <<'UZAKTA'
set -euo pipefail
f=/etc/nginx/sites-enabled/dizijpg.com
cp -a "$f" "${f}.yedek-ga4-$(date +%Y%m%d-%H%M%S)"
python3 - <<'PY'
import io
f = "/etc/nginx/sites-enabled/dizijpg.com"
s = io.open(f, encoding="utf-8").read()
ilk = s

ESKI = "'sha256-RJ/D5BTfkRmRMxMKCW/0OVhx1yUCR3lJaAw9RjfZi+E='"
YENI = "'sha256-p/xJp3p6Le6vk1RK2BbFTfd80YTI7kLSRICxU8kBtrU='"

# script-src: yeni hash + googletagmanager (yalnız TAM eşleşen 13 blokta)
a = ESKI + " https://accounts.google.com https://static.cloudflareinsights.com"
b = (ESKI + " " + YENI
     + " https://accounts.google.com https://static.cloudflareinsights.com"
     + " https://www.googletagmanager.com")
n1 = s.count(a)
s = s.replace(a, b)

# connect-src: GA ölçüm isteği (region1.google-analytics.com dahil)
a = "connect-src blob: 'self' https://accounts.google.com https://fonts.gstatic.com;"
b = ("connect-src blob: 'self' https://accounts.google.com https://fonts.gstatic.com"
     " https://*.google-analytics.com https://*.analytics.google.com"
     " https://*.googletagmanager.com;")
n2 = s.count(a)
s = s.replace(a, b)

# img-src: GA'nin XHR'i engellenirse dustugu piksel yedegi
a = "https://*.googleusercontent.com https://i.ytimg.com;"
b = "https://*.googleusercontent.com https://i.ytimg.com https://*.google-analytics.com;"
n3 = s.count(a)
s = s.replace(a, b)

if s == ilk:
    print("  CSP zaten yamalı (değişiklik yok)")
else:
    io.open(f, "w", encoding="utf-8").write(s)
    print("  script-src: %d | connect-src: %d | img-src: %d blok" % (n1, n2, n3))
PY
nginx -t
systemctl reload nginx
echo "  nginx yeniden yüklendi"
UZAKTA

echo "### 2/7  web dosyaları (rsync, --delete YOK: robots.txt build'de değil)"
rsync -az --info=stats1 -e ssh "$YEREL/" "$S:$UZAK/"

echo "### 3/7  yeni paket canlıda mı"
for f in "$YENI_PAKET" "$YENI_PARCA"; do
  kod=$(curl -s -o /dev/null -w '%{http_code}' "https://dizijpg.com/$f")
  echo "  $f -> $kod"
  [ "$kod" = "200" ] || { echo "HATA: $f canlıda yok, DURDU"; exit 1; }
done

echo "### 4/7  brotli (.br) üretimi"
ssh "$S" 'bash /opt/dizijpg/web_brotli.sh' | tail -3

echo "### 5/7  doğrulama: etiket + CSP başlığı"
say=$(curl -s "https://dizijpg.com/?ga-dogrula=$RANDOM" | grep -c "$OLCUM_ID" || true)
echo "  ana sayfada ölçüm kimliği: $say kez (beklenen: 3)"
[ "$say" -ge 1 ] || { echo "HATA: etiket canlı HTML'de yok, DURDU"; exit 1; }

csp=$(curl -sI https://dizijpg.com/ | tr -d '\r' | grep -i '^content-security-policy')
echo "$csp" | grep -q "googletagmanager.com" \
  || { echo "HATA: CSP'de googletagmanager yok, DURDU"; exit 1; }
echo "$csp" | grep -q "google-analytics.com" \
  || { echo "HATA: CSP'de google-analytics yok, DURDU"; exit 1; }
echo "$csp" | grep -q "$YENI_HASH" \
  || { echo "HATA: CSP'de yeni hash yok, DURDU"; exit 1; }
echo "  CSP: googletagmanager + google-analytics + yeni hash TAMAM"

dil=$(curl -s https://dizijpg.com/de/ | grep -c "$OLCUM_ID" || true)
echo "  Almanca kabukta ölçüm kimliği: $dil kez"

echo "### 6/7  eski hash'li paketleri sil (.br karşılıklarıyla)"
ssh "$S" "cd $UZAK && rm -f '$ESKI_PAKET' '$ESKI_PARCA' '$ESKI_PAKET.br' '$ESKI_PARCA.br' && ls -1 main.*.dart.js main.dart.js_*.part.js"

echo "### 7/7  CSP'den ESKİ hash'i düşür (yeni betik artık canlı)"
ssh "$S" 'bash -s' <<UZAKTA2
set -euo pipefail
f=/etc/nginx/sites-enabled/dizijpg.com
sed -i "s|'$ESKI_HASH' ||g" "\$f"
kalan=\$(grep -c "$ESKI_HASH" "\$f" || true)
echo "  eski hash kalan: \$kalan (beklenen: 0)"
nginx -t
systemctl reload nginx
UZAKTA2

echo
echo "BİTTİ. GA4 gerçek zamanlı rapor:"
echo "https://analytics.google.com/analytics/web/#/p_/realtime/overview"
echo "Veri 30-60 sn içinde 'Gerçek zamanlı' ekranında görünür; standart"
echo "raporlar 24-48 saat sonra dolar."
