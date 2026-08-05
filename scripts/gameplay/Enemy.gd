class_name Enemy
extends Node2D

## Tek bir düşman. Nesne havuzundan alınır; `configure()` ile her doğuşta
## yeniden kurulur. Yol boyunca ilerler, kaleye ulaşınca hasar verip kaybolur.

signal died(enemy: Enemy)
signal reached_castle(enemy: Enemy, damage: float)
signal phase_changed(enemy: Enemy, phase: int)

const BASE_RADIUS := 31.0
const HEALTH_BAR_WIDTH := 54.0
## Yürüyüş animasyonu yeniden çizim hızı. Konum her karede güncellenir (düğüm
## dönüşümü), ama _draw() bu hızda çalışır — düşük cihazlarda ciddi kazanç.
const REDRAW_HZ := 20.0
const REDRAW_HZ_LOW := 10.0

var type_id := ""
var data := {}
var max_hp := 1.0
var hp := 1.0
var speed := 60.0
var damage := 5.0
var gold := 0
var armor := 1.0
var weakness := {}
var immunity: Array = []
var is_boss := false
var steals_letter := false
var steal_duration := 5.0

var track: PathTrack = null
var distance := 0.0
var alive := false
var stolen_letter := -1   ## Harf Hırsızı'nın kilitlediği harfin çark indeksi

var _tint := Color.WHITE
var _walk := 0.0
var _facing := -1.0
var _phase := 0
var _phases: Array = []
var _hit_flash := 0.0
var _slow_until := 0.0
var _speed_scale := 1.0
var _redraw_timer := 0.0


func _ready() -> void:
	z_index = 5


## Havuzdan alınan düğümü yeni bir düşman olarak kurar.
func configure(enemy_type: String, path: PathTrack, power: float) -> void:
	type_id = enemy_type
	data = GameConfig.ENEMIES.get(enemy_type, {})
	if data.is_empty():
		push_error("[Enemy] Bilinmeyen düşman tipi: %s" % enemy_type)
		data = GameConfig.ENEMIES["goblin"]

	max_hp = float(data["can"]) * power
	hp = max_hp
	speed = float(data["hiz"])
	damage = float(data["hasar"]) * power
	gold = int(data["altin"])
	armor = float(data.get("zirh", 1.0))
	weakness = data.get("zayiflik", {})
	immunity = data.get("bagisiklik", [])
	is_boss = bool(data.get("boss", false))
	steals_letter = bool(data.get("calar_harf", false))
	steal_duration = float(data.get("calma_suresi", 5.0))
	_phases = data.get("fazlar", [])
	_phase = 0
	_tint = Color(data.get("renk", "#ffffff"))
	_speed_scale = 1.0
	_slow_until = 0.0
	_hit_flash = 0.0
	_walk = randf() * TAU

	track = path
	distance = 0.0
	alive = true
	stolen_letter = -1
	_redraw_timer = 0.0
	position = track.position_at(0.0)
	queue_redraw()


func pool_reset() -> void:
	alive = false
	track = null
	stolen_letter = -1


func radius() -> float:
	return BASE_RADIUS * float(data.get("boy", 1.0))


func _process(delta: float) -> void:
	if not alive or track == null:
		return

	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta * 4.0)
		queue_redraw()
	if _slow_until > 0.0:
		_slow_until -= delta
		if _slow_until <= 0.0:
			_speed_scale = 1.0

	var step := speed * _speed_scale * _phase_speed() * delta
	var previous := position
	distance += step
	var total := track.length()
	if distance >= total:
		alive = false
		reached_castle.emit(self, damage)
		return
	position = track.position_at(distance)
	if not is_equal_approx(position.x, previous.x):
		_facing = signf(position.x - previous.x)
	_walk += delta * (6.0 + speed * 0.03)

	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = 1.0 / (REDRAW_HZ_LOW if PerfManager.low_quality else REDRAW_HZ)
		queue_redraw()


