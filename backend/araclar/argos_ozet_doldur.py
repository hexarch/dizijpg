#!/usr/bin/env python3
"""TMDB ÖZETLERİNİ Argos ile 14 dile çevirip `metin_cevirileri`ne yazar.

NEDEN AYRI ARAÇ, NEDEN AYNI BORU
--------------------------------
29 Ağu 2026'da SSR 46 dile açıldı. Sayfanın BİZİM yazdığımız her parçası (SSS
soruları, künye etiketleri, başlık/açıklama şablonları, şema) `seo_dil.js`
tablosundan geliyor ve gerçekten çevrili. Çevrilmeyen TEK blok TMDB özetiydi:
TMDB bir yapımın özetini yalnız bazı dillerde veriyor.

Kural (server.js `seoOzetZinciri`):
    1. TMDB o dilde özet veriyorsa ONU kullan,
    2. yoksa ve dilin Argos çifti varsa `metin_cevirileri` ÖNBELLEĞİNE bak,
    3. ikisi de yoksa BOŞ bırak — Türkçesi HİÇBİR DURUMDA basılmaz.

Bu araç 2. adımın önbelleğini doldurur. Makine çevirisi bu projede yeni bir
emsal DEĞİL: kullanıcı gönderileri 30 Tem 2026'dan beri aynı boruyla (Argos
Translate + CTranslate2, ÇEVRİMDIŞI — Google Translate değil) çevriliyor.
Motor, önbellek tablosu, anahtar (md5(btrim(metin))) ve yazma deseni
`argos_doldur.py`den İÇE AKTARILIR; paralel bir sistem kurulmaz.

⚠ SSR BU ARACI ÇAĞIRMAZ. Model 5,1 GB ve metin başına saniyeler sürüyor; SSR
süre bütçesi nginx'in 20 sn'lik `proxy_read_timeout`una göre ayarlı. Senkron
çeviri Googlebot'a 504 bastırırdı. SSR yalnız ÖNBELLEK OKUR (read-through);
doldurma bu araçla, elle ya da gece işi olarak yapılır.

KURULU ÇİFTLER (29 Ağu 2026 sunucu ölçümü):
    en->ar bn de es fr hi id ja ko pt ru ur vi zh   (14)  + tr->en
`ARGOS_DILLERI` (server.js) bu listeyle AYNI olmak zorunda.

KAYNAK METİN: `tmdb_onbellek` içindeki İNGİLİZCE (`language=en-US`) yükün
`overview` alanı — yani SSR'ın Argos kaynağı olarak okuduğu metnin BİREBİR
aynısı. Bölüm özetleri de aynı tablodan (`/season/N/episode/M`) gelir.

KULLANIM (sunucuda, host):
  /opt/dizijpg/argos-venv/bin/python3 /opt/dizijpg/argos_ozet_doldur.py --kuru
  /opt/dizijpg/argos-venv/bin/python3 /opt/dizijpg/argos_ozet_doldur.py
  /opt/dizijpg/argos-venv/bin/python3 /opt/dizijpg/argos_ozet_doldur.py --dil=de
  /opt/dizijpg/argos-venv/bin/python3 /opt/dizijpg/argos_ozet_doldur.py --sinir=500

Veritabanı dışarı port açmadığı için `docker exec dizijpg-db psql` kullanılır
(argos_doldur.py ile aynı yol). INSERT ... ON CONFLICT DO NOTHING — mevcut
satır EZİLMEZ, yani TMDB'nin insan çevirisi bir gün önbelleğe girerse burası
onu bozmaz.
"""

from __future__ import annotations

import argparse
import os
import sys
import time

# argos_doldur.py YANIBAŞINDA duruyor (hem depoda `backend/araclar/` hem
# sunucuda `/opt/dizijpg/`). Motoru, psql yardımcılarını ve yazma desenini
# ORADAN alıyoruz — ikinci bir kopya iki sistemin zamanla ayrışması demekti.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from argos_doldur import (  # noqa: E402
    BatchCevirmen, CEVIR_OBEGI, log, psql, psql_copy_csv, yaz_obek,
)

# server.js `ARGOS_DILLERI` ile AYNI liste olmak ZORUNDA. Ayrışırsa ya
# çevrilmiş ama okunmayan satır (boşa harcanan CPU) ya da okunmaya çalışılan
# ama hiç üretilmemiş dil (boş özet) doğar.
HEDEF_DILLER: list[str] = [
    "ar", "bn", "de", "es", "fr", "hi", "id", "ja", "ko", "pt", "ru", "ur",
    "vi", "zh",
]

# Çok kısa özet çevirmeye değmez ve genelde tek kelimelik yer tutucudur.
EN_AZ_UZUNLUK = 40

