extends Node

## Seviye verisi. `data/levels/levels.json` çevrimdışı olarak
## `tools/generate_levels.py` ile üretilir (rastgele değil, küratörlü).

const LEVELS_PATH := "res://data/levels/levels.json"

var _levels := {}     ## id -> Dictionary
var _ordered: Array = []


func _ready() -> void:
	_load()


func _load() -> void:
	var file := FileAccess.open(LEVELS_PATH, FileAccess.READ)
	if file == null:
		push_error("[LevelDB] Seviye dosyası açılamadı: %s" % LEVELS_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("seviyeler"):
		push_error("[LevelDB] Seviye dosyası bozuk.")
		return
	for entry in parsed["seviyeler"]:
		_levels[int(entry["id"])] = entry
		_ordered.append(entry)
	print("[LevelDB] %d seviye yüklendi." % _ordered.size())


func count() -> int:
	return _ordered.size()


func has_level(level_id: int) -> bool:
	return _levels.has(level_id)


func get_level(level_id: int) -> Dictionary:
	return _levels.get(level_id, {})


func levels_in_region(region_index: int) -> Array:
	var result: Array = []
	for entry in _ordered:
		if int(entry.get("bolge", 0)) == region_index:
			result.append(entry)
	return result


## Seviyede geçen düşman tiplerinin benzersiz listesi (önizleme ekranı için).
func enemy_types(level_id: int) -> Array:
	var seen := {}
	var order: Array = []
	for wave in get_level(level_id).get("dalgalar", []):
		for group in wave.get("gruplar", []):
			var type_id := str(group.get("tip", ""))
			if type_id != "" and not seen.has(type_id):
				seen[type_id] = true
				order.append(type_id)
	return order


## Seviyede önerilen kule tipleri: hedef kategorilerin kuleleri.
func recommended_towers(level_id: int) -> Array:
	var towers: Array = []
	for category in get_level(level_id).get("hedef_kategoriler", []):
		var tower: String = WordEngine.tower_for_category(str(category))
		if tower != "" and not towers.has(tower):
			towers.append(tower)
	return towers


func total_enemy_count(level_id: int) -> int:
	var total := 0
	for wave in get_level(level_id).get("dalgalar", []):
		for group in wave.get("gruplar", []):
			total += int(group.get("adet", 0))
	return total
