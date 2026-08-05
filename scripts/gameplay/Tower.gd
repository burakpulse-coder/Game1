class_name Tower
extends Node2D

## Yerleştirilmiş kule. Menzilindeki düşmanı hedefler ve mermi atar.
## Şifa Çeşmesi saldırmaz; belirli aralıklarla kaleyi iyileştirir.

signal wants_shot(tower: Tower, target: Enemy)
signal wants_heal(tower: Tower, amount: float)

const SLOT_RADIUS := 46.0

var tower_type := ""
var level := 1
var config := {}
var tint := Color.WHITE      ## kule tipinin rengi (menzil halkası, namlu parıltısı)
var stone := Color.WHITE     ## gövde rengi (kozmetikten gelir)

var _cooldown := 0.0
var _battlefield: Node = null
var _combo_bonus := 0.0     ## Combo'dan gelen atış hızı bonusu (0.1 = %10 hızlı)
var _energy_bonus := 0.0    ## Kategori dışı kelimelerin verdiği genel güç
var _muzzle := 0.0
var _range_flash := 0.0
var _recoil := 0.0          ## ateşlemede kule geriye seker
var _build_anim := 0.0      ## yerleştirme sırasında yerden yükselir


func _ready() -> void:
	z_index = 6


func setup(type_id: String, battlefield: Node) -> void:
	tower_type = type_id
	config = GameConfig.TOWERS.get(type_id, {}).duplicate()
	config["tip"] = type_id
	_battlefield = battlefield
	level = 1
	tint = Color(config.get("renk", "#ffffff"))
	stone = EconomyManager.cosmetic_color("kule", Color("#9a8f7f"))
	_cooldown = randf() * 0.3
	_range_flash = 1.0
	queue_redraw()


func upgrade() -> bool:
	if level >= GameConfig.MAX_TOWER_LEVEL:
		return false
	level += 1
	_range_flash = 1.0
	_build_anim = 0.55
	if _battlefield != null and _battlefield.has_method("get") and _battlefield.effects != null:
		_battlefield.effects.rising(position, 14, Color("#f4d06a"), SLOT_RADIUS * 0.7)
		_battlefield.effects.ring(position, SLOT_RADIUS * 2.0, Color("#f4d06a"), 0.5, 6.0)
	queue_redraw()
	return true


## Yerleştirildiğinde kısa bir "yerden yükselme" animasyonu oynatır.
func play_build_animation() -> void:
	_build_anim = 1.0
	queue_redraw()


func level_scale() -> float:
	return GameConfig.TOWER_LEVEL_SCALE[clampi(level - 1, 0, GameConfig.TOWER_LEVEL_SCALE.size() - 1)]


func attack_range() -> float:
	return float(config.get("menzil", 0.0)) * (1.0 + (level - 1) * 0.08)


func damage() -> float:
	return float(config.get("hasar", 0.0)) * level_scale() \
		* EconomyManager.tower_damage_multiplier() * (1.0 + _energy_bonus)


func fire_interval() -> float:
	var speed_bonus := 1.0 + _combo_bonus
	return float(config.get("atis_araligi", 1.0)) / maxf(speed_bonus, 0.2)


func set_combo_bonus(value: float) -> void:
	_combo_bonus = clampf(value, 0.0, GameConfig.COMBO_MAX)


## Kategori dışı geçerli kelimeler tüm kulelere küçük, kalıcı güç ekler.
func add_energy(amount: float) -> void:
	_energy_bonus += amount
	_range_flash = 0.6
	queue_redraw()


func _process(delta: float) -> void:
	_muzzle = maxf(0.0, _muzzle - delta * 5.0)
	if _recoil > 0.0:
		_recoil = maxf(0.0, _recoil - delta * 6.0)
		queue_redraw()
	if _build_anim > 0.0:
		_build_anim = maxf(0.0, _build_anim - delta * 2.4)
		queue_redraw()
	if _range_flash > 0.0:
		_range_flash = maxf(0.0, _range_flash - delta)
		queue_redraw()

	_cooldown -= delta
	if _cooldown > 0.0:
		return

	if tower_type == "sifa":
		_cooldown = fire_interval()
		var heal := float(config.get("iyilestirme", 0.0)) * level_scale() * (1.0 + _energy_bonus)
		wants_heal.emit(self, heal)
		_muzzle = 1.0
		queue_redraw()
		return

	var target := _pick_target()
	if target == null:
		return
	_cooldown = fire_interval()
	_muzzle = 1.0
	_recoil = 1.0
	wants_shot.emit(self, target)
	queue_redraw()


## Kaleye en yakın (yolda en ilerideki) vurulabilir düşmanı seçer —
## sızmayı önlemek için doğru öncelik budur.
func _pick_target() -> Enemy:
	if _battlefield == null or not _battlefield.has_method("enemies_in_range"):
		return null
	# Kuleler ve düşmanlar Battlefield'ın aynı orijinli katmanlarında durur,
	# bu yüzden karşılaştırma yerel koordinatta yapılır.
	var candidates: Array = _battlefield.enemies_in_range(position, attack_range())
	var best: Enemy = null
	var best_progress := -1.0
	for enemy in candidates:
		if not enemy.alive:
			continue
		# Bağışık düşmana ateş edip mermi harcanmaz (hayalet gibi).
		if enemy.immunity.has(tower_type):
			continue
		if enemy.distance > best_progress:
			best_progress = enemy.distance
			best = enemy
	return best


func _draw() -> void:
	# İnşa/yükseltme animasyonu: aşağıdan yukarı esneyerek oturur.
	if _build_anim > 0.0:
		var grow := 1.0 - _build_anim
		var bounce := 1.0 + sin(grow * PI) * 0.12
		draw_set_transform(Vector2(0, SLOT_RADIUS * _build_anim * 0.5), 0.0,
			Vector2(bounce, clampf(grow * 1.3, 0.12, 1.0) * bounce))
	elif _recoil > 0.0:
		# Ateşleme geri tepmesi: namlu yönünde küçük bir sarsıntı.
		draw_set_transform(Vector2(0, _recoil * 4.0), 0.0,
			Vector2(1.0 + _recoil * 0.05, 1.0 - _recoil * 0.05))

	if _range_flash > 0.0 and attack_range() > 0.0:
		draw_arc(Vector2.ZERO, attack_range(), 0.0, TAU, 48,
			Color(tint.r, tint.g, tint.b, 0.28 * _range_flash), 3.0, true)

	ProcArt.draw_tower(self, tower_type, level, SLOT_RADIUS, stone, tint)

	if _muzzle > 0.0:
		var flash := Color(1, 0.95, 0.75, _muzzle * 0.7)
		ProcArt.filled_circle(self, Vector2(0, -SLOT_RADIUS * 0.9), 10.0 * _muzzle, flash, false)

	# Seviye göstergesi: kulenin altında yıldızlar
	for i in level:
		var x := (i - (level - 1) * 0.5) * 16.0
		ProcArt.filled_circle(self, Vector2(x, SLOT_RADIUS * 1.05), 5.0, Color("#f4d06a"), false)
