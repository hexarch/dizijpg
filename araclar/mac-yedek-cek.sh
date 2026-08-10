#!/bin/bash
#
# dizi.jpg — yedekleri SUNUCUDAN MAC'E ÇEKER (pull).
#
# NEDEN ÇEKME (pull), İTME (push) DEĞİL:
#   Sunucu bu makineye erişemez. Sunucu ele geçirilse bile saldırgan buradaki
#   yedekleri silemez/şifreleyemez. İtme modelinde sunucudaki bir anahtar hedefe
#   yazabildiği için fidye yazılımı yedekleri de yok edebilir. Bu betik tek
#   gerçek koruma katmanıdır — sunucu tamamen kaybolsa bile veriler burada kalır.
#
# NE ÇEKİLİR:
#   1) /opt/dizijpg/yedekler   -> veritabani/   (GPG ile ŞİFRELİ .gpg dökümler)
#   2) medya Docker birimi     -> medya/        (kullanıcı foto/video/avatarları)
#
# ANAHTAR UYARISI:
#   Buradaki .gpg dosyaları /opt/dizijpg/yedek-anahtar.key OLMADAN AÇILMAZ.
#   Kullanıcı 10 Ağu 2026'da anahtarın parola yöneticisinde olduğunu doğruladı
#   (sunucuda: /opt/dizijpg/anahtar-parola-yoneticisinde-ONAY). Anahtar
#   değiştirilirse yeni kopyası da parola yöneticisine konmalı, yoksa bu
#   yedeklerin tamamı çöpe döner.
#
# SİLME YOK: `--delete` BİLEREK KULLANILMIYOR. Klasik ayna, kaynakta yanlışlıkla
#   silinen dosyayı yedekten de siler — yani korumak istediğimiz kazayı yayar.
#   Yerelde biriken fazlalık, kaybedilen dosyadan iyidir.
#
# Kullanım:  ./mac-yedek-cek.sh [hedef_dizin]
#   Varsayılan hedef: ~/dizijpg-yedekler

set -uo pipefail

SUNUCU="${DIZIJPG_SUNUCU:-root@154.53.163.3}"
HEDEF="${1:-$HOME/dizijpg-yedekler}"
UZAK_YEDEK="/opt/dizijpg/yedekler/"
UZAK_MEDYA="/var/lib/docker/volumes/dizijpg_dizijpg_dosyalar/_data/"
KILIT="$HEDEF/.calisiyor.kilit"
# Diskte bu kadar boş kalmazsa çekme YAPILMAZ. Mac 10 Ağu'da %96 doluydu;
# yedek yüzünden makineyi doldurup kullanıcıyı zor durumda bırakmayalım.
ASGARI_BOS_GB=10

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
oldu()  { log "HATA: $*"; rmdir "$KILIT" 2>/dev/null; exit 1; }

command -v rsync >/dev/null || oldu "rsync yok"

mkdir -p "$HEDEF" || oldu "hedef dizin oluşturulamadı: $HEDEF"
# Yedekler kullanıcı verisi: başkası okumasın.
chmod 700 "$HEDEF" 2>/dev/null

# Kilit: iki çekme üst üste binmesin (büyük ilk kopya saatlerce sürebilir).
# mkdir atomiktir; `-f dosya` kontrolü yarış durumuna açıktır.
if ! mkdir "$KILIT" 2>/dev/null; then
  log "Başka bir çekme sürüyor ($KILIT) — atlanıyor."
  exit 0
fi
trap 'rmdir "$KILIT" 2>/dev/null' EXIT

# --- Disk kontrolü: dolu diske yazmaya çalışmak sessiz yarım kopya üretir ---
bos_gb=$(df -g "$HEDEF" | awk 'NR==2 {print $4}')
[ -z "$bos_gb" ] && oldu "boş alan okunamadı"
if [ "$bos_gb" -lt "$ASGARI_BOS_GB" ]; then
  oldu "diskte yalnız ${bos_gb} GB boş var (asgari ${ASGARI_BOS_GB} GB). Çekme yapılmadı."
