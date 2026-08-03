class_name Projectile
extends Node2D

## Kulelerin attığı mermi. Havuzdan alınır, hedefe ulaşınca hasarı uygular
## ve geri bırakılır. Alan hasarlı mermiler çarpma noktasında patlar.

signal finished(projectile: Projectile)

var tower_type := ""
var damage := 0.0
var splash_radius := 0.0
var speed := 600.0
var tint := Color.WHITE

var _target: Enemy = null
var _target_point := Vector2.ZERO
var _battlefield: Node = null
var _spin := 0.0
var _active := false


func _ready() -> void:
	z_index = 8


func launch(from: Vector2, target: Enemy, config: Dictionary, damage_amount: float,
		battlefield: Node) -> void:
	position = from
	tower_type = str(config.get("tip", ""))
	damage = damage_amount
	splash_radius = float(config.get("alan_yaricap", 0.0))
	speed = maxf(float(config.get("mermi_hiz", 600.0)), 60.0)
	tint = Color(config.get("renk", "#ffffff"))
	_target = target
	_target_point = target.position if target != null else from
	_battlefield = battlefield
	_active = true
	queue_redraw()


func pool_reset() -> void:
	_active = false
	_target = null
	_battlefield = null


func _process(delta: float) -> void:
	if not _active:
		return
	# Hedef ölmüşse mermi son bilinen konuma gider (boşa atış hissi doğru olsun).
	if _target != null and _target.alive:
		_target_point = _target.position
	var to_target := _target_point - position
	var step := speed * delta
	_spin += delta * 9.0

	if to_target.length() <= step:
		position = _target_point
		_impact()
		return
	position += to_target.normalized() * step
	rotation = to_target.angle() if tower_type == "okcu" else 0.0
	# Yalnızca dönen büyü küresinin görüntüsü kare kare değişir; ok ve gülle
	# sabit çizimdir, konumları düğüm dönüşümüyle güncellenir.
	if tower_type == "buyu":
		queue_redraw()


func _impact() -> void:
	_active = false
	if _battlefield != null and _battlefield.has_method("apply_damage"):
		_battlefield.apply_damage(position, damage, tower_type, splash_radius, _target)
	finished.emit(self)


func _draw() -> void:
	if not _active:
		return
	ProcArt.draw_projectile(self, tower_type, tint, _spin)
