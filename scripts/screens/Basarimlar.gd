extends Control

## Başarımlar ve istatistikler. Play Games bağlıysa oradaki listeyi de açar.


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.background(Color("#2f2a44"), Color("#12101c")))

	var margin := UiKit.margin(36)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var column := UiKit.vbox(16)
	margin.add_child(column)
	column.add_child(UiKit.top_bar("Başarımlar", func(): SceneRouter.go_to("ana_menu"), false))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var list := UiKit.vbox(14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	list.add_child(_stats_block())

	var unlocked: Array = SaveManager.progress.get("basarimlar", [])
	list.add_child(UiKit.label("Başarımlar (%d / %d)" % [unlocked.size(),
		PlayServices.ACHIEVEMENTS.size()], UiKit.FONT_BODY, UiKit.INK))
	for id in PlayServices.ACHIEVEMENTS:
		list.add_child(_achievement_row(id, unlocked.has(id)))

	if PlayServices.is_available():
		var open := UiKit.ghost_button("Play Oyunlar'da aç")
		open.pressed.connect(func(): PlayServices.show_achievements())
		list.add_child(open)


func _stats_block() -> Control:
	var box := UiKit.panel(UiKit.BG_PANEL)
	var column := UiKit.vbox(8)
	box.add_child(column)
	column.add_child(UiKit.label("İstatistikler", UiKit.FONT_BODY, UiKit.INK))

	var stats: Dictionary = SaveManager.progress.get("istatistik", {})
	var rows := [
		["Toplam yıldız", "%d / %d" % [SaveManager.total_stars(), GameConfig.TOTAL_LEVELS * 3]],
		["Tamamlanan seviye", str(stats.get("tamamlanan_seviye", 0))],
		["Bulunan kelime", str(stats.get("bulunan_kelime", 0))],
		["Kadim kelime", str(stats.get("kadim_kelime", 0))],
		["Öldürülen düşman", str(stats.get("oldurulen_dusman", 0))],
		["En uzun kelime", TurkishText.to_upper(str(stats.get("en_uzun_kelime", "—")))],
	]
	for row in rows:
		var line := UiKit.hbox(10)
		var name_label := UiKit.label(row[0], UiKit.FONT_SMALL, UiKit.INK_SOFT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		line.add_child(UiKit.label(row[1] if row[1] != "" else "—", UiKit.FONT_SMALL, UiKit.INK))
		column.add_child(line)
	return box


func _achievement_row(id: String, unlocked: bool) -> Control:
	var data: Dictionary = PlayServices.ACHIEVEMENTS[id]
	var box := UiKit.panel(UiKit.BG_PANEL, UiKit.GOLD if unlocked else Color(0, 0, 0, 0))
	var row := UiKit.hbox(14)
	box.add_child(row)

	row.add_child(UiKit.label("🏆" if unlocked else "🔒", UiKit.FONT_HEAD,
		UiKit.GOLD if unlocked else UiKit.INK_SOFT))

	var info := UiKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiKit.label(str(data["ad"]), UiKit.FONT_SMALL,
		UiKit.INK if unlocked else UiKit.INK_SOFT))
	info.add_child(UiKit.paragraph(str(data["aciklama"]), 22))
	row.add_child(info)
	return box
