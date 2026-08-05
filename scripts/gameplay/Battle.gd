extends Control

## Seviye oynanışının orkestratörü.
##
## Ekran düzeni (dikey):
##   üst  ~%60  Battlefield  — yollar, kuleler, düşmanlar, kale
##   alt  ~%40  LetterWheel  — harf çarkı
##   üstte HUD ve öğretici katmanı
##
## Temel döngü: oyuncu kelime kaydırır -> WordEngine doğrular -> kelimenin
## kategorisi TowerSystem'e inşa puanı yazar -> puan dolunca yuvaya kule dikilir.
## Bu sırada WaveManager düşman göndermeye devam eder (gerçek zamanlı tempo).

## Ekran bantları: savaş alanı üstte, HUD göstergeleri ortada, çark altta.
## Üçü ayrı bantlarda durur ki HUD savaş alanının üstünü kapatmasın.
## Seviye bittiğinde, sonuç ekranına yönlendirilmeden önce yayınlanır.
## (Yönlendirme call_deferred ile yapıldığından, dışarıdan `_finished` alanını
## yoklamak kare sırasına bağlı kalıyordu.)
signal level_finished(result: Dictionary)

const BATTLE_RATIO := 0.53
const BAND_TOP := 0.535
const BAND_BOTTOM := 0.685
const WHEEL_TOP := 0.685

## Çizim sırası. Savaş alanının iç katmanları z_index 1..9 kullanıyor ve
## Godot'ta z_index kardeşler arasındaki ağaç sırasını ezer; arayüze açıkça
## daha yüksek z verilmezse yol, kule, düşman ve efektler HUD'un, öğreticinin
## ve duraklatma perdesinin ÜSTÜNE çiziliyordu.
## Çocukların z_index'i varsayılan olarak GÖRELİdir (z_as_relative), yani iç içe
## katmanlarda değerler toplanır: düşman katmanı (5) içindeki düşman (5) etkin
## olarak 10'a çıkar. Bu yüzden arayüz değerleri geniş payla ayrılır.
const Z_BATTLEFIELD := 0
const Z_WHEEL := 100
const Z_HUD := 200
const Z_TUTORIAL := 300
const Z_OVERLAY := 400

var level_id := 1
var level := {}

var battlefield: Battlefield
var wheel: LetterWheel
var hud: Hud
var tutorial: TutorialOverlay
var waves: WaveManager
var towers: TowerSystem

var _found_words: Array = []
var _combo := 0
var _ulti_charge := 0.0
var _finished := false
var _paused := false
var _enemies_killed := 0
var _ancient_words := 0
var _stolen := {}          ## Enemy -> harf indeksi
var _pause_menu: Control = null
var _elapsed := 0.0
var _continue_used := false
var _word_totals := {}      ## harf sayısı -> çarktaki toplam kelime


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_id = SceneRouter.pending_level_id
	level = LevelDB.get_level(level_id)
	if level.is_empty():
		push_error("[Battle] Seviye bulunamadı: %d" % level_id)
		SceneRouter.go_to("harita")
		return

	_build_layout()
	_start_level()
	AudioManager.play_music("savas")


## --------------------------------------------------------------------------
## Kurulum
## --------------------------------------------------------------------------

