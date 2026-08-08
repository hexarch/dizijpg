#!/usr/bin/env python3
"""dizi.jpg rehber demo hesabı için MARKA GIF'leri üretir.

Neden: rehber ekran görüntülerinde kullanılan demo hesabın (testkullanici)
profil ve kapak fotoğrafı olmalı. Bu görseller dizijpg.com'da YAYINLANIYOR,
dolayısıyla telifli hiçbir kare kullanılamaz — her piksel burada üretilir.

Üretilenler (bu dosyanın yanına):
  avatar.gif  400x400   (1:1  — uygulama daireye kırpar)
  kapak.gif  1200x500   (2.4:1 — kapak oranı)

Renkler tema.dart'tan: sarı #F5C518, siyah #0B0B0D.
Kullanım:  python3 marka_gif_uret.py
Bağımlılık: pillow, numpy
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw

SARI = (0xF5, 0xC5, 0x18)
SIYAH = (0x0B, 0x0B, 0x0D)
DIZIN = os.path.dirname(os.path.abspath(__file__))

KARE = 24          # kare sayısı (döngü dikişsiz: her şey faz=i/KARE ile periyodik)
SURE = 70          # kare başına ms  -> 1.68 sn'lik döngü
RENK = 64          # global palet boyu (küçük palet = küçük dosya)


def _sari_karisim(taban, yogunluk):
    """Siyah zemine sarı ışık ekler (yogunluk 0..1, HxW float)."""
    y = np.clip(yogunluk, 0.0, 1.0)[..., None]
    sari = np.array(SARI, dtype=np.float32)
    return taban + (sari - taban) * y


def _tepe(x, merkez, genislik):
    """0..1 arası dairesel koordinatta yumuşak tepe (dikişsiz)."""
    d = np.abs(((x - merkez + 0.5) % 1.0) - 0.5)
    return np.exp(-(d * d) / (2 * genislik * genislik))


# --------------------------------------------------------------------------
# AVATAR: dönen sarı ışık süpürmesi + film perforasyon halkası + nabız atan
# oynat üçgeni. Daireye kırpıldığında da tam görünür (tasarım radyal).
# --------------------------------------------------------------------------
def avatar_karesi(faz, boyut=800):
    lin = np.linspace(-1.0, 1.0, boyut, dtype=np.float32)
    x, y = np.meshgrid(lin, lin)
    r = np.hypot(x, y)
    aci = np.arctan2(y, x) / (2 * math.pi)          # -0.5..0.5

    taban = np.zeros((boyut, boyut, 3), dtype=np.float32)
    taban[:] = SIYAH
    # merkezden dışa hafif sıcak parlama
    taban = _sari_karisim(taban, 0.05 * np.exp(-(r * r) / 0.28))

    # dönen süpürme: halka üstünde (r~0.72) dolaşan sarı yay
    halka = np.exp(-((r - 0.72) ** 2) / (2 * 0.075 ** 2))
    supurme = _tepe(aci, faz - 0.5, 0.085) * halka
    taban = _sari_karisim(taban, 0.85 * supurme)
    # ters yönde ikinci, sönük süpürme (derinlik hissi)
    taban = _sari_karisim(taban, 0.28 * _tepe(aci, -faz * 0.6 + 0.25, 0.13) * halka)

    # ince dış kontur
    taban = _sari_karisim(taban, 0.5 * np.exp(-((r - 0.95) ** 2) / (2 * 0.012 ** 2)))

    img = Image.fromarray(np.clip(taban, 0, 255).astype(np.uint8), 'RGB')
    ciz = ImageDraw.Draw(img, 'RGBA')
    o = boyut / 2

    # film perforasyonları: 24 delik, süpürmeyle birlikte döner ve parlar
    n = 24
    for i in range(n):
        t = i / n + faz / n * 6            # dikişsiz: KARE sonunda tam delik kayar
        a = t * 2 * math.pi
        px = o + math.cos(a) * o * 0.88
        py = o + math.sin(a) * o * 0.88
        yakin = math.exp(-(((t - faz + 0.5) % 1.0 - 0.5) ** 2) / (2 * 0.10 ** 2))
        alfa = int(60 + 175 * yakin)
        k = o * (0.020 + 0.012 * yakin)
        ciz.ellipse([px - k, py - k, px + k, py + k], fill=SARI + (alfa,))

    # merkez işaret: yuvarlatılmış kare içinde oynat üçgeni, nabız atar
    nabiz = 0.5 + 0.5 * math.cos(2 * math.pi * faz)
    s = o * (0.40 + 0.018 * nabiz)
    ciz.rounded_rectangle([o - s, o - s, o + s, o + s], radius=s * 0.30,
                          fill=SARI + (int(228 + 27 * nabiz),))
    u = s * 0.52
    ciz.polygon([(o - u * 0.62, o - u), (o - u * 0.62, o + u), (o + u * 0.85, o)],
                fill=SIYAH + (255,))
    return img.resize((boyut // 2, boyut // 2), Image.LANCZOS)


# --------------------------------------------------------------------------
# KAPAK: kayan film şeritleri + çapraz ışık süpürmesi + nokta ızgara.
# --------------------------------------------------------------------------
def kapak_karesi(faz, en=1800, boy=750):
    gx = np.linspace(0.0, 1.0, en, dtype=np.float32)
    gy = np.linspace(0.0, 1.0, boy, dtype=np.float32)
    x, y = np.meshgrid(gx, gy)

    taban = np.zeros((boy, en, 3), dtype=np.float32)
    taban[:] = SIYAH

    # çapraz ışık süpürmesi (soldan sağa, dikişsiz)
    u = x * 0.85 + y * 0.32
    taban = _sari_karisim(taban, 0.42 * _tepe(u - faz, 0.0, 0.075))
    taban = _sari_karisim(taban, 0.16 * _tepe(u + faz * 0.5, 0.35, 0.16))

    # nokta ızgara (çok sönük, doku için). ADIM 26 -> 46: ince nokta bulutu GIF'te
    # yüksek entropi demek, LZW sıkıştırmasını öldürüp dosyayı ~2 kat büyütüyordu.
    izgara = ((np.sin(x * en / 46 * math.pi) ** 8) * (np.sin(y * boy / 46 * math.pi) ** 8))
    taban = _sari_karisim(taban, 0.09 * izgara)

    # alt/üst vinyet
    taban *= (1.0 - 0.55 * np.clip((np.abs(y - 0.5) - 0.28) / 0.22, 0, 1))[..., None]

    img = Image.fromarray(np.clip(taban, 0, 255).astype(np.uint8), 'RGB')
    ciz = ImageDraw.Draw(img, 'RGBA')

    # üç film şeridi, farklı hız ve yönde kayar (paralaks)
    seritler = [(0.20, 0.055, 1.0, 90), (0.50, 0.085, -0.6, 150), (0.80, 0.045, 1.6, 70)]
    for oran, kalinlik, hiz, alfa in seritler:
        ym = boy * oran
        h = boy * kalinlik
        ciz.rectangle([0, ym - h / 2, en, ym + h / 2], fill=SARI + (int(alfa * 0.22),))
        adim = h * 1.55
        kaydir = (faz * hiz * adim) % adim
        i = -2
        while True:
            px = i * adim + kaydir
            if px > en + adim:
                break
            d = h * 0.26
            ciz.rounded_rectangle([px, ym - d, px + d * 1.5, ym + d],
                                  radius=d * 0.4, fill=SARI + (alfa,))
            i += 1
        # şerit kenar çizgileri
        for ky in (ym - h / 2, ym + h / 2):
            ciz.line([0, ky, en, ky], fill=SARI + (int(alfa * 0.9),), width=max(1, int(boy / 380)))

    return img.resize((en // 2 if en % 2 == 0 else en // 2 + 1, boy // 2), Image.LANCZOS)


def gif_yaz(kareler, yol):
    """Tek GLOBAL palet + dithersiz kuantalama = küçük ve titremesiz GIF."""
    ornek = Image.new('RGB', (len(kareler) * 8, 64))
    for i, k in enumerate(kareler):                       # paleti tüm karelerden çıkar
        ornek.paste(k.resize((8, 64)), (i * 8, 0))
    palet = ornek.quantize(colors=RENK, method=Image.MEDIANCUT)
    p = [k.quantize(palette=palet, dither=Image.Dither.NONE) for k in kareler]
    p[0].save(yol, save_all=True, append_images=p[1:], duration=SURE,
              loop=0, optimize=True, disposal=1)
    return os.path.getsize(yol)


if __name__ == '__main__':
    a = [avatar_karesi(i / KARE) for i in range(KARE)]
    yol = os.path.join(DIZIN, 'avatar.gif')
    print(f'avatar.gif  {a[0].size}  {gif_yaz(a, yol) / 1024:.0f} KB')

    k = [kapak_karesi(i / KARE) for i in range(KARE)]
    yol = os.path.join(DIZIN, 'kapak.gif')
    print(f'kapak.gif   {k[0].size}  {gif_yaz(k, yol) / 1024:.0f} KB')
