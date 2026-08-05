extends Control

## Ayarlar: ses, müzik, titreşim, kare hızı, dil altyapısı, Play Games oturumu.


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.background(Color("#26304a"), Color("#12101c")))

	var margin := UiKit.margin(36)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var column := UiKit.vbox(18)
	margin.add_child(column)
	column.add_child(UiKit.top_bar("Ayarlar", func(): SceneRouter.go_to("ana_menu"), false))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var list := UiKit.vbox(16)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	list.add_child(_slider_row("Müzik", "muzik"))
	list.add_child(_slider_row("Ses Efektleri", "ses"))
	list.add_child(_toggle_row("Titreşim", "titresim"))
	list.add_child(_toggle_row("Tüm Bölümler (test)", "tum_bolumler", false))
	list.add_child(_fps_row())
	list.add_child(_language_row())
	list.add_child(_play_games_row())
	list.add_child(_reset_row())
	list.add_child(_about_row())


func _slider_row(title: String, key: String) -> Control:
	var box := UiKit.panel(UiKit.BG_PANEL)
	var column := UiKit.vbox(10)
	box.add_child(column)

	var header := UiKit.hbox(10)
	var name_label := UiKit.label(title, UiKit.FONT_BODY, UiKit.INK)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	var value_label := UiKit.label("", UiKit.FONT_SMALL, UiKit.GOLD)
	header.add_child(value_label)
	column.add_child(header)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(SaveManager.get_setting(key, 0.8))
	slider.custom_minimum_size = Vector2(0, 56)
	slider.value_changed.connect(func(value):
		SaveManager.set_setting(key, value)
		value_label.text = "%d%%" % roundi(value * 100.0))
	column.add_child(slider)
	value_label.text = "%d%%" % roundi(slider.value * 100.0)
	return box


func _toggle_row(title: String, key: String, default_value := true) -> Control:
	var box := UiKit.panel(UiKit.BG_PANEL)
	var row := UiKit.hbox(14)
	box.add_child(row)

	var name_label := UiKit.label(title, UiKit.FONT_BODY, UiKit.INK)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var toggle := UiKit.button("", UiKit.SUCCESS)
	toggle.custom_minimum_size = Vector2(180, UiKit.TOUCH_MIN)
	# Düğme zemini artık doku olabildiği için bg_color kullanılamıyor; açık/kapalı
	# farkı metin ve renk çarpanıyla veriliyor.
	var apply := func(value: bool):
		toggle.text = "AÇIK" if value else "KAPALI"
		toggle.modulate = Color.WHITE if value else Color(0.62, 0.62, 0.68)
	apply.call(bool(SaveManager.get_setting(key, default_value)))
	toggle.pressed.connect(func():
		var value := not bool(SaveManager.get_setting(key, default_value))
		SaveManager.set_setting(key, value)
		apply.call(value)
		if key == "titresim" and value:
			Haptics.pulse(Haptics.MEDIUM))
	row.add_child(toggle)
	return box


func _fps_row() -> Control:
	var box := UiKit.panel(UiKit.BG_PANEL)
	var column := UiKit.vbox(10)
	box.add_child(column)
	column.add_child(UiKit.label("Kare Hızı", UiKit.FONT_BODY, UiKit.INK))
	column.add_child(UiKit.paragraph(
		"Otomatik modda cihaz zorlanırsa oyun kendiliğinden 30 FPS'e düşer.", 22))

	var row := UiKit.hbox(10)
	var labels := ["Otomatik", "60 FPS", "30 FPS"]
	var buttons: Array[Button] = []
	for i in labels.size():
		var button := UiKit.ghost_button(labels[i])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.append(button)
		row.add_child(button)
	var apply := func(selected: int):
		for i in buttons.size():
			var style := buttons[i].get_theme_stylebox("normal") as StyleBoxFlat
			if style != null:
				style.bg_color = UiKit.GOLD if i == selected else UiKit.BG_PANEL_SOFT
			buttons[i].add_theme_color_override("font_color",
				UiKit.OUTLINE if i == selected else UiKit.INK_SOFT)
	for i in buttons.size():
		var index := i
		buttons[i].pressed.connect(func():
			SaveManager.set_setting("kare_hizi", index)
			apply.call(index))
	apply.call(int(SaveManager.get_setting("kare_hizi", 0)))
	column.add_child(row)
	return box


