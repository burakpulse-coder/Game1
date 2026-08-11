#!/usr/bin/env python3
"""Derlenen APK/AAB'nin çalışabilir olduğunu doğrular.

Neden var: Godot yalnızca TANIDIĞI kaynak türlerini kendiliğinden paketler.
`data/dictionary/tr_words.trie` ve `.txt` Godot için kaynak değil, dolayısıyla
`include_filter` boşken hiç paketlenmiyordu — üretilen her APK sözlüksüz
çıkıyor ve cihazda hiçbir kelime doğrulanamıyordu. Masaüstünde `res://`
doğrudan diskten okunduğu için hata hiç görünmüyordu.

Bu betik derlemeden sonra çalıştırılır ve kritik veri dosyalarının paketin
içinde olduğunu doğrular.

Kullanım:
  python3 tools/paket_dogrula.py build/kelime_kalesi.apk
"""
from __future__ import annotations

import sys
import zipfile

## Bunlar olmadan oyun cihazda çalışmaz.
ZORUNLU = [
    "data/dictionary/tr_words.trie",
    "data/levels/levels.json",
    "data/categories/index.json",
]

## En az bu kadar içe aktarılmış doku paketlenmiş olmalı; yoksa sanat
## varlıkları düşmüş demektir (oyun yordamsal çizime geri düşer ve bambaşka
## görünür). Godot bunları kaynak yolunda değil, .godot/imported altında
## karma adlarla saklar — o yüzden yol değil uzantı sayılır.
MIN_DOKU = 60


def main() -> int:
    if len(sys.argv) < 2:
        print("kullanım: paket_dogrula.py <apk|aab>", file=sys.stderr)
        return 2
    path = sys.argv[1]

    try:
        archive = zipfile.ZipFile(path)
    except (OSError, zipfile.BadZipFile) as err:
        print(f"HATA: paket okunamadı: {err}", file=sys.stderr)
        return 1

    names = archive.namelist()
    eksik = []
    for gerekli in ZORUNLU:
        # APK'da varlıklar "assets/" altında, AAB'de "base/assets/" altında.
        if not any(n.endswith(gerekli) for n in names):
            eksik.append(gerekli)

    doku = sum(1 for n in names if n.endswith(".ctex"))
    boyut = sum(i.compress_size for i in archive.infolist()) / 1048576.0

    print(f"paket   : {path}  ({boyut:.1f} MB)")
    print(f"doku    : {doku}")
    for gerekli in ZORUNLU:
        print(f"  {'VAR ' if gerekli not in eksik else 'YOK '} {gerekli}")

    hata = 0
    if eksik:
        print(f"HATA: zorunlu veri dosyaları pakette yok: {', '.join(eksik)}",
              file=sys.stderr)
        hata = 1
    if doku < MIN_DOKU:
        print(f"HATA: yalnız {doku} doku paketlenmiş (en az {MIN_DOKU} bekleniyor)",
              file=sys.stderr)
        hata = 1
    if hata == 0:
        print("TAMAM: paket çalışabilir görünüyor.")
    return hata


if __name__ == "__main__":
    raise SystemExit(main())
