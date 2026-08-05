extends Node

## Başsız (headless) test koşucusu.
##
## Çalıştırma:
##   godot --headless --path . scenes/Testler.tscn
##
## Sözlük doğruluğu, Türkçe harf dönüşümü, seviye verisi tutarlılığı, ekonomi
## kuralları ve tam bir savaş turunun uçtan uca çalışması sınanır.
## Başarısız test varsa süreç 1 koduyla çıkar (CI'da kullanılabilir).

var _passed := 0
var _failed := 0
var _current := ""


func _ready() -> void:
	print("=== Kelime Kalesi test koşusu ===")
	await get_tree().process_frame

	_run("Türkçe harf dönüşümü", _test_turkish)
	_run("Trie sözlük", _test_trie)
	_run("Trie başarımı (<5 ms)", _test_trie_performance)
	_run("Çarktan kelime türetme", _test_wheel_solver)
	_run("Kelime motoru", _test_word_engine)
	_run("Kategori verisi", _test_categories)
	_run("Seviye verisi", _test_levels)
	_run("Kelime kalitesi (küfür ve yaygınlık)", _test_word_quality)
	_run("Ekonomi ve yükseltmeler", _test_economy)
	_run("Kayıt sistemi", _test_save)
	await _run_async("Savaş turu (uçtan uca)", _test_battle)
	await _run_async("Gerçek dokunma girdisi", _test_touch_input)
	await _run_async("Fare girdisi (masaüstü)", _test_mouse_input)
	await _run_async("Arayüz çizim sırası", _test_ui_layering)
	await _run_async("Harf çarkı yerleşimi (telefon oranları)", _test_wheel_layout)
	await _run_async("Yürüyüş animasyonu", _test_walk_animation)
	await _run_async("Sprite yön çevirme", _test_sprite_flip)
	await _run_async("Bölüme özgü saha yerleşimi", _test_level_layout)
	await _run_async("Yol şeridi delik bırakmıyor", _test_road_strip)
	await _run_async("Yol zeminden ayırt ediliyor", _test_road_contrast)
	await _run_async("Kalabalık çarkta parmak yolu", _test_swipe_routing)
	await _run_async("Altmış bölümde yuva menzili", _test_slot_coverage)
	await _run_async("Bölüm haritası", _test_kingdom_map)
	await _run_async("Tüm ekranlar açılıyor", _test_screens_open)

	print("\n=== Sonuç: %d başarılı, %d başarısız ===" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


## --------------------------------------------------------------------------
## Çatı
## --------------------------------------------------------------------------

func _run(title: String, test: Callable) -> void:
	_current = title
	var before := _failed
	test.call()
	print("  %s %s" % ["✓" if _failed == before else "✗", title])


func _run_async(title: String, test: Callable) -> void:
	_current = title
	var before := _failed
	await test.call()
	print("  %s %s" % ["✓" if _failed == before else "✗", title])


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("    HATA [%s] %s" % [_current, message])


func _equal(actual, expected, message: String) -> void:
	_check(actual == expected, "%s (beklenen: %s, gelen: %s)" % [message, expected, actual])


## --------------------------------------------------------------------------
## Testler
## --------------------------------------------------------------------------

func _test_turkish() -> void:
	_equal(TurkishText.to_upper("istanbul"), "İSTANBUL", "i -> İ")
	_equal(TurkishText.to_lower("IRMAK"), "ırmak", "I -> ı")
	_equal(TurkishText.to_lower("İĞNE"), "iğne", "İ -> i")
	_equal(TurkishText.to_upper("çiğ şu ölü"), "ÇİĞ ŞU ÖLÜ", "özel harfler")
	_equal(TurkishText.normalize("  KÂĞIT "), "kağıt", "düzeltme işareti katlanır")
	_equal(TurkishText.normalize("RÜZGÂR"), "rüzgar", "â -> a")
	_check(TurkishText.is_turkish_word("şeftali"), "geçerli Türkçe kelime")
	_check(not TurkishText.is_turkish_word("wxq"), "alfabe dışı harf reddedilir")
	# Sıralama: h < ı < i < j
	_check(TurkishText.compare("hız", "iyi") < 0, "ı harfi i'den önce gelir")
	_check(TurkishText.compare("cam", "çam") < 0, "c harfi ç'den önce gelir")


func _test_trie() -> void:
	_check(WordEngine.is_ready(), "sözlük yüklendi")
	_check(WordEngine.word_count() > 50000, "sözlük 50 binden fazla kelime içeriyor")

	for word in ["kale", "kelime", "kılıç", "şeftali", "ağaç", "ıspanak", "öğretmen", "üzüm"]:
		_check(WordEngine.contains(word), "sözlükte olmalı: %s" % word)
	for word in ["zzzt", "qwerty", "kalexx", "aaaaaa", "şşşş"]:
		_check(not WordEngine.contains(word), "sözlükte olmamalı: %s" % word)

	_check(WordEngine.has_prefix("kel"), "ön ek bulunmalı: kel")
	_check(not WordEngine.has_prefix("zzq"), "ön ek bulunmamalı: zzq")

	# Büyük harfli ve boşluklu girdi normalize edilerek bulunmalı.
	_check(WordEngine.contains(" KALE "), "normalize edilmiş girdi")


func _test_trie_performance() -> void:
	var samples := ["kale", "kelime", "kılıç", "zzzt", "şeftali", "qwerty", "ağaç", "üzüm"]
	var started := Time.get_ticks_usec()
	var rounds := 2000
	for i in rounds:
		WordEngine.contains(samples[i % samples.size()])
	var micros := (Time.get_ticks_usec() - started) / float(rounds)
	print("      ortalama doğrulama: %.1f µs" % micros)
	_check(micros < 5000.0, "tek doğrulama 5 ms altında olmalı (%.1f µs)" % micros)


func _test_wheel_solver() -> void:
	# Bilinen küçük bir çark: "kale" harfleri
	var letters := ["k", "a", "l", "e"]
	var words := WordEngine.words_for_wheel(letters)
	_check(words.has("kale"), "çarktan 'kale' türetilmeli")
	_check(words.has("elk") == false or WordEngine.contains("elk"), "yalnız sözlük kelimeleri")

	# Türetilen her kelime gerçekten sözlükte olmalı ve harfleri çarkta bulunmalı.
	var pool := {}
	for letter in letters:
		pool[letter] = int(pool.get(letter, 0)) + 1
	var all_valid := true
	for word in words:
		if not WordEngine.contains(word):
			all_valid = false
			break
		var used := {}
		for i in word.length():
			var ch: String = word[i]
			used[ch] = int(used.get(ch, 0)) + 1
			if int(used[ch]) > int(pool.get(ch, 0)):
				all_valid = false
				break
	_check(all_valid, "türetilen kelimeler hem sözlükte hem çark harflerinden oluşmalı")
	_check(words.size() >= 2, "en az birkaç kelime türetilmeli (%d)" % words.size())


func _test_word_engine() -> void:
	var result: WordEngine.WordResult = WordEngine.submit("kurt")
	_check(result.valid, "kurt geçerli olmalı")
	_equal(result.category, "hayvan", "kurt hayvan kategorisinde")
	_equal(result.tower_type, "okcu", "hayvan -> okçu kulesi")
	_equal(result.length_multiplier, 1.5, "4 harf -> 1.5x")

	_equal(WordEngine.submit("dağ").category, "doga", "dağ doğa kategorisinde")
	_equal(WordEngine.submit("kılıç").tower_type, "mancinik", "nesne -> mancınık")
	_equal(WordEngine.submit("ekmek").tower_type, "sifa", "yiyecek -> şifa çeşmesi")

	_equal(WordEngine.submit("at").valid, false, "2 harf reddedilir")
	_equal(WordEngine.submit("zzzt").valid, false, "sözlük dışı reddedilir")
	_equal(WordEngine.submit("kale", ["kale"]).valid, false, "tekrarlanan kelime reddedilir")

	_equal(GameConfig.length_multiplier(3), 1.0, "3 harf 1x")
	_equal(GameConfig.length_multiplier(5), 2.0, "5 harf 2x")
	_equal(GameConfig.length_multiplier(6), 3.0, "6+ harf 3x")
	_equal(GameConfig.length_multiplier(9), 3.0, "9 harf de 3x")

	var ancient: WordEngine.WordResult = WordEngine.submit("öğretmen")
	_check(ancient.valid and ancient.is_ancient, "8 harfli kelime Kadim Kelime olmalı")
	_check(not WordEngine.submit("kurt").is_ancient, "4 harfli kelime Kadim değil")


func _test_categories() -> void:
	for category in ["hayvan", "doga", "nesne", "yiyecek"]:
		var meta := WordEngine.category_meta(category)
		_check(not meta.is_empty(), "kategori tanımlı: %s" % category)
		var tower: String = WordEngine.tower_for_category(category)
		_check(GameConfig.TOWERS.has(tower), "kategorinin kulesi geçerli: %s" % category)
		_equal(WordEngine.category_for_tower(tower), category, "kule -> kategori geri eşleme")


func _test_levels() -> void:
	_equal(LevelDB.count(), GameConfig.TOTAL_LEVELS, "60 seviye yüklenmeli")

	var bad_words := 0
	var bad_letters := 0
	for level_id in range(1, GameConfig.TOTAL_LEVELS + 1):
		var level := LevelDB.get_level(level_id)
		_check(not level.is_empty(), "seviye var: %d" % level_id)

		var letters: Array = level.get("harfler", [])
		_check(letters.size() >= 5 and letters.size() <= 8,
			"seviye %d çark boyutu 5-8 arası (%d)" % [level_id, letters.size()])

		# Kayıtlı çözüm kelimeleri gerçekten sözlükte ve çarktan türetilebilir olmalı.
		var pool := {}
		for letter in letters:
			pool[letter] = int(pool.get(letter, 0)) + 1
		for word in level.get("cozum_kelimeler", []):
			if not WordEngine.contains(str(word)):
				bad_words += 1
				continue
			var used := {}
			for i in str(word).length():
				var ch := str(word)[i]
				used[ch] = int(used.get(ch, 0)) + 1
				if int(used[ch]) > int(pool.get(ch, 0)):
					bad_letters += 1
					break

		_check((level.get("dalgalar", []) as Array).size() > 0,
			"seviye %d dalga içermeli" % level_id)
		_equal(bool(level.get("boss", false)), GameConfig.is_boss_level(level_id),
			"seviye %d boss işareti" % level_id)

		for enemy_type in LevelDB.enemy_types(level_id):
			_check(GameConfig.ENEMIES.has(enemy_type),
				"seviye %d bilinen düşman: %s" % [level_id, enemy_type])

	_equal(bad_words, 0, "tüm çözüm kelimeleri sözlükte olmalı")
	_equal(bad_letters, 0, "tüm çözüm kelimeleri çark harflerinden türetilebilmeli")

	# Öğretici ilk üç seviyede olmalı.
	for level_id in [1, 2, 3]:
		_check(str(LevelDB.get_level(level_id).get("ogretici", "")) != "",
			"seviye %d öğretici adımı taşımalı" % level_id)


func _test_economy() -> void:
	var gold_before := EconomyManager.gold()
	EconomyManager.add_gold(500)
	_equal(EconomyManager.gold(), gold_before + 500, "altın eklenir")
	_check(EconomyManager.spend_gold(200), "yeterli altın harcanır")
	_equal(EconomyManager.gold(), gold_before + 300, "harcama düşülür")
	_check(not EconomyManager.spend_gold(999999), "yetersiz altın reddedilir")

	# Yükseltme maliyeti seviyeyle artmalı.
	var first := GameConfig.upgrade_cost("kule_gucu", 0)
	var second := GameConfig.upgrade_cost("kule_gucu", 1)
	_check(second > first, "yükseltme maliyeti artmalı (%d -> %d)" % [first, second])
	_equal(GameConfig.upgrade_cost("kule_gucu", GameConfig.UPGRADES["kule_gucu"]["max_seviye"]), -1,
		"en üst seviyede maliyet -1")

	# Yıldız ödülü daha yüksek olmalı.
	var low := EconomyManager.level_reward(5, 1, 10, true)
	var high := EconomyManager.level_reward(5, 3, 10, true)
	_check(high > low, "3 yıldız daha çok altın vermeli")
	_check(EconomyManager.level_reward(5, 3, 10, false) < high, "tekrar oynamada ödül azalır")

	# Kozmetikler oyun gücünü etkilememeli.
	_equal(EconomyManager.tower_damage_multiplier(),
		1.0 + EconomyManager.upgrade_bonus("kule_gucu"),
		"kule hasarı yalnız yükseltmeye bağlı")


func _test_save() -> void:
	# Testler gerçek user:// kaydını kullanır; önceki koşudan kalan veri
	# sonuçları bozmasın diye temiz bir kayıtla başlanır.
	SaveManager.reset_progress()
	SaveManager.record_level_result(1, 2, 0.6)
	_equal(SaveManager.level_stars(1), 2, "yıldız kaydedilir")
	SaveManager.record_level_result(1, 1, 0.3)
	_equal(SaveManager.level_stars(1), 2, "daha düşük skor yıldızı düşürmez")
	SaveManager.record_level_result(1, 3, 0.9)
	_equal(SaveManager.level_stars(1), 3, "daha yüksek skor yıldızı yükseltir")

	_check(SaveManager.is_level_unlocked(1), "ilk seviye hep açık")
	_check(SaveManager.is_level_unlocked(2), "1. seviye geçilince 2. açılır")
	_check(not SaveManager.is_level_unlocked(20), "uzak seviye kilitli")

	SaveManager.save_progress()
	var reloaded := SaveManager._read_progress()
	_equal(int(reloaded["seviyeler"]["1"]["yildiz"]), 3, "kayıt diskten geri okunur")


## --------------------------------------------------------------------------
## Uçtan uca savaş turu
## --------------------------------------------------------------------------

func _test_battle() -> void:
	SceneRouter.pending_level_id = 4  # öğreticisiz, çok kelimeli bir seviye
	var scene: PackedScene = load("res://scenes/Oyun.tscn")
	var battle := scene.instantiate()
	add_child(battle)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(battle.size.x > 0.0 and battle.size.y > 0.0,
		"savaş sahnesi çapa ayarlarıyla ekranı kaplamalı (%s)" % battle.size)
	_check(battle.battlefield.size.y > 0.0, "savaş alanı yüksekliği hesaplandı")

	_check(battle.battlefield != null, "savaş alanı kuruldu")
	_check(battle.battlefield.tracks.size() >= 1, "en az bir yol var")
	_check(battle.battlefield.slots.size() >= 1, "kule yuvaları var")
	_check(battle.battlefield.castle.hp > 0.0, "kale canı dolu")
	_equal(battle.wheel.letters.size(),
		(LevelDB.get_level(4).get("harfler", []) as Array).size(), "çark harfleri yüklendi")

	# Yuvalar yolun üstüne düşmemeli.
	var overlapping := 0
	for slot in battle.battlefield.slots:
		for track in battle.battlefield.tracks:
			if track.distance_to_path(slot.position) < PathTrack.PATH_WIDTH * 0.5:
				overlapping += 1
	_equal(overlapping, 0, "hiçbir yuva yolun üstünde olmamalı")

	# Kategorili kelimeler gönder: inşa puanı birikmeli ve kule hazır olmalı.
	var level := LevelDB.get_level(4)
	var category_words: Array = []
	for category in level.get("kategori_kelimeler", {}):
		for word in level["kategori_kelimeler"][category]:
			category_words.append(str(word))
	_check(category_words.size() > 0, "seviyede kategori kelimesi var")

	var built := false
	for word in category_words:
		battle._on_word_submitted(word)
		if not battle.towers.ready_types().is_empty():
			# Hazır olan tipi ilk boş yuvaya dik.
			for slot in battle.battlefield.slots:
				if slot.is_empty() and battle.towers.build_on(slot):
					built = true
					break
		if built:
			break
	_check(built, "kategori kelimeleriyle kule inşa edilebilmeli")
	_check(battle.battlefield.towers().size() > 0, "savaş alanında kule var")

	# Geçersiz kelime combo'yu sıfırlamalı ve kabul edilmemeli.
	var found_before: int = battle._found_words.size()
	battle._on_word_submitted("zzzt")
	_equal(battle._found_words.size(), found_before, "geçersiz kelime listeye eklenmez")

	# Düşman doğur ve kulenin onu vurduğunu doğrula.
	var enemy: Enemy = battle.battlefield.spawn_enemy("goblin", 0, 1.0)
	_check(enemy != null and enemy.alive, "düşman doğdu")
	var hp_before: float = enemy.hp
	# Kuleyi yolun ortasına al ve düşmanı oraya yakın bir mesafeden yürüt.
	# (Düşmanın konumu her karede yoldan yeniden hesaplandığı için doğrudan
	# position atamak işe yaramaz; ilerleme mesafesi ayarlanmalıdır.)
	var tower: Tower = battle.battlefield.towers()[0] as Tower
	var track: PathTrack = battle.battlefield.tracks[0]
	var midpoint := track.length() * 0.5
	tower.position = track.position_at(midpoint)
	enemy.distance = maxf(0.0, midpoint - 40.0)
	for i in 120:
		await get_tree().process_frame
		if not enemy.alive or enemy.hp < hp_before:
			break
	_check(enemy.hp < hp_before or not enemy.alive, "kule menzilindeki düşmana hasar verdi")

	# Hayalet yalnız büyü kulesinden hasar almalı.
	var ghost: Enemy = battle.battlefield.spawn_enemy("hayalet", 0, 1.0)
	_equal(ghost.take_damage(50.0, "okcu"), 0.0, "hayalet oka bağışık")
	_equal(ghost.take_damage(50.0, "mancinik"), 0.0, "hayalet mancınığa bağışık")
	_check(ghost.take_damage(10.0, "buyu") > 0.0, "hayalet büyüden hasar alır")

	# Zırhlı trol: normal hasar yarılanır, mancınık zırhı deler.
	var troll: Enemy = battle.battlefield.spawn_enemy("zirhli_trol", 0, 1.0)
	var archer_damage: float = troll.take_damage(100.0, "okcu")
	var catapult_damage: float = troll.take_damage(100.0, "mancinik")
	_equal(archer_damage, 50.0, "trol zırhı ok hasarını yarılar")
	_check(catapult_damage > archer_damage, "mancınık trole daha çok hasar verir")

	# Harf Hırsızı bir harfi kilitlemeli, ölünce açmalı.
	var thief: Enemy = battle.battlefield.spawn_enemy("harf_hirsizi", 0, 1.0)
	await get_tree().process_frame
	_check(battle.wheel.locked_indices().size() > 0, "harf hırsızı bir harfi kilitledi")
	thief.take_damage(9999.0, "okcu")
	await get_tree().process_frame
	_equal(battle.wheel.locked_indices().size(), 0, "hırsız ölünce harf açıldı")

	# Ulti ekranı temizlemeli.
	battle.battlefield.spawn_enemy("goblin", 0, 1.0)
	battle.battlefield.spawn_enemy("goblin", 0, 1.0)
	await get_tree().process_frame
	var before_ulti: int = battle.battlefield.live_enemy_count()
	_check(before_ulti > 0, "ultiden önce düşman var")
	battle.battlefield.cast_ulti(GameConfig.ULTI_DAMAGE)
	await get_tree().process_frame
	_check(battle.battlefield.live_enemy_count() < before_ulti, "ulti düşmanları temizledi")

	# Kale hasar alınca can azalmalı.
	var castle_hp: float = battle.battlefield.castle.hp
	battle.battlefield.castle.take_damage(10.0)
	_check(battle.battlefield.castle.hp < castle_hp, "kale hasar aldı")

	battle.queue_free()
	await get_tree().process_frame


## --------------------------------------------------------------------------
## Gerçek dokunma girdisi
## --------------------------------------------------------------------------

## Oyunun iç metotları değil, gerçek InputEvent yolu sınanır: çarkta kelime
## kurma ve yuvaya dokunup kule dikme. Bu test, kök Control'ün dokunuşları
## yuttuğu ve yuvaların hiç tıklanamadığı hatayı yakalamak için eklendi.
func _test_touch_input() -> void:
	SceneRouter.pending_level_id = 4
	var battle: Node = load("res://scenes/Oyun.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	await get_tree().process_frame

	var wheel: LetterWheel = battle.wheel
	var level := LevelDB.get_level(4)

	# Çarktan gerçekten kurulabilen bir kategori kelimesi seç.
	var word := ""
	for category in level.get("kategori_kelimeler", {}):
		for candidate in level["kategori_kelimeler"][category]:
			if word == "":
				word = str(candidate)
	_check(word != "", "seviyede kategori kelimesi var")

	# Harfleri taşlara eşle.
	var stones: Array = []
	var upper := TurkishText.to_upper(word)
	for i in upper.length():
		for stone in wheel.letters.size():
			if not stones.has(stone) and wheel.letters[stone] == upper[i]:
				stones.append(stone)
				break
	_equal(stones.size(), upper.length(), "kelimenin her harfi çarkta bulundu")

	# Parmağı taşların üzerinden gerçek dokunma olaylarıyla geçir.
	_touch(wheel, wheel._positions[stones[0]], true)
	await get_tree().process_frame
	_check(wheel._selection.size() == 1, "dokunma ilk harfi seçti")
	for index in range(1, stones.size()):
		_drag(wheel, wheel._positions[stones[index]])
		await get_tree().process_frame
	_equal(wheel._selection.size(), stones.size(), "kaydırma tüm harfleri seçti")
	_touch(wheel, wheel._positions[stones[stones.size() - 1]], false)
	await get_tree().process_frame
	_check(battle._found_words.has(word), "parmak kalkınca kelime kabul edildi: %s" % word)

	# Kule hazır olana kadar kelime göndermeye devam et.
	for candidate in level.get("cozum_kelimeler", []):
		if not battle.towers.ready_types().is_empty():
			break
		battle._on_word_submitted(str(candidate))
	_check(not battle.towers.ready_types().is_empty(), "inşa puanı kule için doldu")

	# Boş bir yuvaya GERÇEK dokunma olayı gönder; kule dikilmeli.
	var target: TowerSlot = null
	for slot in battle.battlefield.slots:
		if slot.is_empty():
			target = slot
			break
	_check(target != null, "boş yuva var")
	var before: int = (battle.battlefield.towers() as Array).size()
	_touch(battle.battlefield, target.position, true)
	await get_tree().process_frame
	_check(battle.battlefield.towers().size() > before,
		"yuvaya dokunmak kule dikti (%d -> %d)" % [before, battle.battlefield.towers().size()])

	# Hiçbir yuva HUD üst şeridinin altında kalmamalı; yoksa yuvaya dokunmak
	# duraklat düğmesine basar.
	var under_hud := 0
	for slot in battle.battlefield.slots:
		if slot.position.y < Battlefield.TOP_UI_CLEARANCE:
			under_hud += 1
	_equal(under_hud, 0, "hiçbir yuva HUD üst şeridinin altında değil")

	# Her yuva en kısa menzilli saldırı kulesinin yolu dövebileceği kadar yola
	# yakın olmalı. Bu sağlanmazsa kuleler hiçbir düşmana yetişemez ve seviye
	# yalnızca Şifa Çeşmesi'yle "kazanılır" — oynanış tamamen bozulur.
	var shortest_range := INF
	for tower_type in GameConfig.TOWERS:
		var config: Dictionary = GameConfig.TOWERS[tower_type]
		var reach := float(config["menzil"])
		if reach > 0.0:
			shortest_range = minf(shortest_range, reach)
	var out_of_reach := 0
	for slot in battle.battlefield.slots:
		var nearest := INF
		for track in battle.battlefield.tracks:
			nearest = minf(nearest, (track as PathTrack).distance_to_path(slot.position))
		if nearest > shortest_range:
			out_of_reach += 1
		# Yuva yolun üstünde de olmamalı.
		_check(nearest >= PathTrack.PATH_WIDTH * 0.5,
			"yuva %d yolun üstünde değil (%.0f px)" % [slot.index, nearest])
	_equal(out_of_reach, 0,
		"her yuva en kısa kule menzilinden (%.0f px) yakın" % shortest_range)

	battle.queue_free()
	await get_tree().process_frame


## Kontrole yerel koordinatta gerçek bir dokunma olayı gönderir.
func _touch(control: Control, local_point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = pressed
	event.position = _to_window(control, local_point)
	Input.parse_input_event(event)


func _drag(control: Control, local_point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = _to_window(control, local_point)
	Input.parse_input_event(event)


## Girdi olayları pencere uzayında beklenir; oyun 1080x1920 tuvalini pencereye
## ölçeklediği için dönüşüm gerekir.
func _to_window(control: Control, local_point: Vector2) -> Vector2:
	var canvas: Vector2 = control.get_global_transform_with_canvas() * local_point
	return get_viewport().get_screen_transform() * canvas


## --------------------------------------------------------------------------
## Fare girdisi
## --------------------------------------------------------------------------

## Masaüstünde oyun fareyle oynanır. Projede emulate_touch_from_mouse açık
## olduğu için fare olayları ayrıca dokunma olayına da çevrilir; çarkın her iki
## olay tipini de işlemesi çift tetiklemeye yol açmamalı.
func _test_mouse_input() -> void:
	SceneRouter.pending_level_id = 4
	var battle: Node = load("res://scenes/Oyun.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	await get_tree().process_frame

	var wheel: LetterWheel = battle.wheel
	var level := LevelDB.get_level(4)
	var word := ""
	for category in level.get("kategori_kelimeler", {}):
		for candidate in level["kategori_kelimeler"][category]:
			if word == "":
				word = str(candidate)

	var stones: Array = []
	var upper := TurkishText.to_upper(word)
	for i in upper.length():
		for stone in wheel.letters.size():
			if not stones.has(stone) and wheel.letters[stone] == upper[i]:
				stones.append(stone)
				break

	_click(wheel, wheel._positions[stones[0]], true)
	await get_tree().process_frame
	_equal(wheel._selection.size(), 1, "fare tıklaması ilk harfi seçti (çift eklemedi)")
	for index in range(1, stones.size()):
		_move(wheel, wheel._positions[stones[index]])
		await get_tree().process_frame
	_equal(wheel._selection.size(), stones.size(), "fareyi sürüklemek harfleri sırayla seçti")
	_click(wheel, wheel._positions[stones[stones.size() - 1]], false)
	await get_tree().process_frame
	_check(battle._found_words.has(word), "fare bırakılınca kelime kabul edildi: %s" % word)
	_equal(battle._found_words.size(), 1, "kelime yalnızca bir kez sayıldı")

	battle.queue_free()
	await get_tree().process_frame


func _click(control: Control, local_point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = _to_window(control, local_point)
	Input.parse_input_event(event)


func _move(control: Control, local_point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = _to_window(control, local_point)
	Input.parse_input_event(event)


## --------------------------------------------------------------------------
## Çizim sırası
## --------------------------------------------------------------------------

## Godot'ta z_index kardeş düğümler arasındaki ağaç sırasını ezer. Savaş alanı
## iç katmanları için z_index 1..9 kullanıyor; arayüze açıkça daha yüksek z
## verilmezse yol, kule, düşman ve efektler HUD'un, öğreticinin ve duraklatma
## perdesinin üstüne çiziliyor (menü ve öğretici yazıları görünmüyordu).
func _test_ui_layering() -> void:
	SceneRouter.pending_level_id = 4
	var battle: Node = load("res://scenes/Oyun.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	await get_tree().process_frame

	var deepest := _max_z(battle.battlefield)
	_check(deepest > 0, "savaş alanı iç katmanları z_index kullanıyor (%d)" % deepest)
	_check(battle.wheel.z_index > deepest,
		"harf çarkı savaş alanının üstünde (%d > %d)" % [battle.wheel.z_index, deepest])
	_check(battle.hud.z_index > battle.wheel.z_index,
		"HUD çarkın üstünde (%d > %d)" % [battle.hud.z_index, battle.wheel.z_index])
	_check(battle.tutorial.z_index > battle.hud.z_index,
		"öğretici HUD'un üstünde (%d > %d)" % [battle.tutorial.z_index, battle.hud.z_index])

	# Duraklatma perdesi her şeyin üstünde olmalı ve ekranı tam kaplamalı.
	battle._toggle_pause()
	await get_tree().process_frame
	var overlay: Control = null
	for child in battle.get_children():
		if child is ColorRect and (child as ColorRect).color.a > 0.5:
			overlay = child
	_check(overlay != null, "duraklatma perdesi oluşturuldu")
	if overlay != null:
		_check(overlay.z_index > battle.tutorial.z_index,
			"duraklatma perdesi en üstte (%d)" % overlay.z_index)
		_check(overlay.size.x >= battle.size.x and overlay.size.y >= battle.size.y,
			"duraklatma perdesi ekranı tam kaplıyor (%s)" % overlay.size)
	battle._toggle_pause()
	get_tree().paused = false

	battle.queue_free()
	await get_tree().process_frame



## Yürüyüş şeritlerinin geçerliliği ve karelerin gerçekten ilerlediği.
## "Testler geçiyor" tek başına animasyonun aktığını göstermez: şerit eşit
## hücrelere bölünemiyorsa ya da kare indeksi hep aynı kalıyorsa düşman yine
## sabit görünür, üstelik hiçbir hata da vermez.
func _test_walk_animation() -> void:
	var SB := preload("res://scripts/core/SpriteBank.gd")
	var sheets := 0
	for type_id in GameConfig.ENEMIES:
		var sheet: Texture2D = SB.enemy_walk(type_id)
		if sheet == null:
			continue
		sheets += 1
		_check(sheet.get_width() % SB.WALK_FRAMES == 0,
			"%s şeridi %d eşit hücreye bölünüyor (genişlik %d)"
				% [type_id, SB.WALK_FRAMES, sheet.get_width()])
		# Hücre dikeyden daha geniş olmamalı; olursa kesim kaymış demektir.
		var cell := sheet.get_width() / SB.WALK_FRAMES
		_check(cell < sheet.get_height(),
			"%s hücresi makul oranda (%dx%d)" % [type_id, cell, sheet.get_height()])
	_check(sheets >= 5, "en az beş düşmanın yürüyüş şeridi var (%d)" % sheets)

	# Kare indeksi bir tam döngüde dört değerin hepsini görmeli.
	SceneRouter.pending_level_id = 1
	var battle: Node = load("res://scenes/Oyun.tscn").instantiate()
	add_child(battle)
	for i in 3:
		await get_tree().process_frame

	var enemy := Enemy.new()
	battle.battlefield.add_child(enemy)
	enemy.configure("goblin", battle.battlefield.track, 1.0)
	var seen := {}
	for step in 40:
		enemy._walk += 0.25
		seen[posmod(int(enemy._walk * Enemy.WALK_FRAME_RATE), SB.WALK_FRAMES)] = true
	_check(seen.size() == SB.WALK_FRAMES,
		"kare indeksi dört karenin hepsini geziyor (%d)" % seen.size())
	enemy.queue_free()
	battle.queue_free()
	await get_tree().process_frame


## Üretilen yol, kule yuvalarını menzil dışında bırakmamalı.
##
## Bu oynanabilirliğin can damarı: yuvalar yola uzak kalırsa kuleler hiçbir
## düşmanı vuramaz ve bölüm kazanılamaz. Yol artık bölüme göre üretildiği için
## altmış bölümün HEPSİ tek tek denetlenir — örnekleme yetmez, tek bir kötü
## tohum bir bölümü oynanamaz yapar.
func _test_slot_coverage() -> void:
	var field := Battlefield.new()
	field.size = Vector2(1080, 1000)
	add_child(field)
	await get_tree().process_frame

	var worst_level := 0
	var worst_ratio := 0.0
	var failures := 0
	for level_id in range(1, GameConfig.TOTAL_LEVELS + 1):
		var level := LevelDB.get_level(level_id)
		field.region_theme = GameConfig.theme_of_level(level_id)
		field.layout_seed = level_id
		field.build(int(level.get("yol_sayisi", 1)), int(level.get("slot_sayisi", 4)))
		await get_tree().process_frame

		var reach := field.shortest_attack_range() * Battlefield.RELAXED_RANGE_RATIO
		for slot in field.slots:
			var nearest := INF
			for track in field.tracks:
				nearest = minf(nearest, track.distance_to_path(slot.position))
			var ratio := nearest / maxf(reach, 1.0)
			if ratio > worst_ratio:
				worst_ratio = ratio
				worst_level = level_id
			if nearest > reach:
				failures += 1

	print("      en uzak yuva: seviye %d, menzilin %.2f katı" % [worst_level, worst_ratio])
	_check(failures == 0,
		"her bölümde bütün yuvalar menzil içinde (%d yuva dışarıda)" % failures)
	field.queue_free()
	await get_tree().process_frame


## Her bölümün kendi yolu ve yuva yerleşimi olmalı; aynı bölüm ise her
## açılışta aynısını vermeli.
##
## Bölge içindeki 15 bölüm önceden aynı şablonu kullanıyordu — hepsi birebir
## aynı sahada oynanıyordu ve bu hiçbir teste takılmıyordu.
func _test_level_layout() -> void:
	var rect := Rect2(0, 0, 1080, 1000)
	var shapes := {}
	for level_id in [1, 2, 3, 8, 15, 22, 30, 41, 52, 60]:
		var track := PathTrack.new()
		add_child(track)
		track.setup(0, rect, level_id)
		shapes[level_id] = _path_signature(track)
		# Aynı bölüm iki kez kurulunca aynı yolu vermeli.
		track.setup(0, rect, level_id)
		_check(_path_signature(track) == shapes[level_id],
			"seviye %d yolu kararlı (aynı tohum aynı yol)" % level_id)
		track.queue_free()
	await get_tree().process_frame

	var unique := {}
	for key in shapes:
		unique[shapes[key]] = true
	_check(unique.size() >= 8,
		"on bölümün en az sekizi farklı yol veriyor (%d)" % unique.size())

	# Uzunluk bandı: yol uzunluğu düşmanın kaleye varma süresini belirliyor,
	# serbest bırakılırsa zorluk bölümden bölüme rastgele kayar.
	var reference := 0.0
	var template := PathTrack.new()
	add_child(template)
	template.setup(0, rect, 0)
	reference = template.length()
	template.queue_free()
	await get_tree().process_frame

	for level_id in [1, 8, 15, 22, 30, 41, 52, 60]:
		var track := PathTrack.new()
		add_child(track)
		track.setup(0, rect, level_id)
		var ratio := track.length() / maxf(reference, 1.0)
		_check(ratio > 0.75 and ratio < 1.30,
			"seviye %d yol uzunluğu bandın içinde (%.2fx)" % [level_id, ratio])
		track.queue_free()
	await get_tree().process_frame


## Yolun köşe noktalarından kısa bir imza; iki yolu karşılaştırmak için.
func _path_signature(track: PathTrack) -> String:
	var parts: PackedStringArray = []
	for i in range(0, int(track.length()), 120):
		var point := track.position_at(float(i))
		parts.append("%d,%d" % [int(point.x / 12.0), int(point.y / 12.0)])
	return ",".join(parts)


## Sağa yürüyen düşman kendi konumunda aynalanmalı.
##
## Bu testin sebebi gerçek bir hata: Rect2'ye negatif genişlik vermek Godot'ta
## dokuyu çevirmiyor, kendi genişliği kadar sağa kaydırıyor. Sağa giden
## düşmanlar yolun yanında yürüyordu ve hiçbir hata mesajı çıkmıyordu — ancak
## piksel ölçerek yakalanabildi.
##
## Çizim gerektirdiği için başsız (--headless) koşuda atlanır; ekranlı koşuda
## (xvfb) çalışır.
func _test_sprite_flip() -> void:
	if DisplayServer.get_name() == "headless":
		print("      (başsız koşu — çizim ölçümü atlandı)")
		return

	var SB := preload("res://scripts/core/SpriteBank.gd")
	var sheet: Texture2D = SB.enemy_walk("goblin")
	if sheet == null:
		_check(false, "goblin yürüyüş şeridi yüklendi")
		return

	# Ölçüm KENDİ görüntü alanında yapılır. Ana görüntü alanı kullanıldığında
	# önceki testlerden kalan sahneler (öğretici kartı) sprite'ların üstünü
	# kapatıyordu ve test aslında onları ölçüyordu — hata vermeden.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1080, 900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var canvas := _FlipCanvas.new()
	canvas.sheet = sheet
	viewport.add_child(canvas)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var shot := viewport.get_texture().get_image()
	if OS.has_environment("KK_SONDA"):
		shot.save_png("user://sonda_yon.png")

	var boxes := []
	for center in _FlipCanvas.CENTERS:
		var x0 := 1 << 30
		var x1 := -1
		for y in range(300, 900, 2):
			for x in range(int(center) - 150, int(center) + 150):
				if _differs(shot, x, y):
					x0 = mini(x0, x)
					x1 = maxi(x1, x)
		boxes.append([x0, x1])
	viewport.queue_free()
	await get_tree().process_frame

	_check(boxes[0][1] > boxes[0][0], "sağa yürüyen sprite çizildi")
	_check(boxes[1][1] > boxes[1][0], "sola yürüyen sprite çizildi")
	_check(boxes[2][1] > boxes[2][0], "ham doku çizildi")
	if boxes[0][1] <= boxes[0][0] or boxes[1][1] <= boxes[1][0]:
		return

	var width_left: int = boxes[0][1] - boxes[0][0]
	var width_right: int = boxes[1][1] - boxes[1][0]
	_check(absi(width_left - width_right) <= 2,
		"iki yön aynı genişlikte (%d / %d)" % [width_left, width_right])
	for i in 3:
		var middle: float = (boxes[i][0] + boxes[i][1]) * 0.5
		_check(absf(middle - _FlipCanvas.CENTERS[i]) <= 6.0,
			"sprite kendi konumunda (%d: merkez %.1f, beklenen %.1f)"
				% [i, middle, _FlipCanvas.CENTERS[i]])

	# Asıl mesele: HANGİ yönün aynalandığı. Görseller sağa bakacak şekilde
	# çizildi, yani sağa yürüyen ham dokuyla AYNI, sola yürüyen onun aynası
	# olmalı. Bu kural ters kurulduğunda düşmanlar iki yönde de gittikleri
	# yönün tersine bakıyordu ve konum ölçümü bunu yakalamıyordu.
	# Karşılaştırma bloğun nominal merkezine göre değil, ÖLÇÜLEN sprite
	# merkezine göre hizalanır: karakter hücrenin içinde birkaç piksel yana
	# kaçık ve aynalama bu kaçıklığı ikiye katlıyor.
	var mid: Array = []
	for box in boxes:
		mid.append((box[0] + box[1]) * 0.5)
	var same := _overlap(shot, mid[0], mid[2], false)
	var mirrored := _overlap(shot, mid[1], mid[2], true)
	var wrong := _overlap(shot, mid[1], mid[2], false)
	_check(same > 0.85, "sağa yürüyen ham dokuyla aynı (%.2f)" % same)
	_check(mirrored > wrong + 0.15,
		"sola yürüyen ham dokunun aynası: ayna %.2f > düz %.2f" % [mirrored, wrong])
	_check(same > wrong + 0.15,
		"çevirme yönü doğru: aynı %.2f, ters %.2f" % [same, wrong])


## İki bloğun örtüşme oranı. `mirror` açıkken ikinci blok yatay çevrilerek
## karşılaştırılır.
##
## Karşılaştırma RENK üzerinden yapılır, silüet üzerinden değil: karakterlerin
## dış hatları neredeyse simetrik olduğu için silüet aynalansa da %96 örtüşüyor
## ve yön hatasını göstermiyordu. Bıçak, göz ve pelerin gibi ayrıntılar ancak
## renkle ayırt ediliyor.
func _overlap(shot: Image, first: float, second: float, mirror: bool) -> float:
	var hit := 0
	var total := 0
	for y in range(500, 820, 2):
		for x in range(-120, 120, 2):
			var left := Vector2i(int(round(first)) + x, y)
			var offset := -x if mirror else x
			var right := Vector2i(int(round(second)) + offset, y)
			var a := _differs(shot, left.x, left.y)
			var b := _differs(shot, right.x, right.y)
			if not (a or b):
				continue
			total += 1
			if a and b and _same_color(shot, left, right):
				hit += 1
	return float(hit) / maxf(total, 1)


func _same_color(shot: Image, first: Vector2i, second: Vector2i) -> bool:
	var a := shot.get_pixel(first.x, first.y)
	var b := shot.get_pixel(second.x, second.y)
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.22


func _differs(img: Image, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return false
	var c := img.get_pixel(x, y)
	var background := Color(0.078, 0.086, 0.129)
	return absf(c.r - background.r) + absf(c.g - background.g) \
		+ absf(c.b - background.b) > 0.12


## Sözlük ve bölüm verisi küfür içermemeli; erken bölümlerde oyuncunun
## gerçekten bulabileceği yeterince kelime olmalı.
##
## İkisi de ölçülmüş hata: 1. bölümün çözüm listesinde müstehcen bir kelime
## vardı; aynı listede "esik, kesi, nesi, sek, seki" gibi ağız/eskimiş
## maddeler çoğunluktaydı ve "3 harf 0/7" göstergesi hiç dolmuyordu.
func _test_word_quality() -> void:
	# Örnek küfür listesi: hepsi TDK listesinde vardı, artık sözlükte olmamalı.
	var yasak := ["sik", "bok", "göt", "orospu", "piç", "kahpe", "yarak",
		"puşt", "ibne", "kaltak", "yavşak", "osuruk", "am"]
	var sizan := 0
	for word in yasak:
		if WordEngine.contains(word):
			sizan += 1
			printerr("    sözlükte kalmış: %s" % word)
	_equal(sizan, 0, "küfür sözlüğe girmiyor")

	# Masum kelimeler elenmemiş olmalı: filtre tam eşleşme, alt dize değil.
	for word in ["sikke", "boks", "yavşan", "sıçan", "kaşar", "götürmek", "fahiş"]:
		_check(WordEngine.contains(word), "masum kelime korundu: %s" % word)

	var eksik_bolum := 0
	var en_dusuk := 999
	var en_dusuk_bolum := 0
	for level_id in range(1, GameConfig.TOTAL_LEVELS + 1):
		var level := LevelDB.get_level(level_id)
		var yaygin: Array = level.get("yaygin_kelimeler", [])
		var cozum: Array = level.get("cozum_kelimeler", [])
		_check(not yaygin.is_empty(), "seviye %d yaygın kelime listesi taşıyor" % level_id)

		# Küfür bölüm verisine de sızmamalı.
		for word in cozum:
			if yasak.has(str(word)):
				sizan += 1

		# Oyuncunun bulabileceği kelime sayısı: gösterge dolabilmeli.
		if yaygin.size() < en_dusuk:
			en_dusuk = yaygin.size()
			en_dusuk_bolum = level_id
		if yaygin.size() < 7:
			eksik_bolum += 1
	_equal(sizan, 0, "küfür bölüm verisinde de yok")
	_equal(eksik_bolum, 0,
		"her bölümde en az 7 yaygın kelime var (en azı seviye %d: %d)"
			% [en_dusuk_bolum, en_dusuk])

	# İlk bölge en kırılgan yer: yeni oyuncu burada bırakır.
	var oran_toplam := 0.0
	for level_id in range(1, 16):
		var level := LevelDB.get_level(level_id)
		var yaygin: float = float((level.get("yaygin_kelimeler", []) as Array).size())
		var cozum: float = maxf(float((level.get("cozum_kelimeler", []) as Array).size()), 1.0)
		oran_toplam += yaygin / cozum
	var ortalama := oran_toplam / 15.0
	_check(ortalama >= 0.50,
		"ilk bölgede çözümlerin en az yarısı yaygın kelime (%%%.0f)" % (ortalama * 100.0))


## Yol, her bölgede zeminden ayırt edilebilmeli.
##
## Ölçülmüş hata: elle çizilen yol dokuları bölge zeminleriyle aynı paletten
## geldiği için buz ve ejder bölgelerinde yol zemine karışıyordu — doku ile
## zemin dosyalarının ortalama renk farkı 765 ölçeğinde 15 ve 2. Ekranda yol
## bir patika değil, ince gri çizgilerden oluşan bir labirent gibi
## görünüyordu. Bu test sahayı gerçekten render edip yolun üstündeki
## piksellerle yoldan uzak piksellerin farkını ölçer.
func _test_road_contrast() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1080, 1000)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var field := Battlefield.new()
	field.size = Vector2(1080, 1000)
	viewport.add_child(field)

	var en_dusuk := 1000.0
	var en_dusuk_bolge := ""
	for level_id in [1, 20, 40, 55]:
		field.region_theme = GameConfig.theme_of_level(level_id)
		field.layout_seed = level_id
		field.build(1, 4)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var shot := viewport.get_texture().get_image()

		var track: PathTrack = field.tracks[0]
		var yol := Color(0, 0, 0, 0)
		var yol_adet := 0
		var zemin := Color(0, 0, 0, 0)
		var zemin_adet := 0
		# HUD şeridinin altındaki bandı örnekle: üstteki arayüz ölçümü bozmasın.
		for y in range(int(Battlefield.TOP_UI_CLEARANCE) + 40, 940, 7):
			for x in range(20, 1060, 7):
				var uzaklik := track.distance_to_path(Vector2(x, y))
				if uzaklik < PathTrack.PATH_WIDTH * 0.30:
					yol += shot.get_pixel(x, y)
					yol_adet += 1
				elif uzaklik > PathTrack.PATH_WIDTH * 1.60:
					zemin += shot.get_pixel(x, y)
					zemin_adet += 1
		if yol_adet == 0 or zemin_adet == 0:
			continue
		yol /= float(yol_adet)
		zemin /= float(zemin_adet)
		var fark := (absf(yol.r - zemin.r) + absf(yol.g - zemin.g)
			+ absf(yol.b - zemin.b)) * 255.0
		print("      %s: yol-zemin farkı %.0f" % [field.region_theme.get("id", ""), fark])
		if fark < en_dusuk:
			en_dusuk = fark
			en_dusuk_bolge = str(field.region_theme.get("id", ""))
	viewport.queue_free()
	await get_tree().process_frame

	# 60: gözle bakıldığında yolun zeminden ayrıldığı alt sınır. Ölçümden önce
	# buz 15, ejder 2 idi.
	_check(en_dusuk >= 60.0,
		"her bölgede yol zeminden ayırt ediliyor (en zayıfı %s, fark %.0f)"
			% [en_dusuk_bolge, en_dusuk])


## Kalabalık çarkta parmak yolu, hedef olmayan taşlara değmemeli.
##
## Ölçülmüş hata: iki taş arasında düz çizgi çizmek 7-8 harfli çarklarda
## aradaki taşların üstünden geçiyordu. LetterWheel parmağın değdiği HER taşı
## kelimeye ekliyor, yani gönderilen kelime bozuk çıkıyordu. Bu, otomatik
## oynatıcının denge taramasını tamamen geçersiz kılmıştı: 40. bölümde
## 55 saniyede sıfır kelime kabul edilmişti. Hata --hizli kipinde gizlenmişti,
## çünkü kare başına 175 piksel ilerleyen bot aradaki taşların üstünden
## atlıyordu; gerçek oyuncu böyle oynayamaz.
func _test_swipe_routing() -> void:
	# 8 harfli çark: taşlar birbirine en yakın olduğu durum.
	var level_id := 0
	for candidate in range(1, GameConfig.TOTAL_LEVELS + 1):
		if (LevelDB.get_level(candidate).get("harfler", []) as Array).size() >= 8:
			level_id = candidate
			break
	if level_id == 0:
		_check(true, "8 harfli çark yok — yönlendirme denetimi atlandı")
		return

	SceneRouter.pending_level_id = level_id
	var battle: Node = load("res://scenes/Oyun.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	await get_tree().process_frame
	var wheel: LetterWheel = battle.wheel

	# Karşılıklı iki taş: aradan geçen düz çizgi çarkın ortasındaki taşlara
	# değil ama komşu taşlara değer; en zorlu durum uzak taş çiftleridir.
	var pilot := preload("res://scripts/tests/DemoPilot.gd")
	var worst := 0
	var checked := 0
	for a in wheel.letters.size():
		for b in wheel.letters.size():
			if a == b:
				continue
			checked += 1
			var path: Array = pilot.swipe_path(wheel, [a, b])
			# Yol boyunca hangi taşlara değildiğini say.
			var touched := {}
			for i in range(1, path.size()):
				for stone in wheel._positions.size():
					var closest := Geometry2D.get_closest_point_to_segment(
						wheel._positions[stone], path[i - 1], path[i])
					if closest.distance_to(wheel._positions[stone]) \
							<= maxf(wheel._stone_radius * LetterWheel.TOUCH_SLACK, 44.0):
						touched[stone] = true
			touched.erase(a)
			touched.erase(b)
			worst = maxi(worst, touched.size())
	_check(checked > 0, "taş çiftleri denendi (%d)" % checked)
	_equal(worst, 0, "hiçbir parmak yolu hedef dışı taşa değmiyor")

	# Uçtan uca: yolun gerçekten o kelimeyi ürettiğini dokunma olaylarıyla
	# doğrula.
	var word := ""
	for candidate in LevelDB.get_level(level_id).get("cozum_kelimeler", []):
		if str(candidate).length() >= 4:
			word = str(candidate)
			break
	var stones: Array = []
	var upper := TurkishText.to_upper(word)
	for i in upper.length():
		for stone in wheel.letters.size():
			if not stones.has(stone) and wheel.letters[stone] == upper[i]:
				stones.append(stone)
				break
	if stones.size() == upper.length():
		var path: Array = pilot.swipe_path(wheel, stones)
		wheel._selection.clear()
		_touch(wheel, path[0], true)
		await get_tree().process_frame
		# Parmağı gerçek adımlarla yürüt: sürükleme olayları arada atlamasın.
		for i in range(1, path.size()):
			var from: Vector2 = path[i - 1]
			var to: Vector2 = path[i]
			var steps := maxi(2, int(from.distance_to(to) / 12.0))
			for step in range(1, steps + 1):
				_drag(wheel, from.lerp(to, float(step) / steps))
				await get_tree().process_frame
		_equal(wheel.current_word(), upper, "yol tam olarak hedef kelimeyi üretti")
		_touch(wheel, path[path.size() - 1], false)
		await get_tree().process_frame
	battle.queue_free()
	await get_tree().process_frame


## Dokulu yol şeridi köşelerde delik bırakmamalı.
##
## Ölçülmüş hata: şerit parça parça dörtgenlerle çiziliyor ve köşelerde ardışık
## örnek noktalar ~3 piksel aralıkla gelirken yanal normal 45° dönüyor; dörtgen
## kendi üstüne katlanıyor. `draw_colored_polygon` böyle bir dörtgeni
## üçgenleyemeyip HİÇ çizmiyordu — her köşede yolda delik kalıyordu (tek
## bölümde 6 bin ila 14 bin piksel). Bu test dokulu katmanı tek başına, mor bir
## zeminin üstüne çizip merkez çizgi boyunca mor arıyor: eski çizim yöntemine
## dönülürse burada takılır.
func _test_road_strip() -> void:
	var bank := preload("res://scripts/core/SpriteBank.gd")
	var texture: Texture2D = bank.road("yesil_vadi")
	if texture == null:
		_check(true, "yol dokusu yok — şerit denetimi atlandı")
		return

	var viewport := SubViewport.new()
	viewport.size = _RoadCanvas.SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var canvas := _RoadCanvas.new()
	canvas.texture = texture
	viewport.add_child(canvas)

	var toplam_delik := 0
	var en_kotu := 0
	for level_id in [1, 4, 8, 15, 22, 37, 52]:
		var track := PathTrack.new()
		add_child(track)
		track.setup(0, Rect2(Vector2.ZERO, Vector2(_RoadCanvas.SIZE)), level_id)
		var baked := track.curve.get_baked_points()
		track.queue_free()

		canvas.baked = baked
		canvas.queue_redraw()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var shot := viewport.get_texture().get_image()

		# Merkez çizgi boyunca örnekle: şerit yarım genişlikte olduğu için
		# merkezdeki her nokta doku ile örtülmüş olmalı.
		var delik := 0
		for i in baked.size():
			var p := baked[i]
			var x := clampi(int(p.x), 0, shot.get_width() - 1)
			var y := clampi(int(p.y), 0, shot.get_height() - 1)
			var c := shot.get_pixel(x, y)
			if c.r > 0.75 and c.g < 0.25 and c.b > 0.75:
				delik += 1
		toplam_delik += delik
		en_kotu = maxi(en_kotu, delik)
	viewport.queue_free()
	await get_tree().process_frame

	_check(toplam_delik == 0,
		"yol şeridi köşelerde delik bırakmıyor (%d örnek nokta açıkta, en kötü bölümde %d)"
			% [toplam_delik, en_kotu])


## Yol dokusunu tek başına mor zemine çizen geçici tuval.
class _RoadCanvas extends Node2D:
	const SIZE := Vector2i(1080, 1000)
	## Delik rengi: dokuda bulunmayan bir ton.
	const HOLE := Color(1, 0, 1)
	var baked := PackedVector2Array()
	var texture: Texture2D

	func _ready() -> void:
		# PathTrack ile aynı: UV'ler 1'i aşıyor.
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE)), HOLE)
		if texture != null and baked.size() >= 2:
			PathTrack.draw_road_strip(self, baked, texture)


## Testin ölçeceği iki sprite'ı çizen geçici tuval. Enemy._draw ile aynı kalıbı
## kullanır: çevirme dış dönüşümde, SpriteBank pozitif dikdörtgenle çizer.
class _FlipCanvas extends Node2D:
	## 0: sağa yürüyen, 1: sola yürüyen, 2: ham doku (çevirmesiz).
	const CENTERS := [180.0, 540.0, 900.0]
	const RADIUS := 60.0
	var sheet: Texture2D

	func _draw() -> void:
		if sheet == null:
			return
		# Üç blok da AYNI zemine otursun: arkada kalan başka bir sahne
		# karşılaştırmayı bozuyordu.
		draw_rect(Rect2(0, 460, 1080, 400), Color(0.078, 0.086, 0.129))
		var bank := preload("res://scripts/core/SpriteBank.gd")
		for i in 3:
			var scale := Vector2(1.0, 1.0)
			if i < 2:
				# Enemy._draw ile aynı kural.
				scale.x = bank.facing_scale(1.0 if i == 0 else -1.0)
			draw_set_transform(Vector2(CENTERS[i], 700.0), 0.0, scale)
			bank.draw_enemy_frame(self, sheet, RADIUS, 0.0, 0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Çarkın üstündeki ilerleme şeridi ile taşlar üst üste binmemeli; taşlar da
## birbirine ve çarkın kenarlarına taşmamalı. Farklı telefon en/boy oranlarında
## kontrol edilir, çünkü stretch "expand" ile tuval yüksekliği cihaza göre değişir.
func _test_wheel_layout() -> void:
	var wheel := LetterWheel.new()
	add_child(wheel)
	await get_tree().process_frame

	# 4:3 tablet en basık hâl, 21:9 en uzun telefon.
	var aspects := {
		"4:3 tablet": 4.0 / 3.0,
		"16:9": 16.0 / 9.0,
		"18:9": 2.0,
		"19.5:9": 19.5 / 9.0,
		"20:9": 20.0 / 9.0,
		"21:9": 21.0 / 9.0,
	}
	var progress := {3: {"bulunan": 0, "toplam": 7}, 4: {"bulunan": 0, "toplam": 11},
		5: {"bulunan": 1, "toplam": 3}, 6: {"bulunan": 0, "toplam": 2}}

	# Çarkın ekranda kapladığı şerit Battle ile aynı oranda hesaplanmalı.
	var wheel_top: float = preload("res://scripts/gameplay/Battle.gd").WHEEL_TOP
	for aspect_name in aspects:
		var canvas_height: float = 1080.0 * float(aspects[aspect_name])
		var band_height: float = canvas_height * (1.0 - wheel_top)
		for count in [5, 6, 7, 8]:
			wheel.size = Vector2(1080.0, band_height)
			var letters: Array = []
			for i in count:
				letters.append("ABCDEFGH"[i])
			wheel.set_letters(letters)
			wheel.set_word_progress(progress)
			wheel._layout()

			var label := "%s / %d harf" % [aspect_name, count]
			var band_bottom: float = LetterWheel.PROGRESS_TOP + LetterWheel.PROGRESS_HEIGHT

			# 1) Hiçbir taş ilerleme şeridine girmemeli.
			var highest := INF
			for point in wheel._positions:
				highest = minf(highest, point.y - wheel._stone_radius)
			_check(highest >= band_bottom,
				"%s: taşlar ilerleme şeridinin altında (üst kenar %.1f >= %.1f)"
					% [label, highest, band_bottom])

			# 2) Taşlar birbirine binmemeli.
			var closest := INF
			for i in wheel._positions.size():
				var next: Vector2 = wheel._positions[(i + 1) % wheel._positions.size()]
				closest = minf(closest, wheel._positions[i].distance_to(next))
			# Seçili taş büyüdüğü için çap SELECTED_SCALE ile ölçülür.
			var widest := wheel._stone_radius * 2.0 * LetterWheel.SELECTED_SCALE
			_check(closest >= widest - 0.5,
				"%s: komşu taşlar seçiliyken de ayrık (mesafe %.1f >= çap %.1f)"
					% [label, closest, widest])

			# 3) Taşlar çarkın dışına taşmamalı ve en alttaki taş Android'in
			#    hareket şeridine girmemeli.
			var inside := true
			var lowest := -INF
			for point in wheel._positions:
				if point.x - wheel._stone_radius < 0.0 or point.x + wheel._stone_radius > wheel.size.x:
					inside = false
				lowest = maxf(lowest, point.y + wheel._stone_radius)
			_check(inside, "%s: taşlar yanlardan taşmıyor" % label)
			_check(lowest <= wheel.size.y - LetterWheel.BOTTOM_SAFE,
				"%s: en alt taş hareket şeridinden uzak (%.1f <= %.1f)"
					% [label, lowest, wheel.size.y - LetterWheel.BOTTOM_SAFE])

			# 4) Rozet satırı ekran genişliğine sığmalı.
			var labels := wheel._progress_labels(progress.keys(), true)
			var row := wheel._row_width(wheel._pill_widths(labels, 20))
			if row > wheel.size.x - 24.0:
				labels = wheel._progress_labels(progress.keys(), false)
				row = wheel._row_width(wheel._pill_widths(labels, LetterWheel.PROGRESS_MIN_FONT))
			_check(row <= wheel.size.x - 24.0,
				"%s: rozet satırı sığıyor (%.1f <= %.1f)" % [label, row, wheel.size.x - 24.0])

	wheel.queue_free()
	await get_tree().process_frame

	# Sentetik ölçüler doğru olsa da gerçek sahnede çarkın boyutu çapalardan
	# gelir ve ilerleme Battle tarafından doldurulur; aynı kuralı orada da sına.
	SceneRouter.pending_level_id = 4
	var battle: Node = load("res://scenes/Oyun.tscn").instantiate()
	add_child(battle)
	for i in 3:
		await get_tree().process_frame
	var live: LetterWheel = battle.wheel
	_check(not live._progress.is_empty(), "gerçek sahnede ilerleme şeridi dolu")
	var top_edge := INF
	for point in live._positions:
		top_edge = minf(top_edge, point.y - live._stone_radius)
	_check(top_edge >= LetterWheel.PROGRESS_TOP + LetterWheel.PROGRESS_HEIGHT,
		"gerçek sahnede taşlar şeridin altında (%.1f)" % top_edge)
	battle.queue_free()
	await get_tree().process_frame


## Ağaçtaki en yüksek ETKİN z_index. z_as_relative açıkken çocuğun z'si
## ebeveyninkine eklenir; ham değerlere bakmak yanıltıcı olur.
func _max_z(node: Node, inherited: int = 0) -> int:
	var own := inherited
	if node is CanvasItem:
		var item := node as CanvasItem
		own = (inherited + item.z_index) if item.z_as_relative else item.z_index
	var best := own
	for child in node.get_children():
		best = maxi(best, _max_z(child, own))
	return best


## --------------------------------------------------------------------------
## Bölüm haritası
## --------------------------------------------------------------------------

## Harita düğümleri ayrı Button değil; isabet _gui_input içinde en yakın
## düğüme bakılarak çözülüyor. Bu yüzden dokunma yolu ve kilit kuralları
## gerçek olayla sınanır.
func _test_kingdom_map() -> void:
	SaveManager.reset_progress()
	# İlk üç bölümü geç ki hem açık hem kilitli düğüm bulunsun.
	for level_id in [1, 2, 3]:
		SaveManager.record_level_result(level_id, 3, 1.0)

	var map := KingdomMap.new()
	map.custom_minimum_size = Vector2(1080, 0)
	map.size = Vector2(1080, 6000)
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame

	_equal(map._nodes.size(), GameConfig.TOTAL_LEVELS, "60 bölüm düğümü oluşturuldu")

	# Kilit durumu kayıt sistemiyle tutarlı olmalı.
	var mismatched := 0
	for node in map._nodes:
		var level_id := int(node["id"])
		var should_lock := not SaveManager.is_level_unlocked(level_id) \
			or not SaveManager.is_region_unlocked(int(node["bolge"]))
		if bool(node["kilitli"]) != should_lock:
			mismatched += 1
	_equal(mismatched, 0, "düğüm kilitleri kayıt durumuyla uyumlu")

	# "Tüm Bölümler" test anahtarı açıkken haritada TEK BİR kilit kalmamalı.
	#
	# Ölçülmüş hata: anahtar yalnızca bölüm kilidini kaldırıyordu, harita bölge
	# sisini kendi hesaplıyordu; ilk bölgenin 15 bölümü açılıyor, kalan 45'i
	# sisin altında kapalı kalıyordu.
	var previous_setting: Variant = SaveManager.get_setting("tum_bolumler", false)
	SaveManager.set_setting("tum_bolumler", true)
	map._rebuild()
	var locked := 0
	var fogged := 0
	for node in map._nodes:
		if bool(node["kilitli"]):
			locked += 1
	for band in map._region_bands:
		if not bool(band["acik"]):
			fogged += 1
	_equal(locked, 0, "tüm bölümler açıkken kilitli bölüm kalmıyor")
	_equal(fogged, 0, "tüm bölümler açıkken sisli bölge kalmıyor")
	SaveManager.set_setting("tum_bolumler", previous_setting)
	map._rebuild()

	# Düğümler dokunma yarıçapından daha yakın olmamalı, yoksa yanlış bölüm açılır.
	var too_close := 0
	for i in map._nodes.size():
		for j in range(i + 1, map._nodes.size()):
			var a: Vector2 = map._nodes[i]["konum"]
			var b: Vector2 = map._nodes[j]["konum"]
			if a.distance_to(b) < KingdomMap.NODE_TOUCH:
				too_close += 1
	_equal(too_close, 0, "hiçbir düğüm çifti dokunma yarıçapından yakın değil")

	# Boss düğümleri her 15. bölümde olmalı.
	var boss_count := 0
	for node in map._nodes:
		if bool(node["boss"]):
			boss_count += 1
			_equal(int(node["id"]) % GameConfig.LEVELS_PER_REGION, 0,
				"boss düğümü bölge sonunda (%d)" % int(node["id"]))
	_equal(boss_count, GameConfig.REGIONS.size(), "her bölgede bir boss düğümü")

	# Gerçek dokunma: açık bir düğüm sinyal yaymalı.
	var picked := [0]
	map.level_selected.connect(func(id): picked[0] = id)
	var open_node: Dictionary = {}
	var locked_node: Dictionary = {}
	for node in map._nodes:
		if not bool(node["kilitli"]) and open_node.is_empty():
			open_node = node
		if bool(node["kilitli"]) and locked_node.is_empty():
			locked_node = node
	_check(not open_node.is_empty(), "açık düğüm var")
	_check(not locked_node.is_empty(), "kilitli düğüm var")

	_touch(map, open_node["konum"], true)
	await get_tree().process_frame
	_equal(picked[0], int(open_node["id"]), "açık düğüme dokunmak bölümü seçti")

	picked[0] = 0
	_touch(map, locked_node["konum"], true)
	await get_tree().process_frame
	_equal(picked[0], 0, "kilitli düğüme dokunmak hiçbir şey yapmadı")

	map.queue_free()
	await get_tree().process_frame


## --------------------------------------------------------------------------
## Ekran duman testi
## --------------------------------------------------------------------------

## Her ekran hatasız kurulup ekranı kaplıyor mu? Ekranlar kod içinde
## kurulduğu için bir yazım hatası ancak o ekran açılınca ortaya çıkıyor;
## bu test hepsini tek koşuda dolaşır.
func _test_screens_open() -> void:
	SceneRouter.pending_level_id = 4
	SceneRouter.last_result = {
		"zafer": true, "seviye": 4, "yildiz": 3, "altin": 120,
		"kelime": 9, "kadim": 1, "oldurulen": 20, "can_orani": 0.9,
		"ilk_gecis": true, "sure": 75.0,
	}

	for key in SceneRouter.SCENES:
		var path: String = SceneRouter.SCENES[key]
		var scene: PackedScene = load(path)
		_check(scene != null, "sahne yüklendi: %s" % key)
		if scene == null:
			continue
		var instance := scene.instantiate()
		add_child(instance)
		await get_tree().process_frame
		await get_tree().process_frame

		var control := instance as Control
		_check(control != null, "%s bir Control" % key)
		if control != null:
			_check(control.size.x > 0.0 and control.size.y > 0.0,
				"%s ekranı kaplıyor (%s)" % [key, control.size])
			_check(control.get_child_count() > 0, "%s içerik kurdu" % key)
		instance.queue_free()
		await get_tree().process_frame
