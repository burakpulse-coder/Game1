class_name Hud
extends Control

## Oyun içi arayüz. Ekran üç bölgeye ayrılır ve HUD savaş alanının üstüne
## taşmaz:
##   üst şerit          : duraklat, kale canı, dalga bilgisi
##   orta şerit (bant)  : kule inşa göstergeleri, combo, kelime, düğmeler
##   alt                : harf çarkı (Battle tarafından yerleştirilir)
##
## Orta şerit `set_band()` ile savaş alanı ile çarkın arasına konumlandırılır.

signal pause_pressed
signal hint_pressed
signal shuffle_pressed
signal ulti_pressed

const METER_MIN_WIDTH := 150.0
const TOAST_SECONDS := 1.6

var _top: VBoxContainer
var _band: VBoxContainer
var _hp_bar: ProgressBar
var _hp_label: Label
var _wave_label: Label
var _combo_label: Label
var _word_label: Label
var _found_label: Label
var _break_label: Label
var _ulti_button: Button
var _hint_button: Button
var _meters := {}
var _toast: Label
var _toast_root: Control
var _toast_timer := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top()
	_build_band()
	_build_toast()
	set_process(true)


## Orta şeridi ekranın `top`..`bottom` oranları arasına yerleştirir.
func set_band(top_ratio: float, bottom_ratio: float) -> void:
	_band.anchor_top = top_ratio
	_band.anchor_bottom = bottom_ratio
	_band.offset_top = 6
	_band.offset_bottom = -6


## --------------------------------------------------------------------------
## Üst şerit
## --------------------------------------------------------------------------

func _build_top() -> void:
	# Yazılar açık gökyüzünün üstünde de okunsun diye önce karartma şeridi.
	add_child(UiKit.scrim(260.0, 0.55))

	_top = UiKit.vbox(8)
	_top.anchor_right = 1.0
	_top.offset_left = 24
	_top.offset_right = -24
	_top.offset_top = 24
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top)

	var row := UiKit.hbox(14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(row)

	var pause := UiKit.ghost_button("॥")
	pause.custom_minimum_size = Vector2(88, 88)
	pause.pressed.connect(func(): pause_pressed.emit())
	row.add_child(pause)

	var hp_box := UiKit.vbox(4)
	hp_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar = UiKit.progress_bar(UiKit.SUCCESS, 26.0)
	_hp_bar.value = 1.0
	_hp_label = UiKit.label("Kale 100 / 100", 24, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, false)
	hp_box.add_child(_hp_bar)
	hp_box.add_child(_hp_label)
	row.add_child(hp_box)

	_wave_label = UiKit.label("Dalga 1/3", 26, UiKit.INK, HORIZONTAL_ALIGNMENT_RIGHT, false)
	_wave_label.custom_minimum_size = Vector2(170, 0)
	_wave_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_wave_label)

	_break_label = UiKit.label("", 30, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER, false)
	_top.add_child(_break_label)


## --------------------------------------------------------------------------
## Orta şerit
## --------------------------------------------------------------------------

func _build_band() -> void:
	_band = UiKit.vbox(8)
	_band.anchor_right = 1.0
	_band.anchor_top = 0.56
	_band.anchor_bottom = 0.68
	_band.offset_left = 18
	_band.offset_right = -18
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band)

	# Kule inşa göstergeleri
	var meters := UiKit.hbox(10)
	meters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.add_child(meters)
	for tower_type in GameConfig.TOWERS:
		meters.add_child(_make_meter(tower_type))

	# Combo + kelime önizlemesi + bulunan kelime sayısı
	var status := UiKit.hbox(12)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.add_child(status)

	_combo_label = UiKit.label("", 24, UiKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT, false)
	_combo_label.custom_minimum_size = Vector2(260, 0)
	status.add_child(_combo_label)

	_word_label = UiKit.label("", 42, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, false)
	_word_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(_word_label)

	_found_label = UiKit.label("0 kelime", 24, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_RIGHT, false)
	_found_label.custom_minimum_size = Vector2(200, 0)
	status.add_child(_found_label)

	# Düğmeler
	var actions := UiKit.hbox(12)
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.add_child(actions)

	_hint_button = UiKit.ghost_button("İpucu")
	_hint_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_button.pressed.connect(func(): hint_pressed.emit())
	actions.add_child(_hint_button)

	var shuffle := UiKit.ghost_button("Karıştır")
	shuffle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shuffle.pressed.connect(func(): shuffle_pressed.emit())
	actions.add_child(shuffle)

	_ulti_button = UiKit.button("Kadim Büyü", UiKit.GOLD)
	_ulti_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ulti_button.disabled = true
	_ulti_button.pressed.connect(func(): ulti_pressed.emit())
	actions.add_child(_ulti_button)


