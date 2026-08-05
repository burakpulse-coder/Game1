class_name Scenery
extends Node2D

const SpriteBank := preload("res://scripts/core/SpriteBank.gd")

## Savaş alanının manzara katmanı.
##
## Önceden savaş alanı düz tek renk bir dikdörtgendi ve dört bölge birbirinin
## aynı görünüyordu. Bu katman derinliği katmanlarla kurar:
##
##   1. gökyüzü degradesi        (en uzak)
##   2. uzak tepe/ağaç siluetleri
##   3. sis şeridi               (uzaklık hissi)
##   4. zemin degradesi + renk lekeleri
##   5. süsler: ağaç, kaya, mantar, buz…  (yola ve yuvalara değmeyecek şekilde)
##   6. vinyet                   (kenarları koyultup ortayı öne çıkarır)
##
## Hepsi yordamsal çizim; ikili varlık yok. Yerleşim tohumlu rastgelelikle
## belirlenir: aynı seviye her açılışta aynı görünür.

const PROP_CLEARANCE := 26.0      ## süsler yoldan bu kadar uzak dursun
const SLOT_CLEARANCE := 62.0      ## kule yuvalarının üstünü kapatmasın
const HORIZON_RATIO := 0.17       ## gökyüzü şeridinin savaş alanına oranı

var region_theme := {}

var _rect := Rect2()
var _props: Array = []            ## [{tip, konum, olcek, sallanma}]
var _patches: Array = []          ## zemin renk lekeleri
var _hills: PackedVector2Array = []
var _sway := 0.0
var _motes: Array = []            ## ortam parçacıkları (polen, kar, köz…)
var _keep_clear: Array = []       ## [{konum, yaricap}] süs konulmayacak alanlar
var _prop_layer: Node2D = null    ## süsler yolun ÜSTÜNDE çizilir


func _ready() -> void:
	# Süs katmanı yol katmanının (z=1) üstünde olmalı.
	_prop_layer = _PropLayer.new()
	_prop_layer.scenery = self
	_prop_layer.z_index = PROP_LAYER_Z
	add_child(_prop_layer)
	z_index = 0


## `tracks` ve `slot_positions` verilir ki süsler oynanışın üstüne binmesin.
func setup(level_region_theme: Dictionary, rect: Rect2, tracks: Array, slot_positions: Array,
		seed_value: int, keep_clear: Array = []) -> void:
	region_theme = level_region_theme
	_keep_clear = keep_clear
	_rect = rect
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_build_hills(rng)
	_build_patches(rng)
	_build_props(rng, tracks, slot_positions)
	_build_motes(rng)
	if _prop_layer != null:
		_prop_layer.queue_redraw()
	queue_redraw()


func _process(delta: float) -> void:
	# Yapraklar salınır, ortam parçacıkları süzülür. Tüm manzara tek düğüm
	# olduğu için bu kare başına tek bir _draw() demek; düşük cihazlarda kapalı.
	if PerfManager.low_quality:
		return
	_sway += delta * 0.7
	for mote in _motes:
		mote["konum"] += Vector2(
			sin(_sway * float(mote["salinim"]) + float(mote["faz"])) * 14.0 * delta,
			float(mote["dusus"]) * delta)
		# Alanı terk eden parçacık karşı kenardan geri girer.
		if mote["konum"].y > _rect.end.y:
			mote["konum"].y = _rect.position.y
		elif mote["konum"].y < _rect.position.y:
			mote["konum"].y = _rect.end.y
	queue_redraw()


## Bölgeye göre ortam parçacığı: vadide polen, ormanda ateşböceği yukarı,
## buzda kar aşağı, ejder kalesinde köz yukarı.
func _build_motes(rng: RandomNumberGenerator) -> void:
	_motes.clear()
	var rises: bool = str(region_theme.get("susler", ["agac"])[0]) in ["cam", "lav"]
	for i in 26:
		_motes.append({
			"konum": Vector2(
				rng.randf_range(_rect.position.x, _rect.end.x),
				rng.randf_range(_rect.position.y, _rect.end.y)),
			"dusus": rng.randf_range(-34.0, -14.0) if rises else rng.randf_range(12.0, 34.0),
			"salinim": rng.randf_range(0.6, 1.8),
			"faz": rng.randf() * TAU,
			"boyut": rng.randf_range(1.8, 4.2),
		})


