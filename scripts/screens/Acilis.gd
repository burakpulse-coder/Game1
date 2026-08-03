extends Control

## Açılış ekranı. Sözlük ve seviye verisi otomatik yükleyicilerde hazırlanır;
## burada yalnızca kısa bir marka ekranı gösterilir ve ana menüye geçilir.

const MIN_SPLASH := 0.9

var _elapsed := 0.0
var _routed := false
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.background(Color("#2a2140"), Color("#12101c")))

	var column := UiKit.vbox(16)
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.anchor_left = 0.1
	column.anchor_right = 0.9
	column.offset_top = -180
	column.offset_bottom = 180
	add_child(column)

	column.add_child(UiKit.title("KELİME KALESİ"))
	column.add_child(UiKit.label("Kadim kelimelerle kaleni savun",
		UiKit.FONT_BODY, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	_status = UiKit.label("Sözlük hazırlanıyor…", UiKit.FONT_SMALL, UiKit.INK_SOFT,
		HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(_status)


func _process(delta: float) -> void:
	if _routed:
		return
	_elapsed += delta
	if WordEngine.is_ready():
		_status.text = "%s kelimelik sözlük hazır" % _thousands(WordEngine.word_count())
	if _elapsed >= MIN_SPLASH and WordEngine.is_ready() and LevelDB.count() > 0:
		_routed = true
		AudioManager.play_music("menu")
		SceneRouter.go_to("ana_menu")
	elif _elapsed > 8.0:
		# Veri yüklenemese bile oyuncu menüde kalmasın diye yine de geç.
		_routed = true
		SceneRouter.go_to("ana_menu")


func _thousands(value: int) -> String:
	var text := str(value)
	var out := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		out = text[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return out
