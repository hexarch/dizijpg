#!/usr/bin/env bash
# dizi.jpg admin paneli IP beyaz listesini TEK dinamik IPv4 (+ isteğe bağlı
# TEK dinamik IPv6 /64) ile günceller.
# Kullanım: dizijpg-admin-ip.sh <ipv4> [ipv6-önek/64]
# Sunucuda /usr/local/bin/dizijpg-admin-ip.sh olarak durur.
# - nginx geo bloğunda 127.0.0.1 dışındaki tek IPv4/32 satırını ve ::1 dışındaki
#   tek IPv6 satırını değiştirir (sites-enabled GERÇEK DOSYA; ikisi de yazılır)
# - /opt/dizijpg/.env ADMIN_IPLER'i "<ipv4>,<ipv6cidr>" yapar; IPv6 verilmezse
#   mevcut IPv6 girdileri korunur
# - /opt/dizijpg/admin-ip/ipler.txt'i ayni degerle yazar (Node SICAK okur;
#   konteyner yeniden yaratilmaz — 5 Eyl 2026, bkz. asagidaki not)
# Deponun kaynagi: backend/dizijpg-admin-ip.sh (robots.txt ile ayni gerekce:
# sunucudaki kopya izsiz kalmasin).
# - Değişiklik yoksa hiçbir şeye dokunmaz (idempotent)
set -euo pipefail

IP="${1:-}"; IP6="${2:-}"
[[ "$IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || { echo "HATA: geçersiz IPv4: '$IP'" >&2; exit 2; }
if [[ -n "$IP6" ]]; then
  [[ "$IP6" =~ ^[0-9a-fA-F:]+/[0-9]{1,3}$ ]] || { echo "HATA: geçersiz IPv6 CIDR: '$IP6'" >&2; exit 2; }
fi

ENABLED=/etc/nginx/sites-enabled/dizijpg.com
AVAILABLE=/etc/nginx/sites-available/dizijpg.com
ENV=/opt/dizijpg/.env
SABIT=/opt/dizijpg/admin-ip-sabit   # elle acilan kalici IP/CIDR listesi (satir basina bir kayit)
DAMGA=$(date +%Y%m%d-%H%M%S)
DEGISTI=0

# geo bloğundaki dinamik satırı değiştirir/ekler: $1 dosya, $2 tür (4|6), $3 yeni değer
geo_satir() {
  local dosya="$1" tur="$2" yeni="$3" mevcut etiket
  etiket="$(basename "$(dirname "$dosya")")"
  if [[ "$tur" == 4 ]]; then
    mevcut=$(awk '/geo \$dizijpg_admin_izinli/{b=1} b&&/^}/{b=0} b&&/^[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\/[0-9]+[[:space:]]+1;/&&!/127\.0\.0\.1/{print $1}' "$dosya" | head -1)
  else
    mevcut=$(awk '/geo \$dizijpg_admin_izinli/{b=1} b&&/^}/{b=0} b&&/^[[:space:]]*[0-9a-fA-F:]+\/[0-9]+[[:space:]]+1;/&&!/::1\/128/{print $1}' "$dosya" | head -1)
  fi
  if [[ "$mevcut" == "$yeni" ]]; then echo "nginx $etiket v$tur: zaten $yeni"; return; fi
  [[ -f "/root/nginx-yedek-dizijpg-$etiket-$DAMGA.conf" ]] || cp -a "$dosya" "/root/nginx-yedek-dizijpg-$etiket-$DAMGA.conf"
  if [[ -n "$mevcut" ]]; then
    awk -v yeni="$yeni" -v eski="$mevcut" '
      /geo \$dizijpg_admin_izinli/{b=1} b&&/^}/{b=0}
      b && $1==eski && !d { $0="    " yeni " 1;"; d=1 }
      {print}' "$dosya" > "$dosya.tmp"
  else
    awk -v yeni="    $yeni 1;" '
      /geo \$dizijpg_admin_izinli/{b=1} b&&/^}/{b=0}
      {print} b && /::1\/128/ && !d { print yeni; d=1 }' "$dosya" > "$dosya.tmp"
  fi
  mv "$dosya.tmp" "$dosya"
  echo "nginx $etiket v$tur: ${mevcut:-yok} -> $yeni"
  DEGISTI=1
}

