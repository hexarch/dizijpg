#!/usr/bin/env python3
"""Gönderi metinlerini Argos Translate ile 15 dile çevirip önbelleğe yazar.

Google Translate KULLANILMAZ. Motor: Argos paketleri + CTranslate2 (çevrimdışı).
Stanza cümle bölücü atlanır — o yol saatte ~80 metin üretiyordu; burada cümleler
toplu (batch) çevrilir.

Kaynak çoğunlukla Türkçe; pivot İngilizce (mevcut EN önbelleği ezilmez).

Hedef 15 dil — Ethnologue konuşur sırası + uygulamada olan / Argos paketi olan
kodlar: en, zh, hi, es, fr, ar, bn, pt, ru, ur, id, de, ja, vi, ko.

Sunucuda (host):
  /opt/dizijpg/argos-venv/bin/python3 /opt/dizijpg/argos_doldur.py
  /opt/dizijpg/argos-venv/bin/python3 /opt/dizijpg/argos_doldur.py --kuru
  /opt/dizijpg/argos-venv/bin/python3 /opt/dizijpg/argos_doldur.py --dil=ar

Veritabanı dışarı port açmadığı için `docker exec dizijpg-db psql` kullanılır.
INSERT ... ON CONFLICT DO NOTHING — mevcut satır ezilmez.
"""

from __future__ import annotations

import argparse
import csv
import io
import os
import re
import subprocess
import sys
import time
from collections.abc import Iterable

# Canlı API'yi boğmamak için iplik tavanı — ctranslate2 import'undan ÖNCE.
os.environ.setdefault("OMP_NUM_THREADS", "4")
os.environ.setdefault("OPENBLAS_NUM_THREADS", "4")
os.environ.setdefault("MKL_NUM_THREADS", "4")

DB_KAP = os.environ.get("ARGOS_DB_KAP", "dizijpg-db")
DB_KULLANICI = os.environ.get("ARGOS_DB_KULLANICI", "dizijpg")
DB_AD = os.environ.get("ARGOS_DB_AD", "dizijpg")

HEDEF_DILLER: list[str] = [
    "en", "zh", "hi", "es", "fr", "ar", "bn", "pt", "ru",
    "ur", "id", "de", "ja", "vi", "ko",
]
YAZMA_OBEGI = 120
CEVIR_OBEGI = 96  # metin / yazma turu
CT2_BATCH = 64    # cümle / CTranslate2 çağrısı

_HARF = re.compile(
    r"[A-Za-zÀ-ÖØ-öø-ÿΑ-ωА-я\u0600-\u06FF\u0900-\u097F"
    r"\u4E00-\u9FFF\u3040-\u30FF가-힣çğıöşüÇĞİÖŞÜ]",
)
# Ayırıcıları koru (cümle sonu + satır sonu)
_PARCA = re.compile(r"((?<=[.!?…。！？])\s+|\n)")


def damga() -> str:
    """Kısa zaman damgası (log satırı)."""
    return time.strftime("%Y-%m-%d %H:%M:%S")


def log(msg: str) -> None:
    """Stdout'a satır basar (nohup yönlendirmesi log dosyasına gider)."""
    print(f"[{damga()}] {msg}", flush=True)


def psql(sql: str) -> str:
    """Tek SQL çalıştırır; stdout döner."""
    return subprocess.check_output(
        [
            "docker", "exec", "-i", DB_KAP,
            "psql", "-U", DB_KULLANICI, "-d", DB_AD,
            "-v", "ON_ERROR_STOP=1", "-Atq", "-c", sql,
        ],
        text=True,
        stderr=subprocess.STDOUT,
    )


def psql_copy_csv(sql: str) -> list[list[str]]:
    """COPY ... TO STDOUT CSV çıktısını satır listesine çevirir."""
    ham = subprocess.check_output(
        [
            "docker", "exec", "-i", DB_KAP,
            "psql", "-U", DB_KULLANICI, "-d", DB_AD,
            "-v", "ON_ERROR_STOP=1", "-Atq", "-c", sql,
        ],
        text=True,
        stderr=subprocess.STDOUT,
    )
    return [satir for satir in csv.reader(io.StringIO(ham)) if satir]


def sadece_etiket(metin: str) -> bool:
    """Hashtag / mention / URL / emoji dışında harf kalmıyor mu?"""
    s = re.sub(r"https?://\S+", " ", metin)
    s = re.sub(r"[#@][\w.]+", " ", s, flags=re.UNICODE)
    return _HARF.search(s) is None


