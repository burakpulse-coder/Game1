class_name TowerSystem
extends Node

## Kelime -> kule bağlantısının kalbi.
##
## Bulunan her kategorili kelime, o kategorinin kulesi için "inşa puanı" biriktirir.
## Puan eşiği dolduğunda:
##   * boş yuva varsa yuvalar parıldar, oyuncu dokunarak kuleyi diker,
##   * boş yuva yoksa puan aynı tipteki en düşük seviyeli kuleyi yükseltmeye gider.
## Kategori dışı geçerli kelimeler tüm kulelere küçük bir güç (%5) ekler.

signal points_changed(tower_type: String, points: float, threshold: float)
signal tower_ready(tower_type: String)
signal tower_built(tower: Tower, tower_type: String)
signal tower_upgraded(tower: Tower, level: int)

var battlefield: Battlefield = null

var _points := {}          ## kule tipi -> birikmiş puan
var _ready_types: Array = []
var _combo_bonus := 0.0


func setup(field: Battlefield) -> void:
	battlefield = field
	_points.clear()
	_ready_types.clear()
	for tower_type in GameConfig.TOWERS:
		_points[tower_type] = 0.0
		points_changed.emit(tower_type, 0.0, GameConfig.BUILD_POINT_THRESHOLD)


func points_of(tower_type: String) -> float:
	return float(_points.get(tower_type, 0.0))


func threshold_for(tower_type: String) -> float:
	# Boş yuva yoksa biriken puan yükseltmeye gider; eşik de yükseltme maliyetidir.
	if battlefield != null and battlefield.empty_slot_count() == 0:
		var target := _weakest_tower(tower_type)
		if target != null:
			return _upgrade_cost(target.level)
	return GameConfig.BUILD_POINT_THRESHOLD


func is_ready(tower_type: String) -> bool:
	return _ready_types.has(tower_type)


func ready_types() -> Array:
	return _ready_types


func set_combo_bonus(value: float) -> void:
	_combo_bonus = value
	if battlefield == null:
		return
	for tower in battlefield.towers():
		(tower as Tower).set_combo_bonus(value)


## --------------------------------------------------------------------------
## Kelime girişleri
## --------------------------------------------------------------------------

## Kategorili kelime: ilgili kuleye puan ekler. Yükseltme otomatik yapılır.
func add_category_word(tower_type: String, multiplier: float) -> void:
	if not GameConfig.TOWERS.has(tower_type):
		return
	var gain := GameConfig.BUILD_POINTS_PER_WORD * multiplier \
		* (1.0 + _combo_bonus) * EconomyManager.build_point_multiplier()
	_points[tower_type] = points_of(tower_type) + gain
	_settle(tower_type)


## Kategori dışı geçerli kelime: tüm kulelere küçük güç + her tipe az puan.
func add_general_energy(multiplier: float) -> void:
	var share := GameConfig.BUILD_POINTS_PER_WORD * multiplier * GameConfig.GENERAL_ENERGY_RATIO \
		* EconomyManager.build_point_multiplier()
	for tower_type in GameConfig.TOWERS:
		_points[tower_type] = points_of(tower_type) + share
		_settle(tower_type)
	if battlefield != null:
		for tower in battlefield.towers():
			(tower as Tower).add_energy(GameConfig.GENERAL_ENERGY_RATIO)


## Eşiği aşan puanı harcar: boş yuva varsa "hazır" işaretler, yoksa yükseltir.
func _settle(tower_type: String) -> void:
	var guard := 0
	while guard < 8:
		guard += 1
		var threshold := threshold_for(tower_type)
		if points_of(tower_type) < threshold:
			break
		if battlefield != null and battlefield.empty_slot_count() > 0:
			if not _ready_types.has(tower_type):
				_ready_types.append(tower_type)
				tower_ready.emit(tower_type)
			break  # puan yuvaya dokunulana kadar bekler
		var target := _weakest_tower(tower_type)
		if target == null:
			break  # bu tipte kule yok ve boş yuva da yok: puan birikmeye devam eder
		_points[tower_type] = points_of(tower_type) - threshold
		if target.upgrade():
			tower_upgraded.emit(target, target.level)
		else:
			# Hepsi 3. seviye: puanı geri ver ve biriktirmeyi durdur.
			_points[tower_type] = threshold - 1.0
			break
	points_changed.emit(tower_type, points_of(tower_type), threshold_for(tower_type))


func _weakest_tower(tower_type: String) -> Tower:
	if battlefield == null:
		return null
	var best: Tower = null
	for node in battlefield.towers():
		var tower := node as Tower
		if tower.tower_type != tower_type:
			continue
		if tower.level >= GameConfig.MAX_TOWER_LEVEL:
			continue
		if best == null or tower.level < best.level:
			best = tower
	return best


func _upgrade_cost(current_level: int) -> float:
	return GameConfig.UPGRADE_COST_L2 if current_level == 1 else GameConfig.UPGRADE_COST_L3


## --------------------------------------------------------------------------
## Yerleştirme
## --------------------------------------------------------------------------

## Oyuncu boş yuvaya dokundu. Hazır kule tiplerinden birini (en çok puanı olanı)
## oraya diker. Hazır tip yoksa false döner.
func build_on(slot: TowerSlot) -> bool:
	if battlefield == null or not slot.is_empty() or _ready_types.is_empty():
		return false
	var chosen: String = _ready_types[0]
	var best := -1.0
	for tower_type in _ready_types:
		var score := points_of(tower_type) - GameConfig.BUILD_POINT_THRESHOLD
		if score > best:
			best = score
			chosen = tower_type
	return build_type_on(slot, chosen)


func build_type_on(slot: TowerSlot, tower_type: String) -> bool:
	if battlefield == null or not slot.is_empty():
		return false
	if points_of(tower_type) < GameConfig.BUILD_POINT_THRESHOLD:
		return false
	var tower := battlefield.place_tower(slot, tower_type)
	if tower == null:
		return false
	tower.set_combo_bonus(_combo_bonus)
	_points[tower_type] = points_of(tower_type) - GameConfig.BUILD_POINT_THRESHOLD
	_ready_types.erase(tower_type)
	tower_built.emit(tower, tower_type)
	_refresh_ready()
	points_changed.emit(tower_type, points_of(tower_type), threshold_for(tower_type))
	return true


## Yuva doldu/boşaldı: hazır listesini ve puanları yeniden değerlendir.
func _refresh_ready() -> void:
	if battlefield == null:
		return
	if battlefield.empty_slot_count() == 0:
		_ready_types.clear()
		for tower_type in GameConfig.TOWERS.keys():
			_settle(tower_type)
	else:
		for tower_type in GameConfig.TOWERS.keys():
			if points_of(tower_type) >= GameConfig.BUILD_POINT_THRESHOLD \
					and not _ready_types.has(tower_type):
				_ready_types.append(tower_type)
				tower_ready.emit(tower_type)


func highest_tower_level() -> int:
	var best := 0
	if battlefield == null:
		return best
	for tower in battlefield.towers():
		best = maxi(best, (tower as Tower).level)
	return best
