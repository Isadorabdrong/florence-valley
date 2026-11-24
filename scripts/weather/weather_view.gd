class_name WeatherView
extends CanvasLayer
## Screen-space weather effects: rain, storm (rain + lightning), snow,
## wind-blown leaves and drifting fog. Driven by set_weather().

const FLASH_MIN := 6.0
const FLASH_MAX := 14.0

var kind: Weather.Kind = Weather.Kind.SUNNY
var _flash_timer := 0.0

@onready var _rain: CPUParticles2D = $Rain
@onready var _snow: CPUParticles2D = $Snow
@onready var _leaves: CPUParticles2D = $Leaves
@onready var _fog: ColorRect = $Fog
@onready var _flash: ColorRect = $Flash
@onready var _rain_sound: AudioStreamPlayer = $RainSound
@onready var _wind_sound: AudioStreamPlayer = $WindSound


func _ready() -> void:
	_flash.modulate.a = 0.0
	_rain_sound.stream = AudioManager.make_loop(_rain_sound.stream)
	_wind_sound.stream = AudioManager.make_loop(_wind_sound.stream)
	set_weather(kind)


func set_weather(new_kind: Weather.Kind) -> void:
	kind = new_kind
	if not is_node_ready():
		return
	var raining := kind == Weather.Kind.RAIN or kind == Weather.Kind.STORM
	_rain.emitting = raining
	_rain.visible = raining
	_rain.amount = 320 if kind == Weather.Kind.STORM else 170
	_snow.emitting = kind == Weather.Kind.SNOW
	_snow.visible = _snow.emitting
	_leaves.emitting = kind == Weather.Kind.WIND or kind == Weather.Kind.STORM
	_leaves.visible = _leaves.emitting
	_fog.visible = kind == Weather.Kind.FOG
	_flash_timer = randf_range(FLASH_MIN, FLASH_MAX)
	_set_loop(_rain_sound, raining)
	_set_loop(_wind_sound, kind == Weather.Kind.WIND or kind == Weather.Kind.STORM)


func _process(delta: float) -> void:
	if kind != Weather.Kind.STORM:
		return
	_flash_timer -= delta
	if _flash_timer <= 0.0:
		_flash_timer = randf_range(FLASH_MIN, FLASH_MAX)
		var tween := create_tween()
		tween.tween_property(_flash, "modulate:a", 0.55, 0.05)
		tween.tween_property(_flash, "modulate:a", 0.0, 0.12)
		tween.tween_property(_flash, "modulate:a", 0.35, 0.05)
		tween.tween_property(_flash, "modulate:a", 0.0, 0.5)
		AudioManager.play(&"thunder")


func _set_loop(player: AudioStreamPlayer, on: bool) -> void:
	if player.stream == null:
		return
	if on and not player.playing:
		player.play()
	elif not on and player.playing:
		player.stop()
