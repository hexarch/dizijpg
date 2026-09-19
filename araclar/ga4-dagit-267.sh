#!/bin/bash
# dizi.jpg — Google Analytics 4 (G-9P6MTX343J) canlı dağıtımı, 1.178.0+267
#
# KULLANIM
#   bash araclar/ga4-dagit-267.sh        # 1. adımdan
#   bash araclar/ga4-dagit-267.sh 4      # 4. adımdan devam (hepsi idempotent)
#
# NEDEN AYRI BETİK: nginx CSP yaması ile web dağıtımı BİRLİKTE yapılmak
# zorunda. CSP satır içi betiğe yalnız sha256 hash'iyle izin veriyor; GA
# etiketi eklenirken o betik değişti, yani hash de değişti. Yalnız biri
# yapılırsa:
#   * yalnız nginx   -> CANLIDAKİ eski betik engellenir, açılış katmanı hiç
#                       kalkmaz (kullanıcı sarı çubukta kilitli kalır),
#   * yalnız dağıtım -> YENİ betik engellenir, aynı arıza.
# Bu yüzden 1. adımda nginx'e İKİ hash birlikte yazılır (eski + yeni); dağıtım
# DOĞRULANDIKTAN sonra 7. adımda eski hash düşürülür. Aradaki hiçbir anda
# kırık bir kombinasyon servis edilmiyor.
set -euo pipefail

S=keyubu                       # 87.248.157.114 (~/.ssh/config)
YEREL=/Users/wolf/Desktop/masaustuyedek/projeler/dizijpg/app/build/web
UZAK=/var/www/dizijpg

# KEEPALIVE ŞART: brotli adımı dakikalarca sessiz çalışıyor; kanal boş kalınca
# aradaki güvenlik duvarı bağlantıyı RST'liyor ("Read from remote host:
# Connection reset by peer" — 19 Eyl 14:04'te tam bu oldu).
SSH="ssh -o ServerAliveInterval=15 -o ServerAliveCountMax=8 -o ConnectTimeout=20"

ESKI_HASH="sha256-RJ/D5BTfkRmRMxMKCW/0OVhx1yUCR3lJaAw9RjfZi+E="
YENI_HASH="sha256-p/xJp3p6Le6vk1RK2BbFTfd80YTI7kLSRICxU8kBtrU="
OLCUM_ID="G-9P6MTX343J"

YENI_PAKET="main.e83027c76b05.dart.js"
YENI_PARCA="main.dart.js_1.03742cc4cbf6.part.js"
ESKI_PAKET="main.bdefb51d2134.dart.js"
ESKI_PARCA="main.dart.js_1.e0f5929b5fde.part.js"

ADIM="${1:-1}"
yap() { [ "$ADIM" -le "$1" ]; }

# ---------------------------------------------------------------- 1) nginx CSP
if yap 1; then
  echo "### 1/7  nginx CSP: yeni hash + GA hostları (eski hash KALIYOR)"
  $SSH "$S" 'bash -s' <<'UZAKTA'
set -euo pipefail
f=/etc/nginx/sites-enabled/dizijpg.com

# YEDEK sites-enabled DIŞINA: nginx.conf bu dizinin TAMAMINI include ediyor,
# içeride bırakılan bir kopya "duplicate log_format" ile `nginx -t`yi patlatır
# (19 Eyl 13:55'te tam bu oldu; reload reddedildi, yama diskte asılı kaldı).
mkdir -p /root/nginx-yedek
cp -a "$f" "/root/nginx-yedek/dizijpg.com.ga4-$(date +%Y%m%d-%H%M%S)"
rm -f /etc/nginx/sites-enabled/dizijpg.com.yedek-ga4-*

python3 - <<'PY'
import io
f = "/etc/nginx/sites-enabled/dizijpg.com"
s = io.open(f, encoding="utf-8").read()
ilk = s

ESKI = "'sha256-RJ/D5BTfkRmRMxMKCW/0OVhx1yUCR3lJaAw9RjfZi+E='"
YENI = "'sha256-p/xJp3p6Le6vk1RK2BbFTfd80YTI7kLSRICxU8kBtrU='"

# script-src: yeni hash + googletagmanager (yalnız TAM eşleşen 13 blokta;
# admin bloğunun CSP'si farklı, ona dokunmuyor)
a = ESKI + " https://accounts.google.com https://static.cloudflareinsights.com"
b = (ESKI + " " + YENI
     + " https://accounts.google.com https://static.cloudflareinsights.com"
     + " https://www.googletagmanager.com")
n1 = s.count(a)
s = s.replace(a, b)

# connect-src: GA olcum istegi (region1.google-analytics.com dahil)
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
    print("  CSP zaten yamali (degisiklik yok)")
else:
    io.open(f, "w", encoding="utf-8").write(s)
    print("  script-src: %d | connect-src: %d | img-src: %d blok" % (n1, n2, n3))
PY

nginx -t
systemctl reload nginx
echo "  nginx yeniden yuklendi"
UZAKTA
fi

# ------------------------------------------------------------------- 2) rsync
if yap 2; then
  echo "### 2/7  web dosyaları (rsync, --delete YOK: robots.txt build'de değil)"
  # `--info=stats1` KULLANILMAZ: macOS 15'te /usr/bin/rsync artık openrsync
  # (protokol 29) ve o bayrağı tanımıyor. `--stats` ikisinde de var.
  rsync -az --stats -e "$SSH" "$YEREL/" "$S:$UZAK/" | tail -4
