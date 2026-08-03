extends Control

## Kalıcı yükseltmeler — yalnızca altınla (soft currency) alınır.
## Elmas gerektirmez; ödeme yapan oyuncu güç avantajı kazanmaz.

var _rows := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.background(Color("#33294a"), Color("#12101c")))

	var margin := UiKit.margin(36)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var column := UiKit.vbox(18)
	margin.add_child(column)
	column.add_child(UiKit.top_bar("Yükseltmeler", func(): SceneRouter.go_to("ana_menu")))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var list := UiKit.vbox(16)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for key in GameConfig.UPGRADES:
		list.add_child(_upgrade_row(key))

	EconomyManager.upgrade_purchased.connect(func(_k, _l): _refresh())
	EconomyManager.currency_changed.connect(func(_g, _e): _refresh())
	_refresh()


func _upgrade_row(key: String) -> Control:
	var data: Dictionary = GameConfig.UPGRADES[key]
	var box := UiKit.panel(UiKit.BG_PANEL)
	var column := UiKit.vbox(10)
	box.add_child(column)

	column.add_child(UiKit.label(str(data["ad"]), UiKit.FONT_BODY, UiKit.INK))
	column.add_child(UiKit.paragraph(str(data["aciklama"])))

	var bar := UiKit.progress_bar(UiKit.GOLD, 18.0)
	column.add_child(bar)

	var row := UiKit.hbox(12)
	var level_label := UiKit.label("", UiKit.FONT_SMALL, UiKit.GOLD)
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(level_label)

	var buy := UiKit.button("", UiKit.GOLD)
	buy.custom_minimum_size = Vector2(280, UiKit.TOUCH_MIN)
	buy.pressed.connect(func():
		if EconomyManager.buy_upgrade(key):
			AudioManager.play_sfx("kule_insa"))
	row.add_child(buy)
	column.add_child(row)

	_rows[key] = {"bar": bar, "seviye": level_label, "al": buy}
	return box


func _refresh() -> void:
	for key in _rows:
		var data: Dictionary = GameConfig.UPGRADES[key]
		var level := EconomyManager.upgrade_level(key)
		var maximum := int(data["max_seviye"])
		var row: Dictionary = _rows[key]
		(row["bar"] as ProgressBar).value = float(level) / float(maximum)
		(row["seviye"] as Label).text = "Seviye %d / %d   (+%%%d)" % [
			level, maximum, roundi(EconomyManager.upgrade_bonus(key) * 100.0)]

		var button := row["al"] as Button
		var cost := EconomyManager.upgrade_cost(key)
		if cost < 0:
			button.text = "EN ÜST"
			button.disabled = true
		else:
			button.text = "%d ●" % cost
			button.disabled = EconomyManager.gold() < cost
