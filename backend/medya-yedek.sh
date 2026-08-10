#!/bin/bash
# dizi.jpg MEDYA yedeği — ARTIMLI (rsync). Kullanıcıların fotoğraf/video/avatarları.
#
# Sunucudaki yeri: /opt/dizijpg/medya-yedek.sh
# Bu dosya deponun KANONİK kopyasıdır; sunucuya scp ile gider.
#
# Kullanım:
#   /opt/dizijpg/medya-yedek.sh                      # varsayılan yerel hedef
#   /opt/dizijpg/medya-yedek.sh /yedek/medya         # başka yerel dizin
#   /opt/dizijpg/medya-yedek.sh kullanici@makine:/yedek/dizijpg-medya
#
# =============================================================================
# NEDEN VAR (yapilacaklar2 A1)
# =============================================================================
# `yedek.sh` YALNIZCA veritabanını alıyordu. 10 Ağu 2026 ölçümü: 30.997 dosya,
# 5,8 GB medya — TEK KOPYA. Silinirse/bozulursa geri gelmez. Veritabanındaki
# `mesajlar.medya`, `yorumlar.medya`, `kullanicilar.avatar` kolonları dosya adı
# tutar; dosya yoksa yedekten dönen veritabanı KIRIK bağlantılarla açılır.
#
# =============================================================================
# NEDEN ARTIMLI (her gün tam kopya DEĞİL)
# =============================================================================
# Günde 5,8 GB göndermek anlamsız: medya dosyaları DEĞİŞMEZ (yüklenir, silinir;
# üzerine yazılmaz). rsync yalnız yeni/değişen dosyayı aktarır. Ölçüm:
#   1. çalıştırma  ~5,8 GB   2. çalıştırma  ~0 bayt   (bkz. raporda kanıt)
#
# =============================================================================
# NEDEN ŞİFRELİ DEĞİL (bilinçli karar — veritabanı yedeğinden FARKLI)
# =============================================================================
# `yedek.sh` GPG ile şifreler; burada şifrelemiyoruz. Gerekçe ölçüme dayanır:
#
#  1) MEDYA ZATEN HERKESE AÇIK. 10 Ağu 2026'da doğrulandı:
#       curl https://dizijpg.com/api/medya/m10-364054fc2907c5b1.jpg
#       -> HTTP 200, image/jpeg, 188.762 bayt (diskteki boyutun aynısı)
#     Kimlik doğrulaması YOK. `MEDYA_IMZA_ZORUNLU` bugün KAPALI (server.js),
#     yani imzasız istek de servis ediliyor. Şifreleme, saldırganın zaten
#     `curl` ile indirebildiği veriyi korumaya çalışmak olurdu.
#  2) ÖZEL ALT KÜME ÇOK KÜÇÜK: DM eki olan dosya sayısı 9 (canlıda ölçüldü,
#     `mesajlar.medya EXCEPT yorumlar.medya`). Bu 9 dosya da bugün imzasız
#     servis ediliyor (göç dönemi).
#  3) ASIL SIR VERİTABANINDA VE O ŞİFRELİ. E-posta, bcrypt hash'i ve mesaj
#     içeriği `.sql.gz.gpg` içinde. Medya dosyası tek başına anonim bir görsel
#     yığınıdır; kimin yüklediğini bilmek için veritabanı gerekir.
#     DÜRÜSTLÜK NOTU: dosya adı `m<kullanici_id>-<16 hex>.jpg` biçiminde, yani
#     yükleyenin SAYISAL kimliğini sızdırır. Ama aynı eşleme sitede zaten
#     herkese açık olduğu için şifreleme bunu gizlemiyor, yalnız erteliyor.
#  4) ŞİFRELEME İLE ARTIMLILIK BİRBİRİNİ YER. Dosya bazlı GPG 31 bin gpg
#     çağrısı + yerelde 5,8 GB ikinci kopya demek (diskte 36 GB boş var).
#     Kazanç ~0 iken maliyet gerçek.
#
# BU KARAR NE ZAMAN DEĞİŞİR (tetikleyiciler):
#   · `MEDYA_IMZA_ZORUNLU=1` açılırsa — o gün medya gerçekten özel olur.
#   · DM eki sayısı üç haneye çıkarsa.
#   · Hedef olarak GÜVENİLMEYEN bir depolama (ücretsiz bulut) seçilirse.
# O gün yapılacak: ev yapımı gpg döngüsü YAZMA — `restic` kullan (açık kaynak,
# şifreli + artımlı + tekilleştirmeli, tam olarak bu iş için var). Bugünkü
# tercih: aktarım SSH ile şifreli, HEDEF KULLANICININ DENETİMİNDEKİ bir makine
# olmalı (kendi bilgisayarı / kendi ikinci sunucusu), rastgele bir bulut değil.
#
# =============================================================================
# NEDEN VARSAYILAN OLARAK SİLMİYOR (--sil ile açılır)
# =============================================================================
# Klasik `rsync --delete` aynası, kaynakta yanlışlıkla silinen dosyayı yedekten
# de siler — yani korumak istediğimiz kazanın ta kendisini yayar. Bu projede
# gerçek bir tetikleyici var: AI kare tekrar süzgeci dosyaları `karantina-*`
# dizinine taşıyor. Varsayılan: yedek YALNIZCA büyür. Gerçekten aynalamak
# gerekirse `--sil` ile bilinçli olarak açılır.
# =============================================================================

