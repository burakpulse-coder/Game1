class_name ArtIcon
extends Control

## Arayüzde kule / düşman / harf taşı simgesi.
##
## Seviye önizlemesinde ve mağazada "Okçu Kulesi" yazmak yerine kulenin
## kendisini göstermek, oyuncunun savaş alanında ne arayacağını öğretir.
## Simgeler savaş alanıyla aynı çizim kitaplığını (ProcArt) kullanır, yani
## ayrı bir simge seti bakımı gerekmez.

enum Kind { TOWER, ENEMY, STONE }
const SpriteBank := preload("res://scripts/core/SpriteBank.gd")


var kind: Kind = Kind.TOWER
var id := ""
var level := 1
var letter := ""

var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(96, 96)


static func tower(tower_type: String, tower_level: int = 1, box: float = 96.0) -> ArtIcon:
	var icon := ArtIcon.new()
	icon.kind = Kind.TOWER
	icon.id = tower_type
	icon.level = tower_level
	icon.custom_minimum_size = Vector2(box, box)
	return icon


static func enemy(enemy_type: String, box: float = 96.0) -> ArtIcon:
	var icon := ArtIcon.new()
	icon.kind = Kind.ENEMY
	icon.id = enemy_type
	icon.custom_minimum_size = Vector2(box, box)
	return icon


static func stone(text: String, box: float = 96.0) -> ArtIcon:
	var icon := ArtIcon.new()
	icon.kind = Kind.STONE
	icon.letter = TurkishText.to_upper(text)
	icon.custom_minimum_size = Vector2(box, box)
	return icon


func _draw() -> void:
	var box := minf(size.x, size.y)
	if box <= 0.0:
		return
	var center := size * 0.5

	match kind:
		Kind.TOWER:
			var config: Dictionary = GameConfig.TOWERS.get(id, {})
			if config.is_empty():
				return
			# Sprite varsa simge de onu göstersin; önizlemedeki kule ile savaş
			# alanındaki kule aynı görünmeli.
			var sprite := SpriteBank.tower(id, level)
			if sprite != null:
				SpriteBank.draw_fitted(self, sprite, center + Vector2(0, box * 0.46),
					Vector2(box * 0.92, box * 0.92))
				return
			# Kule çizimi (0,0) merkezli ve SLOT_RADIUS ölçeğinde; kutuya sığdır.
			var factor := box / (Tower.SLOT_RADIUS * 3.0)
			draw_set_transform(center + Vector2(0, box * 0.12), 0.0, Vector2(factor, factor))
			ProcArt.draw_tower(self, id, level, Tower.SLOT_RADIUS,
				Color("#9a8f7f"), Color(config["renk"]))
		Kind.ENEMY:
			var data: Dictionary = GameConfig.ENEMIES.get(id, {})
			if data.is_empty():
				return
			var radius := Enemy.BASE_RADIUS * float(data.get("boy", 1.0))
			# Sprite varsa simge de onu göstersin; önizlemedeki düşman ile
			# savaş alanındaki düşman aynı görünmeli.
			var sprite := SpriteBank.enemy(id)
			if sprite != null:
				draw_set_transform(center + Vector2(0, box * 0.30), 0.0, Vector2.ONE)
				SpriteBank.draw_enemy(self, sprite, box / SpriteBank.ENEMY_HEIGHT, 0.0)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				return
			var factor := box / (radius * 3.2)
			draw_set_transform(center + Vector2(0, box * 0.16), 0.0, Vector2(factor, factor))
			if bool(data.get("boss", false)):
				ProcArt.draw_boss(self, radius, Color(data["renk"]), 0.0, -1.0, 0)
			else:
				ProcArt.draw_enemy(self, id, radius, Color(data["renk"]), 0.0, -1.0)
		Kind.STONE:
			ProcArt.filled_circle(self, center + Vector2(0, 4), box * 0.44,
				Color(0, 0, 0, 0.28), false)
			ProcArt.shaded_circle(self, center, box * 0.44, LetterWheel.STONE_FILL)
			draw_arc(center, box * 0.35, 0.0, TAU, 24,
				Color(LetterWheel.STONE_EDGE.r, LetterWheel.STONE_EDGE.g,
					LetterWheel.STONE_EDGE.b, 0.45), 3.0, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if _font != null:
				var font_size := int(box * 0.44)
				var measured := _font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT,
					-1, font_size)
				var origin := center - Vector2(measured.x * 0.5, -measured.y * 0.32)
				draw_string(_font, origin, letter, HORIZONTAL_ALIGNMENT_LEFT, -1,
					font_size, LetterWheel.TEXT_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
