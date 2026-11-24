class_name WorldGraph
extends RefCounted
## The world registry (data/maps/world.json): maps, named spawn points,
## edge exits, per-cell interactions (doors, signs, shops, landmarks) and
## daily forage tables. Static + cached; validate() checks consistency.

const PATH := "res://data/maps/world.json"
const LEGEND_PATH := "res://data/configuration/map_legend.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var file := FileAccess.open(PATH, FileAccess.READ)
		if file == null:
			push_error("WorldGraph: cannot open %s" % PATH)
			return {}
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("WorldGraph: invalid JSON in %s" % PATH)
			return {}
		_data = parsed
	return _data


static func clear_cache() -> void:
	_data = {}


static func has_map(map_id: StringName) -> bool:
	return (data().get("maps", {}) as Dictionary).has(String(map_id))


static func map_def(map_id: StringName) -> Dictionary:
	return (data().get("maps", {}) as Dictionary).get(String(map_id), {})


static func map_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: String in data().get("maps", {}):
		out.append(StringName(id))
	return out


static func is_outdoor(map_id: StringName) -> bool:
	return bool(map_def(map_id).get("outdoor", true))


static func allows_farming(map_id: StringName) -> bool:
	return bool(map_def(map_id).get("farming", false))


static func start_map() -> StringName:
	return StringName(str(data().get("start_map", "farm")))


static func home_map() -> StringName:
	return StringName(str(data().get("home_map", "house")))


static func home_spawn() -> String:
	return str(data().get("home_spawn", "default"))


## {"cell": Vector2i, "facing": Vector2} or {} if unknown.
static func spawn(map_id: StringName, spawn_name: String) -> Dictionary:
	var map_spawns: Dictionary = (data().get("spawns", {}) as Dictionary).get(String(map_id), {})
	var s: Variant = map_spawns.get(spawn_name, map_spawns.get("default"))
	if typeof(s) != TYPE_ARRAY or (s as Array).size() < 2:
		return {}
	var facing := Vector2.DOWN
	match str(s[2]) if (s as Array).size() > 2 else "down":
		"up":
			facing = Vector2.UP
		"left":
			facing = Vector2.LEFT
		"right":
			facing = Vector2.RIGHT
	return {"cell": Vector2i(int(s[0]), int(s[1])), "facing": facing}


## Edge exits of a map: [{"cells": Array[Vector2i], "to": StringName, "spawn": String}]
static func exits(map_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in data().get("exits", []):
		if e.get("map") != String(map_id):
			continue
		var cells: Array[Vector2i] = []
		for c: Array in e.get("cells", []):
			cells.append(Vector2i(int(c[0]), int(c[1])))
		out.append({"cells": cells, "to": StringName(str(e.get("to"))), "spawn": str(e.get("spawn", "default"))})
	return out


static func interaction(map_id: StringName, cell: Vector2i) -> Dictionary:
	return (data().get("interactions", {}) as Dictionary).get("%s:%d,%d" % [map_id, cell.x, cell.y], {})


## All landmark ids, for the map screen's discovery counter.
static func landmarks() -> Dictionary:
	var out := {}
	var all: Dictionary = data().get("interactions", {})
	for key: String in all:
		var d: Dictionary = all[key]
		if d.get("type") == "landmark":
			out[str(d.get("id"))] = key.get_slice(":", 0)
	return out


static func forage_chance() -> float:
	return float((data().get("forage", {}) as Dictionary).get("chance", 0.7))


static func forage_table(map_id: StringName, season: int) -> Array:
	var tables: Dictionary = (data().get("forage", {}) as Dictionary).get("tables", {})
	return (tables.get(String(map_id), {}) as Dictionary).get(str(season), [])


## Deterministic forage roll for a spot on a given day. "" = nothing today.
static func roll_forage(map_id: StringName, cell: Vector2i, total_day: int, season: int, world_seed: int) -> StringName:
	var table := forage_table(map_id, season)
	if table.is_empty():
		return &""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, String(map_id), cell.x, cell.y, total_day])
	if rng.randf() >= forage_chance():
		return &""
	var total := 0
	for entry: Array in table:
		total += int(entry[1])
	var pick := rng.randi_range(1, total)
	for entry: Array in table:
		pick -= int(entry[1])
		if pick <= 0:
			return StringName(str(entry[0]))
	return &""


