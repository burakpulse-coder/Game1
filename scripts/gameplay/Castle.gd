class_name Castle
extends Node2D

## Oyuncunun kalesi. Can barındırır, hasar/iyileşme geri bildirimini gösterir.

signal destroyed
signal health_changed(current: float, maximum: float)

const WIDTH := 190.0

var max_hp := 100.0
var hp := 100.0

var _shake := 0.0
var _flash := 0.0
var _heal_flash := 0.0
var _stone := Color("#8e8e96")
var _shake_offset := Vector2.ZERO


func _ready() -> void:
	z_index = 3
	_stone = EconomyManager.cosmetic_color("kale", _stone)


func setup(maximum: float) -> void:
	max_hp = maxf(maximum, 1.0)
	hp = max_hp
	health_changed.emit(hp, max_hp)
	queue_redraw()


func health_ratio() -> float:
	return clampf(hp / maxf(max_hp, 0.001), 0.0, 1.0)


func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	_shake = 1.0
	_flash = 1.0
	health_changed.emit(hp, max_hp)
	AudioManager.play_sfx("kale_hasar")
	queue_redraw()
	if hp <= 0.0:
		destroyed.emit()


func heal(amount: float) -> float:
	if hp >= max_hp:
		return 0.0
	var before := hp
	hp = minf(max_hp, hp + amount)
	_heal_flash = 1.0
	health_changed.emit(hp, max_hp)
	queue_redraw()
	return hp - before


func revive(ratio: float) -> void:
	hp = maxf(hp, max_hp * ratio)
	health_changed.emit(hp, max_hp)
	queue_redraw()


func _process(delta: float) -> void:
	var dirty := false
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 3.0)
		var amount := _shake * 9.0 * PerfManager.effect_scale()
		_shake_offset = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
		dirty = true
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.5)
		dirty = true
	if _heal_flash > 0.0:
		_heal_flash = maxf(0.0, _heal_flash - delta * 1.6)
		dirty = true
	if dirty:
		queue_redraw()


func _draw() -> void:
	# Sarsıntı düğümün konumunu değil, yalnızca çizimi kaydırır;
	# böylece kule/yol yerleşimi bozulmaz.
	draw_set_transform(_shake_offset, 0.0, Vector2.ONE)
	var stone := _stone
	if _flash > 0.0:
		stone = stone.lerp(Color("#d1544a"), _flash * 0.6)
	if _heal_flash > 0.0:
		stone = stone.lerp(Color("#5ec97a"), _heal_flash * 0.45)
	ProcArt.draw_castle(self, WIDTH, stone, health_ratio())

	if _heal_flash > 0.0:
		draw_arc(Vector2.ZERO, WIDTH * (0.55 + (1.0 - _heal_flash) * 0.4), 0.0, TAU, 32,
			Color(0.37, 0.79, 0.48, _heal_flash * 0.7), 4.0, true)
