class_name KingdomMap
extends Control

## Krallık haritası — 60 bölümün kıvrılan bir yol üzerinde dizildiği ekran.
##
## Önceki hâli düz bir kutucuk ızgarasıydı; ilerleme hissi vermiyordu ve dört
## bölge birbirinden ayırt edilemiyordu. Burada her bölge kendi paletiyle
## (GameConfig.REGION_THEMES) çizilir, düğümler yılankavi bir yol boyunca
## sıralanır, kilitli bölgeler sisle kapatılır.
##
## Dokunma isabeti `_gui_input` içinde en yakın düğüme bakılarak çözülür —
## düğüm başına ayrı Button koymak yerine. Böylece hem çizim hem isabet tek
## yerde durur ve dokunma hedefi (NODE_TOUCH) görsel yarıçaptan bağımsız
## büyük tutulabilir.

signal level_selected(level_id: int)

const NODE_RADIUS := 46.0
const BOSS_RADIUS := 62.0
const NODE_TOUCH := 76.0
const ROW_HEIGHT := 128.0        ## iki bölüm arası dikey mesafe
const BANNER_HEIGHT := 150.0     ## bölge başlığı için ayrılan yer
const WAVE_AMPLITUDE := 0.26     ## yolun yatay salınımı (genişliğe oran)
const REDRAW_HZ := 15.0

var _nodes: Array = []           ## [{id, konum, bolge, kilitli, yildiz, boss}]
var _region_bands: Array = []    ## [{bolge, ust, alt, acik, gereken}]
var _pulse := 0.0
var _redraw_timer := 0.0
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, _total_height())
	resized.connect(_rebuild)
	_rebuild()


func _total_height() -> float:
	var per_region := BANNER_HEIGHT + GameConfig.LEVELS_PER_REGION * ROW_HEIGHT
	return per_region * GameConfig.REGIONS.size() + 80.0


## --------------------------------------------------------------------------
## Yerleşim
## --------------------------------------------------------------------------

func _rebuild() -> void:
	_nodes.clear()
	_region_bands.clear()
	if size.x <= 0.0:
		return

	var total_stars := SaveManager.total_stars()
	var cursor := 40.0

	for region_index in GameConfig.REGIONS.size():
		var region: Dictionary = GameConfig.REGIONS[region_index]
		var needed := int(region["gereken_yildiz"])
		var region_open := total_stars >= needed
		var band_top := cursor
		cursor += BANNER_HEIGHT

		for step in GameConfig.LEVELS_PER_REGION:
			var level_id := region_index * GameConfig.LEVELS_PER_REGION + step + 1
			# Yılankavi yol: dikey ilerlerken yatayda sinüsle salınır.
			var phase := step * 0.62
			var x := size.x * 0.5 + sin(phase) * size.x * WAVE_AMPLITUDE
			var y := cursor + ROW_HEIGHT * 0.5
			_nodes.append({
				"id": level_id,
				"konum": Vector2(x, y),
				"bolge": region_index,
				"kilitli": not (region_open and SaveManager.is_level_unlocked(level_id)),
				"yildiz": SaveManager.level_stars(level_id),
				"boss": GameConfig.is_boss_level(level_id),
			})
			cursor += ROW_HEIGHT

		_region_bands.append({
			"bolge": region_index,
			"ust": band_top,
			"alt": cursor,
			"acik": region_open,
			"gereken": needed,
		})

	custom_minimum_size = Vector2(0, cursor + 40.0)
	queue_redraw()


## Oyuncunun sıradaki bölümünün dikey konumu — ekran açılınca oraya kaydırmak için.
func focus_offset(viewport_height: float) -> float:
	var target := SaveManager.highest_unlocked_level()
	for node in _nodes:
		if int(node["id"]) == target:
			return maxf(0.0, float(node["konum"].y) - viewport_height * 0.55)
	return 0.0


## --------------------------------------------------------------------------
## Girdi
## --------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var point := Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		point = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			point = click.position
	if point == Vector2.INF:
		return

	var best: Dictionary = {}
	var best_distance := NODE_TOUCH
	for node in _nodes:
		var distance: float = (node["konum"] as Vector2).distance_to(point)
		if distance <= best_distance:
			best_distance = distance
			best = node
	if best.is_empty() or bool(best["kilitli"]):
		return
	accept_event()
	AudioManager.play_sfx("dugme")
	level_selected.emit(int(best["id"]))


