extends Control

## Seviye önizlemesi: hangi düşmanların geleceği ve hangi kulelerin işe
## yarayacağı önceden gösterilir ki oyuncu hazırlıklı girsin.


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.background(Color("#2b2a44"), Color("#12101c")))

	var level_id := SceneRouter.pending_level_id
	var level := LevelDB.get_level(level_id)
	if level.is_empty():
		SceneRouter.go_to("harita")
		return

	var margin := UiKit.margin(36)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var column := UiKit.vbox(18)
	margin.add_child(column)
	column.add_child(UiKit.top_bar(str(level.get("ad", "Seviye")),
		func(): SceneRouter.go_to("harita")))

	var subtitle := "Seviye %d" % level_id
	if bool(level.get("boss", false)):
		subtitle += "  •  BOSS SAVAŞI"
	column.add_child(UiKit.label(subtitle, UiKit.FONT_BODY,
		UiKit.DANGER if level.get("boss", false) else UiKit.INK_SOFT))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var body := UiKit.vbox(18)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	body.add_child(_wheel_preview(level))
	body.add_child(_tower_block(level_id, level))
	body.add_child(_enemy_block(level_id))

	var start := UiKit.button("SAVAŞA BAŞLA", UiKit.GOLD, UiKit.FONT_HEAD)
	start.custom_minimum_size = Vector2(0, 120)
	start.pressed.connect(func(): SceneRouter.play_level(level_id))
	column.add_child(start)


func _wheel_preview(level: Dictionary) -> Control:
	var box := UiKit.panel(UiKit.BG_PANEL)
	var column := UiKit.vbox(10)
	box.add_child(column)

	var letters: Array = level.get("harfler", [])
	var upper: Array = []
	for letter in letters:
		upper.append(TurkishText.to_upper(str(letter)))
	column.add_child(UiKit.label("Çark harfleri", UiKit.FONT_SMALL, UiKit.INK_SOFT))
	column.add_child(UiKit.label("  ".join(upper), UiKit.FONT_HEAD, UiKit.GOLD))
	column.add_child(UiKit.paragraph(
		"Bu çarktan %d geçerli kelime türetilebilir." % int(level.get("cozum_sayisi", 0))))
	return box


func _tower_block(level_id: int, level: Dictionary) -> Control:
	var box := UiKit.panel(UiKit.BG_PANEL)
	var column := UiKit.vbox(12)
	box.add_child(column)
	column.add_child(UiKit.label("Önerilen kuleler", UiKit.FONT_BODY, UiKit.INK))

	var recommended := LevelDB.recommended_towers(level_id)
	if recommended.is_empty():
		recommended = GameConfig.TOWERS.keys()
	for tower_type in recommended:
		var config: Dictionary = GameConfig.TOWERS[tower_type]
		var category := WordEngine.category_for_tower(tower_type)
		var meta: Dictionary = WordEngine.category_meta(category)
		var row := UiKit.vbox(2)
		row.add_child(UiKit.label("%s  ←  %s kelimeleri" % [config["ad"], meta.get("ad", category)],
			UiKit.FONT_SMALL, Color(config["renk"])))
		row.add_child(UiKit.paragraph(str(config["aciklama"]), 22))
		column.add_child(row)

	var counts: Dictionary = level.get("kategori_kelimeler", {})
	var hint := []
	for category in counts:
		hint.append("%s: %d" % [WordEngine.category_meta(category).get("ad", category),
			(counts[category] as Array).size()])
	if not hint.is_empty():
		column.add_child(UiKit.paragraph("Bu çarkta bulunabilecek kategori kelimeleri — "
			+ ", ".join(hint), 22))
	return box


func _enemy_block(level_id: int) -> Control:
	var box := UiKit.panel(UiKit.BG_PANEL)
	var column := UiKit.vbox(12)
	box.add_child(column)
	column.add_child(UiKit.label("Gelecek düşmanlar", UiKit.FONT_BODY, UiKit.INK))

	for enemy_type in LevelDB.enemy_types(level_id):
		var data: Dictionary = GameConfig.ENEMIES.get(enemy_type, {})
		if data.is_empty():
			continue
		var row := UiKit.vbox(2)
		row.add_child(UiKit.label(str(data["ad"]), UiKit.FONT_SMALL, Color(data["renk"])))
		row.add_child(UiKit.paragraph(str(data.get("aciklama", "")), 22))
		column.add_child(row)

	column.add_child(UiKit.paragraph("Toplam %d düşman, %d dalga" % [
		LevelDB.total_enemy_count(level_id),
		(LevelDB.get_level(level_id).get("dalgalar", []) as Array).size(),
	], 22))
	return box
