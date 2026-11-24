extends TestCase


func test_world_is_consistent() -> void:
	var problems := WorldGraph.validate()
	assert_true(problems.is_empty(), "world.json problems:\n  " + "\n  ".join(problems))


func test_expected_places_exist() -> void:
	for id in [&"farm", &"village", &"cherry_forest", &"rare_grove", &"clear_lake", &"lavender_mountains",
			&"butterfly_garden", &"house", &"market", &"cafe", &"library", &"community_center"]:
		assert_true(WorldGraph.has_map(id), "map %s" % id)
		assert_ne(TranslationServer.translate(str(WorldGraph.map_def(id)["name_key"])),
			StringName(str(WorldGraph.map_def(id)["name_key"])), "name for %s" % id)
	assert_true(WorldGraph.allows_farming(&"farm"))
	assert_false(WorldGraph.allows_farming(&"village"))
	assert_false(WorldGraph.is_outdoor(&"house"))


func test_every_region_has_forage_and_a_landmark() -> void:
	var landmarks := WorldGraph.landmarks()
	for id in [&"cherry_forest", &"rare_grove", &"clear_lake", &"lavender_mountains", &"butterfly_garden"]:
		for season in 4:
			assert_false(WorldGraph.forage_table(id, season).is_empty(), "%s season %d" % [id, season])
		assert_true(landmarks.values().has(String(id)), "landmark in %s" % id)


func test_all_texts_translated() -> void:
	var all: Dictionary = WorldGraph.data()["interactions"]
	for key: String in all:
		var text := str(all[key].get("text", ""))
		if not text.is_empty():
			assert_ne(TranslationServer.translate(text), StringName(text), "translation for %s" % text)


func test_forage_roll_is_deterministic() -> void:
	var a := WorldGraph.roll_forage(&"cherry_forest", Vector2i(3, 4), 10, 0, 42)
	var b := WorldGraph.roll_forage(&"cherry_forest", Vector2i(3, 4), 10, 0, 42)
	assert_eq(a, b)
	var found := 0
	for day in 100:
		if WorldGraph.roll_forage(&"cherry_forest", Vector2i(3, 4), day + 2, 0, 42) != &"":
			found += 1
	assert_gt(found, 50, "about 70% of days have an item")
	assert_lt(found, 90)
	assert_eq(WorldGraph.roll_forage(&"village", Vector2i(3, 4), 5, 0, 42), &"", "no table = nothing")


func test_spawns_and_exits() -> void:
	var s := WorldGraph.spawn(&"house", "bed")
	assert_eq(s["cell"], Vector2i(3, 5))
	assert_eq(s["facing"], Vector2.LEFT)
	assert_eq(WorldGraph.spawn(&"house", "nope")["cell"], WorldGraph.spawn(&"house", "default")["cell"], "falls back")
	var targets := WorldGraph.exits(&"village").map(func(e: Dictionary) -> StringName: return e["to"])
	assert_true(targets.has(&"farm") and targets.has(&"clear_lake") and targets.has(&"butterfly_garden"))
