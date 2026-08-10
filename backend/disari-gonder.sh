#!/bin/bash
# dizi.jpg — yedekleri SUNUCU DIŞINA kopyalar (yapilacaklar2 A2).
#
# Sunucudaki yeri: /opt/dizijpg/disari-gonder.sh
# Bu dosya deponun KANONİK kopyasıdır; sunucuya scp ile gider.
#
# ⚠ HEDEF HENÜZ SEÇİLMEDİ. Bu betik KURULMADI ve cron'a EKLENMEDİ.
#   Hedefe karar verildikten sonra tek satırla açılır:
#       15 4 * * * /opt/dizijpg/disari-gonder.sh <hedef> >> /opt/dizijpg/disari.log 2>&1
#   (yedek.sh 04:00'te bitiyor; 04:15 güvenli.)
#
# Kullanım:
#   /opt/dizijpg/disari-gonder.sh kullanici@makine:/yedek/dizijpg
#   /opt/dizijpg/disari-gonder.sh /mnt/harici/dizijpg        # takılı disk
#
# =============================================================================
# NEDEN VAR
# =============================================================================
# 10 Ağu 2026 ölçümü: 31 yedeğin TAMAMI `/opt/dizijpg/yedekler` altında, yani
# korudukları veritabanının yanı başında. LVM iki fiziksel diski (sda5 + sdb)
# TEK mantıksal birime bağlamış, RAID YOK, VFree 0. Kök birimde işletim
# sistemi + veritabanı + medya + bütün yedekler var. BİR disk arızalanırsa
# hepsi birden gider. Sunucu dışına bir kopya olmadan geri kalan her önlem
# tek diskin ömrüne bağlıdır.
#
# =============================================================================
# HEDEFİN GÜVENİLİR OLMASI ŞART DEĞİL — AMA ANAHTAR ŞART
# =============================================================================
# `/opt/dizijpg/yedekler` içindeki her şey GPG ile şifreli (`yedek.sh`, AES256).
# Bu yüzden içerik gizliliği açısından hedefin güvenilir olması GEREKMEZ;
# ücretsiz bir bulut kovası bile olur. Şifreleme tam da bunun için seçilmişti.
#
# ⚠ AMA: çözme anahtarı `/opt/dizijpg/yedek-anahtar.key` AYNI MAKİNEDE. Sunucu
#   tamamen kaybolursa dışarıdaki şifreli yedekler ANAHTARSIZ KALIR ve hiçbir
#   işe yaramaz. Anahtarın kullanıcının PAROLA YÖNETİCİSİNDE olduğu
#   DOĞRULANMADAN bu mekanizma yalnızca güvenlik hissi verir.
#   Onay verildiğinde şu boş dosya oluşturulur:
#       touch /opt/dizijpg/anahtar-parola-yoneticisinde-ONAY
#   Dosya yoksa betik her çalıştırmada GÜRÜLTÜLÜ uyarır (ama işi yapar —
#   uyarı yüzünden yedeklemeyi durdurmak daha kötü olurdu).
#
# ANAHTARIN KENDİSİ ASLA GÖNDERİLMEZ. Yalnız `yedekler/` dizini kopyalanır;
# ayrıca aşağıda açık bir `--exclude` ve bir denetim var. Anahtarı şifreli
# yedeklerin yanına koymak, kasanın anahtarını kasanın üstüne bantlamaktır.
#
# =============================================================================
# NEDEN İTME (push) DEĞİL ÇEKME (pull) DAHA İYİ — ve bu betik neden yine itiyor
# =============================================================================
# Bu betik sunucudan hedefe İTER. İtme modelinin zayıflığı: sunucu ele
# geçirilirse saldırganın hedefe yazma yetkisi de vardır, dışarıdaki yedekleri
# de silebilir/şifreleyebilir (fidye yazılımı bunu yapar).
# DAHA GÜVENLİSİ ÇEKMEDİR: hedef makine sunucudan çeker, sunucunun hedefe
# hiçbir kimlik bilgisi olmaz. Kullanıcının kendi bilgisayarında çalıştıracağı
# komut (bu betiğe gerek yok):
#     rsync -a --info=stats2 root@154.53.163.3:/opt/dizijpg/yedekler/ \
#           ~/dizijpg-yedekler/
# Çekme mümkünse ONU SEÇ. Bu betik, hedefin çekemediği durumlar içindir
# (ör. nesne depolama kovası, sürekli açık olmayan bir makine).
# İtme kullanılacaksa hedefteki `authorized_keys` satırı KISITLANMALI:
#     command="rsync --server -logDtpre.iLsfxCIvu . /yedek/dizijpg",
#     no-port-forwarding,no-pty,no-agent-forwarding ssh-ed25519 AAAA...
# =============================================================================

set -euo pipefail
# pipefail ŞART — `yedek.sh` başlığındaki yaşanmış hata: boru zincirinde ilk
# komut çökse bile son komut 0 döndüğü için betik "OK" yazıyordu.

