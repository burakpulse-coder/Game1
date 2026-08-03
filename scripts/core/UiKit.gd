class_name UiKit
extends RefCounted

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

const TOUCH_MIN := 96.0
const RADIUS := 18.0

const FONT_TITLE := 66
const FONT_HEAD := 46
const FONT_BODY := 34
const FONT_SMALL := 27


static func panel_style(fill: Color = BG_PANEL, border: Color = Color(0, 0, 0, 0),
		radius: float = RADIUS) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(int(radius))
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	if border.a > 0.0:
		style.set_border_width_all(3)
		style.border_color = border
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

	var normal := panel_style(accent, Color(0, 0, 0, 0), RADIUS)
	normal.content_margin_left = 34
	normal.content_margin_right = 34
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = accent.lerp(Color.WHITE, 0.14)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = accent.lerp(Color.BLACK, 0.22)
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


## Üst bilgi çubuğu: geri düğmesi + başlık + altın/elmas göstergesi.
static func top_bar(title_text: String, on_back: Callable, show_currency: bool = true) -> Control:
	var bar := hbox(20)
	bar.custom_minimum_size = Vector2(0, TOUCH_MIN)

	if on_back.is_valid():
		var back := ghost_button("‹")
		back.custom_minimum_size = Vector2(TOUCH_MIN, TOUCH_MIN)
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
static func currency_chip(kind: String) -> Control:
	var chip := panel(BG_PANEL_SOFT)
	var row := hbox(10)
	var icon := label("◆" if kind == "elmas" else "●", FONT_BODY,
		GEM if kind == "elmas" else GOLD)
	var amount := label("0", FONT_BODY, INK)
	amount.name = "Tutar"
	row.add_child(icon)
	row.add_child(amount)
	chip.add_child(row)
	chip.set_meta("kind", kind)
	chip.set_script(preload("res://scripts/ui/CurrencyChip.gd"))
	return chip
