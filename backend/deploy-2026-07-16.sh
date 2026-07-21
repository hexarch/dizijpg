#!/bin/bash
# dizi.jpg — 2026-07-16 deploy: profil + yorumlar + medya
# Sunucuda /opt/dizijpg içinden çalıştırılır.
set -e
cd /opt/dizijpg

echo "== API imajı yeniden derleniyor =="
docker-compose build api
docker-compose up -d

echo "== DB migrasyonu =="
docker exec -i dizijpg-db psql -U dizijpg -d dizijpg < migrasyon-2026-07-16.sql

echo "== nginx gövde limiti (medya yüklemeleri için) =="
CONF=$(grep -rl "dizijpg" /etc/nginx/sites-enabled/ | head -1)
if ! grep -q "client_max_body_size" "$CONF"; then
  sed -i '/location \/api\//a\        client_max_body_size 35m;' "$CONF"
  nginx -t && systemctl reload nginx
  echo "nginx guncellendi: $CONF"
else
  echo "client_max_body_size zaten var"
fi

echo "== sağlık kontrolü =="
sleep 3
curl -s http://127.0.0.1:8500/saglik
echo
echo "DEPLOY TAMAM"
