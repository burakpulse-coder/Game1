extends Node

## Basit, kapatılabilir günlükleme. Yayın derlemesinde ayrıntılı kayıtlar susar.

enum Level { DEBUG, INFO, WARN, ERROR }

var min_level: Level = Level.DEBUG


func _ready() -> void:
	if not OS.is_debug_build():
		min_level = Level.WARN


func debug(tag: String, message: String) -> void:
	_write(Level.DEBUG, tag, message)


func info(tag: String, message: String) -> void:
	_write(Level.INFO, tag, message)


func warn(tag: String, message: String) -> void:
	_write(Level.WARN, tag, message)


func error(tag: String, message: String) -> void:
	_write(Level.ERROR, tag, message)


func _write(level: Level, tag: String, message: String) -> void:
	if level < min_level:
		return
	var line := "[%s] %s" % [tag, message]
	match level:
		Level.ERROR:
			push_error(line)
		Level.WARN:
			push_warning(line)
		_:
			print(line)
