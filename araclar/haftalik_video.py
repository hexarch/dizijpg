# -*- coding: utf-8 -*-
"""dizi.jpg — haftalık listenin 10 DİLDE seslendirilmiş videosu (Reels/Shorts).

`haftalik_gonderi.py` ile AYNI veriyi kullanır (o dosyayı modül olarak
içe aktarır); farkı biçim: 1080×1920 dikey video, geri sayım 10 → 1,
her dilde ayrı seslendirme (ElevenLabs) ve o dilin TMDB başlıkları.

Kullanım:
    python3 araclar/haftalik_video.py                 # 10 dilin hepsi
    python3 araclar/haftalik_video.py --dil tr
    python3 araclar/haftalik_video.py --dil tr --sessiz   # seslendirmesiz deneme
    python3 araclar/haftalik_video.py --hafta 2026-08-31

Çıktı: projeler/cikti/instagram/<yyyy>-h<hafta>/video/<dil>.mp4

DİL SEÇİMİ LATİN ALFABESİYLE SINIRLI: marka fontu Poppins yalnız Latin +
Latin-Ext alt kümesiyle paketlendi (app/pubspec.yaml notu). Rusça/Arapça/
Hintçe eklenecekse önce o alfabeyi taşıyan bir font ve — Arapça için —
harf birleştirme + RTL düzeni gerekir (bkz. magaza/ortak/uretim/cerceve.py).

MÜZİK YOK: telifsiz olduğunu KANITLAYAMADIĞIMIZ hiçbir parça bu videoya
girmez; Instagram'ın kendi müzik kütüphanesi gönderi yüklenirken eklenebilir.

SES: ElevenLabs (`~/.dizijpg-eleven.env` içinde ELEVENLABS_API_KEY).
Türkçe için İstanbul aksanlı yerli ses, diğerleri için çok dilli model.
"""
import argparse
import json
import os
import subprocess
import sys
import urllib.request

from PIL import Image, ImageDraw

BURASI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BURASI)
import haftalik_gonderi as HG                                    # noqa: E402

G, Y = 1080, 1920
KENAR = 72
FPS = 30

ELEVEN_URL = "https://api.elevenlabs.io/v1/text-to-speech"
ELEVEN_MODEL = "eleven_multilingual_v2"
VARSAYILAN_SES = "TX3LPaxmHKxFdv7VOQHJ"        # Liam — enerjik, sosyal medya tonu
SESLER = {"tr": "4XumGDZjxmgp3U7xXaul"}        # Gamze Baykan — İstanbul aksanı

# TMDB dil kodu + ekran/seslendirme metinleri. Sayılar seslendirmede rakam
# olarak yazılır; model onları hedef dilde okur.
DILLER = {
    "tr": {"tmdb": "tr-TR", "b1": "Haftanın en çok", "b2": "izlenen 10 dizisi",
           "vo_giris": "Bu haftanın en çok izlenen on dizisi.",
           "vo_cikis": "Sen bu hafta ne izledin? Dizi nokta je pe ge.",
           "cikis": "Haftanı dizi.jpg'de tut"},
    "en": {"tmdb": "en-US", "b1": "The 10 most watched", "b2": "shows this week",
           "vo_giris": "The ten most watched shows this week.",
           "vo_cikis": "What did you watch this week? dizi dot j p g.",
           "cikis": "Keep your week on dizi.jpg"},
    "es": {"tmdb": "es-ES", "b1": "Las 10 series más", "b2": "vistas de la semana",
           "vo_giris": "Las diez series más vistas de esta semana.",
           "vo_cikis": "¿Y tú qué viste esta semana? dizi punto j p g.",
           "cikis": "Guarda tu semana en dizi.jpg"},
    "pt": {"tmdb": "pt-BR", "b1": "As 10 séries mais", "b2": "vistas da semana",
           "vo_giris": "As dez séries mais assistidas desta semana.",
           "vo_cikis": "E você, o que assistiu esta semana? dizi ponto j p g.",
           "cikis": "Guarde sua semana no dizi.jpg"},
    "fr": {"tmdb": "fr-FR", "b1": "Les 10 séries les", "b2": "plus vues du moment",
           "vo_giris": "Les dix séries les plus regardées cette semaine.",
           "vo_cikis": "Et toi, tu as regardé quoi cette semaine ? dizi point j p g.",
           "cikis": "Garde ta semaine sur dizi.jpg"},
    "de": {"tmdb": "de-DE", "b1": "Die 10 meistgesehenen", "b2": "Serien der Woche",
           "vo_giris": "Die zehn meistgesehenen Serien dieser Woche.",
           "vo_cikis": "Was hast du diese Woche geschaut? dizi punkt j p g.",
           "cikis": "Halte deine Woche auf dizi.jpg fest"},
    "it": {"tmdb": "it-IT", "b1": "Le 10 serie più", "b2": "viste della settimana",
           "vo_giris": "Le dieci serie più viste di questa settimana.",
           "vo_cikis": "E tu cosa hai visto questa settimana? dizi punto j p g.",
           "cikis": "Tieni la tua settimana su dizi.jpg"},
    "nl": {"tmdb": "nl-NL", "b1": "De 10 meest bekeken", "b2": "series van de week",
           "vo_giris": "De tien meest bekeken series van deze week.",
           "vo_cikis": "Wat keek jij deze week? dizi punt j p g.",
           "cikis": "Bewaar je week op dizi.jpg"},
    "pl": {"tmdb": "pl-PL", "b1": "10 najczęściej", "b2": "oglądanych seriali",
           "vo_giris": "Dziesięć najczęściej oglądanych seriali w tym tygodniu.",
           "vo_cikis": "A ty co oglądałeś w tym tygodniu? dizi kropka j p g.",
           "cikis": "Zapisz swój tydzień na dizi.jpg"},
    "id": {"tmdb": "id-ID", "b1": "10 serial paling", "b2": "banyak ditonton",
           "vo_giris": "Sepuluh serial paling banyak ditonton minggu ini.",
           "vo_cikis": "Kamu nonton apa minggu ini? dizi titik j p g.",
           "cikis": "Simpan pekanmu di dizi.jpg"},
}


