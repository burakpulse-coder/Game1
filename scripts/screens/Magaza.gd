extends Control

## Mağaza: destekler, elmas paketleri, reklam kaldırma ve paketler.
##
## Kozmetik satışı kaldırıldı. Rakiplerin (Wordscapes, Words of Wonders,
## Royal Match, Kingdom Rush, Bloons TD) ortak dizilimi iki başlık altında
## toplanıyor: bölümü geçmene yardım eden tüketilir destekler ve reklam
## kaldırma. Görünüm satmak mobil bulmaca/savunma oyunlarında karşılık
## bulmuyor.
##
## Destekler elmasla alınır; elmas oyun içinde de kazanılır (bölüm ödülü,
## ödüllü video). Yani ödeme kilit açmaz, hızlandırır.

var _status: Label
var _booster_rows := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.background(Color("#3a2a44"), Color("#12101c")))

	var margin := UiKit.margin(36)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var column := UiKit.vbox(16)
	margin.add_child(column)
	column.add_child(UiKit.top_bar("Mağaza", func(): SceneRouter.go_to("ana_menu")))

	_status = UiKit.paragraph("")
	column.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var list := UiKit.vbox(16)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	# Destekler önce: mağazanın asıl işi bu.
	list.add_child(UiKit.label("Bölüm öncesi destekler", UiKit.FONT_BODY, UiKit.INK))
	list.add_child(UiKit.paragraph(
		"Savaş başlamadan takılır. Aynı anda en fazla %d tane."
			% GameConfig.MAX_PRE_BOOSTERS, 22))
	for id in EconomyManager.boosters_of_kind("oncesi"):
		list.add_child(_booster_row(str(id)))

	list.add_child(UiKit.spacer(10))
	list.add_child(UiKit.label("Savaş içi destekler", UiKit.FONT_BODY, UiKit.INK))
	list.add_child(UiKit.paragraph("Savaş sırasında, sıkıştığın anda kullanılır.", 22))
	for id in EconomyManager.boosters_of_kind("savas"):
		list.add_child(_booster_row(str(id)))

	list.add_child(UiKit.spacer(10))
	list.add_child(UiKit.label("Elmas ve paketler", UiKit.FONT_BODY, UiKit.INK))
	for product_id in GameConfig.IAP_PRODUCTS:
		list.add_child(_product_row(str(product_id)))

	IapManager.purchase_completed.connect(_on_purchase_completed)
	IapManager.purchase_failed.connect(_on_purchase_failed)
	IapManager.products_updated.connect(_refresh)
	EconomyManager.currency_changed.connect(func(_g, _e): _refresh())
	EconomyManager.boosters_changed.connect(_refresh)
	_refresh()


## --------------------------------------------------------------------------
## Satırlar
## --------------------------------------------------------------------------

func _booster_row(booster_id: String) -> Control:
	var data: Dictionary = GameConfig.BOOSTERS[booster_id]
	var box := UiKit.panel(UiKit.BG_PANEL)
	var row := UiKit.hbox(14)
	box.add_child(row)

	row.add_child(ArtIcon.booster(str(data.get("simge", "")), 64.0))

	var info := UiKit.vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiKit.label(str(data["ad"]), UiKit.FONT_SMALL, UiKit.INK))
	info.add_child(UiKit.paragraph(str(data["aciklama"]), 22))
	row.add_child(info)

	var count := UiKit.label("", UiKit.FONT_SMALL, UiKit.INK_SOFT)
	count.custom_minimum_size = Vector2(70, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(count)

	var buy := UiKit.button("", UiKit.GEM)
	buy.custom_minimum_size = Vector2(190, UiKit.TOUCH_MIN)
	buy.pressed.connect(func():
		if not EconomyManager.buy_booster(booster_id):
			_status.text = "Yeterli elmas yok"
		else:
			_status.text = "%s alındı" % data["ad"]
		_refresh())
	row.add_child(buy)

	_booster_rows[booster_id] = {"buton": buy, "sayi": count}
	return box


func _product_row(product_id: String) -> Control:
	var data: Dictionary = GameConfig.IAP_PRODUCTS[product_id]
	var box := UiKit.panel(UiKit.BG_PANEL)
	var column := UiKit.vbox(6)
	box.add_child(column)

	if data.has("rozet"):
		column.add_child(UiKit.label(str(data["rozet"]), UiKit.FONT_SMALL, UiKit.GOLD))

	var row := UiKit.hbox(14)
	column.add_child(row)

	var info := UiKit.vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiKit.label(str(data["ad"]), UiKit.FONT_SMALL, UiKit.INK))
	info.add_child(UiKit.paragraph(_product_detail(product_id, data), 22))
	row.add_child(info)

	var buy := UiKit.button(IapManager.price_of(product_id), UiKit.GEM)
	buy.custom_minimum_size = Vector2(240, UiKit.TOUCH_MIN)
	buy.set_meta("product", product_id)
	buy.pressed.connect(func(): IapManager.purchase(product_id))
	if not IapManager.is_purchasable(product_id):
		buy.text = "SAHİPSİN"
		buy.disabled = true
	elif not IapManager.is_available():
		buy.disabled = true
	row.add_child(buy)
	return box


func _product_detail(product_id: String, data: Dictionary) -> String:
	if data.has("aciklama"):
		var text := str(data["aciklama"])
		if int(data.get("elmas", 0)) > 0:
			text += "  (+%d ◆)" % int(data["elmas"])
		return text
	var parts: PackedStringArray = []
	if int(data.get("elmas", 0)) > 0:
		parts.append("%d ◆" % int(data["elmas"]))
	if data.has("altin"):
		parts.append("%d ●" % int(data["altin"]))
	for id in data.get("destekler", {}):
		parts.append("%dx %s" % [int(data["destekler"][id]),
			GameConfig.BOOSTERS.get(id, {}).get("ad", id)])
	return "  •  ".join(parts) if not parts.is_empty() else str(product_id)


## --------------------------------------------------------------------------
## Yenileme
## --------------------------------------------------------------------------

func _refresh() -> void:
	for booster_id in _booster_rows:
		var data: Dictionary = GameConfig.BOOSTERS[booster_id]
		var refs: Dictionary = _booster_rows[booster_id]
		var button := refs["buton"] as Button
		var count := refs["sayi"] as Label
		count.text = "x%d" % EconomyManager.booster_count(str(booster_id))
		button.text = "%d ◆" % int(data["elmas"])
		button.disabled = EconomyManager.gems() < int(data["elmas"])

	if not IapManager.is_available():
		_status.text = "Mağaza bağlantısı yok — gerçek para satın almaları şu an "
		_status.text += "kullanılamıyor. Destekleri elmasla almaya devam edebilirsin."
	elif _status.text.begins_with("Mağaza bağlantısı"):
		_status.text = ""


func _on_purchase_completed(product_id: String) -> void:
	var data: Dictionary = GameConfig.IAP_PRODUCTS.get(product_id, {})
	_status.text = "%s alındı, teşekkürler!" % data.get("ad", product_id)
	_refresh()


func _on_purchase_failed(_product_id: String, reason: String) -> void:
	_status.text = reason