func _process(delta: float) -> void:
	_pulse += delta
	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = 1.0 / REDRAW_HZ
		queue_redraw()


## --------------------------------------------------------------------------
## Çizim
## --------------------------------------------------------------------------

func _draw() -> void:
	if _region_bands.is_empty():
		return
	for band in _region_bands:
		_draw_region(band)
	_draw_trail()
	for node in _nodes:
		_draw_node(node)
	# Sis, düğümlerin üstünde kalmalı ki kilitli bölge gerçekten kapalı görünsün.
	for band in _region_bands:
		if not bool(band["acik"]):
			_draw_fog(band)


func _theme_of(region_index: int) -> Dictionary:
	var region: Dictionary = GameConfig.REGIONS[region_index]
	return GameConfig.REGION_THEMES.get(region["id"], GameConfig.REGION_THEMES["yesil_vadi"])


func _draw_region(band: Dictionary) -> void:
	var theme := _theme_of(int(band["bolge"]))
	var top := float(band["ust"])
	var bottom := float(band["alt"])
	var rect := Rect2(0, top, size.x, bottom - top)

	# Zemin degradesi
	draw_polygon(PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y),
	]), PackedColorArray([
		Color(theme["gok_alt"]), Color(theme["gok_alt"]),
		Color(theme["zemin_alt"]), Color(theme["zemin_alt"]),
	]))

	# Silüet süsler: bölgeyi tanıtan, yolu kapatmayan basit şekiller.
	var silhouette := Color(theme["ufuk"])
	silhouette.a = 0.55
	var rng := RandomNumberGenerator.new()
	rng.seed = int(band["bolge"]) * 977 + 31
	for i in 26:
		var point := Vector2(rng.randf_range(0.0, size.x), rng.randf_range(top + 60.0, bottom - 30.0))
		# Yolun ortasına denk gelenler atlanır.
		if absf(point.x - size.x * 0.5) < size.x * 0.34:
			continue
		var scale := rng.randf_range(0.6, 1.3)
		_draw_silhouette(str(theme["susler"][rng.randi() % (theme["susler"] as Array).size()]),
			point, scale, silhouette)

	_draw_banner(band, theme)


func _draw_silhouette(kind: String, point: Vector2, scale: float, color: Color) -> void:
	var h := 54.0 * scale
	match kind:
		"cam", "agac":
			ProcArt.filled_polygon(self, PackedVector2Array([
				point + Vector2(-h * 0.34, 0), point + Vector2(0, -h),
				point + Vector2(h * 0.34, 0),
			]), color, false)
		"buz":
			ProcArt.filled_polygon(self, PackedVector2Array([
				point + Vector2(-h * 0.22, 0), point + Vector2(0, -h * 1.1),
				point + Vector2(h * 0.22, 0),
			]), color, false)
		_:
			ProcArt.ellipse(self, point + Vector2(0, -h * 0.25),
				Vector2(h * 0.42, h * 0.3), color, false)


func _draw_banner(band: Dictionary, theme: Dictionary) -> void:
	var region: Dictionary = GameConfig.REGIONS[int(band["bolge"])]
	var top := float(band["ust"])
	var center := Vector2(size.x * 0.5, top + BANNER_HEIGHT * 0.5)

	var plate := Rect2(size.x * 0.10, top + 30.0, size.x * 0.80, BANNER_HEIGHT - 60.0)
	ProcArt.shaded_rect(self, plate, 18.0, Color(0.10, 0.08, 0.14, 0.82))
	draw_rect(plate, Color(theme["zerre"]).lerp(Color(0, 0, 0, 0), 0.5), false, 3.0)

	var open := bool(band["acik"])
	_draw_text(str(region["ad"]), center + Vector2(0, -12.0), 40,
		Color(region["renk"]) if open else Color(0.62, 0.60, 0.70))

	var earned := _stars_in_region(int(band["bolge"]))
	var label := "★ %d / %d" % [earned, GameConfig.LEVELS_PER_REGION * 3]
	if not open:
		label = "🔒  %d ★ gerekli" % int(band["gereken"])
	_draw_text(label, center + Vector2(0, 30.0), 24,
		Color(0.85, 0.80, 0.62) if open else Color(0.70, 0.66, 0.78))


func _stars_in_region(region_index: int) -> int:
	var total := 0
	for node in _nodes:
		if int(node["bolge"]) == region_index:
			total += int(node["yildiz"])
	return total


