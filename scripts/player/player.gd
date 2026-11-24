class_name Player
extends CharacterBody2D
## The player character: 8-direction movement, walk/run, 4-facing animation
## and a following camera clamped to the current map.

signal facing_changed(facing: MovementLogic.Facing)
## A foot touched the ground (walk frames); the scene picks the sound.
signal stepped

const SHEET := preload("res://assets/characters/player_sheet.png")
const FRAME_SIZE := Vector2i(16, 24)

@export var walk_speed := 78.0
@export var run_speed := 126.0
@export var acceleration := 950.0
@export var friction := 1200.0
@export var run_anim_scale := 1.45

var facing: MovementLogic.Facing = MovementLogic.Facing.DOWN
var input_enabled := true
var _lock_time := 0.0

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _camera: Camera2D = $Camera


func _ready() -> void:
	_sprite.sprite_frames = CharacterSpriteFrames.build(SHEET, FRAME_SIZE)
	_sprite.frame_changed.connect(_on_frame_changed)
	apply_outfit(GameState.outfit_index)
	_update_animation(false, false)


func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	_lock_time = maxf(_lock_time - delta, 0.0)
	if input_enabled and _lock_time <= 0.0:
		dir = Input.get_vector(InputBindings.MOVE_LEFT, InputBindings.MOVE_RIGHT,
			InputBindings.MOVE_UP, InputBindings.MOVE_DOWN)
	var running := input_enabled and Input.is_action_pressed(InputBindings.RUN)
	var max_speed := run_speed if running else walk_speed
	velocity = MovementLogic.step_velocity(velocity, dir, max_speed, acceleration, friction, delta)
	move_and_slide()

	var new_facing := MovementLogic.facing_from_direction(dir, facing)
	if new_facing != facing:
		facing = new_facing
		facing_changed.emit(facing)
	_update_animation(not dir.is_zero_approx(), running)


func apply_outfit(index: int) -> void:
	_sprite.material = OutfitPalette.make_material(index)


## Briefly stops movement (e.g. while swinging a tool).
func lock_movement(seconds: float) -> void:
	_lock_time = maxf(_lock_time, seconds)
	velocity = Vector2.ZERO


## Little squash-and-stretch when swinging a tool.
func squash() -> void:
	var tween := create_tween()
	_sprite.scale = Vector2(1.18, 0.86)
	tween.tween_property(_sprite, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## True while moving faster than walking (used for run dust).
func is_running() -> bool:
	return velocity.length() > walk_speed + 4.0


## Turns to face a direction without moving (used by mouse targeting).
func face(direction: Vector2) -> void:
	var new_facing := MovementLogic.facing_from_direction(direction, facing)
	if new_facing != facing:
		facing = new_facing
		facing_changed.emit(facing)
		_update_animation(false, false)


## Map cell under the player's feet.
func feet_cell(tile_size: int = 16) -> Vector2i:
	return Vector2i(((position + Vector2(0, -3)) / tile_size).floor())


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled:
		velocity = Vector2.ZERO


## Clamps the camera to the map so it never shows outside the world.
func set_camera_limits(world_rect: Rect2) -> void:
	_camera.limit_left = int(world_rect.position.x)
	_camera.limit_top = int(world_rect.position.y)
	_camera.limit_right = int(world_rect.end.x)
	_camera.limit_bottom = int(world_rect.end.y)
	_camera.reset_smoothing()


func snap_camera() -> void:
	_camera.reset_smoothing()


func _on_frame_changed() -> void:
	# walk sequence [1, 2, 3, 2]: feet land on frames 0 and 2
	if _sprite.animation.begins_with("walk_") and _sprite.frame % 2 == 0:
		stepped.emit()


func _update_animation(moving: bool, running: bool) -> void:
	# Sheet only has a right-facing row; left is mirrored.
	var dir_name := MovementLogic.facing_name(facing)
	_sprite.flip_h = facing == MovementLogic.Facing.LEFT
	if _sprite.flip_h:
		dir_name = "right"
	var anim := ("walk_" if moving else "idle_") + dir_name
	_sprite.speed_scale = run_anim_scale if (moving and running) else 1.0
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)
