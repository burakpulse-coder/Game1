extends Node

## Ekranlar arası geçiş ve iki ekran arasında taşınan oturum verisi.
## UI/UX akışı: Ana Menü -> Harita -> Önizleme -> Oyun -> Sonuç -> Harita

const SCENES := {
	"ana_menu": "res://scenes/AnaMenu.tscn",
	"harita": "res://scenes/BolumHaritasi.tscn",
	"onizleme": "res://scenes/SeviyeOnizleme.tscn",
	"oyun": "res://scenes/Oyun.tscn",
	"sonuc": "res://scenes/SonucEkrani.tscn",
	"yukseltme": "res://scenes/YukseltmeEkrani.tscn",
	"magaza": "res://scenes/Magaza.tscn",
	"ayarlar": "res://scenes/Ayarlar.tscn",
	"basarimlar": "res://scenes/Basarimlar.tscn",
	"gunluk": "res://scenes/GunlukOdul.tscn",
}

## Oyun -> Sonuç ekranına taşınan veri.
var pending_level_id := 1
var last_result := {}
var _fading := false


func go_to(key: String) -> void:
	var path: String = SCENES.get(key, "")
	if path == "":
		push_error("[SceneRouter] Bilinmeyen ekran: %s" % key)
		return
	AudioManager.play_sfx("dugme")
	_change(path)


func play_level(level_id: int) -> void:
	pending_level_id = level_id
	_change(SCENES["oyun"])


func show_result(result: Dictionary) -> void:
	last_result = result
	_change(SCENES["sonuc"])


func _change(path: String) -> void:
	if _fading:
		return
	_fading = true
	# call_deferred: mevcut sahne sinyalleri işlerken sahne değiştirmek çökmeye yol açar.
	_do_change.call_deferred(path)


func _do_change(path: String) -> void:
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("[SceneRouter] Sahne yüklenemedi: %s (%s)" % [path, error_string(error)])
	_fading = false
