#!/usr/bin/env bash
# SUNUCUDA koşar (16 Eyl 2026): belirtilen mesajın albüm fotoğraflarını
# yedekleyip uzun kenarı 3840'a küçültür ve medya_olculer'i günceller.
# Kullanım: bash dm-medya-kucult.sh <mesaj_id>
# Yedekler: /veri/medya/kucultme-yedek/ (konteyner içi = medya volume'ü)
set -euo pipefail
ID=${1:?mesaj id}
docker exec dizijpg-api mkdir -p /veri/medya/kucultme-yedek
docker exec dizijpg-db psql -U dizijpg -d dizijpg -tc \
  "SELECT unnest(coalesce(medyalar, ARRAY[medya])) FROM mesajlar WHERE id=$ID" \
  | sed 's#.*/##' | tr -d ' ' | grep -E '\.(jpg|jpeg|png)$' | while read -r f; do
  boyut=$(docker exec dizijpg-api ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "/veri/medya/$f" | head -1)
  en=${boyut%x*}; boy=${boyut#*x}
  if [ "${en:-0}" -le 3840 ] && [ "${boy:-0}" -le 3840 ]; then echo "$f $boyut — zaten küçük"; continue; fi
  docker exec dizijpg-api cp -n "/veri/medya/$f" "/veri/medya/kucultme-yedek/$f"
  uz=${f##*.}; q=""; [ "$uz" != "png" ] && q="-q:v 3"
  docker exec dizijpg-api sh -c "ffmpeg -y -v error -i /veri/medya/$f -vf \"scale=w='min(3840,iw)':h='min(3840,ih)':force_original_aspect_ratio=decrease:flags=lanczos\" -frames:v 1 -update 1 $q /veri/medya/$f.kucuk.$uz && mv /veri/medya/$f.kucuk.$uz /veri/medya/$f"
  yeni=$(docker exec dizijpg-api ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "/veri/medya/$f" | head -1)
  bayt=$(docker exec dizijpg-api stat -c %s "/veri/medya/$f")
  docker exec dizijpg-db psql -U dizijpg -d dizijpg -qc \
    "INSERT INTO medya_olculer (medya, en, boy) VALUES ('/medya/$f', ${yeni%x*}, ${yeni#*x}) ON CONFLICT (medya) DO UPDATE SET en=EXCLUDED.en, boy=EXCLUDED.boy"
  echo "$f $boyut → $yeni ($bayt bayt)"
done
echo "TAMAM — yedekler /veri/medya/kucultme-yedek/"
