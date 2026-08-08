#!/bin/bash
# dizi.jpg günlük veritabanı yedeği — ŞİFRELİ + yalnız root okunur.
#
# Sunucudaki yeri: /opt/dizijpg/yedek.sh   (cron: 0 4 * * *)
# Bu dosya deponun KANONİK kopyasıdır; sunucuya scp ile gider.
#
# =============================================================================
# NEDEN DEĞİŞTİ (GUVENLIK-DENETIMI-2026-08-07.md §3.2 [SARI])
# =============================================================================
# Eski hâl: dizin 755, dosyalar 644, içerik gzip (şifresiz). Sunucuda kabuğu
# olan root DIŞI bir hesap (`kara`) tüm veritabanı dökümünü — bütün kullanıcı
# e-postaları ve bcrypt hash'leri dahil — okuyabiliyordu. Mesajlar 7 Ağustos'ta
# durağan şifrelemeye geçti (kripto.js) ama e-posta/hash düz duruyor.
#
# =============================================================================
# NEYİ KORUR / NEYİ KORUMAZ (abartma)
# =============================================================================
# KORUR: sunucuda root OLMAYAN bir kullanıcı (ör. `kara`) — hem dizin izni (700)
#        hem şifreleme onu durdurur. Diskin/anlık görüntünün elden çıkması.
#        Yedeğin ileride sunucu dışına kopyalanması (o gün dosya zaten şifreli).
#        Bir izin kazasının (yanlışlıkla 644) tek başına veriyi ifşa etmesi.
# KORUMAZ: root ele geçirilmesi. Anahtar aynı makinede
#        (/opt/dizijpg/yedek-anahtar.key) ve root onu okuyabilir. Zaten root
#        olan biri canlı veritabanına da erişir; bu sınır bilinçlidir.
#
# =============================================================================
# ANAHTAR YÖNETİMİ — "açamadığın yedek, yedek değildir"
# =============================================================================
# Anahtar: /opt/dizijpg/yedek-anahtar.key (600 root:root, 32 rastgele bayt b64).
#
# İKİ KOPYA ŞART:
#   1) SUNUCUDA — otomatik geri yükleme çalışsın diye. (`yedek-ac.sh` onu okur.)
#   2) SUNUCU DIŞINDA, kullanıcının parola yöneticisinde — sunucu tamamen
#      kaybolursa elde kalan şifreli yedekler ancak bu kopyayla açılır.
# İkinci kopya ALINMADAN şifrelemeyi açmak, yedekleri çöpe çevirir.
#
# NEDEN SİMETRİK (asimetrik/çevrimdışı-özel-anahtar DEĞİL):
#   Kapatılan tehdit root olmayan yerel kullanıcı. Asimetrik şema (yalnız açık
#   anahtar sunucuda) yalnızca "root sunucudayken ESKİ yedekleri çözemesin"
#   senaryosunu ekler — ama root zaten CANLI veritabanını okur, kazanç küçük.
#   Buna karşılık maliyeti gerçek: özel anahtar kaybolursa TÜM yedekler kalıcı
#   olarak ölür ve bu projede anahtar emaneti (escrow) süreci yok. Kaybetme
#   riski, eklediği korumadan büyük olduğu için simetrik seçildi.
#
# NEDEN gpg (openssl enc DEĞİL):
#   `openssl enc` bütünlük etiketi yazmaz (AES-CBC eğilebilir); bozulmuş ya da
#   kurcalanmış bir yedek sessizce "çözülür" ve bozuk SQL üretir. gpg simetrik
#   modda MDC ile bütünlüğü doğrular, `gpg -d` kurcalanmada HATA verir.
# =============================================================================

set -euo pipefail
# pipefail ŞART: eski betik `#!/bin/sh` + `set -e` idi ve `pg_dump | gzip`
# zincirinde pg_dump ÇÖKSE BİLE gzip 0 döndüğü için betik "yedek OK" yazıyordu.
# Yani bozuk/boş bir yedek başarı sanılabilirdi.

DIZIN=/opt/dizijpg/yedekler
ANAHTAR=/opt/dizijpg/yedek-anahtar.key

# gpg ev dizini AÇIKÇA verilir ve ÖNCEDEN kurulur.
# YAŞANMIŞ HATA (8 Ağu 2026, canlıda ölçüldü): ev dizini henüz yokken bir
# BORU içinde iki gpg süreci aynı anda başlarsa ikisi de /root/.gnupg'yi
# yaratmaya çalışır ve biri şu hatayla ölür:
#     gpg: Fatal: can't create directory '/root/.gnupg': File exists
# Bu betikte gpg'ler sıralı çalıştığı için yarış yok, ama ilk çalıştırmada
# dizin yine de hazır olsun diye burada bir kez kuruluyor.
export GNUPGHOME=${GNUPGHOME:-/root/.gnupg}
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"

# gpg 2.x'te --passphrase-file yalnızca loopback pinentry ile çalışır; bu
# bayrak olmadan gpg terminal parola kutusu açmaya çalışır ve cron'da (TTY
# yokken) sessizce başarısız olur.
GPG_ORTAK=(--batch --yes --quiet --pinentry-mode loopback
           --passphrase-file "$ANAHTAR")
GPG_SIFRELE=(--symmetric --cipher-algo AES256
             --s2k-mode 3 --s2k-digest-algo SHA512 --s2k-count 65011712)
# Şifrelemeyi geçici olarak kapatmak için: SIFRELE=0 /opt/dizijpg/yedek.sh
SIFRELE=${SIFRELE:-1}
# Sağlıklı bir yedeğin altına düşemeyeceği boyut (bayt). Canlı döküm ~10 MB;
# 1 MB'ın altı "pg_dump yarıda kesildi" demektir.
ASGARI_BOYUT=${ASGARI_BOYUT:-1000000}