set -euo pipefail
# pipefail ŞART. `yedek.sh` başlığındaki yaşanmış hata: `pg_dump | gzip`
# zincirinde pg_dump çökse bile gzip 0 döndüğü için betik "yedek OK" yazıyordu.
# Sessiz başarısızlık bu projede DAHA ÖNCE OLDU; aynı hatayı yapma.

KAYNAK=${KAYNAK:-/var/lib/docker/volumes/dizijpg_dizijpg_dosyalar/_data}
HEDEF=${1:-/opt/dizijpg/medya-yedek}
SIL=0
[ "${2:-}" = "--sil" ] && SIL=1
[ "${1:-}" = "--sil" ] && { SIL=1; HEDEF=${2:-/opt/dizijpg/medya-yedek}; }

# Kaynak sağlıklı değilse HİÇ BAŞLAMA. Docker birimi bağlanmamışsa dizin BOŞ
# görünür; o hâlde `--sil` ile çalışmak yedeği süpürürdü.
ASGARI_DOSYA=${ASGARI_DOSYA:-1000}

KILIT=/var/lock/dizijpg-medya-yedek.lock
# flock: cron sıklaşırsa iki kopya üst üste binmesin (rsync'in kendisi
# eşzamanlılığa dayanıklı değil; iki taraf aynı geçici dosyayı yazar).
exec 9>"$KILIT"
if ! flock -n 9; then
  echo "HATA: başka bir medya yedeği hâlâ çalışıyor ($KILIT) — atlanıyor" >&2
  exit 1
fi

hata() { echo "$(date '+%Y-%m-%d %H:%M:%S') HATA: $*" >&2; exit 1; }

[ -d "$KAYNAK" ] || hata "kaynak dizin yok: $KAYNAK"

KAYNAK_DOSYA=$(find "$KAYNAK" -type f | wc -l)
if [ "$KAYNAK_DOSYA" -lt "$ASGARI_DOSYA" ]; then
  hata "kaynakta yalnız $KAYNAK_DOSYA dosya var (asgari $ASGARI_DOSYA).
      Docker birimi bağlı değil ya da veri gitmiş olabilir. Yedek ÇALIŞTIRILMADI
      ki sağlam yedeğin üzerine boşluk yazılmasın."
fi
KAYNAK_BAYT=$(du -sb "$KAYNAK" | cut -f1)

UZAK=0
case "$HEDEF" in
  *:*) UZAK=1 ;;   # kullanici@makine:/yol
esac

if [ "$UZAK" = "0" ]; then
  mkdir -p "$HEDEF"
  chmod 700 "$HEDEF"          # mevcut kural: yedek dizinleri 700
  # Diski doldurma. İlk kopya 5,8 GB; boş alan yetmiyorsa BAŞLAMA.
  MEVCUT_BAYT=$(du -sb "$HEDEF" 2>/dev/null | cut -f1 || echo 0)
  BOS_BAYT=$(df -B1 --output=avail "$HEDEF" | tail -1)
  GEREKLI=$(( KAYNAK_BAYT - MEVCUT_BAYT + 1073741824 ))   # +1 GB emniyet payı
  if [ "$GEREKLI" -gt 0 ] && [ "$BOS_BAYT" -lt "$GEREKLI" ]; then
    hata "yetersiz disk: gereken ~$((GEREKLI/1048576)) MB, boş $((BOS_BAYT/1048576)) MB ($HEDEF)"
  fi
fi

RSYNC=(rsync -a --stats --human-readable --no-inc-recursive)
# -a: izin/zaman/simge bağlarını korur. Zaman damgası korunmazsa rsync her
#     çalıştırmada her dosyayı yeniden aktarır ve "artımlı" olmaktan çıkar.
[ "$UZAK" = "1" ] && RSYNC+=(-e "ssh -o BatchMode=yes -o ConnectTimeout=20")
[ "$SIL" = "1" ]  && RSYNC+=(--delete)

