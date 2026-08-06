class_name UiKit
extends RefCounted

const SpriteBank := preload("res://scripts/core/SpriteBank.gd")

## Ortak arayüz bileşenleri ve renk paleti.
##
## Ekranlar kod içinde kurulur; bu sınıf tüm ekranların aynı tipografiyi,
## renkleri ve dokunma hedefi boyutlarını paylaşmasını sağlar.
## Dokunma hedefleri en az 96 px (1080 genişlikte ~10 mm) tutulur ki
## tek elle rahat oynansın.

const BG := Color("#141220")
const BG_PANEL := Color("#221d33")
const BG_PANEL_SOFT := Color("#2c2542")
const INK := Color("#f6f0e2")
const INK_SOFT := Color("#b9b0cc")
const GOLD := Color("#f4d06a")
const GEM := Color("#67d8f0")
const DANGER := Color("#d1544a")
const SUCCESS := Color("#5ec97a")
const OUTLINE := Color("#100d1a")

const PRESS_SINK := 8.0     ## basılıyken yazının indiği piksel
const PRESS_SCALE := 0.965  ## basılıyken düğmenin küçüldüğü oran
const TOUCH_MIN := 96.0
const RADIUS := 18.0

const FONT_TITLE := 66
const FONT_HEAD := 46
const FONT_BODY := 34
const FONT_SMALL := 27


## Panel çerçevesi. Düz koyu dikdörtgenler yerine hafif kabartmalı, ince altın
## çizgili bir çerçeve: ortaçağ hissi verir ve panelin sınırını belirginleştirir.
const FRAME_LINE := Color(0.83, 0.72, 0.45, 0.28)


static func panel_style(fill: Color = BG_PANEL, border: Color = Color(0, 0, 0, 0),
		radius: float = RADIUS) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(int(radius))
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	# Üstten gelen ışık: panelin üst kenarı açık, alt kenarı koyu.
	style.bg_color = fill
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	if border.a > 0.0:
		style.set_border_width_all(3)
		style.border_color = border
	else:
		# Görünmez kenarlık yerine ince altın hat: panel zeminden ayrışsın.
		style.set_border_width_all(2)
		style.border_color = FRAME_LINE
	return style


static func panel(fill: Color = BG_PANEL, border: Color = Color(0, 0, 0, 0)) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", panel_style(fill, border))
	return node