func _color(key: String, fallback: String) -> Color:
	return Color(region_theme.get(key, fallback))


## --------------------------------------------------------------------------
## Yerleşim
## --------------------------------------------------------------------------

func _build_hills(rng: RandomNumberGenerator) -> void:
	# Ufuk çizgisinde yumuşak tepe silueti.
	var horizon := _rect.position.y + _rect.size.y * HORIZON_RATIO
	_hills = PackedVector2Array()
	_hills.append(Vector2(_rect.position.x, horizon + 40.0))
	var steps := 9
	for i in steps + 1:
		var x := lerpf(_rect.position.x, _rect.end.x, i / float(steps))
		var y := horizon - rng.randf_range(6.0, 58.0)
		_hills.append(Vector2(x, y))
	_hills.append(Vector2(_rect.end.x, horizon + 40.0))


func _build_patches(rng: RandomNumberGenerator) -> void:
	_patches.clear()
	var horizon := _rect.position.y + _rect.size.y * HORIZON_RATIO
	for i in 14:
		_patches.append({
			"konum": Vector2(
				rng.randf_range(_rect.position.x, _rect.end.x),
				rng.randf_range(horizon, _rect.end.y)),
			"boyut": Vector2(rng.randf_range(70.0, 190.0), rng.randf_range(24.0, 60.0)),
		})


func _build_props(rng: RandomNumberGenerator, tracks: Array, slot_positions: Array) -> void:
	_props.clear()
	var kinds: Array = region_theme.get("susler", ["agac", "cali", "kaya"])
	var horizon := _rect.position.y + _rect.size.y * HORIZON_RATIO

	# Sarsıntılı ızgara: dağılım düzenli ama mekanik görünmesin.
	var cols := 7
	var rows := 8
	for row in rows:
		for col in cols:
			if rng.randf() > 0.55:
				continue
			var point := Vector2(
				_rect.position.x + _rect.size.x * (col + rng.randf_range(0.15, 0.85)) / cols,
				horizon + (_rect.end.y - horizon) * (row + rng.randf_range(0.1, 0.9)) / rows)
			if not _is_free(point, tracks, slot_positions):
				continue
			# Uzaktakiler küçük çizilir — basit bir derinlik ipucu.
			var depth := clampf((point.y - horizon) / maxf(_rect.end.y - horizon, 1.0), 0.0, 1.0)
			_props.append({
				"tip": kinds[rng.randi() % kinds.size()],
				"konum": point,
				"olcek": lerpf(0.55, 1.15, depth) * rng.randf_range(0.85, 1.15),
				"faz": rng.randf() * TAU,
			})
	# Yakındakiler sonra çizilsin ki öndekiler arkadakileri örtsün.
	_props.sort_custom(func(a, b): return a["konum"].y < b["konum"].y)


func _is_free(point: Vector2, tracks: Array, slot_positions: Array) -> bool:
	for track in tracks:
		if (track as PathTrack).distance_to_path(point) < PathTrack.PATH_WIDTH * 0.5 + PROP_CLEARANCE:
			return false
	for slot_point in slot_positions:
		if point.distance_to(slot_point) < SLOT_CLEARANCE:
			return false
	for area in _keep_clear:
		if point.distance_to(area["konum"]) < float(area["yaricap"]):
			return false
	return true


## --------------------------------------------------------------------------
## Çizim
## --------------------------------------------------------------------------

## Süs katmanı manzaranın çocuğu ama z_index'i yol katmanının üstünde.
## Aksi hâlde tabanı yolun altında kalan bir ağacın tepesi yol tarafından
## kesiliyordu — yol manzaradan sonra çiziliyor.
class _PropLayer extends Node2D:
	var scenery: Node = null

	func _draw() -> void:
		if scenery != null:
			scenery.draw_props(self)


## Sprite'ı olan süsleri üst katmana çizer (süs katmanı çağırır).
## Sprite'ı olmayanlar burada atlanır: yordamsal çizimler doğrudan `self`e
## komut veriyor ve başka bir düğümün `_draw`undan çağrılamaz.
func draw_props(canvas: CanvasItem) -> void:
	for prop in _props:
		var kind := str(prop["tip"])
		if SpriteBank.prop(kind) == null:
			continue
		_draw_prop(canvas, kind, prop["konum"], float(prop["olcek"]), float(prop["faz"]))


