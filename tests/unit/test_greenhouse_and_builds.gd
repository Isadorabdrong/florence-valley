extends TestCase

const LEGEND := "res://data/configuration/map_legend.json"


func before_each() -> void:
	GameState.start_new_profile("Teste", "Florence", 0)


func after_each() -> void:
	GameState.start_new_profile("Teste", "Florence", 0)


func test_greenhouse_only_flowers() -> void:
	var outdoor := SoilGrid.new()
	outdoor.till(Vector2i.ZERO)
	assert_eq(outdoor.plant(Vector2i.ZERO, &"orchid", 0), SoilGrid.PlantError.NEEDS_GREENHOUSE)
	var indoor := GameState.greenhouse_soil
	indoor.till(Vector2i.ZERO)
	assert_eq(indoor.plant(Vector2i.ZERO, &"orchid", Calendar.Season.WINTER), SoilGrid.PlantError.NONE)


func test_greenhouse_grows_out_of_season() -> void:
	var soil := GameState.greenhouse_soil
	soil.till(Vector2i(1, 1))
	assert_eq(soil.plant(Vector2i(1, 1), &"tulip", Calendar.Season.WINTER), SoilGrid.PlantError.NONE)
	for i in 6:
		soil.water(Vector2i(1, 1))
		soil.advance_day(Calendar.Season.WINTER)
	assert_true(soil.is_harvestable(Vector2i(1, 1)), "spring tulip blooms in winter indoors")


func test_greenhouse_restoration_cost() -> void:
	assert_false(GameState.restore_greenhouse())
	GameState.wallet.set_amount(2000)
	for entry: Array in GameState.GREENHOUSE_COST["items"]:
		GameState.inventory.add_item(StringName(entry[0]), int(entry[1]))
	assert_true(GameState.restore_greenhouse())
	assert_true(GameState.greenhouse_restored)
	assert_eq(GameState.wallet.amount, 500 + 500, "cost paid, plus the 'greenhouse' achievement reward")
	assert_eq(GameState.progression.stat("greenhouse_restored"), 1)


func _farm_layout() -> MapLayout:
	return MapLayout.load_from_files("res://data/maps/farm.txt", LEGEND)


func _validate(item_id: StringName, map_id: StringName, cell: Vector2i, occupied: Dictionary = {},
		blocked: Dictionary = {}, soil: SoilGrid = null) -> String:
	var layout := MapLayout.load_from_files(str(WorldGraph.map_def(map_id)["layout"]), LEGEND)
	var occ := func(c: Vector2i) -> bool: return occupied.has(c) or not layout.object_at(c).is_empty()
	return Placement.validate(ItemRegistry.item(item_id), map_id, cell, layout, occ, soil, blocked)


func test_placement_rules() -> void:
	assert_eq(_validate(&"build_bench", &"farm", Vector2i(50, 15)), "")
	assert_eq(_validate(&"build_bench", &"village", Vector2i(30, 24)), "MSG_BUILD_NOT_HERE", "only on the farm")
	assert_eq(_validate(&"build_table", &"farm", Vector2i(50, 15)), "MSG_BUILD_NOT_HERE", "furniture is indoor")
	assert_eq(_validate(&"build_table", &"house", Vector2i(7, 7)), "")
	assert_eq(_validate(&"build_vase", &"house", Vector2i(7, 7)), "", "vases fit anywhere")
	assert_eq(_validate(&"build_bench", &"farm", Vector2i(46, 25)), "MSG_BUILD_BAD_GROUND", "water")
	assert_eq(_validate(&"build_lamp", &"farm", Vector2i(45, 11)), "MSG_BUILD_BLOCKED", "greenhouse there")
	assert_eq(_validate(&"build_lamp", &"farm", Vector2i(50, 15), {Vector2i(50, 15): true}), "MSG_BUILD_BLOCKED")
	assert_eq(_validate(&"build_lamp", &"farm", Vector2i(50, 15), {}, {Vector2i(50, 15): true}), "MSG_BUILD_BLOCKED")
	var soil := SoilGrid.new()
	soil.till(Vector2i(50, 15))
	assert_eq(_validate(&"build_lamp", &"farm", Vector2i(50, 15), {}, {}, soil), "MSG_BUILD_BLOCKED", "tilled")
	assert_eq(_validate(&"build_fountain", &"farm", Vector2i(50, 15), {Vector2i(51, 14): true}), "MSG_BUILD_BLOCKED",
		"whole footprint checked")


