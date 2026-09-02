# -*- coding: utf-8 -*-
"""dizi.jpg Play mağaza görselleri: ham 1080x2160 kareleri çerçeveler.
Kullanım: python3 cerceve.py <locale> <ham_dizin> <cikti_dizin> [--tablet] [--feature]
"""
import sys, os, json
from PIL import Image, ImageDraw, ImageFont, ImageFilter

BASE = os.path.dirname(os.path.abspath(__file__))
FONT_DIR = "/Users/wolf/Desktop/masaustuyedek/projeler/dizijpg/app/assets/fonts"
SARI = (245, 197, 24)
ZEMIN = (11, 11, 13)
BEYAZ = (255, 255, 255)
GRI = (190, 190, 196)

METIN = json.load(open(os.path.join(BASE, "metinler.json"), encoding="utf-8"))

def font_yukle(locale, kalin, boyut):
    if locale == "ar":
        f = ImageFont.truetype(os.path.join(BASE, "fonts/Cairo-Bold.ttf" if kalin else "fonts/Cairo-SemiBold.ttf"), boyut)
        f.kalin = kalin; return f
    if locale in ("el-GR", "ru-RU"):
        f = ImageFont.truetype(os.path.join(BASE, "fonts/NotoSans-var.ttf"), boyut)
        f.set_variation_by_name("Bold" if kalin else "Medium")
        f.kalin = kalin; return f
    f = ImageFont.truetype(os.path.join(FONT_DIR, "Poppins-Bold.ttf" if kalin else "Poppins-Medium.ttf"), boyut)
    f.kalin = kalin; return f

def sekil(locale, s):
    if locale != "ar":
        return s
    import arabic_reshaper
    from bidi.algorithm import get_display
    return get_display(arabic_reshaper.reshape(s))

def parcala(satir):
    """'abc **vurgu** def' -> [(metin, vurgu_mu)]"""
    out = []; i = 0; vurgu = False
    for p in satir.split("**"):
        if p: out.append((p, vurgu))
        vurgu = not vurgu
    return out

import subprocess, hashlib
_AR_ONBELLEK = {}
def ar_ciz(satir, boyut, kalin, renk, vurgu_renk):
    """Arapça satırı CoreText ile RGBA görsele çizer (harf birleştirme + RTL doğru)."""
    k = (satir, boyut, kalin, renk, vurgu_renk)
    if k in _AR_ONBELLEK: return _AR_ONBELLEK[k]
    h = hashlib.md5(repr(k).encode()).hexdigest()[:12]
    yol = os.path.join(BASE, "ar_cache", h + ".png"); os.makedirs(os.path.dirname(yol), exist_ok=True)
    if not os.path.exists(yol):
        ad = "Cairo-Bold" if kalin else "Cairo-SemiBold"
        subprocess.run([os.path.join(BASE, "metin_ciz"), os.path.join(BASE, "fonts", ad + ".ttf"), str(boyut),
                        "%02X%02X%02X" % renk, "%02X%02X%02X" % vurgu_renk, yol, satir, ad], check=True, capture_output=True)
    im = Image.open(yol).convert("RGBA"); _AR_ONBELLEK[k] = im; return im

def metin_genislik(satir, font, locale):
    if locale == "ar":
        return ar_ciz(satir, font.size, font.kalin, (255,255,255), (255,255,255)).width
    return sum(font.getlength(t) for t, _ in parcala(satir))

def satir_ciz(draw, x, y, satir, font, locale, renk, vurgu_renk, hiza="sol", genislik=1080, im=None):
    parcalar = parcala(satir)
    if locale == "ar":
        g = ar_ciz(satir, font.size, font.kalin, renk, vurgu_renk)
        sag = (genislik - x) if hiza == "sag" else (genislik/2 + g.width/2 if hiza == "orta" else x + g.width)
        im.alpha_composite(g, (int(sag - g.width), int(y - font.size*0.28)))
        return
    if False:
        parcalar = [(sekil(locale, t), v) for t, v in parcalar]
        toplam = sum(font.getlength(t) for t, _ in parcalar)
        # sağdan sola: mantıksal sıradaki ilk parça en sağda
        cx = (genislik - x) if hiza == "sag" else (genislik/2 + toplam/2 if hiza == "orta" else x + toplam)
        for t, v in parcalar:
            w = font.getlength(t); cx -= w
            draw.text((cx, y), t, font=font, fill=vurgu_renk if v else renk)
        return
    toplam = sum(font.getlength(t) for t, _ in parcalar)
    cx = (genislik - toplam) / 2 if hiza == "orta" else x
    for t, v in parcalar:
        draw.text((cx, y), t, font=font, fill=vurgu_renk if v else renk)
        cx += font.getlength(t)

