class_name FencePiece
extends StaticBody2D
## A fence segment that picks its sprite and collision from its neighbours.
## WorldMap calls configure_neighbors() with a N/E/S/W bitmask before adding
## the node to the tree.

const TILE := 16

var neighbor_mask := 0

@onready var _sprite: Sprite2D = $Sprite


func configure_neighbors(mask: int) -> void:
	neighbor_mask = clampi(mask, 0, 15)
	if is_node_ready():
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(neighbor_mask * TILE, 0, TILE, TILE)
	for child in get_children():
		if child is CollisionShape2D:
			child.queue_free()
	var east := (neighbor_mask & MapLayout.EAST) != 0
	var west := (neighbor_mask & MapLayout.WEST) != 0
	var north := (neighbor_mask & MapLayout.NORTH) != 0
	var south := (neighbor_mask & MapLayout.SOUTH) != 0
	# Horizontal bar (post + east/west rails)
	var left := -8.0 if west else -3.0
	var right := 8.0 if east else 3.0
	_add_rect(Rect2(left, -9.0, right - left, 6.0))
	# Vertical bar for north/south runs
	if north or south:
		var top := -16.0 if north else -9.0
		var bottom := 0.0 if south else -3.0
		_add_rect(Rect2(-3.0, top, 6.0, bottom - top))


func _add_rect(r: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.get_center()
	add_child(shape)
