#!/usr/bin/env python3
"""Kategori tohumlarını ana sözlükle doğrulayıp data/categories/*.json üretir."""
from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from category_seeds import CATEGORY_META, PRIORITY, SEEDS
from kelime_listeleri import kategori_disi
from turkish import tr_sort_key

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MIN_LEN = 3  # oyunda en kısa kelime 3 harf


def main() -> int:
    dict_path = os.path.join(ROOT, "data", "dictionary", "tr_words.txt")
    with open(dict_path, encoding="utf-8") as handle:
        lexicon = {line.strip() for line in handle if line.strip()}

    assigned: dict[str, str] = {}
    rejected: dict[str, list[str]] = {}
    conflicts: list[tuple[str, str, str]] = []
    # Kategori kelimeleri kule enerjisi veriyor; oyuncunun aklına gelmeyecek
    # bir madde onu bulamadığı bir hedefe bağlar.
    nadir = kategori_disi()
    elenen_nadir = 0

    for category in PRIORITY:
        bad: list[str] = []
        for word in SEEDS[category]:
            if len(word) < MIN_LEN:
                continue
            if word in nadir:
                elenen_nadir += 1
                continue
            if word not in lexicon:
                bad.append(word)
                continue
            owner = assigned.get(word)
            if owner is None:
                assigned[word] = category
            elif owner != category:
                conflicts.append((word, owner, category))
        rejected[category] = bad

    print(f"  nadir olduğu için kategoriye alınmadı: {elenen_nadir}")

    out_dir = os.path.join(ROOT, "data", "categories")
    os.makedirs(out_dir, exist_ok=True)

    summary = {}
    for category in PRIORITY:
        words = sorted((w for w, c in assigned.items() if c == category), key=tr_sort_key)
        payload = {
            "kategori": category,
            "meta": CATEGORY_META[category],
            "kelime_sayisi": len(words),
            "kelimeler": words,
        }
        path = os.path.join(out_dir, f"{category}.json")
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, ensure_ascii=False, indent=1)
            handle.write("\n")
        summary[category] = len(words)
        if rejected[category]:
            print(f"  [{category}] sözlükte yok, elendi ({len(rejected[category])}): "
                  + ", ".join(rejected[category][:25])
                  + (" ..." if len(rejected[category]) > 25 else ""))

    # Motorun tek dosyadan okuyabileceği düz eşleme (kelime -> kategori).
    index_path = os.path.join(out_dir, "index.json")
    with open(index_path, "w", encoding="utf-8") as handle:
        json.dump(
            {
                "oncelik": PRIORITY,
                "meta": CATEGORY_META,
                "esleme": {w: assigned[w] for w in sorted(assigned, key=tr_sort_key)},
            },
            handle,
            ensure_ascii=False,
            indent=0,
        )
        handle.write("\n")

    if conflicts:
        print(f"  çakışma ({len(conflicts)}, öncelik sırasına göre çözüldü): "
              + ", ".join(f"{w}={o}" for w, o, _ in conflicts[:20]))
    print("  kategori boyutları:", summary, "toplam", sum(summary.values()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
