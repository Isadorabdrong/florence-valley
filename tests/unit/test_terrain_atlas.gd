extends TestCase


func test_masked_terrains_use_mask_as_column() -> void:
	assert_eq(TerrainAtlas.coords_for("path", 5, Vector2i.ZERO), Vector2i(5, 1))
	assert_eq(TerrainAtlas.coords_for("water", 15, Vector2i.ZERO), Vector2i(15, 2))
	assert_eq(TerrainAtlas.coords_for("soil", 0, Vector2i.ZERO), Vector2i(0, 3))


func test_grass_variants_are_stable_and_in_range() -> void:
	for x in 20:
		for y in 20:
			var a := TerrainAtlas.coords_for("grass", 0, Vector2i(x, y))
			var b := TerrainAtlas.coords_for("grass", 0, Vector2i(x, y))
			assert_eq(a, b, "deterministic")
			assert_true(a.x >= 0 and a.x < 4 and a.y == 0, "grass in row 0, cols 0-3: %s" % a)
			var f := TerrainAtlas.coords_for("grass_flowers", 0, Vector2i(x, y))
			assert_true(f.x >= 4 and f.x < 8, "flower grass in cols 4-7: %s" % f)


func test_tileset_has_water_collision_only() -> void:
	var ts := load("res://resources/tilesets/terrain_tileset.tres") as TileSet
	assert_ne(ts, null, "tileset exists")
	if ts == null:
		return
	var src := ts.get_source(TerrainAtlas.SOURCE_ID) as TileSetAtlasSource
	var water := src.get_tile_data(Vector2i(0, 2), 0)
	var path := src.get_tile_data(Vector2i(0, 1), 0)
	assert_eq(water.get_collision_polygons_count(0), 1, "water blocks")
	assert_eq(path.get_collision_polygons_count(0), 0, "path is walkable")
