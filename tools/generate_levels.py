#!/usr/bin/env python3
"""60 seviyelik küratörlü seviye verisini üretir -> data/levels/levels.json

Harf çarkları rastgele değildir: her çark, sözlükten seçilen bir "kaynak kelime"nin
harflerinden oluşur ve şu ölçütleri sağlayana kadar aday çarklar elenir:

  * çarktan türetilebilen toplam geçerli kelime sayısı >= seviyeye göre eşik (8..14)
  * seviyenin hedef kategorilerinden en az N kelime türetilebilmesi
  * 7+ harfli çarklarda en az bir "Kadim Kelime" bulunabilmesi (kaynak kelimenin
    kendisi zaten bunu garanti eder)

Üretim tamamen deterministiktir; aynı girdi her zaman aynı levels.json'u verir.
"""
from __future__ import annotations

import json
import os
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from category_seeds import CATEGORY_META
from turkish import LETTER_INDEX, tr_sort_key

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MIN_WORD_LEN = 3
MAX_STORED_WORDS = 80
MAX_CANDIDATES = 2500
VOWELS = set("aeıioöuü")

REGION_IDS = ["yesil_vadi", "karanlik_orman", "buz_daglari", "ejder_kalesi"]
REGION_NAMES = ["Yeşil Vadi", "Karanlık Orman", "Buz Dağları", "Ejder Kalesi"]
REGION_BOSSES = ["boss_vadi", "boss_orman", "boss_buz", "boss_ejder"]
LEVELS_PER_REGION = 15
TOTAL_LEVELS = 60

# Düşman tiplerinin açıldığı seviyeler.
ENEMY_UNLOCK = [
    ("goblin", 1),
    ("ork", 4),
    ("zirhli_trol", 9),
    ("hayalet", 16),
    ("harf_hirsizi", 22),
]

# İlk üç seviye interaktif öğretici adımlarını taşır.
TUTORIALS = {1: "kaydirma", 2: "kule_yerlestirme", 3: "kategori_eslesmesi"}


