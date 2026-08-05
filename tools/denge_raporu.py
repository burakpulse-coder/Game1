#!/usr/bin/env python3
"""Denge taramasının iki profilini birleştirip okunur bir tablo yazar.

Girdi: tools/denge_taramasi.sh çıktıları (insan.txt, bot.txt).
Çıktı: bölüm bölüm sonuç + sorunlu bölümlerin sınıflandırması.

Sınıflar:
  TAMAM        iki profil de kazanıyor
  ZOR          bot kazanıyor, insan kaybediyor  -> insan için fazla zor
  BOZUK        ikisi de kaybediyor              -> matematiksel olarak sorunlu

Kullanım:
  python3 tools/denge_raporu.py /tmp/kk_denge
"""

import json
import os
import re
import sys

SATIR = re.compile(
    r"seviye=(\d+) (ZAFER|YENILGI|ZAMAN_ASIMI)"
    r"(?: yildiz=(\d+) can=%(\d+) kelime=(\d+) kadim=(\d+) oldurulen=(\d+) sure=(\d+)s)?"
)


def oku(yol):
    sonuc = {}
    if not os.path.exists(yol):
        return sonuc
    with open(yol, encoding="utf-8") as f:
        for satir in f:
            m = SATIR.search(satir)
            if not m:
                continue
            sonuc[int(m.group(1))] = {
                "zafer": m.group(2) == "ZAFER",
                "durum": m.group(2),
                "yildiz": int(m.group(3) or 0),
                "can": int(m.group(4) or 0),
                "kelime": int(m.group(5) or 0),
                "oldurulen": int(m.group(7) or 0),
                "sure": int(m.group(8) or 0),
            }
    return sonuc


def seviye_verisi():
    yol = os.path.join(os.path.dirname(__file__), "..", "data", "levels", "levels.json")
    with open(yol, encoding="utf-8") as f:
        veri = json.load(f)
    liste = veri if isinstance(veri, list) else veri.get("seviyeler", veri.get("levels"))
    cikti = {}
    for i in range(1, len(liste) + 1):
        lv = liste[i - 1] if isinstance(liste, list) else liste[str(i)]
        kat = lv.get("kategori_kelimeler", {})
        cikti[i] = {
            "harf": len(lv.get("harfler", [])),
            "cozum": len(lv.get("cozum_kelimeler", [])),
            "kategori": sum(len(kat[c]) for c in kat),
            "dalga": len(lv.get("dalgalar", [])),
        }
    return cikti


def main():
    dizin = sys.argv[1] if len(sys.argv) > 1 else "/tmp/kk_denge"
    insan = oku(os.path.join(dizin, "insan.txt"))
    bot = oku(os.path.join(dizin, "bot.txt"))
    veri = seviye_verisi()
    toplam = max(len(insan), len(bot), len(veri))

    zor, bozuk, kil_pay = [], [], []
    print(f"{'blm':>4} {'insan':>18} {'bot':>18}  {'harf':>4} {'kat':>4} {'durum'}")
    print("-" * 72)
    for i in range(1, toplam + 1):
        h = insan.get(i)
        b = bot.get(i)
        if h is None and b is None:
            continue
        if h and b:
            if h["zafer"] and b["zafer"]:
                durum = "TAMAM"
            elif b["zafer"]:
                durum = "ZOR"
                zor.append(i)
            else:
                durum = "BOZUK"
                bozuk.append(i)
        else:
            durum = "eksik"

        def yaz(r):
            if r is None:
                return "-"
            if not r["zafer"]:
                return f"{r['durum']} kel={r['kelime']} old={r['oldurulen']}"
            return f"ZAFER {r['yildiz']}* can=%{r['can']}"

        d = veri.get(i, {})
        print(f"{i:>4} {yaz(h):>18} {yaz(b):>18}  {d.get('harf', '?'):>4} "
              f"{d.get('kategori', '?'):>4} {durum}")
        if h and h["zafer"] and h["can"] <= 25:
            kil_pay.append(i)

    print()
    print(f"insan profili: {sum(1 for r in insan.values() if r['zafer'])}/{len(insan)} kazanıldı")
    print(f"bot profili  : {sum(1 for r in bot.values() if r['zafer'])}/{len(bot)} kazanıldı")
    print()
    print(f"ZOR (bot geçiyor, insan geçemiyor) [{len(zor)}]: {zor}")
    print(f"BOZUK (ikisi de geçemiyor) [{len(bozuk)}]: {bozuk}")
    print(f"kıl payı (insan kazandı ama can <= %25) [{len(kil_pay)}]: {kil_pay}")

    if zor or bozuk:
        print()
        print("sorunlu bölümlerin veri profili:")
        for i in sorted(set(zor + bozuk)):
            d = veri.get(i, {})
            print(f"  bölüm {i:>2}: {d.get('harf')} harf, {d.get('cozum')} çözüm kelimesi, "
                  f"{d.get('kategori')} kategori kelimesi, {d.get('dalga')} dalga")


if __name__ == "__main__":
    main()
