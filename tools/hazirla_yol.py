#!/usr/bin/env python3
"""Yol karosu hazırlayıcı.

2x2 karo sayfasını oyunun döşeyebileceği dört karoya ayırır.

İki iş yapar, ikisi de gerekli:
  * Sayfadaki karolar arasında beyaz ayırıcı şeritler var. Onlar karoya
    girerse yol boyunca her tekrarda beyaz çizgi çıkıyor — cömert kırpma.
  * Üretilen karo gerçekte kesintisiz değil; karşılıklı kenarlar tutmuyor ve
    her tekrarda dikiş görünüyor. Kenar bantları karşı kenarla harmanlanarak
    geçiş yumuşatılır.

Kullanım:
    python3 tools/hazirla_yol.py <sayfa> <klasor> <ad1,ad2,ad3,ad4>
"""

import argparse
import os
import sys

from PIL import Image

PAY = 60          # sayfadaki beyaz ayırıcıyı kesip atacak kadar içeriden
BOYUT = 256
BANT = 28         # kenar harmanlama bandı (piksel)
KALITE = 90


def kesintisiz(im: Image.Image, bant: int) -> Image.Image:
    """Karşılıklı kenarları harmanlayarak dikişi yumuşatır.

    Sol banda sağ kenarın devamı, üst banda alt kenarın devamı karıştırılır;
    böylece karo kendisiyle yan yana gelince kopukluk kademeli olur.
    """
    w, h = im.size
    piksel = im.load()
    kaynak = im.copy().load()

    for x in range(bant):
        agirlik = 1.0 - x / float(bant)
        for y in range(h):
            a = kaynak[x, y]
            b = kaynak[w - bant + x, y]
            piksel[x, y] = tuple(int(a[i] * (1.0 - agirlik) + b[i] * agirlik)
                                 for i in range(3))
    kaynak = im.copy().load()
    for y in range(bant):
        agirlik = 1.0 - y / float(bant)
        for x in range(w):
            a = kaynak[x, y]
            b = kaynak[x, h - bant + y]
            piksel[x, y] = tuple(int(a[i] * (1.0 - agirlik) + b[i] * agirlik)
                                 for i in range(3))
    return im


def main() -> int:
    ayrist = argparse.ArgumentParser()
    ayrist.add_argument("kaynak")
    ayrist.add_argument("klasor")
    ayrist.add_argument("adlar", help="sol üst, sağ üst, sol alt, sağ alt")
    arg = ayrist.parse_args()

    adlar = [a.strip() for a in arg.adlar.split(",")]
    if len(adlar) != 4:
        print("HATA: dört ad gerekli.", file=sys.stderr)
        return 1

    sayfa = Image.open(arg.kaynak).convert("RGB")
    w, h = sayfa.size
    os.makedirs(arg.klasor, exist_ok=True)

    for i, ad in enumerate(adlar):
        satir, sutun = divmod(i, 2)
        kutu = (sutun * w // 2 + PAY, satir * h // 2 + PAY,
                (sutun + 1) * w // 2 - PAY, (satir + 1) * h // 2 - PAY)
        karo = sayfa.crop(kutu).resize((BOYUT, BOYUT), Image.LANCZOS)
        karo = kesintisiz(karo, BANT)
        yol = os.path.join(arg.klasor, ad + ".jpg")
        karo.save(yol, quality=KALITE, optimize=True)

        # Kenar/iç parlaklık farkı beyaz şeridin kalıp kalmadığını gösterir.
        def ortalama(noktalar):
            return sum(sum(p) / 3.0 for p in noktalar) / len(noktalar)
        piksel = karo.load()
        kenar = ortalama([piksel[x, 0] for x in range(0, BOYUT, 8)]
                         + [piksel[0, y] for y in range(0, BOYUT, 8)])
        ic = ortalama([piksel[x, BOYUT // 2] for x in range(0, BOYUT, 8)])
        print("%-34s kenar %5.1f  iç %5.1f  fark %5.1f"
              % (yol, kenar, ic, abs(kenar - ic)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
