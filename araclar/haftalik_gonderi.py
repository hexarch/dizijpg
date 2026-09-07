# -*- coding: utf-8 -*-
"""dizi.jpg — haftalık Instagram gönderi üreticisi.

HER PAZARTESİ 09:00'da (launchd: araclar/com.dizijpg.haftalikgonderi.plist)
geçen ISO haftasının (Pzt 00:00 → Pzt 00:00, Europe/Istanbul) özet
gönderilerini üretir:

  diziler   → "Haftanın en çok izlenen 10 dizisi"
  oyuncu    → "Haftanın en beğenilen 10 oyuncusu"
  film      → "Haftanın en beğenilen 10 filmi"
  studyo    → "Haftanın en beğenilen 10 stüdyosu"
  yonetmen  → "Haftanın en beğenilen 10 yönetmeni"
Hepsi ONLUK LİSTE ve 1080x1350 (Instagram dikey).

GÖRSELDE VE METİNDE SAYI YOK (kullanıcı kuralı, 7 Eyl 2026): kaç kişi izledi,
kaç oy, kaç puan, "N yapımı beğenildi" — hiçbiri yazılmaz; sıralamanın nasıl
hesaplandığı da yazılmaz. Onluk liste dolmuyorsa gönderi HİÇ üretilmez
(dokuz kutuluk bir "ilk 10" verinin azlığını ilan eder).

Çıktı: projeler/cikti/instagram/<yyyy>-h<hafta>/<n>-<slug>.png + .txt (açıklama)
Hafıza notu: derlenen her şey `projeler/cikti/` altına yazılır, köke değil.

------------------------------------------------------------------ VERİ
Veritabanı DIŞARI PORT AÇMIYOR (docker-compose.yml: db servisinde ports yok),
bu yüzden sorgular `ssh root@<sunucu> docker exec -i dizijpg-db psql` ile
gönderilir — projedeki diğer araçlarla (backend/araclar/dil_duzelt.js,
testci_isaretle.js) aynı desen. SQL stdin'den akar: iki kabuk arası tırnak
kaçırma derdi kalmaz. Çıktı JSON'dur (`json_agg`), böylece ayraç seçme
sorunu da yok — dizi adlarında '|' geçse bile bozulmaz.

KİMLER SAYILMAZ: `tohum` (bizim ürettiğimiz hesaplar — resmî dizi.jpg,
dizi.jpg.ai ve intl personalar) ve `yasakli` hesaplar. Gerekçe kullanicilar
tablosunun şemasındaki `tohum` notuyla aynı: kendi ürettiğimiz etkinlik
"topluluk ölçümü" diye yayınlanamaz.

NEDEN "KAÇ KİŞİ", "KAÇ BÖLÜM" DEĞİL: kullanıcılar geçmişlerini toplu
işaretliyor (ölçüldü: tek dakikada 177 bölüm = The Walking Dead'in tamamı).
Bölüm sayısı bu yüzden birkaç kişinin arşiv işaretlemesini "haftanın trendi"
gibi gösterir. TEKİL KİŞİ sayısı bu çarpıtmaya kapalı: arşivini işaretleyen
kişi listeye 1 katkı verir. Bölüm sayısı yalnız eşitlik bozucudur.

------------------------------------------------------- TELİF / ATIF (ZORUNLU)
1. Afişler ve kişi fotoğrafları TMDB'den gelir. TMDB ADI HİÇBİR YERDE GEÇMEZ
   (kullanıcı kararı, 7 Eyl 2026: önce görselden, sonra açıklama metninden
   kaldırıldı). Atıf cümlesini geri koymak gerekirse yeri açıklama metninin
   sonudur — görsel değil.
2. Afişler KÜÇÜK ÖLÇEKTE ve yapımı TANIMLAMAK için kullanılır; üzerlerindeki
   marka/dağıtımcı işaretleri kırpılmaz, filigran kaldırılmaz.
3. Stüdyo gönderisinde şirketin KENDİ LOGOSU kullanılır (TMDB `logo_path`) —
   şirketi TANIMLAMAK için, adını yazmakla aynı iş; onay/iş birliği ima eden
   hiçbir ifade yok, logo değiştirilmez/deforme edilmez (yalnız beyaz-saydam
   logolar açık kartta görünsün diye koyuya çevrilir). Buna karşılık YAYIN
   PLATFORMU logosu (Netflix, Disney+, ...) hiçbir görsele girmez: onlar
   listelenen taraf değil, sıralamayla ilgisi olmayan üçüncü markalar.
4. Font Poppins (SIL OFL 1.1) — ticari kullanım serbest, dosyalar
   app/assets/fonts/ altında, lisans app/assets/fonts/LISANSLAR/'da.
5. Şablon TAMAMEN bizim: TV Time / Letterboxd / IMDb'den hiçbir görsel,
   ikon, renk paleti veya yerleşim varlığı kopyalanmaz.

Kullanım:
    python3 araclar/haftalik_gonderi.py                    # geçen hafta, tüm hazır gönderiler
    python3 araclar/haftalik_gonderi.py --post diziler
    python3 araclar/haftalik_gonderi.py --hafta 2026-08-31 # o ISO haftası
    python3 araclar/haftalik_gonderi.py --kuru             # yalnız veri, görsel üretme
"""
import argparse
import datetime as dt
import hashlib
import json
import os
import re
import subprocess
import sys
import urllib.parse
import urllib.request

from PIL import Image, ImageDraw, ImageFilter, ImageFont

BURASI = os.path.dirname(os.path.abspath(__file__))
PROJE = os.path.dirname(BURASI)                      # .../projeler/dizijpg
ONBELLEK = os.path.expanduser("~/.cache/dizijpg-gonderi")

# ÇALIŞMA KOPYASI (macOS TCC): proje ~/Desktop altında ve launchd'den başlayan
# süreç Masaüstü'nü OKUYAMIYOR (ölçüldü 7 Eyl 2026: `desktop-oku:
# PermissionError [Errno 1] Operation not permitted`, aynı ajan
# ~/Library/Application Support'u okuyup ~/Pictures'a yazabiliyor). Tam Disk
# Erişimi vermek de çözmedi: /usr/bin/python3 bir kabuk, gerçek ikili
# Xcode.app içinde.
# Bu yüzden `--kur` betiği + fontları + logoyu + TMDB anahtarını korumasız
# alana kopyalar; zamanlanmış koşu ORADAN çalışır ve çıktıyı ~/Pictures'a yazar.
CALISMA = os.path.expanduser("~/Library/Application Support/dizijpg/gonderi")
CALISIYOR_KOPYADAN = os.path.abspath(BURASI) == os.path.abspath(CALISMA)

if CALISIYOR_KOPYADAN:
    FONT_DIZIN = os.path.join(CALISMA, "varliklar", "fonts")
    LOGO = os.path.join(CALISMA, "varliklar", "logo.png")
    CIKTI_KOK = os.path.expanduser("~/Pictures/dizi.jpg-gonderiler")