# Sondaki `/` ŞART: kaynağın İÇİNDEKİLER hedefe gider, `_data` adlı bir alt
# dizin oluşmaz. Yoksa her çalıştırmada iç içe dizin üretilir.
GUNLUK=$(mktemp /tmp/medya-yedek-XXXXXX.log)
temizle() { rm -f "$GUNLUK"; }
trap temizle EXIT

calistir() {
  set +e
  "${RSYNC[@]}" "$@" "$KAYNAK/" "$HEDEF" > "$GUNLUK" 2>&1
  local k=$?
  set -e
  # 24 = "kaynakta dosya kayboldu" — canlı bir medya dizininde NORMAL
  # (kullanıcı yükleme sırasında/sonrasında dosya silebilir). Diğer her kod hata.
  if [ "$k" -ne 0 ] && [ "$k" -ne 24 ]; then
    # rsync'in kendi hata satırlarını GÖSTER; yoksa "başarısız" tek başına
    # teşhis edilemez (izin mi, ssh mi, disk mi?).
    tail -5 "$GUNLUK" >&2
    hata "rsync başarısız (çıkış kodu $k) — hedef: $HEDEF"
  fi
  return 0
}
# DİKKAT: `calistir` bilerek `$( )` İÇİNDE çağrılmıyor. Komut ikamesi alt kabuk
# açar; oradaki `exit 1` yalnız alt kabuğu öldürür ve ana betik "başarılı"
# sayılabilirdi. Tam da `yedek.sh`in başında anlatılan sessiz başarısızlık.

BAS=$(date +%s)
calistir
grep -E 'Number of regular files transferred|Total transferred file size|Literal data|Total file size' "$GUNLUK" || true

# --- DOĞRULAMA: "yedekledim" demeden ÖNCE kanıtla --------------------------
# rsync 0 döndü diye iş bitmiş sayılmaz. Kuru çalıştırma hedefte EKSİK kalan
# dosyaları listeler. Canlı dizinde iki tarama arasında yeni dosya doğabilir,
# bu yüzden bir kez daha aktarıp TEKRAR bakıyoruz; ikinci turda da kalan varsa
# GERÇEK hatadır.
kalan() {
  set +e
  local c
  c=$("${RSYNC[@]}" --dry-run --itemize-changes "$KAYNAK/" "$HEDEF" 2>/dev/null \
      | grep -c '^[<>]')
  set -e
  echo "${c:-0}"
}

KALAN=$(kalan)
if [ "$KALAN" -gt 0 ]; then
  echo "  bilgi: $KALAN dosya hâlâ bekliyor (tarama sırasında değişmiş olabilir) — ikinci tur"
  calistir
  KALAN=$(kalan)
  if [ "$KALAN" -gt 0 ]; then
    hata "doğrulama başarısız: ikinci turdan sonra da $KALAN dosya hedefte eksik/farklı ($HEDEF)"
  fi
fi

BIT=$(date +%s)

if [ "$UZAK" = "0" ]; then
  HEDEF_DOSYA=$(find "$HEDEF" -type f | wc -l)
  chmod 700 "$HEDEF"
else
  UZAK_MAKINE=${HEDEF%%:*}; UZAK_YOL=${HEDEF#*:}
  # Uzak hedefte de 700; yedekler dünyaya okunur durmasın.
  ssh -o BatchMode=yes -o ConnectTimeout=20 "$UZAK_MAKINE" \
      "chmod 700 '$UZAK_YOL' 2>/dev/null; find '$UZAK_YOL' -type f | wc -l" \
      > /tmp/.medya-yedek-sayi.$$ 2>/dev/null || hata "uzak hedef doğrulanamadı: $HEDEF"
  HEDEF_DOSYA=$(cat /tmp/.medya-yedek-sayi.$$); rm -f /tmp/.medya-yedek-sayi.$$
fi

# Silme kapalıyken hedef yalnız büyür; hedef kaynaktan AZ olamaz.
if [ "$SIL" = "0" ] && [ "$HEDEF_DOSYA" -lt "$KAYNAK_DOSYA" ]; then
  hata "hedefte $HEDEF_DOSYA dosya var ama kaynakta $KAYNAK_DOSYA — kopya eksik: $HEDEF"
fi

echo "$(date '+%Y-%m-%d %H:%M') medya yedek OK: $HEDEF"
echo "  kaynak: $KAYNAK_DOSYA dosya / $((KAYNAK_BAYT/1048576)) MB · hedef: $HEDEF_DOSYA dosya · süre: $((BIT-BAS)) sn"
