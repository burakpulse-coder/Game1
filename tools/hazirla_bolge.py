#!/usr/bin/env python3
"""Bölge zemini hazırlayıcı.

Üretilen manzarayı savaş alanının kullanacağı boyuta indirir.

Neden ham dosya doğrudan kullanılmıyor:
  * Üretilen görsel yatay (2000x1493), savaş alanı ise cihaza göre neredeyse
    kare ile dikey arası değişiyor. Fazlalık genişlik depoda taşınmasın diye
    burada kırpılır; son kırpma yine de çalışma zamanında yapılır, çünkü
    en/boy oranı telefondan telefona değişiyor.
  * Ufuk üstte kalmalı: kırpma yatayda ortalanır ama dikeyde ÜSTTEN başlar.
  * PNG bu boyutta megabaytlarca yer tutuyor; zeminde saydamlık gerekmediği
    için JPEG hem küçük hem yeterli.

Kullanım:
    python3 tools/hazirla_bolge.py <kaynak> <cikti.jpg>
"""

import argparse
import os
import sys

from PIL import Image

# Savaş alanı en dar 16:9'da 1.06, en geniş 21:9'da 0.81 oranında. Depolanan
# görsel en genişten biraz daha geniş tutulur ki uzun telefonda kırpacak yer
# kalsın, kısa telefonda da kenar eksilmesin.
HEDEF_ORAN = 1.15
HEDEF_GENISLIK = 1500
KALITE = 86


def main() -> int:
    ayrist = argparse.ArgumentParser()
    ayrist.add_argument("kaynak")
    ayrist.add_argument("cikti")
    arg = ayrist.parse_args()

    im = Image.open(arg.kaynak).convert("RGB")
    w, h = im.size

    kirp_g = min(w, int(round(h * HEDEF_ORAN)))
    kirp_y = min(h, int(round(kirp_g / HEDEF_ORAN)))
    sol = (w - kirp_g) // 2          # yatayda ortala
    im = im.crop((sol, 0, sol + kirp_g, kirp_y))   # dikeyde üstten: ufuk kalsın

    if im.width > HEDEF_GENISLIK:
        yeni_y = max(1, round(im.height * HEDEF_GENISLIK / im.width))
        im = im.resize((HEDEF_GENISLIK, yeni_y), Image.LANCZOS)

    os.makedirs(os.path.dirname(arg.cikti) or ".", exist_ok=True)
    im.save(arg.cikti, quality=KALITE, optimize=True, progressive=True)
    print("%s  %dx%d  %.0f KB"
          % (arg.cikti, im.width, im.height, os.path.getsize(arg.cikti) / 1024))
    return 0


if __name__ == "__main__":
    sys.exit(main())