# --------------------------------------------------------------------- ses

def eleven_anahtar():
    if os.environ.get("ELEVENLABS_API_KEY"):
        return os.environ["ELEVENLABS_API_KEY"]
    # Zamanlanmış koşu ~/Library altındaki kopyadan çalışır ve ev dizinindeki
    # .env'i okuyabilir; yine de kopya kendi jetonunu taşır (kur() yazar).
    kopya = os.path.join(HG.CALISMA, "eleven.token")
    if HG.CALISIYOR_KOPYADAN and os.path.exists(kopya):
        with open(kopya, encoding="utf-8") as f:
            return f.read().strip()
    yol = os.path.expanduser("~/.dizijpg-eleven.env")
    with open(yol, encoding="utf-8") as f:
        for satir in f:
            if satir.startswith("ELEVENLABS_API_KEY="):
                return satir.split("=", 1)[1].strip()
    raise RuntimeError("ELEVENLABS_API_KEY yok (~/.dizijpg-eleven.env)")


_ANAHTAR = None


def seslendir(metin, dil, hedef):
    """Metni mp3'e çevirir (diske önbellekli — aynı cümle iki kez ücret yazmaz)."""
    global _ANAHTAR
    if os.path.exists(hedef):
        return hedef
    if _ANAHTAR is None:
        _ANAHTAR = eleven_anahtar()
    ses = SESLER.get(dil, VARSAYILAN_SES)
    govde = json.dumps({
        "text": metin, "model_id": ELEVEN_MODEL,
        "voice_settings": {"stability": 0.45, "similarity_boost": 0.75,
                           "style": 0.35, "use_speaker_boost": True},
    }).encode()
    istek = urllib.request.Request(
        f"{ELEVEN_URL}/{ses}?output_format=mp3_44100_128", data=govde,
        headers={"xi-api-key": _ANAHTAR, "Content-Type": "application/json"})
    with urllib.request.urlopen(istek, timeout=90) as y, open(hedef, "wb") as f:
        f.write(y.read())
    return hedef


def sure(dosya):
    r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                        "-of", "csv=p=0", dosya], capture_output=True, text=True)
    return float(r.stdout.strip())


# ------------------------------------------------------------------ kareler

def tuval_dikey():
    im = Image.new("RGB", (G, Y), HG.ZEMIN)
    isik = Image.new("L", (G, Y), 0)
    ImageDraw.Draw(isik).ellipse([G - 620, -420, G + 260, 460], fill=255)
    from PIL import ImageFilter
    isik = isik.filter(ImageFilter.GaussianBlur(200))
    im = Image.composite(Image.new("RGB", (G, Y), (46, 39, 12)), im, isik)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, G, 8], fill=HG.SARI)
    return im, d


