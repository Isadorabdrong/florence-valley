extends TestCase

const LEGEND := {
	"default_terrain": "grass",
	"pad_char": ".",
	"spawn": "P",
	"terrain": {".": "grass", "=": "path", "~": "water", "#": "soil"},
	"objects": {"R": "res://rock.tscn", "F": "res://fence.tscn"},
}


func test_parse_dimensions_and_spawn() -> void:
	var layout := MapLayout.parse("....\n.P..\n....\n", LEGEND)
	assert_eq(layout.width, 4)
	assert_eq(layout.height, 3)
	assert_eq(layout.spawn_cell, Vector2i(1, 1))
	assert_true(layout.warnings.is_empty(), "no warnings expected: %s" % [layout.warnings])


func test_empty_text_returns_null() -> void:
	assert_eq(MapLayout.parse("\n\n", LEGEND), null)


func test_short_rows_are_padded_with_warning() -> void:
	var layout := MapLayout.parse("P...\n..\n", LEGEND)
	assert_eq(layout.rows[1], "....")
	assert_eq(layout.warnings.size(), 1)


func test_missing_spawn_defaults_to_centre() -> void:
	var layout := MapLayout.parse("....\n....\n", LEGEND)
	assert_eq(layout.spawn_cell, Vector2i(2, 1))
	assert_false(layout.warnings.is_empty())


func test_unknown_char_warns_and_uses_default() -> void:
	var layout := MapLayout.parse("P?..\n", LEGEND)
	assert_eq(layout.terrain_at(Vector2i(1, 0)), "grass")
	assert_eq(layout.warnings.size(), 1)


func test_object_cell_takes_surrounding_terrain() -> void:
	var layout := MapLayout.parse("P###\n.#R#\n..##\n", LEGEND)
	assert_eq(layout.object_at(Vector2i(2, 1)), "res://rock.tscn")
	assert_eq(layout.terrain_at(Vector2i(2, 1)), "soil", "rock on a field sits on soil")


func test_spawn_on_path_stays_path() -> void:
	var layout := MapLayout.parse(".=.\n.P.\n.=.\n", LEGEND)
	assert_eq(layout.terrain_at(Vector2i(1, 1)), "path")


func test_object_never_infers_water() -> void:
	var layout := MapLayout.parse("P~.\n~R~\n.~.\n", LEGEND)
	assert_eq(layout.terrain_at(Vector2i(1, 1)), "grass")


func test_terrain_mask() -> void:
	var layout := MapLayout.parse("P...\n.==.\n....\n", LEGEND)
	assert_eq(layout.terrain_mask(Vector2i(1, 1)), MapLayout.EAST, "left path tile connects east only")
	assert_eq(layout.terrain_mask(Vector2i(2, 1)), MapLayout.WEST)


func test_terrain_mask_edges_count_as_connected() -> void:
	var layout := MapLayout.parse("~~\n~P\n", LEGEND)
	assert_eq(layout.terrain_mask(Vector2i(0, 0)), MapLayout.NORTH | MapLayout.WEST | MapLayout.EAST | MapLayout.SOUTH)


func test_char_mask_for_fences() -> void:
	var layout := MapLayout.parse("FFF\n.P.\n", LEGEND)
	assert_eq(layout.char_mask(Vector2i(1, 0)), MapLayout.EAST | MapLayout.WEST)
	assert_eq(layout.char_mask(Vector2i(0, 0)), MapLayout.EAST, "off-map never connects")


func test_real_farm_map_is_valid() -> void:
	var layout := MapLayout.load_from_files("res://data/maps/farm.txt", "res://data/configuration/map_legend.json")
	assert_ne(layout, null, "farm map should load")
	if layout == null:
		return
	assert_true(layout.warnings.is_empty(), "farm map warnings: %s" % [layout.warnings])
	assert_eq(layout.count_char("P"), 1, "exactly one spawn")
	assert_eq(layout.count_char("H"), 1, "exactly one house")
	for ch: String in layout.object_chars:
		var path: String = layout.object_chars[ch]
		assert_true(ResourceLoader.exists(path), "legend scene missing: %s" % path)
