class_name ProcArt
extends RefCounted

## Yordamsal (procedural) çizim kitaplığı.
##
## Oyunun tüm savaş alanı görselleri — kale, kuleler, düşmanlar, mermiler —
## ikili sprite dosyası yerine vektör çizimlerle üretilir. Böylece:
##   * her çözünürlükte keskin kalır (dikey telefonlarda 1080p ve üzeri),
##   * APK boyutu küçük olur,
##   * kozmetik renk değişimi tek parametreyle yapılır.
##
## Stil: düz renkli, koyu konturlu, hafif çizgi film dokusu. Siluetler küçük
## ekranda okunabilecek kadar sade tutulur.

const OUTLINE := Color("#241f2e")
const OUTLINE_WIDTH := 3.0
const SHADOW := Color(0, 0, 0, 0.22)


## --------------------------------------------------------------------------
## Temel yardımcılar
## --------------------------------------------------------------------------

static func filled_polygon(canvas: CanvasItem, points: PackedVector2Array, fill: Color,
		outline: bool = true, width: float = OUTLINE_WIDTH) -> void:
	if points.size() < 3:
		return
	canvas.draw_colored_polygon(points, fill)
	if outline:
		var closed := points.duplicate()
		closed.append(points[0])
		canvas.draw_polyline(closed, OUTLINE, width, true)


static func filled_circle(canvas: CanvasItem, center: Vector2, radius: float, fill: Color,
		outline: bool = true) -> void:
	canvas.draw_circle(center, radius, fill)
	if outline:
		canvas.draw_arc(center, radius, 0.0, TAU, 24, OUTLINE, OUTLINE_WIDTH, true)


static func rounded_rect(canvas: CanvasItem, rect: Rect2, radius: float, fill: Color,
		outline: bool = true) -> void:
	var points := PackedVector2Array()
	var corners := [
		[Vector2(rect.position.x + radius, rect.position.y + radius), PI, PI * 1.5],
		[Vector2(rect.end.x - radius, rect.position.y + radius), PI * 1.5, TAU],
		[Vector2(rect.end.x - radius, rect.end.y - radius), 0.0, PI * 0.5],
		[Vector2(rect.position.x + radius, rect.end.y - radius), PI * 0.5, PI],
	]
	for corner in corners:
		var center: Vector2 = corner[0]
		var from: float = corner[1]
		var to: float = corner[2]
		for i in 7:
			var angle: float = lerpf(from, to, i / 6.0)
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	filled_polygon(canvas, points, fill, outline)


static func ellipse(canvas: CanvasItem, center: Vector2, size: Vector2, fill: Color,
		outline: bool = true) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var angle := TAU * i / 24.0
		points.append(center + Vector2(cos(angle) * size.x, sin(angle) * size.y))
	filled_polygon(canvas, points, fill, outline)


