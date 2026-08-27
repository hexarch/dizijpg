#!/usr/bin/env bash
# dizi.jpg — migrasyonu SUNUCUDA doğru rolle uygular.
#
# NEDEN BU BETİK VAR (27 Ağu 2026):
# Veritabanında iki giriş yapabilen rol var:
#   · `dizijpg`      — tabloların SAHİBİ (.env: DB_SIFRE)
#   · `dizijpg_app`  — uygulamanın kullandığı EN AZ YETKİLİ rol
#                      (.env: DB_APP_KULLANICI / DB_APP_SIFRE)
#
# Tuzak: app rolüyle YENİ TABLO yaratmak çalışıyor, ama mevcut bir tabloyu
# değiştirmek çalışmıyor:
#     ERROR:  must be owner of table izlemeler
# 27 Ağu'da `izlemeler.tarih_kesin` migrasyonu tam da buna takıldı. Hata
# migrasyonun ORTASINDA gelirse yarısı uygulanmış olabilir; bu betik
# `ON_ERROR_STOP=1` ile ilk hatada durur.
#
# KULLANIM (yerelden):
#   scp backend/migrasyon-YYYY-MM-DD.sql root@154.53.163.3:/opt/dizijpg/
#   ssh root@154.53.163.3 'bash -s' < araclar/migrasyon_uygula.sh migrasyon-YYYY-MM-DD.sql
# ya da doğrudan sunucuda:
#   bash /opt/dizijpg/araclar/migrasyon_uygula.sh migrasyon-YYYY-MM-DD.sql
#
# NOT: `docker compose` (v2) sunucuda YOK; v1 (`docker-compose`) var. Bu betik
# compose kullanmıyor, doğrudan `docker exec` ile db konteynerine giriyor.
set -euo pipefail

DIZIN=${DIZIJPG_DIZIN:-/opt/dizijpg}
DB_KONTEYNER=${DB_KONTEYNER:-dizijpg-db}
DOSYA=${1:-}

if [ -z "$DOSYA" ]; then
  echo "kullanım: $0 <migrasyon-dosyasi.sql>" >&2
  exit 64
fi

cd "$DIZIN"
[ -f "$DOSYA" ] || { echo "dosya yok: $DIZIN/$DOSYA" >&2; exit 66; }

SIFRE=$(grep -oP '(?<=^DB_SIFRE=).*' .env || true)
if [ -z "$SIFRE" ]; then
  echo "HATA: .env icinde DB_SIFRE yok — sahip rolunun sifresi gerekli." >&2
  exit 78
fi

echo "→ $DOSYA · sahip rolü (dizijpg) · konteyner $DB_KONTEYNER"

# -h 127.0.0.1 ZORUNLU: soket üzerinden bağlanınca peer kimlik doğrulaması
# konteynerdeki `postgres` sistem kullanıcısını arıyor ve rol bulunamıyor
# ("role postgres does not exist"). TCP'ye zorlayınca parola yolu işliyor.
docker exec -i -e PGPASSWORD="$SIFRE" "$DB_KONTEYNER" \
  psql -U dizijpg -d dizijpg -h 127.0.0.1 -v ON_ERROR_STOP=1 -f /dev/stdin < "$DOSYA"

echo "✓ migrasyon uygulandı: $DOSYA"
echo "  ŞİMDİ: API'yi yenile ve konteynerdeki kodu GREPLE doğrula —"
echo "  docker-compose up -d --build api && docker exec dizijpg-api grep -c <yeni-sey> /app/server.js"