## Düğümleri birleştiren yol: iki kat çizgi + kesik iz.
func _draw_trail() -> void:
	if _nodes.size() < 2:
		return
	var points := PackedVector2Array()
	for node in _nodes:
		points.append(node["konum"])
	draw_polyline(points, Color(0.16, 0.12, 0.09, 0.55), 26.0, true)
	draw_polyline(points, Color(0.72, 0.60, 0.40, 0.75), 16.0, true)
	draw_polyline(points, Color(1, 1, 1, 0.10), 4.0, true)


func _draw_node(node: Dictionary) -> void:
	var point: Vector2 = node["konum"]
	var locked := bool(node["kilitli"])
	var boss := bool(node["boss"])
	var stars := int(node["yildiz"])
	var radius := BOSS_RADIUS if boss else NODE_RADIUS
	var region: Dictionary = GameConfig.REGIONS[int(node["bolge"])]

	# Sıradaki oynanacak bölüm nabız gibi parlar.
	var is_next := not locked and stars == 0
	if is_next:
		var glow := 0.5 + 0.5 * sin(_pulse * 3.0)
		draw_arc(point, radius * (1.25 + glow * 0.18), 0.0, TAU, 32,
			Color(0.96, 0.82, 0.42, 0.30 + glow * 0.35), 6.0, true)

	var fill := Color(region["renk"])
	if boss:
		fill = Color("#b5483c")
	if locked:
		fill = Color(0.28, 0.26, 0.34)
	elif stars > 0:
		fill = fill.lerp(Color("#f4d06a"), 0.18)

	ProcArt.filled_circle(self, point + Vector2(0, 5), radius, Color(0, 0, 0, 0.35), false)
	ProcArt.shaded_circle(self, point, radius, fill)
	draw_arc(point, radius * 0.80, 0.0, TAU, 26, Color(1, 1, 1, 0.16), 3.0, true)

	if locked:
		# Zincir/kilit: bölümün kapalı olduğu tek bakışta anlaşılsın.
		var lock_rect := Rect2(point.x - 15.0, point.y - 4.0, 30.0, 24.0)
		ProcArt.rounded_rect(self, lock_rect, 5.0, Color(0.62, 0.60, 0.70), false)
		draw_arc(point + Vector2(0, -6.0), 12.0, PI, TAU, 14, Color(0.62, 0.60, 0.70), 5.0, true)
		return

	_draw_text(str(node["id"]), point + Vector2(0, -2.0), 34 if not boss else 40,
		Color("#2a2233"))

	if boss:
		# Taç: patron bölümü ayırt edilsin.
		ProcArt.filled_polygon(self, PackedVector2Array([
			point + Vector2(-radius * 0.5, -radius * 0.62),
			point + Vector2(-radius * 0.28, -radius * 1.02),
			point + Vector2(0, -radius * 0.72),
			point + Vector2(radius * 0.28, -radius * 1.02),
			point + Vector2(radius * 0.5, -radius * 0.62),
		]), Color("#f4d06a"), true)

	# Yıldızlar düğümün altında
	for i in 3:
		var star_point := point + Vector2((i - 1) * 26.0, radius * 0.78)
		var filled := i < stars
		ProcArt.star(self, star_point, 12.0,
			Color("#f4d06a") if filled else Color(0, 0, 0, 0.32), filled)


func _draw_fog(band: Dictionary) -> void:
	var top := float(band["ust"])
	var bottom := float(band["alt"])
	# Üstte yumuşak geçiş, altta yoğun sis: bölge "ilerisi görünmüyor" hissi.
	draw_polygon(PackedVector2Array([
		Vector2(0, top), Vector2(size.x, top),
		Vector2(size.x, top + 120.0), Vector2(0, top + 120.0),
	]), PackedColorArray([
		Color(0.08, 0.07, 0.12, 0.30), Color(0.08, 0.07, 0.12, 0.30),
		Color(0.08, 0.07, 0.12, 0.80), Color(0.08, 0.07, 0.12, 0.80),
	]))
	draw_rect(Rect2(0, top + 120.0, size.x, bottom - top - 120.0),
		Color(0.08, 0.07, 0.12, 0.80))


func _draw_text(text: String, center: Vector2, font_size: int, color: Color) -> void:
	if _font == null:
		return
	var measured := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var origin := center - Vector2(measured.x * 0.5, -measured.y * 0.32)
	draw_string_outline(_font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 8,
		Color(0, 0, 0, 0.55))
	draw_string(_font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
