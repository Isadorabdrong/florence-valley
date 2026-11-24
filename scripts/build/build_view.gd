class_name BuildView
extends Node
## Draws the player's builds on a map: scenes (benches, trees, fences…) as
## objects in the y-sorted entities layer, paths and ponds on tile layers.
## Also keeps fences connected (layout fences + placed fences).

const META := &"placed_item"

var map: WorldMap
var registry: Dictionary # "x,y" -> item id (shared with GameState.placed)
var _nodes: Dictionary = {} # origin key -> Node
var _preview_cache: Dictionary = {}


func setup(world_map: WorldMap, map_registry: Dictionary) -> void:
	map = world_map
	registry = map_registry
	for k: String in registry:
		_spawn(Placement.parse_key(k), StringName(str(registry[k])))
	_redraw_floors()
	refresh_fences()


func water_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for k: String in registry:
		var item := ItemRegistry.item(StringName(str(registry[k])))
		if item and item.place_floor == &"pond":
			out.append_array(item.footprint_cells(Placement.parse_key(k)))
	return out


## Called after the registry gained an entry.
func add(origin: Vector2i, item_id: StringName) -> void:
	_spawn(origin, item_id)
	_redraw_floors()
	refresh_fences()


## Called after the registry lost an entry.
func remove(origin: Vector2i, item_id: StringName) -> void:
	var item := ItemRegistry.item(item_id)
	var node: Node = _nodes.get(Placement.key(origin))
	if node:
		for c in item.footprint_cells(origin):
			map.unregister_object(c, node)
		node.queue_free()
		_nodes.erase(Placement.key(origin))
	_redraw_floors()
	refresh_fences()


func node_at(origin: Vector2i) -> Node:
	return _nodes.get(Placement.key(origin))


func _spawn(origin: Vector2i, item_id: StringName) -> void:
	var item := ItemRegistry.item(item_id)
	if item == null or item.place_scene.is_empty():
		return
	var scene := load(item.place_scene) as PackedScene
	if scene == null:
		return
	var node := scene.instantiate()
	node.set_meta(META, item_id)
	(node as Node2D).position = map.cell_anchor(origin)
	map.entities.add_child(node)
	for c in item.footprint_cells(origin):
		map.register_object(c, node)
	_nodes[Placement.key(origin)] = node


func _is_floor(cell: Vector2i, kind: StringName) -> bool:
	var found := Placement.find_at(registry, cell)
	return not found.is_empty() and ItemRegistry.item(found["item"]).place_floor == kind


func _redraw_floors() -> void:
	map.built_floor.clear()
	map.built_water.clear()
	for k: String in registry:
		var item := ItemRegistry.item(StringName(str(registry[k])))
		if item == null or item.place_floor == &"":
			continue
		for c in item.footprint_cells(Placement.parse_key(k)):
			var mask := 0
			var dirs := [[Vector2i.UP, MapLayout.NORTH], [Vector2i.RIGHT, MapLayout.EAST],
				[Vector2i.DOWN, MapLayout.SOUTH], [Vector2i.LEFT, MapLayout.WEST]]
			for d: Array in dirs:
				if _is_floor(c + d[0], item.place_floor):
					mask |= int(d[1])
			if item.place_floor == &"pond":
				map.built_water.set_cell(c, TerrainAtlas.SOURCE_ID, TerrainAtlas.coords_for("water", mask, c))
			else:
				map.built_floor.set_cell(c, TerrainAtlas.SOURCE_ID, TerrainAtlas.coords_for("cobble", mask, c))


## Layout fences and placed fences connect to each other.
func refresh_fences() -> void:
	for y in map.layout.height:
		for x in map.layout.width:
			var cell := Vector2i(x, y)
			var node := map.get_object_at(cell)
			if node is FencePiece:
				var mask := 0
				var dirs := [[Vector2i.UP, MapLayout.NORTH], [Vector2i.RIGHT, MapLayout.EAST],
					[Vector2i.DOWN, MapLayout.SOUTH], [Vector2i.LEFT, MapLayout.WEST]]
				for d: Array in dirs:
					if map.get_object_at(cell + d[0]) is FencePiece:
						mask |= int(d[1])
				(node as FencePiece).configure_neighbors(mask)


## Texture + offset to show a translucent preview of a build.
func preview_for(item: ItemData) -> Dictionary:
	if _preview_cache.has(item.id):
		return _preview_cache[item.id]
	var info := {}
	if not item.place_scene.is_empty():
		var node := (load(item.place_scene) as PackedScene).instantiate()
		var sprite := node.get_node_or_null(^"Sprite") as Sprite2D
		if sprite:
			info = {"texture": sprite.texture, "offset": sprite.offset, "region": sprite.region_rect if sprite.region_enabled else Rect2()}
		node.free()
	_preview_cache[item.id] = info
	return info
