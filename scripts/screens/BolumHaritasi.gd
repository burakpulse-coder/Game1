extends Control

## Bölüm haritası ekranı. Harita çizimi ve dokunma isabeti KingdomMap'te;
## bu ekran yalnızca çerçeveyi (üst çubuk, kaydırma, toplam yıldız) kurar ve
## açılışta oyuncunun sıradaki bölümüne kaydırır.

var _scroll: ScrollContainer
var _map: KingdomMap


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.background(Color("#1e2740"), Color("#12101c")))

	var column := UiKit.vbox(0)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(column)

	# Üst çubuk haritanın üstünde durur; harita altında kayar.
	var header := UiKit.margin(28)
	header.add_theme_constant_override("margin_bottom", 10)
	var bar := UiKit.top_bar("Bölüm Haritası", func(): SceneRouter.go_to("ana_menu"))
	header.add_child(bar)
	column.add_child(header)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)

	_map = KingdomMap.new()
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.level_selected.connect(_on_level_selected)
	_scroll.add_child(_map)

	# Oyuncu haritayı açınca sıradaki bölümünü görsün, en baştan aramasın.
	_focus_current.call_deferred()


func _focus_current() -> void:
	await get_tree().process_frame
	if is_instance_valid(_scroll) and is_instance_valid(_map):
		_scroll.scroll_vertical = int(_map.focus_offset(_scroll.size.y))


func _on_level_selected(level_id: int) -> void:
	SceneRouter.pending_level_id = level_id
	SceneRouter.go_to("onizleme")
