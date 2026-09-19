#!/bin/bash
# dizi.jpg — GENEL WEB DAĞITIMI (her sürümde kullanılır)
#
# KULLANIM
#   bash araclar/web-dagit.sh          # baştan
#   bash araclar/web-dagit.sh 4        # 4. adımdan devam (hepsi idempotent)
#
# NEDEN VAR: 19 Eyl 2026'da GA4 dağıtımı için yazılan betikte hash'ler ve paket
# adları ELLE gömülüydü; her derlemede değiştikleri için betik tek kullanımlık
# oldu ve iki kez yanlış değerle patladı. Bu sürüm hepsini KENDİ ÇIKARIR:
#   * satır içi betiğin sha256'sı  -> derleme çıktısından hesaplanır
#   * paket/parça adları           -> yerel dizinden okunur
#   * nginx'te duran eski hash'ler -> sunucudan okunur, sonunda temizlenir
#
# CSP SIRASI (kritik): satır içi betik her değiştiğinde hash değişir. Dağıtım
# ile nginx AYRILAMAZ; ayrılırsa açılış katmanı hiç kalkmaz. Bu yüzden 1. adım
# yeni hash'i ESKİLERİN YANINA yazar, 7. adım doğrulamadan SONRA eskileri atar.
set -euo pipefail

S=keyubu
KOK=/Users/wolf/Desktop/masaustuyedek/projeler/dizijpg
YEREL="$KOK/app/build/web"
UZAK=/var/www/dizijpg
NGINX=/etc/nginx/sites-enabled/dizijpg.com

# KEEPALIVE ŞART: brotli adımı dakikalarca sessizdir, boş kanal RST yiyor.
SSH="ssh -o ServerAliveInterval=15 -o ServerAliveCountMax=8 -o ConnectTimeout=20"

ADIM="${1:-1}"
yap() { [ "$ADIM" -le "$1" ]; }

[ -f "$YEREL/index.html" ] || { echo "HATA: $YEREL/index.html yok — önce derle"; exit 1; }

# --- türetilen değerler -------------------------------------------------------
# Satır içi betiğin hash'i: test/csp_satir_ici_hash_test.dart ile AYNI desen.
YENI_HASH=$(python3 - "$YEREL/index.html" <<'PY'
import base64, hashlib, io, re, sys
h = io.open(sys.argv[1], encoding='utf-8').read()
m = re.findall(r'<script(?![^>]*\ssrc=)[^>]*>([\s\S]*?)</script>', h)
if len(m) != 1:
    sys.exit('index.html icinde %d satir ici betik var; CSP her biri icin AYRI hash ister' % len(m))
print('sha256-' + base64.b64encode(hashlib.sha256(m[0].encode('utf-8')).digest()).decode())
PY
)
PAKETLER=$(cd "$YEREL" && ls -1 main.*.dart.js main.dart.js_*.part.js 2>/dev/null | tr '\n' ' ')
[ -n "$PAKETLER" ] || { echo "HATA: hash'li paket bulunamadı — web_hashla.js koştu mu?"; exit 1; }

echo "### türetilenler"
echo "  satır içi hash : $YENI_HASH"
echo "  paketler       : $PAKETLER"

# --------------------------------------------------------------- 1) nginx CSP
if yap 1; then
  echo "### 1/7  nginx CSP: yeni hash EKLENİR (eskiler şimdilik KALIR)"
  $SSH "$S" "YENI_HASH='$YENI_HASH' bash -s" <<'UZAKTA'
set -euo pipefail
f=/etc/nginx/sites-enabled/dizijpg.com

# YEDEK sites-enabled DIŞINA: nginx.conf bu dizinin TAMAMINI include ediyor;
# içeride bırakılan kopya "duplicate log_format" ile nginx -t'yi patlatır.
mkdir -p /root/nginx-yedek
cp -a "$f" "/root/nginx-yedek/dizijpg.com.$(date +%Y%m%d-%H%M%S)"
rm -f /etc/nginx/sites-enabled/dizijpg.com.yedek-*