func _make_meter(tower_type: String) -> Control:
	var config: Dictionary = GameConfig.TOWERS[tower_type]
	var color := Color(config["renk"])
	var box := UiKit.panel(UiKit.BG_PANEL_SOFT)
	box.custom_minimum_size = Vector2(METER_MIN_WIDTH, 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := box.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 10
		style.content_margin_bottom = 10

	var column := UiKit.vbox(5)
	# Kısa ad: "Okçu Kulesi" -> "Okçu" (dar göstergede satır kırılmasın)
	var short_name := str(config["ad"]).split(" ")[0]
	column.add_child(UiKit.label(short_name, 24, color, HORIZONTAL_ALIGNMENT_CENTER, false))
	var bar := UiKit.progress_bar(color, 14.0)
	column.add_child(bar)
	var state := UiKit.label("", 20, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER, false)
	column.add_child(state)
	box.add_child(column)

	_meters[tower_type] = {"kok": box, "bar": bar, "etiket": state}
	return box


func _build_toast() -> void:
	# Bildirim, metnin genişliği kadar bir "hap" olarak ortalanır; tam genişlikte
	# siyah şerit savaş alanını gereksiz yere kapatıyordu.
	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_top = 0.30
	center.anchor_bottom = 0.30
	center.offset_left = 24
	center.offset_right = -24
	center.offset_bottom = 78
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var pill := UiKit.panel(Color(0.06, 0.05, 0.10, 0.78))
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(pill)

	_toast = UiKit.label("", 34, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	pill.add_child(_toast)
	_toast_root = center
	_toast_root.modulate.a = 0.0


## --------------------------------------------------------------------------
## Güncellemeler
## --------------------------------------------------------------------------

func set_health(current: float, maximum: float) -> void:
	var ratio := clampf(current / maxf(maximum, 0.001), 0.0, 1.0)
	_hp_bar.value = ratio
	_hp_label.text = "Kale %d / %d" % [ceili(current), ceili(maximum)]
	var fill := _hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		fill.bg_color = UiKit.SUCCESS.lerp(UiKit.DANGER, 1.0 - ratio)


func set_wave(index: int, total: int, is_boss: bool) -> void:
	if is_boss:
		_wave_label.text = "BOSS"
		_wave_label.add_theme_color_override("font_color", UiKit.DANGER)
	else:
		_wave_label.text = "Dalga %d/%d" % [index + 1, total]
		_wave_label.add_theme_color_override("font_color", UiKit.INK)


func set_break(seconds: float) -> void:
	_break_label.text = "" if seconds <= 0.0 else "Sonraki dalga: %d" % ceili(seconds)


func set_word(word: String) -> void:
	_word_label.text = TurkishText.to_upper(word)


func set_combo(count: int, bonus: float) -> void:
	_combo_label.text = "" if count < 2 else "Combo x%d  +%%%d" % [count, roundi(bonus * 100.0)]


func set_found_count(count: int) -> void:
	_found_label.text = "%d kelime" % count


func set_meter(tower_type: String, points: float, threshold: float, ready: bool) -> void:
	if not _meters.has(tower_type):
		return
	var meter: Dictionary = _meters[tower_type]
	var bar := meter["bar"] as ProgressBar
	bar.value = clampf(points / maxf(threshold, 0.001), 0.0, 1.0)
	var label := meter["etiket"] as Label
	if ready:
		label.text = "HAZIR"
		label.add_theme_color_override("font_color", UiKit.GOLD)
	else:
		label.text = "%d%%" % roundi(bar.value * 100.0)
		label.add_theme_color_override("font_color", UiKit.INK_SOFT)


func set_ulti(charge: float) -> void:
	var ready := charge >= 1.0
	_ulti_button.disabled = not ready
	_ulti_button.text = "Kadim Büyü" if ready else "Kadim %d%%" % roundi(charge * 100.0)


func set_hint_label(free_left: int) -> void:
	_hint_button.text = "İpucu (%d)" % free_left if free_left > 0 \
		else "İpucu ◆%d" % GameConfig.HINT_GEM_COST


func toast(message: String, color: Color = UiKit.INK) -> void:
	_toast.text = message
	_toast.add_theme_color_override("font_color", color)
	_toast_root.modulate.a = 1.0
	_toast_timer = TOAST_SECONDS


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.5:
			_toast_root.modulate.a = maxf(0.0, _toast_timer / 0.5)
