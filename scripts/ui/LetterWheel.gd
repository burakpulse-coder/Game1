class_name LetterWheel
extends Control

## Harf çarkı: rünik taş daire üzerinde parmak kaydırarak kelime kurma.
##
## Etkileşim (Words of Wonders tarzı):
##   1. Parmak bir harfe basınca seçim başlar.
##   2. Parmak diğer harflerin üzerinden geçtikçe harfler sırayla eklenir.
##   3. Bir önceki harfe geri dönülürse son harf geri alınır (geri izleme).
##   4. Parmak kalkınca kelime doğrulanmak üzere gönderilir.
##
## Harf Hırsızı bir harfi kilitlediğinde o taş soluklaşır ve seçilemez.

signal word_submitted(word: String)
signal selection_changed(word: String)
signal letter_picked(letter: String)

const STONE_RADIUS := 62.0
const TOUCH_SLACK := 1.25
const TRAIL_WIDTH := 12.0

## İlerleme rozetleri çarkın üst şeridinde durur. Taş dairesi bu şeridi boş
## bırakır; yoksa tepedeki taş rozetlerin üstüne biner.
const PROGRESS_TOP := 8.0
const PROGRESS_HEIGHT := 40.0
const PROGRESS_GAP := 12.0
const PROGRESS_MIN_FONT := 13

const STONE_FILL := Color("#cdbb96")
const STONE_EDGE := Color("#6c5a3c")
const STONE_LOCKED := Color("#5b5468")
const TRAIL_COLOR := Color("#f4d06a")
const TEXT_COLOR := Color("#2e2418")

var letters: PackedStringArray = []
var enabled := true

var _positions: PackedVector2Array = []
var _selection: Array[int] = []
var _locked := {}            ## harf indeksi -> kalan saniye
var _hint_index := -1
var _hint_timer := 0.0
var _drag_point := Vector2.ZERO
var _dragging := false
var _shake := 0.0
var _success := 0.0
var _center := Vector2.ZERO
var _radius := 200.0
var _stone_radius := STONE_RADIUS   ## dar ekranlarda STONE_RADIUS'tan küçülür
var _font: Font
var _flyers: Array = []      ## doğru kelimenin kuleye uçan harfleri
var _stone_shake: Array = []  ## taş başına sarsıntı fazı (geçersiz kelimede)
var _accept_wave := -1.0      ## kabul edilen kelimede taşları sırayla parlatır
var _progress := {}           ## {harf_sayisi: {"bulunan": n, "toplam": m}}
var _sparkle := 0.0           ## iz boyunca akan parıltının konumu


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font
	resized.connect(_layout)
	set_process(true)


func set_letters(values: Array) -> void:
	letters = PackedStringArray()
	for value in values:
		letters.append(TurkishText.to_upper(str(value)))
	_selection.clear()
	_locked.clear()
	_stone_shake.resize(letters.size())
	_stone_shake.fill(0.0)
	_layout()


func _layout() -> void:
	# Üstteki ilerleme şeridi taşlara ayrılmış alanın dışında kalır.
	var reserved := 0.0
	if not _progress.is_empty():
		reserved = PROGRESS_TOP + PROGRESS_HEIGHT + PROGRESS_GAP
	var usable := maxf(size.y - reserved, STONE_RADIUS * 2.0)
	_center = Vector2(size.x * 0.5, reserved + usable * 0.5)
	# Taşlar (yarıçapı STONE_RADIUS) hiçbir kenardan taşmamalı; çember yarıçapı
	# bu yüzden en dar kenara göre sınırlanır.
	var margin := STONE_RADIUS * 1.18
	_radius = minf(size.x * 0.5 - margin, usable * 0.5 - margin)
	_radius = maxf(_radius, STONE_RADIUS * 0.6)
	_positions = PackedVector2Array()
	var count := letters.size()
	for i in count:
		# -PI/2: ilk harf tepede başlasın.
		var angle := -PI * 0.5 + TAU * i / maxf(count, 1)
		_positions.append(_center + Vector2(cos(angle), sin(angle)) * _radius)

	# Taşlar birbirine de binmemeli. Basık ekranlarda 8 harflik çarkın komşu
	# taşları arasındaki kiriş taş çapından kısa kalıyor; o zaman taşı küçültürüz.
	_stone_radius = STONE_RADIUS
	if count >= 2:
		var chord := 2.0 * _radius * sin(PI / float(count))
		_stone_radius = clampf(chord * 0.46, 26.0, STONE_RADIUS)
	queue_redraw()