func _build_layout() -> void:
	# Kök Control dokunuşları yutmamalı; girdiyi çocuklar (savaş alanı, çark,
	# HUD düğmeleri) kendileri alır.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var level_theme := GameConfig.theme_of_level(level_id)
	add_child(UiKit.background(Color(level_theme.get("gok_ust", "#2b3d2a")), Color("#171425")))

	battlefield = Battlefield.new()
	battlefield.z_index = Z_BATTLEFIELD
	battlefield.anchor_right = 1.0
	battlefield.anchor_bottom = BATTLE_RATIO
	battlefield.offset_bottom = 0
	add_child(battlefield)

	wheel = LetterWheel.new()
	wheel.z_index = Z_WHEEL
	wheel.anchor_top = WHEEL_TOP
	wheel.anchor_right = 1.0
	wheel.anchor_bottom = 1.0
	add_child(wheel)

	hud = Hud.new()
	hud.z_index = Z_HUD
	add_child(hud)
	hud.set_band(BAND_TOP, BAND_BOTTOM)

	tutorial = TutorialOverlay.new()
	tutorial.z_index = Z_TUTORIAL
	add_child(tutorial)

	waves = WaveManager.new()
	add_child(waves)

	towers = TowerSystem.new()
	add_child(towers)

	# --- Sinyaller ---------------------------------------------------------
	battlefield.enemy_died.connect(_on_enemy_died)
	battlefield.enemy_reached_castle.connect(_on_enemy_reached_castle)
	battlefield.enemy_spawned.connect(_on_enemy_spawned)
	battlefield.slot_tapped.connect(_on_slot_tapped)

	wheel.word_submitted.connect(_on_word_submitted)
	wheel.selection_changed.connect(func(word): hud.set_word(word))

	hud.pause_pressed.connect(_toggle_pause)
	hud.hint_pressed.connect(_on_hint)
	hud.shuffle_pressed.connect(func(): wheel.shuffle())
	hud.ulti_pressed.connect(_on_ulti)

	waves.wave_started.connect(_on_wave_started)
	waves.break_started.connect(func(seconds): hud.set_break(seconds))
	waves.all_waves_finished.connect(_on_all_waves_finished)
	waves.spawn_requested.connect(_on_spawn_requested)

	towers.points_changed.connect(_on_points_changed)
	towers.tower_ready.connect(_on_tower_ready)
	towers.tower_built.connect(_on_tower_built)
	towers.tower_upgraded.connect(_on_tower_upgraded)


func _start_level() -> void:
	battlefield.region_theme = GameConfig.theme_of_level(level_id)
	battlefield.build(int(level.get("yol_sayisi", 1)), int(level.get("slot_sayisi", 4)))
	battlefield.castle.setup(EconomyManager.castle_max_hp() * float(level.get("kale_can_carpani", 1.0)))
	battlefield.castle.health_changed.connect(hud.set_health)
	battlefield.castle.destroyed.connect(_on_defeat)
	battlefield.castle.healed.connect(_on_castle_healed)
	battlefield.castle.damaged.connect(_on_castle_damaged)
	hud.set_health(battlefield.castle.hp, battlefield.castle.max_hp)

	wheel.set_letters(level.get("harfler", []))
	_build_word_totals()
	towers.setup(battlefield)
	waves.setup(level.get("dalgalar", []))

	hud.set_found_count(0)
	hud.set_ulti(0.0)
	hud.set_hint_label(SaveManager.free_hints_left())

	var step := str(level.get("ogretici", ""))
	if step != "" and not SaveManager.is_tutorial_done(step):
		tutorial.begin(step, self)
		tutorial.finished.connect(_on_tutorial_finished, CONNECT_ONE_SHOT)
	else:
		waves.start()


## Çarktan türetilebilen kelimeleri harf sayısına göre sayar. Oyuncu "burada
## 4 harfli 6 kelime var" bilgisini görünce ne arayacağını bilir; kelime bulmak
## bu oyunun asıl zorluğu ve tamamen kör aramak sinir bozucu.
func _build_word_totals() -> void:
	_word_totals.clear()
	for word in level.get("cozum_kelimeler", []):
		var length := str(word).length()
		_word_totals[length] = int(_word_totals.get(length, 0)) + 1
	_refresh_word_progress()


func _refresh_word_progress() -> void:
	var found_by_length := {}
	for word in _found_words:
		var length := str(word).length()
		found_by_length[length] = int(found_by_length.get(length, 0)) + 1
	var progress := {}
	for length in _word_totals:
		progress[length] = {
			"bulunan": int(found_by_length.get(length, 0)),
			"toplam": int(_word_totals[length]),
		}
	wheel.set_word_progress(progress)


func _on_tutorial_finished(step: String) -> void:
	SaveManager.mark_tutorial_done(step)
	waves.start()


func _process(delta: float) -> void:
	if not _finished and not _paused:
		_elapsed += delta
	hud.set_break(waves.break_remaining())


## --------------------------------------------------------------------------
## Kelime akışı
## --------------------------------------------------------------------------