def satirlar(metin):
    return metin.split("\n")

def sigdir(locale, kalin, boyut, metin, azami, asgari=28):
    """Tüm satırlar azami genişliğe sığana kadar puntoyu düşürür; (font, boyut) döner."""
    while boyut > asgari:
        f = font_yukle(locale, kalin, boyut)
        if all(metin_genislik(s, f, locale) <= azami for s in satirlar(metin)):
            return f, boyut
        boyut -= 2
    return font_yukle(locale, kalin, boyut), boyut

def yuvarlak_maske(w, h, r):
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w - 1, h - 1), r, fill=255)
    return m

def telefon(ekran, sw):
    """ekran: PIL 1080x2160 → çerçeveli telefon (RGBA), ekran genişliği sw."""
    sh = int(ekran.height * sw / ekran.width)
    ekran = ekran.resize((sw, sh), Image.LANCZOS)
    b = int(sw * 0.028)            # bezel
    r_ekran = int(sw * 0.075)
    W, H = sw + 2*b, sh + 2*b
    cerceve = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(cerceve)
    d.rounded_rectangle((0, 0, W-1, H-1), r_ekran + b, fill=(28, 28, 32, 255), outline=(70, 70, 78, 255), width=3)
    ek = ekran.convert("RGBA"); ek.putalpha(yuvarlak_maske(sw, sh, r_ekran))
    cerceve.alpha_composite(ek, (b, b))
    # kamera deliği
    d.ellipse((W/2 - 14, b + 18, W/2 + 14, b + 46), fill=(8, 8, 10, 255))
    return cerceve

def golge(size, blur=60, alpha=170):
    g = Image.new("RGBA", (size[0] + blur*4, size[1] + blur*4), (0, 0, 0, 0))
    ImageDraw.Draw(g).rounded_rectangle((blur*2, blur*2, blur*2 + size[0], blur*2 + size[1]), 80, fill=(0, 0, 0, alpha))
    return g.filter(ImageFilter.GaussianBlur(blur))

def isik(W, H, cx, cy, rx, ry, renk=SARI, alpha=95):
    g = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(g).ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=renk + (alpha,))
    return g.filter(ImageFilter.GaussianBlur(160))

def telefon_karesi(locale, idx, ham_yolu, cikti_yolu):
    W, H = 1080, 1920
    im = Image.new("RGBA", (W, H), ZEMIN + (255,))
    im.alpha_composite(isik(W, H, 540, 1250, 520, 620))
    d = ImageDraw.Draw(im)
    m = METIN[locale]["kareler"][idx]
    hiza = "sag" if locale == "ar" else "sol"
    x = 76
    # başlık
    fb, bb = sigdir(locale, True, 82, m["baslik"], W - 2*x)
    y = 110
    for s in satirlar(m["baslik"]):
        satir_ciz(d, x, y, s, fb, locale, BEYAZ, SARI, hiza, im=im)
        y += int(bb * 1.2)
    y += 14
    fa, ba = sigdir(locale, False, 40, m["alt"], W - 2*x)
    for s in satirlar(m["alt"]):
        satir_ciz(d, x, y, s, fa, locale, GRI, GRI, hiza, im=im)
        y += int(ba * 1.35)
    # telefon
    ekran = Image.open(ham_yolu).convert("RGB")
    tel = telefon(ekran, 800)
    tx = (W - tel.width) // 2
    ty = max(y + 60, 520)
    g = golge((tel.width, tel.height))
    im.alpha_composite(g, (tx - 120, ty - 120 + 40))
    im.alpha_composite(tel, (tx, ty))
    im.convert("RGB").save(cikti_yolu, "PNG", optimize=True)

