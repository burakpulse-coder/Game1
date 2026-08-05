class_name PathTrack
extends Node2D

## Düşmanların izlediği yol. Yol noktaları savaş alanı dikdörtgenine göre
## oranlı tanımlanır, böylece her en-boy oranında aynı tasarım korunur.
##
## Düşmanlar sağdan (ve üçüncü yolda üstten) girer, kaleye doğru kıvrılarak iner.

const PATH_WIDTH := 86.0
const EDGE_COLOR := Color("#3b3350")
const FILL_COLOR := Color("#5a4f36")
const DASH_COLOR := Color(1, 1, 1, 0.10)

## Yol şablonları (oranlı koordinatlar). Son nokta kalenin bulunduğu yerdir.
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


func setup(path_index: int, rect: Rect2) -> void:
	index = path_index
	var template: Array = TEMPLATES[path_index % TEMPLATES.size()]
	_points = PackedVector2Array()
	for ratio in template:
		_points.append(rect.position + Vector2(rect.size.x * ratio.x, rect.size.y * ratio.y))
	_rebuild_curve()
	queue_redraw()


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
