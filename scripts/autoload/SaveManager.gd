extends Node

## Yerel kayıt + ayarlar. Bulut kaydı PlayServices üzerinden bu dosyayı taşır.
##
## İki ayrı dosya kullanılır:
##   user://kayit.json    -> ilerleme (JSON, bulut kaydına da bu gönderilir)
##   user://ayarlar.cfg   -> cihaza özel ayarlar (ses, titreşim, kare hızı)

signal progress_changed
signal settings_changed

const SAVE_PATH := "user://kayit.json"
const SETTINGS_PATH := "user://ayarlar.cfg"
const SAVE_VERSION := 1
const AUTOSAVE_DELAY := 1.5

var progress := {}
var settings := {}

var _dirty := false
var _autosave_timer := 0.0


static func default_progress() -> Dictionary:
	return {
		"surum": SAVE_VERSION,
		"altin": 0,
		"elmas": 25,
		"seviyeler": {},            ## "3" -> {"yildiz": 2, "en_iyi_can": 0.71}
		"yukseltmeler": {},         ## "kule_gucu" -> 2
		"satin_alinanlar": [],      ## kalıcı IAP kimlikleri
		"kozmetikler": ["kale_varsayilan", "kule_varsayilan"],
		"secili_kozmetik": {"kale": "kale_varsayilan", "kule": "kule_varsayilan"},
		"basarimlar": [],
		"ipucu": {"tarih": "", "kalan": GameConfig.FREE_HINTS_PER_DAY},
		"istatistik": {
			"bulunan_kelime": 0,
			"kadim_kelime": 0,
			"oldurulen_dusman": 0,
			"tamamlanan_seviye": 0,
			"en_uzun_kelime": "",
		},
		"tutorial_tamam": [],
		"tamamlanan_seviye_sayaci": 0,  ## geçiş reklamı sayacı
		"olusturma": Time.get_datetime_string_from_system(true),
	}


static func default_settings() -> Dictionary:
	return {
		"tum_bolumler": false,
		"muzik": 0.7,
		"ses": 0.9,
		"titresim": true,
		"kare_hizi": 0,   ## 0 = otomatik, 1 = 60 FPS, 2 = 30 FPS
		"dil": "tr",
	}


func _ready() -> void:
	load_all()


func _process(delta: float) -> void:
	if not _dirty:
		return
	_autosave_timer -= delta
	if _autosave_timer <= 0.0:
		save_progress()


func _notification(what: int) -> void:
	# Uygulama arka plana alındığında ya da kapatıldığında kaybolan ilerleme olmasın.
	if what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _dirty:
			save_progress()


## --------------------------------------------------------------------------
## Yükleme / kaydetme
## --------------------------------------------------------------------------

func load_all() -> void:
	progress = _read_progress()
	settings = _read_settings()
	_normalize_hints()


func _read_progress() -> Dictionary:
	var defaults := default_progress()
	if not FileAccess.file_exists(SAVE_PATH):
		return defaults
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("[SaveManager] Kayıt okunamadı, varsayılan kullanılıyor.")
		return defaults
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[SaveManager] Kayıt bozuk, varsayılana dönülüyor.")
		return defaults
	return _migrate(parsed, defaults)


## Eksik alanları varsayılanla tamamlar; eski sürüm kayıtlarını taşır.
func _migrate(data: Dictionary, defaults: Dictionary) -> Dictionary:
	for key in defaults:
		if not data.has(key):
			data[key] = defaults[key]
	data["surum"] = SAVE_VERSION
	return data


func _read_settings() -> Dictionary:
	var values := default_settings()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return values
	for key in values:
		values[key] = cfg.get_value("ayarlar", key, values[key])
	return values


func save_progress() -> void:
	_dirty = false
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] Kayıt yazılamadı: %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(progress, "\t"))
	file.close()
	PlayServices.upload_save(progress)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in settings:
		cfg.set_value("ayarlar", key, settings[key])
	cfg.save(SETTINGS_PATH)
	settings_changed.emit()


func mark_dirty() -> void:
	_dirty = true
	_autosave_timer = AUTOSAVE_DELAY
	progress_changed.emit()


## Bulut kaydı geldiğinde: daha ileri olan kayıt kazanır.
func merge_cloud_save(cloud: Dictionary) -> bool:
	if cloud.is_empty():
		return false
	var local_score := _progress_score(progress)
	var cloud_score := _progress_score(cloud)
	if cloud_score <= local_score:
		return false
	progress = _migrate(cloud, default_progress())
	mark_dirty()
	print("[SaveManager] Bulut kaydı uygulandı (yerel=%d, bulut=%d)." % [local_score, cloud_score])
	return true


func _progress_score(data: Dictionary) -> int:
	var score := 0
	for key in data.get("seviyeler", {}):
		score += 10 + int(data["seviyeler"][key].get("yildiz", 0))
	score += int(data.get("altin", 0)) / 100
	return score


