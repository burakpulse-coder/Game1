class_name TurkishText
extends RefCounted

## Türkçe yerel ayara duyarlı metin yardımcıları.
##
## Godot'un String.to_upper()/to_lower() metotları Unicode varsayılanını kullanır
## ve Türkçe için hatalıdır:
##   "i".to_upper() -> "I"   (doğrusu "İ")
##   "I".to_lower() -> "i"   (doğrusu "ı")
## Oyunun her yerinde harf dönüşümü bu sınıf üzerinden yapılır.

const ALPHABET := "abcçdefgğhıijklmnoöprsştuüvyz"
const ALPHABET_UPPER := "ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ"

const _LOWER := {
	"I": "ı", "İ": "i", "Ş": "ş", "Ğ": "ğ", "Ü": "ü", "Ö": "ö", "Ç": "ç",
}
const _UPPER := {
	"ı": "I", "i": "İ", "ş": "Ş", "ğ": "Ğ", "ü": "Ü", "ö": "Ö", "ç": "Ç",
}
## TDK yazımındaki düzeltme işaretli harfler oyun alfabesine indirgenir.
const _FOLD := {
	"â": "a", "Â": "a", "î": "i", "Î": "i", "û": "u", "Û": "u",
	"ô": "o", "Ô": "o", "ê": "e", "Ê": "e",
}

static var _order: Dictionary = _build_order()


static func _build_order() -> Dictionary:
	var map := {}
	for i in ALPHABET.length():
		map[ALPHABET[i]] = i
	return map


static func to_lower(text: String) -> String:
	var out := ""
	for i in text.length():
		var ch := text[i]
		out += _LOWER.get(ch, ch.to_lower())
	return out


static func to_upper(text: String) -> String:
	var out := ""
	for i in text.length():
		var ch := text[i]
		out += _UPPER.get(ch, ch.to_upper())
	return out


static func fold(text: String) -> String:
	var out := ""
	for i in text.length():
		var ch := text[i]
		out += _FOLD.get(ch, ch)
	return out


## Kullanıcı girdisini sözlükte aranabilir biçime getirir.
static func normalize(text: String) -> String:
	return fold(to_lower(text.strip_edges()))


static func letter_index(ch: String) -> int:
	return _order.get(ch, -1)


static func is_turkish_word(text: String) -> bool:
	if text.is_empty():
		return false
	for i in text.length():
		if not _order.has(text[i]):
			return false
	return true


## Türk alfabesi sıralaması: a < b < c < ç < ... < h < ı < i < j ...
static func compare(a: String, b: String) -> int:
	var limit: int = mini(a.length(), b.length())
	for i in limit:
		var ia := letter_index(a[i])
		var ib := letter_index(b[i])
		if ia != ib:
			return -1 if ia < ib else 1
	if a.length() == b.length():
		return 0
	return -1 if a.length() < b.length() else 1


static func sort_words(words: Array) -> Array:
	var copy := words.duplicate()
	copy.sort_custom(func(a, b): return compare(a, b) < 0)
	return copy