## --------------------------------------------------------------------------
## Dış denetim
## --------------------------------------------------------------------------

func current_word() -> String:
	var word := ""
	for index in _selection:
		word += letters[index]
	return word


func lock_letter(index: int, duration: float) -> void:
	if index < 0 or index >= letters.size():
		return
	_locked[index] = maxf(float(_locked.get(index, 0.0)), duration)
	_selection.erase(index)
	queue_redraw()


func unlock_letter(index: int) -> void:
	_locked.erase(index)
	queue_redraw()


func locked_indices() -> Array:
	return _locked.keys()


## Kilitlenebilecek rastgele bir harf seçer (zaten kilitli olanları atlar).
func pick_lockable_index() -> int:
	var free: Array = []
	for i in letters.size():
		if not _locked.has(i):
			free.append(i)
	if free.is_empty():
		return -1
	return free[randi() % free.size()]


func index_of_letter(letter: String) -> int:
	var upper := TurkishText.to_upper(letter)
	for i in letters.size():
		if letters[i] == upper and not _locked.has(i):
			return i
	return -1


## Çarkta kaç harfli kaç kelime var, kaçı bulundu? Oyuncunun "burada ne
## arayacağım" sorusuna cevap verir — kelime bulmak oyunun asıl zorluğu.
func set_word_progress(progress: Dictionary) -> void:
	var was_empty := _progress.is_empty()
	_progress = progress
	# Şerit ilk kez dolduğunda taş dairesinin ona yer açması gerekir.
	if was_empty != _progress.is_empty():
		_layout()
	queue_redraw()


## İpucu: kelimenin ilk harfini birkaç saniye vurgular.
func flash_hint(word: String) -> void:
	if word.is_empty():
		return
	_hint_index = index_of_letter(word[0])
	_hint_timer = 3.0
	queue_redraw()


func shuffle() -> void:
	var order := range(letters.size())
	order.shuffle()
	var shuffled := PackedStringArray()
	var remap := {}
	for new_index in order.size():
		remap[order[new_index]] = new_index
		shuffled.append(letters[order[new_index]])
	var relocked := {}
	for old_index in _locked:
		relocked[remap[old_index]] = _locked[old_index]
	letters = shuffled
	_locked = relocked
	_selection.clear()
	_layout()
	AudioManager.play_sfx("harf_sec")


func reject() -> void:
	_shake = 1.0
	# Taşlar tek tek, hafif gecikmeli sarsılır: tek parça titremeden daha canlı.
	for i in _stone_shake.size():
		_stone_shake[i] = 1.0 + i * 0.12
	_selection.clear()
	selection_changed.emit("")
	queue_redraw()


## Kabul edilen kelimenin harflerini hedefe (kuleye) uçurur.
func accept(target: Vector2, color: Color) -> void:
	_success = 1.0
	_accept_wave = 0.0
	for index in _selection:
		_flyers.append({
			"harf": letters[index],
			"from": _positions[index],
			"to": target,
			"t": 0.0,
			"renk": color,
		})
	_selection.clear()
	selection_changed.emit("")
	queue_redraw()


## --------------------------------------------------------------------------
## Girdi
## --------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_drag(touch.position)
		else:
			_end_drag()
		accept_event()
	elif event is InputEventScreenDrag:
		_update_drag((event as InputEventScreenDrag).position)
		accept_event()
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT:
			if click.pressed:
				_begin_drag(click.position)
			else:
				_end_drag()
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_update_drag((event as InputEventMouseMotion).position)
		accept_event()


func _begin_drag(point: Vector2) -> void:
	_dragging = true
	_drag_point = point
	_selection.clear()
	_try_add(point)
	queue_redraw()


