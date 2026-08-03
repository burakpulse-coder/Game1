class_name Battlefield
extends Control

## Savaş alanı: yollar, kule yuvaları, kale, düşman ve mermi havuzları.
## Ekranın üst ~%60'ını kaplar ve tüm en-boy oranlarında kendini yeniden ölçer.

signal enemy_died(enemy: Enemy)
signal enemy_reached_castle(enemy: Enemy, damage: float)
signal enemy_spawned(enemy: Enemy)
signal slot_tapped(slot: TowerSlot)

const SLOT_CLEARANCE := PathTrack.PATH_WIDTH * 0.5 + TowerSlot.RADIUS + 14.0
const CASTLE_CLEARANCE := 150.0
## HUD'un üst şeridi (duraklat düğmesi, kale canı, dalga bilgisi) savaş alanının
## üstünü kaplar. Bu şeridin altına yuva konulursa yuvaya dokunmak düğmeye basar;
## bu yüzden üst bant yuva yerleşiminden dışlanır.
const TOP_UI_CLEARANCE := 210.0
## Yuva yola yakın olmalı: en kısa menzilli saldırı kulesi bile yolu dövebilsin.
## Aksi hâlde yuvalar savaş alanına dengeli ama işe yaramaz biçimde dağılıyor,
## kuleler hiçbir düşmana yetişemiyor ve seviye yalnızca Şifa Çeşmesi'yle
## sürünerek "kazanılıyordu". Sınır menzilden türetilir, elle yazılmaz.
const PREFERRED_RANGE_RATIO := 0.78
const RELAXED_RANGE_RATIO := 0.92


## En kısa saldırı menzili (Şifa Çeşmesi saldırmadığı için sayılmaz).
static func shortest_attack_range() -> float:
	var best := INF
	for tower_type in GameConfig.TOWERS:
		var reach := float(GameConfig.TOWERS[tower_type]["menzil"])
		if reach > 0.0:
			best = minf(best, reach)
	return best
const ENEMY_PREWARM := 24
const PROJECTILE_PREWARM := 24

var tracks: Array[PathTrack] = []
var slots: Array[TowerSlot] = []
var castle: Castle = null

var _path_layer: Node2D
var _slot_layer: Node2D
var _tower_layer: Node2D
var _enemy_layer: Node2D
var _projectile_layer: Node2D
var _effect_layer: Node2D

var _enemy_pool: ObjectPool
var _projectile_pool: ObjectPool
var _bursts: Array = []   ## [{pos, t, radius, color}]
var _slot_count := 4
var _path_count := 1
var _built := false


func _ready() -> void:
	clip_contents = true
	# Yuva dokunuşları buradan çözülür; savaş alanında başka etkileşimli
	# öğe yok, bu yüzden alan tüm dokunuşları alabilir.
	mouse_filter = Control.MOUSE_FILTER_STOP

	_path_layer = _make_layer(1)
	_slot_layer = _make_layer(2)
	_tower_layer = _make_layer(6)
	_enemy_layer = _make_layer(5)
	_projectile_layer = _make_layer(8)
	_effect_layer = _make_layer(9)

	_enemy_pool = ObjectPool.new(_enemy_layer, _make_enemy, ENEMY_PREWARM, 160)
	_projectile_pool = ObjectPool.new(_projectile_layer, _make_projectile, PROJECTILE_PREWARM, 200)

	castle = Castle.new()
	_tower_layer.add_child(castle)

	resized.connect(_layout)


func _make_layer(z: int) -> Node2D:
	var layer := Node2D.new()
	layer.z_index = z
	add_child(layer)
	return layer


func _make_enemy() -> Node:
	var enemy := Enemy.new()
	enemy.died.connect(_on_enemy_died)
	enemy.reached_castle.connect(_on_enemy_reached_castle)
	return enemy


func _make_projectile() -> Node:
	var projectile := Projectile.new()
	projectile.finished.connect(_on_projectile_finished)
	return projectile


## --------------------------------------------------------------------------
## Kurulum
## --------------------------------------------------------------------------

func build(path_count: int, slot_count: int) -> void:
	_path_count = clampi(path_count, 1, PathTrack.TEMPLATES.size())
	_slot_count = maxi(slot_count, 1)

	for track in tracks:
		track.queue_free()
	tracks.clear()
	for slot in slots:
		slot.queue_free()
	slots.clear()

	for i in _path_count:
		var track := PathTrack.new()
		_path_layer.add_child(track)
		tracks.append(track)

	for i in _slot_count:
		var slot := TowerSlot.new()
		slot.index = i
		_slot_layer.add_child(slot)
		slots.append(slot)

	_built = true
	_layout()


