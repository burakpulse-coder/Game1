class_name TowerSlot
extends Node2D

## Kule yuvası. Boşken dokunulabilir; inşa puanı dolu bir kule tipi varsa
## parıldar ve dokunuşla o kule inşa edilir.

## Dokunma isabeti Battlefield'ın `_gui_input`'inde çözülür: kök Control'ler
## dokunma olaylarını yuttuğu için `_unhandled_input` savaş sahnesinde hiç
## tetiklenmiyordu. Bu düğüm yalnızca kendi görünümünden sorumludur.

const RADIUS := 46.0
const TOUCH_RADIUS := 74.0

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


func _draw() -> void:
	if not is_empty():
		return
	ProcArt.draw_slot(self, RADIUS, ready_to_build, _pulse)
