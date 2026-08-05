class_name EffectLayer
extends Node2D

## Savaş alanının tüm geçici efektleri tek bir düğümde toplanır.
##
## Neden tek düğüm: her efekt ayrı Node olsaydı her biri kendi _draw()'unu
## çağırırdı. Burada hepsi tek bir _draw() içinde çizilir ve efekt kalmayınca
## düğüm _process/_draw'u tamamen bırakır — düşük cihazlarda bedava.
##
## Efektler oynanışı etkilemez: hasar, ölüm ve sayaçlar Battlefield tarafında
## anında işlenir; buradaki "ölüm" efekti yalnızca görsel bir kalıntıdır.
## Bu ayrım sayesinde canlı düşman sayımı (zafer koşulu) efektlerden etkilenmez.

const MAX_PARTICLES := 240
const GRAVITY := 900.0

var _sparks: Array = []      ## {konum, hiz, omur, sure, renk, boyut}
var _rings: Array = []       ## {konum, t, sure, yaricap, renk, kalinlik}
var _corpses: Array = []     ## {tip, konum, t, yaricap, renk, yon}
var _texts: Array = []       ## {konum, metin, t, sure, renk, boyut}
var _font: Font


func _ready() -> void:
	z_index = 9
	_font = ThemeDB.fallback_font
	set_process(false)


func _budget_left() -> int:
	return MAX_PARTICLES - _sparks.size()


func _wake() -> void:
	set_process(true)


## --------------------------------------------------------------------------
## Efekt üretimi
## --------------------------------------------------------------------------

## Dağılan kıvılcımlar. Yerçekimiyle düşer, sönerek kaybolur.
func sparks(point: Vector2, count: int, color: Color, speed: float = 260.0,
		spread: float = TAU, direction: float = 0.0, gravity: float = 1.0) -> void:
	var amount := count if not PerfManager.low_quality else int(count * 0.4)
	amount = mini(amount, _budget_left())
	for i in amount:
		var angle := direction + randf_range(-spread * 0.5, spread * 0.5)
		var velocity := Vector2(cos(angle), sin(angle)) * speed * randf_range(0.45, 1.15)
		_sparks.append({
			"konum": point,
			"hiz": velocity,
			"sure": randf_range(0.28, 0.62),
			"omur": 0.0,
			"renk": color,
			"boyut": randf_range(2.5, 5.5),
			"yercekimi": gravity,
		})
	_wake()


## Yükselen parıltı (iyileşme, yükseltme).
func rising(point: Vector2, count: int, color: Color, radius: float = 34.0) -> void:
	var amount := mini(count if not PerfManager.low_quality else int(count * 0.5), _budget_left())
	for i in amount:
		_sparks.append({
			"konum": point + Vector2(randf_range(-radius, radius), randf_range(-8.0, 8.0)),
			"hiz": Vector2(randf_range(-24.0, 24.0), randf_range(-150.0, -70.0)),
			"sure": randf_range(0.6, 1.1),
			"omur": 0.0,
			"renk": color,
			"boyut": randf_range(3.0, 6.0),
			"yercekimi": -0.08,   # hafifçe hızlanarak yükselir
		})
	_wake()


## Genişleyen halka. `thickness` kalınlığı, `duration` süresi.
func ring(point: Vector2, radius: float, color: Color, duration: float = 0.45,
		thickness: float = 5.0) -> void:
	_rings.append({
		"konum": point, "t": 0.0, "sure": duration,
		"yaricap": radius, "renk": color, "kalinlik": thickness,
	})
	_wake()


## Toz bulutu: kule inşası, ağır çarpma.
func dust(point: Vector2, radius: float, color: Color) -> void:
	ring(point, radius, Color(color.r, color.g, color.b, 0.55), 0.5, 8.0)
	sparks(point, 10, color, 150.0, PI, -PI * 0.5, 0.35)


## Ölen düşmanın görsel kalıntısı: büzülerek ve sönerek kaybolur.
func corpse(enemy_type: String, point: Vector2, radius: float, color: Color,
		facing: float) -> void:
	if PerfManager.low_quality:
		return
	_corpses.append({
		"tip": enemy_type, "konum": point, "t": 0.0,
		"yaricap": radius, "renk": color, "yon": facing,
	})
	_wake()