def kare_giris(dil, b, s):
    im, d = tuval_dikey()
    HG.logo_yaz(im, KENAR, 150, 96)
    m = DILLER[dil]
    f = HG.font("Bold", 82)
    d.text((KENAR, 700), m["b1"], font=f, fill=HG.BEYAZ)
    d.text((KENAR, 700 + 100), m["b2"], font=f, fill=HG.SARI)
    fr = HG.font("SemiBold", 34)
    metin = HG.tarih_metni(b, s).upper()
    w = HG.gen(d, metin, fr)
    d.rounded_rectangle([KENAR, 940, KENAR + w + 52, 1010], 35, fill=HG.IKINCIL,
                        outline=HG.KOYU_GRI, width=2)
    d.text((KENAR + 26, 954), metin, font=fr, fill=HG.GRI)
    return im


def kare_oge(sira, oge):
    im, d = tuval_dikey()
    afis_g, afis_y = 724, 1086
    x, y = (G - afis_g) // 2, 356
    HG.kutu_ciz(im, d, HG.gorsel_indir(oge["afis"], "w780"), x, y, afis_g, afis_y, 28)

    r = 128
    d.rounded_rectangle([x, y, x + r, y + r], 28, fill=HG.SARI)
    d.rectangle([x, y + r - 28, x + 28, y + r], fill=HG.SARI)
    d.rectangle([x + r - 28, y, x + r, y + 28], fill=HG.SARI)
    d.text((x + r / 2, y + r / 2 - 2), str(sira), font=HG.font("Bold", 74),
           fill=HG.ZEMIN, anchor="mm")

    f = HG.font("Bold", 60)
    ty = y + afis_y + 60
    for satir in HG.sar(d, oge["ad"], f, G - 2 * KENAR, 2):
        d.text((G / 2, ty), satir, font=f, fill=HG.BEYAZ, anchor="ma")
        ty += 72
    return im


def kare_cikis(dil):
    im, d = tuval_dikey()
    HG.logo_yaz(im, (G - 420) // 2, 760, 120)
    f = HG.font("Bold", 56)
    d.text((G / 2, 1010), DILLER[dil]["cikis"], font=f, fill=HG.BEYAZ, anchor="ma")
    fs = HG.font("SemiBold", 46)
    d.text((G / 2, 1110), HG.SITE, font=fs, fill=HG.SARI, anchor="ma")
    return im


# ------------------------------------------------------------------- video

def parca_uret(png, mp3, mp4, saniye):
    """Tek segment: duran kare + yavaş zoom + kendi sesi.

    ZOOM NEDEN: 30 saniye boyunca hiç kıpırdamayan kareler Reels'te 'donmuş
    görsel' gibi okunuyor; %6'lık yavaş yakınlaşma videoyu canlı tutuyor."""
    kare_sayisi = max(2, int(saniye * FPS))
    suzgec = (f"scale={G * 2}:{Y * 2},"
              f"zoompan=z='min(zoom+0.00035,1.06)':d={kare_sayisi}:"
              f"x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s={G}x{Y}:fps={FPS},"
              f"fade=t=in:st=0:d=0.25,format=yuv420p")
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-loop", "1", "-i", png, "-i", mp3,
         "-filter_complex", f"[0:v]{suzgec}[v];[1:a]apad=pad_dur=0.45[a]",
         "-map", "[v]", "-map", "[a]", "-t", f"{saniye:.3f}",
         "-c:v", "libx264", "-preset", "veryfast", "-crf", "20",
         "-c:a", "aac", "-b:a", "160k", "-ar", "44100", "-ac", "2",
         "-pix_fmt", "yuv420p", "-r", str(FPS), mp4], check=True)


def sessiz_parca(png, mp4, saniye):
    kare_sayisi = max(2, int(saniye * FPS))
    suzgec = (f"scale={G * 2}:{Y * 2},"
              f"zoompan=z='min(zoom+0.00035,1.06)':d={kare_sayisi}:"
              f"x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s={G}x{Y}:fps={FPS},"
              f"fade=t=in:st=0:d=0.25,format=yuv420p")
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-loop", "1", "-i", png,
         "-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo",
         "-filter_complex", f"[0:v]{suzgec}[v]", "-map", "[v]", "-map", "1:a",
         "-t", f"{saniye:.3f}", "-c:v", "libx264", "-preset", "veryfast",
         "-crf", "20", "-c:a", "aac", "-b:a", "160k", "-r", str(FPS),
         "-pix_fmt", "yuv420p", mp4], check=True)


