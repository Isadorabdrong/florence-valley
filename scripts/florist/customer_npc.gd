class_name CustomerNPC
extends Node2D
## A shop customer walking along waypoints (no physics). Purely visual:
## the FloristShop simulation decides what they do.

signal arrived_at_end

const SHEETS := [preload("res://assets/characters/customer_a.png"), preload("res://assets/characters/customer_b.png")]
const SPEED := 46.0
const OUTFITS := ["e07a9a", "9d8bc9", "86a37a", "f2c14e", "6c9fc4", "c47c56"]
const HAIR := [["3d2b2b", "2b1f1f"], ["c99a55", "a8783a"], ["8a5236", "6a3b27"], ["5b3a2e", "422a20"], ["e3d1b8", "c9b49a"]]

var customer_id := -1
var waiting := false
var _path: Array[Vector2] = []
var _free_at_end := false
var facing: MovementLogic.Facing = MovementLogic.Facing.UP

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _bubble: Sprite2D = $Bubble


func setup(id: int) -> void:
	customer_id = id
	var h := absi(hash(id * 7919))
	_sprite.sprite_frames = CharacterSpriteFrames.build(SHEETS[h % SHEETS.size()], Vector2i(16, 24))
	var mat := OutfitPalette.make_material(0)
	var outfit := Color(OUTFITS[h % OUTFITS.size()])
	mat.set_shader_parameter("dst_main", outfit)
	mat.set_shader_parameter("dst_shade", outfit.darkened(0.2))
	var hair: Array = HAIR[(h / 7) % HAIR.size()]
	mat.set_shader_parameter("dst_hair", Color(hair[0]))
	mat.set_shader_parameter("dst_hair_shade", Color(hair[1]))
	_sprite.material = mat
	_bubble.visible = false
	_sprite.play("idle_up")


func walk(points: Array[Vector2], free_at_end: bool = false) -> void:
	_path = points.duplicate()
	_free_at_end = free_at_end
	set_waiting(false)


func set_waiting(on: bool) -> void:
	waiting = on
	if is_node_ready():
		_bubble.visible = on


func is_walking() -> bool:
	return not _path.is_empty()


func _process(delta: float) -> void:
	if _path.is_empty():
		_play("idle_")
		return
	var target: Vector2 = _path[0]
	var to := target - position
	if to.length() <= SPEED * delta:
		position = target
		_path.pop_front()
		if _path.is_empty():
			arrived_at_end.emit()
			if _free_at_end:
				queue_free()
		return
	var dir := to.normalized()
	position += dir * SPEED * delta
	facing = MovementLogic.facing_from_direction(dir, facing)
	_play("walk_")


func _play(prefix: String) -> void:
	var name := MovementLogic.facing_name(facing)
	_sprite.flip_h = facing == MovementLogic.Facing.LEFT
	if _sprite.flip_h:
		name = "right"
	if _sprite.animation != prefix + name:
		_sprite.play(prefix + name)
