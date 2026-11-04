extends Node
## Configurações do jogador (autoload). Persistidas em user://settings.cfg.

signal changed

const PATH := "user://settings.cfg"

var music_volume: float = 0.6
var sfx_volume: float = 0.8
var fullscreen: bool = false
var screen_shake: bool = true
var reduced_motion: bool = false
var persist: bool = true   # desligado nos testes automatizados


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	load_settings()
	apply()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	music_volume = cfg.get_value("audio", "music", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	screen_shake = cfg.get_value("video", "screen_shake", screen_shake)
	reduced_motion = cfg.get_value("video", "reduced_motion", reduced_motion)


func save_settings() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "screen_shake", screen_shake)
	cfg.set_value("video", "reduced_motion", reduced_motion)
	cfg.save(PATH)


func apply() -> void:
	_set_bus("Music", music_volume)
	_set_bus("SFX", sfx_volume)
	if DisplayServer.get_name() != "headless" and not OS.has_feature("web"):
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	emit_signal("changed")


func set_value(key: String, value) -> void:
	set(key, value)
	apply()
	save_settings()


func _set_bus(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))


## Fator de movimento: 0 quando "movimento reduzido" está ativo.
func motion() -> float:
	return 0.0 if reduced_motion else 1.0
