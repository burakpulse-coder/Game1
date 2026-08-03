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
	_run("Ekonomi ve yükseltmeler", _test_economy)
	_run("Kayıt sistemi", _test_save)
	await _run_async("Savaş turu (uçtan uca)", _test_battle)

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
