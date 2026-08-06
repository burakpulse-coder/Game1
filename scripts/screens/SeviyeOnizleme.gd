extends Control

## Seviye önizlemesi: hangi düşmanların geleceği ve hangi kulelerin işe
## yarayacağı önceden gösterilir ki oyuncu hazırlıklı girsin.


var _booster_toggles := {}
var _booster_hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var level_id := SceneRouter.pending_level_id
	var backdrop := Backdrop.new()
	add_child(backdrop)
	backdrop.setup(GameConfig.theme_of_level(level_id), level_id * 97)
	backdrop.set_veil(0.66)
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

	body.add_child(_booster_block())
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

	column.add_child(UiKit.label("Çark harfleri", UiKit.FONT_SMALL, UiKit.INK_SOFT))
	# Harfleri düz metin yerine oyundaki rün taşlarıyla göster.
	var stones := UiKit.hbox(8)
	stones.alignment = BoxContainer.ALIGNMENT_CENTER
	for letter in level.get("harfler", []):
		stones.add_child(ArtIcon.stone(str(letter), 84.0))
	column.add_child(stones)
	# Sayı yaygın kelimelerden: sözlükteki her maddeyi saymak yanıltıcı.
	# Bir çarktan 190 kelime "türetilebilir" ama bunların yarıdan çoğu ağız ya
	# da eskimiş; oyuncuya ulaşamayacağı bir hedef göstermek istemiyoruz.
	var hedef := int(level.get("yaygin_sayisi", 0))
	if hedef <= 0:
		hedef = int(level.get("cozum_sayisi", 0))
	column.add_child(UiKit.paragraph(
		"Bu çarktan %d kelime bulmanı bekliyoruz." % hedef))
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
		var row := UiKit.hbox(12)
		row.add_child(ArtIcon.tower(tower_type, 2, 88.0))
		var text := UiKit.vbox(2)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		text.add_child(UiKit.label("%s  ←  %s kelimeleri" % [config["ad"], meta.get("ad", category)],
			UiKit.FONT_SMALL, Color(config["renk"])))
		text.add_child(UiKit.paragraph(str(config["aciklama"]), 22))
		row.add_child(text)
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
		var row := UiKit.hbox(12)
		row.add_child(ArtIcon.enemy(enemy_type, 88.0))
		var text := UiKit.vbox(2)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		text.add_child(UiKit.label(str(data["ad"]), UiKit.FONT_SMALL, Color(data["renk"])))
		text.add_child(UiKit.paragraph(str(data.get("aciklama", "")), 22))
		row.add_child(text)
		column.add_child(row)

	column.add_child(UiKit.paragraph("Toplam %d düşman, %d dalga" % [
		LevelDB.total_enemy_count(level_id),
		(LevelDB.get_level(level_id).get("dalgalar", []) as Array).size(),
	], 22))
	return box


## --------------------------------------------------------------------------
## Bölüm öncesi destekler
## --------------------------------------------------------------------------
##
## Savaşa girmeden takılır; savaş başlarken envanterden düşer. Rakiplerde
## (Royal Match, Toon Blast, Kingdom Rush) bölüm öncesi destek seçimi
## standart — oyuncu zorlandığı bölümde kendi kararıyla güç ekler.
func _booster_block() -> Control:
	var box := UiKit.panel(UiKit.BG_PANEL)
	var column := UiKit.vbox(10)
	box.add_child(column)

	var head := UiKit.hbox(10)
	column.add_child(head)
	var title := UiKit.label("Destekler", UiKit.FONT_BODY, UiKit.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_booster_hint = UiKit.label("", UiKit.FONT_SMALL, UiKit.INK_SOFT)
	head.add_child(_booster_hint)

	var elde_var := false
	for id in EconomyManager.boosters_of_kind("oncesi"):
		if EconomyManager.booster_count(str(id)) > 0:
			elde_var = true
		column.add_child(_booster_row(str(id)))

	if not elde_var:
		column.add_child(UiKit.paragraph(
			"Elinde bölüm öncesi destek yok. Mağazadan elmasla alabilir ya da "
			+ "bölüm ödülleriyle kazanabilirsin.", 22))
		var shop := UiKit.ghost_button("Mağazaya git")
		shop.pressed.connect(func(): SceneRouter.go_to("magaza"))
		column.add_child(shop)
	_refresh_boosters()
	return box


func _booster_row(booster_id: String) -> Control:
	var data: Dictionary = GameConfig.BOOSTERS[booster_id]
	var row := UiKit.hbox(12)
	row.add_child(ArtIcon.booster(str(data.get("simge", "")), 56.0))

	var info := UiKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiKit.label(str(data["ad"]), UiKit.FONT_SMALL, UiKit.INK))
	info.add_child(UiKit.paragraph(str(data["aciklama"]), 20))
	row.add_child(info)

	var toggle := UiKit.ghost_button("")
	toggle.custom_minimum_size = Vector2(180, UiKit.TOUCH_MIN)
	toggle.pressed.connect(func():
		EconomyManager.toggle_equipped_booster(booster_id)
		_refresh_boosters())
	row.add_child(toggle)

	_booster_toggles[booster_id] = toggle
	return row


func _refresh_boosters() -> void:
	var secili := EconomyManager.equipped_boosters()
	for booster_id in _booster_toggles:
		var button := _booster_toggles[booster_id] as Button
		var adet := EconomyManager.booster_count(str(booster_id))
		if secili.has(booster_id):
			button.text = "TAKILI"
			button.disabled = false
		elif adet <= 0:
			button.text = "YOK"
			button.disabled = true
		else:
			button.text = "TAK (x%d)" % adet
			button.disabled = false
	if _booster_hint != null:
		_booster_hint.text = "%d / %d" % [secili.size(), GameConfig.MAX_PRE_BOOSTERS]