func _draw() -> void:
	if _rect.size.x <= 0.0:
		return
	var horizon := _rect.position.y + _rect.size.y * HORIZON_RATIO

	# Elle çizilmiş bölge zemini varsa gökyüzü/tepe/zemin/leke katmanlarının
	# yerini alır; süsler, parçacıklar ve vinyet üstüne gelmeye devam eder.
	if _draw_region_art():
		_draw_overlay()
		return

	# 1. Gökyüzü
	_gradient_quad(Rect2(_rect.position, Vector2(_rect.size.x, horizon - _rect.position.y)),
		_color("gok_ust", "#6f9fc4"), _color("gok_alt", "#a8c98a"))

	# 2. Uzak tepeler
	if _hills.size() > 2:
		ProcArt.filled_polygon(self, _hills, _color("uzak_tepe", "#7fa86a"), false)
		var far := _hills.duplicate()
		for i in far.size():
			far[i] = far[i] + Vector2(0, 26.0)
		ProcArt.filled_polygon(self, far, _color("ufuk", "#3f6b3a"), false)

	# 3. Zemin
	_gradient_quad(Rect2(_rect.position.x, horizon, _rect.size.x, _rect.end.y - horizon),
		_color("zemin", "#5f9b45"), _color("zemin_alt", "#3d6b2e"))

	# 4. Zemin lekeleri — düz rengi kırar
	var patch_color := _color("leke", "#6fae4a")
	patch_color.a = 0.35
	for patch in _patches:
		ProcArt.ellipse(self, patch["konum"], patch["boyut"], patch_color, false)

	# 5. Sis şeridi (ufkun hemen altı)
	var fog := _color("gok_alt", "#a8c98a")
	fog.a = 0.30
	_gradient_quad(Rect2(_rect.position.x, horizon - 6.0, _rect.size.x, 54.0),
		fog, Color(fog.r, fog.g, fog.b, 0.0))

	_draw_overlay()


## Zeminin üstündeki ortak katmanlar: parçacıklar ve vinyet. Süsler ayrı bir
## katmanda, yolun üstünde çizilir (bkz. _PropLayer).
func _draw_overlay() -> void:
	# Sprite'ı olmayan süsler yordamsal çizilir ve manzara katmanında kalır.
	for prop in _props:
		var kind := str(prop["tip"])
		if SpriteBank.prop(kind) == null:
			_draw_prop(self, kind, prop["konum"], float(prop["olcek"]), float(prop["faz"]))

	if not PerfManager.low_quality:
		var mote_color := _color("zerre", "#f6f0a0")
		for mote in _motes:
			var alpha := 0.35 + 0.35 * sin(_sway * 1.6 + float(mote["faz"]))
			draw_circle(mote["konum"], float(mote["boyut"]),
				Color(mote_color.r, mote_color.g, mote_color.b, alpha))

	_vignette()


## Bölge zeminini alanı TAM dolduracak şekilde çizer; dosya yoksa false döner.
##
## Ölçek yerine kaynak kırpma kullanılır: görsel yatay, savaş alanı cihaza göre
## dikey. Esnetmek buz dağlarını ve bulutları eziyordu. Kırpma yatayda
## ortalanır, dikeyde üstten başlar — ufuk her telefonda görünsün.
func _draw_region_art() -> bool:
	var region_id := str(region_theme.get("id", ""))
	if region_id.is_empty():
		return false
	var texture: Texture2D = SpriteBank.region(region_id)
	if texture == null:
		return false

	var source_size := texture.get_size()
	var target_ratio := _rect.size.x / maxf(_rect.size.y, 1.0)
	var crop_width := source_size.x
	var crop_height := crop_width / maxf(target_ratio, 0.001)
	if crop_height > source_size.y:
		crop_height = source_size.y
		crop_width = crop_height * target_ratio
	var source := Rect2((source_size.x - crop_width) * 0.5, 0.0, crop_width, crop_height)
	draw_texture_rect_region(texture, _rect, source)
	return true


## Dikey degradeli dörtgen (köşe renkleriyle, ek doku gerekmez).
func _gradient_quad(rect: Rect2, top: Color, bottom: Color) -> void:
	var points := PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	draw_polygon(points, PackedColorArray([top, top, bottom, bottom]))


