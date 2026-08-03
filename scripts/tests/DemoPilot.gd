extends Node

## Otomatik oynatıcı — bir bölümü baştan sona oynar.
##
## Amaç: oyunun gerçekten oynanabildiğini kayıt alarak göstermek. Oyuncu
## girdisi taklit edilmez, gerçekten üretilir: harf çarkında parmak hareketi
## `InputEventScreenTouch`/`InputEventScreenDrag` olayları olarak enjekte edilir,
## kule yuvaları dokunma olayıyla açılır. Yani kayıt, gerçek dokunma yolunu
## kullanır — doğrudan iç metot çağrısı değil.
##
## Kayıt:
##   xvfb-run -a godot --path . --write-movie /tmp/demo.avi scenes/Demo.tscn

## Kaydedilecek bölüm. Komut satırından değiştirilebilir:
##   godot --headless --path . scenes/Demo.tscn -- --seviye=15 --hizli --yukseltme=5
const VARSAYILAN_SEVIYE := 26

const MAX_SECONDS := 260.0       ## güvenlik: bu süre dolunca çık
const AFTER_RESULT_SECONDS := 8.0
const FINGER_SPEED := 2100.0     ## piksel/sn (1080x1920 tuval biriminde)
const PAUSE_BETWEEN_WORDS := 0.55
const START_DELAY := 1.6

enum Phase { HAZIRLIK, DUSUN, KAYDIR, BEKLE, BITTI }

var battle: Node = null
var _phase: Phase = Phase.HAZIRLIK
var _timer := START_DELAY
var _pool: Array = []            ## henüz denenmemiş kelimeler
var _points: Array = []          ## geçerli kaydırmanın taş konumları (çark-yerel)
var _leg := 0                    ## kaçıncı taşa gidiyoruz
var _finger := Vector2.ZERO
var _touch_down := false
var _quit_armed := false
var _report := 0.0
var _elapsed := 0.0
var _tap_cooldown := 0.0
var level_id := VARSAYILAN_SEVIYE
var _tutorial_timer := 0.0


func _ready() -> void:
	# Oyun bir şekilde duraklatılırsa pilot yine de çalışsın (yoksa kayıt donar).
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Kayıt sırasında sabit adımlı döngü 30 FPS ölçüldüğü için otomatik kalite
	# düşürme devreye girerdi; kayıtta efektler tam kalsın diye 60 FPS modu sabitlenir.
	SaveManager.set_setting("kare_hizi", 1)
	# Süre sınırı: sahne değişse bile SceneTree üzerinde yaşar.
	get_tree().create_timer(MAX_SECONDS).timeout.connect(get_tree().quit)

	_read_args()
	SceneRouter.pending_level_id = level_id
	battle = load("res://scenes/Oyun.tscn").instantiate()
	add_child(battle)

	var level := LevelDB.get_level(level_id)
	_pool = _plan_words(level)
	print("[Demo] Seviye %d — %s | çark: %s | %d kelime planlandı" % [
		level_id, level.get("ad", ""), "".join(level.get("harfler", [])), _pool.size()])


## --seviye=N   oynanacak bölüm
## --hizli      zamanı hızlandır (denge taraması için; kayıt alırken kullanılmaz)
## --yukseltme=N  oyuncunun kalıcı yükseltmelerini N seviyeye ayarla
func _read_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seviye="):
			level_id = clampi(int(arg.split("=")[1]), 1, GameConfig.TOTAL_LEVELS)
		elif arg == "--hizli":
			Engine.time_scale = 5.0
		elif arg.begins_with("--yukseltme="):
			var seviye := int(arg.split("=")[1])
			for key in GameConfig.UPGRADES:
				SaveManager.set_upgrade_level(key,
					mini(seviye, int(GameConfig.UPGRADES[key]["max_seviye"])))


