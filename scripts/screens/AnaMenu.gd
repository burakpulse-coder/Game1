extends Control

const SpriteBank := preload("res://scripts/core/SpriteBank.gd")

## Ana menü.
##
## Yerleşim üç bloğa ayrılır: üstte para göstergeleri, ortada kale arması ve
## başlık, altta düğmeler. Aradaki boşluk eşit paylaştırılır — önceki sürümde
## tek büyük boşluk vardı ve ekranın ortası bomboş kalıyordu.
##
## Başlık ve ilerleme, manzaranın üstünde durdukları için kendi levhalarına
## oturur; düz yazı açık zeminlerde okunmuyordu.

const CREST_HEIGHT := 200.0
const PLAY_HEIGHT := 132.0
const SIDE_ICON := 40.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Menü de savaşla aynı görsel dili konuşsun: Yeşil Vadi manzarası.
	var backdrop := Backdrop.new()
	add_child(backdrop)
	backdrop.setup(GameConfig.REGION_THEMES["yesil_vadi"], 4242)
	backdrop.set_veil(0.58)
	AudioManager.play_music("menu")

	var margin := UiKit.margin(44)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var column := UiKit.vbox(18)
	margin.add_child(column)

	column.add_child(_currency_bar())
	column.add_child(UiKit.spacer())
	column.add_child(_hero())
	column.add_child(UiKit.spacer())
	column.add_child(_actions())
	column.add_child(_footer())


## Üst şerit: altın ve elmas sağa yaslı.
func _currency_bar() -> Control:
	var bar := UiKit.hbox(12)
	bar.add_child(UiKit.spacer())
	bar.add_child(UiKit.currency_chip("altin"))
	bar.add_child(UiKit.currency_chip("elmas"))
	return bar


## Orta blok: kale arması, başlık levhası ve yıldız ilerlemesi.
func _hero() -> Control:
	var hero := UiKit.vbox(10)

	var crest: Control = preload("res://scripts/ui/MenuCrest.gd").new()
	crest.custom_minimum_size = Vector2(0, CREST_HEIGHT)
	hero.add_child(crest)

	# Başlık levhası: manzaranın üstünde başlık tek başına dağılıyordu.
	var plate := UiKit.panel(Color(0.08, 0.07, 0.12, 0.55))
	var plate_column := UiKit.vbox(4)
	plate.add_child(plate_column)
	plate_column.add_child(UiKit.title("KELİME KALESİ"))
	plate_column.add_child(UiKit.label("Kadim kelimelerle kaleni savun",
		UiKit.FONT_SMALL, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	hero.add_child(plate)

	hero.add_child(_star_progress())
	return hero


## Yıldız ilerlemesi: simge + sayı, ortalanmış.
func _star_progress() -> Control:
	var row := UiKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon := SpriteBank.icon("yildiz_dolu")
	if icon != null:
		var texture := TextureRect.new()
		texture.texture = icon
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture.custom_minimum_size = Vector2(SIDE_ICON, SIDE_ICON)
		texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(texture)
	row.add_child(UiKit.label("%d / %d yıldız"
		% [SaveManager.total_stars(), GameConfig.TOTAL_LEVELS * 3],
		UiKit.FONT_BODY, UiKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	return row


## Alt blok: birincil oyna düğmesi ve ikincil menüler.
func _actions() -> Control:
	var actions := UiKit.vbox(14)

	var next_level := SaveManager.highest_unlocked_level()
	var region: Dictionary = GameConfig.REGIONS[GameConfig.region_of_level(next_level)]
	var play := UiKit.button("OYNA  —  Seviye %d" % next_level, UiKit.GOLD, UiKit.FONT_HEAD)
	play.custom_minimum_size = Vector2(0, PLAY_HEIGHT)
	play.pressed.connect(func():
		SceneRouter.pending_level_id = next_level
		SceneRouter.go_to("onizleme"))
	actions.add_child(play)

	# Sıradaki bölümün bölgesi: oyuncu nereye devam ettiğini bilsin.
	actions.add_child(UiKit.label("Sıradaki bölge: %s" % region["ad"],
		UiKit.FONT_SMALL, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))

	var map := _menu_button("Bölüm Haritası", "harita", "parsomen")
	map.add_theme_color_override("font_color", UiKit.INK)
	actions.add_child(map)

	# Günlük ödül düğmesi yalnız alınabilirken öne çıkar: her gün geri gelmek
	# için görünür bir sebep. Alındıysa yine erişilebilir ama sessiz kalır.
	var daily := _menu_button(_daily_label(), "gunluk", "sandik")
	if EconomyManager.daily_available():
		daily.add_theme_color_override("font_color", UiKit.GOLD)
	actions.add_child(daily)

	# İkincil menüler ikişerli: dört düğme tek sütunda ekranı dolduruyordu.
	var pairs := [
		[["Yükseltme", "yukseltme", "savas"], ["Mağaza", "magaza", "sandik"]],
		[["Başarımlar", "basarimlar", "yildiz_dolu"], ["Ayarlar", "ayarlar", ""]],
	]
	for pair in pairs:
		var row := UiKit.hbox(14)
		for entry in pair:
			var button := _menu_button(str(entry[0]), str(entry[1]), str(entry[2]))
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(button)
		actions.add_child(row)
	return actions


func _daily_label() -> String:
	if EconomyManager.daily_available():
		return "Günlük Ödül  •  HAZIR"
	var seri := EconomyManager.daily_streak()
	return "Günlük Ödül  •  %d gün seri" % seri


func _menu_button(text: String, target: String, icon_name: String) -> Button:
	var button := UiKit.ghost_button(text)
	if not icon_name.is_empty():
		UiKit.set_button_icon(button, icon_name)
	button.pressed.connect(func(): SceneRouter.go_to(target))
	return button


func _footer() -> Control:
	var text := "%s kelimelik TDK tabanlı sözlük • çevrimdışı oynanır" % WordEngine.word_count()
	return UiKit.paragraph(text, 22, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
