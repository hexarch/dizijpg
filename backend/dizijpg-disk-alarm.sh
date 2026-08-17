#!/bin/bash
# dizi.jpg DİSK ALARMI — güvenlik denetimi 2026-08-17 §3.1.
#
# NEDEN AYRI BETİK: `dizijpg-saglik.sh` dakikada bir DIŞARIDAN HTTP yoklar ve
# tek bir durum dosyası tutar. Disk ölçümü farklı bir soru, farklı bir eşik ve
# farklı bir sıklık ister; aynı betiğe sıkıştırmak iki sinyali tek sayaca
# bağlar ve "site ayakta ama disk doluyor" hâli kaybolurdu.
#
# NEDEN GEREKLİ: §3.1 kapısı boş alan 10 GB'ın altına inince yüklemeleri 507'ye
# düşürür — yani DİSK DOLARSA KULLANICI ÖNCE ÖĞRENİR, işletmeci sonra. Bu betik
# sırayı tersine çevirir. Kapı felaketi önler; alarm felaketin yaklaştığını
# haber verir.
#
# EŞİK 82: kapı %  boş 10 GB'da (80 GB diskte ~%87 doluluk) devreye giriyor.
# Alarm ondan ÖNCE, %82'de ötsün ki müdahale için yer kalsın.
#
# Spam yağmuru yok: eşiği ilk geçişte BİR kez uyarır, normale dönünce
# "toparlandı" der ve bayrağı sıfırlar (saglik.sh ile aynı desen).

ALICI="alicihanceliktht@gmail.com"
DURUM="/var/lib/dizijpg-disk.durum"
ESIK=82          # yüzde doluluk
BOL="/"

kullanim=$(df --output=pcent "$BOL" 2>/dev/null | tail -1 | tr -dc '0-9')
bos_gb=$(df -BG --output=avail "$BOL" 2>/dev/null | tail -1 | tr -dc '0-9')
[ -z "$kullanim" ] && exit 0   # ölçemediysek sessiz çık (yanlış alarm yok)

uyarildi=0
[ -f "$DURUM" ] && read -r uyarildi < "$DURUM"
[ -z "$uyarildi" ] && uyarildi=0

mail_at() {
  printf 'Subject: %s\nFrom: dizi.jpg izleyici <noreply@dizijpg.com>\nTo: %s\n\n%s\n' \
    "$1" "$ALICI" "$2" | /usr/sbin/sendmail -f noreply@dizijpg.com "$ALICI"
}

if [ "$kullanim" -ge "$ESIK" ]; then
  if [ "$uyarildi" = "0" ]; then
    mail_at "dizi.jpg DİSK UYARISI (%$kullanim dolu)" "Kök bölüm %$kullanim dolu; boş alan ${bos_gb} GB.
Zaman: $(date '+%d.%m.%Y %H:%M:%S %Z')

Boş alan 10 GB'ın ALTINA inerse yükleme uçları 507 dönmeye başlar
(güvenlik denetimi 2026-08-17 §3.1 disk eşiği kapısı) — yani kullanıcılar
fotoğraf/ses gönderemez. Veritabanı ve gece yedeği de aynı diskte.

En büyük tüketiciler:
$(du -sh /srv/dizijpg-veri/medya /srv/dizijpg-veri/avatarlar /opt/dizijpg/yedekler /var/lib/docker 2>/dev/null | sort -rh | head -6)

Hızlı kontrol:
  df -h /
  docker system df
  ls -lat /opt/dizijpg/yedekler | head
Kapının durumu admin panelinde: Depolama sekmesi (bos_kullanilabilir / esik / kapi_acik)."
    echo "1" > "$DURUM"
  fi
else
  if [ "$uyarildi" = "1" ]; then
    mail_at "dizi.jpg disk TOPARLANDI (%$kullanim)" "Kök bölüm %$kullanim dolu; boş alan ${bos_gb} GB.
Eşiğin (%$ESIK) altına inildi: $(date '+%d.%m.%Y %H:%M:%S %Z')"
  fi
  echo "0" > "$DURUM"
fi
