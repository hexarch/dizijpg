#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""dizi.jpg — DOĞUM GÜNÜ UYGULAMA İKONU ÖNERİLERİ (istek md. 36)

Bu betik dört ikon VARYANTI üretir. Varyantlar YALNIZ ÖNERİDİR: uygulamaya
kurulmuş değiller, kullanıcı görüp seçmeden hiçbiri kullanılmayacak.

--- NEDEN İKON HENÜZ DEĞİŞMİYOR (kod tarafındaki karar) -------------------
Android'de çalışma anında uygulama ikonu değiştirmenin resmi bir API'si yok.
Tek yol manifeste gömülü `activity-alias`ları `PackageManager` ile açıp
kapatmak; yan etkileri gerçek: bazı başlatıcılarda ikon ANA EKRANDAN DÜŞER,
kısayollar/widget'lar kırılır, uygulama o an kapanabilir. Kutlama niyetiyle
kullanıcının ana ekranındaki kısayolunu kaybettiremeyiz — kutlama uygulama
İÇİNDE yapılıyor (`app/lib/ekranlar/dogum_gunu.dart`).

--- TASARIM KURALLARI -----------------------------------------------------
1. MARKA BOZULMAZ. Taban, uygulamanın GERÇEK ikonudur
   (`app/assets/icon/icon.png`): siyah zemin + açık gri "DİZİ" + kırmızı
   bloklu "JPG". Kelime işareti hiç kırpılmaz, kaydırılmaz, rengi
   değiştirilmez — ikon uzaktan bakınca AYNI ikondur.
2. TEK DOKUNUŞ. Her varyantta doğum günü teması TEK bir öğeyle verilir
   (şapka / konfeti / mum / balon). Üst üste yığmak ikonu tanınmaz yapar.
3. SÜSLEME BOŞ ALANA KONUR. Kelime işareti 512'lik tuvalde ~y165-340
   arasında; üst şerit (y<160) ve alt şerit (y>350) tamamen boş. Süsleme
   oraya yerleşir, harflerin üstüne binmez.
