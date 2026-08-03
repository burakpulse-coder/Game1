#!/usr/bin/env python3
"""TDK tabanlı ham kelime listesini oyunun kullandığı verilere dönüştürür.

Üretilenler:
  data/dictionary/tr_words.txt   -> temizlenmiş, sıralı düz metin liste (referans/araç amaçlı)
  data/dictionary/tr_words.trie  -> oyun içinde kullanılan sıkıştırılmış (minimal DAWG) ikili trie

Kullanım:
  python3 tools/build_dictionary.py tools/raw_tdk_list.txt
"""
from __future__ import annotations

import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from turkish import (
    ALPHABET,
    LETTER_INDEX,
    fold_circumflex,
    is_pure_turkish,
    tr_lower,
    tr_sort_key,
)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

MIN_LEN = 2
MAX_LEN = 16
NO_CHILD = 0xFFFFFFFF
MAGIC = b"KKTR"
VERSION = 1


# --------------------------------------------------------------------------
# Temizleme
# --------------------------------------------------------------------------
def clean_source(path: str) -> list[str]:
    words: set[str] = set()
    dropped = {"ozel_isim": 0, "cok_kelime": 0, "yabanci_karakter": 0, "uzunluk": 0}
    with open(path, encoding="utf-8") as handle:
        for raw in handle:
            entry = raw.strip()
            if not entry:
                continue
            # Özel isimler büyük harfle başlar; oyunda kullanılmaz.
            if entry[0] != tr_lower(entry[0]):
                dropped["ozel_isim"] += 1
                continue
            # "aba güreşi", "a / e", "kuş-bakışı" gibi çok parçalı girdiler elenir.
            if any(sep in entry for sep in (" ", "/", "-", "'", ".", ",")):
                dropped["cok_kelime"] += 1
                continue
            word = fold_circumflex(tr_lower(entry))
            if not is_pure_turkish(word):
                dropped["yabanci_karakter"] += 1
                continue
            if not (MIN_LEN <= len(word) <= MAX_LEN):
                dropped["uzunluk"] += 1
                continue
            words.add(word)
    print("  elenen:", dropped)
    return sorted(words, key=tr_sort_key)


# --------------------------------------------------------------------------
# Minimal DAWG (Daciuk artımlı inşa algoritması)
# --------------------------------------------------------------------------
class Node:
    __slots__ = ("edges", "final", "run")

    def __init__(self) -> None:
        self.edges: dict[str, "Node"] = {}
        self.final = False
        self.run = NO_CHILD

    def signature(self) -> tuple:
        return (self.final,) + tuple(
            (ch, id(child)) for ch, child in sorted(self.edges.items(), key=lambda kv: LETTER_INDEX[kv[0]])
        )


class DawgBuilder:
    def __init__(self) -> None:
        self.root = Node()
        self.register: dict[tuple, Node] = {}
        self.unchecked: list[tuple[Node, str, Node]] = []
        self.previous = ""

    def add(self, word: str) -> None:
        if tr_sort_key(word) < tr_sort_key(self.previous):
            raise ValueError(f"kelimeler sıralı gelmeli: {word!r} < {self.previous!r}")
        common = 0
        limit = min(len(word), len(self.previous))
        while common < limit and word[common] == self.previous[common]:
            common += 1
        self._minimize(common)
        node = self.unchecked[-1][2] if self.unchecked else self.root
        for ch in word[common:]:
            child = Node()
            node.edges[ch] = child
            self.unchecked.append((node, ch, child))
            node = child
        node.final = True
        self.previous = word

    def _minimize(self, down_to: int) -> None:
        while len(self.unchecked) > down_to:
            parent, ch, child = self.unchecked.pop()
            sig = child.signature()
            existing = self.register.get(sig)
            if existing is not None:
                parent.edges[ch] = existing
            else:
                self.register[sig] = child

    def finish(self) -> Node:
        self._minimize(0)
        return self.root


def collect_nodes(root: Node) -> list[Node]:
    seen: set[int] = set()
    ordered: list[Node] = []
    stack = [root]
    while stack:
        node = stack.pop()
        if id(node) in seen:
            continue
        seen.add(id(node))
        ordered.append(node)
        stack.extend(node.edges.values())
    return ordered