def parcala(metin: str) -> list[str]:
    """Metni cümle / satır parçalarına böler; ayırıcılar ayrı eleman kalır."""
    if len(metin) <= 400:
        return [metin]
    parcalar = [p for p in _PARCA.split(metin) if p != ""]
    # Noktasız uzun blokları boşluktan kır
    cikti: list[str] = []
    for p in parcalar:
        if len(p) <= 500 or not _HARF.search(p):
            cikti.append(p)
            continue
        while len(p) > 500:
            kes = p.rfind(" ", 0, 500)
            if kes < 150:
                kes = 500
            cikti.append(p[:kes])
            p = p[kes:]
        if p:
            cikti.append(p)
    return cikti or [metin]


class BatchCevirmen:
    """Argos paketi + CTranslate2; Stanza yok, beam=1, toplu cümle."""

    def __init__(self, from_code: str, to_code: str) -> None:
        """Kurulu Argos paketinden çevirmen açar."""
        import argostranslate.package as paket
        import ctranslate2

        pkg = next(
            (
                x for x in paket.get_installed_packages()
                if x.from_code == from_code and x.to_code == to_code
            ),
            None,
        )
        if pkg is None:
            raise SystemExit(f"Argos paketi yok: {from_code}->{to_code}")
        self.pkg = pkg
        self.tok = pkg.tokenizer
        self.prefix = pkg.target_prefix or ""
        self.tr = ctranslate2.Translator(
            str(pkg.package_path / "model"),
            device="cpu",
            inter_threads=4,
            intra_threads=4,
            compute_type="default",
        )

    def _decode(self, tokens: list[str]) -> str:
        """CT2 çıktı tokenlarını metne çevirir (Argos ile aynı temizlik)."""
        value = self.tok.decode(tokens)
        if self.prefix and value.startswith(self.prefix):
            value = value[len(self.prefix):]
        if value[:1] == " ":
            value = value[1:]
        return value

    def cevir_cumleler(self, cumleler: list[str]) -> list[str]:
        """Cümle listesini öbek öbek çevirir; sıra korunur."""
        if not cumleler:
            return []
        cikti: list[str] = [""] * len(cumleler)
        for bas in range(0, len(cumleler), CT2_BATCH):
            dilim = cumleler[bas: bas + CT2_BATCH]
            tokenli = [self.tok.encode(c) for c in dilim]
            on_ek = [[self.prefix]] * len(tokenli) if self.prefix else None
            sonuclar = self.tr.translate_batch(
                tokenli,
                target_prefix=on_ek,
                replace_unknowns=True,
                max_batch_size=CT2_BATCH,
                batch_type="examples",
                beam_size=1,
                num_hypotheses=1,
            )
            for i, s in enumerate(sonuclar):
                cikti[bas + i] = self._decode(s.hypotheses[0])
        return cikti

    def cevir_metinler(self, metinler: list[str]) -> list[str | None]:
        """Birden fazla tam metni parçalayıp toplu çevirir."""
        # (metin_idx, parca_idx) eşlemesi
        is_istek: list[tuple[int, int]] = []
        cumleler: list[str] = []
        yapilar: list[list[str]] = []
        for mi, metin in enumerate(metinler):
            parcalar = parcala(metin)
            yapilar.append(parcalar)
            for pi, p in enumerate(parcalar):
                if _HARF.search(p) and len(p.strip()) > 1:
                    is_istek.append((mi, pi))
                    cumleler.append(p)
        try:
            cevrilmis = self.cevir_cumleler(cumleler)
        except Exception as e:  # noqa: BLE001
            log(f"  batch hatasi: {type(e).__name__}: {e}")
            return [None] * len(metinler)
        for (mi, pi), y in zip(is_istek, cevrilmis, strict=True):
            yapilar[mi][pi] = y
        son: list[str | None] = []
        for parcalar in yapilar:
            birlesik = "".join(parcalar).strip()
            son.append(birlesik or None)
        return son


