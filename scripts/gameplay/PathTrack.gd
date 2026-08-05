class_name PathTrack
extends Node2D

const SpriteBank := preload("res://scripts/core/SpriteBank.gd")


func _ready() -> void:
	# UV birden büyük olduğu için doku tekrarı açık olmalı.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

## Düşmanların izlediği yol. Yol noktaları savaş alanı dikdörtgenine göre
## oranlı tanımlanır, böylece her en-boy oranında aynı tasarım korunur.
##
## Düşmanlar sağdan (ve üçüncü yolda üstten) girer, kaleye doğru kıvrılarak iner.

const PATH_WIDTH := 86.0
const EDGE_COLOR := Color("#3b3350")
const FILL_COLOR := Color("#5a4f36")
const DASH_COLOR := Color(1, 1, 1, 0.10)

## Yol şablonları (oranlı koordinatlar). Son nokta kalenin bulunduğu yerdir.
## Yolun bittiği nokta (oran). Kale burada durur, bu yüzden bütün yollar —
## çok yollu bölümlerde de — aynı noktada birleşir.
const FINISH := Vector2(0.10, 0.84)
## Üretilen yolun uzunluğu şablonunkinden bu kadar sapabilir. Yol uzunluğu
## düşmanın kaleye varma süresini belirliyor; serbest bırakılırsa bölümün
## zorluğu bölümden bölüme rastgele kayardı.
const LENGTH_BAND := 0.16
const LENGTH_TRIES := 14

const TEMPLATES := [
	[Vector2(1.08, 0.20), Vector2(0.63, 0.20), Vector2(0.63, 0.54), Vector2(0.30, 0.54),
		Vector2(0.30, 0.84), Vector2(0.10, 0.84)],
	[Vector2(1.08, 0.70), Vector2(0.76, 0.70), Vector2(0.76, 0.34), Vector2(0.46, 0.34),
		Vector2(0.46, 0.84), Vector2(0.10, 0.84)],
	[Vector2(0.52, -0.08), Vector2(0.52, 0.28), Vector2(0.88, 0.28), Vector2(0.88, 0.62),
		Vector2(0.22, 0.62), Vector2(0.22, 0.84), Vector2(0.10, 0.84)],
]

var region_theme := {}
var index := 0
var curve := Curve2D.new()
var _points := PackedVector2Array()


## `layout_seed` bölüm numarasıdır: aynı bölüm her açılışta aynı yolu verir,
## farklı bölümler farklı yol alır. 0 verilirse sabit şablonlar kullanılır
## (testler ve menü arka planları için).
func setup(path_index: int, rect: Rect2, layout_seed: int = 0) -> void:
	index = path_index
	var ratios := TEMPLATES[path_index % TEMPLATES.size()] as Array
	if layout_seed > 0:
		ratios = _generate_ratios(layout_seed, path_index, rect)
	_points = PackedVector2Array()
	for ratio in ratios:
		_points.append(rect.position + Vector2(rect.size.x * ratio.x, rect.size.y * ratio.y))
	_rebuild_curve()
	queue_redraw()


## Bölüme özgü bir yol üretir.
##
## Yol dik açılı bir merdiven: kenardan girer, birkaç kez döner ve kalede
## biter. Uzunluğu şablonunkine yakın kalana kadar farklı tohumlarla denenir;
## tutmazsa şablona düşülür — bölüm oynanamaz hâle gelmesin.
func _generate_ratios(layout_seed: int, path_index: int, rect: Rect2) -> Array:
	var template: Array = TEMPLATES[path_index % TEMPLATES.size()]
	var target := _ratio_length(template, rect)
	var rng := RandomNumberGenerator.new()
	for attempt in LENGTH_TRIES:
		rng.seed = layout_seed * 7919 + path_index * 104729 + attempt * 131
		var candidate := _staircase(rng)
		var length := _ratio_length(candidate, rect)
		if absf(length - target) <= target * LENGTH_BAND:
			return candidate
	return template


