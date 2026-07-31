#!/bin/bash
# dizi.jpg dış erişim izleyicisi.
#
# NEDEN: 31 Tem'de Cloudflare→sunucu hattı ~20 dk koptu (522). Sunucu, nginx ve
# konteynerler sağlamdı; sorunu ancak testçiler söyleyince öğrendik. Uygulamanın
# kendi hata günlüğü de yakalayamaz, çünkü istekler sunucuya HİÇ ulaşmıyor.
#
# Bu betik sunucudan ÇIKIP herkesin kullandığı genel adrese (Cloudflare üzerinden)
# istek atar — yani kullanıcının gördüğü yolu ölçer. Üst üste 3 hatada bir kez
# mail atar, düzelince "toparlandı" maili gelir (spam yağmuru olmaz).

ADRES="https://dizijpg.com/api/saglik"
ALICI="alicihanceliktht@gmail.com"
DURUM="/var/lib/dizijpg-saglik.durum"   # ardışık hata sayacı + uyarı bayrağı
ESIK=3

kod=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$ADRES" 2>/dev/null)

hata=0
uyarildi=0
[ -f "$DURUM" ] && read -r hata uyarildi < "$DURUM"
[ -z "$hata" ] && hata=0
[ -z "$uyarildi" ] && uyarildi=0

mail_at() {
  printf 'Subject: %s\nFrom: dizi.jpg izleyici <noreply@dizijpg.com>\nTo: %s\n\n%s\n' \
    "$1" "$ALICI" "$2" | /usr/sbin/sendmail -f noreply@dizijpg.com "$ALICI"
}

if [ "$kod" = "200" ]; then
  if [ "$uyarildi" = "1" ]; then
    mail_at "dizi.jpg TOPARLANDI" "$ADRES yeniden 200 dönüyor.
Kesinti bitti: $(date '+%d.%m.%Y %H:%M:%S %Z')"
  fi
  echo "0 0" > "$DURUM"
else
  hata=$((hata + 1))
  if [ "$hata" -ge "$ESIK" ] && [ "$uyarildi" = "0" ]; then
    mail_at "dizi.jpg ERİŞİLEMİYOR (HTTP $kod)" "$ADRES son $hata denemede yanıt vermedi (HTTP $kod).
Zaman: $(date '+%d.%m.%Y %H:%M:%S %Z')

522/523/524 ise Cloudflare sunucuya ulaşamıyor demektir.
Sunucu içi hızlı kontrol:
  systemctl is-active nginx
  cd /opt/dizijpg && docker-compose ps
  curl -sk -o /dev/null -w '%{http_code}\n' https://127.0.0.1/ -H 'Host: dizijpg.com'
Yerelde 200 dönüyorsa sorun Cloudflare-sunucu hattındadır."
    uyarildi=1
  fi
  echo "$hata $uyarildi" > "$DURUM"
fi
