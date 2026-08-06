extends Node

## AdMob sarmalayıcısı.
##
## Kurallar (spesifikasyon gereği):
##   * Geçiş reklamı yalnızca seviye sonuçlarından sonra ve 3 seviyede bir gösterilir;
##     asla oyun ortasında gösterilmez.
##   * "Reklamları Kaldır" satın alındığında geçiş reklamları kapanır,
##     ödüllü videolar çalışmaya devam eder.
##   * Eklenti yoksa ya da internet yoksa oyun tam oynanabilir kalır; ödüllü
##     video isteği başarısız olarak döner ve oyuncuya ödül vaadi verilmez.

signal rewarded_finished(success: bool, placement: String)
signal interstitial_closed

const SINGLETON_NAME := "AdMob"
const REMOVE_ADS_PRODUCT := "reklamsiz"

## Ödüllü video yerleşimleri.
const PLACEMENT_CONTINUE := "devam_et"
const PLACEMENT_DAILY_CHEST := "gunluk_sandik"
const PLACEMENT_EXTRA_HINT := "ekstra_ipucu"
## Bölüm sonunda "video izle, destek kazan" teklifi.
const PLACEMENT_BOOSTER := "destek_kazan"

## Yayına çıkarken Play Console'daki gerçek birim kimlikleriyle değiştirilir.
## Buradakiler Google'ın resmî test kimlikleridir.
const AD_UNITS := {
	"banner": "ca-app-pub-3940256099942544/6300978111",
	"interstitial": "ca-app-pub-3940256099942544/1033173712",
	"rewarded": "ca-app-pub-3940256099942544/5224354917",
}

var _plugin: Object = null
var _rewarded_ready := false
var _interstitial_ready := false
var _pending_placement := ""


func _ready() -> void:
	if Engine.has_singleton(SINGLETON_NAME):
		_plugin = Engine.get_singleton(SINGLETON_NAME)
		_connect_plugin_signals()
		_call("initialize")
		_load_rewarded()
		_load_interstitial()
	else:
		print("[AdManager] AdMob eklentisi yok — reklamlar devre dışı.")


func _connect_plugin_signals() -> void:
	for pair in [
		["rewarded_ad_loaded", _on_rewarded_loaded],
		["rewarded_ad_failed_to_load", _on_rewarded_failed],
		["user_earned_rewarded", _on_reward_earned],
		["rewarded_ad_dismissed", _on_rewarded_dismissed],
		["interstitial_loaded", _on_interstitial_loaded],
		["interstitial_failed_to_load", _on_interstitial_failed],
		["interstitial_closed", _on_interstitial_closed],
	]:
		if _plugin.has_signal(pair[0]):
			_plugin.connect(pair[0], pair[1])


func _call(method: String, args: Array = []):
	if _plugin == null or not _plugin.has_method(method):
		return null
	return _plugin.callv(method, args)


func is_available() -> bool:
	return _plugin != null


func ads_removed() -> bool:
	return SaveManager.has_purchase(REMOVE_ADS_PRODUCT)


## --------------------------------------------------------------------------
## Ödüllü video
## --------------------------------------------------------------------------

func rewarded_available() -> bool:
	return _plugin != null and _rewarded_ready


## Ödüllü videoyu gösterir. Gösterilemiyorsa rewarded_finished(false, ...) yayınlar;
## çağıran taraf ödülü yalnızca success=true olduğunda vermelidir.
func show_rewarded(placement: String) -> void:
	if not rewarded_available():
		rewarded_finished.emit(false, placement)
		return
	_pending_placement = placement
	_call("show_rewarded_ad")


func _load_rewarded() -> void:
	_call("load_rewarded_ad", [AD_UNITS["rewarded"]])


func _on_rewarded_loaded(_data = null) -> void:
	_rewarded_ready = true


func _on_rewarded_failed(_data = null) -> void:
	_rewarded_ready = false


func _on_reward_earned(_currency = "", _amount = 0) -> void:
	rewarded_finished.emit(true, _pending_placement)
	_pending_placement = ""


func _on_rewarded_dismissed(_data = null) -> void:
	# Ödül kazanılmadan kapatıldıysa başarısız say.
	if _pending_placement != "":
		rewarded_finished.emit(false, _pending_placement)
		_pending_placement = ""
	_rewarded_ready = false
	_load_rewarded()


## --------------------------------------------------------------------------
## Geçiş reklamı
## --------------------------------------------------------------------------

func _load_interstitial() -> void:
	_call("load_interstitial", [AD_UNITS["interstitial"]])


func _on_interstitial_loaded(_data = null) -> void:
	_interstitial_ready = true


func _on_interstitial_failed(_data = null) -> void:
	_interstitial_ready = false


func _on_interstitial_closed(_data = null) -> void:
	_interstitial_ready = false
	_load_interstitial()
	interstitial_closed.emit()


## Seviye tamamlandığında çağrılır. Sayaç dolmadıysa ya da reklamlar
## kaldırıldıysa hiçbir şey yapmaz. Oyun ortasında ASLA çağrılmaz.
func maybe_show_interstitial_after_level() -> bool:
	if ads_removed():
		return false
	var counter := int(SaveManager.progress.get("tamamlanan_seviye_sayaci", 0)) + 1
	SaveManager.progress["tamamlanan_seviye_sayaci"] = counter
	SaveManager.mark_dirty()
	if counter % GameConfig.INTERSTITIAL_EVERY_N_LEVELS != 0:
		return false
	if _plugin == null or not _interstitial_ready:
		return false
	_call("show_interstitial")
	return true
