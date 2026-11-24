extends SceneTree
## Builds resources/tilesets/terrain_tileset.tres from the terrain atlas.
## Run after generate_assets.gd and an import pass:
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/build_tileset.gd

const ATLAS_PATH := "res://assets/environments/terrain_atlas.png"
const OUT_PATH := "res://resources/tilesets/terrain_tileset.tres"
const SOIL_ATLAS_PATH := "res://assets/environments/soil_atlas.png"
const SOIL_OUT_PATH := "res://resources/tilesets/soil_tileset.tres"
const TILE := 16
const COLUMNS := 16
const ROWS := 9
## Rows/cells with full-tile collision: water, cliffs and interior walls.
const SOLID_ROWS := [2, 6]
const SOLID_CELLS := [Vector2i(8, 8), Vector2i(9, 8)]
const EMPTY_CELLS := [Vector2i(11, 8), Vector2i(12, 8), Vector2i(13, 8), Vector2i(14, 8), Vector2i(15, 8)]
const WORLD_LAYER_BIT := 1


func _initialize() -> void:
	var texture := load(ATLAS_PATH) as Texture2D
	if texture == null:
		push_error("[tileset] atlas not imported yet: %s" % ATLAS_PATH)
		quit(1)
		return
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, WORLD_LAYER_BIT)
	tile_set.set_physics_layer_collision_mask(0, 0)

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE, TILE)
	tile_set.add_source(source, 0)

	var half := TILE / 2.0
	var square := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	for row in ROWS:
		for col in COLUMNS:
			var coords := Vector2i(col, row)
			if (row == 0 and col >= 8) or EMPTY_CELLS.has(coords):
				continue # unused atlas cells
			source.create_tile(coords)
			if SOLID_ROWS.has(row) or SOLID_CELLS.has(coords):
				var data := source.get_tile_data(coords, 0)
				data.add_collision_polygon(0)
				data.set_collision_polygon_points(0, 0, square)
	var err := ResourceSaver.save(tile_set, OUT_PATH)
	if err != OK:
		push_error("[tileset] save failed: %d" % err)
		quit(1)
		return
	print("[tileset] wrote ", OUT_PATH)
	if not _build_soil_tileset():
		quit(1)
		return
	quit(0)


## Tilled-soil overlay (no physics): rows 0-1 x 16 masks, plus (0, 2).
func _build_soil_tileset() -> bool:
	var texture := load(SOIL_ATLAS_PATH) as Texture2D
	if texture == null:
		push_error("[tileset] soil atlas not imported yet: %s" % SOIL_ATLAS_PATH)
		return false
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE, TILE)
	tile_set.add_source(source, 0)
	for row in 2:
		for col in COLUMNS:
			source.create_tile(Vector2i(col, row))
	source.create_tile(Vector2i(0, 2))
	var err := ResourceSaver.save(tile_set, SOIL_OUT_PATH)
	if err != OK:
		push_error("[tileset] soil save failed: %d" % err)
		return false
	print("[tileset] wrote ", SOIL_OUT_PATH)
	return true
