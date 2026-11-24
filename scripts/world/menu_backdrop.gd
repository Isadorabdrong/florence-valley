extends Node2D
## Living backdrop for menus: the real farm map with a slowly drifting camera.

@export var drift_x := 150.0
@export var drift_y := 28.0
@export var speed := 1.0

var _time := 0.0
var _center := Vector2.ZERO

@onready var _map: WorldMap = $FarmMap
@onready var _camera: Camera2D = $Camera


func _ready() -> void:
	var rect := _map.get_world_rect()
	_camera.limit_left = int(rect.position.x)
	_camera.limit_top = int(rect.position.y)
	_camera.limit_right = int(rect.end.x)
	_camera.limit_bottom = int(rect.end.y)
	_center = _map.spawn_position + Vector2(40, 20)
	_camera.position = _center
	_camera.reset_smoothing()


func _process(delta: float) -> void:
	_time += delta * speed
	_camera.position = _center + Vector2(sin(_time * 0.07) * drift_x, sin(_time * 0.045) * drift_y)
