class_name StarRow
extends Control

## Sonuç ekranındaki yıldızlar. Metin karakteri (★) yerine çizilir ve
## kazanılanlar sırayla, hafif bir zıplamayla belirir — zafer anı hissi.

const POP_DELAY := 0.32     ## yıldızlar arası gecikme
const POP_TIME := 0.45

var earned := 0

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	# Son yıldız da yerleştikten sonra çizmeyi bırak.
	if _time > POP_DELAY * 3.0 + POP_TIME + 0.4:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var radius := minf(size.y * 0.42, size.x * 0.16)
	if radius <= 0.0:
		return
	var gap := radius * 2.6
	var center := Vector2(size.x * 0.5, size.y * 0.5)

	for i in 3:
		var point := center + Vector2((i - 1) * gap, 0)
		if i >= earned:
			# Kazanılmayan yıldız: sönük oyuk.
			ProcArt.star(self, point, radius, Color(0, 0, 0, 0.35), false)
			draw_arc(point, radius * 0.98, 0.0, TAU, 20, Color(1, 1, 1, 0.10), 2.0, true)
			continue

		var t := clampf((_time - i * POP_DELAY) / POP_TIME, 0.0, 1.0)
		if t <= 0.0:
			continue
		# Hedefin biraz üstüne çıkıp yerine oturur.
		var pop := 1.0 + sin(t * PI) * 0.35
		var alpha := clampf(t * 2.0, 0.0, 1.0)
		var glow := Color(0.96, 0.82, 0.42, (1.0 - t) * 0.5)
		if t < 1.0:
			draw_arc(point, radius * (1.4 + (1.0 - t) * 1.2), 0.0, TAU, 24, glow, 5.0, true)
		ProcArt.star(self, point, radius * pop, Color(0.96, 0.82, 0.42, alpha))