def video_uret(dil, b, s, cikti_dizin, sessiz=False):
    m = DILLER[dil]
    HG.bilgi(f"{dil}: veri + başlıklar ({m['tmdb']})")
    satirlar = HG.sorgu(HG.SQL_DIZILER.format(**HG.pencere(b, s)))
    yasak = HG.haric("tv")
    ogeler = []
    for r in satirlar:
        if r["tmdb_id"] in yasak:
            continue
        v = HG.tmdb(f"/tv/{r['tmdb_id']}", language=m["tmdb"])
        afis = v.get("poster_path") or HG.tmdb(
            f"/tv/{r['tmdb_id']}", language="en-US").get("poster_path")
        ogeler.append({"ad": v.get("name") or v.get("original_name") or "",
                       "afis": afis})
        if len(ogeler) == 10:
            break
    if len(ogeler) < 10:
        HG.uyari(f"{dil}: liste 10'a dolmadı, video üretilmedi")
        return None

    gecici = os.path.join(cikti_dizin, ".gecici", dil)
    os.makedirs(gecici, exist_ok=True)
    parcalar = []

    # geri sayım: 10 → 1 (ızgara gönderisinin TERSİ; videoda merak eğrisi
    # sondaki birinciye doğru yükselmeli)
    sahneler = [("giris", kare_giris(dil, b, s), m["vo_giris"])]
    for i in range(9, -1, -1):
        sahneler.append((f"s{i + 1:02d}", kare_oge(i + 1, ogeler[i]),
                         f"{i + 1}. {ogeler[i]['ad']}"))
    sahneler.append(("cikis", kare_cikis(dil), m["vo_cikis"]))

    for ad, kare, metin in sahneler:
        png = os.path.join(gecici, f"{ad}.png")
        mp4 = os.path.join(gecici, f"{ad}.mp4")
        kare.save(png)
        if sessiz:
            sessiz_parca(png, mp4, 2.4)
        else:
            mp3 = seslendir(metin, dil, os.path.join(gecici, f"{ad}.mp3"))
            parca_uret(png, mp3, mp4, sure(mp3) + 0.45)
        parcalar.append(mp4)

    liste = os.path.join(gecici, "liste.txt")
    with open(liste, "w", encoding="utf-8") as f:
        for p in parcalar:
            f.write(f"file '{p}'\n")
    hedef = os.path.join(cikti_dizin, f"{dil}.mp4")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat",
                    "-safe", "0", "-i", liste, "-c", "copy", hedef], check=True)
    # Ara parçalar TEMİZLENİR: 12 segmentin png+mp4'ü dil başına ~19 MB tutuyor
    # (ölçüldü: 10 dil = 187 MB). Seslendirme mp3'leri KALIR — tekrar üretim
    # ücretsiz olsun diye önbellek görevi görürler.
    for dosya in os.listdir(gecici):
        if dosya.endswith((".png", ".mp4", ".txt")):
            os.remove(os.path.join(gecici, dosya))
    HG.tamam(f"{hedef}  ({os.path.getsize(hedef) // 1024} KB, {sure(hedef):.1f} sn)")
    return hedef


def main():
    a = argparse.ArgumentParser(description="dizi.jpg haftalık video (10 dil)")
    a.add_argument("--hafta")
    a.add_argument("--dil", default="hepsi", help="tr | en | ... | hepsi")
    a.add_argument("--sessiz", action="store_true", help="seslendirmesiz deneme")
    p = a.parse_args()

    b, s = HG.hafta_araligi(p.hafta)
    HG.bilgi(f"hafta: {HG.tarih_metni(b, s)}")
    dizin = os.path.join(HG.CIKTI_KOK, HG.hafta_klasoru(b), "video")
    os.makedirs(dizin, exist_ok=True)
    diller = list(DILLER) if p.dil == "hepsi" else [p.dil]
    for dil in diller:
        if dil not in DILLER:
            HG.hata(f"bilinmeyen dil: {dil}")
            return 1
        video_uret(dil, b, s, dizin, sessiz=p.sessiz)
    return 0


if __name__ == "__main__":
    sys.exit(main())