python3 - <<'PY'
import io, os, re
f = "/etc/nginx/sites-enabled/dizijpg.com"
yeni = os.environ["YENI_HASH"]
sat = io.open(f, encoding="utf-8").read().split("\n")
degisen = 0
for i, s in enumerate(sat):
    if "script-src 'self' 'wasm-unsafe-eval'" not in s:
        continue          # admin blogunun CSP'si farkli, ona dokunulmaz
    ilk = s
    if yeni not in s:
        s = s.replace("'wasm-unsafe-eval'", "'wasm-unsafe-eval' '%s'" % yeni, 1)
    if "googletagmanager.com" not in s:
        s = s.replace("https://static.cloudflareinsights.com",
                      "https://static.cloudflareinsights.com https://www.googletagmanager.com", 1)
    if "google-analytics.com" not in s:
        s = s.replace("connect-src blob: 'self'",
                      "connect-src blob: 'self' https://*.google-analytics.com"
                      " https://*.analytics.google.com https://*.googletagmanager.com", 1)
        s = s.replace("https://i.ytimg.com;",
                      "https://i.ytimg.com https://*.google-analytics.com;", 1)
    if s != ilk:
        sat[i] = s
        degisen += 1
if degisen:
    io.open(f, "w", encoding="utf-8").write("\n".join(sat))
print("  guncellenen CSP blogu: %d" % degisen)
PY

nginx -t 2>&1 | tail -1
systemctl reload nginx
echo "  nginx yeniden yuklendi"
UZAKTA
fi

# ------------------------------------------------------------------- 2) rsync
if yap 2; then
  echo "### 2/7  web dosyaları (--delete YOK: robots.txt build çıktısında değil)"
  # `--info=...` KULLANILMAZ: macOS 15'te /usr/bin/rsync openrsync, tanımıyor.
  rsync -az --stats -e "$SSH" "$YEREL/" "$S:$UZAK/" | tail -4
fi

# ------------------------------------------------------- 3) paketler canlı mı
if yap 3; then
  echo "### 3/7  yeni paketler canlıda mı"
  for f in $PAKETLER; do
    kod=$(curl -s -o /dev/null -w '%{http_code}' "https://dizijpg.com/$f")
    echo "  $f -> $kod"
    [ "$kod" = "200" ] || { echo "HATA: $f canlıda yok, DURDU"; exit 1; }
  done
fi

# ------------------------------------------------------------------ 4) brotli
if yap 4; then
  echo "### 4/7  brotli (.br) — AYRIK OTURUM"
  # BİTİŞ `pgrep` İLE ARANMAZ: desen, aynı deseni bekleyen eski kabukların
  # KOMUT SATIRINI da yakalıyor (19 Eyl: hiç brotli yokken 4 eşleşme). Bitiş
  # dosyası kendi kendini eşleştiremez ve çıkış kodunu da taşır.
  $SSH "$S" 'bash -s' <<'UZAKTA3'
rm -f /tmp/web-brotli.bitti /tmp/web-brotli.log
setsid nohup bash -c 'bash /opt/dizijpg/web_brotli.sh > /tmp/web-brotli.log 2>&1; echo $? > /tmp/web-brotli.bitti' < /dev/null > /dev/null 2>&1 &
sleep 1
echo "  ayrik baslatildi"
UZAKTA3
  kod=""
  for i in $(seq 1 90); do
    sleep 10
    kod=$($SSH "$S" 'cat /tmp/web-brotli.bitti 2>/dev/null || true')
    [ -n "$kod" ] && { echo "  bitti (~$((i * 10)) sn, çıkış kodu $kod)"; break; }
  done
  [ -n "$kod" ] || { echo "HATA: brotli 15 dk'da bitmedi, DURDU"; exit 1; }
  [ "$kod" = "0" ] || { echo "HATA: brotli kod $kod:"; $SSH "$S" 'tail -20 /tmp/web-brotli.log'; exit 1; }
  $SSH "$S" 'tail -2 /tmp/web-brotli.log'
fi

