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

if [ "$SIFRELE" = "1" ] && [ ! -r "$ANAHTAR" ]; then
  echo "HATA: anahtar dosyası yok/okunamıyor: $ANAHTAR" >&2
  echo "      Kurulum: head -c 32 /dev/urandom | base64 > $ANAHTAR" >&2
  echo "      ve anahtarı parola yöneticisine de KAYDET (yoksa yedekler açılamaz)." >&2
  exit 1
fi

# =============================================================================
# İKİ DÖKÜM: GÜNLÜK kullanıcı verisi + HAFTALIK TMDB önbelleği (15 Eyl 2026)
# =============================================================================
# NEDEN: `tmdb_onbellek` (TMDB API yanıtlarının önbelleği) 15 Eyl 2026'da
# 26 GB / 2,3 M satırdı ve veritabanının neredeyse TAMAMIYDI; gerçek kullanıcı
# verisi (izlemeler, yorumlar, mesajlar, çeviriler…) 300 MB'nin altında. Tek
# tam döküm her gece 15 GB üretiyor, 14 günlük saklama diski %90'a taşıdı
# (150 GB yedek). Önbellek yeniden çekilebilir ama KULLANICI KARARI: "silme,
# tekrar çekmek istemiyorum; kullanıcı arttıkça TMDB limiti yetmez" — yani
# önbellek de yedeklenir, yalnız daha SEYREK.
#
#   dizijpg-<ts>.sql.gz.gpg          her gece: TÜM şema + önbellek DIŞINDAKİ
#                                     tüm veri (--exclude-table-data). ~100 MB.
#   dizijpg-onbellek-<ts>.sql.gz.gpg 7 günde bir: YALNIZ tmdb_onbellek
#                                     satırları (--data-only). ~15 GB, ~1 saat.
#
# GERİ YÜKLEME SIRASI: önce günlük döküm (tabloyu ve indeksleri de kurar),
# sonra önbellek dökümü (yalnız INSERT/COPY). Önbellek dökümü en fazla bir
# hafta geridir; aradaki fark TMDB'den kendiliğinden tamamlanır.
#   /opt/dizijpg/yedek-ac.sh dizijpg-<ts>.sql.gz.gpg          | psql …
#   /opt/dizijpg/yedek-ac.sh dizijpg-onbellek-<ts>.sql.gz.gpg | psql …
# Önbellek dökümünü BOŞ OLMAYAN tabloya yüklemek anahtar çakışması verir;
# gerekirse önce `TRUNCATE tmdb_onbellek`.
ONBELLEK_TABLO=tmdb_onbellek
ONBELLEK_ARALIK_GUN=${ONBELLEK_ARALIK_GUN:-7}   # bu kadar günde bir
ONBELLEK_SAKLA=${ONBELLEK_SAKLA:-4}             # en yeni N önbellek dökümü kalır
ONBELLEK_ASGARI_BOYUT=${ONBELLEK_ASGARI_BOYUT:-100000000}  # 100 MB altı = yarım

# Tek bir dökümü üretip doğrulayan yardımcı: dok <ad-öneki> <asgari-bayt> <pg_dump argümanları…>
# "yedek aldım" demeden önce yedeğin AÇILDIĞINI kanıtlar. Sessiz bozulma bu
# işin en sinsi hatasıdır: dosya vardır, boyutu makuldür, ama geri yüklenemez.
dok() {
  local onek=$1 asgari=$2; shift 2
  local hedef boyut bas
  if [ "$SIFRELE" = "1" ]; then
    hedef="$DIZIN/$onek-$TS.sql.gz.gpg"
    docker exec dizijpg-db pg_dump -U dizijpg "$@" dizijpg \
      | gzip \
      | gpg "${GPG_ORTAK[@]}" "${GPG_SIFRELE[@]}" -o "$hedef"
  else
    hedef="$DIZIN/$onek-$TS.sql.gz"
    docker exec dizijpg-db pg_dump -U dizijpg "$@" dizijpg | gzip > "$hedef"
  fi
  chmod 600 "$hedef"
  boyut=$(stat -c %s "$hedef")
  if [ "$boyut" -lt "$asgari" ]; then
    echo "HATA: yedek çok küçük ($boyut bayt < $asgari) — pg_dump yarıda kesilmiş olabilir: $hedef" >&2
    exit 1
  fi
  if [ "$SIFRELE" = "1" ]; then
    # Çöz → gunzip → ilk satırı oku. Boru erken kapandığı için gpg/gunzip
    # SIGPIPE alabilir; bu yüzden çıkış kodu yerine İÇERİĞE bakıyoruz.
    bas=$(gpg "${GPG_ORTAK[@]}" --decrypt "$hedef" 2>/dev/null \
          | gunzip 2>/dev/null | head -c 200 || true)
  else
    bas=$(gunzip -c "$hedef" 2>/dev/null | head -c 200 || true)
  fi
  case "$bas" in
    *PostgreSQL*|*pg_dump*|*SET\ *)
      : ;;   # geçerli döküm başlığı
    *)
      echo "HATA: yedek doğrulanamadı (çözülüp okunamadı): $hedef" >&2
      exit 1 ;;
  esac
  echo "$(date '+%Y-%m-%d %H:%M') yedek OK: $(basename "$hedef") ($boyut bayt, dogrulandi)"
}

# 1) Günlük: her şey, önbellek SATIRLARI hariç (şeması dahil).
dok dizijpg "$ASGARI_BOYUT" --exclude-table-data="$ONBELLEK_TABLO"

# 2) Haftalık önbellek: son önbellek dökümü ARALIK'tan eskiyse (ya da hiç yoksa).
if [ -z "$(find "$DIZIN" -name 'dizijpg-onbellek-*.sql.gz*' -mtime -"$ONBELLEK_ARALIK_GUN" -print -quit)" ]; then
  dok dizijpg-onbellek "$ONBELLEK_ASGARI_BOYUT" --data-only --table="$ONBELLEK_TABLO"
fi

# --- Temizlik ----------------------------------------------------------------
# Günlük dökümler artık küçük: 30 gün saklanır (eski 14). ŞİFRELİ ve şifresiz
# adları AYRI AYRI eşle: tek kalıpla ilerlerken göç döneminde eski `.sql.gz`ler
# hiç silinmezdi. Önbellek dökümleri bu kalıba GİRMEZ (adı `dizijpg-onbellek-`),
# onlar sayıyla budanır: en yeni ONBELLEK_SAKLA tanesi kalır.
# NOT: 15 Eyl 2026 öncesinin tam dökümleri (`dizijpg-2026091[45]-…`, 15 GB)
# günlük kalıba uyar ve 30 gün sonra kendiliğinden gider.
find "$DIZIN" -name 'dizijpg-[0-9]*.sql.gz'     -mtime +30 -delete
find "$DIZIN" -name 'dizijpg-[0-9]*.sql.gz.gpg' -mtime +30 -delete
ls -1t "$DIZIN"/dizijpg-onbellek-*.sql.gz* 2>/dev/null \
  | tail -n +"$((ONBELLEK_SAKLA + 1))" | xargs -r rm -f --

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

echo "$(date '+%Y-%m-%d %H:%M') temizlik OK: $(ls -1 "$DIZIN"/dizijpg-*.sql.gz* | wc -l) döküm, $(du -sh "$DIZIN" | cut -f1)"