## Consistency checks used by the tests. Returns a list of problems.
static func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	var maps: Dictionary = data().get("maps", {})
	var layouts := {}
	for id: String in maps:
		var layout := MapLayout.load_from_files(str(maps[id].get("layout")), LEGEND_PATH)
		if layout == null:
			problems.append("%s: layout missing" % id)
			continue
		for w in layout.warnings:
			problems.append("%s: %s" % [id, w])
		layouts[id] = layout
		for sp: String in (data().get("spawns", {}) as Dictionary).get(id, {}):
			var s := spawn(StringName(id), sp)
			var cell: Vector2i = s["cell"]
			if not layout.in_bounds(cell) or TerrainAtlas.is_solid(layout.terrain_at(cell)) \
					or not layout.object_at(cell).is_empty():
				problems.append("%s: spawn '%s' %s is not walkable" % [id, sp, cell])
	for e: Dictionary in data().get("exits", []):
		var from := str(e.get("map"))
		if not maps.has(from) or not maps.has(str(e.get("to"))):
			problems.append("exit %s -> %s: unknown map" % [from, e.get("to")])
			continue
		var target_spawns: Dictionary = (data().get("spawns", {}) as Dictionary).get(str(e.get("to")), {})
		if not target_spawns.has(str(e.get("spawn"))):
			problems.append("exit %s -> %s: missing spawn %s" % [from, e.get("to"), e.get("spawn")])
		for c: Array in e.get("cells", []):
			var layout: MapLayout = layouts.get(from)
			if layout and TerrainAtlas.is_solid(layout.terrain_at(Vector2i(int(c[0]), int(c[1])))):
				problems.append("exit %s %s is on a solid tile" % [from, c])
	var all: Dictionary = data().get("interactions", {})
	for key: String in all:
		var map_id := key.get_slice(":", 0)
		var xy := key.get_slice(":", 1).split(",")
		var cell := Vector2i(int(xy[0]), int(xy[1]))
		var layout: MapLayout = layouts.get(map_id)
		if layout == null:
			problems.append("interaction %s: unknown map" % key)
			continue
		if layout.object_at(cell).is_empty():
			problems.append("interaction %s: no object at that cell" % key)
		var d: Dictionary = all[key]
		match str(d.get("type")):
			"door":
				var target := str(d.get("to"))
				if not maps.has(target) or not ((data().get("spawns", {}) as Dictionary).get(target, {}) as Dictionary).has(str(d.get("spawn"))):
					problems.append("door %s: bad target %s/%s" % [key, target, d.get("spawn")])
			"sign", "locked", "landmark", "diary":
				if str(d.get("text", "")).is_empty():
					problems.append("%s: missing text" % key)
			"shop":
				if not FileAccess.file_exists("res://data/shops/%s.json" % d.get("shop")):
					problems.append("%s: missing shop %s" % [key, d.get("shop")])
			"florist_door", "greenhouse_door":
				var target := str(d.get("to"))
				if not maps.has(target):
					problems.append("florist door %s: bad target %s" % [key, target])
			"florist_counter", "florist_board", "florist_workbench", "florist_stand":
				pass
			_:
				problems.append("%s: unknown type %s" % [key, d.get("type")])
	var tables: Dictionary = (data().get("forage", {}) as Dictionary).get("tables", {})
	for map_id: String in tables:
		for season: String in tables[map_id]:
			for entry: Array in tables[map_id][season]:
				if not ItemRegistry.has_item(StringName(str(entry[0]))):
					problems.append("forage %s/%s: unknown item %s" % [map_id, season, entry[0]])
	# every map reachable from the start map
	var seen := {String(start_map()): true}
	var queue: Array = [String(start_map())]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		var nexts: Array = []
		for e: Dictionary in data().get("exits", []):
			if e.get("map") == cur:
				nexts.append(str(e.get("to")))
		for key: String in all:
			if key.begins_with(cur + ":") and (all[key].get("type") in ["door", "florist_door", "greenhouse_door"]):
				nexts.append(str(all[key].get("to")))
		for n: String in nexts:
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	for id: String in maps:
		if not seen.has(id):
			problems.append("%s is unreachable from %s" % [id, start_map()])
	return problems