else:
    FONT_DIZIN = os.path.join(PROJE, "app", "assets", "fonts")
    LOGO = os.path.join(PROJE, "logo.png")
    CIKTI_KOK = os.path.join(os.path.dirname(PROJE), "cikti", "instagram")

SUNUCU = os.environ.get("DIZIJPG_SUNUCU", "root@154.53.163.3")
DB_KAP = os.environ.get("DIZIJPG_DB_KAP", "dizijpg-db")
DB_KUL = os.environ.get("DIZIJPG_DB_KUL", "dizijpg")
DB_AD = os.environ.get("DIZIJPG_DB_AD", "dizijpg")

# --- Marka (app/lib/tema.dart ile birebir) ---
SARI = (245, 197, 24)          # DiziRenkler.sari  #F5C518
ACIK_SARI = (255, 215, 94)     # DiziRenkler.acikSari
ZEMIN = (11, 11, 13)           # DiziRenkler.markaKoyu / koyu tema zemini
KART = (31, 31, 35)            # DiziRenkler.kart (koyu)
IKINCIL = (23, 23, 26)         # DiziRenkler.koyuGri (koyu)
BEYAZ = (255, 255, 255)
GRI = (158, 158, 163)          # DiziRenkler.ikincilMetin (koyu)
KOYU_GRI = (58, 58, 64)

SITE = "dizijpg.com"

AYLAR = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz",
         "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]

# ---------------------------------------------------------------- yardımcılar

R = {"sif": "\x1b[0m", "sar": "\x1b[33m", "yes": "\x1b[32m", "gri": "\x1b[90m",
     "kir": "\x1b[31m"}
bilgi = lambda m: print(f"{R['gri']}·{R['sif']} {m}")
tamam = lambda m: print(f"{R['yes']}✓{R['sif']} {m}")
uyari = lambda m: print(f"{R['sar']}!{R['sif']} {m}")
hata = lambda m: print(f"{R['kir']}✗{R['sif']} {m}", file=sys.stderr)


AYAR_DOSYA = "gonderi_ayar.json"
_AYAR = None


def ayar():
    """Elle ayar dosyası (araclar/gonderi_ayar.json): kara liste, şirket adı ve
    logo ezmeleri. Kullanıcının doğrudan düzenlediği yer."""
    global _AYAR
    if _AYAR is None:
        yol = os.path.join(CALISMA if CALISIYOR_KOPYADAN else BURASI, AYAR_DOSYA)
        try:
            with open(yol, encoding="utf-8") as f:
                _AYAR = json.load(f)
        except FileNotFoundError:
            _AYAR = {}
    return _AYAR


def haric(tur):
    return set((ayar().get("haric") or {}).get(tur) or [])


def font(ad, boyut):
    return ImageFont.truetype(os.path.join(FONT_DIZIN, f"Poppins-{ad}.ttf"), boyut)


def gen(draw, metin, f):
    return draw.textlength(metin, font=f)


def kirp(draw, metin, f, azami):
    """Sığmayan metni üç noktayla kısaltır."""
    if gen(draw, metin, f) <= azami:
        return metin
    while metin and gen(draw, metin + "…", f) > azami:
        metin = metin[:-1]
    return metin.rstrip() + "…"


def sar(draw, metin, f, azami, satir_sayisi):
    """Piksel genişliğine göre kelime sarma; son satır taşarsa kırpılır."""
    kelimeler = metin.split()
    satirlar, aktif = [], ""
    for k in kelimeler:
        deneme = (aktif + " " + k).strip()
        if gen(draw, deneme, f) <= azami or not aktif:
            aktif = deneme
        else:
            satirlar.append(aktif)
            aktif = k
        if len(satirlar) == satir_sayisi:
            break
    if aktif and len(satirlar) < satir_sayisi:
        satirlar.append(aktif)
    if len(satirlar) == satir_sayisi:
        # sarma sırasında kelime arttıysa son satırı kırp
        kalan = metin
        for s in satirlar[:-1]:
            kalan = kalan[len(s):].strip()
        satirlar[-1] = kirp(draw, kalan, f, azami)
    return satirlar


def yuvarlak(im, yaricap):
    """Görselin köşelerini yuvarlar (alfa maskesiyle)."""
    maske = Image.new("L", im.size, 0)
    ImageDraw.Draw(maske).rounded_rectangle([0, 0, im.size[0] - 1, im.size[1] - 1],
                                            yaricap, fill=255)
    im = im.convert("RGBA")
    im.putalpha(maske)
    return im


# ------------------------------------------------------------------ veritabanı

def sorgu(sql):
    """SQL'i sunucudaki psql'e stdin'den verir, JSON dizi döner."""
    komut = ["ssh", "-o", "BatchMode=yes", SUNUCU,
             f"docker exec -i {DB_KAP} psql -U {DB_KUL} -d {DB_AD} -tA"]
    s = subprocess.run(komut, input=sql.encode(), capture_output=True)
    if s.returncode != 0:
        raise RuntimeError(f"psql hatası: {s.stderr.decode()[:400]}")
    cikti = s.stdout.decode().strip()
    if not cikti or cikti == "":
        return []
    return json.loads(cikti) or []


# ------------------------------------------------------------------------ TMDB

def tmdb_token():
    t = os.environ.get("TMDB_TOKEN")
    if t:
        return t
    yol = (os.path.join(CALISMA, "tmdb.token") if CALISIYOR_KOPYADAN
           else os.path.join(PROJE, "backend", ".env"))
    if CALISIYOR_KOPYADAN:
        with open(yol, encoding="utf-8") as f:
            return f.read().strip()
    with open(yol, encoding="utf-8") as f:
        for satir in f:
            if satir.startswith("TMDB_TOKEN="):
                return satir.split("=", 1)[1].strip()
    raise RuntimeError("TMDB_TOKEN yok (backend/.env ya da ortam değişkeni)")


_TOKEN = None


def tmdb(yol, **parametre):
    """TMDB v3 çağrısı (v4 bearer ile). Yanıtlar diske önbelleklenir —
    aynı hafta betiği tekrar çalıştırmak TMDB kotasını yemez."""
    global _TOKEN
    if _TOKEN is None:
        _TOKEN = tmdb_token()
    p = "&".join(f"{k}={v}" for k, v in parametre.items())
    url = f"https://api.themoviedb.org/3{yol}" + (f"?{p}" if p else "")
    anahtar = hashlib.md5(url.encode()).hexdigest()
    dosya = os.path.join(ONBELLEK, "tmdb", anahtar + ".json")
    os.makedirs(os.path.dirname(dosya), exist_ok=True)
    if os.path.exists(dosya) and (dt.datetime.now().timestamp() -
                                  os.path.getmtime(dosya)) < 7 * 86400:
        with open(dosya, encoding="utf-8") as f:
            return json.load(f)
    istek = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {_TOKEN}", "Accept": "application/json"})
    with urllib.request.urlopen(istek, timeout=20) as y:
        veri = json.loads(y.read().decode())
    with open(dosya, "w", encoding="utf-8") as f:
        json.dump(veri, f, ensure_ascii=False)
    return veri


