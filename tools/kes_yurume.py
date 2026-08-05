#!/usr/bin/env python3
"""Yürüyüş şeridi kesici.

Üretilen dört kareli sayfayı (beyaz zeminli, tek sıra) oyunun kullanabileceği
eşit hücreli bir sprite şeridine çevirir.

Neden basit bir "dörde böl" yetmiyor:
  * Kareler sayfada eşit aralıklı çıkmıyor; sabit ızgara uzuvları kesiyor.
  * Karakterin boyu karelere göre birkaç piksel oynuyor; her kareyi kendi
    boyuna göre ölçeklersek oyunda karakter nefes alıyormuş gibi büyüyüp
    küçülüyor. Bu yüzden ölçek TÜM karelerden ortak hesaplanır.
  * Ayak hizası kaymışsa karakter yürürken zıplıyor. Yürüyenlerde kareler alt
    kenardan, süzülen hayalette üst kenardan hizalanır.

Kullanım:
    python3 tools/kes_yurume.py <sayfa.png> <cikti.png> [--hiza alt|ust]
"""

import argparse
import sys
from collections import deque

from PIL import Image, ImageDraw

BEYAZ_ESIK = 34        # JPEG sıkıştırması zemini tam beyaz bırakmıyor
EN_KUCUK_PARCA = 3000  # bundan küçük lekeler artık sayılır, kare değil
HEDEF_YUKSEKLIK = 256  # ekrandaki boyuta yakın; büyük doku mipmap'siz titriyor
KENAR_PAYI = 8


def zemini_sil(im: Image.Image) -> Image.Image:
    """Dışarıdan erişilebilen beyazı saydam yapar.

    Genel "beyaza yakın her piksel saydam" kuralı hayaletin beyaz gövdesini de
    silerdi; taşkın doldurma yalnızca kenardan ulaşılabilen zemini siler.
    """
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


def parcalar(im: Image.Image) -> list:
    """Saydam olmayan bölgeleri bağlantılı bileşenlere ayırır."""
    w, h = im.size
    piksel = im.load()
    etiket = bytearray(w * h)
    bulunan = []
    for sy in range(h):
        for sx in range(w):
            if piksel[sx, sy][3] < 8 or etiket[sy * w + sx]:
                continue
            etiket[sy * w + sx] = 1
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
                        if 0 <= nx < w and 0 <= ny < h and not etiket[ny * w + nx] \
                                and piksel[nx, ny][3] >= 8:
                            etiket[ny * w + nx] = 1
                            yigin.append((nx, ny))
            if sayi >= EN_KUCUK_PARCA:
                bulunan.append({"sayi": sayi, "kutu": (x0, y0, x1 + 1, y1 + 1)})
    return bulunan


def govde_merkezi(kare: Image.Image) -> float:
    """Yatay hizalama için kararlı bir merkez.

    Kutu merkezi kullanılamaz: kol ve silah sallandıkça kutu genişliyor,
    karakter yürürken sağa sola kayıyor. Bunun yerine alt yarının (bacaklar ve
    gövde) ağırlık merkezi alınır — orası kare boyunca en az oynayan bölge.
    """
    w, h = kare.size
    piksel = kare.load()
    toplam = 0.0
    agirlik = 0.0
    for y in range(int(h * 0.5), h):
        for x in range(w):
            a = piksel[x, y][3]
            if a > 40:
                toplam += x * a
                agirlik += a
    return (toplam / agirlik) if agirlik > 0 else w * 0.5


def main() -> int:
    ayrist = argparse.ArgumentParser()
    ayrist.add_argument("kaynak")
    ayrist.add_argument("cikti")
    ayrist.add_argument("--hiza", choices=["alt", "ust"], default="alt",
                        help="alt: yürüyenler (ayak hizası), ust: süzülen hayalet")
    ayrist.add_argument("--kare", type=int, default=4)
    arg = ayrist.parse_args()

    sayfa = zemini_sil(Image.open(arg.kaynak))
    bulunan = parcalar(sayfa)
    if len(bulunan) < arg.kare:
        print("HATA: %d kare bekleniyordu, %d parça bulundu."
              % (arg.kare, len(bulunan)), file=sys.stderr)
        return 1

    bulunan.sort(key=lambda p: -p["sayi"])
    bulunan = bulunan[:arg.kare]
    bulunan.sort(key=lambda p: p["kutu"][0])
    kareler = [sayfa.crop(p["kutu"]) for p in bulunan]

    # Ortak ölçek: kareler arası boy oynamasın.
    en_yuksek = max(k.height for k in kareler)
    olcek = HEDEF_YUKSEKLIK / en_yuksek
    kareler = [k.resize((max(1, round(k.width * olcek)),
                         max(1, round(k.height * olcek))), Image.LANCZOS)
               for k in kareler]

    hucre_g = max(k.width for k in kareler) + KENAR_PAYI * 2
    hucre_y = max(k.height for k in kareler) + KENAR_PAYI * 2
    serit = Image.new("RGBA", (hucre_g * arg.kare, hucre_y), (0, 0, 0, 0))

    for i, kare in enumerate(kareler):
        ox = i * hucre_g + round(hucre_g * 0.5 - govde_merkezi(kare))
        oy = hucre_y - KENAR_PAYI - kare.height if arg.hiza == "alt" else KENAR_PAYI
        serit.paste(kare, (ox, oy), kare)

    serit.save(arg.cikti, optimize=True)
    print("%s  %dx%d  hücre %dx%d  %d kare"
          % (arg.cikti, serit.width, serit.height, hucre_g, hucre_y, arg.kare))
    return 0


if __name__ == "__main__":
    sys.exit(main())
