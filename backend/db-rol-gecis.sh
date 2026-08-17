#!/bin/bash
# dizi.jpg — uygulama DB rolunu SUPER KULLANICIDAN indir (denetim §4.3).
#
# Parola BU SUNUCUDA uretilir ve .env disina HIC cikmaz; betik onu ekrana
# basmaz. Calistirmadan once .env yedeklenir, geri alma en altta.
set -euo pipefail

ENV_YOL=/opt/dizijpg/.env
YEDEK="${ENV_YOL}.rol-oncesi-$(date +%Y%m%d-%H%M%S)"
SQL=/opt/dizijpg/db-rol-en-az-yetki-20260808.sql

cp -a "$ENV_YOL" "$YEDEK"
echo "env yedegi: $YEDEK"

if grep -q '^DB_APP_SIFRE=' "$ENV_YOL"; then
  echo "DB_APP_SIFRE zaten var — yeniden uretilmiyor."
  APP_SIFRE=$(grep '^DB_APP_SIFRE=' "$ENV_YOL" | cut -d= -f2-)
else
  APP_SIFRE=$(openssl rand -hex 24)
  printf '\n# Uygulama DB rolu (guvenlik denetimi 2026-08-17 §4.3).\n' >> "$ENV_YOL"
  printf '# `dizijpg` SUPER KULLANICIDIR ve artik YALNIZ migrasyon icindir.\n' >> "$ENV_YOL"
  printf '# GERI ALMA: DB_APP_KULLANICI=dizijpg + DB_APP_SIFRE=<DB_SIFRE degeri>\n' >> "$ENV_YOL"
  printf 'DB_APP_KULLANICI=dizijpg_app\n' >> "$ENV_YOL"
  printf 'DB_APP_SIFRE=%s\n' "$APP_SIFRE" >> "$ENV_YOL"
  echo "DB_APP_KULLANICI + DB_APP_SIFRE .env'e yazildi (deger basilmadi)"
fi
chmod 600 "$ENV_YOL"

# SQL'i super kullanici olarak uygula.
#
# PAROLAYI TIRNAKLAMA. SQL icinde `ALTER ROLE ... PASSWORD :'app_sifre'`
# yaziyor ve psql tirnaklamayi KENDISI yapiyor. Ilk denemede deger
# "'<parola>'" diye gecildi; parola TIRNAKLARLA BIRLIKTE kaydedildi,
# .env'deki ciplak degerle uyusmadi ve uygulama uc dakika boyunca
# "password authentication failed for user dizijpg_app" (28P01) ile
# 500 dondu. Duzeltmesi ALTER ROLE'u dogru degerle tekrarlamakti.
docker exec -i dizijpg-db psql -U dizijpg -d dizijpg \
  -v ON_ERROR_STOP=1 -v app_sifre="${APP_SIFRE}" -f - < "$SQL"
