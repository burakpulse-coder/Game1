extends Node

## Dokunsal geri bildirim. Android'de Input.vibrate_handheld() kullanılır,
## ayarlardan kapatılabilir. Diğer platformlarda sessizce yok sayılır.

const LIGHT := 18
const MEDIUM := 35
const STRONG := 70

var _enabled := true
var _supported := false


func _ready() -> void:
	_supported = OS.get_name() == "Android" or OS.get_name() == "iOS"
	SaveManager.settings_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	_enabled = bool(SaveManager.get_setting("titresim", true))


func pulse(duration_ms: int = LIGHT) -> void:
	if not _enabled or not _supported:
		return
	Input.vibrate_handheld(duration_ms)


func word_accepted() -> void:
	pulse(MEDIUM)


func word_rejected() -> void:
	pulse(LIGHT)


func tower_built() -> void:
	pulse(STRONG)


func ancient_word() -> void:
	pulse(STRONG)