def yaz_obek(satirlar: list[tuple[str, str, str]]) -> int:
    """(ozet, dil, metin) öbeğini temp tablo + ON CONFLICT DO NOTHING ile yazar."""
    if not satirlar:
        return 0
    buf = io.StringIO()
    yazici = csv.writer(buf, lineterminator="\n", quoting=csv.QUOTE_MINIMAL)
    for ozet, dil, metin in satirlar:
        temiz = metin.replace("\r\n", "\n").replace("\x00", "")
        if temiz.strip() == "\\.":
            temiz = "."
        yazici.writerow([ozet, dil, temiz])
    csv_bayt = buf.getvalue().encode("utf-8")
    govde = (
        "CREATE TEMP TABLE _argos "
        "(ozet text NOT NULL, dil text NOT NULL, metin text NOT NULL);\n"
        "COPY _argos FROM STDIN WITH (FORMAT csv, ENCODING 'UTF8');\n"
    ).encode("utf-8") + csv_bayt + (
        "\\.\n"
        "INSERT INTO metin_cevirileri (ozet, dil, metin)\n"
        "SELECT ozet, dil, metin FROM _argos\n"
        "ON CONFLICT (ozet, dil) DO NOTHING;\n"
    ).encode("utf-8")
    proc = subprocess.run(
        [
            "docker", "exec", "-i", DB_KAP,
            "psql", "-U", DB_KULLANICI, "-d", DB_AD,
            "-v", "ON_ERROR_STOP=1", "-Atq",
        ],
        input=govde,
        capture_output=True,
    )
    if proc.returncode != 0:
        err = (proc.stderr or proc.stdout or b"").decode("utf-8", "replace")
        raise RuntimeError(f"psql yazma hatasi: {err[:800]}")
    return len(satirlar)


def metinleri_yukle() -> list[tuple[str, str, str]]:
    """Benzersiz gönderi metinleri: (ozet, kaynak_dil, metin)."""
    sql = """
COPY (
  SELECT DISTINCT ON (md5(btrim(metin)))
         md5(btrim(metin)),
         COALESCE(kaynak_dil, ''),
         btrim(metin)
    FROM yorumlar
   WHERE metin IS NOT NULL AND length(btrim(metin)) > 2
   ORDER BY md5(btrim(metin)), id
) TO STDOUT WITH (FORMAT csv, ENCODING 'UTF8');
"""
    return [(s[0], s[1], s[2]) for s in psql_copy_csv(sql) if len(s) >= 3]


def mevcut_ciftler(diller: Iterable[str]) -> set[tuple[str, str]]:
    """(ozet, dil) önbellekte zaten var olan çiftler."""
    liste = ",".join("'" + d.replace("'", "") + "'" for d in diller)
    sql = f"""
COPY (
  SELECT ozet, dil FROM metin_cevirileri WHERE dil IN ({liste})
) TO STDOUT WITH (FORMAT csv, ENCODING 'UTF8');
"""
    return {(s[0], s[1]) for s in psql_copy_csv(sql) if len(s) >= 2}


def en_onbellek() -> dict[str, str]:
    """ozet → mevcut İngilizce çeviri."""
    sql = """
COPY (
  SELECT ozet, metin FROM metin_cevirileri WHERE dil = 'en'
) TO STDOUT WITH (FORMAT csv, ENCODING 'UTF8');
"""
    return {s[0]: s[1] for s in psql_copy_csv(sql) if len(s) >= 2}


def dil_doldur(
    kod: str,
    metinler: list[tuple[str, str, str]],
    en_map: dict[str, str],
    varolan: set[tuple[str, str]],
    cevirmen: BatchCevirmen,
) -> tuple[int, int]:
    """Bir hedef dil için eksikleri toplu çevirir. (yazilan, atlanan) döner."""
    bekleyen = [(o, k, m) for o, k, m in metinler if (o, kod) not in varolan]
    log(f"{kod}: eksik {len(bekleyen)} / {len(metinler)}")
    if not bekleyen:
        return 0, 0
    yazilan = 0
    atlanan = 0
    t0 = time.perf_counter()
    for bas in range(0, len(bekleyen), CEVIR_OBEGI):
        dilim = bekleyen[bas: bas + CEVIR_OBEGI]
        kopya_satir: list[tuple[str, str, str]] = []
        cevrilecek_ozet: list[str] = []
        cevrilecek_src: list[str] = []
        for ozet, kaynak, metin in dilim:
            if sadece_etiket(metin):
                kopya_satir.append((ozet, kod, metin))
                continue
            src = en_map.get(ozet) or (metin if kaynak == "en" else None)
            if not src:
                atlanan += 1
                continue
            cevrilecek_ozet.append(ozet)
            cevrilecek_src.append(src)
        sonuclar = cevirmen.cevir_metinler(cevrilecek_src) if cevrilecek_src else []
        obek = list(kopya_satir)
        for ozet, sonuc in zip(cevrilecek_ozet, sonuclar, strict=True):
            if not sonuc:
                atlanan += 1
                continue
            obek.append((ozet, kod, sonuc))
        if obek:
            yaz_obek(obek)
            yazilan += len(obek)
            for ozet, _, _ in obek:
                varolan.add((ozet, kod))
        biten = min(bas + CEVIR_OBEGI, len(bekleyen))
        if biten % 256 == 0 or biten == len(bekleyen):
            log(
                f"  {kod} {biten}/{len(bekleyen)} yazilan={yazilan} "
                f"atlanan={atlanan} {time.perf_counter() - t0:.0f}s"
            )
    log(f"{kod}: bitti yazilan={yazilan} atlanan={atlanan}")
    return yazilan, atlanan


