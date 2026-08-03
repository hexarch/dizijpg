#!/bin/bash
#
# Cloudflare IP aralık listesini tazeler (güvenlik denetimi §2.2).
#
# NEDEN GEREKLİ
#   dizijpg.com'un 80/443 trafiği artık YALNIZ Cloudflare edge aralıklarından
#   kabul ediliyor (nginx `geo $realip_remote_addr $dizijpg_cf_disi` + `return 444`).
#   Cloudflare bir gün yeni bir aralık eklerse ve biz haberdar olmazsak, o
#   aralıktan gelen GERÇEK ziyaretçiler 444 yer — yani kısmi kesinti olur.
#   Bu betik listeyi günlük tazeler.
#
# GÜVENLİK AĞI (bu betik siteyi kapatamaz)
#   1. Listeler biçim doğrulamasından geçer (geçerli CIDR + asgari aralık sayısı).
#      Kısa/bozuk/HTML bir yanıt gelirse HİÇBİR ŞEY değişmez.
#   2. Değişiklik yoksa dosyaya dokunulmaz, nginx yeniden yüklenmez (gürültü yok).
#   3. Değişiklik varsa önce yedek alınır, sonra `nginx -t` çalıştırılır.
#      Test BAŞARISIZ olursa yedek geri yüklenir ve nginx'e dokunulmaz.
#   4. Her gerçek değişiklikte yöneticiye mail gider.
#
# Kurulum (sunucuda):
#   install -m 755 cf_ip_tazele.sh /usr/local/bin/cf-ip-tazele.sh
#   cron:  30 4 * * * /usr/local/bin/cf-ip-tazele.sh >> /var/log/cf-ip-tazele.log 2>&1
#
# Elle çalıştırma / deneme:  /usr/local/bin/cf-ip-tazele.sh
#
set -uo pipefail

DIZIN="/etc/nginx/cloudflare"
REALIP="$DIZIN/realip.conf"
GEOIZIN="$DIZIN/geo-izin.conf"
ALICI="alicihanceliktht@gmail.com"
GECICI="$(mktemp -d)"
trap 'rm -rf "$GECICI"' EXIT

zaman() { date '+%Y-%m-%d %H:%M:%S %Z'; }
gunluk() { echo "[$(zaman)] $*"; }

mail_at() {
  printf 'Subject: %s\nFrom: dizi.jpg CF-IP tazeleyici <noreply@dizijpg.com>\nTo: %s\n\n%s\n' \
    "$1" "$ALICI" "$2" | /usr/sbin/sendmail -f noreply@dizijpg.com "$ALICI" 2>/dev/null
}

# --- 1. Listeleri indir -----------------------------------------------------
V4="$(curl -fsS --max-time 25 https://www.cloudflare.com/ips-v4)" || {
  gunluk "HATA: ips-v4 indirilemedi, degisiklik yapilmadi."; exit 1; }
V6="$(curl -fsS --max-time 25 https://www.cloudflare.com/ips-v6)" || {
  gunluk "HATA: ips-v6 indirilemedi, degisiklik yapilmadi."; exit 1; }

# --- 2. Biçim ve asgari sayı doğrulaması ------------------------------------
# Sadece geçerli CIDR satırlarını al; başka her şey (HTML hata sayfası, captcha,
# kesilmiş yanıt) elenir ve asgari sayı testine takılır.
T4="$(printf '%s\n' "$V4" | grep -E '^[0-9]{1,3}(\.[0-9]{1,3}){3}/[0-9]{1,2}$' || true)"
T6="$(printf '%s\n' "$V6" | grep -E '^[0-9a-fA-F:]+/[0-9]{1,3}$'              || true)"
n4="$(printf '%s\n' "$T4" | grep -c . || true)"
n6="$(printf '%s\n' "$T6" | grep -c . || true)"

if [ "$n4" -lt 10 ] || [ "$n6" -lt 5 ]; then
  gunluk "HATA: liste supheli (IPv4=$n4, IPv6=$n6). Degisiklik YAPILMADI."
  mail_at "dizi.jpg: Cloudflare IP listesi supheli" \
