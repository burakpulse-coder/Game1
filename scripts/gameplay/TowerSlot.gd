class_name TowerSlot
extends Node2D

## Kule yuvası. Boşken dokunulabilir; inşa puanı dolu bir kule tipi varsa
## parıldar ve dokunuşla o kule inşa edilir.

signal tapped(slot: TowerSlot)

const RADIUS := 46.0
const TOUCH_RADIUS := 62.0

var index := 0
var tower: Tower = null
var ready_to_build := false

var _pulse := 0.0


func _ready() -> void:
	z_index = 4


func is_empty() -> bool:
	return tower == null


func set_ready(value: bool) -> void:
	if ready_to_build == value:
		return
	ready_to_build = value
	queue_redraw()


func _process(delta: float) -> void:
	if ready_to_build and is_empty():
		_pulse += delta
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not is_empty():
		return
	var point := Vector2.INF
	if event is InputEventScreenTouch and event.pressed:
		point = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		point = (event as InputEventMouseButton).position
	if point == Vector2.INF:
		return
	# Ekran koordinatını düğümün yerel uzayına çevirip dokunma yarıçapına bak.
	var local := get_global_transform_with_canvas().affine_inverse() * point
	if local.length() <= TOUCH_RADIUS:
		get_viewport().set_input_as_handled()
		tapped.emit(self)


func _draw() -> void:
	if not is_empty():
		return
	ProcArt.draw_slot(self, RADIUS, ready_to_build, _pulse)
