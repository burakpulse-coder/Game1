extends Control

## Zafer/Yenilgi ekranı. Geçiş reklamı yalnızca burada, seviye bittikten
## sonra ve 3 seviyede bir denenir — oyun ortasında asla.

var _result := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result = SceneRouter.last_result
	var win := bool(_result.get("zafer", false))
	add_child(UiKit.background(
		Color("#2c3a26") if win else Color("#3a2429"), Color("#12101c")))

	var margin := UiKit.margin(40)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var column := UiKit.vbox(20)
	margin.add_child(column)

	var bar := UiKit.hbox(14)
	bar.add_child(UiKit.spacer())
	bar.add_child(UiKit.currency_chip("altin"))
	bar.add_child(UiKit.currency_chip("elmas"))
	column.add_child(bar)

	column.add_child(UiKit.spacer(20))
	column.add_child(UiKit.title("ZAFER!" if win else "KALE DÜŞTÜ"))

	if win:
		var stars := int(_result.get("yildiz", 0))
		var star_label := UiKit.label("★".repeat(stars) + "☆".repeat(3 - stars),
			92, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		column.add_child(star_label)
	else:
		column.add_child(UiKit.paragraph("Kuleler yeterli değildi. Daha uzun kelimeler dene!",
			UiKit.FONT_BODY, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))

	column.add_child(_stats_block(win))
	column.add_child(UiKit.spacer())
	column.add_child(_actions(win))

	# Reklam denemesi ekran çizildikten sonra, oyuncuyu kesmeden yapılır.
	if win:
		AdManager.maybe_show_interstitial_after_level.call_deferred()


func _stats_block(win: bool) -> Control:
	var box := UiKit.panel(UiKit.BG_PANEL)
	var column := UiKit.vbox(8)
	box.add_child(column)

	var rows := [
		["Bulunan kelime", str(_result.get("kelime", 0))],
		["Kadim kelime", str(_result.get("kadim", 0))],
		["Öldürülen düşman", str(_result.get("oldurulen", 0))],
		["Kalan kale canı", "%%%d" % roundi(float(_result.get("can_orani", 0.0)) * 100.0)],
		["Süre", _format_time(float(_result.get("sure", 0.0)))],
	]
	if win:
		rows.append(["Kazanılan altın", "%d ●" % int(_result.get("altin", 0))])
	for row in rows:
		var line := UiKit.hbox(10)
		var name_label := UiKit.label(row[0], UiKit.FONT_SMALL, UiKit.INK_SOFT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		line.add_child(UiKit.label(row[1], UiKit.FONT_SMALL, UiKit.INK))
		column.add_child(line)
	return box


func _actions(win: bool) -> Control:
	var column := UiKit.vbox(14)
	var level_id := int(_result.get("seviye", 1))

	if win:
		var next_id := level_id + 1
		if next_id <= GameConfig.TOTAL_LEVELS and SaveManager.is_level_unlocked(next_id):
			var next_button := UiKit.button("Sonraki Seviye", UiKit.GOLD, UiKit.FONT_HEAD)
			next_button.custom_minimum_size = Vector2(0, 118)
			next_button.pressed.connect(func():
				SceneRouter.pending_level_id = next_id
				SceneRouter.go_to("onizleme"))
			column.add_child(next_button)
		elif next_id > GameConfig.TOTAL_LEVELS:
			column.add_child(UiKit.paragraph("Tüm bölgeleri tamamladın, tebrikler lordum!",
				UiKit.FONT_BODY, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		else:
			column.add_child(UiKit.paragraph("Sonraki bölge için daha çok yıldız topla.",
				UiKit.FONT_SMALL, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))

	var retry := UiKit.button("Tekrar Dene" if not win else "Tekrar Oyna", UiKit.BG_PANEL_SOFT)
	retry.add_theme_color_override("font_color", UiKit.INK)
	retry.pressed.connect(func(): SceneRouter.play_level(level_id))
	column.add_child(retry)

	var row := UiKit.hbox(14)
	var upgrade := UiKit.ghost_button("Yükseltme")
	upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade.pressed.connect(func(): SceneRouter.go_to("yukseltme"))
	row.add_child(upgrade)

	var map := UiKit.ghost_button("Haritaya Dön")
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.pressed.connect(func(): SceneRouter.go_to("harita"))
	row.add_child(map)
	column.add_child(row)
	return column


func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]
