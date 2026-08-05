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

## Güvenlik: bu süre dolunca çık. Uzun bölümlerin kaydı için --sure ile
## büyütülür (45. bölüm tek başına 232 saniye sürüyor).
var max_seconds := 260.0
const AFTER_RESULT_SECONDS := 8.0
const FINGER_SPEED := 2100.0     ## piksel/sn (1080x1920 tuval biriminde)
var pause_between_words := 0.55   ## --kelime-hizi ile insan temposuna çekilir
const START_DELAY := 1.6

## --------------------------------------------------------------------------
## İnsan profili (--insan)
## --------------------------------------------------------------------------
##
## Varsayılan pilot bir insanın yapamayacağı şeyleri yapıyor: bölümün bütün
## çözüm kelimelerini biliyor, en uzunlarını önce yazıyor, hiç yanlış
## denemiyor, parmağı saniyede 2100 piksel gidiyor ve kule ile ultiyi anında
## kullanıyor. Böyle bir pilotun bölümü geçmesi, bölümün bir insan için
## geçilebilir olduğunu göstermez.
##
## Aşağıdaki sayılar ölçüm değil, MODEL: "ortalama bir oyuncu" varsayımı.
## Amaç mutlak doğruluk değil, bölümleri birbiriyle aynı ölçütle
## karşılaştırabilmek.

## Kelime uzunluğuna göre "bu kelimeyi aklıma getirebilir miyim" olasılığı.
## Kısa kelimeler kolay bulunur, 7-8 harfliler nadiren akla gelir.
const HUMAN_VOCAB := {3: 0.92, 4: 0.78, 5: 0.55, 6: 0.32, 7: 0.18, 8: 0.10}
const HUMAN_VOCAB_MIN := 0.08          ## 9+ harf
## Somut isimler (hayvan/doğa/nesne/yiyecek) daha kolay akla gelir.
const HUMAN_CONCRETE_BONUS := 0.30     ## akla gelme şansına eklenir
const HUMAN_CONCRETE_HEAD_START := 2.5 ## sırada bu kadar öne alınır
const HUMAN_WORDS_PER_MINUTE := 11.0   ## ortalama tempo
const HUMAN_TEMPO_JITTER := 0.45       ## molalara ± bu oranda sapma
const HUMAN_MISTAKE_CHANCE := 0.18     ## denemelerin bu kadarı geçersiz kelime
const HUMAN_FINGER_SPEED := 850.0      ## piksel/sn
const HUMAN_BUILD_REACTION := Vector2(0.9, 2.4)  ## kule dikmeden önceki tepki
const HUMAN_ULTI_REACTION := 1.8       ## ulti düğmesini fark etme süresi
const HUMAN_ULTI_MISS := 0.30          ## ulti fırsatını tamamen kaçırma oranı

var human := false
var _rng := RandomNumberGenerator.new()
var _ulti_wait := -1.0

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
	_read_args()
	# Süre sınırı: sahne değişse bile SceneTree üzerinde yaşar.
	get_tree().create_timer(max_seconds).timeout.connect(get_tree().quit)

	SceneRouter.pending_level_id = level_id
	battle = load("res://scenes/Oyun.tscn").instantiate()
	battle.level_finished.connect(_on_level_finished)
	add_child(battle)

	var level := LevelDB.get_level(level_id)
	_pool = _plan_words(level)
	print("[Demo] Seviye %d — %s | çark: %s | %d/%d kelime planlandı%s" % [
		level_id, level.get("ad", ""), "".join(level.get("harfler", [])),
		_pool.size(), (level.get("cozum_kelimeler", []) as Array).size(),
		" (insan profili)" if human else ""])