## Yukarı süzülen yazı (hasar, kazanılan altın, "KADİM!").
func floating_text(point: Vector2, text: String, color: Color, size: int = 30) -> void:
	if PerfManager.low_quality:
		return
	_texts.append({
		"konum": point, "metin": text, "t": 0.0, "sure": 0.9,
		"renk": color, "boyut": size,
	})
	_wake()


func clear_all() -> void:
	_sparks.clear()
	_rings.clear()
	_corpses.clear()
	_texts.clear()
	set_process(false)
	queue_redraw()


## --------------------------------------------------------------------------
## Güncelleme
## --------------------------------------------------------------------------

func _process(delta: float) -> void:
	var index := _sparks.size() - 1
	while index >= 0:
		var spark: Dictionary = _sparks[index]
		spark["omur"] += delta
		if spark["omur"] >= spark["sure"]:
			_sparks.remove_at(index)
		else:
			spark["hiz"].y += GRAVITY * float(spark["yercekimi"]) * delta
			spark["konum"] += spark["hiz"] * delta
		index -= 1

	index = _rings.size() - 1
	while index >= 0:
		_rings[index]["t"] += delta / float(_rings[index]["sure"])
		if _rings[index]["t"] >= 1.0:
			_rings.remove_at(index)
		index -= 1

	index = _corpses.size() - 1
	while index >= 0:
		_corpses[index]["t"] += delta * 2.6
		if _corpses[index]["t"] >= 1.0:
			_corpses.remove_at(index)
		index -= 1

	index = _texts.size() - 1
	while index >= 0:
		_texts[index]["t"] += delta / float(_texts[index]["sure"])
		if _texts[index]["t"] >= 1.0:
			_texts.remove_at(index)
		index -= 1

	if _sparks.is_empty() and _rings.is_empty() and _corpses.is_empty() and _texts.is_empty():
		set_process(false)
	queue_redraw()


## --------------------------------------------------------------------------
## Çizim
## --------------------------------------------------------------------------

func _draw() -> void:
	# Ölüm kalıntıları en altta
	for corpse_data in _corpses:
		var t: float = corpse_data["t"]
		var fade := 1.0 - t
		var squash := 1.0 + t * 0.5
		draw_set_transform(corpse_data["konum"], 0.0, Vector2(squash, maxf(1.0 - t * 0.9, 0.08)))
		var tint: Color = corpse_data["renk"]
		ProcArt.draw_enemy(self, str(corpse_data["tip"]), float(corpse_data["yaricap"]),
			Color(tint.r, tint.g, tint.b, fade * 0.9), 0.0, float(corpse_data["yon"]))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	for ring_data in _rings:
		var t: float = ring_data["t"]
		var color: Color = ring_data["renk"]
		var eased := 1.0 - pow(1.0 - t, 3.0)   # hızlı açılıp yavaşlar
		draw_arc(ring_data["konum"], float(ring_data["yaricap"]) * (0.15 + eased * 0.85),
			0.0, TAU, 30, Color(color.r, color.g, color.b, color.a * (1.0 - t)),
			float(ring_data["kalinlik"]) * (1.0 - t) + 1.0, true)

	for spark in _sparks:
		var life: float = 1.0 - float(spark["omur"]) / float(spark["sure"])
		var color: Color = spark["renk"]
		draw_circle(spark["konum"], float(spark["boyut"]) * life,
			Color(color.r, color.g, color.b, life))

	if _font != null:
		for text_data in _texts:
			var t: float = text_data["t"]
			var point: Vector2 = text_data["konum"] + Vector2(0, -52.0 * t)
			var color: Color = text_data["renk"]
			var alpha := 1.0 - maxf(0.0, (t - 0.55) / 0.45)
			# Belirirken hafifçe büyür: gözü yakalar.
			var pop := 1.0 + 0.25 * maxf(0.0, 1.0 - t * 6.0)
			var size := int(text_data["boyut"] * pop)
			var measured := _font.get_string_size(str(text_data["metin"]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, size)
			var origin := point - Vector2(measured.x * 0.5, 0.0)
			draw_string_outline(_font, origin, str(text_data["metin"]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, size, 12, Color(0.02, 0.01, 0.05, 0.85 * alpha))
			draw_string(_font, origin, str(text_data["metin"]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color.r, color.g, color.b, alpha))