func _phase_speed() -> float:
	if _phase <= 0 or _phase > _phases.size():
		return 1.0
	return float(_phases[_phase - 1].get("hiz_carpani", 1.0))


## Kule tipinden gelen hasarı zırh/zayıflık/bağışıklık kurallarıyla uygular.
## Gerçekten uygulanan hasarı döndürür (0 = bağışık).
func take_damage(amount: float, source_tower: String) -> float:
	if not alive:
		return 0.0
	if immunity.has(source_tower):
		_hit_flash = 0.35
		queue_redraw()
		return 0.0

	var multiplier := armor
	if weakness.has(source_tower):
		# Zayıflık zırhı geçersiz kılar: mancınık trolün zırhını parçalar.
		multiplier = float(weakness[source_tower])
	var applied := amount * multiplier
	hp -= applied
	_hit_flash = 1.0
	_check_phase()
	queue_redraw()
	if hp <= 0.0:
		alive = false
		died.emit(self)
	return applied


func slow(factor: float, duration: float) -> void:
	_speed_scale = minf(_speed_scale, factor)
	_slow_until = maxf(_slow_until, duration)


func _check_phase() -> void:
	if _phases.is_empty():
		return
	var ratio := hp / max_hp
	while _phase < _phases.size() and ratio <= float(_phases[_phase]["can_orani"]):
		_phase += 1
		phase_changed.emit(self, _phase)


func current_phase() -> int:
	return _phase


## Fazın çağırdığı yardımcı düşman tipi (yoksa boş metin).
func phase_summon(phase: int) -> String:
	if phase <= 0 or phase > _phases.size():
		return ""
	return str(_phases[phase - 1].get("cagirir", ""))


func health_ratio() -> float:
	return clampf(hp / maxf(max_hp, 0.001), 0.0, 1.0)


func _draw() -> void:
	var r := radius()
	var tint := _tint
	if _hit_flash > 0.0:
		tint = tint.lerp(Color.WHITE, _hit_flash * 0.7)

	# Vuruş anında ezilip yayılır (squash & stretch) — darbe hissini verir.
	if _hit_flash > 0.0:
		draw_set_transform(Vector2(0, _hit_flash * 3.0), 0.0,
			Vector2(1.0 + _hit_flash * 0.16, 1.0 - _hit_flash * 0.14))

	# Elle çizilmiş sprite varsa o kullanılır; yoksa yordamsal çizime düşülür.
	var sprite := SpriteBank.enemy(type_id)
	if sprite != null:
		SpriteBank.draw_enemy(self, sprite, r, _facing, _hit_flash, _walk)
	elif is_boss:
		ProcArt.draw_boss(self, r, tint, _walk, _facing, _phase)
	else:
		ProcArt.draw_enemy(self, type_id, r, tint, _walk, _facing)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Can çubuğu — yalnız hasar aldıysa gösterilir, ekran kalabalığı olmasın.
	if hp < max_hp:
		var width := HEALTH_BAR_WIDTH * (1.6 if is_boss else 1.0)
		# Sprite yordamsal çizimden daha uzun; çubuk aksi hâlde başın üstüne biner.
		var top := -r * (SpriteBank.ENEMY_HEAD if sprite != null else 1.55)
		var back := Rect2(-width * 0.5, top, width, 8.0)
		draw_rect(back, Color(0, 0, 0, 0.55))
		var fill := back
		fill.size.x *= health_ratio()
		var bar_color := Color("#5ec97a").lerp(Color("#d1544a"), 1.0 - health_ratio())
		draw_rect(fill, bar_color)

	# Harf çalan düşmanın üstünde uyarı simgesi
	if stolen_letter >= 0:
		var head := SpriteBank.ENEMY_HEAD + 0.35 if sprite != null else 2.0
		var badge := Vector2(0, -r * head)
		ProcArt.filled_circle(self, badge, 13.0, Color("#f4d06a"))
		draw_arc(badge, 17.0, 0.0, TAU, 16, Color(0.96, 0.82, 0.42, 0.5), 2.0, true)