func _update_drag(point: Vector2) -> void:
	if not _dragging:
		return
	_drag_point = point
	_try_add(point)
	queue_redraw()


func _end_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	var word := current_word()
	if word.is_empty():
		queue_redraw()
		return
	word_submitted.emit(TurkishText.to_lower(word))
	queue_redraw()


func _try_add(point: Vector2) -> void:
	var index := _letter_at(point)
	if index < 0 or _locked.has(index):
		return
	# Geri izleme: bir önceki harfe dönüldüyse son harfi geri al.
	if _selection.size() >= 2 and _selection[_selection.size() - 2] == index:
		_selection.pop_back()
		selection_changed.emit(current_word())
		AudioManager.play_sfx("harf_sec", 0.85)
		return
	if _selection.has(index):
		return
	_selection.append(index)
	_hint_index = -1
	selection_changed.emit(current_word())
	letter_picked.emit(letters[index])
	AudioManager.play_sfx("harf_sec", 1.0 + _selection.size() * 0.04)


func _letter_at(point: Vector2) -> int:
	# Dokunma alanı taş küçülse de parmak boyunun altına inmesin.
	var reach := maxf(_stone_radius * TOUCH_SLACK, 44.0)
	for i in _positions.size():
		if point.distance_to(_positions[i]) <= reach:
			return i
	return -1


## --------------------------------------------------------------------------
## Güncelleme ve çizim
## --------------------------------------------------------------------------

func _process(delta: float) -> void:
	var dirty := false

	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 3.5)
		dirty = true
	if _success > 0.0:
		_success = maxf(0.0, _success - delta * 1.8)
		dirty = true
	if _accept_wave >= 0.0:
		_accept_wave += delta * 3.2
		if _accept_wave > 1.0 + letters.size() * 0.1:
			_accept_wave = -1.0
		dirty = true
	for i in _stone_shake.size():
		if float(_stone_shake[i]) > 0.0:
			_stone_shake[i] = maxf(0.0, float(_stone_shake[i]) - delta * 3.0)
			dirty = true
	if _dragging or not _selection.is_empty():
		_sparkle = fmod(_sparkle + delta * 1.6, 1.0)
		dirty = true

	if _hint_timer > 0.0:
		_hint_timer -= delta
		if _hint_timer <= 0.0:
			_hint_index = -1
		dirty = true

	var expired: Array = []
	for index in _locked:
		_locked[index] = float(_locked[index]) - delta
		if float(_locked[index]) <= 0.0:
			expired.append(index)
		dirty = true
	for index in expired:
		_locked.erase(index)

	if not _flyers.is_empty():
		var i := _flyers.size() - 1
		while i >= 0:
			_flyers[i]["t"] += delta * 1.8
			if _flyers[i]["t"] >= 1.0:
				_flyers.remove_at(i)
			i -= 1
		dirty = true

	if dirty:
		queue_redraw()


