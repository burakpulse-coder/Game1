class_name Backdrop
extends Control

## Menü ekranları için manzara arka planı.
##
## Savaş alanındaki `Scenery` katmanını yeniden kullanır: menüler de savaşla
## aynı görsel dili konuşsun diye. Yol ve kule yuvası olmadığı için süsler
## ekranın her yerine serbestçe yerleşir.
##
## Üstüne içerik geleceğinden manzara bir tül perdeyle yumuşatılır; yoksa
## panel metinleri ağaçların ve tepelerin üstünde okunmuyor.

const VEIL := Color(0.06, 0.05, 0.10, 0.55)

var _scenery: Scenery
var _region_theme := {}
var _seed := 1
var _veil: ColorRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

	_scenery = Scenery.new()
	add_child(_scenery)

	_veil = ColorRect.new()
	_veil.color = VEIL
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)

	resized.connect(_refresh)
	_refresh()


## `theme` GameConfig.REGION_THEMES girdilerinden biri. `seed_value` aynı
## ekranın her açılışta aynı görünmesini sağlar.
func setup(theme: Dictionary, seed_value: int = 1) -> void:
	_region_theme = theme
	_seed = seed_value
	_refresh()


func set_veil(strength: float) -> void:
	if _veil != null:
		_veil.color = Color(VEIL.r, VEIL.g, VEIL.b, strength)


func _refresh() -> void:
	if _scenery == null or size.x <= 0.0 or _region_theme.is_empty():
		return
	_scenery.setup(_region_theme, Rect2(Vector2.ZERO, size), [], [], _seed)