static func drop_shadow(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	ellipse(canvas, center, Vector2(radius, radius * 0.35), SHADOW, false)


static func shade(color: Color, amount: float) -> Color:
	if amount >= 0.0:
		return color.lerp(Color.WHITE, amount)
	return color.lerp(Color("#1a1622"), -amount)


## --------------------------------------------------------------------------
## Kale
## --------------------------------------------------------------------------

## Kaleyi (0,0) merkezli, verilen genişlikte çizer. `hp_ratio` kapı bayrağının
## rengini belirler; hasar aldıkça kızarır.
static func draw_castle(canvas: CanvasItem, width: float, stone: Color, hp_ratio: float) -> void:
	var half := width * 0.5
	var height := width * 0.78
	var top := -height * 0.5
	var bottom := height * 0.5

	drop_shadow(canvas, Vector2(0, bottom + 6), half * 1.05)

	# Ana sur
	var wall_top := top + height * 0.32
	rounded_rect(canvas, Rect2(-half, wall_top, width, bottom - wall_top), 4.0, stone)

	# Mazgallar
	var merlon_w := width / 7.0
	for i in 4:
		var x := -half + i * merlon_w * 1.75
		rounded_rect(canvas, Rect2(x, wall_top - merlon_w * 0.6, merlon_w, merlon_w * 0.7),
			2.0, shade(stone, 0.08))

	# Yan kuleler
	for side in [-1.0, 1.0]:
		var tower_w := width * 0.24
		var tower_x: float = side * (half - tower_w * 0.5) - tower_w * 0.5
		rounded_rect(canvas, Rect2(tower_x, top + height * 0.12, tower_w, height * 0.88),
			4.0, shade(stone, -0.08))
		# Konik çatı
		filled_polygon(canvas, PackedVector2Array([
			Vector2(tower_x - 4, top + height * 0.12),
			Vector2(tower_x + tower_w * 0.5, top - height * 0.06),
			Vector2(tower_x + tower_w + 4, top + height * 0.12),
		]), Color("#8c3f3f"))

	# Kapı
	var gate_w := width * 0.26
	var gate_h := height * 0.42
	var gate_rect := Rect2(-gate_w * 0.5, bottom - gate_h, gate_w, gate_h)
	rounded_rect(canvas, gate_rect, gate_w * 0.45, Color("#4a3524"))

	# Bayrak — can azaldıkça yeşilden kırmızıya döner
	var flag := Color("#4fbf6a").lerp(Color("#c94a3f"), 1.0 - clampf(hp_ratio, 0.0, 1.0))
	var pole := Vector2(0, wall_top - merlon_w * 0.6)
	canvas.draw_line(pole, pole + Vector2(0, -height * 0.28), OUTLINE, 3.0)
	filled_polygon(canvas, PackedVector2Array([
		pole + Vector2(0, -height * 0.28),
		pole + Vector2(width * 0.16, -height * 0.22),
		pole + Vector2(0, -height * 0.16),
	]), flag)


## --------------------------------------------------------------------------
## Kuleler
## --------------------------------------------------------------------------

## Kule tipine ve seviyesine (1-3) göre çizim. Seviye arttıkça kule büyür,
## katman kazanır ve tepesi belirginleşir — görsel olarak ayırt edilebilir.
## `stone` gövdenin (kozmetik) rengi, `accent` kule tipinin rengidir; ikisi ayrı
## tutulur ki kozmetik seçimi kule tiplerini birbirine benzetmesin.
static func draw_tower(canvas: CanvasItem, tower_type: String, level: int, radius: float,
		stone: Color, accent: Color) -> void:
	var tint := stone
	var scale := 1.0 + (level - 1) * 0.14
	var base_w := radius * 1.5 * scale
	var base_h := radius * 1.7 * scale
	drop_shadow(canvas, Vector2(0, base_h * 0.5 + 4), base_w * 0.6)

	# Taş gövde: aşağı doğru genişleyen yamuk
	filled_polygon(canvas, PackedVector2Array([
		Vector2(-base_w * 0.38, -base_h * 0.5),
		Vector2(base_w * 0.38, -base_h * 0.5),
		Vector2(base_w * 0.5, base_h * 0.5),
		Vector2(-base_w * 0.5, base_h * 0.5),
	]), tint)

	# Seviye kuşakları
	for i in range(1, level):
		var y := base_h * 0.5 - i * base_h * 0.26
		canvas.draw_line(Vector2(-base_w * 0.44, y), Vector2(base_w * 0.44, y),
			shade(tint, -0.25), 2.5)

	# Tip rengini taşıyan bir kuşak: küçük ekranda kule tipini anında ayırt ettirir.
	canvas.draw_line(Vector2(-base_w * 0.46, -base_h * 0.5 + 6.0),
		Vector2(base_w * 0.46, -base_h * 0.5 + 6.0), accent, 8.0, true)

	match tower_type:
		"okcu":
			_draw_archer_top(canvas, base_w, base_h, accent, level)
		"buyu":
			_draw_mage_top(canvas, base_w, base_h, accent, level)
		"mancinik":
			_draw_catapult_top(canvas, base_w, base_h, accent, level)
		"sifa":
			_draw_fountain_top(canvas, base_w, base_h, accent, level)


static func _draw_archer_top(canvas: CanvasItem, w: float, h: float, tint: Color, level: int) -> void:
	# Mazgallı platform
	var top := -h * 0.5
	rounded_rect(canvas, Rect2(-w * 0.46, top - h * 0.16, w * 0.92, h * 0.18), 2.0, shade(tint, 0.12))
	for i in 3:
		var x := -w * 0.4 + i * w * 0.34
		rounded_rect(canvas, Rect2(x, top - h * 0.27, w * 0.14, h * 0.13), 1.0, shade(tint, 0.2))
	# Yay: seviyeye göre kalınlaşır
	canvas.draw_arc(Vector2(0, top - h * 0.05), w * 0.22, PI * 1.15, PI * 1.85, 12,
		Color("#7a4a22"), 2.0 + level, true)


static func _draw_mage_top(canvas: CanvasItem, w: float, h: float, accent: Color,
		level: int) -> void:
	var top := -h * 0.5
	# Sivri külah
	filled_polygon(canvas, PackedVector2Array([
		Vector2(-w * 0.44, top),
		Vector2(0, top - h * (0.30 + 0.05 * level)),
		Vector2(w * 0.44, top),
	]), shade(accent, -0.15))
	# Yüzen rün küresi
	var orb := Vector2(0, top - h * (0.34 + 0.05 * level))
	filled_circle(canvas, orb, 5.0 + level * 1.6, Color("#8fd6ff"))
	canvas.draw_arc(orb, 9.0 + level * 2.0, 0.0, TAU, 18, Color(0.6, 0.85, 1.0, 0.5), 2.0, true)


static func _draw_catapult_top(canvas: CanvasItem, w: float, h: float, accent: Color,
		level: int) -> void:
	var top := -h * 0.5
	rounded_rect(canvas, Rect2(-w * 0.5, top - h * 0.1, w, h * 0.12), 2.0, shade(accent, -0.25))
	# Fırlatma kolu
	var pivot := Vector2(-w * 0.1, top - h * 0.08)
	var arm_end := pivot + Vector2(w * 0.46, -h * (0.24 + 0.04 * level))
	canvas.draw_line(pivot, arm_end, Color("#7a5330"), 5.0 + level, true)
	filled_circle(canvas, arm_end, 5.0 + level * 1.5, Color("#5a5f66"))


static func _draw_fountain_top(canvas: CanvasItem, w: float, h: float, accent: Color,
		level: int) -> void:
	var top := -h * 0.5
	# Çanak
	filled_polygon(canvas, PackedVector2Array([
		Vector2(-w * 0.42, top),
		Vector2(w * 0.42, top),
		Vector2(w * 0.3, top - h * 0.14),
		Vector2(-w * 0.3, top - h * 0.14),
	]), Color("#cfd8dd"))
	# Su
	ellipse(canvas, Vector2(0, top - h * 0.13), Vector2(w * 0.28, h * 0.05), accent, false)
	for i in level:
		var offset := (i - (level - 1) * 0.5) * w * 0.2
		canvas.draw_line(Vector2(offset, top - h * 0.14), Vector2(offset, top - h * 0.3),
			Color(0.55, 0.9, 0.7, 0.75), 2.5)


## Boş kule yuvası: kesik çizgili daire + yerleştirme ipucu.
static func draw_slot(canvas: CanvasItem, radius: float, highlight: bool, pulse: float) -> void:
	var color := Color("#f4d06a") if highlight else Color(1, 1, 1, 0.28)
	var segments := 16
	for i in segments:
		if i % 2 == 1:
			continue
		var from := TAU * i / segments
		var to := TAU * (i + 1) / segments
		canvas.draw_arc(Vector2.ZERO, radius, from, to, 4, color, 3.0, true)
	if highlight:
		var alpha := 0.18 + 0.12 * sin(pulse * 4.0)
		canvas.draw_circle(Vector2.ZERO, radius * 0.92, Color(0.96, 0.82, 0.42, alpha))
		# Artı işareti
		canvas.draw_line(Vector2(-radius * 0.3, 0), Vector2(radius * 0.3, 0), color, 3.0)
		canvas.draw_line(Vector2(0, -radius * 0.3), Vector2(0, radius * 0.3), color, 3.0)


## --------------------------------------------------------------------------
## Düşmanlar
## --------------------------------------------------------------------------

## `walk` yürüyüş animasyonu için 0..TAU arası faz.
static func draw_enemy(canvas: CanvasItem, enemy_type: String, radius: float, tint: Color,
		walk: float, facing: float) -> void:
	var bob := sin(walk) * radius * 0.08
	var center := Vector2(0, bob)
	drop_shadow(canvas, Vector2(0, radius * 0.95), radius * 0.62)

	match enemy_type:
		"hayalet":
			_draw_ghost(canvas, center, radius, tint, walk)
			return
		"zirhli_trol":
			_draw_armored(canvas, center, radius, tint, walk, facing)
			return
		"harf_hirsizi":
			_draw_thief(canvas, center, radius, tint, walk, facing)
			return

	# Bacaklar
	for side in [-1.0, 1.0]:
		var swing := sin(walk + (0.0 if side < 0.0 else PI)) * radius * 0.22
		canvas.draw_line(center + Vector2(side * radius * 0.28, radius * 0.35),
			center + Vector2(side * radius * 0.28 + swing, radius * 0.95),
			shade(tint, -0.35), radius * 0.22, true)
	# Gövde
	ellipse(canvas, center, Vector2(radius * 0.62, radius * 0.68), tint)
	# Kafa
	var head := center + Vector2(0, -radius * 0.72)
	filled_circle(canvas, head, radius * 0.46, shade(tint, 0.1))
	# Gözler
	_draw_eyes(canvas, head, radius, facing, Color("#2a1c14"))
	# Kulaklar (goblin/ork siluetini ayırt eder)
	if enemy_type == "goblin":
		for side in [-1.0, 1.0]:
			filled_polygon(canvas, PackedVector2Array([
				head + Vector2(side * radius * 0.38, -radius * 0.08),
				head + Vector2(side * radius * 0.86, -radius * 0.42),
				head + Vector2(side * radius * 0.4, radius * 0.16),
			]), shade(tint, -0.1))
	elif enemy_type == "ork":
		# Dişler
		for side in [-1.0, 1.0]:
			filled_polygon(canvas, PackedVector2Array([
				head + Vector2(side * radius * 0.2, radius * 0.16),
				head + Vector2(side * radius * 0.3, radius * 0.02),
				head + Vector2(side * radius * 0.1, radius * 0.06),
			]), Color("#f2eadb"))


static func _draw_eyes(canvas: CanvasItem, head: Vector2, radius: float, facing: float,
		color: Color) -> void:
	var dir := signf(facing) if absf(facing) > 0.01 else -1.0
	for side in [-1.0, 1.0]:
		var eye := head + Vector2(side * radius * 0.18 + dir * radius * 0.06, -radius * 0.06)
		filled_circle(canvas, eye, radius * 0.09, color, false)


static func _draw_ghost(canvas: CanvasItem, center: Vector2, radius: float, tint: Color,
		walk: float) -> void:
	var body := tint
	body.a = 0.72
	var points := PackedVector2Array()
	# Üst yarım daire
	for i in 13:
		var angle := PI + PI * i / 12.0
		points.append(center + Vector2(cos(angle) * radius * 0.68, sin(angle) * radius * 0.8))
	# Dalgalı etek
	for i in range(4, -1, -1):
		var x := lerpf(radius * 0.68, -radius * 0.68, (4 - i) / 4.0)
		var wave := sin(walk * 1.5 + i) * radius * 0.12
		points.append(center + Vector2(x, radius * 0.62 + wave))
	filled_polygon(canvas, points, body)
	_draw_eyes(canvas, center + Vector2(0, -radius * 0.22), radius * 1.15, -1.0, Color("#1d2436"))


static func _draw_armored(canvas: CanvasItem, center: Vector2, radius: float, tint: Color,
		walk: float, facing: float) -> void:
	for side in [-1.0, 1.0]:
		var swing := sin(walk + (0.0 if side < 0.0 else PI)) * radius * 0.16
		canvas.draw_line(center + Vector2(side * radius * 0.3, radius * 0.35),
			center + Vector2(side * radius * 0.3 + swing, radius * 0.95),
			shade(tint, -0.4), radius * 0.26, true)
	ellipse(canvas, center, Vector2(radius * 0.74, radius * 0.72), tint)
	# Zırh plakaları — mancınığın parçaladığı katman
	for i in 3:
		var y := center.y - radius * 0.3 + i * radius * 0.3
		canvas.draw_line(Vector2(center.x - radius * 0.6, y), Vector2(center.x + radius * 0.6, y),
			shade(tint, 0.25), radius * 0.12, true)
	var head := center + Vector2(0, -radius * 0.76)
	filled_circle(canvas, head, radius * 0.4, shade(tint, -0.1))
	# Miğfer siperliği
	canvas.draw_line(head + Vector2(-radius * 0.34, 0), head + Vector2(radius * 0.34, 0),
		Color("#2a2f38"), radius * 0.16, true)
	_draw_eyes(canvas, head, radius, facing, Color("#ffd35c"))


static func _draw_thief(canvas: CanvasItem, center: Vector2, radius: float, tint: Color,
		walk: float, facing: float) -> void:
	for side in [-1.0, 1.0]:
		var swing := sin(walk * 1.4 + (0.0 if side < 0.0 else PI)) * radius * 0.3
		canvas.draw_line(center + Vector2(side * radius * 0.22, radius * 0.3),
			center + Vector2(side * radius * 0.22 + swing, radius * 0.95),
			shade(tint, -0.35), radius * 0.18, true)
	ellipse(canvas, center, Vector2(radius * 0.5, radius * 0.6), tint)
	var head := center + Vector2(0, -radius * 0.68)
	filled_circle(canvas, head, radius * 0.4, shade(tint, 0.12))
	# Kukuleta
	filled_polygon(canvas, PackedVector2Array([
		head + Vector2(-radius * 0.44, 0),
		head + Vector2(0, -radius * 0.62),
		head + Vector2(radius * 0.44, 0),
	]), shade(tint, -0.3))
	_draw_eyes(canvas, head, radius, facing, Color("#ffe9a8"))
	# Çaldığı harfi taşıdığı torba
	filled_circle(canvas, center + Vector2(radius * 0.5, radius * 0.1), radius * 0.26,
		Color("#e2c68a"))


## Boss'lar aynı temel siluetin büyütülmüş ve taçlı hâlidir.
static func draw_boss(canvas: CanvasItem, radius: float, tint: Color, walk: float,
		facing: float, phase: int) -> void:
	draw_enemy(canvas, "ork", radius, tint, walk, facing)
	var head := Vector2(0, sin(walk) * radius * 0.08 - radius * 0.72)
	# Taç — faz sayısı kadar sivri uç
	var crown := Color("#f4d06a")
	var spikes := 3 + phase
	var points := PackedVector2Array()
	points.append(head + Vector2(-radius * 0.5, -radius * 0.3))
	for i in spikes:
		var t := i / float(maxi(spikes - 1, 1))
		points.append(head + Vector2(lerpf(-radius * 0.42, radius * 0.42, t), -radius * 0.72))
		points.append(head + Vector2(lerpf(-radius * 0.42, radius * 0.42, t + 0.5 / spikes),
			-radius * 0.34))
	points.append(head + Vector2(radius * 0.5, -radius * 0.3))
	filled_polygon(canvas, points, crown)


## --------------------------------------------------------------------------
## Mermiler ve efektler
## --------------------------------------------------------------------------

static func draw_projectile(canvas: CanvasItem, kind: String, tint: Color, spin: float) -> void:
	match kind:
		"okcu":
			# Ok
			canvas.draw_line(Vector2(-10, 0), Vector2(8, 0), Color("#6b4a2c"), 3.0, true)
			filled_polygon(canvas, PackedVector2Array([
				Vector2(14, 0), Vector2(4, -4), Vector2(4, 4),
			]), Color("#cfd8dd"), false)
		"buyu":
			filled_circle(canvas, Vector2.ZERO, 8.0, tint, false)
			canvas.draw_arc(Vector2.ZERO, 12.0, spin, spin + PI * 1.4, 12,
				Color(tint.r, tint.g, tint.b, 0.6), 3.0, true)
		"mancinik":
			filled_circle(canvas, Vector2.ZERO, 11.0, Color("#5a5f66"))
			canvas.draw_arc(Vector2.ZERO, 6.0, spin, spin + PI, 8, Color("#3b4048"), 2.0, true)
		_:
			filled_circle(canvas, Vector2.ZERO, 7.0, tint, false)


## Patlama halkası: 0..1 arası ilerlemeye göre büyüyüp solar.
static func draw_burst(canvas: CanvasItem, progress: float, radius: float, tint: Color) -> void:
	var t := clampf(progress, 0.0, 1.0)
	var color := Color(tint.r, tint.g, tint.b, (1.0 - t) * 0.8)
	canvas.draw_arc(Vector2.ZERO, radius * (0.3 + t * 0.7), 0.0, TAU, 28, color, 4.0 * (1.0 - t) + 1.0, true)
