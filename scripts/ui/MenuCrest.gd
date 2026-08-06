extends Control

const SpriteBank := preload("res://scripts/core/SpriteBank.gd")

## Ana menüdeki kale arması: oyunun ne olduğunu tek bakışta anlatır.
## Savaş alanındaki kaleyle aynı görseli kullanır.

const SWAY_SPEED := 1.1
const CASTLE_WIDTH := 220.0

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	if PerfManager.low_quality:
		return
	_time += delta
	queue_redraw()


func _skin_id() -> String:
	return "tas"


func _draw() -> void:
	var box := minf(size.x, size.y * 1.6)
	if box <= 0.0:
		return
	var center := Vector2(size.x * 0.5, size.y * 0.62)
	var stone := Color("#8e8e96")

	# Arkada yumuşak bir ışık halesi — kale zeminden ayrışsın.
	ProcArt.ellipse(self, center + Vector2(0, -size.y * 0.1),
		Vector2(box * 0.36, box * 0.26), Color(0.96, 0.82, 0.42, 0.10), false)

	var factor := minf(size.y / 190.0, box / 320.0)
	# Menüdeki arma savaş alanındaki kaleyle aynı görseli kullanmalı.
	var sprite := SpriteBank.castle(_skin_id())
	if sprite != null:
		var height := CASTLE_WIDTH * 0.86 * factor
		SpriteBank.draw_fitted(self, sprite, center + Vector2(0, height * 0.46),
			Vector2(height * 1.2, height))
	else:
		draw_set_transform(center, 0.0, Vector2(factor, factor))
		ProcArt.draw_castle(self, CASTLE_WIDTH, stone, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Kalenin iki yanında hafifçe salınan sancaklar. Konum kalenin gerçek
	# genişliğinden türetilir; kutu genişliğine göre hesaplanınca direkler
	# surun üstüne düşüyordu.
	if PerfManager.low_quality:
		return
	var castle_half := CASTLE_WIDTH * 0.5 * factor
	for side in [-1.0, 1.0]:
		var base := center + Vector2(side * (castle_half + box * 0.09), -size.y * 0.02)
		draw_line(base, base + Vector2(0, -size.y * 0.34), Color("#3a2b1e"), 4.0, true)
		var wave := sin(_time * SWAY_SPEED + side) * box * 0.02
		ProcArt.filled_polygon(self, PackedVector2Array([
			base + Vector2(0, -size.y * 0.34),
			base + Vector2(side * box * 0.10 + wave, -size.y * 0.30),
			base + Vector2(0, -size.y * 0.24),
		]), Color("#b5483c"), true)