WIKI_UA = {"User-Agent": "dizijpg-gonderi/1.0 (https://dizijpg.com)"}
# Sadeleştirmede atılan jenerik kelimeler: ad eşleşmesi "warner" gibi ÖZ ada
# baksın, "pictures/studios" gibi herkeste olan eklere değil.
JENERIK = {"pictures", "picture", "studios", "studio", "television", "tv",
           "entertainment", "productions", "production", "company", "films",
           "film", "media", "group", "inc", "llc", "ltd", "the", "co"}


def _sade(ad):
    parcalar = re.sub(r"[^a-z0-9 ]", " ", ad.lower()).split()
    return [p for p in parcalar if p not in JENERIK]


def wikidata_logo(ad):
    """Şirketin GÜNCEL resmî logosu (Wikidata P154 → Wikimedia Commons).

    NEDEN TMDB YETMİYOR: TMDB şirket başına TEK logo tutar ve çoğu, yıllar önce
    yüklenmiş siyah/eski sürümdür (7 Eyl 2026: kullanıcı "neden bazıları renkli
    bazıları siyah?" diye sordu — ölçüldü, Warner/Paramount/20th Century
    TMDB'de eski markayla duruyordu). Wikidata güncel logoyu işaret eder,
    Commons da SVG'yi `Special:FilePath?width=` ile PNG'ye çevirir.

    YANLIŞ EŞLEŞME KAPISI: aday varlığın etiketi ile şirket adının ÖZ
    kelimeleri kesişmiyorsa kabul edilmez (aksi hâlde "Syncopy" araması
    alakasız bir varlığın logosunu getirebilirdi)."""
    onbellek = os.path.join(ONBELLEK, "wikidata.json")
    try:
        with open(onbellek, encoding="utf-8") as f:
            kayit = json.load(f)
    except (FileNotFoundError, ValueError):
        kayit = {}
    if ad in kayit:
        return kayit[ad]

    def cek(url):
        with urllib.request.urlopen(
                urllib.request.Request(url, headers=WIKI_UA), timeout=20) as y:
            return json.loads(y.read().decode())

    sonuc = None
    try:
        q = urllib.parse.quote(ad)
        arama = cek("https://www.wikidata.org/w/api.php?action=wbsearchentities"
                    f"&search={q}&language=en&format=json&type=item&limit=4")
        cekirdek = set(_sade(ad))
        for aday in arama.get("search", []):
            if cekirdek and not (cekirdek & set(_sade(aday.get("label") or ""))):
                continue
            iddia = cek("https://www.wikidata.org/w/api.php?action=wbgetclaims"
                        f"&entity={aday['id']}&property=P154&format=json")
            p154 = (iddia.get("claims") or {}).get("P154")
            if not p154:
                continue
            dosya = p154[0]["mainsnak"]["datavalue"]["value"]
            sonuc = ("https://commons.wikimedia.org/wiki/Special:FilePath/"
                     + urllib.parse.quote(dosya) + "?width=600")
            break
    except Exception as e:                      # ağ/kota hatası sessizce TMDB'ye düşer
        uyari(f"wikidata ({ad}): {e}")
        return None

    kayit[ad] = sonuc
    os.makedirs(ONBELLEK, exist_ok=True)
    with open(onbellek, "w", encoding="utf-8") as f:
        json.dump(kayit, f, ensure_ascii=False)
    return sonuc


def url_indir(url):
    """Herhangi bir adresten görsel (diske önbellekli, saydamlık korunur)."""
    dosya = os.path.join(ONBELLEK, "gorsel",
                         hashlib.md5(url.encode()).hexdigest() + ".png")
    os.makedirs(os.path.dirname(dosya), exist_ok=True)
    if not os.path.exists(dosya):
        with urllib.request.urlopen(
                urllib.request.Request(url, headers=WIKI_UA), timeout=30) as y, \
                open(dosya, "wb") as f:
            f.write(y.read())
    return Image.open(dosya).convert("RGBA")


def gorsel_indir(yol, boyut="w342", alfa=False):
    """TMDB görselini indirir (diske önbellekli), PIL Image döner."""
    if not yol:
        return None
    dosya = os.path.join(ONBELLEK, "gorsel", boyut + yol.replace("/", "_"))
    os.makedirs(os.path.dirname(dosya), exist_ok=True)
    if not os.path.exists(dosya):
        url = f"https://image.tmdb.org/t/p/{boyut}{yol}"
        istek = urllib.request.Request(url, headers={"User-Agent": "dizijpg-gonderi/1.0"})
        with urllib.request.urlopen(istek, timeout=30) as y, open(dosya, "wb") as f:
            f.write(y.read())
    return Image.open(dosya).convert("RGBA" if alfa else "RGB")


# ------------------------------------------------------------------- hafta

def hafta_araligi(baslangic=None):
    """(baslangic_tarih, bitis_tarih) — ISO hafta, Pzt..Paz (dahil).
    Varsayılan: BUGÜNDEN ÖNCEKİ tamamlanmış hafta."""
    if baslangic:
        b = dt.date.fromisoformat(baslangic)
        b = b - dt.timedelta(days=b.weekday())
    else:
        bugun = dt.date.today()
        b = bugun - dt.timedelta(days=bugun.weekday() + 7)
    return b, b + dt.timedelta(days=6)


# VERİ PENCERESİ (kullanıcı kararı, 7 Eyl 2026): sayım SON 30 GÜNE bakar,
# görselde ise o haftanın tarih aralığı yazar. Gerekçe kullanıcının: liste her
# hafta dolu ve güçlü görünsün, topluluğun küçüklüğü gönderiden okunmasın.
# Tek haftalık pencere bazı listelerde 10'u zor dolduruyordu.
VERI_GUN = 30


def pencere(b, s):
    """SQL'e giren tarih aralığı — bitiş haftanın sonu, başlangıç 30 gün öncesi."""
    bitis = s + dt.timedelta(days=1)
    return dict(b=(bitis - dt.timedelta(days=VERI_GUN)).isoformat(),
                s=bitis.isoformat())


def tarih_metni(b, s):
    if b.month == s.month:
        return f"{b.day}–{s.day} {AYLAR[s.month - 1]} {s.year}"
    return f"{b.day} {AYLAR[b.month - 1]} – {s.day} {AYLAR[s.month - 1]} {s.year}"


def hafta_klasoru(b):
    yil, hafta, _ = b.isocalendar()
    return f"{yil}-h{hafta:02d}"


# ------------------------------------------------------------- ortak çerçeve

G, Y = 1080, 1350           # Instagram dikey (4:5) — akışta en çok yer kaplayan oran
KENAR = 64