def wheel_size_for(level_id: int) -> int:
    """5 harften başlar, 8'e kadar çıkar."""
    return 5 + min(3, (level_id - 1) // 12)


def path_count_for(level_id: int) -> int:
    if level_id >= 41:
        return 3
    if level_id >= 21:
        return 2
    return 1


def slot_count_for(paths: int) -> int:
    # Üç yollu bölümlerde savunma üç şeride bölündüğü için yuva sayısı artar;
    # 8 yuva ile üç şerit birden tutulamıyordu.
    return {1: 4, 2: 6, 3: 9}[paths]


def target_categories_for(level_id: int) -> list[str]:
    """Öğretici seviyelerde tek kategori; ilerledikçe kategori sayısı artar."""
    rotation = ["hayvan", "doga", "nesne", "yiyecek"]
    if level_id <= 3:
        return ["hayvan"]
    if level_id <= 8:
        return [rotation[(level_id - 4) % 2]]          # hayvan / doga
    if level_id <= 20:
        start = (level_id - 9) % 4
        return [rotation[start], rotation[(start + 1) % 4]]
    if level_id <= 40:
        start = (level_id - 21) % 4
        return [rotation[start], rotation[(start + 1) % 4], rotation[(start + 2) % 4]]
    return rotation


def word_threshold_for(size: int) -> int:
    return {5: 8, 6: 10, 7: 12, 8: 14}[size]


def category_threshold_for(size: int, target_count: int) -> int:
    base = {5: 4, 6: 5, 7: 6, 8: 7}[size]
    return max(3, min(base, target_count * 3))


# --------------------------------------------------------------------------
# Sözlük indeksi
# --------------------------------------------------------------------------
def mask_of(word: str) -> int:
    value = 0
    for ch in word:
        value |= 1 << LETTER_INDEX[ch]
    return value


class Lexicon:
    def __init__(self, words: list[str], categories: dict[str, str]) -> None:
        self.categories = categories
        # Çarkta en fazla 8 harf olabileceği için daha uzun kelimeler hiç aranmaz.
        self.entries = [
            (mask_of(w), Counter(w), w)
            for w in words
            if MIN_WORD_LEN <= len(w) <= 8
        ]
        self.by_length: dict[int, list[str]] = {}
        for word in words:
            self.by_length.setdefault(len(word), []).append(word)

    def solve(self, letters: str) -> list[str]:
        """Harf havuzundan türetilebilen tüm kelimeler."""
        pool = Counter(letters)
        pool_mask = mask_of(letters)
        limit = len(letters)
        found = []
        for word_mask, counts, word in self.entries:
            if len(word) > limit or (word_mask & ~pool_mask):
                continue
            for ch, need in counts.items():
                if pool[ch] < need:
                    break
            else:
                found.append(word)
        return found


# --------------------------------------------------------------------------
# Dalga tasarımı
# --------------------------------------------------------------------------
def unlocked_enemies(level_id: int) -> list[str]:
    return [name for name, unlock in ENEMY_UNLOCK if level_id >= unlock]


def build_waves(level_id: int, paths: int) -> list[dict]:
    """Seviyeye göre dalga listesi. Zorluk seviye numarasıyla düzgün artar."""
    region = (level_id - 1) // LEVELS_PER_REGION
    step = (level_id - 1) % LEVELS_PER_REGION
    is_boss = level_id % LEVELS_PER_REGION == 0
    pool = unlocked_enemies(level_id)

    wave_count = min(8, 3 + region + step // 5)
    # Düşman gücü, oyuncunun ulaşabileceği güçle birlikte artmalı. Oyuncunun
    # tavanı: kule seviyesi 2.0x, kalıcı yükseltme 1.6x, combo 2.0x.
    # 0.055'lik eğim son bölgede 4.25x'e çıkıyordu ve tam yükseltmeyle bile
    # bölüm bitirilemiyordu; 0.030 ile son bölüm 2.77x'te kalıyor.
    strength = 1.0 + 0.030 * (level_id - 1)

    waves: list[dict] = []
    for index in range(wave_count):
        groups = []
        # Her dalgada 1-3 grup; ilerledikçe çeşitlilik artar.
        variety = 1 + min(2, (index + region) // 2)
        for slot in range(variety):
            enemy = pool[(index + slot + level_id) % len(pool)]
            # Tanklar ve hırsızlar daha az sayıda gelir.
            base_count = 6 if enemy in ("goblin",) else 4
            if enemy in ("zirhli_trol", "harf_hirsizi"):
                base_count = 2
            count = base_count + index // 2 + region
            groups.append({
                "tip": enemy,
                "adet": count,
                "aralik": round(max(0.45, 1.25 - 0.05 * index - 0.05 * region), 2),
                "yol": slot % paths,
                "guc": round(strength, 3),
            })
        waves.append({
            "gecikme": 3.0 if index == 0 else 0.0,  # 0 => dalga arası mola kullanılır
            "gruplar": groups,
        })

    if is_boss:
        waves.append({
            "gecikme": 0.0,
            "boss": True,
            "gruplar": [{
                "tip": REGION_BOSSES[region],
                "adet": 1,
                "aralik": 1.0,
                "yol": 0,
                "guc": round(1.0 + 0.022 * (level_id - 1), 3),
            }],
        })
    return waves


# --------------------------------------------------------------------------
# Çark seçimi
# --------------------------------------------------------------------------
def pick_wheel(lex: Lexicon, level_id: int, size: int, targets: list[str],
               used: set[str], need_cat: int):
    """Ölçütleri sağlayan en uygun çarkı seçer. Deterministik: adaylar sıralı gezilir."""
    need_words = word_threshold_for(size)

    sources = lex.by_length.get(size, [])
    # Deterministik ama seviyeler arası çeşitli bir başlangıç noktası.
    start = (level_id * 733) % max(1, len(sources))
    order = sources[start:] + sources[:start]

    best = None
    evaluated = 0
    for source in order:
        if evaluated >= MAX_CANDIDATES:
            break
        letters = "".join(sorted(source, key=lambda c: LETTER_INDEX[c]))
        if letters in used:
            continue
        # Aynı harften üç ya da daha fazla olan çarklar sıkıcı olur.
        if max(Counter(letters).values()) > 2:
            continue
        # Sesli harfsiz ya da tek sesli harfli çarklardan kelime türetilemez.
        if sum(1 for ch in set(letters) if ch in VOWELS) < 2:
            continue
        evaluated += 1
        solution = lex.solve(source)
        if len(solution) < need_words:
            continue
        cat_words = {c: [] for c in targets}
        for word in solution:
            category = lex.categories.get(word, "")
            if category in cat_words:
                cat_words[category].append(word)
        total_cat = sum(len(v) for v in cat_words.values())
        if total_cat < need_cat:
            continue
        # Her hedef kategoriden en az bir kelime bulunabilmeli.
        if any(len(v) == 0 for v in cat_words.values()):
            continue
        # Kaynak kelimenin kendisi tematikse (hedef kategoride) çark daha anlamlı olur.
        thematic = 6 if lex.categories.get(source, "") in targets else 0
        score = total_cat * 4 + min(len(solution), 45) + thematic
        if best is None or score > best[0]:
            best = (score, source, letters, solution, cat_words)
            if total_cat >= need_cat + 5 and thematic:
                break
    return best


def main() -> int:
    with open(os.path.join(ROOT, "data", "dictionary", "tr_words.txt"), encoding="utf-8") as handle:
        words = [line.strip() for line in handle if line.strip()]
    with open(os.path.join(ROOT, "data", "categories", "index.json"), encoding="utf-8") as handle:
        categories = json.load(handle)["esleme"]

    lex = Lexicon(words, categories)
    print(f"  aranabilir kelime (3-8 harf): {len(lex.entries)}")

    used_wheels: set[str] = set()
    levels = []
    relaxed = 0

    for level_id in range(1, TOTAL_LEVELS + 1):
        region = (level_id - 1) // LEVELS_PER_REGION
        size = wheel_size_for(level_id)
        targets = target_categories_for(level_id)
        paths = path_count_for(level_id)

        # Gevşetme merdiveni: önce tam ölçüt, sonra sırayla kategori eşiği ve
        # hedef kategori sayısı düşürülerek denenir. Her seviyede mutlaka bir
        # çark bulunur, ama hangi seviyelerin gevşetildiği raporlanır.
        pick = None
        ladder = []
        full_need = category_threshold_for(size, len(targets))
        for need in range(full_need, 2, -1):
            ladder.append((targets, need))
        for count in range(len(targets) - 1, 0, -1):
            ladder.append((targets[:count], max(3, category_threshold_for(size, count) - 1)))
        for index, (try_targets, need) in enumerate(ladder):
            pick = pick_wheel(lex, level_id, size, try_targets, used_wheels, need)
            if pick is not None:
                targets = try_targets
                if index > 0:
                    relaxed += 1
                break
        if pick is None:
            raise SystemExit(f"Seviye {level_id} için uygun çark bulunamadı.")

        _score, source, letters, solution, cat_words = pick
        used_wheels.add(letters)
        solution = sorted(solution, key=tr_sort_key)

        wheel_letters = sorted(source, key=lambda c: LETTER_INDEX[c])
        entry = {
            "id": level_id,
            "bolge": region,
            "bolge_id": REGION_IDS[region],
            "ad": "%s %d" % (REGION_NAMES[region], (level_id - 1) % LEVELS_PER_REGION + 1),
            "harfler": wheel_letters,
            "kaynak_kelime": source,
            "hedef_kategoriler": targets,
            "cozum_kelimeler": solution[:MAX_STORED_WORDS],
            "cozum_sayisi": len(solution),
            "kategori_kelimeler": {c: sorted(v, key=tr_sort_key)[:20] for c, v in cat_words.items()},
            "yol_sayisi": paths,
            "slot_sayisi": slot_count_for(paths),
            "kale_can_carpani": round(1.0 + 0.012 * (level_id - 1), 3),
            "dalgalar": build_waves(level_id, paths),
            "boss": level_id % LEVELS_PER_REGION == 0,
        }
        if level_id in TUTORIALS:
            entry["ogretici"] = TUTORIALS[level_id]
        levels.append(entry)

    out_path = os.path.join(ROOT, "data", "levels", "levels.json")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as handle:
        json.dump({"surum": 1, "seviye_sayisi": len(levels), "seviyeler": levels},
                  handle, ensure_ascii=False, indent=1)
        handle.write("\n")

    solved = [entry["cozum_sayisi"] for entry in levels]
    cat_totals = [sum(len(v) for v in entry["kategori_kelimeler"].values()) for entry in levels]
    print(f"  {len(levels)} seviye yazıldı -> {out_path} ({os.path.getsize(out_path)/1024:.0f} KB)")
    print(f"  çarkta türetilebilen kelime: min={min(solved)} ort={sum(solved)/len(solved):.1f} maks={max(solved)}")
    print(f"  hedef kategoriden kelime:    min={min(cat_totals)} ort={sum(cat_totals)/len(cat_totals):.1f}")
    if relaxed:
        print(f"  {relaxed} seviyede hedef kategori sayısı gevşetildi")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
