extends Node

## Google Play Games Services sarmalayıcısı (oturum, başarım, bulut kayıt, skor).
##
## Eklenti (`GodotPlayGameServices`) yalnızca Android derlemesinde bulunur.
## Eklenti yoksa tüm çağrılar sessizce yerel moda düşer; oyun tam oynanabilir kalır.
## Kurulum: bkz. README "Android eklentileri".

signal sign_in_changed(signed_in: bool)
signal cloud_save_loaded(data: Dictionary)

const SINGLETON_NAME := "GodotPlayGameServices"
const SAVE_SLOT := "kelime_kalesi_kayit"

## Başarım kimlikleri. Play Console'da tanımlanan gerçek kimliklerle eşlenir.
const ACHIEVEMENTS := {
	"ilk_kelime": {"ad": "İlk Kelime", "aciklama": "İlk geçerli kelimeni bul."},
	"ilk_kule": {"ad": "İlk Kule", "aciklama": "İlk kuleni inşa et."},
	"kadim_kelime": {"ad": "Kadim Kelime", "aciklama": "7 harfli bir kelime bul."},
	"vadi_fatihi": {"ad": "Vadi Fatihi", "aciklama": "Yeşil Vadi'yi tamamla."},
	"orman_fatihi": {"ad": "Orman Fatihi", "aciklama": "Karanlık Orman'ı tamamla."},
	"buz_fatihi": {"ad": "Buz Fatihi", "aciklama": "Buz Dağları'nı tamamla."},
	"ejder_avcisi": {"ad": "Ejder Avcısı", "aciklama": "Ejder Kalesi Efendisi'ni yen."},
	"kelime_ustasi": {"ad": "Kelime Ustası", "aciklama": "Toplam 500 kelime bul."},
	"kusursuz": {"ad": "Kusursuz Savunma", "aciklama": "Hiç can kaybetmeden bir seviye bitir."},
	"usta_mimar": {"ad": "Usta Mimar", "aciklama": "Bir seviyede 3. seviye kule inşa et."},
}

## Skor tabloları — sonsuz mod ileride eklendiğinde bu altyapı kullanılacak.
const LEADERBOARDS := {
	"toplam_yildiz": "Toplam Yıldız",
	"sonsuz_mod": "Sonsuz Mod Skoru",
}

var _plugin: Object = null
var _signed_in := false


func _ready() -> void:
	if Engine.has_singleton(SINGLETON_NAME):
		_plugin = Engine.get_singleton(SINGLETON_NAME)
		_connect_plugin_signals()
		_call_plugin("signIn")
	else:
		print("[PlayServices] Eklenti yok — yerel modda çalışılıyor.")


func _connect_plugin_signals() -> void:
	# Eklenti sürümleri arasında sinyal adları değişebildiği için savunmacı bağlanılır.
	for pair in [
		["signInSuccess", _on_sign_in_success],
		["signInFailed", _on_sign_in_failed],
		["saveGameLoaded", _on_cloud_save_loaded],
	]:
		if _plugin.has_signal(pair[0]):
			_plugin.connect(pair[0], pair[1])


func _call_plugin(method: String, args: Array = []):
	if _plugin == null or not _plugin.has_method(method):
		return null
	return _plugin.callv(method, args)


func is_signed_in() -> bool:
	return _signed_in


func is_available() -> bool:
	return _plugin != null


func _on_sign_in_success(_data = null) -> void:
	_signed_in = true
	sign_in_changed.emit(true)
	load_cloud_save()
	for id in SaveManager.progress.get("basarimlar", []):
		unlock_achievement(id)


func _on_sign_in_failed(_data = null) -> void:
	_signed_in = false
	sign_in_changed.emit(false)


func sign_in() -> void:
	_call_plugin("signIn")


func unlock_achievement(id: String) -> void:
	if not _signed_in:
		return
	_call_plugin("unlockAchievement", [id])


func submit_score(leaderboard_id: String, score: int) -> void:
	if not _signed_in:
		return
	_call_plugin("submitScore", [leaderboard_id, score])


func show_achievements() -> void:
	_call_plugin("showAchievements")


func show_leaderboard(leaderboard_id: String) -> void:
	_call_plugin("showLeaderboard", [leaderboard_id])


func upload_save(data: Dictionary) -> void:
	if not _signed_in:
		return
	_call_plugin("saveSnapshot", [SAVE_SLOT, JSON.stringify(data)])


func load_cloud_save() -> void:
	if not _signed_in:
		return
	_call_plugin("loadSnapshot", [SAVE_SLOT])


func _on_cloud_save_loaded(payload) -> void:
	var text := str(payload)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	cloud_save_loaded.emit(parsed)
	SaveManager.merge_cloud_save(parsed)
