extends Control

## Günlük giriş ödülü: yedi günlük takvim.
##
## Rakiplerin (Royal Match, Toon Blast, Wordscapes) ortak kalıbı: gün gün
## büyüyen ödüller, yedinci günde belirgin bir sıçrama ve bir gün kaçırınca
## baştan başlama. Buradaki amaç sadece geri getirmek değil — destek sistemi
## elmasla çalışıyor ve ödemeyen oyuncunun düzenli bir kaynağı olmalı.
##
## Ödül alındıktan sonra ödüllü videoyla bir kat daha alınabilir (günde bir).

var _cards := {}
var _status: Label
var _claim: Button
var _double: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.background(Color("#2a2440"), Color("#12101c")))

	var margin := UiKit.margin(36)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var column := UiKit.vbox(16)
	margin.add_child(column)
	column.add_child(UiKit.top_bar("Günlük Ödül", func(): SceneRouter.go_to("ana_menu")))

	_status = UiKit.paragraph("", UiKit.FONT_SMALL, UiKit.INK_SOFT,
		HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	for entry in GameConfig.DAILY_REWARDS:
		grid.add_child(_day_card(int(entry["gun"]), entry))

	_claim = UiKit.button("ÖDÜLÜ AL", UiKit.GOLD, UiKit.FONT_HEAD)
	_claim.custom_minimum_size = Vector2(0, 118)
	_claim.pressed.connect(_on_claim)
	column.add_child(_claim)

	_double = UiKit.button("Video izle → iki katı", UiKit.SUCCESS)
	_double.pressed.connect(_on_double)
	column.add_child(_double)

	_refresh()


## Tek bir günün kartı: ödül simgesi + miktar.
func _day_card(day: int, reward: Dictionary) -> Control:
	# Son gün serinin ödülü: kart altın çerçeveli, oyuncu neye doğru
	# gittiğini görsün.
	var buyuk_gun := day == GameConfig.DAILY_REWARDS.size()
	var box := UiKit.panel(UiKit.BG_PANEL,
		UiKit.GOLD if buyuk_gun else Color(0, 0, 0, 0))
	var column := UiKit.vbox(6)
	box.add_child(column)

	var head := UiKit.label("%d. gün" % day, UiKit.FONT_SMALL,
		UiKit.GOLD if buyuk_gun else UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(head)

	var icons := UiKit.hbox(6)
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	if reward.has("destek"):
		var data: Dictionary = GameConfig.BOOSTERS.get(reward["destek"], {})
		icons.add_child(ArtIcon.booster(str(data.get("simge", "")), 56.0))
	column.add_child(icons)

	var parts: PackedStringArray = []
	if reward.has("altin"):
		parts.append("%d ●" % int(reward["altin"]))
	if reward.has("elmas"):
		parts.append("%d ◆" % int(reward["elmas"]))
	if reward.has("destek"):
		var data: Dictionary = GameConfig.BOOSTERS.get(reward["destek"], {})
		var adet := int(reward.get("adet", 1))
		# Dar kartta "1x Yıldırım" satır ortasından bölünüyordu; tek adette
		# sayı yazılmaz, simge zaten hangi destek olduğunu söylüyor.
		parts.append(str(data.get("ad", "")) if adet == 1
			else "%dx %s" % [adet, data.get("ad", "")])
	var text := UiKit.label("\n".join(parts), 22, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	# Kelime ortasından bölme: dar kartta "Yıldırım" -> "Yıldırı m" oluyordu.
	text.autowrap_mode = TextServer.AUTOWRAP_WORD
	column.add_child(text)

	var state := UiKit.label("", 22, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(state)

	_cards[day] = {"kutu": box, "durum": state}
	return box


func _refresh() -> void:
	var bugun := EconomyManager.daily_day()
	var alinabilir := EconomyManager.daily_available()

	for day in _cards:
		var refs: Dictionary = _cards[day]
		var state := refs["durum"] as Label
		var box := refs["kutu"] as PanelContainer
		if int(day) < bugun or (int(day) == bugun and not alinabilir):
			state.text = "alındı"
			state.add_theme_color_override("font_color", UiKit.SUCCESS)
			box.modulate = Color(0.65, 0.65, 0.65)
		elif int(day) == bugun:
			state.text = "BUGÜN"
			state.add_theme_color_override("font_color", UiKit.GOLD)
			box.modulate = Color.WHITE
		else:
			state.text = ""
			box.modulate = Color(0.8, 0.8, 0.8)

	var seri := EconomyManager.daily_streak()
	if alinabilir:
		_status.text = "Bugünün ödülü seni bekliyor. Seri: %d gün" % seri
		_claim.disabled = false
		_claim.text = "ÖDÜLÜ AL"
	else:
		_status.text = "Bugünkü ödülü aldın. Seri: %d gün — yarın devam et." % seri
		_claim.disabled = true
		_claim.text = "YARIN GÖRÜŞÜRÜZ"

	var video_var := AdManager.rewarded_available() and not AdManager.ads_removed()
	_double.visible = EconomyManager.daily_can_double() and video_var
	_double.disabled = false


func _on_claim() -> void:
	var verilen := EconomyManager.claim_daily()
	if verilen.is_empty():
		_refresh()
		return
	AudioManager.play_sfx("zafer")
	Haptics.pulse(Haptics.MEDIUM)
	_status.text = "Aldın: %s" % _reward_text(verilen)
	_refresh()


func _on_double() -> void:
	_double.disabled = true
	AdManager.rewarded_finished.connect(_on_double_ad, CONNECT_ONE_SHOT)
	AdManager.show_rewarded(AdManager.PLACEMENT_DAILY_CHEST)


func _on_double_ad(success: bool, placement: String) -> void:
	if placement != AdManager.PLACEMENT_DAILY_CHEST:
		return
	if not success:
		_status.text = "Video açılamadı."
		_double.disabled = false
		return
	var verilen := EconomyManager.double_daily_with_ad()
	_status.text = "Bir kat daha: %s" % _reward_text(verilen)
	_refresh()


func _reward_text(verilen: Dictionary) -> String:
	var parts: PackedStringArray = []
	if verilen.has("altin"):
		parts.append("%d altın" % int(verilen["altin"]))
	if verilen.has("elmas"):
		parts.append("%d elmas" % int(verilen["elmas"]))
	if verilen.has("destek"):
		var data: Dictionary = GameConfig.BOOSTERS.get(verilen["destek"], {})
		parts.append("%dx %s" % [int(verilen.get("adet", 1)), data.get("ad", "")])
	return ", ".join(parts)
