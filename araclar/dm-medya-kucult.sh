#!/usr/bin/env bash
# SUNUCUDA koşar (16 Eyl 2026): bir mesajın fotoğrafları için `<ad>.k.jpg`
# KÜÇÜK KOPYA üretir (uzun kenar 1600). ORİJİNAL DOKUNULMAZ — tam ekran ve
# indirme orijinali kullanır, sohbet ızgarası kopyayı çeker.
# Kullanım: bash dm-medya-kucult.sh <mesaj_id>
set -euo pipefail
ID=${1:?mesaj id}
docker exec dizijpg-db psql -U dizijpg -d dizijpg -tc \
  "SELECT unnest(coalesce(medyalar, ARRAY[medya])) FROM mesajlar WHERE id=$ID" \
  | sed 's#.*/##' | tr -d ' ' | grep -E '\.(jpg|jpeg|png|webp)$' | while read -r f; do
  if docker exec dizijpg-api test -f "/veri/medya/$f.k.jpg"; then echo "$f — kopya zaten var"; continue; fi
  boyut=$(docker exec dizijpg-api ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "/veri/medya/$f" | head -1)
  en=${boyut%x*}; boy=${boyut#*x}
  if [ "${en:-0}" -le 1600 ] && [ "${boy:-0}" -le 1600 ]; then echo "$f $boyut — küçük, kopya gerekmez"; continue; fi
  docker exec dizijpg-api sh -c "ffmpeg -y -v error -i /veri/medya/$f -vf \"scale=w='min(1600,iw)':h='min(1600,ih)':force_original_aspect_ratio=decrease:flags=lanczos\" -frames:v 1 -update 1 -q:v 4 /veri/medya/$f.k.gecici.jpg && mv /veri/medya/$f.k.gecici.jpg /veri/medya/$f.k.jpg"
  yeni=$(docker exec dizijpg-api ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "/veri/medya/$f.k.jpg" | head -1)
  bayt=$(docker exec dizijpg-api stat -c %s "/veri/medya/$f.k.jpg")
  echo "$f $boyut → kopya $yeni ($bayt bayt); orijinal yerinde"
done
echo "TAMAM — ızgara kopyaları API yeniden başlatılmadan da görür (dosya varlığına bakar)"