func _on_word_submitted(raw: String) -> void:
	if _finished:
		return
	var result: WordEngine.WordResult = WordEngine.submit(raw, _found_words)
	if not result.valid:
		_combo = 0
		towers.set_combo_bonus(0.0)
		hud.set_combo(0, 0.0)
		hud.toast(result.reason, UiKit.DANGER)
		wheel.reject()
		AudioManager.play_sfx("kelime_yanlis")
		Haptics.word_rejected()
		return

	_found_words.append(result.word)
	_combo += 1
	var combo_bonus := minf((_combo - 1) * GameConfig.COMBO_STEP, GameConfig.COMBO_MAX)
	towers.set_combo_bonus(combo_bonus)
	hud.set_combo(_combo, combo_bonus)
	hud.set_found_count(_found_words.size())
	_refresh_word_progress()

	var target := _wheel_target_for(result.tower_type)
	var color := UiKit.GOLD
	if result.tower_type != "":
		color = Color(GameConfig.TOWERS[result.tower_type]["renk"])
	wheel.accept(target, color)

	AudioManager.play_sfx("kelime_dogru", 1.0 + minf(_combo, 6) * 0.05)
	Haptics.word_accepted()

	# Kelimenin gücünü savaş alanında da göster: hedef kulede/kalede parıltı.
	var focus := _battlefield_focus(result.tower_type)
	battlefield.effects.rising(focus, 6 + int(result.length_multiplier * 3), color, 30.0)
	battlefield.effects.ring(focus, 60.0 * result.length_multiplier, color, 0.45, 4.0)

	if result.tower_type != "":
		towers.add_category_word(result.tower_type, result.length_multiplier)
		var meta: Dictionary = WordEngine.category_meta(result.category)
		hud.toast("%s  →  %s" % [TurkishText.to_upper(result.word), meta.get("ad", "")], color)
	else:
		towers.add_general_energy(result.length_multiplier)
		hud.toast("%s  →  Genel enerji" % TurkishText.to_upper(result.word), UiKit.INK)

	if result.is_ancient:
		_ancient_words += 1
		_ulti_charge = minf(1.0, _ulti_charge
			+ GameConfig.ULTI_CHARGE_PER_ANCIENT * EconomyManager.ulti_charge_multiplier())
		hud.set_ulti(_ulti_charge)
		hud.toast("KADİM KELİME!", UiKit.GOLD)
		battlefield.effects.floating_text(
			Vector2(battlefield.size.x * 0.5, battlefield.size.y * 0.45),
			TurkishText.to_upper(result.word), UiKit.GOLD, 46)
		battlefield.effects.ring(Vector2(battlefield.size.x * 0.5, battlefield.size.y * 0.45),
			260.0, UiKit.GOLD, 0.7, 9.0)
		battlefield.shake(8.0, 0.35)
		Haptics.ancient_word()
		SaveManager.unlock_achievement("kadim_kelime")

	_track_word_stats(result)
	tutorial.notify("kelime", result.category)


func _track_word_stats(result: WordEngine.WordResult) -> void:
	var stats: Dictionary = SaveManager.progress["istatistik"]
	stats["bulunan_kelime"] = int(stats.get("bulunan_kelime", 0)) + 1
	if result.is_ancient:
		stats["kadim_kelime"] = int(stats.get("kadim_kelime", 0)) + 1
	if result.word.length() > str(stats.get("en_uzun_kelime", "")).length():
		stats["en_uzun_kelime"] = result.word
	SaveManager.mark_dirty()
	SaveManager.unlock_achievement("ilk_kelime")
	if int(stats["bulunan_kelime"]) >= 500:
		SaveManager.unlock_achievement("kelime_ustasi")


## Kelime etkisinin savaş alanındaki odak noktası (kule varsa kule, yoksa kale).
func _battlefield_focus(tower_type: String) -> Vector2:
	if tower_type != "":
		for node in battlefield.towers():
			var tower := node as Tower
			if tower.tower_type == tower_type:
				return tower.position
	return battlefield.castle.position


## Harflerin uçacağı hedef: o tipteki bir kule, yoksa boş bir yuva, o da yoksa kale.
func _wheel_target_for(tower_type: String) -> Vector2:
	var point := battlefield.castle.global_position
	if tower_type != "":
		for node in battlefield.towers():
			var tower := node as Tower
			if tower.tower_type == tower_type:
				point = tower.global_position
				break
	return wheel.get_global_transform_with_canvas().affine_inverse() \
		* (battlefield.get_global_transform_with_canvas() * point)


## --------------------------------------------------------------------------
## Kule olayları
## --------------------------------------------------------------------------

func _on_points_changed(tower_type: String, points: float, threshold: float) -> void:
	hud.set_meter(tower_type, points, threshold, towers.is_ready(tower_type))


func _on_tower_ready(tower_type: String) -> void:
	for slot in battlefield.slots:
		slot.set_ready(slot.is_empty())
	var config: Dictionary = GameConfig.TOWERS[tower_type]
	hud.toast("%s hazır — boş bir yuvaya dokun" % config["ad"], Color(config["renk"]))
	tutorial.notify("kule_hazir", tower_type)