KAYNAK=${KAYNAK:-/opt/dizijpg/yedekler}
ANAHTAR=/opt/dizijpg/yedek-anahtar.key
ONAY=/opt/dizijpg/anahtar-parola-yoneticisinde-ONAY
HEDEF=${1:-}

hata() { echo "$(date '+%Y-%m-%d %H:%M:%S') HATA: $*" >&2; exit 1; }

if [ -z "$HEDEF" ]; then
  echo "Kullanım: $0 <hedef>" >&2
  echo "  hedef: /yerel/yol  ya da  kullanici@makine:/uzak/yol" >&2
  exit 1
fi

[ -d "$KAYNAK" ] || hata "kaynak yedek dizini yok: $KAYNAK"

# Kaynak sağlıklı mı? Boş bir dizini "başarıyla" göndermek, dışarıdaki kopyanın
# boş olduğunu fark etmeden yıllarca beklemek demektir.
ADET=$(find "$KAYNAK" -maxdepth 1 -type f -name '*.gpg' | wc -l)
[ "$ADET" -ge 1 ] || hata "kaynakta hiç şifreli yedek yok ($KAYNAK) — gönderilecek bir şey yok"

# ŞİFRESİZ yedek var mı? Aşağıdaki `--exclude` onları zaten dışarı çıkarmaz;
# burada yalnız HABER VERİLİR. Bilinçli tercih: tek bir düz dosya yüzünden
# bütün dışarı kopyalamayı durdurmak, korumaya çalıştığımız şeyi (dışarıda
# güncel bir kopya bulunması) yok ederdi. Panelden alınan elle yedekler
# şifresiz yazılır ve `yedek.sh` en geç 24 saat içinde şifreler.
DUZ=$(find "$KAYNAK" -maxdepth 1 -type f \( -name '*.sql' -o -name '*.sql.gz' \) | wc -l)
if [ "$DUZ" -gt 0 ]; then
  echo "UYARI: $KAYNAK içinde $DUZ adet ŞİFRESİZ döküm var; DIŞARI GÖNDERİLMEDİ" >&2
  echo "       (--exclude ile atlandı). Şifrelemek için: /opt/dizijpg/yedek.sh" >&2
fi

if [ ! -e "$ONAY" ]; then
  echo "=============================================================" >&2
  echo "UYARI: ÇÖZME ANAHTARININ DIŞ KOPYASI ONAYLANMAMIŞ." >&2
  echo "  Dışarı gönderilen yedekler GPG ile şifreli. Anahtar yalnız" >&2
  echo "  bu makinede: $ANAHTAR" >&2
  echo "  Sunucu kaybolursa dışarıdaki kopyalar AÇILAMAZ." >&2
  echo "  Anahtarı parola yöneticisine kaydettikten sonra:" >&2
  echo "      touch $ONAY" >&2
  echo "=============================================================" >&2
fi

UZAK=0
case "$HEDEF" in *:*) UZAK=1 ;; esac

# --checksum: boyut+tarih değil İÇERİK karşılaştırılır.
# NEDEN (test sırasında yakalandı, 10 Ağu 2026): hedefteki bir yedeği boyutunu
# ve tarihini KORUYARAK bozdum. `--checksum` olmadan rsync dosyayı "güncel"
# sayıp atladı — yani hedefte sessizce bozuk bir yedek kaldı ve betik "OK" dedi.
# Sessiz bozulma bu işin en sinsi hatasıdır (aynı gerekçe `yedek.sh` içinde de
# var). Bedeli: her çalıştırmada iki tarafta ~817 MB okunur, birkaç saniye.
# Gerçekten yavaş kalırsa: HIZLI=1 ile kapatılır (o zaman bozulma FARK EDİLMEZ).
RSYNC=(rsync -a --stats --human-readable)
[ "${HIZLI:-0}" = "1" ] || RSYNC+=(--checksum)
RSYNC+=(
       # Anahtar ASLA gitmesin: dizin dışında ama açıkça da yasakla.
       --exclude 'yedek-anahtar.key' --exclude '*.key'
       # Şifresiz hiçbir şey gitmesin (yukarıdaki denetim ikinci kez burada).
       --exclude '*.sql' --exclude '*.sql.gz')
# --delete YOK ve OLMAYACAK: dışarıdaki kopya, sunucudaki 14 günlük budamadan
# BAĞIMSIZ yaşamalı. Sunucuda bir şey silindi diye dışarıda da silinirse,
# "yanlışlıkla silme" senaryosuna karşı hiçbir koruma kalmaz.
[ "$UZAK" = "1" ] && RSYNC+=(-e "ssh -o BatchMode=yes -o ConnectTimeout=20")

if [ "$UZAK" = "0" ]; then
  mkdir -p "$HEDEF"
  chmod 700 "$HEDEF"
fi

GUNLUK=$(mktemp /tmp/disari-gonder-XXXXXX.log)
trap 'rm -f "$GUNLUK"' EXIT