func _language_row() -> Control:
	var box := UiKit.panel(UiKit.BG_PANEL)
	var column := UiKit.vbox(6)
	box.add_child(column)
	column.add_child(UiKit.label("Dil", UiKit.FONT_BODY, UiKit.INK))
	column.add_child(UiKit.paragraph(
		"Türkçe (Kelime havuzu TDK Güncel Türkçe Sözlük tabanlıdır). "
		+ "Diğer diller için altyapı hazır; kelime listesi eklendiğinde açılacak.", 22))
	return box


func _play_games_row() -> Control:
	var box := UiKit.panel(UiKit.BG_PANEL)
	var column := UiKit.vbox(10)
	box.add_child(column)
	column.add_child(UiKit.label("Google Play Oyunlar", UiKit.FONT_BODY, UiKit.INK))

	var state := UiKit.paragraph("", 22)
	column.add_child(state)

	var row := UiKit.hbox(10)
	var sign_in := UiKit.ghost_button("Giriş Yap")
	sign_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sign_in.pressed.connect(func(): PlayServices.sign_in())
	row.add_child(sign_in)

	var achievements := UiKit.ghost_button("Başarımlar")
	achievements.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	achievements.pressed.connect(func(): PlayServices.show_achievements())
	row.add_child(achievements)
	column.add_child(row)

	var refresh := func():
		if not PlayServices.is_available():
			state.text = "Bu derlemede Play Oyunlar eklentisi yok — ilerleme yalnızca cihazda saklanıyor."
			sign_in.disabled = true
			achievements.disabled = true
		elif PlayServices.is_signed_in():
			state.text = "Giriş yapıldı. İlerlemen buluta yedekleniyor."
			sign_in.disabled = true
		else:
			state.text = "Giriş yapılmadı."
			sign_in.disabled = false
	refresh.call()
	PlayServices.sign_in_changed.connect(func(_signed): refresh.call())
	return box


func _reset_row() -> Control:
	var box := UiKit.panel(UiKit.BG_PANEL, UiKit.DANGER)
	var column := UiKit.vbox(10)
	box.add_child(column)
	column.add_child(UiKit.label("İlerlemeyi Sıfırla", UiKit.FONT_BODY, UiKit.DANGER))

	var confirm := UiKit.paragraph("Bu işlem geri alınamaz. Emin misin?", 22)
	confirm.visible = false
	column.add_child(confirm)

	var row := UiKit.hbox(10)
	var ask := UiKit.ghost_button("Sıfırla")
	ask.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ask)

	var yes := UiKit.button("Evet, sıfırla", UiKit.DANGER)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.visible = false
	row.add_child(yes)
	column.add_child(row)

	ask.pressed.connect(func():
		confirm.visible = true
		yes.visible = true
		ask.visible = false)
	yes.pressed.connect(func():
		SaveManager.reset_progress()
		SceneRouter.go_to("ana_menu"))
	return box


func _about_row() -> Control:
	var box := UiKit.panel(UiKit.BG_PANEL)
	var column := UiKit.vbox(6)
	box.add_child(column)
	column.add_child(UiKit.label("Hakkında", UiKit.FONT_BODY, UiKit.INK))
	column.add_child(UiKit.paragraph(
		"Kelime Kalesi v%s\n%d kelimelik çevrimdışı Türkçe sözlük\nGodot %s"
			% [ProjectSettings.get_setting("application/config/version", "0.0.0"),
				WordEngine.word_count(),
				Engine.get_version_info().get("string", "4.x")],
		22))
	return box
