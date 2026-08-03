extends Node

## Görsel doğrulama aracı: her ekranı sırayla yükleyip PNG olarak kaydeder.
##
## Çalıştırma (sanal ekranla):
##   xvfb-run -a godot --path . --resolution 540x960 scenes/EkranGoruntusu.tscn
##
## Çıktılar user://ekran_goruntuleri/ altına yazılır. Yordamsal çizimlerin
## (kale, kule, düşman, harf çarkı) gerçekten beklendiği gibi göründüğünü
## gözle denetlemek için kullanılır.

const OUT_DIR := "user://ekran_goruntuleri"

## [dosya adı, sahne, oturum hazırlığı]
var _shots := [
	["01_acilis", "res://scenes/Acilis.tscn", ""],
	["02_ana_menu", "res://scenes/AnaMenu.tscn", ""],
	["03_harita", "res://scenes/BolumHaritasi.tscn", "ilerleme"],
	["04_onizleme", "res://scenes/SeviyeOnizleme.tscn", "seviye4"],
	["05_oyun_baslangic", "res://scenes/Oyun.tscn", "seviye4"],
	["06_oyun_savas", "res://scenes/Oyun.tscn", "savas"],
	["07_oyun_boss", "res://scenes/Oyun.tscn", "boss"],
	["08_sonuc", "res://scenes/SonucEkrani.tscn", "zafer"],
	["09_yukseltme", "res://scenes/YukseltmeEkrani.tscn", "zengin"],
	["10_magaza", "res://scenes/Magaza.tscn", "zengin"],
	["11_ayarlar", "res://scenes/Ayarlar.tscn", ""],
	["12_basarimlar", "res://scenes/Basarimlar.tscn", "ilerleme"],
]

var _current: Node = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for shot in _shots:
		await _capture(str(shot[0]), str(shot[1]), str(shot[2]))
	print("Ekran görüntüleri: %s" % ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit()


func _capture(name: String, scene_path: String, setup: String) -> void:
	_prepare(setup)

	if _current != null:
		_current.queue_free()
		await get_tree().process_frame
	var scene: PackedScene = load(scene_path)
	_current = scene.instantiate()
	add_child(_current)
	await get_tree().process_frame
	await get_tree().process_frame

	if setup == "savas" or setup == "boss":
		await _simulate_battle(setup == "boss")

	# Çizimin tamamlanması için birkaç kare bekle.
	for i in 4:
		await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, name]
	image.save_png(path)
	print("  %s (%dx%d)" % [name, image.get_width(), image.get_height()])


func _prepare(setup: String) -> void:
	match setup:
		"ilerleme":
			for level_id in range(1, 20):
				SaveManager.record_level_result(level_id, 2 + level_id % 2, 0.7)
		"seviye4":
			SceneRouter.pending_level_id = 4
		"savas":
			SceneRouter.pending_level_id = 8
		"boss":
			SceneRouter.pending_level_id = 15
		"zengin":
			EconomyManager.add_gold(5000)
			EconomyManager.add_gems(500)
		"zafer":
			SceneRouter.last_result = {
				"zafer": true, "seviye": 4, "yildiz": 3, "altin": 138,
				"kelime": 11, "kadim": 1, "oldurulen": 24, "can_orani": 0.87,
				"ilk_gecis": true, "sure": 96.0,
			}


## Ekran görüntüsü için savaşı ileri sarar: kelimeler gönderip kule diker,
## düşman doğurur ve birkaç saniye simüle eder.
func _simulate_battle(boss: bool) -> void:
	var battle := _current
	var level := LevelDB.get_level(SceneRouter.pending_level_id)

	# Kategori kelimeleriyle birkaç kule dik.
	# Önce kategori kelimeleri (kule tipini belirlerler), sonra çarkın diğer
	# kelimeleri — üç kule dikecek kadar inşa puanı biriksin.
	var words: Array = []
	for category in level.get("kategori_kelimeler", {}):
		for word in level["kategori_kelimeler"][category]:
			words.append(str(word))
	for word in level.get("cozum_kelimeler", []):
		if not words.has(str(word)):
			words.append(str(word))
	var built := 0
	for word in words:
		battle._on_word_submitted(word)
		for slot in battle.battlefield.slots:
			if slot.is_empty() and battle.towers.build_on(slot):
				built += 1
				break
		if built >= 3:
			break

	# Kuleleri seviye atlat ki farklı görseller görünsün.
	var towers: Array = battle.battlefield.towers()
	if towers.size() > 1:
		(towers[1] as Tower).upgrade()
	if towers.size() > 2:
		(towers[2] as Tower).upgrade()
		(towers[2] as Tower).upgrade()

	# Düşman kadrosu doğur ve yol boyunca yay.
	var roster := ["goblin", "ork", "zirhli_trol", "hayalet", "harf_hirsizi"]
	if boss:
		roster = ["boss_vadi", "goblin", "goblin", "ork", "zirhli_trol"]
	for i in roster.size():
		var enemy: Enemy = battle.battlefield.spawn_enemy(roster[i], i % battle.battlefield.tracks.size(), 1.0)
		if enemy != null:
			enemy.distance = enemy.track.length() * (0.25 + 0.11 * i)
			enemy.take_damage(enemy.max_hp * 0.3, "ulti")  # can çubukları görünsün

	battle.battlefield.castle.take_damage(battle.battlefield.castle.max_hp * 0.25)
	battle._ulti_charge = 0.5
	battle.hud.set_ulti(0.5)
	battle.hud.set_combo(4, 0.3)
	battle.hud.toast("KADİM KELİME!", UiKit.GOLD)

	# Harf çarkında bir seçim izi görünsün.
	var demo_selection: Array[int] = [0, 1, 2]
	battle.wheel._selection = demo_selection
	battle.wheel._dragging = true
	battle.wheel._drag_point = battle.wheel._positions[2] + Vector2(60, 40)
	battle.wheel.queue_redraw()

	for i in 30:
		await get_tree().process_frame
