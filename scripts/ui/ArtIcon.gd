class_name ArtIcon
extends Control

## Arayüzde kule / düşman / harf taşı simgesi.
##
## Seviye önizlemesinde ve mağazada "Okçu Kulesi" yazmak yerine kulenin
## kendisini göstermek, oyuncunun savaş alanında ne arayacağını öğretir.
## Simgeler savaş alanıyla aynı çizim kitaplığını (ProcArt) kullanır, yani
## ayrı bir simge seti bakımı gerekmez.

enum Kind { TOWER, ENEMY, STONE, BOOSTER }
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


## Destek simgesi. Yeni görsel gerektirmemesi için mevcut çizim
## kitaplığından türetilir.
static func booster(symbol: String, box: float = 96.0) -> ArtIcon:
	var icon := ArtIcon.new()
	icon.kind = Kind.BOOSTER
	icon.id = symbol
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
		Kind.BOOSTER:
			_draw_booster(center, box)
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


## Destek simgeleri: her biri ne yaptığını tek bakışta anlatan basit bir şekil.
func _draw_booster(center: Vector2, box: float) -> void:
	var radius := box * 0.42
	var renk := _booster_color()
	ProcArt.filled_circle(self, center + Vector2(0, 4), radius, Color(0, 0, 0, 0.28), false)
	ProcArt.shaded_circle(self, center, radius, renk.darkened(0.35))
	draw_arc(center, radius * 0.92, 0.0, TAU, 28, renk.lightened(0.25), 3.0, true)

	var r := radius * 0.5
	match id:
		"kule":
			# Küçük kule silueti
			ProcArt.filled_polygon(self, PackedVector2Array([
				center + Vector2(-r * 0.6, r), center + Vector2(-r * 0.45, -r * 0.5),
				center + Vector2(r * 0.45, -r * 0.5), center + Vector2(r * 0.6, r),
			]), Color("#e8dcc6"), false)
			for i in 3:
				var x := center.x + (i - 1) * r * 0.45
				draw_rect(Rect2(x - r * 0.15, center.y - r * 0.85, r * 0.3, r * 0.4),
					Color("#e8dcc6"))
		"kale":
			# Kalkan
			ProcArt.filled_polygon(self, PackedVector2Array([
				center + Vector2(0, -r), center + Vector2(r * 0.8, -r * 0.5),
				center + Vector2(r * 0.55, r * 0.9), center + Vector2(0, r * 1.1),
				center + Vector2(-r * 0.55, r * 0.9), center + Vector2(-r * 0.8, -r * 0.5),
			]), Color("#e8dcc6"), false)
		"elmas":
			ProcArt.filled_polygon(self, PackedVector2Array([
				center + Vector2(0, -r), center + Vector2(r * 0.75, 0),
				center + Vector2(0, r), center + Vector2(-r * 0.75, 0),
			]), Color("#9fe4ff"), false)
		"buz":
			# Kar tanesi: üç çapraz
			for i in 3:
				var angle := PI * i / 3.0
				var dir := Vector2(cos(angle), sin(angle)) * r
				draw_line(center - dir, center + dir, Color("#dff4ff"), 5.0, true)
		"yildirim":
			ProcArt.filled_polygon(self, PackedVector2Array([
				center + Vector2(r * 0.15, -r), center + Vector2(-r * 0.55, r * 0.15),
				center + Vector2(-r * 0.05, r * 0.15), center + Vector2(-r * 0.2, r),
				center + Vector2(r * 0.55, -r * 0.2), center + Vector2(r * 0.05, -r * 0.2),
			]), Color("#ffe27a"), false)
		"kalp":
			var points := PackedVector2Array()
			for i in 24:
				var t := TAU * i / 24.0
				points.append(center + Vector2(
					16.0 * pow(sin(t), 3.0), -(13.0 * cos(t) - 5.0 * cos(2.0 * t)
						- 2.0 * cos(3.0 * t) - cos(4.0 * t))) * (r / 16.0))
			ProcArt.filled_polygon(self, points, Color("#ff7d7d"), false)
		_:
			ProcArt.filled_circle(self, center, r * 0.6, Color("#e8dcc6"), false)


func _booster_color() -> Color:
	match id:
		"kule": return Color("#c9772e")
		"kale": return Color("#8fa8d6")
		"elmas": return Color("#4fbf6a")
		"buz": return Color("#5fb8e0")
		"yildirim": return Color("#d9a83c")
		"kalp": return Color("#c2544f")
	return Color("#8f8aa0")