func _draw() -> void:
	if _positions.is_empty():
		return

	var shake_offset := Vector2.ZERO
	if _shake > 0.0:
		shake_offset = Vector2(sin(_shake * 42.0) * 10.0 * _shake, 0)

	# Rünik zemin dairesi
	draw_circle(_center + shake_offset, _radius + _stone_radius * 0.95, Color(0, 0, 0, 0.22))
	draw_arc(_center + shake_offset, _radius + _stone_radius * 0.8, 0.0, TAU, 64,
		Color(0.85, 0.75, 0.5, 0.22), 3.0, true)

	# Seçim izi
	if _selection.size() >= 1:
		var trail := PackedVector2Array()
		for index in _selection:
			trail.append(_positions[index] + shake_offset)
		if _dragging:
			trail.append(_drag_point)
		var color := TRAIL_COLOR
		if _shake > 0.0:
			color = Color("#d1544a")
		if trail.size() >= 2:
			# Üç kat: dışta geniş ve soluk parlama, ortada gövde, içte parlak çekirdek.
			draw_polyline(trail, Color(color.r, color.g, color.b, 0.18), TRAIL_WIDTH * 2.2, true)
			draw_polyline(trail, Color(color.r, color.g, color.b, 0.55), TRAIL_WIDTH, true)
			draw_polyline(trail, Color(1, 1, 1, 0.35), TRAIL_WIDTH * 0.35, true)
			# İz boyunca akan parıltı
			var total := 0.0
			for i in trail.size() - 1:
				total += trail[i].distance_to(trail[i + 1])
			var travelled := _sparkle * total
			for i in trail.size() - 1:
				var segment := trail[i].distance_to(trail[i + 1])
				if travelled <= segment:
					var spot: Vector2 = trail[i].lerp(trail[i + 1], travelled / maxf(segment, 0.01))
					draw_circle(spot, 9.0, Color(1, 1, 1, 0.5))
					break
				travelled -= segment

	# Taşlar
	for i in _positions.size():
		_draw_stone(i, _positions[i] + shake_offset)

	# Harf sayısına göre kelime ilerlemesi: "burada 4 harfli 6 kelime var,
	# 2'sini buldun". Oyuncunun neyi arayacağını bilmesi en büyük yardım.
	_draw_progress()

	# Uçan harfler
	for flyer in _flyers:
		var t: float = flyer["t"]
		var eased := t * t * (3.0 - 2.0 * t)
		var point: Vector2 = (flyer["from"] as Vector2).lerp(flyer["to"], eased)
		# Hafif yay çizsin
		point.y -= sin(t * PI) * 90.0
		var alpha := 1.0 - t
		var color: Color = flyer["renk"]
		ProcArt.filled_circle(self, point, 26.0 * (1.0 - t * 0.4),
			Color(color.r, color.g, color.b, alpha * 0.85), false)
		_draw_glyph(str(flyer["harf"]), point, 34, Color(1, 1, 1, alpha))


## Çarkın üstünde, her kelime uzunluğu için bulunan/toplam göstergesi.
##
## Rozet genişliği yazıya göre ölçülür ve satır ekrana sığmazsa önce punto,
## sonra etiket biçimi küçülür. Sabit genişlikte yazı rozetin dışına taşıyordu.
func _draw_progress() -> void:
	if _progress.is_empty() or _font == null:
		return
	var lengths := _progress.keys()
	lengths.sort()

	var labels := _progress_labels(lengths, true)
	var available := size.x - 24.0
	var font_size := 20
	var widths := _pill_widths(labels, font_size)
	while _row_width(widths) > available and font_size > PROGRESS_MIN_FONT:
		font_size -= 1
		widths = _pill_widths(labels, font_size)
	if _row_width(widths) > available:
		labels = _progress_labels(lengths, false)
		widths = _pill_widths(labels, font_size)

	var x := (size.x - _row_width(widths)) * 0.5
	for i in labels.size():
		var entry: Dictionary = _progress[lengths[i]]
		var found := int(entry.get("bulunan", 0))
		var total := int(entry.get("toplam", 0))
		var done := found >= total and total > 0
		var rect := Rect2(x, PROGRESS_TOP, widths[i], PROGRESS_HEIGHT)
		var fill := Color(0.96, 0.82, 0.42, 0.85) if done else Color(0.16, 0.14, 0.22, 0.75)
		var ink := Color("#2e2418") if done else Color("#d8d0e6")
		ProcArt.rounded_rect(self, rect, 12.0, fill, false)
		_draw_glyph(labels[i], rect.get_center() + Vector2(0, -2), font_size, ink)
		x += widths[i] + PROGRESS_GAP


func _progress_labels(lengths: Array, verbose: bool) -> PackedStringArray:
	var labels := PackedStringArray()
	for key in lengths:
		var entry: Dictionary = _progress[key]
		var found := int(entry.get("bulunan", 0))
		var total := int(entry.get("toplam", 0))
		if verbose:
			labels.append("%d harf  %d/%d" % [int(key), found, total])
		else:
			labels.append("%d: %d/%d" % [int(key), found, total])
	return labels


