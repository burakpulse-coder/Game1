"""Türkçe metin yardımcıları (yerel ayara duyarlı büyük/küçük harf dönüşümü).

Python'un str.lower()/upper() metotları Türkçe için hatalıdır:
  "I".lower()  -> "i"   (olması gereken: "ı")
  "İ".lower()  -> "i̇"  (birleşen nokta kalır, olması gereken: "i")
  "i".upper()  -> "I"   (olması gereken: "İ")
Bu modül doğru eşlemeyi yapar.
"""

ALPHABET = "abcçdefgğhıijklmnoöprsştuüvyz"
ALPHABET_UPPER = "ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ"

_LOWER_MAP = {
    "I": "ı", "İ": "i", "Ş": "ş", "Ğ": "ğ", "Ü": "ü", "Ö": "ö", "Ç": "ç",
}
_UPPER_MAP = {
    "ı": "I", "i": "İ", "ş": "Ş", "ğ": "Ğ", "ü": "Ü", "ö": "Ö", "ç": "Ç",
}

# Unicode birleşen işaretler (yukarı nokta vb.) temizlenir.
_STRIP = "̇̀́̂̃̈"

# TDK yazımında geçen düzeltme işaretli harfler oyun alfabesine indirgenir
# ("kâğıt" -> "kağıt"). Harf çarkında düzeltme işaretli taş bulunmaz.
FOLD_MAP = {
    "â": "a", "Â": "a", "î": "i", "Î": "i", "û": "u", "Û": "u",
    "ô": "o", "Ô": "o", "ê": "e", "Ê": "e",
}


def fold_circumflex(text: str) -> str:
    return "".join(FOLD_MAP.get(ch, ch) for ch in text)

LETTER_INDEX = {ch: i for i, ch in enumerate(ALPHABET)}


def tr_lower(text: str) -> str:
    out = []
    for ch in text:
        if ch in _STRIP:
            continue
        out.append(_LOWER_MAP.get(ch, ch.lower()))
    return "".join(out)


def tr_upper(text: str) -> str:
    return "".join(_UPPER_MAP.get(ch, ch.upper()) for ch in text)


def is_pure_turkish(word: str) -> bool:
    return bool(word) and all(ch in LETTER_INDEX for ch in word)


def tr_sort_key(word: str):
    """Türk alfabesi sıralaması (a < b < c < ç < ... < ı < i < ...)."""
    return [LETTER_INDEX[ch] for ch in word]