func _on_slot_tapped(slot: TowerSlot) -> void:
	if _finished or _paused:
		return
	if towers.build_on(slot):
		return
	hud.toast("Önce kategoriden kelime bul", UiKit.INK_SOFT)


func _on_tower_built(tower: Tower, tower_type: String) -> void:
	tower.wants_heal.connect(_on_tower_heal)
	for slot in battlefield.slots:
		slot.set_ready(slot.is_empty() and not towers.ready_types().is_empty())
	Haptics.tower_built()
	SaveManager.unlock_achievement("ilk_kule")
	tutorial.notify("kule_kuruldu", tower_type)


func _on_tower_upgraded(tower: Tower, tower_level: int) -> void:
	hud.toast("%s → Seviye %d" % [tower.config.get("ad", ""), tower_level], UiKit.GOLD)
	if tower_level >= GameConfig.MAX_TOWER_LEVEL:
		SaveManager.unlock_achievement("usta_mimar")


func _on_tower_heal(tower: Tower, amount: float) -> void:
	var healed := battlefield.castle.heal(amount)
	if healed > 0.0:
		battlefield.effects.rising(tower.position, 8, Color("#7fe0a0"), 26.0)


func _on_castle_healed(amount: float) -> void:
	var castle := battlefield.castle
	battlefield.effects.rising(castle.position + Vector2(0, -20.0), 12, Color("#7fe0a0"), 60.0)
	battlefield.effects.floating_text(castle.position + Vector2(0, -120.0),
		"+%d" % ceili(amount), Color("#7fe0a0"), 28)


func _on_castle_damaged(amount: float) -> void:
	var castle := battlefield.castle
	battlefield.effects.sparks(castle.position + Vector2(0, -40.0), 12, Color("#d1544a"), 260.0)
	battlefield.effects.floating_text(castle.position + Vector2(0, -140.0),
		"-%d" % ceili(amount), Color("#ff8a7a"), 30)
	battlefield.shake(minf(4.0 + amount * 0.35, 16.0), 0.3)


## --------------------------------------------------------------------------
## Dalga ve düşman olayları
## --------------------------------------------------------------------------

func _on_wave_started(index: int, total: int, is_boss: bool) -> void:
	hud.set_wave(index, total, is_boss)
	if is_boss:
		hud.toast("BOSS GELİYOR!", UiKit.DANGER)


func _on_spawn_requested(enemy_type: String, path_index: int, power: float) -> void:
	battlefield.spawn_enemy(enemy_type, path_index, power)


func _on_enemy_spawned(enemy: Enemy) -> void:
	if enemy.is_boss:
		enemy.phase_changed.connect(_on_boss_phase)
	if not enemy.steals_letter:
		return
	# Harf Hırsızı doğar doğmaz çarktan bir harfi kilitler.
	var index := wheel.pick_lockable_index()
	if index < 0:
		return
	enemy.stolen_letter = index
	_stolen[enemy] = index
	wheel.lock_letter(index, enemy.steal_duration)
	hud.toast("Harf Hırsızı bir harfi çaldı!", UiKit.DANGER)


func _on_boss_phase(enemy: Enemy, phase: int) -> void:
	var summon := enemy.phase_summon(phase)
	if summon == "":
		return
	hud.toast("Boss yardım çağırıyor!", UiKit.DANGER)
	for i in 3:
		waves.force_spawn(summon, i % maxi(battlefield.tracks.size(), 1), 1.0)


func _on_enemy_died(enemy: Enemy) -> void:
	_enemies_killed += 1
	EconomyManager.add_gold(enemy.gold)
	_release_stolen_letter(enemy)
	var stats: Dictionary = SaveManager.progress["istatistik"]
	stats["oldurulen_dusman"] = int(stats.get("oldurulen_dusman", 0)) + 1
	if _finished:
		return
	if waves.is_finished() and battlefield.live_enemy_count() == 0:
		_on_victory()


func _on_enemy_reached_castle(enemy: Enemy, damage: float) -> void:
	_release_stolen_letter(enemy)
	battlefield.castle.take_damage(damage)
	if not _finished and waves.is_finished() and battlefield.live_enemy_count() == 0:
		_on_victory()