def serialize(root: Node, word_count: int) -> bytes:
    """Düğümleri bitişik kenar dizilerine (run) çevirip ikili biçime yazar.

    Kenar kaydı (6 bayt, little endian):
      u8  harf indeksi (Türk alfabesinde 0..28)
      u8  bayraklar   bit0 = kelime burada biter, bit1 = düğümün son kenarı
      u32 çocuk düğümün kenar dizisi başlangıcı (kenarı yoksa 0xFFFFFFFF)
    """
    nodes = [n for n in collect_nodes(root) if n.edges]
    # Kök her zaman ilk sırada olsun ki okuma tarafı sabit bir başlangıç bulsun.
    nodes.sort(key=lambda n: 0 if n is root else 1)

    cursor = 0
    for node in nodes:
        node.run = cursor
        cursor += len(node.edges)
    total_edges = cursor

    buf = bytearray()
    for node in nodes:
        items = sorted(node.edges.items(), key=lambda kv: LETTER_INDEX[kv[0]])
        for i, (ch, child) in enumerate(items):
            flags = 0
            if child.final:
                flags |= 1
            if i == len(items) - 1:
                flags |= 2
            buf += struct.pack("<BBI", LETTER_INDEX[ch], flags, child.run if child.edges else NO_CHILD)

    alphabet = ALPHABET.encode("utf-8")
    header = bytearray()
    header += MAGIC
    header += struct.pack("<HH", VERSION, len(alphabet))
    header += alphabet
    header += struct.pack("<III", total_edges, root.run if root.edges else NO_CHILD, word_count)
    # Kök düğümün de kelime sonu olabilmesi teorik olarak mümkün değil (boş kelime yok).
    return bytes(header + buf)


# --------------------------------------------------------------------------
# Doğrulama
# --------------------------------------------------------------------------
def verify(blob: bytes, words: list[str]) -> None:
    assert blob[:4] == MAGIC
    version, alpha_len = struct.unpack_from("<HH", blob, 4)
    assert version == VERSION
    off = 8 + alpha_len
    edge_count, root_run, count = struct.unpack_from("<III", blob, off)
    edges_off = off + 12
    assert count == len(words)

    def edge_at(index: int):
        return struct.unpack_from("<BBI", blob, edges_off + index * 6)

    def contains(word: str) -> bool:
        run = root_run
        for pos, ch in enumerate(word):
            if run == NO_CHILD:
                return False
            target = LETTER_INDEX.get(ch, -1)
            if target < 0:
                return False
            found = None
            i = run
            while True:
                letter, flags, child = edge_at(i)
                if letter == target:
                    found = (flags, child)
                    break
                if flags & 2:
                    break
                i += 1
            if found is None:
                return False
            flags, child = found
            if pos == len(word) - 1:
                return bool(flags & 1)
            run = child
        return False

    sample = words[:: max(1, len(words) // 4000)]
    for word in sample:
        assert contains(word), f"kayıp kelime: {word}"
    for bogus in ("zzzt", "qwerty", "kalexx", "aaaaaa", "elmaz"):
        bogus = tr_lower(bogus)
        if bogus not in set(sample):
            assert not contains(bogus) or bogus in words, f"yanlış pozitif: {bogus}"
    print(f"  doğrulama tamam ({len(sample)} örnek), kenar sayısı={edge_count}")


def main() -> int:
    source = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "tools", "raw_tdk_list.txt")
    print(f"Kaynak: {source}")
    words = clean_source(source)
    print(f"  temiz kelime: {len(words)}")

    out_dir = os.path.join(ROOT, "data", "dictionary")
    os.makedirs(out_dir, exist_ok=True)

    txt_path = os.path.join(out_dir, "tr_words.txt")
    with open(txt_path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(words))
        handle.write("\n")

    builder = DawgBuilder()
    for word in words:
        builder.add(word)
    root = builder.finish()
    blob = serialize(root, len(words))
    verify(blob, words)

    trie_path = os.path.join(out_dir, "tr_words.trie")
    with open(trie_path, "wb") as handle:
        handle.write(blob)

    print(f"  {txt_path} ({os.path.getsize(txt_path)/1024:.0f} KB)")
    print(f"  {trie_path} ({os.path.getsize(trie_path)/1024:.0f} KB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
