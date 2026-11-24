extends TestCase


func before_each() -> void:
	GameState.start_new_profile("Teste", "Florence", 0)


func after_each() -> void:
	GameState.start_new_profile("Teste", "Florence", 0)


func _cell_with_item(map_id: StringName) -> Vector2i:
	for y in 40:
		for x in 56:
			if GameState.forage_item_at(map_id, Vector2i(x, y)) != &"":
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func test_forage_pick_once_per_day() -> void:
	var cell := _cell_with_item(&"clear_lake")
	assert_ne(cell, Vector2i(-1, -1))
	var id := GameState.pick_forage(&"clear_lake", cell)
	assert_ne(id, &"")
	assert_eq(GameState.forage_item_at(&"clear_lake", cell), &"", "gone for today")
	assert_eq(GameState.pick_forage(&"clear_lake", cell), &"")
	GameState.weather_override = Weather.Kind.SUNNY
	for i in 3:
		GameState.advance_day()
	GameState.weather_override = -1
	assert_ne(GameState.forage_picked.get("clear_lake:%d,%d" % [cell.x, cell.y]), GameState.calendar.total_days(),
		"a new day resets the spot")


func test_discover_and_visit() -> void:
	assert_true(GameState.discover("sundial"))
	assert_false(GameState.discover("sundial"), "only once")
	assert_true(GameState.visit(&"village"))
	assert_false(GameState.visit(&"village"))


func test_travel_validates_map() -> void:
	GameState.travel(&"village", "from_farm")
	assert_eq(GameState.current_map, &"village")
	assert_eq(GameState.pending_spawn, "from_farm")
	GameState.travel(&"atlantis", "x")
	assert_eq(GameState.current_map, &"village", "unknown maps are refused")


func test_exploration_saved_and_loaded() -> void:
	GameState.travel(&"clear_lake", "default")
	GameState.discover("lake_marker")
	GameState.visit(&"clear_lake")
	GameState.forage_picked["clear_lake:1,2"] = 5
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_save_data()))
	GameState.start_new_profile("Outra", "Fazenda", 0)
	assert_true(GameState.apply_save_data(data).is_empty())
	assert_eq(GameState.current_map, &"clear_lake")
	assert_true(GameState.discoveries.has("lake_marker"))
	assert_true(GameState.visited_maps.has("clear_lake"))
	assert_eq(GameState.forage_picked["clear_lake:1,2"], 5)


func test_unknown_saved_map_falls_back_to_farm() -> void:
	var data := GameState.to_save_data()
	data["world"]["map"] = "atlantis"
	var issues := GameState.apply_save_data(data)
	assert_true(issues.has("map"))
	assert_eq(GameState.current_map, &"farm")


func test_schema_1_save_migrates_to_world() -> void:
	var v1 := {"profile": {"name": "Ana", "farm": "Lua", "outfit": 0}, "money": 40, "world": {"seed": 1}}
	var migrated := SaveSystem.migrate(v1, 1)
	assert_eq(migrated["world"]["map"], "farm")
	assert_true(migrated.has("exploration"))
	assert_true(GameState.apply_save_data(migrated).is_empty())
	assert_eq(GameState.current_map, &"farm")
