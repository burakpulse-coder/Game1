class_name TutorialOverlay
extends Control

## İlk üç seviyenin interaktif öğreticisi.
##
##   1. seviye "kaydirma"          -> parmakla harfleri birleştirip kelime bulma
##   2. seviye "kule_yerlestirme"  -> inşa puanı dolunca yuvaya kule dikme
##   3. seviye "kategori_eslesmesi"-> kelime kategorisinin kule tipini belirlemesi
##
## Öğretici oyunu durdurmaz; yalnızca yönlendirme balonu gösterir ve oyuncu
## istenen eylemi yapınca bir sonraki adıma geçer. Böylece "izlenen" değil,
## "yaşanan" bir öğretici olur.

signal finished(step: String)

const STEPS := {
	"kaydirma": [
		{
			"baslik": "Hoş geldin lordum!",
			"metin": "Kalen canavarlarla çevrili. Silahın kılıç değil — kelimeler.",
			"bekle": "dokun",
		},
		{
			"baslik": "Parmağını kaydır",
			"metin": "Aşağıdaki taşların üzerinde parmağını gezdirerek bir kelime kur "
				+ "ve parmağını kaldır.",
			"bekle": "kelime",
		},
		{
			"baslik": "İşte bu!",
			"metin": "Her doğru kelime kulelerini güçlendirir. Düşmanlar sen kelime "
				+ "ararken de yürümeye devam eder — hızlı ol.",
			"bekle": "dokun",
		},
	],
	"kule_yerlestirme": [
		{
			"baslik": "İnşa puanı",
			"metin": "Bulduğun kelimeler ekranın ortasındaki göstergeleri doldurur. "
				+ "Bir gösterge dolunca kule inşa edebilirsin.",
			"bekle": "kule_hazir",
		},
		{
			"baslik": "Yuvaya dokun",
			"metin": "Yol kenarındaki parıldayan boş yuvalardan birine dokunarak "
				+ "kuleni dik.",
			"bekle": "kule_kuruldu",
		},
		{
			"baslik": "Kule dikildi!",
			"metin": "Aynı kategoriden kelime bulmaya devam edersen bu kule seviye "
				+ "atlar (en fazla 3).",
			"bekle": "dokun",
		},
	],
	"kategori_eslesmesi": [
		{
			"baslik": "Kelime kuleyi seçer",
			"metin": "Hayvan → Okçu Kulesi\nDoğa → Büyü Kulesi\n"
				+ "Nesne → Mancınık\nYiyecek → Şifa Çeşmesi",
			"bekle": "dokun",
		},
		{
			"baslik": "Bir hayvan adı bul",
			"metin": "Çarktan bir hayvan adı kur; okçu kulesinin göstergesinin "
				+ "dolduğunu göreceksin.",
			"bekle": "kelime_hayvan",
		},
		{
			"baslik": "Uzun kelime = büyük etki",
			"metin": "3 harf 1x, 4 harf 1.5x, 5 harf 2x, 6+ harf 3x etki. "
				+ "7 harf ve üzeri 'Kadim Kelime' sayılır ve ultini şarj eder.",
			"bekle": "dokun",
		},
	],
}

var _step := ""
var _index := 0
var _waiting := ""
var _panel: PanelContainer
var _title: Label
var _body: Label
var _next: Button
var _battle: Node = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func _build() -> void:
	_panel = UiKit.panel(UiKit.BG_PANEL, UiKit.GOLD)
	_panel.anchor_left = 0.05
	_panel.anchor_right = 0.95
	_panel.anchor_top = 0.30
	_panel.anchor_bottom = 0.30
	_panel.offset_bottom = 340
	add_child(_panel)

	var column := UiKit.vbox(14)
	_title = UiKit.label("", UiKit.FONT_HEAD, UiKit.GOLD)
	_body = UiKit.paragraph("", UiKit.FONT_BODY, UiKit.INK)
	_next = UiKit.button("Anladım", UiKit.GOLD)
	_next.pressed.connect(_advance)
	column.add_child(_title)
	column.add_child(_body)
	column.add_child(_next)
	_panel.add_child(column)


func begin(step: String, battle: Node) -> void:
	if not STEPS.has(step):
		finished.emit(step)
		return
	_step = step
	_battle = battle
	_index = -1
	visible = true
	_advance()


func _advance() -> void:
	_index += 1
	var steps: Array = STEPS[_step]
	if _index >= steps.size():
		visible = false
		finished.emit(_step)
		return
	var data: Dictionary = steps[_index]
	_title.text = str(data["baslik"])
	_body.text = str(data["metin"])
	_waiting = str(data.get("bekle", "dokun"))
	# "dokun" dışındaki adımlarda oyuncunun eylemi beklenir; düğme gizlenir.
	_next.visible = _waiting == "dokun"
	_panel.visible = true


## Battle, oyuncunun yaptığı eylemleri buraya bildirir.
func notify(event: String, detail: String = "") -> void:
	if not visible or _waiting == "" or _waiting == "dokun":
		return
	var matched := false
	match _waiting:
		"kelime":
			matched = event == "kelime"
		"kelime_hayvan":
			matched = event == "kelime" and detail == "hayvan"
		"kule_hazir":
			matched = event == "kule_hazir"
		"kule_kuruldu":
			matched = event == "kule_kuruldu"
	if matched:
		_advance()