func _pill_widths(labels: PackedStringArray, font_size: int) -> PackedFloat32Array:
	var widths := PackedFloat32Array()
	for label in labels:
		var measured := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		widths.append(maxf(measured.x + 22.0, 56.0))
	return widths


func _row_width(widths: PackedFloat32Array) -> float:
	var total := 0.0
	for w in widths:
		total += w
	return total + PROGRESS_GAP * maxf(widths.size() - 1, 0)


func _draw_stone(index: int, point: Vector2) -> void:
	var locked := _locked.has(index)
	var selected := _selection.has(index)
	var fill := STONE_LOCKED if locked else STONE_FILL
	var radius := _stone_radius

	if selected:
		fill = TRAIL_COLOR
		radius *= 1.06
	elif index == _hint_index:
		fill = fill.lerp(TRAIL_COLOR, 0.45 + 0.2 * sin(_hint_timer * 8.0))
	if _success > 0.0 and not locked:
		fill = fill.lerp(Color.WHITE, _success * 0.25)

	# Kabul dalgası: harfler seçildikleri sırayla parlar.
	if _accept_wave >= 0.0:
		var order := _selection.find(index)
		if order >= 0:
			var local := clampf(_accept_wave - order * 0.1, 0.0, 1.0)
			fill = fill.lerp(Color.WHITE, sin(local * PI) * 0.6)

	# Taş başına sarsıntı (geçersiz kelime)
	var own_shake := float(_stone_shake[index]) if index < _stone_shake.size() else 0.0
	if own_shake > 0.0:
		point += Vector2(sin(own_shake * 34.0) * 7.0 * minf(own_shake, 1.0), 0)

	# Gölge
	ProcArt.filled_circle(self, point + Vector2(0, 6), radius, Color(0, 0, 0, 0.30), false)

	# Seçili taşın etrafında parlama halkası
	if selected:
		draw_arc(point, radius * 1.16, 0.0, TAU, 28,
			Color(TRAIL_COLOR.r, TRAIL_COLOR.g, TRAIL_COLOR.b, 0.35), 7.0, true)

	# Taş gövdesi: degradeli, oyulmuş kenarlı
	ProcArt.shaded_circle(self, point, radius, fill)
	# Oyuk iç halka — rün taşı hissi
	draw_arc(point, radius * 0.80, 0.0, TAU, 28,
		Color(STONE_EDGE.r, STONE_EDGE.g, STONE_EDGE.b, 0.45 if not locked else 0.18), 3.0, true)
	draw_arc(point, radius * 0.74, 0.0, TAU, 28, Color(1, 1, 1, 0.16), 2.0, true)
	# Kenara oyulmuş dört çentik
	if not locked:
		for i in 4:
			var angle := PI * 0.25 + TAU * i / 4.0
			var from := point + Vector2(cos(angle), sin(angle)) * radius * 0.84
			var to := point + Vector2(cos(angle), sin(angle)) * radius * 0.96
			draw_line(from, to, Color(STONE_EDGE.r, STONE_EDGE.g, STONE_EDGE.b, 0.4), 3.0, true)

	var text_color := TEXT_COLOR if not locked else Color(0.75, 0.72, 0.82, 0.5)
	_draw_glyph(letters[index], point, 52, text_color)

	if locked:
		# Kilit simgesi
		var lock_point := point + Vector2(0, -radius * 0.05)
		ProcArt.rounded_rect(self, Rect2(lock_point.x - 15, lock_point.y - 2, 30, 24), 5.0,
			Color("#f4d06a"), false)
		draw_arc(lock_point + Vector2(0, -2), 11.0, PI, TAU, 12, Color("#f4d06a"), 4.0, true)
		var remaining := ceilf(float(_locked[index]))
		_draw_glyph("%d" % remaining, point + Vector2(0, radius * 0.62), 26, Color("#f4d06a"))


func _draw_glyph(text: String, center: Vector2, font_size: int, color: Color) -> void:
	if _font == null:
		return
	var measured := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var origin := center - Vector2(measured.x * 0.5, -measured.y * 0.32)
	draw_string_outline(_font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6,
		Color(0, 0, 0, 0.45))
	draw_string(_font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