func test_registry_place_and_pick_up() -> void:
	GameState.inventory.add_item(&"build_pond", 1)
	assert_true(GameState.place_build(&"farm", &"build_pond", Vector2i(50, 15)))
	assert_eq(GameState.inventory.count_of(&"build_pond"), 0)
	var found := Placement.find_at(GameState.placed_on(&"farm"), Vector2i(51, 14))
	assert_eq(found["origin"], Vector2i(50, 15), "footprint lookup")
	assert_eq(GameState.progression.stat("placed_total"), 1)
	var back := GameState.pick_up_build(&"farm", Vector2i(51, 15))
	assert_eq(back["item"], &"build_pond")
	assert_eq(GameState.inventory.count_of(&"build_pond"), 1)
	assert_true(GameState.placed_on(&"farm").is_empty())


func test_builds_saved_and_invalid_dropped() -> void:
	GameState.inventory.add_item(&"build_lamp", 1)
	GameState.place_build(&"farm", &"build_lamp", Vector2i(50, 15))
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_save_data()))
	data["placed"]["farm"]["1,1"] = "rocket_ship"
	GameState.start_new_profile("Outra", "Lua", 0)
	var issues := GameState.apply_save_data(data)
	assert_true(issues.has("placed"))
	assert_eq(GameState.placed_on(&"farm"), {"50,15": "build_lamp"})


func test_workshop_materials_levels_and_upgrades() -> void:
	var shop := Shop.load_from_file("res://data/shops/workshop.json")
	var w := Wallet.new()
	w.add(5000)
	var inv := GameState.inventory
	assert_eq(shop.buy(&"build_path", 1, 0, w, inv, 1), Shop.Result.NEEDS_MATERIALS)
	inv.add_item(&"stone", 40)
	assert_eq(shop.buy(&"build_path", 3, 0, w, inv, 1), Shop.Result.OK)
	assert_eq(inv.count_of(&"stone"), 34, "2 stone each")
	assert_eq(shop.buy(&"watering_can_copper", 1, 0, w, inv, 2), Shop.Result.NEEDS_LEVEL)
	inv.add_item(&"forage_amethyst", 1)
	var slot := inv.first_slot_of(&"watering_can")
	assert_eq(shop.buy(&"watering_can_copper", 1, 0, w, inv, 3), Shop.Result.OK)
	assert_eq(inv.item_at(slot), &"watering_can_copper", "upgrade takes the old slot")
	assert_eq(inv.count_of(&"watering_can"), 0)
	assert_eq(GameState.can_capacity(), 40)
	assert_eq(shop.buy(&"watering_can_copper", 1, 0, w, inv, 3), Shop.Result.NEEDS_OLD_TOOL)


func test_new_recipes() -> void:
	var items: Array[StringName] = [&"flower_golden_rose", &"flower_moon_flower", &"flower_star_flower"]
	assert_eq(BouquetBook.find(items)["id"], "bouquet_crown")
	items = [&"flower_peony", &"flower_peony", &"flower_rose"]
	assert_eq(BouquetBook.find(items)["id"], "bouquet_peony")
	items = [&"flower_orchid", &"flower_lotus", &"flower_iris"]
	assert_eq(BouquetBook.find(items)["id"], "bouquet_oriental")
	assert_eq(BouquetBook.recipes().size(), 15)


func test_schema_4_migration() -> void:
	var v4 := GameState.to_save_data()
	for key in ["progression", "placed", "greenhouse"]:
		v4.erase(key)
	var migrated := SaveSystem.migrate(v4, 4)
	assert_true(GameState.apply_save_data(migrated).is_empty())
	assert_false(GameState.greenhouse_restored)