## Hırsız öldüğünde ya da kaleye ulaştığında kilitlediği harf açılır.
func _release_stolen_letter(enemy: Enemy) -> void:
	if not _stolen.has(enemy):
		return
	wheel.unlock_letter(int(_stolen[enemy]))
	_stolen.erase(enemy)
	enemy.stolen_letter = -1


## --------------------------------------------------------------------------
## İpucu, ulti, duraklatma
## --------------------------------------------------------------------------

func _on_hint() -> void:
	if _finished:
		return
	var preferred := ""
	var targets: Array = level.get("hedef_kategoriler", [])
	if not targets.is_empty():
		preferred = str(targets[0])
	var suggestion: String = WordEngine.hint(Array(wheel.letters).map(
		func(l): return TurkishText.to_lower(l)), _found_words, preferred)
	if suggestion == "":
		hud.toast("Bu çarkta bulunacak kelime kalmadı", UiKit.INK_SOFT)
		return
	if not EconomyManager.try_spend_hint():
		hud.toast("Yeterli elmas yok", UiKit.DANGER)
		return
	wheel.flash_hint(suggestion)
	hud.toast("%d harfli bir kelime: %s…" % [suggestion.length(),
		TurkishText.to_upper(suggestion.substr(0, 2))], UiKit.GOLD)
	hud.set_hint_label(SaveManager.free_hints_left())


func _on_ulti() -> void:
	if _ulti_charge < 1.0 or _finished:
		return
	_ulti_charge = 0.0
	hud.set_ulti(0.0)
	AudioManager.play_sfx("ulti")
	Haptics.pulse(Haptics.STRONG)
	var hits := battlefield.cast_ulti(GameConfig.ULTI_DAMAGE)
	hud.toast("Kadim Büyü! %d düşman vuruldu" % hits, UiKit.GOLD)


func _toggle_pause() -> void:
	if _finished:
		return
	_paused = not _paused
	get_tree().paused = _paused
	if _paused:
		_show_pause_menu()
	elif _pause_menu != null:
		_pause_menu.queue_free()
		_pause_menu = null