def kuru_rapor(metinler: list[tuple[str, str, str]], varolan: set[tuple[str, str]]) -> None:
    """Yazmadan dil dil eksik sayısını basar."""
    print(f"benzersiz metin: {len(metinler)}")
    for kod in HEDEF_DILLER:
        eksik = sum(1 for o, _, _ in metinler if (o, kod) not in varolan)
        print(f"  {kod}: kayitli {len(metinler) - eksik}  eksik {eksik}")


def main() -> int:
    """Komut satırı girişi."""
    ap = argparse.ArgumentParser(description="Argos ile metin_cevirileri doldur")
    ap.add_argument("--kuru", action="store_true", help="yalnız say, yazma")
    ap.add_argument("--dil", help="tek hedef dil (ör. ar)")
    args = ap.parse_args()

    hedefler = HEDEF_DILLER
    if args.dil:
        if args.dil not in HEDEF_DILLER:
            print(f"bilinmeyen dil: {args.dil}", file=sys.stderr)
            return 2
        hedefler = [args.dil]

    log("metinler okunuyor...")
    metinler = metinleri_yukle()
    varolan = mevcut_ciftler(HEDEF_DILLER)
    en_map = en_onbellek()
    log(f"benzersiz={len(metinler)} onbellek_cift={len(varolan)} en={len(en_map)}")

    if args.kuru:
        kuru_rapor(metinler, varolan)
        return 0

    # EN pivot zaten dolu olmalı; kalan varsa Argos tr→en (Stanza'lı, az kayıt)
    eksik_en = [(o, k, m) for o, k, m in metinler if (o, "en") not in varolan]
    log(f"EN eksik {len(eksik_en)} / {len(metinler)}")
    if eksik_en:
        log("model tr→en (kalan pivot)")
        tr_en = BatchCevirmen("tr", "en")
        obek: list[tuple[str, str, str]] = []
        src_ozet: list[str] = []
        src_metin: list[str] = []
        for ozet, kaynak, metin in eksik_en:
            if kaynak == "en" or sadece_etiket(metin):
                obek.append((ozet, "en", metin))
                en_map[ozet] = metin
                continue
            src_ozet.append(ozet)
            src_metin.append(metin)
        if src_metin:
            for i in range(0, len(src_metin), CEVIR_OBEGI):
                dilim_o = src_ozet[i: i + CEVIR_OBEGI]
                dilim_m = src_metin[i: i + CEVIR_OBEGI]
                for ozet, sonuc in zip(dilim_o, tr_en.cevir_metinler(dilim_m), strict=True):
                    if sonuc:
                        obek.append((ozet, "en", sonuc))
                        en_map[ozet] = sonuc
        if obek:
            yaz_obek(obek)
            for ozet, _, _ in obek:
                varolan.add((ozet, "en"))
        log(f"EN bitti harita={len(en_map)}")
        del tr_en

    for kod in hedefler:
        if kod == "en":
            continue
        log(f"model en→{kod}")
        cevirmen = BatchCevirmen("en", kod)
        dil_doldur(kod, metinler, en_map, varolan, cevirmen)
        del cevirmen

    ozet = psql(
        "SELECT dil || '=' || count(*)::text FROM metin_cevirileri "
        "WHERE dil IN ('" + "','".join(HEDEF_DILLER) + "') "
        "GROUP BY 1 ORDER BY 1;"
    )
    log("DOLULUK:\n" + ozet)
    return 0


if __name__ == "__main__":
    sys.exit(main())