func _vignette() -> void:
	var dark := Color(0, 0, 0, 0.30)
	var clear := Color(0, 0, 0, 0)
	var band := _rect.size.y * 0.16
	# üst
	draw_polygon(PackedVector2Array([
		_rect.position, Vector2(_rect.end.x, _rect.position.y),
		Vector2(_rect.end.x, _rect.position.y + band), Vector2(_rect.position.x, _rect.position.y + band),
	]), PackedColorArray([dark, dark, clear, clear]))
	# alt
	draw_polygon(PackedVector2Array([
		Vector2(_rect.position.x, _rect.end.y - band), Vector2(_rect.end.x, _rect.end.y - band),
		Vector2(_rect.end.x, _rect.end.y), Vector2(_rect.position.x, _rect.end.y),
	]), PackedColorArray([clear, clear, dark, dark]))


## --------------------------------------------------------------------------
## Süsler
## --------------------------------------------------------------------------

## Süs yüksekliği yordamsal ağaçla aynı ölçüde (74 piksel); böylece sprite'a
## geçince manzaranın yoğunluğu değişmiyor.
const PROP_HEIGHT := 74.0
## Süs katmanının z değeri: yol (1) ve yuvaların (2) üstünde, düşmanların (5)
## altında. Manzaranın çocuğu olduğu için değer manzaranınkine eklenir.
const PROP_LAYER_Z := 3

## Her süs kendi doğal boyunda olmalı. Sprite sayfasında hepsi aynı yükseklikte
## çizildiği için hepsini aynı boya sığdırınca kaya ağaçtan, mantar çalıdan
## büyük görünüyordu.
const PROP_SCALE := {
	"agac": 1.00, "cam": 1.15, "cali": 0.55, "kaya": 0.62,
	"mantar": 0.48, "buz": 0.80, "kutuk": 0.50, "lav": 0.52,
}


func _draw_prop(canvas: CanvasItem, kind: String, point: Vector2, scale: float,
		phase: float) -> void:
	var sway := 0.0 if PerfManager.low_quality else sin(_sway + phase) * 3.0 * scale

	var sprite: Texture2D = SpriteBank.prop(kind)
	if sprite != null:
		var height := PROP_HEIGHT * scale * float(PROP_SCALE.get(kind, 1.0))
		ProcArt.ellipse(canvas, point, Vector2(height * 0.30, height * 0.09),
			Color(0, 0, 0, 0.20), false)
		# Sallanma tepede olmalı, tabanda değil: taban zemine sabit durur.
		SpriteBank.draw_fitted(canvas, sprite, point + Vector2(sway * 0.35, 0.0),
			Vector2(height * 1.7, height))
		return

	match kind:
		"agac":
			_draw_tree(point, scale, sway)
		"cam":
			_draw_conifer(point, scale, sway)
		"cali":
			_draw_bush(point, scale, sway)
		"kaya":
			_draw_rock(point, scale)
		"mantar":
			_draw_mushroom(point, scale)
		"buz":
			_draw_ice(point, scale)
		"kutuk":
			_draw_stump(point, scale)
		"lav":
			_draw_lava(point, scale, phase)


func _shadow(point: Vector2, radius: float) -> void:
	ProcArt.ellipse(self, point, Vector2(radius, radius * 0.3), Color(0, 0, 0, 0.20), false)


func _draw_tree(point: Vector2, scale: float, sway: float) -> void:
	var h := 74.0 * scale
	_shadow(point, h * 0.34)
	draw_line(point, point + Vector2(sway * 0.4, -h * 0.45), _color("govde", "#5a4029"), 7.0 * scale, true)
	var crown := point + Vector2(sway, -h * 0.72)
	ProcArt.shaded_circle(self, crown, h * 0.36, _color("yaprak", "#3e7a34"))
	ProcArt.shaded_circle(self, crown + Vector2(-h * 0.22, h * 0.16), h * 0.24,
		ProcArt.shade(_color("yaprak", "#3e7a34"), -0.10))


func _draw_conifer(point: Vector2, scale: float, sway: float) -> void:
	var h := 96.0 * scale
	_shadow(point, h * 0.24)
	draw_line(point, point + Vector2(0, -h * 0.28), _color("govde", "#3a2b1e"), 6.0 * scale, true)
	var leaf := _color("yaprak", "#25452c")
	for i in 3:
		var base_y := -h * (0.22 + i * 0.24)
		var width := h * (0.34 - i * 0.07)
		var top := -h * (0.5 + i * 0.24)
		ProcArt.shaded_polygon(self, PackedVector2Array([
			point + Vector2(-width, base_y),
			point + Vector2(sway * (i + 1) * 0.3, top),
			point + Vector2(width, base_y),
		]), ProcArt.shade(leaf, i * 0.06), 0.22, 0.26)


