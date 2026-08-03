class_name WaveManager
extends Node

## Dalga akışını yönetir.
##
## Gerçek zamanlı tempo: düşmanlar oyuncu kelime ararken de gelmeye devam eder.
## Dalgalar arasında 5 saniyelik nefes molası verilir; bu sırada oyuncu kelime
## bulup kule dizmeye devam edebilir.

signal wave_started(index: int, total: int, is_boss: bool)
signal break_started(seconds: float)
signal all_waves_finished
signal spawn_requested(enemy_type: String, path_index: int, power: float)

enum State { IDLE, DELAY, SPAWNING, BREAK, DONE }

var waves: Array = []
var current_index := -1

var _state: State = State.IDLE
var _timer := 0.0
var _queue: Array = []       ## bu dalgada kalan doğumlar: {tip, yol, guc}
var _spawn_gap := 1.0
var _break_seconds := GameConfig.WAVE_BREAK_SECONDS


func setup(wave_data: Array) -> void:
	waves = wave_data
	current_index = -1
	_state = State.IDLE
	_timer = 0.0
	_queue.clear()


func start() -> void:
	if waves.is_empty():
		_state = State.DONE
		all_waves_finished.emit()
		return
	_begin_wave(0)


func is_finished() -> bool:
	return _state == State.DONE


func wave_count() -> int:
	return waves.size()


## Kalan bekleme süresi (mola göstergesi için); mola yoksa 0.
func break_remaining() -> float:
	return _timer if _state == State.BREAK or _state == State.DELAY else 0.0


func _begin_wave(index: int) -> void:
	current_index = index
	var wave: Dictionary = waves[index]
	_queue.clear()

	# Grupları sırayla değil, aralarına serpiştirerek kuyruğa al ki dalga
	# tek tip bir tren yerine karışık bir akın gibi hissettirsin.
	var streams: Array = []
	var gaps: Array = []
	for group in wave.get("gruplar", []):
		var stream: Array = []
		for i in int(group.get("adet", 0)):
			stream.append({
				"tip": str(group.get("tip", "goblin")),
				"yol": int(group.get("yol", 0)),
				"guc": float(group.get("guc", 1.0)),
			})
		if not stream.is_empty():
			streams.append(stream)
			gaps.append(float(group.get("aralik", 1.0)))
	var cursor := 0
	while not streams.is_empty():
		var stream_index := cursor % streams.size()
		var stream: Array = streams[stream_index]
		_queue.append(stream.pop_front())
		if stream.is_empty():
			streams.remove_at(stream_index)
			gaps.remove_at(stream_index)
			cursor = 0
		else:
			cursor += 1
	_spawn_gap = 1.0
	for group in wave.get("gruplar", []):
		_spawn_gap = minf(_spawn_gap, float(group.get("aralik", 1.0)))

	var delay := float(wave.get("gecikme", 0.0))
	wave_started.emit(index, waves.size(), bool(wave.get("boss", false)))
	if delay > 0.0:
		_state = State.DELAY
		_timer = delay
		break_started.emit(delay)
	else:
		_state = State.SPAWNING
		_timer = 0.0


func _process(delta: float) -> void:
	match _state:
		State.DELAY:
			_timer -= delta
			if _timer <= 0.0:
				_state = State.SPAWNING
				_timer = 0.0
		State.SPAWNING:
			_timer -= delta
			while _timer <= 0.0 and not _queue.is_empty():
				var entry: Dictionary = _queue.pop_front()
				spawn_requested.emit(entry["tip"], entry["yol"], entry["guc"])
				_timer += _spawn_gap
			if _queue.is_empty():
				_finish_wave()
		State.BREAK:
			_timer -= delta
			if _timer <= 0.0:
				_begin_wave(current_index + 1)
		_:
			pass


func _finish_wave() -> void:
	if current_index + 1 >= waves.size():
		_state = State.DONE
		all_waves_finished.emit()
		return
	_state = State.BREAK
	_timer = _break_seconds
	break_started.emit(_break_seconds)


## Boss fazlarının çağırdığı yardımcı düşmanlar dalga kuyruğuna değil,
## doğrudan savaş alanına gider — bu yüzden Battle tarafından çağrılır.
func force_spawn(enemy_type: String, path_index: int, power: float) -> void:
	spawn_requested.emit(enemy_type, path_index, power)