"Cloudflare IP listesi indirildi ama dogrulamayi gecemedi.
Gecerli IPv4 araligi: $n4 (asgari 10)
Gecerli IPv6 araligi: $n6 (asgari 5)

Hicbir dosya degistirilmedi, nginx'e dokunulmadi. Site etkilenmedi.
Elle kontrol:  curl https://www.cloudflare.com/ips-v4"
  exit 1
fi

# --- 3. Aday dosyaları üret -------------------------------------------------
{
  echo "# OTOMATIK URETILDI - elle duzenlemeyin."
  echo "# Kaynak: https://www.cloudflare.com/ips-v4 + ips-v6"
  echo "# Uretim: $(zaman)"
  printf '%s\n%s\n' "$T4" "$T6" | grep . | sed 's/^/set_real_ip_from /; s/$/;/'
} > "$GECICI/realip.conf"

{
  echo "# OTOMATIK URETILDI - elle duzenlemeyin."
  echo "# geo blogu icinde kullanilir: CF edge araliklari -> 0 (izinli)."
  echo "# Uretim: $(zaman)"
  printf '%s\n%s\n' "$T4" "$T6" | grep . | sed 's/$/ 0;/'
} > "$GECICI/geo-izin.conf"

# --- 4. Değişiklik var mı? (Uretim satırını yok sayarak karşılaştır) --------
suz() { grep -v '^# Uretim:' "$1" 2>/dev/null; }
if suz "$GECICI/realip.conf" | diff -q - <(suz "$REALIP") >/dev/null 2>&1 &&
   suz "$GECICI/geo-izin.conf" | diff -q - <(suz "$GEOIZIN") >/dev/null 2>&1; then
  gunluk "Degisiklik yok (IPv4=$n4, IPv6=$n6). nginx'e dokunulmadi."
  exit 0
fi

gunluk "DEGISIKLIK VAR (IPv4=$n4, IPv6=$n6). Uygulaniyor..."
FARK="$( { suz "$REALIP" 2>/dev/null || true; } | diff -u - <(suz "$GECICI/realip.conf") || true)"

# --- 5. Yedekle, uygula, doğrula -------------------------------------------
DAMGA="$(date '+%Y%m%d-%H%M%S')"
YEDEK="/root/cf-ip-yedek-$DAMGA"
mkdir -p "$YEDEK"
cp -a "$REALIP" "$GEOIZIN" "$YEDEK/" 2>/dev/null

install -m 644 "$GECICI/realip.conf"   "$REALIP"
install -m 644 "$GECICI/geo-izin.conf" "$GEOIZIN"

if ! nginx -t >"$GECICI/test.out" 2>&1; then
  gunluk "HATA: nginx -t BASARISIZ. Yedek geri yukleniyor."
  cp -a "$YEDEK/realip.conf" "$REALIP"
  cp -a "$YEDEK/geo-izin.conf" "$GEOIZIN"
  nginx -t >/dev/null 2>&1
  mail_at "dizi.jpg: CF IP tazeleme BASARISIZ (geri alindi)" \
"Yeni Cloudflare IP listesi uygulandi ama 'nginx -t' basarisiz oldu.
Eski liste GERI YUKLENDI, nginx yeniden yuklenmedi. Site etkilenmedi.

nginx -t ciktisi:
$(cat "$GECICI/test.out")

Yedek: $YEDEK"
  exit 1
fi

systemctl reload nginx
gunluk "Uygulandi ve nginx yeniden yuklendi. Yedek: $YEDEK"
mail_at "dizi.jpg: Cloudflare IP listesi guncellendi" \
"Cloudflare IP araliklari degisti; liste guncellendi ve nginx yeniden yuklendi.

Gecerli aralik sayisi: IPv4=$n4, IPv6=$n6
Yedek: $YEDEK

Fark (realip.conf):
$FARK

Kontrol:
  curl -s -o /dev/null -w '%{http_code}\\n' https://dizijpg.com/api/saglik   -> 200 olmali
  curl -sk -H 'Host: dizijpg.com' https://154.53.163.3/api/saglik            -> engellenmis olmali"
exit 0