## Kelime sırası: önce kategori kelimeleri (kule tipini belirler), sonra uzun
## kelimeler (daha çok inşa puanı), en sonda kısalar.
func _plan_words(level: Dictionary) -> Array:
	var category_words: Array = []
	for category in level.get("kategori_kelimeler", {}):
		for word in level["kategori_kelimeler"][category]:
			category_words.append(str(word))

	var rest: Array = []
	for word in level.get("cozum_kelimeler", []):
		if not category_words.has(str(word)):
			rest.append(str(word))

	# Kategori kelimeleri uzundan kısaya, sonra kalanlar uzundan kısaya.
	category_words.sort_custom(func(a, b): return a.length() > b.length())
	rest.sort_custom(func(a, b): return a.length() > b.length())

	# İlk kule hızlı çıksın diye en uzun kategori kelimeleriyle başla, sonra
	# kalanları serpiştir ki kule çeşitliliği ve genel enerji birlikte gelsin.
	var plan: Array = []
	var i := 0
	var j := 0
	while i < category_words.size() or j < rest.size():
		if i < category_words.size():
			plan.append(category_words[i])
			i += 1
		if i < category_words.size():
			plan.append(category_words[i])
			i += 1
		if j < rest.size():
			plan.append(rest[j])
			j += 1
	return plan


func _process(delta: float) -> void:
	if battle == null or not is_instance_valid(battle):
		if not _quit_armed:
			_quit_armed = true
			print("[Demo] battle düğümü yok oldu (sahne değişmiş olabilir)")
			get_tree().create_timer(AFTER_RESULT_SECONDS).timeout.connect(get_tree().quit)
		return

	if battle._finished and _phase != Phase.BITTI:
		_phase = Phase.BITTI
		var hp: float = battle.battlefield.castle.health_ratio()
		print("[Demo] SONUC seviye=%d %s can=%%%d kelime=%d kule=%d sure=%.0fs" % [
			level_id, "ZAFER" if hp > 0.0 else "YENILGI", roundi(hp * 100.0),
			battle._found_words.size(), battle.battlefield.towers().size(), _elapsed])
		if not _quit_armed:
			_quit_armed = true
			get_tree().create_timer(AFTER_RESULT_SECONDS).timeout.connect(get_tree().quit)
		return
	if _phase == Phase.BITTI:
		return

	_elapsed += delta
	_report -= delta
	if _report <= 0.0:
		_report = 2.0
		print("[Demo] %5.1fs dalga=%d/%d kelime=%d kule=%d kale=%d/%d dusman=%d" % [
			_elapsed, battle.waves.current_index + 1, battle.waves.wave_count(),
			battle._found_words.size(), battle.battlefield.towers().size(),
			roundi(battle.battlefield.castle.hp), roundi(battle.battlefield.castle.max_hp),
			battle.battlefield.live_enemy_count()])

	_advance_tutorial(delta)
	_use_ulti_if_ready()
	_tap_cooldown -= delta
	_build_if_ready()

	match _phase:
		Phase.HAZIRLIK, Phase.BEKLE:
			_timer -= delta
			if _timer <= 0.0:
				_phase = Phase.DUSUN
		Phase.DUSUN:
			_choose_word()
		Phase.KAYDIR:
			_advance_finger(delta)


## --------------------------------------------------------------------------
## Kelime seçimi
## --------------------------------------------------------------------------

func _choose_word() -> void:
	var wheel: LetterWheel = battle.wheel
	var locked: Array = wheel.locked_indices()

	for index in _pool.size():
		var word: String = _pool[index]
		if battle._found_words.has(word):
			continue
		var stones := _stones_for(word, locked)
		if stones.is_empty():
			continue
		_pool.remove_at(index)
		_points = []
		for stone in stones:
			_points.append(wheel._positions[stone])
		_leg = 0
		_finger = _points[0]
		_press(_finger)
		_phase = Phase.KAYDIR
		return

	# Bu çarkta denenecek kelime kalmadı; dalgaların bitmesini bekle.
	_phase = Phase.BEKLE
	_timer = 1.0