func _layout() -> void:
	if not _built or size.x <= 0.0 or size.y <= 0.0:
		return
	var rect := Rect2(Vector2.ZERO, size)
	for track in tracks:
		track.setup(track.index if track.index > 0 else tracks.find(track), rect)
	# PathTrack.setup index'i kendi belirlemez; sırayı burada garanti et.
	for i in tracks.size():
		tracks[i].setup(i, rect)

	castle.position = tracks[0].end_point()

	var positions := _pick_slot_positions(rect)
	for i in slots.size():
		slots[i].position = positions[i % positions.size()]


## Yuva konumları: ızgara adaylarından yola ve kaleye yeterince uzak olanlar
## seçilir, sonra aralarında en açık duranlar (farthest-point sampling) alınır.
## Böylece yol sayısı değişse de yuvalar hep dengeli dağılır.
func _pick_slot_positions(rect: Rect2) -> Array:
	var candidates: Array = []
	# Yoğun ızgara: yola "ne üstünde ne menzil dışında" olan dar bant yeterince
	# aday barındırsın.
	var cols := 9
	var rows := 9
	var preferred_max := maxf(SLOT_CLEARANCE + 20.0,
		shortest_attack_range() * PREFERRED_RANGE_RATIO)
	var relaxed_max := shortest_attack_range() * RELAXED_RANGE_RATIO
	for row in rows:
		for col in cols:
			var point := rect.position + Vector2(
				rect.size.x * (col + 0.5) / cols,
				rect.size.y * (row + 0.5) / rows)
			if point.y - rect.position.y < TOP_UI_CLEARANCE:
				continue
			if point.distance_to(castle.position) < CASTLE_CLEARANCE:
				continue
			var nearest := INF
			for track in tracks:
				nearest = minf(nearest, track.distance_to_path(point))
			# Yolun üstünde olmayacak kadar uzak, menzil dışında kalmayacak kadar yakın.
			if nearest >= SLOT_CLEARANCE and nearest <= preferred_max:
				candidates.append(point)

	if candidates.size() < _slot_count:
		# Yeterli aday yoksa yakınlık koşulunu gevşet (dar ekran / tek yol).
		for row in rows:
			for col in cols:
				var point := rect.position + Vector2(
					rect.size.x * (col + 0.5) / cols,
					rect.size.y * (row + 0.5) / rows)
				if point.y - rect.position.y < TOP_UI_CLEARANCE:
					continue
				if point.distance_to(castle.position) < CASTLE_CLEARANCE:
					continue
				if candidates.has(point):
					continue
				var nearest := INF
				for track in tracks:
					nearest = minf(nearest, track.distance_to_path(point))
				if nearest >= SLOT_CLEARANCE and nearest <= relaxed_max:
					candidates.append(point)

	if candidates.is_empty():
		# Hiç uygun nokta yoksa (çok dar ekran) yolun sağ kenarına diz.
		var fallback: Array = []
		var usable := maxf(rect.size.y - TOP_UI_CLEARANCE, 1.0)
		for i in _slot_count:
			fallback.append(rect.position + Vector2(rect.size.x * 0.9,
				TOP_UI_CLEARANCE + usable * (i + 1.0) / (_slot_count + 1.0)))
		return fallback

	var chosen: Array = [candidates.pop_front()]
	while chosen.size() < _slot_count and not candidates.is_empty():
		var best_index := 0
		var best_distance := -1.0
		for i in candidates.size():
			var nearest := INF
			for picked in chosen:
				nearest = minf(nearest, candidates[i].distance_to(picked))
			if nearest > best_distance:
				best_distance = nearest
				best_index = i
		chosen.append(candidates.pop_at(best_index))
	return chosen


## --------------------------------------------------------------------------
## Dokunma
## --------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var point := Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		point = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			point = click.position
	if point == Vector2.INF:
		return
	var slot := slot_at(point)
	if slot == null:
		return
	accept_event()
	slot_tapped.emit(slot)


## Verilen (savaş alanına göre yerel) noktaya en yakın boş yuva; menzil dışıysa null.
func slot_at(point: Vector2) -> TowerSlot:
	var best: TowerSlot = null
	var best_distance := TowerSlot.TOUCH_RADIUS
	for slot in slots:
		if not slot.is_empty():
			continue
		var distance := slot.position.distance_to(point)
		if distance <= best_distance:
			best_distance = distance
			best = slot
	return best


## --------------------------------------------------------------------------
## Düşmanlar
## --------------------------------------------------------------------------

func spawn_enemy(enemy_type: String, path_index: int, power: float) -> Enemy:
	if tracks.is_empty():
		return null
	var enemy := _enemy_pool.acquire() as Enemy
	enemy.configure(enemy_type, tracks[path_index % tracks.size()], power)
	enemy_spawned.emit(enemy)
	return enemy


func enemies() -> Array:
	return _enemy_pool.active()


func live_enemy_count() -> int:
	var count := 0
	for enemy in _enemy_pool.active():
		if (enemy as Enemy).alive:
			count += 1
	return count


