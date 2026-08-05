#!/usr/bin/env python3
"""Genel sayfa kesici.

Beyaz zeminli bir varlık sayfasını tek tek saydam PNG'lere ayırır.

Sabit ızgarayla bölmek işe yaramıyor: üretilen sayfalarda varlıklar eşit
aralıklı çıkmıyor, satır başına düşen sayı da değişebiliyor. Bu yüzden
bağlantılı bileşen kullanılır, sonra bileşenler önce satıra (dikey kümeleme)
sonra soldan sağa sıralanır.

Adları vermeden çalıştırırsan yalnızca ne bulduğunu yazar ve etiketli bir
önizleme üretir — sıralamayı doğrulamadan isim atamak için.

Kullanım:
    python3 tools/kes_sayfa.py sayfa.jpg --onizleme onizleme.png
    python3 tools/kes_sayfa.py sayfa.jpg --klasor assets/sprites/x --adlar a,b,c
"""

import argparse
import os
import sys

from PIL import Image, ImageDraw

BEYAZ_ESIK = 34
EN_KUCUK_PARCA = 2500
SATIR_TOLERANSI = 0.35   # kutu yüksekliğinin bu kadarı kadar kayma aynı satır


def zemini_sil(im: Image.Image) -> Image.Image:
    rgb = im.convert("RGB")
    isaret = (255, 0, 255)
    w, h = rgb.size
    for nokta in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        ImageDraw.floodfill(rgb, nokta, isaret, thresh=BEYAZ_ESIK)
    rgba = im.convert("RGBA")
    piksel = rgba.load()
    kaynak = rgb.load()
    for y in range(h):
        for x in range(w):
            if kaynak[x, y] == isaret:
                piksel[x, y] = (255, 255, 255, 0)
    return rgba


def parcalar(im: Image.Image, en_kucuk: int) -> list:
    w, h = im.size
    piksel = im.load()
    gorulen = bytearray(w * h)
    bulunan = []
    for sy in range(h):
        for sx in range(w):
            if piksel[sx, sy][3] < 8 or gorulen[sy * w + sx]:
                continue
            gorulen[sy * w + sx] = 1
            yigin = [(sx, sy)]
            x0 = x1 = sx
            y0 = y1 = sy
            sayi = 0
            while yigin:
                x, y = yigin.pop()
                sayi += 1
                if x < x0: x0 = x
                if x > x1: x1 = x
                if y < y0: y0 = y
                if y > y1: y1 = y
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and not gorulen[ny * w + nx] \
                                and piksel[nx, ny][3] >= 8:
                            gorulen[ny * w + nx] = 1
                            yigin.append((nx, ny))
            if sayi >= en_kucuk:
                bulunan.append({"sayi": sayi, "kutu": (x0, y0, x1 + 1, y1 + 1)})
    return bulunan


def satirlara_diz(bulunan: list) -> list:
    """Önce satır, sonra soldan sağa. Satır sınırı, kutuların dikey
    örtüşmesinden bulunur — sabit bir satır yüksekliği varsaymaz."""
    kalan = sorted(bulunan, key=lambda p: p["kutu"][1])
    sirali = []
    while kalan:
        ilk = kalan.pop(0)
        yukseklik = ilk["kutu"][3] - ilk["kutu"][1]
        merkez = (ilk["kutu"][1] + ilk["kutu"][3]) * 0.5
        satir = [ilk]
        for aday in list(kalan):
            aday_merkez = (aday["kutu"][1] + aday["kutu"][3]) * 0.5
            if abs(aday_merkez - merkez) <= yukseklik * SATIR_TOLERANSI + 30:
                satir.append(aday)
                kalan.remove(aday)
        satir.sort(key=lambda p: p["kutu"][0])
        sirali.extend(satir)
    return sirali


def main() -> int:
    ayrist = argparse.ArgumentParser()
    ayrist.add_argument("kaynak")
    ayrist.add_argument("--klasor")
    ayrist.add_argument("--adlar", help="virgülle ayrılmış, sıralı dosya adları")
    ayrist.add_argument("--onizleme")
    ayrist.add_argument("--yukseklik", type=int, default=256)
    ayrist.add_argument("--en-kucuk", type=int, default=EN_KUCUK_PARCA)
    arg = ayrist.parse_args()

    sayfa = zemini_sil(Image.open(arg.kaynak))
    bulunan = satirlara_diz(parcalar(sayfa, arg.en_kucuk))
    print("%d parça bulundu" % len(bulunan))
    for i, p in enumerate(bulunan):
        k = p["kutu"]
        print("  %2d  %4dx%-4d  konum %4d,%-4d  %d piksel"
              % (i, k[2] - k[0], k[3] - k[1], k[0], k[1], p["sayi"]))

    if arg.onizleme:
        onizleme = sayfa.convert("RGB").copy()
        ciz = ImageDraw.Draw(onizleme)
        for i, p in enumerate(bulunan):
            ciz.rectangle(p["kutu"], outline=(230, 40, 40), width=6)
            ciz.text((p["kutu"][0] + 8, p["kutu"][1] + 8), str(i), fill=(230, 40, 40))
        onizleme.save(arg.onizleme)
        print("önizleme: %s" % arg.onizleme)

    if not arg.adlar:
        return 0
    adlar = [a.strip() for a in arg.adlar.split(",") if a.strip()]
    if len(adlar) != len(bulunan):
        print("HATA: %d ad verildi ama %d parça var." % (len(adlar), len(bulunan)),
              file=sys.stderr)
        return 1
    os.makedirs(arg.klasor, exist_ok=True)
    for ad, p in zip(adlar, bulunan):
        if ad == "-":       # atlanacak parça
            continue
        kare = sayfa.crop(p["kutu"])
        if kare.height > arg.yukseklik:
            yeni_g = max(1, round(kare.width * arg.yukseklik / kare.height))
            kare = kare.resize((yeni_g, arg.yukseklik), Image.LANCZOS)
        yol = os.path.join(arg.klasor, ad + ".png")
        kare.save(yol, optimize=True)
        print("%-34s %s" % (yol, kare.size))
    return 0


if __name__ == "__main__":
    sys.exit(main())