## --seviye=N   oynanacak bölüm
## --sure=N     güvenlik süresi (sn); uzun bölümlerin kaydı için büyüt
## --hizli      zamanı hızlandır (denge taraması için; kayıt alırken kullanılmaz)
## --yukseltme=N  oyuncunun kalıcı yükseltmelerini N seviyeye ayarla
##                (--yukseltme=oto: bölüme kadar biriktirilebilecek kadar)
## --insan      ortalama bir oyuncuyu taklit et (sınırlı kelime dağarcığı,
##              insan temposu, yanlış denemeler, yavaş parmak, tepki gecikmesi)
func _read_args() -> void:
	var args := OS.get_cmdline_user_args()

	# Bölüm numarası önce okunur: --yukseltme=oto ona bakıyor, sıraya bağlı
	# kalmasın.
	for arg in args:
		if arg.begins_with("--seviye="):
			level_id = clampi(int(arg.split("=")[1]), 1, GameConfig.TOTAL_LEVELS)

	for arg in args:
		if arg.begins_with("--sure="):
			max_seconds = maxf(float(arg.split("=")[1]), 10.0)
		elif arg == "--hizli":
			Engine.time_scale = 5.0
		elif arg == "--insan":
			human = true
		elif arg.begins_with("--kelime-hizi="):
			# Dakikada kaç kelime bulunsun? Bot varsayılanı ~38/dk; gerçek bir
			# oyuncu 8-15/dk civarında. Denge insan temposunda ölçülmeli.
			var per_minute := maxf(float(arg.split("=")[1]), 1.0)
			# Kaydırma süresi ~0.8 sn; kalanı düşünme molası olarak eklenir.
			pause_between_words = maxf(60.0 / per_minute - 0.8, 0.2)
		elif arg.begins_with("--yukseltme="):
			var value := arg.split("=")[1]
			var seviye := _auto_upgrade_level() if value == "oto" else int(value)
			for key in GameConfig.UPGRADES:
				SaveManager.set_upgrade_level(key,
					mini(seviye, int(GameConfig.UPGRADES[key]["max_seviye"])))

	if human:
		# Tohum bölüme bağlı: aynı bölüm her koşuda aynı "oyuncuyu" yaşar,
		# yani liste tekrar üretilebilir olur.
		_rng.seed = level_id * 2654435761
		pause_between_words = maxf(60.0 / HUMAN_WORDS_PER_MINUTE - 1.4, 0.4)


## Bölüme kadar oynamış bir oyuncunun makul yükseltme seviyesi.
## 60. bölüme gelen oyuncu her şeyi 10'a çıkarmış olur; 1. bölümdeki hiçbir şey
## almamıştır. Aradaki bölümler doğrusal.
func _auto_upgrade_level() -> int:
	return clampi(roundi(level_id / 6.0), 0, 10)


## Ortalama bir oyuncunun bu çarkta gerçekten bulabileceği kelimeler.
##
## Üç fark var:
##  1. Dağarcık: uzun kelimeler nadiren akla gelir (HUMAN_VOCAB).
##  2. Sıra: insan uzunları öne almaz, aklına ilk geleni yazar.
##  3. Somut isimler öne geçer: harflere bakan biri "inek"i "eksin"den önce
##     görür. Oyunun kategori listesi (hayvan/doğa/nesne/yiyecek) tam olarak
##     bu somut isimlerden oluşuyor, o yüzden onlara öncelik verilir.
func _plan_words_human(level: Dictionary) -> Array:
	var category_words := {}
	for category in level.get("kategori_kelimeler", {}):
		for word in level["kategori_kelimeler"][category]:
			category_words[str(word)] = true

	var words: Array = []
	for word in level.get("cozum_kelimeler", []):
		var text := str(word)
		var chance: float = HUMAN_VOCAB.get(text.length(), HUMAN_VOCAB_MIN)
		if category_words.has(text):
			# Somut isim: akla gelme şansı belirgin yüksek.
			chance = minf(chance + HUMAN_CONCRETE_BONUS, 0.97)
		if _rng.randf() >= chance:
			continue
		# Sıralama anahtarı: kısa ve somut olan öne, ama kesin değil.
		var key := float(text.length()) + _rng.randf_range(-1.2, 1.2)
		if category_words.has(text):
			key -= HUMAN_CONCRETE_HEAD_START
		words.append([key, text])
	words.sort_custom(func(a, b): return a[0] < b[0])
	var plan: Array = []
	for entry in words:
		plan.append(entry[1])
	return plan


