extends Node

## Müzik ve ses efektleri. Müzik ile efekt sesi ayrı ayrı kısılabilir/kapatılabilir.
## Ses efektleri için küçük bir oynatıcı havuzu kullanılır (aynı anda çok ses).

const SFX_VOICES := 8
const MUSIC_FADE := 0.8

const SFX := {
	"kelime_dogru": "res://assets/audio/sfx_kelime_dogru.wav",
	"kelime_yanlis": "res://assets/audio/sfx_kelime_yanlis.wav",
	"harf_sec": "res://assets/audio/sfx_harf_sec.wav",
	"kule_insa": "res://assets/audio/sfx_kule_insa.wav",
	"okcu_atis": "res://assets/audio/sfx_okcu_atis.wav",
	"buyu_atis": "res://assets/audio/sfx_buyu_atis.wav",
	"mancinik_atis": "res://assets/audio/sfx_mancinik_atis.wav",
	"dusman_olum": "res://assets/audio/sfx_dusman_olum.wav",
	"kale_hasar": "res://assets/audio/sfx_kale_hasar.wav",
	"ulti": "res://assets/audio/sfx_ulti.wav",
	"zafer": "res://assets/audio/sfx_zafer.wav",
	"yenilgi": "res://assets/audio/sfx_yenilgi.wav",
	"dugme": "res://assets/audio/sfx_dugme.wav",
}

const MUSIC := {
	"menu": "res://assets/audio/muzik_menu.wav",
	"savas": "res://assets/audio/muzik_savas.wav",
}

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _cache := {}
var _current_music := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	add_child(_music_player)
	for i in SFX_VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_sfx_players.append(player)
	SaveManager.settings_changed.connect(_apply_volumes)
	_apply_volumes()


func _apply_volumes() -> void:
	_music_player.volume_db = _to_db(float(SaveManager.get_setting("muzik", 0.7)))
	var sfx_db := _to_db(float(SaveManager.get_setting("ses", 0.9)))
	for player in _sfx_players:
		player.volume_db = sfx_db


func _to_db(linear: float) -> float:
	if linear <= 0.001:
		return -80.0
	return linear_to_db(clampf(linear, 0.0, 1.0))


func _stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		_cache[path] = null
		return null
	var stream := ResourceLoader.load(path) as AudioStream
	_cache[path] = stream
	return stream


func play_sfx(key: String, pitch: float = 1.0) -> void:
	if float(SaveManager.get_setting("ses", 0.9)) <= 0.001:
		return
	var path: String = SFX.get(key, "")
	var stream := _stream(path)
	if stream == null:
		return
	var player := _sfx_players[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx_players.size()
	player.stream = stream
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	player.play()


func play_music(key: String) -> void:
	if _current_music == key:
		return
	var path: String = MUSIC.get(key, "")
	var stream := _stream(path)
	_current_music = key
	if stream == null:
		_music_player.stop()
		return
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = stream.data.size() / 2  # 16-bit mono örnek sayısı
	_music_player.stream = stream
	if float(SaveManager.get_setting("muzik", 0.7)) > 0.001:
		_music_player.play()


func stop_music() -> void:
	_current_music = ""
	_music_player.stop()