# SABIT listedeki girdiyi geo blogunun SONUNA (kapanis susunden once) ekler.
# Sona eklenir cunku geo_satir "127.0.0.1 disindaki ILK IPv4/32" satirini dinamik
# kabul edip uzerine yazar; sabit kayit onde olsaydi silinirdi.
geo_sabit() {
  local dosya="$1" deger="$2" etiket blok
  etiket="$(basename "$(dirname "$dosya")")"
  blok=$(awk '/geo \$dizijpg_admin_izinli/{b=1} b{print} b&&/^}/{b=0}' "$dosya")
  grep -qE "^[[:space:]]*${deger//./\\.}[[:space:]]+1;" <<< "$blok" && return
  [[ -f "/root/nginx-yedek-dizijpg-$etiket-$DAMGA.conf" ]] || cp -a "$dosya" "/root/nginx-yedek-dizijpg-$etiket-$DAMGA.conf"
  awk -v yeni="    $deger 1;" '/geo \$dizijpg_admin_izinli/{b=1} b&&/^}/{print yeni; b=0} {print}' "$dosya" > "$dosya.tmp"
  mv "$dosya.tmp" "$dosya"
  echo "nginx $etiket sabit: + $deger"
  DEGISTI=1
}

# SABIT dosyasindaki kayitlari oku (yorum/bosluk temizlenmis)
SABITLER=()
if [[ -f "$SABIT" ]]; then
  while read -r s || [[ -n "$s" ]]; do
    s="${s%%#*}"; s="${s// /}"; s="${s//$'\t'/}"
    if [[ -n "$s" ]]; then SABITLER+=("$s"); fi
  done < "$SABIT"
fi