def tuval():
    im = Image.new("RGB", (G, Y), ZEMIN)
    d = ImageDraw.Draw(im)
    # Üst kenarda ince marka şeridi + sağ üstte yumuşak sarı ışıma:
    # düz siyah kare akışta "boş" görünüyor, şerit gönderiyi markaya bağlıyor.
    # Işıma AĞIR BULANIKLAŞTIRILIR: keskin kenarlı elips "yanlışlıkla çizilmiş
    # daire" gibi duruyordu (ilk denemede görüldü), bulanık hâli ışık okunuyor.
    isik = Image.new("L", (G, Y), 0)
    ImageDraw.Draw(isik).ellipse([G - 470, -300, G + 190, 360], fill=255)
    isik = isik.filter(ImageFilter.GaussianBlur(160))
    im = Image.composite(Image.new("RGB", (G, Y), (46, 39, 12)), im, isik)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, G, 6], fill=SARI)
    return im, d


def logo_yaz(im, x, y, yukseklik=74):
    """GERÇEK marka logosu (DİZİ|JPG) — uygulama ikonuyla birebir aynı dosya.

    Tipografiyle 'dizi.jpg' yazmak YOK (kullanıcı kararı, 7 Eyl 2026): marka
    bu logodur. Dosya saydam PNG; kenarındaki boş alan kırpılıp (alfa sınır
    kutusu) istenen yüksekliğe indirilir, böylece hizalama logonun GERÇEK
    kenarına göre olur, tuvalin ortasına göre değil.
    Koyu zemin şart — logonun 'DİZİ' harfleri açık gri + ince siyah kontur,
    açık zeminde eriyor (tema.dart: markaKoyu notu)."""
    l = Image.open(LOGO).convert("RGBA")
    l = l.crop(l.split()[-1].getbbox())
    genislik = round(l.width * yukseklik / l.height)
    l = l.resize((genislik, yukseklik), Image.LANCZOS)
    im.paste(l, (x, y), l)
    return genislik


def baslik_bloku(im, d, ust_metin, satir1, satir2, alt_metin):
    """Ortak başlık: kelime işareti + tarih rozeti + iki satır başlık + alt not."""
    logo_yaz(im, KENAR, 46)
    # tarih rozeti (sağ üst)
    f_rozet = font("SemiBold", 24)
    tw = gen(d, ust_metin, f_rozet)
    x0 = G - KENAR - tw - 40
    d.rounded_rectangle([x0, 56, G - KENAR, 108], 26, fill=IKINCIL,
                        outline=KOYU_GRI, width=2)
    d.text((x0 + 20, 68), ust_metin, font=f_rozet, fill=GRI)

    f_bas = font("Bold", 62)
    d.text((KENAR, 156), satir1, font=f_bas, fill=BEYAZ)
    d.text((KENAR, 156 + 74), satir2, font=f_bas, fill=SARI)

    f_alt = font("Medium", 25)
    d.text((KENAR, 156 + 74 + 88), alt_metin, font=f_alt, fill=GRI)


def alt_bilgi(d):
    # GÖRSELDE ATIF YOK (kullanıcı kararı, 7 Eyl 2026): TMDB cümlesi yalnız
    # açıklama metninde (`ATIF_METIN`) geçiyor — gönderiyle birlikte yayımlanan
    # metin de atfın geçerli yeridir. Buraya geri koyulacaksa alt satıra
    # "Afişler: TMDB" yazılır (veri bizim, o kelime metne GİRMEZ).
    fs = font("SemiBold", 24)
    d.text((G - KENAR - gen(d, SITE, fs), Y - 86), SITE, font=fs, fill=SARI)


# ---------------------------------------------------------- ORTAK: 10'lu ızgara
#
# BEŞ GÖNDERİ DE ONLUK LİSTEDİR (kullanıcı kararı, 7 Eyl 2026) — tek kazananlı
# düzen kaldırıldı. Yerleşim hepsinde aynı: 5 sütun × 2 satır, sıra rozeti
# afişin sol üstünde, ad afişin altında.
#
# GÖRSELDE HİÇBİR SAYI YOK (kullanıcı kararı): kişi sayısı, oy sayısı, puan,
# "N yapımı beğenildi" gibi ifadeler yazılmaz — ne görselde ne açıklamada.
# Sıralamanın nasıl hesaplandığı da yazılmaz.

IZGARA_SUTUN = 5
AFIS_G, AFIS_Y = 176, 264
IZGARA_UST = 470


def kutu_ciz(im, d, gorsel, x, y, w, h, yaricap=14):
    """Görseli kutuya KIRPARAK (cover) yerleştirir; oran bozulmaz."""
    if gorsel is not None:
        oran = max(w / gorsel.width, h / gorsel.height)
        yeni = gorsel.resize((round(gorsel.width * oran), round(gorsel.height * oran)),
                             Image.LANCZOS)
        sol, ust = (yeni.width - w) // 2, (yeni.height - h) // 2
        gorsel = yeni.crop((sol, ust, sol + w, ust + h))
    else:
        gorsel = Image.new("RGB", (w, h), KART)
    gorsel = yuvarlak(gorsel, yaricap)
    im.paste(gorsel, (x, y), gorsel)
    d.rounded_rectangle([x, y, x + w - 1, y + h - 1], yaricap,
                        outline=(46, 46, 52), width=2)