func _draw_bush(point: Vector2, scale: float, sway: float) -> void:
	var r := 26.0 * scale
	_shadow(point, r * 1.1)
	var leaf := _color("yaprak", "#3e7a34")
	ProcArt.shaded_circle(self, point + Vector2(-r * 0.55, -r * 0.3), r * 0.7, ProcArt.shade(leaf, -0.08))
	ProcArt.shaded_circle(self, point + Vector2(r * 0.55, -r * 0.25), r * 0.65, ProcArt.shade(leaf, -0.04))
	ProcArt.shaded_circle(self, point + Vector2(sway * 0.3, -r * 0.7), r * 0.85, leaf)


func _draw_rock(point: Vector2, scale: float) -> void:
	var r := 30.0 * scale
	_shadow(point, r * 1.05)
	ProcArt.shaded_polygon(self, PackedVector2Array([
		point + Vector2(-r, 0), point + Vector2(-r * 0.62, -r * 0.78),
		point + Vector2(r * 0.1, -r * 0.95), point + Vector2(r * 0.82, -r * 0.5),
		point + Vector2(r * 0.95, 0),
	]), _color("tas", "#8a8f7a"), 0.24, 0.30)


func _draw_mushroom(point: Vector2, scale: float) -> void:
	var h := 30.0 * scale
	_shadow(point, h * 0.6)
	draw_line(point, point + Vector2(0, -h * 0.55), Color("#d8cdb4"), 6.0 * scale, true)
	ProcArt.shaded_polygon(self, PackedVector2Array([
		point + Vector2(-h * 0.5, -h * 0.5), point + Vector2(-h * 0.3, -h * 0.9),
		point + Vector2(h * 0.3, -h * 0.9), point + Vector2(h * 0.5, -h * 0.5),
	]), Color("#b0453f"), 0.26, 0.24)
	ProcArt.filled_circle(self, point + Vector2(-h * 0.12, -h * 0.68), h * 0.08, Color("#f2e6cf"), false)
	ProcArt.filled_circle(self, point + Vector2(h * 0.18, -h * 0.6), h * 0.06, Color("#f2e6cf"), false)


func _draw_ice(point: Vector2, scale: float) -> void:
	var h := 60.0 * scale
	_shadow(point, h * 0.34)
	for i in 2:
		var offset := (i - 0.5) * h * 0.36
		var height := h * (0.9 if i == 0 else 0.6)
		ProcArt.shaded_polygon(self, PackedVector2Array([
			point + Vector2(offset - h * 0.2, 0),
			point + Vector2(offset, -height),
			point + Vector2(offset + h * 0.2, 0),
		]), Color("#a9dcf0"), 0.34, 0.22)


func _draw_stump(point: Vector2, scale: float) -> void:
	var r := 24.0 * scale
	_shadow(point, r * 1.0)
	ProcArt.shaded_polygon(self, PackedVector2Array([
		point + Vector2(-r * 0.7, 0), point + Vector2(-r * 0.6, -r * 0.8),
		point + Vector2(r * 0.6, -r * 0.8), point + Vector2(r * 0.7, 0),
	]), _color("govde", "#3a2b1e"), 0.20, 0.26)
	ProcArt.ellipse(self, point + Vector2(0, -r * 0.8), Vector2(r * 0.6, r * 0.22),
		ProcArt.shade(_color("govde", "#3a2b1e"), 0.22))


func _draw_lava(point: Vector2, scale: float, phase: float) -> void:
	var r := 34.0 * scale
	var pulse := 0.6 + 0.4 * sin(_sway * 2.0 + phase)
	var glow := Color("#ff7a2f")
	ProcArt.ellipse(self, point, Vector2(r, r * 0.34),
		Color(glow.r, glow.g, glow.b, 0.22 * pulse), false)
	ProcArt.shaded_polygon(self, PackedVector2Array([
		point + Vector2(-r * 0.8, 0), point + Vector2(-r * 0.2, -r * 0.22),
		point + Vector2(r * 0.5, -r * 0.1), point + Vector2(r * 0.8, r * 0.12),
		point + Vector2(0, r * 0.24),
	]), Color("#c8442a").lerp(glow, 0.35 * pulse), 0.30, 0.20, false)
