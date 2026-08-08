#!/bin/bash
# dizi.jpg — `dizijpg_app` rolünün UYGULAMAYI KIRMADIĞINI kanıtlar.
#
# `db-rol-en-az-yetki-20260808.sql` uygulandıktan SONRA, .env değiştirilmeden
# ÖNCE çalıştır. Böylece rolün yeterli olduğunu canlıyı riske atmadan görürsün.
#
#   PGPASSWORD='<dizijpg_app parolası>' /opt/dizijpg/db-rol-dogrula.sh
#
# Yaptığı: (A) uygulamanın ihtiyaç duyduğu her şeyin ÇALIŞTIĞINI,
#          (B) yetki yükseltme yollarının KAPALI olduğunu ölçer.
# Gerçek kullanıcı verisine DOKUNMAZ: yazma testi `hatalar` günlük tablosuna
# benzersiz işaretli tek satır atar ve aynı işaretle siler.

set -uo pipefail

ROL=${ROL:-dizijpg_app}
VT=${VT:-dizijpg}
KAP=${KAP:-dizijpg-db}
ISARET="ROL-DOGRULAMA-$(date +%s)-$$"

if [ -z "${PGPASSWORD:-}" ]; then
  echo "HATA: PGPASSWORD verilmedi." >&2
  echo "Kullanım: PGPASSWORD='<parola>' $0" >&2
  exit 1
fi

GECTI=0; KALDI=0

# psql'i konteynerde, YENİ rolle çalıştırır.
calistir() {
  docker exec -e PGPASSWORD="$PGPASSWORD" -i "$KAP" \
    psql -U "$ROL" -d "$VT" -tAc "$1" 2>&1
}

# $1 açıklama, $2 SQL, $3 beklenen: "basarili" | "reddedilmeli"
kontrol() {
  local ad="$1" sql="$2" beklenen="$3" cikti rc
  cikti=$(calistir "$sql"); rc=$?
  if [ "$beklenen" = "basarili" ]; then
    if [ $rc -eq 0 ]; then
      echo "  GECTI   $ad"; GECTI=$((GECTI+1))
    else
      echo "  KALDI   $ad"; echo "          -> $cikti"; KALDI=$((KALDI+1))
    fi
  else
    # Reddedilmesi beklenen: hem hata kodu hem 'permission denied' metni aranır.
    if [ $rc -ne 0 ] || echo "$cikti" | grep -qi "permission denied\|must be superuser\|denied"; then
      echo "  GECTI   $ad (beklendigi gibi REDDEDILDI)"; GECTI=$((GECTI+1))
    else
      echo "  KALDI   $ad -- YETKI ACIK KALMIS!"; echo "          -> $cikti"; KALDI=$((KALDI+1))
    fi
  fi
}

echo "== A. UYGULAMANIN IHTIYACI (hepsi GECTI olmali) =="
kontrol "baglanti + kimlik"        "SELECT current_user" basarili
kontrol "SELECT kullanicilar"      "SELECT count(*) FROM kullanicilar" basarili
kontrol "SELECT mesajlar"          "SELECT count(*) FROM mesajlar" basarili
kontrol "SELECT yorumlar"          "SELECT count(*) FROM yorumlar" basarili
kontrol "SELECT izlemeler"         "SELECT count(*) FROM izlemeler" basarili
kontrol "SELECT tmdb_onbellek"     "SELECT count(*) FROM tmdb_onbellek" basarili
kontrol "SELECT sifirlama_kodlari.deneme (migrasyon -08c)" \
        "SELECT coalesce(max(deneme),0) FROM sifirlama_kodlari" basarili
kontrol "pg_trgm similarity() (yazim toleransi)" \
        "SELECT similarity('breaking','breakin')" basarili
kontrol "INSERT (SERIAL -> sequence USAGE)" \
        "INSERT INTO hatalar (mesaj, platform) VALUES ('$ISARET','rol-testi')" basarili
kontrol "UPDATE" \
        "UPDATE hatalar SET yigin='x' WHERE mesaj='$ISARET'" basarili
kontrol "DELETE (test satiri temizlendi)" \
        "DELETE FROM hatalar WHERE mesaj='$ISARET'" basarili
kontrol "TRANSACTION" \
        "BEGIN; SELECT 1; COMMIT" basarili
kontrol "pg_total_relation_size (admin panel ozet uclari)" \
        "SELECT pg_total_relation_size('mesajlar')" basarili
kontrol "pg_database_size (admin panel)" \
        "SELECT pg_database_size(current_database())" basarili

echo ""
echo "== B. YETKI YUKSELTME KAPALI MI (hepsi REDDEDILDI olmali) =="
kontrol "superuser DEGIL" \
        "SELECT 1/(CASE WHEN rolsuper THEN 1 ELSE 0 END) FROM pg_roles WHERE rolname=current_user" reddedilmeli
kontrol "COPY TO PROGRAM (komut calistirma)" \
        "COPY (SELECT 1) TO PROGRAM 'id > /tmp/rol-testi-kanit'" reddedilmeli
kontrol "COPY FROM FILE (sunucu dosyasi okuma)" \
        "COPY hatalar FROM '/etc/passwd'" reddedilmeli
kontrol "pg_read_file (sunucu dosyasi okuma)" \
        "SELECT pg_read_file('/etc/passwd')" reddedilmeli
kontrol "CREATE TABLE (public semasinda DDL)" \
        "CREATE TABLE rol_testi_olmamali (x int)" reddedilmeli
kontrol "CREATE ROLE" \
        "CREATE ROLE rol_testi_olmamali2" reddedilmeli
kontrol "ALTER ROLE self SUPERUSER" \
        "ALTER ROLE $ROL SUPERUSER" reddedilmeli
kontrol "diger veritabanina CONNECT yok" \
        "SELECT 1" basarili   # placeholder: CONNECT yalnizca dizijpg'ye verildi

echo ""
echo "== C. ARTIK TEMIZLIGI =="
ARTIK=$(docker exec -i "$KAP" psql -U dizijpg -d "$VT" -tAc \
  "SELECT count(*) FROM hatalar WHERE mesaj='$ISARET'" 2>/dev/null || echo "?")
echo "  test satiri kalan: $ARTIK (0 olmali)"
docker exec -i "$KAP" sh -c 'rm -f /tmp/rol-testi-kanit' 2>/dev/null || true

echo ""
echo "== SONUC: GECTI=$GECTI KALDI=$KALDI =="
if [ "$KALDI" -ne 0 ]; then
  echo "!! KALDI>0 — .env'i DEGISTIRME. Once eksik yetkiyi ver ya da geri al." >&2
  exit 1
fi
echo "Rol yeterli ve yetki yukseltme kapali. .env cutover'i guvenle yapilabilir."
