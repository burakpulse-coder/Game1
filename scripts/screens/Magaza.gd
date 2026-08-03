extends Control

## Mağaza: elmas paketleri, reklamsız paket, başlangıç paketi ve kozmetikler.
##
## Kozmetikler yalnızca görünüm değiştirir; kule gücünü, kale canını veya
## kelime etkisini ETKİLEMEZ (pay-to-win yok).

var _status: Label
var _cosmetic_rows := {}


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

	list.add_child(UiKit.label("Elmas ve paketler", UiKit.FONT_BODY, UiKit.INK))
	for product_id in GameConfig.IAP_PRODUCTS:
		list.add_child(_product_row(product_id))

	list.add_child(UiKit.spacer(10))
	list.add_child(UiKit.label("Görünümler", UiKit.FONT_BODY, UiKit.INK))
	list.add_child(UiKit.paragraph(
		"Kozmetikler yalnızca görünümü değiştirir, oyun gücünü etkilemez.", 22))
	for cosmetic_id in GameConfig.COSMETICS:
		list.add_child(_cosmetic_row(cosmetic_id))

	IapManager.purchase_completed.connect(_on_purchase_completed)
	IapManager.purchase_failed.connect(_on_purchase_failed)
	IapManager.products_updated.connect(_refresh)
	EconomyManager.currency_changed.connect(func(_g, _e): _refresh())
	_refresh()


func _product_row(product_id: String) -> Control:
	var data: Dictionary = GameConfig.IAP_PRODUCTS[product_id]
	var box := UiKit.panel(UiKit.BG_PANEL)
	var row := UiKit.hbox(14)
	box.add_child(row)

	var info := UiKit.vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiKit.label(str(data["ad"]), UiKit.FONT_SMALL, UiKit.INK))
	var detail := ""
	if int(data.get("elmas", 0)) > 0:
		detail += "%d ◆" % int(data["elmas"])
	if data.has("altin"):
		detail += "   %d ●" % int(data["altin"])
	if product_id == "reklamsiz":
		detail = "Tüm geçiş reklamları kapanır (ödüllü videolar kalır)"
	info.add_child(UiKit.paragraph(detail, 22))
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


func _cosmetic_row(cosmetic_id: String) -> Control:
	var data: Dictionary = GameConfig.COSMETICS[cosmetic_id]
	var box := UiKit.panel(UiKit.BG_PANEL)
	var row := UiKit.hbox(14)
	box.add_child(row)

	var swatch := ColorRect.new()
	swatch.color = Color(data["renk"])
	swatch.custom_minimum_size = Vector2(64, 64)
	row.add_child(swatch)

	var info := UiKit.vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiKit.label(str(data["ad"]), UiKit.FONT_SMALL, UiKit.INK))
	info.add_child(UiKit.paragraph("Kale görünümü" if data["hedef"] == "kale" else "Kule görünümü",
		22))
	row.add_child(info)

	var action := UiKit.button("", UiKit.GEM)
	action.custom_minimum_size = Vector2(230, UiKit.TOUCH_MIN)
	action.pressed.connect(func():
		if EconomyManager.owns_cosmetic(cosmetic_id):
			EconomyManager.equip_cosmetic(cosmetic_id)
		elif not EconomyManager.buy_cosmetic(cosmetic_id):
			_status.text = "Yeterli elmas yok"
		_refresh())
	row.add_child(action)

	_cosmetic_rows[cosmetic_id] = action
	return box


func _refresh() -> void:
	for cosmetic_id in _cosmetic_rows:
		var data: Dictionary = GameConfig.COSMETICS[cosmetic_id]
		var button := _cosmetic_rows[cosmetic_id] as Button
		if EconomyManager.equipped_cosmetic(str(data["hedef"])) == cosmetic_id:
			button.text = "KULLANILIYOR"
			button.disabled = true
		elif EconomyManager.owns_cosmetic(cosmetic_id):
			button.text = "KUŞAN"
			button.disabled = false
		else:
			button.text = "%d ◆" % int(data["elmas"])
			button.disabled = EconomyManager.gems() < int(data["elmas"])

	if not IapManager.is_available():
		_status.text = "Mağaza bağlantısı yok — satın almalar şu an kullanılamıyor. "
		_status.text += "Oyunun tamamı çevrimdışı oynanabilir."
	else:
		_status.text = ""


func _on_purchase_completed(product_id: String) -> void:
	var data: Dictionary = GameConfig.IAP_PRODUCTS.get(product_id, {})
	_status.text = "%s alındı, teşekkürler!" % data.get("ad", product_id)
	_refresh()


func _on_purchase_failed(_product_id: String, reason: String) -> void:
	_status.text = reason
