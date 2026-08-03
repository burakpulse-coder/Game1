extends Node

## Kelime motoru: sözlük doğrulama + kategori çözümleme + puanlama.
##
## Otomatik yüklenir (autoload). Sahnelerden `WordEngine.submit(...)` çağrılır.
## Tamamen çevrimdışıdır; ağ bağlantısı gerektirmez.

signal dictionary_ready

const DICT_PATH := "res://data/dictionary/tr_words.trie"
const CATEGORY_INDEX_PATH := "res://data/categories/index.json"

## Bir kelime denemesinin sonucu.
class WordResult extends RefCounted:
	var word: String = ""
	var valid: bool = false
	var category: String = ""        ## "hayvan"/"doga"/"nesne"/"yiyecek" ya da ""
	var tower_type: String = ""      ## Kategoriye karşılık gelen kule; yoksa ""
	var length_multiplier: float = 0.0
	var is_ancient: bool = false     ## 7+ harf -> Kadim Kelime
	var reason: String = ""          ## Geçersizse kullanıcıya gösterilecek sebep

	func _to_string() -> String:
		return "WordResult(%s, gecerli=%s, kategori=%s, carpan=%.1f)" % [
			word, valid, category, length_multiplier
		]


var _trie := TrieDict.new()
var _word_category := {}        ## kelime -> kategori
var _category_meta := {}        ## kategori -> {ad, kule, renk, aciklama}
var _tower_by_category := {}    ## kategori -> kule tipi
var _dict_ready := false


func _ready() -> void:
	_load_categories()
	_load_dictionary()


func _load_dictionary() -> void:
	var started := Time.get_ticks_usec()
	if _trie.load_from_file(DICT_PATH):
		_dict_ready = true
		var ms := (Time.get_ticks_usec() - started) / 1000.0
		print("[WordEngine] Sözlük yüklendi: %d kelime, %.1f ms" % [_trie.word_count(), ms])
		dictionary_ready.emit()
	else:
		push_error("[WordEngine] Sözlük yüklenemedi; kelime doğrulama devre dışı.")


func _load_categories() -> void:
	var file := FileAccess.open(CATEGORY_INDEX_PATH, FileAccess.READ)
	if file == null:
		push_error("[WordEngine] Kategori dosyası açılamadı: %s" % CATEGORY_INDEX_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[WordEngine] Kategori dosyası bozuk.")
		return
	_word_category = parsed.get("esleme", {})
	_category_meta = parsed.get("meta", {})
	for category in _category_meta:
		_tower_by_category[category] = _category_meta[category].get("kule", "")


func is_ready() -> bool:
	return _dict_ready


func word_count() -> int:
	return _trie.word_count()


func category_meta(category: String) -> Dictionary:
	return _category_meta.get(category, {})


func tower_for_category(category: String) -> String:
	return _tower_by_category.get(category, "")


func category_for_tower(tower_type: String) -> String:
	for category in _tower_by_category:
		if _tower_by_category[category] == tower_type:
			return category
	return ""


## --------------------------------------------------------------------------
## Doğrulama
## --------------------------------------------------------------------------

## Ham kullanıcı girdisini değerlendirir. Çark harflerinden oluştuğu
## LetterWheel tarafından zaten garanti edilir; burada sözlük kontrolü yapılır.
func submit(raw: String, already_found: Array = []) -> WordResult:
	var result := WordResult.new()
	var word := TurkishText.normalize(raw)
	result.word = word

	if word.length() < GameConfig.MIN_WORD_LENGTH:
		result.reason = "En az %d harf gerekli" % GameConfig.MIN_WORD_LENGTH
		return result
	if not TurkishText.is_turkish_word(word):
		result.reason = "Geçersiz harf"
		return result
	if already_found.has(word):
		result.reason = "Bu kelimeyi zaten buldun"
		return result
	if not _trie.contains(word):
		result.reason = "Sözlükte yok"
		return result

	result.valid = true
	result.category = _word_category.get(word, "")
	result.tower_type = _tower_by_category.get(result.category, "")
	result.length_multiplier = GameConfig.length_multiplier(word.length())
	result.is_ancient = word.length() >= GameConfig.ANCIENT_WORD_LENGTH
	return result


func contains(word: String) -> bool:
	return _trie.contains(TurkishText.normalize(word))


func has_prefix(prefix: String) -> bool:
	return _trie.has_prefix(TurkishText.normalize(prefix))


func category_of(word: String) -> String:
	return _word_category.get(TurkishText.normalize(word), "")


## --------------------------------------------------------------------------
## Çark analizi (seviye önizleme, ipucu, tamamlama yüzdesi)
## --------------------------------------------------------------------------

## Harf havuzundan türetilebilen tüm kelimeler (Türkçe sıralı).
func words_for_wheel(letters: Array) -> Array:
	if not _dict_ready:
		return []
	return TurkishText.sort_words(_trie.words_from_letters(letters, GameConfig.MIN_WORD_LENGTH))


## Çarkın kategori dağılımı: {"hayvan": [...], "doga": [...], ...}
func categorized_words_for_wheel(letters: Array) -> Dictionary:
	var buckets := {"hayvan": [], "doga": [], "nesne": [], "yiyecek": [], "": []}
	for word in words_for_wheel(letters):
		var category: String = _word_category.get(word, "")
		buckets[category].append(word)
	return buckets


## İpucu: henüz bulunmamış kelimelerden, tercihen istenen kategoriden,
## en kısa olanını döndürür. Bulunamazsa boş metin.
func hint(letters: Array, found: Array, preferred_category: String = "") -> String:
	var candidates := words_for_wheel(letters)
	var fallback := ""
	for word in candidates:
		if found.has(word):
			continue
		if preferred_category != "" and _word_category.get(word, "") == preferred_category:
			return word
		if fallback == "":
			fallback = word
	return fallback