## Kelime sırası: önce kategori kelimeleri (kule tipini belirler), sonra uzun
## kelimeler (daha çok inşa puanı), en sonda kısalar.
func _plan_words(level: Dictionary) -> Array:
	if human:
		return _plan_words_human(level)
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

	if _phase == Phase.BITTI:
		return
	_elapsed += delta
	_report -= delta
	if _report <= 0.0:
		_report = 2.0
		print("[Demo] %5.1fs dalga=%d/%d kelime=%d kule=%d kale=%d/%d dusman=%d oldurulen=%d kuleler=%s" % [
			_elapsed, battle.waves.current_index + 1, battle.waves.wave_count(),
			battle._found_words.size(), battle.battlefield.towers().size(),
			roundi(battle.battlefield.castle.hp), roundi(battle.battlefield.castle.max_hp),
			battle.battlefield.live_enemy_count(), battle._enemies_killed,
			str((battle.battlefield.towers() as Array).map(func(t): return t.tower_type))])

	_advance_tutorial(delta)
	_use_ulti_if_ready(delta)
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

	# İnsan zaman zaman olmayan bir kelime dener: kaydırma süresi ve mola
	# harcanır, karşılığında hiçbir şey gelmez.
	if human and _rng.randf() < HUMAN_MISTAKE_CHANCE and _swipe_guess(locked):
		return

	for index in _pool.size():
		var word: String = _pool[index]
		if battle._found_words.has(word):
			continue
		var stones := _stones_for(word, locked)
		if stones.is_empty():
			continue
		_pool.remove_at(index)
		_points = swipe_path(wheel, stones)
		_leg = 0
		_finger = _points[0]
		_press(_finger)
		_phase = Phase.KAYDIR
		return

	# Bu çarkta denenecek kelime kalmadı; dalgaların bitmesini bekle.
	_phase = Phase.BEKLE
	_timer = 1.0


## Tutmayan bir deneme kaydırır.
##
## İnsanın yanlış denemesi rastgele bir zikzak DEĞİLDİR: aklındaki kelimenin
## yakınında bir şey dener — bir harf eksik ya da bir harf fazla. Bu ayrım
## ölçülebilir bir fark yaratıyor: rastgele taş dizisi çarkın bir ucundan
## diğerine dolaşıp bir kelimenin birkaç katı süre harcıyordu ve 20. bölümde
## hiç kule dikilememesinin tek başına sebebiydi.
##
## Sıradaki planlı kelimeyi bozarak deneme yapar; kelime plandan silinmez,
## oyuncu birazdan doğrusunu yazacaktır.
func _swipe_guess(locked: Array) -> bool:
	var wheel: LetterWheel = battle.wheel
	var stones: Array = []
	for word in _pool:
		if battle._found_words.has(word):
			continue
		stones = _stones_for(str(word), locked)
		if not stones.is_empty():
			break
	if stones.size() < 3:
		return false

	if _rng.randf() < 0.5 and stones.size() > 3:
		# Bir harf eksik dene.
		stones = stones.slice(0, stones.size() - 1)
	else:
		# Sona uygun olmayan bir harf ekle.
		var extra := -1
		for stone in wheel.letters.size():
			if not locked.has(stone) and not stones.has(stone):
				extra = stone
				if _rng.randf() < 0.5:
					break
		if extra < 0:
			return false
		stones.append(extra)

	_points = swipe_path(wheel, stones)
	_leg = 0
	_finger = _points[0]
	_press(_finger)
	_phase = Phase.KAYDIR
	return true


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

## Taş dizisini, aradaki taşlara değmeyen bir parmak yoluna çevirir.
##
## Ölçülmüş hata: iki taş arasında düz çizgi çizmek 7-8 harfli çarklarda
## aradaki taşların üstünden geçiyor. LetterWheel._try_add parmağın değdiği
## HER taşı kelimeye ekliyor, dolayısıyla gönderilen kelime bozuk çıkıyor ve
## hiçbir kelime kabul edilmiyordu (40. bölümde 55 saniyede 0 kelime).
##
## Bu bir hızlandırma yan etkisiyle gizlenmişti: --hizli ile kare başına
## 175 piksel ilerleyen bot aradaki taşların üstünden ATLIYOR ve sorunu hiç
## yaşamıyordu. Gerçek oyuncu böyle oynayamaz; o yüzden yol artık gerçek bir
## oyuncunun yaptığını yapıyor — engel varsa çarkın ortasından dolanıyor.
static func swipe_path(wheel: LetterWheel, stones: Array) -> Array:
	if stones.is_empty():
		return []
	var path: Array = [wheel._positions[stones[0]]]
	for i in range(1, stones.size()):
		var from_index: int = stones[i - 1]
		var to_index: int = stones[i]
		var a: Vector2 = wheel._positions[from_index]
		var b: Vector2 = wheel._positions[to_index]
		for via in _detour(wheel, a, b, from_index, to_index):
			path.append(via)
		path.append(b)
	return path