## Kelimenin harflerini çarktaki taşlara eşler. Kilitli taş kullanılamaz;
## eşleşme kurulamazsa boş dizi döner (kelime bu tur atlanır).
func _stones_for(word: String, locked: Array) -> Array:
	var wheel: LetterWheel = battle.wheel
	var upper := TurkishText.to_upper(word)
	var used: Array = []
	var stones: Array = []
	for i in upper.length():
		var letter := upper[i]
		var found := -1
		for stone in wheel.letters.size():
			if used.has(stone) or locked.has(stone):
				continue
			if wheel.letters[stone] == letter:
				found = stone
				break
		if found < 0:
			return []
		used.append(found)
		stones.append(found)
	return stones


## --------------------------------------------------------------------------
## Parmak hareketi
## --------------------------------------------------------------------------

func _advance_finger(delta: float) -> void:
	var target: Vector2 = _points[_leg]
	var step := FINGER_SPEED * delta
	var to_target := target - _finger

	if to_target.length() <= step:
		_finger = target
		_drag(_finger)
		_leg += 1
		if _leg >= _points.size():
			_release(_finger)
			_phase = Phase.BEKLE
			_timer = PAUSE_BETWEEN_WORDS
		return

	_finger += to_target.normalized() * step
	_drag(_finger)


## Çark-yerel noktayı pencere koordinatına çevirir (girdi olayları pencere
## uzayında beklenir; oyun 1080x1920 tuvalini pencereye ölçekler).
func _to_window(local_point: Vector2) -> Vector2:
	var canvas: Vector2 = battle.wheel.get_global_transform_with_canvas() * local_point
	return get_viewport().get_screen_transform() * canvas


func _press(local_point: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = true
	event.position = _to_window(local_point)
	Input.parse_input_event(event)
	_touch_down = true


func _drag(local_point: Vector2) -> void:
	if not _touch_down:
		return
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = _to_window(local_point)
	Input.parse_input_event(event)


func _release(local_point: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = false
	event.position = _to_window(local_point)
	Input.parse_input_event(event)
	_touch_down = false


## --------------------------------------------------------------------------
## Kule dikme ve ulti
## --------------------------------------------------------------------------

func _build_if_ready() -> void:
	if _tap_cooldown > 0.0 or battle.towers.ready_types().is_empty():
		return
	for slot in battle.battlefield.slots:
		if not slot.is_empty():
			continue
		_tap_slot(slot)
		_tap_cooldown = 0.4
		return


## Yuvaya gerçek dokunma olayı gönderir (TowerSlot._unhandled_input dinler).
func _tap_slot(slot: TowerSlot) -> void:
	var canvas: Vector2 = slot.get_global_transform_with_canvas() * Vector2.ZERO
	var window: Vector2 = get_viewport().get_screen_transform() * canvas
	var press := InputEventScreenTouch.new()
	press.index = 1
	press.pressed = true
	press.position = window
	Input.parse_input_event(press)
	var release := InputEventScreenTouch.new()
	release.index = 1
	release.pressed = false
	release.position = window
	Input.parse_input_event(release)


func _use_ulti_if_ready() -> void:
	if battle._ulti_charge < 1.0:
		return
	if battle.battlefield.live_enemy_count() < 4:
		return
	battle._on_ulti()


## Öğretici balonu "Anladım" beklerken oyuncunun yapacağını yapar: metni
## okunacak kadar bekletip düğmeye basar. Diğer adımlar zaten oyuncunun
## eylemiyle (kelime bulma, kule dikme) kendiliğinden ilerler.
func _advance_tutorial(delta: float) -> void:
	var tutorial = battle.tutorial
	if tutorial == null or not tutorial.visible:
		_tutorial_timer = 0.0
		return
	if tutorial._waiting != "dokun":
		return
	_tutorial_timer += delta
	if _tutorial_timer >= 2.6:
		_tutorial_timer = 0.0
		tutorial._advance()
