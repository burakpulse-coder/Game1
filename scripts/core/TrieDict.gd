class_name TrieDict
extends RefCounted

## Sıkıştırılmış (minimal DAWG) trie okuyucusu.
##
## Sözlük, `tools/build_dictionary.py` tarafından çevrimdışı olarak üretilen
## ikili dosyadan okunur. Dosya belleğe tek parça PackedByteArray olarak alınır;
## çalışma anında düğüm nesnesi oluşturulmaz. Bu sayede 58 bin kelimelik sözlük
## ~300 KB bellek kullanır ve sorgu maliyeti O(kelime uzunluğu) olur (<1 ms).
##
## İkili biçim (little endian):
##   "KKTR" | u16 sürüm | u16 alfabe_bayt | alfabe | u32 kenar | u32 kök | u32 kelime
##   ardından her biri 6 bayt olan kenar kayıtları:
##     u8 harf indeksi, u8 bayraklar (bit0: kelime burada biter, bit1: son kenar),
##     u32 çocuk düğümün kenar dizisi başlangıcı (0xFFFFFFFF = çocuk yok)

const MAGIC := "KKTR"
const EDGE_SIZE := 6
const NO_CHILD := 0xFFFFFFFF
const FLAG_TERMINAL := 1
const FLAG_LAST := 2

var _data := PackedByteArray()
var _edges_offset := 0
var _edge_count := 0
var _root := NO_CHILD
var _word_count := 0
var _loaded := false

## Alfabedeki harf -> indeks. Dosyadan okunur, TurkishText ile aynı olmalıdır.
var _letter_index := {}
var _index_letter := PackedStringArray()


func is_loaded() -> bool:
	return _loaded


func word_count() -> int:
	return _word_count


func load_from_file(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Sözlük açılamadı: %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	var blob := file.get_buffer(file.get_length())
	file.close()
	return load_from_buffer(blob)


func load_from_buffer(blob: PackedByteArray) -> bool:
	_loaded = false
	if blob.size() < 16 or blob.slice(0, 4).get_string_from_ascii() != MAGIC:
		push_error("Sözlük dosyası geçersiz (imza uyuşmuyor).")
		return false
	var version := blob.decode_u16(4)
	if version != 1:
		push_error("Desteklenmeyen sözlük sürümü: %d" % version)
		return false
	var alpha_bytes := blob.decode_u16(6)
	var alphabet := blob.slice(8, 8 + alpha_bytes).get_string_from_utf8()
	var head := 8 + alpha_bytes
	_edge_count = blob.decode_u32(head)
	_root = blob.decode_u32(head + 4)
	_word_count = blob.decode_u32(head + 8)
	_edges_offset = head + 12

	if _edges_offset + _edge_count * EDGE_SIZE > blob.size():
		push_error("Sözlük dosyası eksik/bozuk.")
		return false

	_letter_index.clear()
	_index_letter.resize(alphabet.length())
	for i in alphabet.length():
		_letter_index[alphabet[i]] = i
		_index_letter[i] = alphabet[i]

	_data = blob
	_loaded = true
	return true


## --------------------------------------------------------------------------
## Sorgular
## --------------------------------------------------------------------------

## Kelime sözlükte var mı? Girdi normalize edilmiş (küçük harf) olmalıdır.
func contains(word: String) -> bool:
	if not _loaded or word.is_empty():
		return false
	var run := _root
	var last := word.length() - 1
	for i in word.length():
		if run == NO_CHILD:
			return false
		var target: int = _letter_index.get(word[i], -1)
		if target < 0:
			return false
		var edge := _find_edge(run, target)
		if edge < 0:
			return false
		if i == last:
			return (_flags_at(edge) & FLAG_TERMINAL) != 0
		run = _child_at(edge)
	return false


## Verilen ön ekle başlayan en az bir kelime var mı?
func has_prefix(prefix: String) -> bool:
	return _run_for(prefix) != -1


## Ön ekin bittiği düğümü döndürür; yoksa -1. (Kelime sonu olması gerekmez.)
func _run_for(prefix: String) -> int:
	if not _loaded:
		return -1
	var run := _root
	if prefix.is_empty():
		return run
	for i in prefix.length():
		if run == NO_CHILD:
			return -1
		var target: int = _letter_index.get(prefix[i], -1)
		if target < 0:
			return -1
		var edge := _find_edge(run, target)
		if edge < 0:
			return -1
		run = _child_at(edge)
	return run


## Verilen harf havuzundan (her harf en fazla havuzdaki adedi kadar kullanılarak)
## türetilebilen tüm sözlük kelimelerini döndürür.
func words_from_letters(letters: Array, min_len: int = 3, max_len: int = 0) -> Array:
	var results: Array[String] = []
	if not _loaded or _root == NO_CHILD:
		return results
	var pool := {}
	for letter in letters:
		var idx: int = _letter_index.get(letter, -1)
		if idx >= 0:
			pool[idx] = int(pool.get(idx, 0)) + 1
	if max_len <= 0:
		max_len = letters.size()
	max_len = mini(max_len, letters.size())
	_collect(_root, pool, "", min_len, max_len, results)
	return results


func _collect(run: int, pool: Dictionary, prefix: String, min_len: int, max_len: int, out: Array) -> void:
	if run == NO_CHILD or prefix.length() >= max_len:
		return
	var edge := run
	while true:
		var letter := _data[_edges_offset + edge * EDGE_SIZE]
		var available: int = pool.get(letter, 0)
		if available > 0:
			var flags := _flags_at(edge)
			var word := prefix + _index_letter[letter]
			if (flags & FLAG_TERMINAL) != 0 and word.length() >= min_len:
				out.append(word)
			pool[letter] = available - 1
			_collect(_child_at(edge), pool, word, min_len, max_len, out)
			pool[letter] = available
		if (_flags_at(edge) & FLAG_LAST) != 0:
			break
		edge += 1


## --------------------------------------------------------------------------
## Kenar erişimi
## --------------------------------------------------------------------------

func _flags_at(edge: int) -> int:
	return _data[_edges_offset + edge * EDGE_SIZE + 1]


func _child_at(edge: int) -> int:
	return _data.decode_u32(_edges_offset + edge * EDGE_SIZE + 2)


## Bir düğümün kenarları harf indeksine göre artan sıralıdır (en fazla 29 kenar),
## bu yüzden hedefi geçtiğimiz anda kesilen doğrusal tarama yeterlidir.
func _find_edge(run: int, target: int) -> int:
	var edge := run
	while true:
		var letter := _data[_edges_offset + edge * EDGE_SIZE]
		if letter == target:
			return edge
		if letter > target or (_flags_at(edge) & FLAG_LAST) != 0:
			return -1
		edge += 1
	return -1
