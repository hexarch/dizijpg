#!/bin/sh
# =============================================================================
# dizi.jpg — Let's Encrypt yenileme kancası (coturn için)
# Hedef: /etc/letsencrypt/renewal-hooks/deploy/coturn.sh   (chmod 0755)
# =============================================================================
#
# NEDEN BU KANCA ŞART — İKİ AYRI SEBEP
# -----------------------------------------------------------------------------
# 1) İZİN. certbot'un ürettiği /etc/letsencrypt/live/... yolları root'a 0600'dür
#    ve archive dizini 0700'dür. coturn `turnserver` kullanıcısına düştüğü için
#    (turnserver.conf: proc-user) o dosyaları OKUYAMAZ. Doğrudan
#    /etc/letsencrypt yolunu `cert=`/`pkey=` olarak vermek, ilk açılışta
#    "cannot read private key" ile ölmeye ya da daha kötüsü TLS'i sessizce
#    devre dışı bırakmaya yol açar. Çözüm: kopyala + sahiplendir.
#
# 2) YENİDEN YÜKLEME. coturn sertifikayı YALNIZ AÇILIŞTA okur; dosya diskte
#    değişince kendiliğinden fark etmez. Kanca olmadan sertifika 90 günde bir
#    yenilenir, coturn ESKİSİNİ bellekte tutmaya devam eder ve gerçek son
#    kullanma tarihinde TURNS sessizce ölür. Arıza, yenilemeden ~90 gün SONRA
#    ortaya çıkar — nedenini bulmak çok zordur.
#
# ARIZA MODU (bilerek nazik): bu kanca ya da sertifikanın tamamı bozulsa bile
# TURN 3478 (TLS'siz) çalışmaya devam eder ve istemci ICE sırasında ona düşer.
# Aramalar durmaz, yalnız kurumsal güvenlik duvarı ardındaki kullanıcılar
# kaybedilir. (turnserver.conf §4'teki "arıza modu nazik" gerekçesi budur.)

set -eu

ALAN="turn.dizijpg.com"
KAYNAK="/etc/letsencrypt/live/${ALAN}"
HEDEF="/etc/coturn/certs"

# certbot bu kancayı YENİLENEN HER sertifika için çağırır. Bizimki değilse
# hiçbir şey yapma — başka bir alan adının yenilenmesi coturn'ü boşuna
# yeniden başlatmasın (yeniden başlatma DEVAM EDEN ARAMALARI KOPARIR).
if [ "${RENEWED_LINEAGE:-}" != "$KAYNAK" ]; then
  exit 0
fi

install -d -m 0750 -o root -g turnserver "$HEDEF"

# `install` ile tek adımda kopyala + izin + sahip: yarı yazılmış bir dosyanın
# coturn tarafından okunma penceresi oluşmaz.
install -m 0640 -o root -g turnserver "${KAYNAK}/fullchain.pem" "${HEDEF}/fullchain.pem"
install -m 0640 -o root -g turnserver "${KAYNAK}/privkey.pem"   "${HEDEF}/privkey.pem"

# `reload` YOK: coturn SIGHUP ile sertifikayı yeniden okumaz, restart gerekir.
# Bedeli, yenileme anında (90 günde bir, gece) devam eden aramaların kopması.
# Kabul edilebilir; alternatifi süresi dolmuş sertifikayla yayın yapmaktır.
systemctl restart coturn

logger -t coturn-cert "sertifika yenilendi ve coturn yeniden baslatildi (${ALAN})"