BAS=$(date +%s)
set +e
"${RSYNC[@]}" "$KAYNAK/" "$HEDEF" > "$GUNLUK" 2>&1
KOD=$?
set -e
if [ "$KOD" -ne 0 ] && [ "$KOD" -ne 24 ]; then
  tail -5 "$GUNLUK" >&2
  hata "rsync başarısız (çıkış kodu $KOD) — hedef: $HEDEF"
fi
grep -E 'Number of regular files transferred|Literal data|Total file size' "$GUNLUK" || true

# --- DOĞRULAMA: dosya "gitti" demek yetmez, KARŞIDA DOĞRU MU ---------------
# HER şifreli yedeğin sha256'sı iki tarafta karşılaştırılır.
#
# NEDEN "yalnız en yeni dosyayı doğrula" YETMEZ (10 Ağu 2026 testinde yakalandı):
# hedefteki ESKİ bir yedeği boyutunu ve tarihini koruyarak bozdum; betik yalnız
# en yeniye baktığı için "OK" yazdı. Yani hedefte bozuk bir yedek olduğu hâlde
# her şey yolunda görünüyordu. Felaket günü açılmayacak dosyayı o gün öğrenmek
# tam olarak kaçınmaya çalıştığımız senaryo (bkz. A3).
# Bedel: iki tarafta ~817 MB okumak, birkaç saniye.
# `sort` TÜM SATIRA ve LC_ALL=C ile uygulanır. `sort -k2` kullanmak hataydı:
# `comm` satırın tamamına göre sıralı girdi bekler, alan bazlı sıralamada
# "file 1 is not in sorted order" deyip karşılaştırmayı çöpe çevirir.
# LC_ALL=C ŞART: yerel ve uzak makinenin yereli (locale) farklıysa sıralama
# farklı çıkar ve iki sağlam manifest bile "uyuşmuyor" görünür.
yerel_manifest() { (cd "$KAYNAK" && LC_ALL=C sha256sum -- *.gpg | LC_ALL=C sort); }
uzak_manifest() {
  if [ "$UZAK" = "0" ]; then
    (cd "$HEDEF" && LC_ALL=C sha256sum -- *.gpg 2>/dev/null | LC_ALL=C sort)
  else
    ssh -o BatchMode=yes -o ConnectTimeout=20 "${HEDEF%%:*}" \
        "cd '${HEDEF#*:}' && LC_ALL=C sha256sum -- *.gpg 2>/dev/null | LC_ALL=C sort"
  fi
}

MY=$(mktemp); MU=$(mktemp)
trap 'rm -f "$GUNLUK" "$MY" "$MU"' EXIT

dogrula() {
  yerel_manifest > "$MY"
  uzak_manifest  > "$MU" || true
  # Yerelde olup hedefte OLMAYAN ya da ÖZETİ TUTMAYAN satırlar:
  LC_ALL=C comm -23 "$MY" "$MU" | wc -l
}

EKSIK=$(dogrula)
if [ "$EKSIK" -gt 0 ]; then
  # Doğrulama ile aktarım arasında yeni bir yedek doğmuş olabilir (04:00 cron).
  # Bir kez daha aktar, tekrar bak; hâlâ kalıyorsa GERÇEK hata.
  echo "  bilgi: $EKSIK dosya hedefte eksik/farklı — ikinci tur"
  set +e; "${RSYNC[@]}" "$KAYNAK/" "$HEDEF" >> "$GUNLUK" 2>&1; KOD=$?; set -e
  [ "$KOD" -eq 0 ] || [ "$KOD" -eq 24 ] || { tail -5 "$GUNLUK" >&2; hata "rsync (2. tur) başarısız: $KOD"; }
  EKSIK=$(dogrula)
  if [ "$EKSIK" -gt 0 ]; then
    echo "--- hedefte eksik/bozuk olanlar ---" >&2
    LC_ALL=C comm -23 "$MY" "$MU" | awk '{print "    " $2}' >&2
    hata "DOĞRULAMA BAŞARISIZ: $EKSIK yedek hedefte eksik ya da bozuk ($HEDEF)"
  fi
fi
DOGRULANAN=$(wc -l < "$MY")

# Hedef dizin izni 700 (mevcut kural).
if [ "$UZAK" = "0" ]; then
  chmod 700 "$HEDEF"
else
  ssh -o BatchMode=yes -o ConnectTimeout=20 "${HEDEF%%:*}" \
      "chmod 700 '${HEDEF#*:}'" 2>/dev/null || \
      echo "UYARI: uzak dizin izni 700 yapılamadı: $HEDEF" >&2
fi

# Anahtar kazara gitmiş mi? Paranoyak ama ucuz.
if [ "$UZAK" = "0" ] && [ -e "$HEDEF/$(basename "$ANAHTAR")" ]; then
  hata "ANAHTAR HEDEFE KOPYALANMIŞ: $HEDEF/$(basename "$ANAHTAR") — DERHAL SİL"
fi

BIT=$(date +%s)
echo "$(date '+%Y-%m-%d %H:%M') disari gonderildi: $HEDEF"
echo "  $ADET sifreli yedek · sha256 dogrulanan: $DOGRULANAN dosya · sure: $((BIT-BAS)) sn"
