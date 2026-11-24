class_name VillagerNPC
extends Node2D
## A villager on the map: walks between schedule spots (straight lines,
## no physics), faces the player when talked to and shows a "!" when they
## have something for you (quest, delivery, heart event, birthday).

const SHEETS := {"a": preload("res://assets/characters/customer_a.png"), "b": preload("res://assets/characters/customer_b.png")}
const SPEED := 40.0

var npc_id := ""
var object_kind: StringName = &"npc"
var target_cell := Vector2i.ZERO
var facing: MovementLogic.Facing = MovementLogic.Facing.DOWN
var _path: Array[Vector2] = []
var _rest_facing := Vector2.DOWN

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _bubble: Sprite2D = $Bubble
@onready var _body: StaticBody2D = $Body


func setup(id: String) -> void:
	npc_id = id
	name = "Villager_" + id
	var npc := Villagers.npc(id)
	_sprite.sprite_frames = CharacterSpriteFrames.build(SHEETS.get(str(npc.get("sheet", "a")), SHEETS["a"]), Vector2i(16, 24))
	var mat := OutfitPalette.make_material(0)
	mat.set_shader_parameter("dst_main", Color(npc["outfit"][0]))
	mat.set_shader_parameter("dst_shade", Color(npc["outfit"][1]))
	mat.set_shader_parameter("dst_hair", Color(npc["hair"][0]))
	mat.set_shader_parameter("dst_hair_shade", Color(npc["hair"][1]))
	mat.set_shader_parameter("dst_skin", Color(npc["skin"][0]))
	mat.set_shader_parameter("dst_skin_shade", Color(npc["skin"][1]))
	_sprite.material = mat
	set_marker(false)
	_play("idle_")


func place(pos: Vector2, cell: Vector2i, face_dir: Vector2) -> void:
	position = pos
	target_cell = cell
	_path.clear()
	_rest_facing = face_dir
	face(face_dir)


func walk_to(pos: Vector2, cell: Vector2i, face_dir: Vector2) -> void:
	target_cell = cell
	_rest_facing = face_dir
	_path = [pos]


func is_walking() -> bool:
	return not _path.is_empty()


func set_marker(on: bool) -> void:
	if is_node_ready():
		_bubble.visible = on


func face(direction: Vector2) -> void:
	facing = MovementLogic.facing_from_direction(direction, facing)
	_play("idle_")


func _process(delta: float) -> void:
	if _path.is_empty():
		return
	var to := _path[0] - position
	if to.length() <= SPEED * delta:
		position = _path.pop_front()
		if _path.is_empty():
			face(_rest_facing)
		return
	var dir := to.normalized()
	position += dir * SPEED * delta
	facing = MovementLogic.facing_from_direction(dir, facing)
	_play("walk_")


func _play(prefix: String) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var dir_name := MovementLogic.facing_name(facing)
	_sprite.flip_h = facing == MovementLogic.Facing.LEFT
	if _sprite.flip_h:
		dir_name = "right"
	if _sprite.animation != prefix + dir_name:
		_sprite.play(prefix + dir_name)
