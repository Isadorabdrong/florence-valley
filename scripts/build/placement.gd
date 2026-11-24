class_name Placement
extends RefCounted
## Rules and registry for player builds (fences, paths, benches, ponds…).
## The registry lives in GameState.placed: {map_id: {"x,y": item_id}} keyed by
## the target cell; an item's footprint may cover more cells.

const OUTDOOR_MAPS: Array[StringName] = [&"farm"]
const INDOOR_MAPS: Array[StringName] = [&"house", &"greenhouse"]
const OUTDOOR_GROUND: Array[String] = ["grass", "grass_flowers", "soil", "path", "sand", "meadow", "forest"]
const INDOOR_GROUND: Array[String] = ["wood", "rug", "path"]


static func key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


static func parse_key(k: String) -> Vector2i:
	var xy := k.split(",")
	return Vector2i(int(xy[0]), int(xy[1]))


static func map_allows(item: ItemData, map_id: StringName) -> bool:
	match item.place_where:
		&"indoor":
			return INDOOR_MAPS.has(map_id)
		&"both":
			return INDOOR_MAPS.has(map_id) or OUTDOOR_MAPS.has(map_id)
	return OUTDOOR_MAPS.has(map_id)


## "" if the build fits at `cell`, otherwise a message key.
## `occupied`: (Vector2i) -> bool for objects/placed builds/players on a cell.
## `blocked`: cells that must stay free (exits, arrival points).
static func validate(item: ItemData, map_id: StringName, cell: Vector2i, layout: MapLayout,
		occupied: Callable, soil: SoilGrid, blocked: Dictionary) -> String:
	if item == null or not item.is_placeable():
		return "MSG_CANT_USE_HERE"
	if not map_allows(item, map_id):
		return "MSG_BUILD_NOT_HERE"
	var ground := INDOOR_GROUND if INDOOR_MAPS.has(map_id) else OUTDOOR_GROUND
	for c in item.footprint_cells(cell):
		if not layout.in_bounds(c) or not ground.has(layout.terrain_at(c)):
			return "MSG_BUILD_BAD_GROUND"
		if blocked.has(c):
			return "MSG_BUILD_BLOCKED"
		if bool(occupied.call(c)) or (soil != null and soil.is_tilled(c)):
			return "MSG_BUILD_BLOCKED"
	return ""


## Origin cell and item of the build covering `cell`, or {}.
static func find_at(registry: Dictionary, cell: Vector2i) -> Dictionary:
	for k: String in registry:
		var origin := parse_key(k)
		var item := ItemRegistry.item(StringName(str(registry[k])))
		if item and item.footprint_cells(origin).has(cell):
			return {"origin": origin, "item": item.id}
	return {}