def tablet_karesi(locale, cift, ham_dizin, cikti_yolu, adlar):
    """Yatay 1920x1080: solda başlık, sağda iki telefon."""
    W, H = 1920, 1080
    im = Image.new("RGBA", (W, H), ZEMIN + (255,))
    im.alpha_composite(isik(W, H, 1300 if locale != "ar" else 620, 700, 700, 500, alpha=80))
    d = ImageDraw.Draw(im)
    i1, i2 = cift
    m = METIN[locale]["kareler"][i1]
    hiza = "sag" if locale == "ar" else "sol"
    x = 90; y = 300
    genis = 900
    fb, bb = sigdir(locale, True, 64, m["baslik"], genis - x)
    fa, ba = sigdir(locale, False, 32, m["alt"], genis - x)
    for s in satirlar(m["baslik"]):
        satir_ciz(d, x, y, s, fb, locale, BEYAZ, SARI, hiza, genislik=genis if locale != "ar" else W, im=im)
        y += int(bb * 1.22)
    y += 12
    for s in satirlar(m["alt"]):
        satir_ciz(d, x, y, s, fa, locale, GRI, GRI, hiza, genislik=genis if locale != "ar" else W, im=im)
        y += int(ba * 1.4)
    for k, (idx, dx, dy) in enumerate([(i1, 980, 120), (i2, 1440, 260)]):
        ek = Image.open(os.path.join(ham_dizin, adlar[idx])).convert("RGB")
        tel = telefon(ek, 400)
        if locale == "ar": dx = W - dx - tel.width
        im.alpha_composite(golge((tel.width, tel.height), blur=40, alpha=150), (dx - 80, dy - 60))
        im.alpha_composite(tel, (dx, dy))
    im.convert("RGB").save(cikti_yolu, "PNG", optimize=True)

def ozellik_grafigi(locale, ham_dizin, cikti_yolu, adlar):
    """1024x500 özellik grafiği."""
    W, H = 1024, 500
    im = Image.new("RGBA", (W, H), ZEMIN + (255,))
    im.alpha_composite(isik(W, H, 760 if locale != "ar" else 264, 300, 360, 260, alpha=110))
    d = ImageDraw.Draw(im)
    m = METIN[locale]["ozellik"]
    hiza = "sag" if locale == "ar" else "sol"
    # logo metni
    fl = ImageFont.truetype(os.path.join(FONT_DIR, "Poppins-Black.ttf"), 54)
    lx = 64 if locale != "ar" else W - 64 - fl.getlength("dizi.jpg")
    d.text((lx, 64), "dizi", font=fl, fill=BEYAZ)
    d.text((lx + fl.getlength("dizi"), 64), ".jpg", font=fl, fill=SARI)
    fb, bb = sigdir(locale, True, 44, m["baslik"], 520, asgari=24)
    fa, ba = sigdir(locale, False, 24, m["alt"], 520, asgari=16)
    y = 160
    for s in satirlar(m["baslik"]):
        satir_ciz(d, 64, y, s, fb, locale, BEYAZ, SARI, hiza, genislik=W, im=im)
        y += int(bb * 1.23)
    y += 10
    for s in satirlar(m["alt"]):
        satir_ciz(d, 64, y, s, fa, locale, GRI, GRI, hiza, genislik=W, im=im)
        y += int(ba * 1.4)
    for idx, dx, dy in [(0, 600, 70), (1, 800, 150)]:
        ek = Image.open(os.path.join(ham_dizin, adlar[idx])).convert("RGB")
        tel = telefon(ek, 210)
        if locale == "ar": dx = W - dx - tel.width
        im.alpha_composite(golge((tel.width, tel.height), blur=30, alpha=150), (dx - 60, dy - 40))
        im.alpha_composite(tel, (dx, dy))
    im.convert("RGB").save(cikti_yolu, "PNG", optimize=True)

ADLAR = ["1-ana-sayfa.png", "2-dizi-sayfasi.png", "3-bolum-isaretleme.png", "4-takvim.png",
         "5-bolum-isi-haritasi.png", "6-istatistik-kutuphane.png", "7-incelemeler.png", "8-kesfet.png"]

if __name__ == "__main__":
    locale, ham, cikti = sys.argv[1:4]
    os.makedirs(cikti, exist_ok=True)
    if "--only-feature" not in sys.argv:
        for i, ad in enumerate(ADLAR):
            telefon_karesi(locale, i, os.path.join(ham, ad), os.path.join(cikti, ad))
        if "--tablet" in sys.argv:
            os.makedirs(os.path.join(cikti, "tablet"), exist_ok=True)
            for n, cift in enumerate([(0, 1), (2, 3), (4, 5), (6, 7)]):
                tablet_karesi(locale, cift, ham, os.path.join(cikti, "tablet", f"{n+1}-tablet.png"), ADLAR)
    if "--feature" in sys.argv or "--only-feature" in sys.argv:
        ozellik_grafigi(locale, ham, os.path.join(cikti, "ozellik-grafigi.png"), ADLAR)
    print("ok", locale, cikti)