func enemies_in_range(point: Vector2, radius: float) -> Array:
	var found: Array = []
	if radius <= 0.0:
		return found
	var squared := radius * radius
	for node in _enemy_pool.active():
		var enemy := node as Enemy
		if enemy.alive and enemy.position.distance_squared_to(point) <= squared:
			found.append(enemy)
	return found


func _on_enemy_died(enemy: Enemy) -> void:
	add_burst(enemy.position, enemy.radius() * 1.6, Color(enemy.data.get("renk", "#ffffff")))
	AudioManager.play_sfx("dusman_olum", randf_range(0.92, 1.08))
	enemy_died.emit(enemy)
	_enemy_pool.release(enemy)


func _on_enemy_reached_castle(enemy: Enemy, damage: float) -> void:
	enemy_reached_castle.emit(enemy, damage)
	_enemy_pool.release(enemy)


## --------------------------------------------------------------------------
## Mermiler ve hasar
## --------------------------------------------------------------------------

func fire(tower: Tower, target: Enemy) -> void:
	var projectile := _projectile_pool.acquire() as Projectile
	projectile.launch(tower.position + Vector2(0, -TowerSlot.RADIUS * 0.7), target,
		tower.config, tower.damage(), self)
	match tower.tower_type:
		"okcu":
			AudioManager.play_sfx("okcu_atis", randf_range(0.95, 1.1))
		"buyu":
			AudioManager.play_sfx("buyu_atis", randf_range(0.95, 1.05))
		"mancinik":
			AudioManager.play_sfx("mancinik_atis", randf_range(0.9, 1.0))


func _on_projectile_finished(projectile: Projectile) -> void:
	_projectile_pool.release(projectile)


## Merminin çarpma noktasında hasarı uygular. Alan hasarı varsa yarıçaptaki
## tüm düşmanlara, yoksa yalnız asıl hedefe işler.
func apply_damage(point: Vector2, amount: float, tower_type: String, splash: float,
		primary: Enemy) -> void:
	if splash > 0.0:
		add_burst(point, splash, Color(GameConfig.TOWERS.get(tower_type, {}).get("renk", "#ffffff")))
		for enemy in enemies_in_range(point, splash):
			# Merkezden uzaklaştıkça hasar azalır.
			var falloff: float = 1.0 - 0.45 * ((enemy as Enemy).position.distance_to(point) / maxf(splash, 1.0))
			(enemy as Enemy).take_damage(amount * falloff, tower_type)
	elif primary != null and primary.alive:
		primary.take_damage(amount, tower_type)


## Ulti: ekrandaki tüm düşmanlara büyük hasar.
func cast_ulti(damage: float) -> int:
	var hits := 0
	add_burst(Vector2(size.x * 0.5, size.y * 0.5), maxf(size.x, size.y), Color("#f4d06a"))
	for node in _enemy_pool.active().duplicate():
		var enemy := node as Enemy
		if not enemy.alive:
			continue
		enemy.take_damage(damage, "ulti")
		hits += 1
	return hits


func clear_all() -> void:
	_enemy_pool.release_all()
	_projectile_pool.release_all()
	_bursts.clear()
	queue_redraw()


## --------------------------------------------------------------------------
## Kuleler
## --------------------------------------------------------------------------

func place_tower(slot: TowerSlot, tower_type: String) -> Tower:
	if not slot.is_empty():
		return null
	var tower := Tower.new()
	_tower_layer.add_child(tower)
	tower.position = slot.position
	tower.setup(tower_type, self)
	tower.wants_shot.connect(fire)
	slot.tower = tower
	slot.set_ready(false)
	slot.queue_redraw()
	AudioManager.play_sfx("kule_insa")
	return tower


func towers() -> Array:
	var list: Array = []
	for slot in slots:
		if slot.tower != null:
			list.append(slot.tower)
	return list


func empty_slot_count() -> int:
	var count := 0
	for slot in slots:
		if slot.is_empty():
			count += 1
	return count


## --------------------------------------------------------------------------
## Efektler
## --------------------------------------------------------------------------

func add_burst(point: Vector2, radius: float, color: Color) -> void:
	if PerfManager.low_quality and _bursts.size() > 6:
		return
	_bursts.append({"pos": point, "t": 0.0, "radius": radius, "color": color})
	set_process(true)


func _process(delta: float) -> void:
	if _bursts.is_empty():
		return
	var index := _bursts.size() - 1
	while index >= 0:
		_bursts[index]["t"] += delta * 2.4
		if _bursts[index]["t"] >= 1.0:
			_bursts.remove_at(index)
		index -= 1
	_effect_layer.queue_redraw()
	queue_redraw()


func _draw() -> void:
	for burst in _bursts:
		draw_set_transform(burst["pos"], 0.0, Vector2.ONE)
		ProcArt.draw_burst(self, burst["t"], burst["radius"], burst["color"])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