# umask 077: bu betiğin OLUŞTURDUĞU her dosya doğrudan 600 doğar. Sonradan
# chmod'a güvenmek yarış koşulu bırakır (dosya bir an 644 olarak var olur).
umask 077

mkdir -p "$DIZIN"
chmod 700 "$DIZIN"

TS=$(date +%Y%m%d-%H%M)

if [ "$SIFRELE" = "1" ]; then
  if [ ! -r "$ANAHTAR" ]; then
    echo "HATA: anahtar dosyası yok/okunamıyor: $ANAHTAR" >&2
    echo "      Kurulum: head -c 32 /dev/urandom | base64 > $ANAHTAR" >&2
    echo "      ve anahtarı parola yöneticisine de KAYDET (yoksa yedekler açılamaz)." >&2
    exit 1
  fi
  HEDEF="$DIZIN/dizijpg-$TS.sql.gz.gpg"
  docker exec dizijpg-db pg_dump -U dizijpg dizijpg \
    | gzip \
    | gpg "${GPG_ORTAK[@]}" "${GPG_SIFRELE[@]}" -o "$HEDEF"
else
  HEDEF="$DIZIN/dizijpg-$TS.sql.gz"
  docker exec dizijpg-db pg_dump -U dizijpg dizijpg | gzip > "$HEDEF"
fi

chmod 600 "$HEDEF"

# --- DOĞRULAMA: "yedek aldım" demeden önce yedeğin AÇILDIĞINI kanıtla --------
# Sessiz bozulma bu işin en sinsi hatasıdır: dosya vardır, boyutu makuldür,
# ama geri yüklenemez. Her gece açılıp gzip başlığına kadar okunur.
BOYUT=$(stat -c %s "$HEDEF")
if [ "$BOYUT" -lt "$ASGARI_BOYUT" ]; then
  echo "HATA: yedek çok küçük ($BOYUT bayt < $ASGARI_BOYUT) — pg_dump yarıda kesilmiş olabilir: $HEDEF" >&2
  exit 1
fi

if [ "$SIFRELE" = "1" ]; then
  # Çöz → gunzip → ilk satırı oku. Boru erken kapandığı için gpg/gunzip
  # SIGPIPE alabilir; bu yüzden çıkış kodu yerine İÇERİĞE bakıyoruz.
  BAS=$(gpg "${GPG_ORTAK[@]}" --decrypt "$HEDEF" 2>/dev/null \
        | gunzip 2>/dev/null | head -c 200 || true)
else
  BAS=$(gunzip -c "$HEDEF" 2>/dev/null | head -c 200 || true)
fi
case "$BAS" in
  *PostgreSQL*|*pg_dump*|*SET\ *)
    : ;;   # geçerli döküm başlığı
  *)
    echo "HATA: yedek doğrulanamadı (çözülüp okunamadı): $HEDEF" >&2
    exit 1 ;;
esac

# --- Temizlik ----------------------------------------------------------------
# 14 günden eski yedekleri sil. ŞİFRELİ ve şifresiz adları AYRI AYRI eşle:
# tek kalıpla ilerlerken göç döneminde eski `.sql.gz`ler hiç silinmezdi.
find "$DIZIN" -name 'dizijpg-*.sql.gz'     -mtime +14 -delete
find "$DIZIN" -name 'dizijpg-*.sql.gz.gpg' -mtime +14 -delete

# Göç emniyeti: dizinde eski/elle bırakılmış ne varsa izni sıkılaştır.
# (Panelden alınan `-elle` yedekleri ve denetim öncesi kalan 644 dosyalar.)
chmod 700 "$DIZIN"
find "$DIZIN" -type f ! -perm 600 -exec chmod 600 {} +

# Şifresiz kalmış dökümleri şifrele. İki kaynağı var:
#   1) denetim öncesinden kalan eski `.sql.gz` / `.sql` dosyaları,
#   2) admin panelindeki "elle yedek" — API konteynerinde gpg YOK, o yüzden
#      şifresiz yazılır ve en geç 24 saat içinde burada şifrelenir.
# Şifreleme BAŞARILIYSA düz dosya silinir; başarısızsa DÜZ DOSYA KORUNUR
# (yedeği kaybetmektense şifresiz tutmak yeğdir) ve uyarı basılır.
if [ "$SIFRELE" = "1" ]; then
  while IFS= read -r -d '' duz; do
    [ -e "$duz.gpg" ] && continue
    if gpg "${GPG_ORTAK[@]}" "${GPG_SIFRELE[@]}" -o "$duz.gpg" "$duz" 2>/dev/null; then
      chmod 600 "$duz.gpg"
      rm -f "$duz"
      echo "  sifrelendi: $(basename "$duz") -> $(basename "$duz").gpg"
    else
      echo "  UYARI: sifrelenemedi, DUZ birakildi: $(basename "$duz")" >&2
    fi
  done < <(find "$DIZIN" -type f \( -name '*.sql.gz' -o -name '*.sql' \) -print0)
fi

# 30 günden eski hata günlüğünü buda (tablo sınırsız büyümesin)
docker exec dizijpg-db psql -U dizijpg -d dizijpg -c \
  "DELETE FROM hatalar WHERE tarih < now() - interval '30 days'" >/dev/null

echo "$(date '+%Y-%m-%d %H:%M') yedek OK: $(basename "$HEDEF") ($BOYUT bayt, dogrulandi)"
