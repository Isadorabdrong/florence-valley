class_name GameSettings
extends RefCounted
## Player preferences, stored in user://settings.cfg (separate from saves).

const PATH := "user://settings.cfg"
const LOCALES: Array[String] = ["pt_BR", "en"]
const BUS_SFX := &"SFX"
const BUS_AMBIENT := &"Ambient"
const BUS_MUSIC := &"Music"

var sfx_volume := 0.8
var ambient_volume := 0.7
var music_volume := 0.7
var fullscreen := false
var locale := "pt_BR"


static func load_or_default(path: String = PATH) -> GameSettings:
	var s := GameSettings.new()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return s
	s.sfx_volume = clampf(float(cfg.get_value("audio", "sfx", s.sfx_volume)), 0.0, 1.0)
	s.ambient_volume = clampf(float(cfg.get_value("audio", "ambient", s.ambient_volume)), 0.0, 1.0)
	s.music_volume = clampf(float(cfg.get_value("audio", "music", s.music_volume)), 0.0, 1.0)
	s.fullscreen = bool(cfg.get_value("display", "fullscreen", false))
	var loc := str(cfg.get_value("general", "locale", s.locale))
	s.locale = loc if LOCALES.has(loc) else "pt_BR"
	return s


func save(path: String = PATH) -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "ambient", ambient_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("general", "locale", locale)
	return cfg.save(path)


func apply() -> void:
	ensure_audio_buses()
	_set_bus(BUS_SFX, sfx_volume)
	_set_bus(BUS_AMBIENT, ambient_volume)
	_set_bus(BUS_MUSIC, music_volume)
	TranslationServer.set_locale(locale)
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)


static func ensure_audio_buses() -> void:
	for bus in [BUS_MUSIC, BUS_AMBIENT, BUS_SFX]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, &"Master")


static func _set_bus(bus: StringName, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i == -1:
		return
	AudioServer.set_bus_mute(i, linear <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.001)))