for f in "$ENABLED" "$AVAILABLE"; do
  geo_satir "$f" 4 "$IP/32"
  [[ -n "$IP6" ]] && geo_satir "$f" 6 "$IP6"
  for s in "${SABITLER[@]:-}"; do
    [[ -z "$s" ]] && continue
    if [[ "$s" == */* ]]; then geo_sabit "$f" "$s"
    elif [[ "$s" == *:* ]]; then geo_sabit "$f" "$s/128"
    else geo_sabit "$f" "$s/32"; fi
  done
done

# .env
satir=$(grep -E '^ADMIN_IPLER=' "$ENV" || true)
deger="${satir#ADMIN_IPLER=}"
IFS=',' read -ra parcalar <<< "$deger"
yeni_parcalar=("$IP")
if [[ -n "$IP6" ]]; then
  yeni_parcalar+=("$IP6")
else
  for p in "${parcalar[@]}"; do p="${p// /}"; [[ "$p" == *:* ]] && yeni_parcalar+=("$p"); done
fi
for s in "${SABITLER[@]:-}"; do
  [[ -z "$s" ]] && continue
  var=0; for v in "${yeni_parcalar[@]}"; do if [[ "$v" == "$s" ]]; then var=1; fi; done
  if [[ $var -eq 0 ]]; then yeni_parcalar+=("$s"); fi
done
yeni_deger=$(IFS=','; echo "${yeni_parcalar[*]}")
ENV_DEGISTI=0
if [[ "$deger" != "$yeni_deger" ]]; then
  cp -a "$ENV" "$ENV.yedek-$DAMGA"
  if [[ -n "$satir" ]]; then sed -i "s|^ADMIN_IPLER=.*|ADMIN_IPLER=$yeni_deger|" "$ENV"
  else echo "ADMIN_IPLER=$yeni_deger" >> "$ENV"; fi
  echo ".env ADMIN_IPLER: $deger -> $yeni_deger"; ENV_DEGISTI=1
else
  echo ".env ADMIN_IPLER: zaten $yeni_deger"
fi

if [[ $DEGISTI -eq 1 ]]; then
  nginx -t 2>&1 | tail -1
  systemctl reload nginx
  canli=$(nginx -T 2>/dev/null | grep -A8 'geo $dizijpg_admin_izinli')
  grep -q "$IP/32" <<< "$canli" && echo "nginx canlı: $IP/32 doğrulandı" || { echo "HATA: nginx -T'de $IP yok" >&2; exit 1; }
  if [[ -n "$IP6" ]]; then grep -q "$IP6" <<< "$canli" && echo "nginx canlı: $IP6 doğrulandı" || { echo "HATA: nginx -T'de $IP6 yok" >&2; exit 1; }; fi
fi
# SICAK LISTE (5 Eyl 2026): konteyner ARTIK YENIDEN YARATILMAZ.
# Eskiden burada `docker-compose up -d api` vardi: .env degisince konteyner
# yeniden yaratiliyor, her seferinde 10-30 sn 502 penceresi aciliyordu ve
# IP gunde 3-5 kez degistigi icin Googlebot bunlara denk geliyordu (GSC
# "Sunucu hatasi (5xx)" 37 URL, nginx error.log gunde ~10 "connect() failed").
# Simdi liste /opt/dizijpg/admin-ip/ipler.txt'e yazilir; compose bu dizini
# /admin-ip olarak SALT-OKUNUR baglar, Node dosyayi 2 sn'de bir yeniden okur
# (server.js: adminIpListesi). .env yine guncellenir: dosya yokken / yeniden
# baslatmada yedek kaynak odur.
# Atomik yazim (gecici dosya + mv): Node yarim satir okumasin. Dizin bagli
# oldugu icin yeni inode konteynerde de gorunur.
IPDIZIN=/opt/dizijpg/admin-ip
IPDOSYA=$IPDIZIN/ipler.txt
mkdir -p "$IPDIZIN"; chmod 755 "$IPDIZIN"
if [[ ! -f "$IPDOSYA" ]] || [[ "$(cat "$IPDOSYA" 2>/dev/null)" != "$yeni_deger" ]]; then
  printf '%s\n' "$yeni_deger" > "$IPDOSYA.gecici"
  chmod 644 "$IPDOSYA.gecici"
  mv -f "$IPDOSYA.gecici" "$IPDOSYA"
  echo "admin-ip/ipler.txt: $yeni_deger"
  # Dogrulama: konteyner dosyayi GORUYOR mu? Gormuyorsa bag eksiktir (compose
  # eski) ve Node env'e dusmustur — o durumda eski yol: konteyneri yenile.
  KONTEYNER=$(cd /opt/dizijpg && docker-compose ps -q api)
  if docker exec "$KONTEYNER" cat /admin-ip/ipler.txt 2>/dev/null | grep -qx "$yeni_deger"; then
    echo "konteyner admin-ip/ipler.txt: $yeni_deger doğrulandı"
  else
    echo "UYARI: konteyner /admin-ip/ipler.txt görmüyor (compose bağı eksik?) — konteyner yenileniyor" >&2
    (cd /opt/dizijpg && docker-compose up -d api >/dev/null 2>&1)
    sleep 4
    docker exec "$(cd /opt/dizijpg && docker-compose ps -q api)" cat /admin-ip/ipler.txt 2>/dev/null | grep -qx "$yeni_deger" \
      && echo "konteyner admin-ip/ipler.txt: $yeni_deger doğrulandı (yenilemeden sonra)" \
      || { echo "HATA: konteyner dosyayı hâlâ görmüyor" >&2; exit 1; }
  fi
else
  echo "admin-ip/ipler.txt: zaten $yeni_deger"
fi
echo "TAMAM: $IP ${IP6:-}"
