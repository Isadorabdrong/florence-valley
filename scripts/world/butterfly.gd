class_name Butterfly
extends Node2D
## A butterfly fluttering around its spawn point (daytime, good weather).

const FRAME := Vector2i(8, 6)
const RADIUS := 26.0

var _home := Vector2.ZERO
var _time := 0.0
var _row := 0
var _speed := 1.0

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	_home = position
	var h := absi(hash(Vector2i(position)))
	_row = h % 4
	_time = float(h % 1000) / 100.0
	_speed = 0.6 + float(h % 7) / 10.0


func _process(delta: float) -> void:
	_time += delta * _speed
	position = _home + Vector2(sin(_time * 1.3) * RADIUS, sin(_time * 2.1) * RADIUS * 0.5 - 12.0 + sin(_time * 7.0) * 2.0)
	var frame := int(_time * 10.0) % 2
	_sprite.region_rect = Rect2(frame * 10 if frame == 1 else 0, _row * FRAME.y, FRAME.x, FRAME.y)
	_sprite.flip_h = cos(_time * 1.3) < 0.0
