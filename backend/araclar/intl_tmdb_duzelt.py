#!/usr/bin/env python3
"""Yanlış TMDB id'lerini intl_profiller.json içinde kanıtlı numaralarla değiştirir.

Sıra önemli: The Raid 2 (94329→180299) önce, Raid 1 (71469→94329) sonra.
"""

from __future__ import annotations

import json
from pathlib import Path

KOK = Path(__file__).resolve().parent
JSON_YOL = KOK / "intl_profiller.json"

# (tur, eski, yeni) — zincirler önce
HARITA: list[tuple[str, int, int]] = [
    ("movie", 94329, 180299),  # The Raid 2
    ("movie", 71469, 94329),   # The Raid
    ("movie", 479, 20992),     # Брат
    ("movie", 1443, 666),      # Central do Brasil
    ("movie", 1667, 11190),    # Возвращение
    ("movie", 1690, 3040),     # Ночной дозор
    ("movie", 4488, 219),      # Volver
    ("movie", 10427, 19552),   # Mùi đu đủ xanh
    ("movie", 10664, 7347),    # Tropa de Elite
    ("movie", 242578, 265180), # Левиафан
    ("movie", 265208, 411088), # Contratiempo
    ("movie", 334543, 360814), # Dangal
    ("movie", 397422, 416477), # The Big Sick
    ("movie", 426426, 428495), # Nile Hilton
    ("movie", 447055, 467012), # Pengabdi Setan
    ("movie", 480414, 567973), # Hai Phượng
    ("movie", 504562, 517814), # كفرناحوم
    ("movie", 893341, 464293), # Maula Jatt
    ("movie", 948969, 962571), # Joyland
    ("tv", 2832, 890),         # Evangelion
    ("tv", 10950, 30981),      # Monster
    ("tv", 30984, 30991),      # Cowboy Bebop
    ("tv", 30985, 1063),       # Samurai Champloo
    ("tv", 42586, 42509),      # Steins;Gate
    ("tv", 46260, 46298),      # HxH 2011
    ("tv", 61181, 66980),      # Babylon Berlin
    ("tv", 62746, 62476),      # Le Bureau
    ("tv", 67198, 68467),      # 3%
    ("tv", 67744, 79352),      # Sacred Games
    ("tv", 80752, 88236),      # How to Sell Drugs Online
    ("tv", 82156, 87508),      # Delhi Crime
    ("tv", 82230, 81133),      # 延禧攻略
    ("tv", 87917, 87382),      # Ramy
    ("tv", 90669, 95202),      # Эпидемия
    ("tv", 90977, 96677),      # Lupin
    ("tv", 91734, 106590),     # ما وراء الطبيعة
    ("tv", 95480, 95479),      # 呪術廻戦 (Slow Horses 95480)
    ("tv", 96199, 90761),      # 陈情令
    ("tv", 110316, 128883),    # 갯마을 차차차
    ("tv", 123356, 126308),    # Shōgun
    ("tv", 136311, 206010),    # Kleo
    ("tv", 125988, 95480),     # Slow Horses (Silo değildi)
]


def yuru(obj: object, tur: str, eski: int, yeni: int) -> int:
    """tur+tmdb_id çiftini ağaçta değiştirir. Değişen düğüm sayısı."""
    n = 0
    if isinstance(obj, dict):
        if obj.get("tur") == tur and int(obj.get("tmdb_id") or 0) == eski:
            obj["tmdb_id"] = yeni
            n += 1
        for v in obj.values():
            n += yuru(v, tur, eski, yeni)
    elif isinstance(obj, list):
        for v in obj:
            n += yuru(v, tur, eski, yeni)
    return n


def tekil_yapimlar(p: dict) -> None:
    """Aynı (tur,id) iki kez kalmasın; son yazılan kazansın."""
    gorulen: dict[tuple[str, int], dict] = {}
    for y in p.get("yapimlar", []):
        gorulen[(y["tur"], int(y["tmdb_id"]))] = y
    p["yapimlar"] = list(gorulen.values())
    for liste in p.get("listeler", []):
        og: dict[tuple[str, int], dict] = {}
        for o in liste.get("ogeler", []):
            og[(o["tur"], int(o["tmdb_id"]))] = o
        liste["ogeler"] = list(og.values())
    fav: dict[tuple[str, int], dict] = {}
    for f in p.get("favoriler", []):
        fav[(f["tur"], int(f["tmdb_id"]))] = f
    p["favoriler"] = list(fav.values())


def main() -> None:
    """JSON'daki sahte id'leri TMDB aramasıyla doğrulanmış numaralarla değiştirir."""
    data = json.loads(JSON_YOL.read_text(encoding="utf-8"))
    toplam = 0
    for tur, eski, yeni in HARITA:
        n = yuru(data, tur, eski, yeni)
        toplam += n
        print(f"  {tur} {eski} → {yeni}  ({n})")
    for p in data:
        tekil_yapimlar(p)
    JSON_YOL.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"bitti degisen_düğüm={toplam} profil={len(data)}")


if __name__ == "__main__":
    main()