## --------------------------------------------------------------------------
## İlerleme yardımcıları
## --------------------------------------------------------------------------

func level_stars(level_id: int) -> int:
	var entry: Dictionary = progress.get("seviyeler", {}).get(str(level_id), {})
	return int(entry.get("yildiz", 0))


## Bölge açık mı? Bölüm kilidiyle AYNI anahtarı sorar.
##
## Harita bunu ayrıca kendi hesaplıyordu ve "Tüm Bölümler" ayarını bilmiyordu:
## bölümlerin kilidi açılıyor ama bölgenin üstündeki sis kalkmadığı için
## haritada yalnızca ilk bölge oynanabiliyordu.
func is_region_unlocked(region_index: int) -> bool:
	if region_index <= 0:
		return true
	if bool(get_setting("tum_bolumler", false)):
		return true
	if region_index >= GameConfig.REGIONS.size():
		return false
	return total_stars() >= int(GameConfig.REGIONS[region_index]["gereken_yildiz"])


func is_level_unlocked(level_id: int) -> bool:
	if level_id <= 1:
		return true
	# Test kolaylığı: Ayarlar'dan açılan bu anahtar tüm bölümleri erişilebilir
	# yapar. İlerleme kaydı değişmez; kapatılınca normal kilit geri gelir.
	if bool(get_setting("tum_bolumler", false)):
		return true
	if not is_region_unlocked(GameConfig.region_of_level(level_id)):
		return false
	return level_stars(level_id - 1) > 0


func record_level_result(level_id: int, stars: int, hp_ratio: float) -> bool:
	var levels: Dictionary = progress["seviyeler"]
	var key := str(level_id)
	var previous := int(levels.get(key, {}).get("yildiz", 0))
	var improved := stars > previous
	if improved or not levels.has(key):
		levels[key] = {
			"yildiz": maxi(stars, previous),
			"en_iyi_can": maxf(hp_ratio, float(levels.get(key, {}).get("en_iyi_can", 0.0))),
		}
	if previous == 0 and stars > 0:
		progress["istatistik"]["tamamlanan_seviye"] = int(progress["istatistik"]["tamamlanan_seviye"]) + 1
	mark_dirty()
	return improved


func total_stars() -> int:
	var total := 0
	for key in progress.get("seviyeler", {}):
		total += int(progress["seviyeler"][key].get("yildiz", 0))
	return total


func highest_unlocked_level() -> int:
	var best := 1
	for level_id in range(1, GameConfig.TOTAL_LEVELS + 1):
		if is_level_unlocked(level_id):
			best = level_id
	return best


func upgrade_level(key: String) -> int:
	return int(progress.get("yukseltmeler", {}).get(key, 0))


func set_upgrade_level(key: String, value: int) -> void:
	progress["yukseltmeler"][key] = value
	mark_dirty()


func has_purchase(product_id: String) -> bool:
	return progress.get("satin_alinanlar", []).has(product_id)


func add_purchase(product_id: String) -> void:
	if not has_purchase(product_id):
		progress["satin_alinanlar"].append(product_id)
		mark_dirty()


func is_tutorial_done(step: String) -> bool:
	return progress.get("tutorial_tamam", []).has(step)


func mark_tutorial_done(step: String) -> void:
	if not is_tutorial_done(step):
		progress["tutorial_tamam"].append(step)
		mark_dirty()


func unlock_achievement(id: String) -> bool:
	if progress["basarimlar"].has(id):
		return false
	progress["basarimlar"].append(id)
	mark_dirty()
	PlayServices.unlock_achievement(id)
	return true


## --------------------------------------------------------------------------
## Günlük ücretsiz ipuçları
## --------------------------------------------------------------------------

func _normalize_hints() -> void:
	var today := Time.get_date_string_from_system(true)
	var hints: Dictionary = progress.get("ipucu", {})
	if hints.get("tarih", "") != today:
		hints["tarih"] = today
		hints["kalan"] = GameConfig.FREE_HINTS_PER_DAY
		progress["ipucu"] = hints
		mark_dirty()


func free_hints_left() -> int:
	_normalize_hints()
	return int(progress["ipucu"]["kalan"])


func consume_free_hint() -> bool:
	if free_hints_left() <= 0:
		return false
	progress["ipucu"]["kalan"] = int(progress["ipucu"]["kalan"]) - 1
	mark_dirty()
	return true


## --------------------------------------------------------------------------
## Ayarlar
## --------------------------------------------------------------------------

func get_setting(key: String, fallback = null):
	return settings.get(key, fallback)


func set_setting(key: String, value) -> void:
	settings[key] = value
	save_settings()


func reset_progress() -> void:
	progress = default_progress()
	save_progress()
	progress_changed.emit()