## Tek satırlık etiket. Satır kırma varsayılan olarak KAPALIDIR: autowrap açık
## bir Label yatay kaplarda en küçük genişliğini 0 bildirdiği için başlıklar
## harf harf alt alta dizilir. Çok satırlı metinler için paragraph() kullanılır.
static func label(text: String, size: int = FONT_BODY, color: Color = INK,
		align: int = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_outline_color", OUTLINE)
	node.add_theme_constant_override("outline_size", 6)
	node.horizontal_alignment = align
	# Dar göstergelerde tek kelimelik etiketler bölünmesin diye kırma kapatılabilir.
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	return node


static func title(text: String) -> Label:
	return label(text, FONT_TITLE, GOLD, HORIZONTAL_ALIGNMENT_CENTER)


## Çok satırlı, kendi kendine satır kıran metin bloğu.
static func paragraph(text: String, size: int = FONT_SMALL, color: Color = INK_SOFT,
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var node := label(text, size, color, align, true)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func button(text: String, accent: Color = GOLD, size: int = FONT_BODY) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(0, TOUCH_MIN)
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size", size)

	# Elle çizilmiş düğme zemini varsa dokuz dilim olarak esnetilir; yoksa
	# yordamsal kabartma kutuya düşülür.
	var skin := _button_skin(accent)
	if skin != null:
		# Dokuz dilimin sabit uçları kutuya sığmazsa Godot onları üst üste
		# bindirip kırpıyor ve yuvarlak uç düz bir çizgiyle kesiliyor. Düğme
		# en az uçlar kadar geniş olmalı; dar isteyen round_button kullanmalı.
		node.custom_minimum_size.x = maxf(node.custom_minimum_size.x,
			skin.texture_margin_left + skin.texture_margin_right)
		node.custom_minimum_size.y = maxf(node.custom_minimum_size.y,
			skin.texture_margin_top + skin.texture_margin_bottom)
		node.add_theme_stylebox_override("normal", skin)
		node.add_theme_stylebox_override("hover", _tinted(skin, Color(1.12, 1.12, 1.12)))
		node.add_theme_stylebox_override("pressed", _pressed_style(skin))
		node.add_theme_stylebox_override("focus", skin)
		var off := _button_texture_style("mor_pasif")
		node.add_theme_stylebox_override("disabled",
			off if off != null else _tinted(skin, Color(0.6, 0.6, 0.6)))
		_add_press_feel(node)
		return node

	var normal := panel_style(accent, Color(0, 0, 0, 0), RADIUS)
	normal.content_margin_left = 34
	normal.content_margin_right = 34
	# Kabartma: üst kenar açık, alt kenar koyu — düğme basılabilir görünür.
	normal.border_width_top = 3
	normal.border_width_bottom = 5
	normal.border_color = accent.lerp(Color.BLACK, 0.35)
	normal.shadow_size = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = accent.lerp(Color.WHITE, 0.14)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = accent.lerp(Color.BLACK, 0.22)
	# Basılıyken kabartma tersine döner ve düğme biraz aşağı iner.
	pressed.border_width_top = 5
	pressed.border_width_bottom = 3
	pressed.shadow_size = 2
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = accent.lerp(BG_PANEL, 0.7)

	node.add_theme_stylebox_override("normal", normal)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("pressed", pressed)
	node.add_theme_stylebox_override("disabled", disabled)
	node.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var ink := OUTLINE if accent.get_luminance() > 0.45 else INK
	node.add_theme_color_override("font_color", ink)
	node.add_theme_color_override("font_hover_color", ink)
	node.add_theme_color_override("font_pressed_color", ink)
	node.add_theme_color_override("font_disabled_color", Color(ink.r, ink.g, ink.b, 0.45))
	return node


## Düğme dokusunu vurgu rengine göre seçer: altın vurgu altın zemin, geri
## kalanı mor panel zemini.
static func _button_skin(accent: Color) -> StyleBoxTexture:
	return _button_texture_style("altin" if accent.is_equal_approx(GOLD) else "mor")


static func _button_texture_style(state: String) -> StyleBoxTexture:
	var texture := SpriteBank.button(state)
	if texture == null:
		return null
	var style := StyleBoxTexture.new()
	style.texture = texture
	# Yuvarlak uçlar sabit kalmalı, yalnızca orta esnemeli.
	style.texture_margin_left = texture.get_width() * 0.17
	style.texture_margin_right = texture.get_width() * 0.17
	style.texture_margin_top = texture.get_height() * 0.34
	style.texture_margin_bottom = texture.get_height() * 0.34
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	return style


## Basılı hâl: yazı aşağı kayar ve zemin koyulaşır — düğme yuvasına gömülmüş
## gibi durur. Yalnızca renk değiştirmek dokunuşu hissettirmiyordu.
static func _pressed_style(style: StyleBoxTexture) -> StyleBoxTexture:
	var down := _tinted(style, Color(0.82, 0.82, 0.86))
	down.content_margin_top = style.content_margin_top + PRESS_SINK
	down.content_margin_bottom = maxf(style.content_margin_bottom - PRESS_SINK, 4.0)
	return down


## Basarken hafif küçülme. Ölçek yerleşimi etkilemez, yalnızca çizimi;
## bu yüzden kutu düzeni bozulmadan dokunma geri bildirimi verir.
static func _add_press_feel(node: Button) -> void:
	node.resized.connect(func(): node.pivot_offset = node.size * 0.5)
	node.button_down.connect(func():
		node.pivot_offset = node.size * 0.5
		node.scale = Vector2(PRESS_SCALE, PRESS_SCALE))
	node.button_up.connect(func(): node.scale = Vector2.ONE)
	node.mouse_exited.connect(func(): node.scale = Vector2.ONE)


static func _tinted(style: StyleBoxTexture, color: Color) -> StyleBoxTexture:
	var copy := style.duplicate() as StyleBoxTexture
	copy.modulate_color = color
	return copy


## Düğmeye simge ekler; simge dosyası yoksa düğme yalnız metinle kalır.
## Duraklat gibi yalnız simgeli düğmelerde metin kaldırılır.
static func set_button_icon(node: Button, icon_name: String, keep_text := true) -> void:
	var texture := SpriteBank.icon(icon_name)
	if texture == null:
		return
	node.icon = texture
	node.expand_icon = true
	node.add_theme_constant_override("icon_max_width", 46)
	node.add_theme_constant_override("h_separation", 12)
	if not keep_text:
		node.text = ""


## Kare/dairesel simge düğmesi (duraklat gibi).
##
## Ölçülmüş hata: elle çizilen düğme dokusu 426x128 GENİŞ bir hap. Dokuz
## dilim payları sol ve sağ için 72'şer piksel, yani sabit uçlar toplam 144
## piksel yer istiyor. Duraklat düğmesi 91x88 idi; uçlar kutuya sığmayınca
## Godot onları üst üste bindirip kırpıyor ve yuvarlak uç düz bir çizgiyle
## kesiliyordu — ekranda "düğmeler üst üste binmiş" gibi görünüyordu.
##
## Geniş bir hap dokusu kare kutuya oturmaz; bu yüzden simge düğmeleri
## dokuyu hiç kullanmaz, aynı paletten dairesel bir kutu çizer.
static func round_button(text: String, diameter: float = TOUCH_MIN,
		accent: Color = INK) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(diameter, diameter)
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size", int(diameter * 0.42))
	node.add_theme_color_override("font_color", accent)
	node.add_theme_color_override("font_hover_color", INK)
	node.add_theme_color_override("font_pressed_color", INK)

	var radius := int(diameter * 0.5)
	var normal := StyleBoxFlat.new()
	# Renkler hap dokusundan örneklendi: uç (0,8,44), gövde (57,49,109).
	normal.bg_color = Color("#39316d")
	normal.set_corner_radius_all(radius)
	normal.border_width_top = 3
	normal.border_width_bottom = 5
	normal.border_width_left = 3
	normal.border_width_right = 3
	normal.border_color = Color("#0d1440")
	normal.shadow_color = Color(0, 0, 0, 0.45)
	normal.shadow_size = 8
	normal.shadow_offset = Vector2(0, 4)
	normal.content_margin_left = 0
	normal.content_margin_right = 0
	normal.content_margin_top = 0
	normal.content_margin_bottom = 0

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = normal.bg_color.lerp(Color.WHITE, 0.14)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = normal.bg_color.lerp(Color.BLACK, 0.22)
	pressed.border_width_top = 5
	pressed.border_width_bottom = 3
	pressed.shadow_size = 2
	pressed.content_margin_top = PRESS_SINK * 0.5

	node.add_theme_stylebox_override("normal", normal)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("pressed", pressed)
	node.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_add_press_feel(node)
	return node


static func ghost_button(text: String, accent: Color = INK_SOFT) -> Button:
	var node := button(text, BG_PANEL_SOFT)
	node.add_theme_color_override("font_color", accent)
	node.add_theme_color_override("font_hover_color", INK)
	node.add_theme_color_override("font_pressed_color", INK)
	return node


static func spacer(height: float = 0.0) -> Control:
	var node := Control.new()
	if height > 0.0:
		node.custom_minimum_size = Vector2(0, height)
	else:
		node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return node


static func vbox(separation: int = 18) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


static func hbox(separation: int = 18) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


static func margin(all: int = 40) -> MarginContainer:
	var node := MarginContainer.new()
	node.add_theme_constant_override("margin_left", all)
	node.add_theme_constant_override("margin_right", all)
	node.add_theme_constant_override("margin_top", all)
	node.add_theme_constant_override("margin_bottom", all)
	return node


static func progress_bar(color: Color, height: float = 26.0) -> ProgressBar:
	var node := ProgressBar.new()
	node.custom_minimum_size = Vector2(0, height)
	node.show_percentage = false
	node.max_value = 1.0
	node.step = 0.001

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.35)
	bg.set_corner_radius_all(int(height * 0.5))
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(int(height * 0.5))
	node.add_theme_stylebox_override("background", bg)
	node.add_theme_stylebox_override("fill", fill)
	return node


## Ekranların ortak arka planı: dikey degrade + hafif vinyet.
static func background(top: Color = Color("#241d38"), bottom: Color = BG) -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.set_color(0, top)
	gradient.set_color(1, bottom)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	var material := CanvasItemMaterial.new()
	rect.material = material
	# ColorRect yerine TextureRect gerektiği için degrade dokusu ayrı düğümde verilir.
	var texture_rect := TextureRect.new()
	texture_rect.texture = texture
	texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.add_child(texture_rect)
	rect.color = Color(0, 0, 0, 0)
	return rect


## Üstten aşağı sönen karartma. Manzara katmanı geldikten sonra HUD yazıları
## açık gökyüzünün üstünde okunmuyordu; bu şerit metni her bölgede okunur tutar.
static func scrim(height: float, strength: float = 0.5) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.04, 0.03, 0.07, strength))
	gradient.set_color(1, Color(0.04, 0.03, 0.07, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)

	var node := TextureRect.new()
	node.texture = texture
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.anchor_right = 1.0
	node.offset_bottom = height
	return node


## Üst bilgi çubuğu: geri düğmesi + başlık + altın/elmas göstergesi.
static func top_bar(title_text: String, on_back: Callable, show_currency: bool = true) -> Control:
	var bar := hbox(20)
	bar.custom_minimum_size = Vector2(0, TOUCH_MIN)

	if on_back.is_valid():
		# Kare geri düğmesi geniş hap dokusunu taşıyamaz; dairesel kutu.
		var back := round_button("‹", TOUCH_MIN)
		back.add_theme_font_size_override("font_size", FONT_HEAD)
		back.pressed.connect(on_back)
		bar.add_child(back)

	var heading := label(title_text, FONT_HEAD, INK)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(heading)

	if show_currency:
		bar.add_child(currency_chip("altin"))
		bar.add_child(currency_chip("elmas"))
	return bar


## Para göstergesi. EconomyManager sinyaline kendisi abone olur.
## Para simgesi: elle çizilmiş varsa doku, yoksa metin karakteri.
static func _currency_icon(kind: String) -> Control:
	var texture := SpriteBank.icon("elmas" if kind == "elmas" else "altin")
	if texture == null:
		return label("◆" if kind == "elmas" else "●", FONT_BODY,
			GEM if kind == "elmas" else GOLD)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(40, 40)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func currency_chip(kind: String) -> Control:
	var chip := panel(BG_PANEL_SOFT)
	var row := hbox(10)
	var icon: Control = _currency_icon(kind)
	var amount := label("0", FONT_BODY, INK)
	amount.name = "Tutar"
	row.add_child(icon)
	row.add_child(amount)
	chip.add_child(row)
	chip.set_meta("kind", kind)
	chip.set_script(preload("res://scripts/ui/CurrencyChip.gd"))
	return chip
