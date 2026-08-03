extends Node

## Kare hızı yönetimi: 60 FPS hedeflenir, cihaz yetişemiyorsa otomatik olarak
## 30 FPS moduna düşülür ve görsel efektler azaltılır.
##
## Ayarlardan elle 60/30 seçilebilir (kare_hizi: 0=otomatik, 1=60, 2=30).

signal quality_changed(low_quality: bool)

const SAMPLE_SECONDS := 3.0
const DOWNGRADE_FPS := 45.0   ## bu ortalamanın altında kalıcı olarak düşülür
const UPGRADE_FPS := 57.0     ## 30 modunda bu kadar rahat çalışıyorsa geri çıkılır

var low_quality := false
var _accum := 0.0
var _frames := 0
var _auto := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.settings_changed.connect(_apply_setting)
	_apply_setting()


func _apply_setting() -> void:
	var mode := int(SaveManager.get_setting("kare_hizi", 0))
	_auto = mode == 0
	match mode:
		1:
			_set_quality(false)
			Engine.max_fps = 60
		2:
			_set_quality(true)
			Engine.max_fps = 30
		_:
			Engine.max_fps = 60
			_reset_sample()


func _reset_sample() -> void:
	_accum = 0.0
	_frames = 0


func _process(delta: float) -> void:
	if not _auto:
		return
	_accum += delta
	_frames += 1
	if _accum < SAMPLE_SECONDS:
		return
	var average := _frames / _accum
	_reset_sample()
	if not low_quality and average < DOWNGRADE_FPS:
		GameLog.info("Perf", "Ortalama %.0f FPS — 30 FPS moduna düşülüyor." % average)
		_set_quality(true)
		Engine.max_fps = 30
	elif low_quality and average > UPGRADE_FPS:
		GameLog.info("Perf", "Cihaz rahat çalışıyor — 60 FPS moduna dönülüyor.")
		_set_quality(false)
		Engine.max_fps = 60


func _set_quality(low: bool) -> void:
	if low_quality == low:
		return
	low_quality = low
	quality_changed.emit(low)


## Efekt yoğunluğu: düşük kalitede parçacık/sarsıntı azaltılır.
func effect_scale() -> float:
	return 0.4 if low_quality else 1.0
