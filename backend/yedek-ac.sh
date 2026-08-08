#!/bin/bash
# dizi.jpg — ŞİFRELİ yedeği açma / geri yükleme yardımcısı.
#
# Sunucudaki yeri: /opt/dizijpg/yedek-ac.sh
#
# "Açamadığın yedek, yedek değildir." Bu betik iki işi kolaylaştırır:
#   1) yedek-ac.sh <dosya.sql.gz.gpg>              -> düz SQL'i STDOUT'a döker
#   2) yedek-ac.sh --dogrula <dosya.sql.gz.gpg>    -> yalnız açılabilirliği ölçer
#
# GERİ YÜKLEME (yıkıcı! önce ne yaptığını bil):
#   /opt/dizijpg/yedek-ac.sh /opt/dizijpg/yedekler/dizijpg-YYYYMMDD-HHMM.sql.gz.gpg \
#     | docker exec -i dizijpg-db psql -U dizijpg -d dizijpg
#
# ANAHTAR: /opt/dizijpg/yedek-anahtar.key (600 root:root). Sunucu tamamen
# kaybolduysa parola yöneticisindeki kopyayı geçici bir dosyaya yazıp
# ANAHTAR=/yol/anahtar ile çalıştır.

set -euo pipefail

ANAHTAR=${ANAHTAR:-/opt/dizijpg/yedek-anahtar.key}
DOGRULA=0
if [ "${1:-}" = "--dogrula" ]; then DOGRULA=1; shift; fi
DOSYA=${1:-}

if [ -z "$DOSYA" ] || [ ! -r "$DOSYA" ]; then
  echo "Kullanım: $0 [--dogrula] <yedek dosyası>" >&2
  echo "Mevcut yedekler:" >&2
  ls -1t /opt/dizijpg/yedekler/ 2>/dev/null | head -20 >&2 || true
  exit 1
fi

coz() {
  case "$DOSYA" in
    *.gpg)
      if [ ! -r "$ANAHTAR" ]; then
        echo "HATA: anahtar okunamıyor: $ANAHTAR" >&2; exit 1
      fi
      # --pinentry-mode loopback ŞART: gpg 2.x aksi hâlde parola kutusu
      # açmaya çalışır ve TTY olmayan ortamda (cron, betik) başarısız olur.
      export GNUPGHOME=${GNUPGHOME:-/root/.gnupg}
      mkdir -p "$GNUPGHOME"; chmod 700 "$GNUPGHOME"
      gpg --batch --quiet --decrypt --pinentry-mode loopback \
          --passphrase-file "$ANAHTAR" "$DOSYA" | gunzip ;;
    *.gz)  gunzip -c "$DOSYA" ;;
    *)     cat "$DOSYA" ;;
  esac
}

if [ "$DOGRULA" = "1" ]; then
  # Satır say + ilk satırı göster. Bütünlük bozuksa gpg burada HATA verir
  # (simetrik modda MDC var), sessizce bozuk SQL üretmez.
  SATIR=$(coz | wc -l)
  echo "DOSYA   : $DOSYA"
  echo "BOYUT   : $(stat -c %s "$DOSYA") bayt"
  echo "SQL SATIR: $SATIR"
  echo "İLK SATIR: $(coz | head -1)"
  if [ "$SATIR" -lt 100 ]; then
    echo "UYARI: satır sayısı şüpheli derecede az — yedek eksik olabilir." >&2
    exit 1
  fi
  echo "SONUÇ   : açılabilir."
else
  coz
fi
