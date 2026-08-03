extends Control

## Bölüm haritası: 4 bölge × 15 seviye. Yıldız toplamı yeni bölgelerin
## kilidini açar. Kilitli seviyeler soluk gösterilir.

const TILE := 132.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.background(Color("#25324a"), Color("#12101c")))

	var margin := UiKit.margin(32)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var column := UiKit.vbox(18)
	margin.add_child(column)
	column.add_child(UiKit.top_bar("Bölüm Haritası", func(): SceneRouter.go_to("ana_menu")))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var list := UiKit.vbox(26)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var total_stars := SaveManager.total_stars()
	for region_index in GameConfig.REGIONS.size():
		list.add_child(_region_block(region_index, total_stars))


func _region_block(region_index: int, total_stars: int) -> Control:
	var region: Dictionary = GameConfig.REGIONS[region_index]
	var needed := int(region["gereken_yildiz"])
	var unlocked := total_stars >= needed
	var accent := Color(region["renk"])

	var box := UiKit.panel(UiKit.BG_PANEL, accent if unlocked else Color(0, 0, 0, 0))
	var column := UiKit.vbox(14)
	box.add_child(column)

	var header := UiKit.hbox(12)
	header.add_child(UiKit.label(str(region["ad"]), UiKit.FONT_HEAD,
		accent if unlocked else UiKit.INK_SOFT))
	header.add_child(UiKit.spacer())
	if not unlocked:
		header.add_child(UiKit.label("🔒 %d ★ gerekli" % needed, UiKit.FONT_SMALL, UiKit.INK_SOFT))
	column.add_child(header)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	column.add_child(grid)

	var first := region_index * GameConfig.LEVELS_PER_REGION + 1
	for offset in GameConfig.LEVELS_PER_REGION:
		grid.add_child(_level_tile(first + offset, unlocked, accent))
	return box


func _level_tile(level_id: int, region_unlocked: bool, accent: Color) -> Control:
	var stars := SaveManager.level_stars(level_id)
	var open := region_unlocked and SaveManager.is_level_unlocked(level_id)
	var is_boss := GameConfig.is_boss_level(level_id)

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, TILE * 0.86)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not open

	var fill := accent.lerp(UiKit.BG_PANEL_SOFT, 0.45)
	if is_boss:
		fill = UiKit.DANGER.lerp(UiKit.BG_PANEL_SOFT, 0.35)
	if not open:
		fill = UiKit.BG_PANEL_SOFT

	var style := UiKit.panel_style(fill, Color(0, 0, 0, 0), 14.0)
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("disabled", UiKit.panel_style(
		Color(0.16, 0.14, 0.22), Color(0, 0, 0, 0), 14.0))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var label := UiKit.label("", UiKit.FONT_SMALL, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if open:
		var star_text := "★".repeat(stars) + "☆".repeat(3 - stars)
		label.text = "%s\n%s%s" % [level_id, star_text, "\n👑" if is_boss else ""]
	else:
		label.text = "🔒"
		label.add_theme_color_override("font_color", UiKit.INK_SOFT)
	button.add_child(label)

	if open:
		button.pressed.connect(func():
			SceneRouter.pending_level_id = level_id
			SceneRouter.go_to("onizleme"))
	return button
