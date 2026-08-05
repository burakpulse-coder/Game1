extends Control

## Ana menü: Oyna, Yükseltme, Mağaza, Başarımlar, Ayarlar.


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Menü de savaşla aynı görsel dili konuşsun: Yeşil Vadi manzarası.
	var backdrop := Backdrop.new()
	add_child(backdrop)
	backdrop.setup(GameConfig.REGION_THEMES["yesil_vadi"], 4242)
	backdrop.set_veil(0.62)
	AudioManager.play_music("menu")

	var margin := UiKit.margin(46)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var column := UiKit.vbox(20)
	margin.add_child(column)

	var bar := UiKit.hbox(14)
	bar.add_child(UiKit.spacer())
	bar.add_child(UiKit.currency_chip("altin"))
	bar.add_child(UiKit.currency_chip("elmas"))
	column.add_child(bar)

	column.add_child(UiKit.spacer(16))

	# Başlığın üstünde kalenin kendisi: oyunun ne olduğunu tek bakışta anlatır.
	var crest: Control = preload("res://scripts/ui/MenuCrest.gd").new()
	crest.custom_minimum_size = Vector2(0, 190)
	column.add_child(crest)

	column.add_child(UiKit.title("KELİME KALESİ"))

	var stars := SaveManager.total_stars()
	column.add_child(UiKit.label("★ %d / %d yıldız" % [stars, GameConfig.TOTAL_LEVELS * 3],
		UiKit.FONT_BODY, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	column.add_child(UiKit.spacer())

	var next_level := SaveManager.highest_unlocked_level()
	var play := UiKit.button("OYNA  —  Seviye %d" % next_level, UiKit.GOLD, UiKit.FONT_HEAD)
	play.custom_minimum_size = Vector2(0, 130)
	play.pressed.connect(func():
		SceneRouter.pending_level_id = next_level
		SceneRouter.go_to("onizleme"))
	column.add_child(play)

	var map := UiKit.button("Bölüm Haritası", UiKit.BG_PANEL_SOFT)
	map.add_theme_color_override("font_color", UiKit.INK)
	map.pressed.connect(func(): SceneRouter.go_to("harita"))
	column.add_child(map)

	var row := UiKit.hbox(14)
	for entry in [["Yükseltme", "yukseltme"], ["Mağaza", "magaza"]]:
		var button := UiKit.ghost_button(entry[0])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func(): SceneRouter.go_to(entry[1]))
		row.add_child(button)
	column.add_child(row)

	var row2 := UiKit.hbox(14)
	for entry in [["Başarımlar", "basarimlar"], ["Ayarlar", "ayarlar"]]:
		var button := UiKit.ghost_button(entry[0])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func(): SceneRouter.go_to(entry[1]))
		row2.add_child(button)
	column.add_child(row2)

	column.add_child(UiKit.spacer(20))
	var footer := "%s kelimelik TDK tabanlı sözlük • çevrimdışı oynanır" % WordEngine.word_count()
	column.add_child(UiKit.paragraph(footer, 22, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