fi

# ------------------------------------------------------- 3) yeni paket canlıda
if yap 3; then
  echo "### 3/7  yeni paket canlıda mı"
  for f in "$YENI_PAKET" "$YENI_PARCA"; do
    kod=$(curl -s -o /dev/null -w '%{http_code}' "https://dizijpg.com/$f")
    echo "  $f -> $kod"
    [ "$kod" = "200" ] || { echo "HATA: $f canlıda yok, DURDU"; exit 1; }
  done
fi

# ------------------------------------------------------------------ 4) brotli
if yap 4; then
  echo "### 4/7  brotli (.br) üretimi — AYRIK OTURUM"
  # Uzun süren işi ssh oturumuna BAĞLAMA: setsid ile kopar, logla, sonra KISA
  # bağlantılarla yokla. Kopan bir ssh artık işi yarıda bırakmıyor.
  $SSH "$S" 'setsid nohup bash /opt/dizijpg/web_brotli.sh > /tmp/ga4-brotli.log 2>&1 < /dev/null & sleep 1; echo "  ayrik baslatildi"'
  bitti=0
  for i in $(seq 1 90); do
    sleep 10
    if $SSH "$S" '! pgrep -f "bash /opt/dizijpg/web_brotli.sh" > /dev/null'; then
      echo "  brotli bitti (~$((i * 10)) sn)"
      bitti=1
      break
    fi
  done
  [ "$bitti" = 1 ] || { echo "HATA: brotli 15 dk'da bitmedi, DURDU"; exit 1; }
  $SSH "$S" 'tail -3 /tmp/ga4-brotli.log'
fi

# --------------------------------------------------------------- 5) doğrulama
if yap 5; then
  echo "### 5/7  doğrulama: etiket + .br gövdesi + CSP başlığı"
  say=$(curl -s "https://dizijpg.com/?ga-dogrula=$RANDOM" | grep -c "$OLCUM_ID" || true)
  echo "  ana sayfada ölçüm kimliği: $say kez (beklenen: 3)"
  [ "${say:-0}" -ge 1 ] || { echo "HATA: etiket canlı HTML'de yok, DURDU"; exit 1; }

  # BROTLI GÖVDESİ AYRICA DOĞRULANIR. Düz `curl` sıkıştırılmamış dosyayı
  # çeker; nginx'te `brotli_static on` olduğu için GERÇEK tarayıcı
  # index.html.br alır. Bayat bir .br, düz dosya güncelken bile eski sayfayı
  # servis eder (16 Ağu'da SW sökücüde tam bu oldu).
  brsay=$($SSH "$S" "brotli -dc $UZAK/index.html.br | grep -c '$OLCUM_ID' || true")
  echo "  index.html.br içinde ölçüm kimliği: $brsay kez"
  [ "${brsay:-0}" -ge 1 ] || { echo "HATA: .br BAYAT (tarayıcı eski sayfayı görür), DURDU"; exit 1; }

  csp=$(curl -sI https://dizijpg.com/ | tr -d '\r' | grep -i '^content-security-policy' || true)
  [ -n "$csp" ] || { echo "HATA: CSP başlığı hiç gelmedi, DURDU"; exit 1; }
  for beklenen in "googletagmanager.com" "google-analytics.com" "$YENI_HASH"; do
    echo "$csp" | grep -q "$beklenen" \
      || { echo "HATA: CSP'de '$beklenen' yok, DURDU"; exit 1; }
  done
  echo "  CSP: googletagmanager + google-analytics + yeni hash TAMAM"

  dil=$(curl -s https://dizijpg.com/de/ | grep -c "$OLCUM_ID" || true)
  echo "  Almanca kabukta ölçüm kimliği: $dil kez"
fi

# -------------------------------------------------- 6) eski paketleri temizle
if yap 6; then
  echo "### 6/7  eski hash'li paketleri sil (.br karşılıklarıyla)"
  $SSH "$S" "cd $UZAK && rm -f '$ESKI_PAKET' '$ESKI_PARCA' '$ESKI_PAKET.br' '$ESKI_PARCA.br' && ls -1 main.*.dart.js main.dart.js_*.part.js"
fi

# ------------------------------------------------------ 7) eski hash'i düşür
if yap 7; then
  echo "### 7/7  CSP'den ESKİ hash'i düşür (yeni betik artık canlı)"
  $SSH "$S" 'bash -s' <<UZAKTA2
set -euo pipefail
f=/etc/nginx/sites-enabled/dizijpg.com
sed -i "s|'$ESKI_HASH' ||g" "\$f"
kalan=\$(grep -c "$ESKI_HASH" "\$f" || true)
echo "  eski hash kalan: \$kalan (beklenen: 0)"
nginx -t
systemctl reload nginx
UZAKTA2
fi

echo
echo "BİTTİ. GA4 gerçek zamanlı rapor:"
echo "https://analytics.google.com/analytics/web/#/a408757374p555028304/realtime/overview"
echo "Veri 30-60 sn içinde 'Gerçek zamanlı'da görünür; standart raporlar"
echo "24-48 saat sonra dolar."