def logo_kutusu(im, d, logo, x, y, w, h, yaricap=14):
    """Şirket logosunu kutuya ortalar.

    KART RENGİ HEP AYNI (açık): on kutunun bir kısmı koyu bir kısmı açık olunca
    ızgara dağınık duruyordu (ilk deneme). TMDB logolarının bir kısmı
    BEYAZ-SAYDAM olduğu için açık kartta kaybolurdu; bu logolar (parlak ve
    renksiz olanlar) tersine çevrilip koyu çizilir — biçim korunur, renkli
    logolar (Marvel'ın kırmızısı, WB'nin altını) olduğu gibi kalır."""
    if logo is None:
        return
    kucuk = logo.resize((64, 64))
    piksel = list(kucuk.getdata())
    agirlik = sum(p[3] for p in piksel) or 1
    parlaklik = sum((0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]) * p[3]
                    for p in piksel) / agirlik
    doygunluk = sum((max(p[:3]) - min(p[:3])) * p[3] for p in piksel) / agirlik
    if parlaklik > 175 and doygunluk < 45:
        r, g, bl, a = logo.split()
        logo = Image.merge("RGBA", (r.point(lambda v: 40), g.point(lambda v: 40),
                                    bl.point(lambda v: 44), a))

    kart = Image.new("RGBA", (w, h), (242, 242, 245, 255))
    en_g, en_y = int(w * 0.82), int(h * 0.56)
    oran = min(en_g / logo.width, en_y / logo.height)
    logo = logo.resize((max(1, round(logo.width * oran)),
                        max(1, round(logo.height * oran))), Image.LANCZOS)
    kart.alpha_composite(logo, ((w - logo.width) // 2, (h - logo.height) // 2))
    kart = yuvarlak(kart, yaricap)
    im.paste(kart, (x, y), kart)
    d.rounded_rectangle([x, y, x + w - 1, y + h - 1], yaricap,
                        outline=(46, 46, 52), width=2)


def ciz_izgara(b, s, satir1, satir2, alt_metin, ogeler):
    """Onluk ızgara gönderisi. `ogeler`: [{ad, afis}] — afis TMDB yolu."""
    im, d = tuval()
    baslik_bloku(im, d, tarih_metni(b, s).upper(), satir1, satir2, alt_metin)

    bosluk = (G - 2 * KENAR - IZGARA_SUTUN * AFIS_G) // (IZGARA_SUTUN - 1)
    hucre_y = AFIS_Y + 12 + 2 * 25
    f_ad = font("SemiBold", 19)

    for i, oge in enumerate(ogeler[:10]):
        sx = KENAR + (i % IZGARA_SUTUN) * (AFIS_G + bosluk)
        sy = IZGARA_UST + (i // IZGARA_SUTUN) * (hucre_y + 60)
        if oge.get("logo") is not None:
            logo_kutusu(im, d, oge["logo"], sx, sy, AFIS_G, AFIS_Y)
        else:
            kutu_ciz(im, d, gorsel_indir(oge["afis"], "w342"), sx, sy, AFIS_G, AFIS_Y)

        # sıra rozeti — sarı üstüne DAİMA siyah (tema kuralı)
        r = 52 if i == 0 else 46
        d.rounded_rectangle([sx, sy, sx + r, sy + r], 14, fill=SARI)
        d.rectangle([sx, sy + r - 14, sx + 14, sy + r], fill=SARI)
        d.rectangle([sx + r - 14, sy, sx + r, sy + 14], fill=SARI)
        d.text((sx + r / 2, sy + r / 2 - 1), str(i + 1),
               font=font("Bold", 30 if i == 0 else 26), fill=ZEMIN, anchor="mm")

        ty = sy + AFIS_Y + 12
        for satir in sar(d, oge["ad"], f_ad, AFIS_G, 2):
            d.text((sx, ty), satir, font=f_ad, fill=BEYAZ)
            ty += 25

    alt_bilgi(d)
    return im


def izgara_metni(baslik, ogeler, b, s, kapanis, etiketler):
    """Instagram açıklaması. SAYI YOK: yalnız sıra ve ad."""
    return "\n".join([
        f"{baslik} — {tarih_metni(b, s)}",
        "",
        *[f"{i + 1}. {o['ad']}" for i, o in enumerate(ogeler[:10])],
        "",
        f"{kapanis} {SITE}",
        "",
        etiketler,
    ])


# ------------------------------------------------- ORTAK: haftalık beğeni skoru
#
# NEDEN KARMA SKOR: kişi ve şirket profillerine DOĞRUDAN verilen puan/favori
# tek başına haftalık bir onluk liste doldurmaya yetmiyor. Skor üç kaynaktan
# gelir ve hepsi AYNI HAFTANIN içinde kalır:
#   1) Doğrudan beğeni — kişi/şirket profiline favori (5) veya puan (puan/100×4).
#   2) Beğenilen yapımların künyesi — o hafta favorilenen (1) ya da 60+ puan
#      alan (puan/100) dizi/filmlerin başrolleri (ilk 3 ×1, 4-5. ×0,6),
#      yönetmeni (film ×1,2 / dizi ×0,5) ve yapım şirketi (ilk iki ×1, ×0,5).
#   3) İzlenen yapımların künyesi — hafta boyunca bölüm/film işaretlenen
#      yapımlar, izleyen tekil kişi başına 0,2 ağırlıkla. Beğeniden HAFİF
#      kalır ama listeyi her hafta dolu tutan asıl kaynak budur.
# Dizi yönetmeni film yönetmeninden az ağırlık taşır: dizide yönetmen bölüm
# başına değişir. Eşit verildiğinde (ilk deneme) listenin başına kimsenin
# tanımadığı bölüm yönetmenleri çıktı.

SQL_YAPIM_SINYAL = """
SELECT coalesce(json_agg(t), '[]') FROM (
  SELECT tur, tmdb_id, sum(agirlik)::float8 AS skor
  FROM (
    SELECT p.tur, p.tmdb_id, (p.puan::numeric / 100) AS agirlik
      FROM puanlar p
      JOIN kullanicilar k ON k.id = p.kullanici_id
                         AND NOT k.tohum AND NOT k.yasakli
     WHERE p.tur IN ('tv', 'movie') AND p.sezon IS NULL AND p.puan >= 60
       AND p.tarih >= timestamptz '{b} 00:00:00+03'
       AND p.tarih <  timestamptz '{s} 00:00:00+03'
    UNION ALL
    SELECT f.tur, f.tmdb_id, 1.0
      FROM favoriler f
      JOIN kullanicilar k ON k.id = f.kullanici_id
                         AND NOT k.tohum AND NOT k.yasakli
     WHERE f.tur IN ('tv', 'movie')
       AND f.tarih >= timestamptz '{b} 00:00:00+03'
       AND f.tarih <  timestamptz '{s} 00:00:00+03'
    UNION ALL
    SELECT i.tur, i.tmdb_id, 0.2
      FROM (SELECT DISTINCT tur, tmdb_id, kullanici_id FROM izlemeler
             WHERE tarih >= timestamptz '{b} 00:00:00+03'
               AND tarih <  timestamptz '{s} 00:00:00+03') i
      JOIN kullanicilar k ON k.id = i.kullanici_id
                         AND NOT k.tohum AND NOT k.yasakli
  ) x
  GROUP BY tur, tmdb_id
  ORDER BY skor DESC
  LIMIT {limit}
) t;
"""

SQL_ACIK_KISI = """
SELECT coalesce(json_agg(t), '[]') FROM (
  SELECT tmdb_id, sum(agirlik)::float8 AS skor
  FROM (
    SELECT p.tmdb_id, (p.puan::numeric / 100) * 4 AS agirlik
      FROM puanlar p
      JOIN kullanicilar k ON k.id = p.kullanici_id
                         AND NOT k.tohum AND NOT k.yasakli
     WHERE p.tur = 'person' AND p.puan >= 60
       AND p.tarih >= timestamptz '{b} 00:00:00+03'
       AND p.tarih <  timestamptz '{s} 00:00:00+03'
    UNION ALL
    SELECT f.tmdb_id, 5.0
      FROM favoriler f
      JOIN kullanicilar k ON k.id = f.kullanici_id
                         AND NOT k.tohum AND NOT k.yasakli
     WHERE f.tur = 'person'
       AND f.tarih >= timestamptz '{b} 00:00:00+03'
       AND f.tarih <  timestamptz '{s} 00:00:00+03'
  ) x GROUP BY tmdb_id
) t;
"""

SQL_ACIK_SIRKET = """
SELECT coalesce(json_agg(t), '[]') FROM (
  SELECT p.tmdb_id, (sum(p.puan::numeric / 100) * 4)::float8 AS skor
    FROM puanlar p
    JOIN kullanicilar k ON k.id = p.kullanici_id
                       AND NOT k.tohum AND NOT k.yasakli
   WHERE p.tur = 'company' AND p.puan >= 60
     AND p.tarih >= timestamptz '{b} 00:00:00+03'
     AND p.tarih <  timestamptz '{s} 00:00:00+03'
   GROUP BY p.tmdb_id
) t;
"""

KUNYE_LIMIT = 40          # künyesi çekilecek yapım sayısı (TMDB çağrısı = 2×bu)
_HAVUZ = {}               # (b, s) -> (oyuncu, yonetmen, sirket); üç gönderi paylaşır


def _ekle(havuz, anahtar, skor, yapim=None):
    h = havuz.setdefault(anahtar, {"skor": 0.0, "isler": []})
    h["skor"] += skor
    if yapim:
        h["isler"].append((skor, yapim))


def havuzlar(b, s):
    """(oyuncu, yonetmen, sirket) skor havuzları — TMDB künyeleriyle birlikte."""
    anahtar = (b, s)
    if anahtar in _HAVUZ:
        return _HAVUZ[anahtar]
    ara = pencere(b, s)
    sinyal = sorgu(SQL_YAPIM_SINYAL.format(limit=KUNYE_LIMIT, **ara))
    oyuncu, yonetmen, sirket = {}, {}, {}

    for y in sinyal:
        det = tmdb(f"/{y['tur']}/{y['tmdb_id']}", language="tr-TR")
        yapim = {"tur": y["tur"], "tmdb_id": y["tmdb_id"],
                 "ad": det.get("title") or det.get("name") or f"#{y['tmdb_id']}",
                 "afis": det.get("poster_path")}
        if y["tur"] == "movie":
            kunye = tmdb(f"/movie/{y['tmdb_id']}/credits", language="tr-TR")
            kadro = kunye.get("cast", [])
            yonetenler = [c for c in kunye.get("crew", []) if c.get("job") == "Director"]
        else:
            # Dizide tek "yönetmen" yoktur; aggregate_credits bölüm sayısını
            # verir, en çok bölüm yöneten isim alınır. Yaratıcıyı (created_by)
            # yönetmen diye YAZMIYORUZ — farklı iş, yanlış olur.
            kunye = tmdb(f"/tv/{y['tmdb_id']}/aggregate_credits", language="tr-TR")
            kadro = kunye.get("cast", [])
            yonetenler = [c for c in kunye.get("crew", [])
                          if any(j.get("job") == "Director" for j in c.get("jobs", []))]
            yonetenler.sort(key=lambda c: -(c.get("total_episode_count") or 0))
        for c in kadro[:5]:
            _ekle(oyuncu, c["id"],
                  y["skor"] * (1.0 if (c.get("order") or 9) < 3 else 0.6), yapim)
        for c in yonetenler[:2]:
            _ekle(yonetmen, c["id"],
                  y["skor"] * (1.2 if y["tur"] == "movie" else 0.5), yapim)
        for i, sk in enumerate(det.get("production_companies", [])[:4]):
            _ekle(sirket, sk["id"], y["skor"] * (1.0 if i < 2 else 0.5), yapim)

    for r in sorgu(SQL_ACIK_KISI.format(**ara)):
        kisi = tmdb(f"/person/{r['tmdb_id']}", language="tr-TR")
        hedef = yonetmen if kisi.get("known_for_department") == "Directing" else oyuncu
        _ekle(hedef, r["tmdb_id"], r["skor"])
    for r in sorgu(SQL_ACIK_SIRKET.format(**ara)):
        _ekle(sirket, r["tmdb_id"], r["skor"])

    _HAVUZ[anahtar] = (oyuncu, yonetmen, sirket)
    return _HAVUZ[anahtar]


def kisi_listesi(havuz, bolum, adet=10):
    """Skora göre sıralı kişiler. FOTOĞRAFSIZ kişi ATLANIR: ızgarada boş kutu
    olarak görünürdü."""
    yasak = haric("person")
    cikti = []
    for kimlik, kayit in sorted(havuz.items(), key=lambda p: -p[1]["skor"]):
        if kimlik in yasak:
            continue
        kisi = tmdb(f"/person/{kimlik}", language="tr-TR")
        if not kisi.get("profile_path"):
            continue
        if bolum and kisi.get("known_for_department") not in bolum:
            continue
        cikti.append({"tmdb_id": kimlik, "ad": kisi.get("name") or "",
                      "afis": kisi["profile_path"]})
        if len(cikti) == adet:
            break
    return cikti


def sirket_listesi(havuz, adet=10):
    """Şirketler; kutuda ŞİRKETİN KENDİ LOGOSU (TMDB `logo_path`).

    Logo, şirketi TANIMLAMAK için kullanılıyor — bir markanın adını yazmakla
    aynı iş; onay/iş birliği ima eden hiçbir ifade yok. Logosu olmayan şirket
    LİSTEYE ALINMAZ: kutuların yarısı logo yarısı afiş olunca ızgara dağılıyor
    (7 Eyl 2026, ilk deneme afişliydi ve aynı afiş iki kutuda çıkıyordu)."""
    yasak = haric("company")
    cikti, kullanilan = [], set()
    for kimlik, kayit in sorted(havuz.items(), key=lambda p: -p[1]["skor"]):
        if kimlik in yasak:
            continue
        # Aynı afiş iki kutuda görünmesin (ilk denemede Marvel Studios ile
        # Columbia Pictures aynı Örümcek-Adam afişini taşıyordu): şirketin
        # BAŞKA bir yapımı varsa o seçilir.
        afisler = [y["afis"] for _, y in sorted(kayit["isler"], key=lambda p: -p[0])
                   if y["afis"]]
        afis = next((a for a in afisler if a not in kullanilan),
                    afisler[0] if afisler else None)
        if not afis:
            continue
        kullanilan.add(afis)
        det = tmdb(f"/company/{kimlik}")
        ad = (ayar().get("sirket_ad") or {}).get(str(kimlik)) or det.get("name")
        if not ad:
            continue
        # Logo kaynağı sırası: elle ezme → Wikidata (güncel resmî) → TMDB (eski).
        elle = (ayar().get("sirket_logo") or {}).get(str(kimlik))
        adres = elle or wikidata_logo(det.get("name") or ad)
        try:
            logo = url_indir(adres) if adres else None
        except Exception as e:
            uyari(f"logo inilemedi ({ad}): {e}")
            logo = None
        if logo is None and det.get("logo_path"):
            logo = gorsel_indir(det["logo_path"], "w500", alfa=True)
        if logo is None:
            continue
        cikti.append({"tmdb_id": kimlik, "ad": ad, "afis": afis, "logo": logo})
        if len(cikti) == adet:
            break
    return cikti


# ------------------------------------------------------- 1) EN ÇOK İZLENEN DİZİ

SQL_DIZILER = """
SELECT coalesce(json_agg(t), '[]') FROM (
  SELECT i.tmdb_id,
         count(DISTINCT i.kullanici_id) AS kisi,
         count(*)                       AS bolum
  FROM izlemeler i
  JOIN kullanicilar k ON k.id = i.kullanici_id
                     AND NOT k.tohum AND NOT k.yasakli
  WHERE i.tur = 'tv'
    AND i.tarih >= timestamptz '{b} 00:00:00+03'
    AND i.tarih <  timestamptz '{s} 00:00:00+03'
  GROUP BY i.tmdb_id
  ORDER BY kisi DESC, bolum DESC
  LIMIT 14
) t;
"""


def veri_diziler(b, s):
    # SIRALAMA TEKİL KİŞİYE GÖRE, bölüm sayısına göre DEĞİL: kullanıcılar
    # arşivlerini toplu işaretliyor (ölçüm 7 Eyl 2026: tek dakikada 177 bölüm,
    # The Walking Dead'in tamamı). Bölüm sayısı sıralasaydı haftanın listesi
    # birkaç kişinin geçmiş dökümü olurdu. Bölüm sayısı yalnız eşitlik bozucu.
    satirlar = sorgu(SQL_DIZILER.format(**pencere(b, s)))
    yasak = haric("tv")
    cikti = []
    for r in satirlar:
        if r["tmdb_id"] in yasak:
            continue
        v = tmdb(f"/tv/{r['tmdb_id']}", language="tr-TR")
        afis = v.get("poster_path") or tmdb(f"/tv/{r['tmdb_id']}",
                                            language="en-US").get("poster_path")
        cikti.append({"tmdb_id": r["tmdb_id"], "afis": afis,
                      "ad": v.get("name") or v.get("original_name") or ""})
        if len(cikti) == 10:
            break
    return cikti


def ciz_diziler(veri, b, s):
    return ciz_izgara(b, s, "Haftanın en çok", "izlenen 10 dizisi",
                      "dizi.jpg kullanıcılarının bu hafta izlediği diziler", veri)


def metin_diziler(veri, b, s):
    return izgara_metni("Haftanın en çok izlenen 10 dizisi", veri, b, s,
                        "Sen bu hafta ne izledin? Bölümlerini işaretle:",
                        "#dizijpg #dizi #dizitakip #diziler #haftanindizileri "
                        "#dizionerisi #dizisever #diziizle #dizitavsiyesi #tvshows")


# --------------------------------------------------------- 2) EN BEĞENİLEN OYUNCU

def veri_oyuncu(b, s):
    oyuncu, _, _ = havuzlar(b, s)
    return kisi_listesi(oyuncu, {"Acting"})


def ciz_oyuncu(veri, b, s):
    return ciz_izgara(b, s, "Haftanın en beğenilen", "10 oyuncusu",
                      "dizi.jpg kullanıcılarının bu hafta öne çıkardığı isimler",
                      veri)


def metin_oyuncu(veri, b, s):
    return izgara_metni("Haftanın en beğenilen 10 oyuncusu", veri, b, s,
                        "Senin bu haftaki favorin kim? Beğenini bırak:",
                        "#dizijpg #oyuncu #haftaninoyunculari #dizi #film "
                        "#sinema #dizitakip #dizisever #oyunculuk #tvshows")


# ------------------------------------------------------------ 3) EN BEĞENİLEN FİLM

SQL_FILM = """
WITH oy AS (
  SELECT p.tmdb_id,
         count(DISTINCT p.kullanici_id) AS kisi,
         avg(p.puan)                    AS ort
    FROM puanlar p
    JOIN kullanicilar k ON k.id = p.kullanici_id
                       AND NOT k.tohum AND NOT k.yasakli
   WHERE p.tur = 'movie'
     AND p.tarih >= timestamptz '{b} 00:00:00+03'
     AND p.tarih <  timestamptz '{s} 00:00:00+03'
   GROUP BY p.tmdb_id
), genel AS (SELECT avg(ort) AS o FROM oy)
SELECT coalesce(json_agg(t), '[]') FROM (
  SELECT oy.tmdb_id,
         ((oy.kisi * oy.ort + {m} * genel.o) / (oy.kisi + {m}))::float8 AS bayes
    FROM oy, genel
   ORDER BY bayes DESC, oy.kisi DESC
   LIMIT 30
) t;
"""


def veri_film(b, s, m=2):
    # BAYES ORTALAMASI: tek kişinin verdiği 100, üç kişinin verdiği 93'ü
    # geçmesin diye. Ölçüm (7 Eyl 2026): bir kullanıcı tek haftada 778 filme
    # puan verdi (Letterboxd aktarımı) — ham ortalama o hesabın listesi olurdu.
    satirlar = sorgu(SQL_FILM.format(m=m, **pencere(b, s)))
    yasak = haric("movie")
    cikti = []
    for r in satirlar:
        if r["tmdb_id"] in yasak:
            continue
        det = tmdb(f"/movie/{r['tmdb_id']}", language="tr-TR")
        if not det.get("poster_path"):
            continue
        cikti.append({"tmdb_id": r["tmdb_id"], "afis": det["poster_path"],
                      "ad": det.get("title") or det.get("original_title") or ""})
        if len(cikti) == 10:
            break
    return cikti


def ciz_film(veri, b, s):
    return ciz_izgara(b, s, "Haftanın en beğenilen", "10 filmi",
                      "dizi.jpg kullanıcılarının bu hafta en beğendiği filmler",
                      veri)


def metin_film(veri, b, s):
    return izgara_metni("Haftanın en beğenilen 10 filmi", veri, b, s,
                        "Sen hangisini beğendin?",
                        "#dizijpg #film #haftaninfilmleri #sinema #filmonerisi "
                        "#filmizle #movie #sinemakeyfi #filmsever #tvshows")


# ---------------------------------------------------------- 4) EN BEĞENİLEN STÜDYO

def veri_studyo(b, s):
    _, _, sirket = havuzlar(b, s)
    return sirket_listesi(sirket)


def ciz_studyo(veri, b, s):
    return ciz_izgara(b, s, "Haftanın en beğenilen", "10 stüdyosu",
                      "dizi.jpg'de bu hafta öne çıkan yapımların arkasındaki isimler",
                      veri)


def metin_studyo(veri, b, s):
    return izgara_metni("Haftanın en beğenilen 10 stüdyosu", veri, b, s,
                        "Senin takip ettiğin stüdyo hangisi?",
                        "#dizijpg #stüdyo #yapımşirketi #dizi #film #sinema "
                        "#dizitakip #dizisever #filmsever #tvshows")


# -------------------------------------------------------- 5) EN BEĞENİLEN YÖNETMEN

def veri_yonetmen(b, s):
    _, yonetmen, _ = havuzlar(b, s)
    liste = kisi_listesi(yonetmen, {"Directing"})
    if len(liste) < 10:      # küçük hafta: bölüm yöneten oyuncu/yapımcılar da aday
        gorulen = {k["tmdb_id"] for k in liste}
        for k in kisi_listesi(yonetmen, None, adet=20):
            if k["tmdb_id"] not in gorulen:
                liste.append(k)
            if len(liste) == 10:
                break
    return liste[:10]


def ciz_yonetmen(veri, b, s):
    return ciz_izgara(b, s, "Haftanın en beğenilen", "10 yönetmeni",
                      "dizi.jpg'de bu hafta öne çıkan yapımların yönetmenleri",
                      veri)


def metin_yonetmen(veri, b, s):
    return izgara_metni("Haftanın en beğenilen 10 yönetmeni", veri, b, s,
                        "Bu hafta kimin işini beğendin?",
                        "#dizijpg #yönetmen #haftaninyonetmenleri #sinema #film "
                        "#dizi #filmonerisi #dizitakip #sinemasever #tvshows")


# ------------------------------------------------------------------- gönderiler

GONDERILER = {
    "diziler": {"sira": 1, "slug": "en-cok-izlenen-diziler",
                "veri": veri_diziler, "ciz": ciz_diziler, "metin": metin_diziler},
    "oyuncu": {"sira": 2, "slug": "en-begenilen-oyuncular",
               "veri": veri_oyuncu, "ciz": ciz_oyuncu, "metin": metin_oyuncu},
    "film": {"sira": 3, "slug": "en-begenilen-filmler",
             "veri": veri_film, "ciz": ciz_film, "metin": metin_film},
    "studyo": {"sira": 4, "slug": "en-begenilen-studyolar",
               "veri": veri_studyo, "ciz": ciz_studyo, "metin": metin_studyo},
    "yonetmen": {"sira": 5, "slug": "en-begenilen-yonetmenler",
                 "veri": veri_yonetmen, "ciz": ciz_yonetmen,
                 "metin": metin_yonetmen},
}


def uret(ad, b, s, kuru=False, cikti_dizin=None):
    tanim = GONDERILER[ad]
    bilgi(f"{ad}: veri çekiliyor…")
    veri = tanim["veri"](b, s)
    if len(veri) < 10:
        # ONLUK LİSTE EKSİK ÇIKARSA GÖNDERİ ÜRETİLMEZ: dokuz kutuluk bir
        # "ilk 10" verinin azlığını ilan eder.
        uyari(f"{ad}: yalnız {len(veri)} aday çıktı, gönderi üretilmedi")
        return None
    for i, o in enumerate(veri[:10]):
        bilgi(f"  {i + 1:>2}. {o.get('ad', '?')}")
    if kuru:
        return None
    dizin = cikti_dizin or os.path.join(CIKTI_KOK, hafta_klasoru(b))
    os.makedirs(dizin, exist_ok=True)
    png = os.path.join(dizin, f"{tanim['sira']}-{tanim['slug']}.png")
    txt = os.path.join(dizin, f"{tanim['sira']}-{tanim['slug']}.txt")
    tanim["ciz"](veri, b, s).save(png, "PNG", optimize=True)
    with open(txt, "w", encoding="utf-8") as f:
        f.write(tanim["metin"](veri, b, s) + "\n")
    tamam(f"{png}  ({os.path.getsize(png) // 1024} KB)")
    return png


def kur():
    """Zamanlanmış koşu için korumasız alana çalışma kopyası yazar
    (bkz. CALISMA sabitinin üstündeki TCC notu)."""
    import glob as _glob
    import shutil
    varliklar = os.path.join(CALISMA, "varliklar")
    os.makedirs(os.path.join(varliklar, "fonts"), exist_ok=True)
    shutil.copy2(os.path.abspath(__file__),
                 os.path.join(CALISMA, "haftalik_gonderi.py"))
    shutil.copy2(os.path.join(BURASI, "haftalik_video.py"),
                 os.path.join(CALISMA, "haftalik_video.py"))
    shutil.copy2(os.path.join(BURASI, AYAR_DOSYA),
                 os.path.join(CALISMA, AYAR_DOSYA))
    shutil.copy2(LOGO, os.path.join(varliklar, "logo.png"))
    for f in _glob.glob(os.path.join(FONT_DIZIN, "Poppins-*.ttf")):
        shutil.copy2(f, os.path.join(varliklar, "fonts", os.path.basename(f)))
    jeton = os.path.join(CALISMA, "tmdb.token")
    with open(jeton, "w", encoding="utf-8") as f:
        f.write(tmdb_token())
    os.chmod(jeton, 0o600)
    # ElevenLabs anahtarı (video seslendirmesi) — varsa kopyalanır.
    env = os.path.expanduser("~/.dizijpg-eleven.env")
    if os.path.exists(env):
        with open(env, encoding="utf-8") as f:
            for satir in f:
                if satir.startswith("ELEVENLABS_API_KEY="):
                    ses = os.path.join(CALISMA, "eleven.token")
                    with open(ses, "w", encoding="utf-8") as g:
                        g.write(satir.split("=", 1)[1].strip())
                    os.chmod(ses, 0o600)
    tamam(f"çalışma kopyası: {CALISMA}")
    tamam(f"zamanlanmış çıktı: {os.path.expanduser('~/Pictures/dizi.jpg-gonderiler')}")


def main():
    a = argparse.ArgumentParser(description="dizi.jpg haftalık Instagram gönderileri")
    a.add_argument("--hafta", help="ISO hafta içindeki bir tarih (YYYY-AA-GG); "
                                   "varsayılan: geçen tamamlanmış hafta")
    a.add_argument("--post", default="hepsi",
                   help="diziler | oyuncu | film | studyo | yonetmen | hepsi")
    a.add_argument("--cikti", help="çıktı klasörü (varsayılan cikti/instagram/<hafta>)")
    a.add_argument("--kuru", action="store_true", help="yalnız veri, görsel üretme")
    a.add_argument("--kur", action="store_true",
                   help="zamanlanmış koşu için çalışma kopyasını tazele")
    p = a.parse_args()

    if p.kur:
        kur()
        return 0

    b, s = hafta_araligi(p.hafta)
    bilgi(f"hafta: {tarih_metni(b, s)}  ({b} → {s})")
    adlar = list(GONDERILER) if p.post == "hepsi" else [p.post]
    for ad in adlar:
        if ad not in GONDERILER:
            hata(f"bilinmeyen gönderi: {ad}")
            return 1
        uret(ad, b, s, kuru=p.kuru, cikti_dizin=p.cikti)
    return 0


if __name__ == "__main__":
    sys.exit(main())