## Dik açılı merdiven: giriş kenarı, ara köşeler ve bitiş.
func _staircase(rng: RandomNumberGenerator) -> Array:
	var points: Array = []
	var corners := rng.randi_range(2, 4)

	# Giriş: sağ kenardan ya da üstten. Üstten giriş HUD'un altından başlar.
	var from_right := rng.randf() < 0.62
	var entry_y := rng.randf_range(0.14, 0.62) if from_right else 0.10
	var entry_x := 1.08 if from_right else rng.randf_range(0.42, 0.94)
	if not from_right:
		points.append(Vector2(entry_x, -0.08))
		points.append(Vector2(entry_x, entry_y))
	else:
		points.append(Vector2(entry_x, entry_y))

	# Ara köşeler: x soldan sağa azalır, y yukarıdan aşağı artar.
	var x := entry_x
	var y := entry_y
	for i in corners:
		var t := (i + 1.0) / (corners + 1.0)
		var next_x := clampf(lerpf(entry_x, FINISH.x, t) + rng.randf_range(-0.10, 0.10),
			FINISH.x + 0.06, 0.94)
		var next_y := clampf(lerpf(entry_y, FINISH.y, t) + rng.randf_range(-0.07, 0.07),
			0.10, FINISH.y - 0.04)
		# Dik açı: önce yatay, sonra dikey.
		points.append(Vector2(next_x, y))
		points.append(Vector2(next_x, next_y))
		x = next_x
		y = next_y

	# Bitiş: kaleye son iniş ve yatay giriş.
	points.append(Vector2(x, FINISH.y))
	points.append(FINISH)
	return points


func _ratio_length(ratios: Array, rect: Rect2) -> float:
	var total := 0.0
	for i in ratios.size() - 1:
		var a: Vector2 = Vector2(ratios[i].x * rect.size.x, ratios[i].y * rect.size.y)
		var b: Vector2 = Vector2(ratios[i + 1].x * rect.size.x, ratios[i + 1].y * rect.size.y)
		total += a.distance_to(b)
	return total


func _rebuild_curve() -> void:
	curve.clear_points()
	# Köşeleri yuvarlatmak için her köşede kısa bir kontrol noktası kullanılır;
	# düşmanlar dik dönüş yerine yumuşak yay çizer.
	for i in _points.size():
		var point := _points[i]
		var incoming := Vector2.ZERO
		var outgoing := Vector2.ZERO
		if i > 0:
			incoming = (_points[i - 1] - point).normalized() * 26.0
		if i < _points.size() - 1:
			outgoing = (_points[i + 1] - point).normalized() * 26.0
		curve.add_point(point, incoming, outgoing)


func length() -> float:
	return curve.get_baked_length()


func position_at(distance: float) -> Vector2:
	return curve.sample_baked(clampf(distance, 0.0, length()))


## Yolun bittiği (kalenin olduğu) nokta.
func end_point() -> Vector2:
	return _points[_points.size() - 1] if _points.size() > 0 else Vector2.ZERO


## Verilen noktaya en yakın yol noktasının uzaklığı — kule yuvası yerleşiminde
## yolun üstüne kule konmasını engellemek için kullanılır.
func distance_to_path(point: Vector2) -> float:
	var best := INF
	var steps := 48
	var total := length()
	for i in steps + 1:
		var sample := position_at(total * i / float(steps))
		best = minf(best, sample.distance_to(point))
	return best


func _draw() -> void:
	if curve.point_count < 2:
		return
	var baked := curve.get_baked_points()
	var fill := Color(region_theme.get("yol", FILL_COLOR.to_html()))
	var edge := Color(region_theme.get("yol_kenar", EDGE_COLOR.to_html()))

	# Paletten bağımsız koyu dış hat. Bölge renkleri zemine göre ayarlanmıştı;
	# elle çizilmiş zeminler gelince açık bölgelerde (buz) yol zemine karışıyordu.
	# Sabit koyu bir hale her zeminde yolu ayırır, koyu bölgelerde ise fark
	# edilmeyecek kadar hafif kalır.
	draw_polyline(baked, Color(0, 0, 0, 0.30), PATH_WIDTH + 26.0, true)

	# Toprak kenar + zemin
	draw_polyline(baked, ProcArt.shade(edge, -0.25), PATH_WIDTH + 16.0, true)
	draw_polyline(baked, edge, PATH_WIDTH + 8.0, true)
	draw_polyline(baked, fill, PATH_WIDTH, true)

	# Elle çizilmiş yol dokusu varsa parke çizimi yerine o döşenir.
	if _draw_textured(baked):
		return

	# Parke taşları: yol boyunca sıralanan, yönüne dik yerleşmiş taşlar.
	# Düz kahverengi şerit yerine dokulu bir yola dönüştürür.
	var total := length()
	var step := 34.0
	var travelled := step * 0.5
	var row := 0
	while travelled < total:
		var here := position_at(travelled)
		var ahead := position_at(minf(travelled + 6.0, total))
		var forward := (ahead - here).normalized()
		var side := Vector2(-forward.y, forward.x)
		var offset := (-1.0 if row % 2 == 0 else 1.0) * PATH_WIDTH * 0.16
		for lane: float in [-1.0, 0.0, 1.0]:
			var center: Vector2 = here + side * (lane * PATH_WIDTH * 0.3 + offset)
			var tone := ProcArt.shade(fill, 0.06 if (row + int(lane)) % 2 == 0 else -0.07)
			draw_colored_polygon(PackedVector2Array([
				center + side * -11.0 + forward * -8.0,
				center + side * 11.0 + forward * -8.0,
				center + side * 11.0 + forward * 8.0,
				center + side * -11.0 + forward * 8.0,
			]), tone)
		travelled += step
		row += 1

	# Yürüyüş yönü ipucu
	draw_polyline(baked, DASH_COLOR, 3.0, true)


