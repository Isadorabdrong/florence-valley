class_name ForageSpot
extends Node2D
## A spot where a wild item may appear each day (decided by GameState's
## forage rolls). Walkable; when it holds an item, interacting picks it up.

var item_id: StringName = &""

## Read by FarmActionResolver: "forage" while something can be picked.
var object_kind: StringName:
	get:
		return &"forage" if item_id != &"" else &""

var _time := 0.0

@onready var _icon: Sprite2D = $Icon
@onready var _shadow: Sprite2D = $Shadow


func _ready() -> void:
	_time = fmod(position.x * 0.13 + position.y * 0.07, TAU)
	_refresh()


func set_item(id: StringName) -> void:
	item_id = id
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	visible = item_id != &""
	_icon.texture = ItemRegistry.icon(item_id) if item_id != &"" else null
	set_process(visible)


func _process(delta: float) -> void:
	_time += delta * 2.2
	_icon.position.y = -9.0 + round(sin(_time) * 1.0)