4. AKSAN RENGİ MARKA SARISI (#F5C518). Uygulamanın her yerindeki vurgu
   rengi bu; kutlama öğesi de bu sarıyla çiziliyor ki "başka bir uygulama"
   gibi durmasın. Kırmızı yalnız ikinci derece aksan olarak (logodaki JPG
   bloğunun kırmızısı) kullanılır.
5. KENAR PAYI. Android maskeleri (daire/squircle) kenarlardan ~%10 kırpar.
   Hiçbir süsleme öğesi tuvalin dış %8'ine girmez.

--- ÇALIŞTIRMA ------------------------------------------------------------
    python3 ikon_uret.py
Çıktı: bu klasöre 512x512 PNG'ler. Pillow gerekir (`pip install pillow`).
"""

import math
import os

from PIL import Image, ImageDraw

# --- yollar ---------------------------------------------------------------
KLASOR = os.path.dirname(os.path.abspath(__file__))
PROJE = os.path.dirname(KLASOR)
TABAN_IKON = os.path.join(PROJE, "app", "assets", "icon", "icon.png")

# --- ölçüler --------------------------------------------------------------
BOYUT = 512
# Kenar yumuşatma: her şey 4 katı tuvale çizilip küçültülür. Pillow'un
# poligon çizimi antialias YAPMAZ; 4x süperörnekleme tırtıklı kenarları
# tamamen giderir.
OLCEK = 4
BUYUK = BOYUT * OLCEK

# --- marka renkleri -------------------------------------------------------
SARI = (245, 197, 24, 255)        # #F5C518 — uygulamanın vurgu rengi
ACIK_SARI = (255, 215, 94, 255)   # #FFD75E
KIRMIZI = (183, 28, 40, 255)      # logodaki JPG bloğunun kırmızısı
BEYAZ = (240, 240, 244, 255)
SIYAH = (11, 11, 13, 255)


def taban():
    """Gerçek uygulama ikonunu 512x512 RGBA olarak döndürür."""
    im = Image.open(TABAN_IKON).convert("RGBA")
    return im.resize((BOYUT, BOYUT), Image.LANCZOS)


def tuval():
    """Süsleme katmanı (şeffaf, 4x)."""
    return Image.new("RGBA", (BUYUK, BUYUK), (0, 0, 0, 0))


def bindir(alt, ust):
    """4x süsleme katmanını küçültüp tabanın üstüne yapıştırır."""
    return Image.alpha_composite(alt, ust.resize((BOYUT, BOYUT), Image.LANCZOS))


def o(x):
    """512'lik koordinatı 4x tuvale çevirir."""
    return x * OLCEK


def dondur(noktalar, merkez, aci):
    """[noktalar]ı [merkez] etrafında [aci] derece döndürür."""
    r = math.radians(aci)
    cx, cy = merkez
    return [
        (
            cx + (x - cx) * math.cos(r) - (y - cy) * math.sin(r),
            cy + (x - cx) * math.sin(r) + (y - cy) * math.cos(r),
        )
        for x, y in noktalar
    ]


def serit(cizim, merkez, en, boy, aci, renk):
    """Döndürülmüş dolu dikdörtgen (konfeti parçası)."""
    cx, cy = merkez
    kose = [
        (cx - en / 2, cy - boy / 2),
        (cx + en / 2, cy - boy / 2),
        (cx + en / 2, cy + boy / 2),
        (cx - en / 2, cy + boy / 2),
    ]
    cizim.polygon(dondur(kose, merkez, aci), fill=renk)


# ---------------------------------------------------------------------------
# 1) PARTİ ŞAPKASI
# ---------------------------------------------------------------------------
def varyant_parti_sapkasi():
    """Kelime işaretinin üstüne yan yatmış sarı parti şapkası."""
    kat = tuval()
    c = ImageDraw.Draw(kat)

    # Şapka, kelime işaretinin ÜSTÜNDEKİ boş şeride oturur ve hafif sağa
    # eğiktir — dik dursaydı ikonu ikiye bölen bir üçgen gibi okunurdu.
    tepe = (o(238), o(44))
    sol = (o(178), o(158))
    sag = (o(310), o(158))
    merkez = (o(244), o(120))
    aci = 12
    koni = dondur([tepe, sol, sag], merkez, aci)
    c.polygon(koni, fill=SARI)

    # Siyah şeritler: koninin İÇİNE maskelenir (taşan kısım kırpılır).
    seritler = Image.new("RGBA", (BUYUK, BUYUK), (0, 0, 0, 0))
    sc = ImageDraw.Draw(seritler)
    for i, (y0, y1) in enumerate([(78, 96), (116, 136)]):
        genislik = 34 + i * 30
        sc.polygon(
            dondur(
                [
                    (o(238 - genislik / 2), o(y0)),
                    (o(238 + genislik / 2), o(y0)),
                    (o(238 + genislik / 2 + 8), o(y1)),
                    (o(238 - genislik / 2 - 8), o(y1)),
                ],
                merkez,
                aci,
            ),
            fill=SIYAH,
        )
    maske = Image.new("L", (BUYUK, BUYUK), 0)
    ImageDraw.Draw(maske).polygon(koni, fill=255)
    kat = Image.alpha_composite(kat, Image.composite(
        seritler, Image.new("RGBA", (BUYUK, BUYUK), (0, 0, 0, 0)), maske))

    # Ponpon: koninin ucuna BİNDİRİLİR (tepe noktasının 8 px altına). Tam
    # tepeye konsaydı sivri uçla arasında ince bir siyah çizgi kalıyor,
    # küçültünce ponpon havada duruyor gibi görünüyordu.
    c = ImageDraw.Draw(kat)
    px, py = dondur([(o(238), o(52))], merkez, aci)[0]
    c.ellipse([px - o(21), py - o(21), px + o(21), py + o(21)], fill=BEYAZ)
    return bindir(taban(), kat)


# ---------------------------------------------------------------------------
# 2) KONFETİ
# ---------------------------------------------------------------------------
def varyant_konfeti():
    """Kelime işaretinin üstüne ve altına serpilmiş konfeti."""
    kat = tuval()
    c = ImageDraw.Draw(kat)

    # Elle yerleştirildi (rastgele değil): hiçbir parça harflere değmiyor,
    # kenar payı korunuyor, dağılım köşelere doğru seyreliyor.
    parcalar = [
        # (x, y, en, boy, açı, renk)
        (92, 96, 15, 26, 24, SARI),
        (148, 52, 13, 22, -38, BEYAZ),
        (206, 104, 16, 27, 62, KIRMIZI),
        (262, 56, 14, 24, 14, SARI),
        (318, 108, 13, 22, -22, ACIK_SARI),
        (376, 64, 15, 26, 44, SARI),
        (428, 118, 12, 21, -56, BEYAZ),
        (128, 142, 12, 20, 70, ACIK_SARI),
        (350, 148, 12, 20, -12, KIRMIZI),
        (244, 132, 11, 19, 34, BEYAZ),
        (74, 396, 14, 24, -30, SARI),
        (140, 438, 12, 21, 52, BEYAZ),
        (208, 392, 15, 25, 8, ACIK_SARI),
        (276, 444, 13, 22, -46, SARI),
        (344, 398, 14, 24, 28, KIRMIZI),
        (410, 436, 12, 21, -16, SARI),
        (176, 366, 10, 18, 64, KIRMIZI),
        (312, 362, 10, 18, -64, ACIK_SARI),
    ]
    for x, y, en, boy, aci, renk in parcalar:
        serit(c, (o(x), o(y)), o(en), o(boy), aci, renk)

    # Birkaç yuvarlak pul: yalnız dikdörtgen olsaydı doku tekdüze kalırdı.
    for x, y, r, renk in [
        (110, 60, 8, KIRMIZI), (300, 90, 7, BEYAZ), (400, 96, 8, SARI),
        (104, 442, 7, ACIK_SARI), (240, 400, 8, KIRMIZI), (378, 460, 7, BEYAZ),
    ]:
        c.ellipse([o(x - r), o(y - r), o(x + r), o(y + r)], fill=renk)
    return bindir(taban(), kat)


# ---------------------------------------------------------------------------
# 3) MUM
# ---------------------------------------------------------------------------
def varyant_mum():
    """Kelime işareti "pasta"ya dönüşür: üstünde tek bir doğum günü mumu."""
    kat = tuval()
    c = ImageDraw.Draw(kat)

    # Tek mum, tam ortada: "kaç yaşında" bilgisi vermeyen, her yaşa uyan
    # tek bir mum (birden çok mum saymaya davet eder ve küçük boyda lapa olur).
    x = 256
    govde_ust, govde_alt = 96, 158
    c.rounded_rectangle(
        [o(x - 15), o(govde_ust), o(x + 15), o(govde_alt)],
        radius=o(6), fill=BEYAZ,
    )
    # Sarı sarmal şeritler (klasik mum dokusu).
    for i, y in enumerate(range(govde_ust + 8, govde_alt - 4, 18)):
        c.polygon(
            [
                (o(x - 15), o(y)), (o(x + 15), o(y - 7)),
                (o(x + 15), o(y + 2)), (o(x - 15), o(y + 9)),
            ],
            fill=SARI,
        )
    # Fitil
    c.line([o(x), o(govde_ust), o(x), o(govde_ust - 12)], fill=SIYAH, width=o(3))
    # Alev: damla. Köşeli poligon yerine PARAMETRİK eğri — az köşeli bir alev
    # "ok ucu" gibi okunuyordu.
    c.polygon(alev_noktalari(x, govde_ust - 6, 21, 62), fill=SARI)
    c.polygon(alev_noktalari(x, govde_ust - 14, 10, 34), fill=(255, 246, 214, 255))

    # Alevin çevresine YUMUŞAK hâle. Tek bir yarı saydam elips SERT KENARLI
    # bir disk gibi görünüyordu (siyah zeminde apaçık bir daire); bunun yerine
    # düşük çözünürlükte iç içe elipslerle gerçek bir geçiş üretilip
    # büyütülüyor.
    kat = Image.alpha_composite(hale_katmani(x, govde_ust - 30, 96), kat)
    return bindir(taban(), kat)


def alev_noktalari(x, dip, en, boy):
    """Damla biçimli alev konturu (4x koordinatlarda)."""
    noktalar = []
    for i in range(41):
        t = i / 40  # 0 = dip, 1 = tepe
        # Genişlik profili: dipte dar, %35'te en geniş, tepede sıfır.
        genislik = en * math.sin(math.pi * min(1.0, t ** 0.62))
        noktalar.append((o(x + genislik), o(dip - boy * t)))
    for i in range(41):
        t = (40 - i) / 40
        genislik = en * math.sin(math.pi * min(1.0, t ** 0.62))
        noktalar.append((o(x - genislik), o(dip - boy * t)))
    return noktalar


def hale_katmani(x, y, yaricap):
    """Merkezden dışa sönümlenen sarı hâle (4x tuval boyunda RGBA)."""
    kucuk = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    kc = ImageDraw.Draw(kucuk)
    adim = 40
    for i in range(adim, 0, -1):
        r = 64 * i / adim
        alfa = int(46 * (1 - i / adim) ** 1.7)
        kc.ellipse([64 - r, 64 - r, 64 + r, 64 + r], fill=(245, 197, 24, alfa))
    kucuk = kucuk.resize((o(yaricap * 2), o(yaricap * 2)), Image.LANCZOS)
    kat = Image.new("RGBA", (BUYUK, BUYUK), (0, 0, 0, 0))
    kat.paste(kucuk, (o(x - yaricap), o(y - yaricap)), kucuk)
    return kat


# ---------------------------------------------------------------------------
# 4) BALON
# ---------------------------------------------------------------------------
def varyant_balon():
    """Sağ üst köşeden yükselen iki balon (sarı önde, kırmızı arkada)."""
    kat = tuval()
    c = ImageDraw.Draw(kat)

    # İpler kelime işaretinin ÜSTÜNDE biter (y=158). Harflerin üstünden
    # geçseydi kural 3 çiğnenir, "DİZİ"nin üstü çizilmiş gibi görünürdü.
    IP_SONU = 160

    def balon(x, y, r, renk, ip_egim):
        # Gövde: hafif yumurta (yatay yarıçap dikeyden küçük).
        c.ellipse([o(x - r * 0.86), o(y - r), o(x + r * 0.86), o(y + r)], fill=renk)
        # Ağız üçgeni
        c.polygon(
            [(o(x - r * 0.16), o(y + r * 0.94)), (o(x + r * 0.16), o(y + r * 0.94)),
             (o(x), o(y + r * 1.2))],
            fill=renk,
        )
        # İp: S kıvrımlı, üst şeridin içinde biten kısa bir eğri.
        bas = y + r * 1.2
        boy = max(0, IP_SONU - bas)
        # Kıvrım BAŞTA VE SONDA sıfırlanır (sin(t*pi)): ucu yana kaçan eğri
        # kısa boyda "ayak" gibi duruyordu, bu profil sarkan ip gibi durur.
        ip = [
            (x + ip_egim * math.sin(t * math.pi), bas + t * boy)
            for t in [i / 24 for i in range(25)]
        ]
        c.line([(o(px), o(py)) for px, py in ip], fill=(206, 206, 214, 230),
               width=o(2), joint="curve")
        # Parlama: küçük ve PARLAK. Büyük/soluk bir elips sarının üstünde
        # gri bir leke gibi duruyordu.
        c.ellipse(
            [o(x - r * 0.52), o(y - r * 0.60), o(x - r * 0.22), o(y - r * 0.28)],
            fill=(255, 255, 255, 205),
        )

    # Arkadaki kırmızı önce çizilir ki sarı önde kalsın.
    # Konumlar kenar payına göre seçildi: hiçbir balon tuvalin dış %8'ine
    # (41 px) girmiyor — daire/squircle maskesi ikonu kırpınca kesilmesinler.
    balon(392, 112, 34, KIRMIZI, 10)
    balon(312, 90, 44, SARI, -12)
    return bindir(taban(), kat)


VARYANTLAR = [
    ("1-parti-sapkasi.png", varyant_parti_sapkasi),
    ("2-konfeti.png", varyant_konfeti),
    ("3-mum.png", varyant_mum),
    ("4-balon.png", varyant_balon),
]


def main():
    for ad, uret in VARYANTLAR:
        yol = os.path.join(KLASOR, ad)
        uret().save(yol)
        print("yazıldı:", yol)
    # Karşılaştırma için tabanı da 512'ye indirip yanına koyuyoruz: varyantı
    # tek başına görmek yanıltıcı, "bugünkü ikonla yan yana" karar veriliyor.
    taban().save(os.path.join(KLASOR, "0-mevcut-ikon.png"))
    print("yazıldı:", os.path.join(KLASOR, "0-mevcut-ikon.png"))


if __name__ == "__main__":
    main()
