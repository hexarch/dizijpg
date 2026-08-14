#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Arama ipucu + Şirketler + Senarist anahtarlarını 45 dil dosyasına ekler.

UTF-8 ile dosyaya yazılır (heredoc bozmasın diye). Aynı turda çalıştırılır.
Mevcut anahtar varsa atlanır. Eski ipucu anahtarı sohbet.dart için durur.
"""
from __future__ import annotations

from pathlib import Path

DIL_DIZIN = Path(__file__).resolve().parents[2] / "lib" / "diller"

HINT = "Dizi, film, kişi veya şirket ara..."
SIRKET = "Şirketler"
SENARIST = "Senarist"

# Dil kodu → (ipucu, Şirketler, Senarist). Kesme işareti yok.
CEVIRILER: dict[str, tuple[str, str, str]] = {
    "en": ("Search shows, movies, people or companies...", "Companies", "Screenwriter"),
    "zh": ("搜索剧集、电影、人物或公司...", "公司", "编剧"),
    "hi": ("सीरीज़, फ़िल्म, व्यक्ति या कंपनी खोजो...", "कंपनियाँ", "पटकथा लेखक"),
    "es": ("Busca series, películas, personas o compañías...", "Compañías", "Guionista"),
    "fr": ("Cherche une série, un film, une personne ou une société...", "Sociétés", "Scénariste"),
    "ar": ("ابحث عن مسلسل أو فيلم أو شخص أو شركة...", "شركات", "كاتب سيناريو"),
    "bn": ("সিরিজ, সিনেমা, ব্যক্তি বা কোম্পানি খোঁজো...", "কোম্পানি", "চিত্রনাট্যকার"),
    "pt": ("Busque séries, filmes, pessoas ou empresas...", "Empresas", "Roteirista"),
    "ru": ("Поиск сериалов, фильмов, людей и компаний...", "Компании", "Сценарист"),
    "ur": ("سیریز، فلم، شخصیت یا کمپنی تلاش کریں...", "کمپنیاں", "اسکرین رائٹر"),
    "id": ("Cari serial, film, orang, atau perusahaan...", "Perusahaan", "Penulis naskah"),
    "de": ("Serie, Film, Person oder Unternehmen suchen...", "Unternehmen", "Drehbuchautor"),
    "ja": ("ドラマ・映画・人物・会社を検索...", "会社", "脚本家"),
    "sw": ("Tafuta mfululizo, filamu, mtu au kampuni...", "Kampuni", "Mwandishi wa filamu"),
    "mr": ("सीरीज, सिनेमा, व्यक्ती किंवा कंपनी शोधा...", "कंपन्या", "पटकथा लेखक"),
    "te": ("సిరీస్, సినిమా, వ్యక్తి లేదా కంపెనీని వెతుకు...", "కంపెనీలు", "స్క్రీన్ రైటర్"),
    "vi": ("Tìm phim bộ, phim lẻ, người hoặc công ty...", "Công ty", "Biên kịch"),
    "ko": ("드라마, 영화, 인물, 회사 검색...", "회사", "각본가"),
    "ta": ("தொடர், படம், நபர் அல்லது நிறுவனத்தைத் தேடு...", "நிறுவனங்கள்", "திரைக்கதையாளர்"),
    "it": ("Cerca serie, film, persone o società...", "Società", "Sceneggiatore"),
    "fa": ("سریال، فیلم، شخص یا شرکت جستجو کن...", "شرکت‌ها", "فیلم‌نامه‌نویس"),
    "pl": ("Szukaj serialu, filmu, osoby lub firmy...", "Firmy", "Scenarzysta"),
    "uk": ("Пошук серіалів, фільмів, людей і компаній...", "Компанії", "Сценарист"),
    "ro": ("Caută seriale, filme, persoane sau companii...", "Companii", "Scenarist"),
    "nl": ("Zoek een serie, film, persoon of bedrijf...", "Bedrijven", "Scenarist"),
    "th": ("ค้นหาซีรีส์ หนัง บุคคล หรือบริษัท...", "บริษัท", "นักเขียนบท"),
    "gu": ("સિરીઝ, ફિલ્મ, વ્યક્તિ કે કંપની શોધો...", "કંપનીઓ", "પટકથા લેખક"),
    "kn": ("ಸೀರೀಸ್, ಸಿನಿಮಾ, ವ್ಯಕ್ತಿ ಅಥವಾ ಕಂಪನಿ ಹುಡುಕು...", "ಕಂಪನಿಗಳು", "ಚಿತ್ರಕಥೆಗಾರ"),
    "ml": ("സീരീസ്, സിനിമ, വ്യക്തി അല്ലെങ്കിൽ കമ്പനി തിരയൂ...", "കമ്പനികൾ", "തിരക്കഥാകൃത്ത്"),
    "pa": ("ਸੀਰੀਜ਼, ਫ਼ਿਲਮ, ਵਿਅਕਤੀ ਜਾਂ ਕੰਪਨੀ ਖੋਜੋ...", "ਕੰਪਨੀਆਂ", "ਸਕ੍ਰੀਨਰਾਈਟਰ"),
    "ms": ("Cari siri, filem, orang atau syarikat...", "Syarikat", "Penulis skrip"),
    "my": ("ဇာတ်လမ်းတွဲ၊ ရုပ်ရှင်၊ လူ သို့မဟုတ် ကုမ္ပဏီ ရှာရန်...", "ကုမ္ပဏီများ", "ဇာတ်ညွှန်းရေးသူ"),
    "am": ("ድራማ፣ ፊልም፣ ሰው ወይም ኩባንያ ፈልግ...", "ኩባንያዎች", "ስክሪፕት ጸሃፊ"),
    "az": ("Serial, film, şəxs və ya şirkət axtar...", "Şirkətlər", "Ssenarist"),
    "el": ("Ψάξε σειρά, ταινία, πρόσωπο ή εταιρεία...", "Εταιρείες", "Σεναριογράφος"),
    "hu": ("Sorozat, film, személy vagy cég keresése...", "Cégek", "Forgatókönyvíró"),
    "cs": ("Hledat seriál, film, osobu nebo společnost...", "Společnosti", "Scénárista"),
    "sv": ("Sök serie, film, person eller bolag...", "Bolag", "Manusförfattare"),
    "he": ("חפש סדרה, סרט, אדם או חברה...", "חברות", "תסריטאי"),
    "fil": ("Maghanap ng serye, pelikula, tao, o kumpanya...", "Mga kumpanya", "Manunulat ng iskrip"),
    "sr": ("Претражи серије, филмове, особе или компаније...", "Компаније", "Сценариста"),
    "bg": ("Търси сериал, филм, човек или компания...", "Компании", "Сценарист"),
    "da": ("Søg efter serie, film, person eller selskab...", "Selskaber", "Manuskriptforfatter"),
    "fi": ("Hae sarjaa, elokuvaa, henkilöä tai yhtiötä...", "Yhtiöt", "Käsikirjoittaja"),
    "nb": ("Søk etter serie, film, person eller selskap...", "Selskaper", "Manusforfatter"),
}


def dart_str(s: str) -> str:
    """Dart tek tırnaklı dize; gerekirse kaçış."""
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


def ekle(yol: Path, kod: str) -> str:
    metin = yol.read_text(encoding="utf-8")
    if HINT in metin and SIRKET in metin and SENARIST in metin:
        return "var"
    if kod not in CEVIRILER:
        raise SystemExit(f"çeviri yok: {kod}")
    ipucu, sirketler, senarist = CEVIRILER[kod]
    blok = (
        f"  {dart_str(HINT)}: {dart_str(ipucu)},\n"
        f"  {dart_str(SIRKET)}: {dart_str(sirketler)},\n"
        f"  {dart_str(SENARIST)}: {dart_str(senarist)},\n"
    )
    i = metin.rfind("\n};")
    if i < 0:
        raise SystemExit(f"kapanış bulunamadı: {yol}")
    yol.write_text(metin[: i + 1] + blok + metin[i + 1 :], encoding="utf-8")
    return "eklendi"


def main() -> None:
    dosyalar = sorted(DIL_DIZIN.glob("dil_*.dart"))
    if len(dosyalar) != 45:
        raise SystemExit(f"45 dil dosyası bekleniyordu, {len(dosyalar)} bulundu")
    ozet: dict[str, int] = {"eklendi": 0, "var": 0}
    for yol in dosyalar:
        kod = yol.stem.removeprefix("dil_")
        durum = ekle(yol, kod)
        ozet[durum] += 1
        print(f"{kod}: {durum}")
    print(f"özet {ozet}")


if __name__ == "__main__":
    main()