## Yol dokusunu şerit boyunca döşer. Tek bir çokgen kullanılamıyor: kıvrılan
## şerit dışbükey değil ve üçgenlemesi bozuluyor. Bunun yerine her parça için
## bir dörtgen çizilir.
##
## Dörtgenler `draw_primitive` ile çizilir, `draw_colored_polygon` ile değil.
## Sebebi ölçülmüş bir hata: köşelerde ardışık örnek noktalar ~3 piksel
## aralıkla gelirken yanal normal 45° dönüyor, dörtgen kendi üstüne katlanıyor
## ve Godot "triangulation failed" deyip o parçayı hiç çizmiyordu — yani her
## köşede yolda delik kalıyordu (tek bölümde 8-18 parça). `draw_primitive`
## üçgenleme yapmaz, köşe sırasını olduğu gibi kullanır: katlanan parça
## kendi üstüne binerek çizilir, boşluk kalmaz.
##
## Dokusu yoksa false döner ve çağıran parke çizimine devam eder.
func _draw_textured(baked: PackedVector2Array) -> bool:
	var texture: Texture2D = SpriteBank.road(str(region_theme.get("id", "")))
	if texture == null or baked.size() < 2:
		return false
	draw_road_strip(self, baked, texture,
		Color(region_theme.get("yol_tint", "#ffffff")))
	return true


## Şeridi verilen tuvale çizer. Ayrı bir fonksiyon, çünkü testler dokulu katmanı
## tek başına (alttaki düz renk şerit olmadan) çizip deliklerini ölçüyor.
##
## `tint` doku rengiyle çarpılır: elle çizilen yol dokuları bölge zeminleriyle
## aynı paletten geldiği için buz ve ejder bölgelerinde yol zemine karışıyordu
## (bkz. GameConfig.REGION_THEMES).
##
## Tuvalin `texture_repeat` ayarı ENABLED olmalı; UV'ler 1'i aşıyor.
static func draw_road_strip(canvas: CanvasItem, baked: PackedVector2Array,
		texture: Texture2D, tint: Color = Color.WHITE) -> void:
	# Her köşe noktası için ORTAK bir yanal kaydırma hesaplanır: gelen ve giden
	# yönün ortalamasına dik. Her parçayı kendi yönüne göre kaydırınca komşu
	# dörtgenler köşelerde ortak kenarı paylaşmıyor ve arada takoz boşluklar
	# kalıyordu.
	var half := PATH_WIDTH * 0.5
	var sides := PackedVector2Array()
	sides.resize(baked.size())
	for i in baked.size():
		var incoming := Vector2.ZERO
		var outgoing := Vector2.ZERO
		if i > 0:
			incoming = (baked[i] - baked[i - 1]).normalized()
		if i < baked.size() - 1:
			outgoing = (baked[i + 1] - baked[i]).normalized()
		var forward := (incoming + outgoing).normalized()
		if forward == Vector2.ZERO:
			forward = outgoing if outgoing != Vector2.ZERO else incoming
		sides[i] = Vector2(-forward.y, forward.x) * half

	var tile := PATH_WIDTH        # dokunun bir kenarının kapladığı yol uzunluğu
	var white := PackedColorArray([tint, tint, tint, tint])
	var travelled := 0.0
	for i in baked.size() - 1:
		var length := baked[i].distance_to(baked[i + 1])
		if length <= 0.01:
			continue
		var v0 := travelled / tile
		var v1 := (travelled + length) / tile
		canvas.draw_primitive(
			PackedVector2Array([
				baked[i] - sides[i], baked[i] + sides[i],
				baked[i + 1] + sides[i + 1], baked[i + 1] - sides[i + 1]]),
			white,
			PackedVector2Array([Vector2(0.0, v0), Vector2(1.0, v0),
				Vector2(1.0, v1), Vector2(0.0, v1)]),
			texture)
		travelled += length