## a'dan b'ye giderken başka taşa değmemek için gereken ara noktalar.
static func _detour(wheel: LetterWheel, a: Vector2, b: Vector2,
		from_index: int, to_index: int) -> Array:
	if _leg_clear(wheel, a, b, from_index, to_index):
		return []

	# Çarkın ortası bütün taşlardan yarıçap kadar uzak: en güvenli geçiş.
	if _leg_clear(wheel, a, wheel._center, from_index, to_index) \
			and _leg_clear(wheel, wheel._center, b, from_index, to_index):
		return [wheel._center]

	# Ortası da tutmazsa kirişin dışına doğru kaydırılmış bir nokta denenir.
	var mid := (a + b) * 0.5
	var normal := (b - a).normalized().orthogonal()
	for scale: float in [0.4, 0.7, 1.0]:
		for side: float in [1.0, -1.0]:
			var via := mid + normal * (wheel._radius * scale * side)
			# Nokta çarkın kutusunun dışına çıkmasın: dışarıdaki sürükleme
			# olayları çarka ulaşmayabilir.
			if not Rect2(Vector2.ZERO, wheel.size).has_point(via):
				continue
			if _leg_clear(wheel, a, via, from_index, to_index) \
					and _leg_clear(wheel, via, b, from_index, to_index):
				return [via]
	# Temiz yol yok: insan da bazen yanlış taşa değer.
	return []


static func _leg_clear(wheel: LetterWheel, a: Vector2, b: Vector2,
		from_index: int, to_index: int) -> bool:
	# LetterWheel._letter_at ile aynı yarıçap, biraz emniyet payıyla.
	var reach := maxf(wheel._stone_radius * LetterWheel.TOUCH_SLACK, 44.0) * 1.15
	for i in wheel._positions.size():
		if i == from_index or i == to_index:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(wheel._positions[i], a, b)
		if closest.distance_to(wheel._positions[i]) <= reach:
			return false
	return true


func _advance_finger(delta: float) -> void:
	var target: Vector2 = _points[_leg]
	var step := (HUMAN_FINGER_SPEED if human else FINGER_SPEED) * delta
	var to_target := target - _finger

	if to_target.length() <= step:
		_finger = target
		_drag(_finger)
		_leg += 1
		if _leg >= _points.size():
			_release(_finger)
			_phase = Phase.BEKLE
			_timer = pause_between_words
			if human:
				# Her kelime aynı sürede bulunmaz; tempo dalgalanır.
				_timer *= 1.0 + _rng.randf_range(-HUMAN_TEMPO_JITTER, HUMAN_TEMPO_JITTER)
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
		# İnsan kulenin hazır olduğunu anında görmez: enerji dolduktan sonra
		# fark edip yuvaya basana kadar bir-iki saniye geçer.
		_tap_cooldown = _rng.randf_range(HUMAN_BUILD_REACTION.x, HUMAN_BUILD_REACTION.y) \
			if human else 0.4
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


func _use_ulti_if_ready(delta: float) -> void:
	if battle._ulti_charge < 1.0 or battle.battlefield.live_enemy_count() < 4:
		# Fırsat penceresi kapandı; bir sonraki kalabalıkta baştan karar verilir.
		_ulti_wait = -1.0
		return
	if not human:
		battle._on_ulti()
		return

	# İnsan: fırsatı bazen tamamen kaçırır, kaçırmazsa da geç basar.
	if _ulti_wait < 0.0:
		_ulti_wait = INF if _rng.randf() < HUMAN_ULTI_MISS else HUMAN_ULTI_REACTION
	if is_inf(_ulti_wait):
		return
	_ulti_wait -= delta
	if _ulti_wait <= 0.0:
		_ulti_wait = -1.0
		battle._on_ulti()


## Seviye bitti: sonucu yaz ve sonuç ekranı görünsün diye biraz bekleyip çık.
## Sinyal, sahne değişiminden önce geldiği için pilot serbest bırakılsa bile
## sonuç kaydedilmiş olur.
func _on_level_finished(result: Dictionary) -> void:
	_phase = Phase.BITTI
	print("[Demo] SONUC seviye=%d %s yildiz=%d can=%%%d kelime=%d kadim=%d oldurulen=%d sure=%.0fs" % [
		level_id, "ZAFER" if result.get("zafer", false) else "YENILGI",
		int(result.get("yildiz", 0)), roundi(float(result.get("can_orani", 0.0)) * 100.0),
		int(result.get("kelime", 0)), int(result.get("kadim", 0)),
		int(result.get("oldurulen", 0)), float(result.get("sure", 0.0))])
	print("[Demo] denetim: battle._enemies_killed=%d  sonuc.oldurulen=%s" % [battle._enemies_killed, result.get("oldurulen")])
	if not _quit_armed:
		_quit_armed = true
		get_tree().create_timer(AFTER_RESULT_SECONDS).timeout.connect(get_tree().quit)


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