fi

ssh -o BatchMode=yes -o ConnectTimeout=15 "$SUNUCU" true 2>/dev/null \
  || oldu "sunucuya SSH ile bağlanılamadı ($SUNUCU)"

# --- Kaynak sağlık kontrolü ---
# Kaynak beklenmedik biçimde BOŞSA çekmeyi durdur. Docker birimi bağlı değilse
# veya bir kaza dizini boşalttıysa, boş kaynağı sessizce kopyalayıp "yedek
# tamam" demek en tehlikeli sonuçtur.
uzak_yedek_sayi=$(ssh "$SUNUCU" "ls -1 '$UZAK_YEDEK' 2>/dev/null | wc -l" | tr -d ' ')
uzak_medya_sayi=$(ssh "$SUNUCU" "find '$UZAK_MEDYA' -type f 2>/dev/null | wc -l" | tr -d ' ')
[ "${uzak_yedek_sayi:-0}" -lt 1 ]   && oldu "uzak yedek dizini BOŞ görünüyor — çekme iptal"
[ "${uzak_medya_sayi:-0}" -lt 100 ] && oldu "uzak medya şüpheli derecede boş ($uzak_medya_sayi dosya) — çekme iptal"
log "Uzakta: $uzak_yedek_sayi yedek dosyası, $uzak_medya_sayi medya dosyası"

hata=0

# --- 1) Veritabanı yedekleri (şifreli) ---
log "Veritabanı yedekleri çekiliyor..."
if rsync -az --partial --stats -e "ssh -o BatchMode=yes" \
     "$SUNUCU:$UZAK_YEDEK" "$HEDEF/veritabani/" 2>&1 | grep -E "Number of regular files transferred|Total transferred file size"; then
  log "Veritabanı yedekleri TAMAM"
else
  log "HATA: veritabanı yedekleri çekilemedi"; hata=1
fi

# --- 2) Medya ---
# Medya ŞİFRESİZ: herkese açık servis ediliyor (curl ile indirilebiliyor),
# şifrelemek saldırganın zaten görebildiği veriyi korumaya çalışmak olurdu.
# Aktarım SSH ile şifreli. Hedef kullanıcının kendi makinesi.
log "Medya çekiliyor (ilk kopya uzun sürer)..."
if rsync -az --partial --stats -e "ssh -o BatchMode=yes" \
     "$SUNUCU:$UZAK_MEDYA" "$HEDEF/medya/" 2>&1 | grep -E "Number of regular files transferred|Total transferred file size"; then
  log "Medya TAMAM"
else
  log "HATA: medya çekilemedi"; hata=1
fi

[ "$hata" -ne 0 ] && oldu "bir veya daha fazla aktarım başarısız"

# --- Doğrulama: yerel sayım uzak sayımla tutuyor mu ---
yerel_yedek=$(ls -1 "$HEDEF/veritabani/" 2>/dev/null | wc -l | tr -d ' ')
yerel_medya=$(find "$HEDEF/medya/" -type f 2>/dev/null | wc -l | tr -d ' ')
log "Yerelde: $yerel_yedek yedek dosyası, $yerel_medya medya dosyası"
# Yerelde FAZLA olabilir (silme yapmıyoruz); AZ olamaz.
[ "$yerel_yedek" -lt "$uzak_yedek_sayi" ] && oldu "yedek sayısı eksik ($yerel_yedek < $uzak_yedek_sayi)"
[ "$yerel_medya" -lt "$uzak_medya_sayi" ] && oldu "medya sayısı eksik ($yerel_medya < $uzak_medya_sayi)"

log "Toplam boyut: $(du -sh "$HEDEF" | cut -f1) · diskte kalan: $(df -g "$HEDEF" | awk 'NR==2 {print $4}') GB"
log "ÇEKME BAŞARILI"
exit 0