func _show_pause_menu() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.02, 0.05, 0.72)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = Z_OVERLAY
	overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	# Serbest duran düğme yığını yerine ortada bir kart: menü savaş alanından
	# ayrı bir katman gibi dursun.
	var card := UiKit.panel(Color(0.10, 0.09, 0.15, 0.96))
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.anchor_left = 0.08
	card.anchor_right = 0.92
	card.offset_left = 0
	card.offset_right = 0
	card.offset_top = -300
	card.offset_bottom = 300

	var box := UiKit.vbox(16)
	card.add_child(box)

	box.add_child(UiKit.title("Duraklatıldı"))

	# Oyuncu neyi bıraktığını görsün: dalga ve kale canı.
	var wave_text := "Dalga %d / %d" % [maxi(waves.current_index + 1, 1), waves.wave_count()]
	var hp_text := "Kale %d%%" % int(round(battlefield.castle.health_ratio() * 100.0))
	box.add_child(UiKit.label("%s   •   %s" % [wave_text, hp_text],
		UiKit.FONT_BODY, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiKit.spacer(10))

	var resume := UiKit.button("Devam Et", UiKit.GOLD, UiKit.FONT_HEAD)
	resume.custom_minimum_size = Vector2(0, 126)
	resume.pressed.connect(_toggle_pause)
	box.add_child(resume)

	var restart := UiKit.ghost_button("Yeniden Başla")
	UiKit.set_button_icon(restart, "karistir")
	restart.pressed.connect(func():
		get_tree().paused = false
		SceneRouter.play_level(level_id))
	box.add_child(restart)

	var quit := UiKit.ghost_button("Haritaya Dön")
	UiKit.set_button_icon(quit, "parsomen")
	quit.pressed.connect(func():
		get_tree().paused = false
		SceneRouter.go_to("harita"))
	box.add_child(quit)

	overlay.add_child(card)
	add_child(overlay)
	_pause_menu = overlay


## --------------------------------------------------------------------------
## Bitiş
## --------------------------------------------------------------------------

func _on_all_waves_finished() -> void:
	if not _finished and battlefield.live_enemy_count() == 0:
		_on_victory()


func _on_victory() -> void:
	if _finished:
		return
	_finished = true
	wheel.enabled = false
	AudioManager.play_sfx("zafer")

	var hp_ratio := battlefield.castle.health_ratio()
	var stars := 1
	if hp_ratio >= GameConfig.STAR_THRESHOLDS[2]:
		stars = 3
	elif hp_ratio >= GameConfig.STAR_THRESHOLDS[1]:
		stars = 2

	var first_clear := SaveManager.level_stars(level_id) == 0
	var reward := EconomyManager.level_reward(level_id, stars, _found_words.size(), first_clear)
	EconomyManager.add_gold(reward)
	SaveManager.record_level_result(level_id, stars, hp_ratio)

	if hp_ratio >= 0.999:
		SaveManager.unlock_achievement("kusursuz")
	if GameConfig.is_boss_level(level_id):
		var region := GameConfig.region_of_level(level_id)
		SaveManager.unlock_achievement(["vadi_fatihi", "orman_fatihi", "buz_fatihi",
			"ejder_avcisi"][region])
	PlayServices.submit_score("toplam_yildiz", SaveManager.total_stars())

	_finish({
		"zafer": true,
		"seviye": level_id,
		"yildiz": stars,
		"altin": reward,
		"kelime": _found_words.size(),
		"kadim": _ancient_words,
		"oldurulen": _enemies_killed,
		"can_orani": hp_ratio,
		"ilk_gecis": first_clear,
		"sure": _elapsed,
	})


func _on_defeat() -> void:
	if _finished:
		return
	_finished = true
	wheel.enabled = false
	AudioManager.play_sfx("yenilgi")
	# "Devam et" teklifi seviye başına bir kez ve yalnızca ödüllü video hazırsa.
	if not _continue_used and AdManager.rewarded_available():
		_show_continue_offer()
		return
	_report_defeat()


func _report_defeat() -> void:
	_finish({
		"zafer": false,
		"seviye": level_id,
		"yildiz": 0,
		"altin": 0,
		"kelime": _found_words.size(),
		"kadim": _ancient_words,
		"oldurulen": _enemies_killed,
		"can_orani": 0.0,
		"ilk_gecis": false,
		"sure": _elapsed,
	})


func _finish(result: Dictionary) -> void:
	# Reklam yalnızca seviye BİTTİKTEN sonra; oyun ortasında asla.
	set_process(false)
	level_finished.emit(result)
	battlefield.clear_all()
	SaveManager.save_progress()
	SceneRouter.show_result(result)


## --------------------------------------------------------------------------
## "Devam et" ödüllü reklamı
## --------------------------------------------------------------------------

## Kale yıkıldığında, seviyeyi baştan almak yerine ödüllü video izleyip
## kaldığı yerden devam etme teklifi. Seviye başına tek kez sunulur.
func _show_continue_offer() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.82)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = Z_OVERLAY

	var box := UiKit.vbox(20)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.anchor_left = 0.1
	box.anchor_right = 0.9
	box.offset_top = -240
	box.offset_bottom = 240

	box.add_child(UiKit.title("Kale düştü!"))
	box.add_child(UiKit.label(
		"Kısa bir video izle, kalen %d%% canla ayağa kalksın ve kaldığın yerden devam et."
			% roundi(GameConfig.CONTINUE_REVIVE_HP_RATIO * 100.0),
		UiKit.FONT_BODY, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER))

	var watch := UiKit.button("Video izle ve devam et", UiKit.SUCCESS)
	watch.pressed.connect(func():
		watch.disabled = true
		AdManager.rewarded_finished.connect(_on_continue_ad_finished.bind(overlay),
			CONNECT_ONE_SHOT)
		AdManager.show_rewarded(AdManager.PLACEMENT_CONTINUE))
	box.add_child(watch)

	var give_up := UiKit.ghost_button("Vazgeç")
	give_up.pressed.connect(func():
		overlay.queue_free()
		_report_defeat())
	box.add_child(give_up)

	overlay.add_child(box)
	add_child(overlay)


func _on_continue_ad_finished(success: bool, placement: String, overlay: Control) -> void:
	if placement != AdManager.PLACEMENT_CONTINUE:
		return
	if is_instance_valid(overlay):
		overlay.queue_free()
	if not success:
		hud.toast("Video izlenemedi", UiKit.DANGER)
		_report_defeat()
		return
	_continue_used = true
	revive_and_continue()


## Kaleyi diriltip savaşı kaldığı yerden sürdürür.
func revive_and_continue() -> void:
	_finished = false
	wheel.enabled = true
	battlefield.castle.revive(GameConfig.CONTINUE_REVIVE_HP_RATIO)
	hud.toast("Kale ayağa kalktı!", UiKit.SUCCESS)
	set_process(true)