# TMDB önbelleğinden İNGİLİZCE özetler. Üç aile:
#   · /movie/:id  ve /tv/:id            -> içerik sayfası
#   · /tv/:id/season/:s/episode/:b      -> bölüm sayfası
# `language=en-US` süzgeci ŞART: aynı yapımın tr-TR satırı da tabloda duruyor
# ve onu çevirmek Türkçeden çeviri yapmak olurdu (kural: pivot İNGİLİZCE).
OZET_SQL = f"""
COPY (
  SELECT DISTINCT ON (md5(btrim(veri->>'overview')))
         md5(btrim(veri->>'overview')),
         btrim(veri->>'overview')
    FROM tmdb_onbellek
   WHERE anahtar LIKE '%language=en-US%'
     AND anahtar ~ '^/(movie|tv)/[0-9]+'
     AND veri->>'overview' IS NOT NULL
     AND length(btrim(veri->>'overview')) >= {EN_AZ_UZUNLUK}
   ORDER BY md5(btrim(veri->>'overview')), anahtar
) TO STDOUT WITH (FORMAT csv, ENCODING 'UTF8');
"""


def ozetleri_yukle(sinir: int = 0) -> list[tuple[str, str]]:
    """Benzersiz İngilizce özetler: (ozet_md5, metin)."""
    satirlar = [(s[0], s[1]) for s in psql_copy_csv(OZET_SQL) if len(s) >= 2]
    return satirlar[:sinir] if sinir else satirlar


def mevcut_ciftler(diller: list[str]) -> set[tuple[str, str]]:
    """Önbellekte ZATEN olan (ozet, dil) çiftleri — ikinci kez çevirmeyiz."""
    liste = ",".join("'" + d.replace("'", "") + "'" for d in diller)
    sql = f"""
COPY (
  SELECT ozet, dil FROM metin_cevirileri WHERE dil IN ({liste})
) TO STDOUT WITH (FORMAT csv, ENCODING 'UTF8');
"""
    return {(s[0], s[1]) for s in psql_copy_csv(sql) if len(s) >= 2}


def dil_doldur(
    kod: str,
    ozetler: list[tuple[str, str]],
    varolan: set[tuple[str, str]],
    cevirmen: BatchCevirmen,
) -> int:
    """Bir hedef dilin eksiklerini toplu çevirip yazar; yazılan satır sayısı."""
    bekleyen = [(o, m) for o, m in ozetler if (o, kod) not in varolan]
    log(f"{kod}: eksik {len(bekleyen)} / {len(ozetler)}")
    if not bekleyen:
        return 0
    yazilan = 0
    t0 = time.perf_counter()
    for bas in range(0, len(bekleyen), CEVIR_OBEGI):
        dilim = bekleyen[bas: bas + CEVIR_OBEGI]
        sonuclar = cevirmen.cevir_metinler([m for _, m in dilim])
        obek = [
            (o, kod, s) for (o, _), s in zip(dilim, sonuclar, strict=True) if s
        ]
        if obek:
            yazilan += yaz_obek(obek)
            for o, _, _ in obek:
                varolan.add((o, kod))
        gecen = time.perf_counter() - t0
        log(f"  {kod}: {bas + len(dilim)}/{len(bekleyen)} "
            f"yazilan={yazilan} {gecen:.0f} sn")
    return yazilan


def main() -> int:
    """CLI girişi."""
    ap = argparse.ArgumentParser(
        description="TMDB özetlerini Argos ile metin_cevirileri'ne doldur")
    ap.add_argument("--dil", help="yalnız bu hedef dil (ör. de)")
    ap.add_argument("--sinir", type=int, default=0,
                    help="yalnız ilk N özet (deneme için)")
    ap.add_argument("--kuru", action="store_true",
                    help="çeviri YAPMA, yalnız eksik sayısını raporla")
    a = ap.parse_args()

    hedefler = [a.dil] if a.dil else HEDEF_DILLER
    bilinmeyen = [d for d in hedefler if d not in HEDEF_DILLER]
    if bilinmeyen:
        raise SystemExit(f"Argos çifti kurulu değil: {','.join(bilinmeyen)}")

    ozetler = ozetleri_yukle(a.sinir)
    log(f"benzersiz İngilizce özet: {len(ozetler)}")
    if not ozetler:
        log("çevrilecek özet yok (tmdb_onbellek'te en-US satırı var mı?)")
        return 0

    varolan = mevcut_ciftler(hedefler)
    if a.kuru:
        for kod in hedefler:
            eksik = sum(1 for o, _ in ozetler if (o, kod) not in varolan)
            log(f"{kod}: eksik {eksik} / {len(ozetler)}")
        return 0

    for kod in hedefler:
        log(f"model en→{kod}")
        cevirmen = BatchCevirmen("en", kod)
        dil_doldur(kod, ozetler, varolan, cevirmen)
        del cevirmen

    rapor = psql(
        "SELECT dil || '=' || count(*)::text FROM metin_cevirileri "
        "WHERE dil IN ('" + "','".join(HEDEF_DILLER) + "') "
        # `GROUP BY 1` ifadenin İÇİNDEKİ count(*)'ı gruplamaya sokuyordu:
        # Postgres "aggregate functions are not allowed in GROUP BY" ile
        # DÜŞÜYORDU (29 Ağu 2026'da yakalandı — betiğin son adımı, yani tüm
        # çeviri bittikten SONRA patlıyor ve çıkış kodunu 1 yapıyordu).
        "GROUP BY dil ORDER BY dil;"
    )
    log("DOLULUK (gönderi + özet toplamı):\n" + rapor)
    return 0


if __name__ == "__main__":
    sys.exit(main())