# --------------------------------------------------------------- 5) doğrulama
if yap 5; then
  echo "### 5/7  doğrulama"
  ana=$(echo "$PAKETLER" | tr ' ' '\n' | grep -E '^main\.[a-f0-9]+\.dart\.js$' | head -1)

  # Düz gövde
  # `curl ... | grep -q` KULLANILMAZ: `grep -q` ilk eşleşmede çıkar, `curl`
  # SIGPIPE alıp 23 döner ve `set -o pipefail` EŞLEŞMİŞ pipeline'ı başarısız
  # sayar (19 Eyl 2026: dağıtım canlıya çıkmışken 5. adım "yeni paket yok"
  # diye durdu). Gövde önce değişkene alınır; grep'in erken çıkışı artık
  # curl'ü öldüremez.
  govde=$(curl -s "https://dizijpg.com/?dagit=$RANDOM")
  case "$govde" in *"$ana"*) ;; *)
    echo "HATA: canlı HTML yeni paketi göstermiyor, DURDU"; exit 1;; esac
  echo "  düz index.html -> $ana TAMAM"

  # BROTLI GÖVDESİ AYRI KONTROL: nginx `brotli_static on`, yani gerçek tarayıcı
  # index.html.br alır. Bayat .br, düz dosya güncelken eski sayfayı servis eder
  # (16 Ağu'da SW sökücüde tam bu oldu) — düz curl bunu GÖRMEZ.
  $SSH "$S" "brotli -dc $UZAK/index.html.br | grep -q '$ana'" \
    || { echo "HATA: index.html.br BAYAT, DURDU"; exit 1; }
  echo "  index.html.br  -> $ana TAMAM"

  csp=$(curl -sI https://dizijpg.com/ | tr -d '\r' | grep -i '^content-security-policy' || true)
  [ -n "$csp" ] || { echo "HATA: CSP başlığı gelmedi, DURDU"; exit 1; }
  case "$csp" in *"$YENI_HASH"*) ;; *)
    echo "HATA: CSP'de yeni hash yok, DURDU"; exit 1;; esac
  echo "  CSP yeni hash  -> TAMAM"

  # Dil kabuğu örneği (46 dilin hepsi aynı üreticiden çıkıyor)
  de=$(curl -s https://dizijpg.com/de/)
  case "$de" in *"$ana"*) echo "  /de/ kabuğu    -> TAMAM";;
    *) echo "  UYARI: /de/ kabuğu eski";; esac

  kod=$(curl -s -o /dev/null -w '%{http_code}' https://dizijpg.com/api/saglik)
  echo "  /api/saglik    -> $kod"
fi

# ------------------------------------------------- 6) eski paketleri temizle
if yap 6; then
  echo "### 6/7  sunucuda ARTIK OLMAYAN paketleri sil"
  # `scp`/`rsync --delete` kullanılmadığı için eski hash'li paketler sunucuda
  # birikiyor; web_brotli.sh onlara da .br üretip diski şişiriyor.
  $SSH "$S" "GUNCEL='$PAKETLER' bash -s" <<'UZAKTA4'
set -euo pipefail
cd /var/www/dizijpg
for f in main.*.dart.js main.dart.js_*.part.js; do
  [ -e "$f" ] || continue
  case " $GUNCEL " in
    *" $f "*) ;;
    *) echo "  siliniyor: $f"; rm -f "$f" "$f.br" ;;
  esac
done
echo "  kalan:"; ls -1 main.*.dart.js main.dart.js_*.part.js | sed 's/^/    /'
UZAKTA4
fi

# ------------------------------------------------- 7) CSP'yi tek hash'e indir
if yap 7; then
  echo "### 7/7  CSP'den ESKİ hash'leri at (yeni betik artık canlı)"
  $SSH "$S" "YENI_HASH='$YENI_HASH' bash -s" <<'UZAKTA5'
set -euo pipefail
python3 - <<'PY'
import io, os, re
f = "/etc/nginx/sites-enabled/dizijpg.com"
yeni = os.environ["YENI_HASH"]
sat = io.open(f, encoding="utf-8").read().split("\n")
atilan = 0
for i, s in enumerate(sat):
    if "script-src 'self' 'wasm-unsafe-eval'" not in s:
        continue
    def sec(m):
        global atilan
        if m.group(1) == yeni:
            return m.group(0)
        atilan += 1
        return ""
    yenis = re.sub(r"'(sha256-[A-Za-z0-9+/=]+)' ?", sec, s)
    # Fazla boslugu temizle ama SATIR BASI GIRINTISINA dokunma (nginx dosyasi
    # girintili; bastaki boslugu ezmek dosyayi okunamaz hale getirir).
    g = re.match(r"^[ \t]*", yenis).group(0)
    sat[i] = g + re.sub(r"  +", " ", yenis[len(g):])
if atilan:
    io.open(f, "w", encoding="utf-8").write("\n".join(sat))
print("  atilan eski hash: %d" % atilan)
PY
nginx -t 2>&1 | tail -1
systemctl reload nginx
UZAKTA5
fi

echo
echo "BİTTİ."
