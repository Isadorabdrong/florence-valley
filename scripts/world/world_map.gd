class_name WorldMap
extends Node2D
## Builds a playable map from a text layout + JSON legend:
## terrain goes into TileMapLayers, objects are instanced into a y-sorted
## Entities node (where the player and NPCs also live), and invisible walls
## are placed around the map edge.

signal built(world_rect: Rect2)

const TILE_SIZE := 16
const BOUNDS_THICKNESS := 32.0

## Identifies this map in the world state (e.g. removed objects).
@export var map_id: StringName = &"farm"
@export_file("*.txt") var layout_path := ""
@export_file("*.json") var legend_path := "res://data/configuration/map_legend.json"
## When false the owner configures map_id/layout_path and calls build().
@export var auto_build := true

var layout: MapLayout
var spawn_position := Vector2.ZERO
var _scene_cache: Dictionary = {}
var _objects_by_cell: Dictionary = {} # Vector2i -> Node

@onready var ground: TileMapLayer = $Ground
@onready var water: TileMapLayer = $Water
@onready var soil_layer: TileMapLayer = $Soil
## Player-built paths and ponds (Phase 7).
@onready var built_floor: TileMapLayer = $BuiltFloor
@onready var built_water: TileMapLayer = $BuiltWater
@onready var soil_decor_layer: TileMapLayer = $SoilDecor
## Ground-level effects (target cursor, particles) drawn under the entities.
@onready var overlay: Node2D = $Overlay
@onready var entities: Node2D = $Entities


func _ready() -> void:
	if auto_build:
		build()


func build() -> bool:
	layout = MapLayout.load_from_files(layout_path, legend_path)
	if layout == null:
		push_error("WorldMap: could not build map from %s" % layout_path)
		return false
	for warning in layout.warnings:
		push_warning("WorldMap (%s): %s" % [layout_path.get_file(), warning])
	ground.clear()
	water.clear()
	for node: Node in _objects_by_cell.values():
		if is_instance_valid(node):
			node.queue_free()
	_objects_by_cell.clear()
	_paint_terrain()
	_spawn_objects()
	_create_bounds()
	spawn_position = cell_center(layout.spawn_cell)
	built.emit(get_world_rect())
	return true


func get_world_rect() -> Rect2:
	if layout == null:
		return Rect2()
	return Rect2(Vector2.ZERO, Vector2(layout.width, layout.height) * TILE_SIZE)


func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE_SIZE + Vector2.ONE * (TILE_SIZE / 2.0)


## Objects are anchored at the bottom-centre of their cell (their "feet"),
## which is what y-sorting compares.
func cell_anchor(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2.0, (cell.y + 1) * TILE_SIZE)


func world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i((world_position / TILE_SIZE).floor())


## The layout object anchored at this cell (rock, weed, house…), or null.
func get_object_at(cell: Vector2i) -> Node:
	var node: Node = _objects_by_cell.get(cell)
	if node != null and not is_instance_valid(node):
		_objects_by_cell.erase(cell)
		return null
	return node


## Lets other systems (player builds) occupy cells.
func register_object(cell: Vector2i, node: Node) -> void:
	_objects_by_cell[cell] = node


func unregister_object(cell: Vector2i, node: Node) -> void:
	if _objects_by_cell.get(cell) == node:
		_objects_by_cell.erase(cell)


## Removes the object anchored at this cell. Returns false if there was none.
func remove_object_at(cell: Vector2i) -> bool:
	var node := get_object_at(cell)
	if node == null:
		return false
	_objects_by_cell.erase(cell)
	node.queue_free()
	return true


## Seasonal colour grading for ground and foliage.
func apply_season(season: int) -> void:
	SeasonVisuals.set_shader_season(season)
	ground.modulate = SeasonVisuals.ground_tint(season)
	var foliage := SeasonVisuals.foliage_tint(season)
	for node in entities.get_children():
		if node.is_in_group(&"foliage") and node is CanvasItem:
			(node as CanvasItem).modulate = foliage


func cells_with_terrain(terrain: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if layout == null:
		return out
	for y in layout.height:
		for x in layout.width:
			if layout.terrain_at(Vector2i(x, y)) == terrain:
				out.append(Vector2i(x, y))
	return out


func _paint_terrain() -> void:
	for y in layout.height:
		for x in layout.width:
			var cell := Vector2i(x, y)
			var terrain := layout.terrain_at(cell)
			var mask := layout.terrain_mask(cell) if TerrainAtlas.uses_mask(terrain) else 0
			var coords := TerrainAtlas.coords_for(terrain, mask, cell)
			var target := water if TerrainAtlas.is_water(terrain) else ground
			target.set_cell(cell, TerrainAtlas.SOURCE_ID, coords)


func _spawn_objects() -> void:
	for y in layout.height:
		for x in layout.width:
			var cell := Vector2i(x, y)
			var path := layout.object_at(cell)
			if path.is_empty():
				continue
			var scene := _get_scene(path)
			if scene == null:
				continue
			var instance := scene.instantiate()
			if instance is Node2D:
				(instance as Node2D).position = cell_anchor(cell)
			if instance.has_method(&"configure_neighbors"):
				instance.call(&"configure_neighbors", layout.char_mask(cell))
			entities.add_child(instance)
			_objects_by_cell[cell] = instance


func _get_scene(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		var scene := load(path) as PackedScene
		if scene == null:
			push_error("WorldMap: object scene not found: %s" % path)
		_scene_cache[path] = scene
	return _scene_cache[path]


func _create_bounds() -> void:
	var old := get_node_or_null(^"Bounds")
	if old:
		old.free()
	var body := StaticBody2D.new()
	body.name = "Bounds"
	body.collision_layer = 1
	body.collision_mask = 0
	var rect := get_world_rect()
	var t := BOUNDS_THICKNESS
	var walls := [
		Rect2(rect.position.x - t, rect.position.y - t, rect.size.x + t * 2.0, t), # top
		Rect2(rect.position.x - t, rect.end.y, rect.size.x + t * 2.0, t), # bottom
		Rect2(rect.position.x - t, rect.position.y, t, rect.size.y), # left
		Rect2(rect.end.x, rect.position.y, t, rect.size.y), # right
	]
	for wall: Rect2 in walls:
		var shape := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = wall.size
		shape.shape = rect_shape
		shape.position = wall.get_center()
		body.add_child(shape)
	add_child(body)
